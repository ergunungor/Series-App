import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/services/app_settings.dart';
import 'package:series_app/widgets/sound_mode_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Ses eklentisi testte yok: kanal çağrılarını sessizce karşıla.
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(channel),
            (call) async => null,
          );
    }
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
    await AppSettings.instance.setSoundEnabled(true);
    await AppSettings.instance.setSoundMode(SoundMode.mix);
  });

  test('varsayılan: sesler açık, müzikle birlikte', () {
    expect(AppSettings.instance.soundEnabled, isTrue);
    expect(AppSettings.instance.soundMode, SoundMode.mix);
  });

  test('ayarlar cihazda saklanır ve geri okunur', () async {
    await AppSettings.instance.setSoundEnabled(false);
    await AppSettings.instance.setSoundMode(SoundMode.duck);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.sound_enabled'), isFalse);
    expect(prefs.getString('settings.sound_mode'), 'duck');

    await AppSettings.instance.load();
    expect(AppSettings.instance.soundEnabled, isFalse);
    expect(AppSettings.instance.soundMode, SoundMode.duck);
  });

  test('ses oturumu moda göre değişir', () async {
    await AppSettings.instance.setSoundMode(SoundMode.mix);
    var ctx = AppSettings.instance.audioContext;
    expect(ctx.iOS.options, contains(AVAudioSessionOptions.mixWithOthers));
    expect(ctx.android.audioFocus, AndroidAudioFocus.none);

    await AppSettings.instance.setSoundMode(SoundMode.duck);
    ctx = AppSettings.instance.audioContext;
    expect(ctx.iOS.options, contains(AVAudioSessionOptions.duckOthers));
    expect(ctx.android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);

    await AppSettings.instance.setSoundMode(SoundMode.pause);
    ctx = AppSettings.instance.audioContext;
    expect(ctx.iOS.options, isEmpty);
    expect(ctx.android.audioFocus, AndroidAudioFocus.gainTransient);
  });

  testWidgets('seçim sayfasından mod değiştirilir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () => showSoundModeSheet(context),
                child: const Text('aç'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.text('Müzik çalarken'), findsOneWidget);
    await tester.tap(find.text('Müziği kıs'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.soundMode, SoundMode.duck);
  });
}
