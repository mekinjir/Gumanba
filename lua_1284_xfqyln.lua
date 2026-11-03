local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local HttpService        = game:GetService("HttpService")
local VirtualUser        = game:GetService("VirtualUser")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

--==================== CLEANUP ENGINE ====================
if env.MekiHub_Cleanup then
	pcall(env.MekiHub_Cleanup)
end

local isCleaningUp = false
local cleanupConns = {}
local function addCleanup(conn)
	table.insert(cleanupConns, conn)
	return conn
end

--==================== TEMA ====================
local T = {
	Bg         = Color3.fromRGB(18, 18, 24),
	Topbar     = Color3.fromRGB(24, 24, 32),
	Sidebar    = Color3.fromRGB(21, 21, 28),
	Panel      = Color3.fromRGB(30, 30, 40),
	PanelHover = Color3.fromRGB(38, 38, 52),
	PanelLite  = Color3.fromRGB(40, 40, 56),
	Track      = Color3.fromRGB(14, 14, 20),
	Stroke     = Color3.fromRGB(55, 55, 75),
	Accent     = Color3.fromRGB(0, 210, 255),
	AccentDark = Color3.fromRGB(0, 147, 178),
	Text       = Color3.fromRGB(255, 255, 255),
	SubText    = Color3.fromRGB(155, 165, 188),
	Danger     = Color3.fromRGB(255, 75, 75),
	Success    = Color3.fromRGB(70, 220, 140),
}
local FONT  = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold

local THEMES = {
	{"Cyan",   Color3.fromRGB(0, 210, 255)},
	{"Ungu",   Color3.fromRGB(160, 110, 255)},
	{"Hijau",  Color3.fromRGB(70, 220, 140)},
	{"Pink",   Color3.fromRGB(255, 100, 180)},
	{"Orange", Color3.fromRGB(255, 150, 60)},
}
local THEME_FILE = "meki_hub_theme.txt"

local function darken(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function hasFileAPI()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

-- Load tema tersimpan
local currentThemeName = "Cyan"
pcall(function()
	if hasFileAPI() and isfile(THEME_FILE) then
		local name = readfile(THEME_FILE):gsub("%s+", "")
		for _, th in ipairs(THEMES) do
			if th[1] == name then
				currentThemeName = name
				T.Accent = th[2]
				T.AccentDark = darken(th[2], 0.7)
			end
		end
	end
end)

local WIN_W, WIN_H, SIDEBAR_W = 540, 380, 132
local AUTO_INTERVAL = 1.0

--==================== HELPERS ====================
local accentReg = {}   -- objek yang warnanya ngikutin tema
local gradReg = {}     -- gradient yang ngikutin tema
local themeCallbacks = {}
local pruneReg

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
		if typeof(v) == "Color3" then
			if v == T.Accent then
				table.insert(accentReg, {o, k, "Accent"})
			elseif v == T.AccentDark then
				table.insert(accentReg, {o, k, "AccentDark"})
			end
		end
	end
	if parent then o.Parent = parent end
	return o
end

local function seqFor(kind)
	local h, s, v = T.Accent:ToHSV()
	local b = Color3.fromHSV((h + 0.09) % 1, s, v)
	if kind == "loop" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, T.Accent),
			ColorSequenceKeypoint.new(0.5, b),
			ColorSequenceKeypoint.new(1, T.Accent),
		})
	elseif kind == "topbar" then
		return ColorSequence.new(T.Topbar:Lerp(T.Accent, 0.12), T.Topbar)
	elseif kind == "card" then
		return ColorSequence.new(T.Panel:Lerp(T.Accent, 0.2), T.Panel)
	end
	return ColorSequence.new(T.Accent, b)
end

local function gradient(parent, kind, rotation)
	local g = new("UIGradient", {Color = seqFor(kind), Rotation = rotation or 0}, parent)
	table.insert(gradReg, {g, kind})
	return g
end

local function round(o, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local function outline(o, color, thick, trans)
	return new("UIStroke", {
		Color = color or T.Stroke,
		Thickness = thick or 1,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function safe(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if not ok then warn("[MekiHub] " .. tostring(a)) return nil end
	return a, b
end

local function parentGui()
	local ok, hui = pcall(function() return gethui() end)
	if ok and hui then return hui end
	return player:WaitForChild("PlayerGui")
end

local function getHRP()
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function resetHumanoidState()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

local function setupDrag(targetFrame, dragArea)
	local dragging, dragInput, dragStart, startPos
	local isMoving = false

	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			isMoving = false
			dragStart = input.Position
			startPos = targetFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					task.delay(0.1, function() isMoving = false end)
				end
			end)
		end
	end)
	dragArea.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	addCleanup(UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			if delta.Magnitude > 5 then isMoving = true end
			targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
	return function() return isMoving end
end

-- Hapus GUI lama
pcall(function()
	local old = parentGui():FindFirstChild("MekiHub_UI")
	if old then old:Destroy() end
end)

--==================== ROOT GUI ====================
local gui = new("ScreenGui", {
	Name = "MekiHub_UI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999,
})
gui.Parent = parentGui()

task.spawn(function()
	while not isCleaningUp do
		task.wait(1)
		if not isCleaningUp and not gui.Parent then
			pcall(function() gui.Parent = parentGui() end)
		end
	end
end)

pruneReg = function()
	local keep = {}
	for _, e in ipairs(accentReg) do
		if e[1]:IsDescendantOf(gui) then table.insert(keep, e) end
	end
	accentReg = keep
	local keepG = {}
	for _, e in ipairs(gradReg) do
		if e[1]:IsDescendantOf(gui) then table.insert(keepG, e) end
	end
	gradReg = keepG
end

local function applyTheme(name, color)
	currentThemeName = name
	T.Accent = color
	T.AccentDark = darken(color, 0.7)
	pruneReg()
	for _, e in ipairs(accentReg) do
		pcall(function() e[1][e[2]] = T[e[3]] end)
	end
	for _, e in ipairs(gradReg) do
		pcall(function() e[1].Color = seqFor(e[2]) end)
	end
	for _, cb in ipairs(themeCallbacks) do pcall(cb) end
	if hasFileAPI() then pcall(function() writefile(THEME_FILE, name) end) end
end

--=====================================================================
-- UI LIBRARY
--=====================================================================
-- Icon digambar pakai Frame (tidak butuh emoji atau asset)
local function makeIcon(kind, parent)
	if not kind then return nil end
	local holder = new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 10, 0.5, -9),
		BackgroundTransparency = 1,
	}, parent)
	local fills, strokes = {}, {}
	local function box(x, y, w, h, r, rot)
		local f = new("Frame", {
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = T.SubText, BorderSizePixel = 0, Rotation = rot or 0,
		}, holder)
		if r then round(f, r) end
		table.insert(fills, f)
		return f
	end
	if kind == "home" then
		box(5, 1, 8, 8, 0, 45)
		box(3, 9, 12, 8, 2)
	elseif kind == "pin" then
		box(4, 1, 10, 10, 5)
		box(6, 8, 6, 6, 0, 45)
	elseif kind == "user" then
		box(5, 1, 8, 8, 4)
		box(2, 11, 14, 7, 5)
	elseif kind == "users" then
		box(2, 2, 6, 6, 3)
		box(0, 10, 10, 7, 4)
		box(11, 4, 5, 5, 3)
		box(9, 11, 9, 6, 3)
	elseif kind == "eye" then
		local ring = new("Frame", {
			Position = UDim2.fromOffset(3, 5), Size = UDim2.fromOffset(12, 8),
			BackgroundTransparency = 1, BorderSizePixel = 0,
		}, holder)
		round(ring, 4)
		local st = new("UIStroke", {
			Color = T.SubText, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)
		table.insert(strokes, st)
		box(6, 6, 6, 6, 3)
	elseif kind == "misc" then
		box(1, 7, 4, 4, 2)
		box(7, 7, 4, 4, 2)
		box(13, 7, 4, 4, 2)
	elseif kind == "flag" then
		box(4, 1, 2, 16)
		box(6, 2, 9, 7, 1)
	elseif kind == "gear" then
		local ring = new("Frame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1, BorderSizePixel = 0,
		}, holder)
		round(ring, 5)
		local st = new("UIStroke", {
			Color = T.SubText, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)
		table.insert(strokes, st)
		box(8, 0, 2, 3)
		box(8, 15, 2, 3)
		box(0, 8, 3, 2)
		box(15, 8, 3, 2)
	end
	local obj = {}
	function obj.setColor(c)
		for _, f in ipairs(fills) do f.BackgroundColor3 = c end
		for _, s in ipairs(strokes) do s.Color = c end
	end
	return obj
end

local Lib = {}

function Lib:CreateWindow(cfg)
	local Window = {}
	local toggles = {}
	local tabs = {}
	Window.SpinBorder = true
	local flags = {}
	Window.Flags = flags

	local root = new("Frame", {
		Name = "Root",
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local uiScale = new("UIScale", {}, root)
	local baseScale, animating = 1, false
	local function updScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		baseScale = math.clamp(math.min((vp.X - 24) / WIN_W, (vp.Y - 24) / WIN_H), 0.5, 1)
		if not animating then uiScale.Scale = baseScale end
	end
	updScale()
	pcall(function()
		addCleanup(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updScale))
	end)
	Window.Root = root

	function Window:IsVisible() return root.Visible end
	function Window:SetVisible(v)
		if animating or v == root.Visible then return end
		animating = true
		if v then
			uiScale.Scale = baseScale * 0.9
			root.Visible = true
			tween(uiScale, 0.22, {Scale = baseScale})
			task.delay(0.25, function()
				animating = false
				uiScale.Scale = baseScale
			end)
		else
			tween(uiScale, 0.15, {Scale = baseScale * 0.9})
			task.delay(0.17, function()
				root.Visible = false
				animating = false
				uiScale.Scale = baseScale
			end)
		end
	end
	function Window:Toggle() Window:SetVisible(not root.Visible) end

	new("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 50, 1, 50),
	}, root)

	local main = new("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, root)
	round(main, 14)

	-- Border gradient yang berputar pelan
	local borderStroke = outline(main, Color3.new(1, 1, 1), 1.5, 0.2)
	local borderGrad = gradient(borderStroke, "loop", 0)
	addCleanup(RunService.Heartbeat:Connect(function(dt)
		if Window.SpinBorder and root.Visible then
			borderGrad.Rotation = (borderGrad.Rotation + dt * 40) % 360
		end
	end))

	-- TOPBAR
	local topbar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, main)
	gradient(topbar, "topbar", 0)
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = T.Stroke,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, topbar)
	local titleX = 16
	new("TextLabel", {
		Text = cfg.Title or "MEKI HUB",
		Font = FONTB, TextSize = 16, TextColor3 = T.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(titleX, 0), Size = UDim2.fromOffset(96, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, topbar)

	-- Badge (pill)
	local badge = new("Frame", {
		Size = UDim2.fromOffset(94, 18),
		Position = UDim2.new(0, titleX + 100, 0.5, -9),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, topbar)
	round(badge, 9)
	gradient(badge, "seq", 0)
	new("TextLabel", {
		Text = cfg.Badge or "V3",
		Font = FONTB, TextSize = 9, TextColor3 = T.Bg,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	}, badge)

	-- FPS / Ping live
	local statsLabel = new("TextLabel", {
		Text = "-- FPS  |  -- ms",
		Font = FONTB, TextSize = 11, TextColor3 = T.SubText,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(130, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, topbar)
	Window.StatsLabel = statsLabel

	local function topBtn(text, size, xOff, hoverColor)
		local b = new("TextButton", {
			Text = text, Font = FONTB, TextSize = size, TextColor3 = T.SubText,
			BackgroundColor3 = T.PanelLite, BackgroundTransparency = 1,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, xOff, 0.5, -14),
		}, topbar)
		round(b, 8)
		b.MouseEnter:Connect(function()
			tween(b, 0.15, {BackgroundTransparency = 0, BackgroundColor3 = hoverColor, TextColor3 = T.Text})
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.15, {BackgroundTransparency = 1, TextColor3 = T.SubText})
		end)
		return b
	end
	local closeBtn = topBtn("X", 12, -40, T.Danger)
	local minBtn   = topBtn("-", 20, -74, T.PanelLite)

	minBtn.MouseButton1Click:Connect(function() Window:SetVisible(false) end)
	closeBtn.MouseButton1Click:Connect(function()
		if env.MekiHub_Cleanup then pcall(env.MekiHub_Cleanup) end
	end)


	-- SIDEBAR
	local sidebar = new("Frame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(0, SIDEBAR_W, 1, -46),
		BackgroundColor3 = T.Sidebar,
		BorderSizePixel = 0,
	}, main)
	new("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = T.Stroke,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, sidebar)

	local tabHolder = new("Frame", {
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
	}, sidebar)
	new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tabHolder)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10),
	}, tabHolder)

	local profile = new("Frame", {
		Position = UDim2.new(0, 0, 1, -52),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
	}, sidebar)
	new("Frame", {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = T.Stroke,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, profile)
	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(10, 11),
		BackgroundColor3 = T.PanelLite,
		BorderSizePixel = 0,
	}, profile)
	round(avatar, 15)
	local avStroke = outline(avatar, Color3.new(1, 1, 1), 1.5, 0)
	gradient(avStroke, "seq", 45)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then avatar.Image = img end
	end)
	new("TextLabel", {
		Text = player.DisplayName,
		Font = FONTB, TextSize = 12, TextColor3 = T.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -54, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, profile)

	local pages = new("Frame", {
		Position = UDim2.fromOffset(SIDEBAR_W, 46),
		Size = UDim2.new(1, -SIDEBAR_W, 1, -46),
		BackgroundTransparency = 1,
	}, main)

	-- NOTIFIKASI
	local notifHolder = new("Frame", {
		Size = UDim2.fromOffset(260, 400),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		BackgroundTransparency = 1,
		ZIndex = 200,
	}, gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, notifHolder)

	local notifCount = 0
	function Window:Notify(title, text, dur, kind)
		if isCleaningUp then return end
		notifCount = notifCount + 1
		local color = (kind == "error" and T.Danger) or (kind == "success" and T.Success) or T.Accent
		local holder = new("Frame", {
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundTransparency = 1,
			LayoutOrder = notifCount,
		}, notifHolder)
		local toast = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(290, 0),
			BackgroundColor3 = T.Panel,
			BorderSizePixel = 0,
		}, holder)
		round(toast, 10)
		outline(toast, color, 1, 0.55)
		local bar = new("Frame", {
			Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = color, BorderSizePixel = 0,
		}, toast)
		round(bar, 2)
		new("TextLabel", {
			Text = title, Font = FONTB, TextSize = 13, TextColor3 = T.Text,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(20, 9), Size = UDim2.new(1, -28, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, toast)
		new("TextLabel", {
			Text = text or "", Font = FONT, TextSize = 11, TextColor3 = T.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(20, 27), Size = UDim2.new(1, -28, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, toast)
		tween(toast, 0.3, {Position = UDim2.fromOffset(0, 0)})
		task.delay(dur or 2, function()
			if toast.Parent then
				tween(toast, 0.3, {Position = UDim2.fromOffset(290, 0)})
				task.wait(0.35)
			end
			pcall(function() holder:Destroy() end)
		end)
	end

	-- PROMPT
	function Window:Prompt(titleText, default, cb, placeholder)
		local overlay = new("TextButton", {
			Text = "", AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 60,
		}, gui)
		tween(overlay, 0.2, {BackgroundTransparency = 0.45})

		local dlg = new("Frame", {
			Size = UDim2.fromOffset(280, 150),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Panel,
			BorderSizePixel = 0,
		}, overlay)
		round(dlg, 14)
		outline(dlg, T.Accent, 1, 0.5)

		new("TextLabel", {
			Text = titleText, Font = FONTB, TextSize = 14, TextColor3 = T.Text,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, dlg)

		local box = new("TextBox", {
			Text = default or "", Font = FONT, TextSize = 13, TextColor3 = T.Text,
			PlaceholderText = placeholder or "Nama waypoint...", PlaceholderColor3 = T.SubText,
			BackgroundColor3 = T.Track, BorderSizePixel = 0, ClearTextOnFocus = false,
			Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, dlg)
		round(box, 8)
		outline(box, T.Stroke, 1, 0.3)
		new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, box)

		local function dlgBtn(text, w, xOff, bg, fg)
			local b = new("TextButton", {
				Text = text, Font = FONTB, TextSize = 12, TextColor3 = fg,
				BackgroundColor3 = bg, AutoButtonColor = false,
				Size = UDim2.fromOffset(w, 32), Position = UDim2.new(1, xOff, 1, -46),
			}, dlg)
			round(b, 8)
			return b
		end
		local okBtn = dlgBtn("Simpan", 96, -112, T.Accent, T.Bg)
		local cancelBtn = dlgBtn("Batal", 80, -200, T.PanelLite, T.SubText)

		local function close()
			tween(overlay, 0.15, {BackgroundTransparency = 1})
			task.delay(0.15, function() pcall(function() overlay:Destroy() end) end)
		end
		cancelBtn.MouseButton1Click:Connect(close)
		okBtn.MouseButton1Click:Connect(function()
			if box.Text:match("%S") then safe(cb, box.Text) end
			close()
		end)
		task.defer(function() if box:IsDescendantOf(game) then box:CaptureFocus() end end)
	end

	function Window:ResetToggles()
		for _, t in ipairs(toggles) do t:Set(false, true) end
	end

	local function selectTab(target)
		for _, t in ipairs(tabs) do t._setActive(t == target) end
	end

	-- TAB
	function Window:CreateTab(name, icon)
		local Tab = {}
		local order = 0
		local function nextOrder()
			order = order + 1
			return order
		end

		local btn = new("TextButton", {
			Text = "", AutoButtonColor = false,
			BackgroundColor3 = T.PanelLite, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0,
			LayoutOrder = #tabs + 1,
		}, tabHolder)
		round(btn, 8)
		local iconObj = makeIcon(icon, btn)
		local lbl = new("TextLabel", {
			Text = name, Font = FONTB, TextSize = 13, TextColor3 = T.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, btn)
		local bar = new("Frame", {
			Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 0, 0.5, -8),
			BackgroundColor3 = T.Accent, BorderSizePixel = 0, Visible = false,
		}, btn)
		round(bar, 2)

		local page = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
		}, pages)
		new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14),
		}, page)

		Tab.Page = page

		Tab._setActive = function(on)
			page.Visible = on
			bar.Visible = on
			tween(btn, 0.15, {BackgroundTransparency = on and 0 or 1})
			tween(lbl, 0.15, {TextColor3 = on and T.Text or T.SubText})
			if iconObj then iconObj.setColor(on and T.Accent or T.SubText) end
		end
		table.insert(themeCallbacks, function()
			if page.Visible and iconObj then iconObj.setColor(T.Accent) end
		end)
		btn.MouseEnter:Connect(function()
			if not page.Visible then tween(btn, 0.15, {BackgroundTransparency = 0.6}) end
		end)
		btn.MouseLeave:Connect(function()
			if not page.Visible then tween(btn, 0.15, {BackgroundTransparency = 1}) end
		end)
		btn.MouseButton1Click:Connect(function() selectTab(Tab) end)

		table.insert(tabs, Tab)
		if #tabs == 1 then selectTab(Tab) end

		function Tab:NextOrder() return nextOrder() end

		function Tab:CreateSection(text)
			local l = new("TextLabel", {
				Text = string.upper(text), Font = FONTB, TextSize = 11, TextColor3 = T.Accent,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = nextOrder(),
			}, page)
			new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6)}, l)
			return l
		end

		function Tab:CreateLabel(text)
			local l = new("TextLabel", {
				Text = text, Font = FONT, TextSize = 11, TextColor3 = T.SubText,
				TextWrapped = true,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = nextOrder(),
			}, page)
			new("UIPadding", {PaddingLeft = UDim.new(0, 4)}, l)
			return l
		end

		function Tab:CreateButton(o)
			local baseC, hoverC, pressC
			if o.Accent then
				baseC, hoverC, pressC = Color3.new(1, 1, 1), Color3.new(0.88, 0.88, 0.88), Color3.new(0.7, 0.7, 0.7)
			elseif o.Danger then
				baseC, hoverC, pressC = T.Danger, darken(T.Danger, 0.85), darken(T.Danger, 0.7)
			else
				baseC, hoverC, pressC = T.Panel, T.PanelHover, T.PanelLite
			end
			local holder = new("Frame", {
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = baseC, BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
			}, page)
			round(holder, 8)
			if o.Accent then
				gradient(holder, "seq", 0)
			elseif not o.Danger then
				outline(holder, T.Stroke, 1, 0.5)
			end
			local b = new("TextButton", {
				Text = o.Name, Font = FONTB, TextSize = 13,
				TextColor3 = o.Accent and T.Bg or T.Text,
				BackgroundTransparency = 1, AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
			}, holder)
			b.MouseEnter:Connect(function() tween(holder, 0.15, {BackgroundColor3 = hoverC}) end)
			b.MouseLeave:Connect(function() tween(holder, 0.15, {BackgroundColor3 = baseC}) end)
			b.MouseButton1Down:Connect(function() tween(holder, 0.08, {BackgroundColor3 = pressC}) end)
			b.MouseButton1Up:Connect(function() tween(holder, 0.12, {BackgroundColor3 = hoverC}) end)
			b.MouseButton1Click:Connect(function()
				if o.Callback then safe(o.Callback) end
			end)
			return b
		end

		function Tab:CreateToggle(o)
			local state = false
			local f = new("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
			}, page)
			round(f, 8)
			outline(f, T.Stroke, 1, 0.5)
			new("TextLabel", {
				Text = o.Name, Font = FONT, TextSize = 13, TextColor3 = T.Text,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, f)
			local track = new("Frame", {
				Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -50, 0.5, -10),
				BackgroundColor3 = T.Track, BorderSizePixel = 0,
			}, f)
			round(track, 10)
			local knob = new("Frame", {
				Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 3, 0.5, -7),
				BackgroundColor3 = T.SubText, BorderSizePixel = 0,
			}, track)
			round(knob, 7)
			local click = new("TextButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			}, f)

			local function visual(s)
				if s then
					tween(track, 0.2, {BackgroundColor3 = T.Accent})
					tween(knob, 0.2, {Position = UDim2.new(1, -17, 0.5, -7), BackgroundColor3 = T.Bg})
				else
					tween(track, 0.2, {BackgroundColor3 = T.Track})
					tween(knob, 0.2, {Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = T.SubText})
				end
			end
			table.insert(themeCallbacks, function()
				if state then track.BackgroundColor3 = T.Accent end
			end)

			local obj = {}
			function obj:Get() return state end
			function obj:Set(s, silent, quiet)
				state = s
				visual(s)
				if silent then return end
				local failed, msg = false, nil
				if o.Callback then
					local ok, res, m = pcall(o.Callback, s)
					if not ok then
						warn("[MekiHub] " .. tostring(res))
						failed, msg = true, "Terjadi error (cek console)"
					elseif res == false then
						failed, msg = true, m
					end
				end
				if failed then
					state = false
					visual(false)
					if not quiet then Window:Notify(o.Name, msg or "Gagal diaktifkan", 2, "error") end
				elseif not o.Silent and not quiet then
					Window:Notify(o.Name, s and "Aktif" or "Nonaktif", 1.5, s and "success" or nil)
				end
			end

			f.MouseEnter:Connect(function() tween(f, 0.15, {BackgroundColor3 = T.PanelHover}) end)
			f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundColor3 = T.Panel}) end)
			click.MouseButton1Click:Connect(function() obj:Set(not state) end)

			if o.ResetOnRespawn then table.insert(toggles, obj) end
			if o.Flag then
				flags[o.Flag] = {
					kind = "toggle",
					get = function() return state end,
					set = function(v)
						v = v and true or false
						if state ~= v then obj:Set(v, false, true) end
					end,
				}
			end
			if o.Default then
				state = true
				visual(true)
				if o.Callback then safe(o.Callback, true) end
			end
			return obj
		end

		function Tab:CreateSlider(o)
			local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
			local value = math.clamp(o.Default or min, min, max)
			local f = new("Frame", {
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
			}, page)
			round(f, 8)
			outline(f, T.Stroke, 1, 0.5)
			new("TextLabel", {
				Text = o.Name, Font = FONT, TextSize = 13, TextColor3 = T.Text,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -90, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, f)
			local valLbl = new("TextLabel", {
				Font = FONTB, TextSize = 12, TextColor3 = T.Accent,
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -82, 0, 8), Size = UDim2.fromOffset(70, 18),
				TextXAlignment = Enum.TextXAlignment.Right,
			}, f)
			local track = new("Frame", {
				Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 38),
				BackgroundColor3 = T.Track, BorderSizePixel = 0,
			}, f)
			round(track, 3)
			local fill = new("Frame", {
				Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			}, track)
			round(fill, 3)
			gradient(fill, "seq", 0)
			local knob = new("Frame", {
				Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.Text, BorderSizePixel = 0,
			}, track)
			round(knob, 7)
			local hit = new("TextButton", {
				Text = "", BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 28),
			}, f)

			local function render()
				local pct = (value - min) / (max - min)
				fill.Size = UDim2.fromScale(pct, 1)
				knob.Position = UDim2.fromScale(pct, 0.5)
				valLbl.Text = tostring(value) .. (o.Suffix or "")
			end
			render()

			local function setFromX(x)
				local pct = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				local v = min + (max - min) * pct
				v = math.floor((v - min) / step + 0.5) * step + min
				v = math.clamp(v, min, max)
				v = tonumber(string.format("%.3f", v))
				if v ~= value then
					value = v
					render()
					if o.Callback then safe(o.Callback, value) end
				end
			end

			local dragging = false
			hit.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					page.ScrollingEnabled = false
					setFromX(input.Position.X)
				end
			end)
			addCleanup(UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					setFromX(input.Position.X)
				end
			end))
			addCleanup(UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if dragging then
						dragging = false
						page.ScrollingEnabled = true
					end
				end
			end))

			if o.Callback then safe(o.Callback, value) end
			local obj = {}
			function obj:Get() return value end
			function obj:Set(v)
				value = math.clamp(tonumber(v) or value, min, max)
				render()
				if o.Callback then safe(o.Callback, value) end
			end
			if o.Flag then
				flags[o.Flag] = { kind = "slider", get = function() return value end, set = function(v) obj:Set(v) end }
			end
			return obj
		end

		function Tab:CreateDropdown(o)
			local selected = o.Default
			local open = false
			local card = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = nextOrder(),
			}, page)
			round(card, 8)
			outline(card, T.Stroke, 1, 0.5)
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, card)

			local header = new("TextButton", {
				Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0,
			}, card)
			local valueLbl = new("TextLabel", {
				Text = selected or o.Placeholder or "Pilih...", Font = FONTB, TextSize = 13,
				TextColor3 = selected and T.Text or T.SubText,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -50, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			}, header)
			local arrow = new("TextLabel", {
				Text = ">", Font = FONTB, TextSize = 16, TextColor3 = T.SubText,
				BackgroundTransparency = 1, Rotation = 90,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -22, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
			}, header)

			local list = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1, Visible = false, LayoutOrder = 1,
			}, card)
			new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			new("UIPadding", {
				PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			}, list)

			local items = {}
			local function refresh()
				valueLbl.Text = selected or o.Placeholder or "Pilih..."
				valueLbl.TextColor3 = selected and T.Text or T.SubText
				for name, it in pairs(items) do
					local on = (name == selected)
					it.dot.BackgroundColor3 = on and T.Accent or T.Track
					it.lbl.TextColor3 = on and T.Text or T.SubText
					it.btn.BackgroundColor3 = on and T.PanelLite or T.Panel
				end
			end
			table.insert(themeCallbacks, refresh)

			local function setOpen(v)
				open = v
				list.Visible = v
				tween(arrow, 0.15, { Rotation = v and -90 or 90 })
			end
			header.MouseButton1Click:Connect(function() setOpen(not open) end)

			local function choose(name)
				selected = name
				refresh()
				setOpen(false)
				if o.Callback then safe(o.Callback, name) end
			end

			for i, name in ipairs(o.Options) do
				local btn = new("TextButton", {
					Text = "", AutoButtonColor = false, BorderSizePixel = 0,
					BackgroundColor3 = T.Panel,
					Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i,
				}, list)
				round(btn, 6)
				local dot = new("Frame", {
					Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 10, 0.5, -5),
					BackgroundColor3 = T.Track, BorderSizePixel = 0,
				}, btn)
				round(dot, 5)
				local lbl = new("TextLabel", {
					Text = name, Font = FONTB, TextSize = 13, TextColor3 = T.SubText,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				}, btn)
				items[name] = { btn = btn, dot = dot, lbl = lbl }
				btn.MouseButton1Click:Connect(function() choose(name) end)
			end
			refresh()

			local obj = {}
			function obj:Get() return selected end
			function obj:Set(name)
				if items[name] then choose(name) end
			end
			if o.Flag then
				flags[o.Flag] = { kind = "select", get = function() return selected end, set = function(v) obj:Set(v) end }
			end
			return obj
		end

		function Tab:CreateInput(o)
			local f = new("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
			}, page)
			round(f, 8)
			outline(f, T.Stroke, 1, 0.5)
			local box = new("TextBox", {
				Text = "", PlaceholderText = o.Placeholder or "", PlaceholderColor3 = T.SubText,
				Font = FONT, TextSize = 13, TextColor3 = T.Text,
				BackgroundTransparency = 1, ClearTextOnFocus = false,
				Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, f)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if o.Callback then safe(o.Callback, box.Text) end
			end)
			return box
		end

		function Tab:CreateColorRow(o)
			local selected = o.Default
			local card = new("Frame", {
				Size = UDim2.new(1, 0, 0, 78),
				BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
			}, page)
			round(card, 8)
			outline(card, T.Stroke, 1, 0.5)
			new("TextLabel", {
				Text = o.Name, Font = FONT, TextSize = 13, TextColor3 = T.Text,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, card)
			local row = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 32),
			}, card)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}, row)
			local rings = {}
			local function refresh()
				for name, ring in pairs(rings) do
					ring.Transparency = (name == selected) and 0 or 1
				end
			end
			local function choose(name, color)
				selected = name
				refresh()
				if o.Callback then safe(o.Callback, name, color) end
			end
			for _, c in ipairs(o.Colors) do
				local b = new("TextButton", {
					Text = "", AutoButtonColor = false, BorderSizePixel = 0,
					Size = UDim2.fromOffset(28, 28),
				}, row)
				b.BackgroundColor3 = c[2]   -- diset setelah dibuat supaya warnanya nggak ikut berubah saat ganti tema
				round(b, 14)
				rings[c[1]] = new("UIStroke", {
					Color = Color3.new(1, 1, 1), Thickness = 2,
					Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}, b)
				b.MouseButton1Click:Connect(function() choose(c[1], c[2]) end)
			end
			refresh()
			local obj = {}
			function obj:Get() return selected end
			function obj:Set(name)
				for _, c in ipairs(o.Colors) do
					if c[1] == name then choose(c[1], c[2]) return end
				end
			end
			if o.Flag then
				flags[o.Flag] = { kind = "color", get = function() return selected end, set = function(v) obj:Set(v) end }
			end
			return obj
		end

		return Tab
	end

	-- DRAG DARI MANA SAJA (kecuali tombol / slider / kotak teks)
	local drag = {active = false}
	local function beginWindowDrag(input, scrollPage)
		if drag.active then return end
		local ut = input.UserInputType
		if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
		drag.active = true
		drag.input = input
		drag.start = input.Position
		drag.startPos = root.Position
		drag.scrollPage = scrollPage
		-- di area scroll (HP): geser vertikal = scroll, geser horizontal = pindah menu
		drag.decided = not (ut == Enum.UserInputType.Touch and scrollPage ~= nil)
	end

	addCleanup(UserInputService.InputChanged:Connect(function(input)
		if not drag.active then return end
		local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
		local isTouchMove = input.UserInputType == Enum.UserInputType.Touch and input == drag.input
		if not (isMouseMove or isTouchMove) then return end
		local delta = input.Position - drag.start
		if not drag.decided then
			if delta.Magnitude < 8 then return end
			if math.abs(delta.Y) > math.abs(delta.X) then
				drag.active = false
				return
			end
			drag.decided = true
			if drag.scrollPage then drag.scrollPage.ScrollingEnabled = false end
		end
		root.Position = UDim2.new(
			drag.startPos.X.Scale, drag.startPos.X.Offset + delta.X,
			drag.startPos.Y.Scale, drag.startPos.Y.Offset + delta.Y
		)
	end))

	addCleanup(UserInputService.InputEnded:Connect(function(input)
		if not drag.active then return end
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or (ut == Enum.UserInputType.Touch and input == drag.input) then
			drag.active = false
			if drag.scrollPage then drag.scrollPage.ScrollingEnabled = true end
		end
	end))

	local function hookDrag(d)
		if not d.Parent then return end
		if not d:IsA("GuiObject") then return end
		if d:IsA("GuiButton") or d:IsA("TextBox") then return end
		if d.Name == "Shadow" then return end
		if d:FindFirstAncestorWhichIsA("GuiButton") then return end
		local sf = d:IsA("ScrollingFrame") and d or d:FindFirstAncestorWhichIsA("ScrollingFrame")
		d.InputBegan:Connect(function(input) beginWindowDrag(input, sf) end)
	end
	for _, d in ipairs(root:GetDescendants()) do hookDrag(d) end
	root.DescendantAdded:Connect(function(d) task.defer(hookDrag, d) end)

	return Window
end

--==================== KEY SYSTEM ====================
local REQUIRED_KEY = "MEK-HUB-853"
local LINKVERTISE_URL = "https://direct-link.net/3821198/2Kbmdmttpa3S"
local KEY_FILE = "meki_hub_key.dat"
local function keySaved()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
    local ok, value = pcall(function() if isfile(KEY_FILE) then return readfile(KEY_FILE) end end)
    return ok and value == REQUIRED_KEY
end
local function saveKey()
    if type(writefile) == "function" then pcall(writefile, KEY_FILE, REQUIRED_KEY) end
end

--=====================================================================
-- LOADING SCREEN (3 detik)
--=====================================================================
local loadingScreen = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1,
	ZIndex = 100,
}, gui)

local loadBox = new("Frame", {
	Size = UDim2.fromOffset(300, 220),
	Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = T.Panel, BackgroundTransparency = 0.2,
}, loadingScreen)
round(loadBox, 16)
local loadStroke = outline(loadBox, Color3.new(1, 1, 1), 1.5, 0.3)
local loadStrokeGrad = gradient(loadStroke, "loop", 0)
local loadSpin = RunService.Heartbeat:Connect(function(dt)
	loadStrokeGrad.Rotation = (loadStrokeGrad.Rotation + dt * 120) % 360
end)
addCleanup(loadSpin)

local loadAvatar = new("ImageLabel", {
	Size = UDim2.fromOffset(70, 70),
	Position = UDim2.fromScale(0.5, 0.25), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = T.Bg,
}, loadBox)
round(loadAvatar, 35)
local loadAvStroke = outline(loadAvatar, Color3.new(1, 1, 1), 2, 0)
gradient(loadAvStroke, "seq", 45)

task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)
	if ok and loadAvatar.Parent then loadAvatar.Image = img end
end)

new("TextLabel", {
	Text = "MEKI HUB", Font = FONTB, TextSize = 20, TextColor3 = T.Text,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.4, 0),
}, loadBox)
new("TextLabel", {
	Text = "Welcome back, " .. player.DisplayName, Font = FONT, TextSize = 13, TextColor3 = T.SubText,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.55, 0),
}, loadBox)
local statusLbl = new("TextLabel", {
	Text = "Loading...", Font = FONT, TextSize = 11, TextColor3 = T.Accent,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.7, 0),
}, loadBox)

local barBg = new("Frame", {
	Size = UDim2.new(0.8, 0, 0, 6),
	Position = UDim2.new(0.5, 0, 0.85, 0), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = T.PanelLite,
}, loadBox)
round(barBg, 3)
local barFill = new("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
}, barBg)
round(barFill, 3)
gradient(barFill, "seq", 0)
TweenService:Create(barFill, TweenInfo.new(3, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)}):Play()

task.spawn(function()
	local steps = {"Memuat modul...", "Menyiapkan UI...", "Hampir selesai..."}
	for _, s in ipairs(steps) do
		task.wait(0.9)
		if isCleaningUp or not statusLbl.Parent then return end
		statusLbl.Text = s
	end
end)

--=====================================================================
-- BUAT WINDOW
--=====================================================================
local Window = Lib:CreateWindow({
	Title = "MEKI HUB",
	Badge = "V3 FREEMIUM",
})

-- Tombol logo buka/tutup
local toggleCircle = new("Frame", {
	Size = UDim2.fromOffset(52, 52),
	Position = UDim2.new(0, 20, 0.5, -26),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0, Visible = false,
}, gui)
round(toggleCircle, 14)
gradient(toggleCircle, "seq", 45)
outline(toggleCircle, Color3.new(1, 1, 1), 1.5, 0.55)
new("TextLabel", {
	Text = "Meki\nHub", Font = FONTB, TextSize = 12, TextColor3 = T.Bg,
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
}, toggleCircle)
local toggleHit = new("TextButton", {
	Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = true,
}, toggleCircle)
local isDraggingCircle = setupDrag(toggleCircle, toggleHit)
toggleHit.MouseButton1Click:Connect(function()
	if not isDraggingCircle() then Window:Toggle() end
end)

addCleanup(UserInputService.InputBegan:Connect(function(input, gp)
	if gp or isCleaningUp then return end
	if input.KeyCode == Enum.KeyCode.RightShift and toggleCircle.Visible then
		Window:Toggle()
	end
end))

-- Selesai loading -> loading hilang -> UI muncul
task.spawn(function()
	task.wait(3)
	if isCleaningUp then return end
	local info = TweenInfo.new(0.5)
	TweenService:Create(loadingScreen, info, {BackgroundTransparency = 1}):Play()
	TweenService:Create(loadBox, info, {BackgroundTransparency = 1}):Play()
	for _, v in pairs(loadBox:GetDescendants()) do
		if v:IsA("UIStroke") then
			TweenService:Create(v, info, {Transparency = 1}):Play()
		elseif v:IsA("Frame") then
			TweenService:Create(v, info, {BackgroundTransparency = 1}):Play()
		elseif v:IsA("TextLabel") then
			TweenService:Create(v, info, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		elseif v:IsA("ImageLabel") then
			TweenService:Create(v, info, {BackgroundTransparency = 1, ImageTransparency = 1}):Play()
		end
	end
	task.wait(0.6)
	if isCleaningUp then return end
	pcall(function() loadSpin:Disconnect() end)
	loadingScreen:Destroy()

    -- Key gate tampil setelah loading, sebelum menu utama.
    if not keySaved() then
        local gate = new("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=T.Bg, BackgroundTransparency=0.04, ZIndex=300}, gui)
        -- Dekorasi latar agar layar key tidak terlihat kosong.
        local glowTop = new("Frame", {Size=UDim2.fromOffset(230,230), Position=UDim2.new(0, -90, 0, -95), BackgroundColor3=T.Accent, BackgroundTransparency=0.88, ZIndex=300}, gate)
        round(glowTop,115)
        local glowBottom = new("Frame", {Size=UDim2.fromOffset(190,190), Position=UDim2.new(1, -80, 1, -75), BackgroundColor3=T.Accent2 or T.Accent, BackgroundTransparency=0.9, ZIndex=300}, gate)
        round(glowBottom,95)

        local card = new("Frame", {Size=UDim2.fromOffset(360,246), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=T.Panel, ZIndex=301}, gate)
        round(card,16); outline(card,T.Accent,1.2,0.2)

        -- Panel samping dengan identitas MEKI HUB.
        local side = new("Frame", {Size=UDim2.new(0,96,1,0), BackgroundColor3=T.Bg, BorderSizePixel=0, ZIndex=302}, card)
        round(side,15)
        local sideCover = new("Frame", {Size=UDim2.new(0,18,1,0), Position=UDim2.new(1,-18,0,0), BackgroundColor3=T.Bg, BorderSizePixel=0, ZIndex=302}, side)
        gradient(side,"seq",45)
        new("TextLabel", {Text="M", Font=FONTB, TextSize=38, TextColor3=T.Bg, BackgroundColor3=T.Accent, Position=UDim2.fromOffset(21,35), Size=UDim2.fromOffset(54,54), ZIndex=303}, side)
        new("TextLabel", {Text="MEKI", Font=FONTB, TextSize=15, TextColor3=T.Text, BackgroundTransparency=1, Position=UDim2.fromOffset(8,103), Size=UDim2.new(1,-16,0,22), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=303}, side)
        new("TextLabel", {Text="HUB V3", Font=FONT, TextSize=10, TextColor3=T.SubText, BackgroundTransparency=1, Position=UDim2.fromOffset(8,125), Size=UDim2.new(1,-16,0,18), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=303}, side)
        local sideLine = new("Frame", {Size=UDim2.fromOffset(38,2), Position=UDim2.new(0.5,-19,0,157), BackgroundColor3=T.Accent, BorderSizePixel=0, ZIndex=303}, side)
        new("TextLabel", {Text="ACCESS\nPROTECTED", Font=FONTB, TextSize=8, TextColor3=T.SubText, BackgroundTransparency=1, Position=UDim2.fromOffset(5,169), Size=UDim2.new(1,-10,0,30), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=303}, side)

        -- Form key di panel utama.
        new("TextLabel", {Text="WELCOME BACK", Font=FONTB, TextSize=9, TextColor3=T.Accent, BackgroundTransparency=1, Position=UDim2.fromOffset(112,20), Size=UDim2.new(1,-126,0,16), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=303}, card)
        new("TextLabel", {Text="MEKI HUB ACCESS", Font=FONTB, TextSize=17, TextColor3=T.Text, BackgroundTransparency=1, Position=UDim2.fromOffset(112,38), Size=UDim2.new(1,-126,0,26), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=303}, card)
        new("TextLabel", {Text="Masukkan access key untuk lanjut.", Font=FONT, TextSize=10, TextColor3=T.SubText, BackgroundTransparency=1, Position=UDim2.fromOffset(112,65), Size=UDim2.new(1,-126,0,18), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=303}, card)
        local box = new("TextBox", {Text="", PlaceholderText="ENTER YOUR KEY", ClearTextOnFocus=false, Font=FONTB, TextSize=12, TextColor3=T.Text, PlaceholderColor3=T.SubText, BackgroundColor3=T.Track, BorderSizePixel=0, Position=UDim2.fromOffset(112,91), Size=UDim2.new(1,-128,0,36), ZIndex=303}, card)
        round(box,8); outline(box,T.Stroke,1,0.2); new("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},box)
        -- Paksa input key menjadi huruf besar secara otomatis.
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local upperText = string.upper(box.Text)
            if box.Text ~= upperText then
                local cursor = box.CursorPosition
                box.Text = upperText
                box.CursorPosition = cursor
            end
        end)
        local status = new("TextLabel", {Text="●  WAITING FOR KEY", Font=FONTB, TextSize=9, TextColor3=T.SubText, BackgroundTransparency=1, Position=UDim2.fromOffset(112,132), Size=UDim2.new(1,-126,0,17), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=303}, card)
        local submit = new("TextButton", {Text="SUMMIT KEY", Font=FONTB, TextSize=10, TextColor3=T.Bg, BackgroundColor3=T.Accent, BorderSizePixel=0, Position=UDim2.fromOffset(112,160), Size=UDim2.new(1,-128,0,32), ZIndex=303}, card)
        round(submit,8); gradient(submit,"seq",0)
        local get = new("TextButton", {Text="GET KEY  ↗", Font=FONTB, TextSize=10, TextColor3=T.Text, BackgroundColor3=T.PanelLite, BorderSizePixel=0, Position=UDim2.fromOffset(112,199), Size=UDim2.new(1,-128,0,29), ZIndex=303}, card)
        round(get,8); outline(get,T.Stroke,1,0.35)

        local function openLink()
            pcall(function() if setclipboard then setclipboard(LINKVERTISE_URL) end end)
            pcall(function() game:GetService("GuiService"):OpenBrowserWindow(LINKVERTISE_URL) end)
            status.Text = "●  LINK COPIED / OPENING..."
            status.TextColor3 = T.Success
        end
        get.MouseButton1Click:Connect(openLink)
        submit.MouseButton1Click:Connect(function()
            if string.upper(box.Text) == REQUIRED_KEY then
                saveKey()
                status.Text = "●  KEY VERIFIED. LOADING HUB..."
                status.TextColor3 = T.Success
                task.wait(0.35)
                if gate.Parent then gate:Destroy() end
                Window:SetVisible(true); toggleCircle.Visible = true
                Window:Notify("Meki Hub", "Key berhasil diverifikasi", 3, "success")
            else
                status.Text = "●  INVALID KEY. TRY AGAIN."
                status.TextColor3 = T.Danger
                box.Text = ""
            end
        end)
    else
        Window:SetVisible(true)
        toggleCircle.Visible = true
        Window:Notify("Meki Hub", "Key tersimpan, selamat datang " .. player.DisplayName, 3, "success")
    end
end)

--=====================================================================
-- FITUR PLAYER (logic)
--=====================================================================
local flySpeed = 150
local walkSpeed = 50
local speedEnabled = false
local defaultWalkSpeed = 16
local isFlying = false
local flyBV, flyBG, flyConn
local isNoclip = false
local noclipConn
local isInfJump = false
local freezeTrack = nil

local function getMoveVector()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.MoveDirection.Magnitude == 0 then return Vector3.new(0, 0, 0) end
	local rel = workspace.CurrentCamera.CFrame:VectorToObjectSpace(hum.MoveDirection)
	local v = Vector3.new(rel.X, 0, rel.Z)
	return v.Magnitude > 0 and v.Unit or v
end

local function stopFly()
	if not isFlying then return end
	isFlying = false
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	if flyConn then flyConn:Disconnect() flyConn = nil end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = speedEnabled and walkSpeed or defaultWalkSpeed end
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
	end
	if freezeTrack then
		pcall(function() freezeTrack:Stop() end)
		freezeTrack = nil
	end
end

local function toggleFly(state)
	if not state then stopFly(); return end

	local char = player.Character
	local hrp = getHRP()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return false, "Karakter belum siap" end

	isFlying = true
	if not speedEnabled then defaultWalkSpeed = hum.WalkSpeed end
	hum.WalkSpeed = 0

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 10000
	flyBG.D = 100
	flyBG.Parent = hrp

	local animate = char:FindFirstChild("Animate")
	if animate then animate.Disabled = true end
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() t:Stop(0) end)
		end
		pcall(function()
			local id
			local idle = animate and animate:FindFirstChild("idle")
			local a1 = idle and idle:FindFirstChild("Animation1")
			if a1 then id = a1.AnimationId end
			id = id or (hum.RigType == Enum.HumanoidRigType.R15 and "rbxassetid://507766666" or "rbxassetid://180435571")
			local freezeAnim = Instance.new("Animation")
			freezeAnim.AnimationId = id
			freezeTrack = animator:LoadAnimation(freezeAnim)
			freezeTrack.Priority = Enum.AnimationPriority.Action4
			freezeTrack:Play(0)
			freezeTrack:AdjustSpeed(0)
		end)
	end

	if flyConn then flyConn:Disconnect() end
	flyConn = RunService.RenderStepped:Connect(function()
		if not isFlying or not hrp.Parent then return end
		local cam = workspace.CurrentCamera
		local moveVec = getMoveVector()

		flyBV.Velocity = (cam.CFrame.LookVector * -moveVec.Z * flySpeed) + (cam.CFrame.RightVector * moveVec.X * flySpeed)

		local _, camYaw, _ = cam.CFrame:ToEulerAnglesYXZ()
		flyBG.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, camYaw, 0)
	end)
end

local function toggleNoclip(state)
	isNoclip = state
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	if isNoclip then
		noclipConn = RunService.Stepped:Connect(function()
			if player.Character then
				for _, v in pairs(player.Character:GetDescendants()) do
					if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
				end
			end
		end)
	else
		if player.Character then
			for _, v in pairs(player.Character:GetDescendants()) do
				if v:IsA("BasePart") then v.CanCollide = true end
			end
		end
	end
end

addCleanup(RunService.Heartbeat:Connect(function()
	if not isInfJump then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = getHRP()
	if not hum or not hrp then return end

	local holding = hum.Jump
	if not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		holding = true
	end

	if holding then
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, 50, v.Z)
	end
end))

-- ANTI AFK (cuma jalan pas Roblox ngira kamu idle)
local antiAfkConn
local function setAntiAfk(on)
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn = nil end
	if on then
		antiAfkConn = player.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end)
	end
end

-- ANTI STUCK STATE
addCleanup(RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and not isFlying and hum.Health > 0 then
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end))

-- SPEED HACK (dipaksa tiap frame selama ON)
addCleanup(RunService.Heartbeat:Connect(function()
	if not speedEnabled or isFlying then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end
end))

--=====================================================================
-- TAB: HOME
--=====================================================================
local HM = Window:CreateTab("Home", "home")

local card = new("Frame", {
	Size = UDim2.new(1, 0, 0, 88),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	LayoutOrder = HM:NextOrder(),
}, HM.Page)
round(card, 12)
gradient(card, "card", 20)
outline(card, T.Stroke, 1, 0.4)

local homeAvatar = new("ImageLabel", {
	Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(14, 14),
	BackgroundColor3 = T.PanelLite, BorderSizePixel = 0,
}, card)
round(homeAvatar, 30)
local homeAvStroke = outline(homeAvatar, Color3.new(1, 1, 1), 2, 0)
gradient(homeAvStroke, "seq", 45)
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and homeAvatar.Parent then homeAvatar.Image = img end
end)

new("TextLabel", {
	Text = player.DisplayName, Font = FONTB, TextSize = 16, TextColor3 = T.Text,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(86, 16), Size = UDim2.new(1, -96, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, card)
new("TextLabel", {
	Text = "@" .. player.Name .. "  |  ID " .. player.UserId, Font = FONT, TextSize = 11, TextColor3 = T.SubText,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(86, 38), Size = UDim2.new(1, -96, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, card)
new("TextLabel", {
	Text = "Umur akun: " .. player.AccountAge .. " hari", Font = FONT, TextSize = 11, TextColor3 = T.Accent,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(86, 56), Size = UDim2.new(1, -96, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

HM:CreateSection("Info Server")

local function infoRow(key)
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = T.Panel, BorderSizePixel = 0,
		LayoutOrder = HM:NextOrder(),
	}, HM.Page)
	round(f, 8)
	outline(f, T.Stroke, 1, 0.6)
	new("TextLabel", {
		Text = key, Font = FONT, TextSize = 12, TextColor3 = T.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	return new("TextLabel", {
		Text = "-", Font = FONTB, TextSize = 12, TextColor3 = T.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -12, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
end

local mapLbl     = infoRow("Map")
local placeLbl   = infoRow("Place ID")
local playersLbl = infoRow("Pemain")
local fpsLbl     = infoRow("FPS")
local pingLbl    = infoRow("Ping")
local timeLbl    = infoRow("Durasi Sesi")

placeLbl.Text = tostring(game.PlaceId)
mapLbl.Text = game.Name
task.spawn(function()
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	if ok and info and info.Name and mapLbl.Parent then mapLbl.Text = info.Name end
end)

local frames, acc = 0, 0
addCleanup(RunService.RenderStepped:Connect(function(dt)
	frames = frames + 1
	acc = acc + dt
end))

local function getPing()
	local ok, v = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and math.floor(v) or 0
end

local startClock = os.clock()
task.spawn(function()
	while not isCleaningUp do
		task.wait(0.5)
		if isCleaningUp then break end
		local fps = (acc > 0) and math.floor(frames / acc + 0.5) or 0
		frames, acc = 0, 0
		local ping = getPing()
		local secs = math.floor(os.clock() - startClock)
		local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60

		fpsLbl.Text = fps .. " FPS"
		pingLbl.Text = ping .. " ms"
		playersLbl.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
		timeLbl.Text = string.format("%02d:%02d:%02d", h, m, s)
		Window.StatsLabel.Text = fps .. " FPS  |  " .. ping .. " ms"
	end
end)

--=====================================================================
-- TAB: WAYPOINTS
--=====================================================================
local waypoints = {}
local autoTarget, autoRun, autoState = 1, 0, false
local summitState = false
local FILE = "meki_hub_" .. tostring(game.PlaceId) .. ".json"

local function saveData()
	if not hasFileAPI() then return end
	local data = {}
	for i, wp in ipairs(waypoints) do data[i] = { name = wp.name, cf = { wp.cframe:GetComponents() } } end
	pcall(function() writefile(FILE, HttpService:JSONEncode(data)) end)
end

local function loadData()
	if not hasFileAPI() or not isfile(FILE) then return end
	local ok, raw = pcall(readfile, FILE)
	if not ok or not raw then return end
	local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok2 or type(decoded) ~= "table" then return end
	for _, wp in ipairs(decoded) do
		if type(wp.name) == "string" and type(wp.cf) == "table" and #wp.cf == 12 then
			table.insert(waypoints, { name = wp.name, cframe = CFrame.new(unpack(wp.cf)) })
		end
	end
end

local WP = Window:CreateTab("Waypoints", "pin")
local renderLists
local autoToggle

local function saveCurrent()
	local char = player.Character
	if not char then
		Window:Notify("Waypoint", "Karakter belum siap", 2, "error")
		return
	end
	table.insert(waypoints, { name = "Lokasi " .. (#waypoints + 1), cframe = char:GetPivot() })
	saveData()
	renderLists()
	Window:Notify("Waypoint", "Lokasi " .. #waypoints .. " tersimpan", 1.5, "success")
end

WP:CreateSection("Auto Teleport")
autoToggle = WP:CreateToggle({
	Name = "Auto TP", Flag = "autoTP",
	Callback = function(s)
		if not s then
			autoState = false
			return
		end
		if #waypoints == 0 then return false, "Belum ada waypoint tersimpan" end
		if summitState then return false, "Matikan Auto Summit dulu" end

		autoState = true
		autoTarget = 1
		autoRun = autoRun + 1
		local myRun = autoRun
		task.spawn(function()
			while autoState and myRun == autoRun and not isCleaningUp do
				if #waypoints == 0 then
					autoToggle:Set(false)
					break
				end
				if autoTarget > #waypoints then autoTarget = 1 end
				local wp = waypoints[autoTarget]
				local char = player.Character
				if char and wp then
					pcall(function()
						char:PivotTo(wp.cframe)
						local hrp = char:FindFirstChild("HumanoidRootPart")
						if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
						resetHumanoidState()
					end)
				end
				task.wait(AUTO_INTERVAL)
				if autoState and myRun == autoRun and #waypoints > 0 then
					autoTarget = (autoTarget % #waypoints) + 1
				end
			end
		end)
	end,
})
WP:CreateSlider({
	Name = "Jeda Auto TP", Flag = "autoInterval", Min = 0.1, Max = 5, Default = AUTO_INTERVAL, Step = 0.1, Suffix = " dtk",
	Callback = function(v) AUTO_INTERVAL = v end,
})

WP:CreateSection("Lokasi")
WP:CreateButton({ Name = "+  Simpan Lokasi Sekarang", Accent = true, Callback = saveCurrent })
WP:CreateSection("Daftar Waypoint")

local function buildRow(page, i, wp)
	local row = new("Frame", {
		Name = "WPRow",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = T.Panel, BorderSizePixel = 0,
		LayoutOrder = 1000 + i,
	}, page)
	round(row, 8)
	outline(row, T.Stroke, 1, 0.5)

	new("TextLabel", {
		Text = i .. ". " .. wp.name, Font = FONT, TextSize = 13, TextColor3 = T.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -(34 + 150), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local actBtn = new("TextButton", {
		Text = "TP", Font = FONTB, TextSize = 11, TextColor3 = T.Bg,
		BackgroundColor3 = T.Accent, AutoButtonColor = false,
		Size = UDim2.fromOffset(34, 26), Position = UDim2.new(1, -(34 + 138), 0.5, -13),
	}, row)
	round(actBtn, 6)
	actBtn.MouseButton1Click:Connect(function()
		local char = player.Character
		if char then
			char:PivotTo(wp.cframe)
			resetHumanoidState()
			Window:Notify("Teleport", "Ke " .. wp.name, 1.5)
		end
	end)

	local upBtn = new("TextButton", {
		Text = "", BackgroundColor3 = T.PanelLite, AutoButtonColor = false,
		Size = UDim2.fromOffset(24, 26), Position = UDim2.new(1, -112, 0.5, -13),
	}, row)
	round(upBtn, 6)
	local upArrow = new("TextLabel", {
		Text = ">", Font = FONTB, TextSize = 14, TextColor3 = T.SubText,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = -90,
	}, upBtn)
	if i > 1 then
		upBtn.MouseButton1Click:Connect(function()
			waypoints[i], waypoints[i - 1] = waypoints[i - 1], waypoints[i]
			saveData()
			renderLists()
		end)
	else
		upArrow.TextColor3 = T.Track
	end

	local downBtn = new("TextButton", {
		Text = "", BackgroundColor3 = T.PanelLite, AutoButtonColor = false,
		Size = UDim2.fromOffset(24, 26), Position = UDim2.new(1, -86, 0.5, -13),
	}, row)
	round(downBtn, 6)
	local downArrow = new("TextLabel", {
		Text = ">", Font = FONTB, TextSize = 14, TextColor3 = T.SubText,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = 90,
	}, downBtn)
	if i < #waypoints then
		downBtn.MouseButton1Click:Connect(function()
			waypoints[i], waypoints[i + 1] = waypoints[i + 1], waypoints[i]
			saveData()
			renderLists()
		end)
	else
		downArrow.TextColor3 = T.Track
	end

	local editBtn = new("TextButton", {
		Text = "", BackgroundColor3 = T.PanelLite, AutoButtonColor = false,
		Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -60, 0.5, -13),
	}, row)
	round(editBtn, 6)
	-- ikon pensil (digambar)
	new("Frame", {
		Size = UDim2.fromOffset(4, 12), Position = UDim2.new(0.5, -2, 0.5, -7),
		BackgroundColor3 = T.SubText, BorderSizePixel = 0, Rotation = 45,
	}, editBtn)
	new("Frame", {
		Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, 5),
		BackgroundColor3 = T.SubText, BorderSizePixel = 0,
	}, editBtn)
	editBtn.MouseButton1Click:Connect(function()
		Window:Prompt("Ganti Nama Waypoint", wp.name, function(newName)
			wp.name = newName
			saveData()
			renderLists()
		end)
	end)

	local delBtn = new("TextButton", {
		Text = "X", Font = FONTB, TextSize = 11, TextColor3 = T.Text,
		BackgroundColor3 = T.Danger, AutoButtonColor = false,
		Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0.5, -13),
	}, row)
	round(delBtn, 6)
	delBtn.MouseButton1Click:Connect(function()
		table.remove(waypoints, i)
		if autoTarget > #waypoints then autoTarget = math.max(1, #waypoints) end
		saveData()
		renderLists()
	end)
end

renderLists = function()
	pruneReg()
	for _, c in ipairs(WP.Page:GetChildren()) do
		if c.Name == "WPRow" then c:Destroy() end
	end
	if #waypoints == 0 then
		new("TextLabel", {
			Name = "WPRow",
			Text = "Belum ada waypoint. Tekan tombol simpan di atas.",
			Font = FONT, TextSize = 12, TextColor3 = T.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = 1000,
		}, WP.Page)
	else
		for i, wp in ipairs(waypoints) do
			buildRow(WP.Page, i, wp)
		end
	end
end

--=====================================================================
-- TAB: TELEPORTS (pilih map -> Auto Summit)
--=====================================================================
-- Tambah map baru: salin satu blok { name = "...", points = { ... } } di bawah ini.
-- Tiap titik: { name = "nama", cf = { 12 angka CFrame } }
local TELEPORT_MAPS = {
	{
		name = "MOUNT FUNKOT",
		points = {
			{ name = "cp 1", cf = { -8.677769660949707, 4.69999885559082, 836.5045166015625, -0.9564000964164734, 6.390950346712998e-8, 0.2920597791671753, 5.421065907285083e-8, 1, -4.130121666889863e-8, -0.2920597791671753, -2.3667734438959088e-8, -0.9564000964164734 } },
			{ name = "summit", cf = { -4221.38037109375, 2980.21435546875, 21684.75, -0.9715039730072022, 2.5034383455135868e-9, 0.23702339828014375, 4.351584426132149e-9, 1, 7.274146618385657e-9, -0.23702339828014375, 8.098289150382243e-9, -0.9715039730072022 } },
			{ name = "bc", cf = { -4335.751953125, 2996.500732421875, 21742.18359375, 0.6425053477287293, 3.436352002950116e-8, 0.7662811875343323, 9.230559072648248e-8, 1, -1.2224019485529426e-7, -0.7662811875343323, 1.4927201164027793e-7, 0.6425053477287293 } },
		},
	},
	{
		name = "MOUNT SORRY",
		-- di titik terakhir, game minta ResetCheckpoint (balik ke basecamp) sebelum ngulang
		finishRemote = { "LavaSummitKit", "Remotes", "ResetCheckpoint" },
		points = {
			{ name = "Lokasi 1", cf = { -1453.88037109375, 1315.7882080078125, -4514.326171875, -0.9949424862861633, 0, 0.10044623166322708, 0, 1, 0, -0.10044623166322708, 0, -0.9949424862861633 } },
			{ name = "Lokasi 2", cf = { -1463.992431640625, 1344.937255859375, -3112.145751953125, -0.19555272161960602, 0, -0.9806931614875793, 0, 1, 0, 0.9806931614875793, 0, -0.19555272161960602 } },
			{ name = "Lokasi 3", cf = { -1359.891845703125, 1224.937255859375, -2229.94482421875, -0.8999244570732117, 0, 0.4360458552837372, 0, 1, 0, -0.4360458552837372, 0, -0.8999244570732117 } },
			{ name = "Lokasi 4", cf = { -1427.7603759765625, 1268.937255859375, -1403.12646484375, -0.9967790842056274, 0, -0.08019640296697617, 0, 1, 0, 0.08019640296697617, 0, -0.9967790842056274 } },
			{ name = "Lokasi 5", cf = { -1486.658935546875, 1268.9364013671875, -376.5919494628906, -0.7110816240310669, 1.26657337395919e-10, -0.7031094431877136, 7.516268851759378e-08, 1, -7.583477668049454e-08, 0.7031094431877136, -1.067723118808317e-07, -0.7110816240310669 } },
			{ name = "Lokasi 6", cf = { -1389.287109375, 1551.3262939453125, 1168.878662109375, -0.9993882775306702, -1.7158875209588587e-08, 0.034972574561834335, -1.4129022396502933e-08, 1, 8.6882224081819e-08, -0.034972574561834335, 8.63349427504545e-08, -0.9993882775306702 } },
			{ name = "Lokasi 7", cf = { -765.2026977539062, 1824.7886962890625, 1864.849365234375, -0.9976733326911926, 0, -0.06817574799060822, 0, 1, 0, 0.06817574799060822, 0, -0.9976733326911926 } },
			{ name = "Lokasi 8", cf = { -18.991838455200195, 2007.67919921875, 1680.8494873046875, -0.2137427031993866, 0, -0.976889967918396, 0, 1, 0, 0.976889967918396, 0, -0.2137427031993866 } },
			{ name = "Lokasi 9", cf = { 1204.2799072265625, 1772.002685546875, 1815.01513671875, -0.0269776564091444, 0, -0.9996360540390015, 0, 1, 0, 0.9996360540390015, 0, -0.0269776564091444 } },
			{ name = "Lokasi 10", cf = { 2614.21728515625, 2083.699462890625, 2101.213623046875, -0.38138851523399353, 0, -0.9244148135185242, 0, 1, 0, 0.9244148135185242, 0, -0.38138851523399353 } },
			{ name = "Lokasi 11", cf = { 2813.47607421875, 2164.113037109375, 2803.460693359375, -0.5829921960830688, 0, -0.8124777674674988, 0, 1, 0, 0.8124777674674988, 0, -0.5829921960830688 } },
			{ name = "Lokasi 12", cf = { 4301.3623046875, 2560.86962890625, 3979.83642578125, 0.0029296278953552246, 0, -0.9999957084655762, 0, 1, 0, 0.9999957084655762, 0, 0.0029296278953552246 } },
			{ name = "Lokasi 13", cf = { 7168.435546875, 3983.90478515625, 8614.44140625, -0.7129423022270203, 0, 0.7012227177619934, 0, 1, 0, -0.7012227177619934, 0, -0.7129423022270203 } },
			{ name = "Lokasi 14", cf = { 6703.90478515625, 3995.328857421875, 9495.5830078125, -0.9019111394882202, 0, 0.43192169070243835, 0, 1, 0, -0.43192169070243835, 0, -0.9019111394882202 } },
			{ name = "Lokasi 15", cf = { 6187.06591796875, 4154.01513671875, 10926.09375, -0.9945721626281738, 0, 0.10404905676841736, 0, 1, 0, -0.10404905676841736, 0, -0.9945721626281738 } },
			{ name = "Lokasi 16", cf = { 5569.26806640625, 4272.75830078125, 12535.923828125, -0.08799827098846436, -1.074441087212108e-07, 0.9961206316947937, 1.573736696514061e-08, 1, 1.0925280236051549e-07, -0.9961206316947937, 2.5290374239261837e-08, -0.08799827098846436 } },
		},
	},
	{
		name = "MOUNT SOREYA",
		-- Lokasi 22 sudah berada di titik reset/basecamp; tunggu 2 detik lalu ulang dari lokasi 1.
		cycleDelay = 2,
		points = {
			{ name = "Lokasi 1", cf = { 465.2262268066406, 451.2574768066406, -8944.884765625, 0.999977171421051, 8.956568109397267e-08, 0.006753375753760338, -8.9959584670396e-08, 1.0, 5.8022937565738175e-08, -0.006753375753760338, -5.862914420617926e-08, 0.999977171421051 } },
			{ name = "Lokasi 2", cf = { 450.9278259277344, 495.3647766113281, -9566.4169921875, 0.999938428401947, 2.1953468376523233e-08, 0.011094803921878338, -2.1072025901958114e-08, 1.0, -7.956339231895981e-08, -0.011094803921878338, 7.932469969773592e-08, 0.999938428401947 } },
			{ name = "Lokasi 3", cf = { 393.07696533203125, 640.940185546875, -10113.5068359375, 0.9980251789093018, -4.107807072273317e-08, 0.06281533092260361, 3.780193580382729e-08, 1.0, 5.334344166385563e-08, -0.06281533092260361, -5.086355514549723e-08, 0.9980251789093018 } },
			{ name = "Lokasi 4", cf = { 485.3341979980469, 643.888671875, -10684.146484375, -0.07656729221343994, -2.4567038181544377e-08, -0.9970644116401672, -7.60073781691517e-09, 1, -2.4055687219970424e-08, 0.9970644116401672, 5.736546793144726e-09, -0.07656729221343994 } },
			{ name = "Lokasi 5", cf = { 1086.5220947265625, 726.9559936523438, -11154.77734375, 0.9997825622558594, 2.2816186717733444e-09, 0.02085362933576107, -1.6146723957888298e-09, 1.0, -3.1999100258417457e-08, -0.02085362933576107, 3.1958471424786694e-08, 0.9997825622558594 } },
			{ name = "Lokasi 6", cf = { 974.2940063476562, 743.998779296875, -11815.5986328125, 0.1057509109377861, 2.3553035077839013e-09, 0.9943926334381104, -8.511861770976736e-10, 1.0, -2.2780635156038898e-09, -0.9943926334381104, -6.055059786902461e-10, 0.1057509109377861 } },
			{ name = "Lokasi 7", cf = { 392.1001281738281, 890.9053955078125, -11832.73046875, -0.18582166731357574, 2.5191166427157574e-15, 0.9825834631919861, 3.247671491747573e-15, 1.0, -1.9495837592014642e-15, -0.9825834631919861, 2.828833392846345e-15, -0.18582166731357574 } },
			{ name = "Lokasi 8", cf = { -324.4762268066406, 860.4766845703125, -11735.4833984375, 0.026753392070531845, 6.167360730186672e-14, 0.9996420741081238, -2.043649774961017e-14, 1.0, -6.114875180643006e-14, -0.9996420741081238, -1.8793245361607355e-14, 0.026753392070531845 } },
			{ name = "Lokasi 9", cf = { -868.4699096679688, 863.384033203125, -11736.3291015625, -0.041036177426576614, -2.5201552844578146e-08, 0.9991576671600342, 2.332847692798623e-09, 1.0, 2.5318611207580943e-08, -0.9991576671600342, 3.3698615009569725e-09, -0.041036177426576614 } },
			{ name = "Lokasi 10", cf = { -1281.6817626953125, 867.7041015625, -12093.5009765625, 0.9985512495040894, 4.440159415001251e-16, -0.05380885675549507, -4.511506588335257e-16, 1.0, -1.2044682778503043e-16, 0.05380885675549507, 1.4454822385686548e-16, 0.9985512495040894 } },
			{ name = "Lokasi 11", cf = { -1310.7728271484375, 901.794921875, -12835.283203125, 0.11296887695789337, 7.115592600001e-15, 0.9935985207557678, 4.583738275824433e-15, 1.0, -7.682592219728293e-15, -0.9935985207557678, 5.422289458661403e-15, 0.11296887695789337 } },
			{ name = "Lokasi 12", cf = { -2316.08544921875, 926.2474365234375, -12674.1875, -0.9344789385795593, -3.49352795581126e-08, -0.35601842403411865, -3.041247609303355e-08, 1.0, -1.8300907456136883e-08, 0.35601842403411865, -6.274411656903567e-09, -0.9344789385795593 } },
			{ name = "Lokasi 13", cf = { -2307.584716796875, 922.5309448242188, -11857.6875, -0.7694045901298523, 6.084164994035746e-08, 0.6387616991996765, 5.314154449820308e-08, 1.0, -3.123903269397488e-08, -0.6387616991996765, 9.909330245250203e-09, -0.7694045901298523 } },
			{ name = "Lokasi 14", cf = { -2443.790771484375, 966.5309448242188, -11056.515625, 0.08942752331495285, 9.244352128234823e-08, 0.9959933161735535, 9.511425957953179e-08, 1.0, -1.0135545380762778e-07, -0.9959933161735535, 1.0379713444308436e-07, 0.08942752331495285 } },
			{ name = "Lokasi 15", cf = { -3480.800537109375, 985.4891967773438, -11026.193359375, 0.7330354452133179, -3.2478031375404726e-09, 0.68019038438797, -1.2725646314493133e-08, 1.0, 1.8489165753976522e-08, -0.68019038438797, -2.2209077243928732e-08, 0.7330354452133179 } },
			{ name = "Lokasi 16", cf = { -4225.501953125, 1006.4288330078125, -11014.1689453125, -0.00672221090644598, -9.357729879866383e-08, 0.9999774098396301, 4.997040647936046e-08, 1.0, 9.391533239977434e-08, -0.9999774098396301, 5.060059748984713e-08, -0.00672221090644598 } },
			{ name = "Lokasi 17", cf = { -4650.3271484375, 1085.0804443359375, -11668.5595703125, -0.06734001636505127, 2.496225626202886e-08, 0.9977300763130188, 9.458340599621806e-08, 1.0, -1.863531018386766e-08, -0.9977300763130188, 9.311381177212752e-08, -0.06734001636505127 } },
			{ name = "Lokasi 18", cf = { -5543.0146484375, 1106.4356689453125, -11651.4296875, 0.044536292552948, -9.074737405967426e-09, 0.9990077614784241, 7.253122902284304e-08, 1.0, 5.850270046181549e-09, -0.9990077614784241, 7.219870923336202e-08, 0.044536292552948 } },
			{ name = "Lokasi 19", cf = { -6761.7568359375, 1100.008056640625, -11506.435546875, -0.9987558722496033, -3.922038516179782e-08, -0.04986699298024178, -3.7384129569772995e-08, 1.0, -3.775574342057553e-08, 0.04986699298024178, -3.584453267535537e-08, -0.9987558722496033 } },
			{ name = "Lokasi 20", cf = { -6760.42529296875, 1105.5643310546875, -10800.583984375, -0.979160726070404, 4.907910522433667e-08, 0.2030867487192154, 6.756027204346537e-08, 1.0, 8.406881590872217e-08, -0.2030867487192154, 9.60374819669596e-08, -0.979160726070404 } },
			{ name = "Lokasi 21", cf = { -6768.21337890625, 1318.4285888671875, -10082.080078125, -0.9984205365180969, 1.9393437966641613e-08, -0.05618179962038994, 1.2905613466784871e-08, 1.0, 1.1584192805003113e-07, 0.05618179928064346, 1.1493390417172122e-07, -0.9984205365180969 } },
			{ name = "Lokasi 22", cf = { -6830.0439453125, 1314.447265625, -9901.853515625, -0.6374328136444092, -4.897924199553927e-08, 0.7705059051513672, 3.088304501019934e-09, 1.0, 6.612256697735575e-08, -0.7705059051513672, 4.452825308476349e-08, -0.6374328136444092 } },
		},
	},
}
for _, m in ipairs(TELEPORT_MAPS) do
	for _, pt in ipairs(m.points) do
		pt.cframe = CFrame.new(unpack(pt.cf))
	end
end

local TPT = Window:CreateTab("Teleports", "flag")
local selectedMap
local summitDelay = 0.5
local summitRun = 0
local summitToggle

local function findMap(name)
	for _, m in ipairs(TELEPORT_MAPS) do
		if m.name == name then return m end
	end
end

local function tpTo(pt)
	local char = player.Character
	if not char then return false end
	pcall(function()
		char:PivotTo(pt.cframe)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
		resetHumanoidState()
	end)
	return true
end

-- Auto Summit normal: teleport langsung ke setiap waypoint.
local function stopSummitAnim() end

-- Kirim remote reset (dipakai map yang punya finishRemote)
local function fireFinishRemote(map)
	local path = map.finishRemote
	if not path then return end
	local char = player.Character
	if char and char:GetAttribute("Carried") == true then return end -- game menolak reset saat digendong
	local obj = game:GetService("ReplicatedStorage")
	for _, name in ipairs(path) do
		obj = obj and obj:FindFirstChild(name)
	end
	if obj and obj:IsA("RemoteEvent") then
		local ok, err = pcall(function() obj:FireServer() end)
		if not ok then warn("[MekiHub] ResetCheckpoint gagal: " .. tostring(err)) end
	else
		warn("[MekiHub] Remote ResetCheckpoint tidak ditemukan")
	end
end

TPT:CreateSection("Pilih Map")
local mapNames = {}
for _, m in ipairs(TELEPORT_MAPS) do table.insert(mapNames, m.name) end
TPT:CreateDropdown({
	Options = mapNames, Placeholder = "Pilih map...", Flag = "tpMap",
	Callback = function(name)
		selectedMap = findMap(name)
		Window:Notify("Teleports", "Map: " .. name, 1.5)
	end,
})

TPT:CreateSection("Auto Summit")
summitToggle = TPT:CreateToggle({
	Name = "Auto Summit", Flag = "autoSummit",
	Callback = function(s)
		if not s then
			summitState = false
			stopSummitAnim()
			return
		end
		if not selectedMap then return false, "Pilih map dulu" end
		if autoState then return false, "Matikan Auto TP (Waypoints) dulu" end

		summitState = true
		summitRun = summitRun + 1
		local myRun = summitRun
		task.spawn(function()
			local idx, last = 1, nil
			while summitState and myRun == summitRun and not isCleaningUp do
				local map = selectedMap
				if not map or #map.points == 0 then
					summitToggle:Set(false)
					break
				end
				if map ~= last then
					idx = 1
					last = map
				end
				if idx > #map.points then idx = 1 end

                tpTo(map.points[idx])
                task.wait(summitDelay)

				-- Setelah titik terakhir: panggil remote hanya untuk map yang memerlukannya,
				-- lalu beri jeda tambahan sesuai konfigurasi map sebelum kembali ke titik 1.
				if idx == #map.points then
					if map.finishRemote then
						task.wait(0.25)
						fireFinishRemote(map)
						task.wait(math.max(summitDelay, 1.5))
					end
					task.wait(map.cycleDelay or 0)
				end
				idx = idx + 1
			end
		end)
	end,
})
local summitNote = TPT:CreateLabel("NOTE : JIKA ADA CP YANG KE-SKIP, MATIKAN AUTO SUMMIT LALU NYALAKAN LAGI.")
summitNote.Size = UDim2.new(1, 0, 0, 42)

--=====================================================================
-- TAB: PLAYERS (TP ke pemain + Spectate)
--=====================================================================
local PT = Window:CreateTab("Players", "users")
local specTarget, specConn
local plFilter = ""
local plList
local renderPlayers

local function stopSpectate()
	local was = specTarget
	if specConn then specConn:Disconnect() specConn = nil end
	specTarget = nil
	local cam = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if cam and hum then cam.CameraSubject = hum end
	if was and renderPlayers then renderPlayers() end
end

local function startSpectate(target)
	stopSpectate()
	specTarget = target
	specConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local ch = target.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if cam and hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
	end)
	renderPlayers()
	Window:Notify("Spectate", "Melihat " .. target.DisplayName, 1.5)
end

local function tpToPlayer(target)
	local char = player.Character
	local tchar = target.Character
	local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
	if not char or not thrp then
		Window:Notify("Teleport", "Pemain belum siap / tidak punya karakter", 2, "error")
		return
	end
	char:PivotTo(thrp.CFrame * CFrame.new(0, 0, 3))
	resetHumanoidState()
	Window:Notify("Teleport", "Ke " .. target.DisplayName, 1.5)
end

PT:CreateSection("Cari Pemain")
PT:CreateInput({
	Placeholder = "Ketik nama pemain...",
	Callback = function(text)
		plFilter = tostring(text):lower():match("^%s*(.-)%s*$")
		renderPlayers()
	end,
})
PT:CreateButton({ Name = "Berhenti Spectate", Callback = function()
	if specTarget then
		stopSpectate()
		Window:Notify("Spectate", "Kembali ke karakter sendiri", 1.5)
	end
end })

PT:CreateSection("Daftar Pemain")
plList = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = PT:NextOrder(),
}, PT.Page)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, plList)

renderPlayers = function()
	pruneReg()
	for _, c in ipairs(plList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end

	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local key = (p.DisplayName .. " " .. p.Name):lower()
			if plFilter == "" or key:find(plFilter, 1, true) then
				table.insert(list, p)
			end
		end
	end
	table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)

	if #list == 0 then
		new("TextLabel", {
			Text = (plFilter == "") and "Tidak ada pemain lain di server." or "Pemain tidak ditemukan.",
			Font = FONT, TextSize = 12, TextColor3 = T.SubText,
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32),
		}, plList)
		return
	end

	for i, p in ipairs(list) do
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = T.Panel, BorderSizePixel = 0,
			LayoutOrder = i,
		}, plList)
		round(row, 8)
		outline(row, T.Stroke, 1, 0.5)

		new("TextLabel", {
			Text = p.DisplayName, Font = FONTB, TextSize = 13, TextColor3 = T.Text,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -118, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		new("TextLabel", {
			Text = "@" .. p.Name, Font = FONT, TextSize = 11, TextColor3 = T.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -118, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local tpBtn = new("TextButton", {
			Text = "TP", Font = FONTB, TextSize = 11, TextColor3 = T.Bg,
			BackgroundColor3 = T.Accent, AutoButtonColor = false,
			Size = UDim2.fromOffset(34, 28), Position = UDim2.new(1, -96, 0.5, -14),
		}, row)
		round(tpBtn, 6)
		tpBtn.MouseButton1Click:Connect(function() tpToPlayer(p) end)

		local isSpec = (specTarget == p)
		local viewBtn = new("TextButton", {
			Text = isSpec and "Stop" or "View", Font = FONTB, TextSize = 11, TextColor3 = T.Text,
			BackgroundColor3 = isSpec and T.Danger or T.PanelLite, AutoButtonColor = false,
			Size = UDim2.fromOffset(48, 28), Position = UDim2.new(1, -56, 0.5, -14),
		}, row)
		round(viewBtn, 6)
		viewBtn.MouseButton1Click:Connect(function()
			if specTarget == p then
				stopSpectate()
			else
				startSpectate(p)
			end
		end)
	end
end
renderPlayers()

addCleanup(Players.PlayerAdded:Connect(function() task.defer(renderPlayers) end))
addCleanup(Players.PlayerRemoving:Connect(function(p)
	if specTarget == p then stopSpectate() end
	task.defer(renderPlayers)
end))

--=====================================================================
-- ESP + FULLBRIGHT (logic)
--=====================================================================
local ESP = {
	enabled = false, box = true, name = true, dist = true, health = true,
	tracer = false, teamCheck = false, maxDist = 1000,
	color = Color3.fromRGB(255, 70, 90),
}
local espFolder = Instance.new("Folder")
espFolder.Name = "MekiESP"
espFolder.Parent = parentGui()
local tracerLayer = new("Frame", {
	Name = "Tracers", Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0,
}, gui)
local espObjs = {}
local espConn

local function espClear(p)
	local o = espObjs[p]
	if not o then return end
	pcall(function() o.hl:Destroy() end)
	pcall(function() o.bb:Destroy() end)
	pcall(function() o.line:Destroy() end)
	espObjs[p] = nil
end

local function espCreate(p)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = false
	hl.Parent = espFolder

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 46)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.Parent = espFolder

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32),
		Font = FONTB, TextSize = 13, TextColor3 = ESP.color,
		TextStrokeTransparency = 0.3, Text = "",
		TextYAlignment = Enum.TextYAlignment.Bottom,
	}, bb)
	local barBack = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(80, 5),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0,
	}, bb)
	round(barBack, 2)
	local barFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 220, 140), BorderSizePixel = 0,
	}, barBack)
	round(barFill, 2)

	local line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = ESP.color, BorderSizePixel = 0, Visible = false,
	}, tracerLayer)

	local o = {hl = hl, bb = bb, lbl = lbl, barBack = barBack, barFill = barFill, line = line}
	espObjs[p] = o
	return o
end

local function espHide(o)
	o.hl.Enabled = false
	o.bb.Enabled = false
	o.line.Visible = false
end

local function espUpdate()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local myHRP = getHRP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local show = hrp ~= nil and hum ~= nil and hum.Health > 0
			if show and ESP.teamCheck and p.Team ~= nil and p.Team == player.Team then show = false end
			local dist = 0
			if show and myHRP then
				dist = (myHRP.Position - hrp.Position).Magnitude
				if dist > ESP.maxDist then show = false end
			end

			local o = espObjs[p]
			if not show then
				if o then espHide(o) end
			else
				if not o then o = espCreate(p) end

				o.hl.Adornee = char
				o.hl.FillColor = ESP.color
				o.hl.OutlineColor = ESP.color
				o.hl.Enabled = ESP.box

				local showText = ESP.name or ESP.dist
				local txt = ""
				if ESP.name then txt = p.DisplayName end
				if ESP.dist then txt = txt .. ((txt ~= "") and "\n" or "") .. math.floor(dist) .. " m" end
				o.bb.Adornee = hrp
				o.bb.Enabled = showText or ESP.health
				o.lbl.Visible = showText
				o.lbl.Text = txt
				o.lbl.TextColor3 = ESP.color
				o.barBack.Visible = ESP.health
				if ESP.health then
					local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					o.barFill.Size = UDim2.fromScale(frac, 1)
					o.barFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(70, 220, 140), frac)
				end

				if ESP.tracer then
					local v, onScreen = cam:WorldToViewportPoint(hrp.Position)
					if onScreen then
						local a = Vector2.new(vp.X / 2, vp.Y)
						local b = Vector2.new(v.X, v.Y)
						local d = b - a
						local mid = a + d / 2
						o.line.Size = UDim2.fromOffset(d.Magnitude, 2)
						o.line.Position = UDim2.fromOffset(mid.X, mid.Y)
						o.line.Rotation = math.deg(math.atan2(d.Y, d.X))
						o.line.BackgroundColor3 = ESP.color
						o.line.Visible = true
					else
						o.line.Visible = false
					end
				else
					o.line.Visible = false
				end
			end
		end
	end
end

local function espStop()
	if espConn then espConn:Disconnect() espConn = nil end
	for p in pairs(espObjs) do espClear(p) end
end

local function espStart()
	if espConn then return end
	espConn = RunService.RenderStepped:Connect(function() pcall(espUpdate) end)
end

addCleanup(Players.PlayerRemoving:Connect(function(p) espClear(p) end))

-- Fullbright
local Lighting = game:GetService("Lighting")
local fbSaved
local function setFullbright(on)
	if on then
		if not fbSaved then
			fbSaved = {
				Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
				Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1000000
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	elseif fbSaved then
		for k, v in pairs(fbSaved) do Lighting[k] = v end
		fbSaved = nil
	end
end

-- ANTI LAG (FPS Booster)
local AL = { on = false, extreme = false }
local alSaved = setmetatable({}, { __mode = "k" })
local alConn
local alToken = 0
local alQuality

local function alRecord(inst, prop)
	local s = alSaved[inst]
	if not s then
		s = {}
		alSaved[inst] = s
	end
	if s[prop] == nil then s[prop] = inst[prop] end
end

local function alProcess(inst)
	if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
		or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") then
		alRecord(inst, "Enabled")
		inst.Enabled = false
	elseif inst:IsA("PostEffect") then
		alRecord(inst, "Enabled")
		inst.Enabled = false
	elseif inst:IsA("BasePart") and not inst:IsA("Terrain") then
		alRecord(inst, "Material")
		alRecord(inst, "Reflectance")
		inst.Material = Enum.Material.SmoothPlastic
		inst.Reflectance = 0
		if AL.extreme then
			alRecord(inst, "CastShadow")
			inst.CastShadow = false
		end
	elseif AL.extreme and (inst:IsA("Decal") or inst:IsA("Texture")) then
		alRecord(inst, "Transparency")
		inst.Transparency = 1
	elseif AL.extreme and inst:IsA("Light") then
		alRecord(inst, "Enabled")
		inst.Enabled = false
	end
end

local function alRestore()
	alToken = alToken + 1
	if alConn then alConn:Disconnect() alConn = nil end
	for inst, props in pairs(alSaved) do
		pcall(function()
			for prop, val in pairs(props) do inst[prop] = val end
		end)
	end
	alSaved = setmetatable({}, { __mode = "k" })
	if alQuality then
		pcall(function() settings().Rendering.QualityLevel = alQuality end)
		alQuality = nil
	end
end

local function alStart()
	alRestore()
	if not AL.on then return end
	local my = alToken

	pcall(function()
		alRecord(Lighting, "GlobalShadows")
		Lighting.GlobalShadows = false
	end)
	pcall(function()
		local terr = workspace.Terrain
		alRecord(terr, "WaterWaveSize")
		alRecord(terr, "WaterWaveSpeed")
		alRecord(terr, "WaterReflectance")
		terr.WaterWaveSize = 0
		terr.WaterWaveSpeed = 0
		terr.WaterReflectance = 0
	end)
	if AL.extreme then
		pcall(function()
			alQuality = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
	end

	alConn = workspace.DescendantAdded:Connect(function(d) pcall(alProcess, d) end)

	task.spawn(function()
		for _, d in ipairs(Lighting:GetDescendants()) do pcall(alProcess, d) end
		local list = workspace:GetDescendants()
		for i, d in ipairs(list) do
			if alToken ~= my or isCleaningUp then return end
			pcall(alProcess, d)
			if i % 300 == 0 then task.wait() end
		end
	end)
end

--=====================================================================
-- TAB: MOVEMENT
--=====================================================================
local MV = Window:CreateTab("Movement", "user")

MV:CreateSection("Terbang")
MV:CreateToggle({ Name = "Fly", Flag = "fly", ResetOnRespawn = true, Callback = toggleFly })
MV:CreateSlider({
	Name = "Kecepatan Fly", Flag = "flySpeed", Min = 10, Max = 1000, Default = 150, Step = 5,
	Callback = function(v) flySpeed = v end,
})

MV:CreateSection("Lari")
MV:CreateToggle({
	Name = "Speed Hack", Flag = "speedHack", ResetOnRespawn = true,
	Callback = function(s)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if s then
			if not hum then return false, "Karakter belum siap" end
			if not isFlying then defaultWalkSpeed = hum.WalkSpeed end
			speedEnabled = true
			if not isFlying then hum.WalkSpeed = walkSpeed end
		else
			speedEnabled = false
			if hum and not isFlying then hum.WalkSpeed = defaultWalkSpeed end
		end
	end,
})
MV:CreateSlider({
	Name = "Kecepatan Jalan", Flag = "walkSpeed", Min = 16, Max = 300, Default = 50, Step = 1,
	Callback = function(v) walkSpeed = v end,
})

MV:CreateSection("Lainnya")
MV:CreateToggle({ Name = "No Clip", Flag = "noclip", ResetOnRespawn = true, Callback = toggleNoclip })
MV:CreateToggle({
	Name = "Infinite Jump (tahan = loncat terus)", Flag = "infJump", ResetOnRespawn = true,
	Callback = function(s) isInfJump = s end,
})

--=====================================================================
-- TAB: ESP
--=====================================================================
local EP = Window:CreateTab("ESP", "eye")

EP:CreateSection("Utama")
EP:CreateToggle({
	Name = "Aktifkan ESP", Flag = "esp",
	Callback = function(s)
		ESP.enabled = s
		if s then espStart() else espStop() end
	end,
})

EP:CreateSection("Tampilan")
EP:CreateToggle({ Name = "Outline Highlight", Flag = "espBox", Default = true, Silent = true, Callback = function(s) ESP.box = s end })
EP:CreateToggle({ Name = "Nama", Flag = "espName", Default = true, Silent = true, Callback = function(s) ESP.name = s end })
EP:CreateToggle({ Name = "Jarak", Flag = "espDist", Default = true, Silent = true, Callback = function(s) ESP.dist = s end })
EP:CreateToggle({ Name = "Bar HP", Flag = "espHealth", Default = true, Silent = true, Callback = function(s) ESP.health = s end })
EP:CreateToggle({ Name = "Tracer (garis ke pemain)", Flag = "espTracer", Silent = true, Callback = function(s) ESP.tracer = s end })

EP:CreateSection("Filter")
EP:CreateToggle({ Name = "Team Check (sembunyikan satu tim)", Flag = "espTeam", Silent = true, Callback = function(s) ESP.teamCheck = s end })
EP:CreateSlider({
	Name = "Jarak Maksimal", Flag = "espMax", Min = 50, Max = 3000, Default = 1000, Step = 50, Suffix = " m",
	Callback = function(v) ESP.maxDist = v end,
})
EP:CreateColorRow({
	Name = "Warna ESP", Flag = "espColor", Default = "Merah",
	Colors = {
		{"Merah",  Color3.fromRGB(255, 70, 90)},
		{"Kuning", Color3.fromRGB(255, 220, 70)},
		{"Putih",  Color3.fromRGB(255, 255, 255)},
		{"Cyan",   Color3.fromRGB(0, 210, 255)},
		{"Hijau",  Color3.fromRGB(70, 220, 140)},
	},
	Callback = function(_, color) ESP.color = color end,
})

--=====================================================================
-- TAB: MISC
--=====================================================================
local MS = Window:CreateTab("Misc", "misc")

MS:CreateSection("Performa")
MS:CreateToggle({ Name = "Anti AFK", Flag = "antiAfk", Default = true, Callback = setAntiAfk })
MS:CreateToggle({
	Name = "Anti Lag (FPS Booster)", Flag = "antiLag",
	Callback = function(s)
		AL.on = s
		alStart()
	end,
})
MS:CreateToggle({
	Name = "Anti Lag Ekstrem (hapus texture & bayangan)", Flag = "antiLagExtreme", Silent = true,
	Callback = function(s)
		AL.extreme = s
		if AL.on then alStart() end
	end,
})
MS:CreateLabel("Aktifkan Anti Lag dulu, mode Ekstrem menambah penghapusan texture, decal, lampu, dan kualitas grafik minimum. Semua kembali normal saat dimatikan.")

MS:CreateSection("Visual")
MS:CreateToggle({ Name = "Fullbright", Flag = "fullbright", Callback = setFullbright })

MS:CreateSection("Karakter")
MS:CreateButton({
	Name = "Reset Karakter",
	Callback = function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
	end,
})

addCleanup(player.CharacterAdded:Connect(function()
	stopFly()
	if isNoclip then toggleNoclip(false) end
	isInfJump = false
	speedEnabled = false
	stopSpectate()
	Window:ResetToggles()

	task.wait(0.5)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then defaultWalkSpeed = hum.WalkSpeed end
end))

--=====================================================================
-- TAB: CONFIG
--=====================================================================
local TeleportService = game:GetService("TeleportService")
local CFG_FILE = "meki_hub_configs.json"
local cfgData = { configs = {}, last = nil, autoload = false }

local function cfgRead()
	if not hasFileAPI() or not isfile(CFG_FILE) then return end
	local ok, raw = pcall(readfile, CFG_FILE)
	if not ok or not raw then return end
	local ok2, dec = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok2 and type(dec) == "table" then
		cfgData.configs = type(dec.configs) == "table" and dec.configs or {}
		cfgData.last = type(dec.last) == "string" and dec.last or nil
		cfgData.autoload = (dec.autoload == true)
	end
end

local function cfgWrite()
	if not hasFileAPI() then return false end
	return (pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(cfgData)) end))
end

local function cfgSnapshot()
	local out = {}
	for id, f in pairs(Window.Flags) do
		local ok, v = pcall(f.get)
		if ok then out[id] = v end
	end
	return out
end

local function cfgApply(vals)
	-- slider & warna dulu, baru toggle (biar Speed Hack dkk. pakai nilai yang benar)
	for id, f in pairs(Window.Flags) do
		if vals[id] ~= nil and f.kind ~= "toggle" then pcall(f.set, vals[id]) end
	end
	for id, f in pairs(Window.Flags) do
		if vals[id] ~= nil and f.kind == "toggle" then pcall(f.set, vals[id]) end
	end
end

cfgRead()
local renderCfgList

local function cfgLoad(name)
	local vals = cfgData.configs[name]
	if type(vals) ~= "table" then
		Window:Notify("Config", "Config tidak ditemukan", 2, "error")
		return
	end
	cfgApply(vals)
	cfgData.last = name
	cfgWrite()
	Window:Notify("Config", "'" .. name .. "' dimuat", 2, "success")
end

local function cfgSave(name)
	name = tostring(name):match("^%s*(.-)%s*$")
	if #name == 0 then
		Window:Notify("Config", "Nama tidak boleh kosong", 2, "error")
		return
	end
	if #name > 24 then name = name:sub(1, 24) end
	local existed = cfgData.configs[name] ~= nil
	cfgData.configs[name] = cfgSnapshot()
	cfgData.last = name
	if cfgWrite() then
		Window:Notify("Config", "'" .. name .. (existed and "' diperbarui" or "' tersimpan"), 2, "success")
	else
		Window:Notify("Config", "Gagal menyimpan (executor tidak support file)", 3, "error")
	end
	renderCfgList()
end

local function cfgDelete(name)
	cfgData.configs[name] = nil
	if cfgData.last == name then cfgData.last = nil end
	cfgWrite()
	renderCfgList()
	Window:Notify("Config", "'" .. name .. "' dihapus", 1.5)
end

local function rejoinServer()
	Window:Notify("Rejoin", "Masuk ulang ke server...", 2)
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			TeleportService:Teleport(game.PlaceId, player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end
	end)
end

local hopping = false
local function serverHop()
	if hopping then return end
	hopping = true
	Window:Notify("Server Hop", "Mencari server lain...", 2)
	task.spawn(function()
		local ok, err = pcall(function()
			local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			local raw
			local okGet, res = pcall(function() return game:HttpGet(url) end)
			if okGet and res then
				raw = res
			else
				local req = (env.syn and env.syn.request) or env.http_request or env.request
				if req then
					local r = req({ Url = url, Method = "GET" })
					raw = r and r.Body
				end
			end
			assert(raw, "tidak bisa mengambil daftar server")
			local data = HttpService:JSONDecode(raw)
			local candidates = {}
			for _, s in ipairs(data.data or {}) do
				if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers - 1 then
					table.insert(candidates, s.id)
				end
			end
			assert(#candidates > 0, "tidak ada server lain yang tersedia")
			local pick = candidates[math.random(1, math.min(#candidates, 10))]
			TeleportService:TeleportToPlaceInstance(game.PlaceId, pick, player)
		end)
		if not ok then
			local msg = tostring(err):gsub("^.-:%d+: ", "")
			Window:Notify("Server Hop", msg, 3, "error")
		end
		task.delay(4, function() hopping = false end)
	end)
end

local CF = Window:CreateTab("Config", "gear")

CF:CreateSection("Simpan Pengaturan")
CF:CreateButton({
	Name = "+  Simpan Pengaturan Sekarang", Accent = true,
	Callback = function()
		Window:Prompt("Nama Config", "", cfgSave, "Contoh: Farming")
	end,
})
CF:CreateLabel("Menyimpan semua toggle, slider, ESP, dan tema yang sedang dipakai. Nama yang sama akan ditimpa.")

CF:CreateSection("Config Tersimpan")
local cfgList = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = CF:NextOrder(),
}, CF.Page)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, cfgList)

CF:CreateToggle({
	Name = "Auto Load config terakhir saat dijalankan", Default = cfgData.autoload, Silent = true,
	Callback = function(s)
		if cfgData.autoload ~= s then
			cfgData.autoload = s
			cfgWrite()
		end
	end,
})

renderCfgList = function()
	pruneReg()
	for _, c in ipairs(cfgList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local names = {}
	for n in pairs(cfgData.configs) do table.insert(names, n) end
	table.sort(names)

	if #names == 0 then
		new("TextLabel", {
			Text = "Belum ada config tersimpan.", Font = FONT, TextSize = 12, TextColor3 = T.SubText,
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32),
		}, cfgList)
		return
	end

	for i, n in ipairs(names) do
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = T.Panel, BorderSizePixel = 0,
			LayoutOrder = i,
		}, cfgList)
		round(row, 8)
		outline(row, T.Stroke, 1, 0.5)
		new("TextLabel", {
			Text = n, Font = FONT, TextSize = 13, TextColor3 = T.Text,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		local loadBtn = new("TextButton", {
			Text = "Load", Font = FONTB, TextSize = 11, TextColor3 = T.Bg,
			BackgroundColor3 = T.Accent, AutoButtonColor = false,
			Size = UDim2.fromOffset(50, 26), Position = UDim2.new(1, -90, 0.5, -13),
		}, row)
		round(loadBtn, 6)
		loadBtn.MouseButton1Click:Connect(function() cfgLoad(n) end)
		local delBtn = new("TextButton", {
			Text = "X", Font = FONTB, TextSize = 11, TextColor3 = T.Text,
			BackgroundColor3 = T.Danger, AutoButtonColor = false,
			Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0.5, -13),
		}, row)
		round(delBtn, 6)
		delBtn.MouseButton1Click:Connect(function() cfgDelete(n) end)
	end
end
renderCfgList()

CF:CreateSection("Server")
CF:CreateButton({ Name = "Rejoin Server", Callback = rejoinServer })
CF:CreateButton({ Name = "Server Hop (pindah server lain)", Callback = serverHop })

CF:CreateSection("Tampilan")
CF:CreateColorRow({
	Name = "Warna Aksen", Flag = "theme", Colors = THEMES, Default = currentThemeName,
	Callback = function(name, color)
		applyTheme(name, color)
		Window:Notify("Tema", "Warna " .. name .. " dipakai", 1.5, "success")
	end,
})
CF:CreateToggle({
	Name = "FPS & Ping di topbar", Flag = "showStats", Default = true, Silent = true,
	Callback = function(s) Window.StatsLabel.Visible = s end,
})
CF:CreateToggle({
	Name = "Border berputar", Flag = "spinBorder", Default = true, Silent = true,
	Callback = function(s) Window.SpinBorder = s end,
})

CF:CreateSection("Lainnya")
CF:CreateLabel("RightShift (PC) atau tombol Meki Hub = buka/tutup menu. Menu bisa digeser dari mana saja.")
CF:CreateButton({
	Name = "Hapus UI (Unload)", Danger = true,
	Callback = function()
		if env.MekiHub_Cleanup then pcall(env.MekiHub_Cleanup) end
	end,
})

-- Auto load config terakhir (kalau diaktifkan)
if cfgData.autoload and cfgData.last and cfgData.configs[cfgData.last] then
	task.spawn(function()
		task.wait(3.8)
		if isCleaningUp then return end
		cfgLoad(cfgData.last)
	end)
end

--=====================================================================
-- CLEANUP (otomatis kalau script di-execute ulang / tombol X ditekan)
--=====================================================================
env.MekiHub_Cleanup = function()
	isCleaningUp = true
	autoState = false
	summitState = false
	isInfJump = false
	pcall(stopFly)
	pcall(toggleNoclip, false)
	pcall(espStop)
	pcall(stopSpectate)
	pcall(stopSummitAnim)
	pcall(setAntiAfk, false)
	pcall(alRestore)
	pcall(setFullbright, false)
	pcall(function() espFolder:Destroy() end)
	for _, c in ipairs(cleanupConns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end

-- INIT
loadData()
renderLists()
