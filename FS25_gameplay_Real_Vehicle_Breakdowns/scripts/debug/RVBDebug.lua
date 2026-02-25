
RVBDebug = {}
RVBDebug_mt = {__index = RVBDebug}

function RVBDebug.new(generalSettings)
	local self = setmetatable({}, RVBDebug_mt)
	self.generalSettings = generalSettings
	self.generalSettings.showdebugisplay = self.generalSettings.showdebugisplay or false
	return self
end
function RVBDebug:log(level, funcName, fmt, ...)
	local msg = string.format(fmt, ...)
	funcName = funcName or "unknownFunc"
	msg = string.format("[%s] %s", funcName, msg)
	if level == "ERROR" then
		Logging.error("[RVB] " .. msg)
	elseif level == "WARNING" then
		Logging.warning("[RVB] " .. msg)
	else
		if self.generalSettings.showdebugisplay then
			Logging.info("[RVB] " .. msg)
		end
	end
end
function RVBDebug:info(funcName, fmt, ...) self:log("INFO", funcName, fmt, ...) end
function RVBDebug:warning(funcName, fmt, ...) self:log("WARNING", funcName, fmt, ...) end
function RVBDebug:error(funcName, fmt, ...) self:log("ERROR", funcName, fmt, ...) end

--[[
debugger = RVBDebug.new(generalSettings)

debugger:info("Settings 'workshopOpen': %d", workshopOpen)
debugger:warning("This might be wrong: %s", someValue)
debugger:error("Failed to set value: %s", errorMsg)
]]
