--[=[
	Sigma Gizmo :cool:
]=]--

local configurations = {
	MoveHandles = {
		shaftLength = 2.4,
		tipLength = 0.9,
		Radius = 0.1
	}
}

local Instance_new = Instance.new
local table_insert = table.insert
local table_remove = table.remove
local table_find = table.find
local table_clear = table.clear
local min = math.min
local max = math.max
local clamp = math.clamp
local abs = math.abs
local sin = math.sin
local cos = math.cos
local acos = math.acos
local sqrt = math.sqrt
local atan2 = math.atan2

local vector_magnitude = vector.magnitude
local vector_cross = vector.cross
local vector_normalize = vector.normalize
local vector_dot = vector.dot

local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB
local vector_create = vector.create
local CFrame_new = CFrame.new
local CFrame_Angles = CFrame.fromEulerAngles
local CFrame_fromAxisAngle = CFrame.fromAxisAngle
local CFrame_fromMatrix = CFrame.fromMatrix
local CFrame_lookAt = CFrame.lookAt

local vector_zero = vector.zero
local vector_one = vector.one
local CFrame_identity = CFrame.identity

local MouseButton1 = Enum.UserInputType.MouseButton1
local Touch = Enum.UserInputType.Touch
local MouseMovement = Enum.UserInputType.MouseMovement

local global = shared or _G
local ccontainer = rawget(global, "Azurion")
if not ccontainer then
	repeat
		ccontainer = rawget(global, "Azurion")
		wait()
	until ccontainer
end

local cleanTasks = ccontainer.cleanTasks
local azFuncs = rawget(ccontainer, "functions")
local waitForModule = rawget(azFuncs, "waitForModule")

local CreateSignal = waitForModule("Signal")

local container = rawget(ccontainer, "container")

local Workspace = game:FindFirstChildOfClass("Workspace")
local Players = game:FindFirstChildOfClass("Players")
local UserInputService = game:FindFirstChildOfClass("UserInputService")
local RunService = game:FindFirstChildOfClass("RunService")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Heartbeat = RunService.Heartbeat
local GizmoFolder = Instance_new("Folder", container)

table_insert(cleanTasks, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera
end))

------------------------------------------------------------------------------------------------------------------------
-- Important tuffs
------------------------------------------------------------------------------------------------------------------------
local isAllowedClass = function(instance)
	if not instance then
		return
	end
	
	if instance:IsA("BasePart") then
		return "BasePart"
	elseif instance:IsA("PVInstance") then
		return "PVInstance"
	elseif instance:IsA("JointInstance") then
		if instance.ClassName == "Motor6D" then
			return "Motor6D"
		else
			return "Joint"
		end
	elseif instance:IsA("AnimationConstraint") then
		return "AnimationConstraint"
	elseif instance:IsA("Attachment") then
		if instance.ClassName == "Bone" then
			return "Bone"
		else
			return "Attachment"
		end
	end
end

local getAdorneeCFrame = function(adornee, class)
	if class == "BasePart" then
		return adornee.CFrame
	elseif class == "PVInstance" then
		return adornee:GetPivot()
	elseif class == "Motor6D" then
		local part0, part1 = adornee.Part0, adornee.Part1
		if part0 and part1 then
			return part0.CFrame * adornee.C0 * adornee.Transform
		else
			return
		end
	elseif class == "Joint" then
		local part0, part1 = adornee.Part0, adornee.Part1
		if part0 and part1 then
			return part0.CFrame * adornee.C0
		else
			return
		end
	elseif class == "AnimationConstraint" then
		local att0, att1 = adornee.Attachment0, adornee.Attachment1
		if att0 and att1 then
			return att0.WorldCFrame * adornee.C0 * adornee.Transform
		else
			return
		end
	elseif class == "Attachment" or class == "Bone" then
		return adornee.WorldCFrame
	end
end

local newHolder = function(name, parent)
	local holder = Instance_new("Part")
	holder.Name = name
	holder.Anchored = true
	holder.CanCollide = false
	holder.AudioCanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = vector_zero
	if parent then
		holder.Parent = parent
	end
	return holder
end

local getAxisOffset = function(adornee, axis)
	local size
	if adornee:IsA("BasePart") then
		size = adornee.Size
	elseif adornee:IsA("PVInstance") then
		size = adornee:GetExtentsSize()
	elseif adornee:IsA("JointInstance") then
		size = vector_one * 4
	elseif adornee:IsA("Constraint") then
		size = vector_one * 4
	elseif adornee:IsA("Attachment") then
		size = vector_one * 4
	end

	return abs(axis.X) * size.X * 0.5 + abs(axis.Y) * size.Y * 0.5 + abs(axis.Z) * size.Z * 0.5
end

local getRadius = function(adornee)
	local size
	if adornee:IsA("BasePart") then
		size = adornee.Size
	elseif adornee:IsA("PVInstance") then
		size = adornee:GetExtentsSize()
	elseif adornee:IsA("JointInstance") then
		size = vector_one * 4
	elseif adornee:IsA("Constraint") then
		size = vector_one * 4
	elseif adornee:IsA("Attachment") then
		size = vector_one * 4
	end

	return max(size.X, size.Y, size.Z) * 0.65
end

local axisCFrame = function(dir, offset)
	local up = abs(dir.Y) < 0.99 and vector_create(0, 1, 0) or vector_create(1, 0, 0)
	local look = dir
	local right = vector_normalize(vector_cross(up, look))
	local realUp = vector_normalize(vector_cross(look, right))
	return CFrame_fromMatrix(dir * offset, right, realUp, look)
end

local Axes = {
	{name = "+X", dir = vector_create(1, 0, 0), color = Color3_fromRGB(255, 70, 70)},
	{name = "+Y", dir = vector_create(0, 1, 0), color = Color3_fromRGB(80, 255, 80)},
	{name = "+Z", dir = vector_create(0, 0, 1), color = Color3_fromRGB(80, 140, 255)},
	
	{name = "-X", dir = -vector_create(1, 0, 0), color = Color3_fromRGB(255, 70, 70)},
	{name = "-Y", dir = -vector_create(0, 1, 0), color = Color3_fromRGB(80, 255, 80)},
	{name = "-Z", dir = -vector_create(0, 0, 1), color = Color3_fromRGB(80, 140, 255)},
}

local RotateAxes = {
	{name = "+X", dir = vector_create(1, 0, 0), kdir = vector_create(0, 1, 0), color = Color3_fromRGB(255, 70, 70)},
	{name = "+Y", dir = vector_create(0, 1, 0), kdir = vector_create(0, 0, 1), color = Color3_fromRGB(80, 255, 80)},
	{name = "+Z", dir = vector_create(0, 0, 1), kdir = vector_create(1, 0, 0), color = Color3_fromRGB(80, 140, 255)},
	
	{name = "-X", dir = -vector_create(1, 0, 0), kdir = vector_create(0, -1, 0), color = Color3_fromRGB(255, 70, 70)},
	{name = "-Y", dir = -vector_create(0, 1, 0), kdir = vector_create(0, 0, -1), color = Color3_fromRGB(80, 255, 80)},
	{name = "-Z", dir = -vector_create(0, 0, 1), kdir = vector_create(-1, 0, 0), color = Color3_fromRGB(80, 140, 255)},
}

local ResizeAxes = {
	{name = "+X", dir = vector_create(1, 0, 0)},
	{name = "+Y", dir = vector_create(0, 1, 0)},
	{name = "+Z", dir = vector_create(0, 0, 1)},
	
	{name = "-X", dir = -vector_create(1, 0, 0)},
	{name = "-Y", dir = -vector_create(0, 1, 0)},
	{name = "-Z", dir = -vector_create(0, 0, 1)},
}

local mouseRay = function()
	local loc = UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(loc.X, loc.Y)
	return unitRay.Origin, unitRay.Direction
end

local closestT = function(p1, d1, p2, d2)
	local r = p1 - p2
	local a = vector_dot(d1, d1)
	local e = vector_dot(d2, d2)
	local f = vector_dot(d2, r)
	local c = vector_dot(d1, r)
	local b = vector_dot(d1, d2)
	local denom = a * e - b * b
	if abs(denom) < 1e-6 then
		return 0
	end
	return (b * f - c * e) / denom
end

local rayPlaneHit = function(rayOrigin, rayDir, planePoint, planeNormal)
	local denom = vector_dot(rayDir, planeNormal)
	if abs(denom) < 1e-6 then
		return nil
	end
	local t = vector_dot(planePoint - rayOrigin, planeNormal) / denom
	if t < 0 then
		return nil
	end
	return rayOrigin + rayDir * t
end

local withAxis = function(v, axisName, value)
	return (axisName == "X" and vector_create(value, v.Y, v.Z)) or (axisName == "Y" and vector_create(v.X, value, v.Z)) or vector_create(v.X, v.Y, value)
end

local getAxisVal = function(v, axisName)
	return (axisName == "X" and v.X) or (axisName == "Y" and v.Y) or v.Z
end

------------------------------------------------------------------------------------------------------------------------
-- Adornment Watcher
------------------------------------------------------------------------------------------------------------------------
local Watcher = {}
Watcher.__index = Watcher

local watchers = {}
local hoveredWatcher = nil
local activeDragWatcher = nil

local inputChangedConn = nil
local inputBeganConn = nil
local inputEndedConn = nil

local rayHitBox = function(rayOrigin, rayDir, boxCFrame, boxSize)
	local relOrigin = boxCFrame:PointToObjectSpace(rayOrigin)
	local relDir = boxCFrame:VectorToObjectSpace(rayDir)
	local halfSize = boxSize * 0.5

	local tMin, tMax = -math.huge, math.huge

	local origins = {relOrigin.X, relOrigin.Y, relOrigin.Z}
	local dirs = {relDir.X, relDir.Y, relDir.Z}
	local halves = {halfSize.X, halfSize.Y, halfSize.Z}

	for i = 1, 3 do
		local o, d, h = origins[i], dirs[i], halves[i]
		if abs(d) < 1e-8 then
			if o < -h or o > h then
				return false, 0
			end
		else
			local t1 = (-h - o) / d
			local t2 = (h - o) / d
			if t1 > t2 then t1, t2 = t2, t1 end
			tMin = max(tMin, t1)
			tMax = min(tMax, t2)
			if tMin > tMax then
				return false, 0
			end
		end
	end

	if tMax < 0 then
		return false, 0
	end

	return true, max(tMin, 0)
end

local getWorldCFrame = function(w)
	local adornment = w._adornment
	local adornee = adornment.Adornee
	if not adornee then
		return nil
	end

	local adorneeCFrame
	if adornee:IsA("BasePart") then
		adorneeCFrame = adornee.CFrame
	elseif adornee:IsA("Model") then
		adorneeCFrame = adornee:GetPivot()
	end

	return adorneeCFrame * adornment.CFrame
end

local findBestHit = function()
	local ro, rd = mouseRay()
	local best = nil
	local bestT = math.huge

	for w in next, watchers do
		if w._enabled and w._adornment.Visible then
			if w._customHitTest then
				local hit, t = w._customHitTest(ro, rd)
				if hit and t < bestT then
					best, bestT = w, t
				end
			else
				local worldCFrame = getWorldCFrame(w)
				if worldCFrame then
					local paddedSize = w._size + vector_create(w._padding, w._padding, w._padding)
					local hit, t = rayHitBox(ro, rd, worldCFrame, paddedSize)
					if hit and t < bestT then
						best, bestT = w, t
					end
				end
			end
		end
	end

	return best
end

local updateHover = function()
	if activeDragWatcher then
		return
	end

	local best = findBestHit()

	if best ~= hoveredWatcher then
		if hoveredWatcher then
			hoveredWatcher._hovering = false
			hoveredWatcher.MouseLeave:Fire()
		end
		if best then
			best._hovering = true
			best.MouseEnter:Fire()
		end
		hoveredWatcher = best
	end
end

local watchdogCheckDrag = function()
	local w = activeDragWatcher
	if not w then return end

	local input = w._dragInput
	if input and input.UserInputState == Enum.UserInputState.End then
		w:_internalEndDrag()
	end
end

local onHeartbeat = function()
	if activeDragWatcher then
		local ro, rd = mouseRay()
		activeDragWatcher.DragChanged:Fire(ro, rd)
		watchdogCheckDrag()
	else
		updateHover()
	end
end

local isRelevantInputType = function(inputType)
	return inputType == MouseButton1 or inputType == Touch
end

local onInputBegan = function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end
	if not isRelevantInputType(input.UserInputType) then return end
	if activeDragWatcher then return end

	local best = findBestHit()
	if not best then return end

	best.MouseButton1Down:Fire(input)

	if best._draggable then
		best:_internalBeginDrag(input)
	end
end

local onInputEnded = function(input)
	if not isRelevantInputType(input.UserInputType) then return end

	if hoveredWatcher then
		hoveredWatcher.MouseButton1Up:Fire(input)
	end

	if activeDragWatcher and activeDragWatcher._dragInput == input then
		activeDragWatcher:_internalEndDrag()
	end
end

local ensureConnected = function()
	if not inputChangedConn then
		inputChangedConn = UserInputService.InputChanged:Connect(onHeartbeat)
	end
	if not inputBeganConn then
		inputBeganConn = UserInputService.InputBegan:Connect(onInputBegan)
	end
	if not inputEndedConn then
		inputEndedConn = UserInputService.InputEnded:Connect(onInputEnded)
	end
end

local disconnectIfIdle = function()
	if next(watchers) ~= nil then return end

	if inputChangedConn then inputChangedConn:Disconnect(); inputChangedConn = nil end
	if inputBeganConn then inputBeganConn:Disconnect(); inputBeganConn = nil end
	if inputEndedConn then inputEndedConn:Disconnect(); inputEndedConn = nil end
end

function Watcher.MakeRingHitTest(getCFrame, planeNormalLocal, radius, tolerance)
	local tol = tolerance or 0.3

	return function(rayOrigin, rayDir)
		local cf = getCFrame()
		local center = cf.Position
		local normal = vector_normalize(cf:VectorToWorldSpace(planeNormalLocal))

		local denom = vector_dot(rayDir, normal)
		if abs(denom) < 1e-6 then
			return false, 0
		end

		local t = vector_dot(center - rayOrigin, normal) / denom
		if t < 0 then
			return false, 0
		end

		local hitPoint = rayOrigin + rayDir * t
		local distFromCenter = vector_magnitude(hitPoint - center)

		if distFromCenter < radius - tol or distFromCenter > radius + tol then
			return false, 0
		end

		return true, t
	end
end

function Watcher.MakeSphereHitTest(getCFrame, radiusOrFn)
	return function(rayOrigin, rayDir)
		local radius = type(radiusOrFn) == "function" and radiusOrFn() or radiusOrFn
		local center = getCFrame().Position
		local oc = rayOrigin - center

		local a = vector_dot(rayDir, rayDir)
		local b = 2 * vector_dot(oc, rayDir)
		local c = vector_dot(oc, oc) - radius * radius

		local disc = b * b - 4 * a * c
		if disc < 0 then
			return false, 0
		end

		local sqrtDisc = disc ^ 0.5
		local t1 = (-b - sqrtDisc) / (2 * a)
		local t2 = (-b + sqrtDisc) / (2 * a)

		local t = t1 >= 0 and t1 or t2
		if t < 0 then
			return false, 0
		end

		return true, t
	end
end

function Watcher.MakeCylinderHitTest(getCFrame, radius, height, axisLocal)
	local axis = axisLocal or vector_create(0, 0, 1)
	local halfHeight = height * 0.5

	return function(rayOrigin, rayDir)
		local cf = getCFrame()
		local relOrigin = cf:PointToObjectSpace(rayOrigin)
		local relDir = cf:VectorToObjectSpace(rayDir)

		local axisComp = vector_dot(relDir, axis)
		local originAxisComp = vector_dot(relOrigin, axis)

		local dirRadial = relDir - axis * axisComp
		local originRadial = relOrigin - axis * originAxisComp

		local a = vector_dot(dirRadial, dirRadial)
		local b = 2 * vector_dot(originRadial, dirRadial)
		local c = vector_dot(originRadial, originRadial) - radius * radius

		local bestT = math.huge
		local found = false

		if a > 1e-8 then
			local disc = b * b - 4 * a * c
			if disc >= 0 then
				local sqrtDisc = disc ^ 0.5
				for _, t in next, {(-b - sqrtDisc) / (2 * a), (-b + sqrtDisc) / (2 * a)} do
					if t >= 0 then
						local axialPos = originAxisComp + axisComp * t
						if axialPos >= -halfHeight and axialPos <= halfHeight and t < bestT then
							bestT, found = t, true
						end
					end
				end
			end
		end

		if abs(axisComp) > 1e-8 then
			for _, capOffset in next, {-halfHeight, halfHeight} do
				local t = (capOffset - originAxisComp) / axisComp
				if t >= 0 and t < bestT then
					local hitRadial = originRadial + dirRadial * t
					if vector_dot(hitRadial, hitRadial) <= radius * radius then
						bestT, found = t, true
					end
				end
			end
		end

		return found, found and bestT or 0
	end
end

local getAdornmentWorldCFrame = function(adornment)
	local adornee = adornment.Adornee
	if not adornee then
		return CFrame_identity
	end

	local base
	if adornee:IsA("BasePart") then
		base = adornee.CFrame
	else
		base = adornee:GetPivot()
	end

	return base * adornment.CFrame
end

function Watcher:_internalBeginDrag(input)
	if activeDragWatcher then return end

	activeDragWatcher = self
	self._dragging = true
	self._dragInput = input

	self.DragBegan:Fire(input)
end

function Watcher:_internalEndDrag()
	if activeDragWatcher ~= self then return end

	activeDragWatcher = nil
	self._dragging = false
	self._dragInput = nil

	self.DragEnded:Fire()
	
	updateHover()
end

function Watcher:SetEnabled(enabled)
	self._enabled = enabled
	if not enabled then
		if hoveredWatcher == self then
			self._hovering = false
			self.MouseLeave:Fire()
			hoveredWatcher = nil
		end
		if activeDragWatcher == self then
			self:_internalEndDrag()
		end
	end
end

function Watcher:SetSize(size)
	self._size = size
end

function Watcher:Destroy()
	if hoveredWatcher == self then
		hoveredWatcher = nil
	end
	if activeDragWatcher == self then
		activeDragWatcher = nil
	end

	watchers[self] = nil

	self.MouseEnter:Destroy()
	self.MouseLeave:Destroy()
	self.MouseButton1Down:Destroy()
	self.MouseButton1Up:Destroy()
	self.DragBegan:Destroy()
	self.DragChanged:Destroy()
	self.DragEnded:Destroy()

	disconnectIfIdle()
end

function Watcher.Watch(adornment, opts)
	opts = opts or {}
	local self = setmetatable({}, Watcher)

	local size = opts.Size
	if not opts.HitTest and not size then
		if adornment:IsA("BoxHandleAdornment") then
			size = adornment.Size
			self._sizechanged = adornment:GetPropertyChangedSignal("Size"):Connect(function()
				size = adornment.Size
				self._size = size
			end)
		else
			error("opts.Size or opts.HitTest is required for non-BoxHandleAdornment adornments")
		end
	end

	self._adornment = adornment
	self._size = size or vector_zero
	self._padding = opts.Padding or 0
	self._draggable = opts.Draggable or false
	self._enabled = opts.Enabled ~= false
	self._hovering = false
	self._dragging = false
	self._dragInput = nil
	self._customHitTest = opts.HitTest

	self.MouseEnter = CreateSignal()
	self.MouseLeave = CreateSignal()
	self.MouseButton1Down = CreateSignal()
	self.MouseButton1Up = CreateSignal()
	self.DragBegan = CreateSignal()
	self.DragChanged = CreateSignal()
	self.DragEnded = CreateSignal()

	watchers[self] = true
	ensureConnected()

	return self
end

function Watcher.WatchSphere(adornment, opts)
	opts = opts or {}

	return Watcher.Watch(adornment, {
		Draggable = opts.Draggable,
		Enabled = opts.Enabled,
		HitTest = Watcher.MakeSphereHitTest(
			function() return getAdornmentWorldCFrame(adornment) end,
			function() return adornment.Radius end
		)
	})
end

function Watcher.WatchCylinder(adornment, opts)
	opts = opts or {}

	return Watcher.Watch(adornment, {
		Draggable = opts.Draggable,
		Enabled = opts.Enabled,
		HitTest = Watcher.MakeCylinderHitTest(
			function()
				return getAdornmentWorldCFrame(adornment)
			end,
			adornment.Radius,
			adornment.Height
		)
	})
end

function Watcher.WatchRing(adornment, opts)
	opts = opts or {}
	local extraTolerance = opts.Tolerance or 0.15

	return Watcher.Watch(adornment, {
		Draggable = opts.Draggable,
		Enabled = opts.Enabled,
		HitTest = Watcher.MakeRingHitTest(
			function() return getAdornmentWorldCFrame(adornment) end,
			vector_create(0, 0, 1),
			function() return (adornment.Radius + adornment.InnerRadius) / 2 end,
			function() return (adornment.Radius - adornment.InnerRadius) / 2 + extraTolerance end
		)
	})
end

------------------------------------------------------------------------------------------------------------------------
-- Move Handles
------------------------------------------------------------------------------------------------------------------------
local MoveHandles = {}
MoveHandles.__index = MoveHandles

function MoveHandles.new(adornee)
	local self = setmetatable({}, MoveHandles)
	self.Adornee = adornee
	self._visible = true
	self._holder = newHolder("MoveHandles", GizmoFolder)
	self._watchers = {}
	self._pieces = {}
	self._conns = {}
	self._dragConns = {}
	self.Class = isAllowedClass(adornee)
	self.isWorldSpace = false
	self._dragging = false

	self.Began = CreateSignal()
	self.Changed = CreateSignal()
	self.Ended = CreateSignal()
	self.MouseEnter = CreateSignal()
	self.MouseLeave = CreateSignal()
	
	for _, axis in next, Axes do
		self:_buildAxis(axis)
	end
	
	local originsphere = Instance_new("SphereHandleAdornment")
	originsphere.Name = "origin"
	originsphere.Adornee = self._holder
	originsphere.AlwaysOnTop = true
	originsphere.Color3 = Color3_fromRGB(240, 160, 25)
	originsphere.ZIndex = 0
	originsphere.Radius = 0.1
	originsphere.Transparency = 0.4
	originsphere.Parent = self._holder
	
	self._originsphere = originsphere
	
	self:_syncHolder()
	self._heartbeatConn = Heartbeat:Connect(function()
		self:_syncHolder()
	end)

	return self
end

function MoveHandles:_syncHolder()
	local adornee = self.Adornee
	if self._visible and adornee then
		local class = self.Class
		if class == "BasePart" then
			local cframe = adornee.CFrame
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "PVInstance" then
			local cframe = adornee:GetPivot()
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "Motor6D" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0 * adornee.Transform
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "Joint" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "AnimationConstraint" then
			local att0, att1 = adornee.Attachment0, adornee.Attachment1
			if att0 and att1 then
				local cframe = att0.WorldCFrame * adornee.Transform
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "Attachment" then
			local cframe = adornee.WorldCFrame
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "Bone" then
			local cframe = adornee.WorldCFrame * adornee.Transform
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		end
		self:_updateHandlePositions()
	end
end

function MoveHandles:_buildAxis(axis)
	local configuration = configurations.MoveHandles
	local shaftLen, tipLen, radius = configuration.shaftLength, configuration.tipLength, configuration.Radius
	
	local inputbox = Instance_new("BoxHandleAdornment")
	inputbox.Name = axis.name .. "_InputBox"
	inputbox.Adornee = self._holder
	inputbox.AlwaysOnTop = true
	inputbox.ZIndex = 1
	inputbox.Transparency = 1
	inputbox.CFrame = axisCFrame(axis.dir, shaftLen * 1.5)
	inputbox.Parent = self._holder
	
	local shaft = Instance_new("CylinderHandleAdornment")
	shaft.Name = axis.name .. "_Shaft"
	shaft.Adornee = self._holder
	shaft.Color3 = axis.color
	shaft.Radius = radius
	shaft.Height = shaftLen
	shaft.AlwaysOnTop = true
	shaft.ZIndex = 0
	shaft.Transparency = 0.25
	shaft.CFrame = axisCFrame(axis.dir, shaftLen / 2)
	shaft.Parent = self._holder

	local tip = Instance_new("ConeHandleAdornment")
	tip.Name = axis.name .. "_Tip"
	tip.Adornee = self._holder
	tip.Color3 = axis.color
	tip.Radius = radius * 2.5
	tip.Height = tipLen
	tip.AlwaysOnTop = true
	tip.ZIndex = 0
	tip.Transparency = 0.25
	tip.CFrame = axisCFrame(axis.dir, shaftLen + tipLen / 2) * (CFrame_new(0, 0, -0.45) * CFrame_Angles(3.141592653589793, 0, 0))
	tip.Parent = self._holder

	self._pieces[axis.name] = {
		inputbox = inputbox,
		shaft = shaft,
		tip = tip,
		axis = axis
	}
	
	local watcher = Watcher.Watch(inputbox, {
		Draggable = true,
		Padding = 0.5
	})
	self._watchers[axis.name] = watcher

	local highlight = function(on)
		local c = on and Color3_new(1, 1, 1) or axis.color
		shaft.Color3 = c
		tip.Color3 = c
	end
	
	table_insert(self._conns, watcher.MouseEnter:Connect(function()
		if self._visible then
			highlight(true)
			self.MouseEnter:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseLeave:Connect(function()
		highlight(false)
		if self._visible then
			self.MouseLeave:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Down:Connect(function(input)
		if self._visible then
			highlight(true)
			local type = input.UserInputType
			if (type == MouseButton1 or type == Touch) and self._visible then
				self:_beginDrag(axis, highlight)
			end
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Up:Connect(function()
		highlight(false)
		if self._dragging then
			self.Ended:Fire(axis.name)
		end
	end))
end

function MoveHandles:_updateHandlePositions()
	if not self.Adornee then
		return
	end

	for _, data in next, self._pieces do
		local axis = data.axis
		local inputbox = data.inputbox
		local shaft = data.shaft
		local tip = data.tip
		
		local offset = getAxisOffset(self.Adornee, axis.dir) + 0.5
		
		shaft.CFrame = axisCFrame(axis.dir, offset + shaft.Height * 0.5)
		tip.CFrame = axisCFrame(axis.dir, offset + shaft.Height + tip.Height * 0.5) * CFrame_new(0, 0, -0.45) * CFrame_Angles(3.141592653589793,0,0)
		
		local overallHeight = shaft.Height + tip.Height
		local radius = configurations.MoveHandles.Radius

		inputbox.Size = vector_create(radius * 5, radius * 5, overallHeight)
		inputbox.CFrame = axisCFrame(axis.dir, offset + overallHeight * 0.5)
	end
end

function MoveHandles:_setOtherAxesVisible(activeAxisName, visible)
	for name, p in next, self._pieces do
		local inputbox, shaft, tip = p.inputbox, p.shaft, p.tip
		if name ~= activeAxisName then
			shaft.Visible = visible
			tip.Visible = visible
			inputbox.Visible = visible
		end
	end
end

function MoveHandles:_beginDrag(axis, highlight)
	if self._dragging then return end
	self._dragging = true
	self:_setOtherAxesVisible(axis.name, false)
	
	local adornee = self.Adornee
	local class = self.Class
	
	if not adornee then return end
	if not class then return end

	local startCFrame = getAdorneeCFrame(adornee, class)
	
	local worldDir
	if self.isWorldSpace then
		worldDir = vector_normalize(axis.dir)
	else
		worldDir = vector_normalize(startCFrame:VectorToWorldSpace(axis.dir))
	end
	local origin = startCFrame.Position
	
	local ro, rd = mouseRay()
	local startT = closestT(origin, worldDir, ro, rd)

	self.Began:Fire(axis.name)
	
	local watcher = self._watchers[axis.name]

	local moveConn = watcher.DragChanged:Connect(function(o2, d2)
		local t = closestT(origin, worldDir, o2, d2)
		local delta = worldDir * (t - startT)
		local newCF = startCFrame + delta
		if class == "BasePart" then
			adornee.CFrame = newCF
		elseif class == "PVInstance" then
			adornee:PivotTo(newCF)
		elseif class == "Motor6D" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "Joint" then
			adornee.C0 = adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "AnimationConstraint" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Attachment0.WorldCFrame:ToObjectSpace(newCF)
		elseif class == "Attachment" then
			adornee.CFrame = adornee.Parent.CFrame:ToObjectSpace(newCF)
		elseif class == "Bone" then
			local parentWorld
			if bone.Parent:IsA("Bone") then
				parentWorld = bone.Parent.WorldCFrame
			else
				parentWorld = bone.Parent.CFrame
			end
			adornee.Transform = adornee.CFrame:Inverse() * parentWorld:ToObjectSpace(newCF)
		end
		self:_syncHolder()
		self.Changed:Fire(axis.name, delta)
	end)

	local upConn
	upConn = watcher.DragEnded:Connect(function(input)
		moveConn:Disconnect()
		upConn:Disconnect()
		self._dragging = false
		highlight(false)
		if self._visible then
			self:_setOtherAxesVisible(axis.name, true)
			self.Ended:Fire(axis.name)
		end
	end)

	table_insert(self._dragConns, moveConn)
	table_insert(self._dragConns, upConn)
end

function MoveHandles:SetAdornee(adornee)
	self.Adornee = adornee
	self.Class = isAllowedClass(adornee)
	if self._visible then
		self:_setOtherAxesVisible("", true)
	end
	self:_syncHolder()
end

function MoveHandles:SetVisible(bool)
	self._visible = bool
	self:_setOtherAxesVisible("", bool)
	self._originsphere.Visible = bool
end

function MoveHandles:SetWorldSpace(bool)
	self.isWorldSpace = bool
	self:_syncHolder()
end

function MoveHandles:Destroy()
	for _, c in next, self._conns do c:Disconnect() end
	for _, c in next, self._dragConns do c:Disconnect() end
	for _, i in next, self._watchers do i:Destroy() end
	
	self._heartbeatConn:Disconnect()
	
	self._holder:Destroy()
	
	table_clear(self._conns)
	table_clear(self._dragConns)
	table_clear(self._pieces)
	table_clear(self._watchers)
	
	self.Began:Destroy()
	self.Changed:Destroy()
	self.Ended:Destroy()
	self.MouseEnter:Destroy()
	self.MouseLeave:Destroy()
	
	table_clear(self)
	setmetatable(self, nil)
end

------------------------------------------------------------------------------------------------------------------------
-- Rotate Handles
------------------------------------------------------------------------------------------------------------------------
local RotateHandles = {}
RotateHandles.__index = RotateHandles

function RotateHandles.new(adornee)
	local self = setmetatable({}, RotateHandles)
	self.Adornee = adornee
	self._visible = false
	self._holder = newHolder("RotateHandles", GizmoFolder)
	self._rings = {}
	self._conns = {}
	self._dragConns = {}
	self._watchers = {}
	self.Class = isAllowedClass(adornee)
	self.isWorldSpace = false
	self._dragging = false
	
	self.Began = CreateSignal()
	self.Changed = CreateSignal()
	self.Ended = CreateSignal()
	self.MouseEnter = CreateSignal()
	self.MouseLeave = CreateSignal()
	
	for _, axis in next, RotateAxes do
		self:_buildRing(axis)
	end
	
	local originsphere = Instance_new("SphereHandleAdornment")
	originsphere.Name = "origin"
	originsphere.Adornee = self._holder
	originsphere.AlwaysOnTop = true
	originsphere.Color3 = Color3_fromRGB(240, 160, 25)
	originsphere.ZIndex = 0
	originsphere.Radius = 0.1
	originsphere.Transparency = 0.4
	originsphere.Parent = self._holder
	
	self._originsphere = originsphere

	self:_syncHolder()
	self._heartbeatConn = Heartbeat:Connect(function()
		self:_syncHolder()
	end)

	return self
end

function RotateHandles:_syncHolder()
	local adornee = self.Adornee
	if self._visible and adornee then
		local class = self.Class
		if class == "BasePart" then
			local cframe = adornee.CFrame
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "PVInstance" then
			local cframe = adornee:GetPivot()
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "Motor6D" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0 * adornee.Transform
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "Joint" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "AnimationConstraint" then
			local att0, att1 = adornee.Attachment0, adornee.Attachment1
			if att0 and att1 then
				local cframe = att0.WorldCFrame * adornee.Transform
				self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
			end
		elseif class == "Attachment" then
			local cframe = adornee.WorldCFrame
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		elseif class == "Bone" then
			local cframe = adornee.WorldCFrame * adornee.Transform
			self._holder.CFrame = self.isWorldSpace and CFrame_new(cframe.Position) or cframe
		end
		self:_updateRings()
	end
end

function RotateHandles:_buildRing(axis)
	local radius = 3

	local up = abs(axis.dir.Y) < 0.99 and vector_create(0, 1, 0) or vector_create(1, 0, 0)
	local u = vector_normalize(vector_cross(axis.dir, up))
	local v = vector_normalize(vector_cross(axis.dir, u))
	
	local ring = Instance_new("CylinderHandleAdornment")
	ring.Name = axis.name.."_Ring"
	ring.Adornee = self._holder
	ring.Color3 = axis.color
	ring.CFrame = axisCFrame(axis.dir, 0)
	ring.ZIndex = 0
	ring.Transparency = 0.6
	ring.Parent = self._holder
		
	local knob = Instance_new("SphereHandleAdornment")
	knob.Name = axis.name.."_Knob"
	knob.Adornee = self._holder
	knob.AlwaysOnTop = true
	knob.Color3 = axis.color
	knob.ZIndex = 1
	knob.Transparency = 0.2
	knob.Parent = self._holder

	self._rings[axis.name] = {
		ring = ring,
		knob = knob,
		axis = axis
	}
	
	local watcher = Watcher.WatchSphere(knob, {
		Draggable = true,
		Padding = 1
	})
	self._watchers[axis.name] = watcher

	local highlight = function(on)
		knob.Color3 = on and Color3_new(1, 1, 1) or axis.color
	end
	
	table_insert(self._conns, watcher.MouseEnter:Connect(function()
		if self._visible then
			highlight(true)
			self.MouseEnter:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseLeave:Connect(function()
		highlight(false)
		if self._visible then
			self.MouseLeave:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Down:Connect(function(input)
		if self._visible then
			highlight(true)
			local type = input.UserInputType
			if (type == MouseButton1 or type == Touch) and self._visible then
				self:_beginDrag(axis, u, v, radius, highlight)
			end
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Up:Connect(function()
		highlight(false)
		if self._dragging then
			self.Ended:Fire(axis.name)
		end
	end))
end

function RotateHandles:_updateRings()
	local adornee = self.Adornee
	if not adornee then
		return
	end
	
	local radius = getRadius(adornee) + 1
	local thickness = radius * 0.045
	local handleRadius = radius * 0.08
	
	for _, data in next, self._rings do
		local ring = data.ring
		local knob = data.knob
		local axis = data.axis
		
		ring.Radius = radius
		ring.InnerRadius = radius - thickness
		ring.Height = thickness
		ring.CFrame = axisCFrame(axis.dir, 0)
		
		knob.Radius = handleRadius * 2
		local knobOffset = radius + (handleRadius * 2) * 0.6
		knob.CFrame = axisCFrame(axis.kdir, knobOffset)
	end
end

function RotateHandles:_setOtherRingsVisible(activeAxisName, visible)
	for name, p in next, self._rings do
		local ring, knob = p.ring, p.knob
		if name ~= activeAxisName then
			ring.Visible = visible
			knob.Visible = visible
		end
	end
end

function RotateHandles:_beginDrag(axis, u, v, radius, highlight)
	if self._dragging then return end
	self._dragging = true
	self:_setOtherRingsVisible(axis.name, false)
	
	local adornee = self.Adornee
	local class = self.Class
	
	if not adornee then return end
	if not class then return end

	local startCFrame = getAdorneeCFrame(adornee, class)
	
	local center = startCFrame.Position
	local worldNormal, worldU, worldV
	
	if self.isWorldSpace then
		worldNormal = vector_normalize(axis.dir)
		worldU = vector_normalize(u)
		worldV = vector_normalize(v)
	else
		worldNormal = vector_normalize(startCFrame:VectorToWorldSpace(axis.dir))
		worldU = vector_normalize(startCFrame:VectorToWorldSpace(u))
		worldV = vector_normalize(startCFrame:VectorToWorldSpace(v))
	end

	local angleAt = function(ro, rd)
		local hit = rayPlaneHit(ro, rd, center, worldNormal)
		if not hit then return nil end
		local rel = hit - center
		return atan2(vector_dot(rel, worldV), vector_dot(rel, worldU))
	end

	local ro, rd = mouseRay()
	local startAngle = angleAt(ro, rd) or 0
	local lastAngle = startAngle

	self.Began:Fire(axis.name)
	
	local watcher = self._watchers[axis.name]

	local moveConn = watcher.DragChanged:Connect(function(o2, d2)
		local ang = angleAt(o2, d2)
		if not ang then return end

		local step = ang - lastAngle
		local pi = 3.141592653589793
		if step > pi then step -= pi * 2 end
		if step < -pi then step += pi * 2 end
		lastAngle = ang
		
		local cframe = getAdorneeCFrame(adornee, class)
		local newCF
		if self.isWorldSpace then
			local position = cframe.Position
			newCF = CFrame_new(position) * CFrame_fromAxisAngle(axis.dir, step) * CFrame_new(-position) * pivot
		else
			newCF = cframe * CFrame_fromAxisAngle(axis.dir, step)
		end
		
		if class == "BasePart" then
			adornee.CFrame = newCF
		elseif class == "PVInstance" then
			adornee:PivotTo(newCF)
		elseif class == "Motor6D" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "Joint" then
			adornee.C0 = adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "AnimationConstraint" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Attachment0.WorldCFrame:ToObjectSpace(newCF)
		elseif class == "Attachment" then
			adornee.CFrame = adornee.Parent.CFrame:ToObjectSpace(newCF)
		elseif class == "Bone" then
			local parentWorld
			if bone.Parent:IsA("Bone") then
				parentWorld = bone.Parent.WorldCFrame
			else
				parentWorld = bone.Parent.CFrame
			end
			adornee.Transform = adornee.CFrame:Inverse() * parentWorld:ToObjectSpace(newCF)
		end
		
		self:_syncHolder()
		self.Changed:Fire(axis.name, step)
	end)

	local upConn
	upConn = watcher.DragEnded:Connect(function()
		moveConn:Disconnect()
		upConn:Disconnect()
		self._dragging = false
		highlight(false)
		if self._visible then
			self:_setOtherRingsVisible(axis.name, true)
			self.Ended:Fire(axis.name)
		end
	end)
	
	table_insert(self._dragConns, moveConn)
	table_insert(self._dragConns, upConn)
end

function RotateHandles:SetAdornee(adornee)
	self.Adornee = adornee
	self.Class = isAllowedClass(adornee)
	if self._visible then
		self:_setOtherRingsVisible("", true)
	end
	self:_syncHolder()
end

function RotateHandles:SetVisible(bool)
	self._visible = bool
	self:_setOtherRingsVisible("", bool)
	self._originsphere.Visible = bool
end

function RotateHandles:SetWorldSpace(bool)
	self.isWorldSpace = bool
	self:_syncHolder()
end

function RotateHandles:Destroy()
	for _, c in next, self._conns do c:Disconnect() end
	for _, c in next, self._dragConns do c:Disconnect() end
	if self._heartbeatConn then self._heartbeatConn:Disconnect() end
	for _, i in next, self._watchers do i:Destroy() end
	
	self._holder:Destroy()
	
	table_clear(self._conns)
	table_clear(self._dragConns)
	table_clear(self._rings)
	table_clear(self._watchers)
	
	self.Began:Destroy()
	self.Changed:Destroy()
	self.Ended:Destroy()
	self.MouseEnter:Destroy()
	self.MouseLeave:Destroy()
	
	table_clear(self)
	setmetatable(self, nil)
end

------------------------------------------------------------------------------------------------------------------------
-- Resize Handles
------------------------------------------------------------------------------------------------------------------------
local ResizeHandles = {}
ResizeHandles.__index = ResizeHandles

local axisExtent = function(size, dir)
	return abs(dir.X) * size.X + abs(dir.Y) * size.Y + abs(dir.Z) * size.Z
end

local withAxisAligned = function(size, dir, newValue)
	local mask = vector_create(abs(dir.X), abs(dir.Y), abs(dir.Z))
	local keep = vector_one - mask
	return size * keep + mask * newValue
end

function ResizeHandles.new(adornee)
	local self = setmetatable({}, ResizeHandles)
	self.Adornee = adornee
	self._visible = true
	self._holder = newHolder("ResizeHandles", GizmoFolder)
	self._cubes = {}
	self._conns = {}
	self._dragConns = {}
	self._watchers = {}
	self.isValid = adornee and adornee:IsA("BasePart")
	self._dragging = false

	self.Began = CreateSignal()
	self.Changed = CreateSignal()
	self.Ended = CreateSignal()
	self.MouseEnter = CreateSignal()
	self.MouseLeave = CreateSignal()
	
	for _, axis in next, ResizeAxes do
		self:_buildHandle(axis)
	end

	self:_syncHolder()
	self._heartbeatConn = Heartbeat:Connect(function()
		self:_syncHolder()
	end)

	return self
end

function ResizeHandles:_syncHolder()
	if self._visible and self.Adornee and self.isValid then
		self._holder.CFrame = self.Adornee.CFrame
		self:_reposition()
	end
end

function ResizeHandles:_buildHandle(axis)
	local cube = Instance_new("BoxHandleAdornment")
	cube.Name = axis.name
	cube.Adornee = self._holder
	cube.Size = vector_one * 0.4
	cube.Color3 = Color3_fromRGB(80, 140, 255)
	cube.AlwaysOnTop = true
	cube.ZIndex = 1
	cube.Parent = self._holder
	
	self._cubes[axis.name] = {
		cube = cube,
		axis = axis
	}

	local watcher = Watcher.Watch(cube, {
		Draggable = true,
		Padding = 0.4
	})
	self._watchers[axis.name] = watcher
	
	local highlight = function(on)
		cube.Color3 = on and Color3_new(1, 1, 1) or Color3_fromRGB(80, 140, 255)
		cube.Size = vector_one * (on and 0.5 or 0.4)
	end
	
	table_insert(self._conns, watcher.MouseEnter:Connect(function()
		if self._visible then
			highlight(true)
			self.MouseEnter:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseLeave:Connect(function()
		highlight(false)
		if self._visible then
			self.MouseLeave:Fire(axis.name)
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Down:Connect(function(input)
		if self._visible then
			highlight(true)
			local type = input.UserInputType
			if (type == MouseButton1 or type == Touch) and self._visible then
				self:_beginDrag(axis, highlight)
			end
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Up:Connect(function()
		highlight(false)
		if self._dragging then
			self.Ended:Fire(axis.name)
		end
	end))

	self:_reposition()
end

function ResizeHandles:_reposition()
	local adornee = self.Adornee
	if not adornee then
		return
	end
	
	local size = adornee.Size
	for _, c in next, self._cubes do
		local axis = c.axis
		local offset = getAxisOffset(self.Adornee, axis.dir) + 0.5
		c.cube.CFrame = axisCFrame(axis.dir, offset)
	end
end

function ResizeHandles:_setOtherAxesVisible(activeAxisName, visible)
	for _, c in next, self._cubes do
		if c.axis.name ~= activeAxisName then
			c.cube.Visible = visible
		end
	end
end

function ResizeHandles:_beginDrag(axis, highlight)
	if self._dragging then return end
	self._dragging = true
	self:_setOtherAxesVisible(axis.name, false)
	
	if not self.Adornee then return end

	local startCFrame = self.Adornee.CFrame
	local startSize = self.Adornee.Size
	local worldNormal = vector_normalize(startCFrame:VectorToWorldSpace(axis.dir))
	local faceCenter = startCFrame.Position + worldNormal * (axisExtent(startSize, axis.dir) / 2)

	local ro, rd = mouseRay()
	local startT = closestT(faceCenter, worldNormal, ro, rd)

	self.Began:Fire(axis.name)
	
	local watcher = self._watchers[axis.name]
	local startAxisSize = axisExtent(startSize, axis.dir)

	local moveConn = watcher.DragChanged:Connect(function(o2, d2)
		local t = closestT(faceCenter, worldNormal, o2, d2)
		local sizeDelta = t - startT

		local newAxisSize = clamp(startAxisSize + sizeDelta, 0, 2048)
		local appliedDelta = newAxisSize - startAxisSize

		self.Adornee.Size = withAxisAligned(startSize, axis.dir, newAxisSize)
		self.Adornee.CFrame = startCFrame * CFrame_new(axis.dir * (appliedDelta / 2))
		self:_syncHolder()

		self.Changed:Fire(axis.name, self.Adornee.Size)
	end)

	local upConn
	upConn = watcher.DragEnded:Connect(function()
		moveConn:Disconnect()
		upConn:Disconnect()
		self._dragging = false
		highlight(false)
		self:_setOtherAxesVisible(axis.name, true)
		self.Ended:Fire(axis.name)
	end)
	
	table_insert(self._dragConns, moveConn)
	table_insert(self._dragConns, upConn)
end

function ResizeHandles:SetAdornee(part)
	self.Adornee = part
	self.isValid = adornee and adornee:IsA("BasePart")
	self:_setOtherAxesVisible("", true)
	self:_syncHolder()
end

function ResizeHandles:SetVisible(bool)
	self._visible = bool
	self:_setOtherAxesVisible("", bool)
end

function ResizeHandles:Destroy()
	for _, c in next, self._conns do c:Disconnect() end
	for _, c in next, self._dragConns do c:Disconnect() end
	if self._heartbeatConn then self._heartbeatConn:Disconnect() end
	for _, i in next, self._watchers do i:Destroy() end
	
	self._holder:Destroy()
	
	table_clear(self._conns)
	table_clear(self._dragConns)
	table_clear(self._rings)
	table_clear(self._watchers)
	
	self.Began:Destroy()
	self.Changed:Destroy()
	self.Ended:Destroy()
	self.MouseEnter:Destroy()
	self.MouseLeave:Destroy()
	
	table_clear(self)
	setmetatable(self, nil)
end

------------------------------------------------------------------------------------------------------------------------
-- Arcball
------------------------------------------------------------------------------------------------------------------------
local Arcball = {}
Arcball.__index = Arcball

local GetArcballVector = function(mousePos, viewportSize)
	local x = (mousePos.X / viewportSize.X) * 2 - 1
	local y = 1 - (mousePos.Y / viewportSize.Y) * 2

	local length2 = x*x + y*y

	if length2 <= 1 then
		return vector_create(x, y, sqrt(1 - length2))
	else
		local length = sqrt(length2)
		return vector_create(x / length, y / length, 0)
	end
end

local RotationBetween = function(v1, v2)
	local axis = vector_cross(v1, v2)
	local axisMag = vector_magnitude(axis)

	local dot = clamp(vector_dot(v1, v2), -1, 1)

	if axisMag < 1e-6 then
		if dot < -0.999 then
			local fallbackAxis = vector_cross(v1, vector_create(0, 1, 0))
			if vector_magnitude(fallbackAxis) < 1e-6 then
				fallbackAxis = vector_cross(v1, vector_create(1, 0, 0))
			end
			return CFrame_fromAxisAngle(vector_normalize(fallbackAxis), 3.141592653589793)
		end
		return CFrame_identity
	end

	local angle = acos(dot)
	return CFrame_fromAxisAngle(vector_normalize(axis), angle)
end

function Arcball.new(adornee)
	local self = setmetatable({}, Arcball)
	self.Adornee = adornee
	self._visible = true
	self._holder = newHolder("Arcball", GizmoFolder)
	self._conns = {}
	self._dragConns = {}
	self._arcs = {}
	self._lastTouchCount = 0
	self.Class = isAllowedClass(adornee)
	self._dragging = false

	self.Began = CreateSignal()
	self.Changed = CreateSignal()
	self.Ended = CreateSignal()
	self.MouseEnter = CreateSignal()
	self.MouseLeave = CreateSignal()
	
	self:_buildAdornment()
	
	local originsphere = Instance_new("SphereHandleAdornment")
	originsphere.Name = "origin"
	originsphere.Adornee = self._holder
	originsphere.AlwaysOnTop = true
	originsphere.Color3 = Color3_fromRGB(240, 160, 25)
	originsphere.ZIndex = 0
	originsphere.Radius = 0.1
	originsphere.Transparency = 0.4
	originsphere.Parent = self._holder
	
	self._originsphere = originsphere

	self:_syncHolder()
	self._heartbeatConn = Heartbeat:Connect(function()
		self:_syncHolder()
	end)

	return self
end

function Arcball:_syncHolder()
	local adornee = self.Adornee
	if self._visible and adornee then
		local class = self.Class
		if class == "BasePart" then
			local cframe = adornee.CFrame
			self._holder.CFrame = cframe
		elseif class == "PVInstance" then
			local cframe = adornee:GetPivot()
			self._holder.CFrame = cframe
		elseif class == "Motor6D" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0 * adornee.Transform
				self._holder.CFrame = cframe
			end
		elseif class == "Joint" then
			local part0, part1 = adornee.Part0, adornee.Part1
			if part0 and part1 then
				local cframe = part0.CFrame * adornee.C0
				self._holder.CFrame = cframe
			end
		elseif class == "AnimationConstraint" then
			local att0, att1 = adornee.Attachment0, adornee.Attachment1
			if att0 and att1 then
				local cframe = att0.WorldCFrame * adornee.C0 * adornee.Transform
				self._holder.CFrame = cframe
			end
		elseif class == "Attachment" then
			local cframe = adornee.WorldCFrame
			self._holder.CFrame = cframe
		elseif class == "Bone" then
			local cframe = adornee.WorldCFrame * adornee.Transform
			self._holder.CFrame = cframe
		end
		self:_update()
	end
end

function Arcball:_buildAdornment()
	local outlinepart = newHolder("outlinepart", self._holder)
	
	local outlinering = Instance_new("CylinderHandleAdornment")
	outlinering.Name = "outline"
	outlinering.Adornee = outlinepart
	outlinering.AlwaysOnTop = true
	outlinering.Color3 = Color3_new(1, 1, 1)
	outlinering.ZIndex = 1
	outlinering.Transparency = 0.3
	outlinering.Parent = self._holder
	
	local inputsphere = Instance_new("SphereHandleAdornment")
	inputsphere.Name = "trackSphere"
	inputsphere.Adornee = outlinepart
	inputsphere.AlwaysOnTop = true
	inputsphere.ZIndex = 2
	inputsphere.Transparency = 1
	inputsphere.Parent = self._holder
	
	local sphere = Instance_new("SphereHandleAdornment")
	sphere.Name = "innerline"
	sphere.Adornee = outlinepart
	sphere.AlwaysOnTop = true
	sphere.Color3 = Color3_new(1, 1, 1)
	sphere.ZIndex = 1
	sphere.Transparency = 0.6
	sphere.Parent = self._holder
	
	local rings = {
		{name = "X", dir = vector_create(1, 0, 0), color = Color3_fromRGB(255, 70, 70)},
		{name = "Y", dir = vector_create(0, 1, 0), color = Color3_fromRGB(80, 255, 80)},
		{name = "Z", dir = vector_create(0, 0, 1), color = Color3_fromRGB(80, 140, 255)}
	}
	
	for _, data in next, rings do
		local ring = Instance_new("CylinderHandleAdornment")
		ring.Name = data.name.."_ring"
		ring.Adornee = self._holder
		ring.Color3 = data.color
		ring.CFrame = axisCFrame(data.dir, 0)
		ring.AlwaysOnTop = true
		ring.ZIndex = 0
		ring.Angle = 180
		ring.Transparency = 0.5
		ring.Parent = self._holder
		
		self._arcs[data.name] = ring
	end
	
	self._arcs.outline = outlinering
	self._arcs.sphere = sphere
	self._arcs.inputsphere = inputsphere
	self._arcs.outlinepart = outlinepart
	
	local watcherdata = {
		Draggable = true,
		Padding = 5
	}
	local watcher = Watcher.WatchSphere(inputsphere, watcherdata)
	
	self._watcherdata = watcherdata
	self._watcher = watcher
	
	local highlight = function(on)
		
	end
	
	table_insert(self._conns, watcher.MouseEnter:Connect(function()
		if self._visible then
			highlight(true)
			self.MouseEnter:Fire()
		end
	end))
	table_insert(self._conns, watcher.MouseLeave:Connect(function()
		highlight(false)
		if self._visible then
			self.MouseLeave:Fire()
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Down:Connect(function(input)
		if self._visible then
			highlight(true)
			local type = input.UserInputType
			if (type == MouseButton1 or type == Touch) and self._visible then
				self:_beginDrag(highlight)
			end
		end
	end))
	table_insert(self._conns, watcher.MouseButton1Up:Connect(function()
		highlight(false)
		if self._dragging then
			self.Ended:Fire()
		end
	end))
end

function Arcball:_update()
	local adornee = self.Adornee
	local class = self.Class
	
	if not adornee then return end
	if not class then return end
	
	local radius = getRadius(adornee)
	local thickness = radius * 0.045
	local handleRadius = radius * 0.08
	
	for name, obj in next, self._arcs do
		if name == "X" or name == "Y" or name == "Z" then
			obj.Radius = radius
			obj.InnerRadius = radius - thickness
			obj.Height = thickness
		end
	end
	
	self._watcherdata.Padding = radius
	self._arcs.inputsphere.Radius = radius
	self._arcs.sphere.Radius = radius / 1.25
	self._arcs.outline.Radius = radius
	self._arcs.outline.InnerRadius = radius - thickness
	self._arcs.outline.Height = thickness
	
	if Camera then
		local cframe = getAdorneeCFrame(adornee, class)
		local look = Camera.CFrame.LookVector

		self._arcs.outlinepart.CFrame = CFrame_lookAt(cframe.Position, cframe.Position + look, Camera.CFrame.UpVector)
	end
end

function Arcball:_beginDrag(highlight)
	if self._dragging then return end
	self._dragging = true
	
	local adornee = self.Adornee
	local class = self.Class
	
	if not adornee then return end
	if not class then return end
	
	local startLocalVector = GetArcballVector(UserInputService:GetMouseLocation(), Camera.ViewportSize)
	local worldStart = Camera.CFrame:VectorToWorldSpace(startLocalVector)
	local startCFrame = getAdorneeCFrame(adornee, class)
	
	self.Began:Fire()
	
	local watcher = self._watcher

	local moveConn = watcher.DragChanged:Connect(function()
		local currentLocalVector = GetArcballVector(UserInputService:GetMouseLocation(), Camera.ViewportSize)
		local worldCurrent = Camera.CFrame:VectorToWorldSpace(currentLocalVector)
		local rotation = RotationBetween(worldStart, worldCurrent)
		local position = startCFrame.Position
		
		local newCF = CFrame_new(position) * rotation * CFrame_new(-position) * startCFrame
		if class == "BasePart" then
			adornee.CFrame = newCF
		elseif class == "PVInstance" then
			adornee:PivotTo(newCF)
		elseif class == "Motor6D" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "Joint" then
			adornee.C0 = adornee.Part0.CFrame:ToObjectSpace(newCF)
		elseif class == "AnimationConstraint" then
			adornee.Transform = adornee.C0:Inverse() * adornee.Attachment0.WorldCFrame:ToObjectSpace(newCF)
		elseif class == "Attachment" then
			adornee.CFrame = adornee.Parent.CFrame:ToObjectSpace(newCF)
		elseif class == "Bone" then
			local parentWorld
			if bone.Parent:IsA("Bone") then
				parentWorld = bone.Parent.WorldCFrame
			else
				parentWorld = bone.Parent.CFrame
			end
			adornee.Transform = adornee.CFrame:Inverse() * parentWorld:ToObjectSpace(newCF)
		end
		
		self:_syncHolder()
		self.Changed:Fire()
	end)

	local upConn
	upConn = watcher.DragEnded:Connect(function()
		moveConn:Disconnect()
		upConn:Disconnect()
		self._dragging = false
		highlight(false)
		self.Ended:Fire()
	end)
	
	table_insert(self._dragConns, moveConn)
	table_insert(self._dragConns, upConn)
end

function Arcball:SetAdornee(adornee)
	self.Adornee = adornee
	self.Class = isAllowedClass(adornee)
	self:_syncHolder()
end

function Arcball:SetVisible(bool)
	self._visible = bool
	for name, obj in next, self._arcs do
		if name ~= "outlinepart" then
			obj.Visible = bool
		end
	end
	self._originsphere.Visible = bool
end

function Arcball:Destroy()
	for _, c in next, self._conns do c:Disconnect() end
	for _, c in next, self._dragConns do c:Disconnect() end
	if self._heartbeatConn then self._heartbeatConn:Disconnect() end
	self._watcher:Destroy()
	
	self._holder:Destroy()
	
	table_clear(self._conns)
	table_clear(self._dragConns)
	table_clear(self._arcs)
	
	self.Began:Destroy()
	self.Changed:Destroy()
	self.Ended:Destroy()
	self.MouseEnter:Destroy()
	self.MouseLeave:Destroy()
	
	table_clear(self)
	setmetatable(self, nil)
end

return {MoveHandles = MoveHandles, RotateHandles = RotateHandles, ResizeHandles = ResizeHandles, Arcball = Arcball}
