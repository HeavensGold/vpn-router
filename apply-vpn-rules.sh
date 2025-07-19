#!/bin/bash

# --- 변수 설정 ---
# 사용자의 로컬 네트워크 인터페이스 (예: eth0, enp3s0)
LAN_IF="eth0"
#LAN_IF="wlp3s0"
# 사용자의 로컬 네트워크 주소 대역 (예: 192.168.1.0/24)
LAN_SUBNET="192.168.1.0/24"
#LAN_SUBNET="192.168.99.0/24"
# OpenVPN이 사용하는 가상 인터페이스
VPN_IF="tun0"

# --- IP 포워딩 활성화 ---
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

# --- 기존 iptables 규칙 초기화 ---
echo "Flushing existing iptables rules..."
iptables -F
iptables -t nat -F

# --- NAT 규칙 설정 ---
# 로컬 네트워크 트래픽을 VPN 인터페이스로 전달 (MASQUERADE)
echo "Setting up NAT rules for $LAN_SUBNET via $VPN_IF..."
iptables -t nat -A POSTROUTING -s $LAN_SUBNET -o $VPN_IF -j MASQUERADE

# --- 패킷 포워딩 규칙 설정 ---
echo "Setting up forwarding rules..."
# 내부 -> VPN 허용
iptables -A FORWARD -i $LAN_IF -o $VPN_IF -j ACCEPT
# VPN -> 내부 (이미 연결된 트래픽에 대해서만 허용)
iptables -A FORWARD -i $VPN_IF -o $LAN_IF -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "VPN router rules applied successfully."
