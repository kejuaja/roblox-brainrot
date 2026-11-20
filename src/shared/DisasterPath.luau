-- DisasterPath: where the farm disasters are at any moment, as pure functions of (seed, speed, time). The
-- server uses them to fling players and trample field brainrots; every client uses the very same functions
-- to draw a smooth tornado and a smooth bull herd - no per-frame replication needed, everyone agrees.
--   DisasterPath.duration(kind, seed, speed)        seconds the disaster is on the move
--   DisasterPath.tornado(seed, speed, t)            funnel centre on the ground (Vector3), 0..1 progress
--   DisasterPath.bulls(seed, speed, t)              { { position, heading, visible } } per bull
--   DisasterPath.isSafe(position)                   plateau / ramp, a SAFE HILL top, or outside the field

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local DisasterPath = {}

local CONFIG = GameConfig.DISASTER
local HILL_HALF = GameConfig.HILL_SIZE / 2
local MAX_ROW_OFFSET = CONFIG.Stampede.rowGap + 10

-- A deterministic 0..1 noise value for (seed, i): identical on the server and on every client.
local function hash(seed: number, i: number): number
	local v = math.sin(seed * 12.9898 + i * 78.233) * 43758.5453
	return v - math.floor(v)
end
DisasterPath.hash = hash

function DisasterPath.tornado(seed: number, speed: number, t: number): (Vector3, number)
	local cfg = CONFIG.Tornado
	local travelled = math.max(0, speed * t)
	local z = CONFIG.startZ - travelled
	local phase = hash(seed, 1) * math.pi * 2
	local wobble = hash(seed, 2) * math.pi * 2
	local x = cfg.sway * math.sin(travelled / cfg.swayLength * math.pi * 2 + phase) + 12 * math.sin(travelled / 37 + wobble)
	x = math.clamp(x, -GameConfig.FIELD_HALF_WIDTH + 12, GameConfig.FIELD_HALF_WIDTH - 12)
	local progress = math.clamp(travelled / (CONFIG.startZ - CONFIG.endZ), 0, 1)
	return Vector3.new(x, 0, math.max(z, CONFIG.endZ)), progress
end

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- One bull: its lane, start offset and pace come from the seed. The herd splits around the SAFE HILLS (and
-- their ramps) and fans out to both sides near the base ramp before vanishing in its own dust.
local function bullAt(seed: number, speed: number, t: number, i: number, count: number): Vector3
	local lane = -GameConfig.FIELD_HALF_WIDTH + 6 + (2 * GameConfig.FIELD_HALF_WIDTH - 12) * (i - 0.5) / count
	local x = lane + (hash(seed, i) - 0.5) * 6
	local offset = (i % 2) * CONFIG.Stampede.rowGap + hash(seed, i + 50) * 10
	local pace = 1 + (hash(seed, i + 100) - 0.5) * 0.12
	local z = CONFIG.startZ + offset - speed * pace * t
	for _, hill in GameConfig.HILLS do
		local gap = HILL_HALF + 5
		if math.abs(x - hill.X) < gap then
			-- Influence ramps in before the hill's ramp (+Z side) and out after the hill.
			local enter = smoothstep(hill.Z + HILL_HALF + 40, hill.Z + HILL_HALF + 26, z)
			local leave = smoothstep(hill.Z - HILL_HALF - 14, hill.Z - HILL_HALF, z)
			local f = enter * leave
			local side = if x >= hill.X then 1 else -1
			x += (hill.X + side * gap - x) * f
		end
	end
	local fan = smoothstep(CONFIG.endZ + 34, CONFIG.endZ, z)
	if fan > 0 then
		local side = if x >= 0 then 1 else -1
		x += (side * (GameConfig.FIELD_HALF_WIDTH + 20) - x) * fan * fan
	end
	return Vector3.new(x, 0, z)
end

function DisasterPath.bulls(seed: number, speed: number, t: number)
	local count = CONFIG.Stampede.bulls
	local out = table.create(count)
	for i = 1, count do
		local position = bullAt(seed, speed, t, i, count)
		local ahead = bullAt(seed, speed, t + 0.05, i, count)
		local heading = ahead - position
		heading = if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 0, -1)
		out[i] = { position = position, heading = heading, visible = position.Z > CONFIG.endZ - 2 }
	end
	return out
end

function DisasterPath.duration(kind: string, _seed: number, speed: number): number
	if kind == "Tornado" then
		return (CONFIG.startZ - CONFIG.endZ) / speed + 1.5
	end
	return (CONFIG.startZ + MAX_ROW_OFFSET - CONFIG.endZ + 4) / (speed * 0.94)
end

-- The places a disaster can't touch you.
function DisasterPath.isSafe(position: Vector3): boolean
	if position.Z < CONFIG.safeZ then
		return true -- the base ramp and plateau
	end
	if math.abs(position.X) > GameConfig.FIELD_HALF_WIDTH + 6 then
		return true -- past the field fence: the village
	end
	for _, hill in GameConfig.HILLS do
		if math.abs(position.X - hill.X) <= HILL_HALF + 1 and math.abs(position.Z - hill.Z) <= HILL_HALF + 1 and position.Y > GameConfig.HILL_HEIGHT - 0.5 then
			return true
		end
	end
	return false
end

return DisasterPath
