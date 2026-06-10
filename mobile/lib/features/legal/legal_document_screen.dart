import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/investment_disclaimer.dart';
import 'package:rico_investidor/features/legal/legal_content.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    this.url,
    this.body,
  });

  final String title;
  final String? url;
  final String? body;

  String? get _inlineBody {
    if (body != null) return body;
    if (title == LegalContent.termsTitle || title == 'Terms of Service') {
      return LegalContent.termsBody;
    }
    if (title == LegalContent.privacyTitle || title == 'Privacy Policy') {
      return LegalContent.privacyBody;
    }
    return null;
  }

  Future<void> _openDocument(BuildContext context) async {
    if (url == null) return;
    final uri = Uri.parse(url!);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o documento no navegador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inline = _inlineBody;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InvestmentDisclaimer(compact: true),
          const SizedBox(height: 16),
          if (inline != null)
            Text(inline, style: Theme.of(context).textTheme.bodyMedium)
          else
            Text(
              'Documento indisponível.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (url != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _openDocument(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir versão online'),
            ),
          ],
        ],
      ),
    );
  }
}
