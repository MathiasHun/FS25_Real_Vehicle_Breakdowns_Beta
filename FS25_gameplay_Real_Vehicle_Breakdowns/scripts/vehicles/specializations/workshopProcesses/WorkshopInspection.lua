
WorkshopInspection = {}
	
function WorkshopInspection.start(vehicle, farmId)
    local spec = vehicle.spec_faultData
    if spec.inspection.state ~= INSPECTION_STATE.NONE then
        return
    end

    local cost = vehicle:getInspectionPrice()
    if g_currentMission:getMoney(farmId) < cost then
		print("WorkshopInspection:startInspection(): " .. g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
        return
    end
	
    local AddHour = math.floor(INSPECTION.TIME / 3600)
    local AddMinute = math.floor(((INSPECTION.TIME / 3600) - AddHour) * 60)
    local d,h,m = vehicle:CalculateFinishTime(AddHour, AddMinute)
	local inspection = spec.inspection

    inspection.state = INSPECTION_STATE.ACTIVE
    inspection.finishDay = d
    inspection.finishHour = h
    inspection.finishMinute = m
    inspection.cost = cost

    RVBInspection_Event.sendEvent(vehicle, inspection, {result=false,cost=0,text=""})
	
	local RVB = g_currentMission.vehicleBreakdowns
	if not RVB.workshopVehicles[vehicle] then
		RVB.workshopVehicles[vehicle] = true
		RVB.workshopCount = RVB.workshopCount + 1
		WorkshopCount_Event.sendEvent(RVB.workshopCount)
	end
end

function WorkshopInspection.update(vehicle, dt)
    if not vehicle.isServer then return end

    local spec = vehicle.spec_faultData
    local inspection = spec.inspection

    local state = inspection.state or INSPECTION_STATE.NONE

    if state == INSPECTION_STATE.NONE then
        return
    end

    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day, hour, minute = env.currentDay, env.currentHour, env.currentMinute
    local insDay, insHour, insMinute = inspection.finishDay, inspection.finishHour, inspection.finishMinute

    -- ProgressMessage kezelése 5 percenként
    if state == INSPECTION_STATE.ACTIVE then
        if minute % 5 == 0 and spec.alertMessage["inspection"] ~= minute then
            spec.alertMessage["inspection"] = minute
			--table.insert(spec.uiProgressMessage, {
			--	key  = "inspection",
			--	text = "RVB_alertmessage_inspection"
			--})
			--vehicle:raiseDirtyFlags(spec.uiEventsDirtyFlag)
			--if vehicle.isServer and vehicle.isClient then
			--	g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, vehicle, "inspection", "RVB_alertmessage_inspection")
			--end
			vehicle:addBlinkingMessage("inspection", "RVB_alertmessage_inspection")
        end

    end

    if day > insDay or (day == insDay and hour > insHour) or (day == insDay and hour == insHour and minute >= insMinute) then
        vehicle:finishInspection(spec)
    end

    -- Minden aktív vagy szüneteltetett inspection esetén frissítjük az aktivitást
    --if state == INSPECTION_STATE.ACTIVE or state == INSPECTION_STATE.PAUSED then
    --    vehicle:raiseActive()
    --end
	if state == INSPECTION_STATE.ACTIVE then
		vehicle:openHoodForWorkshop(true)
		vehicle:raiseActive()
	elseif state == INSPECTION_STATE.PAUSED then
		vehicle:openHoodForWorkshop(false)
		vehicle:raiseActive()
	end
end

function WorkshopInspection.finish(vehicle, spec)
    local inspection = spec.inspection
    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day = env.currentDay

    local faultTexts = {}
    for i, key in ipairs(g_vehicleBreakdownsPartKeys) do
        local part = spec.parts[key]
        local faultData = FaultRegistry[key]
        if part and faultData then
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, key)
            local partFoot = (part.operatingHours * 100) / maxLifetime
            local shouldBreak = faultData.strictBreak and (partFoot >= faultData.breakThreshold) or (partFoot > faultData.breakThreshold)
            --local criticalLevel = faultData.hud and (faultData.hud.temperatureBased and partFoot >= faultData.hud.temp.critical or partFoot >= faultData.hud.condition.critical) or false
            local criticalLevel
			if faultData.hud ~= nil and faultData.hud.temperatureBased then
				criticalLevel = partFoot >= faultData.hud.temp.critical
			else
				criticalLevel = partFoot >= faultData.hud.condition.critical
			end
			local thresholdPassed = faultData.threshold and faultData.threshold(vehicle, 0, true) or false
            local needsNewFault = part.fault == nil or part.fault == "empty"

            if shouldBreak and (thresholdPassed or criticalLevel) and needsNewFault then
                local valid = getValidFaultVariants(vehicle, key, true)
                if valid then
                    part.fault = valid
                    part.repairreq = true
                    spec.faultList[i] = true
                    vehicle.rvbDebugger:info("WorkshopInspection.finish", "Vehicle part error: %s, specific error: %s", part.name, valid)
                end
            end

            if part.repairreq then
                --table.insert(faultTexts, g_i18n:getText("RVB_faultText_" .. part.name))
				table.insert(faultTexts, "RVB_faultText_" .. part.name)
            end
        end
    end

	local specM = vehicle.spec_motorized
	if specM then
		specM.motorTemperature.value = vehicle.currentTemperaturDay
		specM.motorFan.enableTemperature = 95
		specM.motorFan.disableTemperature = 85
	end

    -- Ellenőrzés és üzenet összeállítás
    local serviceManualDesc = #faultTexts > 0 and
        g_i18n:getText("RVB_WorkshopS_repNeed") .. g_i18n:getText("RVB_ErrorList") .. " " .. table.concat(faultTexts, ", ") or
        g_i18n:getText("RVB_WorkshopS_repNoNeed")
	local resultKey = (#faultTexts > 0) and "RVB_WorkshopS_repNeed" or "RVB_WorkshopS_repNoNeed"
	local errorList = faultTexts
	
    local keyText = #faultTexts > 0 and "RVB_inspectionDialogFault" or
        (vehicle:getDamageAmount() >= 0.90 and "RVB_inspectionDialogEnd_other" or "RVB_inspectionDialogEnd")

    local removeMoney = inspection.cost
    if #faultTexts == 0 and vehicle:getDamageAmount() >= 0.90 then
        removeMoney = removeMoney + vehicle:getRepairPrice()
        vehicle:setDamageAmount(math.random(20,50), true)
    end
				
    local message = {
        result = (#faultTexts == 0),
        cost = removeMoney,
        text = keyText
    }

    local entry = {
        entryType = INSPECTION.SERVICE_MANUAL,
        entryTime = day,
        operatingHours = spec.totaloperatingHours,
        odometer = 0,
        --result = serviceManualDesc,
		resultKey = resultKey,
		errorList = errorList,
        cost = removeMoney
    }
				
    -- Inspection státusz reset
    inspection.state = INSPECTION_STATE.NONE
    inspection.finishDay, inspection.finishHour, inspection.finishMinute, inspection.cost, inspection.factor, inspection.completed = 0,0,0,0,0,true
    spec.alertMessage["inspection"] = -1

    -- Eventek elküldése
    RVBserviceManual_Event.sendEvent(vehicle, entry)
    RVBParts_Event.sendEvent(vehicle, spec.parts)
    RVBInspection_Event.sendEvent(vehicle, spec.inspection, message)

    local RVB = g_currentMission.vehicleBreakdowns
    if RVB.workshopVehicles[vehicle] then
        RVB.workshopVehicles[vehicle] = nil
        RVB.workshopCount = RVB.workshopCount - 1
        WorkshopCount_Event.sendEvent(RVB.workshopCount)
    end
	
	vehicle:openHoodForWorkshop(false)
end
function WorkshopInspection.SyncClientServer(vehicle, inspection, message)
	local spec = vehicle.spec_faultData
	spec.inspection = inspection
	if spec.inspection.state == INSPECTION_STATE.ACTIVE then
		vehicle.rvbDebugger:info("WorkshopInspection.SyncClientServer", "The inspection of vehicle %s has started. Activated in the updateInspection(dt) function.", vehicle:getFullName())
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
				notiMessage = string.format(g_i18n:getText(message.text), vehicle:getFullName(), g_i18n:formatMoney(vehicle:getInspectionPrice(true)))
			end
			g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notiMessage, 10000, GuiSoundPlayer.SOUND_SAMPLES.SUCCESS)
		end
	end

	local i = spec.inspection
	vehicle.rvbDebugger:info(
		"WorkshopInspection.SyncClientServer", 
		"The inspection of vehicle %s has been completed. Inspection data block: state=%s finishDay=%s finishHour=%s finishMinute=%s cost=%s factor=%s completed=%s",
		vehicle:getFullName(),
		tostring(i.state), tostring(i.finishDay), tostring(i.finishHour), tostring(i.finishMinute),
		tostring(i.cost),	tostring(i.factor), tostring(i.completed)
	)
	local inspectionNone = spec.inspection.state == INSPECTION_STATE.NONE
	if vehicle.isClient and inspectionNone and vehicle.getIsEntered and vehicle:getIsEntered() then
		vehicle.rvbDebugger:info("WorkshopInspection.SyncClientServer", "Inspection process for vehicle %s completed: requestActionEventUpdate().", vehicle:getFullName())
		vehicle:requestActionEventUpdate()
	end
end
