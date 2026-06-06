import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

String buildFiiNarrative({
  required FiiDetail detail,
  FiiTenantsResponse? tenants,
}) {
  final parts = <String>[];

  parts.add('${detail.ticker} é um FII');

  if (detail.fundType != null) {
    parts.add('de ${detail.fundType!.toLowerCase()}');
  }

  if (detail.segment != null) {
    parts.add('no segmento ${detail.segment}');
  }

  if (detail.managementType != null) {
    parts.add('com gestão ${detail.managementType!.toLowerCase()}');
  }

  if (detail.administrator != null) {
    parts.add('administrado por ${detail.administrator}');
  }

  if (detail.inceptionDate != null) {
    final year = detail.inceptionDate!.split('-').first;
    parts.add('desde $year');
  }

  var sentence = '${parts.join(', ')}.';

  final facts = <String>[];

  if (detail.propertyCount != null && detail.totalAreaSqm != null) {
    facts.add(
      '${detail.propertyCount} imóveis (${formatAreaSqm(detail.totalAreaSqm!)})',
    );
  } else if (detail.propertyCount != null) {
    facts.add('${detail.propertyCount} imóveis');
  }

  if (detail.vacancyPct != null) {
    facts.add('vacância de ${formatPct(detail.vacancyPct!)}');
  }

  if (detail.dividendYieldTtm != null) {
    facts.add('DY de ${formatPct(detail.dividendYieldTtm!)} nos últimos 12 meses');
  }

  if (detail.pvp != null) {
    facts.add('P/VP de ${detail.pvp!.toStringAsFixed(2)}');
  }

  if (facts.isNotEmpty) {
    sentence = '$sentence Possui ${facts.join(', ')}.';
  }

  if (tenants != null && tenants.sectors.isNotEmpty) {
    final top = List<FiiTenantSector>.from(tenants.sectors)
      ..sort((a, b) => (b.revenuePct ?? 0).compareTo(a.revenuePct ?? 0));
    final leaders = top
        .where((s) => s.revenuePct != null && s.revenuePct! > 0)
        .take(3)
        .map((s) => '${s.sector} (${formatPct(s.revenuePct!)})')
        .join(', ');
    if (leaders.isNotEmpty) {
      sentence = '$sentence A receita concentra-se em setores como $leaders.';
    }
  }

  if (detail.mandate != null) {
    sentence = '$sentence Mandato: ${detail.mandate}.';
  }

  return sentence.replaceAll(', .', '.').replaceAll('  ', ' ');
}

List<String> buildFiiHighlights({
  required FiiDetail detail,
  FiiTenantsResponse? tenants,
}) {
  final items = <String>[];

  if (detail.fundType != null && detail.segment != null) {
    items.add('${detail.fundType} · ${detail.segment}');
  }

  if (detail.netAssetValue != null) {
    items.add('Patrimônio ${formatCompactBrl(detail.netAssetValue!)}');
  }

  if (detail.totalShareholders != null) {
    items.add('${formatShareholders(detail.totalShareholders!)} cotistas');
  }

  if (detail.leasedPct != null) {
    items.add('Ocupação ${formatPct(detail.leasedPct!)}');
  }

  if (detail.delinquencyPct != null) {
    items.add('Inadimplência ${formatPct(detail.delinquencyPct!)}');
  }

  if (tenants?.topSectorPct != null && tenants!.sectors.isNotEmpty) {
    final top = tenants.sectors.reduce(
      (a, b) => (a.revenuePct ?? 0) >= (b.revenuePct ?? 0) ? a : b,
    );
    items.add('Maior setor: ${top.sector} (${formatPct(tenants.topSectorPct!)})');
  }

  if (detail.targetInvestors != null) {
    items.add(detail.targetInvestors!);
  }

  return items.take(6).toList();
}

String fiiDataDisclaimer() {
  return 'Resumo gerado automaticamente a partir dos dados oficiais (CVM/B3). '
      'Não constitui recomendação de investimento.';
}
