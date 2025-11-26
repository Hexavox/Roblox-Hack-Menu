-- ULTRA AUTO-FIND PATHFINDER
-- [ = toggle auto-find on/off
-- Uses Name / ClassName / FullName / Ancestry filters (no attributes).
-- Draws a white tracer along waypoints.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

----------------------------------------------------
-- CONFIG: WHAT COUNTS AS A "TARGET"
----------------------------------------------------
-- Set these to match what the INSPECTOR shows for your desired drops.
-- Leave a field nil to ignore it.
local TARGET_FILTERS = {
    Name = "Drop",                    -- exact Name match, or nil
    Class = "Model",                  -- exact ClassName match, or nil
    FullNameContains = "Workspace.Drops",   -- substring of GetFullName(), or nil
    AncestryContains = "Map -> Drops"       -- substring of ancestry path, or nil
}

-- If you don't care about some filters, just set them to nil, e.g.:
-- TARGET_FILTERS = { Name = "Drop" }

-- Scan interval for finding new targets
local SCAN_INTERVAL = 5

-- Distance considered "close enough" to stop and try E
local ARRIVE_DISTANCE = 8

-- Time to wait after respawning before moving
local RESPAWN_WAIT = 1.5

----------------------------------------------------
-- INTERNAL STATE
----------------------------------------------------

local autoEnabled = false
local badTargets = {}         -- [Instance] = true for targets that repeatedly failed

local currentPathParts = {}

----------------------------------------------------
-- HELPERS: COMMON
----------------------------------------------------

local function getCharacter()
    local char = player.Character
    if not char or not char.Parent then
        char = player.CharacterAdded:Wait()
    end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
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

local function matchesInfo(inst, filters)
    if filters.Name and inst.Name ~= filters.Name then
        return false
    end
    if filters.Class and inst.ClassName ~= filters.Class then
        return false
    end
    if filters.FullNameContains then
        local fn = inst:GetFullName()
        if not string.find(fn, filters.FullNameContains, 1, true) then
            return false
        end
    end
    if filters.AncestryContains then
        local anc = getAncestryPath(inst)
        if not string.find(anc, filters.AncestryContains, 1, true) then
            return false
        end
    end
    return true
end

local function clearPathVisual()
    for _, p in ipairs(currentPathParts) do
        p:Destroy()
    end
    table.clear(currentPathParts)
end

local function drawPath(waypoints)
    clearPathVisual()
    for i = 1, #waypoints - 1 do
        local a = waypoints[i].Position
        local b = waypoints[i + 1].Position
        local mid = (a + b) / 2
        local dist = (a - b).Magnitude

        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.new(1, 1, 1)
        part.Size = Vector3.new(0.2, 0.2, dist)
        part.CFrame = CFrame.new(mid, b)
        part.Parent = workspace
        table.insert(currentPathParts, part)
    end
end

----------------------------------------------------
-- FIND NEAREST TARGET BY BASIC INFO
----------------------------------------------------

local function getTargetPosition(inst)
    if not inst then return nil end

    if inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Model") then
        local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
        if pp then
            return pp.Position
        end
    end

    return nil
end

local function getNearestTarget()
    local char, hum, root = getCharacter()
    if not root then return nil, nil end

    local origin = root.Position
    local bestInst, bestDist

    for _, inst in ipairs(workspace:GetDescendants()) do
        if not badTargets[inst] and matchesInfo(inst, TARGET_FILTERS) then
            local pos = getTargetPosition(inst)
            if pos then
                local d = (pos - origin).Magnitude
                if not bestDist or d < bestDist then
                    bestDist = d
                    bestInst = inst
                end
            end
        end
    end

    return bestInst, bestDist
end

----------------------------------------------------
-- OPTIONAL "LEARNING"
-- If a target fails too often (no path / stuck), mark it as bad so we skip it later.
----------------------------------------------------

local function markTargetBad(inst)
    if inst then
        badTargets[inst] = true
    end
end

----------------------------------------------------
-- PRESS E / TRIGGER PROXIMITYPROMPT
----------------------------------------------------

local function tryPressE()
    -- Generic logic: trigger any nearby ProximityPrompt
    local char, hum, root = getCharacter()
    if not root then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parentPart = obj.Parent
            if parentPart and parentPart:IsA("BasePart") then
                local d = (parentPart.Position - root.Position).Magnitude
                if d <= (obj.MaxActivationDistance + 2) then
                    pcall(function()
                        fireproximityprompt(obj)
                    end)
                end
            end
        end
    end
end

----------------------------------------------------
-- PATHFOLLOW + RESET CHARACTER OPTION
----------------------------------------------------

local function distanceFromSpawnToTarget(targetPos)
    -- crude guess: use current spawn location as your humanoid root after respawn
    -- This is approximate; if the game uses custom spawns this still often helps.
    local char, hum, root = getCharacter()
    if not root then return math.huge end

    local spawnPos = root.Position  -- best we can do client-side; game-specific would be better
    return (targetPos - spawnPos).Magnitude
end

local function followPathTo(targetInst)
    local char, hum, root = getCharacter()
    if not hum or not root then return false end

    local targetPos = getTargetPosition(targetInst)
    if not targetPos then return false end

    -- Decide whether to reset character if that seems shorter
    local distNow = (targetPos - root.Position).Magnitude
    local distFromSpawn = distanceFromSpawnToTarget(targetPos)

    if distFromSpawn + 5 < distNow then
        -- reset character
        hum.Health = 0
        char, hum, root = getCharacter()
        task.wait(RESPAWN_WAIT)
    end

    -- Compute path
    local path = PathfindingService:CreatePath()
    local success = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        markTargetBad(targetInst)
        clearPathVisual()
        return false
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        markTargetBad(targetInst)
        clearPathVisual()
        return false
    end

    drawPath(waypoints)

    for i, wp in ipairs(waypoints) do
        if not autoEnabled then
            clearPathVisual()
            return false
        end

        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end

        hum:MoveTo(wp.Position)
        local reached = hum.MoveToFinished:Wait(2)

        if not reached then
            -- stuck -> mark as bad, bail
            markTargetBad(targetInst)
            clearPathVisual()
            return false
        end
    end

    clearPathVisual()
    -- close enough, try pickup/E
    tryPressE()
    return true
end

----------------------------------------------------
-- MAIN LOOP
----------------------------------------------------

local function autoLoop()
    while autoEnabled do
        local target, dist = getNearestTarget()
        if target and dist then
            followPathTo(target)
        end

        local t = 0
        while autoEnabled and t < SCAN_INTERVAL do
            task.wait(0.2)
            t += 0.2
        end
    end
    clearPathVisual()
end

----------------------------------------------------
-- INPUT BIND
----------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.LeftBracket then -- [
        autoEnabled = not autoEnabled
        if autoEnabled then
            task.spawn(autoLoop)
        else
            clearPathVisual()
        end
    end
end)
