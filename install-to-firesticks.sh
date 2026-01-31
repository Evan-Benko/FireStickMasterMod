#!/bin/bash

ADB="./adb"
APK_DIR="./apks"
MAX_PARALLEL=25
TIMEOUT=1

command -v adb >/dev/null || { echo "❌ adb not found"; exit 1; }

echo "🔥 FireTV Fleet Installer"
echo "=========================="

# --- Get active interfaces ---
INTERFACES=$(route get default 2>/dev/null | awk '/interface:/{print $2}')

declare -A SUBNETS

for IFACE in $INTERFACES; do
    IP=$(ipconfig getifaddr "$IFACE" 2>/dev/null) || continue
    SUBNET=$(echo "$IP" | awk -F. '{print $1"."$2"."$3}')
    SUBNETS["$SUBNET"]=1
done

if [ ${#SUBNETS[@]} -eq 0 ]; then
    echo "❌ No active subnets found"
    exit 1
fi

echo "🌐 Subnets detected:"
for S in "${!SUBNETS[@]}"; do
    echo "   • $S.0/24"
done
echo ""

# --- FireTV detection ---
is_fire_tv() {
    local serial=$1
    MODEL=$($ADB -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    BRAND=$($ADB -s "$serial" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')

    [[ "$MODEL" == *"AFT"* || "$MODEL" == *"Fire"* || "$BRAND" == *"Amazon"* ]]
}

# --- Get installed packages ---
get_installed_packages() {
    $ADB -s "$1" shell pm list packages 2>/dev/null | sed 's/package://'
}

# --- Optional cleanup ---
cleanup_storage() {
    echo "🧹 Cleaning cache..."
    $ADB -s "$1" shell pm trim-caches 1G >/dev/null 2>&1
}

# --- Install APKs ---
install_apks() {
    local serial=$1
    local installed
    installed=$(get_installed_packages "$serial")

    for APK in "$APK_DIR"/*.apk; do
        PKG=$(aapt dump badging "$APK" 2>/dev/null | awk -F"'" '/package: name=/{print $2}')

        if echo "$installed" | grep -q "^$PKG$"; then
            echo "   ⏭️  Skipping $(basename "$APK") (already installed)"
        else
            echo "   📦 Installing $(basename "$APK")"
            $ADB -s "$serial" install -r "$APK" >/dev/null 2>&1 \
                && echo "   ✅ Installed" \
                || echo "   ❌ Failed"
        fi
    done
}

export -f is_fire_tv get_installed_packages cleanup_storage install_apks

# --- Scan function ---
scan_ip() {
    local IP=$1
    timeout $TIMEOUT adb connect "$IP:5555" >/dev/null 2>&1 || return

    if is_fire_tv "$IP:5555"; then
        MODEL=$(adb -s "$IP:5555" shell getprop ro.product.model | tr -d '\r')
        echo "🔥 Fire TV FOUND: $MODEL @ $IP"

        cleanup_storage "$IP:5555"
        install_apks "$IP:5555"
    fi
}

export -f scan_ip

# --- Parallel scan ---
for SUBNET in "${!SUBNETS[@]}"; do
    echo "🔍 Scanning subnet $SUBNET.0/24"
    seq 1 254 | xargs -P $MAX_PARALLEL -I{} bash -c "scan_ip $SUBNET.{}"
done

echo ""
echo "🎉 Deployment complete"
