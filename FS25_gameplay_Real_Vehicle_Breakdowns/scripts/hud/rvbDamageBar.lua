
Wearable.getDamageShowOnHud = Utils.overwrittenFunction(
	Wearable.getDamageShowOnHud,
	function(self, superFunc)
		local show = superFunc(self)
		if not show then
			return false
		end
		if self.getIsSelected ~= nil then
			return self:getIsSelected()
		else
			return false
		end
	end
)
