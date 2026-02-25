
GeneratorManager = {}

local r = FaultRegistry[GENERATOR]
local ghud = r.hud
local condition = ghud.condition
local variants = r.variants

function GeneratorManager.updateColor(hud, part)
	local newColor = hud:getDefaultHudColor()--HUDCOLOR.DEFAULT
	local variantDef = variants[part.fault]
	if variantDef and variantDef.hudcolor then
		newColor = variantDef.hudcolor
	end
	local HUD = hud.battery
	if not HUD.lastColor or not rvb_Utils.colorsAreEqual(HUD.lastColor, newColor) then
		if part.fault ~= "empty" then
			HUD:setColor(unpack(hud:getDefaultHudColor()))
		else
			HUD:setColor(unpack(newColor))
		end
		HUD.lastColor = newColor
    end
end
function GeneratorManager.updateHud(hud, vehicle, dt)
	local HUD = hud.battery
	local currentColor = HUD.lastColor or hud:getDefaultHudColor()--HUDCOLOR.DEFAULT
	local rvb = vehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[GENERATOR]
	if vehicle:getIsMotorStarted() then
		local fault = part and part.fault or "empty"
		if fault ~= HUD.lastFault then
			HUD.timer = 0
			HUD.playCount = 0
			HUD.colorState = false
			HUD.lastFault = fault
		end
		if fault ~= "empty" then
			HUD.timer = (HUD.timer or 0) + dt
			HUD.colorState = HUD.colorState or false
			HUD.playCount = HUD.playCount or 0
			if HUD.playCount < 3 and not part.runOncePerStart then
				if HUD.timer > 1400 then
					if not HUD.colorState then
						HUD:setColor(unpack(currentColor))
						g_soundManager:playSample(rvb.samples.dasalert)
						HUD.playCount = HUD.playCount + 1
						HUD.colorState = true
					end
					HUD.timer = 0
				elseif HUD.timer > 700 then
					if HUD.colorState then
						HUD:setColor(unpack(hud:getDefaultHudColor()))
						HUD.colorState = false
					end
				end
			else
				part.runOncePerStart = true
				if not HUD.lastColorHud or not rvb_Utils.colorsAreEqual(HUD.lastColorHud, currentColor) then
					HUD:setColor(unpack(currentColor))
					HUD.lastColorHud = currentColor
				end
			end
		else
			HUD.timer = 0
			HUD.colorState = false
			HUD.playCount = 0
		end
	else
		HUD.timer = 0
		HUD.colorState = false
		HUD.playCount = 0
	end
end
function GeneratorManager.chargeBatteryFromGenerator(vehicle, dt, isActiveForInputIgnoreSelection)
    local spec = vehicle.spec_faultData
	if spec == nil or not spec.isrvbSpecEnabled then return end
	local partGenerator = spec.parts[GENERATOR]
    local generatorBaseOutput = 60
    local maxGeneratorOutput = 120
	local capacityAh = 100
	local specMotorized = vehicle.spec_motorized
	local specMotorizedM = vehicle.spec_motorized.motor
	local motorState = vehicle:getMotorState()

    if motorState == MotorState.ON then
        if spec.isInitialized and vehicle.getConsumerFillUnitIndex ~= nil and vehicle:getConsumerFillUnitIndex(FillType.DIESEL) ~= nil then
			local batteryFillUnitIndex = BatteryManager.getBatteryFillUnitIndex(vehicle)
            local batteryFillLevel = vehicle:getFillUnitFillLevel(batteryFillUnitIndex)

			-- számítsuk az akkumulátor egészségét 0–1 között
			local maxBatteryLifetime = PartManager.getMaxPartLifetime(vehicle, BATTERY)
			local usedFraction = spec.parts[BATTERY].operatingHours / maxBatteryLifetime

			-- threshold: 50% használat alatt nem romlik a max töltöttség
			local batteryHealth = 1
			if usedFraction >= 0.5 then
				-- 50%-tól kezdve csökken a max töltöttség
				batteryHealth = 1 - (usedFraction - 0.5) / 0.5  -- lineárisan csökken 50%-tól 100%-ig
				batteryHealth = math.max(0.2, batteryHealth)     -- minimum 50%-ra korlátozva
			end
			local maxBatteryPercent = 100 * batteryHealth

			--if batteryFillLevel < 100 then
            if batteryFillLevel < maxBatteryPercent then
			
                local currentRPM = specMotorizedM.lastMotorRpm
                local minRPM = specMotorizedM.minRpm
                local maxRPM = specMotorizedM.maxRpm
				local maxGeneratorLifetime = PartManager.getMaxPartLifetime(vehicle, GENERATOR)
                local efficiencyFactor = math.max(0.1, 1 - (partGenerator.operatingHours / maxGeneratorLifetime))

				local faultName = (partGenerator.prefault ~= "empty" and partGenerator.prefault) or partGenerator.fault
				if faultName and faultName ~= "empty" then
					local variantData = variants[faultName]
					if variantData ~= nil then
						local severity = variantData.severity or 0.5
						local penalty = severity
						efficiencyFactor = math.max(0, 1 - penalty)
					end
				end

                local rpmPercentage = (currentRPM - minRPM) / (maxRPM - minRPM)
                local idleFactor = 0.5
                local rpmFactor = idleFactor + rpmPercentage * (1 - idleFactor)

                local loadFactor = math.max(specMotorized.smoothedLoadPercentage * rpmPercentage, 0)
				local motorFactor = 0.6 * (0.6 * rpmFactor + 2.5 * loadFactor) + 0.4

                if currentRPM < 1000 then
                    --print("A fordulatszám túl alacsony a töltéshez.")
                --    return -- Nem töltjük, ha a fordulatszám alacsony
                end

				local runtimeIncrease = dt * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
				local generatorOutput = generatorBaseOutput + (maxGeneratorOutput - generatorBaseOutput) * loadFactor
				
				local currentA = generatorOutput * motorFactor * efficiencyFactor
				local deltaAh = currentA * runtimeIncrease
				local deltaPercent = (deltaAh / capacityAh) * 100


				spec.batteryChargeAmount = deltaPercent
				vehicle:raiseDirtyFlags(spec.batteryChargeDirtyFlag)
				
				
				--local newFillLevel = math.min(100, batteryFillLevel + deltaPercent)

				-- új töltöttség nem haladhatja meg a max értéket
				local newFillLevel = math.min(maxBatteryPercent, batteryFillLevel + deltaPercent)


				--if vehicle.isServer then
					vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), batteryFillUnitIndex, newFillLevel - batteryFillLevel, vehicle:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)
				--end
				
				--if vehicle.isClient and isActiveForInputIgnoreSelection then
				--	g_currentMission:addExtraPrintText("deltaPercent "..deltaPercent)
				--	g_currentMission:addExtraPrintText("batteryFillLevel "..batteryFillLevel)
				--end
			else
				--if vehicle.isServer then
					if spec.batteryChargeAmount > 0 then
						spec.batteryChargeAmount = 0
						vehicle:raiseDirtyFlags(spec.batteryChargeDirtyFlag)
					end
				--end
            end
        end
    end
end

return GeneratorManager
