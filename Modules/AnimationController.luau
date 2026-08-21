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

const RunService = game:GetService("RunService")
const PreAnimation = RunService.PreAnimation

const Lerp = CFrame_identity.Lerp

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

const StandardProductive = Bezier(0.2, 0, 0.38, 0.9)
const StandardExpressive = Bezier(0.4, 0.14, 0.3, 1)

const EntranceProductive = Bezier(0, 0, 0.38, 0.9)
const EntranceExpressive = Bezier(0, 0, 0.3, 1)

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
		for _, inst in rig:QueryDescendants("Motor6D") do
			onJointAdded(inst)
		end
		for _, inst in rig:QueryDescendants("AnimationConstraint") do
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

return AnimationController
