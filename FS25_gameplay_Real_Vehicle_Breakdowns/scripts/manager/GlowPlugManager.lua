
GlowPlugManager = {}

local r = FaultRegistry[GLOWPLUG]
local ghud = r.hud
local condition = ghud.condition
local variants = r.variants

function GlowPlugManager.rbv_startMotor(vehicle)
    if not vehicle then return end
    local rvbspec = vehicle.spec_faultData
    if not rvbspec then return end
    if not r.isApplicable(vehicle) then return end
    local specM = vehicle.spec_motorized
    local motorTemp = specM and specM.motorTemperature.value
    if motorTemp and motorTemp > MOTORTEMP_THRESHOLD then
        return
    end

    local part = rvbspec.parts[GLOWPLUG]
    local prefaultName = (part.prefault ~= "empty" and part.prefault) or nil
    if not prefaultName then
        return
    end
    
    local minIgnition, maxIgnition = 1, 4
    
    if prefaultName == "shortCircuit" then
        if math.random(0, 1) == 0 then
            ignition = 0
        else
            ignition = math.random(1, 2)
        end
    else
        if part.prefault ~= "empty" and part.fault == "empty" then
            if vehicle.currentTemperaturDay > 20 then
                ignition = math.random(1, 2)
            elseif vehicle.currentTemperaturDay >= 5 then
                ignition = math.random(2, 3)
            else
                ignition = math.random(3, 4)
            end
        elseif part.prefault ~= "empty" and part.fault ~= "empty" then
            if vehicle.currentTemperaturDay > 20 then
                ignition = math.random(2, 3)
            elseif vehicle.currentTemperaturDay >= 5 then
                ignition = math.random(2, 4)
            else
                ignition = math.random(3, 5)
            end
        end
    end

    return ignition
end
function GlowPlugManager.setVehicleDamage(vehicle, dt)

	local spec = vehicle.spec_faultData
	local RVBSET = g_currentMission.vehicleBreakdowns
	local runtimeIncrease = dt * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
	--if vehicle:getIsFaultGlowPlug() then
		local increase = runtimeIncrease
		if increase ~= 0 then
			spec.glowplugRuntimeToChange = spec.glowplugRuntimeToChange + increase
			local glowplugRuntimeToChange = spec.glowplugRuntimeToChange
			--if math.abs(glowplugRuntimeToChange) > 0.016666 then
				increase = spec.glowplugRuntimeToChange
				spec.glowplugRuntimeToChange = 0
				-- PARTS operatingHours
				for _, partName in ipairs({THERMOSTAT, GENERATOR, ENGINE, BATTERY}) do
					spec.parts[partName].operatingHours = spec.parts[partName].operatingHours + increase
				end
				RVBParts_Event.sendEvent(vehicle, spec.parts)
				--vehicle:raiseDirtyFlags(spec.dirtyFlag)
				if RVBSET:getIsAlertMessage() then
					if vehicle.getIsEntered ~= nil and vehicle:getIsEntered() then
					--	g_currentMission:showBlinkingWarning(g_i18n:getText("RVB_fault_glowplug"), 2500)
					else
					--	g_currentMission.hud:addSideNotification(VehicleBreakdowns.INGAME_NOTIFICATION, string.format(g_i18n:getText("RVB_fault_glowplug_hud"), vehicle:getFullName()), 5000)
					end
				end
			--end
		end
	--end
end
function GlowPlugManager.startMotor(vehicle)
	if vehicle == nil then return end
	local rvbspec = vehicle.spec_faultData
	if rvbspec == nil then return end
	local part = rvbspec.parts[GLOWPLUG]
	-- github issues#112 60 -> 30
	local oneGameMinute = 30
	local wearFactor = 1
	if vehicle.currentTemperaturDay < 5 then
		wearFactor = 1.5
	elseif vehicle.currentTemperaturDay > 20 then
		wearFactor = 0.75
	end
	local maxLifetime = PartManager.getMaxPartLifetime(self, GLOWPLUG)
	if part.operatingHours < maxLifetime then
		part.operatingHours = part.operatingHours + (oneGameMinute / 3600) * wearFactor
	end
end

return GlowPlugManager