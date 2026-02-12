
source(g_vehicleBreakdownsDirectory .. "scripts/enums/InspectionState.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/enums/ServiceState.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/enums/RepairState.lua")
--source(g_vehicleBreakdownsDirectory .. "scripts/enums/JumperCableState.lua") 

source(g_vehicleBreakdownsDirectory .. "scripts/debug/RVBDebug.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/PartManager.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/GlowPlugManager.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/SelfStarterManager.lua")

-- MANAGERS FOR PART FAULTS
source(g_vehicleBreakdownsDirectory .. "scripts/manager/ThermostatManager.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/LightingsManager.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/GeneratorManager.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/manager/EngineManager.lua")

source(g_vehicleBreakdownsDirectory .. "scripts/manager/BatteryManager.lua")

source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/rvbVehicle.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/rvbMotorized.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/rvbWearable.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/rvbWorkshopScreen.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/rvbAIJobVehicle.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/rvbLights.lua")

source(g_vehicleBreakdownsDirectory .. "scripts/placeables/specializations/rvbPlaceableChargingStation.lua")

source(g_vehicleBreakdownsDirectory .. "scripts/events/RVBserviceManual_Event.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/events/WorkshopCount_Event.lua")

source(g_vehicleBreakdownsDirectory .. "scripts/ai/jobs/rvbAIJob.lua")


source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/workshopProcesses/WorkshopService.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/workshopProcesses/WorkshopInspection.lua")
source(g_vehicleBreakdownsDirectory .. "scripts/vehicles/specializations/workshopProcesses/WorkshopRepair.lua")

VehicleBreakdowns = {}


VehicleBreakdowns.TIRE_PRESSURE_LOW = 40  -- kPa
VehicleBreakdowns.TIRE_PRESSURE_NORMAL = 180 -- kPa
VehicleBreakdowns.TIRE_PRESSURE_MIN = 40 -- kPa
VehicleBreakdowns.TIRE_PRESSURE_MAX = 180 -- kPa

VehicleBreakdowns.INCREASE = 1.15
VehicleBreakdowns.FLATE_MULTIPLIER = 0.005
VehicleBreakdowns.MAX_INPUT_MULTIPLIER = 10
VehicleBreakdowns.INPUT_MULTIPLIER_STEP = 0.01

VehicleBreakdowns.INFLATION_PRESSURE = 50 -- Ezt változtathatod

	-- ================================
	-- Helper függvény az egyes flag-ek frissítésére
	-- ================================
	local function updateFlag(self, key, shouldPause)
		local spec = self.spec_faultData
		local data = spec[key]

		if data == nil or data.state == nil then
			return false
		end

		-- ha nincs aktív folyamat → nincs mit csinálni
		if data.state == _G[string.upper(key) .. "_STATE"].NONE then
			return false
		end

		local newState
		if shouldPause then
			newState = _G[string.upper(key) .. "_STATE"].PAUSED
		else
			newState = _G[string.upper(key) .. "_STATE"].ACTIVE
		end

		if data.state ~= newState then
			data.state = newState
			if self.isServer then
				if key == "service" then
					--RVBService_Event.sendEvent(self, data, {result=false, cost=0, text=""})
					self:raiseDirtyFlags(spec.serviceDirtyFlag)
				elseif key == "inspection" then
					--RVBInspection_Event.sendEvent(self, data, {result=false, cost=0, text=""})
					self:raiseDirtyFlags(spec.inspectionDirtyFlag)
				elseif key == "repair" then
					--RVBRepair_Event.sendEvent(self, data, {result=false, cost=0, text=""})
					self:raiseDirtyFlags(spec.repairDirtyFlag)
				end
			end
			return true
		end
		return false
	end

	-- ================================
	-- Percenkénti update ciklus a járműnél
	-- ================================
	local function updateSuspensionState(self, workshopStatus)
		local spec = self.spec_faultData
		local isClosed = not workshopStatus

		local rvbTables = {"service", "inspection", "repair"}
		local anyChanged = false

		for _, key in ipairs(rvbTables) do
			local data = spec[key]
			if data and data.state ~= _G[string.upper(key) .. "_STATE"].NONE then
				if updateFlag(self, key, isClosed) then
					anyChanged = true
				end
			end
		end
		-- opcionális: log, ha bármelyik változott
		if anyChanged then
			--print("Workshop state updated for "..self:getFullName())
		end
	end


function VehicleBreakdowns.prerequisitesPresent(specializations)
	return true
end

local overwrittenFunctions = {
	--{ original = "onPostLoad", replacement = rvbMotorized.onPostLoad },
	{ original = "onUpdateTick", replacement = rvbMotorized.onUpdateTick },
    { original = "updateMotorTemperature", replacement = rvbMotorized.updateMotorTemperature },
    { original = "getCanMotorRun", replacement = rvbMotorized.getCanMotorRun },
	{ original = "getMotorNotAllowedWarning", replacement = rvbMotorized.getMotorNotAllowedWarning },
	{ original = "startMotor", replacement = rvbMotorized.startMotor },
	{ original = "stopMotor", replacement = rvbMotorized.stopMotor },
	{ original = "updateConsumers", replacement = rvbMotorized.updateConsumers },
	{ original = "getIsActiveForWipers", replacement = rvbMotorized.getIsActiveForWipers },
	{ original = "getSpeedLimit", replacement = rvbVehicle.getSpeedLimit },
	{ original = "updateDamageAmount", replacement = rvbWearable.updateDamageAmount },
}
function VehicleBreakdowns.registerOverwrittenFunctions(vehicleType)
	--SpecializationUtil.registerOverwrittenFunction(vehicleType, "setLightsTypesMask", VehicleBreakdowns.setLightsTypesMask)
	for _, func in pairs(overwrittenFunctions) do
        SpecializationUtil.registerOverwrittenFunction(vehicleType, func.original, func.replacement)
    end
end

function VehicleBreakdowns.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onPreLoad", VehicleBreakdowns)
	--SpecializationUtil.registerEventListener(vehicleType, "onRegisterDashboardValueTypes", VehicleBreakdowns)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", VehicleBreakdowns)
end

function VehicleBreakdowns.registerFunctions(vehicleType)

	
	--SpecializationUtil.registerFunction(vehicleType, "setBatteryDrain", VehicleBreakdowns.setBatteryDrain)
	--SpecializationUtil.registerFunction(vehicleType, "onBatteryDrain", VehicleBreakdowns.onBatteryDrain)
	--SpecializationUtil.registerFunction(vehicleType, "updateBatteryDrain", VehicleBreakdowns.updateBatteryDrain)
	--SpecializationUtil.registerFunction(vehicleType, "setBatteryDrainingIfGeneratorFailure", VehicleBreakdowns.setBatteryDrainingIfGeneratorFailure)
	SpecializationUtil.registerFunction(vehicleType, "setBatteryDrainingIfStartMotor", VehicleBreakdowns.setBatteryDrainingIfStartMotor)
	--SpecializationUtil.registerFunction(vehicleType, "StopAI", VehicleBreakdowns.StopAI)
	SpecializationUtil.registerFunction(vehicleType, "DebugFaultPrint", VehicleBreakdowns.DebugFaultPrint)
	SpecializationUtil.registerFunction(vehicleType, "getIsFaultThermostat", VehicleBreakdowns.getIsFaultThermostat)
	
	
	
	--SpecializationUtil.registerFunction(vehicleType, "getIsFaultGenerator", VehicleBreakdowns.getIsFaultGenerator)
	SpecializationUtil.registerFunction(vehicleType, "getIsFaultEngine", VehicleBreakdowns.getIsFaultEngine)
	SpecializationUtil.registerFunction(vehicleType, "getIsFaultSelfStarter", VehicleBreakdowns.getIsFaultSelfStarter)
	

	SpecializationUtil.registerFunction(vehicleType, "getIsFaultOperatingHours", VehicleBreakdowns.getIsFaultOperatingHours)

	SpecializationUtil.registerFunction(vehicleType, "getPartsPercentage", VehicleBreakdowns.getPartsPercentage)
	SpecializationUtil.registerFunction(vehicleType, "getFaultParts", VehicleBreakdowns.getFaultParts)


	SpecializationUtil.registerFunction(vehicleType, "getIsDailyService", VehicleBreakdowns.getIsDailyService)
	--SpecializationUtil.registerFunction(vehicleType, "setIsDailyService", VehicleBreakdowns.setIsDailyService)
	SpecializationUtil.registerFunction(vehicleType, "getIsPeriodicServiceTime", VehicleBreakdowns.getIsPeriodicServiceTime)
	SpecializationUtil.registerFunction(vehicleType, "setIsPeriodicServiceTime", VehicleBreakdowns.setIsPeriodicServiceTime)
	SpecializationUtil.registerFunction(vehicleType, "getIsRepairStartService", VehicleBreakdowns.getIsRepairStartService)
	SpecializationUtil.registerFunction(vehicleType, "getIsRepairClockService", VehicleBreakdowns.getIsRepairClockService)
	SpecializationUtil.registerFunction(vehicleType, "getIsRepairTimeService", VehicleBreakdowns.getIsRepairTimeService)
	SpecializationUtil.registerFunction(vehicleType, "getIsRepairTimePassedService", VehicleBreakdowns.getIsRepairTimePassedService)
	SpecializationUtil.registerFunction(vehicleType, "getIsRepairScaleService", VehicleBreakdowns.getIsRepairScaleService)

	SpecializationUtil.registerFunction(vehicleType, "CalculateFinishTime", VehicleBreakdowns.CalculateFinishTime)
	SpecializationUtil.registerFunction(vehicleType, "calculateCost", VehicleBreakdowns.calculateCost)
	SpecializationUtil.registerFunction(vehicleType, "getRepairPrice_RVBClone", VehicleBreakdowns.getRepairPrice_RVBClone)
	SpecializationUtil.registerFunction(vehicleType, "getServicePrice", VehicleBreakdowns.getServicePrice)
	SpecializationUtil.registerFunction(vehicleType, "getInspectionPrice", VehicleBreakdowns.getInspectionPrice)
	SpecializationUtil.registerFunction(vehicleType, "getSellPrice_RVBClone", VehicleBreakdowns.getSellPrice_RVBClone)
	
	


	
	
	SpecializationUtil.registerFunction(vehicleType, "onStartChargeBattery", VehicleBreakdowns.onStartChargeBattery)
	
	SpecializationUtil.registerFunction(vehicleType, "onStartDirtHeat", VehicleBreakdowns.onStartDirtHeat)
	SpecializationUtil.registerFunction(vehicleType, "updateDirtHeat", VehicleBreakdowns.updateDirtHeat)

	SpecializationUtil.registerFunction(vehicleType, "displayMessage", VehicleBreakdowns.displayMessage)
	--SpecializationUtil.registerFunction(vehicleType, "getIsRVBMotorStarted", VehicleBreakdowns.getIsRVBMotorStarted)


	
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_RVBBattery", VehicleBreakdowns.SyncClientServer_RVBBattery)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_RVBParts", VehicleBreakdowns.SyncClientServer_RVBParts)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_BatteryChargeLevel", VehicleBreakdowns.SyncClientServer_BatteryChargeLevel)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_Other", VehicleBreakdowns.SyncClientServer_Other)

	
	SpecializationUtil.registerFunction(vehicleType, "getBatteryFillUnitIndex", VehicleBreakdowns.getBatteryFillUnitIndex)
	
	SpecializationUtil.registerFunction(vehicleType, "batteryChargeVehicle", VehicleBreakdowns.batteryChargeVehicle)

	--SpecializationUtil.registerFunction(vehicleType, "rvbVehicleSetLifetime", VehicleBreakdowns.rvbVehicleSetLifetime)

	
	
	SpecializationUtil.registerFunction(vehicleType, "updatePartsBreakdowns", VehicleBreakdowns.updatePartsBreakdowns)
	SpecializationUtil.registerFunction(vehicleType, "updatePartsIgnitionBreakdowns", VehicleBreakdowns.updatePartsIgnitionBreakdowns)

	SpecializationUtil.registerFunction(vehicleType, "updatePartsNoBreakdowns", VehicleBreakdowns.updatePartsNoBreakdowns)
	SpecializationUtil.registerFunction(vehicleType, "RVBresetVehicle", VehicleBreakdowns.RVBresetVehicle)
	SpecializationUtil.registerFunction(vehicleType, "setPartsRepairreq", VehicleBreakdowns.setPartsRepairreq)
	
	--SpecializationUtil.registerFunction(vehicleType, "updateTireDeformation", VehicleBreakdowns.updateTireDeformation)
	SpecializationUtil.registerFunction(vehicleType, "adjustSteeringAngle", VehicleBreakdowns.adjustSteeringAngle)
	

	

	--SpecializationUtil.registerFunction(vehicleType, "setInflationPressure", VehicleBreakdowns.setInflationPressure)

	SpecializationUtil.registerFunction(vehicleType, "chargeBatteryViaJumpStart", VehicleBreakdowns.chargeBatteryViaJumpStart)
--	SpecializationUtil.registerFunction(vehicleType, "setRVBJumpStarting", VehicleBreakdowns.setRVBJumpStarting)
	SpecializationUtil.registerFunction(vehicleType, "setRVBJumpchargerate", VehicleBreakdowns.setRVBJumpchargerate)
	


	SpecializationUtil.registerFunction(vehicleType, "onJumperCableMessage", VehicleBreakdowns.onJumperCableMessage)
	SpecializationUtil.registerFunction(vehicleType, "addJumperCableMessage", VehicleBreakdowns.addJumperCableMessage)

	SpecializationUtil.registerFunction(vehicleType, "onBlinkingMessage", VehicleBreakdowns.onBlinkingMessage)
	SpecializationUtil.registerFunction(vehicleType, "addBlinkingMessage", VehicleBreakdowns.addBlinkingMessage)

	SpecializationUtil.registerFunction(vehicleType, "setJumperCableConnection", VehicleBreakdowns.setJumperCableConnection)
	SpecializationUtil.registerFunction(vehicleType, "canBeDonor", VehicleBreakdowns.canBeDonor)

	
	SpecializationUtil.registerFunction(vehicleType, "FillUnit_loadFillUnitFromXML", VehicleBreakdowns.FillUnit_loadFillUnitFromXML)
	
	

	

	SpecializationUtil.registerFunction(vehicleType, "getServiceManualEntry", VehicleBreakdowns.getServiceManualEntry)

	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_serviceManual", VehicleBreakdowns.SyncClientServer_serviceManual)
	
	SpecializationUtil.registerFunction(vehicleType, "updateEngineTorque", VehicleBreakdowns.updateEngineTorque)
	SpecializationUtil.registerFunction(vehicleType, "updateEngineSpeedLimit", VehicleBreakdowns.updateEngineSpeedLimit)
	SpecializationUtil.registerFunction(vehicleType, "updateExhaustEffect", VehicleBreakdowns.updateExhaustEffect)
	SpecializationUtil.registerFunction(vehicleType, "onStartOverheatingFailure", VehicleBreakdowns.onStartOverheatingFailure)
	SpecializationUtil.registerFunction(vehicleType, "updateOverheatingFailure", VehicleBreakdowns.updateOverheatingFailure)
	
	SpecializationUtil.registerFunction(vehicleType, "addBreakdown", VehicleBreakdowns.addBreakdown)
	SpecializationUtil.registerFunction(vehicleType, "delBreakdown", VehicleBreakdowns.delBreakdown)
	
	SpecializationUtil.registerFunction(vehicleType, "onUpdateJumperCable", VehicleBreakdowns.onUpdateJumperCable)
	SpecializationUtil.registerFunction(vehicleType, "onUpdateTickJumperCable", VehicleBreakdowns.onUpdateTickJumperCable)
	


	
	SpecializationUtil.registerFunction(vehicleType, "ignitionMotor", VehicleBreakdowns.ignitionMotor)
	
	
    
    
	SpecializationUtil.registerFunction(vehicleType, "steeringWheels", VehicleBreakdowns.steeringWheels)
	SpecializationUtil.registerFunction(vehicleType, "updateAxisSteer", VehicleBreakdowns.updateAxisSteer)
	
	SpecializationUtil.registerFunction(vehicleType, "isExcluded", VehicleBreakdowns.isExcluded)
	
	

	SpecializationUtil.registerFunction(vehicleType, "minuteChanged", VehicleBreakdowns.minuteChanged)
	SpecializationUtil.registerFunction(vehicleType, "RVBhourChanged", VehicleBreakdowns.RVBhourChanged)

	SpecializationUtil.registerFunction(vehicleType, "onSetPartsLifetime", VehicleBreakdowns.onSetPartsLifetime)
	SpecializationUtil.registerFunction(vehicleType, "applyLifetimeToPart", VehicleBreakdowns.applyLifetimeToPart)
	SpecializationUtil.registerFunction(vehicleType, "onSetDifficulty", VehicleBreakdowns.onSetDifficulty)
	SpecializationUtil.registerFunction(vehicleType, "onSetPlannedDaysPerPeriod", VehicleBreakdowns.onSetPlannedDaysPerPeriod)
	SpecializationUtil.registerFunction(vehicleType, "onWorkshopStateChanged", VehicleBreakdowns.onWorkshopStateChanged)
	SpecializationUtil.registerFunction(vehicleType, "onSleepingStateChanged", VehicleBreakdowns.onSleepingStateChanged)
	SpecializationUtil.registerFunction(vehicleType, "onRVBVehicleReset", VehicleBreakdowns.onRVBVehicleReset)
	SpecializationUtil.registerFunction(vehicleType, "onProgressMessage", VehicleBreakdowns.onProgressMessage)

	
	
	SpecializationUtil.registerFunction(vehicleType, "isRepairRequired", VehicleBreakdowns.isRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isThermostatRepairRequired", VehicleBreakdowns.isThermostatRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isLightingsRepairRequired", VehicleBreakdowns.isLightingsRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isGlowPlugRepairRequired", VehicleBreakdowns.isGlowPlugRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isWipersRepairRequired", VehicleBreakdowns.isWipersRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isGeneratorRepairRequired", VehicleBreakdowns.isGeneratorRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isEngineRepairRequired", VehicleBreakdowns.isEngineRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isSelfStarterRepairRequired", VehicleBreakdowns.isSelfStarterRepairRequired)
	SpecializationUtil.registerFunction(vehicleType, "isBatteryRepairRequired", VehicleBreakdowns.isBatteryRepairRequired)
	
	
	SpecializationUtil.registerFunction(vehicleType, "getIsFaultStates", VehicleBreakdowns.getIsFaultStates)
	
	SpecializationUtil.registerFunction(vehicleType, "getBatteryFillLevelPercentage", VehicleBreakdowns.getBatteryFillLevelPercentage)
	SpecializationUtil.registerFunction(vehicleType, "getVehicleSpeed", VehicleBreakdowns.getVehicleSpeed)
	
	SpecializationUtil.registerFunction(vehicleType, "lightingsFault", VehicleBreakdowns.lightingsFault)
	SpecializationUtil.registerFunction(vehicleType, "onStartLightingsOperatingHours", VehicleBreakdowns.onStartLightingsOperatingHours)
	SpecializationUtil.registerFunction(vehicleType, "updateLightingOperatingHours", VehicleBreakdowns.updateLightingOperatingHours)
	
	SpecializationUtil.registerFunction(vehicleType, "onStartOperatingHours", VehicleBreakdowns.onStartOperatingHours)
	SpecializationUtil.registerFunction(vehicleType, "updateOperatingHours", VehicleBreakdowns.updateOperatingHours)
	
	SpecializationUtil.registerFunction(vehicleType, "onStartWiperOperatingHours", VehicleBreakdowns.onStartWiperOperatingHours)
	SpecializationUtil.registerFunction(vehicleType, "updateWiperOperatingHours", VehicleBreakdowns.updateWiperOperatingHours)

	
	SpecializationUtil.registerFunction(vehicleType, "openHoodForWorkshop", VehicleBreakdowns.openHoodForWorkshop)

	SpecializationUtil.registerFunction(vehicleType, "startInspection", VehicleBreakdowns.startInspection)
	SpecializationUtil.registerFunction(vehicleType, "updateInspection", VehicleBreakdowns.updateInspection)
	SpecializationUtil.registerFunction(vehicleType, "finishInspection", VehicleBreakdowns.finishInspection)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_RVBInspection", VehicleBreakdowns.SyncClientServer_RVBInspection)
	
	SpecializationUtil.registerFunction(vehicleType, "startService", VehicleBreakdowns.startService)
	SpecializationUtil.registerFunction(vehicleType, "updateService", VehicleBreakdowns.updateService)
	SpecializationUtil.registerFunction(vehicleType, "finishService", VehicleBreakdowns.finishService)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_RVBService", VehicleBreakdowns.SyncClientServer_RVBService)
	
	SpecializationUtil.registerFunction(vehicleType, "startRepair", VehicleBreakdowns.startRepair)
	SpecializationUtil.registerFunction(vehicleType, "updateRepair", VehicleBreakdowns.updateRepair)
	SpecializationUtil.registerFunction(vehicleType, "finishRepair", VehicleBreakdowns.finishRepair)
	SpecializationUtil.registerFunction(vehicleType, "SyncClientServer_RVBRepair", VehicleBreakdowns.SyncClientServer_RVBRepair)
	
	SpecializationUtil.registerFunction(vehicleType, "updateEngineCooling", VehicleBreakdowns.updateEngineCooling)
	
	

end



	



function VehicleBreakdowns.initSpecialization()

	-- vehicle schema
	local schema = Vehicle.xmlSchema

    schema:setXMLSpecializationType("VehicleBreakdowns")

	-- savegame schema
	local schemaSavegame = Vehicle.xmlSchemaSavegame

	local rvbSavegameKey = string.format("vehicles.vehicle(?).%s.vehicleBreakdowns", g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.BOOL, rvbSavegameKey .. "#isrvbSpecEnabled", "RVB is enabled")
	schemaSavegame:register(XMLValueType.FLOAT, rvbSavegameKey .. "#TotaloperatingHours", "Összes üzemóra")
	schemaSavegame:register(XMLValueType.FLOAT, rvbSavegameKey .. "#operatingHours", "futott üzemóra")
	schemaSavegame:register(XMLValueType.FLOAT, rvbSavegameKey .. "#dirtHeatOperatingHours", "")

	local parts = ("vehicles.vehicle(?).%s.vehicleBreakdowns.parts"):format(g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.STRING, parts .. ".part(?)#name", "")
	schemaSavegame:register(XMLValueType.FLOAT, parts .. ".part(?)#operatingHours", "Kár")
	schemaSavegame:register(XMLValueType.BOOL, parts .. ".part(?)#repairreq", "Repair is required")
	schemaSavegame:register(XMLValueType.STRING, parts .. ".part(?)#prefault", "Elő hiba")
	schemaSavegame:register(XMLValueType.STRING, parts .. ".part(?)#fault", "Hiba")
	schemaSavegame:register(XMLValueType.FLOAT, parts .. ".part(?)#cost", "Javítási költség")

	local serviceSavegameKey = string.format("vehicles.vehicle(?).%s.vehicleBreakdowns.vehicleService", g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.INT, serviceSavegameKey .. "#state", "Service in progress")
	schemaSavegame:register(XMLValueType.INT, serviceSavegameKey .. "#finishDay", "")
	schemaSavegame:register(XMLValueType.INT, serviceSavegameKey .. "#finishHour", "")
	schemaSavegame:register(XMLValueType.INT, serviceSavegameKey .. "#finishMinute", "")
	schemaSavegame:register(XMLValueType.FLOAT, serviceSavegameKey .. "#cost", "Service cost")

	local inspectionSavegameKey = string.format("vehicles.vehicle(?).%s.vehicleBreakdowns.vehicleInspection", g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.INT, inspectionSavegameKey .. "#state", "Inspection in progress")
	schemaSavegame:register(XMLValueType.INT, inspectionSavegameKey .. "#finishDay", "")
	schemaSavegame:register(XMLValueType.INT, inspectionSavegameKey .. "#finishHour", "")
	schemaSavegame:register(XMLValueType.INT, inspectionSavegameKey .. "#finishMinute", "")
	schemaSavegame:register(XMLValueType.FLOAT, inspectionSavegameKey .. "#cost", "Javítási költség")
	schemaSavegame:register(XMLValueType.INT, inspectionSavegameKey .. "#factor", "")
	schemaSavegame:register(XMLValueType.BOOL, inspectionSavegameKey .. "#completed", "")
	
	local repairSavegameKey = string.format("vehicles.vehicle(?).%s.vehicleBreakdowns.vehicleRepair", g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.INT, repairSavegameKey .. "#state", "Repair in progress")
	schemaSavegame:register(XMLValueType.INT, repairSavegameKey .. "#finishDay", "")
	schemaSavegame:register(XMLValueType.INT, repairSavegameKey .. "#finishHour", "")
	schemaSavegame:register(XMLValueType.INT, repairSavegameKey .. "#finishMinute", "")
	schemaSavegame:register(XMLValueType.FLOAT, repairSavegameKey .. "#cost", "Javítási költség")

	local batterySavegameKey = string.format("vehicles.vehicle(?).%s.vehicleBreakdowns.vehicleBattery", g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.BOOL, batterySavegameKey .. "#state", "Töltés elkezdve")
	schemaSavegame:register(XMLValueType.BOOL, batterySavegameKey .. "#suspension", "Munka szüneteltetés")
	schemaSavegame:register(XMLValueType.INT, batterySavegameKey .. "#finishday", "")
	schemaSavegame:register(XMLValueType.INT, batterySavegameKey .. "#finishhour", "")
	schemaSavegame:register(XMLValueType.INT, batterySavegameKey .. "#finishminute", "")
	schemaSavegame:register(XMLValueType.FLOAT, batterySavegameKey .. "#amount", "Mennyit tölt")
	schemaSavegame:register(XMLValueType.FLOAT, batterySavegameKey .. "#cost", "Töltési költség")

	local serviceManual = ("vehicles.vehicle(?).%s.vehicleBreakdowns.serviceManual"):format(g_vehicleBreakdownsModName)
	schemaSavegame:register(XMLValueType.INT, serviceManual .. ".entry(?)#entryType", "")
	schemaSavegame:register(XMLValueType.INT, serviceManual .. ".entry(?)#entryTime", "")
	schemaSavegame:register(XMLValueType.FLOAT, serviceManual .. ".entry(?)#operatingHours", "")
	schemaSavegame:register(XMLValueType.FLOAT, serviceManual .. ".entry(?)#odometer", "")
	schemaSavegame:register(XMLValueType.STRING, serviceManual .. ".entry(?)#result", "empty")
	schemaSavegame:register(XMLValueType.STRING, serviceManual .. ".entry(?)#resultKey", "empty")
	--schemaSavegame:register(XMLValueType.STRING, serviceManual .. ".entry(?)#errorList", "empty")
	schemaSavegame:register(XMLValueType.INT,   serviceManual .. ".entry(?)#errorCount", "")
	schemaSavegame:register(XMLValueType.STRING, serviceManual .. ".entry(?).error(?)#key", "empty")
	schemaSavegame:register(XMLValueType.FLOAT, serviceManual .. ".entry(?)#cost", "Javítási költség")

	schemaSavegame:setXMLSpecializationType()
end

function VehicleBreakdowns:onPreLoad(savegame)
	--print("onPreLoad " .. self:getFullName() .. " " .. g_rvbGameplaySettings.difficulty)
	--g_messageCenter:publish(MessageType.SET_DIFFICULTY, g_rvbGameplaySettings.difficulty)
	--print("onPreLoad END")
end



function VehicleBreakdowns:isExcluded()
    if not self.configFileName then return false end
    --local modName = self.configFileName:match("mods[/\\]([^/\\]+)")
    --return modName and RVB_EXCLUDEDMODS[modName
	local cfg = self.configFileName
	-- 1) Mod mappanév (mods/)
    local modName = cfg:match("mods[/\\]([^/\\]+)")
    if modName and RVB_EXCLUDEDMODS[modName] then
        return true
    end

    -- 2) DLC mappanév (pdlc/)
    local dlcName = cfg:match("pdlc[/\\]([^/\\]+)")
    if dlcName and RVB_EXCLUDEDMODS[dlcName] then
        return true
    end

    -- 3) Jármű XML neve
    local vehicleFile = cfg:match("([^/\\]+)%.xml$")
    if vehicleFile and RVB_EXCLUDEDMODS[vehicleFile] then
        return true
    end
	
	-- 4) mod könyvtárnév alapján
	for name, _ in pairs(RVB_EXCLUDEDMODS) do
		--local pattern = "[/\\]" .. name .. "[/\\]"
		--local escapedName = name:gsub("/", "[/\\]"):gsub("\\", "[/\\]")
		--local pattern = "[/\\]" .. escapedName .. "[/\\]"
		--if cfg:find(escapedName) then
		local normalizedName = name:gsub("\\", "/")
        local normalizedPath = cfg:gsub("\\", "/")
        if normalizedPath:find(normalizedName, 1, true) then
			return true
		end
	end

	return false
end

function VehicleBreakdowns:onLoad(savegame)

	if self.spec_faultData == nil then
		self.spec_faultData = {}
	end
	
	local spec = self.spec_faultData
	
	
	-- jumper kábel spec létrehozása
	if self.spec_jumperCable == nil then

		self.spec_jumperCable = {
			connection = nil
		}
	end
	
	spec.dirtyFlag						= self:getNextDirtyFlag()
	spec.motorizedDirtyFlag				= self:getNextDirtyFlag()
	spec.motorTemperatureDirtyFlag		= self:getNextDirtyFlag()
	spec.rvbdirtyFlag					= self:getNextDirtyFlag()
	spec.serviceDirtyFlag				= self:getNextDirtyFlag()
	spec.repairDirtyFlag				= self:getNextDirtyFlag()
	spec.inspectionDirtyFlag			= self:getNextDirtyFlag()
	spec.partsDirtyFlag					= self:getNextDirtyFlag()
	spec.lifetimeDirtyFlag				= self:getNextDirtyFlag()
	spec.batteryDrainDirtyFlag			= self:getNextDirtyFlag()
	spec.batteryChargeDirtyFlag			= self:getNextDirtyFlag()
	spec.updateTyreDirtyFlag			= self:getNextDirtyFlag()
	spec.dirtHeatDirtyFlag				= self:getNextDirtyFlag()
	spec.uiEventsDirtyFlag				= self:getNextDirtyFlag()
	spec.motorLoadDirtyFlag				= self:getNextDirtyFlag()
	spec.inflationDirtyFlag				= self:getNextDirtyFlag()
	spec.uiJumperCableMessageDirtyFlag	= self:getNextDirtyFlag()
	spec.uiBlinkingDirtyFlag			= self:getNextDirtyFlag()
	spec.jumperCableDirtyFlag			= self:getNextDirtyFlag()
	

	self.rvbDebugger = g_currentMission.vehicleBreakdowns.rvbDebugger

	spec.messageCenter = g_messageCenter	

	
	spec.isrvbSpecEnabled = true
	spec.totaloperatingHours = 0
	spec.operatingHours = 0
	spec.dirtHeatOperatingHours = 0

	spec.service = {
		state = SERVICE_STATE.NONE,
		finishDay = 0,
		finishHour = 0,
		finishMinute = 0,
		cost = 0
	}
	spec.inspection = {
		state = INSPECTION_STATE.NONE,
		finishDay = 0,
		finishHour = 0,
		finishMinute = 0,
		cost = 0,
		factor = 0,
		completed = false
	}
	spec.repair = {
		state = REPAIR_STATE.NONE,
		finishDay = 0,
		finishHour = 0,
		finishMinute = 0,
		cost = 0
	}
	
	spec.serviceManual = {}
	
	spec.parts = {}
	--[[if self.isServer then
		PartManager.loadPartsFromXML(self, savegame)
		self:raiseDirtyFlags(spec.partsDirtyFlag)
	else
		-- kliens oldalon default inicializálás, hogy ne legyen nil
		for _, partKey in ipairs(g_vehicleBreakdownsPartKeys) do
			spec.parts[partKey] = PartManager.PartsDefaults({name = partKey})
			if partKey == GLOWPLUG then
				spec.parts[partKey].pre_random = math.random(1,5)
			end
		end
	end]]
	PartManager.loadFromDefaultConfig(self)



	spec.preCalculatedRepair = {}
    spec.preCalculatedRepair.day = 0
    spec.preCalculatedRepair.hour = 0
    spec.preCalculatedRepair.minute = 0
    spec.preCalculatedRepair.fault = 0
    spec.preCalculatedRepair.faultTime = 0
	
	
	spec.battery = {}
	spec.battery.drainTimer = 0
	
	spec.rvbupdateTimer = {
		battery = 0,
		repair = 0,
		motorRun = 0
	}

	
    
    

	
    
spec.message = nil

	spec.partsToChange = 0
	spec.serviceToChange = 0
	spec.jumpstartToChange = 0
	spec.jumperTimeToChange = 0
	
	spec.runtimeToChange = 0
	spec.serviceRuntimeToChange = 0
	spec.thermostatoverHeatingRuntimeToChange = 0
	spec.glowplugRuntimeToChange = 0
	spec.wiperRuntimeToChange = 0
	spec.lightingsRuntimeToChange = 0


	spec.partfoot = 0
	spec.rvblightsTypesMask = 0
	

	spec.lightingUpdateTimer = 0
	spec.operatingHoursUpdateTimer = 0
	spec.isRVBMotorStarted = false
	spec.rvbmotorStartTime = 0
	spec.rvbMotorStart = false
	
	
	
	spec.motorTries = 0
	spec.ignition = 0
	spec.engineStarts = false
	spec.engineStartStop = false
	spec.faultType = 0
	spec.firstStart = true
	
	spec.batteryDrainAmount = 0
	spec.batteryChargeAmount = 0
	spec.vehicleDebugEnabled = false
	
	-- load sound effects
	if g_dedicatedServerInfo == nil then
		local file, id
		VehicleBreakdowns.sounds = {}
		for _, id in ipairs({"self_starter", "battery"}) do
			VehicleBreakdowns.sounds[id] = createSample(id)
			file = g_currentMission.vehicleBreakdowns.modDirectory.."sounds/"..id..".ogg"
			loadSample(VehicleBreakdowns.sounds[id], file, false)
		end
	end
	
	

	local xmlSoundFile = loadXMLFile("rvbsounds", g_currentMission.vehicleBreakdowns.modDirectory .. "sounds/rvbsounds.xml")
    if spec.samples == nil then
        spec.samples = {}
    end
    
    if xmlSoundFile ~= nil then
        spec.samples.dasalert = g_soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "dasalert", g_currentMission.vehicleBreakdowns.modDirectory, self.rootNode, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        spec.samples.motormuting = g_soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "motormuting", g_currentMission.vehicleBreakdowns.modDirectory, self.rootNode, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        --spec.samples.self_starter = g_soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "self_starter", g_currentMission.vehicleBreakdowns.modDirectory, self.rootNode, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        spec.samples.battery = g_soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "battery", g_currentMission.vehicleBreakdowns.modDirectory, self.rootNode, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        self.spec_motorized.samples.motorStop = g_soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "motorStop", g_currentMission.vehicleBreakdowns.modDirectory, self.rootNode, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		delete(xmlSoundFile)
    else
        log_dbg("ERROR: g_currentMission.vehicleBreakdowns - Could not load rvbsounds.xml")
    end


	self.tireDeformationTimer = 0
	self.tireDeformationTimer2 = 0
	
	spec.inflationPressure = VehicleBreakdowns.TIRE_PRESSURE_NORMAL
    spec.inflationPressureTarget = VehicleBreakdowns.TIRE_PRESSURE_LOW 
	spec.pressureMax = VehicleBreakdowns.TIRE_PRESSURE_MAX
    spec.pressureMin = VehicleBreakdowns.TIRE_PRESSURE_MIN
	
	self.deformation = 0
	self.deformationDegrees = 0
	self.tmpdeformation = 0
	
	
	
    spec.isActive = true -- default enabled.



    spec.isInflating = false
    spec.allWheelsAreCrawlers = true

    spec.lastInputChangePressureValue = 0
    spec.lastPressureValue = 0
    spec.changeCurrentDelay = 0
    spec.changeMultiplier = 1
    spec.changePushUpdate = false

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    for _, wheel in ipairs(self:getWheels()) do
        if wheel.tireType ~= tireTypeCrawler then
            spec.allWheelsAreCrawlers = false
        end
    end

    

    if self.isClient then
        --spec.samples = {}
        --spec.samples.air = g_soundManager:loadSampleFromXML(self.xmlFile.handle, "vehicle.tirePressure.sounds", "air", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
    end
	
	
	
	
	
	
	
	
	

	self.currentTemperaturDay = g_currentMission.environment.weather:getCurrentTemperature()
	self.currentTemperaturDay =  self.currentTemperaturDay - math.random(2,5)
	self.spec_motorized.motorTemperature.value = self.currentTemperaturDay
	self.spec_motorized.motorTemperature.valueMin = self.currentTemperaturDay
	--self.spec_motorized.motorFan.disableTemperature = 85
	self.spec_motorized.motorTemperature.valueMax = 122
	
	self.tireDeformation = false

	-- engine data
	spec.motorTemperature = self.currentTemperaturDay
	spec.fanEnabled = false
	spec.fanEnabledLast = false

	spec.fanEnableTemperature = 95
	spec.fanDisableTemperature = 85
	
	self.spec_motorized.motorFan.defaultEnableTemp = self.spec_motorized.motorFan.enableTemperature
	self.spec_motorized.motorFan.defaultDisableTemp = self.spec_motorized.motorFan.disableTemperature

	spec.lastFuelUsage = 0
	spec.lastDefUsage = 0
	spec.lastAirUsage = 0

	spec.DontStopMotor = {}
	spec.DontStopMotor.glowPlug	= false
	spec.DontStopMotor.self_starter	= false
	spec.RandomNumber = {}
	spec.RandomNumber.glowPlug = 0
	spec.TimesSoundPlayed = {}
	spec.TimesSoundPlayed.glowPlug = 2
	spec.TimesSoundPlayed.self_starter = 2
	spec.MotorTimer = {}
	spec.MotorTimer.glowPlug = -1
	spec.MotorTimer.self_starter = -1
	spec.NumberMotorTimer = {}
	spec.NumberMotorTimer.glowPlug = 0
	spec.NumberMotorTimer.self_starter = 0

	spec.DontStopMotor.battery	= false
	
	spec.updateTimer = 0
	
	spec.addDamage = {}
	spec.addDamage.alert = false

	--spec.uiEvents = {
	--	engineLoadWarning = false,
	--	batteryLowWarning = false,
	--	serviceOverdueWarning = false,
	--	progressMessage = {}
	--}
	spec.uiProgressMessage = {}
	spec.engineLoadWarningTriggered = false
	
	spec.uiJumperCableMessage = {}
	
	spec.uiBlinkingMessage = {}
	
	spec.repairToChange = 0
	
	spec.ShortCircuitStop = false
	
	spec.alertMessage = {
		inspection = -1,
		service = -1,
		repair = -1
	}

	g_messageCenter:subscribe(MessageType.MINUTE_CHANGED, self.minuteChanged, self)
	g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.RVBhourChanged, self)

	g_messageCenter:subscribe(MessageType.SET_PARTS_LIFETIME, self.onSetPartsLifetime, self)
	g_messageCenter:subscribe(MessageType.SET_DIFFICULTY, self.onSetDifficulty, self)
	--g_messageCenter:subscribe(MessageType.SET_DAYSPERPERIOD, self.onSetPlannedDaysPerPeriod, self)
	g_messageCenter:subscribe(MessageType.SET_WORKSHOP_STATE, self.onWorkshopStateChanged, self)
	g_messageCenter:subscribe(MessageType.SLEEPING, self.onSleepingStateChanged, self)
	--g_messageCenter:subscribe(ResetVehicleEvent, self.onRVBVehicleReset, self)
	g_messageCenter:subscribe(MessageType.RVB_VEHICLE_RESET, self.onRVBVehicleReset, self)

	
	
	if self.isClient then
		g_messageCenter:subscribe(MessageType.RVB_PROGRESS_MESSAGE, self.onProgressMessage, self)
	end
	g_messageCenter:subscribe(MessageType.RVB_JUMPERCABLE_MESSAGE, self.onJumperCableMessage, self)
	g_messageCenter:subscribe(MessageType.RVB_BLINKINGMESSAGE, self.onBlinkingMessage, self)

	local RVB = g_currentMission.vehicleBreakdowns
	--RVB:setRVBDifficulty(g_currentMission.vehicleBreakdowns.generalSettings.difficulty)
	
	

	
	
	spec.motorStart_updateDelta = 0
	spec.motorStart_updateRate = 600

	spec.lights_request_A = false
	spec.lights_request_B = false

	spec.faultListText = {}
	spec.faultList = {}




	spec.RVB_Battery = {}
	spec.RVB_BatteryFillLevel = 100.000000
	spec.updateBatteryTimer = 0
	
	spec.BatteryPlusMinus = {}
	spec.BatteryPlusMinus.lightings = 0
	
	spec.batteryFillUnitIndex = nil
	spec.isInitialized = true
	
	local specFillunit = self.spec_fillUnit
	local batteryFillUnitsCount = 0

	spec.batteryCHActive = false
	local batteryLevel = 100
	local spec_fillUnit = self.spec_fillUnit
	
	spec.updateDelta = 5001
	spec.updateRate = 5000
	
	
	spec.isRepairActive = false
	spec.isServiceActive = false
	--spec.isInspectionActive = false


	spec.totalRepairTime = 0.0
	

	spec.partFaultDebugHud = {
		isBreakConditionMet = false,
		thresholdTriggered = false,
		needsNewPreFault = false,
		isCritical = false,
		preFaultStartPercent = 0,
		breakThresholdPercent = 0,
		randomOffset = 0,
		currentPreFault = "empty"
	}



						
	local spec_m = self.spec_motorized

	if spec_m.motor ~= nil then
	
	
	
	local fillUnits = self.spec_fillUnit.fillUnits

		local xmlFillUnit = XMLFile.load("vehicleXml", Utils.getFilename("config/battery_fillUnit.xml", g_currentMission.vehicleBreakdowns.modDirectory), Vehicle.xmlSchema)
		local batteryKey = string.format("vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit(0)")
		local entry = {}
		if not self:FillUnit_loadFillUnitFromXML(xmlFillUnit, batteryKey, entry, #fillUnits + 1) then
			Logging.xmlWarning(xmlFillUnit, "RVB: Could not load fillUnit for \'%s\'", batteryKey)
			self:setLoadingState(VehicleLoadingState.ERROR)
		end
		--entry.fillType = FillType.BATTERYCHARGE
		--entry.startFillTypeIndex = FillType.BATTERYCHARGE
		--entry.capacity = 100
		--entry.startFillLevel = 100
		
		-- ez is kell hozzá (akku infobar megjelenítés)
		--entry.showOnHud = true
		--entry.showOnInfoHud = true
		entry.hasDashboards = false
		local fillUnits = self.spec_fillUnit.fillUnits
		table.insert(fillUnits, entry)
	
		spec.batteryFillUnitIndex = #fillUnits
		spec.RVB_BatteryFillLevel = entry.capacity

	else
		spec.isInitialized = false
	end
	
	local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
	-- spec.batteryFillUnitIndex
	-- github Version v0.9.5.5 does not detect the battery #116
	self.spec_fillUnit.fillUnits[batteryFillUnitIndex].fillType = FillType.BATTERYCHARGE
	self.spec_fillUnit.fillUnits[batteryFillUnitIndex].fillLevel = spec.RVB_BatteryFillLevel
	
	--[[if self.getConsumerFillUnitIndex ~= nil and self:getConsumerFillUnitIndex(FillType.DIESEL) ~= nil then

		local specConsumers = self.spec_motorized
		if spec.batteryFillUnitIndex ~= nil and spec.isInitialized then

		
			local xmlFillUnit = XMLFile.load("vehicleXml", Utils.getFilename("config/battery_consumer.xml", g_currentMission.vehicleBreakdowns.modDirectory), Vehicle.xmlSchema)
			local unitindex = 1

			local vkey, motorId = ConfigurationUtil.getXMLConfigurationKey(self.xmlFile, self.configurations["motor"], "vehicle.motorized.motorConfigurations.motorConfiguration", "vehicle.motorized", "motor")
			local fallbackConfigKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"
			local consumerConfigurationIndex = ConfigurationUtil.getConfigurationValue(self.xmlFile, vkey, "#consumerConfigurationIndex", "", 1, fallbackConfigKey)
			local key = string.format("vehicle.motorized.consumerConfigurations.consumerConfiguration(%d)", consumerConfigurationIndex-1)
			local consumerKey = string.format(".consumer(%d)", #specConsumers.consumers + 1)
			local consumer = {}
			consumer.fillUnitIndex = spec.batteryFillUnitIndex
	--		print("spec.batteryFillUnitIndex "..spec.batteryFillUnitIndex)
			self.spec_fillUnit.fillUnits[spec.batteryFillUnitIndex].fillType = FillType.BATTERYCHARGE
			self.spec_fillUnit.fillUnits[spec.batteryFillUnitIndex].fillLevel = spec.RVB_BatteryFillLevel -- batteryLevel
			--self:raiseDirtyFlags(self.spec_fillUnit.dirtyFlag)
			local fillTypeName = "batteryCharge"
			consumer.fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			consumer.capacity = nil
			local fillUnit = self:getFillUnitByIndex(consumer.fillUnitIndex)
			if fillUnit ~= nil then
			
				if fillUnit.supportedFillTypes[consumer.fillType] == nil then
					fillUnit.supportedFillTypes = {}
					fillUnit.supportedFillTypes[consumer.fillType] = true
				end
				fillUnit.capacity = consumer.capacity or fillUnit.capacity
				if (consumer.fillType == FillType.DIESEL or (consumer.fillType == FillType.ELECTRICCHARGE or consumer.fillType == FillType.METHANE)) and fillUnit.exactFillRootNode == nil then
					Logging.xmlWarning(self.xmlFile, "Missing exactFillRootNode for fuel fill unit (%d).", consumer.fillUnitIndex)
				end
				fillUnit.startFillLevel = fillUnit.capacity
				fillUnit.startFillTypeIndex = consumer.fillType
				fillUnit.ignoreFillLimit = true
				--local v347 = ConfigurationUtil.getConfigurationValue(p338, v340, v343, "#usage", 1, "vehicle.motorized.consumers")
				--consumer.permanentConsumption = ConfigurationUtil.getConfigurationValue(p338, v340, v343, "#permanentConsumption", true, "vehicle.motorized.consumers")
				consumer.permanentConsumption = false
				local usage = 0.1
				if consumer.permanentConsumption then
					consumer.usage = usage / 3600000
				else
					consumer.usage = usage
				end
				consumer.refillLitersPerSecond = 0 --ConfigurationUtil.getConfigurationValue(p338, v340, v343, "#refillLitersPerSecond", 0, "vehicle.motorized.consumers")
				consumer.refillCapacityPercentage = 0 --ConfigurationUtil.getConfigurationValue(p338, v340, v343, "#refillCapacityPercentage", 0, "vehicle.motorized.consumers")
				consumer.fillLevelToChange = 0
				local v348 = specConsumers.consumers
				table.insert(v348, consumer)
				specConsumers.consumersByFillTypeName[string.upper(fillTypeName)] = consumer
				specConsumers.consumersByFillType[consumer.fillType] = consumer

			else
				Logging.xmlWarning(self.xmlFile, "RVB: Unknown fillUnit '%d' for consumer '%s'", consumer.fillUnitIndex, key..consumerKey)
			end
		end
	end]]

	
	spec.rvb_actionEventToggleLights = 0
	
	
	spec.jumperCableConnections = { nil, nil }

	self.players = {}
	spec.isJumperCablesConnected = false
	spec.isJumpStarting = false
	spec.chargeRate = 0
	spec.actionEvents = {}
	
	self.vehicle = nil
	self.interactText = ""
	self.actionEventIdJC = nil
	
	self.rvbjumperCableConnections = {}
	self.rvb_addextra_connecting = false
	
	spec.batteryDrainStartMotorTriggered = false
	spec.batteryDrain = false
	
	spec.isTorqueModified = false
	
	spec.isSpeedLimitPercent = false

	spec.drivenDistanceNetworkThreshold = 10
	
	spec.steeringWheels = {}
	self:steeringWheels()
	
	if self.isExcluded and self:isExcluded() then
		spec.isrvbSpecEnabled = false
	end


	
	spec.motorLoadPercent = 0
	spec.smoothedLoadUpdateTimer = 0
	spec.hasNewUIBlinkingMessage = false
	
	spec.batterySelfDischarge = true
	
end

				
function VehicleBreakdowns:steeringWheels()
	local spec = self.spec_faultData
	if self.spec_wheels ~= nil then
		for _, wheel in pairs(self.spec_wheels.wheels) do
			--print(wheel.wheelIndex .. " " .. tostring(wheel.driveNode).. " "..wheel.physics.rotSpeed)
			if wheel.physics.rotSpeed ~= 0 then
			--if wheel.driveNode ~= nil and wheel.driveNode ~= 0 then
				table.insert(spec.steeringWheels, wheel.wheelIndex)
			end
		end
	end
	--print("Kormányozható kerekek indexei: ", table.concat(spec.steeringWheels, ", "))
end
	
function VehicleBreakdowns:getBatteryFillUnitIndex()
    local spec = self.spec_fillUnit
    local batteryFillType = g_fillTypeManager:getFillTypeIndexByName("BATTERYCHARGE")
    for fillUnitIndex, _ in ipairs(spec.fillUnits) do
        if self:getFillUnitAllowsFillType(fillUnitIndex, batteryFillType) then
            return fillUnitIndex
        end
    end
    return nil
end






function VehicleBreakdowns.setLightsTypesMask(self, superFunc, lightsTypesMask, force, noEventSend)
	superFunc(self, lightsTypesMask, force, noEventSend)
    local currentLightMask = self:getLightsTypesMask()
	local rvb = self.spec_faultData
	rvb.rvblightsTypesMask = currentLightMask
    return
end


function VehicleBreakdowns:setBatteryDrainingIfStartMotor()
	if self.isServer then
		local spec = self.spec_faultData
		if spec == nil or spec.batteryDrainStartMotorTriggered then return end
		
		local RVBSET = g_currentMission.vehicleBreakdowns
		local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
		if batteryFillUnitIndex == nil then return end

		local batteryPct = self:getBatteryFillLevelPercentage()

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
end


function VehicleBreakdowns:batteryChargeVehicle()
	if self.isServer then
	local spec = self.spec_faultData
	
	
	local CurEnvironment = g_currentMission.environment
	local manualDesc = g_i18n:getText("RVB_WorkshopMessage_batteryDone")
	local entry = {
		entryType = BATTERYS.SERVICE_MANUAL,
		entryTime = CurEnvironment.currentDay,
		operatingHours = spec.totaloperatingHours,
		odometer = 0,
		--result = manualDesc,
		resultKey = "RVB_WorkshopMessage_batteryDone",
		errorList = {},
		cost = 25
	}
	RVBserviceManual_Event.sendEvent(self, entry)

	
	local maxPartLifetime = PartManager.getMaxPartLifetime(self, BATTERY)
	local usedFraction = spec.parts[BATTERY].operatingHours / maxPartLifetime
	local batteryHealth = 1
	if usedFraction >= 0.5 then
		batteryHealth = 1 - (usedFraction - 0.5) / 0.5
		batteryHealth = math.max(0.15, batteryHealth)
	end
	local maxBatteryPercent = 100 * batteryHealth
	local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
	--spec.batteryFillUnitIndex
																				-- 100
	self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, maxBatteryPercent, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)
	--if self.isServer then
		g_currentMission:addMoney(-25, self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
		local total, _ = g_farmManager:updateFarmStats(self:getOwnerFarmId(), "repairVehicleCount", 1)
		if total ~= nil then
			g_achievementManager:tryUnlock("VehicleRepairFirst", total)
			g_achievementManager:tryUnlock("VehicleRepair", total)
		end
	end
end


function VehicleBreakdowns.setRVBJumpchargerate(self, rate)
	if self.isServer then
		local rvb = self.spec_faultData
		local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
		self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, rate, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)
		rvb.chargeRate = 0
	--	self:raiseDirtyFlags(rvb.dirtyFlag)
	end
end

function VehicleBreakdowns:chargeBatteryViaJumpStart(dt, isActiveForInputIgnoreSelection)
	local LowBatteryVehicle = nil
	local conn = self.spec_jumperCable.connection
	
	local jc = self.spec_jumperCable
    if jc == nil or jc.connection == nil then
        return
    end

    local conn = jc.connection
    local donor = conn.donor
    local receiver = conn.receiver

	local LowBatteryVehicle = receiver
	--local LowBatteryVehicle = self.spec_jumperCable.connections[2]
	if LowBatteryVehicle ~= nil and self:getIsMotorStarted() then -- kellehet de lehet kulon feltetelbe and not self:getIsFaultGenerator() then
		local spec = self.spec_faultData
		local partGenerator = spec.parts[GENERATOR]
		local lowspec = LowBatteryVehicle.spec_faultData
		local batteryFillUnitIndex = LowBatteryVehicle:getBatteryFillUnitIndex()
		--lowspec.batteryFillUnitIndex
		local batteryFillLevel = LowBatteryVehicle:getFillUnitFillLevel(batteryFillUnitIndex)
		if LowBatteryVehicle:getIsMotorStarted() then
			spec.isJumpStarting = false
			VehicleBreakdowns.updateActionEvents(self)
			return
		end
		local maxBatteryLifetime = PartManager.getMaxPartLifetime(LowBatteryVehicle, BATTERY)
		local maxGeneratorLifetime = PartManager.getMaxPartLifetime(self, GENERATOR)
		local usedFraction = lowspec.parts[BATTERY].operatingHours / maxBatteryLifetime
		local batteryHealth = 1
		if usedFraction >= 0.5 then
			batteryHealth = 1 - (usedFraction - 0.5) / 0.5
			batteryHealth = math.max(0.15, batteryHealth)
		end
		local maxBatteryPercent = 100 * batteryHealth
		
		--if batteryFillLevel < 100 then
		if batteryFillLevel < maxBatteryPercent then
			local generatorBaseOutput = 60 -- Alap generátor kimenet (A)
			local maxGeneratorOutput = 120 -- Maximális generátor kimenet (A)
			local specMotorized = self.spec_motorized
			local specMotorizedM = self.spec_motorized.motor
			local currentRPM = specMotorizedM.lastMotorRpm -- Aktuális fordulatszám
			local minRPM = specMotorizedM.minRpm
			local maxRPM = specMotorizedM.maxRpm

			-- Hatékonysági tényező az üzemórák alapján
			local efficiencyFactor = math.max(0.1, 1 - (partGenerator.operatingHours / maxGeneratorLifetime))

			local faultName = (partGenerator.prefault ~= "empty" and partGenerator.prefault) or partGenerator.fault
			local r = FaultRegistry[GENERATOR]
			local variants = r.variants
			if faultName and faultName ~= "empty" then
				local variantData = variants[faultName]
				if variantData ~= nil then
					local severity = variantData.severity or 0.5
					local penalty = severity
					efficiencyFactor = math.max(0, 1 - penalty)
				end
			end

			-- RPM százalék és RPM faktor számítása
			local rpmPercentage = (currentRPM - minRPM) / (maxRPM - minRPM)
			local idleFactor = 0.5
			local rpmFactor = idleFactor + rpmPercentage * (1 - idleFactor)
			-- Terhelési tényező számítása
			local loadFactor = math.max(specMotorized.smoothedLoadPercentage * rpmPercentage, 0)
			--local motorFactor = 0.5 * (0.2 * rpmFactor + 1.8 * loadFactor) + 0.4  -- Motor faktor frissítve
			--local motorFactor = 0.6 * (0.4 * rpmFactor + 1.8 * loadFactor) + 0.9
			--local motorFactor = 0.5 * (0.3 * rpmFactor + 1.8 * loadFactor) + 0.5

			local motorFactor = 0.6 * (0.8 * rpmFactor + 2.1 * loadFactor) + 0.3


			-- Töltési ráta számítása a motor és generátor állapot alapján
			local runtimeIncrease = dt * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
			local generatorOutput = generatorBaseOutput + (maxGeneratorOutput - generatorBaseOutput) * loadFactor
			local chargeRate = generatorOutput * motorFactor * efficiencyFactor * runtimeIncrease
			-- Ellenőrizzük, hogy a kimeneti áram helyes legyen
			if chargeRate < 0 then
				chargeRate = 0
			end
			if chargeRate ~= 0 then
				lowspec.jumpstartToChange = lowspec.jumpstartToChange + chargeRate
				local jumpstartToChange = lowspec.jumpstartToChange
				if self.isClient and isActiveForInputIgnoreSelection then
					--local LowBatteryVehicle = self.spec_jumperCable.connections[2]
					local LowBatteryVehicle = nil
	local conn = self.spec_jumperCable.connection
	if conn == nil then return end
	if conn.donor == self then
		boosterVehicle = conn.donor
	elseif conn.receiver == self then
		LowBatteryVehicle = conn.receiver
	end
					local currentChargeLevel = (1 - receiver:getBatteryFillLevelPercentage())*100
					local lackofcharge = 100 - currentChargeLevel
					g_currentMission:addExtraPrintText(string.format(g_i18n:getText("RVB_addextra_progress"), string.format("%.2f", lackofcharge)))
					-- Töltési érték megjelenítése
					local approxAmps = generatorOutput * motorFactor * efficiencyFactor
					g_currentMission:addExtraPrintText(string.format(g_i18n:getText("RVB_addextra_charging"), string.format("%.2f", approxAmps)))
				end
				if math.abs(jumpstartToChange) > 0.1 then
					chargeRate = lowspec.jumpstartToChange
					lowspec.chargeRate = lowspec.jumpstartToChange
					lowspec.jumpstartToChange = 0
					local newFillLevel = batteryFillLevel + chargeRate
					if newFillLevel > 100 then
						newFillLevel = 100
						spec.isJumpStarting = false
						VehicleBreakdowns.updateActionEvents(self)
					end
					--LowBatteryVehicle:addFillUnitFillLevel(LowBatteryVehicle:getOwnerFarmId(), lowspec.batteryFillUnitIndex, chargeRate, LowBatteryVehicle:getFillUnitFillType(lowspec.batteryFillUnitIndex), ToolType.UNDEFINED, nil)
					g_client:getServerConnection():sendEvent(RVBJumpStartingEvent.new(receiver, lowspec.chargeRate))
				end
			end
		end
	end
end


function VehicleBreakdowns:CalculateFinishTime(AddHour, AddMinute)
    local currentTimeInMinutes = g_currentMission.environment.currentHour * 60 + g_currentMission.environment.currentMinute
    local addTimeInMinutes = AddHour * 60 + AddMinute
    local workshopOpenTime = g_rvbGameplaySettings.workshopOpen * 60
    local workshopCloseTime = g_rvbGameplaySettings.workshopClose * 60
    local finishDay = g_currentMission.environment.currentDay
    if currentTimeInMinutes < workshopOpenTime then
        currentTimeInMinutes = workshopOpenTime
    end
    local finishTimeInMinutes = currentTimeInMinutes + addTimeInMinutes
    if finishTimeInMinutes >= workshopCloseTime then
        finishDay = finishDay + 1
        finishTimeInMinutes = workshopOpenTime + (finishTimeInMinutes - workshopCloseTime)
    end
    local finishHour = math.floor(finishTimeInMinutes / 60)
    local finishMinute = finishTimeInMinutes % 60
    return finishDay, finishHour, finishMinute
end




function VehicleBreakdowns:setIsRepairActive(isRepairActive, noEventSend)
	local spec = self.spec_faultData
	if isRepairActive ~= spec.isRepairActive then
		RVBRepairControlEvent.sendEvent(self, isRepairActive, noEventSend)
	end
end
function TurnOnVehicle:setIsTurnedOn(isTurnedOn, noEventSend)
	local v54_ = self.spec_turnOnVehicle
	if isTurnedOn ~= v54_.isTurnedOn then
		SetTurnedOnEvent.sendEvent(self, isTurnedOn, noEventSend)
		v54_.isTurnedOn = isTurnedOn
		if v54_.isTurnedOn then
			SpecializationUtil.raiseEvent(self, "onTurnedOn")
			self.rootVehicle:raiseStateChange(VehicleStateChange.TURN_ON, self)
		else
			SpecializationUtil.raiseEvent(self, "onTurnedOff")
			self.rootVehicle:raiseStateChange(VehicleStateChange.TURN_OFF, self)
		end
		if self.isClient and self.updateDashboardValueType ~= nil then
			self:updateDashboardValueType("turnOnVehicle.turnedOn")
		end
	end
end



function VehicleBreakdowns:displayMessage(currentMinute)
	local count = 0
	local string_num = tostring(currentMinute)
	for i in string_num:gmatch("") do
		count = count + 1
	end
	count = count - 1
	return string.sub(string_num, count, count)
end





function VehicleBreakdowns:onPostLoad(savegame)

	if savegame == nil then
        return
    end
	


	local p25 = self
	local p26 = savegame

	local v27 = p25.spec_fillUnit
	if p25.isServer then
		local fillUnitsToLoad = {}
		
		if p26 == nil or not p26.xmlFile:hasProperty(p26.key .. ".fillUnit") then --print("NINCS MENTES")
			if not p25.vehicleLoadingData:getCustomParameter("spawnEmpty") then
				
			end
			
		else
			
			
			local v34 = p26.xmlFile
			local v35 = 0
			while true do
				local v36 = string.format("%s.fillUnit.unit(%d)", p26.key, v35)
				if not v34:hasProperty(v36) then
					break
				end
				local v37 = v34:getValue(v36 .. "#index")
				local v38
				if fillUnitsToLoad[v37] == nil then
					v38 = true
				elseif fillUnitsToLoad[v37] == nil then
					v38 = false
				else
					v38 = not p26.resetVehicles
				end
				if v38 then
					local v39 = v34:getValue(v36 .. "#fillType") --print("v39 fillType "..tostring(v39))
					local v40 = v34:getValue(v36 .. "#fillLevel") --print("v40 fillLevel "..tostring(v40))
					
					if v39 == "BATTERYCHARGE" then
						--if p25.isServer then
						local v41 = g_fillTypeManager:getFillTypeIndexByName(v39) --print("v41 "..tostring(v41))
						--p25:addFillUnitFillLevel(p25:getOwnerFarmId(), v37, v40, v41, ToolType.UNDEFINED, nil)
						local spec = p25.spec_faultData
						p25.spec_fillUnit.fillUnits[v37].fillLevel = v40
						--spec.RVB_BatteryFillLevel = v40
						
						p25:raiseDirtyFlags(p25.spec_fillUnit.dirtyFlag)
						--end
						if p25.isClient and not p25.isServer then
							p25.spec_fillUnit.fillUnits[v37].fillLevel = v40
						end

					end
					

					local fillUnit = p25.spec_fillUnit.fillUnits[v37]
					if fillUnit ~= nil then
						for _, unit in ipairs(fillUnit.fillLevelAnimations) do
					--		AnimatedVehicle.updateAnimationByName(p25, unit.name, 9999999, true)
						end
					end
	
				end
				v35 = v35 + 1
			end
		end
		for _, v44 in ipairs(v27.fillUnits) do
			--p25:updateAlarmTriggers(v44.alarmTriggers)
		end
	end
	

	if savegame == nil or savegame.resetVehicles then
        --return
    end

    local spec = self.spec_faultData
	
	local rvbkey = string.format("%s.%s.%s", savegame.key, g_vehicleBreakdownsModName, "vehicleBreakdowns")
	spec.isrvbSpecEnabled = savegame.xmlFile:getValue(rvbkey .. "#isrvbSpecEnabled", true)

	local totaloperatingHours = savegame.xmlFile:getValue(rvbkey .. "#TotaloperatingHours", spec.totaloperatingHours) 
	spec.totaloperatingHours = math.max(Utils.getNoNil(totaloperatingHours, 0), 0)
	
	local periodic = savegame.xmlFile:getValue(rvbkey .. "#operatingHours", spec.operatingHours)
	spec.operatingHours = math.max(Utils.getNoNil(periodic, 0), 0)
	
	local dirtHeatOperatingHours = savegame.xmlFile:getValue(rvbkey .. "#dirtHeatOperatingHours", spec.dirtHeatOperatingHours)
	spec.dirtHeatOperatingHours = math.max(Utils.getNoNil(dirtHeatOperatingHours, 0), 0)

	local keyservice = string.format("%s.%s.%s", savegame.key, g_vehicleBreakdownsModName, "vehicleBreakdowns.vehicleService")
	spec.service.state        = savegame.xmlFile:getValue(keyservice .. "#state", 1)
	spec.service.finishDay    = savegame.xmlFile:getValue(keyservice .. "#finishDay", 0)
	spec.service.finishHour   = savegame.xmlFile:getValue(keyservice .. "#finishHour", 0)
	spec.service.finishMinute = savegame.xmlFile:getValue(keyservice .. "#finishMinute", 0)
	spec.service.cost         = savegame.xmlFile:getValue(keyservice .. "#cost", 0)

	local keyinspection = string.format("%s.%s.%s", savegame.key, g_vehicleBreakdownsModName, "vehicleBreakdowns.vehicleInspection")
	spec.inspection.state        = savegame.xmlFile:getValue(keyinspection .. "#state", 1)
	spec.inspection.finishDay    = savegame.xmlFile:getValue(keyinspection .. "#finishDay", 0)
	spec.inspection.finishHour   = savegame.xmlFile:getValue(keyinspection .. "#finishHour", 0)
	spec.inspection.finishMinute = savegame.xmlFile:getValue(keyinspection .. "#finishMinute", 0)
	spec.inspection.cost         = savegame.xmlFile:getValue(keyinspection .. "#cost", 0)
	spec.inspection.factor       = savegame.xmlFile:getValue(keyinspection .. "#factor", 0)
	spec.inspection.completed    = savegame.xmlFile:getValue(keyinspection .. "#completed", false)

	local keyrepair = string.format("%s.%s.%s", savegame.key, g_vehicleBreakdownsModName, "vehicleBreakdowns.vehicleRepair")
	spec.repair.state        = savegame.xmlFile:getValue(keyrepair .. "#state", 1)
	spec.repair.finishDay    = savegame.xmlFile:getValue(keyrepair .. "#finishDay", 0)
	spec.repair.finishHour   = savegame.xmlFile:getValue(keyrepair .. "#finishHour", 0)
	spec.repair.finishMinute = savegame.xmlFile:getValue(keyrepair .. "#finishMinute", 0)
	spec.repair.cost         = savegame.xmlFile:getValue(keyrepair .. "#cost", 0)



	--if spec.inspection[1] or spec.service[1] or spec.repair[1] then
	if spec.inspection.state == INSPECTION_STATE.ACTIVE or spec.service.state == SERVICE_STATE.ACTIVE or spec.repair.state == REPAIR_STATE.ACTIVE then
		local RVB = g_currentMission.vehicleBreakdowns

		-- ha még nincs benne a jármű, hozzáadjuk
		if not RVB.workshopVehicles[self] then
			RVB.workshopVehicles[self] = true
			RVB.workshopCount = RVB.workshopCount + 1
			--print("onPostLoad workshopCount "..RVB.workshopCount)
			WorkshopCount_Event.sendEvent(RVB.workshopCount)
		end
	end
	

	
	if self.isServer then
        PartManager.loadFromPostLoad(self, savegame)
    end

	--[[if savegame ~= nil and savegame.resetVehicles then
		--print("onPostLoad " .. self:getFullName() .. " " .. tostring(savegame.resetVehicles))
		for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = spec.parts[key]
			--g_resetVehiclesRVB[self] = nil
			print(string.format("Part %d: %s, Lifetime: %s, Operating Hours: %s, Repair Required: %s, Amount: %s, Cost: %s",
			i, part.name, part.lifetime, part.operatingHours, tostring(part.repairreq), part.amount, part.cost))
		end
	end]]

	local i = 0
	local xmlFile = savegame.xmlFile
	local key = string.format("%s.%s.vehicleBreakdowns.serviceManual", savegame.key, g_vehicleBreakdownsModName)
    while true do
		local entryKey = string.format("%s.entry(%d)", key, i)
		if not xmlFile:hasProperty(entryKey) then
			break
		end
		local entry = {
			entryType      = xmlFile:getValue(entryKey .. "#entryType", 0),
			entryTime      = xmlFile:getValue(entryKey .. "#entryTime", 0),
			operatingHours = xmlFile:getValue(entryKey .. "#operatingHours", 0),
			odometer       = xmlFile:getValue(entryKey .. "#odometer", 0),
			resultKey         = xmlFile:getValue(entryKey .. "#resultKey", ""),
			errorList      = {},
			cost           = xmlFile:getValue(entryKey .. "#cost", 0)
		}
		if xmlFile:hasProperty(entryKey .. "#result") then
			local legacy = xmlFile:getValue(entryKey .. "#result", "")
			if legacy ~= "" then
				entry.resultKey = "notification_nowAvailable"
				entry.errorList = {legacy}
			end
		end

    -- új formátum feldolgozása
    --local errorCount = xmlFile:getValue(entryKey .. "#errorCount", 0)
    --for j = 0, errorCount - 1 do
    --    local errKey = xmlFile:getValue(entryKey .. ".error(" .. j .. ")#key", "")
    --    if errKey ~= "" then
    --        table.insert(entry.errorList, errKey)
    --    end
    --end

		-- ÚJ formátum (lista)
		local errorCount = xmlFile:getValue(entryKey .. "#errorCount", 0)
		if errorCount ~= nil and errorCount > 0 then
			for j = 0, errorCount - 1 do
				local errKey = xmlFile:getValue(entryKey .. ".error(" .. j .. ")#key", "")
				if errKey ~= "" then
					table.insert(entry.errorList, errKey)
				end
			end
		end

		table.insert(spec.serviceManual, entry)
		i = i + 1
    end

	if spec.totalRepairTime == nil then
        spec.totalRepairTime = 0.0
    end


		
		
		
if self.isServer then




	local i = 0
	local xmlFile = savegame.xmlFile
	while true do
		local key = string.format("%s.fillUnit.unit(%d)", savegame.key, i)
		if not xmlFile:hasProperty(key) then
			break
		end

		local fillTypeName = xmlFile:getValue(key.."#fillType")
		if fillTypeName == "BATTERYCHARGE" then
			local fillUnitIndex = xmlFile:getValue(key.."#index")
			--print("fillUnitIndex "..fillUnitIndex)
			local fillLevel = xmlFile:getValue(key.."#fillLevel", 100)
			if self.isClient then
		--	print("fillLevel "..fillLevel)
			end
		--	self.spec_fillUnit.fillUnits[fillUnitIndex].fillLevel = fillLevel
		--	spec.RVB_BatteryFillLevel = fillLevel
			--self:raiseDirtyFlags(spec.dirtyFlag)
		end	

		i = i + 1
	end
	
	
	
	
	
end
	

	--print("onPostLoad " .. self:getFullName() .. g_rvbGameplaySettings.difficulty)
	--g_messageCenter:publish(MessageType.SET_DIFFICULTY, g_rvbGameplaySettings.difficulty)
	--print("onPostLoad END")



end

function VehicleBreakdowns:onLoadFinished(savegame)

	if savegame == nil then
		return
	end
	local rvb = self.spec_faultData
	if not rvb then return end

	if self.isExcluded and self:isExcluded() then
		rvb.isrvbSpecEnabled = false
		self.rvbDebugger:info("The Real Vehicle Breakdowns 'specialization' is disabled for the %s vehicle.", self:getFullName())
		return
	end

	if g_modIsLoaded["FS25_useYourTyres"] then

		if self.spec_wheels == nil then
			return
		end

		if self.isServer then
			local isSavegameLoad = (savegame.xmlFile.filename ~= "")
			for wheelIdx, wheel in ipairs(self.spec_wheels.wheels) do
				local wheelKey = string.format("%s.wheels.wheel(%d)#uytTravelledDist", savegame.key, wheelIdx - 1)
				local travelDist = savegame.xmlFile:getValue(wheelKey)
				if travelDist ~= nil and isSavegameLoad then
					-- base
					--wheel.uytTravelledDist = travelDist
					local partName = WHEELTOPART[wheelIdx]
					if partName == nil then return end
					local part = rvb.parts[partName]
					if not part then return end
					--wheel.uytTravelledDist = part.operatingHours
					part.operatingHours = wheel.uytTravelledDist
				else
					--wheel.uytTravelledDist = 0
				end
			end
		end

		local maxLifetime = PartManager.getMaxPartLifetime(self, TIREFL)
		FS25_useYourTyres.UseYourTyres.USED_MAX_M = maxLifetime

		WheelPhysics.updateContact = Utils.appendedFunction(WheelPhysics.updateContact, VehicleBreakdowns.injPhysWheelUpdateContact)

	end

end



function VehicleBreakdowns:SyncClientServer_serviceManual(entry, noEventSend)
	local spec = self.spec_faultData
	table.insert(spec.serviceManual, 1, entry)
end


function VehicleBreakdowns:getServiceManualEntry()
	local spec = self.spec_faultData
	return spec.serviceManual
end

function VehicleBreakdowns.SyncClientServer_Other(vehicle, batteryCHActive)
	local spec = vehicle.spec_faultData
	spec.batteryCHActive = batteryCHActive
end



function VehicleBreakdowns.SyncClientServer_RVBBattery(vehicle, b1, b2, b3, b4, b5, b6, b7)
    local spec = vehicle.spec_faultData
    spec.battery = spec.battery or {}
    spec.battery[1] = b1
    spec.battery[2] = b2
    spec.battery[3] = b3
    spec.battery[4] = b4
    spec.battery[5] = b5
    spec.battery[6] = b6
    spec.battery[7] = b7
--	vehicle:raiseDirtyFlags(spec.dirtyFlag)
    if vehicle:getIsSynchronized() then
    end
end



function VehicleBreakdowns:SyncClientServer_RVBParts(parts)
	local spec = self.spec_faultData
	spec.parts = parts
	if self.isServer then
		self:raiseDirtyFlags(spec.partsDirtyFlag)
	end
end


function VehicleBreakdowns.SyncClientServer_BatteryChargeLevel(vehicle, level)
	local spec = vehicle.spec_faultData
	spec.RVB_BatteryFillLevel = level
end

function VehicleBreakdowns:onReadStream(streamId, connection)

	local spec = self.spec_faultData
	if spec == nil then return end

	spec.isrvbSpecEnabled = streamReadBool(streamId)
	spec.totaloperatingHours = streamReadFloat32(streamId)
	spec.operatingHours = streamReadFloat32(streamId)
	spec.dirtHeatOperatingHours = streamReadFloat32(streamId)

	spec.inspection = spec.inspection or {}
    spec.inspection.state        = streamReadInt16(streamId)
    spec.inspection.finishDay    = streamReadInt16(streamId)
    spec.inspection.finishHour   = streamReadInt16(streamId)
    spec.inspection.finishMinute = streamReadInt16(streamId)
    spec.inspection.cost         = streamReadFloat32(streamId)
    spec.inspection.factor       = streamReadFloat32(streamId)
    spec.inspection.completed    = streamReadBool(streamId)

	spec.service = spec.service or {}
    spec.service.state        = streamReadInt16(streamId)
    spec.service.finishDay    = streamReadInt16(streamId)
    spec.service.finishHour   = streamReadInt16(streamId)
    spec.service.finishMinute = streamReadInt16(streamId)
    spec.service.cost         = streamReadFloat32(streamId)

	spec.repair = spec.repair or {}
    spec.repair.state        = streamReadInt16(streamId)
    spec.repair.finishDay    = streamReadInt16(streamId)
    spec.repair.finishHour   = streamReadInt16(streamId)
    spec.repair.finishMinute = streamReadInt16(streamId)
    spec.repair.cost         = streamReadFloat32(streamId)

	local count = streamReadInt32(streamId)
	for i = 1, count do
		local key = streamReadString(streamId)
		local part = {
			name            = streamReadString(streamId),
			operatingHours  = streamReadFloat32(streamId),
			repairreq       = streamReadBool(streamId),
			prefault        = streamReadString(streamId),
			fault           = streamReadString(streamId),
			cost            = streamReadFloat32(streamId),
			runOncePerStart = streamReadBool(streamId)
		}
		spec.parts[key] = part
	end

	spec.serviceManual = {}
	local count = streamReadInt32(streamId) or 0
    for i=1, count do
        local entry = {
            entryType = streamReadInt16(streamId),
            entryTime = streamReadInt16(streamId),
            operatingHours = streamReadFloat32(streamId),
            odometer = streamReadFloat32(streamId),
			resultKey = streamReadString(streamId),
        }
		local errCount = streamReadUInt8(streamId)
		if errCount > 0 then
			entry.errorList = {}
			for j = 1, errCount do
				table.insert(entry.errorList, streamReadString(streamId))
			end
		end
		entry.cost = streamReadFloat32(streamId)
        table.insert(spec.serviceManual, entry)
    end
	
	spec.batteryDrainAmount = streamReadFloat32(streamId)
	spec.batteryChargeAmount = streamReadFloat32(streamId)
	
	spec.RVB_BatteryFillLevel = streamReadFloat32(streamId)
	spec.batteryFillUnitIndex = streamReadInt16(streamId)
	
	
	--[[local hasConnection = streamReadBool(streamId)
    if not hasConnection then
        return
    end
	local donor = NetworkUtil.readNodeObject(streamId)
	local state = streamReadInt16(streamId)
	local hasReceiver = streamReadBool(streamId)
    local receiver = nil
    if hasReceiver then
        receiver = NetworkUtil.readNodeObject(streamId)
    end
	local jumperTime = streamReadFloat32(streamId)
	local jumperThreshold = streamReadInt32(streamId)
	local activePlayerUserId = streamReadInt32(streamId)

	if donor ~= nil and donor:getIsSynchronized() then
        self.spec_jumperCable.connection = {
            donor = donor,
			state = state,
            receiver = receiver,
            jumperTime = jumperTime,
			jumperThreshold = jumperThreshold,
			activePlayerUserId = activePlayerUserId
        }
    end]]


	--if connection:getIsServer() then
	g_messageCenter:publish(MessageType.SET_DIFFICULTY, g_rvbGameplaySettings.difficulty)
	--end
end

function VehicleBreakdowns:onWriteStream(streamId, connection)
	
	local spec = self.spec_faultData
	if spec == nil then return end

	streamWriteBool(streamId, spec.isrvbSpecEnabled)
	streamWriteFloat32(streamId, spec.totaloperatingHours)
	streamWriteFloat32(streamId, spec.operatingHours)
	streamWriteFloat32(streamId, spec.dirtHeatOperatingHours)
	
	spec.inspection = spec.inspection or {}
    streamWriteInt16(streamId, spec.inspection.state or 1)
    streamWriteInt16(streamId, spec.inspection.finishDay or 0)
    streamWriteInt16(streamId, spec.inspection.finishHour or 0)
    streamWriteInt16(streamId, spec.inspection.finishMinute or 0)
    streamWriteFloat32(streamId, spec.inspection.cost or 0)
    streamWriteFloat32(streamId, spec.inspection.factor or 0)
    streamWriteBool(streamId, spec.inspection.completed or false)

	spec.service = spec.service or {}
    streamWriteInt16(streamId, spec.service.state or 1)
    streamWriteInt16(streamId, spec.service.finishDay or 0)
    streamWriteInt16(streamId, spec.service.finishHour or 0)
    streamWriteInt16(streamId, spec.service.finishMinute or 0)
    streamWriteFloat32(streamId, spec.service.cost or 0)

	spec.repair = spec.repair or {}
    streamWriteInt16(streamId, spec.repair.state or 1)
    streamWriteInt16(streamId, spec.repair.finishDay or 0)
    streamWriteInt16(streamId, spec.repair.finishHour or 0)
    streamWriteInt16(streamId, spec.repair.finishMinute or 0)
    streamWriteFloat32(streamId, spec.repair.cost or 0)

	streamWriteInt32(streamId, table.count(spec.parts))
	for key, part in pairs(spec.parts) do
		streamWriteString(streamId, key)
		streamWriteString(streamId, part.name)
		streamWriteFloat32(streamId, part.operatingHours)
		streamWriteBool(streamId, part.repairreq)
		streamWriteString(streamId, part.prefault)
		streamWriteString(streamId, part.fault)
		streamWriteFloat32(streamId, part.cost)
		streamWriteBool(streamId, part.runOncePerStart)
	end

	local count = #spec.serviceManual
    streamWriteInt32(streamId, count)
    for i=1, count do
        local entry = spec.serviceManual[i]
        streamWriteInt16(streamId, entry.entryType or 0)
        streamWriteInt16(streamId, entry.entryTime or 0)
        streamWriteFloat32(streamId, entry.operatingHours or 0)
        streamWriteFloat32(streamId, entry.odometer or 0)
		streamWriteString(streamId, entry.resultKey or "")
		local errors = entry.errorList or {}
		streamWriteUInt8(streamId, #errors)
		for _, errKey in ipairs(errors) do
			streamWriteString(streamId, errKey)
		end
        streamWriteFloat32(streamId, entry.cost or 0)
    end

	streamWriteFloat32(streamId, spec.batteryDrainAmount)
	streamWriteFloat32(streamId, spec.batteryChargeAmount)
	
	streamWriteFloat32(streamId, spec.RVB_BatteryFillLevel)
	streamWriteInt16(streamId, spec.batteryFillUnitIndex)
	
	--[[local specJumper = self.spec_jumperCable
    if specJumper == nil or specJumper.connection == nil then
        streamWriteBool(streamId, false)
        return
    end
    streamWriteBool(streamId, true)
    local conn = specJumper.connection
	NetworkUtil.writeNodeObject(streamId, conn.donor)
	streamWriteInt16(streamId, conn.state or 0)
	if conn.receiver ~= nil then
		streamWriteBool(streamId, true)
		NetworkUtil.writeNodeObject(streamId, conn.receiver)
	else
		streamWriteBool(streamId, false)
	end
	streamWriteFloat32(streamId, conn.jumperTime or 0)
	streamWriteInt32(streamId, conn.jumperThreshold or 0)
	streamWriteInt32(streamId, conn.activePlayerUserId or 0)]]

end

function VehicleBreakdowns:onReadUpdateStream(streamId, timestamp, connection)

	if connection:getIsServer() then
	--if connection.isServer then
	
		local spec = self.spec_faultData
		if spec == nil then return end

		if streamReadBool(streamId) then
			spec.isrvbSpecEnabled = streamReadBool(streamId)
			spec.totaloperatingHours = streamReadFloat32(streamId)
			spec.operatingHours = streamReadFloat32(streamId)
			spec.dirtHeatOperatingHours = streamReadFloat32(streamId)
		end

		if streamReadBool(streamId) then
			local count = streamReadInt32(streamId)
			for i = 1, count do
				local key = streamReadString(streamId)
				local part = {
					name            = streamReadString(streamId),
					operatingHours  = streamReadFloat32(streamId),
					repairreq       = streamReadBool(streamId),
					prefault        = streamReadString(streamId),
					fault           = streamReadString(streamId),
					cost            = streamReadFloat32(streamId),
					runOncePerStart = streamReadBool(streamId)
				}
				spec.parts[key] = part
			end
			spec.lastUpdateTick = g_currentMission.environment.currentHour .. ":" .. g_currentMission.environment.currentMinute
		end

		if streamReadBool(streamId) then
			--for _, key in ipairs({TIREFL, TIREFR, TIRERL, TIRERR}) do
			--	spec.parts[key].operatingHours = streamReadFloat32(streamId)
			--end
		--end
			local count = streamReadInt32(streamId)  -- olvassuk ki a 4-et
			local tyres = {TIREFL, TIREFR, TIRERL, TIRERR}
			for i = 1, count do
				local key = tyres[i]
				spec.parts[key].operatingHours = streamReadFloat32(streamId)
			end
		end
		
		if streamReadBool(streamId) then
			spec.motorTemperature = streamReadFloat32(streamId)
			spec.fanEnabled = streamReadBool(streamId)
			spec.fanEnableTemperature = streamReadFloat32(streamId)
			spec.fanDisableTemperature = streamReadFloat32(streamId)
			spec.lastFuelUsage = streamReadFloat32(streamId)
			spec.lastDefUsage = streamReadFloat32(streamId)
			spec.lastAirUsage = streamReadFloat32(streamId)
		end
		if streamReadBool(streamId) then
			self.spec_motorized.motorTemperature.value = streamReadFloat32(streamId)
			self.spec_motorized.motorTemperature.valueSend = streamReadFloat32(streamId)
		end
		
		if streamReadBool(streamId) then
			spec.batteryDrainAmount = streamReadFloat32(streamId)
		end
		if streamReadBool(streamId) then
			spec.batteryChargeAmount = streamReadFloat32(streamId)
		end
		
		spec.RVB_BatteryFillLevel = streamReadFloat32(streamId)
		spec.batteryFillUnitIndex = streamReadInt16(streamId)
		
		if streamReadBool(streamId) then
			local count = streamReadUInt8(streamId)
			spec.uiJumperCableMessage = {}
			for i = 1, count do
				spec.uiJumperCableMessage[i] = {
					method = streamReadString(streamId),
					key  = streamReadString(streamId),
					text = streamReadString(streamId),
					value = streamReadFloat32(streamId)
				}
			end
			spec.hasNewUIJumperCableMessage = true
		end

		if streamReadBool(streamId) then
			local count = streamReadUInt8(streamId)
			spec.uiBlinkingMessage = {}
			for i = 1, count do 
				spec.uiBlinkingMessage[i] = {
					key  = streamReadString(streamId),
					text = streamReadString(streamId)
				}
			end
			--if count > 0 then
			--	local last = spec.uiBlinkingMessage[count]
			--	print("onReadUpdateStream " .. last.key)
			--end
			spec.hasNewUIBlinkingMessage = true
		end
		
		

		--[[if streamReadBool(streamId) then
		local count = streamReadUInt8(streamId)
		for i = 1, count do
		local key = streamReadString(streamId)
		local text = streamReadString(streamId)
		g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, self, key, text)
		end
		end]]

		
		if streamReadBool(streamId) then
			spec.motorLoadPercent = streamReadFloat32(streamId) * 100
		end
		
		if streamReadBool(streamId) then
			spec.service.state = streamReadInt16(streamId)
		end
		if streamReadBool(streamId) then
			spec.inspection.state = streamReadInt16(streamId)
		end
		if streamReadBool(streamId) then
			spec.repair.state = streamReadInt16(streamId)
		end
		--if self.spec_jumperCable.connection ~= nil then
		--if streamReadBool(streamId) then
		--	self.spec_jumperCable.connection.jumperTime = streamReadInt32(streamId)
		--end
		--end
		
		--[[local hasConnection = streamReadBool(streamId)
		if hasConnection then
			local donor = NetworkUtil.readNodeObject(streamId)
			local state = streamReadInt16(streamId)
			local hasReceiver = streamReadBool(streamId)
			local receiver = nil
			if hasReceiver then
				receiver = NetworkUtil.readNodeObject(streamId)
			end
			local jumperTime = streamReadFloat32(streamId)
			local jumperThreshold = streamReadInt32(streamId)
			local activePlayerUserId = streamReadInt32(streamId)
			--if donor ~= nil and donor:getIsSynchronized() then
			if donor ~= nil then
				self.spec_jumperCable.connection = {
					donor = donor,
					state = state,
					receiver = receiver,
					jumperTime = jumperTime,
					jumperThreshold = jumperThreshold,
					activePlayerUserId = activePlayerUserId
				}
			end
		end]]

	end

end


function VehicleBreakdowns:onWriteUpdateStream(streamId, connection, dirtyMask)

	if not connection:getIsServer() then
	--if not connection.isServer then
	
		local spec = self.spec_faultData
		if spec == nil then return end
	
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.rvbdirtyFlag) ~= 0) then
			streamWriteBool(streamId, spec.isrvbSpecEnabled)
			streamWriteFloat32(streamId, spec.totaloperatingHours)
			streamWriteFloat32(streamId, spec.operatingHours)
			streamWriteFloat32(streamId, spec.dirtHeatOperatingHours)
		end

		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.partsDirtyFlag) ~= 0) then
			streamWriteInt32(streamId, table.count(spec.parts))
			for key, part in pairs(spec.parts) do
				streamWriteString(streamId, key)
				streamWriteString(streamId, part.name)
				streamWriteFloat32(streamId, part.operatingHours)
				streamWriteBool(streamId, part.repairreq)
				streamWriteString(streamId, part.prefault)
				streamWriteString(streamId, part.fault)
				streamWriteFloat32(streamId, part.cost)
				streamWriteBool(streamId, part.runOncePerStart)
			end
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.updateTyreDirtyFlag) ~= 0) then
			local tyres = {TIREFL, TIREFR, TIRERL, TIRERR}
			streamWriteInt32(streamId, 4)
			for _, key in ipairs(tyres) do
				streamWriteFloat32(streamId, spec.parts[key].operatingHours)
			end
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.motorizedDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.motorTemperature)
			streamWriteBool(streamId, spec.fanEnabled)
			streamWriteFloat32(streamId, spec.fanEnableTemperature)
			streamWriteFloat32(streamId, spec.fanDisableTemperature)
			streamWriteFloat32(streamId, spec.lastFuelUsage)
			streamWriteFloat32(streamId, spec.lastDefUsage)
			streamWriteFloat32(streamId, spec.lastAirUsage)
		
			self.spec_motorized.motorTemperature.valueSend = spec.motorTemperature
			self.spec_motorized.motorFan.enabled = spec.fanEnabled
			self.spec_motorized.motorFan.enableTemperature = spec.fanEnableTemperature
			self.spec_motorized.motorFan.disableTemperature = spec.fanDisableTemperature
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.motorTemperatureDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, self.spec_motorized.motorTemperature.value)
			streamWriteFloat32(streamId, self.spec_motorized.motorTemperature.valueSend)
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.batteryDrainDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.batteryDrainAmount)
		end
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.batteryChargeDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.batteryChargeAmount)
		end
		
		streamWriteFloat32(streamId, spec.RVB_BatteryFillLevel)
		streamWriteInt16(streamId, spec.batteryFillUnitIndex)
		
		--[[if streamWriteBool(streamId, bit32.band(dirtyMask, spec.uiEventsDirtyFlag) ~= 0) then
			local message = spec.uiProgressMessage
			local count = #message
			streamWriteUInt8(streamId, count)
			for i = 1, count do
				streamWriteString(streamId, message[i].key)
				streamWriteString(streamId, message[i].text)
			end
			spec.uiProgressMessage = {}
		end]]

	
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.uiJumperCableMessageDirtyFlag) ~= 0) then
			local message = spec.uiJumperCableMessage
			local count = #message
			streamWriteUInt8(streamId, count)
			for i = 1, count do
				streamWriteString(streamId, message[i].method)
				streamWriteString(streamId, message[i].key)
				streamWriteString(streamId, message[i].text)
				streamWriteFloat32(streamId, message[i].value)
			end
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.uiBlinkingDirtyFlag) ~= 0) then
			local message = spec.uiBlinkingMessage or {}
			local count = #message
			streamWriteUInt8(streamId, count)
			for i = 1, count do
				streamWriteString(streamId, message[i].key)
				streamWriteString(streamId, message[i].text)
			end
		end

		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.motorLoadDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.motorLoadPercent / 100)
		end
		
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.serviceDirtyFlag) ~= 0) then
			streamWriteInt16(streamId, spec.service.state)
		end
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.inspectionDirtyFlag) ~= 0) then
			streamWriteInt16(streamId, spec.inspection.state)
		end
		if streamWriteBool(streamId, bit32.band(dirtyMask, spec.repairDirtyFlag) ~= 0) then
			streamWriteInt16(streamId, spec.repair.state)
		end
		

		--[[if streamWriteBool(streamId, bit32.band(dirtyMask, spec.jumperCableDirtyFlag) ~= 0) then
			local specJumper = self.spec_jumperCable
			if specJumper == nil or specJumper.connection == nil then
				streamWriteBool(streamId, false)
				return
			end
			streamWriteBool(streamId, true)
			local conn = specJumper.connection
			NetworkUtil.writeNodeObject(streamId, conn.donor)
			streamWriteInt16(streamId, conn.state or 0)
			if conn.receiver ~= nil then
				streamWriteBool(streamId, true)
				NetworkUtil.writeNodeObject(streamId, conn.receiver)
			else
				streamWriteBool(streamId, false)
			end
			streamWriteFloat32(streamId, conn.jumperTime or 0)
			streamWriteInt32(streamId, conn.jumperThreshold or 0)
			streamWriteInt32(streamId, conn.activePlayerUserId or 0)
		end]]

	end
end

function VehicleBreakdowns:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_faultData

	xmlFile:setValue(key .. "#isrvbSpecEnabled", spec.isrvbSpecEnabled)
	xmlFile:setValue(key .. "#TotaloperatingHours", spec.totaloperatingHours)
	xmlFile:setValue(key .. "#operatingHours", spec.operatingHours)
	xmlFile:setValue(key .. "#dirtHeatOperatingHours", spec.dirtHeatOperatingHours)

	xmlFile:setValue(key .. ".vehicleService#state", spec.service.state)
	xmlFile:setValue(key .. ".vehicleService#finishDay", spec.service.finishDay)
	xmlFile:setValue(key .. ".vehicleService#finishHour", spec.service.finishHour)
	xmlFile:setValue(key .. ".vehicleService#finishMinute", spec.service.finishMinute)
	xmlFile:setValue(key .. ".vehicleService#cost", spec.service.cost)

	xmlFile:setValue(key .. ".vehicleInspection#state", spec.inspection.state)
	xmlFile:setValue(key .. ".vehicleInspection#finishDay", spec.inspection.finishDay)
	xmlFile:setValue(key .. ".vehicleInspection#finishHour", spec.inspection.finishHour)
	xmlFile:setValue(key .. ".vehicleInspection#finishMinute", spec.inspection.finishMinute)
	xmlFile:setValue(key .. ".vehicleInspection#cost", spec.inspection.cost)
	xmlFile:setValue(key .. ".vehicleInspection#factor", spec.inspection.factor)
	xmlFile:setValue(key .. ".vehicleInspection#completed", spec.inspection.completed)
	
	xmlFile:setValue(key .. ".vehicleRepair#state", spec.repair.state)
	xmlFile:setValue(key .. ".vehicleRepair#finishDay", spec.repair.finishDay)
	xmlFile:setValue(key .. ".vehicleRepair#finishHour", spec.repair.finishHour)
	xmlFile:setValue(key .. ".vehicleRepair#finishMinute", spec.repair.finishMinute)
	xmlFile:setValue(key .. ".vehicleRepair#cost", spec.repair.cost)

	PartManager.savePartsToXML(self, xmlFile, key)

	local manual = spec.serviceManual
    if manual then
		local i = 0
		for i, entry in ipairs(manual) do
			local manualKey = string.format("%s.serviceManual.entry(%d)", key, i - 1)
			xmlFile:setValue(manualKey.."#entryType", entry.entryType)
			xmlFile:setValue(manualKey.."#entryTime", entry.entryTime)
			xmlFile:setValue(manualKey.."#operatingHours", entry.operatingHours)
			xmlFile:setValue(manualKey.."#odometer", entry.odometer)
			--xmlFile:setValue(manualKey.."#result", entry.result)
			xmlFile:setValue(manualKey.."#resultKey", entry.resultKey)
			--xmlFile:setValue(manualKey.."#errorList", entry.errorList)
			-- errorList mentése
			if entry.errorList ~= nil and #entry.errorList > 0 then
				xmlFile:setValue(manualKey.."#errorCount", #entry.errorList)
				for i, errKey in ipairs(entry.errorList) do
					xmlFile:setValue(manualKey..".error("..(i-1)..")#key", errKey)
				end
			else
				xmlFile:setValue(manualKey.."#errorCount", 0)
			end

			xmlFile:setValue(manualKey.."#cost", entry.cost)
        end
    end

end

function VehicleBreakdowns.onRegisterActionEvents(self, _, isActiveForInputIgnoreSelection)
	if self.isClient and (self.getIsEntered and self:getIsEntered()) then
		local spec = self.spec_lights
		self:clearActionEventsTable(spec.actionEvents)
		local rvbToggleLights, rvbToggleLightsBack, rvbToggleLightFront, rvbToggleWorkLightBack, rvbToggleWorkLightFront, rvbToggleHighBeamLight
		local rvbToggleBeaconLights, rvbToggleTurnLightHazard, rvbToggleTurnLightLeft, rvbToggleTurnLightRight
		if self.getBatteryFillLevelPercentage then
			if self:getBatteryFillLevelPercentage() > BATTERY_LEVEL.LIGHTS then
				rvbToggleLights = Lights.actionEventToggleLights
				rvbToggleLightsBack = Lights.actionEventToggleLightsBack
				rvbToggleLightFront = Lights.actionEventToggleLightFront
				rvbToggleWorkLightBack = Lights.actionEventToggleWorkLightBack
				rvbToggleWorkLightFront = Lights.actionEventToggleWorkLightFront
				rvbToggleHighBeamLight = Lights.actionEventToggleHighBeamLight
				rvbToggleBeaconLights = Lights.actionEventToggleBeaconLights
				rvbToggleTurnLightHazard = Lights.actionEventToggleTurnLightHazard
				rvbToggleTurnLightLeft = Lights.actionEventToggleTurnLightLeft
				rvbToggleTurnLightRight = Lights.actionEventToggleTurnLightRight
			elseif self:getBatteryFillLevelPercentage() <= BATTERY_LEVEL.LIGHTS and self:getBatteryFillLevelPercentage() > BATTERY_LEVEL.LIGHTS_BEACONS then
				rvbToggleLights = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleLightsBack = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleLightFront = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleWorkLightBack = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleWorkLightFront = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleHighBeamLight = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleBeaconLights = Lights.actionEventToggleBeaconLights
				rvbToggleTurnLightHazard = Lights.actionEventToggleTurnLightHazard
				rvbToggleTurnLightLeft = Lights.actionEventToggleTurnLightLeft
				rvbToggleTurnLightRight = Lights.actionEventToggleTurnLightRight
			elseif self:getBatteryFillLevelPercentage() <= BATTERY_LEVEL.LIGHTS_BEACONS then
				rvbToggleLights = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleLightsBack = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleLightFront = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleWorkLightBack = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleWorkLightFront = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleHighBeamLight = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleBeaconLights = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleTurnLightHazard = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleTurnLightLeft = VehicleBreakdowns.actionToggleLightsFault
				rvbToggleTurnLightRight = VehicleBreakdowns.actionToggleLightsFault
			end
		end
		if self.isLightingsRepairRequired and self:isLightingsRepairRequired() then
			rvbToggleLights = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleLightsBack = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleLightFront = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleWorkLightBack = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleWorkLightFront = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleHighBeamLight = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleBeaconLights = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightHazard = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightLeft = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightRight = VehicleBreakdowns.actionToggleLightsFault
		end
		local isWorkshopActive = false
		if self.spec_faultData ~= nil then
			local specRVB = self.spec_faultData
			isWorkshopActive =
				specRVB.service.state == SERVICE_STATE.ACTIVE or
				specRVB.service.state == SERVICE_STATE.PAUSED or
				specRVB.inspection.state == INSPECTION_STATE.ACTIVE or
				specRVB.inspection.state == INSPECTION_STATE.PAUSED or
				specRVB.repair.state == REPAIR_STATE.ACTIVE or
				specRVB.repair.state == REPAIR_STATE.PAUSED
		end
		if isWorkshopActive then
			rvbToggleLights = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleLightsBack = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleLightFront = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleWorkLightBack = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleWorkLightFront = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleHighBeamLight = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleBeaconLights = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightHazard = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightLeft = VehicleBreakdowns.actionToggleLightsFault
			rvbToggleTurnLightRight = VehicleBreakdowns.actionToggleLightsFault
		end
		if isActiveForInputIgnoreSelection then
			local _, actionEventIdLight = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_LIGHTS, self, rvbToggleLights, false, true, false, true, nil)
			spec.actionEventIdLight = actionEventIdLight
			local _, actionEventIdReverse = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_LIGHTS_BACK, self, rvbToggleLightsBack, false, true, false, true, nil)
			local _, actionEventIdFront = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_LIGHT_FRONT, self, rvbToggleLightFront, false, true, false, true, nil)
			local _, actionEventIdWorkBack = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_WORK_LIGHT_BACK, self, rvbToggleWorkLightBack, false, true, false, true, nil)
			local _, actionEventIdWorkFront = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_WORK_LIGHT_FRONT, self, rvbToggleWorkLightFront, false, true, false, true, nil)
			local _, actionEventIdHighBeam = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_HIGH_BEAM_LIGHT, self, rvbToggleHighBeamLight, false, true, false, true, nil)
			self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_TURNLIGHT_HAZARD, self, rvbToggleTurnLightHazard, false, true, false, true, nil)
			self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_TURNLIGHT_LEFT, self, rvbToggleTurnLightLeft, false, true, false, true, nil)
			self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_TURNLIGHT_RIGHT, self, rvbToggleTurnLightRight, false, true, false, true, nil)
			local _, actionEventIdBeacon = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_BEACON_LIGHTS, self, rvbToggleBeaconLights, false, true, false, true, nil)
			spec.actionEventsActiveChange = {
				actionEventIdFront,
				actionEventIdWorkBack,
				actionEventIdWorkFront,
				actionEventIdHighBeam,
				actionEventIdBeacon
			}
			for _, actionEvent in pairs(spec.actionEvents) do
				if actionEvent.actionEventId ~= nil then
				--print("actionEvent.actionEventId "..actionEvent.actionEventId)
					g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, false)
					g_inputBinding:setActionEventTextPriority(actionEvent.actionEventId, GS_PRIO_LOW)
				end
			end
			g_inputBinding:setActionEventTextVisibility(spec.actionEventIdLight, not g_currentMission.environment.isSunOn)
			g_inputBinding:setActionEventTextVisibility(actionEventIdReverse, false)
		end


		if self.spec_faultData == nil then return end
		local spec = self.spec_faultData
		if spec.actionEvents == nil then spec.actionEvents = {} end
		self:clearActionEventsTable(spec.actionEvents)
		if isActiveForInputIgnoreSelection then
			local set, actionEventIdSet = self:addActionEvent(spec.actionEvents, InputAction.RVB_MENU, self, VehicleBreakdowns.actionToggleRVBMenu, false, true, false, true, nil)
			if set then
				g_inputBinding:setActionEventTextPriority(actionEventIdSet, GS_PRIO_VERY_HIGH)
				g_inputBinding:setActionEventTextVisibility(actionEventIdSet, true)
				g_inputBinding:setActionEventActive(actionEventIdSet, true)
			end
			local setSpec, actionEventIdSetSpec = self:addActionEvent(spec.actionEvents, InputAction.RVB_SPEC, self, VehicleBreakdowns.actionToggleRVBSpecialization, false, true, false, true, nil)
			if setSpec then
				g_inputBinding:setActionEventTextPriority(actionEventIdSetSpec, GS_PRIO_VERY_HIGH)
				g_inputBinding:setActionEventTextVisibility(actionEventIdSetSpec, true)
				g_inputBinding:setActionEventActive(actionEventIdSetSpec, true)
			end

			--VehicleBreakdowns.updateActionEvents(self)
		end
			
	end
end

	
	
function VehicleBreakdowns.updateActionEvents(self)
	local spec = self.spec_faultData
	if spec.actionEvents == nil then spec.actionEvents = {} end
	
	local jc = self.spec_jumperCable
    if jc == nil or jc.connection == nil then
        return
    end

    local conn = jc.connection
    local donor = conn.donor
    local receiver = conn.receiver
	
	
	local actionEventJS = spec.actionEvents[InputAction.RVB_JUMPSTARTOFF]
	local vehiclesConnecting = donor ~= nil and receiver ~= nil and true --g_rvbPlayer:areJumperCablesConnected()
	if not vehiclesConnecting and spec.isJumpStarting then spec.isJumpStarting = false end
	if actionEventJS ~= nil then
		local text
		g_inputBinding:setActionEventTextVisibility(actionEventJS.actionEventId, vehiclesConnecting)
		if spec.isJumpStarting then
			text = g_i18n:getText("action_RVB_JUMPSTARTON")
		else
			text = g_i18n:getText("input_RVB_JUMPSTARTOFF")
		end
		g_inputBinding:setActionEventActive(actionEventJS.actionEventId, true)
		g_inputBinding:setActionEventTextPriority(actionEventJS.actionEventId, GS_PRIO_VERY_HIGH)
		g_inputBinding:setActionEventText(actionEventJS.actionEventId, text)
	end
end


function VehicleBreakdowns:actionToggleRVBMenu()
	local rvb = self.spec_faultData
	if not rvb.isrvbSpecEnabled then
        return
    end
	if not self.isClient then
      return
    end
    if not g_currentMission.isSynchronizingWithPlayers then
      if not g_gui:getIsGuiVisible() then
        g_gui:showDialog("RVBMenu")
      end
    end
end

function VehicleBreakdowns:actionToggleRVBSpecialization()
	if self.spec_faultData == nil then
        return
    end
	local spec = self.spec_faultData
	if self.isExcluded and self:isExcluded() then
		spec.isrvbSpecEnabled = false
		return
	end
	g_client:getServerConnection():sendEvent(RVBToggleSpec_Event.new(self, not spec.isrvbSpecEnabled))
end



function VehicleBreakdowns:actionToggleLightsFault(actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_faultData
	local lightsText
	if actionName == InputAction.TOGGLE_LIGHTS then
		if not self:isLightingsRepairRequired() then
			--if self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS then
				lightsText = "RVB_fault_BHlights"
			--end
		else
			lightsText = "RVB_fault_lights"
		end
	elseif actionName == InputAction.TOGGLE_HIGH_BEAM_LIGHT then
		if not self:isLightingsRepairRequired() then
			--if self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS then
				lightsText = "RVB_fault_BHlights"
			--end
		else
			lightsText = "RVB_fault_lights"
		end
	elseif actionName == InputAction.TOGGLE_BEACON_LIGHTS then
		if not self:isLightingsRepairRequired() then
			--if self:getBatteryFillLevelPercentage() ~= 0 and self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS_BEACONS then
				lightsText = "RVB_fault_BHlights"
			--end
		else
			lightsText = "RVB_fault_lights"
		end
	elseif actionName == InputAction.TOGGLE_BEACON_LIGHTS then
		if not self:isLightingsRepairRequired() then
			--if self:getBatteryFillLevelPercentage() ~= 0 and self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS_BEACONS then
				lightsText = "RVB_fault_BHlights"
			--end
		else
			lightsText = "RVB_fault_lights"
		end
	end

	local serviceState = spec.service.state
	local inspectionState = spec.inspection.state
	local repairState = spec.repair.state

	if serviceState == SERVICE_STATE.ACTIVE or serviceState == SERVICE_STATE.PAUSED then
		lightsText = "RVB_fault_lights_SERVICE"
	elseif inspectionState == INSPECTION_STATE.ACTIVE or inspectionState == INSPECTION_STATE.PAUSED then
		lightsText = "RVB_fault_lights_INSPECTION"
	elseif repairState == REPAIR_STATE.ACTIVE or repairState == REPAIR_STATE.PAUSED then
		lightsText = "RVB_fault_lights_REPAIR"
	elseif not self:isLightingsRepairRequired() then
		lightsText = "RVB_fault_BHlights"
	else
		lightsText = "RVB_fault_lights"
	end
	if g_rvbGeneralSettings.alertmessage then
		if self.getIsEntered and self:getIsEntered() then
			g_currentMission:showBlinkingWarning(g_i18n:getText(lightsText), 1500)
		else
		--	g_currentMission.hud:addSideNotification(VehicleBreakdowns.INGAME_NOTIFICATION, string.format(g_i18n:getText("RVB_fault_lights_hud"), self:getFullName()), 5000)
		end
	end
end



--[[
function VehicleBreakdowns.StopAI(self)
    local rootVehicle = self.rootVehicle
    if rootVehicle ~= nil and rootVehicle:getIsAIActive() then
        rootVehicle:stopCurrentAIJob(AIMessageErrorVehicleBroken.new())
    end
end
]]






--[[function VehicleBreakdowns:onSetPartsLifetime(partsName, partsLifetime)
	--print("DEBUG: onSetPartsLifetime called! " .. partsName, partsLifetime)
    local GSET = g_currentMission.vehicleBreakdowns.generalSettings
    local daysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod
    for _, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle.spec_faultData then
            local part = vehicle.spec_faultData.parts[partsName]
            if part and part.lifetime ~= partsLifetime then
                part.lifetime = partsLifetime
                if GSET.difficulty == 1 then
                    part.tmp_lifetime = part.lifetime * 2 * daysPerPeriod
                elseif GSET.difficulty == 2 then
                    part.tmp_lifetime = part.lifetime * 1 * daysPerPeriod
                else
                    part.tmp_lifetime = part.lifetime / 2 * daysPerPeriod
                end
                --Logging.info("[RVB] Updated %s lifetime to %s on %s", partsName, partsLifetime, vehicle:getFullName())
				self.rvbDebugger:info("Updated %s lifetime to %s on %s", partsName, partsLifetime, vehicle:getFullName())
				if self.isServer then
					--vehicle:raiseDirtyFlags(vehicle.spec_faultData.partsDirtyFlag)
				end
				RVBParts_Event.sendEvent(vehicle, vehicle.spec_faultData.parts)
            end
        end
    end
end]]



	
function VehicleBreakdowns:onStartDirtHeat(dt)
	local spec = self.spec_faultData
	if spec == nil or not self.isServer then return end
	if self.isServer then
		local dirt = self.spec_washable and self.spec_washable:getDirtAmount() or 0
		if dirt > 0.99 then
			spec.dirtHeatUpdateTimer = (spec.dirtHeatUpdateTimer or 0) + dt
			if spec.dirtHeatUpdateTimer >= RVB_DELAY.DIRT_HEAT then
				self:updateDirtHeat(spec.dirtHeatUpdateTimer, spec)
				spec.dirtHeatUpdateTimer = 0
			end
			self:raiseActive()
		else
			if spec.dirtHeatOperatingHours > 0 then
				spec.dirtHeatUpdateTimer = 0
				--spec.dirtHeatOperatingHours = 0
				self:raiseDirtyFlags(spec.dirtHeatDirtyFlag)
			end
		end
	end
end
function VehicleBreakdowns:updateDirtHeat(msDelta, spec)
    local runtimeIncrease = msDelta * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
    spec.dirtHeatOperatingHours = math.min(spec.dirtHeatOperatingHours + runtimeIncrease, 10)
    self:raiseDirtyFlags(spec.dirtHeatDirtyFlag)
end


function VehicleBreakdowns:onStartChargeBattery(dt, isActiveForInputIgnoreSelection)
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





--[[
Növelje az ablaktörlő üzemidejét
Amikor a motor jár
Ha az ablaktörlő működik és esik az eső
Increase wiper operating hours
When the engine is running
If the wiper is working and it is raining
]]










function VehicleBreakdowns:onStartOverheatingFailure(dt)
	if self.isServer then
		local spec = self.spec_faultData
		local motorSpec = self.spec_motorized
		if not spec or not motorSpec or not self:getIsMotorStarted() then
			return
		end
		-- Csak akkor fut, ha tényleg overheating hiba van
		local enginePart = spec.parts[ENGINE]
		if not enginePart or (enginePart.fault ~= "overheating" and enginePart.prefault ~= "overheating") then
			return
		end
		spec.overheatingUpdateTimer = (spec.overheatingUpdateTimer or 0) + dt
		if spec.overheatingUpdateTimer >= RVB_DELAY.OVERHEATING_FAILURE then
			local engineTemp = motorSpec.motorTemperature and motorSpec.motorTemperature.value or 0
			self:updateOverheatingFailure(engineTemp)
			spec.overheatingUpdateTimer = 0
		end
		self:raiseActive()
	end
end
function VehicleBreakdowns:updateOverheatingFailure(engineTemp)
	if engineTemp <= 100 then return end
	-- Minél melegebb, annál nagyobb az esély leállásra
	local shutdownChance = 0
	if engineTemp > 119 then
		shutdownChance = 70
	elseif engineTemp > 110 then
		shutdownChance = 25
	elseif engineTemp > 100 then
		shutdownChance = 5
	end
	if shutdownChance > 0 and math.random(100) <= shutdownChance then
		if rvbAIJobVehicle ~= nil and rvbAIJobVehicle.StopAI ~= nil then
			rvbAIJobVehicle.StopAI(self)
		end
		self:stopMotor()
		self.rvbDebugger:info("Engine stopped due to overheating! Temp = %.1f°C", engineTemp)
	end
end
-- Motor túlmelegedés miatti leállás
function VehicleBreakdowns:updateOverheatingFailure_OLD(dt)
	local spec = self.spec_faultData
	local motorSpec = self.spec_motorized
	if not spec or not motorSpec or not self:getIsMotorStarted() then
		return
	end
	-- Csak akkor fut, ha tényleg overheating hiba van
	local enginePart = spec.parts[ENGINE]
	if not enginePart or (enginePart.fault ~= "overheating" and enginePart.prefault ~= "overheating") then
		return
	end

	self.overheatingUpdateTimer = (self.overheatingUpdateTimer or 0) + dt
    if self.overheatingUpdateTimer >= RVB_DELAY.OVERHEATING_FAILURE then
        self.overheatingUpdateTimer = 0

		local engineTemp = motorSpec.motorTemperature and motorSpec.motorTemperature.value or 0
		if engineTemp <= 100 then
			return
		end

		-- Minél melegebb, annál nagyobb az esély leállásra
		local shutdownChance = 0
		if engineTemp > 119 then
			shutdownChance = 70
		elseif engineTemp > 110 then
			shutdownChance = 25
		elseif engineTemp > 100 then
			shutdownChance = 5
		end

		if shutdownChance > 0 and math.random(100) <= shutdownChance then
			if self.isServer then
				--if self.StopAI then
				--	self:StopAI(self)
				--end
				if rvbAIJobVehicle ~= nil and rvbAIJobVehicle.StopAI ~= nil then
					rvbAIJobVehicle.StopAI(self)
				end
				self:stopMotor()
				--print(string.format("[RVB] Motor leállt túlmelegedés miatt! Temp=%.1f°C", engineTemp))
				self.rvbDebugger:info("Engine stopped due to overheating! Temp = %.1f°C", engineTemp)
			end
		end
	end
	self:raiseActive()
end


function VehicleBreakdowns:updateEngineTorque(isActive)
    -- Ha csak az aktív járműre akarod számolni, hagyd bent, 
    -- ha minden járműre (pl. AI, MP), akkor vedd ki:
    -- if not isActive then return end

    local spec = self.spec_faultData
    local motorSpec = self.spec_motorized
    if not spec or not motorSpec or not self:getIsMotorStarted() then
        return
    end

		
	local fuelFillUnitIndex = self:getConsumerFillUnitIndex(FillType.DIESEL) or self:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE) or self:getConsumerFillUnitIndex(FillType.METHANE)

		if fuelFillUnitIndex ~= nil then
			local fillLevel = self:getFillUnitFillLevel(fuelFillUnitIndex)
			local fillType = self:getFillUnitFillType(fuelFillUnitIndex)
			local unit = fillType == FillType.ELECTRICCHARGE and "kw" or fillType == FillType.METHANE and "kg" or "l"
			local str3 = string.format("%s:", g_fillTypeManager:getFillTypeNameByIndex(fillType))
			local str4 = string.format("%.2f%s/h (%.2f%s)", motorSpec.lastFuelUsage, unit, fillLevel, unit)
			--print(str3 .. str4)
		end

		local defFillUnitIndex = self:getConsumerFillUnitIndex(FillType.DEF)

		if defFillUnitIndex ~= nil then
			local fillLevel = self:getFillUnitFillLevel(defFillUnitIndex)
			local str3 = "DEF:"
			local str4 = string.format("%.2fl/h (%.2fl)", motorSpec.lastDefUsage, fillLevel)
			--print(str3 .. str4)
		end
		
    local partData = spec.parts[ENGINE]
    local registry = FaultRegistry[ENGINE]
    if not partData or not registry or not registry.variants or not partData.pre_random then 
        return 
    end

    -- Prefault előjele → fault valós hiba
    local faultName = (partData.prefault ~= "empty" and partData.prefault) or partData.fault
    if faultName and faultName ~= "empty" then
        local variant = registry.variants[faultName]
        if variant and variant.torqueFactor then
            local progress = 1.0
--print("updateEngineTorque")	
            -- Ha csak prefault van → progress arányos a küszöbig
            if partData.fault == "empty" and partData.prefault ~= "empty" and partData.pre_random > 0 then
				local maxLifetime = PartManager.getMaxPartLifetime(self, ENGINE)
                local partFoot = (partData.operatingHours * 100) / maxLifetime
		--		print("partFoot "..partFoot)
                local diff = math.max(0, registry.breakThreshold - partFoot)
		--		print("diff "..diff)
                --local maxDiff = 5 -- előhiba -1..-5%-nál jön

				local maxDiff = partData.pre_random
				--[[print("maxDiffw "..maxDiffw)
				local defaultMaxDiff = 5 -- előhiba hatása 5%-ig
				local maxDiff = partData.pre_random or defaultMaxDiff
				if maxDiff <= 0 then
					maxDiff = defaultMaxDiff
				end]]
				
				

	--			print("maxDiff "..maxDiff)
	--			print("progress OLD " .. math.min(math.max(1 - (diff / 5), 0), 1))
				progress = math.min(math.max(1 - (diff / maxDiff), 0), 1)
				
				
				--local diff = math.max(0, registry.breakThreshold - partFoot)
				--local maxDiff = 5 -- előhiba -1..-5%-nál jön 
				--progress = 1 - (diff / maxDiff)
                --progress = 1 - (diff / maxDiff) -- 0 → gyenge hatás, 1 → teljes hatás
	



            end
--print("progress "..progress)

            -- Dinamikus nyomaték számítása
            --local dynamicTorque = 1 - ((1 - variant.torqueFactor) * progress)
			local dynamicTorque = 1 + (variant.torqueFactor - 1) * progress

--print("dynamicTorque "..dynamicTorque)
            -- Csak akkor alkalmazzuk, ha tényleg változott
            if math.abs(dynamicTorque - (spec.lastTorqueFactor or 1)) > 0.01 then
                if self.isServer then
                    applyEngineTorqueModifier(self, dynamicTorque)
                end
                spec.lastTorqueFactor = dynamicTorque
            end

            spec.isTorqueModified = true
            return
        end
    end

    -- Ha nincs sem prefault, sem fault → reset
    if spec.isTorqueModified then
        if self.isServer then
            resetEngineTorque(self)
        end
        spec.isTorqueModified = false
        spec.lastTorqueFactor = nil
    end
end

function VehicleBreakdowns:updateEngineSpeedLimit(isActive)
    -- Ha csak az aktív járműre akarod számolni, hagyd bent, 
    -- ha minden járműre (pl. AI, MP), akkor vedd ki:
    -- if not isActive then return end

    local spec = self.spec_faultData
    local motorSpec = self.spec_motorized
	local motor = motorSpec and motorSpec.motor
    if not spec or not motorSpec or not motor or not self:getIsMotorStarted() then
        return
    end

    local partData = spec.parts[ENGINE]
    local registry = FaultRegistry[ENGINE]
    if not partData or not registry or not registry.variants or not partData.pre_random then 
        return 
    end

    -- Prefault előjele → fault valós hiba
    --local faultName = (partData.prefault ~= "empty" and partData.prefault) or partData.fault
	local faultName = partData.fault
    if faultName and faultName ~= "empty" then
        local variant = registry.variants[faultName]
        if variant and variant.limitPercent then
            local progress = 1.0

            -- Ha csak prefault van → progress arányos a küszöbig
            --[[if partData.fault == "empty" and partData.prefault ~= "empty" and partData.pre_random > 0 then
                local partFoot = (partData.operatingHours * 100) / partData.tmp_lifetime
                local diff = math.max(0, registry.breakThreshold - partFoot)
				local maxDiff = partData.pre_random
				progress = math.min(math.max(1 - (diff / maxDiff), 0), 1)
            end]]

            -- Dinamikus speedlimit számítása
			local dynamicSpeed = 1 + (variant.limitPercent - 1) * progress

            -- Csak akkor alkalmazzuk, ha tényleg változott
            if math.abs(dynamicSpeed - (spec.lastSpeedLimitPercent or 1)) > 0.01 then
                if self.isServer then print("applySpeedLimit "..dynamicSpeed)
					applySpeedLimit(self, dynamicSpeed)
                end
                spec.lastSpeedLimitPercent = dynamicSpeed
            end

            spec.isSpeedLimitPercent = true
            return
        end
    end

    -- Ha nincs sem prefault, sem fault → reset
    if spec.isSpeedLimitPercent then
        if self.isServer then
            resetSpeedLimit(self)
        end
        spec.isSpeedLimitPercent = false
        spec.lastSpeedLimitPercent = nil
    end
end


function VehicleBreakdowns:updateExhaustEffect()
    local spec = self.spec_faultData
    local motorSpec = self.spec_motorized
    if not spec or not motorSpec or not motorSpec.exhaustEffects then return end

    local registry = FaultRegistry[ENGINE]
    local partData = spec.parts[ENGINE]
    if not partData then return end

    local faultName = (partData.prefault ~= "empty" and partData.prefault) or partData.fault
    if not faultName or faultName == "empty" then return end

    local variant = registry.variants[faultName]

    local engineTemp = motorSpec.motorTemperature and motorSpec.motorTemperature.value or MOTORTEMP_THRESHOLD
    local rpm = motorSpec.motor:getEqualizedMotorRpm()
    local maxRpm = motorSpec.motor:getMaxRpm()
    local rpmFactor = rpm / maxRpm

    local progress = 1.0
    if partData.fault == "empty" and partData.prefault ~= "empty" then
		local maxLifetime = PartManager.getMaxPartLifetime(self, ENGINE)
        local partFoot = (partData.operatingHours * 100) / maxLifetime
        local diff = math.max(0, registry.breakThreshold - partFoot)
        local maxDiff = 5
        progress = 1 - (diff / maxDiff)
    end

    for _, exhaustEffect in ipairs(motorSpec.exhaustEffects) do
        if not exhaustEffect.defaultMinRpmColor then
            exhaustEffect.defaultMinRpmColor = table.clone(exhaustEffect.minRpmColor)
            exhaustEffect.defaultMaxRpmColor = table.clone(exhaustEffect.maxRpmColor)
        end

        local baseMin = variant and variant.exhaustEffect and variant.exhaustEffect.minRpmColor or exhaustEffect.defaultMinRpmColor
        local baseMax = variant and variant.exhaustEffect and variant.exhaustEffect.maxRpmColor or exhaustEffect.defaultMaxRpmColor

        -- Hideg motor → fehéres gőz
        local tempFactor = 1
        if engineTemp < MOTORTEMP_THRESHOLD then
            tempFactor = 0.6 + (engineTemp / MOTORTEMP_THRESHOLD) * 0.3
        elseif engineTemp > 100 then
            tempFactor = 1.1
        end

        local rpmStrength = 0.6 + rpmFactor * 1.4

        local function interpolateColor(baseColor, progress)
			
            local r = baseColor[1] * (0.5 + 0.5 * progress)
            local g = baseColor[2] * (0.5 + 0.5 * progress)
            local b = baseColor[3] * (0.5 + 0.5 * progress)
            local a = baseColor[4] * rpmStrength * progress
			
            return {math.min(r*tempFactor,1), math.min(g*tempFactor,1), math.min(b*tempFactor,1), math.min(a,10)}
        end

		exhaustEffect.minRpmColor = interpolateColor(baseMin, progress)
		exhaustEffect.maxRpmColor = interpolateColor(baseMax, progress)
    end
end










function VehicleBreakdowns:onUpdateTickJumperCable(dt, isActiveForInputIgnoreSelection)

    local specFault  = self.spec_faultData
    local specJumper = self.spec_jumperCable

    if specFault == nil or not specFault.isrvbSpecEnabled then
        return
    end

    local conn = specJumper.connection
    if conn == nil then
        return
    end

    if conn.donor.rootNode == self.rootNode then
        self:raiseActive()
    end

    local donor    = conn.donor
    local receiver = conn.receiver

    ------------------------------------------------------------------
    -- 1️ DONOR VAN, RECEIVER MÉG NINCS (gyalogos figyelmeztetés)
    --    CSAK KLIENSEN!
    ------------------------------------------------------------------
    if self.isClient and g_dedicatedServer == nil and donor ~= nil and receiver == nil then

        if self ~= donor then
            return
        end

        local distance = nil
        local isEntered    = self.getIsEntered and self:getIsEntered() or false
        local isControlled = self.getIsControlled and self:getIsControlled() or false

        if not (isEntered or isControlled) then
            if g_localPlayer ~= nil and g_localPlayer.userId == donor.spec_jumperCable.connection.activePlayerUserId then
                distance = calcDistanceFrom(donor.rootNode, g_localPlayer.rootNode)
            end
        elseif self.rootNode == donor.rootNode then
            distance = 0
        end

        if distance ~= nil then

            local showWarning = true

            if not donor:getIsEntered() and g_localPlayer ~= nil and g_localPlayer.userId == donor.spec_jumperCable.connection.activePlayerUserId
			and g_localPlayer:getCurrentVehicle() ~= nil then
                showWarning = false
            end

            if g_rvbPlayer.vehicle ~= nil and g_rvbPlayer.vehicle == donor and donor == self then
                g_currentMission:addExtraPrintText(
                    string.format(
                        g_i18n:getText("RVB_blinking_connecting_length"),
                        string.format("%.1f", distance),
                        JUMPERCABLE_LENGTH
                    )
                )
            end
            if distance > JUMPERCABLE_MINRADIUS and distance <= JUMPERCABLE_LENGTH then
                g_currentMission:showBlinkingWarning(
                    string.format(
                        g_i18n:getText("RVB_blinking_connecting_toofar"),
                        string.format("%.1f", distance)
                    ),
                    100,
                    getMD5("jumperCableOutVehicle")
                )
			end
			if distance > JUMPERCABLE_LENGTH and self.rootNode == donor.rootNode then
				donor:setJumperCableConnection(
					donor,
					JUMPERCABLE_STATE.DONOR_DISCONNECT,
					nil,
					0,
					0,
					g_localPlayer.userId
				)
				if showWarning then
					g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_disconnecting_toofar"), donor:getFullName()), 1500)
				end
			end
        end
    end

    ------------------------------------------------------------------
    -- 2️ SZERVER OLDALI LOGIKA (DÖNTÉSEK)
    ------------------------------------------------------------------
    if self.isServer and donor ~= nil then
		if conn ~= nil then
        if donor:getIsMotorStarted() and receiver ~= nil then
            if conn.jumperTime < conn.jumperThreshold then
                --conn.jumperTime = conn.jumperTime + dt
				donor.spec_faultData.jumperTimeToChange = donor.spec_faultData.jumperTimeToChange + dt
				local jumperTimeToChange = donor.spec_faultData.jumperTimeToChange
				if math.abs(jumperTimeToChange) > 100 then
					donor.spec_faultData.jumperTimeToChange = 0
					conn.jumperTime = conn.jumperTime + jumperTimeToChange
					--donor:raiseDirtyFlags(donor.spec_faultData.jumperCableDirtyFlag)
				end
            end
        end
		end
        ------------------------------------------------------------------
        -- 3️ KÁBEL SZAKAD
        ------------------------------------------------------------------
        if receiver ~= nil then
            local distance = calcDistanceFrom(donor.rootNode, receiver.rootNode)

            if distance > JUMPERCABLE_LENGTH then

                local breaker = nil
                if donor.getVehicleSpeed(donor) > 0.5 then
                    breaker = donor
                elseif receiver.getVehicleSpeed(receiver) > 0.5 then
                    breaker = receiver
                end

                if breaker ~= nil then
                    breaker:setJumperCableConnection(
                        donor,
                        JUMPERCABLE_STATE.CABLE_BROKEN,
                        receiver,
                        0,
                        0,
						g_localPlayer.userId
                    )

					
					breaker:addBlinkingMessage("disconnecting_toofar", "RVB_blinking_disconnecting_toofar")



					-- kliensen nem frissül de ha történik egy másik pénz mozgás akkor jó lesz
                    --g_currentMission:addMoney(-100, donor:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
					

                    --table.insert(breaker.spec_faultData.uiJumperCableMessage, {
                    --    key   = "cableBroken", -- jelnleg nem is hasznalom
                    --    text  = "RVB_blinking_connecting_cableBroken",
                    --    value = 100
                    --})
					breaker:addJumperCableMessage("notification", "cableBroken", "RVB_blinking_connecting_cableBroken", 100)
                    --breaker:raiseDirtyFlags(breaker.spec_faultData.uiJumperCableMessageDirtyFlag)
					
					--if self.isServer and self.isClient then
					--	g_messageCenter:publish(
					--		MessageType.RVB_JUMPERCABLE_MESSAGE,
					--		breaker,
					--		"cableBroken", -- jelnleg nem is hasznalom
					--		"RVB_blinking_connecting_cableBroken",
					--		100
					--	)
					--end
                end
            end
        end
    end
end


function VehicleBreakdowns:onUpdateJumperCable(dt, isActiveForInputIgnoreSelection)

    local specFault  = self.spec_faultData
    local specJumper = self.spec_jumperCable

    if specFault == nil or not specFault.isrvbSpecEnabled then
        return
    end

    local conn = specJumper.connection
    if conn == nil then
        return
    end

    local donor    = conn.donor
    local receiver = conn.receiver

	if self.isClient then --and g_dedicatedServer == nil then
		if receiver ~= nil then
			if g_localPlayer:getCurrentVehicle() == self and (donor:getIsControlled() or receiver:getIsControlled()) then
				local distance = calcDistanceFrom(donor.rootNode, receiver.rootNode)
				if distance <= JUMPERCABLE_LENGTH then
					if self.getVehicleSpeed(donor) > 0.5 or self.getVehicleSpeed(receiver) > 0.5 then
						g_currentMission:showBlinkingWarning(
						string.format(g_i18n:getText("RVB_blinking_connecting_drive"), string.format("%.1f", distance)),
						100,
						getMD5(tostring("jumperCableInVehicle"))
					)
					end
				end
				if isActiveForInputIgnoreSelection then
					local jumperTime = conn.donor.spec_jumperCable.connection ~= nil and conn.donor.spec_jumperCable.connection.jumperTime or 0
					local jumperThreshold = conn.donor.spec_jumperCable.connection ~= nil and conn.donor.spec_jumperCable.connection.jumperThreshold or 0
					--g_currentMission:addExtraPrintText(string.format("donor %.1f / %.1f", jumperTime, jumperThreshold))
				end
			end
			if isActiveForInputIgnoreSelection and (donor.rootNode == self.rootNode or receiver.rootNode == self.rootNode) then
				g_currentMission:addExtraPrintText(g_i18n:getText("RVB_addextra_connecting"))
			end
		end
	end
end

function VehicleBreakdowns:canBeDonor()
	local spec = self.spec_jumperCable
	if spec == nil then
		return false, nil --"RVB_no_jumper_spec"
	end
	if spec.connection ~= nil then
		return false, nil --"RVB_already_donor"
	end
	if self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.MOTOR then
		return false, "RVB_blinking_connecting_order"
	end
	return true
end

function VehicleBreakdowns:setJumperCableConnection(donor, state, receiver, jumperTime, jumperThreshold, activePlayerUserId, noEventSend)
	local receiverName = receiver ~= nil and receiver:getFullName() or "nil"
    local msg = message ~= nil and message or "nil"
    --print("setJumperCableConnection " .. donor:getFullName() .. " state=" .. tostring(state) ..
    --      " receiver=" .. receiverName ..
    --      " jumperTime=" .. tostring(jumperTime) ..
    --      " jumperThreshold=" .. tostring(jumperThreshold) ..
	--	  " activePlayerUserId=" .. tostring(activePlayerUserId) ..
    --      " noEventSend=" .. tostring(noEventSend))
	
	local spec = self.spec_jumperCable

	local shouldWriteState = self.isServer or noEventSend == true
	
	local donorConn = nil
	if donor ~= nil then
		donorConn = donor.spec_jumperCable.connection
	end
	local finalThreshold = jumperThreshold
	if state == JUMPERCABLE_STATE.DONOR_SELECTED then
		if finalThreshold == nil or finalThreshold <= 0 then
			finalThreshold = math.random(5, 15) * 1000
		end
	elseif state == JUMPERCABLE_STATE.CONNECT then
		if donorConn ~= nil and (finalThreshold == nil or finalThreshold <= 0) then
			finalThreshold = donorConn.jumperThreshold
		end
	end

	if state == JUMPERCABLE_STATE.DONOR_SELECTED then
		local ok, reason = self:canBeDonor()
		if not ok then
			--if self.isClient and reason ~= nil then
			--	g_currentMission:showBlinkingWarning(string.format(g_i18n:getText(reason), self:getFullName()), 1500)
			--end
			return
		end
		if shouldWriteState then
			spec.connection = {
				donor = self,
				receiver = nil,
				jumperTime = 0,
				jumperThreshold = finalThreshold,
				activePlayerUserId = activePlayerUserId
			}
		end
		--if self.isClient then
		--	g_currentMission:showBlinkingWarning( string.format(g_i18n:getText(message), self:getFullName()), 1500)
		--end

	elseif state == JUMPERCABLE_STATE.CONNECT then
		if donor == nil or receiver == nil then return end
		
		if donorConn == nil or donorConn.receiver ~= nil then return end
		if shouldWriteState then
			local conn = {
				donor = donor,
				receiver = receiver,
				jumperTime = jumperTime or 0,
				jumperThreshold = finalThreshold,
				activePlayerUserId = activePlayerUserId
			}
			donor.spec_jumperCable.connection = conn
			receiver.spec_jumperCable.connection = conn
		end
		--if self.isClient then
		--	g_currentMission:showBlinkingWarning(string.format(g_i18n:getText(message), self:getFullName()), 1500)
		--end

	elseif state == JUMPERCABLE_STATE.DISCONNECT then
		if shouldWriteState then
			local conn = spec.connection
			if conn ~= nil and conn.donor == donor and conn.receiver == receiver then

				donor.spec_jumperCable.connection.receiver = nil
				receiver.spec_jumperCable.connection = nil

				-- fault reset
				local rvb = receiver.spec_faultData
				rvb.firstStart = true
				rvb.ignition = 0
				rvb.motorTries = 0
				rvb.faultType = 0
				rvb.engineStarts = false
				rvb.engineStartStop = false
			end
		end

		--if self.isClient then
		--	g_currentMission:showBlinkingWarning(string.format(g_i18n:getText(message), self:getFullName()), 1500)
		--end

	elseif state == JUMPERCABLE_STATE.DONOR_DISCONNECT then
		local conn = spec.connection
		if shouldWriteState then
			if conn ~= nil and conn.donor == donor and conn.receiver == nil then
				donor.spec_jumperCable.connection = nil
			end
		end
		--if self.isClient then
		--	if conn ~= nil and conn.receiver ~= nil then
		--		g_currentMission:showBlinkingWarning(g_i18n:getText("RVB_blinking_disconnecting_order"), 1500)
		--		return
		--	end
		--	if message ~= nil and message ~= "" then
		--		g_currentMission:showBlinkingWarning(string.format(g_i18n:getText(message), self:getFullName()), 1500)
		--	end
		--end

	elseif state == JUMPERCABLE_STATE.CABLE_BROKEN then
		if shouldWriteState then
			local conn = spec.connection
			if conn ~= nil then
				if conn.donor ~= nil then
					conn.donor.spec_jumperCable.connection = nil
				end
				if conn.receiver ~= nil then
					conn.receiver.spec_jumperCable.connection = nil
				end
				if self.isServer then
					--g_currentMission:addMoney(-100, self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
				end
			end
		end
		--if self.isClient and message ~= nil then
		--	g_currentMission:showBlinkingWarning(g_i18n:getText(message), 1500)
		--end
		

	end

	JumperCableEvent.sendEvent(self, donor, state, receiver, jumperTime, finalThreshold, activePlayerUserId, noEventSend)

end

function VehicleBreakdowns:ignitionMotor(dt)

	if not self.isServer then return end
	local spec = self.spec_faultData
	if spec == nil then return end
	local step = 100
	local minTime = 450 / step
	local maxTime = 800 / step
	local PRIORITY = {
		BATTERY = 1,
		SELFSTARTER = 2,
		GLOWPLUG = 3,
		JUMPER = 0.5
	}
	local function setIgnition(priority, ignitionValue, igMin, igMax)
		if spec.faultType == 0 or priority < spec.faultType then
			spec.faultType = priority
			spec.ignition = ignitionValue
			minTime = igMin
			maxTime = igMax
		end
	end

	local specJumper = self.spec_jumperCable
	local jumperReady = false
	if specJumper ~= nil and specJumper.connection ~= nil then
		local conn = specJumper.connection
		jumperReady = conn.jumperTime >= conn.jumperThreshold and conn.donor:getMotorState() == MotorState.ON
	end

	local batteryLevel = self:getBatteryFillLevelPercentage()
	local batteryLow = batteryLevel <= BATTERY_LEVEL.MOTOR

	if spec.prevBatteryLow == nil then
		spec.prevBatteryLow = batteryLow
	end
	if spec.prevBatteryLow and not batteryLow then
		spec.firstStart = true
	end
	if jumperReady then
		--spec.firstStart = true
	end
	spec.prevBatteryLow = batteryLow
	if spec.firstStart and self:getMotorState() == MotorState.OFF then
		spec.faultType = 0
		if jumperReady then
			local ignitionValue = math.random(0, 1)
			setIgnition(PRIORITY.JUMPER, ignitionValue, 3.5, 5.5)
		elseif batteryLow  then
			local ignitionValue = 3
			setIgnition(PRIORITY.BATTERY, ignitionValue, 3.5, 5.5)
		else
			if spec.faultType == PRIORITY.BATTERY then
				spec.faultType = 0
				spec.ignition = 0
				spec.firstStart = true
			end
		end
		if spec.parts[SELFSTARTER] and spec.parts[SELFSTARTER].prefault ~= "empty" then
			local ignitionValue = SelfStarterManager.rbv_startMotor(self) or 0
			setIgnition(PRIORITY.SELFSTARTER, ignitionValue, 3.5, 6)
		end
		if spec.parts[GLOWPLUG] and spec.parts[GLOWPLUG].prefault ~= "empty" then
			local ignitionValue = GlowPlugManager.rbv_startMotor(self) or 0
			setIgnition(PRIORITY.GLOWPLUG, ignitionValue, 4.5, 8)
		end
		spec.firstStart = false
	end
	if spec.ignition ~= 0 and
	(self:getMotorState() == MotorState.STARTING or self:getMotorState() == MotorState.ON)
	and (spec.motorTries or 0) < spec.ignition then

		self.playNeedsUpdateTimer = (self.playNeedsUpdateTimer or 0) + dt
		if spec.randomRestartTime == nil then
			spec.randomRestartTime = math.random(minTime, maxTime) * step
		end
		if self.playNeedsUpdateTimer >= spec.randomRestartTime then
			self.playNeedsUpdateTimer = 0 
			spec.randomRestartTime = nil
			self:stopMotor()
			self:startMotor()
			if spec.faultType == PRIORITY.SELFSTARTER or spec.faultType == PRIORITY.GLOWPLUG then
				GlowPlugManager.setVehicleDamage(self, dt)
			end
			spec.engineStarts = true
			spec.motorTries = spec.motorTries + 1
		end
	end

	if spec.engineStarts then
		if spec.motorTries >= spec.ignition then
			spec.engineStartStop = true
			spec.firstStart = true
			if spec.faultType == PRIORITY.BATTERY then
				self:stopMotor()
			end
		end
		spec.engineStarts = false
	end
end


function VehicleBreakdowns:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	
	local spec = self.spec_faultData
	
	if spec == nil or not spec.isrvbSpecEnabled then
        return
    end
	--print("onUpdate " .. dt)
	--self.dtUpdate = (self.dtUpdate or 0) + dt
	--if self.dtUpdate >= 1000 then 
	--	print("onUpdate " .. dt)
	--	self.dtUpdate = 0
	--end
	
	local RVBSET = g_currentMission.vehicleBreakdowns
	if next(spec.steeringWheels) == nil then
		--self:steeringWheels()
	end
	
	-- github #110
	if not g_gui:getIsGuiVisible() then
		--for _, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
			for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
				local spec = self.spec_faultData
				if spec ~= nil and spec.parts ~= nil then
					local part = spec.parts[key]
					if part and part.name ~= nil then
						local function isTyrePart(name)
							return name == TIREFL or name == TIREFR or name == TIRERL or name == TIRERR
						end
						local tireMultiplier = 1
						if isTyrePart(key) then
							if part.lifetimepercent ~= nil then
								part.lifetimepercent = nil
							end
						end
					end
				end
			end
		--end
	end		


	if g_modIsLoaded["FS25_useYourTyres"] then
		local maxLifetime = PartManager.getMaxPartLifetime(self, TIREFL)
		if FS25_useYourTyres.UseYourTyres.USED_MAX_M ~= maxLifetime then
			FS25_useYourTyres.UseYourTyres.USED_MAX_M = maxLifetime
		end
	end
	
	
	
	
	
	--print("getMotorState "..self:getMotorState())
	local motorState = self:getMotorState()
	-- remelem hogy maradhat így, ha nem torolni a feltetelt
	--if motorState == MotorState.STARTING then
	--	self:ignitionMotor(dt)
	--end
	


	--self:onStartOverheatingFailure(dt)
	
	-- motor teljesítmény csökkentés hibák alapján
	--self:updateEngineTorque(isActiveForInputIgnoreSelection)
	
	--self:updateEngineSpeedLimit(isActiveForInputIgnoreSelection)
	

	if self.isClient then
		if motorState ~= MotorState.OFF then
			self:updateExhaustEffect()
		end
	end

	-- TESZT
	if self.isClient and isActiveForInputIgnoreSelection and spec.parts[ENGINE].prefault ~= "empty" then
		--g_currentMission:addExtraPrintText("Elő hiba: "..spec.parts[ENGINE].prefault)
		--g_currentMission:addExtraPrintText("Hiba: "..spec.parts[ENGINE].fault)
	end
				
	-- TESZT
	if isActiveForInputIgnoreSelection then
		local motor = self:getMotor()
		--local rpm = self.spec_motorized.motor:getRPM()
		local rpm = motor:getEqualizedMotorRpm()
		local torque = motor:getTorqueCurveValue(rpm)
		local hp, kw = g_i18n:getPower(torque)
		--print(string.format("Name %s Aktuális motorerő: %.3f HP / %.3f KW torque: %.3f, rpm: %.3f", self:getFullName(), hp, kw, torque, rpm))
		
		
		
		--g_currentMission:addExtraPrintText(string.format("Motorterhelés: %d %%", spec.motorLoadPercent))

		local dirt = self.spec_washable and self.spec_washable:getDirtAmount() or 0
		--g_currentMission:addExtraPrintText("dirt: "..dirt)
		
		local specMotorized = self.spec_motorized
		--g_currentMission:addExtraPrintText("motorTemperature: "..specMotorized.motorTemperature.value)

	
	end



	
	-- onUpdate rész
	local isPlayerInRange = false
	if calcDistanceFrom(self.rootNode, g_localPlayer.rootNode) < 25 then
		--print("distance ".. self:getFullName().." "..calcDistanceFrom(self.rootNode, g_localPlayer.rootNode))
		isPlayerInRange = true
	else
		for _, enterable in pairs(g_currentMission.vehicleSystem.enterables) do
			if enterable.spec_enterable and enterable.spec_enterable.isControlled and calcDistanceFrom(self.rootNode, enterable.rootNode) < 25 then
				isPlayerInRange = true
				break
			end
		end
	end

	if isPlayerInRange and isActiveForInputIgnoreSelection then
		self:updateAxisSteer(dt)
	end
	
	
	if spec.parts[TIREFL].repairreq then
		--self.spec_drivable.lastInputValues.axisSteer = -0.04
    end


	self:onUpdateJumperCable(dt, isActiveForInputIgnoreSelection)


	--self:updateService(dt)

	--self:updateInspection(dt)

	--self:updateRepair(dt)



	--self:onBatteryDrain(dt)
	--BatteryManager.onBatteryDrain(self, dt)
	
	if motorState == MotorState.IGNITION then
		--print("IGNITION")
	end

	if motorState == MotorState.STARTING then -- or self:getMotorState() == MotorState.IGNITION then
		--self:updatePartsIgnitionBreakdowns(dt)
	end
			
	if self:getIsMotorStarted() then
	
	
		if isActiveForInputIgnoreSelection then
			local specMotorized = self.spec_motorized
			--g_currentMission:addExtraPrintText("enableTemperature: "..specMotorized.motorFan.enableTemperature)
			--g_currentMission:addExtraPrintText("disableTemperature: "..specMotorized.motorFan.disableTemperature)
		end
		


		
		--self:onStartOperatingHours(dt)

		--self:onStartChargeBattery(dt, isActiveForInputIgnoreSelection)

		--self:onStartWiperOperatingHours(dt)

		-- belül időzítve 1200
		--self:updatePartsBreakdowns(dt)
		
		--self:onStartDirtHeat(dt)

	else
		if self.isServer then
			if spec.batteryChargeAmount > 0 then
				spec.batteryChargeAmount = 0
				self:raiseDirtyFlags(spec.batteryChargeDirtyFlag)
			end
		end


	end

	
	--self:onStartLightingsOperatingHours(dt, isActiveForInputIgnoreSelection)
	
	if self.isClient and isActiveForInputIgnoreSelection then
		--g_currentMission:addExtraPrintText("LIGHTINGS: "..spec.parts[LIGHTINGS].operatingHours)
		--print("LIGHTINGS: "..spec.parts[LIGHTINGS].operatingHours)
	end


	local maxLifetime = PartManager.getMaxPartLifetime(self, ENGINE)
	local engine_percent = (spec.parts[ENGINE].operatingHours * 100) / maxLifetime
	if self:getIsFaultSelfStarter() or self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.MOTOR or engine_percent >= 99 then
		--print("Teljesul")
		if g_modIsLoaded["FS25_AutoDrive"] then
			if FS25_AutoDrive ~= nil then
				if self.ad.stateModule:isActive() then --print("FS25_AutoDrive stopAutoDrive")
					self:stopAutoDrive(self)
					--self:updateVehiclePhysics(0, 0, 0, 16)
					self:stopVehicle()
					FS25_AutoDrive.AutoDriveMessageEvent.sendNotification(self, FS25_AutoDrive.ADMessagesManager.messageTypes.INFO, g_i18n:getText("RVB_aimessage_batterydischarged"), 8000, self:getFullName())
				end
			end
		end
		
		if g_modIsLoaded["FS25_Courseplay"] then
			if FS25_Courseplay ~= nil then
				if self:getIsCpActive() then
					if self.getIsAIActive and self:getIsAIActive() then
						self:stopCurrentAIJob(AIMessageErrorBatteryDischarged.new())
						self:stopVehicle()
					end
				end
			end
		end

	end


	if self:getIsMotorStarted() then
		if self.isClient then
			local MotorSounds = self.spec_motorized.motorSamples
			local gearboxSounds = self.spec_motorized.gearboxSamples
			if not g_soundManager:getIsSamplePlaying(MotorSounds[1]) then
				g_soundManager:playSamples(MotorSounds)
			end
			if not g_soundManager:getIsSamplePlaying(gearboxSounds[1]) then
				g_soundManager:playSamples(gearboxSounds)
			end
			if not g_soundManager:getIsSamplePlaying(self.spec_motorized.samples.retarder) then
				g_soundManager:playSample(self.spec_motorized.samples.retarder)
			end
		end	
	end
	
	
	--if self:isLightingsRepairRequired() or self:getBatteryFillLevelPercentage() ~= nil and self:getBatteryFillLevelPercentage() ~= 0 then
	--	self:lightingsFault()
	--end
	
	if self.isServer then
		if self:isLightingsRepairRequired() or (self:getBatteryFillLevelPercentage() ~= nil and self:getBatteryFillLevelPercentage() ~= 0) then
			self:lightingsFault()
		end
	end


	
	local engine_percent = (spec.parts[ENGINE].operatingHours * 100) / maxLifetime
	if engine_percent >= 99 then
		--self:StopAI(self)
		if rvbAIJobVehicle ~= nil and rvbAIJobVehicle.StopAI ~= nil then
			rvbAIJobVehicle.StopAI(self)
		end
	end
	
	
	
		--if self.isServer and self.isClient then
	if self.isClient and spec.hasNewUIJumperCableMessage then
		if #spec.uiJumperCableMessage ~= 0 then
			for i = 1, #spec.uiJumperCableMessage do
				local msg = spec.uiJumperCableMessage[i]
				g_messageCenter:publish(MessageType.RVB_JUMPERCABLE_MESSAGE, self, msg.method, msg.key, msg.text, msg.value)
			end
			spec.uiJumperCableMessage = {}
			spec.hasNewUIJumperCableMessage = false
		end
	end

	if self.isClient and spec.hasNewUIBlinkingMessage then
		if #spec.uiBlinkingMessage ~= 0 then
			for i = 1, #spec.uiBlinkingMessage do
				local msg = spec.uiBlinkingMessage[i]
				g_messageCenter:publish(MessageType.RVB_BLINKINGMESSAGE, self, msg.key, msg.text)
			end
			spec.uiBlinkingMessage = {}
			spec.hasNewUIBlinkingMessage = false
		end
	end


end













function VehicleBreakdowns:updateAxisSteer(dt)
	local spec = self.spec_faultData
	
	if spec == nil then return end
	if self.spec_wheels == nil then return end

	local tireTypeCrawler = WheelsUtil.getTireType("crawler")

	local leftFlat, rightFlat = false, false

	if spec.steeringWheels and #spec.steeringWheels > 2 then return end
	
	for _, wheelIdx in ipairs(spec.steeringWheels) do
		local partName = WHEELTOPART[wheelIdx]
		local partData = spec.parts[partName]
		if partData == nil then 
			--print("ERROR RVB updateAxisSteer() " .. self:getFullName() .. " " .. tostring(spec.parts[partName]))
			return
		end
		if partData.fault and partData.fault ~= "empty" then
			local registry = FaultRegistry[partName]
			if registry and registry.variants then
				local variant = registry.variants[partData.fault]
				--print("Steering wheel", partName, "fault variant:", variant)
				if wheelIdx == 1 or wheelIdx == 3 then
					leftFlat = true
				elseif wheelIdx == 2 or wheelIdx == 4 then
					rightFlat = true
				end
				--print("leftFlat", tostring(leftFlat), "rightFlat:", tostring(rightFlat))
			end
		end
	end
	if self.getVehicleSpeed(self) > 2 then
		if leftFlat and not rightFlat then
			self.spec_drivable.lastInputValues.axisSteer = -0.04
		elseif rightFlat and not leftFlat then
			self.spec_drivable.lastInputValues.axisSteer = 0.04
		elseif leftFlat and rightFlat then
			self.spec_drivable.lastInputValues.axisSteer = self.spec_drivable.lastInputValues.axisSteer
		else
			self.spec_drivable.lastInputValues.axisSteer = 0
		end
	end

end




function VehicleBreakdowns:adjustSteeringAngle(wheel, angleAdjustment)
    local currentAngle = wheel.steeringAngle
    wheel.steeringAngle = currentAngle + angleAdjustment
    -- Kormányzási logika frissítése
	if self.isServer and self.isAddedToPhysics then
    setWheelShapeProps(wheel.node, wheel.wheelShape, 0, self:getBrakeForce()*wheel.brakeFactor, wheel.steeringAngle, wheel.rotationDamping)
	end
end


function VehicleBreakdowns:updatePartsIgnitionBreakdowns(dt)
    -- Időzítő beállítása a javítási igények frissítéséhez
    self.ignitionUpdateTimer = (self.ignitionUpdateTimer or 0) + dt

	local faultChanged = false
    if self.ignitionUpdateTimer >= RVB_DELAY.PARTS_BREAKDOWNS then
	--print("updatePartsIgnitionBreakdowns")
        self.ignitionUpdateTimer = 0 -- Időzítő visszaállítása
        local spec = self.spec_faultData
		for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
			if key ~= THERMOSTAT and key ~= LIGHTINGS and key ~= WIPERS and key ~= GENERATOR and key ~= ENGINE and key ~= BATTERY
			and key ~= TIREFL and key ~= TIREFR and key ~= TIRERL and key ~= TIRERR then
			local part = spec.parts[key]
			local faultData = FaultRegistry[key]
			if part and faultData then
				local maxLifetime = PartManager.getMaxPartLifetime(self, key)
				local partFoot = (part.operatingHours * 100) / maxLifetime
				local shouldBreak = false
				if part.prefault == "empty" then
					if not part.pre_random or part.pre_random == 0 then
						part.pre_random = math.random(1,5)
					end
					if faultData.strictBreak then
						shouldBreak = partFoot >= (faultData.breakThreshold - part.pre_random)
					else
						shouldBreak = partFoot > (faultData.breakThreshold - part.pre_random)
						--print(part.name.." partFoot "..partFoot.." > preTreshold "..(faultData.breakThreshold - part.pre_random).. "part.pre_random "..part.pre_random.." shouldBreak "..tostring(shouldBreak))
					end
					local criticalLevel
					if faultData.hud ~= nil and faultData.hud.temperatureBased then
						criticalLevel = partFoot >= faultData.hud.temp.critical
					else
						criticalLevel = partFoot >= faultData.hud.condition.critical
					end
					local thresholdPassed = faultData.threshold and faultData.threshold(self, part.pre_random, false) or false
					local needsNewpreFault = part.prefault == nil or part.prefault == "empty"
					if part.name == "ENGINE" then
					--print(part.name.." shouldBreak "..tostring(shouldBreak))
					--print(part.name.." thresholdPassed "..tostring(thresholdPassed))
					--print(part.name.." needsNewpreFault "..tostring(needsNewpreFault))
					--print(part.name.." criticalLevel "..tostring(criticalLevel))
					end
					if shouldBreak and (thresholdPassed or criticalLevel) and needsNewpreFault then
						--print(part.name.." bejutottam")
						local valid = getValidFaultVariants(self, key, false)
						if valid then
							part.prefault = valid
							faultChanged = true 
							--print("Előhiba dobva: "..part.name.." prefault="..tostring(part.prefault).." fault="..tostring(part.fault))
						end
					end
				else
					part.pre_random = 0
					local needsNewFault = part.fault == nil or part.fault == "empty"
					local thresholdPassed = faultData.threshold and faultData.threshold(self, 0, false) or false
					if faultData.strictBreak then
						shouldBreak = partFoot >= faultData.breakThreshold
					else
						shouldBreak = partFoot > faultData.breakThreshold
					end
				--	print(part.name.." else partFoot "..partFoot.." > breakThreshold "..faultData.breakThreshold.. "part.pre_random "..part.pre_random.." shouldBreak "..tostring(shouldBreak))
					local criticalLevel
					if faultData.hud.temperatureBased then
						criticalLevel = partFoot >= faultData.hud.temp.critical
					else
						criticalLevel = partFoot >= faultData.hud.condition.critical
					end
					if shouldBreak and (thresholdPassed or criticalLevel) and needsNewFault then
						part.fault = part.prefault
						faultChanged = true  
						spec.faultList[i] = true
						part.repairreq = true
						--print("Hiba dobva: "..part.name.." prefault="..tostring(part.prefault).." fault="..tostring(part.fault))
					end
				end
			end
		end	
		end
        if faultChanged then
			if self.isServer then
				self:raiseDirtyFlags(spec.partsDirtyFlag)
			end
		end
    end
	self:raiseActive()
end

function VehicleBreakdowns:updatePartsBreakdowns(dt)
    -- Időzítő beállítása a javítási igények frissítéséhez
    self.repairNeedsUpdateTimer = (self.repairNeedsUpdateTimer or 0) + dt

	local faultChanged = false
    if self.repairNeedsUpdateTimer >= RVB_DELAY.PARTS_BREAKDOWNS then
        self.repairNeedsUpdateTimer = 0 -- Időzítő visszaállítása
        local spec = self.spec_faultData
		for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
			if key ~= GLOWPLUG and key ~= SELFSTARTER then
			local part = spec.parts[key]
			local faultData = FaultRegistry[key]
			if part and faultData then
				local maxLifetime = PartManager.getMaxPartLifetime(self, key)
				local partFoot = (part.operatingHours * 100) / maxLifetime
				local shouldBreak = false
				if part.prefault == "empty" then
					if not part.pre_random or part.pre_random == 0 then
						part.pre_random = math.random(3,9)
					end
					if faultData.strictBreak then
						shouldBreak = partFoot >= (faultData.breakThreshold - part.pre_random)
					else
						shouldBreak = partFoot > (faultData.breakThreshold - part.pre_random)
						--print(part.name.." partFoot "..partFoot.." > preTreshold "..(faultData.breakThreshold - part.pre_random).. "part.pre_random "..part.pre_random.." shouldBreak "..tostring(shouldBreak))
					end
					local criticalLevel
					if faultData.hud ~= nil and faultData.hud.temperatureBased then
						criticalLevel = partFoot >= faultData.hud.temp.critical
					else
						criticalLevel = partFoot >= faultData.hud.condition.critical
					end
					local thresholdPassed = faultData.threshold and faultData.threshold(self, part.pre_random, false) or false
					local needsNewpreFault = part.prefault == nil or part.prefault == "empty"
					if part.name == "ENGINE" then
					--print(part.name.." shouldBreak "..tostring(shouldBreak))
					--print(part.name.." thresholdPassed "..tostring(thresholdPassed))
					--print(part.name.." needsNewpreFault "..tostring(needsNewpreFault))
					--print(part.name.." criticalLevel "..tostring(criticalLevel))

						spec.partFaultDebugHud.isBreakConditionMet=shouldBreak
						spec.partFaultDebugHud.thresholdTriggered=thresholdPassed
						spec.partFaultDebugHud.needsNewPreFault=needsNewpreFault
						spec.partFaultDebugHud.isCritical=criticalLevel
						local preFaultStartPercent = faultData.breakThreshold - part.pre_random
						spec.partFaultDebugHud.preFaultStartPercent=preFaultStartPercent
						spec.partFaultDebugHud.breakThresholdPercent=faultData.breakThreshold
						spec.partFaultDebugHud.randomOffset=part.pre_random
					
					end
					if shouldBreak and (thresholdPassed or criticalLevel) and needsNewpreFault then
						--print(part.name.." bejutottam")
						local valid = getValidFaultVariants(self, key, false)
						if valid then
							part.prefault = valid
							faultChanged = true 
							--print("Előhiba dobva: "..part.name.." prefault="..tostring(part.prefault).." fault="..tostring(part.fault))
							spec.partFaultDebugHud.currentPreFault=part.prefault
						end
					end
				else
					part.pre_random = 0
					local needsNewFault = part.fault == nil or part.fault == "empty"
					local thresholdPassed = faultData.threshold and faultData.threshold(self, 0, false) or false
					if faultData.strictBreak then
						shouldBreak = partFoot >= faultData.breakThreshold
					else
						shouldBreak = partFoot > faultData.breakThreshold
					end
				--	print(part.name.." else partFoot "..partFoot.." > breakThreshold "..faultData.breakThreshold.. "part.pre_random "..part.pre_random.." shouldBreak "..tostring(shouldBreak))
					local criticalLevel
					if faultData.hud.temperatureBased then
						criticalLevel = partFoot >= faultData.hud.temp.critical
					else
						criticalLevel = partFoot >= faultData.hud.condition.critical
					end
					if shouldBreak and (thresholdPassed or criticalLevel) and needsNewFault then
						part.fault = part.prefault
						faultChanged = true  
						spec.faultList[i] = true
						part.repairreq = true
						--print("Hiba dobva: "..part.name.." prefault="..tostring(part.prefault).." fault="..tostring(part.fault))
					end
				end
			end
		end	
		end
        if faultChanged then
			if self.isServer then
				self:raiseDirtyFlags(spec.partsDirtyFlag)
			end
		end
    end
	self:raiseActive()
end
function VehicleBreakdowns:updatePartsNoBreakdowns(dt)
    self.PartsNeedsUpdateTimer = (self.PartsNeedsUpdateTimer or 0) + dt
    if self.PartsNeedsUpdateTimer >= RVB_DELAY.PARTS_noBREAKDOWNS then
        self.PartsNeedsUpdateTimer = 0
        local spec = self.spec_faultData
		--- Ha van jaitas ne fusson le, mert a javitas nem fejezodik be soha
		if spec.repair.state == REPAIR_STATE.ACTIVE then return end
		local isSend = false
        for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
            local part = spec.parts[key]
            local faultData = FaultRegistry[key]
			if part and faultData then
				local maxLifetime = PartManager.getMaxPartLifetime(self, key)
                local partFoot = (part.operatingHours * 100) / maxLifetime
                local threshold = faultData.breakThreshold or 100
                local shouldBreak = false
				if faultData.strictBreak then
					shouldBreak = partFoot <= faultData.breakThreshold
				else
					shouldBreak = partFoot < faultData.breakThreshold
				end
				if shouldBreak and part.repairreq then
                    spec.faultList[i] = false
                    part.repairreq = false
                    --part.damaged = false
                    part.fault = "empty"
					isSend = true
                end
			end
		end
        --RVBParts_Event.sendEvent(self, spec.parts)
		if isSend then
			isSend = false
			--print("VehicleBreakdowns:updatePartsNoBreakdowns isSend")
			self:raiseDirtyFlags(spec.partsDirtyFlag)
		end
    end
end


function VehicleBreakdowns:getIsRVBMotorStarted(isRunning)
    return self.spec_faultData.isRVBMotorStarted and (not isRunning or self.spec_faultData.rvbmotorStartTime < g_currentMission.time)
end





function VehicleBreakdowns:onDelete()
    local spec = self.spec_faultData

	g_messageCenter:unsubscribe(MessageType.MINUTE_CHANGED, self)
	g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
	g_messageCenter:unsubscribe(MessageType.SET_PARTS_LIFETIME, self)
	g_messageCenter:unsubscribe(MessageType.SET_DIFFICULTY, self)
	g_messageCenter:unsubscribe(MessageType.SET_DAYSPERPERIOD, self)
	--g_messageCenter:unsubscribe(MessageType.RVB_START_REPAIR, self)
	--g_messageCenter:unsubscribe(MessageType.RVB_START_SERVICE, self)
	--g_messageCenter:unsubscribe(MessageType.RVB_START_INSPECTION, self)
	--g_messageCenter:unsubscribe(MessageType.RVB_END_INSPECTION, self)
	g_messageCenter:unsubscribe(MessageType.RVB_PROGRESS_MESSAGE, self)
	g_messageCenter:unsubscribe(MessageType.RVB_JUMPERCABLE_MESSAGE, self)
	--g_messageCenter:unsubscribe(MessageType.RVB_JUMPERCABLE_BLINKINGMESSAGE, self)
	g_messageCenter:unsubscribe(MessageType.RVB_BLINKINGMESSAGE, self)
	g_messageCenter:unsubscribe(MessageType.MONEY_CHANGED, self)
	

end



function VehicleBreakdowns:DebugFaultPrint(spec)
    local faultMessages = {}
    for faultIndex, isActive in pairs(spec.faultList) do
        if isActive and g_vehicleBreakdownsPartKeys[faultIndex] then
			table.insert(faultMessages, g_i18n:getText("RVB_faultText_"..g_vehicleBreakdownsPartKeys[faultIndex]))
        end
    end
    if #faultMessages > 0 then
        local NotifiText = g_i18n:getText("RVB_ErrorNotifi") .. table.concat(faultMessages, ", ")
        g_currentMission:addGameNotification(
            g_i18n:getText("input_RVB_MENU"),
            NotifiText,
            "",
            nil, --"dataS/menu/vignette.dds",
            4000
        )
    end
    for faultIndex, _ in pairs(spec.faultList) do
        spec.faultList[faultIndex] = nil
    end
end

    

function VehicleBreakdowns:onEnterVehicle()
	local spec = self.spec_faultData
	if spec == nil or not spec.isrvbSpecEnabled then
		return
	end
	--print("onEnterVehicle")
	local specJumper = self.spec_jumperCable
	local jumperReady = false
	if specJumper ~= nil and specJumper.connection ~= nil then
		local conn = specJumper.connection
		--print("conn.donor " .. (conn.donor ~= nil and conn.donor:getFullName() or "nil"))
		--print("conn.receiver " .. (conn.receiver ~= nil and conn.receiver:getFullName() or "nil"))
		--print("conn.jumperTime "..conn.jumperTime)
		--print("conn.jumperThreshold "..conn.jumperThreshold)

		-- Ha donorban vagy receiver ülök showBlinkingWarning megjelenítése
		if self.isClient and g_localPlayer:getCurrentVehicle() == self and self:getIsControlled() then
			if conn.donor ~= nil and conn.donor.rootNode == self.rootNode
			or conn.receiver ~= nil and conn.receiver.rootNode == self.rootNode then
				g_currentMission:showBlinkingWarning(g_i18n:getText("RVB_addextra_connecting"), 1500)
			end
		end
	
	end

	

	local RVB = g_currentMission.vehicleBreakdowns

	--print("getWorkshopCountMax ".. RVB:getWorkshopCountMax())
	--print("workshopCount ".. RVB.workshopCount)
	
	local RVBSET = g_currentMission.vehicleBreakdowns
	local showOnHud = RVBSET:getIsAlertMessage()
	local showOnInfoHud = RVBSET:getIsAlertMessage()
	local batteryFillUnitIndex = self:getConsumerFillUnitIndex(FillType.BATTERYCHARGE)
	--self.spec_fillUnit.fillUnits[batteryFillUnitIndex].showOnHud = showOnHud
	--self.spec_fillUnit.fillUnits[batteryFillUnitIndex].showOnInfoHud = showOnInfoHud
		
	if self.isServer then 
		--spec.rvb[1] = spec.rvb[1] + 1
	--RVBTotal_Event.sendEvent(self, spec.rvb)
	end
	-- for _, wheel in pairs(self:getWheels()) do
	--local v65, v66, v67, v68, v69, v70 = wheel.physics:getVisualInfo()
		--						print("v65 "..v65)
	--							print("v66 "..v66)
		--						print("v67 "..v67)
		--						print("v68 "..v68)
		--						print("v69 "..v69)
		--						print("v70 "..v70)

--end

	
	--[[
	WheelManager.BRAND_TO_SORT_INDEX.TRELLEBORG = 1
	WheelManager.BRAND_TO_SORT_INDEX.MICHELIN = 2
	WheelManager.BRAND_TO_SORT_INDEX.CONTINENTAL = 3
	WheelManager.BRAND_TO_SORT_INDEX.MITAS = 4
	WheelManager.BRAND_TO_SORT_INDEX.BKT = 5
	WheelManager.BRAND_TO_SORT_INDEX.VREDESTEIN = 6
	WheelManager.BRAND_TO_SORT_INDEX.NOKIAN = 7
	]]


	-- BROAD_MICHELIN_ széles
	-- NARROW_MICHELIN_ keskeny
	-- DEFAULT_TRELLEBORG normal

	local function getWheelBrand(vehicle)
		local specWheels = vehicle.spec_wheels
		if not specWheels then
			return "UNKNOWN"
		end
		local id = specWheels.lastWheelConfigSaveId
		if type(id) ~= "string" then
			return "UNKNOWN"
		end
		-- ismert márkák
		local KNOWN_BRANDS = {
			TRELLEBORG = true,
			MICHELIN = true,
			CONTINENTAL = true,
			MITAS = true,
			BKT = true,
			VREDESTEIN = true,
			NOKIAN = true,
			LIZARD = true
		}
		-- 1️ tokenizáljuk az ID-t (_ szerint)
		for token in id:gmatch("[^_]+") do
			if KNOWN_BRANDS[token] then
				return token
			end
		end
		-- 2) fallback: bárhol (mod kompatibilitás)
		for brand, _ in pairs(KNOWN_BRANDS) do
			if id:find(brand, 1, true) then
				return brand
			end
		end
		return "UNKNOWN"
	end
	local specWheels = self.spec_wheels
--	print(specWheels.lastWheelConfigSaveId)
--	print(getWheelBrand(self))
	
	
	local function getWheelType(id)
		if type(id) ~= "string" then
			return "DEFAULT"
		end
		for token in id:gmatch("[^_]+") do
			if token == "BROAD" or token == "BROADS" then
				return "BROAD"
			end
			if token == "NARROW" or token == "NARROWS" then
				return "NARROW"
			end
		end
		return "DEFAULT"
	end
	local id = specWheels.lastWheelConfigSaveId
--  print(getWheelType(id))
	
	



end




function VehicleBreakdowns:onLeaveVehicle()
	local spec = self.spec_faultData
	if spec == nil or not spec.isrvbSpecEnabled then
		return
	end

	if self.isClient and not self.isServer then
		self.rvb_addextra_connecting = false
	end
end

function VehicleBreakdowns:mouseEvent(posX, posY, isDown, isUp, button)
end

function VehicleBreakdowns:keyEvent(unicode, sym, modifier, isDown)
end




function VehicleBreakdowns:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_motorized
	local rvb = self.spec_faultData

	if rvb and not rvb.isrvbSpecEnabled then
		return
	end
	
	--self.dtUpdateTick = (self.dtUpdateTick or 0) + dt
	--if self.dtUpdateTick >= 1000 then 
	--	print("onUpdateTick " .. dt)
	--	self.dtUpdateTick = 0
	--end
	
	--print("onUpdateTick " .. dt)
	
	self:onUpdateTickJumperCable(dt, isActiveForInputIgnoreSelection)
	
	if self.isServer then

		self:ignitionMotor(dt)
		
		self:updateService(dt)
		
		self:updateInspection(dt)

		self:updateRepair(dt)
		
		BatteryManager.onBatteryDrain(self, dt)
		
		self:onStartLightingsOperatingHours(dt, isActiveForInputIgnoreSelection)
		

		local motorState = self:getMotorState()
		
		if motorState == MotorState.STARTING then -- or self:getMotorState() == MotorState.IGNITION then
			self:updatePartsIgnitionBreakdowns(dt)
		end

		if motorState == MotorState.ON then
		
			if rvb.batterySelfDischarge then rvb.batterySelfDischarge = false end
		
			self:updateEngineTorque(isActiveForInput)
			self:updateEngineSpeedLimit(isActiveForInput)
			self:onStartOverheatingFailure(dt)
			
			self:onStartOperatingHours(dt)

			self:onStartChargeBattery(dt, isActiveForInputIgnoreSelection)

			self:onStartWiperOperatingHours(dt)

			self:updatePartsBreakdowns(dt)
		
			self:onStartDirtHeat(dt)

			rvb.smoothedLoadUpdateTimer = rvb.smoothedLoadUpdateTimer + dt
			if rvb.smoothedLoadUpdateTimer >= RVB_DELAY.MOTORLOAD then
				rvb.smoothedLoadUpdateTimer = 0
				local motorload = self:getMotorLoadPercentage()
				if motorload ~= nil then
					motorload = math.max(0, motorload)
					rvb.motorLoadPercent = math.floor(motorload * 100 + 0.5)
					self:raiseDirtyFlags(rvb.motorLoadDirtyFlag)
				end
			end
		end

		if motorState == MotorState.OFF then

			--if self.spec_motorized.motorTemperature.value > self.currentTemperaturDay then
				self:updateEngineCooling(dt)

				--rvb.motorTempSyncTimer = (rvb.motorTempSyncTimer or 0) + dt
				-- rvb.motorTempSyncTimer >= 1000 and 
				if self.spec_motorized.motorTemperature.value ~= self.spec_motorized.motorTemperature.valueSend then
					--rvb.motorTempSyncTimer = 0
					self.spec_motorized.motorTemperature.valueSend = self.spec_motorized.motorTemperature.value
					self:raiseDirtyFlags(rvb.motorTemperatureDirtyFlag)
				end
			if self.spec_motorized.motorTemperature.value > self.currentTemperaturDay then
				--local ambientTemp = g_currentMission.environment.weather:getCurrentTemperature()
				self:raiseActive()
			end

		end

	end
	


	VehicleBreakdowns.updateActionEvents(self)
	
	
	-- sync engine data with server
	if not g_modIsLoaded["FS25_gameplay_RoadMaster"] then 
		rvb.updateTimer = rvb.updateTimer + dt
		if self.isServer and self.getIsMotorStarted ~= nil and self:getIsMotorStarted() then
			rvb.motorTemperature = spec.motorTemperature.value
			rvb.fanEnabled = spec.motorFan.enabled
			rvb.lastFuelUsage = spec.lastFuelUsage
			rvb.lastDefUsage = spec.lastDefUsage
			rvb.lastAirUsage = spec.lastAirUsage
			rvb.fanEnableTemperature = spec.motorFan.enableTemperature
			rvb.fanDisableTemperature = spec.motorFan.disableTemperature
			if rvb.updateTimer >= 1000 and rvb.motorTemperature ~= self.spec_motorized.motorTemperature.valueSend then
			--if rvb.updateTimer >= 1000 and spec.motorTemperature.value ~= self.spec_motorized.motorTemperature.valueSend then
				self:raiseDirtyFlags(rvb.motorizedDirtyFlag)
			end
			if rvb.fanEnabled ~= rvb.fanEnabledLast then
				rvb.fanEnabledLast = rvb.fanEnabled
				self:raiseDirtyFlags(rvb.motorizedDirtyFlag)
			end
		end
		if self.isClient and not self.isServer and self.getIsMotorStarted ~= nil and self:getIsMotorStarted() then
			spec.motorTemperature.value = rvb.motorTemperature
			spec.motorFan.enabled = rvb.fanEnabled
			spec.lastFuelUsage = rvb.lastFuelUsage
			spec.lastDefUsage = rvb.lastDefUsage
			spec.lastAirUsage = rvb.lastAirUsage
			spec.motorFan.enableTemperature = rvb.fanEnableTemperature
			spec.motorFan.disableTemperature = rvb.fanDisableTemperature
		end
	end
	-- sync end

	local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
	--rvb.batteryFillUnitIndex
	rvb.updateBatteryTimer = rvb.updateBatteryTimer + dt
	if self.isServer then
		rvb.RVB_BatteryFillLevel = self.spec_fillUnit.fillUnits[batteryFillUnitIndex].fillLevel
		if rvb.updateBatteryTimer >= 1000 then
			self:raiseDirtyFlags(rvb.dirtyFlag)
			rvb.updateBatteryTimer = 0
		end
	end
	if self.isClient and not self.isServer then
		if self.spec_fillUnit.fillUnits[batteryFillUnitIndex] == nil then
			print("RVB ERROR: batteryFillUnitIndex is NIL for vehicle: "..tostring(self:getFullName()))
		end
		self.spec_fillUnit.fillUnits[batteryFillUnitIndex].fillLevel = rvb.RVB_BatteryFillLevel
		self.spec_fillUnit.fillUnits[batteryFillUnitIndex].fillType = FillType.BATTERYCHARGE
		--self:raiseDirtyFlags(self.spec_fillUnit.dirtyFlag)
	end
	
	--[[if self.isClient and spec.hasNewUIProgressMessage then
		for i = 1, #spec.uiProgressMessage do
			local msg = spec.uiProgressMessage[i]
			g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, self, msg.key, msg.text)
		end
		spec.uiProgressMessage = {}
		spec.hasNewUIProgressMessage = false
	end]]
	



end




function VehicleBreakdowns:getIsFaultBattery_OLD()
	local batteryFillUnitIndex = self:getConsumerFillUnitIndex(FillType.BATTERYCHARGE)
	local dieselFillUnitIndex = self:getConsumerFillUnitIndex(FillType.DIESEL)
	
	if batteryFillUnitIndex ~= nil and dieselFillUnitIndex ~= nil then
		return tonumber(self:getFillUnitFillLevelPercentage(batteryFillUnitIndex)) or 1
	end
	return 1
end




function VehicleBreakdowns:getPartsPercentage(part)
	local spec = self.spec_faultData
	local maxLifetime = PartManager.getMaxPartLifetime(self, part)
	return (spec.parts[part].operatingHours * 100) / maxLifetime
end
function VehicleBreakdowns:getFaultParts(part)
	local spec = self.spec_faultData
	return spec.parts[part].repairreq
end
	
function VehicleBreakdowns:getIsFaultOperatingHours()
	local spec = self.spec_faultData
	return spec.operatingHours
end



function VehicleBreakdowns:getIsDailyService()
	local spec = self.spec_faultData
	return spec.service[2]
end

function VehicleBreakdowns:getIsPeriodicServiceTime()
	local spec = self.spec_faultData
	return spec.service[3]
end

function VehicleBreakdowns:setIsPeriodicServiceTime(servicetime)
	local spec = self.spec_faultData
	spec.service[3] = servicetime
end

function VehicleBreakdowns:getIsRepairStartService()
	local spec = self.spec_faultData
	return spec.vehicleService[3]
end

function VehicleBreakdowns:getIsRepairClockService()
	local spec = self.spec_faultData
	return spec.vehicleService[4]
end

function VehicleBreakdowns:getIsRepairTimeService()
	local spec = self.spec_faultData
	return spec.vehicleService[5]
end

function VehicleBreakdowns:getIsRepairTimePassedService()
	local spec = self.spec_faultData
	return spec.vehicleService[6]
end

function VehicleBreakdowns:getIsRepairScaleService()
	local spec = self.spec_faultData
	return spec.vehicleService[7]
end

function VehicleBreakdowns:setPartsRepairreq(part, state)
	local spec = self.spec_faultData
	spec.parts[part].repairreq = state
	--g_client:getServerConnection():sendEvent(BatteryFillUnitFillLevelEvent.new(self.vehicle, true))
	RVBParts_Event.sendEvent(self, spec.parts)
end


function VehicleBreakdowns:getSellPrice_RVBClone()
    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    return VehicleBreakdowns.calculateSellPriceClone(storeItem, self.age, self.operatingTime, self:getPrice(), self:getRepairPrice(), self:getRepairPrice_RVBClone(), self:getRepaintPrice())
end
function VehicleBreakdowns.calculateSellPriceClone(storeItem, age, operatingTime, price, repairPrice, repairPriceRVBClone, repaintPrice)
	local operatingTimeHours = operatingTime / 3600000
	local maxVehicleAge = storeItem.lifetime
	local ageInYears = age / Environment.PERIODS_IN_YEAR
	StoreItemUtil.loadSpecsFromXML(storeItem)
	local operatingTimeFactor = 1 - operatingTimeHours ^ (storeItem.specs.power == nil and 1.3 or 1) / maxVehicleAge
	local ageFactor = -0.1 * math.log(ageInYears) + 0.75
	local v476 = math.min(ageFactor, 0.85)
	local v477 = price * operatingTimeFactor * v476 - repairPrice - repairPriceRVBClone - repaintPrice
	local v478 = price * 0.03
	return math.max(v477, v478)
end


function VehicleBreakdowns:calculateCost(costType)
	local ageInYears = self.age / Environment.PERIODS_IN_YEAR
	local ageFactor = 1
	if costType == "repair" then
		if ageInYears < 2 then
			ageFactor = 0.95 + 0.02 * ageInYears
		elseif ageInYears <= 20 then
			ageFactor = 1 + 0.03 * ageInYears
		else
			ageFactor = math.min(1.6 + 0.05 * (ageInYears - 20), 2.2)
		end
		local rvb = self.spec_faultData
		local faultListCosts, laborCosts = 0, 0
		local baseLaborFee, hourlyRate = 100, 50
		for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = rvb.parts[key]
			if part and part.repairreq then
				-- github issues#111
				--local partCost = (i >= 9 and i <= 12) and 0.03 or REPAIR_COSTS[i]
				local conParts = FaultRegistry[key]
				local partCost = conParts.cost or 111
				faultListCosts = faultListCosts + partCost
				local repairTimeSec = conParts.repairTime or 3600
				laborCosts = laborCosts + (repairTimeSec / 3600) * hourlyRate
			end
		end
		local total = (self:getPrice() * ageFactor * faultListCosts) + laborCosts + baseLaborFee
		return total
	elseif costType == "inspection" then
		if ageInYears < 2 then
			ageFactor = 0.9 + 0.05 * ageInYears
		elseif ageInYears <= 20 then
			ageFactor = 1 + 0.05 * ageInYears
		else
			ageFactor = math.min(2 + 0.05 * (ageInYears - 20), 3)
		end
		--return self:getPrice() * ageFactor * REPAIR_COSTS[10]
		-- github issues#111
		--local total = self:getPrice() * ageFactor * REPAIR_COSTS[10]
		local total = self:getPrice() * ageFactor * INSPECTION.COST
		return total
	elseif costType == "service" then
		if ageInYears < 2 then
			ageFactor = 0.9 + 0.05 * ageInYears
		elseif ageInYears <= 20 then
			ageFactor = 1 + 0.05 * ageInYears
		else
			ageFactor = math.min(2 + 0.05 * (ageInYears - 20), 3)
		end
		local specRVB = self.spec_faultData
		local baseLaborFee, hourlyRate = 75, 50
		-- github issues#111
		--local materialCost = self:getPrice() * ageFactor * REPAIR_COSTS[9]
		local materialCost = self:getPrice() * ageFactor * SERVICE.COST
		local baseserviceTime = 10800
		local periodicService = g_currentMission.vehicleBreakdowns:getPeriodicService()
		local hoursOverdue = math.max(0, math.floor(specRVB.operatingHours) - periodicService)
		local additionalTime = hoursOverdue * SERVICE.TIME
		local totalServiceTime = baseserviceTime + additionalTime
		local laborCosts = (totalServiceTime / 3600) * hourlyRate
		local total = materialCost + laborCosts + baseLaborFee
		return total
	end
	return 0
end

function VehicleBreakdowns:getRepairPrice_RVBClone()
	return self:calculateCost("repair")
end
function VehicleBreakdowns:getServicePrice()
	return self:calculateCost("service")
end
function VehicleBreakdowns:getInspectionPrice()
	return self:calculateCost("inspection")
end


function VehicleBreakdowns:RVBresetVehicle(vehicle)

	if vehicle ~= self then
        return
    end
	if self.isServer then
		--g_currentMission:addMoney(-self:getRepaintPrice(), self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
		local rvb = self.spec_faultData
		--rvb.battery = { false, false, 0, 0, 0, 0, 0 }
		
		rvb.isrvbSpecEnabled = true
		rvb.totaloperatingHours = 0
		rvb.operatingHours = 0
		rvb.dirtHeatOperatingHours = 0
		self:raiseDirtyFlags(rvb.rvbdirtyFlag)

		rvb.service = {
			state = SERVICE_STATE.NONE,
			finishDay = 0,
			finishHour = 0,
			finishMinute = 0,
			cost = 0
		}
		RVBService_Event.sendEvent(self, rvb.service, {result=false,cost=0,text=""})
		rvb.inspection = {
			state = INSPECTION_STATE.NONE,
			finishDay = 0,
			finishHour = 0,
			finishMinute = 0,
			cost = 0,
			factor = 0,
			completed = false
		}
		RVBInspection_Event.sendEvent(self, rvb.inspection, {result=false,cost=0,text=""})
		rvb.repair = {
			state = REPAIR_STATE.NONE,
			finishDay = 0,
			finishHour = 0,
			finishMinute = 0,
			cost = 0
		}
		RVBRepair_Event.sendEvent(self, rvb.repair, {result=false,cost=0,text=""})
		
		for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = rvb.parts[key]
			if part then
				part.operatingHours = 0.000000
				part.repairreq = false
				part.prefault = "empty"
				part.fault = "empty"
				part.pre_random = nil
			end
		end
		print("RVBresetVehicle " .. self:getFullName())
		
		local CurEnvironment = g_currentMission.environment
		--local manualDesc = g_i18n:getText("RVB_WorkshopMessage_vResetDone")
		local entry = {
			entryType = RESET.SERVICE_MANUAL,
			entryTime = CurEnvironment.currentDay,
			operatingHours = rvb.totaloperatingHours,
			odometer = 0,
			--result = manualDesc,
			resultKey = "RVB_WorkshopMessage_vResetDone",
			errorList = "",
			cost = 25
		}
		RVBserviceManual_Event.sendEvent(self, entry)
	
		RVBParts_Event.sendEvent(self, rvb.parts)
		
		local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
		--rvb.batteryFillUnitIndex
		self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, 100, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)

		local RVB = g_currentMission.vehicleBreakdowns

		--table.remove(RVB.workshopVehicles, self)
		if RVB.workshopVehicles[self] then
			RVB.workshopVehicles[self] = nil
			RVB.workshopCount = RVB.workshopCount - 1
			WorkshopCount_Event.sendEvent(RVB.workshopCount)
		end


		if g_modIsLoaded["FS25_useYourTyres"] then
			if self.spec_wheels ~= nil then
			for wheelIdx, wheel in ipairs(self.spec_wheels.wheels) do
				local partName = WHEELTOPART[wheelIdx]
				if partName == nil then return end
				local part = rvb.parts[partName]
				if not part then return end
				wheel.uytTravelledDist = part.operatingHours
			end
			end
			WheelPhysics.updateContact = Utils.appendedFunction(WheelPhysics.updateContact, VehicleBreakdowns.injPhysWheelUpdateContact)
		end
		
		self:openHoodForWorkshop(false)
		
		--local v102 = self.spec_wearable
		--for _, v103 in ipairs(v102.wearableNodes) do
		--	self:setNodeWearAmount(v103, 0, true)
		--end
--		self:raiseDirtyFlags(rvb.dirtyFlag)
		--local v104, _ = g_farmManager:updateFarmStats(self:getOwnerFarmId(), "repaintVehicleCount", 1)
		--if v104 ~= nil then
		--	g_achievementManager:tryUnlock("VehicleRepaint", v104)
		--end
	end
end



--[[
local InGameMenuMapFrame_onYesNoReset_Orig = InGameMenuMapFrame.onYesNoReset
function InGameMenuMapFrame:onYesNoReset(yes)
    if yes then
        if self.currentHotspot ~= nil then
            local v492_ = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
            if v492_ ~= nil then

                print("RVB DEBUG: Reset started for " .. v492_:getFullName())
                g_messageCenter:publish(MessageType.RVB_VEHICLE_RESET, v492_)
                
                -- eredeti kód
                self:setMapSelectionItem(nil)
                g_messageCenter:subscribe(ResetVehicleEvent, self.onVehicleReset, self)
                self.isResetPending = true
                g_client:getServerConnection():sendEvent(ResetVehicleEvent.new(v492_))
                return
            end
        end
    else
        self.elementToFocus = self.contextButtonList
    end
end
]]


function table:count()
	local c = 0
	if self ~= nil then
		for _ in pairs(self) do
			c = c + 1
		end
	end
	return c
end

function table:contains(value)
	for _, v in pairs(self) do
		if v == value then
			return true
		end
	end
	return false
end

function VehicleBreakdowns:FillUnit_loadFillUnitFromXML(xmlFile, key, entry, index)
	local v_u_383_ = self.spec_fillUnit
	entry.fillUnitIndex = index
	--- RVB MOD START
	--entry.capacity = xmlFile:getValue(key .. "#capacity", math.huge)
	entry.capacity = xmlFile:getValue(key .. "#capacity", 100)
	--- RVB MOD END
	entry.defaultCapacity = entry.capacity
	entry.updateMass = xmlFile:getValue(key .. "#updateMass", true)
	entry.canBeUnloaded = xmlFile:getValue(key .. "#canBeUnloaded", true)
	entry.allowFoldingThreshold = xmlFile:getValue(key .. "#allowFoldingThreshold")
	local v384_ = xmlFile:getValue(key .. "#allowFoldingFillType")
	if v384_ ~= nil then
		local v385_ = g_fillTypeManager:getFillTypeIndexByName(v384_)
		if v385_ == nil then
			Logging.xmlWarning(self.xmlFile, "Invalid fill type for fill unit in \'%s\'", v384_, key .. "#allowFoldingFillType")
		else
			entry.allowFoldingFillType = v385_
		end
	end
	entry.needsSaving = true
	entry.fillLevel = 0
	entry.fillLevelSent = 0
	entry.fillType = FillType.UNKNOWN
	entry.fillTypeSent = FillType.UNKNOWN
	entry.fillTypeToDisplay = FillType.UNKNOWN
	entry.fillLevelToDisplay = nil
	entry.capacityToDisplay = nil
	entry.lastValidFillType = FillType.UNKNOWN
	entry.lastValidFillTypeSent = FillType.UNKNOWN
	if xmlFile:hasProperty(key .. ".exactFillRootNode") then
		XMLUtil.checkDeprecatedXMLElements(xmlFile, key .. ".exactFillRootNode#index", key .. ".exactFillRootNode#node")
		entry.exactFillRootNode = xmlFile:getValue(key .. ".exactFillRootNode#node", nil, self.components, self.i3dMappings)
		if entry.exactFillRootNode == nil then
			Logging.xmlWarning(self.xmlFile, "ExactFillRootNode not found for fillUnit \'%s\'!", key)
		elseif CollisionFlag.getHasGroupFlagSet(entry.exactFillRootNode, CollisionFlag.FILLABLE) then
			v_u_383_.exactFillRootNodeToFillUnit[entry.exactFillRootNode] = entry
			v_u_383_.exactFillRootNodeToExtraDistance[entry.exactFillRootNode] = xmlFile:getValue(key .. ".exactFillRootNode#extraEffectDistance", 0)
			v_u_383_.hasExactFillRootNodes = true
			g_currentMission:addNodeObject(entry.exactFillRootNode, self)
		else
			Logging.xmlWarning(self.xmlFile, "Missing collision group %s. Please add this bit to exact fill root node \'%s\' collision filter group in \'%s\'", CollisionFlag.getBitAndName(CollisionFlag.FILLABLE), getName(entry.exactFillRootNode), key)
		end
	--- RVB MOD START
	else
		for _, otherFillUnit in ipairs(v_u_383_.fillUnits) do
			if otherFillUnit.exactFillRootNode ~= nil then
				--local cloneNode = clone(otherFillUnit.exactFillRootNode, true, false)
				--link(getParent(otherFillUnit.exactFillRootNode), cloneNode)
				--setTranslation(cloneNode, 0,0,0)
				
				-- github issues#107
				local src = otherFillUnit.exactFillRootNode
				local cloneNode = clone(src, true, false)
				local parent = getParent(src)
				link(parent, cloneNode)
				local x, y, z = getTranslation(src)
				setTranslation(cloneNode, x, y, z)
				local rx, ry, rz = getRotation(src)
				setRotation(cloneNode, rx, ry, rz)
				local sx, sy, sz = getScale(src)
				setScale(cloneNode, sx, sy, sz)
				local fillUnitIndexStr = tostring(entry.fillUnitIndex or 0)
				setName(cloneNode, "BatteryFillRootNode_" .. fillUnitIndexStr)
				entry.exactFillRootNode = cloneNode
				--print("BatteryFillRootNode_" .. fillUnitIndexStr)
				--print(("Klónoztam exactFillRootNode-t: fillUnit %s kapott node-ot %s-ről"):format(p375, otherFillUnit.fillType))
				break
			end
		end
		if entry.exactFillRootNode == nil then
			Logging.xmlWarning(self.xmlFile, "RVB ExactFillRootNode not found for fillUnit \'%s\'!", key)
		elseif CollisionFlag.getHasGroupFlagSet(entry.exactFillRootNode, CollisionFlag.FILLABLE) then
			v_u_383_.exactFillRootNodeToFillUnit[entry.exactFillRootNode] = entry
			v_u_383_.exactFillRootNodeToExtraDistance[entry.exactFillRootNode] = xmlFile:getValue(key .. ".exactFillRootNode#extraEffectDistance", 0)
			v_u_383_.hasExactFillRootNodes = true
			g_currentMission:addNodeObject(entry.exactFillRootNode, self)
		else
			Logging.xmlWarning(self.xmlFile, "RVB Missing collision group %s. Please add this bit to exact fill root node \'%s\' collision filter group in \'%s\'", CollisionFlag.getBitAndName(CollisionFlag.FILLABLE), getName(entry.exactFillRootNode), key)
		end
	--- RVB MOD END
	end
	XMLUtil.checkDeprecatedXMLElements(xmlFile, key .. ".autoAimTargetNode#index", key .. ".autoAimTargetNode#node")
	entry.autoAimTarget = {}
	entry.autoAimTarget.node = xmlFile:getValue(key .. ".autoAimTargetNode#node", nil, self.components, self.i3dMappings)
	if entry.autoAimTarget.node ~= nil then
		entry.autoAimTarget.baseTrans = { getTranslation(entry.autoAimTarget.node) }
		entry.autoAimTarget.startZ = xmlFile:getValue(key .. ".autoAimTargetNode#startZ")
		entry.autoAimTarget.endZ = xmlFile:getValue(key .. ".autoAimTargetNode#endZ")
		entry.autoAimTarget.startPercentage = xmlFile:getValue(key .. ".autoAimTargetNode#startPercentage", 25) / 100
		entry.autoAimTarget.invert = xmlFile:getValue(key .. ".autoAimTargetNode#invert", false)
		if entry.autoAimTarget.startZ ~= nil and entry.autoAimTarget.endZ ~= nil then
			local v386_ = entry.autoAimTarget.startZ
			if entry.autoAimTarget.invert then
				v386_ = entry.autoAimTarget.endZ
			end
			setTranslation(entry.autoAimTarget.node, entry.autoAimTarget.baseTrans[1], entry.autoAimTarget.baseTrans[2], v386_)
		end
	end
	entry.supportedFillTypes = {}
	local v387_ = xmlFile:getValue(key .. "#fillTypeCategories")
	local v388_ = xmlFile:getValue(key .. "#fillTypes")
	local v389_
	if v387_ == nil or v388_ ~= nil then
		if v387_ ~= nil or v388_ == nil then
			Logging.xmlWarning(self.xmlFile, "Missing \'fillTypeCategories\' or \'fillTypes\' for fillUnit \'%s\'", key)
			return false
		end
		v389_ = g_fillTypeManager:getFillTypesByNames(v388_, "Warning: \'" .. self.configFileName .. "\' has invalid fillType \'%s\'.")
	else
		v389_ = g_fillTypeManager:getFillTypesByCategoryNames(v387_, "Warning: \'" .. self.configFileName .. "\' has invalid fillTypeCategory \'%s\'.")
	end
	if v389_ ~= nil then
		for _, v390_ in pairs(v389_) do
			entry.supportedFillTypes[v390_] = true
		end
	end
	entry.supportedToolTypes = {}
	for v391_ = 1, g_toolTypeManager:getNumberOfToolTypes() do
		entry.supportedToolTypes[v391_] = true
	end
	local v392_ = xmlFile:getValue(key .. "#startFillLevel")
	local v393_ = xmlFile:getValue(key .. "#startFillType")
	if v393_ ~= nil then
		local v394_ = g_fillTypeManager:getFillTypeIndexByName(v393_)
		if v394_ ~= nil then
			entry.startFillLevel = v392_
			entry.startFillTypeIndex = v394_
		end
	end
	entry.fillRootNode = xmlFile:getValue(key .. ".fillRootNode#node", nil, self.components, self.i3dMappings)
	if entry.fillRootNode == nil then
		entry.fillRootNode = self.components[1].node
	end
	entry.fillMassNode = xmlFile:getValue(key .. ".fillMassNode#node", nil, self.components, self.i3dMappings)
	local v395_ = xmlFile:getValue(key .. "#updateFillLevelMass", true)
	if entry.fillMassNode == nil and v395_ then
		entry.fillMassNode = self.components[1].node
	end
	entry.ignoreFillLimit = xmlFile:getValue(key .. "#ignoreFillLimit", false)
	entry.synchronizeFillLevel = xmlFile:getValue(key .. "#synchronizeFillLevel", true)
	entry.synchronizeFullFillLevel = xmlFile:getValue(key .. "#synchronizeFullFillLevel", false)
	local v396_ = 16
	for v397_, v398_ in pairs(FillUnit.CAPACITY_TO_NETWORK_BITS) do
		if v397_ <= entry.capacity then
			v396_ = v398_
		end
	end
	entry.synchronizationNumBits = xmlFile:getValue(key .. "#synchronizationNumBits", v396_)
	entry.showOnHud = xmlFile:getValue(key .. "#showOnHud", true)
	entry.showOnInfoHud = xmlFile:getValue(key .. "#showOnInfoHud", true)
	entry.uiPrecision = xmlFile:getValue(key .. "#uiPrecision", 0)
	entry.uiCustomFillTypeName = xmlFile:getValue(key .. "#uiCustomFillTypeName", nil, self.customEnvironment, false)
	entry.uiExtraInfoText = xmlFile:getValue(key .. "#uiExtraInfoText", nil, self.customEnvironment, false)
	entry.uiDisplayTypeId = FillLevelsDisplay["TYPE_" .. xmlFile:getValue(key .. "#uiDisplayType", "BAR")] or FillLevelsDisplay.TYPE_BAR
	local v399_ = xmlFile:getValue(key .. "#unitTextOverride")
	if v399_ ~= nil then
		entry.unitText = g_i18n:convertText(v399_)
	end
	entry.parentUnitOnHud = nil
	entry.childUnitOnHud = nil
	entry.blocksAutomatedTrainTravel = xmlFile:getValue(key .. "#blocksAutomatedTrainTravel", false)
	entry.fillAnimation = xmlFile:getValue(key .. "#fillAnimation")
	entry.fillAnimationLoadTime = xmlFile:getValue(key .. "#fillAnimationLoadTime")
	entry.fillAnimationEmptyTime = xmlFile:getValue(key .. "#fillAnimationEmptyTime")
	entry.fillLevelAnimations = {}
	for _, v400_ in xmlFile:iterator(key .. ".fillLevelAnimation") do
		local v401_ = {
			["name"] = xmlFile:getValue(v400_ .. "#name")
		}
		if v401_.name == nil then
			Logging.xmlWarning(xmlFile, "Missing \'name\' for fillLevelAnimation \'%s\'", v400_)
		else
			v401_.resetOnEmpty = xmlFile:getValue(v400_ .. "#resetOnEmpty", true)
			v401_.updateWhileFilled = xmlFile:getValue(v400_ .. "#updateWhileFilled", true)
			v401_.useMaxStateIfEmpty = xmlFile:getValue(v400_ .. "#useMaxStateIfEmpty", false)
			local v402_ = entry.fillLevelAnimations
			table.insert(v402_, v401_)
		end
	end
	if self.isClient then
		entry.alarmTriggers = {}
		local v403_ = 0
		while true do
			local v404_ = key .. string.format(".alarmTriggers.alarmTrigger(%d)", v403_)
			if not xmlFile:hasProperty(v404_) then
				break
			end
			local v405_ = {}
			if self:loadAlarmTrigger(xmlFile, v404_, v405_, entry) then
				local v406_ = entry.alarmTriggers
				table.insert(v406_, v405_)
			end
			v403_ = v403_ + 1
		end
		entry.measurementNodes = {}
		local v407_ = 0
		while true do
			local v408_ = key .. string.format(".measurementNodes.measurementNode(%d)", v407_)
			if not xmlFile:hasProperty(v408_) then
				break
			end
			local v409_ = {}
			if self:loadMeasurementNode(xmlFile, v408_, v409_) then
				local v410_ = entry.measurementNodes
				table.insert(v410_, v409_)
			end
			v407_ = v407_ + 1
		end
		entry.fillPlane = {}
		entry.lastFillPlaneType = nil
		if not self:loadFillPlane(xmlFile, key .. ".fillPlane", entry.fillPlane, entry) then
			entry.fillPlane = nil
		end
		entry.fillTypeMaterials = self:loadFillTypeMaterials(xmlFile, key)
		entry.fillEffects = g_effectManager:loadEffect(xmlFile, key .. ".fillEffect", self.components, self, self.i3dMappings)
		entry.animationNodes = g_animationManager:loadAnimations(xmlFile, key .. ".animationNodes", self.components, self, self.i3dMappings)
		XMLUtil.checkDeprecatedXMLElements(xmlFile, key .. ".fillLevelHud", key .. ".dashboard")
		entry.hasDashboards = false
		--- RVB MOD START
		-- github issues#63
		--[[if self.registerDashboardValueType ~= nil then
			local function v_u_418_(_, p411_, p412_, p413_, _)
				-- upvalues: (copy) v_u_383_, (copy) entry
				local v414_ = p411_:getValue(p412_ .. "#fillType")
				if v414_ ~= nil then
					local v415_ = g_fillTypeManager:getFillTypeIndexByName(v414_)
					if v415_ ~= nil then
						for _, v416_ in ipairs(v_u_383_.fillUnits) do
							if v407.fillType ~= FillType.BATTERYCHARGE then print("BATTERYCHARGE "..v407.fillType)
							if v416_.supportedFillTypes[v415_] then
								p413_.fillUnit = v416_
							end
							end
						end
					end
				end
				local v417_ = p411_:getValue(p412_ .. "#fillUnitIndex")
				if v417_ ~= nil then
					p413_.fillUnit = v_u_383_.fillUnits[v417_]
				end
				if p413_.fillUnit == nil then
					entry.hasDashboards = true
				else
					p413_.fillUnit.hasDashboards = true
				end
				return true
			end
			local v419_ = DashboardValueType.new("fillUnit", "fillLevel")
			v419_:setXMLKey(key)
			v419_:setValue(entry, function(p420_, p421_)
				return (p421_.fillUnit or p420_).fillLevel
			end)
			v419_:setRange(0, function(p422_, p423_)
				return (p423_.fillUnit or p422_).capacity
			end)
			v419_:setInterpolationSpeed(function(p424_, p425_)
				return (p425_.fillUnit or p424_).capacity * 0.001
			end)
			v419_:setAdditionalFunctions(v_u_418_, nil)
			v419_:setPollUpdate(false)
			self:registerDashboardValueType(v419_)
			local v426_ = DashboardValueType.new("fillUnit", "fillLevelPct")
			v426_:setXMLKey(key)
			v426_:setValue(entry, function(p427_, p428_)
				local v429_ = p428_.fillUnit or p427_
				local v430_ = v429_.fillLevel / v429_.capacity
				return math.clamp(v430_, 0, 1) * 100
			end)
			v426_:setRange(0, 100)
			v426_:setInterpolationSpeed(0.1)
			v426_:setAdditionalFunctions(v_u_418_, nil)
			v426_:setPollUpdate(false)
			self:registerDashboardValueType(v426_)
			local v431_ = DashboardValueType.new("fillUnit", "fillLevelWarning")
			v431_:setXMLKey(key)
			v431_:setValue(entry, function(p432_, p433_)
				local v434_ = (p433_.fillUnit or p432_).fillLevel
				local v435_
				if p433_.warningThresholdMin < v434_ then
					v435_ = v434_ < p433_.warningThresholdMax
				else
					v435_ = false
				end
				return v435_
			end)
			v431_:setAdditionalFunctions(function(p436_, p437_, p438_, p439_, p440_)
				-- upvalues: (copy) v_u_418_
				v_u_418_(p436_, p437_, p438_, p439_, p440_)
				return Dashboard.warningAttributes(p436_, p437_, p438_, p439_, p440_)
			end)
			v431_:setPollUpdate(false)
			self:registerDashboardValueType(v431_)
		end]]
	end
	return true
end

--FillUnit.loadFillUnitFromXML = Utils.overwrittenFunction(FillUnit.loadFillUnitFromXML, VehicleBreakdowns.FillUnit_loadFillUnitFromXML)









function VehicleBreakdowns.injPhysWheelUpdateContact(self)

	if self.vehicle.isServer then
	local vWheel = self.wheel
	if vWheel.uytTravelledDist == nil then
		vWheel.uytTravelledDist = 0
	end
	local rvb = self.vehicle.spec_faultData
    if not rvb then return end
	
	if not rvb.isrvbSpecEnabled then return	end
	
	if self.contact == WheelContactType.GROUND or self.contact == WheelContactType.OBJECT then

		local partName = WHEELTOPART[vWheel.wheelIndex]
		if partName == nil then return end
		local part = rvb.parts[partName]
		if not part then
			if self.vehicle.isServer then
				print(string.format("RVB WARNING: part %s missing on SERVER for vehicle %s", tostring(partName), tostring(self.vehicle:getFullName())))
			else
				print(string.format("RVB WARNING: part %s missing on CLIENT for vehicle %s", tostring(partName), tostring(self.vehicle:getFullName())))
			end
			return
		end
		-- distance traveled
		local needDirtyUpdate = false
		if vWheel.uytTravelledDist ~= part.operatingHours then
			--vWheel.uytTravelledDist = part.operatingHours
			part.operatingHours = vWheel.uytTravelledDist
			needDirtyUpdate = true
		end
		if needDirtyUpdate then
			self.vehicle:raiseDirtyFlags(rvb.updateTyreDirtyFlag)
		end
	end
	end
end











function VehicleBreakdowns:minuteChanged()
	local spec = self.spec_faultData
	if spec == nil or not spec.isrvbSpecEnabled then
        return
    end
	--local specMotorized = self.spec_motorized

	--local side = self.isServer and "[SERVER]" or "[CLIENT]"
	--print(side .. " " .. self:getFullName() .. " temp= " .. specMotorized.motorTemperature.value.. " self.currentTemperaturDay " ..self.currentTemperaturDay)

end
function VehicleBreakdowns:RVBhourChanged()
	local spec = self.spec_faultData
	if spec == nil or not spec.isrvbSpecEnabled then
        return
    end
	self.currentTemperaturDay = g_currentMission.environment.weather:getCurrentTemperature()
	self.currentTemperaturDay =  self.currentTemperaturDay - math.random(2,5)
	if self.isServer then
		local workshopStatus, _ = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
		updateSuspensionState(self, workshopStatus)
	end

	--- ---
	local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
	if batteryFillUnitIndex == nil then return end
	if self.isServer then
		if spec.batterySelfDischarge then
			local batteryFillLevel = self:getFillUnitFillLevel(batteryFillUnitIndex)
			if batteryFillLevel <= 0 then return end
			local daysPerMonth = g_currentMission.environment.plannedDaysPerPeriod or 1
			local dischargePerDay = 0.03 / daysPerMonth  -- 3% havonta
			local dischargePerHour = dischargePerDay / 24
			local dischargeAmount = math.min(batteryFillLevel * dischargePerHour, batteryFillLevel)
			self:addFillUnitFillLevel(self:getOwnerFarmId(), batteryFillUnitIndex, -dischargeAmount, self:getFillUnitFillType(batteryFillUnitIndex), ToolType.UNDEFINED, nil)
		end
		if self:getMotorState() == MotorState.OFF and not spec.batterySelfDischarge then spec.batterySelfDischarge = true end
	end
	
end


function VehicleBreakdowns:onSetPartsLifetime(partsName, partsLifetime, oldLifetime)
	if self.isServer then
		local daysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod or 1
		local tyres = { TIREFL, TIRERL, TIREFR, TIRERR }
		if partsName == "TIRES" then
			for _, tname in ipairs(tyres) do
				self:applyLifetimeToPart(tname, partsLifetime, oldLifetime, daysPerPeriod)
			end
		else
			self:applyLifetimeToPart(partsName, partsLifetime, oldLifetime, daysPerPeriod)
		end
	end
end



function VehicleBreakdowns:applyLifetimeToPart(partsName, partsLifetime, oldLifetime, daysPerPeriod)
	local tireMultiplier = 1000
	--for _, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
	local vehicle = self
	if vehicle.spec_faultData then
		local part = vehicle.spec_faultData.parts[partsName]
		if part then

			local function isTyrePart(name)
				return name == TIREFL or name == TIREFR or name == TIRERL or name == TIRERR
			end

			local function rescaleOperatingHours(percent, newTmpLifetime)
				return math.max(0, math.min(percent * newTmpLifetime, newTmpLifetime))
			end

			if isTyrePart(partsName) and part.lifetimepercent == nil then

				local maxLifetime 
				local baseLifetime = oldLifetime
				if baseLifetime <= 0 then
					return 0
				end

				if g_rvbGameplaySettings.difficulty == 1 then
					maxLifetime = baseLifetime * 2 * daysPerPeriod * tireMultiplier
				elseif g_rvbGameplaySettings.difficulty == 2 then
					maxLifetime = baseLifetime * 1 * daysPerPeriod * tireMultiplier
				else
					maxLifetime = baseLifetime / 2 * daysPerPeriod * tireMultiplier
				end
	
				part.lifetimepercent = part.operatingHours / maxLifetime

			end

			if isTyrePart(partsName) then
				local maxLifetime = PartManager.getMaxPartLifetime(vehicle, partsName)
				part.operatingHours = rescaleOperatingHours(part.lifetimepercent, maxLifetime)
				--print("NEW operatingHours "..vehicle:getFullName().." "..partsName.." "..part.operatingHours)
			end

			if g_modIsLoaded["FS25_useYourTyres"] then
				if vehicle.spec_wheels ~= nil then
					for wheelIdx, wheel in ipairs(vehicle.spec_wheels.wheels) do
						local partName = WHEELTOPART[wheelIdx]
						if partName == nil then return end
						local part = vehicle.spec_faultData.parts[partName]
						if not part then return end
						wheel.uytTravelledDist = part.operatingHours
					end
				end
			end

			vehicle.rvbDebugger:info("Updated %s lifetime to %s on %s", partsName, partsLifetime, vehicle:getFullName())

			RVBParts_Event.sendEvent(vehicle, vehicle.spec_faultData.parts)
		end
	end
    --end
end



function VehicleBreakdowns:onSetDifficulty(difficulty)
	--print("DEBUG: onSetDifficulty called!" .. difficulty)
    local daysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod
	--for _, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
	local vehicle = self
		if vehicle.spec_faultData then
		--print(string.format("onSetDifficulty %s difficulty %s", vehicle:getFullName(), difficulty))
			local rvbVehicle = vehicle.spec_faultData
			for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
				local part = rvbVehicle.parts[key]
				if part and part.name ~= nil then
				
					local function isTyrePart(name)
						return name == TIREFL or name == TIREFR or name == TIRERL or name == TIRERR
					end
					local tireMultiplier = 1
					if isTyrePart(key) then
						tireMultiplier = 1000
					end
					
					if g_rvbGameplaySettings.difficulty == 1 then
						--part.tmp_lifetime = part.lifetime * 2 * daysPerPeriod * tireMultiplier
					elseif g_rvbGameplaySettings.difficulty == 2 then
						--part.tmp_lifetime = part.lifetime * 1 * daysPerPeriod * tireMultiplier
					else
						--part.tmp_lifetime = part.lifetime / 2 * daysPerPeriod * tireMultiplier
					end
				end
			end
			--RVBParts_Event.sendEvent(vehicle, rvbVehicle.parts)
		end
	--end

	if g_modIsLoaded["FS25_useYourTyres"] then
		local RVBMain = g_currentMission.vehicleBreakdowns
		if GPSET.difficulty == 1 then
			FS25_useYourTyres.UseYourTyres.USED_MAX_M = RVBMain:getTireLifetime() * 1000 * 2 --* daysPerPeriod
		elseif GPSET.difficulty == 2 then
			FS25_useYourTyres.UseYourTyres.USED_MAX_M = RVBMain:getTireLifetime() * 1000 * 1 --* daysPerPeriod
		else
			FS25_useYourTyres.UseYourTyres.USED_MAX_M = RVBMain:getTireLifetime() * 1000 / 2 --* daysPerPeriod
		end
	end
end
function VehicleBreakdowns:onSetPlannedDaysPerPeriod(days)
    --local daysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod
	local daysPerPeriod = days
	
	if g_dedicatedServer ~= nil then
	--if g_server ~= nil then
        -- Server ne számoljon difficulty alapján, mert az kliens-specifikus
        return
    end
	for _, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
		if vehicle.spec_faultData then
			local rvbVehicle = vehicle.spec_faultData
			for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
				local part = rvbVehicle.parts[key]
				if part and part.name ~= nil then
					local function isTyrePart(name)
						return name == TIREFL or name == TIREFR or name == TIRERL or name == TIRERR
					end
					local tireMultiplier = 1
					if isTyrePart(key) then
						tireMultiplier = 1000
					end
					if g_rvbGameplaySettings.difficulty == 1 then
						--part.tmp_lifetime = part.lifetime * 2 * daysPerPeriod * tireMultiplier
					elseif g_rvbGameplaySettings.difficulty == 2 then
						--part.tmp_lifetime = part.lifetime * 1 * daysPerPeriod * tireMultiplier
					else
						--part.tmp_lifetime = part.lifetime / 2 * daysPerPeriod * tireMultiplier
					end
				end
			end
			--RVBParts_Event.sendEvent(vehicle, rvbVehicle.parts)
		end
	end
end
function VehicleBreakdowns:onWorkshopStateChanged()
	if self.isServer then
		local workshopStatus, _ = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
		local spec = self.spec_faultData
		if spec ~= nil and spec.isrvbSpecEnabled then
			updateSuspensionState(self, workshopStatus)
			self.rvbDebugger:info("'onWorkshopStateChanged' function is for this %s", self:getFullName())
		end
	end
end
--if g_sleepManager:getIsSleeping() then
function VehicleBreakdowns:onSleepingStateChanged(isSleeping)
	if not isSleeping and self.spec_motorized ~= nil then
		self.spec_motorized.motorTemperature.value = self.currentTemperaturDay
	end
end
function VehicleBreakdowns:onRVBVehicleReset(vehicle)
    if vehicle ~= self then
        return
    end
    
    if self.isServer  then
	print("onRVBVehicleReset " .. self:getFullName())
	
--[[local rvb = self.spec_faultData
    rvb.service = { false, false, 0, 0, 0, 0, 0, 0 }
    rvb.repair = { false, false, 0, 0, 0, 0, 0, 0, 0, false }
	rvb.inspection = { false, false, 0, 0, 0, 0, 0, false }
    
    for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
        local part = rvb.parts[key]
		if part then
			part.repairreq = false
			part.prefault = "empty"
			part.fault = "empty"
			part.pre_random = nil
		end
    end
]]

--	RVBParts_Event.sendEvent(self, rvb.parts)
	--if self.isServer  then
--    self:addFillUnitFillLevel(self:getOwnerFarmId(), rvb.batteryFillUnitIndex, 100, self:getFillUnitFillType(rvb.batteryFillUnitIndex), ToolType.UNDEFINED, nil)
	--end

	--[[local RVB = g_currentMission.vehicleBreakdowns
	if RVB.workshopVehicles[self] then
		RVB.workshopVehicles[self] = nil
		RVB.workshopCount = RVB.workshopCount - 1
		WorkshopCount_Event.sendEvent(RVB.workshopCount)
	end]]
	
    end

end

function VehicleBreakdowns:onProgressMessage(vehicle, key, textKey)
	if vehicle ~= self then return end
	if vehicle.spec_faultData == nil or not vehicle.spec_faultData.isrvbSpecEnabled then return end
	if not g_rvbGeneralSettings.alertmessage then return end
	if vehicle.getIsEntered ~= nil and vehicle:getIsEntered() and vehicle:getIsControlled() then 
		g_currentMission:showBlinkingWarning(g_i18n:getText(textKey), 1500)
	end
	vehicle.rvbDebugger:info(g_i18n:getText(textKey .. "_hud"), vehicle:getFullName())
end

function VehicleBreakdowns:addJumperCableMessage(method, key, text, value)
    local spec = self.spec_faultData
    spec.uiJumperCableMessage = spec.uiJumperCableMessage or {}
    table.insert(spec.uiJumperCableMessage, {
		method = method,
        key  = key,
        text = text,
		value = value
    })
	local list = spec.uiJumperCableMessage
	local last = list[#list]
	if last ~= nil then
		print("addJumperCableMessage "..last.key)
	end
	--g_currentMission:addMoney(-value, self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
	--local farmId = self:getOwnerFarmId()
	--local farm = g_farmManager:getFarmById(farmId)
	--local money = g_localPlayer == nil and 0 or g_farmManager:getFarmById(g_localPlayer.farmId).money
	--g_currentMission.hud:addMoneyChange(MoneyType.VEHICLE_REPAIR, money)
    spec.hasNewUIJumperCableMessage = true
    if self.isServer then
        self:raiseDirtyFlags(spec.uiJumperCableMessageDirtyFlag)
    end
end
	
	
function VehicleBreakdowns:onJumperCableMessage(vehicle, method, key, textKey, value)
	if vehicle ~= self then return end
	if vehicle.spec_faultData == nil or not vehicle.spec_faultData.isrvbSpecEnabled then return end
	if not g_rvbGeneralSettings.alertmessage then return end
	if method == "notification" then
		if self.isClient then
			local message = string.format(g_i18n:getText(textKey), g_i18n:formatMoney(value, 0, true, true))
			g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, message, 12000, GuiSoundPlayer.SOUND_SAMPLES.SUCCESS)
			vehicle.rvbDebugger:info(message)
		end
	end
	if method == "blinking" then
		if vehicle.getIsEntered ~= nil and vehicle:getIsEntered() and vehicle:getIsControlled() then
			g_currentMission:showBlinkingWarning(g_i18n:getText(textKey), 1500)
		end
		vehicle.rvbDebugger:info(g_i18n:getText(textKey), vehicle:getFullName())
	end
end

function VehicleBreakdowns:addBlinkingMessage(key, text)
    local spec = self.spec_faultData
    spec.uiBlinkingMessage = spec.uiBlinkingMessage or {}
    table.insert(spec.uiBlinkingMessage, {
        key  = key,
        text = text
    })
	--local list = spec.uiBlinkingMessage
	--local last = list[#list]
	--if last ~= nil then
	--	print("disconnecting_toofar "..last.key)
	--end
    spec.hasNewUIBlinkingMessage = true
    if self.isServer then
		if key == "disconnecting_toofar" then
			g_currentMission:addMoney(-100, self:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
		end
        self:raiseDirtyFlags(spec.uiBlinkingDirtyFlag)
    end
end


function VehicleBreakdowns:onBlinkingMessage(vehicle, key, textKey)
	if vehicle ~= self then return end
	if vehicle.spec_faultData == nil or not vehicle.spec_faultData.isrvbSpecEnabled then return end
	if not g_rvbGeneralSettings.alertmessage then return end
	if vehicle.getIsEntered ~= nil and vehicle:getIsEntered() and vehicle:getIsControlled() then
		g_currentMission:showBlinkingWarning(g_i18n:getText(textKey), 1500)
	end
	vehicle.rvbDebugger:info(g_i18n:getText(textKey), vehicle:getFullName())
end	

function VehicleBreakdowns:isRepairRequired(partId)
    local part = self.spec_faultData and self.spec_faultData.parts[partId]
    return part and part.repairreq or false
end

function VehicleBreakdowns:isThermostatRepairRequired()
    return self:isRepairRequired(THERMOSTAT)
end
function VehicleBreakdowns:isLightingsRepairRequired()
    return self:isRepairRequired(LIGHTINGS)
end
function VehicleBreakdowns:isGlowPlugRepairRequired()
    return self:isRepairRequired(GLOWPLUG)
end
function VehicleBreakdowns:isWipersRepairRequired()
    return self:isRepairRequired(WIPERS)
end
function VehicleBreakdowns:isGeneratorRepairRequired()
    return self:isRepairRequired(GENERATOR)
end
function VehicleBreakdowns:isEngineRepairRequired()
    return self:isRepairRequired(ENGINE)
end
function VehicleBreakdowns:isSelfStarterRepairRequired()
    return self:isRepairRequired(SELFSTARTER)
end
function VehicleBreakdowns:isBatteryRepairRequired()
    return self:isRepairRequired(BATTERY)
end

function VehicleBreakdowns:getIsFaultStates(partId)
    local part = self.spec_faultData and self.spec_faultData.parts[partId]
    local prefault, fault = "empty", "empty"
    if part then
        prefault = (part.prefault and part.prefault ~= "empty") and part.prefault or "empty"
        fault    = (part.fault and part.fault ~= "empty") and part.fault or "empty"
    end
    return prefault, fault
end






function VehicleBreakdowns:getIsFaultThermostat()
    return self:getIsFaultPart(THERMOSTAT)
end
function VehicleBreakdowns:getFaultThermostat()
	local spec = self.spec_faultData
	return spec.parts[THERMOSTAT].repairreq
end




function VehicleBreakdowns:getIsFaultEngine()
	local spec = self.spec_faultData
	return spec.parts[ENGINE].repairreq
end

function VehicleBreakdowns:getIsFaultSelfStarter()
	local spec = self.spec_faultData
	return spec.parts[SELFSTARTER].repairreq
end




function VehicleBreakdowns:getBatteryFillLevelPercentage()
    if self.spec_faultData == nil then
        return 1
    end
    local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
    if batteryFillUnitIndex ~= nil then
        return tonumber(self:getFillUnitFillLevelPercentage(batteryFillUnitIndex))
    end
    return 1
end
--[[function VehicleBreakdowns:getBatteryFillLevelPercentage()
	local spec = self.spec_faultData
	if spec == nil then return end
	local batteryFillUnitIndex = self:getBatteryFillUnitIndex()
	local dieselFillUnitIndex = self:getConsumerFillUnitIndex(FillType.DIESEL)
	if batteryFillUnitIndex ~= nil and dieselFillUnitIndex ~= nil then
		return tonumber(self:getFillUnitFillLevelPercentage(batteryFillUnitIndex)) or 1
	end
	return 1
end]]
function VehicleBreakdowns.getVehicleSpeed(vehicle)
    local speedKmh = math.max(Utils.getNoNil(vehicle.lastSpeed, 0) * 3600, 0)
    local useMiles = g_gameSettings:getValue("useMiles")
    return useMiles and (speedKmh * 0.621371192) or speedKmh
end
function VehicleBreakdowns:lightingsFault()
	if self:isLightingsRepairRequired() or self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS then
		self:setLightsTypesMask(0, true, true)
	end
	if self:getBatteryFillLevelPercentage() < BATTERY_LEVEL.LIGHTS_BEACONS then
		self:setBeaconLightsVisibility(false, true, true)
		self:setTurnLightState(Lights.TURNLIGHT_OFF, true, true)
	end
end
--[[
	Növelje a világítás üzemidejét
	Amikor ég a lámpa
	A világítás működik
	Az akkumulátor működik és a töltési szint megfelelő
	Increase the operating hours of the lighting
	When the light is on
	Lighting is working
	The battery is working and the charge level is adequate
]]
function VehicleBreakdowns:onStartLightingsOperatingHours(dt, isActiveForInputIgnoreSelection)
	if self.isServer then
		local spec = self.spec_faultData
		if spec == nil then return end
		local parts = spec.parts
		local batteryOk = self:getBatteryFillLevelPercentage() >= BATTERY_LEVEL.LIGHTS
		local activeDrain = BatteryManager.getLightsDrain(self)
		if activeDrain <= 0 then return end
		local lightsFault  = parts[LIGHTINGS] and parts[LIGHTINGS].fault or "empty"
		local batteryFault = parts[BATTERY] and parts[BATTERY].fault or "empty"
		if lightsFault == "empty" and batteryFault == "empty" and batteryOk then
			spec.lightingUpdateTimer = (spec.lightingUpdateTimer or 0) + dt
			if spec.lightingUpdateTimer >= RVB_DELAY.LIGHTINGS_OPERATINGHOURS then
				self:updateLightingOperatingHours(spec.lightingUpdateTimer, spec)
				spec.lightingUpdateTimer = 0
			end
			self:raiseActive()
		end
	end
end
function VehicleBreakdowns:updateLightingOperatingHours(msDelta, spec)
	local runtimeIncrease = msDelta * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
	local partLightings = spec.parts[LIGHTINGS]
	local maxLifetime = PartManager.getMaxPartLifetime(self, LIGHTINGS)
	partLightings.operatingHours = math.min(partLightings.operatingHours + runtimeIncrease, maxLifetime)
	self:raiseDirtyFlags(spec.partsDirtyFlag)
end

function VehicleBreakdowns:onStartOperatingHours(dt)
	if self.isServer then
		local spec = self.spec_faultData
		if spec == nil then return end
		spec.operatingHoursUpdateTimer = (spec.operatingHoursUpdateTimer or 0) + dt
		if spec.operatingHoursUpdateTimer >= RVB_DELAY.PARTS_OPERATINGHOURS then
			self:updateOperatingHours(spec.operatingHoursUpdateTimer, spec)
			spec.operatingHoursUpdateTimer = 0
		end
		self:raiseActive()
	end
end
local function isImplementWorking(obj, vehicle, minSpeed)
	if not obj then return false end
	if obj.spec_roller and obj.spec_roller.isWorking then
		return true
	end
	if not obj.getIsTurnedOn and obj.getIsLowered and obj:getIsLowered() and vehicle:getLastSpeed() >= minSpeed then
		return true
	end
	if obj.getIsTurnedOn and obj:getIsTurnedOn() and obj.getIsLowered and obj:getIsLowered() and obj.getIsImplementChainLowered and obj:getIsImplementChainLowered() and vehicle:getLastSpeed() >= minSpeed then
		return true
	end
	if obj.getIsTurnedOn and not obj:getIsTurnedOn() and obj.getIsLowered and obj:getIsLowered() and obj.getIsImplementChainLowered and obj:getIsImplementChainLowered() and vehicle:getLastSpeed() >= minSpeed then
		return true
	end
	if obj.getPtoRpm and obj:getPtoRpm() > 0 then
		return true
	end
	return false
end
function VehicleBreakdowns:updateOperatingHours(msDelta, spec)

	local runtimeIncrease = msDelta * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
	
	spec.totaloperatingHours = spec.totaloperatingHours + runtimeIncrease
	spec.operatingHours = spec.operatingHours + runtimeIncrease

	local isWorking = false
	local minSpeed = 0.5
	local attachedImplements = self.getAttachedImplements and self:getAttachedImplements()
	if attachedImplements then
		for _, implement in ipairs(attachedImplements) do
			if isImplementWorking(implement.object, self, minSpeed) then
				isWorking = true
				break
			end
		end
	end

	if self.getDoConsumePtoPower and self:getDoConsumePtoPower() then
		isWorking = true
	end

	local specM = self.spec_motorized
	local motorTemp = specM and specM.motorTemperature.value
	--local speedKmH = self:getLastSpeed()
	--local maxSpeed = specM.motor and (specM.motor:getMaximumForwardSpeed() * 3.6) or 50
	--local maxSpeedThreshold = math.floor(maxSpeed * MAXSPEED_THRESHOLD)
	--local speedFactor = 1
	local motorFactor = 1
	local loadFactor = 1
	
	--spec.operatingHoursUpdateTimer = (spec.operatingHoursUpdateTimer or 0) + dt
	--	if spec.operatingHoursUpdateTimer >= RVB_DELAY.PARTS_OPERATINGHOURS then
	--		self:updateOperatingHours(spec.operatingHoursUpdateTimer, spec)
	--		spec.operatingHoursUpdateTimer = 0
	--	end
		
		
	--local loadPercentage = (specM.motor and specM.motor.smoothedLoadPercentage) or 0
	local loadPercentage = (spec.motorLoadPercent or 0) / 100
	
	if motorTemp < MOTORTEMP_THRESHOLD then
		if loadPercentage > MOTORTEMP_LOAD_THRESHOLD then
			local overload = (loadPercentage - MOTORTEMP_LOAD_THRESHOLD) / (1.0 - MOTORTEMP_LOAD_THRESHOLD)
			loadFactor = math.min(1 + math.pow(overload, 1.4) * 1.5, 2)
		end
		--if speedKmH >= maxSpeedThreshold then
		--	local extraSteps = math.floor((speedKmH - maxSpeedThreshold) / 5)
		--	speedFactor = math.min(1.2 + extraSteps * 0.5, 3)
		--end
		if isWorking then
			motorFactor = 2.2
		end
	else
		if loadPercentage > LOADPERCENTAGE_THRESHOLD then
			local overload = (loadPercentage - LOADPERCENTAGE_THRESHOLD) / (1.0 - LOADPERCENTAGE_THRESHOLD)
			loadFactor = math.min(1 + math.pow(overload, 1.4) * 1.5, 2.5)
		elseif loadPercentage > LOADPERCENTAGE_LOAD_THRESHOLD then
			local overload = (loadPercentage - LOADPERCENTAGE_LOAD_THRESHOLD) / (1.0 - LOADPERCENTAGE_LOAD_THRESHOLD)
			loadFactor = math.min(1 + math.pow(overload, 1.4) * 1.5, 1.6)
		end
	end
	
	if motorTemp >= 100 then
		for _, partName in ipairs({THERMOSTAT, ENGINE}) do
			local partData = spec.parts[partName]
			partData.operatingHours = partData.operatingHours + runtimeIncrease * 1.2
		end
	end
	
	local RVBSET = g_currentMission.vehicleBreakdowns

	if motorTemp < MOTORTEMP_THRESHOLD and (loadFactor > 1 or motorFactor > 1) and not spec.engineLoadWarningTriggered then
		--table.insert(spec.uiProgressMessage, {
		--	key  = "engineLoad",
		--	text = "RVB_fault_engineload"
		--})
		spec.engineLoadWarningTriggered = true
		--self:raiseDirtyFlags(spec.uiEventsDirtyFlag)
		--if self.isServer and self.isClient then
		--	g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, self, "engineLoad", "RVB_fault_engineload")
		--end
		self:addBlinkingMessage("engineLoad", "RVB_fault_engineload")
	end
	
	local serviceFactor = 1
	local operatingHours = math.floor(spec.operatingHours)
	local maxServiceThreshold = RVBSET:getPeriodicService()
	if operatingHours > maxServiceThreshold then
		local extraSteps = math.floor((operatingHours - maxServiceThreshold) / 5)
		serviceFactor = math.min(1.05 + extraSteps * 0.2, 3)
	end

	local boostedWear = runtimeIncrease * loadFactor * motorFactor * serviceFactor --* speedFactor
	local normalWear  = runtimeIncrease
    for _, partName in ipairs({THERMOSTAT, GENERATOR, ENGINE, BATTERY}) do
        local partData = spec.parts[partName]
        local applied = false
		--local wearToApply = ((motorFactor > 1 or speedFactor > 1) and (partName == THERMOSTAT or partName == ENGINE))
        --and boostedWear or normalWear
		local wearToApply = ((motorFactor > 1 or loadFactor > 1) and (partName == THERMOSTAT or partName == ENGINE))
        and boostedWear or normalWear
		local wearFactor = 1

        if partData.fault and partData.fault ~= "empty" then
            local registry = FaultRegistry[partName]
            if registry and registry.variants then
                local variant = registry.variants[partData.fault]
                if variant and (not variant.wear or variant.wear(self)) then
                    if variant.wearMultiplier then
                        if variant.wearMultiplier.component then
                            local target = variant.wearMultiplier.component
                            spec.parts[target].operatingHours = spec.parts[target].operatingHours + wearToApply * (variant.wearMultiplier.multiplier or 1)
							wearFactor = variant.wearMultiplier.multiplier
                        else
                            for _, wm in ipairs(variant.wearMultiplier) do
                                local target = wm.component
                                spec.parts[target].operatingHours = spec.parts[target].operatingHours + wearToApply * (wm.multiplier or 1)
								wearFactor = wm.multiplier
                            end
                        end
                    end
                    applied = true
                end
            end
        end
        if not applied then
            partData.operatingHours = partData.operatingHours + wearToApply
        end
		--self.rvbDebugger:info(
		--	"Part: %s | Wear applied: %.6f | Mode: %s | SpeedFactor: %.2f | MotorFactor: %.2f | WearFactor: %.2f",
		--	partName, wearToApply,
		--	wearToApply == boostedWear and "BOOSTED" or "NORMAL",
		--	speedFactor, motorFactor, wearFactor
		--)
    end
	self:raiseDirtyFlags(spec.partsDirtyFlag)
end
function VehicleBreakdowns:onStartWiperOperatingHours(dt)
	if self.isServer then
		local spec = self.spec_faultData
		if spec == nil then return end
		local lastRainScale = g_currentMission.environment.weather:getRainFallScale()
		local wipersOk = false
		if self.getIsActiveForWipers ~= nil then
			wipersOk = self:getIsActiveForWipers()
		end
		if wipersOk and lastRainScale > 0.01 then
			spec.wiperUpdateTimer = (spec.wiperUpdateTimer or 0) + dt
			if spec.wiperUpdateTimer >= RVB_DELAY.WIPERS_OPERATINGHOURS then
				self:updateWiperOperatingHours(spec.wiperUpdateTimer, spec)
				spec.wiperUpdateTimer = 0
			end
			self:raiseActive()
		end
	end
end
function VehicleBreakdowns:updateWiperOperatingHours(msDelta, spec)
	local runtimeIncrease = msDelta * g_currentMission.missionInfo.timeScale / MS_PER_GAME_HOUR
	local part = spec.parts[WIPERS]
	if part == nil then return end
	local maxLifetime = PartManager.getMaxPartLifetime(self, WIPERS)
	part.operatingHours = math.min(part.operatingHours + runtimeIncrease, maxLifetime)
	self:raiseDirtyFlags(spec.partsDirtyFlag)
end



function VehicleBreakdowns:openHoodForWorkshop(open)
	local rvb = self.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then
        return
    end
	
    local specAV = self.spec_animatedVehicle
    if specAV == nil or specAV.animations == nil then
        return
    end

    -- Választható animációk listája ami biztos capotIC CapotIC Capot
    local hoodAnims = { "capotIC", "CapotIC", "capot", "Capot", "motore", "hood", "Hood", "kapot", "Kapot", "Kapot_OLD", "Kapot_NEW" }
    local anim
    for _, name in ipairs(hoodAnims) do
        if specAV.animations[name] ~= nil then
            anim = name
            break
        end
    end
    if anim == nil then return end

    local currentTime = self:getAnimationTime(anim)
    local isPlaying = self:getIsAnimationPlaying(anim)

	if open then
		if not g_gui:getIsGuiVisible() then
			if not isPlaying then
				if currentTime <= 0 then
					self:playAnimation(anim, 1, 0)
				end
			end
		end
	else
		if not isPlaying then
			if currentTime >= 1 then
				self:playAnimation(anim, -1, 1)
			end
		end
	end

end

	
function VehicleBreakdowns:startInspection(farmId)
	WorkshopInspection.start(self, farmId)
end
function VehicleBreakdowns:updateInspection(dt)
	WorkshopInspection.update(self, dt)
end
function VehicleBreakdowns:finishInspection(spec)
	WorkshopInspection.finish(self, spec)
end
function VehicleBreakdowns:SyncClientServer_RVBInspection(inspection, message)
	WorkshopInspection.SyncClientServer(self, inspection, message)
end

function VehicleBreakdowns:startService(farmId)
    WorkshopService.start(self, farmId)
end
function VehicleBreakdowns:updateService(dt)
	WorkshopService.update(self, dt)
end
function VehicleBreakdowns:finishService(spec, manualDesc_more)
	WorkshopService.finish(self, spec, manualDesc_more)
end
function VehicleBreakdowns:SyncClientServer_RVBService(service, message)
	WorkshopService.SyncClientServer(self, service, message)
end

function VehicleBreakdowns:startRepair(farmId)
	WorkshopRepair.start(self, farmId)
end
function VehicleBreakdowns:updateRepair(dt)
	WorkshopRepair.update(self, dt)
end
function VehicleBreakdowns:finishRepair(spec, manualDesc_more)
    WorkshopRepair.finish(self, spec, manualDesc_more)
end
function VehicleBreakdowns:SyncClientServer_RVBRepair(repair, message)
	WorkshopRepair.SyncClientServer(self, repair, message)
end


--[[
	Motor hűtőfolyadék hőmérséklet csökkentése
	Ha a motor nem jár
	Ha a motor hőmérséklete nagyobb, mint az aktuális időjárási hőmérséklet
]]
function VehicleBreakdowns:updateEngineCooling(dt)
	local specMotorized = self.spec_motorized
	if specMotorized == nil or specMotorized.motorTemperature == nil then
		return
	end
	local rvb = self.spec_faultData
	rvb.EngineCoolingUpdateTimer = (rvb.EngineCoolingUpdateTimer or 0) + dt
	if rvb.EngineCoolingUpdateTimer < RVB_DELAY.MOTORTEMPERATURE then return end
	rvb.EngineCoolingUpdateTimer = 0
	if specMotorized.motorTemperature.value > self.currentTemperaturDay then
		local ambientTemp = g_currentMission.environment.weather:getCurrentTemperature()
		local coolingRatePerMinute = (ambientTemp < 0) and 2.5 or 1.8
		-- Ha a motor hőmérséklete 90°C felett van, kezdetben lassabb hűtés (50%)
		local tempDiff = specMotorized.motorTemperature.value - ambientTemp
		-- Ha a külső hőmérséklet magasabb, akkor a hűtés lassuljon
		local coolingFactor = math.max(0.5, 1 - (tempDiff / 100))
		-- Hűtés skálázása a játékidőhöz
		local coolingRatePerSecond = coolingRatePerMinute / 60  -- fok/másodperc
		-- Csökkentjük a hőmérsékletet a dt és a g_currentMission.missionInfo.timeScale figyelembevételével
		specMotorized.motorTemperature.value = specMotorized.motorTemperature.value - (coolingRatePerSecond * (dt / 1000) * g_currentMission.missionInfo.timeScale * coolingFactor)
	end
end





















function VehicleBreakdowns:addBreakdown(partKey, fault, pre)
    local spec = self.spec_faultData
    if not spec then return end
	local part = spec.parts[partKey]
	local faultData = FaultRegistry[partKey]
	if part and faultData then
		if pre then
			part.prefault = fault
		else
			part.fault = fault
			part.repairreq = true
		end
	end
end

function VehicleBreakdowns:delBreakdown(partKey, pre)
    local spec = self.spec_faultData
    if not spec then return end
	local part = spec.parts[partKey]
	local faultData = FaultRegistry[partKey]
	if part and faultData then
		if pre then
			part.prefault = "empty"
		else
			part.fault = "empty"
			part.repairreq = false
		end
		part.pre_random = math.random(3,6)
		
		if self.isServer then
			resetEngineTorque(self)
		end
		if self.isClient then
			self:updateExhaustEffect()
		end
	end
end


VehicleBreakdowns.ConsoleCommands = {}

-- A függvény a console parancsból közvetlenül kapja az argumentumokat
function VehicleBreakdowns.ConsoleCommands:addBreakdown(partKey, fault, pre)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Error: no vehicle selected!")
        return 
    end

	if vehicle.spec_faultData and not vehicle.spec_faultData.isrvbSpecEnabled then
		vehicle.rvbDebugger:info("'rvb_addPreBreakdown' function is not enabled for this %s", vehicle:getFullName())
		return
	end
	
    if not partKey or not fault then
        print("[RVB] Error: partKey or fault is not specified!")
        return
    end

    partKey = string.upper(partKey)
    pre = pre and pre:lower() == "yes" or false
    
    vehicle:addBreakdown(partKey, fault, pre)
    print(string.format("RVB: Added breakdown '%s' at fault '%s' at pre '%s' to '%s'.", partKey, fault, tostring(pre), vehicle:getFullName()))
end

-- rvb_addPreBreakdown engine misfire yes
-- rvb_addPreBreakdown engine lowOilPressure yes
-- rvb_addPreBreakdown engine headGasketFailure yes
-- rvb_addPreBreakdown engine overheating yes
-- rvb_addPreBreakdown engine mechanicalWear yes
-- rvb_addPreBreakdown engine sensorFault yes
-- rvb_addPreBreakdown engine completeFailure yes
-- rvb_addPreBreakdown termostat stuckClosed yes
-- rvb_addPreBreakdown selfstarter connectorIssue yes
addConsoleCommand("rvb_addPreBreakdown", "Adds a breakdown. Usage: rvb_addPreBreakdown partname fault pre", "addBreakdown", VehicleBreakdowns.ConsoleCommands)

function VehicleBreakdowns.ConsoleCommands:delBreakdown(partKey, pre)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Error: no vehicle selected!")
        return 
    end
	if vehicle.spec_faultData and not vehicle.spec_faultData.isrvbSpecEnabled then
		vehicle.rvbDebugger:info("'rvb_delPreBreakdown' function is not enabled for this %s", vehicle:getFullName())
		return
	end
    if not partKey then
        print("[RVB] Error: partKey is not specified!")
        return
    end

    partKey = string.upper(partKey)
    pre = pre and pre:lower() == "yes" or false
    
    vehicle:delBreakdown(partKey, pre)
    print(string.format("RVB: Deleted breakdown '%s' at pre '%s' to '%s'.", partKey, tostring(pre), vehicle:getFullName()))
end

addConsoleCommand("rvb_delPreBreakdown", "Delete a breakdown. Usage: rvb_delPreBreakdown partname pre", "delBreakdown", VehicleBreakdowns.ConsoleCommands)

--[[function VehicleBreakdowns.ConsoleCommands:vehicleDebug(mode)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Hiba: nincs jármű kiválasztva!")
        return 
    end
    if vehicle.spec_faultData then
        local enableDebug = false
print(type(mode)) 
        if tostring(mode) == "true" or mode == "1" then
            enableDebug = true
        end

        vehicle.spec_faultData.vehicleDebugEnabled = enableDebug
        print("[RVB] Debug: " .. tostring(enableDebug))
    end
end]]

function VehicleBreakdowns.ConsoleCommands:vehicleDebug(mode)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Error: no vehicle selected!")
        return 
    end
    if vehicle.spec_faultData then
		if not vehicle.spec_faultData.isrvbSpecEnabled then
			vehicle.rvbDebugger:info("'rvb_VehicleDebug' function is not enabled for this %s", vehicle:getFullName())
			return
		end
        -- Ha nincs paraméter megadva → toggle
        if mode == nil then
            vehicle.spec_faultData.vehicleDebugEnabled = not vehicle.spec_faultData.vehicleDebugEnabled
            print("[RVB] Debug toggled: " .. tostring(vehicle.spec_faultData.vehicleDebugEnabled))
            return
        end
    end
end

addConsoleCommand("rvb_VehicleDebug", "Toggles the vehicle debug values rendering. Usage: rvb_VehicleDebug", "vehicleDebug", VehicleBreakdowns.ConsoleCommands)

function VehicleBreakdowns.ConsoleCommands:trieUseRVB(trieId, value)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Error: no vehicle selected!")
        return 
    end
    local rvb = vehicle.spec_faultData
	if not rvb then return end
	local part = rvb.parts[WHEELTOPART[tonumber(trieId)]]
	if not part then return end
	local RVBMain = g_currentMission.vehicleBreakdowns
	local n = tonumber(value) or 0
	local use = math.min(math.max(n, 0), RVBMain:getTireLifetime())
	part.operatingHours = use * 1000
	print(string.format("[RVB] %s set to: %d (%.0f km)", WHEELTOPART[tonumber(trieId)], use, (part.operatingHours / 1000)))
end
--addConsoleCommand("rvb_trieUse", "Usage: rvb_trieUse 1-4 value(etc. 340)", "trieUseRVB", VehicleBreakdowns.ConsoleCommands)

function VehicleBreakdowns.ConsoleCommands:trieUse(trieId, value)
    local vehicle = g_localPlayer:getCurrentVehicle() 
    if not vehicle then 
        print("[RVB] Error: no vehicle selected!")
        return 
    end
    local rvb = vehicle.spec_faultData
	if not rvb or not rvb.isrvbSpecEnabled then
		vehicle.rvbDebugger:info("'rvb_trieUse' function is not enabled for this %s", vehicle:getFullName())
		return
	end
	if vehicle.spec_wheels ~= nil then
	for wheelIdx, wheel in ipairs(vehicle.spec_wheels.wheels) do
		if wheelIdx == tonumber(trieId) then
			local RVBMain = g_currentMission.vehicleBreakdowns
			local n = tonumber(value) or 0
			local use = math.min(math.max(n, 0), RVBMain:getTireLifetime())
			wheel.uytTravelledDist = use * 1000
			print(string.format("[RVB] %s set to: %d (%.0f km)", tonumber(trieId), use, (wheel.uytTravelledDist / 1000)))
		end
	end
	end
end
if g_modIsLoaded["FS25_useYourTyres"] then
	addConsoleCommand("rvb_trieUse", "Usage: rvb_trieUse 1-4 value(etc. 340)", "trieUse", VehicleBreakdowns.ConsoleCommands)
end



-- recursive search through all attached vehicles including rootVehicle
-- usage: call getIndexOfActiveImplement(rootVehicle)
local function getIndexOfActiveImplement(rootVehicle, level)
	
	local level = level or 1
	local returnVal = 0
	local returnSign = 1
	
	if rootVehicle ~= nil and not rootVehicle:getIsActiveForInput() and rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil and rootVehicle.steeringAxleNode ~= nil then
	
		for _,impl in pairs(rootVehicle.spec_attacherJoints.attachedImplements) do
			
			-- called from rootVehicle
			if level == 1 then
				local jointDescIndex = impl.jointDescIndex
				local jointDesc = rootVehicle.spec_attacherJoints.attacherJoints[jointDescIndex]
				local wx, wy, wz = getWorldTranslation(jointDesc.jointTransform)
				local _, _, lz = worldToLocal(rootVehicle.steeringAxleNode, wx, wy, wz)
				if lz > 0 then 
					returnSign = 1
				else 
					returnSign = -1
				end 
			end
			
			if impl.object:getIsActiveForInput() then
				returnVal = level
			else
				returnVal = getIndexOfActiveImplement(impl.object, level+1)
			end
			-- found active implement? --> exit recursion
			if returnVal ~= 0 then break end
		
		end		
	end

	return returnVal * returnSign
end

function VehicleBreakdowns:DashboardLive_onUpdate(superFunc, dt)
	local spec = self.spec_DashboardLive
	local specDis = self.spec_dischargeable
	local dspec = self.spec_dashboard
	local mspec = self.spec_motorized
	
	
	-- get active vehicle
	if self:getIsActiveForInput(true) then
		spec.selectorActive = getIndexOfActiveImplement(self:getRootVehicle())
		spec.selectorGroup = self.currentSelection.subIndex or 0
	end
	

	
	-- sync server to client data
	if self.isServer then
		local setDirty = false
		
		-- sync currentDischargeState with server
		if specDis ~= nil then
			spec.currentDischargeState = specDis.currentDischargeState
			if spec.currentDischargeState ~= spec.lastDischargeState then
				spec.lastDischargeState = spec.currentDischargeState
				setDirty = true
			end
		end
	
		-- sync motor temperature
		--[[if self.getIsMotorStarted ~= nil and self:getIsMotorStarted() then
			spec.motorTemperature = mspec.motorTemperature.value
			spec.fanEnabled = mspec.motorFan.enabled
			spec.lastFuelUsage = mspec.lastFuelUsage
			spec.lastDefUsage = mspec.lastDefUsage
			spec.lastAirUsage = mspec.lastAirUsage
			
			if spec.motorTemperature ~= self.spec_motorized.motorTemperature.valueSend then
				setDirty = true
			end
			
			if spec.fanEnabled ~= spec.fanEnabledLast then
				spec.fanEnabledLast = spec.fanEnabled
				setDirty = true
			end
			
		end]]
		if setDirty then
			self:raiseDirtyFlags(spec.dirtyFlag)
		end
	end
		
	-- sync client from server data
	if self.isClient and not self.isServer then
	
		-- sync motor data
		--[[if self.getIsMotorStarted ~= nil and self:getIsMotorStarted() then
			mspec.motorTemperature.value = spec.motorTemperature
			mspec.motorFan.enabled = spec.fanEnabled
			mspec.lastFuelUsage = spec.lastFuelUsage
			mspec.lastDefUsage = spec.lastDefUsage
			mspec.lastAirUsage = spec.lastAirUsage
		end]]
		
		-- sync currentDischargeState from server
		if specDis ~= nil then
			specDis.currentDischargeState = spec.currentDischargeState
		end
	end
		
	-- switch light/dark mode
	if spec.isDirty then
	
		-- force update of all dashboards
		self:updateDashboards(dspec.groupDashboards, dt, true)
		self:updateDashboards(dspec.tickDashboards, dt, true)
		self:updateDashboards(dspec.criticalDashboards, dt, true)
		for _, dashboards in pairs(dspec.dashboardsByValueType) do
			self:updateDashboards(dashboards, dt, true)
		end
	
		spec.isDirty = false
		spec.darkModeLast = spec.darkMode
	end
end
if g_modIsLoaded["FS25_DashboardLive"] then
	FS25_DashboardLive.DashboardLive.onUpdate = Utils.overwrittenFunction(FS25_DashboardLive.DashboardLive.onUpdate, VehicleBreakdowns.DashboardLive_onUpdate)
end