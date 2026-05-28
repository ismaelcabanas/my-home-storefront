#!/bin/bash
# =============================================================================
# API Test Script
# Generated for: Create Inventory Item API
# =============================================================================
#
# Usage: ./scripts/test-api.sh [BASE_URL]
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
# │ SUCCESS TESTS (HTTP 201)                                                    │
# ├─────────┬────────────────────────────────────────┬──────────────────────────┤
# │ Test ID │ Description                            │ Input Name               │
# ├─────────┼────────────────────────────────────────┼──────────────────────────┤
# │ AC1     │ Create item with valid name            │ "Leche"                  │
# │ AC1.1   │ Create item with long name             │ "Aceite de oliva virgen" │
# │ AC1.2   │ Create item with unicode characters    │ "Café ☕"                 │
# └─────────┴────────────────────────────────────────┴──────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ VALIDATION ERROR TESTS (HTTP 400)                                           │
# ├─────────┬────────────────────────────────────────┬──────────────────────────┤
# │ Test ID │ Description                            │ Input Name               │
# ├─────────┼────────────────────────────────────────┼──────────────────────────┤
# │ AC2     │ Empty name                             │ ""                       │
# │ AC2.1   │ Missing name field                     │ (no name field)          │
# │ AC2.2   │ Whitespace-only name                   │ "   "                    │
# │ AC2.3   │ Empty JSON body                        │ {}                       │
# └─────────┴────────────────────────────────────────┴──────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ EDGE CASE TESTS                                                             │
# ├─────────┬────────────────────────────────────────┬──────────────────────────┤
# │ Test ID │ Description                            │ Expected HTTP            │
# ├─────────┼────────────────────────────────────────┼──────────────────────────┤
# │ EDGE1   │ Name with leading/trailing spaces      │ 201 (trimmed)            │
# │ EDGE2   │ Single character name                  │ 201                      │
# │ EDGE3   │ Name with special characters           │ 201                      │
# └─────────┴────────────────────────────────────────┴──────────────────────────┘
#
# =============================================================================
#
# EXPECTED RESPONSE FORMATS
# =============================================================================
#
# Success (201):
# {
#   "id": "<UUID>",
#   "name": "<trimmed-name>",
#   "state": "Available",
#   "requiresPurchase": false,
#   "createdAt": "<ISO-8601-timestamp>"
# }
#
# Error (400):
# {
#   "error": {
#     "type": "InvalidRequest",
#     "description": "El nombre del producto es obligatorio",
#     "params": {}
#   }
# }
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
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

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
    echo -e "${BLUE}TEST: $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_expected() {
    echo -e "${YELLOW}Expected: $1${NC}"
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
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo ""
}

# Print final results table
print_results_table() {
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                         TEST RESULTS SUMMARY                                │${NC}"
    echo -e "${CYAN}├──────────┬────────────────────────────────┬──────────┬──────────┬──────────┤${NC}"
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
# SCRIPT START
# -----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    CREATE INVENTORY ITEM API - TEST SUITE                     ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Base URL: ${BASE_URL}"
echo "Started at: $(date)"
echo ""

# =============================================================================
# SUCCESS TESTS (HTTP 201)
# =============================================================================

# -----------------------------------------------------------------------------
# AC1: Create item with valid name "Leche"
# -----------------------------------------------------------------------------
TEST_ID="AC1"
TEST_DESC="Create item with valid name"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with id, name='Leche', state='Available', requiresPurchase=false"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Leche"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# AC1.1: Create item with longer name
# -----------------------------------------------------------------------------
TEST_ID="AC1.1"
TEST_DESC="Create item with long name"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Aceite de oliva virgen extra"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# AC1.2: Create item with unicode/emoji characters
# -----------------------------------------------------------------------------
TEST_ID="AC1.2"
TEST_DESC="Create item with unicode chars"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Café ☕"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# =============================================================================
# VALIDATION ERROR TESTS (HTTP 400)
# =============================================================================

# -----------------------------------------------------------------------------
# AC2: Empty name string
# -----------------------------------------------------------------------------
TEST_ID="AC2"
TEST_DESC="Empty name rejected"
EXPECTED="400"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with error: 'El nombre del producto es obligatorio'"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": ""}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# AC2.1: Missing name field entirely
# -----------------------------------------------------------------------------
TEST_ID="AC2.1"
TEST_DESC="Missing name field rejected"
EXPECTED="400"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with error: 'El nombre del producto es obligatorio'"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"other": "field"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# AC2.2: Whitespace-only name
# -----------------------------------------------------------------------------
TEST_ID="AC2.2"
TEST_DESC="Whitespace-only name rejected"
EXPECTED="400"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with error: 'El nombre del producto es obligatorio'"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "   "}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# AC2.3: Empty JSON body
# -----------------------------------------------------------------------------
TEST_ID="AC2.3"
TEST_DESC="Empty JSON body rejected"
EXPECTED="400"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with error: 'El nombre del producto es obligatorio'"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

# -----------------------------------------------------------------------------
# EDGE1: Name with leading/trailing spaces (should be trimmed)
# -----------------------------------------------------------------------------
TEST_ID="EDGE1"
TEST_DESC="Name with spaces is trimmed"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED with trimmed name"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "  Pan  "}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# EDGE2: Single character name
# -----------------------------------------------------------------------------
TEST_ID="EDGE2"
TEST_DESC="Single character name"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "X"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

# -----------------------------------------------------------------------------
# EDGE3: Name with special characters
# -----------------------------------------------------------------------------
TEST_ID="EDGE3"
TEST_DESC="Name with special characters"
EXPECTED="201"
print_test_header "$TEST_ID: $TEST_DESC"
print_expected "HTTP $EXPECTED"
print_result
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "${BASE_URL}/api/inventory/items" \
    -H "Content-Type: application/json" \
    -m 10 \
    -d '{"name": "Tomate (kg) - 2.50€/unidad"}')
BODY=$(cat /tmp/response.txt)
check_result "$TEST_ID" "$TEST_DESC" "$EXPECTED" "$HTTP_CODE" "$BODY"

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
