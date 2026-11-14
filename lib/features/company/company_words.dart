/// The company workspace's words. The website's `company` namespace is the source, with the owner's recommended
/// wording laid over it (the company-workspace review of Nov 2026: "View Public Profile", "Trust & Verification",
/// "Company Overview", "Supplier Trust Level", "Completed / Pending Upload"…). A card reads from here, never types
/// a sentence of its own, so the page and its tests say one thing.
library;

class CompanyWords {
  CompanyWords._();

  // --- the header ----------------------------------------------------------------------------------------------
  static const barTitle = 'My Company';
  static const eyebrow = 'COMPANY PROFILE';
  static const yourCompany = 'Your company';
  static const verifiedChip = 'Verified';
  static const sharedNote = 'Changes are visible to all company members.';
  static const createNote = 'Add your company’s details below to create its page.';
  static const viewPublicProfile = 'View Public Profile';
  static const switchCompany = 'Switch Company';
  static const changeLogo = 'Change company logo';
  static const addLogo = 'Add a company logo';

  // --- the tabs ------------------------------------------------------------------------------------------------
  static const tabOverview = 'Overview';
  static const tabDetails = 'Company Details';
  static const tabOrganizationDetails = 'Organization Details';
  static const tabCertifications = 'Certifications';
  static const tabTeam = 'Team';

  // --- the overview --------------------------------------------------------------------------------------------
  static const completenessTitle = 'Company Profile Completeness';
  static const completenessCaption = 'See how much of your company profile is visible to buyers and candidates.';
  static String percentComplete(int score) => '$score% Complete';
  static const completenessNoCompany = 'Add the company’s details to start its page.';
  static const addDetails = 'Add Details';
  static const add = 'Add';
  static const editCompanyProfile = 'Edit Company Profile';
  static String more(int n) => n == 1 ? 'and 1 more item' : 'and $n more items';

  static const trustTitle = 'Trust & Verification';
  static const trustCaption = 'Your Company’s Verification Status';
  static const companyVerification = 'Company Verification';
  static const notFiledLabel = 'Not Filed';
  static const checkUnavailable = 'Unable to load the company check.';
  static String checkNotFiled(String company) => 'Needed before $company can publish jobs.';
  static const checkInReview = 'ICR is reviewing what was filed.';
  static const checkDocsRequested = 'ICR has asked for more information.';
  static const checkVerified = 'Your company is verified and eligible to publish jobs on ICR.';
  static const checkRejected = 'It can be corrected and filed again.';
  static const checkSuspended = 'ICR withdrew the verification. Resolve the issue in ICR’s note and file again.';
  static String checkReverify(String date) => 'Verified. ICR asked for new documents by $date.';
  static const actionView = 'View Details';
  static const actionVerify = 'Verify';
  static const actionRespond = 'Respond';
  static const actionResubmit = 'Resubmit';
  static const supplierTrustLevel = 'Supplier Trust Level';
  static String levelOf(String level, int rank) => '$level – Level $rank';
  static String trustScore(int score) => 'Trust Score $score';
  static String notSelling(String company) => 'Supplier levels apply once $company sells on the Marketplace.';
  static const upgradeTrustLevel = 'Upgrade Trust Level';
  static const supplierLevelHint =
      'Build your supplier credentials to unlock higher trust levels and improve visibility.';
  static const docsRequestedSupplier = 'ICR has asked for supplier documents.';

  static const overviewTitle = 'Company Overview';
  static const overviewCaption = 'A snapshot of your company’s presence and activity on ICR.';
  static const figureMembers = 'Members';
  static const figureOffices = 'Office Locations';
  static const figureOpenJobs = 'Active Job Listings';
  static const figureProducts = 'Products Listed';
  static const figureServices = 'Services Listed';
  static const figureCertificates = 'Certifications Uploaded';

  static const membershipTitle = 'Membership & Subscriptions';
  static const membershipCaption = 'View and manage your company’s active plans.';
  static const jobPortalPlan = 'Job Portal Plan';
  static const marketplacePlan = 'Marketplace Plan';
  static const freePlan = 'Free';
  static const seePlans = 'See Plans';
  static const managePlan = 'Manage Plan';
  static String renewsOn(String date) => 'Renews on $date';
  static String endsOn(String date) => 'Ends on $date';
  static const plansAndReceipts = 'View Plans & Payment History';

  static const publicPageTitle = 'Company Public Profile';
  static const publicPageCaption = 'Manage and share your company’s public profile with buyers and visitors.';
  static const profileUrl = 'Profile URL';
  static const copyProfileLink = 'Copy Profile Link';
  static const linkCopied = 'Link copied.';

  // --- the company check ---------------------------------------------------------------------------------------
  static const verificationCaption = 'A one-time check to confirm your company’s identity and business credentials.';
  static const readyToSubmit = 'Ready to Submit';
  static String notFiledBody(String company) =>
      'Complete the items below, then submit. Jobs for $company can be drafted in the meantime. They go live once ICR has '
      'confirmed the company.';
  static const readyBody = 'All details the check needs are complete. Submit it below.';
  static const readyBodyMember = 'All details the check needs are complete. Your company admin submits it.';
  static String verifiedOn(String date) =>
      'Verified on $date. Your company can publish jobs and connect with candidates on ICR.';
  static String submittedOn(String date) =>
      'Submitted on $date. ICR usually replies within one business day, by email and here.';
  static const submittedBody =
      'We are checking your details. This usually takes one business day. We will email you when it is complete.';
  static const docsRequestedBody = 'Update the details below and resubmit.';
  static const rejectedBody = 'Correct the details below and resubmit.';
  static const suspendedBody = 'ICR withdrew this company’s verification. Resolve the issue below and file again.';
  static const suspendedOverdue =
      'The documents ICR asked for did not arrive by the due date, so the company’s verification was withdrawn. '
      'Upload them below and file again.';
  static String reverifyOpenBody(String company, String documents, String date) =>
      'ICR asked for new copies of: $documents. Upload them below and send them by $date. $company stays verified '
      'until then.';
  static String reverifySentBody(String company, String date) =>
      'New documents sent on $date. ICR is reviewing them. $company stays verified in the meantime.';
  static String reverifyChip(String date) => 'Re-Verify by $date';
  static const reverifySentChip = 'Re-Verification Under Review';
  static String attempt(int n) => 'Attempt $n';
  static const reviewerNote = 'ICR’s note';
  static const reviewSnapshot =
      'ICR is reviewing the details as they were when submitted. Changes saved now are not part of this review.';
  static const filedByYourAdmin = 'Your company admin files and updates this check.';
  static String progress(int done, int total) => '$done of $total ready';
  static String notGstRegistered(String company) => '$company is not registered for GST';
  static const whatVerificationUnlocks = 'What Verification Unlocks';
  static const submitForVerification = 'Submit for Verification';
  static const resubmit = 'Resubmit';
  static const sendToIcr = 'Send to ICR';
  static const submitting = 'Submitting…';
  static String completeToSubmit(int n) =>
      n == 1 ? 'Complete 1 more item to submit.' : 'Complete $n more items to submit.';
  static const filed = 'Submitted for verification. ICR usually replies within one business day.';
  static const needHelp = 'Need help with verification?';
  static const contactSupport = 'Contact ICR Support';
  static const plansNote =
      'Contact details and messaging also need a Silver or higher plan. Certified, Preferred and Elite supplier '
      'levels are earned through a separate supplier review.';

  // --- the company details -------------------------------------------------------------------------------------
  static const detailsTitle = 'Company Details';
  static const detailsBlurb =
      'Add your organisation’s key information to help buyers and candidates understand your business.';
  static const legalTitle = 'Legal & Registration Details';
  static const legalBlurb = 'Enter your company’s registered details exactly as they appear on official documents.';
  static const locationTitle = 'Business Location & Coverage';
  static const locationBlurb = 'Add your registered office address and indicate where your company operates.';
  static const contactTitle = 'Company Contact Details';
  static const contactBlurb =
      'Provide an authorised contact for ICR communications and business enquiries. These details are not displayed '
      'on your public profile.';
  static const companyLogo = 'Company Logo';
  static const uploadLogo = 'Upload Logo';

  /// The owner's doc says SVG; the upload API takes PNG, JPEG and WEBP only, so the line names those.
  static const logoHelp = 'PNG, JPG or WEBP · Maximum 5 MB';
  static const saveChanges = 'Save Changes';
  static const saved = 'Saved.';
  static const privateNote = 'Private. Visible only to ICR’s review team and your company’s admins.';
  static const notSet = 'Not added yet';
  static const notSpecified = 'Not specified';
  static const taxIdsLocked = 'PAN and GSTIN cannot be edited after verification. Contact ICR Support for changes.';
  static String missingLead(int n) =>
      n == 1 ? '1 detail is missing from the company page.' : '$n details are missing from the company page.';
  static const notUploaded = 'Not uploaded';
  static const upload = 'Upload';
  static const replace = 'Replace';
  static const remove = 'Remove';
  static const uploading = 'Uploading…';
  static String reverifyDocument(String date) =>
      'ICR asked for a new copy. Upload it by $date, then send it with the button on the verification card.';

  // --- the certifications tab ----------------------------------------------------------------------------------
  static const supplierLevelsTitle = 'Supplier Trust Levels';
  static const supplierLevelsCaption =
      'Certified, Preferred and Elite: the levels above Verified that buyers filter on in the Marketplace, earned '
      'with documents and certifications.';
  static const verificationStatus = 'Your Verification Status';
  static const verificationStatusCaption = 'Your current verification status and supplier trust level';
  static const badgeCaption = 'ICR Verified Supplier';
  static String applyFor(String level) => 'Apply for $level Status';
  static const uploadRequestedDocuments = 'Upload Requested Documents';
  static String upgradeUnderReview(String level) => 'Upgrade to $level is under review';
  static String reviewTeamNeeds(String level) =>
      'The ICR review team needs more documents to continue your $level review:';
  static const pleaseUploadRequested = 'Upload the requested documents.';
  static String requirementsFor(String level) => '$level Level Requirements';
  static String underReviewFor(String level) => 'Under review for $level';
  static String doneOfTotal(int done, int total) => '$done of $total completed';
  static const awardedByIcr =
      'Preferred and Elite levels are awarded by the ICR team based on sustained performance and buyer feedback. '
      'They cannot be requested. This is what the team reviews.';
  static const statusCompleted = 'Completed';
  static const statusUnderReview = 'Under Review';
  static const statusPendingUpload = 'Pending Upload';

  /// A missing item put right on the profile or the listing, not by an upload (the review: "Missing → Pending").
  static const statusPending = 'Pending';
  static const addDetailsFix = 'Add Details';
  static const editListing = 'Edit Listing';
  static const addCertificationFix = 'Add Certification';
  static const uploadDocument = 'Upload Document';
  static const topLevelReached = 'Top trust level reached';
  static const reviewsTheList =
      'ICR reviews these details and supporting documents to determine your vendor partner trust level.';
  static const stillMissing = 'Still missing:';
  static const uploadAtLeastOne = 'Upload at least one supporting document.';
  static const uploadTheDocuments =
      'Upload the documents above (licences, insurance, financials). Name each file for what it is. The checklist '
      'recognises it by name. Certifications are recorded lower on this page, not here. Our team reviews them '
      'and updates your level.';
  static const submitForReview = 'Submit for Review';
  static const businessExperience = 'Business Experience';

  static const historyTitle = 'Verification History';
  static const historyCaption = 'Every review decision on your listing.';

  static const renewalsTitle = 'Certificates & Renewals';
  static const renewalsCaption = 'Track certificate expiry dates and upcoming renewals.';
  static const renewalsEmpty =
      'No certificates with expiry dates added yet. Add your certificates to track validity and renewal dates.';
  static String expiredAlert(int n) =>
      '$n ${n == 1 ? 'certification has' : 'certifications have'} expired. Record the renewed certificate below to '
      'stay compliant.';
  static String soonAlert(int n, int days) =>
      '$n ${n == 1 ? 'certification expires' : 'certifications expire'} within $days days.';
  static const chipExpired = 'Expired';
  static const chipExpiresToday = 'Expires Today';
  static String chipDaysLeft(int days) => '${days}d left';

  static const certificationsTitle = 'Company Certifications';
  static const certificationsBlurb =
      'Add certifications held by your company and upload the supporting certificates. Verified certifications will '
      'be displayed on your company profile for buyer reference.';
  static const addCertification = 'Add Certification';
  static const nothingRecorded =
      'No certifications recorded yet. Add one your company holds and upload the certificate.';
  static const onYourProfile = 'On Your Public Profile';
  static const showsOnceVerified = 'Shows Once Your Company Is Verified';
  static const showsOnceVerifiedHelp =
      'ICR approves your company’s whole profile, certificates included. These appear on your company page and in the '
      'Marketplace as soon as your company is verified.';
  static const expired = 'Expired';
  static const expiredHelp = 'Record the renewed certificate to show it again.';
  static const pendingUpload = 'Certificates Pending Upload';
  static const pendingUploadHelp =
      'You have indicated that your company holds the following certification. Upload the certificate to complete '
      'your record.';
  static const uploadCertificate = 'Upload Certificate';
  static const replacedByRenewal = 'Replaced by a Renewal';
  static const notAccepted = 'Not Accepted';
  static String validTo(String date) => 'valid to $date';
  static const noExpiry = 'no expiry';
  static String supersededLine(String validity, String date) => '$validity · replaced $date';
  static const certificationsNote =
      'ICR does not issue certifications. Submitted documents are subject to verification as part of your company '
      'profile review. ICR may request additional information or mark documents as unverified if requirements are '
      'not met.';
  static const certificationsPrivacy =
      'Privacy: Uploaded documents are confidential and accessible only to your company and authorised ICR '
      'personnel.';
  static const certificationField = 'Certification';
  static const chooseACertification = 'Select a certification.';
  static const certificateField = 'Certificate';
  static const attachTheCertificate = 'Attach the certificate.';
  static const uploadCertificateHelp =
      'Upload the certificate from your issuing body. It is added to your company’s record immediately. ICR does '
      'not issue certifications.';
  static const issuingBody = 'Issuing Body (Optional)';
  static const issuerFilledIn =
      'Filled in from the certification. Change it if your certificate names a different body.';
  static const issuerAnyAccredited = 'Any accredited body may issue this certification. Select yours or enter another.';
  static const issuerWho = 'The body that issued the certificate, e.g. BSI or TUV SUD.';
  static const certificateNumber = 'Certificate Number (Optional)';
  static const certificateNumberHelp = 'The number printed on the certificate, so ICR can check it.';
  static const issueDate = 'Issue Date (Optional)';
  static const issuedOnHelp = 'The date the issuing body granted it.';
  static const expiryDate = 'Expiry Date (Optional)';
  static const expiresAtHelp = 'Leave blank if the certificate does not expire.';
  static const noteField = 'Note (Optional)';
  static const alreadyHeld = 'Your company already holds this certification.';
  static String alreadyHeldValidTo(String date) =>
      'Your company already holds this certification, valid to $date. Record it again when you renew it.';
  static const thatDidNotSave = 'Unable to save. Try again.';

  // --- the supplier listing notice and no company --------------------------------------------------------------
  static const noListingTitle = 'Your Company Has No Supplier Listing Yet';
  static const noListingBody =
      'Certifications come with the listing: it is how buyers find you, and how your bids and replies are filed. ICR '
      'reviews it, and once verified you can respond to requirements.';
  static const startSelling = 'Start Selling';
  static const starting = 'Starting…';
  static const askAdminToSell = 'Ask your company’s admin to start selling on ICR.';
  static const couldNotStart = 'Unable to start selling. Try again.';

  static const noCompanyLead = 'A company’s details, supplier listing and verification belong to a company.';
  static const personalAccountTitle = 'You Are Using Your Personal Account';
  static String switchDescription(String lead) => '$lead Switch to one of your companies to work on its behalf.';
  static const notLinkedTitle = 'Your Account Isn’t Linked to a Company';
  static String inviteOrCreateDescription(String lead) =>
      '$lead If your company is already on ICR, ask its admin to invite this email address. Accepting the invite '
      'links your account. If it is not on ICR yet, create it and you become its admin.';
  static String inviteDescription(String lead) =>
      '$lead If your company is on ICR, ask its admin to invite this email address. Accepting the invite links your '
      'account.';
  static const createACompany = 'Create a Company';
  static const contactSupportPlain = 'Contact Support';
  static const notAnEditorTitle = 'Your Role Does Not Edit the Company Profile';
  static String notAnEditorBody(String company) =>
      'The company page of $company is managed by its admins, sellers and buyers. Ask an admin to change it.';
}
