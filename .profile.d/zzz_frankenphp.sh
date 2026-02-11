#!/usr/bin/env bash
# FrankenPHP runtime environment — runs LAST to override heroku/php PATH.
# File named zzz_ to ensure it runs after heroku/php's .profile.d scripts.

# Add FrankenPHP bin FIRST in PATH so the php shim and frankenphp binary
# take precedence over the heroku/php buildpack's php at runtime.
# This is critical: FrankenPHP includes pcntl, posix, etc. compiled
# statically — heroku/php's PHP may NOT have these extensions.
export PATH="$HOME/.heroku/frankenphp/bin:$PATH"

# Tell FrankenPHP's PHP where to find our custom .ini files
# (standalone binary defaults to /etc/frankenphp/php.d/ which is read-only on Heroku)
export PHP_INI_SCAN_DIR="$HOME/.heroku/frankenphp/etc/php.d"

# FrankenPHP / Caddy config dirs
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"

# Go runtime optimizations (FrankenPHP is written in Go)
export GODEBUG="${GODEBUG:-cgocheck=0}"

# Disable Caddy's automatic HTTPS — Heroku handles TLS termination externally.
# Listen on HTTP only at the $PORT Heroku assigns.
export SERVER_NAME="${SERVER_NAME:-http://0.0.0.0:${PORT:-8000}}"

# Laravel defaults
export APP_ENV="${APP_ENV:-production}"
export APP_DEBUG="${APP_DEBUG:-false}"
export LOG_CHANNEL="${LOG_CHANNEL:-stderr}"
export LOG_LEVEL="${LOG_LEVEL:-warning}"

# Octane server
export OCTANE_SERVER="${OCTANE_SERVER:-frankenphp}"
