-- DisasterFx: draws the farm disasters on this client from the shared DisasterPath functions, so they move
-- perfectly smoothly and exactly where the server checks for hits.
--   FARM TORNADO        a swirling funnel of dust under a dark storm cloud, orbiting hay bales, planks and
--                       fence posts, a dust skirt at its foot; it forms during the warning and fizzles out at
--                       the base ramp. Within its pull radius an unsheltered player gets dragged towards it.
--   WILD BULL STAMPEDE  a herd of dark bulls with glowing red eyes, gold nose rings and horns, galloping with
--                       swinging legs and dust clouds; the ground shakes when they are near.
-- It also plays the server's Fling: the character is knocked down and thrown with the given velocity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DisasterPath = require(Shared:WaitForChild("DisasterPath"))
local Fling = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fling") :: RemoteEvent

local player = Players.LocalPlayer
local CONFIG = GameConfig.DISASTER
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "DisasterFx"
folder.Parent = workspace

local function newPart(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

---------------------------------------------------------------------------------------------------------------
-- The tornado
---------------------------------------------------------------------------------------------------------------
local LAYERS = 10
local tornado = nil

local function buildTornado()
	local model = Instance.new("Model")
	model.Name = "FarmTornado"
	local layers = {}
	for k = 0, LAYERS - 1 do
		local shade = Color3.fromRGB(95, 85, 78):Lerp(Color3.fromRGB(150, 145, 155), k / (LAYERS - 1))
		local layer = newPart(model, Vector3.new(7, 6, 6), shade, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		layer.Transparency = 0.32 + k * 0.025
		layers[k] = layer
	end
	local swirl = newPart(model, Vector3.new(24, 56, 24), Color3.new(1, 1, 1))
	swirl.Transparency = 1
	emitter(swirl, {
		Rate = 70,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1, 3),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		LockedToPart = true,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		RotSpeed = NumberRange.new(-90, 90),
		Color = ColorSequence.new(Color3.fromRGB(120, 105, 90), Color3.fromRGB(170, 165, 170)),
	})
	emitter(swirl, {
		Rate = 25,
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(4, 8),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		LockedToPart = true,
		Size = NumberSequence.new(0.4, 0.2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		Color = ColorSequence.new(Color3.fromRGB(240, 205, 100)),
		Squash = NumberSequence.new(-2),
	})
	local foot = newPart(model, Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
	foot.Transparency = 1
	emitter(foot, {
		Rate = 40,
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 10),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 6, 0),
		Drag = 2,
		Size = NumberSequence.new(3, 8),
		Transparency = NumberSequence.new(0.4, 1),
		Color = ColorSequence.new(Color3.fromRGB(150, 120, 85)),
	})
	local clouds = {}
	for i = 1, 3 do
		local cloud = newPart(model, Vector3.new(80, 18, 80), Color3.fromRGB(70, 68, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		cloud.Transparency = 0.15
		clouds[i] = cloud
	end
	local debris = {}
	local kinds = {
		{ size = Vector3.new(3, 2, 2.2), color = Color3.fromRGB(235, 200, 95), material = Enum.Material.Fabric },
		{ size = Vector3.new(0.4, 0.8, 5), color = Color3.fromRGB(150, 100, 60), material = Enum.Material.WoodPlanks },
		{ size = Vector3.new(0.7, 4, 0.7), color = Color3.fromRGB(105, 68, 40), material = Enum.Material.Wood },
		{ size = Vector3.new(1.4, 1.4, 1.4), color = Color3.fromRGB(255, 130, 20), material = Enum.Material.SmoothPlastic },
	}
	for i = 1, 16 do
		local kind = kinds[(i - 1) % #kinds + 1]
		local piece = newPart(model, kind.size, kind.color, kind.material, if i % #kinds == 0 then Enum.PartType.Ball else nil)
		debris[i] = {
			part = piece,
			radius = rng:NextNumber(9, 24),
			height = rng:NextNumber(4, 48),
			speed = rng:NextNumber(2, 4),
			phase = rng:NextNumber(0, math.pi * 2),
			tumble = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4)),
		}
	end
	model.Parent = folder
	return { model = model, layers = layers, swirl = swirl, foot = foot, clouds = clouds, debris = debris }
end

local function drawTornado(center: Vector3, grow: number, t: number)
	tornado = tornado or buildTornado()
	local s = math.max(0.05, grow)
	for k = 0, LAYERS - 1 do
		local diameter = (5 + 0.45 * k * k + 2.2 * k) * s
		local height = 6.6 * s
		local wobble = Vector3.new(math.sin(t * 2.1 + k * 0.6), 0, math.cos(t * 1.7 + k * 0.5)) * k * 0.7 * s
		local y = (1 + k * 6.2) * s + height / 2
		tornado.layers[k].Size = Vector3.new(height, diameter, diameter)
		tornado.layers[k].CFrame = CFrame.new(center + wobble + Vector3.new(0, y, 0)) * CFrame.Angles(0, t * (4 - k * 0.25), 0) * UPRIGHT
	end
	tornado.swirl.Size = Vector3.new(26, 60, 26) * s
	tornado.swirl.CFrame = CFrame.new(center + Vector3.new(0, 30 * s, 0)) * CFrame.Angles(0, t * 5, 0)
	tornado.foot.CFrame = CFrame.new(center + Vector3.new(0, 1, 0))
	for i, cloud in tornado.clouds do
		local angle = t * 0.3 + i * 2.1
		cloud.Size = Vector3.new(70 + i * 12, 16, 70 + i * 12) * math.max(s, 0.3)
		cloud.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 10, 64 * s + 6 + i * 3, math.sin(angle) * 10))
	end
	for _, item in tornado.debris do
		local angle = item.phase + t * item.speed
		local r = item.radius * s * (0.6 + 0.4 * item.height / 48)
		local p = center + Vector3.new(math.cos(angle) * r, item.height * s + math.sin(t * 2 + item.phase) * 2, math.sin(angle) * r)
		item.part.CFrame = CFrame.new(p) * CFrame.Angles(item.tumble.X * t, item.tumble.Y * t, item.tumble.Z * t)
	end
end

local function hideTornado()
	if tornado then
		tornado.model:Destroy()
		tornado = nil
	end
end

---------------------------------------------------------------------------------------------------------------
-- The bull herd
---------------------------------------------------------------------------------------------------------------
local bulls = nil
local BULL_SCALE = 1.25

local function buildBull()
	local model = Instance.new("Model")
	model.Name = "WildBull"
	local hide = Color3.fromRGB(62, 36, 24)
	local k = BULL_SCALE
	local pieces = {}
	local function add(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, swing: number?)
		local p = newPart(model, size * k, color, material, shape)
		table.insert(pieces, { part = p, offset = CFrame.new(offset.Position * k) * offset.Rotation, swing = swing })
		return p
	end
	add(Vector3.new(4, 3.6, 7.4), CFrame.new(0, 4.3, 0), hide)
	add(Vector3.new(3.6, 1.6, 3), CFrame.new(0, 6.3, -1.6), hide)
	add(Vector3.new(2.6, 2.6, 3), CFrame.new(0, 5.1, -4.7), hide)
	add(Vector3.new(2.2, 1.6, 1.1), CFrame.new(0, 4.4, -6.5), Color3.fromRGB(150, 105, 85))
	add(Vector3.new(0.25, 1, 1), CFrame.new(0, 3.75, -7.1) * UPRIGHT, Color3.fromRGB(255, 200, 40), Enum.Material.Foil, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		add(Vector3.new(0.6, 0.5, 0.2), CFrame.new(side * 0.75, 5.7, -6.23), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
		add(Vector3.new(2.4, 0.5, 0.5), CFrame.new(side * 1.9, 6.4, -4.9) * CFrame.Angles(0, 0, side * math.rad(-28)), Color3.fromRGB(240, 230, 200))
		add(Vector3.new(0.4, 1, 0.4), CFrame.new(side * 3.05, 7.2, -4.9), Color3.fromRGB(240, 230, 200))
		add(Vector3.new(0.4, 1, 1), CFrame.new(side * 1.5, 5.8, -3.6), hide)
	end
	add(Vector3.new(0.3, 2.6, 0.3), CFrame.new(0, 4.6, 3.9) * CFrame.Angles(math.rad(25), 0, 0), hide)
	for _, spec in { { x = -1.3, z = -2.6, swing = 1 }, { x = 1.3, z = -2.6, swing = -1 }, { x = -1.3, z = 2.6, swing = -1 }, { x = 1.3, z = 2.6, swing = 1 } } do
		add(Vector3.new(1, 3, 1), CFrame.new(spec.x, 1.6, spec.z), hide, nil, nil, spec.swing)
		add(Vector3.new(1.05, 0.5, 1.05), CFrame.new(spec.x, 0.25, spec.z), Color3.fromRGB(30, 25, 25), nil, nil, spec.swing)
	end
	local dust = newPart(model, Vector3.one, Color3.new(1, 1, 1))
	dust.Transparency = 1
	emitter(dust, {
		Rate = 14,
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 1.5,
		Size = NumberSequence.new(2.5, 7),
		Transparency = NumberSequence.new(0.35, 1),
		Color = ColorSequence.new(Color3.fromRGB(175, 140, 100)),
	})
	model.Parent = folder
	return { model = model, pieces = pieces, dust = dust, phase = rng:NextNumber(0, math.pi * 2) }
end

local function drawBulls(list, t: number, running: boolean)
	if not bulls then
		bulls = {}
		for i = 1, #list do
			bulls[i] = buildBull()
		end
	end
	local parts, frames = {}, {}
	for i, info in list do
		local bull = bulls[i]
		if bull then
			if info.visible then
				if bull.model.Parent ~= folder then
					bull.model.Parent = folder
				end
				local phase = bull.phase + t * (if running then 9 else 2)
				local bob = if running then math.abs(math.sin(phase)) * 0.7 else 0
				local heading = Vector3.new(info.heading.X, 0, info.heading.Z)
				local root = CFrame.lookAt(info.position, info.position + (if heading.Magnitude > 0.01 then heading else Vector3.new(0, 0, -1))) * CFrame.new(0, bob, 0)
				if running then
					root *= CFrame.Angles(math.sin(phase) * 0.06, 0, 0)
				end
				for _, piece in bull.pieces do
					local cf
					if piece.swing then
						-- Legs (and hooves) swing around the hip at the top of the leg.
						local hipY = 3.1 * BULL_SCALE
						local hip = CFrame.new(piece.offset.Position.X, hipY, piece.offset.Position.Z)
						local swing = if running then math.sin(phase) * 0.75 * piece.swing else math.sin(phase) * 0.15 * piece.swing
						cf = root * hip * CFrame.Angles(swing, 0, 0) * CFrame.new(0, piece.offset.Position.Y - hipY, 0)
					else
						cf = root * piece.offset
					end
					table.insert(parts, piece.part)
					table.insert(frames, cf)
				end
				bull.dust.CFrame = root
			elseif bull.model.Parent then
				bull.model.Parent = nil
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function hideBulls()
	if bulls then
		for _, bull in bulls do
			bull.model:Destroy()
		end
		bulls = nil
	end
end

---------------------------------------------------------------------------------------------------------------
-- Getting thrown, being dragged, the ground shaking
---------------------------------------------------------------------------------------------------------------
local shakeUntil, shakeStrength = 0, 0
local shaking = false

Fling.OnClientEvent:Connect(function(velocity, kind)
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = velocity
	if kind == "Tornado" then
		root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(8, 14), rng:NextNumber(-6, 6))
	end
	shakeUntil, shakeStrength = os.clock() + 0.6, 0.6
	task.delay(1.6, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

local function localRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local phase = workspace:GetAttribute("DisasterPhase")
	local kind = workspace:GetAttribute("DisasterKind")
	local seed = workspace:GetAttribute("DisasterSeed") or 1
	local speed = workspace:GetAttribute("DisasterSpeed") or 30
	local start = workspace:GetAttribute("DisasterStart") or now
	local t = now - start
	local root = localRoot()
	local nearest = math.huge

	if (phase == "warning" or phase == "active") and kind == "Tornado" then
		local duration = DisasterPath.duration("Tornado", seed, speed)
		local grow = if t < 0 then math.clamp(1 + t / CONFIG.warning, 0.1, 1) else math.clamp((duration - t) / 1.5, 0, 1)
		local center = DisasterPath.tornado(seed, speed, math.max(t, 0))
		drawTornado(center, grow, now)
		if root and phase == "active" and not DisasterPath.isSafe(root.Position) then
			local offset = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
			local distance = offset.Magnitude
			nearest = distance
			local cfg = CONFIG.Tornado
			if distance < cfg.pullRadius and distance > 2 then
				local pull = cfg.pullStrength * (1 - distance / cfg.pullRadius)
				root.AssemblyLinearVelocity += offset.Unit * pull * dt * 8
			end
		end
	else
		hideTornado()
	end

	if (phase == "warning" or phase == "active") and kind == "Stampede" then
		local list = DisasterPath.bulls(seed, speed, math.max(t, 0))
		drawBulls(list, now, t >= 0)
		if root and t >= 0 then
			for _, bull in list do
				if bull.visible then
					nearest = math.min(nearest, (bull.position - root.Position).Magnitude)
				end
			end
		end
	else
		hideBulls()
	end

	-- The ground rumbles as a disaster closes in; a fling adds a big jolt.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local rumble = if nearest < 60 then (1 - nearest / 60) * 0.35 else 0
		local jolt = if os.clock() < shakeUntil then shakeStrength else 0
		local strength = math.max(rumble, jolt)
		if strength > 0.01 then
			shaking = true
			humanoid.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * strength
		elseif shaking then
			shaking = false
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)
