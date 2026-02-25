
WorkshopService = {}
	
function WorkshopService.start(vehicle, farmId)
    local spec = vehicle.spec_faultData

    if spec.service.state ~= SERVICE_STATE.NONE then
        return
    end

    local cost = vehicle:getServicePrice()
    if g_currentMission:getMoney(farmId) < cost then
		print("WorkshopService:start(): " .. g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
        return
    end

	local RVB = g_currentMission.vehicleBreakdowns
	local periodicService = RVB:getPeriodicService()
    local hoursOverdue = math.max(0, math.floor(spec.operatingHours) - periodicService)
    local additionalTime = hoursOverdue * SERVICE.TIME
    local totalServiceTime = SERVICE.BASE_TIME + additionalTime
    local AddHour = math.floor(totalServiceTime / 3600)
    local AddMinute = math.floor(((totalServiceTime / 3600) - AddHour) * 60)
    local d,h,m = vehicle:CalculateFinishTime(AddHour, AddMinute)
	local service = spec.service

    service.state = SERVICE_STATE.ACTIVE
    service.finishDay = d
    service.finishHour = h
    service.finishMinute = m
    service.cost = cost

    RVBService_Event.sendEvent(vehicle, service, {result=false,cost=0,text=""})

	local RVB = g_currentMission.vehicleBreakdowns
	if not RVB.workshopVehicles[vehicle] then
		RVB.workshopVehicles[vehicle] = true
		RVB.workshopCount = RVB.workshopCount + 1
		WorkshopCount_Event.sendEvent(RVB.workshopCount)
	end

end
function WorkshopService.update(vehicle, dt)
    if not vehicle.isServer then return end

    local spec = vehicle.spec_faultData
    local service = spec.service

    local state = service.state or SERVICE_STATE.NONE

    if state == SERVICE_STATE.NONE then
        return
    end

    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day, hour, minute = env.currentDay, env.currentHour, env.currentMinute
    local insDay, insHour, insMinute = service.finishDay or 0, service.finishHour or 0, service.finishMinute or 0
	local manualDesc_more = ""

    if state == SERVICE_STATE.ACTIVE then
        if minute % 5 == 0 and spec.alertMessage["service"] ~= minute then
            spec.alertMessage["service"] = minute
			--table.insert(spec.uiProgressMessage, {
			--	key  = "service",
			--	text = "RVB_alertmessage_service"
			--})
			--vehicle:raiseDirtyFlags(spec.uiEventsDirtyFlag)
			--if vehicle.isServer and vehicle.isClient then
			--	g_messageCenter:publish(MessageType.RVB_PROGRESS_MESSAGE, vehicle, "service", "RVB_alertmessage_service")
			--end
			vehicle:addBlinkingMessage("service", "RVB_alertmessage_service")
        end

		local moreservice = 0
		local servicePeriodic = math.floor(spec.operatingHours)
		if servicePeriodic > RVBSET:getPeriodicService() then
			moreservice = math.floor(servicePeriodic - RVBSET:getPeriodicService())
		end

		local serviceTime = SERVICE.BASE_TIME
		if moreservice > 0 then
			serviceTime = serviceTime + SERVICE.TIME * moreservice
			manualDesc_more = string.format(g_i18n:getText("RVB_WorkshopMessage_service"), moreservice)
		end
		if not spec.startingService then
			spec.startingService = spec.operatingHours
			vehicle.rvbDebugger:info("WorkshopService.update", "VehicleBreakdowns:updateService startingService: %s", spec.startingService)
		end

		if serviceTime > 0 then
			local servicePerSecond = spec.startingService  / serviceTime
			local reduction = servicePerSecond * (dt / 1000) * g_currentMission.missionInfo.timeScale
			if reduction ~= 0 and spec.operatingHours > 0 then
				spec.serviceToChange = spec.serviceToChange + reduction
				local serviceToChange = spec.serviceToChange
				if math.abs(serviceToChange) > 0.1 then
					reduction = spec.serviceToChange
					spec.serviceToChange = 0
					spec.operatingHours = math.max(spec.operatingHours - reduction, 0)
					vehicle:raiseDirtyFlags(spec.rvbdirtyFlag)
					vehicle.rvbDebugger:info("WorkshopService.update", "VehicleBreakdowns:updateService  serviceTime: %s", spec.operatingHours)
				end
			end
		end
    end

    if day > insDay or (day == insDay and hour > insHour) or (day == insDay and hour == insHour and minute >= insMinute) then
        vehicle:finishService(spec, manualDesc_more)
    end

    --if state == SERVICE_STATE.ACTIVE or state == SERVICE_STATE.PAUSED then
    --    vehicle:raiseActive()
    --end
	if state == SERVICE_STATE.ACTIVE then
		vehicle:openHoodForWorkshop(true)
		vehicle:raiseActive()
	elseif state == SERVICE_STATE.PAUSED then
		vehicle:openHoodForWorkshop(false)
		vehicle:raiseActive()
	end
end
function WorkshopService.finish(vehicle, spec, manualDesc_more)
    local service = spec.service
    local RVBSET = g_currentMission.vehicleBreakdowns
    local env = g_currentMission.environment
    local day = env.currentDay

	spec.startingService = nil
	local specM = vehicle.spec_motorized
	if specM then
		specM.motorTemperature.value = vehicle.currentTemperaturDay
		specM.motorFan.enableTemperature = 95
		specM.motorFan.disableTemperature = 85
	end

    --local manualDesc = g_i18n:getText("RVB_WorkshopMessage_serviceDone")
	--manualDesc_more = manualDesc_more or ""
	--if manualDesc_more ~= "" then
	--	manualDesc = manualDesc .. " " .. manualDesc_more
	--end
    local keyText = "RVB_serviceDialogEnd"
    local removeMoney = service.cost

    local message = {
        result = true,
        cost = removeMoney,
        text = keyText
    }

    local entry = {
        entryType = SERVICE.SERVICE_MANUAL,
        entryTime = day,
        operatingHours = spec.totaloperatingHours,
        odometer = 0,
        --result = manualDesc,
		resultKey = "RVB_WorkshopMessage_serviceDone",
		errorList = manualDesc_more,
        cost = removeMoney
    }

    service.state = SERVICE_STATE.NONE
    service.finishDay, service.finishHour, service.finishMinute, service.cost, service.factor, service.completed = 0,0,0,0,0,true
    spec.alertMessage["service"] = -1

	RVBserviceManual_Event.sendEvent(vehicle, entry)
	RVBService_Event.sendEvent(vehicle, spec.service, message)
	
	spec.operatingHours = 0
	vehicle:raiseDirtyFlags(spec.rvbdirtyFlag)

    local RVB = g_currentMission.vehicleBreakdowns
    if RVB.workshopVehicles[vehicle] then
        RVB.workshopVehicles[vehicle] = nil
        RVB.workshopCount = RVB.workshopCount - 1
        WorkshopCount_Event.sendEvent(RVB.workshopCount)
    end
	vehicle:openHoodForWorkshop(false)
end
function WorkshopService.SyncClientServer(vehicle, service, message)
	local spec = vehicle.spec_faultData
	spec.service = service
	if spec.service.state == SERVICE_STATE.ACTIVE then
		vehicle.rvbDebugger:info("WorkshopService.SyncClientServer", "The service of vehicle %s has started. Activated in the updateService(dt) function.", vehicle:getFullName())
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
				notiMessage = string.format(g_i18n:getText(message.text), vehicle:getFullName(), g_i18n:formatMoney(vehicle:getServicePrice(true)))
			end
			g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notiMessage, 10000, GuiSoundPlayer.SOUND_SAMPLES.SUCCESS)
		end
	end
	local s = spec.service
	vehicle.rvbDebugger:info(
		"WorkshopService.SyncClientServer", 
		"The service of vehicle %s has been completed. Service data block: state=%s finishday=%s finishhour=%s finishminute=%s cost=%s",
		vehicle:getFullName(),
		tostring(s.state), tostring(s.finishDay), tostring(s.finishHour), tostring(s.finishMinute), tostring(s.cost)
	)
	local serviceNone = spec.service.state == SERVICE_STATE.NONE
	if vehicle.isClient and serviceNone and vehicle.getIsEntered and vehicle:getIsEntered() then
		vehicle.rvbDebugger:info("WorkshopService.SyncClientServer", "Service process for vehicle %s completed: requestActionEventUpdate().", vehicle:getFullName())
		vehicle:requestActionEventUpdate()
	end
end
