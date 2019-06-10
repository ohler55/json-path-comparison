#!/bin/bash

set -euo pipefail

readonly tmp_errors_dir="$1"
readonly target_dir="$2"

. src/shared.sh

all_errors() {
    find "${tmp_errors_dir}" -type f -depth 1 -print0 | xargs -0 -n1 basename | sort
}

nice_error_headline() {
    local error_key="$1"
    local query
    local tool
    query="$(sed "s/.*___\(.*\)/\1/" <<< "$error_key")"
    tool="$(sed "s/\(.*\)___.*/\1/" <<< "$error_key")"

    echo "$(pretty_tool_name "$tool"), $(pretty_query_name "$query")"
}

compile_error_report() {
    local error_key

    {
        echo "## Errors"
        echo

        while IFS= read -r error_key; do
            echo "<h3 id=\"${error_key}\">"
            nice_error_headline "$error_key"
            echo "</h3>"
            echo
            pre_block < "${tmp_errors_dir}/${error_key}"
            echo
        done <<< "$(all_errors)"
    } > "${target_dir}/errors.md"
}

main() {
    compile_error_report
}

main
