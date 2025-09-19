# Application Icons

이 디렉터리에는 Windows 데스크톱 및 트레이 아이콘으로 사용하는 리소스가 포함되어 있습니다.

| 파일 | 설명 | 원본 아이콘 |
| --- | --- | --- |
| `icon.ico` | 앱 메인 아이콘 (스토어/창) | Tabler Icons – `stethoscope` |
| `tray_recording.ico` | 녹음 중 트레이 아이콘 (빨간색) | Tabler Icons – `microphone` |
| `tray_waiting.ico` | 대기 상태 트레이 아이콘 (회색) | Tabler Icons – `hourglass` |
| `tray_error.ico` | 오류 상태 트레이 아이콘 (노란색) | Tabler Icons – `alert-triangle` |

- 모든 아이콘은 [Tabler Icons](https://tabler-icons.io)에서 가져왔으며 MIT 라이선스이며, 수정된 색상 버전을 사용했습니다.
- 원본 SVG(`*.svg`)와 변환된 ICO 파일을 함께 보관해 향후 색상/크기 변경 시 참고합니다.
- 새로운 아이콘을 추가할 경우, `convert` (ImageMagick)으로 다음 커맨드를 사용하세요.

```bash
convert source.svg -background none -resize 256x256 -define icon:auto-resize=256,128,64,48,32,16 target.ico
```

라이선스 전문은 `TABLER_LICENSE.txt`를 참조하세요.
