
PartManager = {}

function PartManager.getMaxPartLifetime(vehicle, partKey)
    local RVB = g_currentMission.vehicleBreakdowns
    local GPSET = RVB.gameplaySettings

    local baseLifetime = RVB:getPartBaseLifetime(partKey)
    if baseLifetime <= 0 then
        return 0
    end

    local daysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod or 1

    local tireMultiplier = 1
    if partKey == TIREFL or partKey == TIREFR or partKey == TIRERL or partKey == TIRERR then
        tireMultiplier = 1000
    end

    if GPSET.difficulty == 1 then
        return baseLifetime * 2 * daysPerPeriod * tireMultiplier
    elseif GPSET.difficulty == 2 then
        return baseLifetime * 1 * daysPerPeriod * tireMultiplier
    else
        return baseLifetime / 2 * daysPerPeriod * tireMultiplier
    end
end
function PartManager.loadFromDefaultConfig(vehicle)
	local spec = vehicle.spec_faultData
	local GSET = g_currentMission.vehicleBreakdowns.generalSettings
	local GPSET = g_currentMission.vehicleBreakdowns.gameplaySettings
	spec.parts = {}
	local xmlFilePath = Utils.getFilename('config/PartsSettingsSetup.xml', g_vehicleBreakdownsDirectory)
	local xmlFile = XMLFile.load("settingSetupXml", xmlFilePath)
	if xmlFile ~= nil then
		for i, partKeyName in ipairs(g_vehicleBreakdownsPartKeys) do
			local key = string.format("Parts.Part(%d)", i - 1)
			if not xmlFile:hasProperty(key) then break end
			spec.parts[partKeyName] = {
				name            = xmlFile:getString(key.."#name", "PartName"),
				operatingHours  = 0.000000,
				repairreq       = xmlFile:getBool(key.."#repairreq", false),
				prefault        = xmlFile:getString(key.."#prefault", "empty"),
				fault           = xmlFile:getString(key.."#fault", "empty"),
				cost            = xmlFile:getFloat(key.."#cost", 0),
				runOncePerStart = false,
				odoDistanceSent = 0.000000
			}
			spec.parts[partKeyName].pre_random = math.random(3,6)
			if partKeyName == GLOWPLUG then
				spec.parts[partKeyName].pre_random = math.random(1,5)
			end
		end
		xmlFile:delete()
	end
end
function PartManager.loadFromPostLoad(vehicle, savegame)
	if not (vehicle and vehicle.spec_faultData) then
		Logging.error("PartManager.onPostLoad() No vehicle.")
		return false
	end
	local rvb = vehicle.spec_faultData
	local GSET = g_currentMission.vehicleBreakdowns.generalSettings
	local GPSET = g_currentMission.vehicleBreakdowns.gameplaySettings
	local keyparts = string.format("%s.%s.vehicleBreakdowns", savegame.key, g_vehicleBreakdownsModName)
	for i, partKey in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = rvb.parts[partKey]
		if part then
			local keyss = string.format("%s.parts.part(%d)", keyparts, i - 1)
			part.name            = savegame.xmlFile:getValue(keyss .. "#name", part.name)
			part.operatingHours  = savegame.xmlFile:getValue(keyss .. "#operatingHours", part.operatingHours)
			part.repairreq       = savegame.xmlFile:getValue(keyss .. "#repairreq", part.repairreq)
			part.prefault        = savegame.xmlFile:getValue(keyss .. "#prefault", part.prefault)
			part.fault           = savegame.xmlFile:getValue(keyss .. "#fault", part.fault)
			part.cost            = savegame.xmlFile:getValue(keyss .. "#cost", part.cost)
			part.odoDistanceSent = part.operatingHours
		end
	end
end
function PartManager.savePartsToXML(vehicle, xmlFile, key)
	local spec = vehicle.spec_faultData
	local i = 0
	for _, partKeyName in ipairs(g_vehicleBreakdownsPartKeys) do
		local part = spec.parts[partKeyName]
		if part and part.name ~= nil and part.name ~= "" then
			local partKey = string.format("%s.parts.part(%d)", key, i)
			xmlFile:setValue(partKey.."#name", part.name)
			xmlFile:setValue(partKey.."#operatingHours", part.operatingHours)
			xmlFile:setValue(partKey.."#repairreq", part.repairreq)
			xmlFile:setValue(partKey.."#prefault", tostring(part.prefault))
			xmlFile:setValue(partKey.."#fault", tostring(part.fault))
			xmlFile:setValue(partKey.."#cost", part.cost)
			i = i + 1
		end
	end
end
function PartManager.PartsDefaults(data)
	local defaults = {
		name = "",
		operatingHours = 0,
		repairreq = false,
		prefault = "empty",
		fault = "empty",
		cost = 0,
		runOncePerStart = false,
		pre_random = math.random(3,6),
		odoDistanceSent = 0,
	}
	for key, defaultValue in pairs(defaults) do
		if data[key] == nil then
			data[key] = defaultValue
		end
	end
	return data
end	

return PartManager