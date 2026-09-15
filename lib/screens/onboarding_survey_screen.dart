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
import '../services/program_repository.dart'; // YENİ EKLENDİ (programRefreshNotifier için)

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

  static const int totalSteps = 10;

  static const List<String> _genderOptions = [
    'Erkek',
    'Kadın',
    'Belirtmek İstemiyorum',
  ];
  String? _selectedGender;

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
  final Set<String> _selectedGoals = {};

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
    if (_currentStep > 0) {
      _goBack();
      return;
    }

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

  Future<bool> _canUseAI(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user?.email == 'ergun6e@gmail.com') {
      return true;
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('daily_ai_count, last_ai_date')
            .eq('id', userId)
            .single();

    int count = response['daily_ai_count'] as int? ?? 0;
    String? lastDate = response['last_ai_date'] as String?;

    if (lastDate != today) count = 0;

    return count < 5;
  }

  Future<void> _consumeAICredit(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user?.email == 'ergun6e@gmail.com') {
      return;
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('daily_ai_count, last_ai_date')
            .eq('id', userId)
            .single();

    int count = response['daily_ai_count'] as int? ?? 0;
    String? lastDate = response['last_ai_date'] as String?;

    if (lastDate != today) count = 0;

    await Supabase.instance.client
        .from('profiles')
        .update({'daily_ai_count': count + 1, 'last_ai_date': today})
        .eq('id', userId);
  }

  // YENİ: ATEŞLE VE UNUT MANTIĞI
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
    _data.gender = _selectedGender;
    _data.primaryGoal = _selectedGoals.join(', ');

    if (_data.age == null) {
      _showError('Lütfen yaşını girdiğinden emin ol.');
      return;
    }

    // Kota kontrolünü hızlıca bekliyoruz
    final hasCredit = await _canUseAI(user.id);
    if (!hasCredit) {
      _showError(
        'Bugünlük ücretsiz yapay zeka limitine (5/5) ulaştın. Lütfen yarın tekrar dene.',
      );
      return;
    }

    // 1. Arka planda AI işlemini başlat (await YOK!)
    ProgramService.generateProgram(_data, user.id)
        .then((_) async {
          await _consumeAICredit(user.id);
          // İşlem bitince ana sayfadaki listeyi otomatik yenile
          programRefreshNotifier.value++;
        })
        .catchError((error) {
          debugPrint('AI Oluşturma Hatası: $error');
        });

    // 2. Anket sayfasını ANINDA kapat ki ana sayfadaki Shimmer görünsün!
    if (mounted) {
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: Beyaz yükleme ekranı kodu tamamen silindi

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSurveyExitOrBack();
      },
      child: GestureDetector(
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
              _genderStep(),
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

  Widget _genderStep() => SurveyStepScaffold(
    currentStep: _currentStep,
    totalSteps: totalSteps,
    question: 'Cinsiyetin nedir?',
    onExit: _handleCloseSurvey,
    onBack: _goBack,
    content: Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _genderOptions
              .map(
                (o) => SelectableChip(
                  label: o,
                  isSelected: _selectedGender == o,
                  onTap: () => setState(() => _selectedGender = o),
                ),
              )
              .toList(),
    ),
    onNext: () {
      if (_selectedGender == null) {
        _showError('Lütfen bir cinsiyet seç.');
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
    question: 'Ana hedefin ne? (Birden fazla seçebilirsin)',
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
                  isSelected: _selectedGoals.contains(o),
                  onTap:
                      () => setState(() {
                        if (_selectedGoals.contains(o)) {
                          _selectedGoals.remove(o);
                        } else {
                          _selectedGoals.add(o);
                        }
                      }),
                ),
              )
              .toList(),
    ),
    onNext: () {
      if (_selectedGoals.isEmpty) {
        _showError('Lütfen en az bir hedef seç.');
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
      children: [
        SelectableChip(
          label: 'Hepsi (Tüm Vücut)',
          isSelected: _data.specificInterests.length == _interestOptions.length,
          onTap: () {
            setState(() {
              if (_data.specificInterests.length == _interestOptions.length) {
                _data.specificInterests.clear();
              } else {
                _data.specificInterests.clear();
                _data.specificInterests.addAll(_interestOptions);
              }
            });
          },
        ),
        ..._interestOptions.map((o) {
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
        }),
      ],
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
    nextLabel: 'Bitir',
    content: TextField(
      controller: _blockerController,
      maxLength: 700,
      maxLines: 4,
      minLines: 2,
      keyboardType: TextInputType.multiline,
      style: AppTypography.body16Regular.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Örn: motivasyon eksikliği, zaman yönetimi...',
        hintStyle: AppTypography.body14Regular.copyWith(
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.brandSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.brandSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    ),
    onNext: _submit, // Artık butona basınca hiç beklemeden kapatacak
  );
}
