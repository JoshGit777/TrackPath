--[[ if not game:IsLoaded() then
    game.Loaded:Wait()
end ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local TrackPath = require(Shared:WaitForChild("TrackPath"))

local NewPath = TrackPath.create(game.Workspace:WaitForChild("bigboibob"))

local SmolBoiBob = workspace:WaitForChild("smolboibob")


local ActiveReporterThread = nil

game.Workspace:GetAttributeChangedSignal("PathActive"):Connect(function()
    local Value = game.Workspace:GetAttribute("PathActive")
    if Value then
        NewPath:Run(SmolBoiBob)

        if not ActiveReporterThread then
            ActiveReporterThread = task.spawn(function()
                while task.wait(0.1) do
                    print(NewPath.Mode)
                end
            end)    
        end

    else
        task.cancel(ActiveReporterThread)
        NewPath:End()
    end
end)
