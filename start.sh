#!/usr/bin/env bash

# This script must be run with root privileges.

# --- Configuration ---
VPNGATE_URL="https://www.vpngate.net/api/iphone/"
OPENVPN_OPTIONS="--config /dev/stdin --data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC --log /dev/null"

# --- State ---
VPN_PID=0 # To store the PID of the current OpenVPN process

# --- Functions ---

# Function to get the current global IP address
function global_ip {
  curl -s --max-time 10 inet-ip.info
}

# Cleanup function to be called on script exit
function cleanup {
  echo "Caught signal, shutting down..."
  if [ $VPN_PID -ne 0 ] && ps -p $VPN_PID > /dev/null; then
    echo "Stopping OpenVPN process (PID: $VPN_PID)..."
    sudo kill $VPN_PID
    # Wait a moment for the process to terminate
    sleep 2
  fi
  # Kill any remaining openvpn processes just in case
  sudo pkill openvpn
  echo "VPN connections terminated."
  exit 0
}

# --- Main Execution ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo'." >&2
  exit 1
fi

# Set up trap to call cleanup function on script exit/interruption
trap cleanup EXIT SIGINT SIGTERM

# Clean up any previous openvpn processes and apply firewall rules
sudo pkill openvpn
sleep 1
sudo pkill -9 openvpn
sleep 1
sudo bash apply-vpn-rules.sh

# Store the IP address before connecting
BEFORE_IP=$(global_ip)
if [ -z "$BEFORE_IP" ]; then
  echo "Could not determine initial public IP. Please check your internet connection."
  exit 1
fi
echo "Your public IP before connecting is: $BEFORE_IP"

# Main loop to find and maintain a VPN connection
while :; do
  echo "Searching for a Japanese VPN server..."
  
  # Fetch, filter, and randomize a list of top 10 Japanese servers
  SERVER_LIST=$(curl -s "$VPNGATE_URL" | grep ',Japan,JP,' | grep -v 'public-vpn-' | sort -t',' -k5 -n -r | head -10 | sort -R)

  if [ -z "$SERVER_LIST" ]; then
    echo "Could not retrieve VPN server list. Retrying in 30 seconds..."
    sleep 30
    continue
  fi

  # Iterate through the fetched server list
  while read -r line; do
    OVPN_CONFIG=$(echo "$line" | cut -d',' -f15 | tr -d '' | base64 -d)
    
    if [ -z "$OVPN_CONFIG" ]; then
      echo "Failed to decode a server configuration. Skipping."
      continue
    fi

    echo "Attempting to connect to a new server..."
    # Start openvpn in the background and store its PID
    echo "$OVPN_CONFIG" | sudo openvpn $OPENVPN_OPTIONS &
    VPN_PID=$!

    # Wait for the connection to establish
    echo "Waiting 15 seconds for connection to establish (PID: $VPN_PID)..."
    sleep 15

    # Health Check
    AFTER_IP=$(global_ip)
    
    # Check if connection was successful (IP changed)
    if [ $? -eq 0 ] && [ -n "$AFTER_IP" ] && [ "$BEFORE_IP" != "$AFTER_IP" ]; then
      echo "VPN connection successful! Current IP: $AFTER_IP"
      
      # Monitor the connection health
      while :; do
        # Check if the OpenVPN process is still running
        if ! ps -p $VPN_PID > /dev/null; then
          echo "VPN process (PID: $VPN_PID) is no longer running. Finding a new server..."
          VPN_PID=0
          break # Exit monitor loop to find a new server
        fi

        # Check if the IP is still the VPN IP
        CURRENT_IP=$(global_ip)
        if [ $? -ne 0 ] || [ "$BEFORE_IP" = "$CURRENT_IP" ]; then
          echo "Health check failed. IP has reverted or is unreachable. Restarting connection..."
          sudo kill $VPN_PID
          VPN_PID=0
          break # Exit monitor loop to find a new server
        fi
        
        echo "Connection is stable. Current IP: $CURRENT_IP. Checking again in 60 seconds."
        sleep 60
      done
      # After breaking from the monitor loop, we need a new server.
      # The outer 'while read' loop will continue to the next server in the list.

    else
      # Connection failed
      echo "Connection failed. IP address did not change or could not be fetched."
      echo "Killing failed OpenVPN process (PID: $VPN_PID)..."
      sudo kill $VPN_PID
      VPN_PID=0
      # Wait a moment before trying the next server
      sleep 1
    fi
  done <<< "$SERVER_LIST" # Feed the server list into the loop

  echo "Exhausted all servers in the list. Fetching a new list..."
  sleep 5
done
