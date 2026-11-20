-- WeaponService: the five farm weapons a player can buy in the WEAPONS shop to beat back the Brainrot Bandit -
-- Farm Pitchfork, Tractor Exhaust Pipe (smoking), Milk Churn Hammer, Golden Corn Bat and Scarecrow Scythe.
-- Each is a Tool built out of Parts and handed to the Backpack on every spawn. A click / tap swings it (server-
-- side Tool.Activated): the bandit in reach takes damage, gets knocked back and dazed, and every client plays
-- the comic BONK effect (Remotes.Bonk). Weapons are bought once and kept through rebirths.
--
-- Tool space: the Handle's +Z is the business end (points up when held), +X points forward, +Y to the right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local BanditService = require(script.Parent:WaitForChild("BanditService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local WeaponService = {}

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 110, 110)
local WOOD = Color3.fromRGB(150, 105, 60)
local STEEL = Color3.fromRGB(190, 195, 205)
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis (X) to Z

local rng = Random.new()
local nextSwing = {} -- [Player] = os.clock() when the next swing is allowed

local function add(handle: BasePart, name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = handle.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function block(h, name, size, offset, color, material)
	return add(h, name, Enum.PartType.Block, size, offset, color, material)
end

local function ball(h, name, diameter, offset, color, material)
	return add(h, name, Enum.PartType.Ball, Vector3.one * diameter, offset, color, material)
end

-- A cylinder along the tool's Z axis (the shaft direction).
local function shaft(h, name, length, diameter, offset, color, material)
	return add(h, name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), offset * ALONG_Z, color, material)
end

-- A cylinder along the tool's X axis (pointing forward, like a hammer head).
local function across(h, name, length, diameter, offset, color, material)
	return add(h, name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), offset, color, material)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local BUILDERS = {}

function BUILDERS.Pitchfork(h: BasePart)
	h.Size = Vector3.new(0.3, 0.3, 5.4)
	h.Color = WOOD
	h.Material = Enum.Material.Wood
	block(h, "Grip", Vector3.new(0.38, 0.38, 1.1), at(0, 0, -2), Color3.fromRGB(190, 50, 45), Enum.Material.Fabric)
	shaft(h, "Ferrule", 0.6, 0.45, at(0, 0, 2.75), STEEL, Enum.Material.Metal)
	block(h, "Crossbar", Vector3.new(0.25, 1.95, 0.25), at(0, 0, 3.05), STEEL, Enum.Material.Metal)
	for _, y in { -0.85, 0, 0.85 } do
		block(h, "Tine", Vector3.new(0.16, 0.16, 1.7), at(0, y, 3.95), STEEL, Enum.Material.Metal)
		block(h, "TineTip", Vector3.new(0.1, 0.1, 0.3), at(0, y, 4.9), Color3.fromRGB(230, 235, 245), Enum.Material.Metal)
	end
	return Vector3.new(0, 0, -1.6)
end

function BUILDERS.ExhaustPipe(h: BasePart)
	h.Size = Vector3.new(0.45, 0.45, 4.6)
	h.Transparency = 1
	local pipe = Color3.fromRGB(70, 70, 78)
	shaft(h, "Pipe", 4.6, 0.5, at(0, 0, 0), pipe, Enum.Material.Metal)
	shaft(h, "RubberGrip", 1.3, 0.62, at(0, 0, -1.75), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
	shaft(h, "Muffler", 1.9, 1.25, at(0, 0, 1.1), Color3.fromRGB(95, 95, 100), Enum.Material.DiamondPlate)
	for _, z in { 0.25, 1.95 } do
		shaft(h, "Clamp", 0.16, 1.36, at(0, 0, z), Color3.fromRGB(220, 225, 235), Enum.Material.Foil)
	end
	block(h, "RustStripe", Vector3.new(1.27, 0.25, 0.9), at(0, 0, 1.1), Color3.fromRGB(170, 80, 40), Enum.Material.CorrodedMetal)
	-- The bent tail pipe, tilted forward, with a hot glowing mouth that never stops smoking.
	local bend = CFrame.new(0, 0, 2.4) * CFrame.Angles(0, math.rad(30), 0)
	shaft(h, "TailPipe", 1.3, 0.5, bend * CFrame.new(0, 0, 0.6), pipe, Enum.Material.Metal)
	local tip = shaft(h, "Tip", 0.3, 0.62, bend * CFrame.new(0, 0, 1.3), Color3.fromRGB(230, 230, 240), Enum.Material.Foil)
	shaft(h, "HotMouth", 0.06, 0.46, bend * CFrame.new(0, 0, 1.47), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	local smoke = Instance.new("Smoke")
	smoke.Size = 0.7
	smoke.RiseVelocity = 3
	smoke.Opacity = 0.18
	smoke.Color = Color3.fromRGB(70, 70, 75)
	smoke.Parent = tip
	local puffs = Instance.new("ParticleEmitter")
	puffs.Rate = 7
	puffs.Lifetime = NumberRange.new(0.8, 1.4)
	puffs.Speed = NumberRange.new(1, 2.5)
	puffs.SpreadAngle = Vector2.new(20, 20)
	puffs.Size = NumberSequence.new(0.3, 1.4)
	puffs.Transparency = NumberSequence.new(0.35, 1)
	puffs.Color = ColorSequence.new(Color3.fromRGB(60, 60, 65), Color3.fromRGB(140, 140, 145))
	puffs.Parent = tip
	return Vector3.new(0, 0, -1.7)
end

function BUILDERS.ChurnHammer(h: BasePart)
	h.Size = Vector3.new(0.4, 0.4, 4.4)
	h.Color = WOOD
	h.Material = Enum.Material.Wood
	block(h, "Grip", Vector3.new(0.48, 0.48, 1.1), at(0, 0, -1.6), Color3.fromRGB(40, 90, 200), Enum.Material.Fabric)
	-- The milk churn is the hammer head: its flat bottom is the striking face (forward, +X).
	local milk = Color3.fromRGB(228, 232, 238)
	local z = 2.75
	across(h, "Churn", 2.6, 2.0, at(0.2, 0, z), milk, Enum.Material.Metal)
	across(h, "BaseRing", 0.22, 2.16, at(1.45, 0, z), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	across(h, "Stripe", 0.4, 2.06, at(0.3, 0, z), Color3.fromRGB(40, 110, 230), Enum.Material.SmoothPlastic)
	across(h, "Shoulder", 0.5, 1.6, at(-1.25, 0, z), milk, Enum.Material.Metal)
	across(h, "Neck", 0.7, 1.05, at(-1.75, 0, z), milk, Enum.Material.Metal)
	across(h, "Lid", 0.28, 1.25, at(-2.2, 0, z), Color3.fromRGB(210, 40, 40), Enum.Material.SmoothPlastic)
	for _, y in { -1, 1 } do
		block(h, "HandleLoop", Vector3.new(0.5, 0.18, 0.5), at(-0.9, y * 1.05, z), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	end
	local drip = Instance.new("ParticleEmitter")
	drip.Rate = 3
	drip.Lifetime = NumberRange.new(0.6, 1)
	drip.Speed = NumberRange.new(0.5, 1)
	drip.Acceleration = Vector3.new(0, -20, 0)
	drip.Size = NumberSequence.new(0.2, 0.05)
	drip.Color = ColorSequence.new(Color3.new(1, 1, 1))
	drip.Parent = h
	return Vector3.new(0, 0, -1.5)
end

function BUILDERS.CornBat(h: BasePart)
	h.Size = Vector3.new(0.38, 0.38, 2.4)
	h.Color = Color3.fromRGB(160, 110, 40)
	h.Material = Enum.Material.Fabric
	local gold = Color3.fromRGB(255, 205, 45)
	ball(h, "Knob", 0.62, at(0, 0, -1.25), gold, Enum.Material.Foil)
	-- The golden cob: an ellipsoid covered in rows of shiny kernels.
	local cobZ, halfLength, radius = 3.05, 2.1, 0.68
	local cob = block(h, "Cob", Vector3.new(radius * 2, radius * 2, halfLength * 2), at(0, 0, cobZ), gold, Enum.Material.Foil)
	cob.Reflectance = 0.2
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = cob
	for row = -5, 5 do
		local t = row / 6
		local r = radius * math.sqrt(math.max(0, 1 - t * t)) * 0.95
		for i = 0, 7 do
			local angle = (i + (row % 2) * 0.5) / 8 * math.pi * 2
			local kernel = ball(h, "Kernel", 0.36, at(math.cos(angle) * r, math.sin(angle) * r, cobZ + t * halfLength), Color3.fromRGB(255, 228, 90), Enum.Material.Foil)
			kernel.Reflectance = 0.15
		end
	end
	-- Green husk leaves peeling back at the base of the cob.
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		local leaf = CFrame.new(0, 0, 1.25) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, 0.7)
		block(h, "Husk", Vector3.new(0.6, 0.08, 1.6), leaf, Color3.fromRGB(80, 170, 60), Enum.Material.Grass)
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 225, 90)
	sparkles.Parent = cob
	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Range = 8
	glow.Brightness = 1.5
	glow.Parent = cob
	return Vector3.new(0, 0, -0.5)
end

function BUILDERS.Scythe(h: BasePart)
	h.Size = Vector3.new(0.32, 0.32, 6.2)
	h.Color = Color3.fromRGB(115, 80, 48)
	h.Material = Enum.Material.Wood
	local burlap = Color3.fromRGB(190, 160, 105)
	for _, z in { -1.9, 0.5, 2.3 } do
		block(h, "Burlap", Vector3.new(0.42, 0.42, 0.45), at(0, 0, z), burlap, Enum.Material.Fabric)
	end
	block(h, "Peg", Vector3.new(0.2, 0.9, 0.2), at(0, 0.5, 0.5), Color3.fromRGB(115, 80, 48), Enum.Material.Wood)
	block(h, "StrawTuft", Vector3.new(0.7, 0.7, 0.5), at(0, 0, 3.0), Color3.fromRGB(235, 200, 95), Enum.Material.Fabric)
	-- The curved blade: three steel segments sweeping forward and down, with a cursed purple edge.
	local steel = Color3.fromRGB(200, 205, 218)
	local segments = {
		{ x = 0.75, z = 3.0, angle = 8, length = 1.5, width = 0.6 },
		{ x = 2.1, z = 2.78, angle = 24, length = 1.4, width = 0.52 },
		{ x = 3.25, z = 2.25, angle = 46, length = 1.2, width = 0.4 },
		{ x = 4.0, z = 1.45, angle = 70, length = 0.8, width = 0.26 },
	}
	for _, seg in segments do
		local cf = CFrame.new(seg.x, 0, seg.z) * CFrame.Angles(0, math.rad(seg.angle), 0)
		block(h, "Blade", Vector3.new(seg.length, 0.1, seg.width), cf, steel, Enum.Material.Metal)
		block(h, "Edge", Vector3.new(seg.length, 0.12, 0.08), cf * CFrame.new(0, 0, -seg.width / 2), Color3.fromRGB(180, 110, 255), Enum.Material.Neon)
	end
	local wisps = Instance.new("ParticleEmitter")
	wisps.Rate = 8
	wisps.Lifetime = NumberRange.new(0.6, 1.1)
	wisps.Speed = NumberRange.new(0.5, 1.5)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.Size = NumberSequence.new(0.3, 0)
	wisps.LightEmission = 1
	wisps.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255))
	wisps.Parent = h
	return Vector3.new(0, 0, -1.8)
end

function WeaponService.buildTool(id: string): Tool
	local def = GameConfig.WEAPONS[id]
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.ToolTip = def.special
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local gripPos = BUILDERS[id](handle)
	tool.GripPos = gripPos
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool.GripForward = Vector3.new(-1, 0, 0)
	local swoosh = Instance.new("Sound")
	swoosh.Name = "Swing"
	swoosh.SoundId = "rbxasset://sounds/swordslash.wav"
	swoosh.Volume = 0.6
	swoosh.Parent = handle
	return tool
end

-- The swing: a forward chop of the grip plus the default Animate script's "Slash" arm animation.
local function playSwing(tool: Tool, baseGrip: CFrame)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	game:GetService("Debris"):AddItem(anim, 0.5)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Swing")
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 0.9 + rng:NextNumber() * 0.25
		sound:Play()
	end
	tool.Grip = baseGrip * CFrame.Angles(math.rad(75), 0, 0)
	task.delay(0.2, function()
		tool.Grip = baseGrip
	end)
end

local function swing(player: Player, tool: Tool, id: string, baseGrip: CFrame)
	local def = GameConfig.WEAPONS[id]
	local character = tool.Parent
	if not character or Players:GetPlayerFromCharacter(character) ~= player then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if (nextSwing[player] or 0) > now then
		return
	end
	nextSwing[player] = now + def.cooldown
	playSwing(tool, baseGrip)

	local origin = root.Position
	local hits = {}
	for _, bandit in BanditService.targets() do
		if bandit.alive() then
			local target = bandit.root.Position
			local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Magnitude
			local reach = def.range + (if bandit.boss then 4 else 0)
			if flat <= reach and math.abs(target.Y - origin.Y) < (if bandit.boss then 14 else 9) then
				table.insert(hits, { bandit = bandit, distance = flat })
			end
		end
	end
	if #hits == 0 then
		return
	end
	table.sort(hits, function(a, b)
		return a.distance < b.distance
	end)
	local last = if def.sweep then #hits else 1
	for i = 1, last do
		local bandit = hits[i].bandit
		local crit = def.crit ~= nil and rng:NextNumber() < def.crit
		local damage = def.damage * (if crit then def.critMult else 1)
		local position = bandit.root.Position + Vector3.new(0, if bandit.boss then 5 else 2.5, 0)
		Remotes.Bonk:FireAllClients(position, def.color, if crit then "CRIT!" else def.word, player, {
			smoke = def.smoke,
			milk = def.milk,
			crit = crit,
			boss = bandit.boss,
			weapon = id,
		})
		bandit.hit(damage, origin, if crit then Color3.fromRGB(255, 240, 90) else def.color, player, nil)
		bandit.knock(bandit.root.Position - origin, def.knockback, def.stun)
	end
end

local function hasTool(player: Player, id: string): boolean
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") == id then
					return true
				end
			end
		end
	end
	return false
end

function WeaponService.giveTool(state, id: string)
	local player = state.player
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or hasTool(player, id) then
		return
	end
	local tool = WeaponService.buildTool(id)
	local baseGrip = tool.Grip
	tool.Activated:Connect(function()
		swing(player, tool, id, baseGrip)
	end)
	tool.Parent = backpack
end

-- Every owned weapon goes into the hotbar (in shop order) on each spawn.
function WeaponService.giveAll(state)
	for _, id in GameConfig.WEAPON_ORDER do
		if state.weapons[id] then
			WeaponService.giveTool(state, id)
		end
	end
end

function WeaponService.buy(state, id: string)
	local def = GameConfig.WEAPONS[id]
	if not def then
		return
	end
	if state.weapons[id] then
		Remotes.notify(state.player, def.icon .. " You already own the " .. def.name .. " - it's in your hotbar!", BAD)
		return
	end
	if state.cash < def.cost then
		Remotes.notify(state.player, "Not enough cash: the " .. def.name .. " costs " .. Format.cash(def.cost), BAD)
		return
	end
	PlayerState.addCash(state, -def.cost)
	state.weapons[id] = true
	PlayerState.syncWeapons(state)
	PlayerState.sync(state)
	WeaponService.giveTool(state, id)
	Remotes.notify(state.player, def.icon .. " Bought the " .. def.name .. "! Equip it from your hotbar and BONK those bandits!", GOOD)
end

function WeaponService.init()
	Players.PlayerRemoving:Connect(function(player)
		nextSwing[player] = nil
	end)
end

return WeaponService
