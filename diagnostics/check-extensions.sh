#!/usr/bin/env bash
# Script de diagnóstico para verificar extensões PHP em runtime
# Use: heroku run php diagnostics/check-extensions.php

echo "=== FrankenPHP Extensions Diagnostic ==="
echo ""

# Check if extensions directory exists
if [ -d "/app/.heroku/frankenphp/extensions" ]; then
    echo "✅ Extensions directory exists: /app/.heroku/frankenphp/extensions"
    echo ""
    echo "Files in extensions directory:"
    ls -lh /app/.heroku/frankenphp/extensions/ 2>/dev/null || echo "  (empty or no access)"
else
    echo "❌ Extensions directory NOT found: /app/.heroku/frankenphp/extensions"
fi

echo ""
echo "=== PHP Configuration ==="
php -i 2>/dev/null | grep -E "extension_dir|Configuration File|Loaded Configuration" || echo "  (unable to read php -i)"

echo ""
echo "=== PHP Loaded Extensions ==="
php -m 2>/dev/null | grep -E "mbstring|pcntl|posix|sockets" || echo "  Critical extensions NOT loaded"

echo ""
echo "=== PHP INI Scan Directory ==="
echo "PHP_INI_SCAN_DIR: $PHP_INI_SCAN_DIR"
if [ -d "$PHP_INI_SCAN_DIR" ]; then
    echo "✅ Directory exists"
    echo "INI files:"
    ls -lh "$PHP_INI_SCAN_DIR" || echo "  (unable to list)"
else
    echo "❌ PHP_INI_SCAN_DIR does not exist"
fi

echo ""
echo "=== heroku.ini Content (first 30 lines) ==="
if [ -f "$PHP_INI_SCAN_DIR/heroku.ini" ]; then
    head -30 "$PHP_INI_SCAN_DIR/heroku.ini"
else
    echo "❌ $PHP_INI_SCAN_DIR/heroku.ini NOT found"
fi

echo ""
echo "=== Test mb_split function ==="
php -r "echo 'Testing mb_split: '; var_dump(function_exists('mb_split')); if (function_exists('mb_split')) { echo 'Result: ' . implode(', ', mb_split('\\s+', 'hello world')) . PHP_EOL; }" 2>&1 || echo "  Failed to execute test"

echo ""
echo "=== ldd analysis of frankenphp binary ==="
ldd /app/.heroku/frankenphp/bin/frankenphp 2>&1 | head -10

echo ""
echo "Done! Compare output with expected values above."
