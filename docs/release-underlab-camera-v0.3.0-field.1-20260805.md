# Underlab Camera v0.3.0-field.1

Release lock: `FieldLock-20260805`

이 릴리스는 2026년 8월 5일 오프라인 출사 검증을 위해 고정한 첫 현장 후보판이다.

## 구성

- Flutter 앱: `0.3.0-field.1+20260805` / Android versionCode `30001`
- Opal remote-ui/runtime: `v21.3.0-field.1`
- ddserver: `0.2-15` frozen artifact
- 전체 묶음: `underlab-camera-v0.3.0-field.1-20260805`

## 고정 조건

- 외부 인터넷 없이 S10–Opal–D810 로컬망으로 동작
- 앱 실행만으로 LIVE를 시작하지 않음
- LIVE 60 FPS, AF, 셔터, 미리보기, STOP 검증 완료
- LIVE/STOP 경쟁, stale live 의도, WebSocket worker 누수 방어 적용
- Opal overlay 사용량 77% 수준으로 정리 완료

## 승격 규칙

출사 후 결함이 없으면 `v0.3.0-field.2`를 생략하고 `v0.3.0`으로 승격한다. 현장에서 문제가 발견되면 같은 기준선을 보존한 채 `field.2`로 분기한다.
