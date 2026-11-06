import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'api_support_repository.dart';
import 'demo_support_repository.dart';
import 'support_repository.dart';

/// The support desk's calls for this screen: the API through the app's client, or the sample in demo mode
/// (`FEED_SOURCE=demo`).
SupportRepository supportRepositoryOf(BuildContext context) => AppConfig.demo
    ? DemoSupportRepository()
    : ApiSupportRepository(api: Provider.of<ApiClient>(context, listen: false));
