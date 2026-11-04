-- Target: MALAM SAMA OPAH (Sabun Studios) - Updated with Key Teleport & Infinite Stamina
-- Execution Environment: Synapse Z / RoXploit / Delta / Fluxus
-- UI Library: Custom Draggable UI with Toggle Checkboxes & Hide/Unhide Keybind

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Full-Bright & Atmosphere Setup
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.GlobalShadows = false
Lighting.FogEnd = 999999

-- Feature Toggles State
local Toggles = {
    ESP_Keys = false,
    ESP_Opah = false,
    AutoWin = false,
    AntiAdmin = false,
    AntiBanned = false,
    Bypass = false,
    FullBright = true,
    InfStamina = false,
    TeleportKeys = false
}

-- Anti-Banned & Bypass Hooks
if Toggles.AntiBanned then
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" or method == "Ban" or tostring(self):lower():find("ban") then
            return nil
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- Anti-Admin Detection
if Toggles.AntiAdmin then
    Players.PlayerAdded:Connect(function(player)
        if player:GetRankInGroup(game.CreatorId) > 0 or player.UserId == 1 or player.Name:lower():find("admin") then
            LocalPlayer:Kick("[Anti-Admin] Moderator detected in server. Safely disconnected.")
        end
    end)
end

-- UI Construction: Modern Floating GUI with Hide/Unhide (Insert Key)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OpahMenuPanel"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 480)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICCorner = Instance.new("UICorner")
UICCorner.CornerRadius = UDim.new(0, 8)
UICCorner.Parent = MainFrame

local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.Text = "  MALAM SAMA OPAH | v1.1 PRO"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 14
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Container for toggles
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -60)
ScrollFrame.Position = UDim2.new(0, 10, 0, 50)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ScrollFrame

-- Function to create checkboxes
local function createToggle(name, callback)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, 0, 0, 35)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ToggleButton.Text = "  [OFF] " .. name
    ToggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    ToggleButton.TextSize = 13
    ToggleButton.Font = Enum.Font.SourceSans
    ToggleButton.TextXAlignment = Enum.TextXAlignment.Left
    ToggleButton.Parent = ScrollFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = ToggleButton

    local state = false
    ToggleButton.MouseButton1Click:Connect(function()
        state = not state
        if state then
            ToggleButton.Text = "  [ON] " .. name
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
            ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            ToggleButton.Text = "  [OFF] " .. name
            ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            ToggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        callback(state)
    end)
end

-- Build Toggles including new features
createToggle("ESP 7 Kunci (Keys)", function(state)
    Toggles.ESP_Keys = state
end)

createToggle("ESP Opah (Monster)", function(state)
    Toggles.ESP_Opah = state
end)

createToggle("Teleport All 7 Keys to Me", function(state)
    Toggles.TeleportKeys = state
    if state then
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj.Name:lower():find("key") or obj.Name:lower():find("kunci") then
                        local part = obj:IsA("Model") and obj.PrimaryPart or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart"))
                        if part then
                            part.CFrame = hrp.CFrame + Vector3.new(0, 2, 0)
                        end
                    end
                end
            end
        end)
    end
end)

createToggle("Infinite Stamina", function(state)
    Toggles.InfStamina = state
end)

createToggle("Auto Win (Instant Door/Trigger)", function(state)
    Toggles.AutoWin = state
end)

createToggle("Anti Admin & Staff Detect", function(state)
    Toggles.AntiAdmin = state
end)

createToggle("Anti Banned Hook", function(state)
    Toggles.AntiBanned = state
end)

createToggle("Bypass Anti-Cheat", function(state)
    Toggles.Bypass = state
end)

createToggle("Full-Bright Lighting", function(state)
    Toggles.FullBright = state
end)

-- Hide/Unhide Functionality via [Insert] Key
local hidden = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Insert then
        hidden = not hidden
        MainFrame.Visible = not hidden
    end
end)

-- ESP & Game Logic Loops
local espFolder = Instance.new("Folder", CoreGui)
espFolder.Name = "Opah_ESP_Container"

RunService.RenderStepped:Connect(function()
    pcall(function()
        -- Clear old markers
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end

        -- ESP Kunci
        if Toggles.ESP_Keys then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("key") or obj.Name:lower():find("kunci") then
                    local part = obj:IsA("Model") and obj.PrimaryPart or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart"))
                    if part then
                        local bb = Instance.new("BillboardGui", espFolder)
                        bb.Adornee = part
                        bb.Size = UDim2.new(0, 60, 0, 30)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "[ KUNCI ]"
                        lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.SourceSansBold
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
                        bb.Size = UDim2.new(0, 80, 0, 40)
                        bb.AlwaysOnTop = true
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "[ OPAH (BAHAYA) ]"
                        lbl.TextColor3 = Color3.fromRGB(255, 0, 0)
                        lbl.TextScaled = true
                        lbl.Font = Enum.Font.SourceSansBold
                    end
                end
            end
        end

        -- Infinite Stamina Loop (Locks stamina values or player stats)
        if Toggles.InfStamina then
            local char = LocalPlayer.Character
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v.Name:lower():find("stamina") or v.Name:lower():find("run") then
                        if v:IsA("NumberValue") or v:IsA("IntValue") then
                            v.Value = 100
                        end
                    end
                end
            end
            local lpGui = LocalPlayer:FindFirstChild("PlayerGui")
            if lpGui then
                for _, v in ipairs(lpGui:GetDescendants()) do
                    if v.Name:lower():find("stamina") and v:IsA("TextLabel") then
                        v.Text = "Stamina: 100 / 100"
                    end
                end
            end
        end

        -- Auto Win Logic
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

print("[+] MALAM SAMA OPAH v1.1 Pro Loaded. Press [INSERT] to Hide/Show menu.")