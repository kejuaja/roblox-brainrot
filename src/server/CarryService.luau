-- CarryService: the brainrots a player is carrying home. Each one is a mini model stacked on the
-- character's head; dying or being flung by a farm disaster drops the whole stack. Capacity comes from the Carry upgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local CarryService = {}

local CARRY_SCALE = 0.3 -- of the 2x model size: a head stack you can still see past

local function destroyModels(state)
	for _, item in state.carried do
		if item.model then
			item.model:Destroy()
			item.model = nil
		end
	end
end

-- Rebuilds the stack of mini brainrots on the character's head.
function CarryService.refresh(state)
	destroyModels(state)
	local character = state.player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local y = head.Size.Y / 2 + 0.2
	for _, item in state.carried do
		local model = Factory.build(item.id, item.mutation, { scale = CARRY_SCALE, noLabel = true })
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.Massless = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		model:PivotTo(head.CFrame * CFrame.new(0, y, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Name = "Carried_" .. item.id
		model.Parent = character
		item.model = model
		y += (model:GetAttribute("Height") or 2) + 0.1
	end
end

function CarryService.isFull(state): boolean
	return #state.carried >= PlayerState.carryMax(state)
end

function CarryService.give(state, id: string, mutation: string)
	table.insert(state.carried, { id = id, mutation = mutation })
	PlayerState.discover(state, id, mutation)
	CarryService.refresh(state)
	PlayerState.applyCharacter(state) -- SPEED passives of carried brainrots change WalkSpeed
	PlayerState.sync(state)
end

-- Removes and returns every carried brainrot (their models are destroyed).
function CarryService.takeAll(state)
	destroyModels(state)
	local items = state.carried
	state.carried = {}
	PlayerState.applyCharacter(state)
	PlayerState.sync(state)
	return items
end

-- Removes the carried brainrots at these stack positions (used by the Barn Fuse Machine).
function CarryService.removeAt(state, positions: { number })
	table.sort(positions, function(a, b)
		return a > b
	end)
	destroyModels(state)
	for _, position in positions do
		table.remove(state.carried, position)
	end
	CarryService.refresh(state)
	PlayerState.applyCharacter(state)
	PlayerState.sync(state)
end

function CarryService.clear(state): number
	local lost = #state.carried
	CarryService.takeAll(state)
	return lost
end

return CarryService
