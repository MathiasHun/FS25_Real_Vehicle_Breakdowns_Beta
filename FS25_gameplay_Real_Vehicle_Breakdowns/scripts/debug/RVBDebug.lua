
RVBDebug = {}
RVBDebug_mt = {__index = RVBDebug}

function RVBDebug.new(generalSettings)
    local self = setmetatable({}, RVBDebug_mt)
    self.generalSettings = generalSettings
    self.generalSettings.showdebugisplay = self.generalSettings.showdebugisplay or false
    return self
end
function RVBDebug:log(level, fmt, ...)
    if self.generalSettings.showdebugisplay then
        local msg = string.format(fmt, ...)
        if level == "ERROR" then
            Logging.error("[RVB] " .. msg)
        elseif level == "WARNING" then
            Logging.warning("[RVB] " .. msg)
        else
            Logging.info("[RVB] " .. msg)
        end
    end
end
function RVBDebug:info(fmt, ...) self:log("INFO", fmt, ...) end
function RVBDebug:warning(fmt, ...) self:log("WARNING", fmt, ...) end
function RVBDebug:error(fmt, ...) self:log("ERROR", fmt, ...) end

--[[
debugger = RVBDebug.new(generalSettings)

debugger:info("Settings 'workshopOpen': %d", workshopOpen)
debugger:warning("This might be wrong: %s", someValue)
debugger:error("Failed to set value: %s", errorMsg)
]]