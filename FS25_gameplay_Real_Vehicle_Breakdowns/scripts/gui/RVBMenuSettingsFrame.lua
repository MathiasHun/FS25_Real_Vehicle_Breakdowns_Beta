RVBMenuSettingsFrame = {}

local v_u_1 = Class(RVBMenuSettingsFrame, TabbedMenuFrameElement)
local function v_u_2() end
RVBMenuSettingsFrame.SUB_CATEGORY = {
	["GAME_SETTINGS"] = 1,
	["GENERAL_SETTINGS"] = 2
}

function RVBMenuSettingsFrame.register()
	local v3 = RVBMenuSettingsFrame.new()
	g_gui:loadGui(g_vehicleBreakdownsDirectory .. "gui/RVBMenuSettingsFrame.xml", "SettingsFrame", v3, true)
end
function RVBMenuSettingsFrame.new(p4, p5)
	local v6 = TabbedMenuFrameElement.new(p4, p5 or v_u_1)
	v6.missionInfo = nil
	v6.RVB = nil
	v6.hasMasterRights = false
	v6.isOpening = false
	v6.currentUser = User.new()
	return v6
end
function RVBMenuSettingsFrame.createFromExistingGui(p11, p12)
	local v13 = RVBMenuSettingsFrame.new()
	g_gui.frames[p11.name].target:delete()
	g_gui.frames[p11.name]:delete()
	g_gui:loadGui(p11.xmlFilename, p12, v13, true)
	return v13
end
function RVBMenuSettingsFrame:initialize()
	self:initializeSubCategoryPages()
	self:initializeGameSettings()
	self:initializeGeneralSettings()
	self:initializeButtons()
	self.subCategoryPagingFocusChangeFunc = self.subCategoryPaging.shouldFocusChange
end
function RVBMenuSettingsFrame:initializeSubCategoryPages()
	local v25_ = {}
	for v_u_26_, v27_ in pairs(self.subCategoryTabs) do
		v27_:getDescendantByName("background").getIsSelected = function()
			-- upvalues: (copy) v_u_26_, (copy) self
			local v28_ = v_u_26_
			local v29_ = self.subCategoryPaging.texts[self.subCategoryPaging:getState()]
			return v28_ == tonumber(v29_)
		end
		function v27_.getIsSelected()
			-- upvalues: (copy) v_u_26_, (copy) self
			local v30_ = v_u_26_
			local v31_ = self.subCategoryPaging.texts[self.subCategoryPaging:getState()]
			return v30_ == tonumber(v31_)
		end
		local v32_ = g_currentMission
		--if v_u_26_ == RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS and not (self.hasMasterRights and v32_.missionDynamicInfo.isMultiplayer) then
			v27_:setVisible(false)
		--else
			v27_:setVisible(true)
			local v33_ = tostring(v_u_26_)
			table.insert(v25_, v33_)
		--end
	end
	self.subCategoryBox:invalidateLayout()
	self.subCategoryPaging:setTexts(v25_)
	self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)
end
function RVBMenuSettingsFrame.initializeGameSettings(p_u_34, p35, p36)
	p_u_34:assignStaticTexts()
	local difficultyTable = {}
	table.insert(difficultyTable, g_i18n:getText(RVBMenuSettingsFrame.L10N_SYMBOL.DIFFICULTY_SLOW))
	table.insert(difficultyTable, g_i18n:getText(RVBMenuSettingsFrame.L10N_SYMBOL.DIFFICULTY_MEDIUM))
	table.insert(difficultyTable, g_i18n:getText(RVBMenuSettingsFrame.L10N_SYMBOL.DIFFICULTY_FAST))
	p_u_34.multiRvbDifficulty:setTexts(difficultyTable)
	p_u_34.onClickBackCallback = p36 or v_u_2
end
function RVBMenuSettingsFrame.initializeGeneralSettings(self)

end
function RVBMenuSettingsFrame:initializeButtons()
	self.backButtonInfo = {
		["inputAction"] = InputAction.MENU_BACK
	}
	self.nextPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_NEXT,
		["text"] = g_i18n:getText("ui_ingameMenuNext"),
		["callback"] = self.onPageNext
	}
	self.prevPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_PREV,
		["text"] = g_i18n:getText("ui_ingameMenuPrev"),
		["callback"] = self.onPagePrevious
	}
	self.resetButtonInfo = {
		["inputAction"] = InputAction.MENU_CANCEL,
		["text"] = g_i18n:getText(RVBMenuSettingsFrame.L10N_SYMBOL.BUTTON_DEFAULTS),
		["callback"] = function()
			self:onClickDefaults()
		end,
		["showWhenPaused"] = true
	}
	self.adminButtonInfo = {
		["inputAction"] = InputAction.MENU_ACTIVATE,
		["text"] = g_i18n:getText("button_adminLogin"),
		["callback"] = function()
			self:onButtonAdminLogin()
		end
	}
end
function RVBMenuSettingsFrame:setMissionInfo(missionInfo)
	self.missionInfo = missionInfo
end
function RVBMenuSettingsFrame:setHasMasterRights(hasMasterRights)
	self.hasMasterRights = hasMasterRights
	if g_currentMission ~= nil then
		self:updateButtons()
	end
end
	
	
function RVBMenuSettingsFrame:onFrameOpen(element)
	RVBMenuSettingsFrame:superClass().onFrameOpen(self)
	g_messageCenter:subscribe(MessageType.MASTERUSER_ADDED, self.onMasterUserAdded, self)
	self:setCurrentUserId(g_currentMission.playerUserId)
	self:initializeSubCategoryPages()
	self.isOpening = true
	local v50 = g_currentMission
	local v51 = v50.missionDynamicInfo.isMultiplayer
	if not v51 or (g_inGameMenu.isServer or self.hasMasterRights) then
		self:updateGameSettings()
		self.gameSettingsLayout:setVisible(true)
		self.gameSettingsSeparator:setVisible(true)
		self.gameSettingsNoPermissionText:setVisible(false)
	else
		self.gameSettingsLayout:setVisible(false)
		self.gameSettingsSeparator:setVisible(false)
		self.gameSettingsNoPermissionText:setVisible(true)
	end
	self:updateAlternatingElements(self.gameSettingsLayout)
	self:updateGeneralSettings()
	self:updateAlternatingElements(self.generalSettingsLayout)
	self:updateSubCategoryPages((self.subCategoryPaging:getState()))
	self.isOpening = false
end
function RVBMenuSettingsFrame:updateAlternatingElements(layout)
	local v79_ = true
	for _, v80_ in pairs(layout.elements) do
		if v80_.name == "sectionHeader" then
			v79_ = true
		elseif v80_.visible then
			local v81_ = RVBMenuSettingsFrame.COLOR_ALTERNATING[v79_]
			v80_:setImageColor(nil, unpack(v81_))
			v79_ = not v79_
		end
	end
	layout:invalidateLayout()
end
function RVBMenuSettingsFrame.onFrameClose(p76)
	--g_settingsModel:saveChanges(SettingsModel.SETTING_CLASS.SAVE_GAMEPLAY_SETTINGS)
	RVBMenuSettingsFrame:superClass().onFrameClose(p76)
end
function RVBMenuSettingsFrame.update(p77, p78)
	RVBMenuSettingsFrame:superClass().update(p77, p78)
	if p77.nextFocusSection ~= nil then
		local v79 = p77.controlsList:getElementAtSectionIndex(p77.nextFocusSection, p77.nextFocusCell)
		if v79 ~= nil then
			local v80 = v79:getAttribute(p77.nextFocusedButtonName)
			FocusManager:setFocus(v80)
			p77.nextFocusSection = nil
			p77.nextFocusCell = nil
		end
	end
end
function RVBMenuSettingsFrame:updateButtons()
	self.menuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo }
	local v121_ = self.subCategoryPaging.texts[self.subCategoryPaging:getState()]
	local v122_ = tonumber(v121_)
	if v122_ == RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS then
		if g_currentMission ~= nil and (g_currentMission.connectedToDedicatedServer and not self.currentUser:getIsMasterUser()) then
			local v131_ = self.menuButtonInfo
			local v132_ = self.adminButtonInfo
			table.insert(v131_, v132_)
		end
	end
	self:setMenuButtonInfoDirty()
end
function RVBMenuSettingsFrame:setCurrentUserId(currentUserId)
	self.currentUserId = currentUserId
	self.currentUser = g_currentMission.userManager:getUserByUserId(currentUserId) or self.currentUser
	self:updateButtons()
end
function RVBMenuSettingsFrame:onButtonAdminLogin()
	PasswordDialog.show(self.onAdminPassword, self, nil, "", g_i18n:getText("button_adminLogin"))
end
function RVBMenuSettingsFrame:onAdminPassword(password, yes)
	if yes then
		g_client:getServerConnection():sendEvent(GetAdminEvent.new(password))
	end
end
function RVBMenuSettingsFrame:onMasterUserAdded(user)
	local v50 = g_currentMission
	local v51 = v50.missionDynamicInfo.isMultiplayer
	if not v51 or (g_inGameMenu.isServer or self.hasMasterRights) then
		self:updateGameSettings()
		self.gameSettingsLayout:setVisible(true)
		self.gameSettingsLayout:invalidateLayout()
		self.gameSettingsSeparator:setVisible(true)
		self.gameSettingsNoPermissionText:setVisible(false)
	end
	self:updateButtons()
end
function RVBMenuSettingsFrame.updateGameSettings(self)
	local RVB = g_currentMission.vehicleBreakdowns
	self.multidailyServiceInterval:setState(rvb_Utils.getDailyServiceIndex(RVB:getDailyService(), 2))
	self.multiperiodicServiceInterval:setState(rvb_Utils.getPeriodicServiceIndex(RVB:getPeriodicService(), 1))
	self.checkworkshopTime:setIsChecked(RVB:getIsWorkshopTime(), self.isOpening)
	self.multiworkshopOpen:setState(rvb_Utils.getWorkshopOpenIndex(RVB:getWorkshopOpen(), 1))
	self.multiworkshopClose:setState(rvb_Utils.getWorkshopCloseIndex(RVB:getWorkshopClose(), 1))
	self.multiworkshopCountMax:setState(rvb_Utils.getWorkshopCountMaxIndex(RVB:getWorkshopCountMax(), 2))
	self.multiRvbDifficulty:setState(RVB:getRVBDifficulty())
	self.multiThermostatLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getThermostatLifetime(), 30))
	self.multiLightingsLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getLightingsLifetime(), 44))
	self.multiGlowplugLifetime:setState(rvb_Utils.getSmallLifetimeIndex(RVB:getGlowplugLifetime(), 2))
	self.multiWipersLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getWipersLifetime(), 16))
	self.multiGeneratorLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getGeneratorLifetime(), 36))
	self.multiEngineLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getEngineLifetime(), 42))
	self.multiSelfstarterLifetime:setState(rvb_Utils.getSmallLifetimeIndex(RVB:getSelfstarterLifetime(), 3))
	self.multiBatteryLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getBatteryLifetime(), 28))
	self.multiTireLifetime:setState(rvb_Utils.getLargeLifetimeIndex(RVB:getTireLifetime(), 68))
end
function RVBMenuSettingsFrame.assignStaticTexts(self)
	self:assignDailyServiceTexts()
	self:assignPeriodicServiceTexts()
	self:assignWorkshopOpenTexts()
	self:assignWorkshopCloseTexts()
	self:assignWorkshopCountMaxTexts()
	self:assignThermostatLifetimeTexts()
	self:assignLightingsLifetimeTexts()
	self:assignGlowplugLifetimeTexts()
	self:assignWipersLifetimeTexts()
	self:assignGeneratorLifetimeTexts()
	self:assignEngineLifetimeTexts()
	self:assignSelfstarterLifetimeTexts()
	self:assignBatteryLifetimeTexts()
	self:assignTireLifetimeTexts()
end
function RVBMenuSettingsFrame.assignDailyServiceTexts(self)
	local dailyServiceTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.DailyService) do
		table.insert(dailyServiceTable, rvb_Utils.getDailyServiceString(i))
	end
	self.multidailyServiceInterval:setTexts(dailyServiceTable)
end
function RVBMenuSettingsFrame.assignPeriodicServiceTexts(self)
	local periodicServiceTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.PeriodicService) do
		table.insert(periodicServiceTable, rvb_Utils.getPeriodicServiceString(i))
	end
	self.multiperiodicServiceInterval:setTexts(periodicServiceTable)
end
function RVBMenuSettingsFrame.assignWorkshopOpenTexts(self)
	local workshopOpenTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.WorkshopOpen) do
		table.insert(workshopOpenTable, rvb_Utils.getWorkshopOpenString(i))
	end
	self.multiworkshopOpen:setTexts(workshopOpenTable)
end
function RVBMenuSettingsFrame.assignWorkshopCloseTexts(self)
	local workshopCloseTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.WorkshopClose) do
		table.insert(workshopCloseTable, rvb_Utils.getWorkshopCloseString(i))
	end
	self.multiworkshopClose:setTexts(workshopCloseTable)
end
function RVBMenuSettingsFrame.assignWorkshopCountMaxTexts(self)
	local workshopCountMaxTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.WorkshopCountMax) do
		table.insert(workshopCountMaxTable, rvb_Utils.getWorkshopCountMaxString(i))
	end
	self.multiworkshopCountMax:setTexts(workshopCountMaxTable)
end
function RVBMenuSettingsFrame.assignThermostatLifetimeTexts(self)
	local thermostatLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(thermostatLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiThermostatLifetime:setTexts(thermostatLifetimeTable)
end
function RVBMenuSettingsFrame.assignLightingsLifetimeTexts(self)
	local lightingsLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(lightingsLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiLightingsLifetime:setTexts(lightingsLifetimeTable)
end
function RVBMenuSettingsFrame.assignGlowplugLifetimeTexts(self)
	local glowplugLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.SmallArray) do
		table.insert(glowplugLifetimeTable, rvb_Utils.getSmallLifetimeString(i))
	end
	self.multiGlowplugLifetime:setTexts(glowplugLifetimeTable)
end
function RVBMenuSettingsFrame.assignWipersLifetimeTexts(self)
	local wipersLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(wipersLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiWipersLifetime:setTexts(wipersLifetimeTable)
end
function RVBMenuSettingsFrame.assignGeneratorLifetimeTexts(self)
	local generatorLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(generatorLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiGeneratorLifetime:setTexts(generatorLifetimeTable)
end
function RVBMenuSettingsFrame.assignEngineLifetimeTexts(self)
	local engineLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(engineLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiEngineLifetime:setTexts(engineLifetimeTable)
end
function RVBMenuSettingsFrame.assignSelfstarterLifetimeTexts(self)
	local selfstarterLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.SmallArray) do
		table.insert(selfstarterLifetimeTable, rvb_Utils.getSmallLifetimeString(i))
	end
	self.multiSelfstarterLifetime:setTexts(selfstarterLifetimeTable)
end
function RVBMenuSettingsFrame.assignBatteryLifetimeTexts(self)
	local batteryLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(batteryLifetimeTable, rvb_Utils.getLargeLifetimeString(i))
	end
	self.multiBatteryLifetime:setTexts(batteryLifetimeTable)
end
function RVBMenuSettingsFrame.assignTireLifetimeTexts(self)
	local tireLifetimeTable = {}
	for i = 1, rvb_Utils.table_count(rvb_Utils.LargeArray) do
		table.insert(tireLifetimeTable, rvb_Utils.getLargeLifetimeKmString(i))
	end
	self.multiTireLifetime:setTexts(tireLifetimeTable)
end
function RVBMenuSettingsFrame:updateGeneralSettings()
	local RVB = g_currentMission.vehicleBreakdowns
	self.checkAlertDialog:setIsChecked(RVB:getIsAlertMessage(), self.isOpening)
	self.checkVHud:setIsChecked(RVB:getIsVHudDisplay(), self.isOpening)
	self.checkshowTemp:setIsChecked(RVB:getIsShowTempDisplay(), self.isOpening)
	self.checkshowRpm:setIsChecked(RVB:getIsShowRpmDisplay(), self.isOpening)
	self.checkshowFuel:setIsChecked(RVB:getIsShowFuelDisplay(), self.isOpening)
	self.checkshowMotorLoad:setIsChecked(RVB:getIsShowMotorLoadDisplay(), self.isOpening)
	self.checkshowDebug:setIsChecked(RVB:getIsShowDebugDisplay(), self.isOpening)
end
function RVBMenuSettingsFrame.onClickDailyServiceInterval(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setDailyServiceInterval(rvb_Utils.getDailyServiceFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickPeriodicServiceInterval(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setPeriodicServiceInterval(rvb_Utils.getPeriodicServiceFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickWorkshopTime(self, _, elements)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setIsWorkshopTime(elements:getIsChecked())
	end
end
function RVBMenuSettingsFrame.onClickWorkshopOpen(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setWorkshopOpen(rvb_Utils.getWorkshopOpenFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickWorkshopClose(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setWorkshopClose(rvb_Utils.getWorkshopCloseFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickWorkshopCountMax(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setWorkshopCountMax(rvb_Utils.getWorkshopCountMaxFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickRvbDifficulty(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setRVBDifficulty(state)
	end
end
function RVBMenuSettingsFrame.onClickThermostatLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setThermostatLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickLightingsLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setLightingsLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickGlowplugLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setGlowplugLifetime(rvb_Utils.getSmallLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickWipersLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setWipersLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickGeneratorLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setGeneratorLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickEngineLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setEngineLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickSelfstarterLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setSelfstarterLifetime(rvb_Utils.getSmallLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickBatteryLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setBatteryLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickTireLifetime(self, state)
	if self.hasMasterRights then
		g_currentMission.vehicleBreakdowns:setTireLifetime(rvb_Utils.getLargeLifetimeFromIndex(state))
	end
end
function RVBMenuSettingsFrame.onClickAlertDialog(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsAlertMessage(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickVHud(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsVHudDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickshowTemp(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsShowTempDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickshowRpm(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsShowRpmDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickshowFuel(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsShowFuelDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickshowMotorLoad(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsShowMotorLoadDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickshowDebug(self, _, elements)
	g_currentMission.vehicleBreakdowns:setIsShowDebugDisplay(elements:getIsChecked())
end
function RVBMenuSettingsFrame.onClickGameSettings(p266)
	p266.subCategoryPaging:setState(RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS, true)
end
function RVBMenuSettingsFrame.onClickGeneralSettings(p267)
	p267.subCategoryPaging:setState(RVBMenuSettingsFrame.SUB_CATEGORY.GENERAL_SETTINGS, true)
end
function RVBMenuSettingsFrame.onClickPreviousSubCategory(p270)
	p270.subCategoryPaging:onLeftButtonClicked()
end
function RVBMenuSettingsFrame.onClickNextSubCategory(p271)
	p271.subCategoryPaging:onRightButtonClicked()
end
function RVBMenuSettingsFrame:updateSubCategoryPages(state)
	local v274 = self.subCategoryPaging.texts[state]
	if v274 == nil then
		return
	else
		local v275 = tonumber(v274)
		if self:requestClose(function()
			self:updateSubCategoryPages(state)
		end) then
			for v276, v277 in pairs(self.subCategoryPages) do
				v277:setVisible(v276 == v275)
			end
			self.subCategoryPaging.shouldFocusChange = self.subCategoryPagingFocusChangeFunc
			self.categoryHeaderIcon:setImageSlice(nil, RVBMenuSettingsFrame.HEADER_SLICES[v275])
			self.categoryHeaderText:setText(g_i18n:getText(RVBMenuSettingsFrame.HEADER_TITLES[v275]))
			if self.menuAcceptUpEventId ~= nil then
				g_inputBinding:removeActionEvent(self.menuAcceptUpEventId)
			end
			if v275 == RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS then
				self.settingsSlider:setDataElement(self.gameSettingsLayout)
				FocusManager:linkElements(self.subCategoryPaging, FocusManager.TOP, self.gameSettingsLayout.elements[#self.gameSettingsLayout.elements].elements[1])
				FocusManager:linkElements(self.subCategoryPaging, FocusManager.BOTTOM, self.gameSettingsLayout:findFirstFocusable(true))
			elseif v275 == RVBMenuSettingsFrame.SUB_CATEGORY.GENERAL_SETTINGS then
				self.settingsSlider:setDataElement(self.generalSettingsLayout)
				FocusManager:linkElements(self.subCategoryPaging, FocusManager.TOP, self.generalSettingsLayout.elements[#self.generalSettingsLayout.elements].elements[1])
				FocusManager:linkElements(self.subCategoryPaging, FocusManager.BOTTOM, self.generalSettingsLayout:findFirstFocusable(true))
			end
			self:updateButtons()
			FocusManager:setFocus(self.subCategoryPaging)
		end
	end
end
function RVBMenuSettingsFrame.inputEvent(p324, p325, _, p326)
	if p325 == InputAction.MENU_ACCEPT then
		return FocusManager:getFocusedElement() ~= p324.buttonPauseGame
	else
		return p326
	end
end
function InGameMenuSettingsFrame:onClickDefaults()
	YesNoDialog.show(function(p585_)
		-- upvalues: (copy) self
		if p585_ then
			self.userChangedInput = false
			self:updateButtons()
			InfoDialog.show(g_i18n:getText(SettingsControlsFrame.L10N_SYMBOL.DEFAULTS_LOADED), function(p586_)
				p586_.controlsList:makeCellVisible(1, 1)
				p586_.nextFocusSection = 1
				p586_.nextFocusCell = 1
				p586_.nextFocusedButtonName = "actionButton1"
			end, self, DialogElement.TYPE_INFO)
		end
	end, nil, g_i18n:getText(InGameMenuSettingsFrame.L10N_SYMBOL.LOAD_DEFAULTS), g_i18n:getText(InGameMenuSettingsFrame.L10N_SYMBOL.BUTTON_RESET))
end

RVBMenuSettingsFrame.L10N_SYMBOL = {
	["DIFFICULTY_SLOW"] = "RVB_difficulty_slow",
	["DIFFICULTY_MEDIUM"] = "RVB_difficulty_medium",
	["DIFFICULTY_FAST"] = "RVB_difficulty_fast",
	["BUTTON_DEFAULTS"] = "button_defaults",
	["LOAD_DEFAULTS"] = "ui_loadDefaultSettings",
	["DEFAULTS_LOADED"] = "ui_loadedDefaultSettings",
	["BUTTON_RESET"] = "button_reset"
}
RVBMenuSettingsFrame.HEADER_SLICES = {
	[RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS] = "gui.icon_options_gameSettings2",
	[RVBMenuSettingsFrame.SUB_CATEGORY.GENERAL_SETTINGS] = "gui.icon_options_generalSettings2"
}
RVBMenuSettingsFrame.HEADER_TITLES = {
	[RVBMenuSettingsFrame.SUB_CATEGORY.GAME_SETTINGS] = "ui_ingameMenuGameSettingsGame",
	[RVBMenuSettingsFrame.SUB_CATEGORY.GENERAL_SETTINGS] = "ui_ingameMenuGameSettingsGeneral"
}
RVBMenuSettingsFrame.COLOR_ALTERNATING = {
	[true] = {
		0.02956,
		0.02956,
		0.02956,
		0.6
	},
	[false] = {
		0.02956,
		0.02956,
		0.02956,
		0.2
	}
}
RVBMenuSettingsFrame.COLOR = {
	["BLACK"] = {
		0.00439,
		0.00478,
		0.00368,
		1
	},
	["GREEN"] = {
		0.22323,
		0.40724,
		0.00368,
		1
	}
}