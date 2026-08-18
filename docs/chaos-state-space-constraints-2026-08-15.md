# D810 트러블 인젝션 상태공간 및 불가능 조합 제거

- 작성일: 2026-08-15
- 모델: 7계층, 26 factor, 33개 제약식
- 계산기: `deploy/scripts/calculate-chaos-state-space.py`
- 검산: `deploy/scripts/test-chaos-state-space.py`

## 1. 계산 결과

| 항목 | 조합 수 |
|---|---:|
| 제약 적용 전 | 187,861,869,527,040 |
| 불가능하여 제거 | 186,865,128,161,280 |
| 제약 적용 후 유효 | 996,741,365,760 |
| 유효 비율 | 0.530571408% |
| 제거 비율 | 99.469428592% |

따라서 불가능한 순간 상태를 제거한 뒤에도 약 9,967억 개의 논리적으로 가능한 상태가 남는다.

이 수치는 아래에 고정한 상태 구간과 제약식 안에서의 정확한 값이다. 배터리 퍼센트, 응답시간, 온도, 재시도 횟수 같은 연속값은 포함하지 않는다.

## 2. 상태공간 정의

| 계층 | factor | 상태 |
|---|---|---|
| 카메라·USB·PTP | `camera_power` | off, standby, awake |
|  | `usb_state` | absent, enumerating, present, overcurrent_latched |
|  | `ptp_state` | closed, opening, ready, busy, fault |
|  | `camera_mode` | body, remote_idle, liveview |
| Opal 런타임 | `ddserver_state` | stopped, starting, running |
|  | `bridge_process` | stopped, starting, running, hung |
|  | `backend_state` | idle, connecting, ready, live, degraded, recovering |
|  | `websocket_state` | stopped, connecting, running, stale |
|  | `session_state` | absent, booting, ready, recovering |
| 감시 계층 | `runtime_guardian` | stopped, running, stale_pid, duplicate |
|  | `session_health` | stopped, running, stale_pid, duplicate |
|  | `battery_worker` | stopped, running, stale_pid, duplicate |
|  | `boot_watch` | stopped, running, stale_pid, duplicate |
| S10 | `s10_app` | stopped, background, foreground |
|  | `s10_link` | disconnected, connecting, connected, recovering |
|  | `s10_power` | awake, screen_off, doze |
| 네트워크 | `s10_wifi` | disconnected, associating, healthy, degraded |
|  | `opal_ap` | down, up |
|  | `tailscale` | down, up |
|  | `pc_reachability` | offline, online |
| 로그·저장 | `event_writer` | idle, writing, rotating, failed |
|  | `checkpoint` | idle, running, contended, failed |
|  | `outbox` | empty, normal, backlogged, damaged |
|  | `storage` | normal, low, exhausted |
| PC 수집 | `puller` | stopped, running, hung, stale_lock |
|  | `transfer` | idle, downloading, verifying, retrying |

## 3. 불가능 조합 제거 기준

비정상 상태라는 이유만으로 제거하지 않는다. fault injection으로 실제 만들 수 있는 `프로세스 중단`, `stale PID`, `중복 프로세스`, `damaged outbox` 등은 모두 남긴다.

제거 대상은 같은 순간에 정의상 공존할 수 없는 상태다.

### 카메라·USB·PTP

1. 카메라 OFF와 USB enumerating/present는 공존할 수 없다.
2. USB absent/overcurrent-latched에서는 PTP opening/ready/busy가 될 수 없다.
3. PTP opening은 USB enumerating/present가 필요하다.
4. PTP ready/busy는 USB present와 카메라 awake가 필요하다.
5. remote-idle/liveview는 카메라 awake와 PTP ready/busy가 필요하다.
6. PTP opening은 ddserver starting/running이 필요하다.
7. PTP ready/busy는 ddserver running이 필요하다.
8. ddserver stopped에서는 PTP closed/fault만 가능하다.
9. ddserver starting에서는 PTP ready/busy가 불가능하다.

### bridge·backend·session

10. bridge stopped에서는 실제 backend를 idle로 정의한다.
11. bridge starting에서는 backend idle/connecting/recovering만 가능하다.
12. backend ready는 bridge running/hung, session ready, PTP ready/busy가 필요하다.
13. backend live는 위 조건과 camera liveview가 필요하다.
14. backend connecting은 session booting/recovering이 필요하다.
15. backend recovering은 session booting/ready/recovering이 필요하다.
16. session absent에서는 backend idle/degraded만 가능하다.
17. session recovering에서는 backend ready/live가 불가능하다.

### S10·네트워크

18. S10 앱 stopped에서는 link disconnected만 가능하다.
19. link connecting/connected/recovering에는 실행 중인 앱이 필요하다.
20. 단말 doze와 앱 foreground는 공존하지 않는다.
21. S10 Wi-Fi associating/healthy/degraded에는 Opal AP up이 필요하다.
22. S10 link connected에는 Wi-Fi healthy/degraded가 필요하다.
23. S10 link connecting에는 Wi-Fi associating/healthy/degraded가 필요하다.
24. PC online에는 Opal AP 또는 Tailscale 중 하나가 필요하다.

### 저장·전송

25. storage exhausted에서는 event writer writing/rotating이 불가능하다.
26. storage exhausted에서는 checkpoint running/contended가 불가능하다.
27. transfer non-idle에는 puller running/hung이 필요하다.
28. puller stopped/stale-lock에서는 transfer idle만 가능하다.
29. downloading/verifying에는 PC online이 필요하다.
30. downloading/verifying에는 non-empty outbox가 필요하다.
31. retrying에는 PC offline 또는 damaged outbox라는 원인이 필요하다.

코드에서는 위 복합 문장을 원자 조건으로 나누어 총 33개의 predicate로 계산한다.

## 4. 연결 성분별 검산

서로 제약으로 연결된 factor 집합을 독립적으로 계산한 뒤 곱했다.

| 연결 성분 | 제약 전 | 유효 |
|---|---:|---:|
| 카메라·USB·PTP·ddserver·bridge·session | 51,840 | 2,898 |
| S10·네트워크·outbox·puller·transfer | 73,728 | 9,330 |
| storage·writer·checkpoint | 48 | 36 |
| 독립 4상태 factor 5개 | 1,024 | 1,024 |

```text
2,898 × 9,330 × 36 × 1,024
= 996,741,365,760
```

독립 factor는 WebSocket과 감시 프로세스 4개다. 장애 주입 중에는 이들이 다른 계층의 상태와 무관하게 stopped/running/stale/duplicate가 될 수 있으므로 추가 제거하지 않았다.

## 5. 재현 명령

```powershell
python deploy\scripts\calculate-chaos-state-space.py
python deploy\scripts\test-chaos-state-space.py
```

JSON 결과가 필요하면 다음을 사용한다.

```powershell
python deploy\scripts\calculate-chaos-state-space.py --json
```

## 6. 다음 계산 단계

다음 단계에서는 996,741,365,760개의 유효 상태를 직접 열거하지 않는다.

1. 정상 기준 상태를 하나 지정한다.
2. 각 factor의 fault state와 운용 mode를 분리한다.
3. 같은 효과를 내는 대칭·중복 상태를 합친다.
4. 제약식을 유지한 constrained pairwise covering array를 생성한다.
5. 위험도가 높은 3-way와 시간 순서 A→B/B→A를 별도로 추가한다.

이 과정을 거쳐야 실제 실행 가능한 테스트 행의 정확한 개수를 산출할 수 있다.
