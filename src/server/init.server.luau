-- GameServer: bootstrap for Brainrot Farm Tycoon. Builds the world and the village, starts every service
-- (field spawner, farm disasters, meme meteor, bandit + boss bandit, steam train, shop, weapons, Barn Fuse
-- Machine, World Leaderboard, rebirth titles), and wires
-- players in and out: load save -> PlayerState -> base plot -> character stats + weapons. Runs the 1-second income tick, the deposit check and autosave.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(script.Remotes)
local PlayerState = require(script.PlayerState)
local DataService = require(script.DataService)
local WorldBuilder = require(script.WorldBuilder)
local CarryService = require(script.CarryService)
local BaseService = require(script.BaseService)
local BrainrotSpawner = require(script.BrainrotSpawner)
local DisasterService = require(script.DisasterService)
local VillageBuilder = require(script.VillageBuilder)
local LeaderboardService = require(script.LeaderboardService)
local TitleService = require(script.TitleService)
local MeteorService = require(script.MeteorService)
local BanditService = require(script.BanditService)
local TrainService = require(script.TrainService)
local ShopService = require(script.ShopService)
local WeaponService = require(script.WeaponService)
local FuseService = require(script.FuseService)

local AUTOSAVE_SECONDS = 60

local world = WorldBuilder.build()
local village = VillageBuilder.build(world)
BaseService.init(world)
ShopService.init()
WeaponService.init()
FuseService.build(world)
BrainrotSpawner.start(world)
DisasterService.start(world)
LeaderboardService.start(village.leaderboard)
TitleService.start()
MeteorService.start(world)
BanditService.start(world)
TrainService.start(world)

local function onCharacter(state, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	PlayerState.applyCharacter(state)
	state.carried = {}
	PlayerState.sync(state)
	task.delay(0.1, function()
		if character.Parent and state.player:WaitForChild("Backpack", 5) then
			WeaponService.giveAll(state)
		end
	end)
	if state.plot then
		task.defer(function()
			if character.Parent then
				character:PivotTo(state.plot.spawnCFrame)
			end
		end)
	end
	humanoid.Died:Connect(function()
		CarryService.clear(state)
	end)
end

local function onPlayerAdded(player: Player)
	local saved = DataService.load(player)
	if not player.Parent then
		return
	end
	local state = PlayerState.create(player, saved)
	local plot = BaseService.assignPlot(state)
	PlayerState.sync(state)
	player.CharacterAdded:Connect(function(character)
		onCharacter(state, character)
	end)
	if player.Character then
		task.spawn(onCharacter, state, player.Character)
	end
	if plot then
		Remotes.notify(player, "Welcome! Grab brainrots in the field, bring them home and survive the TORNADO and the BULL STAMPEDE!", Color3.fromRGB(255, 230, 80))
	else
		Remotes.notify(player, "All six bases are taken - you can still steal brainrots!", Color3.fromRGB(255, 110, 110))
	end
end

local function onPlayerRemoving(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	DataService.save(player, PlayerState.serialize(state))
	BaseService.releasePlot(state)
	PlayerState.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, state in PlayerState.all() do
		DataService.save(player, PlayerState.serialize(state))
	end
end)

-- Income tick and autosave.
task.spawn(function()
	local sinceSave = 0
	while true do
		task.wait(1)
		for _, state in PlayerState.all() do
			BaseService.tick(state)
		end
		sinceSave += 1
		if sinceSave >= AUTOSAVE_SECONDS then
			sinceSave = 0
			for player, state in PlayerState.all() do
				task.spawn(DataService.save, player, PlayerState.serialize(state))
			end
		end
	end
end)

-- Deposit check: five times a second, anyone standing on their own plot drops what they carry.
local sinceDeposit = 0
RunService.Heartbeat:Connect(function(dt)
	sinceDeposit += dt
	if sinceDeposit < 0.2 then
		return
	end
	sinceDeposit = 0
	for _, state in PlayerState.all() do
		BaseService.depositIfHome(state)
	end
end)
