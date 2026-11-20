-- BrainrotInspector: the hover card. Point the mouse at any brainrot (in the field, in a base or on someone's
-- head) and a detail card follows the cursor - name, rarity, mutation, $/s, ATK, Passive Skill and owner -
-- while a white outline marks the brainrot. On touch screens a tap shows the card for a few seconds.
-- Everything is computed from the model's BrainrotId / Mutation attributes with the shared catalog.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Format = require(Shared:WaitForChild("Format"))

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local CARD_WIDTH, CARD_HEIGHT = 320, 196
local MAX_RANGE = 400

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotInspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.IgnoreGuiInset = true

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
card.BackgroundColor3 = Color3.fromRGB(22, 20, 38)
card.BackgroundTransparency = 0.06
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card
local border = Instance.new("UIStroke")
border.Thickness = 3
border.Parent = card
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = card
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = card

local function row(name: string, height: number, order: number, wrapped: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.LayoutOrder = order
	if wrapped then
		label.TextWrapped = true
		label.TextSize = 17
		label.TextYAlignment = Enum.TextYAlignment.Top
	else
		label.TextScaled = true
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = label
	label.Parent = card
	return label
end

local titleRow = row("Title", 28, 1)
local rarityRow = row("Rarity", 20, 2)
local incomeRow = row("Income", 22, 3)
local atkRow = row("Atk", 22, 4)
local passiveRow = row("Passive", 40, 5, true)
local ownerRow = row("Owner", 18, 6)

local outline = Instance.new("Highlight")
outline.Name = "InspectOutline"
outline.FillTransparency = 0.85
outline.FillColor = Color3.new(1, 1, 1)
outline.OutlineColor = Color3.new(1, 1, 1)
outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
outline.Enabled = false
outline.Parent = workspace -- created by this LocalScript, so it exists for this player only

gui.Parent = player:WaitForChild("PlayerGui")

local function brainrotFrom(instance: Instance?): Model?
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("BrainrotId") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function pick(screen: Vector2): Model?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, params)
	return result and brainrotFrom(result.Instance)
end

local shown: Model? = nil

local function fill(model: Model)
	local id = model:GetAttribute("BrainrotId")
	local mutationKey = model:GetAttribute("Mutation") or "Normal"
	local def = Catalog.BY_ID[id]
	if not def then
		return false
	end
	local rarity = Catalog.rarityOf(id)
	local mutation = Catalog.MUTATION_BY_KEY[mutationKey] or Catalog.MUTATIONS[1]
	titleRow.Text = def.name
	titleRow.TextColor3 = rarity.color
	local mutationText = Catalog.mutationText(mutationKey)
	rarityRow.Text = rarity.key .. (if mutationText ~= "" then "  ·  " .. mutationText else "")
	rarityRow.TextColor3 = if mutationKey ~= "Normal" then mutation.color else Color3.fromRGB(200, 200, 220)
	incomeRow.Text = "💰 " .. Format.perSecond(Catalog.incomeFor(id, mutationKey))
	incomeRow.TextColor3 = Color3.fromRGB(110, 255, 130)
	atkRow.Text = "⚔️ ATK " .. Catalog.atkFor(id, mutationKey)
	atkRow.TextColor3 = Color3.fromRGB(255, 140, 120)
	passiveRow.Text = "✨ " .. Catalog.passiveText(id)
	passiveRow.TextColor3 = Color3.fromRGB(255, 225, 120)
	local ownerId = model:GetAttribute("OwnerUserId")
	local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
	if owner then
		ownerRow.Text = "🏠 " .. (if owner == player then "Your base" else owner.DisplayName .. "'s base")
	elseif model:GetAttribute("WalkFrom") then
		ownerRow.Text = "🌾 Wild - press E to grab"
	else
		ownerRow.Text = "🎒 Being carried"
	end
	ownerRow.TextColor3 = Color3.fromRGB(170, 200, 255)
	border.Color = rarity.color
	return true
end

local function show(model: Model?)
	if model == shown then
		return
	end
	shown = model
	if model and fill(model) then
		outline.Adornee = model
		outline.Enabled = true
		card.Visible = true
	else
		shown = nil
		outline.Adornee = nil
		outline.Enabled = false
		card.Visible = false
	end
end

local function placeCard(screen: Vector2)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local x: number = screen.X + 22
	local y: number = screen.Y + 22
	if x + CARD_WIDTH > viewport.X - 8 then
		x = screen.X - CARD_WIDTH - 22
	end
	if y + CARD_HEIGHT > viewport.Y - 8 then
		y = viewport.Y - CARD_HEIGHT - 8
	end
	card.Position = UDim2.fromOffset(math.max(8, x), math.max(8, y))
end

local touchUntil = 0
local touchPoint = Vector2.zero

UserInputService.TouchTap:Connect(function(positions, processed)
	if processed or #positions == 0 then
		return
	end
	touchPoint = positions[1]
	local model = pick(touchPoint)
	show(model)
	if model then
		placeCard(touchPoint)
		touchUntil = os.clock() + 3
	end
end)

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		if shown and os.clock() > touchUntil then
			show(nil)
		end
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	if shown then
		placeCard(mouse)
	end
	accumulator += dt
	if accumulator < 0.05 then
		return
	end
	accumulator = 0
	if shown and not shown.Parent then
		show(nil)
	end
	show(pick(mouse))
	if shown then
		placeCard(mouse)
	end
end)
