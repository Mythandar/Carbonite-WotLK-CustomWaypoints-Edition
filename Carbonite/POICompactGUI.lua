local function InstallCompactPOIGUI()
    local POI = _G.CarbonitePOI
    if not POI or POI.compactGUIInstalled then return false end
    if type(POI.GetCategories) ~= "function" or type(POI.IsEnabled) ~= "function" then return false end

    POI.layerProviders = POI.layerProviders or {}
    POI.layerProviderOrder = POI.layerProviderOrder or {}
    POI.layerControls = POI.layerControls or {}

    local function Print(message)
        DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI|r: " .. tostring(message))
    end

    local function Normalize(value)
        return string.lower(tostring(value or "")):gsub("[%s%p]+", "")
    end

    local function SavedUI()
        NxData = NxData or {}
        NxData.POICategories = NxData.POICategories or {}
        NxData.POICategories.Collapsed = NxData.POICategories.Collapsed or {}
        return NxData.POICategories.Collapsed
    end

    local function CreateButton(parent, text, width)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetWidth(width)
        button:SetHeight(22)
        button:SetText(text)
        return button
    end

    local function BuiltInProvider()
        local categories = {}
        for _, category in ipairs(POI:GetCategories() or {}) do
            categories[#categories + 1] = {
                id = category.key or Normalize(category.name),
                name = category.name,
                IsEnabled = function() return POI:IsEnabled(category.name) end,
                SetEnabled = function(enabled) return POI:SetEnabled(category.name, enabled) end,
            }
        end
        return {
            id = "carbonite",
            name = "Carbonite built-in POIs",
            categories = categories,
            SetAll = function(enabled) POI:SetAll(enabled) end,
        }
    end

    function POI:RegisterLayerProvider(id, provider)
        id = Normalize(id)
        if id == "" or type(provider) ~= "table" then return false end
        provider.id = id
        if not self.layerProviders[id] then
            self.layerProviderOrder[#self.layerProviderOrder + 1] = id
        end
        self.layerProviders[id] = provider
        if self.frame then self:RebuildLayerGUI() end
        return true
    end

    function POI:UnregisterLayerProvider(id)
        id = Normalize(id)
        self.layerProviders[id] = nil
        for index = #self.layerProviderOrder, 1, -1 do
            if self.layerProviderOrder[index] == id then table.remove(self.layerProviderOrder, index) end
        end
        if self.frame then self:RebuildLayerGUI() end
    end

    function POI:GetLayerProviders()
        local providers = { BuiltInProvider() }
        for _, id in ipairs(self.layerProviderOrder) do
            local provider = self.layerProviders[id]
            if provider then providers[#providers + 1] = provider end
        end
        return providers
    end

    local function CategoryEnabled(category)
        if type(category.IsEnabled) == "function" then
            local ok, enabled = pcall(category.IsEnabled, category)
            if ok then return enabled and true or false end
        end
        return category.enabled ~= false
    end

    local function SetCategory(category, enabled)
        if type(category.SetEnabled) ~= "function" then return false end
        local ok, result, err = pcall(category.SetEnabled, category, enabled)
        if not ok then Print(result) return false end
        if result == false and err then Print(err) end
        return result ~= false
    end

    function POI:RebuildLayerGUI()
        local frame = self.frame
        if not frame then return end

        for _, control in ipairs(self.layerControls) do control:Hide() end
        self.layerControls = {}
        self.checks = {}

        local frameWidth = 352
        local leftX, rightX = 20, 181
        local rowHeight = 21
        local y = -39
        local collapsed = SavedUI()

        local function Keep(control)
            self.layerControls[#self.layerControls + 1] = control
            return control
        end

        for _, provider in ipairs(self:GetLayerProviders()) do
            local providerId = Normalize(provider.id or provider.name)
            local categories = provider.categories or {}
            if type(provider.GetCategories) == "function" then
                local ok, result = pcall(provider.GetCategories, provider)
                if ok and type(result) == "table" then categories = result end
            end

            local header = Keep(CreateFrame("Button", nil, frame))
            header:SetHeight(20)
            header:SetWidth(frameWidth - 38)
            header:SetPoint("TOPLEFT", frame, "TOPLEFT", 19, y)

            local arrow = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            arrow:SetPoint("LEFT", header, "LEFT", 0, 0)
            arrow:SetText(collapsed[providerId] and ">" or "v")

            local title = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            title:SetPoint("LEFT", arrow, "RIGHT", 5, 0)
            title:SetText(string.format("%s (%d)", tostring(provider.name or providerId), #categories))

            header:SetScript("OnClick", function()
                collapsed[providerId] = not collapsed[providerId] or nil
                POI:RebuildLayerGUI()
            end)

            local divider = Keep(frame:CreateTexture(nil, "ARTWORK"))
            divider:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            divider:SetBlendMode("ADD")
            divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, y - 15)
            divider:SetWidth(frameWidth - 36)
            divider:SetHeight(7)
            y = y - 24

            if not collapsed[providerId] then
                local split = math.ceil(#categories / 2)
                local rows = math.max(1, split)
                for index, category in ipairs(categories) do
                    local column = index > split and 2 or 1
                    local row = column == 1 and index or index - split
                    local x = column == 1 and leftX or rightX
                    local cy = y - ((row - 1) * rowHeight)
                    local check = Keep(CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate"))
                    check:SetWidth(20)
                    check:SetHeight(20)
                    check:SetPoint("TOPLEFT", frame, "TOPLEFT", x, cy)
                    check.layerCategory = category

                    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                    label:SetPoint("LEFT", check, "RIGHT", 1, 0)
                    label:SetWidth(132)
                    label:SetJustifyH("LEFT")
                    label:SetText(category.name or category.id or "Layer")
                    check.label = label
                    check:SetChecked(CategoryEnabled(category))
                    check:SetScript("OnClick", function(self)
                        local enabled = not CategoryEnabled(self.layerCategory)
                        SetCategory(self.layerCategory, enabled)
                        self:SetChecked(CategoryEnabled(self.layerCategory))
                        POI:RefreshGUI()
                    end)
                    self.checks[providerId .. ":" .. Normalize(category.id or category.name)] = check
                end
                y = y - (rows * rowHeight) - 5
            end
        end

        frame:SetWidth(frameWidth)
        frame:SetHeight(math.max(118, -y + 48))
    end

    function POI:CreateGUI()
        if self.frame then return self.frame end

        local frame = CreateFrame("Frame", "CarbonitePOIFrame", UIParent)
        frame:SetWidth(352)
        frame:SetHeight(180)
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
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -17)
        title:SetText("Map Layers")

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

        local allOn = CreateButton(frame, "Carbonite On", 94)
        allOn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 17)
        allOn:SetScript("OnClick", function() POI:SetAll(true) end)

        local allOff = CreateButton(frame, "Carbonite Off", 94)
        allOff:SetPoint("LEFT", allOn, "RIGHT", 8, 0)
        allOff:SetScript("OnClick", function() POI:SetAll(false) end)

        local reset = CreateButton(frame, "Reset", 70)
        reset:SetPoint("LEFT", allOff, "RIGHT", 8, 0)
        reset:SetScript("OnClick", function()
            POI:Reset()
            Print("all built-in categories are ON")
        end)

        frame:SetScript("OnShow", function()
            POI:RebuildLayerGUI()
            POI:RefreshGUI()
        end)
        table.insert(UISpecialFrames, "CarbonitePOIFrame")
        self.frame = frame
        self:RebuildLayerGUI()
        return frame
    end

    local originalRefresh = POI.RefreshGUI
    function POI:RefreshGUI()
        if type(originalRefresh) == "function" then originalRefresh(self) end
        for _, check in pairs(self.checks or {}) do
            if check.layerCategory then check:SetChecked(CategoryEnabled(check.layerCategory)) end
        end
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
    if InstallCompactPOIGUI() then self:SetScript("OnUpdate", nil) end
end)