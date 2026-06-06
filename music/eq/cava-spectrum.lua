--[[ 
    Cava Audio Visualizer for Conky - OPTIMIZED
    v1 01 2026-03-09 @rew62
    Full support for reflections, gradients, and custom block styling.
]]

require 'cairo'

-- Global State Variables
local last_config = ""
local config_loaded = false
local cava_loop_started = false

-- 1. START CAVA LOOP (Only once)
if not cava_loop_started then
    os.execute("./cava-loop.sh $PPID &")
    cava_loop_started = true
end

-- HELPER: Convert Hex to RGBA
local function rgb_to_r_g_b(col_a)
    if col_a == nil then return 0, 1, 0, 1 end -- Default Green if nil
    return ((col_a[1] / 0x10000) % 0x100) / 255., ((col_a[1] / 0x100) % 0x100) / 255., (col_a[1] % 0x100) / 255., col_a[2]
end

-- HELPER: Linear Gradient Creator
local function create_smooth_linear_gradient(x0, y0, x1, y1, t)
    local pat = cairo_pattern_create_linear(x0, y0, x1, y1)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(t.fg_colour))
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(t.alarm_colour or t.fg_colour))
    if t.mid_colour ~= nil then
        for i = 1, #t.mid_colour do
            cairo_pattern_add_color_stop_rgba(pat, t.mid_colour[i][1], rgb_to_r_g_b({t.mid_colour[i][2], t.mid_colour[i][3]}))
        end
    end
    return pat
end

-- DRAWING FUNCTION
function draw_spectrum_bar(t, cr)
    cairo_save(cr)
    
    -- Setup Geometry
    local pct = 100 * t.arg / t.max
    local pcb = 100 / t.blocks
    
    cairo_set_line_width(cr, t.height)
    cairo_translate(cr, t.x, t.y)
    cairo_rotate(cr, (t.angle or 0) * math.pi / 180)

    -- Draw Multi-Block Bar
    for pt = 1, t.blocks do
        local y1 = -(pt - 1) * (t.height + t.space)
        local col = t.bg_colour
        local is_on = false
        
        if pct >= (pcb * (pt - 1)) and pct > 0 then
            is_on = true
            col = t.fg_colour
            if t.alarm and pct >= (100 * t.alarm / t.max) and (pcb * pt) > (100 * t.alarm / t.max) then
                col = t.alarm_colour or t.fg_colour
            end
        end

        -- Handle Gradients vs Solid
        if t.smooth and is_on then
            local pat = create_smooth_linear_gradient(t.width / 2, 0, t.width / 2, -(t.blocks * (t.height + t.space)), t)
            cairo_set_source(cr, pat)
            cairo_pattern_destroy(pat)
        else
            local r, g, b, a = rgb_to_r_g_b(col)
            cairo_set_source_rgba(cr, r, g, b, a)
        end

        cairo_move_to(cr, 0, y1)
        cairo_line_to(cr, t.width, y1)
        cairo_stroke(cr)
    end
    
    cairo_restore(cr)
end

-- MAIN ENTRY POINT
function conky_main_bars(name)
    if conky_window == nil then return end
    
    -- 1. LOAD EXTERNAL CONFIG (Only once per session/name change)
    if not config_loaded or last_config ~= name then
        local path = "./spectrum-configs/" .. name
        if io.open(path, "r") then
            local chunk = loadfile(path)
            if chunk then 
                chunk() -- Executes config and sets global variables
                config_loaded = true
                last_config = name
            end
        end
    end

    -- 2. READ CAVA DATA (The high-speed optimization)
    local cava_values = {}
    local cava_file = io.open("/dev/shm/cava-out.tmp", "r")
    if cava_file then
        local line = cava_file:read("*l")
        cava_file:close()
        if line then
            for val in string.gmatch(line, "%S+") do
                table.insert(cava_values, tonumber(val) or 0)
            end
        end
    end

    -- 3. SETUP CAIRO CONTEXT
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- 4. RENDER LOOP
    if tonumber(conky_parse('${updates}')) > 3 then
        for i = 1, (bars or 0) do
            local k = {
                arg = cava_values[i] or 0,
                max = max or 100,
                alarm = alarm,
                x = x + (i - 1) * (width + (barspaces or 2)),
                y = y,
                blocks = blocks or 10,
                height = height or 5,
                width = width or 20,
                space = blockspaces or 2,
                fg_colour = fg_colour,
                bg_colour = bg_colour,
                alarm_colour = alarm_colour,
                smooth = smooth,
                mid_colour = mid_colour,
                angle = angle or 0
            }
            draw_spectrum_bar(k, cr)
        end
    end

    -- 5. CLEANUP
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    return ""  -- keeps conky happy if calling from the TEXT section
end
