-- Lunaris HTTP Library • gamesense

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
-- #region : FFI DEFINITIONS
-- #region : STEAM API STRUCTURES
-- #region : HTTP STATUS CODES
-- #region : CONFIGURATION
-- #region : UTILITY FUNCTIONS
-- #region : CALLBACK MANAGEMENT
-- #region : STEAM API BINDINGS
-- #region : HTTP INTERFACE
-- #region : REQUEST HANDLING
-- #region : COOKIE MANAGEMENT
-- #region : CLEANUP & INITIALIZATION
-- #region : PUBLIC API

]]--

------------------------------------

-- #region : DEPENDENCIES

local ffi = require("ffi")
local base64 = require("gamesense/base64")
local assert = assert
local xpcall = xpcall
local error = error
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local client_log = client.log
local client_delay_call = client.delay_call
local ui_get = ui.get
local string_format = string.format
local ffi_typeof = ffi.typeof
local ffi_sizeof = ffi.sizeof
local ffi_cast = ffi.cast
local ffi_string = ffi.string
local ffi_gc = ffi.gc
local string_lower = string.lower
local string_len = string.len

local register_api_call_callback, register_callback, is_steam_api_call_valid

-- #endregion : DEPENDENCIES

------------------------------------

-- #region : FFI DEFINITIONS

-- Define Steam API structures if not already defined
if not pcall(ffi.sizeof, "SteamAPICall_t") then
    ffi.cdef([[
        typedef uint64_t SteamAPICall_t;
        
        struct SteamAPI_callback_base_vtbl {
            void(__thiscall *run1)(struct SteamAPI_callback_base *, void *, bool, uint64_t);
            void(__thiscall *run2)(struct SteamAPI_callback_base *, void *);
            int(__thiscall *get_size)(struct SteamAPI_callback_base *);
        };
        
        struct SteamAPI_callback_base {
            struct SteamAPI_callback_base_vtbl *vtbl;
            uint8_t flags;
            int id;
            uint64_t api_call_handle;
            struct SteamAPI_callback_base_vtbl vtbl_storage[1];
        };
    ]])
end

-- #endregion : FFI DEFINITIONS

------------------------------------

-- #region : STEAM API STRUCTURES

-- Steam API call failure messages
local steam_api_call_failure_messages = {
    [-1] = "No failure",
    [0] = "Steam gone",
    [1] = "Network failure",
    [2] = "Invalid handle",
    [3] = "Mismatched callback"
}

-- Forward declarations
local register_steam_api_call, unregister_steam_api_call_callback, is_valid_steam_api_call_handle, get_is_call_complete

-- FFI type definitions
local callback_base_type = ffi_typeof("struct SteamAPI_callback_base")
local callback_base_size = ffi_sizeof(callback_base_type)
local callback_base_array_type = ffi_typeof("struct SteamAPI_callback_base[1]")
local callback_base_ptr_type = ffi_typeof("struct SteamAPI_callback_base*")
local uintptr_type = ffi_typeof("uintptr_t")

-- Callback storage tables
local api_call_callbacks = {}
local callback_handlers = {}
local registered_callbacks = {}

-- #endregion : STEAM API STRUCTURES

------------------------------------

-- #region : HTTP STATUS CODES

-- HTTP status code messages
local http_status_messages = {
    -- 1xx Informational
    [100] = "Continue",
    [101] = "Switching Protocols",
    [102] = "Processing",
    
    -- 2xx Success
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [207] = "Multi-Status",
    [208] = "Already Reported",
    [226] = "IM Used",
    
    -- 3xx Redirection
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [306] = "Switch Proxy",
    [307] = "Temporary Redirect",
    [308] = "Permanent Redirect",
    
    -- 4xx Client Error
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Timeout",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Long",
    [415] = "Unsupported Media Type",
    [416] = "Requested Range Not Satisfiable",
    [417] = "Expectation Failed",
    [418] = "I'm a teapot",
    [420] = "Enhance Your Calm",
    [422] = "Unprocessable Entity",
    [423] = "Locked",
    [424] = "Method Failure",
    [425] = "Unordered Collection",
    [426] = "Upgrade Required",
    [428] = "Precondition Required",
    [429] = "Too Many Requests",
    [431] = "Request Header Fields Too Large",
    [444] = "No Response",
    [449] = "Retry With",
    [450] = "Blocked by Windows Parental Controls",
    [451] = "Redirect",
    [494] = "Request Header Too Large",
    [495] = "Cert Error",
    [496] = "No Cert",
    [497] = "HTTP to HTTPS",
    [499] = "Client Closed Request",
    
    -- 5xx Server Error
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Timeout",
    [505] = "HTTP Version Not Supported",
    [506] = "Variant Also Negotiates",
    [507] = "Insufficient Storage",
    [508] = "Loop Detected",
    [509] = "Bandwidth Limit Exceeded",
    [510] = "Not Extended",
    [511] = "Network Authentication Required",
    [551] = "Option not supported",
    [598] = "Network read timeout error",
    [599] = "Network connect timeout error"
}

-- #endregion : HTTP STATUS CODES

------------------------------------

-- #region : CONFIGURATION

-- Mutually exclusive request options
local mutually_exclusive_options = {
    "params",
    "body",
    "json"
}

-- Steam HTTP callback IDs
local HTTP_REQUEST_COMPLETED_CALLBACK_ID = 2101
local HTTP_REQUEST_HEADERS_RECEIVED_CALLBACK_ID = 2102
local HTTP_REQUEST_DATA_RECEIVED_CALLBACK_ID = 2103

-- #endregion : CONFIGURATION

------------------------------------

-- #region : UTILITY FUNCTIONS

-- Convert pointer to numeric value
local function pointer_to_number(ptr)
    return tonumber(ffi_cast(uintptr_type, ffi_cast(callback_base_ptr_type, ptr)))
end

-- Find signature in memory
local function find_signature(module_name, signature, return_type, offset, dereference_count)
    local address = ffi_cast("uintptr_t", client.find_signature(module_name, signature) or error("signature not found", 2))
    
    if offset ~= nil and offset ~= 0 then
        address = address + offset
    end
    
    if dereference_count ~= nil then
        for i = 1, dereference_count do
            address = ffi_cast("uintptr_t*", address)[0]
            if address == nil then
                return error("signature not found")
            end
        end
    end
    
    return ffi_cast(return_type, address)
end

-- Create wrapper for vtbl methods
local function create_vtbl_wrapper(vtbl, method_ptr)
    return function(...)
        return method_ptr(vtbl, ...)
    end
end

-- #endregion : UTILITY FUNCTIONS

------------------------------------

-- #region : CALLBACK MANAGEMENT

-- Handle callback completion
local function handle_callback_completion(callback_obj, data, has_io_failure)
    local error_message = has_io_failure and (steam_api_call_failure_messages[tonumber(callback_obj.api_call_handle)] or "Unknown error")
    callback_obj.api_call_handle = 0
    
    client_delay_call(function()
        local ptr_num = pointer_to_number(callback_obj)
        if api_call_callbacks[ptr_num] ~= nil then
            xpcall(callback_obj, client.error_log, data, error_message)
        end
        
        if callback_handlers[ptr_num] ~= nil then
            api_call_callbacks[ptr_num] = nil
            callback_handlers[ptr_num] = nil
        end
    end, client.error_log)
end

-- Cancel callback
local function cancel_callback(callback_obj)
    if callback_obj.api_call_handle ~= 0 then
        unregister_steam_api_call_callback(callback_obj, callback_obj.api_call_handle)
        callback_obj.api_call_handle = 0
        local ptr_num = pointer_to_number(callback_obj)
        api_call_callbacks[ptr_num] = nil
        callback_handlers[ptr_num] = nil
    end
end

-- Set callback metatable
setmetatable(ffi.metatype, callback_base_type, {
    __gc = cancel_callback,
    __index = {
        cancel = cancel_callback
    }
})

-- Virtual table callback functions
local vtbl_run1_callback = ffi_cast("void(__thiscall *)(struct SteamAPI_callback_base *, void *, bool, uint64_t)", 
    function(callback_obj, data, has_io_failure, api_call_handle)
        if api_call_handle == callback_obj.api_call_handle then
            handle_callback_completion(callback_obj, data, has_io_failure)
        end
    end)

local vtbl_run2_callback = ffi_cast("void(__thiscall *)(struct SteamAPI_callback_base *, void *)", 
    function(callback_obj, data)
        handle_callback_completion(callback_obj, data, false)
    end)

local vtbl_get_size_callback = ffi_cast("int(__thiscall *)(struct SteamAPI_callback_base *)", 
    function(callback_obj)
        return callback_base_size
    end)

-- Register callback for API call
function register_api_call_callback(api_call_handle, handler, callback_id)
    assert(api_call_handle ~= 0)
    
    local callback_array = callback_base_array_type()
    local callback_obj = ffi_cast(callback_base_ptr_type, callback_array)
    
    callback_obj.vtbl_storage[0].run1 = vtbl_run1_callback
    callback_obj.vtbl_storage[0].run2 = vtbl_run2_callback
    callback_obj.vtbl_storage[0].get_size = vtbl_get_size_callback
    callback_obj.vtbl = callback_obj.vtbl_storage
    callback_obj.api_call_handle = api_call_handle
    callback_obj.id = callback_id
    
    local ptr_num = pointer_to_number(callback_obj)
    api_call_callbacks[ptr_num] = handler
    callback_handlers[ptr_num] = callback_array
    
    register_steam_api_call(callback_obj, api_call_handle)
    
    return callback_obj
end

-- Register persistent callback
function register_callback(callback_id, handler)
    assert(registered_callbacks[callback_id] == nil)
    
    local callback_array = callback_base_array_type()
    local callback_obj = ffi_cast(callback_base_ptr_type, callback_array)
    
    callback_obj.vtbl_storage[0].run1 = vtbl_run1_callback
    callback_obj.vtbl_storage[0].run2 = vtbl_run2_callback
    callback_obj.vtbl_storage[0].get_size = vtbl_get_size_callback
    callback_obj.vtbl = callback_obj.vtbl_storage
    callback_obj.api_call_handle = 0
    callback_obj.id = callback_id
    
    local ptr_num = pointer_to_number(callback_obj)
    api_call_callbacks[ptr_num] = handler
    registered_callbacks[callback_id] = callback_array
    
    register_steam_api_call(callback_obj, callback_id)
end

-- #endregion : CALLBACK MANAGEMENT

------------------------------------

-- #region : STEAM API BINDINGS

-- Find Steam API functions
register_steam_api_call = find_signature("steam_api.dll", 
    "U\\x8b\\xec\\x83=\\xcc\\xcc\\xcc\\xcc\\xcc~\rh\\xcc\\xcc\\xcc\\xcc\\xff\\xcc\\xcc\\xcc\\xcc]\\xc3\\xffu", 
    "void(__cdecl*)(struct SteamAPI_callback_base *, uint64_t)")

unregister_steam_api_call_callback = find_signature("steam_api.dll", 
    "U\\x8b\\xec\\xffu\\xffu", 
    "void(__cdecl*)(struct SteamAPI_callback_base *, uint64_t)")

is_valid_steam_api_call_handle = find_signature("steam_api.dll", 
    "U\\x8b\\xec\\x83=\\xcc\\xcc\\xcc\\xcc\\xcc~\rh\\xcc\\xcc\\xcc\\xcc\\xff\\xcc\\xcc\\xcc\\xcc]\\xc3\\xc7", 
    "void(__cdecl*)(struct SteamAPI_callback_base *, int)")

is_steam_api_call_valid = find_signature("steam_api.dll", 
    "U\\x8b\\xec\\x83\\xec\\x80=\\xcc\\xcc\\xcc\\xcc\\xcc\\x84", 
    "void(__cdecl*)(struct SteamAPI_callback_base *)")

-- Get is_call_complete function
get_is_call_complete = function(vptr, vtbl_index, cast_type)
    return ffi_cast(cast_type, ffi_cast("void***", vptr)[0][vtbl_index])
end(ffi_cast("uintptr_t*", find_signature("client_panorama.dll", 
    "\\xb9\\xcc\\xcc\\xcc\\xcc\\xe8\\xcc\\xcc\\xcc\\xcc̃=\\xcc\\xcc\\xcc\\xcc\\xcc\\x84", 
    "uintptr_t", 1, 1))[3], 12, "int(__thiscall*)(void*, SteamAPICall_t)")

function is_steam_api_call_valid(api_call_handle)
    return get_is_call_complete(api_call_handle)
end

-- #endregion : STEAM API BINDINGS

------------------------------------

-- #region : HTTP INTERFACE

-- Define HTTP structures if not already defined
if not pcall(ffi_sizeof, "http_HTTPRequestHandle") then
    ffi.cdef([[
        typedef uint32_t http_HTTPRequestHandle;
        typedef uint32_t http_HTTPCookieContainerHandle;
        
        enum http_EHTTPMethod {
            k_EHTTPMethodInvalid,
            k_EHTTPMethodGET,
            k_EHTTPMethodHEAD,
            k_EHTTPMethodPOST,
            k_EHTTPMethodPUT,
            k_EHTTPMethodDELETE,
            k_EHTTPMethodOPTIONS,
            k_EHTTPMethodPATCH,
        };
        
        struct http_ISteamHTTPVtbl {
            http_HTTPRequestHandle(__thiscall *CreateHTTPRequest)(uintptr_t, enum http_EHTTPMethod, const char *);
            bool(__thiscall *SetHTTPRequestContextValue)(uintptr_t, http_HTTPRequestHandle, uint64_t);
            bool(__thiscall *SetHTTPRequestNetworkActivityTimeout)(uintptr_t, http_HTTPRequestHandle, uint32_t);
            bool(__thiscall *SetHTTPRequestHeaderValue)(uintptr_t, http_HTTPRequestHandle, const char *, const char *);
            bool(__thiscall *SetHTTPRequestGetOrPostParameter)(uintptr_t, http_HTTPRequestHandle, const char *, const char *);
            bool(__thiscall *SendHTTPRequest)(uintptr_t, http_HTTPRequestHandle, SteamAPICall_t *);
            bool(__thiscall *SendHTTPRequestAndStreamResponse)(uintptr_t, http_HTTPRequestHandle, SteamAPICall_t *);
            bool(__thiscall *DeferHTTPRequest)(uintptr_t, http_HTTPRequestHandle);
            bool(__thiscall *PrioritizeHTTPRequest)(uintptr_t, http_HTTPRequestHandle);
            bool(__thiscall *GetHTTPResponseHeaderSize)(uintptr_t, http_HTTPRequestHandle, const char *, uint32_t *);
            bool(__thiscall *GetHTTPResponseHeaderValue)(uintptr_t, http_HTTPRequestHandle, const char *, uint8_t *, uint32_t);
            bool(__thiscall *GetHTTPResponseBodySize)(uintptr_t, http_HTTPRequestHandle, uint32_t *);
            bool(__thiscall *GetHTTPResponseBodyData)(uintptr_t, http_HTTPRequestHandle, uint8_t *, uint32_t);
            bool(__thiscall *GetHTTPStreamingResponseBodyData)(uintptr_t, http_HTTPRequestHandle, uint32_t, uint8_t *, uint32_t);
            bool(__thiscall *ReleaseHTTPRequest)(uintptr_t, http_HTTPRequestHandle);
            bool(__thiscall *GetHTTPDownloadProgressPct)(uintptr_t, http_HTTPRequestHandle, float *);
            bool(__thiscall *SetHTTPRequestRawPostBody)(uintptr_t, http_HTTPRequestHandle, const char *, uint8_t *, uint32_t);
            http_HTTPCookieContainerHandle(__thiscall *CreateCookieContainer)(uintptr_t, bool);
            bool(__thiscall *ReleaseCookieContainer)(uintptr_t, http_HTTPCookieContainerHandle);
            bool(__thiscall *SetCookie)(uintptr_t, http_HTTPCookieContainerHandle, const char *, const char *, const char *);
            bool(__thiscall *SetHTTPRequestCookieContainer)(uintptr_t, http_HTTPRequestHandle, http_HTTPCookieContainerHandle);
            bool(__thiscall *SetHTTPRequestUserAgentInfo)(uintptr_t, http_HTTPRequestHandle, const char *);
            bool(__thiscall *SetHTTPRequestRequiresVerifiedCertificate)(uintptr_t, http_HTTPRequestHandle, bool);
            bool(__thiscall *SetHTTPRequestAbsoluteTimeoutMS)(uintptr_t, http_HTTPRequestHandle, uint32_t);
            bool(__thiscall *GetHTTPRequestWasTimedOut)(uintptr_t, http_HTTPRequestHandle, bool *pbWasTimedOut);
        };
    ]])
end

-- FFI types for HTTP structures
local http_request_completed_type = ffi_typeof([[
    struct {
        http_HTTPRequestHandle m_hRequest;
        uint64_t m_ulContextValue;
        bool m_bRequestSuccessful;
        int m_eStatusCode;
        uint32_t m_unBodySize;
    } *
]])

local http_request_headers_received_type = ffi_typeof([[
    struct {
        http_HTTPRequestHandle m_hRequest;
        uint64_t m_ulContextValue;
    } *
]])

local http_request_data_received_type = ffi_typeof([[
    struct {
        http_HTTPRequestHandle m_hRequest;
        uint64_t m_ulContextValue;
        uint32_t m_cOffset;
        uint32_t m_cBytesReceived;
    } *
]])

local cookie_container_type = ffi_typeof([[
    struct {
        http_HTTPCookieContainerHandle m_hCookieContainer;
    } *
]])

-- FFI array types
local steam_api_call_array_type = ffi_typeof("SteamAPICall_t[1]")
local char_array_type = ffi_typeof("const char[?]")
local uint8_array_type = ffi_typeof("uint8_t[?]")
local uint32_array_type = ffi_typeof("unsigned int[?]")
local bool_array_type = ffi_typeof("bool[1]")
local float_array_type = ffi_typeof("float[1]")

-- Get ISteamHTTP interface
local isteam_http_ptr, isteam_http_vtbl = (function()
    local steam_client_ptr = ffi_cast("uintptr_t*", find_signature("client_panorama.dll", 
        "\\xb9\\xcc\\xcc\\xcc\\xcc\\xe8\\xcc\\xcc\\xcc\\xcc̃=\\xcc\\xcc\\xcc\\xcc\\xcc\\x84", 
        "uintptr_t", 1, 1))[12]
    
    if steam_client_ptr == 0 or steam_client_ptr == nil then
        return error("find_isteamhttp failed")
    end
    
    local vtbl_ptr = ffi_cast("struct http_ISteamHTTPVtbl**", steam_client_ptr)[0]
    if vtbl_ptr == 0 or vtbl_ptr == nil then
        return error("find_isteamhttp failed")
    end
    
    return steam_client_ptr, vtbl_ptr
end)()

-- Create wrappers for HTTP API methods
local http_create_request = create_vtbl_wrapper(isteam_http_vtbl.CreateHTTPRequest, isteam_http_ptr)
local http_set_context_value = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestContextValue, isteam_http_ptr)
local http_set_network_timeout = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestNetworkActivityTimeout, isteam_http_ptr)
local http_set_header = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestHeaderValue, isteam_http_ptr)
local http_set_parameter = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestGetOrPostParameter, isteam_http_ptr)
local http_send_request = create_vtbl_wrapper(isteam_http_vtbl.SendHTTPRequest, isteam_http_ptr)
local http_send_streaming_request = create_vtbl_wrapper(isteam_http_vtbl.SendHTTPRequestAndStreamResponse, isteam_http_ptr)
local http_defer_request = create_vtbl_wrapper(isteam_http_vtbl.DeferHTTPRequest, isteam_http_ptr)
local http_prioritize_request = create_vtbl_wrapper(isteam_http_vtbl.PrioritizeHTTPRequest, isteam_http_ptr)
local http_get_response_header_size = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPResponseHeaderSize, isteam_http_ptr)
local http_get_response_header_value = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPResponseHeaderValue, isteam_http_ptr)
local http_get_response_body_size = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPResponseBodySize, isteam_http_ptr)
local http_get_response_body_data = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPResponseBodyData, isteam_http_ptr)
local http_get_streaming_response_body_data = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPStreamingResponseBodyData, isteam_http_ptr)
local http_release_request = create_vtbl_wrapper(isteam_http_vtbl.ReleaseHTTPRequest, isteam_http_ptr)
local http_get_download_progress = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPDownloadProgressPct, isteam_http_ptr)
local http_set_raw_post_body = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestRawPostBody, isteam_http_ptr)
local http_create_cookie_container = create_vtbl_wrapper(isteam_http_vtbl.CreateCookieContainer, isteam_http_ptr)
local http_release_cookie_container = create_vtbl_wrapper(isteam_http_vtbl.ReleaseCookieContainer, isteam_http_ptr)
local http_set_cookie = create_vtbl_wrapper(isteam_http_vtbl.SetCookie, isteam_http_ptr)
local http_set_cookie_container = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestCookieContainer, isteam_http_ptr)
local http_set_user_agent = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestUserAgentInfo, isteam_http_ptr)
local http_set_require_ssl = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestRequiresVerifiedCertificate, isteam_http_ptr)
local http_set_absolute_timeout = create_vtbl_wrapper(isteam_http_vtbl.SetHTTPRequestAbsoluteTimeoutMS, isteam_http_ptr)
local http_get_was_timed_out = create_vtbl_wrapper(isteam_http_vtbl.GetHTTPRequestWasTimedOut, isteam_http_ptr)

-- #endregion : HTTP INTERFACE

------------------------------------

-- #region : REQUEST HANDLING

-- Storage for handlers and data
local completed_callbacks = {}
local headers_received_active = false
local data_received_active = false
local request_headers = {}
local headers_received_registered = false
local headers_received_callbacks = {}
local data_received_registered = false

local response_headers_cache = setmetatable({}, { __mode = "k" })
local cookie_containers_cache = setmetatable({}, { __mode = "k" })
local request_handle_to_completed_struct = setmetatable({}, { __mode = "v" })
local active_requests = {}

-- Metatable for response headers access
local response_headers_metatable = {
    __metatable = false,
    __index = function(self, header_name)
        local request_struct = request_handle_to_completed_struct[self]
        if request_struct == nil then
            return
        end
        
        header_name = string_lower(header_name)
        
        if request_struct.m_hRequest ~= 0 then
            local size_array = uint32_array_type(1)
            if http_get_response_header_size(request_struct.m_hRequest, header_name, size_array) and size_array ~= nil then
                local header_size = size_array[0]
                if header_size < 0 then
                    return
                end
                
                local header_buffer = uint8_array_type(header_size)
                if http_get_response_header_value(request_struct.m_hRequest, header_name, header_buffer, header_size) then
                    self[header_name] = ffi_string(header_buffer, header_size - 1)
                    return self[header_name]
                end
            end
        end
    end
}

-- Release HTTP request
local function release_http_request(request_struct)
    if request_struct.m_hRequest ~= 0 then
        http_release_request(request_struct.m_hRequest)
        request_struct.m_hRequest = 0
    end
end

-- Helper function for releasing and calling callback
local function release_and_callback(request_struct, ...)
    release_http_request(request_struct)
    return (...)
end

-- Safe callback invocation with error handling
local function safe_callback_invoke(request_struct, callback_func, response_data, ...)
    local request_handle = request_struct.m_hRequest
    
    if request_headers[request_handle] == nil then
        request_headers[request_handle] = setmetatable({}, response_headers_metatable)
    end
    
    local headers = request_headers[request_handle]
    request_handle_to_completed_struct[headers] = request_struct
    response_data.headers = headers
    
    headers_received_active = true
    xpcall(callback_func, client.error_log, response_data, ...)
    headers_received_active = false
end

-- Handle HTTP request completion
local function handle_http_request_completed(completed_struct, has_io_failure)
    if completed_struct == nil then
        return
    end
    
    local request_struct = ffi_cast(http_request_completed_type, completed_struct)
    
    if request_struct.m_hRequest ~= 0 and completed_callbacks[request_struct.m_hRequest] ~= nil then
        local callback_func = completed_callbacks[request_struct.m_hRequest]
        
        completed_callbacks[request_struct.m_hRequest] = nil
        request_headers[request_struct.m_hRequest] = nil
        active_requests[request_struct.m_hRequest] = nil
        
        if callback_func then
            local response_data = {}
            local status_code = request_struct.m_eStatusCode
            local body_size = request_struct.m_unBodySize
            local body_data = nil
            
            if has_io_failure == false and request_struct.m_bRequestSuccessful and body_size > 0 then
                local body_buffer = uint8_array_type(body_size)
                if http_get_response_body_data(request_struct.m_hRequest, body_buffer, body_size) then
                    body_data = ffi_string(body_buffer, body_size)
                end
            elseif not request_struct.m_bRequestSuccessful then
                local timed_out_array = bool_array_type()
                http_get_was_timed_out(request_struct.m_hRequest, timed_out_array)
                response_data.timed_out = timed_out_array ~= nil and timed_out_array[0] == true
            end
            
            if status_code > 0 then
                response_data.status_message = http_status_messages[status_code] or "Unknown status"
            elseif has_io_failure then
                response_data.status_message = string_format("IO Failure: %s", has_io_failure)
            else
                response_data.status_message = response_data.timed_out and "Timed out" or "Unknown error"
            end
            
            response_data.status = request_struct.m_eStatusCode
            response_data.body = body_data
            
            safe_callback_invoke(request_struct, callback_func, response_data)
        end
        
        release_http_request(request_struct)
    end
end

-- Handle headers received
local function handle_headers_received(headers_struct, has_io_failure)
    if headers_struct == nil then
        return
    end
    
    local request_struct = ffi_cast(http_request_headers_received_type, headers_struct)
    
    if request_struct.m_hRequest ~= 0 and headers_received_callbacks[request_struct.m_hRequest] then
        local callback_func = headers_received_callbacks[request_struct.m_hRequest]
        
        if callback_func then
            safe_callback_invoke(request_struct, callback_func, has_io_failure == false, {})
        end
    end
end

-- Handle data received (streaming)
local function handle_data_received(data_struct, has_io_failure)
    if data_struct == nil then
        return
    end
    
    local request_struct = ffi_cast(http_request_data_received_type, data_struct)
    
    if request_struct.m_hRequest ~= 0 then
        local callback_func = headers_received_callbacks[request_struct.m_hRequest]
        
        if callback_func then
            local progress_array = float_array_type()
            if http_get_download_progress(request_struct.m_hRequest, progress_array) then
                local progress = tonumber(progress_array[0])
            end
            
            local body_data = nil
            local bytes_received = request_struct.m_cBytesReceived
            local data_buffer = uint8_array_type(bytes_received)
            
            if http_get_streaming_response_body_data(request_struct.m_hRequest, 
                request_struct.m_cOffset, data_buffer, bytes_received) then
                body_data = ffi_string(data_buffer, bytes_received)
            end
            
            local response_data = {
                download_progress = progress,
                body = body_data
            }
            
            safe_callback_invoke(request_struct, callback_func, has_io_failure == false, response_data)
        end
    end
end

-- HTTP methods mapping
local http_methods = {
    get = ffi.C.k_EHTTPMethodGET,
    head = ffi.C.k_EHTTPMethodHEAD,
    post = ffi.C.k_EHTTPMethodPOST,
    put = ffi.C.k_EHTTPMethodPUT,
    delete = ffi.C.k_EHTTPMethodDELETE,
    options = ffi.C.k_EHTTPMethodOPTIONS,
    patch = ffi.C.k_EHTTPMethodPATCH
}

-- #endregion : REQUEST HANDLING

------------------------------------

-- #region : COOKIE MANAGEMENT

-- Metatable for cookie containers
local cookie_container_metatable = {
    __metatable = false,
    __index = {
        set_cookie = function(self, host, url, cookie_name, cookie_value)
            local container_struct = cookie_containers_cache[self]
            if container_struct == nil or container_struct.m_hCookieContainer == 0 then
                return
            end
            
            http_set_cookie(container_struct.m_hCookieContainer, host, url, 
                tostring(cookie_name) .. "=" .. tostring(cookie_value))
        end
    }
}

-- Release cookie container
local function release_cookie_container(container_struct)
    if container_struct.m_hCookieContainer ~= 0 then
        http_release_cookie_container(container_struct.m_hCookieContainer)
        container_struct.m_hCookieContainer = 0
    end
end

-- #endregion : COOKIE MANAGEMENT

------------------------------------

-- #region : CLEANUP & INITIALIZATION

-- Cleanup on shutdown
client.set_event_callback("shutdown", function()
    for _, callback_array in pairs(callback_handlers) do
        unregister_steam_api_call_callback(ffi_cast(callback_base_ptr_type, callback_array))
    end
    
    for _, callback_array in pairs(registered_callbacks) do
        is_valid_steam_api_call_handle(ffi_cast(callback_base_ptr_type, callback_array))
    end
end)

-- #endregion : CLEANUP & INITIALIZATION

------------------------------------

-- #region : PUBLIC API

-- Exported API
return {
    -- Main function for HTTP requests
    request = function(method, url, options, callbacks)
        -- If options is a function, it's the callback
        if type(options) == "function" and callbacks == nil then
            callbacks = options
            options = {}
        end
        
        options = options or {}
        
        -- Validate method
        local http_method = http_methods[string_lower(tostring(method))]
        if http_method == nil then
            return error("invalid HTTP method")
        end
        
        -- Validate URL
        if type(url) ~= "string" then
            return error("URL has to be a string")
        end
        
        -- Parse callbacks
        local completed_callback, headers_callback, data_callback
        
        if type(callbacks) == "function" then
            completed_callback = callbacks
        elseif type(callbacks) == "table" then
            headers_callback = callbacks.headers_received or callbacks.headers
            data_callback = callbacks.data_received or callbacks.data
            completed_callback = callbacks.completed or callbacks.complete
            
            if completed_callback ~= nil and type(completed_callback) ~= "function" then
                return error("callbacks.completed callback has to be a function")
            elseif headers_callback ~= nil and type(headers_callback) ~= "function" then
                return error("callbacks.headers_received callback has to be a function")
            elseif data_callback ~= nil and type(data_callback) ~= "function" then
                return error("callbacks.data_received callback has to be a function")
            end
        else
            return error("callbacks has to be a function or table")
        end
        
        -- Create HTTP request
        local request_handle = http_create_request(http_method, url)
        if request_handle == 0 then
            return error("Failed to create HTTP request")
        end
        
        -- Check mutually exclusive options
        local has_exclusive_option = false
        for _, option_name in ipairs(mutually_exclusive_options) do
            if options[option_name] ~= nil then
                if has_exclusive_option then
                    return error("can only set options.params, options.body or options.json")
                else
                    has_exclusive_option = true
                end
            end
        end
        
        -- Handle JSON
        local post_body = nil
        if options.json ~= nil then
            local success, json_string = xpcall(json.stringify, options.json)
            if not success then
                return error("options.json is invalid: " .. json_string)
            end
            post_body = json_string
        end
        
        -- Set network timeout
        local network_timeout = options.network_timeout
        if network_timeout == nil then
            network_timeout = 10
        end
        
        if type(network_timeout) == "number" and network_timeout > 0 then
            if not http_set_network_timeout(request_handle, network_timeout) then
                return release_and_callback(request_handle, error("failed to set network_timeout"))
            end
        elseif network_timeout ~= nil then
            return release_and_callback(request_handle, error("options.network_timeout has to be of type number and greater than 0"))
        end
        
        -- Set absolute timeout
        local absolute_timeout = options.absolute_timeout
        if absolute_timeout == nil then
            absolute_timeout = 30
        end
        
        if type(absolute_timeout) == "number" and absolute_timeout > 0 then
            if not http_set_absolute_timeout(request_handle, absolute_timeout * 1000) then
                return release_and_callback(request_handle, error("failed to set absolute_timeout"))
            end
        elseif absolute_timeout ~= nil then
            return release_and_callback(request_handle, error("options.absolute_timeout has to be of type number and greater than 0"))
        end
        
        -- Set headers
        local content_type = post_body ~= nil and "application/json" or "text/plain"
        local has_authorization_header = false
        
        if type(options.headers) == "table" then
            for header_name, header_value in pairs(options.headers) do
                local header_name_lower = string_lower(tostring(header_name))
                
                if header_name_lower == "content-type" then
                    content_type = tostring(header_value)
                elseif header_name_lower == "authorization" then
                    has_authorization_header = true
                end
                
                if not http_set_header(request_handle, header_name, header_value) then
                    return release_and_callback(request_handle, error("failed to set header " .. header_name))
                end
            end
        elseif options.headers ~= nil then
            return release_and_callback(request_handle, error("options.headers has to be of type table"))
        end
        
        -- Set authorization
        if type(options.authorization) == "table" then
            if has_authorization_header then
                return release_and_callback(request_handle, error("Cannot set both options.authorization and the 'Authorization' header."))
            end
            
            local auth_header = string_format("Basic %s", 
                base64.encode(string_format("%s:%s", 
                    tostring(options.authorization[1]), 
                    tostring(options.authorization[2])), "base64"))
            
            if not http_set_header(request_handle, "Authorization", auth_header) then
                return release_and_callback(request_handle, error("failed to apply options.authorization"))
            end
        elseif options.authorization ~= nil then
            return release_and_callback(request_handle, error("options.authorization has to be of type table"))
        end
        
        -- Set request body
        local body = post_body or options.body
        if type(body) == "string" then
            if not http_set_raw_post_body(request_handle, content_type, 
                ffi_cast("unsigned char*", body), string_len(body)) then
                return release_and_callback(request_handle, error("failed to set post body"))
            end
        elseif body ~= nil then
            return release_and_callback(request_handle, error("options.body has to be of type string"))
        end
        
        -- Set parameters
        if type(options.params) == "table" then
            for param_name, param_value in pairs(options.params) do
                if not http_set_parameter(request_handle, tostring(param_name or nil), tostring(param_value)) then
                    return release_and_callback(request_handle, error("failed to set parameter " .. param_name))
                end
            end
        elseif options.params ~= nil then
            return release_and_callback(request_handle, error("options.params has to be of type table"))
        end
        
        -- Set require_ssl
        if type(options.require_ssl) == "boolean" then
            if not http_set_require_ssl(request_handle, options.require_ssl == true) then
                return release_and_callback(request_handle, error("failed to set require_ssl"))
            end
        elseif options.require_ssl ~= nil then
            return release_and_callback(request_handle, error("options.require_ssl has to be of type boolean"))
        end
        
        -- Set user agent
        if type(options.user_agent_info) == "string" then
            if not http_set_user_agent(request_handle, tostring(options.user_agent_info)) then
                return release_and_callback(request_handle, error("failed to set user_agent_info"))
            end
        elseif options.user_agent_info ~= nil then
            return release_and_callback(request_handle, error("options.user_agent_info has to be of type string"))
        end
        
        -- Set cookie container
        if type(options.cookie_container) == "table" then
            local container_struct = cookie_containers_cache[options.cookie_container]
            if container_struct ~= nil and container_struct.m_hCookieContainer ~= 0 then
                if not http_set_cookie_container(request_handle, container_struct.m_hCookieContainer) then
                    return release_and_callback(request_handle, error("failed to set user_agent_info"))
                end
            else
                return release_and_callback(request_handle, error("options.cookie_container has to a valid cookie container"))
            end
        elseif options.cookie_container ~= nil then
            return release_and_callback(request_handle, error("options.cookie_container has to a valid cookie container"))
        end
        
        -- Determine request type (streaming or normal)
        local send_func = http_send_request
        
        if type(options.stream_response) == "boolean" then
            if options.stream_response then
                send_func = http_send_streaming_request
                
                if completed_callback == nil and headers_callback == nil and data_callback == nil then
                    return release_and_callback(request_handle, error("a 'completed', 'headers_received' or 'data_received' callback is required"))
                end
            elseif completed_callback == nil then
                return release_and_callback(request_handle, error("'completed' callback has to be set for non-streamed requests"))
            elseif headers_callback ~= nil or data_callback ~= nil then
                return release_and_callback(request_handle, error("non-streamed requests only support 'completed' callbacks"))
            end
        elseif options.stream_response ~= nil then
            return release_and_callback(request_handle, error("options.stream_response has to be of type boolean"))
        end
        
        -- Register callbacks for headers and data if needed
        if headers_callback ~= nil or data_callback ~= nil then
            headers_received_callbacks[request_handle] = headers_callback or false
            
            if headers_callback ~= nil and not headers_received_registered then
                register_callback(HTTP_REQUEST_HEADERS_RECEIVED_CALLBACK_ID, handle_headers_received)
                headers_received_registered = true
            end
            
            active_requests[request_handle] = data_callback or false
            
            if data_callback ~= nil and not data_received_registered then
                register_callback(HTTP_REQUEST_DATA_RECEIVED_CALLBACK_ID, handle_data_received)
                data_received_registered = true
            end
        end
        
        -- Send request
        local api_call_array = steam_api_call_array_type()
        if not send_func(request_handle, api_call_array) then
            release_http_request(request_handle)
            
            if completed_callback ~= nil then
                completed_callback(false, {
                    status_message = "Failed to send request",
                    status = 0
                })
            end
            
            return
        end
        
        -- Set priority if specified
        if options.priority == "defer" or options.priority == "prioritize" then
            local priority_func = options.priority == "prioritize" and http_prioritize_request or http_defer_request
            
            if not priority_func(request_handle) then
                return release_and_callback(request_handle, error("failed to set priority"))
            end
        elseif options.priority ~= nil then
            return release_and_callback(request_handle, error("options.priority has to be 'defer' of 'prioritize'"))
        end
        
        -- Save completed callback
        completed_callbacks[request_handle] = completed_callback or false
        
        -- Register completion callback
        if completed_callback ~= nil then
            register_api_call_callback(api_call_array[0], handle_http_request_completed, HTTP_REQUEST_COMPLETED_CALLBACK_ID)
        end
    end,
    
    -- Create cookie container
    create_cookie_container = function(allow_modification)
        if allow_modification ~= nil and type(allow_modification) ~= "boolean" then
            return error("allow_modification has to be of type boolean")
        end
        
        local container_handle = http_create_cookie_container(allow_modification == true)
        if container_handle ~= nil then
            local container_struct = cookie_container_type(container_handle)
            ffi_gc(container_struct, release_cookie_container)
            
            local container_table = setmetatable({}, cookie_container_metatable)
            cookie_containers_cache[container_table] = container_struct
            
            return container_table
        end
    end
}

-- Create convenience methods for each HTTP method
for method_name, _ in pairs(http_methods) do
    _G[method_name] = function(...)
        return request(method_name, ...)
    end
end

-- #endregion : PUBLIC API

------------------------------------
