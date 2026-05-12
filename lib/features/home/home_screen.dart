import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/location_provider.dart';

/// 홈 화면 (대시보드)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(locationStatsProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── 히어로 헤더 ──
          SliverToBoxAdapter(child: _HeroHeader(isDesktop: isDesktop)),

          // ── 통계 카드 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('📊 대시보드', style: theme.textTheme.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: stats.when(
              data:
                  (data) => _StatsGrid(
                    total: data['total'] ?? 0,
                    fixed: data['fixed'] ?? 0,
                    unfixed: data['unfixed'] ?? 0,
                    isDesktop: isDesktop,
                  ),
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (e, _) => _StatsGrid(
                    total: 0,
                    fixed: 0,
                    unfixed: 0,
                    isDesktop: isDesktop,
                  ),
            ),
          ),

          // ── 빠른 액션 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('⚡ 빠른 시작', style: theme.textTheme.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(child: _QuickActions(isDesktop: isDesktop)),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── 히어로 헤더 ───
class _HeroHeader extends StatelessWidget {
  final bool isDesktop;

  const _HeroHeader({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF7C3AED), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '점심 지도',
                      style: TextStyle(
                        fontSize: isDesktop ? 32 : 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lunch Map — 맛집을 한눈에',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '지도에서 장소를 등록하고 내 주변 맛집을 한눈에 확인하세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 통계 그리드 ───
class _StatsGrid extends StatelessWidget {
  final int total;
  final int fixed;
  final int unfixed;
  final bool isDesktop;

  const _StatsGrid({
    required this.total,
    required this.fixed,
    required this.unfixed,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(
        label: '전체 장소',
        value: total.toString(),
        icon: Icons.place_rounded,
        gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ),
      _StatCardData(
        label: '위치 확정',
        value: fixed.toString(),
        icon: Icons.check_circle_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
      ),
      _StatCardData(
        label: '위치 미확정',
        value: unfixed.toString(),
        icon: Icons.pending_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child:
          isDesktop
              ? Row(
                children:
                    cards
                        .map((c) => Expanded(child: _StatCard(data: c)))
                        .toList(),
              )
              : Column(children: cards.map((c) => _StatCard(data: c)).toList()),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              data.gradient[0].withValues(alpha: 0.08),
              data.gradient[1].withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: data.gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: data.gradient[0],
                  ),
                ),
                Text(data.label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 빠른 액션 ───
class _QuickActions extends StatelessWidget {
  final bool isDesktop;

  const _QuickActions({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        title: '장소 목록 보기',
        subtitle: '등록된 모든 장소를 확인합니다',
        icon: Icons.list_alt_rounded,
        color: const Color(0xFF3B82F6),
        route: '/locations',
      ),
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
        _ActionData(
          title: '지도에서 등록',
          subtitle: '네이버 지도에서 위치를 선택합니다',
          icon: Icons.map_rounded,
          color: const Color(0xFF10B981),
          route: '/map-picker',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child:
          isDesktop
              ? Row(
                children:
                    actions
                        .map((a) => Expanded(child: _ActionCard(data: a)))
                        .toList(),
              )
              : Column(
                children: actions.map((a) => _ActionCard(data: a)).toList(),
              ),
    );
  }
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionData data;

  const _ActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(data.route),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: data.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
