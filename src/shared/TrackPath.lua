local TrackPath = {}

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

TrackPath.__index = TrackPath

export type TrackSettings = {
	ComputationDelay: number,
}

export type TrackPath = {
	TrackSettings: TrackSettings,
	Model: Model,
	Primary: BasePart,
	Humanoid: Humanoid,
	MoveFunction: (self: TrackPath, Position: Vector3) -> nil,
	MoveFinishedEvent: BindableEvent,
	Path: Path,
	Waypoints: { PathWaypoint },
	AgentParameters: {},
	Mode: "Path" | "Direct" | "",
	PathfindConnection: RBXScriptConnection,
	PathUpdateConnection: RBXScriptConnection,
	DirectConnection: RBXScriptConnection,
	UpdateConnection: RBXScriptConnection,
	MoveCompleteConnection: RBXScriptSignal,
	PathPosition: Vector3,
	LastComputation: number,
	WaypointNumber: number,
	IsComputing: boolean,

	Move: (self: TrackPath, Position: Vector3) -> nil,
	ComputeWaypoints: (self: TrackPath, Destination: Vector3) -> nil,
	DirectMove: (self: TrackPath, Destination: Model | Vector3) -> nil,
	Pathfind: (self: TrackPath, Destination: Model | Vector3) -> nil,
	Run: (self: TrackPath, Destination: Vector3 | Model) -> nil,
    End: (self:TrackPath) -> nil,
    Destroy: (self:TrackPath) -> nil
}

function TrackPath.create(Model, MoveFunction: ((self: TrackPath, Position: Vector3) -> nil)?): TrackPath
	local self: TrackPath = setmetatable({} :: any, TrackPath)
	self.Model = Model
	self.Primary = Model.PrimaryPart

	if not self.Primary then
		error("Primary Part Not Found")
	end

	self.Humanoid = Model:FindFirstChildOfClass("Humanoid") :: Humanoid

	if not self.Humanoid then
		self.MoveFunction = MoveFunction :: (self: TrackPath, Position: Vector3) -> nil
		self.MoveFinishedEvent = Instance.new("BindableEvent")
	end

	self.Path = PathfindingService:CreatePath()

	if self.Humanoid then
		self.MoveCompleteConnection = self.Humanoid.MoveToFinished
	else
		self.MoveCompleteConnection = self.MoveFinishedEvent.Event
	end

	self.TrackSettings = {
		ComputationDelay = 0.25,
	}

	self.LastComputation = 0
	self.WaypointNumber = 2

	self.Path.Blocked:Connect(function()
		print("blocked")
	end)

	return self
end

function TrackPath.SetTrackSettings(self: TrackPath, TrackSettings: TrackSettings)
	self.TrackSettings = TrackSettings
end

function TrackPath.SetAgentParameters(self: TrackPath, AgentParameters: {})
	self.AgentParameters = AgentParameters
	self.Path = PathfindingService:CreatePath(AgentParameters)
end

function TrackPath.ComputeWaypoints(self: TrackPath, Destination: Vector3)
	task.spawn(function()
		if not self.IsComputing then
			self.IsComputing = true
			self.Path:ComputeAsync(self.Primary.Position, Destination)
			self.WaypointNumber = math.min(2, #self.Path:GetWaypoints())
			self.IsComputing = false
		end
	end)
end

function TrackPath.Move(self: TrackPath, Position)
	if Position then
		if self.Humanoid then
			self.Humanoid:MoveTo(Position)
		else
			self.MoveFunction(self, Position)
		end
	end
end

function TrackPath.Pathfind(self: TrackPath, Destination: Vector3 | Model)
	local DestinationPosition: Vector3
	local DestinationCanMove

	if typeof(Destination) == "Vector3" then
		DestinationPosition = Destination
	else
		DestinationCanMove = true
	end

	if DestinationCanMove and (typeof(Destination) == "Instance" and Destination:IsA("Model")) then
		local Primary = Destination.PrimaryPart :: BasePart
		DestinationPosition = Primary.Position
	end

	self.PathUpdateConnection = RunService.Heartbeat:Connect(function()

		if self.DirectConnection then
			self.DirectConnection:Disconnect()
		end

		if tick() - self.LastComputation > self.TrackSettings["ComputationDelay"] then
			self:ComputeWaypoints(DestinationPosition)
			self.LastComputation = tick()
		end

		if DestinationCanMove and (typeof(Destination) == "Instance" and Destination:IsA("Model")) then
			local Primary = Destination.PrimaryPart :: BasePart
			DestinationPosition = Primary.Position
		end

		if self.Path.Status == Enum.PathStatus.Success then

            local WaypointNumber = math.min(self.WaypointNumber + 1, #self.Path:GetWaypoints())
			local Waypoint = self.Path:GetWaypoints()[WaypointNumber]

			if Waypoint then
				self.PathPosition = Waypoint.Position
			end
		end

		self:Move(self.PathPosition)
	end)

	self.PathfindConnection = self.MoveCompleteConnection:Connect(function()
		self.WaypointNumber += 1
	end)
end

function TrackPath.DirectMove(self: TrackPath, Destination: Model | Vector3)
	local DestinationPosition: Vector3
	local DestinationCanMove

	if typeof(Destination) == "Vector3" then
		DestinationPosition = Destination
	else
		DestinationCanMove = true
	end

	self.DirectConnection = RunService.Heartbeat:Connect(function()
		if self.PathfindConnection and self.PathUpdateConnection then
			self.WaypointNumber = 2
			self.PathfindConnection:Disconnect()
			self.PathUpdateConnection:Disconnect()
		end

		if DestinationCanMove and (typeof(Destination) == "Instance") then
			local Primary = Destination.PrimaryPart :: BasePart
			DestinationPosition = Primary.Position
		end

		self:Move(DestinationPosition)
	end)
end

function TrackPath.Run(self: TrackPath, Destination: Vector3 | Model)
	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = { self.Model }
	Params.FilterType = Enum.RaycastFilterType.Exclude

	self.Mode = ""

	self.UpdateConnection = RunService.Heartbeat:Connect(function()
		local DestinationPosition: Vector3 = nil

		if typeof(Destination) == "Vector3" then
			DestinationPosition = Destination :: Vector3
		elseif Destination:IsA("Model") then
			local DestinationPrimary = Destination.PrimaryPart :: BasePart
			DestinationPosition = DestinationPrimary.Position
		else
			error("DESTINATION MUST BE EITHER A VECTOR 3 OR A MODEL")
		end

		local PartDirection = DestinationPosition - self.Primary.Position
		local Result = Workspace:Raycast(self.Primary.Position, PartDirection, Params)

		local DestinationHit = nil

		if typeof(Destination) == "Instance" and Destination:IsA("Model") then
			DestinationHit = Result.Instance and Result.Instance:IsDescendantOf(Destination) or false
		else
			DestinationHit = false
		end

		if Result and (Result.Instance == nil or DestinationHit) then
			if self.Mode == "Path" or self.Mode == "" then
				if self.PathfindConnection and self.PathUpdateConnection then
					self.WaypointNumber = 2
					self.PathfindConnection:Disconnect()
					self.PathUpdateConnection:Disconnect()
				end

				self.Mode = "Direct"
				self:DirectMove(Destination)
			end
		else
			if self.Mode == "Direct" or self.Mode == "" then
				if self.DirectConnection then
					self.DirectConnection:Disconnect()
				end

				self:Move(self.Primary.Position)
				self.Mode = "Path"
				self:Pathfind(Destination)
			end
		end
	end)
end

function TrackPath.End(self:TrackPath)
    self.UpdateConnection:Disconnect()
    if self.DirectConnection then
        self.DirectConnection:Disconnect()
    end

    if self.PathUpdateConnection then
        self.PathUpdateConnection:Disconnect()
        self.PathfindConnection:Disconnect()
    end
end

return TrackPath
