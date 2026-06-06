import 'package:rico_investidor/models/fii_models.dart';

bool isFiiPaperFund(FiiDetail detail) {
  final type = detail.fundType?.toLowerCase().trim() ?? '';
  if (type.contains('papel')) return true;
  final cri = detail.assetComposition?.criPct ?? 0;
  final lci = detail.assetComposition?.lciPct ?? 0;
  final deb = detail.assetComposition?.debenturesPct ?? 0;
  return (cri + lci + deb) >= 50;
}

bool isFiiBrickFund(FiiDetail detail) {
  final type = detail.fundType?.toLowerCase().trim() ?? '';
  if (type.contains('tijolo')) return true;
  final realEstate = detail.assetComposition?.realEstateLeasedPct ?? 0;
  return realEstate >= 40;
}

String fiiPatrimonySectionTitle(FiiDetail detail) {
  if (isFiiPaperFund(detail)) {
    return 'Ativos do fundo (papel)';
  }
  if (isFiiBrickFund(detail)) {
    return 'Principais imóveis';
  }
  return 'Principais ativos';
}

String? fiiPatrimonySectionSubtitle(FiiDetail detail) {
  final shown = detail.topProperties.length;
  final total = detail.propertyCount;
  final parts = <String>[];

  if (isFiiPaperFund(detail)) {
    final cri = detail.assetComposition?.criPct;
    if (cri != null && cri > 0) {
      parts.add('Carteira com ${cri.toStringAsFixed(1)}% em CRIs');
    } else {
      parts.add('Recebíveis, CRIs, LCIs e debêntures');
    }
  } else if (isFiiBrickFund(detail)) {
    parts.add('Galpões, lajes e ativos físicos com vacância e ocupação');
  }

  if (total != null && total > 0) {
    if (shown > 0 && shown < total) {
      parts.add('Exibindo $shown de $total ativos no relatório CVM');
    } else if (shown > 0) {
      parts.add('$shown ativos no recorte');
    }
  }

  if (detail.propertyReferenceDate != null) {
    parts.add('Ref. ${detail.propertyReferenceDate}');
  }

  return parts.isEmpty ? null : parts.join(' · ');
}

String? fiiOperacionalHint(FiiDetail detail) {
  if (isFiiPaperFund(detail) && detail.vacancyPct == null) {
    return 'FII de papel: vacância física costuma não se aplicar — veja a composição em CRIs e recebíveis.';
  }
  return null;
}
