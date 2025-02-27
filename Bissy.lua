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

-- Initialize JSON module if not available globally
if not json then
    json = {}
end

-- Check if JSON module is loaded
if not addon.json then
    addon.json = json
end

-- Function to load JSON module
local function LoadJSONModule()
    -- First check if we already have a working JSON module
    if addon.json and addon.json.decode then
        return true
    end
    
    -- Try to use the global json module if available
    if json and json.decode then
        addon.json = json
        return true
    end
    
    -- If we get here, we need to create our own json module
    addon.json = addon.json or {}
    
    -- Create a simple decode function if needed
    if not addon.json.decode then
        addon.json.decode = function(str)
            -- Very basic JSON parser for simple structures
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("Bissy: Using built-in JSON parser", 1, 0.7, 0)
            end
            
            -- Try to parse with a simple approach
            local success, data = pcall(function()
                return loadstring("return " .. str:gsub("([%w_]+):", "[%1]="):gsub("%[%s*([%w_\"\']+)%s*%]", "[%1]"))()
            end)
            
            if success and data then
                return data
            end
            
            error("Failed to parse JSON")
        end
    end
    
    return true
end

-- Map slot names from JSON to WoW slot IDs
local SLOT_MAP = {
    HEAD = "HeadSlot",
    NECK = "NeckSlot",
    SHOULDERS = "ShoulderSlot",
    SHOULDER = "ShoulderSlot", -- Alternative name
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
local primaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
primaryBtn:SetText("Primary")
primaryBtn:SetSize(80, 22)
primaryBtn:SetPoint("TOP", 0, -35)
primaryBtn:SetPoint("RIGHT", -5, 0)
primaryBtn:SetScript("OnClick", function()
    addon.currentSet = "primary"
    addon:UpdateFrameTitle()
    
    -- Update the display if we have data
    if addon.db.primary then
        addon:ProcessImportedData(addon.db.primary)
    else
        -- Clear the display if no data
        addon:ClearAllSlots()
    end
    
    -- Update button states
    addon:UpdateButtonStates()
end)

-- Secondary button
local secondaryBtn = CreateFrame("Button", nil, Bissy, "UIPanelButtonTemplate")
secondaryBtn:SetText("Secondary")
secondaryBtn:SetSize(80, 22)
secondaryBtn:SetPoint("TOP", 0, -35)
secondaryBtn:SetPoint("LEFT", 5, 0)
secondaryBtn:SetScript("OnClick", function()
    addon.currentSet = "secondary"
    addon:UpdateFrameTitle()
    
    -- Update the display if we have data
    if addon.db.secondary then
        addon:ProcessImportedData(addon.db.secondary)
    else
        -- Clear the display if no data
        addon:ClearAllSlots()
    end
    
    -- Update button states
    addon:UpdateButtonStates()
end)

-- Function to update button states based on current set
function addon:UpdateButtonStates()
    if addon.currentSet == "primary" then
        primaryBtn:SetEnabled(false)
        secondaryBtn:SetEnabled(true)
    else
        primaryBtn:SetEnabled(true)
        secondaryBtn:SetEnabled(false)
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

-- Function to clear all slots (for when switching between sets with no data)
function addon:ClearAllSlots()
    -- Create slots array if it doesn't exist
    addon.slots = addon.slots or {}
    
    -- Populate slots array if it's empty
    if #addon.slots == 0 then
        for _, info in ipairs(SLOT_INFO) do
            table.insert(addon.slots, info)
        end
    end
    
    for _, slot in ipairs(addon.slots) do
        local button = _G["BissyItem"..slot.name]
        if button then
            button.itemLink = nil
            button.itemID = nil
            button.icon:SetTexture(nil)
            button.name:SetText("")
        end
    end
end

-- Show the frame
Bissy:SetScript("OnShow", function()
    -- Update the character model when the frame is shown
    addon.UpdateCharacterModel()
end)

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
    {"id": 16863, "name": "Gauntlets of Might", "slot": "HANDS"},
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
            
            -- Debug output
            print("Bissy: Parsing JSON string of length " .. #jsonStr)
            
            -- Extract items using a more flexible pattern matching
            local data = {}
            data.items = {}
            
            -- Extract character name
            data.name = jsonStr:match('"name"%s*:%s*"([^"]+)"')
            if not data.name then
                data.name = "Unknown Character"
            end
            
            -- Extract items using a more flexible pattern matching
            for itemSection in jsonStr:gmatch('(%{[^%{%}]*"slot"%s*:%s*"[^"]+"%s*[^%{%}]*%})') do
                local id = itemSection:match('"id"%s*:%s*(%d+)')
                local name = itemSection:match('"name"%s*:%s*"([^"]+)"')
                local slot = itemSection:match('"slot"%s*:%s*"([^"]+)"')
                
                if id and name and slot then
                    print("Bissy: Found item - " .. name .. " (ID: " .. id .. ", Slot: " .. slot .. ")")
                    table.insert(data.items, {
                        id = tonumber(id),
                        name = name,
                        slot = slot
                    })
                end
            end
            
            if #data.items > 0 then
                print("Bissy: Import successful! Found " .. #data.items .. " items.")
                addon:ProcessImportedData(data)
                dialog:Hide()
            else
                print("Bissy: Failed to parse import data - no items found")
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
    local setName = addon.currentSet == "primary" and "Primary" or "Secondary"
    local characterName = ""
    
    -- Get character name from the current set
    if addon.currentSet == "primary" and addon.db.primary and addon.db.primary.name then
        characterName = " - " .. addon.db.primary.name
    elseif addon.currentSet == "secondary" and addon.db.secondary and addon.db.secondary.name then
        characterName = " - " .. addon.db.secondary.name
    end
    
    Bissy:SetTitle("Bissy (" .. setName .. ")" .. characterName)
end

-- Process imported data
function addon:ProcessImportedData(data)
    if not data then
        print("Bissy: Import data is nil")
        return
    end
    
    -- Save the data to the appropriate set
    if addon.currentSet == "primary" then
        addon.db.primary = data
    else
        addon.db.secondary = data
    end
    
    -- Hide any existing frame before showing the new one
    if Bissy:IsShown() then
        Bissy:Hide()
    end
    
    -- Show the frame
    Bissy:Show()
    
    -- Check if we have items
    if not data.items then
        addon:Debug("No items found in import data")
        return
    end
    
    -- Clear all slots first
    for slotName, slot in pairs(slots) do
        if slot.SetNormalTexture then
            -- Use appropriate texture based on slot
            local slotTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slotName
            slot:SetNormalTexture(slotTexture)
        end
        slot.itemLink = nil
        if slot.icon then
            slot.icon:Hide()
        end
        if slot.IconBorder then
            slot.IconBorder:Hide()
        end
    end
    
    -- Track how many items were successfully equipped
    local equippedCount = 0
    
    -- Process each item
    for _, item in ipairs(data.items) do
        -- Map JSON slot name to WoW slot ID
        local slotName = SLOT_MAP[item.slot]
        if not slotName then
            addon:Debug("Unknown slot:", (item.slot or "nil"))
        else
            -- Get the slot
            local slot = slots[slotName]
            if not slot then
                addon:Debug("Slot not found:", slotName)
            else
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
                    else
                        slot.IconBorder:Hide()
                    end
                    
                    equippedCount = equippedCount + 1
                else
                    -- Item not in cache, request it
                    local item = Item:CreateFromItemID(item.id)
                    item:ContinueOnItemLoad(function()
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
                            else
                                slot.IconBorder:Hide()
                            end
                            
                            equippedCount = equippedCount + 1
                            
                            -- Update the model
                            addon.UpdateCharacterModel()
                        else
                            addon:Debug("Failed to load item info even after request")
                        end
                    end)
                end
            end
        end
    end
    
    -- Update the character model
    addon.UpdateCharacterModel()
    
    addon:Debug("Import complete.", equippedCount, "items equipped.")
    
    -- Update the frame title
    addon:UpdateFrameTitle()
    
    -- Update button states
    addon:UpdateButtonStates()
    
    -- Store the imported data
    if addon.currentSet == "primary" then
        addon.primaryItems = {}
        for _, item in ipairs(data.items) do
            table.insert(addon.primaryItems, item.id)
        end
    elseif addon.currentSet == "secondary" then
        addon.secondaryItems = {}
        for _, item in ipairs(data.items) do
            table.insert(addon.secondaryItems, item.id)
        end
    end
end

-- Fallback JSON parser for when the main parser fails
function addon:FallbackJSONParse(jsonStr)
    addon:Debug("Using fallback JSON parser")
    
    -- Try to parse with a simple approach
    local success, data = pcall(function()
        -- Very simple JSON parser for basic structures
        local parsed = loadstring("return " .. jsonStr:gsub("([%w_]+):", "[%1]="):gsub("%[%s*([%w_\"\']+)%s*%]", "[%1]"))()
        return parsed
    end)
    
    if not success or not data then
        -- Try another approach - extract specific fields
        local result = {}
        result.name = jsonStr:match('"name"%s*:%s*"([^"]+)"')
        result.items = {}
        
        -- Extract items with regex
        for id, name, slot in jsonStr:gmatch('"id"%s*:%s*(%d+)%s*,%s*"name"%s*:%s*"([^"]+)"%s*,%s*"slot"%s*:%s*"([^"]+)"') do
            table.insert(result.items, {
                id = tonumber(id),
                name = name,
                slot = slot
            })
        end
        
        if #result.items > 0 then
            return result
        end
    else
        return data
    end
    
    return nil
end

-- Function to initialize the addon
function addon:OnInitialize()
    -- Initialize database
    addon.db = BissyDB or {}
    BissyDB = addon.db
    
    -- Restore position if saved
    if addon.db.position then
        Bissy:ClearAllPoints()
        -- Safe position loading
        local pos = addon.db.position
        if pos.point and pos.relativePoint and pos.x and pos.y then
            Bissy:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.x, pos.y)
        else
            -- Default position if saved position is invalid
            Bissy:SetPoint("CENTER")
        end
    end
    
    -- Load any saved import data
    if addon.db.primary or addon.db.secondary then
        addon:Debug("Found saved character data")
        
        -- Populate item lists for tooltip integration
        addon.primaryItems = {}
        addon.secondaryItems = {}
        
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
        
        -- Set up a hook to restore data when frame is shown
        local originalOnShow = Bissy:GetScript("OnShow")
        Bissy:SetScript("OnShow", function(self)
            -- Call original OnShow if it exists
            if originalOnShow then
                originalOnShow(self)
            end
            
            -- Restore imported data for current set
            if addon.currentSet == "primary" and addon.db.primary then
                addon:Debug("Restoring primary character set")
                addon:ProcessImportedData(addon.db.primary)
            elseif addon.currentSet == "secondary" and addon.db.secondary then
                addon:Debug("Restoring secondary character set")
                addon:ProcessImportedData(addon.db.secondary)
            else
                -- Clear all slots if no data
                addon:ClearAllSlots()
            end
            
            -- Update the frame title
            addon:UpdateFrameTitle()
            
            -- Update button states
            addon:UpdateButtonStates()
        end)
    end
end

-- Add slash command
SLASH_BISSY1 = "/bissy"
SlashCmdList["BISSY"] = function(msg)
    local command = msg:match("^%s*(%S+)") or ""
    command = command:lower()
    
    if command == "reset" or command == "resetpos" then
        -- Reset the position
        Bissy:ClearAllPoints()
        Bissy:SetPoint("CENTER")
        addon.db.position = nil
        print("Bissy: Position has been reset.")
    elseif command == "import" then
        addon:ShowImportDialog()
    elseif command == "test" then
        -- Test the JSON parser
        if not json or not json.decode then
            print("Bissy: JSON module not loaded")
            return
        end
        
        local testJson = [[
{
  "name": "Test Character",
  "items": [
    {"id": 18832, "name": "Brutality Blade", "slot": "MAIN_HAND"},
    {"id": 18805, "name": "Core Hound Tooth", "slot": "OFF_HAND"}
  ]
}
]]
        
        local success, result = pcall(function() return json.decode(testJson) end)
        if success and result then
            print("Bissy: JSON test successful")
            print("Character name: " .. (result.name or "Unknown"))
            print("Items: " .. (result.items and #result.items or 0))
        else
            print("Bissy: JSON test failed: " .. tostring(result))
        end
    elseif command == "primary" then
        -- Switch to primary set
        addon.currentSet = "primary"
        print("Bissy: Switched to primary character set")
        
        -- Update button states
        addon:UpdateButtonStates()
        
        -- Update if frame is shown
        if Bissy:IsShown() and addon.db.primary then
            addon:ProcessImportedData(addon.db.primary)
        else
            addon:UpdateFrameTitle()
        end
    elseif command == "secondary" then
        -- Switch to secondary set
        addon.currentSet = "secondary"
        print("Bissy: Switched to secondary character set")
        
        -- Update button states
        addon:UpdateButtonStates()
        
        -- Update if frame is shown
        if Bissy:IsShown() and addon.db.secondary then
            addon:ProcessImportedData(addon.db.secondary)
        else
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
        print("  /bissy resetpos - Reset the frame position")
        print("  /bissy import - Show the import dialog")
        print("  /bissy test - Test the addon")
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

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        -- Check if JSON module is loaded
        if DEFAULT_CHAT_FRAME then
            if LoadJSONModule() then
                DEFAULT_CHAT_FRAME:AddMessage("Bissy: Loaded successfully", 0, 1, 0)
            else
                DEFAULT_CHAT_FRAME:AddMessage("Bissy: Failed to load JSON module", 1, 0, 0)
            end
        end
        
        -- Hook tooltip to show BiS status
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local name, link = tooltip:GetItem()
            if not link then return end
            
            local itemId = tonumber(string.match(link, "item:(%d+)"))
            if not itemId then return end
            
            local isPrimaryBest = false
            local isSecondaryBest = false
            
            -- Check if it's in primary list
            if addon.primaryItems then
                for _, id in ipairs(addon.primaryItems) do
                    if id == itemId then
                        isPrimaryBest = true
                        break
                    end
                end
            end
            
            -- Check if it's in secondary list
            if addon.secondaryItems then
                for _, id in ipairs(addon.secondaryItems) do
                    if id == itemId then
                        isSecondaryBest = true
                        break
                    end
                end
            end
            
            -- Add tooltip line if it's in either list
            if isPrimaryBest or isSecondaryBest then
                tooltip:AddLine(" ") -- Empty line for spacing
                tooltip:AddLine("Your best!", 1, 1, 1) -- White text
                
                if isPrimaryBest then
                    tooltip:AddLine("Primary Set", 0, 1, 0) -- Green text
                end
                
                if isSecondaryBest then
                    tooltip:AddLine("Secondary Set", 0, 1, 0) -- Green text
                end
            end
        end)
        
        -- Initialize the addon
        addon:OnInitialize()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)
