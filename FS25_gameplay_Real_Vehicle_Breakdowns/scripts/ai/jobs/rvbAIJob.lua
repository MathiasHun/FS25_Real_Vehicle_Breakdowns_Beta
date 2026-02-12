
rvbAIJob = {}

function rvbAIJob.stopTask(self, task, wasJobStopped)
    if self.deactivateLights ~= nil then
        self:deactivateLights()
    end
end
AIJob.stopTask = Utils.appendedFunction(AIJob.stopTask, rvbAIJob.stopTask)