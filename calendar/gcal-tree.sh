#!/bin/bash

# Check for flags
CONKY_MODE=false
INDENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            if [[ "$2" == "conky" ]]; then
                CONKY_MODE=true
                shift 2
            else
                shift
            fi
            ;;
        -i|--indent)
            INDENT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Buffer all output lines
output=()

# Read input line by line
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Try to match: date (cols 1-20) then optional time then event
    # Looking for pattern where time might be embedded in the date field or after
    if [[ "$line" =~ ^([A-Z][a-z]{2}\ [A-Z][a-z]{2}\ [0-9]{1,2})\ +([0-9]{1,2}:[0-9]{2}[ap]m)\ +(.+)$ ]]; then
        # Has time: date in group 1, time in group 2, event in group 3
        date="${BASH_REMATCH[1]}"
        time="${BASH_REMATCH[2]}"
        event="${BASH_REMATCH[3]}"
        
        if [[ "$CONKY_MODE" == true ]]; then
            output+=("\${color1}├── $date\${color}")
            output+=("\${color1}│   \${color2}└── $time\${color} \${color3}$event\${color}")
        else
            output+=("├── $date")
            output+=("│   └── $time $event")
        fi
    elif [[ "$line" =~ ^([A-Z][a-z]{2}\ [A-Z][a-z]{2}\ [0-9]{1,2})\ +(.+)$ ]]; then
        # No time: just date and event
        date="${BASH_REMATCH[1]}"
        event="${BASH_REMATCH[2]}"
        
        if [[ "$CONKY_MODE" == true ]]; then
            output+=("\${color1}├── $date\${color}")
            output+=("\${color1}│   \${color2}└── \${color}\${color3}$event\${color}")
        else
            output+=("├── $date")
            output+=("│   └── $event")
        fi
    fi
done

# Print all lines, changing the last ├── to └── and removing │ from the final event line
for i in "${!output[@]}"; do
    line="${output[$i]}"
    
    # Add indent if specified
    if [[ -n "$INDENT" ]]; then
        line="${INDENT}${line}"
    fi
    
    if [[ $i -eq $((${#output[@]} - 2)) ]]; then
        # This is the last date line, change ├── to └──
        echo "${line/├──/└──}"
    elif [[ $i -eq $((${#output[@]} - 1)) ]]; then
        # This is the final event line, change │ to space
        echo "${line/│/\ }"
    else
        echo "$line"
    fi
done
