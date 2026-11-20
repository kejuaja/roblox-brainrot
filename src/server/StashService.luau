-- StashService: the player's personal Stash (bagspace) and the ways brainrots move between hands, Stash,
-- base and ground:
--   store(i)    hands -> Stash          (any time, anywhere, while there is Stash space)
--   take(i)     Stash -> hands          (needs a free Carry slot)
--   drop(i?)    hands -> the ground at your feet (G key / DROP button); anyone can pick it up again later
--   pickUp      base pedestal -> hands, or into the Stash when your hands are full (owner's Pick Up prompt)
-- Capacity starts at 2 and grows with the "Stash Space" upgrade. The Stash survives leaving the game and
-- tornado / stampede flings, is a fuse source for the Barn Fuse Machine, and is emptied by a rebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local BrainrotSpawner = require(script.Parent:WaitForChild("BrainrotSpawner"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local StashService = {}

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 110, 110)
local STASH = Color3.fromRGB(255, 200, 120)

function StashService.isFull(state): boolean
	return #state.stash >= PlayerState.stashMax(state)
end

function StashService.add(state, id: string, mutation: string): boolean
	if StashService.isFull(state) then
		return false
	end
	table.insert(state.stash, { id = id, mutation = mutation })
	PlayerState.discover(state, id, mutation)
	PlayerState.sync(state)
	return true
end

-- Removes the Stash entries at these positions (used by the Barn Fuse Machine).
function StashService.removeAt(state, positions: { number })
	table.sort(positions, function(a, b)
		return a > b
	end)
	for _, position in positions do
		table.remove(state.stash, position)
	end
	PlayerState.sync(state)
end

function StashService.clear(state)
	state.stash = {}
	PlayerState.sync(state)
end

local function validIndex(list, index): number?
	local i = tonumber(index)
	if i and i == math.floor(i) and list[i] then
		return i
	end
	return nil
end

function StashService.store(state, index)
	local i = validIndex(state.carried, index) or #state.carried
	local item = state.carried[i]
	if not item then
		Remotes.notify(state.player, "🎒 Your hands are empty - nothing to stash.", BAD)
		return
	end
	if StashService.isFull(state) then
		Remotes.notify(state.player, "📦 Stash full (" .. #state.stash .. "/" .. PlayerState.stashMax(state) .. ")! Upgrade Stash Space in the Upgrade Shop.", BAD)
		return
	end
	CarryService.removeAt(state, { i })
	StashService.add(state, item.id, item.mutation)
	Remotes.notify(state.player, "📦 Stashed " .. Catalog.displayName(item.id, item.mutation) .. " (" .. #state.stash .. "/" .. PlayerState.stashMax(state) .. ")", STASH)
end

function StashService.take(state, index)
	local i = validIndex(state.stash, index)
	local item = i and state.stash[i]
	if not item then
		return
	end
	if CarryService.isFull(state) then
		Remotes.notify(state.player, "🎒 Hands full! Drop or place what you carry first.", BAD)
		return
	end
	table.remove(state.stash, i)
	CarryService.give(state, item.id, item.mutation)
	Remotes.notify(state.player, "📦 Took " .. Catalog.displayName(item.id, item.mutation) .. " out of your Stash.", GOOD)
end

-- Puts a carried brainrot down on the ground just in front of the player, where it sits still until someone
-- grabs it (or a disaster wrecks it, if it's in the field).
function StashService.drop(state, index)
	local i = validIndex(state.carried, index) or #state.carried
	local item = state.carried[i]
	local character = state.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not item then
		Remotes.notify(state.player, "🎒 You're not carrying anything to drop.", BAD)
		return
	end
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local ahead = root.Position + root.CFrame.LookVector * 5
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local hit = workspace:Raycast(ahead + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	if not hit then
		hit = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
		ahead = root.Position
	end
	local ground = if hit then hit.Position else ahead - Vector3.new(0, 3, 0)
	CarryService.removeAt(state, { i })
	BrainrotSpawner.spawn(Vector3.new(ground.X, ground.Y + 0.05, ground.Z), item.id, item.mutation, { still = true })
	Remotes.notify(state.player, "⬇ Dropped " .. Catalog.displayName(item.id, item.mutation) .. " - grab it again any time!", STASH)
end

-- Owner's Pick Up prompt on a base pedestal: to the hands, or the Stash when the hands are full.
function StashService.pickUpFromBase(state, index: number, who: Player, removeSlot)
	if who ~= state.player then
		return
	end
	local entry = state.slots[index]
	if not entry then
		return
	end
	local toHands = not CarryService.isFull(state)
	if not toHands and StashService.isFull(state) then
		Remotes.notify(who, "🎒 Hands and Stash are both full! Place, drop or sell something first.", BAD)
		return
	end
	removeSlot(state, index)
	local name = Catalog.displayName(entry.id, entry.mutation)
	if toHands then
		CarryService.give(state, entry.id, entry.mutation)
		Remotes.notify(who, "🤲 Picked up " .. name .. " - it's on your head now.", GOOD)
	else
		StashService.add(state, entry.id, entry.mutation)
		Remotes.notify(who, "📦 Hands full - " .. name .. " went into your Stash.", STASH)
	end
	PlayerState.sync(state)
end

return StashService
