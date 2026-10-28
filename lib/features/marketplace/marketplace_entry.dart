import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'api_marketplace_repository.dart';
import 'demo_marketplace_repository.dart';
import 'marketplace_controller.dart';
import 'marketplace_repository.dart';

final _apiRepositories = Expando<ApiMarketplaceRepository>('marketplace');
DemoMarketplaceRepository? _demo;

/// The repository the Marketplace's doors use when none is passed: the one the
/// Marketplace tab already holds (a [MarketplaceController] above), else one
/// provided above (`Provider<MarketplaceRepository>`), else one per signed-in API
/// client, else the design's sample content in a demo build.
MarketplaceRepository marketplaceRepositoryOf(BuildContext context) {
  final market = Provider.of<MarketplaceController?>(context, listen: false);
  if (market != null) return market.repository;
  final provided = Provider.of<MarketplaceRepository?>(context, listen: false);
  if (provided != null) return provided;
  if (AppConfig.demo) return _demo ??= DemoMarketplaceRepository();
  final api = context.read<ApiClient>();
  return _apiRepositories[api] ??= ApiMarketplaceRepository(api: api);
}
