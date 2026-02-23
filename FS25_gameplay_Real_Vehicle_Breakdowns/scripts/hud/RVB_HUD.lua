
local function colorsAreEqual(color1, color2)
	if #color1 ~= #color2 then return false end
	for i = 1, #color1 do
		if color1[i] ~= color2[i] then return false end
	end
	return true
end
local function colorsAreEqual_(c1, c2, eps)
	if c1 == nil or c2 == nil then return false end
	if #c1 ~= #c2 then return false end
	eps = eps or 0.001
	for i = 1, #c1 do
		if math.abs(c1[i] - c2[i]) > eps then
			return false
		end
	end
	return true
end

RVB_HUD = {}
local RVB_HUD_mt = Class(RVB_HUD, HUDDisplay)

RVB_HUD.LIGHT_DEFAULT    = bit32.lshift(1, Lights.LIGHT_TYPE_DEFAULT)
RVB_HUD.LIGHT_WORK_BACK  = bit32.lshift(1, Lights.LIGHT_TYPE_WORK_BACK)
RVB_HUD.LIGHT_WORK_FRONT = bit32.lshift(1, Lights.LIGHT_TYPE_WORK_FRONT)
RVB_HUD.LIGHT_HIGHBEAM   = bit32.lshift(1, Lights.LIGHT_TYPE_HIGHBEAM)
RVB_HUD.HUD_LIGHT_MASK = bit32.bor(
	RVB_HUD.LIGHT_DEFAULT,
	RVB_HUD.LIGHT_WORK_BACK,
	RVB_HUD.LIGHT_WORK_FRONT,
	RVB_HUD.LIGHT_HIGHBEAM
)

function RVB_HUD:new()
	local self = RVB_HUD:superClass().new(RVB_HUD_mt)
	self.modDirectory      = g_vehicleBreakdownsDirectory
	self.vehicle           = nil

	g_overlayManager:addTextureConfigFile(self.modDirectory .. "menu/rvbgui.xml", "rvbgui")
	g_overlayManager:addTextureConfigFile(self.modDirectory .. "menu/debugHud.xml", "debugHud")

	self.temperature = g_overlayManager:createOverlay("rvbgui.temperature", 0, 0, 0, 0)
	self.temperature:setVisible(true) -- false
	self.temperature.lastColor = nil
	self.temperature.faultlastColor = nil

	self.battery = g_overlayManager:createOverlay("rvbgui.battery", 0, 0, 0, 0)
	self.battery:setVisible(true) -- false
	self.battery.lastColor = nil
	self.battery.faultlastColor = nil

	self.engine = g_overlayManager:createOverlay("rvbgui.engine", 0, 0, 0, 0)
	self.engine:setVisible(true) -- false
	self.engine.lastColor = nil
	self.engine.faultlastColor = nil

	self.lights = g_overlayManager:createOverlay("rvbgui.lights", 0, 0, 0, 0)
	self.lights:setVisible(true) -- false
	self.lights.lastColor = nil
	self.lights.faultlastColor = nil

	--self.service = g_overlayManager:createOverlay("rvbgui.service", 0, 0, 0, 0)
	--self.service:setVisible(false)

	self.debugBg = g_overlayManager:createOverlay("debugHud.debugBg", 0, 0, 0, 0)
	self.debugBgScale = g_overlayManager:createOverlay("debugHud.debugBgScale", 0, 0, 0, 0)
	self.debugBgRight = g_overlayManager:createOverlay("debugHud.debugBgRight", 0, 0, 0, 0)
	
	self.fuelUsageUpdate = 0
	self.fuelUsage = 0
	self.lastfuelUsageText1 = ""
	self.lastfuelUsageText2 = ""
	self.updateFuelUsageInterval = 500
	self.motorLoadUpdate = 0
	self.updateMotorLoadInterval = 500

	self.isVehicleDrawSafe = false
	self.hudLightActive = false
	self.hudDefaultColor = {0.6, 0.6, 0.6, 0.1}
	return self
end
function RVB_HUD:delete()
	if self.vehicle ~= nil then
		self.vehicle = nil
		self.lastfuelUsageText1 = ""
		self.lastfuelUsageText2 = ""
		self.updateFuelUsageInterval = 500
		self.updateMotorLoadInterval = 500
		self.hudLightActive = false
	end
	self.isVehicleDrawSafe = false
	self.temperature:delete()
	self.battery:delete()
	self.engine:delete()
	self.lights:delete()
	--self.service:delete()
	self.debugBg:delete()
	self.debugBgScale:delete()
	self.debugBgRight:delete()
	RVB_HUD:superClass().delete(self)
end
function RVB_HUD:update(dt)
	RVB_HUD:superClass().update(self, dt)
	if self.vehicle == nil or self.vehicle.spec_faultData == nil then
		return
	end
	if self.vehicle ~= nil then
		self.isVehicleDrawSafe = true
		GeneratorManager.updateHud(self, self.vehicle, dt)
		LightingsManager.updateHud(self, self.vehicle, dt)
		EngineManager.updateHud(self, self.vehicle, dt)
		ThermostatManager.updateThermostatHud(self, self.vehicle, dt)
		ThermostatManager.updateDirtHud(self, self.vehicle, dt)
		
		if self.vehicle.spec_lights ~= nil then
			local mask = self.vehicle.spec_lights.lightsTypesMask
			local isLightOn = bit32.band(mask, RVB_HUD.HUD_LIGHT_MASK) ~= 0
			if self.hudLightActive ~= isLightOn then
				self.hudLightActive = isLightOn
			end
			if self.hudLightActive then
				self.hudDefaultColor = HUDCOLOR.DEFAULT_LIGHT
			else
				self.hudDefaultColor = HUDCOLOR.DEFAULT
			end
		end

	else
		self.isVehicleDrawSafe = false	
	end
	local motorState = self.vehicle:getMotorState()
	local RVBMain = g_currentMission.vehicleBreakdowns
	if (self.hasDiesel or self.hasElectric or self.hasMethane) and (motorState == MotorState.ON or motorState == MotorState.STARTING) and self.vehicle.spec_fillUnit ~= nil then
		if RVBMain:getIsShowFuelDisplay() then
			self.fuelUsageUpdate = self.fuelUsageUpdate + dt
			if self.fuelUsageUpdate >= self.updateFuelUsageInterval then
				self.fuelUsageUpdate = 0
				self.fuelUsage = self.vehicle.spec_motorized.lastFuelUsage
				self.updateFuelUsageInterval = 500
			end
		end
		
		if RVBMain:getIsShowMotorLoadDisplay() then
			self.motorLoadUpdate = self.motorLoadUpdate + dt
			if self.motorLoadUpdate >= self.updateMotorLoadInterval and self.updateMotorLoadInterval ~= 500 then
				--local motorload = self.vehicle:getMotorLoadPercentage()
				--if motorload ~= nil then
				--	self.motorLoad = math.floor(motorload * 100 + 0.5)
				--end
				self.updateMotorLoadInterval = 500
				self.motorLoadUpdate = 0
			end
		end
	end
end
function RVB_HUD:getDefaultHudColor()
	return self.hudDefaultColor or HUDCOLOR.DEFAULT
end
function RVB_HUD:storeScaledValues()
	self.temperatureOffsetX, self.temperatureOffsetY = self:scalePixelValuesToScreenVector(34, -16)
	local temperatureWidth, temperatureHeight = self:scalePixelValuesToScreenVector(16, 14)
	self.temperature:setDimension(temperatureWidth, temperatureHeight)
	
	self.batteryOffsetX, self.batteryOffsetY = self:scalePixelValuesToScreenVector(-50, -16)
	local batteryWidth, batteryHeight = self:scalePixelValuesToScreenVector(16, 14)
	self.battery:setDimension(batteryWidth, batteryHeight)
	
	self.engineOffsetX, self.engineOffsetY = self:scalePixelValuesToScreenVector(-50, 5)
	local engineWidth, engineHeight = self:scalePixelValuesToScreenVector(16, 14)
	self.engine:setDimension(engineWidth, engineHeight)
	
	self.lightsOffsetX, self.lightsOffsetY = self:scalePixelValuesToScreenVector(34, 5)
	local lightsWidth, lightsHeight = self:scalePixelValuesToScreenVector(16, 14)
	self.lights:setDimension(lightsWidth, lightsHeight)
	
	--self.serviceOffsetX, self.serviceOffsetY = self:scalePixelValuesToScreenVector(-15, 25)
	--local serviceWidth, serviceHeight = self:scalePixelValuesToScreenVector(35, 33)
	--self.service:setDimension(serviceWidth, serviceHeight)
	self.serviceTextOffsetX, self.serviceTextOffsetY = self:scalePixelValuesToScreenVector(0, 48)
	self.serviceTextSize = self:scalePixelToScreenHeight(10)

	local debugBgX, debugBgY = self:scalePixelValuesToScreenVector(247, 232)
	self.debugBg:setDimension(debugBgX, debugBgY)
	self.debugBgScale:setDimension(0, debugBgY)
	local debugBgRightX, debugBgRightY = self:scalePixelValuesToScreenVector(23, 232)
	self.debugBgRight:setDimension(debugBgRightX, debugBgRightY)
	self.debugBg:setColor(unpack({0, 0, 0, 0.55}))
	self.debugBgScale:setColor(unpack({0, 0, 0, 0.55}))
	self.debugBgRight:setColor(unpack({0, 0, 0, 0.55}))

	self.speedBgScaleWidth = self:scalePixelToScreenWidth(5)

	self.tempTextOffsetX, self.tempTextOffsetY = self:scalePixelValuesToScreenVector(52, -59)
	self.tempTextSize = self:scalePixelToScreenHeight(10)
	self.rpmTextOffsetX, self.rpmTextOffsetY = self:scalePixelValuesToScreenVector(-54, -59)
	self.rpmTextSize = self:scalePixelToScreenHeight(10)
	self.fuelTextOffsetX, self.fuelTextOffsetY = self:scalePixelValuesToScreenVector(8, 4)
	self.fuelTextSize = self:scalePixelToScreenHeight(13)

	self.debugTextSize = self:scalePixelToScreenHeight(14)
	self.damageTextOffsetX, self.damageTextOffsetY = self:scalePixelValuesToScreenVector(20, 212)
	self.thermostatTextOffsetX, self.thermostatTextOffsetY = self:scalePixelValuesToScreenVector(20, 192)
	self.lightingsTextOffsetX, self.lightingsTextOffsetY = self:scalePixelValuesToScreenVector(20, 172)
	self.glowplugTextOffsetX, self.glowplugTextOffsetY = self:scalePixelValuesToScreenVector(20, 152)
	self.wipersTextOffsetX, self.wipersTextOffsetY = self:scalePixelValuesToScreenVector(20, 132)
	self.generatorTextOffsetX, self.generatorTextOffsetY = self:scalePixelValuesToScreenVector(20, 112)
	self.engineTextOffsetX, self.engineTextOffsetY = self:scalePixelValuesToScreenVector(20, 92)
	self.selfstarterTextOffsetX, self.selfstarterTextOffsetY = self:scalePixelValuesToScreenVector(20, 72)
	self.batteryTextOffsetX, self.batteryTextOffsetY = self:scalePixelValuesToScreenVector(20, 52)
	self.serviceDTextOffsetX, self.serviceDTextOffsetY = self:scalePixelValuesToScreenVector(20, 32)

	self.motorLoadTextOffsetX, self.motorLoadTextOffsetY = self:scalePixelValuesToScreenVector(-25, 32)
	self.motorLoadTextSize = self:scalePixelToScreenHeight(11)
end
function RVB_HUD:setVehicle(vehicle)
	self.vehicle = nil
	self.lastfuelUsageText1 = ""
	self.lastfuelUsageText2 = ""
	self.updateFuelUsageInterval = 50
	self.lastmotorLoadText = ""
	self.updateMotorLoadInterval = 50
	self.hudLightActive = false
	local hasVehicle = vehicle ~= nil
	local isMotorized = hasVehicle and vehicle.spec_motorized ~= nil
	if hasVehicle and isMotorized then
		self.vehicle = vehicle
		self.temperature.lastColor = nil
		self.temperature.faultlastColor = nil
		self.battery.lastColor = nil
		self.battery.faultlastColor = nil
		self.engine.lastColor = nil
		self.engine.faultlastColor = nil
		self.lights.lastColor = nil
		self.lights.faultlastColor = nil
		self.hudLightActive = false
	end
	if self.vehicle and self.vehicle.getConsumerFillUnitIndex ~= nil then
		self.hasDiesel   = self.vehicle:getConsumerFillUnitIndex(FillType.DIESEL) ~= nil
		self.hasElectric = self.vehicle:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE) ~= nil
		self.hasMethane  = self.vehicle:getConsumerFillUnitIndex(FillType.METHANE) ~= nil
	end
	self:setVisible(self.vehicle ~= nil)
	self.isVehicleDrawSafe = false

end
function RVB_HUD:draw()

	local vehicle = self.vehicle
	if vehicle == nil or not self.isVehicleDrawSafe then
		return
	end
	
	local rvb = vehicle.spec_faultData
	
	if rvb ~= nil and not rvb.isrvbSpecEnabled then
		return
	end

	g_currentMission.hud.speedMeter.speedTextSize = self:scalePixelToScreenHeight(43)

	local speedBgX, speedBgY = g_currentMission.hud.speedMeter.speedBg:getPosition()
	local posX = speedBgX + g_currentMission.hud.speedMeter.speedGaugeCenterOffsetX
	local posY = speedBgY + g_currentMission.hud.speedMeter.speedGaugeCenterOffsetY
	
	
	if rvb ~= nil and rvb.vehicleDebugEnabled then
		RVB_HUD:vehicleDebug(vehicle)
	end
	
	local motorState = vehicle:getMotorState()
	local RVBMain = g_currentMission.vehicleBreakdowns
	local GSET = g_currentMission.vehicleBreakdowns.generalSettings
	local GPSET = g_currentMission.vehicleBreakdowns.gameplaySettings
	local serviceVisible = false
	
	if not g_modIsLoaded["FS25_gameplay_RoadMaster"] then
		if RVBMain:getIsShowTempDisplay() and rvb ~= nil and self.hasDiesel then
			if vehicle.spec_motorized ~= nil then --and vehicle.isServer then
				local _useF = g_gameSettings:getValue(GameSettings.SETTING.USE_FAHRENHEIT)
				local _s = "C"
				if _useF then _s = "F" end
				local temp_txt1 = "0"
				local temp_txt2 = "\n°" .. _s
				--if motorState == MotorState.ON then
				if motorState == MotorState.ON or motorState == MotorState.IGNITION or motorState == MotorState.STARTING then
					local _value = vehicle.spec_motorized.motorTemperature.value
					if _useF then _value = _value * 1.8 + 32 end
					temp_txt1 = string.format("%i", _value)
				end
				local tempTextOffsetX = posX + self.tempTextOffsetX 
				local tempTextOffsetY = posY + self.tempTextOffsetY
				setTextColor(unpack(HUDCOLOR.BASE))
				setTextAlignment(RenderText.ALIGN_CENTER)
				setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
				setTextBold(true)
				renderText(tempTextOffsetX, tempTextOffsetY, self.tempTextSize, temp_txt1)
				setTextColor(unpack(HUD.COLOR.ACTIVE))
				renderText(tempTextOffsetX, tempTextOffsetY, self.tempTextSize, temp_txt2)
				setTextColor(unpack(HUDCOLOR.BASE))
				setTextAlignment(RenderText.ALIGN_LEFT)
			end
			if g_modIsLoaded["FS25_EnhancedVehicle"] then
				g_currentMission.EnhancedVehicle.hud.temp.enabled = false
			end
		end
		if RVBMain:getIsShowRpmDisplay() and rvb ~= nil and self.hasDiesel then
			if vehicle.spec_motorized ~= nil then --and vehicle.isServer then
				local rpm_txt1 = "0"
				local rpm_txt2 = "\nrpm"
				--if motorState == MotorState.ON then
				if motorState == MotorState.ON or motorState == MotorState.STARTING then
					rpm_txt1 = string.format("%i", vehicle.spec_motorized:getMotorRpmReal())
				end
				local rpmTextOffsetX = posX + self.rpmTextOffsetX 
				local rpmTextOffsetY = posY + self.rpmTextOffsetY
				setTextColor(unpack(HUDCOLOR.BASE))
				setTextAlignment(RenderText.ALIGN_CENTER)
				setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
				setTextBold(true)
				renderText(rpmTextOffsetX, rpmTextOffsetY, self.rpmTextSize, rpm_txt1)
				setTextColor(unpack(HUD.COLOR.ACTIVE))
				renderText(rpmTextOffsetX, rpmTextOffsetY + 0.002, self.rpmTextSize, rpm_txt2)
				setTextColor(unpack(HUDCOLOR.BASE))
				setTextAlignment(RenderText.ALIGN_LEFT)
			end
			if g_modIsLoaded["FS25_EnhancedVehicle"] then
				g_currentMission.EnhancedVehicle.hud.rpm.enabled = false
			end
		end
		if RVBMain:getIsShowFuelDisplay() and rvb ~= nil and (self.hasDiesel or self.hasElectric or self.hasMethane) then
			if (motorState == MotorState.ON or motorState == MotorState.STARTING) and vehicle.spec_fillUnit ~= nil then
				local electric  = self.fuelLevels and self.fuelLevels[FillType.ELECTRICCHARGE]
				if electric ~= nil and electric >= 0 then
					if self.lastfuelUsageText1 ~= "kW" then
						self.lastfuelUsageText1 = "kW"
					end
				else
					if self.lastfuelUsageText1 ~= "l/h" then
						self.lastfuelUsageText1 = "l/h"
					end
				end
				local currentFuelUsage = string.format("%.1f", self.fuelUsage)
				if self.lastfuelUsageText2 ~= currentFuelUsage then
					self.lastfuelUsageText2 = currentFuelUsage
				end
				local fuelIconX, fuelIconY = g_currentMission.hud.speedMeter.fuelIcon:getPosition()
				local fuelTextOffsetX = fuelIconX + self.fuelTextOffsetX - 0.001
				local fuelTextOffsetX_ = fuelIconX + self.fuelTextOffsetX + 0.001
				local fuelTextOffsetY = fuelIconY + self.fuelTextOffsetY
				setTextAlignment(RenderText.ALIGN_LEFT)
				setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
				setTextBold(true)
				setTextColor(unpack(HUD.COLOR.ACTIVE))
				renderText(fuelTextOffsetX_, fuelTextOffsetY, self.fuelTextSize, self.lastfuelUsageText1)
				setTextAlignment(RenderText.ALIGN_RIGHT)
				setTextColor(unpack(HUDCOLOR.BASE))
				renderText(fuelTextOffsetX, fuelTextOffsetY, self.fuelTextSize, self.lastfuelUsageText2)
			end
		end
	end

	if RVBMain:getIsShowMotorLoadDisplay() and rvb ~= nil and (self.hasDiesel or self.hasElectric or self.hasMethane) then
		if motorState == MotorState.ON then
			local currentMotorLoad = string.format("%d", rvb.motorLoadPercent)
			if self.lastmotorLoadText ~= currentMotorLoad then
				self.lastmotorLoadText = currentMotorLoad
			end
			local motorLoadTextOffsetX = posX + self.motorLoadTextOffsetX - 0.0005
			local motorLoadTextOffsetX_ = posX + self.motorLoadTextOffsetX + 0.0005
			local motorLoadTextOffsetY = posY + self.motorLoadTextOffsetY
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			setTextColor(unpack(HUD.COLOR.ACTIVE))
			renderText(motorLoadTextOffsetX_, motorLoadTextOffsetY, self.motorLoadTextSize, "%")
			setTextAlignment(RenderText.ALIGN_RIGHT)
			local _value = 0
			if vehicle.spec_motorized ~= nil then
				_value = vehicle.spec_motorized.motorTemperature.value
			end
			local motorLoadColor = HUDCOLOR.BASE
			local motorLoad = rvb.motorLoadPercent / 100
			if motorLoad > LOADPERCENTAGE_THRESHOLD then
				motorLoadColor = HUDCOLOR.CRITICAL
			--elseif _value < MOTORTEMP_THRESHOLD and motorLoad <= LOADPERCENTAGE_THRESHOLD and motorLoad > LOADPERCENTAGE_LOAD_THRESHOLD then
			elseif motorLoad <= LOADPERCENTAGE_THRESHOLD and motorLoad > LOADPERCENTAGE_LOAD_THRESHOLD then
				motorLoadColor = HUDCOLOR.WARNING
			else
				motorLoadColor = HUDCOLOR.BASE
			end
			setTextColor(unpack(motorLoadColor))
			renderText(motorLoadTextOffsetX, motorLoadTextOffsetY, self.motorLoadTextSize, self.lastmotorLoadText)
		end
	end

	if rvb ~= nil and self.hasDiesel then

		if motorState == MotorState.ON then

			local thermostatPart = rvb.parts[THERMOSTAT]
			local thermostat = FaultRegistry[THERMOSTAT]
			local thermostatHudVisible = thermostat.hud.visible
			if thermostat.isApplicable(vehicle) then
				self.temperature:setVisible(thermostatHudVisible)
				local motorTemp = vehicle.spec_motorized.motorTemperature.value
				ThermostatManager.updateThermostatColor(self, thermostatPart, motorTemp)
			end

			local generatorPart = rvb.parts[GENERATOR]
			local generator = FaultRegistry[GENERATOR]
			local generatorHud = generator.hud
			local generatorHudVisible = generatorHud.visible
			if generator.isApplicable(vehicle) then
				self.battery:setVisible(generatorHudVisible)
				GeneratorManager.updateColor(self, generatorPart)
			end

			local enginePart = rvb.parts[ENGINE]
			local engine = FaultRegistry[ENGINE]
			local engineHud = engine.hud
			local engineHudVisible = engineHud.visible
			if engine.isApplicable(vehicle) then
				self.engine:setVisible(engineHudVisible)
				EngineManager.updateColor(self, enginePart)
			end

			local lightingsPart = rvb.parts[LIGHTINGS]
			local lightings = FaultRegistry[LIGHTINGS]
			local lightingsHud = lightings.hud
			local lightingsHudVisible = lightingsHud.visible
			if lightings.isApplicable(vehicle) then
				self.lights:setVisible(lightingsHudVisible)
				LightingsManager.updateColor(self, lightingsPart)
			end
			
			serviceVisible = true
			local service_percent = (rvb.operatingHours * 100) / RVBMain:getPeriodicService()
			--if not rvb.parts[GENERATOR].damaged or not rvb.parts[GENERATOR].repairreq then
				if service_percent < 90 then
					setTextColor(unpack(self:getDefaultHudColor()))
				elseif service_percent >= 90 and service_percent < 99 then
					setTextColor(unpack(HUDCOLOR.WARNING))
				else
					setTextColor(unpack(HUDCOLOR.CRITICAL))
				end
			--else
				--setTextColor(unpack(HUDCOLOR.CRITICAL))
			--end



		elseif motorState == MotorState.STARTING or motorState == MotorState.IGNITION then
			self.temperature:setVisible(true)
			self.temperature:setColor(unpack(HUDCOLOR.COOL))

			self.battery:setVisible(true)
			self.battery:setColor(unpack(HUDCOLOR.CRITICAL))

			self.engine:setVisible(true)
			self.engine:setColor(unpack(HUDCOLOR.WARNING))

			self.lights:setVisible(true)
			self.lights:setColor(unpack(HUDCOLOR.WARNING))

			serviceVisible = true
			--self.service:setVisible(true)
			--self.service:setColor(unpack(HUDCOLOR.WARNING))
			setTextColor(unpack(HUDCOLOR.WARNING))

		else
			self.temperature:setVisible(true) --false
			self.temperature:setColor(unpack(self:getDefaultHudColor()))
			self.battery:setVisible(true) --false
			self.battery:setColor(unpack(self:getDefaultHudColor()))
			self.engine:setVisible(true) --false
			self.engine:setColor(unpack(self:getDefaultHudColor()))
			self.lights:setVisible(true) --false
			self.lights:setColor(unpack(self:getDefaultHudColor()))--HUDCOLOR.DEFAULT
			--self.service:setVisible(false)
			setTextColor(unpack(self:getDefaultHudColor()))
			serviceVisible = true --false

			self.temperature.lastColor = nil
			self.temperature.faultlastColor = nil
			self.battery.lastColor = nil
			self.battery.faultlastColor = nil
			self.engine.lastColor = nil
			self.engine.faultlastColor = nil
			self.lights.lastColor = nil
			self.lights.faultlastColor = nil
		end

		self.temperature:setPosition(posX + self.temperatureOffsetX, posY + self.temperatureOffsetY)
		self.temperature:render()
		--setTextAlignment(RenderText.ALIGN_LEFT)

		self.battery:setPosition(posX + self.batteryOffsetX, posY + self.batteryOffsetY)
		self.battery:render()
		--setTextAlignment(RenderText.ALIGN_LEFT)

		self.engine:setPosition(posX + self.engineOffsetX, posY + self.engineOffsetY)
		self.engine:render()
		--setTextAlignment(RenderText.ALIGN_LEFT)

		self.lights:setPosition(posX + self.lightsOffsetX, posY + self.lightsOffsetY)
		self.lights:render()
		--setTextAlignment(RenderText.ALIGN_LEFT)

		--self.service:setPosition(posX + self.serviceOffsetX, posY + self.serviceOffsetY)
		--self.service:render()
		--setTextAlignment(RenderText.ALIGN_CENTER)
		local service_txt1 = "SERVICE"
		if serviceVisible then
			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(posX + self.serviceTextOffsetX, posY + self.serviceTextOffsetY, self.serviceTextSize, service_txt1)
			setTextColor(unpack(HUDCOLOR.BASE))
			setTextAlignment(RenderText.ALIGN_LEFT)
		end
	end

	if GSET.vhuddisplay then
		local specf = vehicle.spec_faultData
		if specf ~= nil and vehicle.spec_motorized ~= nil and self.hasDiesel then
			local width = 0
			local debugBgScaleWidth = width + self.speedBgScaleWidth
			local speedBgX, speedBgY = g_currentMission.hud.speedMeter.speedBg:getPosition()
			speedBgX = speedBgX - 0.0025
			self.debugBgRight:setPosition(speedBgX - self.debugBgRight.width, speedBgY)
			self.debugBgScale:setDimension(debugBgScaleWidth, nil)
			self.debugBgScale:setPosition(self.debugBgRight.x - self.debugBgScale.width , speedBgY)
			self.debugBg:setPosition(self.debugBgScale.x - self.debugBg.width, speedBgY)
			self.debugBg:render()
			self.debugBgScale:render()
			self.debugBgRight:render()

			--local specf = vehicle.spec_faultData
			local COLOR = {}
			COLOR.DEFAULT = {1, 1, 1, 1}
			COLOR.YELLOW = {1.0000, 0.6592, 0.0000, 1}

			local posX = self.debugBg.x
			local posY = self.debugBg.y
			local damageTextOffsetX = posX + self.damageTextOffsetX 
			local damageTextOffsetY = posY + self.damageTextOffsetY
			local Partfoot = (vehicle:getDamageAmount() * 100) / 1
			--local batteryFillUnitIndex = vehicle:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE)
			--local Partfoot = (vehicle:getFillUnitFillLevel(batteryFillUnitIndex) * 100) / 100
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local damage_Text = rvb_Utils.to_upper(g_i18n:getText("ui_condition"))..": "..string.format("%.4f", vehicle:getDamageAmount()).." ("..string.format("%.0f", Partfoot).."%)"
			--local damage_Text = "DAMAGE: "..string.format("%.4f", vehicle:getFillUnitFillLevel(batteryFillUnitIndex)).." ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.DEFAULT))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(damageTextOffsetX, damageTextOffsetY, self.debugTextSize, damage_Text)	

			local thermostatTextOffsetX = posX + self.thermostatTextOffsetX 
			local thermostatTextOffsetY = posY + self.thermostatTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, THERMOSTAT)
			local Partfoot = (specf.parts[THERMOSTAT].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[THERMOSTAT].operatingHours)
			local minutes = math.floor((specf.parts[THERMOSTAT].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local thermostat_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_THERMOSTAT"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(thermostatTextOffsetX, thermostatTextOffsetY, self.debugTextSize, thermostat_Text)

			local lightingsTextOffsetX = posX + self.lightingsTextOffsetX 
			local lightingsTextOffsetY = posY + self.lightingsTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, LIGHTINGS)
			local Partfoot = (specf.parts[LIGHTINGS].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[LIGHTINGS].operatingHours)
			local minutes = math.floor((specf.parts[LIGHTINGS].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local lightings_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_LIGHTINGS"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(lightingsTextOffsetX, lightingsTextOffsetY, self.debugTextSize, lightings_Text)

			local glowplugTextOffsetX = posX + self.glowplugTextOffsetX 
			local glowplugTextOffsetY = posY + self.glowplugTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, GLOWPLUG)
			local Partfoot = (specf.parts[GLOWPLUG].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[GLOWPLUG].operatingHours)
			local minutes = math.floor((specf.parts[GLOWPLUG].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local glowplug_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_GLOWPLUG"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(glowplugTextOffsetX, glowplugTextOffsetY, self.debugTextSize, glowplug_Text)

			local wipersTextOffsetX = posX + self.wipersTextOffsetX 
			local wipersTextOffsetY = posY + self.wipersTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, WIPERS)
			local Partfoot = (specf.parts[WIPERS].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[WIPERS].operatingHours)
			local minutes = math.floor((specf.parts[WIPERS].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local wipers_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_WIPERS"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(wipersTextOffsetX, wipersTextOffsetY, self.debugTextSize, wipers_Text)

			local generatorTextOffsetX = posX + self.generatorTextOffsetX 
			local generatorTextOffsetY = posY + self.generatorTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, GENERATOR)
			local Partfoot = (specf.parts[GENERATOR].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[GENERATOR].operatingHours)
			local minutes = math.floor((specf.parts[GENERATOR].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local generator = FaultRegistry[GENERATOR]
			local generator_Text = rvb_Utils.to_upper(g_i18n:getText(generator.name))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(generatorTextOffsetX, generatorTextOffsetY, self.debugTextSize, generator_Text)

			local engineTextOffsetX = posX + self.engineTextOffsetX 
			local engineTextOffsetY = posY + self.engineTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, ENGINE)
			local Partfoot = (specf.parts[ENGINE].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[ENGINE].operatingHours)
			local minutes = math.floor((specf.parts[ENGINE].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local engine_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_ENGINE"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(engineTextOffsetX, engineTextOffsetY, self.debugTextSize, engine_Text)

			local selfstarterTextOffsetX = posX + self.selfstarterTextOffsetX 
			local selfstarterTextOffsetY = posY + self.selfstarterTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, SELFSTARTER)
			local Partfoot = (specf.parts[SELFSTARTER].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[SELFSTARTER].operatingHours)
			local minutes = math.floor((specf.parts[SELFSTARTER].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local selfstarter_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_SELFSTARTER"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(selfstarterTextOffsetX, selfstarterTextOffsetY, self.debugTextSize, selfstarter_Text)

			local batteryTextOffsetX = posX + self.batteryTextOffsetX 
			local batteryTextOffsetY = posY + self.batteryTextOffsetY
			local maxLifetime = PartManager.getMaxPartLifetime(vehicle, BATTERY)
			local Partfoot = (specf.parts[BATTERY].operatingHours * 100) / maxLifetime
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.parts[BATTERY].operatingHours)
			local minutes = math.floor((specf.parts[BATTERY].operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local battery_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_faultText_BATTERY"))..": "..string.format("%s:%s", hours, minutes).."/"..maxLifetime..":00 ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(batteryTextOffsetX, batteryTextOffsetY, self.debugTextSize, battery_Text)

			local serviceDTextOffsetX = posX + self.serviceDTextOffsetX 
			local serviceDTextOffsetY = posY + self.serviceDTextOffsetY
			local Partfoot = (specf.operatingHours * 100) / g_currentMission.vehicleBreakdowns:getPeriodicService()
			Partfoot = MathUtil.round(Partfoot)
			Partfoot = 100 - Partfoot
			if Partfoot < 0 then Partfoot = 0 end
			local hours = math.floor(specf.operatingHours)
			local minutes = math.floor((specf.operatingHours - hours) * 60)
			if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
			if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end
			local service_Text = rvb_Utils.to_upper(g_i18n:getText("RVB_settingSectionHeader_Service"))..": "..string.format("%s", hours).."/"..g_currentMission.vehicleBreakdowns:getPeriodicService().." ("..string.format("%.0f", Partfoot).."%)"
			setTextColor(unpack(COLOR.YELLOW))
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
			setTextBold(true)
			renderText(serviceDTextOffsetX, serviceDTextOffsetY, self.debugTextSize, service_Text)
		end
	end

	setTextColor(1,1,1,1)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
	setTextBold(false)
end


-- Utils.renderMultiColumnText
function RVB_renderMultiColumnTextAA(x, y, textSize, texts, spacingX, aligns)
	for v207_, v208_ in ipairs(texts) do
		local v209_ = aligns ~= nil and aligns[v207_] or RenderText.ALIGN_LEFT
		setTextAlignment(v209_)
		setTextColor(1,1,1,1)
		local v210_ = getTextWidth(textSize, v208_)
		if v209_ == RenderText.ALIGN_RIGHT then
			renderText(x + v210_, y, textSize, v208_)
		elseif v209_ == RenderText.ALIGN_CENTER then
			renderText(x + v210_ * 0.5, y, textSize, v208_)
		else
			--setTextColor(1, 0.5, 0, 1) -- narancs
			setTextColor(1,1,1,1)
			renderText(x, y, textSize, v208_)
		end
		x = x + v210_ + spacingX
	end
	setTextAlignment(RenderText.ALIGN_LEFT)
end
function RVB_renderMultiColumnText(x, y, textSize, texts, spacingX, aligns)
	local lineHeight = getTextHeight(textSize, "A")

	for col, text in ipairs(texts) do
		local align = aligns and aligns[col] or RenderText.ALIGN_LEFT
		setTextAlignment(align)

		local lines_ = string.split(text, "\n")
		local maxWidth = 0

		for i, line in ipairs(lines_) do
			if line ~= "" then
				local width = getTextWidth(textSize, line)
				maxWidth = math.max(maxWidth, width)

				local drawX = x
				if align == RenderText.ALIGN_RIGHT then
					drawX = x + width
				elseif align == RenderText.ALIGN_CENTER then
					drawX = x + width * 0.5
				end

				renderText(drawX, y - (i - 1) * lineHeight, textSize, line)
			end
		end

		x = x + maxWidth + spacingX
	end

	setTextAlignment(RenderText.ALIGN_LEFT)
end

function RVB_HUD:vehicleDebug(vehicle)

	local spec = vehicle.spec_faultData
	if vehicle.isClient and vehicle:getIsControlled() then

		local textSize = getCorrectTextSize(0.02)

		local baseX, baseY = 0.2, 0.70
		local yStep = 0.02

		setTextColor(1,1,1,1)
		setTextBold(false)
		setTextAlignment(RenderText.ALIGN_LEFT)

		renderText(baseX, baseY, textSize, string.format("[VehicleBreakdowns Debug]"))

		baseY = baseY - yStep
		renderText(baseX, baseY, textSize, string.format("%s", vehicle:getFullName() or "unknown"))

		local batteryFillLevel = vehicle:getFillUnitFillLevel(vehicle:getBatteryFillUnitIndex()) --spec.batteryFillUnitIndex
		local motorSpec = vehicle.spec_motorized
		local motor = vehicle.getMotor and vehicle:getMotor()
		local rpm = motor:getEqualizedMotorRpm()
		local torque = motor:getTorqueCurveValue(rpm)
		local kW = motor.peakMotorPower
		local torque = motor:getMotorAvailableTorque()
		local neededPtoTorque = motor:getMotorExternalTorque()
		local motorPower = motor:getMotorRotSpeed() * (torque - neededPtoTorque) * 1000

		local baseX, baseY = 0.2, 0.64
		local s11_ = ""
		local s12_ = ""
		local s21_ = s11_ .. "Battery drain amount:\n"
		local s22_ = s12_ .. string.format("%.6f\n", spec.batteryDrainAmount or 0)
		local s31_ = s21_ .. "Battery charge amount:\n"
		local s32_ = s22_ .. string.format("%.6f\n", spec.batteryChargeAmount or 0)
		local s41_ = s31_ .. "Battery:\n"
		local s42_ = s32_ .. string.format("%.6f\n", batteryFillLevel or 0)
		local s51_ = s41_ .. "Motor temp:\n"
		local s52_ = s42_ .. string.format("%.6f\n", motorSpec.motorTemperature.value or 0)
		local s61_ = s51_ .. "Torque:\n"
		local s62_ = s52_ .. string.format("%.6f, (%.6f), %.0f kW\n", spec.lastTorqueFactor or 0, torque or 0, kW or 0)
		local s71_ = s61_ .. "Motor:\n"
		local s72_ = s62_ .. string.format("%1.2frpm available power: %1.2fhp %1.2fkW\n", motor:getNonClampedMotorRpm(), motorPower / 735.49875, motorPower / 1000)
		RVB_renderMultiColumnText(baseX, baseY, textSize, { s71_, s72_ }, 0.008, { RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT })
		--Utils.renderMultiColumnText(baseX, baseY, textSize, { s71_, s72_ }, 0.008, { RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT })

        --baseY = baseY - yStep*2
		local baseX, baseY = 0.2, 0.46
		--setTextColor(1,1,1,1)
        -- Megjelenít néhány alkatrészt
		local shown = 0
		
		local v130_ = {
			"\n",
			"Part\n",
			"Lifetime\n",
			"Prefault\n",
			"Fault\n",
			"repairreq\n"
		}
		for index, key in ipairs(g_vehicleBreakdownsPartKeys) do
			local part = spec.parts[key]
			if part then
				local maxLifetime = PartManager.getMaxPartLifetime(vehicle, key)
				local Partfoot = (part.operatingHours * 100) / maxLifetime
				Partfoot = MathUtil.round(Partfoot)
				Partfoot = 100 - Partfoot
				if Partfoot < 0 then Partfoot = 0 end
				local hours = math.floor(part.operatingHours)
				local minutes = math.floor((part.operatingHours - hours) * 60)
				if hours < 10 then hours = string.format("0%s", hours) else hours = string.format("%s", hours) end
				if minutes < 10 then minutes = string.format("0%s", minutes) else minutes = string.format("%s", minutes) end

				--[[RVB_renderMultiColumnText(
					baseX, baseY, textSize,
					{
						"",
						part.name,
						"lifetime:",
						string.format("%.6f (%s:%s - %.0f%%)", part.operatingHours, hours, minutes, Partfoot),
						"prefault:",
						tostring(part.prefault),
						"fault:",
						tostring(part.fault),
						"repairreq:",
						tostring(part.damaged)
					},

					0.005,

					{ RenderText.ALIGN_LEFT, RenderText.ALIGN_RIGHT,
					RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT,
					RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT,
					RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT,
					RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT }
				)
				baseY = baseY - 0.025]]
				v130_[1] = v130_[1] .. string.format("%d:\n", index)
				v130_[2] = v130_[2] .. string.format("%s\n", part.name)
				v130_[3] = v130_[3] .. string.format("%.6f (%s:%s - %.0f%%)\n", part.operatingHours, hours, minutes, Partfoot)
				v130_[4] = v130_[4] .. string.format("%s\n", tostring(part.prefault))
				v130_[5] = v130_[5] .. string.format("%s\n", tostring(part.fault))
				v130_[6] = v130_[6] .. string.format("%s\n", tostring(part.repairreq))
				shown = shown + 1
				--if shown >= 6 then break end -- ne írja ki mind a 12-t
			end
		end
		setTextColor(1,1,1,1)
		RVB_renderMultiColumnText(baseX, baseY, textSize, v130_, 0.008, { RenderText.ALIGN_RIGHT, RenderText.ALIGN_RIGHT })
		--Utils.renderMultiColumnText(baseX, baseY, textSize, v130_, 0.008, { RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT })
		


		--setTextColor(1,1,1,1)
		--setTextAlignment(RenderText.ALIGN_LEFT)
	end
end
