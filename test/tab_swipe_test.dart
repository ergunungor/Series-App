import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/widgets/app_bottom_nav.dart';
import 'package:series_app/widgets/fade_branch_container.dart';

Widget _host(ValueNotifier<int> index) {
  return MaterialApp(
    home: ValueListenableBuilder<int>(
      valueListenable: index,
      builder:
          (context, i, _) => FadeBranchContainer(
            currentIndex: i,
            onIndexChanged: (n) => index.value = n,
            children: [
              for (var k = 0; k < 3; k++) Center(child: Text('Sekme $k')),
            ],
          ),
    ),
  );
}

void main() {
  testWidgets('yeterince kaydırınca komşu sekmeye geçer', (tester) async {
    final index = ValueNotifier<int>(0);
    await tester.pumpWidget(_host(index));

    await tester.drag(find.text('Sekme 0'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(index.value, 1);
    expect(tabSwipeProgress.value, isNull);
  });

  testWidgets('az kaydırınca geri döner, sekme değişmez', (tester) async {
    final index = ValueNotifier<int>(0);
    await tester.pumpWidget(_host(index));

    await tester.drag(find.text('Sekme 0'), const Offset(-60, 0));
    await tester.pumpAndSettle();

    expect(index.value, 0);
    expect(tabSwipeProgress.value, isNull);
    expect(find.text('Sekme 0'), findsOneWidget);
  });

  testWidgets('uçtaki sekmede dışarı kaydırma bir şey yapmaz', (tester) async {
    final index = ValueNotifier<int>(0);
    await tester.pumpWidget(_host(index));

    await tester.drag(find.text('Sekme 0'), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(index.value, 0);
  });

  testWidgets('sağa kaydırınca önceki sekmeye geçer', (tester) async {
    final index = ValueNotifier<int>(2);
    await tester.pumpWidget(_host(index));

    await tester.drag(find.text('Sekme 2'), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(index.value, 1);
  });

  testWidgets('alt barda basılı tutup kaydırınca seçim değişir', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.bottomCenter,
          child: AppBottomNav(currentIndex: 0, onTap: (i) => tapped = i),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AppBottomNav));
    final start = Offset(rect.center.dx - 120, rect.center.dy);
    await tester.dragFrom(start, const Offset(240, 0));
    await tester.pumpAndSettle();

    expect(tapped, 3);
  });

  testWidgets('alt barda dokunma hâlâ çalışır', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.bottomCenter,
          child: AppBottomNav(currentIndex: 0, onTap: (i) => tapped = i),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(tapped, 3);
  });
}
