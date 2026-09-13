import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/personal_qr.dart';

class PersonalQrScreen extends StatefulWidget {
  final Future<PersonalQr> Function() loadPersonalQr;

  const PersonalQrScreen({super.key, required this.loadPersonalQr});

  @override
  State<PersonalQrScreen> createState() => _PersonalQrScreenState();
}

class _PersonalQrScreenState extends State<PersonalQrScreen> {
  Future<PersonalQr>? _qrFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _qrFuture = widget.loadPersonalQr();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My QR')),
    body: FutureBuilder<PersonalQr>(
      future: _qrFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load your QR code.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final deepLink = snapshot.data!.deepLink;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('My QR', style: AppTextStyles.headline),
                const SizedBox(height: AppSpacing.md),
                PersonalQrRenderer(deepLink: deepLink),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Share this QR code so others can find your public profile.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class PersonalQrRenderer extends StatelessWidget {
  final String deepLink;

  const PersonalQrRenderer({super.key, required this.deepLink});

  @override
  Widget build(BuildContext context) => QrImageView(data: deepLink, size: 240);
}
