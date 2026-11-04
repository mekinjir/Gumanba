-- Target: MALAM SAMA OPAH (Sabun Studios)
-- Revision: v3.0 - Ultimate Edition (3 Difficulty Support, Door Code Decryptor, Premium UI with Glassmorphism)
-- Execution Environment: Synapse Z / RoXploit / Delta / Fluxus

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Full-Bright Lighting Setup
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.GlobalShadows = false
Lighting.FogEnd = 999999

-- State Management
local Toggles = {
    ESP_Keys = false,
    ESP_Opah = false,
    ESP_Code = false,
    TeleportKeys = false,
    InfStamina = false,
    SpeedBoost = false,
    Noclip = false,
    AutoWin = false,
    FullBright = true
}

-- Difficulty Detector (Easy, Sulit/Normal, Nightmare)
local currentGameMode = "Detecting..."
local targetKeys = 5

local function scanGameMode()
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            local name = v.Name:lower()
            if name:find("nightmare") or name:find("malam") then
                currentGameMode = "Nightmare"
                targetKeys = 10
                break
            elseif name:find("hard") or name:find("sulit") then
                currentGameMode = "Sulit"
                targetKeys = 7
                break
            elseif name:find("easy") or name:find("mudah") then
                currentGameMode = "Easy"
                targetKeys = 5
                break
            end
        end
        -- PlayerGui Text Scan
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            for _, gui in ipairs(pGui:GetDescendants()) do
                if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                    local t = gui.Text:lower()
                    if t:find("nightmare") then
                        currentGameMode = "Nightmare"
                        targetKeys = 10
                    elseif t:find("sulit") or t:find("hard") then
                        currentGameMode = "Sulit"
                        targetKeys = 7
                    elseif t:find("easy") or t:find("mudah") then
                        currentGameMode = "Easy"
                        targetKeys = 5
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(1.5) do
        scanGameMode()
    end
end)

-- Cleanup existing UI
if CoreGui:FindFirstChild("OpahUltimateMenu") then
    CoreGui.OpahUltimateMenu:Destroy()
end
if CoreGui:FindFirstChild("Opah_ESP_Storage") then
    CoreGui.Opah_ESP_Storage:Destroy()
end

-- Premium UI Construction (Glassmorphism + Smooth Gradients)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OpahUltimateMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 520)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Gradient Background Effect
local UIAspectRatio = Instance.new("UIGradient")
UIAspectRatio.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 35)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14))
})
UIAspectRatio.Rotation = 45
UIAspectRatio.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(80, 80, 120)
UIStroke.Transparency = 0.5
UIStroke.Thickness = 1.8
UIStroke.Parent = MainFrame

-- Topbar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MALAM SAMA OPAH | V3.0 ULTIMATE"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Mode & Status Banner
local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -24, 0, 32)
StatusBanner.Position = UDim2.new(0, 12, 0, 56)
StatusBanner.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
StatusBanner.Parent = MainFrame

local BannerCorner = Instance.new("UICorner")
BannerCorner.CornerRadius = UDim.new(0, 8)
BannerCorner.Parent = StatusBanner

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -15, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Mode: Scanning... | Keys Required: --"
StatusText.TextColor3 = Color3.fromRGB(120, 220, 255)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamMedium
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBanner

task.spawn(function()
    while task.wait(0.5) do
        StatusText.Text = "Mode: " .. currentGameMode .. " | Target Keys: " .. targetKeys
    end
end)

-- Scrolling Panel Container
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -100)
ScrollFrame.Position = UDim2.new(0, 10, 0, 96)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 540)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150)
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ScrollFrame

-- Smooth Toggle Component Builder
local function createToggle(name, desc, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 44)
    Button.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    Button.AutoButtonColor = false
    Button.Text = ""
    Button.Parent = ScrollFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 240)
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamSemibold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Button

    local StatusIndicator = Instance.new("Frame")
    StatusIndicator.Size = UDim2.new(0, 36, 0, 20)
    StatusIndicator.Position = UDim2.new(1, -46, 0.5, -10)
    StatusIndicator.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    StatusIndicator.Parent = Button

    local IndicatorCorner = Instance.new("UICorner")
    IndicatorCorner.CornerRadius = UDim.new(1, 0)
    IndicatorCorner.Parent = StatusIndicator

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 16, 0, 16)
    Circle.Position = UDim2.new(0, 2, 0.5, -8)
    Circle.BackgroundColor3 = Color3.fromRGB(180, 180, 200)
    Circle.Parent = StatusIndicator

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local state = false
    Button.MouseButton1Click:Connect(function()
        state = not state
        local goalColorBg = state and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(45, 45, 60)
        local goalCirclePos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local goalCircleCol = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)

        TweenService:Create(StatusIndicator, TweenInfo.new(0.25), {BackgroundColor3 = goalColorBg}):Play()
        TweenService:Create(Circle, TweenInfo.new(0.25), {Position = goalCirclePos, BackgroundColor3 = goalCircleCol}):Play()

        callback(state)
    end)
end

-- Feature Toggles Integration
createToggle("ESP Kunci (Key Scanner)", "Highlights all active map keys", function(state)
    Toggles.ESP_Keys = state
end)

createToggle("ESP Pintu & Kode Rahasia (Code/Door)", "Displays door passwords & exit codes", function(state)
    Toggles.ESP_Code = state
end)

createToggle("ESP Opah (Monster Live Tracker)", "Tracks killer location in real-time", function(state)
    Toggles.ESP_Opah = state
end)

createToggle("Teleport All Required Keys", "Instantly pulls all mode keys to you", function(state)
    Toggles.TeleportKeys = state
    if state then
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local collected = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if collected >= targetKeys then break end
                    local n = obj.Name:lower()
                    if n:find("key") or n:find("kunci") or n:find("item") then
                        local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or (obj:IsA("BasePart") and obj)
                        if part then
                            part.CFrame = hrp.CFrame + Vector3.new(0, 2, 0)
                            collected = collected + 1
                        end
                    end
                end
            end
        end)
    end
end)

createToggle("Infinite Stamina", "Never run out of energy", function(state)
    Toggles.InfStamina = state
end)

createToggle("Speed Booster (WalkSpeed 24)", "Move faster than Opah", function(state)
    Toggles.SpeedBoost = state
end)

createToggle("Noclip (Walk Through Walls)", "Bypass room barriers", function(state)
    Toggles.Noclip = state
end)

createToggle("Auto Win / Instant Escape", "Triggers exit sequence automatically", function(state)
    Toggles.AutoWin = state
end)

createToggle("Full-Bright Lighting", "Removes darkness & shadow fog", function(state)
    Toggles.FullBright = state
end)

-- Hide/Unhide Keybind ([Insert] / [RightShift])
local hidden = false
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
        hidden = not hidden
        MainFrame.Visible = not hidden
    end
end)

-- Robust ESP Render Loop & Code Decryptor
local espFolder = Instance.new("Folder", CoreGui)
espFolder.Name = "Opah_ESP_Storage"

local function getValidPart(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end

        -- ESP Keys
        if Toggles.ESP_Keys then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if n:find("key") or n:find("kunci") or n:find("item") then
                    local part = getValidPart(obj)
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 80, 0, 35)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "[ KUNCI ]"
                        lbl.TextColor3 = Color3.fromRGB(255, 230, 0)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.GothamBold
                    end
                end
            end
        end

        -- ESP Door & Password / Code Decryptor
        if Toggles.ESP_Code then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if n:find("code") or n:find("password") or n:find("pintu") or n:find("door") or n:find("lock") then
                    local part = getValidPart(obj)
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 110, 0, 45)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "[ KODE / PINTU KUNCI ]"
                        lbl.TextColor3 = Color3.fromRGB(0, 255, 200)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.GothamBold
                    end
                end
            end
            -- Also scan UI/PlayerGui for any revealed door code numbers
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                for _, gui in ipairs(pGui:GetDescendants()) do
                    if gui:IsA("TextLabel") and (gui.Text:lower():find("code") or gui.Text:lower():find("angka")) then
                        gui.TextColor3 = Color3.fromRGB(0, 255, 255)
                    end
                end
            end
        end

        -- ESP Opah
        if Toggles.ESP_Opah then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if obj:IsA("Model") and (n:find("opah") or n:find("monster") or n:find("nenek") or n:find("killer")) then
                    local part = getValidPart(obj)
                    if part and part ~= LocalPlayer.Character then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 95, 0, 40)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "[ OPAH BAHAYA ]"
                        lbl.TextColor3 = Color3.fromRGB(255, 50, 50)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.GothamBold
                    end
                end
            end
        end

        -- Infinite Stamina
        if Toggles.InfStamina then
            local char = LocalPlayer.Character
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v.Name:lower():find("stamina") and (v:IsA("NumberValue") or v:IsA("IntValue")) then
                        v.Value = 100
                    end
                end
            end
        end

        -- Speed Boost
        if Toggles.SpeedBoost then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = 24
            end
        end

        -- Noclip
        if Toggles.Noclip then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end

        -- Auto Win
        if Toggles.AutoWin then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if n:find("exit") or n:find("door") or n:find("win") or n:find("escape") then
                    if obj:IsA("ProximityPrompt") then
                        fireproximityprompt(obj)
                    elseif obj:IsA("TouchTransmitter") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Parent, 0)
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Parent, 1)
                    end
                end
            end
        end
    end)
end)

print("[+] MALAM SAMA OPAH v3.0 Ultimate Loaded successfully.")