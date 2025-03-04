local addonName, addon = ...

-- Initialize saved variables
local db = BissyDB or {}
BissyDB = db

-- Visibility state
local isShown = false

-- Initialize character data
db.primary = db.primary or {}
db.secondary = db.secondary or {}
db.currentSet = db.currentSet or "primary"  -- Initialize currentSet
local currentSet = db.currentSet  -- Load the setting

-- Store item IDs for tooltip integration
local primaryItems = {}
local secondaryItems = {}

-- Debug function - only output in debug mode
local DEBUG_MODE = false
local function Debug(...)
    if DEBUG_MODE and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Bissy Debug: " .. string.format(...), 0.5, 0.5, 1)
    end
end

-- Create main frame
local Bissy = CreateFrame("Frame", "Bissy", UIParent, "PortraitFrameTemplate")
Bissy:Hide()
Bissy:SetSize(430, 550)  -- Increased width to accommodate slots on both sides
Bissy:SetPoint("CENTER")
Bissy:SetMovable(true)
Bissy:EnableMouse(true)
Bissy:RegisterForDrag("LeftButton")
Bissy:SetScript("OnDragStart", Bissy.StartMoving)
Bissy:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    
    -- Save position
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    db.position = {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName() or nil,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs
    }
end)
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
}

-- Define all equipment slots with positions matching standard WoW character sheet
local SLOT_INFO = {
    -- Left column
    { name = "HeadSlot", x = 75, y = -76 },
    { name = "NeckSlot", x = 75, y = -117 },
    { name = "ShoulderSlot", x = 75, y = -158 },
    { name = "BackSlot", x = 75, y = -199 },
    { name = "ChestSlot", x = 75, y = -240 },
    { name = "ShirtSlot", x = 75, y = -281 },
    { name = "TabardSlot", x = 75, y = -322 },
    { name = "WristSlot", x = 75, y = -363 },
    
    -- Right column
    { name = "HandsSlot", x = 340, y = -76 },
    { name = "WaistSlot", x = 340, y = -117 },
    { name = "LegsSlot", x = 340, y = -158 },
    { name = "FeetSlot", x = 340, y = -199 },
    { name = "Finger0Slot", x = 340, y = -240 },
    { name = "Finger1Slot", x = 340, y = -281 },
    { name = "Trinket0Slot", x = 340, y = -322 },
    { name = "Trinket1Slot", x = 340, y = -363 },
    
    -- Weapons row (below model)
    { name = "MainHandSlot", x = 150, y = -430 },
    { name = "SecondaryHandSlot", x = 215, y = -430 },
    { name = "RangedSlot", x = 280, y = -430 },
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
local function SwitchSet(setName)
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
    
    print("Switching to " .. setName .. " set")

    -- Only proceed with UI updates if the frame is shown
    if isShown then
        print("Updating UI with switched set")
        
        -- Clear all slots first
        ClearAllSlots()
        
        -- Get the current set data
        local currentData = db[setName]
        
        -- Process each item if we have data
        if currentData and currentData.items and #currentData.items > 0 then
            print("Displaying " .. #currentData.items .. " items for " .. setName .. " set")
            
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
                                SetItemButtonQuality(slot, itemRarity, itemLink)
                            end
                            
                            -- Store item ID for tooltip integration
                            if setName == "primary" then
                                primaryItems[slotName] = itemId
                            else
                                secondaryItems[slotName] = itemId
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
model:SetPoint("TOPLEFT", 130, -76)
model:SetSize(170, 320)  -- Adjusted size to better match character sheet
model:SetUnit("player")
Bissy.model = model  -- Store the model in the Bissy frame for easy access

-- Add equipment section titles
local leftTitle = Bissy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftTitle:SetPoint("TOPLEFT", 75, -50)
leftTitle:SetText("Armor")

local rightTitle = Bissy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightTitle:SetPoint("TOPLEFT", 340, -50)
rightTitle:SetText("Accessories")

-- Add weapons section title
local weaponsTitle = Bissy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
weaponsTitle:SetPoint("TOPLEFT", 190, -405)
weaponsTitle:SetText("Weapons")

-- Function to update the character model with equipped items
function UpdateCharacterModel()
    -- Reset the model
    model:Undress()
    
    -- Try to dress the model with all equipped items
    local itemCount = 0
    for slotName, slot in pairs(slots) do
        if slot.itemLink then
            -- Try to extract item ID from item link
            local itemID = slot.itemLink:match("item:(%d+)")
            if itemID then
                print("Bissy Debug: Trying on item ID: " .. itemID .. " for slot: " .. slotName)
                model:TryOn(itemID)
                itemCount = itemCount + 1
            else
                print("Bissy Debug: Trying on item link: " .. slot.itemLink .. " for slot: " .. slotName)
                model:TryOn(slot.itemLink)
                itemCount = itemCount + 1
            end
        end
    end
    
    print("Bissy Debug: Updated character model with " .. itemCount .. " items")
    
    -- Force model to update
    model:RefreshCamera()
    model:SetModelScale(1.0)
end

-- Function to clear all item slots
function ClearAllSlots()
    print("Bissy Debug: Clearing all slots")
    for slotName, slot in pairs(slots) do
        slot.itemLink = nil
        
        -- Clear the icon texture
        SetItemButtonTexture(slot, "")
        
        -- Clear the border color
        SetItemButtonQuality(slot, 0, "")
    end
    
    -- Also reset the model
    if Bissy.model then
        Bissy.model:Undress()
        Bissy.model:RefreshCamera()
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

-- Import dialog
function ShowImportDialog()
    if not importDialog then
        -- Create a very simple frame
        local dialog = CreateFrame("Frame", "BissyImportDialog", UIParent)
        dialog:SetSize(500, 300)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        
        -- Simple background
        local bg = dialog:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.8)
        
        -- Simple border
        local border = dialog:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.5, 0.5, 0.5, 1)
        
        -- Title
        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dialog.title:SetPoint("TOP", 0, -10)
        dialog.title:SetText("Import Character Sheet")
        
        -- Description
        dialog.desc = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dialog.desc:SetPoint("TOP", 0, -30)
        dialog.desc:SetText("Paste your character sheet JSON data below:")
        
        -- Edit box
        dialog.editBox = CreateFrame("EditBox", nil, dialog)
        dialog.editBox:SetMultiLine(true)
        dialog.editBox:SetFontObject(ChatFontNormal)
        dialog.editBox:SetWidth(450)
        dialog.editBox:SetHeight(150)
        dialog.editBox:SetPoint("TOP", 0, -60)
        dialog.editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
        
        -- Add a background to the edit box
        local bg = dialog.editBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        
        -- Scroll frame for the edit box
        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(450, 150)
        scrollFrame:SetPoint("TOP", 0, -60)
        scrollFrame:SetScrollChild(dialog.editBox)
        
        -- Test button (loads example JSON)
        local testBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        testBtn:SetText("Load Example")
        testBtn:SetSize(100, 22)
        testBtn:SetPoint("BOTTOMRIGHT", -10, 10)
        testBtn:SetScript("OnClick", function()
            local exampleJson = [[
{
  "name": "Test Character",
  "items": [
    {"id": 18832, "name": "Brutality Blade", "slot": "MAIN_HAND"},
    {"id": 18805, "name": "Core Hound Tooth", "slot": "OFF_HAND"},
    {"id": 16866, "name": "Helm of Might", "slot": "HEAD"},
    {"id": 16868, "name": "Pauldrons of Might", "slot": "SHOULDER"},
    {"id": 16865, "name": "Breastplate of Might", "slot": "CHEST"},
    {"id": 16861, "name": "Bracers of Might", "slot": "WRIST"},
    {"id": 16863, "name": "Gauntlets of Might", "slot": "HAND"},
    {"id": 16864, "name": "Belt of Might", "slot": "WAIST"},
    {"id": 16867, "name": "Legplates of Might", "slot": "LEGS"},
    {"id": 16862, "name": "Sabatons of Might", "slot": "FEET"},
    {"id": 18404, "name": "Onyxia Blood Talisman", "slot": "NECK"},
    {"id": 17063, "name": "Band of Accuria", "slot": "FINGER1"},
    {"id": 19138, "name": "Band of Sulfuras", "slot": "FINGER2"},
    {"id": 18814, "name": "Choker of the Fire Lord", "slot": "TRINKET1"},
    {"id": 18806, "name": "Core Forged Greaves", "slot": "TRINKET2"},
    {"id": 18541, "name": "Puissant Cape", "slot": "BACK"}
  ]
}
]]
            print("Bissy: Loading example JSON")
            dialog.editBox:SetText(exampleJson)
        end)
        
        -- Import button
        local importBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        importBtn:SetText("Import")
        importBtn:SetSize(100, 22)
        importBtn:SetPoint("BOTTOMRIGHT", testBtn, "BOTTOMLEFT", -5, 0)
        importBtn:SetScript("OnClick", function()
            local jsonStr = dialog.editBox:GetText()
            if not jsonStr or jsonStr == "" then
                print("Bissy: No data to import")
                return
            end
            
            print("Bissy: Attempting to parse JSON data")
            
            -- Try to use the json.lua library if available
            if json and json.decode then
                local success, result = pcall(function() return json.decode(jsonStr) end)
                if success and result and result.items then
                    print("Bissy: Successfully parsed JSON with library")
                    ProcessImportedData(result)
                    dialog:Hide()
                    return
                end
            end
            
            -- Fallback to manual parsing if json library failed or isn't available
            local data = {
                name = "Imported Character",
                items = {}
            }
            
            -- Extract character name if possible
            local name = jsonStr:match('"name"%s*:%s*"([^"]+)"')
            if name then
                data.name = name
                print("Bissy: Found character name: " .. name)
            end
            
            -- Count of items found
            local itemCount = 0
            
            -- Extract items with a simpler approach
            local itemPattern = '{"id":%s*(%d+)%s*,%s*"name":%s*"([^"]+)"%s*,%s*"slot":%s*"([^"]+)"}'
            for id, name, slot in string.gmatch(jsonStr, itemPattern) do
                -- Check if the slot is valid
                if SLOT_MAP[slot] then
                    table.insert(data.items, {
                        id = tonumber(id),
                        name = name,
                        slot = slot
                    })
                    itemCount = itemCount + 1
                end
            end
            
            -- If no items found with the first pattern, try a more flexible one
            if #data.items == 0 then
                for id, name, slot in string.gmatch(jsonStr, '"id"%s*:%s*(%d+).-"name"%s*:%s*"([^"]+)".-"slot"%s*:%s*"([^"]+)"') do
                    -- Check if the slot is valid
                    if SLOT_MAP[slot] then
                        table.insert(data.items, {
                            id = tonumber(id),
                            name = name,
                            slot = slot
                        })
                        itemCount = itemCount + 1
                    end
                end
            end
            
            -- If still no items found, try a very direct approach
            if #data.items == 0 then
                -- Try to find the items section
                local itemsSection = jsonStr:match('"items"%s*:%s*%[(.-)%]')
                if itemsSection then
                    -- Try a very simple pattern that just looks for IDs and slots
                    for id, slot in string.gmatch(itemsSection, '"id"%s*:%s*(%d+).-"slot"%s*:%s*"([^"]+)"') do
                        -- Check if the slot is valid
                        if SLOT_MAP[slot] then
                            table.insert(data.items, {
                                id = tonumber(id),
                                name = "Item " .. id,  -- Use a placeholder name
                                slot = slot
                            })
                            itemCount = itemCount + 1
                        end
                    end
                end
            end
            
            -- Process the data
            if #data.items > 0 then
                print("Bissy: Found " .. itemCount .. " items in imported data")
                ProcessImportedData(data)
                dialog:Hide()
            else
                print("Bissy: No items found in JSON data. Please check format.")
            end
        end)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        closeBtn:SetText("Cancel")
        closeBtn:SetSize(100, 22)
        closeBtn:SetPoint("BOTTOMLEFT", 10, 10)
        closeBtn:SetScript("OnClick", function()
            dialog:Hide()
        end)
        
        importDialog = dialog
    end
    
    importDialog:Show()
end

-- Create button on character frame
local openButton = CreateFrame("Button", nil, CharacterFrame, "UIPanelButtonTemplate")
openButton:SetText("Bissy")
openButton:SetSize(80, 22)
openButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -25, -25)
openButton:SetScript("OnClick", function()
    if isShown then
        Bissy:Hide()
        isShown = false
    else
        Bissy:Show()
        isShown = true
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
    print("Bissy Debug: Processing imported data")
    
    -- Validate data structure
    if not data or type(data) ~= "table" then
        print("Bissy Debug: Invalid data format - not a table")
        return false
    end
    
    if not data.items or type(data.items) ~= "table" or #data.items == 0 then
        print("Bissy Debug: Invalid data format - no items array or empty items array")
        return false
    end
    
    -- Debug: Print the imported data structure
    print("Bissy Debug: Imported data structure:")
    print("  Name: " .. (data.name or "Unknown"))
    print("  Items: " .. #data.items)
    
    -- Validate each item
    for i, item in ipairs(data.items) do
        if not item.id or not item.slot then
            print("Bissy Debug: Invalid item at index " .. i .. " - missing id or slot")
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
    local currentSetName = currentSet
    print("Bissy Debug: Saving to current set: " .. currentSetName)
    
    if currentSetName == "primary" then
        db.primary = data
    elseif currentSetName == "secondary" then
        db.secondary = data
    else
        print("Bissy Debug: Invalid current set: " .. tostring(currentSetName))
        return false
    end
    
    -- Update the UI if the frame is shown
    if isShown then
        print("Bissy Debug: Updating UI with imported data")
        SwitchSet(currentSetName)
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
        if Bissy:IsVisible() then
            print("Bissy Debug: Bissy is shown")
        else
            print("Bissy Debug: Bissy is not shown")
        end
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

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print("Bissy: Addon loaded")
        
        -- Initialize the addon
        db = BissyDB or {}
        BissyDB = db
        
        -- Initialize character sets if they don't exist
        db.primary = db.primary or {}
        db.secondary = db.secondary or {}
        
        -- Set default character set
        db.currentSet = db.currentSet or "primary"
        currentSet = db.currentSet
        
        -- Initialize item arrays
        primaryItems = {}
        secondaryItems = {}
        
        -- Debug output
        print("Bissy: Addon initialized")
        print("Bissy: Current set is " .. currentSet)
        
        -- Dump database for debugging
        DumpDatabase()
        
        -- Set the current set using our new function (with a slight delay to ensure UI is ready)
        C_Timer.After(0.1, function()
            SwitchSet(db.currentSet)
        end)
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
    elseif msg == "hide" then
        Bissy:Hide()
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