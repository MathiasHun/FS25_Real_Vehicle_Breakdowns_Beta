source(g_vehicleBreakdownsDirectory .. "scripts/events/RVBGamePSettings_Event.lua")

RVBMain = {}
local RVBMain_mt = Class(RVBMain)

RVBMain.ModSettingsDirectory = g_currentModSettingsDirectory

RVBMain.alertmessage = true
RVBMain.vhuddisplay = false
RVBMain.showtempdisplay = false
RVBMain.showrpmdisplay = false
RVBMain.showfueldisplay = false
RVBMain.showdebugisplay = false
RVBMain.showmotorloaddisplay = false
RVBMain.dailyServiceInterval = 2
RVBMain.periodicServiceInterval = 40
RVBMain.workshopTime = true
RVBMain.workshopOpen = 7
RVBMain.workshopClose = 21
RVBMain.workshopCountMax = 2
RVBMain.cp_notice = false

RVBMain.difficulty = 2
RVBMain.thermostatLifetime = 150
RVBMain.lightingsLifetime = 220
RVBMain.glowplugLifetime = 2
RVBMain.wipersLifetime = 80
RVBMain.generatorLifetime = 180
RVBMain.engineLifetime = 210
RVBMain.selfstarterLifetime = 3
RVBMain.batteryLifetime = 140
RVBMain.tireLifetime = 340

RVBMain.DEFAULT_SETTINGS = {
	alertmessage = RVBMain.alertmessage,
	vhuddisplay = RVBMain.vhuddisplay,
	showtempdisplay = RVBMain.showtempdisplay,
	showrpmdisplay = RVBMain.showrpmdisplay,
	showfueldisplay = RVBMain.showfueldisplay,
	showdebugisplay = RVBMain.showdebugisplay,
	showmotorloaddisplay = RVBMain.showmotorloaddisplay,
	dailyServiceInterval = RVBMain.dailyServiceInterval,
	periodicServiceInterval = RVBMain.periodicServiceInterval,
	workshopTime = RVBMain.workshopTime,
	workshopOpen = RVBMain.workshopOpen,
	workshopClose = RVBMain.workshopClose,
	workshopCountMax = RVBMain.workshopCountMax,
	cp_notice = RVBMain.cp_notice,
	difficulty = RVBMain.difficulty,
	thermostatLifetime = RVBMain.thermostatLifetime,
	lightingsLifetime = RVBMain.lightingsLifetime,
	glowplugLifetime = RVBMain.glowplugLifetime,
	wipersLifetime = RVBMain.wipersLifetime,
	generatorLifetime = RVBMain.generatorLifetime,
	engineLifetime = RVBMain.engineLifetime,
	selfstarterLifetime = RVBMain.selfstarterLifetime,
	batteryLifetime = RVBMain.batteryLifetime,
	tireLifetime = RVBMain.tireLifetime
}

local popupMessage

function RVBMain:new(modDirectory, modName)
	local self = {}
	setmetatable(self, RVBMain_mt)
	self.modDirectory = modDirectory
	self.modName = modName
	self.gameplaySettings = {}
	self.generalSettings = {}
	self.actionEvents = {}
		
	self.workshopCount = 0
    self.workshopVehicles = {}

	return self
end

function RVBMain:onMissionLoaded(mission)

	self.rvbDebugger = RVBDebug.new(self.generalSettings)
	
	self:registerGamePlaySettingsSchema()
	self:registerGeneralSettingsSchema()

	self.mission = mission
	
	-- game play settings
	local DEFAUL_GAMEPLAY_SETTINGS_XML = Utils.getFilename("config/DefaultGamePlaySettings.xml", self.modDirectory)
	
	local savegameFolderPath = self.mission.missionInfo.savegameDirectory
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), math.floor(self.mission.missionInfo.savegameIndex))
	end
	
	local GAMEPLAY_SETTINGS_XML = Utils.getFilename("/RVBGamePlaySettings.xml", savegameFolderPath)
	if fileExists(GAMEPLAY_SETTINGS_XML) then
		self:loadGamePlaySettingsFromXml(GAMEPLAY_SETTINGS_XML)
	else
		copyFile(DEFAUL_GAMEPLAY_SETTINGS_XML, GAMEPLAY_SETTINGS_XML, false)
		self:resetGamePlaySettings()
	end
	
	-- general settings
	createFolder(RVBMain.ModSettingsDirectory)
	local GENERAL_SETTINGS_XML = Utils.getFilename("RVBGeneralSettings.xml", RVBMain.ModSettingsDirectory)
	local DEFAUL_GENERAL_SETTINGS_XML = Utils.getFilename("config/DefaultGeneralSettings.xml", self.modDirectory)
	if fileExists(GENERAL_SETTINGS_XML) then
		self:loadGeneralSettingsFromXml(GENERAL_SETTINGS_XML)
	else
		copyFile(DEFAUL_GENERAL_SETTINGS_XML, GENERAL_SETTINGS_XML, false)
		self:resetGeneralSettings()
	end

	-- hud
	RVBMain.rvbHud = RVB_HUD.new()
    RVBMain.rvbHud:setScale(g_gameSettings:getValue(GameSettings.SETTING.UI_SCALE))
	RVBMain.rvbHud:setVehicle(nil)
	table.insert(mission.hud.displayComponents, RVBMain.rvbHud)
	mission.hud.setControlledVehicle = Utils.appendedFunction(mission.hud.setControlledVehicle, function(self, vehicle)
		RVBMain.rvbHud:setVehicle(vehicle)
		RVBMain.rvbHud:setVisible(vehicle ~= nil and vehicle.spec_motorized ~= nil and vehicle.spec_faultData ~= nil, true)
	end)
	mission.hud.update = Utils.appendedFunction(mission.hud.update, function(self, dt)
		RVBMain.rvbHud:update(dt)
	end)
	mission.hud.drawControlledEntityHUD = Utils.appendedFunction(mission.hud.drawControlledEntityHUD, function(self)
		if self.isVisible then
			RVBMain.rvbHud:draw()
		end
	end)

	g_rvbMenu = RVBMenu.register()
	g_rvbMenu:setClient(g_client)
	g_rvbMenu:setServer(g_server)

	local conflictList = {}
	if g_modIsLoaded["FS25_Courseplay"] then
		if FS25_Courseplay ~= nil and FS25_Courseplay.WearableController.autoRepair ~= nil then
			table.insert(conflictList, "CoursePlay")
			FS25_Courseplay.WearableController.autoRepair = Utils.overwrittenFunction(FS25_Courseplay.WearableController.autoRepair, RVBMain.autoRepair)
			print("[RVB] Courseplay autoRepair overwritten by RVB mod")
		end
	end

	if g_modIsLoaded["FS25_AutoDrive"] then
		if FS25_AutoDrive ~= nil and FS25_AutoDrive.ADTaskModule.hasToRepair ~= nil then
			table.insert(conflictList, "AutoDrive")
			FS25_AutoDrive.ADTaskModule.hasToRepair = Utils.overwrittenFunction(FS25_AutoDrive.ADTaskModule.hasToRepair, RVBMain.hasToRepair)
			print("[RVB] AutoDrive hasToRepair overwritten by RVB mod")
		end
	end
	
	if g_modIsLoaded["FS25_DashboardLive"] then
		if FS25_DashboardLive ~= nil and FS25_DashboardLive.DashboardLive.onUpdate ~= nil then
			table.insert(conflictList, "DashboardLive")
			print("[RVB] DashboardLive onUpdate overwritten by RVB mod")
		end
	end

	if #conflictList > 0 then
		popupMessage = {
			startUpdateTime = 2000,
			update = function(self, dt)
				self.startUpdateTime = self.startUpdateTime - dt
				if self.startUpdateTime < 0 and not g_gui:getIsGuiVisible() then
					if g_currentMission.hud ~= nil then
						local message = string.format(g_i18n:getText("Automatic_Repair_conflict_notice"), table.concat(conflictList, ",  "))
						RVBInfoDialog.show(message, nil, nil, DialogElement.TYPE_INFO)
					end
					removeModEventListener(self)
					popupMessage = nil
				end
			end
		}
		if not self.generalSettings.cp_notice then
			addModEventListener(popupMessage)
			self.generalSettings.cp_notice = true
			self:saveGeneralettingsToXML()
		end
	end

	if g_currentMission.missionInfo.automaticMotorStartEnabled then
		g_currentMission:setAutomaticMotorStartEnabled(false, true)
		self.rvbDebugger:info("onMissionLoaded", "The RVB mod has disabled automatic engine start.")
	end

	if g_modIsLoaded["FS25_VehicleExplorer"] then
		if FS25_VehicleExplorer ~= nil and FS25_VehicleExplorer.VehicleSort.getFillLevel ~= nil then
			FS25_VehicleExplorer.VehicleSort.getFillLevel = Utils.overwrittenFunction(FS25_VehicleExplorer.VehicleSort.getFillLevel, RVBMain.VehicleSortgetFillLevel)
		end
	end

end

function RVBMain.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
	specializationManager:addSpecialization("vehicleBreakdowns", "VehicleBreakdowns", Utils.getFilename("scripts/vehicles/specializations/VehicleBreakdowns.lua", modDirectory), nil)
	if specializationManager:getSpecializationByName("vehicleBreakdowns") == nil then
		Logging.error("  [RVB] getSpecializationByName(\"vehicleBreakdowns\") == nil")
	else
		for typeName, typeEntry in pairs(vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil and not RVB_EXCLUDED_TYPES[typeName] then
				if SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations) and
					SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations) and
					SpecializationUtil.hasSpecialization(Motorized, typeEntry.specializations) and
					not SpecializationUtil.hasSpecialization(VehicleBreakdowns, typeEntry.specializations) then
						vehicleTypeManager:addSpecialization(typeName, modName .. ".vehicleBreakdowns")
						Logging.info("  [RVB] Register RVB \'" .. typeName .. "\'")
				end
			else
				Logging.info("  [RVB] No register RVB \'" .. typeName .. "\'")
			end
		end
	end
	
end
function RVBMain:registerGamePlaySettingsSchema()
	self.gameplaySettingSchema = XMLSchema.new("rvbGamePlaySettings")
	local schemaKey = "rvbGamePlaySettings"
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".dailyServiceInterval#value", "Daily Service Interval")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".periodicServiceInterval#value", "Periodic Service Interval")
	self.gameplaySettingSchema:register(XMLValueType.BOOL, schemaKey .. ".workshopTime#value", "")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".workshopOpen#value", "Workshop opening")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".workshopClose#value", "Workshop closing")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".workshopCountMax#value", "Workshop max count")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".difficulty#value", "RVB difficulty")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".thermostatLifetime#value", "Thermostat Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".lightingsLifetime#value", "Lightings Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".glowplugLifetime#value", "Glowplug Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".wipersLifetime#value", "Wipers Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".generatorLifetime#value", "Generator Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".engineLifetime#value", "Engine Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".selfstarterLifetime#value", "Selfstarter Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".batteryLifetime#value", "Battery Lifetime")
	self.gameplaySettingSchema:register(XMLValueType.INT, schemaKey .. ".tireLifetime#value", "Tire Lifetime")
end
function RVBMain:registerGeneralSettingsSchema()
	self.generalSettingSchema = XMLSchema.new("rvbGeneralSettings")
	local schemaKey = "rvbGeneralSettings"
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".alertmessage#value", "Alert Message")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".vhuddisplay#value", "vhuddisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".showtempdisplay#value", "showtempdisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".showrpmdisplay#value", "showrpmdisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".showfueldisplay#value", "showfueldisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".showdebugisplay#value", "showdebugisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".showmotorloaddisplay#value", "showmotorloaddisplay")
	self.generalSettingSchema:register(XMLValueType.BOOL, schemaKey .. ".cp_notice#value", "CP")
end
function RVBMain:loadGamePlaySettingsFromXml(xmlPath)
	local xmlFile = XMLFile.load("configXml", xmlPath, self.gameplaySettingSchema)
	if xmlFile ~= 0 then
		local key = "rvbGamePlaySettings"
		self.gameplaySettings.dailyServiceInterval    = xmlFile:getValue(key .. ".dailyServiceInterval#value", RVBMain.dailyServiceInterval)
		self.gameplaySettings.periodicServiceInterval = xmlFile:getValue(key .. ".periodicServiceInterval#value", RVBMain.periodicServiceInterval)
		self.gameplaySettings.workshopTime            = xmlFile:getValue(key .. ".workshopTime#value", RVBMain.workshopTime)
		self.gameplaySettings.workshopOpen            = xmlFile:getValue(key .. ".workshopOpen#value", RVBMain.workshopOpen)
		self.gameplaySettings.workshopClose           = xmlFile:getValue(key .. ".workshopClose#value", RVBMain.workshopClose)
		self.gameplaySettings.workshopCountMax        = xmlFile:getValue(key .. ".workshopCountMax#value", RVBMain.workshopCountMax)
		self.gameplaySettings.difficulty              = xmlFile:getValue(key .. ".difficulty#value", RVBMain.difficulty)
		self.gameplaySettings.thermostatLifetime      = xmlFile:getValue(key .. ".thermostatLifetime#value", RVBMain.thermostatLifetime)
		self.gameplaySettings.lightingsLifetime       = xmlFile:getValue(key .. ".lightingsLifetime#value", RVBMain.lightingsLifetime)
		self.gameplaySettings.glowplugLifetime        = xmlFile:getValue(key .. ".glowplugLifetime#value", RVBMain.glowplugLifetime)
		self.gameplaySettings.wipersLifetime          = xmlFile:getValue(key .. ".wipersLifetime#value", RVBMain.wipersLifetime)
		self.gameplaySettings.generatorLifetime       = xmlFile:getValue(key .. ".generatorLifetime#value", RVBMain.generatorLifetime)
		self.gameplaySettings.engineLifetime          = xmlFile:getValue(key .. ".engineLifetime#value", RVBMain.engineLifetime)
		self.gameplaySettings.selfstarterLifetime     = xmlFile:getValue(key .. ".selfstarterLifetime#value", RVBMain.selfstarterLifetime)
		self.gameplaySettings.batteryLifetime         = xmlFile:getValue(key .. ".batteryLifetime#value", RVBMain.batteryLifetime)
		self.gameplaySettings.tireLifetime            = xmlFile:getValue(key .. ".tireLifetime#value", RVBMain.tireLifetime)
		xmlFile:delete()
	end
end
function RVBMain:loadGeneralSettingsFromXml(xmlPath)
	local xmlFile = XMLFile.load("configXml", xmlPath, self.generalSettingSchema)
	if xmlFile ~= 0 then
		local key = "rvbGeneralSettings"
		self.generalSettings.alertmessage         = xmlFile:getValue(key .. ".alertmessage#value", RVBMain.alertmessage)
		self.generalSettings.vhuddisplay          = xmlFile:getValue(key .. ".vhuddisplay#value", RVBMain.vhuddisplay)
		self.generalSettings.showtempdisplay      = xmlFile:getValue(key .. ".showtempdisplay#value", RVBMain.showtempdisplay)
		self.generalSettings.showrpmdisplay       = xmlFile:getValue(key .. ".showrpmdisplay#value", RVBMain.showrpmdisplay)
		self.generalSettings.showfueldisplay      = xmlFile:getValue(key .. ".showfueldisplay#value", RVBMain.showfueldisplay)
		self.generalSettings.showdebugisplay      = xmlFile:getValue(key .. ".showdebugisplay#value", RVBMain.showdebugisplay)
		self.generalSettings.showmotorloaddisplay = xmlFile:getValue(key .. ".showmotorloaddisplay#value", RVBMain.showmotorloaddisplay)
		self.generalSettings.cp_notice            = xmlFile:getValue(key .. ".cp_notice#value", RVBMain.cp_notice)
		xmlFile:delete()
	end
end
function RVBMain:resetGamePlaySettings()
	self.gameplaySettings = {
		dailyServiceInterval = RVBMain.DEFAULT_SETTINGS.dailyServiceInterval,
		periodicServiceInterval = RVBMain.DEFAULT_SETTINGS.periodicServiceInterval,
		workshopTime = RVBMain.DEFAULT_SETTINGS.workshopTime,
		workshopOpen = RVBMain.DEFAULT_SETTINGS.workshopOpen,
		workshopClose = RVBMain.DEFAULT_SETTINGS.workshopClose,
		workshopCountMax = RVBMain.DEFAULT_SETTINGS.workshopCountMax,
		difficulty = RVBMain.DEFAULT_SETTINGS.difficulty,
		thermostatLifetime = RVBMain.DEFAULT_SETTINGS.thermostatLifetime,
		lightingsLifetime = RVBMain.DEFAULT_SETTINGS.lightingsLifetime,
		glowplugLifetime = RVBMain.DEFAULT_SETTINGS.glowplugLifetime,
		wipersLifetime = RVBMain.DEFAULT_SETTINGS.wipersLifetime,
		generatorLifetime = RVBMain.DEFAULT_SETTINGS.generatorLifetime,
		engineLifetime = RVBMain.DEFAULT_SETTINGS.engineLifetime,
		selfstarterLifetime = RVBMain.DEFAULT_SETTINGS.selfstarterLifetime,
		batteryLifetime = RVBMain.DEFAULT_SETTINGS.batteryLifetime,
		tireLifetime = RVBMain.DEFAULT_SETTINGS.tireLifetime
	}
end
function RVBMain:resetGeneralSettings()
	self.generalSettings = {
		alertmessage = RVBMain.DEFAULT_SETTINGS.alertmessage,
		vhuddisplay = RVBMain.DEFAULT_SETTINGS.vhuddisplay,
		showtempdisplay = RVBMain.DEFAULT_SETTINGS.showtempdisplay,
		showrpmdisplay = RVBMain.DEFAULT_SETTINGS.showrpmdisplay,
		showfueldisplay = RVBMain.DEFAULT_SETTINGS.showfueldisplay,
		showdebugisplay = RVBMain.DEFAULT_SETTINGS.showdebugisplay,
		showmotorloaddisplay = RVBMain.DEFAULT_SETTINGS.showmotorloaddisplay,
		cp_notice = RVBMain.DEFAULT_SETTINGS.cp_notice
	}
end
function RVBMain:rvbsaveToXMLFile(RVBXMLFile)
	local schemaKey = "rvbGamePlaySettings"
	local xmlFile = XMLFile.create("RBVGamePlaySettingsXML", RVBXMLFile, "rvbGamePlaySettings", self.gameplaySettingSchema)
	if xmlFile == 0 then
		Logging.info("  [RVB] Failed to create the XML file(RBVGamePlaySettingsXML)!")
        return
    end
	if xmlFile ~= 0 then
		xmlFile:setValue(schemaKey .. ".dailyServiceInterval#value", self.gameplaySettings.dailyServiceInterval)
		xmlFile:setValue(schemaKey .. ".periodicServiceInterval#value", self.gameplaySettings.periodicServiceInterval)
		xmlFile:setValue(schemaKey .. ".workshopTime#value", self.gameplaySettings.workshopTime)
		xmlFile:setValue(schemaKey .. ".workshopOpen#value", self.gameplaySettings.workshopOpen)
		xmlFile:setValue(schemaKey .. ".workshopClose#value", self.gameplaySettings.workshopClose)
		xmlFile:setValue(schemaKey .. ".workshopCountMax#value", self.gameplaySettings.workshopCountMax)
		xmlFile:setValue(schemaKey .. ".difficulty#value", self.gameplaySettings.difficulty)
		xmlFile:setValue(schemaKey .. ".thermostatLifetime#value", self.gameplaySettings.thermostatLifetime)
		xmlFile:setValue(schemaKey .. ".lightingsLifetime#value", self.gameplaySettings.lightingsLifetime)
		xmlFile:setValue(schemaKey .. ".glowplugLifetime#value", self.gameplaySettings.glowplugLifetime)
		xmlFile:setValue(schemaKey .. ".wipersLifetime#value", self.gameplaySettings.wipersLifetime)
		xmlFile:setValue(schemaKey .. ".generatorLifetime#value", self.gameplaySettings.generatorLifetime)
		xmlFile:setValue(schemaKey .. ".engineLifetime#value", self.gameplaySettings.engineLifetime)
		xmlFile:setValue(schemaKey .. ".selfstarterLifetime#value", self.gameplaySettings.selfstarterLifetime)
		xmlFile:setValue(schemaKey .. ".batteryLifetime#value", self.gameplaySettings.batteryLifetime)
		xmlFile:setValue(schemaKey .. ".tireLifetime#value", self.gameplaySettings.tireLifetime)
		xmlFile:save()
		xmlFile:delete()
	end
end
function RVBMain:saveGeneralettingsToXML()
	local GENERAL_SETTINGS_XML = Utils.getFilename("RVBGeneralSettings.xml", RVBMain.ModSettingsDirectory)
	local schemaKey = "rvbGeneralSettings"
	local xmlFile = XMLFile.create("RBVGeneralSettingsXML", GENERAL_SETTINGS_XML, "rvbGeneralSettings", self.generalSettingSchema)
	if xmlFile ~= 0 then
		xmlFile:setValue(schemaKey .. ".alertmessage#value", self.generalSettings.alertmessage)
		xmlFile:setValue(schemaKey .. ".vhuddisplay#value", self.generalSettings.vhuddisplay)
		xmlFile:setValue(schemaKey .. ".showtempdisplay#value", self.generalSettings.showtempdisplay)
		xmlFile:setValue(schemaKey .. ".showrpmdisplay#value", self.generalSettings.showrpmdisplay)
		xmlFile:setValue(schemaKey .. ".showfueldisplay#value", self.generalSettings.showfueldisplay)
		xmlFile:setValue(schemaKey .. ".showdebugisplay#value", self.generalSettings.showdebugisplay)
		xmlFile:setValue(schemaKey .. ".showmotorloaddisplay#value", self.generalSettings.showmotorloaddisplay)
		xmlFile:setValue(schemaKey .. ".cp_notice#value", self.generalSettings.cp_notice)
		xmlFile:save()
		xmlFile:delete()
	end
end

function RVBMain:update()
end
function RVBMain:draw()
end
function RVBMain:delete()
end

function RVBMain:updateGeneralSetting(key, value, displayValue, noEventSend)
    if self.generalSettings[key] ~= value then
        self.generalSettings[key] = value
        self:saveGeneralettingsToXML()
		local logValue = displayValue or tostring(value)
        self.rvbDebugger:info("updateGeneralSetting", "Settings \'%s\': %s", key, logValue)
    end
end
function RVBMain:getIsAlertMessage()
	return self.generalSettings.alertmessage
end
function RVBMain:setIsAlertMessage(alertmessage, noEventSend)
	self:updateGeneralSetting("alertmessage", alertmessage, nil, noEventSend)
end
function RVBMain:getIsVHudDisplay()
	return self.generalSettings.vhuddisplay
end
function RVBMain:setIsVHudDisplay(vhuddisplay, noEventSend)
	self:updateGeneralSetting("vhuddisplay", vhuddisplay, nil, noEventSend)
end
function RVBMain:getIsShowTempDisplay()
	return self.generalSettings.showtempdisplay
end
function RVBMain:setIsShowTempDisplay(showtempdisplay, noEventSend)
	self:updateGeneralSetting("showtempdisplay", showtempdisplay, nil, noEventSend)
end
function RVBMain:getIsShowRpmDisplay()
	return self.generalSettings.showrpmdisplay
end
function RVBMain:setIsShowRpmDisplay(showrpmdisplay, noEventSend)
	self:updateGeneralSetting("showrpmdisplay", showrpmdisplay, nil, noEventSend)
end
function RVBMain:getIsShowFuelDisplay()
	return self.generalSettings.showfueldisplay
end
function RVBMain:setIsShowFuelDisplay(showfueldisplay, noEventSend)
	self:updateGeneralSetting("showfueldisplay", showfueldisplay, nil, noEventSend)
end
function RVBMain:getIsShowDebugDisplay()
	return self.generalSettings.showdebugisplay
end
function RVBMain:setIsShowDebugDisplay(showdebugisplay, noEventSend)
	self:updateGeneralSetting("showdebugisplay", showdebugisplay, nil, noEventSend)
end
function RVBMain:getIsShowMotorLoadDisplay()
	return self.generalSettings.showmotorloaddisplay
end
function RVBMain:setIsShowMotorLoadDisplay(showmotorloaddisplay, noEventSend)
	self:updateGeneralSetting("showmotorloaddisplay", showmotorloaddisplay, nil, noEventSend)
end

function RVBMain:setIsCPNotice(cpnotice)
	self.generalSettings.cp_notice = cpnotice
end

function RVBMain:updateGameplaySetting(key, value, part, noEventSend)
	local old = self.gameplaySettings[key]
    if self.gameplaySettings[key] ~= value then
        self.gameplaySettings[key] = value
        RVBGamePSettings_Event.sendEvent(self.gameplaySettings, noEventSend)
		if part then
			g_messageCenter:publish(MessageType.SET_PARTS_LIFETIME, part, value, old)
		end
		if key == "workshopOpen" or key == "workshopClose" then
			g_messageCenter:publish(MessageType.SET_WORKSHOP_STATE)
		end
		if key == "difficulty" then
			--RVBGenSettingsSync_Event.sendEvent(value)
		end
		self.rvbDebugger:info("updateGameplaySetting", "Settings \'%s\': %s", key, tostring(value))
    end
end
	
function RVBMain:getDailyService()
	return self.gameplaySettings.dailyServiceInterval
end
function RVBMain:setDailyServiceInterval(dailyServiceInterval, noEventSend)
	self:updateGameplaySetting("dailyServiceInterval", dailyServiceInterval, nil, noEventSend)
end
function RVBMain:getPeriodicService()
	return self.gameplaySettings.periodicServiceInterval
end
function RVBMain:setPeriodicServiceInterval(periodicServiceInterval, noEventSend)
	self:updateGameplaySetting("periodicServiceInterval", periodicServiceInterval, nil, noEventSend)
end
function RVBMain:getIsWorkshopTime()
	return self.gameplaySettings.workshopTime
end
function RVBMain:setIsWorkshopTime(workshopTime, noEventSend)
	self:updateGameplaySetting("workshopTime", workshopTime, nil, noEventSend)
end
function RVBMain:getWorkshopOpen()
	return self.gameplaySettings.workshopOpen
end
function RVBMain:setWorkshopOpen(workshopOpen, noEventSend)
	self:updateGameplaySetting("workshopOpen", workshopOpen, nil, noEventSend)
end
function RVBMain:getWorkshopClose()
	return self.gameplaySettings.workshopClose
end
function RVBMain:setWorkshopClose(workshopClose, noEventSend)
	self:updateGameplaySetting("workshopClose", workshopClose, nil, noEventSend)
end
function RVBMain:getWorkshopCountMax()
	return self.gameplaySettings.workshopCountMax
end
function RVBMain:setWorkshopCountMax(workshopCountMax, noEventSend)
	self:updateGameplaySetting("workshopCountMax", workshopCountMax, nil, noEventSend)
end
function RVBMain:getWorkshopCount()
	return self.workshopCount
end
function RVBMain:setWorkshopCount(workshopCount, noEventSend)
	if self.workshopCount ~= workshopCount then
		self.workshopCount = workshopCount
		WorkshopCount_Event.sendEvent(self.workshopCount, noEventSend)
		self.rvbDebugger:info("setWorkshopCount", "\'%s\': %s", "workshopCount", tostring(workshopCount))
	end
end
function RVBMain:getRVBDifficulty()
	return self.gameplaySettings.difficulty
end
function RVBMain:setRVBDifficulty(difficulty, noEventSend)
	local difficultyTable = {
		g_i18n:getText("RVB_difficulty_slow"),
		g_i18n:getText("RVB_difficulty_medium"),
		g_i18n:getText("RVB_difficulty_fast")
	}
	self:updateGameplaySetting("difficulty", difficulty, difficultyTable[difficulty], noEventSend)

	g_messageCenter:publish(MessageType.SET_DIFFICULTY, difficulty)
end
function RVBMain:getPartBaseLifetime(partKey)
	local GPSET = self.gameplaySettings

	if partKey == THERMOSTAT then
		return GPSET.thermostatLifetime
	elseif partKey == LIGHTINGS then
		return GPSET.lightingsLifetime
	elseif partKey == GLOWPLUG then
		return GPSET.glowplugLifetime
	elseif partKey == WIPERS then
		return GPSET.wipersLifetime
	elseif partKey == GENERATOR then
		return GPSET.generatorLifetime
	elseif partKey == ENGINE then
		return GPSET.engineLifetime
	elseif partKey == SELFSTARTER then
		return GPSET.selfstarterLifetime
	elseif partKey == BATTERY then
		return GPSET.batteryLifetime
	elseif partKey == TIREFL or partKey == TIREFR or partKey == TIRERL or partKey == TIRERR then
		return GPSET.tireLifetime
	end

	return 0
end
function RVBMain:getThermostatLifetime()
	return self.gameplaySettings.thermostatLifetime
end
function RVBMain:setThermostatLifetime(thermostat, noEventSend)
	thermostat = math.clamp(thermostat, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("thermostatLifetime", thermostat, "THERMOSTAT", noEventSend)
end
function RVBMain:getLightingsLifetime()
	return self.gameplaySettings.lightingsLifetime
end
function RVBMain:setLightingsLifetime(lightings, noEventSend)
	lightings = math.clamp(lightings, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("lightingsLifetime", lightings, "LIGHTINGS", noEventSend)
end
function RVBMain:getGlowplugLifetime()
	return self.gameplaySettings.glowplugLifetime
end
function RVBMain:setGlowplugLifetime(glowplug, noEventSend)
	glowplug = math.clamp(glowplug, rvb_Utils.SmallArrayMin, rvb_Utils.SmallArrayMax)
	self:updateGameplaySetting("glowplugLifetime", glowplug, "GLOWPLUG", noEventSend)
end
function RVBMain:getWipersLifetime()
	return self.gameplaySettings.wipersLifetime
end
function RVBMain:setWipersLifetime(wipers, noEventSend)
	wipers = math.clamp(wipers, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("wipersLifetime", wipers, "WIPERS", noEventSend)
end
function RVBMain:getGeneratorLifetime()
	return self.gameplaySettings.generatorLifetime
end
function RVBMain:setGeneratorLifetime(generator, noEventSend)
	generator = math.clamp(generator, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("generatorLifetime", generator, "GENERATOR", noEventSend)
end
function RVBMain:getEngineLifetime()
	return self.gameplaySettings.engineLifetime
end
function RVBMain:setEngineLifetime(engine, noEventSend)
	engine = math.clamp(engine, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("engineLifetime", engine, "ENGINE", noEventSend)
end
function RVBMain:getSelfstarterLifetime()
	return self.gameplaySettings.selfstarterLifetime
end
function RVBMain:setSelfstarterLifetime(selfstarter, noEventSend)
	selfstarter = math.clamp(selfstarter, rvb_Utils.SmallArrayMin, rvb_Utils.SmallArrayMax)
	self:updateGameplaySetting("selfstarterLifetime", selfstarter, "SELFSTARTER", noEventSend)
end
function RVBMain:getBatteryLifetime()
	return self.gameplaySettings.batteryLifetime
end
function RVBMain:setBatteryLifetime(battery, noEventSend)
	battery = math.clamp(battery, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	self:updateGameplaySetting("batteryLifetime", battery, "BATTERY", noEventSend)
end
function RVBMain:getTireLifetime()
	return self.gameplaySettings.tireLifetime
end
function RVBMain:setTireLifetime(tire, noEventSend)
	tire = math.clamp(tire, rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax)
	-- TIRES = "TIREFL", "TIREFR", "TIRERL", "TIRERR"
	self:updateGameplaySetting("tireLifetime", tire, "TIRES", noEventSend)
end
function RVBMain:isAlwaysOpenWorkshop()
	if g_workshopScreen ~= nil then
		if g_workshopScreen.isMobileWorkshop then
			return true
		end
		if g_workshopScreen.isOwnWorkshop then
			return true
		end
	end
	return false
end
function RVBMain.getWorkshopStatusMessage(self)
	if not self:getIsWorkshopTime() then
		return true, ""
	end
	if self:isAlwaysOpenWorkshop() then
		return true, ""
	end
	local openHour, closeHour = self:getWorkshopOpen(), self:getWorkshopClose()
	local currentHour = g_currentMission.environment.currentHour
	local workshopStatus = currentHour >= openHour and currentHour < closeHour
	local timeInfo = workshopStatus and "" or string.format(
		g_i18n:getText("RVB_WorkShopClose"), 
		string.format("%02d:%02d", openHour, 0)
	)
	return workshopStatus, timeInfo
end

function RVBMain:onWriteStream(streamId, connection)
	local s = self.gameplaySettings
	streamWriteInt32(streamId, s.dailyServiceInterval)
	streamWriteInt32(streamId, s.periodicServiceInterval)
	streamWriteBool(streamId, s.workshopTime)
	streamWriteInt32(streamId, s.workshopOpen)
	streamWriteInt32(streamId, s.workshopClose)
	streamWriteInt32(streamId, s.workshopCountMax)
	streamWriteInt32(streamId, s.difficulty)
	streamWriteInt32(streamId, s.thermostatLifetime)
	streamWriteInt32(streamId, s.lightingsLifetime)
	streamWriteInt32(streamId, s.glowplugLifetime)
	streamWriteInt32(streamId, s.wipersLifetime)
	streamWriteInt32(streamId, s.generatorLifetime)
	streamWriteInt32(streamId, s.engineLifetime)
	streamWriteInt32(streamId, s.selfstarterLifetime)
	streamWriteInt32(streamId, s.batteryLifetime)
	streamWriteInt32(streamId, s.tireLifetime)
	streamWriteInt16(streamId, self.workshopCount)
end
function RVBMain:onReadStream(streamId, connection)
	self.gameplaySettings = {}
	local s = self.gameplaySettings
	s.dailyServiceInterval = streamReadInt32(streamId)
	s.periodicServiceInterval = streamReadInt32(streamId)
	s.workshopTime = streamReadBool(streamId)
	s.workshopOpen = streamReadInt32(streamId)
	s.workshopClose = streamReadInt32(streamId)
	s.workshopCountMax = streamReadInt32(streamId)
	s.difficulty = streamReadInt32(streamId)
	s.thermostatLifetime = streamReadInt32(streamId)
	s.lightingsLifetime = streamReadInt32(streamId)
	s.glowplugLifetime = streamReadInt32(streamId)
	s.wipersLifetime = streamReadInt32(streamId)
	s.generatorLifetime = streamReadInt32(streamId)
	s.engineLifetime = streamReadInt32(streamId)
	s.selfstarterLifetime = streamReadInt32(streamId)
	s.batteryLifetime = streamReadInt32(streamId)
	s.tireLifetime = streamReadInt32(streamId)
	self.workshopCount = streamReadInt16(streamId)
end

-- Original CP WearableController:autoRepair()
function RVBMain:autoRepair(superFunc)
	--if self:isBrokenGreaterThan(100-self.autoRepairSetting:getValue()) then 
	--	self.implement:repairVehicle()
	--end
	--print("RVBMain:autoRepair")
end
-- Original AD ADTaskModule hasToRepair()
function RVBMain:hasToRepair()
	local repairNeeded = false
--	if self.vehicle.ad.onRouteToRepair then
--		repair is forced by user or CP, so send vehicle to workshop independent of damage level
--		return true
--	end
--	if AutoDrive.getSetting("autoRepair", self.vehicle) then
--		local attachedObjects = AutoDrive.getAllImplements(self.vehicle, true)
--		for _, attachedObject in pairs(attachedObjects) do
--			repairNeeded = repairNeeded or (attachedObject.spec_wearable ~= nil and attachedObject.spec_wearable.damage > 0.6)
--		end
--	end
	--print("RVBMain:hasToRepair")
	return repairNeeded
end
-- Original FS25_VehicleExplorer VehicleSort:getFillLevel()
function RVBMain:VehicleSortgetFillLevel(superFunc, obj)
	local fillLevel = 0
	local cap = 0
	local fillType = ""
	if obj.getFillUnits ~= nil then
		for _, fillUnit in ipairs(obj:getFillUnits()) do
			if (fillUnit.fillType ~= g_fillTypeManager.nameToFillType.DEF.index) and (fillUnit.fillType ~= g_fillTypeManager.nameToFillType.DIESEL.index)
			and (fillUnit.fillType ~= g_fillTypeManager.nameToFillType.AIR.index) and (fillUnit.fillType ~= g_fillTypeManager.nameToFillType.BATTERYCHARGE.index) then
				fillLevel = fillUnit.fillLevel
				cap = fillUnit.capacity
				fillType = g_fillTypeManager.fillTypes[fillUnit.fillType].title
			end
		end
	end
	return fillLevel, cap, fillType
end
