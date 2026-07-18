#!/usr/bin/bash
# update-moon.sh: script to retrieve moon illumination from moongiant, calculate phase, and get moon image from NASA API. (PNG Only)
# Usage: update-moon.sh [--transform]
# v3.5 2026-03-06 @rew62

OUTPUT_DIR="/dev/shm"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CACHE_DIR="$(dirname "$SCRIPT_DIR")/.cache"
LOGFILE="$CACHE_DIR/moon.log"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
THRESHOLD_MINS=29
MAX_AGE=300
mkdir -p "$CACHE_DIR"
log() { echo "[$(date)] $*" >> "$LOGFILE"; }

# --- SPAM PROTECTION CHECK ---
NOW_EPOCH=$(date +%s)
# Get the last modification time of the output file (default to 0 if missing)
LAST_RUN=$(stat -c %Y "${OUTPUT_DIR}/moon-data2.txt" 2>/dev/null || echo 0)
# Calculate age in minutes
AGE_MINS=$(( (NOW_EPOCH - LAST_RUN) / 60 ))

if [ -f "${OUTPUT_DIR}/moon-data2.txt" ] && [ "$AGE_MINS" -lt "$THRESHOLD_MINS" ]; then
    log "moon-data2.txt is only ${AGE_MINS}m old. Skipping network fetch."
    exit 0
fi

# --- PRE-RUN CHECK (throttle) ---
#if [ -f "$OUTPUT_DIR/moon-data2.txt" ]; then
#    FILE_TIME=$(stat -c %Y "$OUTPUT_DIR/moon-data2.txt")
#    CURRENT_TIME=$(date +%s)
#    if [ $((CURRENT_TIME - FILE_TIME)) -lt $((THRESHOLD_MINS * 60)) ]; then
#        exit 0
#    fi
#fi

# --- 1. FETCH MOON TEXT ---
if wget -T 10 -t 2 -O "${OUTPUT_DIR}/raw.tmp" --user-agent="$UA" \
   "http://www.moongiant.com/phase/today" 2>>"$LOGFILE"; then

    if [ -s "${OUTPUT_DIR}/raw.tmp" ]; then
        sed -i -e '/^ *$/d; s/^ *//g; /Illumination/!d; s/<br>/\n/g; s|<[^>]*>||g' "${OUTPUT_DIR}/raw.tmp"
        sed -i '2,3!d' "${OUTPUT_DIR}/raw.tmp"
        sed -i '1s/^/Phase: /' "${OUTPUT_DIR}/raw.tmp"

	# Math Logic for Calulating Next Moon Phase and Next New Moon
        REF_DATE="2024-12-30 22:27:00 UTC"
        REF_EPOCH=$(date -d "$REF_DATE" +%s)
        SYNODIC_SECONDS=2551443
        NOW_EPOCH=$(date +%s)
        SECONDS_SINCE_REF=$(( (NOW_EPOCH - REF_EPOCH) % SYNODIC_SECONDS ))
        FULL_MOON_SECONDS=$(( SYNODIC_SECONDS / 2 ))
        SECONDS_TO_FULL=$(( (FULL_MOON_SECONDS - SECONDS_SINCE_REF + SYNODIC_SECONDS) % SYNODIC_SECONDS ))
        FULL_EPOCH=$((NOW_EPOCH + SECONDS_TO_FULL))
        SECONDS_TO_NEW=$(( (SYNODIC_SECONDS - SECONDS_SINCE_REF) % SYNODIC_SECONDS ))
        NEW_EPOCH=$((NOW_EPOCH + SECONDS_TO_NEW))
        NEXT_FULL=$(date -d "@$FULL_EPOCH" "+%b %d, %Y")
        NEXT_NEW=$(date -d "@$NEW_EPOCH" "+%b %d, %Y")

	if [ "$FULL_EPOCH" -lt "$NEW_EPOCH" ]; then
            echo "Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw.tmp"
            echo "New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw.tmp"
        else
            echo "New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw.tmp"
            echo "Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw.tmp"
        fi

        PHASE=$(sed -n '1p' "${OUTPUT_DIR}/raw.tmp" | sed 's/^[^:]*: //')
        ILLUM=$(sed -n '2p' "${OUTPUT_DIR}/raw.tmp" | sed 's/^[^:]*: //')
        LINE3=$(sed -n '3p' "${OUTPUT_DIR}/raw.tmp")
        LINE4=$(sed -n '4p' "${OUTPUT_DIR}/raw.tmp")
        #F_HEAD="\${font Fira Code:size=10}"
        #F_DATA="\${font Ubuntu Mono:size=10}"

	# sidepanel-1 formatted output
	#{
        #    echo "$F_HEAD\${color4}\${alignr}$PHASE - $ILLUM\${font}"
        #    echo "\${alignr}\${color1}$F_HEAD${LINE3%%:*}:\${font}"
        #    echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE3#*: }\${font}"
        #    echo "\${alignr}\${color1}$F_HEAD${LINE4%%:*}:\${font}"
        #    echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE4#*: }\${font}"
        #} > "${OUTPUT_DIR}/moon-data.new"
	#mv "${OUTPUT_DIR}/moon-data.new" "${OUTPUT_DIR}/moon-data.txt"

	# moon.rc formatted output
	{
            echo "\${color1}Phase:\${alignr}\${color4}$PHASE"
            echo "\${color1}Illumination:\${alignr}\${color4}$ILLUM"
            echo "\${color1}${LINE3%%:*}:\${alignr}\${color4}${LINE3#*: }"
            echo "\${color1}${LINE4%%:*}:\${alignr}\${color4}${LINE4#*: }"
        } > "${OUTPUT_DIR}/moon-data2.new"
	mv "${OUTPUT_DIR}/moon-data2.new" "${OUTPUT_DIR}/moon-data2.txt"

        [ ! -f "$CACHE_DIR/moon-data2.bak" ] || [ $((NOW_EPOCH - $(stat -c %Y "$CACHE_DIR/moon-data2.bak"))) -ge 14400 ] && \
            cp "${OUTPUT_DIR}/moon-data2.txt" "$CACHE_DIR/moon-data2.bak"
    else
        log "Moongiant returned empty file"
    fi
else
    log "Moongiant wget failed"
fi

sleep 1

# --- 2. FETCH MOON IMAGE (NASA DIAL-A-MOON API - PNG ONLY) ---
NOW_UTC=$(date -u +"%Y-%m-%dT%H:00")
NASA_API="https://svs.gsfc.nasa.gov/api/dialamoon/${NOW_UTC}"

if wget -q -T 10 -t 2 -O "${OUTPUT_DIR}/dialamoon.json" --user-agent="$UA" "$NASA_API" 2>>"$LOGFILE"; then
    if [ -s "${OUTPUT_DIR}/dialamoon.json" ]; then
        img_url=$(grep -A2 '"image":' "${OUTPUT_DIR}/dialamoon.json" | grep '"url":' | head -1 | sed 's/.*"url": "\([^"]*\)".*/\1/')
        if [ -n "$img_url" ]; then
            if wget -q -T 15 -t 2 -O "${OUTPUT_DIR}/moon_temp.jpg" --user-agent="$UA" "$img_url" 2>>"$LOGFILE"; then
                if [ -s "${OUTPUT_DIR}/moon_temp.jpg" ]; then
                    if convert "${OUTPUT_DIR}/moon_temp.jpg" -fuzz 10% -transparent black "${OUTPUT_DIR}/moon_new.png"; then
                        touch "${OUTPUT_DIR}/moon_new.png"
                        mv "${OUTPUT_DIR}/moon_new.png" "${OUTPUT_DIR}/moon.png"
                        [ ! -f "$CACHE_DIR/moon.png.bak" ] || [ $((NOW_EPOCH - $(stat -c %Y "$CACHE_DIR/moon.png.bak"))) -ge 14400 ] && \
                            cp "${OUTPUT_DIR}/moon.png" "$CACHE_DIR/moon.png.bak"
                        rm -f "${OUTPUT_DIR}/moon_temp.jpg"
                    else
                        log "ImageMagick conversion to PNG failed"
                        rm -f "${OUTPUT_DIR}/moon_temp.jpg"
                    fi
                else
                    log "NASA moon image download returned empty file"
                    rm -f "${OUTPUT_DIR}/moon_temp.jpg"
                fi
            else
                log "NASA moon image wget failed"
            fi
        else
            log "Failed to parse image URL from NASA JSON"
        fi
    else
        log "NASA API returned empty JSON"
    fi
else
    log "NASA API wget failed"
fi

rm -f "${OUTPUT_DIR}/dialamoon.json"

# --- 3. RECOVERY ---
NOW=$(date +%s)

# Recover text
if [ ! -s "${OUTPUT_DIR}/moon-data2.txt" ] && [ -f "$CACHE_DIR/moon-data2.bak" ]; then
    cp -p "$CACHE_DIR/moon-data2.bak" "${OUTPUT_DIR}/moon-data2.txt"
    log "Recovered moon-data2.txt from cache"
fi

# Recover image
if [ ! -s "${OUTPUT_DIR}/moon.png" ] && [ -f "$CACHE_DIR/moon.png.bak" ]; then
    cp -p "$CACHE_DIR/moon.png.bak" "${OUTPUT_DIR}/moon.png"
    log "Recovered moon.png from cache"
fi

# Status flag for Conky
if [ -s "${OUTPUT_DIR}/moon-data2.txt" ] && [ -s "${OUTPUT_DIR}/moon.png" ]; then
    rm -f "$OUTPUT_DIR/moon_script_error"
else
    touch "$OUTPUT_DIR/moon_script_error"
fi

if [[ "$1" == "--transform" || "$1" == "-t" ]]; then
    lua "${SCRIPT_DIR}/moon-rotate.lua" 
    log "${OUTPUT_DIR}/moon.png angle rotated"
fi

rm -f "${OUTPUT_DIR}/raw.tmp" "${OUTPUT_DIR}/img.tmp"
