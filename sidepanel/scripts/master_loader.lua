-- master-loader.lua - Lua master_loader for all cario draw functions
-- v1.3 02 @rew62

local script_path = debug.getinfo(1).source:sub(2):match("(.*[/\\])")
package.path = package.path .. ';' .. script_path .. '?.lua'
local HOME = os.getenv("HOME")

-- A helper function to build the full path to an image
local function get_img(name)
    local full_path = HOME .. "/.conky/rew62/sidepanel/images/" .. name
    -- print("Looking for image at: " .. full_path) 
    return full_path
end

-- Modules
require('analog_clock') 
-- local net = require('bleys_network')
local data_mod = require('nws_data_helper')

dofile('./scripts/allcombined.lua')  --Load the fancy graphs from manyroards

-- SETTINGS: Change these to move your widgets
local clock_settings = {x = 40, y = 40, r = 28}
local net_settings = {
    iface = "eth0",
    x = 20, 
    y = 795,  
    width = 180, 
    height = 30, 
    samples = 300
}

-- Persistent data for network
local up, down, nzeiger = {}, {}, -1

-- Main Hub Logic
function conky_main_hub()
    if conky_window == nil then return end

    -- 1. Pulse Data (Scraper)
    -- This handles timing and background execution of your shell script
    if data_mod and data_mod.refresh then
        data_mod.refresh()
    end

    -- 2. Setup Cairo
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, 
                                        conky_window.visual, conky_window.width, 
                                        conky_window.height)
    local cr = cairo_create(cs)

    -- 3. Draw Background Image
    -- Drawing this first ensures it sits behind the clock/text
    draw_image(cr, get_img("World.W.png"), 0, 0, 200, 160)

    -- 4. Draw Clock
    if draw_my_clock then
        draw_my_clock(cr, clock_settings.x, clock_settings.y, clock_settings.r)
    end

    -- 5. Draw Network Graph
    -- We update traffic data then draw the chart
    --up, down, nzeiger = net.add_network_traffic(net_settings.iface, up, down, nzeiger, net_settings.samples)
    --net.draw_network_chart(cr, net_settings.iface, up, down, nzeiger, 
    --                       net_settings.x, net_settings.y, 
    --                       net_settings.width, net_settings.height, 
    --                       net_settings.samples)

    -- 6. Cleanup
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Bridges for the Conky TEXT section
-- Usage in .rc: ${lua get_val1}
function conky_get_val1() return data_mod.get_v1() end
function conky_get_val2() return data_mod.get_v2() end

-- Helper: Draw PNG image
function draw_image(cr, path, x, y, w, h)
    local image = cairo_image_surface_create_from_png(path)
    
    -- Safety check: ensure file exists and is valid PNG
    if cairo_surface_status(image) ~= CAIRO_STATUS_SUCCESS then
        cairo_surface_destroy(image)
        return
    end

    local img_w = cairo_image_surface_get_width(image)
    local img_h = cairo_image_surface_get_height(image)

    cairo_save(cr)
    cairo_translate(cr, x, y)
    cairo_scale(cr, w/img_w, h/img_h)
    cairo_set_source_surface(cr, image, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)
    cairo_surface_destroy(image)
end
