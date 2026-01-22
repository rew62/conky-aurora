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
    print("Now: " .. now)
    print("Last update: " .. last_update)
    print("Difference: " .. (now - last_update))
    print("Interval: " .. update_interval)
    
    if now - last_update >= update_interval then
        print("Condition met, executing script...")
        local cmd = HOME .. "/.conky/rew62/sidepanel/scripts/nws-scrape.sh > " .. data_file
        print("Command: " .. cmd)
        local result = os.execute(cmd)
        print("Execute result: " .. tostring(result))
        last_update = now
        
        -- Check if file was created
        os.execute("ls -la " .. data_file)
    else
        print("Condition NOT met, skipping script execution")
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
        print("v1: " .. data.v1)
        print("v2: " .. data.v2)
    else
        print("Could not open data file: " .. data_file)
    end
end

function M.get_v1() return data.v1 end
function M.get_v2() return data.v2 end

-- For testing
M.refresh()

return M
