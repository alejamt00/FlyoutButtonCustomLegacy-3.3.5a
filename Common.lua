--[[ Common ]]

--const
local MIN_VISIBLE_BUTTONS_SETTINGS_MODE = 4
FBC_BUTTON_PLACE_SIZE = 36
FBC_BUTTON_PLACE_OFFSET = 4

--arrow button directions
FBC_DIR_UP		= 1
FBC_DIR_LEFT	= 2
FBC_DIR_DOWN	= 3
FBC_DIR_RIGHT	= 4


function FlyoutButton_GetSpellName(spell, ...)
	-- GetSpellBookItemName was added after Wrath.  3.3.5 exposes the
	-- equivalent GetSpellName(index, bookType).
	local name, rank = GetSpellName(spell, ...)

	if (not rank) then
		rank = ""
	end
	if (name) then
		return name.."("..rank..")", name
	end
	return nil, nil
end

function FlyoutButton_FindSpellSlot(spellName)
	local slot = 1
	while true do
		local name, baseName = FlyoutButton_GetSpellName(slot, BOOKTYPE_SPELL)
		if (not name) then
			break
		end
		if (spellName == name or spellName == baseName) then
			return slot
		end
		slot = slot + 1
	end
	return nil
end

function FlyoutButton_GetCompanionInfoCustom(compType, compName)
	local creatureName, creatureSpellID, spellName, icon
	for i = 1, GetNumCompanions(compType) do
		--creatureID, creatureName, creatureSpellID, icon, issummoned
		_, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo(compType, i)
		local spellName = GetSpellInfo(creatureSpellID)
		if spellName == compName then
			return i, creatureName, creatureSpellID, spellName, icon, issummoned
		end
	end
	
	return nil
end

function FlyoutButton_SetCursor(command, value, subValue)
	if not(command) then
		return false
	end

	ClearCursor()
	if (command == "spell") then
		if (subValue == "MOUNT" or subValue == "CRITTER") then
			--index, creatureName, creatureSpellID, spellName, icon
			local idx = FlyoutButton_GetCompanionInfoCustom(subValue, value)
			PickupCompanion(subValue, idx)	--("type", index)
		elseif type(subValue) == "string" and subValue:match("^action:") then
			local spellID, actionSlot = subValue:match("^action:(%d+):?(%d*)$")
			spellID = tonumber(spellID)
			actionSlot = tonumber(actionSlot)
			if spellID then
				PickupSpell(spellID)
				if not GetCursorInfo() and actionSlot then
					PickupAction(actionSlot)
				end
			end
		elseif type(subValue) == "number" then
			local actionType = GetActionInfo(subValue)
			if actionType == "spell" then
				PickupAction(subValue)
			end
		else
			local slot = FlyoutButton_FindSpellSlot(value, BOOKTYPE_SPELL)
			if slot then
				PickupSpell(slot, BOOKTYPE_SPELL)
				if not GetCursorInfo() then
					local _, baseName = FlyoutButton_GetSpellName(slot, BOOKTYPE_SPELL)
					local _, rank = GetSpellName(slot, BOOKTYPE_SPELL)
					PickupSpell(baseName, rank)
					if not GetCursorInfo() then
						PickupSpell(baseName)
					end
				end
			end
		end
	elseif (command == "item") then
		PickupItem(value)	--itemID or "itemString" or "itemName" or "itemLink"
	elseif (command == "macro") then
		PickupMacro(value)
	end
	return GetCursorInfo() ~= nil
end

function FlyoutButton_GetCursorValues()
	local command, value, subValue = GetCursorInfo()
	if (command == "action") then
		local actionType, actionValue = GetActionInfo(value)
		if actionType == "spell" then
			command = "spell"
			subValue = "action:"..tostring(actionValue)..":"..tostring(value)
			value = GetSpellInfo(actionValue)
		elseif actionType == "item" then
			command = "item"
			value = actionValue
		elseif actionType == "macro" then
			command = "macro"
			subValue = actionValue
			value = GetMacroInfo(actionValue)
		end
	elseif (command == "spell") then
		_, value = FlyoutButton_GetSpellName(value, BOOKTYPE_SPELL)
	elseif (command == "item") then
		--nothing to do
	elseif (command == "macro") then		
		subValue = value -- value is macro index	
		value = GetMacroInfo(value) --name, texture, body
	elseif (command == "companion") then
		local _, _, spellId = GetCompanionInfo(subValue, value)
		value = GetSpellInfo(spellId)
		command = "spell"
	end
	return command, value, subValue
end

function FlyoutButton_GetListButtonsCount(listTable)
	local count = 0
	if listTable then
		for index, value in pairs(listTable) do
			if type(index) == "number" and value then
				count = math.max(count, index)
			end
		end
	end
	local settingsCount = count
	
	if FbcSettingsMode then
		if count < MIN_VISIBLE_BUTTONS_SETTINGS_MODE then
			settingsCount = MIN_VISIBLE_BUTTONS_SETTINGS_MODE
		else
			settingsCount = count + 1
		end
	end
	return count, settingsCount
end

