local libName, libVersion = "ElioteDropDownMenu-1.0", 13

--- @class ElioteDropDownMenu
local lib = LibStub:NewLibrary(libName, libVersion)
if not lib then return end

local _G = _G

local prefixDropDownList = "ElioteDDM_DropDownList"
local prefixDropDownListButtonRegex = "^" .. prefixDropDownList .. "[0-9]+$"

local BACKDROP_DROPDOWN = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 9, },
}

local MENUBACKDROP_DROPDOWN = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3, },
}

lib.UIDROPDOWNMENU_MAXBUTTONS = 0; -- the initialization will make this 1
lib.UIDROPDOWNMENU_MAXLEVELS = 0;  -- the initialization will make this 2
lib.UIDROPDOWNMENU_BUTTON_HEIGHT = 16;
lib.UIDROPDOWNMENU_BORDER_HEIGHT = 15;
-- The current open menu
lib.UIDROPDOWNMENU_OPEN_MENU = nil;
-- The current menu being initialized
lib.UIDROPDOWNMENU_INIT_MENU = nil;
-- Current level shown of the open menu
lib.UIDROPDOWNMENU_MENU_LEVEL = 1;
-- Current value of the open menu
lib.UIDROPDOWNMENU_MENU_VALUE = nil;
-- Time to wait to hide the menu
lib.UIDROPDOWNMENU_SHOW_TIME = 2;
-- Default dropdown text height
lib.UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = nil;
-- List of open menus
lib.OPEN_DROPDOWNMENUS = {};
-- Offset for buttons with checkbox in menu
-- Blizzards default is 6, with make arrows misaligned
lib.UIDROPDOWNMENU_DISPLAY_MODE_MENU_CHECKBOX_OFFSET = 2

------------------------------------
--- Custom Dropdown
------------------------------------

local function DropDownExpandArrow_OnMouseDown(self, button)
	if self:IsEnabled() then
		lib.ToggleDropDownMenu(self:GetParent():GetParent():GetID() + 1, self:GetParent().value, nil, nil, nil, nil, self:GetParent().menuList, self);
	end
end

local function DropDownExpandArrow_OnEnter(self)
	local level = self:GetParent():GetParent():GetID() + 1;

	lib.CloseDropDownMenus(level);

	if self:IsEnabled() then
		local listFrame = _G[prefixDropDownList .. level];
		if (not listFrame or not listFrame:IsShown() or select(2, listFrame:GetPoint()) ~= self) then
			lib.ToggleDropDownMenu(level, self:GetParent().value, nil, nil, nil, nil, self:GetParent().menuList, self);
		end
	end

	lib.UIDropDownMenu_StopCounting(self:GetParent():GetParent());
end

local function DropDownExpandArrow_OnLeave(self)
	lib.UIDropDownMenu_StartCounting(self:GetParent():GetParent());
end

-- UIDropDownMenuTemplates.xml
local function CreateDropDownMenuButton(name, parent)
	local dropDownFrame = _G[name] or CreateFrame("Button", name, parent)
	dropDownFrame:SetWidth(100)
	dropDownFrame:SetHeight(16)
	dropDownFrame:SetFrameLevel(dropDownFrame:GetParent():GetFrameLevel() + 2)

	local highlight = _G[name .. "Highlight"] or dropDownFrame:CreateTexture(name .. "Highlight", "BACKGROUND")
	dropDownFrame.Highlight = highlight
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints()
	highlight:Hide()

	local radioOn = _G[name .. "Check"] or dropDownFrame:CreateTexture(name .. "Check", "ARTWORK")
	radioOn:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
	radioOn:SetSize(16, 16)
	radioOn:SetPoint("LEFT", dropDownFrame, 0, 0)
	radioOn:SetTexCoord(0, 0.5, 0.5, 1.0)

	local radioOff = _G[name .. "UnCheck"] or dropDownFrame:CreateTexture(name .. "UnCheck", "ARTWORK")
	radioOff:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
	radioOff:SetSize(16, 16)
	radioOff:SetPoint("LEFT", dropDownFrame, 0, 0)
	radioOff:SetTexCoord(0.5, 1.0, 0.5, 1.0)

	local icon = _G[name .. "Icon"] or dropDownFrame:CreateTexture(name .. "Icon", "ARTWORK")
	icon:Hide()
	icon:SetSize(16, 16)
	icon:SetPoint("RIGHT", dropDownFrame, 0, 0)

	local colorSwatchFrame = _G[name .. "ColorSwatch"] or CreateFrame("Button", name .. "ColorSwatch", dropDownFrame)
	colorSwatchFrame:Hide()
	colorSwatchFrame:SetPoint("RIGHT", dropDownFrame, -6, 0)
	colorSwatchFrame:SetSize(16, 16)

	local colorSwatchBg = _G[colorSwatchFrame:GetName() .. "SwatchBg"] or colorSwatchFrame:CreateTexture(colorSwatchFrame:GetName() .. "SwatchBg", "BACKGROUND")
	colorSwatchBg:SetSize(14, 14)
	colorSwatchBg:SetPoint("CENTER", colorSwatchFrame, 0, 0)
	colorSwatchBg:SetColorTexture(1.0, 1.0, 1.0)

	local colorSwatchTexture = _G[colorSwatchBg:GetName() .. "NormalTexture"] or colorSwatchFrame:CreateTexture(colorSwatchBg:GetName() .. "NormalTexture")
	colorSwatchTexture:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
	colorSwatchTexture:SetAllPoints()
	colorSwatchFrame:SetNormalTexture(colorSwatchTexture)
	colorSwatchFrame.Color = colorSwatchTexture

	colorSwatchFrame:SetScript("OnClick", function(self, button, down)
		CloseMenus();
		lib.UIDropDownMenuButton_OpenColorPicker(self:GetParent())
	end)
	colorSwatchFrame:SetScript("OnEnter", function(self, motion)
		lib.CloseDropDownMenus(self:GetParent():GetParent():GetID() + 1)
		_G[self:GetName() .. "SwatchBg"]:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		lib.UIDropDownMenu_StopCounting(self:GetParent():GetParent());
	end)
	colorSwatchFrame:SetScript("OnLeave", function(self, motion)
		_G[self:GetName() .. "SwatchBg"]:SetColorTexture(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		lib.UIDropDownMenu_StartCounting(self:GetParent():GetParent());
	end)

	local arrowFrame = _G[name .. "ExpandArrow"] or CreateFrame("Button", name .. "ExpandArrow", dropDownFrame)
	arrowFrame:Hide()
	arrowFrame:SetSize(16, 16)
	arrowFrame:SetPoint("RIGHT", dropDownFrame, 0, 0)
	arrowFrame:SetScript("OnMouseDown", DropDownExpandArrow_OnMouseDown)
	arrowFrame:SetScript("OnEnter", DropDownExpandArrow_OnEnter)
	arrowFrame:SetScript("OnLeave", DropDownExpandArrow_OnLeave)
	arrowFrame:SetScript("OnShow", function(self) colorSwatchFrame:SetPoint("RIGHT", self, "LEFT", -4, 0) end)
	arrowFrame:SetScript("OnHide", function() colorSwatchFrame:SetPoint("RIGHT", dropDownFrame, -6, 0) end)

	local arrowTexture = _G[arrowFrame:GetName() .. "ArrowTexture"] or arrowFrame:CreateTexture(arrowFrame:GetName() .. "ArrowTexture")
	arrowTexture:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	arrowTexture:SetAllPoints()
	arrowFrame:SetNormalTexture(arrowTexture)

	local invisibleButton = _G[name .. "InvisibleButton"] or CreateFrame("Button", name .. "InvisibleButton", dropDownFrame)
	dropDownFrame.invisibleButton = invisibleButton
	invisibleButton:Hide()
	invisibleButton:SetPoint("TOPLEFT")
	invisibleButton:SetPoint("BOTTOMLEFT")
	invisibleButton:SetPoint("RIGHT", colorSwatchFrame, "LEFT", 0, 0)
	invisibleButton:SetScript("OnEnter", lib.UIDropDownMenuButtonInvisibleButton_OnEnter)
	invisibleButton:SetScript("OnLeave", lib.UIDropDownMenuButtonInvisibleButton_OnLeave)

	dropDownFrame:SetScript("OnClick", lib.UIDropDownMenuButton_OnClick) -- blizzard creates a new function every time, is it necessary?
	dropDownFrame:SetScript("OnEnter", lib.UIDropDownMenuButton_OnEnter)
	dropDownFrame:SetScript("OnLeave", lib.UIDropDownMenuButton_OnLeave)
	dropDownFrame:SetScript("OnEnable", function(self) self.invisibleButton:Hide() end)
	dropDownFrame:SetScript("OnDisable", function(self) self.invisibleButton:Show() end)

	local text = _G[name .. "NormalText"] or dropDownFrame:CreateFontString(name .. "NormalText")
	dropDownFrame:SetFontString(text)
	text:SetPoint("LEFT", dropDownFrame, -5, 0)
	dropDownFrame:SetNormalFontObject("GameFontHighlightSmallLeft")
	dropDownFrame:SetHighlightFontObject("GameFontHighlightSmallLeft")
	dropDownFrame:SetDisabledFontObject("GameFontDisableSmallLeft")

	return dropDownFrame
end

-- UIDropDownMenuTemplates.xml
local function CreateDropDownList(name, parent)
	local dropDownListFrame = _G[name] or CreateFrame("Button", name, parent)
	dropDownListFrame:SetParent(parent)
	dropDownListFrame:Hide()
	dropDownListFrame:SetFrameStrata("DIALOG")
	dropDownListFrame:EnableMouse(true)
	dropDownListFrame:SetScript("OnClick", function(self, button, down) self:Hide() end)
	dropDownListFrame:SetScript("OnUpdate", lib.UIDropDownMenu_OnUpdate)
	dropDownListFrame:SetScript("OnShow", lib.UIDropDownMenu_OnShow)
	dropDownListFrame:SetScript("OnHide", lib.UIDropDownMenu_OnHide)
	dropDownListFrame:SetScript("OnEnter", lib.UIDropDownMenu_StopCounting)
	dropDownListFrame:SetScript("OnLeave", lib.UIDropDownMenu_StartCounting)

	local backdropFrame = _G[name .. "Backdrop"] or CreateFrame("Frame", name .. "Backdrop", dropDownListFrame, BackdropTemplateMixin and "BackdropTemplate")
	backdropFrame:SetParent(dropDownListFrame)
	backdropFrame:SetAllPoints()
	backdropFrame:SetBackdrop(BACKDROP_DROPDOWN)

	local menuBackdropFrame = _G[name .. "MenuBackdrop"] or CreateFrame("Frame", name .. "MenuBackdrop", dropDownListFrame, BackdropTemplateMixin and "BackdropTemplate")
	menuBackdropFrame:SetParent(dropDownListFrame)
	menuBackdropFrame:SetAllPoints()
	menuBackdropFrame:SetBackdrop(MENUBACKDROP_DROPDOWN)
	menuBackdropFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	menuBackdropFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)

	return dropDownListFrame
end

local function CreateDropDownMenu(name, parent)
	local dropDownMenu
	if type(name) == "table" then
		dropDownMenu = name
		name = dropDownMenu:GetName()
	else
		dropDownMenu = CreateFrame("Frame", name, parent)
	end
	dropDownMenu:SetWidth(40)
	dropDownMenu:SetHeight(32)

	local left = dropDownMenu:CreateTexture(name .. "Left", "ARTWORK")
	left:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	left:SetWidth(25)
	left:SetHeight(64)
	left:SetPoint("TOPLEFT", dropDownMenu, 0, 17)
	left:SetTexCoord(0, 0.1953125, 0, 1)

	local middle = dropDownMenu:CreateTexture(name .. "Middle", "ARTWORK")
	middle:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	middle:SetWidth(115)
	middle:SetHeight(64)
	middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)

	local right = dropDownMenu:CreateTexture(name .. "Right", "ARTWORK")
	right:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	right:SetWidth(25)
	right:SetHeight(64)
	right:SetPoint("LEFT", middle, "RIGHT", 0, 0)
	right:SetTexCoord(0.8046875, 1, 0, 1)

	local text = dropDownMenu:CreateFontString(name .. "Text", "ARTWORK", "GameFontHighlightSmall")
	dropDownMenu.Text = text
	text:SetWordWrap(false)
	text:SetJustifyH("RIGHT")
	text:SetWidth(0)
	text:SetHeight(10)
	text:SetPoint("RIGHT", right, -43, 2)

	local icon = dropDownMenu:CreateTexture(name .. "Icon", "OVERLAY")
	dropDownMenu.Icon = icon
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", dropDownMenu, 30, 2)
	icon:Hide()

	local button = CreateFrame("Button", name .. "Button", dropDownMenu)
	dropDownMenu.Button = button
	button:SetMotionScriptsWhileDisabled(true)
	button:SetSize(24, 24)
	button:SetPoint("TOPRIGHT", right, -16, -18)
	button:SetScript("OnEnter", function(self, motion)
		local parent = self:GetParent()
		local script = parent:GetScript("OnEnter")
		if script then
			script(parent)
		end
	end)
	button:SetScript("OnLeave", function(self, motion)
		local parent = self:GetParent()
		local script = parent:GetScript("OnLeave")
		if script then
			script(parent)
		end
	end)
	button:SetScript("OnClick", function(self, buttonName, down)
		lib.ToggleDropDownMenu(nil, nil, self:GetParent())
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
	Mixin(button, lib.HandlesGlobalMouseEventMixin)

	local buttonNormalTexture = button:CreateTexture(name .. "ButtonNormalTexture")
	buttonNormalTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	buttonNormalTexture:SetSize(24, 24)
	buttonNormalTexture:SetPoint("RIGHT", button, 0, 0)
	button:SetNormalTexture(buttonNormalTexture)

	local buttonPushedTexture = button:CreateTexture(name .. "ButtonPushedTexture")
	buttonPushedTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	buttonPushedTexture:SetSize(24, 24)
	buttonPushedTexture:SetPoint("RIGHT", button, 0, 0)
	button:SetPushedTexture(buttonPushedTexture)

	local buttonDisabledTexture = button:CreateTexture(name .. "ButtonDisabledTexture")
	buttonDisabledTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
	buttonDisabledTexture:SetSize(24, 24)
	buttonDisabledTexture:SetPoint("RIGHT", button, 0, 0)
	button:SetDisabledTexture(buttonDisabledTexture)

	local buttonHighlightTexture = button:CreateTexture(name .. "ButtonHighlightTexture")
	buttonHighlightTexture:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	buttonHighlightTexture:SetBlendMode("ADD")
	buttonHighlightTexture:SetSize(24, 24)
	buttonHighlightTexture:SetPoint("RIGHT", button, 0, 0)
	button:SetHighlightTexture(buttonHighlightTexture)

	dropDownMenu:SetScript("OnHide", function(self) lib.CloseDropDownMenus() end)

	return dropDownMenu
end

function lib.UIDropDownMenu_GetOrCreate(name, parent)
	if name and _G[name] then return _G[name] end
	return CreateDropDownMenu(name, parent)
end

function lib.UIDropDownMenu_Create(name, parent, ignoreNameConflict)
	if name and not ignoreNameConflict and _G[name] then
		error("Frame with name " .. name .. " already exists!")
	end
	return CreateDropDownMenu(name, parent)
end

------------------------------------------------------------------------
--- "Blizzard Code" but in lib form to prevent compatibility errors
------------------------------------------------------------------------
local UIDropDownMenuDelegate = CreateFrame("FRAME");

function lib.UIDropDownMenuDelegate_OnAttributeChanged(self, attribute, value)
	if (attribute == "createframes" and value == true) then
		lib.UIDropDownMenu_CreateFrames(self:GetAttribute("createframes-level"), self:GetAttribute("createframes-index"));
	elseif (attribute == "initmenu") then
		lib.UIDROPDOWNMENU_INIT_MENU = value;
	elseif (attribute == "openmenu") then
		lib.UIDROPDOWNMENU_OPEN_MENU = value;
		lib.UIDROPDOWNMENU_OPEN_MENU_ANCHOR = self:GetAttribute("anchorframe")
	end
end

UIDropDownMenuDelegate:SetScript("OnAttributeChanged", lib.UIDropDownMenuDelegate_OnAttributeChanged);

function lib.UIDropDownMenu_InitializeHelper(frame)
	-- This deals with the potentially tainted stuff!
	if (frame ~= lib.UIDROPDOWNMENU_OPEN_MENU) then
		lib.UIDROPDOWNMENU_MENU_LEVEL = 1;
	end

	-- Set the frame that's being intialized
	UIDropDownMenuDelegate:SetAttribute("initmenu", frame);

	-- Hide all the buttons
	local button, dropDownList;
	for i = 1, lib.UIDROPDOWNMENU_MAXLEVELS, 1 do
		dropDownList = _G[prefixDropDownList .. i];
		if (i >= lib.UIDROPDOWNMENU_MENU_LEVEL or frame ~= lib.UIDROPDOWNMENU_OPEN_MENU) then
			dropDownList.numButtons = 0;
			dropDownList.maxWidth = 0;
			for j = 1, lib.UIDROPDOWNMENU_MAXBUTTONS, 1 do
				button = _G[prefixDropDownList .. i .. "Button" .. j];
				button:Hide();
			end
			dropDownList:Hide();
		end
	end
	frame:SetHeight(lib.UIDROPDOWNMENU_BUTTON_HEIGHT * 2);
end

local function GetChild(frame, name, key)
	if (frame[key]) then
		return frame[key];
	elseif name then
		return _G[name .. key];
	end

	return nil;
end

function lib.UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList)
	frame.menuList = menuList;

	securecall(lib.UIDropDownMenu_InitializeHelper, frame);

	-- Set the initialize function and call it.  The initFunction populates the dropdown list.
	if (initFunction) then
		lib.UIDropDownMenu_SetInitializeFunction(frame, initFunction);
		initFunction(frame, level, frame.menuList);
	end

	--master frame
	if (level == nil) then
		level = 1;
	end

	local dropDownList = _G[prefixDropDownList .. level];
	dropDownList.dropdown = frame;
	dropDownList.shouldRefresh = true;

	lib.UIDropDownMenu_SetDisplayMode(frame, displayMode);
end

function lib.UIDropDownMenu_SetInitializeFunction(frame, initFunction)
	frame.initialize = initFunction;
end

function lib.UIDropDownMenu_SetDisplayMode(frame, displayMode)
	-- Change appearance based on the displayMode
	-- Note: this is a one time change based on previous behavior.
	if (displayMode == "MENU") then
		local name = frame:GetName();
		GetChild(frame, name, "Left"):Hide();
		GetChild(frame, name, "Middle"):Hide();
		GetChild(frame, name, "Right"):Hide();
		local button = GetChild(frame, name, "Button");
		local buttonName = button:GetName();
		GetChild(button, buttonName, "NormalTexture"):SetTexture(nil);
		GetChild(button, buttonName, "DisabledTexture"):SetTexture(nil);
		GetChild(button, buttonName, "PushedTexture"):SetTexture(nil);
		GetChild(button, buttonName, "HighlightTexture"):SetTexture(nil);
		local text = GetChild(frame, name, "Text");

		button:ClearAllPoints();
		button:SetPoint("LEFT", text, "LEFT", -9, 0);
		button:SetPoint("RIGHT", text, "RIGHT", 6, 0);
		frame.displayMode = "MENU";
	end
end

function lib.UIDropDownMenu_RefreshDropDownSize(self)
	self.maxWidth = lib.UIDropDownMenu_GetMaxButtonWidth(self);
	self:SetWidth(self.maxWidth + 25);

	for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS, 1 do
		local icon = _G[self:GetName() .. "Button" .. i .. "Icon"];

		if (icon.tFitDropDownSizeX) then
			icon:SetWidth(self.maxWidth - 5);
		end
	end
end

-- If dropdown is visible then see if its timer has expired, if so hide the frame
function lib.UIDropDownMenu_OnUpdate(self, elapsed)
	if (self.shouldRefresh) then
		lib.UIDropDownMenu_RefreshDropDownSize(self);
		self.shouldRefresh = false;
	end
end

function lib.UIDropDownMenuButtonInvisibleButton_OnEnter(self)
	lib.CloseDropDownMenus(self:GetParent():GetParent():GetID() + 1);
	local parent = self:GetParent();
	if (parent.tooltipTitle and parent.tooltipWhileDisabled) then
		if (parent.tooltipOnButton) then
			local tooltip = GetAppropriateTooltip();
			tooltip:SetOwner(parent, "ANCHOR_RIGHT");
			GameTooltip_SetTitle(tooltip, parent.tooltipTitle);
			if parent.tooltipInstruction then
				GameTooltip_AddInstructionLine(tooltip, parent.tooltipInstruction);
			end
			if parent.tooltipText then
				GameTooltip_AddNormalLine(tooltip, parent.tooltipText, true);
			end
			if parent.tooltipWarning then
				GameTooltip_AddColoredLine(tooltip, parent.tooltipWarning, RED_FONT_COLOR, true);
			end
			tooltip:Show();
		end
	end
end

function lib.UIDropDownMenuButtonInvisibleButton_OnLeave(self)
	lib.UIDropDownMenu_StartCounting(self:GetParent():GetParent());
	GetAppropriateTooltip():Hide();
end

function lib.UIDropDownMenuButton_OnEnter(self)
	if (self.hasArrow) then
		local level = self:GetParent():GetID() + 1;
		local listFrame = _G[prefixDropDownList .. level];
		if (not listFrame or not listFrame:IsShown() or select(2, listFrame:GetPoint()) ~= self) then
			lib.ToggleDropDownMenu(self:GetParent():GetID() + 1, self.value, nil, nil, nil, nil, self.menuList, self);
		end
	else
		lib.CloseDropDownMenus(self:GetParent():GetID() + 1);
	end
	self.Highlight:Show();
	lib.UIDropDownMenu_StopCounting(self:GetParent());
	if (self.tooltipTitle and not self.noTooltipWhileEnabled) then
		if (self.tooltipOnButton) then
			local tooltip = GetAppropriateTooltip();
			tooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip_SetTitle(tooltip, self.tooltipTitle);
			if self.tooltipText then
				GameTooltip_AddNormalLine(tooltip, self.tooltipText, true);
			end
			tooltip:Show();
		end
	end

	if (self.mouseOverIcon ~= nil) then
		self.Icon:SetTexture(self.mouseOverIcon);
		self.Icon:Show();
	end

	if GetValueOrCallFunction then
		GetValueOrCallFunction(self, "funcOnEnter", self);
	end
end

function lib.UIDropDownMenuButton_OnLeave(self)
	self.Highlight:Hide();
	lib.UIDropDownMenu_StartCounting(self:GetParent());
	GetAppropriateTooltip():Hide();

	if (self.mouseOverIcon ~= nil) then
		if (self.icon ~= nil) then
			self.Icon:SetTexture(self.icon);
		else
			self.Icon:Hide();
		end
	end

	if GetValueOrCallFunction then
		GetValueOrCallFunction(self, "funcOnLeave", self);
	end
end

--[[
List of button attributes
======================================================
info.text = [STRING]  --  The text of the button
info.value = [ANYTHING]  --  The value that UIDROPDOWNMENU_MENU_VALUE is set to when the button is clicked
info.func = [function()]  --  The function that is called when you click the button
info.checked = [nil, true, function]  --  Check the button if true or function returns true
info.isNotRadio = [nil, true]  --  Check the button uses radial image if false check box image if true
info.isTitle = [nil, true]  --  If it's a title the button is disabled and the font color is set to yellow
info.disabled = [nil, true]  --  Disable the button and show an invisible button that still traps the mouseover event so menu doesn't time out
info.tooltipWhileDisabled = [nil, 1] -- Show the tooltip, even when the button is disabled.
info.hasArrow = [nil, true]  --  Show the expand arrow for multilevel menus
info.hasColorSwatch = [nil, true]  --  Show color swatch or not, for color selection
info.r = [1 - 255]  --  Red color value of the color swatch
info.g = [1 - 255]  --  Green color value of the color swatch
info.b = [1 - 255]  --  Blue color value of the color swatch
info.colorCode = [STRING] -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
info.swatchFunc = [function()]  --  Function called by the color picker on color change
info.hasOpacity = [nil, 1]  --  Show the opacity slider on the colorpicker frame
info.opacity = [0.0 - 1.0]  --  Percentatge of the opacity, 1.0 is fully shown, 0 is transparent
info.opacityFunc = [function()]  --  Function called by the opacity slider when you change its value
info.cancelFunc = [function(previousValues)] -- Function called by the colorpicker when you click the cancel button (it takes the previous values as its argument)
info.notClickable = [nil, 1]  --  Disable the button and color the font white
info.notCheckable = [nil, 1]  --  Shrink the size of the buttons and don't display a check box
info.owner = [Frame]  --  Dropdown frame that "owns" the current dropdownlist
info.keepShownOnClick = [nil, 1]  --  Don't hide the dropdownlist after a button is clicked
info.tooltipTitle = [nil, STRING] -- Title of the tooltip shown on mouseover
info.tooltipText = [nil, STRING] -- Text of the tooltip shown on mouseover
info.tooltipOnButton = [nil, 1] -- Show the tooltip attached to the button instead of as a Newbie tooltip.
info.justifyH = [nil, "CENTER"] -- Justify button text
info.arg1 = [ANYTHING] -- This is the first argument used by info.func
info.arg2 = [ANYTHING] -- This is the second argument used by info.func
info.fontObject = [FONT] -- font object replacement for Normal and Highlight
info.menuTable = [TABLE] -- This contains an array of info tables to be displayed as a child menu
info.noClickSound = [nil, 1]  --  Set to 1 to suppress the sound when clicking the button. The sound only plays if .func is set.
info.padding = [nil, NUMBER] -- Number of pixels to pad the text on the right side
info.leftPadding = [nil, NUMBER] -- Number of pixels to pad the button on the left side
info.minWidth = [nil, NUMBER] -- Minimum width for this line
info.customFrame = frame -- Allows this button to be a completely custom frame, should inherit from UIDropDownCustomMenuEntryTemplate and override appropriate methods.
info.icon = [TEXTURE] -- An icon for the button.
info.mouseOverIcon = [TEXTURE] -- An override icon when a button is moused over.
info.ignoreAsMenuSelection [nil, true] -- Never set the menu text/icon to this, even when this button is checked
]]

function lib.UIDropDownMenu_CreateInfo()
	return {};
end

function lib.UIDropDownMenu_CreateFrames(level, index)
	while (level > lib.UIDROPDOWNMENU_MAXLEVELS) do
		lib.UIDROPDOWNMENU_MAXLEVELS = lib.UIDROPDOWNMENU_MAXLEVELS + 1;
		local newList = CreateDropDownList(prefixDropDownList .. lib.UIDROPDOWNMENU_MAXLEVELS); --CreateFrame("Button", prefix .. "DropDownList" .. lib.UIDROPDOWNMENU_MAXLEVELS, nil, "UIDropDownListTemplate");
		newList:SetFrameStrata("FULLSCREEN_DIALOG");
		newList:SetToplevel(true);
		newList:Hide();
		newList:SetID(lib.UIDROPDOWNMENU_MAXLEVELS);
		newList:SetWidth(180)
		newList:SetHeight(10)
		for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
			local newButton = CreateDropDownMenuButton(
					prefixDropDownList .. lib.UIDROPDOWNMENU_MAXLEVELS .. "Button" .. i,
					newList
			);
			newButton:SetID(i);
		end
	end

	while (index > lib.UIDROPDOWNMENU_MAXBUTTONS) do
		lib.UIDROPDOWNMENU_MAXBUTTONS = lib.UIDROPDOWNMENU_MAXBUTTONS + 1;
		for i = 1, lib.UIDROPDOWNMENU_MAXLEVELS do
			local newButton = CreateDropDownMenuButton(
					prefixDropDownList .. i .. "Button" .. lib.UIDROPDOWNMENU_MAXBUTTONS,
					_G[prefixDropDownList .. i]
			);
			newButton:SetID(lib.UIDROPDOWNMENU_MAXBUTTONS);
		end
	end
end

function lib.UIDropDownMenu_AddSeparator(level)
	local separatorInfo = {
		hasArrow = false;
		dist = 0;
		isTitle = true;
		isUninteractable = true;
		notCheckable = true;
		iconOnly = true;
		icon = "Interface\\Common\\UI-TooltipDivider-Transparent";
		tCoordLeft = 0;
		tCoordRight = 1;
		tCoordTop = 0;
		tCoordBottom = 1;
		tSizeX = 0;
		tSizeY = 8;
		tFitDropDownSizeX = true;
		iconInfo = {
			tCoordLeft = 0,
			tCoordRight = 1,
			tCoordTop = 0,
			tCoordBottom = 1,
			tSizeX = 0,
			tSizeY = 8,
			tFitDropDownSizeX = true
		},
	};

	lib.UIDropDownMenu_AddButton(separatorInfo, level);
end

function lib.UIDropDownMenu_AddSpace(level)
	local spaceInfo = {
		hasArrow = false,
		dist = 0,
		isTitle = true,
		isUninteractable = true,
		notCheckable = true,
	};

	lib.UIDropDownMenu_AddButton(spaceInfo, level);
end

function lib.UIDropDownMenu_AddButton(info, level)
	--[[
	Might to uncomment this if there are performance issues
	if ( not UIDROPDOWNMENU_OPEN_MENU ) then
		return;
	end
	]]
	if (not level) then
		level = 1;
	end

	local listFrame = _G[prefixDropDownList .. level];
	local index = listFrame and (listFrame.numButtons + 1) or 1;
	local width;

	UIDropDownMenuDelegate:SetAttribute("createframes-level", level);
	UIDropDownMenuDelegate:SetAttribute("createframes-index", index);
	UIDropDownMenuDelegate:SetAttribute("createframes", true);

	listFrame = listFrame or _G[prefixDropDownList .. level];
	local listFrameName = listFrame:GetName();

	-- Set the number of buttons in the listframe
	listFrame.numButtons = index;

	local button = _G[listFrameName .. "Button" .. index];
	local normalText = _G[button:GetName() .. "NormalText"];
	local icon = _G[button:GetName() .. "Icon"];
	-- This button is used to capture the mouse OnEnter/OnLeave events if the dropdown button is disabled, since a disabled button doesn't receive any events
	-- This is used specifically for drop down menu time outs
	local invisibleButton = _G[button:GetName() .. "InvisibleButton"];

	-- Default settings
	button:SetDisabledFontObject(GameFontDisableSmallLeft);
	invisibleButton:Hide();
	button:Enable();

	-- If not clickable then disable the button and set it white
	if (info.notClickable) then
		info.disabled = true;
		button:SetDisabledFontObject(GameFontHighlightSmallLeft);
	end

	-- Set the text color and disable it if its a title
	if (info.isTitle) then
		info.disabled = true;
		button:SetDisabledFontObject(GameFontNormalSmallLeft);
	end

	-- Disable the button if disabled and turn off the color code
	if (info.disabled) then
		button:Disable();
		invisibleButton:Show();
		info.colorCode = nil;
	end

	-- If there is a color for a disabled line, set it
	if (info.disablecolor) then
		info.colorCode = info.disablecolor;
	end

	-- Configure button
	if (info.text) then
		-- look for inline color code this is only if the button is enabled
		if (info.colorCode) then
			button:SetText(info.colorCode .. info.text .. "|r");
		else
			button:SetText(info.text);
		end

		-- Set icon
		if (info.icon or info.mouseOverIcon) then
			icon:SetSize(16, 16);
			icon:SetTexture(info.icon);
			icon:ClearAllPoints();
			icon:SetPoint("RIGHT");

			if (info.tCoordLeft) then
				icon:SetTexCoord(info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom);
			else
				icon:SetTexCoord(0, 1, 0, 1);
			end
			icon:Show();
		else
			icon:Hide();
		end

		-- Check to see if there is a replacement font
		if (info.fontObject) then
			button:SetNormalFontObject(info.fontObject);
			button:SetHighlightFontObject(info.fontObject);
		else
			button:SetNormalFontObject(GameFontHighlightSmallLeft);
			button:SetHighlightFontObject(GameFontHighlightSmallLeft);
		end
	else
		button:SetText("");
		icon:Hide();
	end

	button.iconOnly = nil;
	button.icon = nil;
	button.iconInfo = nil;

	if (info.iconInfo) then
		icon.tFitDropDownSizeX = info.iconInfo.tFitDropDownSizeX;
	else
		icon.tFitDropDownSizeX = nil;
	end
	if (info.iconOnly and info.icon) then
		button.iconOnly = true;
		button.icon = info.icon;
		button.iconInfo = info.iconInfo;

		lib.UIDropDownMenu_SetIconImage(icon, info.icon, info.iconInfo);
		icon:ClearAllPoints();
		icon:SetPoint("LEFT");
	end

	-- Pass through attributes
	button.func = info.func;
	button.funcOnEnter = info.funcOnEnter;
	button.funcOnLeave = info.funcOnLeave;
	button.owner = info.owner;
	button.hasOpacity = info.hasOpacity;
	button.opacity = info.opacity;
	button.opacityFunc = info.opacityFunc;
	button.cancelFunc = info.cancelFunc;
	button.swatchFunc = info.swatchFunc;
	button.keepShownOnClick = info.keepShownOnClick;
	button.tooltipTitle = info.tooltipTitle;
	button.tooltipText = info.tooltipText;
	button.tooltipInstruction = info.tooltipInstruction;
	button.tooltipWarning = info.tooltipWarning;
	button.arg1 = info.arg1;
	button.arg2 = info.arg2;
	button.hasArrow = info.hasArrow;
	button.hasColorSwatch = info.hasColorSwatch;
	button.notCheckable = info.notCheckable;
	button.menuList = info.menuList;
	button.tooltipWhileDisabled = info.tooltipWhileDisabled;
	button.noTooltipWhileEnabled = info.noTooltipWhileEnabled;
	button.tooltipOnButton = info.tooltipOnButton;
	button.noClickSound = info.noClickSound;
	button.padding = info.padding;
	button.icon = info.icon;
	button.mouseOverIcon = info.mouseOverIcon;
	button.ignoreAsMenuSelection = info.ignoreAsMenuSelection;

	if (info.value) then
		button.value = info.value;
	elseif (info.text) then
		button.value = info.text;
	else
		button.value = nil;
	end

	local expandArrow = _G[listFrameName .. "Button" .. index .. "ExpandArrow"];
	expandArrow:SetShown(info.hasArrow);
	expandArrow:SetEnabled(not info.disabled);

	-- If not checkable move everything over to the left to fill in the gap where the check would be
	local xPos = 5;
	local previousButton = _G[listFrameName .. "Button" .. (index - 1)];
	local yPos
	if (previousButton and previousButton.yPos) then
		yPos = previousButton.yPos - previousButton:GetHeight();
	else
		yPos = -lib.UIDROPDOWNMENU_BORDER_HEIGHT;
	end
	local displayInfo = normalText;
	if (info.iconOnly) then
		displayInfo = icon;
	end

	displayInfo:ClearAllPoints();
	if (info.notCheckable) then
		if (info.justifyH and info.justifyH == "CENTER") then
			displayInfo:SetPoint("CENTER", button, "CENTER", -7, 0);
		else
			displayInfo:SetPoint("LEFT", button, "LEFT", 0, 0);
		end
		xPos = xPos + 10;

	else
		xPos = xPos + 12;
		displayInfo:SetPoint("LEFT", button, "LEFT", 20, 0);
	end

	-- Adjust offset if displayMode is menu
	local frame = lib.UIDROPDOWNMENU_OPEN_MENU;
	if (frame and frame.displayMode == "MENU") then
		if (not info.notCheckable) then
			xPos = xPos - lib.UIDROPDOWNMENU_DISPLAY_MODE_MENU_CHECKBOX_OFFSET;
		end
	end

	-- If no open frame then set the frame to the currently initialized frame
	frame = frame or lib.UIDROPDOWNMENU_INIT_MENU;

	if (info.leftPadding) then
		xPos = xPos + info.leftPadding;
	end
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", xPos, yPos);
	button.yPos = yPos

	-- See if button is selected by id or name
	if (frame) then
		if (lib.UIDropDownMenu_GetSelectedName(frame)) then
			if (button:GetText() == lib.UIDropDownMenu_GetSelectedName(frame)) then
				info.checked = 1;
			end
		elseif (lib.UIDropDownMenu_GetSelectedID(frame)) then
			if (button:GetID() == lib.UIDropDownMenu_GetSelectedID(frame)) then
				info.checked = 1;
			end
		elseif (lib.UIDropDownMenu_GetSelectedValue(frame)) then
			if (button.value == lib.UIDropDownMenu_GetSelectedValue(frame)) then
				info.checked = 1;
			end
		end
	end

	if not info.notCheckable then
		local check = _G[listFrameName .. "Button" .. index .. "Check"];
		local uncheck = _G[listFrameName .. "Button" .. index .. "UnCheck"];
		if (info.disabled) then
			check:SetDesaturated(true);
			check:SetAlpha(0.5);
			uncheck:SetDesaturated(true);
			uncheck:SetAlpha(0.5);
		else
			check:SetDesaturated(false);
			check:SetAlpha(1);
			uncheck:SetDesaturated(false);
			uncheck:SetAlpha(1);
		end

		if info.customCheckIconAtlas or info.customCheckIconTexture then
			check:SetTexCoord(0, 1, 0, 1);
			uncheck:SetTexCoord(0, 1, 0, 1);

			if info.customCheckIconAtlas then
				check:SetAtlas(info.customCheckIconAtlas);
				uncheck:SetAtlas(info.customUncheckIconAtlas or info.customCheckIconAtlas);
			else
				check:SetTexture(info.customCheckIconTexture);
				uncheck:SetTexture(info.customUncheckIconTexture or info.customCheckIconTexture);
			end
		elseif info.isNotRadio then
			check:SetTexCoord(0.0, 0.5, 0.0, 0.5);
			check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
			uncheck:SetTexCoord(0.5, 1.0, 0.0, 0.5);
			uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
		else
			check:SetTexCoord(0.0, 0.5, 0.5, 1.0);
			check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
			uncheck:SetTexCoord(0.5, 1.0, 0.5, 1.0);
			uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
		end

		-- Checked can be a function now
		local checked = info.checked;
		if (type(checked) == "function") then
			checked = checked(button);
		end

		-- Show the check if checked
		if (checked) then
			button:LockHighlight();
			check:Show();
			uncheck:Hide();
		else
			button:UnlockHighlight();
			check:Hide();
			uncheck:Show();
		end
	else
		_G[listFrameName .. "Button" .. index .. "Check"]:Hide();
		_G[listFrameName .. "Button" .. index .. "UnCheck"]:Hide();
	end
	button.checked = info.checked;

	-- If has a colorswatch, show it and vertex color it
	local colorSwatch = _G[listFrameName .. "Button" .. index .. "ColorSwatch"];
	if (info.hasColorSwatch) then
		_G[prefixDropDownList .. level .. "Button" .. index .. "ColorSwatch"].Color:SetVertexColor(info.r, info.g, info.b);
		button.r = info.r;
		button.g = info.g;
		button.b = info.b;
		colorSwatch:Show();
	else
		colorSwatch:Hide();
	end

	lib.UIDropDownMenu_CheckAddCustomFrame(listFrame, button, info);

	button:SetShown(button.customFrame == nil);

	button.minWidth = info.minWidth;

	width = max(lib.UIDropDownMenu_GetButtonWidth(button), info.minWidth or 0);
	--Set maximum button width
	if (width > listFrame.maxWidth) then
		listFrame.maxWidth = width;
	end

	if (button.customFrame) then
		button:SetHeight(button.customFrame:GetPreferredEntryHeight())
	else
		button:SetHeight(lib.UIDROPDOWNMENU_BUTTON_HEIGHT)
	end

	local height = (-yPos) + button:GetHeight() + lib.UIDROPDOWNMENU_BORDER_HEIGHT

	-- Set the height of the listframe
	listFrame:SetHeight(height);

	return button
end

function lib.UIDropDownMenu_CheckAddCustomFrame(self, button, info)
	local customFrame = info.customFrame;
	button.customFrame = customFrame;
	if customFrame then
		customFrame:SetOwningButton(button);
		customFrame:ClearAllPoints();
		customFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
		customFrame:Show();

		lib.UIDropDownMenu_RegisterCustomFrame(self, customFrame);
	end
end

function lib.UIDropDownMenu_RegisterCustomFrame(self, customFrame)
	self.customFrames = self.customFrames or {}
	table.insert(self.customFrames, customFrame);
end

function lib.UIDropDownMenu_GetMaxButtonWidth(self)
	local maxWidth = 0;
	for i = 1, self.numButtons do
		local button = _G[self:GetName() .. "Button" .. i];
		local width = lib.UIDropDownMenu_GetButtonWidth(button);
		if (width > maxWidth) then
			maxWidth = width;
		end
	end
	return maxWidth;
end

function lib.UIDropDownMenu_GetButtonWidth(button)
	local minWidth = button.minWidth or 0;
	if button.customFrame and button.customFrame:IsShown() then
		return math.max(minWidth, button.customFrame:GetPreferredEntryWidth());
	end

	if not button:IsShown() then
		return 0;
	end

	local width;
	local buttonName = button:GetName();
	local icon = _G[buttonName .. "Icon"];
	local normalText = _G[buttonName .. "NormalText"];

	if (button.iconOnly and icon) then
		width = icon:GetWidth();
	elseif (normalText and normalText:GetText()) then
		width = normalText:GetWidth() + 40;

		if (button.icon) then
			-- Add padding for the icon
			width = width + 10;
		end
	else
		return minWidth;
	end

	-- Add padding if has and expand arrow or color swatch
	if (button.hasArrow) then
		width = width + 16;
	end
	if button.hasColorSwatch then
		width = width + 20;
	end
	if (button.notCheckable) then
		width = width - 30;
	end
	if (button.padding) then
		width = width + button.padding;
	end

	return math.max(minWidth, width);
end

function lib.UIDropDownMenu_Refresh(frame, useValue, dropdownLevel)
	local maxWidth = 0;
	local somethingChecked = nil;
	if (not dropdownLevel) then
		dropdownLevel = lib.UIDROPDOWNMENU_MENU_LEVEL;
	end

	local listFrame = _G[prefixDropDownList .. dropdownLevel];
	listFrame.numButtons = listFrame.numButtons or 0;
	-- Just redraws the existing menu
	for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
		local button = _G[prefixDropDownList .. dropdownLevel .. "Button" .. i];
		local checked = nil;

		if (i <= listFrame.numButtons) then
			-- See if checked or not
			if (lib.UIDropDownMenu_GetSelectedName(frame)) then
				if (button:GetText() == lib.UIDropDownMenu_GetSelectedName(frame)) then
					checked = 1;
				end
			elseif (lib.UIDropDownMenu_GetSelectedID(frame)) then
				if (button:GetID() == lib.UIDropDownMenu_GetSelectedID(frame)) then
					checked = 1;
				end
			elseif (lib.UIDropDownMenu_GetSelectedValue(frame)) then
				if (button.value == lib.UIDropDownMenu_GetSelectedValue(frame)) then
					checked = 1;
				end
			end
		end
		if (button.checked and type(button.checked) == "function") then
			checked = button.checked(button);
		end

		if not button.notCheckable and button:IsShown() then
			-- If checked show check image
			local checkImage = _G[prefixDropDownList .. dropdownLevel .. "Button" .. i .. "Check"];
			local uncheckImage = _G[prefixDropDownList .. dropdownLevel .. "Button" .. i .. "UnCheck"];
			if (checked) then
				if not button.ignoreAsMenuSelection then
					somethingChecked = true;
					local icon = GetChild(frame, frame:GetName(), "Icon");
					if (button.iconOnly and icon and button.icon) then
						lib.UIDropDownMenu_SetIconImage(icon, button.icon, button.iconInfo);
					elseif (useValue) then
						lib.UIDropDownMenu_SetText(frame, button.value);
						icon:Hide();
					else
						lib.UIDropDownMenu_SetText(frame, button:GetText());
						icon:Hide();
					end
				end
				button:LockHighlight();
				checkImage:Show();
				uncheckImage:Hide();
			else
				button:UnlockHighlight();
				checkImage:Hide();
				uncheckImage:Show();
			end
		end

		if (button:IsShown()) then
			local width = lib.UIDropDownMenu_GetButtonWidth(button);
			if (width > maxWidth) then
				maxWidth = width;
			end
		end
	end
	if (somethingChecked == nil) then
		lib.UIDropDownMenu_SetText(frame, VIDEO_QUALITY_LABEL6);
		local icon = GetChild(frame, frame:GetName(), "Icon");
		icon:Hide();
	end
	if (not frame.noResize) then
		for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
			local button = _G[prefixDropDownList .. dropdownLevel .. "Button" .. i];
			button:SetWidth(maxWidth);
		end
		lib.UIDropDownMenu_RefreshDropDownSize(_G[prefixDropDownList .. dropdownLevel]);
	end
end

function lib.UIDropDownMenu_RefreshAll(frame, useValue)
	for dropdownLevel = lib.UIDROPDOWNMENU_MENU_LEVEL, 2, -1 do
		local listFrame = _G[prefixDropDownList .. dropdownLevel];
		if (listFrame:IsShown()) then
			lib.UIDropDownMenu_Refresh(frame, nil, dropdownLevel);
		end
	end
	-- useValue is the text on the dropdown, only needs to be set once
	lib.UIDropDownMenu_Refresh(frame, useValue, 1);
end

function lib.UIDropDownMenu_SetIconImage(icon, texture, info)
	icon:SetTexture(texture);
	if (info.tCoordLeft) then
		icon:SetTexCoord(info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom);
	else
		icon:SetTexCoord(0, 1, 0, 1);
	end
	if (info.tSizeX) then
		icon:SetWidth(info.tSizeX);
	else
		icon:SetWidth(16);
	end
	if (info.tSizeY) then
		icon:SetHeight(info.tSizeY);
	else
		icon:SetHeight(16);
	end
	icon:Show();
end

function lib.UIDropDownMenu_SetSelectedName(frame, name, useValue)
	frame.selectedName = name;
	frame.selectedID = nil;
	frame.selectedValue = nil;
	lib.UIDropDownMenu_Refresh(frame, useValue);
end

function lib.UIDropDownMenu_SetSelectedValue(frame, value, useValue)
	-- useValue will set the value as the text, not the name
	frame.selectedName = nil;
	frame.selectedID = nil;
	frame.selectedValue = value;
	lib.UIDropDownMenu_Refresh(frame, useValue);
end

function lib.UIDropDownMenu_SetSelectedID(frame, id, useValue)
	frame.selectedID = id;
	frame.selectedName = nil;
	frame.selectedValue = nil;
	lib.UIDropDownMenu_Refresh(frame, useValue);
end

function lib.UIDropDownMenu_GetSelectedName(frame)
	return frame.selectedName;
end

function lib.UIDropDownMenu_GetSelectedID(frame)
	if (frame.selectedID) then
		return frame.selectedID;
	else
		-- If no explicit selectedID then try to send the id of a selected value or name
		local listFrame = _G[prefixDropDownList .. lib.UIDROPDOWNMENU_MENU_LEVEL];
		for i = 1, listFrame.numButtons do
			local button = _G[prefixDropDownList .. lib.UIDROPDOWNMENU_MENU_LEVEL .. "Button" .. i];
			-- See if checked or not
			if (lib.UIDropDownMenu_GetSelectedName(frame)) then
				if (button:GetText() == lib.UIDropDownMenu_GetSelectedName(frame)) then
					return i;
				end
			elseif (lib.UIDropDownMenu_GetSelectedValue(frame)) then
				if (button.value == lib.UIDropDownMenu_GetSelectedValue(frame)) then
					return i;
				end
			end
		end
	end
end

function lib.UIDropDownMenu_GetSelectedValue(frame)
	return frame.selectedValue;
end

function lib.UIDropDownMenuButton_OnClick(self)
	local checked = self.checked;
	if (type(checked) == "function") then
		checked = checked(self);
	end

	if (self.keepShownOnClick) then
		if not self.notCheckable then
			if (checked) then
				_G[self:GetName() .. "Check"]:Hide();
				_G[self:GetName() .. "UnCheck"]:Show();
				checked = false;
			else
				_G[self:GetName() .. "Check"]:Show();
				_G[self:GetName() .. "UnCheck"]:Hide();
				checked = true;
			end
		end
	else
		self:GetParent():Hide();
	end

	if (type(self.checked) ~= "function") then
		self.checked = checked;
	end

	-- saving this here because func might use a dropdown, changing this self's attributes
	local playSound = true;
	if (self.noClickSound) then
		playSound = false;
	end

	local func = self.func;
	if (func) then
		func(self, self.arg1, self.arg2, checked);
	else
		return ;
	end

	if (playSound) then
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
	end
end

function lib.HideDropDownMenu(level)
	local listFrame = _G[prefixDropDownList .. level];
	listFrame:Hide();
end

function lib.ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
	if (not level) then
		level = 1;
	end
	UIDropDownMenuDelegate:SetAttribute("createframes-level", level);
	UIDropDownMenuDelegate:SetAttribute("createframes-index", 0);
	UIDropDownMenuDelegate:SetAttribute("createframes", true);
	lib.UIDROPDOWNMENU_MENU_LEVEL = level;
	lib.UIDROPDOWNMENU_MENU_VALUE = value;
	local listFrameName = prefixDropDownList .. level;
	local listFrame = _G[listFrameName];
	lib.UIDropDownMenu_ClearCustomFrames(listFrame);

	local tempFrame;
	local point, relativePoint, relativeTo;
	if (not dropDownFrame) then
		tempFrame = button:GetParent();
	else
		tempFrame = dropDownFrame;
	end
	if (listFrame:IsShown() and (lib.UIDROPDOWNMENU_OPEN_MENU == tempFrame)) then
		listFrame:Hide();
	else
		-- Set the dropdownframe scale
		local uiScale;
		local uiParentScale = UIParent:GetScale();
		if (GetCVar("useUIScale") == "1") then
			uiScale = tonumber(GetCVar("uiscale"));
			if (uiParentScale < uiScale) then
				uiScale = uiParentScale;
			end
		else
			uiScale = uiParentScale;
		end
		listFrame:SetScale(uiScale);

		-- Hide the listframe anyways since it is redrawn OnShow()
		listFrame:Hide();

		-- Frame to anchor the dropdown menu to
		local anchorFrame;

		-- Display stuff
		-- Level specific stuff
		if (level == 1) then
			UIDropDownMenuDelegate:SetAttribute("anchorframe", anchorName);
			UIDropDownMenuDelegate:SetAttribute("openmenu", dropDownFrame);
			listFrame:ClearAllPoints();
			-- If there's no specified anchorName then use left side of the dropdown menu
			if (not anchorName) then
				-- See if the anchor was set manually using setanchor
				if (dropDownFrame.xOffset) then
					xOffset = dropDownFrame.xOffset;
				end
				if (dropDownFrame.yOffset) then
					yOffset = dropDownFrame.yOffset;
				end
				if (dropDownFrame.point) then
					point = dropDownFrame.point;
				end
				if (dropDownFrame.relativeTo) then
					relativeTo = dropDownFrame.relativeTo;
				else
					relativeTo = GetChild(lib.UIDROPDOWNMENU_OPEN_MENU, lib.UIDROPDOWNMENU_OPEN_MENU:GetName(), "Left");
				end
				if (dropDownFrame.relativePoint) then
					relativePoint = dropDownFrame.relativePoint;
				end
			elseif (anchorName == "cursor") then
				relativeTo = nil;
				local cursorX, cursorY = GetCursorPosition();
				cursorX = cursorX / uiScale;
				cursorY = cursorY / uiScale;

				if (not xOffset) then
					xOffset = 0;
				end
				if (not yOffset) then
					yOffset = 0;
				end
				xOffset = cursorX + xOffset;
				yOffset = cursorY + yOffset;
			else
				-- See if the anchor was set manually using setanchor
				if (dropDownFrame.xOffset) then
					xOffset = dropDownFrame.xOffset;
				end
				if (dropDownFrame.yOffset) then
					yOffset = dropDownFrame.yOffset;
				end
				if (dropDownFrame.point) then
					point = dropDownFrame.point;
				end
				if (dropDownFrame.relativeTo) then
					relativeTo = dropDownFrame.relativeTo;
				else
					relativeTo = anchorName;
				end
				if (dropDownFrame.relativePoint) then
					relativePoint = dropDownFrame.relativePoint;
				end
			end
			if (not xOffset or not yOffset) then
				xOffset = 8;
				yOffset = 22;
			end
			if (not point) then
				point = "TOPLEFT";
			end
			if (not relativePoint) then
				relativePoint = "BOTTOMLEFT";
			end
			listFrame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset);
		else
			if (not dropDownFrame) then
				dropDownFrame = lib.UIDROPDOWNMENU_OPEN_MENU;
			end
			listFrame:ClearAllPoints();
			-- If this is a dropdown button, not the arrow anchor it to itself
			if (strmatch(button:GetParent():GetName(), prefixDropDownListButtonRegex)) then
				anchorFrame = button;
			else
				anchorFrame = button:GetParent();
			end
			point = "TOPLEFT";
			relativePoint = "TOPRIGHT";
			listFrame:SetPoint(point, anchorFrame, relativePoint, 0, 0);
		end

		-- Change list box appearance depending on display mode
		if (dropDownFrame and dropDownFrame.displayMode == "MENU") then
			_G[listFrameName .. "Backdrop"]:Hide();
			_G[listFrameName .. "MenuBackdrop"]:Show();
		else
			_G[listFrameName .. "Backdrop"]:Show();
			_G[listFrameName .. "MenuBackdrop"]:Hide();
		end
		dropDownFrame.menuList = menuList;
		lib.UIDropDownMenu_Initialize(dropDownFrame, dropDownFrame.initialize, nil, level, menuList);
		-- If no items in the drop down don't show it
		if (listFrame.numButtons == 0) then
			return ;
		end

		listFrame.onShow = dropDownFrame.listFrameOnShow;

		-- Check to see if the dropdownlist is off the screen, if it is anchor it to the top of the dropdown button
		listFrame:Show();
		-- Hack since GetCenter() is returning coords relative to 1024x768
		local x, y = listFrame:GetCenter();
		-- Hack will fix this in next revision of dropdowns
		if (not x or not y) then
			listFrame:Hide();
			return ;
		end

		listFrame.onHide = dropDownFrame.onHide;

		--  We just move level 1 enough to keep it on the screen. We don't necessarily change the anchors.
		if (level == 1) then
			listFrame:ClearAllPoints();
			listFrame:SetClampedToScreen(true)
			listFrame:SetClampRectInsets(-4, 4, 4, -4)
			if (anchorName == "cursor") then
				listFrame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset);
			else
				listFrame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset);
			end
		else
			-- Determine whether the menu is off the screen or not
			local offscreenY, offscreenX;
			if ((y - listFrame:GetHeight() / 2) < 0) then
				offscreenY = 1;
			end
			if (listFrame:GetRight() > GetScreenWidth()) then
				offscreenX = 1;
			end
			if (offscreenY and offscreenX) then
				point = gsub(point, "TOP(.*)", "BOTTOM%1");
				point = gsub(point, "(.*)LEFT", "%1RIGHT");
				relativePoint = gsub(relativePoint, "TOP(.*)", "BOTTOM%1");
				relativePoint = gsub(relativePoint, "(.*)RIGHT", "%1LEFT");
				xOffset = -11;
				yOffset = -14;
			elseif (offscreenY) then
				point = gsub(point, "TOP(.*)", "BOTTOM%1");
				relativePoint = gsub(relativePoint, "TOP(.*)", "BOTTOM%1");
				xOffset = 0;
				yOffset = -14;
			elseif (offscreenX) then
				point = gsub(point, "(.*)LEFT", "%1RIGHT");
				relativePoint = gsub(relativePoint, "(.*)RIGHT", "%1LEFT");
				xOffset = -11;
				yOffset = 14;
			else
				xOffset = 0;
				yOffset = 14;
			end

			listFrame:ClearAllPoints();
			listFrame.parentLevel = tonumber(strmatch(anchorFrame:GetName(), prefixDropDownList .. "(%d+)"));
			listFrame.parentID = anchorFrame:GetID();
			listFrame:SetPoint(point, anchorFrame, relativePoint, xOffset, yOffset);
		end

		if (autoHideDelay and tonumber(autoHideDelay)) then
			listFrame.showTimer = autoHideDelay;
			listFrame.isCounting = 1;
		end
	end
end

function lib.CloseDropDownMenus(level)
	if (not level) then
		level = 1;
	end
	for i = level, lib.UIDROPDOWNMENU_MAXLEVELS do
		_G[prefixDropDownList .. i]:Hide();
	end
end

local function UIDropDownMenu_ContainsMouse()
	for i = 1, lib.UIDROPDOWNMENU_MAXLEVELS do
		local dropdown = _G[prefixDropDownList .. i];
		if dropdown:IsShown() and dropdown:IsMouseOver() then
			return true;
		end
	end

	return false;
end

function lib.UIDropDownMenu_HandleGlobalMouseEvent(button, event)
	if event == "GLOBAL_MOUSE_DOWN" and (button == "LeftButton" or button == "RightButton") then
		if not UIDropDownMenu_ContainsMouse() then
			lib.CloseDropDownMenus();
		end
	end
end

function lib.UIDropDownMenu_OnShow(self)
	if (self.onShow) then
		self.onShow();
		self.onShow = nil;
	end

	for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
		if (not self.noResize) then
			_G[self:GetName() .. "Button" .. i]:SetWidth(self.maxWidth);
		end
	end

	if (not self.noResize) then
		self:SetWidth(self.maxWidth + 25);
	end

	self.showTimer = nil;

	if (self:GetID() > 1) then
		self.parent = _G[prefixDropDownList .. (self:GetID() - 1)];
	end
end

function lib.UIDropDownMenu_OnHide(self)
	local id = self:GetID()
	if (self.onHide) then
		self.onHide(id + 1);
		self.onHide = nil;
	end
	lib.CloseDropDownMenus(id + 1);
	lib.OPEN_DROPDOWNMENUS[id] = nil;
	if (id == 1) then
		lib.UIDROPDOWNMENU_OPEN_MENU = nil;
	end

	lib.UIDropDownMenu_ClearCustomFrames(self);
end

function lib.UIDropDownMenu_ClearCustomFrames(self)
	if self.customFrames then
		for index, frame in ipairs(self.customFrames) do
			frame:Hide();
		end

		self.customFrames = nil;
	end
end

function lib.UIDropDownMenu_SetWidth(frame, width, padding)
	local frameName = frame:GetName();
	GetChild(frame, frameName, "Middle"):SetWidth(width);
	local defaultPadding = 25;
	if (padding) then
		frame:SetWidth(width + padding);
	else
		frame:SetWidth(width + defaultPadding + defaultPadding);
	end
	if (padding) then
		GetChild(frame, frameName, "Text"):SetWidth(width);
	else
		GetChild(frame, frameName, "Text"):SetWidth(width - defaultPadding);
	end
	frame.noResize = 1;
end

function lib.UIDropDownMenu_SetButtonWidth(frame, width)
	local frameName = frame:GetName();
	if (width == "TEXT") then
		width = GetChild(frame, frameName, "Text"):GetWidth();
	end

	GetChild(frame, frameName, "Button"):SetWidth(width);
	frame.noResize = 1;
end

function lib.UIDropDownMenu_SetText(frame, text)
	local frameName = frame:GetName();
	GetChild(frame, frameName, "Text"):SetText(text);
end

function lib.UIDropDownMenu_GetText(frame)
	local frameName = frame:GetName();
	return GetChild(frame, frameName, "Text"):GetText();
end

function lib.UIDropDownMenu_ClearAll(frame)
	-- Previous code refreshed the menu quite often and was a performance bottleneck
	frame.selectedID = nil;
	frame.selectedName = nil;
	frame.selectedValue = nil;
	lib.UIDropDownMenu_SetText(frame, "");

	local button, checkImage, uncheckImage;
	for i = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
		button = _G[prefixDropDownList .. lib.UIDROPDOWNMENU_MENU_LEVEL .. "Button" .. i];
		button:UnlockHighlight();

		checkImage = _G[prefixDropDownList .. lib.UIDROPDOWNMENU_MENU_LEVEL .. "Button" .. i .. "Check"];
		checkImage:Hide();
		uncheckImage = _G[prefixDropDownList .. lib.UIDROPDOWNMENU_MENU_LEVEL .. "Button" .. i .. "UnCheck"];
		uncheckImage:Hide();
	end
end

function lib.UIDropDownMenu_JustifyText(frame, justification, customXOffset)
	local frameName = frame:GetName();
	local text = GetChild(frame, frameName, "Text");
	text:ClearAllPoints();
	if (justification == "LEFT") then
		text:SetPoint("LEFT", GetChild(frame, frameName, "Left"), "LEFT", customXOffset or 27, 2);
		text:SetJustifyH("LEFT");
	elseif (justification == "RIGHT") then
		text:SetPoint("RIGHT", GetChild(frame, frameName, "Right"), "RIGHT", customXOffset or -43, 2);
		text:SetJustifyH("RIGHT");
	elseif (justification == "CENTER") then
		text:SetPoint("CENTER", GetChild(frame, frameName, "Middle"), "CENTER", customXOffset or -5, 2);
		text:SetJustifyH("CENTER");
	end
end

function lib.UIDropDownMenu_SetAnchor(dropdown, xOffset, yOffset, point, relativeTo, relativePoint)
	dropdown.xOffset = xOffset;
	dropdown.yOffset = yOffset;
	dropdown.point = point;
	dropdown.relativeTo = relativeTo;
	dropdown.relativePoint = relativePoint;
end

function lib.UIDropDownMenu_GetCurrentDropDown()
	if (lib.UIDROPDOWNMENU_OPEN_MENU) then
		return lib.UIDROPDOWNMENU_OPEN_MENU;
	elseif (lib.UIDROPDOWNMENU_INIT_MENU) then
		return lib.UIDROPDOWNMENU_INIT_MENU;
	end
end

function lib.UIDropDownMenuButton_GetChecked(self)
	return _G[self:GetName() .. "Check"]:IsShown();
end

function lib.UIDropDownMenuButton_GetName(self)
	return _G[self:GetName() .. "NormalText"]:GetText();
end

function lib.UIDropDownMenuButton_OpenColorPicker(self, button)
	CloseMenus();
	if (not button) then
		button = self;
	end
	lib.UIDROPDOWNMENU_MENU_VALUE = button.value;
	lib.OpenColorPicker(button);
end

function lib.UIDropDownMenu_DisableButton(level, id)
	_G[prefixDropDownList .. level .. "Button" .. id]:Disable();
end

function lib.UIDropDownMenu_EnableButton(level, id)
	_G[prefixDropDownList .. level .. "Button" .. id]:Enable();
end

function lib.UIDropDownMenu_SetButtonText(level, id, text, colorCode)
	local button = _G[prefixDropDownList .. level .. "Button" .. id];
	if (colorCode) then
		button:SetText(colorCode .. text .. "|r");
	else
		button:SetText(text);
	end
end

function lib.UIDropDownMenu_SetButtonNotClickable(level, id)
	_G[prefixDropDownList .. level .. "Button" .. id]:SetDisabledFontObject(GameFontHighlightSmallLeft);
end

function lib.UIDropDownMenu_SetButtonClickable(level, id)
	_G[prefixDropDownList .. level .. "Button" .. id]:SetDisabledFontObject(GameFontDisableSmallLeft);
end

function lib.UIDropDownMenu_DisableDropDown(dropDown)
	local dropDownName = dropDown:GetName();
	local label = GetChild(dropDown, dropDownName, "Label");
	if label then
		label:SetVertexColor(GRAY_FONT_COLOR:GetRGB());
	end
	GetChild(dropDown, dropDownName, "Icon"):SetVertexColor(GRAY_FONT_COLOR:GetRGB());
	GetChild(dropDown, dropDownName, "Text"):SetVertexColor(GRAY_FONT_COLOR:GetRGB());
	GetChild(dropDown, dropDownName, "Button"):Disable();
	dropDown.isDisabled = 1;
end

function lib.UIDropDownMenu_EnableDropDown(dropDown)
	local dropDownName = dropDown:GetName();
	local label = GetChild(dropDown, dropDownName, "Label");
	if label then
		label:SetVertexColor(NORMAL_FONT_COLOR:GetRGB());
	end
	GetChild(dropDown, dropDownName, "Icon"):SetVertexColor(HIGHLIGHT_FONT_COLOR:GetRGB());
	GetChild(dropDown, dropDownName, "Text"):SetVertexColor(HIGHLIGHT_FONT_COLOR:GetRGB());
	GetChild(dropDown, dropDownName, "Button"):Enable();
	dropDown.isDisabled = nil;
end

function lib.UIDropDownMenu_SetDropDownEnabled(dropDown, enabled)
	if enabled then
		return lib.UIDropDownMenu_EnableDropDown(dropDown);
	else
		return lib.UIDropDownMenu_DisableDropDown(dropDown);
	end
end

function lib.UIDropDownMenu_IsEnabled(dropDown)
	return not dropDown.isDisabled;
end

function lib.UIDropDownMenu_GetValue(id)
	--Only works if the dropdown has just been initialized, lame, I know =(
	local button = _G[prefixDropDownList .. "1Button" .. id];
	if (button) then
		return _G[prefixDropDownList .. "1Button" .. id].value;
	else
		return nil;
	end
end

function lib.OpenColorPicker(info)
	if (ColorPickerFrame.SetupColorPickerAndShow) then
		ColorPickerFrame:SetupColorPickerAndShow(info)
		return
	end
	ColorPickerFrame.func = info.swatchFunc;
	ColorPickerFrame.hasOpacity = info.hasOpacity;
	ColorPickerFrame.opacityFunc = info.opacityFunc;
	ColorPickerFrame.opacity = info.opacity;
	ColorPickerFrame.previousValues = { r = info.r, g = info.g, b = info.b, opacity = info.opacity };
	ColorPickerFrame.cancelFunc = info.cancelFunc;
	ColorPickerFrame.extraInfo = info.extraInfo;
	-- This must come last, since it triggers a call to ColorPickerFrame.func()
	ColorPickerFrame:SetColorRGB(info.r, info.g, info.b);
	ShowUIPanel(ColorPickerFrame);
end

function lib.ColorPicker_GetPreviousValues()
	return ColorPickerFrame.previousValues.r, ColorPickerFrame.previousValues.g, ColorPickerFrame.previousValues.b;
end

function lib.UIDropDownMenu_StartCounting() end -- no op
function lib.UIDropDownMenu_StopCounting() end -- no op

if not UIDropDownMenu_HandleGlobalMouseEvent then
	-- Start the countdown on a frame
	function lib.UIDropDownMenu_StartCounting(frame)
		if (frame.parent) then
			lib.UIDropDownMenu_StartCounting(frame.parent);
		else
			frame.showTimer = lib.UIDROPDOWNMENU_SHOW_TIME;
			frame.isCounting = 1;
		end
	end

	-- Stop the countdown on a frame
	function lib.UIDropDownMenu_StopCounting(frame)
		if (frame.parent) then
			lib.UIDropDownMenu_StopCounting(frame.parent);
		else
			frame.isCounting = nil;
		end
	end

	local oldOnUpdate = lib.UIDropDownMenu_OnUpdate
	function lib.UIDropDownMenu_OnUpdate(self, elapsed)
		oldOnUpdate(self, elapsed)
		if (not self.showTimer or not self.isCounting) then
			return ;
		elseif (self.showTimer < 0) then
			self:Hide();
			self.showTimer = nil;
			self.isCounting = nil;
		else
			self.showTimer = self.showTimer - elapsed;
		end
	end
end

function lib.EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
	if (displayMode == "MENU") then
		menuFrame.displayMode = displayMode;
	end
	lib.UIDropDownMenu_Initialize(menuFrame, lib.EasyMenu_Initialize, displayMode, nil, menuList);
	lib.ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay);
end

--- "temporary" ;) fix to avoid showing the menu when it is already visible
function lib.ToggleEasyMenu(menuList, menuFrame, anchor, ...)
	if (lib.UIDROPDOWNMENU_OPEN_MENU == menuFrame and lib.UIDROPDOWNMENU_OPEN_MENU_ANCHOR == anchor) then
		lib.CloseDropDownMenus()
	else
		lib.EasyMenu(menuList, menuFrame, anchor,...)
	end
end

function lib.EasyMenu_Initialize(frame, level, menuList)
	if not menuList then return end
	for index = 1, #menuList do
		local value = menuList[index]
		if (type(value) == "function") then
			value = value(frame, level, menuList, index)
		end
		if (value.text) then
			value.index = index;
			lib.UIDropDownMenu_AddButton(value, level);
		end
	end
end

--- Mixin to prevent clicks in a button to close the menu because of GLOBAL_MOUSE_DOWN,
--- and immediately open again, because the button was clicked.
--- use: Mixin(frame, EDDM.HandlesGlobalMouseEventMixin)
--- Frames created with [EDDM.UIDropDownMenu_Create] or [EDDM.UIDropDownMenu_GetOrCreate] already have this mixin.
lib.HandlesGlobalMouseEventMixin = {
	HandlesGlobalMouseEvent = function(_, buttonID, event)
		if (event == "GLOBAL_MOUSE_DOWN" and buttonID == "LeftButton") then
			return true
		end
	end
}
--------------------------
--- Blizzard's code end
--------------------------

-- Initializations
lib.UIDropDownMenu_CreateFrames(2, 1)
local _, fontHeight, _ = _G[prefixDropDownList .. 1 .. "Button" .. 1 .. "NormalText"]:GetFont()
lib.UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = fontHeight

local function HandlesGlobalMouseEvent(focus, buttonID, event)
	return focus and focus.HandlesGlobalMouseEvent and focus:HandlesGlobalMouseEvent(buttonID, event);
end

UIDropDownMenuDelegate:RegisterEvent("GLOBAL_MOUSE_DOWN")
UIDropDownMenuDelegate:SetScript("OnEvent", function(self, event, buttonID)
	local mouseFocus = (GetMouseFocus and GetMouseFocus()) or (GetMouseFoci and GetMouseFoci()[1])
	if not HandlesGlobalMouseEvent(mouseFocus, buttonID, event) then
		lib.UIDropDownMenu_HandleGlobalMouseEvent(buttonID, event);
	end
end)
