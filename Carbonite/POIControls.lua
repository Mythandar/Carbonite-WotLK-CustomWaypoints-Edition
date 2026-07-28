-- Carbonite Phase 2 POI controls
-- Provides persistent, modern controls over Carbonite's existing Guide POI renderer.

local POI = {
    VERSION = 1,
    installed = false,
    panel = nil,
    checks = {},
}

local CATEGORIES = {
    { header = "Services" },
    { key = "auctioneer", label = "Auction Houses", folder = "Auctioneer" },
    { key = "banker", label = "Banks", folder = "Banker" },
    { key = "flightmaster", label = "Flight Masters", folder = "Flight Master" },
    { key = "innkeeper", label = "Inns", folder = "Innkeeper" },
    { key = "mailbox", label = "Mailboxes", folder = "Mailbox" },
    { key = "trainer", label = "Trainers", folder = "Trainer" },
    { key = "vendor", label = "Vendors", folder = "Vendor" },
    { key = "repair", label = "Repair", folder = "Repair" },

    { header = "Travel" },
    { key = "instances", label = "Instances", folder = "Instances" },
    { key = "portals", label = "Portals", folder = "Portal" },
}

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POIs|r: " .. tostring(message))
    end
end

local function GetSettings()
    NxData = NxData or {}
    NxData.CarbonitePOIVisibility = NxData.CarbonitePOIVisibility or {}
    return NxData.CarbonitePOIVisibility
end

local function NormalizeName(folder)
    if type(folder) ~= "table" then return nil end
    local name = folder.Nam or folder.T
    if type(name) ~= "string" then return nil end
    return string.gsub(name, "   >>", "")
end

local function FindFolderRecursive(name, folder)
    if type(folder) ~= "table" then return nil end
    if NormalizeName(folder) == name then return folder end
    for _, child in ipairs(folder) do
        local found = FindFolderRecursive(name, child)
        if found then return found end
    end
    return nil
end

local function GetGui()
    return Nx and Nx.Map and Nx.Map.Gui
end

local function FindFolder(name)
    if not Nx or type(Nx.GuI) ~= "table" then return nil end
    return FindFolderRecursive(name, Nx.GuI)
end

local function RefreshMap()
    local gui = GetGui()
    if gui and type(gui.UMI1) == "function" then
        pcall(gui.UMI1, gui)
    end
end

function POI:SetCategory(key, enabled, silent)
    local definition
    for _, entry in ipairs(CATEGORIES) do
        if entry.key == key then
            definition = entry
            break
        end
    end
    if not definition then return false, "unknown category" end

    local gui = GetGui()
    if not gui or type(gui.ASF) ~= "function" then return false, "Guide is not ready" end

    local folder = FindFolder(definition.folder)
    if not folder then
        return false, "Guide folder not found: " .. definition.folder
    end

    GetSettings()[key] = enabled and true or false
    gui:ASF(folder, not enabled)
    RefreshMap()

    local check = self.checks[key]
    if check then check:SetChecked(enabled and true or false) end
    if not silent then Print(definition.label .. (enabled and " shown" or " hidden")) end
    return true
end

function POI:GetCategory(key)
    return GetSettings()[key] == true
end

function POI:ApplySavedSettings()
    local settings = GetSettings()
    for _, entry in ipairs(CATEGORIES) do
        if entry.key and settings[entry.key] ~= nil then
            self:SetCategory(entry.key, settings[entry.key], true)
        end
    end
end

local function CreateCheck(parent, entry, x, y)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check.Text:SetText(entry.label)
    check:SetScript("OnClick", function(self)
        POI:SetCategory(entry.key, self:GetChecked() and true or false)
    end)
    POI.checks[entry.key] = check
    return check
end

function POI:CreatePanel()
    if self.panel then return self.panel end

    local panel = CreateFrame("Frame", "CarbonitePOIOptionsPanel", UIParent)
    panel.name = "Carbonite POIs"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Carbonite POIs")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText("Choose which Carbonite Guide points of interest are displayed on the map. Settings are saved account-wide.")

    local y = -72
    for _, entry in ipairs(CATEGORIES) do
        if entry.header then
            local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            header:SetPoint("TOPLEFT", 18, y)
            header:SetText(entry.header)
            y = y - 24
        else
            CreateCheck(panel, entry, 24, y)
            y = y - 28
        end
    end

    panel:SetScript("OnShow", function()
        for _, entry in ipairs(CATEGORIES) do
            if entry.key and POI.checks[entry.key] then
                POI.checks[entry.key]:SetChecked(POI:GetCategory(entry.key))
            end
        end
    end)

    InterfaceOptions_AddCategory(panel)
    self.panel = panel
    return panel
end

function POI:OpenPanel()
    local panel = self:CreatePanel()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

local function HandleSlash(message)
    local command, value = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    value = string.lower(value or "")

    if command == "" or command == "options" then
        POI:OpenPanel()
        return
    end
    if command == "list" then
        for _, entry in ipairs(CATEGORIES) do
            if entry.key then
                Print(entry.key .. " = " .. (POI:GetCategory(entry.key) and "on" or "off"))
            end
        end
        return
    end

    local enabled
    if value == "on" or value == "1" or value == "show" then enabled = true end
    if value == "off" or value == "0" or value == "hide" then enabled = false end
    if enabled == nil then
        Print("Usage: /cpoi <category> on|off, /cpoi list, or /cpoi options")
        return
    end

    local ok, err = POI:SetCategory(command, enabled)
    if not ok then Print(err) end
end

SLASH_CARBONITEPOI1 = "/cpoi"
SlashCmdList.CARBONITEPOI = HandleSlash

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    POI:CreatePanel()
    local attempts = 0
    loader:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < .5 then return end
        self.elapsed = 0
        attempts = attempts + 1
        if Nx and Nx.GuI and GetGui() and type(GetGui().ASF) == "function" then
            POI:ApplySavedSettings()
            POI.installed = true
            self:SetScript("OnUpdate", nil)
            Print("controls v" .. POI.VERSION .. " installed; type /cpoi")
        elseif attempts >= 20 then
            self:SetScript("OnUpdate", nil)
            Print("could not initialize Guide controls")
        end
    end)
end)

_G.CarbonitePOIControlAPI = POI
