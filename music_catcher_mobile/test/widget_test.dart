import 'package:flutter_test/flutter_test.dart';
import 'package:music_catcher_mobile/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicCatcherApp());
    expect(find.text('下载'), findsOneWidget);
  });
}
