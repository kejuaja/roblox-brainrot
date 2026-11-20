-- VillageBuilder: the Brainrot Village west of the base plateau (reached by the stone ramp down the plateau's
-- west cliff, or by hopping the field fence). Builds everything that stands still:
--   * the cobbled market plaza with a stone well and four striped farmers' market stalls - physical shops
--     whose prompts open the UPGRADES / FARM ARMS / REBIRTH / DEX panels (attribute OpenPanel)
--   * the Red Barn and the grain silo, a big windmill whose sail hub is tagged "SpinHub" (spun on clients)
--   * the loop road with street lanterns and the red tractor tagged "PatrolTractor" (driven on clients)
--   * a duck pond, a sheep pen, hay stacks, flower patches (tagged "FlowerPatch"), trees and fences
--   * the giant 3D World Leaderboard board (LeaderboardService fills it)
--   * the farmstead scenery behind the bases: a huge red barn, silos, country houses, hay and trees
-- Everything that moves - farmers, chickens, sheep, ducks, birds, butterflies, the tractor, the windmill -
-- is animated by the VillageLife client script from the server clock, so every player sees the same village.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local VillageBuilder = {}

local V = GameConfig.VILLAGE
local TOP = GameConfig.PLATEAU_TOP
local FONT = Enum.Font.FredokaOne
local WOOD = Color3.fromRGB(150, 100, 60)
local DARK_WOOD = Color3.fromRGB(105, 68, 40)
local BARN_RED = Color3.fromRGB(175, 38, 32)
local TRIM = Color3.fromRGB(245, 240, 230)
local STRAW = Color3.fromRGB(235, 200, 95)
local STONE = Color3.fromRGB(140, 135, 128)
local IRON = Color3.fromRGB(45, 45, 50)
local LEAF_GREENS = { Color3.fromRGB(55, 160, 65), Color3.fromRGB(75, 185, 70), Color3.fromRGB(45, 135, 60), Color3.fromRGB(95, 195, 85) }
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local rng = Random.new(77001) -- fixed seed: the same village every server

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

local function cylinderUp(parent, name, height, diameter, position: Vector3, color, material)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * UPRIGHT, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, diameter, position: Vector3, color, material)
	local p = part(parent, name, Vector3.one * diameter, CFrame.new(position), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, pixelsPerStud: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = target
	return label
end

-- A flat slab whose top runs straight from `low` to `high`.
local function ramp(parent: Instance, name: string, low: Vector3, high: Vector3, width: number, color: Color3, material: Enum.Material)
	local length = (high - low).Magnitude
	local frame = CFrame.lookAt((low + high) / 2, high)
	return part(parent, name, Vector3.new(width, 1, length), frame * CFrame.new(0, -0.5, 0), color, material)
end

local function road(parent: Instance, a: Vector3, b: Vector3, width: number)
	local length = (b - a).Magnitude + width
	local frame = CFrame.lookAt((a + b) / 2, b)
	local slab = part(parent, "Road", Vector3.new(width, 0.2, length), frame * CFrame.new(0, 0.12, 0), Color3.fromRGB(165, 130, 90), Enum.Material.Ground)
	slab.CanCollide = false
	return slab
end

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

local function tree(parent: Instance, position: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local trunkHeight = 9 * scale
	local trunk = part(model, "Trunk", Vector3.new(trunkHeight, 2.2 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * UPRIGHT, DARK_WOOD, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local crown = position + Vector3.new(0, trunkHeight + 2 * scale, 0)
	for i, offset in { Vector3.new(0, 1.5, 0), Vector3.new(2.6, 0, 0.8), Vector3.new(-2.4, 0.2, -1), Vector3.new(0.6, -0.4, 2.6), Vector3.new(0, 3.4, 0.3) } do
		local leaves = ball(model, "Leaves", (5.5 + rng:NextNumber(0, 2.5)) * scale, crown + offset * scale, LEAF_GREENS[(i - 1) % #LEAF_GREENS + 1], Enum.Material.Grass)
		leaves.CanCollide = false
	end
end

local function lantern(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "StreetLantern"
	model.Parent = parent
	part(model, "Pole", Vector3.new(0.5, 9, 0.5), CFrame.new(position + Vector3.new(0, 4.5, 0)), IRON, Enum.Material.Metal)
	part(model, "Foot", Vector3.new(1.4, 0.6, 1.4), CFrame.new(position + Vector3.new(0, 0.3, 0)), IRON, Enum.Material.Metal)
	part(model, "Arm", Vector3.new(2.2, 0.3, 0.3), CFrame.new(position + Vector3.new(0.9, 8.8, 0)), IRON, Enum.Material.Metal)
	local cage = part(model, "Lamp", Vector3.new(1.2, 1.5, 1.2), CFrame.new(position + Vector3.new(1.8, 7.9, 0)), Color3.fromRGB(255, 200, 110), Enum.Material.Neon)
	cage.CanCollide = false
	part(model, "LampCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(position + Vector3.new(1.8, 8.85, 0)), IRON, Enum.Material.Metal).CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = cage
end

local function hayBale(parent: Instance, cframe: CFrame)
	local bale = part(parent, "HayBale", Vector3.new(3, 2, 2.2), cframe, STRAW, Enum.Material.Fabric)
	for _, x in { -0.8, 0.8 } do
		part(parent, "Twine", Vector3.new(0.15, 2.05, 2.25), cframe * CFrame.new(x, 0, 0), Color3.fromRGB(150, 110, 60), Enum.Material.Fabric).CanCollide = false
	end
	return bale
end

local function hayRoll(parent: Instance, position: Vector3)
	local roll = part(parent, "HayRoll", Vector3.new(3.2, 4.4, 4.4), CFrame.new(position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), STRAW, Enum.Material.Fabric)
	roll.Shape = Enum.PartType.Cylinder
end

local function haystack(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "HayStack"
	model.Parent = parent
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local base = CFrame.new(position) * yaw
	hayBale(model, base * CFrame.new(-1.6, 1, 0))
	hayBale(model, base * CFrame.new(1.6, 1, 0))
	hayBale(model, base * CFrame.new(0, 3, 0))
	hayRoll(model, position + yaw:VectorToWorldSpace(Vector3.new(0, 0, 4)))
end

local function flowers(parent: Instance, center: Vector3)
	local patch = part(parent, "FlowerPatch", Vector3.new(8, 0.2, 8), CFrame.new(center + Vector3.new(0, 0.12, 0)), Color3.fromRGB(80, 160, 60), Enum.Material.Grass)
	patch.CanCollide = false
	CollectionService:AddTag(patch, "FlowerPatch")
	local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60) }
	for _ = 1, 14 do
		local p = center + Vector3.new(rng:NextNumber(-3.6, 3.6), 0, rng:NextNumber(-3.6, 3.6))
		part(parent, "Stem", Vector3.new(0.15, 1, 0.15), CFrame.new(p + Vector3.new(0, 0.5, 0)), Color3.fromRGB(60, 140, 50), Enum.Material.Grass).CanCollide = false
		ball(parent, "Bloom", 0.6, p + Vector3.new(0, 1.05, 0), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic).CanCollide = false
	end
end

-- A striped farmers' market stall; its front (counter side, local -Z) faces `lookAt`.
local function stall(parent: Instance, position: Vector3, lookAt: Vector3, stripe: Color3, title: string, panel: string)
	local model = Instance.new("Model")
	model.Name = "MarketStall_" .. panel
	model.Parent = parent
	local base = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local w, d = 11, 6
	part(model, "Floor", Vector3.new(w + 1, 0.4, d + 1), at(0, 0.2, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	local counter = part(model, "Counter", Vector3.new(w - 1, 3, 1.8), at(0, 1.9, -d / 2 + 1), WOOD, Enum.Material.WoodPlanks)
	part(model, "CounterTop", Vector3.new(w - 0.6, 0.3, 2.2), at(0, 3.55, -d / 2 + 1), DARK_WOOD, Enum.Material.Wood)
	part(model, "CounterStripe", Vector3.new(w - 0.9, 0.8, 0.1), at(0, 2.3, -d / 2 + 0.05), stripe, Enum.Material.SmoothPlastic)
	for _, x in { -w / 2 + 0.4, w / 2 - 0.4 } do
		for _, z in { -d / 2 + 0.4, d / 2 - 0.4 } do
			part(model, "Post", Vector3.new(0.5, 8, 0.5), at(x, 4, z), DARK_WOOD, Enum.Material.Wood)
		end
	end
	part(model, "BackBoard", Vector3.new(w - 1, 5, 0.3), at(0, 3, d / 2 - 0.4), WOOD, Enum.Material.WoodPlanks)
	-- The striped awning, sloping down towards the customers.
	local strips = 8
	for i = 1, strips do
		local x = -w / 2 + (i - 0.5) * (w / strips)
		local color = if i % 2 == 1 then stripe else TRIM
		part(model, "Awning", Vector3.new(w / strips, 0.25, d + 2), at(x, 8.2, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), color, Enum.Material.Fabric).CanCollide = false
		local flap = part(model, "Flap", Vector3.new(w / strips, 0.9, 0.12), at(x, 7.35, -d / 2 - 1.55), color, Enum.Material.Fabric)
		flap.CanCollide = false
	end
	local sign = part(model, "Sign", Vector3.new(w - 1.5, 2.2, 0.3), at(0, 10, 0.4), Color3.fromRGB(40, 28, 22), Enum.Material.Wood)
	sign.CanCollide = false
	surfaceText(sign, Enum.NormalId.Front, title, Color3.fromRGB(255, 235, 150))
	surfaceText(sign, Enum.NormalId.Back, title, Color3.fromRGB(255, 235, 150))
	-- Goods on the counter: crates of produce and a pumpkin or two.
	for i, x in { -3.4, -1.2, 1.2, 3.4 } do
		local crate = part(model, "Crate", Vector3.new(1.6, 1, 1.4), at(x, 4.2, -d / 2 + 1), Color3.fromRGB(190, 140, 80), Enum.Material.WoodPlanks)
		crate.CanCollide = false
		local produce = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(220, 40, 40), Color3.fromRGB(250, 210, 60), Color3.fromRGB(120, 200, 60) }
		for j = -1, 1 do
			ball(model, "Produce", 0.55, (at(x + j * 0.45, 4.85, -d / 2 + 1)).Position, produce[i], Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
	ball(model, "Pumpkin", 1.6, (at(w / 2 + 0.6, 0.8, -d / 2)).Position, Color3.fromRGB(255, 130, 20), Enum.Material.SmoothPlastic)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StallPrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenPanel", panel)
	prompt.Parent = counter
	return model
end

local function well(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "StoneWell"
	model.Parent = parent
	cylinderUp(model, "Ring", 3.2, 7, center + Vector3.new(0, 1.6, 0), STONE, Enum.Material.Cobblestone)
	cylinderUp(model, "Water", 0.2, 5.6, center + Vector3.new(0, 2.6, 0), Color3.fromRGB(50, 120, 200), Enum.Material.Glass).CanCollide = false
	for _, x in { -3, 3 } do
		part(model, "WellPost", Vector3.new(0.6, 6, 0.6), CFrame.new(center + Vector3.new(x, 5, 0)), DARK_WOOD, Enum.Material.Wood)
	end
	local axle = part(model, "Axle", Vector3.new(6.4, 0.4, 0.4), CFrame.new(center + Vector3.new(0, 6.6, 0)), DARK_WOOD, Enum.Material.Wood)
	axle.Shape = Enum.PartType.Cylinder
	part(model, "Rope", Vector3.new(0.12, 2.6, 0.12), CFrame.new(center + Vector3.new(0, 5.2, 0)), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric).CanCollide = false
	local bucket = cylinderUp(model, "Bucket", 1, 1, center + Vector3.new(0, 3.6, 0), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	bucket.CanCollide = false
	for _, side in { -1, 1 } do
		part(model, "WellRoof", Vector3.new(4.4, 0.35, 7.4), CFrame.new(center + Vector3.new(side * 1.8, 8.6, 0)) * CFrame.Angles(0, 0, side * math.rad(-30)), Color3.fromRGB(150, 60, 45), Enum.Material.Slate)
	end
end

local function gables(parent: Instance, at, w: number, h: number, z: number, rise: number, color: Color3)
	local steps = 8
	for i = 0, steps - 1 do
		local y0 = rise * i / steps
		local width = w * (1 - (i + 0.5) / steps)
		part(parent, "Gable", Vector3.new(width, rise / steps, 0.6), at(0, h + y0 + rise / steps / 2, z), color, Enum.Material.WoodPlanks)
	end
end

local function redBarn(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "RedBarn"
	model.Parent = parent
	local base = CFrame.lookAt(position, position + Vector3.new(0, 0, -1)) -- doors face the plaza (-Z)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local w, d, h = 26, 20, 14
	part(model, "Foundation", Vector3.new(w + 1, 0.6, d + 1), at(0, 0.3, 0), STONE, Enum.Material.Cobblestone)
	part(model, "BackWall", Vector3.new(w, h, 0.8), at(0, h / 2, d / 2), BARN_RED, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		part(model, "SideWall", Vector3.new(0.8, h, d), at(side * w / 2, h / 2, 0), BARN_RED, Enum.Material.WoodPlanks)
		part(model, "CornerTrim", Vector3.new(1, h, 1), at(side * w / 2, h / 2, -d / 2), TRIM, Enum.Material.WoodPlanks)
		part(model, "FrontWall", Vector3.new(w / 2 - 5, h, 0.8), at(side * (w / 4 + 2.5), h / 2, -d / 2), BARN_RED, Enum.Material.WoodPlanks)
		-- Big double doors with the classic white X.
		local door = part(model, "Door", Vector3.new(5, 10, 0.4), at(side * 2.5, 5, -d / 2 - 0.3), BARN_RED, Enum.Material.WoodPlanks)
		for _, tilt in { -1, 1 } do
			part(model, "DoorX", Vector3.new(0.5, math.sqrt(25 + 100) - 0.6, 0.15), door.CFrame * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, tilt * math.atan2(5, 10)), TRIM, Enum.Material.WoodPlanks)
		end
		part(model, "DoorFrame", Vector3.new(0.5, 10, 0.5), at(side * 5.2, 5, -d / 2 - 0.4), TRIM, Enum.Material.WoodPlanks)
	end
	part(model, "DoorHeader", Vector3.new(w - 9, h - 10, 0.8), at(0, 10 + (h - 10) / 2, -d / 2), BARN_RED, Enum.Material.WoodPlanks)
	part(model, "DoorLintel", Vector3.new(11, 0.6, 0.6), at(0, 10.2, -d / 2 - 0.4), TRIM, Enum.Material.WoodPlanks)
	-- Roof and gables.
	local slope = math.rad(36)
	local halfSpan = w / 2 + 1.5
	local roofLength = halfSpan / math.cos(slope)
	for _, side in { -1, 1 } do
		part(model, "Roof", Vector3.new(roofLength, 0.9, d + 2.4), at(side * halfSpan / 2, h + math.tan(slope) * halfSpan / 2, 0) * CFrame.Angles(0, 0, side * -slope), Color3.fromRGB(80, 60, 55), Enum.Material.Slate)
	end
	local rise = math.tan(slope) * (w / 2)
	gables(model, at, w, h, -d / 2, rise, BARN_RED)
	gables(model, at, w, h, d / 2, rise, BARN_RED)
	local loft = part(model, "HayLoft", Vector3.new(4, 4, 0.4), at(0, h + 3, -d / 2 - 0.4), TRIM, Enum.Material.WoodPlanks)
	part(model, "LoftHay", Vector3.new(3.2, 1.2, 0.5), at(0, h + 1.8, -d / 2 - 0.6), STRAW, Enum.Material.Fabric)
	loft.CanCollide = false
	local sign = part(model, "BarnSign", Vector3.new(12, 2.4, 0.3), at(0, 11.9, -d / 2 - 0.6), TRIM, Enum.Material.WoodPlanks)
	surfaceText(sign, Enum.NormalId.Front, "🐮 RED BARN 🐮", BARN_RED)
	-- A rooster weather vane on the ridge.
	part(model, "VanePole", Vector3.new(0.3, 4, 0.3), at(0, h + rise + 2, 0), IRON, Enum.Material.Metal)
	part(model, "VaneRooster", Vector3.new(0.2, 1.4, 2.2), at(0, h + rise + 4, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	for i, x in { -9, -5.5 } do
		hayBale(model, at(x, 1, -d / 2 - 3) * CFrame.Angles(0, math.rad(i * 20), 0))
	end
	hayBale(model, at(-7.2, 3, -d / 2 - 3))
	return model
end

local function silo(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "GrainSilo"
	model.Parent = parent
	local height, diameter = 32, 12
	cylinderUp(model, "Footing", 1, diameter + 2, position + Vector3.new(0, 0.5, 0), STONE, Enum.Material.Concrete)
	cylinderUp(model, "Tank", height, diameter, position + Vector3.new(0, height / 2 + 1, 0), Color3.fromRGB(200, 205, 210), Enum.Material.CorrodedMetal)
	for y = 5, height, 6 do
		cylinderUp(model, "Band", 0.5, diameter + 0.3, position + Vector3.new(0, y, 0), Color3.fromRGB(150, 155, 165), Enum.Material.Metal).CanCollide = false
	end
	ball(model, "Dome", diameter + 0.2, position + Vector3.new(0, height + 1, 0), Color3.fromRGB(175, 40, 35), Enum.Material.Metal)
	for y = 2, height, 1.2 do
		part(model, "LadderRung", Vector3.new(1.6, 0.15, 0.15), CFrame.new(position + Vector3.new(0, y, -diameter / 2 - 0.5)), IRON, Enum.Material.Metal).CanCollide = false
	end
	for _, x in { -0.8, 0.8 } do
		part(model, "LadderRail", Vector3.new(0.15, height, 0.15), CFrame.new(position + Vector3.new(x, height / 2 + 1, -diameter / 2 - 0.5)), IRON, Enum.Material.Metal).CanCollide = false
	end
	local plate = part(model, "Label", Vector3.new(7, 3, 0.2), CFrame.new(position + Vector3.new(0, 18, -diameter / 2 - 0.15)), Color3.fromRGB(175, 40, 35), Enum.Material.SmoothPlastic)
	plate.CanCollide = false
	surfaceText(plate, Enum.NormalId.Front, "GRAIN", TRIM)
	-- A grain chute sloping into the barn.
	part(model, "Chute", Vector3.new(1.4, 1.4, 16), CFrame.new(position + Vector3.new(8, 22, 0)) * CFrame.Angles(0, math.rad(90), math.rad(-25)), Color3.fromRGB(160, 165, 170), Enum.Material.Metal).CanCollide = false
	return model
end

local function windmill(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Windmill"
	model.Parent = parent
	-- A tapering stone tower, a wooden balcony, a cap - its sails face east, towards the field.
	local tiers = { { h = 12, d = 14 }, { h = 12, d = 12 }, { h = 12, d = 10 } }
	local y = 0
	for i, tier in tiers do
		cylinderUp(model, "Tower" .. i, tier.h, tier.d, position + Vector3.new(0, y + tier.h / 2, 0), if i == 2 then Color3.fromRGB(235, 228, 210) else STONE, if i == 2 then Enum.Material.Plaster else Enum.Material.Cobblestone)
		y += tier.h
	end
	cylinderUp(model, "Balcony", 0.6, 16, position + Vector3.new(0, 12.3, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	part(model, "Door", Vector3.new(0.4, 6, 4), CFrame.new(position + Vector3.new(6.9, 3, 0)), DARK_WOOD, Enum.Material.Wood)
	for _, z in { -3, 3 } do
		part(model, "Window", Vector3.new(0.3, 2, 1.6), CFrame.new(position + Vector3.new(5.95, 20, z)), Color3.fromRGB(255, 220, 130), Enum.Material.Neon)
	end
	local cap = ball(model, "Cap", 11, position + Vector3.new(0, y + 1, 0), Color3.fromRGB(150, 60, 45), Enum.Material.Slate)
	cap.Size = Vector3.new(11, 11, 11)
	-- The sail hub (spun by clients) with four lattice sails, welded to it.
	local hubCFrame = CFrame.new(position + Vector3.new(6.5, y - 2, 0))
	local hub = part(model, "SailHub", Vector3.new(3, 2.4, 2.4), hubCFrame, DARK_WOOD, Enum.Material.Wood)
	hub.Shape = Enum.PartType.Cylinder
	hub.CanCollide = false
	local sails = {}
	for i = 0, 3 do
		local spoke = hubCFrame * CFrame.Angles(i * math.pi / 2, 0, 0)
		table.insert(sails, part(model, "Spoke", Vector3.new(0.5, 21, 0.8), spoke * CFrame.new(0.8, 11, 0), DARK_WOOD, Enum.Material.Wood))
		table.insert(sails, part(model, "Sail", Vector3.new(0.2, 15, 4.6), spoke * CFrame.new(0.9, 13, 2.6), Color3.fromRGB(245, 238, 220), Enum.Material.Fabric))
		for k = 0, 4 do
			table.insert(sails, part(model, "Lath", Vector3.new(0.25, 0.3, 5), spoke * CFrame.new(1.05, 6.5 + k * 3.4, 2.6), DARK_WOOD, Enum.Material.Wood))
		end
	end
	for _, sail in sails do
		sail.Anchored = false
		sail.CanCollide = false
		sail.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hub
		weld.Part1 = sail
		weld.Parent = sail
	end
	hub:SetAttribute("BaseCFrame", hubCFrame)
	hub:SetAttribute("SpinRate", 0.55)
	CollectionService:AddTag(hub, "SpinHub")
end

local function pond(parent: Instance, center: Vector3, radius: number)
	local model = Instance.new("Model")
	model.Name = "DuckPond"
	model.Parent = parent
	cylinderUp(model, "Shore", 0.3, radius * 2 + 4, center + Vector3.new(0, 0.1, 0), Color3.fromRGB(205, 185, 135), Enum.Material.Sand).CanCollide = false
	local water = cylinderUp(model, "Water", 0.3, radius * 2, center + Vector3.new(0, 0.2, 0), Color3.fromRGB(60, 150, 220), Enum.Material.Glass)
	water.Transparency = 0.15
	water.CanCollide = false
	for _ = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, radius - 3)
		local pad = cylinderUp(model, "LilyPad", 0.1, 1.8, center + Vector3.new(math.cos(angle) * r, 0.4, math.sin(angle) * r), Color3.fromRGB(70, 160, 70), Enum.Material.Grass)
		pad.CanCollide = false
	end
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(angle) * (radius + 0.5), 0, math.sin(angle) * (radius + 0.5))
		part(model, "Reed", Vector3.new(0.2, 2.6, 0.2), CFrame.new(p + Vector3.new(0, 1.3, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(80, 140, 60), Enum.Material.Grass).CanCollide = false
		part(model, "Cattail", Vector3.new(0.35, 0.7, 0.35), CFrame.new(p + Vector3.new(0, 2.7, 0)), Color3.fromRGB(110, 70, 40), Enum.Material.Fabric).CanCollide = false
	end
end

local function sheepPen(parent: Instance, center: Vector3)
	local hw, hd = 12, 9
	local c = center
	fence(parent, c + Vector3.new(-hw, 0, -hd), c + Vector3.new(hw, 0, -hd))
	fence(parent, c + Vector3.new(hw, 0, -hd), c + Vector3.new(hw, 0, hd))
	fence(parent, c + Vector3.new(hw, 0, hd), c + Vector3.new(-hw, 0, hd))
	fence(parent, c + Vector3.new(-hw, 0, hd), c + Vector3.new(-hw, 0, 2))
	fence(parent, c + Vector3.new(-hw, 0, -2), c + Vector3.new(-hw, 0, -hd))
	part(parent, "Trough", Vector3.new(6, 1.2, 1.6), CFrame.new(c + Vector3.new(6, 0.6, 6)), DARK_WOOD, Enum.Material.Wood)
	part(parent, "TroughHay", Vector3.new(5.6, 0.4, 1.2), CFrame.new(c + Vector3.new(6, 1.3, 6)), STRAW, Enum.Material.Fabric).CanCollide = false
end

-- The red tractor that patrols the loop road. Pivot at ground level, facing -Z. Clients drive it.
local function tractor(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "PatrolTractor"
	local red = Color3.fromRGB(200, 30, 30)
	local root = part(model, "Body", Vector3.new(3.6, 2.4, 6.4), CFrame.new(0, 3, 0.2), red, Enum.Material.SmoothPlastic)
	part(model, "Hood", Vector3.new(3, 1.8, 4), CFrame.new(0, 4.6, -1.4), red, Enum.Material.SmoothPlastic)
	part(model, "Grille", Vector3.new(2.6, 1.6, 0.2), CFrame.new(0, 4.4, -3.45), Color3.fromRGB(50, 50, 55), Enum.Material.DiamondPlate)
	for _, x in { -0.9, 0.9 } do
		part(model, "Headlight", Vector3.new(0.6, 0.6, 0.2), CFrame.new(x, 3.4, -3.35), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
	end
	part(model, "Seat", Vector3.new(1.8, 0.5, 1.6), CFrame.new(0, 4.5, 2), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
	part(model, "SeatBack", Vector3.new(1.8, 1.6, 0.4), CFrame.new(0, 5.4, 2.9), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
	part(model, "Steering", Vector3.new(0.2, 1.6, 0.2), CFrame.new(0, 5.4, 0.6) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	for _, x in { -1.6, 1.6 } do
		part(model, "RollBar", Vector3.new(0.3, 5, 0.3), CFrame.new(x, 7, 3), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	end
	part(model, "RollTop", Vector3.new(3.5, 0.3, 0.3), CFrame.new(0, 9.5, 3), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	part(model, "Canopy", Vector3.new(4.2, 0.3, 3.4), CFrame.new(0, 9.7, 2.2), Color3.fromRGB(240, 200, 50), Enum.Material.Fabric)
	local stack = part(model, "Exhaust", Vector3.new(0.5, 3, 0.5), CFrame.new(0.9, 6.5, -2.4), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Size = 1
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.15
	smoke.Color = Color3.fromRGB(90, 90, 95)
	smoke.Parent = stack
	for _, spec in { { x = 2.3, z = 2.2, d = 4.6, w = 1.4 }, { x = -2.3, z = 2.2, d = 4.6, w = 1.4 }, { x = 2, z = -2.4, d = 2.8, w = 1 }, { x = -2, z = -2.4, d = 2.8, w = 1 } } do
		local wheel = part(model, "Wheel", Vector3.new(spec.w, spec.d, spec.d), CFrame.new(spec.x, spec.d / 2, spec.z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
		local hubcap = part(model, "Hubcap", Vector3.new(spec.w + 0.1, spec.d * 0.45, spec.d * 0.45), CFrame.new(spec.x, spec.d / 2, spec.z), Color3.fromRGB(240, 200, 50), Enum.Material.SmoothPlastic)
		hubcap.Shape = Enum.PartType.Cylinder
	end
	-- The driver: a farmer in a straw hat.
	part(model, "DriverBody", Vector3.new(1.6, 1.8, 1), CFrame.new(0, 5.8, 1.9), Color3.fromRGB(60, 100, 200), Enum.Material.Fabric)
	ball(model, "DriverHead", 1.2, Vector3.new(0, 7.3, 1.9), Color3.fromRGB(240, 195, 150), Enum.Material.SmoothPlastic)
	local brim = part(model, "HatBrim", Vector3.new(0.12, 2.4, 2.4), CFrame.new(0, 7.8, 1.9) * UPRIGHT, STRAW, Enum.Material.Fabric)
	brim.Shape = Enum.PartType.Cylinder
	local crown = part(model, "HatCrown", Vector3.new(0.7, 1.2, 1.2), CFrame.new(0, 8.15, 1.9) * UPRIGHT, STRAW, Enum.Material.Fabric)
	crown.Shape = Enum.PartType.Cylinder
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if p ~= root then
				p.Anchored = false
				p.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new()
	model:PivotTo(CFrame.new(position))
	CollectionService:AddTag(model, "PatrolTractor")
	model.Parent = parent
end

-- The giant World Leaderboard: two columns (TOP CASH, TOP REBIRTHS) of ten rows. Faces east (+X).
local function leaderboard(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "WorldLeaderboard"
	model.Parent = parent
	local width, height, bottom = 50, 30, 4
	local gold = Color3.fromRGB(255, 200, 50)
	for _, z in { -width / 2 - 1, width / 2 + 1 } do
		part(model, "Pillar", Vector3.new(2.4, bottom + height + 3, 2.4), CFrame.new(position + Vector3.new(0, (bottom + height + 3) / 2, z)), DARK_WOOD, Enum.Material.Wood)
		ball(model, "PillarLamp", 2.4, position + Vector3.new(0, bottom + height + 4.4, z), gold, Enum.Material.Neon)
	end
	local board = part(model, "Board", Vector3.new(1.6, height, width), CFrame.new(position + Vector3.new(0, bottom + height / 2, 0)), Color3.fromRGB(28, 22, 40), Enum.Material.SmoothPlastic)
	for _, y in { bottom - 0.4, bottom + height + 0.4 } do
		part(model, "Trim", Vector3.new(1.9, 0.8, width + 1.6), CFrame.new(position + Vector3.new(0, y, 0)), gold, Enum.Material.Neon)
	end
	part(model, "Roof", Vector3.new(5, 1, width + 6), CFrame.new(position + Vector3.new(0.6, bottom + height + 2.2, 0)), Color3.fromRGB(150, 60, 45), Enum.Material.Slate)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Right
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = board
	local function text(parentFrame: Instance, props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		for key, value in props do
			(l :: any)[key] = value
		end
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = l
		l.Parent = parentFrame
		return l
	end
	text(gui, { Position = UDim2.fromScale(0.03, 0.02), Size = UDim2.fromScale(0.94, 0.12), Text = "🏆 WORLD LEADERBOARD 🏆", TextColor3 = gold })
	local status = text(gui, { Position = UDim2.fromScale(0.03, 0.93), Size = UDim2.fromScale(0.94, 0.05), Text = "Loading...", TextColor3 = Color3.fromRGB(180, 180, 210) })
	local columns = {}
	for c, spec in { { key = "cash", title = "💰 TOP CASH", color = Color3.fromRGB(120, 255, 140) }, { key = "rebirths", title = "♻️ TOP REBIRTHS", color = Color3.fromRGB(230, 140, 255) } } do
		local frame = Instance.new("Frame")
		frame.Position = UDim2.fromScale(0.03 + (c - 1) * 0.48, 0.16)
		frame.Size = UDim2.fromScale(0.46, 0.76)
		frame.BackgroundColor3 = Color3.fromRGB(45, 36, 66)
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = frame
		frame.Parent = gui
		text(frame, { Position = UDim2.fromScale(0.04, 0.01), Size = UDim2.fromScale(0.92, 0.1), Text = spec.title, TextColor3 = spec.color })
		local rows = {}
		for r = 1, 10 do
			local medal = ({ Color3.fromRGB(255, 215, 60), Color3.fromRGB(215, 215, 230), Color3.fromRGB(225, 150, 90) })[r] or Color3.fromRGB(230, 230, 245)
			local y = 0.12 + (r - 1) * 0.087
			local name = text(frame, { Position = UDim2.fromScale(0.04, y), Size = UDim2.fromScale(0.6, 0.075), Text = "#" .. r .. "  ---", TextColor3 = medal, TextXAlignment = Enum.TextXAlignment.Left })
			local value = text(frame, { Position = UDim2.fromScale(0.62, y), Size = UDim2.fromScale(0.34, 0.075), Text = "", TextColor3 = spec.color, TextXAlignment = Enum.TextXAlignment.Right })
			rows[r] = { name = name, value = value }
		end
		columns[spec.key] = rows
	end
	return { cash = columns.cash, rebirths = columns.rebirths, status = status }
end

-- A countryside wooden house: plank walls, a door with a porch light, warm windows, a pitched roof and a
-- chimney. Its door (local -Z) faces `yaw`.
local function farmhouse(parent: Instance, position: Vector3, yaw: number, wall: Color3, roof: Color3)
	local model = Instance.new("Model")
	model.Name = "FarmHouse"
	model.Parent = parent
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local w, d, h = 16, 13, 10
	part(model, "Footing", Vector3.new(w + 1, 0.8, d + 1), at(0, 0.4, 0), STONE, Enum.Material.Cobblestone)
	part(model, "Walls", Vector3.new(w, h, d), at(0, h / 2 + 0.8, 0), wall, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		part(model, "CornerTrim", Vector3.new(0.8, h, 0.8), at(side * w / 2, h / 2 + 0.8, -d / 2), TRIM, Enum.Material.WoodPlanks)
		local window = part(model, "Window", Vector3.new(2.6, 2.6, 0.2), at(side * 4.6, 5.8, -d / 2 - 0.1), Color3.fromRGB(255, 215, 130), Enum.Material.Neon)
		window.Transparency = 0.1
		part(model, "WindowFrame", Vector3.new(3.2, 3.2, 0.15), at(side * 4.6, 5.8, -d / 2 - 0.05), TRIM, Enum.Material.Wood)
		part(model, "FlowerBox", Vector3.new(3.2, 0.7, 0.8), at(side * 4.6, 4.1, -d / 2 - 0.45), DARK_WOOD, Enum.Material.Wood)
	end
	part(model, "Door", Vector3.new(3.2, 6, 0.3), at(0, 3.8, -d / 2 - 0.1), Color3.fromRGB(120, 55, 35), Enum.Material.Wood)
	part(model, "PorchRoof", Vector3.new(6, 0.4, 3), at(0, 7.6, -d / 2 - 1.4) * CFrame.Angles(math.rad(12), 0, 0), roof, Enum.Material.Slate)
	local porchLight = part(model, "PorchLight", Vector3.new(0.6, 0.8, 0.6), at(2.3, 6.6, -d / 2 - 0.4), Color3.fromRGB(255, 200, 110), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 190, 110)
	glow.Range = 12
	glow.Parent = porchLight
	local slope = math.rad(33)
	local halfSpan = w / 2 + 1
	local roofLength = halfSpan / math.cos(slope)
	for _, side in { -1, 1 } do
		part(model, "Roof", Vector3.new(roofLength, 0.8, d + 2), at(side * halfSpan / 2, h + 0.8 + math.tan(slope) * halfSpan / 2, 0) * CFrame.Angles(0, 0, side * -slope), roof, Enum.Material.Slate)
	end
	gables(model, at, w, h + 0.8, -d / 2, math.tan(slope) * (w / 2), wall)
	gables(model, at, w, h + 0.8, d / 2, math.tan(slope) * (w / 2), wall)
	part(model, "Chimney", Vector3.new(1.8, 6, 1.8), at(4, h + 5, 2), Color3.fromRGB(130, 105, 95), Enum.Material.Brick)
	return model
end

-- Turns a freshly built model half way round about `position`, so a building facing -Z faces +Z instead.
local function turnAround(model: Model, position: Vector3)
	local pivot = CFrame.new(position)
	model:PivotTo(pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse() * model:GetPivot())
end

-- Grows a model about its own centre, then sets it back down on the ground at `groundY`.
local function enlarge(model: Model, scale: number, groundY: number)
	model:ScaleTo(scale)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - bottom, 0))
end

-- The farmstead behind the bases: a meadow at plateau height beyond the back wall (out of bounds, scenery
-- only) with a huge red barn and grain silos behind the middle plots, wooden country houses, hay stacks,
-- a fence and dense trees - so the view behind the nine slots is a busy farm instead of empty sky.
local function farmBackdrop(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "FarmBackdrop"
	folder.Parent = parent
	local top = TOP + 0.2
	local ground = part(folder, "BackdropMeadow", Vector3.new(270, TOP + 0.2, 150), CFrame.new(5, top / 2, -246), Color3.fromRGB(105, 175, 75), Enum.Material.Grass)
	ground.CanCollide = true
	local path = part(folder, "BackdropLane", Vector3.new(250, 0.2, 9), CFrame.new(5, top + 0.1, -186), Color3.fromRGB(165, 130, 90), Enum.Material.Ground)
	path.CanCollide = false
	fence(folder, Vector3.new(-118, top, -174), Vector3.new(128, top, -174))

	local barn = Instance.new("Model")
	barn.Name = "BigRedBarn"
	barn.Parent = folder
	redBarn(barn, Vector3.new(0, top, -214))
	turnAround(barn, Vector3.new(0, top, -214))
	enlarge(barn, 1.6, top)
	for i, spot in { Vector3.new(36, top, -222), Vector3.new(50, top, -232) } do
		local siloModel = Instance.new("Model")
		siloModel.Name = "BackdropSilo" .. i
		siloModel.Parent = folder
		silo(siloModel, spot)
		turnAround(siloModel, spot)
		enlarge(siloModel, if i == 1 then 1.25 else 1.05, top)
	end

	local houses = {
		{ x = -46, z = -200, wall = Color3.fromRGB(235, 225, 200), roof = Color3.fromRGB(150, 55, 45) },
		{ x = -84, z = -212, wall = Color3.fromRGB(170, 205, 230), roof = Color3.fromRGB(80, 70, 70) },
		{ x = 80, z = -204, wall = Color3.fromRGB(245, 220, 150), roof = Color3.fromRGB(120, 60, 40) },
		{ x = 110, z = -222, wall = Color3.fromRGB(200, 140, 100), roof = Color3.fromRGB(70, 90, 60) },
		{ x = -112, z = -238, wall = Color3.fromRGB(230, 200, 200), roof = Color3.fromRGB(110, 50, 60) },
	}
	for _, spec in houses do
		farmhouse(folder, Vector3.new(spec.x, top, spec.z), math.pi + rng:NextNumber(-0.2, 0.2), spec.wall, spec.roof)
	end
	for _, p in {
		Vector3.new(-26, top, -190), Vector3.new(24, top, -192), Vector3.new(58, top, -196), Vector3.new(-64, top, -192),
		Vector3.new(96, top, -192), Vector3.new(-100, top, -196), Vector3.new(-22, top, -232), Vector3.new(68, top, -240),
	} do
		haystack(folder, p)
	end
	for _, x in { -8, 8, -30, 30 } do
		hayRoll(folder, Vector3.new(x, top, -194 - math.abs(x) * 0.1))
	end
	-- Rows of dense trees behind and between the buildings.
	for row = 0, 2 do
		local z = -258 - row * 16
		for x = -116, 124, 15 do
			local jitter = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			tree(folder, Vector3.new(x, top, z) + jitter, 1.2 + rng:NextNumber(0, 0.6) + row * 0.15)
		end
	end
	for _, p in { Vector3.new(-64, top, -226), Vector3.new(-20, top, -246), Vector3.new(24, top, -250), Vector3.new(96, top, -244), Vector3.new(-104, top, -214), Vector3.new(66, top, -218) } do
		tree(folder, p, 1.3 + rng:NextNumber(0, 0.4))
	end
end

function VillageBuilder.build(world)
	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = world.folder
	local plaza = V.plaza
	local width, depth = V.maxX - V.minX, V.maxZ - V.minZ
	local cx, cz = (V.minX + V.maxX) / 2, (V.minZ + V.maxZ) / 2
	part(folder, "VillageGround", Vector3.new(width, 4, depth), CFrame.new(cx, -2, cz), Color3.fromRGB(110, 178, 78), Enum.Material.Grass)

	-- The stone ramp down the plateau's west cliff, with a welcome arch at its foot.
	local rampLow, rampHigh = Vector3.new(-163, 0, -112), Vector3.new(-120.5, TOP + 0.2, -112)
	ramp(folder, "VillageRamp", rampLow, rampHigh, 16, Color3.fromRGB(150, 140, 130), Enum.Material.Cobblestone)
	for _, z in { -120.5, -103.5 } do
		part(folder, "ArchPost", Vector3.new(1.4, 14, 1.4), CFrame.new(-168, 7, z), DARK_WOOD, Enum.Material.Wood)
	end
	local arch = part(folder, "ArchSign", Vector3.new(1, 3.4, 20), CFrame.new(-168, 13.2, -112), Color3.fromRGB(60, 40, 25), Enum.Material.WoodPlanks)
	surfaceText(arch, Enum.NormalId.Right, "🌾 BRAINROT VILLAGE 🌾", STRAW)
	surfaceText(arch, Enum.NormalId.Left, "🏠 TO THE BASES 🏠", Color3.fromRGB(150, 220, 255))
	road(folder, Vector3.new(-170, 0, -112), Vector3.new(-181, 0, -78), 8)

	-- The loop road the tractor patrols, with lanterns at the corners and halfway along each side.
	local loop = V.roadLoop
	for i, a in loop do
		local b = loop[i % #loop + 1]
		road(folder, a, b, 9)
		lantern(folder, a + (if a.X < -181 then Vector3.new(-6.5, 0, 0) else Vector3.new(6.5, 0, 0)))
		lantern(folder, (a + b) / 2 + (if math.abs(a.X - b.X) < 1 then Vector3.new(if a.X < -181 then -6.5 else 6.5, 0, 0) else Vector3.new(0, 0, if a.Z < -21 then -6.5 else 6.5)))
	end
	road(folder, Vector3.new(-181, 0, 36), Vector3.new(-190, 0, 70), 8) -- up to the barn

	-- The market plaza: cobbles, the stone well and four striped stalls facing it.
	local cobbles = cylinderUp(folder, "Plaza", 0.3, 60, plaza + Vector3.new(0, 0.12, 0), Color3.fromRGB(165, 155, 145), Enum.Material.Cobblestone)
	cobbles.CanCollide = false
	well(folder, plaza)
	stall(folder, plaza + Vector3.new(-15, 0, -22), plaza, Color3.fromRGB(60, 140, 255), "⚡ UPGRADES", "Shop")
	stall(folder, plaza + Vector3.new(15, 0, -22), plaza, Color3.fromRGB(220, 60, 50), "⚔️ FARM ARMS", "Weapons")
	stall(folder, plaza + Vector3.new(-15, 0, 22), plaza, Color3.fromRGB(190, 80, 230), "♻️ REBIRTH", "Rebirth")
	stall(folder, plaza + Vector3.new(15, 0, 22), plaza, Color3.fromRGB(60, 180, 90), "📖 BRAINROT DEX", "Dex")
	for _, offset in { Vector3.new(-26, 0, 0), Vector3.new(26, 0, 0) } do
		lantern(folder, plaza + offset)
		flowers(folder, plaza + offset + Vector3.new(0, 0, 8))
		flowers(folder, plaza + offset + Vector3.new(0, 0, -8))
	end

	redBarn(folder, V.barn)
	silo(folder, V.silo)
	windmill(folder, V.windmill)
	pond(folder, V.pond, V.pondRadius)
	sheepPen(folder, V.sheepPen)
	tractor(folder, loop[1])
	local board = leaderboard(folder, V.leaderboard)

	for _, p in {
		Vector3.new(-172, 0, 88), Vector3.new(-176, 0, 52), Vector3.new(-133, 0, 70), Vector3.new(-232, 0, 40),
		Vector3.new(-133, 0, -140), Vector3.new(-205, 0, -120), Vector3.new(-150, 0, 18), Vector3.new(-230, 0, -70),
	} do
		haystack(folder, p)
	end
	for _, p in { Vector3.new(-196, 0, 124), Vector3.new(-232, 0, 110), Vector3.new(-170, 0, 128), Vector3.new(-130, 0, 44), Vector3.new(-200, 0, -100) } do
		flowers(folder, p)
	end
	-- Trees around the edge of the village.
	for _, p in {
		Vector3.new(-236, 0, -150), Vector3.new(-214, 0, -158), Vector3.new(-186, 0, -150), Vector3.new(-160, 0, -158), Vector3.new(-136, 0, -150),
		Vector3.new(-236, 0, -110), Vector3.new(-236, 0, 24), Vector3.new(-236, 0, 60), Vector3.new(-136, 0, 140), Vector3.new(-176, 0, 142),
		Vector3.new(-128, 0, 10), Vector3.new(-128, 0, -45),
	} do
		tree(folder, p, 1.1 + rng:NextNumber(0, 0.5))
	end
	-- Fences along the village's outer edges.
	fence(folder, Vector3.new(V.minX + 2, 0, V.minZ + 2), Vector3.new(V.minX + 2, 0, V.maxZ - 2))
	fence(folder, Vector3.new(V.minX + 2, 0, V.maxZ - 2), Vector3.new(V.maxX, 0, V.maxZ - 2))
	farmBackdrop(world.folder)
	return { leaderboard = board }
end

return VillageBuilder
