import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../models/launch_program.dart';
import '../../services/auto_launch_manager_service.dart';
import '../style/app_spacing.dart';

class AddProgramDialog extends StatefulWidget {
  const AddProgramDialog({
    super.key,
    this.program, // null이면 새 프로그램 추가, 있으면 편집
    this.initialPath, // 드래그 앤 드롭 등으로 미리 채울 경로
  });

  final LaunchProgram? program;
  final String? initialPath;

  /// 새 프로그램 추가 다이얼로그
  ///
  /// [initialPath]가 주어지면 경로/이름을 미리 채운다(드래그 앤 드롭 진입용).
  static Future<LaunchProgram?> showAdd(
    BuildContext context, {
    String? initialPath,
  }) {
    return showDialog<LaunchProgram>(
      context: context,
      builder: (context) => AddProgramDialog(initialPath: initialPath),
    );
  }

  /// 기존 프로그램 편집 다이얼로그
  static Future<LaunchProgram?> showEdit(
    BuildContext context,
    LaunchProgram program,
  ) {
    return showDialog<LaunchProgram>(
      context: context,
      builder: (context) => AddProgramDialog(program: program),
    );
  }

  @override
  State<AddProgramDialog> createState() => _AddProgramDialogState();
}

class _AddProgramDialogState extends State<AddProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final _argumentsController = TextEditingController();
  final _workingDirectoryController = TextEditingController();

  final AutoLaunchManagerService _launchService = AutoLaunchManagerService();

  double _delaySeconds = 10.0;
  WindowState _windowState = WindowState.normal;
  bool _enabled = true;
  bool _isTesting = false;
  bool _showAdvanced = false;

  bool get _isEditing => widget.program != null;

  @override
  void initState() {
    super.initState();
    _initializeFromProgram();
  }

  bool _isPathDragging = false;

  void _initializeFromProgram() {
    if (widget.program != null) {
      final program = widget.program!;
      _nameController.text = program.name;
      _pathController.text = program.path;
      _argumentsController.text = program.arguments
          .map((a) => a.contains(' ') || a.contains('\t') ? '"$a"' : a)
          .join(' ');
      _workingDirectoryController.text = program.workingDirectory ?? '';
      _delaySeconds = program.delaySeconds.toDouble();
      _windowState = program.windowState;
      _enabled = program.enabled;
    } else if (widget.initialPath != null &&
        widget.initialPath!.trim().isNotEmpty) {
      _fillFromPath(widget.initialPath!.trim());
    }
  }

  /// 경로로부터 경로/이름 필드를 채운다(이름이 비어 있을 때만 자동 추출).
  void _fillFromPath(String path) {
    _pathController.text = path;
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = LaunchProgram.extractProgramName(path);
    }
  }

  Future<void> _selectFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: '실행 파일',
      extensions: ['exe', 'lnk', 'bat', 'cmd'],
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: [typeGroup],
    );

    if (file != null) {
      setState(() {
        _pathController.text = file.path;
        if (_nameController.text.isEmpty) {
          _nameController.text = LaunchProgram.extractProgramName(file.path);
        }
      });
    }
  }

  Future<void> _selectWorkingDirectory() async {
    final String? directory = await getDirectoryPath();
    if (directory != null) {
      setState(() {
        _workingDirectoryController.text = directory;
      });
    }
  }

  Future<void> _testProgram() async {
    if (!_formKey.currentState!.validate()) return;

    final program = _createProgram();
    if (program == null) return;

    setState(() {
      _isTesting = true;
    });

    try {
      final success = await _launchService.testLaunchProgram(program);
      if (mounted) {
        final message = success
            ? '✅ 프로그램이 성공적으로 실행되었습니다.\n경로: ${program.path}'
            : '❌ 프로그램 실행에 실패했습니다.\n경로: ${program.path}\n\n로그 파일을 확인하세요:\nC:\\Users\\<사용자명>\\Documents\\EyebottleRecorder\\logs\\';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: success
                ? const Duration(seconds: 3)
                : const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '테스트 실행 중 오류가 발생했습니다:\n${e.toString()}\n\n경로: ${program.path}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  /// 따옴표를 인식하는 인수 토크나이저.
  ///
  /// `--config="C:\Program Files\x"` 처럼 공백이 포함된 인수를 따옴표 기준으로
  /// 하나의 논리 인수로 묶는다. (기존 `split(' ')`는 공백마다 쪼개 인수를 깨뜨렸다.)
  /// 반환값은 논리 인수 목록이며, Windows에서 셸/프로세스 호출 시 각 요소의
  /// 따옴표 처리는 하위 계층(win32_shell_execute)이 담당하므로 여기서는
  /// 이스케이프 백슬래시를 넣지 않는다.
  static List<String> _tokenizeArguments(String input) {
    final args = <String>[];
    final buf = StringBuffer();
    String? quote; // null, '"' 또는 "'"
    var hasToken = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else {
          buf.write(c);
        }
      } else if (c == '"' || c == "'") {
        quote = c;
        hasToken = true;
      } else if (c == ' ' || c == '\t') {
        if (hasToken) {
          args.add(buf.toString());
          buf.clear();
          hasToken = false;
        }
      } else {
        buf.write(c);
        hasToken = true;
      }
    }
    if (hasToken) args.add(buf.toString());
    return args;
  }

  LaunchProgram? _createProgram() {
    if (_pathController.text.isEmpty) return null;

    final arguments = _tokenizeArguments(_argumentsController.text.trim());

    final workingDirectory = _workingDirectoryController.text.trim();

    return LaunchProgram(
      id: widget.program?.id ?? LaunchProgram.generateId(_pathController.text),
      name: _nameController.text.trim(),
      path: _pathController.text.trim(),
      arguments: arguments,
      workingDirectory: workingDirectory.isEmpty ? null : workingDirectory,
      delaySeconds: _delaySeconds.round(),
      windowState: _windowState,
      enabled: _enabled,
      order: widget.program?.order ?? 0, // 실제 순서는 LaunchManagerSettings에서 처리
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final program = _createProgram();
    if (program != null) {
      Navigator.of(context).pop(program);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicSettings(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildAdvancedToggle(),
                        if (_showAdvanced) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildAdvancedSettings(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _isEditing ? Icons.edit : Icons.add,
          size: 24,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _isEditing ? '프로그램 편집' : '프로그램 추가',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildBasicSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로그램 경로
        const Text(
          '프로그램 경로 *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropTarget(
          onDragEntered: (_) => setState(() => _isPathDragging = true),
          onDragExited: (_) => setState(() => _isPathDragging = false),
          onDragDone: (detail) {
            setState(() => _isPathDragging = false);
            if (detail.files.isEmpty) return;
            final path = detail.files.first.path.trim();
            if (path.isEmpty) return;
            setState(() => _fillFromPath(path));
          },
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    hintText: '경로를 선택하거나 파일을 끌어다 놓으세요',
                    border: const OutlineInputBorder(),
                    enabledBorder: _isPathDragging
                        ? OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '프로그램 경로를 선택해주세요';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: _selectFile,
                child: const Text('찾기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.drag_indicator, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '실행 파일(.exe)·바로가기(.lnk)를 여기로 끌어다 놓아도 됩니다',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // 프로그램 이름
        const Text(
          '프로그램 이름 *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: '프로그램 이름을 입력하세요',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '프로그램 이름을 입력해주세요';
            }
            return null;
          },
        ),

        const SizedBox(height: AppSpacing.md),

        // 지연 시간
        const Text(
          '실행 후 대기 시간',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _delaySeconds,
                min: 5,
                max: 60,
                divisions: 11,
                label: '${_delaySeconds.round()}초',
                onChanged: (value) {
                  setState(() {
                    _delaySeconds = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '${_delaySeconds.round()}초',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        Text(
          '이전 프로그램 실행 후 이 프로그램을 실행하기까지 대기할 시간입니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 활성화 상태
        SwitchListTile(
          title: const Text('프로그램 활성화'),
          subtitle: const Text('체크해제하면 자동 실행에서 제외됩니다'),
          value: _enabled,
          onChanged: (value) {
            setState(() {
              _enabled = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _showAdvanced = !_showAdvanced;
        });
      },
      child: Row(
        children: [
          Icon(
            _showAdvanced ? Icons.expand_less : Icons.expand_more,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '고급 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 명령줄 인수
        const Text(
          '명령줄 인수',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _argumentsController,
          decoration: const InputDecoration(
            hintText: '예: --fullscreen --config=config.ini',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '프로그램 실행 시 전달할 명령줄 인수를 입력하세요 (공백으로 구분)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 작업 디렉터리
        const Text(
          '작업 디렉터리',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _workingDirectoryController,
                decoration: const InputDecoration(
                  hintText: '프로그램이 실행될 작업 폴더를 선택하세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: _selectWorkingDirectory,
              child: const Text('찾기'),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // 창 상태
        const Text(
          '창 상태',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<WindowState>(
          value: _windowState,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: WindowState.normal,
              child: Text('일반'),
            ),
            DropdownMenuItem(
              value: WindowState.minimized,
              child: Text('최소화'),
            ),
            DropdownMenuItem(
              value: WindowState.maximized,
              child: Text('최대화'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _windowState = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testProgram,
          icon: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isTesting ? '테스트 중...' : '테스트 실행'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton(
          onPressed: _save,
          child: Text(_isEditing ? '수정' : '추가'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _argumentsController.dispose();
    _workingDirectoryController.dispose();
    super.dispose();
  }
}
