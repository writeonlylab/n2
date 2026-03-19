#!/usr/bin/env bash
# E2E test runner for n2
# Usage: ./tests/e2e/run.sh [--platform debian|fedora|macos] [--test install|prompt]
#
# Runs E2E tests inside Docker containers using tmux for terminal interaction.
# Default: runs all tests on all platforms.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N2_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORMS=(debian fedora)
TESTS=(test_install test_prompt test_uninstall)
PASS_TOTAL=0
FAIL_TOTAL=0
RESULTS=()

usage() {
    echo "Usage: $0 [--platform debian|fedora] [--test install|prompt|uninstall]"
    echo ""
    echo "Options:"
    echo "  --platform, -p    Platform to test (can be repeated). Default: all"
    echo "  --test, -t        Test to run (install|prompt|uninstall, can be repeated). Default: all"
    echo "  --help, -h        Show this help"
    exit 0
}

# Parse args
SELECTED_PLATFORMS=()
SELECTED_TESTS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p) SELECTED_PLATFORMS+=("$2"); shift 2 ;;
        --test|-t)     SELECTED_TESTS+=("test_$2"); shift 2 ;;
        --help|-h)     usage ;;
        *)             echo "Unknown option: $1"; usage ;;
    esac
done

[[ ${#SELECTED_PLATFORMS[@]} -eq 0 ]] && SELECTED_PLATFORMS=("${PLATFORMS[@]}")
[[ ${#SELECTED_TESTS[@]} -eq 0 ]]     && SELECTED_TESTS=("${TESTS[@]}")

# Check Docker is available
if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is required but not found in PATH"
    exit 1
fi

run_test() {
    local platform=$1
    local test_name=$2
    local dockerfile="$SCRIPT_DIR/platforms/${platform}.Dockerfile"
    local test_script="tests/e2e/tests/${test_name}.sh"
    local image_tag="n2-e2e-${platform}"
    local label="${platform}/${test_name}"

    if [[ ! -f "$dockerfile" ]]; then
        echo "⚠️  Dockerfile not found: $dockerfile — skipping $label"
        RESULTS+=("SKIP $label (no Dockerfile)")
        return
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐳 $label"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Build the image
    echo "Building image $image_tag..."
    if ! docker build -t "$image_tag" -f "$dockerfile" "$N2_ROOT" 2>&1; then
        echo "❌ Build failed for $label"
        RESULTS+=("FAIL $label (build failed)")
        FAIL_TOTAL=$((FAIL_TOTAL + 1))
        return
    fi

    # Run the test inside the container
    echo "Running $test_script..."
    if docker run --rm "$image_tag" bash "$test_script" 2>&1; then
        echo "✅ $label passed"
        RESULTS+=("PASS $label")
        PASS_TOTAL=$((PASS_TOTAL + 1))
    else
        echo "❌ $label failed"
        RESULTS+=("FAIL $label")
        FAIL_TOTAL=$((FAIL_TOTAL + 1))
    fi
}

echo "🧪 n2 E2E Test Runner"
echo "Platforms: ${SELECTED_PLATFORMS[*]}"
echo "Tests:     ${SELECTED_TESTS[*]}"

for platform in "${SELECTED_PLATFORMS[@]}"; do
    for test in "${SELECTED_TESTS[@]}"; do
        run_test "$platform" "$test"
    done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${RESULTS[@]}"; do
    echo "  $result"
done
echo ""
echo "Total: $PASS_TOTAL passed, $FAIL_TOTAL failed"

[[ $FAIL_TOTAL -eq 0 ]] || exit 1
echo "🎉 All tests passed!"
