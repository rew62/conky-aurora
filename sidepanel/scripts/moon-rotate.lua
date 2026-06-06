#!/usr/bin/env lua

-- Derive repo root from this script's absolute path (works regardless of cwd or repo name)
local _h = io.popen("readlink -f '" .. debug.getinfo(1,"S").source:sub(2) .. "' | xargs dirname | xargs dirname | xargs dirname")
local REPO_DIR = _h:read("*l") .. "/"
_h:close()
local env_path = REPO_DIR .. ".env"
local f = loadfile(env_path)
if f then pcall(f) end

-- Your location from .env file
local LATITUDE = tonumber(lat) or 40.7128  -- fallback to NYC if not set
local LONGITUDE = tonumber(lon) or -74.0060

-- Check if input image exists
local input_image = "/dev/shm/moon.png"
--local input_image = "/dev/shm/moon2.png"
local file = io.open(input_image, "r")
if not file then
    print("Moon image not found at " .. input_image)
    print("Please run the moon update script first.")
    os.exit(0)
end
file:close()

-- Helper function to get current Julian Date
function get_julian_date()
    local time = os.time()
    local date = os.date("!*t", time)
    local a = math.floor((14 - date.month) / 12)
    local y = date.year + 4800 - a
    local m = date.month + 12 * a - 3
    
    local jdn = date.day + math.floor((153 * m + 2) / 5) + 365 * y + 
                math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) - 32045
    
    local jd = jdn + (date.hour - 12) / 24 + date.min / 1440 + date.sec / 86400
    return jd
end

-- Calculate moon's rotation angle for local viewing
function calculate_moon_rotation(lat, lon)
    local jd = get_julian_date()
    local d = jd - 2451545.0
    
    -- Moon's mean elements
    local L_moon = 218.316 + 13.176396 * d
    local M_moon = 134.963 + 13.064993 * d
    local F = 93.272 + 13.229350 * d
    
    -- Moon's ecliptic longitude
    local lambda_moon = L_moon + 6.289 * math.sin(math.rad(M_moon))
    
    -- Moon's ecliptic latitude
    local beta_moon = 5.128 * math.sin(math.rad(F))
    
    -- Obliquity of ecliptic
    local epsilon = 23.439 - 0.0000004 * d
    
    -- Convert to equatorial coordinates
    local lambda_m_rad = math.rad(lambda_moon)
    local beta_m_rad = math.rad(beta_moon)
    local eps_rad = math.rad(epsilon)
    
    local alpha_moon = math.deg(math.atan2(
        math.sin(lambda_m_rad) * math.cos(eps_rad) - math.tan(beta_m_rad) * math.sin(eps_rad),
        math.cos(lambda_m_rad)
    ))
    if alpha_moon < 0 then alpha_moon = alpha_moon + 360 end
    
    local delta_moon = math.deg(math.asin(
        math.sin(beta_m_rad) * math.cos(eps_rad) + 
        math.cos(beta_m_rad) * math.sin(eps_rad) * math.sin(lambda_m_rad)
    ))
    
    -- Calculate Local Sidereal Time
    local gmst = 280.46061837 + 360.98564736629 * d
    gmst = gmst % 360
    local lst = (gmst + lon) % 360
    
    -- Hour angle
    local H = (lst - alpha_moon)
    if H < -180 then H = H + 360 end
    if H > 180 then H = H - 360 end
    
    -- Calculate parallactic angle (position angle)
    local H_rad = math.rad(H)
    local lat_rad = math.rad(lat)
    local dec_rad = math.rad(delta_moon)
    
    local rotation = math.deg(math.atan2(
        math.sin(H_rad),
        math.tan(lat_rad) * math.cos(dec_rad) - math.sin(dec_rad) * math.cos(H_rad)
    ))
    
    return rotation
end

-- Main script
local rotation = calculate_moon_rotation(LATITUDE, LONGITUDE)

-- Use ImageMagick to rotate the image
local output_image = "/dev/shm/moon_rotated.png"

local cmd = string.format("convert '%s' -background none -rotate %.2f '%s'", 
                         input_image, rotation, output_image)

os.execute(cmd)
