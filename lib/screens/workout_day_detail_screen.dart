import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_logo.dart';
import '../widgets/pressable_scale.dart';

class WorkoutDayDetailScreen extends StatefulWidget {
  final WorkoutDay workout;

  const WorkoutDayDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDayDetailScreen> createState() => _WorkoutDayDetailScreenState();
}

class _WorkoutDayDetailScreenState extends State<WorkoutDayDetailScreen> {
  static const double _pagePadding = 16;

  static const double _ctaHeight = 56;
  static const double _ctaGap = 16;
  static const double _ctaFade = 32;

  // Eski butonun onpayı ve yönlendirmesi birebir aynı; sadece metoda alındı.
  Future<void> _confirmAndStart() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Antrenmanı Başlat',
      message:
          '"${widget.workout.name}" antrenmanına başlamak istiyor musunuz?',
      confirmLabel: 'Başla',
    );
    if (confirmed && mounted) {
      context.push('/workout-player', extra: widget.workout);
    }
  }

  Widget _buildStartBar() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // Listenin buton arkasında keskin kesilmemesi için yumuşak geçiş.
        // IgnorePointer: bu şerit altındaki satırlara dokunmayı engellemesin.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background,
                  ],
                  stops: const [0, 0.4],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            _pagePadding,
            _ctaFade,
            _pagePadding,
            bottomInset + _ctaGap,
          ),
          child: PressableScale(
            onTap: _confirmAndStart,
            child: Container(
              height: _ctaHeight,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(_ctaHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldDeep.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 24,
                    color: AppColors.espresso,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Antrenmanı Başlat',
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  final GlobalKey _heroKey = GlobalKey();
  bool _isStatusBarLight = true;

  // Hero ekranın üstünden çıkınca saat/pil rengini koyuya çevirir.
  bool _handleScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return false;
    }
    final heroHeight = _heroKey.currentContext?.size?.height;
    if (heroHeight == null) return false;

    final isLight =
        notification.metrics.pixels <
        heroHeight - MediaQuery.paddingOf(context).top;
    if (isLight != _isStatusBarLight) {
      setState(() => _isStatusBarLight = isLight);
    }
    return false;
  }

  Widget _heroStat(String value, String label, {bool isFirst = false}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isFirst ? 0 : 14, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body12Regular.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 0.5,
      color: AppColors.onHeroDark.withValues(alpha: 0.18),
    );
  }

  Widget _buildHero() {
    final workout = widget.workout;

    final hero = Container(
      key: _heroKey,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        _pagePadding,
        MediaQuery.paddingOf(context).top + 12,
        _pagePadding,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.heroDarkStart, AppColors.heroDarkEnd],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -32,
            bottom: -44,
            child: Opacity(
              opacity: 0.06,
              child: const AppLogo(explicitSize: 190, type: AppLogoType.light),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PressableScale(
                    pressedScale: 0.92,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.onHeroDark.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.back,
                        size: 20,
                        color: AppColors.onHeroDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.16),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${workout.dayNumber}. gün',
                      style: AppTypography.body14Medium.copyWith(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                workout.name,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.onHeroDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _heroStat(
                      '${workout.exercises.length}',
                      'hareket',
                      isFirst: true,
                    ),
                    _heroDivider(),
                    _heroStat('${workout.estimatedDurationMin}', 'dk'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Aşağı çekildiğinde (bounce) hero'nun üstü açık kalmasın diye aynı
    // renkte, ekran yüksekliğinde bir blok ekliyoruz.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -MediaQuery.sizeOf(context).height,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height,
          child: const ColoredBox(color: AppColors.heroDarkStart),
        ),
        hero,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;

    final rows = <Widget>[];
    for (var i = 0; i < workout.exercises.length; i++) {
      final exercise = workout.exercises[i];

      // Süre varsa süreyi, yoksa tekrarı gösteriyoruz
      final String repsOrDuration =
          (exercise.durationSeconds != null && exercise.durationSeconds! > 0)
              ? '${exercise.durationSeconds}sn'
              : '${exercise.reps ?? ""}';

      if (i > 0) rows.add(const _RowDivider());
      rows.add(
        _ExerciseRow(
          number: i + 1,
          name: exercise.name,
          setsLabel: '${exercise.sets} × $repsOrDuration',
          // restSeconds null gelirse varsayılan 60sn
          restLabel: '${exercise.restSeconds ?? 60}sn dinlenme',
          notes: exercise.notes,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Hero durum çubuğunun arkasındayken açık, liste altına geçince koyu
        value:
            _isStatusBarLight
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ListView(
                // Son satır, butonun ve geçiş şeridinin altında kalmasın
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      _ctaHeight +
                      _ctaGap +
                      _ctaFade,
                ),
                children: [
                  _buildHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _pagePadding,
                      24,
                      _pagePadding,
                      12,
                    ),
                    child: Text(
                      'Hareketler',
                      style: AppTypography.body18Medium.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (rows.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: _pagePadding,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(children: rows),
                    ),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildStartBar()),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    // Numara karosu + boşluk kadar içeriden başlar (14 + 34 + 12)
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 60),
      color: AppColors.espresso.withValues(alpha: 0.1),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int number;
  final String name;
  final String setsLabel;
  final String restLabel;
  final String? notes;

  const _ExerciseRow({
    required this.number,
    required this.name,
    required this.setsLabel,
    required this.restLabel,
    this.notes,
  });

  static const double _tileSize = 34;
  static const double _chipHeight = 28;

  Widget _chip({
    required String label,
    required Color background,
    required Color foreground,
    IconData? icon,
    FontWeight weight = FontWeight.w400,
  }) {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body12Regular.copyWith(
                color: foreground,
                fontWeight: weight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _tileSize,
            height: _tileSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$number',
              style: AppTypography.body14Medium.copyWith(
                color: AppColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ad, karonun dikey ortasına hizalı; uzun ad iki satıra inerse
                // blok büyür ve karo ilk satırla hizalı kalır.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _tileSize),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _chip(
                        label: setsLabel,
                        background: AppColors.goldTint,
                        foreground: AppColors.espresso,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _chip(
                        label: restLabel,
                        background: AppColors.fillSubtle,
                        foreground: AppColors.textTertiary,
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                if (notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes!,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
