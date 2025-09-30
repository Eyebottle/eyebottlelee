import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'help_section.dart';

class HelpCenterDialog {
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onStartDashboardTutorial,
    VoidCallback? onStartSettingsTutorial,
    VoidCallback? onStartAutoLaunchTutorial,
  }) {
    return showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, theme),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: _HelpContent(
                      onStartDashboardTutorial: onStartDashboardTutorial,
                      onStartSettingsTutorial: onStartSettingsTutorial,
                      onStartAutoLaunchTutorial: onStartAutoLaunchTutorial,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Text('닫기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '도움말 & 빠른 시작',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '처음 설치부터 녹음 흐름, 트레이 제어, 문제 해결까지 핵심 내용을 정리했습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
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
    );
  }
}

class _HelpContent extends StatelessWidget {
  const _HelpContent({
    this.onStartDashboardTutorial,
    this.onStartSettingsTutorial,
    this.onStartAutoLaunchTutorial,
  });

  final VoidCallback? onStartDashboardTutorial;
  final VoidCallback? onStartSettingsTutorial;
  final VoidCallback? onStartAutoLaunchTutorial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HelpSection(
          icon: Icons.play_circle_fill,
          title: '1. 첫 실행 체크리스트',
          description:
              '마이크 권한을 확인하고 기본 스케줄(09:00~13:00 / 14:00~18:00)을 검토하세요. 저장 폴더는 OneDrive를 권장합니다.',
          actions: [
            FilledButton.tonal(
              onPressed: () => _openDocsSection('docs/user-guide.md#1-준비-사항'),
              child: const Text('사용 가이드 열기'),
            ),
          ],
        ),
        HelpSection(
          icon: Icons.dashboard_customize,
          title: '2. 대시보드',
          description:
              '녹음 상태 카드에서 수동으로 시작/중지할 수 있고, 오늘 일정과 저장 정책을 한눈에 볼 수 있습니다.',
          actions: [
            if (onStartDashboardTutorial != null)
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  onStartDashboardTutorial!();
                },
                child: const Text('대시보드 튜토리얼'),
              ),
          ],
        ),
        HelpSection(
          icon: Icons.schedule,
          title: '3. 진료 시간표 & 보관 설정',
          description:
              '설정 탭에서 요일별 오전/오후 시간을 조절하고, 녹음 품질·민감도(저장 공간 절약), 무음 감지, 보관 기간을 관리하세요.',
          actions: [
            if (onStartSettingsTutorial != null)
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  onStartSettingsTutorial!();
                },
                child: const Text('설정 튜토리얼'),
              ),
          ],
        ),
        HelpSection(
          icon: Icons.rocket_launch,
          title: '4. 자동 실행 매니저',
          description:
              '자주 사용하는 프로그램들(EMR, 문서 등)을 앱 시작 시 자동으로 실행합니다. 프로그램 추가 후 순서와 대기 시간을 조정할 수 있습니다.',
          actions: [
            if (onStartAutoLaunchTutorial != null)
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  onStartAutoLaunchTutorial!();
                },
                child: const Text('자동 실행 튜토리얼'),
              ),
          ],
        ),
        HelpSection(
          icon: Icons.mic_external_on,
          title: '5. 마이크 점검',
          description:
              '앱 시작 시 자동으로 3초 샘플을 녹음해 입력 레벨을 확인합니다. 정상 기준은 RMS 0.04 이상입니다.',
          actions: [
            TextButton(
              onPressed: () => _openDocsSection('docs/user-guide.md#7-자동-마이크-점검-해석'),
              child: const Text('민감도 설명 보기'),
            ),
          ],
        ),
        HelpSection(
          icon: Icons.system_update_alt,
          title: '6. 시스템 트레이',
          description:
              '창을 닫아도 앱은 트레이에서 계속 실행됩니다. 좌/더블 클릭으로 창을 복원하고, 우클릭 메뉴로 녹음 토글·마이크 점검·설정·종료를 실행하세요.',
        ),
        HelpSection(
          icon: Icons.help_outline,
          title: '7. 문제 해결 & FAQ',
          description:
              '마이크 권한, 자동 시작, 스케줄 적용 문제는 사용자 가이드의 FAQ 섹션에서 확인할 수 있습니다.',
          actions: [
            FilledButton(
              onPressed: () => _openDocsSection('docs/user-guide.md#9-문제-해결--faq'),
              child: const Text('FAQ 확인'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '더 궁금한 점이 있으면 개발 가이드 또는 팀 채널에 문의하세요.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

Future<void> _openDocsSection(String relativePath) async {
  final uri = Uri.parse('https://github.com/eyebottle/eyebottlelee/blob/main/$relativePath');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('문서를 열 수 없습니다: $uri');
  }
}
