import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Wassil'**
  String get appTitle;

  /// No description provided for @newRiderLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newRiderLabel;

  /// No description provided for @vehicleColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get vehicleColorWhite;

  /// No description provided for @vehicleColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get vehicleColorBlack;

  /// No description provided for @vehicleColorSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get vehicleColorSilver;

  /// No description provided for @vehicleColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get vehicleColorRed;

  /// No description provided for @vehicleColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get vehicleColorBlue;

  /// No description provided for @vehicleColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get vehicleColorGreen;

  /// No description provided for @vehicleColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get vehicleColorYellow;

  /// No description provided for @vehicleColorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get vehicleColorGrey;

  /// No description provided for @vehicleColorOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get vehicleColorOther;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your delivery, your price.'**
  String get splashTagline;

  /// No description provided for @skipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipButton;

  /// No description provided for @phoneLoginHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter your name and phone number'**
  String get phoneLoginHeading;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameHint;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'09XXXXXXXX'**
  String get phoneHint;

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCodeButton;

  /// No description provided for @enterNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterNameError;

  /// No description provided for @enterPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneError;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get otpTitle;

  /// No description provided for @otpCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {phone}'**
  String otpCodeSentTo(String phone);

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'123456'**
  String get otpHint;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get enterSixDigitCode;

  /// No description provided for @invalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Try again.'**
  String get invalidCodeError;

  /// No description provided for @verificationFailedError.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Try again.'**
  String get verificationFailedError;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @faqButton.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faqButton;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @newDeliveryRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New delivery request'**
  String get newDeliveryRequestTitle;

  /// No description provided for @zoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zoneLabel;

  /// No description provided for @postRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Post request & start bidding'**
  String get postRequestButton;

  /// No description provided for @moreOptionsButton.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsButton;

  /// No description provided for @moreOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTitle;

  /// No description provided for @basePriceWord.
  ///
  /// In en, this message translates to:
  /// **'Base price'**
  String get basePriceWord;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @orderHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistoryTooltip;

  /// No description provided for @profileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTooltip;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Changed my mind'**
  String get reasonChangedMind;

  /// No description provided for @reasonNoLongerNeeded.
  ///
  /// In en, this message translates to:
  /// **'No longer needed'**
  String get reasonNoLongerNeeded;

  /// No description provided for @reasonFoundAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'Found another way'**
  String get reasonFoundAnotherWay;

  /// No description provided for @reasonRiderTakingTooLong.
  ///
  /// In en, this message translates to:
  /// **'Rider taking too long'**
  String get reasonRiderTakingTooLong;

  /// No description provided for @reportProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblemTitle;

  /// No description provided for @reportReasonItemDamaged.
  ///
  /// In en, this message translates to:
  /// **'Item damaged'**
  String get reportReasonItemDamaged;

  /// No description provided for @reportReasonWrongItem.
  ///
  /// In en, this message translates to:
  /// **'Wrong item delivered'**
  String get reportReasonWrongItem;

  /// No description provided for @reportReasonRiderUnprofessional.
  ///
  /// In en, this message translates to:
  /// **'Rider was unprofessional'**
  String get reportReasonRiderUnprofessional;

  /// No description provided for @reportReasonNeverReceived.
  ///
  /// In en, this message translates to:
  /// **'Never received the item'**
  String get reportReasonNeverReceived;

  /// No description provided for @biddingWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for bids ({time})'**
  String biddingWaitingTitle(String time);

  /// No description provided for @biddingClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Bidding closed'**
  String get biddingClosedTitle;

  /// No description provided for @bidsHeading.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bidsHeading;

  /// No description provided for @cheapestFirstLabel.
  ///
  /// In en, this message translates to:
  /// **'Cheapest first'**
  String get cheapestFirstLabel;

  /// No description provided for @cancelRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get cancelRequestDialogTitle;

  /// No description provided for @cancelRequestError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel this request.'**
  String get cancelRequestError;

  /// No description provided for @acceptBidError.
  ///
  /// In en, this message translates to:
  /// **'Could not accept this bid. It may have expired.'**
  String get acceptBidError;

  /// No description provided for @noBidsYetWaiting.
  ///
  /// In en, this message translates to:
  /// **'No bids yet — riders nearby are being notified.'**
  String get noBidsYetWaiting;

  /// No description provided for @noBidsTimedOut.
  ///
  /// In en, this message translates to:
  /// **'No riders bid in time. You can post the request again.'**
  String get noBidsTimedOut;

  /// No description provided for @boostPriceButton.
  ///
  /// In en, this message translates to:
  /// **'Increase Price to Attract Riders'**
  String get boostPriceButton;

  /// No description provided for @boostPriceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Increase your price'**
  String get boostPriceDialogTitle;

  /// No description provided for @boostPriceDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Your current offer of {currentPrice} SDG didn\'t attract any riders. A higher price may get faster offers.'**
  String boostPriceDialogHint(String currentPrice);

  /// No description provided for @newPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'New price'**
  String get newPriceLabel;

  /// No description provided for @boostPriceConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Repost with New Price'**
  String get boostPriceConfirmButton;

  /// No description provided for @boostPriceError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the price. Please try again.'**
  String get boostPriceError;

  /// No description provided for @etaMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ETA'**
  String etaMinutesLabel(int minutes);

  /// No description provided for @etaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'ETA unavailable'**
  String get etaUnavailable;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @activeOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Order'**
  String get activeOrderTitle;

  /// No description provided for @activeDeliveryInProgress.
  ///
  /// In en, this message translates to:
  /// **'You already have a delivery in progress.'**
  String get activeDeliveryInProgress;

  /// No description provided for @viewOrderButton.
  ///
  /// In en, this message translates to:
  /// **'View Order'**
  String get viewOrderButton;

  /// No description provided for @calculatingPrice.
  ///
  /// In en, this message translates to:
  /// **'Calculating price...'**
  String get calculatingPrice;

  /// No description provided for @priceCalculationError.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate a price — check your connection and try again.'**
  String get priceCalculationError;

  /// No description provided for @estimatedDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated distance: {distance} km'**
  String estimatedDistanceLabel(String distance);

  /// No description provided for @basePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Base price: {price} SDG'**
  String basePriceLabel(String price);

  /// No description provided for @maxBidLabel.
  ///
  /// In en, this message translates to:
  /// **'Riders may bid anywhere up to {maxBid} SDG'**
  String maxBidLabel(String maxBid);

  /// No description provided for @addressNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find that address — tap the map to set the pin manually.'**
  String get addressNotFoundError;

  /// No description provided for @pickupAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup address'**
  String get pickupAddressTitle;

  /// No description provided for @dropoffAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop-off address'**
  String get dropoffAddressTitle;

  /// No description provided for @orderDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetailTitle;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhoneLabel;

  /// No description provided for @selectZoneError.
  ///
  /// In en, this message translates to:
  /// **'Select a zone before creating a request'**
  String get selectZoneError;

  /// No description provided for @vehicleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicleTypeLabel;

  /// No description provided for @selectVehicleTypeError.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle type before creating a request'**
  String get selectVehicleTypeError;

  /// No description provided for @setPickupDropoffError.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set both pickup and drop-off'**
  String get setPickupDropoffError;

  /// No description provided for @describePackageError.
  ///
  /// In en, this message translates to:
  /// **'Describe what needs to be delivered'**
  String get describePackageError;

  /// No description provided for @estimatedWeightRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter the approximate weight of the goods (kg)'**
  String get estimatedWeightRequiredError;

  /// No description provided for @estimatedWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Approximate weight of the goods (kg)'**
  String get estimatedWeightHint;

  /// No description provided for @priceStillCalculatingError.
  ///
  /// In en, this message translates to:
  /// **'Price is still being calculated — wait a moment or tap Recalculate'**
  String get priceStillCalculatingError;

  /// No description provided for @setPickupOnMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set pickup on map'**
  String get setPickupOnMapTooltip;

  /// No description provided for @setDropoffOnMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set drop-off on map'**
  String get setDropoffOnMapTooltip;

  /// No description provided for @pickupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Pickup address / landmark'**
  String get pickupAddressHint;

  /// No description provided for @addressSearchHelper.
  ///
  /// In en, this message translates to:
  /// **'Type an address and press search, or tap the map'**
  String get addressSearchHelper;

  /// No description provided for @findOnMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find on map'**
  String get findOnMapTooltip;

  /// No description provided for @savedAddressesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get savedAddressesTooltip;

  /// No description provided for @savedAddressesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String savedAddressesCountLabel(int count);

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletButton.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletButton;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalanceLabel;

  /// No description provided for @savedAddressesHeading.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddressesHeading;

  /// No description provided for @addNewAddressAction.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNewAddressAction;

  /// No description provided for @pickupPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup contact phone (optional)'**
  String get pickupPhoneLabel;

  /// No description provided for @pickupPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Who should the rider call at pickup?'**
  String get pickupPhoneHelper;

  /// No description provided for @dropoffAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Drop-off address / landmark'**
  String get dropoffAddressHint;

  /// No description provided for @receiverPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Receiver contact phone (optional)'**
  String get receiverPhoneLabel;

  /// No description provided for @receiverPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Only shown to the rider once they pick up'**
  String get receiverPhoneHelper;

  /// No description provided for @packageDescLabel.
  ///
  /// In en, this message translates to:
  /// **'What are you sending?'**
  String get packageDescLabel;

  /// No description provided for @packageDescHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Pick up a pizza from Al-Salam Restaurant\"'**
  String get packageDescHelper;

  /// No description provided for @purchaseBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated purchase amount (optional, SDG)'**
  String get purchaseBudgetLabel;

  /// No description provided for @purchaseBudgetHelper.
  ///
  /// In en, this message translates to:
  /// **'If the rider needs to pay for something (like your pizza), how much cash should they bring?'**
  String get purchaseBudgetHelper;

  /// No description provided for @packageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Package size'**
  String get packageSizeLabel;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small (fits a backpack)'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faqTitle;

  /// No description provided for @faq1Question.
  ///
  /// In en, this message translates to:
  /// **'How does bidding work?'**
  String get faq1Question;

  /// No description provided for @faq1Answer.
  ///
  /// In en, this message translates to:
  /// **'After you post a delivery request, nearby riders see it and place bids with their own price. You choose which bid to accept — you\'re never stuck with a price you don\'t like.'**
  String get faq1Answer;

  /// No description provided for @faq2Question.
  ///
  /// In en, this message translates to:
  /// **'How do I pay?'**
  String get faq2Question;

  /// No description provided for @faq2Answer.
  ///
  /// In en, this message translates to:
  /// **'You pay the rider directly in cash or via bank transfer when your delivery arrives, using the price shown on your tracking screen.'**
  String get faq2Answer;

  /// No description provided for @faq3Question.
  ///
  /// In en, this message translates to:
  /// **'What is the confirmation code for?'**
  String get faq3Question;

  /// No description provided for @faq3Answer.
  ///
  /// In en, this message translates to:
  /// **'It\'s your proof of delivery. Give the code shown on your tracking screen to the rider only once you\'ve actually received your delivery — this is what lets them mark it complete.'**
  String get faq3Answer;

  /// No description provided for @faq4Question.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel my request?'**
  String get faq4Question;

  /// No description provided for @faq4Answer.
  ///
  /// In en, this message translates to:
  /// **'Yes, anytime before the rider has picked up your package. Once it\'s been picked up, use \"Report a Problem\" instead if something goes wrong.'**
  String get faq4Answer;

  /// No description provided for @faq5Question.
  ///
  /// In en, this message translates to:
  /// **'What if my rider cancels?'**
  String get faq5Question;

  /// No description provided for @faq5Answer.
  ///
  /// In en, this message translates to:
  /// **'Your request automatically reopens for new bids — you won\'t need to start over from scratch.'**
  String get faq5Answer;

  /// No description provided for @faq6Question.
  ///
  /// In en, this message translates to:
  /// **'What does the estimated purchase amount mean?'**
  String get faq6Question;

  /// No description provided for @faq6Answer.
  ///
  /// In en, this message translates to:
  /// **'If you need the rider to buy something on your behalf (like picking up food from a restaurant), this tells them roughly how much cash to bring so they can pay for it before bidding.'**
  String get faq6Answer;

  /// No description provided for @orderHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistoryTitle;

  /// No description provided for @noPastOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No past orders yet.'**
  String get noPastOrdersYet;

  /// No description provided for @noDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(no description)'**
  String get noDescriptionPlaceholder;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get statusAssigned;

  /// No description provided for @statusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get statusPickedUp;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @cancelDeliveryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this delivery?'**
  String get cancelDeliveryDialogTitle;

  /// No description provided for @cancelDeliveryError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel this delivery.'**
  String get cancelDeliveryError;

  /// No description provided for @cancelDeliveryButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel delivery'**
  String get cancelDeliveryButton;

  /// No description provided for @riderOnWayTitle.
  ///
  /// In en, this message translates to:
  /// **'Rider is on the way'**
  String get riderOnWayTitle;

  /// No description provided for @waitingForRiderLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for rider location...'**
  String get waitingForRiderLocation;

  /// No description provided for @amountDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get amountDueLabel;

  /// No description provided for @etaTileLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA to you'**
  String get etaTileLabel;

  /// No description provided for @etaApproxMinutes.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min'**
  String etaApproxMinutes(int minutes);

  /// No description provided for @yourRiderFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Your rider'**
  String get yourRiderFallbackName;

  /// No description provided for @phoneDialerError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone dialer.'**
  String get phoneDialerError;

  /// No description provided for @confirmationCodeInstruction.
  ///
  /// In en, this message translates to:
  /// **'Give this code to your rider at delivery: '**
  String get confirmationCodeInstruction;

  /// No description provided for @statusHeadingToPickup.
  ///
  /// In en, this message translates to:
  /// **'Rider is heading to pickup'**
  String get statusHeadingToPickup;

  /// No description provided for @statusRiderArrived.
  ///
  /// In en, this message translates to:
  /// **'Rider has arrived at pickup'**
  String get statusRiderArrived;

  /// No description provided for @imComingButton.
  ///
  /// In en, this message translates to:
  /// **'I\'m Coming'**
  String get imComingButton;

  /// No description provided for @arrivalGracePeriodMessage.
  ///
  /// In en, this message translates to:
  /// **'Please meet your rider — {remaining} left'**
  String arrivalGracePeriodMessage(String remaining);

  /// No description provided for @arrivalGraceExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your rider has been waiting a while — extra charges may apply.'**
  String get arrivalGraceExpiredMessage;

  /// No description provided for @statusPickedUpOnWay.
  ///
  /// In en, this message translates to:
  /// **'Package picked up — on the way to you'**
  String get statusPickedUpOnWay;

  /// No description provided for @statusDeliveredThankYou.
  ///
  /// In en, this message translates to:
  /// **'Delivered! Thank you.'**
  String get statusDeliveredThankYou;

  /// No description provided for @statusTrackingOrder.
  ///
  /// In en, this message translates to:
  /// **'Tracking order...'**
  String get statusTrackingOrder;

  /// No description provided for @etaToPickupLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA to pickup: ~{minutes} min'**
  String etaToPickupLabel(int minutes);

  /// No description provided for @etaToDropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA to you: ~{minutes} min'**
  String etaToDropoffLabel(int minutes);

  /// Deliberately short — used only in the Dynamic Island / Lock Screen Live Activity's compact regions, which have room for only a few characters, unlike etaToPickupLabel/etaToDropoffLabel's full in-app sentence.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String liveActivityEtaMinutes(int minutes);

  /// No description provided for @tapStarToRateError.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate your rider'**
  String get tapStarToRateError;

  /// No description provided for @submitRatingError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit rating.'**
  String get submitRatingError;

  /// No description provided for @howWasYourDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your delivery?'**
  String get howWasYourDeliveryTitle;

  /// No description provided for @optionalCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Optional comment about your rider'**
  String get optionalCommentHint;

  /// No description provided for @submitRatingButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRatingButton;

  /// No description provided for @deliveredAmountCollected.
  ///
  /// In en, this message translates to:
  /// **'Delivered — {amount} SDG collected'**
  String deliveredAmountCollected(String amount);

  /// No description provided for @deliveredExclamation.
  ///
  /// In en, this message translates to:
  /// **'Delivered!'**
  String get deliveredExclamation;

  /// No description provided for @thanksForRatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your rating!'**
  String get thanksForRatingMessage;

  /// No description provided for @tellUsMoreHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us more...'**
  String get tellUsMoreHint;

  /// No description provided for @confirmCancellationButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancellation'**
  String get confirmCancellationButton;

  /// No description provided for @keepItButton.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepItButton;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @additionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get additionalDetailsHint;

  /// No description provided for @submitReportButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReportButton;

  /// No description provided for @reportSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Our team will follow up.'**
  String get reportSubmittedMessage;

  /// No description provided for @saveCurrentPinButton.
  ///
  /// In en, this message translates to:
  /// **'Save current pin as a new address'**
  String get saveCurrentPinButton;

  /// No description provided for @addressSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Address saved.'**
  String get addressSavedMessage;

  /// No description provided for @noSavedAddressesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet.'**
  String get noSavedAddressesYet;

  /// No description provided for @recentLocationsHeading.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentLocationsHeading;

  /// No description provided for @nameAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this address'**
  String get nameAddressTitle;

  /// No description provided for @addressLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Home, University, Market'**
  String get addressLabelHint;

  /// No description provided for @saveThisAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Save this address'**
  String get saveThisAddressLabel;

  /// No description provided for @resolvingAddressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Resolving address...'**
  String get resolvingAddressPlaceholder;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileSetupTitle;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @regionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get regionLabel;

  /// No description provided for @noRegionsAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No regions available yet — you can set this later from your profile.'**
  String get noRegionsAvailableMessage;

  /// No description provided for @addPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo'**
  String get addPhotoLabel;

  /// No description provided for @photoOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — you can add this later'**
  String get photoOptionalHint;

  /// No description provided for @takePhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhotoOption;

  /// No description provided for @chooseFromGalleryOption.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGalleryOption;

  /// No description provided for @profileSetupError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Try again.'**
  String get profileSetupError;

  /// No description provided for @redeemPromoCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem a promo code'**
  String get redeemPromoCodeButton;

  /// No description provided for @promoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get promoCodeHint;

  /// No description provided for @redeemButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeemButton;

  /// No description provided for @promoRedeemedMessage.
  ///
  /// In en, this message translates to:
  /// **'Promo applied: -{amount} SDG on your next request'**
  String promoRedeemedMessage(String amount);

  /// No description provided for @promoAppliedBanner.
  ///
  /// In en, this message translates to:
  /// **'Promo applied: -{amount} SDG'**
  String promoAppliedBanner(String amount);

  /// No description provided for @promoRedeemError.
  ///
  /// In en, this message translates to:
  /// **'Could not redeem this code.'**
  String get promoRedeemError;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @bidRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Bid declined.'**
  String get bidRejectedMessage;

  /// No description provided for @bidRejectError.
  ///
  /// In en, this message translates to:
  /// **'Could not decline this bid.'**
  String get bidRejectError;

  /// No description provided for @confirmLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocationButton;

  /// No description provided for @moveMapToSelectLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map to place the pin at your location'**
  String get moveMapToSelectLocationHint;

  /// No description provided for @couldNotDetectLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not detect your location — tap the map icon to set your pickup point.'**
  String get couldNotDetectLocationMessage;

  /// No description provided for @submitRequestError.
  ///
  /// In en, this message translates to:
  /// **'Could not create your request. Check your connection and try again.'**
  String get submitRequestError;

  /// No description provided for @accountSuspendedError.
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended. Contact support for more information.'**
  String get accountSuspendedError;

  /// No description provided for @signInHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to continue'**
  String get signInHeading;

  /// No description provided for @phoneContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get phoneContinueButton;

  /// No description provided for @checkPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Could not verify this phone number. Check your connection and try again.'**
  String get checkPhoneError;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @wrongPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Try again.'**
  String get wrongPasswordError;

  /// No description provided for @setPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPasswordTitle;

  /// No description provided for @setPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Set a password so you can sign in faster next time without waiting for a code.'**
  String get setPasswordInstruction;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// No description provided for @showPasswordWord.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showPasswordWord;

  /// No description provided for @pwRuleLength.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get pwRuleLength;

  /// No description provided for @pwRuleMatch.
  ///
  /// In en, this message translates to:
  /// **'Both fields match'**
  String get pwRuleMatch;

  /// No description provided for @passwordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShortError;

  /// No description provided for @passwordsDontMatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatchError;

  /// No description provided for @savePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save Password'**
  String get savePasswordButton;

  /// No description provided for @setPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your password. Try again.'**
  String get setPasswordError;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text a verification code to {phone}'**
  String forgotPasswordInstruction(String phone);

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need your phone number and password to sign back in.'**
  String get logoutConfirmMessage;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailLabel;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmailError;

  /// No description provided for @contactSupportButton.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupportButton;

  /// No description provided for @contactSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupportTitle;

  /// No description provided for @callSupportButton.
  ///
  /// In en, this message translates to:
  /// **'Call Support'**
  String get callSupportButton;

  /// No description provided for @whatsappSupportButton.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get whatsappSupportButton;

  /// No description provided for @emailSupportButton.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupportButton;

  /// No description provided for @supportMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue...'**
  String get supportMessageHint;

  /// No description provided for @submitSupportMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get submitSupportMessageButton;

  /// No description provided for @supportMessageSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Message sent — our team will get back to you.'**
  String get supportMessageSentMessage;

  /// No description provided for @supportMessageError.
  ///
  /// In en, this message translates to:
  /// **'Could not send your message. Try again.'**
  String get supportMessageError;

  /// No description provided for @describeIssueError.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue before sending'**
  String get describeIssueError;

  /// No description provided for @myTicketsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your Messages'**
  String get myTicketsHeading;

  /// No description provided for @ticketStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Awaiting reply'**
  String get ticketStatusOpen;

  /// No description provided for @ticketStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get ticketStatusResolved;

  /// No description provided for @supportReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportReplyLabel;

  /// No description provided for @accountSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
