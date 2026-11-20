-- DisasterService: the farm disasters that replaced the tsunami. They take turns, one every 42 seconds:
--   odd waves   FARM TORNADO        a spinning funnel full of flying hay zig-zags down the field, dragging
--                                   people in and hurling whoever it touches into the air
--   even waves  WILD BULL STAMPEDE  a herd of red-eyed bulls thunders down the field in a cloud of dust,
--                                   splitting around the SAFE HILLS and trampling anyone in the way
-- Each one is announced with an 8 s warning. Safe: the base plateau and its ramp, a SAFE HILL top, or the
-- village outside the field fence. Caught = flung through the air and every carried brainrot scatters back
-- into the field. Both also wreck field brainrots in their path.
-- The positions come from the shared DisasterPath functions; the server publishes only the seed, speed and
-- start time (workspace attributes) and every client draws the disaster itself (DisasterFx).
--   DisasterPhase  "calm" | "warning" | "active"      DisasterAt     server time the phase ends
--   DisasterWave   wave number                         DisasterKind   "Tornado" | "Stampede"
--   DisasterNext   the kind of the next wave           DisasterSeed / DisasterSpeed / DisasterStart

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DisasterPath = require(Shared:WaitForChild("DisasterPath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local CarryService = require(script.Parent:WaitForChild("CarryService"))
local BrainrotSpawner = require(script.Parent:WaitForChild("BrainrotSpawner"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local DisasterService = {}

local CONFIG = GameConfig.DISASTER
local WARN = Color3.fromRGB(255, 90, 90)
local CALM = Color3.fromRGB(140, 220, 255)

local rng = Random.new()
local lastHit = {} -- [Player] = os.clock() of the last fling

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(phase: string, at: number)
	workspace:SetAttribute("DisasterPhase", phase)
	workspace:SetAttribute("DisasterAt", at)
end

local function kindOf(wave: number): string
	return CONFIG.kinds[(wave - 1) % #CONFIG.kinds + 1]
end

local function speedFor(kind: string, wave: number): number
	local cfg = CONFIG[kind]
	local round = math.floor((wave - 1) / #CONFIG.kinds) -- each kind speeds up every time it comes back
	return math.min(cfg.startSpeed + round * cfg.speedPerWave, cfg.maxSpeed)
end

-- Throws the player (the client applies the velocity: it owns its character's physics) and scatters what
-- they carry back into the field around them.
local function fling(player: Player, root: BasePart, center: Vector3, kind: string, wave: number)
	local t = os.clock()
	if (lastHit[player] or 0) > t then
		return
	end
	lastHit[player] = t + CONFIG.hitCooldown
	local cfg = CONFIG[kind].fling
	local away = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	if away.Magnitude < 0.1 then
		local angle = rng:NextNumber(0, math.pi * 2)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	away = away.Unit
	if kind == "Stampede" then
		-- Bulls toss you forward along their charge and off to one side.
		away = (Vector3.new(0, 0, -1) + away * 0.8).Unit
	end
	local spin = Vector3.new(-away.Z, 0, away.X)
	local velocity = away * cfg.out + spin * cfg.spin + Vector3.new(0, cfg.up, 0)
	Remotes.Fling:FireClient(player, velocity, kind)

	local state = PlayerState.get(player)
	local items = if state then CarryService.takeAll(state) else {}
	if #items > 0 then
		BrainrotSpawner.scatter(root.Position, items)
	end
	local what = if kind == "Tornado" then "🌪️ The FARM TORNADO hurled you into the sky!" else "🐂 The bulls TRAMPLED you!"
	local suffix = if #items > 0 then " Your " .. #items .. " brainrot" .. (if #items == 1 then "" else "s") .. " scattered across the field!" else ""
	Remotes.notify(player, what .. suffix .. " (wave #" .. wave .. ")", WARN)
end

local function eachExposedPlayer(callback)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not DisasterPath.isSafe(root.Position) then
			callback(player, root)
		end
	end
end

local function runTornado(wave: number, seed: number, speed: number, start: number)
	local cfg = CONFIG.Tornado
	local duration = DisasterPath.duration("Tornado", seed, speed)
	local sinceSweep = 0
	while now() - start < duration do
		local dt = RunService.Heartbeat:Wait()
		local center = DisasterPath.tornado(seed, speed, now() - start)
		eachExposedPlayer(function(player, root)
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
			if flat < cfg.flingRadius and root.Position.Y < 70 then
				fling(player, root, center, "Tornado", wave)
			end
		end)
		sinceSweep += dt
		if sinceSweep > 0.1 then
			sinceSweep = 0
			BrainrotSpawner.sweepCircle(center, cfg.flingRadius - 2)
		end
	end
end

local function runStampede(wave: number, seed: number, speed: number, start: number)
	local cfg = CONFIG.Stampede
	local duration = DisasterPath.duration("Stampede", seed, speed)
	local sinceSweep = 0
	while now() - start < duration do
		local dt = RunService.Heartbeat:Wait()
		local bulls = DisasterPath.bulls(seed, speed, now() - start)
		eachExposedPlayer(function(player, root)
			if root.Position.Y > 12 then
				return
			end
			for _, bull in bulls do
				if bull.visible then
					local flat = Vector3.new(root.Position.X - bull.position.X, 0, root.Position.Z - bull.position.Z).Magnitude
					if flat < cfg.hitRadius then
						fling(player, root, bull.position, "Stampede", wave)
						break
					end
				end
			end
		end)
		sinceSweep += dt
		if sinceSweep > 0.12 then
			sinceSweep = 0
			for _, bull in bulls do
				if bull.visible then
					BrainrotSpawner.sweepCircle(bull.position, cfg.hitRadius - 1.5)
				end
			end
		end
	end
end

function DisasterService.start(_world)
	workspace:SetAttribute("DisasterWave", 0)
	workspace:SetAttribute("DisasterNext", kindOf(1))
	task.spawn(function()
		local wave = 0
		while true do
			setPhase("calm", now() + CONFIG.interval - CONFIG.warning)
			task.wait(CONFIG.interval - CONFIG.warning)

			wave += 1
			local kind = kindOf(wave)
			local cfg = CONFIG[kind]
			local seed = rng:NextInteger(1, 1000000)
			local speed = speedFor(kind, wave)
			local start = now() + CONFIG.warning
			workspace:SetAttribute("DisasterWave", wave)
			workspace:SetAttribute("DisasterKind", kind)
			workspace:SetAttribute("DisasterNext", kindOf(wave + 1))
			workspace:SetAttribute("DisasterSeed", seed)
			workspace:SetAttribute("DisasterSpeed", speed)
			workspace:SetAttribute("DisasterStart", start)
			setPhase("warning", start)
			local hint = if kind == "Tornado" then "GET TO YOUR BASE, A SAFE HILL OR THE VILLAGE!" else "GET OFF THE FIELD - BASE, SAFE HILL OR VILLAGE!"
			Remotes.announce(cfg.icon .. " " .. cfg.label .. " (wave #" .. wave .. ") in " .. CONFIG.warning .. "s! " .. hint, WARN)
			task.wait(math.max(0, start - now()))

			setPhase("active", start + DisasterPath.duration(kind, seed, speed))
			local ok, err = pcall(if kind == "Tornado" then runTornado else runStampede, wave, seed, speed, start)
			if not ok then
				warn("[DisasterService]", err)
			end
			Remotes.announce("✅ The " .. string.lower(cfg.label) .. " is over. The field is safe... for now.", CALM)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return DisasterService
