RVBInfoDialog = {}
local RVBInfoDialog_mt = Class(RVBInfoDialog, MessageDialog)
function RVBInfoDialog.register()
	local rvbInfoDialog = RVBInfoDialog.new()
	g_gui:loadGui(g_vehicleBreakdownsDirectory .. "gui/dialogs/RVBInfoDialog.xml", "RVBInfoDialog", rvbInfoDialog)
	RVBInfoDialog.INSTANCE = rvbInfoDialog
end
function RVBInfoDialog.show(p3, p4, p5, p6, p7, p8, p9, p10)
	if RVBInfoDialog.INSTANCE ~= nil then
		local dialog = RVBInfoDialog.INSTANCE
		dialog:setCallback(p4, p5, p9)
		dialog:setDialogType(Utils.getNoNil(p6, DialogElement.TYPE_INFO))
		dialog:setButtonTexts(p7)
		dialog:setButtonAction(p8)
		dialog:setText(p3)
		dialog:setDisableOpenSound(p10)
		g_gui:showDialog("RVBInfoDialog")
	end
end
function RVBInfoDialog.cancel()
	local v12 = RVBInfoDialog.INSTANCE
	if v12.isOpen then
		v12:onClickBack()
	end
end
function RVBInfoDialog.new(p13, p14)
	local self = MessageDialog.new(p13, p14 or RVBInfoDialog_mt)
	self.buttonAction = InputAction.MENU_ACCEPT
	self.isBackAllowed = false
	self.inputDelay = 250
	return self
end
function RVBInfoDialog.createFromExistingGui(p16, _)
	RVBInfoDialog.register()
	local v17 = p16.dialogType
	local v18 = p16.infoText
	local v19 = p16.callbackFunc
	local v20 = p16.target
	local v21 = p16.okButton.text
	if p16.okButton.textSeparator ~= nil and v21 ~= nil then
		v21 = string.gsub(v21, p16.okButton.textSeparator, "", 1)
	end
	local v22 = p16.buttonAction
	local v23 = p16.args
	RVBInfoDialog.show(v18, v19, v20, v17, v21, v22, v23)
end
function RVBInfoDialog.onCreate(p24)
	RVBInfoDialog:superClass().onCreate(p24)
	p24:setDialogType(DialogElement.TYPE_INFO)
	p24.defaultOkText = p24.okButton.text
	if p24.okButton.textSeparator ~= nil then
		p24.defaultOkText = string.gsub(p24.defaultOkText, p24.okButton.textSeparator, "", 1)
	end
end
function RVBInfoDialog.onOpen(p25)
	RVBInfoDialog:superClass().onOpen(p25)
	p25.inputDelay = p25.time + 250
end
function RVBInfoDialog.onClose(p26)
	RVBInfoDialog:superClass().onClose(p26)
	p26:setButtonTexts(p26.defaultOkText)
	p26.buttonAction = InputAction.MENU_ACCEPT
	p26:setButtonAction(InputAction.MENU_ACCEPT)
	p26:setText("")
end
function RVBInfoDialog.setText(p27, p28)
	RVBInfoDialog:superClass().setText(p27, p28)
	p27.infoText = p28
end
function RVBInfoDialog.acceptDialog(p29, p30, p31)
	if p29.inputDelay > p29.time then
		return true
	end
	if p30 ~= p29.buttonAction and not p31 then
		return true
	end
	p29:close()
	if p29.onOk ~= nil then
		if p29.target == nil then
			p29.onOk(p29.args)
		else
			p29.onOk(p29.target, p29.args)
		end
		p29.onOk = nil
		p29.target = nil
		p29.args = nil
	end
	return false
end
function RVBInfoDialog.onClickBack(p32, _, p33)
	if p33 then
		return nil
	else
		return p32:acceptDialog(InputAction.MENU_BACK, true)
	end
end
function RVBInfoDialog.onClickOk(p34)
	return p34:acceptDialog(p34.buttonAction, false)
end
function RVBInfoDialog.setCallback(p35, p36, p37, p38)
	p35.onOk = p36
	p35.target = p37
	p35.args = p38
end
function RVBInfoDialog.setButtonTexts(p39, p40)
	if p39.okButton ~= nil then
		p39.okButton:setText(Utils.getNoNil(p40, p39.defaultOkText))
	end
end
function RVBInfoDialog.setButtonAction(p41, p42)
	if p42 ~= nil then
		p41.buttonAction = p42
		p41.okButton:setInputAction(p42)
	end
end
function RVBInfoDialog.inputEvent(p43, p44, p45, p46)
	local v47 = RVBInfoDialog:superClass().inputEvent(p43, p44, p45, p46)
	if Platform.isAndroid and (p43.inputDisableTime <= 0 and p44 == InputAction.MENU_BACK) then
		p43:onClickOk()
		v47 = true
	end
	return v47
end