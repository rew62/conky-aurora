local M = {}

-- Configuration
local HOME = os.getenv("HOME")
local update_interval = 14400 
local last_update = 0
local data_file = "/dev/shm/nws_data.txt"

-- Internal storage
local data = { v1 = "Loading...", v2 = "Loading..." }

function M.refresh()
    local now = os.time()

    if now - last_update >= update_interval then
        -- Run the shell script in the BACKGROUND (&) 
        -- and redirect its output to a temp file in RAM
        os.execute(HOME .. "/.conky/rew62/sidepanel/scripts/nws-scrape.sh > " .. data_file)
        last_update = now
    end

    -- Every time refresh is called, we peek at the file to see if it's updated
    local f = io.open(data_file, "r")
    if f then
        local lines = {}
        for line in f:lines() do
            table.insert(lines, line)
        end
        f:close()
        
        data.v1 = lines[1] or data.v1
        data.v2 = lines[2] or data.v2
    end
end

function M.get_v1() return data.v1 end
function M.get_v2() return data.v2 end

return M
