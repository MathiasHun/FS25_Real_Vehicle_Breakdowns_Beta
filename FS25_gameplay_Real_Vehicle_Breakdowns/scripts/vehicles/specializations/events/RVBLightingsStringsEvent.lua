
RVBLightingsStringsEvent = {}
local RVBLightingsStringsEvent_mt = Class(RVBLightingsStringsEvent, Event)

InitEventClass(RVBLightingsStringsEvent, "RVBLightingsStringsEvent")

function RVBLightingsStringsEvent.emptyNew()
	local self = Event.new(RVBLightingsStringsEvent_mt)

	return self
end

function RVBLightingsStringsEvent.new(object, lights_request_A, lights_request_B)
	local self = RVBLightingsStringsEvent.emptyNew()
	self.object = object
	self.lights_request_A = lights_request_A
	self.lights_request_B = lights_request_B

	return self
end

function RVBLightingsStringsEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.lights_request_A = streamReadBool(streamId)
	self.lights_request_B = streamReadBool(streamId)

	self:run(connection)
end

function RVBLightingsStringsEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.lights_request_A)
	streamWriteBool(streamId, self.lights_request_B)
end

function RVBLightingsStringsEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setRVBLightsStrings(self.lights_request_A, self.lights_request_B, true, true)
	end

	if not connection:getIsServer() then
		g_server:broadcastEvent(RVBLightingsStringsEvent.new(self.object, self.lights_request_A, self.lights_request_B), nil, connection, self.object)
	end
end
