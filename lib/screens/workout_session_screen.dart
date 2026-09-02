import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_confirm_dialog.dart';
import '../models/program.dart';
import '../models/set_log.dart';
import '../services/exercise_log_repository.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/workout_history.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';

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

  WorkoutExercise get _currentExercise =>
      widget.workout.exercises[_exerciseIndex];

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) setState(() => _elapsedSeconds++);
    });
    _fetchLastPerformance();
    _fetchCurrentExerciseGif();
  }

  Future<void> _fetchCurrentExerciseGif() async {
    setState(() => _isLoadingGif = true);
    try {
      // YENİ: İsim ve talimat kelimelerini karşılaştırarak nokta atışı çeken metot
      final apiData = await _exerciseService.fetchExerciseById(
        _currentExercise.id,
      );

      if (mounted) {
        setState(() {
          _apiExerciseInfo = apiData;
          _isLoadingGif = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGif = false);
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

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _confirmSet() {
    if (_isPaused) return;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;

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
      _startRest(justFinished.restSeconds);
    } else if (_exerciseIndex + 1 < widget.workout.exercises.length) {
      setState(() {
        _exerciseIndex++;
        _setIndex = 0;
        _apiExerciseInfo = null; // YENİ EKLENDİ: Eski görseli ekrandan kaldır
      });
      _startRest(justFinished.restSeconds);
      _fetchCurrentExerciseGif(); // YENİ EKLENDİ: Arka planda yeni görseli çekmeye başla
    } else {
      _finishWorkout();
    }
  }

  void _startRest(int seconds) {
    final duration = seconds > 0 ? seconds : 30;
    _restTimer?.cancel();
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
      // YENİ EKLENEN SATIR: Yeni harekete geçerken eski hareketin GIF'ini ekrandan temizle
      _apiExerciseInfo = null;
    });

    // YENİ EKLENEN SATIR: State güncellendikten hemen sonra yeni hareketin GIF'ini API'den çek
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
        );
        success = true;
      } catch (error) {
        debugPrint('Set logları kaydedilemedi: $error');
      }
    }

    if (!mounted) return;

    if (success) {
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
    if (_setIndex + 1 < _currentExercise.sets) {
      return '${_currentExercise.name} · Set ${_setIndex + 2}/${_currentExercise.sets}';
    }
    if (_exerciseIndex + 1 < widget.workout.exercises.length) {
      return widget.workout.exercises[_exerciseIndex + 1].name;
    }
    return 'Son hareket';
  }

  Widget _buildSessionBar(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Sol Taraf: Timer
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_elapsedSeconds),
                style: AppTypography.body14Medium.copyWith(color: color),
              ),
            ],
          ),
        ),

        // Orta: Logo (Eğer kırmızının üstüne beyaz gelmesini istiyorsan type'ı light yap)
        const AppLogo(
          explicitSize: 56, // Varsa minimal bir boyut tercih et
          type: AppLogoType.dark,
        ),

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

  Widget _buildExerciseView() {
    return Scaffold(
      backgroundColor: AppColors.textSecondary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // 1. ÜST BAR (Timer ve Bitir Butonu)
                _buildSessionBar(Colors.white),
                const SizedBox(height: 16),

                // 2. ÜST BEYAZ KART (Hareket Adı ve 180x180 GIF Alanı)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentExercise.name.toUpperCase(),
                        style: AppTypography.heading2.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // 180x180 Sabit GIF / Yüklenme Alanı
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(
                          child:
                              _isLoadingGif
                                  ? const CircularProgressIndicator(
                                    color: AppColors.brandPrimary,
                                  )
                                  : (_apiExerciseInfo == null
                                      ? Icon(
                                        Icons.fitness_center,
                                        size: 50,
                                        color: Colors.grey[400],
                                      )
                                      : ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _apiExerciseInfo!.gifUrl,
                                          width: 180,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.brandPrimary,
                                              ),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            debugPrint('❌ GIF Hatası: $error');
                                            return Icon(
                                              Icons.broken_image,
                                              size: 50,
                                              color: Colors.grey[400],
                                            );
                                          },
                                        ),
                                      )),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. ALT BEYAZ KART (Set, Bilgi ve Düzgün Hizalanmış Inputlar)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst Satır: Set Bilgisi ve Set/Tekrar Özeti
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Sol Taraf: Set: 1/3
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set:',
                                style: AppTypography.body14Regular.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_setIndex + 1}/${_currentExercise.sets}',
                                style: AppTypography.heading1.copyWith(
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            width: 12,
                          ), // İki alan arasına güvenlik boşluğu
                          // Sağ Taraf: Uzun gelirse alt satıra geçecek olan metin
                          Expanded(
                            child: Text(
                              '${_currentExercise.sets} SET ${_currentExercise.reps} TEKRAR',
                              textAlign:
                                  TextAlign.right, // Sağa yaslı durması için
                              softWrap: true, // Alt satıra geçmeyi aktif eder
                              style: AppTypography.body18Medium.copyWith(
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Alt Satır: Input Alanları (Tam Hizalı)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // TEKRAR TextField
                          SizedBox(
                            width: 110,
                            height: 44,
                            child: TextField(
                              controller: _repsController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: AppTypography.body14Medium.copyWith(
                                color: Colors.grey[800],
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                    _lastPerformanceForCurrentSet != null
                                        ? '${_lastPerformanceForCurrentSet!.repsPerformed}'
                                        : 'TEKRAR',
                                hintStyle: AppTypography.body14Medium.copyWith(
                                  color: Colors.grey[400],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: AppColors.brandPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // AĞIRLIK TextField
                          SizedBox(
                            width: 110,
                            height: 44,
                            child: TextField(
                              controller: _weightController,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppTypography.body14Medium.copyWith(
                                color: Colors.grey[800],
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                    _lastPerformanceForCurrentSet != null
                                        ? _formatWeight(
                                          _lastPerformanceForCurrentSet!
                                              .weightUsed,
                                        )
                                        : 'AĞIRLIK',
                                hintStyle: AppTypography.body14Medium.copyWith(
                                  color: Colors.grey[400],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: AppColors.brandPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. SIRADAKİ HAREKET METNİ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sıradaki:',
                        style: AppTypography.body14Regular.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _nextPreviewLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppTypography.body14Regular.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. ALT KONTROLLER (Oklar ve Onay Butonu)
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
                        color: Colors.white.withOpacity(
                          _exerciseIndex > 0 ? 1 : 0.3,
                        ),
                        size: 40,
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _isPaused ? null : _confirmSet,
                        icon: Opacity(
                          opacity: _isPaused ? 0.4 : 1.0,
                          child: SvgPicture.asset(
                            'assets/images/check_icon.svg',
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _exerciseIndex < widget.workout.exercises.length - 1
                              ? () => _goToExercise(_exerciseIndex + 1)
                              : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: Colors.white.withOpacity(
                          _exerciseIndex < widget.workout.exercises.length - 1
                              ? 1
                              : 0.3,
                        ),
                        size: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
                        color: AppColors.brandPrimary.withOpacity(0.15),
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
