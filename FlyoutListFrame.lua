--[[ FlyoutListFrame ]]

FlyoutListFrame = {}


local FlyoutListFrameCombatSnippet = [=[
	if newstate == 1 and self:GetAttribute("bcount") == 0 and self:IsVisible() then
		self:Hide()
	end
]=]

local FlyoutListFrameVehicleSnippet = [=[
	if newstate == 1 and self:IsVisible() then
		self:SetAttribute("was_visible_vehicle", true)
		self:Hide()
	elseif self:GetAttribute("was_visible_vehicle") then
		self:SetAttribute("was_visible_vehicle", false)
		self:Show()
	end
]=]

function FlyoutListFrame_New(arrowBtn)
	local ownerName = arrowBtn:GetName()
	flf = CreateFrame("Frame", ownerName.."CustomFlyoutListFrame", arrowBtn, "CustomFlyoutListFrameTemplate")
	flf:SetAttribute("_onenter", FlyoutListFrameOnEnterSnippet)
	flf:SetAttribute("_onleave", FlyoutListFrameOnLeaveSnippet)
	-- adding methods to list frame
	for k, v in pairs(FlyoutListFrame) do
		--print(tostring(k).." = "..tostring(v)..", type "..tostring(type(v)))
		if type(v) == "function" then
			flf[k] = v
		end
	end
	
	flf.ButtonList = {}
	
	--arrowBtn, stateid, newstate
	flf:SetAttribute("_onstate-combat", FlyoutListFrameCombatSnippet)
	RegisterStateDriver(flf, "combat", "[nocombat] 0; [combat] 1;")

	flf:SetAttribute("_onstate-vehicle", FlyoutListFrameVehicleSnippet)
	RegisterStateDriver(flf, "vehicle", "[novehicleui] 0; [vehicleui] 1;")
	
	flf:RegisterEvents()
	
	return flf
end

function FlyoutListFrame:SetAnchor(arrowBtn, expandDir)
	self:ClearAllPoints()
	if expandDir == FBC_DIR_UP then
		self:SetPoint("BOTTOM", arrowBtn, "TOP", 0, 5)
	elseif expandDir == FBC_DIR_LEFT then
		self:SetPoint("RIGHT", arrowBtn, "LEFT", -5, 0)
	elseif expandDir == FBC_DIR_DOWN then
		self:SetPoint("TOP", arrowBtn, "BOTTOM", 0, -5)
	else --if expandDir == FBC_DIR_RIGHT then
		self:SetPoint("LEFT", arrowBtn, "RIGHT", 5, 0)
	end
end

function FlyoutListFrame:SetSize(expandDir, bcount)
	local width = FBC_BUTTON_PLACE_SIZE + 2 * FBC_BUTTON_PLACE_OFFSET
	local height = bcount * (FBC_BUTTON_PLACE_SIZE + FBC_BUTTON_PLACE_OFFSET) + FBC_BUTTON_PLACE_OFFSET
	
	if expandDir == FBC_DIR_UP or expandDir == FBC_DIR_DOWN then
		self:SetWidth(width)
		self:SetHeight(height)
	else
		self:SetWidth(height)
		self:SetHeight(width)
	end
end

function FlyoutListFrame:OnShow()
	self:GetParent():SetAlpha(1)
	if FbcShowBorders then
		self:SetBackdrop({edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
	else
		self:SetBackdrop({edgeFile = ""})
	end

	local ab = self:GetParent()
	if ab then
		ab:SetTextureRotation(ab:GetAttribute("expandDir"), ab:GetAttribute("expanded"))
	end
end

function FlyoutListFrame:OnHide()
	local ab = self:GetParent()
	if ab then
		ab:SetTextureRotation(ab:GetAttribute("expandDir"), ab:GetAttribute("expanded"))
	end
end

local function EventShowGrid(self, ...)
	self:SetFrameStrata("FULLSCREEN")
end

local function EventHideGrid(self, ...)
	self:SetFrameStrata("DIALOG")
end

function FlyoutListFrame:OnEvent(event, ...)
	if self.EventHandlersTable[event] then
		self.EventHandlersTable[event](self, ...)
	end
end

function FlyoutListFrame:RegisterEvents()
	--event table
	self.EventHandlersTable = {
		["ACTIONBAR_SHOWGRID"] 			= EventShowGrid,
		["ACTIONBAR_HIDEGRID"] 			= EventHideGrid,
	}
	self:RegisterEvent("ACTIONBAR_SHOWGRID")
	self:RegisterEvent("ACTIONBAR_HIDEGRID")
	
	self:SetScript("OnEvent", FlyoutListFrame.OnEvent)	
end

function FlyoutListFrame:UnregisterEvents()
	if self.EventHandlersTable then
		for k, _ in pairs(self.EventHandlersTable) do
			self:UnregisterEvent(k)
		end
	end
	self.EventHandlersTable = {}
end
