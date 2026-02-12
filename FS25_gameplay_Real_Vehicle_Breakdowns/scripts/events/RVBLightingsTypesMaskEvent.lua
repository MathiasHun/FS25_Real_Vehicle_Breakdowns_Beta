
RVBLightingsTypesMaskEvent = {}
local RVBLightingsTypesMaskEvent_mt = Class(RVBLightingsTypesMaskEvent, Event)

InitEventClass(RVBLightingsTypesMaskEvent, "RVBLightingsTypesMaskEvent")

function RVBLightingsTypesMaskEvent.emptyNew()
	local self = Event.new(RVBLightingsTypesMaskEvent_mt)

	return self
end

function RVBLightingsTypesMaskEvent.new(object, lightsTypesMask)
	local self = RVBLightingsTypesMaskEvent.emptyNew()
	self.object = object
	self.lightsTypesMask = lightsTypesMask

	return self
end

function RVBLightingsTypesMaskEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.lightsTypesMask = streamReadInt16(streamId)

	self:run(connection)
end

function RVBLightingsTypesMaskEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt16(streamId, self.lightsTypesMask)
end

function RVBLightingsTypesMaskEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setRVBLightsTypesMask(self.lightsTypesMask, true, true)
	end

	if not connection:getIsServer() then
		g_server:broadcastEvent(RVBLightingsTypesMaskEvent.new(self.object, self.lightsTypesMask), nil, connection, self.object)
	end
end
