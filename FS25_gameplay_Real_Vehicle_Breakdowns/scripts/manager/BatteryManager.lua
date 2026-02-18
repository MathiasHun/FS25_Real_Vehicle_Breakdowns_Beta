
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
	--if not vehicle:getIsMotorStarted() and lightsOk and rvb.isInitialized then
	if lightsOk and rvb.isInitialized then
		if vehicle:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS and vehicle:getBatteryFillLevelPercentage() >= BATTERY_LEVEL.LIGHTS_BEACONS then
			if vehicle.deactivateLights ~= nil then
				vehicle:setLightsTypesMask(0, true, true)
			end
		end
		if vehicle:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS_BEACONS then
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
	local RVBSET = g_currentMission.vehicleBreakdowns
	local activeDrain = BatteryManager.getLightsDrain(vehicle)
	local batteryFillUnitIndex = vehicle:getBatteryFillUnitIndex()
    if activeDrain <= 0 then return end
	local batteryFillLevel = vehicle:getFillUnitFillLevel(batteryFillUnitIndex)
	local drainPerSec = 100 / BATTERY_DRAIN_TIME
	local runtimeIncrease = drainPerSec * activeDrain * (msDelta / 1000) * g_currentMission.missionInfo.timeScale
	spec.batteryDrainAmount = runtimeIncrease
	vehicle:raiseDirtyFlags(spec.batteryDrainDirtyFlag)
	if batteryFillLevel > 0 then
		--if vehicle.isServer then
			vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), batteryFillUnitIndex, -runtimeIncrease, vehicle:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED)
		--end
	end
	end
end

return BatteryManager