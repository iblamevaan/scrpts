local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local currentTrack = nil
local cooldown = false
local COOLDOWN_TIME = 1

------------------------------------------------
-- CHARACTER TRACKING (FIXED)
------------------------------------------------
local character = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function(c)
	character = c
end)

------------------------------------------------
-- ANIMATION
------------------------------------------------
local function playAnimation()
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if currentTrack then
		pcall(function()
			currentTrack:Stop(0)
		end)
		currentTrack = nil
	end

	local ok, track = pcall(function()
		return humanoid:PlayEmoteAndGetAnimTrackById(118139871934372)
	end)

	if not ok or not track then return end

	track.Looped = false
	track:AdjustSpeed(2)

	currentTrack = track

	task.delay(3, function()
		if currentTrack then
			pcall(function()
				currentTrack:Stop(0)
			end)
			currentTrack = nil
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.X then
		playAnimation()
	end
end)

------------------------------------------------
-- SETTINGS
------------------------------------------------
local FLING_RADIUS = 15
local FLING_VELOCITY = 250
local FLING_FORCE = 400000

------------------------------------------------
-- SOUND (STABLE FIX)
------------------------------------------------
local function playSFX(soundId, character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local old = root:FindFirstChild("ActiveSFX")
	if old then
		old:Stop()
		old:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = "ActiveSFX"
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = 1.5
	sound.RollOffMaxDistance = 60
	sound.Parent = root

	-- non-blocking load fix
	task.spawn(function()
		if not sound.IsLoaded then
			sound.Loaded:Wait()
		end
	end)

	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

------------------------------------------------
-- GET PARTS
------------------------------------------------
local function getNearbyUnanchoredParts(centerPos, range, character)
	local region = Region3.new(
		centerPos - Vector3.new(range, range, range),
		centerPos + Vector3.new(range, range, range)
	)

	local parts = workspace:FindPartsInRegion3WithIgnoreList(region, {character}, math.huge)
	local valid = {}

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and not part.Anchored and not part:IsDescendantOf(character) then
			table.insert(valid, part)
		end
	end

	return valid
end

------------------------------------------------
-- CREATE BALL
------------------------------------------------
local function createHeldBall(char)
	if not char then return end

	local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not rightArm or not rootPart then return end

	local ball = Instance.new("Part")
	ball.Name = "HeldBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.5, 0.5, 0.5)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 0, 0)
	ball.Anchored = false
	ball.CanCollide = true
	ball.Parent = char

	------------------------------------------------
	-- PARTICLES (your existing style kept)
	------------------------------------------------
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 0))
	})

	particles.LightEmission = 0.8
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0)
	})

	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1)
	})

	particles.Lifetime = NumberRange.new(0.25, 0.5)
	particles.Rate = 55
	particles.Speed = NumberRange.new(2, 6)
	particles.Drag = 2
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-90, 90)
	particles.Parent = ball

	local light = Instance.new("PointLight")
	light.Brightness = 10
	light.Range = 15
	light.Color = Color3.fromRGB(255, 0, 0)
	light.Parent = ball

	local weld = Instance.new("Weld")
	weld.Part0 = rightArm
	weld.Part1 = ball
	weld.C0 = CFrame.new(0, 0, 0)
	weld.Parent = ball

	playSFX("113806286169554", char)

	task.delay(1, function()
		if not char or not rootPart or not ball.Parent then return end

		weld:Destroy()
		ball.Anchored = true

		local startPos = ball.Position
		local forwardDirection = rootPart.CFrame.LookVector
		local endPos = startPos + forwardDirection * 600

		local tween = TweenService:Create(
			ball,
			TweenInfo.new(1, Enum.EasingStyle.Linear),
			{Position = endPos}
		)

		tween:Play()

		local flingConn
		flingConn = RunService.Heartbeat:Connect(function()
			if not ball or not ball.Parent then
				if flingConn then flingConn:Disconnect() end
				return
			end

			local pos = ball.Position
			local parts = getNearbyUnanchoredParts(pos, FLING_RADIUS, char)

			for _, part in ipairs(parts) do
				local offset = part.Position - pos
				if offset.Magnitude == 0 then continue end

				local direction = offset.Unit

				local bv = Instance.new("BodyVelocity")
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

------------------------------------------------
-- INPUT (FIXED — NO BREAKING)
------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.X and not cooldown then
		cooldown = true
		createHeldBall(character)

		task.delay(COOLDOWN_TIME, function()
			cooldown = false
		end)
	end
end)
