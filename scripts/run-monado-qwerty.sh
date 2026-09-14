#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runtime_root=${TMPDIR:-/tmp}
runtime_dir=$(mktemp -d -p "$runtime_root" mech-vr-monado.XXXXXX)
artifact_dir="$repo_dir/test-artifacts"
service_log="$artifact_dir/monado-qwerty.log"
service_pid=""

mkdir -p "$artifact_dir"
chmod 700 "$runtime_dir"

cleanup() {
  status=$?
  if [[ -n "$service_pid" ]] && kill -0 "$service_pid" 2>/dev/null; then
    kill -TERM "$service_pid" 2>/dev/null || true
    wait "$service_pid" 2>/dev/null || true
  fi
  rm -rf -- "$runtime_dir"
  exit "$status"
}
trap cleanup EXIT INT TERM

export XDG_RUNTIME_DIR="$runtime_dir"
export XR_RUNTIME_JSON=/run/current-system/sw/share/openxr/1/openxr_monado.json
export QWERTY_ENABLE=1
export QWERTY_COMBINE=0
export XRT_COMPOSITOR_NULL=1
export XRT_NO_STDIN=1
export IPC_EXIT_ON_DISCONNECT=1

monado-service >"$service_log" 2>&1 &
service_pid=$!

for _ in $(seq 1 100); do
  if [[ -S "$runtime_dir/monado_comp_ipc" ]]; then
    break
  fi
  if ! kill -0 "$service_pid" 2>/dev/null; then
    echo "Isolated Monado exited before creating its IPC socket." >&2
    echo "See $service_log" >&2
    exit 1
  fi
  sleep 0.05
done

if [[ ! -S "$runtime_dir/monado_comp_ipc" ]]; then
  echo "Timed out waiting for isolated Monado. See $service_log" >&2
  exit 1
fi

echo "Isolated Monado QWERTY runtime: $runtime_dir"
echo "Monado log: $service_log"
if [[ ${1:-} == "--smoke" ]]; then
  godot4 --path "$repo_dir" --xr-mode on --quit-after 180 -- --xr
  exit $?
fi
godot4 --path "$repo_dir" --xr-mode on -- --xr
