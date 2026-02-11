#!/usr/bin/env bash
# Script de diagnóstico para verificar extensões PHP em runtime
# Use: heroku run bash diagnostics/check-extensions.sh

echo "=== FrankenPHP Extensions Diagnostic ==="
echo ""

# Check FrankenPHP binary
echo "=== FrankenPHP Binary ==="
if command -v frankenphp &>/dev/null; then
  echo "✅ frankenphp found at: $(command -v frankenphp)"
  frankenphp version 2>/dev/null || echo "  (version not available)"
else
  echo "❌ frankenphp NOT found in PATH"
fi

echo ""
echo "=== PHP Shim ==="
if command -v php &>/dev/null; then
  echo "✅ php found at: $(command -v php)"
  php --version 2>/dev/null | head -1
else
  echo "❌ php NOT found in PATH"
fi

echo ""
echo "=== Built-in PHP Extensions ==="
echo "FrankenPHP standalone includes these extensions statically compiled:"
echo ""
frankenphp php-cli -m 2>/dev/null || php -m 2>/dev/null || echo "  (unable to list modules)"

echo ""
echo "=== Critical Extensions Check ==="
CRITICAL_EXTS="mbstring pcntl posix sockets opcache curl gd intl pdo pdo_mysql pdo_pgsql"
for ext in $CRITICAL_EXTS; do
  if frankenphp php-cli -m 2>/dev/null | grep -qi "^${ext}$"; then
    echo "  ✅ $ext"
  else
    echo "  ❌ $ext (NOT available)"
  fi
done

echo ""
echo "=== Test mb_split function ==="
frankenphp php-cli -r "echo 'Testing mb_split: '; var_dump(function_exists('mb_split')); if (function_exists('mb_split')) { echo 'Result: ' . implode(', ', mb_split('\\s+', 'hello world')) . PHP_EOL; } else { echo 'FAIL: mb_split not available' . PHP_EOL; }" 2>&1

echo ""
echo "=== Environment ==="
echo "PATH: $PATH"
echo "HOME: $HOME"
echo "OCTANE_SERVER: ${OCTANE_SERVER:-not set}"
echo "APP_ENV: ${APP_ENV:-not set}"

echo ""
echo "=== FrankenPHP Binary Info ==="
file "$(command -v frankenphp 2>/dev/null || echo /app/.heroku/frankenphp/bin/frankenphp)" 2>/dev/null || echo "  (file command not available)"

echo ""
echo "Done!"
