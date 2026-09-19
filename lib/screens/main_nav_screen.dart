import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import '../services/supabase_service.dart';
import '../services/recognition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/stamp.dart';
import '../services/collection_service.dart';
import '../services/stamp_repository.dart';
import '../widgets/stamp_visual_view.dart';
import '../widgets/stamp_facts.dart';
import '../widgets/recognition_result_view.dart';
import '../theme/app_theme.dart';

const _green = AppTheme.primaryBlack;
const _muted = AppTheme.textMuted;
const _line = AppTheme.borderGray;

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});
  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int tab = 0;
  String query = '', theme = '전체', collectionFilter = '전체';
  bool newest = false;
  final search = TextEditingController();
  Uint8List? photo;
  bool picking = false, identifying = false;
  Recognition? recognition;
  String? scanError;
  StreamSubscription<AuthState>? authSubscription;
  String? accountId;
  int scanGeneration = 0;
  bool recoveryOpen = false;
  Timer? dateTimer;
  DateTime displayedDate = DateTime.now();
  @override
  void initState() {
    super.initState();
    dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (now.year != displayedDate.year ||
          now.month != displayedDate.month ||
          now.day != displayedDate.day) {
        displayedDate = now;
        refresh();
      }
    });
    CollectionService.notifier.addListener(refresh);
    StampRepository.syncWithCloud().then((_) => refresh());
    accountId = SupabaseService.currentUser?.id;
    authSubscription = SupabaseService.authStateChanges?.listen(
      (state) {
        if (!mounted) return;
        final changed = state.session?.user.id != accountId;
        accountId = state.session?.user.id;
        if (changed) {
          scanGeneration++;
          setState(() {
            photo = null;
            recognition = null;
            scanError = null;
            identifying = false;
          });
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          refresh();
        }
        if (state.event == AuthChangeEvent.passwordRecovery) openRecovery();
      },
      onError: (_) {
        if (mounted) notify('로그인 연결을 확인해 주세요.');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupabaseService.recoveryPending) openRecovery();
    });
  }

  void openAccount() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
  Future<void> openRecovery() async {
    if (!mounted || recoveryOpen) return;
    recoveryOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen(recovery: true)),
    );
    recoveryOpen = false;
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    dateTimer?.cancel();
    CollectionService.notifier.removeListener(refresh);
    authSubscription?.cancel();
    search.dispose();
    super.dispose();
  }

  void navigate(int index) => setState(() {
    tab = index;
  });
  void notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void browse([String value = '전체']) => setState(() {
    tab = 1;
    theme = value;
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final body = [home, catalog, scanner, collection][tab]();
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: _line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(28, 38, 20, 34),
                      child: _Brand(),
                    ),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          selected: i == tab,
                          selectedTileColor: AppTheme.mint,
                          leading: Icon(_icons[i], color: _green),
                          title: Text(
                            _labels[i],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () => navigate(i),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        '작은 우표에 담긴\n커다란 세상.',
                        style: TextStyle(color: _muted, height: 1.8),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          wide
              ? null
              : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: navigate,
                destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _labels[i],
                  ),
                ),
              ),
    );
  }

  static const _icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.document_scanner_outlined,
    Icons.collections_bookmark_outlined,
  ];
  static const _labels = ['홈', '우표 도감', '사진 판독', '내 수집함'];

  Widget page(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
    children: children,
  );
  Widget heading(String eyebrow, String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
  Widget section(String title, VoidCallback action) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: action, child: const Text('모두 보기  →')),
    ],
  );

  Widget home() {
    final stamps = StampRepository.getAllStamps();
    final today = StampRepository.getTodayStamp();
    final stats = CollectionService.getStatistics();
    return page([
      Row(
        children: [
          const _Brand(),
          const Spacer(),
          IconButton(
            tooltip: SupabaseService.isLoggedIn ? '내 계정' : '로그인',
            onPressed: openAccount,
            icon: Icon(
              SupabaseService.isLoggedIn
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
          ),
          IconButton(
            tooltip: '앱 안내',
            onPressed: about,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        '당신의 수집이, 이야기가 되는 곳',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.peach,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final art = Transform.rotate(
              angle: .09,
              child: StampVisualView(
                stamp: today,
                width: (c.maxWidth * .42).clamp(110.0, 150.0),
                height: 168,
              ),
            );
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '오늘의 우표',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        today.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        StampRepository.todayStampContext(today),
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => detail(today),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: const Text('우표 이야기 읽기  ↗'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                art,
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      Material(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => navigate(2),
          child: const Padding(
            padding: EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(Icons.document_scanner_outlined, color: _green, size: 30),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이 우표, 어떤 우표일까요?',
                        style: TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '사진을 찍고 수집을 시작하세요',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: _green, size: 20),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 30),
      section('차곡차곡, 나의 수집', () => navigate(3)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _Stat('${stats['uniqueCollected']}', '수집한 우표')),
                Expanded(child: _Stat('${stats['totalPieces']}', '보유한 수량')),
                Expanded(child: _Stat('${stamps.length}', '도감 등록 종수')),
              ],
            ),
            const SizedBox(height: 22),
            LinearProgressIndicator(
              value: ((stats['completionRate'] as double) / 100).clamp(0, 1),
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: const Color(0xFFF0F1E9),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '나만의 도감을 한 장씩 채워보세요',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      section('테마로 만나는 우표', () => browse()),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            StampRepository.getAllThemes()
                .where((t) => t != '전체')
                .map(
                  (t) => ActionChip(
                    label: Text(t),
                    onPressed: () => browse(t),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _line),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 30),
      section('도감에서 발견하기', () => browse()),
      const SizedBox(height: 12),
      grid(stamps.take(4).toList()),
      const SizedBox(height: 22),
    ]);
  }

  Widget catalog() {
    final stamps =
        StampRepository.searchStamps(query: query, theme: theme).toList()..sort(
          (a, b) =>
              newest
                  ? b.issueYear.compareTo(a.issueYear)
                  : a.issueYear.compareTo(b.issueYear),
        );
    return page([
      heading('THE KOREAN STAMP ARCHIVE', '우표 도감'),
      TextField(
        controller: search,
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: '우표 이름, 발행연도, 키워드',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              query.isEmpty
                  ? null
                  : IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () {
                      search.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
        ),
      ),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              StampRepository.getAllThemes()
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: theme == t,
                        onSelected: (_) => setState(() => theme = t),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Text('${stamps.length}종의 우표', style: const TextStyle(color: _muted)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => newest = !newest),
            icon: const Icon(Icons.swap_vert, size: 17),
            label: Text(newest ? '최신 발행순' : '오래된 발행순'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (stamps.isEmpty)
        empty('검색 결과가 없어요', '다른 이름이나 발행연도로 찾아보세요.', Icons.search_off)
      else
        grid(stamps),
    ]);
  }

  Widget grid(List<Stamp> stamps) => LayoutBuilder(
    builder: (context, c) {
      final columns =
          c.maxWidth >= 680
              ? 4
              : c.maxWidth >= 480
              ? 3
              : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stamps.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 270,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, i) => tile(stamps[i], i),
      );
    },
  );
  Widget tile(Stamp s, int i) {
    final owned = CollectionService.getItemByStampId(s.id);
    final backgrounds = [
      const Color(0xFFFFF2CC),
      const Color(0xFFFFE8DC),
      const Color(0xFFDDF6EB),
      const Color(0xFFEDE6FF),
    ];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => detail(s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: backgrounds[i % 4],
                child: Stack(
                  children: [
                    Center(
                      child: StampVisualView(stamp: s, width: 86, height: 114),
                    ),
                    Positioned(
                      right: 3,
                      top: 3,
                      child: IconButton(
                        tooltip:
                            CollectionService.isWishlisted(s.id)
                                ? '위시리스트에서 제거'
                                : '위시리스트에 추가',
                        onPressed: () => CollectionService.toggleWishlist(s.id),
                        icon: Icon(
                          CollectionService.isWishlisted(s.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.issueYear}  ·  ${s.category}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    owned == null ? s.faceValue : '✓ 소장 ${owned.count}장',
                    style: TextStyle(
                      fontSize: 11,
                      color: owned == null ? _muted : _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget collection() {
    final all = StampRepository.getAllStamps();
    final stamps =
        all.where((s) {
          final item = CollectionService.getItemByStampId(s.id);
          return collectionFilter == '위시리스트'
              ? CollectionService.isWishlisted(s.id)
              : collectionFilter == '중복'
              ? item != null && item.count > 1
              : item != null;
        }).toList();
    return page([
      heading(
        'MY PERSONAL ARCHIVE',
        '내 수집함',
        trailing: IconButton(
          tooltip: '수집 기록 복사',
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: CollectionService.generateCatalogTextReport(),
              ),
            );
            if (mounted) notify('수집 기록을 복사했어요.');
          },
          icon: const Icon(Icons.ios_share),
        ),
      ),
      const Text('좋아하는 것을 모으는, 나만의 방식.', style: TextStyle(color: _muted)),
      const SizedBox(height: 22),
      Wrap(
        spacing: 8,
        children:
            ['전체', '중복', '위시리스트']
                .map(
                  (t) => ChoiceChip(
                    label: Text(t),
                    selected: collectionFilter == t,
                    onSelected: (_) => setState(() => collectionFilter = t),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 22),
      Text(
        '${stamps.length}종',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      if (stamps.isEmpty) ...[
        empty(
          collectionFilter == '위시리스트' ? '마음에 드는 우표를 찜해보세요' : '아직 수집한 우표가 없어요',
          '도감에서 우표를 선택해 첫 기록을 남겨보세요.',
          Icons.collections_bookmark_outlined,
        ),
        Center(
          child: FilledButton(
            onPressed: () => browse(),
            child: const Text('우표 도감 둘러보기'),
          ),
        ),
      ] else
        grid(stamps),
      const SizedBox(height: 24),
      if (CollectionService.loading) const LinearProgressIndicator(),
      if (CollectionService.syncError != null) ...[
        Text(CollectionService.syncError!),
        TextButton(
          onPressed: CollectionService.reloadForAccount,
          child: const Text('다시 불러오기'),
        ),
      ],
      Text(
        SupabaseService.isLoggedIn
            ? '로그인한 계정의 Supabase 수집함입니다. 찜 목록은 이 기기에 저장됩니다.'
            : '이 기기에 저장되는 개인 수집 기록입니다.',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      TextButton(
        onPressed: openAccount,
        child: Text(
          SupabaseService.isLoggedIn ? '내 계정 관리' : '로그인하고 클라우드 수집함 이용하기',
        ),
      ),
    ]);
  }

  Future<void> pick(ImageSource source) async {
    if (picking || identifying) return;
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await compute(
          normalizeStampPhoto,
          await file.readAsBytes(),
        );
        if (mounted) {
          setState(() {
            photo = bytes;
            recognition = null;
            scanError = null;
            scanGeneration++;
          });
        }
      }
    } on FormatException catch (e) {
      if (mounted) notify(e.message);
    } catch (_) {
      if (mounted) notify('사진을 열 수 없어요. 사진 접근 권한을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> identify() async {
    if (photo == null || identifying) return;
    if (!SupabaseService.isLoggedIn) {
      openAccount();
      return;
    }
    final generation = ++scanGeneration;
    setState(() {
      identifying = true;
      scanError = null;
      recognition = null;
    });
    try {
      final result = await RecognitionService.identify(photo!);
      if (mounted && generation == scanGeneration) {
        setState(() => recognition = result);
      }
    } on RecognitionException catch (e) {
      if (mounted && generation == scanGeneration) {
        setState(() => scanError = e.message);
      }
    } finally {
      if (mounted && generation == scanGeneration) {
        setState(() => identifying = false);
      }
    }
  }

  Future<void> saveRecognized() async {
    final official = recognition?.official;
    if (official == null) return;
    final stamp = official.toStamp();
    if (mounted) await edit(stamp, bytes: photo);
  }

  Widget scanner() {
    if (recognition != null) {
      return RecognitionResultView(
        result: recognition!,
        photo: photo,
        collected:
            recognition!.official != null &&
            CollectionService.isCollected(recognition!.official!.id),
        onBack: () => setState(() => recognition = null),
        onChoose: manualMatch,
        onSave: saveRecognized,
        onSelectCandidate:
            (stamp) => setState(() => recognition = recognition!.choose(stamp)),
      );
    }
    return page([
      heading(
        'STAMP SCANNER',
        '사진으로 우표 찾기',
        trailing: IconButton(
          tooltip: '내 계정',
          onPressed: openAccount,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ),
      const Text('우표 한 장이 선명하게 보이도록 촬영해 주세요.', style: TextStyle(color: _muted)),
      const SizedBox(height: 24),
      Container(
        height: 310,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: photo == null ? AppTheme.mint : AppTheme.subtleGray,
          borderRadius: BorderRadius.circular(24),
        ),
        child:
            photo != null
                ? Image.memory(photo!, fit: BoxFit.contain)
                : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_center_focus, color: _green, size: 72),
                    SizedBox(height: 20),
                    Text(
                      '우표 전체가 프레임 안에',
                      style: TextStyle(color: AppTheme.textMain),
                    ),
                  ],
                ),
      ),
      const SizedBox(height: 20),
      if (photo != null) ...[
        FilledButton.icon(
          onPressed: identifying ? null : identify,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(
            identifying
                ? '우표를 찾고 있어요…'
                : SupabaseService.isLoggedIn
                ? 'AI 판독하기'
                : '로그인하고 AI 판독하기',
          ),
        ),
        if (identifying)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          ),
        if (scanError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                scanError!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const SizedBox(height: 20),
      ],
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  picking || identifying
                      ? null
                      : () => pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 19),
              label: const Text('우표 촬영'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  picking || identifying
                      ? null
                      : () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 19),
              label: const Text('앨범에서 선택'),
            ),
          ),
        ],
      ),
      if (photo != null)
        TextButton(
          onPressed: identifying ? null : manualMatch,
          child: const Text('도감에서 직접 선택'),
        ),
      const SizedBox(height: 24),
      const _Tip(
        Icons.light_mode_outlined,
        '밝은 곳에서, 정면으로',
        '반사와 그림자를 피하고 네 모서리를 담아주세요.',
      ),
    ]);
  }

  Future<void> manualMatch() async {
    final captured = photo;
    final selected = await showModalBottomSheet<Stamp>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        String q = '';
        return StatefulBuilder(
          builder:
              (context, update) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        '사진 속 우표를 선택하세요',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => update(() => q = v),
                        decoration: const InputDecoration(
                          hintText: '우표 이름 또는 연도',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children:
                              StampRepository.searchStamps(query: q)
                                  .map(
                                    (s) => ListTile(
                                      title: Text(s.name),
                                      subtitle: Text(
                                        '${s.issueYear} · ${s.faceValue}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pop(context, s),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
    if (selected != null && mounted) await edit(selected, bytes: captured);
  }

  Future<void> detail(Stamp stamp) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _StampDetail(stamp: stamp, onEdit: () => edit(stamp)),
      ),
    );
    refresh();
  }

  Future<void> edit(Stamp stamp, {Uint8List? bytes}) async {
    final existing = CollectionService.getItemByStampId(stamp.id);
    final memo = TextEditingController(text: existing?.memo ?? '');
    final place = TextEditingController(text: existing?.storageLocation ?? '');
    int count = existing?.count ?? 1;
    var condition = existing?.condition ?? StampCondition.mint;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, update) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existing == null ? '수집함에 한 장 더' : '소장 기록 편집',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(stamp.name),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Text('보유 수량')),
                          IconButton(
                            tooltip: '수량 줄이기',
                            onPressed:
                                count > 1 && !saving
                                    ? () => update(() => count--)
                                    : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$count장'),
                          IconButton(
                            tooltip: '수량 늘리기',
                            onPressed:
                                count < 9999 && !saving
                                    ? () => update(() => count++)
                                    : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<StampCondition>(
                        value: condition,
                        decoration: const InputDecoration(labelText: '우표 상태'),
                        items:
                            StampCondition.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.title),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            saving ? null : (v) => update(() => condition = v!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: place,
                        decoration: const InputDecoration(
                          labelText: '보관 위치',
                          hintText: '예: 첫 번째 앨범 12쪽',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: memo,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '수집 메모',
                          hintText: '이 우표와의 만남을 기록해 보세요',
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed:
                            saving
                                ? null
                                : () async {
                                  update(() => saving = true);
                                  try {
                                    await CollectionService.addOrUpdateItem(
                                      CollectionItem(
                                        id:
                                            existing?.id ??
                                            'local_${DateTime.now().microsecondsSinceEpoch}',
                                        stampId: stamp.id,
                                        condition: condition,
                                        count: count,
                                        acquiredDate:
                                            existing?.acquiredDate ??
                                            DateTime.now(),
                                        purchasePrice: existing?.purchasePrice,
                                        storageLocation: place.text.trim(),
                                        memo: memo.text.trim(),
                                        userImageUrl: existing?.userImageUrl,
                                        userImagePath: existing?.userImagePath,
                                      ),
                                      photoBytes: bytes,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (mounted) notify('수집 기록을 저장했어요.');
                                  } catch (_) {
                                    if (context.mounted) {
                                      update(() => saving = false);
                                    }
                                    if (mounted) {
                                      notify('저장하지 못했어요. 다시 시도해 주세요.');
                                    }
                                  }
                                },
                        child: Text(saving ? '저장 중…' : '수집 기록 저장'),
                      ),
                    ],
                  ),
                ),
          ),
    );
    // Controllers remain alive through the sheet's closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    memo.dispose();
    place.dispose();
  }

  Widget empty(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45),
    child: Column(
      children: [
        Icon(icon, size: 48, color: _muted),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
  void about() => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('우표모아 · 첫 번째 버전'),
          content: const Text(
            '대한민국 우표를 발견하고 기록하는 수집 앱입니다.\n\n우표 이미지와 발행 정보는 사용 허락을 받은 한국우표포털 자료를 연결합니다. 도감은 순차 확장 중입니다.\n\n사진 판독은 AI 관찰, 공식 DB 검색, 원본 이미지 비교를 함께 사용합니다. 비슷한 우표는 직접 확인하여 선택해 주세요. 판독은 진품 감정이나 시세 평가가 아닙니다.',
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

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          'assets/branding/app-logo.png',
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          semanticLabel: '우표모아 로고',
        ),
      ),
      const SizedBox(width: 9),
      const Text(
        '우표모아',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ],
  );
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Tip(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: _muted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StampDetail extends StatelessWidget {
  final Stamp stamp;
  final Future<void> Function() onEdit;
  const _StampDetail({required this.stamp, required this.onEdit});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: CollectionService.notifier,
    builder: (context, value, child) {
      final item = CollectionService.getItemByStampId(stamp.id);
      return Scaffold(
        appBar: AppBar(
          title: const Text('우표 이야기'),
          actions: [
            IconButton(
              tooltip: '위시리스트 변경',
              onPressed: () => CollectionService.toggleWishlist(stamp.id),
              icon: Icon(
                CollectionService.isWishlisted(stamp.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if ((item?.userImageUrl ?? stamp.imageUrl ?? '').isNotEmpty)
                  StampDetailImage(
                    url: item?.userImageUrl ?? stamp.imageUrl!,
                    label: stamp.name,
                  )
                else
                  Center(
                    child: StampVisualView(
                      stamp: stamp,
                      width: 180,
                      height: 210,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  '${stamp.issueYear}  /  ${stamp.category}',
                  style: const TextStyle(color: _muted, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                Text(
                  stamp.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                StampFacts(
                  fields:
                      stamp.officialDetails.isNotEmpty
                          ? stamp.officialDetails
                          : {
                            '발행일': stamp.issueDate,
                            '액면가격': stamp.faceValue,
                            '디자이너': stamp.designer,
                            '인쇄처': stamp.printer,
                            '우표크기': stamp.sizeMm,
                            '천공': stamp.perforation,
                          },
                ),
                const Divider(height: 40),
                const Text(
                  '우표 설명',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(stamp.description, style: const TextStyle(height: 1.8)),
                const SizedBox(height: 12),
                Text(
                  stamp.historicalStory,
                  style: const TextStyle(height: 1.8),
                ),
                const SizedBox(height: 18),
                Text(
                  stamp.id.startsWith('epost_')
                      ? '우표 설명 출처 · 한국우표포털'
                      : '기존 프로젝트의 샘플 정보입니다. 공식 발행자료와 대조가 필요합니다.',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (item != null) ...[
                  const Divider(height: 40),
                  Text(
                    '내 소장 기록 · ${item.count}장',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('상태: ${item.condition.title}'),
                  if (item.storageLocation?.isNotEmpty ?? false)
                    Text('보관: ${item.storageLocation}'),
                  if (item.memo?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(item.memo!),
                  ],
                  TextButton.icon(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('수집 기록을 삭제할까요?'),
                              content: const Text(
                                '수량, 메모와 사진 기록이 삭제됩니다. 도감의 우표 정보는 유지됩니다.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                      );
                      if (yes == true) {
                        try {
                          await CollectionService.removeItem(item.id);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('삭제하지 못했어요. 연결 상태를 확인해 주세요.'),
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('수집 기록 삭제'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.add),
                  label: Text(item == null ? '내 수집함에 추가' : '소장 기록 편집'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );
}
