#!/usr/bin/lua
-- weather.lua - A lua based weather script using openweathermap 2.5 API Obtain a key at http://openweathermap.org
-- v3 2026-01-11 @rew62

local http = require("socket.http")
local json = require("cjson")

-- CONFIGURATION
local api_url = "http://api.openweathermap.org/data/2.5/weather?"
local cf = "imperial"

-- Load Environment
local env_path = os.getenv("HOME") .. "/.conky/rew62/.env"
local f = loadfile(env_path) 
if f then f() else print(".env error") end

-- PATHS
local icon_path = os.getenv("HOME").."/.conky/rew62/weather-icons/"
local icon_family = "dovora"
local icon_theme = "light"

local cache_path = "/dev/shm/"
local cache_file = cache_path .. "weather.json"
local scrape_cache = "/dev/shm/nws_data.txt"

-- SETTINGS
local measure = '°' .. (cf == 'metric' and 'C' or 'F')
local wind_units = (cf == 'metric' and 'kph' or 'mph')
local currenttime = os.time()

-- UNICODE ICONS
local uni_icons = {
    ["01"] = "☀", ["02"] = "🌤", ["03"] = "🌥", ["04"] = "☁",
    ["09"] = "🌧", ["10"] = "🌦", ["11"] = "🌩", ["13"] = "🌨", ["50"] = "🌫",
}

--- HELPER FUNCTIONS ---

local function math_round(n) return math.floor(n + 0.5) end

local function degrees_to_direction(d)
    local val = math.floor(d/22.5 + 0.5)
    local directions = {[0]="N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"}
    return directions[val % 16]
end

local function format_time_portable(timestamp)
    local hour_12h = os.date("%I", timestamp)
    if string.sub(hour_12h, 1, 1) == "0" then hour_12h = string.sub(hour_12h, 2) end
    local minute = os.date("%M", timestamp)
    local am_pm_char = string.lower(os.date("%p", timestamp):sub(1,1))
    return hour_12h .. ":" .. minute .. am_pm_char
end

local function cardinal_direction(deg)
    local directions = {
        {337.5, "N", "↓"}, {22.5, "NE", "↙"}, {67.5, "E", "←"}, 
        {112.5, "SE", "↖"}, {157.5, "S", "↑"}, {202.5, "SW", "↗"}, 
        {247.5, "W", "→"}, {292.5, "NW", "↘"}
    }
    for i = #directions, 1, -1 do
        if deg >= directions[i][1] then return directions[i][2], directions[i][3] end
    end
    return "N", "↓"
end

-- SVG GENERATORS (Now strictly called once every 5 mins)
local function save_svg(filename, content)
    local file = io.open(filename, "w")
    if file then file:write(content) file:close() end
end

local function create_arrows(deg, speed, ts)
    local clean_ts = string.format("%.0f", ts)
    local arrow_deg = (deg + 180) % 360 
    
    -- 1. THICKNESS: Base 1.0, grows 1px per 3mph to reach ~11px at 30mph
    local thick = 1.0 + (speed / 3)
    if thick > 12 then thick = 12 end

    -- 2. COLOR SHIFT
    local fill_color = "white"
    if speed >= 40 then
        fill_color = "#ff0000" -- Red for Dangerous
    elseif speed >= 15 then
        fill_color = "#ffff00" -- Yellow for Caution
    end

    local svg3 = string.format([[<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg"> <defs><filter id="shadow"><feDropShadow dx="0" dy="1" stdDeviation="1" flood-opacity="0.5"/></filter></defs> <g transform="translate(24,24) rotate(%f)" filter="url(#shadow)"> <line x1="0" y1="12" x2="0" y2="-5" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/> <polygon points="0,-18 -12,-5 12,-5" fill="%s"/> </g> </svg>]], arrow_deg, fill_color, thick, fill_color)

    save_svg(cache_path .. "wind_dynamic_" .. clean_ts .. ".svg", svg3)
end

--- DATA PROCESSING ---

local data
local f_cache = io.open(cache_file, "r")
if f_cache then
    local content = f_cache:read("*all")
    f_cache:close()
    local ok, decoded = pcall(json.decode, content)
    if ok then data = decoded end
end

local timepassed = data and os.difftime(currenttime, data.timestamp or 0) or 9999

-- FETCH DATA BLOCK
if timepassed >= 300 then
    local url = ("%sid=%s&units=%s&APPID=%s"):format(api_url, cityid, cf, apikey)
    local response, code = http.request(url)
    
    if response and code == 200 then
        local new_fetch = json.decode(response)
        if new_fetch and new_fetch.cod == 200 then
            data = new_fetch
            data.timestamp = currenttime
            
            -- Save JSON
            local w_cache = io.open(cache_file, "w+")
            if w_cache then w_cache:write(json.encode(data)) w_cache:close() end

            -- Clean old SVGs and Create new ones
            os.execute("rm " .. cache_path .. "wind_*.svg 2>/dev/null")
            -- create_arrows(data.wind.deg, data.timestamp)
            create_arrows(data.wind.deg, data.wind.speed, data.timestamp)
        end
    end
end


if not data then
    io.write("${color red}Weather data unavailable.")
    return
end

-- Final Variables
local cardinal, arrow = cardinal_direction(data.wind.deg)
local uni_id = data.weather[1].icon:sub(1, 2)
local uni_char = uni_icons[uni_id] or "✨"

local clean_ts = string.format("%.0f", data.timestamp)

local nws_high, nws_low
local f_nws = io.open(scrape_cache, "r")
if f_nws then
    nws_high = f_nws:read("*l") -- Line 1
    nws_low  = f_nws:read("*l") -- Line 2
    f_nws:close()
end

local wind_str = (degrees_to_direction(data.wind.deg)) .. " | " .. (math_round(data.wind.deg)) .. "°"
local text_width = #wind_str * 7 -- 7 is usually safer for variable-width fonts
local dynamic_x = 32 + text_width -- '22' is your starting goto/margin

-- VARIABLE MAPPING
local vars = {
    icon         = data.weather[1].icon,
    uni_char     = uni_char,
    temp         = math_round(data.main.temp),
    temp_max     = nws_high or math_round(data.main.temp_max),
    temp_min     = nws_low  or math_round(data.main.temp_min),
    humidity     = math_round(data.main.humidity),
    pressure     = math_round(data.main.pressure),
    measure      = measure,
    conditions   = data.weather[1].description,
    wind         = math_round(data.wind.speed),
    wind_units   = wind_units,
    deg          = degrees_to_direction(data.wind.deg),
    deg2         = math_round(data.wind.deg),
    arrow        = arrow,
    arrow_plain   = cache_path .. "wind_plain_" .. clean_ts .. ".svg",
    arrow_circle  = cache_path .. "wind_circle_" .. clean_ts .. ".svg",
    arrow_dynamic = cache_path .. "wind_dynamic_" .. clean_ts .. ".svg",
    arrow_x      = math.floor(dynamic_x),
    sunrise      = format_time_portable(data.sys.sunrise),
    sunset       = format_time_portable(data.sys.sunset),
    location     = data.name,
    updated      = os.date("%H:%M", data.timestamp)
}

-- TEMPLATE
local conky_text = [[
${voffset 20}${goto 85}${font7}${color1}$(location)${color4}
${image ]] .. icon_path .. icon_theme .. "/" .. icon_family .. [[/$(icon).png -p 150,28 -s 50x50}
${voffset -1}${goto 7}${font :size=9}${uppercase ${time %a  %d  %b  |  %Y}}$alignr${time | d: %-j | w: %-U}
${voffset 2}${goto 7}${font :size=10}$(temp)$(measure)  |$alignc  $(conditions) $alignr | $(temp_max)/$(temp_min)
${voffset 1}${goto 7}${font Hack Nerd Font:size=12}${color1}${color4}${font :size=10}    $(humidity)%      |  ${font Hack Nerd Font:size=12}${color1}  ${color4}${font :size=10}  $(pressure)$alignr${font Symbola:size=11}$(uni_char)
${voffset -5}${font Noto Serif Tibetan:size=12:bold}${color1}༄${color4}${font :size=10}  $(deg)  |  $(deg2)°  |  $(wind) $(wind_units)${image $(arrow_dynamic) -p 168, 142 -s 32x32}
${voffset -1}${goto 7}${font Hack Nerd Font:size=18}${color1}󰖜${color4}${font :size=10}${voffset -1}     $(sunrise)${goto 90}${voffset -6}${font Hack Nerd Font:size=18}${color1}󰖛${voffset -4}${color4}${font :size=10}     $(sunset)$alignr${font DejaVu Sans:size=8}${color4}$(updated)
]]


local output = conky_text:gsub("%$%(([%w_]+)%)", function(name)
    return tostring(vars[name] or ("MISSING:" .. name))
end)

io.write(output)
