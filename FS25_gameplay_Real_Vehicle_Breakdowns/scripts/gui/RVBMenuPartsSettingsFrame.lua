
local function buildDynamicPercentArray(currentPercent, step, maxValue, minValue)
    local arr = {}
    maxValue = maxValue or 100
    minValue = minValue or 0
	-- 2 tizedesre kerekítés
    local function round2(val)
        return math.floor(val * 100 + 0.5) / 100
    end
    currentPercent = round2(currentPercent)
	-- Lefelé
    local down = currentPercent
    while down >= minValue do
        table.insert(arr, 1, round2(down))
        down = down - step
    end
	-- Felfelé
    local up = currentPercent + step
    while up <= maxValue do
        table.insert(arr, round2(up))
        up = up + step
    end
    -- Biztosítjuk, hogy a pontos aktuális érték is szerepeljen
    local containsCurrent = false
    for _, v in ipairs(arr) do
        if math.abs(v - currentPercent) < 0.0001 then
            containsCurrent = true
            break
        end
    end
    if not containsCurrent then
        table.insert(arr, 1, currentPercent)
    end
    return arr
end

RVBMenuPartsSettingsFrame = {}
local RVBMenuPartsSettingsFrame_mt = Class(RVBMenuPartsSettingsFrame, TabbedMenuFrameElement)

function RVBMenuPartsSettingsFrame.register()
	local partssettings = RVBMenuPartsSettingsFrame.new()
	g_gui:loadGui(g_vehicleBreakdownsDirectory .. "gui/RVBMenuPartsSettingsFrame.xml", "PartsSettingsFrame", partssettings, true)
end
function RVBMenuPartsSettingsFrame.new(target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or RVBMenuPartsSettingsFrame_mt)
	self.missionInfo = nil
	self.RVB = nil
	self.hasMasterRights = false
	self.isOpening = false
	self.autoSetFocusOnOpen = true
	return self
end
function RVBMenuPartsSettingsFrame.createFromExistingGui(gui, guiName)
	local partssettings = RVBMenuPartsSettingsFrame.new()
	g_gui.frames[gui.name].target:delete()
	g_gui.frames[gui.name]:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, partssettings, true)
	return partssettings
end
function RVBMenuPartsSettingsFrame:copyAttributes(src)
    RVBMenuPartsSettingsFrame:superClass().copyAttributes(self, src)
end
function RVBMenuPartsSettingsFrame.onFrameOpen(self, _)
	RVBMenuPartsSettingsFrame:superClass().onFrameOpen(self)
	self.isOpening = true
	self:updatePartsSettings()
	self:onFrameOpening()
	if self.autoSetFocusOnOpen and FocusManager:getFocusedElement() == nil then
        self:setSoundSuppressed(true)
        if self.boxLayout then
            FocusManager:setFocus(self.boxLayout)
        else
            FocusManager:setFocus(self:findFirstFocusable(true))
        end
        self:setSoundSuppressed(false)
    end
	self.isOpening = false
end
function RVBMenuPartsSettingsFrame:onFrameOpening()
end
function RVBMenuPartsSettingsFrame.onFrameClose(self)
	RVBMenuPartsSettingsFrame:superClass().onFrameClose(self)
end
function RVBMenuPartsSettingsFrame.initialize(self)
	self.Step = 1
end
function RVBMenuPartsSettingsFrame:getVehicle(ignoreFarm, getRootVehicle)
    local player = g_localPlayer
    if player then
        local vehicle = player:getCurrentVehicle()
        if vehicle then
            return vehicle, true
        end
    end
    return nil, false
end
function RVBMenuPartsSettingsFrame.updatePartsSettings(self)
	local vehicle, isEntered = self:getVehicle()
	self.isServer = g_server ~= nil
    self.currentVehicle = vehicle
	self.intervalTimeRemaining = 0
	-- Set Operating Time
    local setOperatingTimeDisabled = vehicle == nil
	local rvb = self.currentVehicle.spec_faultData
	if rvb and not rvb.isrvbSpecEnabled then
        return
    end
	local thermostatStepLifetimeTable = {}
	for i = 1, #rvb_Utils.PercentStepArray do
		table.insert(thermostatStepLifetimeTable, rvb_Utils.getPercentStepLifetimeString(i))
	end
    self.textInputPercentStep:setTexts(thermostatStepLifetimeTable)
	self.textInputPercentStep:setState(rvb_Utils.getPercentStepLifetimeIndex(self.Step, 1))
    self.textInputPercentStep:setDisabled(setOperatingTimeDisabled)
		

	for _, partName in ipairs(g_vehicleBreakdownsPartKeys) do
		if self["textCurrent" .. partName] then
			self["textCurrent" .. partName]:setText(string.format(g_i18n:getText("RVB_Parts_currentValue"), g_i18n:getText("RVB_faultText_"..partName)))
			self["textRemaining" .. partName]:setText(string.format(g_i18n:getText("RVB_Parts_remainingValue"), g_i18n:getText("RVB_faultText_"..partName)))
		end
		local part = rvb.parts[partName]
		local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
		local percentInput = self["textInput" .. part.name .. "Percent"]
		if part and currentLifetime and percentInput then
			self:updateLifetimeUI(vehicle, part, partName, currentLifetime, percentInput)
		end
	end
end
function RVBMenuPartsSettingsFrame.updateLifetimeUI(self, vehicle, part, partName, operatingTextInput, percentTextInput)
    local hours = math.floor(part.operatingHours)
    local minutes = math.floor((part.operatingHours - hours) * 60)
    if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
    if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
	local maxLifetime = PartManager.getMaxPartLifetime(vehicle, partName)
    local percentUsed = (part.operatingHours * 100) / maxLifetime
    local percentRemaining = 100 - percentUsed
    local lifetimeTable = {
        string.format("%.2f/%.2f", part.operatingHours, maxLifetime),
        string.format("%s óra %s perc", hours, minutes),
        string.format("%.2f %%", percentRemaining)
    }
    operatingTextInput:setTexts(lifetimeTable)
    operatingTextInput:setState(1)

    local step = rvb_Utils.getPercentStepLifetimeFromIndex(self.textInputPercentStep:getState()) or 1
    local percentArray = buildDynamicPercentArray(percentRemaining, step)
    local percentOptions = {}
    for i, val in ipairs(percentArray) do
        table.insert(percentOptions, string.format("%.2f %%", val))
    end
    percentTextInput:setTexts(percentOptions)
    local newState = 1
    for i, val in ipairs(percentArray) do
        if math.abs(val - percentRemaining) < 0.0001 then
            newState = i
            break
        elseif val > percentRemaining then
            newState = i
            break
        end
    end
    percentTextInput:setState(newState)
    percentTextInput:setDisabled(false)
end
function RVBMenuPartsSettingsFrame.onClickPercentStep(self, state)
    local step = rvb_Utils.getPercentStepLifetimeFromIndex(state)
    for _, partName in ipairs(g_vehicleBreakdownsPartKeys) do
        local input = self["textInput" .. partName .. "Percent"]
        if input then
            -- Aktuális érték közvetlenül a kijelzett szövegből
            local currentText = input.texts[input:getState()]
            local currentValue = tonumber(currentText:match("[%d%.]+")) or 0
            -- Új tömb az aktuális érték + step alapján
            local percentArray = buildDynamicPercentArray(currentValue, step)
            -- Szövegek
            local lifetimeTable = {}
            for i, val in ipairs(percentArray) do
                --lifetimeTable[i] = tostring(val) .. " %"
				lifetimeTable[i] = string.format("%.2f %%", val)
            end
            input:setTexts(lifetimeTable)
            -- Új index az aktuális érték alapján
            local newIndex = 1
            for i, val in ipairs(percentArray) do
                if math.abs(val - currentValue) < 0.0001 then
                    newIndex = i
                    break
                end
            end
            input:setState(newIndex)
            self["actual" .. partName .. "Value"] = currentValue
        end
    end
end
function RVBMenuPartsSettingsFrame.onClickConfirmThermostatLifetime(self)
    local rvb = self.currentVehicle.spec_faultData
    if rvb == nil or not rvb.isrvbSpecEnabled then return end
    local part = rvb.parts[THERMOSTAT]
    local percentInput = self["textInput" .. part.name .. "Percent"]
    if percentInput == nil then return end
    local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
    -- Számítás
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, THERMOSTAT)
    part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
    -- Eseményküldés
    RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
    -- UI frissítés
    local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
    self:updateLifetimeUI(self.currentVehicle, part, THERMOSTAT, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmLightingsLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[LIGHTINGS]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, LIGHTINGS)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, LIGHTINGS, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmGlowplugLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[GLOWPLUG]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, GLOWPLUG)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, GLOWPLUG, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmWipersLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[WIPERS]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, WIPERS)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, WIPERS, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmGeneratorLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[GENERATOR]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, GENERATOR)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, GENERATOR, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmEngineLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[ENGINE]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, ENGINE)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, ENGINE, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmSelfstarterLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[SELFSTARTER]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, SELFSTARTER)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, SELFSTARTER, currentLifetime, percentInput)
end
function RVBMenuPartsSettingsFrame.onClickConfirmBatteryLifetime(self)
	local rvb = self.currentVehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[BATTERY]
	local percentInput = self["textInput" .. part.name .. "Percent"]
	if percentInput == nil then return end
	local currentText = percentInput.texts[percentInput:getState()]
    local currentPercentValue = tonumber(currentText:match("[%d%.]+")) or 0
	local maxLifetime = PartManager.getMaxPartLifetime(self.currentVehicle, BATTERY)
	part.operatingHours = maxLifetime * ((100 - currentPercentValue) / 100)
	RVBParts_Event.sendEvent(self.currentVehicle, rvb.parts)
	local currentLifetime = self["textInputCurrent" .. part.name .. "Lifetime"]
	self:updateLifetimeUI(self.currentVehicle, part, BATTERY, currentLifetime, percentInput)
end

--[[

function RVBMenuPartsSettingsFrame.update(self, dt)
    RVBMenuPartsSettingsFrame:superClass().update(self, dt)


	local rvb = self.currentVehicle.spec_faultData
	
	if rvb ~= nil and not rvb.isrvbSpecEnabled then
        return
    end
	
    --if not self.intervalUpdateDisabled then
        self.intervalTimeRemaining -= dt

        if self.intervalTimeRemaining <= 0 then
            self.intervalTimeRemaining = 5000

            if self.currentVehicle ~= nil and not self.currentVehicle:getIsBeingDeleted() then
			

				local Partfoot = (rvb.parts[THERMOSTAT].operatingHours * 100) / rvb.parts[THERMOSTAT].tmp_lifetime
				--Partfoot = MathUtil.round(Partfoot)
				Partfoot = 100 - Partfoot

				local value = string.format("%.2f", Partfoot)
			--self.textInputThermostatPercent:setState(rvb_Utils.getPercentLifetimeIndex(value, 100))
			--print("operatingHours" ..rvb.parts[THERMOSTAT].operatingHours)
			--print("getPercentLifetimeIndex" ..rvb_Utils.getPercentLifetimeIndex(value, 100))

            end
        end
    --end
end]]