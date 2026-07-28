local function InstallPOIStateFix()
    local POI = _G.CarbonitePOI
    if not POI or POI.stateFixInstalled then return false end
    if type(POI.GetCategory) ~= "function" or type(POI.CreateGUI) ~= "function" then return false end

    local function Print(message)
        DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI|r: " .. tostring(message))
    end

    local function EnsureDisabledTable()
        NxData = NxData or {}
        NxData.POICategories = NxData.POICategories or {}
        NxData.POICategories.Disabled = NxData.POICategories.Disabled or {}
        return NxData.POICategories.Disabled
    end

    local function RebuildPOIs()
        local map
        if Nx and Nx.Map and type(Nx.Map.GeM) == "function" then
            local ok, result = pcall(Nx.Map.GeM, Nx.Map, 1)
            if ok then map = result end
        end

        local gui = map and map.Gui or (Nx and Nx.Map and Nx.Map.Gui)
        if not gui or type(gui.UZPOII) ~= "function" then
            Print("active map POI renderer was not found")
            return false
        end

        gui.POIMI = nil
        gui.POID = nil
        local ok, err = pcall(gui.UZPOII, gui)
        if not ok then
            Print("POI rebuild error: " .. tostring(err))
            return false
        end
        return true
    end

    local function Notify(categoryName, enabled)
        if type(POI.listeners) ~= "table" then return end
        for _, listener in ipairs(POI.listeners) do
            pcall(listener, categoryName, enabled)
        end
    end

    -- Lua's "enabled and nil or true" expression always evaluates to true.
    -- Use explicit branches so an entry can actually be removed from the
    -- disabled table when a category is switched back on.
    function POI:SetEnabled(name, enabled)
        local category, err = self:GetCategory(name)
        if not category then return false, err end

        enabled = not not enabled
        local disabled = EnsureDisabledTable()
        if enabled then
            disabled[category.key] = nil
        else
            disabled[category.key] = true
        end

        RebuildPOIs()
        Notify(category.name, enabled)
        self:RefreshGUI()
        return true, category.name
    end

    function POI:SetCategory(name, enabled)
        return self:SetEnabled(name, enabled)
    end

    function POI:SetAll(enabled)
        enabled = not not enabled
        local disabled = EnsureDisabledTable()
        for _, category in ipairs(self.categoryCatalog or {}) do
            if enabled then
                disabled[category.key] = nil
            else
                disabled[category.key] = true
            end
        end

        RebuildPOIs()
        Notify(nil, enabled)
        self:RefreshGUI()
    end

    local originalCreateGUI = POI.CreateGUI

    local function FixCheckboxes()
        if type(POI.checks) ~= "table" then return end

        for _, check in pairs(POI.checks) do
            if check and check.categoryName then
                check:SetScript("OnClick", function(self)
                    local enabled = not POI:IsEnabled(self.categoryName)
                    local ok, err = POI:SetEnabled(self.categoryName, enabled)
                    if not ok then Print(err) end
                    self:SetChecked(POI:IsEnabled(self.categoryName))
                end)
                check.poiToggleFixed = true
            end
        end
    end

    POI.CreateGUI = function(self, ...)
        local frame = originalCreateGUI(self, ...)
        FixCheckboxes()
        return frame
    end

    FixCheckboxes()
    POI.stateFixInstalled = true
    return true
end

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.25 then return end
    self.elapsed = 0

    if InstallPOIStateFix() then
        self:SetScript("OnUpdate", nil)
    end
end)
