
RVBRepairRequest_Event = {}
local mt = Class(RVBRepairRequest_Event, Event)
InitEventClass(RVBRepairRequest_Event, "RVBRepairRequest_Event")

function RVBRepairRequest_Event.emptyNew()
	return Event.new(mt)
end
function RVBRepairRequest_Event.new(vehicle, farmId)
	local self = RVBRepairRequest_Event.emptyNew()
	self.vehicle = vehicle
	self.farmId = farmId
	return self
end
function RVBRepairRequest_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.farmId = streamReadInt16(streamId)
	self:run(connection)
end
function RVBRepairRequest_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt16(streamId, self.farmId)
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
		self.vehicle:startRepair(self.farmId)
		self.vehicle.rvbDebugger:info("RVBRepairRequest_Event run", "startRepair on vehicle %s", self.vehicle:getFullName())
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, nil, nil, self.vehicle)
		end
	end
end
