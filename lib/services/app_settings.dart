import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set arası sesler çalarken telefonda çalan müziğe ne olacağı.
enum SoundMode {
  /// Müzik durmaz, ses üstüne biner.
  mix,

  /// Ses çalarken müziğin sesi kısılır, sonra geri gelir.
  duck,

  /// Ses çalarken müzik duraklar (eski davranış).
  pause,
}

/// Uygulama ayarları (cihazda saklanır). Dinlenebilir: ayar değişince arayüz yenilenir.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _soundEnabledKey = 'settings.sound_enabled';
  static const _soundModeKey = 'settings.sound_mode';

  bool _soundEnabled = true;
  SoundMode _soundMode = SoundMode.mix;

  bool get soundEnabled => _soundEnabled;
  SoundMode get soundMode => _soundMode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      final name = prefs.getString(_soundModeKey);
      _soundMode = SoundMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => SoundMode.mix,
      );
    } catch (e) {
      debugPrint('Ayarlar okunamadı, varsayılanlar kullanılıyor: $e');
    }
    await applyAudioContext();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSoundMode(SoundMode mode) async {
    _soundMode = mode;
    notifyListeners();
    await _save();
    await applyAudioContext();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      await prefs.setString(_soundModeKey, _soundMode.name);
    } catch (e) {
      debugPrint('Ayarlar kaydedilemedi: $e');
    }
  }

  /// Seçili moda göre ses oturumu: müzikle karışsın, kısılsın ya da duraklatsın.
  AudioContext get audioContext {
    switch (_soundMode) {
      case SoundMode.mix:
        return AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        );
      case SoundMode.duck:
        return AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        );
      case SoundMode.pause:
        return AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        );
    }
  }

  Future<void> applyAudioContext() async {
    if (kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(audioContext);
    } catch (e) {
      debugPrint('Ses oturumu ayarlanamadı: $e');
    }
  }
}
