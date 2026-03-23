#!/usr/bin/env bash
# ifind - Intelligent project finder
# https://github.com/marsha5813/ifind
#
# Source this file in your shell rc to use the `ifind` function.
# Compatible with both bash and zsh.
# Usage: ifind [query...]

# Default config files to search inside projects
IFIND_DEFAULT_FILES="CLAUDE.md,README.md,README.rst,README,README.txt,package.json,pyproject.toml,Cargo.toml,go.mod,Makefile,docker-compose.yml,docker-compose.yaml,.env.example,setup.py,setup.cfg,pom.xml,build.gradle,CMakeLists.txt"

ifind() {
    local root="${IFIND_ROOT:-$HOME/dev}"
    local depth="${IFIND_DEPTH:-1}"
    local files="${IFIND_FILES:-$IFIND_DEFAULT_FILES}"

    # Check required dependencies
    if ! command -v rg >/dev/null 2>&1; then
        echo "ifind: ripgrep (rg) is required but not found. Install with: brew install ripgrep" >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "ifind: fzf is required but not found. Install with: brew install fzf" >&2
        return 1
    fi

    # Check that root directory exists
    if [[ ! -d "$root" ]]; then
        echo "ifind: root directory '$root' does not exist. Set IFIND_ROOT to your projects directory." >&2
        return 1
    fi

    # Discover project directories
    local dirs
    if command -v fd >/dev/null 2>&1; then
        dirs=$(fd --type d --min-depth 1 --max-depth "$depth" --no-hidden . "$root" 2>/dev/null)
    else
        dirs=$(find "$root" -mindepth 1 -maxdepth "$depth" -type d ! -name '.*' 2>/dev/null)
    fi

    if [[ -z "$dirs" ]]; then
        echo "ifind: no directories found in '$root'" >&2
        return 1
    fi

    local matches
    if [[ $# -gt 0 ]]; then
        local query="$*"

        # Source 1: Match directory basenames — all words must appear (case-insensitive)
        # Uses a grep chain: pipe dir list through one grep per word
        local name_matches
        name_matches=$(echo "$dirs" | while IFS= read -r d; do
            d="${d%/}"
            echo "${d##*/}	$d"
        done)
        while [[ $# -gt 0 ]]; do
            name_matches=$(echo "$name_matches" | grep -i -- "$1")
            shift
        done
        # Extract the full paths (after the tab)
        name_matches=$(echo "$name_matches" | while IFS= read -r line; do
            [[ -n "$line" ]] && printf '%s\n' "${line#*	}"
        done)

        # Restore positional params from the saved query string
        # shellcheck disable=SC2086
        set -- $query

        # Source 2: Match inside config files — all words must appear
        local glob_args=()
        local IFS=','
        for f in $files; do
            glob_args+=(--glob "$f")
        done
        unset IFS

        # Start with files matching the first word
        local content_matches
        content_matches=$(rg --ignore-case --files-with-matches \
            --no-messages \
            --max-depth "$((depth + 1))" \
            "${glob_args[@]}" \
            -- "$1" "$root" 2>/dev/null)
        shift

        # Filter to keep only files containing ALL remaining words
        while [[ $# -gt 0 ]]; do
            if [[ -z "$content_matches" ]]; then
                break
            fi
            content_matches=$(echo "$content_matches" | while IFS= read -r f; do
                if rg --ignore-case --quiet -- "$1" "$f" 2>/dev/null; then
                    echo "$f"
                fi
            done)
            shift
        done

        # Extract parent directories (skip empty lines)
        if [[ -n "$content_matches" ]]; then
            content_matches=$(echo "$content_matches" | while IFS= read -r filepath; do
                [[ -n "$filepath" ]] && dirname "$filepath"
            done)
        fi

        # Combine and deduplicate
        matches=$(printf '%s\n%s' "$name_matches" "$content_matches" | sort -u | grep -v '^$')
    else
        matches="$dirs"
    fi

    if [[ -z "$matches" ]]; then
        echo "ifind: no projects matched '$query'" >&2
        return 1
    fi

    # Build preview command (single quotes intentional — fzf substitutes {} at runtime)
    # shellcheck disable=SC2016
    local preview_cmd='
        dir={}
        for f in "$dir"/CLAUDE.md "$dir"/README.md "$dir"/README.rst "$dir"/README "$dir"/README.txt; do
            if [[ -f "$f" ]]; then
                head -100 "$f"
                exit 0
            fi
        done
        ls -la "$dir"
    '

    # Interactive selection via fzf
    local selected
    selected=$(echo "$matches" | fzf \
        --header "ifind${query:+: $query}" \
        --preview "bash -c '$preview_cmd'" \
        --preview-window 'right:60%:wrap' \
        --ansi \
        --select-1 \
        --exit-0)

    if [[ -n "$selected" ]]; then
        cd "$selected" || return 1
        echo "ifind: jumped to $(basename "$selected")"
    fi
}
