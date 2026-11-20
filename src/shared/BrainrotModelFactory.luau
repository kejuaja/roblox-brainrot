-- BrainrotModelFactory: builds a farmyard brainrot's 3D model out of Parts - a piece of farm gear for the body
-- (milk bucket, milk can, hay bale, haystack, wheelbarrow, tractor, harvester, milk tanker, silo, windmill,
-- barn, horse body), one or more animal heads on top (cow, bull, chicken, rooster, goat, pig, horse) with
-- googly eyes, then extras (legs, straw hat, cow bell, eggs, pitchfork, wings, crown, halo). It paints the
-- mutation (incl. the steam-and-steel TRAIN GOD) and hangs a compact BillboardGui: name + small mutation tag.
-- The model's pivot sits at its feet, it faces -Z, and the root (body) is the only Anchored part.

local CollectionService = game:GetService("CollectionService")

local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local Factory = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(35, 30, 40)
local BLACK = Color3.fromRGB(25, 25, 25)
local TIRE = Color3.fromRGB(30, 30, 30)
local STRAW = Color3.fromRGB(235, 200, 95)
local PINK = Color3.fromRGB(255, 170, 185)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a Roblox cylinder (axis X) up
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis to Z

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Anchored = false
	part.CFrame = cframe
	part.Parent = model
	return part
end

local function block(m, name, size, color, cframe, material)
	return newPart(m, name, Enum.PartType.Block, size, color, cframe, material)
end

local function ball(m, name, diameter, color, cframe, material)
	return newPart(m, name, Enum.PartType.Ball, Vector3.one * diameter, color, cframe, material)
end

-- An ellipsoid: a block with a sphere mesh, so it can be squashed unlike a Ball.
local function sphere(m, name, size, color, cframe, material)
	local part = block(m, name, size, color, cframe, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function cylUp(m, name, height, diameter, color, cframe, material)
	return newPart(m, name, Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), color, cframe * UPRIGHT, material)
end

local function cylX(m, name, length, diameter, color, cframe, material)
	return newPart(m, name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), color, cframe, material)
end

local function cylZ(m, name, length, diameter, color, cframe, material)
	return newPart(m, name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), color, cframe * ALONG_Z, material)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function addEyes(m: Model, center: Vector3, width: number)
	local eye = width * 0.32
	for _, side in { -1, 1 } do
		local p = center + Vector3.new(side * width * 0.24, 0, 0)
		ball(m, "Eye", eye, Color3.new(1, 1, 1), CFrame.new(p))
		ball(m, "Pupil", eye * 0.5, BLACK, CFrame.new(p + Vector3.new(side * eye * 0.06, eye * 0.08, -eye * 0.32)))
	end
end

--------------------------------------------------------------------------------------------------------
-- Bodies: the farm gear. Each gets (model, scale, legHeight, colorOverride) and returns its layout:
-- root part, top Y, width, the spot where the head sits (mountY = head bottom, mountZ) and skin parts.
--------------------------------------------------------------------------------------------------------
local BODIES = {}

BODIES.bucket = function(m, s, y0, color)
	local c = color or Color3.fromRGB(175, 182, 195)
	local h, d = 2.4 * s, 2.6 * s
	local root = cylUp(m, "Body", h, d, c, at(0, y0 + h / 2, 0), Enum.Material.Metal)
	cylUp(m, "Rim", 0.25 * s, d + 0.2 * s, c:Lerp(BLACK, 0.3), at(0, y0 + h - 0.1 * s, 0), Enum.Material.Metal)
	cylUp(m, "Milk", 0.12 * s, d - 0.3 * s, Color3.new(1, 1, 1), at(0, y0 + h - 0.12 * s, 0))
	cylUp(m, "Band", 0.2 * s, d + 0.06 * s, c:Lerp(BLACK, 0.3), at(0, y0 + h * 0.35, 0), Enum.Material.Metal)
	for _, side in { -1, 1 } do
		block(m, "Lug", Vector3.new(0.3, 0.4, 0.3) * s, c, at(side * (d / 2 + 0.1 * s), y0 + h * 0.8, 0), Enum.Material.Metal)
	end
	block(m, "Handle", Vector3.new(d + 0.4 * s, 0.15 * s, 0.15 * s), DARK, at(0, y0 + h + 0.35 * s, 0.9 * s) * CFrame.Angles(math.rad(-35), 0, 0), Enum.Material.Metal)
	return { root = root, top = y0 + h, width = d, mountY = y0 + h - 0.6 * s, mountZ = 0 }
end

BODIES.milkcan = function(m, s, y0, color)
	local c = color or Color3.fromRGB(205, 210, 220)
	local root = cylUp(m, "Body", 2.4 * s, 2.0 * s, c, at(0, y0 + 1.2 * s, 0), Enum.Material.Metal)
	cylUp(m, "Shoulder", 0.5 * s, 1.6 * s, c, at(0, y0 + 2.65 * s, 0), Enum.Material.Metal)
	cylUp(m, "Neck", 0.6 * s, 1.0 * s, c, at(0, y0 + 3.2 * s, 0), Enum.Material.Metal)
	cylUp(m, "Lid", 0.2 * s, 1.3 * s, c:Lerp(BLACK, 0.25), at(0, y0 + 3.6 * s, 0), Enum.Material.Metal)
	cylUp(m, "Stripe", 0.3 * s, 2.05 * s, Color3.fromRGB(60, 120, 230), at(0, y0 + 0.9 * s, 0))
	return { root = root, top = y0 + 3.7 * s, width = 2.0 * s, mountY = y0 + 3.6 * s, mountZ = 0 }
end

BODIES.haybale = function(m, s, y0, color)
	local c = color or STRAW
	local root = block(m, "Body", Vector3.new(3, 2, 2.4) * s, c, at(0, y0 + 1 * s, 0), Enum.Material.Fabric)
	for _, x in { -0.8, 0.8 } do
		block(m, "Twine", Vector3.new(0.2, 2.06, 2.46) * s, Color3.fromRGB(140, 90, 50), at(x * s, y0 + 1 * s, 0), Enum.Material.Fabric)
	end
	for i, x in { -1.1, 0.2, 1.0 } do
		block(m, "Straw", Vector3.new(0.12, 0.6, 0.12) * s, c:Lerp(Color3.new(1, 1, 1), 0.2), at(x * s, y0 + 2.2 * s, (i - 2) * 0.6 * s) * CFrame.Angles(0, 0, math.rad(20 * (i - 2))))
	end
	return { root = root, top = y0 + 2 * s, width = 3 * s, mountY = y0 + 1.8 * s, mountZ = -0.3 * s }
end

BODIES.haystack = function(m, s, y0, color)
	local c = color or STRAW
	local root = sphere(m, "Body", Vector3.new(3.6, 3.2, 3.6) * s, c, at(0, y0 + 1.5 * s, 0), Enum.Material.Grass)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		block(m, "Straw", Vector3.new(0.12, 0.9, 0.12) * s, c:Lerp(Color3.new(1, 1, 1), 0.25), at(math.cos(a) * 1.2 * s, y0 + 2.6 * s, math.sin(a) * 1.2 * s) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5))
	end
	return { root = root, top = y0 + 3.1 * s, width = 3.6 * s, mountY = y0 + 2.5 * s, mountZ = 0 }
end

BODIES.wheelbarrow = function(m, s, _, color)
	local c = color or Color3.fromRGB(70, 150, 80)
	local root = block(m, "Body", Vector3.new(2.4, 1.0, 3.0) * s, c, at(0, 1.4 * s, 0), Enum.Material.Metal)
	block(m, "Dirt", Vector3.new(2.1, 0.2, 2.7) * s, Color3.fromRGB(110, 75, 45), at(0, 1.85 * s, 0), Enum.Material.Ground)
	cylX(m, "Wheel", 0.5 * s, 1.3 * s, TIRE, at(0, 0.65 * s, -1.9 * s))
	cylX(m, "Hub", 0.55 * s, 0.5 * s, Color3.fromRGB(250, 200, 50), at(0, 0.65 * s, -1.9 * s))
	for _, side in { -1, 1 } do
		block(m, "Handle", Vector3.new(0.2, 0.2, 1.8) * s, Color3.fromRGB(140, 95, 55), at(side * 0.9 * s, 1.3 * s, 2.2 * s), Enum.Material.Wood)
		block(m, "Stand", Vector3.new(0.2, 0.9, 0.2) * s, DARK, at(side * 0.9 * s, 0.45 * s, 1.1 * s))
	end
	return { root = root, top = 1.95 * s, width = 2.4 * s, mountY = 1.7 * s, mountZ = 0.2 * s }
end

BODIES.tractor = function(m, s, _, color)
	local c = color or Color3.fromRGB(205, 45, 40)
	local root = block(m, "Body", Vector3.new(2.4, 1.2, 4.0) * s, c, at(0, 1.5 * s, 0), Enum.Material.Metal)
	block(m, "Hood", Vector3.new(2.0, 1.0, 1.8) * s, c, at(0, 2.55 * s, -1.0 * s), Enum.Material.Metal)
	block(m, "Grille", Vector3.new(1.6, 0.8, 0.1) * s, DARK, at(0, 2.5 * s, -1.95 * s), Enum.Material.DiamondPlate)
	for _, side in { -1, 1 } do
		ball(m, "Headlight", 0.35 * s, Color3.fromRGB(255, 240, 160), at(side * 0.65 * s, 2.75 * s, -1.97 * s), Enum.Material.Neon)
		cylX(m, "RearWheel", 0.7 * s, 2.8 * s, TIRE, at(side * 1.55 * s, 1.4 * s, 1.1 * s))
		cylX(m, "RearHub", 0.75 * s, 1.2 * s, Color3.fromRGB(250, 200, 50), at(side * 1.55 * s, 1.4 * s, 1.1 * s))
		cylX(m, "FrontWheel", 0.5 * s, 1.5 * s, TIRE, at(side * 1.35 * s, 0.75 * s, -1.4 * s))
		cylX(m, "FrontHub", 0.55 * s, 0.6 * s, Color3.fromRGB(250, 200, 50), at(side * 1.35 * s, 0.75 * s, -1.4 * s))
		block(m, "RollBar", Vector3.new(0.2, 2.4, 0.2) * s, DARK, at(side * 1.0 * s, 3.3 * s, 1.9 * s), Enum.Material.Metal)
	end
	block(m, "RollTop", Vector3.new(2.2, 0.2, 0.2) * s, DARK, at(0, 4.5 * s, 1.9 * s), Enum.Material.Metal)
	block(m, "Seat", Vector3.new(1.4, 0.4, 1.2) * s, DARK, at(0, 2.3 * s, 1.1 * s))
	cylUp(m, "Exhaust", 1.6 * s, 0.25 * s, DARK, at(0.6 * s, 3.5 * s, -1.3 * s), Enum.Material.Metal)
	return { root = root, top = 4.6 * s, width = 3.1 * s, mountY = 2.5 * s, mountZ = 1.0 * s }
end

BODIES.harvester = function(m, s, y0, color)
	local layout = BODIES.tractor(m, s, y0, color or Color3.fromRGB(235, 190, 40))
	cylX(m, "Reel", 3.6 * s, 1.1 * s, Color3.fromRGB(240, 70, 40), at(0, 1.0 * s, -2.8 * s), Enum.Material.Metal)
	for i = 0, 3 do
		block(m, "ReelBar", Vector3.new(3.7, 0.15, 0.15) * s, DARK, at(0, 1.0 * s, -2.8 * s) * CFrame.Angles(math.rad(i * 45), 0, 0) * CFrame.new(0, 0.6 * s, 0))
	end
	for _, side in { -1, 1 } do
		block(m, "ReelArm", Vector3.new(0.2, 0.2, 1.4) * s, DARK, at(side * 1.7 * s, 1.2 * s, -2.1 * s))
	end
	return layout
end

BODIES.tanker = function(m, s, _, color)
	local c = color or Color3.fromRGB(245, 245, 250)
	local root = cylZ(m, "Body", 4.2 * s, 2.2 * s, c, at(0, 2.2 * s, 0.6 * s), Enum.Material.Metal)
	for _, z in { -0.6, 1.8 } do
		cylZ(m, "Ring", 0.35 * s, 2.28 * s, Color3.fromRGB(60, 120, 230), at(0, 2.2 * s, z * s))
	end
	block(m, "Chassis", Vector3.new(2.0, 0.4, 5.4) * s, DARK, at(0, 1.0 * s, 0.2 * s), Enum.Material.Metal)
	block(m, "Cab", Vector3.new(2.0, 1.4, 1.2) * s, Color3.fromRGB(60, 120, 230), at(0, 1.9 * s, -2.2 * s), Enum.Material.Metal)
	block(m, "Windshield", Vector3.new(1.7, 0.6, 0.1) * s, Color3.fromRGB(170, 220, 255), at(0, 2.2 * s, -2.82 * s), Enum.Material.Glass)
	for _, z in { -2.0, 0.4, 2.2 } do
		for _, side in { -1, 1 } do
			cylX(m, "Wheel", 0.4 * s, 1.3 * s, TIRE, at(side * 1.1 * s, 0.65 * s, z * s))
		end
	end
	return { root = root, top = 3.3 * s, width = 2.3 * s, mountY = 2.6 * s, mountZ = -2.2 * s }
end

BODIES.silo = function(m, s, y0, color)
	local c = color or Color3.fromRGB(150, 170, 195)
	local root = cylUp(m, "Body", 4.2 * s, 2.4 * s, c, at(0, y0 + 2.1 * s, 0), Enum.Material.CorrodedMetal)
	sphere(m, "Dome", Vector3.new(2.4, 1.6, 2.4) * s, c:Lerp(Color3.new(1, 1, 1), 0.3), at(0, y0 + 4.2 * s, 0), Enum.Material.Metal)
	for _, y in { 1.2, 3.0 } do
		cylUp(m, "Band", 0.2 * s, 2.46 * s, DARK, at(0, y0 + y * s, 0), Enum.Material.Metal)
	end
	block(m, "Ladder", Vector3.new(0.5, 4.0, 0.1) * s, DARK, at(0.6 * s, y0 + 2.1 * s, -1.22 * s), Enum.Material.DiamondPlate)
	return { root = root, top = y0 + 5.0 * s, width = 2.4 * s, mountY = y0 + 4.5 * s, mountZ = 0 }
end

BODIES.windmill = function(m, s, y0, color)
	local c = color or Color3.fromRGB(245, 240, 230)
	local root = block(m, "Body", Vector3.new(2.0, 4.0, 2.0) * s, c, at(0, y0 + 2.0 * s, 0), Enum.Material.WoodPlanks)
	block(m, "Cap", Vector3.new(2.4, 0.4, 2.4) * s, Color3.fromRGB(190, 50, 45), at(0, y0 + 4.2 * s, 0), Enum.Material.WoodPlanks)
	block(m, "Door", Vector3.new(0.8, 1.4, 0.1) * s, Color3.fromRGB(120, 70, 40), at(0, y0 + 0.7 * s, -1.02 * s), Enum.Material.Wood)
	cylZ(m, "Hub", 0.4 * s, 0.6 * s, DARK, at(0, y0 + 3.0 * s, -1.2 * s))
	for i = 0, 3 do
		block(m, "Blade", Vector3.new(0.45, 2.8, 0.08) * s, Color3.fromRGB(200, 160, 110), at(0, y0 + 3.0 * s, -1.4 * s) * CFrame.Angles(0, 0, math.rad(45 + i * 90)) * CFrame.new(0, 1.4 * s, 0), Enum.Material.Wood)
	end
	return { root = root, top = y0 + 4.4 * s, width = 2.4 * s, mountY = y0 + 4.4 * s, mountZ = 0 }
end

BODIES.barn = function(m, s, y0, color)
	local c = color or Color3.fromRGB(185, 45, 40)
	local root = block(m, "Body", Vector3.new(3.0, 2.4, 2.6) * s, c, at(0, y0 + 1.2 * s, 0), Enum.Material.WoodPlanks)
	local slope = math.rad(35)
	local half = 1.7 * s
	for _, side in { -1, 1 } do
		block(m, "Roof", Vector3.new(half / math.cos(slope), 0.25 * s, 2.9 * s), Color3.fromRGB(80, 60, 55), at(side * half / 2, y0 + 2.4 * s + math.tan(slope) * half / 2, 0) * CFrame.Angles(0, 0, side * -slope), Enum.Material.Slate)
	end
	block(m, "BarnDoor", Vector3.new(1.4, 1.6, 0.1) * s, Color3.fromRGB(120, 30, 30), at(0, y0 + 0.8 * s, -1.32 * s), Enum.Material.WoodPlanks)
	for _, angle in { 40, -40 } do
		block(m, "DoorCross", Vector3.new(0.15, 2.0, 0.05) * s, Color3.new(1, 1, 1), at(0, y0 + 0.8 * s, -1.38 * s) * CFrame.Angles(0, 0, math.rad(angle)))
	end
	return { root = root, top = y0 + 3.6 * s, width = 3.0 * s, mountY = y0 + 3.0 * s, mountZ = 0 }
end

BODIES.horsebody = function(m, s, _, color)
	local c = color or Color3.fromRGB(140, 85, 45)
	for _, x in { -0.6, 0.6 } do
		for _, z in { -1.1, 1.1 } do
			block(m, "Leg", Vector3.new(0.45, 1.8, 0.45) * s, c:Lerp(BLACK, 0.2), at(x * s, 0.9 * s, z * s))
			block(m, "Hoof", Vector3.new(0.5, 0.3, 0.5) * s, BLACK, at(x * s, 0.15 * s, z * s))
		end
	end
	local root = block(m, "Body", Vector3.new(1.8, 1.6, 3.2) * s, c, at(0, 2.6 * s, 0))
	block(m, "Saddle", Vector3.new(1.9, 0.3, 1.2) * s, Color3.fromRGB(150, 40, 40), at(0, 3.45 * s, 0.2 * s), Enum.Material.Fabric)
	block(m, "Tail", Vector3.new(0.3, 1.4, 0.3) * s, BLACK, at(0, 2.4 * s, 1.8 * s) * CFrame.Angles(math.rad(25), 0, 0))
	return { root = root, top = 3.4 * s, width = 1.8 * s, mountY = 3.0 * s, mountZ = -1.5 * s }
end

--------------------------------------------------------------------------------------------------------
-- Heads: each gets (model, scale, bottomCenter, color) and returns { top, skins }.
--------------------------------------------------------------------------------------------------------
local HEADS = {}

local function cowHead(m, s, base: Vector3, color: Color3?, bull: boolean)
	local c = color or (if bull then Color3.fromRGB(110, 60, 35) else Color3.fromRGB(245, 245, 245))
	local w, h, d = 1.8 * s, 1.5 * s, 1.6 * s
	local center = base + Vector3.new(0, h / 2, 0)
	local head = block(m, "Head", Vector3.new(w, h, d), c, CFrame.new(center))
	if not bull then
		block(m, "Spot", Vector3.new(0.06, 0.6, 0.7) * s, BLACK, CFrame.new(center + Vector3.new(w / 2 + 0.01 * s, 0.1 * s, 0.2 * s)))
		block(m, "Spot", Vector3.new(0.6, 0.06, 0.7) * s, BLACK, CFrame.new(center + Vector3.new(0.3 * s, h / 2 + 0.01 * s, 0.3 * s)))
	end
	block(m, "Muzzle", Vector3.new(1.5, 0.7, 0.5) * s, if bull then Color3.fromRGB(200, 140, 120) else PINK, CFrame.new(center + Vector3.new(0, -0.35 * s, -d / 2 - 0.2 * s)))
	for _, side in { -1, 1 } do
		ball(m, "Nostril", 0.18 * s, BLACK, CFrame.new(center + Vector3.new(side * 0.3 * s, -0.3 * s, -d / 2 - 0.45 * s)))
		local hornSize = if bull then Vector3.new(0.32, 1.1, 0.32) else Vector3.new(0.25, 0.7, 0.25)
		block(m, "Horn", hornSize * s, Color3.fromRGB(240, 230, 200), CFrame.new(center + Vector3.new(side * 0.65 * s, h / 2 + hornSize.Y * s * 0.4, 0.1 * s)) * CFrame.Angles(0, 0, side * math.rad(if bull then -50 else -25)))
		block(m, "Ear", Vector3.new(0.7, 0.3, 0.4) * s, c, CFrame.new(center + Vector3.new(side * (w / 2 + 0.3 * s), 0.3 * s, 0)))
	end
	if bull then
		local ring = cylZ(m, "NoseRing", 0.08 * s, 0.6 * s, Color3.fromRGB(255, 205, 40), CFrame.new(center + Vector3.new(0, -0.65 * s, -d / 2 - 0.45 * s)), Enum.Material.Neon)
		ring.Transparency = 0.1
	end
	addEyes(m, center + Vector3.new(0, 0.25 * s, -d / 2), w)
	return { top = center.Y + h / 2 + (if bull then 0.9 else 0.6) * s, skins = { head } }
end

HEADS.cow = function(m, s, base, color)
	return cowHead(m, s, base, color, false)
end

HEADS.bull = function(m, s, base, color)
	return cowHead(m, s, base, color, true)
end

local function chickenHead(m, s, base: Vector3, color: Color3?, rooster: boolean)
	local c = color or (if rooster then Color3.fromRGB(255, 225, 190) else Color3.new(1, 1, 1))
	local h = 1.6 * s
	local center = base + Vector3.new(0, h / 2, 0)
	local head = sphere(m, "Head", Vector3.new(1.5, 1.6, 1.5) * s, c, CFrame.new(center))
	local combs = if rooster then 4 else 3
	for i = 1, combs do
		local z = (i - (combs + 1) / 2) * 0.3 * s
		local tall = (if rooster then 0.8 else 0.5) * s * (1 - math.abs(i - (combs + 1) / 2) * 0.15)
		block(m, "Comb", Vector3.new(0.25 * s, tall, 0.32 * s), Color3.fromRGB(230, 30, 40), CFrame.new(center + Vector3.new(0, h / 2 + tall / 2 - 0.1 * s, z)))
	end
	block(m, "Beak", Vector3.new(0.45, 0.3, 0.6) * s, Color3.fromRGB(255, 160, 30), CFrame.new(center + Vector3.new(0, -0.05 * s, -0.85 * s)))
	block(m, "Wattle", Vector3.new(0.25, 0.45, 0.2) * s, Color3.fromRGB(230, 30, 40), CFrame.new(center + Vector3.new(0, -0.5 * s, -0.72 * s)))
	if rooster then
		for i = -1, 1 do
			block(m, "TailFeather", Vector3.new(0.2, 1.4, 0.5) * s, if i == 0 then Color3.fromRGB(30, 140, 90) else Color3.fromRGB(200, 70, 30), CFrame.new(center + Vector3.new(i * 0.3 * s, 0.2 * s, 1.0 * s)) * CFrame.Angles(math.rad(-30), 0, math.rad(i * 15)))
		end
	end
	addEyes(m, center + Vector3.new(0, 0.25 * s, -0.68 * s), 1.5 * s)
	return { top = center.Y + h / 2 + (if rooster then 0.7 else 0.4) * s, skins = { head } }
end

HEADS.chicken = function(m, s, base, color)
	return chickenHead(m, s, base, color, false)
end

HEADS.rooster = function(m, s, base, color)
	return chickenHead(m, s, base, color, true)
end

HEADS.goat = function(m, s, base, color)
	local c = color or Color3.fromRGB(225, 222, 215)
	local h = 1.3 * s
	local center = base + Vector3.new(0, h / 2, 0)
	local head = block(m, "Head", Vector3.new(1.4, 1.3, 1.6) * s, c, CFrame.new(center))
	block(m, "Snout", Vector3.new(1.0, 0.8, 0.8) * s, c:Lerp(Color3.new(1, 1, 1), 0.3), CFrame.new(center + Vector3.new(0, -0.25 * s, -1.0 * s)))
	block(m, "Nose", Vector3.new(0.5, 0.2, 0.1) * s, BLACK, CFrame.new(center + Vector3.new(0, -0.1 * s, -1.42 * s)))
	block(m, "Beard", Vector3.new(0.3, 0.75, 0.2) * s, c:Lerp(BLACK, 0.15), CFrame.new(center + Vector3.new(0, -0.95 * s, -1.1 * s)))
	for _, side in { -1, 1 } do
		block(m, "Horn", Vector3.new(0.25, 1.1, 0.25) * s, Color3.fromRGB(90, 85, 80), CFrame.new(center + Vector3.new(side * 0.4 * s, h / 2 + 0.4 * s, 0.35 * s)) * CFrame.Angles(math.rad(35), 0, side * math.rad(-10)))
		block(m, "Ear", Vector3.new(0.8, 0.25, 0.4) * s, c, CFrame.new(center + Vector3.new(side * 0.95 * s, 0.2 * s, 0)) * CFrame.Angles(0, 0, side * math.rad(-20)))
	end
	addEyes(m, center + Vector3.new(0, 0.3 * s, -0.8 * s), 1.4 * s)
	return { top = center.Y + h / 2 + 0.9 * s, skins = { head } }
end

HEADS.pig = function(m, s, base, color)
	local c = color or PINK
	local h = 1.7 * s
	local center = base + Vector3.new(0, h / 2, 0)
	local head = sphere(m, "Head", Vector3.new(1.9, 1.7, 1.8) * s, c, CFrame.new(center))
	cylZ(m, "Snout", 0.4 * s, 0.85 * s, c:Lerp(Color3.fromRGB(230, 110, 140), 0.5), CFrame.new(center + Vector3.new(0, -0.15 * s, -0.95 * s)))
	for _, side in { -1, 1 } do
		ball(m, "Nostril", 0.2 * s, Color3.fromRGB(120, 40, 60), CFrame.new(center + Vector3.new(side * 0.18 * s, -0.15 * s, -1.12 * s)))
		block(m, "Ear", Vector3.new(0.55, 0.55, 0.15) * s, c:Lerp(Color3.fromRGB(230, 110, 140), 0.3), CFrame.new(center + Vector3.new(side * 0.6 * s, 0.85 * s, -0.1 * s)) * CFrame.Angles(math.rad(-30), 0, side * math.rad(-20)))
	end
	addEyes(m, center + Vector3.new(0, 0.35 * s, -0.78 * s), 1.7 * s)
	return { top = center.Y + h / 2 + 0.3 * s, skins = { head } }
end

HEADS.horse = function(m, s, base, color)
	local c = color or Color3.fromRGB(150, 95, 55)
	local h = 1.4 * s
	local center = base + Vector3.new(0, h / 2, 0)
	local head = block(m, "Head", Vector3.new(1.2, 1.4, 1.4) * s, c, CFrame.new(center))
	block(m, "Muzzle", Vector3.new(1.0, 0.9, 1.4) * s, c:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(center + Vector3.new(0, -0.3 * s, -1.2 * s)))
	for _, side in { -1, 1 } do
		ball(m, "Nostril", 0.18 * s, BLACK, CFrame.new(center + Vector3.new(side * 0.25 * s, -0.3 * s, -1.92 * s)))
		block(m, "Ear", Vector3.new(0.25, 0.55, 0.2) * s, c, CFrame.new(center + Vector3.new(side * 0.4 * s, 0.95 * s, 0.2 * s)))
	end
	block(m, "Mane", Vector3.new(0.3, 0.6, 1.8) * s, Color3.fromRGB(45, 30, 20), CFrame.new(center + Vector3.new(0, 0.8 * s, 0.5 * s)))
	addEyes(m, center + Vector3.new(0, 0.3 * s, -0.7 * s), 1.2 * s)
	return { top = center.Y + h / 2 + 0.6 * s, skins = { head } }
end

--------------------------------------------------------------------------------------------------------
-- Extras
--------------------------------------------------------------------------------------------------------
local function addExtras(m: Model, extras, s: number, layout)
	local top = layout.top
	for _, extra in extras do
		if extra == "legs" then
			for _, side in { -1, 1 } do
				cylUp(m, "Leg", layout.legH, 0.45 * s, DARK, at(side * layout.width * 0.25, layout.legH / 2, 0))
				block(m, "Shoe", Vector3.new(0.7, 0.35, 0.9) * s, Color3.fromRGB(240, 240, 240), at(side * layout.width * 0.25, 0.18 * s, -0.15 * s))
			end
		elseif extra == "chickenlegs" then
			for _, side in { -1, 1 } do
				cylUp(m, "Leg", layout.legH, 0.22 * s, Color3.fromRGB(255, 160, 30), at(side * layout.width * 0.22, layout.legH / 2, 0))
				for _, yaw in { -30, 0, 30 } do
					block(m, "Toe", Vector3.new(0.12, 0.1, 0.6) * s, Color3.fromRGB(255, 160, 30), at(side * layout.width * 0.22, 0.05 * s, -0.2 * s) * CFrame.Angles(0, math.rad(yaw), 0))
				end
			end
		elseif extra == "hat" then
			local y = layout.headTop
			cylUp(m, "HatBrim", 0.12 * s, 2.5 * s, STRAW, at(0, y + 0.06 * s, layout.headZ), Enum.Material.Fabric)
			cylUp(m, "HatCrown", 0.6 * s, 1.3 * s, STRAW, at(0, y + 0.4 * s, layout.headZ), Enum.Material.Fabric)
			cylUp(m, "HatBand", 0.15 * s, 1.34 * s, Color3.fromRGB(200, 40, 40), at(0, y + 0.25 * s, layout.headZ))
			top = math.max(top, y + 0.8 * s)
		elseif extra == "bell" then
			local bell = ball(m, "CowBell", 0.55 * s, Color3.fromRGB(255, 205, 40), CFrame.new(layout.headBase + Vector3.new(0, -0.15 * s, -0.8 * s)), Enum.Material.Foil)
			bell.Reflectance = 0.2
		elseif extra == "eggs" then
			for i = 0, 2 do
				local a = math.rad(200 + i * 55)
				sphere(m, "Egg", Vector3.new(0.6, 0.8, 0.6) * s, Color3.fromRGB(250, 240, 220), at(math.cos(a) * layout.width * 0.7, 0.4 * s, math.sin(a) * layout.width * 0.7))
			end
		elseif extra == "pitchfork" then
			local x = layout.width / 2 + 0.6 * s
			cylUp(m, "ForkStick", 4.2 * s, 0.18 * s, Color3.fromRGB(150, 100, 60), at(x, 2.4 * s, -0.4 * s) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.Wood)
			for i = -1, 1 do
				block(m, "Tine", Vector3.new(0.1, 0.9, 0.1) * s, Color3.fromRGB(190, 195, 205), at(x + i * 0.22 * s, 4.75 * s, -0.9 * s) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.Metal)
			end
			block(m, "ForkBar", Vector3.new(0.6, 0.1, 0.1) * s, Color3.fromRGB(190, 195, 205), at(x, 4.35 * s, -0.82 * s), Enum.Material.Metal)
			top = math.max(top, 5.2 * s)
		elseif extra == "wings" then
			for _, side in { -1, 1 } do
				block(m, "Wing", Vector3.new(0.2 * s, 1.6 * s, 2.2 * s), Color3.fromRGB(250, 250, 255), at(side * (layout.width / 2 + 0.4 * s), layout.bodyMid + 0.3 * s, 0.4 * s) * CFrame.Angles(math.rad(-15), side * math.rad(25), side * math.rad(-20)))
			end
		elseif extra == "crown" then
			local gold = Color3.fromRGB(255, 205, 40)
			cylUp(m, "Crown", 0.5 * s, 1.5 * s, gold, at(0, top + 0.25 * s, layout.headZ), Enum.Material.Foil)
			for i = 0, 4 do
				local a = math.rad(i * 72)
				block(m, "CrownSpike", Vector3.new(0.25, 0.55, 0.25) * s, gold, at(math.cos(a) * 0.6 * s, top + 0.75 * s, layout.headZ + math.sin(a) * 0.6 * s), Enum.Material.Foil)
			end
			top += 1 * s
		elseif extra == "halo" then
			local halo = cylUp(m, "Halo", 0.12 * s, 2 * s, Color3.fromRGB(255, 240, 120), at(0, top + 0.6 * s, layout.headZ), Enum.Material.Neon)
			halo.Transparency = 0.2
			top += 0.8 * s
		elseif extra == "glow" then
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 230, 160)
			light.Parent = layout.root
		end
	end
	return top
end

-- Paints the mutation onto the body and heads and adds its effect (sparkles, fire, particles, highlight).
local function applyMutation(model: Model, root: BasePart, skins: { BasePart }, mutationKey: string, s: number)
	if mutationKey == "Normal" then
		return
	end
	for _, part in skins do
		if mutationKey == "Gold" then
			part.Color = Color3.fromRGB(255, 200, 40)
			part.Material = Enum.Material.Foil
			part.Reflectance = 0.25
		elseif mutationKey == "Diamond" then
			part.Color = Color3.fromRGB(150, 235, 255)
			part.Material = Enum.Material.Glass
			part.Transparency = 0.15
			part.Reflectance = 0.3
		elseif mutationKey == "Rainbow" then
			part.Material = Enum.Material.Neon
			CollectionService:AddTag(part, "RainbowPart")
		elseif mutationKey == "Lava" then
			part.Color = Color3.fromRGB(255, 95, 25)
			part.Material = Enum.Material.CrackedLava
		elseif mutationKey == "Galaxy" then
			part.Color = Color3.fromRGB(95, 45, 190)
			part.Material = Enum.Material.Neon
		elseif mutationKey == "Radioactive" then
			part.Color = Color3.fromRGB(110, 255, 60)
			part.Material = Enum.Material.Neon
		elseif mutationKey == "Celestial" then
			-- Pearly white-gold that catches the light.
			part.Color = Color3.fromRGB(255, 244, 205)
			part.Material = Enum.Material.Glass
			part.Reflectance = 0.45
		elseif mutationKey == "TrainGod" then
			-- Locomotive steel with brass trim.
			part.Color = Color3.fromRGB(55, 55, 65)
			part.Material = Enum.Material.DiamondPlate
			part.Reflectance = 0.1
		end
	end
	if mutationKey == "TrainGod" then
		local steam = Instance.new("ParticleEmitter")
		steam.Rate = 10
		steam.Lifetime = NumberRange.new(1.5, 2.5)
		steam.Speed = NumberRange.new(2, 4)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.SpreadAngle = Vector2.new(15, 15)
		steam.Size = NumberSequence.new(0.6 * s, 2.2 * s)
		steam.Transparency = NumberSequence.new(0.3, 1)
		steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
		steam.Parent = root
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 160, 50)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = root
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Catalog.MUTATION_BY_KEY.TrainGod.color
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		return
	end
	if mutationKey == "Radioactive" or mutationKey == "Celestial" then
		local radioactive = mutationKey == "Radioactive"
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = if radioactive then 14 else 10
		emitter.Lifetime = NumberRange.new(1.2, 2.2)
		emitter.Speed = NumberRange.new(1.5, 3.5)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Size = NumberSequence.new(0.45 * s, 0)
		emitter.LightEmission = 1
		emitter.Color = ColorSequence.new(if radioactive then Color3.fromRGB(150, 255, 90) else Color3.fromRGB(255, 225, 120))
		emitter.Parent = root
		local glow = Instance.new("PointLight")
		glow.Color = Catalog.MUTATION_BY_KEY[mutationKey].color
		glow.Range = 14
		glow.Brightness = if radioactive then 2.5 else 3
		glow.Parent = root
		if not radioactive then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 240, 180)
			sparkles.Parent = root
		end
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Catalog.MUTATION_BY_KEY[mutationKey].color
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		return
	end
	if mutationKey == "Gold" or mutationKey == "Diamond" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if mutationKey == "Gold" then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(200, 245, 255)
		sparkles.Parent = root
	elseif mutationKey == "Lava" then
		local fire = Instance.new("Fire")
		fire.Size = 4 * s
		fire.Heat = 6
		fire.Parent = root
	else
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 12
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.35 * s, 0)
		emitter.LightEmission = 1
		if mutationKey == "Rainbow" then
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
			})
		else
			emitter.Color = ColorSequence.new(Color3.fromRGB(230, 220, 255))
		end
		emitter.Parent = root
	end
	if mutationKey == "Rainbow" or mutationKey == "Lava" or mutationKey == "Galaxy" then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Catalog.MUTATION_BY_KEY[mutationKey].color
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
end

-- The always-on label is deliberately small - just the name (in its rarity colour) and a small mutation tag -
-- so a crowded field or base stays readable. $/s, ATK and the Passive Skill live on the hover card
-- (BrainrotInspector), which reads the BrainrotId / Mutation attributes set below.
local function addLabel(root: BasePart, def, mutationKey: string, height: number, rootY: number, maxDistance: number)
	local rarity = Catalog.rarityOf(def.id)
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(210, if mutationKey == "Normal" then 28 else 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height - rootY + 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	local function line(name: string, text: string, color: Color3, heightPx: number, order: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, heightPx)
		label.Font = FONT
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		label.Parent = gui
		return label
	end

	if mutationKey ~= "Normal" then
		local icon = if mutationKey == "TrainGod" then "🚂 " elseif mutationKey == "Radioactive" then "☢ " elseif mutationKey == "Celestial" then "☀ " else "✦ "
		local mutationLine = line("Mutation", icon .. Catalog.mutationText(mutationKey), mutation.color, 16, 1)
		if mutationKey == "Rainbow" then
			CollectionService:AddTag(mutationLine, "RainbowText")
		end
	end
	local nameLine = line("Name", def.name, rarity.color, 26, 2)
	if rarity.key == "Secret" or rarity.key == "Brainrot God" then
		CollectionService:AddTag(nameLine, "RainbowText")
	end
	gui.Parent = root
	return gui
end

--[[
	Factory.build(id, mutationKey, options) -> Model
	options.scale          extra size multiplier on top of GameConfig.BRAINROT_SCALE (carried ones use 0.3)
	options.noLabel        skip the BillboardGui
	options.labelDistance  how far away the label stays visible (default 80 studs)
]]
function Factory.build(id: string, mutationKey: string, options): Model
	local opts = options or {}
	local def = Catalog.BY_ID[id]
	assert(def, "unknown brainrot " .. tostring(id))
	local rarity = Catalog.rarityOf(id)
	local s = rarity.scale * GameConfig.BRAINROT_SCALE * (opts.scale or 1)

	local model = Instance.new("Model")
	model.Name = def.name

	local hasLegs = table.find(def.extras, "legs") ~= nil or table.find(def.extras, "chickenlegs") ~= nil
	local legH = if hasLegs then 1.1 * s else 0
	local bodyBuilder = BODIES[def.body]
	assert(bodyBuilder, "unknown body " .. tostring(def.body))
	local body = bodyBuilder(model, s, legH, def.bodyColor)
	local root = body.root
	local skins = { root }

	local heads = if type(def.head) == "table" then def.head else { def.head }
	local spacing = 1.7 * s
	local headTop = body.top
	local firstBase
	for i, kind in heads do
		local x = (i - (#heads + 1) / 2) * spacing
		local base = Vector3.new(x, body.mountY, body.mountZ)
		local result = HEADS[kind](model, s, base, def.headColor)
		firstBase = firstBase or (base + Vector3.new(-x, 0, 0))
		headTop = math.max(headTop, result.top)
		for _, skin in result.skins do
			table.insert(skins, skin)
		end
	end

	local top = addExtras(model, def.extras, s, {
		root = root,
		top = math.max(body.top, headTop),
		headTop = headTop,
		headZ = body.mountZ,
		headBase = firstBase,
		legH = legH,
		width = body.width,
		bodyMid = (legH + body.mountY) / 2,
	})

	applyMutation(model, root, skins, mutationKey, s)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	root.Anchored = true
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new()

	if not opts.noLabel then
		addLabel(root, def, mutationKey, top, root.Position.Y, opts.labelDistance or 80)
	end

	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("Mutation", mutationKey)
	model:SetAttribute("Height", top)
	model:SetAttribute("Atk", Catalog.atkFor(id, mutationKey))
	return model
end

return Factory
