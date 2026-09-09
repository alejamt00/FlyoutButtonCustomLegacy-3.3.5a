--[[ FlyoutListButton ]]

local StoredCursor = {}
local ParentAlpha
FlyoutListButton = {}


local FlyoutListButtonOnClickWrapScript = [=[
	local listFrame = self:GetParent()
	if listFrame then
		local arrowBtn = listFrame:GetParent()
		if arrowBtn then
			arrowBtn:SetAttribute("expanded", false)
			listFrame:Hide()
		end
	end
]=]

function FlyoutListButton_New(parent, idx)
	parent.ButtonList[idx] = CreateFrame("CheckButton", parent:GetName().."ListButton"..idx, parent, "CustomFlyoutListButtonTemplate")
	btn = parent.ButtonList[idx]
	btn.index = idx
	btn.icon = _G[btn:GetName().."Icon"]
	btn.cooldown = _G[btn:GetName().."Cooldown"]
	btn.border = _G[btn:GetName().."Border"]
	btn.count = _G[btn:GetName().."Count"]
	btn.name = _G[btn:GetName().."Name"]
	btn.hotkey = _G[btn:GetName().."HotKey"]
	btn.ntexture = _G[btn:GetName().."NormalTexture"]
	local arrowBtn = parent:GetParent()
	btn.actnBtnName = arrowBtn.flyoutName or arrowBtn:GetParent():GetName()
	
	-- adding methods to button
	for k, v in pairs(FlyoutListButton) do
		if type(v) == "function" then
			btn[k] = v
		end
	end
	
	btn:SetMovable(true)
	btn:RegisterForDrag("LeftButton")
	btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot")
	btn:SetAttribute("checkselfcast", true)
	btn:SetAttribute("checkfocuscast", true)
	btn:SetAttribute("unit2", "player") --right-click self cast
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetHideOnClick(FbcHideOnClick)

	return btn
end

function FlyoutListButton_AttachToList(parent, idx, expandDir)
	local btn = parent.ButtonList[idx]
	if not(btn) then
		btn = FlyoutListButton_New(parent, idx)
		if (FbcLBFMasterGroup) then
			FbcLBFMasterGroup:AddButton(btn)
		end
	end
	btn:SetAnchor(parent, idx, expandDir)

	return btn
end

function FlyoutListButton:SetHideOnClick(value)
	if InCombatLockdown() then
		return
	end
	if value then
		self:WrapScript(self, "OnClick", FlyoutListButtonOnClickWrapScript)
	else
		self:UnwrapScript(self, "OnClick")
	end
end

function FlyoutListButton:SetAnchor(parent, idx, expandDir)
	self:ClearAllPoints()
	if expandDir == FBC_DIR_UP then
		self:SetPoint("BOTTOM", parent, "BOTTOM", 0, idx * FBC_BUTTON_PLACE_OFFSET + (idx - 1) * FBC_BUTTON_PLACE_SIZE)
	elseif expandDir == FBC_DIR_LEFT then
		self:SetPoint("RIGHT", parent, "RIGHT", - (idx * FBC_BUTTON_PLACE_OFFSET + (idx - 1) * FBC_BUTTON_PLACE_SIZE), 0)
	elseif expandDir == FBC_DIR_DOWN then
		self:SetPoint("TOP", parent, "TOP", 0, - (idx * FBC_BUTTON_PLACE_OFFSET + (idx - 1) * FBC_BUTTON_PLACE_SIZE))
	else
		self:SetPoint("LEFT", parent, "LEFT", idx * FBC_BUTTON_PLACE_OFFSET + (idx - 1) * FBC_BUTTON_PLACE_SIZE, 0)
	end
end

function FlyoutListButton:GetHotkey()
	local key = GetBindingKey("CLICK "..self:GetName()..":LeftButton")
	local displayKey = FbcLibKeyBound:ToShortKey(key)
	return displayKey
end

function FlyoutListButton:SetKey(key) -- binds the given key to the given button
	local binding = "CLICK "..self:GetName()..":LeftButton"
	if (key ~= "" and key ~= nil) then
		SetBinding(key, binding)
		self.hotkey:SetText(GetBindingText(key, "KEY_", 1))
		if not self.hotkey.__LBF_SetPoint then
			self.hotkey:ClearAllPoints()
			self.hotkey:SetPoint("TOPLEFT", self, "TOPLEFT", -2, -2)
		end
		self.hotkey:SetVertexColor(0.6, 0.6, 0.6)
		self.hotkey:Show()
	else
		self.hotkey:SetText(RANGE_INDICATOR)
		if not self.hotkey.__LBF_SetPoint then
			self.hotkey:ClearAllPoints()
			self.hotkey:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -2)
		end
		self.hotkey:Hide()
	end
	self.keybind = key

	local fbcs = FlyoutButtonCustomLegacy_Settings
	local currentSet = GetActiveTalentGroup()
	local actnBtnName = self.actnBtnName
	if fbcs[actnBtnName] and fbcs[actnBtnName][currentSet] and fbcs[actnBtnName][currentSet][self.index] then
		fbcs[actnBtnName][currentSet][self.index]["keybind"] = key
	end
end

function FlyoutListButton:ClearBindings() -- removes all keys bound to the given button
	local binding = "CLICK "..self:GetName()..":LeftButton"
	while GetBindingKey(binding) do
		SetBinding(GetBindingKey(binding), nil)
		self:SetKey(nil)
	end
end

function FlyoutListButton:FreeKey(key) -- unbinds the given key from all other buttons
	for _, arrowBtn in pairs(FbcArrowButtons) do
		for i, v in ipairs(arrowBtn.FlyoutListFrame.ButtonList) do
			if v.keybind == key then
				v:SetKey(nil)
			end
		end
	end
end

function FlyoutListButton:OnEnter()
	if (self.GetHotkey) then
		FbcLibKeyBound:Set(self)
	end
	
	if (GetCVar("UberTooltips") == "1") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
	else
		local lf = self:GetParent() --list->arrowBtn->actBtn->Bar
		local arrBtn = lf:GetParent() --arrowBtn->actBtn->Bar
		local actBtn = arrBtn:GetParent() --actBtn->Bar
		local bar = actBtn:GetParent()
		if (bar == MultiBarBottomRight or bar == MultiBarRight or bar == MultiBarLeft) then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
	end
	
	if self.tooltipType and self.tooltipValue then
		if self.tooltipType == "hyperlink" then
			GameTooltip:SetHyperlink(self.tooltipValue)
		elseif self.tooltipType == "spell" then
			-- Wrath calls this method SetSpell; it was renamed to
			-- SetSpellBookItem in 4.0.1.
			local spellSlot = FlyoutButton_FindSpellSlot(self.tooltipValue)
			if spellSlot then
				GameTooltip:SetSpell(spellSlot, BOOKTYPE_SPELL)
			end
		elseif self.tooltipType == "item" then
			local _, hyperLink = GetItemInfo(self.tooltipValue)
			if (hyperLink) then
				GameTooltip:SetHyperlink(hyperLink)
			end
		elseif self.tooltipType == "macro" then
			GameTooltip:SetText(self.tooltipValue, 1.0, 1.0, 1.0)
		end
	end	

	-- anti fading stuff
	local arrBtn = self:GetParent():GetParent()
	if arrBtn then
		local actBtn = arrBtn:GetParent()
		if actBtn then
			local parent = actBtn
			while true do
				local bar = parent:GetParent()
				if not(bar) or bar == UIParent then
					break
				elseif bar:GetAlpha() ~= 1 then
					ParentAlpha = {}
					ParentAlpha.bar = bar
					ParentAlpha.alpha = bar:GetAlpha()
					bar:SetAlpha(1)
					break
				end
				parent = bar
			end
		end
	end
end

function FlyoutListButton:OnLeave()
	GameTooltip:Hide()
	
	-- anti fading stuff
	if ParentAlpha and ParentAlpha.bar then
		ParentAlpha.bar:SetAlpha(ParentAlpha.alpha)
		ParentAlpha = nil
	end
end

function FlyoutListButton:SetTooltip()
	self.tooltipValue = nil
	self.tooltipType = nil
	
	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			_, _, creatureSpellID = FlyoutButton_GetCompanionInfoCustom(subValue, value)
			self.tooltipType = "hyperlink"
			self.tooltipValue = "spell:"..creatureSpellID
		else
			self.tooltipType = command
			self.tooltipValue = value
		end
	elseif (command == "item") then
		self.tooltipType = command
		self.tooltipValue = value
	elseif (command == "macro") then
		self.tooltipType = command
		self.tooltipValue = value
	end
end

function FlyoutListButton:UpdateTexture()
	local icon = self.icon
	local texture = nil
	
	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			_, _, _, _, texture = FlyoutButton_GetCompanionInfoCustom(subValue, value)
		else
			local spellSlot = FlyoutButton_FindSpellSlot(value)
			local _, _, spellInfoTexture = GetSpellInfo(value)
			if spellSlot and GetSpellBookItemTexture then
				texture = GetSpellBookItemTexture(spellSlot, BOOKTYPE_SPELL)
			end
			if not texture then
				texture = spellInfoTexture
			end
			if not texture and spellSlot then
				texture = GetSpellTexture(spellSlot, BOOKTYPE_SPELL)
			end
			if not texture then
				texture = GetSpellTexture(value)
			end
		end
	elseif (command == "item") then
		texture = GetItemIcon(value)
	elseif (command == "macro") then
		_, texture = GetMacroInfo(value)
	end

	if (texture) then
		icon:SetTexture(texture)
		icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
		icon:Show()
		if FbcShowBorders then
			self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
		else
			self:SetNormalTexture("") --remove border
		end
	elseif (command == "spell") or (command == "macro") then
		icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetVertexColor(1.0, 1.0, 1.0, 0.5)
		icon:Show()
		self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")		
	else
		local buttonCooldown = self.cooldown
		icon:Hide()
		buttonCooldown:Hide()
		self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot")
	end
end

function FlyoutListButton:UpdateChecked()
	local result = false

	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			_, _, _, _, _, result = FlyoutButton_GetCompanionInfoCustom(subValue, value)
			local spellName = UnitCastingInfo("player")
			result = result or spellName == value
		else
			result = IsCurrentSpell(value) or IsAutoRepeatSpell(value)
		end
	elseif (command == "item") then
		result = IsCurrentItem(value)
	elseif (command == "macro") then
		--nothing, this isn't action bar
	end
	
	self:SetChecked(result)
end

function FlyoutListButton:UpdateEquipped()
	local border = self.border

	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "item") then
		if IsEquippedItem(value) then
			border:SetVertexColor(0, 1.0, 0, 0.35)
			border:Show()
		else
			border:Hide()
		end
	elseif (command == "macro") then
		--todo?
	end
end

function FlyoutListButton:UpdateCooldown()
	local cooldown = self.cooldown

	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			local index = FlyoutButton_GetCompanionInfoCustom(subValue, value)
			if (index) then
				CooldownFrame_SetTimer(cooldown, GetCompanionCooldown(subValue, index))
			end
		else
			local start, duration, enable = GetSpellCooldown(value)
			if start then
				CooldownFrame_SetTimer(cooldown, start, duration, enable)
			else
				CooldownFrame_SetTimer(cooldown, 0, 0, 0)
				cooldown:Hide()
			end
		end
	elseif (command == "item") then
		CooldownFrame_SetTimer(cooldown, GetItemCooldown(value))
	elseif (command == "macro") then
		local index = subValue --GetMacroIndexByName(value)
		if (index) then
			local name, rank = GetMacroSpell(index)
			if (name) then
				local spell = name.."("..rank..")"
				local start, duration, enable = GetSpellCooldown(spell)
				if start then
					CooldownFrame_SetTimer(cooldown, start, duration, enable)
				else
					CooldownFrame_SetTimer(cooldown, 0, 0, 0)
					cooldown:Hide()
				end
			end
		end
	end
end

function FlyoutListButton:UpdateUsable()
	local isUsable, notEnoughMana

	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			--nothing works in Darkbreak Cove for mounts, Blizz using IsUsableAction(action_bar_slot)
			isUsable = (subValue == "MOUNT" and IsOutdoors()) or subValue == "CRITTER"
		else
			isUsable, notEnoughMana = IsUsableSpell(value)
		end
	elseif (command == "item") then
		isUsable, notEnoughMana = IsUsableItem(value)
	elseif (command == "macro") then
		--this isn't action bar, always usable
		isUsable = true
	end
	
	local icon = self.icon
	local ntexture = self.ntexture
	if (isUsable) then
		icon:SetVertexColor(1.0, 1.0, 1.0)
		ntexture:SetVertexColor(1.0, 1.0, 1.0)
	elseif (notEnoughMana and not(subValue == "MOUNT" or subValue == "CRITTER")) then
		icon:SetVertexColor(0.5, 0.5, 1.0)
		ntexture:SetVertexColor(0.5, 0.5, 1.0)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
		ntexture:SetVertexColor(1.0, 1.0, 1.0)
	end	
end

function FlyoutListButton:UpdateButtonText()
	local text = self.count
	local actionName = self.name
	
	text:SetText("")
	actionName:SetText("")
	
	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell" and IsConsumableSpell(value)) then
		text:SetText(GetSpellCount(value))
	elseif (command == "item" and IsConsumableItem(value)) then
		text:SetText(GetItemCount(value))
	elseif (command == "item" and GetItemCount(value) > 1) then
		text:SetText(GetItemCount(value))
	elseif (self:GetAttribute("type") == "macro") then
		-- name, iconTexture, body, isLocal = GetMacroInfo("name" or macroSlot)
		actionName:SetText(GetMacroInfo(subValue)) --by slot
	end
	text:Show()
end

function FlyoutListButton:InRange()
	local command, value, subValue = self.command, self.value, self.subValue
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			return nil
		else
			return IsSpellInRange(value, "target")
		end
	elseif (command == "item") then
		return IsItemInRange(value, "target")
	elseif (command == "macro") then
		--this isn't action bar, always usable
		return nil
	end
	return nil
end

function FlyoutListButton:UpdateRange()
	local hotkey = self.hotkey
	local valid = self:InRange()
	if ( hotkey:GetText() == RANGE_INDICATOR ) then
		if ( valid == 0 ) then
			hotkey:Show()
			hotkey:SetVertexColor(1.0, 0.1, 0.1)
		elseif ( valid == 1 ) then
			hotkey:Show()
			hotkey:SetVertexColor(0.6, 0.6, 0.6)
		else
			hotkey:Hide()
		end
	else
		if ( valid == 0 ) then
			hotkey:SetVertexColor(1.0, 0.1, 0.1)
		else
			hotkey:SetVertexColor(0.6, 0.6, 0.6)
		end
	end
end

function FlyoutListButton:Set(command, value, subValue)
	--print("SetListButton "..tostring(command)..", "..tostring(value)..", "..tostring(subValue))
	if command == "spell" and subValue ~= "MOUNT" and subValue ~= "CRITTER" and value then
		local spellSlot = FlyoutButton_FindSpellSlot(value)
		if spellSlot then
			_, value = FlyoutButton_GetSpellName(spellSlot, BOOKTYPE_SPELL)
		end
	end
	self.command, self.value, self.subValue = command, value, subValue
	self:SetAttribute("type", command)
	if command then
		self:SetAttribute(command, value)
	end
	if command == "item" then
		local itemname = GetItemInfo(value)
		self:SetAttribute("item", itemname)
	end
	
	self:SetTooltip()
	self:UpdateButton()
	self:Show()
	if command then
		self:RegisterEvents()
	else
		self:UnregisterEvents()
	end
end

function FlyoutListButton:PreClick(button)
	if InCombatLockdown() then
		ClearCursor()
		return
	end
	
	StoredCursor = {}
	local command, value, subValue = FlyoutButton_GetCursorValues()
	--print("PreClick "..tostring(command)..", "..tostring(value)..", "..tostring(subValue))
	if button == "LeftButton" then
		if command and FbcSettingsMode then
			StoredCursor.command, StoredCursor.value, StoredCursor.subValue = command, value, subValue
			self:SetAttribute("type", nil) --to avoid click event (spell cast)
		end
	elseif button == "RightButton" then
		StoredCursor.prevCommand = self:GetAttribute("type")
		self:SetAttribute("type", nil) --to avoid click event (spell cast)
	end
end

function FlyoutListButton:PostClick(button)
	if InCombatLockdown() then
		return
	end
	
	if button == "LeftButton" and StoredCursor.command then
		local arrowBtn = self:GetParent():GetParent()
		local command, value, subValue = self.command, self.value, self.subValue
		FlyoutButton_SetCursor(StoredCursor.command, StoredCursor.value, StoredCursor.subValue)
		self:OnReceiveDrag()
		if command then
			FlyoutButton_SetCursor(command, value, subValue)
		end
	elseif button == "RightButton" then
		local arrowBtn = self:GetParent():GetParent()
		local actBtn = arrowBtn:GetParent()
		if StoredCursor.prevCommand then
			self:SetAttribute("type", StoredCursor.prevCommand)
		end
		if self.command then
			-- frame._state_action for BT4 ?
			if actBtn.action and actBtn.action <= 120 then
				FlyoutButton_SetCursor(self.command, self.value, self.subValue)
				PlaceAction(actBtn.action)
				ActionButton_UpdateState(actBtn)
				ActionButton_UpdateFlash(actBtn)
				ClearCursor()
			elseif tostring(actBtn:GetName()):match("^ButtonForge%d+$") and BFButton and BFButton.OnReceiveDrag then
				FlyoutButton_SetCursor(self.command, self.value, self.subValue)
				BFButton.OnReceiveDrag(actBtn)
				ClearCursor()
			end
		end
		self:SetChecked(nil)
	end
end

function FlyoutListButton:OnReceiveDrag()
	if InCombatLockdown() then
		ClearCursor()
		return
	end

	local command, value, subValue = FlyoutButton_GetCursorValues()
	--print("OnReceiveDrag "..tostring(command)..", "..tostring(value)..", "..tostring(subValue))

	ClearCursor()
	if self.command then
		FlyoutButton_SetCursor(self.command, self.value, self.subValue)
	end

	self:Set(command, value, subValue)
	
	local actnBtnName = self.actnBtnName
	local currentSet = GetActiveTalentGroup()
	if command then
		FlyoutButtonCustomLegacy_Settings[actnBtnName] = FlyoutButtonCustomLegacy_Settings[actnBtnName] or {}
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] = FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] or {}
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] = FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] or {}
		
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["command"] = command
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["value"] = value
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["subValue"] = subValue
	end
	self:GetParent():GetParent():UpdateArrow()
	self:GetParent():GetParent():UpdateMainIcon()
end

function FlyoutListButton:OnDragStart()
	if not(FbcSettingsMode) then
		return
	end
	
	local arrowBtn = self:GetParent():GetParent()
	local actnBtnName = self.actnBtnName
	local currentSet = GetActiveTalentGroup()

	if self.command then
		FlyoutButton_SetCursor(self.command, self.value, self.subValue)
	end
	
	if FlyoutButtonCustomLegacy_Settings[actnBtnName] and FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] and FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] then
		FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] = {}
	end
	
	self:Set(nil, nil, nil)
	
	--clear all upper empty slots
	local bl = self:GetParent().ButtonList
	for i = #bl, 1, -1 do
		if not(bl[i].command) then
			if FlyoutButtonCustomLegacy_Settings[actnBtnName] and FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] and FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][i] then
				FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][i] = nil
			end
		else
			break
		end
	end
	
	--empty tables to nil
	if FlyoutButtonCustomLegacy_Settings[actnBtnName] then
		if FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] then
			if #FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] == 0 then
				FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] = nil
			end
		end
		if #FlyoutButtonCustomLegacy_Settings[actnBtnName] == 0 then
			FlyoutButtonCustomLegacy_Settings[actnBtnName] = nil
		end
	end
	arrowBtn:UpdateArrow()
	arrowBtn:UpdateMainIcon()
end

function FlyoutListButton:HideButton()
	self.tooltipValue = nil
	self.tooltipType = nil
	self:SetAttribute("type", "none")
	self.icon:Hide()
	self.cooldown:Hide()
	self.border:Hide()
	self.count:Hide()
	self.name:SetText("")
	self.hotkey:Hide()
	self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot")
	self:SetChecked(0)
	self:Hide()
end

function FlyoutListButton:UpdateButton()
	self:SetTooltip()
	self:UpdateTexture()
	self:UpdateCooldown()
	self:UpdateChecked()
	self:UpdateEquipped()
	self:UpdateUsable()
	self:UpdateButtonText()
	if self.command then
		self.rangeTimer = -1
	else
		self.rangeTimer = nil
	end
end

local function EventCooldownUpdate(self, ...)
	self:UpdateCooldown()
end

local function EventCheckedUpdate(self, ...)
	self:UpdateChecked()
end

local function EventEquippedUpdate(self, ...)
	self:UpdateEquipped()
	self:UpdateButtonText()
	self:UpdateCooldown()
end

local function EventUsableUpdate(self, ...)
	self:UpdateUsable()
	self:UpdateButtonText()
	self:UpdateCooldown()
end

local function EventMacroUpdate(self, ...)
	if InCombatLockdown() then
		return
	end

	if self.command == "macro" then
		--command = "macro", value = macro name, subValue = macro index
		local command, subValue = self.command, self.subValue
		local value = GetMacroInfo(subValue)
		self:Set(command, value, subValue)

		local arrowBtn = self:GetParent():GetParent()
		local actnBtnName = self.actnBtnName
		local currentSet = GetActiveTalentGroup()
		if value then
			FlyoutButtonCustomLegacy_Settings[actnBtnName] = FlyoutButtonCustomLegacy_Settings[actnBtnName] or {}
			FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] = FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] or {}
			FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] = FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index] or {}
			
			FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["command"] = command
			FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["value"] = value
			FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet][self.index]["subValue"] = subValue
		else
			--empty tables to nil
			if FlyoutButtonCustomLegacy_Settings[actnBtnName] then
				if FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] then
					if #FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] == 0 then
						FlyoutButtonCustomLegacy_Settings[actnBtnName][currentSet] = nil
					end
				end
				if #FlyoutButtonCustomLegacy_Settings[actnBtnName] == 0 then
					FlyoutButtonCustomLegacy_Settings[actnBtnName] = nil
				end
			end
		end
		arrowBtn:UpdateArrow()
	end
end

local function EventRangeUpdate(self, ...)
	self:UpdateRange()
	rangeTimer = TOOLTIP_UPDATE_TIME
end

function FlyoutListButton:OnUpdate(elapsed)
	local rangeTimer = self.rangeTimer
	if ( rangeTimer ) then
		rangeTimer = rangeTimer - elapsed

		if ( rangeTimer <= 0 ) then
			self:UpdateRange()
			rangeTimer = TOOLTIP_UPDATE_TIME
		end
		
		self.rangeTimer = rangeTimer
	end
end

function FlyoutListButton:OnEvent(event, ...)
	if self.EventHandlersTable[event] then
		self.EventHandlersTable[event](self, ...)
	end
end

function FlyoutListButton:RegisterEvents()
	--event table
	self.EventHandlersTable = {
		--cooldown
		["SPELL_UPDATE_COOLDOWN"] 			= EventCooldownUpdate,
		["BAG_UPDATE_COOLDOWN"] 			= EventCooldownUpdate,
		["ACTIONBAR_UPDATE_COOLDOWN"] 		= EventCooldownUpdate,
		["UPDATE_SHAPESHIFT_COOLDOWN"] 		= EventCooldownUpdate,
		--checked
		["TRADE_SKILL_SHOW"] 				= EventCheckedUpdate,
		["TRADE_SKILL_CLOSE"] 				= EventCheckedUpdate,
		["COMPANION_UPDATE"] 				= EventCheckedUpdate,
		["CURRENT_SPELL_CAST_CHANGED"] 		= EventCheckedUpdate,
		["ACTIONBAR_UPDATE_STATE"] 			= EventCheckedUpdate,
		["PLAYER_ENTER_COMBAT"] 			= EventCheckedUpdate,
		["PLAYER_LEAVE_COMBAT"] 			= EventCheckedUpdate,
		["START_AUTOREPEAT_SPELL"] 			= EventCheckedUpdate,
		["STOP_AUTOREPEAT_SPELL"] 			= EventCheckedUpdate,
		["UPDATE_BONUS_ACTIONBAR"] 			= EventCheckedUpdate,
		["ACTIONBAR_PAGE_CHANGED"] 			= EventCheckedUpdate,
		--equipment
		["PLAYER_EQUIPMENT_CHANGED"] 		= EventEquippedUpdate,
		--usable
		["BAG_UPDATE"] 						= EventUsableUpdate,
		--["UNIT_INVENTORY_CHANGED"] 		= EventUsableUpdate,
		["SPELL_UPDATE_USABLE"] 			= EventUsableUpdate,
		["PLAYER_CONTROL_LOST"] 			= EventUsableUpdate,
		["PLAYER_CONTROL_GAINED"] 			= EventUsableUpdate,
		["UPDATE_BONUS_ACTIONBAR"] 			= EventUsableUpdate,
		["ACTIONBAR_UPDATE_USABLE"] 		= EventUsableUpdate,
		["VEHICLE_UPDATE"] 					= EventUsableUpdate,
		["UPDATE_WORLD_STATES"] 			= EventUsableUpdate,
		--macro
		["UPDATE_MACROS"]					= EventMacroUpdate,
		--ranfe
		["PLAYER_TARGET_CHANGED"]			= EventRangeUpdate,
	}
	
	--cooldown events
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
	--checked events
	self:RegisterEvent("TRADE_SKILL_SHOW")
	self:RegisterEvent("TRADE_SKILL_CLOSE")
	self:RegisterEvent("COMPANION_UPDATE")
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
	self:RegisterEvent("ACTIONBAR_UPDATE_STATE")
	self:RegisterEvent("PLAYER_ENTER_COMBAT")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT")
	self:RegisterEvent("START_AUTOREPEAT_SPELL")
	self:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	--equipment events
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	--usable events
	self:RegisterEvent("BAG_UPDATE")
	--self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("SPELL_UPDATE_USABLE")
	self:RegisterEvent("PLAYER_CONTROL_LOST")
	self:RegisterEvent("PLAYER_CONTROL_GAINED")
	self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
	self:RegisterEvent("VEHICLE_UPDATE")
	self:RegisterEvent("UPDATE_WORLD_STATES")
	--macro event
	self:RegisterEvent("UPDATE_MACROS")
	--range events
	self:RegisterEvent("PLAYER_TARGET_CHANGED")

	self:SetScript("OnEvent", FlyoutListButton.OnEvent)
	self:SetScript("OnUpdate", FlyoutListButton.OnUpdate)
end

function FlyoutListButton:UnregisterEvents()
	if self.EventHandlersTable then
		for k, _ in pairs(self.EventHandlersTable) do
			self:UnregisterEvent(k)
		end
	end
	self.EventHandlersTable = {}
	self.rangeTimer = nil
	self.hotkey:Hide()
end

