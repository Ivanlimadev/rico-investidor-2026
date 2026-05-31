/// Mínimo de caracteres para iniciar a busca global (a partir da 2ª letra).
const kMinAssetSearchLength = 2;

const kAssetSearchDebounce = Duration(milliseconds: 220);

const kMaxSearchResults = 24;

const kMaxSearchFavoritesDisplay = 12;

const kSearchFavoritesGridColumns = 3;

/// Grid compacto da aba Buscar (favoritos + resultados).
const kSearchGridSpacing = 8.0;

/// Cards quase quadrados — logo ocupa boa parte da largura.
const kSearchGridChildAspectRatio = 0.98;

/// Logo ≈ metade da largura da célula.
const kSearchGridLogoWidthRatio = 0.52;

const kSearchGridMinLogoSize = 46.0;

const kSearchGridMaxLogoSize = 58.0;

const kUnifiedAssetSearchHint = 'Buscar qualquer ativo (ação, cripto, FII, EUA…)';

bool unifiedSearchActive(String query) => query.trim().length >= kMinAssetSearchLength;

double searchGridCellWidth({
  required double gridWidth,
  required int columns,
  double spacing = kSearchGridSpacing,
}) {
  if (columns <= 0 || gridWidth <= 0) return gridWidth;
  return (gridWidth - spacing * (columns - 1)) / columns;
}

double searchGridLogoSizeForCellWidth(double cellWidth) {
  return (cellWidth * kSearchGridLogoWidthRatio).clamp(kSearchGridMinLogoSize, kSearchGridMaxLogoSize);
}

double searchGridFlagSizeForLogo(double logoSize) {
  return (logoSize * 0.30).clamp(10.0, 14.0);
}

double searchGridLabelFontSize(double logoSize) {
  return (logoSize * 0.24).clamp(11.0, 13.0);
}

double searchGridPriceFontSize(double logoSize) {
  return (logoSize * 0.21).clamp(9.5, 11.5);
}
