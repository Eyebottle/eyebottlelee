import 'package:flutter/material.dart';

import '../../models/launch_program.dart';
import '../../models/launch_manager_settings.dart';
import '../../services/auto_launch_manager_service.dart';
import '../style/app_spacing.dart';
import 'app_section_card.dart';
import 'add_program_dialog.dart';

class LaunchManagerWidget extends StatefulWidget {
  const LaunchManagerWidget({super.key});

  @override
  State<LaunchManagerWidget> createState() => _LaunchManagerWidgetState();
}

class _LaunchManagerWidgetState extends State<LaunchManagerWidget> {
  final AutoLaunchManagerService _launchService = AutoLaunchManagerService();

  LaunchManagerSettings _settings = LaunchManagerSettings.defaultSettings();
  bool _loading = true;
  bool _isExecuting = false;

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
    _launchService.progressStream.listen((progress) {
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

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          AppSpacing.md.vertical,
          _buildProgramList(),
          AppSpacing.lg.vertical,
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rocket_launch, size: 24),
            AppSpacing.sm.horizontal,
            const Text(
              '자동 실행 매니저',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Switch(
              value: _settings.autoLaunchEnabled,
              onChanged: _isExecuting ? null : _toggleAutoLaunch,
            ),
          ],
        ),
        AppSpacing.sm.vertical,
        Text(
          '진료실에서 자주 사용하는 프로그램들을 자동으로 실행합니다.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        if (_settings.autoLaunchEnabled && _settings.enabledPrograms.isNotEmpty)
          Padding(
            padding: AppPadding.sm.copyWith(left: 0),
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
        AppSpacing.sm.vertical,
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
        border: index > 0 ? Border(top: BorderSide(color: Colors.grey[200]!)) : null,
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
            AppSpacing.sm.horizontal,
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
              onPressed: _isExecuting
                  ? null
                  : () => _editProgram(program),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isExecuting
                  ? null
                  : () => _removeProgram(program.id),
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: AppPadding.lg,
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
          AppSpacing.md.vertical,
          Text(
            '등록된 프로그램이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          AppSpacing.sm.vertical,
          Text(
            '자주 사용하는 프로그램을 추가해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isExecuting ? null : _addProgram,
          icon: const Icon(Icons.add),
          label: const Text('프로그램 추가'),
        ),
        AppSpacing.md.horizontal,
        OutlinedButton.icon(
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
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}