-- BrainrotCatalog: the cast. Sixteen farmyard brainrots, each an animal head (cow, bull, chicken, rooster,
-- goat, pig, horse) fused with a piece of village farm gear (milk bucket, milk can, hay bale, wheelbarrow,
-- tractor, harvester, milk tanker, silo, windmill, barn). Each has an income, an ATK stat (used to fight off
-- the Brainrot Bandit) and one Passive Skill that the server really applies. Also: the seven-step rarity
-- ladder, nine mutations (eight on the Barn Fuse Machine's ladder plus TRAIN GOD), and the weighted rolls the field, meteor and bandit use.

local Catalog = {}

Catalog.RARITIES = {
	{ key = "Common", color = Color3.fromRGB(215, 215, 215), weight = 60, scale = 1.0 },
	{ key = "Rare", color = Color3.fromRGB(70, 165, 255), weight = 25, scale = 1.1 },
	{ key = "Epic", color = Color3.fromRGB(185, 95, 255), weight = 10, scale = 1.2 },
	{ key = "Legendary", color = Color3.fromRGB(255, 195, 40), weight = 4, scale = 1.35 },
	{ key = "Mythic", color = Color3.fromRGB(255, 75, 95), weight = 1.2, scale = 1.5 },
	{ key = "Brainrot God", color = Color3.fromRGB(70, 255, 200), weight = 0.35, scale = 1.7 },
	{ key = "Secret", color = Color3.fromRGB(255, 255, 255), weight = 0.06, scale = 1.9 },
}
Catalog.RARITY_INDEX = {}
for index, rarity in Catalog.RARITIES do
	Catalog.RARITY_INDEX[rarity.key] = index
end

-- mult multiplies the brainrot's own income. TrainGod never rolls naturally (weight 0): only the steam
-- train's cargo can carry it, and instead of its own income it doubles ALL income of the base it stands in.
-- Radioactive is a very rare natural roll; Celestial only comes out of the Barn Fuse Machine.
-- source: how to get it, shown in the DEX.
Catalog.MUTATIONS = {
	{ key = "Normal", label = "Normal", mult = 1, weight = 78, color = Color3.fromRGB(255, 255, 255), source = "Everywhere in the field" },
	{ key = "Gold", label = "Gold", mult = 2, weight = 11, color = Color3.fromRGB(255, 200, 40), source = "Field, meteor or fuse" },
	{ key = "Diamond", label = "Diamond", mult = 3, weight = 6, color = Color3.fromRGB(140, 230, 255), source = "Field, meteor or fuse" },
	{ key = "Rainbow", label = "Rainbow", mult = 5, weight = 2.6, color = Color3.fromRGB(255, 120, 220), source = "Field, meteor or fuse" },
	{ key = "Lava", label = "Lava", mult = 7, weight = 1.6, color = Color3.fromRGB(255, 100, 30), source = "Field, meteor or fuse" },
	{ key = "Galaxy", label = "Galaxy", mult = 10, weight = 0.8, color = Color3.fromRGB(150, 100, 255), source = "Deep field, meteor or fuse" },
	{ key = "Radioactive", label = "Radioactive", mult = 15, weight = 0.3, color = Color3.fromRGB(110, 255, 60), source = "Ultra-rare roll or fuse" },
	{ key = "Celestial", label = "Celestial", mult = 25, weight = 0, color = Color3.fromRGB(255, 240, 170), source = "Barn Fuse Machine only" },
	{ key = "TrainGod", label = "Train God", mult = 1, allIncome = 2, weight = 0, color = Color3.fromRGB(255, 150, 30), source = "Steam train cargo only" },
}
Catalog.MUTATION_BY_KEY = {}
Catalog.MUTATION_INDEX = {}
for index, mutation in Catalog.MUTATIONS do
	Catalog.MUTATION_BY_KEY[mutation.key] = mutation
	Catalog.MUTATION_INDEX[mutation.key] = index
end

-- The Barn Fuse Machine's ladder: 3 identical brainrots -> 1 with the next mutation (TRAIN GOD is off-ladder).
Catalog.FUSE_LADDER = { "Normal", "Gold", "Diamond", "Rainbow", "Lava", "Galaxy", "Radioactive", "Celestial" }
Catalog.FUSE_TIER = {}
for tier, key in Catalog.FUSE_LADDER do
	Catalog.FUSE_TIER[key] = tier
end

-- The mutation `steps` rungs above mutationKey (capped at the top), or nil when it can't be fused.
function Catalog.fuseUpgrade(mutationKey: string, steps: number): string?
	local tier = Catalog.FUSE_TIER[mutationKey]
	if not tier or tier >= #Catalog.FUSE_LADDER then
		return nil
	end
	return Catalog.FUSE_LADDER[math.min(tier + steps, #Catalog.FUSE_LADDER)]
end

--[[
	Passive skills (one per brainrot). value is a fraction for percentages, studs/s for SPEED, a multiplier for GUARD.
	  SELF_INCOME  this brainrot earns +value more             (BrainrotCatalog.incomeFor)
	  AURA         every brainrot in the same base earns +value (PlayerState.income)
	  GUARD        deals value x damage to the Brainrot Bandit  (BanditService defenders)
	  SPEED        +value WalkSpeed while you carry it          (PlayerState.walkSpeed)
	  VAULT        COLLECT pays +value extra                    (BaseService collect)
	  ANCHOR       too heavy: players and the bandit can't steal it (BaseService.steal / bestSlot)
]]
Catalog.PASSIVE_KINDS = { "SELF_INCOME", "AURA", "GUARD", "SPEED", "VAULT", "ANCHOR" }

-- body: the farm item it is fused with; head: the animal head (or a list of heads for a chimera).
-- extras: decorations the model factory knows how to build.
Catalog.CHARACTERS = {
	{
		id = "Muccarello", name = "Muccarello Secchiello", rarity = "Common", income = 2, atk = 3,
		head = "cow", body = "bucket", extras = { "legs", "bell" },
		passive = { kind = "SELF_INCOME", value = 0.1, name = "Fresh Milk" },
	},
	{
		id = "Gallinetto", name = "Gallinetto Fienetto", rarity = "Common", income = 3, atk = 2,
		head = "chicken", body = "haybale", extras = { "chickenlegs", "eggs" },
		passive = { kind = "SPEED", value = 2, name = "Panic Sprint" },
	},
	{
		id = "Porcellino", name = "Porcellino Carriola", rarity = "Common", income = 4, atk = 4,
		head = "pig", body = "wheelbarrow", extras = { "hat" },
		passive = { kind = "VAULT", value = 0.05, name = "Piggy Bank" },
	},
	{
		id = "Capretto", name = "Capretto Bidoncino", rarity = "Rare", income = 10, atk = 8,
		head = "goat", body = "milkcan", extras = { "legs" },
		passive = { kind = "GUARD", value = 1.5, name = "Headbutt" },
	},
	{
		id = "Cavallino", name = "Cavallino Forcone", rarity = "Rare", income = 14, atk = 12,
		head = "horse", body = "horsebody", extras = { "pitchfork" },
		passive = { kind = "GUARD", value = 1.5, name = "Pitchfork Poke" },
	},
	{
		id = "Trattorino", name = "Trattorino Muuu", rarity = "Rare", income = 18, atk = 9,
		head = "cow", body = "tractor", extras = { "hat" },
		passive = { kind = "SPEED", value = 3, name = "Diesel Moo" },
	},
	{
		id = "Gallotrattore", name = "Gallo Trattorello", rarity = "Epic", income = 45, atk = 18,
		head = "rooster", body = "tractor", bodyColor = Color3.fromRGB(40, 130, 220), extras = {},
		passive = { kind = "AURA", value = 0.05, name = "Dawn Crow" },
	},
	{
		id = "Maialone", name = "Maialone Pagliaio", rarity = "Epic", income = 60, atk = 15,
		head = "pig", body = "haystack", extras = { "hat", "legs" },
		passive = { kind = "VAULT", value = 0.1, name = "Truffle Stash" },
	},
	{
		id = "Mietimucca", name = "Mucca Mietitrice", rarity = "Legendary", income = 160, atk = 35,
		head = "cow", body = "harvester", extras = { "bell" },
		passive = { kind = "SELF_INCOME", value = 0.25, name = "Harvest Moon" },
	},
	{
		id = "Mulinocapra", name = "Caprone Mulino", rarity = "Legendary", income = 220, atk = 30,
		head = "goat", body = "windmill", extras = { "legs" },
		passive = { kind = "AURA", value = 0.08, name = "Wind Blessing" },
	},
	{
		id = "Cisternello", name = "Cavallo Cisternello", rarity = "Mythic", income = 600, atk = 60,
		head = "horse", body = "tanker", extras = { "crown" },
		passive = { kind = "ANCHOR", value = 1, name = "Too Heavy To Steal" },
	},
	{
		id = "Pollosilo", name = "Pollo Silone", rarity = "Mythic", income = 850, atk = 55,
		head = "chicken", body = "silo", extras = { "eggs", "wings" },
		passive = { kind = "GUARD", value = 2, name = "Egg Barrage" },
	},
	{
		id = "Torotrattore", name = "Toro Trattorone", rarity = "Brainrot God", income = 2500, atk = 120,
		head = "bull", body = "tractor", bodyColor = Color3.fromRGB(30, 30, 35), extras = { "crown", "bell" },
		passive = { kind = "AURA", value = 0.12, name = "Stampede Spirit" },
	},
	{
		id = "Porcofienile", name = "Porco Fienile Volante", rarity = "Brainrot God", income = 3400, atk = 100,
		head = "pig", body = "barn", extras = { "wings", "halo" },
		passive = { kind = "VAULT", value = 0.2, name = "Golden Trough" },
	},
	{
		id = "Lattemucca", name = "Lattemucca Galattica", rarity = "Secret", income = 12000, atk = 250,
		head = "cow", body = "bucket", bodyColor = Color3.fromRGB(255, 200, 60), extras = { "legs", "crown", "wings", "glow" },
		passive = { kind = "SELF_INCOME", value = 0.5, name = "Cosmic Cream" },
	},
	{
		id = "Chimera", name = "Chimera Contadina", rarity = "Secret", income = 18000, atk = 300,
		head = { "goat", "bull", "rooster" }, body = "tractor", bodyColor = Color3.fromRGB(120, 40, 160), extras = { "halo", "glow" },
		passive = { kind = "AURA", value = 0.2, name = "Three-Headed Harvest" },
	},
}

Catalog.BY_ID = {}
Catalog.BY_RARITY = {}
for _, def in Catalog.CHARACTERS do
	Catalog.BY_ID[def.id] = def
	Catalog.BY_RARITY[def.rarity] = Catalog.BY_RARITY[def.rarity] or {}
	table.insert(Catalog.BY_RARITY[def.rarity], def)
end

local rng = Random.new()

local function weightedPick(entries, weightOf)
	local total = 0
	for index, entry in entries do
		total += weightOf(entry, index)
	end
	local roll = rng:NextNumber() * total
	for index, entry in entries do
		roll -= weightOf(entry, index)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- luck 0..3 tilts the ladder towards rare brainrots; minIndex forbids rarities below it.
function Catalog.rollRarity(luck: number, minIndex: number?)
	local floor = minIndex or 1
	local tilt = 1 + luck * 0.45
	return weightedPick(Catalog.RARITIES, function(rarity, index)
		if index < floor then
			return 0
		end
		return rarity.weight * tilt ^ (index - 1)
	end)
end

-- boost > 1 makes every non-Normal mutation more likely (the Meme Meteor uses 4).
function Catalog.rollMutation(boost: number?)
	local factor = boost or 1
	return weightedPick(Catalog.MUTATIONS, function(mutation)
		if mutation.key == "Normal" then
			return mutation.weight
		end
		return mutation.weight * factor
	end)
end

function Catalog.rollCharacter(luck: number, minIndex: number?)
	local rarity = Catalog.rollRarity(luck, minIndex)
	local pool = Catalog.BY_RARITY[rarity.key]
	return pool[rng:NextInteger(1, #pool)]
end

function Catalog.passiveOf(id: string)
	local def = Catalog.BY_ID[id]
	return def and def.passive
end

-- Income per second of one brainrot: base income x mutation, plus its own SELF_INCOME passive.
function Catalog.incomeFor(id: string, mutationKey: string): number
	local def = Catalog.BY_ID[id]
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey] or Catalog.MUTATIONS[1]
	if not def then
		return 0
	end
	local bonus = if def.passive.kind == "SELF_INCOME" then def.passive.value else 0
	return def.income * mutation.mult * (1 + bonus)
end

-- ATK grows with the square root of the mutation multiplier (Galaxy x10 income -> about x3.2 ATK).
function Catalog.atkFor(id: string, mutationKey: string): number
	local def = Catalog.BY_ID[id]
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey] or Catalog.MUTATIONS[1]
	if not def then
		return 0
	end
	return math.floor(def.atk * math.sqrt(mutation.mult) + 0.5)
end

-- The line shown under the brainrot: "Wind Blessing: +8% income for the whole base".
function Catalog.passiveText(id: string): string
	local passive = Catalog.passiveOf(id)
	if not passive then
		return ""
	end
	local value = passive.value
	local effect
	if passive.kind == "SELF_INCOME" then
		effect = "+" .. math.floor(value * 100 + 0.5) .. "% own income"
	elseif passive.kind == "AURA" then
		effect = "+" .. math.floor(value * 100 + 0.5) .. "% income for the whole base"
	elseif passive.kind == "GUARD" then
		effect = "x" .. value .. " damage to bandits"
	elseif passive.kind == "SPEED" then
		effect = "+" .. value .. " WalkSpeed while carried"
	elseif passive.kind == "VAULT" then
		effect = "+" .. math.floor(value * 100 + 0.5) .. "% cash on COLLECT"
	else
		effect = "can't be stolen"
	end
	return passive.name .. ": " .. effect
end

-- The small mutation tag over a brainrot and on its hover card: "GOLD x2", "TRAIN GOD x2 ALL INCOME".
function Catalog.mutationText(mutationKey: string): string
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey]
	if not mutation or mutationKey == "Normal" then
		return ""
	end
	if mutation.allIncome then
		return string.upper(mutation.label) .. " x" .. mutation.allIncome .. " ALL INCOME"
	end
	return string.upper(mutation.label) .. " x" .. mutation.mult
end

-- The base-wide multiplier from TRAIN GOD brainrots in a list of slot entries (does not stack: x2 at most).
function Catalog.allIncomeMultiplier(entries): number
	local best = 1
	for _, entry in entries do
		local mutation = Catalog.MUTATION_BY_KEY[entry.mutation]
		if mutation and mutation.allIncome and mutation.allIncome > best then
			best = mutation.allIncome
		end
	end
	return best
end

function Catalog.displayName(id: string, mutationKey: string): string
	local def = Catalog.BY_ID[id]
	local name = if def then def.name else id
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey]
	if mutation and mutationKey ~= "Normal" then
		return mutation.label .. " " .. name
	end
	return name
end

function Catalog.rarityOf(id: string)
	local def = Catalog.BY_ID[id]
	return Catalog.RARITIES[Catalog.RARITY_INDEX[def.rarity]]
end

return Catalog
