import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/program_import_service.dart';
import '../theme/app_typography.dart';
import '../widgets/detail_hero.dart' show HeroStatusBarScope;
import '../widgets/kiremit_hero_surface.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/reveal.dart';

class ImportProgramScreen extends StatefulWidget {
  const ImportProgramScreen({super.key});

  @override
  State<ImportProgramScreen> createState() => _ImportProgramScreenState();
}

class _ImportProgramScreenState extends State<ImportProgramScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _showPickerOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final bottomSafe = MediaQuery.paddingOf(context).bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(45),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Program Ekle',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PickerOption(
                icon: Icons.camera_alt_outlined,
                label: 'Kamera ile Çek',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _PickerOption(
                icon: Icons.photo_library_outlined,
                label: 'Galeriden Seç',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              _PickerOption(
                icon: Icons.description_outlined,
                label: 'Dosya Yükle (PDF vb.)',
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        _sendMessage(file: File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Görsel seçilemedi: $e')));
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        _sendMessage(file: File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Dosya seçilemedi: $e')));
      }
    }
  }

  Future<void> _sendMessage({File? file}) async {
    final messageText = _controller.text.trim();
    if (messageText.isEmpty && file == null) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      if (file != null) {
        await ProgramImportService.importFromFile(file, user.id);
      } else {
        await ProgramImportService.importFromText(messageText, user.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Programın başarıyla oluşturuldu!'),
            backgroundColor: AppColors.homeHero,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        // "Exception: " metnini kullanıcı görmemesi için temizliyoruz.
        final cleanMessage = e.toString().replaceAll('Exception: ', '').trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $cleanMessage'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // ŞART 3: İşlem başarılı da olsa hata da alsa, loading state'i mutlaka kapatıyoruz.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _pagePadding = 20;
  static const double _cardRadius = 24;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: HeroStatusBarScope(
          builder:
              (context, heroKey) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    _buildHero(heroKey),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pagePadding,
                        24,
                        _pagePadding,
                        32,
                      ),
                      child: Column(
                        children: [
                          Reveal(
                            duration: const Duration(milliseconds: 500),
                            child: _buildInputCard(),
                          ),
                          const SizedBox(height: 20),
                          Reveal(
                            delay: const Duration(milliseconds: 100),
                            duration: const Duration(milliseconds: 500),
                            child: _buildInfoCard(),
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

  Widget _buildHero(GlobalKey heroKey) {
    return KiremitHeroSurface(
      heroKey: heroKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          MediaQuery.paddingOf(context).top + 8,
          _pagePadding,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PressableScale(
                  pressedScale: 0.92,
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: AppColors.accentGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Program Yükle',
              style: AppTypography.heading1.copyWith(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Programını yapıştır veya ekran görüntüsü yükle, yapay zeka ile hemen dijital forma dönüştürelim.',
              style: AppTypography.body14Regular.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Metin giriş kutusu: yazı alanı, ayırıcı, dosya ekle ve dönüştür.
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            enabled: !_isLoading,
            minLines: 5,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            cursorColor: AppColors.homeHero,
            style: AppTypography.body14Regular.copyWith(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText:
                  'Örn:\n1. Gün: Göğüs & Biceps\n- Bench Press 4x10\n- Incline Dumbbell Press 3x12',
              hintStyle: AppTypography.body14Regular.copyWith(
                color: AppColors.textTertiary.withValues(alpha: 0.8),
                height: 1.45,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PressableScale(
                pressedScale: 0.96,
                onTap: _isLoading ? null : _showPickerOptions,
                child: Opacity(
                  opacity: _isLoading ? 0.5 : 1,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.fillSubtle,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 20,
                          color: AppColors.homeHero,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Görsel veya Dosya Ekle',
                          style: AppTypography.body12Medium.copyWith(
                            color: AppColors.homeHero,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isLoading
                  ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: AppColors.homeHero,
                    ),
                  )
                  : PressableScale(
                    pressedScale: 0.95,
                    onTap: _sendMessage,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.homeHero.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'Dönüştür',
                        style: AppTypography.body14Medium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.fillSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.homeHero,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Nasıl Çalışır?',
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Notes uygulamasındaki programını direkt üstteki alana yapıştırabilirsin.\n'
            '• Telefonundaki program ekran görüntüsünü veya PDF dosyasını alt butondan yükleyebilirsin.\n'
            '• Hareket isimleri, set ve tekrar sayıları yapay zeka tarafından otomatik ayarlanır.',
            style: AppTypography.body14Regular.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dosya/görsel seçici sheet'indeki satır: beyaz kart, nötr ikon karosu.
class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.fillSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.homeHero, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
