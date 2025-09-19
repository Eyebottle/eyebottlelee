# Repository Guidelines

WSL에서 작성한 Flutter 코드를 Windows 데스크톱 환경으로 빠르게 배포하기 위한 지침입니다. 변경 전에는 반드시 `docs/medical-recording-prd.md`와 `docs/developing.md`를 확인해 제품 방향과 개발 계획을 맞춰 주세요.

## Project Structure & Module Organization
- `lib/`는 앱 로직의 중심이며, `services/`(녹음·스케줄), `ui/`(화면·위젯), `models/`, `utils/`로 구성됩니다.
- `docs/`에는 PRD와 개발 가이드가 있으니 기능 정의나 일정 변경 시 함께 갱신합니다.
- `assets/icons/`는 트레이·앱 아이콘을 보관하며, `scripts/`에는 `sync_wsl_to_windows.sh`와 `windows/` 하위 PowerShell 스크립트가 있습니다.
- Windows 데스크톱 빌드 리소스는 `windows/runner/`에 있으며, 플랫폼 수정 전 Flutter 업데이트 여부를 확인합니다.

## Build, Test, and Development Commands
- `flutter pub get` — 의존성을 동기화합니다.
- `flutter run -d windows` — Windows 데스크톱 디바이스로 실행해 UI/오디오 동작을 검증합니다.
- `flutter analyze` 및 `flutter test` — 정적 분석과 단위 테스트를 수행하며, 테스트가 없다면 최소 스텁 추가를 권장합니다.
- `pwsh -File scripts/windows/generate-placeholder-icons.ps1` — 개발용 아이콘 세트를 생성합니다.
- `bash scripts/sync_wsl_to_windows.sh` — WSL→Windows 워킹카피를 수동 동기화합니다.

## Coding Style & Naming Conventions
- Dart 공식 스타일을 따르며 저장 전 `dart format` 또는 IDE 자동 포매터를 사용합니다.
- 파일과 클래스 이름은 UpperCamelCase, 프라이빗 멤버는 선행 `_`, 상수는 UPPER_SNAKE_CASE를 사용합니다.
- UI 위젯은 `lib/ui/widgets/`에서 `FeatureRoleWidget` 식으로 이름 붙이고, 서비스는 `FeatureService` 접미사를 일관되게 유지합니다.

## Testing Guidelines
- 테스트는 `test/` 루트에 배치하고, 파일은 `<target>_test.dart` 패턴을 따릅니다.
- 오디오 세그먼트, 스케줄 계산, 보관 정리 로직은 모킹 가능한 서비스 단위 테스트를 우선 작성합니다.
- 장시간 녹음 시나리오는 PowerShell soak 스크립트 추가 계획(Phase 0)을 참고해 수동 체크리스트라도 결과를 기록합니다.

## Commit & Pull Request Guidelines
- 커밋 메시지는 `docs:`, `feat:`, `fix:` 등 범위 접두사를 사용하고, 필수 설명을 50자 내외로 유지합니다.
- PR에는 변경 요약, 영향 모듈, 테스트 결과(`flutter analyze`, `flutter test`, 수동 시나리오)를 표 형식으로 포함합니다.
- 이슈를 다룰 때는 `Fixes #123` 또는 `Refs #123` 라인을 추가해 추적성을 보장합니다.
- UI 변경은 필요 시 Windows 실행 화면 캡처를 첨부하고, 동기화 스크립트 수정 시 `docs/sync-workflow.md`를 함께 갱신합니다.

## Sync Workflow Essentials
- post-commit 훅이 `scripts/sync_wsl_to_windows.sh`를 호출하므로, 훅 비활성화 시 수동 실행을 잊지 마세요.
- Windows 경로 `C:\\ws-workspace\\eyebottlelee`에서 빌드할 때 열린 편집기가 있다면 동기화 전 저장하고 닫습니다.
- 새 스크립트를 추가할 경우 실행 권한(`chmod +x`)과 Windows 대응 PowerShell 버전을 동시에 제공합니다.

## Security & Configuration Tips
- 비밀 값은 `.env`나 OS 비밀 저장소에 보관하고 레포지토리에 커밋하지 않습니다.
- `pubspec.yaml` 의존성 변경은 `docs/developing.md`의 단계별 계획과 충돌하지 않는지 검토한 뒤 진행합니다.
- Windows 자동 시작이나 OneDrive 경로는 사용자의 관리자 권한에 의존하므로, 실패 시 사용자 안내 문구를 UI와 문서에 동기화합니다.
