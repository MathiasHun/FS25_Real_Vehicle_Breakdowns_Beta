
rvb_Utils = {}

function rvb_Utils.removeLifetimeText(field)
	--return string.upper(field:gsub("%Lifetime", ""))
	return string.upper(field:gsub("Lifetime", ""))
end

function rvb_Utils.table_count(array)
	local count = 0
	for _ in pairs(array) do count = count + 1 end
	return count
end

function rvb_Utils.getLargeLifetimeString(valueIndex)
	local value = rvb_Utils.getLargeLifetimeFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getLargeLifetimeKmString(valueIndex)
	local value = rvb_Utils.getLargeLifetimeFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_km"), value)
end

function rvb_Utils.getLargeLifetimeFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.LargeArray[valueIndex]
end

function rvb_Utils.getLargeLifetimeIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.LargeArray, 1, -1 do
		if rvb_Utils.LargeArray[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getSmallLifetimeString(valueIndex)
	local value = rvb_Utils.getSmallLifetimeFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getSmallLifetimeFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.SmallArray[valueIndex]
end

function rvb_Utils.getSmallLifetimeIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.SmallArray, 1, -1 do
		if rvb_Utils.SmallArray[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getDailyServiceString(valueIndex)
	local value = rvb_Utils.getDailyServiceFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getDailyServiceFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.DailyService[valueIndex]
end

function rvb_Utils.getDailyServiceIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.DailyService, 1, -1 do
		if rvb_Utils.DailyService[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getPeriodicServiceString(valueIndex)
	local value = rvb_Utils.getPeriodicServiceFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getPeriodicServiceFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.PeriodicService[valueIndex]
end

function rvb_Utils.getPeriodicServiceIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.PeriodicService, 1, -1 do
		if rvb_Utils.PeriodicService[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getWorkshopOpenString(valueIndex)
	local value = rvb_Utils.getWorkshopOpenFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getWorkshopOpenFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.WorkshopOpen[valueIndex]
end

function rvb_Utils.getWorkshopOpenIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.WorkshopOpen, 1, -1 do
		if rvb_Utils.WorkshopOpen[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getWorkshopCloseString(valueIndex)
	local value = rvb_Utils.getWorkshopCloseFromIndex(valueIndex)
	return string.format(g_i18n:getText("RVB_utils_hour"), value)
end

function rvb_Utils.getWorkshopCloseFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.WorkshopClose[valueIndex]
end

function rvb_Utils.getWorkshopCloseIndex(value, defaultIndex)
	if value == nil then
        --print("Hiba: value értéke nil!")
        return defaultIndex
    end
	for i = #rvb_Utils.WorkshopClose, 1, -1 do
		if rvb_Utils.WorkshopClose[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getWorkshopCountMaxString(valueIndex)
	local value = rvb_Utils.getWorkshopCountMaxFromIndex(valueIndex)
	--return string.format(g_i18n:getText("RVB_utils_maxcount"), value)
	return tostring(value)
end

function rvb_Utils.getWorkshopCountMaxFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.WorkshopCountMax[valueIndex]
end

function rvb_Utils.getWorkshopCountMaxIndex(value, defaultIndex)
	if value == nil then
        --print("Hiba: value értéke nil!")
        return defaultIndex
    end
	for i = #rvb_Utils.WorkshopCountMax, 1, -1 do
		if rvb_Utils.WorkshopCountMax[i] <= value then
			return i
		end
	end
	return defaultIndex
end

function rvb_Utils.getPercentStepLifetimeString(valueIndex)
	local value = rvb_Utils.getPercentStepLifetimeFromIndex(valueIndex)
	return string.format("%.2f", value)
end

function rvb_Utils.getPercentStepLifetimeFromIndex(valueIndex)
	valueIndex = math.max(valueIndex, 1)
	return rvb_Utils.PercentStepArray[valueIndex]
end

function rvb_Utils.getPercentStepLifetimeIndex(value, defaultIndex)
	if value == nil then
		--print("Hiba: value értéke nil!")
		return defaultIndex
	end
	for i = #rvb_Utils.PercentStepArray, 1, -1 do
		if rvb_Utils.PercentStepArray[i] <= tonumber(value) then
			return i
		end
	end
	return defaultIndex
end

rvb_Utils.DailyService = { 2, 4, 6, 8, 10, 12 }
rvb_Utils.PeriodicService = { 40, 60, 80, 100 }
rvb_Utils.WorkshopOpen = { 7, 8, 9, 10 }
rvb_Utils.WorkshopClose = { 16, 17, 18, 19, 20, 21 }
rvb_Utils.WorkshopCountMax = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

--[[rvb_Utils.LargeArray = {}
rvb_Utils.LargeArrayMin = 5
rvb_Utils.LargeArrayMax = 340
for i = rvb_Utils.LargeArrayMin, rvb_Utils.LargeArrayMax do
	if i % 5 == 0 then
		table.insert(rvb_Utils.LargeArray, i)
	end
end]]
rvb_Utils.LargeArray = {
    5, 10, 15, 20, 25, 30, 35, 40, 45, 50,
    55, 60, 65, 70, 75, 80, 85, 90, 95, 100,
    105, 110, 115, 120, 125, 130, 135, 140, 145, 150,
    155, 160, 165, 170, 175, 180, 185, 190, 195, 200,
    205, 210, 215, 220, 225, 230, 235, 240, 245, 250,
    255, 260, 265, 270, 275, 280, 285, 290, 295, 300,
    305, 310, 315, 320, 325, 330, 335, 340
}
rvb_Utils.LargeArrayMin = 5
rvb_Utils.LargeArrayMax = 340

--[[rvb_Utils.SmallArray = {}
rvb_Utils.SmallArrayMin = 1
rvb_Utils.SmallArrayMax = 6
for i = rvb_Utils.SmallArrayMin, rvb_Utils.SmallArrayMax do
	table.insert(rvb_Utils.SmallArray, i)
end]]
rvb_Utils.SmallArray = {1, 2, 3, 4, 5, 6}
rvb_Utils.SmallArrayMin = 1
rvb_Utils.SmallArrayMax = 6


rvb_Utils.PercentStepArray = { 0.01, 0.1, 1, 10 }

function rvb_Utils.to_upper(str)
    local replacements = {
        ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ö"] = "Ö",
        ["ő"] = "Ő", ["ú"] = "Ú", ["ü"] = "Ü", ["ű"] = "Ű"
    }
    -- Először alkalmazzuk a standard upper függvényt
    local upper_str = string.upper(str)
    -- Majd cseréljük ki az ékezetes kisbetűket nagybetűkre
    for lower, upper in pairs(replacements) do
        upper_str = upper_str:gsub(lower, upper)
    end
    return upper_str
end

--[[function rvb_Utils.appendedFunction(oldTarget, oldFunc, newTarget, newFunc)
	local superFunc = oldTarget[oldFunc]
	oldTarget[oldFunc] = function(...)
		superFunc(...)
		newTarget[newFunc](newTarget, ...)
	end
end]]

function rvb_Utils.colorsAreEqual_QQQQQQQQQQQ(color1, color2)
    if #color1 ~= #color2 then return false end
    for i = 1, #color1 do
        if color1[i] ~= color2[i] then return false end
    end
    return true
end
function rvb_Utils.colorsAreEqual(c1, c2)
	if not c1 or not c2 then return false end
	for i = 1, 4 do
		if math.abs(c1[i] - c2[i]) > 0.01 then
			return false
		end
	end
	return true
end
