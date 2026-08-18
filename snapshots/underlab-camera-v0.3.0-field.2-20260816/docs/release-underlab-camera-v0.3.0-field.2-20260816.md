# Underlab Camera v0.3.0-field.2

Release lock: `FieldLock-20260816`

이 릴리스는 S10–Opal–D810 전 구간의 안정성·지연 계측과 로그/Tailscale
스케줄링 최적화를 반영한 두 번째 현장 기준판이다.

## 구성

- Flutter 앱: `0.3.0-field.2+20260816` / Android versionCode `20260816`
- Opal remote-ui/runtime: `v21.3.0-field.2`
- ddserver: 현재 검증된 소스·OpenWrt 패키징
- 전체 묶음: `underlab-camera-v0.3.0-field.2-20260816`

## 고정된 정상 조건

- 카메라와 Opal API는 Opal SSID 로컬 경로를 유지한다.
- 메인 PC 로그·제어 경로만 Tailscale을 사용한다.
- 라이브뷰는 대체로 54–60 FPS이며 가짜 프레임과 확인된 ID 누락이 없다.
- 촬영·썸네일·원본 JPEG 실제 경로는 전 구간 10/10 성공했다.
- 정상 상태 확인과 건강한 복구는 queue-free 빠른 경로를 사용한다.
- 로그 체크포인트와 PC 전송은 라이브뷰 중 보류되고 유휴 시 재개된다.
- 최종 검증 상태는 ready, live off, frame failure 0, reconnect 0이다.
- AF 슬라이더는 라이브뷰 OFF에서도 PREP→SHUTTER 순서를 유지하며 실제 촬영과
  새 썸네일 표시를 완료한다.
- D810이 촬영 후 반환하는 `0xA003` 제어 해제 응답은 이미 완료된 촬영을
  실패로 뒤집지 않으며, 구조화된 Nikon 오류는 원문 상태로 전달된다.
- 릴리즈 임계점의 중복 `shutter-hold-start` 왕복을 제거해 S10 실측
  촬영 완료 지연을 약 4.26초에서 3.49초로 줄였다.

## 판정 주의사항

- 과거 하네스의 `capture-event` FAIL은 실제 촬영 실패가 아니라 이미 소비된
  이벤트를 다시 검사한 판정 불일치다.
- 68–130초 수치는 오팔 부팅이 아니라 USB 장애를 강제로 만든 전체 카메라
  스택 복구 시험이다.
- 약 8MB 원본 JPEG 18–20초는 D810 물리 전송 구간이며 썸네일은 먼저 표시된다.

## 스냅샷

- `snapshots/underlab-camera-v0.3.0-field.2-20260816/`
- 파일 무결성은 스냅샷 루트의 `SHA256SUMS.txt`로 검증한다.
