
BatteryManager = {}

--local r = FaultRegistry[GENERATOR]
--local ghud = r.hud
--local condition = ghud.condition
--local variants = r.variants

local LIGHT_DRAIN = {
    DIM = 0.25,
    HIGH = 0.25,
    WORK_FRONT = 0.15,
    WORK_BACK = 0.15,
    PIPE = 0.10,
    TURN_LEFT = 0.01,
	TURN_RIGHT = 0.01,
	HAZARD = 0.02,
	BEACON = 0.025,
    BRAKE = 0.05,
    REVERSE = 0.05,
    TOP = 0.05,
    BOTTOM = 0.05,
}

BatteryManager.DEFAULT    = bit32.lshift(1, Lights.LIGHT_TYPE_DEFAULT)
BatteryManager.WORK_BACK  = bit32.lshift(1, Lights.LIGHT_TYPE_WORK_BACK)
BatteryManager.WORK_FRONT = bit32.lshift(1, Lights.LIGHT_TYPE_WORK_FRONT)
BatteryManager.HIGHBEAM   = bit32.lshift(1, Lights.LIGHT_TYPE_HIGHBEAM)
BatteryManager.PIPE       = bit32.lshift(1, 4)


local LIGHT_DRAIN_MASK = {
    [BatteryManager.DEFAULT]    = 0.25,
    [BatteryManager.HIGHBEAM]   = 0.25,
    [BatteryManager.WORK_FRONT] = 0.15,
    [BatteryManager.WORK_BACK]  = 0.15,
	[BatteryManager.PIPE]       = 0.10,
}

function BatteryManager.getBatteryFillUnitIndex(self)
    local spec = self.spec_fillUnit
    local batteryFillType = g_fillTypeManager:getFillTypeIndexByName("BATTERYCHARGE")
    for fillUnitIndex, _ in ipairs(spec.fillUnits) do
        if self:getFillUnitAllowsFillType(fillUnitIndex, batteryFillType) then
            return fillUnitIndex
        end
    end
    return nil
end
function BatteryManager.getActiveLights(vehicle)
    local activeLights = {}
    local spec = vehicle.spec_lights
    if not spec then return activeLights end

    --print("getActiveLights")
    
	local LIGHT_TYPES = {
		[0] = "DIM",        -- tompított
		[1] = "WORK_BACK",  -- hátsó munkalámpa
		[2] = "WORK_FRONT", -- első munkalámpa
		[3] = "HIGH",       -- távolsági
	}
	if vehicle.typeName == "combineDrivable" then
		LIGHT_TYPES[4] = "PIPE"
	end

    for bit, name in pairs(LIGHT_TYPES) do
		--print("bit:", bit, "name:", name, "mask:", spec.lightsTypesMask)
        if bit32.band(spec.lightsTypesMask, 2^bit) ~= 0 then
            table.insert(activeLights, name)
        end
    end

    if spec.turnLightState == Lights.TURNLIGHT_LEFT then
        table.insert(activeLights, "TURN_LEFT")
    elseif spec.turnLightState == Lights.TURNLIGHT_RIGHT then
        table.insert(activeLights, "TURN_RIGHT")
    elseif spec.turnLightState == Lights.TURNLIGHT_HAZARD then
        table.insert(activeLights, "HAZARD")
    end

    if spec.beaconLightsActive then
        table.insert(activeLights, "BEACON")
    end
	
	if spec.brakeLightsVisibility then
		table.insert(activeLights, "BRAKE")
	end
	
	if spec.topLightsVisibility then
        --table.insert(activeLights, "TOP")
    end
    local default = 2 ^ Lights.LIGHT_TYPE_DEFAULT
    if bit32.band(spec.lightsTypesMask, default) ~= 0 then
        if spec.topLightsVisibility then
            --local v131_ = 2 ^ spec.additionalLightTypes.topLight
            --lightsTypesMask = bit32.bor(lightsTypesMask, v131_)
        --    table.insert(activeLights, "TOP")
        else
            --local v132_ = 2 ^ spec.additionalLightTypes.bottomLight
            --lightsTypesMask = bit32.bor(lightsTypesMask, v132_)
        --    table.insert(activeLights, "BOTTOM")
        end
    end
	
	if spec.reverseLightsVisibility then
        table.insert(activeLights, "REVERSE")
    end

    return activeLights
end

function BatteryManager.getLightsDrain_OLD(vehicle)
    local active = BatteryManager.getActiveLights(vehicle)
    local total = 0
    for _, light in ipairs(active) do
		--print("Aktív lámpa: " .. light)
        total = total + (LIGHT_DRAIN[light] or 0)
    end
    return total
end


function BatteryManager.getLightsDrain(vehicle)
    local spec = vehicle.spec_lights
    if not spec then return 0 end

    local mask = spec.lightsTypesMask
    local total = 0

    for lightMask, drain in pairs(LIGHT_DRAIN_MASK) do
        if bit32.band(mask, lightMask) ~= 0 then
			--print("lightMask "..lightMask)
            total = total + drain
        end
    end

    -- külön kezelendők (nem maskosak)
    if spec.turnLightState == Lights.TURNLIGHT_LEFT then
        total = total + 0.01
    elseif spec.turnLightState == Lights.TURNLIGHT_RIGHT then
        total = total + 0.01
    elseif spec.turnLightState == Lights.TURNLIGHT_HAZARD then
        total = total + 0.02
    end

    if spec.beaconLightsActive then
        total = total + 0.025
    end

    if spec.brakeLightsVisibility then
        total = total + 0.05
    end

    if spec.reverseLightsVisibility then
        total = total + 0.05
    end
	--print("total "..total)
    return total
end

function BatteryManager.onBatteryDrain(vehicle, dt)
	local rvb = vehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local spec_light = vehicle.spec_lights
	local lightsOk = rvb.parts[LIGHTINGS].fault == "empty"
	if lightsOk and rvb.isInitialized then
		local batteryLevelPercentage = BatteryManager.getBatteryFillLevelPercentage(vehicle)
		if batteryLevelPercentage < BATTERY_LEVEL.LIGHTS and batteryLevelPercentage >= BATTERY_LEVEL.LIGHTS_BEACONS then
			if vehicle.deactivateLights ~= nil then
				vehicle:setLightsTypesMask(0, true, true)
			end
		end
		if batteryLevelPercentage < BATTERY_LEVEL.LIGHTS_BEACONS then
			if vehicle.deactivateBeaconLights ~= nil then
				vehicle:deactivateBeaconLights()
			end
			if vehicle.deactivateLights ~= nil then
				vehicle:deactivateLights()
			end
		end
		if vehicle.isServer then
			local activeDrain = BatteryManager.getLightsDrain(vehicle)
			if activeDrain <= 0 then
				if rvb.batteryDrainAmount > 0 then
					rvb.batteryDrainAmount = 0
					vehicle:raiseDirtyFlags(rvb.batteryDrainDirtyFlag)
				end
				return
			end
			rvb.batteryDrainUpdateTimer = (rvb.batteryDrainUpdateTimer or 0) + dt
			if rvb.batteryDrainUpdateTimer >= RVB_DELAY.BATTERY_DRAIN then
				BatteryManager.updateBatteryDrain(vehicle, rvb.batteryDrainUpdateTimer, rvb)
				rvb.batteryDrainUpdateTimer = 0
			end
			vehicle:raiseActive()
		end
	end
end
function BatteryManager.updateBatteryDrain(vehicle, msDelta, spec)
	if vehicle.isServer then
		local activeDrain = BatteryManager.getLightsDrain(vehicle)
		local batteryFillUnitIndex = BatteryManager.getBatteryFillUnitIndex(vehicle)
		if batteryFillUnitIndex == nil then return end
		if activeDrain <= 0 then return end
		local batteryFillLevel = vehicle:getFillUnitFillLevel(batteryFillUnitIndex)
		local drainPerSec = 100 / BATTERY_DRAIN_TIME
		local runtimeIncrease = drainPerSec * activeDrain * (msDelta / 1000) * g_currentMission.missionInfo.timeScale
		spec.batteryDrainAmount = runtimeIncrease
		vehicle:raiseDirtyFlags(spec.batteryDrainDirtyFlag)
		if batteryFillLevel > 0 then
			vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), batteryFillUnitIndex, -runtimeIncrease, vehicle:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED)
		end
	end
end

function BatteryManager.setBatteryDrainingIfStartMotor(self)
	local spec = self.spec_faultData
	if spec == nil or spec.batteryDrainStartMotorTriggered then return end

	local batteryFillUnitIndex = BatteryManager.getBatteryFillUnitIndex(self)
	if batteryFillUnitIndex == nil then return end

	local batteryPct = BatteryManager.getBatteryFillLevelPercentage(self)

	-- ==========================
	-- Hideg hatás korrigálása
	-- ==========================
	local temperature = g_currentMission.environment.weather:getCurrentTemperature() -- °C
	local tempFactor = 1.0
	if temperature <= 0 then
		if temperature >= -5 then
			tempFactor = 0.65
		elseif temperature >= -10 then
			tempFactor = 0.55
		else
			tempFactor = 0.4
		end
	end
	local effectiveBatteryPct = batteryPct * tempFactor

	-- ==========================
	-- Alap kisülés meghatározása
	-- ==========================
	local drainValue = 2
	local electricIdx, dieselIdx
	if self.getConsumerFillUnitIndex ~= nil then
		electricIdx = self:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE)
		dieselIdx   = self:getConsumerFillUnitIndex(FillType.DIESEL)
	end
	if electricIdx ~= nil and dieselIdx == nil then
		drainValue = 1
	end

	-- ==========================
	-- Bikázás ellenőrzése
	-- ==========================
	local specJumper = self.spec_jumperCable
	local jumperActive, jumperReady, donorMotor = false, false, false
	if specJumper ~= nil and specJumper.connection ~= nil then
		local conn = specJumper.connection
		jumperActive = true
		jumperReady  = conn.jumperTime >= conn.jumperThreshold
		donorMotor   = conn.donor:getMotorState() == MotorState.ON
	end

	-- ==========================
	-- Hiba logika
	-- ==========================
	if effectiveBatteryPct <= BATTERY_LEVEL.MOTOR then
		-- Bikázás folyamatban
		if jumperActive and not jumperReady and donorMotor then
			drainValue = 0
			self:addBlinkingMessage("low_jumper", "RVB_lowjumper")
		-- Bikakábel csatlakoztva, de Donor motor nem jár
		elseif jumperActive and not donorMotor then
			drainValue = 0
			self:addBlinkingMessage("donorMotor", "RVB_lowjumperDonorMotor")
		-- Alacsony akku / önindító hiba
		elseif not jumperActive or self:getIsFaultSelfStarter() then
			drainValue = 0.5
			self:addBlinkingMessage("low_battery", "RVB_fault_BHlights")
		-- Glowplug hiba
		elseif self:isGlowPlugRepairRequired() then
			drainValue = 1
		end
	end

	-- ==========================
	-- Ellenőrzés és drain alkalmazása
	-- ==========================
	if effectiveBatteryPct < BATTERY_LEVEL.MOTOR or not spec.isInitialized then return end

	local batteryFillLevel = self:getFillUnitFillLevel(batteryFillUnitIndex)
	if batteryFillLevel <= 0 then return end

	drainValue = math.min(drainValue, batteryFillLevel)

	spec.batteryDrainStartMotorTriggered = true

	self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, -drainValue, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)

end

function BatteryManager.batteryChargeVehicle(self)
	if self.isServer then
		local spec = self.spec_faultData
		local CurEnvironment = g_currentMission.environment
		local manualDesc = g_i18n:getText("RVB_WorkshopMessage_batteryDone")
		local entry = {
			entryType = BATTERYS.SERVICE_MANUAL,
			entryTime = CurEnvironment.currentDay,
			operatingHours = spec.totaloperatingHours,
			odometer = 0,
			resultKey = "RVB_WorkshopMessage_batteryDone",
			errorList = {},
			cost = 25
		}
		RVBserviceManual_Event.sendEvent(self, entry)

		local maxLifetime = spec.cachedMaxLifetime[BATTERY]
		if maxLifetime > 0 then
			local usedFraction = spec.parts[BATTERY].operatingHours / maxLifetime
			local batteryHealth = 1
			if usedFraction >= 0.5 then
				batteryHealth = 1 - (usedFraction - 0.5) / 0.5
				batteryHealth = math.max(0.15, batteryHealth)
			end
			local maxBatteryPercent = 100 * batteryHealth
			local batteryFillUnitIndex = BatteryManager.getBatteryFillUnitIndex(self)
			self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, maxBatteryPercent, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)
			g_currentMission:addMoney(-25, self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
			local total, _ = g_farmManager:updateFarmStats(self:getOwnerFarmId(), "repairVehicleCount", 1)
			if total ~= nil then
				g_achievementManager:tryUnlock("VehicleRepairFirst", total)
				g_achievementManager:tryUnlock("VehicleRepair", total)
			end
		else
			self.rvbDebugger:warning("batteryChargeVehicle", "Vehicle '%s': BATTERY maxLifetime not set (using default 0)", self:getFullName())
		end
	end
end
function BatteryManager.onStartChargeBattery(self, dt, isActiveForInputIgnoreSelection)
	if self.isServer then
		local spec = self.spec_faultData
		if spec == nil then return end
		spec.chargeBatteryUpdateTimer = (spec.chargeBatteryUpdateTimer or 0) + dt
		if spec.chargeBatteryUpdateTimer >= RVB_DELAY.BATTERY_DRAIN then
			GeneratorManager.chargeBatteryFromGenerator(self, spec.chargeBatteryUpdateTimer, isActiveForInputIgnoreSelection)
			spec.chargeBatteryUpdateTimer = 0
		end
		self:raiseActive()
	end
end
function BatteryManager.getBatteryFillLevelPercentage(self)
    if self.spec_faultData == nil then
        return 1
    end
    local batteryFillUnitIndex = BatteryManager.getBatteryFillUnitIndex(self)
    if batteryFillUnitIndex ~= nil then
        return tonumber(self:getFillUnitFillLevelPercentage(batteryFillUnitIndex))
    end
    return 1
end
function BatteryManager.isBatteryRepairRequired(self)
    return self:isRepairRequired(BATTERY)
end
return BatteryManager
