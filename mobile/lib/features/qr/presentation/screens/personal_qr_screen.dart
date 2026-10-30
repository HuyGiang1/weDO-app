import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/links/wedo_deep_link.dart';
import '../../data/personal_qr.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

class PersonalQrScreen extends StatefulWidget {
  final Future<PersonalQr> Function() loadPersonalQr;
  final VoidCallback? onScanQr;

  const PersonalQrScreen({
    super.key,
    required this.loadPersonalQr,
    this.onScanQr,
  });

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

  void _copyLink(String deepLink) {
    Clipboard.setData(ClipboardData(text: deepLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết hồ sơ!')),
    );
  }

  Future<void> _shareLink(String deepLink) async {
    final shared = await WeDoPlatformLinks.shareText(
      deepLink,
      subject: 'Kết bạn với tôi trên weDO',
    );
    if (!shared && mounted) {
      _copyLink(deepLink);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My QR Code'),
      actions: [
        if (widget.onScanQr != null)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Quét QR',
            onPressed: widget.onScanQr,
          ),
      ],
    ),
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
                  Text(
                    'Unable to load your QR code.',
                    style: AppTextStyles.of(context).bodyMedium,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('My QR Code', style: AppTextStyles.of(context).headline),
                const SizedBox(height: AppSpacing.md),
                ProfileSurface(child: PersonalQrRenderer(deepLink: deepLink)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Share this QR code so others can find your public profile.',
                  style: AppTextStyles.of(context).bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  deepLink,
                  style: AppTextStyles.of(context).bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyLink(deepLink),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Sao chép liên kết'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _shareLink(deepLink),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Chia sẻ'),
                    ),
                    if (widget.onScanQr != null)
                      OutlinedButton.icon(
                        onPressed: widget.onScanQr,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Quét QR'),
                      ),
                  ],
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
