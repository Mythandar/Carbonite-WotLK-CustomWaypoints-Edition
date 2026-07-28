local function InstallPOICheckFix()
    local POI = _G.CarbonitePOI
    if not POI or POI.checkFixInstalled then return false end

    local originalCreateGUI = POI.CreateGUI
    if type(originalCreateGUI) ~= "function" then return false end

    local function FixCheckboxes()
        if type(POI.checks) ~= "table" then return end

        for _, check in pairs(POI.checks) do
            if check and check.categoryName and not check.poiToggleFixed then
                check:SetScript("OnClick", function(self)
                    -- On Wrath 3.3.5 the template's checked state can be stale while
                    -- this popup is anchored to Carbonite's map toolbar. Toggle from
                    -- the saved POI state instead of trusting GetChecked().
                    local enabled = not POI:IsEnabled(self.categoryName)
                    local ok, err = POI:SetEnabled(self.categoryName, enabled)
                    if not ok then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI|r: " .. tostring(err))
                    end
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

    -- Also cover a GUI that another addon opened unusually early.
    FixCheckboxes()
    POI.checkFixInstalled = true
    return true
end

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.25 then return end
    self.elapsed = 0

    if InstallPOICheckFix() then
        self:SetScript("OnUpdate", nil)
    end
end)
