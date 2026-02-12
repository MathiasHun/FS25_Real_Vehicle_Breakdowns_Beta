rvbPlaceableChargingStation = {}

function rvbPlaceableChargingStation.getChargeState(self, superFunc)
	local v13_ = self.spec_chargingStation
	if v13_.loadTrigger ~= nil then
		local v14_ = next(v13_.loadTrigger.fillableObjects)
		if v14_ ~= nil then
			local v15_ = v13_.loadTrigger.fillableObjects[v14_].object
			if v15_.getConsumerFillUnitIndex ~= nil then
				local v16_ = v15_:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE)
				--if v16 ~= nil then
				--	return v15_:getFillUnitFillLevel(v16), v15_:getFillUnitCapacity(v16)
				--end
		--		local battery = v15:getConsumerFillUnitIndex(FillType.BATTERYCHARGE)
		--		local chargeLevel, chargeCapacity = 0, 1
		--		if v16 ~= nil then
		--			chargeLevel = v15:getFillUnitFillLevel(v16)
		--			chargeCapacity = v15:getFillUnitCapacity(v16)
					--print("ELECTRICCHARGE chargeLevel "..chargeLevel.." / chargeCapacity "..chargeCapacity)
		--		end
		--		if battery then
		--			chargeLevel = chargeLevel + v15:getFillUnitFillLevel(battery)
		--			chargeCapacity = chargeCapacity + v15:getFillUnitCapacity(battery)
					--print("BATTERY chargeLevel "..chargeLevel.." / chargeCapacity "..chargeCapacity)
		--		end
		--		return chargeLevel, chargeCapacity
				if v16_ == nil then
					v16_ = v15_:getConsumerFillUnitIndex(FillType.BATTERYCHARGE)
                end
				if v16_ ~= nil then
					return v15_:getFillUnitFillLevel(v16_), v15_:getFillUnitCapacity(v16_)
				end
			end
		end
	end
	return 0, 1
end
PlaceableChargingStation.getChargeState = Utils.overwrittenFunction(PlaceableChargingStation.getChargeState, rvbPlaceableChargingStation.getChargeState)

function rvbPlaceableChargingStation.onUpdate(self, superFunc, dt)
	local spec = self.spec_chargingStation
	if spec.loadTrigger ~= nil then
		local isActive = next(spec.loadTrigger.fillableObjects) ~= nil
		if spec.chargeIndicatorNode ~= nil then
			if isActive then
				local color = spec.chargeIndicatorColorEmpty
				local fillLevel, capacity = self:getChargeState()
				if fillLevel / capacity > 0.95 then
					color = spec.chargeIndicatorColorFull
				end
				setShaderParameter(spec.chargeIndicatorNode, "colorScale", color[1], color[2], color[3], color[4], false)
				spec.chargeIndicatorLightColor = color
				--
				if g_currentMission.controlledVehicle ~= nil then
					local rvb = g_currentMission.controlledVehicle.spec_faultData
					rvb.batteryCHActive = false
				end
				--
			end
			local blinkSpeed = spec.loadTrigger.isLoading and (spec.chargeIndicatorBlinkSpeed or 0) or 0
			setShaderParameter(spec.chargeIndicatorNode, "blinkSimple", blinkSpeed, 0, 0, 0, false)
			setShaderParameter(spec.chargeIndicatorNode, "lightControl", isActive and (spec.chargeIndicatorIntensity or 0) or 0, 0, 0, 0, false)
			if spec.chargeIndicatorLight ~= nil then
				local alpha
				if isActive then
					local x, y, _, _ = getShaderParameter(spec.chargeIndicatorNode, "blinkSimple")
					local v27 = x * getShaderTimeSec() + y
					local v28 = math.fmod(v27, 1) - 0.5
					local v29 = 4 * math.abs(v28) - 0.8
					alpha = math.clamp(v29, 0, 1)
				else
					alpha = 0
				end
				setLightColor(spec.chargeIndicatorLight, spec.chargeIndicatorLightColor[1] * alpha, spec.chargeIndicatorLightColor[2] * alpha, spec.chargeIndicatorLightColor[3] * alpha)
			end
		end
		if spec.loadTrigger.isLoading then
			local allowDisplay = false
			local v31 = g_localPlayer
			if v31 == nil or v31:getIsInVehicle() then
				local v32 = v31:getCurrentVehicle()
				if v32 ~= nil then
					for _, v33 in pairs(spec.loadTrigger.fillableObjects) do
						if v33.object == v32 then
							allowDisplay = true
						end
					end
				end
			elseif calcDistanceFrom(v31.rootNode, self.rootNode) < spec.interactionRadius then
				allowDisplay = true
			end			
			if allowDisplay then
				local fillLevel, capacity = self:getChargeState()
				capacity = capacity - 1
				local seconds = (capacity - fillLevel) / (spec.loadTrigger.fillLitersPerMS * 1000)

				--[[if v36 >= 1 then
					local v37 = v36 / 60
					local v38 = math.floor(v37)
					local v39 = v38 / 60
					local v40 = math.floor(v39)
					local v41 = v38 - v40 * 60
					local v42 = v34 / v35 * 100
					local v43 = string.namedFormat(g_i18n:getText("info_chargeTime"), "hours", v40, "minutes", v41, "percentage", v42)
					g_currentMission:addExtraPrintText(v43)
				end]]
				if seconds >= 1 then

					local totalSeconds = seconds

					local hours = math.floor(totalSeconds / 3600)
					local minutes = math.floor((totalSeconds % 3600) / 60)
					local secondsRemaining = math.floor(totalSeconds % 60)
					local percentage = math.floor(fillLevel / capacity * 100)
					local seconds = seconds - minutes * 60

					if g_currentMission.controlledVehicle ~= nil then
						local rvb = g_currentMission.controlledVehicle.spec_faultData
						rvb.batteryCHActive = true
					end
					-- motor es vilagitas leallitas 
					local index = next(spec.loadTrigger.fillableObjects)
					local vehicle = spec.loadTrigger.fillableObjects[index].object
					if vehicle.configurations["motor"] ~= nil then
						if vehicle:getIsMotorStarted() then
							vehicle:stopMotor()
						end
						if vehicle.deactivateLights ~= nil then
							vehicle:deactivateLights()
						end
						local spec_m = vehicle.spec_motorized
						if spec_m.motor ~= nil then
							spec_m.motor:setGearShiftMode(spec_m.gearShiftMode)
						end
					end
					-- motor es vilagitas leallitas END

					--local v40 = string.format(g_i18n:getText("info_chargeTime"), minutes, seconds, fillLevel / capacity * 100)
		--			local v43 = string.namedFormat(g_i18n:getText("info_chargeTime"), "hours", v40, "minutes", v41, "percentage", v42)
					local formatted = string.namedFormat(g_i18n:getText("rvb_info_chargeTime"), "hours", hours, "minutes", minutes, "seconds", secondsRemaining, "percentage", percentage)
					g_currentMission:addExtraPrintText(formatted)
				end
			end
		end
		if isActive then
			self:raiseActive()
		end
	end
end
PlaceableChargingStation.onUpdate = Utils.overwrittenFunction(PlaceableChargingStation.onUpdate, rvbPlaceableChargingStation.onUpdate)