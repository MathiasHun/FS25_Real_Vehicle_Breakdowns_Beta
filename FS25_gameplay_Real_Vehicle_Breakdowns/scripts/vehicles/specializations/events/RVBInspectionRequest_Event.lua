
RVBInspectionRequest_Event = {}
local mt = Class(RVBInspectionRequest_Event, Event)
InitEventClass(RVBInspectionRequest_Event, "RVBInspectionRequest_Event")

function RVBInspectionRequest_Event.emptyNew()
	return Event.new(mt)
end
function RVBInspectionRequest_Event.new(vehicle, farmId)
	local self = RVBInspectionRequest_Event.emptyNew()
	self.vehicle = vehicle
	self.farmId = farmId
	return self
end
function RVBInspectionRequest_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.farmId = streamReadInt16(streamId)
	self:run(connection)
end
function RVBInspectionRequest_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt16(streamId, self.farmId)
end
--[[function RVBInspectionRequest_Event:run(connection)
	if g_server == nil then
		return
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startInspection(self.farmId)
	end
end
function RVBInspectionRequest_Event.sendEvent(vehicle, farmId)
	if g_server ~= nil then
		vehicle:startInspection(farmId)
	else
		g_client:getServerConnection():sendEvent(RVBInspectionRequest_Event.new(vehicle, farmId))
	end
end]] 
function RVBInspectionRequest_Event:run(connection)
	--if g_server == nil then
       -- return
    --end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:startInspection(self.farmId)
		self.vehicle.rvbDebugger:info("RVBInspectionRequest_Event run", "startInspection on vehicle %s", self.vehicle:getFullName())
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, nil, nil, self.vehicle)
		end
	end
end
