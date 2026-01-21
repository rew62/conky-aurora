#!/usr/bin/env lua
-- rcal.lua - A lua calendar
-- v1.4 01 @rew62

-- Colors (Change these to match your Conky config colors)
local color_main  = "${font :size=12}${color5}%s${color}${font}"  -- Month and Year
local color_today = "${color5}%s${color}"  -- Today's Weekday and Date

local t = os.date('*t', os.time())

local year, month, currentday, wday = t.year, t.month, t.day, t.wday
-- DEBUG: Set a specific date for testing
--local debug_date = os.date('*t', os.time{year=2026, month=2, day=15})
--local year, month, currentday, wday = debug_date.year, debug_date.month, debug_date.day, debug_date.wday

-- 1. Format and Color the Month and Year
-- local month_name = os.date("%B")
-- DEBUG: Set use debug date for Month Title
local month_name = os.date("%B", os.time{year=year, month=month, day=1})


local colored_title_text = color_main:format(month_name .. " " .. year)

-- 2. Color the Weekday Name
local week_headers = {"Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"}
local colored_week_parts = {}
for i, h in ipairs(week_headers) do
    local formatted_h = string.format("%3s", h)
    if i == wday then
        table.insert(colored_week_parts, color_today:format(formatted_h))
    else
        table.insert(colored_week_parts, formatted_h)
    end
end
local colored_week_string = table.concat(colored_week_parts, "")

-- Date Logic
local daystart = os.date("*t",os.time{year=year,month=month,day=01}).wday
local days_in_month = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

local function LeapYear(y)
    return y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
end

if LeapYear(year) then days_in_month[2] = 29 end
local days = days_in_month[month]

-- Calculate centering based on raw text length
local title_start = math.floor((21 - (string.len(month_name) + 5)) / 2 + 0.5) + 1
io.write(string.rep(" ", title_start) .. colored_title_text .. "\n")
io.write("${voffset 5}")
io.write(colored_week_string .. "\n")

-- Helper for sequence
function seq(a,b)
    if a > b then return end
    return a, seq(a+1,b)
end

-- Print calendar grid
local calendar_output = string.format(
    string.rep("   ", daystart-1) ..
    string.rep(" %2d", days), seq(1,days)
)

-- Split the calendar string into lines based on the 21-character width
local lines = {}
for line in calendar_output:gmatch(".?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?") do
    if #line > 0 then
        -- Apply the "Today" coloring to the specific line
        local colored_line = line:gsub(string.format(" %2d", currentday),
                                     (color_today):format(string.format(" %2d", currentday)))
        table.insert(lines, colored_line)
    end
end

-- Force exactly 6 lines of dates
for i = 1, 6 do
    if lines[i] then
        io.write(lines[i] .. "\n")
    else
        -- Print an empty line to maintain the 6-line height
        io.write("\n")
    end
end
