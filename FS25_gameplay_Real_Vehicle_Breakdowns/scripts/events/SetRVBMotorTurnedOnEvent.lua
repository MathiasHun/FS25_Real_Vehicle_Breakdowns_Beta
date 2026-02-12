
SetRVBMotorTurnedOnEvent = {}
local SetRVBMotorTurnedOnEvent_mt = Class(SetRVBMotorTurnedOnEvent, Event)
InitEventClass(SetRVBMotorTurnedOnEvent, "SetRVBMotorTurnedOnEvent")
function SetRVBMotorTurnedOnEvent.emptyNew()
    local self = Event.new(SetRVBMotorTurnedOnEvent_mt)
    return self
end
function SetRVBMotorTurnedOnEvent.new(vehicle, turnedOn)
    local self = SetRVBMotorTurnedOnEvent.emptyNew()
    self.vehicle = vehicle
    self.turnedOn = turnedOn
    return self
end
function SetRVBMotorTurnedOnEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.turnedOn = streamReadBool(streamId)
    self:run(connection)
end
function SetRVBMotorTurnedOnEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.turnedOn)
end
--[[function SetRVBMotorTurnedOnEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        if self.turnedOn then
            self.vehicle:startMotor(true) print("SetRVBMotorTurnedOnEvent turnedOn")
        else
            self.vehicle:stopMotor(true) print("SetRVBMotorTurnedOnEvent else")
        end
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(SetRVBMotorTurnedOnEvent.new(self.vehicle, self.turnedOn), nil, connection, self.vehicle)
    end
end]]
function SetRVBMotorTurnedOnEvent.run(self, connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setIsTurnedOn(self.turnedOn, true)
	end
end
function SetRVBMotorTurnedOnEvent.sendEvent(vehicle, turnedOn, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(SetRVBMotorTurnedOnEvent.new(vehicle, turnedOn), nil, nil, vehicle)
			return
		end
		g_client:getServerConnection():sendEvent(SetRVBMotorTurnedOnEvent.new(vehicle, turnedOn))
	end
end

