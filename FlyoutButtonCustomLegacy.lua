--[[
	Author: another
	
	Custom flyout buttons support
]]
	
local ARROW_BUTTON_DEF_HEIGHT, ARROW_BUTTON_MIN_HEIGHT, ARROW_BUTTON_MAX_HEIGHT = 15, 5, 36
local BF_SETTINGS_GROUP = "Button Facade"
local FBC_MINIMAP_ICON = "Interface\\AddOns\\FlyoutButtonCustomLegacy\\media\\FlyoutButtonCustomLegacy"


--variables
local AddonName, AddonTable = ...
FbcButtonFrames = {}
FbcArrowButtons = {}
FbcStandaloneButtons = {}

FbcSettingsMode = nil
FbcKeybindMode = nil
FbcArrowButtonsHeight = nil
FbcShowBorders = nil
FbcEnableMouseover = nil
FbcEnableMouseoverInCombat = nil
FbcHideOnClick = nil
FbcHighlight = nil
FbcStubFrame = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")

local EventHandlersTable = {}
local EnteringWorldOrVariablesLoaded = false
local ActionBarRescanDelay = nil
local ActionBarRescanAttempts = 0
--Button Facade stuff
local LBF
local BF_Table = {}
FbcLBFMasterGroup = nil

local FbcSettingsWindow
local FBC_SETTINGS_CHECKBOX, FBC_SETTINGS_SLIDER = 1, 2


--[[structures
ActionButton
	- customFlyout
	ArrowBtn
		- FlyoutArrow		
		- expandDir: up, left, down, right
		- expanded
	
		- FlyoutListFrame	--also through SetFrameRef
			- ButtonList
]]

local function RegisterFrames()
	FbcButtonFrames = {}
	local frame = EnumerateFrames()
	while frame do
		if frame.IsProtected and frame.GetObjectType and frame.GetScript and frame:GetObjectType() == "CheckButton" and frame:IsProtected() then
			local script = frame:GetScript("OnClick")
			if script == ActionButton1:GetScript("OnClick") or tostring(frame:GetName()):match("^BT4Button%d+$") then
				tinsert(FbcButtonFrames, frame)
			end
		end
		frame = EnumerateFrames(frame)
	end
end

local function AttachToAllActionButtons()
	local attached = {}
	for _, frame in ipairs(FbcButtonFrames) do
		attached[frame:GetName()] = false
	end

	for _, frame in ipairs(FbcButtonFrames) do
		local action = frame.action or frame._state_action
		if action then
			local actionType, actionID = GetActionInfo(action)
			if actionType == "macro" then
				local macroName, _, macroBody = GetMacroInfo(actionID)
				local slots = macroBody and tonumber(macroBody:match("/fbc%s+(%d+)"))
				if macroName and slots and slots > 0 then
					FlyoutArrowButton_Attach(frame, macroName, slots, actionID)
					attached[frame:GetName()] = true
				end
			end
		end
	end

	for name, arrowBtn in pairs(FbcArrowButtons) do
		local parent = arrowBtn:GetParent()
		if parent and not parent.isStandalone and not attached[name] then
			arrowBtn:SetAttribute("expanded", false)
			arrowBtn.FlyoutListFrame:Hide()
			arrowBtn:Hide()
			parent.customFlyout = nil
			FbcArrowButtons[name] = nil
		end
	end
end

local function QueueActionBarRescan()
	ActionBarRescanDelay = 0.1
	ActionBarRescanAttempts = 5
end

local function RescanActionBars()
	if InCombatLockdown() then
		return
	end
	RegisterFrames()
	if ActionButton_Update then
		for _, frame in ipairs(FbcButtonFrames) do
			if type(frame.action) == "number" then
				ActionButton_Update(frame)
			end
		end
	end
	AttachToAllActionButtons()
end

local function AttachStandaloneButtons()
	-- Native action-bar macro slots are the flyout buttons.
end

local function ShowAllFlyoutButtons()
	for _, frame in ipairs(FbcButtonFrames) do
		if frame.action or frame._state_action then
			local arrowBtn = FbcArrowButtons[frame:GetName()]
			if arrowBtn then 
				arrowBtn:ShowArrow()
			end
		end
	end
	for name, root in pairs(FbcStandaloneButtons) do
		local arrowBtn = FbcArrowButtons[name]
		if arrowBtn then
			arrowBtn:ShowArrow()
		end
	end
end

local function HideUnusedFlyoutButtons()
	for _, frame in ipairs(FbcButtonFrames) do
		if frame.action or frame._state_action then
			local arrowBtn = FbcArrowButtons[frame:GetName()]
			if arrowBtn then 
				arrowBtn:UpdateArrow()
				arrowBtn:HideArrow()
			end
		end
	end
	for name, root in pairs(FbcStandaloneButtons) do
		local arrowBtn = FbcArrowButtons[name]
		if arrowBtn then
			arrowBtn:UpdateArrow()
			arrowBtn:HideArrow()
		end
	end
end

local function HideFlyoutFrames()
	if InCombatLockdown() then
		return
	end
	for _, arrowBtn in pairs(FbcArrowButtons) do
		arrowBtn:SetAttribute("expanded", false)
		arrowBtn.FlyoutListFrame:Hide()
	end
end


--[[ Button Facade stuff ]]

function FlyoutButtonCustomLegacy_ButtonFacadeCallback(self, SkinID, Gloss, Backdrop, Group, Button, Colors)
	-- If no group is specified, save the data as the root add-on skin.
	-- This will allow the ButtonFacade GUI to display it correctly.
	if not(Group) then
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP]["SkinID"] = SkinID
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP]["Gloss"] = Gloss
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP]["Backdrop"] = Backdrop
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP]["Colors"] = Colors
	else
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP][Group]["SkinID"] = SkinID
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP][Group]["Gloss"] = Gloss
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP][Group]["Backdrop"] = Backdrop
		FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP][Group]["Colors"] = Colors
	end
end


--[[ events stuff ]]

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("VARIABLES_LOADED")

function EventFrame:LIBKEYBOUND_ENABLED()
	FbcKeybindMode = true
end

function EventFrame:LIBKEYBOUND_DISABLED()
	FbcKeybindMode = nil
end

function EventFrame:LIBKEYBOUND_MODE_COLOR_CHANGED()
	print("color changed")
end


--event handlers
local function DoUpdates(func)
	for _, arrowBtn in pairs(FbcArrowButtons) do
		for i, v in ipairs(arrowBtn.FlyoutListFrame.ButtonList) do
			if v.command then
				func(v)
			end
		end
	end
end

local function EventEnteringCombat(self, ...)
	FbcSettingsMode = false
end

local function EventTalentGroupChanged(self, ...)
	if InCombatLockdown() then
		return
	end
	
	for _, arrowBtn in pairs(FbcArrowButtons) do
		for i, v in ipairs(arrowBtn.FlyoutListFrame.ButtonList) do
			v.command, v.value, v.subValue = nil, nil, nil
		end
	end

	HideFlyoutFrames()
	FbcArrowButtons = {}
	RegisterFrames()
	AttachToAllActionButtons()
	AttachStandaloneButtons()
	
	DoUpdates(FlyoutListButton.SetTooltip)
	DoUpdates(FlyoutListButton.UpdateTexture)
	DoUpdates(FlyoutListButton.UpdateCooldown)
	DoUpdates(FlyoutListButton.UpdateChecked)
	DoUpdates(FlyoutListButton.UpdateEquipped)
	DoUpdates(FlyoutListButton.UpdateUsable)
	DoUpdates(FlyoutListButton.UpdateButtonText)
end

local function EventLearnedSpellInTab(self, ...)
	DoUpdates(FlyoutListButton.SetTooltip)
	DoUpdates(FlyoutListButton.UpdateTexture)
	DoUpdates(FlyoutListButton.UpdateCooldown)
	DoUpdates(FlyoutListButton.UpdateChecked)
	DoUpdates(FlyoutListButton.UpdateUsable)
	DoUpdates(FlyoutListButton.UpdateButtonText)
end

local function RegisterEvents()
	--event table
	EventHandlersTable = {
		--common
		["PLAYER_REGEN_DISABLED"] 			= EventEnteringCombat,
		["ACTIVE_TALENT_GROUP_CHANGED"] 	= EventTalentGroupChanged,
		["LEARNED_SPELL_IN_TAB"] 			= EventLearnedSpellInTab,
		["ACTIONBAR_SLOT_CHANGED"]			= function()
				QueueActionBarRescan()
			end,
		["UPDATE_MACROS"]					= function()
				QueueActionBarRescan()
			end,
		["PLAYER_REGEN_ENABLED"]			= function()
			RescanActionBars()
		end,
	}
	
	EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	EventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
	EventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	EventFrame:RegisterEvent("UPDATE_MACROS")
	EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end


--[[ slash handlers ]]

local function SlashTable_border(rest)
	if InCombatLockdown() then
		print("can't change borders while in combat")
		return
	end
	FbcShowBorders = not(FbcShowBorders)
	FlyoutButtonCustomLegacy_Settings["ShowBorders"] = FbcShowBorders
	print("ShowBorders = "..tostring(FbcShowBorders))

	for _, arrowBtn in pairs(FbcArrowButtons) do
		local flf = arrowBtn.FlyoutListFrame
		for i, v in ipairs(arrowBtn.FlyoutListFrame.ButtonList) do
			if v.command then
				v:UpdateTexture()
			end
		end
	end
end

local function SlashTable_hide(rest)
	if InCombatLockdown() then
		print("can't change hide-on-click while in combat")
		return
	end
	FbcHideOnClick = not(FbcHideOnClick)
	FlyoutButtonCustomLegacy_Settings["HideOnClick"] = FbcHideOnClick
	print("HideOnClick = "..tostring(FbcHideOnClick))

	for _, arrowBtn in pairs(FbcArrowButtons) do
		for _, v in ipairs(arrowBtn.FlyoutListFrame.ButtonList) do
			v:SetHideOnClick(FbcHideOnClick)
		end
	end
end

local function SlashTable_highlight(rest)
	if InCombatLockdown() then
		print("can't change highlight while in combat")
		return
	end
	FbcHighlight = not(FbcHighlight)
	FlyoutButtonCustomLegacy_Settings["Highlight"] = FbcHighlight
	print("Highlight = "..tostring(FbcHighlight))

	for _, arrowBtn in pairs(FbcArrowButtons) do
		arrowBtn:SetHighlight(FbcHighlight)
	end
end

local function SlashTable_height(rest)
	if InCombatLockdown() then
		print("can't change arrow height while in combat")
		return
	end
	if rest ~= "" then
		local temp = tonumber(rest)
		if not(temp) or (temp < ARROW_BUTTON_MIN_HEIGHT) or (temp > ARROW_BUTTON_MAX_HEIGHT) then
			print("new height value '"..rest.."' out of range "..ARROW_BUTTON_MIN_HEIGHT.."-"..ARROW_BUTTON_MAX_HEIGHT)
		else
			FbcArrowButtonsHeight = temp
			FlyoutButtonCustomLegacy_Settings["ArrowButtonsHeight"] = FbcArrowButtonsHeight
			
			for _, arrowBtn in pairs(FbcArrowButtons) do
				arrowBtn:SetFrameSize(arrowBtn:GetAttribute("expandDir"))
			end
		end
	end
end

local function SlashTable_keybind(rest)
	FbcLibKeyBound:Toggle()
end

local function SlashTable_mouseover(rest)
	if InCombatLockdown() then
		print("can't toggle mouseover while in combat")
		return
	end
	
	FbcEnableMouseover = not(FbcEnableMouseover)
	FlyoutButtonCustomLegacy_Settings["EnableMouseover"] = FbcEnableMouseover
	print("EnableMouseover = "..tostring(FbcEnableMouseover))
	for _, arrowBtn in pairs(FbcArrowButtons) do
		arrowBtn:SetAttribute("mouseover-enabled", FbcEnableMouseover)
		if FbcEnableMouseover then
			arrowBtn:SetAttribute("_onenter", ArrowButtonOnEnterSnippet)
		else
			arrowBtn:SetAttribute("_onenter", "")
		end
		arrowBtn:SetAttribute("_onleave", "")
	end
end

local function SlashTable_mouseoverincombat(rest)
	if InCombatLockdown() then
		print("can't toggle mouseoverincombat while in combat")
		return
	end
	
	FbcEnableMouseoverInCombat = not(FbcEnableMouseoverInCombat)
	FlyoutButtonCustomLegacy_Settings["EnableMouseoverInCombat"] = FbcEnableMouseoverInCombat
	print("EnableMouseoverInCombat = "..tostring(FbcEnableMouseoverInCombat))
	for _, arrowBtn in pairs(FbcArrowButtons) do
		arrowBtn:SetAttribute("mouseoverincombat", FbcEnableMouseoverInCombat)
	end
end

local function toboolean(v)
	return not not v
end

local function SlashTable_settings(rest)
	if InCombatLockdown() then
		print("can't enter SettingsMode while in combat")
		return
	end
	
	FbcSettingsMode = not(FbcSettingsMode)
	print("SettingsMode = "..tostring(FbcSettingsMode))
	if FbcSettingsMode then
		EventTalentGroupChanged()
		ShowAllFlyoutButtons()
	else
		HideUnusedFlyoutButtons()
	end
end

local function SlashTable_new(rest)
	print("Create a uniquely named macro containing /fbc <number of slots>, then drag it to a Blizzard action bar. Example: /fbc 4")
end

local function SlashTable_unique(rest)
	if InCombatLockdown() then
		print("can't set unique while in combat")
		return
	end
	
	FbcStubFrame:SetAttribute("unique-list", not(FbcStubFrame:GetAttribute("unique-list")))
	FlyoutButtonCustomLegacy_Settings["UniqueList"] = FbcStubFrame:GetAttribute("unique-list")
	print("unique list = "..tostring(FbcStubFrame:GetAttribute("unique-list")))
end

local FlyoutButtonCustomLegacy_SlashTable = {
	{
		['name'] = 'new',
		['hint'] = "create another standalone flyout",
		['func'] = SlashTable_new,
		['get'] = function() return nil; end,
		['type'] = nil
	},
	{
		['name'] = 'border',
		['label'] = 'Border',
		['hint'] = "Show a border around flyout buttons.",
		['func'] = SlashTable_border,
		['get'] = function() return FbcShowBorders; end,
		['type'] = FBC_SETTINGS_CHECKBOX
	},
	{
		['name'] = 'hide',
		['label'] = 'Hide',
		['hint'] = "Close the flyout after selecting an item.",
		['func'] = SlashTable_hide,
		['get'] = function() return FbcHideOnClick; end,
		['type'] = FBC_SETTINGS_CHECKBOX
	},
	{
		['name'] = 'mouseover',
		['label'] = 'Mouseover',
		['hint'] = "Open the flyout when the cursor enters the button.",
		['func'] = SlashTable_mouseover,
		['get'] = function() return FbcEnableMouseover; end,
		['type'] = FBC_SETTINGS_CHECKBOX
	},
	{
		['name'] = 'mouseoverincombat',
		['label'] = 'Mouseover in combat',
		['hint'] = "Allow mouseover opening while in combat.",
		['func'] = SlashTable_mouseoverincombat,
		['get'] = function() return FbcEnableMouseoverInCombat; end,
		['type'] = FBC_SETTINGS_CHECKBOX
	},
}

local function FlyoutButtonCustomLegacy_SlashHandler(msg, editbox)
	local command, rest = msg:match("^(%S*)%s*(.-)$")
	-- Any leading non-whitespace is captured into command
	-- the rest (minus leading whitespace) is captured into rest.
	command = string.lower(command)
	
	if command == "" then
		FbcSettingsWindow:Show()
	elseif command == "help" then
		print("FlyoutButton Custom slash commands:\n/fbc or /fbcustom, params:")
		for _, v in ipairs(FlyoutButtonCustomLegacy_SlashTable) do
			print(v.name.." : "..v.hint)
		end
	else
		if tonumber(command) then
			return
		end
		local found = false
		for _, v in ipairs(FlyoutButtonCustomLegacy_SlashTable) do
			if v.name == command then
				found = true
				v.func(rest)
				break
			end
		end
		
		if not(found) then
			print("unknown command '"..command.."'")
		end
	end
end

local spb_frame = SpellBookFrame
spb_frame:HookScript("OnShow", function()
	if not(InCombatLockdown()) then
		FbcSettingsMode = true
		EventTalentGroupChanged()
		ShowAllFlyoutButtons()
	end
end)
spb_frame:HookScript("OnHide", function()
	FbcSettingsMode = false
	if not(InCombatLockdown()) then
		HideUnusedFlyoutButtons()
	end
end)

local function GetKeyValue(key, ...)
	if FlyoutButtonCustomLegacy_Settings[key] ~= nil then
		return FlyoutButtonCustomLegacy_Settings[key]
	else
		return ...
	end
end

local function CreateSettingsMinimapButton()
	local button = CreateFrame("Button", "FBCMinimapButton", Minimap)
	local radius = 80
	button:SetWidth(31)
	button:SetHeight(31)
	button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	button:SetFrameStrata("MEDIUM")
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", button, "CENTER")
	icon:SetTexture(FBC_MINIMAP_ICON)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	button.icon = icon
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetWidth(54)
	border:SetHeight(54)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button.border = border
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	button:SetClampedToScreen(true)
	button:RegisterForDrag("LeftButton")
	button.angle = FlyoutButtonCustomLegacy_Settings["MinimapButtonAngle"] or math.rad(225)
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(button.angle) * radius, math.sin(button.angle) * radius)
	button:SetScript("OnDragStart", function(self)
		self.dragging = true
	end)
	button:SetScript("OnDragStop", function(self)
		self.dragging = nil
		FlyoutButtonCustomLegacy_Settings["MinimapButtonAngle"] = self.angle
	end)
	button:SetScript("OnUpdate", function(self)
		if not self.dragging then
			return
		end
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		local minimapX, minimapY = Minimap:GetCenter()
		if not cursorX or not cursorY or not minimapX or not minimapY then
			return
		end
		cursorX = cursorX / scale
		cursorY = cursorY / scale
		self.angle = math.atan2(cursorY - minimapY, cursorX - minimapX)
		self:ClearAllPoints()
		self:SetPoint("CENTER", Minimap, "CENTER", math.cos(self.angle) * radius, math.sin(self.angle) * radius)
	end)
	button:SetScript("OnClick", function()
		if FbcSettingsWindow:IsShown() then
			FbcSettingsWindow:Hide()
		else
			FbcSettingsWindow:Show()
		end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("FlyoutButton Custom")
		GameTooltip:AddLine("Open settings", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Show()
end

local function Init()
	FlyoutButtonCustomLegacy_Settings = FlyoutButtonCustomLegacy_Settings or {}
	local fbc_s = FlyoutButtonCustomLegacy_Settings
	
	--read settings
	FbcArrowButtonsHeight 		= GetKeyValue("ArrowButtonsHeight", ARROW_BUTTON_DEF_HEIGHT)
	FbcShowBorders 				= GetKeyValue("ShowBorders", true)
	FbcEnableMouseover			= GetKeyValue("EnableMouseover", false)
	FbcEnableMouseoverInCombat 	= GetKeyValue("EnableMouseoverInCombat", true)
	FbcHideOnClick 				= GetKeyValue("HideOnClick", true)
	FbcHighlight 				= GetKeyValue("Highlight", true)
	fbc_s["UniqueList"] = true
	FbcStubFrame:SetAttribute("unique-list", fbc_s["UniqueList"])
	FlyoutButtonCustomLegacy_Settings["positions"] = FlyoutButtonCustomLegacy_Settings["positions"] or {}
	FlyoutButtonCustomLegacy_Settings["expandDir"] = FlyoutButtonCustomLegacy_Settings["expandDir"] or {}
	--for 2 talent sets
	FlyoutButtonCustomLegacy_Settings["expandDir"][1] = FlyoutButtonCustomLegacy_Settings["expandDir"][1] or {}
	FlyoutButtonCustomLegacy_Settings["expandDir"][2] = FlyoutButtonCustomLegacy_Settings["expandDir"][2] or {}
	
	--Button Facade
	if (LibStub) then
		LBF = LibStub("LibButtonFacade", true)
		if (LBF) then
			FbcLBFMasterGroup = LBF:Group("FlyoutButtonCustomLegacy")
			LBF:RegisterSkinCallback("FlyoutButtonCustomLegacy", FlyoutButtonCustomLegacy_ButtonFacadeCallback, BF_Table)
		end
	end
	FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP] = FlyoutButtonCustomLegacy_Settings[BF_SETTINGS_GROUP] or {}
	if (FbcLBFMasterGroup and fbc_s[BF_SETTINGS_GROUP]["SkinID"]) then
		FbcLBFMasterGroup:Skin(fbc_s[BF_SETTINGS_GROUP]["SkinID"], fbc_s[BF_SETTINGS_GROUP]["Gloss"], fbc_s[BF_SETTINGS_GROUP]["Backdrop"], fbc_s[BF_SETTINGS_GROUP]["Colors"])
	end			
	
	RegisterFrames()
	AttachToAllActionButtons()
	RegisterEvents()
	
	--LibKeyBound
	if (LibStub) then
		FbcLibKeyBound = LibStub("LibKeyBound-1.0")
		if (FbcLibKeyBound) then
			FbcLibKeyBound.RegisterCallback(EventFrame, "LIBKEYBOUND_ENABLED")
			FbcLibKeyBound.RegisterCallback(EventFrame, "LIBKEYBOUND_DISABLED")
			FbcLibKeyBound.RegisterCallback(EventFrame, "LIBKEYBOUND_MODE_COLOR_CHANGED")
		end
	end

	SLASH_FBCUSTOM1, SLASH_FBCUSTOM2 = "/fbc", "/fbcustom"
	SlashCmdList["FBCUSTOM"] = FlyoutButtonCustomLegacy_SlashHandler
	
	--SettingsWindow
	FbcSettingsWindow = CreateFrame("Frame", "FBCSettingsDialog", UIParent, "FBCSettingsDialogTemplate")
	local optionIndex = 0
	for i, v in ipairs(FlyoutButtonCustomLegacy_SlashTable) do
		local name = "FlyoutButtonCustomLegacy_SettingsButton_"..i
		if v.type == FBC_SETTINGS_CHECKBOX then
			optionIndex = optionIndex + 1
			v.widget = CreateFrame("CheckButton", name, FbcSettingsWindow, "FBCSettingsButtonTemplate")
			local btn = v.widget
			_G[name.."Text"]:SetText(v.label or v.name)
			_G[name.."Description"]:SetText(v.hint)
			_G[name.."Text"]:SetTextColor(1, 0.82, 0)
			btn.func = v.func
			btn.get = v.get
			btn.type = v.type
			btn:SetPoint("TOPLEFT", FbcSettingsWindow, "TOPLEFT", 25, 0 - optionIndex * 55)
		elseif v.type == FBC_SETTINGS_SLIDER then
			v.widget = CreateFrame("Slider", name, FbcSettingsWindow, "OptionsSliderTemplate")
			local slider = v.widget

			local subText = slider:CreateFontString(name.."Value", "ARTWORK", "GameFontHighlight")
			subText:SetPoint("CENTER", slider, "CENTER", 0, -12)
			
			_G[name.."Text"]:SetText(v.name)
			_G[name.."Low"]:SetText(ARROW_BUTTON_MIN_HEIGHT)
			_G[name.."High"]:SetText(ARROW_BUTTON_MAX_HEIGHT)
			slider.valueText = _G[name.."Value"]
			slider:SetValueStep(1)
			slider:SetMinMaxValues(ARROW_BUTTON_MIN_HEIGHT, ARROW_BUTTON_MAX_HEIGHT)
			slider.tooltipText = v.hint
			slider.func = v.func
			slider.get = v.get
			slider.type = v.type
			slider:SetPoint("TOPLEFT", FbcSettingsWindow, "TOPLEFT", 80, -300)
			slider:SetScript("OnValueChanged", function(self)
				self.valueText:SetText(self:GetValue())
				FBCSettingsDialogTemplate_UpdateSaveState(self:GetParent())
			end)
		end
	end	
	CreateSettingsMinimapButton()
end

function FBCSettingsDialogTemplate_OnShow(self)
	if not FbcSettingsMode then
		FbcSettingsMode = true
		EventTalentGroupChanged()
		ShowAllFlyoutButtons()
	end
	local buttons = { self:GetChildren() }
	for i, b in ipairs(buttons) do
		if b.get then
			b.old = b.get()
			if b.type == FBC_SETTINGS_CHECKBOX then
				b:SetChecked(b.get())
			elseif b.type == FBC_SETTINGS_SLIDER then
				b:SetValue(b.get())
				b.valueText:SetText(b.get())
			end
		end
	end
	FBCSettingsDialogTemplate_UpdateSaveState(self)
end

function FBCSettingsDialogTemplate_UpdateSaveState(self)
	local dirty = false
	local buttons = { self:GetChildren() }
	for i, b in ipairs(buttons) do
		if b.func then
			if b.type == FBC_SETTINGS_CHECKBOX then
				dirty = dirty or toboolean(b.old) ~= toboolean(b:GetChecked())
			elseif b.type == FBC_SETTINGS_SLIDER then
				dirty = dirty or b.old ~= b:GetValue()
			end
		end
	end
	local saveButton = _G[self:GetName().."Save"]
	if saveButton then
		if dirty then
			saveButton:Enable()
		else
			saveButton:Disable()
		end
	end
end

function FBCSettingsDialogTemplate_OnHide(self)
	if FbcSettingsMode then
		FbcSettingsMode = false
		HideUnusedFlyoutButtons()
	end
end

function FBCSettingsDialogTemplate_Apply(self)
	local buttons = { self:GetChildren() }
	for i, b in ipairs(buttons) do
		if b.func then
			if b.type == FBC_SETTINGS_CHECKBOX then
				if toboolean(b.old) ~= toboolean(b:GetChecked()) then
					b.func()
				end
				b.old = b:GetChecked()
			elseif b.type == FBC_SETTINGS_SLIDER then
				local value = b:GetValue()
				if b.old ~= value then
					b.func(value)
				end
				b.old = value
			end
		end
	end
	FBCSettingsDialogTemplate_UpdateSaveState(self)
end

local function OnEvent(self, event, ...)
	if EventHandlersTable[event] then
		EventHandlersTable[event](self, ...)
	elseif event == "PLAYER_ENTERING_WORLD" or event == "VARIABLES_LOADED" then
		if EnteringWorldOrVariablesLoaded then
			Init()
		else
			EnteringWorldOrVariablesLoaded = true
		end
		if event == "PLAYER_ENTERING_WORLD" then EventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
		if event == "VARIABLES_LOADED" then EventFrame:UnregisterEvent("VARIABLES_LOADED") end
	end
end

EventFrame:SetScript("OnEvent", OnEvent)
EventFrame:SetScript("OnUpdate", function(self, elapsed)
	if ActionBarRescanDelay then
		ActionBarRescanDelay = ActionBarRescanDelay - elapsed
		if ActionBarRescanDelay <= 0 then
			ActionBarRescanAttempts = ActionBarRescanAttempts - 1
			RescanActionBars()
			if ActionBarRescanAttempts > 0 then
				ActionBarRescanDelay = 0.1
			else
				ActionBarRescanDelay = nil
			end
		end
	end
end)
