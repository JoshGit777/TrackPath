local TrackPath = {}
local PathfindingService = game:GetService("PathfindingService")

TrackPath.__index = TrackPath

export type TrackPath = {
	Model: Model,
	Humanoid: Humanoid,
	MoveFunction: (self: TrackPath, Position: Vector3) -> nil,
	MoveFinishedEvent: BindableEvent,
	Path: Path,
	Waypoints: { PathWaypoint },
    AgentParameters: {},
}

function TrackPath.create(Model, MoveFunction: ((self: TrackPath, Position: Vector3) -> nil)?)
	local self: TrackPath = setmetatable({} :: any, TrackPath)
	self.Model = Model
	self.Humanoid = Model:FindFirstChildOfClass("Humanoid") :: Humanoid

	if not self.Humanoid then
		self.MoveFunction = MoveFunction :: (self: TrackPath, Position: Vector3) -> nil
	end

	self.Path = PathfindingService:CreatePath()
end

function TrackPath.SetAgentParameters(self:TrackPath, AgentParameters: {})
    self.AgentParameters = AgentParameters
    self.Path = PathfindingService:CreatePath(AgentParameters)
end


return TrackPath
