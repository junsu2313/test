# S10 연결 상태 전체 기능 검증 기록

검증일: 2026-08-11 17:39–17:47 KST

## 조건

- Opal: `192.168.8.1`
- S10: `192.168.8.165`, SSID 연결 및 전원 상태 확인
- 카메라: Nikon D810, USB/PTP 연결
- 카메라 설정: M, 사진 모드
- 배터리: 40%
- Opal 저장공간: 22.9MB free, 74% 사용
- 현재 세션: `002_session`

## 결과 요약

| 기능 | 결과 | 근거 |
|---|---|---|
| S10 SSID 연결 | PASS | ARP reachable, ping 3/3, packet loss 0% |
| 카메라 USB 인식 | PASS | `gphoto2 --auto-detect`에서 D810 확인 |
| 배터리 조회 | PASS | 40% 반환 |
| 상태 API | PASS | `cameraDetected=true`, `transportReady=true` |
| 세션 복구 | PASS | `action-v21?action=recover` 성공, frameFailures 0 복귀 |
| 라이브뷰 시작 | BLOCKED | `camera is not in live view` / frame unavailable |
| 라이브뷰 프레임 | BLOCKED | frame endpoint HTTP 실패 |
| AF | BLOCKED | `camera could not acquire focus` |
| UI 셔터 | BLOCKED | AF 선행 실패로 촬영하지 않음 |
| 촬영 이벤트 | BLOCKED | `captureEventSeq=0`, `no_event` |
| 프리뷰·원본 | BLOCKED | 생성된 캡처가 없어 응답 파일 없음 |

## 관찰된 상태

상태 API는 카메라를 정상적으로 감지했지만 `LIVE_START` 후 첫 프레임을 얻지 못했다. D810의 `/main/actions/viewfinder` 값이 `0`인 것은 앱이 라이브뷰를 시작하기 전에는 정상일 수 있으므로, 물리 라이브뷰 버튼 미조작을 원인으로 단정하지 않는다. 앱의 `LIVE_START` 구현이 카메라 라이브뷰를 직접 시작해야 한다.

실패 이후 bridge가 PTP 장치를 점유한 상태가 남아 직접 `gphoto2`를 실행하면 `Could not claim the USB device: Resource busy`가 발생했다. 이는 카메라 미연결이 아니라 bridge/PTP 세션 점유 상태다.

## 세션 관찰

이번 검증은 `001_session`이 아니라 `002_session`에서 진행되었다. 따라서 “001 세션을 계속 유지한다”는 운영 목표는 아직 실제 실행 상태와 일치하지 않는다. 다음 테스트 전 세션 번호 정책을 먼저 확인해야 한다.

## 다음 검증 조건

1. 물리 라이브뷰 조작 없이 앱의 `LIVE_START` 경로만 시험한다.
2. Opal의 bridge가 PTP 장치를 점유한 상태에서 직접 `gphoto2`를 병행 실행하지 않는다.
3. bridge 로그에서 `Device Ready`, `LIVE_START` 응답 코드, 첫 `FRAME` 응답을 함께 수집한다.
4. `/cgi-bin/action-v21?action=live-on` 성공 후 프레임을 확인한다.
5. 프레임 확인 후 `af`, `shutter`, capture event, preview, captured object 순서로 실행한다.
6. 마지막에 `live-off`와 상태 API를 확인한다.
7. 결과 세션이 001인지 확인하고, 아니면 세션 생성·재사용 정책을 별도 수정 대상으로 기록한다.

이번 기록만으로는 라이브뷰·AF·셔터 기능의 소프트웨어 PASS/FAIL을 확정할 수 없다. 현재는 카메라의 실제 라이브뷰 미활성이라는 전제 조건이 충족되지 않은 상태다.

## 배터리 충전 후 재시험

같은 S10 연결 상태에서 배터리가 100%로 올라온 뒤, 물리 라이브뷰 조작 없이 동일한 순서를 다시 실행했다.

| 기능 | 결과 | 측정·응답 |
|---|---|---|
| `live-on` | PASS | `status=liveview_on`, 첫 프레임 약 452ms |
| 라이브뷰 프레임 | PASS | JPEG 35,139 bytes, `frameFailures=0` |
| AF | PASS | `status=ok`, `afResponseCode=8193` |
| UI 셔터 | PASS | `captureVerified=true`, 저장 8,162,062 bytes |
| 촬영 이벤트 | PASS | `captureEventSeq=1`, `captureComplete=true` |
| 캡처 프리뷰 | PASS | JPEG 9,352 bytes |
| 캡처 원본 | PASS | JPEG 8,162,062 bytes |
| 최종 상태 | PASS | `liveView=true`, `backendState=live`, `frameFailures=0` |

배터리 40% 표시·한 칸 상태에서 라이브뷰·AF·셔터가 연쇄 실패했고, 배터리 100%에서 모든 기능이 같은 순서로 성공했다. 이 비교 결과는 직전 실패의 우선 원인을 배터리/전원 안정성으로 분류하는 강한 근거다. 다만 완전한 확정을 위해 한 칸 상태와 완충 상태를 각각 여러 차례 반복하는 것이 좋다.
