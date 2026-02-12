
RVBMenu = {}
local RVBMenu_mt = Class(RVBMenu, TabbedMenu)

function RVBMenu.register()
	RVBMenuSettingsFrame.register()
	RVBMenuPartsSettingsFrame.register()
	local self = RVBMenu.new()
	g_gui:loadGui(g_vehicleBreakdownsDirectory .. "gui/RVBMenu.xml", "RVBMenu", self)
	return self
end
function RVBMenu.new(target, custom_mt)
	local self = RVBMenu:superClass().new(target, custom_mt or RVBMenu_mt)
	self.client = nil
	self.server = nil
	self.isMasterUser = false
	self.isServer = false
	self.pageMain = nil
	self.playerFarmId = 0
	self.pageSettings = nil
	self.pagePartsSettings = nil
	self.missionInfo = {}
	self.missionDynamicInfo = {}
	self.currentDeviceHasNoSpace = false
	self.defaultMenuButtonInfo = {}
	self.backButtonInfo = {}
	self.blockNextPageNextEvent = false
	return self
end
function RVBMenu.onGuiSetupFinished(self)
	RVBMenu:superClass().onGuiSetupFinished(self)
	g_messageCenter:subscribe(MessageType.MASTERUSER_ADDED, self.onMasterUserAdded, self)
	self:initializePages()
	self:setupMenuPages()
end
function RVBMenu:initializePages()
	self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)
	self.pageSettings:initialize()
	self.pagePartsSettings:initialize()
end
function RVBMenu.createFromExistingGui(gui, guiName)
	RVBMenuSettingsFrame.createFromExistingGui(g_gui.frames.rvbMenuSettings.target, "RVBMenuSettingsFrame")
	RVBMenuPartsSettingsFrame.createFromExistingGui(g_gui.frames.rvbMenuPartsSettings.target, "RVBMenuPartsSettingsFrame")
	local rvbmenu = RVBMenu.new()
	g_gui.guis.RVBMenu:delete()
	g_gui.guis.RVBMenu.target:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, rvbmenu)
	local cMission = g_currentMission
	rvbmenu:setClient(g_client)
	rvbmenu:setServer(g_server)
	rvbmenu:setMissionInfo(cMission.missionInfo, cMission.missionDynamicInfo, cMission.baseDirectory)
	rvbmenu:setPlayerFarm(gui.playerFarm)
	g_rvbMenu = rvbmenu
	return rvbmenu
end
function RVBMenu:setClient(client)
	self.client = client
end
function RVBMenu:setServer(server)
	self.server = server
	self.isServer = server ~= nil
	self:updateHasMasterRights()
end
function RVBMenu:updateHasMasterRights()
	local hasMasterRights = self.isMasterUser or self.isServer
	if Platform.isMobile then
	else
		self.pageSettings:setHasMasterRights(hasMasterRights)
	end
	if self.currentPage ~= nil then
		self:updatePages()
	end
end
function RVBMenu:setPlayerFarm(farm)
	self.playerFarm = farm
	if farm == nil then
		self.playerFarmId = 0
	else
		self.playerFarmId = farm.farmId
	end
	if farm ~= nil and self:getIsOpen() then
		self:updatePages()
	end
end
function RVBMenu:updatePages(prevIndex)
	self.header:setVisible(true)
	if prevIndex ~= nil then
		local previousPage = self.pagingElement:getPageElementByIndex(prevIndex)
		local currentPage = self.pagingElement:getPageElementByIndex(self.currentPageId)
		if previousPage == self.pageSettings then
			self:setPageEnabled(ClassUtil.getClassObjectByObject(self.pageSettings), false)
		end
	end
	RVBMenu:superClass().updatePages(self)
end
function RVBMenu:setMissionInfo(missionInfo, missionDynamicInfo, missionBaseDirectory)
	self.missionInfo = missionInfo
	self.missionDynamicInfo = missionDynamicInfo
	if Platform.isMobile then
		--self.pageSettingsMobile:setMissionInfo(missionInfo)
	else
		self.pageSettings:setMissionInfo(missionInfo)
	end
	self.currentDeviceHasNoSpace = false
end
function RVBMenu:setupMenuButtonInfo()
	RVBMenu:superClass().setupMenuButtonInfo(self)
	local onButtonBackFunction = self.clickBackCallback
	local onButtonPagePrevious = self:makeSelfCallback(self.onPagePrevious)
	local onButtonPageNext = self:makeSelfCallback(self.onPageNext)
	self.backButtonInfo = {
		["inputAction"] = InputAction.MENU_BACK,
		["text"] = g_i18n:getText("button_back"),
		["callback"] = onButtonBackFunction
	}
	self.prevPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_PREV,
		["text"] = g_i18n:getText("ui_ingameMenuPrev"),
		["callback"] = onButtonPagePrevious
	}
	self.nextPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_NEXT,
		["text"] = g_i18n:getText("ui_ingameMenuNext"),
		["callback"] = onButtonPageNext
	}
	if Platform.isMobile then
		self.defaultMenuButtonInfo = { self.backButtonInfo }
	else
		self.defaultMenuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo }
	end
	self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1]
	self.defaultMenuButtonInfoByActions[InputAction.MENU_PAGE_PREV] = self.defaultMenuButtonInfo[2]
	self.defaultMenuButtonInfoByActions[InputAction.MENU_PAGE_NEXT] = self.defaultMenuButtonInfo[3]
	self.defaultButtonActionCallbacks = {
		[InputAction.MENU_BACK] = onButtonBackFunction,
		[InputAction.MENU_PAGE_PREV] = onButtonPagePrevious,
		[InputAction.MENU_PAGE_NEXT] = onButtonPageNext
	}
end
function RVBMenu:setupMenuPages()
	local pageIndex = 1
	local function registerOrRemovePage(page, predicate, icon, id)
		if page == nil then
			local existingPage = self.pagingElement:getPageElementByIndex(pageIndex)
			self.pagingElement:removePageByElement(existingPage)
		else
			self:registerPage(page, pageIndex, predicate)
			self:addPageTab(page, nil, nil, icon, id)
			pageIndex = pageIndex + 1
		end
	end
	registerOrRemovePage(self.pageSettings, self:makeIsMenuTabEnabledPredicate(), "gui.icon_ingameMenu_options", "settings")
	registerOrRemovePage(self.pagePartsSettings, self:makeIsMenuTabEnabledPredicate(), "gui.icon_options_gameSettings2", "partssettings")
	self:rebuildTabList()
end
function RVBMenu:makeIsMenuTabEnabledPredicate()
	return function()
		local isEnabled = not self.missionDynamicInfo.isMultiplayer or self.playerFarmId ~= FarmManager.SPECTATOR_FARM_ID
		if isEnabled then
			isEnabled = not g_guidedTourManager:getIsTourRunning()
		end
		return isEnabled
	end
end
function RVBMenu:onMasterUserAdded(user)
	if user:getId() == g_currentMission.playerUserId then
		self.isMasterUser = true
		self:updateHasMasterRights()
	end
end
function RVBMenu:onMasterUserRemoved(user)
	if user:getId() == g_currentMission.playerUserId then
		self.isMasterUser = false
		self:updateHasMasterRights()
	end
end
function RVBMenu:openGameSettingsScreen()
	if not self:getIsOpen() then
		self:changeScreen("RVBMenu")
	end
	self:setPageEnabled(ClassUtil.getClassObjectByObject(self.pageSettings), true)
	local pageIndex = self.pagingElement:getPageMappingIndexByElement(self.pageSettings)
	self.pageSelector:setState(pageIndex, true)
	self.pageSettings.isOpening = true
	self.pageSettings:onClickGameSettings()
	self.pageSettings.isOpening = false
end
function RVBMenu:openGeneralSettingsScreen()
	if not self:getIsOpen() then
		self:changeScreen("RVBMenu")
	end
	self:setPageEnabled(ClassUtil.getClassObjectByObject(self.pageSettings), true)
	local pageIndex = self.pagingElement:getPageMappingIndexByElement(self.pageSettings)
	self.pageSelector:setState(pageIndex, true)
	self.pageSettings.isOpening = true
	self.pageSettings:onClickGeneralSettings()
	self.pageSettings.isOpening = false
end