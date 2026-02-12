
RVBRepairControlEvent = {}

local RVBRepairControlEvent_mt = Class(RVBRepairControlEvent, Event)
InitEventClass(RVBRepairControlEvent, "RVBRepairControlEvent")

function RVBRepairControlEvent.emptyNew()
	return Event.new(RVBRepairControlEvent_mt)
end
function RVBRepairControlEvent.new(vehicle, isRepairActive)
	local self = RVBRepairControlEvent.emptyNew()
	self.vehicle = vehicle
	self.isRepairActive = isRepairActive
	return self
end
function RVBRepairControlEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.isRepairActive = streamReadBool(streamId)
	self:run(connection)
end
function RVBRepairControlEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.isRepairActive)
end
function RVBRepairControlEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		--self.vehicle.spec_faultData.isRepairActive = self.isRepairActive
		self.vehicle:setIsRepairActive(self.isRepairActive, true)
	end
end
function RVBRepairControlEvent.sendEvent(vehicle, isRepairActive, noEventSend)
	if noEventSend == nil or not noEventSend then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBRepairControlEvent.new(vehicle, isRepairActive), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(RVBRepairControlEvent.new(vehicle, isRepairActive))
		end
	end
end
