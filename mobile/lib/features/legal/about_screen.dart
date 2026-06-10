import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rico_investidor/core/widgets/investment_disclaimer.dart';
import 'package:rico_investidor/features/legal/legal_content.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

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
      appBar: AppBar(title: const Text(LegalContent.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_version.isNotEmpty)
            Text('Versão $_version', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          const InvestmentDisclaimer(),
          const SizedBox(height: 16),
          Text(LegalContent.aboutBody, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
