import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/survey_step_scaffold.dart';
import '../widgets/selectable_chip.dart';
import '../models/onboarding_data.dart';
import '../services/program_service.dart';

class OnboardingSurveyScreen extends StatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  State<OnboardingSurveyScreen> createState() => _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState extends State<OnboardingSurveyScreen> {
  final _data = OnboardingData();
  final _ageController = TextEditingController();
  final _blockerController = TextEditingController();
  final _pageController = PageController();

  int _currentStep = 0;
  bool _isSubmitting = false;

  // yeni:
  static const int totalSteps = 9;
  static const List<String> _experienceOptions = [
    'Başlangıç',
    'Orta',
    'İleri',
    'Profesyonel/Atlet',
  ];
  static const List<String> _goalOptions = [
    'Kas Kütlesi',
    'Yağ Yakımı',
    'Dayanıklılık',
    'Genel Fitness',
    'Güç (Strength)',
    'Esneklik & Hareketlilik',
    'Sağlık / Rehabilitasyon',
  ];
  static const List<String> _interestOptions = [
    'Karın',
    'Kol',
    'Bacak',
    'Sırt',
    'Göğüs',
    'Omuz',
    'Kalça / Glute',
    'Baldır',
    'Ön Kol',
    'Core / Bel',
  ];
  static const List<String> _restrictionOptions = [
    'Yok',
    'Diz',
    'Bel/Sırt',
    'Omuz',
    'Bilek',
    'Dirsek',
    'Kalça',
    'Boyun',
    'Ayak Bileği',
  ];
  static const List<String> _locationOptions = [
    'Ev',
    'Spor Salonu',
    'Açık Hava',
    'Ofis',
    'Seyahat/Otel',
  ];
  @override
  void dispose() {
    _ageController.dispose();
    _blockerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    setState(() => _currentStep--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Oturum bulunamadı, lütfen tekrar giriş yapın.');
      return;
    }

    _data.age = int.tryParse(_ageController.text);
    _data.mentalBlocker =
        _blockerController.text.trim().isEmpty
            ? null
            : _blockerController.text.trim();

    if (_data.age == null) {
      _showError('Lütfen yaşını girdiğinden emin ol.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ProgramService.generateProgram(_data, user.id);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) _showError('Program oluşturulurken bir hata oluştu: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brandPrimary),
              const SizedBox(height: 24),
              Text(
                'Yapay zeka senin için program hazırlıyor...',
                textAlign: TextAlign.center,
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _ageStep(),
          _experienceStep(),
          _goalStep(),
          _interestsStep(),
          _restrictionsStep(),
          _locationStep(),
          _daysPerWeekStep(),
          _durationStep(),
          _blockerStep(),
        ],
      ),
    );
  }

  Widget _ageStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Kaç yaşındasın?',
    content: AppInput(
      hintText: 'Yaşın',
      controller: _ageController,
      keyboardType: TextInputType.number,
    ),
    onNext: () {
      if (int.tryParse(_ageController.text) == null) {
        _showError('Lütfen geçerli bir yaş gir.');
        return;
      }
      _goNext();
    },
  );

  Widget _experienceStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Antrenman tecrüben ne seviyede?',
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _experienceOptions
              .map(
                (o) => SelectableChip(
                  label: o,
                  isSelected: _data.experience == o,
                  onTap: () => setState(() => _data.experience = o),
                ),
              )
              .toList(),
    ),
    onNext: () {
      if (_data.experience == null) {
        _showError('Lütfen bir seviye seç.');
        return;
      }
      _goNext();
    },
  );

  Widget _goalStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Ana hedefin ne?',
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _goalOptions
              .map(
                (o) => SelectableChip(
                  label: o,
                  isSelected: _data.primaryGoal == o,
                  onTap: () => setState(() => _data.primaryGoal = o),
                ),
              )
              .toList(),
    ),
    onNext: () {
      if (_data.primaryGoal == null) {
        _showError('Lütfen bir hedef seç.');
        return;
      }
      _goNext();
    },
  );

  Widget _interestsStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Hangi bölgelere odaklanmak istersin?',
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _interestOptions.map((o) {
            final isSelected = _data.specificInterests.contains(o);
            return SelectableChip(
              label: o,
              isSelected: isSelected,
              onTap:
                  () => setState(() {
                    isSelected
                        ? _data.specificInterests.remove(o)
                        : _data.specificInterests.add(o);
                  }),
            );
          }).toList(),
    ),
    onNext: () {
      if (_data.specificInterests.isEmpty) {
        _showError('Lütfen en az bir alan seç.');
        return;
      }
      _goNext();
    },
  );

  Widget _restrictionsStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Sağlık kısıtlaman veya sakatlığın var mı?',
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _restrictionOptions.map((o) {
            final isSelected = _data.healthRestrictions.contains(o);
            return SelectableChip(
              label: o,
              isSelected: isSelected,
              onTap:
                  () => setState(() {
                    if (o == 'Yok') {
                      _data.healthRestrictions
                        ..clear()
                        ..add('Yok');
                    } else {
                      _data.healthRestrictions.remove('Yok');
                      isSelected
                          ? _data.healthRestrictions.remove(o)
                          : _data.healthRestrictions.add(o);
                    }
                  }),
            );
          }).toList(),
    ),
    onNext: () {
      if (_data.healthRestrictions.isEmpty) {
        _showError('Lütfen bir seçim yap ("Yok" da olabilir).');
        return;
      }
      _goNext();
    },
  );

  Widget _locationStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Nerede antrenman yapacaksın?',
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _locationOptions
              .map(
                (o) => SelectableChip(
                  label: o,
                  isSelected: _data.logistics.location == o,
                  onTap: () => setState(() => _data.logistics.location = o),
                ),
              )
              .toList(),
    ),
    onNext: () {
      if (_data.logistics.location == null) {
        _showError('Lütfen bir yer seç.');
        return;
      }
      _goNext();
    },
  );

  Widget _daysPerWeekStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Haftada kaç gün antrenman yapmak istersin?',
    onBack: _goBack,
    content: Column(
      children: [
        Text(
          '${_data.logistics.daysPerWeek} gün',
          style: AppTypography.heading1.copyWith(color: AppColors.brandPrimary),
        ),
        Slider(
          value: _data.logistics.daysPerWeek.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          activeColor: AppColors.brandPrimary,
          onChanged:
              (v) => setState(() => _data.logistics.daysPerWeek = v.round()),
        ),
      ],
    ),
    onNext: _goNext,
  );

  Widget _durationStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Antrenman başına maksimum kaç dakika ayırabilirsin?',
    onBack: _goBack,
    content: Column(
      children: [
        Text(
          '${_data.logistics.maxDurationMin} dk',
          style: AppTypography.heading1.copyWith(color: AppColors.brandPrimary),
        ),
        Slider(
          value: _data.logistics.maxDurationMin.toDouble(),
          min: 15,
          max: 90,
          divisions: 15,
          activeColor: AppColors.brandPrimary,
          onChanged:
              (v) => setState(() => _data.logistics.maxDurationMin = v.round()),
        ),
      ],
    ),
    onNext: _goNext,
  );

  Widget _blockerStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Seni antrenmandan alıkoyan bir şey var mı? (opsiyonel)',
    onBack: _goBack,
    nextLabel: 'Programımı Oluştur',
    content: AppInput(
      hintText: 'Örn: motivasyon eksikliği, zaman yönetimi...',
      controller: _blockerController,
    ),
    onNext: _submit,
  );
}
