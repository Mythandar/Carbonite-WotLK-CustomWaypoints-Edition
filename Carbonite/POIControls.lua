local POI = {
    VERSION = 1,
    installed = false,
    originalUZPOII = nil,
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

local function GetCategories()
    local categories = {}

    if not Nx or type(Nx.GPOI) ~= "table" then
        return categories
    end

    for index, value in ipairs(Nx.GPOI) do
        local name = GetPOIName(value)
        categories[#categories + 1] = {
            index = index,
            name = name,
            key = Normalize(name),
            value = value,
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

    for _, category in ipairs(GetCategories()) do
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
    local disabled = EnsureSavedData()
    return not disabled[Normalize(name)]
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

function POI:GetCategories()
    return GetCategories()
end

function POI:IsEnabled(name)
    return IsCategoryEnabled(name)
end

function POI:SetEnabled(name, enabled)
    local category, err = ResolveCategory(name)
    if not category then
        return false, err
    end

    local disabled = EnsureSavedData()
    if enabled then
        disabled[category.key] = nil
    else
        disabled[category.key] = true
    end

    RebuildBuiltInPOIs()
    return true, category.name
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
end

local function PrintList()
    Print("built-in categories:")
    for _, category in ipairs(GetCategories()) do
        local state = IsCategoryEnabled(category.name) and "ON" or "OFF"
        Print(string.format("%-18s %s", category.name, state))
    end
end

local function PrintHelp()
    Print("commands:")
    Print("/cpoi list")
    Print("/cpoi hide <category>")
    Print("/cpoi show <category>")
    Print("/cpoi toggle <category>")
    Print("/cpoi status <category>")
    Print("/cpoi reset")
end

local function HandleCommand(message)
    local input = Trim(message)
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = string.lower(command or "")

    if command == "list" then
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
    Print("category controls v" .. POI.VERSION .. " loaded. Type /cpoi list")
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
