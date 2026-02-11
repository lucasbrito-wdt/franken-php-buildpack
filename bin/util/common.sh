#!/usr/bin/env bash
# Shared utility functions for the FrankenPHP buildpack.

# Export environment variables from the env dir.
# Usage: export_env_dir <env-dir> [whitelist-regex] [blacklist-regex]
export_env_dir() {
  local env_dir=$1
  local whitelist_regex=${2:-''}
  local blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|LANG|BUILD_DIR)$'}

  if [ -d "$env_dir" ]; then
    for e in $(ls "$env_dir"); do
      echo "$e" | grep -E "$blacklist_regex" && continue
      if [ -z "$whitelist_regex" ] || echo "$e" | grep -qE "$whitelist_regex"; then
        export "$e=$(cat "$env_dir/$e")"
      fi
    done
  fi
}

# Log an error message and exit
error() {
  echo " !     $*" >&2
  exit 1
}

# Log a warning message
warning() {
  echo " #     $*"
}

# Log a status message with arrow prefix
status() {
  echo "-----> $*"
}

# Log an info message with indent
info() {
  echo "       $*"
}
