class ApiConfig {
  // ⚠️ Bilgisayarının LOCAL AĞ IP'sini yaz (terminalde `ipconfig getifaddr en0`
  // [Mac] ya da `ipconfig` [Windows] ile bulabilirsin). "localhost" fiziksel
  // cihazda/emülatörde backend'e ulaşamaz.
  static const String baseUrl = 'http://127.0.0.1:8000';
}
