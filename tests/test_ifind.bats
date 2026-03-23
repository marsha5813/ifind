#!/usr/bin/env bats

setup() {
    # Source the ifind function
    source "${BATS_TEST_DIRNAME}/../bin/ifind.sh"

    # Point at test fixtures
    export IFIND_ROOT="${BATS_TEST_DIRNAME}/fixtures"
    export IFIND_DEPTH=1
}

@test "ifind prints error when rg is missing" {
    run env PATH="/usr/bin:/bin" bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        hash -r
        ifind test
    "
    [[ "$output" == *"is required"* ]]
}

@test "ifind prints error when fzf is missing" {
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export PATH='/usr/bin:/bin:/usr/local/bin'
        # Ensure rg is found but fzf is not
        which rg >/dev/null 2>&1 || skip 'rg not installed'
        hash -d fzf 2>/dev/null
        ifind test
    "
    # Should fail because fzf is missing from restricted PATH
    [[ "$status" -ne 0 ]]
}

@test "ifind prints error for nonexistent root" {
    export IFIND_ROOT="/nonexistent/path"
    run ifind test
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"does not exist"* ]]
}

@test "ifind prints error when no projects match query" {
    # Use a query that won't match anything
    # Mock fzf to not be called (rg should find nothing)
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        ifind zzzznonexistentqueryzzzz
    "
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"no projects matched"* ]]
}

@test "ifind finds project by file content keyword" {
    # Search for 'scraping' which exists in project-a's README
    # Mock fzf to just output its input (select first match)
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        # Override fzf to just pass through first line
        fzf() { head -1; }
        export -f fzf
        ifind scraping
    "
    [[ "$output" == *"project-a"* ]]
}

@test "ifind finds project by directory name" {
    # 'pipeline' appears in directory name 'project-c' description but also
    # let's search for 'project-b' which is a directory basename match
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        fzf() { head -1; }
        export -f fzf
        ifind project-a
    "
    [[ "$output" == *"project-a"* ]]
}

@test "ifind multi-word AND search filters correctly" {
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        fzf() { head -1; }
        export -f fzf
        ifind web scraping
    "
    [[ "$output" == *"project-a"* ]]
}

@test "ifind content search works in zsh" {
    command -v zsh >/dev/null || skip "zsh not installed"
    run zsh -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        fzf() { head -1; }
        ifind scraping
    "
    [[ "$output" == *"project-a"* ]]
}

@test "ifind multi-word AND works in zsh" {
    command -v zsh >/dev/null || skip "zsh not installed"
    run zsh -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='${BATS_TEST_DIRNAME}/fixtures'
        export IFIND_DEPTH=1
        fzf() { head -1; }
        ifind web scraping
    "
    [[ "$output" == *"project-a"* ]]
}

@test "IFIND_ROOT override is respected" {
    run bash -c "
        source '${BATS_TEST_DIRNAME}/../bin/ifind.sh'
        export IFIND_ROOT='/nonexistent/custom/path'
        ifind test
    "
    [[ "$output" == *"/nonexistent/custom/path"* ]]
}
