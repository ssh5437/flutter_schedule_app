import 'package:flutter/material.dart';

class HelpGuideScreen extends StatefulWidget {
  final int initialTab;
  const HelpGuideScreen({super.key, this.initialTab = 0});

  @override
  State<HelpGuideScreen> createState() => _HelpGuideScreenState();
}

class _HelpGuideScreenState extends State<HelpGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기능 가이드'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '업체 등록'),
            Tab(text: '텍스트 추출'),
            Tab(text: '이미지 추출'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CompanyGuideTab(),
          _TextExtractionGuideTab(),
          _ImageExtractionGuideTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _StepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final IconData icon;

  const _TipBox({
    required this.title,
    required this.content,
    this.color = const Color(0xFF1565C0),
    this.icon = Icons.lightbulb_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 탭 1: 업체 등록 가이드
// ─────────────────────────────────────────────────────────────

class _CompanyGuideTab extends StatelessWidget {
  const _CompanyGuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        _TipBox(
          icon: Icons.info_outline,
          title: '업체 등록이 왜 필요한가요?',
          content:
              '업체 등록은 스케줄 관리의 시작점입니다. '
              '업체마다 자주 하는 작업과 단가를 미리 등록해 두면, '
              '스케줄 추가 시 선택만 해도 금액이 자동으로 계산됩니다.',
          color: const Color(0xFF1565C0),
        ),
        const _SectionHeader(
          text: '업체 등록 순서',
          icon: Icons.business,
          color: Color(0xFF1565C0),
        ),
        const _StepCard(
          step: 1,
          icon: Icons.menu,
          title: '업체 관리 메뉴 진입',
          description:
              '하단 탭에서 [업체 관리] 버튼을 누르거나, 스케줄 추가 화면에서 업체 선택 드롭다운 옆의 [+] 버튼을 누르면 업체 등록 화면으로 이동합니다.',
          color: Color(0xFF1565C0),
        ),
        const _StepCard(
          step: 2,
          icon: Icons.edit,
          title: '업체명 입력',
          description:
              '업체 이름을 입력합니다. 최대 10자까지 입력할 수 있으며, 스케줄 목록에서 구분이 쉽도록 짧고 명확하게 입력하는 것이 좋습니다.\n예) 삼성, 엘지, 코웨이',
          color: Color(0xFF1565C0),
        ),
        const _StepCard(
          step: 3,
          icon: Icons.palette,
          title: '업체 색상 지정',
          description:
              '캘린더와 스케줄 목록에서 해당 업체의 스케줄을 색상으로 구분할 수 있습니다. '
              '색상 선택기에서 원하는 색상을 선택하세요. 업체마다 다른 색상을 지정하면 한눈에 구분하기 쉽습니다.',
          color: Color(0xFF1565C0),
        ),
        const _StepCard(
          step: 4,
          icon: Icons.work_outline,
          title: '작업 항목 등록',
          description:
              '해당 업체에서 자주 하는 작업과 단가를 등록합니다.\n'
              '• [작업 추가] 버튼을 눌러 작업명과 단가(금액)를 입력하세요.\n'
              '• 여러 작업을 추가하면 스케줄 등록 시 체크박스로 선택할 수 있습니다.\n'
              '• 작업 항목 순서는 길게 눌러 드래그로 변경할 수 있습니다.',
          color: Color(0xFF1565C0),
        ),
        const _StepCard(
          step: 5,
          icon: Icons.save,
          title: '저장',
          description:
              '모든 정보 입력 후 우측 상단의 [저장] 버튼을 눌러 업체를 등록합니다. '
              '이후 스케줄 추가 화면에서 해당 업체를 선택하면 등록된 작업 항목이 자동으로 불러와집니다.',
          color: Color(0xFF1565C0),
        ),
        const _SectionHeader(
          text: '작업 항목 활용',
          icon: Icons.checklist,
          color: Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.check_circle_outline,
          title: '작업 항목 = 자동 금액 계산의 핵심',
          content:
              '작업 항목에 단가를 등록해 두면, 스케줄 작성 시 작업을 선택하는 것만으로 총 금액이 자동 계산됩니다. '
              '단가 변경이 필요하면 업체 편집에서 수정하면 됩니다.',
          color: const Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.repeat,
          title: '같은 작업을 여러 번 하는 경우',
          content:
              '스케줄 추가 시 같은 작업 항목을 선택한 후 건수를 늘릴 수 있습니다. '
              '예를 들어 에어컨 청소를 3대 진행한다면 [에어컨 청소] 항목에서 건수를 3으로 설정하면 '
              '단가 × 3으로 자동 계산됩니다.',
          color: const Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.share,
          title: '업체 정보 공유 (같은 도급사 사용)',
          content:
              '같은 도급사에서 일하는 동료에게 업체 세팅을 공유할 수 있습니다.\n'
              '[설정 → 데이터 복구] 화면에서 [업체 정보 가져오기]를 선택하거나, '
              '디버그 화면에서 [업체정보 백업하기]로 JSON 파일을 내보낼 수 있습니다.',
          color: const Color(0xFF7B1FA2),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 탭 2: 텍스트에서 스케줄 추출 가이드
// ─────────────────────────────────────────────────────────────

class _TextExtractionGuideTab extends StatelessWidget {
  const _TextExtractionGuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        _TipBox(
          icon: Icons.auto_awesome,
          title: '텍스트에서 스케줄 추출이란?',
          content:
              '카카오톡·문자 등에서 받은 고객 정보 텍스트를 붙여넣기만 하면 '
              'AI가 이름·연락처·주소·방문일 등을 자동으로 인식해 스케줄 양식을 채워줍니다. '
              '직접 입력하는 시간을 크게 줄일 수 있습니다.',
          color: const Color(0xFF7B1FA2),
        ),
        const _SectionHeader(
          text: '사용 방법',
          icon: Icons.text_snippet,
          color: Color(0xFF7B1FA2),
        ),
        const _StepCard(
          step: 1,
          icon: Icons.add_circle_outline,
          title: '스케줄 추가 화면 열기',
          description:
              '스케줄 목록에서 우측 하단의 [+] 버튼을 눌러 스케줄 추가 화면을 엽니다.',
          color: Color(0xFF7B1FA2),
        ),
        const _StepCard(
          step: 2,
          icon: Icons.text_fields,
          title: '텍스트 추출 버튼 누르기',
          description:
              '화면 상단 오른쪽의 [T↓] 버튼(텍스트에서 스케줄 추출)을 누릅니다. '
              '남은 사용 가능 횟수가 표시됩니다.',
          color: Color(0xFF7B1FA2),
        ),
        const _StepCard(
          step: 3,
          icon: Icons.content_paste,
          title: '텍스트 붙여넣기',
          description:
              '팝업 입력창에 카카오톡·문자 등에서 받은 고객 정보를 붙여넣습니다.\n\n'
              '예시 형식:\n'
              '"홍길동 010-1234-5678\n'
              '서울시 강남구 테헤란로 123\n'
              '5월 15일 오전 10시 방문\n'
              '에어컨 청소 2대"',
          color: Color(0xFF7B1FA2),
        ),
        const _StepCard(
          step: 4,
          icon: Icons.auto_fix_high,
          title: '추출하기',
          description:
              '[추출하기] 버튼을 누르면 AI가 텍스트를 분석합니다. '
              '잠시 기다리면 고객명·연락처·주소·방문일자가 자동으로 입력됩니다. '
              '작업 항목도 업체에 등록된 항목과 매칭되면 자동 선택됩니다.',
          color: Color(0xFF7B1FA2),
        ),
        const _StepCard(
          step: 5,
          icon: Icons.edit_note,
          title: '확인 및 저장',
          description:
              '자동 입력된 내용을 확인하고 필요한 부분을 수정한 뒤 [저장] 버튼을 누릅니다. '
              'AI가 인식하지 못한 정보는 직접 입력해 주세요.',
          color: Color(0xFF7B1FA2),
        ),
        const _SectionHeader(
          text: '사용 횟수 안내',
          icon: Icons.info_outline,
          color: Color(0xFFE65100),
        ),
        _TipBox(
          icon: Icons.hourglass_bottom,
          title: '무료 사용자: 월 30회',
          content:
              '무료 사용자는 매월 30회까지 텍스트 추출 기능을 사용할 수 있습니다. '
              '매월 1일에 자동으로 초기화됩니다. '
              '추출 버튼에서 남은 횟수를 확인할 수 있습니다.',
          color: const Color(0xFFE65100),
        ),
        _TipBox(
          icon: Icons.workspace_premium,
          title: 'Plus 회원: 무제한',
          content:
              'Plus 멤버십 구독 시 횟수 제한 없이 무제한으로 사용할 수 있습니다. '
              '매일 대량의 스케줄을 처리하는 경우 Plus 멤버십을 추천드립니다.',
          color: const Color(0xFF1565C0),
        ),
        const _SectionHeader(
          text: '잘 되는 예시 / 주의사항',
          icon: Icons.tips_and_updates,
          color: Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.check_circle_outline,
          title: '잘 인식되는 정보',
          content:
              '• 이름: "홍길동", "홍 길동", "성함: 홍길동"\n'
              '• 연락처: "010-1234-5678", "01012345678"\n'
              '• 주소: 도로명/지번 주소 모두 인식\n'
              '• 날짜: "5월 15일", "5/15", "2025-05-15"\n'
              '• 작업: 업체에 등록된 작업명과 유사한 단어',
          color: const Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.warning_amber_outlined,
          title: '주의사항',
          content:
              '• 추출 결과는 AI 분석이므로 반드시 확인 후 저장하세요.\n'
              '• 방문 시간은 자동 추출되지 않아 "시간 미정"으로 설정됩니다. 직접 입력해 주세요.\n'
              '• 과거 날짜가 추출되면 오늘 날짜로 자동 변경됩니다.\n'
              '• 추출 실패 시 사용 횟수는 차감되지 않습니다.',
          color: const Color(0xFFE65100),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 탭 3: 이미지에서 스케줄 추출 가이드
// ─────────────────────────────────────────────────────────────

class _ImageExtractionGuideTab extends StatelessWidget {
  const _ImageExtractionGuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        _TipBox(
          icon: Icons.auto_awesome,
          title: '이미지에서 스케줄 추출이란?',
          content:
              '사진으로 받은 고객 정보(작업 지시서, 캡처 이미지 등)를 카메라로 찍거나 갤러리에서 선택하면 '
              'AI가 이미지 속 글자를 읽어 스케줄 양식을 자동으로 채워줍니다.',
          color: const Color(0xFF00695C),
        ),
        const _SectionHeader(
          text: '사용 방법',
          icon: Icons.image_search,
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 1,
          icon: Icons.add_circle_outline,
          title: '스케줄 추가 화면 열기',
          description:
              '스케줄 목록에서 우측 하단의 [+] 버튼을 눌러 스케줄 추가 화면을 엽니다.',
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 2,
          icon: Icons.image,
          title: '이미지 추출 버튼 누르기',
          description:
              '화면 상단 오른쪽의 [📷] 버튼(이미지에서 스케줄 추출)을 누릅니다. '
              '남은 사용 가능 횟수가 표시되며, 업체를 미리 선택하면 작업 항목 매칭 정확도가 높아집니다.',
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 3,
          icon: Icons.photo_library,
          title: '이미지 선택',
          description:
              '• [갤러리]: 카카오톡 등에서 저장한 이미지를 선택합니다.\n'
              '• [카메라]: 작업 지시서나 메모를 바로 촬영합니다.\n\n'
              '글씨가 선명하고 이미지가 밝을수록 인식률이 높아집니다.',
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 4,
          icon: Icons.document_scanner,
          title: 'OCR 텍스트 인식',
          description:
              '선택한 이미지에서 텍스트를 자동으로 추출합니다. '
              '처음 사용 시 한국어 인식 모델(약 50MB)을 자동으로 다운로드합니다. '
              'Wi-Fi 환경에서 처음 사용하는 것을 권장합니다.',
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 5,
          icon: Icons.auto_fix_high,
          title: 'AI 정보 분석',
          description:
              '인식된 텍스트를 AI가 분석해 고객명·연락처·주소·방문일·작업 항목을 추출합니다. '
              '업체에 등록된 작업 항목과 자동으로 매칭합니다.',
          color: Color(0xFF00695C),
        ),
        const _StepCard(
          step: 6,
          icon: Icons.edit_note,
          title: '확인 및 저장',
          description:
              '자동 입력된 내용을 확인하고 필요한 부분을 수정한 뒤 [저장]을 누릅니다.',
          color: Color(0xFF00695C),
        ),
        const _SectionHeader(
          text: '사용 횟수 안내',
          icon: Icons.info_outline,
          color: Color(0xFFE65100),
        ),
        _TipBox(
          icon: Icons.hourglass_bottom,
          title: '무료 사용자: 월 30회 (텍스트 추출과 합산)',
          content:
              '텍스트 추출과 이미지 추출의 사용 횟수는 합산됩니다. '
              '두 기능을 합쳐 월 30회까지 사용할 수 있으며, 매월 1일에 자동 초기화됩니다.',
          color: const Color(0xFFE65100),
        ),
        _TipBox(
          icon: Icons.workspace_premium,
          title: 'Plus 회원: 무제한',
          content:
              'Plus 멤버십 구독 시 횟수 제한 없이 무제한으로 사용할 수 있습니다.',
          color: const Color(0xFF1565C0),
        ),
        const _SectionHeader(
          text: '잘 되는 예시 / 주의사항',
          icon: Icons.tips_and_updates,
          color: Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.check_circle_outline,
          title: '인식률을 높이는 촬영 팁',
          content:
              '• 밝은 곳에서 촬영하세요.\n'
              '• 텍스트가 흔들리지 않도록 카메라를 고정하세요.\n'
              '• 이미지가 기울어지지 않도록 정면에서 촬영하세요.\n'
              '• 손글씨보다 인쇄된 텍스트가 더 잘 인식됩니다.\n'
              '• 카카오톡 이미지는 갤러리에 저장 후 선택하세요.',
          color: const Color(0xFF388E3C),
        ),
        _TipBox(
          icon: Icons.warning_amber_outlined,
          title: '주의사항',
          content:
              '• 이미지 최대 크기는 2048×2048 픽셀입니다. 큰 이미지는 자동으로 축소됩니다.\n'
              '• 이미지에서 텍스트를 전혀 찾지 못하면 사용 횟수가 차감되지 않습니다.\n'
              '• 방문 시간은 "시간 미정"으로 설정되므로 직접 입력해 주세요.\n'
              '• 과거 날짜는 오늘 날짜로 자동 변경됩니다.\n'
              '• 추출 결과는 반드시 확인 후 저장하세요.',
          color: const Color(0xFFE65100),
        ),
        _TipBox(
          icon: Icons.compare_arrows,
          title: '텍스트 추출 vs 이미지 추출',
          content:
              '카카오톡 등에서 문자로 받은 정보 → 텍스트 추출\n'
              '사진·스크린샷·작업 지시서 등 이미지로 받은 정보 → 이미지 추출\n\n'
              '두 기능 모두 같은 AI를 사용하므로 정확도는 유사합니다.',
          color: const Color(0xFF00695C),
        ),
      ],
    );
  }
}
