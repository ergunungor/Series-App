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
import '../widgets/app_confirm_dialog.dart';

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

  static const List<String> _equipmentOptions = [
    'Sadece Vücut Ağırlığı',
    'Dambıl',
    'Barfiks Demiri',
    'Direnç Bandı',
    'Kettlebell',
    'Atlama İpi',
  ];

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

  Future<void> _handleSurveyExitOrBack() async {
    // 1. Eğer anketin ilk sorusunda değilse, bir önceki soruya dön:
    if (_currentStep > 0) {
      _goBack();
      return;
    }

    // 2. İlk sorudaysa çıkmak için onay iste:
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Anketten Çık',
      message:
          'Program oluşturma anketinden çıkmak istediğine emin misin? Girdiğin bilgiler kaybolacak.',
      confirmLabel: 'Çık',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _handleCloseSurvey() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Anketten Çık',
      message:
          'Program oluşturma anketinden çıkmak istediğine emin misin? Girdiğin bilgiler kaybolacak.',
      confirmLabel: 'Çık',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
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
      if (mounted) {
        // Eğer bu ekrana context.push() ile gelindiyse (sağ alttaki + butonundan):
        if (context.canPop()) {
          context.pop(true); // Geriye 'true' döndürür
        } else {
          // Eğer ilk kayıt/onboarding akışından gelindiyse:
          context.go('/home');
        }
      }
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

    return PopScope(
      canPop: false, // Donanım/Tarayıcı geri tuşunu kilitler
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSurveyExitOrBack();
      },
      child: GestureDetector(
        // Soldan sağa kaydırma jestini yakalar (Swipe-to-back)
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 250) {
            _handleSurveyExitOrBack();
          }
        },
        child: Scaffold(
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
        ),
      ),
    );
  }

  Widget _ageStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Kaç yaşındasın?',
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
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
    question: 'Nerede antrenman yapacaksın? (birden fazla seçebilirsin)',
    onExit: _handleCloseSurvey,
    onBack: _goBack,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              _locationOptions.map((o) {
                final isSelected = _data.logistics.location.contains(o);
                return SelectableChip(
                  label: o,
                  isSelected: isSelected,
                  onTap:
                      () => setState(() {
                        if (isSelected) {
                          _data.logistics.location.remove(o);
                        } else {
                          _data.logistics.location.add(o);
                        }
                      }),
                );
              }).toList(),
        ),
        if (_data.logistics.location.contains('Ev')) ...[
          const SizedBox(height: 32),
          Text(
            'Evde hangi ekipmanların var?',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                _equipmentOptions.map((o) {
                  // Not: OnboardingData modelinde logistics.equipment listesinin
                  // tanımlı olması gerekir.
                  final isSelected = _data.logistics.equipment.contains(o);
                  return SelectableChip(
                    label: o,
                    isSelected: isSelected,
                    onTap:
                        () => setState(() {
                          if (isSelected) {
                            _data.logistics.equipment.remove(o);
                          } else {
                            if (o == 'Sadece Vücut Ağırlığı') {
                              _data.logistics.equipment.clear();
                            } else {
                              _data.logistics.equipment.remove(
                                'Sadece Vücut Ağırlığı',
                              );
                            }
                            _data.logistics.equipment.add(o);
                          }
                        }),
                  );
                }).toList(),
          ),
        ],
      ],
    ),
    onNext: () {
      if (_data.logistics.location.isEmpty) {
        _showError('Lütfen en az bir yer seç.');
        return;
      }
      _goNext();
    },
  );
  Widget _daysPerWeekStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Haftada kaç gün antrenman yapmak istersin?',
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
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
    onExit: _handleCloseSurvey,
    onBack: _goBack,
    nextLabel: 'Programımı Oluştur',
    content: AppInput(
      hintText: 'Örn: motivasyon eksikliği, zaman yönetimi...',
      controller: _blockerController,
    ),
    onNext: _submit,
  );
}
