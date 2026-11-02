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

local WIN_W, WIN_H, SIDEBAR_W = 540, 360, 132
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
		Position = UDim2.fromOffset(titleX, 0), Size = UDim2.fromOffset(86, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, topbar)

	-- Badge (pill)
	local badge = new("Frame", {
		Size = UDim2.fromOffset(78, 18),
		Position = UDim2.new(0, titleX + 88, 0.5, -9),
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
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabHolder)
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
			Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0,
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
	Window:SetVisible(true)
	toggleCircle.Visible = true
	Window:Notify("Meki Hub", "Berhasil dimuat, selamat datang " .. player.DisplayName, 3, "success")
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
local isFling = false
local flingConn = nil

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

local function toggleFling(state)
	isFling = state
	if flingConn then flingConn:Disconnect() flingConn = nil end
	if isFling then
		flingConn = RunService.Stepped:Connect(function()
			local myHRP = getHRP()
			if not myHRP then return end

			for _, otherPlayer in pairs(Players:GetPlayers()) do
				if otherPlayer ~= player and otherPlayer.Character then
					local otherHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
					if otherHRP and (myHRP.Position - otherHRP.Position).Magnitude < 4 then
						local bv = Instance.new("BodyVelocity")
						bv.Velocity = Vector3.new(math.random(-500, 500), math.random(500, 1000), math.random(-500, 500))
						bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
						bv.Parent = otherHRP
						task.delay(0.2, function()
							if bv then bv:Destroy() end
						end)
					end
				end
			end
		end)
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
addCleanup(player.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end))

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

MS:CreateSection("Troll")
MS:CreateToggle({ Name = "Touch Fling", Flag = "fling", ResetOnRespawn = true, Callback = toggleFling })

addCleanup(player.CharacterAdded:Connect(function()
	stopFly()
	if isNoclip then toggleNoclip(false) end
	if isFling then toggleFling(false) end
	isInfJump = false
	speedEnabled = false
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
	isInfJump = false
	pcall(stopFly)
	pcall(toggleNoclip, false)
	pcall(toggleFling, false)
	pcall(espStop)
	pcall(setFullbright, false)
	pcall(function() espFolder:Destroy() end)
	for _, c in ipairs(cleanupConns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end

-- INIT
loadData()
renderLists()
