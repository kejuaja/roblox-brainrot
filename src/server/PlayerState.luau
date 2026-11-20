-- PlayerState: the one authoritative record of every player's progress - cash, unclaimed vault, rebirths,
-- upgrade levels, the brainrots in each base slot and the ones being carried, the base lock timers, the
-- weapons bought in the WEAPONS shop and the DEX (Index Book: every character + mutation ever owned).
-- Clients never write it; sync() mirrors it onto Player attributes and leaderstats for the HUD to read.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local PlayerState = {}

local states = {}

local function now(): number
	return workspace:GetServerTimeNow()
end
PlayerState.now = now

-- saved: what DataService loaded (or nil for a new player); anything malformed falls back to defaults.
function PlayerState.create(player: Player, saved)
	local data = if type(saved) == "table" then saved else {}
	local state = {
		player = player,
		cash = math.max(0, tonumber(data.cash) or GameConfig.START_CASH),
		rebirths = math.max(0, math.floor(tonumber(data.rebirths) or 0)),
		upgrades = { Speed = 0, Carry = 0, Lock = 0, Stash = 0 },
		slots = {}, -- [slotIndex] = { id, mutation, model }
		carried = {}, -- { { id, mutation, model } }
		stash = {}, -- { { id, mutation } }: the personal Stash, kept between sessions
		vault = 0,
		lockUntil = 0,
		lockReadyAt = 0,
		plot = nil,
		weapons = {}, -- [weaponId] = true
		seenWelcome = data.seenWelcome == true, -- closed the Welcome modal once: it no longer pops up on join
		dex = {}, -- [brainrotId] = { [mutationKey] = true }
	}
	if type(data.stash) == "table" then
		for _, entry in data.stash do
			if type(entry) == "table" and Catalog.BY_ID[entry.id] and Catalog.MUTATION_BY_KEY[entry.m] then
				table.insert(state.stash, { id = entry.id, mutation = entry.m })
				state.dex[entry.id] = state.dex[entry.id] or {}
				state.dex[entry.id][entry.m] = true
			end
		end
	end
	if type(data.weapons) == "table" then
		for _, id in data.weapons do
			if GameConfig.WEAPONS[id] then
				state.weapons[id] = true
			end
		end
	end
	if type(data.dex) == "table" then
		for id, mutations in data.dex do
			if Catalog.BY_ID[id] and type(mutations) == "table" then
				for _, key in mutations do
					if Catalog.MUTATION_BY_KEY[key] then
						state.dex[id] = state.dex[id] or {}
						state.dex[id][key] = true
					end
				end
			end
		end
	end
	if type(data.upgrades) == "table" then
		for key in state.upgrades do
			local level = tonumber(data.upgrades[key])
			if level then
				state.upgrades[key] = math.clamp(math.floor(level), 0, GameConfig.UPGRADES[key].max)
			end
		end
	end
	if type(data.slots) == "table" then
		local maxSlots = GameConfig.slotCount(state.rebirths)
		for _, entry in data.slots do
			local index = type(entry) == "table" and tonumber(entry.s)
			if index and index >= 1 and index <= maxSlots and Catalog.BY_ID[entry.id] and Catalog.MUTATION_BY_KEY[entry.m] then
				state.slots[index] = { id = entry.id, mutation = entry.m }
				state.dex[entry.id] = state.dex[entry.id] or {}
				state.dex[entry.id][entry.m] = true
			end
		end
	end
	states[player] = state
	player:SetAttribute("ShowWelcome", not state.seenWelcome)
	PlayerState.syncDex(state)
	PlayerState.syncWeapons(state)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
	return state
end

function PlayerState.get(player: Player)
	return states[player]
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

function PlayerState.all()
	return states
end

function PlayerState.serialize(state)
	local slots = {}
	for index, entry in state.slots do
		table.insert(slots, { s = index, id = entry.id, m = entry.mutation })
	end
	local stash = {}
	for _, entry in state.stash do
		table.insert(stash, { id = entry.id, m = entry.mutation })
	end
	local weapons = {}
	for id in state.weapons do
		table.insert(weapons, id)
	end
	return {
		cash = state.cash,
		rebirths = state.rebirths,
		upgrades = table.clone(state.upgrades),
		slots = slots,
		stash = stash,
		weapons = weapons,
		seenWelcome = state.seenWelcome,
		dex = PlayerState.dexList(state),
	}
end

-- The DEX as { [brainrotId] = { mutationKey, ... } } - the save format and what the client decodes.
function PlayerState.dexList(state)
	local out = {}
	for id, mutations in state.dex do
		local list = {}
		for key in mutations do
			table.insert(list, key)
		end
		out[id] = list
	end
	return out
end

function PlayerState.syncDex(state)
	state.player:SetAttribute("Dex", HttpService:JSONEncode(PlayerState.dexList(state)))
end

function PlayerState.syncWeapons(state)
	local owned = {}
	for _, id in GameConfig.WEAPON_ORDER do
		if state.weapons[id] then
			table.insert(owned, id)
		end
	end
	state.player:SetAttribute("Weapons", table.concat(owned, ","))
end

local function dexCounts(state): (number, number)
	local characters, seen = 0, {}
	for _, mutations in state.dex do
		characters += 1
		for key in mutations do
			seen[key] = true
		end
	end
	local mutations = 0
	for _ in seen do
		mutations += 1
	end
	return characters, mutations
end

-- Records that the player now owns this character + mutation - one of the DEX's 144 collection entries.
-- A new entry pops a toast with the collection count.
function PlayerState.discover(state, id: string, mutationKey: string)
	if not Catalog.BY_ID[id] or not Catalog.MUTATION_BY_KEY[mutationKey] then
		return
	end
	local known = state.dex[id]
	if known and known[mutationKey] then
		return
	end
	local _, mutationsBefore = dexCounts(state)
	local newCharacter = known == nil
	state.dex[id] = known or {}
	state.dex[id][mutationKey] = true
	PlayerState.syncDex(state)
	local _, mutations = dexCounts(state)
	local entries = 0
	for _, owned in state.dex do
		for _ in owned do
			entries += 1
		end
	end
	local total = #Catalog.CHARACTERS * #Catalog.MUTATIONS
	local tag = if newCharacter then "NEW BRAINROT" elseif mutations > mutationsBefore then "NEW MUTATION" else "NEW ENTRY"
	Remotes.notify(state.player, "📖 DEX " .. tag .. ": " .. Catalog.displayName(id, mutationKey) .. " (" .. entries .. "/" .. total .. ")", Catalog.MUTATION_BY_KEY[mutationKey].color:Lerp(Color3.fromRGB(200, 150, 255), 0.4))
end

function PlayerState.slotCount(state): number
	return GameConfig.slotCount(state.rebirths)
end

function PlayerState.slotsUsed(state): number
	local used = 0
	for _ in state.slots do
		used += 1
	end
	return used
end

function PlayerState.carryMax(state): number
	return GameConfig.upgradeValue("Carry", state.upgrades.Carry)
end

-- Sum of one passive kind over a list of { id = ... } entries (base slots or the carried stack).
function PlayerState.passiveSum(entries, kind: string): number
	local total = 0
	for _, entry in entries do
		local passive = Catalog.passiveOf(entry.id)
		if passive and passive.kind == kind then
			total += passive.value
		end
	end
	return total
end

-- WalkSpeed upgrade plus the SPEED passive of everything being carried.
function PlayerState.walkSpeed(state): number
	return GameConfig.upgradeValue("Speed", state.upgrades.Speed) + PlayerState.passiveSum(state.carried, "SPEED")
end

-- Extra fraction paid on COLLECT from VAULT passives in the base.
function PlayerState.vaultBonus(state): number
	return PlayerState.passiveSum(state.slots, "VAULT")
end

function PlayerState.stashMax(state): number
	return GameConfig.upgradeValue("Stash", state.upgrades.Stash)
end

-- { { id, m } } as JSON: what the HUD's STASH panel lists.
local function entriesJson(entries): string
	local list = {}
	for _, entry in entries do
		table.insert(list, { id = entry.id, m = entry.mutation })
	end
	return HttpService:JSONEncode(list)
end

function PlayerState.lockDuration(state): number
	return GameConfig.upgradeValue("Lock", state.upgrades.Lock)
end

function PlayerState.isLocked(state): boolean
	return now() < state.lockUntil
end

-- Income per second of everything placed in the base: each brainrot's own income (mutation and
-- SELF_INCOME included), boosted by the base's AURA passives and the rebirth multiplier.
function PlayerState.income(state): number
	local total = 0
	for _, entry in state.slots do
		total += Catalog.incomeFor(entry.id, entry.mutation)
	end
	local aura = PlayerState.passiveSum(state.slots, "AURA")
	local trainGod = Catalog.allIncomeMultiplier(state.slots) -- a TRAIN GOD in the base doubles everything
	return total * (1 + aura) * trainGod * GameConfig.rebirthMultiplier(state.rebirths)
end

function PlayerState.addCash(state, amount: number)
	state.cash = math.max(0, state.cash + amount)
end

function PlayerState.applyCharacter(state)
	local character = state.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerState.walkSpeed(state)
	end
end

-- Mirrors the state onto the player's attributes (read by the HUD) and leaderstats.
function PlayerState.sync(state)
	local player = state.player
	player:SetAttribute("Cash", state.cash)
	player:SetAttribute("Vault", state.vault)
	player:SetAttribute("Income", PlayerState.income(state))
	player:SetAttribute("Rebirths", state.rebirths)
	player:SetAttribute("RebirthCost", GameConfig.rebirthCost(state.rebirths))
	player:SetAttribute("CarryCount", #state.carried)
	player:SetAttribute("CarryMax", PlayerState.carryMax(state))
	player:SetAttribute("CarriedJson", entriesJson(state.carried))
	player:SetAttribute("StashJson", entriesJson(state.stash))
	player:SetAttribute("StashCount", #state.stash)
	player:SetAttribute("StashMax", PlayerState.stashMax(state))
	player:SetAttribute("SlotsUsed", PlayerState.slotsUsed(state))
	player:SetAttribute("SlotsMax", PlayerState.slotCount(state))
	player:SetAttribute("LockUntil", state.lockUntil)
	player:SetAttribute("LockReadyAt", state.lockReadyAt)
	player:SetAttribute("AuraBonus", PlayerState.passiveSum(state.slots, "AURA"))
	player:SetAttribute("VaultBonus", PlayerState.vaultBonus(state))
	player:SetAttribute("AllIncomeMult", Catalog.allIncomeMultiplier(state.slots))
	for key, level in state.upgrades do
		player:SetAttribute("Upgrade_" .. key, level)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Cash.Value = Format.cash(state.cash)
		leaderstats.Rebirths.Value = state.rebirths
	end
end

return PlayerState
