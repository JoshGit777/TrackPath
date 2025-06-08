--[[ if not game:IsLoaded() then
    game.Loaded:Wait()
end ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local TrackPath = require(Shared:WaitForChild("TrackPath"))

local NewPath = TrackPath.create(game.Workspace:WaitForChild("bigboibob"))

local SmolBoiBob = workspace:WaitForChild("smolboibob")

NewPath:Run(SmolBoiBob)
