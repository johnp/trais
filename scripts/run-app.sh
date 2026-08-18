#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT_DIR/scripts/build-app.sh"
open "$ROOT_DIR/dist/trais.app"
