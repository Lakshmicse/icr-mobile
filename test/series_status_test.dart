import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/series_status.dart';

/// The owner, 16 Nov 2026, on the mentor's group sessions: "Completed" once all the sessions are done; "In Progress"
/// once they have started and are not all done. "Held" is gone.
void main() {
  final now = DateTime(2026, 11, 16, 12);
  SeriesDay day(int daysFromNow, [String status = 'SCHEDULED']) =>
      (at: now.add(Duration(days: daysFromNow)), status: status);

  test('a series not yet begun is open for registration', () {
    expect(seriesState('SCHEDULED', [day(2), day(9)], now), SeriesState.open);
    expect(SeriesState.open.label, 'Open for Registration');
  });

  test('a series with a day done or begun, and days still to come, is in progress', () {
    expect(seriesState('SCHEDULED', [day(-7, 'COMPLETED'), day(3)], now), SeriesState.inProgress);
    expect(seriesState('SCHEDULED', [day(-1), day(6)], now), SeriesState.inProgress, reason: 'begun, not yet closed');
    expect(SeriesState.inProgress.label, 'In Progress');
  });

  test('a series whose days are all done is completed, before or after the mentor closes it', () {
    expect(seriesState('COMPLETED', [day(-9, 'COMPLETED')], now), SeriesState.completed);
    expect(
      seriesState('SCHEDULED', [day(-9, 'COMPLETED'), day(-2, 'COMPLETED'), day(-1, 'CANCELLED')], now),
      SeriesState.completed,
      reason: 'a cancelled day counts for neither',
    );
    expect(SeriesState.completed.label, 'Completed');
  });

  test('a draft and a cancelled series keep their own words', () {
    expect(seriesState('DRAFT', [day(-3)], now).label, 'Draft');
    expect(seriesState('CANCELLED', [day(4)], now).label, 'Cancelled');
  });
}
