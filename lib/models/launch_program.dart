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
    );
  }

  static int _idCounter = 0;

  /// 항상 고유한 ID를 생성한다.
  ///
  /// 이전에는 `filePath.hashCode`를 사용해, 같은 프로그램을 두 번 등록하면
  /// 동일한 id가 만들어져 편집/삭제/토글이 엉뚱한 항목에 적용되는 버그가 있었다
  /// (서로 다른 경로 간 해시 충돌 위험도 있었다). 이제 경로와 무관하게 고유
  /// 값을 생성한다. 파라미터는 기존 호출부 호환을 위해 남겨두되 사용하지 않는다.
  static String generateId([String? _]) {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final n = _idCounter++;
    return '${micros}_$n';
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
