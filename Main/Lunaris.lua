-- Lunaris • gamesense
-- Telegram / https://t.me/Lunaris_lua
-- WebSite  / https://lunaris.tlfis.ru
-- GitHub   / 
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


--@Date: 2025-01-01
--@Version: CLOSED ALPHA
--@License: MIT


------------------------------------
--[[
# NAVIGATION :: REGIONS

-- #region : DEPENDENCIES
-- #region : ORIGINAL MENU REFERENCES
-- #region : HIDE ORIGINAL MENU
-- #region : USER DATA
-- #region : STATISTICS MODULE
-- #region : PUI MENU SETUP
-- #region : HOME TAB
-- #region : ANTI-AIM TAB
-- #region : VISUALS TAB
-- #region : MENU DEPENDENCIES
-- #region : REFERENCES
-- #region : VARIABLES
-- #region : FFI
-- #region : CORE FUNCTIONS
-- #region : CALLBACKS

]]--
------------------------------------


-- #region : DEPENDENCIES
local function try_require(module, msg)
    local success, result = pcall(require, module)
    if success then
        return result
    else
        return error(msg or "Failed to require module: " .. module)
    end
end

local ffi = try_require("ffi", "Failed to require FFI, please make sure 'Allow unsafe scripts' is enabled!")
local bit = try_require("bit")
local vector = try_require("vector")
local pui = try_require("gamesense/pui", "Failed to require gamesense/pui")
local http = try_require("gamesense/http")
local json = try_require("json")
-- #endregion : DEPENDENCIES


-- #region : ORIGINAL MENU REFERENCES
local original_refs = {
    enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
    pitch = { ui.reference("AA", "Anti-aimbot angles", "Pitch") },
    yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
    yaw = { ui.reference("AA", "Anti-aimbot angles", "Yaw") },
    yaw_jitter = { ui.reference("AA", "Anti-aimbot angles", "Yaw jitter") },
    body_yaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
    freestanding_body_yaw = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    freestanding = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    roll = ui.reference("AA", "Anti-aimbot angles", "Roll"),
    fl_enabled = { ui.reference("AA", "Fake lag", "Enabled") },
    fl_amount = ui.reference("AA", "Fake lag", "Amount"),
    fl_variance = ui.reference("AA", "Fake lag", "Variance"),
    fl_limit = ui.reference("AA", "Fake lag", "Limit"),
    slow_motion = { ui.reference("AA", "Other", "Slow motion") },
    leg_movement = ui.reference("AA", "Other", "Leg movement"),
    on_shot = { ui.reference("AA", "Other", "On shot anti-aim") },
    fake_peek = { ui.reference("AA", "Other", "Fake peek") }
}
-- #endregion : ORIGINAL MENU REFERENCES


-- #region : HIDE ORIGINAL MENU
local function hide_original_menu(state)
    ui.set_visible(original_refs.enabled, state)
    ui.set_visible(original_refs.pitch[1], state)
    ui.set_visible(original_refs.pitch[2], state)
    ui.set_visible(original_refs.yaw_base, state)
    ui.set_visible(original_refs.yaw[1], state)
    ui.set_visible(original_refs.yaw[2], state)
    ui.set_visible(original_refs.yaw_jitter[1], state)
    ui.set_visible(original_refs.yaw_jitter[2], state)
    ui.set_visible(original_refs.body_yaw[1], state)
    ui.set_visible(original_refs.body_yaw[2], state)
    ui.set_visible(original_refs.freestanding_body_yaw, state)
    ui.set_visible(original_refs.edge_yaw, state)
    ui.set_visible(original_refs.freestanding[1], state)
    ui.set_visible(original_refs.freestanding[2], state)
    ui.set_visible(original_refs.roll, state)
    ui.set_visible(original_refs.fl_enabled[1], state)
    ui.set_visible(original_refs.fl_enabled[2], state)
    ui.set_visible(original_refs.fl_amount, state)
    ui.set_visible(original_refs.fl_variance, state)
    ui.set_visible(original_refs.fl_limit, state)
    ui.set_visible(original_refs.slow_motion[1], state)
    ui.set_visible(original_refs.slow_motion[2], state)
    ui.set_visible(original_refs.leg_movement, state)
    ui.set_visible(original_refs.on_shot[1], state)
    ui.set_visible(original_refs.on_shot[2], state)
    ui.set_visible(original_refs.fake_peek[1], state)
    ui.set_visible(original_refs.fake_peek[2], state)
end
-- #endregion : HIDE ORIGINAL MENU


-- #region : USER DATA
local player_name_in_game = entity.get_player_name(entity.get_local_player()) or "Unknown"
local obex_data = obex_fetch and obex_fetch() or {
    username = player_name_in_game
}
-- #endregion : USER DATA


-- #region : STATISTICS MODULE
local stats = {
    data = {
        total_loads = 0,
        total_playtime = 0,
        longest_session = 0,
        last_seen = 0,
        session_start = 0,
        current_session = 0,
        user_id = nil
    },
    server = {
        status = "Connecting...",
        online_users = 0,
        total_users = 0,
        last_check = 0,
        connected = false
    }
}

local DB_KEY = "lunaris_stats_v3"

local VERCEL_CONFIG = {
    enabled = true,
    api_url = "https://lunaris-backend-rqix.vercel.app",
    stats_endpoint = "/api/stats",
    heartbeat_endpoint = "/api/heartbeat",
    check_interval = 10,
    heartbeat_interval = 30
}

local function generate_user_id()
    local id = database.read("lunaris_user_id")
    if not id then
        id = string.format("%08x-%04x", 
            math.random(0, 0xFFFFFFFF),
            math.random(0, 0xFFFF))
        database.write("lunaris_user_id", id)
        client.log("Generated new user ID: " .. id)
    end
    return id
end

local function load_stats()
    local saved = database.read(DB_KEY)
    if saved then
        stats.data = saved
    end
    
    -- !!! : Generate ID
    stats.data.user_id = generate_user_id()
    stats.data.total_loads = (stats.data.total_loads or 0) + 1
    stats.data.session_start = globals.realtime()
    stats.data.last_seen = globals.realtime()
    
    database.write(DB_KEY, stats.data)
    client.log("Stats loaded. User ID: " .. tostring(stats.data.user_id))
    client.log("Total loads: " .. tostring(stats.data.total_loads))
end

local function save_stats()
    database.write(DB_KEY, stats.data)
end

local function update_playtime()
    if not entity.get_local_player() then return end
    
    local current_time = globals.realtime()
    stats.data.current_session = current_time - stats.data.session_start
    
    local session_secs = math.floor(stats.data.current_session)
    if session_secs % 10 == 0 and session_secs > 0 then
        stats.data.total_playtime = (stats.data.total_playtime or 0) + 10
        
        if stats.data.current_session > (stats.data.longest_session or 0) then
            stats.data.longest_session = stats.data.current_session
        end
        
        save_stats()
    end
end

local function format_time(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

local function format_date(timestamp)
    if timestamp == 0 then return "Never" end
    
    local diff = globals.realtime() - timestamp
    
    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        return string.format("%d min ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d hours ago", math.floor(diff / 3600))
    else
        return string.format("%d days ago", math.floor(diff / 86400))
    end
end

local last_heartbeat = 0

local function send_heartbeat()
    if not VERCEL_CONFIG.enabled then return end
    if not stats.data.user_id then 
        client.log("Cannot send heartbeat: user_id is nil")
        return 
    end
    
    local current_time = globals.realtime()
    
    if current_time - last_heartbeat < VERCEL_CONFIG.heartbeat_interval then
        return
    end
    
    last_heartbeat = current_time
    
    -- !!! : username - ASCII
    local username = obex_data.username or "Player"
    username = username:gsub("[^%w%-_]", "")
    if username == "" then username = "Player" end
    
    local url = string.format("%s%s?userId=%s&username=%s",
        VERCEL_CONFIG.api_url,
        VERCEL_CONFIG.heartbeat_endpoint,
        stats.data.user_id,
        username
    )
    
    client.log("Sending heartbeat for user: " .. stats.data.user_id)
    
    http.get(url, function(success, response)
        if success and response.status == 200 then
            local parse_success, data = pcall(json.parse, response.body)
            if parse_success and data and data.success then
                stats.server.online_users = tonumber(data.online_users) or stats.server.online_users
                stats.server.total_users = tonumber(data.total_users) or stats.server.total_users
                stats.server.connected = true
                client.log("Heartbeat OK. Online: " .. tostring(stats.server.online_users))
            else
                client.log("Heartbeat failed: parse error")
            end
        else
            client.log("Heartbeat failed: HTTP error")
        end
    end)
end

local last_server_check = 0

local function check_server_status()
    if not VERCEL_CONFIG.enabled then 
        stats.server.status = "Disabled"
        return 
    end
    
    local current_time = globals.realtime()
    
    if current_time - last_server_check >= VERCEL_CONFIG.check_interval then
        last_server_check = current_time
        
        local url = VERCEL_CONFIG.api_url .. VERCEL_CONFIG.stats_endpoint
        
        http.get(url, function(success, response)
            if success and response.status == 200 then
                local parse_success, data = pcall(json.parse, response.body)
                
                if parse_success and data and type(data) == "table" then
                    stats.server.status = data.status == "online" and "Connected" or "Offline"
                    stats.server.online_users = tonumber(data.online_users) or 0
                    stats.server.total_users = tonumber(data.total_users) or 0
                    stats.server.connected = true
                else
                    stats.server.status = "Parse Error"
                    stats.server.connected = false
                end
            else
                stats.server.status = "Offline"
                stats.server.connected = false
                stats.server.online_users = 0
            end
        end)
    end
    
    send_heartbeat()
end
-- #endregion : STATISTICS MODULE


-- #region : PUI MENU SETUP
local menu_groups = {
    aa = pui.group("AA", "Anti-aimbot angles"),
    flg = pui.group("AA", "Fake lag"),
    otr = pui.group("AA", "Other")
}

local menu = {}
local line = " "
-- #endregion : PUI MENU SETUP


-- #region HOME TAB
menu.home = {
    header = menu_groups.flg:label("L U N A R I S"),
    tab_selector = menu_groups.flg:combobox("Tab", {"Home", "Anti-Aim", "Visuals"}),
    spacer1 = menu_groups.flg:label(" "),
    
    _version = menu_groups.flg:label("Version: A L P H A"),
    _user = menu_groups.flg:label("User: " .. obex_data.username),
    spacer2 = menu_groups.flg:label(" "),
    
    stats_header = menu_groups.flg:label("Statistics"),
    spacer3 = menu_groups.flg:label(" "),
    
    stat_loads = menu_groups.flg:label("Loads: 0"),
    stat_playtime = menu_groups.flg:label("Total Playtime: 0h 0m"),
    stat_longest = menu_groups.flg:label("Longest Session: 0h 0m"),
    stat_current = menu_groups.flg:label("Current Session: 0m 0s"),
    stat_last_seen = menu_groups.flg:label("Last Seen: Never"),
    spacer4 = menu_groups.flg:label(" "),
    
    server_header = menu_groups.flg:label("Server Status"),
    spacer5 = menu_groups.flg:label(" "),
    
    server_status = menu_groups.flg:label("Status: Checking..."),
    server_users = menu_groups.flg:label("Online Users: 0"),
    spacer6 = menu_groups.otr:label(" "),
    
    telegram_btn = menu_groups.otr:button("Open Telegram", function()
        panorama.open().SteamOverlayAPI.OpenExternalBrowserURL("https://t.me/Lunaris_lua")
    end),
    website_btn = menu_groups.otr:button("Open WebSite", function()
        panorama.open().SteamOverlayAPI.OpenExternalBrowserURL("https://lunaris.tlfis.ru")
    end),
    reset_stats_btn = menu_groups.otr:button("Reset Statistics", function()
        stats.data = {
            total_loads = 1,
            total_playtime = 0,
            longest_session = 0,
            last_seen = globals.realtime(),
            session_start = globals.realtime(),
            current_session = 0,
            user_id = stats.data.user_id
        }
        save_stats()
        client.log("Statistics reset!")
    end)
}

local function update_stats_ui()
    menu.home.stat_loads:set("Loads: " .. (stats.data.total_loads or 0))
    menu.home.stat_playtime:set("Total Playtime: " .. format_time(stats.data.total_playtime or 0))
    menu.home.stat_longest:set("Longest Session: " .. format_time(stats.data.longest_session or 0))
    menu.home.stat_current:set("Current Session: " .. format_time(stats.data.current_session or 0))
    menu.home.stat_last_seen:set("Last Seen: " .. format_date(stats.data.last_seen or 0))
    
    local status_icon = stats.server.connected and "[+]" or "[-]"
    local status_text = status_icon .. " Status: " .. stats.server.status
    
    menu.home.server_status:set(status_text)
    menu.home.server_users:set(string.format("Online: %d | Total: %d", 
        stats.server.online_users or 0,
        stats.server.total_users or 0))
end
-- #endregion : HOME TAB


-- #region ANTI-AIM TAB
menu.antiaim = {
    subtab_selector = menu_groups.flg:combobox("Anti-Aim Subtab", {"Main Settings", "Desync", "Defensive"}),
    spacer_main = menu_groups.aa:label(line)
}

menu.antiaim.yaw_pitch = {
    header = menu_groups.aa:label("Main Settings"),
    spacer1 = menu_groups.aa:label(line),
    enable_yaw_pitch = menu_groups.aa:checkbox("Enable Main Settings"),
    spacer2 = menu_groups.aa:label(line),
    pitch_mode = menu_groups.aa:combobox("Pitch Mode", {"Off", "Default", "Up", "Down", "Minimal", "Random", "Custom"}),
    pitch_value = menu_groups.aa:slider("Pitch Value", -89, 89, 0, true, "°", 1),
    yaw_mode = menu_groups.aa:combobox("Yaw Mode", {"Off", "180", "Spin", "180 Z", "180 L/R"}),
    spacer3 = menu_groups.aa:label(line),
    yaw_base = menu_groups.aa:combobox("Yaw Base", {"Local view", "At targets"}),
    yaw_offset = menu_groups.aa:slider("Yaw Offset", -180, 180, 0, true, "°", 1),
    yaw_left = menu_groups.aa:slider("Yaw Left", -180, 180, -45, true, "°", 1),
    yaw_right = menu_groups.aa:slider("Yaw Right", -180, 180, 45, true, "°", 1),
    spacer4 = menu_groups.aa:label(line),
    yaw_jitter = menu_groups.aa:combobox("Yaw Jitter", {"Off", "Offset", "Center", "Random", "L/R"}),
    yaw_jitter_value = menu_groups.aa:slider("Jitter Value", -180, 180, 0, true, "°", 1),
    yaw_jitter_left = menu_groups.aa:slider("Jitter Left", -180, 180, -25, true, "°", 1),
    yaw_jitter_right = menu_groups.aa:slider("Jitter Right", -180, 180, 25, true, "°", 1)
}

menu.antiaim.desync = {
    header = menu_groups.aa:label("Desync Settings"),
    spacer1 = menu_groups.aa:label(line),
    enable = menu_groups.aa:checkbox("Enable Custom Desync"),
    spacer2 = menu_groups.aa:label(line),
    fake_limit = menu_groups.aa:slider("Desync Angle", -120, 120, 60, true, "°", 1),
    spacer3 = menu_groups.aa:label(line),
    lby_breaker = menu_groups.aa:checkbox("LBY Breaker"),
    extended_desync = menu_groups.aa:checkbox("Extended Desync"),
    double_desync = menu_groups.aa:checkbox("Double Desync"),
    spacer4 = menu_groups.aa:label(line),
    invert_key = menu_groups.aa:hotkey("Invert Desync")
}

menu.antiaim.defensive = {
    header = menu_groups.aa:label("Defensive Settings"),
    spacer1 = menu_groups.aa:label(line),
    defensive_aa = menu_groups.aa:checkbox("Enable Defensive Anti-Aim"),
    spacer2 = menu_groups.aa:label(line),
    defensive_pitch = menu_groups.aa:combobox("Defensive Pitch", {"Default", "Up", "Down", "Random", "Jitter"}),
    defensive_yaw = menu_groups.aa:combobox("Defensive Yaw", {"Default", "Spin", "Random", "3-Way"}),
    defensive_spin_speed = menu_groups.aa:slider("Spin Speed", 1, 100, 50, true, "%", 1)
}
-- #endregion : ANTI-AIM TAB


-- #region VISUALS TAB
menu.visuals = {
    header = menu_groups.aa:label("Visual Settings"),
    spacer1 = menu_groups.aa:label(line),
    desync_arrows = menu_groups.aa:checkbox("Desync Arrows"),
    arrow_length = menu_groups.aa:slider("Arrow Length", 10, 100, 40, true, " ", 1),
    spacer2 = menu_groups.aa:label(line),
    show_real_angle = menu_groups.aa:checkbox("Show Real Angle"),
    real_color = menu_groups.aa:color_picker("Real Color", 120, 255, 120, 255),
    spacer3 = menu_groups.aa:label(line),
    show_fake_angle = menu_groups.aa:checkbox("Show Fake Angle"),
    fake_color = menu_groups.aa:color_picker("Fake Color", 255, 120, 200, 255)
}
-- #endregion : VISUALS TAB


-- #region : MENU DEPENDENCIES
local function setup_tab_visibility()
    for key, element in pairs(menu.home) do
        if key ~= "header" and key ~= "tab_selector" then
            element:depend({menu.home.tab_selector, "Home"})
        end
    end
    
    menu.antiaim.subtab_selector:depend({menu.home.tab_selector, "Anti-Aim"})
    menu.antiaim.spacer_main:depend({menu.home.tab_selector, "Anti-Aim"})
    
    for key, element in pairs(menu.antiaim.yaw_pitch) do
        element:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"})
    end
    
    menu.antiaim.yaw_pitch.pitch_value:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.pitch_mode, "Custom"})
    menu.antiaim.yaw_pitch.yaw_base:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true})
    menu.antiaim.yaw_pitch.yaw_mode:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true})
    menu.antiaim.yaw_pitch.yaw_offset:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_mode, "180"})
    menu.antiaim.yaw_pitch.yaw_left:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_mode, "180 L/R"})
    menu.antiaim.yaw_pitch.yaw_right:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_mode, "180 L/R"})
    menu.antiaim.yaw_pitch.yaw_jitter:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true})
    menu.antiaim.yaw_pitch.yaw_jitter_value:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_jitter, "Offset"}, {menu.antiaim.yaw_pitch.yaw_jitter, "Center"}, {menu.antiaim.yaw_pitch.yaw_jitter, "Random"})
    menu.antiaim.yaw_pitch.yaw_jitter_left:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_jitter, "L/R"})
    menu.antiaim.yaw_pitch.yaw_jitter_right:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Main Settings"}, {menu.antiaim.yaw_pitch.enable_yaw_pitch, true}, {menu.antiaim.yaw_pitch.yaw_jitter, "L/R"})
    
    for key, element in pairs(menu.antiaim.desync) do
        element:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"})
    end
    
    menu.antiaim.desync.fake_limit:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.spacer3:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.lby_breaker:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.extended_desync:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.double_desync:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.spacer4:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    menu.antiaim.desync.invert_key:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Desync"}, {menu.antiaim.desync.enable, true})
    
    for key, element in pairs(menu.antiaim.defensive) do
        element:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Defensive"})
    end
    
    menu.antiaim.defensive.defensive_pitch:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Defensive"}, {menu.antiaim.defensive.defensive_aa, true})
    menu.antiaim.defensive.defensive_yaw:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Defensive"}, {menu.antiaim.defensive.defensive_aa, true})
    menu.antiaim.defensive.defensive_spin_speed:depend({menu.home.tab_selector, "Anti-Aim"}, {menu.antiaim.subtab_selector, "Defensive"}, {menu.antiaim.defensive.defensive_aa, true})
    
    for key, element in pairs(menu.visuals) do
        element:depend({menu.home.tab_selector, "Visuals"})
    end
    
    menu.visuals.arrow_length:depend({menu.home.tab_selector, "Visuals"}, {menu.visuals.desync_arrows, true})
    menu.visuals.show_real_angle:depend({menu.home.tab_selector, "Visuals"}, {menu.visuals.desync_arrows, true})
    menu.visuals.real_color:depend({menu.home.tab_selector, "Visuals"}, {menu.visuals.desync_arrows, true}, {menu.visuals.show_real_angle, true})
    menu.visuals.show_fake_angle:depend({menu.home.tab_selector, "Visuals"}, {menu.visuals.desync_arrows, true})
    menu.visuals.fake_color:depend({menu.home.tab_selector, "Visuals"}, {menu.visuals.desync_arrows, true}, {menu.visuals.show_fake_angle, true})
end

setup_tab_visibility()
-- #endregion : MENU DEPENDENCIES


-- #region : REFERENCES
local refs = {
    bodyYaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
    flLimit = ui.reference("AA", "Fake lag", "Limit"),
    dt = { ui.reference("RAGE", "Aimbot", "Double tap") },
    os = { ui.reference("AA", "Other", "On shot anti-aim") },
    fakeDuck = ui.reference("RAGE", "Other", "Duck peek assist")
}
-- #endregion : REFERENCES


-- #region : VARIABLES
local vars = {
    yaw = 0,
    choked = 0,
    dt_state = false,
    doubletap_time = 0,
    m1_time = 0,
    last_lby = nil,
    key_was_down = false,
    dd_use_first = true,
    dd_yaw_a = 0,
    dd_yaw_b = 0
}
-- #endregion : VARIABLES


-- #region : FFI
local angle3d_struct = ffi.typeof("struct { float pitch; float yaw; float roll; }")
local vec_struct = ffi.typeof("struct { float x; float y; float z; }")
local cUserCmd = ffi.typeof([[
    struct {
        uintptr_t vfptr;
        int command_number;
        int tick_count;
        $ viewangles;
        $ aimdirection;
        float forwardmove;
        float sidemove;
        float upmove;
        int buttons;
        uint8_t impulse;
        int weaponselect;
        int weaponsubtype;
        int random_seed;
        short mousedx;
        short mousedy;
        bool hasbeenpredicted;
        $ headangles;
        $ headoffset;
        bool send_packet;
    }
]], angle3d_struct, vec_struct, angle3d_struct, vec_struct)

local client_sig = client.find_signature("client.dll", "\xB9\xCC\xCC\xCC\xCC\x8B\x40\x38\xFF\xD0\x84\xC0\x0F\x85") or error("client.dll!:input not found.")
local get_cUserCmd = ffi.typeof("$* (__thiscall*)(uintptr_t ecx, int nSlot, int sequence_number)", cUserCmd)
local input_vtbl = ffi.typeof([[struct { uintptr_t padding[8]; $ GetUserCmd; }]], get_cUserCmd)
local input = ffi.typeof([[struct { $* vfptr; }*]], input_vtbl)
local get_input = ffi.cast(input, ffi.cast("uintptr_t**", tonumber(ffi.cast("uintptr_t", client_sig)) + 1)[0])
-- #endregion : FFI


-- #region : CORE FUNCTIONS
local function get_velocity(player)
    local x, y, z = entity.get_prop(player, "m_vecVelocity")
    if not x then return 0 end
    return math.sqrt(x * x + y * y + z * z)
end

local function can_desync(cmd)
    local local_player = entity.get_local_player()
    if not local_player or entity.get_prop(local_player, "m_MoveType") == 9 then
        return false
    end
    
    local weapon = entity.get_player_weapon(local_player)
    if not weapon then return false end
    
    local weapon_classname = entity.get_classname(weapon)
    local in_attack = cmd.in_attack == 1
    local in_use = cmd.in_use == 1
    
    if in_use then return false end
    
    if in_attack and weapon_classname:find("Grenade") then
        vars.m1_time = globals.curtime() + 0.15
    end
    
    if vars.m1_time > globals.curtime() then return false end
    if in_attack then return false end
    
    return true
end

local function get_choke(cmd)
    local fl_limit = ui.get(refs.flLimit)
    local fl_p = fl_limit % 2 == 1
    local chokedcommands = cmd.chokedcommands
    local cmd_p = chokedcommands % 2 == 0
    local doubletap_ref = ui.get(refs.dt[1]) and ui.get(refs.dt[2])
    local osaa_ref = ui.get(refs.os[1]) and ui.get(refs.os[2])
    local fd_ref = ui.get(refs.fakeDuck)
    
    if doubletap_ref then
        if vars.choked > 2 then
            if cmd.chokedcommands >= 0 then
                cmd_p = false
            end
        end
    end
    
    vars.choked = cmd.chokedcommands
    
    if vars.dt_state ~= doubletap_ref then
        vars.doubletap_time = globals.curtime() + 0.25
    end
    
    if (not doubletap_ref and not osaa_ref and not cmd.no_choke) or fd_ref then
        if not fl_p then
            if vars.doubletap_time > globals.curtime() then
                if cmd.chokedcommands >= 0 and cmd.chokedcommands < fl_limit then
                    cmd_p = chokedcommands % 2 == 0
                else
                    cmd_p = chokedcommands % 2 == 1
                end
            else
                cmd_p = chokedcommands % 2 == 1
            end
        end
    end
    
    vars.dt_state = doubletap_ref
    return cmd_p
end

local function is_moving()
    local local_player = entity.get_local_player()
    if not local_player then return false end
    return get_velocity(local_player) > 1.0
end

local function get_lby()
    local local_player = entity.get_local_player()
    if not local_player then return 0 end
    return entity.get_prop(local_player, "m_flLowerBodyYawTarget") or 0
end

local function apply_yaw_pitch(cmd)
    local pitch_mode = menu.antiaim.yaw_pitch.pitch_mode:get()
    local yaw_mode = menu.antiaim.yaw_pitch.yaw_mode:get()
    local yaw_base = menu.antiaim.yaw_pitch.yaw_base:get()
    local yaw_offset = menu.antiaim.yaw_pitch.yaw_offset:get()
    local yaw_left = menu.antiaim.yaw_pitch.yaw_left:get()
    local yaw_right = menu.antiaim.yaw_pitch.yaw_right:get()
    local yaw_jitter = menu.antiaim.yaw_pitch.yaw_jitter:get()
    local yaw_jitter_value = menu.antiaim.yaw_pitch.yaw_jitter_value:get()
    local yaw_jitter_left = menu.antiaim.yaw_pitch.yaw_jitter_left:get()
    local yaw_jitter_right = menu.antiaim.yaw_pitch.yaw_jitter_right:get()
    
    local local_player = entity.get_local_player()
    if not local_player then return end
    
    local bodyYaw = entity.get_prop(local_player, "m_flPoseParameter", 11) * 120 - 60
    local side = bodyYaw > 0 and 1 or -1
    
    if pitch_mode ~= "Off" then
        if pitch_mode == "Custom" then
            ui.set(original_refs.pitch[1], "Custom")
            ui.set(original_refs.pitch[2], menu.antiaim.yaw_pitch.pitch_value:get())
        else
            ui.set(original_refs.pitch[1], pitch_mode)
        end
    else
        ui.set(original_refs.pitch[1], "Off")
    end
    
    ui.set(original_refs.yaw_base, yaw_base)
    
    if yaw_mode == "Off" then
        ui.set(original_refs.yaw[1], "Off")
        ui.set(original_refs.yaw[2], 0)
    elseif yaw_mode == "180" then
        ui.set(original_refs.yaw[1], "180")
        ui.set(original_refs.yaw[2], yaw_offset)
    elseif yaw_mode == "Spin" then
        ui.set(original_refs.yaw[1], "Spin")
        ui.set(original_refs.yaw[2], 0)
    elseif yaw_mode == "180 Z" then
        ui.set(original_refs.yaw[1], "180 Z")
        ui.set(original_refs.yaw[2], 0)
    elseif yaw_mode == "180 L/R" then
        ui.set(original_refs.yaw[1], "180")
        ui.set(original_refs.yaw[2], side == 1 and yaw_left or yaw_right)
    end
    
    if yaw_jitter == "Off" then
        ui.set(original_refs.yaw_jitter[1], "Off")
        ui.set(original_refs.yaw_jitter[2], 0)
    elseif yaw_jitter == "Offset" then
        ui.set(original_refs.yaw_jitter[1], "Offset")
        ui.set(original_refs.yaw_jitter[2], yaw_jitter_value)
    elseif yaw_jitter == "Center" then
        ui.set(original_refs.yaw_jitter[1], "Center")
        ui.set(original_refs.yaw_jitter[2], yaw_jitter_value)
    elseif yaw_jitter == "Random" then
        ui.set(original_refs.yaw_jitter[1], "Random")
        ui.set(original_refs.yaw_jitter[2], yaw_jitter_value)
    elseif yaw_jitter == "L/R" then
        ui.set(original_refs.yaw_jitter[1], "Center")
        ui.set(original_refs.yaw_jitter[2], side == 1 and yaw_jitter_left or yaw_jitter_right)
    end
end

local function apply_desync(cmd, fake_limit)
    local success, usrcmd = pcall(function()
        return get_input.vfptr.GetUserCmd(ffi.cast("uintptr_t", get_input), 0, cmd.command_number)
    end)
    
    if not success or not usrcmd then return end
    
    cmd.allow_send_packet = false
    local _, yaw = client.camera_angles()
    local can_apply = can_desync(cmd)
    local is_choke = get_choke(cmd)
    
    ui.set(refs.bodyYaw[1], is_choke and "Static" or "Off")
    
    local lby_enabled = menu.antiaim.desync.lby_breaker:get()
    local double_enabled = menu.antiaim.desync.double_desync:get()
    
    local currently_moving = is_moving()
    local current_lby = get_lby()
    local lby_updated = false
    
    if not currently_moving and vars.last_lby ~= nil and vars.last_lby ~= current_lby then
        lby_updated = true
    end
    
    vars.last_lby = current_lby
    local defensive_forced = cmd.force_defensive == true
    
    if cmd.chokedcommands == 0 then
        if lby_enabled and lby_updated then
            vars.yaw = current_lby + math.random(80, 100)
            vars.dd_yaw_a = vars.yaw
            vars.dd_yaw_b = vars.yaw
        else
            local base_offset = fake_limit
            vars.dd_yaw_a = (yaw + 180) - base_offset
            vars.dd_yaw_b = (yaw + 180) + base_offset
            
            if double_enabled then
                local dt_on = ui.get(refs.dt[1]) and ui.get(refs.dt[2])
                if defensive_forced or dt_on then
                    vars.dd_use_first = not vars.dd_use_first
                else
                    if math.random(0, 10) < 3 then
                        vars.dd_use_first = not vars.dd_use_first
                    end
                end
                vars.yaw = vars.dd_use_first and vars.dd_yaw_a or vars.dd_yaw_b
            else
                vars.yaw = vars.dd_yaw_a
            end
        end
    end
    
    if can_apply then
        if not usrcmd.hasbeenpredicted then
            if is_choke then
                cmd.yaw = vars.yaw
            end
        end
    end
    
    if menu.antiaim.desync.extended_desync:get() and can_apply then
        local local_player = entity.get_local_player()
        if local_player then
            local pose_value = (math.abs(fake_limit) / 150.0)
            entity.set_prop(local_player, "m_flPoseParameter", pose_value, 0)
        end
    end
end

local function draw_desync_arrows()
    if not menu.visuals.desync_arrows:get() then return end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end
    
    local origin_x, origin_y, origin_z = entity.get_prop(local_player, "m_vecOrigin")
    if not origin_x then return end
    
    local pitch, real_yaw = client.camera_angles()
    local fake_yaw = vars.yaw
    local arrow_length = menu.visuals.arrow_length:get()
    
    local function draw_arrow(yaw_angle, r, g, b, a)
        local yaw_rad = math.rad(yaw_angle)
        local end_x = origin_x + math.cos(yaw_rad) * arrow_length
        local end_y = origin_y + math.sin(yaw_rad) * arrow_length
        
        local start_screen_x, start_screen_y = renderer.world_to_screen(origin_x, origin_y, origin_z)
        local end_screen_x, end_screen_y = renderer.world_to_screen(end_x, end_y, origin_z)
        
        if not start_screen_x or not end_screen_x then return end
        
        renderer.line(start_screen_x, start_screen_y, end_screen_x, end_screen_y, r, g, b, a)
        
        local arrow_size = 8
        local arrow_angle = 30
        
        local left_angle = yaw_rad + math.rad(180 - arrow_angle)
        local left_x = end_x + math.cos(left_angle) * arrow_size
        local left_y = end_y + math.sin(left_angle) * arrow_size
        local left_screen_x, left_screen_y = renderer.world_to_screen(left_x, left_y, origin_z)
        
        local right_angle = yaw_rad + math.rad(180 + arrow_angle)
        local right_x = end_x + math.cos(right_angle) * arrow_size
        local right_y = end_y + math.sin(right_angle) * arrow_size
        local right_screen_x, right_screen_y = renderer.world_to_screen(right_x, right_y, origin_z)
        
        if left_screen_x and right_screen_x then
            renderer.line(end_screen_x, end_screen_y, left_screen_x, left_screen_y, r, g, b, a)
            renderer.line(end_screen_x, end_screen_y, right_screen_x, right_screen_y, r, g, b, a)
        end
    end
    
    if menu.visuals.show_real_angle:get() then
        local r, g, b, a = menu.visuals.real_color:get()
        draw_arrow(real_yaw, r, g, b, a)
    end
    
    if menu.visuals.show_fake_angle:get() and menu.antiaim.desync.enable:get() then
        local r, g, b, a = menu.visuals.fake_color:get()
        draw_arrow(fake_yaw, r, g, b, a)
    end
end
-- #endregion : CORE FUNCTIONS


-- #region : CALLBACKS
client.set_event_callback("setup_command", function(cmd)
    if not entity.is_alive(entity.get_local_player()) then return end
    
    if menu.antiaim.yaw_pitch.enable_yaw_pitch:get() then
        apply_yaw_pitch(cmd)
    end
    
    if menu.antiaim.desync.enable:get() then
        local limit = menu.antiaim.desync.fake_limit:get()
        apply_desync(cmd, limit)
    end
end)

client.set_event_callback("paint", function()
    update_playtime()
    check_server_status()
    update_stats_ui()
    
    if menu.antiaim.desync.enable:get() then
        local is_key_down = menu.antiaim.desync.invert_key:get()
        
        if is_key_down and not vars.key_was_down then
            local current_value = menu.antiaim.desync.fake_limit:get()
            menu.antiaim.desync.fake_limit:set(-current_value)
        end
        
        vars.key_was_down = is_key_down
    end
    
    draw_desync_arrows()
end)

client.set_event_callback("paint_ui", function()
    local time = globals.realtime()
    local text = "L U N A R I S"
    local result = ""
    
    local speed = 2.5
    local spread = 0.5
    
    for i = 1, #text do
        local char = text:sub(i, i)
        
        if char == " " then
            result = result .. " "
        else
            local wave = math.sin((time * speed) + (i * spread))
            local intensity = (wave + 1) / 2
            
            local r_min, r_max = 170, 230
            local g_min, g_max = 167, 227
            local b = 255
            
            local r = math.floor(r_min + (r_max - r_min) * intensity)
            local g = math.floor(g_min + (g_max - g_min) * intensity)
            
            local color_hex = string.format("%02X%02X%02XFF", r, g, b)
            result = result .. string.format("\a%s%s", color_hex, char)
        end
    end
    
    menu.home.header:set(result)
    hide_original_menu(false)
end)

client.set_event_callback("shutdown", function()
    stats.data.total_playtime = (stats.data.total_playtime or 0) + stats.data.current_session
    if stats.data.current_session > (stats.data.longest_session or 0) then
        stats.data.longest_session = stats.data.current_session
    end
    save_stats()
    
    hide_original_menu(true)
end)

client.set_event_callback("client_disconnect", function()
    vars.yaw = 0
    vars.choked = 0
    vars.dt_state = false
    vars.doubletap_time = 0
    vars.m1_time = 0
    vars.last_lby = nil
    vars.key_was_down = false
    vars.dd_use_first = true
    vars.dd_yaw_a = 0
    vars.dd_yaw_b = 0
end)

hide_original_menu(false)
client.delay_call(0.1, function()
    load_stats()
    check_server_status()
end)

client.log("Lunaris loaded successfully!")
-- #endregion : CALLBACKS

