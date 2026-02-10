-- .luacheckrc for Skada
std = "lua51"

globals = {
    -- WoW Globals
    "issecretvalue", "canaccessvalue", "C_DamageMeter", "ChatFontNormal",
    "IsInPVP", "UIParent", "CreateFrame", "LibStub", "UnitGUID", "C_Spell",
    "NORMAL_FONT_COLOR", "GameTooltip", "InterfaceOptionsFrame_OpenToCategory",
    "Settings", "GetSpellInfo", "GetSpellLink", "GetSpellTexture", "wipe",
    "tinsert", "tremove", "unpack", "Enum", "GetPowerTypeInfo", "UnitPower",
    "UnitPowerMax", "UnitPowerType", "GetSpellCount", "GetSpellPowerCost",
    "GetSpellBaseDamage", "CLASS_ICON_TCOORDS", "GetCursorPosition",
    "IsShiftKeyDown", "IsControlKeyDown", "UnitName", "UnitClass",
    "UnitIsPlayer", "UnitLevel", "InCombatLockdown", "GetTime", "time",
    "GetScreenWidth", "GetScreenHeight", "GetBuildInfo", "GetNumSubgroupMembers",
    "GetNumGroupMembers", "UnitExists", "UnitIsUnit", "UnitInParty",
    "UnitInRaid", "UnitIsDeadOrGhost", "UnitIsFriend", "UnitIsEnemy",
    "UnitAffectingCombat", "GetZoneText", "GetInstanceInfo", "SlashCmdList",
    "hash_Servant22", "BackdropTemplateMixin", "GetUnitName", "UnitHealth",
    "UnitHealthMax", "UnitGroupRolesAssigned", "UnitCastingInfo", "UnitChannelInfo",
    "GetManaRegen", "GetCombatRating", "GetCombatRatingBonus", "GetCritChance",
    "GetSpellCritChance", "GetRangedCritChance", "GetMeleeHaste", "GetRangedHaste",
    "GetSpellHaste", "GetMasteryEffect", "GetArmorPenetration", "GetVersatilityBonus",
    "GetItemInfo", "GetItemIcon", "GetInventoryItemLink", "GetInventoryItemID",
    "GetInventoryItemTexture", "GetInventoryItemCount", "GetContainerItemLink", "GetContainerItemID",
    "GetContainerItemTexture", "StaticPopup_Show", "StaticPopup_Hide",
    "PlaySound", "PlaySoundFile", "UIFrameFadeIn", "UIFrameFadeOut", "GetAddOnMetadata",
    "IsInInstance", "IsInRaid", "GetRaidRosterInfo", "SendChatMessage", "UnitIsFeignDeath",
    "DEFAULT_CHAT_FRAME", "UnitDetailedThreatSituation", "WorldFrame", "AceGUIWidgetLSMlists",
    "ChatEdit_GetActiveWindow", "ChatEdit_InsertLink", "ChatFrame_OpenChat",
    "CombatLog_Color_ColorArrayBySchool", "CreateFont", "RAID_CLASS_COLORS", "ElvUI",
    "GetScreenResolutions", "GetCurrentResolution", "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton", "ToggleDropDownMenu", "GetBindingFromClick",
    "BATTLENET_OPTIONS_LABEL", "GetChannelList", "strlenutf8", "strtrim",
    "BNet_GetBNetIDAccount", "APPLY", "ReloadUI", "InterfaceOptions_AddCategory",
    "IsInGroup", "SecondsToTime", "date", "UpdateAddOnCPUUsage", "GetFunctionCPUUsage",
    "LE_PARTY_CATEGORY_INSTANCE", "BNSendWhisper", "SkadaPerCharDB", "CloseWindows",
    "SLASH_SKADA1", "CUSTOM_CLASS_COLORS", "math", "floor", "min", "max",
    "CLOSE", "CloseDropDownMenus", "UIDROPDOWNMENU_MENU_VALUE",
    "_G", "setmetatable", "getmetatable", "rawequal", "rawget", "rawset",

    -- Skada specific
    "Skada",
    "L"
}

-- Ignore noise
ignore = {
    "111", -- Setting non-standard global
    "611", -- Whitespace only lines
    "612", -- Trailing whitespace
    "631", -- Line too long
    "211", -- Unused variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Unused value
    "4..", -- All shadowing
    "542", -- Empty if branch
}

exclude_files = {
    "lib/",
    "modules/legacy/"
}
