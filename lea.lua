-- Target: MALAM SAMA OPAH (Sabun Studios)
-- Revision: v2.0 - Adaptive Difficulty Detection, Smooth UI, Robust Teleport & ESP
-- Execution Environment: Synapse Z / RoXploit / Delta / Fluxus

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Full-Bright Lighting
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.GlobalShadows = false
Lighting.FogEnd = 999999

-- Feature Toggles & Difficulty State
local Toggles = {
    ESP_Keys = false,
    ESP_Opah = false,
    TeleportKeys = false,
    InfStamina = false,
    FullBright = true,
    SpeedHack = false,
    Noclip = false,
    AutoWin = false
}

-- Adaptive Difficulty Detector (Scans workspace/ReplicatedStorage for active difficulty state)
local currentDifficulty = "Normal"
local targetKeyCount = 7

local function detectGameDifficulty()
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            local name = v.Name:lower()
            if name:find("easy") or name:find("mudah") then
                currentDifficulty = "Easy"
                targetKeyCount = 5
                break
            elseif name:find("hard") or name:find("sulit") then
                currentDifficulty = "Hard / Sulit"
                targetKeyCount = 7
                break
            elseif name:find("normal") then
                currentDifficulty = "Normal"
                targetKeyCount = 7
                break
            end
        end
        -- Fallback check in PlayerGui
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            for _, gui in ipairs(pGui:GetDescendants()) do
                if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                    local t = gui.Text:lower()
                    if t:find("easy") or t:find("5 kunci") then
                        currentDifficulty = "Easy"
                        targetKeyCount = 5
                    elseif t:find("sulit") or t:find("hard") or t:find("7 kunci") then
                        currentDifficulty = "Hard / Sulit"
                        targetKeyCount = 7
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(2) do
        detectGameDifficulty()
    end
end)

-- UI Construction: Smooth Modern UI Library with Acrylic/Blur aesthetic
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OpahProMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 480)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 80)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Topbar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 45)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MALAM SAMA OPAH | V2.0 PRO"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Status Indicator (Difficulty)
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 15, 0, 50)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Mode: Detecting... | Target Keys: --"
StatusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

task.spawn(function()
    while task.wait(0.5) do
        StatusLabel.Text = "Mode: " .. currentDifficulty .. " | Target Keys: " .. targetKeyCount
    end
end)

-- Scrolling Container
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -85)
ScrollFrame.Position = UDim2.new(0, 10, 0, 80)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ScrollFrame

-- Smooth Toggle Builder function with Tween animations
local function createToggle(name, desc, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 42)
    Button.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    Button.AutoButtonColor = false
    Button.Text = ""
    Button.Parent = ScrollFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(200, 200, 220)
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamSemibold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Button

    local StatusIndicator = Instance.new("Frame")
    StatusIndicator.Size = UDim2.new(0, 32, 0, 18)
    StatusIndicator.Position = UDim2.new(1, -42, 0.5, -9)
    StatusIndicator.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    StatusIndicator.Parent = Button

    local IndicatorCorner = Instance.new("UICorner")
    IndicatorCorner.CornerRadius = UDim.new(1, 0)
    IndicatorCorner.Parent = StatusIndicator

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 14, 0, 14)
    Circle.Position = UDim2.new(0, 2, 0.5, -7)
    Circle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    Circle.Parent = StatusIndicator

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local state = false
    Button.MouseButton1Click:Connect(function()
        state = not state
        local goalColorBg = state and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(50, 50, 65)
        local goalCirclePos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        local goalCircleCol = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)

        TweenService:Create(StatusIndicator, TweenInfo.new(0.2), {BackgroundColor3 = goalColorBg}):Play()
        TweenService:Create(Circle, TweenInfo.new(0.2), {Position = goalCirclePos, BackgroundColor3 = goalCircleCol}):Play()

        callback(state)
    end)
end

-- Feature Implementation
createToggle("ESP Kunci (Keys Scanner)", "Highlights active keys based on game mode", function(state)
    Toggles.ESP_Keys = state
end)

createToggle("ESP Opah (Monster Tracker)", "Real-time tracker for Opah", function(state)
    Toggles.ESP_Opah = state
end)

createToggle("Teleport All Required Keys to Me", "Instant collection of required keys", function(state)
    Toggles.TeleportKeys = state
    if state then
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local collected = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if collected >= targetKeyCount then break end
                    if obj.Name:lower():find("key") or obj.Name:lower():find("kunci") then
                        local part = obj:IsA("Model") and obj.PrimaryPart or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart"))
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

createToggle("Infinite Stamina", "Never run out of energy when running", function(state)
    Toggles.InfStamina = state
end)

createToggle("Speed Modifier (Walkspeed Boost)", "Increase movement speed safely", function(state)
    Toggles.SpeedHack = state
end)

createToggle("Noclip (Walk Through Walls)", "Bypass room obstacles and locked doors", function(state)
    Toggles.Noclip = state
end)

createToggle("Auto Win / Instant Exit", "Triggers door extraction instantly", function(state)
    Toggles.AutoWin = state
end)

createToggle("Full-Bright Lighting", "Removes darkness completely", function(state)
    Toggles.FullBright = state
end)

-- Hide / Unhide Keybind ([Insert] or [RightShift])
local hidden = false
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
        hidden = not hidden
        MainFrame.Visible = not hidden
    end
end)

-- Core Render / Game Loop
local espFolder = Instance.new("Folder", CoreGui)
espFolder.Name = "Opah_ESP_Storage"

RunService.RenderStepped:Connect(function()
    pcall(function()
        -- Clear old ESP
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end

        -- ESP Keys
        if Toggles.ESP_Keys then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("key") or obj.Name:lower():find("kunci") then
                    local part = obj:IsA("Model") and obj.PrimaryPart or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart"))
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 70, 0, 35)
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

        -- ESP Opah
        if Toggles.ESP_Opah then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("opah") or obj.Name:lower():find("monster") or obj.Name:lower():find("nenek")) then
                    local part = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 90, 0, 45)
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

        -- Speed Hack
        if Toggles.SpeedHack then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = 24
            end
        end

        -- Noclip Loop
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

        -- Auto Win Trigger
        if Toggles.AutoWin then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("exit") or obj.Name:lower():find("door") or obj.Name:lower():find("win") then
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

print("[+] MALAM SAMA OPAH v2.0 PRO Loaded. Press [INSERT] or [RIGHT SHIFT] to Hide/Show panel.")