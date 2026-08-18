# 계층형 파이프라인 장애 테스트 모델

## 핵심 구조

```text
D810 → ddserver → session manager/bridge → S10 → 최종 판정
```

이 큰 흐름은 항상 순서를 보존한다. 각 계층 내부에서는 독립적인 미세 사건 순서를 세지 않고, 그 계층이 다음 경계에 전달하는 상태를 하나의 조건으로 취급한다.

## 계층별 조건

| 계층 | 조건 수 | 조건 |
|---|---:|---|
| D810 | 4 | 정상, 대기 복귀, USB 재연결, 전원 재인가 복구 |
| ddserver | 3 | 정상, TERM 후 복구, 요청 중 서비스 재시작 |
| session manager | 4 | 정상, bridge 복구, stale 세션 repair, WebSocket 재연결 |
| S10 | 4 | foreground, Wi-Fi 재연결, background 복귀, force-stop 후 재실행 |

네 계층은 `4 × 3 × 4 × 4 = 192개` 조합을 전부 실행표에 남긴다. 따라서 특정 계층 조합을 페어와이즈로 생략하지 않는다.

운영 모드 2개, 로그 조건 3개, 전송 조건 3개는 192개 행에 분산 배치한다. 이 보조 조건들은 유효한 모든 2-way 조합이 최소 한 번 나타나도록 검산한다. WebSocket 재연결은 liveview에서만 허용한다.

## 순서를 별도로 보존하는 경쟁 조건

모든 내부 사건을 순열화하지 않고, 실제 공유 자원이나 경계 경쟁이 있는 12개만 별도 사건열로 둔다.

- 요청과 ddserver 종료의 앞뒤 관계
- 요청 도중 bridge 종료
- guardian과 session-health의 복구 경쟁
- S10 재연결과 세션 재생성의 앞뒤·동시 관계
- checkpoint 중 강제 재부팅
- 전송 중 puller 종료와 stale lock 복구
- 로그 회전과 checkpoint의 중첩

## 최종 크기와 보장

- 4계층 전체 조합: 192개
- 순서 의존 경쟁 조건: 12개
- 보조 조건 페어 커버: 100%
- 최종 실행표: 생성 결과 기준 약 204개이며, 보조 페어 보완 행이 필요하면 자동으로 소수 추가된다.
- 과전류와 저장소 완전 고갈은 포함하지 않는다.

## 셔터 금지 정책

대표 204개와 향후 3,024개 전체 교차 실행에서는 실제 `SHOT` 명령과 물리 셔터 작동을 사용하지 않는다. 따라서 이 캠페인으로 증가하는 의도된 셔터 카운트는 0회다.

파이프라인 생존과 복구는 다음 비촬영 관찰로 판정한다.

- `manual-status`와 카메라 Ready 상태
- USB/PTP 세션 개방과 재개방
- liveview 시작·프레임 수신·정지
- bridge/WebSocket 응답 및 단일 인스턴스 확인
- checkpoint, outbox, 전송 해시와 ACK 완결성

실제 촬영 기능은 이 전수 캠페인과 분리하고, 최종 승인 단계에서만 최소 횟수로 검증한다.

이 모델은 모든 미세 이력을 전수 조사하지 않는다. 대신 네 계층의 모든 고차 조합, 보조 환경의 모든 2-way 관계, 알려진 순서 의존 경계를 동시에 보존한다.

## 산출물

- 생성기: `deploy/scripts/generate-chaos-pipeline-suite.py`
- 검산: `deploy/scripts/test-chaos-pipeline-suite.py`
- 실행표: `docs/chaos-hierarchical-pipeline-suite-seed810.csv`
- 재개 가능한 실행기: `deploy/scripts/invoke-chaos-pipeline-suite.ps1`

## 중단과 재개

실행기는 각 케이스를 10개 단계로 나누고 단계가 끝날 때마다 `state.json`을 임시 파일에서 원자적으로 교체한다. 완료된 케이스는 개별 JSON 결과가 존재하므로 재실행하지 않는다. 중단된 케이스는 마지막 미완료 단계부터 다시 시작한다.

```powershell
# 새 캠페인
powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy\scripts\invoke-chaos-pipeline-suite.ps1 `
  -RunId pipeline-204-seed810-20260815

# 같은 캠페인 재개
powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy\scripts\invoke-chaos-pipeline-suite.ps1 `
  -RunId pipeline-204-seed810-20260815

# 가장 최근 캠페인 재개
powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy\scripts\invoke-chaos-pipeline-suite.ps1 `
  -ResumeLatest
```

D810 USB 재연결·전원 재인가와 S10 Wi-Fi 재연결은 `WAITING` 체크포인트에서 멈춘다. 사용자가 해당 조작을 완료한 뒤 같은 run ID와 `-ConfirmManualCase <case_id>`로 재개한다. 실행표 SHA-256이 시작 후 바뀌면 안전하지 않은 재개를 거부한다.
