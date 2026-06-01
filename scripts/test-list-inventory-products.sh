#!/bin/bash
# =============================================================================
# API Test Script - List All Inventory Products
# Generated for: STORY-001-003 - List All Inventory Products with Cursor-Based Pagination
# =============================================================================
#
# Usage: ./scripts/test-list-inventory-products.sh [BASE_URL]
#        Default BASE_URL: http://localhost:3000
#
# Requirements:
# - No external dependencies (no jq, only curl and bash)
# - Each request has -m 10 timeout to prevent hanging
# - HTTP status captured via: -o /tmp/response.txt -w "%{http_code}"
#
# Prerequisites:
# - Database should have inventory items for pagination testing
# - Run POST /api/inventory/items first to create test data if needed
#
# =============================================================================
#
# TEST CASE OVERVIEW (Human-Reviewable)
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ HAPPY PATH TESTS - Pagination Scenarios                                      │
# ├─────────┬──────────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description               │ Limit    │ Cursor   │ HTTP    │ Expected │
# ├─────────┼──────────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ HP1     │ First page (no cursor)   │ (none)   │ (none)   │ 200    │ items +  │
# │         │                          │          │          │        │ hasMore  │
# │ HP2     │ Custom limit - 10 items  │ 10       │ (none)   │ 200    │ 10 items │
# │ HP3     │ Custom limit - 5 items  │ 5        │ (none)   │ 200    │ 5 items  │
# │ HP4     │ With cursor - page 2    │ 20       │ <cursor> │ 200    │ next     │
# │         │                          │          │          │        │ page    │
# │ HP5     │ Empty inventory          │ (none)   │ (none)   │ 200    │ empty [] │
# └─────────┴──────────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ VALIDATION ERROR TESTS - Invalid Input                                      │
# ├─────────┬──────────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description               │ Cursor   │ Expected │ HTTP    │ Error    │
# ├─────────┼──────────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ VE1     │ Malformed cursor -       │ invalid  │ Invalid  │ 400    │ Invalid  │
# │         │ non-base64               │ base64   │ cursor   │        │ cursor   │
# │ VE2     │ Malformed cursor -       │ invalid  │ Invalid  │ 400    │ Invalid  │
# │         │ invalid JSON             │ json     │ cursor   │        │ cursor   │
# │ VE3     │ Malformed cursor -       │ valid    │ Invalid  │ 400    │ Invalid  │
# │         │ missing fields          │ base64   │ cursor   │        │ cursor   │
# └─────────┴──────────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ LIMIT VALIDATION TESTS - Boundary Conditions                                │
# ├─────────┬──────────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description               │ Input    │ Expected │ HTTP    │ Actual   │
# ├─────────┼──────────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ LV1     │ Zero limit               │ 0        │ defaults │ 200    │ 20       │
# │ LV2     │ Negative limit           │ -5       │ defaults │ 200    │ 20       │
# │ LV3     │ Non-numeric limit        │ abc      │ defaults │ 200    │ 20       │
# │ LV4     │ Limit = 1 (minimum)      │ 1        │ 1 item   │ 200    │ 1 item   │
# │ LV5     │ Limit = 100 (maximum)    │ 100      │ 100 items│ 200    │ 100 items│
# │ LV6     │ Limit > 100              │ 150      │ defaults │ 200    │ 20       │
# └─────────┴──────────────────────────┴──────────┴──────────┴────────┴──────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ EDGE CASE TESTS - Special Scenarios                                        │
# ├─────────┬──────────────────────────┬──────────┬──────────┬────────┬──────────┤
# │ Test ID │ Description               │ Input    │ Expected │ HTTP    │ Result   │
# ├─────────┼──────────────────────────┼──────────┼──────────┼────────┼──────────┤
# │ EC1     │ Empty string cursor      │ ""       │ treated  │ 200    │ first   │
# │         │                          │          │ as null  │        │ page    │
# │ EC2     │ Cursor from deleted item │ <old     │ empty    │ 200    │ empty   │
# │         │                          │ cursor>  │ or next  │        │ or next │
# │ EC3     │ Large limit with few     │ 100      │ all      │ 200    │ all     │
# │         │ items                    │          │ items    │        │ items   │
# └─────────┴──────────────────────────┴──────────┴──────────┴────────┴──────────┘
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
#   - state: VARCHAR(20) (Available/Low/Depleted - returned in response)
#   - requires_purchase: BOOLEAN (derived from state)
#   - created_at: TIMESTAMPTZ (used for sorting with duplicate names)
#
# Note: This script assumes test data exists. To create test data:
#   curl -X POST "${BASE_URL}/api/inventory/items" \
#        -H "Content-Type: application/json" \
#        -d '{"name": "Product Name"}'
#
# Recommended test data (create in alphabetical order):
#   - "Apple", "Banana", "Carrot", "Dates", "Eggs"
#   - "Flour", "Grapes", "Honey", "Ice cream", "Juice"
#   - "Kiwi", "Lemon", "Milk", "Nuts", "Olive Oil"
#   - "Pasta", "Quinoa", "Rice", "Sugar", "Tomato"
# -----------------------------------------------------------------------------

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

# Store first page cursor for pagination tests
FIRST_PAGE_CURSOR=""

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
print_test_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST: ${NC}$1"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
}

print_expected() {
    echo -e "${YELLOW}Expected: ${NC}$1"
}

print_result() {
    echo -e "${GREEN}Response:${NC}"
}

# Record test result for final summary table
# Usage: record_result "Test ID" "Description" "Expected" "Actual" "PASS|FAIL"
record_result() {
    TEST_IDS+=("$1")
    TEST_DESCRIPTIONS+=("$2")
    EXPECTED_STATUS+=("$3")
    ACTUAL_STATUS+=("$4")
    TEST_RESULTS+=("$5")
}

# Check test result - called after each curl command
# Usage: check_result "Test ID" "Test Description" "Expected Status" "$HTTP_CODE" "$BODY"
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

# Extract nextCursor from response body (using grep for JSON parsing)
extract_cursor() {
    local body="$1"
    # Extract nextCursor value using grep/sed (no jq dependency)
    echo "$body" | grep -o '"nextCursor":"[^"]*"' | sed 's/"nextCursor":"\([^"]*\)"/\1/' | head -1
}

# Extract hasMore from response body
extract_has_more() {
    local body="$1"
    # Extract hasMore value using grep/sed
    echo "$body" | grep -o '"hasMore":\([^,}]*\)' | sed 's/"hasMore":\(.*\)/\1/' | head -1
}

# Count items in response
count_items() {
    local body="$1"
    # Count occurrences of "name": to estimate item count
    echo "$body" | grep -o '"name"' | wc -l | tr -d ' '
}

# Print final results table
print_results_table() {
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                            TEST RESULTS SUMMARY                                     │${NC}"
    echo -e "${CYAN}├──────────┬──────────────────────────────────────┬──────────┬──────────┬────────────┤${NC}"
    echo -e "${CYAN}│ Test ID  │ Description                          │ Expected │ Actual   │ Result     │${NC}"
    echo -e "${CYAN}├──────────┼──────────────────────────────────────┼──────────┼──────────┼────────────┤${NC}"

    for i in "${!TEST_IDS[@]}"; do
        local result_color="${GREEN}"
        if [ "${TEST_RESULTS[$i]}" = "FAIL" ]; then
            result_color="${RED}"
        fi
        printf "${CYAN}│${NC} %-8s ${CYAN}│${NC} %-36s ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-8s ${CYAN}│${NC} ${result_color}%-10s${NC} ${CYAN}│${NC}\n" \
            "${TEST_IDS[$i]}" \
            "${TEST_DESCRIPTIONS[$i]:0:36}" \
            "${EXPECTED_STATUS[$i]}" \
            "${ACTUAL_STATUS[$i]}" \
            "${TEST_RESULTS[$i]}"
    done

    echo -e "${CYAN}└──────────┴──────────────────────────────────────┴──────────┴──────────┴────────────┘${NC}"
}

# -----------------------------------------------------------------------------
# TEST CASES
# -----------------------------------------------------------------------------

# =============================================================================
# HAPPY PATH TESTS - Pagination Scenarios
# =============================================================================

# -----------------------------------------------------------------------------
# HP1: First page (no cursor, no limit) - Should return default 20 items
# -----------------------------------------------------------------------------
TEST_ID="HP1"
TEST_DESC="First page with default pagination"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - items array with nextCursor and hasMore fields"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# Store cursor for subsequent tests (if pagination is available)
if [ "$HTTP_CODE" = "200" ]; then
    FIRST_PAGE_CURSOR=$(extract_cursor "$BODY")
    HAS_MORE=$(extract_has_more "$BODY")
    ITEM_COUNT=$(count_items "$BODY")

    echo -e "${CYAN}Pagination Info:${NC}"
    echo -e "  Items returned: ${ITEM_COUNT}"
    echo -e "  hasMore: ${HAS_MORE}"
    if [ -n "$FIRST_PAGE_CURSOR" ] && [ "$FIRST_PAGE_CURSOR" != "null" ]; then
        echo -e "  nextCursor: ${FIRST_PAGE_CURSOR:0:50}..."
    else
        echo -e "  nextCursor: null (no more pages)"
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# HP2: Custom limit - 10 items per page
# -----------------------------------------------------------------------------
TEST_ID="HP2"
TEST_DESC="Custom limit - 10 items per page"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - exactly 10 items in response"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=10" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# Verify item count
if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 10)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# HP3: Custom limit - 5 items per page
# -----------------------------------------------------------------------------
TEST_ID="HP3"
TEST_DESC="Custom limit - 5 items per page"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - exactly 5 items in response"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=5" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# Verify item count
if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 5)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# HP4: Pagination with cursor - Second page
# -----------------------------------------------------------------------------
if [ -n "$FIRST_PAGE_CURSOR" ] && [ "$FIRST_PAGE_CURSOR" != "null" ] && [ "$FIRST_PAGE_CURSOR" != "" ]; then
    TEST_ID="HP4"
    TEST_DESC="Second page with cursor"
    EXPECTED="200"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test_header "$TEST_ID: $TEST_DESC"
    print_expected "HTTP $EXPECTED - items after first page"
    print_result
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=20&cursor=${FIRST_PAGE_CURSOR}" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

    # Verify pagination info
    if [ "$HTTP_CODE" = "200" ]; then
        ITEM_COUNT=$(count_items "$BODY")
        HAS_MORE=$(extract_has_more "$BODY")
        echo -e "${CYAN}Items returned: ${ITEM_COUNT}${NC}"
        echo -e "${CYAN}hasMore: ${HAS_MORE}${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping HP4: No pagination cursor available (inventory may have ≤20 items)${NC}"
    echo ""
fi

# -----------------------------------------------------------------------------
# HP5: Empty inventory (edge case - returns 200 with empty array)
# -----------------------------------------------------------------------------
TEST_ID="HP5"
TEST_DESC="Empty inventory handling"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED - empty items array, nextCursor: null, hasMore: false"
print_result
echo -e "${YELLOW}Note: This test assumes inventory has items. If empty, expect: {\"items\":[],\"nextCursor\":null,\"hasMore\":false}${NC}"
echo ""
echo -e "${CYAN}To test empty inventory, truncate the inventory_items table and re-run.${NC}"
echo ""

# =============================================================================
# VALIDATION ERROR TESTS - Invalid Input
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
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?cursor=not-valid-base64!!" \
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
# "SGVsbG8=" is "Hello" in base64, not valid JSON cursor structure
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?cursor=SGVsbG8=" \
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
print_expected "HTTP $EXPECTED - Invalid cursor error (empty name)"
print_result
# {"wrongField":"value"} in base64
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?cursor=eyJ3cm9uZ0ZpZWxkIjoidmFsdWUifQ==" \
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
print_expected "HTTP $EXPECTED - returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=0" \
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
print_expected "HTTP $EXPECTED - returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=-5" \
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
print_expected "HTTP $EXPECTED - returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=abc" \
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
print_expected "HTTP $EXPECTED - exactly 1 item"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=1" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
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
print_expected "HTTP $EXPECTED - up to 100 items"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=100" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
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
print_expected "HTTP $EXPECTED - returns up to 20 items (default behavior)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=150" \
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
print_expected "HTTP $EXPECTED - returns first page (empty cursor treated as null)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?cursor=" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"
echo ""

# -----------------------------------------------------------------------------
# EC2: Cursor with both limit parameters combined
# -----------------------------------------------------------------------------
if [ -n "$FIRST_PAGE_CURSOR" ] && [ "$FIRST_PAGE_CURSOR" != "null" ] && [ "$FIRST_PAGE_CURSOR" != "" ]; then
    TEST_ID="EC2"
    TEST_DESC="Pagination with limit and cursor combined"
    EXPECTED="200"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test_header "$TEST_ID: $TEST_DESC"
    print_expected "HTTP $EXPECTED - respects both limit and cursor"
    print_result
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=5&cursor=${FIRST_PAGE_CURSOR}" \
        -H "Content-Type: application/json" \
        -m 10)
    BODY=$(cat /tmp/response.txt)
    check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

    if [ "$HTTP_CODE" = "200" ]; then
        ITEM_COUNT=$(count_items "$BODY")
        echo -e "${CYAN}Items returned: ${ITEM_COUNT} (expected: 5)${NC}"
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
TEST_DESC="Large limit with few inventory items"
EXPECTED="200"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $200 - returns all available items (no error for small inventory)"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=100" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    ITEM_COUNT=$(count_items "$BODY")
    HAS_MORE=$(extract_has_more "$BODY")
    echo -e "${CYAN}Items returned: ${ITEM_COUNT}${NC}"
    echo -e "${CYAN}hasMore: ${HAS_MORE} (should be false if all items fit in one page)${NC}"
fi
echo ""

# =============================================================================
# ADDITIONAL VERIFICATION - Response Structure
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
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=5" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)

# Verify response structure
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
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X GET "${BASE_URL}/api/inventory/items?limit=1" \
    -H "Content-Type: application/json" \
    -m 10)
BODY=$(cat /tmp/response.txt)

# Verify item fields
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
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}TEST EXECUTION COMPLETE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
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

# Print test data creation instructions if no items were found
if [ "$TESTS_PASSED" -gt 0 ]; then
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Test Data Setup Instructions${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "To create test inventory items, run:"
    echo ""
    echo -e "${YELLOW}  # Create alphabetical test data${NC}"
    echo -e "  ${MAGENTA}curl -X POST \"${BASE_URL}/api/inventory/items\" \\${NC}"
    echo -e "  ${MAGENTA}    -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${MAGENTA}    -d '{\"name\": \"Apple\"}'${NC}"
    echo ""
    echo -e "  ${MAGENTA}curl -X POST \"${BASE_URL}/api/inventory/items\" \\${NC}"
    echo -e "  ${MAGENTA}    -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${MAGENTA}    -d '{\"name\": \"Banana\"}'${NC}"
    echo ""
    echo "Create at least 25 items to test pagination (default 20 per page)"
    echo ""
fi

# Exit with error code if any tests failed
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
