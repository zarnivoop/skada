local _, Skada = ...
Skada:AddLoadableModule("Threat", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Threat then return end

	local mod = Skada:NewModule(L["Threat"])
	local media = LibStub("LibSharedMedia-3.0")
	local format = string.format
	local time = time
	local UnitExists = UnitExists
	local UnitName = UnitName
	local UnitIsFriend = UnitIsFriend
	local UnitDetailedThreatSituation = _G.UnitDetailedThreatSituation
	local PlaySoundFile = PlaySoundFile
	local CreateFrame = CreateFrame
	local UIParent = UIParent
	local WorldFrame = WorldFrame
	local InCombatLockdown = InCombatLockdown
	local random = math.random
	local tinsert = table.insert

	local last_warn = 0
	local dataset_index = 1

	-- Find the best target to track threat on
	local function find_threat_target()
		if UnitExists("target") and not UnitIsFriend("player", "target") then
			return "target"
		elseif Skada.db.profile.modules.threatfocustarget then
			if UnitExists("focus") and not UnitIsFriend("player", "focus") then
				return "focus"
			elseif UnitExists("focustarget") and not UnitIsFriend("player", "focustarget") then
				return "focustarget"
			end
		end
		if UnitExists("target") and UnitIsFriend("player", "target") and UnitExists("targettarget") and not UnitIsFriend("player", "targettarget") then
			return "targettarget"
		end
		return nil
	end

	local function readable(value)
		return value ~= nil and not issecretvalue(value)
	end

	-- Add unit's threat data to the dataset. UnitDetailedThreatSituation returns
	-- raw threat plus the encoded percentages used by Forever's threat list;
	-- UnitThreatSituation only gives the percentage and leaves TPS/raw blank.
	local function add_threat_data(win, unit, target)
		if not UnitDetailedThreatSituation or not unit or not UnitExists(unit) then return end

		local isTanking, _status, scaled, rawPct, raw = UnitDetailedThreatSituation(unit, target)
		if not readable(raw) or type(raw) ~= "number" or raw <= 0 then
			return nil
		end
		if not readable(scaled) or type(scaled) ~= "number" then scaled = nil end
		if not readable(rawPct) or type(rawPct) ~= "number" then rawPct = nil end
		if not readable(isTanking) or type(isTanking) ~= "boolean" then isTanking = nil end

		local d = win.dataset[dataset_index] or {}
		win.dataset[dataset_index] = d

		d.id = unit
		d.label = UnitName(unit)
		d.class = select(2, UnitClass(unit))
		d.role = UnitGroupRolesAssigned(unit)
		d.isTanking = isTanking
		d.isPlayer = UnitIsUnit(unit, "player")
		d.value = raw
		d.valuetext = nil
		d.valueText3 = nil
		d.threat = raw
		d.threatPct = rawPct or scaled
		d.scaled = scaled
		d.percent = d.threatPct
		d.tps = nil

		dataset_index = dataset_index + 1
		return d.value
	end

	-- Check if we should warn the player about threat
	local function check_threat_warning(self, data, maxvalue)
		if type(data) ~= "table" or time() - last_warn <= 2 then return end

		if data.isPlayer then
			local treshold = Skada.db.profile.modules.threattreshold or 100
			local percent = data.percent

			if type(percent) == "number" and percent >= treshold and
				(not data.isTanking or not Skada.db.profile.modules.notankwarnings) then
				if Skada.db.profile.modules.threatflash then
					self:Flash()
				end
				if Skada.db.profile.modules.threatshake then
					self:Shake()
				end
				if Skada.db.profile.modules.threatsound then
					PlaySoundFile(media:Fetch("sound", Skada.db.profile.modules.threatsoundname))
				end
				last_warn = time()
			end
		end
	end

	function mod:Update(win, set)
		local target = find_threat_target()
		if not target then
			win.metadata.title = self:GetName()
			return
		end

		local targetName = UnitName(target)
		if issecretvalue(targetName) or type(targetName) ~= "string" then
			targetName = self:GetName()
		end
		win.metadata.title = targetName
		dataset_index = 1

		local max_value = 0
		local groupType, count = Skada:GetGroupTypeAndCount()

		if count > 0 then
			for i = 1, count do
				local unit = format("%s%d", groupType, i)
				local value = add_threat_data(win, unit, target)
				if value then max_value = math.max(max_value, value) end

				local pet = format("%s%dpet", groupType, i)
				value = add_threat_data(win, pet, target)
				if value then max_value = math.max(max_value, value) end
			end
		end

		if groupType ~= "raid" then
			local value = add_threat_data(win, "player", target)
			if value then max_value = math.max(max_value, value) end

			value = add_threat_data(win, "pet", target)
			if value then max_value = math.max(max_value, value) end
		end

		-- The tank's pull line: raw threat required to take aggro from the
		-- current tank, derived from the readable scaled percentage. This is
		-- the same line Forever's threat list displays.
		local me
		for i = 1, dataset_index - 1 do
			local d = win.dataset[i]
			if d and d.isPlayer then me = d; break end
		end
		if me and me.isTanking == false and type(me.scaled) == "number" and me.scaled > 0 then
			local pullValue = me.value * 100 / me.scaled
			if pullValue > max_value then max_value = pullValue end
			local d = win.dataset[dataset_index] or {}
			win.dataset[dataset_index] = d
			d.id = "pull"
			d.label = L["Pull Aggro"]
			d.class = nil
			d.role = nil
			d.isTanking = false
			d.isPlayer = false
			d.value = pullValue
			d.valuetext = nil
			d.valueText3 = nil
			d.threat = pullValue
			d.threatPct = 100
			d.percent = 100
			d.pull = true
			d.tps = nil
			dataset_index = dataset_index + 1
		end

		win.metadata.maxvalue = max_value > 0 and max_value or 1

		for i, data in ipairs(win.dataset) do
			if data.id then
				if data.value and data.value > 0 then
					local percent = data.percent
					local percentText = type(percent) == "number" and format("%.1f%%", percent) or ""
					Skada:FormatValueText(
						data,
						Skada:FormatNumber(data.value),
						self.metadata.columns.Threat,
						percentText,
						self.metadata.columns.Percent,
						nil,
						false
					)
					check_threat_warning(self, data, win.metadata.maxvalue)
				else
					data.id = nil
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			wipestale = true,
			columns = {
				Threat = true,
				Percent = true,
			},
			columnSpec = {
				{ label = L["Threat"], value = "valueText1" },
				{ label = "%", value = "valueText2" },
			},
			icon = "Interface\\Icons\\Ability_warrior_challange"
		}

		Skada:AddFeed(L["Threat: Personal Threat"], function()
			if Skada.current and UnitExists("target") then
				local _, _, threatpct = UnitThreatSituation("player", "target")
				if threatpct then
					-- Use string.format to avoid concatenation crimes
					return string.format("%.1f%%", threatpct)
				end
			end
		end)

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	-- Create options table
	local opts = {
		threatoptions = {
			type = "group",
			name = L["Threat"],
			args = {
				warnings = {
					type = "group",
					name = L["Threat warning"],
					inline = true,
					order = 1,
					args = {
						flash = {
							type = "toggle",
							name = L["Flash screen"],
							desc = L["This will cause the screen to flash as a threat warning."],
							get = function() return Skada.db.profile.modules.threatflash end,
							set = function(_, val) Skada.db.profile.modules.threatflash = val end,
							order = 1,
						},
						shake = {
							type = "toggle",
							name = L["Shake screen"],
							desc = L["This will cause the screen to shake as a threat warning."],
							get = function() return Skada.db.profile.modules.threatshake end,
							set = function(_, val) Skada.db.profile.modules.threatshake = val end,
							order = 2,
						},
						playsound = {
							type = "toggle",
							name = L["Play sound"],
							desc = L["This will play a sound as a threat warning."],
							get = function() return Skada.db.profile.modules.threatsound end,
							set = function(_, val) Skada.db.profile.modules.threatsound = val end,
							order = 3,
						},
						sound = {
							type = "select",
							dialogControl = "LSM30_Sound",
							name = L["Threat sound"],
							desc = L
							["The sound that will be played when your threat percentage reaches a certain point."],
							values = AceGUIWidgetLSMlists.sound,
							get = function() return Skada.db.profile.modules.threatsoundname end,
							set = function(_, val) Skada.db.profile.modules.threatsoundname = val end,
							order = 4,
						},
						threshold = {
							type = "range",
							name = L["Threat threshold"],
							desc = L["When your threat reaches this level, relative to tank, warnings are shown."],
							min = 0,
							max = 130,
							step = 1,
							get = function() return Skada.db.profile.modules.threattreshold end,
							set = function(_, val) Skada.db.profile.modules.threattreshold = val end,
							order = 5,
						},
						notankwarnings = {
							type = "toggle",
							name = L["Do not warn while tanking"],
							get = function() return Skada.db.profile.modules.notankwarnings end,
							set = function(_, val) Skada.db.profile.modules.notankwarnings = val end,
							order = 6,
						},
					},
				},
				focustarget = {
					type = "toggle",
					name = L["Use focus target"],
					desc = L["Shows threat on focus target, or focus target's target, when available."],
					get = function() return Skada.db.profile.modules.threatfocustarget end,
					set = function(_, val) Skada.db.profile.modules.threatfocustarget = val end,
					order = 3,
				},
			},
		}
	}

	function mod:OnInitialize()
		table.insert(Skada.options.plugins, opts)
	end

	-- Flash frame implementation from Omen
	function mod:Flash()
		if not self.FlashFrame then
			local flasher = CreateFrame("Frame", "SkadaThreatFlashFrame")
			flasher:SetToplevel(true)
			flasher:SetFrameStrata("FULLSCREEN_DIALOG")
			flasher:SetAllPoints(UIParent)
			flasher:EnableMouse(false)
			flasher:Hide()
			flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
			flasher.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
			flasher.texture:SetAllPoints(UIParent)
			flasher.texture:SetBlendMode("ADD")
			flasher:SetScript("OnShow", function(self)
				self.elapsed = 0
				self:SetAlpha(0)
			end)
			flasher:SetScript("OnUpdate", function(self, elapsed)
				elapsed = self.elapsed + elapsed
				if elapsed < 2.6 then
					local alpha = elapsed % 1.3
					if alpha < 0.15 then
						self:SetAlpha(alpha/0.15)
					elseif alpha < 0.9 then
						self:SetAlpha(math.max(0, 1 - ((alpha - 0.15) / 0.6)))
					else
						self:SetAlpha(0)
					end
				else
					self:Hide()
				end
				self.elapsed = elapsed
			end)
			self.FlashFrame = flasher
		end

		self.FlashFrame:Show()
	end

	-- Shake frame implementation from Omen
	function mod:Shake()
		local shaker = self.ShakerFrame
		if not shaker then
			shaker = CreateFrame("Frame", "SkadaThreatShaker", UIParent)
			shaker:Hide()
			shaker:SetScript("OnUpdate", function(self, elapsed)
				elapsed = self.elapsed + elapsed
				local x, y = 0, 0 -- Resets to original position if we're supposed to stop.
				if elapsed >= 0.8 then
					self:Hide()
				else
					x, y = random(-8, 8), random(-8, 8)
				end
				if WorldFrame:IsProtected() and InCombatLockdown() then
					if not shaker.fail then
						shaker.fail = true
					end
					self:Hide()
				else
					WorldFrame:ClearAllPoints()
					for i = 1, #self.originalPoints do
						local v = self.originalPoints[i]
						WorldFrame:SetPoint(v[1], v[2], v[3], v[4] + x, v[5] + y)
					end
				end
				self.elapsed = elapsed
			end)
			shaker:SetScript("OnShow", function(self)
				-- Store old worldframe positions, we need them all, people have frame modifiers for it
				if not self.originalPoints then
					self.originalPoints = {}
					for i = 1, WorldFrame:GetNumPoints() do
						tinsert(self.originalPoints, {WorldFrame:GetPoint(i)})
					end
				end
				self.elapsed = 0
			end)
			self.ShakerFrame = shaker
		end

		shaker:Show()
	end
end)
