# MS Store v1.3.20 — 브라우저 조작 Claude용 최종 프롬프트

> 크롬을 직접 조작하는 Claude(browser automation)에게 아래 **"프롬프트"** 블록을
> 그대로 복사해 전달하세요. 로그인은 사용자가 직접 하며, Claude는 로그인 화면에서
> 멈추고 기다립니다. 최종 "제출" 직전에도 사용자 확인을 받습니다.
>
> ⚠️ **먼저 빌드부터**: 이 프롬프트는 v1.3.20 `.msix`가 빌드되어 있어야 동작합니다.
> 같은 Windows PC에서 아래를 먼저 실행하세요(`flutter pub get`·`flutter analyze`가
> 반드시 선행):
>
> ```powershell
> bash scripts/sync_wsl_to_windows.sh
> cd C:\ws-workspace\eyebottlelee
> flutter pub get
> flutter analyze          # error 0 확인 후 진행 (info 3건은 무관)
> flutter build windows --release
> dart run msix:create
> powershell -NoProfile -ExecutionPolicy Bypass -File scripts\preflight\verify-msix.ps1
> ```

---

## 프롬프트 (이 아래 전체를 복사)

```
너는 지금 Chrome 브라우저를 직접 조작해서 Microsoft Store(Partner Center)에 앱
업데이트를 제출하는 작업을 맡았다. 아래 절차를 한 단계씩, 각 단계의 결과를
화면에서 확인하며 진행해라. 추측으로 넘어가지 말고, 버튼/입력란을 실제로 찾은
뒤 클릭/입력해라. 한국어로 진행 상황을 보고해라.

[중요 규칙]
1. 로그인: Microsoft 로그인 화면이 나오거나 로그인이 안 되어 있으면, 절대
   직접 로그인 정보를 입력하지 마라. 즉시 멈추고 사용자에게 이렇게 말해라:
   "로그인 화면입니다. 직접 로그인해 주시고, 완료되면 '로그인 완료'라고
   알려주세요." 사용자가 완료를 알릴 때까지 기다린 뒤 다음 단계로 진행해라.
2. 2단계 인증(OTP/Authenticator)도 마찬가지로 사용자에게 맡기고 기다려라.
3. 최종 "제출(Submit)" 버튼은 사용자 확인 없이 누르지 마라(아래 12번 참조).
4. 각 단계에서 예상한 버튼/요소를 못 찾으면, 화면을 캡처해 무엇이 보이는지
   사용자에게 설명하고 어떻게 할지 물어라.

[제출 정보]
- 앱: "아이보틀 진료녹음" (앱 목록에서 "아이보틀"로 검색/식별)
- 새 버전: 1.3.20.0
- 업로드할 파일(이 PC 경로):
  C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
- 직전 버전: 1.3.19 (패키지 탭에서 발견되면 삭제하고 새로 올림)

[절차]
1. https://partner.microsoft.com/dashboard 로 이동해라.
2. 로그인이 안 되어 있으면 위 [중요 규칙] 1번대로 멈추고 사용자를 기다려라.
   로그인이 되어 있으면 다음으로 진행.
3. 앱 목록(또는 "내 앱")에서 "아이보틀"로 시작하는 앱(아이보틀 진료녹음 /
   아이보틀 진료녹음 & 자동실행 매니저)을 찾아 클릭해라. 정확한 이름이
   애매하면 후보를 사용자에게 확인받아라.
4. "새 제출 시작"(Start submission / Update) 버튼을 클릭해라. 이미 진행 중인
   draft 제출이 있으면, 사용자에게 "기존 미완료 제출이 있습니다. 삭제하고 새로
   만들까요, 이어서 할까요?"라고 물어본 뒤 답에 따라 진행해라.
5. "패키지(Packages)" 탭으로 이동해라.
6. 기존 패키지(1.3.19 이하)가 보이면 X/삭제 버튼으로 제거해라.
7. "찾아보기(Browse)"를 눌러 파일 선택 창을 열고, 위 [제출 정보]의 .msix
   경로를 입력/선택해 업로드해라:
   C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 끝날 때까지 기다려라(진행 표시가 사라지고 녹색
   체크/성공 표시가 뜰 때까지). 패키지 버전이 1.3.20.0 으로 표시되는지
   확인해라. 경고/오류가 뜨면 그 내용을 사용자에게 그대로 보고하고 멈춰라.
9. "스토어 목록(Store listings)" → 한국어(ko-kr) 목록으로 이동해라.
   "이 릴리스의 새로운 기능 / What's new in this release" 입력란에 아래를
   그대로 입력해라:

v1.3.20 업데이트

[버그 수정]
• 빠른 시간표 설정에서 요일이 어긋나 적용되던 문제 해결
  (예: '오전·오후 분리'가 금요일을 쉬고 일요일에 근무로 잡히던 문제)
• 녹음 중 문제가 생겨도 화면에 '녹음 중'이 유지되던 문제 수정 — 이제 중단되면 바로 알림
• 시간표 편집 중 일부 진료 시간이 저장할 때 사라지던 문제 수정

[개선]
• 시간표 시간 표시를 오전/오후 12시간제로 통일
• 시간 편집을 표준 시간 선택기(오전/오후)로 변경
• 기본 시간표를 흔한 진료 패턴(평일 오전·오후 + 토요일 반일)으로 정비
• 앱 아이콘 선명도 개선 (큰 화면/타일에서 흐릿하게 보이던 문제 해결)

[안정성]
• 녹음 정지/분할 처리 안정화 (음성 유실·중복 녹음 방지)
• 사용하지 않는 구성요소 정리 및 내부 코드 정돈

   (만약 글자 수 초과/"too long" 오류가 나면 위 내용을 아래 한 줄로 교체해라:
    v1.3.20: 시간표 빠른설정 요일 버그 수정 + 12시간제 통일 + 녹음 안정성 개선)

10. "제출 옵션(Submission options)" 탭으로 이동해라. "인증 노트(Notes for
    certification)" 입력란에 아래 영문을 그대로 입력해라:

v1.3.20 - Schedule fixes (weekday mapping, 12h display, defaults) + recording reliability

SCHEDULE QUICK-PRESET WEEKDAY BUG (main user-facing fix):
The quick-schedule templates were built with a 0=Monday day index while the app's
model/cron use 0=Sunday. As a result a "weekdays" preset (e.g. morning/afternoon
split) was applied to Sun-Thu with Fri/Sat off (i.e. Friday off and Sunday
working). Fixed to 1-5 = Mon-Fri, 6 = Sat, 0 = Sun, with regression tests.

RECORDING RELIABILITY:
- Segment split/stop state machine hardened: if a segment restart fails, the app
  now transitions to a clear stopped/aborted state and notifies the UI instead of
  showing "recording" while audio is dead (prevents silent data loss).
- start/stop/split are serialized via a lock to prevent an orphan recording session
  (UI stopped but microphone still capturing).
- stop cleanup moved to a finally block so a failed stop cannot leave stuck state.

SCHEDULE UI:
- All schedule time displays unified to 12-hour (AM/PM) format.
- Time editing uses the standard time picker (12-hour).
- Default schedule set to a common clinic pattern (Mon-Fri 09:00-13:00 / 14:00-18:00,
  Sat 09:00-13:00, Sun off); fixed an inconsistency where Monday's lunch differed.
- Fixed an editor bug that silently dropped valid sessions on save.

ALSO:
- Previously-swallowed failures are now logged/surfaced (boot-decision history
  write, schedule load, StartupTask enable/disable).
- ffmpeg conversion runs as a tracked process and is killed on cancel/exit
  (no zombie process holding the WAV file).
- Removed dead code/dependencies (permission_handler, flutter_local_notifications,
  an unreachable diagnostics dialog).
- App icon/tile logos regenerated from a 1024px source (msix logo_path) to fix
  upscaling blur on larger tiles.

NOTE: This release does NOT change any boot/tray/window-visibility code, so the
boot-to-tray behavior shipped in 1.3.19 is unchanged.

TEST CASES:
1. Quick schedule "weekdays morning/afternoon split" -> Mon-Fri working, Sun/Sat off
2. Quick schedule "weekdays + Saturday half" -> Sat 09:00-13:00, Sun off
3. Schedule times shown as AM/PM; tapping a time opens a 12-hour picker
4. Start recording, let a segment split occur, then stop -> single clean stop, file saved
5. Recording / scheduling / WAV->m4a conversion work as before
6. Boot-to-tray behavior unchanged from 1.3.19

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

11. 입력한 내용들을 "저장(Save)"해라. (가격/배포 등 다른 탭은 기존 설정을
    그대로 두고 변경하지 마라.)
12. 최종 제출 직전 확인: "제출(Submit)" 버튼을 누르기 전에, 다음을 요약해
    사용자에게 보고하고 "제출할까요?"라고 물어라. 사용자가 명시적으로
    "제출"이라고 답할 때까지 누르지 마라:
    - 업로드된 패키지 버전(1.3.20.0)
    - "새로운 기능" 입력 완료 여부
    - "인증 노트" 입력 완료 여부
    - 검증 경고/오류 유무
13. 사용자가 확인하면 "제출(Submit)"을 눌러라.
14. 제출이 완료되면 제출 ID(Submission ID)와 상태(예: "인증 진행 중")를
    사용자에게 보고해라.

[문제 발생 시]
- 어떤 단계든 예상과 다른 화면이 나오면 멈추고, 현재 화면을 캡처/설명한 뒤
  사용자에게 어떻게 할지 물어라. 임의로 새 항목을 만들거나 기존 설정을
  바꾸지 마라.
```

---

## 사용 메모 (사용자용 — 브라우저 Claude에게 전달하지 않아도 됨)

- 업로드 파일은 **반드시 v1.3.20 빌드본**이어야 합니다. 탐색기에서
  `medical_recorder.msix` 속성 → 자세히 → 제품 버전이 **1.3.20.0**, 빌드 시각이
  오늘인지 확인하세요. (`scripts\preflight\verify-msix.ps1` 가 버전·StartupTask·
  capability·ffmpeg 번들을 자동 점검합니다.)
- **버전 정책**: Store는 동일 버전 재업로드를 막고 revision(4번째 자리)=0을
  강제합니다. 그래서 1.3.19.1이 아니라 build 자리를 올려 **1.3.20.0**으로
  빌드했습니다. 다음에도 1.3.21.0 식으로 올리세요.
- 브라우저 Claude는 같은 Windows PC에서 실행되어야 파일 선택 창에서 위 경로에
  접근할 수 있습니다.
- 이번 릴리스는 **부팅/트레이 코드를 건드리지 않았으므로** 1.3.19의 부팅-트레이
  동작은 그대로입니다(재부팅 재검증 불필요). 핵심 확인은 **시간표 빠른설정/편집기**:
  빠른 스케줄 적용 시 요일이 맞는지, 시간이 오전/오후로 표시되는지, 시간 칩을
  누르면 12시간제 선택기가 뜨는지 보세요.
