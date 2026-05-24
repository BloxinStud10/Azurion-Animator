--tis a fork of BoatTween :p

local env = (getfenv and getfenv()) or _G
local cenv = env.Azurion or {}
local settings = cenv.settings

local BLACK_COLOR3 = Color3.new()
local CFRAME_ZERO = CFrame.identity

local C3Lerp = BLACK_COLOR3.Lerp
local CLerp = CFRAME_ZERO.Lerp

local function Color3Lerp(C0, C1, Alpha)
	if settings.BetterColor3Lerp then
		local L0, U0, V0
		local R0, G0, B0 = C0.R, C0.G, C0.B
		R0 = R0 < 0.0404482362771076 and R0 / 12.92 or 0.87941546140213 * (R0 + 0.055) ^ 2.4
		G0 = G0 < 0.0404482362771076 and G0 / 12.92 or 0.87941546140213 * (G0 + 0.055) ^ 2.4
		B0 = B0 < 0.0404482362771076 and B0 / 12.92 or 0.87941546140213 * (B0 + 0.055) ^ 2.4
	
		local Y0 = 0.2125862307855956 * R0 + 0.71517030370341085 * G0 + 0.0722004986433362 * B0
		local Z0 = 3.6590806972265883 * R0 + 11.4426895800574232 * G0 + 4.1149915024264843 * B0
		local _L0 = Y0 > 0.008856451679035631 and 116 * Y0 ^ (1 / 3) - 16 or 903.296296296296 * Y0
	
		if Z0 > 1E-15 then
			local X = 0.9257063972951867 * R0 - 0.8333736323779866 * G0 - 0.09209820666085898 * B0
			L0, U0, V0 = _L0, _L0 * X / Z0, _L0 * (9 * Y0 / Z0 - 0.46832)
		else
			L0, U0, V0 = _L0, -0.19783 * _L0, -0.46832 * _L0
		end
	
		local L1, U1, V1
		local R1, G1, B1 = C1.R, C1.G, C1.B
		R1 = R1 < 0.0404482362771076 and R1 / 12.92 or 0.87941546140213 * (R1 + 0.055) ^ 2.4
		G1 = G1 < 0.0404482362771076 and G1 / 12.92 or 0.87941546140213 * (G1 + 0.055) ^ 2.4
		B1 = B1 < 0.0404482362771076 and B1 / 12.92 or 0.87941546140213 * (B1 + 0.055) ^ 2.4
	
		local Y1 = 0.2125862307855956 * R1 + 0.71517030370341085 * G1 + 0.0722004986433362 * B1
		local Z1 = 3.6590806972265883 * R1 + 11.4426895800574232 * G1 + 4.1149915024264843 * B1
		local _L1 = Y1 > 0.008856451679035631 and 116 * Y1 ^ (1 / 3) - 16 or 903.296296296296 * Y1
	
		if Z1 > 1E-15 then
			local X = 0.9257063972951867 * R1 - 0.8333736323779866 * G1 - 0.09209820666085898 * B1
			L1, U1, V1 = _L1, _L1 * X / Z1, _L1 * (9 * Y1 / Z1 - 0.46832)
		else
			L1, U1, V1 = _L1, -0.19783 * _L1, -0.46832 * _L1
		end
	
		local L = (1 - Alpha) * L0 + Alpha * L1
		if L < 0.0197955 then
			return BLACK_COLOR3
		end
	
		local U = ((1 - Alpha) * U0 + Alpha * U1) / L + 0.19783
		local V = ((1 - Alpha) * V0 + Alpha * V1) / L + 0.46832
	
		local Y = (L + 16) / 116
		Y = Y > 0.206896551724137931 and Y * Y * Y or 0.12841854934601665 * Y - 0.01771290335807126
		local X = Y * U / V
		local Z = Y * ((3 - 0.75 * U) / V - 5)
	
		local R = 7.2914074 * X - 1.5372080 * Y - 0.4986286 * Z
		local G = -2.1800940 * X + 1.8757561 * Y + 0.0415175 * Z
		local B = 0.1253477 * X - 0.2040211 * Y + 1.0569959 * Z
	
		if R < 0 and R < G and R < B then
			R, G, B = 0, G - R, B - R
		elseif G < 0 and G < B then
			R, G, B = R - G, 0, B - G
		elseif B < 0 then
			R, G, B = R - B, G - B, 0
		end
	
		R = R < 3.1306684425E-3 and 12.92 * R or 1.055 * R ^ (1 / 2.4) - 0.055 -- 3.1306684425E-3
		G = G < 3.1306684425E-3 and 12.92 * G or 1.055 * G ^ (1 / 2.4) - 0.055
		B = B < 3.1306684425E-3 and 12.92 * B or 1.055 * B ^ (1 / 2.4) - 0.055
	
		R = R > 1 and 1 or R < 0 and 0 or R
		G = G > 1 and 1 or G < 0 and 0 or G
		B = B > 1 and 1 or B < 0 and 0 or B
	
		return Color3.new(R, G, B)
	else
		return C3Lerp(C0, C1, Alpha)
	end
end

return {
	boolean = function(V0, V1, Alpha)
		if Alpha < 0.5 then
			return V0
		else
			return V1
		end
	end,
	number = math.lerp,
	string = function(A, B, Alpha)
		Alpha = math.clamp(Alpha, 0, 1)
		
		local len = math.max(#A, #B)
		local t = table.create(len)
		
		local switchPoint = math.floor(len * alpha)
		
		for i = 1, len do
			if i <= switchPoint then
				t[i] = string.sub(b, i, i)
			else
				t[i] = string.sub(a, i, i)
			end
		end
	
		return table.concat(t)
	end,
	CFrame = CLerp,
	Color3 = Color3Lerp,
	NumberRange = function(V0, V1, Alpha)
		local Min0, Max0 = V0.Min, V0.Max
		local DeltaMin, DeltaMax = V1.Min - Min0, V1.Max - Max0

		return NumberRange.new(Min0 + Alpha * DeltaMin, Max0 + Alpha * DeltaMax)
	end,
	PhysicalProperties = function(V0, V1, Alpha)
		local D0, E0, EW0, F0, FW0 = V0.Density, V0.Elasticity, V0.ElasticityWeight, V0.Friction, V0.FrictionWeight

		local DD, DE, DEW, DF, DFW = V1.Density - D0, V1.Elasticity - E0, V1.ElasticityWeight - EW0, V1.Friction - F0, V1.FrictionWeight - FW0

		return PhysicalProperties.new(
			D0 + Alpha * DD,
			E0 + Alpha * DE, EW0 + Alpha * DEW,
			F0 + Alpha * DF, FW0 + Alpha * DFW
		)
	end,
	UDim = function(V0, V1, Alpha)
		local SC, OF = V0.Scale, V0.Offset
		local DSC, DOF = V1.Scale - SC, V1.Offset - OF

		return UDim.new(SC + Alpha * DSC, OF + Alpha * DOF)
	end,
	UDim2 = UDim2.new().Lerp,
	Vector2 = Vector2.new().Lerp,
	Vector3 = vector.lerp,
	NumberSequence = function(V0, V1, Alpha)
		local keypoints = {}
		local addedTimes = {}
		local keylength = 0

		for _, ap in next, V0.Keypoints do
			local closestAbove, closestBelow

			for _, bp in next, V1.Keypoints do
				if bp.Time == ap.Time then
					closestAbove, closestBelow = bp, bp
					break
				elseif bp.Time < ap.Time and (closestBelow == nil or bp.Time > closestBelow.Time) then
					closestBelow = bp
				elseif bp.Time > ap.Time and (closestAbove == nil or bp.Time < closestAbove.Time) then
					closestAbove = bp
				end
			end

			local bValue, bEnvelope
			if closestAbove == closestBelow then
				bValue, bEnvelope = closestAbove.Value, closestAbove.Envelope
			else
				local p = (ap.Time - closestBelow.Time) / (closestAbove.Time - closestBelow.Time)
				bValue = (closestAbove.Value - closestBelow.Value) * p + closestBelow.Value
				bEnvelope = (closestAbove.Envelope - closestBelow.Envelope) * p + closestBelow.Envelope
			end

			keylength += 1
			keypoints[keylength] = NumberSequenceKeypoint.new(ap.Time, (bValue - ap.Value) * Alpha + ap.Value, (bEnvelope - ap.Envelope) * Alpha + ap.Envelope)
			addedTimes[ap.Time] = true
		end

		for _, bp in next, V1.Keypoints do
			if not addedTimes[bp.Time] then
				local closestAbove, closestBelow

				for _, ap in ipairs(V0.Keypoints) do
					if ap.Time == bp.Time then
						closestAbove, closestBelow = ap, ap
						break
					elseif ap.Time < bp.Time and (closestBelow == nil or ap.Time > closestBelow.Time) then
						closestBelow = ap
					elseif ap.Time > bp.Time and (closestAbove == nil or ap.Time < closestAbove.Time) then
						closestAbove = ap
					end
				end

				local aValue, aEnvelope
				if closestAbove == closestBelow then
					aValue, aEnvelope = closestAbove.Value, closestAbove.Envelope
				else
					local p = (bp.Time - closestBelow.Time) / (closestAbove.Time - closestBelow.Time)
					aValue = (closestAbove.Value - closestBelow.Value) * p + closestBelow.Value
					aEnvelope = (closestAbove.Envelope - closestBelow.Envelope) * p + closestBelow.Envelope
				end

				keylength += 1
				keypoints[keylength] = NumberSequenceKeypoint.new(bp.Time, (bp.Value - aValue) * Alpha + aValue, (bp.Envelope - aEnvelope) * Alpha + aEnvelope)
			end
		end

		table.sort(keypoints, SortByTime)
		return NumberSequence.new(keypoints)
	end,
	ColorSequence = function(V0, V1, Alpha)
		local keypoints = {}
		local addedTimes = {}
		local keylength = 0

		for _, ap in next, V0.Keypoints do
			local closestAbove, closestBelow

			for _, bp in next, V1.Keypoints do
				if bp.Time == ap.Time then
					closestAbove, closestBelow = bp, bp
					break
				elseif bp.Time < ap.Time and (closestBelow == nil or bp.Time > closestBelow.Time) then
					closestBelow = bp
				elseif bp.Time > ap.Time and (closestAbove == nil or bp.Time < closestAbove.Time) then
					closestAbove = bp
				end
			end

			local bValue
			if closestAbove == closestBelow then
				bValue = closestAbove.Value
			else
				bValue = Color3Lerp(closestBelow.Value, closestAbove.Value)((ap.Time - closestBelow.Time) / (closestAbove.Time - closestBelow.Time))
			end

			keylength += 1
			keypoints[keylength] = ColorSequenceKeypoint.new(ap.Time, Color3Lerp(ap.Value, bValue)(Alpha))
			addedTimes[ap.Time] = true
		end

		for _, bp in next, V1.Keypoints do
			if not addedTimes[bp.Time] then
				local closestAbove, closestBelow

				for _, ap in next, V0.Keypoints do
					if ap.Time == bp.Time then
						closestAbove, closestBelow = ap, ap
						break
					elseif ap.Time < bp.Time and (closestBelow == nil or ap.Time > closestBelow.Time) then
						closestBelow = ap
					elseif ap.Time > bp.Time and (closestAbove == nil or ap.Time < closestAbove.Time) then
						closestAbove = ap
					end
				end

				local aValue
				if closestAbove == closestBelow then
					aValue = closestAbove.Value
				else
					aValue = Color3Lerp(closestBelow.Value, closestAbove.Value)((bp.Time - closestBelow.Time) / (closestAbove.Time - closestBelow.Time))
				end

				keylength += 1
				keypoints[keylength] = ColorSequenceKeypoint.new(bp.Time, Color3Lerp(bp.Value, aValue)(Alpha))
			end
		end

		table.sort(keypoints, SortByTime)
		return ColorSequence.new(keypoints)
	end
}
