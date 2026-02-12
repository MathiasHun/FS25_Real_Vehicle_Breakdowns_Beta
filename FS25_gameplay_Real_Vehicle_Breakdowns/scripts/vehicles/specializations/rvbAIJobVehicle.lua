rvbAIJobVehicle = {}

function rvbAIJobVehicle.StopAI(self)
    local rootVehicle = self.rootVehicle
    if rootVehicle ~= nil and rootVehicle:getIsAIActive() then
        rootVehicle:stopCurrentAIJob(AIMessageErrorVehicleBroken.new())
    end
end
