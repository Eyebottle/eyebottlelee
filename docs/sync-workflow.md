# WSL ↔ Windows 동기화 흐름 가이드

본 문서는 `/home/usereyebottle/projects/eyebottlelee`(WSL)와 `C:\ws-workspace\eyebottlelee`(Windows) 사이의 코드 동기화 방식을 정리한다. Windows 데스크톱 빌드를 안정적으로 실행하기 위해서는 소스가 NTFS 경로에도 존재해야 하며, 아래 흐름을 통해 이를 자동/수동으로 유지한다.

## 1. 도입 배경

- Flutter Windows 데스크톱 빌드는 NTFS 상의 프로젝트 경로를 요구한다.
- WSL 공유(`\\wsl$`) 환경에서는 심볼릭 링크 생성과 파일 권한 차이로 인해 빌드가 반복적으로 실패하였다.
- 이를 해결하기 위해 WSL의 실개발 경로를 기준으로 Windows 작업 트리(`C:\ws-workspace\eyebottlelee`)를 유지하며, 변경 사항을 동기화하도록 구성하였다.

## 2. 동기화 구성 요소

### 2.1 스크립트

- 위치: `scripts/sync_wsl_to_windows.sh`
- 내용: rsync 기반으로 WSL → Windows 방향 복사를 수행한다.
- 제외 디렉터리
  - `.git/`: Git 메타데이터는 복사 불필요
  - `build/`: 빌드 산출물은 매 실행 시 생성됨
  - `.dart_tool/`: Flutter/Dart 캐시
  - `.claude/`: 도구별 임시 설정 파일
  - `windows/flutter/ephemeral/`: Flutter가 자동 생성하는 임시 폴더(Windows 권한 문제를 야기할 수 있어 매 동기화 시 재생성하도록 제외)

### 2.2 Git post-commit 훅

- 위치: `.git/hooks/post-commit`
- 역할: 커밋이 완료될 때마다 위 스크립트를 호출해 자동 동기화를 수행한다.
- 구현: 프로젝트 루트 경로를 구한 뒤 `scripts/sync_wsl_to_windows.sh`를 실행하도록 지정.

### 2.3 수동 실행 alias

- `~/.bashrc`에 `alias syncw='~/projects/eyebottlelee/scripts/sync_wsl_to_windows.sh'`를 등록했다.
- 새 터미널에서 `syncw` 명령만 입력하면 즉시 동기화를 수행할 수 있다.

## 3. 사용 방법

### 3.1 일반 개발 흐름

1. WSL 환경에서 코드 작업 및 저장.
2. `git commit` 실행.
3. 커밋 완료 후 post-commit 훅이 자동으로 동기화 스크립트를 실행.
4. Windows 측 `C:\ws-workspace\eyebottlelee`에서 Android Studio 또는 Flutter CLI로 Windows 빌드 실행.

### 3.2 수동 실행이 필요한 경우

- 커밋 없이 코드만 테스트해야 할 때 WSL 터미널에서 `syncw` 명령을 직접 실행한다.
- 현재 세션에 alias가 적용되지 않았다면 `source ~/.bashrc` 이후 실행.

## 4. 문제 해결

- **권한 거부(Permission denied)**: Windows 경로를 사용 중인 프로세스(Android Studio, 탐색기 등)를 종료하고 다시 시도한다. `windows/flutter/ephemeral/` 폴더는 관리자 PowerShell에서 `Remove-Item ... -Recurse -Force`로 삭제할 수 있다.
- **ephemeral 폴더가 자동으로 생성됨**: Flutter가 빌드 시 재생성하므로 동기화 스크립트에서 제외되어도 정상이다. 삭제 후 빌드하면 자동 복원된다.
- **동기화 스크립트 수정 필요 시**: `scripts/sync_wsl_to_windows.sh`를 편집하고 실행 권한(`chmod +x`)을 유지한다.

## 5. 향후 확장

- 필요 시 post-commit 훅 외에 `pre-push` 훅, inotify 기반 실시간 감시 등을 추가할 수 있다. 다만 빌드 산출물이 많으므로 현 구성(커밋 시 자동, 필요 시 수동)이 가장 안정적이다.

