import '../account_labels.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../api_account_repository.dart';

/// An industry as the pickers offer it: the key the API stores, and its name.
typedef IndustryOption = (String key, String label);

/// The industries the create page offers.
///
/// The website reads Master Data's live list (`GET /masters`, public), because
/// `CreateMyCompanyDto.industry` is checked against that list as it is now
/// (`@IsMasterKey('INDUSTRY')`), so an industry staff add is accepted at once
/// and one they retire is refused. Until it arrives (or when it cannot be read,
/// or on the sample repository), the list the platform was seeded with
/// (`industries`) keeps the picker from being empty, as the website does.
Future<List<IndustryOption>> loadIndustries(AccountRepository repository) async {
  if (repository is! ApiAccountRepository) return industries;
  try {
    final res = await repository.api.dio.get<Map<String, dynamic>>('/masters');
    final rows = <IndustryOption>[
      for (final row in (res.data?['industries'] as List? ?? const []))
        if (row is Map && row['key'] is String && row['name'] is String)
          (row['key'] as String, row['name'] as String),
    ];
    return rows.isEmpty ? industries : rows;
  } catch (_) {
    return industries;
  }
}

/// The name of an industry key among [options], else the seeded label, else the key.
String industryName(String? key, List<IndustryOption> options) {
  for (final (k, label) in options) {
    if (k == key) return label;
  }
  return industryLabel(key) ?? '';
}

/// The company page a lookalike or a search hit stands for, as a search hit.
CompanyHit hitOf(CompanyLookalike l) => CompanyHit(id: l.id, name: l.name, city: l.city, logoUrl: l.logoUrl);
