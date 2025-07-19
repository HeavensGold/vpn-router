#!/bin/bash

# --- 변수 설정 ---
# WAN (Wide Area Network) 인터페이스 - 인터넷에 연결된 인터페이스
# (예: eth0, ppp0)
WAN_IF="eth0"

# LAN (Local Area Network) 인터페이스 - 내부 네트워크에 연결된 인터페이스
# (예: eth1, wlan0)
LAN_IF="eth1"

# LAN 서브넷 주소 대역
LAN_SUBNET="192.168.10.0/24"


# --- IP 포워딩 활성화 ---
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1


# --- 기존 iptables 규칙 초기화 ---
echo "Flushing existing iptables rules..."
iptables -F
iptables -t nat -F
iptables -X


# --- 기본 정책 설정 ---
# 보안을 위해 기본적으로 모든 포워딩 트래픽을 차단합니다.
echo "Setting default FORWARD policy to DROP..."
iptables -P FORWARD DROP


# --- NAT 규칙 설정 ---
# LAN에서 WAN으로 나가는 트래픽에 대해 IP 마스커레이딩(NAT)을 설정합니다.
# 이를 통해 LAN 내부의 장치들이 WAN 인터페이스의 IP 주소를 사용하여 인터넷에 접속할 수 있습니다.
echo "Setting up NAT (Masquerade) for traffic from $LAN_IF to $WAN_IF..."
iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE


# --- 패킷 포워딩 규칙 설정 ---
echo "Setting up forwarding rules..."

# LAN -> WAN 으로 나가는 트래픽 허용
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# WAN -> LAN 으로 들어오는 트래픽 중, 이미 연결된(ESTABLISHED) 또는 관련된(RELATED) 트래픽 허용
# 이는 외부에서 시작된 새로운 연결은 차단하지만, 내부에서 시작된 연결의 응답은 허용합니다.
iptables -A FORWARD -i $WAN_IF -o $LAN_IF -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT


echo "WAN/LAN router rules applied successfully."
