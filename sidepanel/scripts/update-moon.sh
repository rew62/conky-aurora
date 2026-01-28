#!/usr/bin/bash
# update-moon.sh: script to get moon illumination from moongiant, calculate phase, and get moon image from NASA.
# v3.0 2026-01-28 @rew62

OUTPUT_DIR="/dev/shm"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CACHE_DIR="$(dirname "$SCRIPT_DIR")/.cache"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
THRESHOLD_MINS=29

mkdir -p "$CACHE_DIR"

# --- 1. PRE-RUN CHECK ---
# If fresh data exists, skip to avoid hitting NASA/Moongiant too hard
if [ -f "$OUTPUT_DIR/moon-data.txt" ]; then
    FILE_TIME=$(stat -c %Y "$OUTPUT_DIR/moon-data.txt")
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - FILE_TIME)) -lt $((THRESHOLD_MINS * 60)) ]; then
        exit 0
    fi
fi

# --- 2. FETCH MOON TEXT ---
wget -q -T 10 -t 2 -O "${OUTPUT_DIR}/raw.tmp" --user-agent="$UA" "http://www.moongiant.com/phase/today"

if [ $? -eq 0 ] && [ -s "${OUTPUT_DIR}/raw.tmp" ]; then
    # Process text
    sed -i -e '/^ *$/d; s/^ *//g; /Illumination/!d; s/<br>/\n/g; s|<[^>]*>||g' "${OUTPUT_DIR}/raw.tmp"
    sed -i '2,3!d' "${OUTPUT_DIR}/raw.tmp"
    sed -i '1s/^/Phase: /' "${OUTPUT_DIR}/raw.tmp"

    # Math Logic
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
        echo "Next Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw.tmp"
        echo "Next New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw.tmp"
    else
        echo "Next New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw.tmp"
        echo "Next Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw.tmp"
    fi

    # Format for Conky
    PHASE=$(sed -n '1p' "${OUTPUT_DIR}/raw.tmp" | sed 's/^[^:]*: //')
    ILLUM=$(sed -n '2p' "${OUTPUT_DIR}/raw.tmp" | sed 's/^[^:]*: //')
    LINE3=$(sed -n '3p' "${OUTPUT_DIR}/raw.tmp")
    LINE4=$(sed -n '4p' "${OUTPUT_DIR}/raw.tmp")
    F_HEAD="\${font Fira Code:size=10}"
    F_DATA="\${font Ubuntu Mono:size=10}"

    {
        echo "$F_HEAD\${color4}\${alignr}$PHASE - $ILLUM\${font}"
        echo "\${alignr}\${color1}$F_HEAD${LINE3%%:*}:\${font}"
        echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE3#*: }\${font}"
        echo "\${alignr}\${color1}$F_HEAD${LINE4%%:*}:\${font}"
        echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE4#*: }\${font}"
    } > "${OUTPUT_DIR}/moon-data.new"
    
    # Atomic Swap
    mv "${OUTPUT_DIR}/moon-data.new" "${OUTPUT_DIR}/moon-data.txt"
    cp "${OUTPUT_DIR}/moon-data.txt" "$CACHE_DIR/moon-data.bak"
fi

# --- 3. FETCH MOON IMAGE ---
wget -q -T 10 -t 2 -O "${OUTPUT_DIR}/img.tmp" "https://moon.nasa.gov/moon-observation/daily-moon-guide/"

if [ $? -eq 0 ] && [ -s "${OUTPUT_DIR}/img.tmp" ]; then
    now_ico="$(LANG=en_us_88591 date +'%d %b %Y')"
    img_icon=$(grep -Eio "${now_ico}.{0,428}" "${OUTPUT_DIR}/img.tmp" | \
               sed "s/&quot;/ /g; s/, /\n/g" | \
               sed -e "2,13d; s/image_src ://g; s/^ *//g; s/\.jpg.*/.jpg/" | sed -n 2p)

    if [ -n "$img_icon" ]; then
        wget -q -T 15 -t 2 -O "${OUTPUT_DIR}/moon_new.jpg" "https://moon.nasa.gov/$img_icon"
        if [ -s "${OUTPUT_DIR}/moon_new.jpg" ]; then
            mv "${OUTPUT_DIR}/moon_new.jpg" "${OUTPUT_DIR}/moon.jpg"
            cp "${OUTPUT_DIR}/moon.jpg" "$CACHE_DIR/moon.jpg.bak"
        fi
    fi
fi

# --- 4. RECOVERY (If /dev/shm is empty/wiped) ---
#if [ ! -s "${OUTPUT_DIR}/moon-data.txt" ] && [ -f "$CACHE_DIR/moon-data.bak" ]; then
#    cp "$CACHE_DIR/moon-data.bak" "${OUTPUT_DIR}/moon-data.txt"
#fi
#if [ ! -s "${OUTPUT_DIR}/moon.jpg" ] && [ -f "$CACHE_DIR/moon.jpg.bak" ]; then
#    cp "$CACHE_DIR/moon.jpg.bak" "${OUTPUT_DIR}/moon.jpg"
#fi

# --- 4. RECOVERY & STATUS ---
# Define how old a file can be before we consider it a "failure" (e.g., 5 mins)
# This handles the case where the script runs but the network fetch failed.
MAX_AGE=300
NOW=$(date +%s)
FILE_TIME=$(stat -c %Y "${OUTPUT_DIR}/moon-data.txt" 2>/dev/null || echo 0)
AGE=$((NOW - FILE_TIME))

if [ -s "${OUTPUT_DIR}/moon-data.txt" ] && [ $AGE -lt $MAX_AGE ]; then
    # SUCCESS: File exists and is fresh
    rm -f "$OUTPUT_DIR/moon_script_error"
else
    # FAILURE: File is missing, empty, or old. Try to recover from backup.
    touch "$OUTPUT_DIR/moon_script_error"
    
    if [ ! -s "${OUTPUT_DIR}/moon-data.txt" ] && [ -f "$CACHE_DIR/moon-data.bak" ]; then
        cp "$CACHE_DIR/moon-data.bak" "${OUTPUT_DIR}/moon-data.txt"
    fi
    if [ ! -s "${OUTPUT_DIR}/moon.jpg" ] && [ -f "$CACHE_DIR/moon.jpg.bak" ]; then
        cp "$CACHE_DIR/moon.jpg.bak" "${OUTPUT_DIR}/moon.jpg"
    fi
fi



# Clean up
rm -f "${OUTPUT_DIR}/raw.tmp" "${OUTPUT_DIR}/img.tmp"
