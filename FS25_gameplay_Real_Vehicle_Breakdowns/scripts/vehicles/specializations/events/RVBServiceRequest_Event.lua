
RVBServiceRequest_Event = {}
local mt = Class(RVBServiceRequest_Event, Event)
InitEventClass(RVBServiceRequest_Event, "RVBServiceRequest_Event")

function RVBServiceRequest_Event.emptyNew()
	return Event.new(mt)
end
function RVBServiceRequest_Event.new(vehicle, farmId, plusDuration)
	local self = RVBServiceRequest_Event.emptyNew()
	self.vehicle = vehicle
	self.farmId = farmId
	self.plusDuration = plusDuration
	return self
end
function RVBServiceRequest_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
	self.plusDuration = streamReadInt16(streamId)
	self:run(connection)
end
function RVBServiceRequest_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
	streamWriteInt16(streamId, self.plusDuration)
end
--[[function RVBServiceRequest_Event:run(connection)
	if g_server == nil then
		return
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startService(self.farmId)
	end
end
function RVBServiceRequest_Event.sendEvent(vehicle, farmId)
	if g_server ~= nil then
		vehicle:startService(farmId)
	else
		g_client:getServerConnection():sendEvent(RVBServiceRequest_Event.new(vehicle, farmId))
	end
end]]
function RVBServiceRequest_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startService(self.farmId)
		self.vehicle.rvbDebugger:info("RVBServiceRequest_Event run", "startService on vehicle %s", self.vehicle:getFullName())
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, nil, nil, self.vehicle)
		end
	end
end