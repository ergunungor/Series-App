/// Kütüphanedeki ham egzersiz adını ekranda göstermek için biçimlendirir:
/// `barbell close-grip bench press (male)` → `Barbell Close-Grip Bench Press (Male)`.
///
/// Yalnızca GÖSTERİM içindir. Egzersiz adı veritabanında, önceki seans ipucu
/// anahtarında ve GIF eşleştirmesinde kimlik olarak kullanılıyor; model
/// değerini bununla değiştirmeyin.
String formatExerciseName(String raw) {
  const boundaries = {' ', '-', '(', '/'};
  final buffer = StringBuffer();
  var capitalizeNext = true;
  for (final char in raw.split('')) {
    final isLetter = char.toLowerCase() != char.toUpperCase();
    buffer.write(capitalizeNext && isLetter ? char.toUpperCase() : char);
    // Rakam ya da sembol (3/4, 45°) kelimenin başını tüketir, harf gelirse
    // büyütülmez; sınır karakterleri bir sonraki harfi büyütür.
    capitalizeNext = boundaries.contains(char);
  }
  return buffer.toString();
}
