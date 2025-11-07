# GitHub Pages 설정 가이드

이 문서는 `eyebottlelee` 프로젝트의 GitHub Pages를 활성화하여 개인정보 처리방침을 웹에 게시하는 방법을 설명합니다.

---

## 🎯 목표

**개인정보 처리방침 URL 생성:**
```
https://eyebottle.github.io/eyebottlelee/privacy-policy
```

이 URL은 MS Store 제출 시 개인정보 처리방침 URL로 사용됩니다.

---

## ✅ 사전 준비 (완료됨)

다음 파일들이 이미 준비되었습니다:
- ✅ `docs/_config.yml` - Jekyll 설정
- ✅ `docs/index.md` - 홈페이지
- ✅ `docs/privacy-policy.md` - 개인정보 처리방침

---

## 📋 GitHub Pages 활성화 단계

### 1️⃣ 변경사항 커밋 및 푸시

```bash
# Git 상태 확인
git status

# 변경사항 추가
git add docs/_config.yml docs/index.md docs/GITHUB-PAGES-SETUP.md

# 커밋
git commit -m "feat: GitHub Pages 설정 추가"

# GitHub에 푸시
git push origin main
```

---

### 2️⃣ GitHub 저장소에서 Pages 활성화

1. **GitHub 저장소 접속**
   ```
   https://github.com/Eyebottle/eyebottlelee
   ```

2. **Settings 탭 클릭**
   - 저장소 상단 메뉴에서 "Settings" 클릭

3. **Pages 메뉴 선택**
   - 왼쪽 사이드바에서 "Pages" 클릭

4. **Source 설정**
   - **Branch**: `main` 선택
   - **Folder**: `/docs` 선택
   - **Save** 버튼 클릭

5. **배포 대기 (1-2분)**
   - "Your site is ready to be published at..." 메시지 확인
   - 배포 완료 시 초록색으로 변경됨

---

### 3️⃣ 배포 확인

**배포가 완료되면 다음 URL에 접속하여 확인:**

1. **홈페이지:**
   ```
   https://eyebottle.github.io/eyebottlelee/
   ```

2. **개인정보 처리방침:**
   ```
   https://eyebottle.github.io/eyebottlelee/privacy-policy
   ```

3. **테스트:**
   - 개인정보 처리방침 페이지가 정상적으로 표시되는지 확인
   - 내용이 `docs/privacy-policy.md`와 동일한지 확인

---

## 🔧 문제 해결

### 1. "404 Not Found" 오류

**원인:** 배포가 아직 완료되지 않았거나 설정이 잘못됨

**해결 방법:**
1. GitHub Actions 탭에서 배포 상태 확인
2. Settings > Pages에서 설정 재확인
3. 5-10분 대기 후 재시도

---

### 2. CSS/스타일이 적용되지 않음

**원인:** 테마가 로드되지 않음

**해결 방법:**
1. `docs/_config.yml`에 `theme: jekyll-theme-minimal` 확인
2. GitHub Actions 빌드 로그 확인
3. 캐시 삭제 후 재접속 (Ctrl + F5)

---

### 3. Private 저장소에서 Pages가 보이지 않음

**원인:** GitHub Pages는 Public 저장소에서만 무료로 사용 가능

**해결 방법:**
- 옵션 A: 저장소를 Public으로 변경
- 옵션 B: GitHub Pro 구독 (Private 저장소에서 Pages 사용)

---

## 📝 저장소 Public 여부 확인

**확인 방법:**
1. https://github.com/Eyebottle/eyebottlelee 접속
2. 저장소 이름 옆 배지 확인:
   - "Public" 🟢 - GitHub Pages 무료 사용 가능
   - "Private" 🔒 - GitHub Pro 필요 또는 Public으로 변경

---

## ✅ MS Store 제출 시 사용할 URL

**개인정보 처리방침 URL:**
```
https://eyebottle.github.io/eyebottlelee/privacy-policy
```

이 URL을 MS Store Partner Center의 "개인정보 처리방침" 필드에 입력하세요.

---

## 🔄 업데이트 방법

개인정보 처리방침을 수정하려면:

1. `docs/privacy-policy.md` 파일 수정
2. Git 커밋 및 푸시
3. GitHub Pages 자동 재배포 (1-2분 소요)

---

## 📞 문의

문제가 발생하면 다음을 확인하세요:
- GitHub Actions 빌드 로그
- GitHub Pages 배포 상태
- 브라우저 개발자 도구 콘솔

---

**작성일:** 2025-11-07
**버전:** 1.0
