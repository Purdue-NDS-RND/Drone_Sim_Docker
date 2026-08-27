#!/usr/bin/env bash
set -Eeuo pipefail

log_file=${SITL_PROCESS_LOG:-/sim/arducopter.log}
exec "$@" >>"$log_file" 2>&1
