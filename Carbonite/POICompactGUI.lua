local function InstallCompactPOIGUI()
    local POI = _G.CarbonitePOI
    if not POI or POI.compactGUIInstalled then return false end
    if type(POI.GetCategories) ~= "function" or type(POI.IsEnabled) ~= "function" then return false end

    local function Print(message)
        DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI|r: " .. tostring(message))
    end

    local function Normalize(value)
        return string.lower(tostring(value or "")):gsub("[%s%p]+", "")
    end

    local function CreateButton(parent, text, width)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetWidth(width)
        button:SetHeight(22)
        button:SetText(text)
        return button
    end

    local function CreateCheck(parent, category, x, y)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetWidth(20)
        check:SetHeight(20)
        check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        check.categoryName = category.name

        local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("LEFT", check, "RIGHT", 1, 0)
        label:SetWidth(125)
        label:SetJustifyH("LEFT")
        label:SetText(category.name)
        check.label = label

        check:SetScript("OnClick", function(self)
            -- Toggle from the saved state. Wrath's checkbox template may report
            -- a stale checked value when this window is anchored to the map bar.
            local enabled = not POI:IsEnabled(self.categoryName)
            local ok, err = POI:SetEnabled(self.categoryName, enabled)
            if not ok then Print(err) end
            self:SetChecked(POI:IsEnabled(self.categoryName))
        end)
        return check
    end

    function POI:CreateGUI()
        if self.frame then return self.frame end

        local categories = self:GetCategories()
        local rows = math.max(1, math.ceil(#categories / 2))
        local rowHeight = 22
        local frameWidth = 330
        local frameHeight = 108 + (rows * rowHeight)

        local frame = CreateFrame("Frame", "CarbonitePOIFrame", UIParent)
        frame:SetWidth(frameWidth)
        frame:SetHeight(frameHeight)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -17)
        title:SetText("Map Layers")

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

        local source = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        source:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
        source:SetText("Carbonite built-in POIs")

        local divider = frame:CreateTexture(nil, "ARTWORK")
        divider:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        divider:SetBlendMode("ADD")
        divider:SetPoint("TOPLEFT", source, "BOTTOMLEFT", 0, -2)
        divider:SetWidth(frameWidth - 40)
        divider:SetHeight(8)

        self.checks = {}
        local split = math.ceil(#categories / 2)
        local startY = -57
        for index, category in ipairs(categories) do
            local column = index > split and 2 or 1
            local row = column == 1 and index or index - split
            local x = column == 1 and 18 or 168
            local y = startY - ((row - 1) * rowHeight)
            self.checks[category.key or Normalize(category.name)] = CreateCheck(frame, category, x, y)
        end

        local allOn = CreateButton(frame, "All On", 76)
        allOn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 37, 18)
        allOn:SetScript("OnClick", function() POI:SetAll(true) end)

        local allOff = CreateButton(frame, "All Off", 76)
        allOff:SetPoint("LEFT", allOn, "RIGHT", 8, 0)
        allOff:SetScript("OnClick", function() POI:SetAll(false) end)

        local reset = CreateButton(frame, "Reset", 76)
        reset:SetPoint("LEFT", allOff, "RIGHT", 8, 0)
        reset:SetScript("OnClick", function()
            POI:Reset()
            Print("all built-in categories are ON")
        end)

        frame:SetScript("OnShow", function() POI:RefreshGUI() end)
        table.insert(UISpecialFrames, "CarbonitePOIFrame")
        self.frame = frame
        return frame
    end

    POI.compactGUIInstalled = true
    return true
end

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.25 then return end
    self.elapsed = 0

    if InstallCompactPOIGUI() then
        self:SetScript("OnUpdate", nil)
    end
end)
