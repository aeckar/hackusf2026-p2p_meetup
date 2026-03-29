import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:p2p_meetup/state/app_session.dart';

void main() {
  testWidgets('AppSession provides local user id', (WidgetTester tester) async {
    const id = '00000000-0000-0000-0000-000000000001';
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSession(localUserId: id),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Text(context.watch<AppSession>().localUserId);
            },
          ),
        ),
      ),
    );
    expect(find.text(id), findsOneWidget);
  });
}
