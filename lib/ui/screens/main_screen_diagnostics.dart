part of 'main_screen.dart';

/// Dialog to show autostart diagnostics details
class StartupDiagnosticsDialog extends StatelessWidget {
  const StartupDiagnosticsDialog({
    super.key,
    required this.expectedEnabled,
    required this.actualEnabled,
    required this.isPackaged,
    this.packageFamilyName,
    required this.logPath,
  });

  final bool expectedEnabled;
  final bool? actualEnabled;
  final bool isPackaged;
  final String? packageFamilyName;
  final String logPath;

  static Future<void> show(
    BuildContext context, {
    required bool expectedEnabled,
    required bool? actualEnabled,
    required bool isPackaged,
    String? packageFamilyName,
    required String logPath,
  }) {
    return showDialog(
      context: context,
      builder: (context) => StartupDiagnosticsDialog(
        expectedEnabled: expectedEnabled,
        actualEnabled: actualEnabled,
        isPackaged: isPackaged,
        packageFamilyName: packageFamilyName,
        logPath: logPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMismatch =
        actualEnabled != null && actualEnabled != expectedEnabled;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasMismatch
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasMismatch
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      color:
                          hasMismatch ? AppColors.warning : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '자동 시작 진단',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasMismatch
                              ? 'Windows 설정과 앱 설정이 일치하지 않습니다'
                              : '설정이 정상적으로 동기화되어 있습니다',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow(
                      context,
                      label: '앱 설정 (예상)',
                      value: expectedEnabled ? '켜짐' : '꺼짐',
                      isOk: !hasMismatch,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      context,
                      label: 'OS 상태 (실제)',
                      value: actualEnabled == null
                          ? '확인 불가'
                          : actualEnabled!
                              ? '켜짐'
                              : '꺼짐',
                      isOk: !hasMismatch,
                      isUnknown: actualEnabled == null,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Package info
                    Text(
                      '패키지 정보',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(context, '패키지 형태',
                        isPackaged ? 'MSIX (Store)' : '비패키지 실행'),
                    if (packageFamilyName != null &&
                        packageFamilyName!.isNotEmpty)
                      _buildInfoRow(
                          context, 'PackageFamilyName', packageFamilyName!),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Log path
                    Text(
                      '로그 파일 경로',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.neutral50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined,
                              color: AppColors.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              logPath,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasMismatch) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Windows 설정 > 앱 > 시작프로그램에서 "Eyebottle Medical Recorder" 상태를 확인하세요.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool isOk,
    bool isUnknown = false,
  }) {
    final theme = Theme.of(context);
    final color = isUnknown
        ? AppColors.textSecondary
        : isOk
            ? AppColors.success
            : AppColors.warning;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
