
RVBserviceManual_Event = {}
local mt = Class(RVBserviceManual_Event, Event)
InitEventClass(RVBserviceManual_Event, "RVBserviceManual_Event")

function RVBserviceManual_Event.emptyNew()
	return Event.new(mt)
end
function RVBserviceManual_Event.new(vehicle, entry)
	local self = RVBserviceManual_Event.emptyNew()
	self.vehicle = vehicle
	self.entry = entry or {}
	return self
end
function RVBserviceManual_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.entry = {}
	self.entry.entryType = streamReadInt16(streamId)
	self.entry.entryTime = streamReadInt16(streamId)
	self.entry.operatingHours = streamReadFloat32(streamId)
	self.entry.odometer = streamReadFloat32(streamId)
	self.entry.resultKey = streamReadString(streamId)
	local count = streamReadUInt8(streamId)
    if count > 0 then
        self.entry.errorList = {}
        for i = 1, count do
            table.insert(self.entry.errorList, streamReadString(streamId))
        end
    end
	self.entry.cost = streamReadFloat32(streamId)
	self:run(connection)
end
function RVBserviceManual_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt16(streamId, self.entry.entryType)
	streamWriteInt16(streamId, self.entry.entryTime)
	streamWriteFloat32(streamId, self.entry.operatingHours)
	streamWriteFloat32(streamId, self.entry.odometer)
	streamWriteString(streamId, self.entry.resultKey)
	local errors = self.entry.errorList or {}
    streamWriteUInt8(streamId, #errors)
    for _, err in ipairs(errors) do
        streamWriteString(streamId, err)
    end
	streamWriteFloat32(streamId, self.entry.cost)
end
function RVBserviceManual_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:SyncClientServer_serviceManual(self.entry)
	end
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.vehicle)
	end
end
function RVBserviceManual_Event.sendEvent(vehicle, data, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(RVBserviceManual_Event.new(vehicle, data), true, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(RVBserviceManual_Event.new(vehicle, data))
		end
	end
end
