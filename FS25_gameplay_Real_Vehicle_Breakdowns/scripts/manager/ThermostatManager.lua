
ThermostatManager = {}

local g = FaultRegistry[THERMOSTAT]
local ghud = g.hud
local gtemp = ghud.temp
local condition = ghud.condition
local variants = g.variants

function ThermostatManager.updateThermostatColor(hud, part, motorTemp)
	local variantDef = variants[part.fault]
	local newColor = hud:getDefaultHudColor()
	--if motorTemp < gtemp.cool then
	--	newColor = HUDCOLOR.COOL
	--end
	local hudThermostat = hud.temperature
	if motorTemp > gtemp.critical then
		newColor = HUDCOLOR.CRITICAL
	elseif motorTemp > gtemp.default+2 and motorTemp <= gtemp.critical then
		newColor = HUDCOLOR.WARNING
	elseif motorTemp >= gtemp.cool and motorTemp <= gtemp.default then
		newColor = hud:getDefaultHudColor()
	elseif motorTemp < gtemp.cool then
		newColor = HUDCOLOR.COOL
	else
		newColor = hud:getDefaultHudColor()
	end
	if variantDef and variantDef.hudcolor then
		newColor = variantDef.hudcolor(motorTemp, gtemp)
	end
	if not hudThermostat.lastColor or not rvb_Utils.colorsAreEqual(hudThermostat.lastColor, newColor) then
		if part.fault ~= "empty" then
			hudThermostat:setColor(unpack(hud:getDefaultHudColor()))
		else
			if motorTemp > gtemp.default+2 then
				hudThermostat:setColor(unpack(hud:getDefaultHudColor()))
			else
				hudThermostat:setColor(unpack(newColor))
			end
		end
		hudThermostat.lastColor = newColor
	end
end
function ThermostatManager.updateThermostatHud(hud, vehicle, dt)
	local hudThermostat = hud.temperature
	local currentColor = hudThermostat.lastColor or hud:getDefaultHudColor()
	local rvb = vehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[THERMOSTAT]
	if vehicle:getIsMotorStarted() then
		local fault = part and part.fault or "empty"
		if fault ~= hudThermostat.lastFault then
			hudThermostat.timer = 0
			hudThermostat.playCount = 0
			hudThermostat.colorState = false
			hudThermostat.lastFault = fault
		end
		if fault ~= "empty" then
			hudThermostat.timer = (hudThermostat.timer or 0) + dt
			hudThermostat.colorState = hudThermostat.colorState or false
			hudThermostat.playCount = hudThermostat.playCount or 0
			if hudThermostat.playCount < 3 and not part.runOncePerStart then
				if hudThermostat.timer > 1400 then
					if not hudThermostat.colorState then
						hudThermostat:setColor(unpack(currentColor))
						g_soundManager:playSample(rvb.samples.dasalert)
						hudThermostat.playCount = hudThermostat.playCount + 1
						hudThermostat.colorState = true
					end
					hudThermostat.timer = 0
				elseif hudThermostat.timer > 700 then
					if hudThermostat.colorState then
						hudThermostat:setColor(unpack(hud:getDefaultHudColor()))
						hudThermostat.colorState = false
					end
				end
			else
				part.runOncePerStart = true
				if not hudThermostat.lastColorHud or not rvb_Utils.colorsAreEqual(hudThermostat.lastColorHud, currentColor) then
					hudThermostat:setColor(unpack(currentColor))
					hudThermostat.lastColorHud = currentColor
				end
			end
		else
			hudThermostat.timer = 0
			hudThermostat.colorState = false
			hudThermostat.playCount = 0
		end
	else
		hudThermostat.timer = 0
		hudThermostat.colorState = false
		hudThermostat.playCount = 0
	end
end

function ThermostatManager.updateDirtHud(hud, vehicle, dt)
	local hudThermostat = hud.temperature
	local currentColor = hudThermostat.lastColor or hud:getDefaultHudColor()
	local rvb = vehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	if vehicle:getIsMotorStarted() then
		hudThermostat.dirtPlay = false
		local motorTemp = vehicle.spec_motorized.motorTemperature.value
		if motorTemp > gtemp.critical then
			--newColor = HUDCOLOR.CRITICAL
			hudThermostat.dirtPlay = true
		elseif motorTemp > gtemp.default+2 and motorTemp <= gtemp.critical then
			--newColor = HUDCOLOR.WARNING
			hudThermostat.dirtPlay = true
		elseif motorTemp >= gtemp.cool and motorTemp <= gtemp.default then
			--newColor = HUDCOLOR.DEFAULT
			hudThermostat.dirttimer = 0
			hudThermostat.dirtplayCount = 0
			hudThermostat.dirtcolorState = false
		elseif motorTemp < gtemp.cool then
			--newColor = HUDCOLOR.COOL
		else
			--newColor = HUDCOLOR.DEFAULT
		end
		if hudThermostat.dirtPlay then
			hudThermostat.dirttimer = (hudThermostat.dirttimer or 0) + dt
			hudThermostat.dirtcolorState = hudThermostat.dirtcolorState or false
			hudThermostat.dirtplayCount = hudThermostat.dirtplayCount or 0
			if hudThermostat.dirtplayCount < 2 then
				if hudThermostat.dirttimer > 1400 then
					if not hudThermostat.dirtcolorState then
						hudThermostat:setColor(unpack(currentColor))
						g_soundManager:playSample(rvb.samples.dasalert)
						hudThermostat.dirtplayCount = hudThermostat.dirtplayCount + 1
						hudThermostat.dirtcolorState = true
					end
					hudThermostat.dirttimer = 0
				elseif hudThermostat.dirttimer > 700 then
					if hudThermostat.dirtcolorState then
						hudThermostat:setColor(unpack(hud:getDefaultHudColor()))
						hudThermostat.dirtcolorState = false
					end
				end
			else
				if not hudThermostat.lastColorHud or not rvb_Utils.colorsAreEqual(hudThermostat.lastColorHud, currentColor) then
					hudThermostat:setColor(unpack(currentColor))
					hudThermostat.lastColorHud = currentColor
				end
			end
		else
			hudThermostat.dirttimer = 0
			hudThermostat.dirtcolorState = false
			hudThermostat.dirtplayCount = 0
		end
	else
		hudThermostat.dirttimer = 0
		hudThermostat.dirtcolorState = false
		hudThermostat.dirtplayCount = 0
	end
end

return ThermostatManager