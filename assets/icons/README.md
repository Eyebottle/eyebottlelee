# Application Icons

이 디렉터리에는 Windows 데스크톱 및 트레이 아이콘으로 사용하는 리소스가 포함되어 있습니다.

| 파일 | 설명 | 원본 |
| --- | --- | --- |
| `icon.ico` | 앱 아이콘 (16~256, exe/창용). 1024 원본에서 LANCZOS로 재생성 | `assets/images/eyebottle-logo.png` (1024) |
| `tray_recording.ico` | 녹음 중 트레이 아이콘 (빨간색) | Tabler Icons – `microphone` |
| `tray_waiting.ico` | 대기 상태 트레이 아이콘 (회색) | Tabler Icons – `hourglass` |
| `tray_error.ico` | 오류 상태 트레이 아이콘 (노란색) | Tabler Icons – `alert-triangle` |

- **MSIX 타일 로고**는 `pubspec.yaml`의 `msix_config.logo_path` = `assets/images/eyebottle-logo.png`
  (1024)를 사용한다. 과거 256 한도의 `icon.ico`를 쓰면 큰 타일에서 업스케일되어 흐릿했다.
- exe 창/작업표시줄 아이콘은 `windows/runner/resources/app_icon.ico`(역시 1024 원본에서 재생성).
- 트레이 아이콘은 Tabler Icons(MIT) 색상 변형. 원본 SVG(`*.svg`)도 함께 보관한다.
- 아이콘 재생성(ImageMagick 없을 때는 Python PIL):

```python
from PIL import Image
src = Image.open('assets/images/eyebottle-logo.png').convert('RGBA')
sizes = [16, 24, 32, 48, 64, 128, 256]
[src.resize((s, s), Image.LANCZOS) for s in sizes][-1].save(
    'assets/icons/icon.ico', format='ICO', sizes=[(s, s) for s in sizes])
```

라이선스 전문은 `TABLER_LICENSE.txt`를 참조하세요.
