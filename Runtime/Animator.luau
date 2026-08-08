--!optimize 2

--[=[
	Universal KeyframeSequence Animator
	A custom animator that emulates Roblox animator but better
	
	Written by Epicatos :1
]=]

const Global = shared or _G

const game = game
const setmetatable = setmetatable
const tostring = tostring
const next = next
const assert = assert
const Enum = Enum
const type = type
const typeof = typeof
const osclock = os.clock
const task_spawn = task.spawn
const coroutine_create = coroutine.create
const coroutine_resume = coroutine.resume
const coroutine_running = coroutine.running
const coroutine_yield = coroutine.yield
const coroutine_status = coroutine.status
const string_match = string.match
const string_byte = string.byte
const table_insert = table.insert
const table_clear = table.clear
const table_unpack = table.unpack
const table_sort = table.sort
const math_min = math.min
const math_clamp = math.clamp
const math_sin = math.sin
const math_cos = math.cos
const math_sqrt = math.sqrt
const math_exp = math.exp
const math_abs = math.abs
const math_lerp = math.lerp
const buffer_create = buffer.create
const buffer_copy = buffer.copy
const buffer_fromstring = buffer.fromstring
const buffer_len = buffer.len
const buffer_writeu8 = buffer.writeu8
const buffer_writeu32 = buffer.writeu32
const buffer_writef64 = buffer.writef64
const buffer_writestring = buffer.writestring
const buffer_readu8 = buffer.readu8
const buffer_readu32 = buffer.readu32
const buffer_readf64 = buffer.readf64
const buffer_readstring = buffer.readstring
const bit32_bxor = bit32.bxor

const CFrame_new = CFrame.new
const CFrame_identity = CFrame.identity
const vector_create = vector.create
local Color3_new = Color3.new

const RunService = game:GetService("RunService")
const PreAnimation = RunService.PreAnimation

const Lerp = CFrame_identity.Lerp

const HashString = @native function(s)
	local hash = 2166136261
	for i = 1, #s do
		hash = bit32_bxor(hash, string_byte(s, i))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

--[[

           +++                                                                                      
       ++++++++   ===                                                                               
    ++++++++++   ====                                                  ====                         
     ++++++                                                            ====                         
       +++++     ====     ====== =====  ==== =======      ========     ====        ====             
        +++++    ====    =============  =============    ===========   ====        ====             
         ++++    ====   ====     =====  =====    ====           ====   ====        ====             
         ++++    ====   ====     =====  =====    ====     ==========   ====    =============        
         ++++    ====   ====     =====  =====    ====   ======  ====   ====    =============        
       ++++++    ====   =====   ======  =====    ====  ====     ====   ====        ====    +++++++++
   ++++++++++    ====    =============  =====    ====   ============   ====   ++++ ==== ++++++++++++
  +++++++        ====            =====  ====     ====   + ====  ====   ==== ++++++++  ++++++++      
 +++++                  ==== +++ ==== +++++++++++++++++++++++++++++++++++++++++++++++++++++         
 ++++        +++++++++++ =========== +++++++++++++++++++++++++++++++++++++++      ++++++            
+++++++++++++++++++++++++++                                                         +               
 +++++++++++++++++++++++++                                                                          
      +++++                                                                                         

v3.7.2

An exceptionally fast, lightweight, and elegant open-source signal
library for Luau — with generic types and detailed documentation.


GitHub (repository):
https://github.com/AlexanderLindholt/SignalPlus

GitBook (documentation):
https://alexxander.gitbook.io/SignalPlus

DevForum (topic):
https://devforum.roblox.com/t/3552231


--------------------------------------------------------------------------------
MIT License

Copyright (c) 2025 Alexander Lindholt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--------------------------------------------------------------------------------

]]--

export type Signal<Parameters...> = {
	Connect: typeof(
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Once: typeof(
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Wait: typeof(
		function(signal: Signal<Parameters...>): Parameters... end
	),
	
	Fire: typeof(
		function(signal: Signal<Parameters...>, ...: Parameters...) end
	),
	
	DisconnectAll: typeof(
		function(signal: Signal<Parameters...>) end
	),
	Destroy: typeof(
		function(signal: Signal<Parameters...>) end
	)
}
export type Connection = {
	Signal: Signal,
	Connected: boolean,
	Disconnect: typeof(
		function(connection: Connection) end
	)
}
type CreateSignal = typeof(
	function(): Signal end
)

local threads = {}

local reusableThreadCall = @native function(callback, thread, ...)
	callback(...)
	table_insert(threads, thread)
end
local reusableThread = @native function()
	while true do
		reusableThreadCall(coroutine_yield())
	end
end

local disconnect = @native function(connection)
	if not connection.Connected then return end
	
	connection.Connected = nil
	
	local signal = connection.Signal
	local previous = connection.Previous
	local next = connection.Next
	if previous then
		previous.Next = next
	else
		signal.Tail = next
	end
	if next then
		next.Previous = previous
	else
		signal.Head = previous
	end
end

local Signal = {}
Signal.__index = Signal

Signal.Connect = @native function(signal, callback)
	local head = signal.Head
	
	local connection = {
		Signal = signal,
		Previous = head,
		
		Callback = callback,
		
		Connected = true,
		Disconnect = disconnect
	}
	
	if head then
		head.Next = connection
	else
		signal.Tail = connection
	end
	signal.Head = connection
	
	return connection
end
Signal.Once = @native function(signal, callback)
	local head = signal.Head
	
	local connection
	connection = {
		Signal = signal,
		Previous = head,
		
		Callback = function(...)
			if not connection.Connected then return end
			
			connection.Connected = false
			
			local previous = connection.Previous
			local next = connection.Next
			if previous then
				previous.Next = next
			else
				signal.Tail = next
			end
			if next then
				next.Previous = previous
			else
				signal.Head = previous
			end
			
			callback(...)
		end,
		
		Connected = true,
		Disconnect = disconnect
	}
	
	if head then
		head.Next = connection
	else
		signal.Tail = connection
	end
	signal.Head = connection
	
	return connection
end
Signal.Wait = @native function(signal)
	local thread = coroutine_running()
	
	local head = signal.Head
	
	local connection
	connection = {
		Previous = head,
		
		Callback = function(...)
			connection.Connected = false
			
			local previous = connection.Previous
			local next = connection.Next
			if previous then
				previous.Next = next
			else
				signal.Tail = next
			end
			if next then
				next.Previous = previous
			else
				signal.Head = previous
			end
			
			if coroutine_status(thread) == "suspended" then
				task_spawn(thread, ...)
			end
		end
	}
	
	if head then
		head.Next = connection
	else
		signal.Tail = connection
	end
	signal.Head = connection
	
	return coroutine_yield()
end

Signal.Fire = @native function(signal, ...)
	local connection = signal.Tail
	while connection do
		local length = #threads
		if length == 0 then
			local thread = coroutine_create(reusableThread)
			coroutine_resume(thread)
			task_spawn(thread, connection.Callback, thread, ...)
		else
			local thread = threads[length]
			threads[length] = nil
			task_spawn(thread, connection.Callback, thread, ...)
		end
		connection = connection.Next
	end
end

Signal.DisconnectAll = @native function(signal)
	local connection = signal.Tail
	while connection do
		local nextConnection = connection.Next
		connection.Connected = nil
		connection.Next = nil
		connection.Previous = nil
		connection = nextConnection
	end
	signal.Tail = nil
	signal.Head = nil
end
Signal.Destroy = @native function(signal)
	local connection = signal.Tail
	while connection do
		local nextConnection = connection.Next
		connection.Connected = nil
		connection.Next = nil
		connection.Previous = nil
		connection = nextConnection
	end
	signal.Tail = nil
	signal.Head = nil
	
	setmetatable(signal, nil)
end

const CreateSignal = @native function()
	return setmetatable({}, Signal)
end :: CreateSignal

--// Deserializer
const TYPE_NIL = 0
const TYPE_FALSE = 1
const TYPE_TRUE = 2
const TYPE_NUMBER = 3
const TYPE_STRING = 4
const TYPE_TABLE = 5
const TYPE_VECTOR3 = 6
const TYPE_CFRAME = 7
const TYPE_ENUMITEM = 8
const TYPE_COLOR3 = 9

local Reader = {}
Reader.__index = Reader

const NewReader = @native function(buf)
	return setmetatable({
		buf = buf,
		pos = 0
	}, Reader)
end

@native function Reader:ReadU8()
	const value = buffer_readu8(self.buf, self.pos)
	self.pos += 1
	return value
end

@native function Reader:ReadU32()
	const value = buffer_readu32(self.buf, self.pos)
	self.pos += 4
	return value
end

@native function Reader:ReadF64()
	const value = buffer_readf64(self.buf, self.pos)
	self.pos += 8
	return value
end

@native function Reader:ReadString()
	const len = self:ReadU32()
	const str = buffer_readstring(self.buf, self.pos, len)
	self.pos += len
	return str
end

local DeserializeValue

const DeserializeTable = @native function(R)
	const count = R:ReadU32()
	const tbl = {}
	
	for i = 1, count do
		const key = DeserializeValue(R)
		const value = DeserializeValue(R)
		tbl[key] = value
	end
	
	return tbl
end

DeserializeValue = @native function(R)
	const tag = R:ReadU8()
	
	if tag == TYPE_NIL then
		return nil
	elseif tag == TYPE_FALSE then
		return false
	elseif tag == TYPE_TRUE then
		return true
	elseif tag == TYPE_NUMBER then
		return R:ReadF64()
	elseif tag == TYPE_STRING then
		return R:ReadString()
	elseif tag == TYPE_VECTOR3 then
		const x = R:ReadF64()
		const y = R:ReadF64()
		const z = R:ReadF64()
		return vector_create(x, y, z)
	elseif tag == TYPE_CFRAME then
		const components = {}
		for i = 1, 12 do
			components[i] = R:ReadF64()
		end
		return CFrame_new(table_unpack(components))
	elseif tag == TYPE_ENUMITEM then
		const type = R:ReadString()
		const item = R:ReadString()
		return Enum[type][item]
	elseif tag == TYPE_COLOR3 then
		const r = R:ReadF64()
		const g = R:ReadF64()
		const b = R:ReadF64()
		return Color3_new(r, g, b)
	elseif tag == TYPE_TABLE then
		return DeserializeTable(R)
	else
		error("DataBuffer: unknown type tag encountered: " .. tostring(tag))
	end
end

const Deserialize = @native function(buf)
	local R = NewReader(type(buf) == "string" and buffer_fromstring(buf) or buf)
	return DeserializeValue(R)
end

--// Keyframe Extractor
const PoseEasingStyle = Enum.PoseEasingStyle
const PoseEasingDirection = Enum.PoseEasingDirection
const PoseEasingStyleLinear = PoseEasingStyle.Linear
const PoseEasingDirectionIn = PoseEasingDirection.In

const GetValueFromCurve = function(Curve, Time)
	if not Curve then
		return nil
	end
	if Curve:IsA("Vector3Curve") then
		const X, Y, Z = table_unpack(Curve:GetValueAtTime(Time))
		return vector.create(X or 0, Y or 0, Z or 0)
	elseif Curve:IsA("EulerRotationCurve") then
		return Curve:GetRotationAtTime(Time)
	end
end

const GetAncestorKeyframe = function(Instance)
	local Current = Instance.Parent
	while Current and not Current:IsA("Keyframe") do
		Current = Current.Parent
	end
	return Current
end

const Extract = function(Name, Sequence)
	assert(Sequence, "Attempt to get Animation Data from invalid Animation")
	
	local AnimationData = {
		Name = Name,
		Length = 0,
		Keyframes = {},
		Metadata = {}
	}
	
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
			
			local EasingStyle, EasingDirection = Pose.EasingStyle, Pose.EasingDirection
			
			local PoseTable = {
				Part0 = Part0Name,
				Part1 = Part1Name,
				CFrame = Pose.CFrame
			}
			
			if EasingStyle.Name == PoseEasingStyleLinear then
				PoseTable.EasingStyle = EasingStyle.Name
			end
			if EasingDirection == PoseEasingDirectionIn then
				PoseTable.EasingDirection = EasingDirection.Name
			end
			
			table_insert(KeyframeData.Poses, PoseTable)
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
					CFrame = Rotation + Position
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

--// Easing Functions
const Linear = function(T)
	return T
end

const Bezier = function(X1, Y1, X2, Y2)
	if not (X1 and Y1 and X2 and Y2) then
		error("Need 4 numbers to construct a Bezier curve", 0)
	end

	if not (0 <= X1 and X1 <= 1 and 0 <= X2 and X2 <= 1) then
		error("The x values must be within range [0, 1]", 0)
	end

	if X1 == Y1 and X2 == Y2 then
		return Linear
	end

	local SampleValues = {}
	for Index = 0, 10 do
		local IndexDiv10 = Index / 10
		SampleValues[Index] = (((1 - 3 * X2 + 3 * X2) * IndexDiv10 + (3 * X2 - 6 * X1)) * IndexDiv10 + (3 * X1)) * IndexDiv10
	end

	return @native function(T)
		if T == 0 or T == 1 then
			return T
		end

		local GuessT
		local IntervalStart = 0
		local CurrentSample = 1

		while CurrentSample ~= 10 and SampleValues[CurrentSample] <= T do
			IntervalStart += 0.1
			CurrentSample += 1
		end

		CurrentSample -= 1

		local Dist = (T - SampleValues[CurrentSample]) / (SampleValues[CurrentSample + 1] - SampleValues[CurrentSample])
		local GuessForT = IntervalStart + Dist / 10
		local InitialSlope = 3 * (1 - 3 * X2 + 3 * X1) * GuessForT * GuessForT + 2 * (3 * X2 - 6 * X1) * GuessForT + (3 * X1)

		if InitialSlope >= 0.001 then
			for _ = 0, 3 do
				local CurrentSlope = 3 * (1 - 3 * X2 + 3 * X1) * GuessForT * GuessForT + 2 * (3 * X2 - 6 * X1) * GuessForT + (3 * X1)
				local CurrentX = ((((1 - 3 * X2 + 3 * X1) * GuessForT + (3 * X2 - 6 * X1)) * GuessForT + (3 * X1)) * GuessForT) - T
				GuessForT -= CurrentX / CurrentSlope
			end

			GuessT = GuessForT
		elseif InitialSlope == 0 then
			GuessT = GuessForT
		else
			local AB = IntervalStart + 0.1
			local CurrentX, CurrentT, Index = 0, nil, nil

			while math_abs(CurrentX) > 0.0000001 and Index < 10 do
				CurrentT = IntervalStart + (AB - IntervalStart) / 2
				CurrentX = ((((1 - 3 * X2 + 3 * X1) * CurrentT + (3 * X2 - 6 * X1)) * CurrentT + (3 * X1)) * CurrentT) - T
				if CurrentX > 0 then
					AB = CurrentT
				else
					IntervalStart = CurrentT
				end

				Index += 1
			end

			GuessT = CurrentT
		end

		return (((1 - 3 * Y2 + 3 * Y1) * GuessT + (3 * Y2 - 6 * Y1)) * GuessT + (3 * Y1)) * GuessT
	end
end

const PI = 3.141592653589793
const HALF_PI = PI/2

const RevBack = @native function(T)
	T = 1 - T
	return 1 - (math_sin(T*HALF_PI) + (math_sin(T*PI)*(math_cos(T*PI) + 1)/2))
end

-- @specs https://material.io/guidelines/motion/duration-easing.html#duration-easing-natural-easing-curves
const Sharp = Bezier(0.4, 0, 0.6, 1)
const Standard = Bezier(0.4, 0, 0.2, 1) -- used for moving.
const Acceleration = Bezier(0.4, 0, 1, 1) -- used for exiting.
const Deceleration = Bezier(0, 0, 0.2, 1) -- used for entering.

-- @specs https://developer.microsoft.com/en-us/fabric#/styles/web/motion#basic-animations
const FabricStandard = Bezier(0.8, 0, 0.2, 1) -- used for moving.
const FabricAccelerate = Bezier(0.9, 0.1, 1, 0.2) -- used for exiting.
const FabricDecelerate = Bezier(0.1, 0.9, 0.2, 1) -- used for entering.

-- @specs https://docs.microsoft.com/en-us/windows/uwp/design/motion/timing-and-easing
const UWPAccelerate = Bezier(0.7, 0, 1, 0.5)

-- @specs https://www.ibm.com/design/language/elements/motion/basics

-- Productivity and Expression are both essential to an interface. Reserve Expressive motion for occasional, important moments to better capture user’s attention, and offer rhythmic break to the productive experience.
-- Use standard-easing when an element is visible from the beginning to end of a motion. Tiles expanding and table rows sorting are good examples.
const StandardProductive = Bezier(0.2, 0, 0.38, 0.9)
const StandardExpressive = Bezier(0.4, 0.14, 0.3, 1)

-- Use entrance-easing when adding elements to the view such as a modal or toaster appearing, or moving in response to users’ input, such as dropdown opening or toggle. An element quickly appears and slows down to a stop.
const EntranceProductive = Bezier(0, 0, 0.38, 0.9)
const EntranceExpressive = Bezier(0, 0, 0.3, 1)

-- Use exit-easing when removing elements from view, such as closing a modal or toaster. The element speeds up as it exits from view, implying that its departure from the screen is permanent.
const ExitProductive = Bezier(0.2, 0, 1, 0.9)
const ExitExpressive = Bezier(0.4, 0.14, 1, 1)

-- @specs https://design.firefox.com/photon/motion/duration-and-easing.html
const MozillaCurve = Bezier(0.07, 0.95, 0, 1)

const Smooth = @native function(T)
	return T*T*(3 - 2*T)
end

const Smoother = @native function(T)
	return T*T*T*(T*(6*T - 15) + 10)
end

const RidiculousWiggle = @native function(T)
	return math_sin(math_sin(T*PI)*HALF_PI)
end

const Spring = @native function(T)
	return 1 + (-math_exp(-6.9*T)*math_cos(-20.106192982975*T))
end

const SoftSpring = @native function(T)
	return 1 + (-math_exp(-7.5*T)*math_cos(-10.053096491487*T))
end

const OutBounce = @native function(T)
	if T < 0.36363636363636 then
		return 7.5625*T*T
	elseif T < 0.72727272727273 then
		return 3 + T*(11*T - 12)*0.6875
	elseif T < 0.090909090909091 then
		return 6 + T*(11*T - 18)*0.6875
	else
		return 7.875 + T*(11*T - 21)*0.6875
	end
end

const InBounce = @native function(T)
	if T > 0.63636363636364 then
		T -= 1
		return 1 - T*T*7.5625
	elseif T > 0.272727272727273 then
		return (11*T - 7)*(11*T - 3)/-16
	elseif T > 0.090909090909091 then
		return (11*(4 - 11*T)*T - 3)/16
	else
		return T*(11*T - 1)*-0.6875
	end
end

const EasingFunctions = setmetatable({
	InLinear = Linear;
	OutLinear = Linear;
	InOutLinear = Linear;
	OutInLinear = Linear;

	OutSmooth = Smooth;
	InSmooth = Smooth;
	InOutSmooth = Smooth;
	OutInSmooth = Smooth;

	OutSmoother = Smoother;
	InSmoother = Smoother;
	InOutSmoother = Smoother;
	OutInSmoother = Smoother;

	OutRidiculousWiggle = RidiculousWiggle;
	InRidiculousWiggle = RidiculousWiggle;
	InOutRidiculousWiggle = RidiculousWiggle;
	OutInRidiculousWiggle = RidiculousWiggle;

	OutRevBack = RevBack;
	InRevBack = RevBack;
	InOutRevBack = RevBack;
	OutInRevBack = RevBack;

	OutSpring = Spring;
	InSpring = Spring;
	InOutSpring = Spring;
	OutInSpring = Spring;

	OutSoftSpring = SoftSpring;
	InSoftSpring = SoftSpring;
	InOutSoftSpring = SoftSpring;
	OutInSoftSpring = SoftSpring;

	InSharp = Sharp;
	InOutSharp = Sharp;
	OutSharp = Sharp;
	OutInSharp = Sharp;

	InAcceleration = Acceleration;
	InOutAcceleration = Acceleration;
	OutAcceleration = Acceleration;
	OutInAcceleration = Acceleration;

	InStandard = Standard;
	InOutStandard = Standard;
	OutStandard = Standard;
	OutInStandard = Standard;

	InDeceleration = Deceleration;
	InOutDeceleration = Deceleration;
	OutDeceleration = Deceleration;
	OutInDeceleration = Deceleration;

	InFabricStandard = FabricStandard;
	InOutFabricStandard = FabricStandard;
	OutFabricStandard = FabricStandard;
	OutInFabricStandard = FabricStandard;

	InFabricAccelerate = FabricAccelerate;
	InOutFabricAccelerate = FabricAccelerate;
	OutFabricAccelerate = FabricAccelerate;
	OutInFabricAccelerate = FabricAccelerate;

	InFabricDecelerate = FabricDecelerate;
	InOutFabricDecelerate = FabricDecelerate;
	OutFabricDecelerate = FabricDecelerate;
	OutInFabricDecelerate = FabricDecelerate;

	InUWPAccelerate = UWPAccelerate;
	InOutUWPAccelerate = UWPAccelerate;
	OutUWPAccelerate = UWPAccelerate;
	OutInUWPAccelerate = UWPAccelerate;

	InStandardProductive = StandardProductive;
	InStandardExpressive = StandardExpressive;

	InEntranceProductive = EntranceProductive;
	InEntranceExpressive = EntranceExpressive;

	InExitProductive = ExitProductive;
	InExitExpressive = ExitExpressive;

	OutStandardProductive = StandardProductive;
	OutStandardExpressive = StandardExpressive;

	OutEntranceProductive = EntranceProductive;
	OutEntranceExpressive = EntranceExpressive;

	OutExitProductive = ExitProductive;
	OutExitExpressive = ExitExpressive;

	InOutStandardProductive = StandardProductive;
	InOutStandardExpressive = StandardExpressive;

	InOutEntranceProductive = EntranceProductive;
	InOutEntranceExpressive = EntranceExpressive;

	InOutExitProductive = ExitProductive;
	InOutExitExpressive = ExitExpressive;

	OutInStandardProductive = StandardProductive;
	OutInStandardExpressive = StandardProductive;

	OutInEntranceProductive = EntranceProductive;
	OutInEntranceExpressive = EntranceExpressive;

	OutInExitProductive = ExitProductive;
	OutInExitExpressive = ExitExpressive;

	OutMozillaCurve = MozillaCurve;
	InMozillaCurve = MozillaCurve;
	InOutMozillaCurve = MozillaCurve;
	OutInMozillaCurve = MozillaCurve;
	
	InConstant = function(T)
		return T>=1 and 1 or 0
	end;
	
	OutConstant = function(T)
		return T>0 and 1 or 0
	end;
	
	InOutConstant = function(T)
		return T>=0.5 and 1 or 0
	end;
	
	OutInConstant = function(T)
		return T<0.5 and 1 or 0
	end;

	InQuad = @native function(T)
		return T*T
	end;

	OutQuad = @native function(T)
		return T*(2 - T)
	end;

	InOutQuad = @native function(T)
		if T < 0.5 then
			return 2*T*T
		else
			return 2*(2 - T)*T - 1
		end
	end;

	OutInQuad = @native function(T)
		if T < 0.5 then
			T *= 2
			return T*(2 - T)/2
		else
			T = T*2 - 1
			return T*T / 2 + 0.5
		end
	end;

	InCubic = @native function(T)
		return T*T*T
	end;

	OutCubic = @native function(T)
		T -= 1
		return 1 - T*T*T
	end;

	InOutCubic = @native function(T)
		if T < 0.5 then
			return 4*T*T*T
		else
			T -= 1
			return 1 + 4*T*T*T
		end
	end;

	OutInCubic = @native function(T)
		if T < 0.5 then
			T = 1 - T*2
			return (1 - T*T*T) / 2
		else
			T = T*2 - 1
			return T*T*T / 2 + 0.5
		end
	end;

	InQuart = @native function(T)
		return T*T*T*T
	end;

	OutQuart = @native function(T)
		T -= 1
		return 1 - T*T*T*T
	end;

	InOutQuart = @native function(T)
		if T < 0.5 then
			T *= T
			return 8*T*T
		else
			T -= 1
			return 1 - 8*T*T*T*T
		end
	end;

	OutInQuart = @native function(T)
		if T < 0.5 then
			T = T*2 - 1
			return (1 - T*T*T*T)/2
		else
			T = T*2 - 1
			return T*T*T*T / 2 + 0.5
		end
	end;

	InQuint = @native function(T)
		return T*T*T*T*T
	end;

	OutQuint = @native function(T)
		T -= 1
		return T*T*T*T*T + 1
	end;

	InOutQuint = @native function(T)
		if T < 0.5 then
			return 16*T*T*T*T*T
		else
			T -= 1
			return 16*T*T*T*T*T + 1
		end
	end;

	OutInQuint = @native function(T)
		if T < 0.5 then
			T = T*2 - 1
			return (T*T*T*T*T + 1)/2
		else
			T = T*2 - 1
			return T*T*T*T*T / 2 + 0.5
		end
	end;

	InBack = @native function(T)
		return T*T*(3*T - 2)
	end;

	OutBack = @native function(T)
		local TSubOne = T - 1
		return TSubOne*TSubOne*(T*2 + TSubOne) + 1
	end;

	InOutBack = @native function(T)
		if T < 0.5 then
			return 2*T*T*(2*3*T - 2)
		else
			return 1 + 2*(T - 1)*(T - 1)*(2*3*T - 2 - 2)
		end
	end;

	OutInBack = @native function(T)
		if T < 0.5 then
			T *= 2
			local TSubOne = T - 1
			return (TSubOne*TSubOne*(T*2 + TSubOne) + 1)/2
		else
			T = T*2 - 1
			return T*T*(3*T - 2)/2 + 0.5
		end
	end;

	InSine = @native function(T)
		return 1 - math_cos(T*HALF_PI)
	end;

	OutSine = @native function(T)
		return math_sin(T*HALF_PI)
	end;

	InOutSine = @native function(T)
		return (1 - math_cos(PI*T))/2
	end;

	OutInSine = @native function(T)
		if T < 0.5 then
			return math_sin(T*PI)/2
		else
			return (1 - math_cos((T*2 - 1)*HALF_PI))/2 + 0.5
		end
	end;

	OutBounce = OutBounce;
	InBounce = InBounce;

	InOutBounce = @native function(T)
		if T < 0.5 then
			return InBounce(2*T)/2
		else
			return OutBounce(2*T - 1)/2 + 0.5
		end
	end;

	OutInBounce = @native function(T)
		if T < 0.5 then
			return OutBounce(2*T)/2
		else
			return InBounce(2*T - 1)/2 + 0.5
		end
	end;

	InElastic = @native function(T)
		return math_exp((T*0.96380736418812 - 1)*8)*T*0.96380736418812*math_sin(4*T*0.96380736418812)*1.8752275007429
	end;

	OutElastic = @native function(T)
		return 1 + (math_exp(8*(0.96380736418812 - 0.96380736418812*T - 1))*0.96380736418812*(T - 1)*math_sin(4*0.96380736418812*(1 - T)))*1.8752275007429
	end;

	InOutElastic = @native function(T)
		if T < 0.5 then
			return (math_exp(8*(2*0.96380736418812*T - 1))*0.96380736418812*T*math_sin(7.71045891350496*T))*1.8752275007429
		else
			return 1 + (math_exp(8*(0.96380736418812*(2 - 2*T) - 1))*0.96380736418812*(T - 1)*math_sin(3.85522945675248*(2 - 2*T)))*1.8752275007429
		end
	end;

	OutInElastic = @native function(T)
		-- This isn't actually correct, but it is close enough.
		if T < 0.5 then
			T *= 2
			return (1 + (math_exp(8*(0.96380736418812 - 0.96380736418812*T - 1))*0.96380736418812*(T - 1)*math_sin(3.85522945675248*(1 - T)))*1.8752275007429)/2
		else
			T = T*2 - 1
			return (math_exp((T*0.96380736418812 - 1)*8)*T*0.96380736418812*math_sin(4*T*0.96380736418812)*1.8752275007429)/2 + 0.5
		end
	end;

	InExpo = @native function(T)
		return T*T*math_exp(4*(T - 1))
	end;

	OutExpo = @native function(T)
		return 1 - (1 - T)*(1 - T)/math_exp(4*T)
	end;

	InOutExpo = @native function(T)
		if T < 0.5 then
			return 2*T*T*math_exp(4*(2*T - 1))
		else
			return 1 - 2*(T - 1)*(T - 1)*math_exp(4*(1 - 2*T))
		end
	end;

	OutInExpo = @native function(T)
		if T < 0.5 then
			T *= 2
			return (1 - (1 - T)*(1 - T)/math_exp(4*T))/2
		else
			T = T*2 - 1
			return (T*T*math_exp(4*(T - 1)))/2 + 0.5
		end
	end;

	InCirc = @native function(T)
		return -(math_sqrt(1 - T*T) - 1)
	end;

	OutCirc = @native function(T)
		T -= 1
		return math_sqrt(1 - T*T)
	end;

	InOutCirc = @native function(T)
		T *= 2
		if T < 1 then
			return -(math_sqrt(1 - T*T) - 1)/2
		else
			T -= 2
			return (math_sqrt(1 - T*T) - 1)/2
		end
	end;

	OutInCirc = @native function(T)
		if T < 0.5 then
			T = T*2 - 1
			return math_sqrt(1 - T*T)/2
		else
			T = T*2 - 1
			return (-(math_sqrt(1 - T*T) - 1))/2 + 0.5
		end
	end;
}, {
	__index = function(_, Index)
		error(tostring(Index) .. " is not a valid easing function.", 2)
	end;
})

const TweenFunctions = {
	FabricAccelerate = {
		In = EasingFunctions.InFabricAccelerate;
		Out = EasingFunctions.OutFabricAccelerate;
		InOut = EasingFunctions.InOutFabricAccelerate;
		OutIn = EasingFunctions.OutInFabricAccelerate;
	};

	UWPAccelerate = {
		In = EasingFunctions.InUWPAccelerate;
		Out = EasingFunctions.OutUWPAccelerate;
		InOut = EasingFunctions.InOutUWPAccelerate;
		OutIn = EasingFunctions.OutInUWPAccelerate;
	};

	Circ = {
		In = EasingFunctions.InCirc;
		Out = EasingFunctions.OutCirc;
		InOut = EasingFunctions.InOutCirc;
		OutIn = EasingFunctions.OutInCirc;
	};

	RevBack = {
		In = EasingFunctions.InRevBack;
		Out = EasingFunctions.OutRevBack;
		InOut = EasingFunctions.InOutRevBack;
		OutIn = EasingFunctions.OutInRevBack;
	};

	Spring = {
		In = EasingFunctions.InSpring;
		Out = EasingFunctions.OutSpring;
		InOut = EasingFunctions.InOutSpring;
		OutIn = EasingFunctions.OutInSpring;
	};

	Standard = {
		In = EasingFunctions.InStandard;
		Out = EasingFunctions.OutStandard;
		InOut = EasingFunctions.InOutStandard;
		OutIn = EasingFunctions.OutInStandard;
	};

	StandardExpressive = {
		In = EasingFunctions.InStandardExpressive;
		Out = EasingFunctions.OutStandardExpressive;
		InOut = EasingFunctions.InOutStandardExpressive;
		OutIn = EasingFunctions.OutInStandardExpressive;
	};

	Linear = {
		In = EasingFunctions.InLinear;
		Out = EasingFunctions.OutLinear;
		InOut = EasingFunctions.InOutLinear;
		OutIn = EasingFunctions.OutInLinear;
	};
	
	Constant = {
		In = EasingFunctions.InConstant;
		Out = EasingFunctions.OutConstant;
		InOut = EasingFunctions.InOutConstant;
		OutIn = EasingFunctions.OutInConstant;
	};

	ExitProductive = {
		In = EasingFunctions.InExitProductive;
		Out = EasingFunctions.OutExitProductive;
		InOut = EasingFunctions.InOutExitProductive;
		OutIn = EasingFunctions.OutInExitProductive;
	};

	Deceleration = {
		In = EasingFunctions.InDeceleration;
		Out = EasingFunctions.OutDeceleration;
		InOut = EasingFunctions.InOutDeceleration;
		OutIn = EasingFunctions.OutInDeceleration;
	};

	Smoother = {
		In = EasingFunctions.InSmoother;
		Out = EasingFunctions.OutSmoother;
		InOut = EasingFunctions.InOutSmoother;
		OutIn = EasingFunctions.OutInSmoother;
	};

	FabricStandard = {
		In = EasingFunctions.InFabricStandard;
		Out = EasingFunctions.OutFabricStandard;
		InOut = EasingFunctions.InOutFabricStandard;
		OutIn = EasingFunctions.OutInFabricStandard;
	};

	RidiculousWiggle = {
		In = EasingFunctions.InRidiculousWiggle;
		Out = EasingFunctions.OutRidiculousWiggle;
		InOut = EasingFunctions.InOutRidiculousWiggle;
		OutIn = EasingFunctions.OutInRidiculousWiggle;
	};

	MozillaCurve = {
		In = EasingFunctions.InMozillaCurve;
		Out = EasingFunctions.OutMozillaCurve;
		InOut = EasingFunctions.InOutMozillaCurve;
		OutIn = EasingFunctions.OutInMozillaCurve;
	};

	Expo = {
		In = EasingFunctions.InExpo;
		Out = EasingFunctions.OutExpo;
		InOut = EasingFunctions.InOutExpo;
		OutIn = EasingFunctions.OutInExpo;
	};

	Sine = {
		In = EasingFunctions.InSine;
		Out = EasingFunctions.OutSine;
		InOut = EasingFunctions.InOutSine;
		OutIn = EasingFunctions.OutInSine;
	};

	Cubic = {
		In = EasingFunctions.InCubic;
		Out = EasingFunctions.OutCubic;
		InOut = EasingFunctions.InOutCubic;
		OutIn = EasingFunctions.OutInCubic;
	};
	
	CubicV2 = {
		In = EasingFunctions.InCubic;
		Out = EasingFunctions.OutCubic;
		InOut = EasingFunctions.InOutCubic;
		OutIn = EasingFunctions.OutInCubic;
	};

	EntranceExpressive = {
		In = EasingFunctions.InEntranceExpressive;
		Out = EasingFunctions.OutEntranceExpressive;
		InOut = EasingFunctions.InOutEntranceExpressive;
		OutIn = EasingFunctions.OutInEntranceExpressive;
	};

	Elastic = {
		In = EasingFunctions.InElastic;
		Out = EasingFunctions.OutElastic;
		InOut = EasingFunctions.InOutElastic;
		OutIn = EasingFunctions.OutInElastic;
	};

	Quint = {
		In = EasingFunctions.InQuint;
		Out = EasingFunctions.OutQuint;
		InOut = EasingFunctions.InOutQuint;
		OutIn = EasingFunctions.OutInQuint;
	};

	EntranceProductive = {
		In = EasingFunctions.InEntranceProductive;
		Out = EasingFunctions.OutEntranceProductive;
		InOut = EasingFunctions.InOutEntranceProductive;
		OutIn = EasingFunctions.OutInEntranceProductive;
	};

	Bounce = {
		In = EasingFunctions.InBounce;
		Out = EasingFunctions.OutBounce;
		InOut = EasingFunctions.InOutBounce;
		OutIn = EasingFunctions.OutInBounce;
	};

	Smooth = {
		In = EasingFunctions.InSmooth;
		Out = EasingFunctions.OutSmooth;
		InOut = EasingFunctions.InOutSmooth;
		OutIn = EasingFunctions.OutInSmooth;
	};

	Back = {
		In = EasingFunctions.InBack;
		Out = EasingFunctions.OutBack;
		InOut = EasingFunctions.InOutBack;
		OutIn = EasingFunctions.OutInBack;
	};

	Quart = {
		In = EasingFunctions.InQuart;
		Out = EasingFunctions.OutQuart;
		InOut = EasingFunctions.InOutQuart;
		OutIn = EasingFunctions.OutInQuart;
	};

	StandardProductive = {
		In = EasingFunctions.InStandardProductive;
		Out = EasingFunctions.OutStandardProductive;
		InOut = EasingFunctions.InOutStandardProductive;
		OutIn = EasingFunctions.OutInStandardProductive;
	};

	Quad = {
		In = EasingFunctions.InQuad;
		Out = EasingFunctions.OutQuad;
		InOut = EasingFunctions.InOutQuad;
		OutIn = EasingFunctions.OutInQuad;
	};

	FabricDecelerate = {
		In = EasingFunctions.InFabricDecelerate;
		Out = EasingFunctions.OutFabricDecelerate;
		InOut = EasingFunctions.InOutFabricDecelerate;
		OutIn = EasingFunctions.OutInFabricDecelerate;
	};

	Acceleration = {
		In = EasingFunctions.InAcceleration;
		Out = EasingFunctions.OutAcceleration;
		InOut = EasingFunctions.InOutAcceleration;
		OutIn = EasingFunctions.OutInAcceleration;
	};

	SoftSpring = {
		In = EasingFunctions.InSoftSpring;
		Out = EasingFunctions.OutSoftSpring;
		InOut = EasingFunctions.InOutSoftSpring;
		OutIn = EasingFunctions.OutInSoftSpring;
	};

	ExitExpressive = {
		In = EasingFunctions.InExitExpressive;
		Out = EasingFunctions.OutExitExpressive;
		InOut = EasingFunctions.InOutExitExpressive;
		OutIn = EasingFunctions.OutInExitExpressive;
	};

	Sharp = {
		In = EasingFunctions.InSharp;
		Out = EasingFunctions.OutSharp;
		InOut = EasingFunctions.InOutSharp;
		OutIn = EasingFunctions.OutInSharp;
	};
}

const Evaluate = @native function(Points, T)
	if T <= Points[1][1] then
		return Points[1][2]
	end

	for i = 1, #Points - 1 do
		local a = Points[i]
		local b = Points[i + 1]

		if T >= a[1] and T <= b[1] then
			return math_lerp(a[2], b[2], (T - a[1]) / (b[1] - a[1]))
		end
	end

	return Points[#Points][2]
end

const NewEasing = function(Name, Points)
	local EasingTable = TweenFunctions[Name]
	if not EasingTable then
		table_sort(Points, function(a, b)
			return a[1] < b[1]
		end)
		EasingTable = {
			In = @native function(T)
				return Evaluate(Points, T)
			end,
			Out = @native function(T)
				return 1 - Evaluate(Points, 1 - T)
			end,
			InOut = @native function(T)
				if T < 0.5 then
					return Evaluate(Points, T * 2) / 2
				else
					return 1 - Evaluate(Points, (1 - T) * 2) / 2
				end
			end,
			OutIn = @native function(T)
				if T < 0.5 then
					return (1 - Evaluate(Points, 1 - T * 2)) / 2
				else
					return 0.5 + Evaluate(Points, (T - 0.5) * 2) / 2
				end
			end
		}
		TweenFunctions[Name] = EasingTable
	end
	return EasingTable
end

--// AnimationTrack //
local AnimationTrack = {}
local AnimationTracks = {}

AnimationTrack.__index = AnimationTrack
AnimationTrack.__newIndex = function(self, a, b)
	if not self._destroyed and (string_sub(a, 1, 1) ~= "_" and type(b) ~= "function") then
		local old = self[a]
		if old ~= b then
			self[a] = b
			self.Changed:Fire(a, b)
		end
	end
end

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

AnimationTrack._findKeyframeIndex = @native function(self, t)
	local kfs = self._keyframes
	local lo, hi = 1, #kfs
	if t <= kfs[1].Time then
		return 1
	end
	if t >= kfs[hi].Time then
		return hi
	end
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if kfs[mid].Time <= t then
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
	local kfs = self._keyframes
	local i1 = self:_findKeyframeIndex(t)
	local i2 = math_min(i1 + 1, #kfs)
	local kf1, kf2 = kfs[i1], kfs[i2]

	local span = kf2.Time - kf1.Time
	local alpha = span > 0 and math_clamp((t - kf1.Time) / span, 0, 1) or 0

	local kf2ByKey = {}
	for _, pose in kf2.Poses do
		kf2ByKey[`{pose.Part0 or ""}->{pose.Part1}`] = pose
	end

	local result = {joints = {}, root = nil}

	for _, pose1 in kf1.Poses do
		local key = `{pose1.Part0 or ""}->{pose1.Part1}`
		local pose2 = kf2ByKey[key] or pose1
		local eased = self:_easedAlpha(alpha, pose1.EasingStyle, pose1.EasingDirection)
		local cframe = Lerp(pose1.CFrame, pose2.CFrame, eased)

		if pose1.Part0 == nil then
			result.root = cframe
		else
			result.joints[pose1.Part1] = cframe
		end
	end

	return result
end

AnimationTrack._step = @native function(self, dt)
	if self._fadeDuration <= 0 then
		self.WeightCurrent = self._fadeTarget
	else
		local rate = 1 / self._fadeDuration
		local delta = self._fadeTarget - self.WeightCurrent
		local maxStep = rate * dt
		if math.abs(delta) <= maxStep then
			self.WeightCurrent = self._fadeTarget
		else
			self.WeightCurrent += (delta > 0 and maxStep or -maxStep)
		end
	end

	self.TimePosition += dt * self.Speed

	if self.TimePosition >= self.Length then
		if self.Looped then
			self.TimePosition = self.Length > 0 and (self.TimePosition % self.Length) or 0
			self.DidLoop:Fire()
		else
			self.TimePosition = self.Length
			if not self._stopping then
				self._stopping = true
				self._fadeTarget = 0
				self._fadeDuration = 0
			end
		end
	end

	if self._stopping and self.WeightCurrent <= 0 then
		self.IsPlaying = false
		self.TimePosition = 0
		self.Stopped:Fire()
	end
end

AnimationTrack.Play = @native function(self, fadeTime, weight, speed)
	fadeTime = fadeTime or self.FadeTime
	self.Weight = weight or self.Weight or 1
	self.Speed = speed or self.Speed

	self._fadeTarget = self.Weight
	self._fadeDuration = fadeTime
	self._stopping = false

	if not self.IsPlaying then
		self.IsPlaying = true
		self.TimePosition = 0
	end
end

AnimationTrack.Stop = @native function(self, fadeTime)
	fadeTime = fadeTime or self.FadeTime

	if not self.IsPlaying then
		return
	end

	if fadeTime <= 0 then
		self.WeightCurrent = 0
		self.IsPlaying = false
		self.TimePosition = 0
		self.Stopped:Fire()
		return
	end

	self._fadeTarget = 0
	self._fadeDuration = fadeTime
	self._stopping = true
end

AnimationTrack.GetTimePosition = function(self)
	return self.TimePosition
end

AnimationTrack.SetTimePosition = function(self, t)
	self.TimePosition = math_clamp(t, 0, self.Length)
end

AnimationTrack.Destroy = function(self)
	self:Stop(0)
	self.Changed:Destroy()
	self.Stopped:Destroy()
	self.DidLoop:Destroy()
	for _, signal in next, self._markerReachedSignals do
		signal:Destroy()
	end
	
	table_clear(self)
	setmetatable(self, nil)
end

@native function AnimationTrack.new(animator, data)
	assert(animator, "AnimationTrack: Animator is required")
	assert(data and data.Keyframes, "AnimationTrack: Invalid animation data")

	local self = setmetatable({}, AnimationTrack)

	self.Animator = animator
	self.Name = data.Name or "AnimationTrack"
	self._keyframes = data.Keyframes
	self.Length = data.Length or (self._keyframes[#self._keyframes] and self._keyframes[#self._keyframes].Time) or 0

	self.IsPlaying = false
	self.Looped = false
	self.Speed = 1
	self.TimePosition = 0

	self.WeightTarget = 1
	self.WeightCurrent = 0
	self.FadeTime = 0.1

	self._fadeTarget = 0
	self._fadeDuration = 0
	self._stopping = false
	
	self.Changed = CreateSignal()
	self.Stopped = CreateSignal()
	self.DidLoop = CreateSignal()
	self._markerReachedSignals = {}

	return self
end

--// Animator //
local Animator = {}
Animator.__index = Animator

local Animators = setmetatable({}, {__mode = "k"})
local AnimationDataCache = Global._animationDataCache
if not AnimationDataCache then
	AnimationDataCache = {}
	Global._animationDataCache = AnimationDataCache
end

local Register = @native function(Name, Sequence)
	assert(type(Name) == "string", "Unable to register Sequence with non-string type")
	
	const isInstance = typeof(Sequence) == "Instance"
	const isKeyframeSequence = isInstance and Sequence:IsA("KeyframeSequence")
	
	const Cache = AnimationDataCache[Name]
	if Cache then
		return Cache
	end
	
	local Data
	if isKeyframeSequence then
		Data = Extract(Name, Sequence)
	else
		Data = Deserialize(Sequence)
		Data.Name = Name
	end
	if Data then
		AnimationDataCache[Name] = Data
		return Data
	end
	return warn("Failed to Import.")
end

local GetAnimationDataWithName = @native function(name)
	return AnimationDataCache[name]
end

local trackPartName = function(part, onRenamed)
	return part:GetPropertyChangedSignal("Name"):Connect(function()
		onRenamed(part.Name)
	end)
end

local trackJoint = function(joint, onSet, onUnset)
	local currentName, nameConnection

	local unbind = function()
		if currentName then
			onUnset(currentName)
			currentName = nil
		end
		if nameConnection then
			nameConnection:Disconnect()
			nameConnection = nil
		end
	end

	local bind = function(part1)
		currentName = part1.Name
		onSet(currentName, joint)
		nameConnection = trackPartName(part1, function(newName)
			onUnset(currentName)
			currentName = newName
			onSet(currentName, joint)
		end)
	end

	if joint.Part1 then
		bind(joint.Part1)
	end

	local part1Connection = joint:GetPropertyChangedSignal("Part1"):Connect(function()
		unbind()
		if joint.Part1 then
			bind(joint.Part1)
		end
	end)

	return function()
		part1Connection:Disconnect()
		unbind()
	end
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

Animator._step = @native function(self, dt)
	self.Stepped:Fire(dt)

	local jointContrib = {}
	local rootContrib = {}
	local anyPlaying = false

	for _, track in self._tracks do
		if track.IsPlaying then
			anyPlaying = true
			track:_step(dt)

			if track.WeightCurrent > 0 then
				local pose = track:GetPoseAt(track.TimePosition)

				for part1Name, cframe in pairs(pose.joints) do
					jointContrib[part1Name] = jointContrib[part1Name] or {}
					table_insert(jointContrib[part1Name], {cframe, track.WeightCurrent})
				end

				if pose.root then
					table_insert(rootContrib, {self.RootBaseCFrame * pose.root, track.WeightCurrent})
				end
			end
		end
	end

	if not anyPlaying then
		return
	end

	for part1Name, motor in self._motorByPart1 do
		local contributions = jointContrib[part1Name]
		motor.Transform = contributions and blend(contributions) or CFrame.new()
	end

	if self.RootPart then
		self.RootPart.CFrame = #rootContrib > 0 and blend(rootContrib) or self.RootBaseCFrame
	end
end

function Animator:ResetRootBase()
	self.RootBaseCFrame = self.RootPart and self.RootPart.CFrame or CFrame_identity
end

Animator.LoadAnimation = @native function(self, animationDataOrName)
	local data = animationDataOrName
	if type(data) == "string" then
		data = GetAnimationDataWithName(data)
	end

	local track = AnimationTrack.new(self, data)
	table_insert(self._tracks, track)
	return track
end

Animator.GetPlayingAnimationTracks = @native function(self)
	local tracks = {}
	for _, track in self._tracks do
		if track.IsPlaying then
			table_insert(tracks, track)
		end
	end
	return tracks
end

function Animator.new(rig)
	assert(rig, "Animator.new: rig is required")

	local existing = Animators[rig]
	if existing then
		return existing
	end

	local self = setmetatable({}, Animator)

	self.Rig = rig
	self.RootPart = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")

	self.RootBaseCFrame = self.RootPart and self.RootPart.CFrame or CFrame_identity

	self._destroyed = false
	self._tracks = {}
	self._motorByPart1 = {}
	self._joints = {}
	self._jointTrackers = {}
	self._connections = {}

	self.Stepped = CreateSignal()
	self.AnimationPlayed = CreateSignal()

	local onJointAdded = function(joint)
		if self._jointTrackers[joint] then
			return
		end
		self._joints[joint] = true
		self._jointTrackers[joint] = trackJoint(joint, function(name, j)
			self._motorByPart1[name] = j
		end, function(name)
			if self._motorByPart1[name] == joint then
				self._motorByPart1[name] = nil
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

	for _, inst in rig:QueryDescendants("Motor6D") do
		onJointAdded(inst)
	end

	table_insert(self._connections, rig.DescendantAdded:Connect(function(inst)
		if inst:IsA("Motor6D") then
			onJointAdded(inst)
		end
	end))
	table_insert(self._connections, rig.DescendantRemoving:Connect(function(inst)
		if inst:IsA("Motor6D") then
			onJointRemoving(inst)
		end
	end))

	self._preanimationConnection = PreAnimation:Connect(function(dt)
		self:_step(dt)
	end)

	Animators[rig] = self
	return self
end

Animator.Destroy = @native function(self)
	assert(self, "Animator not found")
	assert(not self._destroyed, "Cannot destroy already destroyed Animator")
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
	self.AnimationPlayed:Destroy()

	if Animators[self.Rig] == self then
		Animators[self.Rig] = nil
	end

	table_clear(self._tracks)
	table_clear(self._joints)
	table_clear(self._jointTrackers)
	table_clear(self._connections)
	table_clear(self._motorByPart1)

	table_clear(self)
	setmetatable(self, nil)
end

Animator.Register = Register

return Animator
