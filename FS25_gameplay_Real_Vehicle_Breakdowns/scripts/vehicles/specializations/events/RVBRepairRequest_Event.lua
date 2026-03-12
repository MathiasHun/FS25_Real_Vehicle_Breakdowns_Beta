
RVBRepairRequest_Event = {}
local mt = Class(RVBRepairRequest_Event, Event)
InitEventClass(RVBRepairRequest_Event, "RVBRepairRequest_Event")

function RVBRepairRequest_Event.emptyNew()
	return Event.new(mt)
end
function RVBRepairRequest_Event.new(vehicle, farmId, plusDuration)
	local self = RVBRepairRequest_Event.emptyNew()
	self.vehicle = vehicle
	self.farmId = farmId
	self.plusDuration = plusDuration
	return self
end
function RVBRepairRequest_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
	self.plusDuration = streamReadInt16(streamId)
	self:run(connection)
end
function RVBRepairRequest_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
	streamWriteInt16(streamId, self.plusDuration)
end
--[[function RVBRepairRequest_Event:run(connection)
	if g_server == nil then
		return
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startRepair(self.farmId)
	end
end
function RVBRepairRequest_Event.sendEvent(vehicle, farmId)
	if g_server ~= nil then
		vehicle:startRepair(farmId)
	else
		g_client:getServerConnection():sendEvent(RVBRepairRequest_Event.new(vehicle, farmId))
	end
end]]
function RVBRepairRequest_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startRepair(self.farmId, self.plusDuration)
		self.vehicle.rvbDebugger:info("RVBRepairRequest_Event run", "startRepair on vehicle %s", self.vehicle:getFullName())
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, nil, nil, self.vehicle)
		end
	end
end