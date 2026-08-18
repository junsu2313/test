# Opal 카메라 시스템 운영 정리

작성일: 2026-08-11

이 문서는 GL.iNet Opal, D810 카메라, 카메라 서비스, Tailscale, SSH, 장시간 테스트와 결과 수집 구조를 한 곳에 정리한 운영 기준이다.

## 1. 전체 구조

Opal은 카메라 서비스의 호스트이자 외부에서 접근 가능한 보관함 역할을 한다. 카메라 명령과 라이브뷰처럼 지연에 민감한 트래픽은 SSID/LAN을 사용하고, SSH·로그·백업·복구처럼 관리 목적의 트래픽은 Tailscale을 사용한다.

```text
D810 camera
    │ USB/PTP
    ▼
Opal
    ├─ SSID/LAN: 카메라 명령, 라이브뷰, 프리뷰, 일반 서비스
    └─ STA/WAN → Tailscale: SSH, 로그 수집, 백업, 복구
                              │
                              ▼
                         Windows PC
```

S10은 실사용 클라이언트 검증에는 사용할 수 있지만, 자동 반복 테스트에서는 제외한다. PC도 카메라 동작의 구성원이 아니라 명령 발사·결과 수집기이며, 테스트 자체는 Opal에서 실행된다.

## 2. 네트워크 주소와 역할

| 경로 | 주소 | 용도 |
|---|---:|---|
| Opal SSID/LAN | `192.168.8.1` | 로컬 서비스, 비상 SSH 경로 |
| PC SSID/LAN | `192.168.8.246` | 로컬 명령 및 확인 |
| S10 SSID/LAN | `192.168.8.165` | 실사용 클라이언트 검증 시에만 사용 |
| Opal STA/WAN | `192.168.0.30` | 인터넷·Tailscale 연결의 기반 |
| Opal Tailscale | `100.123.59.97` | 주 SSH·백업 경로 |
| PC Tailscale | `100.94.174.121` | Opal 관리용 피어 |

Tailscale은 인터넷이 필요하다. Opal은 자체 인터넷 제공자가 아니라 기존 공유기 또는 휴대폰 핫스팟을 STA로 연결해 외부망을 얻는다.

## 3. Tailscale 시작 정책

부팅 직후 Tailscale을 무조건 재시작하지 않는다. STA 인터페이스가 올라오고, 기본 경로가 생기고, DNS가 동작하며, Tailscale control plane의 TCP 443 연결까지 확인된 경우에만 `tailscaled`를 시작한다.

이 정책의 목적은 인터넷이 없는 상태에서 재시작 루프가 발생해 OOM을 유발하는 것을 막는 것이다. 시작 조건은 다음 파일에 있다.

- `/etc/hotplug.d/iface/95-tailscale-sta`
- `/usr/bin/tailscale-sta-trigger`
- `/etc/init.d/tailscaled`

Tailscale은 자동 부팅 서비스로 직접 등록하지 않고 STA hotplug가 촉발한다. `GOMEMLIMIT=32MiB`도 적용되어 있다. 따라서 STA 이전에는 조용히 대기하고, STA와 control plane이 준비된 뒤 한 번만 시작한다.

## 4. SSH 인증 정책

Opal Dropbear의 비밀번호 SSH 로그인을 끄고 공개키 인증만 허용한다. 현재 `/etc/dropbear/authorized_keys`에는 RSA 공개키 두 개가 있다.

| 키 | 경로 | 용도 |
|---|---|---|
| Tailscale RSA | `artifacts/ssh/opal-tailscale_rsa` | `100.123.59.97` 주 경로 |
| SSID RSA | `artifacts/ssh/opal-ssid_rsa` | `192.168.8.1` 비상 경로 |

개인키 파일은 공유하거나 문서에 내용을 복사하지 않는다. 키 파일의 권한과 백업 상태를 별도로 관리한다.

### Windows OpenSSH 사용

Tailscale 경로:

```powershell
ssh -i "E:\Underlab_APP\Camera\artifacts\ssh\opal-tailscale_rsa" `
  -o HostKeyAlgorithms=+ssh-rsa `
  -o PubkeyAcceptedAlgorithms=+ssh-rsa `
  -o HostKeyAlias=192.168.8.1 `
  root@100.123.59.97
```

SSID 비상 경로는 키 파일과 대상 주소만 바꾼다.

```powershell
ssh -i "E:\Underlab_APP\Camera\artifacts\ssh\opal-ssid_rsa" `
  -o HostKeyAlgorithms=+ssh-rsa `
  -o PubkeyAcceptedAlgorithms=+ssh-rsa `
  -o HostKeyAlias=192.168.8.1 `
  root@192.168.8.1
```

두 경로의 OpenSSH 키 인증은 확인되었고, 비밀번호만 사용하는 Plink 접속은 실패하는 것이 정상이다.

### PuTTY 사용

현재 RSA 개인키는 Windows OpenSSH 형식이다. PuTTY/Plink에서 사용하려면 PuTTYgen으로 해당 개인키를 Import한 뒤 `.ppk`로 저장하고, PuTTY의 `Connection → SSH → Auth`에서 그 `.ppk`를 선택한다.

PuTTY 경로는 SSID 비상용으로 남긴다. PuTTY GUI에서 변환한 `.ppk`로 실제 접속하는 최종 확인은 아직 별도 검증 항목이다. 비밀번호 로그인은 이미 막혀 있으므로 키 없이는 접속할 수 없다.

## 5. 서비스와 세션 운영

부팅·초기화는 직렬화한다. 앞 단계가 `ready`가 된 뒤에만 다음 단계가 시작된다.

```text
서비스 A 종료/준비 완료
        ↓
서비스 B 시작/준비 완료
        ↓
USB/PTP 준비
        ↓
카메라 인식
        ↓
앱 준비
        ↓
라이브뷰·촬영 검증
```

한 단계 실패 때문에 이미 성공한 앞단계를 전부 초기화하지 않는다. 실패한 단계만 재시도·초기화하며, 각 단계는 독립적인 상태와 결과를 남긴다.

테스트 반복 중에는 세션을 매번 바꾸지 않고 `001` 세션을 유지한다. 이는 반복 과정에서 세션이 오염되는지, 같은 세션을 계속 재사용해도 안정적인지 확인하기 위한 지표다. 세션 관리자가 상태를 제공하고, 감시기는 상태를 관찰하며 세션을 임의로 고정하지 않는다.

## 6. 장시간 테스트와 관측

테스트는 Opal에서 실행하고 PC는 시작 명령과 결과 수집만 담당한다. 기록해야 할 구간은 다음과 같다.

- Opal 부팅 시작 및 서비스 초기화
- STA/SSID 연결
- 관련 서비스 시작·준비 완료
- USB와 카메라 인식
- 앱 준비 완료 또는 실패 시점
- 첫 라이브뷰 프레임 확인
- AF, 라이브뷰, UI 셔터, 물리 셔터, 연사 결과
- 세션 상태와 세션 파일 변화
- 각 단계별 시작·종료 시각과 소요 시간
- 배터리 조회 결과와 마지막으로 확인된 배터리 값
- 종료 원인: 정상 완료, 재시도 한도, 배터리 미확인, 저장공간 부족, 프로세스 오류 등

관측기는 모든 Opal 서비스를 복제하지 않고 우리 서비스와 관련 서비스만 기록한다. 변화가 없더라도 각 테스트의 구간 시작·종료와 최종 상태는 남겨야 하므로, 이벤트 로그와 타임라인 로그를 함께 보관한다.

## 7. 배터리와 저장공간

D810 배터리 표시는 연속적인 1% 값이 아니라 대략적인 구간 값이다. 따라서 `100 → 80 → 60`처럼 보일 수 있으며, 마지막으로 성공적으로 조회된 값을 직전 관측값으로 해석한다.

배터리 조회 실패와 배터리 부족은 구분한다.

- 값이 임계값 이하: 테스트를 정상 중단
- 일시적인 조회 실패: 즉시 전체 초기화하지 않고 해당 단계에서 재시도
- 연속 조회 실패: `battery_unknown`으로 중단하고 마지막 관측값을 함께 기록
- 카메라 전원 차단: 배터리 마지막 값, 마지막 성공 회차, 파일 생성 상태를 함께 분석

Opal의 writable overlay는 약 92.6MB 수준이며, Tailscale과 카메라 서비스가 함께 동작하면 여유 RAM도 제한적이다. 장시간 테스트에서 Opal에 이미지와 로그를 계속 쌓으면 저장공간 고갈이 발생할 수 있다. 이전 장시간 테스트에서는 저장공간이 100%까지 차서 후반부 결과를 오염시킬 가능성이 있었다.

따라서 Opal에는 서비스 실행에 필요한 최소 데이터와 전송 대기 중인 파일만 두고, 로그·백업·분석 자료는 가능한 즉시 PC로 옮긴 뒤 Opal에서 삭제한다. 현 시점 운영 목표는 약 5MB의 쿠션을 남기는 것이다.

## 8. 단방향 Outbox 백업

Samba 공유폴더나 양방향 파일시스템은 사용하지 않는다. Opal은 보관함이고 PC는 수집기다.

Opal producer:

```sh
/usr/bin/opal-outbox-enqueue /path/to/file category
```

이 명령은 `/root/d810-outbox`에 다음 순서로 파일을 만든다.

1. `.payload.part`로 복사
2. SHA-256과 크기를 계산
3. `.manifest.part` 작성
4. payload와 manifest를 완성 이름으로 원자적 이동
5. 마지막에 `.ready` marker 생성

`.ready`가 보이는 항목만 완성된 전송 대상으로 취급한다. 전송 중 연결이 끊기면 Opal의 원본 대기 항목을 유지하고 다음 실행에서 다시 시도한다. 현재 구현은 복잡도를 낮추기 위해 중단 지점부터 이어받기보다 해당 파일을 처음부터 재전송한다.

PC collector:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "E:\Underlab_APP\Camera\deploy\scripts\pull-opal-outbox.ps1"
```

수집기는 Tailscale RSA 키를 사용하고, 자체 프로세스 우선순위를 `BelowNormal`로 낮춘다. 다운로드 후 SHA-256을 비교하고, 일치할 때만 로컬 파일을 확정한 뒤 Opal의 payload·manifest·ready를 ACK 삭제한다. 중복 실행은 `.pull.lock`으로 막는다.

Opal에는 SFTP 서버가 없으므로 현재 수집기는 Windows OpenSSH의 legacy SCP(`scp -O`)를 사용한다. 이 구조는 실시간 공유가 아니라 낮은 우선순위의 지연 가능한 백업에 적합하다.

## 9. 이전 테스트에서 확인된 사실

- 직렬화된 부팅·초기화 구조는 정상적으로 먹혔다.
- 장시간 테스트는 약 895회까지 진행되었으나, 배터리 소진과 저장공간 고갈이 섞여 후반부를 순수한 소프트웨어 결과로 보기 어렵다.
- 마지막으로 확인된 배터리 값은 80%였고, 실제 카메라 전원은 이후 꺼진 것으로 해석된다.
- `100N`과 `102N` 세션에 이미지가 생성되었고, `102N`에는 NEF도 함께 있었다.
- 라이브뷰·UI 셔터·연사·물리 셔터의 경로가 서로 다르므로 한 기능의 성공이 다른 기능의 성공을 보장하지 않는다.
- 현장 문제는 설치·부팅 초기의 서비스 준비 순서, 카메라 인식 시점, 백엔드 상태 오염, 저장공간·배터리 조건이 결합해 나타날 수 있다.

## 10. 운영 체크리스트

### 테스트 전

- 카메라 전원과 배터리 상태 확인
- SD 카드와 Opal 저장공간 확인
- `001` 세션의 이전 결과를 PC로 백업
- Opal의 로그·백업 임시파일 정리
- Tailscale은 STA와 control plane 확인 후에만 활성화
- outbox 수집기를 낮은 우선순위로 실행

### 테스트 중

- 세션을 임의로 변경하지 않음
- 앞단 성공 상태를 보존하고 실패 단계만 재시도
- 단계별 시간·배터리·저장공간·프로세스 상태 기록
- ready marker가 없는 `.part` 파일을 결과로 해석하지 않음
- 카메라가 사라지면 마지막 성공 회차와 마지막 배터리 관측값을 기준으로 분석

### 테스트 후

- Opal outbox를 비우고 PC checksum 확인
- 세션 001의 파일 수·크기·생성 패턴 비교
- 실패 단계별 분포와 재시도 횟수 집계
- 배터리·저장공간·USB 분리 여부를 소프트웨어 실패와 분리
- 현장 재현 실패 시 하드웨어 가능성을 우선순위에 올리되, 전원·케이블·카메라 연결해제는 별도 항목으로 남김

## 11. 현재 남은 항목

- PuTTYgen으로 SSID RSA 개인키를 `.ppk`로 변환한 뒤 PuTTY GUI 접속을 최종 검증
- 배터리 조회가 포함된 최신 카메라 루너를 Opal에 다시 배포하고 단회 smoke test
- 로그·세션 생성부에 `opal-outbox-enqueue`를 연결하되, 카메라 명령보다 낮은 우선순위를 유지
- outbox 재전송을 계속 사용할지, 파일 크기가 큰 경우에만 재개 기능을 추가할지 결정
- 전원이 켜진 Opal에서 카메라 USB를 분리·재연결하는 하드웨어 경로는 소프트웨어 테스트와 분리하여 별도 검증

## 관련 파일

- `deploy/scripts/tailscale-sta-trigger.sh`
- `deploy/openwrt/95-tailscale-sta-hotplug`
- `deploy/scripts/opal-outbox-enqueue.sh`
- `deploy/scripts/pull-opal-outbox.ps1`
- `deploy/scripts/opal-camera-loop-runner.sh`
- `deploy/scripts/opal-camera-loop-launch.sh`
- `deploy/scripts/generate-opal-rsa-keys.cmd`
- `deploy/scripts/convert-opal-rsa-to-pem.cmd`
- `artifacts/ssh/`
- `artifacts/opal-test-backups/20260811-001613/`
- `artifacts/opal-storage-backup-20260811/`
