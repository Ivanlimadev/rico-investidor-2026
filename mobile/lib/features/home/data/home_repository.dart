import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/home/data/home_api_client.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';

class HomeRepository {
  HomeRepository({HomeApiClient? api}) : _api = api ?? homeApiClient;

  final HomeApiClient _api;
  final _feedCache = SessionCache<HomeFeed>(ttl: const Duration(minutes: 5));
  Future<HomeFeed>? _feedFuture;

  Future<HomeFeed> loadFeed() {
    final cached = _feedCache.get();
    if (cached != null) return Future.value(cached);
    return _feedFuture ??= _fetchFeed();
  }

  Future<HomeFeed> _fetchFeed() async {
    try {
      final feed = await _api.getFeed();
      _feedCache.set(feed);
      return feed;
    } finally {
      _feedFuture = null;
    }
  }

  void invalidateFeed() {
    _feedCache.clear();
    _feedFuture = null;
  }
}

final homeRepository = HomeRepository();
