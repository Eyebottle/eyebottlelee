#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Command line arguments (including --autostart when the OS delivers it) are
  // passed to Dart, where they are used only as a hint (see below).
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"medical_recorder", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // v1.3.18: Do NOT Show() the window natively. Visibility is controlled
  // entirely by Dart (main.dart) via windowManager.waitUntilReadyToShow():
  //   - background start (boot + "start minimized") -> stays hidden (tray only)
  //   - otherwise                                    -> Dart calls show()+focus()
  //
  // Why: MSIX StartupTask's uap10:Parameters("--autostart") is NOT reliably
  // delivered as argv on some Windows 10 setups, so the native layer cannot
  // know whether this is a boot launch. Making Dart the single source of truth
  // (it also uses a system-uptime heuristic) removes the previous
  // native-Show() vs Dart-hide() race entirely. The window is created hidden
  // and FlutterWindow::OnCreate already calls ForceRedraw() to render the first
  // frame without showing it.

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
