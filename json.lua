--[[
Simple JSON parser for WoW addons
]]

local addonName, addon = ...

local json = {}
addon.json = json

-- Simple recursive JSON parser
function json.decode(str)
    print("Bissy JSON: Starting to parse JSON string of length " .. #str)
    if #str < 10 then
        print("Bissy JSON: Input too short: " .. str)
        return nil
    end
    
    -- Check if it starts with { or [
    local firstChar = str:match("^%s*(.)")
    if firstChar ~= "{" and firstChar ~= "[" then
        print("Bissy JSON: Invalid JSON, must start with { or [, got: " .. firstChar)
        return nil
    end
    
    -- Remove comments and whitespace
    str = str:gsub("/%*.-%*/", "") -- Remove /* */ comments
    str = str:gsub("//.-\n", "\n") -- Remove // comments
    
    -- Position tracker
    local pos = 1
    
    -- Forward declarations
    local parseValue, parseObject, parseArray, parseString, parseNumber
    
    -- Skip whitespace
    local function skipWhitespace()
        local _, newPos = str:find("^[ \t\n\r]*", pos)
        if newPos then pos = newPos + 1 end
    end
    
    -- Parse a string value
    parseString = function()
        local startPos = pos
        pos = pos + 1 -- Skip opening quote
        
        local value = ""
        local escaped = false
        
        while pos <= #str do
            local c = str:sub(pos, pos)
            
            if escaped then
                if c == '"' or c == '\\' or c == '/' then
                    value = value .. c
                elseif c == 'b' then
                    value = value .. '\b'
                elseif c == 'f' then
                    value = value .. '\f'
                elseif c == 'n' then
                    value = value .. '\n'
                elseif c == 'r' then
                    value = value .. '\r'
                elseif c == 't' then
                    value = value .. '\t'
                elseif c == 'u' then
                    -- Unicode escape (not fully implemented)
                    value = value .. '\\u' .. str:sub(pos+1, pos+4)
                    pos = pos + 4
                else
                    value = value .. '\\' .. c
                end
                escaped = false
            elseif c == '\\' then
                escaped = true
            elseif c == '"' then
                pos = pos + 1
                return value
            else
                value = value .. c
            end
            
            pos = pos + 1
        end
        
        print("Bissy JSON: Unterminated string starting at position " .. startPos)
        error("Unterminated string starting at position " .. startPos)
    end
    
    -- Parse a number value
    parseNumber = function()
        local startPos = pos
        local endPos = str:find("[^0-9%.eE%+%-]", pos)
        if not endPos then endPos = #str + 1 end
        
        local numStr = str:sub(pos, endPos - 1)
        pos = endPos
        
        return tonumber(numStr)
    end
    
    -- Parse a JSON array
    parseArray = function()
        local arr = {}
        pos = pos + 1 -- Skip opening bracket
        
        skipWhitespace()
        
        -- Handle empty array
        if str:sub(pos, pos) == "]" then
            pos = pos + 1
            return arr
        end
        
        while pos <= #str do
            -- Parse array element
            table.insert(arr, parseValue())
            
            skipWhitespace()
            
            local c = str:sub(pos, pos)
            pos = pos + 1
            
            if c == "]" then
                return arr
            elseif c ~= "," then
                print("JSON Error: Expected ',' or ']' in array at position " .. pos)
                return arr -- Return what we have so far instead of erroring
            end
            
            skipWhitespace()
        end
        
        print("JSON Error: Unterminated array")
        return arr -- Return what we have so far
    end
    
    -- Parse an object
    parseObject = function()
        local obj = {}
        pos = pos + 1 -- Skip opening brace
        
        skipWhitespace()
        
        -- Handle empty object
        if str:sub(pos, pos) == "}" then
            pos = pos + 1
            return obj
        end
        
        while pos <= #str do
            skipWhitespace()
            
            -- Parse key
            if str:sub(pos, pos) ~= "\"" then
                print("JSON Error: Expected '\"' at start of object key at position " .. pos)
                return obj
            end
            
            local key = parseString()
            
            skipWhitespace()
            
            -- Check for colon
            if str:sub(pos, pos) ~= ":" then
                print("JSON Error: Expected ':' after key in object at position " .. pos)
                return obj
            end
            
            pos = pos + 1 -- Skip colon
            
            -- Parse value
            obj[key] = parseValue()
            
            skipWhitespace()
            
            local c = str:sub(pos, pos)
            pos = pos + 1
            
            if c == "}" then
                return obj
            elseif c ~= "," then
                print("JSON Error: Expected ',' or '}' in object at position " .. pos)
                return obj -- Return what we have so far instead of erroring
            end
        end
        
        print("JSON Error: Unterminated object")
        return obj -- Return what we have so far
    end
    
    -- Parse any JSON value
    parseValue = function()
        skipWhitespace()
        
        local c = str:sub(pos, pos)
        
        if c == '"' then
            return parseString()
        elseif c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == 't' and str:sub(pos, pos+3) == "true" then
            pos = pos + 4
            return true
        elseif c == 'f' and str:sub(pos, pos+4) == "false" then
            pos = pos + 5
            return false
        elseif c == 'n' and str:sub(pos, pos+3) == "null" then
            pos = pos + 4
            return nil
        elseif c:match("[%d%-]") then
            return parseNumber()
        else
            error("Unexpected character at position " .. pos .. ": " .. c)
        end
    end
    
    -- Start parsing
    local success, result = pcall(parseValue)
    if not success then
        print("Bissy JSON: Error parsing JSON: " .. tostring(result))
        return nil
    end
    
    skipWhitespace()
    
    if pos <= #str then
        print("Bissy JSON: Unexpected trailing characters at position " .. pos)
    end
    
    print("Bissy JSON: Successfully parsed JSON")
    return result
end

-- Encode a Lua table to JSON
function json.encode(value, pretty)
    local indent = pretty and "  " or ""
    local level = 0
    
    local forward_declarations
    local encode
    
    local function indentation()
        if not pretty then return "" end
        return string.rep(indent, level)
    end
    
    local function encodeString(str)
        str = str:gsub('\\', '\\\\')
        str = str:gsub('"', '\\"')
        str = str:gsub('\n', '\\n')
        str = str:gsub('\r', '\\r')
        str = str:gsub('\t', '\\t')
        str = str:gsub('\b', '\\b')
        str = str:gsub('\f', '\\f')
        return '"' .. str .. '"'
    end
    
    encode = function(val, isObjectValue)
        local valType = type(val)
        
        if val == nil then
            return "null"
        elseif valType == "number" then
            return tostring(val)
        elseif valType == "boolean" then
            return val and "true" or "false"
        elseif valType == "string" then
            return encodeString(val)
        elseif valType == "table" then
            local isArray = true
            local n = 0
            
            -- Check if it's an array
            for k, _ in pairs(val) do
                if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                    isArray = false
                    break
                end
                n = math.max(n, k)
            end
            
            if isArray and n > 0 then
                level = level + 1
                local parts = {}
                for i = 1, n do
                    if pretty then
                        table.insert(parts, indentation() .. encode(val[i]))
                    else
                        table.insert(parts, encode(val[i]))
                    end
                end
                level = level - 1
                
                if pretty then
                    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indentation() .. "]"
                else
                    return "[" .. table.concat(parts, ",") .. "]"
                end
            else
                level = level + 1
                local parts = {}
                for k, v in pairs(val) do
                    if type(k) == "string" then
                        if pretty then
                            table.insert(parts, indentation() .. encodeString(k) .. ": " .. encode(v, true))
                        else
                            table.insert(parts, encodeString(k) .. ":" .. encode(v, true))
                        end
                    end
                end
                level = level - 1
                
                if pretty then
                    if #parts > 0 then
                        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indentation() .. "}"
                    else
                        return "{}"
                    end
                else
                    return "{" .. table.concat(parts, ",") .. "}"
                end
            end
        else
            error("Cannot encode " .. valType .. " to JSON")
        end
    end
    
    return encode(value)
end

return json
