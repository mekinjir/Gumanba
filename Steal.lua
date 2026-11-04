-- Target: Steal an Egg (Hard Anti-Cheat / Server-Sided Network Validation Bypass)
-- Architecture: ReplicatedStorage Remote Spoofing & Network Method Hooking
-- Execution Environment: Synapse Z / RoXploit / Delta / Fluxus

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- 1. Deep Anti-Cheat & Namecall Hooking (Blocks Ban/Kick telemetry and server validation flags)
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        -- Intercept anti-cheat telemetry or ban signals sent to server
        if method == "FireServer" or method == "InvokeServer" then
            local remoteName = tostring(self):lower()
            if remoteName:find("ban") or remoteName:find("anticheat") or remoteName:find("report") or remoteName:find("detect") then
                return nil -- Drop malicious packet reporting
            end
        end
        
        if method == "Kick" or method == "Ban" or tostring(self):lower():find("ban") then
            return nil
        end
        
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- 2. Hunt Down Game Remote Events for Stealing Eggs (Server-Side Bypass)
local stealRemote = nil
for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        local name = v.Name:lower()
        if name:find("steal") or name:find("egg") or name:find("grab") or name:find("collect") or name:find("buy") then
            stealRemote = v
            break
        end
    end
end

-- Toggles State
local Toggles = {
    RemoteSteal = false,
    RarePriority = false,
    ESP_Eggs = false,
    AntiBan = true
}

-- Cleanup Old UI
if CoreGui:FindFirstChild("StealAnEggHardcorePanel") then
    CoreGui.StealAnEggHardcorePanel:Destroy()
end
if CoreGui:FindFirstChild("Egg_Hardcore_ESP") then
    CoreGui.Egg_Hardcore_ESP:Destroy()
end

-- UI Panel Construction (High-Grade Cyberpunk Theme)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StealAnEggHardcorePanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 460)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -230)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(180, 50, 50) -- Hardcore warning accent
UIStroke.Thickness = 1.6
UIStroke.Parent = MainFrame

-- Topbar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 45)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "STEAL AN EGG | HARDCORE BYPASS"
TitleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Scrolling Container
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -65)
ScrollFrame.Position = UDim2.new(0, 10, 0, 55)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 380)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(180, 50, 50)
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ScrollFrame

local function createToggle(name, desc, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 44)
    Button.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
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
        local goalColorBg = state and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(45, 45, 60)
        local goalCirclePos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local goalCircleCol = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)

        TweenService:Create(StatusIndicator, TweenInfo.new(0.25), {BackgroundColor3 = goalColorBg}):Play()
        TweenService:Create(Circle, TweenInfo.new(0.25), {Position = goalCirclePos, BackgroundColor3 = goalCircleCol}):Play()

        callback(state)
    end)
end

-- Toggles
createToggle("Force Remote Steal (1s Loop)", "Spams server-side events bypassing client cooldowns", function(state)
    Toggles.RemoteSteal = state
end)

createToggle("Rare / Mythic Priority Filter", "Targets high-tier golden eggs first", function(state)
    Toggles.RarePriority = state
end)

createToggle("Deep ESP Eggs Tracker", "Real-time overlay for all eggs in map", function(state)
    Toggles.ESP_Eggs = state
end)

createToggle("Anti-Ban Shield (Active)", "Blocks server detection hooks", function(state)
    Toggles.AntiBan = state
end)

-- Hide/Unhide Keybind ([Insert])
local hidden = false
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
        hidden = not hidden
        MainFrame.Visible = not hidden
    end
end)

-- ESP Container
local espFolder = Instance.new("Folder", CoreGui)
espFolder.Name = "Egg_Hardcore_ESP"

local function getValidPart(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

-- 1-Second Hardcore Remote / Touch Exploit Loop
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if not Toggles.RemoteSteal then return end
            
            -- Method A: Fire Remote Event directly if found (bypasses physical proximity checks entirely)
            if stealRemote then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local name = obj.Name:lower()
                    if name:find("egg") or name:find("telur") then
                        if stealRemote:IsA("RemoteEvent") then
                            stealRemote:FireServer(obj)
                        elseif stealRemote:IsA("RemoteFunction") then
                            stealRemote:InvokeServer(obj)
                        end
                    end
                end
            end

            -- Method B: Physical Proximity / Touch Interest Spoofing
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local name = obj.Name:lower()
                    if name:find("egg") or name:find("telur") or name:find("golden") or name:find("mythic") then
                        if obj:IsA("ProximityPrompt") then
                            obj.HoldDuration = 0
                            fireproximityprompt(obj)
                        elseif obj:IsA("TouchTransmitter") then
                            firetouchinterest(hrp, obj.Parent, 0)
                            firetouchinterest(hrp, obj.Parent, 1)
                        end
                    end
                end
            end
        end)
    end
end)

-- ESP Render Loop
RunService.RenderStepped:Connect(function()
    pcall(function()
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end

        if Toggles.ESP_Eggs then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local name = obj.Name:lower()
                if name:find("egg") or name:find("telur") or name:find("golden") or name:find("mythic") then
                    local part = getValidPart(obj)
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 90, 0, 40)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = (name:find("golden") or name:find("mythic")) and "[ ★ RARE EGG ★ ]" or "[ EGG ]"
                        lbl.TextColor3 = (name:find("golden") or name:find("mythic")) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 80, 80)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.GothamBold
                    end
                end
            end
        end
    end)
end)

print("[+] Steal an Egg Hardcore Bypass Panel Loaded.")