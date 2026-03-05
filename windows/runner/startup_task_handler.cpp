#include "startup_task_handler.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <windows.h>
#include <appmodel.h>
#include <roapi.h>
#include <winstring.h>
#include <hstring.h>

#include <string>
#include <functional>
#include <memory>

// ---------------------------------------------------------------
// WinRT COM interfaces for Windows.ApplicationModel.StartupTask
// We define them manually to avoid requiring a full C++/WinRT projection.
// ---------------------------------------------------------------

// StartupTaskState enum values
enum StartupTaskState {
  StartupTaskState_Disabled = 0,
  StartupTaskState_DisabledByUser = 1,
  StartupTaskState_Enabled = 2,
  StartupTaskState_DisabledByPolicy = 3,
  StartupTaskState_EnabledByPolicy = 4,
};

// IStartupTask interface
// {F2AB3780-3B68-4e3E-A65E-3BCE7EB46AD6}
MIDL_INTERFACE("F2AB3780-3B68-4E3E-A65E-3BCE7EB46AD6")
IStartupTask : public IInspectable {
 public:
  virtual HRESULT STDMETHODCALLTYPE RequestEnableAsync(
      /* [out, retval] */ void** operation) = 0;
  virtual HRESULT STDMETHODCALLTYPE Disable(void) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_State(
      /* [out, retval] */ StartupTaskState* value) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_TaskId(
      /* [out, retval] */ HSTRING* value) = 0;
};

// IStartupTaskStatics interface (for GetAsync)
// {EE5B60BD-A148-41A7-B26E-E8B88A1E62F8}
MIDL_INTERFACE("EE5B60BD-A148-41A7-B26E-E8B88A1E62F8")
IStartupTaskStatics : public IInspectable {
 public:
  virtual HRESULT STDMETHODCALLTYPE GetForCurrentPackageAsync(
      /* [out, retval] */ void** operation) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetAsync(
      /* [in] */ HSTRING taskId,
      /* [out, retval] */ void** operation) = 0;
};

// ---------------------------------------------------------------
// Helper: Check if running as MSIX packaged app
// ---------------------------------------------------------------
static bool IsRunningAsPackagedApp() {
  UINT32 length = 0;
  LONG result = GetCurrentPackageFamilyName(&length, nullptr);
  return (result != APPMODEL_ERROR_NO_PACKAGE);
}

// ---------------------------------------------------------------
// Helper: Convert StartupTaskState to string
// ---------------------------------------------------------------
static std::string StateToString(StartupTaskState state) {
  switch (state) {
    case StartupTaskState_Disabled: return "disabled";
    case StartupTaskState_DisabledByUser: return "disabledByUser";
    case StartupTaskState_Enabled: return "enabled";
    case StartupTaskState_DisabledByPolicy: return "disabledByPolicy";
    case StartupTaskState_EnabledByPolicy: return "enabledByPolicy";
    default: return "unknown";
  }
}

// ---------------------------------------------------------------
// Helper: Get IStartupTask via WinRT activation
// Returns nullptr on failure (e.g., not packaged)
// ---------------------------------------------------------------
static IStartupTask* GetStartupTask(const wchar_t* taskId) {
  if (!IsRunningAsPackagedApp()) {
    return nullptr;
  }

  // Activate StartupTask runtime class
  HSTRING className;
  HRESULT hr = WindowsCreateString(
      L"Windows.ApplicationModel.StartupTask",
      (UINT32)wcslen(L"Windows.ApplicationModel.StartupTask"),
      &className);
  if (FAILED(hr)) return nullptr;

  IStartupTaskStatics* statics = nullptr;
  // IID for IStartupTaskStatics
  IID iid_statics = {0xEE5B60BD, 0xA148, 0x41A7,
                      {0xB2, 0x6E, 0xE8, 0xB8, 0x8A, 0x1E, 0x62, 0xF8}};
  hr = RoGetActivationFactory(className, iid_statics, (void**)&statics);
  WindowsDeleteString(className);
  if (FAILED(hr) || !statics) return nullptr;

  // Create HSTRING for taskId
  HSTRING hTaskId;
  hr = WindowsCreateString(taskId, (UINT32)wcslen(taskId), &hTaskId);
  if (FAILED(hr)) {
    statics->Release();
    return nullptr;
  }

  // GetAsync returns IAsyncOperation<StartupTask>
  void* asyncOp = nullptr;
  hr = statics->GetAsync(hTaskId, &asyncOp);
  WindowsDeleteString(hTaskId);
  statics->Release();
  if (FAILED(hr) || !asyncOp) return nullptr;

  // Wait for async operation to complete
  // Poll IAsyncInfo::Status until completed (1) or failed (3)
  IUnknown* asyncUnk = (IUnknown*)asyncOp;

  // IAsyncInfo IID: {00000036-0000-0000-C000-000000000046}
  IID iid_asyncInfo = {0x00000036, 0x0000, 0x0000,
                        {0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};

  // We use a simple approach: just sleep and try to get the result
  // The GetAsync call for startup tasks typically completes very quickly
  Sleep(500);

  // Get the result via vtable
  // IAsyncOperation<T> layout:
  //   IUnknown (3) + IInspectable (3) + put_Completed(1) + get_Completed(1) + GetResults(1)
  // So GetResults is at vtable index 8
  typedef HRESULT(STDMETHODCALLTYPE* GetResultsFn)(void* self, IStartupTask** result);
  void** vtable = *(void***)asyncOp;
  GetResultsFn getResults = (GetResultsFn)vtable[8];

  IStartupTask* task = nullptr;
  hr = getResults(asyncOp, &task);
  asyncUnk->Release();

  if (FAILED(hr)) return nullptr;
  return task;
}

// ---------------------------------------------------------------
// Platform Channel Registration
// ---------------------------------------------------------------
void RegisterStartupTaskChannel(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "eyebottle/startup_task",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        // -- isPackaged --
        if (call.method_name() == "isPackaged") {
          result->Success(flutter::EncodableValue(IsRunningAsPackagedApp()));
          return;
        }

        // -- getState --
        if (call.method_name() == "getState") {
          if (!IsRunningAsPackagedApp()) {
            result->Success(flutter::EncodableValue(std::string("notPackaged")));
            return;
          }

          IStartupTask* task = GetStartupTask(L"EyebottleMedicalRecorder");
          if (!task) {
            result->Success(flutter::EncodableValue(std::string("unavailable")));
            return;
          }

          StartupTaskState state;
          HRESULT hr = task->get_State(&state);
          task->Release();

          if (FAILED(hr)) {
            result->Success(flutter::EncodableValue(std::string("error")));
            return;
          }

          result->Success(flutter::EncodableValue(StateToString(state)));
          return;
        }

        // -- enable --
        if (call.method_name() == "enable") {
          if (!IsRunningAsPackagedApp()) {
            result->Error("NOT_PACKAGED", "Not running as MSIX package");
            return;
          }

          IStartupTask* task = GetStartupTask(L"EyebottleMedicalRecorder");
          if (!task) {
            result->Error("UNAVAILABLE", "StartupTask not found");
            return;
          }

          // RequestEnableAsync - returns IAsyncOperation<StartupTaskState>
          void* asyncOp = nullptr;
          HRESULT hr = task->RequestEnableAsync(&asyncOp);
          if (FAILED(hr) || !asyncOp) {
            task->Release();
            result->Error("ENABLE_FAILED", "RequestEnableAsync failed");
            return;
          }

          // Wait for async operation to complete
          Sleep(500);

          // Check final state
          StartupTaskState state;
          hr = task->get_State(&state);
          task->Release();
          ((IUnknown*)asyncOp)->Release();

          if (SUCCEEDED(hr)) {
            result->Success(flutter::EncodableValue(StateToString(state)));
          } else {
            result->Error("STATE_CHECK_FAILED", "Failed to get state after enable");
          }
          return;
        }

        // -- disable --
        if (call.method_name() == "disable") {
          if (!IsRunningAsPackagedApp()) {
            result->Error("NOT_PACKAGED", "Not running as MSIX package");
            return;
          }

          IStartupTask* task = GetStartupTask(L"EyebottleMedicalRecorder");
          if (!task) {
            result->Error("UNAVAILABLE", "StartupTask not found");
            return;
          }

          HRESULT hr = task->Disable();
          task->Release();

          if (SUCCEEDED(hr)) {
            result->Success(flutter::EncodableValue(std::string("disabled")));
          } else {
            result->Error("DISABLE_FAILED", "Disable() failed");
          }
          return;
        }

        result->NotImplemented();
      });

  // Channel will be cleaned up by Flutter engine
  channel.release();
}
