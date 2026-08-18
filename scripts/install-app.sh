#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE_APP="$ROOT_DIR/dist/trais.app"
INSTALLED_APP="/Applications/trais.app"
STAGING_APP="/Applications/.trais.app.installing.$$"

cleanup() {
    rm -rf "$STAGING_APP"
}
trap cleanup EXIT HUP INT TERM

"$ROOT_DIR/scripts/build-app.sh"

rm -rf "$STAGING_APP"
ditto "$SOURCE_APP" "$STAGING_APP"
codesign --verify --strict "$STAGING_APP"

rm -rf "$INSTALLED_APP"
mv "$STAGING_APP" "$INSTALLED_APP"

codesign --verify --strict "$INSTALLED_APP"
echo "Installed $INSTALLED_APP"
