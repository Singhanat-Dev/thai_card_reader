import 'card_data.dart';

class CardReadResult {
  final CardData? data;
  final String? error;

  bool get isSuccess => data != null;

  const CardReadResult.success(CardData d)
      : data = d,
        error = null;

  const CardReadResult.failure(String e)
      : data = null,
        error = e;
}
