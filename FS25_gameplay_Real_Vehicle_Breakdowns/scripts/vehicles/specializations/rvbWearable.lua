rvbWearable = {}

function rvbWearable.updateDamageAmount(self, superFunc, dt)
    local rvb = self.spec_faultData
	if rvb == nil or not rvb.isrvbSpecEnabled then
        return superFunc(self, dt)
    end
	local motorSpec = self.spec_motorized
	if not motorSpec then
		return 0
	end
	if rvb.needsInitialDamageSync then
        rvb.needsInitialDamageSync = false
    elseif not self:getIsMotorStarted() then
        return 0
    end
    local parts = rvb.parts
	if not parts then
		return 0
	end
    local partKeys = g_vehicleBreakdownsPartKeys
    local tyreParts = TYRE_PARTS
    local totalLifetime = 0
    local totalOperatingHours = 0
    for i = 1, #partKeys do
        local key = partKeys[i]
        local part = parts[key]
        if part and not tyreParts[key] then
			local maxLifetime = rvb.cachedMaxLifetime[key]
            totalLifetime = totalLifetime + maxLifetime
            totalOperatingHours = totalOperatingHours + part.operatingHours
        end
    end
    local damage = 0
    if totalLifetime > 0 then
        damage = totalOperatingHours / totalLifetime
    end
    self:setDamageAmount(damage)
    return 0
end
