#ifndef RUNNER_STARTUP_TASK_HANDLER_H_
#define RUNNER_STARTUP_TASK_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

// Register the "eyebottle/startup_task" MethodChannel on the given engine.
// This provides Dart code with direct access to the WinRT StartupTask API:
//   - getState: Get current StartupTask state
//   - enable:   Request enabling the startup task
//   - disable:  Disable the startup task
//   - isPackaged: Check if running as MSIX package
void RegisterStartupTaskChannel(flutter::FlutterEngine* engine);

#endif  // RUNNER_STARTUP_TASK_HANDLER_H_
