#!/usr/bin/env bash
# FrankenPHP runtime environment setup
# This file is sourced by Heroku dyno manager before starting the process.

# Add FrankenPHP bin FIRST in PATH so the php shim and frankenphp binary
# take precedence over the heroku/php buildpack's php at runtime.
export PATH="$HOME/.heroku/frankenphp/bin:$PATH"

# FrankenPHP / Caddy config directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"

# Laravel defaults
export APP_ENV="${APP_ENV:-production}"
export APP_DEBUG="${APP_DEBUG:-false}"
export LOG_CHANNEL="${LOG_CHANNEL:-stderr}"
export LOG_LEVEL="${LOG_LEVEL:-warning}"

# Octane server
export OCTANE_SERVER="${OCTANE_SERVER:-frankenphp}"
