-- HudController: the player's ScreenGui. Reads only what the server mirrors (Player attributes and the
-- workspace disaster attributes) and sends requests through the Request remote.
--   bottom-left   cash panel: cash, $/sec, vault, carry, slots, rebirths
--   top-center    farm disaster bar (tornado / bull stampede) with countdown, plus the zone you are in
--   bottom-right  DEX + ARMS, STASH + DROP (G), UPGRADES / REBIRTH / LOCK BASE; their panels open from them
--   top-right     "?" reopens the Welcome board (shown automatically to new players)
--   centre        DEX (Index Book: 16 brainrots + 9 mutations with progress), WEAPONS shop, Barn Fuse panel
--   top-center    notification feed; "+$123" popups when cash comes in
-- The village market stalls' prompts (attribute OpenPanel) open the same panels as the buttons.
-- The top-left corner is left free for Roblox's own menu buttons.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Format = require(Shared:WaitForChild("Format"))
local Catalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Factory = require(Shared:WaitForChild("BrainrotModelFactory"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local CashPopup = Remotes:WaitForChild("CashPopup") :: RemoteEvent
local FuseMenu = Remotes:WaitForChild("FuseMenu") :: RemoteEvent

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(22, 20, 38)
local PANEL_LIGHT = Color3.fromRGB(42, 38, 70)
local WHITE = Color3.new(1, 1, 1)
local MONEY = Color3.fromRGB(110, 255, 130)
local GOLD = Color3.fromRGB(255, 215, 70)
local DANGER = Color3.fromRGB(255, 70, 70)
local WATER = Color3.fromRGB(70, 170, 255)

local function create(className: string, props, parent: Instance?)
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(inst: GuiObject, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function outline(inst: Instance, color: Color3, thickness: number)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function textStroke(inst: Instance)
	create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }, inst)
end

local function label(parent: Instance, props)
	local base = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		base[key] = value
	end
	local l = create("TextLabel", base, parent)
	textStroke(l)
	return l
end

local function button(parent: Instance, text: string, color: Color3, props)
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Font = FONT,
		Text = text,
		TextColor3 = WHITE,
		TextScaled = true,
	}
	for key, value in props do
		base[key] = value
	end
	local b = create("TextButton", base, parent)
	round(b, 12)
	outline(b, Color3.new(0, 0, 0), 2)
	textStroke(b)
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
	create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Rotation = 90 }, b)
	return b
end

local function attr_(name: string, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local gui = create("ScreenGui", { Name = "BrainrotHud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
create("UIScale", { Name = "Scale" }, gui)

-- Danger frame: a red border that pulses while a farm disaster is coming.
local danger = create("Frame", { Name = "Danger", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
local dangerStroke = outline(danger, DANGER, 10)

-- Cash panel (bottom-left)
local stats = create("Frame", {
	Name = "Stats",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(300, 176),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.12,
}, gui)
round(stats, 16)
outline(stats, GOLD, 3)
create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, stats)
local cashLabel = label(stats, { Size = UDim2.new(1, 0, 0, 46), Text = "💰 $0", TextColor3 = MONEY })
local incomeLabel = label(stats, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 28), Text = "+$0/s", TextColor3 = GOLD })
local vaultLabel = label(stats, { Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 22), Text = "🏦 Vault $0 · step on COLLECT", TextColor3 = Color3.fromRGB(200, 255, 210) })
local carryLabel = label(stats, { Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 22), Text = "🎒 Carry 0/1" })
local slotLabel = label(stats, { Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 22), Text = "🏠 Slots 0/6 · ♻️ Rebirth 0" })

local popupAnchor = create("Frame", { Name = "PopupAnchor", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 330, 1, -130), Size = UDim2.fromOffset(200, 40) }, gui)

-- Disaster bar (top-center)
local tsunamiBar = create("Frame", {
	Name = "DisasterBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(620, 62),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
}, gui)
round(tsunamiBar, 14)
local tsunamiStroke = outline(tsunamiBar, WATER, 3)
local tsunamiFill = create("Frame", { Name = "Fill", BackgroundColor3 = WATER, BackgroundTransparency = 0.35, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, tsunamiBar)
round(tsunamiFill, 14)
local tsunamiLabel = label(tsunamiBar, {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 1, -12),
	Text = "🌪️ Farm disaster incoming...",
	TextXAlignment = Enum.TextXAlignment.Center,
})
local zoneLabel = label(gui, {
	Name = "Zone",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 78),
	Size = UDim2.fromOffset(420, 26),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- Notification feed (under the disaster bar)
local feed = create("Frame", { Name = "Feed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(640, 200), BackgroundTransparency = 1 }, gui)
create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, feed)

-- Action buttons (bottom-right)
local actions = create("Frame", { Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(210, 312), BackgroundTransparency = 1 }, gui)
create("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }, actions)
local topRow = create("Frame", { Name = "TopRow", Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = -1 }, actions)
local dexButton = button(topRow, "📖 DEX", Color3.fromRGB(150, 90, 230), { Size = UDim2.new(0.5, -5, 1, 0) })
local weaponsButton = button(topRow, "⚔️ ARMS", Color3.fromRGB(230, 140, 40), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -5, 1, 0) })
local bagRow = create("Frame", { Name = "BagRow", Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = 0 }, actions)
local stashButton = button(bagRow, "📦 STASH", Color3.fromRGB(220, 150, 50), { Size = UDim2.new(0.5, -5, 1, 0) })
local dropButton = button(bagRow, "⬇ DROP (G)", Color3.fromRGB(150, 110, 80), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -5, 1, 0) })
local upgradesButton = button(actions, "⚡ UPGRADES", Color3.fromRGB(60, 140, 255), { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 1 })
local rebirthButton = button(actions, "♻️ REBIRTH", Color3.fromRGB(200, 70, 230), { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 2 })
local lockButton = button(actions, "🔓 LOCK BASE", Color3.fromRGB(230, 70, 70), { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 3 })

local function panel(name: string, title: string, size: Vector2, accent: Color3)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -240, 1, -16),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, gui)
	round(frame, 16)
	outline(frame, accent, 3)
	label(frame, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -70, 0, 34), Text = title, TextColor3 = accent })
	local close = button(frame, "X", Color3.fromRGB(90, 90, 110), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(38, 34) })
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	return frame
end

-- Upgrade shop
local shop = panel("Shop", "⚡ UPGRADE SHOP", Vector2.new(380, 364), Color3.fromRGB(90, 170, 255))
local shopRows = {}
for index, key in GameConfig.UPGRADE_ORDER do
	local def = GameConfig.UPGRADES[key]
	local row = create("Frame", { Position = UDim2.fromOffset(14, 54 + (index - 1) * 76), Size = UDim2.new(1, -28, 0, 68), BackgroundColor3 = PANEL_LIGHT }, shop)
	round(row, 12)
	local title = label(row, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -150, 0, 28), Text = def.icon .. " " .. def.label })
	local info = label(row, { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -150, 0, 22), Text = "", TextColor3 = Color3.fromRGB(190, 200, 255) })
	local buy = button(row, "BUY", Color3.fromRGB(60, 190, 90), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(126, 50) })
	buy.MouseButton1Click:Connect(function()
		Request:FireServer("Upgrade", key)
	end)
	shopRows[key] = { title = title, info = info, buy = buy }
end

-- Rebirth panel
local rebirthPanel = panel("RebirthPanel", "♻️ REBIRTH", Vector2.new(380, 250), Color3.fromRGB(230, 110, 255))
local rebirthInfo = label(rebirthPanel, {
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.new(1, -32, 0, 110),
	Text = "",
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextScaled = false,
	TextSize = 20,
})
local rebirthConfirm = button(rebirthPanel, "REBIRTH!", Color3.fromRGB(200, 70, 230), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -32, 0, 56) })
rebirthConfirm.MouseButton1Click:Connect(function()
	Request:FireServer("Rebirth")
end)

-- Big centred panels (DEX, WEAPONS, FUSE): shrink to fit small screens, scroll when the content is taller.
local function bigPanel(name: string, title: string, accent: Color3, maxSize: Vector2, headerHeight: number)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.82),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.03,
		Visible = false,
	}, gui)
	create("UISizeConstraint", { MaxSize = maxSize }, frame)
	round(frame, 16)
	outline(frame, accent, 3)
	label(frame, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -80, 0, 34), Text = title, TextColor3 = accent })
	local close = button(frame, "X", Color3.fromRGB(90, 90, 110), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(38, 34) })
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	local body = create("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(12, headerHeight),
		Size = UDim2.new(1, -24, 1, -headerHeight - 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, frame)
	return frame, body
end

local dexPanel, dexBody = bigPanel("DexPanel", "📖 BRAINROT DEX", Color3.fromRGB(190, 140, 255), Vector2.new(760, 600), 128)
local weaponPanel, weaponBody = bigPanel("WeaponPanel", "⚔️ FARM WEAPONS", Color3.fromRGB(255, 170, 60), Vector2.new(600, 600), 50)
local fusePanel, fuseBody = bigPanel("FusePanel", "🧬 BARN FUSE MACHINE", Color3.fromRGB(200, 130, 255), Vector2.new(640, 560), 50)

local stashPanel, stashBody = bigPanel("StashPanel", "📦 MY STASH", Color3.fromRGB(255, 190, 100), Vector2.new(560, 600), 50)

local allPanels = { shop, rebirthPanel, dexPanel, weaponPanel, fusePanel, stashPanel }
local function toggle(panelFrame: Frame)
	local open = not panelFrame.Visible
	for _, other in allPanels do
		other.Visible = false
	end
	panelFrame.Visible = open
end

upgradesButton.MouseButton1Click:Connect(function()
	toggle(shop)
end)
rebirthButton.MouseButton1Click:Connect(function()
	toggle(rebirthPanel)
end)
dexButton.MouseButton1Click:Connect(function()
	toggle(dexPanel)
end)
weaponsButton.MouseButton1Click:Connect(function()
	toggle(weaponPanel)
end)

---------------------------------------------------------------------------------------------------------------
-- DEX: the Index Book. Two tabs - the 16 brainrots (3D portrait, silhouette until found, which of the 9
-- mutations you've owned it in) and the 9 mutations - and a progress bar over brainrots + mutations.
---------------------------------------------------------------------------------------------------------------
local DIM = Color3.fromRGB(70, 68, 92)
local dexProgressBack = create("Frame", { Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 28), BackgroundColor3 = Color3.fromRGB(40, 30, 60) }, dexPanel)
round(dexProgressBack, 10)
outline(dexProgressBack, Color3.new(0, 0, 0), 2)
local dexProgressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(170, 110, 255), BorderSizePixel = 0 }, dexProgressBack)
round(dexProgressFill, 10)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 200, 255), Color3.fromRGB(220, 110, 255)) }, dexProgressFill)
local dexProgressText = label(dexProgressBack, { Size = UDim2.fromScale(1, 1), Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, dexProgressText)
local charTab = button(dexPanel, "🐮 BRAINROTS", Color3.fromRGB(150, 90, 230), { Position = UDim2.fromOffset(16, 86), Size = UDim2.new(0.5, -21, 0, 34) })
local mutTab = button(dexPanel, "✦ MUTATIONS", Color3.fromRGB(90, 90, 120), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 86), Size = UDim2.new(0.5, -21, 0, 34) })

local function grid(cell: Vector2)
	local frame = create("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, dexBody)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, frame)
	return frame
end
local charGrid = grid(Vector2.new(164, 222))
local mutGrid = grid(Vector2.new(164, 168))
mutGrid.Visible = false

local function selectTab(characters: boolean)
	charGrid.Visible = characters
	mutGrid.Visible = not characters
	charTab.BackgroundColor3 = if characters then Color3.fromRGB(150, 90, 230) else Color3.fromRGB(90, 90, 120)
	mutTab.BackgroundColor3 = if characters then Color3.fromRGB(90, 90, 120) else Color3.fromRGB(150, 90, 230)
	dexBody.CanvasPosition = Vector2.zero
end
charTab.MouseButton1Click:Connect(function()
	selectTab(true)
end)
mutTab.MouseButton1Click:Connect(function()
	selectTab(false)
end)

local function smallText(parent: Instance, y: number, height: number, text: string, color: Color3)
	return label(parent, { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, height), Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
end

local EFFECT_CLASSES = { "ParticleEmitter", "Sparkles", "Fire", "Smoke", "PointLight", "Highlight", "BillboardGui" }

-- Puts a brainrot's 3D portrait into a ViewportFrame: its best owned mutation, or a black silhouette.
local function portrait(viewport: ViewportFrame, id: string, mutationKey: string?)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	local model = Factory.build(id, mutationKey or "Normal", { noLabel = true })
	for _, d in model:GetDescendants() do
		if table.find(EFFECT_CLASSES, d.ClassName) then
			d:Destroy()
		elseif d:IsA("BasePart") then
			if not mutationKey then
				CollectionService:RemoveTag(d, "RainbowPart")
				d.Color = Color3.fromRGB(12, 10, 20)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
				d.Transparency = 0
			elseif mutationKey == "Rainbow" then
				-- A portrait doesn't need live hue cycling: give each part a fixed rainbow tint.
				CollectionService:RemoveTag(d, "RainbowPart")
				d.Color = Color3.fromHSV(math.random(), 0.7, 1)
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local height = model:GetAttribute("Height") or 4
	local extents = model:GetExtentsSize()
	local center = Vector3.new(0, height / 2, 0)
	local distance = math.max(extents.X, extents.Y, extents.Z) * 1.55 + 1.5
	local camera = viewport.CurrentCamera
	if camera then
		camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.5, distance * 0.3, -distance * 0.85), center)
	end
end

local charCards = {}
for index, def in Catalog.CHARACTERS do
	local card = create("Frame", { Name = def.id, BackgroundColor3 = PANEL_LIGHT, LayoutOrder = index }, charGrid)
	round(card, 12)
	local stroke = outline(card, DIM, 2)
	local viewport = create("ViewportFrame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 104),
		BackgroundColor3 = Color3.fromRGB(28, 24, 48),
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
	}, card)
	round(viewport, 10)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	label(card, { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(44, 18), Text = string.format("#%02d", index), TextColor3 = Color3.fromRGB(200, 200, 230), ZIndex = 2 })
	local nameLabel = smallText(card, 114, 22, "???", WHITE)
	smallText(card, 137, 16, def.rarity, Catalog.rarityOf(def.id).color)
	local infoLabel = smallText(card, 155, 16, "", Color3.fromRGB(200, 255, 210))
	local passiveLabel = smallText(card, 173, 15, "", Color3.fromRGB(190, 200, 255))
	local dots = create("Frame", { Position = UDim2.fromOffset(6, 196), Size = UDim2.new(1, -12, 0, 14), BackgroundTransparency = 1 }, card)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, dots)
	local dotFrames = {}
	for mi, mutation in Catalog.MUTATIONS do
		local dot = create("Frame", { Size = UDim2.fromOffset(13, 13), BackgroundColor3 = DIM, LayoutOrder = mi }, dots)
		round(dot, 7)
		outline(dot, Color3.new(0, 0, 0), 1)
		dotFrames[mutation.key] = dot
	end
	charCards[def.id] = { stroke = stroke, viewport = viewport, name = nameLabel, info = infoLabel, passive = passiveLabel, dots = dotFrames, shown = "" }
end

local mutCards = {}
for index, mutation in Catalog.MUTATIONS do
	local card = create("Frame", { Name = mutation.key, BackgroundColor3 = PANEL_LIGHT, LayoutOrder = index }, mutGrid)
	round(card, 12)
	local stroke = outline(card, DIM, 2)
	local swatch = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = DIM }, card)
	round(swatch, 27)
	outline(swatch, Color3.new(0, 0, 0), 2)
	local gradient = create("UIGradient", {
		Enabled = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
		}),
		Rotation = 45,
	}, swatch)
	local mark = label(swatch, { Size = UDim2.fromScale(1, 1), Text = "?", TextXAlignment = Enum.TextXAlignment.Center })
	local nameLabel = smallText(card, 70, 22, "???", WHITE)
	local multText = if mutation.allIncome then "x" .. mutation.allIncome .. " ALL base income" else "x" .. mutation.mult .. " income"
	smallText(card, 93, 17, multText, GOLD)
	local sourceLabel = smallText(card, 112, 30, mutation.source or "", Color3.fromRGB(190, 200, 255))
	sourceLabel.TextWrapped = true
	local foundLabel = smallText(card, 145, 16, "", Color3.fromRGB(200, 255, 210))
	mutCards[mutation.key] = { stroke = stroke, swatch = swatch, gradient = gradient, mark = mark, name = nameLabel, found = foundLabel }
end

local lastDexJson = nil
local function refreshDex()
	local json = player:GetAttribute("Dex") or "{}"
	if json == lastDexJson then
		return
	end
	lastDexJson = json
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		data = {}
	end
	local owned = {} -- [id] = { [mutationKey] = true }
	local mutationFound = {} -- [mutationKey] = how many brainrots you've owned in it
	local characters, variants = 0, 0
	for id, list in data do
		if Catalog.BY_ID[id] and type(list) == "table" then
			owned[id] = {}
			characters += 1
			for _, key in list do
				if Catalog.MUTATION_BY_KEY[key] then
					owned[id][key] = true
					variants += 1
					mutationFound[key] = (mutationFound[key] or 0) + 1
				end
			end
		end
	end
	local mutations = 0
	for _ in mutationFound do
		mutations += 1
	end
	local totalChars, totalMuts = #Catalog.CHARACTERS, #Catalog.MUTATIONS
	local fraction = (characters + mutations) / (totalChars + totalMuts)
	local percent = math.floor(fraction * 100 + 0.5)
	dexProgressFill.Size = UDim2.fromScale(fraction, 1)
	dexProgressText.Text = "Brainrots " .. characters .. "/" .. totalChars .. "  ·  Mutations " .. mutations .. "/" .. totalMuts
		.. "  ·  Variants " .. variants .. "/" .. totalChars * totalMuts .. "  ·  " .. percent .. "%"
	charTab.Text = "🐮 BRAINROTS " .. characters .. "/" .. totalChars
	mutTab.Text = "✦ MUTATIONS " .. mutations .. "/" .. totalMuts
	dexButton.Text = "📖 DEX " .. percent .. "%"

	for _, def in Catalog.CHARACTERS do
		local card = charCards[def.id]
		local found = owned[def.id]
		local best = nil
		if found then
			for index = #Catalog.MUTATIONS, 1, -1 do
				local key = Catalog.MUTATIONS[index].key
				if found[key] and key ~= "TrainGod" then
					best = key
					break
				end
			end
			best = best or "TrainGod"
		end
		local shown = best or "?"
		if card.shown ~= shown then
			card.shown = shown
			portrait(card.viewport, def.id, best)
		end
		card.stroke.Color = if found then Catalog.rarityOf(def.id).color else DIM
		card.name.Text = if found then def.name else "???"
		card.info.Text = if found then Format.perSecond(def.income) .. " · ATK " .. def.atk else "Not found yet"
		card.passive.Text = if found then "✨ " .. def.passive.name else ""
		for key, dot in card.dots do
			dot.BackgroundColor3 = if found and found[key] then Catalog.MUTATION_BY_KEY[key].color else DIM
		end
	end
	for _, mutation in Catalog.MUTATIONS do
		local card = mutCards[mutation.key]
		local count = mutationFound[mutation.key]
		card.stroke.Color = if count then mutation.color else DIM
		card.swatch.BackgroundColor3 = if count then (if mutation.key == "Rainbow" then WHITE else mutation.color) else DIM
		card.gradient.Enabled = count ~= nil and mutation.key == "Rainbow"
		card.mark.Text = if count then "" else "?"
		card.name.Text = if count then string.upper(mutation.label) else "???"
		card.name.TextColor3 = if count then mutation.color else WHITE
		card.found.Text = "Owned on " .. (count or 0) .. "/" .. totalChars .. " brainrots"
	end
end

---------------------------------------------------------------------------------------------------------------
-- WEAPONS shop: five farm weapons, bought once, kept forever; equip from the hotbar and click to swing.
---------------------------------------------------------------------------------------------------------------
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, weaponBody)
label(weaponBody, {
	Size = UDim2.new(1, -10, 0, 40),
	Text = "Buy once, keep forever (even after rebirth). Equip from your hotbar and click / tap to BONK the Bandit back!",
	TextScaled = false,
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 220, 160),
	LayoutOrder = 0,
})
local weaponRows = {}
for index, id in GameConfig.WEAPON_ORDER do
	local def = GameConfig.WEAPONS[id]
	local row = create("Frame", { Size = UDim2.new(1, -10, 0, 96), BackgroundColor3 = PANEL_LIGHT, LayoutOrder = index }, weaponBody)
	round(row, 12)
	outline(row, def.color, 2)
	label(row, { Position = UDim2.fromOffset(8, 14), Size = UDim2.fromOffset(64, 64), Text = def.icon, TextXAlignment = Enum.TextXAlignment.Center })
	label(row, { Position = UDim2.fromOffset(80, 6), Size = UDim2.new(1, -230, 0, 28), Text = def.name, TextColor3 = def.color })
	label(row, {
		Position = UDim2.fromOffset(80, 36),
		Size = UDim2.new(1, -230, 0, 20),
		Text = "💥 " .. def.damage .. " DMG · 📏 " .. def.range .. " · ⏱ " .. def.cooldown .. "s · 💨 KB " .. def.knockback,
		TextColor3 = Color3.fromRGB(220, 220, 255),
	})
	label(row, {
		Position = UDim2.fromOffset(80, 58),
		Size = UDim2.new(1, -230, 0, 32),
		Text = def.special,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(190, 200, 230),
	})
	local buy = button(row, Format.cash(def.cost), Color3.fromRGB(60, 190, 90), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(136, 56) })
	buy.MouseButton1Click:Connect(function()
		Request:FireServer("BuyWeapon", id)
	end)
	weaponRows[id] = buy
end

local function refreshWeapons(cash: number)
	local owned = {}
	for _, id in string.split(attr_("Weapons", ""), ",") do
		owned[id] = true
	end
	for id, buy in weaponRows do
		local def = GameConfig.WEAPONS[id]
		if owned[id] then
			buy.Text = "✓ OWNED"
			buy.BackgroundColor3 = Color3.fromRGB(70, 150, 200)
		else
			buy.Text = Format.cash(def.cost)
			buy.BackgroundColor3 = if cash >= def.cost then Color3.fromRGB(60, 190, 90) else Color3.fromRGB(150, 70, 70)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- BARN FUSE MACHINE: opened by the barn's prompt; lists every brainrot you hold 2+ copies of across your
-- base, hands and Stash. On top: the whole mutation chain as wrapping chips (the 8 fuse tiers in order,
-- then TRAIN GOD, which can't be fused) so nothing overlaps on any screen size.
---------------------------------------------------------------------------------------------------------------
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, fuseBody)
local fuseIntro = label(fuseBody, {
	Size = UDim2.new(1, -10, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Text = "",
	TextScaled = false,
	TextSize = 17,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(235, 210, 255),
	LayoutOrder = 0,
})
local chainTitle = label(fuseBody, {
	Size = UDim2.new(1, -10, 0, 26),
	Text = "MUTATION CHAIN  ·  " .. #Catalog.MUTATIONS .. " MUTATIONS",
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Center,
	LayoutOrder = 1,
})
create("UITextSizeConstraint", { MaxTextSize = 22 }, chainTitle)
local chain = create("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, fuseBody)
create("UIGridLayout", {
	CellSize = UDim2.fromOffset(118, 54),
	CellPadding = UDim2.fromOffset(6, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, chain)
local function chainChip(order: number, mutation, top: string, bottom: string)
	local chip = create("Frame", { BackgroundColor3 = mutation.color:Lerp(PANEL, 0.75), LayoutOrder = order }, chain)
	round(chip, 10)
	outline(chip, mutation.color, 2)
	local name = label(chip, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 26), Text = top, TextColor3 = mutation.color, TextXAlignment = Enum.TextXAlignment.Center })
	create("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 11 }, name)
	local info = label(chip, { Position = UDim2.fromOffset(6, 31), Size = UDim2.new(1, -12, 0, 19), Text = bottom, TextColor3 = Color3.fromRGB(235, 235, 250), TextXAlignment = Enum.TextXAlignment.Center })
	create("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10 }, info)
	if mutation.key == "Rainbow" then
		CollectionService:AddTag(name, "RainbowText")
	end
end
for tier, key in Catalog.FUSE_LADDER do
	local mutation = Catalog.MUTATION_BY_KEY[key]
	local tail = if tier < #Catalog.FUSE_LADDER then "  ➜" else "  ★"
	chainChip(tier, mutation, tier .. ". " .. mutation.label, "x" .. mutation.mult .. " income" .. tail)
end
local trainGod = Catalog.MUTATION_BY_KEY.TrainGod
if trainGod then
	chainChip(#Catalog.FUSE_LADDER + 1, trainGod, "🚂 " .. trainGod.label, "x" .. (trainGod.allIncome or 2) .. " base · no fuse")
end

local fuseRows = {}
local function rebuildFuse(groups, doubleChance: number)
	for _, row in fuseRows do
		row:Destroy()
	end
	fuseRows = {}
	fuseIntro.Text = "Put 3 IDENTICAL brainrots (same brainrot + same mutation) from your base, hands or Stash into the machine: you get 1 back, one mutation higher. "
		.. math.floor(doubleChance * 100 + 0.5) .. "% chance it jumps TWO!"
	if #groups == 0 then
		local empty = label(fuseBody, {
			Size = UDim2.new(1, -10, 0, 60),
			Text = "You don't have two of the same brainrot in your base, hands or Stash yet. Grab duplicates in the field and come back!",
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
		})
		table.insert(fuseRows, empty)
		return
	end
	for index, group in groups do
		local def = type(group) == "table" and Catalog.BY_ID[group.id]
		if def then
			local rarityColor = Catalog.rarityOf(group.id).color
			local mutation = Catalog.MUTATION_BY_KEY[group.mutation] or Catalog.MUTATIONS[1]
			local nextKey = Catalog.fuseUpgrade(group.mutation, 1)
			local jumpKey = Catalog.fuseUpgrade(group.mutation, 2)
			local row = create("Frame", { Size = UDim2.new(1, -10, 0, 92), BackgroundColor3 = PANEL_LIGHT, LayoutOrder = 10 + index }, fuseBody)
			round(row, 12)
			outline(row, rarityColor, 2)
			label(row, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 26), Text = Catalog.displayName(group.id, group.mutation), TextColor3 = rarityColor })
			local arrow
			if nextKey then
				local nextMutation = Catalog.MUTATION_BY_KEY[nextKey]
				arrow = "x" .. math.min(group.count, 3) .. "/3  →  " .. string.upper(nextMutation.label) .. " x" .. nextMutation.mult
				if jumpKey and jumpKey ~= nextKey then
					arrow ..= "   (🎰 " .. string.upper(Catalog.MUTATION_BY_KEY[jumpKey].label) .. ")"
				end
			else
				arrow = if group.mutation == "TrainGod" then "TRAIN GOD can't be fused" else "Already the top mutation!"
			end
			label(row, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -170, 0, 22), Text = arrow, TextColor3 = if nextKey then Catalog.MUTATION_BY_KEY[nextKey].color else mutation.color })
			local sources = label(row, {
				Position = UDim2.fromOffset(12, 63),
				Size = UDim2.new(1, -170, 0, 20),
				Text = "🏠 base " .. (group.base or 0) .. "   🎒 hands " .. (group.hands or 0) .. "   📦 stash " .. (group.stash or 0),
				TextColor3 = Color3.fromRGB(200, 205, 235),
			})
			create("UITextSizeConstraint", { MaxTextSize = 16 }, sources)
			local ready = nextKey ~= nil and group.count >= 3
			local text = if ready then "🧬 FUSE!" elseif nextKey then "NEED " .. (3 - group.count) .. " MORE" else "MAX"
			local fuse = button(row, text, if ready then Color3.fromRGB(170, 80, 240) else Color3.fromRGB(100, 100, 120), {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(146, 54),
			})
			if ready then
				fuse.MouseButton1Click:Connect(function()
					Request:FireServer("Fuse", group.id, group.mutation)
				end)
			end
			table.insert(fuseRows, row)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- STASH: your personal bagspace. Lists what you carry (STORE / DROP) and what's stashed (TAKE), with the
-- empty slots shown so the capacity is obvious. Rebuilt whenever the mirrored JSON changes.
---------------------------------------------------------------------------------------------------------------
local STASH_ACCENT = Color3.fromRGB(255, 190, 100)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, stashBody)
label(stashBody, {
	Size = UDim2.new(1, -10, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Text = "Keep brainrots safe off your head: disasters, thieves and bandits can't touch your Stash, and the Barn Fuse Machine can use it. More space in the ⚡ Upgrade Shop. Press G to drop what you carry.",
	TextScaled = false,
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 230, 190),
	LayoutOrder = 0,
})
local handsHeader = label(stashBody, { Size = UDim2.new(1, -10, 0, 26), Text = "🎒 IN YOUR HANDS", TextColor3 = WHITE, LayoutOrder = 1 })
local handsList = create("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, stashBody)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, handsList)
local stashHeader = label(stashBody, { Size = UDim2.new(1, -10, 0, 26), Text = "📦 STASH", TextColor3 = STASH_ACCENT, LayoutOrder = 3 })
local stashList = create("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4 }, stashBody)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, stashList)

local function decodeEntries(json: string)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	return if ok and type(data) == "table" then data else {}
end

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function itemRow(parent: Instance, order: number, entry, actions)
	local def = Catalog.BY_ID[entry.id]
	if not def then
		return
	end
	local rarity = Catalog.rarityOf(entry.id)
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = PANEL_LIGHT, LayoutOrder = order }, parent)
	round(row, 10)
	outline(row, rarity.color, 2)
	local buttonsWidth = #actions * 98
	local name = label(row, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -buttonsWidth - 20, 0, 26), Text = Catalog.displayName(entry.id, entry.m), TextColor3 = rarity.color })
	create("UITextSizeConstraint", { MaxTextSize = 22 }, name)
	local info = label(row, {
		Position = UDim2.fromOffset(10, 33),
		Size = UDim2.new(1, -buttonsWidth - 20, 0, 19),
		Text = rarity.key .. "  ·  " .. Format.perSecond(Catalog.incomeFor(entry.id, entry.m)),
		TextColor3 = Color3.fromRGB(200, 220, 255),
	})
	create("UITextSizeConstraint", { MaxTextSize = 16 }, info)
	for i, action in actions do
		local b = button(row, action.text, action.color, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (#actions - i) * 98, 0.5, 0),
			Size = UDim2.fromOffset(90, 44),
		})
		b.MouseButton1Click:Connect(action.callback)
	end
end

local function emptyRow(parent: Instance, order: number, text: string)
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(32, 30, 52), BackgroundTransparency = 0.2, LayoutOrder = order }, parent)
	round(row, 10)
	local stroke = outline(row, Color3.fromRGB(90, 85, 120), 1)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	local l = label(row, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -12), Text = text, TextColor3 = Color3.fromRGB(150, 145, 180), TextXAlignment = Enum.TextXAlignment.Center })
	create("UITextSizeConstraint", { MaxTextSize = 17 }, l)
end

local lastStashKey = ""
local function refreshStash(force: boolean?)
	local carriedJson = attr_("CarriedJson", "[]")
	local stashJson = attr_("StashJson", "[]")
	local carryMax, stashMax = attr_("CarryMax", 1), attr_("StashMax", 2)
	local key = carriedJson .. "|" .. stashJson .. "|" .. carryMax .. "|" .. stashMax
	if key == lastStashKey and not force then
		return
	end
	lastStashKey = key
	local carried, stashed = decodeEntries(carriedJson), decodeEntries(stashJson)
	handsHeader.Text = "🎒 IN YOUR HANDS  " .. #carried .. "/" .. carryMax
	stashHeader.Text = "📦 STASH  " .. #stashed .. "/" .. stashMax
	stashButton.Text = "📦 STASH " .. #stashed .. "/" .. stashMax
	clearChildren(handsList)
	clearChildren(stashList)
	if #carried == 0 then
		emptyRow(handsList, 1, "Your hands are empty - grab brainrots in the field!")
	end
	for i, entry in carried do
		itemRow(handsList, i, entry, {
			{ text = "📦 STORE", color = Color3.fromRGB(230, 150, 50), callback = function()
				Request:FireServer("StashStore", i)
			end },
			{ text = "⬇ DROP", color = Color3.fromRGB(150, 110, 80), callback = function()
				Request:FireServer("Drop", i)
			end },
		})
	end
	for i = 1, math.max(stashMax, #stashed) do
		local entry = stashed[i]
		if entry then
			itemRow(stashList, i, entry, {
				{ text = "🤲 TAKE", color = Color3.fromRGB(60, 170, 90), callback = function()
					Request:FireServer("StashTake", i)
				end },
			})
		else
			emptyRow(stashList, i, "empty slot")
		end
	end
end

stashButton.MouseButton1Click:Connect(function()
	toggle(stashPanel)
	refreshStash(true)
end)
dropButton.MouseButton1Click:Connect(function()
	Request:FireServer("Drop")
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.G then
		Request:FireServer("Drop")
	end
end)

---------------------------------------------------------------------------------------------------------------
-- WELCOME: a cartoon wooden sign board that greets new players (and opens again from the "?" button):
-- a big title, a giant brainrot turning on a little grassy stage, three How to Play steps and PLAY!.
---------------------------------------------------------------------------------------------------------------
local WOOD_LIGHT = Color3.fromRGB(196, 136, 76)
local WOOD_DARK = Color3.fromRGB(92, 52, 24)
local backdrop = create("Frame", { Name = "WelcomeBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, Active = true, ZIndex = 50 }, gui)
local welcome = create("Frame", {
	Name = "Welcome",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.94),
	BackgroundColor3 = WOOD_LIGHT,
	Visible = false,
	Active = true,
	ZIndex = 51,
}, gui)
create("UISizeConstraint", { MaxSize = Vector2.new(600, 660) }, welcome)
create("UIAspectRatioConstraint", { AspectRatio = 600 / 660, DominantAxis = Enum.DominantAxis.Height }, welcome)
round(welcome, 26)
outline(welcome, WOOD_DARK, 7)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), Color3.fromRGB(200, 170, 140)), Rotation = 90 }, welcome)
-- Plank seams and four nails make it a farm sign.
for i = 1, 5 do
	create("Frame", { Position = UDim2.new(0, 14, i / 6, 0), Size = UDim2.new(1, -28, 0, 3), BackgroundColor3 = WOOD_DARK, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, welcome)
end
for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
	local nail = create("Frame", {
		AnchorPoint = corner,
		Position = UDim2.new(corner.X, if corner.X == 0 then 14 else -14, corner.Y, if corner.Y == 0 then 14 else -14),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(170, 170, 180),
	}, welcome)
	round(nail, 7)
	outline(nail, Color3.fromRGB(70, 70, 80), 2)
end

local banner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.025), Size = UDim2.fromScale(0.9, 0.115), BackgroundColor3 = Color3.fromRGB(205, 50, 40) }, welcome)
round(banner, 16)
outline(banner, WOOD_DARK, 4)
local welcomeTitle = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "WELCOME TO BRAINROT VILLAGE",
	TextColor3 = Color3.fromRGB(255, 228, 90),
	TextScaled = true,
}, banner)
create("UIStroke", { Color = WOOD_DARK, Thickness = 4 }, welcomeTitle)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, welcomeTitle)
create("UITextSizeConstraint", { MaxTextSize = 46 }, welcomeTitle)

-- The stage: sky, a grassy hill and the giant brainrot (plus two little ones for scale), turning slowly.
local stage = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.155), Size = UDim2.fromScale(0.88, 0.36), BackgroundColor3 = Color3.fromRGB(130, 200, 255), ClipsDescendants = true }, welcome)
round(stage, 18)
outline(stage, WOOD_DARK, 4)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 190, 255), Color3.fromRGB(215, 240, 255)), Rotation = 90 }, stage)
local hill = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(1.4, 0.8), BackgroundColor3 = Color3.fromRGB(110, 190, 80) }, stage)
round(hill, 400)
local viewport = create("ViewportFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(200, 200, 210),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.6, -1, 0.4),
}, stage)
local stageCamera = Instance.new("Camera")
stageCamera.FieldOfView = 38
stageCamera.Parent = viewport
viewport.CurrentCamera = stageCamera
local stageModels = {}
local function stageModel(id: string, mutation: string, scale: number, offset: Vector3)
	local model = Factory.build(id, mutation, { noLabel = true, scale = scale })
	for _, d in model:GetDescendants() do
		if table.find(EFFECT_CLASSES, d.ClassName) then
			d:Destroy()
		elseif d:IsA("BasePart") then
			CollectionService:RemoveTag(d, "RainbowPart")
		end
	end
	model:PivotTo(CFrame.new(offset))
	model.Parent = viewport
	table.insert(stageModels, { model = model, offset = offset })
	return model
end
local giant = stageModel("Chimera", "Gold", 1, Vector3.zero)
stageModel("Muccarello", "Gold", 0.55, Vector3.new(-13, 0, -4))
stageModel("Gallinetto", "Normal", 0.55, Vector3.new(13, 0, -4))
do
	local height = giant:GetAttribute("Height") or 12
	local center = Vector3.new(0, height * 0.48, 0)
	local distance = height * 2.3 + 8
	stageCamera.CFrame = CFrame.lookAt(center + Vector3.new(0, height * 0.18, -distance), center)
end

local howTo = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.6, 0.055),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "HOW TO PLAY",
	TextColor3 = Color3.fromRGB(255, 245, 210),
	TextScaled = true,
}, welcome)
create("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, howTo)

local STEPS = {
	{ icon = "🌾", color = Color3.fromRGB(80, 190, 90), text = "Grab & Stash mutated farm brainrots in the valley" },
	{ icon = "🧬", color = Color3.fromRGB(170, 90, 230), text = "Place them on your 9-slot base or Fuse 3 identical ones at the Red Barn" },
	{ icon = "🌪️", color = Color3.fromRGB(230, 90, 60), text = "Survive Tornadoes & Bull Stampedes, and BONK Bandits with farm weapons" },
}
for i, step in STEPS do
	local row = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.595 + (i - 1) * 0.088),
		Size = UDim2.fromScale(0.88, 0.078),
		BackgroundColor3 = Color3.fromRGB(255, 246, 225),
	}, welcome)
	round(row, 14)
	outline(row, WOOD_DARK, 3)
	local badge = create("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = step.color,
		Font = FONT,
		Text = tostring(i),
		TextColor3 = WHITE,
		TextScaled = true,
	}, row)
	create("UIAspectRatioConstraint", { AspectRatio = 1 }, badge)
	round(badge, 100)
	create("UIStroke", { Color = WOOD_DARK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	local text = create("TextLabel", {
		Position = UDim2.new(0.11, 0, 0.08, 0),
		Size = UDim2.new(0.87, 0, 0.84, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = step.icon .. "  " .. step.text,
		TextColor3 = Color3.fromRGB(70, 40, 20),
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	create("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, text)
end

local playButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.965),
	Size = UDim2.fromScale(0.6, 0.1),
	BackgroundColor3 = Color3.fromRGB(70, 200, 80),
	Font = FONT,
	Text = "PLAY!",
	TextColor3 = WHITE,
	TextScaled = true,
	AutoButtonColor = true,
}, welcome)
round(playButton, 20)
outline(playButton, Color3.fromRGB(30, 90, 30), 4)
create("UIStroke", { Color = Color3.fromRGB(20, 70, 20), Thickness = 3 }, playButton)
create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 210, 180)), Rotation = 90 }, playButton)
create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, playButton)

local helpButton = button(gui, "?", Color3.fromRGB(196, 136, 76), {
	Name = "HelpButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
	Size = UDim2.fromOffset(52, 52),
})
round(helpButton, 26)

local function showWelcome(visible: boolean)
	if visible then
		for _, other in allPanels do
			other.Visible = false
		end
	end
	welcome.Visible = visible
	backdrop.Visible = visible
end
playButton.MouseButton1Click:Connect(function()
	showWelcome(false)
	if attr_("ShowWelcome", false) == true then
		Request:FireServer("WelcomeSeen")
	end
end)
helpButton.MouseButton1Click:Connect(function()
	showWelcome(not welcome.Visible)
end)
local welcomedOnce = false
local function maybeWelcome()
	if not welcomedOnce and player:GetAttribute("ShowWelcome") == true then
		welcomedOnce = true
		showWelcome(true)
	end
end
player:GetAttributeChangedSignal("ShowWelcome"):Connect(maybeWelcome)
task.defer(maybeWelcome)
RunService.RenderStepped:Connect(function()
	if welcome.Visible then
		local t = os.clock()
		for i, item in stageModels do
			local spin = if i == 1 then t * 0.6 else -t * 1.2
			item.model:PivotTo(CFrame.new(item.offset + Vector3.new(0, if i == 1 then 0 else math.abs(math.sin(t * 4 + i)) * 0.8, 0)) * CFrame.Angles(0, spin, 0))
		end
	end
end)

-- The village market stalls are physical shops: their prompts open the matching panel.
local stallPanels = { Shop = shop, Weapons = weaponPanel, Rebirth = rebirthPanel, Dex = dexPanel }
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local target = stallPanels[prompt:GetAttribute("OpenPanel") or ""]
	if target and not target.Visible then
		toggle(target)
	end
end)

FuseMenu.OnClientEvent:Connect(function(groups, doubleChance)
	if type(groups) ~= "table" then
		return
	end
	rebuildFuse(groups, if type(doubleChance) == "number" then doubleChance else 0.1)
	if not fusePanel.Visible then
		toggle(fusePanel)
	end
end)
lockButton.MouseButton1Click:Connect(function()
	Request:FireServer("Lock")
end)

gui.Parent = player:WaitForChild("PlayerGui")

-- Notifications
local notifyOrder = 0
local function pushNotification(text: string, color: Color3)
	notifyOrder += 1
	local item = create("Frame", { Size = UDim2.fromOffset(620, 36), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, LayoutOrder = notifyOrder }, feed)
	round(item, 10)
	local stroke = outline(item, color, 2)
	local text_ = label(item, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
	local items = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #items - 4 do
		items[i]:Destroy()
	end
	task.delay(4.5, function()
		if item.Parent then
			local info = TweenInfo.new(0.5)
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(text_, info, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			task.wait(0.5)
			item:Destroy()
		end
	end)
end

Notify.OnClientEvent:Connect(function(text, color)
	if type(text) == "string" then
		pushNotification(text, if typeof(color) == "Color3" then color else WHITE)
	end
end)

CashPopup.OnClientEvent:Connect(function(amount)
	if type(amount) ~= "number" then
		return
	end
	local pop = label(popupAnchor, { Size = UDim2.fromScale(1, 1), Text = "+" .. Format.cash(amount), TextColor3 = MONEY })
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pop, info, { Position = UDim2.fromOffset(0, -70), TextTransparency = 1 }):Play()
	task.delay(1.25, function()
		pop:Destroy()
	end)
end)

-- Live refresh from the mirrored state.
local function attr(name: string, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function refreshShop(cash: number)
	for key, row in shopRows do
		local def = GameConfig.UPGRADES[key]
		local level = attr("Upgrade_" .. key, 0)
		local value = GameConfig.upgradeValue(key, level)
		row.info.Text = "Lv " .. level .. "/" .. def.max .. " · " .. value .. def.unit
		if level >= def.max then
			row.buy.Text = "MAX"
			row.buy.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
		else
			local cost = GameConfig.upgradeCost(key, level)
			row.buy.Text = Format.cash(cost)
			row.buy.BackgroundColor3 = if cash >= cost then Color3.fromRGB(60, 190, 90) else Color3.fromRGB(150, 70, 70)
		end
	end
end

local function refreshZone(now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		zoneLabel.Text = ""
		return
	end
	local p = root.Position
	local zone = GameConfig.zoneAt(p.Z)
	local onPlateau = p.Z < GameConfig.PLATEAU_EDGE_Z and p.X > GameConfig.VILLAGE.maxX and p.Y > GameConfig.PLATEAU_TOP - 2
	if not onPlateau and math.abs(p.X) > GameConfig.FIELD_HALF_WIDTH + 6 then
		zoneLabel.Text = "🏡 Brainrot Village · SAFE from disasters"
		zoneLabel.TextColor3 = Color3.fromRGB(255, 220, 140)
	elseif not zone and p.Z < GameConfig.PLATEAU_EDGE_Z then
		zoneLabel.Text = "🏠 Base plateau · SAFE from disasters"
		zoneLabel.TextColor3 = Color3.fromRGB(140, 230, 255)
	elseif p.Y > GameConfig.HILL_HEIGHT then
		zoneLabel.Text = "⛰ Safe hill · tornado and bulls can't reach you"
		zoneLabel.TextColor3 = Color3.fromRGB(150, 255, 160)
	elseif zone then
		zoneLabel.Text = "📍 " .. zone.name .. " · Luck x" .. (1 + zone.luck)
		zoneLabel.TextColor3 = zone.color
	else
		zoneLabel.Text = "📍 Base ramp"
		zoneLabel.TextColor3 = WHITE
	end
end

local function refreshDisaster(now: number)
	local cfg = GameConfig.DISASTER
	local phase = workspace:GetAttribute("DisasterPhase")
	local at = workspace:GetAttribute("DisasterAt") or now
	local wave = workspace:GetAttribute("DisasterWave") or 0
	local kind = workspace:GetAttribute("DisasterKind") or "Tornado"
	local info = cfg[kind] or cfg.Tornado
	local boss = wave > 0 and wave % GameConfig.BOSS.everyWaves == 0
	if phase == "warning" then
		local left = at - now
		tsunamiLabel.Text = "⚠️ " .. info.icon .. " " .. info.label .. " IN " .. Format.seconds(left) .. " - GET TO YOUR BASE, A HILL OR THE VILLAGE!"
		tsunamiLabel.TextColor3 = WHITE
		tsunamiFill.BackgroundColor3 = DANGER
		tsunamiFill.Size = UDim2.fromScale(math.clamp(1 - left / cfg.warning, 0, 1), 1)
		tsunamiStroke.Color = DANGER
		danger.Visible = true
		dangerStroke.Transparency = 0.5 + 0.5 * math.sin(now * 10)
	elseif phase == "active" then
		local start = workspace:GetAttribute("DisasterStart") or now
		local total = math.max(1, at - start)
		tsunamiLabel.Text = info.icon .. " " .. info.label .. " (WAVE #" .. wave .. ") IS HERE! STAY SHELTERED!" .. (if boss then " 👑 BOSS NEXT" else "")
		tsunamiLabel.TextColor3 = WHITE
		tsunamiFill.BackgroundColor3 = info.color
		tsunamiFill.Size = UDim2.fromScale(math.clamp((now - start) / total, 0, 1), 1)
		tsunamiStroke.Color = DANGER
		danger.Visible = true
		dangerStroke.Transparency = 0.4 + 0.4 * math.sin(now * 6)
	else
		local left = at - now
		local calm = cfg.interval - cfg.warning
		local nextKind = workspace:GetAttribute("DisasterNext") or "Tornado"
		local nextInfo = cfg[nextKind] or cfg.Tornado
		local bossNext = (wave + 1) % GameConfig.BOSS.everyWaves == 0
		tsunamiLabel.Text = nextInfo.icon .. " Next: " .. nextInfo.label .. " in " .. Format.seconds(left) .. " · Wave #" .. (wave + 1) .. (if bossNext then " · 👑 BOSS after it!" else "")
		tsunamiLabel.TextColor3 = Color3.fromRGB(230, 225, 255)
		tsunamiFill.BackgroundColor3 = nextInfo.color
		tsunamiFill.Size = UDim2.fromScale(math.clamp(1 - left / calm, 0, 1), 1)
		tsunamiStroke.Color = nextInfo.color
		danger.Visible = false
	end
end

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0
	local now = workspace:GetServerTimeNow()
	local cash = attr("Cash", 0)
	local rebirths = attr("Rebirths", 0)
	cashLabel.Text = "💰 " .. Format.cash(cash)
	local trainGod = attr("AllIncomeMult", 1)
	incomeLabel.Text = "+" .. Format.perSecond(attr("Income", 0)) .. "  ·  x" .. GameConfig.rebirthMultiplier(rebirths)
		.. (if trainGod > 1 then "  ·  🚂x" .. trainGod else "")
	vaultLabel.Text = "🏦 Vault " .. Format.cash(attr("Vault", 0)) .. " · step on COLLECT"
	carryLabel.Text = "🎒 Carry " .. attr("CarryCount", 0) .. "/" .. attr("CarryMax", 1)
	slotLabel.Text = "🏠 Slots " .. attr("SlotsUsed", 0) .. "/" .. attr("SlotsMax", GameConfig.BASE_SLOTS) .. " · ♻️ Rebirth " .. rebirths

	local lockUntil, lockReadyAt = attr("LockUntil", 0), attr("LockReadyAt", 0)
	if now < lockUntil then
		lockButton.Text = "🔒 LOCKED " .. Format.seconds(lockUntil - now)
		lockButton.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
	elseif now < lockReadyAt then
		lockButton.Text = "⏳ LOCK " .. Format.seconds(lockReadyAt - now)
		lockButton.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
	else
		lockButton.Text = "🔓 LOCK BASE"
		lockButton.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	end

	if shop.Visible then
		refreshShop(cash)
	end
	if weaponPanel.Visible then
		refreshWeapons(cash)
	end
	refreshDex()
	if stashPanel.Visible then
		refreshStash()
	end
	stashButton.Text = "📦 STASH " .. attr("StashCount", 0) .. "/" .. attr("StashMax", 2)
	dropButton.BackgroundColor3 = if attr("CarryCount", 0) > 0 then Color3.fromRGB(190, 120, 60) else Color3.fromRGB(100, 95, 110)
	if rebirthPanel.Visible then
		local cost = attr("RebirthCost", GameConfig.rebirthCost(rebirths))
		rebirthInfo.Text = "Cost: " .. Format.cash(cost) .. "\nReward: x" .. GameConfig.rebirthMultiplier(rebirths + 1)
			.. " income forever\nResets cash, upgrades, your Stash and the brainrots on your 3x3 base."
		rebirthConfirm.BackgroundColor3 = if cash >= cost then Color3.fromRGB(200, 70, 230) else Color3.fromRGB(110, 80, 120)
	end
	refreshDisaster(now)
	refreshZone(now)
end)
