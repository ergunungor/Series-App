class Exercise {
  final String id;
  final String name;
  final String gifUrl;
  final List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.gifUrl,
    required this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // 1. Göreceli GIF yolunu tam çalışan GitHub Raw linkine dönüştürüyoruz
    final relativeGifPath = json['gif_url']?.toString() ?? '';

    // YENİ: URL içindeki "/data" kısmını kaldırdık, doğrudan root'a bakıyoruz
    final fullGifUrl =
        relativeGifPath.isNotEmpty
            ? 'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/$relativeGifPath'
            : '';

    // 2. Varsa Türkçe talimatları, yoksa İngilizceyi, o da yoksa boş liste alıyoruz
    List<String> instructionsList = [];
    if (json['instruction_steps'] != null) {
      final stepsMap = json['instruction_steps'] as Map<String, dynamic>;
      if (stepsMap['tr'] != null) {
        instructionsList = List<String>.from(stepsMap['tr']);
      } else if (stepsMap['en'] != null) {
        instructionsList = List<String>.from(stepsMap['en']);
      }
    }

    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      gifUrl: fullGifUrl,
      instructions: instructionsList,
    );
  }
}
