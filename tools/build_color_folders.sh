#!/usr/bin/env bash
# This script creates colored folder icons
#
# Colors of the folder icon:
#
#   @ - primary color
#   . - secondary color
#   " - color of symbol
#   * - color of paper
#
#    ..................
#    ..................
#    ........................................
#    ..************************************..
#    ..************************************..
#    ..************************************..
#    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@""""@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@""""@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@""""@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@""""@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@""""""""""""@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@""""""""""@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@""""""@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@@""@@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@""""""""""""@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

set -eo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TARGET_DIR="$SCRIPT_DIR/../Papirus"

DEFAULT_COLOR="blue"
SIZES_REGEX="(16x16|22x22|24x24|32x32|48x48|64x64)"
COLOR_SIZES_REGEX="(22x22|24x24|32x32|48x48|64x64)"
FILES_REGEX="(folder|user)-"

declare -A COLORS

COLORS=(
	# [0] - primary color
	# [1] - secondary color
	# [2] - color of symbol
	# [3] - color of paper
	#
	# | name     | [0]   | [1]   | [2]   | [3]   |
	# |----------|-------|-------|-------|-------|
	[blue]="      #5294e2 #4877b1 #1d344f #e4e4e4"

 	[chameleon]="currentColor fadedColor currentColor #e4e4e4"
)

headline() {
	printf "%b => %b%s\n" "\e[1;32m" "\e[0m" "$*"
}

msg() {
	printf "%b [+] %b%s\n" "\e[1;33m" "\e[0m" "$*"
}

recolor() {
	# args: <old colors> <new colors> <path to file>
	IFS=" " read -ra old_colors <<< "$1"
	IFS=" " read -ra new_colors <<< "$2"
	local filepath="$3"

	[ -f "$filepath" ] || exit 1

	local is_chameleon=false
	if [ ${new_colors[0]} == "currentColor" ]; then
		is_chameleon=true
		new_colors[0]="${new_colors[0]}\" class=\"ColorScheme-Highlight"
		new_colors[1]="${new_colors[1]}\" class=\"ColorScheme-Highlight"
		new_colors[2]="${new_colors[2]}\" class=\"ColorScheme-Text"
	fi

	for (( i = "${#old_colors[@]}" - 1; i >= 0; i-- )); do
		sed -i "s/${old_colors[$i]}/${new_colors[$i]}/gI" "$filepath"
	done

	if $is_chameleon; then
		head="\\n <defs><style id=\\\"current-color-scheme\\\" type=\\\"text\\/css\\\">.ColorScheme-Text { color: ${old_colors[2]}; } .ColorScheme-Highlight { color: ${old_colors[0]}; }<\\/style><\\/defs>"
		sed -i "1 s/$/$head/" "$filepath"
		sed -i "/fadedColor/{s/fadedColor/currentColor/;p;s/currentColor/currentColor\;fill-opacity:0.3/;s/Highlight/Text/}" "$filepath"
	fi
}

headline "PHASE 1: Delete color suffix from monochrome icons ..."
# -----------------------------------------------------------------------------
find "$TARGET_DIR" -regextype posix-extended \
	-regex ".*/16x16/places/${FILES_REGEX}${DEFAULT_COLOR}-.*" \
	-print0 | while read -r -d $'\0' file; do

	new_file="${file/-$DEFAULT_COLOR-/-}"

	msg "'$file' is renamed to '$new_file'"
	mv -f "$file" "$new_file"
done


headline "PHASE 2: Create missing symlinks ..."
# -----------------------------------------------------------------------------
find "$TARGET_DIR" -type f -regextype posix-extended \
	-regex ".*/${COLOR_SIZES_REGEX}/places/${FILES_REGEX}${DEFAULT_COLOR}[-\.].*" \
	-print0 | while read -r -d $'\0' file; do

	target="$(basename "$file")"
	symlink="${file/-$DEFAULT_COLOR/}"

	[ -e "$symlink" ] && continue

	msg "Creating missing symlink '$symlink' ..."
	ln -sf "$target" "$symlink"
done


headline "PHASE 3: Generate color folders ..."
# -----------------------------------------------------------------------------
find "$TARGET_DIR" -type f -regextype posix-extended \
	-regex ".*/${SIZES_REGEX}/places/${FILES_REGEX}${DEFAULT_COLOR}[-\.].*" \
	-print0 | while read -r -d $'\0' file; do

	for color in "${!COLORS[@]}"; do
		[[ "$color" != "$DEFAULT_COLOR" ]] || continue

		new_file="${file/-$DEFAULT_COLOR/-$color}"

		cp -P --remove-destination "$file" "$new_file"
		recolor "${COLORS[$DEFAULT_COLOR]}" "${COLORS[$color]}" "$new_file"
	done
done


headline "PHASE 4: Create symlinks for Folder Color v0.0.80 and newer ..."
# -----------------------------------------------------------------------------
# Icons mapping
FOLDER_COLOR_MAP=(
	# Folder Color icon         | Papirus icon
	# --------------------------|---------------------------
	"folder-COLOR-desktop.svg    user-COLOR-desktop.svg"
	"folder-COLOR-downloads.svg  folder-COLOR-download.svg"
	"folder-COLOR-public.svg     folder-COLOR-image-people.svg"
	"folder-COLOR-videos.svg     folder-COLOR-video.svg"
)

for mask in "${FOLDER_COLOR_MAP[@]}"; do
	for color in "${!COLORS[@]}"; do
		IFS=" " read -ra icon_mask <<< "$mask"
		folder_color_icon="${icon_mask[0]/COLOR/$color}"
		icon="${icon_mask[1]/COLOR/$color}"

		find "$TARGET_DIR" -regextype posix-extended \
			-regex ".*/${SIZES_REGEX}/places/${icon}" \
			-print0 | while read -r -d $'\0' file; do

			base_name="$(basename "$file")"
			dir_name="$(dirname "$file")"

			ln -sf "$base_name" "$dir_name/$folder_color_icon"
		done
	done
done


headline "PHASE 5: Copy color folder icons to derivative themes ..."
# -----------------------------------------------------------------------------
COLOR_NAMES="${!COLORS[*]}"  # get a string of colors
COLOR_REGEX="(${COLOR_NAMES// /|})"  # convert the list of colors to regex
DERIVATIVES=(
)  # array of derivative icon themes with 16x16 places

find "$TARGET_DIR" -regextype posix-extended \
	-regex ".*/16x16/places/folder-${COLOR_REGEX}.*" \
	-print0 | while read -r -d $'\0' file; do

	for d in "${DERIVATIVES[@]}"; do
		cp -P --remove-destination "$file" "${file/Papirus/$d}"
	done
done
