
RVBToggleSpec_Event = {}
local mt = Class(RVBToggleSpec_Event, Event)

InitEventClass(RVBToggleSpec_Event, "RVBToggleSpec_Event")

function RVBToggleSpec_Event.emptyNew()
	return Event.new(mt)
end
function RVBToggleSpec_Event.new(vehicle, enabled)
	local self = RVBToggleSpec_Event.emptyNew()
	self.vehicle = vehicle
	self.enabled = enabled
	return self
end
function RVBToggleSpec_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.enabled = streamReadBool(streamId)
	self:run(connection)
end
function RVBToggleSpec_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.enabled)
end    
function RVBToggleSpec_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		local spec = self.vehicle.spec_faultData
		spec.isrvbSpecEnabled = self.enabled
		self.vehicle.rvbDebugger:info("RVBToggleSpec_Event run", "specialization toggled to %s on vehicle %s", tostring(self.enabled), self.vehicle:getFullName())
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, nil, nil, self.vehicle)
		end
	end
end
