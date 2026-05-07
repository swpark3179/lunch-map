import 'package:flutter/material.dart';

class StartupFailure {
  final String title;
  final String detail;

  const StartupFailure({required this.title, required this.detail});
}

class StartupFailureApp extends StatelessWidget {
  final StartupFailure failure;

  const StartupFailureApp({super.key, required this.failure});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunch Map startup error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFB91C1C),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      failure.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      failure.detail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
