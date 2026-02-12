
rvbLights = {}

function rvbLights.updateAutomaticLights(self, superFunc, isTurnedOn, isWorking)
	local specRvb = self.spec_faultData
	if specRvb == nil or not specRvb.isrvbSpecEnabled then
		return superFunc(self, isTurnedOn, isWorking)
    end
	local spec = self.spec_lights
	if isTurnedOn then
		if g_modIsLoaded["FS25_Courseplay"] and self.spec_cpAIWorker ~= nil and self.spec_cpAIWorker.motorDisabled then
			if spec.lightsTypesMask ~= 0 then
				--self:setLightsTypesMask(0)
				self:deactivateLights()
				--self:setBeaconLightsVisibility(false, true, true)
			end
			return
		end

		if g_modIsLoaded["FS25_AutoDrive"] and self.ad ~= nil and self.ad.stateModule:isActive() and not self:getIsMotorStarted() and self.ad.specialDrivingModule.shouldStopOrHoldVehicle then
			if spec.lightsTypesMask ~= 0 then
				--self:setLightsTypesMask(0)
				self:deactivateLights()
				--self:setBeaconLightsVisibility(false, true, true)
			end
			return
		end
	end
	return superFunc(self, isTurnedOn, isWorking)
end
Lights.updateAutomaticLights = Utils.overwrittenFunction(Lights.updateAutomaticLights, rvbLights.updateAutomaticLights)

	--[[if g_modIsLoaded["FS25_AutoDrive"] then
		if FS25_AutoDrive ~= nil then print(self:getFullName() .." shouldStopOrHoldVehicle "..tostring(self.ad.specialDrivingModule.shouldStopOrHoldVehicle))
			if self.ad.stateModule:isActive() then
				if not self:getIsMotorStarted() and self.deactivateLights then
					self:deactivateLights()
				end
				--print(self:getFullName() .." FS25_AutoDrive isActive")
			end
		end
	end 
	if g_modIsLoaded["FS25_Courseplay"] then
		if FS25_Courseplay ~= nil then
			--print(self:getFullName() .. " getIsCpActive " ..tostring(self:getIsCpActive()))
			--print(self:getFullName() .. " getIsAIActive " ..tostring(self:getIsAIActive()))
			if self.spec_cpAIWorker ~= nil then
				if self.spec_cpAIWorker.motorDisabled then
					--if not self:getIsMotorStarted() and self.deactivateLights then
						--self:deactivateLights()
						--self:setBeaconLightsVisibility(true, true, true)
					--end
				end
			end
		end
	end]]