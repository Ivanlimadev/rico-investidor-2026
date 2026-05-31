/// Mínimo de caracteres para iniciar a busca global (a partir da 2ª letra).
const kMinAssetSearchLength = 2;

const kAssetSearchDebounce = Duration(milliseconds: 280);

const kUnifiedAssetSearchHint = 'Buscar qualquer ativo (ação, cripto, FII, EUA…)';

bool unifiedSearchActive(String query) => query.trim().length >= kMinAssetSearchLength;
