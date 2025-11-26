-- ULTRA CLIENT-SIDE INSPECTOR
-- ]  = toggle GUI
-- \  = lock / unlock target

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local inspectVisible = false
local locked = false
local lockedObject = nil

----------------------------------------------------
-- GUI
----------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltraInspectGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 420, 0, 260)
frame.Position = UDim2.new(0, 50, 0, 120)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, 0, 0, 4)
accent.Position = UDim2.new(0, 0, 0, 0)
accent.BackgroundColor3 = Color3.fromRGB(130, 70, 255)
accent.BorderSizePixel = 0
accent.Parent = frame

local lockLabel = Instance.new("TextLabel")
lockLabel.Size = UDim2.new(1, -10, 0, 20)
lockLabel.Position = UDim2.new(0, 5, 0, 6)
lockLabel.BackgroundTransparency = 1
lockLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
lockLabel.Font = Enum.Font.GothamBold
lockLabel.TextSize = 18
lockLabel.TextXAlignment = Enum.TextXAlignment.Left
lockLabel.Text = "Unlocked"
lockLabel.Parent = frame

local infoBox = Instance.new("TextBox")
infoBox.Size = UDim2.new(1, -24, 1, -55)
infoBox.Position = UDim2.new(0, 12, 0, 34)
infoBox.BackgroundColor3 = Color3.fromRGB(28, 28, 44)
infoBox.BackgroundTransparency = 0.05
infoBox.TextColor3 = Color3.fromRGB(230, 230, 245)
infoBox.Font = Enum.Font.Gotham
infoBox.TextSize = 14
infoBox.TextXAlignment = Enum.TextXAlignment.Left
infoBox.TextYAlignment = Enum.TextYAlignment.Top
infoBox.MultiLine = true
infoBox.ClearTextOnFocus = false
infoBox.TextEditable = true      -- you can select+copy
infoBox.TextWrapped = true
infoBox.Parent = frame

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoBox

----------------------------------------------------
-- HIGHLIGHT (bounding box)
----------------------------------------------------

local selectionBox = Instance.new("SelectionBox")
selectionBox.LineThickness = 0.07
selectionBox.Color3 = Color3.fromRGB(130, 70, 255)
selectionBox.Transparency = 0.4
selectionBox.Parent = workspace
selectionBox.Visible = false

----------------------------------------------------
-- HELPERS
----------------------------------------------------

local function getTopItem()
    local target = mouse.Target
    if target then
        local model = target:FindFirstAncestorOfClass("Model")
        return model or target
    end
    return nil
end

local function getAncestryPath(obj)
    local chain = {}
    local cur = obj
    while cur do
        table.insert(chain, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(chain, " -> ")
end

local function getBoundingBox(obj)
    if obj:IsA("Model") then
        return obj:GetBoundingBox()
    elseif obj:IsA("BasePart") then
        return obj.CFrame, obj.Size
    end
    return nil, nil
end

local function getPlayerDebug()
    local lines = {}

    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hrp then
            local p = hrp.Position
            table.insert(lines, string.format("PlayerPos: %.1f, %.1f, %.1f", p.X, p.Y, p.Z))
        end
        if hum then
            table.insert(lines, "WalkSpeed: " .. tostring(hum.WalkSpeed))
            table.insert(lines, "JumpPower: " .. tostring(hum.JumpPower))
            table.insert(lines, "Health: " .. tostring(hum.Health) .. "/" .. tostring(hum.MaxHealth))
        end
    end

    local cam = workspace.CurrentCamera
    if cam then
        table.insert(lines, "CameraFOV: " .. tostring(cam.FieldOfView))
    end

    if #lines == 0 then
        return "Player/camera info unavailable."
    end
    return table.concat(lines, "\n")
end

local function buildInspectText(obj)
    if not obj then
        return "No object under mouse.\n\n" .. getPlayerDebug()
    end

    local out = {}

    -- General info
    table.insert(out, "Name: " .. obj.Name)
    table.insert(out, "Class: " .. obj.ClassName)
    table.insert(out, "FullName: " .. obj:GetFullName())
    table.insert(out, "Ancestry: " .. getAncestryPath(obj))
    table.insert(out, "Descendants: " .. tostring(#obj:GetDescendants()))

    -- Spatial / physics (if applicable)
    local pos
    if obj:IsA("BasePart") then
        pos = obj.Position
    elseif obj:IsA("Model") and obj.PrimaryPart then
        pos = obj.PrimaryPart.Position
    end
    if pos then
        table.insert(out, string.format("Position: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z))
    end

    local cf, size = getBoundingBox(obj)
    if cf and size then
        table.insert(out, string.format("BoundingBox: %.2f, %.2f, %.2f", size.X, size.Y, size.Z))
    end

    if obj:IsA("BasePart") then
        table.insert(out, "Anchored: " .. tostring(obj.Anchored))
        table.insert(out, "CanCollide: " .. tostring(obj.CanCollide))
        table.insert(out, "Transparency: " .. tostring(obj.Transparency))
        table.insert(out, "Material: " .. tostring(obj.Material))
        table.insert(out, "Color: " .. tostring(obj.Color))
        table.insert(out, "Reflectance: " .. tostring(obj.Reflectance))
    end

    -- Attributes
    local attrs = obj:GetAttributes()
    if next(attrs) then
        table.insert(out, "\nAttributes:")
        for k, v in pairs(attrs) do
            table.insert(out, string.format("  %s = %s", k, tostring(v)))
        end
    end

    -- Value objects in descendants
    local valuesBlock = {}
    for _, desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("StringValue") or desc:IsA("IntValue") or desc:IsA("NumberValue")
        or desc:IsA("BoolValue") or desc:IsA("ObjectValue") then
            local v = desc.Value
            if typeof(v) == "Instance" then
                v = v:GetFullName()
            end
            table.insert(valuesBlock, string.format("  %s (%s) = %s", desc.Name, desc.ClassName, tostring(v)))
        end
    end
    if #valuesBlock > 0 then
        table.insert(out, "\nValues (descendants):")
        for _, line in ipairs(valuesBlock) do
            table.insert(out, line)
        end
    end

    -- Generic player/camera debug at bottom
    table.insert(out, "\n" .. getPlayerDebug())

    return table.concat(out, "\n")
end

----------------------------------------------------
-- INPUT
----------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Toggle GUI
    if input.KeyCode == Enum.KeyCode.RightBracket then -- ]
        inspectVisible = not inspectVisible
        frame.Visible = inspectVisible
        selectionBox.Visible = inspectVisible
        if not inspectVisible then
            locked = false
            lockedObject = nil
            lockLabel.Text = "Unlocked"
            selectionBox.Adornee = nil
            infoBox.Text = ""
        end
    end

    -- Lock / unlock with backslash
    if inspectVisible and input.KeyCode == Enum.KeyCode.BackSlash then -- \
        if not locked then
            lockedObject = getTopItem()
            locked = true
            lockLabel.Text = "Locked"
        else
            locked = false
            lockedObject = nil
            lockLabel.Text = "Unlocked"
        end
    end
end)

----------------------------------------------------
-- UPDATE LOOP
----------------------------------------------------

RunService.RenderStepped:Connect(function()
    if not inspectVisible then return end

    local targetObj = locked and lockedObject or getTopItem()
    infoBox.Text = buildInspectText(targetObj)

    selectionBox.Visible = (targetObj ~= nil)
    selectionBox.Adornee = targetObj
end)
