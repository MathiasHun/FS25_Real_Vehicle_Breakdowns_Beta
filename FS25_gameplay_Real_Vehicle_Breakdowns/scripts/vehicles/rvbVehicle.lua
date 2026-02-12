
rvbVehicle = {}

function rvbVehicle.getSpeedLimit(self, superFunc, onlyIfWorking)
    local limit, doCheck = superFunc(self, onlyIfWorking)

    local rvb = self.spec_faultData
    if rvb == nil or not rvb.isrvbSpecEnabled then
        return limit, doCheck
    end
    local fault = rvb.parts[ENGINE] and rvb.parts[ENGINE].fault
    local hasEngineFault =
        fault == "misfiring"
        or fault == "overheating"
        or fault == "lowOilPressure"
    if hasEngineFault then
        limit = math.min(limit or math.huge, 7)
    end

    local implements = self:getAttachedImplements()
    if implements ~= nil then
        for _, implement in pairs(implements) do
            if implement.object ~= nil then
                local speed, implementDoCheckSpeedLimit = implement.object:getSpeedLimit(onlyIfWorking)
                if onlyIfWorking == nil or (onlyIfWorking and implementDoCheckSpeedLimit) then
                    limit = math.min(limit or math.huge, speed or math.huge)
                    if hasEngineFault then
                        limit = math.min(limit, 3)
                    end
                end
                doCheck = doCheck or implementDoCheckSpeedLimit
            end
        end
    end
    return limit, doCheck
end
function rvbVehicle.showInfo(self, box)
	local rvb = self.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then
		return
	end
	if not g_modIsLoaded["FS25_InfoDisplayExtension"] then
		if self.ideHasPower == nil and self.isDeleted == false then
			local powerConfig = Motorized.loadSpecValuePowerConfig(self.xmlFile)
			self.ideHasPower = 0
			if powerConfig ~= nil then
				for configName, config in pairs(self.configurations) do
					if powerConfig[configName] ~= nil then
						local configPower = powerConfig[configName][config]
						if configPower ~= nil then
							self.ideHasPower = configPower
						end
					end
				end
			end
		end
		box:addLine(g_i18n:getText("infohud_mass"), string.format("%1.2f t\n", self:getTotalMass()))
		if self.ideHasPower ~= nil and self.ideHasPower ~= 0 then
			local hp, kw = g_i18n:getPower(self.ideHasPower)
			local neededPower = string.format(g_i18n:getText("shop_neededPowerValue"), MathUtil.round(kw), MathUtil.round(hp))
			box:addLine(g_i18n:getText("infoDisplayExtension_currentPower"), neededPower)
		end
		if self.getDirtAmount ~= nil then
			local dirt = self:getDirtAmount()
			if dirt > 0.01 then
				box:addLine(g_i18n:getText("groundType_dirt"), string.format("%d %%", dirt * 100))
			end
		end
	end

	-- INSPECTION
	local inspectionActive = rvb.inspection.state == INSPECTION_STATE.ACTIVE
	if inspectionActive then -- and not rvb.repair[10]
		local tomorrowText = ""
		if rvb.inspection.finishDay > g_currentMission.environment.currentDay then
			tomorrowText = g_i18n:getText("infoDisplayExtension_tomorrow")
		end
		box:addLine(g_i18n:getText("infoDisplayExtension_inspectionVheicle"), tomorrowText..string.format("%02d:%02d", rvb.inspection.finishHour, rvb.inspection.finishMinute))
	end
	-- REPAIR
	local repairActive = rvb.repair.state == REPAIR_STATE.ACTIVE
	if repairActive then
		local tomorrowText = ""
		if rvb.repair.finishDay > g_currentMission.environment.currentDay then
			tomorrowText = g_i18n:getText("infoDisplayExtension_tomorrow")
		end
		box:addLine(g_i18n:getText("infoDisplayExtension_repairVheicle"), tomorrowText..string.format("%02d:%02d", rvb.repair.finishHour, rvb.repair.finishMinute))
	end
	-- SERVICE
	local serviceActive = rvb.service.state == SERVICE_STATE.ACTIVE
	if serviceActive then
		local tomorrowText = ""
		if rvb.service.finishDay > g_currentMission.environment.currentDay then
			tomorrowText = g_i18n:getText("infoDisplayExtension_tomorrow")
		end
		box:addLine(g_i18n:getText("infoDisplayExtension_serviceVheicle"), tomorrowText..string.format("%02d:%02d", rvb.service.finishHour, rvb.service.finishMinute))
	end
end
--Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, rvbVehicle.showInfo)
Vehicle.showInfo = Utils.prependedFunction(Vehicle.showInfo, rvbVehicle.showInfo)

function rvbVehicle.showInfo_UUYT(self, box)
	local rvb = self.spec_faultData
	if rvb == nil then --or not rvb.isrvbSpecEnabled then
		return
	end
	for i = #box.lines, 1, -1 do
		if g_modIsLoaded["FS25_useYourTyres"] then
			if rvb.isrvbSpecEnabled and box.lines[i].key == g_i18n:getText("infohud_uytTyresWear") then
				box.lines[i].isActive = false
			end
		end
		if not rvb.isrvbSpecEnabled and box.lines[i].key == g_i18n:getText("RVB_faultText_BATTERY") then
			box.lines[i].isActive = false
		end
	end
	if g_modIsLoaded["FS25_useYourTyres"] then
		if rvb.isrvbSpecEnabled and self.spec_wheels ~= nil then
			for _, wheel in ipairs(self.spec_wheels.wheels) do
				if wheel.uytTravelledDist ~= nil and wheel.uytTravelledDist > 0 then
					local wear = FS25_useYourTyres.UseYourTyres.getWearAmount(wheel)
					local isWarningTyre = false
					if (wear * 100) >= 70 then
						isWarningTyre = true
					end
					box:addLine(
						string.format(g_i18n:getText("rvb_infohud_uytTyresWear"), wheel.wheelIndex),
						string.format("%d %%", wear * 100),
						isWarningTyre
					)
				end
			end
		end	
	end
end
Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, rvbVehicle.showInfo_UUYT)

--[[
function VehicleBreakdowns:getSellPrice_RVBClone()
    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    return VehicleBreakdowns.calculateSellPriceClone(storeItem, self.age, self.operatingTime, self:getPrice(), self:getRepairPrice(), self:getRepairPrice_RVBClone(), self:getRepaintPrice())
end
function VehicleBreakdowns.calculateSellPriceClone(storeItem, age, operatingTime, price, repairPrice, repairPriceRVBClone, repaintPrice)
	local operatingTimeHours = operatingTime / 3600000
	local maxVehicleAge = storeItem.lifetime
	local ageInYears = age / Environment.PERIODS_IN_YEAR
	StoreItemUtil.loadSpecsFromXML(storeItem)
	local operatingTimeFactor = 1 - operatingTimeHours ^ (storeItem.specs.power == nil and 1.3 or 1) / maxVehicleAge
	local ageFactor = -0.1 * math.log(ageInYears) + 0.75
	local v476 = math.min(ageFactor, 0.85)
	local v477 = price * operatingTimeFactor * v476 - repairPrice - repairPriceRVBClone - repaintPrice
	local v478 = price * 0.03
	return math.max(v477, v478)
end


function Vehicle:getSellPrice()
	local v502_ = g_storeManager:getItemByXMLFilename(self.configFileName)
	return Vehicle.calculateSellPrice(v502_, self.age, self.operatingTime, self:getPrice(), self:getRepairPrice(), self:getRepaintPrice())
end

function Vehicle.calculateSellPrice(storeItem, age, operatingTime, price, repairPrice, repaintPrice)
	local v509_ = operatingTime / 3600000
	local v510_ = storeItem.lifetime
	local v511_ = age / Environment.PERIODS_IN_YEAR
	StoreItemUtil.loadSpecsFromXML(storeItem)
	local v512_ = 1 - v509_ ^ (storeItem.specs.power == nil and 1.3 or 1) / v510_
	local v513_ = -0.1 * math.log(v511_) + 0.75
	local v514_ = math.min(v513_, 0.85)
	local v515_ = price * v512_ * v514_ - repairPrice - repaintPrice
	local v516_ = price * 0.03
	return math.max(v515_, v516_)
end

function Vehicle:getRepairPrice()
	return 0
end
]]