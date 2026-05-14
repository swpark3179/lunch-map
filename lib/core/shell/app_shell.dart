import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/opus_tokens.dart';

/// 앱 전체 공통 셸 (바텀 내비게이션) — OPUS-X redesign.
///
/// 탭: 지도 · 목록 · 등록 · 추천.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _routes = ['/', '/locations', '/map-picker', '/budget'];

  int _getCurrentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/budget')) return 3;
    if (loc.startsWith('/map-picker')) return 2;
    if (loc.startsWith('/locations') || loc.startsWith('/location/')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: OpusColors.gray100)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F101828),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) =>
                      context.go(_routes[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map_rounded),
                      label: '지도',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt_rounded),
                      label: '목록',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.add_circle_outline_rounded),
                      selectedIcon: Icon(Icons.add_circle_rounded),
                      label: '등록',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                      label: '추천',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
