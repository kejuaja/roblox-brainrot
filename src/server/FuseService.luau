-- FuseService: the Barn Fuse Machine. A red village barn on a raised wooden deck beside the base plateau (so
-- no disaster can reach it), with a steel fusion tank, three input hoppers and an output pad out front.
-- Walk up, open it, and fuse 3 identical brainrots (same character and same mutation, taken from your Stash,
-- your hands and/or your base) into ONE whose mutation climbs one step up the ladder
--   Normal > Gold > Diamond > Rainbow > Lava > Galaxy > Radioactive > Celestial
-- with a small chance of jumping two steps. Everyone nearby sees the three go in and the result pop out.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local StashService = require(script.Parent:WaitForChild("StashService"))

local FuseService = {}

local CONFIG = GameConfig.FUSE
local TOP = GameConfig.PLATEAU_TOP + 0.2 -- deck height = the plateau's walking surface
local FONT = Enum.Font.FredokaOne
local BARN_RED = Color3.fromRGB(170, 40, 35)
local TRIM = Color3.fromRGB(245, 240, 230)
local WOOD = Color3.fromRGB(150, 100, 60)
local DARK_WOOD = Color3.fromRGB(105, 68, 40)
local BAD = Color3.fromRGB(255, 110, 110)
local FUSE_PURPLE = Color3.fromRGB(190, 110, 255)

local rng = Random.new()
local machine = nil -- { console, inputs = { CFrame x3 }, hopper, output, tankParts, core, sparks, smoke, folder }
local busyUntil = 0

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

local function signText(target: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
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
end

-- Builds the deck, the barn and the machine. The barn's open front faces the bases (-Z).
function FuseService.build(world)
	local folder = Instance.new("Model")
	folder.Name = "BarnFuseMachine"
	folder.Parent = world.folder
	local c = CONFIG.position
	local base = CFrame.new(c.X, TOP, c.Z)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	-- The deck: stone footing up to plateau height with a plank top, flush with the plateau's front edge.
	local deckW, deckD = 22, 24
	part(folder, "DeckFooting", Vector3.new(deckW, TOP, deckD), CFrame.new(c.X, TOP / 2, c.Z), Color3.fromRGB(120, 112, 100), Enum.Material.Cobblestone)
	part(folder, "DeckPlanks", Vector3.new(deckW, 0.2, deckD), at(0, -0.1, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	-- A fence around the three open sides so nobody tumbles off.
	for _, x in { -deckW / 2 + 0.3, deckW / 2 - 0.3 } do
		part(folder, "DeckRail", Vector3.new(0.3, 0.4, deckD - 2), at(x, 2.6, 1), WOOD, Enum.Material.Wood)
		for z = -deckD / 2 + 2, deckD / 2, 4 do
			part(folder, "DeckPost", Vector3.new(0.5, 3, 0.5), at(x, 1.5, z), DARK_WOOD, Enum.Material.Wood)
		end
	end
	part(folder, "DeckRail", Vector3.new(deckW, 0.4, 0.3), at(0, 2.6, deckD / 2 - 0.3), WOOD, Enum.Material.Wood)

	-- The barn: red plank walls with white trim and a pitched roof; open front.
	local w, d, h = 16, 12, 10
	local bz = 4 -- barn centre, towards the back of the deck
	part(folder, "BackWall", Vector3.new(w, h, 0.6), at(0, h / 2, bz + d / 2), BARN_RED, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		local wall = part(folder, "SideWall", Vector3.new(0.6, h, d), at(side * w / 2, h / 2, bz), BARN_RED, Enum.Material.WoodPlanks)
		-- White X brace on the outside of each side wall.
		for _, tilt in { -1, 1 } do
			part(folder, "Brace", Vector3.new(0.2, 0.5, math.sqrt(d * d + h * h) - 1), wall.CFrame * CFrame.new(side * 0.4, 0, 0) * CFrame.Angles(tilt * math.atan2(h, d), 0, 0), TRIM, Enum.Material.WoodPlanks)
		end
		part(folder, "FrontPillar", Vector3.new(2.2, h, 0.8), at(side * (w / 2 - 1.1), h / 2, bz - d / 2), BARN_RED, Enum.Material.WoodPlanks)
		part(folder, "PillarTrim", Vector3.new(0.4, h, 0.9), at(side * (w / 2 - 2.2), h / 2, bz - d / 2), TRIM, Enum.Material.WoodPlanks)
	end
	part(folder, "Lintel", Vector3.new(w, 1.6, 0.8), at(0, h - 0.8, bz - d / 2), TRIM, Enum.Material.WoodPlanks)
	local slope = math.rad(34)
	local halfSpan = w / 2 + 1
	local roofLength = halfSpan / math.cos(slope)
	for _, side in { -1, 1 } do
		part(folder, "Roof", Vector3.new(roofLength, 0.8, d + 2), at(side * halfSpan / 2, h + math.tan(slope) * halfSpan / 2, bz) * CFrame.Angles(0, 0, side * -slope), Color3.fromRGB(75, 55, 50), Enum.Material.Slate)
	end
	-- Gable triangles (front and back) under the roof, built as stepped planks.
	local rise = math.tan(slope) * (w / 2)
	local steps = 7
	for _, zEnd in { -1, 1 } do
		for i = 0, steps - 1 do
			local y0 = rise * i / steps
			local width = w * (1 - (i + 0.5) / steps)
			part(folder, "Gable", Vector3.new(width, rise / steps, 0.6), at(0, h + y0 + rise / steps / 2, bz + zEnd * (d / 2)), BARN_RED, Enum.Material.WoodPlanks)
		end
	end
	local loft = part(folder, "HayLoftDoor", Vector3.new(3, 2.4, 0.3), at(0, h + 1.6, bz - d / 2 - 0.2), TRIM, Enum.Material.WoodPlanks)
	loft.Shape = Enum.PartType.Block
	local sign = part(folder, "Sign", Vector3.new(14, 2.6, 0.4), at(0, h + 4.4, bz - d / 2 - 0.6), Color3.fromRGB(40, 25, 55))
	signText(sign, Enum.NormalId.Front, "🧬 BARN FUSE MACHINE 🧬", Color3.fromRGB(255, 220, 90))
	local how = part(folder, "HowTo", Vector3.new(7, 3, 0.3), at(-w / 2 - 1.6, 2.6, -8), Color3.fromRGB(245, 235, 210), Enum.Material.WoodPlanks)
	signText(how, Enum.NormalId.Front, "3 SAME BRAINROTS\n= 1 MUTATION UP!\n12% chance: +2 🎰", Color3.fromRGB(60, 30, 20))
	part(folder, "HowToPost", Vector3.new(0.4, 2.2, 0.4), at(-w / 2 - 1.6, 1.1, -7.8), DARK_WOOD, Enum.Material.Wood)
	-- Hay bales stacked by the door for village charm.
	for i, offset in { Vector3.new(9.4, 0.9, -7), Vector3.new(9.4, 0.9, -4.6), Vector3.new(9.4, 2.7, -5.8) } do
		part(folder, "HayBale" .. i, Vector3.new(2.4, 1.8, 2.2), at(offset.X, offset.Y, offset.Z), Color3.fromRGB(235, 200, 95), Enum.Material.Fabric)
	end

	-- The machine inside the barn: a steel tank with a glass dome and a glowing core, three hoppers on top.
	local tankZ = bz + 1
	local tankParts = {}
	local function tankPart(name, size, cf, color, material)
		local p = part(folder, name, size, cf, color, material)
		table.insert(tankParts, { part = p, cframe = cf })
		return p
	end
	tankPart("TankBase", Vector3.new(1.2, 6.5, 6.5), at(0, 0.6, tankZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 70, 80), Enum.Material.DiamondPlate).Shape = Enum.PartType.Cylinder
	tankPart("Tank", Vector3.new(4.6, 5.2, 5.2), at(0, 3.5, tankZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(175, 180, 195), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	tankPart("TankBand", Vector3.new(0.5, 5.4, 5.4), at(0, 3.5, tankZ) * CFrame.Angles(0, 0, math.rad(90)), FUSE_PURPLE, Enum.Material.Neon).Shape = Enum.PartType.Cylinder
	local dome = tankPart("Dome", Vector3.new(4.6, 4.6, 4.6), at(0, 5.9, tankZ), Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.55
	local core = tankPart("Core", Vector3.new(2.2, 2.2, 2.2), at(0, 5.9, tankZ), FUSE_PURPLE, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	local coreLight = Instance.new("PointLight")
	coreLight.Color = FUSE_PURPLE
	coreLight.Range = 16
	coreLight.Brightness = 2
	coreLight.Parent = core
	local inputs = {}
	for i, x in { -2.6, 0, 2.6 } do
		local hopper = tankPart("Hopper" .. i, Vector3.new(1.6, 2.2, 1.6), at(x, 8.6, tankZ + 1.2) * CFrame.Angles(math.rad(180), 0, 0), Color3.fromRGB(120, 125, 140), Enum.Material.Metal)
		tankPart("Tube" .. i, Vector3.new(0.5, 2.4, 0.5), at(x * 0.6, 7.3, tankZ + 0.8) * CFrame.Angles(0, 0, math.rad(-x * 10)), FUSE_PURPLE, Enum.Material.Neon)
		hopper.Name = "Hopper"
		-- The input pads on the barn floor in front of the machine.
		local pad = part(folder, "InputPad" .. i, Vector3.new(0.3, 3.4, 3.4), at(x * 1.45, 0.15, -3.2) * CFrame.Angles(0, 0, math.rad(90)), FUSE_PURPLE, Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder
		pad.CanCollide = false
		pad.Transparency = 0.3
		inputs[i] = { pad = at(x * 1.45, 0.3, -3.2), hopper = at(x, 9.6, tankZ + 1.2) }
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Rate = 60
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), FUSE_PURPLE)
	sparks.Parent = core
	local chimney = part(folder, "Chimney", Vector3.new(1.6, 5, 1.6), at(5, h + 4.5, bz + 3), Color3.fromRGB(120, 110, 105), Enum.Material.Brick)
	local smoke = Instance.new("Smoke")
	smoke.Size = 2
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(200, 170, 255)
	smoke.Parent = chimney

	-- The output pad: the fused brainrot pops out here.
	local outputPad = part(folder, "OutputPad", Vector3.new(0.3, 5, 5), at(0, 0.15, -9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	outputPad.Shape = Enum.PartType.Cylinder
	outputPad.CanCollide = false
	outputPad.Transparency = 0.25

	-- The console: a pedestal with a big red FUSE button and the prompt.
	local console = part(folder, "Console", Vector3.new(2.4, 3, 1.6), at(6, 1.5, -7), Color3.fromRGB(60, 60, 75), Enum.Material.DiamondPlate)
	local button = part(folder, "FuseButton", Vector3.new(0.5, 1.2, 1.2), at(6, 3.2, -7) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
	button.Shape = Enum.PartType.Cylinder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusePrompt"
	prompt.ActionText = "Open Fuse Machine"
	prompt.ObjectText = "🧬 Barn Fuse Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = console
	prompt.Triggered:Connect(function(player)
		local state = PlayerState.get(player)
		if state then
			FuseService.sendMenu(state)
		end
	end)
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(240, 46)
	label.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 90
	label.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.Text = "🧬 FUSE 3 → 1 ⬆"
	text.TextColor3 = Color3.fromRGB(220, 170, 255)
	text.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = label
	label.Parent = button

	machine = {
		folder = folder,
		console = console,
		inputs = inputs,
		output = at(0, 0.3, -9),
		tankParts = tankParts,
		core = core,
		coreLight = coreLight,
		sparks = sparks,
		smoke = smoke,
	}
end

-- Every (character, mutation) the player holds at least two of across base, hands and Stash, best first,
-- with how many sit in each place.
function FuseService.groups(state)
	local counts, order = {}, {}
	local function count(entry, source: string)
		local key = entry.id .. "|" .. entry.mutation
		if not counts[key] then
			counts[key] = { id = entry.id, mutation = entry.mutation, count = 0, base = 0, hands = 0, stash = 0 }
			table.insert(order, counts[key])
		end
		counts[key].count += 1
		counts[key][source] += 1
	end
	for _, entry in state.slots do
		count(entry, "base")
	end
	for _, entry in state.carried do
		count(entry, "hands")
	end
	for _, entry in state.stash do
		count(entry, "stash")
	end
	local groups = {}
	for _, group in order do
		if group.count >= 2 then
			table.insert(groups, group)
		end
	end
	table.sort(groups, function(a, b)
		local ra = Catalog.RARITY_INDEX[Catalog.BY_ID[a.id].rarity]
		local rb = Catalog.RARITY_INDEX[Catalog.BY_ID[b.id].rarity]
		if (a.count >= 3) ~= (b.count >= 3) then
			return a.count >= 3
		end
		if ra ~= rb then
			return ra > rb
		end
		return (Catalog.MUTATION_INDEX[a.mutation] or 0) > (Catalog.MUTATION_INDEX[b.mutation] or 0)
	end)
	return groups
end

function FuseService.sendMenu(state)
	Remotes.FuseMenu:FireClient(state.player, FuseService.groups(state), CONFIG.doubleChance)
end

local function nearMachine(state): boolean
	local character = state.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return machine ~= nil and root ~= nil and (root.Position - machine.console.Position).Magnitude <= CONFIG.range
end

local function displayModel(id: string, mutation: string, scale: number, label: boolean): Model
	local model = Factory.build(id, mutation, { scale = scale, noLabel = not label, labelDistance = 90 })
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	model.Parent = machine.folder
	return model
end

-- The show: the three brainrots float up into the hoppers, the tank shakes and sparks, and the result pops
-- out on the golden output pad with a big tier label, then vanishes (the real one is already in your base).
local function animate(id: string, fromMutation: string, toMutation: string, steps: number)
	local inputs = {}
	for i = 1, 3 do
		local model = displayModel(id, fromMutation, 0.4, false)
		model:PivotTo(machine.inputs[i].pad)
		inputs[i] = model
	end
	task.wait(0.4)
	local rise = 0.9
	local start = os.clock()
	while os.clock() - start < rise do
		local alpha = math.min((os.clock() - start) / rise, 1)
		for i, model in inputs do
			local from, to = machine.inputs[i].pad, machine.inputs[i].hopper
			local position = from.Position:Lerp(to.Position, alpha * alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 3, 0)
			model:PivotTo(CFrame.new(position) * CFrame.Angles(0, alpha * math.pi * 4, 0))
			model:ScaleTo(math.max(0.05, 1 - alpha * 0.9))
		end
		task.wait()
	end
	for _, model in inputs do
		model:Destroy()
	end

	-- Rumble: the tank shakes, the core flickers and sparks fly.
	machine.sparks.Enabled = true
	machine.smoke.Opacity = 0.35
	local shake = 1.3
	start = os.clock()
	while os.clock() - start < shake do
		for _, item in machine.tankParts do
			item.part.CFrame = item.cframe * CFrame.new(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.15, 0.15))
		end
		local flicker = Catalog.MUTATION_BY_KEY[if rng:NextNumber() < 0.5 then fromMutation else toMutation].color
		machine.core.Color = flicker
		machine.coreLight.Color = flicker
		machine.coreLight.Brightness = 2 + rng:NextNumber() * 4
		task.wait(0.05)
	end
	for _, item in machine.tankParts do
		item.part.CFrame = item.cframe
	end
	machine.sparks.Enabled = false
	machine.smoke.Opacity = 0.08
	machine.core.Color = FUSE_PURPLE
	machine.coreLight.Color = FUSE_PURPLE
	machine.coreLight.Brightness = 2

	-- Pop! The result rises from the output pad.
	local boom = Instance.new("Explosion")
	boom.Position = machine.output.Position + Vector3.new(0, 2, 0)
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace
	local result = displayModel(id, toMutation, 0.75, true)
	result:PivotTo(machine.output * CFrame.Angles(0, math.pi, 0))
	local mutation = Catalog.MUTATION_BY_KEY[toMutation]
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (result:GetAttribute("Height") or 4) + 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.Text = if steps >= 2 then "🎰 JACKPOT +2 → " .. string.upper(mutation.label) .. "!" else "⬆ +1 → " .. string.upper(mutation.label) .. "!"
	text.TextColor3 = mutation.color
	text.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = gui
	gui.Parent = result.PrimaryPart
	local burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(14, 24)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.LightEmission = 1
	burst.Color = ColorSequence.new(mutation.color, Color3.new(1, 1, 1))
	burst.Parent = result.PrimaryPart
	burst:Emit(if steps >= 2 then 90 else 45)
	local spinStart = os.clock()
	while os.clock() - spinStart < 3.2 and result.Parent do
		local t = os.clock() - spinStart
		result:PivotTo(machine.output * CFrame.new(0, math.min(t * 3, 1.5), 0) * CFrame.Angles(0, math.pi + t * 2, 0))
		task.wait()
	end
	Debris:AddItem(result, 0)
end

function FuseService.fuse(state, id: string, mutation: string)
	if type(id) ~= "string" or type(mutation) ~= "string" or not Catalog.BY_ID[id] or not Catalog.MUTATION_BY_KEY[mutation] then
		return
	end
	local player = state.player
	if not nearMachine(state) then
		Remotes.notify(player, "🧬 Walk up to the Barn Fuse Machine (next to the plateau, by the village) to fuse!", BAD)
		return
	end
	if not Catalog.fuseUpgrade(mutation, 1) then
		local why = if mutation == "TrainGod" then "TRAIN GOD brainrots can't be fused!" else "Celestial is already the top mutation!"
		Remotes.notify(player, "🧬 " .. why, BAD)
		return
	end
	if os.clock() < busyUntil then
		Remotes.notify(player, "⏳ The Fuse Machine is still rumbling - try again in a moment!", BAD)
		return
	end
	-- Gather 3 matching brainrots: the Stash first, then your hands, then the base (so the base keeps earning).
	local stashPositions, carriedPositions, slotIndexes = {}, {}, {}
	local function taken(): number
		return #stashPositions + #carriedPositions + #slotIndexes
	end
	for position, entry in state.stash do
		if taken() < 3 and entry.id == id and entry.mutation == mutation then
			table.insert(stashPositions, position)
		end
	end
	for position, entry in state.carried do
		if taken() < 3 and entry.id == id and entry.mutation == mutation then
			table.insert(carriedPositions, position)
		end
	end
	for index, entry in state.slots do
		if taken() < 3 and entry.id == id and entry.mutation == mutation then
			table.insert(slotIndexes, index)
		end
	end
	if taken() < 3 then
		Remotes.notify(player, "🧬 You need 3x " .. Catalog.displayName(id, mutation) .. " (base, hands or Stash) to fuse!", BAD)
		FuseService.sendMenu(state)
		return
	end
	busyUntil = os.clock() + CONFIG.busySeconds

	if #stashPositions > 0 then
		StashService.removeAt(state, stashPositions)
	end
	if #carriedPositions > 0 then
		CarryService.removeAt(state, carriedPositions)
	end
	for _, index in slotIndexes do
		BaseService.removeSlot(state, index)
	end
	local steps = if rng:NextNumber() < CONFIG.doubleChance and Catalog.fuseUpgrade(mutation, 2) ~= Catalog.fuseUpgrade(mutation, 1) then 2 else 1
	local result = Catalog.fuseUpgrade(mutation, steps) :: string
	-- The result goes to the base if a pedestal is free, else your hands, else the Stash (one of them always
	-- has room: the three ingredients just left it).
	local where
	if BaseService.place(state, id, result) then
		where = "It's in your base."
	elseif not CarryService.isFull(state) then
		CarryService.give(state, id, result)
		where = "It's in your hands."
	else
		StashService.add(state, id, result)
		where = "It's in your Stash."
	end
	PlayerState.sync(state)

	local name = Catalog.displayName(id, result)
	local color = Catalog.MUTATION_BY_KEY[result].color
	if steps >= 2 then
		Remotes.announce("🎰 FUSE JACKPOT! " .. player.DisplayName .. " jumped TWO tiers and made a " .. name .. "!", color)
	else
		Remotes.notify(player, "🧬 FUSED! 3 brainrots became a " .. name .. "!" .. " " .. where, color)
		if (Catalog.FUSE_TIER[result] or 0) >= 6 then
			Remotes.announce("🧬 " .. player.DisplayName .. " fused a " .. name .. "!", color)
		end
	end
	FuseService.sendMenu(state)
	task.spawn(function()
		local ok, err = pcall(animate, id, mutation, result, steps)
		if not ok then
			warn("[FuseService] animation:", err)
		end
	end)
end

return FuseService
