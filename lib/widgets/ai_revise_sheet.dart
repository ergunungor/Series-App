import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

/// Yapay zeka ile düzenleme: istek sayfası, yükleniyor katmanı ve günlük hak.
/// Program detayı ve gün (antrenman) detayı ekranları ortak kullanır.

class AiCredits {
  AiCredits._();

  /// Günlük yapay zeka hakkı (5) kaldı mı.
  static Future<bool> canUse(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;

    // YENİ: Patron çıldırdı (Kendi e-postan için VIP Geçiş)
    if (user?.email == 'ergun6e@gmail.com') {
      return true; // Sınır yok, hep true döner
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

  static Future<void> consume(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;

    // YENİ: Kendi hesabında kota düşürme işlemini tamamen pas geç
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
}

/// İstek sayfasını açar; gönderilen metni döndürür (kapatılırsa null).
Future<String?> showAiReviseSheet(
  BuildContext context, {
  List<String> suggestions = const [],
  String subtitle = 'Antrenmanında neleri değiştirmek istersin?',
}) {
  final promptController = TextEditingController();

  // Boşsa çipin metnini yazar, doluysa mevcut metnin sonuna cümle olarak ekler.
  void addSuggestion(String suggestion) {
    final current = promptController.text.trim();
    final next =
        current.isEmpty
            ? suggestion
            : current.endsWith('.')
            ? '$current $suggestion'
            : '$current. $suggestion';
    promptController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      );

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.espresso,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          // Klavye açıldığında yukarı kayması için
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onHeroDark.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: AppColors.espresso,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'AI ile Şekillendir',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.onHeroDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTypography.body14Regular.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.62),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions)
                  PressableScale(
                    pressedScale: 0.95,
                    onTap: () => addSuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        suggestion,
                        style: AppTypography.body12Medium.copyWith(
                          color: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              // Yazdıkça 4 satıra kadar dikey büyür, 2 satırla başlar
              maxLines: 4,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              keyboardAppearance: Brightness.dark,
              cursorColor: AppColors.accentGold,
              style: AppTypography.body16Regular.copyWith(
                color: AppColors.onHeroDark,
              ),
              decoration: InputDecoration(
                hintText: 'Talebini yaz...',
                hintStyle: AppTypography.body14Regular.copyWith(
                  color: AppColors.onHeroDark.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: AppColors.onHeroDark.withValues(alpha: 0.08),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorder.copyWith(
                  borderSide: BorderSide(
                    color: AppColors.accentGold.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 16),
            PressableScale(
              onTap: () {
                final text = promptController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(ctx).pop(text);
              },
              child: Container(
                height: 52,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.espresso,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Güncelle',
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AiLoadingOverlay extends StatefulWidget {
  const AiLoadingOverlay({super.key});

  @override
  State<AiLoadingOverlay> createState() => _AiLoadingOverlayState();
}

class _AiLoadingOverlayState extends State<AiLoadingOverlay>
    with SingleTickerProviderStateMixin {
  static const List<String> _messages = [
    'Programın yeniden şekilleniyor',
    'Hareketler senin için düzenleniyor',
    'Son rötuşlar yapılıyor',
  ];
  static const Duration _pulseDuration = Duration(milliseconds: 2400);
  static const Duration _messageInterval = Duration(milliseconds: 2800);
  static const double _orbSize = 76;

  late final AnimationController _pulse;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat();
    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // phase: iki halkanın yarım turluk farkla dalgalanması için
  Widget _ring(double phase) {
    final t = (_pulse.value + phase) % 1.0;
    return Opacity(
      opacity: (1 - t) * 0.35,
      child: Transform.scale(
        scale: 1 + t * 0.9,
        child: Container(
          width: _orbSize,
          height: _orbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        // BackdropFilter en dışta: Opacity içine konursa arkadaki sayfayı
        // bulanıklaştıramaz. Geçişi sigma, perde ve içerik opaklığına dağıtıyoruz.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
          child: Container(
            color: AppColors.heroDarkEnd.withValues(alpha: 0.78 * t),
            alignment: Alignment.center,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: _orbSize * 2,
                height: _orbSize * 2,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final breathe = 1 + 0.05 * sin(_pulse.value * 2 * pi);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(0),
                        _ring(0.5),
                        Transform.scale(
                          scale: breathe,
                          child: Container(
                            width: _orbSize,
                            height: _orbSize,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 34,
                              color: AppColors.espresso,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI İş Başında',
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  textAlign: TextAlign.center,
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.onHeroDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
