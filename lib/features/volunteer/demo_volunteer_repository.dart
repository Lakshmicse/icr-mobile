import '../contact/contact_models.dart' show ContactSender;
import 'volunteer_models.dart';
import 'volunteer_repository.dart';

/// The sample source: a member with 12 hours of CPD (8.5 this year, against a target of 15), four chapters,
/// and an application that is kept in memory.
class DemoVolunteerRepository implements VolunteerRepository {
  DemoVolunteerRepository();

  /// What was sent, for tests.
  final sent = <VolunteerApplication>[];

  @override
  Future<CpdSummary?> cpd() async => CpdSummary(
    totalHours: 12,
    hoursThisYear: 8.5,
    bySource: const [(source: 'COURSE', hours: 6.5), (source: 'EVENT', hours: 3.5), (source: 'MENTORING', hours: 2)],
    recent: [
      CpdEntry(
        id: 'c1',
        hours: 3,
        source: 'COURSE',
        description: 'Course · Facility Management Essentials',
        awardedAt: DateTime.utc(2026, 8, 20, 9),
      ),
      CpdEntry(
        id: 'c2',
        hours: 3.5,
        source: 'EVENT',
        description: 'Event · Workplace Experience Conclave 2026',
        awardedAt: DateTime.utc(2026, 6, 5, 9),
      ),
      CpdEntry(
        id: 'c3',
        hours: 2,
        source: 'MENTORING',
        description: 'Mentoring session with Srikanth Sriramagiri',
        awardedAt: DateTime.utc(2026, 3, 12, 9),
      ),
    ],
    year: 2026,
    targetHours: 15,
    progress: 8.5 / 15,
    targetIsDefault: false,
  );

  @override
  Future<ContactSender?> sender() async =>
      const ContactSender(name: 'Nikhil Majjagi', email: 'nikhil@techcorp.example', phone: '+919876543210');

  @override
  Future<List<ChapterChoice>> chapters() async => const [
    ChapterChoice(id: 'ch-bengaluru', name: 'ICR Bengaluru Chapter', city: 'Bengaluru'),
    ChapterChoice(id: 'ch-delhi', name: 'ICR Delhi NCR Chapter', city: 'Delhi NCR'),
    ChapterChoice(id: 'ch-hyderabad', name: 'ICR Hyderabad Chapter', city: 'Hyderabad'),
    ChapterChoice(id: 'ch-mumbai', name: 'ICR Mumbai Chapter', city: 'Mumbai'),
  ];

  @override
  Future<void> apply(VolunteerApplication application) async => sent.add(application);

  @override
  Future<int> unreadNotifications() async => 3;
}
