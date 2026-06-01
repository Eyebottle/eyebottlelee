import 'launch_program.dart';

/// 자동 실행 매니저 전체 설정을 관리하는 모델
class LaunchManagerSettings {
  const LaunchManagerSettings({
    this.autoLaunchEnabled = false,
    this.programs = const [],
    this.version = 1,
  });

  final bool autoLaunchEnabled;
  final List<LaunchProgram> programs;
  final int version;

  /// SharedPreferences 키
  static const String keySettings = 'launch_manager_settings';

  /// JSON에서 생성
  factory LaunchManagerSettings.fromJson(Map<String, dynamic> json) {
    return LaunchManagerSettings(
      autoLaunchEnabled: json['autoLaunchEnabled'] as bool? ?? false,
      programs: (json['programs'] as List<dynamic>?)
              ?.map((p) => LaunchProgram.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      version: json['version'] as int? ?? 1,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'autoLaunchEnabled': autoLaunchEnabled,
      'programs': programs.map((p) => p.toJson()).toList(),
      'version': version,
    };
  }

  /// 활성화된 프로그램 목록 (순서대로 정렬)
  List<LaunchProgram> get enabledPrograms {
    return programs.where((p) => p.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// 활성화된 프로그램 개수
  int get enabledProgramCount => programs.where((p) => p.enabled).length;

  /// 프로그램 추가
  LaunchManagerSettings addProgram(LaunchProgram program) {
    final newPrograms = List<LaunchProgram>.from(programs);

    // 새 프로그램의 순서를 마지막으로 설정
    final maxOrder = programs.isEmpty
        ? 0
        : programs.map((p) => p.order).reduce((a, b) => a > b ? a : b);

    final programWithOrder = program.copyWith(order: maxOrder + 1);
    newPrograms.add(programWithOrder);

    return copyWith(programs: newPrograms);
  }

  /// 프로그램 제거
  LaunchManagerSettings removeProgram(String programId) {
    final newPrograms = programs.where((p) => p.id != programId).toList();
    return copyWith(programs: newPrograms);
  }

  /// 프로그램 업데이트
  LaunchManagerSettings updateProgram(LaunchProgram updatedProgram) {
    final newPrograms = programs.map((p) {
      return p.id == updatedProgram.id ? updatedProgram : p;
    }).toList();

    return copyWith(programs: newPrograms);
  }

  /// 프로그램 순서 재정렬
  LaunchManagerSettings reorderPrograms(List<LaunchProgram> reorderedPrograms) {
    // 순서 번호 재할당
    final programsWithNewOrder = reorderedPrograms.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key + 1);
    }).toList();

    return copyWith(programs: programsWithNewOrder);
  }

  /// 설정 복사 (일부 속성 변경)
  LaunchManagerSettings copyWith({
    bool? autoLaunchEnabled,
    List<LaunchProgram>? programs,
    int? version,
  }) {
    return LaunchManagerSettings(
      autoLaunchEnabled: autoLaunchEnabled ?? this.autoLaunchEnabled,
      programs: programs ?? this.programs,
      version: version ?? this.version,
    );
  }

  /// 기본 설정 생성
  factory LaunchManagerSettings.defaultSettings() {
    return const LaunchManagerSettings();
  }

  /// 설정 마이그레이션 (버전 호환성)
  LaunchManagerSettings migrate() {
    if (version < 1) {
      // v0 -> v1 마이그레이션 로직 (현재는 v1이 첫 버전)
      return copyWith(version: 1);
    }

    // 추후 버전 업그레이드 시 여기에 마이그레이션 로직 추가
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LaunchManagerSettings &&
        other.autoLaunchEnabled == autoLaunchEnabled &&
        _listEquals(other.programs, programs) &&
        other.version == version;
  }

  @override
  int get hashCode {
    return Object.hash(
      autoLaunchEnabled,
      programs,
      version,
    );
  }

  @override
  String toString() {
    return 'LaunchManagerSettings('
        'autoLaunchEnabled: $autoLaunchEnabled, '
        'programs: ${programs.length}, '
        'enabled: $enabledProgramCount, '
        'version: $version)';
  }

  /// 리스트 동등성 비교 유틸리티
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
