-- conky-system-lua V4
-- by @wim66
-- v4 6-April-2024

package.path = "./scripts/?.lua"

function conky_vars()

    -- Set network interface for all scripts here
    var_NETWORK = "wlp2s0"

    use_FONT = "zekton"
    -- https://www.dafont.com/zekton.font

    border_COLOR = "0,0x2E8B57,1.00,0.5,0x2E8B57,1.00,1,0x2E8B57,1.00"
    bg_COLOR = "0x1d1d2e,0.40"
    layer_2 = "0,0xffffff,0.05,0.5,0xc2c2c2,0.20,1,0xffffff,0.05"
    
    -- 3. Set Global Variables
    conky_w = 202 
    conky_h = 200
end

