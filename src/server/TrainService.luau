-- TrainService: the village railway. Lays one winding track across the field (ballast, sleepers, two steel
-- rails and railway crossing signs along RailPath), then every 45 seconds sends a steam train - locomotive
-- with a smoking stack plus two wagons - along it, alternating direction. Halfway it drops a cargo brainrot
-- beside the track that may carry the TRAIN GOD mutation (x2 ALL income of the base it ends up in).
-- Anyone standing on the rails when it passes is run over and drops what they carry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local RailPath = require(Shared:WaitForChild("RailPath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local BrainrotSpawner = require(script.Parent:WaitForChild("BrainrotSpawner"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local TrainService = {}

local CONFIG = GameConfig.TRAIN
local RAIL_GAUGE = 1.6 -- half the distance between the two rails
local RAIL_TOP = 0.85
local TRAIN_COLOR = Color3.fromRGB(255, 150, 30)
local WARN = Color3.fromRGB(255, 120, 80)
local BLACK = Color3.fromRGB(25, 25, 28)
local rng = Random.new()

local function part(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

local function block(parent, name, size, cframe, color, material)
	return part(parent, name, Enum.PartType.Block, size, cframe, color, material)
end

local function insideMap(position: Vector3): boolean
	return math.abs(position.X) < 119
end

-- A white X-shaped railway crossing sign on a post, beside the track.
local function crossbuck(parent: Instance, position: Vector3)
	block(parent, "SignPost", Vector3.new(0.4, 6, 0.4), CFrame.new(position + Vector3.new(0, 3, 0)), Color3.fromRGB(240, 240, 240))
	for _, angle in { 35, -35 } do
		block(parent, "Crossbuck", Vector3.new(4, 0.6, 0.15), CFrame.new(position + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, 0, math.rad(angle)), Color3.fromRGB(245, 245, 245))
	end
	local lamp = part(parent, "WarningLamp", Enum.PartType.Ball, Vector3.one * 0.7, CFrame.new(position + Vector3.new(0, 3.8, 0)), Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
	return lamp
end

local lamps = {}

function TrainService.buildTrack(parent: Instance)
	local track = Instance.new("Model")
	track.Name = "Railway"
	track.Parent = parent
	local points = RailPath.points
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if insideMap(a) and insideMap(b) then
			local length = (b - a).Magnitude
			local frame = CFrame.lookAt((a + b) / 2, b)
			block(track, "Ballast", Vector3.new(6, 0.3, length + 0.4), frame * CFrame.new(0, 0.15, 0), Color3.fromRGB(125, 120, 115), Enum.Material.Slate)
			for _, side in { -1, 1 } do
				block(track, "Rail", Vector3.new(0.3, 0.35, length + 0.15), frame * CFrame.new(side * RAIL_GAUGE, RAIL_TOP - 0.175, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
			end
		end
	end
	local d = 0
	while d <= RailPath.length do
		local position, direction = RailPath.at(d)
		if insideMap(position) then
			block(track, "Sleeper", Vector3.new(4.8, 0.3, 0.9), CFrame.lookAt(position, position + direction) * CFrame.new(0, 0.45, 0), Color3.fromRGB(105, 70, 45), Enum.Material.Wood)
		end
		d += 2.6
	end
	for _, fraction in { 0.3, 0.62 } do
		local position, direction = RailPath.at(RailPath.length * fraction)
		local right = direction:Cross(Vector3.yAxis)
		table.insert(lamps, crossbuck(track, position + right * 5))
	end
	track:SetAttribute("Length", RailPath.length)
	return track
end

--------------------------------------------------------------------------------------------------------
-- Rolling stock. Every car is built with its pivot on the rail top, centred, facing -Z (its front).
--------------------------------------------------------------------------------------------------------
local function weldAll(model: Model, root: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if p ~= root then
				p.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	root.Anchored = true
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new()
end

local function wheels(model: Model, zs: { number }, diameter: number, color: Color3)
	for _, z in zs do
		for _, side in { -1, 1 } do
			part(model, "Wheel", Enum.PartType.Cylinder, Vector3.new(0.5, diameter, diameter), CFrame.new(side * 2.0, diameter / 2, z), color, Enum.Material.Metal)
		end
	end
end

local function buildLocomotive(): (Model, number)
	local m = Instance.new("Model")
	m.Name = "SteamLocomotive"
	local root = block(m, "Chassis", Vector3.new(4.4, 0.8, 12), CFrame.new(0, 1.9, 0), BLACK, Enum.Material.Metal)
	wheels(m, { -3.6, 0, 3.6 }, 2.6, Color3.fromRGB(190, 35, 35))
	local alongZ = CFrame.Angles(0, math.rad(90), 0)
	local green = Color3.fromRGB(30, 85, 55)
	local brass = Color3.fromRGB(230, 180, 60)
	part(m, "Boiler", Enum.PartType.Cylinder, Vector3.new(7.6, 3.6, 3.6), CFrame.new(0, 4.1, -1.9) * alongZ, green, Enum.Material.Metal)
	for _, z in { -4.8, -1.9, 1.0 } do
		part(m, "BoilerBand", Enum.PartType.Cylinder, Vector3.new(0.3, 3.7, 3.7), CFrame.new(0, 4.1, z) * alongZ, brass, Enum.Material.Metal)
	end
	part(m, "SmokeBox", Enum.PartType.Cylinder, Vector3.new(0.6, 3.7, 3.7), CFrame.new(0, 4.1, -5.8) * alongZ, BLACK, Enum.Material.Metal)
	part(m, "Headlamp", Enum.PartType.Ball, Vector3.one * 1, CFrame.new(0, 5.0, -6.2), Color3.fromRGB(255, 240, 170), Enum.Material.Neon)
	local stack = part(m, "Smokestack", Enum.PartType.Cylinder, Vector3.new(2.4, 1.2, 1.2), CFrame.new(0, 7.0, -4.4) * CFrame.Angles(0, 0, math.rad(90)), BLACK, Enum.Material.Metal)
	part(m, "StackCap", Enum.PartType.Cylinder, Vector3.new(0.4, 1.8, 1.8), CFrame.new(0, 8.3, -4.4) * CFrame.Angles(0, 0, math.rad(90)), BLACK, Enum.Material.Metal)
	local dome = part(m, "SteamDome", Enum.PartType.Ball, Vector3.one * 1.4, CFrame.new(0, 6.0, -1.2), brass, Enum.Material.Foil)
	dome.Reflectance = 0.2
	block(m, "Cab", Vector3.new(4.4, 4.2, 3.6), CFrame.new(0, 4.4, 3.9), Color3.fromRGB(180, 35, 35), Enum.Material.Metal)
	block(m, "CabRoof", Vector3.new(4.9, 0.4, 4.2), CFrame.new(0, 6.7, 3.9), BLACK, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		block(m, "CabWindow", Vector3.new(0.1, 1.4, 1.6), CFrame.new(side * 2.22, 5.2, 3.9), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
	end
	block(m, "Cowcatcher", Vector3.new(4.2, 1.0, 1.2), CFrame.new(0, 1.2, -6.4) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(190, 35, 35), Enum.Material.DiamondPlate)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 30
	smoke.Lifetime = NumberRange.new(2, 3.2)
	smoke.Speed = NumberRange.new(6, 10)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.EmissionDirection = Enum.NormalId.Right -- the stack is rolled 90 degrees, so its +X points up
	smoke.Size = NumberSequence.new(1.5, 5)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(230, 230, 235), Color3.fromRGB(120, 120, 125))
	smoke.Parent = stack
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "🚂 TRAIN GOD EXPRESS"
	label.TextColor3 = TRAIN_COLOR
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = root
	weldAll(m, root)
	return m, 13
end

local function buildWagon(kind: string): (Model, number)
	local m = Instance.new("Model")
	m.Name = "Wagon"
	local root = block(m, "Chassis", Vector3.new(4.4, 0.6, 10), CFrame.new(0, 1.8, 0), BLACK, Enum.Material.Metal)
	wheels(m, { -3.2, 3.2 }, 2.0, Color3.fromRGB(60, 60, 65))
	if kind == "box" then
		local box = block(m, "BoxCar", Vector3.new(4.4, 4, 9.6), CFrame.new(0, 4.1, 0), Color3.fromRGB(235, 185, 50), Enum.Material.WoodPlanks)
		block(m, "BoxRoof", Vector3.new(4.8, 0.3, 10), CFrame.new(0, 6.25, 0), Color3.fromRGB(120, 60, 40), Enum.Material.Metal)
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local sign = Instance.new("SurfaceGui")
			sign.Face = face
			sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sign.PixelsPerStud = 30
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.FredokaOne
			text.Text = "TRAIN GOD CARGO"
			text.TextColor3 = Color3.fromRGB(120, 40, 20)
			text.TextScaled = true
			text.Parent = sign
			sign.Parent = box
		end
	else
		block(m, "Flatbed", Vector3.new(4.4, 0.4, 9.6), CFrame.new(0, 2.3, 0), Color3.fromRGB(110, 70, 45), Enum.Material.WoodPlanks)
		for i, z in { -3, 0, 3 } do
			block(m, "HayBale", Vector3.new(3, 1.8, 2.4), CFrame.new(0, 3.4 + (if i == 2 then 1.8 else 0), z), Color3.fromRGB(235, 200, 95), Enum.Material.Fabric)
		end
		for _, side in { -1, 1 } do
			part(m, "MilkCan", Enum.PartType.Cylinder, Vector3.new(1.8, 1.1, 1.1), CFrame.new(side * 1.6, 3.4, 4.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
		end
	end
	weldAll(m, root)
	return m, 10
end

--------------------------------------------------------------------------------------------------------
-- A run along the track
--------------------------------------------------------------------------------------------------------
local function runOver(cars)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			for _, car in cars do
				local rel = car.cframe:PointToObjectSpace(root.Position)
				if math.abs(rel.X) < 3 and math.abs(rel.Z) < car.length / 2 and rel.Y > -2 and rel.Y < 8 then
					local state = PlayerState.get(player)
					local lost = if state then CarryService.clear(state) else 0
					humanoid.Health = 0
					Remotes.notify(player, "🚂 Run over by the steam train!" .. (if lost > 0 then " You dropped " .. lost .. " brainrots!" else ""), WARN)
					break
				end
			end
		end
	end
end

local function dropCargo(distance: number)
	local position, direction = RailPath.at(distance)
	local right = direction:Cross(Vector3.yAxis)
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local spot = position + right * side * 7
	spot = Vector3.new(math.clamp(spot.X, -GameConfig.FIELD_HALF_WIDTH, GameConfig.FIELD_HALF_WIDTH), 0.2, spot.Z)
	local def = Catalog.rollCharacter(CONFIG.cargoLuck, 2)
	local mutation = if rng:NextNumber() < CONFIG.trainGodChance then "TrainGod" else Catalog.rollMutation(2).key
	BrainrotSpawner.spawn(spot, def.id, mutation)
	local rarity = Catalog.rarityOf(def.id)
	if mutation == "TrainGod" then
		Remotes.announce("🚂✨ The train dropped a TRAIN GOD " .. def.name .. "! It doubles ALL income of the base that holds it!", TRAIN_COLOR)
	else
		Remotes.announce("🚂 The train dropped a " .. rarity.key .. " " .. Catalog.displayName(def.id, mutation) .. " by the tracks!", rarity.color)
	end
end

function TrainService.run(parent: Instance, reverse: boolean)
	local cars = {}
	local loco, locoLength = buildLocomotive()
	local boxCar, boxLength = buildWagon("box")
	local flatCar, flatLength = buildWagon("flat")
	local offset = 0
	for _, entry in { { loco, locoLength }, { boxCar, boxLength }, { flatCar, flatLength } } do
		local model, length = entry[1], entry[2]
		table.insert(cars, { model = model, length = length, offset = offset + length / 2, cframe = CFrame.new() })
		offset += length + 1.2
		model.Parent = parent
	end
	local trainLength = offset
	local total = RailPath.length + trainLength
	local dropAt = RailPath.length * rng:NextNumber(0.3, 0.7)
	local dropped = false
	workspace:SetAttribute("TrainRunning", true)

	local front = 0
	while front < total do
		local dt = RunService.Heartbeat:Wait()
		front += CONFIG.speed * dt
		for _, car in cars do
			local along = front - car.offset
			local d = if reverse then RailPath.length - along else along
			local position, direction = RailPath.at(d)
			local heading = if reverse then -direction else direction
			car.cframe = CFrame.lookAt(position + Vector3.new(0, RAIL_TOP, 0), position + Vector3.new(0, RAIL_TOP, 0) + heading)
			car.model:PivotTo(car.cframe)
		end
		runOver(cars)
		if not dropped and front >= dropAt then
			dropped = true
			dropCargo(if reverse then RailPath.length - dropAt else dropAt)
		end
	end
	for _, car in cars do
		car.model:Destroy()
	end
	workspace:SetAttribute("TrainRunning", false)
end

function TrainService.start(world)
	TrainService.buildTrack(world.folder)
	task.spawn(function()
		task.wait(CONFIG.firstDelay)
		local reverse = false
		while true do
			Remotes.announce("🚂 STEAM TRAIN in " .. CONFIG.warning .. "s! Stay off the tracks - it may drop a TRAIN GOD!", TRAIN_COLOR)
			for _, lamp in lamps do
				lamp.Color = Color3.fromRGB(255, 40, 40)
			end
			task.wait(CONFIG.warning)
			task.spawn(function()
				local ok, err = pcall(TrainService.run, world.folder, reverse)
				if not ok then
					warn("[TrainService]", err)
					workspace:SetAttribute("TrainRunning", false)
				end
				for _, lamp in lamps do
					lamp.Color = Color3.fromRGB(90, 30, 30)
				end
			end)
			reverse = not reverse
			task.wait(CONFIG.interval - CONFIG.warning)
		end
	end)
end

return TrainService
