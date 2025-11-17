-- Lunaris Base64 Encoding/Decoding Library • gamesense

-- Telegram / https://t.me/Lunaris_lua
-- WebSite  / https://lunaris.tlfis.ru
-- GitHub   / https://github.com/Kugio/Lunaris-lua

--[[
# LICENSE :: MIT

MIT License

Copyright (c) 2025 Lunaris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

--@Date: 2025-17-11
--@Version: 1.0.0
--@License: MIT

------------------------------------

--[[
# NAVIGATION :: REGIONS

-- #region : DEPENDENCIES
-- #region : UTILITY FUNCTIONS
-- #region : ALPHABET MANAGEMENT
-- #region : ALPHABET CACHE
-- #region : PUBLIC API

]]--

------------------------------------

-- #region : DEPENDENCIES

local bit = require("bit")
local lshift = bit.lshift
local rshift = bit.rshift
local band = bit.band
local string_char = string.char
local string_byte = string.byte
local string_gsub = string.gsub
local string_sub = string.sub
local string_format = string.format
local table_concat = table.concat
local tostring = tostring
local error = error
local pairs = pairs

-- #endregion : DEPENDENCIES

------------------------------------

-- #region : UTILITY FUNCTIONS

-- Extract bits from a value at specified position with given width
local function extract_bits(value, position, width)
    return band(rshift(value, position), lshift(1, width) - 1)
end

-- Create encoding/decoding tables from alphabet string
local function create_alphabet_tables(alphabet)
    local encode_table = {}
    local decode_table = {}
    
    for i = 1, 65 do
        local char = string_byte(string_sub(alphabet, i, i)) or 32
        
        if decode_table[char] ~= nil then
            error("invalid alphabet: duplicate character " .. tostring(char), 3)
        end
        
        encode_table[i - 1] = char
        decode_table[char] = i - 1
    end
    
    return encode_table, decode_table
end

-- #endregion : UTILITY FUNCTIONS

------------------------------------

-- #region : ALPHABET MANAGEMENT

-- Standard Base64 alphabet (with padding)
local base64_standard_encode, base64_standard_decode = 
    create_alphabet_tables("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")

-- URL-safe Base64 alphabet (without padding)
local base64_url_encode, base64_url_decode = 
    create_alphabet_tables("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

-- #endregion : ALPHABET MANAGEMENT

------------------------------------

-- #region : ALPHABET CACHE

-- Metatable for lazy alphabet creation
local alphabet_metatable = {
    __index = function(self, alphabet_name)
        if type(alphabet_name) == "string" and (alphabet_name:len() == 64 or alphabet_name:len() == 65) then
            encode_alphabets[alphabet_name], decode_alphabets[alphabet_name] = create_alphabet_tables(alphabet_name)
            return self[alphabet_name]
        end
    end
}

-- Cache for encoding alphabets
local encode_alphabets = setmetatable({
    base64 = base64_standard_encode,
    base64url = base64_url_encode
}, alphabet_metatable)

-- Cache for decoding alphabets
local decode_alphabets = setmetatable({
    base64 = base64_standard_decode,
    base64url = base64_url_decode
}, alphabet_metatable)

-- #endregion : ALPHABET CACHE

------------------------------------

-- #region : PUBLIC API

return {
    -- Encode string to Base64
    encode = function(data, alphabet_name)
        -- Get alphabet or error
        local alphabet = encode_alphabets[alphabet_name or "base64"] or error("invalid alphabet specified", 2)
        
        local result = {}
        local result_index = 1
        local data_length = #tostring(data)
        local remainder = data_length % 3
        
        -- Cache for encoded triplets (performance optimization)
        local triplet_cache = {}
        
        -- Process full 3-byte chunks
        for i = 1, data_length - remainder, 3 do
            local byte1, byte2, byte3 = string_byte(data, i, i + 2)
            local combined = byte1 * 65536 + byte2 * 256 + byte3
            
            -- Check cache first
            if not triplet_cache[combined] then
                triplet_cache[combined] = string_char(
                    alphabet[extract_bits(combined, 18, 6)],
                    alphabet[extract_bits(combined, 12, 6)],
                    alphabet[extract_bits(combined, 6, 6)],
                    alphabet[extract_bits(combined, 0, 6)]
                )
            end
            
            result[result_index] = triplet_cache[combined]
            result_index = result_index + 1
        end
        
        -- Handle remaining bytes
        if remainder == 2 then
            local byte1, byte2 = string_byte(data, data_length - 1, data_length)
            local combined = byte1 * 65536 + byte2 * 256
            
            result[result_index] = string_char(
                alphabet[extract_bits(combined, 18, 6)],
                alphabet[extract_bits(combined, 12, 6)],
                alphabet[extract_bits(combined, 6, 6)],
                alphabet[64]
            )
        elseif remainder == 1 then
            local byte1 = string_byte(data, data_length) * 65536
            
            result[result_index] = string_char(
                alphabet[extract_bits(byte1, 18, 6)],
                alphabet[extract_bits(byte1, 12, 6)],
                alphabet[64],
                alphabet[64]
            )
        end
        
        return table_concat(result)
    end,
    
    -- Decode Base64 string
    decode = function(data, alphabet_name)
        -- Get alphabet or error
        local alphabet = decode_alphabets[alphabet_name or "base64"] or error("invalid alphabet specified", 2)
        
        -- Build pattern for invalid characters
        local pattern = "[^%w%+%/%=]"
        
        if alphabet_name then
            local char_62, char_63 = nil, nil
            
            -- Find special characters (62nd and 63rd in alphabet)
            for char, index in pairs(alphabet) do
                if index == 62 then
                    char_62 = char
                elseif index == 63 then
                    char_63 = char
                end
            end
            
            pattern = string_format("[^%%w%%%s%%%s%%=]", string_format(char_62), string_format(char_63))
        end
        
        -- Remove invalid characters
        data = string_gsub(tostring(data), pattern, "")
        
        -- Cache for decoded quads (performance optimization)
        local quad_cache = {}
        local result = {}
        local result_index = 1
        local data_length = #data
        
        -- Check for padding
        local padding = (string_sub(data, -2) == "==" and 2) or (string_sub(data, -1) == "=" and 1) or 0
        
        -- Process full 4-character chunks
        for i = 1, padding > 0 and data_length - 4 or data_length, 4 do
            local char1, char2, char3, char4 = string_byte(data, i, i + 3)
            local combined_chars = char1 * 16777216 + char2 * 65536 + char3 * 256 + char4
            
            -- Check cache first
            if not quad_cache[combined_chars] then
                local combined_values = alphabet[char1] * 262144 + alphabet[char2] * 4096 + 
                                       alphabet[char3] * 64 + alphabet[char4]
                
                quad_cache[combined_chars] = string_char(
                    extract_bits(combined_values, 16, 8),
                    extract_bits(combined_values, 8, 8),
                    extract_bits(combined_values, 0, 8)
                )
            end
            
            result[result_index] = quad_cache[combined_chars]
            result_index = result_index + 1
        end
        
        -- Handle padding
        if padding == 1 then
            local char1, char2, char3 = string_byte(data, data_length - 3, data_length - 1)
            local combined = alphabet[char1] * 262144 + alphabet[char2] * 4096 + alphabet[char3] * 64
            
            result[result_index] = string_char(
                extract_bits(combined, 16, 8),
                extract_bits(combined, 8, 8)
            )
        elseif padding == 2 then
            local char1, char2 = string_byte(data, data_length - 3, data_length - 2)
            local combined = alphabet[char1] * 262144 + alphabet[char2] * 4096
            
            result[result_index] = string_char(extract_bits(combined, 16, 8))
        end
        
        return table_concat(result)
    end
}

-- #endregion : PUBLIC API

------------------------------------
