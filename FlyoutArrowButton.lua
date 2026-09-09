--[[ FlyoutArrowButton ]]

local ARROW_BUTTON_DEF_WIDTH = 36
-- The original Cataclysm atlas does not exist in the Wrath client.  Use a
-- native pagination-arrow texture instead, and make its secure click area
-- cover the associated action button so that it acts as the flyout's main
-- button rather than as a separate tiny arrow.
local OPEN_FROM_MAIN_BUTTON = true
local MouseoverCloseDelay = 0.15
local MouseoverCloseTimer = 0
local MouseoverCloseArrow
local MouseoverTimerFrame = CreateFrame("Frame")
local ACCEPTABLE_COMMANDS = {
	["spell"] = true,
	["item"] = true,
	["macro"] = true,
	["companion"] = true
}
FlyoutArrowButton = {}

-- SetClampedTextureRotation is not present in the 3.3.5 client.  The
-- ActionBarFlyoutButton atlas region used by this addon can be rotated with
-- the eight-coordinate Texture:SetTexCoord form, which is available in Wrath.
local ARROW_LEFT, ARROW_RIGHT = 0, 1
local ARROW_TOP, ARROW_BOTTOM = 0, 1
local function SetArrowTextureRotation(texture, rotation)
	if rotation == 90 then
		texture:SetTexCoord(ARROW_LEFT, ARROW_BOTTOM, ARROW_RIGHT, ARROW_BOTTOM, ARROW_LEFT, ARROW_TOP, ARROW_RIGHT, ARROW_TOP)
	elseif rotation == 180 then
		texture:SetTexCoord(ARROW_RIGHT, ARROW_BOTTOM, ARROW_RIGHT, ARROW_TOP, ARROW_LEFT, ARROW_BOTTOM, ARROW_LEFT, ARROW_TOP)
	elseif rotation == 270 then
		texture:SetTexCoord(ARROW_RIGHT, ARROW_TOP, ARROW_LEFT, ARROW_TOP, ARROW_RIGHT, ARROW_BOTTOM, ARROW_LEFT, ARROW_BOTTOM)
	else
		texture:SetTexCoord(ARROW_LEFT, ARROW_TOP, ARROW_LEFT, ARROW_BOTTOM, ARROW_RIGHT, ARROW_TOP, ARROW_RIGHT, ARROW_BOTTOM)
	end
end


local ArrowButtonOnClickSnippet = [=[
	local B_PLACE_SIZE = 36
	local B_PLACE_OFFSET = 4

	local D_UP		= 1
	local D_LEFT	= 2
	local D_DOWN	= 3
	local D_RIGHT	= 4

	if button == "LeftButton" then
		lfRef = self:GetFrameRef("FlyoutListFrame_Ref")
		
		local width = B_PLACE_SIZE + 2 * B_PLACE_OFFSET
		local height = self:GetAttribute("bcount") * (B_PLACE_SIZE + B_PLACE_OFFSET) + B_PLACE_OFFSET
		
		if self:GetAttribute("expandDir") == D_UP or self:GetAttribute("expandDir") == D_DOWN then
			lfRef:SetWidth(width)
			lfRef:SetHeight(height)
		else
			lfRef:SetWidth(height)
			lfRef:SetHeight(width)
		end

		if self:GetAttribute("expanded") then
			self:SetAttribute("expanded", false)
			lfRef:Hide()
		else
			--close other opened lists
			local stub = self:GetFrameRef("StubFrame")
			if stub and stub:GetAttribute("unique-list") then
				local count = stub:GetAttribute("ArrowButtonsCount")
				if count then
					for i = 1, count do
						local ab = stub:GetFrameRef("FbcArrowButtons"..i)
						if ab and ab:GetAttribute("expanded") then
							local lf = ab:GetFrameRef("FlyoutListFrame_Ref")
							if lf then
								ab:SetAttribute("expanded", false)
								lf:Hide()
							end
						end
					end
				end
			end
			
			self:SetAttribute("expanded", true)
			lfRef:Show()
		end
	end
]=]
ArrowButtonOnEnterSnippet = [=[
	if not(self:GetAttribute("mouseoverincombat")) and (self:GetAttribute("incombat") > 0) then
		return
	end
	
	local B_PLACE_SIZE = 36
	local B_PLACE_OFFSET = 4

	local D_UP		= 1
	local D_LEFT	= 2
	local D_DOWN	= 3
	local D_RIGHT	= 4

	lfRef = self:GetFrameRef("FlyoutListFrame_Ref")
	
	local width = B_PLACE_SIZE + 2 * B_PLACE_OFFSET
	local height = self:GetAttribute("bcount") * (B_PLACE_SIZE + B_PLACE_OFFSET) + B_PLACE_OFFSET
	
	if self:GetAttribute("expandDir") == D_UP or self:GetAttribute("expandDir") == D_DOWN then
		lfRef:SetWidth(width)
		lfRef:SetHeight(height)
	else
		lfRef:SetWidth(height)
		lfRef:SetHeight(width)
	end

	if self:GetAttribute("expanded") then
		self:SetAttribute("expanded", false)
		lfRef:Hide()
	else
		--close other opened lists
		local stub = self:GetFrameRef("StubFrame")
		if stub and stub:GetAttribute("unique-list") then
			local count = stub:GetAttribute("ArrowButtonsCount")
			if count then
				for i = 1, count do
					local ab = stub:GetFrameRef("FbcArrowButtons"..i)
					if ab and ab:GetAttribute("expanded") then
						local lf = ab:GetFrameRef("FlyoutListFrame_Ref")
						if lf then
							ab:SetAttribute("expanded", false)
							lf:Hide()
						end
					end
				end
			end
		end
		
		self:SetAttribute("expanded", true)
		lfRef:Show()
	end
]=]

local function CancelMouseoverClose()
	MouseoverCloseArrow = nil
	MouseoverCloseTimer = 0
	MouseoverTimerFrame:Hide()
end

local function QueueMouseoverClose(arrowBtn)
	if not FbcEnableMouseover then
		return
	end
	MouseoverCloseArrow = arrowBtn
	MouseoverCloseTimer = MouseoverCloseDelay
	MouseoverTimerFrame:Show()
end

MouseoverTimerFrame:SetScript("OnUpdate", function(_, elapsed)
	if not MouseoverCloseArrow then
		MouseoverTimerFrame:Hide()
		return
	end
	MouseoverCloseTimer = MouseoverCloseTimer - elapsed
	if MouseoverCloseTimer <= 0 then
		local arrowBtn = MouseoverCloseArrow
		local listFrame = arrowBtn.FlyoutListFrame
		if not arrowBtn:IsMouseOver() and not listFrame:IsMouseOver() and not InCombatLockdown() then
			arrowBtn:SetAttribute("expanded", false)
			listFrame:Hide()
		end
		CancelMouseoverClose()
	end
end)

function FlyoutArrowButton:OnLeave()
	QueueMouseoverClose(self)
end

function FlyoutArrowButton:OnListEnter()
	CancelMouseoverClose()
end

function FlyoutArrowButton:OnListLeave()
	QueueMouseoverClose(self)
end

local ArrowButtonCombatSnippet = [=[
	if newstate == 1 and self:GetAttribute("bcount") == 0 and self:IsVisible() then
		self:SetAttribute("expanded", false)
		self:Hide()
	end
	self:SetAttribute("incombat", newstate)
]=]

local ArrowButtonVehicleSnippet = [=[
	if newstate == 1 and self:IsVisible() then
		self:SetAttribute("was_visible_vehicle", true)
		self:SetAttribute("expanded", false)
		self:Hide()
	elseif self:GetAttribute("was_visible_vehicle") then
		self:SetAttribute("was_visible_vehicle", false)
		self:SetAttribute("expanded", true)
		self:Show()
	end
]=]

function FlyoutArrowButton:SetTextureRotation(expandDir, expanded)
	if expanded then
		if expandDir == FBC_DIR_UP then
			SetArrowTextureRotation(self.FlyoutArrow, 180)
		elseif expandDir == FBC_DIR_LEFT then
			SetArrowTextureRotation(self.FlyoutArrow, 90)
		elseif expandDir == FBC_DIR_DOWN then
			SetArrowTextureRotation(self.FlyoutArrow, 0)
		else --if expandDir == FBC_DIR_RIGHT then
			SetArrowTextureRotation(self.FlyoutArrow, 270)
		end
	else
		if expandDir == FBC_DIR_UP then
			SetArrowTextureRotation(self.FlyoutArrow, 0)
		elseif expandDir == FBC_DIR_LEFT then
			SetArrowTextureRotation(self.FlyoutArrow, 270)
		elseif expandDir == FBC_DIR_DOWN then
			SetArrowTextureRotation(self.FlyoutArrow, 180)
		else --if expandDir == FBC_DIR_RIGHT then
			SetArrowTextureRotation(self.FlyoutArrow, 90)
		end
	end
end

function FlyoutArrowButton:SetFrameSize(expandDir)
	if OPEN_FROM_MAIN_BUTTON then
		self:SetWidth(ARROW_BUTTON_DEF_WIDTH)
		self:SetHeight(ARROW_BUTTON_DEF_WIDTH)
		return
	end
	if expandDir == FBC_DIR_UP or expandDir == FBC_DIR_DOWN then
		self:SetWidth(ARROW_BUTTON_DEF_WIDTH)
		self:SetHeight(FbcArrowButtonsHeight)
	else
		self:SetWidth(FbcArrowButtonsHeight)
		self:SetHeight(ARROW_BUTTON_DEF_WIDTH)
	end
end

function FlyoutArrowButton:UpdateMainIcon()
	if not self.MainIcon then
		return
	end
	local parent = self:GetParent()
	local sourceIcon = parent and _G[parent:GetName().."Icon"]
	local texture = sourceIcon and sourceIcon:GetTexture()
	if not texture and self.FlyoutListFrame then
		local firstButton = self.FlyoutListFrame.ButtonList[1]
		texture = firstButton and firstButton.icon:GetTexture()
	end
	self.MainIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	self.MainIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function FlyoutArrowButton:OnDragStart()
	if InCombatLockdown() then
		return
	end
	if not self:GetParent().isStandalone then
		local action = self:GetParent().action or self:GetParent()._state_action
		if action then
			PickupAction(action)
		end
		return
	end
	if not IsShiftKeyDown() then
		return
	end

	-- Detach from the action-button rectangle before moving. The flyout list
	-- remains a child of this secure button and therefore follows it.
	local x, y = self:GetCenter()
	if not x or not y then
		return
	end
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	self:StartMoving()
end

function FlyoutArrowButton:OnDragStop()
	if InCombatLockdown() then
		return
	end
	self:StopMovingOrSizing()
	local x, y = self:GetCenter()
	if not x or not y then
		return
	end
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

	local positions = FlyoutButtonCustomLegacy_Settings["positions"]
	positions[self.configName or self.flyoutName or self:GetParent():GetName()] = { x = x, y = y }
end

function FlyoutArrowButton:SetAnchor(parent, expandDir)
	if OPEN_FROM_MAIN_BUTTON and self == parent then
		local positions = FlyoutButtonCustomLegacy_Settings["positions"]
		local position = positions and positions[self.configName or self.flyoutName]
		if position then
			self:ClearAllPoints()
			self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", position.x, position.y)
		end
		self.FlyoutArrow:Hide()
		return
	end
	self:ClearAllPoints()
	self.FlyoutArrow:ClearAllPoints()
	if OPEN_FROM_MAIN_BUTTON then
		local positions = FlyoutButtonCustomLegacy_Settings["positions"]
		local position = positions and positions[self.configName or self.flyoutName or parent:GetName()]
		if position then
			self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", position.x, position.y)
		else
			self:SetAllPoints(parent)
		end
		self.FlyoutArrow:Hide()
		return
	end
	if expandDir == FBC_DIR_UP then
		self:SetPoint("TOP", parent, "TOP", 0, 4)
		self.FlyoutArrow:SetPoint("TOP")
	elseif expandDir == FBC_DIR_LEFT then
		self:SetPoint("LEFT", parent, "LEFT", -4, 0)
		self.FlyoutArrow:SetPoint("LEFT")
	elseif expandDir == FBC_DIR_DOWN then
		self:SetPoint("BOTTOM", parent, "BOTTOM", 0, -4)
		self.FlyoutArrow:SetPoint("BOTTOM")
	else
		self:SetPoint("RIGHT", parent, "RIGHT", 4, 0)
		self.FlyoutArrow:SetPoint("RIGHT")
	end
end

function FlyoutArrowButton:SetHighlight(value)
	if value then
		self:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	else
		self:SetHighlightTexture("")
	end
end

function FlyoutArrowButton_New(parent, flyoutName)
	parent.customFlyout = true
	local actnBtnName = parent:GetName()
	local tempFrame = parent.isStandalone and parent or _G[actnBtnName.."ArrowBtn"]

	local arrowBtn
	if tempFrame then
		FbcArrowButtons[actnBtnName] = tempFrame --reuse frame
		arrowBtn = FbcArrowButtons[actnBtnName]
		if parent.isStandalone and not arrowBtn.fbcInitialized then
			for k, v in pairs(FlyoutArrowButton) do
				if type(v) == "function" then
					arrowBtn[k] = v
				end
			end
			local count = FbcStubFrame:GetAttribute("ArrowButtonsCount") or 0
			count = count + 1
			FbcStubFrame:SetAttribute("ArrowButtonsCount", count)
			FbcStubFrame:SetFrameRef("FbcArrowButtons"..count, arrowBtn)
			arrowBtn:SetFrameRef("StubFrame", FbcStubFrame)
			arrowBtn:SetHighlight(FbcHighlight)
			arrowBtn.fbcInitialized = true
		end
	else
		FbcArrowButtons[actnBtnName] = CreateFrame("CheckButton", actnBtnName.."ArrowBtn", parent, "CustomFlyoutArrowButtonTemplate")
		arrowBtn = FbcArrowButtons[actnBtnName]
		
		-- adding methods to arrow button
		for k, v in pairs(FlyoutArrowButton) do
			if type(v) == "function" then
				arrowBtn[k] = v
			end
		end
		
		--set reference in stub
		local count = FbcStubFrame:GetAttribute("ArrowButtonsCount")
		if not(count) then
			count = 1
		else
			count = count + 1
		end
		FbcStubFrame:SetAttribute("ArrowButtonsCount", count)
		FbcStubFrame:SetFrameRef("FbcArrowButtons"..count, arrowBtn)
		arrowBtn:SetFrameRef("StubFrame", FbcStubFrame)
		arrowBtn:SetHighlight(FbcHighlight)
		arrowBtn.fbcInitialized = true
	end
	-- parentKey is not available on all 3.3.5 FrameXML builds.
	if not arrowBtn.FlyoutArrow then
		arrowBtn.FlyoutArrow = _G[arrowBtn:GetName().."FlyoutArrow"]
		if not arrowBtn.FlyoutArrow then
			arrowBtn.FlyoutArrow = arrowBtn:CreateTexture(nil, "OVERLAY")
		end
		arrowBtn.FlyoutArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		arrowBtn.FlyoutArrow:SetWidth(16)
		arrowBtn.FlyoutArrow:SetHeight(16)
	end
	if parent.isStandalone then
		arrowBtn.MainIcon = _G[arrowBtn:GetName().."Icon"]
	end
	arrowBtn.flyoutName = flyoutName or (parent.isStandalone and actnBtnName or nil)
	-- For a macro action slot this secure click receiver is intentionally
	-- invisible: Blizzard owns the action button's icon, border and drag UI.
	arrowBtn:UpdateMainIcon()
	if parent.isStandalone then
		arrowBtn:SetMovable(true)
		arrowBtn:SetClampedToScreen(true)
	end
	arrowBtn:RegisterForDrag("LeftButton")
	arrowBtn:SetScript("OnDragStart", arrowBtn.OnDragStart)
	arrowBtn:SetScript("OnDragStop", arrowBtn.OnDragStop)
	arrowBtn:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	arrowBtn:SetScript("OnEvent", function(self, event, slot)
		if event == "ACTIONBAR_SLOT_CHANGED" and not InCombatLockdown() then
			local parent = self:GetParent()
			if parent and (slot == parent.action or slot == parent._state_action) then
				self:UpdateMainIcon()
			end
		end
	end)
	--arrowBtn:SetFrameLevel(arrowBtn:GetParent():GetFrameLevel() + 1)

	if not(arrowBtn.FlyoutListFrame) then
		arrowBtn.FlyoutListFrame = FlyoutListFrame_New(arrowBtn)
		arrowBtn:SetFrameRef("FlyoutListFrame_Ref", arrowBtn.FlyoutListFrame)
	end

	arrowBtn:SetAttribute("mouseoverincombat", FbcEnableMouseoverInCombat)
	arrowBtn:SetAttribute("mouseover-enabled", FbcEnableMouseover)

	arrowBtn:SetAttribute("_onclick", ArrowButtonOnClickSnippet)
	if FbcEnableMouseover then
		arrowBtn:SetAttribute("_onenter", ArrowButtonOnEnterSnippet)
	end
	arrowBtn:SetAttribute("_onleave", "")
	arrowBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	--self, stateid, newstate
	arrowBtn:SetAttribute("_onstate-combat", ArrowButtonCombatSnippet)
	RegisterStateDriver(arrowBtn, "combat", "[nocombat] 0; [combat] 1;")

	arrowBtn:SetAttribute("_onstate-vehicle", ArrowButtonVehicleSnippet)
	RegisterStateDriver(arrowBtn, "vehicle", "[novehicleui] 0; [vehicleui] 1;")
	
	return arrowBtn
end

function GetFlyoutArrowButton(frame)
	if not(frame) or (frame:GetName() == "") then
		return nil
	end
	
	return FbcArrowButtons[frame:GetName()]
end

function FlyoutArrowButton_Attach(frame, flyoutName, requestedSlots, macroID)
	-- Creating, anchoring, showing, or changing attributes of protected frames
	-- is forbidden in combat. Existing secure list buttons remain usable there.
	if not frame or not frame:GetName() or frame:GetName() == "" or InCombatLockdown() then
		return
	end
	if (frame.action and GetActionInfo(frame.action) == "flyout") or (frame._state_action and GetActionInfo(frame._state_action) == "flyout") then
		return
	end
	
	local actnBtnName = frame:GetName()
	local configName = macroID and "macro:"..tostring(macroID) or flyoutName or actnBtnName
	local currentSet = GetActiveTalentGroup()
	local expandDir = FBC_DIR_UP

	local arrowBtn = GetFlyoutArrowButton(frame)	
	if not(arrowBtn) then --create new
		arrowBtn = FlyoutArrowButton_New(frame, flyoutName)
	end
	arrowBtn.flyoutName = flyoutName
	arrowBtn.configName = configName
	arrowBtn.requestedSlots = requestedSlots
	local fbcs = FlyoutButtonCustomLegacy_Settings
	if macroID and not fbcs[configName] and fbcs[flyoutName] then
		fbcs[configName] = fbcs[flyoutName]
	end
	if macroID and not fbcs["expandDir"][currentSet][configName] then
		fbcs["expandDir"][currentSet][configName] = fbcs["expandDir"][currentSet][flyoutName]
	end
	
	if fbcs["expandDir"][currentSet][configName] then
		expandDir = fbcs["expandDir"][currentSet][configName]
	elseif (frame:GetParent() == MultiBarRight or frame:GetParent() == MultiBarLeft) then
		expandDir = FBC_DIR_LEFT
	end
	arrowBtn:SetAnchor(frame, expandDir)
	arrowBtn:UpdateMainIcon()
	arrowBtn:SetAttribute("expandDir", expandDir)
	
	local flf = arrowBtn.FlyoutListFrame
	flf:SetAnchor(arrowBtn, expandDir)

	if fbcs[configName] and fbcs[configName][currentSet] then
		local savedSlots = fbcs[configName][currentSet]
		local savedCount = FlyoutButton_GetListButtonsCount(savedSlots)
		for i = 1, savedCount do
			local v = savedSlots[i]
			local btn = FlyoutListButton_AttachToList(flf, i, expandDir)
			if v and ACCEPTABLE_COMMANDS[v["command"]] then
				btn:Set(v["command"], v["value"], v["subValue"])
				btn:SetKey(v["keybind"])
			else
				btn:Set(nil, nil, nil)
				btn:SetKey(nil)
			end
		end
		for i = savedCount + 1, requestedSlots or savedCount do
			local btn = FlyoutListButton_AttachToList(flf, i, expandDir)
			btn:Set(nil, nil, nil)
		end
		local visibleCount = requestedSlots or savedCount
		arrowBtn:SetAttribute("bcount", visibleCount)
		flf:SetAttribute("bcount", visibleCount)
		arrowBtn:Show()
		arrowBtn:SetAlpha(1)
		if not OPEN_FROM_MAIN_BUTTON then
			arrowBtn.FlyoutArrow:Show()
		end
	else
		local visibleCount = requestedSlots or 0
		arrowBtn:SetAttribute("bcount", visibleCount)
		flf:SetAttribute("bcount", visibleCount)
		for i = 1, visibleCount do
			local btn = FlyoutListButton_AttachToList(flf, i, expandDir)
			btn:Set(nil, nil, nil)
		end
		if visibleCount > 0 then
			arrowBtn:Show()
		else
			arrowBtn:Hide()
		end
	end
	
	arrowBtn:SetFrameSize(expandDir)
	
	arrowBtn:SetAttribute("expanded", false)
	arrowBtn:SetTextureRotation(expandDir, false)
end

function FlyoutArrowButton:ShowArrow()
	if InCombatLockdown() then
		return
	end
	
	self:SetTextureRotation(self:GetAttribute("expandDir"), self:GetAttribute("expanded"))
	
	self:Show()
	if not OPEN_FROM_MAIN_BUTTON then
		self.FlyoutArrow:Show()
	end
	if (self:GetAttribute("bcount") > 0) then
		self:SetAlpha(1)
	else
		self:SetAlpha(0.5)
	end
end

function FlyoutArrowButton:HideArrow()
	if InCombatLockdown() then
		return
	end
	
	if (self:GetAttribute("bcount") > 0) then
		self:SetAlpha(1)
	else
		self:SetAttribute("expanded", false)
		self.FlyoutListFrame:Hide()
		self.FlyoutArrow:Hide()
		self:Hide()
	end
end

function FlyoutArrowButton:UpdateArrow()
	if InCombatLockdown() or not(self:GetParent().customFlyout) then
		return
	end
	
	local currentSet = GetActiveTalentGroup()
	local actnBtnName = self.configName or self.flyoutName or self:GetParent():GetName()
	local fbcs = FlyoutButtonCustomLegacy_Settings
	local count, settingsCount = 0, 0
	
	if fbcs[actnBtnName] and fbcs[actnBtnName][currentSet] then
		count, settingsCount = FlyoutButton_GetListButtonsCount(fbcs[actnBtnName][currentSet])
	else
		count, settingsCount = FlyoutButton_GetListButtonsCount(nil)
	end
	if self.requestedSlots then
		settingsCount = self.requestedSlots
	end
	local visibleCount = settingsCount
	
	local flf = self.FlyoutListFrame
	flf:SetSize(self:GetAttribute("expandDir"), settingsCount)
	self:SetAttribute("bcount", visibleCount)
	self.FlyoutListFrame:SetAttribute("bcount", visibleCount)
	
	--cleanup
	for i, v in ipairs(flf.ButtonList) do
		if not(v.command) then
			if i <= settingsCount then
				v:Set(nil, nil, nil)
			else
				v:HideButton()
			end
		end
		v:SetAnchor(flf, i, self:GetAttribute("expandDir"))
	end
	
	--add empty buttons
	for i = count + 1, settingsCount do
		local btn = FlyoutListButton_AttachToList(flf, i, self:GetAttribute("expandDir"))
		btn:Set(nil, nil, nil)
	end
end

function FlyoutArrowButton:PostClick(button)
	if not(InCombatLockdown()) then
		if button == "LeftButton" then
			if FbcSettingsMode then
				self:UpdateArrow()
			else
				--cleanup
				for i, v in ipairs(self.FlyoutListFrame.ButtonList) do
					if i <= self:GetAttribute("bcount") then
						v:Show()
					else
						v:HideButton()
					end
				end
				self.FlyoutListFrame:SetSize(self:GetAttribute("expandDir"), self:GetAttribute("bcount"))
			end
		elseif button == "RightButton" then
			local expandDir = self:GetAttribute("expandDir")
			expandDir = expandDir + 1
			if expandDir > FBC_DIR_RIGHT then
				expandDir = FBC_DIR_UP
			end

			local currentSet = GetActiveTalentGroup()
			FlyoutButtonCustomLegacy_Settings["expandDir"][currentSet][self.configName or self.flyoutName or self:GetParent():GetName()] = expandDir

			self:SetAnchor(self:GetParent(), expandDir)
			self:SetFrameSize(expandDir)
			self:SetTextureRotation(expandDir, self:GetAttribute("expanded"))
			self:SetAttribute("expandDir", expandDir)

			self.FlyoutListFrame:SetAnchor(self, expandDir)
			--self.FlyoutListFrame:SetSize(expandDir, self:GetAttribute("bcount"))
			self:UpdateArrow()
		end
	end
end
