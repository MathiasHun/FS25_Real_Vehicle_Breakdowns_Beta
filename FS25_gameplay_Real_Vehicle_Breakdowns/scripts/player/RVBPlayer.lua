
RVBPlayer = {}
local RVBPlayer_mt = Class(RVBPlayer)

function RVBPlayer.register()
	return RVBPlayer:new()
end
function RVBPlayer:new()
	local self = {}
	setmetatable(self, RVBPlayer_mt)
	self.targetVehicle = nil
	self.targetPlayer = nil
	self.infoText = ""
	self.jumperCableEventId = nil
	RVBPlayer.appendedFunction(PlayerInputComponent, "update", self, "PlayerInputComponent_update", false)
	RVBPlayer.appendedFunction(PlayerInputComponent, "registerActionEvents", self, "PlayerInputComponent_registerActionEvents", false)
	return self
end
function RVBPlayer:PlayerInputComponent_update(inputComponent, dt)
	if inputComponent.player.isOwner and g_inputBinding:getContextName() == PlayerInputComponent.INPUT_CONTEXT_NAME and self.jumperCableEventId ~= nil then
		self.targetVehicle = nil
		self.targetPlayer = inputComponent.player.userId
		self.infoText = ""
		local farmId = g_currentMission:getFarmId()
		if farmId ~= FarmManager.SPECTATOR_FARM_ID then
			local targetNode = inputComponent.player.targeter:getClosestTargetedNodeFromType(PlayerInputComponent)
			if targetNode ~= nil and entityExists(targetNode) then
				local nodeObject = g_currentMission:getNodeObject(targetNode)
				if nodeObject ~= nil and nodeObject:isa(Vehicle) then
					self.targetVehicle = nodeObject
					local rvb = self.targetVehicle.spec_faultData
					if rvb == nil or (rvb ~= nil and not rvb.isrvbSpecEnabled) then
						return
					end
					local isConnected = false
					local jc = self.targetVehicle.spec_jumperCable
					if jc ~= nil and jc.connection ~= nil then
						isConnected = true
					end
					self.infoText = g_i18n:getText(isConnected and "action_RVB_DISCONNECTING_JC" or "input_RVB_CONNECTING_JC")
				end
			end
		end
		g_inputBinding:setActionEventTextPriority(self.jumperCableEventId, GS_PRIO_VERY_HIGH)
		g_inputBinding:setActionEventTextVisibility(self.jumperCableEventId, self.targetVehicle ~= nil and self.targetVehicle.spec_faultData ~= nil)
		g_inputBinding:setActionEventActive(self.jumperCableEventId, self.targetVehicle ~= nil and self.targetVehicle.spec_faultData ~= nil)
		g_inputBinding:setActionEventText(self.jumperCableEventId, self.infoText)
	end
end
function RVBPlayer:PlayerInputComponent_registerActionEvents(inputComponent)
	if inputComponent.player.isOwner then
		g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
		local _, jumperCableEventId = g_inputBinding:registerActionEvent(InputAction.RVB_CONNECTING_JC, self, self.actionEventConnectJumperCables, false, true, false, false, nil, true)
		self.jumperCableEventId = jumperCableEventId
		g_inputBinding:endActionEventsModification()
	end
end
function RVBPlayer.appendedFunction(oldTarget, oldFunc, newTarget, newFunc)
	local superFunc = oldTarget[oldFunc]
	oldTarget[oldFunc] = function(...)
		superFunc(...)
		newTarget[newFunc](newTarget, ...)
	end
end
function RVBPlayer:showWarning(messageKey, vehicle)
    g_currentMission:showBlinkingWarning(string.format(g_i18n:getText(messageKey), vehicle:getFullName()), 2000)
end
function RVBPlayer:getNearbyDonorVehicleOLD(maxDistance)
    local px, py, pz = getWorldTranslation(g_localPlayer.rootNode)
    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        local spec = vehicle.spec_jumperCable
        if spec ~= nil and spec.connection ~= nil then
            local conn = spec.connection
            if conn.donor == vehicle and conn.receiver == nil then
                local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
                local dist = MathUtil.vector3Length(px - vx, py - vy, pz - vz)

                if dist <= maxDistance then
                    return vehicle
                end
            end
        end
    end
    return nil
end
function RVBPlayer:getNearbyDonorVehicle(receiver, maxDistance)
	for key, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
		local rvb = vehicle.spec_faultData
		if rvb ~= nil and rvb.isrvbSpecEnabled then
			local spec = vehicle.spec_jumperCable
			if spec ~= nil and spec.connection ~= nil then
				local conn = spec.connection
				if conn.donor ~= nil and conn.receiver == nil then
					if vehicle.steeringAxleNode ~= nil then
						local x_vehicle, y_vehicle, z_vehicle = getWorldTranslation(vehicle.steeringAxleNode)
						local x_receiver, y_receiver, z_receiver = getWorldTranslation(receiver.steeringAxleNode)
						local distanceBetweenDonorAndReceiver = math.sqrt((x_receiver - x_vehicle)^2 + (z_receiver - z_vehicle)^2)
						if distanceBetweenDonorAndReceiver <= maxDistance then
							return vehicle
						end
					end
				end
			end
		end
	end
	return nil
end

function RVBPlayer:searchForDonorNearPlayer(maxDistance)
	local x_player, y_player, z_player = g_localPlayer:getPosition()
	for key, vehicle in ipairs(g_currentMission.vehicleSystem.vehicles) do
		local rvb = vehicle.spec_faultData
		if rvb ~= nil and rvb.isrvbSpecEnabled then
			local spec = vehicle.spec_jumperCable
			if spec ~= nil and spec.connection == nil then
				if vehicle.steeringAxleNode ~= nil then
					local x_vehicle, y_vehicle, z_vehicle = getWorldTranslation(vehicle.steeringAxleNode)
					local distanceBetweenDonorAndReceiver = math.sqrt((x_player - x_vehicle)^2 + (z_player - z_vehicle)^2)
					if distanceBetweenDonorAndReceiver <= maxDistance then
						return vehicle
					end
				end
			end
		end
	end
	return nil
end


function RVBPlayer:actionEventConnectJumperCables()
    if self.targetVehicle == nil then return end
	-- 1️ keresünk aktív donort a receiverhez
    local donor = self:getNearbyDonorVehicle(self.targetVehicle, JUMPERCABLE_LENGTH)
    if donor ~= nil then
        -- receiver csatlakozik
        if self.targetVehicle ~= donor then
			--print("receiver → csatlakozik " .. tostring(donor:getFullName()))
            self.targetVehicle:setJumperCableConnection(
                donor,
                JUMPERCABLE_STATE.CONNECT,
                self.targetVehicle,
                0,
                0,
				self.targetPlayer
            )
			g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_connecting"), self.targetVehicle:getFullName()), 1500)
		else
			--print("Mar donor → le csatlakozik " .. tostring(donor:getFullName()))
			donor:setJumperCableConnection(
				donor,
				JUMPERCABLE_STATE.DONOR_DISCONNECT,
				nil,
				0,
				0,
				self.targetPlayer
			)
			g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_disconnecting"), self.targetVehicle:getFullName()), 1500)
        end

		self.targetVehicle:raiseActive()
        return
    end
	
	-- 2️ nincs donor → ez a jármű lehet donor
    local canBeDonor = self:searchForDonorNearPlayer(JUMPERCABLE_LENGTH)
    if canBeDonor ~= nil then
		--print("donor → csatlakozik " .. tostring(self.targetVehicle:getFullName()))
		if self.targetVehicle:getBatteryFillLevelPercentage() < BATTERY_LEVEL.MOTOR then
			g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_connecting_order"), self.targetVehicle:getFullName()), 1500)
			return
		end
        self.targetVehicle:setJumperCableConnection(
            self.targetVehicle,
            JUMPERCABLE_STATE.DONOR_SELECTED,
            nil,
            0,
            0,
			self.targetPlayer
        )
		--print("targetPlayer "..self.targetPlayer)
		--print("userId "..g_localPlayer.userId)
		--print("playerUserId "..g_currentMission.playerUserId)
		--print("getServerUserId "..g_currentMission:getServerUserId())
		g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_connecting"), self.targetVehicle:getFullName()), 1500)

		self.targetVehicle:raiseActive()
		return
    end
	
	local spec = self.targetVehicle.spec_jumperCable
	if spec == nil then return end

	-- 3️ receiver → le csatlakozik
    if spec.connection ~= nil and spec.connection.receiver == self.targetVehicle then
		--print("receiver → le csatlakozik " .. tostring(self.targetVehicle:getFullName()))
        self.targetVehicle:setJumperCableConnection(
            spec.connection.donor,
            JUMPERCABLE_STATE.DISCONNECT,
            self.targetVehicle,
            0,
            0,
			self.targetPlayer
        )
		g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_disconnecting"), self.targetVehicle:getFullName()), 1500)

		self.targetVehicle:raiseActive()
		return
    end
	
	-- 4 donor → le csatlakozik
    if spec.connection ~= nil and spec.connection.donor == self.targetVehicle then
		--print("donor → le csatlakozik " .. tostring(self.targetVehicle:getFullName()))
		if spec.connection ~= nil and spec.connection.receiver ~= nil then
			g_currentMission:showBlinkingWarning(g_i18n:getText("RVB_blinking_disconnecting_order"), 1500)
			return
		end
        self.targetVehicle:setJumperCableConnection(
            self.targetVehicle,
            JUMPERCABLE_STATE.DONOR_DISCONNECT,
            spec.connection.receiver,
            0,
            0,
			self.targetPlayer
        )
		g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("RVB_blinking_disconnecting"), self.targetVehicle:getFullName()), 1500)
		self.targetVehicle:raiseActive()
		return
    end

end