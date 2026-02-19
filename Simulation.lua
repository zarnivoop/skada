local _, Skada = ...
local Simulation = {}
Skada.Simulation = Simulation

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

-- Classes available in WoW
local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"}

-- Mock names for participants
-- Mock names for participants
local mockNames = {
	"Catman", "Aethelm", "Meowrice", "Brynja", "Clawdia", "Cedric", "Furdinand", "Dalla", "Purrcy", "Eirik",
	"Pawla", "Finna", "Catherine", "Gunnar", "Meowly", "Hilda", "Paws", "Ivar", "Clawed", "Jorra",
	"Purrsephone", "Kael", "Catastrophe", "Lana", "Meowgret", "Meric", "Purrceval", "Nyssa", "Meowington", "Oryn",
	"Caticus", "Phaedra", "Purrlock", "Quinn", "Clawster", "Rurik", "Meowchael", "Sif", "Purgie", "Torin"
}

-- Roles mapping
local classRoles = {
	WARRIOR = "TANK", PALADIN = "HEALER", HUNTER = "DAMAGER", ROGUE = "DAMAGER",
	PRIEST = "HEALER", DEATHKNIGHT = "TANK", SHAMAN = "DAMAGER", MAGE = "DAMAGER",
	WARLOCK = "DAMAGER", MONK = "TANK", DRUID = "HEALER", DEMONHUNTER = "DAMAGER",
	EVOKER = "HEALER"
}

-- Common spell IDs for mock data (WoW real spell IDs)
local mockSpells = {
	[0] = {6603, 116, 585, 1752, 122470}, -- Auto Attack, Frostbolt, Smite, Sinister Strike, Touch of Death
	[2] = {139, 2061, 774, 18562, 331}, -- Renew, Flash Heal, Rejuvenation, Swiftmend, Healing Wave
	[5] = {1766, 2139, 6552, 116705, 183752}, -- Kick, Counterspell, Pummel, Spear Hand Strike, Disrupt
	[6] = {527, 88423, 115450, 77130, 213634}, -- Purify, Nature's Cure, Detox, Purify Spirit, Purify (Evoker)
	[7] = {6603, 133, 3143, 116, 589} -- Melee, Fireball, Cleave, Frostbolt, Shadow Word: Pain
}

-- Current simulated state
Simulation.active = false
Simulation.groupSize = 40
Simulation.participants = {}

function Simulation:SetEnabled(enabled)
	self.active = enabled
	if enabled then
		self:GenerateParticipants()
	else
		self.participants = {}
	end
	Skada:UpdateDisplay(true)
end

function Simulation:SetGroupSize(size)
	self.groupSize = size
	if self.active then
		self:GenerateParticipants()
	end
	Skada:UpdateDisplay(true)
end

function Simulation:GenerateParticipants()
	self.participants = {}
	for i = 1, self.groupSize do
		local class = classes[math.random(#classes)]
		local role = classRoles[class] or "DAMAGER"
		local name = mockNames[((i - 1) % #mockNames) + 1]
		if i > #mockNames then
			name = name .. " " .. math.floor(i / #mockNames)
		end
		
		local p = {
			guid = "sim-player-" .. i,
			sourceGUID = "sim-player-" .. i,
			name = name,
			class = class,
			role = role,
			data = {} -- Data buckets per damageType
		}

		-- Initialize data for common types: 0=Damage, 2=Healing, 5=Interrupts, 6=Dispels, 7=DamageTaken
		for _, typeID in ipairs({0, 2, 5, 6, 7}) do
			local baseVal = 0
			if typeID == 0 then -- Damage
				baseVal = (role == "DAMAGER") and math.random(10000000, 50000000) or math.random(2000000, 8000000)
			elseif typeID == 2 then -- Healing
				baseVal = (role == "HEALER") and math.random(10000000, 40000000) or math.random(500000, 2000000)
			elseif typeID == 7 then -- Damage Taken
				baseVal = (role == "TANK") and math.random(10000000, 60000000) or math.random(1000000, 5000000)
			elseif typeID == 5 or typeID == 6 then -- Interrupts/Dispels
				baseVal = math.random(0, 15)
			end

			local spells = {}
			local spellIDs = mockSpells[typeID] or {0}
			local remaining = baseVal
			for j, spellID in ipairs(spellIDs) do
				local val = (j == #spellIDs) and remaining or math.random(0, remaining)
				spells[spellID] = {spellID = spellID, totalAmount = val}
				remaining = remaining - val
			end

			p.data[typeID] = {
				totalAmount = baseVal,
				amountPerSecond = baseVal / 300, -- Assume 5min session
				spells = spells
			}
		end
		
		self.participants[i] = p
	end
end

-- Simulate updates to the data
function Simulation:Update()
	if not self.active then return end
	
	for i, p in ipairs(self.participants) do
		for typeID, bucket in pairs(p.data) do
			local fluctuation = 0
			if typeID == 0 or typeID == 2 or typeID == 7 then
				fluctuation = math.random(-5000, 5000)
				bucket.amountPerSecond = math.max(100, bucket.amountPerSecond + fluctuation)
				local gain = bucket.amountPerSecond * 0.5 -- timer is 0.5s
				bucket.totalAmount = bucket.totalAmount + gain
				
				-- Update spells
				for _, spell in pairs(bucket.spells) do
					spell.totalAmount = spell.totalAmount + (gain / 5) -- Distribute evenly for simplicity
				end
			elseif math.random() > 0.98 then -- Rare chance for interrupt/dispel
				bucket.totalAmount = bucket.totalAmount + 1
				local spellIDs = mockSpells[typeID]
				local sid = spellIDs[math.random(#spellIDs)]
				bucket.spells[sid].totalAmount = bucket.spells[sid].totalAmount + 1
			end
		end
	end
end

function Simulation:GetMockSession(sessionType, damageType)
	if not self.active then return nil end
	
	damageType = damageType or 0
	local participants = {}
	
	for i, p in ipairs(self.participants) do
		local bucket = p.data[damageType] or p.data[0]
		local p_view = {
			guid = p.guid,
			sourceGUID = p.sourceGUID,
			name = p.name,
			class = p.class,
			role = p.role,
			totalAmount = bucket.totalAmount,
			amountPerSecond = bucket.amountPerSecond,
			rate = bucket.amountPerSecond
		}
		table.insert(participants, p_view)
	end
	
	return {
		sessionID = 999,
		sessionType = sessionType or 1,
		startTime = GetTime() - 300,
		endTime = GetTime(),
		name = L["Simulated Raid"],
		participants = participants,
		combatSources = participants
	}
end

function Simulation:GetMockSource(sourceGUID, damageType)
	if not self.active then return nil end
	
	damageType = damageType or 0
	for _, p in ipairs(self.participants) do
		if p.guid == sourceGUID then
			local bucket = p.data[damageType] or p.data[0]
			return {
				guid = p.guid,
				sourceGUID = p.sourceGUID,
				name = p.name,
				class = p.class,
				role = p.role,
				totalAmount = bucket.totalAmount,
				amountPerSecond = bucket.amountPerSecond,
				combatSpells = bucket.spells,
				spells = bucket.spells
			}
		end
	end
	return nil
end

return Simulation
