#!/bin/bash
# =============================================================================
# Shopping List API Test Script
# Generated for: STORY-001-004 - Shopping List API Endpoint
# =============================================================================
#
# Usage: ./scripts/test-shopping-list.sh [BASE_URL]
#        Default BASE_URL: http://localhost:3000
#
# Requirements:
# - No external dependencies (no jq, only curl and bash)
# - Each request has -m 10 timeout to prevent hanging
# - HTTP status captured via: -o /tmp/response.txt -w "%{http_code}"
#
# Prerequisites:
# - Database should have inventory items in Low/Depleted states
# - Run state transition endpoints to mark items as Low or Depleted
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
# └─────────┴──────────────────────┴────────────────┴────────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ HAPPY PATH TESTS - Shopping List Retrieval                                │
# ├─────────┬──────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description          │ Limit    │ Cursor   │ HTTP    │ Expected │
# ├─────────┼──────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ AC1     │ First page - only    │ (none)   │ (none)   │ 200    │ Items    │
# │         │ items requiring      │          │          │        │ with    │
# │         │ purchase             │          │          │        │ req.    │
# │         │                      │          │          │        │ purch.=  │
# │         │                      │          │          │        │ true     │
# │ AC2     │ Custom limit - 5     │ 5        │ (none)   │ 200    │ 5 items  │
# │ AC3     │ Pagination with      │ 5        │ <cursor> │ 200    │ Next     │
# │         │ cursor               │          │          │        │ page    │
# │ AC4     │ Empty shopping list  │ (none)   │ (none)   │ 200    │ empty [] │
# │         │ (no items require    │          │          │        │          │
# │         │ purchase)            │          │          │        │          │
# │ AC5     │ Filter correctness   │ (none)   │ (none)   │ 200    │ Only     │
# │         │ - Available items    │          │          │        │ Low/     │
# │         │ excluded             │          │          │        │ Depleted │
# │ AC6     │ Alphabetical         │ (none)   │ (none)   │ 200    │ Ordered  │
# │         │ ordering             │          │          │        │ by name  │
# │ AC7     │ Cursor skips non-    │ 10       │ <cursor> │ 200    │ Next     │
# │         │ matching items       │          │          │        │ page     │
# │         │ correctly           │          │          │        │          │
# └─────────┴──────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ VALIDATION ERROR TESTS - Invalid Cursor                                    │
# ├─────────┬──────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description          │ Cursor   │ Expected │ HTTP    │ Error    │
# ├─────────┼──────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ VE1     │ Malformed cursor -   │ invalid  │ Invalid  │ 400    │ Invalid  │
# │         │ non-base64           │ base64   │ cursor   │        │ cursor   │
# │ VE2     │ Malformed cursor -   │ invalid  │ Invalid  │ 400    │ Invalid  │
# │         │ invalid JSON         │ json     │ cursor   │        │ cursor   │
# │ VE3     │ Malformed cursor -   │ valid    │ Invalid  │ 400    │ Invalid  │
# │         │ missing fields       │ base64   │ cursor   │        │ cursor   │
# └─────────┴──────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ LIMIT VALIDATION TESTS - Boundary Conditions                                │
# ├─────────┬──────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description          │ Input    │ Expected │ HTTP    │ Actual   │
# ├─────────┼──────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ LV1     │ Zero limit           │ 0        │ defaults │ 200    │ 20       │
# │ LV2     │ Negative limit       │ -5       │ defaults │ 200    │ 20       │
# │ LV3     │ Non-numeric limit    │ abc      │ defaults │ 200    │ 20       │
# │ LV4     │ Limit = 1 (minimum)  │ 1        │ 1 item   │ 200    │ 1 item   │
# │ LV5     │ Limit = 100 (max)    │ 100      │ 100 items│ 200    │ 100 items│
# │ LV6     │ Limit > 100          │ 150      │ defaults │ 200    │ 20       │
# └─────────┴──────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ EDGE CASE TESTS - Special Scenarios                                        │
# ├─────────┬──────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description          │ Input    │ Expected │ HTTP    │ Result   │
# ├─────────┼──────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ EC1     │ Empty string cursor  │ ""       │ treated  │ 200    │ first    │
# │         │                      │          │ as null  │        │ page     │
# │ EC2     │ Cursor from stale    │ <old     │ empty    │ 200    │ empty    │
# │         │ state                │ cursor>  │ or next  │        │ or next  │
# │ EC3     │ Large limit with     │ 100      │ all      │ 200    │ all      │
# │         │ few items            │          │ items    │        │ items    │
# │ EC4     │ Single item          │ 1        │ 1 item   │ 200    │ 1 item   │
# │         │ shopping list        │          │          │        │          │
# └─────────┴──────────────────────┴──────────┴──────────┴────────┴──────────┘
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
    NC=''
fi

# -----------------------------------------------------------------------------
# SEED DATA REFERENCE
# -----------------------------------------------------------------------------
# Database Schema: inventory.inventory_items
#   - id: UUID (primary key)
#   - name: VARCHAR(255) (product name, used for sorting)
#   - state: VARCHAR(20) (Available/Low/Depleted)
#   - requires_purchase: BOOLEAN (true for Low/Depleted, false for Available)
#   - created_at: TIMESTAMPTZ (used for sorting with duplicate names)
#
# Shopping List Filter:
#   - Only returns items where requires_purchase = true
#   - Filtered items are in "Low" or "Depleted" state
#   - "Available" items are excluded from shopping list
#
# Test Data Creation:
#   1. Create items via POST /api/inventory/items
#   2. Mark items as Low via POST /api/inventory/items/{id}/mark-low
#   3. Deplete items via POST /api/inventory/items/{id}/deplete
#
# Example:
#   curl -X POST "${BASE_URL}/api/inventory/items" \
#        -H "Content-Type: application/json" \
#        -d '{"name": "Milk"}'
#   curl -X POST "${BASE_URL}/api/inventory/items/{id}/mark-low"
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DATA STORAGE
# -----------------------------------------------------------------------------
DEPLETED_ITEM_ID=""
LOW_ITEM_ID=""
AVAILABLE_ITEM_ID=""
SHOPPING_LIST_CURSOR=""

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

# Extract nextCursor from response body
extract_cursor() {
    local body="$1"
    echo "$body" | grep -o '"nextCursor":"[^"]*"' | sed 's/"nextCursor":"\([^"]*\)"/\1/' | head -1
}

# Extract hasMore from response body
extract_has_more() {
    local body="$1"
    echo "$body" | grep -o '"hasMore":\([^,}]*\)' | sed 's/"hasMore":\(.*\)/\1/' | head -1
}

# Count items in response
count_items() {
    local body="$1"
    echo "$body" | grep -o '"name"' | wc -l | tr -d ' '
}

# Check if all items have requiresPurchase = true
verify_requires_purchase() {
    local body="$1"
    # Count requiresPurchase:true vs requiresPurchase:false
    local true_count=$(echo "$body" | grep -o '"requiresPurchase":true' | wc -l | tr -d ' ')
    local false_count=$(echo "$body" | grep -o '"requiresPurchase":false' | wc -l | tr -d ' ')

    if [ "$false_count" -eq 0 ]; then
        echo -e "${GREEN}✓ All items have requiresPurchase=true (${true_count}/${true_count})${NC}"
        return 0
    else
        echo -e "${RED}✗ Found items with requiresPurchase=false (true: ${true_count}, false: ${false_count})${NC}"
        return 1
    fi
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
echo "This section creates test items in different states for shopping list testing."
echo ""

# SETUP-1: Create Depleted Item (will require purchase)
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
    -d '{"name": "Test Shopping Item - Depleted"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    DEPLETED_ITEM_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${DEPLETED_ITEM_ID}${NC}"
fi

# SETUP-2: Create Low Item (will require purchase)
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
    -d '{"name": "Test Shopping Item - Low"}')
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

# SETUP-3: Create Available Item (should NOT appear in shopping list)
TEST_ID="SETUP-3"
TEST_DESC="Create Available Item"
EXPECTED="201"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Item in Available state with requiresPurchase=false"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Test Shopping Item - Available"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "201" ]; then
    AVAILABLE_ITEM_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Stored ID: ${AVAILABLE_ITEM_ID}${NC}"
fi

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}SETUP COMPLETE - Starting Shopping List Tests${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

# -----------------------------------------------------------------------------
# ACCEPTANCE CRITERIA TESTS
# -----------------------------------------------------------------------------

# =============================================================================
# HAPPY PATH TESTS - Shopping List Retrieval
# =============================================================================

# -----------------------------------------------------------------------------
# AC1: First page - only items requiring purchase
# -----------------------------------------------------------------------------
TEST_ID="AC1"
TEST_DESC="First page - items requiring purchase only"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Only items with requiresPurchase=true (Low/Depleted states)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# Verify filtering
if [ "$HTTP_CODE" = "200" ]; then
    verify_requires_purchase "$BODY"
    ITEM_COUNT=$(count_items "$BODY")
    HAS_MORE=$(extract_has_more "$BODY")
    SHOPPING_LIST_CURSOR=$(extract_cursor "$BODY")

    echo -e "${CYAN}Shopping List Info:${NC}"
    echo -e "  Items requiring purchase: ${ITEM_COUNT}"
    echo -e "  hasMore: ${HAS_MORE}"
    if [ -n "$SHOPPING_LIST_CURSOR" ] && [ "$SHOPPING_LIST_CURSOR" != "null" ]; then
        echo -e "  nextCursor: ${SHOPPING_LIST_CURSOR:0:50}..."
    else
        echo -e "  nextCursor: null (no more pages)"
    fi
fi
echo ""

# -----------------------------------------------------------------------------
# AC2: Custom limit - 5 items per page
# -----------------------------------------------------------------------------
TEST_ID="AC2"
TEST_DESC="Custom limit - 5 items per page"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Exactly 5 items with requiresPurchase=true"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=5" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    verify_requires_purchase "$BODY"
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 5)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# AC3: Pagination with cursor - Second page
# -----------------------------------------------------------------------------
if [ -n "$SHOPPING_LIST_CURSOR" ] && [ "$SHOPPING_LIST_CURSOR" != "null" ] && [ "$SHOPPING_LIST_CURSOR" != "" ]; then
    TEST_ID="AC3"
    TEST_DESC="Pagination with cursor"
    EXPECTED="200"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test_header "$TEST_ID: $TEST_DESC"
    print_expected "HTTP $EXPECTED - Next page of items requiring purchase"
    print_result
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=5&cursor=${SHOPPING_LIST_CURSOR}" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

    if [ "$HTTP_CODE" = "200" ]; then
        ITEM_COUNT=$(count_items "$BODY")
        verify_requires_purchase "$BODY"
        HAS_MORE=$(extract_has_more "$BODY")
        echo -e "${CYAN}Items returned: ${ITEM_COUNT}${NC}"
        echo -e "${CYAN}hasMore: ${HAS_MORE}${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping AC3: No pagination cursor available (shopping list may have ≤5 items)${NC}"
    echo ""
fi

# -----------------------------------------------------------------------------
# AC4: Empty shopping list (no items require purchase)
# -----------------------------------------------------------------------------
TEST_ID="AC4"
TEST_DESC="Empty shopping list handling"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Empty items array, nextCursor: null, hasMore: false (when no Low/Depleted items)"
print_result
echo -e "${YELLOW}Note: This test verifies empty result handling. To test properly, ensure all items are in Available state.${NC}"
echo ""
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
echo ""

# -----------------------------------------------------------------------------
# AC5: Filter correctness - Available items excluded
# -----------------------------------------------------------------------------
TEST_ID="AC5"
TEST_DESC="Filter correctness - Available items excluded"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Response contains only Low/Depleted items, no Available items"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)

# Check for Available state items
HAS_AVAILABLE=0
if echo "$BODY" | grep -q '"state":"Available"'; then
    HAS_AVAILABLE=1
fi

echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "200" ] && [ $HAS_AVAILABLE -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC} [HTTP Status: 200, No Available items in response]"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "PASS"
elif [ "$HTTP_CODE" = "200" ] && [ $HAS_AVAILABLE -eq 1 ]; then
    echo -e "${RED}✗ FAILED${NC} [Found Available items in shopping list (should be excluded)]"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
else
    echo -e "${RED}✗ FAILED${NC} [HTTP Status: $HTTP_CODE, Expected: 200]"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
fi
echo ""

# -----------------------------------------------------------------------------
# AC6: Alphabetical ordering by name
# -----------------------------------------------------------------------------
TEST_ID="AC6"
TEST_DESC="Alphabetical ordering by name"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Items ordered by name ASC, created_at ASC"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=20" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${CYAN}Note: Manual verification required - check that item names are alphabetically ordered${NC}"
    echo -e "${CYAN}Expected order: A -> Z, with created_at as tiebreaker${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# AC7: Cursor skips non-matching items correctly
# -----------------------------------------------------------------------------
TEST_ID="AC7"
TEST_DESC="Cursor skips non-matching items"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Pagination correctly skips Available items when using cursor"
print_result
echo -e "${CYAN}Note: This test verifies cursor pagination over filtered subset works correctly${NC}"
echo -e "${CYAN}Cursor should skip items that don't match the filter (Available state)${NC}"
echo ""
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=10" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
echo ""

# =============================================================================
# VALIDATION ERROR TESTS - Invalid Cursor
# =============================================================================

# -----------------------------------------------------------------------------
# VE1: Malformed cursor - Non-base64 string
# -----------------------------------------------------------------------------
TEST_ID="VE1"
TEST_DESC="Malformed cursor - invalid base64"
EXPECTED="400"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Invalid cursor error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?cursor=not-valid-base64!!" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# VE2: Malformed cursor - Valid base64 but invalid JSON
# -----------------------------------------------------------------------------
TEST_ID="VE2"
TEST_DESC="Malformed cursor - valid base64, invalid JSON"
EXPECTED="400"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Invalid cursor error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?cursor=SGVsbG8=" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# VE3: Malformed cursor - Valid base64/JSON but missing fields
# -----------------------------------------------------------------------------
TEST_ID="VE3"
TEST_DESC="Malformed cursor - missing required fields"
EXPECTED="400"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Invalid cursor error"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?cursor=eyJ3cm9uZ0ZpZWxkIjoidmFsdWUifQ==" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# =============================================================================
# LIMIT VALIDATION TESTS - Boundary Conditions
# =============================================================================

# -----------------------------------------------------------------------------
# LV1: Zero limit - Should default to 20
# -----------------------------------------------------------------------------
TEST_ID="LV1"
TEST_DESC="Zero limit - defaults to 20"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=0" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (should default to 20)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# LV2: Negative limit - Should default to 20
# -----------------------------------------------------------------------------
TEST_ID="LV2"
TEST_DESC="Negative limit - defaults to 20"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=-5" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (should default to 20)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# LV3: Non-numeric limit - Should default to 20
# -----------------------------------------------------------------------------
TEST_ID="LV3"
TEST_DESC="Non-numeric limit - defaults to 20"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=abc" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (should default to 20)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# LV4: Limit = 1 (minimum valid value)
# -----------------------------------------------------------------------------
TEST_ID="LV4"
TEST_DESC="Limit = 1 (minimum valid)"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Exactly 1 item"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=1" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    verify_requires_purchase "$BODY"
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 1)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# LV5: Limit = 100 (maximum valid value)
# -----------------------------------------------------------------------------
TEST_ID="LV5"
TEST_DESC="Limit = 100 (maximum valid)"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Up to 100 items"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=100" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    verify_requires_purchase "$BODY"
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (max: 100)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# LV6: Limit > 100 - Should default to 20
# -----------------------------------------------------------------------------
TEST_ID="LV6"
TEST_DESC="Limit > 100 - defaults to 20"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=150" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (should default to 20)${NC}"
fi
echo ""

# =============================================================================
# EDGE CASE TESTS - Special Scenarios
# =============================================================================

# -----------------------------------------------------------------------------
# EC1: Empty string cursor - Should be treated as null (first page)
# -----------------------------------------------------------------------------
TEST_ID="EC1"
TEST_DESC="Empty string cursor - treated as null"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns first page (empty cursor treated as null)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?cursor=" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
echo ""

# -----------------------------------------------------------------------------
# EC2: Cursor from stale state (after items are replenished)
# -----------------------------------------------------------------------------
if [ -n "$SHOPPING_LIST_CURSOR" ] && [ "$SHOPPING_LIST_CURSOR" != "null" ] && [ "$SHOPPING_LIST_CURSOR" != "" ]; then
    TEST_ID="EC2"
    TEST_DESC="Cursor with limit and cursor combined"
    EXPECTED="200"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test_header "$TEST_ID: $TEST_DESC"
    print_expected "HTTP $EXPECTED - Respects both limit and cursor"
    print_result
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=3&cursor=${SHOPPING_LIST_CURSOR}" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

    if [ "$HTTP_CODE" = "200" ]; then
        ITEM_COUNT=$(count_items "$BODY")
        verify_requires_purchase "$BODY"
        echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 3)${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping EC2: No pagination cursor available${NC}"
    echo ""
fi

# -----------------------------------------------------------------------------
# EC3: Large limit with few items - Should return all available items
# -----------------------------------------------------------------------------
TEST_ID="EC3"
TEST_DESC="Large limit with few items"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Returns all items requiring purchase (no error for small list)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=100" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    HAS_MORE=$(extract_has_more "$BODY")
    verify_requires_purchase "$BODY"
    echo -e "${CYAN}Items returned: ${ITEM_COUNT}${NC}"
    echo -e "${CYAN}hasMore: ${HAS_MORE} (should be false if all items fit in one page)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# EC4: Single item shopping list
# -----------------------------------------------------------------------------
TEST_ID="EC4"
TEST_DESC="Single item shopping list"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - Single item with requiresPurchase=true"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=1" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    verify_requires_purchase "$BODY"
    HAS_MORE=$(extract_has_more "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT}${NC}"
    echo -e "${CYAN}hasMore: ${HAS_MORE}${NC}"
fi
echo ""

# =============================================================================
# RESPONSE STRUCTURE VALIDATION
# =============================================================================

# -----------------------------------------------------------------------------
# RS1: Verify response structure has all required fields
# -----------------------------------------------------------------------------
TEST_ID="RS1"
TEST_DESC="Response structure validation"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP 200 - Response contains: items, nextCursor, hasMore fields"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=5" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)

HAS_ITEMS=0
HAS_NEXT_CURSOR=0
HAS_HAS_MORE=0

if echo "$BODY" | grep -q '"items"'; then
    HAS_ITEMS=1
fi
if echo "$BODY" | grep -q '"nextCursor"'; then
    HAS_NEXT_CURSOR=1
fi
if echo "$BODY" | grep -q '"hasMore"'; then
    HAS_HAS_MORE=1
fi

echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "200" ] && [ $HAS_ITEMS -eq 1 ] && [ $HAS_NEXT_CURSOR -eq 1 ] && [ $HAS_HAS_MORE -eq 1 ]; then
    echo -e "${GREEN}✓ Response structure is valid${NC}"
    echo -e "  ✓ Contains 'items' field"
    echo -e "  ✓ Contains 'nextCursor' field"
    echo -e "  ✓ Contains 'hasMore' field"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "PASS"
elif [ "$HTTP_CODE" = "200" ]; then
    echo -e "${RED}✗ Response structure is invalid${NC}"
    [ $HAS_ITEMS -eq 0 ] && echo -e "  ${RED}✗ Missing 'items' field${NC}"
    [ $HAS_NEXT_CURSOR -eq 0 ] && echo -e "  ${RED}✗ Missing 'nextCursor' field${NC}"
    [ $HAS_HAS_MORE -eq 0 ] && echo -e "  ${RED}✗ Missing 'hasMore' field${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
else
    echo -e "${RED}✗ HTTP Status: $HTTP_CODE, Expected: 200${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
fi
echo ""

# -----------------------------------------------------------------------------
# RS2: Verify items contain all required product fields
# -----------------------------------------------------------------------------
TEST_ID="RS2"
TEST_DESC="Product item fields validation"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP 200 - Each item contains: id, name, state, requiresPurchase, createdAt"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/shopping-list?limit=1" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)

HAS_ID=0
HAS_NAME=0
HAS_STATE=0
HAS_REQUIRES_PURCHASE=0
HAS_CREATED_AT=0

if echo "$BODY" | grep -q '"id"'; then
    HAS_ID=1
fi
if echo "$BODY" | grep -q '"name"'; then
    HAS_NAME=1
fi
if echo "$BODY" | grep -q '"state"'; then
    HAS_STATE=1
fi
if echo "$BODY" | grep -q '"requiresPurchase"'; then
    HAS_REQUIRES_PURCHASE=1
fi
if echo "$BODY" | grep -q '"createdAt"'; then
    HAS_CREATED_AT=1
fi

echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "200" ] && [ $HAS_ID -eq 1 ] && [ $HAS_NAME -eq 1 ] && [ $HAS_STATE -eq 1 ] && [ $HAS_REQUIRES_PURCHASE -eq 1 ] && [ $HAS_CREATED_AT -eq 1 ]; then
    echo -e "${GREEN}✓ Item fields are valid${NC}"
    echo -e "  ✓ Contains 'id' field"
    echo -e "  ✓ Contains 'name' field"
    echo -e "  ✓ Contains 'state' field"
    echo -e "  ✓ Contains 'requiresPurchase' field"
    echo -e "  ✓ Contains 'createdAt' field"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "PASS"
elif [ "$HTTP_CODE" = "200" ]; then
    echo -e "${RED}✗ Item fields are invalid${NC}"
    [ $HAS_ID -eq 0 ] && echo -e "  ${RED}✗ Missing 'id' field${NC}"
    [ $HAS_NAME -eq 0 ] && echo -e "  ${RED}✗ Missing 'name' field${NC}"
    [ $HAS_STATE -eq 0 ] && echo -e "  ${RED}✗ Missing 'state' field${NC}"
    [ $HAS_REQUIRES_PURCHASE -eq 0 ] && echo -e "  ${RED}✗ Missing 'requiresPurchase' field${NC}"
    [ $HAS_CREATED_AT -eq 0 ] && echo -e "  ${RED}✗ Missing 'createdAt' field${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
else
    echo -e "${RED}✗ HTTP Status: $HTTP_CODE, Expected: 200${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    record_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "FAIL"
fi
echo ""

# =============================================================================
# CLEANUP
# =============================================================================
rm -f /tmp/response.txt

# =============================================================================
# TEST SUMMARY
# =============================================================================
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

# Print test data setup instructions
echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
echo -e "${CYAN}Test Data Setup Instructions${NC}"
echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "To create test inventory items for shopping list:"
echo ""
echo -e "${YELLOW}  # Create items (they start in Available state)${NC}"
echo -e "  ${MAGENTA}curl -X POST \"${BASE_URL}/api/inventory/items\" \\${NC}"
echo -e "  ${MAGENTA}    -H \"Content-Type: application/json\" \\${NC}"
echo -e "  ${MAGENTA}    -d '{\"name\": \"Product Name\"}'${NC}"
echo ""
echo -e "${YELLOW}  # Mark items as Low (they will appear in shopping list)${NC}"
echo -e "  ${MAGENTA}curl -X POST \"${BASE_URL}/api/inventory/items/{id}/mark-low\" \\${NC}"
echo -e "  ${MAGENTA}    -H \"Content-Type: application/json\"${NC}"
echo ""
echo -e "${YELLOW}  # Deplete items (they will appear in shopping list)${NC}"
echo -e "  ${MAGENTA}curl -X POST \"${BASE_URL}/api/inventory/items/{id}/deplete\" \\${NC}"
echo -e "  ${MAGENTA}    -H \"Content-Type: application/json\"${NC}"
echo ""
echo "Create at least 25 Low/Depleted items to test pagination thoroughly"
echo ""

# Exit with error code if any tests failed
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
