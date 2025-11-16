print("EXECUTED MY SCRIPT (fly.lua)") -- Execution confirmation

local Fly = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

local flying = false
local flyConns = {}

function Fly.Init(parent)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0.8, 0, 0.18, 0)
    panel.Position = UDim2.new(0.1, 0, 0.1, 0)
    panel.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    panel.BackgroundTransparency = 0.15
    panel.Parent = parent

    local corner = Instance.new("UICorner", panel)
    corner.CornerRadius = UDim.new(0.15, 0)

    local label = Instance.new("TextLabel")
    label.Text = "Fly"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 21
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0.05, 0, 0, 0)
    label.Parent = panel

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 44, 0, 24)
    switch.Position = UDim2.new(0.8, 0, 0.3, 0)
    switch.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    switch.BackgroundTransparency = 0.12
    switch.Parent = panel

    local switchCorners = Instance.new("UICorner", switch)
    switchCorners.CornerRadius = UDim.new(1, 0)

    local switchStroke = Instance.new("UIStroke", switch)
    switchStroke.Color = Color3.fromRGB(20, 20, 20)
    switchStroke.Thickness = 1
    switchStroke.Transparency = 0.4

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
    knob.Parent = switch

    local knobCorners = Instance.new("UICorner", knob)
    knobCorners.CornerRadius = UDim.new(1, 0)

    local function setSwitch(on)
        if on then
            switch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            knob:TweenPosition(UDim2.new(1, -22, 0, 2), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        else
            switch.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            knob:TweenPosition(UDim2.new(0, 2, 0, 2), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        end
    end

    local function startFly()
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not root or not hum then return end

        local bv = Instance.new("BodyVelocity", root)
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.new(0, 0, 0)

        local bg = Instance.new("BodyGyro", root)
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.CFrame = root.CFrame

        hum.PlatformStand = true

        local controls = {F=0, B=0, L=0, R=0}
        local speed = 0
        local maxSpeed = 50

        flyConns[#flyConns+1] = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.W then controls.F = 1 end
            if input.KeyCode == Enum.KeyCode.S then controls.B = -1 end
            if input.KeyCode == Enum.KeyCode.A then controls.L = -1 end
            if input.KeyCode == Enum.KeyCode.D then controls.R = 1 end
        end)

        flyConns[#flyConns+1] = UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then controls.F = 0 end
            if input.KeyCode == Enum.KeyCode.S then controls.B = 0 end
            if input.KeyCode == Enum.KeyCode.A then controls.L = 0 end
            if input.KeyCode == Enum.KeyCode.D then controls.R = 0 end
        end)

        spawn(function()
            while flying and char.Parent do
                local cam = workspace.CurrentCamera
                local moveVec = (cam.CFrame.LookVector * (controls.F + controls.B) + cam.CFrame.RightVector * (controls.R + controls.L))

                if moveVec.Magnitude > 0 then
                    speed = math.clamp(speed + 2, 0, maxSpeed)
                else
                    speed = math.clamp(speed - 4, 0, maxSpeed)
                end

                bv.Velocity = moveVec.Unit * speed
                bg.CFrame = cam.CFrame

                RunService.Heartbeat:Wait()
            end
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            hum.PlatformStand = false
        end)
    end

    local function stopFly()
        flying = false
    end

    local function toggleFly()
        flying = not flying
        setSwitch(flying)
        if flying then
            startFly()
        else
            stopFly()
        end
    end

    switch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleFly()
        end
    end)

    setSwitch(false)
end

return Fly
