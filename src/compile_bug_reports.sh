#!/bin/bash
set -euo pipefail

readonly results_dir="$1"
readonly implementations_matching_majority_dir="$2"
readonly consensus_dir="$3"
readonly implementation_dir="$4"

. src/shared.sh

all_queries() {
    find ./queries -type d -maxdepth 1 -mindepth 1 -print0 | xargs -0 -n1 basename | sort
}

is_query_response_correct() {
    local implementation="$1"
    local query="$2"

    if has_consensus "$query" && ! is_in_majority "$query" "$implementation"; then
       return 1
    fi

    if is_query_error "${results_dir}/${query}/${implementation}"; then
        return 1
    fi

    return 0
}

all_incorrect_queries() {
    local implementation="$1"
    local query

    while IFS= read -r query; do
        if ! is_query_response_correct "$implementation" "$query"; then
            echo "$query"
        fi
    done <<< "$(all_queries)"
}

indent_2() {
    sed 's/^/  /'
}

code_block() {
    echo "\`\`\`"
    cat
    echo "\`\`\`"
}

is_in_majority() {
    local query="$1"
    local implementation="$2"
    grep "^${implementation}\$" < "${implementations_matching_majority_dir}/${query}" > /dev/null
}

has_consensus() {
    local query="$1"
    test -s "${consensus_dir}/${query}"
}

header() {
    echo "Results do not match other implementations

The following queries provide results that do not match those of other implementations of JSONPath
(compare https://cburgmer.github.io/json-path-comparison/):
"
}

footer() {
    local implementation="$1"

    echo
    echo "For reference, the output was generated by the program in https://github.com/cburgmer/json-path-comparison/tree/master/implementations/${implementation}."
}

consensus() {
    local query="$1"
    if [[ -f "./implementations/${implementation}/SINGLE_POSSIBLE_MATCH_RETURNED_AS_SCALAR" ]] && grep '^scalar-consensus' < "${consensus_dir}/${query}" > /dev/null; then
        grep '^scalar-consensus' < "${consensus_dir}/${query}" | cut -f2
    else
        grep '^consensus' < "${consensus_dir}/${query}" | cut -f2
    fi
}

actual_output() {
    local implementation="$1"
    local query="$2"

    if is_query_error "${results_dir}/${query}/${implementation}"; then
        echo "Error:"
        query_result_payload "${results_dir}/${query}/${implementation}" | code_block
        return
    fi

    echo "Actual output:"

    if is_query_result_not_found "${results_dir}/${query}/${implementation}"; then
        echo "NOT_FOUND"
        query_result_payload "${results_dir}/${query}/${implementation}" | code_block
        return
    fi

    if is_query_not_supported "${results_dir}/${query}/${implementation}"; then
        echo "NOT_SUPPORTED"
        query_result_payload "${results_dir}/${query}/${implementation}" | code_block
        return
    fi

    query_result_payload "${results_dir}/${query}/${implementation}" | ./src/pretty_json.py | code_block
}

failing_query() {
    local implementation="$1"
    local query="$2"
    local selector

    selector="$(cat "./queries/${query}/selector")"

    echo "- [ ] \`${selector}\`"
    {
        echo "Input:"
        ./src/pretty_json.py < "./queries/${query}/document.json" | code_block
        if has_consensus "$query"; then
            if [[ -f "./queries/${query}/ALLOW_UNORDERED" ]]; then
                echo "Expected output (in any order as no consensus on ordering exists):"
            else
                echo "Expected output:"
            fi
            consensus "$query" | code_block
        fi

        actual_output "$implementation" "$query"
    } | indent_2

    echo
}

process_implementation() {
    local implementation="$1"
    local query

    header

    while IFS= read -r query; do
        # Skip loop for empty results
        if [[ -z "$query" ]]; then
            return
        fi
        failing_query "$implementation" "$query"
    done <<< "$(all_incorrect_queries "$implementation")"

    footer "$implementation"
}

main() {
    process_implementation "$(basename "$implementation_dir")"
}

main
