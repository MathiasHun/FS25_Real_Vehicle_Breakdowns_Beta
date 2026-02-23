
local directory = g_currentModDirectory
local modName = g_currentModName
g_vehicleBreakdownsModName = modName
g_vehicleBreakdownsDirectory = directory
g_resetVehiclesRVB = {}
g_rvbPlayer = nil
g_rvbMain = nil
g_rvbGameplaySettings = nil
g_rvbGeneralSettings = nil
g_maxLifetimeCache = {}

local sourceFiles = {
	-- Config
	"scripts/rvbConfig.lua",
	-- ENUMS
	"scripts/enums/JumperCableState.lua",
	--
	"scripts/RVBMain.lua",
	-- Gui 
	"scripts/gui/RVBMenu.lua",
	"scripts/gui/RVBMenuSettingsFrame.lua",
	"scripts/gui/RVBMenuPartsSettingsFrame.lua",
	-- Dialogs
	"scripts/gui/dialogs/RVBInfoDialog.lua",
	"scripts/gui/dialogs/rvbWorkshopDialog.lua",
	-- Events
	"scripts/events/RVBGenSettingsSync_Event.lua",
	-- HUD
	"scripts/hud/RVB_HUD.lua",
	-- UTILS
	"scripts/utils/rvb_Utils.lua",
	-- AIMessage
	"scripts/ai/errors/AIMessageErrorBatteryDischarged.lua",
	-- PLAYER ACTION
	"scripts/player/RVBPlayer.lua",
}
for i = 1, #sourceFiles do
    source(Utils.getFilename(sourceFiles[i], directory))
end

g_gui:loadProfiles(directory .. "menu/guiProfiles.xml")

local vehicleBreakdowns
local function isEnabled()
	return vehicleBreakdowns ~= nil
end
function init()
	g_rvbPlayer = RVBPlayer.register()
	FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
	Mission00.load = Utils.prependedFunction(Mission00.load, loadMission)
	Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
	FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, rvbgamePlaySetsaveToXMLFile)
	SavegameSettingsEvent.readStream = Utils.appendedFunction(SavegameSettingsEvent.readStream, readStream)
	SavegameSettingsEvent.writeStream = Utils.appendedFunction(SavegameSettingsEvent.writeStream, writeStream)
	FillTypeManager.loadMapData = Utils.appendedFunction(FillTypeManager.loadMapData, loadBatteryType)
	TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, validateVehicleTypes)

	Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
		print("[RVB] Hooked into FSBaseMission:setPlannedDaysPerPeriod")
	end)

	MessageType.RVB_RESET_VEHICLE = nextMessageTypeId()
    MessageType.RVB_VEHICLE_RESET = nextMessageTypeId()
	MessageType.RVB_START_SERVICE = nextMessageTypeId()
	MessageType.SET_PARTS_LIFETIME = nextMessageTypeId()
	MessageType.SET_WORKSHOP_STATE = nextMessageTypeId()
	MessageType.SET_DIFFICULTY = nextMessageTypeId()
	MessageType.SET_DAYSPERPERIOD = nextMessageTypeId()
	MessageType.RVB_PROGRESS_MESSAGE = nextMessageTypeId()
	MessageType.RVB_JUMPERCABLE_MESSAGE = nextMessageTypeId()
	MessageType.RVB_BLINKINGMESSAGE = nextMessageTypeId()

	vehicleBreakdowns = RVBMain:new(directory, modName)
	RVBInfoDialog.register()
	rvbWorkshopDialog.register()
end
function loadMission(mission)
	mission.vehicleBreakdowns = vehicleBreakdowns
	addModEventListener(vehicleBreakdowns)
end
function loadedMission(mission, node)
	if not isEnabled() then
		print("Error: vehicleBreakdowns is nil, not enabled")
		return
	end
	if mission.cancelLoading then
		return
	end
	vehicleBreakdowns:onMissionLoaded(mission)
	g_rvbMain = vehicleBreakdowns
	g_rvbGameplaySettings = mission.vehicleBreakdowns.gameplaySettings
	g_rvbGeneralSettings = mission.vehicleBreakdowns.generalSettings
end
function rvbgamePlaySetsaveToXMLFile(missionInfo)
	if isEnabled() and missionInfo.isValid then
		local savegameFolderPath = missionInfo.savegameDirectory 
		if savegameFolderPath == nil then
			savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), missionInfo.savegameIndex)
		end
		local GAMEPLAY_SETTINGS_XML = Utils.getFilename("/RVBGamePlaySettings.xml", savegameFolderPath)
		vehicleBreakdowns:rvbsaveToXMLFile(GAMEPLAY_SETTINGS_XML)
	end
end
function validateVehicleTypes(typeManager)
	if typeManager.typeName == "vehicle" then
		RVBMain.installSpecializations(g_vehicleTypeManager, g_specializationManager, directory, modName)
	end
end
function registerActionEvents()
	vehicleBreakdowns:registerActionEvents()
end
function unregisterActionEvents()
	vehicleBreakdowns:unregisterActionEvents()
end
function unload()
	if not isEnabled() then
		return
	end
	removeModEventListener(vehicleBreakdowns)
	vehicleBreakdowns:delete()
	vehicleBreakdowns = nil
	if g_currentMission ~= nil then
		g_currentMission.vehicleBreakdowns = nil
	end
end
function readStream(e, streamId, connection)
	if not isEnabled() then
		return
	end
	vehicleBreakdowns:onReadStream(streamId, connection)
end
function writeStream(e, streamId, connection)
	if not isEnabled() then
		return
	end
	vehicleBreakdowns:onWriteStream(streamId, connection)
end
function loadBatteryType()
	local battery = loadXMLFile("fillTypes", g_vehicleBreakdownsDirectory .. "data/battery_fillType.xml")
	if battery ~= nil then
		g_fillTypeManager:loadFillTypes(battery, g_vehicleBreakdownsDirectory, false, g_vehicleBreakdownsModName)
		delete(battery)
	end
end
-- =========================================================================
-- FSBaseMission:setPlannedDaysPerPeriod HOOK
-- =========================================================================
local FSBaseMission_setPlannedDaysPerPeriod = FSBaseMission.setPlannedDaysPerPeriod
function FSBaseMission:setPlannedDaysPerPeriod(days, noEventSend)
    FSBaseMission_setPlannedDaysPerPeriod(self, days, noEventSend)
    if g_messageCenter ~= nil then
        g_messageCenter:publish(MessageType.SET_DAYSPERPERIOD, days)
        print("[RVB] published SET_DAYSPERPERIOD")
    end
end

init()
