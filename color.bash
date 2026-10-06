#!/bin/bash

## Version 0.2
## License: Open Source GPL
## Copyright: (c) 2023

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

printf '\n%s\n' 'Standard colors'
for color in black red green yellow blue purple cyan white brown; do
    printf '%sThis is %s text%s\n' "${!color}" "$color" "$reset"
done

printf '\n%s\n' 'Bright colors'
for color in gray b_red b_green b_yellow \
             b_blue b_purple b_cyan b_white; do
    printf '%sThis is %s text%s\n' "${!color}" "$color" "$reset"
done

printf '\n%s\n' 'Background colors'
for color in bg_black bg_red bg_green bg_yellow \
             bg_blue bg_purple bg_cyan bg_white; do
    # Use contrasting text for readability
    case "$color" in
        bg_black|bg_red|bg_blue|bg_purple) foreground=$b_white ;;
        *) foreground=$black ;;
    esac

    printf '%s%s This is %s %s\n' \
        "${!color}" "$foreground" "$color" "$reset"
done

printf '\n%s\n' 'Text formatting'
for style in bold dim italic underline reverse; do
    printf '%sThis is %s text%s\n' "${!style}" "$style" "$reset"
done

printf '\n%s\n' '256-color foreground palette'
for ((i = 0; i < 256; i++)); do
    printf '%s%4d%s' "$(fg256 "$i")" "$i" "$reset"
    if (( (i + 1) % 16 == 0 )); then
        printf '\n'
    fi
done

printf '\n%s\n' '256-color background palette'
for ((i = 0; i < 256; i++)); do
    printf '%s    %s' "$(bg256 "$i")" "$reset"
    if (( (i + 1) % 16 == 0 )); then
        printf '\n'
    fi
done

printf '\n%s\n' 'RGB color examples'
printf '%sThis is orange text%s\n' "$(fg_rgb 255 165 0)" "$reset"
printf '%sThis is pink text%s\n' "$(fg_rgb 255 105 180)" "$reset"
printf '%sThis is teal text%s\n' "$(fg_rgb 0 128 128)" "$reset"
printf '%s%s Orange background %s\n' \
    "$(bg_rgb 255 165 0)" "$black" "$reset"

printf '\n%sThis text is normal.%s\n' "$reset" "$reset"
echo ""
