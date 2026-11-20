-- WorldBuilder: builds the 3D map when the server starts - the high base plateau ("Markas") with six
-- player plots (slot pads, COLLECT pad, LOCK pad, owner sign, lock barrier), the ramp down into the
-- four-zone brainrot field, the safe hills, the title sign, trees, boundary walls and the lighting.
-- (The village west of the plateau is VillageBuilder's job; the walls here leave room for it.)
-- Returns the layout the other services use: plots (with their slot CFrames) and hills.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RailPath = require(Shared:WaitForChild("RailPath"))

local WorldBuilder = {}

local FONT = Enum.Font.FredokaOne
local TOP = GameConfig.PLATEAU_TOP
local PLOT_LABEL_DISTANCE = GameConfig.PLOT_LABEL_DISTANCE
local PLOT_COLORS = {
	Color3.fromRGB(255, 105, 180),
	Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(120, 230, 80),
	Color3.fromRGB(255, 160, 40),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 225, 60),
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.Font = FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = target
	return label
end

local function billboard(adornee: BasePart, text: string, color: Color3, offset: Vector3, size: UDim2, maxDistance: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = adornee
	return label
end

-- A flat slab whose top runs straight from `low` to `high` (both points on its top surface).
local function ramp(parent: Instance, name: string, low: Vector3, high: Vector3, width: number, color: Color3, material: Enum.Material)
	local length = (high - low).Magnitude
	local frame = CFrame.lookAt((low + high) / 2, high)
	local slab = part(parent, name, Vector3.new(width, 1, length), frame * CFrame.new(0, -0.5, 0), color, material)
	return slab
end

local WOOD = Color3.fromRGB(150, 100, 60)
local DARK_WOOD = Color3.fromRGB(105, 68, 40)
local LEAF_GREENS = { Color3.fromRGB(55, 160, 65), Color3.fromRGB(75, 185, 70), Color3.fromRGB(45, 135, 60), Color3.fromRGB(95, 195, 85) }
local decorRng = Random.new(20261120) -- fixed seed: the same scenery every server

-- A lush tree: a thick trunk under a cluster of overlapping leaf balls in several greens.
local function lushTree(parent: Instance, position: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local trunkHeight = 9 * scale
	part(model, "Trunk", Vector3.new(trunkHeight, 2.2 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), DARK_WOOD, Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	local crown = position + Vector3.new(0, trunkHeight + 2 * scale, 0)
	local offsets = { Vector3.new(0, 1.5, 0), Vector3.new(2.6, 0, 0.8), Vector3.new(-2.4, 0.2, -1), Vector3.new(0.6, -0.4, 2.6), Vector3.new(-0.8, 0.4, -2.6), Vector3.new(0, 3.6, 0.3) }
	for i, offset in offsets do
		local size = (5.5 + decorRng:NextNumber(0, 2.5)) * scale
		local leaves = part(model, "Leaves", Vector3.one * size, CFrame.new(crown + offset * scale), LEAF_GREENS[(i - 1) % #LEAF_GREENS + 1], Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
		leaves.CanCollide = false
	end
end

local function bush(parent: Instance, position: Vector3)
	for i = 1, 3 do
		local size = 3 + decorRng:NextNumber(0, 1.5)
		local ball = part(parent, "Bush", Vector3.one * size, CFrame.new(position + Vector3.new((i - 2) * 1.8, size / 2 - 0.6, decorRng:NextNumber(-0.8, 0.8))), LEAF_GREENS[i], Enum.Material.Grass)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end
end

-- A wooden cabin: plank walls with a door and glowing windows, a pitched roof and a chimney.
-- yaw turns the cabin so its door faces the field.
local function woodenHouse(parent: Instance, position: Vector3, yaw: number)
	local model = Instance.new("Model")
	model.Name = "WoodenHouse"
	model.Parent = parent
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local w, d, h = 12, 11, 8
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	part(model, "Floor", Vector3.new(w + 1, 0.6, d + 1), at(0, 0.3, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	part(model, "BackWall", Vector3.new(w, h, 0.6), at(0, h / 2, d / 2), WOOD, Enum.Material.WoodPlanks)
	part(model, "LeftWall", Vector3.new(0.6, h, d), at(-w / 2, h / 2, 0), WOOD, Enum.Material.WoodPlanks)
	part(model, "RightWall", Vector3.new(0.6, h, d), at(w / 2, h / 2, 0), WOOD, Enum.Material.WoodPlanks)
	-- Front wall in three pieces around the door.
	part(model, "FrontLeft", Vector3.new(4.5, h, 0.6), at(-3.75, h / 2, -d / 2), WOOD, Enum.Material.WoodPlanks)
	part(model, "FrontRight", Vector3.new(4.5, h, 0.6), at(3.75, h / 2, -d / 2), WOOD, Enum.Material.WoodPlanks)
	part(model, "FrontTop", Vector3.new(3, h - 5.5, 0.6), at(0, 5.5 + (h - 5.5) / 2, -d / 2), WOOD, Enum.Material.WoodPlanks)
	part(model, "Door", Vector3.new(3, 5.5, 0.3), at(0, 2.75, -d / 2 - 0.1), Color3.fromRGB(120, 50, 35), Enum.Material.Wood)
	for _, x in { -3.75, 3.75 } do
		local window = part(model, "Window", Vector3.new(2, 2, 0.2), at(x, 4.6, -d / 2 - 0.35), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		window.Transparency = 0.15
		part(model, "WindowFrame", Vector3.new(2.6, 2.6, 0.15), at(x, 4.6, -d / 2 - 0.3), DARK_WOOD, Enum.Material.Wood)
	end
	-- Pitched roof: two planks leaning on each other along the house's width.
	local slope = math.rad(32)
	local halfSpan = w / 2 + 1
	local roofLength = halfSpan / math.cos(slope)
	for _, side in { -1, 1 } do
		part(model, "Roof", Vector3.new(roofLength, 0.7, d + 2), at(side * halfSpan / 2, h + math.tan(slope) * halfSpan / 2, 0) * CFrame.Angles(0, 0, side * -slope), Color3.fromRGB(170, 55, 45), Enum.Material.Slate)
	end
	part(model, "Chimney", Vector3.new(1.6, 4, 1.6), at(3, h + 3, 2), Color3.fromRGB(120, 110, 105), Enum.Material.Brick)
	return model
end

-- A wooden fence from a to b along the ground: posts every 6 studs joined by two rails.
local function fence(parent: Instance, a: Vector3, b: Vector3)
	local model = Instance.new("Model")
	model.Name = "Fence"
	model.Parent = parent
	local length = (b - a).Magnitude
	local posts = math.max(1, math.floor(length / 6))
	for i = 0, posts do
		local p = a:Lerp(b, i / posts)
		part(model, "Post", Vector3.new(0.7, 4, 0.7), CFrame.new(p + Vector3.new(0, 2, 0)), DARK_WOOD, Enum.Material.Wood)
	end
	local direction = CFrame.lookAt((a + b) / 2, b)
	for _, y in { 1.4, 3 } do
		part(model, "Rail", Vector3.new(0.35, 0.5, length), direction * CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
	end
end

-- A shallow creek across the field with arched wooden bridges over it.
local function creekWithBridges(parent: Instance, z: number, bridgeXs: { number })
	local width = 2 * GameConfig.FIELD_HALF_WIDTH + 20
	local water = part(parent, "Creek", Vector3.new(width, 0.3, 10), CFrame.new(0, 0.25, z), Color3.fromRGB(60, 150, 230), Enum.Material.Glass)
	water.Transparency = 0.15
	water.CanCollide = false
	for _, side in { -1, 1 } do
		part(parent, "CreekBank", Vector3.new(width, 0.4, 1.2), CFrame.new(0, 0.3, z + side * 5.4), Color3.fromRGB(150, 130, 95), Enum.Material.Sand)
	end
	for _, x in bridgeXs do
		local model = Instance.new("Model")
		model.Name = "Bridge"
		model.Parent = parent
		local rise = 2.2
		ramp(model, "BridgeRampNear", Vector3.new(x, 0.2, z - 12), Vector3.new(x, rise, z - 6), 10, WOOD, Enum.Material.WoodPlanks)
		ramp(model, "BridgeRampFar", Vector3.new(x, 0.2, z + 12), Vector3.new(x, rise, z + 6), 10, WOOD, Enum.Material.WoodPlanks)
		part(model, "BridgeDeck", Vector3.new(10, 0.8, 12), CFrame.new(x, rise - 0.4, z), WOOD, Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			fence(model, Vector3.new(x + side * 5, rise, z - 6), Vector3.new(x + side * 5, rise, z + 6))
		end
	end
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(90, 90, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(120, 140, 200)
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.2
	grade.Contrast = 0.08
	grade.Parent = Lighting
end

local function buildPlot(parent: Instance, index: number, cx: number)
	local color = PLOT_COLORS[index]
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = parent
	local minZ, maxZ = GameConfig.PLOT_MIN_Z, GameConfig.PLOT_MAX_Z
	local width = GameConfig.PLOT_WIDTH
	local zc = (minZ + maxZ) / 2

	part(model, "Floor", Vector3.new(width, 0.4, maxZ - minZ), CFrame.new(cx, TOP + 0.2, zc), color:Lerp(Color3.fromRGB(40, 40, 50), 0.55), Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		part(model, "Edge", Vector3.new(0.6, 0.6, maxZ - minZ), CFrame.new(cx + side * width / 2, TOP + 0.3, zc), color, Enum.Material.Neon)
	end

	local slotCFrames, slotPads = {}, {}
	for row, z in GameConfig.SLOT_Z do
		for col, dx in GameConfig.SLOT_X do
			local slot = (row - 1) * #GameConfig.SLOT_X + col
			local pad = GameConfig.SLOT_PAD_SIZE
			slotPads[slot] = part(model, "Slot" .. slot, Vector3.new(pad, 0.3, pad), CFrame.new(cx + dx, TOP + 0.5, z), color, Enum.Material.Neon)
			-- Brainrots stand on the pad facing the field (+Z), towards anyone walking up to the base.
			slotCFrames[slot] = CFrame.new(cx + dx, TOP + 0.65, z) * CFrame.Angles(0, math.pi, 0)
		end
	end

	local collectPad = part(model, "CollectPad", Vector3.new(10, 0.6, 7), CFrame.new(cx - 7, TOP + 0.6, -141), Color3.fromRGB(60, 230, 90), Enum.Material.Neon)
	surfaceText(collectPad, Enum.NormalId.Top, "COLLECT", Color3.new(1, 1, 1))
	-- Pad labels only show up close by, so the six plots' labels never pile up on screen.
	local vaultLabel = billboard(collectPad, "💰 $0", Color3.fromRGB(120, 255, 140), Vector3.new(0, 4, 0), UDim2.fromOffset(200, 50), PLOT_LABEL_DISTANCE)

	local lockPad = part(model, "LockPad", Vector3.new(10, 0.6, 7), CFrame.new(cx + 7, TOP + 0.6, -141), Color3.fromRGB(240, 70, 70), Enum.Material.Neon)
	surfaceText(lockPad, Enum.NormalId.Top, "LOCK", Color3.new(1, 1, 1))
	local lockLabel = billboard(lockPad, "🔓 LOCK BASE", Color3.fromRGB(255, 150, 150), Vector3.new(0, 4, 0), UDim2.fromOffset(200, 44), PLOT_LABEL_DISTANCE)

	local sign = part(model, "Sign", Vector3.new(26, 7, 1), CFrame.new(cx, TOP + 6.5, minZ + 1), Color3.fromRGB(30, 28, 45))
	for _, side in { -1, 1 } do
		part(model, "SignPost", Vector3.new(1, 6, 1), CFrame.new(cx + side * 11, TOP + 3, minZ + 1), Color3.fromRGB(30, 28, 45))
	end
	local signLabel = surfaceText(sign, Enum.NormalId.Back, "EMPTY BASE", color)

	local barrier = {}
	local function wall(size: Vector3, position: Vector3)
		local w = part(model, "LockWall", size, CFrame.new(position), Color3.fromRGB(255, 80, 80), Enum.Material.ForceField)
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Transparency = 1
		table.insert(barrier, w)
	end
	local h = 12
	wall(Vector3.new(width, h, 0.5), Vector3.new(cx, TOP + h / 2, maxZ))
	wall(Vector3.new(width, h, 0.5), Vector3.new(cx, TOP + h / 2, minZ))
	wall(Vector3.new(0.5, h, maxZ - minZ), Vector3.new(cx - width / 2, TOP + h / 2, zc))
	wall(Vector3.new(0.5, h, maxZ - minZ), Vector3.new(cx + width / 2, TOP + h / 2, zc))

	return {
		index = index,
		color = color,
		model = model,
		cx = cx,
		minX = cx - width / 2,
		maxX = cx + width / 2,
		minZ = minZ,
		maxZ = maxZ,
		slotCFrames = slotCFrames,
		slotPads = slotPads,
		collectPad = collectPad,
		vaultLabel = vaultLabel,
		lockPad = lockPad,
		lockLabel = lockLabel,
		signLabel = signLabel,
		barrier = barrier,
		spawnCFrame = CFrame.lookAt(Vector3.new(cx, TOP + 4, maxZ - 3), Vector3.new(cx, TOP + 4, maxZ + 20)),
		owner = nil,
	}
end

local function buildHill(parent: Instance, center: Vector3)
	local size, height = GameConfig.HILL_SIZE, GameConfig.HILL_HEIGHT
	local model = Instance.new("Model")
	model.Name = "SafeHill"
	model.Parent = parent
	part(model, "Rock", Vector3.new(size, height, size), CFrame.new(center.X, height / 2, center.Z), Color3.fromRGB(125, 110, 95), Enum.Material.Slate)
	local cap = part(model, "Grass", Vector3.new(size + 1, 1, size + 1), CFrame.new(center.X, height + 0.5, center.Z), Color3.fromRGB(90, 190, 80), Enum.Material.Grass)
	-- The ramp climbs from the far side, so a player running home from deeper in the field can dash up it.
	ramp(model, "HillRamp", Vector3.new(center.X, 0, center.Z + size / 2 + 26), Vector3.new(center.X, height + 1, center.Z + size / 2), 12, Color3.fromRGB(150, 130, 100), Enum.Material.WoodPlanks)
	billboard(cap, "⛰ SAFE HILL", Color3.fromRGB(150, 255, 160), Vector3.new(0, 6, 0), UDim2.fromOffset(180, 40), 220)
end

function WorldBuilder.build()
	buildLighting()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local fieldDepth = 420
	part(world, "Ground", Vector3.new(240, 4, fieldDepth), CFrame.new(0, -2, -80 + fieldDepth / 2), Color3.fromRGB(95, 170, 70), Enum.Material.Grass)

	-- Field zones: tinted strips, a glowing line at each border and a big sign facing the base.
	for index, zone in GameConfig.ZONES do
		local depth = zone.maxZ - zone.minZ
		part(world, "Zone" .. index, Vector3.new(2 * GameConfig.FIELD_HALF_WIDTH + 20, 0.2, depth), CFrame.new(0, 0.1, zone.minZ + depth / 2), zone.color, if index == 4 then Enum.Material.Ground else Enum.Material.Grass)
		if index > 1 then
			part(world, "ZoneLine" .. index, Vector3.new(2 * GameConfig.FIELD_HALF_WIDTH + 20, 0.3, 1), CFrame.new(0, 0.2, zone.minZ), zone.color, Enum.Material.Neon)
		end
		for _, side in { -1, 1 } do
			local sign = part(world, "ZoneSign", Vector3.new(22, 7, 1), CFrame.new(side * (GameConfig.FIELD_HALF_WIDTH + 3), 9, zone.minZ + 4), Color3.fromRGB(25, 25, 35))
			part(world, "ZonePost", Vector3.new(1, 6, 1), CFrame.new(side * (GameConfig.FIELD_HALF_WIDTH + 3), 3, zone.minZ + 4), Color3.fromRGB(25, 25, 35))
			surfaceText(sign, Enum.NormalId.Front, zone.name .. "\nLuck x" .. (1 + zone.luck), zone.color)
		end
	end

	-- The base plateau, its ramp down to the field and the spawn.
	local plateauDepth = 92
	local plateauBack = -75 - plateauDepth
	part(world, "Plateau", Vector3.new(240, TOP, plateauDepth), CFrame.new(0, TOP / 2, -75 - plateauDepth / 2), Color3.fromRGB(95, 95, 115), Enum.Material.Slate)
	part(world, "PlateauTop", Vector3.new(240, 0.2, plateauDepth), CFrame.new(0, TOP + 0.1, -75 - plateauDepth / 2), Color3.fromRGB(70, 72, 92), Enum.Material.Concrete)
	part(world, "PlateauEdge", Vector3.new(240, 0.5, 1), CFrame.new(0, TOP + 0.25, -75.5), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
	ramp(world, "BaseRamp", Vector3.new(0, 0, -40), Vector3.new(0, TOP + 0.2, -75), 2 * GameConfig.FIELD_HALF_WIDTH, Color3.fromRGB(110, 105, 125), Enum.Material.Concrete)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaseSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 8)
	spawn.CFrame = CFrame.new(0, TOP + 0.5, -81)
	spawn.Color = Color3.fromRGB(80, 220, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	-- Title sign over the ramp, readable from the base and from the field.
	local title = part(world, "TitleSign", Vector3.new(84, 12, 2), CFrame.new(0, TOP + 26, -78), Color3.fromRGB(35, 25, 60))
	for _, side in { -1, 1 } do
		part(world, "TitlePillar", Vector3.new(2, 26, 2), CFrame.new(side * 41, TOP + 13, -78), Color3.fromRGB(35, 25, 60))
	end
	-- Front (-Z) faces the bases, so the title is what a player looking out over the field reads.
	surfaceText(title, Enum.NormalId.Front, "🌪️ " .. GameConfig.GAME_TITLE .. " 🐂", Color3.fromRGB(255, 230, 80))
	surfaceText(title, Enum.NormalId.Back, "RUN HOME BEFORE DISASTER STRIKES!", Color3.fromRGB(120, 230, 255))

	local plots = {}
	for index, cx in GameConfig.PLOT_X do
		plots[index] = buildPlot(world, index, cx)
	end

	for _, center in GameConfig.HILLS do
		buildHill(world, center)
	end

	-- Scenery: fences along both sides of the field, lush trees and bushes behind them, wooden cabins
	-- facing the field, a creek with bridges in the Sus Savanna, and trees framing the base plateau.
	local decor = Instance.new("Folder")
	decor.Name = "Scenery"
	decor.Parent = world
	local fenceX = GameConfig.FIELD_HALF_WIDTH + 7
	for _, side in { -1, 1 } do
		-- Leave a gap where the railway crosses the fence line.
		local crossing = RailPath.crossingZ(side * fenceX)
		if crossing then
			fence(decor, Vector3.new(side * fenceX, 0, -42), Vector3.new(side * fenceX, 0, crossing - 9))
			fence(decor, Vector3.new(side * fenceX, 0, crossing + 9), Vector3.new(side * fenceX, 0, 334))
		else
			fence(decor, Vector3.new(side * fenceX, 0, -42), Vector3.new(side * fenceX, 0, 334))
		end
	end
	local function clearOfTrack(x: number, z: number): boolean
		return RailPath.distanceTo(Vector3.new(x, 0, z)) > 9
	end
	local houses = { { -1, 10 }, { 1, 70 }, { -1, 135 }, { 1, 195 }, { -1, 255 }, { 1, 310 } }
	for _, spot in houses do
		local side, z = spot[1], spot[2]
		-- yaw turns the door (local -Z) towards the field's centre line.
		woodenHouse(decor, Vector3.new(side * (fenceX + 15), 0, z), side * math.rad(90))
	end
	local function clearOfHouses(side: number, z: number): boolean
		for _, spot in houses do
			if spot[1] == side and math.abs(spot[2] - z) < 13 then
				return false
			end
		end
		return true
	end
	for i = 0, 15 do
		local z = -30 + i * 23
		local side = if i % 2 == 0 then -1 else 1
		local innerX = side * (fenceX + 6 + decorRng:NextNumber(0, 3))
		local outerX = -side * (fenceX + 16 + decorRng:NextNumber(0, 2))
		if clearOfHouses(side, z) and clearOfTrack(innerX, z) then
			lushTree(decor, Vector3.new(innerX, 0, z), 1.2 + decorRng:NextNumber(0, 0.4))
		end
		if clearOfHouses(-side, z + 11) and clearOfTrack(outerX, z + 11) then
			lushTree(decor, Vector3.new(outerX, 0, z + 11), 1.1 + decorRng:NextNumber(0, 0.4))
		end
		if clearOfTrack(side * (fenceX + 2.5), z + 6) then
			bush(decor, Vector3.new(side * (fenceX + 2.5), 0, z + 6))
		end
	end
	creekWithBridges(decor, 62, { -50, 0, 50 })
	for _, x in { -112, 112 } do
		for _, z in { -160, -130, -100 } do
			lushTree(decor, Vector3.new(x, TOP, z), 1.1)
		end
	end

	-- Invisible walls keep players inside the map. The west side opens onto the village (VillageBuilder).
	local village = GameConfig.VILLAGE
	local back = plateauBack - 2
	local walls = {
		{ Vector3.new(4, 80, 340 - village.maxZ), Vector3.new(-120, 40, (village.maxZ + 340) / 2) },
		{ Vector3.new(4, 80, village.maxZ - back), Vector3.new(village.minX, 40, (back + village.maxZ) / 2) },
		{ Vector3.new(-120 - village.minX, 80, 4), Vector3.new((village.minX - 120) / 2, 40, village.maxZ) },
		{ Vector3.new(4, 80, fieldDepth + plateauDepth), Vector3.new(120, 40, (plateauBack + 340) / 2) },
		{ Vector3.new(240, 80, 4), Vector3.new(0, 40, 340) },
		{ Vector3.new(120 - village.minX, 80, 4), Vector3.new((village.minX + 120) / 2, 40, back) },
	}
	for _, spec in walls do
		local w = part(world, "Boundary", spec[1], CFrame.new(spec[2]), Color3.new(1, 1, 1))
		w.Transparency = 1
	end

	return { folder = world, plots = plots, hills = GameConfig.HILLS }
end

return WorldBuilder
