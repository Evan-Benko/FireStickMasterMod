#!/usr/bin/env bash
set -euo pipefail

# Optional: Pass IPs as args to override scanning (e.g., ./script.sh 192.168.2.164)
MANUAL_IPS=("$@")

# 1) Detect local IP and /24 subnet prefix
get_local_ip() {
  ifconfig | awk '/inet 192.168/ { print $2; exit }'  # Broader detection for any 192.168.x.x interface
}
LOCAL_IP=$(get_local_ip)
[[ -n "$LOCAL_IP" ]] || {
  echo "❌ Could not detect local IP on 192.168.x.x; are you on Wi-Fi/Ethernet?" >&2
  exit 1
}
SUBNET_PREFIX="${LOCAL_IP%.*}"
echo "🔍 Scanning ${SUBNET_PREFIX}.0/24 for Amazon-OEM MACs…"

# 2) Ping-scan + MAC OUI filter for Amazon devices
declare -a FIRE_IPS
if (( ${#MANUAL_IPS[@]} > 0 )); then
  FIRE_IPS=("${MANUAL_IPS[@]}")
  echo "Using manual IPs: ${FIRE_IPS[*]}"
else
  while read -r ip; do
    FIRE_IPS+=("$ip")
  done < <(
    nmap -sn -n "${SUBNET_PREFIX}.0/24" \
        | awk '/Nmap scan report for/ { ip=$NF }
         /MAC Address: .*Amazon/    { print ip }'
  )
fi

if (( ${#FIRE_IPS[@]} == 0 )); then
  echo "⚠️ No Fire Sticks found (no Amazon OUIs). Try running with sudo or manual IPs." >&2
  exit 1
fi

echo "✅ Found/targeted Fire Sticks at: ${FIRE_IPS[*]}"

# 3) Gather APKs
APK_DIR="./apks"
shopt -s nullglob
APKS=( "$APK_DIR"/*.apk )
if (( ${#APKS[@]} == 0 )); then
  echo "❌ No APKs found in $APK_DIR." >&2
  exit 1
fi

# 4) For each Fire Stick, connect and install
for IP in "${FIRE_IPS[@]}"; do
  echo "----"
  echo "📱 Connecting to $IP:5555…"
  if adb connect "$IP:5555" 2>&1 | grep -iqE 'connected|already'; then
    echo "✅ Connected to $IP"
    
    # Optional cleanup - ignore failures so script continues
    echo "  → Attempting to clear caches (may be restricted)…"
    adb -s "$IP:5555" shell pm trim-caches 999G 2>/dev/null || echo "    ⚠️ Cache clear blocked/skipped"
    
    # Skip force-stop on protected packages - it's not essential for installs
    # If you had this line, comment it out or add || true
    # adb -s "$IP:5555" shell am force-stop com.amazon.tv.launcher || true
    
    # Optional: Go to home screen to "wake" device
    adb -s "$IP:5555" shell input keyevent 3 || true
    
    # Now install APKs - this should run regardless
    for APK in "${APKS[@]}"; do
      echo "  → Installing $(basename "$APK")"
      if adb -s "$IP:5555" install -r "$APK"; then
        echo "    ✔️ Success"
      else
        echo "    ⚠️ Failed - check APK compatibility or storage"
      fi
    done
    
    # Optional disconnect
    adb disconnect "$IP:5555" >/dev/null
  else
    echo "⏭ Could not connect to ADB on $IP"
  fi
done

echo "🎉 All done!"
