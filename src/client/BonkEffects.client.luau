-- BonkEffects: the comic hit effect when a weapon (or a bare-hand BONK) lands on a Brainrot Bandit.
--   * a big tilted word ("BONK!", "POKE!", "PUFF!", "THWACK!", "SLASH!", "CRIT!") pops up and floats away
--   * a burst of stars in the weapon's colour, plus diesel smoke (Exhaust Pipe) or milk splash (Churn Hammer)
--   * a bonk sound, and a short camera shake for the player who landed the hit (stronger on the boss)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bonk = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Bonk") :: RemoteEvent

local player = Players.LocalPlayer
local rng = Random.new()

local function anchorAt(position: Vector3): Part
	local anchor = Instance.new("Part")
	anchor.Name = "BonkFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	return anchor
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function word(anchor: Part, text: string, color: Color3, big: boolean)
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromOffset(300, 120) else UDim2.fromOffset(210, 84)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Rotation = rng:NextNumber(-16, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = Color3.fromRGB(20, 10, 30)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	task.delay(0.16, function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	task.delay(0.35, function()
		local info = TweenInfo.new(0.45)
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(anchor, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }):Play()
	end)
end

local function shakeCamera(strength: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			local fade = 1 - (os.clock() - start) / duration
			humanoid.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * strength * fade
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

Bonk.OnClientEvent:Connect(function(position, color, text, hitter, flags)
	if typeof(position) ~= "Vector3" then
		return
	end
	local tint = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 220, 80)
	local options = if type(flags) == "table" then flags else {}
	local crit = options.crit == true
	local boss = options.boss == true
	local small = options.small == true
	local anchor = anchorAt(position)

	word(anchor, if type(text) == "string" then text else "BONK!", if crit then Color3.fromRGB(255, 235, 80) else tint, crit or boss or not small)

	-- Stars flying out of the impact.
	local stars = emitter(anchor, {
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1,
		Drag = 4,
		Color = ColorSequence.new(tint, Color3.new(1, 1, 1)),
	})
	stars:Emit(if crit then 40 elseif small then 10 else 22)
	-- A quick flash ring.
	local ring = emitter(anchor, {
		Lifetime = NumberRange.new(0.18),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, if boss then 9 else 6) }),
		Transparency = NumberSequence.new(0.2, 1),
		LightEmission = 1,
		Color = ColorSequence.new(tint),
	})
	ring:Emit(1)
	if options.smoke then
		emitter(anchor, {
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(3, 7),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(1.5, 5),
			Transparency = NumberSequence.new(0.3, 1),
			Drag = 2,
			RotSpeed = NumberRange.new(-60, 60),
			Color = ColorSequence.new(Color3.fromRGB(55, 55, 60), Color3.fromRGB(150, 150, 155)),
		}):Emit(16)
	end
	if options.milk then
		emitter(anchor, {
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(12, 20),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -50, 0),
			Size = NumberSequence.new(0.6, 0.2),
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
		}):Emit(30)
	end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/swordlunge.wav"
	sound.Volume = if small then 0.5 else 0.8
	sound.PlaybackSpeed = (if boss then 0.7 else 1) * rng:NextNumber(0.9, 1.15)
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()

	if hitter == player then
		shakeCamera(if crit or boss then 0.5 else 0.25, if small then 0.12 else 0.2)
	end
	Debris:AddItem(anchor, 2)
end)
