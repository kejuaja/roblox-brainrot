-- MeteorService: the Meme Meteor event. Every so often a flaming meteor is announced, a red target ring
-- marks where it will land, it streaks down from the sky, explodes (harmlessly) and leaves a crater
-- with a guaranteed Epic-or-better brainrot, very likely mutated. Grab it before the next farm disaster.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local BrainrotSpawner = require(script.Parent:WaitForChild("BrainrotSpawner"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local MeteorService = {}

local CONFIG = GameConfig.METEOR
local ORANGE = Color3.fromRGB(255, 150, 50)
local EPIC_INDEX = 3

local function anchoredPart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

function MeteorService.drop(parent: Instance)
	local target = BrainrotSpawner.randomPoint(30, GameConfig.FIELD_MAX_Z - 20)
	local zone = GameConfig.zoneAt(target.Z)
	local def = Catalog.rollCharacter(3, EPIC_INDEX)
	local mutation = Catalog.rollMutation(4)
	Remotes.announce("☄️ A MEME METEOR is falling on " .. (if zone then zone.name else "the field") .. "! A rare brainrot is inside!", ORANGE)

	local ring = anchoredPart("MeteorTarget", parent)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 18, 18)
	ring.CFrame = CFrame.new(target.X, 0.4, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 50, 50)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35

	local rock = anchoredPart("MemeMeteor", parent)
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 8
	rock.Color = Color3.fromRGB(255, 100, 30)
	rock.Material = Enum.Material.CrackedLava
	local fire = Instance.new("Fire")
	fire.Size = 14
	fire.Heat = 20
	fire.Parent = rock
	local smoke = Instance.new("Smoke")
	smoke.Size = 8
	smoke.RiseVelocity = 4
	smoke.Color = Color3.fromRGB(80, 60, 50)
	smoke.Parent = rock
	local glow = Instance.new("PointLight")
	glow.Color = ORANGE
	glow.Range = 40
	glow.Brightness = 4
	glow.Parent = rock

	local start = target + Vector3.new(70, 240, 90)
	local elapsed = 0
	while elapsed < CONFIG.fallTime do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / CONFIG.fallTime, 1)
		rock.CFrame = CFrame.new(start:Lerp(target + Vector3.new(0, 3, 0), alpha * alpha))
	end
	rock:Destroy()
	ring:Destroy()

	local boom = Instance.new("Explosion")
	boom.Position = target
	boom.BlastRadius = 10
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace

	local crater = anchoredPart("Crater", parent)
	crater.Shape = Enum.PartType.Cylinder
	crater.Size = Vector3.new(0.4, 14, 14)
	crater.CFrame = CFrame.new(target.X, 0.3, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	crater.Color = Color3.fromRGB(45, 35, 30)
	crater.Material = Enum.Material.Basalt
	Debris:AddItem(crater, 20)

	BrainrotSpawner.spawn(target, def.id, mutation.key)
	local rarity = Catalog.rarityOf(def.id)
	Remotes.announce("☄️ The meteor dropped a " .. rarity.key .. " " .. Catalog.displayName(def.id, mutation.key) .. "!", rarity.color)
end

function MeteorService.start(world)
	task.spawn(function()
		task.wait(CONFIG.firstDelay)
		while true do
			local ok, err = pcall(MeteorService.drop, world.folder)
			if not ok then
				warn("[MeteorService]", err)
			end
			task.wait(CONFIG.interval)
		end
	end)
end

return MeteorService
