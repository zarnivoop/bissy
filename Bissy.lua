local addonName, addon = ...

-- Initialize saved variables
addon.db = BissyDB or {}
BissyDB = addon.db

-- Initialize character data
addon.db.primary = addon.db.primary or {}
addon.db.secondary = addon.db.secondary or {}
addon.currentSet = addon.currentSet or "primary"

-- Store item IDs for tooltip integration
addon.primaryItems = {}
addon.secondaryItems = {}

-- Debug function - only output in debug mode
local DEBUG_MODE = false
function addon:Debug(...)
    if DEBUG_MODE and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Bissy Debug: " .. string.format(...), 0.5, 0.5, 1)
    end
end

-- Create main frame
local Bissy = CreateFrame("Frame", "Bissy", UIParent, "PortraitFrameTemplate")
Bissy:Hide()
Bissy:SetSize(370, 500)
Bissy:SetPoint("CENTER")
Bissy:SetMovable(true)
Bissy:EnableMouse(true)
Bissy:RegisterForDrag("LeftButton")
Bissy:SetScript("OnDragStart", Bissy.StartMoving)
Bissy:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    
    -- Save position
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    addon.db.position = {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName() or nil,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs
    }
end)
Bissy:SetClampedToScreen(true)
Bissy:SetTitle("Bissy (Primary)")

-- Add set switcher buttons
-- Primary button
addon.primaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
addon.primaryBtn:SetText("Primary")
addon.primaryBtn:SetSize(80, 22)
addon.primaryBtn:SetPoint("TOP", 0, -35)
addon.primaryBtn:SetPoint("RIGHT", Bissy, "CENTER", -2, 0)
addon.primaryBtn:SetScript("OnClick", function()
    print("Bissy: Primary button clicked")
    addon.currentSet = "primary"
    
    -- Update the display if we have data
    if addon.db.primary then
        print("Bissy: Found primary data with " .. #(addon.db.primary.items or {}) .. " items")
        -- Clear all slots first
        addon:ClearAllSlots()
        
        -- Process each item
        for _, item in ipairs(addon.db.primary.items or {}) do
            -- Map JSON slot name to WoW slot ID
            local slotName = addon.SLOT_MAP[item.slot]
            if slotName then
                -- Get the slot
                local slot = addon.slots[slotName]
                if slot then
                    -- Get item info
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                    
                    if itemLink then
                        slot.itemLink = itemLink
                        slot.icon:SetTexture(itemTexture)
                        slot.icon:Show()
                        
                        -- Set border color based on item quality
                        if itemRarity > 1 then
                            local r, g, b = GetItemQualityColor(itemRarity)
                            slot.IconBorder:SetVertexColor(r, g, b)
                            slot.IconBorder:Show()
                        end
                    end
                end
            end
        end
        
        -- Update the character model
        addon.UpdateCharacterModel()
    else
        -- Clear the display if no data
        addon:ClearAllSlots()
    end
    
    -- Update the frame title
    addon:UpdateFrameTitle()
    
    -- Update button states
    addon:UpdateButtonStates()
end)

-- Secondary button
addon.secondaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
addon.secondaryBtn:SetText("Secondary")
addon.secondaryBtn:SetSize(80, 22)
addon.secondaryBtn:SetPoint("TOP", 0, -35)
addon.secondaryBtn:SetPoint("LEFT", Bissy, "CENTER", 2, 0)
addon.secondaryBtn:SetScript("OnClick", function()
    print("Bissy: Secondary button clicked")
    addon.currentSet = "secondary"
    
    -- Update the display if we have data
    if addon.db.secondary then
        print("Bissy: Found secondary data with " .. #(addon.db.secondary.items or {}) .. " items")
        -- Clear all slots first
        addon:ClearAllSlots()
        
        -- Process each item
        for _, item in ipairs(addon.db.secondary.items or {}) do
            -- Map JSON slot name to WoW slot ID
            local slotName = addon.SLOT_MAP[item.slot]
            if slotName then
                -- Get the slot
                local slot = addon.slots[slotName]
                if slot then
                    -- Get item info
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                    
                    if itemLink then
                        slot.itemLink = itemLink
                        slot.icon:SetTexture(itemTexture)
                        slot.icon:Show()
                        
                        -- Set border color based on item quality
                        if itemRarity > 1 then
                            local r, g, b = GetItemQualityColor(itemRarity)
                            slot.IconBorder:SetVertexColor(r, g, b)
                            slot.IconBorder:Show()
                        end
                    end
                end
            end
        end
        
        -- Update the character model
        addon.UpdateCharacterModel()
    else
        -- Clear the display if no data
        addon:ClearAllSlots()
    end
    
    -- Update the frame title
    addon:UpdateFrameTitle()
    
    -- Update button states
    addon:UpdateButtonStates()
end)

-- Function to update button states based on current set
function addon:UpdateButtonStates()
    print("Bissy: Updating button states, current set: " .. addon.currentSet)
    if addon.currentSet == "primary" then
        print("Bissy: Setting primary button disabled, secondary button enabled")
        addon.primaryBtn:Disable()
        addon.secondaryBtn:Enable()
    else
        print("Bissy: Setting primary button enabled, secondary button disabled")
        addon.primaryBtn:Enable()
        addon.secondaryBtn:Disable()
    end
end

-- Call once to set initial state
addon:UpdateButtonStates()

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

-- Map JSON slot names to WoW slot IDs
addon.SLOT_MAP = {
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

-- Create character model
local model = CreateFrame("DressUpModel", nil, Bissy)
model:SetPoint("TOPLEFT", 22, -76)
model:SetSize(231, 350)  -- Increased height from 320 to 350
model:SetUnit("player")
Bissy.model = model  -- Store the model in the Bissy frame for easy access

-- Define all equipment slots
local SLOT_INFO = {
    { name = "HeadSlot", x = 254, y = -76 },
    { name = "NeckSlot", x = 254, y = -117 },
    { name = "ShoulderSlot", x = 254, y = -158 },
    { name = "BackSlot", x = 254, y = -199 },
    { name = "ChestSlot", x = 254, y = -240 },
    { name = "WristSlot", x = 254, y = -281 },
    { name = "HandsSlot", x = 254, y = -322 },
    { name = "WaistSlot", x = 254, y = -363 },
    { name = "LegsSlot", x = 295, y = -76 },
    { name = "FeetSlot", x = 295, y = -117 },
    { name = "Finger0Slot", x = 295, y = -158 },
    { name = "Finger1Slot", x = 295, y = -199 },
    { name = "Trinket0Slot", x = 295, y = -240 },
    { name = "Trinket1Slot", x = 295, y = -281 },
    { name = "MainHandSlot", x = 295, y = -322 },
    { name = "SecondaryHandSlot", x = 295, y = -363 },
    { name = "RangedSlot", x = 254, y = -404 },
    { name = "ShirtSlot", x = 295, y = -404 },
}

-- Create item slots
local slots = {}
local function CreateItemSlot(info)
    local slot = CreateFrame("Button", nil, Bissy, "ItemButtonTemplate")
    slot:SetPoint("TOPLEFT", info.x, info.y)
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
    return slot
end

for i, info in ipairs(SLOT_INFO) do
    slots[info.name] = CreateItemSlot(info)
end

-- Store the slots in the addon
addon.slots = slots

-- Function to update the character model with equipped items
local function UpdateCharacterModel()
    -- Reset the model
    model:Undress()
    
    -- Try to dress the model with all equipped items
    local itemCount = 0
    for slotName, slot in pairs(slots) do
        if slot.itemLink then
            -- Try to extract item ID from item link
            local itemID = slot.itemLink:match("item:(%d+)")
            if itemID then
                model:TryOn(itemID)
            else
                model:TryOn(slot.itemLink)
            end
            
            itemCount = itemCount + 1
        end
    end
    
    -- Force model to update
    model:RefreshCamera()
    model:SetModelScale(1.0)
end

-- Make the function available to the addon
addon.UpdateCharacterModel = UpdateCharacterModel

-- Function to clear all item slots
function addon:ClearAllSlots()
    for _, slot in pairs(addon.slots) do
        slot.itemLink = nil
        slot.icon:Hide()
        slot.IconBorder:Hide()
    end
end

-- Set up a hook to restore data when frame is shown
local originalOnShow = Bissy:GetScript("OnShow")
Bissy:SetScript("OnShow", function(self)
    -- Call original OnShow if it exists
    if originalOnShow then
        originalOnShow(self)
    end
    
    print("Bissy: Frame shown, current set: " .. addon.currentSet)
    
    -- Restore imported data for current set
    if addon.currentSet == "primary" and addon.db.primary then
        print("Bissy: Restoring primary character set")
        -- Clear all slots first
        addon:ClearAllSlots()
        
        -- Process each item
        for _, item in ipairs(addon.db.primary.items or {}) do
            -- Map JSON slot name to WoW slot ID
            local slotName = addon.SLOT_MAP[item.slot]
            if slotName then
                -- Get the slot
                local slot = addon.slots[slotName]
                if slot then
                    -- Get item info
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                    
                    if itemLink then
                        slot.itemLink = itemLink
                        slot.icon:SetTexture(itemTexture)
                        slot.icon:Show()
                        
                        -- Set border color based on item quality
                        if itemRarity > 1 then
                            local r, g, b = GetItemQualityColor(itemRarity)
                            slot.IconBorder:SetVertexColor(r, g, b)
                            slot.IconBorder:Show()
                        end
                    end
                end
            end
        end
        
        -- Update the character model
        addon.UpdateCharacterModel()
    elseif addon.currentSet == "secondary" and addon.db.secondary then
        print("Bissy: Restoring secondary character set")
        -- Clear all slots first
        addon:ClearAllSlots()
        
        -- Process each item
        for _, item in ipairs(addon.db.secondary.items or {}) do
            -- Map JSON slot name to WoW slot ID
            local slotName = addon.SLOT_MAP[item.slot]
            if slotName then
                -- Get the slot
                local slot = addon.slots[slotName]
                if slot then
                    -- Get item info
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                    
                    if itemLink then
                        slot.itemLink = itemLink
                        slot.icon:SetTexture(itemTexture)
                        slot.icon:Show()
                        
                        -- Set border color based on item quality
                        if itemRarity > 1 then
                            local r, g, b = GetItemQualityColor(itemRarity)
                            slot.IconBorder:SetVertexColor(r, g, b)
                            slot.IconBorder:Show()
                        end
                    end
                end
            end
        end
        
        -- Update the character model
        addon.UpdateCharacterModel()
    else
        -- Clear all slots if no data
        addon:ClearAllSlots()
    end
    
    -- Update the frame title
    addon:UpdateFrameTitle()
    
    -- Update button states
    addon:UpdateButtonStates()
end)

-- Show the frame
-- Bissy:SetScript("OnShow", function()
--     -- Update the character model when the frame is shown
--     addon.UpdateCharacterModel()
-- end)

-- Import dialog
function addon:ShowImportDialog()
    if not addon.importDialog then
        -- Create a very simple frame
        local dialog = CreateFrame("Frame", "BissyImportDialog", UIParent)
        dialog:SetSize(500, 300)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        
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
            
            print("Bissy: Starting import process...")
            
            -- Use a very simple approach for testing
            local data = {
                name = "Imported Character",
                items = {}
            }
            
            -- Extract character name if possible
            local name = jsonStr:match('"name"%s*:%s*"([^"]+)"')
            if name then
                data.name = name
            end
            
            -- Extract items with a simpler approach
            local itemPattern = '{"id":%s*(%d+)%s*,%s*"name":%s*"([^"]+)"%s*,%s*"slot":%s*"([^"]+)"}'
            for id, name, slot in string.gmatch(jsonStr, itemPattern) do
                print(string.format("Found item: %s (ID: %s, Slot: %s)", name, id, slot))
                -- Check if the slot is valid
                if addon.SLOT_MAP[slot] then
                    table.insert(data.items, {
                        id = tonumber(id),
                        name = name,
                        slot = slot
                    })
                    print("Bissy: Added item: " .. name)
                else
                    print("Bissy: Unknown slot: " .. slot)
                end
            end
            
            -- If no items found with the first pattern, try a more flexible one
            if #data.items == 0 then
                print("Bissy: Trying alternative pattern...")
                for id, name, slot in string.gmatch(jsonStr, '"id"%s*:%s*(%d+).-"name"%s*:%s*"([^"]+)".-"slot"%s*:%s*"([^"]+)"') do
                    print(string.format("Found item: %s (ID: %s, Slot: %s)", name, id, slot))
                    -- Check if the slot is valid
                    if addon.SLOT_MAP[slot] then
                        table.insert(data.items, {
                            id = tonumber(id),
                            name = name,
                            slot = slot
                        })
                        print("Bissy: Added item: " .. name)
                    else
                        print("Bissy: Unknown slot: " .. slot)
                    end
                end
            end
            
            -- If still no items found, try a very direct approach
            if #data.items == 0 then
                print("Bissy: Trying direct approach...")
                -- Print the first 100 characters of the JSON to debug
                print("JSON preview: " .. string.sub(jsonStr, 1, 100))
                
                -- Try to find the items section
                local itemsSection = jsonStr:match('"items"%s*:%s*%[(.-)%]')
                if itemsSection then
                    print("Found items section, length: " .. #itemsSection)
                    
                    -- Try a very simple pattern that just looks for IDs and slots
                    for id, slot in string.gmatch(itemsSection, '"id"%s*:%s*(%d+).-"slot"%s*:%s*"([^"]+)"') do
                        print(string.format("Found item ID: %s, Slot: %s", id, slot))
                        -- Check if the slot is valid
                        if addon.SLOT_MAP[slot] then
                            table.insert(data.items, {
                                id = tonumber(id),
                                name = "Item " .. id,  -- Use a placeholder name
                                slot = slot
                            })
                            print("Bissy: Added item ID: " .. id)
                        else
                            print("Bissy: Unknown slot: " .. slot)
                        end
                    end
                else
                    print("Bissy: Could not find items section")
                end
            end
            
            -- Debug output
            print("Bissy: Found " .. #data.items .. " items")
            
            -- Process the data
            if #data.items > 0 then
                print("Bissy: Import successful!")
                addon:ProcessImportedData(data)
                dialog:Hide()
            else
                print("Bissy: No items found in import data")
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
        
        addon.importDialog = dialog
    end
    
    addon.importDialog:Show()
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
    end
end)

-- Create import button
local importButton = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
importButton:SetText("Import Sheet")
importButton:SetSize(100, 22)
importButton:SetPoint("BOTTOMRIGHT", -10, 4)
importButton:SetScript("OnClick", function()
    addon:ShowImportDialog()
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
    addon.db.position = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end)

-- Function to update the frame title based on the current set
function addon:UpdateFrameTitle()
    print("Bissy: Updating frame title, current set: " .. addon.currentSet)
    if addon.currentSet == "primary" then
        Bissy:SetTitle("Bissy (Primary)")
    else
        Bissy:SetTitle("Bissy (Secondary)")
    end
end

-- Process imported data
function addon:ProcessImportedData(data)
    print("Bissy: Processing imported data for set: " .. addon.currentSet)
    
    -- Save the data to the current set
    if addon.currentSet == "primary" then
        addon.db.primary = data
        print("Bissy: Saved to primary set")
        
        -- Update primary items array for tooltip integration
        addon.primaryItems = {}
        for _, item in ipairs(data.items) do
            table.insert(addon.primaryItems, item.id)
        end
    elseif addon.currentSet == "secondary" then
        addon.db.secondary = data
        print("Bissy: Saved to secondary set")
        
        -- Update secondary items array for tooltip integration
        addon.secondaryItems = {}
        for _, item in ipairs(data.items) do
            table.insert(addon.secondaryItems, item.id)
        end
    end
    
    -- Don't show the frame automatically
    -- if not Bissy:IsShown() then
    --     Bissy:Show()
    -- end
    
    -- Check if we have items
    if not data.items then
        addon:Debug("No items found in import data")
        return
    end
    
    -- Clear all slots first
    addon:ClearAllSlots()
    
    -- Process each item
    for _, item in ipairs(data.items) do
        -- Map JSON slot name to WoW slot ID
        local slotName = addon.SLOT_MAP[item.slot]
        if not slotName then
            addon:Debug("Unknown slot:", (item.slot or "nil"))
        else
            -- Get the slot
            local slot = addon.slots[slotName]
            if not slot then
                addon:Debug("Slot not found:", slotName)
            else
                -- Get item info
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                      itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                
                if not itemLink then
                    -- Try to get item info via GetItemInfoInstant
                    local name, _, _, _, _, _, _, _, _, texture = GetItemInfoInstant(item.id)
                    if name then
                        -- We have some basic info, but not the full item link
                        -- Use a placeholder link for now
                        itemLink = "item:" .. item.id .. ":0:0:0:0:0:0:0"
                        itemName = name
                        itemTexture = texture
                        -- Request item info to cache it for later
                        addon:Debug("Requesting item info for:", name)
                    else
                        addon:Debug("Item not found:", (item.id or "nil"))
                        -- Skip this item and continue with the next one
                    end
                end
                
                -- Only set the item if we have a valid itemLink
                if itemLink then
                    -- Set the item
                    slot.itemLink = itemLink
                    slot.icon:SetTexture(itemTexture)
                    slot.icon:Show()
                    
                    -- Set border color based on item quality
                    if itemRarity and itemRarity > 1 then
                        local r, g, b = GetItemQualityColor(itemRarity)
                        slot.IconBorder:SetVertexColor(r, g, b)
                        slot.IconBorder:Show()
                    end
                    
                    addon:Debug("Set item:", itemName, "in slot:", slotName)
                end
            end
        end
    end
    
    -- Update the character model
    addon.UpdateCharacterModel()
    
    -- Update the frame title
    addon:UpdateFrameTitle()
    
    -- Update button states
    addon:UpdateButtonStates()
    
    print("Bissy: Finished processing imported data")
end

-- Test JSON parsing
function addon:TestJSONParse(jsonStr)
    if not jsonStr or jsonStr == "" then
        return false, "Empty JSON string"
    end
    
    -- Debug output
    print("Bissy: Parsing JSON string of length: " .. #jsonStr)
    print("Bissy: First 100 chars: " .. jsonStr:sub(1, 100))
    
    -- Try to use the JSON library
    if addon.json then
        local success, result
        
        -- Use the parse function
        success, result = pcall(function()
            return addon.json.parse(jsonStr)
        end)
        
        if success and result then
            -- Fix for null values in the JSON library
            if result.items == addon.json.null then
                result.items = {}
            end
            
            -- Ensure items is a table
            if not result.items then
                result.items = {}
            end
            
            return true, result
        else
            print("Bissy: JSON parse error: " .. tostring(result))
        end
    end
    
    -- If we get here, either there's no JSON library or parsing failed
    print("Bissy: Falling back to built-in parser")
    
    -- Create a basic result
    local result = {}
    
    -- Extract character name
    result.name = jsonStr:match('"name"%s*:%s*"([^"]+)"')
    if not result.name then
        result.name = "Imported Character"
    end
    
    -- Extract items
    result.items = {}
    
    -- Try to find the items section
    local itemsSection = jsonStr:match('"items"%s*:%s*%[(.-)%]')
    if itemsSection then
        print("Bissy: Found items section, length: " .. #itemsSection)
        
        -- Use a more robust approach to extract items
        local startPos = 1
        while startPos <= #itemsSection do
            -- Find the start of an item object
            local itemStart = itemsSection:find("{", startPos)
            if not itemStart then break end
            
            -- Find the matching end bracket
            local depth = 1
            local itemEnd = itemStart
            while depth > 0 and itemEnd < #itemsSection do
                itemEnd = itemEnd + 1
                local char = itemsSection:sub(itemEnd, itemEnd)
                if char == "{" then
                    depth = depth + 1
                elseif char == "}" then
                    depth = depth - 1
                end
            end
            
            if depth == 0 then
                -- Extract the complete item object
                local itemStr = itemsSection:sub(itemStart, itemEnd)
                print("Bissy: Found item: " .. itemStr)
                
                -- Extract item properties
                local id = itemStr:match('"id"%s*:%s*(%d+)')
                local name = itemStr:match('"name"%s*:%s*"([^"]+)"')
                local slot = itemStr:match('"slot"%s*:%s*"([^"]+)"')
                
                print("Bissy: Extracted - ID: " .. (id or "nil") .. 
                      ", Name: " .. (name or "nil") .. 
                      ", Slot: " .. (slot or "nil"))
                
                if id and name and slot then
                    table.insert(result.items, {
                        id = tonumber(id),
                        name = name,
                        slot = slot
                    })
                    print("Bissy: Added item: " .. name)
                end
                
                startPos = itemEnd + 1
            else
                -- Unmatched brackets, something went wrong
                print("Bissy: Error parsing item - unmatched brackets")
                break
            end
        end
    else
        -- Fallback to more basic pattern matching
        for id, name, slot in jsonStr:gmatch('"id"%s*:%s*(%d+)[^}]*"name"%s*:%s*"([^"]+)"[^}]*"slot"%s*:%s*"([^"]+)"') do
            table.insert(result.items, {
                id = tonumber(id),
                name = name,
                slot = slot
            })
        end
    end
    
    if #result.items > 0 then
        return true, result
    else
        return false, "No items found in import data"
    end
end

-- Test JSON parsing with a hardcoded example
function addon:TestDirectParse()
    local testJson = [[
{
  "name": "Test Character",
  "items": [
    {"id": 12345, "name": "Test Head Item", "slot": "HEAD"},
    {"id": 12346, "name": "Test Neck Item", "slot": "NECK"},
    {"id": 12347, "name": "Test Shoulder Item", "slot": "SHOULDER"}
  ]
}
]]
    print("Bissy: Running direct parse test")
    local success, result = addon:TestJSONParse(testJson)
    if success then
        print("Bissy: Direct parse test successful!")
        print("Character name: " .. (result.name or "Unknown"))
        print("Items: " .. (result.items and #result.items or 0))
        
        if result.items and #result.items > 0 then
            for i, item in ipairs(result.items) do
                print(string.format("Item %d: %s (ID: %d, Slot: %s)", 
                    i, item.name, item.id, item.slot))
            end
        end
    else
        print("Bissy: Direct parse test failed: " .. tostring(result))
    end
end

-- Function to initialize the addon
function addon:OnInitialize()
    -- Restore position if saved
    if addon.db.position then
        local pos = addon.db.position
        Bissy:ClearAllPoints()
        Bissy:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.x, pos.y)
    end
    
    -- Load primary and secondary items
    if addon.db.primary and addon.db.primary.items then
        for _, item in ipairs(addon.db.primary.items) do
            table.insert(addon.primaryItems, item.id)
        end
    end
    
    if addon.db.secondary and addon.db.secondary.items then
        for _, item in ipairs(addon.db.secondary.items) do
            table.insert(addon.secondaryItems, item.id)
        end
    end
end

-- Handle slash commands
function addon:HandleSlashCommand(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()
    
    if command == "show" or command == "" then
        -- Toggle visibility
        if Bissy:IsShown() then
            Bissy:Hide()
        else
            Bissy:Show()
        end
    elseif command == "reset" then
        -- Reset position
        Bissy:ClearAllPoints()
        Bissy:SetPoint("CENTER")
        addon.db.position = nil
        print("Bissy: Position reset")
    elseif command == "test" then
        -- Test JSON parsing with a simple JSON string
        local testJson = [[
{
  "name": "Test Character",
  "items": [
    {"id": 12345, "name": "Test Head Item", "slot": "HEAD"},
    {"id": 12346, "name": "Test Neck Item", "slot": "NECK"},
    {"id": 12347, "name": "Test Shoulder Item", "slot": "SHOULDER"}
  ]
}
]]
        local success, result = addon:TestJSONParse(testJson)
        if success then
            print("Bissy: JSON test successful!")
            print("Character name: " .. (result.name or "Unknown"))
            print("Items: " .. (result.items and #result.items or 0))
        else
            print("Bissy: JSON test failed: " .. tostring(result))
        end
    elseif command == "directtest" then
        -- Run the direct parse test
        addon:TestDirectParse()
    elseif command == "import" then
        addon:ShowImportDialog()
    elseif command == "primary" then
        -- Switch to primary set
        addon.currentSet = "primary"
        print("Bissy: Switched to primary character set")
        
        -- Update button states
        addon:UpdateButtonStates()
        
        -- Update if frame is shown
        if Bissy:IsShown() then
            if addon.db.primary then
                -- Clear all slots first
                addon:ClearAllSlots()
                
                -- Process each item
                for _, item in ipairs(addon.db.primary.items or {}) do
                    -- Map JSON slot name to WoW slot ID
                    local slotName = addon.SLOT_MAP[item.slot]
                    if slotName then
                        -- Get the slot
                        local slot = addon.slots[slotName]
                        if slot then
                            -- Get item info
                            local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                                  itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                            
                            if itemLink then
                                slot.itemLink = itemLink
                                slot.icon:SetTexture(itemTexture)
                                slot.icon:Show()
                                
                                -- Set border color based on item quality
                                if itemRarity > 1 then
                                    local r, g, b = GetItemQualityColor(itemRarity)
                                    slot.IconBorder:SetVertexColor(r, g, b)
                                    slot.IconBorder:Show()
                                end
                            end
                        end
                    end
                end
                
                -- Update the character model
                addon.UpdateCharacterModel()
            else
                -- Clear the display if no data
                addon:ClearAllSlots()
            end
            
            -- Update the frame title
            addon:UpdateFrameTitle()
        end
    elseif command == "secondary" then
        -- Switch to secondary set
        addon.currentSet = "secondary"
        print("Bissy: Switched to secondary character set")
        
        -- Update button states
        addon:UpdateButtonStates()
        
        -- Update if frame is shown
        if Bissy:IsShown() then
            if addon.db.secondary then
                -- Clear all slots first
                addon:ClearAllSlots()
                
                -- Process each item
                for _, item in ipairs(addon.db.secondary.items or {}) do
                    -- Map JSON slot name to WoW slot ID
                    local slotName = addon.SLOT_MAP[item.slot]
                    if slotName then
                        -- Get the slot
                        local slot = addon.slots[slotName]
                        if slot then
                            -- Get item info
                            local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, 
                                  itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(item.id)
                            
                            if itemLink then
                                slot.itemLink = itemLink
                                slot.icon:SetTexture(itemTexture)
                                slot.icon:Show()
                                
                                -- Set border color based on item quality
                                if itemRarity > 1 then
                                    local r, g, b = GetItemQualityColor(itemRarity)
                                    slot.IconBorder:SetVertexColor(r, g, b)
                                    slot.IconBorder:Show()
                                end
                            end
                        end
                    end
                end
                
                -- Update the character model
                addon.UpdateCharacterModel()
            else
                -- Clear the display if no data
                addon:ClearAllSlots()
            end
            
            -- Update the frame title
            addon:UpdateFrameTitle()
        end
    elseif command == "resetdata" then
        -- Reset all stored data
        addon.db.primary = nil
        addon.db.secondary = nil
        addon.db.importedData = nil  -- Clear legacy data format
        print("Bissy: All stored character data has been reset.")
        
        -- Clear the display if frame is shown
        if Bissy:IsShown() then
            addon:ClearAllSlots()
            addon:UpdateFrameTitle()
        end
    elseif command == "resetprimary" then
        -- Reset primary data
        addon.db.primary = nil
        print("Bissy: Primary character data has been reset.")
        
        -- Clear the display if frame is shown and on primary
        if Bissy:IsShown() and addon.currentSet == "primary" then
            addon:ClearAllSlots()
            addon:UpdateFrameTitle()
        end
    elseif command == "resetsecondary" then
        -- Reset secondary data
        addon.db.secondary = nil
        print("Bissy: Secondary character data has been reset.")
        
        -- Clear the display if frame is shown and on secondary
        if Bissy:IsShown() and addon.currentSet == "secondary" then
            addon:ClearAllSlots()
            addon:UpdateFrameTitle()
        end
    elseif command == "help" then
        print("Bissy commands:")
        print("  /bissy - Toggle the Bissy frame")
        print("  /bissy reset - Reset the frame position")
        print("  /bissy import - Show the import dialog")
        print("  /bissy test - Test the addon")
        print("  /bissy directtest - Run the direct parse test")
        print("  /bissy primary - Switch to primary character set")
        print("  /bissy secondary - Switch to secondary character set")
        print("  /bissy resetdata - Reset all stored character data")
        print("  /bissy resetprimary - Reset primary character data")
        print("  /bissy resetsecondary - Reset secondary character data")
        print("  /bissy help - Show this help message")
    else
        Bissy:SetShown(not Bissy:IsShown())
    end
end

-- Add slash command
SLASH_BISSY1 = "/bissy"
SlashCmdList["BISSY"] = function(msg)
    addon:HandleSlashCommand(msg)
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == "Bissy" then
        print("Bissy: Addon loaded")
        
        -- Initialize the addon
        addon.db = BissyDB or {}
        BissyDB = addon.db
        
        -- Set default character set
        addon.currentSet = addon.currentSet or "primary"
        print("Bissy: Addon loaded with current set: " .. addon.currentSet)
        
        -- Initialize character sets if they don't exist
        addon.db.primary = addon.db.primary or {}
        addon.db.secondary = addon.db.secondary or {}
        
        -- Initialize item arrays
        addon.primaryItems = {}
        addon.secondaryItems = {}
        
        -- Call the initialize function
        addon:OnInitialize()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)
