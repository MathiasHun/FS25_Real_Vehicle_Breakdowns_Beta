
rvbWorkshopScreen = {}
rvbWorkshopScreen.rvb_uytBtnDel = false

function rvbWorkshopScreen.onRepairButton(self)
	rvbWorkshopDialog.show(self.vehicle)
end
function rvbWorkshopScreen.setVehicle(self, vehicle)
	if self.repairCallback == nil and self.repairButton.onClickCallback ~= nil then
		self.repairCallback = self.repairButton.onClickCallback
	end
	if vehicle ~= nil and vehicle.spec_faultData ~= nil and vehicle.spec_faultData.isrvbSpecEnabled then
		self.repairButton.onClickCallback = function()
			rvbWorkshopScreen.onRepairButton(self)
		end
		self.repairButton:setText(g_i18n:getText("RVB_Workshop"))
		self.repairButton:setDisabled(false)
		
		if g_modIsLoaded["FS25_useYourTyres"] and self.uytBtn ~= nil then
			self.uytBtn:setVisible(false)
			self.uytBtn:setDisabled(true)
		end
	else
		self.repairButton.onClickCallback = self.repairCallback
	end
end
WorkshopScreen.setVehicle = Utils.appendedFunction(WorkshopScreen.setVehicle, rvbWorkshopScreen.setVehicle)
function rvbWorkshopScreen.update(self, dt)
	if self.vehicle ~= nil then
		if self.vehicle.spec_faultData ~= nil and not self.vehicle.spec_faultData.isrvbSpecEnabled then return end
		if g_modIsLoaded["FS25_useYourTyres"] and self.uytBtn ~= nil and not rvbWorkshopScreen.rvb_uytBtnDel then
			self.uytBtn:setVisible(false)
			self.uytBtn:setDisabled(true)
			rvbWorkshopScreen.rvb_uytBtnDel = true
		end
	end
end
if g_modIsLoaded["FS25_useYourTyres"] then
	WorkshopScreen.update = Utils.appendedFunction(WorkshopScreen.update, rvbWorkshopScreen.update)
end
function rvbWorkshopScreen:WorkshopScreen_setVehicleDetails(vehicle, cell)
	if vehicle ~= nil then
		local rvb = vehicle.spec_faultData
		if rvb == nil or not rvb.isrvbSpecEnabled then
			return
		end
		if cell.actionText == nil then
			local operatingText = cell:getDescendantByName("operatingHoursText")
			if operatingText ~= nil then
				local actionText = operatingText:clone(cell, false, true)
				actionText.name = "actionText"
				actionText:applyProfile("fs25_savegameListItemText_rvb")
				actionText:setText("")
				cell.actionText = actionText
				--print(actionText.absPosition[1], actionText.absPosition[2])
				--print(actionText.absSize[1], actionText.absSize[2])
			end
		end
		local workshopStatus, timeInfo = g_currentMission.vehicleBreakdowns:getWorkshopStatusMessage()
		local infoText = ""
		if workshopStatus then
			local gText, timeText = "", ""
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
		end
		cell.actionText:setText(infoText)
	end
end
WorkshopScreen.setVehicleDetails = Utils.appendedFunction(WorkshopScreen.setVehicleDetails, rvbWorkshopScreen.WorkshopScreen_setVehicleDetails)