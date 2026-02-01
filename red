local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Fling settings
local FLING_RADIUS = 15
local FLING_VELOCITY = 250
local FLING_FORCE = 400000

-- Cooldown
local cooldown = false
local COOLDOWN_TIME = 1 -- seconds

-- Helper to play sound safely
local function playSFX(soundId, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = 3
	sound.PlayOnRemove = false
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5) -- auto-remove after 5 seconds
end

local function getNearbyUnanchoredParts(centerPos, range)
	local region = Region3.new(centerPos - Vector3.new(range, range, range), centerPos + Vector3.new(range, range, range))
	local parts = workspace:FindPartsInRegion3WithIgnoreList(region, {player.Character}, math.huge)
	local valid = {}

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and not part.Anchored and not part:IsDescendantOf(player.Character) then
			table.insert(valid, part)
		end
	end
	return valid
end

local function createHeldBall(character)
	local rightArm = character:FindFirstChild("Right Arm")
	if not rightArm then
		warn("Right Arm not found (R6 required)")
		return
	end

	local ball = Instance.new("Part")
	ball.Name = "HeldBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.5, 0.5, 0.5)
	ball.Material = Enum.Material.Neon
	ball.BrickColor = BrickColor.new("Really red")
	ball.Anchored = false
	ball.CanCollide = true

	-- Dimmed glow
	local light = Instance.new("PointLight")
	light.Brightness = 10
	light.Range = 15
	light.Color = Color3.fromRGB(255, 0, 0)
	light.Parent = ball

	local weld = Instance.new("Weld")
	weld.Part0 = rightArm
	weld.Part1 = ball
	weld.C0 = CFrame.new(0, -1.5, 0)
	weld.Parent = ball
	ball.Parent = character

	-- Play audio
	playSFX("9114314786", ball)

	task.delay(1, function()
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end

		weld:Destroy()
		ball.Anchored = true

		local root = character.HumanoidRootPart
		local startPos = ball.Position
		local forwardDirection = root.CFrame.LookVector
		local endPos = startPos + forwardDirection * 600

		local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear)
		local goal = { Position = endPos }
		local tween = TweenService:Create(ball, tweenInfo, goal)
		tween:Play()

		local flingConn
		flingConn = RunService.Heartbeat:Connect(function()
			if not ball or not ball.Parent then
				if flingConn then flingConn:Disconnect() end
				return
			end

			local pos = ball.Position
			local parts = getNearbyUnanchoredParts(pos, FLING_RADIUS)

			for _, part in ipairs(parts) do
				local offset = part.Position - pos
				if offset.Magnitude == 0 then continue end
				local direction = offset.Unit

				local bv = Instance.new("BodyVelocity")
				bv.Name = "FlingForce"
				bv.MaxForce = Vector3.new(FLING_FORCE, FLING_FORCE, FLING_FORCE)
				bv.P = 400000
				bv.Velocity = direction * FLING_VELOCITY
				bv.Parent = part

				Debris:AddItem(bv, 0.1)
			end
		end)

		tween.Completed:Wait()
		if flingConn then flingConn:Disconnect() end
		ball:Destroy()
	end)
end

local function setupCharacter(character)
	local rightArm = character:WaitForChild("Right Arm", 3)
	if rightArm then
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == Enum.KeyCode.X and not cooldown then
				cooldown = true
				createHeldBall(character)

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Died:Connect(function()
						local ball = character:FindFirstChild("HeldBall")
						if ball then
							ball:Destroy()
						end
					end)
				end

				-- Reset cooldown
				task.delay(COOLDOWN_TIME, function()
					cooldown = false
				end)
			end
		end)
	end
end

-- Run on character spawn
player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end
