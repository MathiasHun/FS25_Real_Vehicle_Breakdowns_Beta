
RVBInspection_Event = {}
local mt = Class(RVBInspection_Event, Event)
InitEventClass(RVBInspection_Event, "RVBInspection_Event")

function RVBInspection_Event.emptyNew()
	return Event.new(mt)
end
function RVBInspection_Event.new(vehicle, inspection, message)
	local self = RVBInspection_Event.emptyNew()
	self.vehicle = vehicle
	self.inspection = inspection or {}
	self.message = message or {}
	return self
end
function RVBInspection_Event.readStream(self, streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.inspection = {}
	self.inspection.state        = streamReadInt16(streamId)
	self.inspection.finishDay    = streamReadInt16(streamId)
	self.inspection.finishHour   = streamReadInt16(streamId)
	self.inspection.finishMinute = streamReadInt16(streamId)
	self.inspection.cost         = streamReadFloat32(streamId)
	self.inspection.factor       = streamReadFloat32(streamId)
	self.inspection.completed    = streamReadBool(streamId)
	self.message = {}
	self.message.result = streamReadBool(streamId) or false
	self.message.cost   = streamReadFloat32(streamId) or 0
	self.message.text   = streamReadString(streamId) or ""
	self:run(connection)
end
function RVBInspection_Event.writeStream(self, streamId, _)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt16(streamId, self.inspection.state)
	streamWriteInt16(streamId, self.inspection.finishDay)
	streamWriteInt16(streamId, self.inspection.finishHour)
	streamWriteInt16(streamId, self.inspection.finishMinute)
	streamWriteFloat32(streamId, self.inspection.cost)
	streamWriteFloat32(streamId, self.inspection.factor)
	streamWriteBool(streamId, self.inspection.completed)
	streamWriteBool(streamId, self.message.result or false)
	streamWriteFloat32(streamId, self.message.cost or 0)
	streamWriteString(streamId, self.message.text or "")
end
function RVBInspection_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:SyncClientServer_RVBInspection(self.inspection, self.message)
		if not connection:getIsServer() then print("RVBInspection_Event:run not")
			--g_server:broadcastEvent(RVBInspection_Event.new(self.vehicle, self.inspection, self.message), nil, nil, self.vehicle)
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end
function RVBInspection_Event.sendEvent(vehicle, data, message, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBInspection_Event.new(vehicle, data, message), true, nil, vehicle)
			--g_server:broadcastEvent(RVBInspection_Event.new(vehicle, data, message), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(RVBInspection_Event.new(vehicle, data, message))
		end
	end
end