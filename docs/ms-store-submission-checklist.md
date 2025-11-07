# MS Store 제출 최종 체크리스트

MS Store에 앱을 제출하기 전 확인해야 할 모든 항목을 정리한 문서입니다.

---

## 📋 Phase 5: MS Store 제출 준비

### 1️⃣ 파일 준비

#### MSIX 패키지
- [x] MSIX 파일 생성 완료
- [x] 파일 크기: 83 MB
- [x] 버전: 1.3.0.0
- [x] 위치: `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix`
- [x] 진료실 테스트 완료 (30분 녹음, 세그먼트 분할 검증)

#### 스크린샷
- [x] screenshot-1-dashboard.png (66 KB)
- [x] screenshot-2-schedule.png (74 KB)
- [x] screenshot-3-advanced-settings.png (92 KB)
- [x] screenshot-4-auto-launch.png (43 KB)
- [x] screenshot-5-help.png (67 KB)

**위치:** `screenshots/` 폴더
**촬영 완료:** 2025-11-07

---

### 2️⃣ 문서 준비

#### 앱 리스팅
- [x] 한글 앱 설명 작성 완료
- [x] 위치: `docs/store-listing-ko.md`
- [x] 카테고리: 생산성 / 의료
- [x] 태그(키워드) 준비됨

#### 개인정보 처리방침
- [x] 개인정보 처리방침 작성 완료
- [x] 위치: `docs/privacy-policy.md`
- [ ] 웹사이트에 게시 (선택적)
- [ ] URL 준비 (Partner Center 입력용)

**옵션 1:** 웹사이트 게시
```
https://www.eyebottle.kr/privacy-policy
```

**옵션 2:** GitHub Pages
```
https://github.com/USERNAME/eyebottlelee/blob/main/docs/privacy-policy.md
```

**옵션 3:** Partner Center에 직접 입력

#### 릴리즈 노트
- [x] RELEASE_NOTES_v1.3.0.md 작성 완료
- [x] CHANGELOG.md 업데이트 완료
- [x] 주요 기능 및 개선사항 정리됨

---

### 3️⃣ MS 개발자 계정

#### 계정 등록
- [ ] Microsoft 계정 준비
- [ ] MS 개발자 센터 등록
  - URL: https://developer.microsoft.com/microsoft-store/register
  - 비용: $19 (개인)
- [ ] 결제 정보 입력
- [ ] 계정 활성화 확인

#### Partner Center 접근
- [ ] https://partner.microsoft.com/dashboard 로그인
- [ ] 대시보드 접근 확인

---

### 4️⃣ 앱 등록 (Partner Center)

#### Step 1: 앱 생성
- [ ] "새 앱" 클릭
- [ ] 앱 이름 예약: "아이보틀 진료 녹음"
- [ ] 이름 사용 가능 확인

#### Step 2: 속성
- [ ] 카테고리: 생산성
- [ ] 부 카테고리: 의료
- [ ] 연령 등급: 모든 연령
- [ ] 시스템 요구사항:
  - Windows 10 버전 1809 이상
  - x64 프로세서
  - 4GB RAM

#### Step 3: 가격 및 사용 가능 여부
- [ ] 가격: 무료
- [ ] 시장: 대한민국 (선택 또는 전체)
- [ ] 출시 날짜: 심사 통과 즉시

---

### 5️⃣ 스토어 리스팅 작성

#### 리스팅 정보
- [ ] **앱 이름:** 아이보틀 진료 녹음
- [ ] **간단한 설명** (255자):
  ```
  진료실을 위한 스마트 녹음 솔루션. 진료 중 환자와의 대화를 시간표 기반으로
  자동 녹음하고, WAV 파일을 AAC로 자동 변환해 용량을 83% 절감합니다.
  ```

- [ ] **상세 설명:**
  - `docs/store-listing-ko.md` 참고
  - 주요 기능, 특징, 사용 대상 포함
  - 3000자 이내

- [ ] **키워드/태그** (7개):
  - 진료 녹음
  - 의료 녹음
  - 음성 녹음
  - 자동 녹음
  - 진료실
  - 병원
  - 의사

#### 스크린샷
- [ ] 5개 스크린샷 업로드
- [ ] 순서 조정 (드래그)
- [ ] 각 스크린샷 설명 입력:
  - screenshot-1: "실시간 녹음 상태와 볼륨 미터"
  - screenshot-2: "주간 진료 시간표 설정"
  - screenshot-3: "고급 설정 및 WAV 자동 변환"
  - screenshot-4: "자동 실행 매니저"
  - screenshot-5: "종합 도움말 센터"

#### 추가 정보
- [ ] **웹사이트:** https://www.eyebottle.kr
- [ ] **지원 연락처:** eyebottle@example.com
- [ ] **개인정보 처리방침 URL** (필수)
- [ ] **저작권 및 상표:** © 2025 Eyebottle

---

### 6️⃣ 패키지 업로드

#### MSIX 업로드
- [ ] Partner Center → 패키지 섹션
- [ ] "패키지 업로드" 클릭
- [ ] `medical_recorder.msix` 선택 (83 MB)
- [ ] 업로드 완료 대기 (5-10분)
- [ ] Microsoft 자동 검증 대기

#### 검증 확인
- [ ] 패키지 무결성 확인
- [ ] 디지털 서명 확인 (Microsoft 자동 서명)
- [ ] 오류 없음 확인

---

### 7️⃣ 제출 전 최종 확인

#### 필수 항목 확인
- [ ] 모든 필수 필드 입력 완료
- [ ] 스크린샷 5개 업로드
- [ ] MSIX 패키지 업로드
- [ ] 개인정보 처리방침 URL 입력
- [ ] 오류 또는 경고 없음

#### 콘텐츠 확인
- [ ] 앱 설명에 오타 없음
- [ ] 스크린샷에 개인정보 없음
- [ ] 개인정보 처리방침 내용 정확
- [ ] 연락처 정보 정확

#### 정책 준수
- [ ] MS Store 정책 준수 (`docs/ms-store-publish.md` 참고)
- [ ] 개인정보 보호 정책 준수
- [ ] 콘텐츠 정책 준수
- [ ] 연령 등급 적절

---

### 8️⃣ 제출

#### 제출 프로세스
- [ ] "심사 제출" 버튼 클릭
- [ ] 제출 확인 메시지
- [ ] 제출 날짜 및 시간 기록

#### 제출 후
- [ ] 제출 ID 기록
- [ ] 심사 상태 확인 URL 저장
- [ ] 알림 이메일 확인

---

## ⏰ 심사 프로세스

### 예상 소요 시간
```
제출 → 자동 검증: 1-2시간
자동 검증 → 수동 심사: 1-2일
수동 심사 → 승인/거부: 1일
──────────────────────────
총 소요 시간: 2-3일
```

### 심사 단계
1. **자동 검증** (1-2시간)
   - 패키지 무결성 확인
   - 디지털 서명 확인
   - 기본 요구사항 확인

2. **수동 심사** (1-2일)
   - 앱 기능 테스트
   - 콘텐츠 검토
   - 정책 준수 확인

3. **최종 승인** (1일)
   - 승인 시: 즉시 게시 또는 예약
   - 거부 시: 피드백 및 수정 요청

---

## ❌ 거부 시 대응

### 일반적인 거부 사유
1. **패키지 문제**
   - MSIX 파일 손상
   - 디지털 서명 오류
   - → 재빌드 및 재제출

2. **콘텐츠 문제**
   - 부적절한 설명 또는 스크린샷
   - → 수정 후 재제출

3. **정책 위반**
   - 개인정보 처리방침 누락
   - → 추가 후 재제출

4. **기능 문제**
   - 앱 충돌 또는 오류
   - → 수정, 재빌드, 재제출

### 재제출 프로세스
1. 거부 사유 확인
2. 문제 수정
3. 재빌드 (필요 시)
4. 재제출

---

## ✅ 승인 후

### 게시 확인
- [ ] MS Store에서 앱 검색
- [ ] 앱 페이지 정상 표시
- [ ] 다운로드 가능 확인
- [ ] 설치 테스트

### 모니터링
- [ ] 다운로드 수 확인
- [ ] 사용자 리뷰 모니터링
- [ ] 오류 보고 확인
- [ ] 업데이트 계획 수립

---

## 📝 참고 문서

| 문서 | 내용 |
|------|------|
| **store-listing-ko.md** | 앱 설명 (한글) |
| **privacy-policy.md** | 개인정보 처리방침 |
| **screenshot-guide.md** | 스크린샷 촬영 가이드 |
| **MS-STORE-GUIDE.md** | MS Store 출시 마스터 가이드 |
| **ms-store-publish.md** | MS Store 정책 준수 |
| **RELEASE_NOTES_v1.3.0.md** | 릴리즈 노트 |

---

## 📞 문의 및 지원

**MS Store 지원:**
- https://developer.microsoft.com/microsoft-store/support

**Partner Center 도움말:**
- https://partner.microsoft.com/dashboard

**프로젝트 관련:**
- eyebottle@example.com
- https://www.eyebottle.kr

---

**작성일:** 2025-11-07
**버전:** 1.3.0
**상태:** Phase 5 준비 완료
