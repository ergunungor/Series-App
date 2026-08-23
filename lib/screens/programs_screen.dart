import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  // Şimdilik arayüzü görmek için sahte (mock) bir veri koyuyoruz.
  // İleride burası Supabase'den gelen programların listesi olacak.
  final List<Map<String, dynamic>> _myPrograms = [
    {
      'id': '1',
      'name': '4 Haftalık Hipertrofi',
      'description': 'AI tarafından oluşturulmuş özel güç programı.',
      'progress': 0.35, // %35 tamamlanmış
    },
  ];

  void _showAddProgramMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors
              .transparent, // Arka planı transparan yapıp kendi tasarımımızı veriyoruz
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.black,
                      ),
                    ),
                    title: Text(
                      'Yapay Zeka ile Oluştur',
                      // DOĞRU:
                      style: AppTypography.body16Regular.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Hedeflerine özel akıllı program hazırlanır',
                      style: AppTypography.body14Regular.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Anket ekranına yönlendirme
                      context.push('/onboarding');
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.upload_file, color: Colors.black),
                    ),
                    title: Text(
                      'Program Yükle',
                      // DOĞRU:
                      style: AppTypography.body14Regular.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Mevcut JSON veya kod ile program içe aktar',
                      style: AppTypography.body14Regular.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Yükleme ekranına yönlendirilecek
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Programlarım',
          style: AppTypography.heading2.copyWith(color: Colors.black),
        ),
      ),
      body:
          _myPrograms.isEmpty
              ? Center(
                child: Text(
                  'Henüz bir programın yok.\nSağ alttan yeni bir tane oluştur!',
                  textAlign: TextAlign.center,
                  style: AppTypography.body16Regular.copyWith(
                    color: Colors.grey,
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _myPrograms.length,
                itemBuilder: (context, index) {
                  final program = _myPrograms[index];
                  return _buildProgramCard(program);
                },
              ),
      // YENİ EKLENEN + BUTONU
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProgramMenu,
        backgroundColor: Colors.black, // Marka rengine göre güncelleyebilirsin
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    return GestureDetector(
      onTap: () {
        // Kartın üstüne tıklanınca program detayına (günlerin listesine) gidecek
        // context.push('/program-details', extra: program['id']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    program['name'],
                    style: AppTypography.heading3.copyWith(color: Colors.black),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              program['description'],
              style: AppTypography.body14Regular.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            // İlerleme çubuğu (opsiyonel ama şık durur)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: program['progress'],
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.black,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '%${(program['progress'] * 100).toInt()}',
                  // DOĞRU:
                  style: AppTypography.body14Regular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
