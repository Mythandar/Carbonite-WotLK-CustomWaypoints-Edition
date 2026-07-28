local Test = {
    VERSION = 2,
    hideFlightMasters = false,
    installed = false,
    originalUMI1 = nil,
    printedMatches = {},
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI test|r: " .. tostring(message))
end

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function Describe(shT, fol)
    if type(fol) ~= "table" then
        return "key=" .. tostring(shT) .. " value=" .. tostring(fol)
    end

    return string.format(
        "key=%s Nam=%s Name=%s N=%s Tx=%s Id=%s Per=%s",
        tostring(shT),
        tostring(fol.Nam),
        tostring(fol.Name),
        tostring(fol.N),
        tostring(fol.Tx),
        tostring(fol.Id),
        tostring(fol.Per)
    )
end

local function IsFlightMasterEntry(shT, fol)
    local values = {
        shT,
        type(fol) == "table" and fol.Nam,
        type(fol) == "table" and fol.Name,
        type(fol) == "table" and fol.N,
        type(fol) == "table" and fol.Tx,
        type(fol) == "table" and fol.InT2,
    }

    for _, value in ipairs(values) do
        local text = Lower(value)
        if string.find(text, "flight", 1, true)
            or string.find(text, "taxi", 1, true)
            or string.find(text, "gryphon", 1, true)
            or string.find(text, "wyvern", 1, true)
        then
            return true
        end
    end

    return false
end

local function RefreshMaps()
    if not Nx or not Nx.Map then return end

    if type(Nx.Map.GetMap) == "function" then
        pcall(function()
            local map = Nx.Map:GetMap(1)
            if map and map.Gui and type(map.Gui.Upd) == "function" then
                map.Gui:Upd()
            end
        end)
    end

    if type(Nx.Map.GeM) == "function" then
        pcall(function()
            local map = Nx.Map:GeM(1)
            if map and map.Gui and type(map.Gui.Upd) == "function" then
                map.Gui:Upd()
            end
        end)
    end
end

local function DumpVisibleFolders(gui)
    if not gui or type(gui.ShF) ~= "table" then
        Print("No active Guide folder table was found. Open or move the Carbonite map, then retry.")
        return
    end

    local count = 0
    local matches = 0
    Print("active Guide entries:")
    for shT, fol in pairs(gui.ShF) do
        count = count + 1
        local match = IsFlightMasterEntry(shT, fol)
        if match then matches = matches + 1 end
        Print((match and "MATCH " or "      ") .. Describe(shT, fol))
    end
    Print(string.format("dump complete: %d entries, %d flight-master candidates", count, matches))
end

local function Install()
    if Test.installed then return true end
    if not Nx or not Nx.Map or not Nx.Map.Gui or type(Nx.Map.Gui.UMI1) ~= "function" then
        return false
    end

    Test.originalUMI1 = Nx.Map.Gui.UMI1
    Nx.Map.Gui.UMI1 = function(self, ...)
        local removed = {}

        if type(self.ShF) == "table" then
            for shT, fol in pairs(self.ShF) do
                if IsFlightMasterEntry(shT, fol) then
                    if not Test.printedMatches[shT] then
                        Test.printedMatches[shT] = true
                        Print("identified candidate: " .. Describe(shT, fol))
                    end
                    if Test.hideFlightMasters then
                        removed[shT] = fol
                        self.ShF[shT] = nil
                    end
                end
            end
        end

        local results = { pcall(Test.originalUMI1, self, ...) }

        for shT, fol in pairs(removed) do
            self.ShF[shT] = fol
        end

        local ok = table.remove(results, 1)
        if not ok then
            Print("renderer error: " .. tostring(results[1]))
            return
        end
        return unpack(results)
    end

    Test.installed = true
    Print("v" .. Test.VERSION .. " installed. Type /cpoitest dump")
    return true
end

SLASH_CARBONITEPOITEST1 = "/cpoitest"
SlashCmdList.CARBONITEPOITEST = function(message)
    local command = Lower(message):match("^%s*(.-)%s*$")

    if command == "dump" then
        DumpVisibleFolders(Nx and Nx.Map and Nx.Map.Gui)
    elseif command == "hide" then
        Test.hideFlightMasters = true
        Print("Flight Master candidate filtering ON")
        RefreshMaps()
    elseif command == "show" then
        Test.hideFlightMasters = false
        Print("Flight Master candidate filtering OFF")
        RefreshMaps()
    elseif command == "status" then
        Print("filter is " .. (Test.hideFlightMasters and "ON" or "OFF"))
    else
        Print("commands: /cpoitest dump, /cpoitest hide, /cpoitest show, /cpoitest status")
    end
end

_G.CarbonitePOITest = Test

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
