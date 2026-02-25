
WorkshopRepair = {}
	
function WorkshopRepair.start(vehicle, farmId)
    local spec = vehicle.spec_faultData

    if spec.repair.state ~= REPAIR_STATE.NONE then
        return
    end

    local cost = vehicle:getRepairPrice_RVBClone()
    if g_currentMission:getMoney(farmId) < cost then
		print("WorkshopRepair:start(): " .. g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
        return
    end
	
	local faultListTime = 0
	local faultListText = {}
	for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = spec.parts[key]
		if part and part.repairreq then
			table.insert(faultListText, g_i18n:getText(FaultRegistry[key].name))
			faultListTime = faultListTime + FaultRegistry[key].repairTime
		end
	end
	local AddHour = math.floor(faultListTime / 3600)
	local AddMinute = math.floor(((faultListTime / 3600) - AddHour) * 60)
    local d,h,m = vehicle:CalculateFinishTime(AddHour, AddMinute)
	local repair = spec.repair

    repair.state = REPAIR_STATE.ACTIVE
    repair.finishDay = d
    repair.finishHour = h
    repair.finishMinute = m
    repair.cost = cost

    RVBRepair_Event.sendEvent(vehicle, repair, {result=false,cost=0,text=""})
	
	local RVB = g_currentMission.vehicleBreakdowns
	if not RVB.workshopVehicles[vehicle] then
		RVB.workshopVehicles[vehicle] = true
		RVB.workshopCount = RVB.workshopCount + 1
		WorkshopCount_Event.sendEvent(RVB.workshopCount)
	end

end

function WorkshopRepair.update(vehicle, dt)
    if not vehicle.isServer then return end

    local spec = vehicle.spec_faultData
    local repair = spec.repair
	local insCompleted = spec.inspection.completed

    local state = repair.state or REPAIR_STATE.NONE

    if state == REPAIR_STATE.NONE then
        return
    end

    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day, hour, minute = env.currentDay, env.currentHour, env.currentMinute
    local insDay, insHour, insMinute = repair.finishDay, repair.finishHour, repair.finishMinute

    if state == REPAIR_STATE.ACTIVE and insCompleted then
        if minute % 5 == 0 and spec.alertMessage["repair"] ~= minute then
            spec.alertMessage["repair"] = minute
			--table.insert(spec.uiProgressMessage, {
			--	key  = "repair",
			--	text = "RVB_alertmessage_repair"
			--})
			--vehicle:raiseDirtyFlags(spec.uiEventsDirtyFlag)
			--if vehicle.isServer and vehicle.isClient then
			--	g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, vehicle, "repair", "RVB_alertmessage_repair")
			--end
			vehicle:addBlinkingMessage("repair", "RVB_alertmessage_repair")
        end

		local parts = spec.parts
		if spec.totalRepairTime == 0.0 then
			for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
				local part = parts[key]
				if not part then
					vehicle.rvbDebugger:warning("WorkshopRepair.update", "Part key '%s' is missing in vehicle %s", key, vehicle:getFullName())
				elseif part.repairreq then
					spec.totalRepairTime = spec.totalRepairTime + (FaultRegistry[key].repairTime or 0)
					vehicle.rvbDebugger:info("WorkshopRepair.update", "VehicleBreakdowns:updateRepair TotalRepairTime: %s", spec.totalRepairTime)
				end
			end
		end
		for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = parts[key]
			if not part then
				vehicle.rvbDebugger:warning("WorkshopRepair.update", "Part key '%s' is missing in vehicle %s", key, vehicle:getFullName())
			elseif part.repairreq then
				if not part.startingOperatingHours then
					part.startingOperatingHours = part.operatingHours
					vehicle.rvbDebugger:info("WorkshopRepair.update", "VehicleBreakdowns:updateRepair %s startingOperatingHours: %s", part.name, part.startingOperatingHours)
				end
				if spec.totalRepairTime > 0 then
					local operatingHoursPerSecond = part.startingOperatingHours / spec.totalRepairTime
					local reduction = operatingHoursPerSecond * (dt / 1000) * g_currentMission.missionInfo.timeScale
					spec.repairToChange = spec.repairToChange + reduction
					local repairToChange = spec.repairToChange
					if math.abs(repairToChange) > 0.1 then
						reduction = spec.repairToChange
						spec.repairToChange = 0
						vehicle.rvbDebugger:info("WorkshopRepair.update", "VehicleBreakdowns:updateRepair  %s reduction: %s dt: %s", part.name, reduction, dt)
						part.operatingHours = math.max(part.operatingHours - reduction, 0)
						vehicle:raiseDirtyFlags(spec.partsDirtyFlag)
						vehicle.rvbDebugger:info("WorkshopRepair.update", "VehicleBreakdowns:updateRepair  %s part.operatingHours: %s", part.name, part.operatingHours)
					end
				end
			end
		end
    end

    if day > insDay or (day == insDay and hour > insHour) or (day == insDay and hour == insHour and minute >= insMinute) then
        vehicle:finishRepair(spec)
    end

    --if state == REPAIR_STATE.ACTIVE or state == REPAIR_STATE.PAUSED then
    --    vehicle:raiseActive()
    --end
	if state == REPAIR_STATE.ACTIVE then
		vehicle:openHoodForWorkshop(true)
		vehicle:raiseActive()
	elseif state == REPAIR_STATE.PAUSED then
		vehicle:openHoodForWorkshop(false)
		vehicle:raiseActive()
	end
end

function WorkshopRepair.finish(vehicle, spec)
    local repair = spec.repair
    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day = env.currentDay

	local anyRepairDone = false
	local partList = {}
	for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = spec.parts[key]
		if not part then
			vehicle.rvbDebugger:warning("WorkshopRepair.finish", "Part key '%s' is missing in vehicle %s", key, vehicle:getFullName())
		elseif part.repairreq then
			--table.insert(partList, g_i18n:getText("RVB_faultText_" .. part.name))
			table.insert(partList, "RVB_faultText_" .. part.name)
			part.repairreq = false
			part.operatingHours = 0
			part.fault = "empty"
			part.prefault = "empty"
			part.startingOperatingHours = nil
			part.pre_random = nil
			anyRepairDone = true
		end
	end
	
    if anyRepairDone then
	
		spec.ShortCircuitStop = false
		spec.isRepairActive = false
		spec.totalRepairTime = 0.0
	
		local specM = vehicle.spec_motorized
		if specM then
			specM.motorTemperature.value = vehicle.currentTemperaturDay
			specM.motorFan.enableTemperature = 95
			specM.motorFan.disableTemperature = 85
		end
		
		--local partListText = table.concat(partList, ", ")
		--local manualDesc = string.format(g_i18n:getText("RVB_WorkshopMessage_repairDone"), partListText)
		local keyText = "RVB_repairDialogEnd"
		local removeMoney = repair.cost

		local message = {
			result = true,
			cost = removeMoney,
			text = keyText
		}

		local entry = {
			entryType = REPAIR.SERVICE_MANUAL,
			entryTime = day,
			operatingHours = spec.totaloperatingHours,
			odometer = 0,
			--result = manualDesc,
			resultKey = "RVB_WorkshopMessage_repairDone",
			errorList = partList,
			cost = removeMoney
		}

		repair.state = REPAIR_STATE.NONE
		repair.finishDay, repair.finishHour, repair.finishMinute, repair.cost = 0,0,0,0
		spec.inspection.completed = false
		spec.alertMessage["repair"] = -1

		RVBserviceManual_Event.sendEvent(vehicle, entry)
		RVBParts_Event.sendEvent(vehicle, spec.parts)
		RVBRepair_Event.sendEvent(vehicle, repair, message)
		RVBInspection_Event.sendEvent(vehicle, spec.inspection, {result=false,cost=0,text=""})

		local RVB = g_currentMission.vehicleBreakdowns
		if RVB.workshopVehicles[vehicle] then
			RVB.workshopVehicles[vehicle] = nil
			RVB.workshopCount = RVB.workshopCount - 1
			WorkshopCount_Event.sendEvent(RVB.workshopCount)
		end
		
		vehicle:openHoodForWorkshop(false)
		
		resetEngineTorque(vehicle)

		if g_modIsLoaded["FS25_useYourTyres"] then
			for wheelIdx, wheel in ipairs(vehicle.spec_wheels.wheels) do
				local partName = WHEELTOPART[wheelIdx]
				if partName == nil then return end
				local part = spec.parts[partName]
				if not part then return end
				wheel.uytTravelledDist = part.operatingHours
			end
			WheelPhysics.updateContact = Utils.appendedFunction(WheelPhysics.updateContact, VehicleBreakdowns.injPhysWheelUpdateContact)
		end
	end
end
function WorkshopRepair.SyncClientServer(vehicle, repair, message)
	local spec = vehicle.spec_faultData
	spec.repair = repair

	if spec.repair.state == REPAIR_STATE.ACTIVE then
		vehicle.rvbDebugger:info("WorkshopRepair.SyncClientServer", "The repair of vehicle %s has started. Activated in the updateRepair(dt) function.", vehicle:getFullName())
		vehicle:raiseActive()
	end

	if message ~= nil and message.cost > 0 then
		if vehicle.isServer then
			g_currentMission:addMoney(-message.cost, vehicle:getOwnerFarmId(), MoneyType.VEHICLE_REPAIR, true, true)
		end
		if vehicle.isClient then
			local notiMessage
			if message.result then
				notiMessage = string.format(g_i18n:getText(message.text), vehicle:getFullName())
			else
				notiMessage = string.format(g_i18n:getText(message.text), vehicle:getFullName(), g_i18n:formatMoney(vehicle:getRepairPrice_RVBClone(true)))
			end
			g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notiMessage, 10000, GuiSoundPlayer.SOUND_SAMPLES.SUCCESS)
		end
	end

	local r = spec.repair
	vehicle.rvbDebugger:info(
		"WorkshopRepair.SyncClientServer", 
		"The repair of vehicle %s has been completed. Repair data block: state=%s finishDay=%s finishHour=%s finishMinute=%s cost=%s",
		vehicle:getFullName(),
		tostring(r.state), tostring(r.finishDay), tostring(r.finishHour), tostring(r.finishMinute), tostring(r.cost)
	)
	local repairNone = spec.repair.state == REPAIR_STATE.NONE
	if vehicle.isClient and repairNone and vehicle.getIsEntered and vehicle:getIsEntered() then
		vehicle.rvbDebugger:info("WorkshopRepair.SyncClientServer","Repair process for vehicle %s completed: requestActionEventUpdate().", vehicle:getFullName())
		vehicle:requestActionEventUpdate()
	end
end
