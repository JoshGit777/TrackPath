local TrackPath = {}

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

TrackPath.__index = TrackPath

export type TrackSettings = {
	ComputationDelay: number,
	MaximumDirectDistance: number,
	HeightTolerance: number,
}

export type TrackPath = {
	TrackSettings: TrackSettings,
	Model: Model,
	Primary: BasePart,
	Humanoid: Humanoid,
	MoveFunction: (self: TrackPath, Position: Vector3) -> nil,
	JumpFunction: (self:TrackPath) -> nil,
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
	LastWaypoint: PathWaypoint,
	LastJumpedWaypoint: PathWaypoint,

	Move: (self: TrackPath, Position: Vector3) -> nil,
	Jump: (self:TrackPath) -> nil,
	ComputeWaypoints: (self: TrackPath, Destination: Vector3) -> nil,
	DirectMove: (self: TrackPath, Destination: Model | Vector3) -> nil,
	Pathfind: (self: TrackPath, Destination: Model | Vector3) -> nil,
	Run: (self: TrackPath, Destination: Vector3 | Model) -> nil,
    End: (self:TrackPath) -> nil,
    Destroy: (self:TrackPath) -> nil,

	_ReachedRef: BindableEvent,
	Reached: RBXScriptSignal,
}

function TrackPath.create(Model, MoveFunction: ((self: TrackPath, Position: Vector3) -> nil)?, JumpFunction: ((self:TrackPath) -> nil)?): TrackPath
	local self: TrackPath = setmetatable({} :: any, TrackPath)
	self.Model = Model
	self.Primary = Model.PrimaryPart

	if not self.Primary then
		error("Primary Part Not Found")
	end

	self.Humanoid = Model:FindFirstChildOfClass("Humanoid") :: Humanoid

	if not self.Humanoid then
		self.MoveFunction = MoveFunction :: (self: TrackPath, Position: Vector3) -> nil

		self.JumpFunction = JumpFunction :: (self:TrackPath) -> nil

		self.MoveFinishedEvent = Instance.new("BindableEvent")
	end

	self.Path = PathfindingService:CreatePath()

	if self.Humanoid then
		self.MoveCompleteConnection = self.Humanoid.MoveToFinished
	else
		self.MoveCompleteConnection = self.MoveFinishedEvent.Event
	end
	
	self._ReachedRef = Instance.new("BindableEvent")

	self.Reached = self._ReachedRef.Event

	self.TrackSettings = {
		ComputationDelay = 0.25,
		MaximumDirectDistance = 100,
		HeightTolerance = 4,
	}

	self.LastComputation = 0
	self.WaypointNumber = 2

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

function TrackPath.Jump(self:TrackPath)
	if self.Humanoid then
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	else
		self.JumpFunction(self)
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

		local Waypoint: PathWaypoint

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
			Waypoint = self.Path:GetWaypoints()[WaypointNumber]

			if Waypoint then
				self.PathPosition = Waypoint.Position
			end
		end

		self:Move(self.PathPosition)

		if Waypoint and Waypoint.Action == Enum.PathWaypointAction.Jump then
			if Waypoint ~= self.LastJumpedWaypoint then
				self:Jump()
				self.LastJumpedWaypoint = Waypoint
			end
		end

		if Waypoint then
			self.LastWaypoint = Waypoint
		end
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

	local TrackSettings = self.TrackSettings

	local MaximumDistance = TrackSettings.MaximumDirectDistance

	self.UpdateConnection = RunService.Heartbeat:Connect(function()

		if not self.Primary then
			self:Destroy()
		end

		local DestinationPosition: Vector3 = nil
		local YTolerance = self.TrackSettings.HeightTolerance

		if typeof(Destination) == "Vector3" then
			DestinationPosition = Destination :: Vector3
		elseif Destination:IsA("Model") then
			local DestinationPrimary = Destination.PrimaryPart :: BasePart
			DestinationPosition = DestinationPrimary.Position
		else
			error("DESTINATION MUST BE EITHER A VECTOR 3 OR A MODEL")
		end

		local PartDirection = (DestinationPosition - self.Primary.Position)
		local Result = Workspace:Blockcast(self.Primary.CFrame, self.Primary.Size, PartDirection, Params)

		local PartDistance = (DestinationPosition - self.Primary.Position).Magnitude
		local DestinationHit = nil

		if PartDistance < 2 then
			self._ReachedRef:Fire()
		end

		if Result and typeof(Destination) == "Instance" and Destination:IsA("Model") then
			DestinationHit = Result.Instance and Result.Instance:IsDescendantOf(Destination) or false
		else
			DestinationHit = false
		end

		local YDistance = DestinationPosition.Y - self.Primary.Position.Y

		if Result and (Result.Instance == nil or DestinationHit) and PartDistance <= MaximumDistance and YDistance <= YTolerance then
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
    
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
	end
	
    if self.DirectConnection then
        self.DirectConnection:Disconnect()
    end

    if self.PathUpdateConnection then
        self.PathUpdateConnection:Disconnect()
        self.PathfindConnection:Disconnect()
    end
end

function TrackPath.Destroy(self:TrackPath)
	self:End()
	
	for index, _ in pairs(self) do
		self[index] = nil
	end

	setmetatable(self, nil)

	table.freeze(self)

	self = nil :: any
end

return TrackPath
