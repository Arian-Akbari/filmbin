// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FilmBin';

  @override
  String get tagline => 'Track the films and series you love';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navWatchlist => 'My list';

  @override
  String get navLists => 'Lists';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSend => 'Send';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionShare => 'Share';

  @override
  String get actionLogin => 'Sign in';

  @override
  String get actionRegister => 'Sign up';

  @override
  String get actionLogout => 'Sign out';

  @override
  String get actionContinueAsGuest => 'Continue as guest';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authLoginSubtitle => 'Sign in to keep track of what you watch';

  @override
  String get authRegisterTitle => 'Create an account';

  @override
  String get authRegisterSubtitle => 'It only takes a moment';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordConfirm => 'Repeat password';

  @override
  String get authFullName => 'Full name';

  @override
  String get authUsername => 'Username';

  @override
  String get authBio => 'About me';

  @override
  String get authRememberMe => 'Keep me signed in for a month';

  @override
  String get authForgotPassword => 'I forgot my password';

  @override
  String get authNoAccount => 'No account yet? Sign up';

  @override
  String get authHaveAccount => 'Already registered? Sign in';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetSubtitle => 'Enter your email to get a reset code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authResetSent => 'Reset code created.';

  @override
  String get authResetDone => 'Password changed. You can sign in now.';

  @override
  String get guestPrompt => 'Sign in to do that.';

  @override
  String get guestAction => 'Sign in or register';

  @override
  String get searchHint => 'Film, series, actor or director';

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchTypeAll => 'All';

  @override
  String get searchTypeMovie => 'Movies';

  @override
  String get searchTypeSeries => 'Series';

  @override
  String get searchByPerson => 'Actor or director';

  @override
  String get searchYearFrom => 'From year';

  @override
  String get searchYearTo => 'To year';

  @override
  String get searchSort => 'Sort by';

  @override
  String get searchSortPopularity => 'Most popular';

  @override
  String get searchSortRating => 'Highest rated';

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchApply => 'Apply filters';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchEmpty => 'Nothing found.';

  @override
  String get searchStart => 'Type something to start.';

  @override
  String get detailStory => 'Storyline';

  @override
  String get detailCast => 'Cast';

  @override
  String get detailDirector => 'Director';

  @override
  String get detailCreator => 'Creator';

  @override
  String get detailCountry => 'Country';

  @override
  String get detailGenres => 'Genres';

  @override
  String get detailSeasons => 'Seasons';

  @override
  String get detailEpisodes => 'Episodes';

  @override
  String get detailReviews => 'Reviews';

  @override
  String get detailChat => 'Chat';

  @override
  String get detailImdbRating => 'IMDb rating';

  @override
  String get detailUserRating => 'Users\' rating';

  @override
  String get detailAddToList => 'Add to a list';

  @override
  String get detailMyRating => 'Your rating';

  @override
  String get detailWriteReview => 'Write a review';

  @override
  String get detailSpoilerWarning => 'This review contains spoilers';

  @override
  String get detailShowSpoiler => 'Show anyway';

  @override
  String get statusTitle => 'Watch status';

  @override
  String get statusRemove => 'Remove status';

  @override
  String get favoriteAdd => 'Add to favourites';

  @override
  String get favoriteRemove => 'Remove from favourites';

  @override
  String get progressTitle => 'Watch progress';

  @override
  String get markSeasonWatched => 'Mark whole season watched';

  @override
  String get markSeasonUnwatched => 'Unmark season';

  @override
  String get watchlistFavorites => 'Favourites';

  @override
  String get watchlistEmpty => 'Your list is still empty.';

  @override
  String get listsTitle => 'My lists';

  @override
  String get listsCreate => 'New list';

  @override
  String get listsName => 'List name';

  @override
  String get listsDescription => 'Short description';

  @override
  String get listsPublic => 'Public list';

  @override
  String get listsEmpty => 'No lists yet.';

  @override
  String listsItemCount(int count) {
    return '$count titles';
  }

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileStats => 'Activity stats';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileAdmin => 'Admin panel';

  @override
  String get profileFeed => 'Friends\' activity';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get statsWatchedMovies => 'Films watched';

  @override
  String get statsWatchedSeries => 'Series watched';

  @override
  String get statsWatchedEpisodes => 'Episodes watched';

  @override
  String get statsWatchTime => 'Watch time';

  @override
  String get statsTopGenre => 'Favourite genre';

  @override
  String get statsAverageRating => 'Average rating';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsHideSpoilers => 'Hide spoilers by default';

  @override
  String get settingsDataSaver => 'Data saver';

  @override
  String get settingsAbout => 'About';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminReviews => 'Reviews';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminStats => 'System stats';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get errorOffline => 'No internet connection.';

  @override
  String get errorLoading => 'Could not load the data.';

  @override
  String get errorNotFound => 'Nothing found.';

  @override
  String get offlineBanner => 'You are offline — showing saved data.';

  @override
  String get loading => 'Loading…';
}
