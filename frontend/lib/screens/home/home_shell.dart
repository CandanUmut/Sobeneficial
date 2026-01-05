import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../rfh/rfh_list_screen.dart';
import '../content/content_list_screen.dart';
import '../qa/qa_list_screen.dart';
import '../projects/projects_list_screen.dart';
import '../events/events_list_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../wallet/wallet_screen.dart';
import '../psm/offers_list_screen.dart'; // PSM main page

enum SortTab { helpful, newest, trending }

class HomeShell extends StatefulWidget {
  final Widget child; // ShellRoute gereği; burada _pages kullanıyoruz
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _supabase = Supabase.instance.client;

  // RFH ekranına global arama/sıralama geçebilmek için:
  final GlobalKey<RFHListScreenState> _rfhKey = GlobalKey<RFHListScreenState>();

  // Sol panel / bottom nav index
  int _index = 0;

  // Üst bar sıralama sekmesi
  SortTab _sort = SortTab.helpful;

  // Üst bar arama metni
  String _query = "";

  // *** SAYFA SIRASI _destinations ile birebir eşleşir ***
  // 0 Help(RFH) • 1 Support(PSM) • 2 Content • 3 Q&A • 4 Projects • 5 Events • 6 Wallet • 7 Profile • 8 Alerts
  late final List<Widget> _pages = <Widget>[
    RFHListScreen(key: _rfhKey), // 0
    const OffersListScreen(),    // 1 (PSM)
    const ContentListScreen(),   // 2
    const QAListScreen(),        // 3
    const ProjectsListScreen(),  // 4
    const EventsListScreen(),    // 5
    const WalletScreen(),        // 6
    const ProfileScreen(),       // 7
    const NotificationsScreen(), // 8
  ];

  // Sol panel hedefleri (ikon, başlık) — sıra _pages ile aynı
  static const _destinations = <(IconData, String)>[
    (Icons.help_outline, "Help"),                 // 0
    (Icons.volunteer_activism, "Support"),        // 1 (PSM)
    (Icons.menu_book_outlined, "Content"),        // 2
    (Icons.question_answer_outlined, "Q&A"),      // 3
    (Icons.group_work_outlined, "Projects"),      // 4
    (Icons.event_outlined, "Events"),             // 5
    (Icons.account_balance_wallet_outlined, "Wallet"), // 6
    (Icons.person_outline, "Profile"),            // 7
    (Icons.notifications_none, "Alerts"),         // 8
  ];

  // Hangi sayfa kendi FAB’ini gösteriyor? (çifte FAB’i önlemek için)
  // Burada global FAB yalnızca liste sayfalarında (Help/Content/Q&A/Projects/Events) görünsün.
  static const List<bool> _pageHasOwnFab = [
    false, // 0 Help
    false, // 1 Support (PSM)
    false, // 2 Content
    false, // 3 Q&A
    false, // 4 Projects
    false, // 5 Events
    false, // 6 Wallet
    false, // 7 Profile
    false, // 8 Alerts
  ];

  void _onSelectIndex(int i) {
    setState(() => _index = i);
  }

  // FAB: sayfa index eşleşmelerine göre yönlendir
  void _onFab() {
    switch (_index) {
      case 0: context.push('/rfh/new'); break;       // Help
      case 2: context.push('/content/new'); break;   // Content
      case 3: context.push('/qa/new'); break;        // Q&A
      case 4: context.push('/projects/new'); break;  // Projects
      case 5: context.push('/events/new'); break;    // Events
      default:
      // Support/Wallet/Profile/Alerts: FAB yok
        break;
    }
  }

  // Responsive: geniş ekranda NavigationRail; dar ekranda BottomNavigationBar
  bool get _isWide => MediaQuery.of(context).size.width >= 900;

  // Arama/sıralama değişince RFH ekranına “dışarıdan” ilet
  void _notifyChildFilters() {
    if (_index == 0) {
      _rfhKey.currentState?.applyExternalFilters(
        query: _query.isEmpty ? null : _query,
        sort: _sort,
      );
    }
  }

  // Kullanıcı avatar’ı (profil fotoğrafı)
  Widget _buildAvatarButton() {
    final user = _supabase.auth.currentUser;
    return IconButton(
      tooltip: user == null ? 'Sign in' : 'Profile',
      onPressed: () => setState(() => _index = 7), // Profile index = 7
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.teal.withOpacity(.15),
        child: const Icon(Icons.person, size: 18),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 8,
      title: Row(
        children: [
          const Text('BenefiSocial', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          // Arama kutusu (global)
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search…",
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onSubmitted: (v) {
                  setState(() => _query = v.trim());
                  _notifyChildFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sıralama sekmeleri (global) — şimdilik yalnız RFH etkileniyor
          SegmentedButton<SortTab>(
            segments: const [
              ButtonSegment(value: SortTab.helpful, label: Text('Helpful'), icon: Icon(Icons.star_rate_outlined)),
              ButtonSegment(value: SortTab.newest, label: Text('New'), icon: Icon(Icons.fiber_new_outlined)),
              ButtonSegment(value: SortTab.trending, label: Text('Trending'), icon: Icon(Icons.trending_up_outlined)),
            ],
            selected: {_sort},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) setState(() => _sort = s.first);
              _notifyChildFilters();
            },
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => setState(() => _index = 8), // Alerts index = 8
          icon: const Icon(Icons.notifications_none),
        ),
        _buildAvatarButton(),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildRail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _onSelectIndex,
      extended: true,
      minExtendedWidth: 200,
      destinations: [
        for (final item in _destinations)
          NavigationRailDestination(
            icon: Icon(item.$1),
            label: Text(item.$2),
          ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _onSelectIndex,
      destinations: [
        for (final item in _destinations)
          NavigationDestination(icon: Icon(item.$1), label: item.$2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(child: _pages[_index]);

    final showFab =
        !_pageHasOwnFab[_index] && [0, 2, 3, 4, 5].contains(_index); // sadece liste sayfalarında göster

    return Scaffold(
      appBar: _buildAppBar(),
      body: _isWide
          ? Row(
        children: [
          _buildRail(),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      )
          : body,
      bottomNavigationBar: _isWide ? null : _buildBottomNav(),
      floatingActionButton: showFab
          ? FloatingActionButton(
        onPressed: _onFab,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
