import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/location.dart';
import '../../data/models/menu.dart';
import '../../data/services/menu_service.dart';
import '../../providers/location_provider.dart';
import '../redesign/widgets/opus_widgets.dart';
import 'budget_logic.dart';

/// 예산 추천 화면 — 디자인 mock 의 `screen-budget` 을 Flutter 로 옮긴 것.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with SingleTickerProviderStateMixin {
  int _budget = 12000;
  late final TabController _tab = TabController(length: 2, vsync: this);

  late Future<List<MenuItem>> _menusFuture;

  @override
  void initState() {
    super.initState();
    _menusFuture = MenuService.getAllWithStats();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationListProvider);

    return Scaffold(
      backgroundColor: OpusColors.gray900,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DarkHeader(
              budget: _budget,
              onChange: (v) => setState(() => _budget = v),
              onClose: () => context.pop(),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: OpusColors.bgCanvas,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(OpusRadius.xl3),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OpusColors.gray200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    TabBar(
                      controller: _tab,
                      labelColor: OpusColors.gray900,
                      unselectedLabelColor: OpusColors.gray500,
                      indicatorColor: OpusColors.purple600,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: GoogleFonts.notoSansKr(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: GoogleFonts.notoSansKr(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: '식당별 조합'),
                        Tab(text: '단품 가성비'),
                      ],
                    ),
                    Expanded(
                      child: locationsAsync.when(
                        data: (locations) => FutureBuilder<List<MenuItem>>(
                          future: _menusFuture,
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return _Results(
                              tab: _tab,
                              budget: _budget,
                              locations: locations,
                              menus: snap.data!,
                            );
                          },
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text('식당 정보를 불러오지 못했습니다\n$e'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkHeader extends StatelessWidget {
  final int budget;
  final ValueChanged<int> onChange;
  final VoidCallback onClose;

  const _DarkHeader({
    required this.budget,
    required this.onChange,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIconBtn(
                icon: Icons.close_rounded,
                onTap: onClose,
                background: Colors.white.withValues(alpha: 0.1),
                color: Colors.white,
              ),
              const Spacer(),
              Text(
                '예산 추천',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            "오늘의 점심 예산".toUpperCase(),
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
              color: OpusColors.purple300,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _format(budget),
                style: GoogleFonts.sora(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '원',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: OpusColors.purple500,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: OpusColors.purple500.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: budget.toDouble(),
              min: 5000,
              max: 50000,
              divisions: 90,
              onChanged: (v) => onChange(v.round()),
            ),
          ),
          Row(
            children: [
              for (final v in const [8000, 12000, 15000, 20000])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PresetChip(
                    label: '${v ~/ 1000}K',
                    active: budget == v,
                    onTap: () => onChange(v),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _format(int v) => formatKrw(v); // reuse formatter
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color color;

  const _RoundIconBtn({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PresetChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OpusRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? OpusColors.purple500
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(OpusRadius.full),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  final TabController tab;
  final int budget;
  final List<Location> locations;
  final List<MenuItem> menus;

  const _Results({
    required this.tab,
    required this.budget,
    required this.locations,
    required this.menus,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final l in locations) l.id: l};
    final menusByR = <String, List<MenuItem>>{};
    for (final m in menus) {
      menusByR.putIfAbsent(m.locationId, () => <MenuItem>[]).add(m);
    }

    final combos = recommendCombos(
      restaurantsById: byId,
      menusByRestaurant: menusByR,
      budget: budget,
    );
    final values = recommendValueMenus(
      restaurantsById: byId,
      menus: menus,
      budget: budget,
    );

    return TabBarView(
      controller: tab,
      children: [
        _CombosList(combos: combos, budget: budget),
        _ValuesList(items: values, budget: budget),
      ],
    );
  }
}

class _CombosList extends StatelessWidget {
  final List<BudgetCombo> combos;
  final int budget;
  const _CombosList({required this.combos, required this.budget});

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) {
      return const _Empty(message: '예산에 맞는 조합이 없어요.\n예산을 올려보세요.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: combos.length.clamp(0, 8),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = combos[i];
        return _ComboCard(combo: c, rank: i, budget: budget);
      },
    );
  }
}

class _ComboCard extends StatelessWidget {
  final BudgetCombo combo;
  final int rank;
  final int budget;

  const _ComboCard({
    required this.combo,
    required this.rank,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final fill = (combo.total / budget * 100).clamp(0, 100).toDouble();
    final remaining = budget - combo.total;
    final isTop = rank == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OpusRadius.xl2),
        border: Border.all(
          color: isTop ? OpusColors.purple500 : OpusColors.gray100,
          width: isTop ? 2 : 1,
        ),
        boxShadow: isTop
            ? [
                const BoxShadow(
                  color: Color(0x1F6941C6),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                )
              ]
            : OpusShadow.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (rank == 0)
                      const OpusBadge(
                        text: 'BEST · 가성비 1위',
                        variant: BadgeVariant.primary,
                        dot: true,
                      )
                    else if (rank == 1)
                      const OpusBadge(
                        text: '추천',
                        variant: BadgeVariant.warning,
                        dot: true,
                      ),
                    const Spacer(),
                    Text(
                      '#${rank + 1}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: OpusColors.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: OpusColors.category(
                            combo.restaurant.category ?? ''),
                        borderRadius: BorderRadius.circular(OpusRadius.xl),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        combo.restaurant.name.characters.first,
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
                              CategoryDot(
                                  categoryKey: combo.restaurant.category,
                                  size: 6),
                              const SizedBox(width: 6),
                              Text(
                                OpusColors.categoryLabel(
                                    combo.restaurant.category ?? ''),
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 11,
                                  color: OpusColors.gray500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            combo.restaurant.name,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OpusColors.gray900,
                            ),
                          ),
                          if (combo.avgRating > 0) ...[
                            const SizedBox(height: 2),
                            StarsView(value: combo.avgRating, size: 11),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in combo.menus)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: OpusColors.purple50,
                          borderRadius: BorderRadius.circular(OpusRadius.lg),
                          border: Border.all(color: OpusColors.purple100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.name,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: OpusColors.purple700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PriceText(
                                won: m.price,
                                size: 11,
                                color: OpusColors.purple800),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: OpusColors.gray25,
              border: Border(top: BorderSide(color: OpusColors.gray100)),
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(OpusRadius.xl2)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '합계  ',
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: OpusColors.gray500,
                      ),
                    ),
                    Text(
                      '₩${formatKrw(combo.total)}',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: OpusColors.gray900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '잔액 ',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: OpusColors.gray500,
                      ),
                    ),
                    Text(
                      '₩${formatKrw(remaining)}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: remaining < 1000
                            ? OpusColors.green700
                            : OpusColors.gray700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(height: 6, color: OpusColors.gray100),
                    FractionallySizedBox(
                      widthFactor: fill / 100,
                      child: Container(
                        height: 6,
                        color: fill > 95
                            ? OpusColors.green500
                            : OpusColors.purple500,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0',
                        style: GoogleFonts.robotoMono(
                            fontSize: 10, color: OpusColors.gray400)),
                    Text('${fill.toStringAsFixed(0)}% 사용',
                        style: GoogleFonts.robotoMono(
                            fontSize: 10, color: OpusColors.gray400)),
                    Text('₩${formatKrw(budget)}',
                        style: GoogleFonts.robotoMono(
                            fontSize: 10, color: OpusColors.gray400)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuesList extends StatelessWidget {
  final List<ValuePick> items;
  final int budget;
  const _ValuesList({required this.items, required this.budget});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(message: '예산에 맞는 메뉴가 없어요.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
      itemCount: items.length.clamp(0, 12),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final it = items[i];
        final remaining = budget - it.menu.price;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(OpusRadius.xl),
            border: Border.all(color: OpusColors.gray100),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: i < 3 ? OpusColors.purple50 : OpusColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: i < 3 ? OpusColors.purple700 : OpusColors.gray500,
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
                        CategoryDot(
                            categoryKey: it.restaurant.category, size: 6),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            it.restaurant.name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              color: OpusColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      it.menu.name,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OpusColors.gray900,
                      ),
                    ),
                    if (it.menu.avgStars > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            StarsView(
                                value: it.menu.avgStars,
                                size: 10,
                                showNum: false),
                            const SizedBox(width: 6),
                            Text(
                              '· 가성비 ${it.value.toStringAsFixed(1)}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 10,
                                color: OpusColors.gray400,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PriceText(won: it.menu.price, size: 15),
                  const SizedBox(height: 2),
                  Text(
                    '-₩${formatKrw(remaining)} 남음',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: OpusColors.green700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 40, color: OpusColors.gray300),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OpusColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
