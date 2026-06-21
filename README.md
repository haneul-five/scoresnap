# ScoreSnap

악보를 사진으로 찍으면 자동으로 스캔(문서 경계 검출 + 원근 보정 + 악보 최적화 흑백 변환)해서
다중 페이지 PDF로 만들어 주는 Flutter 앱입니다. CamScanner처럼 동작하되, 변환 품질을
악보(오선·음표)에 맞게 튜닝했고 모든 처리가 **기기 안(on-device)** 에서 이뤄집니다.

## 주요 기능

- 카메라로 악보 촬영 → 자동 문서 경계 검출 및 원근 보정 (네이티브 스캐너 UI)
- **갤러리에서 기존 사진 가져오기** → 자르기/회전 보정 후 동일 파이프라인으로 변환
  (iOS·Android 모두 동작)
- 악보 최적화 흑백 이진화: 그림자/조명 불균일에 강한 **Sauvola 적응형 임계화**로
  오선과 음표를 또렷하게 보존
- 필터 선택: Original / Grayscale / B&W (악보 기본값은 B&W)
- 다중 페이지 문서: 페이지 추가, 순서 변경(드래그), 삭제
- 다중 페이지 **PDF로 내보내기 / 공유 / 인쇄** (각 페이지를 원본 비율로 손실 없이 배치)
- 스캔한 문서를 기기에 로컬 저장 (라이브러리 목록)
- 서버 불필요, 오프라인 동작, Material 3 라이트/다크 테마

## 기술 스택

- **Flutter 3.29 / Dart 3.7**
- 스캔(촬영·경계검출·원근보정): [`cunning_document_scanner`](https://pub.dev/packages/cunning_document_scanner)
  — Android는 Google ML Kit Document Scanner, iOS는 Apple VisionKit (둘 다 on-device)
- 갤러리 가져오기·자르기: [`image_picker`](https://pub.dev/packages/image_picker) +
  [`image_cropper`](https://pub.dev/packages/image_cropper)
- 이미지 처리: [`image`](https://pub.dev/packages/image) (순수 Dart) + 직접 구현한 Sauvola 이진화
- PDF: [`pdf`](https://pub.dev/packages/pdf) + [`printing`](https://pub.dev/packages/printing)
- 저장: [`path_provider`](https://pub.dev/packages/path_provider) + `dart:io`
- 상태관리: [`provider`](https://pub.dev/packages/provider) (ChangeNotifier)

## 동작 원리

1. **촬영·검출**: 네이티브 시스템 스캐너 UI를 띄워 촬영하면 경계 검출과 원근 보정이 끝난
   크롭 이미지 파일 경로들이 반환됩니다.
2. **이진화**: 각 페이지를 백그라운드 isolate(`compute`)에서 처리합니다 — 그레이스케일 →
   가우시안 블러(잡티 제거) → 대비 보정 → **Sauvola 적응형 임계화**. Sauvola는 적분 영상
   (summed-area table)을 써서 윈도 크기와 무관하게 O(N)으로 동작하므로 고해상도 사진에서도
   UI가 멈추지 않습니다. 결과는 손실 없는 PNG로 저장합니다.
3. **저장**: 원본/처리 이미지는 앱 문서 디렉터리에 파일로, 라이브러리 메타데이터는 `index.json`에
   저장합니다. 경로는 **상대 경로**로 저장한 뒤 로드 시 절대 경로로 복원합니다(iOS 앱 컨테이너
   경로가 업데이트/복원 시 바뀔 수 있기 때문).
4. **PDF**: 각 페이지를 이미지 크기에 맞춘 PDF 페이지로 만들어 한 문서로 합치고, OS 공유 시트
   (파일로 저장 포함) 또는 인쇄 다이얼로그로 내보냅니다.

## 프로젝트 구조

```
lib/
  main.dart                       앱 진입점 (Provider 루트)
  app.dart                        MaterialApp (Material3, 라이트/다크)
  models/
    scan_page.dart                ScanPage + ImageFilterType
    scan_document.dart            ScanDocument
  services/
    scanner_service.dart          네이티브 스캐너 래퍼
    image_processor.dart          Sauvola 이진화 (isolate)
    pdf_service.dart              PDF 생성/공유/인쇄
    storage_service.dart          로컬 저장(상대경로 index.json + 이미지/PDF 파일)
  providers/
    documents_store.dart          라이브러리 상태 + 영속화
    document_edit_controller.dart 편집 세션 상태
  screens/
    home_screen.dart              라이브러리 목록 + 스캔 시작
    document_edit_screen.dart     페이지 편집/필터/내보내기
    page_preview_screen.dart      전체화면 미리보기(줌)
  widgets/                        document_tile, page_thumbnail, filter_selector,
                                  empty_state, busy_overlay
```

## 빌드 및 실행

사전 준비: Flutter SDK(3.29 이상), Android Studio / Xcode.

```bash
flutter pub get

# Android (기기 또는 에뮬레이터)
flutter run

# iOS (최초 1회 pod 설치 후)
cd ios && pod install && cd ..
flutter run
```

### 플랫폼 요구사항 / 설정

- **Android**: `minSdk 23`. ML Kit Document Scanner는 최신 Google Play services와
  **RAM 1.7GB 이상**의 기기가 필요합니다. Play services가 없는 AOSP/일부 에뮬레이터에서는
  스캐너가 동작하지 않습니다(앱은 안내 메시지를 표시). 카메라 권한은 시스템 스캐너 UI가
  관리하므로 앱 매니페스트에 별도 선언이 필요 없습니다.
- **iOS**: 배포 타겟 **iOS 13.0** 이상(VisionKit). `Info.plist`에 `NSCameraUsageDescription`을
  설정했습니다. iOS는 갤러리 가져오기를 지원하지 않습니다(VisionKit은 카메라 전용).

## 알려진 한계

- 스캐너 동작은 실제 기기에서만 검증 가능합니다(네이티브 플러그인). `flutter analyze`와
  단위 테스트는 통과하지만, 촬영/공유 경로는 기기 빌드로 확인해야 합니다.
- Sauvola 파라미터(window 25, k 0.34, R 128)는 일반적인 악보 사진 기준 기본값입니다.
  필요하면 `services/image_processor.dart`에서 조정하세요.
- `image_cropper`는 **11.x로 고정**되어 있습니다. 12.x는 TOCropViewController 3.x(iOS 26
  "Liquid Glass" UI)를 요구해 Xcode 16+가 필요합니다. Xcode를 16 이상으로 올리면 12.x로
  올려도 됩니다.

## 라이선스

미정 (TBD).
