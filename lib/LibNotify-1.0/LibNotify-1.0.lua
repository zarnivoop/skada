local MAJOR, MINOR = "LibNotify-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local pairs = pairs
local unpack = unpack
local tinsert, tremove = table.insert, table.remove

local storage = {}
local icons = {}
local queue = {}
local items = {}
local id = 0

local frame = nil
local messageframe = nil

local clickfunc = nil

-- Initialize storage for notifications
lib.storage = lib.storage or {}

local leftclick = "Left-click for details."
local rightclick = "Right-click to dismiss."
local defaultfont = [[Fonts\FRIZQT__.TTF]]

local locale = GetLocale()
if locale == "ruRU" then
    leftclick = "щелкните левой кнопкой для подробностей."
    rightclick = "Нажмите право увольнять."
    defaultfont = [[Fonts\FRIZQT___CYR.TTF]]
end
if locale == "zhCN" then
    leftclick = "点击左边了解详情。"
    rightclick = "点击右键即可关闭。"
    defaultfont = [[Fonts\ARKai_T.ttf]]
end
if locale == "zhTW" then
    leftclick = "點擊左邊了解詳情。"
    rightclick = "點擊右鍵即可關閉。"
    defaultfont = [[Fonts\ARKai_T.ttf]]
end
if locale == "deDE" then
    leftclick = "Klicken Sie für Details links."
    rightclick = "Klicken Sie rechts, um zu entlassen."
end
if locale == "frFR" then
    leftclick = "Cliquez pour plus de détails."
    rightclick = "Cliquez à droite pour fermer."
end
if locale == "itIT" then
    leftclick = "Clicca per vedere i dettagli."
    rightclick = "Fare clic destro per chiudere."
end

if locale == "esES" then
    leftclick = "Haz click para ver los detalles."
    rightclick = "Haga clic derecho para cerrar."
end

lib.data = {
    icon = "Interface\\Icons\\Inv_misc_book_02",
    popup = {
        size = {
            width = 450,
            height = 400
        },
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, 
            tileSize = 32, 
            edgeSize = 32,
            insets = {left = 11, right = 12, top = 12, bottom = 11}
        }
    },
    frame = {
        size = {
            width = 350,
            height = 100
        },
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, 
            tileSize = 16, 
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        },
        timeout = 0  -- Set to 0 to disable auto-hiding
    }
}

lib.mixinTargets = lib.mixinTargets or {}
local mixins = {"Notify", "NotifyOnce", "SetNotifyStorage", "SetNotifyIcon", "ShowDetailedNotification"}

local function popNotifications(forceShowDetailed, notificationData)
    -- If we're forcing a detailed notification, use that instead of queue
    if forceShowDetailed then
        return showDetailedPopup(notificationData)
    end
    
    -- If we have no queue, exit
    if #queue == 0 then return end
    
    -- If we already have a frame, exit
    if frame and frame:IsShown() then return end
    
    -- Create the frame if it doesn't exist
    if not frame then
        local style = lib.data.frame
        
        -- Create frame with BackdropTemplate mixin for WoW 9.0+
        frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        
        -- Apply backdrop using the correct method based on WoW version
        if frame.SetBackdrop then
            frame:SetBackdrop(style.backdrop)
            if frame.SetBackdropColor then
                frame:SetBackdropColor(0, 0, 0, 0.8)  -- Semi-transparent black background
            end
        else
            -- Fallback for older versions
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(frame)
            bg:SetColorTexture(0, 0, 0, 0.8)  -- Semi-transparent black background
        end
        
        frame:SetSize(style.size.width, style.size.height)
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
        frame:SetFrameStrata("DIALOG")
        frame:Hide()
        
        -- Create icon texture
        local iconTexture = frame:CreateTexture(nil, "ARTWORK")
        iconTexture:SetSize(32, 32)
        iconTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
        iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Trim the icon borders
        frame.icon = iconTexture
        
        -- Create title text
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", iconTexture, "TOPRIGHT", 10, 0)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
        title:SetJustifyH("LEFT")
        title:SetTextColor(1, 0.82, 0, 1)  -- Gold color
        frame.title = title
        
        -- Create description text with proper wrapping
        local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        desc:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -5)
        desc:SetPoint("BOTTOM", frame, "BOTTOM", 0, 25)  -- Leave space at bottom for click instructions
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)  -- Enable word wrapping
        frame.desc = desc
        
        -- Create click instructions text
        local click = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        click:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 5)
        click:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 5)
        click:SetJustifyH("LEFT")
        click:SetTextColor(0.7, 0.7, 0.7, 1)  -- Light gray color
        frame.click = click
        
        -- Make the frame clickable
        frame:EnableMouse(true)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and clickfunc then
                clickfunc()
            elseif button == "RightButton" then
                self:Hide()
                tremove(queue, 1)
                C_Timer.After(0.5, popNotifications)
            end
        end)
    end
    
    -- Get the first notification
    local note = queue[1]
    
    -- Make sure we have a valid notification
    if not note then return end
    
    -- Set the icon
    if note.icon then
        frame.icon:SetTexture(note.icon)
    else
        frame.icon:SetTexture(lib.data.icon)
    end
    
    -- Set the title and description
    frame.title:SetText(note.title or "")
    frame.desc:SetText(note.message or note.text or "")
    
    -- Set the click function and instructions
    clickfunc = function()
        frame:Hide()
        tremove(queue, 1)
        
        if note.detailed then
            showDetailedPopup(note.detailed)
        end
        
        C_Timer.After(0.5, popNotifications)
    end
    
    -- Update click instructions based on if we have detailed info
    if note.detailed then
        frame.click:SetText(leftclick .. " " .. rightclick)
    else
        frame.click:SetText(rightclick)
    end
    
    -- Show the frame
    frame:Show()
end

-- Function to show the detailed popup
function showDetailedPopup(notificationData)
    -- Create the message frame if it doesn't exist
    if not messageframe then
        local style = lib.data.popup
        
        -- Create frame with BackdropTemplate mixin for WoW 9.0+
        messageframe = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        
        -- Apply backdrop using the correct method based on WoW version
        if messageframe.SetBackdrop then
            messageframe:SetBackdrop(style.backdrop)
            if messageframe.SetBackdropColor then
                messageframe:SetBackdropColor(0, 0, 0, 0.9)  -- Nearly black background with high opacity
            end
        else
            -- Fallback for older versions
            local bg = messageframe:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(messageframe)
            bg:SetColorTexture(0, 0, 0, 0.9)  -- Nearly black background with high opacity
        end
        
        messageframe:SetSize(style.size.width, style.size.height)
        messageframe:SetPoint("CENTER", UIParent, "CENTER")
        messageframe:SetFrameStrata("DIALOG")
        messageframe:Hide()
        messageframe:EnableKeyboard(true)
        messageframe:SetScript("OnKeyDown", function(self,key)
            if GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
                messageframe:SetPropagateKeyboardInput(false)
                messageframe:Hide()
            else
                messageframe:SetPropagateKeyboardInput(true)
            end
        end)
        
        -- Create a scrollframe
        local scrollframe = CreateFrame("ScrollFrame", nil, messageframe, "UIPanelScrollFrameTemplate")
        scrollframe:SetPoint("TOPLEFT", messageframe, "TOPLEFT", 20, -20)
        scrollframe:SetPoint("BOTTOMRIGHT", messageframe, "BOTTOMRIGHT", -40, 40) -- Added bottom padding for close button
        
        -- Store the scrollframe reference in the messageframe
        messageframe.scrollframe = scrollframe
        
        -- Create a content frame to hold the text
        local content = CreateFrame("Frame", nil, scrollframe)
        content:SetSize(scrollframe:GetWidth(), 10) -- Initial height, will be adjusted dynamically
        scrollframe:SetScrollChild(content)
        
        -- Create a close button at the bottom center
        local close = CreateFrame("Button", nil, messageframe, "UIPanelButtonTemplate")
        close:SetSize(100, 25)
        close:SetPoint("BOTTOM", messageframe, "BOTTOM", 0, 10)
        close:SetText("Close")
        close:SetScript("OnClick", function() messageframe:Hide() end)
    end
    
    -- Update the text content
    if messageframe and messageframe.scrollframe then
        local content = messageframe.scrollframe:GetScrollChild()
        
        if content then
            -- Create a FontString if it doesn't exist
            if not content.text then
                content.text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                content.text:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
                content.text:SetWidth(content:GetWidth() - 10)
                content.text:SetJustifyH("LEFT")
                content.text:SetSpacing(2) -- Add some line spacing for better readability
            end
            
            -- Prepare the display text
            local displayText = ""
            
            -- Check if we have an array of version entries
            if type(notificationData) == "table" and #notificationData > 0 and type(notificationData[1]) == "table" then
                -- Process each version entry
                for i, version in ipairs(notificationData) do
                    -- Add version header
                    if version.title then
                        displayText = displayText .. "|cFFFFD100" .. version.title .. "|r"
                        
                        -- Add version message if available
                        if version.message then
                            displayText = displayText .. " - |cFFFFFFFF" .. version.message .. "|r"
                        end
                        
                        displayText = displayText .. "\n\n"
                    end
                    
                    -- Add changes as a bulleted list in white
                    if version.changes and #version.changes > 0 then
                        for _, change in ipairs(version.changes) do
                            displayText = displayText .. "|cFFFFFFFF• " .. change .. "|r\n"
                        end
                        
                        -- Add a blank line between versions (except after the last one)
                        if i < #notificationData then
                            displayText = displayText .. "\n"
                        end
                    end
                end
            -- Process a single version notification
            elseif type(notificationData) == "table" then
                -- Add the title as a header with gold color
                if notificationData.title then
                    displayText = "|cFFFFD100" .. notificationData.title .. "|r\n\n"
                end
                
                -- Add the main message in white
                if notificationData.message then
                    displayText = displayText .. "|cFFFFFFFF" .. notificationData.message .. "|r"
                end
                
                -- Add changes as a bulleted list in white
                if notificationData.changes and #notificationData.changes > 0 then
                    displayText = displayText .. "\n\n"
                    for _, change in ipairs(notificationData.changes) do
                        displayText = displayText .. "|cFFFFFFFF• " .. change .. "|r\n"
                    end
                end
            else
                displayText = "|cFFFFFFFF" .. tostring(notificationData) .. "|r"
            end
            
            -- Set the text
            content.text:SetText(displayText)
            
            -- Force a layout update to ensure text height is calculated correctly
            content.text:SetWidth(content:GetWidth() - 10)
            
            -- Adjust the content height based on the text height
            local textHeight = content.text:GetStringHeight() > 0 and content.text:GetStringHeight() or content.text:GetHeight()
            content:SetHeight(textHeight + 20) -- Add some padding
            
            -- Make sure the scrollframe is scrolled to the top
            messageframe.scrollframe:SetVerticalScroll(0)
        end
    end
    
    -- Show the frame
    messageframe:Show()
    
    -- Return true to indicate success
    return true
end

-- Function to directly show a detailed notification popup without using the queue
function lib:ShowDetailedNotification(notificationData)
    -- Store the addon's icon for use in the notification
    if icons[self] then
        notificationData.icon = icons[self]
    end
    
    -- For version history, we want to show directly without going through the queue
    return showDetailedPopup(notificationData)
end

local function add_notifications(self, once, ...)
    local found = false
    if type(...) == 'table' then
        local note = ...
        
        -- Store the addon's icon for use in the notification
        if icons[self] then
            note.icon = icons[self]
        end
        
        -- Check if we should only show this once
        if once then
            local storage = lib.storage[self]
            if not storage then
                storage = {}
                lib.storage[self] = storage
            end
            
            -- Check if we've already shown this notification
            if note.id and storage[note.id] then
                found = true
            else
                -- Mark as shown
                if note.id then
                    storage[note.id] = true
                end
            end
        end
        
        -- Add to queue if not already shown
        if not found then
            queue[#queue+1] = note
            popNotifications()
        end
    else
        local title, text, detailed = ...
        
        -- Create a notification table
        local note = {
            title = title,
            text = text,
            detailed = detailed,
            icon = icons[self]
        }
        
        -- Check if we should only show this once
        if once then
            local storage = lib.storage[self]
            if not storage then
                storage = {}
                lib.storage[self] = storage
            end
            
            -- Check if we've already shown this notification
            if title and storage[title] then
                found = true
            else
                -- Mark as shown
                if title then
                    storage[title] = true
                end
            end
        end
        
        -- Add to queue if not already shown
        if not found then
            queue[#queue+1] = note
            popNotifications()
        end
    end
end

-- Pass a table of notifications, or a single one as individual parameters.
-- Table notifications are shown in the notification frame as the last item - the popup shows them all.
-- If "title" is omitted on a table notification, the id is used as title.
function lib.Notify(self, ...)
    add_notifications(self, false, ...)
end

-- Pass a table of notifications, or a single one as individual parameters.
-- An extra "id" parameter is expected, to identify seen notifications. If the id is omitted, the title is used as id.
-- Table notifications are shown in the notification frame as the first item - the popup shows them all.
-- If "title" is omitted on a table notification, the id is used as title.
function lib.NotifyOnce(self, ...)
    if not storage[self] then
        error('NotifyOnce requires storage to have been set first')
    else
        add_notifications(self, true, ...)
    end
end

-- Set storage where seen notifications are stored. Only required when using "NotifyOnce".
-- This must be a table.
function lib.SetNotifyStorage(self, s)
    if type(s) ~= "table" then
        error('storage must be a table')
    else
        storage[self] = s
    end
end

-- Convenience function for setting the default icon for the addon. Icons from each notification, if present, are still preferred.
function lib.SetNotifyIcon(self, icon)
    icons[self] = icon
end

function lib:Embed(target)
  for _,name in pairs(mixins) do
    target[name] = lib[name]
  end
  lib.mixinTargets[target] = true
end

for target,_ in pairs(lib.mixinTargets) do
  lib:Embed(target)
end
