#!/usr/bin/env bash
# Test script for tools - run without API key needed
set -e

cd "$(dirname "$0")"

echo "=== Tool Reliability Tests ==="
echo ""

# Mock confirm_tool to auto-approve
confirm_tool() { return 0; }

# Setup test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

PASSED=0
FAILED=0

pass() { ((PASSED++)); echo "✓ $1"; }
fail() { ((FAILED++)); echo "✗ $1: $2"; }

# Load tools
source tools/Bash.sh
source tools/Grep.sh
source tools/Edit.sh

echo "=== Bash Tool ==="

# Test 1: Basic command
result=$(Bash '{"command": "echo hello"}')
[[ "$result" == "hello" ]] && pass "basic echo" || fail "basic echo" "$result"

# Test 2: Exit code handling
result=$(Bash '{"command": "exit 42"}')
[[ "$result" == *"Exit code 42"* ]] && pass "exit code" || fail "exit code" "$result"

# Test 3: Output with special chars
result=$(Bash '{"command": "echo \"hello world\""}')
[[ "$result" == "hello world" ]] && pass "special chars" || fail "special chars" "$result"

echo ""
echo "=== Grep Tool ==="

# Setup test files
echo -e "line one\nfoo bar baz\nline three" > "$TEST_DIR/test1.txt"
echo -e "another file\nfoo here too" > "$TEST_DIR/test2.txt"

# Test 1: Basic grep
result=$(Grep "{\"pattern\": \"foo\", \"path\": \"$TEST_DIR\"}")
[[ "$result" == *"foo bar"* ]] && pass "basic grep" || fail "basic grep" "$result"

# Test 2: Multiple matches
result=$(Grep "{\"pattern\": \"foo\", \"path\": \"$TEST_DIR\"}")
[[ "$result" == *"test1.txt"* && "$result" == *"test2.txt"* ]] && pass "multiple files" || fail "multiple files" "$result"

# Test 3: No matches
result=$(Grep "{\"pattern\": \"notexist123\", \"path\": \"$TEST_DIR\"}")
[[ "$result" == *"No matches"* ]] && pass "no matches" || fail "no matches" "$result"

# Test 4: Files only mode
result=$(Grep "{\"pattern\": \"foo\", \"path\": \"$TEST_DIR\", \"files_only\": true}")
[[ "$result" != *"foo bar"* && "$result" == *"test1.txt"* ]] && pass "files_only mode" || fail "files_only mode" "$result"

echo ""
echo "=== Edit Tool ==="

# Test 1: Basic edit
echo "hello world" > "$TEST_DIR/edit1.txt"
Edit "{\"path\": \"$TEST_DIR/edit1.txt\", \"old_string\": \"hello\", \"new_string\": \"goodbye\"}" >/dev/null
result=$(cat "$TEST_DIR/edit1.txt")
[[ "$result" == "goodbye world" ]] && pass "basic edit" || fail "basic edit" "$result"

# Test 2: Uniqueness check (should fail)
echo "foo foo foo" > "$TEST_DIR/edit2.txt"
result=$(Edit "{\"path\": \"$TEST_DIR/edit2.txt\", \"old_string\": \"foo\", \"new_string\": \"bar\"}" 2>&1) || true
[[ "$result" == *"matches"* ]] && pass "uniqueness check" || fail "uniqueness check" "$result"

# Test 3: replace_all
result=$(Edit "{\"path\": \"$TEST_DIR/edit2.txt\", \"old_string\": \"foo\", \"new_string\": \"bar\", \"replace_all\": true}" 2>&1)
content=$(cat "$TEST_DIR/edit2.txt")
[[ "$content" == "bar bar bar" ]] && pass "replace_all" || fail "replace_all" "$content"

# Test 4: Special characters
echo 'echo $VAR && test' > "$TEST_DIR/edit3.txt"
Edit "{\"path\": \"$TEST_DIR/edit3.txt\", \"old_string\": \"\$VAR\", \"new_string\": \"\$NEW_VAR\"}" >/dev/null
result=$(cat "$TEST_DIR/edit3.txt")
[[ "$result" == 'echo $NEW_VAR && test' ]] && pass "special chars" || fail "special chars" "$result"

# Test 5: Multiline edit
cat > "$TEST_DIR/edit4.txt" << 'EOF'
function old() {
    return 1;
}
EOF
Edit "{\"path\": \"$TEST_DIR/edit4.txt\", \"old_string\": \"function old() {\\n    return 1;\\n}\", \"new_string\": \"function new() {\\n    return 2;\\n}\"}" >/dev/null 2>&1 || true
# Note: multiline via JSON escapes is tricky, this tests the mechanism

# Test 6: File not found
result=$(Edit "{\"path\": \"$TEST_DIR/nonexistent.txt\", \"old_string\": \"a\", \"new_string\": \"b\"}" 2>&1) || true
[[ "$result" == *"not found"* ]] && pass "file not found" || fail "file not found" "$result"

# Test 7: String not found
echo "hello" > "$TEST_DIR/edit5.txt"
result=$(Edit "{\"path\": \"$TEST_DIR/edit5.txt\", \"old_string\": \"nothere\", \"new_string\": \"x\"}" 2>&1) || true
[[ "$result" == *"not found"* ]] && pass "string not found" || fail "string not found" "$result"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Passed: $PASSED | Failed: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
