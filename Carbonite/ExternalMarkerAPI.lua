local External = {
    providers = {},
    activeFrames = {},
    installed = false,
    originalUpI = nil,
    originalUMI1 = nil,
    nativeAvailableQuestGivers = true,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffCarbonite API|r: " .. tostring(message))
end

local function HideFrames(name)
    local frames = External.activeFrames[name]
    if not frames then return end
    for _, frame in ipairs(frames) do
        if frame then
            frame:Hide()
            frame.NXType = nil
            frame.NXData = nil
            frame.NxT = nil
        end
    end
    External.activeFrames[name] = {}
end

local function DrawProvider(name, provider, map)
    HideFrames(name)
    if not provider or provider.enabled == false or type(provider.GetMarkers) ~= "function" then
        return
    end
    if not map or type(map.GWP) ~= "function" or type(map.GIS) ~= "function" or type(map.CFW) ~= "function" then
        return
    end

    local ok, markers = pcall(provider.GetMarkers, provider)
    if not ok or type(markers) ~= "table" then
        if not ok then Print(name .. " marker provider error: " .. tostring(markers)) end
        return
    end

    local frames = {}
    External.activeFrames[name] = frames
    local baseSize = 16 * (map.INS or 1)

    for _, marker in ipairs(markers) do
        if marker.carboniteMapId and marker.x and marker.y then
            local wx, wy = map:GWP(marker.carboniteMapId, marker.x, marker.y)
            local style = type(provider.GetStyle) == "function" and provider:GetStyle(marker) or nil
            style = style or {}
            local size = baseSize * (style.scale or 1)
            local frame = map:GIS(4)
            if frame and map:CFW(frame, wx, wy, size, size, 0) then
                frame.NXType = 9900
                frame.NXData = marker
                frame.NxT = type(provider.GetTooltip) == "function" and provider:GetTooltip(marker) or marker.title
                frame.tex:SetTexture(style.texture or "Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaim")
                frame.tex:SetVertexColor(style.r or 1, style.g or .82, style.b or 0, 1)
                frames[#frames + 1] = frame
            end
        end
    end
end

function External:RegisterExternalMarkerProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "provider name required")
    assert(type(provider) == "table", "provider table required")
    self.providers[name] = provider
    self.activeFrames[name] = self.activeFrames[name] or {}
    return true
end

function External:UnregisterExternalMarkerProvider(name)
    HideFrames(name)
    self.providers[name] = nil
end

function External:RefreshExternalMarkers(name)
    if name then
        local map = Nx and Nx.Map and Nx.Map[1]
        if map then DrawProvider(name, self.providers[name], map) end
        return
    end
    local map = Nx and Nx.Map and Nx.Map[1]
    if map then
        for providerName, provider in pairs(self.providers) do
            DrawProvider(providerName, provider, map)
        end
    end
end

function External:SetNativeAvailableQuestGiversEnabled(enabled)
    self.nativeAvailableQuestGivers = enabled and true or false
end

function External:IsNativeAvailableQuestGiversEnabled()
    return self.nativeAvailableQuestGivers
end

local function InstallMapRenderer()
    if External.installed or not Nx or not Nx.Que or type(Nx.Que.UpI) ~= "function" then
        return External.installed
    end

    External.originalUpI = Nx.Que.UpI
    Nx.Que.UpI = function(self, map, ...)
        local results = { External.originalUpI(self, map, ...) }
        for name, provider in pairs(External.providers) do
            DrawProvider(name, provider, map)
        end
        return unpack(results)
    end

    -- Carbonite owns native available-quest visibility here. The bridge only
    -- requests the setting through the public API.
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
    Print("external marker API installed")
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
