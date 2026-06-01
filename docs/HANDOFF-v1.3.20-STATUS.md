# 핸드오프 — v1.3.20 상태 (2026-06-02)

브랜치: `feat/v1.3.18-launch-boot-refactor` (main 대비 다수 커밋, 미머지).

## 1. 지금 상태: ✅ MS Store 제출 완료 (2026-06-02, 인증/게시 대기)

- `medical_recorder.msix` = **1.3.20.0** (Build 31), ffmpeg 번들 포함 — Partner Center 업로드·제출 완료
- `flutter analyze` error 0 (info 3건은 사전 deprecation, 무관)
- 단위 테스트 **22종** 통과 (async_lock / schedule_model / schedule_templates)
- `flutter build windows --release` + `dart run msix:create` 성공
- `scripts/preflight/verify-msix.ps1` 전 항목 OK (버전 1.3.20.0 / StartupTask /
  capability / ffmpeg)
- 업로드한 파일:
  `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix`
- 제출 프롬프트: `docs/MS-STORE-SUBMISSION-v1.3.20-BROWSER-CLAUDE-PROMPT.md`

**게시 후 확인:** Store에서 업데이트 받은 뒤 — (1) 시간표 빠른설정 요일 정상(평일=월~금),
12시간제 표시, 시간 칩 탭→선택기. (2) 앱 아이콘 선명(타일/검색). (3) 녹음 시작/정지/분할
정상. (부팅·트레이는 1.3.19에서 미변경 → 재검증 불필요.) 개발 PC 비패키지 exe 미리보기로
시간표·아이콘은 이미 확인함(2026-06-02).

**버전 정책:** Store는 동일 버전 재업로드 차단 + revision(4번째)=0 강제. 1.3.19가
게시됐으므로 build 자리를 올려 **1.3.20.0**. 다음엔 1.3.21.0 식.

## 2. v1.3.20에 들어간 것 (이번 리팩토링 세션)

**오디오 안정성 (가장 중요)**
- 세그먼트 정지/분할 상태머신 치명 버그 3건 수정: 재시작 실패 시 무음 데이터손실,
  분할↔정지 고아 녹음 세션 경쟁, 정지 실패 시 끼인 상태. AsyncLock 직렬화 +
  onRecordingAborted 통지 + finally 정리. (`lib/services/audio_service.dart`,
  `lib/utils/async_lock.dart`)

**시간표 (사용자 보고 버그)**
- 빠른설정 템플릿 요일 오프바이원 수정(0=월 착각 → "금요일 휴무·일요일 근무" 해소).
- 기본 시간표를 흔한 패턴으로(월~금 9-13/14-18, 토 9-13, 일 휴무; 월요일만 점심
  달랐던 버그 수정).
- 시간 표시 12시간제(오전/오후) 통일, 편집기를 showTimePicker(12h)로 교체.
- 빠른설정 시간을 점심분리로 정비('종일 연속'은 점심 포함 녹음 옵션으로 분리).
- 편집기에서 일부 세션이 저장 시 삭제되던 버그 수정.

**조용한 실패 가시화 / 정리**
- 삼킨 예외 로깅(부팅 이력 저장, 스케줄 로드, StartupTask enable/disable 실패 노출).
- ffmpeg Process.start+kill(좀비 차단). firstWhere orElse 가드.
- 죽은 의존성(permission_handler, flutter_local_notifications) + A26 죽은 진단
  다이얼로그 + 미사용 모델 플래그 제거. 시간 포맷터 통합.

**부팅/트레이 코드는 미변경** → 1.3.19의 부팅-트레이 동작 그대로(재부팅 재검증 불필요).

## 3. 개발 PC에서 변경 확인 방법

Store용 `.msix`는 **미서명(store 모드)**이라 더블클릭/자동설치가 안 됨. 확인은:
- **빠른 확인(설치 불요)**: 새로 빌드된 실행파일 직접 실행 →
  `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.exe`
  → 시간표 빠른설정 적용 시 요일 정상? 시간이 오전/오후로? 시간 칩 탭 시 12h 선택기?
- **설치본 업데이트(자체서명 sideload, 대화형 비번 필요 → 사용자 실행)**:
  `pwsh -File scripts\sideload\build-sideload.ps1` (PFX 비번 입력) →
  `pwsh -File scripts\sideload\install.ps1`

## 4. 다음 작업
- (사용자 확인 후) 브랜치 → **main 머지/푸시**.
- 보류(재부팅 실테스트 필수, 1.3.21+): B2/B4/B5 부팅·트레이 생명주기, AudioService
  god-object 분해, 인코더-폴백 추출, logging_service prune 비동기화.
