local addonName, addon = ...

-- Initialize saved variables
local db
local currentSet = "primary"

-- Debug function - only output in debug mode
local DEBUG_MODE = false
local function Debug(...)
    if DEBUG_MODE and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Bissy Debug: " .. string.format(...), 0.5, 0.5, 1)
    end
end

-- Create a wrapper for JSON parsing that will work regardless of when the JSON library is loaded
local function ParseJSON(jsonStr)
    -- Check if the JSON library is loaded
    if _G.json and _G.json.parse then
        local success, result = pcall(function() return _G.json.parse(jsonStr) end)
        if success and result then
            return result
        else
            print("Bissy: JSON parse error: " .. (result or "unknown error"))
            return nil
        end
    else
        print("Bissy: JSON library not available yet")
        return nil
    end
end

-- Create main frame
local Bissy = CreateFrame("Frame", "Bissy", UIParent, "PortraitFrameTemplate")
Bissy:Hide()
Bissy:SetSize(450, 500)  -- Reduced width from original
Bissy:SetPoint("CENTER")
Bissy:SetMovable(true)
Bissy:EnableMouse(true)
Bissy:RegisterForDrag("LeftButton")
Bissy:SetScript("OnDragStart", Bissy.StartMoving)
Bissy:SetScript("OnDragStop", Bissy.StopMovingOrSizing)
Bissy:SetClampedToScreen(true)
Bissy:SetTitle("Bissy")

-- Define slot mapping from JSON format to WoW slot IDs
local SLOT_MAP = {
    HEAD = "HeadSlot",
    NECK = "NeckSlot",
    SHOULDER = "ShoulderSlot",
    SHOULDERS = "ShoulderSlot", -- Alternative name
    BACK = "BackSlot",
    CLOAK = "BackSlot", -- Alternative name
    CHEST = "ChestSlot",
    ROBE = "ChestSlot", -- Alternative name
    WRISTS = "WristSlot",
    WRIST = "WristSlot", -- Alternative name
    HANDS = "HandsSlot",
    HAND = "HandsSlot", -- Alternative name
    WAIST = "WaistSlot",
    BELT = "WaistSlot", -- Alternative name
    LEGS = "LegsSlot",
    LEG = "LegsSlot", -- Alternative name
    FEET = "FeetSlot",
    FOOT = "FeetSlot", -- Alternative name
    FINGER_1 = "Finger0Slot",
    FINGER1 = "Finger0Slot", -- Alternative name
    FINGER_2 = "Finger1Slot",
    FINGER2 = "Finger1Slot", -- Alternative name
    TRINKET_1 = "Trinket0Slot",
    TRINKET1 = "Trinket0Slot", -- Alternative name
    TRINKET_2 = "Trinket1Slot",
    TRINKET2 = "Trinket1Slot", -- Alternative name
    MAIN_HAND = "MainHandSlot",
    MAINHAND = "MainHandSlot", -- Alternative name
    OFF_HAND = "SecondaryHandSlot",
    OFFHAND = "SecondaryHandSlot", -- Alternative name
    RANGED = "RangedSlot",
    SHIRT = "ShirtSlot",
    TABARD = "TabardSlot",
    AMULET = "NeckSlot", -- Added from import-example.json
    RING_1 = "Finger0Slot", -- Added from import-example.json
    RING_2 = "Finger1Slot", -- Added from import-example.json
}

-- Define all equipment slots with positions matching standard WoW character sheet
local SLOT_INFO = {
    -- Left column
    { name = "HeadSlot", x = 65, y = -70 },
    { name = "NeckSlot", x = 65, y = -110 },
    { name = "ShoulderSlot", x = 65, y = -150 },
    { name = "BackSlot", x = 65, y = -190 },
    { name = "ChestSlot", x = 65, y = -230 },
    { name = "ShirtSlot", x = 65, y = -270 },
    { name = "TabardSlot", x = 65, y = -310 },
    { name = "WristSlot", x = 65, y = -350 },
    
    -- Right column
    { name = "HandsSlot", x = 330, y = -70 },
    { name = "WaistSlot", x = 330, y = -110 },
    { name = "LegsSlot", x = 330, y = -150 },
    { name = "FeetSlot", x = 330, y = -190 },
    { name = "Finger0Slot", x = 330, y = -230 },
    { name = "Finger1Slot", x = 330, y = -270 },
    { name = "Trinket0Slot", x = 330, y = -310 },
    { name = "Trinket1Slot", x = 330, y = -350 },
    
    -- Weapons row (below model)
    { name = "MainHandSlot", x = 150, y = -400 },
    { name = "SecondaryHandSlot", x = 215, y = -400 },
    { name = "RangedSlot", x = 280, y = -400 },
}

-- Create item slots
local slots = {}
local function CreateItemSlot(info)
    Debug("Creating slot: %s", info.name)
    
    -- Create a button using the standard ItemButtonTemplate
    local slot = CreateFrame("Button", "BissySlot_" .. info.name, Bissy, "ItemButtonTemplate")
    slot:SetSize(37, 37)  -- Standard item slot size
    slot:SetPoint("TOPLEFT", info.x, info.y)
    slot:EnableMouse(true)
    
    -- Add tooltip functionality
    slot:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(info.name:gsub("Slot", ""))
            GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Add a click handler
    slot:SetScript("OnClick", function(self)
        if self.itemLink then
            Debug("Clicked on item: %s", self.itemLink)
        else
            Debug("Clicked on empty slot: %s", info.name)
        end
    end)
    
    return slot
end

for i, info in ipairs(SLOT_INFO) do
    slots[info.name] = CreateItemSlot(info)
end

-- Forward declarations for functions we'll define later
local ClearAllSlots
local UpdateCharacterModel

-- CENTRALIZED SET SWITCHING FUNCTION
local function SwitchSet(setName, forceShow)
    -- Validate the set name
    if setName ~= "primary" and setName ~= "secondary" then
        print("Bissy: Invalid set name: " .. tostring(setName))
        return false
    end
    
    -- Update the current set
    currentSet = setName
    db.currentSet = setName  -- Save the setting
    
    -- Update the frame title
    Bissy:SetTitle("Bissy (" .. (setName == "primary" and "Primary" or "Secondary") .. ")")
    
    -- print("Switching to " .. setName .. " set")

    -- Only proceed with UI updates if the frame is shown
    if Bissy:IsShown() or forceShow then
        -- print("Updating UI with switched set")
        
        -- Clear all slots first
        ClearAllSlots()
        
        -- Get the current set data
        local currentData = db[setName]
        
        -- Process each item if we have data
        if currentData and currentData.items and #currentData.items > 0 then
            -- print("Displaying " .. #currentData.items .. " items for " .. setName .. " set")
            
            -- Pre-load item data for all items
            for _, item in ipairs(currentData.items) do
                local itemId = tonumber(item.id)
                if itemId then
                    -- Use C_Item.RequestLoadItemDataByID if available (retail WoW)
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(itemId)
                    end
                end
            end
            
            -- Process each item for display
            for _, item in ipairs(currentData.items) do
                local itemId = tonumber(item.id)
                if not itemId then
                    print("Invalid item ID: " .. tostring(item.id))
                else
                    -- Map JSON slot name to WoW slot ID
                    local slotName = SLOT_MAP[item.slot]
                    
                    if slotName and slots[slotName] then
                        local slot = slots[slotName]
                        
                        -- Get item info
                        local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
                        
                        -- If item info isn't available yet, use GetItemInfoInstant as fallback
                        if not itemLink then
                            local name, _, _, _, _, _, _, _, _, texture = GetItemInfoInstant(itemId)
                            if name then
                                itemLink = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                                itemName = name
                                itemTexture = texture
                                itemRarity = 1  -- Common quality as fallback
                            else
                                -- Use placeholder if no item info is available
                                itemLink = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                                itemName = item.name or ("Item " .. itemId)
                                itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
                                itemRarity = 1
                            end
                        end
                        
                        -- Set item data to slot
                        if itemLink then
                            slot.itemLink = itemLink
                            
                            -- Set texture using ItemButtonTemplate methods
                            if not itemTexture then
                                itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
                            end
                            
                            -- Set the icon texture
                            SetItemButtonTexture(slot, itemTexture)
                            
                            -- Set border color based on item quality
                            if itemRarity then
                                -- Fix for item rarity coloring
                                if C_Item and C_Item.GetItemQualityColor then
                                    local r, g, b = C_Item.GetItemQualityColor(itemRarity)
                                    slot.IconBorder:SetVertexColor(r, g, b)
                                    slot.IconBorder:Show()
                                else
                                    -- Fallback for Classic
                                    local qualityColor = ITEM_QUALITY_COLORS[itemRarity]
                                    if qualityColor then
                                        slot.IconBorder:SetVertexColor(qualityColor.r, qualityColor.g, qualityColor.b)
                                        slot.IconBorder:Show()
                                    end
                                end
                            end
                        end
                    else
                        print("Invalid slot mapping: " .. item.slot)
                    end
                end
            end
            
            -- Update the character model
            UpdateCharacterModel()
        else
            print("No items found for " .. setName .. " set")
        end
    end
    
    -- Update button states
    if primaryBtn and secondaryBtn then
        if setName == "primary" then
            primaryBtn:SetEnabled(false)
            secondaryBtn:SetEnabled(true)
        else
            primaryBtn:SetEnabled(true)
            secondaryBtn:SetEnabled(false)
        end
    end
    
    return true
end

-- Primary button
local primaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
primaryBtn:SetText("Primary")
primaryBtn:SetSize(80, 22)
primaryBtn:SetPoint("TOP", 0, -35)
primaryBtn:SetPoint("RIGHT", Bissy, "CENTER", -2, 0)
primaryBtn:SetScript("OnClick", function()
    SwitchSet("primary")
end)

-- Secondary button
local secondaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
secondaryBtn:SetText("Secondary")
secondaryBtn:SetSize(80, 22)
secondaryBtn:SetPoint("TOP", 0, -35)
secondaryBtn:SetPoint("LEFT", Bissy, "CENTER", 2, 0)
secondaryBtn:SetScript("OnClick", function()
    SwitchSet("secondary")
end)

-- Set the initial button states
C_Timer.After(0.1, function()
    SwitchSet(currentSet)
end)

-- Set the portrait icon
if Bissy.PortraitContainer and Bissy.PortraitContainer.portrait then
    Bissy.PortraitContainer.portrait:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
elseif Bissy.portrait then
    Bissy.portrait:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
end

-- Hide the divider line at the bottom if it exists
if Bissy.Inset then
    Bissy.Inset:Hide()
end
if Bissy.BottomInset then
    Bissy.BottomInset:Hide()
end

-- Create character model
local model = CreateFrame("DressUpModel", nil, Bissy)
model:SetPoint("TOPLEFT", 130, -60)  -- Adjusted position
model:SetSize(170, 320)
model:SetUnit("player")
model:SetAutoDress(false)  -- Don't auto-dress with player's gear
Bissy.model = model  -- Store the model in the Bissy frame for easy access

-- Create item slots
for i, info in ipairs(SLOT_INFO) do
    if not slots[info.name] then
        slots[info.name] = CreateItemSlot(info)
    end
end

-- Function to update the character model with equipped items
function UpdateCharacterModel()
    Debug("Updating character model")
    
    -- Make sure the model exists
    if not model then
        Debug("Model frame doesn't exist yet")
        return
    end
    
    -- Reset the model completely
    model:ClearModel()
    model:SetUnit("player")
    model:Undress()
    
    -- Get the current set data
    local currentData = db[currentSet]
    if not currentData or not currentData.items then
        Debug("No items in current set to display on model")
        return
    end
    
    -- Add a slight delay to ensure the model is ready before trying on items
    C_Timer.After(0.1, function()
        -- Process each item for the model
        local itemCount = 0
        
        for _, item in ipairs(currentData.items) do
            local itemId = tonumber(item.id)
            if itemId then
                Debug("Trying on item ID: %s for slot: %s", itemId, item.slot)
                
                -- Use the item string format that works best with TryOn
                local itemString = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                model:TryOn(itemString)
                itemCount = itemCount + 1
            end
        end
        
        Debug("Updated character model with %d items", itemCount)
        
        -- Force model to update
        model:RefreshCamera()
        model:SetModelScale(1.0)
        
        -- Add another delay and refresh again to ensure all items are loaded
        C_Timer.After(0.5, function()
            Debug("Refreshing character model after delay")
            if model then
                -- Sometimes we need to reset the position after items are loaded
                model:SetPosition(0, 0, 0)
                model:RefreshCamera()
            end
        end)
    end)
end

-- Function to clear all item slots
function ClearAllSlots()
    Debug("Clearing all slots")
    for slotName, slot in pairs(slots) do
        slot.itemLink = nil
        
        -- Clear the icon texture
        SetItemButtonTexture(slot, "")
        
        -- Clear the border color
        SetItemButtonQuality(slot, 0, "")
    end
    
    -- Also reset the model
    model:ClearModel()
    model:SetUnit("player")
    model:Undress()
    model:RefreshCamera()
end

-- Import dialog
function ShowImportDialog()
    -- Create a custom dialog frame without using DialogBoxFrame
    local dialog = CreateFrame("Frame", "BissyImportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 400)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    
    -- Add background and border
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    
    -- Add a title bar
    local titleBG = dialog:CreateTexture(nil, "ARTWORK")
    titleBG:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBG:SetWidth(300)
    titleBG:SetHeight(64)
    titleBG:SetPoint("TOP", 0, 12)
    
    -- Set the title
    dialog.header = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.header:SetPoint("TOP", titleBG, "TOP", 0, -14)
    dialog.header:SetText("Import Character Data")
    
    -- Add a close button
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Add description text
    local descText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT", 20, -40)
    descText:SetPoint("TOPRIGHT", -20, -40)
    descText:SetText("Currently supported is character exports from SixtyUpgrades.com")
    descText:SetJustifyH("LEFT")
    
    -- Create scrolling edit box for input
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -65)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(scrollFrame:GetWidth() - 20, 1000) -- Height larger than needed for scrolling
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    editBox:SetText("Paste your JSON data here...")
    editBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Paste your JSON data here..." then
            self:SetText("")
        end
    end)
    
    -- Add a background for the edit box
    local editBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    editBg:SetAllPoints()
    editBg:SetColorTexture(0, 0, 0, 0.2)
    
    scrollFrame:SetScrollChild(editBox)
    
    -- Create import button
    local importBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    importBtn:SetText("Import")
    importBtn:SetSize(100, 22)
    importBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    importBtn:SetScript("OnClick", function()
        local jsonStr = editBox:GetText()
        
        if not jsonStr or jsonStr == "" or jsonStr == "Paste your JSON data here..." then
            print("Bissy: No data to import")
            return
        end
        
        -- Try to use the json.lua library if available
        local data = ParseJSON(jsonStr)
        if data and data.items then
            print("Bissy: Successfully parsed JSON")
            ProcessImportedData(data)
            dialog:Hide()
            
            -- Show the Bissy frame if it's not already shown
            if not Bissy:IsShown() then
                Bissy:Show()
            end
        else
            print("Bissy: Failed to parse JSON data. Check your input.")
        end
    end)
    
    -- Create cancel button
    local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelBtn:SetText("Cancel")
    cancelBtn:SetSize(100, 22)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -10, 0)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    -- Make the dialog draggable
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    
    -- Make the dialog modal (block input to other frames)
    dialog:EnableKeyboard(true)
    dialog:SetPropagateKeyboardInput(false)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    -- Show the dialog
    dialog:Show()
    editBox:SetFocus()
end

-- Create button on character frame
local openButton = CreateFrame("Button", nil, CharacterFrame, "UIPanelButtonTemplate")
openButton:SetText("Bissy")
openButton:SetSize(80, 22)
openButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -25, -25)
openButton:SetScript("OnClick", function()
    if Bissy:IsShown() then
        Bissy:Hide()
    else
        Bissy:Show()
        SwitchSet(currentSet)
    end
end)

-- Create import button
local importButton = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
importButton:SetText("Import Sheet")
importButton:SetSize(100, 22)
importButton:SetPoint("BOTTOMRIGHT", -10, 4)
importButton:SetScript("OnClick", function()
    ShowImportDialog()
end)

-- Make the frame movable
Bissy:SetMovable(true)
Bissy:EnableMouse(true)
Bissy:RegisterForDrag("LeftButton")
Bissy:SetScript("OnDragStart", function(self) self:StartMoving() end)
Bissy:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    
    -- Save position
    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    db.position = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end)

-- Process imported data
function ProcessImportedData(data)
    -- Validate data
    if not data or not data.items then
        print("Bissy Debug: Invalid data format")
        return false
    end
    
    -- Validate each item
    for i, item in ipairs(data.items) do

        -- Check if item has a slot
        if not item.slot then
            print("Bissy Debug: Item at index " .. i .. " has no slot")
            return false
        end
        
        -- Ensure item ID is a number
        item.id = tonumber(item.id)
        if not item.id then
            print("Bissy Debug: Invalid item ID at index " .. i)
            return false
        end
        
        -- Debug: Print item details
        print("Bissy Debug: Item " .. i .. " - ID: " .. item.id .. ", Slot: " .. item.slot)
    end
    
    -- Save to current set
    local targetSet = currentSet
    print("Bissy Debug: Saving to set: " .. targetSet)
    
    if targetSet == "primary" then
        db.primary = data
    elseif targetSet == "secondary" then
        db.secondary = data
    else
        print("Bissy Debug: Invalid target set: " .. tostring(targetSet))
        return false
    end
    
    -- Update the UI if the frame is shown
    if Bissy:IsShown() then
        -- print("Bissy Debug: Updating UI with imported data")
        SwitchSet(targetSet)
    end
    
    -- Dump database for debugging
    DumpDatabase()
    
    return true
end

-- Function to dump the database contents for debugging
function DumpDatabase()
    print("Bissy Debug: Dumping database contents")
    
    -- Check if we have a database
    if not db then
        print("Bissy Debug: No database found")
        return
    end
    
    -- Check primary set
    if db.primary and db.primary.items then
        print("Bissy Debug: Primary set has " .. #db.primary.items .. " items")
        for i, item in ipairs(db.primary.items) do
            print(string.format("  Item %d: ID=%s, Name=%s, Slot=%s", 
                i, tostring(item.id), tostring(item.name), tostring(item.slot)))
        end
    else
        print("Bissy Debug: No primary set found or it has no items")
    end
    
    -- Check secondary set
    if db.secondary and db.secondary.items then
        print("Bissy Debug: Secondary set has " .. #db.secondary.items .. " items")
        for i, item in ipairs(db.secondary.items) do
            print(string.format("  Item %d: ID=%s, Name=%s, Slot=%s", 
                i, tostring(item.id), tostring(item.name), tostring(item.slot)))
        end
    else
        print("Bissy Debug: No secondary set found or it has no items")
    end
    
    -- Check current set
    print("Bissy Debug: Current set is " .. (currentSet or "nil"))
end

-- Function to verify and fix slot configuration
local function VerifySlotConfiguration()
    print("Bissy: Verifying slot configuration")
    
    -- Check if all slots exist
    for _, info in ipairs(SLOT_INFO) do
        if not slots[info.name] then
            print("Bissy: Missing slot: " .. info.name)
            -- Create the slot
            slots[info.name] = CreateItemSlot(info)
        end
    end
    
    print("Bissy: Slot configuration verified")
end

-- Add the function to the addon for slash command access
addon.VerifySlotConfiguration = VerifySlotConfiguration

-- Add a debug command to dump the database
SLASH_BISSYDEBUG1 = "/bissydebug"
SlashCmdList["BISSYDEBUG"] = function(msg)
    if msg == "dump" then
        DumpDatabase()
    elseif msg == "reload" then
        -- Force a reload of the current set
        if currentSet then
            SwitchSet(currentSet)
        else
            print("Bissy Debug: No current set")
        end
    elseif msg == "checkslots" then
        DebugCheckSlots()
    elseif msg == "shown" then
        CheckVisibility()
    else
        print("Bissy Debug: Available commands:")
        print("  /bissydebug dump - Dump database contents")
        print("  /bissydebug reload - Reload current set")
        print("  /bissydebug checkslots - Check slot visibility")
        print("  /bissyverifyslots - Verify and fix slot configuration")
        print("  /bissytestitemslot - Test different item slot creation methods")
        print("  /bissytestgetitemicon - Test GetItemIcon functionality")
        print("  /bissydirecttest - Create a direct test frame")
    end
end

-- Function to check the visibility of all slots
function DebugCheckSlots()
    Debug("Checking visibility of all slots")
    for slotName, slot in pairs(slots) do
        Debug("Slot: %s", slotName)
        Debug("  - Has itemLink: %s", (slot.itemLink and "Yes" or "No"))
        Debug("  - Icon texture: %s", (slot.icon:GetTexture() and "Yes" or "No"))
    end
end

-- Function to check and print frame visibility status
local function CheckVisibility()
    local isVisible = Bissy:IsVisible()
    Debug("Bissy frame is currently %s", isVisible and "visible" or "hidden")
    return isVisible
end

-- Store the original OnShow handler if it exists
local originalOnShow = Bissy:GetScript("OnShow")

-- Set up the OnShow handler
Bissy:SetScript("OnShow", function(self)
    -- Call original OnShow if it exists
    if originalOnShow then
        originalOnShow(self)
    end
    
    -- Use our centralized SwitchSet function to refresh the UI
    -- This will handle loading items, updating the title, and button states
    SwitchSet(currentSet)
end)

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        
        -- Initialize the addon
        BissyDB = BissyDB or { currentSet = "primary", primary = {}, secondary = {} }
        db = BissyDB
        currentSet = db.currentSet or "primary"
        
        print("Bissy: Addon loaded. Current set: " .. currentSet)
        
        -- Dump database for debugging
        -- DumpDatabase()
        
        -- Set up tooltip hook for showing Bissy info on regular game tooltips
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local name, link = tooltip:GetItem()
            if not name or not link then return end
            
            local itemId = tonumber(string.match(link, "item:(%d+)"))
            if not itemId then return end
                        
            -- Check primary set
            local function checkSet(set, itemId)
                if set and set.items then
                    for _, item in ipairs(set.items) do
                        if tonumber(item.id) == itemId then
                            return true
                        end
                    end
                end
                return false
            end

            -- Check if this item is in our primary or secondary sets
            local inPrimary = checkSet(db.primary, itemId)
            local inSecondary = checkSet(db.secondary, itemId)

            -- Add tooltip line if item is in either set
            if inPrimary or inSecondary then
                tooltip:AddLine(" ")
                
                if inPrimary then
                    tooltip:AddDoubleLine("Bissy item", "Primary set", 0.9, 0.8, 0.5, 0.6, 1.0, 0.6)
                end
                
                if inSecondary then
                    tooltip:AddDoubleLine("Bissy item", "Secondary set", 0.9, 0.8, 0.5, 0.6, 1.0, 0.6)
                end
                
                tooltip:Show()
            end
        end)
        Debug("Tooltip hook set up")
        
        -- Set the current set using our new function (with a slight delay to ensure UI is ready)
        C_Timer.After(0.1, function()
            SwitchSet(db.currentSet)
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)

-- Function to handle slash commands
function HandleSlashCommand(msg)
    msg = msg:lower()
    
    if msg == "show" then
        Bissy:Show()
        CheckVisibility()
    elseif msg == "hide" then
        Bissy:Hide()
        CheckVisibility()
    elseif msg == "reset" then
        Bissy:ClearAllPoints()
        Bissy:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    elseif msg == "primary" then
        SwitchSet("primary")
    elseif msg == "secondary" then
        SwitchSet("secondary")
    elseif msg == "import" then
        ShowImportDialog()
    elseif msg == "reload" then
        -- Force a reload of the current set
        if currentSet then
            print("Bissy: Reloading current set: " .. currentSet)
            SwitchSet(currentSet)
        else
            print("Bissy: No current set to reload")
        end
    elseif msg == "reloadui" then
        -- Reload the UI
        print("Bissy: Reloading UI...")
        ReloadUI()
    elseif msg == "debug" then
        -- Dump database for debugging
        DumpDatabase()
    elseif msg == "checkslots" then
        -- Check slot visibility
        DebugCheckSlots()
    elseif msg == "verifyslots" then
        -- Verify and fix slot configuration
        VerifySlotConfiguration()
    else
        print("Bissy: Available commands:")
        print("  /bissy show - Show the Bissy frame")
        print("  /bissy hide - Hide the Bissy frame")
        print("  /bissy reset - Reset the position of the Bissy frame")
        print("  /bissy primary - Switch to primary character set")
        print("  /bissy secondary - Switch to secondary character set")
        print("  /bissy import - Show the import dialog")
        print("  /bissy reload - Reload the current set")
        print("  /bissy reloadui - Reload the WoW UI")
        print("  /bissy debug - Show debug information")
        print("  /bissy checkslots - Check slot visibility")
        print("  /bissy verifyslots - Verify and fix slot configuration")
    end
end

-- Add slash command
SLASH_BISSY1 = "/bissy"
SlashCmdList["BISSY"] = function(msg, editBox)
    HandleSlashCommand(msg)
end