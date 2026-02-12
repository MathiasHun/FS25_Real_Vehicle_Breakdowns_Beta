rvbWearable = {}

function rvbWearable.updateDamageAmount(self, superFunc, dt)
	local rvb = self.spec_faultData
	if rvb and rvb.isrvbSpecEnabled then
		local currentPartslifetime = 0
		local currentPartsoperatingHours = 0
		local ignoredParts = {
			TIREFL = true, TIREFR = true, TIRERL = true, TIRERR = true
		}
		for _, key in ipairs(g_vehicleBreakdownsPartKeys) do
			if rvb.parts ~= nil then
				local part = rvb.parts[key]
				if part and not ignoredParts[key] then
					local maxLifetime = PartManager.getMaxPartLifetime(self, key)
					currentPartslifetime = currentPartslifetime + maxLifetime
					currentPartsoperatingHours = currentPartsoperatingHours + part.operatingHours
				end
			end
		end
		if currentPartslifetime > 0 then
			self:setDamageAmount(currentPartsoperatingHours / currentPartslifetime)
		else
			self:setDamageAmount(0)
		end
		return 0
	else
		return superFunc(self, dt)
	end
end