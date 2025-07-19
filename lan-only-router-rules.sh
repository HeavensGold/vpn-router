#!/bin/bash

# --- 변수 설정 ---
# 유선 LAN 인터페이스
WIRED_IF="eth0"
WIRED_SUBNET="192.168.1.0/24"

# 무선 LAN(핫스팟) 인터페이스
WIFI_IF="wlan0"
WIFI_SUBNET="192.168.100.0/24"

# OpenVPN이 사용하는 가상 인터페이스
VPN_IF="tun0"


# --- IP 포워딩 활성화 ---
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1


# --- 기존 iptables 규칙 초기화 ---
echo "Flushing existing iptables rules..."
iptables -F
iptables -t nat -F
iptables -X


# --- 기본 정책 설정 (Kill Switch) ---
echo "Setting default FORWARD policy to DROP (Kill Switch enabled)..."
iptables -P FORWARD DROP


# --- NAT 규칙 설정 ---
# 모든 로컬 트래픽(유선, 무선)을 VPN 인터페이스로 전달
echo "Setting up NAT rules for local networks via $VPN_IF..."
iptables -t nat -A POSTROUTING -s $WIRED_SUBNET -o $VPN_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s $WIFI_SUBNET -o $VPN_IF -j MASQUERADE


# --- 패킷 포워딩 규칙 설정 ---
echo "Setting up forwarding rules for both wired and wireless LANs..."

# VPN -> 로컬 네트워크 (유선/무선) 허용 (이미 연결된 트래픽)
iptables -A FORWARD -i $VPN_IF -o $WIRED_IF -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $VPN_IF -o $WIFI_IF -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 로컬 네트워크 (유선/무선) -> VPN 허용
iptables -A FORWARD -i $WIRED_IF -o $VPN_IF -j ACCEPT
iptables -A FORWARD -i $WIFI_IF -o $VPN_IF -j ACCEPT


echo "VPN router rules for both wired and wireless LANs applied successfully."