import '../../../core/config.dart';
import '../../feed/feed_models.dart';

/// Someone the "@" picker offers (`GET /members/mentionable`).
class MentionPerson {
  const MentionPerson({required this.id, required this.firstName, required this.lastName, this.photo, this.headline});

  factory MentionPerson.fromJson(Map<String, dynamic> json, {String? apiBase}) {
    final url = AppConfig.absoluteUrl(json['avatarUrl'] as String?, apiBase: apiBase);
    final headline = (json['headline'] as String?)?.trim();
    return MentionPerson(
      id: json['id'] as String,
      firstName: (json['firstName'] as String? ?? '').trim(),
      lastName: (json['lastName'] as String? ?? '').trim(),
      photo: url == null ? null : FeedPicture.network(url),
      headline: headline == null || headline.isEmpty ? null : headline,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final FeedPicture? photo;
  final String? headline;

  /// "First Last": what "@" is followed by in the words.
  String get name => '$firstName $lastName'.trim();

  /// As the feed's avatars and names draw a person.
  FeedAuthor get author =>
      FeedAuthor(id: id, name: name.isEmpty ? 'ICR member' : name, headline: headline, photo: photo);

  Mention get mention => Mention(id: id, name: name);
}

/// Asks the forum who matches what was typed after the "@".
typedef MentionSearch = Future<List<MentionPerson>> Function(String query);
