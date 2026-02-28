--[[
	SecretValueHelper.lua
	
	Utility module for handling WoW 12.0 secret values.
	Secret values are returned by combat APIs during combat and cannot be used for
	arithmetic or comparisons, but CAN be used with:
	- FontString:SetText()
	- StatusBar:SetValue()
	- string.format() / string.concat()
]]

local _, Skada = ...

local SecretHelper = {}
Skada.SecretHelper = SecretHelper

-- Check if issecretvalue exists (WoW 12.0+)
local hasSecretAPI = issecretvalue ~= nil

--[[
	Check if a value is a secret value
	@param value - The value to check
	@return boolean - true if value is secret
]]
function SecretHelper:IsSecret(value)
	if not hasSecretAPI then return false end
	return issecretvalue(value)
end

--[[
	Check if we can access/operate on a value
	@param value - The value to check
	@return boolean - true if we can do arithmetic/comparisons
]]
function SecretHelper:CanAccess(value)
	if not hasSecretAPI then return true end
	if canaccessvalue then
		return canaccessvalue(value)
	end
	-- If canaccessvalue doesn't exist, assume we can access non-secrets
	return not issecretvalue(value)
end

--[[
	Format a value for text display.
	Works with both regular and secret values.
	@param value - The value to format
	@param suffix - Optional suffix to append (e.g., " DPS")
	@return string - Formatted string for display
]]
function SecretHelper:FormatForDisplay(value, suffix)
	if value == nil then return "--" end
	suffix = suffix or ""
	-- string.format works with secret values
	return string.format("%s%s", value, suffix)
end

--[[
	Get a safe number value for arithmetic/comparisons.
	Returns nil if the value is secret (cannot be used for math).
	@param value - The value to convert
	@return number|nil - The number, or nil if secret
]]
function SecretHelper:GetSafeNumber(value)
	if value == nil then return 0 end
	if hasSecretAPI and issecretvalue(value) then
		return nil  -- Signal that this is secret and can't be used for math
	end
	return tonumber(value) or 0
end

--[[
	Get value for bar sizing. For secrets, returns the order-based fallback.
	@param value - The actual value (may be secret)
	@param orderFallback - Fallback value based on order (for when value is secret)
	@return number, boolean - The value to use for sizing, and whether it's a fallback
]]
function SecretHelper:GetBarValue(value, orderFallback)
	if value == nil then 
		return orderFallback or 0, true 
	end
	if hasSecretAPI and issecretvalue(value) then
		return orderFallback or 0, true
	end
	local num = tonumber(value)
	if num then
		return num, false
	end
	return orderFallback or 0, true
end

--[[
	Safely compare two values. Returns nil if comparison would fail.
	@param a - First value
	@param b - Second value
	@return boolean|nil - Comparison result, or nil if cannot compare
]]
function SecretHelper:SafeCompare(a, b)
	if hasSecretAPI then
		if issecretvalue(a) or issecretvalue(b) then
			return nil
		end
	end
	-- Use pcall as additional safety
	local ok, result = pcall(function() return a > b end)
	if ok then
		return result
	end
	return nil
end

--[[
	Format a number safely, handling secret values
	@param value - The value to format
	@return string - Formatted number or secret representation
]]
function SecretHelper:FormatNumber(value)
	if value == nil then return "0" end
	
	if hasSecretAPI and issecretvalue(value) then
		-- Secret values can be passed to SetText but we can't do math on them
		-- Return as-is, the display layer will handle it
		return tostring(value)
	end
	
	local num = tonumber(value)
	if num then
		return Skada:FormatNumber(num)
	end
	
	return "0"
end

--[[
	Check if the WoW client has secret API (WoW 12.0+)
	@return boolean - true if issecretvalue exists
]]
function SecretHelper:HasSecretAPI()
	return hasSecretAPI
end

--[[
	Detect if any values in a table are secrets
	@param dataTable - Table to check
	@param valueKey - Key to check in each item (default "totalAmount")
	@return boolean - true if any secret values found
]]
function SecretHelper:DetectSecrets(dataTable, valueKey)
	if not hasSecretAPI then return false end
	if not dataTable then return false end
	
	valueKey = valueKey or "totalAmount"
	
	for _, item in pairs(dataTable) do
		if type(item) == "table" then
			local value = item[valueKey]
			if value and issecretvalue(value) then
				return true
			end
		end
	end
	
	return false
end

--[[
	Get player name safely
	@param player - Player table from NativeAPI
	@return string - Player name or nil
]]
function SecretHelper:GetPlayerName(player)
	if not player then return nil end
	
	-- Handle secret values for name
	local rawName = player.name or player.unitName
	if rawName and type(rawName) == "string" then
		return rawName
	end
	
	return nil
end

--[[
	Get player class safely
	@param player - Player table from NativeAPI
	@return string - Player class or nil
]]
function SecretHelper:GetPlayerClass(player)
	if not player then return nil end
	
	local rawClass = player.class or player.classFilename
	if rawClass and type(rawClass) == "string" then
		return rawClass
	end
	
	return nil
end

--[[
	Update window metadata for secret state changes
	Handles the common pattern of wiping window and setting metadata
	@param win - Window object
	@param hasSecrets - Boolean indicating if current data has secrets
]]
function SecretHelper:UpdateWindowMetadata(win, hasSecrets)
	if not win or not win.metadata then return end
	
	-- Wipe window if secret state changed and force refresh
	if win.metadata.wasSecretValues ~= nil and win.metadata.wasSecretValues ~= hasSecrets then
		win:Wipe()
		win.changed = true
	end
	
	win.metadata.wasSecretValues = hasSecrets
	win.metadata.ordersort = hasSecrets
end

--[[
	Get display value for a bar, handling secrets
	@param value - The actual value (may be secret)
	@param order - Order/index for fallback when secret
	@return number - Value to use for bar sizing
]]
function SecretHelper:GetDisplayValue(value, order)
	if hasSecretAPI and value and issecretvalue(value) then
		return 1000 - (order or 1)
	end
	return tonumber(value) or 0
end

--[[
	Get max value for window metadata
	@param hasSecrets - Boolean indicating if data has secrets
	@param max - Calculated max value (for non-secret case)
	@param count - Number of items (for secret case)
	@return number - Max value for metadata
]]
function SecretHelper:GetMaxValue(hasSecrets, max, count)
	if hasSecrets then
		return 1000 - 1
	end
	return (max > 0 and max or 1)
end

--[[
	Safe tonumber that returns 0 for secrets instead of crashing
	@param value - Value to convert
	@return number - 0 if secret or nil, otherwise tonumber result
]]
function SecretHelper:SafeNumber(value)
	if value == nil then return 0 end
	if hasSecretAPI and issecretvalue(value) then return 0 end
	return tonumber(value) or 0
end

--[[
	Format a value for display with optional percentage
	@param value - The value to format
	@param includePercent - Whether to include percentage
	@param total - Total for percentage calculation
	@return string - Formatted text
]]
function SecretHelper:FormatValueText(value, includePercent, total)
	if hasSecretAPI and value and issecretvalue(value) then
		return Skada:FormatNumberSecret(value)
	end
	
	local num = tonumber(value) or 0
	local text = Skada:FormatNumber(num)
	
	if includePercent and total and total > 0 then
		local percent = (num / total) * 100
		text = text .. string.format(" (%02.1f%%)", percent)
	end
	
	return text
end

-- Spell cache for performance optimization
-- Key: spellID, Value: {name, iconID, lastAccess}
SecretHelper.spellCache = {}
local spellCacheMaxSize = 500
local spellCacheTTL = 300  -- 5 minutes TTL

--[[
	Cached version of Skada:GetSpellIcon that avoids repeated API calls
]]
function SecretHelper:GetSpellIcon(spellID)
	if not spellID or spellID == 0 then return nil end
	
	local now = GetTime()
	local cached = self.spellCache[spellID]
	
	-- Return cached result if valid
	if cached and (now - cached.lastAccess) < spellCacheTTL then
		cached.lastAccess = now
		return cached.iconID
	end
	
	-- Fetch from API
	local info = C_Spell.GetSpellInfo(spellID)
	if info then
		-- Cache the result
		self.spellCache[spellID] = {
			name = info.name,
			iconID = info.iconID,
			lastAccess = now
		}
		
		-- Cleanup old entries if cache is too large (simple LRU: remove 10 oldest)
		local cacheSize = 0
		for _ in pairs(self.spellCache) do
			cacheSize = cacheSize + 1
		end
		
		if cacheSize > spellCacheMaxSize then
			-- Remove oldest entries
			local sorted = {}
			for k, v in pairs(self.spellCache) do
				table.insert(sorted, {key = k, access = v.lastAccess})
			end
			table.sort(sorted, function(a, b) return a.access < b.access end)
			
			-- Remove 10% of cache
			local toRemove = math.floor(spellCacheMaxSize * 0.1)
			for i = 1, toRemove do
				if sorted[i] then
					self.spellCache[sorted[i].key] = nil
				end
			end
		end
		
		return info.iconID
	end
	
	return nil
end

--[[
	Per-frame cache for secret detection to avoid redundant scans
	Multiple modules scanning the same data in the same frame is wasteful
]]
SecretHelper.secretDetectionCache = {
	frame = 0,
	results = {}
}

--[[
	Detect secrets with per-frame caching
	This prevents multiple modules from scanning the same data in one update cycle
]]
function SecretHelper:DetectSecretsCached(cacheKey, dataTable, valueKey)
	local currentFrame = GetTime()
	local cache = self.secretDetectionCache
	
	-- Clear cache if we're in a new frame
	if currentFrame ~= cache.frame then
		cache.frame = currentFrame
		wipe(cache.results)
	end
	
	-- Return cached result if available
	if cache.results[cacheKey] ~= nil then
		return cache.results[cacheKey]
	end
	
	-- Perform detection
	local hasSecrets = false
	if dataTable and hasSecretAPI then
		for _, item in pairs(dataTable) do
			if type(item) == "table" then
				local value = item[valueKey]
				if value and issecretvalue(value) then
					hasSecrets = true
					break
				end
			end
		end
	end
	
	-- Cache the result
	cache.results[cacheKey] = hasSecrets
	return hasSecrets
end
