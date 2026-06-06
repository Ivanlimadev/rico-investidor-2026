import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/models/fii_models.dart';

typedef FiiMagicNumberResult = AssetMagicNumberResult;

FiiMagicNumberResult? computeMagicNumber({
  required FiiDetail detail,
  FiiDistributions? distributions,
  List<FiiHistoryPoint> history = const [],
}) {
  return magicNumberFromFii(
    detail: detail,
    distributions: distributions,
    history: history,
  );
}
