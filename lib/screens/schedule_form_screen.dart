import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import '../utils/gemini_helper.dart';
import '../utils/text_extraction_limit_helper.dart';
import '../utils/image_text_extractor.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/address_service.dart';
import '../services/analytics_service.dart';
import '../widgets/gradient_app_bar.dart';
import 'company_edit_screen.dart';

class ScheduleFormScreen extends StatefulWidget {
  final Schedule? schedule;

  const ScheduleFormScreen({super.key, this.schedule});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _workCountController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneNumberFocus = FocusNode();

  DateTime? _visitDate; // 방문확정일자 (선택)
  String? _visitTime; // 방문시간 (확정 시에만 입력)
  Map<String, int> _workItemsWithCount = {}; // 작업 항목과 건수
  Map<String, int> _workPrices = {}; // 작업별 금액

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _isLoadingCompanies = true;

  // 입력 필드 스타일 상수
  static const _primaryColor = Color(0xFF579bf2);
  static final _enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _primaryColor, width: 1.5),
  );
  static final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _primaryColor, width: 2),
  );
  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Colors.red, width: 1.5),
  );

  // 전화번호 포맷팅 (000-0000-0000)
  String _formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 11) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    } else if (digitsOnly.length == 10) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    return digitsOnly;
  }

  // 전화번호에서 숫자만 추출
  String _getDigitsOnly(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // 방문시간 옵션 (5:00 ~ 23:00, 30분 단위)
  List<String> get _timeOptions {
    List<String> times = [];
    for (int hour = 5; hour <= 23; hour++) {
      times.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 23) {
        times.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
    return times;
  }

  @override
  void initState() {
    super.initState();
    _initializeForm();

    // 전화번호 포커스 리스너
    _phoneNumberFocus.addListener(() {
      if (!_phoneNumberFocus.hasFocus) {
        // 포커스 아웃 시 포맷팅 적용
        final digitsOnly = _getDigitsOnly(_phoneNumberController.text);
        if (digitsOnly.isNotEmpty) {
          _phoneNumberController.text = _formatPhoneNumber(digitsOnly);
        }
      } else {
        // 포커스 인 시 숫자만 표시
        final digitsOnly = _getDigitsOnly(_phoneNumberController.text);
        _phoneNumberController.text = digitsOnly;
        _phoneNumberController.selection = TextSelection.fromPosition(
          TextPosition(offset: digitsOnly.length),
        );
      }
    });
  }

  Future<void> _initializeForm() async {
    await _loadCompanies();
    if (widget.schedule != null) {
      setState(() {
        _loadScheduleData();
      });
    }
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final companies = await DatabaseHelper.instance.readAllCompanies(userId);
    setState(() {
      _companies = companies;
      _isLoadingCompanies = false;

      // 기존에 선택된 업체가 있으면 새로 로드된 리스트에서 같은 ID의 업체로 업데이트
      if (_selectedCompany != null && _companies.isNotEmpty) {
        try {
          _selectedCompany = _companies.firstWhere(
            (c) => c.id == _selectedCompany!.id,
          );
        } catch (e) {
          // 선택된 업체가 삭제된 경우 첫 번째 업체로 설정
          _selectedCompany = _companies.first;
        }
      }
      // 기본값으로 첫 번째 업체 선택 (보통 "개인")
      else if (_companies.isNotEmpty && _selectedCompany == null) {
        _selectedCompany = _companies.first;
      }
    });
  }

  void _loadScheduleData() {
    final schedule = widget.schedule!;
    _customerNameController.text = schedule.customerName;
    // 전화번호는 포맷팅해서 표시
    _phoneNumberController.text = _formatPhoneNumber(schedule.phoneNumber);
    _addressController.text = schedule.address ?? '';
    _notesController.text = schedule.notes ?? '';
    _visitDate = schedule.visitDate;
    _visitTime = schedule.visitTime;

    // 업체명으로 업체 찾기
    if (schedule.companyName != null && _companies.isNotEmpty) {
      try {
        _selectedCompany = _companies.firstWhere(
          (c) => c.name == schedule.companyName,
        );
      } catch (e) {
        // 업체를 찾지 못한 경우 첫 번째 업체 선택
        _selectedCompany = _companies.isNotEmpty ? _companies.first : null;
      }
    } else if (_companies.isNotEmpty) {
      _selectedCompany = _companies.first;
    }

    // 기존 데이터에서 작업 항목 파싱 (중복된 항목 카운팅)
    _workItemsWithCount.clear();
    for (var item in schedule.workItems) {
      // 기존 데이터에 " X건" 형식이 포함된 경우 제거
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      _workItemsWithCount[cleanedItem] = (_workItemsWithCount[cleanedItem] ?? 0) + 1;
    }
    _workCountController.text = schedule.workCount.toString();

    // 작업별 금액 로드
    _workPrices = Map.from(schedule.workPrices);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _workCountController.dispose();
    _notesController.dispose();
    _phoneNumberFocus.dispose();
    super.dispose();
  }

  Future<void> _selectVisitDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
      helpText: '방문 일자 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  void _showTimePickerMenu(BuildContext context) {
    final scrollController = ScrollController();
    final allTimeOptions = ['미정', ..._timeOptions];

    // 12:00의 인덱스 계산
    final noonIndex = allTimeOptions.indexOf('12:00');
    final itemHeight = 48.0;

    showDialog(
      context: context,
      builder: (context) {
        // 다이얼로그가 열린 후 12:00으로 스크롤
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            final screenHeight = MediaQuery.of(context).size.height;
            final dialogHeight = screenHeight * 0.6;
            final targetOffset = (noonIndex * itemHeight) - (dialogHeight / 2) + (itemHeight / 2);

            scrollController.jumpTo(
              targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
            );
          }
        });

        return AlertDialog(
          title: const Text('방문시간 선택'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: ListView.builder(
              controller: scrollController,
              itemCount: allTimeOptions.length,
              itemBuilder: (context, index) {
                final time = allTimeOptions[index];
                final isSelected = (time == '미정' && _visitTime == null) || time == _visitTime;

                return ListTile(
                  dense: true,
                  title: Text(
                    time,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _visitTime = time == '미정' ? null : time;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  void _showWorkItemsDialog() {
    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 업체를 선택해주세요')),
      );
      return;
    }

    if (_selectedCompany!.workItems.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('작업 항목 없음'),
          content: const Text('선택한 업체에 작업 항목이 없습니다.\n작업 항목을 추가하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // 업체 수정 화면으로 이동
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyEditScreen(company: _selectedCompany),
                  ),
                );
                // 업체 수정 후 돌아오면 업체 목록 새로고침
                if (result == true && mounted) {
                  await _loadCompanies();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('작업 항목 추가하러 가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF579bf2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _WorkItemsDialog(
        company: _selectedCompany!,
        initialWorkItems: _workItemsWithCount,
        initialWorkPrices: _workPrices,
        onConfirm: (workItems, workPrices) {
          setState(() {
            _workItemsWithCount = workItems;
            _workPrices = workPrices;
            // 총 건수 자동 계산
            int total = _workItemsWithCount.values.fold(0, (sum, count) => sum + count);
            _workCountController.text = total.toString();
          });
        },
      ),
    );
  }

  Future<void> _showPasteDialog() async {
    final textController = TextEditingController();
    final remaining = await TextExtractionLimitHelper.getRemainingCount();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(
              child: Text('텍스트에서 스케줄 추출'),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: remaining > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: remaining > 0 ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                '$remaining/${TextExtractionLimitHelper.monthlyLimit}',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining > 0 ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // 고정 높이 설정
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '스케줄 정보가 포함된 텍스트를 붙여넣으세요.\n(이름, 전화번호, 주소, 날짜, 시간)',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: textController,
                  maxLines: null, // null로 설정하여 자동 확장
                  minLines: 12, // 최소 8줄
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: '예시:\n홍길동\n010-1234-5678\n서울시 강남구 테헤란로 123\n2025년 10월 15일 14시',
                    enabledBorder: _enabledBorder,
                    focusedBorder: _focusedBorder,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('텍스트를 입력해주세요')),
                );
                return;
              }

              Navigator.pop(context);

              // 사용 가능 횟수 확인
              final canUse = await TextExtractionLimitHelper.incrementUsage();

              if (!canUse) {
                final remaining = await TextExtractionLimitHelper.getRemainingCount();
                if (!mounted) return;

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('사용 횟수 초과'),
                    content: Text(
                      '텍스트 추출 기능은 한 달에 ${TextExtractionLimitHelper.monthlyLimit}회까지 무료로 사용할 수 있습니다.\n\n'
                      '이번 달 남은 횟수: $remaining회\n\n'
                      '무제한으로 사용하려면 멤버십에 가입해주세요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
                return;
              }

              // 로딩 다이얼로그 표시
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => PopScope(
                  canPop: false,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'AI로 정보 추출 중...',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              await _extractScheduleInfoDirect(text, true);
            },
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('추출하기'),
          ),
        ],
      ),
    );
  }

  // 이미지에서 추출 다이얼로그
  Future<void> _showImageExtractionDialog() async {
    final remaining = await TextExtractionLimitHelper.getRemainingCount();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(
              child: Text('이미지에서 스케줄 추출'),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: remaining > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: remaining > 0 ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                '$remaining/${TextExtractionLimitHelper.monthlyLimit}',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining > 0 ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '문서 사진이나 캡처 이미지에서\n스케줄 정보를 추출합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 갤러리에서 선택
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _requestPermissionAndPick(fromCamera: false);
                    },
                    icon: const Icon(Icons.photo_library, size: 32),
                    label: const Text('갤러리', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: _primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 카메라로 촬영
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _requestPermissionAndPick(fromCamera: true);
                    },
                    icon: const Icon(Icons.camera_alt, size: 32),
                    label: const Text('카메라', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: _primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 권한 요청 및 이미지 선택
  Future<void> _requestPermissionAndPick({required bool fromCamera}) async {
    debugPrint('🚀 [ScheduleForm] Starting image selection: fromCamera=$fromCamera');

    if (!mounted) {
      debugPrint('⚠️ [ScheduleForm] Widget not mounted');
      return;
    }

    // image_picker 플러그인이 내부적으로 권한을 처리하므로 바로 진행
    await _pickAndExtractImage(fromCamera: fromCamera);
  }

  // 이미지 선택 및 텍스트 추출
  Future<void> _pickAndExtractImage({required bool fromCamera}) async {
    debugPrint('📸 [ScheduleForm] _pickAndExtractImage START');

    if (!mounted) {
      debugPrint('⚠️ [ScheduleForm] Not mounted at start');
      return;
    }

    XFile? selectedImage;

    // Step 1: 이미지 선택
    try {
      debugPrint('📸 [ScheduleForm] Calling ImageTextExtractor...');

      selectedImage = fromCamera
          ? await ImageTextExtractor.pickImageFromCamera()
          : await ImageTextExtractor.pickImageFromGallery();

      debugPrint('📸 [ScheduleForm] ImageTextExtractor returned: ${selectedImage?.path ?? "null"}');

    } on Exception catch (e, stack) {
      debugPrint('❌ [ScheduleForm] Exception in image picker: $e');
      debugPrint('Stack: $stack');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;

    } catch (e, stack) {
      debugPrint('❌ [ScheduleForm] Error in image picker: $e');
      debugPrint('Stack: $stack');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 사용자가 취소했거나 이미지를 선택하지 않음
    if (selectedImage == null) {
      debugPrint('ℹ️ [ScheduleForm] No image selected');
      return;
    }

    debugPrint('✅ [ScheduleForm] Image selected: ${selectedImage.path}');

    if (!mounted) {
      debugPrint('⚠️ [ScheduleForm] Not mounted after image selection');
      return;
    }

    // Step 2: OCR 처리
    debugPrint('🔍 [ScheduleForm] Starting OCR process');
    await _processImageOCR(selectedImage.path);
  }

  // OCR 처리 (이미지 선택과 분리)
  Future<void> _processImageOCR(String imagePath) async {
    debugPrint('🔍 [ScheduleForm] _processImageOCR START for: $imagePath');

    if (!mounted) {
      debugPrint('⚠️ [ScheduleForm] Not mounted at OCR start');
      return;
    }

    // 사용 가능 횟수 확인 (OCR + Gemini 통합 제한)
    final canUse = await TextExtractionLimitHelper.incrementUsage();

    if (!canUse) {
      final remaining = await TextExtractionLimitHelper.getRemainingCount();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('사용 횟수 초과'),
          content: Text(
            '이미지 추출 기능은 한 달에 ${TextExtractionLimitHelper.monthlyLimit}회까지 무료로 사용할 수 있습니다.\n\n'
            '이번 달 남은 횟수: $remaining회\n\n'
            '무제한으로 사용하려면 멤버십에 가입해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    bool isDialogOpen = false;

    try {
      // 로딩 다이얼로그 표시
      debugPrint('⏳ [ScheduleForm] Showing loading dialog');
      isDialogOpen = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '이미지에서 텍스트 추출 중...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '처음 사용시 한글 모델을 다운로드합니다\n잠시만 기다려주세요',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      // 다이얼로그가 완전히 표시될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        debugPrint('⚠️ [ScheduleForm] Not mounted after dialog delay');
        return;
      }

      // OCR 실행
      debugPrint('🤖 [ScheduleForm] Executing OCR');
      final String extractedText = await ImageTextExtractor.extractTextFromImage(imagePath);

      debugPrint('✅ [ScheduleForm] OCR SUCCESS: ${extractedText.length} chars');
      debugPrint('📄 [ScheduleForm] Extracted text:\n$extractedText');

      if (!mounted) {
        debugPrint('⚠️ [ScheduleForm] Not mounted after OCR');
        return;
      }

      // 추출된 텍스트가 비어있는 경우
      if (extractedText.trim().isEmpty) {
        debugPrint('⚠️ [ScheduleForm] No text found in image');

        // 로딩 다이얼로그 닫기
        if (isDialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          isDialogOpen = false;
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('텍스트 추출 실패'),
              content: const Text('이미지에서 텍스트를 찾을 수 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 로딩 메시지 변경 (Gemini API 처리 중)
      if (mounted && isDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;

        // 새 로딩 다이얼로그 표시
        isDialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'AI로 정보 추출 중...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (!mounted) return;

      // Gemini API로 정보 추출 (제한 체크 없이 직접 호출)
      debugPrint('🤖 [ScheduleForm] Calling Gemini API');
      await _extractScheduleInfoDirect(extractedText, isDialogOpen);

    } catch (e, stack) {
      debugPrint('❌ [ScheduleForm] ERROR in _processImageOCR: $e');
      debugPrint('Stack: $stack');

      if (!mounted) return;

      // 열려있는 다이얼로그 닫기
      if (isDialogOpen) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          isDialogOpen = false;
          debugPrint('✅ [ScheduleForm] Dialog closed (error case)');
        } catch (closeErr) {
          debugPrint('⚠️ [ScheduleForm] Failed to close dialog: $closeErr');
        }
      }

      // 사용자에게 에러 표시
      String errorMsg = e.toString().replaceAll('Exception: ', '');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류 발생'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이미지 처리 중 오류가 발생했습니다:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: SelectableText(
                      errorMsg,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Gemini API로 정보 추출 (제한 체크 없이)
  Future<void> _extractScheduleInfoDirect(String text, bool isDialogOpen) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final result = await GeminiHelper.extractScheduleInfo(text);

      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      if (isDialogOpen) {
        try {
          navigator.pop();
        } catch (e) {
          debugPrint('⚠️ Dialog close error: $e');
        }
      }

      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('정보 추출에 실패했습니다. Gemini API 키를 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );

        // Analytics 로그
        await AnalyticsService().logFeatureUsed(
          featureName: 'ocr_text_extraction',
          parameters: {
            'success': false,
            'error': 'api_key_error',
          },
        );
        return;
      }

      // 추출된 정보를 폼에 입력
      setState(() {
        if (result['name'] != null && result['name'].toString().isNotEmpty) {
          _customerNameController.text = result['name'].toString();
        }

        if (result['phone'] != null && result['phone'].toString().isNotEmpty) {
          final phone = result['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
          _phoneNumberController.text = _formatPhoneNumber(phone);
        }

        if (result['address'] != null && result['address'].toString().isNotEmpty) {
          _addressController.text = result['address'].toString();
        }

        // 날짜는 방문확정일자에 입력 (과거 날짜인 경우 오늘 날짜로 설정)
        if (result['date'] != null && result['date'].toString().isNotEmpty) {
          try {
            final extractedDate = DateTime.parse(result['date'].toString());
            final today = DateTime.now();
            final todayDate = DateTime(today.year, today.month, today.day);
            final extractedDateOnly = DateTime(extractedDate.year, extractedDate.month, extractedDate.day);

            // 과거 날짜인 경우 오늘 날짜로, 아니면 추출된 날짜 사용
            if (extractedDateOnly.isBefore(todayDate)) {
              _visitDate = today;
            } else {
              _visitDate = extractedDate;
            }
          } catch (e) {
            // 날짜 파싱 실패 시 무시
          }
        }

        // 방문시간은 null로 설정 (예정 상태)
        _visitTime = null;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('정보가 추출되었습니다. 내용을 확인하고 수정해주세요.'),
          backgroundColor: Colors.green,
        ),
      );

      // Analytics 로그
      await AnalyticsService().logFeatureUsed(
        featureName: 'ocr_text_extraction',
        parameters: {
          'success': true,
        },
      );
    } catch (e) {
      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      if (isDialogOpen) {
        try {
          navigator.pop();
        } catch (closeErr) {
          debugPrint('⚠️ Dialog close error: $closeErr');
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // Analytics 로그
      await AnalyticsService().logFeatureUsed(
        featureName: 'ocr_text_extraction',
        parameters: {
          'success': false,
          'error': 'exception',
        },
      );
    }
  }


  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업체를 선택해주세요')),
      );
      return;
    }

    if (_workItemsWithCount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업 내용을 선택해주세요')),
      );
      return;
    }

    // 로딩 다이얼로그 표시
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // 작업 항목을 건수만큼 중복하여 리스트로 변환
      final workItemsList = <String>[];
      for (var entry in _workItemsWithCount.entries) {
        for (int i = 0; i < entry.value; i++) {
          workItemsList.add(entry.key);
        }
      }

      // 전화번호는 숫자만 저장
      final phoneNumberDigitsOnly = _getDigitsOnly(_phoneNumberController.text);
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 주소를 지번 주소로 변환 (주소가 변경된 경우에만)
      String? jibunAddress = widget.schedule?.jibunAddress; // 기존 값 유지

      // 신규 등록이거나, 주소가 변경된 경우에만 API 호출
      final addressChanged = widget.schedule == null || widget.schedule!.address != _addressController.text;

      if (addressChanged) {
        try {
          jibunAddress = await AddressService.convertToJibunAddress(_addressController.text);
        } catch (e) {
          // 변환 실패 시 무시
          debugPrint('지번 주소 변환 실패: $e');
          jibunAddress = null;
        }
      }

      final schedule = Schedule(
        id: widget.schedule?.id,
        userId: userId,
        customerName: _customerNameController.text,
        visitDate: _visitDate,
        visitTime: _visitTime,
        phoneNumber: phoneNumberDigitsOnly,
        address: _addressController.text.isEmpty ? null : _addressController.text,
        jibunAddress: jibunAddress,
        companyName: _selectedCompany!.name,
        workItems: workItemsList,
        workPrices: _workPrices,
        workCount: int.parse(_workCountController.text),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        status: '예정', // status 필드는 유지하지만 computedStatus로 판단함
      );

      int savedId;
      if (widget.schedule == null) {
        savedId = await DatabaseHelper.instance.createSchedule(schedule);

        // Analytics: 스케줄 생성 이벤트
        await AnalyticsService().logScheduleCreated(
          companyName: _selectedCompany!.name,
          workItemCount: workItemsList.length,
        );
      } else {
        savedId = await DatabaseHelper.instance.updateSchedule(schedule);

        // Analytics: 스케줄 수정 이벤트
        await AnalyticsService().logScheduleUpdated(
          status: schedule.computedStatus,
        );
      }

      // 저장된 ID로 스케줄 객체 업데이트
      final savedSchedule = schedule.copyWith(id: savedId);

      // 스케줄이 변경되었으므로 알림 다시 설정
      await NotificationService.instance.setupDailyNotifications();

      // 위젯 업데이트
      await WidgetService.updateWidget();

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
      }

      if (mounted) {
        Navigator.pop(context, savedSchedule);
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context);
      }

      // 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: widget.schedule == null ? '스케줄 추가' : '스케줄 수정',
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            onPressed: _showPasteDialog,
            tooltip: '텍스트에서 추출',
          ),
          
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _showImageExtractionDialog,
            tooltip: '이미지에서 추출',
          ),
          /*
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
          ),
          */
        ],
      ),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        children: [
                          // 업체 선택 드롭다운
                          DropdownButtonFormField<Company>(
                            key: ValueKey(_selectedCompany?.id),
                            initialValue: _selectedCompany,
                            decoration: InputDecoration(
                              labelText: '업체 *',
                              labelStyle: const TextStyle(fontSize: 13),
                              enabledBorder: _enabledBorder,
                              focusedBorder: _focusedBorder,
                              errorBorder: _errorBorder,
                              focusedErrorBorder: _errorBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            menuMaxHeight: 300, // 드롭다운 최대 높이 제한
                            items: _companies.map((company) {
                              return DropdownMenuItem(
                                value: company,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Color(company.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(company.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (Company? newValue) {
                              setState(() {
                                _selectedCompany = newValue;
                                // 업체 변경 시 작업 항목 초기화
                                _workItemsWithCount.clear();
                                _workPrices.clear();
                                _workCountController.text = '0';
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return '업체를 선택해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: '고객명 *',
                              labelStyle: const TextStyle(fontSize: 13),
                              enabledBorder: _enabledBorder,
                              focusedBorder: _focusedBorder,
                              errorBorder: _errorBorder,
                              focusedErrorBorder: _errorBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zㄱ-ㅎ가-힣\s]')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '고객명을 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _selectVisitDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: '방문일자',
                                      labelStyle: const TextStyle(fontSize: 13),
                                      enabledBorder: _enabledBorder,
                                      border: _enabledBorder,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_visitDate != null)
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _visitDate = null;
                                                  _visitTime = null;
                                                });
                                              },
                                              child: const Icon(Icons.clear, size: 18),
                                            ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.calendar_today, size: 18),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      _visitDate != null
                                          ? DateFormat('MM-dd (E)', 'ko_KR').format(_visitDate!)
                                          : '미정',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showTimePickerMenu(context),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: '방문시간',
                                      labelStyle: const TextStyle(fontSize: 13),
                                      enabledBorder: _enabledBorder,
                                      border: _enabledBorder,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    child: Text(
                                      _visitTime ?? '미정',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneNumberController,
                            focusNode: _phoneNumberFocus,
                            decoration: InputDecoration(
                              labelText: '전화번호 *',
                              labelStyle: const TextStyle(fontSize: 13),
                              hintText: '010-0000-0000',
                              enabledBorder: _enabledBorder,
                              focusedBorder: _focusedBorder,
                              errorBorder: _errorBorder,
                              focusedErrorBorder: _errorBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              final digitsOnly = _getDigitsOnly(value);
                              if (digitsOnly.length != 10 && digitsOnly.length != 11) {
                                return '올바른 전화번호 형식이 아닙니다 (10-11자리)';
                              }
                              if (digitsOnly.length == 11 && !digitsOnly.startsWith('010')) {
                                return '휴대폰 번호는 010으로 시작해야 합니다';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: '주소',
                              labelStyle: const TextStyle(fontSize: 13),
                              enabledBorder: _enabledBorder,
                              focusedBorder: _focusedBorder,
                              errorBorder: _errorBorder,
                              focusedErrorBorder: _errorBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 2,
                            minLines: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9ㄱ-ㅎ가-힣\s,\-]')),
                            ],
                            validator: (value) {
                              // 주소는 선택 입력
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _showWorkItemsDialog,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '작업 내용 *',
                                labelStyle: const TextStyle(fontSize: 13),
                                enabledBorder: _enabledBorder,
                                border: _enabledBorder,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey[50],
                                suffixIcon: const Icon(Icons.add, size: 18),
                              ),
                              child: Text(
                                _workItemsWithCount.isEmpty
                                    ? '선택된 항목 없음'
                                    : _workItemsWithCount.entries.map((e) => '${e.key} ${e.value}건').join(', '),
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _workCountController,
                            decoration: InputDecoration(
                              labelText: '총 작업 건수',
                              labelStyle: const TextStyle(fontSize: 13),
                              disabledBorder: _enabledBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[200],
                            ),
                            readOnly: true,
                            enabled: false,
                          ),
                          const SizedBox(height: 10),
                          // 총 금액 표시
                          if (_workPrices.isNotEmpty)
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: '총 금액',
                                labelStyle: const TextStyle(fontSize: 13),
                                enabledBorder: _enabledBorder,
                                border: _enabledBorder,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey[200],
                              ),
                              child: Text(
                                '${NumberFormat('#,###').format(_workPrices.entries.fold(0, (sum, entry) {
                                  final count = _workItemsWithCount[entry.key] ?? 1;
                                  return sum + (entry.value * count);
                                }))}원',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (_workPrices.isNotEmpty) const SizedBox(height: 10),
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: '비고',
                              labelStyle: const TextStyle(fontSize: 13),
                              enabledBorder: _enabledBorder,
                              focusedBorder: _focusedBorder,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 2,
                            minLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSchedule,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor:  Color.fromARGB(255, 20, 137, 226),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.schedule == null ? '스케줄 추가' : '수정 완료',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// 작업 항목 선택 다이얼로그
class _WorkItemsDialog extends StatefulWidget {
  final Company company;
  final Map<String, int> initialWorkItems;
  final Map<String, int> initialWorkPrices;
  final Function(Map<String, int>, Map<String, int>) onConfirm;

  const _WorkItemsDialog({
    required this.company,
    required this.initialWorkItems,
    required this.initialWorkPrices,
    required this.onConfirm,
  });

  @override
  State<_WorkItemsDialog> createState() => _WorkItemsDialogState();
}

class _WorkItemsDialogState extends State<_WorkItemsDialog> {
  late Map<String, int> _tempWorkItems;
  late Map<String, int> _tempWorkPrices;
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, FocusNode> _priceFocusNodes = {};
  late List<WorkItem> _displayWorkItems; // 표시할 작업 항목 목록 (현재 항목 + 삭제된 항목)
  late Set<String> _deletedWorkItems; // 삭제된 작업 항목 이름

  @override
  void initState() {
    super.initState();
    _tempWorkItems = Map<String, int>.from(widget.initialWorkItems);
    _tempWorkPrices = Map<String, int>.from(widget.initialWorkPrices);

    // 현재 업체 작업 항목 이름 Set
    final currentWorkItemNames = widget.company.workItems.map((item) => item.name).toSet();

    // 삭제된 작업 항목 찾기 (initialWorkItems에는 있지만 현재 company.workItems에는 없는 항목)
    _deletedWorkItems = widget.initialWorkItems.keys.where((name) => !currentWorkItemNames.contains(name)).toSet();

    // 표시할 작업 항목 목록 생성: 현재 작업 항목 + 삭제된 작업 항목
    _displayWorkItems = List<WorkItem>.from(widget.company.workItems);

    // 삭제된 항목을 WorkItem 객체로 생성하여 추가
    for (var deletedName in _deletedWorkItems) {
      _displayWorkItems.add(WorkItem(
        name: deletedName,
        price: widget.initialWorkPrices[deletedName] ?? 0,
      ));
    }

    // 각 작업 항목에 대한 컨트롤러와 FocusNode 초기화
    for (var workItem in _displayWorkItems) {
      final currentPrice = _tempWorkPrices[workItem.name] ?? workItem.price;
      _priceControllers[workItem.name] = TextEditingController(
        text: NumberFormat('#,###').format(currentPrice),
      );

      // FocusNode 생성 및 리스너 추가
      final focusNode = FocusNode();
      focusNode.addListener(() {
        final controller = _priceControllers[workItem.name]!;
        if (focusNode.hasFocus) {
          // 포커스 시: 콤마 제거
          final value = controller.text.replaceAll(',', '');
          controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        } else {
          // 포커스 아웃 시: 콤마 포맷 적용
          final value = controller.text.replaceAll(',', '');
          if (value.isNotEmpty) {
            final numValue = int.tryParse(value) ?? 0;
            controller.text = NumberFormat('#,###').format(numValue);
          }
        }
      });
      _priceFocusNodes[workItem.name] = focusNode;
    }
  }

  @override
  void dispose() {
    // 모든 컨트롤러와 FocusNode 정리
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _priceFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('${widget.company.name} - 작업 선택'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width - 32, // 화면 너비 - 좌우 패딩
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _displayWorkItems.length,
          itemBuilder: (context, index) {
            final workItem = _displayWorkItems[index];
            final isSelected = _tempWorkItems.containsKey(workItem.name);
            final isDeleted = _deletedWorkItems.contains(workItem.name);

            return Card(
              key: ValueKey(workItem.name),
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isSelected ? 2 : 0,
              color: isSelected ? Colors.blue.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _tempWorkItems[workItem.name] = 1;
                                _tempWorkPrices[workItem.name] =
                                    int.tryParse(_priceControllers[workItem.name]!.text) ?? workItem.price;
                              } else {
                                _tempWorkItems.remove(workItem.name);
                                _tempWorkPrices.remove(workItem.name);
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDeleted ? '${workItem.name} (삭제됨)' : workItem.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDeleted ? Colors.red.shade700 : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '기본 금액: ${NumberFormat('#,###').format(workItem.price)}원',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDeleted ? Colors.red.shade400 : const Color.fromARGB(255, 54, 49, 49),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              setState(() {
                                if (_tempWorkItems[workItem.name]! > 1) {
                                  _tempWorkItems[workItem.name] = _tempWorkItems[workItem.name]! - 1;
                                } else {
                                  _tempWorkItems[workItem.name] = 1;
                                }
                              });
                            },
                          ),
                          Text(
                            '${_tempWorkItems[workItem.name]}건',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () {
                              setState(() {
                                _tempWorkItems[workItem.name] = _tempWorkItems[workItem.name]! + 1;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0, right: 8.0, top: 4.0),
                        child: TextField(
                          key: ValueKey('price_${workItem.name}'),
                          controller: _priceControllers[workItem.name],
                          focusNode: _priceFocusNodes[workItem.name],
                          decoration: const InputDecoration(
                            labelText: '금액',
                            hintText: '금액 입력',
                            suffixText: '원',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            final price = int.tryParse(value.replaceAll(',', '')) ?? 0;
                            _tempWorkPrices[workItem.name] = price;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            widget.onConfirm(_tempWorkItems, _tempWorkPrices);
            Navigator.pop(context);
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
