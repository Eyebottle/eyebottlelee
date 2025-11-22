# 🏪 MS Store 출시 가이드

> **🎉 MS Store 출시 완료! (v1.3.0: 2025-11-17 / v1.3.1: 2025-11-18)**
>
> 현재 버전: ✅ v1.3.1 (긴급 버그 수정) - In Microsoft Store

---

## 🎯 출시 정보

```
📦 앱 이름: 아이보틀 진료 녹음
🆔 Store ID: 9NDZB0QSL928
📅 제출 날짜: 2025-11-15
✅ 승인 날짜: 2025-11-17
📧 알림 이메일: lee@eyebottle.kr
🎉 현재 상태: In Microsoft Store (정식 출시)
```

### Package Identity
```
Identity Name: DCD952CB.367669DCDC1D3
Publisher: CN=0CEBC30B-3CD4-4E21-A48A-421AE62E38D3
Publisher Display: 아이보틀
Package Family Name: DCD952CB.367669DCDC1D3_tmhr7zc3de56j
```

### 🔗 Store Links (활성화 완료!)
```
Web: https://www.microsoft.com/store/apps/9NDZB0QSL928
또는: https://apps.microsoft.com/detail/9NDZB0QSL928
Deep Link: ms-windows-store://pdp/?ProductId=9NDZB0QSL928
```

**🎉 지금 다운로드 가능합니다!**

---

## ✅ 완료된 단계

### Phase 1-4: 개발 및 빌드 (2025-11-06 ~ 11-07)
- [x] 코드 정리 및 최적화
- [x] 자동화 테스트 (Phase 2)
- [x] 문서화
- [x] MSIX 패키징 (83 MB)
- [x] 진료실 실사용 테스트

### Phase 5: MS Store 제출 (2025-11-15)
- [x] MS 개발자 계정 등록 ($19)
- [x] Package Identity 설정 (3회 수정)
- [x] MS Store용 MSIX 빌드 (`store: true`)
- [x] 영어 Store Listing 작성
- [x] 한국어 Store Listing 작성
- [x] 스크린샷 업로드 (5개 × 2개 언어 = 10개)
- [x] runFullTrust 권한 설명 작성
- [x] 최종 제출 완료

### Phase 6: MS Store 승인 및 출시 (2025-11-17)
- [x] Pre-processing 완료 (자동 검증)
- [x] Certification 통과 (runFullTrust 승인)
- [x] Publishing 완료
- [x] ✅ **Microsoft Store 정식 출시!** (v1.3.0)

### Phase 7: 긴급 버그 수정 업데이트 (2025-11-18)
- [x] 사용자 크래쉬 문제 발견 (앱 시작 시 즉시 종료)
- [x] 원인 분석: Visual C++ Runtime dependencies 누락
- [x] 코드 수정
  - `pubspec.yaml`: dependencies 추가, windows_capabilities 설정
  - `main.dart`: 전역 에러 핸들러 추가
  - `main_screen.dart`: 초기화 실패 복원력 강화
- [x] MSIX v1.3.1 빌드 (83 MB)
- [x] Submission 2 제출 (2025-11-18)
- [x] Pre-processing 완료 (2시간 내)
- [x] Certification 통과 (초고속 심사!)
- [x] ✅ **v1.3.1 긴급 업데이트 출시!** (같은 날 승인!)

---

## 🎉 출시 타임라인

### v1.3.0 최초 출시
```
📅 2025-11-15: 제출 (Submission 1)
   ↓ (1-2시간)
✅ 2025-11-15: Pre-processing 완료
   ↓ (1-2일)
✅ 2025-11-17: Certification 통과
   ↓ (1시간)
🎉 2025-11-17: Microsoft Store 출시!

총 소요 시간: 2일 (예상: 2-5일)
```

### v1.3.1 긴급 버그 수정 (🚀 초고속!)
```
🚨 2025-11-18: 크래쉬 문제 발견
   ↓ (2시간)
🔧 2025-11-18: 원인 분석 및 수정
   ↓ (1시간)
📦 2025-11-18: MSIX 빌드
   ↓ (즉시)
📅 2025-11-18: 제출 (Submission 2)
   ↓ (2시간)
✅ 2025-11-18: Pre-processing 완료
   ↓ (몇 시간)
✅ 2025-11-18: Certification 통과
   ↓ (즉시)
🎉 2025-11-18: Microsoft Store 출시!

총 소요 시간: 1일 이내! (긴급 수정으로 초고속 승인)
```

---

## 🌐 앱 확인 및 다운로드

### Store 페이지
- Web: https://www.microsoft.com/store/apps/9NDZB0QSL928
- 또는: https://apps.microsoft.com/detail/9NDZB0QSL928

### Partner Center
- Dashboard: https://partner.microsoft.com/dashboard
- Analytics: 다운로드 수, 평점, 리뷰 확인 가능

---

## 📊 제출 통계

### 현재 버전 (v1.3.1)
```
MSIX 파일: medical_recorder.msix
크기: 83 MB
버전: 1.3.1.0
아키텍처: x64
빌드 옵션: store: true (MS Store용)
주요 수정: Visual C++ Runtime dependencies 포함
```

### 이전 버전 (v1.3.0)
```
MSIX 파일: medical_recorder.msix
크기: 83 MB
버전: 1.3.0.0
아키텍처: x64
빌드 옵션: store: true (MS Store용)
```

### Publisher 문제 해결 과정
```
시도 1: PublisherDisplayName 불일치 → 수정
시도 2: Identity Name 불일치 → 수정
시도 3: Publisher 서명 불일치 → store: true 추가 → ✅ 성공
```

---

## 📝 향후 업데이트 방법

### 새 버전 제출
1. 버전 번호 증가 (`pubspec.yaml`)
   ```yaml
   version: 1.3.1+12  # 1.3.0+11에서 증가
   msix_version: 1.3.1.0  # 1.3.0.0에서 증가
   ```

2. MSIX 재빌드
   ```bash
   flutter build windows --release
   flutter pub run msix:create
   ```

3. Partner Center에서 제출
   - "Create submission" 클릭
   - 새 MSIX 업로드
   - 변경사항 설명
   - 제출

---

## 🔗 관련 문서

### 활성 문서
- [privacy-policy.md](./privacy-policy.md) - 개인정보 처리방침
- [store-listing-ko.md](./store-listing-ko.md) - 한국어 스토어 리스팅
- [user-guide.md](./user-guide.md) - 사용자 가이드
- [ms-store-info.md](./ms-store-info.md) - Store 상세 정보

### 개발 문서
- [developing.md](./developing.md) - 개발 가이드
- [medical-recording-prd.md](./medical-recording-prd.md) - 제품 요구사항
- [auto-lancher-prd.md](./auto-lancher-prd.md) - 자동 실행 PRD

### 아카이브
- [archive/](./archive/) - 완료된 작업 문서들
  - MS Store 제출 과정 문서
  - 테스트 결과 및 가이드
  - 기술 구현 문서

---

## ❓ 문제 해결

### 심사가 3일 이상 지연되면?
```
1. Partner Center에서 "Contact support" 클릭
2. Submission ID 제공: Submission 1
3. 제출 날짜 명시: 2025-11-15
4. 24시간 내 응답 대기
```

### runFullTrust로 거부되면?
```
1. 거부 사유 확인
2. Submission Options → runFullTrust 설명 보완
3. "Update submission" 클릭
4. 재제출
```

### 패키지 오류로 거부되면?
```
1. 오류 메시지 확인
2. pubspec.yaml 수정
3. MSIX 재빌드 (store: true 유지)
4. 새 패키지 업로드
5. 재제출
```

---

## 📞 지원

### MS Store Support
- URL: https://developer.microsoft.com/microsoft-store/support
- Partner Center: https://partner.microsoft.com/dashboard

### 프로젝트 관련
- 웹사이트: https://www.eyebottle.kr
- 이메일: lee@eyebottle.kr

---

**문서 최종 업데이트:** 2025-11-18
**현재 버전:** v1.3.1 (긴급 버그 수정)
**상태:** 🎉 Microsoft Store 정식 출시 완료!
**Store 링크:** https://www.microsoft.com/store/apps/9NDZB0QSL928

### 📝 버전 히스토리
- **v1.3.1** (2025-11-18): 긴급 버그 수정 - Visual C++ Runtime dependencies 포함
- **v1.3.0** (2025-11-17): 최초 MS Store 출시
