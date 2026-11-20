-- BaseService: each player's base plot on the plateau. Assigns plots, places brainrots on slot pads,
-- deposits what a player carries home, fills the vault with income every second, pays it out on the
-- COLLECT pad, sells (owner) and steals (other players) placed brainrots, and runs the base LOCK.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local StashService = require(script.Parent:WaitForChild("StashService"))

local BaseService = {}

local plots = {}
local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 110, 110)
local LOCKED_PAD = Color3.fromRGB(60, 60, 70)

local function stateForPlot(plot)
	return plot.owner and PlayerState.get(plot.owner)
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end

local function prompt(parent: BasePart, name: string, action: string, objectText: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = hold
	p.MaxActivationDistance = 13
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Pads beyond the player's slot count are dark until a rebirth unlocks them.
function BaseService.refreshPads(state)
	local plot = state.plot
	if not plot then
		return
	end
	local unlocked = PlayerState.slotCount(state)
	for index, pad in plot.slotPads do
		pad.Color = if index <= unlocked then plot.color else LOCKED_PAD
		pad.Material = if index <= unlocked then Enum.Material.Neon else Enum.Material.Slate
	end
end

function BaseService.spawnSlotModel(state, index: number)
	local plot = state.plot
	local entry = state.slots[index]
	if not plot or not entry then
		return
	end
	local model = Factory.build(entry.id, entry.mutation, { labelDistance = GameConfig.PLACED_LABEL_DISTANCE })
	model:PivotTo(plot.slotCFrames[index])
	model:SetAttribute("OwnerUserId", state.player.UserId)
	model:SetAttribute("SlotIndex", index)
	model:SetAttribute("Locked", PlayerState.isLocked(state))
	CollectionService:AddTag(model, "PlacedBrainrot")
	model.Parent = plot.model
	entry.model = model

	local name = Catalog.displayName(entry.id, entry.mutation)
	local sellValue = Catalog.incomeFor(entry.id, entry.mutation) * GameConfig.SELL_SECONDS
	local sell = prompt(model.PrimaryPart, "SellPrompt", "Sell " .. Format.cash(sellValue), name, 0.6)
	local steal = prompt(model.PrimaryPart, "StealPrompt", "Steal!", name, 1.6)
	-- The owner can lift a brainrot off its pedestal again: into their hands, or the Stash if hands are full.
	local pickUp = prompt(model.PrimaryPart, "PickUpPrompt", "Pick Up", name, 0.35)
	pickUp.KeyboardKeyCode = Enum.KeyCode.R
	pickUp.Triggered:Connect(function(who)
		if state.slots[index] == entry then
			StashService.pickUpFromBase(state, index, who, BaseService.removeSlot)
		end
	end)
	sell.Triggered:Connect(function(who)
		if state.slots[index] == entry then
			BaseService.sell(state, index, who)
		end
	end)
	steal.Triggered:Connect(function(who)
		if state.slots[index] == entry then
			BaseService.steal(state, index, who)
		end
	end)
end

function BaseService.freeSlot(state): number?
	for index = 1, PlayerState.slotCount(state) do
		if not state.slots[index] then
			return index
		end
	end
	return nil
end

function BaseService.place(state, id: string, mutation: string): boolean
	local index = BaseService.freeSlot(state)
	if not index then
		return false
	end
	state.slots[index] = { id = id, mutation = mutation }
	PlayerState.discover(state, id, mutation)
	BaseService.spawnSlotModel(state, index)
	return true
end

function BaseService.removeSlot(state, index: number)
	local entry = state.slots[index]
	if not entry then
		return nil
	end
	if entry.model then
		entry.model:Destroy()
		entry.model = nil
	end
	state.slots[index] = nil
	return entry
end

function BaseService.clearSlots(state)
	for index in state.slots do
		BaseService.removeSlot(state, index)
	end
end

local function isAnchored(entry): boolean
	local passive = Catalog.passiveOf(entry.id)
	return passive ~= nil and passive.kind == "ANCHOR"
end

-- The placed brainrot with the highest income that can be carried off (ANCHOR ones can't), used by the bandit.
function BaseService.bestSlot(state): number?
	local best, bestIncome = nil, -1
	for index, entry in state.slots do
		local income = Catalog.incomeFor(entry.id, entry.mutation)
		if income > bestIncome and not isAnchored(entry) then
			best, bestIncome = index, income
		end
	end
	return best
end

function BaseService.sell(state, index: number, who: Player)
	if who ~= state.player then
		return
	end
	local entry = BaseService.removeSlot(state, index)
	if not entry then
		return
	end
	local value = Catalog.incomeFor(entry.id, entry.mutation) * GameConfig.SELL_SECONDS
	PlayerState.addCash(state, value)
	PlayerState.sync(state)
	Remotes.notify(who, "Sold " .. Catalog.displayName(entry.id, entry.mutation) .. " for " .. Format.cash(value), GOOD)
	Remotes.CashPopup:FireClient(who, value)
end

function BaseService.steal(state, index: number, thief: Player)
	if thief == state.player then
		return
	end
	local thiefState = PlayerState.get(thief)
	if not thiefState then
		return
	end
	if PlayerState.isLocked(state) then
		Remotes.notify(thief, "🔒 " .. state.player.Name .. "'s base is LOCKED!", BAD)
		return
	end
	if CarryService.isFull(thiefState) then
		Remotes.notify(thief, "🎒 Hands full! Upgrade Carry Capacity.", BAD)
		return
	end
	local target = state.slots[index]
	if target and isAnchored(target) then
		Remotes.notify(thief, "🪨 " .. Catalog.displayName(target.id, target.mutation) .. " is too heavy to steal!", BAD)
		return
	end
	local entry = BaseService.removeSlot(state, index)
	if not entry then
		return
	end
	PlayerState.sync(state)
	CarryService.give(thiefState, entry.id, entry.mutation)
	local name = Catalog.displayName(entry.id, entry.mutation)
	Remotes.notify(thief, "🥷 You stole " .. name .. "! Run it to your base!", GOOD)
	Remotes.notify(state.player, "🚨 " .. thief.Name .. " STOLE your " .. name .. "! Lock your base!", BAD)
end

local function setBarrier(state, locked: boolean)
	local plot = state.plot
	if not plot then
		return
	end
	for _, wall in plot.barrier do
		wall.Transparency = if locked then 0.35 else 1
	end
	for _, entry in state.slots do
		if entry.model then
			entry.model:SetAttribute("Locked", locked)
		end
	end
end

function BaseService.lock(state)
	local now = PlayerState.now()
	if now < state.lockUntil then
		return
	end
	if now < state.lockReadyAt then
		Remotes.notify(state.player, "⏳ Lock recharging: " .. Format.seconds(state.lockReadyAt - now), BAD)
		return
	end
	local duration = PlayerState.lockDuration(state)
	state.lockUntil = now + duration
	state.lockReadyAt = now + duration + GameConfig.LOCK_COOLDOWN
	setBarrier(state, true)
	PlayerState.sync(state)
	Remotes.notify(state.player, "🔒 Base LOCKED for " .. duration .. "s - thieves and bandits bounce off!", GOOD)
end

function BaseService.isInsidePlot(state, position: Vector3): boolean
	local plot = state.plot
	return plot ~= nil
		and position.X >= plot.minX
		and position.X <= plot.maxX
		and position.Z >= plot.minZ
		and position.Z <= plot.maxZ + 2
		and position.Y > GameConfig.PLATEAU_TOP
end

-- Puts everything the player carries onto free slots once they step onto their own plot.
function BaseService.depositIfHome(state)
	if #state.carried == 0 or os.clock() < (state.depositPausedUntil or 0) then
		return -- nothing to place, or a Pick Up just happened (GameConfig.PICKUP_DEPOSIT_COOLDOWN)
	end
	local character = state.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not BaseService.isInsidePlot(state, root.Position) then
		return
	end
	local items = CarryService.takeAll(state)
	local placed, leftover = 0, {}
	for _, item in items do
		if BaseService.place(state, item.id, item.mutation) then
			placed += 1
			local def = Catalog.BY_ID[item.id]
			local rarity = Catalog.rarityOf(item.id)
			Remotes.notify(state.player, "🏠 " .. Catalog.displayName(item.id, item.mutation) .. " placed! +" .. Format.perSecond(Catalog.incomeFor(item.id, item.mutation)), rarity.color)
			if Catalog.RARITY_INDEX[def.rarity] >= 5 then
				Remotes.announce("🌟 " .. state.player.Name .. " secured a " .. rarity.key .. " " .. Catalog.displayName(item.id, item.mutation) .. "!", rarity.color)
			end
		else
			table.insert(leftover, item)
		end
	end
	for _, item in leftover do
		CarryService.give(state, item.id, item.mutation)
	end
	if #leftover > 0 then
		Remotes.notify(state.player, "🏠 Base full! Sell a brainrot or REBIRTH for more slots.", BAD)
	end
	PlayerState.sync(state)
end

local collectDebounce = {}

local function collect(state)
	local amount = math.floor(state.vault)
	if amount <= 0 then
		return
	end
	state.vault -= amount
	-- VAULT passives (Piggy Bank, Truffle Stash, Golden Trough) pay extra on top of the vault.
	local paid = math.floor(amount * (1 + PlayerState.vaultBonus(state)))
	PlayerState.addCash(state, paid)
	PlayerState.sync(state)
	state.plot.vaultLabel.Text = "💰 " .. Format.cash(state.vault)
	Remotes.CashPopup:FireClient(state.player, paid)
end

-- Runs once per second: income flows into the vault, labels update, expired locks drop their barrier.
function BaseService.tick(state)
	local plot = state.plot
	if not plot then
		return
	end
	state.vault += PlayerState.income(state)
	plot.vaultLabel.Text = "💰 " .. Format.cash(state.vault)
	local now = PlayerState.now()
	if now < state.lockUntil then
		plot.lockLabel.Text = "🔒 LOCKED " .. Format.seconds(state.lockUntil - now)
	else
		if plot.barrier[1].Transparency < 1 then
			setBarrier(state, false)
			Remotes.notify(state.player, "🔓 Your base lock wore off!", BAD)
		end
		plot.lockLabel.Text = if now < state.lockReadyAt then "⏳ LOCK " .. Format.seconds(state.lockReadyAt - now) else "🔓 LOCK BASE"
	end
	PlayerState.sync(state)
end

function BaseService.assignPlot(state)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = state.player
			state.plot = plot
			for _, label in plot.signLabels do
				label.Text = string.upper(state.player.DisplayName) .. "'S FARM"
			end
			for index in state.slots do
				BaseService.spawnSlotModel(state, index)
			end
			BaseService.refreshPads(state)
			return plot
		end
	end
	return nil
end

function BaseService.releasePlot(state)
	local plot = state.plot
	if not plot then
		return
	end
	setBarrier(state, false)
	for _, entry in state.slots do
		if entry.model then
			entry.model:Destroy()
			entry.model = nil
		end
	end
	plot.owner = nil
	for _, label in plot.signLabels do
		label.Text = "EMPTY FARM"
	end
	plot.vaultLabel.Text = "💰 $0"
	plot.lockLabel.Text = "🔓 LOCK BASE"
	for _, pad in plot.slotPads do
		pad.Color = plot.color
		pad.Material = Enum.Material.Neon
	end
	state.plot = nil
end

function BaseService.init(world)
	plots = world.plots
	for _, plot in plots do
		plot.collectPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local state = stateForPlot(plot)
			if not player or not state or player ~= state.player then
				return
			end
			local t = os.clock()
			if (collectDebounce[player] or 0) > t then
				return
			end
			collectDebounce[player] = t + 0.5
			collect(state)
		end)
		plot.lockPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local state = stateForPlot(plot)
			if not player or not state or player ~= state.player then
				return
			end
			local t = os.clock()
			if (collectDebounce[plot] or 0) > t then
				return
			end
			collectDebounce[plot] = t + 2
			BaseService.lock(state)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		collectDebounce[player] = nil
	end)
end

return BaseService
