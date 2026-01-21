-- analog-clock.lua - Minimalist Lua Soft White Clock Module for Conky
-- v1.1 @rew62

require 'cairo'

-- Note: We removed the "conky_" prefix because the Master script calls this
function draw_my_clock(cr, xc, yc, radius)
    local xc, yc, radius = tonumber(xc), tonumber(yc), tonumber(radius)

    -- Default positions if not provided
    if xc == nil then xc = 100 end
    if yc == nil then yc = 100 end
    if radius == nil then radius = 50 end

    local hours = os.date("%I")
    local mins = os.date("%M")
    local secs = os.date("%S")

    -- Set color to soft white
    cairo_set_source_rgba(cr, 0.925, 0.941, 0.945, 1)

    -- Clock face
    cairo_set_line_width(cr, 2)
    cairo_save(cr) -- Save state before translate/rotate
    cairo_translate(cr, xc, yc)
    cairo_arc(cr, 0, 0, radius, 0, 2 * math.pi)
    cairo_stroke(cr)

    -- Hour hand
    local hour_angle = (math.pi / 6) * (hours + mins / 60)
    cairo_save(cr)
    cairo_rotate(cr, hour_angle)
    cairo_move_to(cr, 0, 0)
    cairo_line_to(cr, 0, -radius * 0.5)
    cairo_stroke(cr)
    cairo_restore(cr)

    -- Minute hand
    local min_angle = (math.pi / 30) * (mins + secs / 60)
    cairo_save(cr)
    cairo_rotate(cr, min_angle)
    cairo_move_to(cr, 0, 0)
    cairo_line_to(cr, 0, -radius * 0.8)
    cairo_stroke(cr)
    cairo_restore(cr)

    -- Second hand
    cairo_set_source_rgba(cr, 0.9, 0.3, 0.3, 0.8)
    cairo_set_line_width(cr, 1)
    local sec_angle = (math.pi / 30) * secs
    cairo_save(cr)
    cairo_rotate(cr, sec_angle)
    cairo_move_to(cr, 0, 0)
    cairo_line_to(cr, 0, -radius * 0.9)
    cairo_stroke(cr)
    cairo_restore(cr)
    
    cairo_restore(cr) -- Back to original position
end
