-- TitleService: every player's rebirth title floats above their head - "🚜 Tractor Titan · ♻️3" - with an
-- aura around their character that grows with the tier: drifting sparkles, then a glow, then orbiting
-- motes, up to a rainbow aura for a Brainrot Farm God. Rebuilt on every spawn and every rebirth.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local TitleService = {}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 180, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

local function clear(character: Model)
	for _, d in character:GetDescendants() do
		if d:GetAttribute("RebirthAura") then
			d:Destroy()
		end
	end
end

function TitleService.apply(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return
	end
	clear(character)
	local rebirths = player:GetAttribute("Rebirths") or 0
	local tier = GameConfig.rebirthTitle(rebirths)

	local gui = Instance.new("BillboardGui")
	gui.Name = "RebirthTitle"
	gui:SetAttribute("RebirthAura", true)
	gui.Size = UDim2.fromOffset(260, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = tier.icon .. " " .. tier.title .. (if rebirths > 0 then "  ·  ♻️" .. rebirths else "")
	label.TextColor3 = tier.color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	label.Parent = gui
	if tier.rainbow then
		CollectionService:AddTag(label, "RainbowText")
	end
	gui.Parent = head

	if tier.aura <= 0 then
		return
	end
	local color = if tier.rainbow then RAINBOW else ColorSequence.new(tier.color, Color3.new(1, 1, 1))
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment:SetAttribute("RebirthAura", true)
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	-- Rising sparkles: more of them every tier.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "AuraSparkles"
	sparkles.Rate = 4 + tier.aura * 4
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.LightEmission = 1
	sparkles.LockedToPart = false
	sparkles.Shape = Enum.ParticleEmitterShape.Cylinder
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.Color = color
	sparkles.Parent = attachment
	if tier.aura >= 3 then
		local light = Instance.new("PointLight")
		light:SetAttribute("RebirthAura", true)
		light.Color = tier.color
		light.Range = 8 + tier.aura * 2
		light.Brightness = 1.2
		light.Parent = root
	end
	if tier.aura >= 4 then
		-- A glowing ring of motes around the feet.
		local ring = Instance.new("ParticleEmitter")
		ring.Name = "AuraRing"
		ring.Rate = 10 + tier.aura * 4
		ring.Lifetime = NumberRange.new(0.6, 1)
		ring.Speed = NumberRange.new(0)
		ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		ring.LightEmission = 1
		ring.Shape = Enum.ParticleEmitterShape.Disc
		ring.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		ring.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		ring.Color = color
		ring.Parent = attachment
		attachment.CFrame = CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, 0)
	end
	if tier.aura >= 5 then
		local highlight = Instance.new("Highlight")
		highlight:SetAttribute("RebirthAura", true)
		highlight.FillTransparency = 1
		highlight.OutlineColor = tier.color
		highlight.OutlineTransparency = 0.3
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = character
	end
end

function TitleService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			character:WaitForChild("HumanoidRootPart", 5)
			TitleService.apply(player)
		end)
		player:GetAttributeChangedSignal("Rebirths"):Connect(function()
			TitleService.apply(player)
		end)
		if player.Character then
			task.spawn(TitleService.apply, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TitleService
