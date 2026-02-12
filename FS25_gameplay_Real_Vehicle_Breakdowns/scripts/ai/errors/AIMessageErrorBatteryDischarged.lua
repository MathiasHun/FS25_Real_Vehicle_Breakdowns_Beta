
AIMessageErrorBatteryDischarged = {}

local AIMessageErrorBatteryDischarged_mt = Class(AIMessageErrorBatteryDischarged, AIMessage)

InitEventClass(AIMessageErrorBatteryDischarged, "AIMessageErrorBatteryDischarged")

function AIMessageErrorBatteryDischarged.new(customMt)
    local self = AIMessage.new(customMt or AIMessageErrorBatteryDischarged_mt)
    return self
end

function AIMessageErrorBatteryDischarged:getMessage()
    return g_i18n:getText("RVB_aimessage_batterydischarged", g_vehicleBreakdownsModName)
end