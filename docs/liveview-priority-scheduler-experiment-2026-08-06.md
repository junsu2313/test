# Live-view priority scheduler experiment — 2026-08-06

1차 단계에서는 라이브뷰를 막는 작업량부터 줄였다.

- 사진별 ObjectInfo 선조회를 제거하고 폴더 단위 JPEG 핸들 목록으로 변경
- 라이브뷰 중 JPEG 핸들 목록: 0.416초
- 라이브뷰 중 선택 썸네일: 0.335초
- 실험 전후 frameFailures: 0 → 0
- liveView: true 유지
- S10 APK 빌드·설치·실행 확인 완료

다음 단계는 목록·썸네일·설정 변경을 중앙 우선순위 큐에 넣고, 라이브뷰 frame deadline이 부족한 경우 자동 보류하는 것이다.
