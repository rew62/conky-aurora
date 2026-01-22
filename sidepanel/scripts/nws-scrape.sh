#!/usr/bin/bash
# nws-scrape.sh v2 02 2026-01-20 @rew62
# openweathermap does not provide daytime high and low. This script grabs that information from nws.

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#Get lat and lon from env
LAT=$(sed -n 's/^lat=//p' "$SCRIPT_DIR/../../.env")
LON=$(sed -n 's/^lon=//p' "$SCRIPT_DIR/../../.env")
#echo $LAT, $LON

# tmpfs location
RAW_FILE="/dev/shm/nws-raw"

wget -q -O $RAW_FILE --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36" "https://forecast.weather.gov/MapClick.php?lat=$LAT&lon=$LON" > /dev/null 2>&1

#  Prints Highs and Lows Range 
#sed -n 'h; s/.*High: \([^ ]*\).*/\1/p; g; s/.*Low: \([^ ]*\).*/\1/p' $RAW_FILE
grep -oE "(High|Low): [0-9]+" $RAW_FILE | head -n 2 | cut -d' ' -f2


#grep -oP 'class="temp temp-high">High: \K[0-9]+' $RAW_FILE | head -1
#grep -oP 'class="temp temp-low">Low: \K[0-9]+' $RAW_FILE | head -1
#grep -o 'class="temp temp-low">Low: [0-9]*' $RAW_FILE | head -1 | grep -o '[0-9]*$

rm $RAW_FILE
