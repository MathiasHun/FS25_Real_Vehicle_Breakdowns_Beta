
SelfStarterManager = {}

local r = FaultRegistry[SELFSTARTER]
local ghud = r.hud
local condition = ghud.condition
local variants = r.variants

function SelfStarterManager.rbv_startMotor(vehicle)
	if not vehicle then return end
	local rvbspec = vehicle.spec_faultData
	if rvbspec == nil or not rvbspec.isrvbSpecEnabled then return end
	if not r.isApplicable(vehicle) then return end
	local part = rvbspec.parts[SELFSTARTER]
	local prefaultName, fault = vehicle:getIsFaultStates(SELFSTARTER)
	--local prefaultName = (part.prefault ~= "empty" and part.prefault) or nil
	--if not prefaultName then
	--	return
	--end
	local minIgnition, maxIgnition = 1, 4
	if prefaultName == "starterClickOnly" or prefaultName == "relayFault" or prefaultName == "connectorIssue" then
		if math.random(0, 2) == 0 then
			ignition = 0
		else
			ignition = math.random(1, 2)
		end
	else
		--if part.prefault ~= "empty" and part.fault == "empty" then
		if prefaultName ~= "empty" and fault == "empty" then
			ignition = math.random(2, 4)
		--elseif part.prefault ~= "empty" and part.fault ~= "empty" then
		elseif prefaultName ~= "empty" and fault ~= "empty" then
			ignition = math.random(3, 5)
		end
	end
	return ignition
end
function SelfStarterManager.startMotor(vehicle)
	if vehicle == nil then return end
	local rvbspec = vehicle.spec_faultData
	if rvbspec == nil or not rvbspec.isrvbSpecEnabled then return end
	local part = rvbspec.parts[SELFSTARTER]
	-- github issues#112 60 -> 30
	local oneGameMinute = 30
	local maxLifetime = PartManager.getMaxPartLifetime(vehicle, SELFSTARTER)
	if part.operatingHours < maxLifetime then
		part.operatingHours = part.operatingHours + oneGameMinute / 3600
	end
end

return SelfStarterManager