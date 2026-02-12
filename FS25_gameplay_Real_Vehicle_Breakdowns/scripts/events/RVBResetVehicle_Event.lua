
RVBResetVehicle_Event = {}
local mt = Class(RVBResetVehicle_Event, Event)
InitEventClass(RVBResetVehicle_Event, "RVBResetVehicle_Event")

function RVBResetVehicle_Event.emptyNew()
	return Event.new(mt)
end
function RVBResetVehicle_Event.new(vehicle)
	local self = RVBResetVehicle_Event.emptyNew()
	self.vehicle = vehicle
	return self
end
function RVBResetVehicle_Event.readStream(self, streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self:run(connection)
end
function RVBResetVehicle_Event.writeStream(self, streamId, _)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
end
function RVBResetVehicle_Event:run(connection)
	if self.vehicle ~= nil and (self.vehicle:getIsSynchronized() and self.vehicle.RVBresetVehicle ~= nil) then
		self.vehicle:RVBresetVehicle(self.vehicle)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self)
		end
		--g_messageCenter:publish(MessageType.RVB_RESET_VEHICLE, self.vehicle)
	end
end