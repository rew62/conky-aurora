#!/usr/bin/lua
-- weather.lua - A lua based weather script using openweathermap 2.5 API.
-- v4.1 2026-02-01 @rew62 | Online Meteocons -> Local Dovora Fallback

local http = require("socket.http")
local json = require("cjson")

-- 1. CONFIGURATION
local api_url = "http://api.openweathermap.org/data/2.5/weather?"
local cf = "imperial"
local USE_ONLINE = true  -- Set to false to use local SagiSan/Dovora icons

-- 2. LOAD ENVIRONMENT
local _h = io.popen("readlink -f '" .. debug.getinfo(1,"S").source:sub(2) .. "' | xargs dirname | xargs dirname | xargs dirname")
local REPO_DIR = _h:read("*l") .. "/"
_h:close()
local env_path = REPO_DIR .. ".env"
local f = loadfile(env_path)
if f then pcall(f) end
if cf ~= "metric" and cf ~= "imperial" then cf = "imperial" end

-- 3. PATHS & CACHE
local icon_path = REPO_DIR .. "weather-icons/"
local icon_family = "SagiSan" -- Change this to "dovora" or "modern" as needed
local icon_theme = "dark"
local cache_path = "/dev/shm/"
local cache_file = cache_path .. "weather.json"
local scrape_cache = "/dev/shm/nws_data.txt"

-- 4. MAPPINGS
local uni_icons = { ["01"]="☀", ["02"]="🌤", ["03"]="🌥", ["04"]="☁", ["09"]="🌧", ["10"]="🌦", ["11"]="🌩", ["13"]="🌨", ["50"]="🌫" }

local meteo_map = {
    [200]="thunderstorms-rain", [201]="thunderstorms-rain", [202]="thunderstorms-rain",
    [300]="drizzle", [500]="rain", [501]="rain", [600]="snow", [701]="mist",
    [800]="clear", [801]="cloudy", [802]="cloudy", [803]="overcast", [804]="overcast"
}

-- 5. HELPERS
local function math_round(n) return math.floor(n + 0.5) end

local function degrees_to_direction(d)
    local directions = {[0]="N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"}
    return directions[math.floor(d/22.5 + 0.5) % 16]
end

local function format_time_portable(timestamp)
    local h = os.date("%I", timestamp):gsub("^0", "")
    return h .. ":" .. os.date("%M", timestamp) .. string.lower(os.date("%p", timestamp):sub(1,1))
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

-- SVG GENERATORS
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

-- 6. DATA FETCHING
local data
local f_cache = io.open(cache_file, "r")
if f_cache then
    local content = f_cache:read("*all")
    f_cache:close()
    pcall(function() data = json.decode(content) end)
end

local currenttime = os.time()
if (not data) or (os.difftime(currenttime, data.timestamp or 0) >= 300) then
    local url = ("%sid=%s&units=%s&APPID=%s"):format(api_url, cityid, cf, apikey)
    local response, code = http.request(url)
    if response and code == 200 then
        data = json.decode(response)
        data.timestamp = currenttime
        
        -- Save JSON cache
        local w_cache = io.open(cache_file, "w+")
        if w_cache then w_cache:write(json.encode(data)) w_cache:close() end
        
        -- Clean old SVGs and create new wind arrows
        os.execute("rm " .. cache_path .. "wind_*.svg 2>/dev/null")
        create_arrows(data.wind.deg, data.wind.speed, data.timestamp)
    end
end

if not data then io.write("${color red}Weather data unavailable.") return end

-- 7. ICON LOGIC
local final_icon = nil
local icon_code = data.weather[1].icon 
local icon_id = data.weather[1].id

if USE_ONLINE == true then
    local dn = icon_code:sub(-1) == "d" and "day" or "night"
    local mapping = meteo_map[icon_id] or "cloudy"
    local name_svg = mapping .. "-" .. dn .. ".svg"
    
    local url = "https://raw.githubusercontent.com/basmilius/weather-icons/dev/production/fill/svg/" .. name_svg
    local online_file = cache_path .. "weather_current.svg"
    
    os.execute("wget -q -U 'Mozilla/5.0' --timeout=5 '" .. url .. "' -O " .. online_file)
    
    local f = io.open(online_file, "r")
    if f then
        if f:seek("end") > 0 then final_icon = online_file end
        f:close()
    end
end

if not final_icon then
    final_icon = icon_path .. icon_theme .. "/" .. icon_family .. "/" .. icon_code .. ".png"
end

-- 8. SCRAPE LOGIC
local nws_high, nws_low
local f_nws = io.open(scrape_cache, "r")
if f_nws then
    nws_high = f_nws:read("*l")
    nws_low  = f_nws:read("*l")
    f_nws:close()
end

-- 9. WIND ARROW POSITIONING
local cardinal, arrow = cardinal_direction(data.wind.deg)
local clean_ts = string.format("%.0f", data.timestamp)
local wind_str = (degrees_to_direction(data.wind.deg)) .. " | " .. (math_round(data.wind.deg)) .. "°"
local text_width = #wind_str * 7
local dynamic_x = 32 + text_width

-- 10. VARIABLES TABLE
local vars = {
    weather_icon = final_icon,
    uni_char     = uni_icons[icon_code:sub(1, 2)] or "✨",
    temp         = math_round(data.main.temp),
    temp_max     = nws_high or math_round(data.main.temp_max),
    temp_min     = nws_low  or math_round(data.main.temp_min),
    humidity     = math_round(data.main.humidity),
    pressure     = math_round(data.main.pressure),
    measure      = '°' .. (cf == 'metric' and 'C' or 'F'),
    conditions   = data.weather[1].description,
    wind         = math_round(data.wind.speed),
    wind_units   = (cf == 'metric' and 'kph' or 'mph'),
    deg          = degrees_to_direction(data.wind.deg),
    deg2         = math_round(data.wind.deg),
    arrow        = arrow,
    arrow_dynamic = cache_path .. "wind_dynamic_" .. clean_ts .. ".svg",
    arrow_x      = math.floor(dynamic_x),
    sunrise      = format_time_portable(data.sys.sunrise),
    sunset       = format_time_portable(data.sys.sunset),
    location     = data.name,
    updated      = os.date("%H:%M", data.timestamp)
}

-- 11. TEMPLATE (restored with wind arrow image)
local conky_text = [[
${voffset 20}${goto 85}${font7}${color1}$(location)${color4}
${image $(weather_icon) -p 150,28 -s 60x60}
${voffset -1}${goto 7}${font :size=9}${uppercase ${time %a  %d  %b  |  %Y}}$alignr${time | d: %-j | w: %-U}
${voffset 2}${goto 7}${font :size=10}$(temp)$(measure)  |$alignc  $(conditions) $alignr | $(temp_max)/$(temp_min)
${voffset 1}${goto 7}${font Hack Nerd Font:size=12}${color1}${color4}${font :size=10}    $(humidity)%      |  ${font Hack Nerd Font:size=12}${color1}  ${color4}${font :size=10}  $(pressure)$alignr${font Symbola:size=11}$(uni_char)
${voffset -5}${font Noto Serif Tibetan:size=12:bold}${color1}༄${color4}${font :size=10}  $(deg)  |  $(deg2)°  |  $(wind) $(wind_units)${image $(arrow_dynamic) -p 170, 142 -s 32x32}
${voffset -1}${goto 7}${font Hack Nerd Font:size=18}${color1}󰖜${color4}${font :size=10}${voffset -1}     $(sunrise)${goto 90}${voffset -6}${font Hack Nerd Font:size=18}${color1}󰖛${voffset -4}${color4}${font :size=10}     $(sunset)$alignr${font DejaVu Sans:size=8}${color4}$(updated)
]]

io.write((conky_text:gsub("%$%(([%w_]+)%)", function(n) return tostring(vars[n] or n) end)))
