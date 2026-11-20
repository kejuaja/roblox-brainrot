-- VillageLife: everything that moves in the Brainrot Village, animated on this client from the server clock
-- (so every player sees the same farmer at the same spot saying the same thing):
--   * the windmill's sails turn (hubs tagged "SpinHub") and the red tractor patrols the loop road
--   * four farmers in straw hats walk their rounds, swing their arms and pop funny speech bubbles
--   * chickens strut and peck by the barn, sheep graze in their pen, ducks paddle on the pond and the creek
--   * flocks of birds circle overhead and butterflies flutter over every flower patch ("FlowerPatch")
-- All of it is local decoration: anchored, non-colliding parts moved in one BulkMoveTo per frame.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local V = GameConfig.VILLAGE
local FONT = Enum.Font.FredokaOne
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local STRAW = Color3.fromRGB(235, 200, 95)
local SKIN = Color3.fromRGB(240, 195, 150)
local DENIM = Color3.fromRGB(55, 90, 170)

local rng = Random.new(4242)
local folder = Instance.new("Folder")
folder.Name = "VillageLife"
folder.Parent = workspace

local creatures = {} -- { rig, update = function(rig, t) -> CFrame root, motion }

---------------------------------------------------------------------------------------------------------------
-- Rigs: a root CFrame plus pieces; a jointed piece turns around its pivot (relative to the root).
---------------------------------------------------------------------------------------------------------------
local function newRig(name: string)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	return { model = model, pieces = {} }
end

local function piece(rig, size: Vector3, offset: CFrame, color: Color3, options)
	local opts = options or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = opts.shadow == true
	p.Size = size
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = rig.model
	local entry = { part = p, offset = offset, joint = opts.joint, pivot = opts.pivot }
	if entry.pivot then
		entry.pivotInverse = entry.pivot:Inverse()
	end
	table.insert(rig.pieces, entry)
	return p
end

-- Joint rotations from the motion values a creature's update returns.
local function jointRotation(joint: string, motion): CFrame
	local swing = motion.swing or 0
	if joint == "legA" then
		return CFrame.Angles(swing, 0, 0)
	elseif joint == "legB" then
		return CFrame.Angles(-swing, 0, 0)
	elseif joint == "armA" then
		return CFrame.Angles(-swing * 0.9, 0, 0)
	elseif joint == "armB" then
		return CFrame.Angles(swing * 0.9, 0, 0)
	elseif joint == "head" then
		return CFrame.Angles(motion.head or 0, 0, 0)
	elseif joint == "wingL" then
		return CFrame.Angles(0, 0, motion.flap or 0)
	elseif joint == "wingR" then
		return CFrame.Angles(0, 0, -(motion.flap or 0))
	end
	return CFrame.identity
end

local function facing(position: Vector3, direction: Vector3): CFrame
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

-- A looping walk through waypoints with a pause at each one, as a pure function of time.
local function makeRoute(points: { Vector3 }, speed: number, pause: number)
	local legs, total = {}, 0
	for i, a in points do
		local b = points[i % #points + 1]
		local walk = (b - a).Magnitude / speed
		table.insert(legs, { a = a, b = b, start = total, walk = walk })
		total += walk + pause
	end
	return function(t: number)
		local tau = t % total
		for _, leg in legs do
			local into = tau - leg.start
			if into >= 0 and into < leg.walk + pause then
				local dir = leg.b - leg.a
				if into < leg.walk then
					return leg.a:Lerp(leg.b, into / leg.walk), dir, true
				end
				return leg.b, dir, false
			end
		end
		return legs[1].a, legs[1].b - legs[1].a, false
	end
end

---------------------------------------------------------------------------------------------------------------
-- Farmers
---------------------------------------------------------------------------------------------------------------
local LINES = {
	"Moo-ve along, partner! 🐄",
	"Has anyone seen my Trattorino Muuu?",
	"That tornado took my hat... AGAIN. 🌪️",
	"The bulls are coming back. Hide the hay! 🐂",
	"Fuse three cows, get one shiny cow. Science! 🧬",
	"I traded a Galaxy chicken for a sandwich. Worth it.",
	"Skibidi... I mean, good morning! ☀️",
	"Ohio Outskirts? I don't go past the creek.",
	"Why do you all carry brainrots on your heads?",
	"The Bandit stole my wheelbarrow. It had a pig in it.",
	"Rebirthed three times. Still farming. 🌾",
	"Check the big board - I'm number zero!",
	"Buy a pitchfork, they said. Bonk bandits, they said.",
	"My windmill spins faster than my brain. 🌀",
	"Psst... the silo is full of corn. Just corn. Probably.",
	"Ducks on the pond, bulls on the field. Normal Tuesday.",
	"That tractor never stops. Nobody knows who drives it.",
	"Rainbow mutation? In THIS economy?",
	"Stay off the field when the sky goes dark!",
	"Cluck cluck. Sorry, I've been with the chickens too long. 🐔",
}

local function bubble(head: BasePart, name: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(230, 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.new(1, 0, 0, 58)
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(60, 50, 40)
	stroke.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = box
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.TextColor3 = Color3.fromRGB(40, 35, 30)
	text.TextScaled = true
	text.TextWrapped = true
	text.Text = ""
	text.Parent = box
	box.Parent = gui
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 0, 58)
	tail.Size = UDim2.fromOffset(14, 14)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.BorderSizePixel = 0
	tail.Visible = false
	tail.Parent = gui
	local tag = Instance.new("TextLabel")
	tag.Position = UDim2.new(0, 0, 1, -24)
	tag.Size = UDim2.new(1, 0, 0, 22)
	tag.BackgroundTransparency = 1
	tag.Font = FONT
	tag.Text = "👨‍🌾 " .. name
	tag.TextColor3 = color
	tag.TextScaled = true
	local tagStroke = Instance.new("UIStroke")
	tagStroke.Thickness = 2
	tagStroke.Parent = tag
	tag.Parent = gui
	gui.Parent = head
	return { box = box, tail = tail, text = text }
end

local function farmer(name: string, shirt: Color3, route, chatOffset: number, beard: boolean)
	local rig = newRig("Farmer_" .. name)
	for _, side in { -1, 1 } do
		local x = side * 0.45
		local joint = if side < 0 then "legA" else "legB"
		local pivot = CFrame.new(x, 2.2, 0)
		piece(rig, Vector3.new(0.8, 2.2, 0.8), CFrame.new(x, 1.1, 0), DENIM, { joint = joint, pivot = pivot })
		piece(rig, Vector3.new(0.85, 0.5, 1.1), CFrame.new(x, 0.25, -0.12), Color3.fromRGB(90, 55, 30), { joint = joint, pivot = pivot })
		local ax = side * 1.35
		local arm = if side < 0 then "armA" else "armB"
		local shoulder = CFrame.new(ax, 4.3, 0)
		piece(rig, Vector3.new(0.7, 2, 0.7), CFrame.new(ax, 3.3, 0), shirt, { joint = arm, pivot = shoulder })
		piece(rig, Vector3.new(0.7, 0.5, 0.7), CFrame.new(ax, 2.1, 0), SKIN, { joint = arm, pivot = shoulder })
	end
	piece(rig, Vector3.new(2, 2.2, 1), CFrame.new(0, 3.3, 0), shirt, { shadow = true })
	piece(rig, Vector3.new(1.5, 1.4, 1.06), CFrame.new(0, 2.9, 0), DENIM)
	for _, x in { -0.5, 0.5 } do
		piece(rig, Vector3.new(0.25, 1.3, 1.07), CFrame.new(x, 3.9, 0), DENIM)
	end
	local head = piece(rig, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 5.1, 0), SKIN)
	for _, x in { -0.3, 0.3 } do
		piece(rig, Vector3.new(0.2, 0.25, 0.05), CFrame.new(x, 5.25, -0.71), Color3.fromRGB(20, 20, 20))
	end
	piece(rig, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 5.0, -0.78), Color3.fromRGB(230, 150, 120))
	if beard then
		piece(rig, Vector3.new(1.3, 0.7, 0.3), CFrame.new(0, 4.55, -0.62), Color3.fromRGB(230, 230, 230))
	else
		piece(rig, Vector3.new(0.8, 0.12, 0.05), CFrame.new(0, 4.75, -0.71), Color3.fromRGB(120, 60, 40))
	end
	piece(rig, Vector3.new(0.15, 3.2, 3.2), CFrame.new(0, 5.85, 0) * UPRIGHT, STRAW, { shape = Enum.PartType.Cylinder, material = Enum.Material.Fabric, shadow = true })
	piece(rig, Vector3.new(0.9, 1.5, 1.5), CFrame.new(0, 6.3, 0) * UPRIGHT, STRAW, { shape = Enum.PartType.Cylinder, material = Enum.Material.Fabric })
	piece(rig, Vector3.new(0.25, 1.56, 1.56), CFrame.new(0, 6.0, 0) * UPRIGHT, Color3.fromRGB(200, 40, 40), { shape = Enum.PartType.Cylinder })
	-- A wheat stalk to chew on.
	piece(rig, Vector3.new(0.08, 0.08, 1.2), CFrame.new(0.35, 4.85, -1.1) * CFrame.Angles(0, math.rad(-20), 0), STRAW)
	local speech = bubble(head, name, shirt:Lerp(Color3.new(1, 1, 1), 0.3))
	local lastLine = -1
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local position, direction, moving = route(t)
			local stride = if moving then math.sin(t * 7) * 0.6 else 0
			-- Speech: every 9 s each farmer says a line for 5 s - the same line on every client.
			local slot = math.floor((t + chatOffset) / 9)
			local talking = ((t + chatOffset) % 9) < 5
			if talking and slot ~= lastLine then
				lastLine = slot
				local index = (slot * 7 + math.floor(chatOffset * 13)) % #LINES + 1
				speech.text.Text = LINES[index]
			end
			speech.box.Visible = talking
			speech.tail.Visible = talking
			local bob = 0.25 + (if moving then math.abs(math.sin(t * 7)) * 0.12 else 0) -- stand on the cobbles
			return facing(position + Vector3.new(0, bob, 0), direction), { swing = stride }
		end,
	})
end

local P = V.plaza
farmer("Gino", Color3.fromRGB(200, 60, 50), makeRoute({
	P + Vector3.new(11, 0, 0), P + Vector3.new(6, 0, 10), P + Vector3.new(-6, 0, 10), P + Vector3.new(-11, 0, 0), P + Vector3.new(-6, 0, -10), P + Vector3.new(6, 0, -10),
}, 4.2, 2.5), 0, true)
farmer("Rosa", Color3.fromRGB(230, 120, 190), makeRoute({
	Vector3.new(-196, 0, 66), Vector3.new(-178, 0, 74), Vector3.new(-140, 0, 80), Vector3.new(-136, 0, 100), Vector3.new(-136, 0, 40), Vector3.new(-176, 0, 44),
}, 5, 3), 3, false)
farmer("Bepi", Color3.fromRGB(70, 160, 80), makeRoute({
	P + Vector3.new(-9, 0, -14), P + Vector3.new(9, 0, -14), P + Vector3.new(14, 0, 0), P + Vector3.new(9, 0, 14), P + Vector3.new(-9, 0, 14), P + Vector3.new(-14, 0, 0),
}, 4.6, 3.5), 6, false)
farmer("Nonna Pia", Color3.fromRGB(150, 90, 210), makeRoute({
	Vector3.new(-200, 0, 110), Vector3.new(-228, 0, 64), Vector3.new(-226, 0, -10), Vector3.new(-205, 0, -66), Vector3.new(-160, 0, -66), Vector3.new(-146, 0, 0), Vector3.new(-176, 0, 48),
}, 4, 3), 1.5, true)

---------------------------------------------------------------------------------------------------------------
-- Animals
---------------------------------------------------------------------------------------------------------------
local function chicken(home: Vector3, seed: number)
	local rig = newRig("Chicken")
	local feathers = if seed % 3 == 0 then Color3.fromRGB(170, 100, 50) else Color3.fromRGB(250, 248, 240)
	piece(rig, Vector3.new(1.3, 1.2, 1.6), CFrame.new(0, 1.3, 0), feathers, { sphere = true, shadow = true })
	piece(rig, Vector3.new(0.3, 0.9, 0.6), CFrame.new(0, 1.9, 0.7) * CFrame.Angles(math.rad(-25), 0, 0), feathers)
	local neck = { joint = "head", pivot = CFrame.new(0, 1.6, -0.5) }
	local function headPiece(size, offset, color, extra)
		local opts = extra or {}
		opts.joint = neck.joint
		opts.pivot = neck.pivot
		piece(rig, size, offset, color, opts)
	end
	headPiece(Vector3.new(0.7, 0.75, 0.7), CFrame.new(0, 2.2, -0.75), feathers, { sphere = true })
	headPiece(Vector3.new(0.12, 0.4, 0.5), CFrame.new(0, 2.65, -0.75), Color3.fromRGB(230, 40, 40))
	headPiece(Vector3.new(0.12, 0.3, 0.2), CFrame.new(0, 1.9, -1.05), Color3.fromRGB(230, 40, 40))
	headPiece(Vector3.new(0.25, 0.18, 0.35), CFrame.new(0, 2.15, -1.2), Color3.fromRGB(255, 190, 40))
	for _, x in { -0.22, 0.22 } do
		headPiece(Vector3.new(0.1, 0.12, 0.05), CFrame.new(x, 2.3, -1.08), Color3.fromRGB(20, 20, 20))
	end
	for _, side in { -1, 1 } do
		piece(rig, Vector3.new(0.14, 0.75, 0.14), CFrame.new(side * 0.3, 0.37, 0), Color3.fromRGB(255, 160, 40), { joint = if side < 0 then "legA" else "legB", pivot = CFrame.new(side * 0.3, 0.75, 0) })
	end
	local phase = seed * 1.7
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local function at(time: number)
				return home + Vector3.new(math.sin(time * 0.35 + phase) * 6, 0, math.cos(time * 0.27 + phase * 1.3) * 4)
			end
			local position = at(t)
			local peck = math.max(0, math.sin(t * 2.6 + phase)) ^ 6
			return facing(position, at(t + 0.2) - position), { swing = math.sin(t * 12 + phase) * 0.5, head = -peck * 1.1 }
		end,
	})
end

local function sheep(home: Vector3, seed: number)
	local rig = newRig("Sheep")
	local wool = Color3.fromRGB(245, 245, 240)
	for _, offset in { Vector3.new(0, 2.3, 0), Vector3.new(0.7, 2.2, 0.8), Vector3.new(-0.7, 2.2, 0.8), Vector3.new(0.7, 2.2, -0.7), Vector3.new(-0.7, 2.2, -0.7), Vector3.new(0, 2.9, 0) } do
		piece(rig, Vector3.one * 2.1, CFrame.new(offset), wool, { shape = Enum.PartType.Ball, material = Enum.Material.Fabric, shadow = true })
	end
	local neck = CFrame.new(0, 2.6, -1.4)
	piece(rig, Vector3.new(1, 1.1, 1.3), CFrame.new(0, 2.5, -2.1), Color3.fromRGB(35, 30, 30), { joint = "head", pivot = neck })
	piece(rig, Vector3.new(1.2, 0.5, 0.9), CFrame.new(0, 3.1, -1.9), wool, { joint = "head", pivot = neck, material = Enum.Material.Fabric })
	for _, x in { -0.65, 0.65 } do
		piece(rig, Vector3.new(0.6, 0.2, 0.35), CFrame.new(x, 2.75, -1.95), Color3.fromRGB(35, 30, 30), { joint = "head", pivot = neck })
	end
	for _, spec in { { -0.6, -0.8, "legA" }, { 0.6, -0.8, "legB" }, { -0.6, 0.8, "legB" }, { 0.6, 0.8, "legA" } } do
		piece(rig, Vector3.new(0.4, 1.3, 0.4), CFrame.new(spec[1], 0.65, spec[2]), Color3.fromRGB(35, 30, 30), { joint = spec[3], pivot = CFrame.new(spec[1], 1.3, spec[2]) })
	end
	local phase = seed * 2.3
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local function at(time: number)
				return home + Vector3.new(math.sin(time * 0.12 + phase) * 8, 0, math.sin(time * 0.09 + phase * 1.7) * 5)
			end
			local position = at(t)
			local graze = (math.sin(t * 0.5 + phase) + 1) / 2
			return facing(position, at(t + 0.5) - position), { swing = math.sin(t * 5 + phase) * 0.3, head = -graze * 0.8 }
		end,
	})
end

local function duck(path: (number) -> Vector3, seed: number)
	local rig = newRig("Duck")
	piece(rig, Vector3.new(1.1, 0.8, 1.8), CFrame.new(0, 0.45, 0), Color3.fromRGB(140, 105, 70), { sphere = true })
	piece(rig, Vector3.new(0.9, 0.35, 1), CFrame.new(0, 0.7, 0.2), Color3.fromRGB(110, 110, 120), { sphere = true })
	piece(rig, Vector3.new(0.4, 0.35, 0.5), CFrame.new(0, 0.65, 0.95) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(40, 40, 45))
	piece(rig, Vector3.new(0.7, 0.75, 0.7), CFrame.new(0, 1.2, -0.75), Color3.fromRGB(40, 140, 70), { sphere = true })
	piece(rig, Vector3.new(0.75, 0.12, 0.2), CFrame.new(0, 0.85, -0.65), Color3.fromRGB(250, 250, 250))
	piece(rig, Vector3.new(0.4, 0.14, 0.5), CFrame.new(0, 1.12, -1.25), Color3.fromRGB(255, 170, 40))
	for _, x in { -0.22, 0.22 } do
		piece(rig, Vector3.new(0.1, 0.12, 0.05), CFrame.new(x, 1.3, -1.08), Color3.fromRGB(10, 10, 10))
	end
	local phase = seed * 0.9
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local position = path(t)
			local bob = math.sin(t * 2 + phase) * 0.06
			return facing(position + Vector3.new(0, bob, 0), path(t + 0.3) - position) * CFrame.Angles(0, 0, math.sin(t * 1.6 + phase) * 0.06), {}
		end,
	})
end

local function bird(center: Vector3, radius: number, speed: number, offset: number, height: number)
	local rig = newRig("Bird")
	local color = Color3.fromRGB(45, 45, 55)
	piece(rig, Vector3.new(0.5, 0.45, 1.4), CFrame.new(0, 0, 0), color, { sphere = true })
	piece(rig, Vector3.new(0.18, 0.12, 0.4), CFrame.new(0, 0, -0.85), Color3.fromRGB(240, 170, 40))
	piece(rig, Vector3.new(0.5, 0.08, 0.6), CFrame.new(0, 0.05, 0.85), color)
	piece(rig, Vector3.new(2.2, 0.08, 0.8), CFrame.new(-1.2, 0.05, 0), color, { joint = "wingL", pivot = CFrame.new(-0.2, 0.05, 0) })
	piece(rig, Vector3.new(2.2, 0.08, 0.8), CFrame.new(1.2, 0.05, 0), color, { joint = "wingR", pivot = CFrame.new(0.2, 0.05, 0) })
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local function at(time: number)
				local angle = time * speed + offset
				return center + Vector3.new(math.cos(angle) * radius, height + math.sin(time * 0.7 + offset) * 3, math.sin(angle) * radius)
			end
			local position = at(t)
			local ahead = at(t + 0.1)
			local bank = CFrame.Angles(0, 0, if speed > 0 then 0.25 else -0.25)
			return CFrame.lookAt(position, ahead) * bank, { flap = math.sin(t * 9 + offset * 5) * 0.7 }
		end,
	})
end

local BUTTERFLY_COLORS = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 240, 90), Color3.fromRGB(240, 120, 220), Color3.fromRGB(255, 255, 255) }
local function butterfly(home: Vector3, seed: number)
	local rig = newRig("Butterfly")
	local color = BUTTERFLY_COLORS[seed % #BUTTERFLY_COLORS + 1]
	piece(rig, Vector3.new(0.12, 0.12, 0.6), CFrame.new(), Color3.fromRGB(30, 25, 25))
	piece(rig, Vector3.new(0.7, 0.04, 0.65), CFrame.new(-0.38, 0, 0), color, { joint = "wingL", pivot = CFrame.new(-0.04, 0, 0), material = Enum.Material.Neon })
	piece(rig, Vector3.new(0.7, 0.04, 0.65), CFrame.new(0.38, 0, 0), color, { joint = "wingR", pivot = CFrame.new(0.04, 0, 0), material = Enum.Material.Neon })
	local phase = seed * 1.31
	table.insert(creatures, {
		rig = rig,
		update = function(t: number)
			local function at(time: number)
				return home + Vector3.new(math.sin(time * 0.8 + phase) * 3.5, 1.8 + math.sin(time * 2.2 + phase) * 0.9, math.cos(time * 0.65 + phase * 2) * 3.5)
			end
			local position = at(t)
			return facing(position, at(t + 0.1) - position), { flap = math.sin(t * 22 + phase) * 1 }
		end,
	})
end

for i = 1, 8 do
	local around = if i <= 6 then V.barn + Vector3.new(-10 + (i - 1) * 4, 0, -20) else P + Vector3.new(-20 + i, 0, 30)
	chicken(around, i)
end
for i = 1, 5 do
	sheep(V.sheepPen + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-1, 1)), i)
end
for i = 1, 5 do
	local radius = 4 + i * 1.6
	local speed = (0.12 + i * 0.03) * (if i % 2 == 0 then -1 else 1)
	local phase = i * 1.3
	duck(function(t)
		local angle = t * speed + phase
		return V.pond + Vector3.new(math.cos(angle) * radius, 0.35, math.sin(angle) * radius)
	end, i)
end
for i = 1, 3 do
	-- Three brave ducks paddling up and down the creek in the field.
	local phase = i * 2.1
	duck(function(t)
		return Vector3.new(math.sin(t * 0.04 + phase) * 75, 0.4, 62 + math.sin(t * 0.3 + phase) * 1.5)
	end, i + 10)
end
for flock, spec in {
	{ center = Vector3.new(-180, 0, 20), radius = 45, speed = 0.22, height = 52 },
	{ center = Vector3.new(0, 0, 140), radius = 70, speed = -0.15, height = 64 },
	{ center = Vector3.new(-90, 0, -60), radius = 38, speed = 0.28, height = 46 },
} do
	for i = 1, 5 do
		bird(spec.center, spec.radius + (i % 2) * 4, spec.speed, flock * 2 + i * 0.09 * (if spec.speed > 0 then -1 else 1), spec.height + (i % 3) * 1.5)
	end
end

local butterflySeed = 0
local function addPatch(patch: Instance)
	if patch:IsA("BasePart") then
		for _ = 1, 2 do
			butterflySeed += 1
			butterfly(patch.Position, butterflySeed)
		end
	end
end
for _, patch in CollectionService:GetTagged("FlowerPatch") do
	addPatch(patch)
end
CollectionService:GetInstanceAddedSignal("FlowerPatch"):Connect(addPatch)

---------------------------------------------------------------------------------------------------------------
-- Machines: windmill sails and the patrolling tractor
---------------------------------------------------------------------------------------------------------------
local loop = V.roadLoop
local loopLength, loopLegs = 0, {}
for i, a in loop do
	local b = loop[i % #loop + 1]
	table.insert(loopLegs, { a = a, b = b, start = loopLength, length = (b - a).Magnitude })
	loopLength += (b - a).Magnitude
end
local function onLoop(distance: number): Vector3
	local d = distance % loopLength
	for _, leg in loopLegs do
		if d <= leg.start + leg.length then
			return leg.a:Lerp(leg.b, (d - leg.start) / leg.length)
		end
	end
	return loop[1]
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	local parts, frames = {}, {}
	for _, creature in creatures do
		local ok, root, motion = pcall(creature.update, t)
		if ok and root then
			for _, entry in creature.rig.pieces do
				local cf
				if entry.joint then
					cf = root * entry.pivot * jointRotation(entry.joint, motion) * entry.pivotInverse * entry.offset
				else
					cf = root * entry.offset
				end
				table.insert(parts, entry.part)
				table.insert(frames, cf)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for _, hub in CollectionService:GetTagged("SpinHub") do
		local base = hub:GetAttribute("BaseCFrame")
		if hub:IsA("BasePart") and typeof(base) == "CFrame" then
			hub.CFrame = base * CFrame.Angles(t * (hub:GetAttribute("SpinRate") or 0.5), 0, 0)
		end
	end
	for _, tractor in CollectionService:GetTagged("PatrolTractor") do
		if tractor:IsA("Model") then
			local distance = t * V.tractorSpeed
			local position = onLoop(distance)
			local ahead = onLoop(distance + 5)
			local bounce = math.sin(t * 9) * 0.06
			tractor:PivotTo(facing(position + Vector3.new(0, bounce, 0), ahead - position))
		end
	end
end)
