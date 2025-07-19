#!/bin/bash

# --- 변수 설정 ---
# 로컬 네트워크와 인터넷에 모두 연결된 단일 네트워크 인터페이스
# (예: eth0, wlan0, enp3s0)
LAN_IF="eth0"

# 사용자의 로컬 네트워크 주소 대역 (예: 192.168.1.0/24)
LAN_SUBNET="192.168.1.0/24"

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


# --- 기본 정책 설정 (Kill Switch의 핵심) ---
# 라우터를 통과하는 모든 트래픽(FORWARD)을 기본적으로 차단합니다.
# 이 규칙은 VPN 연결이 끊겼을 때 인터넷 연결을 차단하는 역할을 합니다.
echo "Setting default FORWARD policy to DROP (Kill Switch enabled)..."
iptables -P FORWARD DROP


# --- NAT 규칙 설정 ---
# 로컬 네트워크 트래픽을 VPN 인터페이스로 전달 (MASQUERADE)
echo "Setting up NAT rules for $LAN_SUBNET via $VPN_IF..."
iptables -t nat -A POSTROUTING -s $LAN_SUBNET -o $VPN_IF -j MASQUERADE


# --- 패킷 포워딩 규칙 설정 ---
# 모든 FORWARD 트래픽은 VPN 인터페이스(tun0)를 통해서만 허용됩니다.
echo "Setting up forwarding rules to only allow traffic via $VPN_IF..."

# VPN -> 내부 (이미 연결된 트래픽에 대해서만 허용)
iptables -A FORWARD -i $VPN_IF -o $LAN_IF -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 내부 -> VPN 허용 (새로운 연결 및 이미 연결된 트래픽)
iptables -A FORWARD -i $LAN_IF -o $VPN_IF -j ACCEPT


echo "VPN router rules applied successfully."
