import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
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
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Çekme Çubuğu (Drag Handle)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(45),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Antrenman Akışı',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Liste
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount:
                      widget
                          .workout
                          .exercises
                          .length, // widget.workout içinden çekiyoruz
                  itemBuilder: (context, index) {
                    final exercise = widget.workout.exercises[index];
                    final isCompleted = index < _exerciseIndex;
                    final isCurrent = index == _exerciseIndex;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isCompleted
                                  ? AppColors.brandPrimary
                                  : (isCurrent
                                      ? AppColors.brandTertiary
                                      : Colors.grey.shade200),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.fitness_center,
                          size: 16,
                          color:
                              isCompleted || isCurrent
                                  ? Colors.white
                                  : Colors.grey.shade500,
                        ),
                      ),
                      title: Text(
                        formatExerciseName(exercise.name), // Hareketin ismi
                        style: AppTypography.body16Medium.copyWith(
                          color:
                              isCompleted
                                  ? Colors.grey.shade400
                                  : AppColors.textPrimary,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        '${exercise.sets} Set x ${exercise.reps}', // Set ve tekrar sayıları
                        style: AppTypography.body14Regular.copyWith(
                          color: Colors.grey.shade400,
                        ),
                      ),
                      trailing:
                          isCurrent
                              ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandTertiary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Şu an',
                                  style: AppTypography.body12Medium.copyWith(
                                    color: AppColors.brandTertiary,
                                  ),
                                ),
                              )
                              : null,
                      onTap: () => Navigator.pop(context),
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

  Widget _buildSessionBar(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Sol Taraf: Liste İkonu ve Timer
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _showExerciseListSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36),
                icon: Icon(Icons.format_list_bulleted, size: 24, color: color),
              ),
              const SizedBox(width: 4),
              Icon(Icons.timer_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_elapsedSeconds),
                style: AppTypography.body14Medium.copyWith(color: color),
              ),
            ],
          ),
        ),

        // Orta: Logo
        const AppLogo(explicitSize: 56, type: AppLogoType.dark),

        // Sağ Taraf: Duraklat ve Bitir
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: color,
                  size: 22,
                ),
              ),
              TextButton(
                onPressed: _handleFinishTap,
                child: Text(
                  'Bitir',
                  style: AppTypography.body14Medium.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinishing) {
      return Scaffold(
        backgroundColor: AppColors.brandPrimary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Antrenman kaydediliyor...',
                style: AppTypography.body16Medium.copyWith(color: Colors.white),
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
        child: _isResting ? _buildRestView() : _buildExerciseView(),
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

  Widget _buildExerciseView() {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: HeroStatusBarScope(
        builder:
            (context, heroKey) => Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: _ctaHeight + bottomSafe + 56,
                  ),
                  child: Column(
                    children: [
                      _buildExerciseHero(heroKey),
                      _buildGifCard(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _pagePadding,
                          20,
                          _pagePadding,
                          0,
                        ),
                        child: _buildSetArea(),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildDock(bottomSafe),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildExerciseHero(GlobalKey heroKey) {
    final total = widget.workout.exercises.length;
    return KiremitHeroSurface(
      heroKey: heroKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          MediaQuery.paddingOf(context).top + 8,
          _pagePadding,
          _gifOverlap + 24,
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
          const SizedBox(height: 18),
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
        const SizedBox(height: 20),
        Row(
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
        ),
      ],
    );
  }

  // Alt dock: iki chevron dairesi ve ortada esneyen altın "Seti Tamamla"
  // butonu; üç eleman aynı dikey eksende. Arkasında listenin kesik görünmemesi
  // için yumuşak geçiş.
  Widget _buildDock(double bottomSafe) {
    final canGoPrev = _exerciseIndex > 0;
    final canGoNext = _exerciseIndex < widget.workout.exercises.length - 1;

    return DecoratedBox(
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          32,
          _pagePadding,
          bottomSafe + 16,
        ),
        child: Row(
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
      ),
    );
  }

  Widget _buildRestView() {
    final progress =
        _restTotalSeconds == 0 ? 0.0 : _remainingSeconds / _restTotalSeconds;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildSessionBar(AppColors.brandTertiary),
                const SizedBox(height: 24),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.15),
                        blurRadius: 14.667,
                        spreadRadius: 3.667,
                        offset: const Offset(2.2, 2.2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(26),
                  child: const AppLogo(
                    size: AppLogoSize.medium,
                    type: AppLogoType.dark,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'MOLA',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.brandPrimary,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 230,
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 230,
                        height: 230,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 18,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brandPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$_remainingSeconds',
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.brandPrimary,
                          fontSize: 60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kalan Süre',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sıradaki: ${_nextPreviewLabel()}',
                  textAlign: TextAlign.center,
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _skipRest,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.brandTertiary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Molayı Atla',
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.brandTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed:
                          _exerciseIndex > 0
                              ? () => _goToExercise(_exerciseIndex - 1)
                              : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: AppColors.brandSecondary,
                        size: 48,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _exerciseIndex < widget.workout.exercises.length - 1
                              ? () => _goToExercise(_exerciseIndex + 1)
                              : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: AppColors.brandSecondary,
                        size: 48,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
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

  const _DockChevron({
    required this.icon,
    required this.size,
    required this.onTap,
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
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 28, color: AppColors.homeHero),
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
