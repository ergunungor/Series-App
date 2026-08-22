import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/workout_card.dart';
import '../widgets/gradient_progress_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_menu_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isMenuOpen = false;
  String _firstName = 'İsim'; // Varsayılan değer
  bool _isLoading = true; // Veri çekilirken loading göstermek için

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Sayfa açılırken veriyi çekmeye başla
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // profiles tablosundan bu user'ın verisini çekiyoruz
        final response =
            await Supabase.instance.client
                .from('profiles')
                .select('full_name')
                .eq('id', user.id)
                .single(); // Sadece tek bir satır döneceğini biliyoruz

        if (response['full_name'] != null) {
          final fullName = response['full_name'] as String;
          // Sadece ilk ismini almak için boşluktan bölüyoruz
          final firstName = fullName.split(' ')[0];

          if (mounted) {
            setState(() {
              _firstName = firstName;
              _isLoading = false;
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Veri çekme hatası: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppMenuOverlay(
          isOpen: _isMenuOpen,
          onClose: () => setState(() => _isMenuOpen = false),
          items: [
            MenuOverlayItem(
              icon: Icons.calendar_month,
              label: 'Programlarım',
              onTap: () {},
            ),
            MenuOverlayItem(
              icon: Icons.history,
              label: 'Geçmiş Antrenmanlarım',
              onTap: () {},
            ),
            MenuOverlayItem(
              icon: Icons.fitness_center,
              label: 'Antrenmanlarım',
              onTap: () {},
            ),
          ],
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTopBar(onMenuTap: () => setState(() => _isMenuOpen = true)),
                const SizedBox(height: 28),
                WorkoutCard(
                  date: '22/08/2026',
                  streakCount: 5,
                  greeting: 'Hoş Geldin, $_firstName',
                  workoutSummary: '6 Hareket - 24 set (~55dk)',
                  nextWorkoutName: 'PUSH DAY - 1',
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Text(
                      'Haftalık Performans',
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(2/4)',
                      style: AppTypography.body16Regular.copyWith(
                        color: AppColors.brandSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const GradientProgressBar(value: 0.5),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.brandSecondary),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AKTİF PROGRAM',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: AppColors.brandSecondary, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        '"4 Günlük Hipertrofi"',
                        style: AppTypography.body18Medium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '3. Hafta',
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 20,
                            child: VerticalDivider(
                              color: AppColors.textTertiary,
                              width: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '12/16 Antrenman',
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const GradientProgressBar(value: 0.75),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '%75',
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.brandSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
