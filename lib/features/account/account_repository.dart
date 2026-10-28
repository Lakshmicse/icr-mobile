import 'account_models.dart';

/// Where the account screens read and write: the API, or the bundled sample
/// member for design review. One interface for sign-up's last step, the
/// person's own profile, other members' pages, companies and settings, since
/// they share the person and their career lists.
abstract class AccountRepository {
  // --- lookups -----------------------------------------------------------------------------------------------

  /// The suggested job titles (`GET /job-titles`), in the staff's order.
  Future<List<String>> jobTitles();

  /// Company pages whose name matches (`GET /companies?search=`), eight at most.
  Future<List<CompanyHit>> searchCompanies(String query);

  /// Every active city (`GET /locations/cities`).
  Future<List<CityOption>> cities();

  // --- my profile --------------------------------------------------------------------------------------------

  /// `GET /users/me/profile`.
  Future<MyProfile> myProfile();

  /// `GET /profile/experience`, in date order.
  Future<List<Experience>> experience();

  /// `GET /profile/education`.
  Future<List<Education>> education();

  /// `GET /profile/career-breaks`.
  Future<List<CareerBreak>> careerBreaks();

  /// `GET /profile/links`.
  Future<ProfileLinks> links();

  /// `GET /credentials/me`.
  Future<List<Credential>> credentials();

  /// `PATCH /users/me` with only the fields given; the profile as saved.
  Future<MyProfile> updateMe(Map<String, Object?> patch);

  /// `PATCH /users/me/resume` with only the fields given; the profile as saved.
  Future<MyProfile> updateResume(Map<String, Object?> patch);

  /// `PUT /profile/experience`: the whole list, replaced. Every id changes.
  Future<List<Experience>> saveExperience(List<Experience> rows);

  /// `PUT /profile/education`.
  Future<List<Education>> saveEducation(List<Education> rows);

  /// `PUT /profile/career-breaks`.
  Future<List<CareerBreak>> saveCareerBreaks(List<CareerBreak> rows);

  /// `PATCH /profile/links`: all five, `''` clearing one.
  Future<ProfileLinks> saveLinks(Map<String, String> links);

  /// `POST /uploads` (multipart `file`, `?purpose=` when given).
  Future<UploadedFile> upload(PickedPhoto file, {String? purpose});

  /// `POST /users/me/phone/send-otp`; the code itself off production.
  Future<String?> sendPhoneCode(String phone);

  /// `POST /users/me/phone/verify-otp`: saves the number, confirmed.
  Future<void> verifyPhoneCode(String phone, String code);

  /// `POST /credentials/me`.
  Future<void> addCredential(CredentialDraft draft);

  /// `PATCH /credentials/me/:id`.
  Future<void> updateCredential(String id, CredentialDraft draft);

  /// `DELETE /credentials/me/:id`; the code also taken off a mentor profile, if any.
  Future<String?> deleteCredential(String id);

  // --- other members -----------------------------------------------------------------------------------------

  /// `GET /members/:id` (the id or the profile slug). A hidden profile is a 404.
  Future<MemberProfile> member(String idOrSlug);

  /// `POST /members/:id/follow`; the member's counts after it.
  Future<FollowState> follow(String memberId);

  /// `DELETE /members/:id/follow`.
  Future<FollowState> unfollow(String memberId);

  /// The member's latest discussions (`GET /forum/threads?authorId=`).
  Future<List<ForumPost>> memberPosts(String userId, {int limit = 5});

  /// `POST /messaging/conversations`: the plain thread with this member (an
  /// existing one is reused). Returns its id.
  Future<String> startConversation(String userId);

  // --- companies ---------------------------------------------------------------------------------------------

  /// `GET /me/companies`.
  Future<MyCompanies> myCompanies();

  /// `POST /me/companies/switch`; null is the personal account. A fresh token pair.
  Future<SessionTokens> switchCompany(String? companyId);

  /// `POST /me/companies/:id/leave`. A fresh token pair.
  Future<SessionTokens> leaveCompany(String companyId);

  /// `DELETE /me/companies/requests/:id`; the list as it now stands.
  Future<MyCompanies> withdrawRequest(String companyId);

  /// `POST /me/companies`: the founder becomes its admin and acts for it. A fresh token pair.
  Future<SessionTokens> createCompany(CompanyDraft draft);

  /// `GET /me/companies/lookalikes`: companies already on ICR that look like this one.
  Future<List<CompanyLookalike>> lookalikes({String? name, String? website});

  /// `POST /team/companies/:id/join-requests`: asks the company's admins to add the person.
  Future<void> requestToJoin(String companyId, {String? note});

  // --- settings ----------------------------------------------------------------------------------------------

  /// The language the account was saved with (`locale` of `GET /auth/me`), or
  /// null when none was chosen: ICR then follows the phone.
  Future<String?> accountLocale();

  /// `GET /notifications/preferences`.
  Future<List<NotificationPreference>> notificationPreferences();

  /// `PUT /notifications/preferences` with the rows given; every row as saved.
  Future<List<NotificationPreference>> saveNotificationPreferences(List<NotificationPreference> rows);

  /// `GET /users/me/export`: the personal data ICR holds, as JSON.
  Future<Map<String, dynamic>> exportData();

  /// `DELETE /users/me`: the account is anonymised and closed, and every session ends.
  Future<void> deleteAccount();
}
