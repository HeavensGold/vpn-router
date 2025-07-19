#!/usr/bin/env bash

# This script must be run with root privileges.

VPNGATE_URL=https://www.vpngate.net/api/iphone/

function global_ip {
  curl -s inet-ip.info
}

# VPN connection function
function connect {
  while :; do
    echo "Searching for a Japanese VPN server..."
    while read line; do
      line=$(echo $line | cut -d ',' -f 15)
      line=$(echo $line | tr -d '')
      # openvpn requires root privileges to modify network routes.
      # We add --data-ciphers to support older encryption used by many VPNGate servers.
      echo "$line" | base64 -d | sudo openvpn --config /dev/stdin --data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC
    done < <(curl -s $VPNGATE_URL | grep ,Japan,JP, | grep -v public-vpn- | sort -R)
    echo "Connection lost or failed. Finding a new server..."
    sleep 1
  done
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo'." >&2
  exit 1
fi

BEFORE_IP="$(global_ip)"
echo "Your public IP before connecting is: $BEFORE_IP"

# Start the VPN connection process in the background.
echo "Starting VPN connection..."
connect &

# VPN health check loop
while :; do
  sleep 15 # Wait a bit for the connection to be established.
  
  AFTER_IP=$(global_ip)
  result=$?
  
  echo "IP check: [Before: $BEFORE_IP] -> [After: $AFTER_IP]"

  if [ $result -ne 0 ]; then
    echo "Health check failed (could not fetch IP). Restarting VPN..."
    # pkill requires root privileges if the process was started by root.
    sudo pkill openvpn
  elif [ "$BEFORE_IP" = "$AFTER_IP" ]; then
    echo "VPN is not connected correctly (IP unchanged). Restarting..."
    sudo pkill openvpn
  else
    echo "VPN is active. Current IP: $AFTER_IP. Checking again in 60 seconds."
    sleep 45 # Total sleep time will be 15 + 45 = 60 seconds
  fi
done
