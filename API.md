# Skada API Documentation

This document describes the Skada API for WoW 12.0+ (Midnight / The War Within).

## Overview

Skada is a modular damage meter that can display any type of data. While Skada's built-in modules use Blizzard's native `C_DamageMeter` API for combat statistics, plugins can collect and display any data they choose.

Modules have full control over:
- What data to collect (events, APIs, custom tracking)
- How to store data (in sets, players, or custom structures)
- How to display data (any format in the dataset)

## Module Types

### Type 1: NativeAPI-Based Modules

Use Blizzard's built-in damage meter data. These are the simplest to implement.

```lua
local _, Skada = ...
local ModuleBase = Skada.ModuleBase

Skada:AddLoadableModule("Damage", nil, function(Skada, L)
    local mod = Skada:NewModule(L["Damage"])
    local DAMAGE_TYPE = 0 -- DamageDone

    function mod:Update(win, set)
        ModuleBase:UpdatePlayerList(win, set, {
            damageType = DAMAGE_TYPE,
            valueKey = "totalAmount",
            rateKey = "amountPerSecond",
            columns = {"Damage", "DPS", "Percent"},
            getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, 1) end,
            includePercent = true
        })
    end

    function mod:OnEnable()
        mod.metadata = {
            showspots = true,
            columns = {Damage = true, DPS = true, Percent = true},
            icon = "Interface\\Icons\\Inv_throwingaxe_01"
        }
        Skada:AddMode(self, L["Damage"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end
end)
```

### Type 2: Custom Data Modules

Collect and store your own data using events or other APIs.

```lua
local _, Skada = ...

Skada:AddLoadableModule("CustomTracker", nil, function(Skada, L)
    local mod = Skada:NewModule(L["Custom Tracker"])
    
    -- Custom data storage
    mod.customData = {}
    
    function mod:OnEnable()
        -- Register for events
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        Skada:AddMode(self, L["Custom Tracker"])
    end
    
    function mod:OnDisable()
        self:UnregisterAllEvents()
        Skada:RemoveMode(self)
    end
    
    function mod:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
        -- Track custom metrics
        if not self.customData[spellID] then
            self.customData[spellID] = 0
        end
        self.customData[spellID] = self.customData[spellID] + 1
    end
    
    function mod:PLAYER_REGEN_ENABLED()
        -- Combat ended, process data
    end
    
    function mod:Update(win, set)
        -- Display custom data
        local nr = 1
        for spellID, count in pairs(self.customData) do
            local d = win.dataset[nr] or {}
            win.dataset[nr] = d
            
            d.id = spellID
            d.label = C_Spell.GetSpellInfo(spellID).name
            d.value = count
            d.valuetext = tostring(count)
            d.icon = Skada:GetSpellIcon(spellID)
            
            nr = nr + 1
        end
    end
end)
```

### Type 3: Hybrid Modules

Use NativeAPI for some data and supplement with custom tracking.

```lua
function mod:Update(win, set)
    -- Start with NativeAPI data
    ModuleBase:UpdatePlayerList(win, set, {
        damageType = DAMAGE_TYPE,
        valueKey = "totalAmount",
        columns = {"Damage", "CustomMetric"}
    })
    
    -- Add custom column data
    for i, data in ipairs(win.dataset) do
        local customValue = self:GetCustomMetric(data.id)
        data.valuetext = data.valuetext .. " (" .. customValue .. ")"
    end
end
```

## Data Collection Methods

### Using NativeAPI (Recommended for Combat Stats)

For damage, healing, and other combat metrics:

```lua
-- Get session view
local view = Skada.NativeAPI:GetSessionView(set, damageType)

-- Access player data
for _, player in pairs(view.combatSources) do
    local name = player.name
    local damage = player.totalAmount
    local dps = player.amountPerSecond
end

-- Get spell breakdown
local spells = Skada.NativeAPI:GetPlayerSpells(playerID, set, damageType)
```

### Using Events

For custom tracking:

```lua
function mod:OnEnable()
    -- Combat log events (still available for custom tracking)
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Unit events
    self:RegisterUnitEvent("UNIT_AURA", "player")
    
    -- Player events
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function mod:COMBAT_LOG_EVENT_UNFILTERED(event)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, 
          destGUID, destName, destFlags, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    
    -- Process custom events
    if subevent == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("player") then
        -- Track spell casts
    end
end
```

### Using Other WoW APIs

```lua
-- C_Timer for periodic updates
C_Timer.NewTicker(5, function()
    mod:CheckCustomCondition()
end)

-- C_QuestLog for quest tracking
local numQuests = C_QuestLog.GetNumQuestLogEntries()

-- C_Container for bag tracking
local freeSlots = C_Container.GetContainerNumFreeSlots(0)

-- Any other API that provides useful data
```

## Storing Custom Data

### In the Set Object

Attach data to the current combat set:

```lua
function mod:AddToSet(set, playerGUID, value)
    if not set.customData then
        set.customData = {}
    end
    if not set.customData[playerGUID] then
        set.customData[playerGUID] = 0
    end
    set.customData[playerGUID] = set.customData[playerGUID] + value
end
```

### In the Player Object

Attach data to player entries:

```lua
function mod:AddToPlayer(player, value)
    if not player.customMetric then
        player.customMetric = 0
    end
    player.customMetric = player.customMetric + value
end
```

### Module-Specific Storage

Keep data in the module itself:

```lua
local mod = Skada:NewModule(L["Tracker"])
mod.sessionData = {}
mod.totalData = {}

function mod:Reset()
    mod.sessionData = {}
end
```

## ModuleBase Functions

ModuleBase provides helpers for common patterns, but its use is optional.

### UpdatePlayerList(win, set, options)

Updates a window with a list of players using NativeAPI data.

**Parameters:**
- `win` - Window object
- `set` - Current combat set
- `options` - Table with:
  - `damageType` - NativeAPI damage type constant
  - `valueKey` - Key for the main value (e.g., "totalAmount")
  - `rateKey` - Key for rate value (e.g., "amountPerSecond")
  - `columns` - Table with column names
  - `getRateFunc` - Optional function to calculate rate
  - `includePercent` - Whether to show percentage column

### UpdateSpellList(win, playerid, set, damageType, options)

Updates a window with spell breakdown for a player.

### UpdateSimpleList(win, set, options)

Updates a window without rates. Used for Dispels, Interrupts, etc.

### Tooltip Helpers

```lua
-- Detailed tooltip with top spells
local tooltip = ModuleBase:CreatePlayerTooltip({
    damageType = 0,
    valueKey = "totalAmount",
    rateKey = "amountPerSecond",
    labelDamage = L["Damage done"],
    labelRate = L["DPS"],
    spellValueKey = "totalAmount"
})

-- Simple tooltip
local simpleTooltip = ModuleBase:CreateSimpleTooltip(L["Total"])

-- Damage share tooltip
local shareTooltip = ModuleBase:CreateDamageShareTooltip({
    damageType = 0,
    labelShare = L["Damage share"]
})
```

## NativeAPI Reference

### Damage Types

- `0` - DamageDone
- `1` - Dps
- `2` - HealingDone
- `3` - Hps
- `4` - Absorbs
- `5` - Interrupts
- `6` - Dispels
- `7` - DamageTaken
- `8` - AvoidableDamageTaken

### Key Functions

```lua
-- Get session data
local view = Skada.NativeAPI:GetSessionView(set, damageType)

-- Get current or total session
local current = Skada.NativeAPI:GetCurrentSession()
local total = Skada.NativeAPI:GetTotalSession()

-- Get specific types
local healing = Skada.NativeAPI:GetHealingDoneSession()
local damageTaken = Skada.NativeAPI:GetDamageTakenSession()

-- Get player spells
local spells = Skada.NativeAPI:GetPlayerSpells(playerID, set, damageType)

-- Reset all sessions
Skada.NativeAPI:ResetAllSessions()
```

## Window Dataset

Regardless of data source, modules populate `win.dataset` with entries:

```lua
function mod:Update(win, set)
    -- Clear or reuse existing dataset entries
    local nr = 1
    
    -- Add entries
    for id, data in pairs(myData) do
        local d = win.dataset[nr] or {}
        win.dataset[nr] = d
        
        -- Required fields
        d.id = id                    -- Unique identifier
        d.label = data.name          -- Display name
        d.value = data.value         -- Numeric value (for sorting/bars)
        
        -- Optional fields
        d.class = data.class         -- Player class (for color)
        d.role = data.role           -- Tank/Healer/Damage
        d.icon = data.icon           -- Icon texture path
        d.order = nr                 -- Position order
        d.valuetext = formattedText  -- Display text
        
        nr = nr + 1
    end
    
    -- Set max value for bar scaling
    win.metadata.maxvalue = maxValue
end
```

## Module Metadata

```lua
mod.metadata = {
    -- Enable click-through to another module
    click1 = detailModule,
    click2 = anotherModule,
    
    -- Show spot numbers (1, 2, 3...)
    showspots = true,
    
    -- Sort by order instead of value
    ordersort = false,
    
    -- Column visibility (for modules using ModuleBase)
    columns = {
        Damage = true,
        DPS = true,
        Percent = true
    },
    
    -- Tooltip handler
    tooltip = tooltipFunction,
    
    -- Post-tooltip handler
    post_tooltip = postTooltipFunction,
    
    -- Icon for mode
    icon = "Interface\\Icons\\icon_path"
}
```

## Set and Player Lifecycle

### Set Lifecycle

```lua
-- New set created (combat started)
function mod:AddSetAttributes(set)
    -- Initialize custom set data
    set.myCustomData = {}
end

-- Set completed (combat ended)
function mod:SetComplete(set)
    -- Finalize calculations
end
```

### Player Lifecycle

```lua
-- New player added to set
function mod:AddPlayerAttributes(player, set)
    -- Initialize custom player data
    player.myCustomMetric = 0
end
```

## Secret Values

WoW 12.0 uses "Secret Values" during active combat to prevent automation. These cannot be used in math operations.

```lua
local SecretHelper = Skada.SecretHelper

-- Check if value is secret
if SecretHelper:IsSecret(val) then
    -- Handle display without math
end

-- Get safe numeric value (0 for secrets)
local safe = SecretHelper:SafeNumber(val)

-- Safe formatting
local text = Skada:FormatNumberSecret(val)
```

## Events

```lua
-- Combat lifecycle
Skada:RegisterMessage("COMBAT_START", function() end)
Skada:RegisterMessage("COMBAT_END", function() end)

-- Set changes
Skada:RegisterMessage("SET_CHANGED", function(set) end)

-- Window updates
Skada:RegisterMessage("WINDOW_UPDATE", function(window) end)
```

## Complete Example: Custom Module

```lua
local _, Skada = ...

Skada:AddLoadableModule("CooldownTracker", nil, function(Skada, L)
    local mod = Skada:NewModule(L["Cooldown Tracker"])
    
    -- Track cooldown usage
    mod.cooldowns = {}
    
    function mod:OnEnable()
        -- Register for spell cast events
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        
        -- Add set/player attribute handlers
        self.AddSetAttributes = function(set)
            set.cooldowns = {}
        end
        
        self.AddPlayerAttributes = function(player, set)
            player.cooldowns = {}
        end
        
        mod.metadata = {
            showspots = true,
            icon = "Interface\\Icons\\Spell_Holy_BorrowedTime"
        }
        
        Skada:AddMode(self, L["Cooldowns"])
    end
    
    function mod:OnDisable()
        self:UnregisterAllEvents()
        Skada:RemoveMode(self)
    end
    
    function mod:COMBAT_LOG_EVENT_UNFILTERED()
        local _, event, _, sourceGUID, sourceName, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
        
        if event == "SPELL_CAST_SUCCESS" then
            -- Check if it's a major cooldown
            if self:IsMajorCooldown(spellID) then
                local set = Skada.current or Skada.total
                if set and set.cooldowns then
                    if not set.cooldowns[sourceGUID] then
                        set.cooldowns[sourceGUID] = {}
                    end
                    table.insert(set.cooldowns[sourceGUID], {
                        spellID = spellID,
                        time = GetTime()
                    })
                end
            end
        end
    end
    
    function mod:IsMajorCooldown(spellID)
        -- Define major cooldowns
        local cooldowns = {
            [45438] = true, -- Ice Block
            [642] = true,   -- Divine Shield
            -- etc
        }
        return cooldowns[spellID]
    end
    
    function mod:Update(win, set)
        if not set or not set.cooldowns then return end
        
        local nr = 1
        for guid, cds in pairs(set.cooldowns) do
            local player = Skada:find_player(set, guid)
            if player then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d
                
                d.id = guid
                d.label = player.name
                d.value = #cds
                d.class = player.class
                d.valuetext = string.format("%d cooldowns used", #cds)
                
                nr = nr + 1
            end
        end
        
        win.metadata.maxvalue = nr - 1
    end
end)
```

## Tips

1. **Use NativeAPI when possible** - It's efficient and handles secret values
2. **Store data in sets** - Survives between updates and can be viewed later
3. **Clean up on disable** - Unregister events and remove modes
4. **Handle nil values** - Always check if set/player exists
5. **Use localization** - All user-facing strings should use `L[]`
6. **Test with secrets** - Ensure your module works during active combat
