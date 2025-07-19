#!/bin/bash

WIFI_IF="wlan0"
WIFI_SUBNET="192.168.100.1/24"

echo "Starting Wi-Fi Hotspot..."

# 와이파이 인터페이스 IP 설정
ip addr add $WIFI_SUBNET dev $WIFI_IF

# hostapd (AP) 실행
hostapd -B /home/c18a/git/vpn-router/hostapd.conf

# dnsmasq (DHCP) 실행
dnsmasq -C /home/c18a/git/vpn-router/dnsmasq.conf

echo "Wi-Fi Hotspot started."
