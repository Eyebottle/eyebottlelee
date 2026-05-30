import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../models/launch_program.dart';
import '../../models/launch_manager_settings.dart';
import '../../services/auto_launch_manager_service.dart';
import '../style/app_spacing.dart';
import 'app_section_card.dart';
import 'add_program_dialog.dart';

class LaunchManagerWidget extends StatefulWidget {
  const LaunchManagerWidget({
    super.key,
    this.onAutoLaunchChanged,
    this.switchShowcaseKey,
    this.addButtonShowcaseKey,
    this.testButtonShowcaseKey,
  });

  final void Function(bool enabled)? onAutoLaunchChanged;
  final GlobalKey? switchShowcaseKey;
  final GlobalKey? addButtonShowcaseKey;
  final GlobalKey? testButtonShowcaseKey;

  @override
  State<LaunchManagerWidget> createState() => _LaunchManagerWidgetState();
}

class _LaunchManagerWidgetState extends State<LaunchManagerWidget> {
  final AutoLaunchManagerService _launchService = AutoLaunchManagerService();

  LaunchManagerSettings _settings = LaunchManagerSettings.defaultSettings();
  bool _loading = true;
  bool _isExecuting = false;
  bool _isDragging = false;

  // Stream 구독 관리
  StreamSubscription<LaunchExecutionProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _subscribeToProgress();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _launchService.loadSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showErrorSnackBar('설정을 불러오는 중 오류가 발생했습니다: $e');
      }
    }
  }

  void _subscribeToProgress() {
    _progressSubscription = _launchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _isExecuting = progress.isRunning;
        });

        if (progress.isCompleted) {
          _showInfoSnackBar(progress.message ?? '프로그램 실행이 완료되었습니다.');
        } else if (progress.isFailed) {
          _showErrorSnackBar(progress.errorMessage ?? '프로그램 실행 중 오류가 발생했습니다.');
        }
      }
    });
  }

  Future<void> _saveSettings() async {
    try {
      await _launchService.saveSettings(_settings);
    } catch (e) {
      _showErrorSnackBar('설정을 저장하는 중 오류가 발생했습니다: $e');
    }
  }

  void _toggleAutoLaunch(bool enabled) {
    setState(() {
      _settings = _settings.copyWith(autoLaunchEnabled: enabled);
    });
    _saveSettings();
    widget.onAutoLaunchChanged?.call(enabled);
  }

  void _toggleProgramEnabled(String programId, bool enabled) {
    final program = _settings.programs.firstWhere((p) => p.id == programId);
    final updatedProgram = program.copyWith(enabled: enabled);

    setState(() {
      _settings = _settings.updateProgram(updatedProgram);
    });
    _saveSettings();
  }

  Future<void> _addProgram() async {
    final program = await AddProgramDialog.showAdd(context);
    if (program == null) return;

    setState(() {
      _settings = _settings.addProgram(program);
    });

    await _saveSettings();
    _showInfoSnackBar('${program.name} 프로그램이 추가되었습니다.');
  }

  /// 드래그 앤 드롭으로 떨어진 파일 경로들을 프로그램으로 등록한다.
  ///
  /// - 1개: 추가 다이얼로그를 경로/이름이 채워진 채로 열어 사용자가 확인·조정.
  /// - 여러 개: 기본값(대기 10초, 활성화)으로 일괄 등록. 이미 등록된 경로는 건너뜀.
  Future<void> _handleDroppedPaths(List<String> paths) async {
    if (_isExecuting) return;

    final valid = paths.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (valid.isEmpty) return;

    if (valid.length == 1) {
      final program =
          await AddProgramDialog.showAdd(context, initialPath: valid.first);
      if (program == null) return;
      setState(() {
        _settings = _settings.addProgram(program);
      });
      await _saveSettings();
      _showInfoSnackBar('${program.name} 프로그램이 추가되었습니다.');
      return;
    }

    final existingPaths =
        _settings.programs.map((p) => p.path.toLowerCase()).toSet();
    var working = _settings;
    var added = 0;
    for (final path in valid) {
      final key = path.toLowerCase();
      if (existingPaths.contains(key)) continue;
      existingPaths.add(key);
      working = working.addProgram(
        LaunchProgram(
          id: LaunchProgram.generateId(path),
          name: LaunchProgram.extractProgramName(path),
          path: path,
          order: 0, // 실제 순서는 addProgram에서 재할당
        ),
      );
      added++;
    }

    if (added == 0) {
      _showInfoSnackBar('이미 등록된 프로그램입니다.');
      return;
    }

    setState(() {
      _settings = working;
    });
    await _saveSettings();
    _showInfoSnackBar('$added개 프로그램이 추가되었습니다. 목록에서 대기 시간을 조정하세요.');
  }

  Future<void> _editProgram(LaunchProgram program) async {
    final updatedProgram = await AddProgramDialog.showEdit(context, program);
    if (updatedProgram == null) return;

    setState(() {
      _settings = _settings.updateProgram(updatedProgram);
    });

    await _saveSettings();
    _showInfoSnackBar('${updatedProgram.name} 프로그램이 수정되었습니다.');
  }

  void _removeProgram(String programId) {
    final program = _settings.programs.firstWhere((p) => p.id == programId);

    setState(() {
      _settings = _settings.removeProgram(programId);
    });

    _saveSettings();
    _showInfoSnackBar('${program.name} 프로그램이 제거되었습니다.');
  }

  void _reorderPrograms(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final programs = List<LaunchProgram>.from(_settings.programs);
    final program = programs.removeAt(oldIndex);
    programs.insert(newIndex, program);

    setState(() {
      _settings = _settings.reorderPrograms(programs);
    });

    _saveSettings();
  }

  Future<void> _testExecution() async {
    if (_settings.enabledPrograms.isEmpty) {
      _showErrorSnackBar('실행할 프로그램이 없습니다.');
      return;
    }

    await _launchService.executePrograms();
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppSectionCard(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return DropTarget(
      onDragEntered: (_) {
        if (!_isExecuting) setState(() => _isDragging = true);
      },
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        _handleDroppedPaths(detail.files.map((f) => f.path).toList());
      },
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return AppSectionCard(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppSpacing.md),
                        _buildProgramList(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isDragging) Positioned.fill(child: _buildDropOverlay()),
        ],
      ),
    );
  }

  Widget _buildDropOverlay() {
    final color = Theme.of(context).primaryColor;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha((0.06 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_download_outlined, size: 40, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '여기에 놓아 프로그램 추가',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Widget switchWidget = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _settings.autoLaunchEnabled
            ? const Color(0xFF1193D4).withAlpha((0.08 * 255).round())
            : Colors.grey.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _settings.autoLaunchEnabled
              ? const Color(0xFF1193D4).withAlpha((0.2 * 255).round())
              : Colors.grey.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.power_settings_new,
            size: 24,
            color: _settings.autoLaunchEnabled
                ? const Color(0xFF1193D4)
                : Colors.grey[600],
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            '자동 실행',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _settings.autoLaunchEnabled ? '켜짐' : '꺼짐',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _settings.autoLaunchEnabled
                  ? const Color(0xFF2E7D32)
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: _settings.autoLaunchEnabled,
            onChanged: _isExecuting ? null : _toggleAutoLaunch,
          ),
        ],
      ),
    );

    if (widget.switchShowcaseKey != null) {
      switchWidget = Showcase(
        key: widget.switchShowcaseKey!,
        description: '자동 실행을 켜면 앱 시작 시 등록된 프로그램들이 순차적으로 실행됩니다.',
        child: switchWidget,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switchWidget,
        if (_settings.autoLaunchEnabled && _settings.enabledPrograms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              '총 ${_settings.enabledPrograms.length}개 프로그램이 자동 실행됩니다.',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgramList() {
    if (_settings.programs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프로그램 목록',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _reorderPrograms,
            itemCount: _settings.programs.length,
            itemBuilder: (context, index) {
              final program = _settings.programs[index];
              return _buildProgramTile(program, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgramTile(LaunchProgram program, int index) {
    final isValid = program.isValid;

    return Container(
      key: ValueKey(program.id),
      decoration: BoxDecoration(
        border: index > 0
            ? Border(top: BorderSide(color: Colors.grey[200]!))
            : null,
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              isValid ? Icons.computer : Icons.error,
              color: isValid ? Colors.blue : Colors.red,
              size: 20,
            ),
          ],
        ),
        title: Text(
          program.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isValid ? null : Colors.red,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              program.path,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isValid)
              const Text(
                '파일을 찾을 수 없습니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            Text(
              '${program.delaySeconds}초 대기',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: program.enabled,
              onChanged: _isExecuting
                  ? null
                  : (enabled) => _toggleProgramEnabled(program.id, enabled),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _isExecuting ? null : () => _editProgram(program),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isExecuting ? null : () => _removeProgram(program.id),
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.computer,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '등록된 프로그램이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '자주 사용하는 프로그램을 추가해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '실행 파일(.exe)이나 바로가기(.lnk)를 여기로 끌어다 놓아도 됩니다',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    Widget addButton = ElevatedButton.icon(
      onPressed: _isExecuting ? null : _addProgram,
      icon: const Icon(Icons.add),
      label: const Text('프로그램 추가'),
    );

    if (widget.addButtonShowcaseKey != null) {
      addButton = Showcase(
        key: widget.addButtonShowcaseKey!,
        description:
            '프로그램 추가 버튼을 누르면 실행 파일을 선택하고 대기 시간을 설정할 수 있습니다. 추가 후 드래그로 실행 순서를 조정하세요.',
        child: addButton,
      );
    }

    Widget testButton = OutlinedButton.icon(
      onPressed: _isExecuting || _settings.enabledPrograms.isEmpty
          ? null
          : _testExecution,
      icon: _isExecuting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow),
      label: Text(_isExecuting ? '실행 중...' : '테스트 실행'),
    );

    if (widget.testButtonShowcaseKey != null) {
      testButton = Showcase(
        key: widget.testButtonShowcaseKey!,
        description: '등록한 프로그램들이 제대로 실행되는지 테스트해볼 수 있습니다.',
        child: testButton,
      );
    }

    return Row(
      children: [
        addButton,
        const SizedBox(width: AppSpacing.md),
        testButton,
      ],
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
