RVBGamePSettings_Event = {}

local RVBGamePSettings_Event_mt = Class(RVBGamePSettings_Event, Event)
InitEventClass(RVBGamePSettings_Event, "RVBGamePSettings_Event")

function RVBGamePSettings_Event.emptyNew()
	return Event.new(RVBGamePSettings_Event_mt)
end
function RVBGamePSettings_Event.new(gameplaySettings)
	local self = RVBGamePSettings_Event.emptyNew()
	self.set = gameplaySettings
	return self
end
function RVBGamePSettings_Event:writeStream(streamId, connection)
	local s = self.set
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
end
function RVBGamePSettings_Event:readStream(streamId, connection)
	local s = {}
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
	self.set = s
	self:run(connection)
end
function RVBGamePSettings_Event:run(connection)
	local RVB = g_currentMission.vehicleBreakdowns
	if RVB == nil then return end
	local s = self.set
	RVB:setDailyServiceInterval(s.dailyServiceInterval, true)
	RVB:setPeriodicServiceInterval(s.periodicServiceInterval, true)
	RVB:setIsWorkshopTime(s.workshopTime, true)
	RVB:setWorkshopOpen(s.workshopOpen, true)
	RVB:setWorkshopClose(s.workshopClose, true)
	RVB:setWorkshopCountMax(s.workshopCountMax, true)
	RVB:setRVBDifficulty(s.difficulty, true)
	RVB:setThermostatLifetime(s.thermostatLifetime, true)
	RVB:setLightingsLifetime(s.lightingsLifetime, true)
	RVB:setGlowplugLifetime(s.glowplugLifetime, true)
	RVB:setWipersLifetime(s.wipersLifetime, true)
	RVB:setGeneratorLifetime(s.generatorLifetime, true)
	RVB:setEngineLifetime(s.engineLifetime, true)
	RVB:setSelfstarterLifetime(s.selfstarterLifetime, true)
	RVB:setBatteryLifetime(s.batteryLifetime, true)
	RVB:setTireLifetime(s.tireLifetime, true)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection)
	end
end
function RVBGamePSettings_Event.sendEvent(set, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBGamePSettings_Event.new(set))
		else
			g_client:getServerConnection():sendEvent(RVBGamePSettings_Event.new(set))
		end
	end
end