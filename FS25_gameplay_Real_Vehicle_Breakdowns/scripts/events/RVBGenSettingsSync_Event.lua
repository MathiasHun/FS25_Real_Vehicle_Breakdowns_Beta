RVBGenSettingsSync_Event = {}

RVBGenSettingsSync_Event_mt = Class(RVBGenSettingsSync_Event, Event)
InitEventClass(RVBGenSettingsSync_Event, "RVBGenSettingsSync_Event")

function RVBGenSettingsSync_Event.emptyNew()
    local self = Event.new(RVBGenSettingsSync_Event_mt)
    return self
end
function RVBGenSettingsSync_Event.new(difficulty)
    local self = RVBGenSettingsSync_Event.emptyNew()
    self.difficulty = difficulty
    return self
end
function RVBGenSettingsSync_Event:readStream(streamId, connection)
	self.difficulty = streamReadUIntN(streamId, 2)
	self:run(connection)
end
function RVBGenSettingsSync_Event:writeStream(streamId, connection)

	streamWriteUIntN(streamId, self.difficulty, 2) -- 1–3 között pl.
end
function RVBGenSettingsSync_Event:run(connection)
	local RVB = g_currentMission.vehicleBreakdowns

	RVB:setWorkshopCount(self.difficulty, true)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection)
	end
end
function RVBGenSettingsSync_Event.sendEvent(difficulty, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBGenSettingsSync_Event.new(difficulty))
		else
			g_client:getServerConnection():sendEvent(RVBGenSettingsSync_Event.new(difficulty))
		end
	end
end
