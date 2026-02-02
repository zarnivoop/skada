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
	-- Safe to compare
	local success, result = pcall(function() return a > b end)
	if success then
		return result
	end
	return nil
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
