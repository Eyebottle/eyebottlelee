import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart'
    show
        APPMODEL_ERROR_NO_PACKAGE,
        ERROR_INSUFFICIENT_BUFFER,
        ERROR_SUCCESS,
        WCHAR;

import '../services/logging_service.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _getCurrentPackageFamilyName = _kernel32.lookupFunction<
    Int32 Function(Pointer<Uint32> length, Pointer<Utf16> familyName),
    int Function(Pointer<Uint32> length,
        Pointer<Utf16> familyName)>('GetCurrentPackageFamilyName');

String? tryGetPackageFamilyName({LoggingService? logging}) {
  if (!Platform.isWindows) return null;

  final log = logging ?? LoggingService();
  final length = calloc<Uint32>();
  try {
    var rc = _getCurrentPackageFamilyName(length, nullptr.cast<Utf16>());

    if (rc == APPMODEL_ERROR_NO_PACKAGE) {
      return null;
    }

    if (rc != ERROR_INSUFFICIENT_BUFFER) {
      log.warning('GetCurrentPackageFamilyName(1) failed: rc=$rc');
      return null;
    }

    final buffer = calloc<WCHAR>(length.value);
    try {
      rc = _getCurrentPackageFamilyName(length, buffer.cast<Utf16>());
      if (rc != ERROR_SUCCESS) {
        log.warning('GetCurrentPackageFamilyName(2) failed: rc=$rc');
        return null;
      }
      final name = buffer.cast<Utf16>().toDartString();
      return name.isEmpty ? null : name;
    } finally {
      calloc.free(buffer);
    }
  } catch (e) {
    log.warning('PackageFamilyName detection failed', error: e);
    return null;
  } finally {
    calloc.free(length);
  }
}
