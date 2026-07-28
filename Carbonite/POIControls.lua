local POI = {
    VERSION = 2,
    installed = false,
    originalUZPOII = nil,
    categoryCatalog = {},
    listeners = {},
    frame = nil,
    checks = {},
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI|r: " .. tostring(message))
end

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function Normalize(value)
    return string.lower(Trim(value)):gsub("[%s%p]+", "")
end

local function GetPOIName(value)
    return strsplit("~", tostring(value or ""))
end

local function EnsureSavedData()
    NxData = NxData or {}
    NxData.POICategories = NxData.POICategories or {}
    NxData.POICategories.Disabled = NxData.POICategories.Disabled or {}
    return NxData.POICategories.Disabled
end

local function BuildCategoryCatalog()
    POI.categoryCatalog = {}

    if not Nx or type(Nx.GPOI) ~= "table" then
        return
    end

    for index, value in ipairs(Nx.GPOI) do
        local name = GetPOIName(value)
        POI.categoryCatalog[#POI.categoryCatalog + 1] = {
            index = index,
            name = name,
            key = Normalize(name),
            value = value,
            source = "builtin",
        }
    end
end

local function GetCategories()
    local categories = {}
    for _, category in ipairs(POI.categoryCatalog) do
        categories[#categories + 1] = {
            index = category.index,
            name = category.name,
            key = category.key,
            value = category.value,
            source = category.source,
            enabled = not EnsureSavedData()[category.key],
        }
    end
    return categories
end

local function ResolveCategory(query)
    local wanted = Normalize(query)
    if wanted == "" then
        return nil, "No category was specified."
    end

    local exact
    local partial = {}

    for _, category in ipairs(POI.categoryCatalog) do
        if category.key == wanted then
            exact = category
            break
        elseif string.find(category.key, wanted, 1, true) == 1 then
            partial[#partial + 1] = category
        end
    end

    if exact then
        return exact
    end

    if #partial == 1 then
        return partial[1]
    end

    if #partial > 1 then
        local names = {}
        for _, category in ipairs(partial) do
            names[#names + 1] = category.name
        end
        return nil, "Category is ambiguous: " .. table.concat(names, ", ")
    end

    return nil, "Unknown category: " .. tostring(query)
end

local function IsCategoryEnabled(name)
    return not EnsureSavedData()[Normalize(name)]
end

local function GetMainMapGui()
    if not Nx or not Nx.Map then return nil end

    if type(Nx.Map.GeM) == "function" then
        local ok, map = pcall(Nx.Map.GeM, Nx.Map, 1)
        if ok and map and map.Gui then
            return map.Gui
        end
    end

    return Nx.Map.Gui
end

local function RebuildBuiltInPOIs()
    local gui = GetMainMapGui()
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

local function RemoveDisabledPOIs()
    local removed = {}
    local disabled = EnsureSavedData()

    if not Nx or type(Nx.GPOI) ~= "table" then
        return removed
    end

    for index = #Nx.GPOI, 1, -1 do
        local value = Nx.GPOI[index]
        local name = GetPOIName(value)
        if disabled[Normalize(name)] then
            table.insert(removed, 1, { index = index, value = value })
            table.remove(Nx.GPOI, index)
        end
    end

    return removed
end

local function RestorePOIs(removed)
    if not Nx or type(Nx.GPOI) ~= "table" then return end

    for _, entry in ipairs(removed) do
        table.insert(Nx.GPOI, entry.index, entry.value)
    end
end

local function Notify(categoryName, enabled)
    for _, listener in ipairs(POI.listeners) do
        pcall(listener, categoryName, enabled)
    end
end

function POI:GetCategories()
    return GetCategories()
end

function POI:GetCategory(name)
    local category, err = ResolveCategory(name)
    if not category then
        return nil, err
    end

    return {
        index = category.index,
        name = category.name,
        key = category.key,
        value = category.value,
        source = category.source,
        enabled = IsCategoryEnabled(category.name),
    }
end

function POI:IsEnabled(name)
    local category = ResolveCategory(name)
    if not category then return false end
    return IsCategoryEnabled(category.name)
end

function POI:SetEnabled(name, enabled)
    local category, err = ResolveCategory(name)
    if not category then
        return false, err
    end

    enabled = not not enabled
    local disabled = EnsureSavedData()
    if enabled then
        disabled[category.key] = nil
    else
        disabled[category.key] = true
    end

    RebuildBuiltInPOIs()
    Notify(category.name, enabled)
    self:RefreshGUI()
    return true, category.name
end

function POI:SetCategory(name, enabled)
    return self:SetEnabled(name, enabled)
end

function POI:Toggle(name)
    local category, err = ResolveCategory(name)
    if not category then
        return false, err
    end

    local enabled = not IsCategoryEnabled(category.name)
    local ok, resolved = self:SetEnabled(category.name, enabled)
    return ok, resolved, enabled
end

function POI:Reset()
    NxData = NxData or {}
    NxData.POICategories = { Disabled = {} }
    RebuildBuiltInPOIs()
    Notify(nil, true)
    self:RefreshGUI()
end

function POI:SetAll(enabled)
    local disabled = EnsureSavedData()
    for _, category in ipairs(POI.categoryCatalog) do
        if enabled then
            disabled[category.key] = nil
        else
            disabled[category.key] = true
        end
    end
    RebuildBuiltInPOIs()
    Notify(nil, enabled)
    self:RefreshGUI()
end

function POI:RegisterListener(callback)
    if type(callback) ~= "function" then return false end
    self.listeners[#self.listeners + 1] = callback
    return true
end

function POI:GetSources()
    return {
        {
            id = "builtin",
            name = "Carbonite built-in POIs",
            categories = self:GetCategories(),
        },
    }
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(text)
    return button
end

local function CreateCheck(parent, category, x, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check.categoryName = category.name

    -- Wrath's UICheckButtonTemplate does not create check.Text.
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    label:SetText(category.name)
    label:SetJustifyH("LEFT")
    check.label = label

    check:SetScript("OnClick", function(self)
        local ok, err = POI:SetEnabled(self.categoryName, self:GetChecked() and true or false)
        if not ok then
            Print(err)
            self:SetChecked(POI:IsEnabled(self.categoryName))
        end
    end)

    return check
end

function POI:CreateGUI()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "CarbonitePOIFrame", UIParent)
    frame:SetWidth(390)
    frame:SetHeight(390)
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

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("Carbonite POI Categories")

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -7)
    subtitle:SetText("Choose which built-in Carbonite POIs appear on the map")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    self.checks = {}
    local categories = self:GetCategories()
    local leftX = 28
    local rightX = 205
    local startY = -68
    local rowHeight = 30
    local split = math.ceil(#categories / 2)

    for index, category in ipairs(categories) do
        local column = index > split and 2 or 1
        local row = column == 1 and index or (index - split)
        local x = column == 1 and leftX or rightX
        local y = startY - ((row - 1) * rowHeight)
        local check = CreateCheck(frame, category, x, y)
        self.checks[category.key] = check
    end

    local allOn = CreateButton(frame, "All On", 90, 24)
    allOn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 22)
    allOn:SetScript("OnClick", function() POI:SetAll(true) end)

    local allOff = CreateButton(frame, "All Off", 90, 24)
    allOff:SetPoint("LEFT", allOn, "RIGHT", 10, 0)
    allOff:SetScript("OnClick", function() POI:SetAll(false) end)

    local reset = CreateButton(frame, "Reset", 90, 24)
    reset:SetPoint("LEFT", allOff, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function()
        POI:Reset()
        Print("all built-in categories are ON")
    end)

    frame:SetScript("OnShow", function() POI:RefreshGUI() end)

    table.insert(UISpecialFrames, "CarbonitePOIFrame")
    self.frame = frame
    return frame
end

function POI:RefreshGUI()
    if not self.frame then return end
    for _, category in ipairs(self.categoryCatalog) do
        local check = self.checks[category.key]
        if check then
            check:SetChecked(IsCategoryEnabled(category.name))
        end
    end
end

function POI:OpenGUI()
    local frame = self:CreateGUI()
    self:RefreshGUI()
    frame:Show()
end

function POI:ToggleGUI()
    local frame = self:CreateGUI()
    if frame:IsShown() then
        frame:Hide()
    else
        self:RefreshGUI()
        frame:Show()
    end
end

local function PrintList()
    Print("built-in categories:")
    for _, category in ipairs(GetCategories()) do
        local state = category.enabled and "ON" or "OFF"
        Print(string.format("%-18s %s", category.name, state))
    end
end

local function PrintHelp()
    Print("commands:")
    Print("/cpoi gui")
    Print("/cpoi list")
    Print("/cpoi hide <category>")
    Print("/cpoi show <category>")
    Print("/cpoi toggle <category>")
    Print("/cpoi status <category>")
    Print("/cpoi all on")
    Print("/cpoi all off")
    Print("/cpoi reset")
end

local function HandleCommand(message)
    local input = Trim(message)
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = string.lower(command or "")

    if command == "gui" or command == "window" or command == "options" then
        POI:ToggleGUI()
    elseif command == "list" then
        PrintList()
    elseif command == "hide" or command == "off" then
        local ok, result = POI:SetEnabled(argument, false)
        Print(ok and (result .. " is OFF") or result)
    elseif command == "show" or command == "on" then
        local ok, result = POI:SetEnabled(argument, true)
        Print(ok and (result .. " is ON") or result)
    elseif command == "toggle" then
        local ok, result, enabled = POI:Toggle(argument)
        Print(ok and (result .. " is " .. (enabled and "ON" or "OFF")) or result)
    elseif command == "status" then
        local category, err = ResolveCategory(argument)
        if category then
            Print(category.name .. " is " .. (IsCategoryEnabled(category.name) and "ON" or "OFF"))
        else
            Print(err)
        end
    elseif command == "all" then
        local state = Normalize(argument)
        if state == "on" or state == "show" then
            POI:SetAll(true)
            Print("all built-in categories are ON")
        elseif state == "off" or state == "hide" then
            POI:SetAll(false)
            Print("all built-in categories are OFF")
        else
            Print("Use /cpoi all on or /cpoi all off")
        end
    elseif command == "reset" then
        POI:Reset()
        Print("all built-in categories are ON")
    else
        PrintHelp()
    end
end

local function Install()
    if POI.installed then return true end
    if not Nx or not Nx.Map or not Nx.Map.Gui or type(Nx.Map.Gui.UZPOII) ~= "function" then
        return false
    end

    EnsureSavedData()
    BuildCategoryCatalog()

    POI.originalUZPOII = Nx.Map.Gui.UZPOII
    Nx.Map.Gui.UZPOII = function(self, ...)
        local removed = RemoveDisabledPOIs()
        local results = { pcall(POI.originalUZPOII, self, ...) }
        RestorePOIs(removed)

        local ok = table.remove(results, 1)
        if not ok then
            Print("renderer error: " .. tostring(results[1]))
            return
        end

        return unpack(results)
    end

    SLASH_CARBONITEPOI1 = "/cpoi"
    SlashCmdList.CARBONITEPOI = HandleCommand

    _G.CarbonitePOI = POI
    POI.installed = true
    Print("framework v" .. POI.VERSION .. " loaded. Type /cpoi gui")
    return true
end

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        if Install() then
            self:SetScript("OnUpdate", nil)
        end
    end
end)
