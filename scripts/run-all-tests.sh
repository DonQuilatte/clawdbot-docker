#!/bin/bash
# Master Test Runner - Runs all Clawdbot system tests

# Source common library for colors and utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="/tmp/clawdbot-test-report-${TIMESTAMP}.txt"

echo "=========================================="
echo "Clawdbot - Complete Test Suite"
echo "=========================================="
echo ""
echo "Timestamp: $(date)"
echo "Report: $REPORT_FILE"
echo ""

# Initialize report
cat > "$REPORT_FILE" << EOF
Clawdbot System Test Report
============================
Date: $(date)
Host: $(hostname)
Remote: tywhitaker@192.168.1.245

EOF

echo -e "${BLUE}Select test suite to run:${NC}"
echo ""
echo "  1. Quick Test (basic functionality only - 2 min)"
echo "  2. Full System Test (comprehensive - 5 min)"
echo "  3. Crash Recovery Test (auto-restart - 1 min)"
echo "  4. Reboot Survival Test (requires reboot - 5 min)"
echo "  5. Stress/Load Test (performance under load - 2 min)"
echo "  6. All Tests (complete validation - 15 min)"
echo "  7. Custom (select individual tests)"
echo ""
read -p "Enter choice (1-7): " CHOICE
echo ""

case $CHOICE in
    1)
        echo -e "${BLUE}Running Quick Test...${NC}"
        echo ""
        echo "=== QUICK TEST ===" >> "$REPORT_FILE"
        "$SCRIPT_DIR/test-clawdbot-system.sh" | tee -a "$REPORT_FILE"
        ;;
    2)
        echo -e "${BLUE}Running Full System Test...${NC}"
        echo ""
        echo "=== FULL SYSTEM TEST ===" >> "$REPORT_FILE"
        "$SCRIPT_DIR/test-clawdbot-system.sh" | tee -a "$REPORT_FILE"
        ;;
    3)
        echo -e "${BLUE}Running Crash Recovery Test...${NC}"
        echo ""
        echo "=== CRASH RECOVERY TEST ===" >> "$REPORT_FILE"
        "$SCRIPT_DIR/test-crash-recovery.sh" | tee -a "$REPORT_FILE"
        ;;
    4)
        echo -e "${BLUE}Running Reboot Survival Test...${NC}"
        echo ""
        echo "=== REBOOT SURVIVAL TEST ===" >> "$REPORT_FILE"
        "$SCRIPT_DIR/test-reboot-survival.sh" | tee -a "$REPORT_FILE"
        ;;
    5)
        echo -e "${BLUE}Running Stress/Load Test...${NC}"
        echo ""
        echo "=== STRESS/LOAD TEST ===" >> "$REPORT_FILE"
        "$SCRIPT_DIR/test-stress-load.sh" | tee -a "$REPORT_FILE"
        ;;
    6)
        echo -e "${BLUE}Running All Tests (Complete Validation)...${NC}"
        echo ""

        echo "=== TEST 1: FULL SYSTEM TEST ===" >> "$REPORT_FILE"
        echo -e "\n${YELLOW}[1/4] Full System Test...${NC}"
        "$SCRIPT_DIR/test-clawdbot-system.sh" | tee -a "$REPORT_FILE"

        echo ""
        echo "=== TEST 2: CRASH RECOVERY TEST ===" >> "$REPORT_FILE"
        echo -e "\n${YELLOW}[2/4] Crash Recovery Test...${NC}"
        "$SCRIPT_DIR/test-crash-recovery.sh" | tee -a "$REPORT_FILE"

        echo ""
        echo "=== TEST 3: STRESS/LOAD TEST ===" >> "$REPORT_FILE"
        echo -e "\n${YELLOW}[3/4] Stress/Load Test...${NC}"
        "$SCRIPT_DIR/test-stress-load.sh" | tee -a "$REPORT_FILE"

        echo ""
        echo -e "${YELLOW}[4/4] Reboot Survival Test...${NC}"
        read -p "Run reboot test? This will reboot the remote Mac (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "=== TEST 4: REBOOT SURVIVAL TEST ===" >> "$REPORT_FILE"
            "$SCRIPT_DIR/test-reboot-survival.sh" | tee -a "$REPORT_FILE"
        else
            echo "Reboot test skipped" | tee -a "$REPORT_FILE"
        fi
        ;;
    7)
        echo -e "${BLUE}Custom Test Selection${NC}"
        echo ""
        echo "Select tests to run (space-separated numbers):"
        echo "  1 - Full System Test"
        echo "  2 - Crash Recovery"
        echo "  3 - Reboot Survival"
        echo "  4 - Stress/Load"
        echo ""
        read -p "Tests: " TESTS

        for test in $TESTS; do
            case $test in
                1)
                    echo "=== FULL SYSTEM TEST ===" >> "$REPORT_FILE"
                    "$SCRIPT_DIR/test-clawdbot-system.sh" | tee -a "$REPORT_FILE"
                    ;;
                2)
                    echo "=== CRASH RECOVERY TEST ===" >> "$REPORT_FILE"
                    "$SCRIPT_DIR/test-crash-recovery.sh" | tee -a "$REPORT_FILE"
                    ;;
                3)
                    echo "=== REBOOT SURVIVAL TEST ===" >> "$REPORT_FILE"
                    "$SCRIPT_DIR/test-reboot-survival.sh" | tee -a "$REPORT_FILE"
                    ;;
                4)
                    echo "=== STRESS/LOAD TEST ===" >> "$REPORT_FILE"
                    "$SCRIPT_DIR/test-stress-load.sh" | tee -a "$REPORT_FILE"
                    ;;
            esac
            echo "" >> "$REPORT_FILE"
        done
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo -e "${GREEN}Testing Complete${NC}"
echo "=========================================="
echo ""
echo "Full report saved to: $REPORT_FILE"
echo ""
echo "To view report:"
echo "  cat $REPORT_FILE"
echo "  open $REPORT_FILE"
echo ""
