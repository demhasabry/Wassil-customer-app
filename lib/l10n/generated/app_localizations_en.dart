// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wassil';

  @override
  String get newRiderLabel => 'New';

  @override
  String get vehicleColorWhite => 'White';

  @override
  String get vehicleColorBlack => 'Black';

  @override
  String get vehicleColorSilver => 'Silver';

  @override
  String get vehicleColorRed => 'Red';

  @override
  String get vehicleColorBlue => 'Blue';

  @override
  String get vehicleColorGreen => 'Green';

  @override
  String get vehicleColorYellow => 'Yellow';

  @override
  String get vehicleColorGrey => 'Grey';

  @override
  String get vehicleColorOther => 'Other';

  @override
  String get splashTagline => 'Your delivery, your price.';

  @override
  String get skipButton => 'Skip';

  @override
  String get phoneLoginHeading => 'Enter your name and phone number';

  @override
  String get fullNameHint => 'Full name';

  @override
  String get phoneHint => '09XXXXXXXX';

  @override
  String get sendCodeButton => 'Send code';

  @override
  String get enterNameError => 'Enter your name';

  @override
  String get enterPhoneError => 'Enter your phone number';

  @override
  String get otpTitle => 'Verify code';

  @override
  String otpCodeSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get otpHint => '123456';

  @override
  String get verifyButton => 'Verify';

  @override
  String get enterSixDigitCode => 'Enter the 6-digit code';

  @override
  String get invalidCodeError => 'Invalid code. Try again.';

  @override
  String get verificationFailedError => 'Verification failed. Try again.';

  @override
  String get profileTitle => 'My Profile';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get faqButton => 'Frequently Asked Questions';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get newDeliveryRequestTitle => 'New delivery request';

  @override
  String get zoneLabel => 'Zone';

  @override
  String get postRequestButton => 'Post request & start bidding';

  @override
  String get moreOptionsButton => 'More options';

  @override
  String get moreOptionsTitle => 'More options';

  @override
  String get basePriceWord => 'Base price';

  @override
  String get doneButton => 'Done';

  @override
  String get orderHistoryTooltip => 'Order History';

  @override
  String get profileTooltip => 'Profile';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get retryButton => 'Retry';

  @override
  String get saveButton => 'Save';

  @override
  String get backButton => 'Back';

  @override
  String get reasonOther => 'Other';

  @override
  String get reasonChangedMind => 'Changed my mind';

  @override
  String get reasonNoLongerNeeded => 'No longer needed';

  @override
  String get reasonFoundAnotherWay => 'Found another way';

  @override
  String get reasonRiderTakingTooLong => 'Rider taking too long';

  @override
  String get reportProblemTitle => 'Report a Problem';

  @override
  String get reportReasonItemDamaged => 'Item damaged';

  @override
  String get reportReasonWrongItem => 'Wrong item delivered';

  @override
  String get reportReasonRiderUnprofessional => 'Rider was unprofessional';

  @override
  String get reportReasonNeverReceived => 'Never received the item';

  @override
  String biddingWaitingTitle(String time) {
    return 'Waiting for bids ($time)';
  }

  @override
  String get biddingClosedTitle => 'Bidding closed';

  @override
  String get bidsHeading => 'Bids';

  @override
  String get cheapestFirstLabel => 'Cheapest first';

  @override
  String get cancelRequestDialogTitle => 'Cancel this request?';

  @override
  String get cancelRequestError => 'Could not cancel this request.';

  @override
  String get acceptBidError =>
      'Could not accept this bid. It may have expired.';

  @override
  String get noBidsYetWaiting =>
      'No bids yet — riders nearby are being notified.';

  @override
  String get noBidsTimedOut =>
      'No riders bid in time. You can post the request again.';

  @override
  String get boostPriceButton => 'Increase Price to Attract Riders';

  @override
  String get boostPriceDialogTitle => 'Increase your price';

  @override
  String boostPriceDialogHint(String currentPrice) {
    return 'Your current offer of $currentPrice SDG didn\'t attract any riders. A higher price may get faster offers.';
  }

  @override
  String get newPriceLabel => 'New price';

  @override
  String get boostPriceConfirmButton => 'Repost with New Price';

  @override
  String get boostPriceError => 'Could not update the price. Please try again.';

  @override
  String etaMinutesLabel(int minutes) {
    return '$minutes min ETA';
  }

  @override
  String get etaUnavailable => 'ETA unavailable';

  @override
  String get acceptButton => 'Accept';

  @override
  String get activeOrderTitle => 'Active Order';

  @override
  String get activeDeliveryInProgress =>
      'You already have a delivery in progress.';

  @override
  String get viewOrderButton => 'View Order';

  @override
  String get calculatingPrice => 'Calculating price...';

  @override
  String get priceCalculationError =>
      'Could not calculate a price — check your connection and try again.';

  @override
  String estimatedDistanceLabel(String distance) {
    return 'Estimated distance: $distance km';
  }

  @override
  String basePriceLabel(String price) {
    return 'Base price: $price SDG';
  }

  @override
  String maxBidLabel(String maxBid) {
    return 'Riders may bid anywhere up to $maxBid SDG';
  }

  @override
  String get addressNotFoundError =>
      'Couldn\'t find that address — tap the map to set the pin manually.';

  @override
  String get pickupAddressTitle => 'Pickup address';

  @override
  String get dropoffAddressTitle => 'Drop-off address';

  @override
  String get orderDetailTitle => 'Order details';

  @override
  String get priceLabel => 'Price';

  @override
  String get contactPhoneLabel => 'Contact phone';

  @override
  String get selectZoneError => 'Select a zone before creating a request';

  @override
  String get vehicleTypeLabel => 'Vehicle type';

  @override
  String get selectVehicleTypeError =>
      'Select a vehicle type before creating a request';

  @override
  String get setPickupDropoffError =>
      'Tap the map to set both pickup and drop-off';

  @override
  String get describePackageError => 'Describe what needs to be delivered';

  @override
  String get estimatedWeightRequiredError =>
      'Enter the approximate weight of the goods (kg)';

  @override
  String get estimatedWeightHint => 'Approximate weight of the goods (kg)';

  @override
  String get priceStillCalculatingError =>
      'Price is still being calculated — wait a moment or tap Recalculate';

  @override
  String get setPickupOnMapTooltip => 'Set pickup on map';

  @override
  String get setDropoffOnMapTooltip => 'Set drop-off on map';

  @override
  String get pickupAddressHint => 'Pickup address / landmark';

  @override
  String get addressSearchHelper =>
      'Type an address and press search, or tap the map';

  @override
  String get findOnMapTooltip => 'Find on map';

  @override
  String get savedAddressesTooltip => 'Saved addresses';

  @override
  String savedAddressesCountLabel(int count) {
    return '$count saved';
  }

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletButton => 'Wallet';

  @override
  String get walletBalanceLabel => 'Balance';

  @override
  String get savedAddressesHeading => 'Saved Addresses';

  @override
  String get addNewAddressAction => 'Add New';

  @override
  String get pickupPhoneLabel => 'Pickup contact phone (optional)';

  @override
  String get pickupPhoneHelper => 'Who should the rider call at pickup?';

  @override
  String get dropoffAddressHint => 'Drop-off address / landmark';

  @override
  String get receiverPhoneLabel => 'Receiver contact phone (optional)';

  @override
  String get receiverPhoneHelper => 'Only shown to the rider once they pick up';

  @override
  String get packageDescLabel => 'What are you sending?';

  @override
  String get packageDescHelper =>
      'e.g. \"Pick up a pizza from Al-Salam Restaurant\"';

  @override
  String get purchaseBudgetLabel => 'Estimated purchase amount (optional, SDG)';

  @override
  String get purchaseBudgetHelper =>
      'If the rider needs to pay for something (like your pizza), how much cash should they bring?';

  @override
  String get packageSizeLabel => 'Package size';

  @override
  String get sizeSmall => 'Small (fits a backpack)';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get faqTitle => 'Frequently Asked Questions';

  @override
  String get faq1Question => 'How does bidding work?';

  @override
  String get faq1Answer =>
      'After you post a delivery request, nearby riders see it and place bids with their own price. You choose which bid to accept — you\'re never stuck with a price you don\'t like.';

  @override
  String get faq2Question => 'How do I pay?';

  @override
  String get faq2Answer =>
      'You pay the rider directly in cash or via bank transfer when your delivery arrives, using the price shown on your tracking screen.';

  @override
  String get faq3Question => 'What is the confirmation code for?';

  @override
  String get faq3Answer =>
      'It\'s your proof of delivery. Give the code shown on your tracking screen to the rider only once you\'ve actually received your delivery — this is what lets them mark it complete.';

  @override
  String get faq4Question => 'Can I cancel my request?';

  @override
  String get faq4Answer =>
      'Yes, anytime before the rider has picked up your package. Once it\'s been picked up, use \"Report a Problem\" instead if something goes wrong.';

  @override
  String get faq5Question => 'What if my rider cancels?';

  @override
  String get faq5Answer =>
      'Your request automatically reopens for new bids — you won\'t need to start over from scratch.';

  @override
  String get faq6Question => 'What does the estimated purchase amount mean?';

  @override
  String get faq6Answer =>
      'If you need the rider to buy something on your behalf (like picking up food from a restaurant), this tells them roughly how much cash to bring so they can pay for it before bidding.';

  @override
  String get orderHistoryTitle => 'Order History';

  @override
  String get noPastOrdersYet => 'No past orders yet.';

  @override
  String get noDescriptionPlaceholder => '(no description)';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusAssigned => 'Assigned';

  @override
  String get statusPickedUp => 'Picked up';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get cancelDeliveryDialogTitle => 'Cancel this delivery?';

  @override
  String get cancelDeliveryError => 'Could not cancel this delivery.';

  @override
  String get cancelDeliveryButton => 'Cancel delivery';

  @override
  String get riderOnWayTitle => 'Rider is on the way';

  @override
  String get waitingForRiderLocation => 'Waiting for rider location...';

  @override
  String get amountDueLabel => 'Amount due';

  @override
  String get etaTileLabel => 'ETA to you';

  @override
  String etaApproxMinutes(int minutes) {
    return '~$minutes min';
  }

  @override
  String get yourRiderFallbackName => 'Your rider';

  @override
  String get phoneDialerError => 'Could not open the phone dialer.';

  @override
  String get confirmationCodeInstruction =>
      'Give this code to your rider at delivery: ';

  @override
  String get statusHeadingToPickup => 'Rider is heading to pickup';

  @override
  String get statusRiderArrived => 'Rider has arrived at pickup';

  @override
  String get imComingButton => 'I\'m Coming';

  @override
  String arrivalGracePeriodMessage(String remaining) {
    return 'Please meet your rider — $remaining left';
  }

  @override
  String get arrivalGraceExpiredMessage =>
      'Your rider has been waiting a while — extra charges may apply.';

  @override
  String get statusPickedUpOnWay => 'Package picked up — on the way to you';

  @override
  String get statusDeliveredThankYou => 'Delivered! Thank you.';

  @override
  String get statusTrackingOrder => 'Tracking order...';

  @override
  String etaToPickupLabel(int minutes) {
    return 'ETA to pickup: ~$minutes min';
  }

  @override
  String etaToDropoffLabel(int minutes) {
    return 'ETA to you: ~$minutes min';
  }

  @override
  String liveActivityEtaMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get tapStarToRateError => 'Tap a star to rate your rider';

  @override
  String get submitRatingError => 'Could not submit rating.';

  @override
  String get howWasYourDeliveryTitle => 'How was your delivery?';

  @override
  String get optionalCommentHint => 'Optional comment about your rider';

  @override
  String get submitRatingButton => 'Submit Rating';

  @override
  String deliveredAmountCollected(String amount) {
    return 'Delivered — $amount SDG collected';
  }

  @override
  String get deliveredExclamation => 'Delivered!';

  @override
  String get thanksForRatingMessage => 'Thanks for your rating!';

  @override
  String get tellUsMoreHint => 'Tell us more...';

  @override
  String get confirmCancellationButton => 'Confirm Cancellation';

  @override
  String get keepItButton => 'Keep it';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get additionalDetailsHint => 'Additional details (optional)';

  @override
  String get submitReportButton => 'Submit Report';

  @override
  String get reportSubmittedMessage =>
      'Report submitted. Our team will follow up.';

  @override
  String get saveCurrentPinButton => 'Save current pin as a new address';

  @override
  String get addressSavedMessage => 'Address saved.';

  @override
  String get noSavedAddressesYet => 'No saved addresses yet.';

  @override
  String get recentLocationsHeading => 'Recent';

  @override
  String get nameAddressTitle => 'Name this address';

  @override
  String get addressLabelHint => 'e.g. Home, University, Market';

  @override
  String get saveThisAddressLabel => 'Save this address';

  @override
  String get resolvingAddressPlaceholder => 'Resolving address...';

  @override
  String get continueButton => 'Continue';

  @override
  String get profileSetupTitle => 'Complete your profile';

  @override
  String get genderLabel => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get regionLabel => 'Region';

  @override
  String get noRegionsAvailableMessage =>
      'No regions available yet — you can set this later from your profile.';

  @override
  String get addPhotoLabel => 'Add a profile photo';

  @override
  String get photoOptionalHint => 'Optional — you can add this later';

  @override
  String get takePhotoOption => 'Take photo';

  @override
  String get chooseFromGalleryOption => 'Choose from gallery';

  @override
  String get profileSetupError => 'Could not save your profile. Try again.';

  @override
  String get redeemPromoCodeButton => 'Redeem a promo code';

  @override
  String get promoCodeHint => 'Enter code';

  @override
  String get redeemButton => 'Redeem';

  @override
  String promoRedeemedMessage(String amount) {
    return 'Promo applied: -$amount SDG on your next request';
  }

  @override
  String promoAppliedBanner(String amount) {
    return 'Promo applied: -$amount SDG';
  }

  @override
  String get promoRedeemError => 'Could not redeem this code.';

  @override
  String get rejectButton => 'Reject';

  @override
  String get bidRejectedMessage => 'Bid declined.';

  @override
  String get bidRejectError => 'Could not decline this bid.';

  @override
  String get confirmLocationButton => 'Confirm Location';

  @override
  String get moveMapToSelectLocationHint =>
      'Move the map to place the pin at your location';

  @override
  String get couldNotDetectLocationMessage =>
      'Could not detect your location — tap the map icon to set your pickup point.';

  @override
  String get submitRequestError =>
      'Could not create your request. Check your connection and try again.';

  @override
  String get accountSuspendedError =>
      'Your account has been suspended. Contact support for more information.';

  @override
  String get signInHeading => 'Enter your phone number to continue';

  @override
  String get phoneContinueButton => 'Continue';

  @override
  String get checkPhoneError =>
      'Could not verify this phone number. Check your connection and try again.';

  @override
  String get passwordHint => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get wrongPasswordError => 'Incorrect password. Try again.';

  @override
  String get setPasswordTitle => 'Set a password';

  @override
  String get setPasswordInstruction =>
      'Set a password so you can sign in faster next time without waiting for a code.';

  @override
  String get newPasswordHint => 'New password';

  @override
  String get confirmPasswordHint => 'Confirm password';

  @override
  String get showPasswordWord => 'Show';

  @override
  String get pwRuleLength => 'At least 6 characters';

  @override
  String get pwRuleMatch => 'Both fields match';

  @override
  String get passwordTooShortError => 'Password must be at least 6 characters';

  @override
  String get passwordsDontMatchError => 'Passwords don\'t match';

  @override
  String get savePasswordButton => 'Save Password';

  @override
  String get setPasswordError => 'Could not save your password. Try again.';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String forgotPasswordInstruction(String phone) {
    return 'We\'ll text a verification code to $phone';
  }

  @override
  String get logoutButton => 'Logout';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage =>
      'You\'ll need your phone number and password to sign back in.';

  @override
  String get emailLabel => 'Email (optional)';

  @override
  String get invalidEmailError => 'Enter a valid email address';

  @override
  String get contactSupportButton => 'Contact Support';

  @override
  String get contactSupportTitle => 'Contact Support';

  @override
  String get callSupportButton => 'Call Support';

  @override
  String get whatsappSupportButton => 'WhatsApp Support';

  @override
  String get emailSupportButton => 'Email Support';

  @override
  String get supportMessageHint => 'Describe your issue...';

  @override
  String get submitSupportMessageButton => 'Send Message';

  @override
  String get supportMessageSentMessage =>
      'Message sent — our team will get back to you.';

  @override
  String get supportMessageError => 'Could not send your message. Try again.';

  @override
  String get describeIssueError => 'Describe your issue before sending';

  @override
  String get myTicketsHeading => 'Your Messages';

  @override
  String get ticketStatusOpen => 'Awaiting reply';

  @override
  String get ticketStatusResolved => 'Resolved';

  @override
  String get supportReplyLabel => 'Support';

  @override
  String get accountSectionLabel => 'Account';
}
