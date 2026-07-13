--// extremely fast animation data extractor //

local next = next
local assert = assert
local table_insert = table.insert
local table_clear = table.clear
local table_unpack = table.unpack
local table_sort = table.sort

local AnimationDatas = {}

local GetValueFromCurve = function(Curve, Time)
	if not Curve then
		return nil
	end
	if Curve:IsA("Vector3Curve") then
		local X, Y, Z = table_unpack(Curve:GetValueAtTime(Time))
		return vector.create(X or 0, Y or 0, Z or 0)
	elseif Curve:IsA("EulerRotationCurve") then
		return Curve:GetRotationAtTime(Time)
	end
end

local GetAncestorKeyframe = function(Instance)
	local Current = Instance.Parent
	while Current and not Current:IsA("Keyframe") do
		Current = Current.Parent
	end
	return Current
end

return function(Name, Sequence)
	assert(Sequence, "Attempt to get Animation Data from invalid Animation")
	
	if next(AnimationDatas) then
		for _, Data in next, AnimationDatas do
			if Data.Name == Name then
				return Data
			end
		end
	end
	
	AnimationData = {
		Name = Name,
		Length = 0,
		Keyframes = {},
		Metadata = {}
	}
	table_insert(AnimationDatas, AnimationData)
	
	if Sequence:IsA("KeyframeSequence") then
		local MaxTime = 0
		local KeyframeLookup = {}
		for _, KeyframeInstance in next, Sequence:QueryDescendants(">Keyframe") do
			local Time = KeyframeInstance.Time
			if Time > MaxTime then
				MaxTime = Time
			end
			
			local KeyframeData = {
				Time = Time,
				Poses = {}
			}
			
			local Markers = KeyframeInstance:QueryDescendants(">KeyframeMarker")
			if next(Markers) then
				KeyframeData.Markers = {}
				for _, Marker in next, Markers do
					table_insert(KeyframeData.Markers, {Name = Marker.Name, Value = Marker.Value})
				end
			end
			
			KeyframeLookup[KeyframeInstance] = KeyframeData
			table_insert(AnimationData.Keyframes, KeyframeData)
		end
		
		for _, Pose in next, Sequence:QueryDescendants("Pose") do
			local KeyframeInstance = GetAncestorKeyframe(Pose)
			local KeyframeData = KeyframeLookup[KeyframeInstance]
			if not KeyframeData then
				continue
			end
			
			local ParentPose = Pose.Parent
			local Part1Name = Pose.Name
			local Part0Name = (ParentPose:IsA("Pose") and ParentPose.Name) or nil
			
			table_insert(KeyframeData.Poses, {
				Part0 = Part0Name,
				Part1 = Part1Name,
				EasingStyle = Pose.EasingStyle.Name,
				EasingDirection = Pose.EasingDirection.Name,
				CFrame = Pose.CFrame
			})
		end
		
		table_sort(AnimationData.Keyframes, function(a, b)
			return a.Time < b.Time
		end)
		
		AnimationData.Length = MaxTime
		AnimationData.Metadata.KeyframeCount = #AnimationData.Keyframes
		AnimationData.Metadata.TotalPoses = 0
		for _, Keyframe in next, AnimationData.Keyframes do
			if Keyframe.Poses and next(Keyframe.Poses) then
				AnimationData.Metadata.TotalPoses += #Keyframe.Poses
			end
		end
	elseif Sequence:IsA("CurveAnimation") then
		local MaxTime = 0
		local KeyframeMap = {}
		
		local AddTimes = function(Curve)
			if not Curve then
				return
			end
			
			for _, Axis in next, {"X", "Y", "Z"} do
				for _, Key in next, Curve[Axis](Curve):GetKeys() do
					KeyframeMap[Key.Time] = KeyframeMap[Key.Time] or {
						Time = Key.Time,
						Poses = {}
					}
				end
			end
		end
		
		for _, Track in next, Sequence:QueryDescendants("Folder:has(Vector3Curve, EulerRotationCurve)") do
			local Vector3Curve = Track:FindFirstChildOfClass("Vector3Curve")
			local EulerRotationCurve = Track:FindFirstChildOfClass("EulerRotationCurve")
			
			AddTimes(Vector3Curve)
			AddTimes(EulerRotationCurve)
			
			for _, Keyframe in next, KeyframeMap do
				local Time = Keyframe.Time

				local Position = GetValueFromCurve(Vector3Curve, Time)
				local Rotation = GetValueFromCurve(EulerRotationCurve, Time)
				
				local ParentTrack = Track.Parent
				local Part1Name = Track.Name
				local Part0Name = (ParentTrack ~= Sequence and ParentTrack.Name) or nil
				
				local PoseData = {
					Part0 = Part0Name,
					Part1 = Part1Name,
					CFrame = Rotation + Position,
					EasingStyle = "Linear",
					EasingDirection = "In"
				}
				
				table_insert(Keyframe.Poses, PoseData)

				if Time > MaxTime then
					MaxTime = Time
				end
			end
		end
		
		local Times = {}
		for Time in next, KeyframeMap do
			table_insert(Times, Time)
		end
		table_sort(Times)
		
		for _, Time in next, Times do
			local Keyframe = KeyframeMap[Time]
			table_insert(AnimationData.Keyframes, Keyframe)
		end

		AnimationData.Length = MaxTime
		AnimationData.Metadata.KeyframeCount = #AnimationData.Keyframes
		AnimationData.Metadata.TotalPoses = 0

		for _, Keyframe in next, AnimationData.Keyframes do
			AnimationData.Metadata.TotalPoses += #Keyframe.Poses
		end
	end
	
	return AnimationData
end
