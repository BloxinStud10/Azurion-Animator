--!optimize 2
--[=[
	Animation Controller
	
	Ported from Runtime version of this
	https://raw.githubusercontent.com/BloxinStud10/Azurion-Animator/refs/heads/main/Runtime/Animator.luau
]=]

const global = shared or _G
local ccontainer = rawget(global, "Azurion")
if not ccontainer then
	repeat
		ccontainer = rawget(global, "Azurion")
		wait()
	until ccontainer
end

local waitForModule = rawget(rawget(ccontainer, "functions"), "waitForModule")
const CreateSignal = waitForModule("Signal")
const TweenFunctions = waitForModule("EasingFunctions").EasingFunctions

const game = game
const setmetatable = setmetatable
const tostring = tostring
const next = next
const assert = assert
const Enum = Enum
const type = type
const typeof = typeof
const osclock = os.clock
const table_insert = table.insert
const table_clear = table.clear
const table_sort = table.sort
const math_min = math.min
const math_clamp = math.clamp
const math_sin = math.sin
const math_cos = math.cos
const math_sqrt = math.sqrt
const math_exp = math.exp
const math_abs = math.abs
const math_lerp = math.lerp

const CFrame_identity = CFrame.identity
const Lerp = CFrame_identity.Lerp

const RunService = game:GetService("RunService")
const PreAnimation = RunService.PreAnimation

const AnimationPriority = Enum.AnimationPriority
const GetPriorityValue = @native function(priority)
	if type(priority) == "number" then
		return priority
	end
	if typeof(priority) == "EnumItem" and priority.EnumType == AnimationPriority then
		return priority.Value
	end
	return 0
end

--// AnimationTrack //
local AnimationTrack = {}
AnimationTrack.__index = AnimationTrack

AnimationTrack.AdjustSpeed = @native function(self, speed)
	self.Speed = speed or 1
end

AnimationTrack.AdjustWeight = @native function(self, weight, fadeTime)
	self.WeightTarget = weight or 1
	self.FadeTime = fadeTime or 0.100000001
end

AnimationTrack.GetMarkerReachedSignal = @native function(self, name)
	local Event = self._markerReachedSignals[name]
	if not Event then
		Event = CreateSignal()
		self._markerReachedSignals[name] = Event
	end
	return Event
end

AnimationTrack.GetTimeOfKeyframe = @native function(self, keyframeName)
	return self._keyframeTimes[keyframeName] or warn("Could not find a keyframe by that name!")
end

AnimationTrack._findTimelineIndex = @native function(self, timeline, cachedIndex, t)
	local hi = #timeline
	if t <= timeline[1].Time then
		return 1
	end
	if t >= timeline[hi].Time then
		return hi
	end
	if cachedIndex and cachedIndex >= 1 and cachedIndex < hi
		and timeline[cachedIndex].Time <= t and timeline[cachedIndex + 1].Time > t then
		return cachedIndex
	end
	local lo = 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if timeline[mid].Time <= t then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

AnimationTrack._easedAlpha = @native function(self, alpha, style, direction)
	local func = TweenFunctions[style or "Linear"][direction or "In"]
	return func(alpha)
end

AnimationTrack.GetPoseAt = @native function(self, t)
	local result = {joints = {}, root = nil}
	local jointCache = self._jointCache

	for part1Name, timeline in self._jointTimelines do
		local n = #timeline
		local i1 = self:_findTimelineIndex(timeline, jointCache[part1Name], t)
		jointCache[part1Name] = i1
		local i2 = math_min(i1 + 1, n)

		local e1, e2 = timeline[i1], timeline[i2]
		local span = e2.Time - e1.Time
		local alpha = span > 0 and math_clamp((t - e1.Time) / span, 0, 1) or 0
		local eased = self:_easedAlpha(alpha, e1.EasingStyle, e1.EasingDirection)

		result.joints[part1Name] = Lerp(e1.CFrame, e2.CFrame, eased)
	end

	local rootTimeline = self._rootTimeline
	local rn = #rootTimeline
	if rn > 0 then
		local i1 = self:_findTimelineIndex(rootTimeline, self._rootCache, t)
		self._rootCache = i1
		local i2 = math_min(i1 + 1, rn)

		local e1, e2 = rootTimeline[i1], rootTimeline[i2]
		local span = e2.Time - e1.Time
		local alpha = span > 0 and math_clamp((t - e1.Time) / span, 0, 1) or 0
		local eased = self:_easedAlpha(alpha, e1.EasingStyle, e1.EasingDirection)

		result.root = Lerp(e1.CFrame, e2.CFrame, eased)
	end

	return result
end

AnimationTrack._step = @native function(self, dt)
	if self._fadeDuration <= 0 then
		self.WeightCurrent = self._fadeTarget
	else
		self._fadeElapsed += dt
		local alpha = math_clamp(self._fadeElapsed / self._fadeDuration, 0, 1)
		self.WeightCurrent = math_lerp(self._fadeStart, self._fadeTarget, alpha)
		if alpha >= 1 then
			self.WeightCurrent = self._fadeTarget
			self._fadeDuration = 0
		end
	end
	
	local prevTime = self._lastTimePosition
	self.TimePosition += dt * self.Speed
	if self.IsPlaying and next(self._markers) then
		for markerIndex, marker in self._markers do
			if prevTime < marker.Time and marker.Time <= self.TimePosition then
				local signal = self._markerReachedSignals[marker.Name]
				if signal then
					signal:Fire(marker.Value)
				end
				self._firedMarkers[markerIndex] = true
			end
		end
	end

	if self.TimePosition >= self.Length then
		if self.Looped then
			self.TimePosition = self.Length > 0 and (self.TimePosition % self.Length) or 0
			self.DidLoop:Fire()
			table_clear(self._firedMarkers)
		else
			self.TimePosition = self.Length
			if not self._stopping then
				self._stopping = true
				self._fadeStart = self.WeightCurrent
				self._fadeElapsed = 0
				self._fadeTarget = 0
				self._fadeDuration = self.FadeTime > 0 and self.FadeTime or 0.15
			end
		end
	end

	if self._stopping and self.WeightCurrent <= 0 then
		self.IsPlaying = false
		self.TimePosition = 0
		self.Stopped:Fire()
		self.Ended:Fire()
		table_clear(self._firedMarkers)
	end
	
	self._lastTimePosition = self.TimePosition
end


AnimationTrack.Play = @native function(self, fadeTime, weight, speed)
	fadeTime = fadeTime or 0.100000001
	weight = weight or self.Weight or 1
	speed = speed or 1

	self.Weight = weight
	self.Speed = speed

	self._fadeStart = self.WeightCurrent
	self._fadeElapsed = 0
	self._fadeTarget = weight
	self._fadeDuration = fadeTime
	self._stopping = false

	if self.IsPlaying then
		self:_step(0)
	else
		self.IsPlaying = true
		self.TimePosition = 0
	end
end

AnimationTrack.Stop = @native function(self, fadeTime)
	fadeTime = fadeTime or 0.100000001

	if not self.IsPlaying then
		return
	end

	if fadeTime <= 0 then
		self.WeightCurrent = 0
		self._fadeTarget = 0
		self.IsPlaying = false
		self.TimePosition = 0
		self.Stopped:Fire()
		self.Ended:Fire()
		return
	end

	self._fadeStart = self.WeightCurrent
	self._fadeElapsed = 0
	self._fadeTarget = 0
	self._fadeDuration = fadeTime
	self._stopping = true
end

AnimationTrack.GetTimePosition = function(self)
	return self.TimePosition
end

AnimationTrack.SetTimePosition = function(self, t)
	self.TimePosition = math_clamp(t, 0, self.Length)
	
	local controller = self.AnimationController
	if not self.IsPlaying and controller then
		local pose = self:GetPoseAt(self.TimePosition)
	
		for part1Name, cframe in pose.joints do
			local motor = controller._motorByPart1[part1Name]
			if motor then
				if controller._motorUsesTransform[part1Name] then
					motor.Transform = cframe
				else
					motor.C0 = controller._motorRestC0[part1Name] * cframe
				end
			end
		end
	
		if pose.root and controller._options.ApplyRootMotion and controller.RootPart then
			controller.RootPart.CFrame = controller.RootBaseCFrame * pose.root
		end
	end
end

AnimationTrack.Destroy = function(self)
	self:Stop(0)
	self.Ended:Destroy()
	self.Stopped:Destroy()
	self.DidLoop:Destroy()
	for _, signal in next, self._markerReachedSignals do
		signal:Destroy()
	end
	
	table_clear(self._markers)
	table_clear(self._firedMarkers)
	table_clear(self)
	setmetatable(self, nil)
end

@native function AnimationTrack.new(controller, data)
	assert(controller, "AnimationTrack: AnimationController is required")
	assert(data and data.Keyframes, "AnimationTrack: Invalid animation data")

	local self = setmetatable({}, AnimationTrack)

	self.AnimationController = controller
	self.Name = data.Name or "AnimationTrack"
	self.Length = data.Length or (data.Keyframes[#data.Keyframes] and data.Keyframes[#data.Keyframes].Time) or 0

	self.IsPlaying = false
	self.Looped = data.Loop or false
	self.Speed = 1
	self.TimePosition = 0

	self.WeightTarget = 1
	self.WeightCurrent = 0
	self.FadeTime = 0.1

	self.Priority = data.Priority or 0

	self._fadeStart = 0
	self._fadeElapsed = 0
	self._fadeTarget = 0
	self._fadeDuration = 0
	self._stopping = false
		
	self._markers = {}
	self._firedMarkers = {}
	self._lastTimePosition = 0
	
	for _, kf in data.Keyframes do
		if kf.Markers and next(kf.Markers) then
			for _, markerData in kf.Markers do
				table_insert(self._markers, {Time = kf.Time, Name = markerData.Name, Value = markerData.Value})
			end
		end
	end
	table_sort(self._markers, function(a, b)
		return a.Time < b.Time
	end)
	
	local jointTimelines = {}
	local rootTimeline = {}

	for _, kf in data.Keyframes do
		local time = kf.Time
		for _, pose in kf.Poses do
			local entry = {
				Time = time,
				CFrame = pose[3],
				EasingStyle = pose[4],
				EasingDirection = pose[5]
			}
			if pose[1] == nil then
				table_insert(rootTimeline, entry)
			else
				local list = jointTimelines[pose[2]]
				if not list then
					list = {}
					jointTimelines[pose[2]] = list
				end
				table_insert(list, entry)
			end
		end
	end
	self._jointTimelines = jointTimelines
	self._rootTimeline = rootTimeline
	self._jointCache = {}
	self._rootCache = nil

	self.Stopped = CreateSignal()
	self.Ended = CreateSignal()
	self.DidLoop = CreateSignal()
	self._markerReachedSignals = {}

	return self
end

--// AnimationController //
local AnimationController = {}
AnimationController.__index = AnimationController

local AnimationControllers = setmetatable({}, {__mode = "k"})

local trackPartName = function(part, onRenamed)
	return part:GetPropertyChangedSignal("Name"):Connect(function()
		onRenamed(part.Name)
	end)
end

local GetJointParts = @native function(joint)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1
	elseif joint:IsA("AnimationConstraint") then
		local attachment0, attachment1 = joint.Attachment0, joint.Attachment1
		return attachment0 and attachment0.Parent, attachment1 and attachment1.Parent
	end
end

local trackJoint = function(joint, onSet, onUnset)
	local currentPart0Name, currentPart1Name
	local nameConnections = {}

	local clearNameConnections = function()
		for _, connection in nameConnections do
			connection:Disconnect()
		end
		table_clear(nameConnections)
	end

	local unbind = function()
		if currentPart1Name then
			onUnset(currentPart0Name, currentPart1Name)
			currentPart0Name, currentPart1Name = nil, nil
		end
		clearNameConnections()
	end

	local bind = function(part0, part1)
		if not part1 then
			return
		end

		currentPart0Name = part0 and part0.Name or nil
		currentPart1Name = part1.Name
		onSet(currentPart0Name, currentPart1Name, joint)

		table_insert(nameConnections, trackPartName(part1, function(newName)
			onUnset(currentPart0Name, currentPart1Name)
			currentPart1Name = newName
			onSet(currentPart0Name, currentPart1Name, joint)
		end))

		if part0 then
			table_insert(nameConnections, trackPartName(part0, function(newName)
				onUnset(currentPart0Name, currentPart1Name)
				currentPart0Name = newName
				onSet(currentPart0Name, currentPart1Name, joint)
			end))
		end
	end

	local rebind = function()
		unbind()
		local part0, part1 = GetJointParts(joint)
		bind(part0, part1)
	end

	rebind()

	local structureConnections = {}
	if joint:IsA("Motor6D") then
		table_insert(structureConnections, joint:GetPropertyChangedSignal("Part0"):Connect(rebind))
		table_insert(structureConnections, joint:GetPropertyChangedSignal("Part1"):Connect(rebind))
	elseif joint:IsA("AnimationConstraint") then
		table_insert(structureConnections, joint:GetPropertyChangedSignal("Attachment0"):Connect(rebind))
		table_insert(structureConnections, joint:GetPropertyChangedSignal("Attachment1"):Connect(rebind))
	end

	return function()
		for _, connection in structureConnections do
			connection:Disconnect()
		end
		unbind()
	end
end

local UsesTransform = @native function(joint)
	if typeof(joint) == "Instance" then
		return joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")
	end
	return joint.Transform ~= nil
end

local blend = @native function(contributions)
	local blended = nil
	local weightSum = 0

	for _, entry in contributions do
		local cframe, weight = entry[1], entry[2]
		weightSum += weight
		if blended == nil then
			blended = cframe
		else
			blended = Lerp(blended, cframe, weight / weightSum)
		end
	end

	return blended or CFrame_identity
end

AnimationController._step = @native function(self, dt)
	self.Stepped:Fire(dt)

	local rootPriority = nil
	local jointContrib = self._jointContribScratch
	local jointPriority = self._jointPriorityScratch
	local rootContrib = self._rootContribScratch
	table_clear(jointContrib)
	table_clear(jointPriority)
	table_clear(rootContrib)

	local anyPlaying = false

	for _, track in self._tracks do
		if track.IsPlaying then
			anyPlaying = true
			track:_step(dt)

			local weight = track.WeightCurrent
			if weight > 0 then
				local priority = GetPriorityValue(track.Priority)
				local pose = track:GetPoseAt(track.TimePosition)

				for part1Name, cframe in pose.joints do
					local currentPriority = jointPriority[part1Name]

					if currentPriority == nil or priority > currentPriority then
						jointPriority[part1Name] = priority
						jointContrib[part1Name] = {
							{cframe, weight}
						}
					elseif priority == currentPriority then
						table_insert(jointContrib[part1Name], {cframe, weight})
					end
				end

				if pose.root then
					if rootPriority == nil or priority > rootPriority then
						rootPriority = priority
						rootContrib = {
							{self.RootBaseCFrame * pose.root, weight}
						}
					elseif priority == rootPriority then
						table_insert(rootContrib, {self.RootBaseCFrame * pose.root, weight})
					end
				end
			end
		end
	end

	if not anyPlaying then
		return
	end

	for part1Name, motor in self._motorByPart1 do
		local contributions = jointContrib[part1Name]
		local pose = contributions and blend(contributions) or CFrame_identity

		if self._motorUsesTransform[part1Name] then
			motor.Transform = pose
		else
			motor.C0 = self._motorRestC0[part1Name] * pose
		end
	end

	if self._options.ApplyRootMotion and self.RootPart then
		self.RootPart.CFrame = #rootContrib > 0 and blend(rootContrib) or self.RootBaseCFrame
	end
end

function AnimationController:ResetRootBase()
	self.RootBaseCFrame = self.RootPart and self.RootPart.CFrame or CFrame_identity
end

AnimationController.LoadAnimation = @native function(self, data)
	local track = AnimationTrack.new(self, data)
	table_insert(self._tracks, track)
	return track
end

AnimationController.GetPlayingAnimationTracks = @native function(self)
	local tracks = {}
	for _, track in self._tracks do
		if track.IsPlaying then
			table_insert(tracks, track)
		end
	end
	return tracks
end

function AnimationController.new(config)
	if typeof(config) == "Instance" then
		config = {Rig = config}
	else
		config = config or {}
	end
	local rig = config.Rig
	local joints = config.Joints

	local isRealRig = rig and typeof(rig) == "Instance"
	assert(rig ~= nil or joints ~= nil, "AnimationController.new: config.Rig or config.Joints is required")

	if isRealRig then
		local existing = AnimationControllers[rig]
		if existing then
			return existing
		end
	end

	local self = setmetatable({}, AnimationController)

	self.Rig = rig
	self.RootPart = config.RootPart or (isRealRig and (rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")))

	self.RootBaseCFrame = self.RootPart and self.RootPart.CFrame or CFrame_identity
	
	self._options = config
	self._destroyed = false
	self._tracks = {}
	self._motorByPart1 = {}
	self._joints = {}
	self._jointTrackers = {}
	self._connections = {}
	
	self._jointContribScratch = {}
	self._jointPriorityScratch = {}
	self._rootContribScratch = {}
	self._motorUsesTransform = {}
	self._motorRestC0 = {}

	self.Stepped = CreateSignal()
	local registerMotor = function(part1Name, joint)
		self._motorByPart1[part1Name] = joint

		local usesTransform = UsesTransform(joint)
		self._motorUsesTransform[part1Name] = usesTransform
		if not usesTransform then
			local ok, restC0 = pcall(function()
				return joint.C0
			end)
			self._motorRestC0[part1Name] = (ok and restC0) or CFrame_identity
		end
	end

	local onJointAdded = function(joint)
		if self._jointTrackers[joint] then
			return
		end
		self._joints[joint] = true
		self._jointTrackers[joint] = trackJoint(joint, function(part0Name, part1Name, j)
			registerMotor(part1Name, j)
		end, function(part0Name, part1Name)
			if self._motorByPart1[part1Name] == joint then
				self._motorByPart1[part1Name] = nil
				self._motorUsesTransform[part1Name] = nil
				self._motorRestC0[part1Name] = nil
			end
		end)
	end

	local onJointRemoving = function(joint)
		local stopTracker = self._jointTrackers[joint]
		if stopTracker then
			stopTracker()
			self._jointTrackers[joint] = nil
		end
		self._joints[joint] = nil
	end

	if isRealRig then
		for _, inst in rig:QueryDescendants("Motor6D, AnimationConstraint") do
			onJointAdded(inst)
		end
		table_insert(self._connections, rig.DescendantAdded:Connect(function(inst)
			if inst:IsA("Motor6D") or inst:IsA("AnimationConstraint") then
				onJointAdded(inst)
			end
		end))
		table_insert(self._connections, rig.DescendantRemoving:Connect(function(inst)
			if inst:IsA("Motor6D") or inst:IsA("AnimationConstraint") then
				onJointRemoving(inst)
			end
		end))
	end

	if joints then
		for key, jointObject in next, joints do
			local part1Name = key[2]
			if part1Name then
				registerMotor(part1Name, jointObject)
			end
		end
	end

	self._lastClock = osclock()
	self._preanimationConnection = PreAnimation:Connect(function()
		local now = osclock()
		local dt = now - self._lastClock
		self._lastClock = now
		self:_step(dt)
	end)

	if isRealRig then
		AnimationControllers[rig] = self
	end

	return self
end

AnimationController.Destroy = @native function(self)
	assert(self, "AnimationController not found")
	assert(not self._destroyed, "Cannot destroy already destroyed AnimationController")
	self._destroyed = true

	if self._preanimationConnection then
		self._preanimationConnection:Disconnect()
		self._preanimationConnection = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, stopTracker in self._jointTrackers do
		stopTracker()
	end
	for _, track in self._tracks do
		track:Destroy()
	end

	self.Stepped:Destroy()
	if AnimationControllers[self.Rig] == self then
		AnimationControllers[self.Rig] = nil
	end

	table_clear(self._tracks)
	table_clear(self._joints)
	table_clear(self._jointTrackers)
	table_clear(self._connections)
	table_clear(self._motorByPart1)
	table_clear(self._motorUsesTransform)
	table_clear(self._motorRestC0)

	table_clear(self)
	setmetatable(self, nil)
end

AnimationController._controllers = AnimationControllers

return AnimationController