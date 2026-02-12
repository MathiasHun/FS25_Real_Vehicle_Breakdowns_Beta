
rvbMotorized = {}

function rvbMotorized.onPostLoad(self, superFunc, savegame)
    local rvbs = self.spec_faultData
    local spec = self.spec_motorized

    if rvbs == nil or not rvbs.isrvbSpecEnabled then
        return superFunc(self, savegame)
    end

    -- Kihagyjuk a 10%-os refill logikát
	self.rvbDebugger:info("'Motorized:onPostLoad' function overridden by RVB mod.")

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
		end
		self:setBatteryDrainingIfStartMotor()
		
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
    local batteryFault = self:getBatteryFillLevelPercentage()
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
	--local batteryLevel = self:getBatteryFillLevelPercentage()
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

function rvbMotorized.onUpdateTick(self, superFunc, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local v157_ = self.spec_motorized
	--- RVB MOD START
	local rvb = self.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    end

	--- RVB MOD END
	local v158_ = g_currentMission.missionInfo.automaticMotorStartEnabled
	if self.isServer then
		if not v158_ then
			local v159_ = self:getMotorState()
			if (v159_ == MotorState.STARTING or v159_ == MotorState.ON) and not self:getIsAIActive() then
				local v160_
				if self.getIsEntered == nil then
					v160_ = false
				else
					v160_ = self:getIsEntered()
				end
				local v161_
				if self.getIsControlled == nil then
					v161_ = false
				else
					v161_ = self:getIsControlled()
				end
				if not (v160_ or v161_) then
					local v162_ = false
					for _, v163_ in pairs(g_currentMission.playerSystem.players) do
						if v163_.isControlled and calcDistanceFrom(self.rootNode, v163_.rootNode) < 250 then
							v162_ = true
							break
						end
					end
					if not v162_ then
						for _, v164_ in pairs(g_currentMission.vehicleSystem.enterables) do
							if v164_:getIsInUse(nil) and calcDistanceFrom(self.rootNode, v164_.rootNode) < 250 then
								v162_ = true
								break
							end
						end
					end
					if v162_ then
						v157_.motorStopTimer = v157_.motorStopTimerDuration
					else
						v157_.motorStopTimer = v157_.motorStopTimer - dt
						if v157_.motorStopTimer <= 0 then
							--- RVB MOD START
							Logging.info("[RVB] Override of the automatic engine shutdown function. The engine will not turn off if the player is not near the vehicle.")
							--self:stopMotor()
							--- RVB MOD END
						end
					end
				end
			end
		end
		local v165_ = self:getMotorState()
		if v165_ == MotorState.STARTING or v165_ == MotorState.ON then
			self:updateMotorTemperature(dt)
		end
		if v158_ then
			if v165_ == MotorState.OFF or v165_ == MotorState.IGNITION then
				if not g_ignitionLockManager:getIsAvailable() then
					if (self.getIsControlled ~= nil and self:getIsControlled() or self.getIsEnteredForInput ~= nil and self:getIsEnteredForInput()) and self:getCanMotorRun() then
						self:startMotor(true)
					end
					if self:getRequiresPower() and self:getCanMotorRun() then
						self:startMotor(true)
					end
				end
			elseif self.getIsControlled ~= nil and (not self:getIsControlled() and (self.getIsEnteredForInput ~= nil and not self:getIsEnteredForInput())) then
				if self:getStopMotorOnLeave() then
					v157_.motorNotRequiredTimer = v157_.motorNotRequiredTimer + dt
					if v157_.motorNotRequiredTimer > 250 then
						self:stopMotor(true)
					end
				end
				self:raiseActive()
			end
		end
	end
	if self.isClient then
		local v166_ = self:getMotorState()
		if v166_ == MotorState.STARTING or v166_ == MotorState.ON then
			local v167_ = self:getMotorRpmReal() / v157_.motor:getMaxRpm()
			if v157_.exhaustParticleSystems ~= nil then
				for _, v168_ in pairs(v157_.exhaustParticleSystems) do
					local v169_ = MathUtil.lerp(v157_.exhaustParticleSystems.minScale, v157_.exhaustParticleSystems.maxScale, v167_)
					ParticleUtil.setEmitCountScale(v157_.exhaustParticleSystems, v169_)
					ParticleUtil.setParticleLifespan(v168_, v168_.originalLifespan * v169_)
				end
			end
			for _, v170_ in ipairs(v157_.exhaustFlaps) do
				local v171_ = MathUtil.lerp(-0.1, 0.1, math.random()) + v167_
				local v172_ = math.clamp(v171_, 0, 1) * v170_.maxRot
				if v170_.rotationAxis == 1 then
					setRotation(v170_.node, v172_, 0, 0)
				elseif v170_.rotationAxis == 2 then
					setRotation(v170_.node, 0, v172_, 0)
				else
					setRotation(v170_.node, 0, 0, v172_)
				end
			end
			if v157_.effects ~= nil then
				g_effectManager:setDensity(v157_.effects, v167_)
			end
			if v157_.exhaustEffects ~= nil then
				for _, v173_ in pairs(v157_.exhaustEffects) do
					local v174_, v175_, v176_ = localToWorld(v173_.effectNode, 0, 0.5, 0)
					if v173_.lastPosition == nil then
						v173_.lastPosition = { v174_, v175_, v176_ }
					end
					local v177_ = (v174_ - v173_.lastPosition[1]) * 10
					local v178_ = (v175_ - v173_.lastPosition[2]) * 10
					local v179_ = (v176_ - v173_.lastPosition[3]) * 10
					local v180_, v181_, v182_ = localToWorld(v173_.effectNode, 0, 1, 0)
					local v183_ = v180_ - v177_
					local v184_ = v181_ - v178_ + v173_.upFactor
					local v185_ = v182_ - v179_
					local v186_, v187_, v188_ = worldToLocal(v173_.effectNode, v183_, v184_, v185_)
					local v189_ = MathUtil.vector2Length(v186_, v188_)
					if v189_ > 0 then
						v186_, v188_ = MathUtil.vector2Normalize(v186_, v188_)
					end
					local v190_ = math.max(v187_, 0.01)
					local v191_ = math.abs(v190_)
					local v192_ = v189_ / v191_
					local v193_ = math.atan(v192_) * (1.2 + 2 * v191_)
					local v194_ = v189_ / v191_
					local v195_ = math.atan(v194_) * (1.2 + 2 * v191_)
					local v196_ = v188_ / v191_
					local v197_ = math.atan(v196_) * v193_
					local v198_ = v186_ / v191_
					local v199_ = -math.atan(v198_) * v195_
					v173_.xRot = v173_.xRot * 0.95 + v197_ * 0.05
					v173_.zRot = v173_.zRot * 0.95 + v199_ * 0.05
					local v200_ = MathUtil.lerp(v173_.minRpmScale, v173_.maxRpmScale, v167_)
					setShaderParameter(v173_.effectNode, "param", v173_.xRot, v173_.zRot, 0, v200_, false)
					local v201_ = MathUtil.lerp(v173_.minRpmColor[1], v173_.maxRpmColor[1], v167_)
					local v202_ = MathUtil.lerp(v173_.minRpmColor[2], v173_.maxRpmColor[2], v167_)
					local v203_ = MathUtil.lerp(v173_.minRpmColor[3], v173_.maxRpmColor[3], v167_)
					local v204_ = MathUtil.lerp(v173_.minRpmColor[4], v173_.maxRpmColor[4], v167_)
					setShaderParameter(v173_.effectNode, "exhaustColor", v201_, v202_, v203_, v204_, false)
					v173_.lastPosition[1] = v174_
					v173_.lastPosition[2] = v175_
					v173_.lastPosition[3] = v176_
				end
			end
			v157_.lastFuelUsageDisplayTime = v157_.lastFuelUsageDisplayTime + dt
			if v157_.lastFuelUsageDisplayTime > 250 then
				v157_.lastFuelUsageDisplayTime = 0
				v157_.lastFuelUsageDisplay = v157_.fuelUsageBuffer:getAverage()
			end
			v157_.fuelUsageBuffer:add(v157_.lastFuelUsage)
		end
		if v157_.clutchCrackingTimeOut < g_time then
			if g_soundManager:getIsSamplePlaying(v157_.samples.clutchCracking) then
				g_soundManager:stopSample(v157_.samples.clutchCracking)
			end
			if v157_.clutchCrackingGearIndex ~= nil then
				self:setGearLeversState(0, nil, 500)
			end
			if v157_.clutchCrackingGroupIndex ~= nil then
				self:setGearLeversState(nil, 0, 500)
			end
			v157_.clutchCrackingTimeOut = math.huge
		end
		if isActiveForInputIgnoreSelection then
			if v158_ and not self:getCanMotorRun() then
				local v205_ = self:getMotorNotAllowedWarning()
				if v205_ ~= nil then
					g_currentMission:showBlinkingWarning(v205_, 2000)
				end
			end
			if g_ignitionLockManager:getIsAvailable() and not self:getIsAIActive() then
				local v206_ = g_ignitionLockManager:getState()
				local v207_ = self:getMotorState()
				if v206_ == IgnitionLockState.OFF then
					if v207_ ~= MotorState.OFF then
						self:setMotorState(MotorState.OFF)
					end
				elseif v206_ == IgnitionLockState.IGNITION then
					if v207_ == MotorState.OFF then
						self:setMotorState(MotorState.IGNITION)
					end
				elseif v206_ == IgnitionLockState.START and (v207_ ~= MotorState.STARTING and v207_ ~= MotorState.ON) then
					if self:getCanMotorRun() then
						self:setMotorState(MotorState.STARTING)
					else
						local v208_ = self:getMotorNotAllowedWarning()
						if v208_ ~= nil then
							g_currentMission:showBlinkingWarning(v208_, 2000)
						end
					end
				end
			end
			Motorized.updateActionEvents(self)
		end
	end
end
--Motorized.onUpdateTick = Utils.overwrittenFunction(Motorized.onUpdateTick, rvbMotorized.onUpdateTick)
