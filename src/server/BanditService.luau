-- BanditService: steal pressure even in a solo server. A masked Brainrot Bandit NPC with an HP bar sneaks up
-- the ramp to a random player's base to grab the best brainrot. The base's own brainrots fight back: every
-- one in range attacks with its ATK (GUARD passives multiply it), and players can BONK him bare-handed or
-- smack him with a bought weapon (WeaponService), which also knocks him back and dazes him.
-- A LOCKED base makes him bounce off; at 0 HP he drops the loot back into the base and pays a reward.
--
-- BOSS BANDIT: right after every 3rd farm disaster a giant crowned bandit raids instead - several times the HP,
-- slower, barely knocked back - and his KO pays a big cash reward (helpers get a share) plus a Legendary-or-
-- better boss loot brainrot dropped at the foot of the ramp.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local BrainrotSpawner = require(script.Parent:WaitForChild("BrainrotSpawner"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local BanditService = {}

local CONFIG = GameConfig.BANDIT
local BOSS = GameConfig.BOSS
local RED = Color3.fromRGB(255, 90, 90)
local GOOD = Color3.fromRGB(120, 255, 140)
local BONK_COLOR = Color3.fromRGB(255, 220, 80)
local CROWN_GOLD = Color3.fromRGB(255, 200, 40)
local BODY_HEIGHT = 3.3

local raids = 0
local bossActive = false
local folder: Instance = workspace

-- Every bandit on the map: [Model] = { model, root, boss, alive(), hit(...), knock(...) }. WeaponService reads it.
local active = {}

function BanditService.targets()
	return active
end

local function piece(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Anchored = false
	p.Parent = model
	return p
end

-- A black-clad bandit with a glowing red visor, a loot sack and a name + HP bar billboard. The boss is the
-- same bandit scaled up, in a purple cape, with a jewelled gold crown.
local function buildBandit(maxHp: number, boss: boolean)
	local k = if boss then BOSS.scale else 1
	local model = Instance.new("Model")
	model.Name = if boss then "BossBandit" else "BrainrotBandit"
	local black = Color3.fromRGB(25, 25, 30)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * k, y * k, z * k)
	end
	local root = piece(model, "Torso", Vector3.new(2.4, 2.6, 1.4) * k, at(0, 3.3, 0), black)
	piece(model, "Head", Vector3.new(1.8, 1.8, 1.8) * k, at(0, 5.5, 0), black)
	piece(model, "Visor", Vector3.new(1.6, 0.4, 0.2) * k, at(0, 5.6, -0.92), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	for _, side in { -1, 1 } do
		piece(model, "Leg", Vector3.new(0.9, 2, 0.9) * k, at(side * 0.6, 1, 0), black)
		piece(model, "Arm", Vector3.new(0.7, 2.2, 0.7) * k, at(side * 1.6, 3.4, 0), black)
	end
	piece(model, "Sack", Vector3.new(2, 2, 1.4) * k, at(0, 3.6, 1.2), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric)
	if boss then
		piece(model, "Cape", Vector3.new(2.6, 3.4, 0.2) * k, at(0, 3.1, 0.85), Color3.fromRGB(110, 30, 150), Enum.Material.Fabric)
		piece(model, "CrownBand", Vector3.new(2, 0.5, 2) * k, at(0, 6.65, 0), CROWN_GOLD, Enum.Material.Foil)
		for _, x in { -0.75, 0, 0.75 } do
			for _, z in { -0.75, 0.75 } do
				local spike = piece(model, "CrownSpike", Vector3.new(0.35, 0.8, 0.35) * k, at(x, 7.2, z) * CFrame.Angles(0, math.rad(45), 0), CROWN_GOLD, Enum.Material.Foil)
				spike.Reflectance = 0.3
			end
		end
		local gem = piece(model, "CrownGem", Vector3.new(0.5, 0.5, 0.2) * k, at(0, 6.7, -1.02), Color3.fromRGB(255, 40, 90), Enum.Material.Neon)
		gem.Shape = Enum.PartType.Block
		local glow = Instance.new("PointLight")
		glow.Color = CROWN_GOLD
		glow.Range = 18
		glow.Brightness = 2
		glow.Parent = gem
		local aura = Instance.new("ParticleEmitter")
		aura.Rate = 18
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(2, 4)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new(0.7, 0)
		aura.LightEmission = 1
		aura.Color = ColorSequence.new(Color3.fromRGB(200, 90, 255), CROWN_GOLD)
		aura.Parent = root
	end
	for _, part in model:GetChildren() do
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

	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.fromRGB(255, 60, 60)
	flash.FillTransparency = 1
	flash.OutlineTransparency = if boss then 0.2 else 1
	flash.OutlineColor = CROWN_GOLD
	flash.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "BanditLabel"
	gui.Size = if boss then UDim2.fromOffset(320, 84) else UDim2.fromOffset(240, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5 * k, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = if boss then 260 else 160
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, if boss then 42 else 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = if boss then "👑 BOSS BANDIT 👑" else "🥷 BRAINROT BANDIT"
	title.TextColor3 = if boss then CROWN_GOLD else RED
	title.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = title
	title.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "HpBar"
	bar.Position = UDim2.fromOffset(20, if boss then 46 else 38)
	bar.Size = UDim2.new(1, -40, 0, if boss then 32 else 26)
	bar.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
	bar.BorderSizePixel = 0
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 2
	barStroke.Color = if boss then CROWN_GOLD else Color3.new(0, 0, 0)
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill
	fill.Parent = bar
	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.FredokaOne
	hpText.Text = "HP " .. maxHp .. " / " .. maxHp
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextScaled = true
	hpText.ZIndex = 2
	local hpStroke = Instance.new("UIStroke")
	hpStroke.Thickness = 2
	hpStroke.Parent = hpText
	hpText.Parent = bar
	bar.Parent = gui
	gui.Parent = root
	return model, root, { fill = fill, text = hpText, flash = flash }
end

-- Ground height under a point: the plateau, the ramp down to the field, or the field itself.
local function groundY(x: number, z: number): number
	if z <= GameConfig.PLATEAU_EDGE_Z then
		return GameConfig.PLATEAU_TOP
	elseif z < -40 and math.abs(x) <= GameConfig.FIELD_HALF_WIDTH then
		return GameConfig.PLATEAU_TOP * (-40 - z) / 35
	end
	return 0
end

local function flatLook(position: Vector3, direction: Vector3): CFrame
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.05 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

-- Step-walks towards `to` every frame, so a knockback can shove him off course and a daze can freeze him.
local function walk(bandit, to: Vector3)
	local root = bandit.root
	while bandit.alive() do
		local dt = task.wait()
		if os.clock() >= bandit.stunUntil then
			local position = root.Position
			local delta = to - position
			local step = bandit.speed * dt
			if delta.Magnitude <= step then
				root.CFrame = flatLook(to, delta)
				return
			end
			local nextPosition = position + delta.Unit * step
			root.CFrame = flatLook(nextPosition, delta)
		end
	end
end

local function dropBossLoot(position: Vector3, finder: string)
	local def = Catalog.rollCharacter(3, BOSS.lootMinRarity)
	local mutation = Catalog.rollMutation(BOSS.lootMutationBoost)
	local spot = Vector3.new(math.clamp(position.X, -80, 80), 0.2, -26)
	BrainrotSpawner.spawn(spot, def.id, mutation.key)
	-- A golden pillar of light marks the loot for everyone on the map.
	local beam = Instance.new("Part")
	beam.Name = "BossLootBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(120, 3, 3)
	beam.CFrame = CFrame.new(spot + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = CROWN_GOLD
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.45
	beam.Parent = folder
	Debris:AddItem(beam, 25)
	local rarity = Catalog.rarityOf(def.id)
	Remotes.announce("👑 BOSS LOOT: a " .. rarity.key .. " " .. Catalog.displayName(def.id, mutation.key) .. " dropped at the foot of the ramp! (" .. finder .. ")", rarity.color)
end

local function pickTarget(boss: boolean)
	local withBrainrots, withPlot = {}, {}
	for _, state in PlayerState.all() do
		if state.plot then
			table.insert(withPlot, state)
			if next(state.slots) then
				table.insert(withBrainrots, state)
			end
		end
	end
	if #withBrainrots > 0 then
		return withBrainrots[math.random(1, #withBrainrots)]
	end
	-- The boss comes for an empty base too: the fight (and the loot) is the point.
	if boss and #withPlot > 0 then
		return withPlot[math.random(1, #withPlot)]
	end
	return nil
end

function BanditService.raid(parent: Instance, boss: boolean?)
	local isBoss = boss == true
	local state = pickTarget(isBoss)
	if not state then
		return
	end
	raids += 1
	local plot = state.plot
	local owner = state.player
	local maxHp = CONFIG.baseHp + CONFIG.hpPerRaid * (raids - 1)
	if isBoss then
		maxHp *= BOSS.hpMult
		bossActive = true
	end
	local hp = maxHp
	if isBoss then
		Remotes.announce("👑 A GIANT BOSS BANDIT (" .. maxHp .. " HP) rides in behind the disaster - heading for " .. owner.DisplayName .. "'s base! Grab your weapons!", CROWN_GOLD)
	else
		Remotes.notify(owner, "🥷 A BRAINROT BANDIT (" .. maxHp .. " HP) is sneaking to your base! LOCK it or BONK him!", RED)
		for _, other in Players:GetPlayers() do
			if other ~= owner then
				Remotes.notify(other, "🥷 A bandit is raiding " .. owner.DisplayName .. "'s base!", RED)
			end
		end
	end

	local model, root, hud = buildBandit(maxHp, isBoss)
	local scale = if isBoss then BOSS.scale else 1
	local bodyHeight = BODY_HEIGHT * scale
	local path = {
		Vector3.new(plot.cx, bodyHeight, -10),
		Vector3.new(plot.cx, bodyHeight, -40),
		Vector3.new(plot.cx, GameConfig.PLATEAU_TOP + bodyHeight, -76),
		Vector3.new(plot.cx, GameConfig.PLATEAU_TOP + bodyHeight, GameConfig.SLOT_Z[1] + 4),
	}
	root.CFrame = CFrame.new(path[1])
	model.Parent = parent

	local loot = nil -- { id, mutation }
	local defeated = false
	local helpers = {} -- [Player] = true for everyone who hit him
	local bandit = {
		model = model,
		root = root,
		boss = isBoss,
		speed = CONFIG.speed * (if isBoss then BOSS.speedMult else 1),
		stunUntil = 0,
	}
	function bandit.alive()
		return not defeated and model.Parent ~= nil
	end
	active[model] = bandit

	local function finish()
		active[model] = nil
		if isBoss then
			bossActive = false
		end
	end

	local function defeat(killer: Player?)
		defeated = true
		finish()
		local reward = math.max(50, math.floor(PlayerState.income(state) * GameConfig.BANDIT_BONK_SECONDS))
		if isBoss then
			reward = math.max(BOSS.minReward, math.floor(PlayerState.income(state) * BOSS.rewardSeconds))
		end
		local rewarded = if killer then PlayerState.get(killer) else nil
		rewarded = rewarded or (if state.plot then state else nil)
		if rewarded then
			PlayerState.addCash(rewarded, reward)
			PlayerState.sync(rewarded)
			Remotes.CashPopup:FireClient(rewarded.player, reward)
		end
		if isBoss then
			local share = math.floor(reward * BOSS.helperShare)
			for helper in helpers do
				local helperState = PlayerState.get(helper)
				if helperState and helperState ~= rewarded and helper.Parent then
					PlayerState.addCash(helperState, share)
					PlayerState.sync(helperState)
					Remotes.CashPopup:FireClient(helper, share)
					Remotes.notify(helper, "🤝 Boss helper share: +" .. Format.cash(share), GOOD)
				end
			end
		end
		if loot and state.plot then
			BaseService.place(state, loot.id, loot.mutation)
			PlayerState.sync(state)
			Remotes.notify(owner, "🎉 Your " .. Catalog.displayName(loot.id, loot.mutation) .. " is back home!", GOOD)
		end
		local who = if killer then killer.DisplayName else owner.DisplayName .. "'s brainrots"
		if isBoss then
			Remotes.announce("👑💥 " .. who .. " TOOK DOWN THE BOSS BANDIT! +" .. Format.cash(reward), CROWN_GOLD)
		else
			Remotes.announce("💥 " .. who .. " KO'd the Brainrot Bandit! +" .. Format.cash(reward), GOOD)
		end
		local boom = Instance.new("Explosion")
		boom.Position = root.Position
		boom.BlastRadius = if isBoss then 14 else 4
		boom.BlastPressure = 0
		boom.DestroyJointRadiusPercent = 0
		boom.Parent = workspace
		if isBoss then
			dropBossLoot(root.Position, who)
		end
		model:Destroy()
	end

	-- Every source of damage ends here: defenders, the bare-hand BONK prompt and weapons.
	function bandit.hit(amount: number, from: Vector3, color: Color3, hitter: Player?, attacker: Instance?)
		if defeated then
			return
		end
		amount = math.max(1, math.floor(amount + 0.5))
		if hitter then
			helpers[hitter] = true
		end
		hp = math.max(0, hp - amount)
		hud.fill.Size = UDim2.fromScale(hp / maxHp, 1)
		hud.fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(90, 230, 90), hp / maxHp)
		hud.text.Text = "HP " .. math.ceil(hp) .. " / " .. maxHp
		hud.flash.FillTransparency = 0.3
		task.delay(0.12, function()
			hud.flash.FillTransparency = 1
		end)
		Remotes.Combat:FireAllClients(attacker, from, root.Position, amount, color)
		if hp <= 0 then
			defeat(hitter)
		end
	end

	-- Shoves him `distance` studs along `direction` (flat) with a recoil tilt, then dazes him for `stun` s.
	function bandit.knock(direction: Vector3, distance: number, stun: number)
		if defeated then
			return
		end
		local resist = if isBoss then BOSS.knockbackResist else 1
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.05 then
			flat = -root.CFrame.LookVector
		end
		flat = flat.Unit
		local from = root.Position
		local target = from + flat * distance * resist
		local x = math.clamp(target.X, -114, 114)
		local z = math.clamp(target.Z, GameConfig.PLOT_MIN_Z, GameConfig.FIELD_MAX_Z)
		local landing = Vector3.new(x, groundY(x, z) + bodyHeight, z)
		local facing = flatLook(landing, -flat)
		local duration = 0.18
		bandit.stunUntil = math.max(bandit.stunUntil, os.clock() + duration + 0.15 + stun * (if isBoss then 0.5 else 1))
		TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = facing * CFrame.Angles(math.rad(-25), 0, 0),
		}):Play()
		task.delay(duration, function()
			if bandit.alive() then
				TweenService:Create(root, TweenInfo.new(0.15), { CFrame = facing }):Play()
			end
		end)
	end

	local bonk = Instance.new("ProximityPrompt")
	bonk.ActionText = "BONK! (-" .. CONFIG.bonkDamage .. " HP)"
	bonk.ObjectText = if isBoss then "Boss Bandit" else "Brainrot Bandit"
	bonk.HoldDuration = 0
	bonk.MaxActivationDistance = 12 * scale
	bonk.RequiresLineOfSight = false
	bonk.Parent = root
	local lastBonk = {}
	bonk.Triggered:Connect(function(who)
		local t = os.clock()
		if (lastBonk[who] or 0) > t then
			return
		end
		lastBonk[who] = t + CONFIG.bonkCooldown
		local character = who.Character
		local hand = character and character:FindFirstChild("HumanoidRootPart")
		local from = if hand then hand.Position else root.Position
		Remotes.Bonk:FireAllClients(root.Position + Vector3.new(0, 2 * scale, 0), BONK_COLOR, "BONK!", who, { small = true, boss = isBoss })
		bandit.hit(CONFIG.bonkDamage, from, BONK_COLOR, who, nil)
		bandit.knock(root.Position - from, 2, 0.15)
	end)

	-- The defenders: every brainrot in the raided base attacks when the bandit is within range.
	local lastAttack = {}
	task.spawn(function()
		while bandit.alive() do
			task.wait(0.25)
			local now = os.clock()
			for index, entry in state.slots do
				local defender = entry.model
				if defender and defender.PrimaryPart and bandit.alive() and (lastAttack[index] or 0) <= now then
					local from = defender.PrimaryPart.Position
					if (from - root.Position).Magnitude <= CONFIG.defendRange + (if isBoss then 6 else 0) then
						lastAttack[index] = now + CONFIG.attackCooldown
						local passive = Catalog.passiveOf(entry.id)
						local mult = if passive and passive.kind == "GUARD" then passive.value else 1
						local amount = Catalog.atkFor(entry.id, entry.mutation) * mult
						bandit.hit(amount, from, Catalog.rarityOf(entry.id).color, nil, defender)
					end
				end
			end
		end
	end)

	for _, point in path do
		walk(bandit, point)
		if not bandit.alive() then
			return
		end
	end

	if PlayerState.isLocked(state) or state.plot ~= plot then
		Remotes.notify(owner, "🛡️ The " .. (if isBoss then "BOSS" else "bandit") .. " bounced off your LOCKED base!", GOOD)
	else
		local index = BaseService.bestSlot(state)
		local entry = index and BaseService.removeSlot(state, index)
		if entry then
			PlayerState.sync(state)
			loot = { id = entry.id, mutation = entry.mutation }
			local sackModel = Factory.build(entry.id, entry.mutation, { scale = 0.3 * scale, noLabel = true })
			for _, part in sackModel:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.Massless = true
				end
			end
			sackModel:PivotTo(root.CFrame * CFrame.new(0, 3.2 * scale, 0))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = sackModel.PrimaryPart
			weld.Parent = sackModel.PrimaryPart
			sackModel.Parent = model
			Remotes.notify(owner, "🚨 The " .. (if isBoss then "BOSS" else "bandit") .. " STOLE your " .. Catalog.displayName(entry.id, entry.mutation) .. "! Knock him out before he escapes!", RED)
		else
			Remotes.notify(owner, "🪨 The " .. (if isBoss then "BOSS" else "bandit") .. " couldn't lift anything in your base!", GOOD)
		end
	end

	-- Escape back down the ramp and off into the field (the defenders keep hitting him on the way out).
	for i = #path - 1, 1, -1 do
		walk(bandit, path[i])
		if not bandit.alive() then
			return
		end
	end
	walk(bandit, Vector3.new(plot.cx, bodyHeight, 120))
	if bandit.alive() then
		defeated = true
		finish()
		if loot then
			Remotes.notify(owner, "😭 The " .. (if isBoss then "BOSS" else "bandit") .. " escaped with your " .. Catalog.displayName(loot.id, loot.mutation) .. "...", RED)
		elseif isBoss then
			Remotes.announce("👑 The Boss Bandit got away... he'll be back after another " .. BOSS.everyWaves .. " waves!", RED)
		end
		model:Destroy()
	end
end

local function safeRaid(boss: boolean)
	local ok, err = pcall(BanditService.raid, folder, boss)
	if not ok then
		warn("[BanditService]", err)
		if boss then
			bossActive = false
		end
	end
end

function BanditService.start(world)
	folder = world.folder
	task.spawn(function()
		task.wait(CONFIG.firstDelay)
		while true do
			safeRaid(false)
			task.wait(CONFIG.interval)
		end
	end)
	-- The boss rides in right after every BOSS.everyWaves-th farm disaster has passed.
	local lastBossWave = 0
	workspace:GetAttributeChangedSignal("DisasterPhase"):Connect(function()
		local wave = workspace:GetAttribute("DisasterWave") or 0
		if workspace:GetAttribute("DisasterPhase") ~= "calm" or wave <= 0 or wave % BOSS.everyWaves ~= 0 then
			return
		end
		if wave == lastBossWave or bossActive then
			return
		end
		lastBossWave = wave
		task.spawn(safeRaid, true)
	end)
end

return BanditService
