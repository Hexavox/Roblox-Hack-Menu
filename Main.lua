local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

print("EXECUTED MY SCRIPT")

local gui = Instance.new("ScreenGui")
gui.Name = "MainHUD"
gui.Parent = player:WaitForChild("PlayerGui")

-- Draggable Dot UI
local dotSize = 40
local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Size = UDim2.new(0, dotSize, 0, dotSize)
dot.Position = UDim2.new(0.1, 0, 0.8, 0)
dot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
dot.Parent = gui
dot.Active = true
dot.Draggable = true

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

-- Expanded Menu UI
local menu = Instance.new("Frame")
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = dot.Position
menu.Size = dot.Size
menu.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
menu.BackgroundTransparency = 0.15
menu.Visible = false
menu.Parent = gui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0.05, 0)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.fromRGB(70, 70, 70)
menuStroke.Thickness = 2
menuStroke.Transparency = 0.5
menuStroke.Parent = menu

local isExpanded = false
local isAnimating = false
local lastDotPosition = dot.Position

-- Define expand/shrink functions
local function expandMenu()
    if isAnimating or isExpanded then return end
    isAnimating = true
    lastDotPosition = dot.Position
    menu.Position = dot.Position
    menu.Size = dot.Size
    menu.Visible = true
    dot.Visible = false

    local tween = TweenService:Create(menu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0.6, 0, 0.6, 0)
    })
    tween:Play()
    tween.Completed:Wait()

    isExpanded = true
    isAnimating = false
end

local function shrinkMenu()
    if isAnimating or not isExpanded then return end
    isAnimating = true

    local tween = TweenService:Create(menu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = lastDotPosition,
        Size = UDim2.new(0, dotSize, 0, dotSize)
    })
    tween:Play()
    tween.Completed:Wait()

    menu.Visible = false
    dot.Position = lastDotPosition
    dot.Visible = true

    isExpanded = false
    isAnimating = false
end

-- Toggle menu on Left Alt press
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        if isExpanded then
            shrinkMenu()
        else
            expandMenu()
        end
    end
end)

-- Placeholder requires for modules (fly.lua, speed.lua, etc.)
local flyModule = require(script.Parent:WaitForChild("fly"))
local speedModule = require(script.Parent:WaitForChild("speed"))
local autoModule = require(script.Parent:WaitForChild("auto"))

-- Initialize modules, passing the `menu` frame as parent
flyModule.Init(menu)
speedModule.Init(menu)
autoModule.Init(menu)

return {
    expandMenu = expandMenu,
    shrinkMenu = shrinkMenu
}
