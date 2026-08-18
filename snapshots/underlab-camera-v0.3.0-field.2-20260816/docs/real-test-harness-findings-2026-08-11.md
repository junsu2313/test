# 실전형 테스터 보완 및 중간 실행 결과

검증일: 2026-08-11

## 이번에 추가한 범위

- 실제 S10 `192.168.8.165`의 연결 상태를 preflight와 매 회차 전후에 확인
- 일시적인 ARP 지연을 흡수하기 위해 S10 probe를 최대 3회 재시도
- 배터리는 회차마다 읽지 않고 10분 주기로만 새로 조회
- 이전 배터리 파일값을 현재값으로 복원하지 않음
- 촬영 후 `capture-event`, `captured-preview`, `captured-object` 확인
- 회차별 저장공간 여유와 최소 쿠션 기록
- 기존 session-manager와 action-v21 잔류 프로세스를 stack 종료 대상에 포함
- 테스트 중단 후 nginx·ddserver·session-manager를 다시 올리는 cleanup 보강

## 현재 가상 클라이언트의 범위

자동 기능 호출은 여전히 Opal 내부의 가상 클라이언트 `192.168.8.250`이 수행한다. S10은 실제 SSID peer로 연결 상태를 감시하지만, S10 화면에서 사용자가 누르는 UI 입력을 원격으로 재현하지는 않는다. 따라서 이 테스트는 “실제 S10이 켜져 있고 같은 무선망에 붙어 있는 상태에서 Opal 서비스가 안정적인가”를 검증하며, S10 앱 UI의 렌더링·터치·WebSocket 재연결까지 검증하지는 않는다.

## 중간 실행 결과

- 첫 실행 `20260811-181626`: stack 종료와 USB 재연결은 성공했으나 S10이 client 단계 직전에 끊겨 `s10_disconnected`로 종료
- 두 번째 실행 `20260811-181857`: preflight에서 S10 1회 판정 실패
- 세 번째 실행 `20260811-182027`: 3회 재시도 후에도 S10 preflight 실패
- 이후 수동 확인에서는 S10 ping이 다시 성공했지만 ARP 상태가 `FAILED`로 바뀌었다가 회복되는 흔적 확인
- 실행 중단 후 Opal 서비스가 내려가는 cleanup 누락이 발견되어 보완

이 결과는 카메라 기능의 20회 신뢰도 결과가 아니다. 현재 우선 확인된 것은 S10 무선 연결 안정성과 테스트 하네스의 중단 복구력이다.

## 다음 실행 조건

S10이 일정 시간 연결된 상태에서 다시 20회를 실행한다. 유효한 기능 결과로 인정하려면 다음을 만족해야 한다.

- preflight 통과
- 각 회차의 `s10.tsv` pre/post가 PASS
- `timings.tsv`, `battery.tsv`, `storage.tsv` 모두 생성
- 라이브뷰·WebSocket·HTTP 프레임·AF·단발 셔터·연사·capture-event·preview·원본 결과 확인
- 중단 시 Opal이 Ready 상태로 자동 복구

관련 결과는 각 run 디렉터리의 `summary.tsv`와 `loop-XX/steps.tsv`에서 확인한다.
