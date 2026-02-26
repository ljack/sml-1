#!/usr/bin/env bash
# ==============================================================================
# Script: update_dashboard_dropdown.sh
# Purpose: Scans the local results directory for all existing benchmark runs
#          and dynamically updates the <select> dropdown in docs/index.html
#          so users can view historical data easily.
# ==============================================================================

set -euo pipefail

RESULTS_DIR="results"
DOCS_HTML="docs/index.html"

# Find all JSON metadata files and extract timestamps
# 1. find searches the results/ folder up to 2 levels deep for metadata.json
# 2. dirname strips the filename, leaving just the directory path (e.g., results/2026-02-26T21...)
# 3. xargs basename extracts just the final folder name (the timestamp string)
# 4. sort -r sorts them reverse-alphabetically (newest first)
AVAILABLE_RUNS=$(find "$RESULTS_DIR" -maxdepth 2 -name "metadata.json" -exec dirname {} \; | xargs -n 1 basename | sort -r)

# Build the <select> options block
OPTIONS_HTML=""
for run in $AVAILABLE_RUNS; do
  # e.g., run = "2026-02-26T21-00-00Z"
  # Format it slightly to look nice by replacing 'T' with a space and ripping off the 'Z'
  DISPLAY_NAME=$(echo "$run" | sed -e 's/T/ /' -e 's/Z//')
  
  # Concatenate the new HTML option string
  OPTIONS_HTML+="                            <option value=\"$run\">$DISPLAY_NAME</option>\n"
done

# Inject the generated options into the HTML file using awk.
# We use awk instead of sed because multi-line replacement in sed is error-prone across platforms.
# -v new_opts passes our generated HTML string into awk as a variable.
awk -v new_opts="$OPTIONS_HTML" '
  # When we find the opening select tag...
  /<select id="dataset-select"/ {
    print                     # Print the existing <select> line
    printf "%s", new_opts     # Inject all our new <option> lines
    skip = 1                  # Turn on the "skip mode" flag
    next                      # Move to the next line in the file
  }
  # When we hit the closing select tag...
  /<\/select>/ {
    skip = 0                  # Turn off "skip mode" so we keep printing the rest of the file
  }
  # As long as skip mode is off, print the line exactly as is.
  !skip { print }
' "$DOCS_HTML" > "${DOCS_HTML}.tmp"

# Overwrite the original file with the modified temp file.
mv "${DOCS_HTML}.tmp" "$DOCS_HTML"

echo "Updated docs/index.html with available benchmark runs."
