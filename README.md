# VPN 라우터

이 프로젝트는 Raspberry Pi와 같은 리눅스 기반 시스템을 강력한 VPN 라우터로 변환하는 스크립트 모음입니다. 유선 및 무선(Wi-Fi 핫스팟)으로 연결된 모든 클라이언트의 인터넷 트래픽을 OpenVPN 연결을 통해 안전하게 라우팅합니다.

## 주요 기능

- **VPN 트래픽 라우팅:** OpenVPN을 통해 모든 아웃바운드 트래픽을 라우팅합니다.
- **Wi-Fi 핫스팟:** `hostapd`와 `dnsmasq`를 사용하여 Wi-Fi 액세스 포인트를 생성합니다.
- **Kill Switch:** VPN 연결이 끊어지면 인터넷 트래픽을 차단하여 데이터 유출을 방지합니다.
- **유선 및 무선 지원:** 유선 LAN과 Wi-Fi 핫스팟 클라이언트를 모두 지원합니다.

## 사전 요구 사항

이 스크립트를 사용하기 전에 다음 소프트웨어가 설치되어 있어야 합니다.

- `openvpn`
- `hostapd`
- `dnsmasq`
- `iptables`

Debian/Ubuntu 기반 시스템에서는 다음 명령어로 설치할 수 있습니다.

```bash
sudo apt-get update
sudo apt-get install openvpn hostapd dnsmasq iptables
```

또한, AP(Access Point) 모드를 지원하는 무선 네트워크 어댑터가 필요합니다.

## 설정

스크립트를 실행하기 전에 몇 가지 설정을 수정해야 합니다.

### 1. VPN 라우팅 규칙 (`apply-vpn-rules.sh`)

스크립트 상단의 변수들을 자신의 네트워크 환경에 맞게 수정하세요.

- `WIRED_IF`: 유선 LAN 인터페이스 이름 (예: `eth0`)
- `WIRED_SUBNET`: 유선 LAN의 서브넷 주소 (예: `192.168.1.0/24`)
- `WIFI_IF`: 무선 LAN 인터페이스 이름 (예: `wlan0`)
- `WIFI_SUBNET`: Wi-Fi 핫스팟에서 사용할 서브넷 주소 (예: `192.168.100.0/24`)
- `VPN_IF`: OpenVPN이 생성하는 가상 인터페이스 이름 (일반적으로 `tun0`)

### 2. Wi-Fi 핫스팟 (`hostapd.conf`)

Wi-Fi 핫스팟의 이름(SSID)과 비밀번호를 설정합니다.

- `ssid`: 원하는 Wi-Fi 이름을 입력합니다.
- `wpa_passphrase`: 8자 이상의 Wi-Fi 비밀번호를 입력합니다.

### 3. DHCP 서버 (`dnsmasq.conf`)

Wi-Fi 클라이언트에게 IP 주소를 할당하는 범위를 설정합니다. `apply-vpn-rules.sh`의 `WIFI_SUBNET`과 일치해야 합니다.

- `interface`: 무선 인터페이스 이름 (`wlan0`)
- `dhcp-range`: IP 주소 할당 범위 (예: `192.168.100.50,192.168.100.150,12h`)

### 4. OpenVPN 설정

사용하려는 OpenVPN 서버의 `.ovpn` 설정 파일이 필요합니다. 이 파일은 VPN 서비스 제공업체로부터 받거나 직접 생성해야 합니다.

## 설치 및 실행

1.  **스크립트 다운로드 또는 복제**

    ```bash
    git clone https://github.com/your-username/vpn-router.git
    cd vpn-router
    ```

2.  **스크립트 실행 권한 부여**

    ```bash
    chmod +x start.sh apply-vpn-rules.sh start-hotspot.sh
    ```

3.  **서비스 시작 (`start.sh`)**

    `start.sh` 스크립트는 필요한 모든 서비스를 순서대로 실행합니다. OpenVPN 설정 파일의 경로를 인자로 전달해야 합니다.

    ```bash
    sudo ./start.sh /path/to/your/vpn_config.ovpn
    ```

    이 스크립트는 다음 작업을 수행합니다.
    - OpenVPN 클라이언트를 백그라운드에서 실행합니다.
    - `start-hotspot.sh`를 실행하여 Wi-Fi 핫스팟과 DHCP 서버를 활성화합니다.
    - `apply-vpn-rules.sh`를 실행하여 `iptables` 라우팅 규칙을 적용합니다.

## systemd 서비스로 등록 (선택 사항)

시스템 부팅 시 VPN 라우터가 자동으로 시작되도록 systemd 서비스로 등록할 수 있습니다.

1.  **`vpn-router.service` 파일 수정**

    `ExecStart` 경로를 실제 `start.sh` 스크립트 위치와 OpenVPN 설정 파일 경로에 맞게 수정합니다.

    ```ini
    [Unit]
    Description=VPN Router Service
    After=network.target

    [Service]
    Type=simple
    ExecStart=/home/c18a/git/vpn-router/start.sh /path/to/your/vpn_config.ovpn
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    ```

2.  **서비스 파일 복사 및 활성화**

    ```bash
    sudo cp vpn-router.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable vpn-router.service
    sudo systemctl start vpn-router.service
    ```

이제 시스템이 부팅될 때마다 VPN 라우터가 자동으로 실행됩니다.
