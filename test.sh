#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIG="$(command -v zig)"

cd "$SCRIPT_DIR"

run_unit() {
    echo -e "${CYAN}${BOLD}=== Unit Tests ===${RESET}"
    if zig build test; then
        echo -e "${GREEN}PASS${RESET}"
    else
        echo -e "${RED}FAIL${RESET}"
        return 1
    fi
}

run_integration() {
    echo -e "${CYAN}${BOLD}=== Integration Tests (requires root) ===${RESET}"
    if [ "$(id -u)" -eq 0 ]; then
        if zig build test; then
            echo -e "${GREEN}PASS${RESET}"
        else
            echo -e "${RED}FAIL${RESET}"
            return 1
        fi
    else
        echo -e "${YELLOW}Not root. Re-running with sudo...${RESET}"
        if sudo env PATH="$PATH" "$ZIG" build test; then
            echo -e "${GREEN}PASS${RESET}"
        else
            echo -e "${RED}FAIL${RESET}"
            return 1
        fi
    fi
}

case "${1:-all}" in
    unit)
        run_unit
        ;;
    integration)
        run_integration
        ;;
    all)
        run_unit
        echo
        run_integration
        ;;
    *)
        echo "Usage: $0 [unit|integration|all]"
        exit 1
        ;;
esac
