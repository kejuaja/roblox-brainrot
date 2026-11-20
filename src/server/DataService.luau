-- DataService: saves and loads each player's progress (cash, rebirths, upgrades, placed brainrots) with
-- DataStoreService. Every call is wrapped in pcall, so an unpublished place or Studio without API access
-- simply plays without saving instead of erroring.

local DataStoreService = game:GetService("DataStoreService")

local DataService = {}

-- v2: the cast became farmyard brainrots, so v1 saves (old brainrot ids) start fresh.
local STORE_NAME = "BrainrotTsunamiTycoon_v2"

local store = nil
local ok, result = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if ok then
	store = result
else
	warn("[DataService] saving disabled:", result)
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService.load(player: Player)
	if not store then
		return nil
	end
	local success, data = pcall(function()
		return store:GetAsync(keyFor(player))
	end)
	if not success then
		warn("[DataService] load failed for", player.Name, data)
		return nil
	end
	return if type(data) == "table" then data else nil
end

function DataService.save(player: Player, payload)
	if not store then
		return
	end
	local success, err = pcall(function()
		store:SetAsync(keyFor(player), payload)
	end)
	if not success then
		warn("[DataService] save failed for", player.Name, err)
	end
end

return DataService
