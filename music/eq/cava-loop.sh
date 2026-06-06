#!/bin/bash
#####################################################
# Optimized Cava Loop v2.0 (Atomic RAM Stream)      #
#####################################################

# 1. SETUP PATHS (Using RAM disk /dev/shm for speed)
log="$HOME/.xsession-errors"
tmp_out="/dev/shm/cava-out.tmp"
cava_conf="./cava-config"
parent_pid="$1"  # Conky PID passed from cava-spectrum.lua via $PPID

# 2. CLEANUP
pkill -f "cava -p $cava_conf"
touch "$tmp_out"

# 3. SYNC BARS (Once at startup)
cavabars=$(grep 'bars = ' "$cava_conf" | awk -F '= ' '{print $2}')
for file in ./spectrum-configs/*; do
    if [ -f "$file" ]; then
        sed -i "s/bars=[0-9]*/bars=$cavabars/g" "$file"
    fi
done

# 4. THE ENGINE (The "Tee" Optimization)
# We pipe Cava directly to a loop that overwrites the RAM file.
# Using 'stdbuf' prevents the shell from "holding" data in a buffer.
echo "cava-loop.sh: Starting RAM stream..." >> "$log"
stdbuf -oL cava -p "$cava_conf" | while read -r line; do
    echo "$line" > "$tmp_out"
done &

# 5. LIGHTWEIGHT MONITOR (PID-based, robust)
(
    #if ! wmctrl -l | grep -q "conky-spectrum"; then  # requires wmctrl
    #if ! pgrep -f "spectrum.conky" > /dev/null; then
    if [ -z "$parent_pid" ]; then exit 0; fi
    while sleep 5; do
        if ! kill -0 "$parent_pid" 2>/dev/null; then
            pkill -f "cava -p $cava_conf"
            exit 0
        fi
    done
) &

echo "cava-loop.sh: EQ Engine is running in the background."
