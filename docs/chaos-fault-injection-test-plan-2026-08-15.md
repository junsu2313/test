# D810 원격 촬영 시스템 단기 트러블 인젝션 테스트 계획

- 작성일: 2026-08-15
- 대상: Nikon D810, GL.iNet Opal(GL-SFT1200), Galaxy S10, Windows PC
- 목적: 장시간 무작정 반복하는 대신, 짧고 재현 가능한 장애를 각 계층에 주입하여 감지·복구·로그 보존 능력을 검증한다.
- 기본 원칙: 셔터를 누르지 않는 테스트를 우선하며, 실제 촬영 검증은 별도 승인 후 최소 횟수로 수행한다.

## 1. 테스트가 증명해야 하는 것

이 캠페인의 목표는 장애가 전혀 발생하지 않는다는 것을 증명하는 것이 아니다. 다음 네 가지를 증명하는 것이 목표다.

1. 장애가 발생하면 시스템이 정확한 계층과 상태를 기록한다.
2. 복구 가능한 장애는 제한 시간 안에 자동 복구한다.
3. 자동 복구가 불가능하면 추가 장애를 겹치지 않고 안전하게 멈춘다.
4. 중단·재부팅·네트워크 단절이 있어도 사건 로그가 최종적으로 PC까지 전달된다.

## 2. 계층과 관찰 대상

| 계층 | 주요 구성 | 관찰 항목 |
|---|---|---|
| 카메라 | D810, USB/PTP 세션 | USB 인식, `cameraDetected`, `transportReady`, `sessionCondition` |
| Opal 런타임 | ddserver, bridge, WebSocket | PID, 중복 프로세스, 응답 상태, 복구시간 |
| Opal 감시 | runtime guardian, session-health, boot-watch | 감지 시점, 재기동 여부, PID 파일 정합성 |
| S10 앱 | Flutter 앱, Android 생명주기 | 앱 재시작, 요청 재개, 로컬 JSONL 기록 |
| 네트워크 | Opal AP, S10 Wi-Fi, Tailscale | 연결 이탈·복귀, 로컬/Tailscale 경로 |
| 로그·저장 | field events, checkpoint, outbox | trace 누락, 중복, 회전, 적체, SHA-256 |
| PC 수집 | outbox puller | worker 생존, stale lock, 최신 로그 우선 회수 |

시간이 서로 달라도 `traceId`와 `commandId`를 기준으로 같은 사건을 연결한다.

## 3. 공통 안전 조건

### 시작 조건

- Opal은 안정적인 5V/3A 전원 또는 검증된 보조배터리로 동작한다.
- D810 USB 케이블과 단자가 고정되어 있으며 비정상 발열이 없다.
- Opal에서 Nikon USB 장치가 1개 인식된다.
- 상태 API가 다음 조건을 모두 만족한다.
  - `ok=true`
  - `cameraDetected=true`
  - `transportReady=true`
  - `softwareReady=true`
  - `status=ready`
- bridge, WebSocket, ddserver, runtime guardian, session-health, battery worker, boot-watch가 각각 한 개만 실행된다.
- PC outbox puller가 실행 중이고 stale lock이 없다.

### 즉시 중단 조건

- 커널 로그에 `Overcurrent`가 한 번이라도 새로 발생한다.
- USB 장치 수가 0이 된 뒤 60초 안에 돌아오지 않는다.
- Opal, 케이블 또는 카메라 단자에서 비정상 발열·냄새·변색이 확인된다.
- 저장공간이 사전 설정한 최소 여유 공간 아래로 내려간다.
- 같은 복구가 두 번 연속 실패한다.
- Opal 재부팅 후에도 카메라가 Ready로 돌아오지 않는다.

과전류는 테스트 항목으로 의도적으로 만들지 않는다. 과전류 후에는 자동 재부팅을 반복하지 않고 Opal 전원을 끈 뒤 수동 점검한다.

## 4. 공통 판정 체계

| 판정 | 의미 |
|---|---|
| PASS | 프로세스와 카메라 명령 경로가 제한 시간 안에 완전히 복구되고 로그도 회수됨 |
| DEGRADED | 프로세스는 복구됐지만 카메라가 Ready가 아니거나 로그 전송이 지연됨 |
| FAIL | 제한 시간 내 복구되지 않거나 필수 로그가 누락·손상됨 |
| ABORT | 과전류, 발열, 저장공간 임계치 등 안전 조건 때문에 중단됨 |

단순히 HTTP가 `ok=true`인 것만으로 PASS 처리하지 않는다. 카메라 감지와 transport 준비 상태까지 확인한다.

## 5. 전체 실행 일정

| 단계 | 권장 시간 | 반복 |
|---|---:|---:|
| 1. 정상 기준선 | 20분 | 1회 |
| 2. 단일 장애 | 45~60분 | 항목별 1~2회 |
| 3. 연결 장애 | 30~40분 | 항목별 1회 |
| 4. 자원 장애 | 30분 | 항목별 1회 |
| 5. 타이밍 장애 | 30~40분 | 항목별 1회 |
| 6. 복합 장애 | 40~60분 | 선정 조합별 1회 |
| 7. 단기 무작위 | 60~90분 | seed 2개 |

전체를 하루에 몰아서 진행할 필요는 없다. 1~3단계와 4~7단계를 나누어 실행해도 된다.

---

## 6. 1단계: 정상 기준선

### 목적

장애를 넣기 전 시스템이 이미 불완전한 상태인지 확인하고, 정상 상태의 응답시간·메모리·로그량을 기준값으로 확보한다.

### 방법

1. Opal, D810, S10을 실제 사용 구성으로 연결한다.
2. S10 앱을 실행하되 라이브뷰와 셔터는 사용하지 않는다.
3. 20분 동안 10초 간격으로 상태를 수집한다.
4. 1분 간격으로 프로세스 PID, 메모리, 저장공간, outbox 개수를 기록한다.
5. 2분 간격으로 `manual-status`를 실행하여 명령 경로가 유휴 후에도 살아 있는지 확인한다.
6. 시작과 종료에 checkpoint를 실행하고 PC 수집본의 SHA-256을 확인한다.

### 관찰값

- 상태 API 성공률과 응답시간 p50/p95/max
- PID 변경 및 중복 프로세스 발생 여부
- Opal 가용 메모리와 저장공간 변화량
- field event 두 줄(`action_received`, `action_completed`)의 쌍 완성률
- Opal outbox 생성 시각과 PC 도착 시각의 차이

### 합격 기준

- 20분 동안 카메라 Ready 유지
- 필수 프로세스 중단·중복 0회
- trace 누락 0건, manifest 해시 불일치 0건
- outbox 적체가 계속 증가하지 않음

---

## 7. 2단계: 단일 장애

### 목적

각 구성요소 하나가 사라졌을 때 감시 계층이 장애를 감지하고 필요한 범위만 복구하는지 검증한다.

### 시나리오

| ID | 장애 | 주입 방법 | 기대 복구 | 제한 시간 |
|---|---|---|---|---:|
| S2-01 | bridge 종료 | PID에 TERM | runtime guardian 또는 action guard가 bridge 재기동 | 45초 |
| S2-02 | WebSocket 종료 | PID에 TERM | guardian이 WebSocket 재기동 | 20초 |
| S2-03 | ddserver 종료 | PID에 TERM | init/복구 경로가 ddserver와 PTP 세션 복구 | 60초 |
| S2-04 | runtime guardian 종료 | PID에 TERM | 다음 action 또는 서비스 관리 경로에서 단일 인스턴스 재기동 | 30초 |
| S2-05 | session-health 종료 | PID에 TERM | runtime guardian이 재기동 | 45초 |
| S2-06 | battery worker 종료 | PID에 TERM | runtime guardian 또는 action guard가 재기동 | 45초 |
| S2-07 | boot-watch 종료 | 서비스 프로세스에 TERM | procd가 재기동 | 20초 |
| S2-08 | S10 앱 강제 종료 | Android force-stop | 재실행 후 Ready 및 로컬 로그 재개 | 60초 |
| S2-09 | PC puller 종료 | worker 종료 | stale lock 회수 후 재시작·backlog 회수 | 60초 |

### 실행 순서

1. 각 항목 직전에 새 trace를 기록한다.
2. 장애를 하나만 주입한다.
3. 처음 15초는 passive recovery를 기다린다.
4. 미복구 상태라면 `manual-status` 한 번으로 실제 사용자 action guard를 작동시킨다.
5. 제한 시간까지 Ready가 아니면 FAIL로 기록하고 다음 장애를 넣지 않는다.
6. 복구 후 2분 동안 안정 상태를 확인한 뒤 다음 항목으로 넘어간다.

### 주의

ddserver 종료 후 프로세스만 살아났다고 PASS 처리하지 않는다. Nikon USB 인식과 PTP transport까지 돌아와야 한다. USB `Overcurrent`가 발생하면 즉시 ABORT한다.

---

## 8. 3단계: 연결 장애

### 목적

카메라 서비스 자체가 정상인 상태에서 클라이언트와 관리 경로가 끊겼다가 복귀하는 동작을 확인한다.

### 시나리오

| ID | 장애 | 방법 | 기대 결과 |
|---|---|---|---|
| S3-01 | S10 Wi-Fi 이탈 | S10 Wi-Fi OFF 30초 후 ON | Opal 서비스 유지, 앱 재접속, 사건 로그 연속성 유지 |
| S3-02 | S10 앱 백그라운드 | 화면 OFF 또는 홈 이동 2분 | Opal 세션 폭증 없음, 복귀 후 명령 가능 |
| S3-03 | PC 단절 | PC를 Opal 네트워크에서 3분 분리 | outbox에 적체 후 PC 복귀 시 자동 회수 |
| S3-04 | Tailscale 단절 | PC는 로컬 AP 유지, Tailscale 경로만 중단 | 촬영 경로 영향 없음, 관리 경로 복귀 |
| S3-05 | Opal AP 재연결 | S10만 AP에서 이탈 후 재접속 | IP 변경 여부와 무관하게 앱 복귀 |
| S3-06 | Opal 재부팅 | 정상 trace 직후 `reboot -f` | boot-watch 시작, checkpoint, PC 자동 전송 |

### 실행 원칙

- S10과 PC를 동시에 끊지 않는다.
- Opal 재부팅은 최대 2회까지만 허용한다.
- 강제 재부팅 시험은 `sync`를 넣는 경우와 넣지 않는 경우를 구분한다.
- PC 부재 중 outbox payload를 원격에서 직접 읽지 않고, 복귀 후 PC 자동 수집본으로 판정한다.

### 합격 기준

- 연결 복귀 후 새 앱 설치나 설정 변경 없이 Ready 복귀
- 세션·worker가 중복 생성되지 않음
- PC 부재 중 생성된 trace가 나중에 해시 일치 상태로 회수됨

---

## 9. 4단계: 자원 장애

### 목적

메모리, 저장공간, 로그량, 전송 backlog가 증가해도 핵심 촬영 경로가 유지되는지 확인한다.

### 시나리오

| ID | 장애 | 안전한 주입 방법 | 중단 임계치 |
|---|---|---|---|
| S4-01 | trace 로그 증가 | 셔터 없는 `action=trace` 반복 | 로그 회전 확인 즉시 종료 |
| S4-02 | checkpoint 경쟁 | checkpoint 6개 동시 실행 | lock 오류·중복 손상 발생 시 중단 |
| S4-03 | outbox 적체 | PC puller를 10분 정지 | Opal 최소 여유 공간 도달 전 종료 |
| S4-04 | puller backlog | 오래된 ready와 최신 field event 혼합 | 최신 field event가 우선 회수되지 않으면 FAIL |
| S4-05 | 제한적 메모리 압박 | 가용 메모리를 안전 범위까지만 점진적으로 사용 | 가용 메모리 20MB 미만 전에 종료 |
| S4-06 | 로그 회전 | field log 회전 크기 근처까지 trace 생성 | 원본·회전본 모두 파싱 가능해야 함 |

### 금지 사항

- 루트 파일시스템을 실제로 100% 채우지 않는다.
- swap 폭주나 OOM killer 발생을 목표로 하지 않는다.
- 카메라 명령을 병렬 폭주시키지 않는다.

### 합격 기준

- log rotation 중 trace 쌍이 찢어지지 않음
- checkpoint manifest와 payload SHA-256 일치
- puller 재시작 후 backlog가 감소함
- 자원 부하 제거 후 별도 재부팅 없이 정상 수준으로 복귀

---

## 10. 5단계: 타이밍 장애

### 목적

정상 상태보다 경계 시점에서 발생하는 경쟁 조건과 부분 기록을 검증한다.

### 시나리오

| ID | 경계 시점 | 장애 주입 | 확인 대상 |
|---|---|---|---|
| S5-01 | `manual-status` 처리 중 | bridge TERM | 요청 결과, action guard, trace 완성 |
| S5-02 | WebSocket 응답 중 | WebSocket TERM | 재접속과 중복 worker |
| S5-03 | checkpoint 실행 중 | Opal 강제 재부팅 | `.part` 파일, ready 원자성, 부팅 회수 |
| S5-04 | PC payload 다운로드 중 | puller 종료 | `.payload.part` 정리와 재다운로드 |
| S5-05 | guardian 교체 중 | 이전 guardian TERM | 새 PID 파일 소유권 보존 |
| S5-06 | 부팅 직후 | S10 조기 접속 | 서비스 준비 전 요청이 최종 Ready로 수렴 |

### 방법

- 각 사건에는 고정 trace와 단계 이름을 넣는다.
- 장애 직전과 직후에 원격 파일을 읽어 OS 캐시를 교란하지 않는다.
- 재부팅 테스트에서는 checkpoint를 의도한 경우에만 `sync`를 사용한다.
- 요청 실패 자체보다 최종 상태와 로그의 상관관계가 정확한지를 판정한다.

### 합격 기준

- `.part` 또는 고아 lock이 다음 실행을 영구 차단하지 않음
- 같은 PID 파일을 여러 프로세스가 소유하지 않음
- 실패한 요청도 `action_completed`에 FAIL 원인이 남음
- 복구 후 다음 정상 요청이 성공함

---

## 11. 6단계: 복합 장애

### 목적

모든 조합을 무차별 대입하지 않고, 서로 다른 계층을 가로지르는 대표적인 2중 장애를 검증한다.

### 우선 조합

| ID | 조합 | 이유 | 기대 결과 |
|---|---|---|---|
| S6-01 | bridge + WebSocket 종료 | 동일 세션의 제어·전송 동시 손실 | 단일 bridge 세션과 WebSocket 복귀 |
| S6-02 | bridge + ddserver 종료 | PTP 계층 전체 손실 | 제한 시간 내 카메라 Ready 복귀 |
| S6-03 | runtime guardian + bridge 종료 | 감시자와 대상 동시 손실 | action guard가 복구 경로 제공 |
| S6-04 | PC 단절 + outbox 증가 | 현장 PC 부재 재현 | Opal 보존 후 PC 복귀 시 회수 |
| S6-05 | S10 Wi-Fi 이탈 + bridge 종료 | 클라이언트 부재 중 서버 장애 | S10 복귀 전에 서버가 정상화 |
| S6-06 | Opal 재부팅 + PC 부재 | 실제 이동 환경의 전원 복구 | 부팅 checkpoint 후 지연 전송 |
| S6-07 | checkpoint 경쟁 + trace 폭주 | 로그 생산·보존 동시 부하 | 누락·손상 없이 dedup |

### 실행 규칙

- 단일 장애 단계에서 각각 PASS한 항목만 조합한다.
- 같은 물리 계층의 위험을 증폭하는 조합은 제외한다.
- USB 과전류, 케이블 단락, 저장공간 완전 소진은 복합 장애에 포함하지 않는다.
- 한 조합이 FAIL이면 원인을 해결하기 전 다음 조합을 진행하지 않는다.

### 합격 기준

- 복구시간 90초 이내
- 최종 필수 프로세스가 각각 정확히 한 개
- 카메라 Ready와 다음 `manual-status` 성공
- 장애 전·중·후 trace가 PC에서 모두 검색됨

---

## 12. 7단계: 단기 무작위 조건

### 목적

정해진 순서의 테스트가 놓치는 상태 전이를 찾되, 긴 시간만 소비하는 soak 테스트는 피한다.

### 범위

- 실행시간: seed당 30~45분, 총 60~90분
- seed: 최소 2개 고정
- fault 간격: 2~5분 무작위
- 총 fault: seed당 8~12개
- 사용 fault: 2~6단계에서 이미 단독 PASS한 항목만 포함
- 동시 장애: 최대 2개
- Opal 재부팅: seed당 최대 1회

### 선택 방식

각 라운드는 다음 값을 seed 기반으로 결정한다.

1. 장애 종류
2. 장애 전 유휴 시간
3. passive recovery 대기시간
4. action guard 호출 여부
5. PC 연결 상태
6. checkpoint 실행 시점

같은 seed를 다시 사용하면 같은 순서가 재현되어야 한다.

### 감독 방식

- 첫 seed의 최초 15분은 사람이 현장에서 감독한다.
- 과전류·발열이 없고 안전 중단 기능이 동작하면 나머지는 로그 중심으로 관찰한다.
- 물리적 케이블 조작과 실제 전원 단락은 무작위 항목에 넣지 않는다.

### 합격 기준

- FAIL 및 ABORT 0건
- 모든 라운드의 trace 쌍 완성
- 복구시간 p95가 단계별 제한 안에 있음
- 중복 프로세스, stale lock, payload 해시 오류 0건
- 종료 후 5분 안정 관찰에서 Ready 유지

---

## 13. 자동화 도구와 현재 구현 상태

현재 `deploy/scripts/invoke-opal-chaos-soak.ps1`은 다음 기능을 제공한다.

- seed 기반 시나리오 선택
- 셔터 없는 trace burst
- checkpoint 경쟁
- bridge, WebSocket, ddserver, runtime guardian 단일 종료
- bridge+WebSocket, bridge+ddserver 복합 종료
- action 처리 중 bridge 종료
- passive recovery와 action-mediated recovery 구분
- 엄격한 카메라 Ready 판정
- JSONL 이벤트와 TSV 요약 기록

현재 도구에 추가해야 할 항목은 다음과 같다.

- 시나리오를 ID별로 선택하는 옵션
- S10 ADB 앱 종료·재실행 모듈
- PC puller 일시 정지·재개 모듈
- Tailscale/로컬 경로 전환 모듈
- 자원 사용량 임계치와 자동 ABORT
- 재부팅 후 Wi-Fi 재접속 및 캠페인 재개
- 최종 trace/manifest 자동 대조 보고서

## 14. 실행 명령 예시

### 짧은 harness 검증

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File deploy\scripts\invoke-opal-chaos-soak.ps1 `
  -DurationMinutes 10 `
  -MaxScenarios 3 `
  -QuietSeconds 5 `
  -Seed 815
```

### 7단계 단기 무작위 캠페인 예시

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File deploy\scripts\invoke-opal-chaos-soak.ps1 `
  -DurationMinutes 45 `
  -RecoveryTimeoutSeconds 90 `
  -QuietSeconds 120 `
  -Seed 81001
```

두 번째 seed는 `81002`를 사용한다. 실제 실행 전에는 시나리오 선택과 재부팅 횟수 제한 기능을 도구에 추가한다.

## 15. 결과 산출물

각 캠페인은 최소한 다음 파일을 남긴다.

- `<runId>-events.jsonl`: 모든 fault·복구·판정 사건
- `<runId>-summary.tsv`: 시나리오별 결과와 복구시간
- Opal field event payload와 manifest
- boot-watch timeline
- 활성 session의 bridge/WebSocket 로그
- 테스트 시작·종료 상태 snapshot

각 요약 행은 다음 필드를 가져야 한다.

```text
runId, seed, scenarioId, traceId, injectedAt, detectedAt,
recoveredAt, recoveryMode, recoveryMs, finalCameraState,
logRecovered, hashMatched, result, errorCode
```

## 16. 최종 종료 기준

다음 조건을 모두 만족하면 짧은 트러블 인젝션 캠페인을 완료한 것으로 본다.

1. 1~5단계 필수 시나리오가 모두 PASS한다.
2. 선정한 6단계 복합 장애가 모두 PASS한다.
3. 7단계 seed 두 개가 FAIL 없이 완료된다.
4. 과전류와 물리적 안전 중단이 발생하지 않는다.
5. trace 누락과 payload 해시 오류가 없다.
6. 캠페인 종료 후 시스템이 별도 수동 초기화 없이 Ready를 유지한다.

이 조건을 통과한 뒤에는 긴 인공 soak를 추가하기보다 실제 천문촬영에서 자연 발생하는 장시간 유휴, 온도 변화, 배터리 소모, Wi-Fi 이동을 관찰하는 편이 더 효과적이다.
