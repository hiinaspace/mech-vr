#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$repo_dir/artifacts"
if [[ ${1:-} == --xr ]]; then
  shift
  exec godot4 --path "$repo_dir" --xr-mode on --log-file "$repo_dir/artifacts/headset-engine.log" "$@" -- --xr
fi
exec godot4 --path "$repo_dir" --xr-mode off --log-file "$repo_dir/artifacts/desktop-engine.log" -- "$@"
