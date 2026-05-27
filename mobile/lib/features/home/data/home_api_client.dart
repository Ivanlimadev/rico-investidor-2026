import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';

class HomeApiClient {
  HomeApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<HomeFeed> getFeed() {
    return _client.getJson(
      '/v1/home/feed',
      fromJson: HomeFeed.fromJson,
    );
  }
}

final homeApiClient = HomeApiClient();
