#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$repo_dir/artifacts"
for test in control range input integration handles flight_pose grip_integration; do
  log="$repo_dir/artifacts/$test.log"
  godot4 --headless --xr-mode off --path "$repo_dir" --script "tests/test_$test.gd" >"$log" 2>&1
  cat "$log"
  if grep -Eq 'SCRIPT ERROR|Parse Error|FAIL' "$log"; then exit 1; fi
done
