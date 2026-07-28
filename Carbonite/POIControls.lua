local Test = {
    VERSION = 3,
    hideFlightMasters = false,
    installed = false,
    originalUMI1 = nil,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite POI test|r: " .. tostring(message))
end

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function IsFlightMasterPOI(value)
    local name = strsplit("~", tostring(value or ""))
    return Lower(name) == "flight master"
end

local function RefreshMaps()
    if not Nx or not Nx.Map then return end

    if type(Nx.Map.GeM) == "function" then
        pcall(function()
            local map = Nx.Map:GeM(1)
            if map and map.Gui and type(map.Gui.Upd) == "function" then
                map.Gui:Upd()
            end
        end)
    end
end

local function DumpBuiltInPOIs()
    if not Nx or type(Nx.GPOI) ~= "table" then
        Print("Nx.GPOI was not found")
        return
    end

    Print("built-in Nx.GPOI entries:")
    for index, value in ipairs(Nx.GPOI) do
        Print(string.format("%d: %s%s", index, tostring(value), IsFlightMasterPOI(value) and "  <MATCH>" or ""))
    end
end

local function RemoveFlightMasterPOIs()
    local removed = {}

    if not Nx or type(Nx.GPOI) ~= "table" then
        return removed
    end

    for index = #Nx.GPOI, 1, -1 do
        local value = Nx.GPOI[index]
        if IsFlightMasterPOI(value) then
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

local function Install()
    if Test.installed then return true end
    if not Nx or not Nx.Map or not Nx.Map.Gui or type(Nx.Map.Gui.UMI1) ~= "function" then
        return false
    end

    Test.originalUMI1 = Nx.Map.Gui.UMI1
    Nx.Map.Gui.UMI1 = function(self, ...)
        local removed = {}

        if Test.hideFlightMasters then
            removed = RemoveFlightMasterPOIs()
        end

        local results = { pcall(Test.originalUMI1, self, ...) }
        RestorePOIs(removed)

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
        DumpBuiltInPOIs()
    elseif command == "hide" then
        Test.hideFlightMasters = true
        Print("built-in Flight Master filtering ON")
        RefreshMaps()
    elseif command == "show" then
        Test.hideFlightMasters = false
        Print("built-in Flight Master filtering OFF")
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
