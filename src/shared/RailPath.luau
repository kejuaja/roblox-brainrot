-- RailPath: the railway's centre line. A Catmull-Rom spline through GameConfig.RAIL_POINTS, sampled densely
-- once and measured by arc length, so RailPath.at(distance) gives the position and heading of any point
-- along the track. The world builder (fence gaps, tree clearance), the track builder and the moving train
-- all read the same line.

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local RailPath = {}

local SAMPLES_PER_SEGMENT = 12

local points = {} -- dense samples along the spline
local cumulative = {} -- arc length at each sample

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

do
	local control = GameConfig.RAIL_POINTS
	local n = #control
	for i = 1, n - 1 do
		local p0 = control[math.max(i - 1, 1)]
		local p1, p2 = control[i], control[i + 1]
		local p3 = control[math.min(i + 2, n)]
		for step = 0, SAMPLES_PER_SEGMENT - 1 do
			table.insert(points, catmullRom(p0, p1, p2, p3, step / SAMPLES_PER_SEGMENT))
		end
	end
	table.insert(points, control[n])
	cumulative[1] = 0
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
end

RailPath.length = cumulative[#cumulative]
RailPath.points = points

-- Position and unit heading (towards the far end) at a distance along the track, clamped to its ends.
function RailPath.at(distance: number): (Vector3, Vector3)
	local d = math.clamp(distance, 0, RailPath.length)
	local lo, hi = 1, #points
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if cumulative[mid] <= d then
			lo = mid
		else
			hi = mid
		end
	end
	local span = cumulative[hi] - cumulative[lo]
	local alpha = if span > 0 then (d - cumulative[lo]) / span else 0
	local direction = points[hi] - points[lo]
	return points[lo]:Lerp(points[hi], alpha), if direction.Magnitude > 0 then direction.Unit else Vector3.new(1, 0, 0)
end

-- Horizontal distance from a point to the nearest dense sample of the track.
function RailPath.distanceTo(position: Vector3): number
	local best = math.huge
	for _, p in points do
		local dx, dz = position.X - p.X, position.Z - p.Z
		local d = dx * dx + dz * dz
		if d < best then
			best = d
		end
	end
	return math.sqrt(best)
end

-- The Z where the track crosses the vertical line x = constant (nil if it never does).
function RailPath.crossingZ(x: number): number?
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if (a.X - x) * (b.X - x) <= 0 and a.X ~= b.X then
			local alpha = (x - a.X) / (b.X - a.X)
			return a.Z + (b.Z - a.Z) * alpha
		end
	end
	return nil
end

return RailPath
