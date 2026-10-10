#!/bin/bash
# Screenshots of the real game, taken in the iOS Simulator (needs a Mac with Xcode):
#
#   scripts/screenshots.sh [output folder]
#
# 1. A computer player plays a new farm to the finale by the game's own rules
#    (`acres-tools autoplay`), saving the farm along the way.
# 2. The app is built for the Simulator and run on an iPhone and an iPad. For
#    each shot a save is copied into the app and a scene picked with launch
#    options (`ScreenshotMode`, debug builds only).
# 3. `simctl io screenshot` grabs the Simulator's screen as it is.
#
# GitHub runs this on a Mac: Actions → Screenshots → Run workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${1:-screenshots}"
OUT="$(cd "${1:-screenshots}" && pwd)"
WORK="$(mktemp -d)"
BUNDLE=com.acresgame.Acres

echo "== Playing a farm to the finale"
(cd "$ROOT/Packages/AcresCore" && swift run -c release acres-tools autoplay "$WORK/saves") | tee "$OUT/autoplay.txt"

echo "== Building the app for the Simulator"
xcodebuild -project "$ROOT/Acres.xcodeproj" -scheme Acres -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$WORK/build" \
    CODE_SIGNING_ALLOWED=NO build > "$WORK/build.log" 2>&1 || { tail -n 80 "$WORK/build.log"; exit 1; }
APP="$WORK/build/Build/Products/Debug-iphonesimulator/Acres.app"

# The first of these device types the Simulator knows.
pick() {
    local known
    known="$(xcrun simctl list devicetypes)"
    for name in "$@"; do
        if grep -q "^$name (" <<<"$known"; then
            echo "$name"
            return
        fi
    done
    echo "No device type among: $*" >&2
    exit 1
}

# take <name> <save, or "new" for a first launch> <scene> [camera x,y] [tiles across]
take() {
    local name="$1" save="$2" scene="$3" camera="${4:-}" tiles="${5:-}"
    xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true
    rm -rf "$SAVES"
    if [ "$save" != new ]; then
        mkdir -p "$SAVES"
        cp "$WORK/saves/$save/farm.json" "$SAVES/farm.json"
    fi
    local args=(-AcresShot "$scene")
    if [ -n "$camera" ]; then args+=(-AcresCamera "$camera"); fi
    if [ -n "$tiles" ]; then args+=(-AcresTiles "$tiles"); fi
    xcrun simctl launch "$UDID" "$BUNDLE" "${args[@]}" > /dev/null
    sleep "$WAIT"
    local file="$OUT/$LABEL-$name.png"
    # (--mask=ignored: the screen as a screenshot on the device has it, without
    # the Simulator's black Dynamic Island.)
    xcrun simctl io "$UDID" screenshot --type=png --mask=ignored "$file" > /dev/null 2>&1
    # The Simulator hands the screen back the way the device is held (upright);
    # the game is played sideways, so turn the picture with it.
    local width height
    width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')
    height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')
    if [ "$height" -gt "$width" ]; then sips -r 270 "$file" > /dev/null; fi
    echo "   $LABEL-$name"
}

# shoot <label> <device type> [runtime]
shoot() {
    LABEL="$1"
    echo "== $LABEL ($2 ${3:-})"
    UDID="$(xcrun simctl create "Acres $LABEL" "$2" ${3:+"$3"})"
    xcrun simctl boot "$UDID"
    xcrun simctl bootstatus "$UDID" -b > /dev/null
    xcrun simctl install "$UDID" "$APP"
    SAVES="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/Library/Application Support/Saves"

    # A first run to warm up (shaders, the textures), then the shots.
    WAIT=25
    take warmup end_day farm
    rm -f "$OUT/$LABEL-warmup.png"
    WAIT=10

    take 01-title           end_day     title
    take 02-first-day       new         farm
    take 03-early-farm      early       farm            31,33   10
    take 04-thriving-farm   mid         farm            33,35   13
    take 05-finest-farm     end_day     farm            31,37   15
    take 06-finale          end_day     finale          31,37   15
    take 07-fields          end_day     farm            45,33   15
    take 08-animals         end_day     farm            30,47   12
    take 09-farm-at-night   end_night   farm            24,36.5 11
    take 10-village         end_village farm            94,27   14
    take 11-seed-shop       end_village shop:seedShop   80,25   14
    take 12-windmill        end_day     farm            109.5,41.5 13
    take 13-harvest-fair    end_day     farm            110,12.5 12
    take 14-willow-lake     end_day     farm            99,9    13
    take 15-journal-village end_day     journal:village
    take 16-journal-almanac end_day     journal:almanac
    take 17-journal-money   end_day     journal:money
    take 18-journal-farm    mid         journal:farm
    take 19-drive-to        end_day     map             31,37   15
    take 20-goals           mid         goals
    take 21-bag             end_day     bag

    xcrun simctl shutdown "$UDID"
    xcrun simctl delete "$UDID"
}

shoot iphone "$(pick "iPhone 17 Pro Max" "iPhone 16 Pro Max" "iPhone 15 Pro Max")"
# The iPad on iPadOS 18: iPadOS 26 letterboxes a sideways-only game while the
# iPad is held upright, and a Simulator without a window never turns.
IPAD_RUNTIME="$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-18-[0-9]*' | tail -n 1)"
shoot ipad "$(pick "iPad Pro 13-inch (M4)" "iPad Pro (12.9-inch) (6th generation)")" "$IPAD_RUNTIME"

echo "== Done: $OUT"
