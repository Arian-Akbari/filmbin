import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
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
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

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
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @appName.
  ///
  /// In fa, this message translates to:
  /// **'فیلم‌بین'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In fa, this message translates to:
  /// **'فیلم‌ها و سریال‌هایت را دنبال کن'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In fa, this message translates to:
  /// **'خانه'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In fa, this message translates to:
  /// **'جست‌وجو'**
  String get navSearch;

  /// No description provided for @navWatchlist.
  ///
  /// In fa, this message translates to:
  /// **'فهرست من'**
  String get navWatchlist;

  /// No description provided for @navLists.
  ///
  /// In fa, this message translates to:
  /// **'فهرست‌ها'**
  String get navLists;

  /// No description provided for @navProfile.
  ///
  /// In fa, this message translates to:
  /// **'پروفایل'**
  String get navProfile;

  /// No description provided for @actionRetry.
  ///
  /// In fa, this message translates to:
  /// **'تلاش دوباره'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get actionEdit;

  /// No description provided for @actionClose.
  ///
  /// In fa, this message translates to:
  /// **'بستن'**
  String get actionClose;

  /// No description provided for @actionSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get actionSend;

  /// No description provided for @actionSeeAll.
  ///
  /// In fa, this message translates to:
  /// **'دیدن همه'**
  String get actionSeeAll;

  /// No description provided for @actionShare.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک‌گذاری'**
  String get actionShare;

  /// No description provided for @actionLogin.
  ///
  /// In fa, this message translates to:
  /// **'ورود'**
  String get actionLogin;

  /// No description provided for @actionRegister.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام'**
  String get actionRegister;

  /// No description provided for @actionLogout.
  ///
  /// In fa, this message translates to:
  /// **'خروج از حساب'**
  String get actionLogout;

  /// No description provided for @actionContinueAsGuest.
  ///
  /// In fa, this message translates to:
  /// **'ورود به‌عنوان مهمان'**
  String get actionContinueAsGuest;

  /// No description provided for @authLoginTitle.
  ///
  /// In fa, this message translates to:
  /// **'خوش آمدید'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'برای ثبت فعالیت‌هایت وارد شو'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In fa, this message translates to:
  /// **'ساخت حساب تازه'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'چند ثانیه بیشتر طول نمی‌کشد'**
  String get authRegisterSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور'**
  String get authPassword;

  /// No description provided for @authPasswordConfirm.
  ///
  /// In fa, this message translates to:
  /// **'تکرار رمز عبور'**
  String get authPasswordConfirm;

  /// No description provided for @authFullName.
  ///
  /// In fa, this message translates to:
  /// **'نام و نام خانوادگی'**
  String get authFullName;

  /// No description provided for @authUsername.
  ///
  /// In fa, this message translates to:
  /// **'نام کاربری'**
  String get authUsername;

  /// No description provided for @authBio.
  ///
  /// In fa, this message translates to:
  /// **'دربارهٔ من'**
  String get authBio;

  /// No description provided for @authRememberMe.
  ///
  /// In fa, this message translates to:
  /// **'یک ماه مرا به خاطر بسپار'**
  String get authRememberMe;

  /// No description provided for @authForgotPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور را فراموش کرده‌ام'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In fa, this message translates to:
  /// **'حساب ندارید؟ ثبت‌نام کنید'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In fa, this message translates to:
  /// **'حساب دارید؟ وارد شوید'**
  String get authHaveAccount;

  /// No description provided for @authResetTitle.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی رمز عبور'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل حسابت را بنویس تا کد بازیابی بسازیم'**
  String get authResetSubtitle;

  /// No description provided for @authNewPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور تازه'**
  String get authNewPassword;

  /// No description provided for @authResetSent.
  ///
  /// In fa, this message translates to:
  /// **'کد بازیابی ساخته شد.'**
  String get authResetSent;

  /// No description provided for @authResetDone.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور عوض شد. حالا وارد شو.'**
  String get authResetDone;

  /// No description provided for @guestPrompt.
  ///
  /// In fa, this message translates to:
  /// **'برای این کار باید وارد حساب کاربری شوید.'**
  String get guestPrompt;

  /// No description provided for @guestAction.
  ///
  /// In fa, this message translates to:
  /// **'ورود یا ثبت‌نام'**
  String get guestAction;

  /// No description provided for @searchHint.
  ///
  /// In fa, this message translates to:
  /// **'نام فیلم، سریال، بازیگر یا کارگردان'**
  String get searchHint;

  /// No description provided for @searchFilters.
  ///
  /// In fa, this message translates to:
  /// **'فیلترها'**
  String get searchFilters;

  /// No description provided for @searchTypeAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get searchTypeAll;

  /// No description provided for @searchTypeMovie.
  ///
  /// In fa, this message translates to:
  /// **'فیلم'**
  String get searchTypeMovie;

  /// No description provided for @searchTypeSeries.
  ///
  /// In fa, this message translates to:
  /// **'سریال'**
  String get searchTypeSeries;

  /// No description provided for @searchByPerson.
  ///
  /// In fa, this message translates to:
  /// **'بازیگر یا کارگردان'**
  String get searchByPerson;

  /// No description provided for @searchYearFrom.
  ///
  /// In fa, this message translates to:
  /// **'از سال'**
  String get searchYearFrom;

  /// No description provided for @searchYearTo.
  ///
  /// In fa, this message translates to:
  /// **'تا سال'**
  String get searchYearTo;

  /// No description provided for @searchSort.
  ///
  /// In fa, this message translates to:
  /// **'مرتب‌سازی'**
  String get searchSort;

  /// No description provided for @searchSortPopularity.
  ///
  /// In fa, this message translates to:
  /// **'محبوب‌ترین'**
  String get searchSortPopularity;

  /// No description provided for @searchSortRating.
  ///
  /// In fa, this message translates to:
  /// **'بیشترین امتیاز'**
  String get searchSortRating;

  /// No description provided for @searchSortNewest.
  ///
  /// In fa, this message translates to:
  /// **'تازه‌ترین'**
  String get searchSortNewest;

  /// No description provided for @searchApply.
  ///
  /// In fa, this message translates to:
  /// **'اعمال فیلترها'**
  String get searchApply;

  /// No description provided for @searchClear.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن'**
  String get searchClear;

  /// No description provided for @searchEmpty.
  ///
  /// In fa, this message translates to:
  /// **'چیزی پیدا نشد.'**
  String get searchEmpty;

  /// No description provided for @searchStart.
  ///
  /// In fa, this message translates to:
  /// **'برای شروع، چیزی بنویس.'**
  String get searchStart;

  /// No description provided for @detailStory.
  ///
  /// In fa, this message translates to:
  /// **'خلاصهٔ داستان'**
  String get detailStory;

  /// No description provided for @detailCast.
  ///
  /// In fa, this message translates to:
  /// **'بازیگران'**
  String get detailCast;

  /// No description provided for @detailDirector.
  ///
  /// In fa, this message translates to:
  /// **'کارگردان'**
  String get detailDirector;

  /// No description provided for @detailCreator.
  ///
  /// In fa, this message translates to:
  /// **'سازنده'**
  String get detailCreator;

  /// No description provided for @detailCountry.
  ///
  /// In fa, this message translates to:
  /// **'کشور سازنده'**
  String get detailCountry;

  /// No description provided for @detailGenres.
  ///
  /// In fa, this message translates to:
  /// **'ژانرها'**
  String get detailGenres;

  /// No description provided for @detailSeasons.
  ///
  /// In fa, this message translates to:
  /// **'فصل‌ها'**
  String get detailSeasons;

  /// No description provided for @detailEpisodes.
  ///
  /// In fa, this message translates to:
  /// **'قسمت‌ها'**
  String get detailEpisodes;

  /// No description provided for @detailReviews.
  ///
  /// In fa, this message translates to:
  /// **'نظرها'**
  String get detailReviews;

  /// No description provided for @detailChat.
  ///
  /// In fa, this message translates to:
  /// **'گفت‌وگو'**
  String get detailChat;

  /// No description provided for @detailImdbRating.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز IMDb'**
  String get detailImdbRating;

  /// No description provided for @detailUserRating.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز کاربران'**
  String get detailUserRating;

  /// No description provided for @detailAddToList.
  ///
  /// In fa, this message translates to:
  /// **'افزودن به فهرست'**
  String get detailAddToList;

  /// No description provided for @detailMyRating.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز شما'**
  String get detailMyRating;

  /// No description provided for @detailWriteReview.
  ///
  /// In fa, this message translates to:
  /// **'نوشتن نظر'**
  String get detailWriteReview;

  /// No description provided for @detailSpoilerWarning.
  ///
  /// In fa, this message translates to:
  /// **'این نظر داستان را لو می‌دهد'**
  String get detailSpoilerWarning;

  /// No description provided for @detailShowSpoiler.
  ///
  /// In fa, this message translates to:
  /// **'نمایش نظر'**
  String get detailShowSpoiler;

  /// No description provided for @statusTitle.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت تماشا'**
  String get statusTitle;

  /// No description provided for @statusRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف وضعیت'**
  String get statusRemove;

  /// No description provided for @favoriteAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن به علاقه‌مندی‌ها'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف از علاقه‌مندی‌ها'**
  String get favoriteRemove;

  /// No description provided for @progressTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت تماشا'**
  String get progressTitle;

  /// No description provided for @markSeasonWatched.
  ///
  /// In fa, this message translates to:
  /// **'همهٔ فصل دیده شد'**
  String get markSeasonWatched;

  /// No description provided for @markSeasonUnwatched.
  ///
  /// In fa, this message translates to:
  /// **'برداشتن علامت فصل'**
  String get markSeasonUnwatched;

  /// No description provided for @watchlistFavorites.
  ///
  /// In fa, this message translates to:
  /// **'موردعلاقه‌ها'**
  String get watchlistFavorites;

  /// No description provided for @watchlistEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی به فهرست اضافه نکرده‌اید.'**
  String get watchlistEmpty;

  /// No description provided for @listsTitle.
  ///
  /// In fa, this message translates to:
  /// **'فهرست‌های من'**
  String get listsTitle;

  /// No description provided for @listsCreate.
  ///
  /// In fa, this message translates to:
  /// **'فهرست تازه'**
  String get listsCreate;

  /// No description provided for @listsName.
  ///
  /// In fa, this message translates to:
  /// **'نام فهرست'**
  String get listsName;

  /// No description provided for @listsDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیح کوتاه'**
  String get listsDescription;

  /// No description provided for @listsPublic.
  ///
  /// In fa, this message translates to:
  /// **'عمومی باشد'**
  String get listsPublic;

  /// No description provided for @listsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز فهرستی نساخته‌اید.'**
  String get listsEmpty;

  /// No description provided for @listsItemCount.
  ///
  /// In fa, this message translates to:
  /// **'{count} اثر'**
  String listsItemCount(int count);

  /// No description provided for @profileEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش پروفایل'**
  String get profileEdit;

  /// No description provided for @profileStats.
  ///
  /// In fa, this message translates to:
  /// **'آمار فعالیت'**
  String get profileStats;

  /// No description provided for @profileSettings.
  ///
  /// In fa, this message translates to:
  /// **'تنظیمات'**
  String get profileSettings;

  /// No description provided for @profileAdmin.
  ///
  /// In fa, this message translates to:
  /// **'پنل مدیریت'**
  String get profileAdmin;

  /// No description provided for @profileFeed.
  ///
  /// In fa, this message translates to:
  /// **'فعالیت دوستان'**
  String get profileFeed;

  /// No description provided for @profileChangePassword.
  ///
  /// In fa, this message translates to:
  /// **'تغییر رمز عبور'**
  String get profileChangePassword;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور فعلی'**
  String get profileCurrentPassword;

  /// No description provided for @statsWatchedMovies.
  ///
  /// In fa, this message translates to:
  /// **'فیلم دیده‌شده'**
  String get statsWatchedMovies;

  /// No description provided for @statsWatchedSeries.
  ///
  /// In fa, this message translates to:
  /// **'سریال دیده‌شده'**
  String get statsWatchedSeries;

  /// No description provided for @statsWatchedEpisodes.
  ///
  /// In fa, this message translates to:
  /// **'قسمت دیده‌شده'**
  String get statsWatchedEpisodes;

  /// No description provided for @statsWatchTime.
  ///
  /// In fa, this message translates to:
  /// **'زمان تماشا'**
  String get statsWatchTime;

  /// No description provided for @statsTopGenre.
  ///
  /// In fa, this message translates to:
  /// **'ژانر موردعلاقه'**
  String get statsTopGenre;

  /// No description provided for @statsAverageRating.
  ///
  /// In fa, this message translates to:
  /// **'میانگین امتیازها'**
  String get statsAverageRating;

  /// No description provided for @settingsTheme.
  ///
  /// In fa, this message translates to:
  /// **'پوستهٔ برنامه'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In fa, this message translates to:
  /// **'مثل سیستم'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In fa, this message translates to:
  /// **'روشن'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In fa, this message translates to:
  /// **'تاریک'**
  String get settingsThemeDark;

  /// No description provided for @settingsHideSpoilers.
  ///
  /// In fa, this message translates to:
  /// **'پنهان کردن خودکار اسپویل‌ها'**
  String get settingsHideSpoilers;

  /// No description provided for @settingsDataSaver.
  ///
  /// In fa, this message translates to:
  /// **'مصرف کمتر اینترنت'**
  String get settingsDataSaver;

  /// No description provided for @settingsAbout.
  ///
  /// In fa, this message translates to:
  /// **'دربارهٔ برنامه'**
  String get settingsAbout;

  /// No description provided for @adminUsers.
  ///
  /// In fa, this message translates to:
  /// **'کاربران'**
  String get adminUsers;

  /// No description provided for @adminReviews.
  ///
  /// In fa, this message translates to:
  /// **'نظرها'**
  String get adminReviews;

  /// No description provided for @adminReports.
  ///
  /// In fa, this message translates to:
  /// **'گزارش‌ها'**
  String get adminReports;

  /// No description provided for @adminStats.
  ///
  /// In fa, this message translates to:
  /// **'آمار سامانه'**
  String get adminStats;

  /// No description provided for @errorGeneric.
  ///
  /// In fa, this message translates to:
  /// **'خطایی رخ داد.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In fa, this message translates to:
  /// **'اتصال اینترنت برقرار نیست.'**
  String get errorOffline;

  /// No description provided for @errorLoading.
  ///
  /// In fa, this message translates to:
  /// **'دریافت اطلاعات با خطا مواجه شد.'**
  String get errorLoading;

  /// No description provided for @errorNotFound.
  ///
  /// In fa, this message translates to:
  /// **'موردی پیدا نشد.'**
  String get errorNotFound;

  /// No description provided for @offlineBanner.
  ///
  /// In fa, this message translates to:
  /// **'آفلاین هستید — اطلاعات ذخیره‌شده نمایش داده می‌شود.'**
  String get offlineBanner;

  /// No description provided for @loading.
  ///
  /// In fa, this message translates to:
  /// **'در حال دریافت…'**
  String get loading;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'fa':
      return LFa();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
