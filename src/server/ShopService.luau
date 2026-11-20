-- ShopService: answers the client's Request remote - buying upgrades (WalkSpeed, Carry Capacity, Base Lock),
-- rebirthing, locking the base, buying weapons (WeaponService) and using the Barn Fuse Machine (FuseService).
-- Every request is validated on the server against PlayerState.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Format = require(Shared:WaitForChild("Format"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local FuseService = require(script.Parent:WaitForChild("FuseService"))
local StashService = require(script.Parent:WaitForChild("StashService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local ShopService = {}

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 110, 110)
local REBIRTH_COLOR = Color3.fromRGB(255, 120, 255)

local lastRequest = {}

function ShopService.buyUpgrade(state, key: string)
	local def = GameConfig.UPGRADES[key]
	if not def then
		return
	end
	local level = state.upgrades[key]
	if level >= def.max then
		Remotes.notify(state.player, def.label .. " is already MAX!", BAD)
		return
	end
	local cost = GameConfig.upgradeCost(key, level)
	if state.cash < cost then
		Remotes.notify(state.player, "Not enough cash: " .. def.label .. " costs " .. Format.cash(cost), BAD)
		return
	end
	PlayerState.addCash(state, -cost)
	state.upgrades[key] = level + 1
	PlayerState.applyCharacter(state)
	PlayerState.sync(state)
	Remotes.notify(state.player, def.icon .. " " .. def.label .. " upgraded to " .. GameConfig.upgradeValue(key, level + 1) .. def.unit .. "!", GOOD)
end

function ShopService.rebirth(state)
	local cost = GameConfig.rebirthCost(state.rebirths)
	if state.cash < cost then
		Remotes.notify(state.player, "♻️ Rebirth needs " .. Format.cash(cost), BAD)
		return
	end
	BaseService.clearSlots(state)
	StashService.clear(state)
	CarryService.clear(state)
	state.rebirths += 1
	state.cash = GameConfig.START_CASH
	state.vault = 0
	for key in state.upgrades do
		state.upgrades[key] = 0
	end
	BaseService.refreshPads(state)
	PlayerState.applyCharacter(state)
	PlayerState.sync(state)
	-- Weapons and the DEX survive a rebirth; the Stash is emptied along with the base.
	Remotes.announce(
		"♻️ " .. state.player.DisplayName .. " REBIRTHED! (Rebirth " .. state.rebirths .. " · x" .. GameConfig.rebirthMultiplier(state.rebirths) .. " income)",
		REBIRTH_COLOR
	)
end

function ShopService.init()
	Remotes.Request.OnServerEvent:Connect(function(player, action, arg, arg2)
		local state = PlayerState.get(player)
		if not state or type(action) ~= "string" then
			return
		end
		local t = os.clock()
		if (lastRequest[player] or 0) > t then
			return
		end
		lastRequest[player] = t + 0.2
		if action == "Upgrade" and type(arg) == "string" then
			ShopService.buyUpgrade(state, arg)
		elseif action == "Rebirth" then
			ShopService.rebirth(state)
		elseif action == "Lock" then
			BaseService.lock(state)
		elseif action == "BuyWeapon" and type(arg) == "string" then
			WeaponService.buy(state, arg)
		elseif action == "Drop" then
			StashService.drop(state, arg)
		elseif action == "StashStore" then
			StashService.store(state, arg)
		elseif action == "StashTake" then
			StashService.take(state, arg)
		elseif action == "WelcomeSeen" then
			state.seenWelcome = true
			player:SetAttribute("ShowWelcome", false)
		elseif action == "FuseMenu" then
			FuseService.sendMenu(state)
		elseif action == "Fuse" and type(arg) == "string" and type(arg2) == "string" then
			FuseService.fuse(state, arg, arg2)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
