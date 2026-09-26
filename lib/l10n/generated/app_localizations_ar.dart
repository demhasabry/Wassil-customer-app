// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'وصل';

  @override
  String get newRiderLabel => 'جديد';

  @override
  String get vehicleColorWhite => 'أبيض';

  @override
  String get vehicleColorBlack => 'أسود';

  @override
  String get vehicleColorSilver => 'فضي';

  @override
  String get vehicleColorRed => 'أحمر';

  @override
  String get vehicleColorBlue => 'أزرق';

  @override
  String get vehicleColorGreen => 'أخضر';

  @override
  String get vehicleColorYellow => 'أصفر';

  @override
  String get vehicleColorGrey => 'رمادي';

  @override
  String get vehicleColorOther => 'أخرى';

  @override
  String get splashTagline => 'طلبك مجاب..لحد الباب';

  @override
  String get skipButton => 'تخطي';

  @override
  String get phoneLoginHeading => 'أدخل اسمك ورقم هاتفك';

  @override
  String get fullNameHint => 'الاسم الكامل';

  @override
  String get phoneHint => '09XXXXXXXX';

  @override
  String get sendCodeButton => 'إرسال الرمز';

  @override
  String get enterNameError => 'أدخل اسمك';

  @override
  String get enterPhoneError => 'أدخل رقم هاتفك';

  @override
  String get otpTitle => 'التحقق من الرمز';

  @override
  String otpCodeSentTo(String phone) {
    return 'تم إرسال الرمز إلى $phone';
  }

  @override
  String get otpHint => '123456';

  @override
  String get verifyButton => 'تحقق';

  @override
  String get enterSixDigitCode => 'أدخل الرمز المكون من 6 أرقام';

  @override
  String get invalidCodeError => 'رمز غير صحيح. حاول مرة أخرى.';

  @override
  String get verificationFailedError => 'فشل التحقق. حاول مرة أخرى.';

  @override
  String get profileTitle => 'ملفي الشخصي';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get saveChangesButton => 'حفظ التغييرات';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي.';

  @override
  String get faqButton => 'الأسئلة الشائعة';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageSystemDefault => 'لغة النظام';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get newDeliveryRequestTitle => 'طلب توصيل جديد';

  @override
  String get zoneLabel => 'المنطقة';

  @override
  String get postRequestButton => 'نشر الطلب وبدء المزايدة';

  @override
  String get moreOptionsButton => 'خيارات أخرى';

  @override
  String get moreOptionsTitle => 'خيارات أخرى';

  @override
  String get basePriceWord => 'السعر الأساسي';

  @override
  String get doneButton => 'تم';

  @override
  String get orderHistoryTooltip => 'سجل الطلبات';

  @override
  String get profileTooltip => 'الملف الشخصي';

  @override
  String get cancelButton => 'إلغاء';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get saveButton => 'حفظ';

  @override
  String get backButton => 'رجوع';

  @override
  String get reasonOther => 'أخرى';

  @override
  String get reasonChangedMind => 'غيرت رأيي';

  @override
  String get reasonNoLongerNeeded => 'لم أعد بحاجة إليه';

  @override
  String get reasonFoundAnotherWay => 'وجدت طريقة أخرى';

  @override
  String get reasonRiderTakingTooLong => 'السائق يتأخر كثيرًا';

  @override
  String get reportProblemTitle => 'الإبلاغ عن مشكلة';

  @override
  String get reportReasonItemDamaged => 'العنصر تالف';

  @override
  String get reportReasonWrongItem => 'تم توصيل عنصر خاطئ';

  @override
  String get reportReasonRiderUnprofessional => 'تصرف السائق بشكل غير مهني';

  @override
  String get reportReasonNeverReceived => 'لم أستلم العنصر';

  @override
  String biddingWaitingTitle(String time) {
    return 'بانتظار العروض ($time)';
  }

  @override
  String get biddingClosedTitle => 'انتهت المزايدة';

  @override
  String get bidsHeading => 'العروض';

  @override
  String get cheapestFirstLabel => 'الأرخص أولاً';

  @override
  String get cancelRequestDialogTitle => 'هل تريد إلغاء هذا الطلب؟';

  @override
  String get cancelRequestError => 'تعذر إلغاء هذا الطلب.';

  @override
  String get acceptBidError =>
      'تعذر قبول هذا العرض. ربما تكون صلاحيته قد انتهت.';

  @override
  String get noBidsYetWaiting =>
      'لا توجد عروض بعد — يتم إشعار السائقين القريبين.';

  @override
  String get noBidsTimedOut =>
      'لم يقدم أي سائق عرضًا في الوقت المحدد. يمكنك نشر الطلب مرة أخرى.';

  @override
  String get boostPriceButton => 'زيادة السعر لجذب السائقين';

  @override
  String get boostPriceDialogTitle => 'زيادة سعرك';

  @override
  String boostPriceDialogHint(String currentPrice) {
    return 'عرضك الحالي $currentPrice جنيه سوداني لم يجذب أي سائق. سعر أعلى قد يجلب عروضًا أسرع.';
  }

  @override
  String get newPriceLabel => 'السعر الجديد';

  @override
  String get boostPriceConfirmButton => 'إعادة النشر بالسعر الجديد';

  @override
  String get boostPriceError => 'تعذر تحديث السعر. حاول مرة أخرى.';

  @override
  String etaMinutesLabel(int minutes) {
    return 'الوصول المتوقع خلال $minutes دقيقة';
  }

  @override
  String get etaUnavailable => 'الوقت المتوقع غير متاح';

  @override
  String get acceptButton => 'قبول';

  @override
  String get activeOrderTitle => 'الطلب النشط';

  @override
  String get activeDeliveryInProgress => 'لديك بالفعل عملية توصيل قيد التنفيذ.';

  @override
  String get viewOrderButton => 'عرض الطلب';

  @override
  String get calculatingPrice => 'جارٍ حساب السعر...';

  @override
  String get priceCalculationError =>
      'تعذر حساب السعر — تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String estimatedDistanceLabel(String distance) {
    return 'المسافة التقديرية: $distance كم';
  }

  @override
  String basePriceLabel(String price) {
    return 'السعر الأساسي: $price جنيه سوداني';
  }

  @override
  String maxBidLabel(String maxBid) {
    return 'يمكن للسائقين تقديم عروض تصل إلى $maxBid جنيه سوداني';
  }

  @override
  String get addressNotFoundError =>
      'تعذر العثور على هذا العنوان — اضغط على الخريطة لتحديد الموقع يدويًا.';

  @override
  String get pickupAddressTitle => 'عنوان الاستلام';

  @override
  String get dropoffAddressTitle => 'عنوان التوصيل';

  @override
  String get orderDetailTitle => 'تفاصيل الطلب';

  @override
  String get priceLabel => 'السعر';

  @override
  String get contactPhoneLabel => 'رقم التواصل';

  @override
  String get selectZoneError => 'اختر منطقة قبل إنشاء الطلب';

  @override
  String get vehicleTypeLabel => 'نوع المركبة';

  @override
  String get selectVehicleTypeError => 'اختر نوع المركبة قبل إنشاء الطلب';

  @override
  String get setPickupDropoffError =>
      'اضغط على الخريطة لتحديد نقطتي الاستلام والتوصيل';

  @override
  String get describePackageError => 'صف ما يحتاج إلى توصيله';

  @override
  String get estimatedWeightRequiredError =>
      'أدخل الوزن التقريبي للبضاعة (كجم)';

  @override
  String get estimatedWeightHint => 'الوزن التقريبي للبضاعة (كجم)';

  @override
  String get priceStillCalculatingError =>
      'لا يزال السعر قيد الحساب — انتظر لحظة أو اضغط على إعادة الحساب';

  @override
  String get setPickupOnMapTooltip => 'تحديد الاستلام على الخريطة';

  @override
  String get setDropoffOnMapTooltip => 'تحديد التوصيل على الخريطة';

  @override
  String get pickupAddressHint => 'عنوان الاستلام / معلم مميز';

  @override
  String get addressSearchHelper =>
      'اكتب عنوانًا واضغط على بحث، أو اضغط على الخريطة';

  @override
  String get findOnMapTooltip => 'البحث على الخريطة';

  @override
  String get savedAddressesTooltip => 'العناوين المحفوظة';

  @override
  String savedAddressesCountLabel(int count) {
    return '$count محفوظ';
  }

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get walletButton => 'المحفظة';

  @override
  String get walletBalanceLabel => 'الرصيد';

  @override
  String get savedAddressesHeading => 'العناوين المحفوظة';

  @override
  String get addNewAddressAction => 'إضافة جديد';

  @override
  String get pickupPhoneLabel => 'رقم هاتف التواصل عند الاستلام (اختياري)';

  @override
  String get pickupPhoneHelper => 'بمن يجب أن يتصل السائق عند الاستلام؟';

  @override
  String get dropoffAddressHint => 'عنوان التوصيل / معلم مميز';

  @override
  String get receiverPhoneLabel => 'رقم هاتف المستلم (اختياري)';

  @override
  String get receiverPhoneHelper => 'يظهر للسائق فقط بعد الاستلام';

  @override
  String get packageDescLabel => 'ماذا ترسل؟';

  @override
  String get packageDescHelper => 'مثال: \"استلام بيتزا من مطعم السلام\"';

  @override
  String get purchaseBudgetLabel =>
      'المبلغ التقديري للشراء (اختياري، جنيه سوداني)';

  @override
  String get purchaseBudgetHelper =>
      'إذا احتاج السائق لدفع ثمن شيء (مثل البيتزا)، كم يجب أن يحضر من النقود؟';

  @override
  String get packageSizeLabel => 'حجم الطرد';

  @override
  String get sizeSmall => 'صغير (يتسع في حقيبة ظهر)';

  @override
  String get sizeMedium => 'متوسط';

  @override
  String get sizeLarge => 'كبير';

  @override
  String get faqTitle => 'الأسئلة الشائعة';

  @override
  String get faq1Question => 'كيف تعمل آلية المزايدة؟';

  @override
  String get faq1Answer =>
      'بعد نشر طلب التوصيل، يرى السائقون القريبون الطلب ويقدمون عروض أسعارهم الخاصة. أنت من يختار العرض الذي يقبله — ولن تكون مضطرًا لقبول سعر لا يعجبك.';

  @override
  String get faq2Question => 'كيف أدفع؟';

  @override
  String get faq2Answer =>
      'تدفع للسائق مباشرة نقدًا أو عبر تحويل بنكي عند وصول طلبك، باستخدام السعر الظاهر في شاشة التتبع.';

  @override
  String get faq3Question => 'ما الغرض من رمز التأكيد؟';

  @override
  String get faq3Answer =>
      'إنه إثبات استلامك للطلب. أعطِ الرمز الظاهر في شاشة التتبع للسائق فقط بعد استلام طلبك فعليًا — فهذا ما يتيح له تعليم الطلب كمكتمل.';

  @override
  String get faq4Question => 'هل يمكنني إلغاء طلبي؟';

  @override
  String get faq4Answer =>
      'نعم، في أي وقت قبل استلام السائق لطردك. وبمجرد استلامه، استخدم \"الإبلاغ عن مشكلة\" بدلاً من ذلك في حال حدوث أي خلل.';

  @override
  String get faq5Question => 'ماذا لو ألغى السائق الطلب؟';

  @override
  String get faq5Answer =>
      'يُعاد فتح طلبك تلقائيًا لاستقبال عروض جديدة — ولن تحتاج إلى البدء من جديد.';

  @override
  String get faq6Question => 'ماذا يعني المبلغ التقديري للشراء؟';

  @override
  String get faq6Answer =>
      'إذا احتجت أن يشتري السائق شيئًا نيابة عنك (مثل استلام طعام من مطعم)، فهذا يخبره تقريبًا بكمية النقود التي يجب إحضارها ليتمكن من الدفع قبل تقديم عرضه.';

  @override
  String get orderHistoryTitle => 'سجل الطلبات';

  @override
  String get noPastOrdersYet => 'لا توجد طلبات سابقة بعد.';

  @override
  String get noDescriptionPlaceholder => '(بدون وصف)';

  @override
  String get statusOpen => 'مفتوح';

  @override
  String get statusAssigned => 'تم التعيين';

  @override
  String get statusPickedUp => 'تم الاستلام';

  @override
  String get statusDelivered => 'تم التوصيل';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusUnknown => 'غير معروف';

  @override
  String get cancelDeliveryDialogTitle => 'هل تريد إلغاء هذا التوصيل؟';

  @override
  String get cancelDeliveryError => 'تعذر إلغاء هذا التوصيل.';

  @override
  String get cancelDeliveryButton => 'إلغاء التوصيل';

  @override
  String get riderOnWayTitle => 'السائق في الطريق';

  @override
  String get waitingForRiderLocation => 'بانتظار موقع السائق...';

  @override
  String get amountDueLabel => 'المبلغ المستحق';

  @override
  String get etaTileLabel => 'الوقت المتوقع للوصول';

  @override
  String etaApproxMinutes(int minutes) {
    return '~$minutes دقيقة';
  }

  @override
  String get yourRiderFallbackName => 'سائقك';

  @override
  String get phoneDialerError => 'تعذر فتح تطبيق الاتصال.';

  @override
  String get confirmationCodeInstruction =>
      'أعطِ هذا الرمز لسائقك عند التوصيل: ';

  @override
  String get statusHeadingToPickup => 'السائق في طريقه للاستلام';

  @override
  String get statusRiderArrived => 'وصل السائق إلى موقع الاستلام';

  @override
  String get imComingButton => 'أنا قادم';

  @override
  String arrivalGracePeriodMessage(String remaining) {
    return 'الرجاء مقابلة سائقك — تبقّى $remaining';
  }

  @override
  String get arrivalGraceExpiredMessage =>
      'سائقك ينتظر منذ فترة — قد تُضاف رسوم إضافية.';

  @override
  String get statusPickedUpOnWay => 'تم استلام الطرد — في الطريق إليك';

  @override
  String get statusDeliveredThankYou => 'تم التوصيل! شكرًا لك.';

  @override
  String get statusTrackingOrder => 'جارٍ تتبع الطلب...';

  @override
  String etaToPickupLabel(int minutes) {
    return 'الوصول المتوقع للاستلام: ~$minutes دقيقة';
  }

  @override
  String etaToDropoffLabel(int minutes) {
    return 'الوصول المتوقع إليك: ~$minutes دقيقة';
  }

  @override
  String liveActivityEtaMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String get tapStarToRateError => 'اضغط على نجمة لتقييم سائقك';

  @override
  String get submitRatingError => 'تعذر إرسال التقييم.';

  @override
  String get howWasYourDeliveryTitle => 'كيف كانت تجربة التوصيل؟';

  @override
  String get optionalCommentHint => 'تعليق اختياري عن سائقك';

  @override
  String get submitRatingButton => 'إرسال التقييم';

  @override
  String deliveredAmountCollected(String amount) {
    return 'تم التوصيل — تم تحصيل $amount جنيه سوداني';
  }

  @override
  String get deliveredExclamation => 'تم التوصيل!';

  @override
  String get thanksForRatingMessage => 'شكرًا لتقييمك!';

  @override
  String get tellUsMoreHint => 'أخبرنا المزيد...';

  @override
  String get confirmCancellationButton => 'تأكيد الإلغاء';

  @override
  String get keepItButton => 'الاحتفاظ به';

  @override
  String get reasonLabel => 'السبب';

  @override
  String get additionalDetailsHint => 'تفاصيل إضافية (اختياري)';

  @override
  String get submitReportButton => 'إرسال البلاغ';

  @override
  String get reportSubmittedMessage => 'تم إرسال البلاغ. سيتابع فريقنا الأمر.';

  @override
  String get saveCurrentPinButton => 'حفظ الموقع الحالي كعنوان جديد';

  @override
  String get addressSavedMessage => 'تم حفظ العنوان.';

  @override
  String get noSavedAddressesYet => 'لا توجد عناوين محفوظة بعد.';

  @override
  String get recentLocationsHeading => 'الأخيرة';

  @override
  String get nameAddressTitle => 'أطلق اسمًا على هذا العنوان';

  @override
  String get addressLabelHint => 'مثال: المنزل، الجامعة، السوق';

  @override
  String get saveThisAddressLabel => 'حفظ هذا العنوان';

  @override
  String get resolvingAddressPlaceholder => 'جارٍ تحديد العنوان...';

  @override
  String get continueButton => 'متابعة';

  @override
  String get profileSetupTitle => 'أكمل ملفك الشخصي';

  @override
  String get genderLabel => 'الجنس';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get regionLabel => 'المنطقة';

  @override
  String get noRegionsAvailableMessage =>
      'لا توجد مناطق متاحة بعد — يمكنك تحديد ذلك لاحقًا من ملفك الشخصي.';

  @override
  String get addPhotoLabel => 'إضافة صورة شخصية';

  @override
  String get photoOptionalHint => 'اختياري — يمكنك إضافتها لاحقًا';

  @override
  String get takePhotoOption => 'التقاط صورة';

  @override
  String get chooseFromGalleryOption => 'الاختيار من المعرض';

  @override
  String get profileSetupError => 'تعذر حفظ ملفك الشخصي. حاول مرة أخرى.';

  @override
  String get redeemPromoCodeButton => 'استخدام رمز ترويجي';

  @override
  String get promoCodeHint => 'أدخل الرمز';

  @override
  String get redeemButton => 'استخدام';

  @override
  String promoRedeemedMessage(String amount) {
    return 'تم تطبيق الخصم: -$amount جنيه سوداني على طلبك القادم';
  }

  @override
  String promoAppliedBanner(String amount) {
    return 'تم تطبيق الخصم: -$amount جنيه سوداني';
  }

  @override
  String get promoRedeemError => 'تعذر استخدام هذا الرمز.';

  @override
  String get rejectButton => 'رفض';

  @override
  String get bidRejectedMessage => 'تم رفض العرض.';

  @override
  String get bidRejectError => 'تعذر رفض هذا العرض.';

  @override
  String get confirmLocationButton => 'تأكيد الموقع';

  @override
  String get moveMapToSelectLocationHint => 'حرّك الخريطة لوضع الدبوس في موقعك';

  @override
  String get couldNotDetectLocationMessage =>
      'تعذر تحديد موقعك — اضغط على أيقونة الخريطة لتحديد نقطة الاستلام.';

  @override
  String get submitRequestError =>
      'تعذر إنشاء طلبك. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get accountSuspendedError =>
      'تم إيقاف حسابك. تواصل مع الدعم لمزيد من المعلومات.';

  @override
  String get signInHeading => 'أدخل رقم هاتفك للمتابعة';

  @override
  String get phoneContinueButton => 'متابعة';

  @override
  String get checkPhoneError =>
      'تعذر التحقق من رقم الهاتف. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get wrongPasswordError => 'كلمة المرور غير صحيحة. حاول مرة أخرى.';

  @override
  String get setPasswordTitle => 'تعيين كلمة مرور';

  @override
  String get setPasswordInstruction =>
      'عيّن كلمة مرور لتسجيل الدخول بشكل أسرع في المرة القادمة دون انتظار رمز التحقق.';

  @override
  String get newPasswordHint => 'كلمة مرور جديدة';

  @override
  String get confirmPasswordHint => 'تأكيد كلمة المرور';

  @override
  String get showPasswordWord => 'إظهار';

  @override
  String get pwRuleLength => '6 أحرف على الأقل';

  @override
  String get pwRuleMatch => 'الحقلان متطابقان';

  @override
  String get passwordTooShortError =>
      'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';

  @override
  String get passwordsDontMatchError => 'كلمتا المرور غير متطابقتين';

  @override
  String get savePasswordButton => 'حفظ كلمة المرور';

  @override
  String get setPasswordError => 'تعذر حفظ كلمة المرور. حاول مرة أخرى.';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String forgotPasswordInstruction(String phone) {
    return 'سنرسل رمز تحقق عبر رسالة نصية إلى $phone';
  }

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get logoutConfirmMessage =>
      'ستحتاج إلى رقم هاتفك وكلمة المرور لتسجيل الدخول مرة أخرى.';

  @override
  String get emailLabel => 'البريد الإلكتروني (اختياري)';

  @override
  String get invalidEmailError => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get contactSupportButton => 'تواصل مع الدعم';

  @override
  String get contactSupportTitle => 'تواصل مع الدعم';

  @override
  String get callSupportButton => 'اتصل بالدعم';

  @override
  String get whatsappSupportButton => 'واتساب الدعم';

  @override
  String get emailSupportButton => 'البريد الإلكتروني للدعم';

  @override
  String get supportMessageHint => 'صف مشكلتك...';

  @override
  String get submitSupportMessageButton => 'إرسال الرسالة';

  @override
  String get supportMessageSentMessage =>
      'تم إرسال الرسالة — سيتواصل معك فريقنا قريبًا.';

  @override
  String get supportMessageError => 'تعذر إرسال رسالتك. حاول مرة أخرى.';

  @override
  String get describeIssueError => 'صف مشكلتك قبل الإرسال';

  @override
  String get myTicketsHeading => 'رسائلك';

  @override
  String get ticketStatusOpen => 'بانتظار الرد';

  @override
  String get ticketStatusResolved => 'تم الحل';

  @override
  String get supportReplyLabel => 'الدعم';

  @override
  String get accountSectionLabel => 'الحساب';
}
