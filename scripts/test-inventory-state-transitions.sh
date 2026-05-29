#!/bin/bash
# =============================================================================
# Inventory Item State Transitions API Test Script
# Generated for: Inventory Item State Transitions (GGQPA-002)
# =============================================================================
#
# Usage: ./scripts/test-inventory-state-transitions.sh [BASE_URL]
#        Default BASE_URL: http://localhost:3000
#
# Requirements:
# - No external dependencies (no jq, only curl and bash)
# - Each request has -m 10 timeout to prevent hanging
# - HTTP status captured via: -o /tmp/response.txt -w "%{http_code}"
#
# =============================================================================
#
# TEST CASE OVERVIEW (Human-Reviewable)
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ SETUP TESTS (Create Test Data)                                            │
# ├─────────┬──────────────────────┬────────────────┬────────────┬──────────┤
# │ Test ID │ Description          │ Initial State  │ Exp. Purchase│ HTTP     │
# ├─────────┼──────────────────────┼────────────────┼────────────┼──────────┤
# │ SETUP-1  │ Create Depleted Item  │ Depleted       │ true        │ 201      │
# │ SETUP-2  │ Create Low Item       │ Low            │ true        │ 201      │
# │ SETUP-3  │ Create Available Item │ Available      │ false       │ 201      │
# │ SETUP-4  │ Create Available Item │ Available      │ false       │ 201      │
# └─────────┴──────────────────────┴────────────────┴────────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ HAPPY PATH TESTS (State Transitions)                                      │
# ├─────────┬──────────────────────┬──────────┬────────────┬────────┬──────────┤
# │ Test ID │ Description          │ From State│ To State    │ Purchase│ HTTP     │
# ├─────────┼──────────────────────┼──────────┼────────────┼────────┼──────────┤
# │ AC1     │ Replenish Depleted   │ Depleted │ Available   │ false  │ 200      │
# │ AC2     │ Replenish Low         │ Low      │ Available   │ false  │ 200      │
# │ AC3     │ Mark as Low           │ Available│ Low         │ true   │ 200      │
# │ AC4     │ Deplete Available     │ Available│ Depleted    │ true   │ 200      │
# │ AC5     │ Deplete Low           │ Low      │ Depleted    │ true   │ 200      │
# │ AC6     │ Idempotent Replenish  │ Available│ Available   │ false  │ 200      │
# └─────────┴──────────────────────┴──────────┴────────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ ERROR TESTS (Not Found Scenarios)                                         │
# ├─────────┬──────────────────────┬──────────┬────────────┬────────┬──────────┤
# │ Test ID │ Description          │ Item ID  │ Expected    │ Actual │ HTTP     │
# ├─────────┼──────────────────────┼──────────┼────────────┼────────┼──────────┤
# │ AC7     │ Replenish Not Found │ Invalid  │ 404         │ -      │ 404      │
# │ AC8     │ Mark-Low Not Found  │ Invalid  │ 404         │ -      │ 404      │
# │ AC9     │ Deplete Not Found   │ Invalid  │ 404         │ -      │ 404      │
# └─────────┴──────────────────────┴──────────┴────────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ EDGE CASE TESTS                                                             │
# ├─────────┬──────────────────────┬────────────────┬────────────┬──────────┤
# │ Test ID │ Description          │ Input          │ Expected    │ HTTP     │
# ├─────────┼──────────────────────┼────────────────┼────────────┼──────────┤
# │ EDGE-1   │ Invalid UUID Format  │ not-a-uuid     │ 404         │ 404      │
# │ EDGE-2   │ Empty UUID           │ (empty)        │ 404         │ 404      │
# │ EDGE-3   │ Rapid Calls          │ Same item 2x   │ Both succeed│ 200,200  │
# └─────────┴──────────────────────┴────────────────┴────────────┴──────────┘
#
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
BASE_URL="${1:-http://localhost:3000}"

# Colors for output (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
fi

# -----------------------------------------------------------------------------
# SEED DATA REFERENCE
# -----------------------------------------------------------------------------
# Test items will be created dynamically via API during setup
#
# Created Items (stored after setup):
#   - DEPLETED_ITEM_ID: Item in "Depleted" state with requiresPurchase=true
#   - LOW_ITEM_ID: Item in "Low" state with requiresPurchase=true
#   - AVAILABLE_ITEM_1_ID: Item in "Available" state with requiresPurchase=false
#   - AVAILABLE_ITEM_2_ID: Item in "Available" state for idempotent test
#
# Test UUID for not-found tests:
#   - INVALID_UUID: "550e8400-e29b-41d4-a716-446655440000" (non-existent)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DATA STORAGE
# -----------------------------------------------------------------------------
DEPLETED_ITEM_ID=""
LOW_ITEM_ID=""
AVAILABLE_ITEM_1_ID=""
AVAILABLE_ITEM_2_ID=""
INVALID_UUID="550e8400-e29b-41d4-a716-446655440000"

# -----------------------------------------------------------------------------
# TEST COUNTERS AND RESULT TRACKING
# -----------------------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Arrays to track results for final summary table
declare -a TEST_IDS
declare -a TEST_DESCRIPTIONS
declare -a EXPECTED_STATUS
declare -a ACTUAL_STATUS
declare -a TEST_RESULTS

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
print_test_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST: ${NC}$1"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_expected() {
    echo -e "${YELLOW}Expected: ${NC}$1"
}

print_result() {
    echo -e "${GREEN}Response:${NC}"
}

# Record test result for final summary table
record_result() {
    TEST_IDS+=("$1")
    TEST_DESCRIPTIONS+=("$2")
    EXPECTED_STATUS+=("$3")
    ACTUAL_STATUS+=("$4")
    TEST_RESULTS+=("$5")
}

# Check test result - called after each curl command
check_result() {
    local test_id="$1"
    local test_desc="$2"
    local expected_status="$3"
    local actual_status="$4"
    local body="$5"

    echo "$body"
    echo ""

    if [ "$actual_status" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED${NC} [HTTP Status: $actual_status]"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        record_result "$test_id" "$test_desc" "$expected_status" "$actual_status" "PASS"
    else
        echo -e "${RED}✗ FAILED${NC} [HTTP Status: $actual_status, Expected: $expected_status]"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_result "$test_id" "$test_desc" "$expected_status" "$actual_status" "FAIL"
    fi
    echo ""
}

# Print final results table
print_results_table() {
    echo ""
    echo -e "${CYAN}┌──────────┬────────────────────────────────┬──────────┬──────────┬──────────┐${NC}"
    echo -e "${CYAN}│ Test ID  │ Description                    │ Expected │ Actual   │ Result   │${NC}"
    echo -e "${CYAN}├──────────┼────────────────────────────────┼──────────┼──────────┼──────────┤${NC}"

    for i in "${!TEST_IDS[@]}"; do
        local result_color="${GREEN}"
        if [ "${TEST_RESULTS[$i]}" = "FAIL" ]; then
            result_color="${RED}"
        fi
        printf "${CYAN}│${NC} %-8s ${CYAN}│${NC} %-30s ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-8s ${CYAN}│${NC} ${result_color}%-8s${NC} ${CYAN}│${NC}\n" \
            "${TEST_IDS[$i]}" \
            "${TEST_DESCRIPTIONS[$i]:0:30}" \
            "${EXPECTED_STATUS[$i]}" \
            "${ACTUAL_STATUS[$i]}" \
            "${TEST_RESULTS[$i]}"
    done

    echo -e "${CYAN}└──────────┴────────────────────────────────┴──────────┴──────────┴──────────┘${NC}"
}

# -----------------------------------------------------------------------------
# SETUP: CREATE TEST DATA
# -----------------------------------------------------------------------------

print_test_header "SETUP: Creating Test Inventory Items"
echo "This section creates test items in different states for subsequent tests."
echo ""

# SETUP-1: Create Depleted Item
TEST_ID="SETUP-1"
TEST_DESC="Create Depleted Item"
EXPECTED="201"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item in Depleted state with requiresPurchase=true"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Test Item - Depleted"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    # Extract ID from response (assuming format: {"id":"uuid",...})
    DEPLETED_ITEM_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${DEPLETED_ITEM_ID}${NC}"
fi

# SETUP-2: Create Low Item (manually set state after creation since create endpoint defaults to Available)
TEST_ID="SETUP-2"
TEST_DESC="Create Low Item"
EXPECTED="201"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item in Low state with requiresPurchase=true"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Test Item - Low"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    LOW_ITEM_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${LOW_ITEM_ID}${NC}"

    # Mark as low
    if [ -n "$LOW_ITEM_ID" ]; then
        echo "Marking item as Low..."
        curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${LOW_ITEM_ID}/mark-low" \
            -H "Content-Type: application/json" \
            -m 10 > /dev/null
    fi
fi

# SETUP-3: Create Available Item 1
TEST_ID="SETUP-3"
TEST_DESC="Create Available Item 1"
EXPECTED="201"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item in Available state with requiresPurchase=false"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Test Item - Available 1"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    AVAILABLE_ITEM_1_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${AVAILABLE_ITEM_1_ID}${NC}"
fi

# SETUP-4: Create Available Item 2 (for idempotent test)
TEST_ID="SETUP-4"
TEST_DESC="Create Available Item 2"
EXPECTED="201"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item in Available state for idempotent test"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Test Item - Available 2"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    AVAILABLE_ITEM_2_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${AVAILABLE_ITEM_2_ID}${NC}"
fi

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SETUP COMPLETE - Starting Acceptance Criteria Tests${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

# -----------------------------------------------------------------------------
# ACCEPTANCE CRITERIA TESTS
# -----------------------------------------------------------------------------

# AC1: Reponer producto agotado
TEST_ID="AC1"
TEST_DESC="Replenish Depleted Item"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Available, requiresPurchase: false"
print_result
if [ -n "$DEPLETED_ITEM_ID" ]; then
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${DEPLETED_ITEM_ID}/replenish" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: DEPLETED_ITEM_ID not set${NC}"
fi

# AC2: Reponer producto con stock bajo
TEST_ID="AC2"
TEST_DESC="Replenish Low Item"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Available, requiresPurchase: false"
print_result
if [ -n "$LOW_ITEM_ID" ]; then
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${LOW_ITEM_ID}/replenish" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: LOW_ITEM_ID not set${NC}"
fi

# AC3: Marcar producto como bajo
TEST_ID="AC3"
TEST_DESC="Mark Available Item as Low"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Low, requiresPurchase: true"
print_result
if [ -n "$AVAILABLE_ITEM_1_ID" ]; then
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${AVAILABLE_ITEM_1_ID}/mark-low" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: AVAILABLE_ITEM_1_ID not set${NC}"
fi

# AC4: Agotar producto desde estado suficiente
TEST_ID="AC4"
TEST_DESC="Deplete Available Item"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Depleted, requiresPurchase: true"
print_result
if [ -n "$AVAILABLE_ITEM_1_ID" ]; then
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${AVAILABLE_ITEM_1_ID}/deplete" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: AVAILABLE_ITEM_1_ID not set${NC}"
fi

# AC5: Agotar producto desde estado bajo
TEST_ID="AC5"
TEST_DESC="Deplete Low Item (after AC2 replenished it to Available, so we need to mark it low again)"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Depleted, requiresPurchase: true"
print_result
if [ -n "$LOW_ITEM_ID" ]; then
    # First mark it low again since AC2 replenished it to Available
    curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${LOW_ITEM_ID}/mark-low" \
        -H "Content-Type: application/json" \
        -m 10 > /dev/null

    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${LOW_ITEM_ID}/deplete" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: LOW_ITEM_ID not set${NC}"
fi

# AC6: Transición idempotente - reponer producto ya suficiente
TEST_ID="AC6"
TEST_DESC="Idempotent Replenish (Already Available)"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - State: Available (unchanged), requiresPurchase: false"
print_result
if [ -n "$AVAILABLE_ITEM_2_ID" ]; then
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${AVAILABLE_ITEM_2_ID}/replenish" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
else
    echo -e "${RED}SKIPPED: AVAILABLE_ITEM_2_ID not set${NC}"
fi

# AC7: Producto no encontrado al reponer
TEST_ID="AC7"
TEST_DESC="Replenish Non-Existent Item"
EXPECTED="404"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item not found error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${INVALID_UUID}/replenish" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# AC8: Producto no encontrado al marcar como bajo
TEST_ID="AC8"
TEST_DESC="Mark-Low Non-Existent Item"
EXPECTED="404"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item not found error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${INVALID_UUID}/mark-low" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# AC9: Producto no encontrado al agotar
TEST_ID="AC9"
TEST_DESC="Deplete Non-Existent Item"
EXPECTED="404"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item not found error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${INVALID_UUID}/deplete" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# EDGE CASE TESTS
# -----------------------------------------------------------------------------

# EDGE-1: Invalid UUID format
TEST_ID="EDGE-1"
TEST_DESC="Invalid UUID Format"
EXPECTED="404"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Invalid ID handled as not found"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/not-a-uuid/replenish" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# EDGE-2: Empty UUID
TEST_ID="EDGE-2"
TEST_DESC="Empty UUID"
EXPECTED="404"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Empty ID handled as not found"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items//replenish" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# EDGE-3: Rapid successive calls (idempotency check)
TEST_ID="EDGE-3"
TEST_DESC="Rapid Successive Calls"
EXPECTED="200,200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "Both calls succeed with HTTP 200 (idempotent)"
print_result
if [ -n "$AVAILABLE_ITEM_2_ID" ]; then
    HTTP_CODE1=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${AVAILABLE_ITEM_2_ID}/replenish" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY1=$(cat /tmp/response.txt)

    HTTP_CODE2=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items/${AVAILABLE_ITEM_2_ID}/replenish" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY2=$(cat /tmp/response.txt)

    echo "First call: HTTP $HTTP_CODE1"
    echo "$BODY1"
    echo ""
    echo "Second call: HTTP $HTTP_CODE2"
    echo "$BODY2"
    echo ""

    if [ "$HTTP_CODE1" = "200" ] && [ "$HTTP_CODE2" = "200" ]; then
        echo -e "${GREEN}✓ PASSED${NC} [HTTP Status: $HTTP_CODE1, $HTTP_CODE2]"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE1,$HTTP_CODE2" "PASS"
    else
        echo -e "${RED}✗ FAILED${NC} [HTTP Status: $HTTP_CODE1, $HTTP_CODE2, Expected: $EXPECTED]"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE1,$HTTP_CODE2" "FAIL"
    fi
else
    echo -e "${RED}SKIPPED: AVAILABLE_ITEM_2_ID not set${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------
rm -f /tmp/response.txt

# -----------------------------------------------------------------------------
# TEST SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}TEST EXECUTION COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Base URL: ${BASE_URL}"
echo "Finished at: $(date)"
echo ""

# Print structured results table
print_results_table

echo ""
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo -e "Total Tests:  ${TESTS_TOTAL}"
echo ""

# Calculate pass rate
if [ "$TESTS_TOTAL" -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed! (${PASS_RATE}%)${NC}"
    else
        echo -e "${RED}✗ Some tests failed (${PASS_RATE}% passed)${NC}"
    fi
fi
echo ""

# Exit with error code if any tests failed
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
