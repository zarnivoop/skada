local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local mod = Skada:NewModule("DispelMode", "AceEvent-3.0")

mod.name = L["Dispels"]

function mod:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	
	Skada:AddMode(self)
end

function mod:OnDisable()
	Skada:RemoveMode(self)
end

function mod:AddToTooltip(set, tooltip)
 	GameTooltip:AddDoubleLine(L["Dispels"], set.dispells, 1,1,1)
end

-- Called by Skada when a new player is added to a set.
function mod:AddPlayerAttributes(player)
	if not player.dispells then
		player.dispells = 0
		player.interrupts = 0
	end
end

-- Called by Skada when a new set is created.
function mod:AddSetAttributes(set)
	if not set.dispells then
		set.dispells = 0
		set.interrupts = 0
	end
end

function mod:GetSetSummary(set)
	return set.dispells
end

function mod:log_dispell(set, dispell)
	if set then
		local player = Skada:get_player(set, dispell.playerid, dispell.playername)
		if player then
			-- Add to player dispels.
			player.dispells = player.dispells + 1
			
			-- Also add to set total dispels.
			set.dispells = set.dispells + 1
		end
	end
end

function mod:log_interrupt(set, interrupt)
	if set then
		local player = Skada:get_player(set, interrupt.playerid, interrupt.playername)
		if player then
			-- Add to player interrupts.
			player.interrupts = player.interrupts + 1
			
			-- Also add to set total interrupts.
			set.interrupts = set.interrupts + 1
		end
	end
end

local dispell = {}

function mod:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if Skada:IsDataCollectionActive() and srcName and Skada:UnitIsInteresting(srcName) then
	
		if eventtype == 'SPELL_DISPEL' then
			local current = Skada:GetCurrentSet()
			local total = Skada:GetTotalSet()
	
			-- Dispells
			local spellId, spellName, spellSchool, sextraSpellId, sextraSpellName, sextraSchool, auraType = ...
			
			dispell.playerid = srcGUID
			dispell.playername = srcName
			dispell.spellid = spellId
			dispell.spellname = spellName
			dispell.extraspellid = sextraSpellId
			dispell.extraspellname = sextraSpellName		
			
			self:log_dispell(current, dispell)
			self:log_dispell(total, dispell)
		elseif eventtype == 'SPELL_INTERRUPT' then
			local current = Skada:GetCurrentSet()
			local total = Skada:GetTotalSet()
	
			-- Interrupts
			local spellId, spellName, spellSchool, sextraSpellId, sextraSpellName, sextraSchool = ...
			
			dispell.playerid = srcGUID
			dispell.playername = srcName
			dispell.spellid = spellId
			dispell.spellname = spellName
			dispell.extraspellid = sextraSpellId
			dispell.extraspellname = sextraSpellName		
			
			self:log_interrupt(current, dispell)
			self:log_interrupt(total, dispell)
		end
	end

end

function mod:Update(set)
	-- Calculate the highest number.
	-- How to get rid of this iteration?
	local maxdispells = 0
	for i, player in ipairs(set.players) do
		if player.dispells > maxdispells then
			maxdispells = player.dispells
		end
	end
	
	-- For each player in the set, see if we have a bar already.
	-- If so, update values, else create bar.
	for i, player in ipairs(set.players) do
		if player.dispells > 0 then
			local bar = Skada:GetBar(tostring(player.id))
			if bar then
				bar:SetMaxValue(maxdispells)
				bar:SetValue(player.dispells)
			else
				bar = Skada:CreateBar(tostring(player.id), player.name, player.dispells, maxdispells, nil, false)
				bar:EnableMouse()
				bar:SetScript("OnMouseDown", function(bar, button) if button == "RightButton" then Skada:RightClick() end end)
				local color = Skada.classcolors[player.class] or Skada:GetDefaultBarColor()
				bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
				
			end
			bar:SetTimerLabel(tostring(player.dispells))
		end
	end
		
	-- Sort the possibly changed bars.
	Skada:SortBars()
end