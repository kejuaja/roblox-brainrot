-- LeaderboardService: fills the giant World Leaderboard board in the village with the TOP CASH and TOP
-- REBIRTHS players. Every minute it writes everyone's numbers to two OrderedDataStores and reads the global
-- top 10 back (so it really is a WORLD board across servers); every few seconds it merges in the live values
-- of the players in this server. In Studio without API access it simply shows this server's players.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local LeaderboardService = {}

local SYNC_SECONDS = 60
local REFRESH_SECONDS = 5
local MAX_VALUE = 2 ^ 52

local stores = {}
for key, name in { cash = "BrainrotFarm_TopCash_v1", rebirths = "BrainrotFarm_TopRebirths_v1" } do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		stores[key] = store
	end
end

local globalTop = { cash = {}, rebirths = {} } -- [userId] = value, from the last global read
local names = {} -- [userId] = display name
local online = false

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "Player " .. userId
	return names[userId]
end

local function valuesFor(key: string)
	local merged = {}
	for userId, value in globalTop[key] do
		merged[userId] = value
	end
	for player, state in PlayerState.all() do
		if player.Parent then
			names[player.UserId] = player.DisplayName
			local value = if key == "cash" then math.floor(state.cash) else state.rebirths
			merged[player.UserId] = math.max(merged[player.UserId] or 0, value)
		end
	end
	local list = {}
	for userId, value in merged do
		table.insert(list, { userId = userId, value = value })
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.userId < b.userId
	end)
	return list
end

local function render(board)
	for key, rows in { cash = board.cash, rebirths = board.rebirths } do
		local list = valuesFor(key)
		for rank, row in rows do
			local entry = list[rank]
			if entry then
				row.name.Text = "#" .. rank .. "  " .. nameOf(entry.userId)
				row.value.Text = if key == "cash" then Format.cash(entry.value) else "♻️ " .. entry.value
			else
				row.name.Text = "#" .. rank .. "  ---"
				row.value.Text = ""
			end
		end
	end
	board.status.Text = if online then "🌍 Global top 10 · updates every minute" else "🏠 This server · global board needs a published game"
end

local function sync()
	if not stores.cash or not stores.rebirths then
		return
	end
	for player, state in PlayerState.all() do
		if player.Parent then
			pcall(function()
				stores.cash:SetAsync(tostring(player.UserId), math.clamp(math.floor(state.cash), 0, MAX_VALUE))
			end)
			pcall(function()
				stores.rebirths:SetAsync(tostring(player.UserId), math.clamp(state.rebirths, 0, MAX_VALUE))
			end)
		end
	end
	local anyOk = false
	for key, store in stores do
		local ok, page = pcall(function()
			return store:GetSortedAsync(false, 10):GetCurrentPage()
		end)
		if ok and page then
			anyOk = true
			local top = {}
			for _, item in page do
				local userId = tonumber(item.key)
				if userId then
					top[userId] = item.value
				end
			end
			globalTop[key] = top
		end
	end
	online = anyOk
end

function LeaderboardService.start(board)
	task.spawn(function()
		local sinceSync = SYNC_SECONDS - 8 -- first global read shortly after start
		while true do
			if sinceSync >= SYNC_SECONDS then
				sinceSync = 0
				sync()
			end
			local ok, err = pcall(render, board)
			if not ok then
				warn("[LeaderboardService]", err)
			end
			task.wait(REFRESH_SECONDS)
			sinceSync += REFRESH_SECONDS
		end
	end)
end

return LeaderboardService
