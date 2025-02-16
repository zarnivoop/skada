std = "lua51"
max_line_length = false
codes = true
exclude_files = {
	".luacheckrc",
	"lib",
}
ignore = {
	"11./SLASH_.*", -- Setting an undefined (Slash handler) global variable
	"11./BINDING_.*", -- Setting an undefined (Keybinding header) global variable
	"211", -- Unused local variable
	"212", -- Unused argument
	"213", -- Unused loop variable
	"311", -- Value assigned to a local variable is unused
	"312", -- Value of an argument is unused
	"42.", -- Shadowing a local variable, an argument, a loop variable.
	"43.", -- Shadowing an upvalue, an upvalue argument, an upvalue loop variable.
}
globals = {
	-- Third-party
	"LibStub",
	"Skada",
	"SkadaPerCharDB",
	"AceGUIWidgetLSMlists",
	"CUSTOM_CLASS_COLORS",
	"ElvUI",

	-- Old style enum
	"LE_PARTY_CATEGORY_INSTANCE",

	-- Frames/tables
	"DEFAULT_CHAT_FRAME",
	"GameTooltip",
	"RAID_CLASS_COLORS",
	"SlashCmdList",
	"UIParent",
	"UIDROPDOWNMENU_MENU_VALUE",
	"WorldFrame",

	-- Functions
	"BNet_GetBNetIDAccount",
	"BNSendWhisper",
	"C_TooltipInfo",
	"ChatEdit_GetActiveWindow",
	"ChatEdit_InsertLink",
	"ChatFrame_OpenChat",
	"CloseDropDownMenus",
	"CloseWindows",
	"CombatLogGetCurrentEventInfo",
	"CombatLog_Color_ColorArrayBySchool",
	"CreateFont",
	"CreateFrame",
	"DeclineName",
	"GetAddOnMemoryUsage",
	"GetBindingFromClick",
	"GetBuildInfo",
	"GetChannelList",
	"GetCurrentResolution",
	"GetCursorPosition",
	"GetFunctionCPUUsage",
	"GetNumDeclensionSets",
	"GetNumGroupMembers",
	"GetPlayerInfoByGUID",
	"GetRaidRosterInfo",
	"GetSchoolString",
	"GetScreenHeight",
	"GetScreenResolutions",
	"GetScreenWidth",
	"GetSpellInfo",
	"GetSpellLink",
	"GetTime",
	"GetZonePVPInfo",
	"InCombatLockdown",
	"InterfaceOptions_AddCategory",
	"IsControlKeyDown",
	"IsInGroup",
	"IsInInstance",
	"IsInRaid",
	"IsShiftKeyDown",
	"PlaySoundFile",
	"ReloadUI",
	"SecondsToTime",
	"SendChatMessage",
	"ToggleDropDownMenu",
	"TooltipUtil",
	"UIDropDownMenu_AddButton",
	"UIDropDownMenu_CreateInfo",
	"UnitAffectingCombat",
	"UnitClass",
	"UnitDetailedThreatSituation",
	"UnitExists",
	"UnitGroupRolesAssigned",
	"UnitGUID",
	"UnitHealth",
	"UnitHealthMax",
	"UnitInRaid",
	"UnitIsDeadOrGhost",
	"UnitIsFeignDeath",
	"UnitIsFriend",
	"UnitName",
	"UnitSex",
	"UpdateAddOnCPUUsage",
	"UpdateAddOnMemoryUsage",
	"bit",
	"date",
	"math",
	"max",
	"min",
	"random",
	"string",
	"strlenutf8",
	"strtrim",
	"time",
	"tinsert",
	"table",
	"tremove",
	"wipe",

	-- Strings
	"ABSORB",
	"APPLY",
	"BATTLENET_OPTIONS_LABEL",
	"CLASS_ICON_TCOORDS",
	"CLOSE",
	"COMBATLOG_OBJECT_AFFILIATION_MINE",
	"COMBATLOG_OBJECT_AFFILIATION_OUTSIDER",
	"COMBATLOG_OBJECT_AFFILIATION_PARTY",
	"COMBATLOG_OBJECT_AFFILIATION_RAID",
	"COMBATLOG_OBJECT_CONTROL_PLAYER",
	"COMBATLOG_OBJECT_REACTION_FRIENDLY",
	"COMBATLOG_OBJECT_REACTION_MASK",
	"COMBATLOG_OBJECT_TYPE_GUARDIAN",
	"COMBATLOG_OBJECT_TYPE_PET",
	"UNKNOWN",
}
