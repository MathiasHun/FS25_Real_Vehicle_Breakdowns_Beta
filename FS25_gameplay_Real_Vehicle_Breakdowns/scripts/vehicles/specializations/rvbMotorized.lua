
rvbMotorized = {}

function rvbMotorized.onPostLoad(self, superFunc, savegame)
    local rvbs = self.spec_faultData
    local spec = self.spec_motorized

    if rvbs == nil or not rvbs.isrvbSpecEnabled then
        return superFunc(self, savegame)
    end

    -- Kihagyjuk a 10%-os refill logikát
	self.rvbDebugger:info("Motorized:onPostLoad", "function overridden by RVB mod.")

	spec.propellantFillUnitIndices = {}
	for _, fillType in pairs({
		FillType.DIESEL,
		FillType.DEF,
		FillType.ELECTRICCHARGE,
		FillType.METHANE
	}) do
		local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
		if spec.consumersByFillTypeName[fillTypeName] ~= nil then
			local propellantFillUnitIndices = spec.propellantFillUnitIndices
			local fillUnitIndex = spec.consumersByFillTypeName[fillTypeName].fillUnitIndex
			table.insert(propellantFillUnitIndices, fillUnitIndex)
		end
	end
	if spec.motor ~= nil then
		spec.motor:postLoad(savegame)
	end
    if type(superFunc) == "function" then
        superFunc(self, savegame)
    end
end
--Motorized.onPostLoad = Utils.overwrittenFunction(Motorized.onPostLoad, rvbMotorized.onPostLoad)

function rvbMotorized.startMotor(self, superFunc, noEventSend)

	local spec = self.spec_motorized
	local rvbs = self.spec_faultData
	
	if rvbs == nil or not rvbs.isrvbSpecEnabled then
		superFunc(self, noEventSend)
		return 
	end

	if not rvbs.rvbMotorStart then
		if self.spec_motorized.motorTemperature.value <= self.currentTemperaturDay then
			self.spec_motorized.motorTemperature.value = self.currentTemperaturDay
		end

		--VehicleBreakdowns:checkGlowPlugFault()
		if self.isServer then
			GlowPlugManager.startMotor(self)
			SelfStarterManager.startMotor(self)

			RVBParts_Event.sendEvent(self, rvbs.parts)
			
			BatteryManager.setBatteryDrainingIfStartMotor(self)
		end
		
		
		-- jelenlegi helye
		rvbs.firstStart = true


		rvbs.rvbMotorStart = true
	end

	superFunc(self, noEventSend)

end

function rvbMotorized.stopMotor(self, superFunc, noEventSend)
	local spec = self.spec_motorized
	local rvbs = self.spec_faultData
	
	if rvbs == nil or not rvbs.isrvbSpecEnabled then
		superFunc(self, noEventSend)
		return 
	end

	if rvbs.rvbMotorStart then
		rvbs.rvbMotorStart = false
	end
	
	for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = rvbs.parts[key]
		if part.runOncePerStart then
			part.runOncePerStart = false
		end
	end

	if self.isServer then

		-- Idozites miatt ha van maradek, azt itt elmentjuk 
		if rvbs.operatingHoursUpdateTimer and rvbs.operatingHoursUpdateTimer > 0 then
			self:updateOperatingHours(rvbs.operatingHoursUpdateTimer, rvbs)
			rvbs.operatingHoursUpdateTimer = 0
		end

		if rvbs.lightingUpdateTimer and rvbs.lightingUpdateTimer > 0 then
			self:updateLightingOperatingHours(rvbs.lightingUpdateTimer, rvbs)
			rvbs.lightingUpdateTimer = 0
		end
	
		if rvbs.wiperUpdateTimer and rvbs.wiperUpdateTimer > 0 then
			self:updateWiperOperatingHours(rvbs.wiperUpdateTimer, rvbs)
			rvbs.wiperUpdateTimer = 0
		end
		
		if rvbs.chargeBatteryUpdateTimer and rvbs.chargeBatteryUpdateTimer > 0 then
			GeneratorManager.chargeBatteryFromGenerator(self, rvbs.chargeBatteryUpdateTimer, nil)
			rvbs.chargeBatteryUpdateTimer = 0
		end

	end

	--if not self:getIsMotorStarted() then
		rvbs.batteryDrainStartMotorTriggered = false
	--end
	--rvbs.batteryDrain = false
	
	if self.isServer then
	--if rvbs.addDamage.alert then
		--rvbs.addDamage.alert = false
		rvbs.alertMessage = {
			inspection = -1,
			service = -1,
			repair = -1
		}
		rvbs.engineLoadWarningTriggered = false
	end

	
	if rvbs.engineStartStop then
		rvbs.ignition = 0
		rvbs.engineStarts = false
		rvbs.motorTries = 0
		rvbs.engineStartStop = false
		rvbs.faultType = 0
		rvbs.firstStart = true
	end

	superFunc(self, noEventSend)
end

function rvbMotorized.updateMotorTemperature(self, superFunc, dt)
    local spec = self.spec_motorized
	local rvb = self.spec_faultData
	
	if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self, dt)
    end
	
	rvb.MotorTemperatureUpdateTimer = (rvb.MotorTemperatureUpdateTimer or 0) + dt
	if rvb.MotorTemperatureUpdateTimer < RVB_DELAY.MOTORTEMPERATURE then return end
	rvb.MotorTemperatureUpdateTimer = 0

	rvb.dirtHeatFactor = (rvb.dirtHeatFactor or 0)
	rvb.dirtHeatExtra = (rvb.dirtHeatExtra or 0)
	rvb.effectiveDirtHeatExtra = (rvb.effectiveDirtHeatExtra or 0)
	--rvb.dirtHeatExtra_temp = (rvb.dirtHeatExtra_temp or 0)
	
	local dirtHeatFactor = 0
	local dirtHeatFactor2 = 0
	local dirtHeatExtra = 0
	local dirt = self.spec_washable and self.spec_washable:getDirtAmount() or 0
	if dirt > 0.99 and rvb.dirtHeatOperatingHours >= g_rvbGameplaySettings.dailyServiceInterval then -- g_rvbGameplaySettings.dailyServiceInterval == DIRT_HEAT_START_HOURS
		local t = (rvb.dirtHeatOperatingHours - g_rvbGameplaySettings.dailyServiceInterval)
			/ (DIRT_HEAT_MAX_HOURS - g_rvbGameplaySettings.dailyServiceInterval)
		rvb.dirtHeatFactor = math.min(math.max(t, 0), 1) * MAX_DIRT_HEAT_BONUS
	--	dirtHeatFactor2 = DIRT_HEAT.MINFACTOR
	--	local t2 = math.min(rvb.dirtHeatOperatingHours, DIRT_HEAT_MAX_HOURS)
	--	dirtHeatFactor2 = DIRT_HEAT.MINFACTOR + (DIRT_HEAT.MAXFACTOR - DIRT_HEAT.MINFACTOR) * (t2 - DIRT_HEAT_START_HOURS) / (DIRT_HEAT_MAX_HOURS - DIRT_HEAT_START_HOURS)
		--dirtHeatExtra = math.min(rvb.dirtHeatOperatingHours, 10)
		rvb.dirtHeatExtra = math.min(DIRT_HEAT.MINFACTOR + rvb.dirtHeatOperatingHours, DIRT_HEAT.MAXFACTOR)
		rvb.dirtHeatExtra_temp = nil
	end

	if dirt < 0.9 then
		-- alapérték
		if rvb.dirtHeatExtra_temp == nil then
			--rvb.effectiveDirtHeatExtra = rvb.dirtHeatExtra or 0
			rvb.dirtHeatExtra_temp = rvb.dirtHeatExtra
			rvb.dirtHeatExtra = 0
		end
		local startDirt = 0.9
		local endDirt   = 0.6
		if dirt <= endDirt then
			-- teljesen eltűnt a hatás
			rvb.effectiveDirtHeatExtra = 0
		else
			-- lineáris visszavonás
			local t = (dirt - endDirt) / (startDirt - endDirt)
			--rvb.effectiveDirtHeatExtra = rvb.dirtHeatExtra * t
			rvb.effectiveDirtHeatExtra = rvb.dirtHeatExtra_temp * math.pow(t, 1.5)
		end
	end


	local fault = rvb.parts[THERMOSTAT].fault
	
	local ambientTemp = g_currentMission.environment.weather:getCurrentTemperature() or self.currentTemperaturDay

	local tempDiff = math.max(-15, math.min(15, ambientTemp - self.currentTemperaturDay))
	local tempFactor = 1 - (tempDiff / 100)

	local gameDt = dt
    -- Heating phase: Calculate heat generated based on load and RPM
    local heatingRate = spec.motorTemperature.heatingPerMS * gameDt
    local loadFactor = (1 + 4 * spec.actualLoadPercentage) / 5
    local rpmFactor = self:getMotorRpmPercentage()

	--local totalHeating = heatingRate * (loadFactor + rpmFactor) * tempFactor
	local totalHeating = heatingRate * (loadFactor + rpmFactor) * tempFactor * (1 + rvb.dirtHeatFactor)

	if fault == "restrictedFlow" then
		totalHeating = totalHeating * 1.1
	end

    spec.motorTemperature.value = math.min(spec.motorTemperature.valueMax, spec.motorTemperature.value + totalHeating)
	
	local coolingFactor = 1 + ((ambientTemp - self.currentTemperaturDay) / 50)
	
	local coolingPenalty = 1.0
	coolingPenalty = coolingPenalty * (1 - rvb.dirtHeatFactor)
	
	if fault == "restrictedFlow" then
		coolingPenalty = 0.5
	end

	-- Dirt alapú coolingPenalty (0 tiszta, 1 koszos)
	coolingPenalty = coolingPenalty * (1 - 0.3 * dirt)
	
	if fault == "restrictedFlow" then
		coolingPenalty = coolingPenalty * 0.75
	end

    -- cooling due to wind Cooling phase: Calculate cooling by wind based on speed
	local windCoolingRate = spec.motorTemperature.coolingByWindPerMS * gameDt * coolingFactor * coolingPenalty
    local speedFactor = math.pow(math.min(1, self:getLastSpeed() / 30), 2)
    spec.motorTemperature.value = math.max(spec.motorTemperature.valueMin, spec.motorTemperature.value - speedFactor * windCoolingRate)

    -- cooling per fan
    if spec.motorTemperature.value > spec.motorFan.enableTemperature then
        spec.motorFan.enabled = true
    end

	-- Hibakezelés: termosztát hibák
	if fault == "stuckClosed" then
		-- Gyakorlatilag nem hűt rendesen, venti nagyon magas hőfokon kapcsol
		--spec.motorFan.enabled = false
		spec.motorFan.enableTemperature = 121
		spec.motorFan.disableTemperature = 100
	elseif fault == "stuckOpen" then
		-- Túl alacsony hőmérsékleten kapcsol venti → motor hidegen fut
		spec.motorFan.enableTemperature = 55
		spec.motorFan.disableTemperature = 30
	elseif fault == "restrictedFlow" then
		local rfExtra = 8
		spec.motorFan.enableTemperature = self.spec_motorized.motorFan.defaultEnableTemp + rfExtra
		spec.motorFan.disableTemperature = self.spec_motorized.motorFan.defaultDisableTemp + rfExtra * 0.8
	elseif rvb.dirtHeatExtra > 0 and rvb.effectiveDirtHeatExtra == 0 then
		local extra = rvb.dirtHeatExtra
		local hysteresis = math.max(3, 10 - extra * 0.4)
		spec.motorFan.enableTemperature = self.spec_motorized.motorFan.defaultEnableTemp + extra
		spec.motorFan.disableTemperature = self.spec_motorized.motorFan.defaultEnableTemp - hysteresis
	elseif rvb.effectiveDirtHeatExtra > 0 then
		local extra = rvb.effectiveDirtHeatExtra
		local hysteresis = math.max(4, 10 - extra * 0.4)
		spec.motorFan.enableTemperature = self.spec_motorized.motorFan.defaultEnableTemp + extra
		spec.motorFan.disableTemperature = self.spec_motorized.motorFan.defaultEnableTemp - hysteresis
	else
		spec.motorFan.enableTemperature = self.spec_motorized.motorFan.defaultEnableTemp
		spec.motorFan.disableTemperature = self.spec_motorized.motorFan.defaultDisableTemp
	end

	if spec.motorFan.enabled and spec.motorTemperature.value < spec.motorFan.disableTemperature then
		spec.motorFan.enabled = false
	end

    -- Cooling phase: Additional cooling by fan if enabled
    if spec.motorFan.enabled then
        local fanCoolingRate = spec.motorFan.coolingPerMS * gameDt * coolingPenalty
        spec.motorTemperature.value = math.max(spec.motorTemperature.valueMin, spec.motorTemperature.value - fanCoolingRate)
    end
end

function rvbMotorized.getCanMotorRunOLD(self, superFunc)
    local rvb = self.spec_faultData
    if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self)
    end
	local maxLifetime = PartManager.getMaxPartLifetime(self, ENGINE)
    local enginePercent = (rvb.parts[ENGINE].operatingHours * 100) / maxLifetime
    local batteryFault = BatteryManager.getBatteryFillLevelPercentage(self)
    local batteryOkay = rvb.batteryCHActive == false and batteryFault >= BATTERY_LEVEL.MOTOR
    local partGlowplug = rvb.parts[GLOWPLUG]
    local shortCircuit = (partGlowplug.fault ~= "empty" and partGlowplug.fault == "shortCircuit")
	local partSelfstarter = rvb.parts[SELFSTARTER]
	
	local pf = partSelfstarter.prefault
	local f = partSelfstarter.fault
	local faultSelfstarter = (
		(pf ~= "empty" and pf == "noEngineCrank") or
		(f ~= "empty" and (f == "noEngineCrank" or f == "starterClickOnly"))
	)

    -- ha már jár a motor, ne állítsa le glowplug miatt
    if self:getMotorState() == MotorState.ON and shortCircuit then
        return true
    end
	--and batteryOkay
	local serviceNone = rvb.service.state == SERVICE_STATE.NONE
	local inspectionNone = rvb.inspection.state == INSPECTION_STATE.NONE
	local repairNone = rvb.repair.state == REPAIR_STATE.NONE
						 -- and not rvb.battery[1]
    if enginePercent < 99 and serviceNone and repairNone and inspectionNone
	 and not shortCircuit and not faultSelfstarter then
        return superFunc(self)
    end
    return false
end
function rvbMotorized.getCanMotorRun(self, superFunc)
    local rvb = self.spec_faultData
    if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self)
    end

	-- ha a motor már ON, akkor hagyjuk futni
	if self:getMotorState() == MotorState.ON then
        return superFunc(self)
    end
	local RUN_STOP_ENGINE = {
		[ENGINE] = {
			overheating = true,
			low_oil_pressure = true,
			engine_shutdown = true,
		},
	}
	for part, faults in pairs(RUN_STOP_ENGINE) do
		local partData = rvb.parts[part]
		if partData and partData.fault ~= "empty" then
			if faults[partData.fault] then
				return false
			end
		end
	end
	local serviceActive = rvb.service.state ~= SERVICE_STATE.NONE
	local inspectionActive = rvb.inspection.state ~= INSPECTION_STATE.NONE
	local repairActive = rvb.repair.state ~= REPAIR_STATE.NONE
    if serviceActive or inspectionActive or repairActive then
        return false
    end

    -- ha nincs leállító hiba, akkor mehet tovább
    return superFunc(self)
end



function rvbMotorized.getMotorNotAllowedWarning(self, superFunc, ...)
    local rvb = self.spec_faultData
    if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self, ...)
    end

	local DEAD_ENGINE_STATE_MESSAGES = {
		inspection = {
			[INSPECTION_STATE.ACTIVE] = "RVB_DEAD_ENGINE_INSPECTION",
			[INSPECTION_STATE.PAUSED] = "RVB_DEAD_ENGINE_SUSPENSION"
		},
		repair = {
			[REPAIR_STATE.ACTIVE] = "RVB_DEAD_ENGINE_REPAIR",
			[REPAIR_STATE.PAUSED] = "RVB_DEAD_ENGINE_SUSPENSION"
		},
		service = {
			[SERVICE_STATE.ACTIVE] = "RVB_DEAD_ENGINE_SERVICE",
			[SERVICE_STATE.PAUSED] = "RVB_DEAD_ENGINE_SUSPENSION"
		}
	}
	local function getDeadEngineMessage(rvb)
		local inspectionMsg = DEAD_ENGINE_STATE_MESSAGES.inspection[rvb.inspection.state]
		if inspectionMsg then
			return g_i18n:getText(inspectionMsg)
		end
		if rvb.inspection.completed then
			local repairMsg = DEAD_ENGINE_STATE_MESSAGES.repair[rvb.repair.state]
			if repairMsg then
				return g_i18n:getText(repairMsg)
			end
		end
		local serviceMsg = DEAD_ENGINE_STATE_MESSAGES.service[rvb.service.state]
		if serviceMsg then
			return g_i18n:getText(serviceMsg)
		end
		return nil
	end
	local msg = getDeadEngineMessage(rvb)
	if msg then
		return msg
	end

	-- Battery check
	--local batteryLevel = BatteryManager.getBatteryFillLevelPercentage(self)
	--if batteryLevel < BATTERY_LEVEL.MOTOR then
	--	return g_i18n:getText("RVB_DEAD_ENGINE_BATTERY")
	--end

	-- 1. konkrét hibák
	local DEAD_ENGINE_FAULTS = {
		[GLOWPLUG] = {
			shortCircuit = true
		},
		[SELFSTARTER] = {
			noEngineCrank = true,
			starterClickOnly = true
		},
		[BATTERY] = {
			internalShort = true
		}
	}
	for part, faults in pairs(DEAD_ENGINE_FAULTS) do
		local partData = rvb.parts[part]
		if partData and partData.fault ~= "empty" then
			if faults[partData.fault] then
				return g_i18n:getText("RVB_DEAD_ENGINE")
			end
		end
	end
	-- 2. elhasználtság miatti motorhalál
	local function isEngineWornOut(rvb, repairNone, self)
		local enginePart = rvb.parts[ENGINE]
		if not enginePart or not repairNone then
			return false
		end
		local maxLifetime = PartManager.getMaxPartLifetime(self, ENGINE)
		if not maxLifetime or maxLifetime <= 0 then
			return false
		end
		local enginePercent = (enginePart.operatingHours * 100) / maxLifetime
		return enginePercent >= 99
	end
	if isEngineWornOut(rvb, repairNone, self) then
		return g_i18n:getText("RVB_DEAD_ENGINE")
	end

    return superFunc(self, ...)
end

function rvbMotorized.getIsActiveForWipers(self, superFunc)
	local rvb = self.spec_faultData
	if rvb ~= nil and rvb.isrvbSpecEnabled then
		if self:isWipersRepairRequired() and self:getMotorState() == MotorState.ON then
			return false
		end
	end
    return superFunc(self)
end
	
function rvbMotorized.updateConsumers(self, superFunc, dt, accInput)
	local v393_ = self.spec_motorized
	--- RVB MOD START
	local rvb = self.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self, dt, accInput)
    end
	--- RVB MOD END
	local v394_ = (v393_.motor.lastMotorRpm - v393_.motor.minRpm) / (v393_.motor.maxRpm - v393_.motor.minRpm)
	local v395_ = 0.5 + v394_ * 0.5
	local v396_ = v393_.smoothedLoadPercentage * v394_
	local v397_ = math.max(v396_, 0)
	local v398_ = 0.5 * (0.2 * v395_ + 1.8 * v397_)
	local v399_ = g_currentMission.missionInfo
	local v400_ = v399_.fuelUsage
	--local v401_ = v400_ == 1 and 1 or (v400_ == 3 and 2.5 or 1.5)
	--- RVB MOD START
    local v401_ = 1.5 -- medium
	if self:isThermostatRepairRequired() or self:isGlowPlugRepairRequired() then
		v401_ = 2.4 -- 160%
	end
    if v400_ == 1 then
        v401_ = 1.0 -- low
		if self:isThermostatRepairRequired() or self:isGlowPlugRepairRequired() then
			v401_ = 1.6
		end
    elseif v400_ == 3 then
        v401_ = 2.5 -- high
		if self:isThermostatRepairRequired() or self:isGlowPlugRepairRequired() then
			v401_ = 4.0
		end
    end
	--- RVB MOD END
	local v402_ = self:getVehicleDamage()
	if v402_ > 0 then
		v401_ = v401_ * (1 + v402_ * Motorized.DAMAGED_USAGE_INCREASE)
	end
	for _, v403_ in pairs(v393_.consumers) do
		if v403_.permanentConsumption and v403_.usage > 0 then
			local v404_ = v401_ * v398_ * v403_.usage * dt
			if v404_ ~= 0 then
				v403_.fillLevelToChange = v403_.fillLevelToChange + v404_
				local v405_ = v403_.fillLevelToChange
				if math.abs(v405_) > 1 then
					v404_ = v403_.fillLevelToChange
					v403_.fillLevelToChange = 0
					local v406_ = self:getFillUnitLastValidFillType(v403_.fillUnitIndex)
					g_farmManager:updateFarmStats(self:getOwnerFarmId(), "fuelUsage", v404_)
					if self:getIsAIActive() and (v406_ == FillType.DIESEL or v406_ == FillType.DEF) and v399_.helperBuyFuel then
						if v406_ == FillType.DIESEL then
							local v407_ = v404_ * g_currentMission.economyManager:getCostPerLiter(v406_) * 1.5
							g_farmManager:updateFarmStats(self:getOwnerFarmId(), "expenses", v407_)
							g_currentMission:addMoney(-v407_, self:getOwnerFarmId(), MoneyType.PURCHASE_FUEL, true)
							v404_ = 0
						else
							v404_ = 0
						end
					end
					if v406_ == v403_.fillType then
						self:addFillUnitFillLevel(self:getOwnerFarmId(), v403_.fillUnitIndex, -v404_, v406_, ToolType.UNDEFINED)
					end
				end
				if v403_.fillType == FillType.DIESEL or (v403_.fillType == FillType.ELECTRICCHARGE or v403_.fillType == FillType.METHANE) then
					v393_.lastFuelUsage = v404_ / dt * 1000 * 60 * 60
				elseif v403_.fillType == FillType.DEF then
					v393_.lastDefUsage = v404_ / dt * 1000 * 60 * 60
				end
			end
		end
	end
	if v393_.consumersByFillTypeName.AIR ~= nil then
		local v408_ = v393_.consumersByFillTypeName.AIR
		if self:getFillUnitLastValidFillType(v408_.fillUnitIndex) == v408_.fillType then
			local v409_ = 0
			local v410_ = self.movingDirection * self:getReverserDirection()
			local v411_
			if v410_ > 0 then
				v411_ = accInput < 0
			else
				v411_ = false
			end
			local v412_
			if v410_ < 0 then
				v412_ = accInput > 0
			else
				v412_ = false
			end
			local v413_
			if self:getLastSpeed() > 1 then
				v413_ = v411_ or v412_
			else
				v413_ = false
			end
			if v413_ then
				local v414_ = math.abs(accInput) * dt * self:getAirConsumerUsage() / 1000
				self:addFillUnitFillLevel(self:getOwnerFarmId(), v408_.fillUnitIndex, -v414_, v408_.fillType, ToolType.UNDEFINED)
				v409_ = v414_ / dt * 1000
			end
			local v415_ = self:getFillUnitFillLevelPercentage(v408_.fillUnitIndex)
			if v415_ < v408_.refillCapacityPercentage then
				v408_.doRefill = true
			elseif v415_ == 1 then
				v408_.doRefill = false
			end
			if v408_.doRefill then
				local v416_ = v408_.refillLitersPerSecond / 1000 * dt
				self:addFillUnitFillLevel(self:getOwnerFarmId(), v408_.fillUnitIndex, v416_, v408_.fillType, ToolType.UNDEFINED)
				v409_ = -v416_ / dt * 1000
			end
			v393_.lastAirUsage = v409_
		end
	end
end
