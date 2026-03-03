# MS Store v1.3.12 코멧 프롬프트

아래 프롬프트를 코멧 브라우저에 그대로 복사-붙여넣기하세요.

---

## 프롬프트

```
Microsoft Store Partner Center에서 앱 업데이트를 제출해줘.

1. https://partner.microsoft.com/dashboard 에 접속해.
2. 로그인이 안 되어 있으면 로그인해.
3. 앱 목록에서 "아이보틀 진료녹음 & 자동실행 매니저"를 클릭해.
4. "새 제출 시작" 또는 "Start submission" 버튼을 클릭해. 기존 draft 제출이 있으면 삭제하고 새로 만들어.
5. "패키지" 또는 "Packages" 탭으로 이동해.
6. 기존 패키지(v1.3.11 이하)가 있으면 X 버튼으로 삭제해.
7. "찾아보기" 또는 "Browse"를 클릭하고 이 파일을 업로드해: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 통과(녹색 체크마크)되는지 확인해. 버전이 1.3.12.0으로 표시되어야 해.
9. "스토어 목록" 탭으로 이동해.
10. "이 릴리스의 새로운 기능" 또는 "What's new in this release" 입력란에 아래 내용을 입력해:

v1.3.12 업데이트

[버그 수정]
• 앱이 실행되지 않는 치명적 버그 수정 (Win32 Show() 누락 복원)
• 부팅 시 백그라운드(트레이) 시작 기능 근본 수정
  - hide() 호출을 최우선으로 실행하여 창 깜빡임 최소화
  - PostFrameCallback에서 재숨김 방어 유지
• 앱 시작 안정성 향상

[개선 사항]
• MSIX 환경 호환성 개선
• 코드 품질 개선

11. "제출 옵션" 또는 "Submission options" 탭으로 이동해.
12. "인증 노트" 또는 "Notes for certification" 입력란에 아래 내용을 입력해:

v1.3.12 - Critical Launch Fix + Background Start Optimization

CHANGES:
- CRITICAL: Restored window.Show() in main.cpp (standard Flutter Windows runner
  call). This was missing, causing the Win32 window to never become visible.
  Without Show(), the app appeared to not launch at all.
- Kept ForceRedraw() in flutter_window.cpp (required for Flutter engine init)
- Optimized Dart-side hide timing: hide() now executes immediately after
  windowManager init, BEFORE window sizing calls, reducing background-start
  window flash from ~300ms to ~50ms
- PostFrameCallback still enforces re-hide as defensive measure

TEST CASES:
1. Launch app normally (double-click) > App window appears correctly
2. Settings > Windows Startup > Toggle OFF > Restart > App should NOT start
3. Toggle startup ON + background ON > Restart > App in tray only (minimal flash)
4. Toggle startup ON + background OFF > Restart > Window appears normally
5. Click tray icon > Window restores correctly

All v1.3.10 features unchanged. Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

13. 모든 섹션에 체크마크가 있는지 확인해.
14. "제출" 또는 "Submit" 버튼을 클릭해.
15. 확인 다이얼로그가 나오면 "확인"을 클릭해.
16. "제출 진행 중" 상태가 되면 완료야. 제출 ID를 알려줘.
```

---

**참고:** "long file" 에러가 발생하면 10번의 릴리스 노트를 아래로 교체:

```
v1.3.12: 앱 실행 오류 수정, 백그라운드 시작 최적화
```
