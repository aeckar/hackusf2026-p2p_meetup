import 'package:flutter/material.dart';

Future<T> showLoadingOverlay<T>(BuildContext context, Future<T> future) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'loading',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      return Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.78,
            height: MediaQuery.of(ctx).size.height * 0.28,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Loading',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  try {
    final result = await future;
    if (context.mounted) nav.pop();
    return result;
  } catch (e) {
    if (context.mounted) nav.pop();
    rethrow;
  }
}
