local External = {
    API_VERSION = 1,
    providers = {},
    activeFrames = {},
    installed = false,
    originalUpI = nil,
    originalUMI1 = nil,
    nativeAvailableQuestGivers = true,
    lastMap = nil,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite API|r: " .. tostring(message))
end

local function InstallExternalTooltip(frame)
    if frame.NxExternalTooltipInstalled then return end
    frame.NxExternalTooltipInstalled = true

    frame:HookScript("OnEnter", function(self)
        local tip = self.NxExternalTooltip
        if not tip or tip == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 5)
        if Nx and type(Nx.STT) == "function" then
            Nx:STT(tip)
        else
            GameTooltip:SetText(tip, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    frame:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

local function ClearFrame(frame)
    if not frame then return end
    frame:Hide()
    frame.NXType = nil
    frame.NXData = nil
    frame.NxT = nil
    frame.NxExternalTooltip = nil
    frame.NxExternalProvider = nil
end

local function HideFrames(name)
    local frames = External.activeFrames[name]
    if not frames then return end
    for _, frame in ipairs(frames) do ClearFrame(frame) end
    External.activeFrames[name] = {}
end

local function SafeProviderCall(name, provider, method, ...)
    local fn = provider and provider[method]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, provider, ...)
    if not ok then
        Print(name .. " " .. method .. " error: " .. tostring(result))
        return nil
    end
    return result
end

local function DrawProvider(name, provider, map)
    HideFrames(name)
    if not provider or provider.enabled == false or type(provider.GetMarkers) ~= "function" then return end
    if not map or type(map.GWP) ~= "function" or type(map.GIS) ~= "function" or type(map.CFW) ~= "function" then return end

    local markers = SafeProviderCall(name, provider, "GetMarkers")
    if type(markers) ~= "table" then return end

    local frames = {}
    External.activeFrames[name] = frames
    local baseSize = 16 * (map.INS or 1)

    for _, marker in ipairs(markers) do
        local mapId = tonumber(marker.carboniteMapId or marker.carboniteMapID)
        local x, y = tonumber(marker.x), tonumber(marker.y)
        if mapId and x and y then
            local wx, wy = map:GWP(mapId, x, y)
            local style = SafeProviderCall(name, provider, "GetStyle", marker) or {}
            local size = baseSize * (tonumber(style.scale) or 1)
            local frame = map:GIS(4)
            if frame and map:CFW(frame, wx, wy, size, size, 0) then
                local tooltip = SafeProviderCall(name, provider, "GetTooltip", marker) or marker.title
                frame.NXType = 9800
                frame.NXData = marker
                frame.NxT = tooltip
                frame.NxExternalTooltip = tooltip
                frame.NxExternalProvider = name
                InstallExternalTooltip(frame)
                frame.tex:SetTexture(style.texture or "Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaim")
                frame.tex:SetVertexColor(style.r or 1, style.g or .82, style.b or 0, 1)
                frames[#frames + 1] = frame
            end
        end
    end
end

function External:GetAPIVersion()
    return self.API_VERSION
end

function External:RegisterExternalMarkerProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "provider name required")
    assert(type(provider) == "table", "provider table required")
    assert(type(provider.GetMarkers) == "function", "provider.GetMarkers required")
    self.providers[name] = provider
    self.activeFrames[name] = self.activeFrames[name] or {}
    return true
end

function External:UnregisterExternalMarkerProvider(name)
    HideFrames(name)
    self.providers[name] = nil
end

function External:GetExternalMarkerProvider(name)
    return self.providers[name]
end

function External:RefreshExternalMarkers(name)
    local map = self.lastMap
    if not map then return false end
    if name then
        DrawProvider(name, self.providers[name], map)
    else
        for providerName, provider in pairs(self.providers) do
            DrawProvider(providerName, provider, map)
        end
    end
    return true
end

function External:SetNativeAvailableQuestGiversEnabled(enabled)
    self.nativeAvailableQuestGivers = enabled and true or false
end

function External:IsNativeAvailableQuestGiversEnabled()
    return self.nativeAvailableQuestGivers
end

function External:SetExternalTarget(providerName, marker)
    local map = self.lastMap
    local mapId = marker and tonumber(marker.carboniteMapId or marker.carboniteMapID)
    local x, y = marker and tonumber(marker.x), marker and tonumber(marker.y)
    if not map or not mapId or not x or not y
        or type(map.GWP) ~= "function" or type(map.SeT3) ~= "function" or type(map.GoP) ~= "function"
    then
        return false
    end

    local wx, wy = map:GWP(mapId, x, y)
    local markerId = tostring(marker.id or marker.questId or "target")
    local title = tostring(marker.title or marker.giverName or markerId)
    map:SeT3("Guide", wx, wy, wx, wy, false, tostring(providerName) .. ":" .. markerId, title, false, mapId)
    map:GoP()
    return true
end

function External:DispatchExternalMarkerAction(providerName, action, marker)
    local provider = self.providers[providerName]
    if not provider then return false end
    if type(provider.OnAction) == "function" then
        local result = SafeProviderCall(providerName, provider, "OnAction", action, marker, self)
        if result ~= nil then return result and true or false end
    end
    if action == "TRACK" or action == "GOTO" then
        return self:SetExternalTarget(providerName, marker)
    end
    return false
end

local function InstallMapRenderer()
    if External.installed or not Nx or not Nx.Que or type(Nx.Que.UpI) ~= "function" then
        return External.installed
    end

    External.originalUpI = Nx.Que.UpI
    Nx.Que.UpI = function(self, map, ...)
        External.lastMap = map
        local results = { External.originalUpI(self, map, ...) }
        for name, provider in pairs(External.providers) do DrawProvider(name, provider, map) end
        return unpack(results)
    end

    if Nx.Map and Nx.Map.Gui and type(Nx.Map.Gui.UMI1) == "function" then
        External.originalUMI1 = Nx.Map.Gui.UMI1
        Nx.Map.Gui.UMI1 = function(self, ...)
            if External.nativeAvailableQuestGivers or type(self.ShF) ~= "table" then
                return External.originalUMI1(self, ...)
            end

            local removed = {}
            for key, value in pairs(self.ShF) do
                if type(key) == "string" and string.byte(key, 1) == 38 then
                    removed[key] = value
                    self.ShF[key] = nil
                end
            end

            local results = { pcall(External.originalUMI1, self, ...) }
            for key, value in pairs(removed) do self.ShF[key] = value end
            local ok = table.remove(results, 1)
            if not ok then
                Print("native quest-giver render error: " .. tostring(results[1]))
                return
            end
            return unpack(results)
        end
    end

    External.installed = true
    Print("external marker API v" .. External.API_VERSION .. " installed")
    return true
end

_G.CarboniteExternalMarkerAPI = External

local loader = CreateFrame("Frame")
loader.elapsed = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= .5 then
        self.elapsed = 0
        InstallMapRenderer()
    end
end)
