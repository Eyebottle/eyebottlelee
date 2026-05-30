import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart'
    show
        CoInitializeEx,
        CoUninitialize,
        COINIT_APARTMENTTHREADED,
        GetLastError,
        S_FALSE,
        S_OK,
        SHELLEXECUTEINFO,
        SW_SHOWMAXIMIZED,
        SW_SHOWMINNOACTIVE,
        SW_SHOWNORMAL,
        ShellExecuteEx;

import '../models/launch_program.dart' show WindowState;
import '../services/logging_service.dart';

// SEE_MASK_* 플래그 (win32 5.14 패키지가 상수로 노출하지 않아 직접 정의).
// 값은 Win32 SDK(ShellAPI.h)에서 ABI-고정된 상수이므로 안전하게 하드코딩한다.
const int _seeMaskNoAsync = 0x00000100; // 셸 처리가 끝날 때까지 동기 대기
const int _seeMaskFlagNoUi = 0x00000400; // 에러 대화상자 억제(우리가 직접 로깅)

/// [shellExecuteProgram]의 실행 결과.
class ShellExecuteResult {
  const ShellExecuteResult(this.success, {this.errorCode, this.hInstApp});

  final bool success;

  /// 실패 시 GetLastError 값(또는 음수 내부 코드: -1=비Windows, -2=예외).
  final int? errorCode;

  /// ShellExecuteEx의 hInstApp(레거시 진단용, 성공 시 32 초과).
  final int? hInstApp;
}

/// [WindowState]를 ShellExecuteEx의 nShow 값으로 변환.
int _showCmdFor(WindowState state) {
  switch (state) {
    case WindowState.minimized:
      // 포커스를 빼앗지 않고 최소화 — 자동 실행 시 다른 작업을 방해하지 않음.
      return SW_SHOWMINNOACTIVE;
    case WindowState.maximized:
      return SW_SHOWMAXIMIZED;
    case WindowState.normal:
      return SW_SHOWNORMAL;
  }
}

/// 단일 인수를 Windows 명령줄 규칙에 맞게 따옴표 처리한다.
///
/// 공백/탭/따옴표가 포함된 인수만 큰따옴표로 감싸고, CommandLineToArgvW
/// 규칙대로 백슬래시와 따옴표를 이스케이프한다. (경로에 공백이 있는 인수가
/// 잘리던 기존 문제를 방지)
String _quoteArgument(String arg) {
  if (arg.isNotEmpty && !arg.contains(RegExp(r'[ \t"]'))) {
    return arg;
  }

  final buffer = StringBuffer('"');
  var backslashes = 0;
  for (var i = 0; i < arg.length; i++) {
    final ch = arg[i];
    if (ch == '\\') {
      backslashes++;
      continue;
    }
    if (ch == '"') {
      // 닫는 따옴표 앞의 백슬래시들을 2배로 + 따옴표 이스케이프
      buffer.write('\\' * (backslashes * 2 + 1));
      buffer.write('"');
      backslashes = 0;
      continue;
    }
    if (backslashes > 0) {
      buffer.write('\\' * backslashes);
      backslashes = 0;
    }
    buffer.write(ch);
  }
  // 종료 따옴표 앞의 백슬래시들도 2배로
  buffer.write('\\' * (backslashes * 2));
  buffer.write('"');
  return buffer.toString();
}

String _joinArguments(List<String> args) =>
    args.where((a) => a.isNotEmpty).map(_quoteArgument).join(' ');

/// Windows 셸(ShellExecuteEx)을 통해 프로그램·문서·바로가기(.lnk)·URL을 실행한다.
///
/// **왜 Process.start(cmd /c start) 대신 ShellExecuteEx인가:**
/// - `.lnk` 바로가기를 셸이 직접 해석해 정확한 대상/인수/작업폴더로 실행한다.
///   (CreateProcess 기반 Process.start는 .lnk를 실행할 수 없어 cmd로 우회해야 했고,
///    따옴표 처리·콘솔 창 깜빡임·MSIX 컨테이너 문제가 있었다.)
/// - 창 상태([WindowState])를 nShow로 반영한다. (기존 Process.start 경로에서는
///   windowState가 무시되는 죽은 설정이었다.)
/// - full-trust MSIX 앱에서 자식 프로세스를 셸(데스크톱) 컨텍스트로 띄워,
///   패키지 컨테이너에 갇히지 않는다.
///
/// ShellExecuteEx는 COM 셸 핸들러에 위임하므로, 호출 스레드(Dart UI 아이솔레이트)
/// 에서 COM 아파트먼트를 초기화한 뒤 호출한다.
ShellExecuteResult shellExecuteProgram({
  required String path,
  List<String> arguments = const [],
  String? workingDirectory,
  WindowState windowState = WindowState.normal,
  LoggingService? logging,
}) {
  if (!Platform.isWindows) {
    return const ShellExecuteResult(false, errorCode: -1);
  }

  final log = logging ?? LoggingService();

  // 호출 스레드에서 COM 초기화. 이미 같은 모드로 초기화돼 있으면 S_FALSE,
  // 다른 모드면 RPC_E_CHANGED_MODE(음수) — 이 경우 우리가 Uninitialize하면 안 된다.
  final coRc = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  final didInitCom = coRc == S_OK || coRc == S_FALSE;

  final info = calloc<SHELLEXECUTEINFO>();
  final pathPtr = path.toNativeUtf16(allocator: calloc);
  final argsStr = _joinArguments(arguments);
  final argsPtr =
      argsStr.isEmpty ? nullptr : argsStr.toNativeUtf16(allocator: calloc);
  final hasWorkingDir =
      workingDirectory != null && workingDirectory.isNotEmpty;
  final dirPtr = hasWorkingDir
      ? workingDirectory!.toNativeUtf16(allocator: calloc)
      : nullptr;

  try {
    info.ref
      ..cbSize = sizeOf<SHELLEXECUTEINFO>()
      ..fMask = _seeMaskNoAsync | _seeMaskFlagNoUi
      ..hwnd = 0
      ..lpVerb = nullptr // 기본 동작(더블클릭과 동일): 셸이 .lnk/문서/exe를 알맞게 처리
      ..lpFile = pathPtr
      ..lpParameters = argsPtr
      ..lpDirectory = dirPtr
      ..nShow = _showCmdFor(windowState);

    final ok = ShellExecuteEx(info) != 0;
    if (ok) {
      return ShellExecuteResult(true, hInstApp: info.ref.hInstApp);
    }

    final err = GetLastError();
    log.error(
      'ShellExecuteEx 실패: path=$path, GetLastError=$err, '
      'hInstApp=${info.ref.hInstApp}',
    );
    return ShellExecuteResult(false, errorCode: err, hInstApp: info.ref.hInstApp);
  } catch (e, st) {
    log.error('ShellExecuteEx 예외 발생: $path', error: e, stackTrace: st);
    return const ShellExecuteResult(false, errorCode: -2);
  } finally {
    calloc.free(info);
    calloc.free(pathPtr);
    if (argsPtr.address != 0) calloc.free(argsPtr);
    if (dirPtr.address != 0) calloc.free(dirPtr);
    if (didInitCom) CoUninitialize();
  }
}
