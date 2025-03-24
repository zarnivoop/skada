local MAJOR, MINOR = "LibNotify-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- WoW API globals
local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local BackdropTemplateMixin = _G.BackdropTemplateMixin or {}
local GetLocale = _G.GetLocale
local tremove = table.remove
local pairs = pairs
local ipairs = ipairs
local type = type
local math = math
local error = error

-- Library variables
lib.mixinTargets = lib.mixinTargets or {}
lib.storage = lib.storage or {}
local defaultfont = "Fonts\\FRIZQT__.TTF"
local storage = lib.storage
local icons = {}
local queue = {}
local items = {}
local id = 0
local frame, messageFrame, clickfunc, popupFrame, once, titlestring, messagestring, icon, note, edgeSize, location, size
local leftclick = "Left-click for details."
local rightclick = "Right-click to dismiss."

-- Forward declarations
local showNotification, showDetailedPopup

-- Function to pop notifications from the queue and show them
local function popNotifications()
    if frame and frame:IsShown() then
        -- Already showing a notification
        return
    end
    
    -- Show the next notification
    showNotification()
end

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

-- Initialize storage for notifications
lib.storage = lib.storage or {}

-- Function to show the notification frame with the current notification
showNotification = function()
    -- If there's no notification in the queue, don't show anything
    if #queue == 0 then return false end
    
    -- Get the first notification in the queue
    local note = queue[1]
    
    -- Create the frame if it doesn't exist
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        frame:SetSize(300, 100)
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 1)
        
        -- Create an icon
        local iconTexture = frame:CreateTexture(nil, "ARTWORK")
        iconTexture:SetSize(50, 50)
        iconTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -15)
        frame.icon = iconTexture
        
        -- Create title text
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", iconTexture, "TOPRIGHT", 10, 0)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
        title:SetJustifyH("LEFT")
        frame.title = title
        
        -- Create description text with proper wrapping
        local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        desc:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        frame.desc = desc
        
        -- Create click instructions text
        local click = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        click:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
        click:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
        click:SetJustifyH("CENTER")
        frame.click = click
        
        -- Make the frame clickable
        frame:EnableMouse(true)
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                -- Show detailed popup if available
                local note = queue[1]
                if note and note.detailed then
                    -- Remove the notification from the queue
                    tremove(queue, 1)
                    frame:Hide()
                    
                    -- Show the detailed popup
                    showDetailedPopup(note.detailed)
                end
            elseif button == "RightButton" then
                -- Dismiss the notification
                tremove(queue, 1)
                frame:Hide()
                
                -- Show the next notification if available
                popNotifications()
            end
        end)
    end
    
    -- Set the icon if available
    if note.icon then
        frame.icon:SetTexture(note.icon)
        frame.icon:Show()
    else
        frame.icon:Hide()
    end
    
    -- Set the title
    if note.title then
        frame.title:SetText(note.title)
    else
        frame.title:SetText(note.id or "")
    end
    
    -- Set the description
    if note.message then
        frame.desc:SetText(note.message)
    else
        frame.desc:SetText("")
    end
    
    -- Set the click instructions
    if note.detailed then
        if locale == "ruRU" then
            frame.click:SetText(leftclick .. " " .. rightclick)
        else
            frame.click:SetText(leftclick .. " " .. rightclick)
        end
    else
        frame.click:SetText(rightclick)
    end
    
    -- Adjust the frame height based on content
    local titleHeight = frame.title:GetStringHeight()
    local descHeight = frame.desc:GetStringHeight()
    local clickHeight = frame.click:GetStringHeight()
    local totalHeight = 30 + titleHeight + descHeight + clickHeight + 15
    
    -- Ensure minimum height
    totalHeight = math.max(totalHeight, 100)
    
    frame:SetHeight(totalHeight)
    
    -- Show the frame
    frame:Show()
    
    -- Return true to indicate success
    return true
end

-- Function to show the detailed popup
showDetailedPopup = function(notificationData)
    -- Create the message frame if it doesn't exist
    if not messageFrame then
        messageFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        messageFrame:SetSize(500, 400)
        messageFrame:SetPoint("CENTER", UIParent, "CENTER")
        messageFrame:SetFrameStrata("DIALOG")
        messageFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        messageFrame:SetBackdropColor(0, 0, 0, 1)
        messageFrame:EnableMouse(true)
        messageFrame:SetMovable(true)
        messageFrame:RegisterForDrag("LeftButton")
        messageFrame:SetScript("OnDragStart", messageFrame.StartMoving)
        messageFrame:SetScript("OnDragStop", messageFrame.StopMovingOrSizing)
        
        -- Create a scrollframe for the content
        local scrollframe = CreateFrame("ScrollFrame", nil, messageFrame, "UIPanelScrollFrameTemplate")
        scrollframe:SetPoint("TOPLEFT", messageFrame, "TOPLEFT", 30, -30)
        scrollframe:SetPoint("BOTTOMRIGHT", messageFrame, "BOTTOMRIGHT", -30, 50)
        
        -- Create the content frame
        local content = CreateFrame("Frame", nil, scrollframe)
        content:SetSize(scrollframe:GetWidth(), 1) -- Height will be adjusted dynamically
        scrollframe:SetScrollChild(content)
        
        -- Store references
        messageFrame.scrollframe = scrollframe
        messageFrame.content = content
        
        -- Create a close button at the bottom center
        local closeButton = CreateFrame("Button", nil, messageFrame, "UIPanelButtonTemplate")
        closeButton:SetSize(100, 25)
        closeButton:SetPoint("BOTTOM", messageFrame, "BOTTOM", 0, 15)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function() messageFrame:Hide() end)
    end
    
    -- Clear the content frame
    local content = messageFrame.content
    for _, child in pairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Add the notifications to the content frame
    local yOffset = 10
    local maxWidth = messageFrame.scrollframe:GetWidth() - 20
    
    -- Prepare the display text
    local displayText = ""
    
    -- Check if we have an array of version entries
    if type(notificationData) == "table" and #notificationData > 0 and type(notificationData[1]) == "table" then
        -- Create a single fontstring for all content
        local textDisplay = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textDisplay:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        textDisplay:SetWidth(maxWidth)
        textDisplay:SetJustifyH("LEFT")
        textDisplay:SetSpacing(2) -- Add some line spacing for better readability
        
        -- Process each version entry
        for i, version in ipairs(notificationData) do
            -- Add version header in gold color
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
        
        -- Set the text
        textDisplay:SetText(displayText)
        
        -- Adjust the content height based on the text height
        yOffset = yOffset + textDisplay:GetStringHeight() + 10
    else
        -- Process a single version notification
        local textDisplay = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textDisplay:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        textDisplay:SetWidth(maxWidth)
        textDisplay:SetJustifyH("LEFT")
        textDisplay:SetSpacing(2) -- Add some line spacing for better readability
        
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
        
        -- Set the text
        textDisplay:SetText(displayText)
        
        -- Adjust the content height based on the text height
        yOffset = yOffset + textDisplay:GetStringHeight() + 10
    end
    
    -- Set the content height
    content:SetHeight(yOffset)
    
    -- Show the message frame
    messageFrame:Show()
end

local function add_notifications(self, once, ...)
    local found = false
    if type(...) == 'table' then
        local data = ...
        
        -- If it's a version array (array of tables), create a summary notification
        if #data > 0 and type(data[1]) == "table" then
            -- Create a summary notification for the main frame
            local latestVersion = data[1] -- Assuming versions are ordered newest first
            local note = {
                id = latestVersion.id,
                title = latestVersion.title,
                message = latestVersion.message,
                detailed = data, -- Store the full version data for detailed view
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
            -- Single notification object
            local note = data
            
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
    if not lib.storage[self] then
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
        lib.storage[self] = s
    end
end

-- Convenience function for setting the default icon for the addon. Icons from each notification, if present, are still preferred.
function lib.SetNotifyIcon(self, icon)
    icons[self] = icon
end

function lib:ShowDetailedNotification(notificationData)
    -- Store the addon's icon for use in the notification
    if icons[self] then
        notificationData.icon = icons[self]
    end
    
    -- For version history, we want to show directly without going through the queue
    return showDetailedPopup(notificationData)
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
