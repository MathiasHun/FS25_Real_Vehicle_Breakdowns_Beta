
RVBParts_Event = {}
local mt = Class(RVBParts_Event, Event)
InitEventClass(RVBParts_Event, "RVBParts_Event")

function RVBParts_Event.emptyNew()
	return Event.new(mt)
end
function RVBParts_Event.new(vehicle, partsTable)
	local self = RVBParts_Event.emptyNew()
	self.vehicle = vehicle
	self.parts = partsTable or {}
	return self
end
function RVBParts_Event:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.parts = {}
	local count = streamReadInt32(streamId)
	for i = 1, count do
		local key = streamReadString(streamId)
		local part = {
			name            = streamReadString(streamId),
			operatingHours  = streamReadFloat32(streamId),
			repairreq       = streamReadBool(streamId),
			prefault        = streamReadString(streamId),
			fault           = streamReadString(streamId),
			cost            = streamReadFloat32(streamId),
			runOncePerStart = streamReadBool(streamId)
		}
		self.parts[key] = part
	end
	self:run(connection)
end

function RVBParts_Event:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteInt32(streamId, table.count(self.parts))
	for key, part in pairs(self.parts) do
		streamWriteString(streamId, key)
		streamWriteString(streamId, part.name)
		streamWriteFloat32(streamId, part.operatingHours)
		streamWriteBool(streamId, part.repairreq)
		streamWriteString(streamId, part.prefault)
		streamWriteString(streamId, part.fault)
		streamWriteFloat32(streamId, part.cost)
		streamWriteBool(streamId, part.runOncePerStart)
	end
end
function RVBParts_Event:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:SyncClientServer_RVBParts(self.parts)
		if not connection:getIsServer() then
			--g_server:broadcastEvent(RVBParts_Event.new(self.vehicle, self.parts), nil, nil, self.vehicle)
			--g_server:broadcastEvent(RVBParts_Event.new(self.vehicle, self.parts), nil, connection, self.vehicle)
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end
function RVBParts_Event.sendEvent(vehicle, data, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--g_server:broadcastEvent(RVBParts_Event.new(vehicle, data), true, nil, vehicle)
			-- vagy
			--g_server:broadcastEvent(RVBParts_Event.new(vehicle, data), false, nil, vehicle)
			-- vagy
			g_server:broadcastEvent(RVBParts_Event.new(vehicle, data), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(RVBParts_Event.new(vehicle, data))
		end
	end
end