--red
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
-- CHARACTER TRACKING
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
local FLING_VELOCITY = 300
local FLING_FORCE = 400000

------------------------------------------------
-- SOUND
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

	local weld = Instance.new("Weld")
	weld.Part0 = rightArm
	weld.Part1 = ball
	weld.C0 = CFrame.new(0, -1.0, 0)
	weld.Parent = ball

	local pullEmitter = Instance.new("ParticleEmitter")
	pullEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pullEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60))
	})
	pullEmitter.LightEmission = 1
	pullEmitter.Speed = NumberRange.new(0.5, 1.8)
	pullEmitter.Rate = 180
	pullEmitter.Lifetime = NumberRange.new(0.25, 0.4)
	pullEmitter.SpreadAngle = Vector2.new(180, 180)
	pullEmitter.Acceleration = Vector3.new(0, -8, 0)
	pullEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0)
	})
	pullEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	pullEmitter.Rotation = NumberRange.new(0, 360)
	pullEmitter.RotSpeed = NumberRange.new(-140, 140)
	pullEmitter.Parent = ball

	local tinyPullEmitter = Instance.new("ParticleEmitter")
	tinyPullEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	tinyPullEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 120))
	})
	tinyPullEmitter.LightEmission = 1
	tinyPullEmitter.Speed = NumberRange.new(0.2, 0.8)
	tinyPullEmitter.Rate = 90
	tinyPullEmitter.Lifetime = NumberRange.new(0.2, 0.35)
	tinyPullEmitter.SpreadAngle = Vector2.new(180, 180)
	tinyPullEmitter.Acceleration = Vector3.new(0, -10, 0)
	tinyPullEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0)
	})
	tinyPullEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	tinyPullEmitter.Rotation = NumberRange.new(0, 360)
	tinyPullEmitter.RotSpeed = NumberRange.new(-200, 200)
	tinyPullEmitter.Parent = ball

	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 12
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Parent = ball

	playSFX("113806286169554", char)

	task.delay(1, function()
		if not char or not rootPart or not ball.Parent then return end

		------------------------------------------------
		-- FIXED GROUND EXPLOSION (RELIABLE)
		------------------------------------------------
		local forward = rootPart.CFrame.LookVector

		local origin = rootPart.Position + forward * 10 + Vector3.new(0, 20, 0)
		local rayDir = Vector3.new(0, -80, 0)

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {char}
		params.FilterType = Enum.RaycastFilterType.Blacklist

		local result = workspace:Raycast(origin, rayDir, params)

		local pos
		local color = Color3.fromRGB(255, 255, 255)
		local material = Enum.Material.Plastic

		if result then
			pos = result.Position
			color = result.Instance.Color
			material = result.Instance.Material
		else
			pos = rootPart.Position + forward * 10
		end

		for i = 1, 12 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(2, 2, 2)
			p.Color = color
			p.Material = material
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true

			p.Position = pos + forward * 2 + Vector3.new(
				math.random(-1, 1) * 0.5,
				0.5,
				math.random(-1, 1) * 0.5
			)

			p.Parent = workspace

			p.AssemblyLinearVelocity =
				(forward * 35) +
				Vector3.new(
					math.random(-6, 6),
					math.random(45, 80),
					math.random(-6, 6)
				)

			p.AssemblyAngularVelocity = Vector3.new(
				math.random(-10, 10),
				math.random(-10, 10),
				math.random(-10, 10)
			)

			Debris:AddItem(p, 1.5)
		end

		------------------------------------------------

		weld:Destroy()
		ball.Anchored = true

		local startPos = ball.Position
		local forwardDirection = rootPart.CFrame.LookVector
		local endPos = startPos + forwardDirection * 600

		local tween = TweenService:Create(ball, TweenInfo.new(1), {
			Position = endPos
		})

		tween:Play()

		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not ball or not ball.Parent then
				conn:Disconnect()
				return
			end

			local pos = ball.Position
			local parts = getNearbyUnanchoredParts(pos, FLING_RADIUS, char)

			for _, p in ipairs(parts) do
				local dir = (p.Position - pos)
				if dir.Magnitude > 0 then
					local bv = Instance.new("BodyVelocity")
					bv.MaxForce = Vector3.new(400000, 400000, 400000)
					bv.Velocity = dir.Unit * FLING_VELOCITY
					bv.Parent = p
					Debris:AddItem(bv, 0.1)
				end
			end
		end)

		tween.Completed:Wait()
		conn:Disconnect()
		ball:Destroy()
	end)
end

------------------------------------------------
-- INPUT
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
