
WorkshopCount_Event = {}
local mt = Class(WorkshopCount_Event, Event)
InitEventClass(WorkshopCount_Event, "WorkshopCount_Event")

function WorkshopCount_Event.emptyNew()
    return Event.new(mt)
end
function WorkshopCount_Event.new(count)
    local self = WorkshopCount_Event.emptyNew()
    self.count = count
    return self
end
function WorkshopCount_Event:readStream(streamId, connection)
    self.count = streamReadInt16(streamId)
	self:run(connection)
end
function WorkshopCount_Event:writeStream(streamId, connection)
    streamWriteInt16(streamId, self.count)
end
function WorkshopCount_Event:run(connection)
	local RVB = g_currentMission.vehicleBreakdowns
	RVB:setWorkshopCount(self.count, true)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection)
	end
end
function WorkshopCount_Event.sendEvent(count, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(WorkshopCount_Event.new(count))
		else
			g_client:getServerConnection():sendEvent(WorkshopCount_Event.new(count))
		end
	end
end