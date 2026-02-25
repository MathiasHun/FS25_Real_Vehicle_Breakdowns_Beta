
rvbWorkshopDialog = {}
rvbWorkshopDialog.MODE = {}
rvbWorkshopDialog.MODE.DIAGNOSTICS = 1
rvbWorkshopDialog.MODE.SERVICE_MANUAL = 2
Enum(rvbWorkshopDialog.MODE)

local function stopVehicle(vehicle)
    if vehicle == nil then return end
    if vehicle.StopAI then
        vehicle:StopAI(vehicle)
    end
    if vehicle.stopMotor then
        vehicle:stopMotor()
    end
    if vehicle.deactivateLights then
        vehicle:deactivateLights()
    end
    local specM = vehicle.spec_motorized
    if specM and specM.motor and specM.gearShiftMode then
        specM.motor:setGearShiftMode(specM.gearShiftMode)
    end
end
	
local rvbWorkshopDialog_mt = Class(rvbWorkshopDialog, MessageDialog, ScreenElement)
function rvbWorkshopDialog.register()
	local rvbworkshopdialog = rvbWorkshopDialog.new()
	g_gui:loadGui(g_vehicleBreakdownsDirectory .. "gui/dialogs/rvbWorkshopDialog.xml", "rvbWorkshopDialog", rvbworkshopdialog)
	rvbWorkshopDialog.INSTANCE = rvbworkshopdialog
end
function rvbWorkshopDialog.show(vehicle)
	if rvbWorkshopDialog.INSTANCE ~= nil then
		local dialog = rvbWorkshopDialog.INSTANCE
		dialog.vehicle = vehicle
		dialog.selectedMode = rvbWorkshopDialog.MODE.DIAGNOSTICS
		--dialog.modeUp = false
		--dialog.partBreakdowns = {}
		--dialog.serviceManual = {}
		dialog:updateScreen()
		dialog:updateButtons()
		g_gui:showDialog("rvbWorkshopDialog")
	end
end


function rvbWorkshopDialog.new(target, custom_mt)
	local dialog = MessageDialog.new(target, custom_mt or rvbWorkshopDialog_mt)
	dialog.vehicle = nil
	dialog.selectedMode = 0
	dialog.partBreakdowns = {}
	dialog.serviceManual = {}
	return dialog
end
function rvbWorkshopDialog.createFromExistingGui(self, _)
	rvbWorkshopDialog.register()
	local v16 = self.vehicle
	rvbWorkshopDialog.show(v16)
end



function rvbWorkshopDialog:onCreate(self)
end
function rvbWorkshopDialog.onOpen(self)
	rvbWorkshopDialog:superClass().onOpen(self)
	self.rvbDebugger = g_currentMission.vehicleBreakdowns.rvbDebugger
	self:updateBalanceText()
	g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.updateBalanceText, self)
	g_messageCenter:subscribe(MessageType.VEHICLE_REPAIRED, self.onVehicleRepairEvent, self)
	g_messageCenter:subscribe(MessageType.RVB_RESET_VEHICLE, self.onVehicleResetEvent, self)
	if g_modIsLoaded["FS25_gameplay_ExtendedSellingSystem"] then
		g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onextended, self)
	end
	self.refreshTimeTimer = 0
	local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
	if not workshopStatus then
		self.titleText:setText(timeInfo)
	end
	self.modeElement:setIsChecked(self.selectedMode == rvbWorkshopDialog.MODE.SERVICE_MANUAL, true)
	self.preCalculatedService = { totalTime = 0, periodicService = 0 }
	self.preCalculatedRepair = { fault = 0, faultTime = 0 }
	self:updateScreen()
	self:updateButtons()
end

function rvbWorkshopDialog.onClose(self)
	rvbWorkshopDialog:superClass().onClose(self)
	self.vehicle = nil
	g_messageCenter:unsubscribeAll(self)
	--g_currentMission:showMoneyChange(MoneyType.SHOP_VEHICLE_BUY)
end

function rvbWorkshopDialog:onClickBack()
    self:close()
end
function rvbWorkshopDialog:updateScreen()
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog:updateScreen", "Vehicle or its faultData spec is missing for vehicle '%s'.", vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local rvb = vehicle.spec_faultData
	local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()

	self.vehicleImage:setImageFilename(vehicle:getImageFilename())
	
	self.templateVehicleInfo:setVisible(false)
	for v29 = #self.settingsBox.elements, 1, -1 do
		self.settingsBox.elements[v29]:delete()
		self.settingsBox.elements[v29] = nil
	end
	local brand = g_brandManager:getBrandByIndex(vehicle:getBrand())
	local brandPrefix = brand == nil and "" or brand.title .. " "
	local sellPrice = 0
	local sellPriceText
	if vehicle.propertyState == VehiclePropertyState.OWNED then
		sellPrice = vehicle:getSellPrice() * EconomyManager.DIRECT_SELL_MULTIPLIER
		sellPrice = math.floor(sellPrice)
		sellPrice = math.min(sellPrice, vehicle:getPrice())
		sellPriceText = g_i18n:formatMoney(sellPrice, 0, true, true)
	elseif vehicle.propertyState == VehiclePropertyState.LEASED then
		sellPriceText = "-"
	elseif vehicle.propertyState == VehiclePropertyState.MISSION then
		sellPriceText = "-"
	end

		
	local vehicleData = {
		{g_i18n:getText("ui_name"), brandPrefix .. vehicle:getName()},
		{g_i18n:getText("ui_age"), string.format(g_i18n:getText("shop_age"), vehicle.age)},
		{g_i18n:getText("ui_sellValue"), sellPriceText},
		{g_i18n:getText("ui_operatingHours"), string.format(g_i18n:getText("RVB_operatingTime"), vehicle:getFormattedOperatingTime())}
	}
	local v31 = true
	for _, data in ipairs(vehicleData) do
		local element = self.templateVehicleInfo:clone(self.settingsBox)
		element:setVisible(true)
		local v38 = AISettingsDialog.COLOR_ALTERNATING[v31]
		element:setImageColor(nil, unpack(v38))
		local label = element:getDescendantByName("label")
		local value = element:getDescendantByName("value")
		label:setText(tostring(data[1]))
		value:setText(tostring(data[2]))
		v31 = not v31
	end

	self.settingsBox:invalidateLayout()

	self:infoTitle(vehicle)
	
	local isDiagnostics = self.selectedMode == rvbWorkshopDialog.MODE.DIAGNOSTICS
	local isService = self.selectedMode == rvbWorkshopDialog.MODE.SERVICE_MANUAL

	self.diagnosticsTitle:setText(g_i18n:getText("RVB_Workshop_diagnostics"))
	self.serviceManualTitle:setText(g_i18n:getText("RVB_Workshop_serviceManual"))

	self.diagnosticsTitle:setVisible(isDiagnostics)
	self.serviceManualTitle:setVisible(isService)

	if isDiagnostics then

		self.partBreakdowns = {}
		for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = rvb.parts[key]
			if part ~= nil then
				--if key ~= "TIREFL" and key ~= "TIREFR" and key ~= "TIRERL" and key ~= "TIRERR" then
					table.insert(self.partBreakdowns, part)
				--end
			end
		end

		self.diagnosticsList:setDataSource(self)
		self.diagnosticsList:setDelegate(self)
		self.diagnosticsList:reloadData()
	end
    if isService then

		self.serviceManual = {}
		local entries = vehicle:getServiceManualEntry() or {}
		for _, entry in ipairs(entries) do
			if entry then
				table.insert(self.serviceManual, {
					entryType      = entry.entryType or 0,
					entryTime      = entry.entryTime or 0,
					operatingHours = entry.operatingHours or 0,
					odometer       = entry.odometer or 0,
					resultKey      = entry.resultKey or "empty",
					errorList      = entry.errorList or {},
					cost           = entry.cost or 0
				})
			end
		end

		self.serviceManualList:setDataSource(self)
		self.serviceManualList:setDelegate(self)
		self.serviceManualList:reloadData()

	end

	self.noinspectionText:setVisible(isDiagnostics and not rvb.inspection.completed)
	self.noserviceManualEntryText:setVisible(isService and #self.serviceManual == 0)

	self.diagnosticsList:setVisible(isDiagnostics and rvb.inspection.completed)
	self.diagnosticsSliderBox:setVisible(isDiagnostics and rvb.inspection.completed)
	self.serviceManualHeader:setVisible(isService)
	self.serviceManualList:setVisible(isService)
	self.serviceManualSliderBox:setVisible(isService and #self.serviceManual > 0)
 
end
function rvbWorkshopDialog.updateButtons(self)
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog:updateButtons", "Vehicle or its faultData spec is missing for vehicle '%s'.", vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local rvb = vehicle.spec_faultData
	local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
	-- BATTERYCHARGING
	local batteryLevelPercentage = BatteryManager.getBatteryFillLevelPercentage(vehicle)
	if batteryLevelPercentage then
		if batteryLevelPercentage <= 0.5 then
			self.chargingBatteryButton:setText(string.format("%s (%s)", g_i18n:getText("RVB_button_battery_ch"), g_i18n:formatMoney(BATTERY_CHARGE_COST, 0, true, true)))
		else
			self.chargingBatteryButton:setLocaKey("RVB_button_battery_ch")
		end
	end
	self.chargingBatteryButton:setDisabled(batteryLevelPercentage >= 0.5 or not workshopStatus)
	-- INSPECTION
	local inspectionPrice = vehicle:getInspectionPrice()
	--if not rvb.inspection[1] then
	if rvb.inspection.state == INSPECTION.NONE then
		self.inspectionButton:setText(string.format("%s (%s)", g_i18n:getText("RVB_button_inspection"), g_i18n:formatMoney(inspectionPrice, 0, true, true)))
	else
		self.inspectionButton:setLocaKey("RVB_button_inspection")
	end
	local inspectionActive = rvb.inspection.state == INSPECTION_STATE.ACTIVE
	local serviceActive = rvb.service.state == SERVICE_STATE.ACTIVE
	local repairActive = rvb.repair.state == REPAIR_STATE.ACTIVE
	local repairNone = rvb.repair.state == REPAIR_STATE.NONE
	self.inspectionButton:setDisabled(inspectionActive or serviceActive or repairActive or not workshopStatus)
	-- SERVICE
	local servicePrice = vehicle:getServicePrice()
	if rvb.service.state == SERVICE_STATE.NONE then
		self.serviceButton:setText(string.format("%s (%s)", g_i18n:getText("RVB_button_service"), g_i18n:formatMoney(servicePrice, 0, true, true)))
	else
		self.serviceButton:setLocaKey("RVB_button_service")
	end
	self.serviceButton:setDisabled(serviceActive or inspectionActive or repairActive or not workshopStatus)
	-- REPAIR
	local repairPrice = vehicle:getRepairPrice_RVBClone()
	if rvb.inspection.completed then
		if repairNone and repairPrice > 100 then
			self.repairButton:setText(string.format("%s (%s)", g_i18n:getText("button_repair"), g_i18n:formatMoney(repairPrice, 0, true, true)))
		else
			self.repairButton:setLocaKey("button_repair")
		end
	else
		self.repairButton:setLocaKey("button_repair")
	end
	self.repairButton:setDisabled(repairPrice <= 100 or not rvb.inspection.completed or repairActive or inspectionActive or serviceActive)
	self.buttonsBox:invalidateLayout()
end
function rvbWorkshopDialog.updateBalanceText(self)
	local money = g_currentMission == nil and 0 or (g_currentMission:getMoney() or 0)
	self.lastBalance = money
	self.balanceElement:setValue(money)
	if money > 0 then
		self.balanceElement:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY)
	else
		self.balanceElement:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE)
	end
	if self.moneyBox ~= nil then
		self.moneyBox:invalidateLayout()
		self.moneyBoxBg:setSize(self.moneyBox.flowSizes[1] + 60 * g_pixelSizeScaledX)
	end
end
function rvbWorkshopDialog.update(self, p25)
	rvbWorkshopDialog:superClass().update(self, p25)
	local timeInfo = ""
	local timevisible = false
	self.refreshTimeTimer = self.refreshTimeTimer + p25
	if self.refreshTimeTimer > 500 then
		self.refreshTimeTimer = 0
		local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
		if not workshopStatus then
			self.titleText:setText(timeInfo)
		else
			self:infoTitle(self.vehicle)
		end
	end
	if self.needsListReload then
		self.diagnosticsList:reloadData()
		self.needsListReload = false
	end
end
function rvbWorkshopDialog.onGuiSetupFinished(self)
	rvbWorkshopDialog:superClass().onGuiSetupFinished(self)
	self.templateVehicleInfo:unlinkElement()
	FocusManager:removeElement(self.templateVehicleInfo)
	self.modeElement:setTexts({ g_i18n:getText("RVB_Workshop_diagnostics"), g_i18n:getText("RVB_Workshop_serviceManual") })
	self.diagnosticsList:setDataSource(self)
	self.serviceManualList:setDataSource(self)
end

function rvbWorkshopDialog.delete(self)
	self.templateVehicleInfo:delete()
	rvbWorkshopDialog:superClass().delete(self)
end
function rvbWorkshopDialog.onClickMode(self, state, _)
	self.selectedMode = state == 2 and rvbWorkshopDialog.MODE.SERVICE_MANUAL or rvbWorkshopDialog.MODE.DIAGNOSTICS
	self.diagnosticsList:setVisible(self.selectedMode == rvbWorkshopDialog.MODE.DIAGNOSTICS)
	self.serviceManualList:setVisible(self.selectedMode == rvbWorkshopDialog.MODE.SERVICE_MANUAL)
	self:updateScreen()
	self:updateButtons()
end

function rvbWorkshopDialog.getNumberOfItemsInSection(self, list, section)
   if self.selectedMode == rvbWorkshopDialog.MODE.DIAGNOSTICS then
        return #self.partBreakdowns
    elseif self.selectedMode == rvbWorkshopDialog.MODE.SERVICE_MANUAL then
        return #self.serviceManual
    end
    return 0
end
function rvbWorkshopDialog.onListSelectionChanged(self, _, _, p92)
	--self:setVehicle(self.vehicles[p92])
	--self:updateScreen()
	--self.selectedItem = true
end

function rvbWorkshopDialog.populateCellForItemInSection(self, list, _, index, cell)
	if self.selectedMode == rvbWorkshopDialog.MODE.DIAGNOSTICS then
        local partID = self.partBreakdowns[index]
        self:setVehicleDetails(partID, cell)
    elseif self.selectedMode == rvbWorkshopDialog.MODE.SERVICE_MANUAL then
        local partID = self.serviceManual[index]
        self:setServiceManualDetails(partID, cell)
    end
end
												  -- p75, p76
function rvbWorkshopDialog.setVehicleDetails(self, part, cell)
	
	local vehicle = self.vehicle
	local rvb = vehicle.spec_faultData
	if part ~= nil then
		
		local partName = cell:getAttribute("partName")
		local Pname = part.name
		partName:setText(g_i18n:getText("RVB_faultText_" .. Pname))
			
		local inspectionActive = rvb.inspection.state == INSPECTION_STATE.ACTIVE
		local serviceActive = rvb.service.state == SERVICE_STATE.ACTIVE
		local repairActive = rvb.repair.state == REPAIR_STATE.ACTIVE
	
		local Partfoot = 0
		if part.operatingHours ~= nil and vehicle.getPartsPercentage ~= nil then
			local partPercentage = vehicle:getPartsPercentage(Pname)
			if partPercentage == nil then
				partPercentage = 0
			end
			Partfoot = math.max(0, MathUtil.round(partPercentage))
			--Partfoot = math.max(0, MathUtil.round(vehicle:getPartsPercentage(Pname)))
			local PartValue = Partfoot / 100
			local Pfoot = 100 - Partfoot
			--print("Pname "..Pname.." getPartsPercentage "..vehicle:getPartsPercentage(Pname).." Partfoot "..Partfoot.." PartValue " ..PartValue.." Pfoot "..Pfoot)
			self:setStatusBarValue(cell:getAttribute("partBar"), 1 - PartValue)
			local partPercent = cell:getAttribute("partPercent")
			local partCondition = cell:getAttribute("partCondition")
			local checkPart = cell:getAttribute("checkPart")
			partPercent:setText(Pfoot .. "%")

			local status = ""
			local faultData = FaultRegistry[Pname]
			if faultData then
			
				local faultProne = false
				local replaceRequired = false
--print(Pname.." "..Pfoot)
				-- Állapot besorolás
				if Pfoot >=90 then
					status = g_i18n:getText("RVB_WorkshopD_new")
				elseif Pfoot >= 65 then
					status = g_i18n:getText("RVB_WorkshopD_conExcellent")
				elseif Pfoot >= 40 then
					status = g_i18n:getText("RVB_WorkshopD_conGood")
				elseif Pfoot >= 11 then
					status = g_i18n:getText("RVB_WorkshopD_conUsed")
				elseif Pfoot <= 10 then
					status = g_i18n:getText("RVB_WorkshopD_conFaults")
					faultProne = true
				else
					status = g_i18n:getText("RVB_WorkshopD_conDown")
					faultProne = true
					replaceRequired = true
				end
				-- BreakThreshold ellenőrzés
				if Pfoot <= faultData.breakThreshold then
					faultProne = true
					if Pfoot < 1 then
						replaceRequired = true
					end
				end

				-- Opció: státusz frissítése a hibára hajlamos/csere érett logika alapján
				if replaceRequired then
					status = g_i18n:getText("RVB_WorkshopD_conReplace")
				elseif faultProne then
					status = g_i18n:getText("RVB_WorkshopD_conFaults")
				end

			end
			partCondition:setText(status)
			if Partfoot < 50 then --or (Partfoot >= 99 and rvb.inspection[8]) then
				checkPart:setDisabled(true)
			elseif Partfoot >= 50 and rvb.inspection.completed then
				--partCondition:setText(g_i18n:getText("RVB_setting_"..string.lower(Pname).."Lifetime") .. " (" .. Pfoot .. "%)")
				checkPart:setDisabled(serviceActive or inspectionActive or repairActive)
			else
				checkPart:setDisabled(true)
			end

			if vehicle.getFaultParts ~= nil then
				checkPart:setIsChecked(vehicle:getFaultParts(Pname))
			end
			local partBox = partCondition.parent
			--partBox:setVisible(true and rvb.inspection[8])
		end
		local partCell = cell:getAttribute("partBar").parent
		--partCell:setVisible(rvb.inspection[8])
		

		if inspectionActive or serviceActive or repairActive then
			self:infoTitle(vehicle)
		end

	end

end

function rvbWorkshopDialog.setServiceManualDetails(self, part, cell)

	local vehicle = self.vehicle
	local rvb = vehicle.spec_faultData
	if part ~= nil then

		local entryType = cell:getAttribute("entryType")
		local serviceManNames = {
			g_i18n:getText("RVB_button_inspection"),
			g_i18n:getText("RVB_button_periodicservice"),
			g_i18n:getText("button_repair"),
			g_i18n:getText("RVB_list_battery"),
			g_i18n:getText("RVB_workshopVResetTitle")
		}
		entryType:setText(serviceManNames[part.entryType])
		local entryTime = cell:getAttribute("entryTime")
		entryTime:setText(part.entryTime .. g_i18n:getText("RVB_WorkshopS_month"))

		local operatingHours = cell:getAttribute("operatingHours")
		local hours = math.floor(part.operatingHours)
		local minutes = math.floor((part.operatingHours - hours) * 60)
		if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
		if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
		operatingHours:setText(string.format(g_i18n:getText("RVB_shop_operatingTimeG"), hours, minutes))

		local odometer = cell:getAttribute("odometer")
		odometer:setText("12343 km")

		local cost = cell:getAttribute("cost")
		cost:setText(g_i18n:formatMoney(part.cost, 0, true, true))

		local result = cell:getAttribute("result")
		--result:setText(part.result)
		local resultKey = g_i18n:getText(part.resultKey)
		local errorList = ""
		if part.entryType == 1 then
			local translatedErrors = {}
			for _, key in ipairs(part.errorList or {}) do
				table.insert(translatedErrors, g_i18n:getText(key))
			end
			if #translatedErrors > 0 then
				errorList = g_i18n:getText("RVB_ErrorList") .. " " .. table.concat(translatedErrors, ", ")
			end
		elseif part.entryType == 2 then
			for _, key in ipairs(part.errorList or {}) do
				errorList = errorList .. " " .. g_i18n:getText(key)
			end
		elseif part.entryType == 3 then
			local translatedErrors = {}
			for _, key in ipairs(part.errorList or {}) do
				table.insert(translatedErrors, g_i18n:getText(key))
			end
			if #translatedErrors > 0 then
				resultKey = string.format(g_i18n:getText(part.resultKey), table.concat(translatedErrors, ", "))
			end
		elseif part.entryType == 4 then
		elseif part.entryType == 5 then
		end
		result:setText(resultKey .. errorList)
	end
end
function rvbWorkshopDialog.infoTitle(self, vehicle)
	local rvb = vehicle.spec_faultData
	local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
	if workshopStatus then--and vehicle.propertyState == VehiclePropertyState.OWNED then
		local gText, timeText, infoText = "", "", ""
		local inspectionActive = rvb.inspection.state == INSPECTION_STATE.ACTIVE
		local serviceActive = rvb.service.state == SERVICE_STATE.ACTIVE
		local repairActive = rvb.repair.state == REPAIR_STATE.ACTIVE
		if serviceActive then
			gText = "RVB_periodicserviceTimeDialog"
			if rvb.service.finishDay > g_currentMission.environment.currentDay then
				gText = "RVB_periodicserviceDayDialog"
			end
			timeText = string.format("%02d:%02d", rvb.service.finishHour, rvb.service.finishMinute)
		elseif inspectionActive then
			gText = "RVB_inspectionTimeDialog"
			if rvb.inspection.finishDay > g_currentMission.environment.currentDay then
				gText = "RVB_inspectionDayDialog"
			end
			timeText = string.format("%02d:%02d", rvb.inspection.finishHour, rvb.inspection.finishMinute)
		elseif repairActive then
			if rvb.inspection.completed then
				gText = "RVB_repairTimeDialog"
				if rvb.repair.finishDay > g_currentMission.environment.currentDay then
					gText = "RVB_repairDayDialog"
				end
				timeText = string.format("%02d:%02d", rvb.repair.finishHour, rvb.repair.finishMinute)
			end
		end
		if gText ~= "" then
			infoText = string.format(g_i18n:getText(gText), timeText)
		end
		self.titleText:setText(infoText)
	end
end
function rvbWorkshopDialog.onClickPart(self, state, element)
	local list = self.diagnosticsList
	local sectionIndex, itemIndex = list:getSelectedPath()
	local part = self.partBreakdowns[itemIndex]
	if part then
		self.vehicle:setPartsRepairreq(part.name, element:getIsChecked())
		self:updateButtons()
		self.needsListReload = true
		self.rvbDebugger:info("rvbWorkshopDialog.onClickPart", "Repair Part %s: \'%s\'", part.name, tostring(element:getIsChecked()))
	end
end
function rvbWorkshopDialog.setStatusBarValue(_, bar, value)
	local lastBar = (bar.lastStatusBarValue or -1) - value
	if math.abs(lastBar) > 0.01 then
		local fullWidth = bar.parent.size[1] - bar.margin[1] * 2
		local minSize = bar.startSize == nil and 0 or bar.startSize[1] + bar.endSize[1]
		local maxSize = fullWidth * math.min(value, 1)
		bar:setSize(math.max(minSize, maxSize), nil)
		bar.lastStatusBarValue = value
	end
end
function rvbWorkshopDialog.onClickResetVehicle(self, _, _)
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog.onClickResetVehicle", "Vehicle or its faultData spec is missing for vehicle '%s'.",
		vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local rvb = vehicle.spec_faultData
	local title = g_i18n:getText("RVB_workshopVResetTitle")
	local text = string.format(g_i18n:getText("RVB_workshopVResetDesc"), vehicle:getFullName())
	local callback = self.onYesNoResetVehicleDialog
	local sound = GuiSoundPlayer.SOUND_SAMPLES.CONFIG_WRENCH
	YesNoDialog.show(callback, self, text, title, nil, nil, nil, sound)
	return true
end
function rvbWorkshopDialog.onYesNoResetVehicleDialog(self, yes)
	if yes then
		local vehicle = self.vehicle
		g_client:getServerConnection():sendEvent(RVBResetVehicle_Event.new(vehicle, true))
		stopVehicle(vehicle)
		self:updateScreen()
		self:updateButtons()
		--g_workshopScreen.list:reloadData()
		g_workshopScreen.needsListReload = true
	end
end
function rvbWorkshopDialog.onVehicleResetEvent(self, vehicle, _)
	if vehicle == self.vehicle then
		self:updateScreen()
		self:updateButtons()
	end
end
function rvbWorkshopDialog.onClickChargingBattery(self, _, _)
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog.onClickChargingBattery", "Vehicle or its faultData spec is missing for vehicle '%s'.",
		vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local rvb = vehicle.spec_faultData
	local text = string.format(g_i18n:getText("RVB_batteryChDialog"), g_i18n:formatMoney(BATTERY_CHARGE_COST, 0, true, true))
	local callback = self.onYesNoChargingBatteryDialog
	local yesSound = GuiSoundPlayer.SOUND_SAMPLES.CONFIG_SPRAY
	YesNoDialog.show(callback, self, text, nil, nil, nil, nil, yesSound)
	return true
end
function rvbWorkshopDialog.onYesNoChargingBatteryDialog(self, yes)
	local vehicle = self.vehicle
	if not (yes and vehicle and vehicle.spec_faultData) then
		return
	end
	local cost = BATTERY_CHARGE_COST
	if g_currentMission:getMoney() < cost then
		InfoDialog.show(g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
		return
	end
	g_client:getServerConnection():sendEvent(BatteryFillUnitFillLevelEvent.new(vehicle))
	stopVehicle(vehicle)
	self:updateScreen()
	self:updateButtons()
end
function rvbWorkshopDialog.onClickInspection(self, _, _)
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog.onClickInspection", "Vehicle or its faultData spec is missing for vehicle '%s'.",
		vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local RVB = g_currentMission.vehicleBreakdowns
	local GPSET = RVB.gameplaySettings
	if RVB.workshopCount >= GPSET.workshopCountMax then
		InfoDialog.show(string.format(g_i18n:getText("RVB_repairErrorMechanics"), GPSET.workshopCountMax))
		self.rvbDebugger:info("rvbWorkshopDialog.onClickInspection", "All mechanics are busy, only up to %s vehicles can be serviced at the same time.", GPSET.workshopCountMax)
		return
	end

	local isOwnWorkshop = g_rvbMain:isAlwaysOpenWorkshop()
	if isOwnWorkshop then
		INSPECTION.TIME = INSPECTION.TIME + math.random(10*60, 30*60)
	end
	local AddHour = math.floor(INSPECTION.TIME / 3600)
	local AddMinute = math.floor(((INSPECTION.TIME / 3600) - AddHour) * 60)
	local FinishDay, FinishHour, FinishMinute = vehicle:CalculateFinishTime(AddHour, AddMinute)
	local timeText = string.format("%02d:%02d", FinishHour, FinishMinute)
	local DialogInspectionText = "RVB_inspectionTimeDialog"
	if FinishDay > g_currentMission.environment.currentDay then
		DialogInspectionText = "RVB_inspectionDayDialog"
	end
	local text = string.format(g_i18n:getText("RVB_inspectionDialog"), g_i18n:formatMoney(vehicle:getInspectionPrice(), 0, true, true)).."\n"..
				 string.format(g_i18n:getText(DialogInspectionText), timeText)
	local callback = self.onYesNoInspectionDialog
	local yesSound = GuiSoundPlayer.SOUND_SAMPLES.CONFIG_SPRAY
	YesNoDialog.show(callback, self, text, nil, nil, nil, nil, yesSound)
	return true
end
function rvbWorkshopDialog.onYesNoInspectionDialog(self, yes)
	local vehicle = self.vehicle
	if not (yes and vehicle and vehicle.spec_faultData) then
		return
	end
	local rvb = vehicle.spec_faultData
	local cost = vehicle:getInspectionPrice()
	if g_currentMission:getMoney() < cost then
		InfoDialog.show(g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
		return
	end
	
	local farmId = g_currentMission:getFarmId()
	--RVBInspectionRequest_Event.sendEvent(vehicle, farmId)
	g_client:getServerConnection():sendEvent(RVBInspectionRequest_Event.new(vehicle, farmId))

	stopVehicle(vehicle)
	self:updateScreen()
	self:updateButtons()

	--g_workshopScreen.list:reloadData()
	g_workshopScreen.needsListReload = true

end
function rvbWorkshopDialog.onClickService(self, _, _)
    local vehicle = self.vehicle
    if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog.onClickService", "Vehicle or its faultData spec is missing for vehicle '%s'.",
		vehicle and vehicle:getFullName() or "unknown")
        return false
    end
	local RVB = g_currentMission.vehicleBreakdowns
	local GPSET = RVB.gameplaySettings
	if RVB.workshopCount >= GPSET.workshopCountMax then
		InfoDialog.show(string.format(g_i18n:getText("RVB_repairErrorMechanics"), GPSET.workshopCountMax))
		self.rvbDebugger:info("rvbWorkshopDialog.onClickService", "All mechanics are busy, only up to %s vehicles can be serviced at the same time.", GPSET.workshopCountMax)
		return
	end
    local specRVB = vehicle.spec_faultData
    local periodicService = RVB:getPeriodicService()
	local isOwnWorkshop = g_rvbMain:isAlwaysOpenWorkshop()
	if isOwnWorkshop then
		SERVICE.BASE_TIME = SERVICE.BASE_TIME + math.random(20*60, 40*60)
	end
    local hoursOverdue = math.max(0, math.floor(specRVB.operatingHours) - periodicService)
    local additionalTime = hoursOverdue * SERVICE.TIME
    local totalServiceTime = SERVICE.BASE_TIME + additionalTime
    local AddHour = math.floor(totalServiceTime / 3600)
    local AddMinute = math.floor(((totalServiceTime / 3600) - AddHour) * 60)
    local FinishDay, FinishHour, FinishMinute = vehicle:CalculateFinishTime(AddHour, AddMinute)
    self.preCalculatedService = {
        totalTime = totalServiceTime,
        periodicService = periodicService
    }
    local timeText = string.format("%02d:%02d", FinishHour, FinishMinute)
    local DialogServiceText = "RVB_periodicserviceTimeDialog"
    if FinishDay > g_currentMission.environment.currentDay then
        DialogServiceText = "RVB_periodicserviceDayDialog"
    end
    local text = string.format(g_i18n:getText("RVB_periodicserviceDialog"), g_i18n:formatMoney(vehicle:getServicePrice())) .. "\n" ..
                 string.format(g_i18n:getText(DialogServiceText), timeText)
    local callback = self.onYesNoServiceDialog
    local yesSound = GuiSoundPlayer.SOUND_SAMPLES.CONFIG_SPRAY
    YesNoDialog.show(callback, self, text, nil, nil, nil, nil, yesSound)
    return true
end
function rvbWorkshopDialog.onYesNoServiceDialog(self, yes)
    local vehicle = self.vehicle
    if not (yes and vehicle and vehicle.spec_faultData) then
        return
    end
    local cost = vehicle:getServicePrice()
    if g_currentMission:getMoney() < cost then
        InfoDialog.show(g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
        return
    end
    local rvb = vehicle.spec_faultData
    local preCalc = self.preCalculatedService
    if not preCalc then
		self.rvbDebugger:error("rvbWorkshopDialog.onYesNoServiceDialog", "No pre-calculated service time found!")
        return
    end
	
	local farmId = g_currentMission:getFarmId()
	--RVBServiceRequest_Event.sendEvent(vehicle, farmId)
	g_client:getServerConnection():sendEvent(RVBServiceRequest_Event.new(vehicle, farmId))
	
    stopVehicle(vehicle)
    self:updateScreen()
	self:updateButtons()
	--g_workshopScreen.list:reloadData()
	g_workshopScreen.needsListReload = true
end
function rvbWorkshopDialog.onClickRepair(self, _, _)
	local vehicle = self.vehicle
	if not (vehicle and vehicle.spec_faultData) then
		self.rvbDebugger:warning("rvbWorkshopDialog.onClickRepair", "Vehicle or its faultData spec is missing for vehicle '%s'.",
		vehicle and vehicle:getFullName() or "unknown")
		return false
	end
	local RVB = g_currentMission.vehicleBreakdowns
	local GPSET = RVB.gameplaySettings
	if RVB.workshopCount >= GPSET.workshopCountMax then
		InfoDialog.show(string.format(g_i18n:getText("RVB_repairErrorMechanics"), GPSET.workshopCountMax))
		self.rvbDebugger:info("rvbWorkshopDialog.onClickRepair", "All mechanics are busy, only up to %s vehicles can be serviced at the same time.", GPSET.workshopCountMax)
		return
	end
	local rvb = vehicle.spec_faultData
	if vehicle:getRepairPrice_RVBClone(true) <= 100 then
		return false
	end
	local faultListTime = 0
	local faultListText = {}
	for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = rvb.parts[key]
		if part and part.repairreq then
			table.insert(faultListText, g_i18n:getText(FaultRegistry[key].name))
			faultListTime = faultListTime + FaultRegistry[key].repairTime
		end
	end
	local isOwnWorkshop = g_rvbMain:isAlwaysOpenWorkshop()
	if isOwnWorkshop then
		faultListTime = faultListTime + math.random(30*60, 50*60)
	end
	local AddHour = math.floor(faultListTime / 3600)
	local AddMinute = math.floor(((faultListTime / 3600) - AddHour) * 60)
	local FinishDay, FinishHour, FinishMinute = vehicle:CalculateFinishTime(AddHour, AddMinute)
	self.preCalculatedRepair = {
		fault = #faultListText,
		faultTime = faultListTime
    }
	local timeText = string.format("%02d:%02d", FinishHour, FinishMinute)
	local DialogRepairText = "RVB_repairTimeDialog"
	if FinishDay > g_currentMission.environment.currentDay then
		DialogRepairText = "RVB_repairDayDialog"
	end
	if #faultListText > 0 then
		local text = string.format(g_i18n:getText("ui_repairDialog"), g_i18n:formatMoney(self.vehicle:getRepairPrice_RVBClone(true))).."\n"..
					 string.format(g_i18n:getText(DialogRepairText), timeText).."\n"..g_i18n:getText("RVB_ErrorList").."\n"..table.concat(faultListText,", ")
		local callback = self.onYesNoRepairDialog
		local yesSound = GuiSoundPlayer.SOUND_SAMPLES.CONFIG_WRENCH
		YesNoDialog.show(callback, self, text, nil, nil, nil, nil, yesSound)
	end
	return true
end
function rvbWorkshopDialog.onYesNoRepairDialog(self, yes)
	local vehicle = self.vehicle
	if not (yes and vehicle and vehicle.spec_faultData) then
		return
	end
	local rvb = vehicle.spec_faultData
	local cost = vehicle:getRepairPrice_RVBClone()
	if g_currentMission:getMoney() < cost then
		InfoDialog.show(g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
		return
	end
	local damage = vehicle.spec_wearable.damage
	local currentDamageLevel = math.ceil((1 - damage)*100)
	local preCalc = self.preCalculatedRepair
    if not preCalc then
		self.rvbDebugger:error("rvbWorkshopDialog.onYesNoRepairDialog", "No pre-calculated repair time found!")
        return
    end
	
	local farmId = g_currentMission:getFarmId()
	--RVBRepairRequest_Event.sendEvent(vehicle, farmId)
	g_client:getServerConnection():sendEvent(RVBRepairRequest_Event.new(vehicle, farmId))

	stopVehicle(vehicle)
	self:updateScreen()
	self:updateButtons()
	--g_workshopScreen.list:reloadData()
	g_workshopScreen.needsListReload = true
end
function rvbWorkshopDialog.onVehicleRepairEvent(self, vehicle, _)
	if vehicle == self.vehicle then
		self:updateScreen()
		self:updateButtons()
	end
end
function rvbWorkshopDialog.onextended(self)
	self:updateScreen()
	self:updateButtons()
end
