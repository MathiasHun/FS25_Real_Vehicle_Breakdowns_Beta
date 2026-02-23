
JumperCableEvent = {}
local JumperCableEvent_mt = Class(JumperCableEvent, Event)
InitEventClass(JumperCableEvent, "JumperCableEvent")

function JumperCableEvent.emptyNew()
	return Event.new(JumperCableEvent_mt)
end
function JumperCableEvent.new(vehicle, donor, state, receiver, jumperTime, jumperThreshold, activePlayerUserId)
	local self = JumperCableEvent.emptyNew()
	self.vehicle = vehicle
	self.donor = donor
	self.state = state
	self.receiver = receiver
	self.jumperTime = jumperTime
	self.jumperThreshold = jumperThreshold
	self.activePlayerUserId = activePlayerUserId
	return self
end
function JumperCableEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	NetworkUtil.writeNodeObject(streamId, self.donor)
	streamWriteInt16(streamId, self.state)
	NetworkUtil.writeNodeObject(streamId, self.receiver)
	streamWriteFloat32(streamId, self.jumperTime)
	streamWriteInt32(streamId, self.jumperThreshold)
	streamWriteInt32(streamId, self.activePlayerUserId)
end
function JumperCableEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.donor = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadInt16(streamId)
	self.receiver = NetworkUtil.readNodeObject(streamId)
	self.jumperTime = streamReadFloat32(streamId)
	self.jumperThreshold = streamReadInt32(streamId)
	self.activePlayerUserId = streamReadInt32(streamId)
    self:run(connection)
end
function JumperCableEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:setJumperCableConnection(self.donor, self.state, self.receiver, self.jumperTime, self.jumperThreshold, self.activePlayerUserId, true)
	--end
	if not connection:getIsServer() then
		g_server:broadcastEvent(JumperCableEvent.new(self.vehicle, self.donor, self.state, self.receiver, self.jumperTime, self.jumperThreshold, self.activePlayerUserId), nil, nil, self.vehicle)
	end
	if self.state == JUMPERCABLE_STATE.CABLE_BROKEN and g_localPlayer:getCurrentVehicle() == self.vehicle then
		--g_messageCenter:publish(MessageType.RVB_JUMPERCABLE_MESSAGE, self.vehicle, "blinking", "disconnecting_toofar", "RVB_blinking_disconnecting_toofar")
		--g_messageCenter:publish(MessageType.RVB_JUMPERCABLE_MESSAGE, self.vehicle, "notification", "cableBroken", "RVB_blinking_connecting_cableBroken", 100)
	end
	end
end

function JumperCableEvent.sendEvent(vehicle, donor, state, receiver, jumperTime, jumperThreshold, activePlayerUserId, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(JumperCableEvent.new(vehicle, donor, state, receiver, jumperTime, jumperThreshold, activePlayerUserId), nil, nil, vehicle)
			return
		end
		g_client:getServerConnection():sendEvent(JumperCableEvent.new(vehicle, donor, state, receiver, jumperTime, jumperThreshold, activePlayerUserId))
	end
end