-- GameConfig: every tunable number of Brainrot Farm Tycoon in one place - map layout, field zones, the
-- village, farm disaster / meteor / bandit timings, upgrade prices and rebirth rules. Server and client both read it.

local GameConfig = {}

GameConfig.GAME_TITLE = "BRAINROT FARM TYCOON"

-- Every brainrot model is built this much bigger than its base design (field, base, carried stack, DEX).
GameConfig.BRAINROT_SCALE = 2

-- Economy
GameConfig.START_CASH = 60
GameConfig.SELL_SECONDS = 25 -- selling a brainrot pays this many seconds of its income
GameConfig.BANDIT_BONK_SECONDS = 20 -- bonking a bandit pays this many seconds of your income

-- Base plots on the high plateau ("Markas")
GameConfig.PLATEAU_TOP = 14
GameConfig.PLATEAU_EDGE_Z = -75 -- the plateau's front edge
GameConfig.PLOT_X = { -80, -48, -16, 16, 48, 80 }
GameConfig.PLOT_WIDTH = 30
GameConfig.PLOT_MIN_Z = -158
GameConfig.PLOT_MAX_Z = -88
-- Every plot uses the same 3 x 3 grid: nine slot pads, all usable from the start.
-- (Spaced for the 2x brainrot models.)
GameConfig.SLOT_X = { -10, 0, 10 }
GameConfig.SLOT_Z = { -100, -113, -126 }
GameConfig.SLOT_PAD_SIZE = 8.5
GameConfig.BASE_SLOTS = 9
GameConfig.SLOTS_PER_REBIRTH = 0
GameConfig.MAX_SLOTS = 9
GameConfig.LOCK_COOLDOWN = 25
-- After a Pick Up from a pedestal, standing on your own tiles doesn't auto-place for this many seconds.
GameConfig.PICKUP_DEPOSIT_COOLDOWN = 2.5
-- BillboardGui ranges: plots are 32 studs apart, so base labels fade out before a neighbour's overlap them.
GameConfig.PLOT_LABEL_DISTANCE = 30 -- COLLECT / LOCK pad labels
GameConfig.PLACED_LABEL_DISTANCE = 38 -- labels over brainrots standing in a base
GameConfig.FIELD_LABEL_DISTANCE = 75 -- labels over brainrots wandering the field

-- The brainrot field: farther from base = rarer brainrots, but a longer run from the disasters
GameConfig.FIELD_HALF_WIDTH = 88
GameConfig.FIELD_MAX_Z = 320
GameConfig.ZONES = {
	{ name = "Chill Meadow", minZ = -45, maxZ = 40, luck = 0, weight = 34, color = Color3.fromRGB(120, 200, 90) },
	{ name = "Sus Savanna", minZ = 40, maxZ = 125, luck = 1, weight = 28, color = Color3.fromRGB(225, 195, 105) },
	{ name = "Cringe Canyon", minZ = 125, maxZ = 215, luck = 2, weight = 22, color = Color3.fromRGB(215, 120, 70) },
	{ name = "Ohio Outskirts", minZ = 215, maxZ = 330, luck = 3, weight = 16, color = Color3.fromRGB(140, 90, 200) },
}
GameConfig.HILLS = {
	Vector3.new(-55, 0, 85),
	Vector3.new(55, 0, 160),
	Vector3.new(-40, 0, 235),
	Vector3.new(50, 0, 295),
}
GameConfig.HILL_SIZE = 26
GameConfig.HILL_HEIGHT = 16
GameConfig.MAX_FIELD_BRAINROTS = 30
GameConfig.SPAWN_INTERVAL = 1.2

-- Hazards and events
-- Farm disasters take turns: odd waves are a FARM TORNADO, even waves a WILD BULL STAMPEDE. Both sweep the
-- field from its far end towards the base ramp. Safe: your base plateau (and its ramp), a SAFE HILL top, and
-- the village outside the field fence. Caught = flung through the air, dropping everything you carry.
GameConfig.DISASTER = {
	interval = 42, -- seconds from one disaster to the next
	warning = 8, -- seconds of warning before it starts moving
	startZ = 335,
	endZ = -38, -- the foot of the base ramp
	safeZ = -40, -- anything nearer the base than this (ramp, plateau) is safe
	hitCooldown = 3, -- seconds before the same player can be flung again
	kinds = { "Tornado", "Stampede" },
	Tornado = {
		label = "FARM TORNADO",
		icon = "🌪️",
		startSpeed = 24,
		speedPerWave = 3,
		maxSpeed = 52,
		sway = 64, -- how far it zig-zags left and right (studs)
		swayLength = 120, -- studs travelled per zig-zag
		flingRadius = 18,
		pullRadius = 52, -- inside this it drags unsheltered players towards the funnel
		pullStrength = 38,
		fling = { up = 85, out = 60, spin = 45 },
		color = Color3.fromRGB(170, 160, 200),
	},
	Stampede = {
		label = "WILD BULL STAMPEDE",
		icon = "🐂",
		startSpeed = 34,
		speedPerWave = 4,
		maxSpeed = 80,
		bulls = 16,
		rowGap = 16,
		hitRadius = 6.5,
		fling = { up = 70, out = 75, spin = 0 },
		color = Color3.fromRGB(230, 120, 70),
	},
}

-- Rebirth titles: floating over every player's head with an aura that grows with the tier.
GameConfig.REBIRTH_TITLES = {
	{ min = 0, title = "Farmhand", icon = "🌱", color = Color3.fromRGB(200, 230, 200), aura = 0 },
	{ min = 1, title = "Hay Hustler", icon = "🌾", color = Color3.fromRGB(150, 255, 120), aura = 1 },
	{ min = 2, title = "Barn Boss", icon = "🐄", color = Color3.fromRGB(255, 190, 90), aura = 2 },
	{ min = 3, title = "Tractor Titan", icon = "🚜", color = Color3.fromRGB(255, 100, 90), aura = 3 },
	{ min = 5, title = "Cattle Baron", icon = "🐂", color = Color3.fromRGB(190, 120, 255), aura = 4 },
	{ min = 8, title = "Harvest Legend", icon = "🌽", color = Color3.fromRGB(255, 215, 60), aura = 5 },
	{ min = 12, title = "Brainrot Farm God", icon = "👑", color = Color3.fromRGB(120, 255, 240), aura = 6, rainbow = true },
}

function GameConfig.rebirthTitle(rebirths: number)
	local best = GameConfig.REBIRTH_TITLES[1]
	for _, entry in GameConfig.REBIRTH_TITLES do
		if rebirths >= entry.min then
			best = entry
		end
	end
	return best
end

-- The village west of the base plateau: market stalls, red barn and silo, windmill, pond, sheep pen,
-- a patrolling tractor on the loop road and the World Leaderboard.
GameConfig.VILLAGE = {
	minX = -240,
	maxX = -120,
	minZ = -170,
	maxZ = 150,
	plaza = Vector3.new(-181, 0, -21),
	roadLoop = { -- corners of the loop road the tractor patrols (clockwise)
		Vector3.new(-222, 0, -78),
		Vector3.new(-140, 0, -78),
		Vector3.new(-140, 0, 36),
		Vector3.new(-222, 0, 36),
	},
	tractorSpeed = 11,
	barn = Vector3.new(-198, 0, 82),
	silo = Vector3.new(-224, 0, 88),
	windmill = Vector3.new(-152, 0, 104),
	pond = Vector3.new(-214, 0, 128),
	pondRadius = 14,
	sheepPen = Vector3.new(-160, 0, 60),
	leaderboard = Vector3.new(-233, 0, -21),
}
GameConfig.METEOR = { interval = 50, fallTime = 2.6, firstDelay = 20 }
GameConfig.BANDIT = {
	interval = 75,
	firstDelay = 45,
	speed = 20,
	baseHp = 120, -- HP of the first bandit
	hpPerRaid = 40, -- every raid sends a tougher bandit
	bonkDamage = 25, -- damage of one player BONK
	bonkCooldown = 0.35,
	defendRange = 34, -- placed brainrots attack the bandit inside this many studs
	attackCooldown = 1.4, -- seconds between two attacks of one brainrot
}

-- Boss Bandit: right after every 3rd farm disaster a giant crowned bandit raids a base. Thick HP, slower,
-- shrugs off most knockback and drops a big reward (cash for the KO, a share for every helper, and a
-- Legendary-or-better boss loot brainrot at the foot of the ramp).
GameConfig.BOSS = {
	everyWaves = 3,
	scale = 2.1,
	hpMult = 6, -- x the HP a normal bandit of that raid would have
	speedMult = 0.7,
	knockbackResist = 0.35, -- he only takes this share of a weapon's knockback
	rewardSeconds = 120, -- KO reward = this many seconds of the base owner's income...
	minReward = 2500, -- ...but never less than this
	helperShare = 0.35, -- everyone else who hit him gets this share of the reward
	lootMinRarity = 4, -- Legendary or better
	lootMutationBoost = 6,
}

-- Player weapons: bought once in the WEAPONS shop, kept through rebirths, in the hotbar on every spawn.
-- Click/tap to swing; a hit damages the Brainrot Bandit and knocks him back (studs) with a BONK effect.
--   stun     seconds the bandit stands dazed after a hit
--   sweep    hits every bandit in range instead of only the nearest
--   crit     chance of a critical hit dealing critMult damage
GameConfig.WEAPON_ORDER = { "Pitchfork", "ExhaustPipe", "ChurnHammer", "CornBat", "Scythe" }
GameConfig.WEAPONS = {
	Pitchfork = {
		name = "Farm Pitchfork", icon = "🔱", cost = 400, damage = 40, range = 11, cooldown = 0.45, knockback = 7, stun = 0.3,
		word = "POKE!", color = Color3.fromRGB(210, 170, 110),
		special = "Long reach - poke him before he gets close",
	},
	ExhaustPipe = {
		name = "Tractor Exhaust Pipe", icon = "💨", cost = 4000, damage = 75, range = 9, cooldown = 0.6, knockback = 9, stun = 1.1,
		word = "PUFF!", color = Color3.fromRGB(150, 150, 160), smoke = true,
		special = "Diesel smoke cloud dazes the bandit for 1.1s",
	},
	ChurnHammer = {
		name = "Milk Churn Hammer", icon = "🥛", cost = 25000, damage = 150, range = 8.5, cooldown = 0.95, knockback = 22, stun = 0.6,
		word = "BONK!", color = Color3.fromRGB(240, 245, 255), milk = true,
		special = "Huge knockback - sends him flying down the ramp",
	},
	CornBat = {
		name = "Golden Corn Bat", icon = "🌽", cost = 150000, damage = 280, range = 9, cooldown = 0.55, knockback = 11, stun = 0.4,
		word = "THWACK!", color = Color3.fromRGB(255, 210, 50), crit = 0.3, critMult = 2.5,
		special = "30% chance of a golden CRIT for x2.5 damage",
	},
	Scythe = {
		name = "Scarecrow Scythe", icon = "🌾", cost = 1000000, damage = 550, range = 14, cooldown = 0.7, knockback = 13, stun = 0.5,
		word = "SLASH!", color = Color3.fromRGB(180, 120, 255), sweep = true,
		special = "Widest reach, sweeps every bandit around you",
	},
}

-- Barn Fuse Machine: on a raised barn deck beside the plateau, next to the village cabins. Fuses 3 identical
-- brainrots (same character AND mutation, from your base or your hands) into 1 with the mutation one step
-- up the ladder - with a small chance of jumping two steps.
GameConfig.FUSE = {
	position = Vector3.new(-107, 0, -63), -- centre of the barn deck (deck top = plateau height)
	range = 30, -- you must stand this close to the machine to fuse
	doubleChance = 0.12, -- chance of +2 mutation tiers instead of +1
	busySeconds = 3.2,
}

-- The village railway: one track winding across the field (Catmull-Rom spline through these points) and
-- the steam train that rolls along it every 45 seconds, dropping a cargo brainrot that may be a TRAIN GOD.
GameConfig.RAIL_POINTS = {
	Vector3.new(-125, 0, 185),
	Vector3.new(-95, 0, 182),
	Vector3.new(-65, 0, 196),
	Vector3.new(-35, 0, 180),
	Vector3.new(-10, 0, 152),
	Vector3.new(15, 0, 128),
	Vector3.new(42, 0, 112),
	Vector3.new(72, 0, 114),
	Vector3.new(98, 0, 104),
	Vector3.new(125, 0, 100),
}
GameConfig.TRAIN = {
	interval = 45, -- a train every 45 seconds
	warning = 4,
	firstDelay = 15,
	speed = 32,
	trainGodChance = 0.35, -- chance that the dropped cargo brainrot is a TRAIN GOD
	cargoLuck = 2,
}

-- Field brainrots wander around their spawn point.
GameConfig.WANDER = { radius = 12, speed = 4, pauseMin = 1.5, pauseMax = 4 }

-- Upgrade shop: value = base + step * level, price = cost * growth ^ level
GameConfig.UPGRADE_ORDER = { "Speed", "Carry", "Lock", "Stash" }
GameConfig.UPGRADES = {
	Speed = { label = "WalkSpeed", icon = "⚡", unit = " speed", base = 16, step = 3, max = 10, cost = 80, growth = 1.85 },
	Carry = { label = "Carry Capacity", icon = "🎒", unit = " brainrots", base = 1, step = 1, max = 6, cost = 200, growth = 2.6 },
	Lock = { label = "Base Lock", icon = "🔒", unit = "s lock", base = 20, step = 6, max = 8, cost = 150, growth = 1.9 },
	-- The personal Stash (bagspace): brainrots kept safe off your head and out of your base.
	Stash = { label = "Stash Space", icon = "📦", unit = " slots", base = 2, step = 1, max = 8, cost = 250, growth = 2.3 },
}

-- Rebirth: costs grow fast, every rebirth adds +50% income forever
GameConfig.REBIRTH = { baseCost = 25000, growth = 4, incomeBonus = 0.5 }

function GameConfig.upgradeValue(key: string, level: number): number
	local def = GameConfig.UPGRADES[key]
	return def.base + def.step * level
end

function GameConfig.upgradeCost(key: string, level: number): number
	local def = GameConfig.UPGRADES[key]
	return math.floor(def.cost * def.growth ^ level)
end

function GameConfig.rebirthCost(rebirths: number): number
	return math.floor(GameConfig.REBIRTH.baseCost * GameConfig.REBIRTH.growth ^ rebirths)
end

function GameConfig.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.REBIRTH.incomeBonus
end

function GameConfig.slotCount(rebirths: number): number
	return math.min(GameConfig.MAX_SLOTS, GameConfig.BASE_SLOTS + rebirths * GameConfig.SLOTS_PER_REBIRTH)
end

-- The field zone at a Z position, or nil when the position is on the plateau.
function GameConfig.zoneAt(z: number)
	if z < GameConfig.ZONES[1].minZ then
		return nil
	end
	for _, zone in GameConfig.ZONES do
		if z < zone.maxZ then
			return zone
		end
	end
	return GameConfig.ZONES[#GameConfig.ZONES]
end

return GameConfig
