local function Linear(T)
	return T
end

local function Bezier(X1, Y1, X2, Y2)
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

	return function(T)
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

			while math.abs(CurrentX) > 0.0000001 and Index < 10 do
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

local PI = 3.141592653589793
local HALF_PI = PI/2

local function RevBack(T)
	T = 1 - T
	return 1 - (math.sin(T*HALF_PI) + (math.sin(T*PI)*(math.cos(T*PI) + 1)/2))
end

local function Linear(T)
	return T
end

-- @specs https://material.io/guidelines/motion/duration-easing.html#duration-easing-natural-easing-curves
local Sharp = Bezier(0.4, 0, 0.6, 1)
local Standard = Bezier(0.4, 0, 0.2, 1) -- used for moving.
local Acceleration = Bezier(0.4, 0, 1, 1) -- used for exiting.
local Deceleration = Bezier(0, 0, 0.2, 1) -- used for entering.

-- @specs https://developer.microsoft.com/en-us/fabric#/styles/web/motion#basic-animations
local FabricStandard = Bezier(0.8, 0, 0.2, 1) -- used for moving.
local FabricAccelerate = Bezier(0.9, 0.1, 1, 0.2) -- used for exiting.
local FabricDecelerate = Bezier(0.1, 0.9, 0.2, 1) -- used for entering.

-- @specs https://docs.microsoft.com/en-us/windows/uwp/design/motion/timing-and-easing
local UWPAccelerate = Bezier(0.7, 0, 1, 0.5)

-- @specs https://www.ibm.com/design/language/elements/motion/basics

-- Productivity and Expression are both essential to an interface. Reserve Expressive motion for occasional, important moments to better capture user’s attention, and offer rhythmic break to the productive experience.
-- Use standard-easing when an element is visible from the beginning to end of a motion. Tiles expanding and table rows sorting are good examples.
local StandardProductive = Bezier(0.2, 0, 0.38, 0.9)
local StandardExpressive = Bezier(0.4, 0.14, 0.3, 1)

-- Use entrance-easing when adding elements to the view such as a modal or toaster appearing, or moving in response to users’ input, such as dropdown opening or toggle. An element quickly appears and slows down to a stop.
local EntranceProductive = Bezier(0, 0, 0.38, 0.9)
local EntranceExpressive = Bezier(0, 0, 0.3, 1)

-- Use exit-easing when removing elements from view, such as closing a modal or toaster. The element speeds up as it exits from view, implying that its departure from the screen is permanent.
local ExitProductive = Bezier(0.2, 0, 1, 0.9)
local ExitExpressive = Bezier(0.4, 0.14, 1, 1)

-- @specs https://design.firefox.com/photon/motion/duration-and-easing.html
local MozillaCurve = Bezier(0.07, 0.95, 0, 1)

local function Smooth(T)
	return T*T*(3 - 2*T)
end

local function Smoother(T)
	return T*T*T*(T*(6*T - 15) + 10)
end

local function RidiculousWiggle(T)
	return math.sin(math.sin(T*PI)*HALF_PI)
end

local function Spring(T)
	return 1 + (-math.exp(-6.9*T)*math.cos(-20.106192982975*T))
end

local function SoftSpring(T)
	return 1 + (-math.exp(-7.5*T)*math.cos(-10.053096491487*T))
end

local function OutBounce(T)
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

local function InBounce(T)
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

local EasingFunctions = setmetatable({
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

	InQuad = function(T)
		return T*T
	end;

	OutQuad = function(T)
		return T*(2 - T)
	end;

	InOutQuad = function(T)
		if T < 0.5 then
			return 2*T*T
		else
			return 2*(2 - T)*T - 1
		end
	end;

	OutInQuad = function(T)
		if T < 0.5 then
			T *= 2
			return T*(2 - T)/2
		else
			T = T*2 - 1
			return T*T / 2 + 0.5
		end
	end;

	InCubic = function(T)
		return T*T*T
	end;

	OutCubic = function(T)
		T -= 1
		return 1 - T*T*T
	end;

	InOutCubic = function(T)
		if T < 0.5 then
			return 4*T*T*T
		else
			T -= 1
			return 1 + 4*T*T*T
		end
	end;

	OutInCubic = function(T)
		if T < 0.5 then
			T = 1 - T*2
			return (1 - T*T*T) / 2
		else
			T = T*2 - 1
			return T*T*T / 2 + 0.5
		end
	end;

	InQuart = function(T)
		return T*T*T*T
	end;

	OutQuart = function(T)
		T -= 1
		return 1 - T*T*T*T
	end;

	InOutQuart = function(T)
		if T < 0.5 then
			T *= T
			return 8*T*T
		else
			T -= 1
			return 1 - 8*T*T*T*T
		end
	end;

	OutInQuart = function(T)
		if T < 0.5 then
			T = T*2 - 1
			return (1 - T*T*T*T)/2
		else
			T = T*2 - 1
			return T*T*T*T / 2 + 0.5
		end
	end;

	InQuint = function(T)
		return T*T*T*T*T
	end;

	OutQuint = function(T)
		T -= 1
		return T*T*T*T*T + 1
	end;

	InOutQuint = function(T)
		if T < 0.5 then
			return 16*T*T*T*T*T
		else
			T -= 1
			return 16*T*T*T*T*T + 1
		end
	end;

	OutInQuint = function(T)
		if T < 0.5 then
			T = T*2 - 1
			return (T*T*T*T*T + 1)/2
		else
			T = T*2 - 1
			return T*T*T*T*T / 2 + 0.5
		end
	end;

	InBack = function(T)
		return T*T*(3*T - 2)
	end;

	OutBack = function(T)
		local TSubOne = T - 1
		return TSubOne*TSubOne*(T*2 + TSubOne) + 1
	end;

	InOutBack = function(T)
		if T < 0.5 then
			return 2*T*T*(2*3*T - 2)
		else
			return 1 + 2*(T - 1)*(T - 1)*(2*3*T - 2 - 2)
		end
	end;

	OutInBack = function(T)
		if T < 0.5 then
			T *= 2
			local TSubOne = T - 1
			return (TSubOne*TSubOne*(T*2 + TSubOne) + 1)/2
		else
			T = T*2 - 1
			return T*T*(3*T - 2)/2 + 0.5
		end
	end;

	InSine = function(T)
		return 1 - math.cos(T*HALF_PI)
	end;

	OutSine = function(T)
		return math.sin(T*HALF_PI)
	end;

	InOutSine = function(T)
		return (1 - math.cos(PI*T))/2
	end;

	OutInSine = function(T)
		if T < 0.5 then
			return math.sin(T*PI)/2
		else
			return (1 - math.cos((T*2 - 1)*HALF_PI))/2 + 0.5
		end
	end;

	OutBounce = OutBounce;
	InBounce = InBounce;

	InOutBounce = function(T)
		if T < 0.5 then
			return InBounce(2*T)/2
		else
			return OutBounce(2*T - 1)/2 + 0.5
		end
	end;

	OutInBounce = function(T)
		if T < 0.5 then
			return OutBounce(2*T)/2
		else
			return InBounce(2*T - 1)/2 + 0.5
		end
	end;

	InElastic = function(T)
		return math.exp((T*0.96380736418812 - 1)*8)*T*0.96380736418812*math.sin(4*T*0.96380736418812)*1.8752275007429
	end;

	OutElastic = function(T)
		return 1 + (math.exp(8*(0.96380736418812 - 0.96380736418812*T - 1))*0.96380736418812*(T - 1)*math.sin(4*0.96380736418812*(1 - T)))*1.8752275007429
	end;

	InOutElastic = function(T)
		if T < 0.5 then
			return (math.exp(8*(2*0.96380736418812*T - 1))*0.96380736418812*T*math.sin(7.71045891350496*T))*1.8752275007429
		else
			return 1 + (math.exp(8*(0.96380736418812*(2 - 2*T) - 1))*0.96380736418812*(T - 1)*math.sin(3.85522945675248*(2 - 2*T)))*1.8752275007429
		end
	end;

	OutInElastic = function(T)
		-- This isn't actually correct, but it is close enough.
		if T < 0.5 then
			T *= 2
			return (1 + (math.exp(8*(0.96380736418812 - 0.96380736418812*T - 1))*0.96380736418812*(T - 1)*math.sin(3.85522945675248*(1 - T)))*1.8752275007429)/2
		else
			T = T*2 - 1
			return (math.exp((T*0.96380736418812 - 1)*8)*T*0.96380736418812*math.sin(4*T*0.96380736418812)*1.8752275007429)/2 + 0.5
		end
	end;

	InExpo = function(T)
		return T*T*math.exp(4*(T - 1))
	end;

	OutExpo = function(T)
		return 1 - (1 - T)*(1 - T)/math.exp(4*T)
	end;

	InOutExpo = function(T)
		if T < 0.5 then
			return 2*T*T*math.exp(4*(2*T - 1))
		else
			return 1 - 2*(T - 1)*(T - 1)*math.exp(4*(1 - 2*T))
		end
	end;

	OutInExpo = function(T)
		if T < 0.5 then
			T *= 2
			return (1 - (1 - T)*(1 - T)/math.exp(4*T))/2
		else
			T = T*2 - 1
			return (T*T*math.exp(4*(T - 1)))/2 + 0.5
		end
	end;

	InCirc = function(T)
		return -(math.sqrt(1 - T*T) - 1)
	end;

	OutCirc = function(T)
		T -= 1
		return math.sqrt(1 - T*T)
	end;

	InOutCirc = function(T)
		T *= 2
		if T < 1 then
			return -(math.sqrt(1 - T*T) - 1)/2
		else
			T -= 2
			return (math.sqrt(1 - T*T) - 1)/2
		end
	end;

	OutInCirc = function(T)
		if T < 0.5 then
			T = T*2 - 1
			return math.sqrt(1 - T*T)/2
		else
			T = T*2 - 1
			return (-(math.sqrt(1 - T*T) - 1))/2 + 0.5
		end
	end;
}, {
	__index = function(_, Index)
		error(tostring(Index) .. " is not a valid easing function.", 2)
	end;
})

local TweenFunctions = {
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

local function Evaluate(Points, T)
	if T <= Points[1][1] then
		return Points[1][2]
	end

	for i = 1, #Points - 1 do
		local a = Points[i]
		local b = Points[i + 1]

		if T >= a[1] and T <= b[1] then
			return math.lerp(a[2], b[2], (T - a[1]) / (b[1] - a[1]))
		end
	end

	return Points[#Points][2]
end

local function NewEasing(Name, Points)
	local EasingTable = TweenFunctions[Name]
	if not EasingTable then
		table.sort(Points, function(a, b)
			return a[1] < b[1]
		end)
		EasingTable = {
			In = function(T)
				return Evaluate(Points, T)
			end,
			Out = function(T)
				return 1 - Evaluate(Points, 1 - T)
			end,
			InOut = function(T)
				if T < 0.5 then
					return Evaluate(Points, T * 2) / 2
				else
					return 1 - Evaluate(Points, (1 - T) * 2) / 2
				end
			end,
			OutIn = function(T)
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

return {
	EasingFunctions = TweenFunctions,
	NewEasing = NewEasing
}
