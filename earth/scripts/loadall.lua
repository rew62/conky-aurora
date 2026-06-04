-- scripts/loadall.lua - Loads and calls Lua Modules
-- by @wim66
-- v4.1 May 2, 2025

package.path = "./scripts/?.lua"

-- Placeholder vars
--local SCRIPT_DIR = debug.getinfo(1, "S").source:match("^@(.*/)")
--local src = debug.getinfo(1, "S").source:sub(2)
--local path = src:match("(.*[/\\])") or "./"
--local handle = io.popen("cd " .. path .. " && pwd")
--local FULL_SCRIPT_DIR = handle and handle:read("*l") or path
--if handle then handle:close() end

local FULL_SCRIPT_DIR = io.popen("realpath '" .. debug.getinfo(1,"S").source:sub(2):match("(.*/)") .. "'"):read("*l")
--print("Earth Script Running From: " .. FULL_SCRIPT_DIR)

--local path = SCRIPT_DIR .. "../spectrum-configs/" .. name
--CONKY_DIR = os.getenv("HOME") .. "/.conky/rew62/earth/"
CONKY_DIR = FULL_SCRIPT_DIR:match("(.*/)") or (FULL_SCRIPT_DIR .. "/")
------------------------------------------

local function try_require(modname)
    local ok, result = pcall(require, modname)
    if not ok then
        print("Error loading " .. modname .. ": " .. tostring(result))
    end
    return ok
end

try_require("background")
try_require("image2")

-- ============================================================
-- conky_main  (lua_draw_hook_pre)
-- Draws: background border
-- ============================================================
function conky_main()
    if conky_window == nil then return end

    -- Background + border (from background.lua) + image (from image2)
    conky_draw_background()
    conky_draw_image(path, x, y, w, h)
end
