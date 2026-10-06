import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_confirm_dialog.dart';
import '../models/program.dart';
import '../models/set_log.dart';
import '../services/exercise_log_repository.dart';
import 'package:shimmer/shimmer.dart';
import '../models/workout_history.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import 'workouts_screen.dart'; // workoutRefreshNotifier'ı kullanabilmek için
import '../widgets/detail_hero.dart' show HeroStatusBarScope;
import '../widgets/exercise_timer_widget.dart';
import '../widgets/kiremit_hero_surface.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/reveal.dart';
import '../widgets/series_wordmark.dart';
import '../utils/exercise_name.dart';
import 'package:audioplayers/audioplayers.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutDay workout;

  const WorkoutSessionScreen({super.key, required this.workout});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _exerciseIndex = 0;
  int _setIndex = 0;
  bool _isResting = false;
  bool _isFinishing = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _restTotalSeconds = 1;
  int _elapsedSeconds = 0;
  Timer? _restTimer;
  Timer? _elapsedTimer;

  // yeni:
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final List<SetLog> _logs = [];
  Map<String, LoggedSet> _lastPerformance = {};
  final ExerciseService _exerciseService = ExerciseService();
  Exercise? _apiExerciseInfo;
  bool _isLoadingGif = false;

  // Ses oynatıcıları
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _playBell() async {
    // Aynı anda birden fazla tetiklenirse sesi baştan başlatır
    await _audioPlayer.play(
      AssetSource('sounds/bell.mp3'),
      mode: PlayerMode.lowLatency,
    );
  }

  void _playFinish() async {
    await _audioPlayer.play(
      AssetSource('sounds/finish.mp3'),
      mode: PlayerMode.lowLatency,
    );
  }

  WorkoutExercise get _currentExercise =>
      widget.workout.exercises[_exerciseIndex];

  int _getExerciseDuration(WorkoutExercise exercise) {
    // 1. Doğrudan durationSeconds varsa
    if (exercise.durationSeconds != null && exercise.durationSeconds! > 0) {
      return exercise.durationSeconds!;
    }

    // 2. Reps metninde süre geçiyorsa
    final repsText = exercise.reps?.toString().toLowerCase() ?? '';
    if (repsText.contains('sn') ||
        repsText.contains('sec') ||
        repsText.contains('saniye') ||
        repsText.contains('s')) {
      final match = RegExp(r'\d+').firstMatch(repsText);
      return match != null
          ? int.parse(match.group(0)!)
          : 30; // Sayı bulunamazsa varsayılan 30 sn
    } else if (repsText.contains('dk') ||
        repsText.contains('min') ||
        repsText.contains('dakika')) {
      final match = RegExp(r'\d+').firstMatch(repsText);
      return match != null ? int.parse(match.group(0)!) * 60 : 60;
    }

    // 3. Eğer hareketin adında (name) "plank" veya "hold" geçiyor ama süre belirtilmemişse varsayılan 30 sn verelim ki timer çıksın
    final nameLower = exercise.name.toLowerCase();
    if (nameLower.contains('plank') ||
        nameLower.contains('hold') ||
        nameLower.contains('static')) {
      return 30;
    }

    return 0;
  }

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) setState(() => _elapsedSeconds++);
    });
    _fetchLastPerformance();
    _fetchCurrentExerciseGif();
    _playBell();
  }

  Future<void> _fetchCurrentExerciseGif() async {
    // İstek başlamadan önce eski bilgiyi temizle ve yükleniyor bayrağını aç
    if (mounted) {
      setState(() {
        _isLoadingGif = true;
        _apiExerciseInfo = null;
      });
    }

    try {
      final apiData = await _exerciseService.fetchExerciseById(
        _currentExercise.id,
      );

      // İstek sonuçlandığında widget hala ekrandaysa (mounted) güncelle
      if (mounted) {
        setState(() {
          _apiExerciseInfo = apiData;
          _isLoadingGif = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGif = false;
        });
      }
      debugPrint('GIF Çekme Hatası: $e');
    }
  }

  Future<void> _fetchLastPerformance() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final performance = await ExerciseLogRepository.fetchLastPerformance(
        userId: user.id,
        exerciseNames: widget.workout.exercises.map((e) => e.name).toList(),
      );
      if (mounted) setState(() => _lastPerformance = performance);
    } catch (error) {
      debugPrint('Önceki performans çekme hatası: $error');
      // Sessizce geçiyoruz — bu tamamen opsiyonel bir bilgi, hata olursa
      // input'lar sadece varsayılan "Tekrar"/"Ağırlık" placeholder'ını
      // gösterir, antrenman akışını hiçbir şekilde engellemez.
    }
  }

  Future<void> _handleExitConfirm() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Antrenmandan Çık',
      message:
          'Antrenmanı sonlandırmak istediğine emin misin? Kaydedilmemiş setler kaybolabilir.',
      confirmLabel: 'Çık',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showExerciseListSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottomSafe = MediaQuery.paddingOf(context).bottom;
        final exercises = widget.workout.exercises;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Çekme çubuğu (drag handle)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(45),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Antrenman Akışı',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 24),
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = _FlowRow(
                      name: formatExerciseName(exercises[index].name),
                      detail:
                          '${exercises[index].sets} Set x ${exercises[index].reps}',
                      number: index + 1,
                      isCompleted: index < _exerciseIndex,
                      isCurrent: index == _exerciseIndex,
                      onTap: () => Navigator.pop(context),
                    );
                    if (index >= 6) return row;
                    return Reveal(
                      delay: const Duration(milliseconds: 50) * index,
                      duration: const Duration(milliseconds: 400),
                      offsetY: 10,
                      child: row,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _confirmSet() {
    if (_isPaused) return;
    _playBell();
    // 1. Varsayılan tekrar sayısını bul (Programdaki hedeften al)
    int defaultReps = 1;
    final repsStr = _currentExercise.reps.toString();
    final match = RegExp(r'\d+').firstMatch(repsStr);
    if (match != null) {
      defaultReps = int.tryParse(match.group(0)!) ?? 1;
    }

    double defaultWeight = 0.0;

    // 2. Geçmiş performans varsa öncelikle onu varsayılan yap
    if (_lastPerformanceForCurrentSet != null) {
      if (_lastPerformanceForCurrentSet!.repsPerformed > 0) {
        defaultReps = _lastPerformanceForCurrentSet!.repsPerformed;
      }
      defaultWeight = _lastPerformanceForCurrentSet!.weightUsed;
    }

    // 3. Kullanıcı girdilerini temizle ve formata uygun hale getir
    final inputReps = _repsController.text.trim();
    final inputWeight = _weightController.text.trim().replaceAll(',', '.');

    // 4. Kutu boşsa varsayılanı, doluysa girilen değeri al (en az 1 tekrar garantile)
    final parsedReps = int.tryParse(inputReps);
    final reps =
        inputReps.isEmpty
            ? defaultReps
            : ((parsedReps != null && parsedReps > 0)
                ? parsedReps
                : defaultReps);

    final parsedWeight = double.tryParse(inputWeight);
    final weight =
        inputWeight.isEmpty ? defaultWeight : (parsedWeight ?? defaultWeight);

    _logs.add(
      SetLog(
        exerciseName: _currentExercise.name,
        setNumber: _setIndex + 1,
        repsPerformed: reps,
        weightUsed: weight,
      ),
    );

    final justFinished = _currentExercise;
    _repsController.clear();
    _weightController.clear();

    if (_setIndex + 1 < justFinished.sets) {
      setState(() => _setIndex++);
      // EĞER REST SECONDS BOŞ GELİRSE VARSAYILAN OLARAK 60 SANİYE MOLA VER
      _startRest(justFinished.restSeconds ?? 60);
    } else if (_exerciseIndex + 1 < widget.workout.exercises.length) {
      setState(() {
        _exerciseIndex++;
        _setIndex = 0;
        _apiExerciseInfo = null;
      });
      // BURAYA DA ?? 60 EKLİYORUZ
      _startRest(justFinished.restSeconds ?? 60);
      _fetchCurrentExerciseGif();
    } else {
      _finishWorkout();
    }
  }

  void _startRest(int seconds) {
    final duration = seconds > 0 ? seconds : 30;
    _restTimer?.cancel();
    _playBell();
    setState(() {
      _isResting = true;
      _remainingSeconds = duration;
      _restTotalSeconds = duration;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isResting = false;
          _remainingSeconds = 0;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _playBell();
    setState(() => _isResting = false);
  }

  void _goToExercise(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.workout.exercises.length) return;
    _restTimer?.cancel();

    setState(() {
      _exerciseIndex = newIndex;
      _setIndex = 0;
      _isResting = false;
      _repsController.clear();
      _weightController.clear();
      _apiExerciseInfo = null; // Önceki hareketin bilgisini sıfırla
      _isLoadingGif = true; // Yükleniyor durumunu tetikle
    });

    // Hemen ardından yeni hareketin verisini çek
    _fetchCurrentExerciseGif();
  }

  Future<void> _handleFinishTap() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Antrenmanı Bitir',
      message:
          'Antrenmanı şimdi sonlandırmak istediğine emin misin? Şu ana kadarki setler kaydedilecek.',
      confirmLabel: 'Bitir',
      isDestructive: true,
    );
    if (confirmed) _finishWorkout();
  }

  Future<void> _finishWorkout() async {
    _restTimer?.cancel();

    _elapsedTimer?.cancel();
    _playFinish();
    setState(() => _isFinishing = true);
    final user = Supabase.instance.client.auth.currentUser;
    bool success = false;

    if (user != null) {
      try {
        await ExerciseLogRepository.saveSessionLogs(
          userId: user.id,
          workoutId: widget.workout.id,
          workoutName: widget.workout.name,
          logs: _logs,
          durationSeconds: _elapsedSeconds,
        );
        success = true;
      } catch (error) {
        debugPrint('Set logları kaydedilemedi: $error');
      }
    }

    if (!mounted) return;
    if (success) {
      // YENİ EKLENEN SATIR: WorkoutsScreen'e "verileri yenile" sinyali gönder
      workoutRefreshNotifier.value = !workoutRefreshNotifier.value;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Harika iş! Antrenman başarıyla kaydedildi.',
                  style: AppTypography.body14Medium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    context.go('/workouts');
  }

  String _formatWeight(double weight) {
    return weight % 1 == 0 ? weight.toInt().toString() : weight.toString();
  }

  LoggedSet? get _lastPerformanceForCurrentSet =>
      _lastPerformance['${_currentExercise.name}|${_setIndex + 1}'];

  String _nextPreviewLabel() {
    // Mola ekranındayken _exerciseIndex ve _setIndex zaten BİR SONRAKİ
    // değere güncellenmiş durumda. Bu yüzden moladayken direkt "şu anki"
    // state'i (yani sıradaki hedefi) ekrana yazdırıyoruz.
    if (_isResting) {
      return '${formatExerciseName(_currentExercise.name)} · Set ${_setIndex + 1}/${_currentExercise.sets}';
    }

    // Egzersiz ekranındayken (molada değilken) standart "sıradaki" hesaplaması:
    if (_setIndex + 1 < _currentExercise.sets) {
      return '${formatExerciseName(_currentExercise.name)} · Set ${_setIndex + 2}/${_currentExercise.sets}';
    }
    if (_exerciseIndex + 1 < widget.workout.exercises.length) {
      return formatExerciseName(
        widget.workout.exercises[_exerciseIndex + 1].name,
      );
    }
    return 'Son hareket';
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinishing) {
      return Scaffold(
        backgroundColor: AppColors.homeHeroDeep,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _RestBackground(),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder:
                      (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 12),
                          child: child,
                        ),
                      ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SeriesWordmark(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: AppColors.accentGold,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Antrenman kaydediliyor...',
                        style: AppTypography.body16Medium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleExitConfirm();
      },
      child: GestureDetector(
        // Soldan sağa doğru parmak kaydırma hareketini (Swipe-to-back) yakalar
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 250) {
            _handleExitConfirm();
          }
        },
        // Hareket ↔ mola geçişi: 350ms crossfade (eskiden anında değişiyordu).
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(_isResting),
            child: _isResting ? _buildRestView() : _buildExerciseView(),
          ),
        ),
      ),
    );
  }

  // --- Hareket ekranı (kiremit hero + krem kart) ---
  static const double _pagePadding = 20;
  static const double _gifHeight = 200;
  // GIF kartının kiremit hero'nun üstüne taşan kısmı.
  static const double _gifOverlap = 56;
  static const double _ctaHeight = 64;
  static const double _chevronSize = 52;
  // Hero altı, GIF, set bloğu, kutular ve "Sıradaki" arasındaki eşit boşluk.
  static const double _sectionGap = 24;
  // Dock'un ekran altından (güvenli alan üstünden) uzaklığı.
  static const double _dockBottomGap = 12;
  // "Sıradaki" satırı ile butonlar arası.
  static const double _nextToDockGap = 14;

  Widget _buildExerciseView() {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: HeroStatusBarScope(
        // Yapı klavye açılıp kapanınca değişmez (Expanded + isteğe bağlı son
        // çocuk); aksi halde tekrar/ağırlık kutuları yeniden kurulup odağı
        // kaybeder ve klavye kapanırdı.
        builder:
            (context, heroKey) => Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildExerciseHero(heroKey, keyboardOpen),
                            // Klavye açıkken GIF kartı küçülüp kaybolur: tekrar/ağırlık
                            // kutuları ve altın buton klavyenin üstünde sığsın.
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              clipBehavior: Clip.none,
                              child:
                                  keyboardOpen
                                      ? const SizedBox(width: double.infinity)
                                      : _buildGifCard(),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _pagePadding,
                                _sectionGap,
                                _pagePadding,
                                0,
                              ),
                              child: _buildSetArea(),
                            ),
                          ],
                        ),
                      ),
                      // Kalan alanı doldurur: "Sıradaki" + butonlar grubu, içerik
                      // ile ekran altı arasında dikey olarak ortalanır. İçerik
                      // uzunsa (küçük ekran) aşağıda kaydırılır. Klavye açıkken
                      // grup aşağıdaki sabit alana geçer.
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child:
                            keyboardOpen
                                ? const SizedBox.shrink()
                                : Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    _pagePadding,
                                    _sectionGap,
                                    _pagePadding,
                                    bottomSafe,
                                  ),
                                  child: Center(child: _buildBottomGroup()),
                                ),
                      ),
                    ],
                  ),
                ),
                if (keyboardOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _pagePadding,
                      12,
                      _pagePadding,
                      _dockBottomGap,
                    ),
                    child: _buildBottomGroup(),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _buildExerciseHero(GlobalKey heroKey, bool keyboardOpen) {
    final total = widget.workout.exercises.length;
    return KiremitHeroSurface(
      heroKey: heroKey,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          MediaQuery.paddingOf(context).top + 8,
          _pagePadding,
          // GIF kartı hero'nun üstüne taştığı için altta yer ayrılır; klavyede
          // kart yok, hero daha kısa.
          keyboardOpen ? 24 : _gifOverlap + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 14),
            _buildProgressSegments(total),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'HAREKET ${_exerciseIndex + 1} / $total',
                  style: AppTypography.body12Medium.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatExerciseName(_currentExercise.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading1.copyWith(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Üç eşit sütun: süre hapı sağdaki grubun genişliğinden etkilenmeden tam ortada.
  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _GlassCircleButton(
              icon: Icons.format_list_bulleted_rounded,
              onTap: _showExerciseListSheet,
            ),
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_elapsedSeconds),
                style: AppTypography.body14Medium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassCircleButton(
                  icon:
                      _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                  onTap: _togglePause,
                ),
                PressableScale(
                  pressedScale: 0.94,
                  onTap: _handleFinishTap,
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Center(
                        child: Text(
                          'Bitir',
                          style: AppTypography.body14Medium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Hareket başına bir segment: bitenler altın dolu, mevcut hareket set
  // ilerlemesi kadar dolu.
  Widget _buildProgressSegments(int total) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: _ProgressSegment(
                fill:
                    i < _exerciseIndex
                        ? 1
                        : (i == _exerciseIndex
                            ? _setIndex / _currentExercise.sets
                            : 0),
              ),
            ),
          ),
      ],
    );
  }

  // GIF kartı: kiremit hero ile krem zeminin sınırına oturur. Align'ın
  // heightFactor'ı yerleşimde yalnızca altta kalan kısmı yer kaplatır, kartın
  // üst kısmı hero'nun üstüne taşar.
  Widget _buildGifCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: (_gifHeight - _gifOverlap) / _gifHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
        child: Container(
          height: _gifHeight,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.homeHeroDeep.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _buildGifContent(),
        ),
      ),
    );
  }

  Widget _buildGifContent() {
    // GIF yerine talimat metni (mevcut davranış)
    if (_currentExercise.instructions != null &&
        _currentExercise.instructions!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              _currentExercise.instructions!,
              textAlign: TextAlign.center,
              style: AppTypography.body14Regular.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child:
          _isLoadingGif
              ? Shimmer.fromColors(
                key: const ValueKey('gif_loading'),
                baseColor: AppColors.fillSubtle,
                highlightColor: Colors.white,
                child: Container(color: Colors.white),
              )
              : (_apiExerciseInfo == null
                  ? Center(
                    key: const ValueKey('gif_empty'),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      size: 52,
                      color: AppColors.homeHero.withValues(alpha: 0.35),
                    ),
                  )
                  : Padding(
                    key: ValueKey(_apiExerciseInfo!.gifUrl),
                    padding: const EdgeInsets.all(12),
                    child: Image.network(
                      _apiExerciseInfo!.gifUrl,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  )),
    );
  }

  Widget _buildSetArea() {
    final exercise = _currentExercise;
    final isTimed = _getExerciseDuration(exercise) > 0;
    final last = _lastPerformanceForCurrentSet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTimed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'SÜRELİ HAREKET',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Burada bağımsız timer widget'ımızı çalıştırıyoruz
                ExerciseTimerWidget(
                  durationSeconds: _getExerciseDuration(exercise),
                  onComplete: _playBell,
                ),
              ],
            ),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${_setIndex + 1}'),
                        TextSpan(
                          text: ' / ${exercise.sets}',
                          style: AppTypography.body18Medium.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.8,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SetDots(total: exercise.sets, current: _setIndex),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'hedef',
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise.sets} × ${exercise.reps}',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: _sectionGap),
          Row(
            children: [
              Expanded(
                child: _SetField(
                  label: 'TEKRAR',
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  hintText:
                      last != null
                          ? '${last.repsPerformed} (önceki)'
                          : exercise.reps.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SetField(
                  label: 'AĞIRLIK (KG)',
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hintText:
                      last != null
                          ? '${_formatWeight(last.weightUsed)} (önceki)'
                          : '0',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // "Sıradaki" bilgisi dock'un hemen üstünde: alt aksiyon grubunun parçası.
  Widget _buildNextRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Sıradaki:',
          style: AppTypography.body14Regular.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            _nextPreviewLabel(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTypography.body14Medium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // "Sıradaki" satırı + iki chevron dairesi ve ortada esneyen altın "Seti
  // Tamamla" butonu; butonlar aynı dikey eksende.
  Widget _buildBottomGroup() {
    final canGoPrev = _exerciseIndex > 0;
    final canGoNext = _exerciseIndex < widget.workout.exercises.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNextRow(),
        const SizedBox(height: _nextToDockGap),
        Row(
          children: [
            _DockChevron(
              icon: Icons.chevron_left_rounded,
              size: _chevronSize,
              onTap: canGoPrev ? () => _goToExercise(_exerciseIndex - 1) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SetCta(
                height: _ctaHeight,
                onTap:
                    _isPaused
                        ? null
                        : () {
                          HapticFeedback.mediumImpact();
                          _confirmSet();
                        },
              ),
            ),
            const SizedBox(width: 10),
            _DockChevron(
              icon: Icons.chevron_right_rounded,
              size: _chevronSize,
              onTap: canGoNext ? () => _goToExercise(_exerciseIndex + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  // --- Mola ekranı: tam kiremit zemin, altın halka, geri sayım ---
  static const double _restRingSize = 236;
  static const double _restRingStroke = 16;

  Widget _buildRestView() {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final total = _restTotalSeconds == 0 ? 1 : _restTotalSeconds;
    // Halka her saniye bir sonraki saniyenin değerine doğru 1 sn boyunca akar
    // (sayı ile birlikte kesintisiz küçülür); duraklatılınca olduğu yerde kalır.
    final ringTarget =
        (_isPaused ? _remainingSeconds : math.max(0, _remainingSeconds - 1)) /
        total;
    final canGoPrev = _exerciseIndex > 0;
    final canGoNext = _exerciseIndex < widget.workout.exercises.length - 1;

    return Scaffold(
      backgroundColor: AppColors.homeHeroDeep,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _RestBackground(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _pagePadding,
                      8,
                      _pagePadding,
                      0,
                    ),
                    child: _buildTopBar(),
                  ),
                  // Süre hapının hemen altında ortalı "SERIES" wordmark'ı.
                  const SizedBox(height: 10),
                  SeriesWordmark(color: Colors.white.withValues(alpha: 0.9)),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _restRingSize,
                              height: _restRingSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: _restRingSize * 0.8,
                                    height: _restRingSize * 0.8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accentGold
                                              .withValues(alpha: 0.22),
                                          blurRadius: 60,
                                          spreadRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(end: ringTarget),
                                    duration:
                                        _isPaused
                                            ? const Duration(milliseconds: 250)
                                            : const Duration(seconds: 1),
                                    curve: Curves.linear,
                                    builder:
                                        (context, value, _) => CustomPaint(
                                          size: const Size.square(
                                            _restRingSize,
                                          ),
                                          painter: _RestRingPainter(
                                            progress: value,
                                            strokeWidth: _restRingStroke,
                                          ),
                                        ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'MOLA',
                                        style: AppTypography.body12Medium
                                            .copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              letterSpacing: 3,
                                              height: 1,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        transitionBuilder:
                                            (child, animation) =>
                                                FadeTransition(
                                                  opacity: animation,
                                                  child: SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: const Offset(
                                                        0,
                                                        0.12,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(animation),
                                                    child: child,
                                                  ),
                                                ),
                                        child: Text(
                                          '$_remainingSeconds',
                                          key: ValueKey(_remainingSeconds),
                                          style: AppTypography.heading1
                                              .copyWith(
                                                color: Colors.white,
                                                fontSize: 88,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -4,
                                                height: 1,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _pagePadding,
                              ),
                              child: _buildRestNextCard(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _pagePadding,
                      12,
                      _pagePadding,
                      _dockBottomGap + (bottomSafe > 0 ? 0 : 8),
                    ),
                    child: Row(
                      children: [
                        _DockChevron(
                          icon: Icons.chevron_left_rounded,
                          size: _chevronSize,
                          glass: true,
                          onTap:
                              canGoPrev
                                  ? () => _goToExercise(_exerciseIndex - 1)
                                  : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _SkipRestButton(onTap: _skipRest)),
                        const SizedBox(width: 10),
                        _DockChevron(
                          icon: Icons.chevron_right_rounded,
                          size: _chevronSize,
                          glass: true,
                          onTap:
                              canGoNext
                                  ? () => _goToExercise(_exerciseIndex + 1)
                                  : null,
                        ),
                      ],
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

  // Mola sırasında _exerciseIndex/_setIndex zaten BİR SONRAKİ hedefi gösterir
  // (bkz. _nextPreviewLabel); kartta aynı bilgi iki satırda sunuluyor.
  Widget _buildRestNextCard() {
    final exercise = _currentExercise;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                _apiExerciseInfo == null
                    ? Icon(
                      Icons.fitness_center_rounded,
                      size: 24,
                      color: AppColors.homeHero.withValues(alpha: 0.5),
                    )
                    : Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.network(
                        _apiExerciseInfo!.gifUrl,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SIRADAKİ',
                  style: AppTypography.body12Medium.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    letterSpacing: 1.6,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatExerciseName(exercise.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body16Medium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Set ${_setIndex + 1}/${exercise.sets}',
                  style: AppTypography.body12Regular.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
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

/// Mola ekranı zemini: kiremit dikey gradyan ve sağ üstten ışık.
class _RestBackground extends StatelessWidget {
  const _RestBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.homeHero, AppColors.homeHeroDeep],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, -0.9),
              radius: 1.3,
              colors: [
                AppColors.homeHeroGlow,
                AppColors.homeHeroGlow.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RestRingPainter extends CustomPainter {
  final double progress; // 0..1 kalan
  final double strokeWidth;

  _RestRingPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = AppColors.accentGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RestRingPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}

class _SkipRestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipRestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
        ),
        child: Text(
          'Molayı Atla',
          style: AppTypography.body16Medium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Hero üzerindeki 44px yarı saydam beyaz daire buton.
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.92,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final double fill;

  const _ProgressSegment({required this.fill});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fill.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              color: Colors.white.withValues(alpha: 0.2),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: const ColoredBox(color: AppColors.accentGold),
              ),
            ),
          ),
    );
  }
}

/// Set göstergesi: bitenler ve mevcut set kiremit dolu, kalanlar silik.
class _SetDots extends StatelessWidget {
  final int total;
  final int current;

  const _SetDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color:
                    i <= current ? AppColors.homeHero : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tekrar / ağırlık kutusu: beyaz kart, üstte küçük etiket, altta büyük rakam.
/// Odakta çerçeve kiremit olur.
class _SetField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hintText;

  const _SetField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.hintText,
  });

  @override
  State<_SetField> createState() => _SetFieldState();
}

class _SetFieldState extends State<_SetField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: focused ? AppColors.homeHero : AppColors.borderSubtle,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  focused
                      ? AppColors.homeHero.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
              blurRadius: focused ? 16 : 8,
              offset: Offset(0, focused ? 6 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: AppTypography.body12Medium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
                letterSpacing: 1.2,
                height: 1,
              ),
            ),
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              textAlign: TextAlign.center,
              cursorColor: AppColors.homeHero,
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTypography.body14Medium.copyWith(
                  color: AppColors.textTertiary.withValues(alpha: 0.7),
                  height: 1,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockChevron extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  /// Koyu (kiremit) zeminde yarı saydam beyaz daire; false iken beyaz daire.
  final bool glass;

  const _DockChevron({
    required this.icon,
    required this.size,
    required this.onTap,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PressableScale(
        pressedScale: 0.92,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: glass ? Colors.white.withValues(alpha: 0.14) : Colors.white,
            shape: BoxShape.circle,
            boxShadow:
                glass
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          child: Icon(
            icon,
            size: 28,
            color: glass ? Colors.white : AppColors.homeHero,
          ),
        ),
      ),
    );
  }
}

/// Ana eylem: altın "Seti Tamamla" pill'i. Duraklatıldığında soluk ve basılamaz.
class _SetCta extends StatelessWidget {
  final double height;
  final VoidCallback? onTap;

  const _SetCta({required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: PressableScale(
        pressedScale: 0.97,
        haptics: false,
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEDC36C), AppColors.accentGold],
            ),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGold.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_rounded,
                size: 26,
                color: AppColors.espresso,
              ),
              const SizedBox(width: 8),
              Text(
                'Seti Tamamla',
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Antrenman Akışı" listesindeki satır: biten hareket kiremit onaylı ve soluk,
/// mevcut hareket kiremit vurgulu ve "Şu an" etiketli, kalanlar nötr.
class _FlowRow extends StatelessWidget {
  final String name;
  final String detail;
  final int number;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback onTap;

  const _FlowRow({
    required this.name,
    required this.detail,
    required this.number,
    required this.isCompleted,
    required this.isCurrent,
    required this.onTap,
  });

  static const double _radius = 20;
  static const double _badge = 40;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Seçim çerçevesi layout'u kaydırmasın diye hep var; yalnızca mevcut
        // harekette görünür.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: isCurrent ? AppColors.homeHero : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _badge,
              height: _badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient:
                    isCurrent
                        ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
                        )
                        : null,
                color:
                    isCurrent
                        ? null
                        : (isCompleted
                            ? AppColors.workoutsTint
                            : AppColors.fillSubtle),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  isCompleted
                      ? const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppColors.success,
                      )
                      : Text(
                        '$number',
                        style: AppTypography.body14Medium.copyWith(
                          color:
                              isCurrent ? Colors.white : AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: isCompleted ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: AppTypography.body12Regular.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Şu an',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
