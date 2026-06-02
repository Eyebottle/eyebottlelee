# 핸드오프 — v1.3.20 진료실 "서브 PC" 실행 즉시 크래시 진단 (2026-06-02)

## 0. 한 줄 결론

**v1.3.20 앱·패키지는 정상.** 진료실 **서브 PC(안과 세극등 카메라 영상장비 PC)** 에서만
실행 즉시 크래시 = **Windows Media Foundation(`MFPlat.dll`) 네이티브 액세스 위반(0xc0000005)**.
앱이 **시작하자마자 MF를 건드리는데**(진료시간 자동녹음 + 자동 마이크점검), 그 PC의 MF 환경이
취약(영상장비 PC)해서 터진다. **실사용 녹음 PC들은 영향 없음(안전).**

> 결정: **서브 PC는 녹음 용도가 아님** → 그 PC만 정상화하면 됨. 재업로드로 "고쳐지는" 종류 아님
> (코드 회귀가 아니라 그 PC의 MF 환경 문제). 단, 재발 방지용 `.21` 코드 하드닝은 별도 권장.

---

## 1. 증상

- 서브 PC를 v1.3.20으로 업데이트(MS Store) 후 **앱이 아예 안 켜짐.**
- 재부팅·앱 **초기화(Reset)** 해도 동일.
- Store에 **"열기" 버튼은 있음** → 설치는 되어 있음(앱이 사라진 게 아님). 열어도 창이 안 뜸.
- **".19에서는 켜졌는데 .20에서 안 됨"** (같은 서브 PC).

## 2. 확정 증거 — 이벤트 뷰어 Event 1000 (Application Error)

```
오류 응용 프로그램: medical_recorder.exe, 버전: 1.3.20.31
오류 모듈      : MFPlat.DLL, 버전: 10.0.26100.3912   ← Windows Media Foundation 코어
예외 코드      : 0xc0000005 (액세스 위반)
시각          : 2026-06-02 오전 11:50:11 (진료시간 09–13시 내)
컴퓨터        : DESKTOP-2HHM52J
패키지        : DCD952CB.367669DCDC1D3_1.3.20.0_x64__tmhr7zc3de56j
모듈 경로      : C:\WINDOWS\SYSTEM32\MFPlat.DLL
```

## 3. 근본 원인

앱이 **시작 루틴(`_initializeServices`)에서 Media Foundation을 건드린다:**

| 위치 | 코드 | MF 진입 경로 |
|---|---|---|
| `lib/ui/screens/main_screen.dart:333` | `await _syncRecordingWithSchedule(initial: true)` | 진료시간이면 즉시 `_startRecording()` → `record_windows` → MF |
| `lib/ui/screens/main_screen.dart:337` | `await _runMicDiagnostic(initial: true)` | `mic_diagnostics_service.runDiagnostic()` → `hasPermission`/`listInputDevices`/녹음 → MF |

- 크래시 시각 11:50은 진료시간 → **스케줄 자동녹음 `_startRecording()`** 이 MF를 가장 먼저 친
  것으로 추정(진단보다 line 333이 먼저 실행).
- **`MFPlat.dll`의 0xc0000005는 네이티브 크래시** → **Dart `try/catch`·`runZonedGuarded`로
  못 잡음.** (시작 진단은 line 336–341 try, runDiagnostic 내부 try가 있지만 전부 무용) →
  프로세스 통째로 종료 → 창도 못 띄움 → "안 켜짐". 앱 데이터가 아니라 OS 구성요소 문제라
  **Reset도 무효.**

## 4. 왜 "서브 PC만"? (= 보편 .20 버그 아님)

- 이벤트뷰어 캡처 **배경에 안과 검사/촬영 SW(Ocular surface · Exam Report · Image Process ·
  Camera · Flash)** 가 떠 있음 → 서브 PC는 **세극등 카메라 영상장비 PC.**
- 이런 의료영상 PC는 **카메라 캡처가 MF/DirectShow를 쓰고 장비 SDK가 자체 코덱/MF 필터를
  설치** → MF 환경이 일반 PC와 달라 취약.
- **개발 PC(일반 PC, 마이크 연결 없음)에서 비패키지 exe는 안 죽음** → 코드가 보편적으로
  깨진 게 아님(환경 특정).
- ".19 OK / .20 크래시"는 **`.20`이 그 시점 자동녹음을 실제로 발동시켜 MF 캡처 경로를 처음
  친 탓**으로 추정. (대조 결과: `record` 패키지 버전·`audio_service` MF 호출부는 .19=.20 동일.
  바뀐 건 스케줄 기본값/제어흐름이지 MF 호출 자체가 아님.)

## 5. 해결 방안

### A. 서브 PC (녹음 불필요 — 확정)

- **A1. 앱이 그 PC에서 불필요하면 → 제거.** (설정 → 앱 → 아이보틀 진료 녹음 → 제거) — 끝.
- **A2. 자동실행 매니저(부팅 시 장비 SW 자동실행)용으로 쓰면 → `.21` 하드닝(아래 B) 후
  그 PC에서 "자동녹음/스케줄 OFF".** (앱은 열리고 MF는 안 건드림 → 다시 안 죽음)
- **A3. (그 PC에서 실제 녹음까지 원할 때만) MF 복구:**
  관리자 PowerShell → `DISM /Online /Cleanup-Image /RestoreHealth` → `sfc /scannow` →
  Windows 업데이트 최신 → 재부팅. + 세극등 카메라 드라이버/SW와 MF 충돌 점검.

### B. `.21` 코드 하드닝 (선택 · 전 PC 재발 방지)

목표: **어떤 PC든 앱은 무조건 "열리게"** 하고, 문제 PC에서 설정을 끌 기회를 준다.
(네이티브 MF 크래시는 못 잡으므로 — **MF를 "안 부르게" 막는 게 유일한 길**)

- `main_screen.dart:337` **시작 자동 마이크점검 제거** — `_runMicDiagnostic(initial: true)`를
  시작에서 빼고, 저장된 마지막 결과(line 302 `loadMicDiagnosticResult`)만 표시. 점검은
  트레이/버튼 등 **사용자 명시 동작에서만.** (가치 낮고 위험만 큼)
- `main_screen.dart:333` **스케줄 자동녹음을 첫 프레임 이후로 미루고 가드** — 창이 확실히
  뜬 뒤 실행, 그리고 "이 PC에서 자동녹음 안 함" 류 설정을 존중. (창이 먼저 떠야 그 PC에서
  토글을 끌 수 있음)
- 버전 `1.3.21.0`(build 32)으로 상향 → 재빌드 → MS Store 재제출.
- **한계 명시**: 위로 앱은 열리지만, 그 PC가 실제로 녹음하려면 결국 A3(그 PC MF 정상화)이
  필요. (B는 "앱이 안 죽게", A3는 "녹음이 되게")

## 6. 실사용(녹음) PC 영향

- **없음(안전).** MF 정상인 일반 PC는 .19가 잘 돌던 그대로 .20도 정상. 서브 PC는 영상장비라
  MF가 특수했던 케이스.

## 7. 미해결 / 다음 단계

- [ ] (원인 최종 확정용, 선택) 서브 PC에 **비패키지 exe**를 USB로 옮겨 실행
      (`build\windows\x64\runner\Release\` 폴더 통째로) →
      잘 뜨면 **MSIX/권한 계층 문제**(코드·패키지로 해결, 재업로드 가능),
      똑같이 죽으면 **그 PC MF 자체 문제**(A3 필수).
- [ ] 서브 PC 처리 결정: A1(제거) vs A2(.21 + 자동녹음 OFF).
- [ ] (B 선택 시) `.21` 하드닝 구현 → 재빌드 → 재제출.

---

## 부록 A — 세극등 카메라 USB 연결 자주 끊김 (별개 이슈, 같은 PC)

**증상**: 세극등 카메라(USB) 연결이 자주 끊김. USB 포트 바꾸고 재시작하면 돌아오기도 하고,
**Windows를 예전 것으로 되돌리면 한동안 잘 버팀.**

**추정 원인 (단서 분석)**:
1. **"윈도우 롤백하면 잘 버틴다" = Windows Update가 잘 되던 USB/카메라 드라이버를 바꿔치기.**
   누적 업데이트마다 호환 깨짐 → 롤백 시 복귀 → 다음 업데이트 때 재발. (가장 유력)
2. **USB 선택적 절전(Selective Suspend)** — 윈도우가 절전하려 포트 전원 내림 → "끊김".
3. **USB2 카메라를 USB3(xHCI) 포트/허브에 연결 시 궁합 문제** (의료 카메라 흔한 증상).

**해결 순서 (효과 큰 순)**:
1. **USB 절전 끄기**: 전원옵션 → 고성능 → 고급 → USB → 선택적 절전 "사용 안 함".
   장치관리자 → 모든 "USB Root Hub" + 카메라 → 전원관리 탭 → "전원 절약 위해 끌 수 있음"
   체크 해제.
2. **Windows Update가 드라이버 못 바꾸게 동결**: 잘 되던 드라이버 버전 고정 +
   드라이버 자동업데이트 차단(`ExcludeWUDriversInQualityUpdate=1` 또는 종량제 연결) +
   기능 업데이트 일시중지/지연.
3. **물리 연결**: 메인보드 **후면 포트 직결**(전면·무전원 허브 X), USB2면 후면 USB2 포트나
   전원 공급 허브, 짧은 정품 케이블.
4. **벤더 드라이버/SDK**: 되던 버전 롤백 후 고정. **⚠️ 의료기기 → 제조사 권장 구성 확인 필수.**

**진단 스크립트(서브 PC PowerShell)** — 결과를 보면 원인 좁힘 가능:
```powershell
Get-PnpDevice | ? {$_.Class -in 'Camera','Image','Media','USB'} | Select Status,Class,FriendlyName,InstanceId | Format-Table -Auto
Get-WinEvent -FilterHashtable @{LogName='System';StartTime=(Get-Date).AddDays(-2)} -EA SilentlyContinue | ? {$_.Message -match 'USB|Kernel-PnP|장치'} | Select -First 15 TimeCreated,Id,ProviderName | Format-Table -Auto
Get-HotFix | Sort InstalledOn -Desc | Select -First 8 HotFixID,InstalledOn
```

> 참고: 이 카메라 불안정(MF/USB 드라이버)이 **본문 MFPlat 크래시의 토양**일 수 있음 —
> 카메라/USB 안정화가 MF 크래시 위험도 낮춘다.

---

## 부록 B — (별개 잠재 위험) 사이드로드 서명 함정

이번 건과 **무관**하지만 조사 중 발견한 실제 위험 — 기록만 남김:

- `pubspec.yaml`의 `msix_config: store: true` → `dart run msix:create`(=`build-msix.ps1`)는
  **미서명(unsigned) Store용 패키지**를 만든다. (OneDrive 배포본도 미서명)
- **미서명 MSIX는 사이드로드(`Add-AppxPackage`) 설치 불가.**
- `scripts/sideload/install.ps1`은 **기존 앱을 먼저 제거한 뒤** 설치 → 미서명/인증서미신뢰로
  설치 실패 시 **앱이 통째로 사라짐**(복구 어려움).
- 올바른 사이드로드 경로: `scripts/sideload/build-sideload.ps1`(store→false 임시치환 + PFX 서명)
  → `install.ps1`. **현재 PFX가 repo/머신에 안 보임** → 사이드로드 시 인증서 재생성 필요할 수
  있음.
- 권장 개선: `install.ps1`을 "새 패키지가 서명·설치 가능한지 **먼저 검증한 뒤** 기존 앱 제거"
  순서로 고치고, 미서명 패키지 배포 차단.

---

**작성**: 2026-06-02 / 조사: 이벤트뷰어 Event 1000 + 코드/깃 대조 + 개발 PC 대조 테스트
**상태**: 진단 완료, 서브 PC 처리(A1/A2) 및 `.21` 하드닝(B) 실행 대기
