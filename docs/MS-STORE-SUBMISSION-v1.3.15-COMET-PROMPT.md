# MS Store v1.3.15 코멧 프롬프트

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
6. 기존 패키지(v1.3.14 이하)가 있으면 X 버튼으로 삭제해.
7. "찾아보기" 또는 "Browse"를 클릭하고 이 파일을 업로드해: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 통과(녹색 체크마크)되는지 확인해. 버전이 1.3.15.0으로 표시되어야 해.
9. "스토어 목록" 탭으로 이동해.
10. "이 릴리스의 새로운 기능" 또는 "What's new in this release" 입력란에 아래 내용을 입력해:

v1.3.15 업데이트

[버그 수정]
• 자동 실행 설정 OFF 시 앱이 실행되지 않는 버그 수정
• 앱 안정성 향상

11. "제출 옵션" 또는 "Submission options" 탭으로 이동해.
12. "인증 노트" 또는 "Notes for certification" 입력란에 아래 내용을 입력해:

v1.3.15 - Fix: App exits immediately when "Launch at Startup" is OFF

ROOT CAUSE:
The MSIX manifest uses uap10:Parameters="--autostart" on the Application
element. This means ALL launches (including manual Start menu clicks)
receive the --autostart argument, not just the StartupTask.

In v1.3.14, the code had: if (hasAutostart && !launchAtStartup) exit(0)
This killed the app on EVERY manual launch when the user disabled startup.

FIX:
- Removed the exit(0) guard entirely
- Changed tray-hide condition to require ALL three:
  hasAutostart && launchAtStartup && startMinimizedOnBoot
- App now always launches successfully regardless of settings

TEST CASES:
1. Set "Launch at Startup" to OFF > Close app > Reopen > App works
2. Set "Launch at Startup" to ON + Background ON > Reboot > Tray mode
3. Set "Launch at Startup" to ON + Background OFF > Reboot > Window visible
4. Manual launch from Start menu > Window always appears

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

13. 모든 섹션에 체크마크가 있는지 확인해.
14. "제출" 또는 "Submit" 버튼을 클릭해.
15. 확인 다이얼로그가 나오면 "확인"을 클릭해.
16. "제출 진행 중" 상태가 되면 완료야. 제출 ID를 알려줘.
```

---

**참고:** "long file" 에러가 발생하면 10번의 릴리스 노트를 아래로 교체:

```
v1.3.15: 자동 실행 OFF 시 앱 종료 버그 수정
```
