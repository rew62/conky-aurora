-- scripts/loadall.lua
-- loads and calls: background, nowplaying, volume
-- v1.1 2026-06-11 @rew62

package.path = "./scripts/?.lua"

local function try_require(modname)
    local ok, result = pcall(require, modname)
    if not ok then
        print("Error loading " .. modname .. ": " .. tostring(result))
    end
    return ok
end

try_require("background")
try_require("nowplaying")
try_require("volume")

-- ============================================================
-- conky_main  (lua_draw_hook_pre)
-- Draws: background border, nowplaying section, volume section
-- ============================================================
function conky_main()
    if conky_window == nil then return end

    -- 1. Background + border (from background.lua)
    conky_draw_background()

    -- shared Cairo surface for all remaining lua drawing
    local cs = cairo_xlib_surface_create(
        conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- 2. Now Playing section  (top of window, y-offset = 15)
    draw_nowplaying(cr, 15)

    -- 3. Volume section  (below nowplaying, y-offset = 200)
    draw_volume(cr, 200)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- ── Mouse / click handling (active only when lua_mouse_hook is set) ──────────
--
-- Volume section geometry mirrors volume.lua:
--   draw_volume(cr, 200)  →  bar_y = 200+22 = 222,  bar_x = 46,  bar_w = win_w-95
--
-- Click zones:
--   x < bar_x            → mute icon:  toggle mute
--   bar_x ≤ x ≤ bar_end  → bar:        set volume to click position
--   x > bar_end          → vol icon:   step +5%
--   scroll up/down       → anywhere in section: ±2%
--   right-click          → anywhere in section: toggle mute

local VOL_SECTION_Y = 195   -- y above which clicks are ignored

function conky_mouse_hook(event)
    local t = event.type
    if t == "mouse_move" or t == "mouse_enter" or t == "mouse_leave" then return false end

    local x, y = event.x, event.y
    if y < VOL_SECTION_Y then return false end

    -- scroll anywhere in the volume section
    if t == "scroll_up" then
        os.execute("pactl set-sink-volume @DEFAULT_SINK@ +2% &")
        return true
    elseif t == "scroll_down" then
        os.execute("pactl set-sink-volume @DEFAULT_SINK@ -2% &")
        return true
    elseif t ~= "button_down" then
        return false
    end

    local win_w  = conky_window and conky_window.width or 340
    local bar_x  = 46
    local bar_w  = win_w - 95
    local bar_end = bar_x + bar_w

    if event.button == "right" then
        os.execute("pactl set-sink-mute @DEFAULT_SINK@ toggle &")
        return true
    end

    if event.button ~= "left" then return false end

    if x < bar_x then
        -- mute icon: toggle mute
        os.execute("pactl set-sink-mute @DEFAULT_SINK@ toggle &")
    elseif x <= bar_end then
        -- click on bar: set volume proportionally
        local pct = math.floor(((x - bar_x) / bar_w) * 100 + 0.5)
        pct = math.max(0, math.min(100, pct))
        os.execute(string.format("pactl set-sink-volume @DEFAULT_SINK@ %d%% &", pct))
    else
        -- vol icon: step up 5%
        os.execute("pactl set-sink-volume @DEFAULT_SINK@ +5% &")
    end
    return true
end
