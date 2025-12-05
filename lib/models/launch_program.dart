import 'dart:io';

/// 프로그램 창 상태 열거형
enum WindowState { normal, minimized, maximized }

/// 자동 실행할 프로그램 정보를 담는 모델
class LaunchProgram {
  const LaunchProgram({
    required this.id,
    required this.name,
    required this.path,
    this.arguments = const [],
    this.workingDirectory,
    this.delaySeconds = 10,
    this.windowState = WindowState.normal,
    this.enabled = true,
    required this.order,
    this.lastExecuted,
    this.requiresConfirmation = false,
  });

  final String id;
  final String name;
  final String path;
  final List<String> arguments;
  final String? workingDirectory;
  final int delaySeconds;
  final WindowState windowState;
  final bool enabled;
  final int order;
  final DateTime? lastExecuted;
  final bool requiresConfirmation;

  /// JSON에서 생성
  factory LaunchProgram.fromJson(Map<String, dynamic> json) {
    return LaunchProgram(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      arguments: List<String>.from(json['arguments'] ?? []),
      workingDirectory: json['workingDirectory'] as String?,
      delaySeconds: json['delaySeconds'] as int? ?? 10,
      windowState: _parseWindowState(json['windowState'] as String?),
      enabled: json['enabled'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      lastExecuted: json['lastExecuted'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastExecuted'] as int)
          : null,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'delaySeconds': delaySeconds,
      'windowState': windowState.name,
      'enabled': enabled,
      'order': order,
      'lastExecuted': lastExecuted?.millisecondsSinceEpoch,
      'requiresConfirmation': requiresConfirmation,
    };
  }

  /// 프로그램 파일이 존재하는지 확인
  bool get isValid {
    try {
      final file = File(path);
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// 바로가기(.lnk) 파일인지 확인
  bool get isShortcut {
    return path.toLowerCase().endsWith('.lnk');
  }

  /// 프로그램 이름을 경로에서 자동 추출
  static String extractProgramName(String filePath) {
    try {
      final file = File(filePath);
      String fileName = file.uri.pathSegments.last;

      // 확장자 제거
      if (fileName.contains('.')) {
        fileName = fileName.substring(0, fileName.lastIndexOf('.'));
      }

      // 첫 글자 대문자로 변환
      if (fileName.isNotEmpty) {
        fileName = fileName[0].toUpperCase() + fileName.substring(1);
      }

      return fileName;
    } catch (e) {
      return 'Unknown Program';
    }
  }

  /// 배치 파일(.bat, .cmd)인지 확인
  bool get isBatchFile {
    final extension = path.toLowerCase();
    return extension.endsWith('.bat') || extension.endsWith('.cmd');
  }

  /// 실행 파일인지 확인 (.exe, .bat, .cmd, .lnk)
  bool get isExecutable {
    final extension = path.toLowerCase();
    return extension.endsWith('.exe') ||
        extension.endsWith('.bat') ||
        extension.endsWith('.cmd') ||
        extension.endsWith('.lnk');
  }

  /// 프로그램 정보 복사 (일부 속성 변경)
  ///
  /// nullable 필드(workingDirectory, lastExecuted)를 명시적으로 null로
  /// 설정하려면 clearWorkingDirectory, clearLastExecuted를 true로 설정하세요.
  LaunchProgram copyWith({
    String? id,
    String? name,
    String? path,
    List<String>? arguments,
    String? workingDirectory,
    bool clearWorkingDirectory = false,
    int? delaySeconds,
    WindowState? windowState,
    bool? enabled,
    int? order,
    DateTime? lastExecuted,
    bool clearLastExecuted = false,
    bool? requiresConfirmation,
  }) {
    return LaunchProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      arguments: arguments ?? this.arguments,
      workingDirectory:
          clearWorkingDirectory ? null : (workingDirectory ?? this.workingDirectory),
      delaySeconds: delaySeconds ?? this.delaySeconds,
      windowState: windowState ?? this.windowState,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      lastExecuted:
          clearLastExecuted ? null : (lastExecuted ?? this.lastExecuted),
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
    );
  }

  /// 고유 ID 생성 (파일 경로 기반)
  static String generateId(String filePath) {
    return filePath.hashCode.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LaunchProgram && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LaunchProgram(id: $id, name: $name, path: $path, order: $order, enabled: $enabled)';
  }

  /// WindowState 문자열을 enum으로 변환
  static WindowState _parseWindowState(String? stateString) {
    if (stateString == null) return WindowState.normal;

    try {
      return WindowState.values.byName(stateString);
    } catch (e) {
      return WindowState.normal;
    }
  }
}
