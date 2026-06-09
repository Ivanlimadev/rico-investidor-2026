import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_version != null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App version'),
              subtitle: Text(_version!),
            ),
          const SizedBox(height: 8),
          const Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _FaqTile(
            question: 'How do I connect my brokerage account?',
            answer:
                'Open the Portfolio tab and tap Connect account. Follow the secure Plaid or Pluggy flow to link your institution.',
          ),
          const _FaqTile(
            question: 'Why are my prices delayed?',
            answer:
                'Free plans may show delayed market data depending on the provider. Pull to refresh on the Portfolio tab to fetch the latest quotes.',
          ),
          const _FaqTile(
            question: 'How do I reset my password?',
            answer:
                'On the login screen tap Forgot password, enter your email, and follow the link sent to your inbox.',
          ),
          const _FaqTile(
            question: 'How do I delete my account?',
            answer:
                'Go to Settings, scroll to account options, and choose Delete account. Registered users must confirm with their password.',
          ),
          const _FaqTile(
            question: 'How do I contact support?',
            answer:
                'Email support@ricoinvestidor.app with your registered email and a short description of the issue.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(answer),
            ),
          ),
        ],
      ),
    );
  }
}
