import 'dart:ffi';
import 'dart:io' show Platform;

// kernel32!GetTickCount64 — 시스템 부팅 후 경과한 밀리초.
// win32 5.14 패키지가 이 함수를 노출하지 않아 직접 lookup한다.
typedef _GetTickCount64Native = Uint64 Function();
typedef _GetTickCount64Dart = int Function();

_GetTickCount64Dart? _getTickCount64;
bool _resolved = false;

/// 시스템 부팅 후 경과 시간(Windows 전용). 실패하거나 비-Windows면 null.
///
/// **용도:** 부팅/로그인 직후 StartupTask로 실행됐는지 추정하는 보조 신호.
/// 일부 Windows 10 환경에서 MSIX StartupTask의 `uap10:Parameters("--autostart")`가
/// 실제 명령줄 인자로 전달되지 않아(`hasAutostart`가 항상 false), 부팅 자동시작을
/// 인자만으로는 구분할 수 없다. 이때 "부팅 후 경과 시간이 짧음"을 추가 단서로 쓴다.
Duration? systemUptime() {
  if (!Platform.isWindows) return null;
  try {
    if (!_resolved) {
      _resolved = true;
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      _getTickCount64 = kernel32.lookupFunction<_GetTickCount64Native,
          _GetTickCount64Dart>('GetTickCount64');
    }
    final fn = _getTickCount64;
    if (fn == null) return null;
    return Duration(milliseconds: fn());
  } catch (_) {
    return null;
  }
}
