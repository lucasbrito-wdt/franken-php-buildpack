#!/usr/bin/env bash
# Test the FrankenPHP Laravel Octane buildpack locally.

set -eo pipefail

BUILDPACK_DIR=$(cd "$(dirname "$0")/.."; pwd)
FIXTURE_DIR="$BUILDPACK_DIR/test/fixtures/simple-app"

echo "=== FrankenPHP Laravel Octane Buildpack Tests ==="
echo ""

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

# ──────────────────────────────────────────────────────────────────────────────
echo "--- Test 1: detect (Laravel Octane app) ---"

"$BUILDPACK_DIR/bin/detect" "$FIXTURE_DIR" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "detect exits 0 for Laravel Octane app"
else
  fail "detect should exit 0"
fi

OUTPUT=$("$BUILDPACK_DIR/bin/detect" "$FIXTURE_DIR" 2>/dev/null)
if echo "$OUTPUT" | grep -qi "octane\|frankenphp"; then
  pass "detect outputs FrankenPHP identifier"
else
  fail "detect should output FrankenPHP identifier, got: $OUTPUT"
fi

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 2: detect (non-Laravel app should fail) ---"

TEMP_DIR=$(mktemp -d)
echo '<?php echo "hello";' > "$TEMP_DIR/index.php"

"$BUILDPACK_DIR/bin/detect" "$TEMP_DIR" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  pass "detect exits non-zero for plain PHP app"
else
  fail "detect should exit non-zero for non-Laravel app"
fi

rm -rf "$TEMP_DIR"

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 3: detect (Laravel without Octane should fail) ---"

TEMP_DIR=$(mktemp -d)
touch "$TEMP_DIR/artisan"
echo '{"require":{"php":">=8.2","laravel/framework":"^11.0"}}' > "$TEMP_DIR/composer.json"

"$BUILDPACK_DIR/bin/detect" "$TEMP_DIR" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  pass "detect exits non-zero for Laravel without Octane"
else
  fail "detect should exit non-zero for Laravel without Octane"
fi

rm -rf "$TEMP_DIR"

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 4: detect (config/octane.php fallback) ---"

TEMP_DIR=$(mktemp -d)
touch "$TEMP_DIR/artisan"
echo '{"require":{"php":">=8.2"}}' > "$TEMP_DIR/composer.json"
mkdir -p "$TEMP_DIR/config"
echo '<?php return ["server"=>"frankenphp"];' > "$TEMP_DIR/config/octane.php"

"$BUILDPACK_DIR/bin/detect" "$TEMP_DIR" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "detect succeeds with config/octane.php fallback"
else
  fail "detect should succeed when config/octane.php exists"
fi

rm -rf "$TEMP_DIR"

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 5: release output ---"

OUTPUT=$("$BUILDPACK_DIR/bin/release" "$FIXTURE_DIR")
if echo "$OUTPUT" | grep -q "start-octane"; then
  pass "release defines web process with start-octane"
else
  fail "release should define start-octane, got: $OUTPUT"
fi

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 6: common.sh functions ---"

source "$BUILDPACK_DIR/bin/util/common.sh"

TEMP_ENV=$(mktemp -d)
echo "latest" > "$TEMP_ENV/FRANKENPHP_VERSION"
echo "4" > "$TEMP_ENV/OCTANE_WORKERS"

export_env_dir "$TEMP_ENV"
if [ "$FRANKENPHP_VERSION" = "latest" ] && [ "$OCTANE_WORKERS" = "4" ]; then
  pass "export_env_dir reads env vars correctly"
else
  fail "export_env_dir failed: FRANKENPHP_VERSION=$FRANKENPHP_VERSION, OCTANE_WORKERS=$OCTANE_WORKERS"
fi

rm -rf "$TEMP_ENV"

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
