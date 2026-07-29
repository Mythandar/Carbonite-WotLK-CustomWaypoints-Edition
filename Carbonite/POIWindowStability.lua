local function InstallStablePOIWindow()
    local POI = _G.CarbonitePOI
    if not POI or POI.windowStabilityInstalled then return false end
    if type(POI.CreateGUI) ~= "function" then return false end

    local originalCreateGUI = POI.CreateGUI

    local function ReadCategoryState(category)
        if type(category) ~= "table" then return false end
        if type(category.IsEnabled) == "function" then
            local ok, enabled = pcall(category.IsEnabled, category)
            if ok then return enabled and true or false end
        end
        return category.enabled ~= false
    end

    -- Keep the options window independent from Carbonite's fading and moving
    -- toolbar. The toolbar button opens the window, but does not remain its
    -- anchor after that.
    function POI:PositionGUI()
        local frame = self:CreateGUI()
        if not frame.poiStablePositioned then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            frame.poiStablePositioned = true
        end
        return frame
    end

    -- Refresh only values that actually changed. Repeated SetChecked calls can
    -- trigger visible redraws in the Wrath client while Carbonite processes map
    -- mouse-over updates.
    function POI:RefreshGUI()
        for _, check in pairs(self.checks or {}) do
            if check and check.layerCategory then
                local enabled = ReadCategoryState(check.layerCategory)
                local checked = check:GetChecked() and true or false
                if checked ~= enabled then
                    check:SetChecked(enabled)
                end
            end
        end
    end

    function POI:CreateGUI()
        local frame = originalCreateGUI(self)
        if not frame.poiStableWindowInstalled then
            frame:SetFrameStrata("DIALOG")
            frame:EnableMouse(true)

            -- The compact GUI already builds itself when providers or collapse
            -- states change. Opening it only needs a state refresh.
            frame:SetScript("OnShow", function()
                POI:RefreshGUI()
            end)

            frame.poiStableWindowInstalled = true
        end
        return frame
    end

    POI.windowStabilityInstalled = true
    return true
end

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.25 then return end
    self.elapsed = 0

    local POI = _G.CarbonitePOI
    if POI and POI.compactGUIInstalled and InstallStablePOIWindow() then
        self:SetScript("OnUpdate", nil)
    end
end)
