local Module = {}
local PathfindingService = game:GetService("PathfindingService")

local MAX_ROAM_ATTEMPTS = 5
local DEFAULT_UPDATE_TIME = 2

local Thresholds = {
    {dist = 8,  interval = 0.1},
    {dist = 15, interval = 0.35},
    {dist = 40, interval = 1.0},
}

local function CalculateUpdateTime(distance)
    for _, config in ipairs(Thresholds) do
        if distance <= config.dist then
            return config.interval
        end
    end
    return DEFAULT_UPDATE_TIME
end

local function StopCurrentThread(entity)
    if entity.Thread then
        task.cancel(entity.Thread)
        entity.Thread = nil
    end
end

local function FollowWaypoints(entity, waypoints)
    local humanoid = entity.Character:FindFirstChildOfClass("Humanoid")
    local root = entity.Character.PrimaryPart
    
    StopCurrentThread(entity)

    entity.Thread = task.spawn(function()
        for i = 2, #waypoints do
            local wp = waypoints[i]
            
            humanoid:MoveTo(wp.Position)
            
            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            
            local reached = false
            local connection
            connection = humanoid.MoveToFinished:Connect(function()
                reached = true
            end)

           
            local start = os.clock()
            repeat task.wait() until reached or (os.clock() - start) > 1
            
            if connection then connection:Disconnect() end
            
         
            if (os.clock() - start) > 1 then
                humanoid.Jump = true
            end
        end
    end)
end

function Module.CreateChase(character, agentRadius, canJump, range, costs, canRoam)
    local path = PathfindingService:CreatePath({
        AgentRadius = agentRadius or 3,
        AgentCanJump = canJump or false,
        Costs = costs or {}
    })

    local entity = {
        Character = character,
        Path = path,
        Range = range or math.huge,
        CanRoam = canRoam or false,
        Target = nil,
        Thread = nil
    }

    -- Set Network to server (Evita lag de interpolação)
    local root = character:WaitForChild("HumanoidRootPart")
    root:SetNetworkOwner(nil)

    -- Loop
    task.spawn(function()
        while character.Parent do
            local target = entity.Target
            local targetPos = nil

            
            if typeof(target) == "Instance" and target:IsA("BasePart") then
                targetPos = target.Position
            elseif typeof(target) == "Vector3" then
                targetPos = target
            end

            if targetPos then
                local dist = (root.Position - targetPos).Magnitude
                if dist <= entity.Range then
                    local success, err = pcall(function()
                        path:ComputeAsync(root.Position, targetPos)
                    end)

                    if success and path.Status == Enum.PathStatus.Success then
                        FollowWaypoints(entity, path:GetWaypoints())
                        task.wait(CalculateUpdateTime(dist))
                        continue
                    end
                end
            end

            if entity.CanRoam then
                -- Well...
                task.wait(1)
            else
                task.wait(0.5)
            end
        end
    end)

    return entity
end

return Module
