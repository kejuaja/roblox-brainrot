-- BrainrotSpawner: keeps the field stocked with wandering brainrots. Deeper zones roll rarer ones
-- (zone luck), each has a "Grab" prompt that puts it on the player's head stack, and the farm disasters
-- (tornado, bull stampede) wreck whatever they pass over.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local BrainrotSpawner = {}

local rng = Random.new()
local folder: Folder
local active = {} -- [Model] = { id, mutation }
local activeCount = 0

local function nearHill(position: Vector3): boolean
	for _, hill in GameConfig.HILLS do
		local dx, dz = position.X - hill.X, position.Z - hill.Z
		if math.abs(dx) < GameConfig.HILL_SIZE / 2 + 4 and dz > -GameConfig.HILL_SIZE / 2 - 4 and dz < GameConfig.HILL_SIZE / 2 + 30 then
			return true
		end
	end
	return false
end

function BrainrotSpawner.randomPoint(minZ: number, maxZ: number): Vector3
	for _ = 1, 20 do
		local point = Vector3.new(
			rng:NextNumber(-GameConfig.FIELD_HALF_WIDTH, GameConfig.FIELD_HALF_WIDTH),
			0.2,
			rng:NextNumber(minZ, maxZ)
		)
		if not nearHill(point) then
			return point
		end
	end
	return Vector3.new(0, 0.2, (minZ + maxZ) / 2)
end

function BrainrotSpawner.grab(model: Model, player: Player)
	local info = active[model]
	local state = PlayerState.get(player)
	if not info or not state then
		return
	end
	if CarryService.isFull(state) then
		Remotes.notify(player, "🎒 Hands full! Bring them home or upgrade Carry Capacity.", Color3.fromRGB(255, 110, 110))
		return
	end
	active[model] = nil
	activeCount -= 1
	model:Destroy()
	CarryService.give(state, info.id, info.mutation)
	local rarity = Catalog.rarityOf(info.id)
	Remotes.notify(player, "Grabbed " .. Catalog.displayName(info.id, info.mutation) .. " (" .. rarity.key .. ", " .. Format.perSecond(Catalog.incomeFor(info.id, info.mutation)) .. ") - run it home!", rarity.color)
end

-- Walk legs are published as attributes (WalkFrom, WalkTo, WalkStart, WalkDuration in server time) so every
-- client animates the same smooth waddle; the server itself only snaps the pivot twice a second.
local function setWalk(model: Model, from: Vector3, to: Vector3, start: number, duration: number)
	model:SetAttribute("WalkFrom", from)
	model:SetAttribute("WalkTo", to)
	model:SetAttribute("WalkStart", start)
	model:SetAttribute("WalkDuration", duration)
end

-- options.still: a brainrot a player dropped - it stays put instead of wandering (it may sit on the plateau
-- or in the village, where wandering would walk it off the edge).
function BrainrotSpawner.spawn(position: Vector3, id: string, mutation: string, options: { still: boolean? }?): Model
	local model = Factory.build(id, mutation, { labelDistance = GameConfig.FIELD_LABEL_DISTANCE })
	local yaw = rng:NextNumber(0, math.pi * 2)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
	model:SetAttribute("Yaw", yaw)
	setWalk(model, position, position, 0, 0)
	CollectionService:AddTag(model, "FieldBrainrot")
	local rarityIndex = Catalog.RARITY_INDEX[Catalog.BY_ID[id].rarity]
	local grab = Instance.new("ProximityPrompt")
	grab.Name = "GrabPrompt"
	grab.ActionText = "Grab"
	grab.ObjectText = Catalog.displayName(id, mutation)
	grab.HoldDuration = 0.2 + rarityIndex * 0.15
	grab.MaxActivationDistance = 15
	grab.RequiresLineOfSight = false
	grab.Parent = model.PrimaryPart
	grab.Triggered:Connect(function(player)
		BrainrotSpawner.grab(model, player)
	end)
	model.Parent = folder
	active[model] = {
		id = id,
		mutation = mutation,
		home = position,
		position = position,
		walk = nil, -- { from, to, start, duration }
		nextMoveAt = workspace:GetServerTimeNow() + rng:NextNumber(0.5, 3),
		still = options ~= nil and options.still == true,
	}
	activeCount += 1
	return model
end

local function facing(from: Vector3, to: Vector3): CFrame
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.05 then
		return CFrame.new(to)
	end
	return CFrame.lookAt(to, to + flat.Unit)
end

-- Picks each idle brainrot's next stroll around its spawn point and keeps the server-side pivot in step.
local function updateWanderers()
	local now = workspace:GetServerTimeNow()
	local wander = GameConfig.WANDER
	for model, info in active do
		local walk = info.walk
		if walk then
			local alpha = math.clamp((now - walk.start) / walk.duration, 0, 1)
			info.position = walk.from:Lerp(walk.to, alpha)
			model:PivotTo(facing(walk.from, info.position))
			if alpha >= 1 then
				info.walk = nil
				info.nextMoveAt = now + rng:NextNumber(wander.pauseMin, wander.pauseMax)
			end
		elseif now >= info.nextMoveAt and not info.still then
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(wander.radius * 0.3, wander.radius)
			local target = info.home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			target = Vector3.new(
				math.clamp(target.X, -GameConfig.FIELD_HALF_WIDTH, GameConfig.FIELD_HALF_WIDTH),
				info.home.Y,
				math.clamp(target.Z, -30, GameConfig.FIELD_MAX_Z)
			)
			if nearHill(target) then
				info.nextMoveAt = now + 1
			else
				local duration = (target - info.position).Magnitude / wander.speed
				info.walk = { from = info.position, to = target, start = now, duration = math.max(duration, 0.5) }
				setWalk(model, info.position, target, now, info.walk.duration)
			end
		end
	end
end

local function pickZone()
	local total = 0
	for _, zone in GameConfig.ZONES do
		total += zone.weight
	end
	local roll = rng:NextNumber() * total
	for _, zone in GameConfig.ZONES do
		roll -= zone.weight
		if roll <= 0 then
			return zone
		end
	end
	return GameConfig.ZONES[1]
end

function BrainrotSpawner.spawnRandom()
	local zone = pickZone()
	local def = Catalog.rollCharacter(zone.luck)
	local mutation = Catalog.rollMutation(1 + zone.luck * 0.3)
	local minZ = math.max(zone.minZ, -30)
	local maxZ = math.min(zone.maxZ, GameConfig.FIELD_MAX_Z)
	BrainrotSpawner.spawn(BrainrotSpawner.randomPoint(minZ, maxZ), def.id, mutation.key)
end

-- Destroys every field brainrot within `radius` studs (flat) of `center`: the tornado's funnel, a bull.
function BrainrotSpawner.sweepCircle(center: Vector3, radius: number)
	for model in active do
		local p = model:GetPivot().Position
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= radius then
			active[model] = nil
			activeCount -= 1
			model:Destroy()
		end
	end
end

-- Drops brainrots a flung player was carrying back into the field around `position`.
function BrainrotSpawner.scatter(position: Vector3, items)
	for _, item in items do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(14, 30)
		local x = math.clamp(position.X + math.cos(angle) * distance, -GameConfig.FIELD_HALF_WIDTH + 4, GameConfig.FIELD_HALF_WIDTH - 4)
		local z = math.clamp(position.Z + math.sin(angle) * distance, -30, GameConfig.FIELD_MAX_Z - 5)
		local point = Vector3.new(x, 0.2, z)
		if nearHill(point) then
			point = BrainrotSpawner.randomPoint(math.max(-30, z - 30), math.min(GameConfig.FIELD_MAX_Z - 5, z + 30))
		end
		BrainrotSpawner.spawn(point, item.id, item.mutation)
	end
end

-- Destroys every field brainrot inside the Z band.
function BrainrotSpawner.sweep(minZ: number, maxZ: number)
	for model in active do
		local z = model:GetPivot().Position.Z
		if z >= minZ and z <= maxZ then
			active[model] = nil
			activeCount -= 1
			model:Destroy()
		end
	end
end

function BrainrotSpawner.start(world)
	folder = Instance.new("Folder")
	folder.Name = "FieldBrainrots"
	folder.Parent = world.folder
	for _ = 1, math.floor(GameConfig.MAX_FIELD_BRAINROTS * 0.8) do
		BrainrotSpawner.spawnRandom()
	end
	task.spawn(function()
		while true do
			task.wait(GameConfig.SPAWN_INTERVAL)
			if activeCount < GameConfig.MAX_FIELD_BRAINROTS then
				BrainrotSpawner.spawnRandom()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateWanderers()
		end
	end)
end

return BrainrotSpawner
