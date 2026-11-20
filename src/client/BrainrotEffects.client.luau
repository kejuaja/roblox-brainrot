-- BrainrotEffects: client-only animation and eye candy.
--   * Walk: field brainrots follow the server's walk legs (WalkFrom/WalkTo/WalkStart/WalkDuration) with a
--     waddle (side-to-side roll + little hops); when idle they bob and look around.
--   * Idle: brainrots standing in a base bob in place.
--   * Attack: on the Combat remote the attacking brainrot lunges at the bandit, a glowing projectile
--     (milk splash / egg / hay) flies across and a floating damage number pops up.
--   * Rainbow mutations and rainbow labels cycle through the hues.
--   * On placed brainrots the owner sees "Sell" and "Pick Up", everyone else only "Steal!" (hidden while locked).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Combat = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat") :: RemoteEvent

local player = Players.LocalPlayer

local placedPivots = {} -- [Model] = CFrame the server placed it at
local phases = {} -- [Model] = random animation offset
local lunges = {} -- [Model] = { start, direction }

local LUNGE_TIME = 0.35
local LUNGE_DISTANCE = 2.2

local function trackPlaced(model: Instance)
	if model:IsA("Model") then
		placedPivots[model] = model:GetPivot()
		phases[model] = math.random() * math.pi * 2
	end
end

local function trackField(model: Instance)
	if model:IsA("Model") then
		phases[model] = math.random() * math.pi * 2
	end
end

local function untrack(model: Instance)
	placedPivots[model] = nil
	phases[model] = nil
	lunges[model] = nil
end

for _, model in CollectionService:GetTagged("PlacedBrainrot") do
	trackPlaced(model)
end
for _, model in CollectionService:GetTagged("FieldBrainrot") do
	trackField(model)
end
CollectionService:GetInstanceAddedSignal("PlacedBrainrot"):Connect(function(model)
	-- Wait a frame so the server-set pivot has arrived before it is remembered.
	task.defer(trackPlaced, model)
end)
CollectionService:GetInstanceAddedSignal("FieldBrainrot"):Connect(trackField)
CollectionService:GetInstanceRemovedSignal("PlacedBrainrot"):Connect(untrack)
CollectionService:GetInstanceRemovedSignal("FieldBrainrot"):Connect(untrack)

-- Offset of an attack lunge: out towards the target and back.
local function lungeOffset(model: Model, t: number): Vector3
	local lunge = lunges[model]
	if not lunge then
		return Vector3.zero
	end
	local alpha = (t - lunge.start) / LUNGE_TIME
	if alpha >= 1 then
		lunges[model] = nil
		return Vector3.zero
	end
	return lunge.direction * math.sin(alpha * math.pi) * LUNGE_DISTANCE
end

local function animateField(model: Model, t: number, serverNow: number)
	local from = model:GetAttribute("WalkFrom")
	local to = model:GetAttribute("WalkTo")
	local start = model:GetAttribute("WalkStart") or 0
	local duration = model:GetAttribute("WalkDuration") or 0
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local phase = phases[model] or 0
	local alpha = if duration > 0 then math.clamp((serverNow - start) / duration, 0, 1) else 1
	local position = from:Lerp(to, alpha)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local base
	if flat.Magnitude > 0.05 then
		base = CFrame.lookAt(position, position + flat.Unit)
	else
		base = CFrame.new(position) * CFrame.Angles(0, tonumber(model:GetAttribute("Yaw")) or 0, 0)
	end
	if alpha < 1 then
		-- Walking: waddle from side to side with a hop on every step.
		local step = t * 9 + phase
		local hop = math.abs(math.sin(step)) * 0.6
		model:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, math.sin(step) * math.rad(10)))
	else
		-- Idle: gentle bob and a slow look around.
		local bob = math.sin(t * 2.2 + phase) * 0.25 + 0.25
		model:PivotTo(base * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 0.7 + phase) * math.rad(25), 0))
	end
end

local function animatePlaced(model: Model, pivot: CFrame, t: number)
	local phase = phases[model] or 0
	local bob = math.sin(t * 2.2 + phase) * 0.2 + 0.2
	local rock = math.sin(t * 4.4 + phase) * math.rad(3)
	-- The lunge is a world-space shove towards the bandit, added on top of the idle bob and rock.
	model:PivotTo(pivot * CFrame.new(0, bob, 0) * CFrame.Angles(rock, 0, 0) + lungeOffset(model, t))
end

local function filterPrompts()
	for _, model in CollectionService:GetTagged("PlacedBrainrot") do
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		local locked = model:GetAttribute("Locked") == true
		local root = model.PrimaryPart
		if root then
			local sell = root:FindFirstChild("SellPrompt")
			local steal = root:FindFirstChild("StealPrompt")
			local pickUp = root:FindFirstChild("PickUpPrompt")
			if sell then
				sell.Enabled = mine
			end
			if pickUp then
				pickUp.Enabled = mine
			end
			if steal then
				steal.Enabled = not mine and not locked
			end
		end
	end
end

local function damageNumber(position: Vector3, amount: number, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random() * 2 - 1, 3, math.random() * 2 - 1))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 48)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "-" .. tostring(amount)
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local function projectile(from: Vector3, to: Vector3, color: Color3, onHit: () -> ())
	local shot = Instance.new("Part")
	shot.Shape = Enum.PartType.Ball
	shot.Size = Vector3.one * 0.9
	shot.Color = color
	shot.Material = Enum.Material.Neon
	shot.Anchored = true
	shot.CanCollide = false
	shot.CanQuery = false
	shot.CanTouch = false
	shot.CFrame = CFrame.new(from + Vector3.new(0, 1.5, 0))
	shot.Parent = workspace
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = shot
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = shot
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.2
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = shot
	local travel = math.clamp((to - from).Magnitude / 80, 0.12, 0.4)
	local tween = TweenService:Create(shot, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) })
	tween.Completed:Connect(function()
		shot:Destroy()
		onHit()
	end)
	tween:Play()
end

Combat.OnClientEvent:Connect(function(attacker, from, to, amount, color)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(amount) ~= "number" then
		return
	end
	local tint = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
	if typeof(attacker) == "Instance" and attacker:IsA("Model") and placedPivots[attacker] then
		local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		lunges[attacker] = { start = os.clock(), direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero }
		projectile(from, to, tint, function()
			damageNumber(to, amount, tint)
		end)
	else
		damageNumber(to, amount, tint) -- a player's BONK lands instantly
	end
end)

local sincePromptFilter = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local serverNow = workspace:GetServerTimeNow()

	local hue = (t * 0.35) % 1
	for _, part in CollectionService:GetTagged("RainbowPart") do
		if part:IsA("BasePart") then
			part.Color = Color3.fromHSV(hue, 0.85, 1)
		end
	end
	for _, text in CollectionService:GetTagged("RainbowText") do
		if text:IsA("TextLabel") then
			text.TextColor3 = Color3.fromHSV((hue + 0.5) % 1, 0.6, 1)
		end
	end

	for _, model in CollectionService:GetTagged("FieldBrainrot") do
		if model:IsA("Model") and model.Parent then
			animateField(model, t, serverNow)
		end
	end
	for model, pivot in placedPivots do
		if model.Parent then
			animatePlaced(model, pivot, t)
		else
			untrack(model)
		end
	end

	sincePromptFilter += dt
	if sincePromptFilter > 0.25 then
		sincePromptFilter = 0
		filterPrompts()
	end
end)
