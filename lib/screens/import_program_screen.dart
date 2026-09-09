import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/program_import_service.dart';

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
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(45),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.brandTertiary,
                  ),
                ),
                title: Text(
                  'Kamera ile Çek',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.brandTertiary,
                  ),
                ),
                title: Text(
                  'Galeriden Seç',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: AppColors.brandTertiary,
                  ),
                ),
                title: Text(
                  'Dosya Yükle (PDF vb.)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
      ); // API'yi yormamak için kalite %80
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
          SnackBar(
            content: const Text('Programın başarıyla oluşturuldu!'),
            backgroundColor: AppColors.brandPrimary,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.brandTertiary),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap:
            () =>
                FocusScope.of(
                  context,
                ).unfocus(), // Ekrana tıklayınca klavyeyi kapatır
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Dekoratif İkon (Boşluğu Doldurur ve Estetik Katar)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brandTertiary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.brandTertiary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Başlık ve Alt Başlık
                  Text(
                    'Program Yükle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandTertiary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Programınızı yapıştırın veya yükleyin,\nyapay zeka ile takip edilebilir\nbir forma dönüştürelim.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 3. Esnek ve Büyük Input Alanı (Multiline)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end, // İkonların aşağıda hizalanması için
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: AppColors.brandTertiary,
                            size: 32,
                          ),
                          onPressed: _isLoading ? null : _showPickerOptions,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_isLoading,
                            minLines: 1,
                            maxLines:
                                8, // Çoklu satır desteği! Metin uzadıkça kutu büyüyecek.
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Programını buraya yapıştır...',
                              hintMaxLines: 1, // Metni zorla tek satırda tutar
                              hintStyle: TextStyle(
                                fontSize:
                                    14, // 15 yerine 14 yaptık ki ikonların arasına daha rahat sığsın
                                color: Colors.grey.shade400,
                                overflow:
                                    TextOverflow
                                        .ellipsis, // Yine de sığmazsa aşağı kaymak yerine sonuna ... koyar
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        _isLoading
                            ? Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.brandTertiary,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                            : IconButton(
                              icon: Icon(
                                Icons.send_rounded,
                                color: AppColors.brandTertiary,
                                size: 26,
                              ),
                              onPressed: _sendMessage,
                            ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4. Bilgi Kartı (Boşluğu doldurmak ve kullanıcıyı yönlendirmek için)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppColors.brandTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nasıl Çalışır?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Notes uygulamasındaki programını direkt yapıştırabilirsin.\n'
                          '• Telefonundaki program ekran görüntüsünü (+) butonuyla yükleyebilirsin.\n'
                          '• Hareket isimleri, set ve tekrar sayıları otomatik olarak algılanıp düzene sokulur.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
