#!/usr/bin/env python3
"""
MS Store 스크린샷 완전 자동 캡처 스크립트
앱을 실행하고 자동으로 5개 스크린샷을 캡처합니다.
"""

import subprocess
import time
import os
from pathlib import Path

try:
    import pyautogui
    import pygetwindow as gw
except ImportError:
    print("필요한 패키지를 설치합니다...")
    subprocess.run(["pip", "install", "pyautogui", "pygetwindow", "pillow"], check=True)
    import pyautogui
    import pygetwindow as gw

# 설정
APP_TITLE = "아이보틀 진료 녹음"  # 앱 창 제목
SCREENSHOT_DIR = Path(__file__).parent.parent.parent / "screenshots"
APP_PATH = r"C:\wsl\eyebottlelee\eyebottlelee-test-release\medical_recorder.exe"

# 스크린샷 디렉토리 생성
SCREENSHOT_DIR.mkdir(exist_ok=True)

def find_app_window():
    """앱 창 찾기"""
    windows = gw.getWindowsWithTitle(APP_TITLE)
    if not windows:
        # 부분 매칭 시도
        all_windows = gw.getAllTitles()
        for title in all_windows:
            if "진료" in title or "녹음" in title or "eyebottle" in title.lower():
                windows = gw.getWindowsWithTitle(title)
                if windows:
                    return windows[0]
        return None
    return windows[0]

def activate_window(window):
    """창 활성화 및 최대화"""
    try:
        if window.isMinimized:
            window.restore()
        window.activate()
        time.sleep(0.5)
        # 최대화는 선택적
        # window.maximize()
        return True
    except Exception as e:
        print(f"창 활성화 실패: {e}")
        return False

def capture_screenshot(filename, window=None):
    """스크린샷 캡처"""
    try:
        if window:
            # 창 영역만 캡처
            left, top, width, height = window.left, window.top, window.width, window.height
            screenshot = pyautogui.screenshot(region=(left, top, width, height))
        else:
            # 전체 화면 캡처
            screenshot = pyautogui.screenshot()

        filepath = SCREENSHOT_DIR / filename
        screenshot.save(filepath)

        # 파일 크기 확인
        size_mb = filepath.stat().st_size / (1024 * 1024)
        print(f"✓ {filename} 캡처 완료 ({size_mb:.2f} MB)")
        return True
    except Exception as e:
        print(f"✗ {filename} 캡처 실패: {e}")
        return False

def click_tab(tab_name):
    """탭 클릭 (텍스트 인식)"""
    try:
        # 화면에서 텍스트 찾기 시도
        location = pyautogui.locateOnScreen(tab_name, confidence=0.8)
        if location:
            pyautogui.click(location)
            time.sleep(1)
            return True

        # 좌표 기반 클릭 (앱 구조에 따라 조정 필요)
        print(f"  {tab_name} 탭을 수동으로 클릭해주세요 (3초 대기)...")
        time.sleep(3)
        return True
    except Exception as e:
        print(f"  탭 클릭 실패: {e}, 수동으로 클릭해주세요 (3초 대기)...")
        time.sleep(3)
        return True

def main():
    print("=" * 50)
    print("MS Store 스크린샷 자동 캡처 도구")
    print("=" * 50)
    print()

    # 앱 실행 확인
    print("1. 앱 찾는 중...")
    window = find_app_window()

    if not window:
        print(f"  앱을 찾을 수 없습니다: '{APP_TITLE}'")
        print(f"  앱을 실행해주세요: {APP_PATH}")
        print("  10초 대기 후 다시 시도...")
        time.sleep(10)
        window = find_app_window()

        if not window:
            print("  앱을 여전히 찾을 수 없습니다. 수동으로 실행해주세요.")
            return False

    print(f"  ✓ 앱 찾음: {window.title}")
    print()

    # 2초 대기
    print("2초 후 캡처 시작...")
    time.sleep(2)

    screenshots = [
        ("screenshot-1-dashboard.png", "대시보드", None),
        ("screenshot-2-schedule.png", "녹음 설정", None),
        ("screenshot-3-advanced-settings.png", "고급 설정 (다이얼로그 열기)", "고급 설정 버튼 클릭"),
        ("screenshot-4-auto-launch.png", "자동 실행", None),
        ("screenshot-5-help.png", "도움말", "도움말 버튼 클릭"),
    ]

    for i, (filename, description, action) in enumerate(screenshots, 1):
        print(f"\n[{i}/5] {description}")

        # 창 활성화
        if not activate_window(window):
            print("  창 활성화 실패")
            continue

        # 액션 수행 (필요시)
        if action:
            print(f"  {action} 필요 - 3초 대기...")
            time.sleep(3)
        else:
            # 탭 전환 대기
            print(f"  '{description}' 탭으로 전환 필요 - 3초 대기...")
            time.sleep(3)

        # 스크린샷 캡처
        capture_screenshot(filename, window)

        # 다음 캡처 전 대기
        time.sleep(1)

    print()
    print("=" * 50)
    print("스크린샷 캡처 완료!")
    print("=" * 50)
    print()
    print(f"저장 위치: {SCREENSHOT_DIR}")
    print()

    # 결과 확인
    print("캡처된 파일:")
    for file in sorted(SCREENSHOT_DIR.glob("screenshot-*.png")):
        size_mb = file.stat().st_size / (1024 * 1024)
        print(f"  ✓ {file.name} ({size_mb:.2f} MB)")

    return True

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n중단됨")
    except Exception as e:
        print(f"\n오류 발생: {e}")
        import traceback
        traceback.print_exc()
