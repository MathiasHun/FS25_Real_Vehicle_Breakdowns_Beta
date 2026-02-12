
RVBJumpStartingEvent = {}
local mt = Class(RVBJumpStartingEvent, Event)
InitEventClass(RVBJumpStartingEvent, "RVBJumpStartingEvent")

function RVBJumpStartingEvent.emptyNew()
	return Event.new(mt)
end
function RVBJumpStartingEvent.new(vehicle, chargeRate)
	local self = RVBJumpStartingEvent.emptyNew()
	self.vehicle = vehicle
	self.chargeRate = chargeRate
	return self
end
function RVBJumpStartingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.chargeRate = streamReadFloat32(streamId)
	self:run(connection)
end
function RVBJumpStartingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteFloat32(streamId, self.chargeRate)
end
function RVBJumpStartingEvent:run(connection)
	if connection:getIsServer() then
		--g_messageCenter:publish(MessageType.RVB_RESET_VEHICLE, self.vehicle)
	elseif self.vehicle ~= nil and (self.vehicle:getIsSynchronized() and self.vehicle.setRVBJumpchargerate ~= nil) then
		self.vehicle:setRVBJumpchargerate(self.chargeRate)
		g_server:broadcastEvent(self)
		--g_messageCenter:publish(MessageType.RVB_RESET_VEHICLE, self.vehicle)
		return
	end
end