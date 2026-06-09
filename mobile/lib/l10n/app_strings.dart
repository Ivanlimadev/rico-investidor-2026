/// Centralized English UI strings for the US-focused app build.
abstract final class AppStrings {
  // Auth — login
  static const loginTitle = 'Sign in';
  static const loginSubtitle = 'Use your email and password to access your account.';
  static const sessionExpiredBanner =
      'Your session expired. Sign in again to continue with your account.';
  static const emailLabel = 'Email';
  static const emailHint = 'you@email.com';
  static const passwordLabel = 'Password';
  static const enterValidEmail = 'Enter a valid email';
  static const enterPassword = 'Enter your password';
  static const signInButton = 'Sign in';
  static const forgotPassword = 'Forgot password?';
  static const createAccount = 'Create account';
  static const loginFailed = 'Could not sign in. Please try again.';

  // Auth — register
  static const registerTitle = 'Create account';
  static const registerSubtitle = 'Fill in your details to get started.';
  static const nameLabel = 'Name';
  static const nameHint = 'How you want to be called';
  static const enterName = 'Enter your name';
  static const confirmPasswordLabel = 'Confirm password';
  static const createSecurePasswordHint = 'Create a secure password';
  static const passwordsDoNotMatch = 'Passwords do not match';
  static const passwordRequirementsNotMet = 'Password does not meet all requirements';
  static const acceptTermsRequired = 'You must accept the terms of service.';
  static const acceptTermsPrefix = 'I have read and accept the ';
  static const termsOfServiceLink = 'terms of service';
  static const registerButton = 'Create account';
  static const alreadyHaveAccount = 'Already have an account';
  static const registerFailed = 'Could not create account. Please try again.';

  // Account menu
  static const editNameTitle = 'Edit name';
  static const displayNameLabel = 'Display name';
  static const displayNameHint = 'How you appear in the app';
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const couldNotUpdateName = 'Could not update name';
  static const photoUpdated = 'Photo updated';
  static const couldNotUploadPhoto = 'Could not upload photo';
  static const signOutTitle = 'Sign out';
  static const signOutMessage =
      'You will continue using the app as a guest on this device.';
  static const signOutButton = 'Sign out';
  static const signedOut = 'You signed out';
  static const deleteAccountTitle = 'Delete account';
  static const deleteAccountMessage =
      'This action is permanent. All account data will be removed.';
  static const confirmPasswordHint = 'Confirm your password';
  static const deleteButton = 'Delete';
  static const accountDeleted = 'Account deleted';
  static const couldNotDeleteAccount = 'Could not delete account';
  static const emailMenuTitle = 'Email';
  static const signInMenuTitle = 'Sign in';
  static const signInMenuSubtitle = 'Access your existing account';
  static const createAccountMenuTitle = 'Create account';
  static const createAccountMenuSubtitle = 'Register with email and password';
  static const addPhoto = 'Add photo';
  static const changeProfilePhoto = 'Change profile photo';
  static const noPhotoSet = 'No photo set';
  static const editName = 'Edit name';
  static const currentPlan = 'Current plan';
  static const manageSubscription = 'Manage subscription';
  static const subscribeRicoPro = 'Subscribe to Rico Pro';
  static const subscriptionManageSubtitle = 'Renewal, billing and cancellation';
  static const subscriptionUpgradeSubtitle = 'Unlock alerts, portfolios and more';
  static const preferences = 'Preferences';
  static const preferencesSubtitle = 'Notifications, privacy and language';
  static const helpAndSupport = 'Help & support';
  static const privacy = 'Privacy';
  static const termsOfUse = 'Terms of use';
  static const changePassword = 'Change password';

  // Home — general
  static String homeGreeting(String name) => 'Hi, $name';
  static const settingsTooltip = 'Settings';
  static const lightThemeTooltip = 'Light theme';
  static const darkThemeTooltip = 'Dark theme';
  static const cryptoSection = 'Crypto';

  // Home — portfolio
  static const portfolioTotal = 'Portfolio total';
  static const monthlyDividends = 'Monthly dividends';
  static const avgPrice = 'Avg price';
  static const avgPriceUsd = 'Avg price (US\$)';
  static const avgPriceBrl = 'Avg price (R\$)';
  static const totalProfit = 'total profit';
  static const dividendsTapHint = 'Tap to see holdings, dates and estimated amounts';
  static const vsLastMonth = 'vs last month';
  static const syncingPortfolio = 'Syncing portfolio…';
  static const portfolioAllocation = 'Portfolio allocation';
  static const addAssetsToSeeChart = 'Add holdings to see the chart';
  static const portfolioTotalLabel = 'Portfolio total';
  static const emptyPortfolio = 'No positions yet';
  static const addAsset = 'Add holding';
  static const stalePricesMessage = 'Prices outdated — use Refresh on the Portfolio tab';
  static const noBackendConnection = 'No connection to backend (port 8000)';

  // Community
  static const communityTitle = 'Community';
  static const comingSoon = 'Coming soon';
  static const communityDiscussions = 'Discussions';
  static const communityDiscussionsSubtitle =
      'Share ideas about stocks, ETFs and strategies with other investors.';
  static const communityFeed = 'Community feed';
  static const communityFeedSubtitle =
      'Follow market moves, analysis and news from the US markets.';
  static const followInvestors = 'Follow investors';
  static const followInvestorsSubtitle =
      'See public portfolios and learn from experienced profiles.';

  // Finance categories
  static const categoryFoodDrink = 'Food & dining';
  static const categoryShopping = 'Shopping';
  static const categoryTransportation = 'Transportation';
  static const categoryHousing = 'Housing';
  static const categoryHealth = 'Health';
  static const categoryEntertainment = 'Entertainment';
  static const categoryTravel = 'Travel';
  static const categoryEducation = 'Education';
  static const categoryIncome = 'Income';
  static const categoryTransfers = 'Transfers';
  static const categoryFees = 'Fees';
  static const categoryOther = 'Other';
}
