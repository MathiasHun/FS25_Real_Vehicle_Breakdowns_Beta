
BatteryFillUnitFillLevelEvent = {}
local mt = Class(BatteryFillUnitFillLevelEvent, Event)
InitEventClass(BatteryFillUnitFillLevelEvent, "BatteryFillUnitFillLevelEvent")

function BatteryFillUnitFillLevelEvent.emptyNew()
	return Event.new(mt)
end
function BatteryFillUnitFillLevelEvent.new(vehicle)
	local self = BatteryFillUnitFillLevelEvent.emptyNew()
	self.vehicle = vehicle
	return self
end
function BatteryFillUnitFillLevelEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self:run(connection)
end
function BatteryFillUnitFillLevelEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
end
function BatteryFillUnitFillLevelEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		BatteryManager.batteryChargeVehicle(self.vehicle)
	end
	if not connection:getIsServer() then
		if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
			g_server:broadcastEvent(self)
			g_messageCenter:publish(MessageType.VEHICLE_REPAIRED, self.vehicle)
		end
	else
		g_messageCenter:publish(MessageType.VEHICLE_REPAIRED, self.vehicle)
	end
end
