
EngineManager = {}
-- Cache-elt hibaregiszter
local g = FaultRegistry[ENGINE]
local ghud = g.hud
local condition = ghud.condition
local variants = g.variants

function EngineManager.updateColor(hud, part)
	local newColor = hud:getDefaultHudColor()--HUDCOLOR.DEFAULT
	local variantDef = variants[part.fault]
	if variantDef and variantDef.hudcolor then
		newColor = variantDef.hudcolor
	end
	local HUD = hud.engine
	if not HUD.lastColor or not rvb_Utils.colorsAreEqual(HUD.lastColor, newColor) then
		if part.fault ~= "empty" then
			HUD:setColor(unpack(hud:getDefaultHudColor()))
		else
			HUD:setColor(unpack(newColor))
		end
		HUD.lastColor = newColor
    end
end
function EngineManager.updateHud(hud, vehicle, dt)
	local HUD = hud.engine
	local currentColor = HUD.lastColor or hud:getDefaultHudColor()--HUDCOLOR.DEFAULT
	local rvb = vehicle.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then return end
	local part = rvb.parts[ENGINE]
	if vehicle:getIsMotorStarted() then
		local fault = part and part.fault or "empty"
		-- Reset, ha változott a hiba
		if fault ~= HUD.lastFault then
			HUD.timer = 0
			HUD.playCount = 0
			HUD.colorState = false
			HUD.lastFault = fault
		end
		if fault ~= "empty" then
			HUD.timer = (HUD.timer or 0) + dt
			HUD.colorState = HUD.colorState or false
			HUD.playCount = HUD.playCount or 0
			if HUD.playCount < 3 and not part.runOncePerStart then
				if HUD.timer > 1400 then
					if not HUD.colorState then
						-- Hang csak ha még nem játszódott le 3-szor
						HUD:setColor(unpack(currentColor))
						g_soundManager:playSample(rvb.samples.dasalert)
						HUD.playCount = HUD.playCount + 1
						HUD.colorState = true
					end
					HUD.timer = 0
				elseif HUD.timer > 700 then
					if HUD.colorState then
						HUD:setColor(unpack(hud:getDefaultHudColor()))
						HUD.colorState = false
					end
				end
			else
				part.runOncePerStart = true
				if not HUD.lastColorHud or not rvb_Utils.colorsAreEqual(HUD.lastColorHud, currentColor) then
					HUD:setColor(unpack(currentColor))
					HUD.lastColorHud = currentColor
				end
			end
		else
			HUD.timer = 0
			HUD.colorState = false
			HUD.playCount = 0
		end
	else
		HUD.timer = 0
		HUD.colorState = false
		HUD.playCount = 0
	end
end
return EngineManager