
RVBService_Event = {}
local mt = Class(RVBService_Event, Event)
InitEventClass(RVBService_Event, "RVBService_Event")

function RVBService_Event.emptyNew()
	return Event.new(mt)
end
function RVBService_Event.new(vehicle, service, message)
	local self = RVBService_Event.emptyNew()
	self.vehicle = vehicle
	self.service = service or {}
	self.message = message or {}
	return self
end
function RVBService_Event.readStream(self, streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.service = {}
	self.service.state        = streamReadInt16(streamId)
	self.service.finishDay    = streamReadInt16(streamId)
	self.service.finishHour   = streamReadInt16(streamId)
	self.service.finishMinute = streamReadInt16(streamId)
	self.service.cost         = streamReadFloat32(streamId)
	self.message = {}
	self.message.result = streamReadBool(streamId) or false
	self.message.cost   = streamReadFloat32(streamId) or 0
	self.message.text   = streamReadString(streamId) or ""
	self:run(connection)
end
function RVBService_Event.writeStream(self, streamId, _)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt16(streamId, self.service.state)
	streamWriteInt16(streamId, self.service.finishDay)
	streamWriteInt16(streamId, self.service.finishHour)
	streamWriteInt16(streamId, self.service.finishMinute)
	streamWriteFloat32(streamId, self.service.cost)
	streamWriteBool(streamId, self.message.result or false)
	streamWriteFloat32(streamId, self.message.cost or 0)
	streamWriteString(streamId, self.message.text or "")
end
function RVBService_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:SyncClientServer_RVBService(self.service, self.message)
		if not connection:getIsServer() then
			--g_server:broadcastEvent(RVBService_Event.new(self.vehicle, self.service, self.message), nil, nil, self.vehicle)
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end
function RVBService_Event.sendEvent(vehicle, data, message, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBService_Event.new(vehicle, data, message), true, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(RVBService_Event.new(vehicle, data, message))
		end
	end
end