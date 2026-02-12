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
	
	-- Not secret, but might still fail if types are incompatible
	if type(a) ~= type(b) then
		return nil
	end
	
	-- Safe to compare
	return a > b
end

--[[
	Format a number with K/M suffixes (only works on non-secret values).
	For secret values, returns the formatted secret directly.
	@param value - The value to format
	@return string - Formatted string
]]
function SecretHelper:FormatNumber(value)
	if value == nil then return "0" end
	
	-- Check if secret
	if hasSecretAPI and issecretvalue(value) then
		-- Can't format with K/M, just return as-is via string.format
		return string.format("%s", value)
	end
	
	-- Non-secret: format with K/M abbreviations
	local num = tonumber(value)
	if not num then return "0" end
	
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 10000 then
		return string.format("%.0fK", num / 1000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	else
		return string.format("%.0f", num)
	end
end

--[[
	MODULE-SPECIFIC HELPERS
	These functions handle common patterns in Skada modules
]]--

--[[
	Check if WoW 12.0 secret API is available
	@return boolean - true if issecretvalue function exists
]]
function SecretHelper:HasSecretAPI()
	return hasSecretAPI
end

--[[
	Detect secrets in a data table and calculate total
	This combines the common "first pass" pattern into one function
	@param dataTable - Table of items to check (e.g., sources, spells)
	@param valueKey - Key to check for secret values (e.g., "totalAmount", "healing")
	@return hasSecrets, total - Boolean indicating if any secrets found, and numeric total
]]
function SecretHelper:DetectSecrets(dataTable, valueKey)
	local hasSecrets = false
	local total = 0
	
	if not dataTable then return false, 0 end
	
	for _, item in pairs(dataTable) do
		if type(item) == "table" then
			local value = item[valueKey]
			if value then
				if hasSecretAPI and issecretvalue(value) then
					hasSecrets = true
				else
					total = total + (tonumber(value) or 0)
				end
			end
		end
	end
	
	return hasSecrets, total
end

--[[
	Get player name safely, handling secret values
	@param player - Player table from NativeAPI
	@return string - Player name (formatted if secret)
]]
function SecretHelper:GetPlayerName(player)
	if not player then return nil end
	
	local rawName = player.name or player.unitName
	if not rawName then return nil end
	
	if hasSecretAPI and issecretvalue(rawName) then
		return string.format("%s", rawName)
	elseif type(rawName) == "string" then
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
	
	-- Wipe window if secret state changed
	if win.metadata.wasSecretValues ~= nil and win.metadata.wasSecretValues ~= hasSecrets then
		win:Wipe()
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
