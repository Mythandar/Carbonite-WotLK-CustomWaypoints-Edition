# Carbonite External Marker API

`CarboniteExternalMarkerAPI` lets another addon provide markers while Carbonite owns frame allocation, map projection, tooltips, fading, and navigation.

## Version

```lua
CarboniteExternalMarkerAPI:GetAPIVersion() -- currently 1
```

## Register a provider

```lua
local provider = {}

function provider:GetMarkers()
    return {
        {
            id = "example:1",
            carboniteMapId = 2020,
            x = 53.9,
            y = 81.7,
            title = "Example marker",
        }
    }
end

function provider:GetTooltip(marker)
    return marker.title
end

function provider:GetStyle(marker)
    return {
        texture = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaim",
        r = 1,
        g = 0.82,
        b = 0,
        scale = 1,
    }
end

function provider:OnAction(action, marker, carboniteAPI)
    if action == "TRACK" or action == "GOTO" then
        return carboniteAPI:SetExternalTarget("Example", marker)
    end
end

CarboniteExternalMarkerAPI:RegisterExternalMarkerProvider("Example", provider)
```

Required marker fields are `carboniteMapId`, `x`, and `y`.

## Lifecycle

```lua
CarboniteExternalMarkerAPI:RefreshExternalMarkers("Example")
CarboniteExternalMarkerAPI:UnregisterExternalMarkerProvider("Example")
```

Carbonite recycles its own marker frames. Providers must return data records, not frames.

## Navigation

```lua
CarboniteExternalMarkerAPI:SetExternalTarget("Example", marker)
CarboniteExternalMarkerAPI:DispatchExternalMarkerAction("Example", "TRACK", marker)
```

## Native available quests

```lua
CarboniteExternalMarkerAPI:SetNativeAvailableQuestGiversEnabled(false)
local enabled = CarboniteExternalMarkerAPI:IsNativeAvailableQuestGiversEnabled()
```

This option affects Carbonite's native available-quest Guide layer only.
