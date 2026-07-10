import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal Manager'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get commonExit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMainIntentionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Main intention updated successfully'**
  String get settingsMainIntentionUpdated;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore;

  /// No description provided for @settingsExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get settingsExportBackup;

  /// No description provided for @settingsExportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your data as JSON file'**
  String get settingsExportBackupSubtitle;

  /// No description provided for @settingsImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get settingsImportBackup;

  /// No description provided for @settingsImportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get settingsImportBackupSubtitle;

  /// No description provided for @settingsTroubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get settingsTroubleshooting;

  /// No description provided for @settingsResetRoutines.
  ///
  /// In en, this message translates to:
  /// **'Reset Routines'**
  String get settingsResetRoutines;

  /// No description provided for @settingsResetRoutinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark all as not done, reschedule notifications'**
  String get settingsResetRoutinesSubtitle;

  /// No description provided for @settingsResetRoutinesMessage.
  ///
  /// In en, this message translates to:
  /// **'This will mark all routines as not done and reschedule notifications.\n\nStreak data will be preserved.'**
  String get settingsResetRoutinesMessage;

  /// No description provided for @settingsRoutinesResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Routines reset successfully'**
  String get settingsRoutinesResetSuccess;

  /// No description provided for @settingsResetGoals.
  ///
  /// In en, this message translates to:
  /// **'Reset Goals'**
  String get settingsResetGoals;

  /// No description provided for @settingsResetGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset completion status and time spent'**
  String get settingsResetGoalsSubtitle;

  /// No description provided for @settingsResetGoalsMessage.
  ///
  /// In en, this message translates to:
  /// **'This will reset all goal completion status, time spent, and stop active sessions.'**
  String get settingsResetGoalsMessage;

  /// No description provided for @settingsGoalsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Goals reset successfully'**
  String get settingsGoalsResetSuccess;

  /// No description provided for @settingsDeleteAllGoals.
  ///
  /// In en, this message translates to:
  /// **'Delete All Goals'**
  String get settingsDeleteAllGoals;

  /// No description provided for @settingsDeleteAllGoalsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? All goals will be permanently deleted.\n\nThis cannot be undone.'**
  String get settingsDeleteAllGoalsMessage;

  /// No description provided for @settingsAllGoalsDeleted.
  ///
  /// In en, this message translates to:
  /// **'All goals deleted'**
  String get settingsAllGoalsDeleted;

  /// No description provided for @settingsDeleteAllRoutines.
  ///
  /// In en, this message translates to:
  /// **'Delete All Routines'**
  String get settingsDeleteAllRoutines;

  /// No description provided for @settingsDeleteAllRoutinesMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? All routines and their notifications will be permanently deleted.\n\nThis cannot be undone.'**
  String get settingsDeleteAllRoutinesMessage;

  /// No description provided for @settingsAllRoutinesDeleted.
  ///
  /// In en, this message translates to:
  /// **'All routines deleted'**
  String get settingsAllRoutinesDeleted;

  /// No description provided for @settingsDeleteAllRecords.
  ///
  /// In en, this message translates to:
  /// **'Delete All Records'**
  String get settingsDeleteAllRecords;

  /// No description provided for @settingsDeleteAllRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notes, tags, and all associated data'**
  String get settingsDeleteAllRecordsSubtitle;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsDangerZone;

  /// No description provided for @settingsDangerZoneDescription.
  ///
  /// In en, this message translates to:
  /// **'These actions are irreversible. Make sure you have a backup.'**
  String get settingsDangerZoneDescription;

  /// No description provided for @settingsDeleteDataPermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete data permanently'**
  String get settingsDeleteDataPermanently;

  /// No description provided for @settingsDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get settingsDebug;

  /// No description provided for @settingsPrintTags.
  ///
  /// In en, this message translates to:
  /// **'Print Tags to Console'**
  String get settingsPrintTags;

  /// No description provided for @settingsTagsPrinted.
  ///
  /// In en, this message translates to:
  /// **'Tags printed to debug console (flutter run / Logcat)'**
  String get settingsTagsPrinted;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get commonShow;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @navGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoals;

  /// No description provided for @navRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get navRoutines;

  /// No description provided for @navTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get navTodo;

  /// No description provided for @navTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get navTags;

  /// No description provided for @navWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get navWorkspace;

  /// No description provided for @navAiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get navAiChat;

  /// No description provided for @backupEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Here is the backup of all notes and tags.'**
  String get backupEmailBody;

  /// No description provided for @backupEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Backup of Notes'**
  String get backupEmailSubject;

  /// No description provided for @homeDeleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get homeDeleteRecordTitle;

  /// No description provided for @homeDeleteRecordMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get homeDeleteRecordMessage;

  /// No description provided for @homeChronoTagMissing.
  ///
  /// In en, this message translates to:
  /// **'Chrono tag not found. Please restart the app.'**
  String get homeChronoTagMissing;

  /// No description provided for @homeChronoNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Chrono note added'**
  String get homeChronoNoteAdded;

  /// No description provided for @homeChronoNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create Chrono note: {error}'**
  String homeChronoNoteFailed(String error);

  /// No description provided for @homeChronoInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Chronological notes'**
  String get homeChronoInfoTitle;

  /// No description provided for @homeChronoInfoBody.
  ///
  /// In en, this message translates to:
  /// **'The Chrono tag is for timeline notes — quick logs of what happens during your day:\n\n• visited a place\n• something happened\n• currently at a location\n• met someone\n\nUse the quick input to capture moments as they happen.'**
  String get homeChronoInfoBody;

  /// No description provided for @homeChronoQuickHint.
  ///
  /// In en, this message translates to:
  /// **'Quick chrono note...'**
  String get homeChronoQuickHint;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search records...'**
  String get homeSearchHint;

  /// No description provided for @homeFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter records'**
  String get homeFilterTooltip;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Records'**
  String get filterTitle;

  /// No description provided for @filterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select which types of records to show:'**
  String get filterSubtitle;

  /// No description provided for @filterShowGoals.
  ///
  /// In en, this message translates to:
  /// **'Show records from Goals'**
  String get filterShowGoals;

  /// No description provided for @filterShowGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include records created from goal sessions'**
  String get filterShowGoalsSubtitle;

  /// No description provided for @filterShowRoutines.
  ///
  /// In en, this message translates to:
  /// **'Show records from Routines'**
  String get filterShowRoutines;

  /// No description provided for @filterShowRoutinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include records created from completed routines'**
  String get filterShowRoutinesSubtitle;

  /// No description provided for @filterShowTodos.
  ///
  /// In en, this message translates to:
  /// **'Show records from Todos'**
  String get filterShowTodos;

  /// No description provided for @filterShowTodosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include records created from completed todos'**
  String get filterShowTodosSubtitle;

  /// No description provided for @filterShowProductivity.
  ///
  /// In en, this message translates to:
  /// **'Show Productivity Index'**
  String get filterShowProductivity;

  /// No description provided for @filterShowProductivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include daily productivity score records'**
  String get filterShowProductivitySubtitle;

  /// No description provided for @noteLocked.
  ///
  /// In en, this message translates to:
  /// **'Note locked'**
  String get noteLocked;

  /// No description provided for @noteUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Note unlocked'**
  String get noteUnlocked;

  /// No description provided for @createNewTagTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create new tag'**
  String get createNewTagTooltip;

  /// No description provided for @noTagsFound.
  ///
  /// In en, this message translates to:
  /// **'No tags found'**
  String get noTagsFound;

  /// No description provided for @searchTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Search tags...'**
  String get searchTagsHint;

  /// No description provided for @saveNoteFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the note first'**
  String get saveNoteFirst;

  /// No description provided for @writeYourNote.
  ///
  /// In en, this message translates to:
  /// **'Write your note'**
  String get writeYourNote;

  /// No description provided for @cardSpaceButton.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get cardSpaceButton;

  /// No description provided for @newWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspaceTitle;

  /// No description provided for @workspaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceNameHint;

  /// No description provided for @createAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Create & Add'**
  String get createAndAdd;

  /// No description provided for @addedToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedToWorkspace(String name);

  /// No description provided for @addToWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to Workspace'**
  String get addToWorkspaceTitle;

  /// No description provided for @noWorkspacesYet.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet'**
  String get noWorkspacesYet;

  /// No description provided for @tapNewToCreate.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New\" to create one'**
  String get tapNewToCreate;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get commonPreview;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @workspaceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace?'**
  String get workspaceDeleteTitle;

  /// No description provided for @noteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No notes} one{{count} note} other{{count} notes}}'**
  String noteCount(int count);

  /// No description provided for @workspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspacesTitle;

  /// No description provided for @workspaceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Workspaces Yet'**
  String get workspaceEmptyTitle;

  /// No description provided for @workspaceEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first workspace.\nLink notes, write documents, and use AI to find related content.'**
  String get workspaceEmptyHint;

  /// No description provided for @workspaceCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Workspace'**
  String get workspaceCreateButton;

  /// No description provided for @newWorkspaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspaceTooltip;

  /// No description provided for @workspaceChangeColor.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get workspaceChangeColor;

  /// No description provided for @workspaceRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{name}\" and its note links. Notes themselves are not deleted.'**
  String workspaceRemoveMessage(String name);

  /// No description provided for @editorWriteMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'Write in Markdown…'**
  String get editorWriteMarkdownHint;

  /// No description provided for @editorNoLinkedNotes.
  ///
  /// In en, this message translates to:
  /// **'No linked notes yet'**
  String get editorNoLinkedNotes;

  /// No description provided for @editorTapAddHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add\" to search or use AI'**
  String get editorTapAddHint;

  /// No description provided for @editorLinkedNotesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Linked notes'**
  String get editorLinkedNotesTooltip;

  /// No description provided for @editorAddNotesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get editorAddNotesTooltip;

  /// No description provided for @editorChatDocNotes.
  ///
  /// In en, this message translates to:
  /// **'Chat: doc + notes'**
  String get editorChatDocNotes;

  /// No description provided for @editorChatDocOnly.
  ///
  /// In en, this message translates to:
  /// **'Chat: doc only'**
  String get editorChatDocOnly;

  /// No description provided for @editorChatIncludeNotes.
  ///
  /// In en, this message translates to:
  /// **'AI Chat will include linked notes'**
  String get editorChatIncludeNotes;

  /// No description provided for @editorChatDocumentOnly.
  ///
  /// In en, this message translates to:
  /// **'AI Chat: document only'**
  String get editorChatDocumentOnly;

  /// No description provided for @editorLinkedNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked Notes'**
  String get editorLinkedNotesTitle;

  /// No description provided for @editorShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get editorShowLess;

  /// No description provided for @editorShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more…'**
  String get editorShowMore;

  /// No description provided for @editorNoTagsSelected.
  ///
  /// In en, this message translates to:
  /// **'No tags selected — AI will scan {count} notes.\nPick tags to narrow scope.'**
  String editorNoTagsSelected(int count);

  /// No description provided for @editorAiSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'AI search failed: {error}'**
  String editorAiSearchFailed(String error);

  /// No description provided for @editorNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added to workspace'**
  String get editorNoteAdded;

  /// No description provided for @editorFindNotes.
  ///
  /// In en, this message translates to:
  /// **'Find Notes'**
  String get editorFindNotes;

  /// No description provided for @editorTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get editorTabSearch;

  /// No description provided for @editorTabAiFind.
  ///
  /// In en, this message translates to:
  /// **'AI Find'**
  String get editorTabAiFind;

  /// No description provided for @editorSearchNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes…'**
  String get editorSearchNotesHint;

  /// No description provided for @editorNoNotesFound.
  ///
  /// In en, this message translates to:
  /// **'No notes found'**
  String get editorNoNotesFound;

  /// No description provided for @editorAllLinked.
  ///
  /// In en, this message translates to:
  /// **'All matching notes already linked'**
  String get editorAllLinked;

  /// No description provided for @editorDescribeLooking.
  ///
  /// In en, this message translates to:
  /// **'Describe what you\'re looking for'**
  String get editorDescribeLooking;

  /// No description provided for @editorAiPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Notes about productivity techniques'**
  String get editorAiPromptHint;

  /// No description provided for @editorSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get editorSearching;

  /// No description provided for @editorFindWithAi.
  ///
  /// In en, this message translates to:
  /// **'Find with AI'**
  String get editorFindWithAi;

  /// No description provided for @editorEnterPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a prompt and tap Find'**
  String get editorEnterPromptHint;

  /// No description provided for @editorAllFoundLinked.
  ///
  /// In en, this message translates to:
  /// **'All found notes already linked'**
  String get editorAllFoundLinked;

  /// No description provided for @editorLargeSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Large search'**
  String get editorLargeSearchTitle;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @editorRenameWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Rename workspace'**
  String get editorRenameWorkspace;

  /// No description provided for @editorWorkspaceColor.
  ///
  /// In en, this message translates to:
  /// **'Workspace color'**
  String get editorWorkspaceColor;

  /// No description provided for @editorWorkspaceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Workspace not found'**
  String get editorWorkspaceNotFound;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commonUpdate;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @tagEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get tagEditTooltip;

  /// No description provided for @goalImportance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get goalImportance;

  /// No description provided for @insightsOutsideContext.
  ///
  /// In en, this message translates to:
  /// **'Outside context window'**
  String get insightsOutsideContext;

  /// No description provided for @errorCouldNotLaunch.
  ///
  /// In en, this message translates to:
  /// **'Could not launch {uri}'**
  String errorCouldNotLaunch(String uri);

  /// No description provided for @drawerPremium.
  ///
  /// In en, this message translates to:
  /// **'Chrono Premium'**
  String get drawerPremium;

  /// No description provided for @drawerPremiumTry.
  ///
  /// In en, this message translates to:
  /// **'Try Premium'**
  String get drawerPremiumTry;

  /// No description provided for @drawerPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get drawerPremiumActive;

  /// No description provided for @drawerPremiumTrial.
  ///
  /// In en, this message translates to:
  /// **'3 days free'**
  String get drawerPremiumTrial;

  /// No description provided for @drawerSectionAiPrompts.
  ///
  /// In en, this message translates to:
  /// **'AI & PROMPTS'**
  String get drawerSectionAiPrompts;

  /// No description provided for @drawerPrompts.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get drawerPrompts;

  /// No description provided for @drawerGptSettings.
  ///
  /// In en, this message translates to:
  /// **'GPT Settings'**
  String get drawerGptSettings;

  /// No description provided for @drawerSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get drawerSectionGeneral;

  /// No description provided for @drawerShowIntro.
  ///
  /// In en, this message translates to:
  /// **'Show Intro'**
  String get drawerShowIntro;

  /// No description provided for @drawerPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get drawerPrivacyPolicy;

  /// No description provided for @drawerTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use (EULA)'**
  String get drawerTermsOfUse;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteAllMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all notes? This action cannot be undone.'**
  String get confirmDeleteAllMessage;

  /// No description provided for @allNotesDeleted.
  ///
  /// In en, this message translates to:
  /// **'All notes have been deleted successfully.'**
  String get allNotesDeleted;

  /// No description provided for @failedToDeleteNotes.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete notes: {error}'**
  String failedToDeleteNotes(String error);

  /// No description provided for @apiAccessSettings.
  ///
  /// In en, this message translates to:
  /// **'API Access Settings'**
  String get apiAccessSettings;

  /// No description provided for @selectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// No description provided for @tokenLimit.
  ///
  /// In en, this message translates to:
  /// **'Token limit: {tpm}'**
  String tokenLimit(String tpm);

  /// No description provided for @openAiApiKey.
  ///
  /// In en, this message translates to:
  /// **'OpenAI API Key'**
  String get openAiApiKey;

  /// No description provided for @geminiApiKey.
  ///
  /// In en, this message translates to:
  /// **'Gemini API Key'**
  String get geminiApiKey;

  /// No description provided for @getOpenAiKey.
  ///
  /// In en, this message translates to:
  /// **'Get OpenAI Key'**
  String get getOpenAiKey;

  /// No description provided for @getGeminiKey.
  ///
  /// In en, this message translates to:
  /// **'Get Gemini Key'**
  String get getGeminiKey;

  /// No description provided for @apiResponseDelay.
  ///
  /// In en, this message translates to:
  /// **'Response delay: {delay}'**
  String apiResponseDelay(String delay);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get exportTitle;

  /// No description provided for @exportSelectData.
  ///
  /// In en, this message translates to:
  /// **'Select data to include in your backup'**
  String get exportSelectData;

  /// No description provided for @exportSelectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one data type.'**
  String get exportSelectAtLeastOne;

  /// No description provided for @exportExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting data...'**
  String get exportExporting;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Backup ready! Choose how to save it.'**
  String get exportReady;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportSharedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup shared successfully!'**
  String get exportSharedSuccess;

  /// No description provided for @exportShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String exportShareFailed(String error);

  /// No description provided for @exportEmailOpened.
  ///
  /// In en, this message translates to:
  /// **'Email composer opened!'**
  String get exportEmailOpened;

  /// No description provided for @exportNoEmailApp.
  ///
  /// In en, this message translates to:
  /// **'No email app found. Please use \'Share\' instead.'**
  String get exportNoEmailApp;

  /// No description provided for @exportEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Email failed: {error}'**
  String exportEmailFailed(String error);

  /// No description provided for @exportLabelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes & Tags'**
  String get exportLabelNotes;

  /// No description provided for @exportLabelTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get exportLabelTodos;

  /// No description provided for @exportLabelInstructions.
  ///
  /// In en, this message translates to:
  /// **'AI Instructions'**
  String get exportLabelInstructions;

  /// No description provided for @exportCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get exportCreateBackup;

  /// No description provided for @exportEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get exportEmailButton;

  /// No description provided for @exportShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exportShareButton;

  /// No description provided for @exportBackupSubject.
  ///
  /// In en, this message translates to:
  /// **'Chrono Data Backup'**
  String get exportBackupSubject;

  /// No description provided for @exportBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Here is the backup of your Chrono data including: {types}.'**
  String exportBackupBody(String types);

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importTitle;

  /// No description provided for @importPressButton.
  ///
  /// In en, this message translates to:
  /// **'Press the button to import data.'**
  String get importPressButton;

  /// No description provided for @importNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected.'**
  String get importNoFileSelected;

  /// No description provided for @importReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace All Data?'**
  String get importReplaceTitle;

  /// No description provided for @importReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'Import will DELETE all current data and replace it with backup.'**
  String get importReplaceMessage;

  /// No description provided for @importCurrentToDelete.
  ///
  /// In en, this message translates to:
  /// **'Current data to be deleted:'**
  String get importCurrentToDelete;

  /// No description provided for @importLabelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get importLabelNotes;

  /// No description provided for @importTotalToDelete.
  ///
  /// In en, this message translates to:
  /// **'Total: {count} items will be deleted'**
  String importTotalToDelete(int count);

  /// No description provided for @importBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Make sure you have a backup before proceeding!'**
  String get importBackupWarning;

  /// No description provided for @importDeleteAndImport.
  ///
  /// In en, this message translates to:
  /// **'Delete & Import'**
  String get importDeleteAndImport;

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled.'**
  String get importCancelled;

  /// No description provided for @importDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting current data...'**
  String get importDeleting;

  /// No description provided for @importImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importImporting;

  /// No description provided for @importImportingRoutines.
  ///
  /// In en, this message translates to:
  /// **'Importing routines...'**
  String get importImportingRoutines;

  /// No description provided for @importImportingGoals.
  ///
  /// In en, this message translates to:
  /// **'Importing goals...'**
  String get importImportingGoals;

  /// No description provided for @importImportingTodos.
  ///
  /// In en, this message translates to:
  /// **'Importing todos...'**
  String get importImportingTodos;

  /// No description provided for @importImportingReminders.
  ///
  /// In en, this message translates to:
  /// **'Importing todo reminders...'**
  String get importImportingReminders;

  /// No description provided for @importImportingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Importing instructions...'**
  String get importImportingInstructions;

  /// No description provided for @importImportingNotes.
  ///
  /// In en, this message translates to:
  /// **'Importing notes and tags...'**
  String get importImportingNotes;

  /// No description provided for @importImportingWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Importing workspaces...'**
  String get importImportingWorkspaces;

  /// No description provided for @importSuccessCount.
  ///
  /// In en, this message translates to:
  /// **'Import successful! Imported {count} items.'**
  String importSuccessCount(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @importSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File & Import'**
  String get importSelectFile;

  /// No description provided for @importWarningLong.
  ///
  /// In en, this message translates to:
  /// **'Select a JSON backup file to import.\n\n⚠️ WARNING: Import will DELETE all current data and replace it with the backup.\n\nYou will see a confirmation screen before deletion.'**
  String get importWarningLong;

  /// No description provided for @promptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get promptsTitle;

  /// No description provided for @promptsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Prompt'**
  String get promptsNewTitle;

  /// No description provided for @promptsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Prompt'**
  String get promptsEditTitle;

  /// No description provided for @promptsEnterText.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt text...'**
  String get promptsEnterText;

  /// No description provided for @promptsOnTapBehavior.
  ///
  /// In en, this message translates to:
  /// **'ON TAP BEHAVIOR'**
  String get promptsOnTapBehavior;

  /// No description provided for @promptsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Prompt'**
  String get promptsCreate;

  /// No description provided for @promptsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get promptsSaveChanges;

  /// No description provided for @promptsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Prompt?'**
  String get promptsDeleteTitle;

  /// No description provided for @promptsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{text}\"?'**
  String promptsDeleteMessage(String text);

  /// No description provided for @promptsSendInstantly.
  ///
  /// In en, this message translates to:
  /// **'Send instantly'**
  String get promptsSendInstantly;

  /// No description provided for @promptsSendInstantlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Sends the prompt immediately'**
  String get promptsSendInstantlyDesc;

  /// No description provided for @promptsInsertToInput.
  ///
  /// In en, this message translates to:
  /// **'Insert to input'**
  String get promptsInsertToInput;

  /// No description provided for @promptsInsertToInputDesc.
  ///
  /// In en, this message translates to:
  /// **'Pastes text for editing'**
  String get promptsInsertToInputDesc;

  /// No description provided for @promptsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Prompts Yet'**
  String get promptsEmptyTitle;

  /// No description provided for @promptsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Create quick prompts to speed up your AI conversations. Tap + to get started.'**
  String get promptsEmptyDesc;

  /// No description provided for @promptsSendsInstantly.
  ///
  /// In en, this message translates to:
  /// **'Sends instantly'**
  String get promptsSendsInstantly;

  /// No description provided for @promptsInsertsToInput.
  ///
  /// In en, this message translates to:
  /// **'Inserts to input'**
  String get promptsInsertsToInput;

  /// No description provided for @goalsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading goals: {error}'**
  String goalsErrorLoading(String error);

  /// No description provided for @goalDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Goal \"{title}\" deleted successfully'**
  String goalDeletedSuccess(String title);

  /// No description provided for @goalErrorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting goal: {error}'**
  String goalErrorDeleting(String error);

  /// No description provided for @goalErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving goal: {error}'**
  String goalErrorSaving(String error);

  /// No description provided for @goalsHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed goals'**
  String get goalsHideCompleted;

  /// No description provided for @goalsShowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Show completed goals'**
  String get goalsShowCompleted;

  /// No description provided for @goalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goalCompleted;

  /// No description provided for @goalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Goals Yet'**
  String get goalsEmptyTitle;

  /// No description provided for @goalsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your first goal to start tracking your progress and building better habits.'**
  String get goalsEmptyDesc;

  /// No description provided for @goalsCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Goal'**
  String get goalsCreateFirst;

  /// No description provided for @goalEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get goalEditTitle;

  /// No description provided for @goalNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get goalNewTitle;

  /// No description provided for @goalTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal Title'**
  String get goalTitleLabel;

  /// No description provided for @goalTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a goal title'**
  String get goalTitleRequired;

  /// No description provided for @goalHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get goalHours;

  /// No description provided for @goalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get goalMinutes;

  /// No description provided for @goalSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Session Duration (minutes)'**
  String get goalSessionDuration;

  /// No description provided for @goalUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Goal'**
  String get goalUpdate;

  /// No description provided for @goalCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get goalCreate;

  /// No description provided for @goalSpecifyTime.
  ///
  /// In en, this message translates to:
  /// **'Please specify at least some hours or minutes'**
  String get goalSpecifyTime;

  /// No description provided for @goalTimeTarget.
  ///
  /// In en, this message translates to:
  /// **'Time Target'**
  String get goalTimeTarget;

  /// No description provided for @goalSessionDurationHelper.
  ///
  /// In en, this message translates to:
  /// **'How long each work session should be'**
  String get goalSessionDurationHelper;

  /// No description provided for @validatorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get validatorInvalid;

  /// No description provided for @validatorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validatorRequired;

  /// No description provided for @goalMinutesRange.
  ///
  /// In en, this message translates to:
  /// **'0-59'**
  String get goalMinutesRange;

  /// No description provided for @goalCannotDeleteActive.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete an active goal. Stop the session first.'**
  String get goalCannotDeleteActive;

  /// No description provided for @goalTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Time spent: {time}'**
  String goalTimeSpent(String time);

  /// No description provided for @goalRunning.
  ///
  /// In en, this message translates to:
  /// **'Running: {time}'**
  String goalRunning(String time);

  /// No description provided for @goalComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get goalComplete;

  /// No description provided for @goalUncomplete.
  ///
  /// In en, this message translates to:
  /// **'Uncomplete'**
  String get goalUncomplete;

  /// No description provided for @goalDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Goal'**
  String get goalDeleteTitle;

  /// No description provided for @goalDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?\n\nThis action cannot be undone.'**
  String goalDeleteMessage(String title);

  /// No description provided for @routineArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String routineArchived(int count);

  /// No description provided for @routineViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View completion history'**
  String get routineViewHistory;

  /// No description provided for @routineDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Routine'**
  String get routineDeleteTitle;

  /// No description provided for @routineDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String routineDeleteMessage(String name);

  /// No description provided for @routinesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Routines Yet'**
  String get routinesEmptyTitle;

  /// No description provided for @routinesEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your first routine to build consistent daily habits and stay organized.'**
  String get routinesEmptyDesc;

  /// No description provided for @routinesCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Routine'**
  String get routinesCreateFirst;

  /// No description provided for @routineSelectDay.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one day'**
  String get routineSelectDay;

  /// No description provided for @routineEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Routine'**
  String get routineEditTitle;

  /// No description provided for @routineNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Routine'**
  String get routineNewTitle;

  /// No description provided for @routineNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Routine Name'**
  String get routineNameLabel;

  /// No description provided for @routineNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get routineNameRequired;

  /// No description provided for @routineDaysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Days of Week'**
  String get routineDaysOfWeek;

  /// No description provided for @routineRemindersPersistence.
  ///
  /// In en, this message translates to:
  /// **'Reminders & Persistence'**
  String get routineRemindersPersistence;

  /// No description provided for @routineSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get routineSchedule;

  /// No description provided for @routineTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get routineTime;

  /// No description provided for @routineHideOtherDays.
  ///
  /// In en, this message translates to:
  /// **'Hide other days'**
  String get routineHideOtherDays;

  /// No description provided for @routineShowOtherDays.
  ///
  /// In en, this message translates to:
  /// **'Show other days'**
  String get routineShowOtherDays;

  /// No description provided for @routineOtherDays.
  ///
  /// In en, this message translates to:
  /// **'Other days'**
  String get routineOtherDays;

  /// No description provided for @routineDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get routineDuration;

  /// No description provided for @routineInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get routineInterval;

  /// No description provided for @routineAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional'**
  String get routineAdditional;

  /// No description provided for @routineTrackStreak.
  ///
  /// In en, this message translates to:
  /// **'Track streak'**
  String get routineTrackStreak;

  /// No description provided for @routineTrackStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Display streak count when completing this routine'**
  String get routineTrackStreakDesc;

  /// No description provided for @routineErrorCreating.
  ///
  /// In en, this message translates to:
  /// **'Error creating routine record: {error}'**
  String routineErrorCreating(String error);

  /// No description provided for @commonMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get commonMin;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @todoSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Please select a deadline date'**
  String get todoSelectDeadline;

  /// No description provided for @todoErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving todo: {error}'**
  String todoErrorSaving(String error);

  /// No description provided for @todoEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Todo'**
  String get todoEditTitle;

  /// No description provided for @todoNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Todo'**
  String get todoNewTitle;

  /// No description provided for @todoTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get todoTitleLabel;

  /// No description provided for @todoTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get todoTitleRequired;

  /// No description provided for @todoNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get todoNoDate;

  /// No description provided for @todoSelectDeadlineDate.
  ///
  /// In en, this message translates to:
  /// **'Select a deadline date'**
  String get todoSelectDeadlineDate;

  /// No description provided for @todoRemindTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Remind me tomorrow'**
  String get todoRemindTomorrow;

  /// No description provided for @todoRemindDaily.
  ///
  /// In en, this message translates to:
  /// **'Remind me every day'**
  String get todoRemindDaily;

  /// No description provided for @todoAtTime.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String todoAtTime(String time);

  /// No description provided for @todoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Todo'**
  String get todoUpdate;

  /// No description provided for @todoCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Todo'**
  String get todoCreate;

  /// No description provided for @todoType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get todoType;

  /// No description provided for @todoTypeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get todoTypeTomorrow;

  /// No description provided for @todoTypeDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get todoTypeDeadline;

  /// No description provided for @todoDeadlineDate.
  ///
  /// In en, this message translates to:
  /// **'Deadline Date'**
  String get todoDeadlineDate;

  /// No description provided for @todoPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get todoPickDate;

  /// No description provided for @todoNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get todoNotification;

  /// No description provided for @todoRepeatNotifications.
  ///
  /// In en, this message translates to:
  /// **'Repeat notifications'**
  String get todoRepeatNotifications;

  /// No description provided for @todoPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: '**
  String get todoPeriodLabel;

  /// No description provided for @todoEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every: '**
  String get todoEveryLabel;

  /// No description provided for @commonChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// No description provided for @todoNotifyOnDay.
  ///
  /// In en, this message translates to:
  /// **'Get a notification on the day'**
  String get todoNotifyOnDay;

  /// No description provided for @todoNotifyDaily.
  ///
  /// In en, this message translates to:
  /// **'Get a notification every day until the deadline'**
  String get todoNotifyDaily;

  /// No description provided for @todoNotificationPreview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} notification} other{{count} notifications}}: starting {period} before, every {interval}'**
  String todoNotificationPreview(int count, String period, String interval);

  /// No description provided for @tagErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving tag: {error}'**
  String tagErrorSaving(String error);

  /// No description provided for @tagSystemCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'System tags cannot be deleted'**
  String get tagSystemCannotDelete;

  /// No description provided for @tagDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag deletion'**
  String get tagDeleteTitle;

  /// No description provided for @tagDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this tag?'**
  String get tagDeleteMessage;

  /// No description provided for @tagEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tag'**
  String get tagEditTitle;

  /// No description provided for @tagCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get tagCreateTitle;

  /// No description provided for @tagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagNameLabel;

  /// No description provided for @tagSystemNameCannotChange.
  ///
  /// In en, this message translates to:
  /// **'System tag name cannot be changed'**
  String get tagSystemNameCannotChange;

  /// No description provided for @tagEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter tag name'**
  String get tagEnterName;

  /// No description provided for @tagNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a tag name'**
  String get tagNameRequired;

  /// No description provided for @tagColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Color'**
  String get tagColorLabel;

  /// No description provided for @productivityWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get productivityWeek;

  /// No description provided for @productivityMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get productivityMonth;

  /// No description provided for @productivityAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get productivityAllTime;

  /// No description provided for @productivityNoActiveToday.
  ///
  /// In en, this message translates to:
  /// **'No active routines or goals today'**
  String get productivityNoActiveToday;

  /// No description provided for @productivityCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'current streak'**
  String get productivityCurrentStreak;

  /// No description provided for @productivityBestStreak.
  ///
  /// In en, this message translates to:
  /// **'best streak'**
  String get productivityBestStreak;

  /// No description provided for @productivityRoutinesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Routines completed'**
  String get productivityRoutinesCompleted;

  /// No description provided for @productivityGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get productivityGoalProgress;

  /// No description provided for @productivityDayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String productivityDayCount(int count);

  /// No description provided for @productivityNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period yet'**
  String get productivityNoData;

  /// No description provided for @productivityNoBreakdown.
  ///
  /// In en, this message translates to:
  /// **'No breakdown available'**
  String get productivityNoBreakdown;

  /// No description provided for @productivityNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get productivityNoHistory;

  /// No description provided for @productivityHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get productivityHistory;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @commonAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added successfully'**
  String get commonAddedSuccess;

  /// No description provided for @calendarErrorLoadingRoutine.
  ///
  /// In en, this message translates to:
  /// **'Error loading completion dates: {error}'**
  String calendarErrorLoadingRoutine(String error);

  /// No description provided for @calendarBackdateLimit.
  ///
  /// In en, this message translates to:
  /// **'Can only backdate completions within the last 14 days'**
  String get calendarBackdateLimit;

  /// No description provided for @calendarMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{name}\" as completed on {date}?\n\nThis will update your streak accordingly.'**
  String calendarMarkCompleted(String name, String date);

  /// No description provided for @routineCompletionAdded.
  ///
  /// In en, this message translates to:
  /// **'Routine completion added successfully'**
  String get routineCompletionAdded;

  /// No description provided for @routineNotScheduled.
  ///
  /// In en, this message translates to:
  /// **'Routine is not scheduled for this day of the week'**
  String get routineNotScheduled;

  /// No description provided for @goalNotScheduled.
  ///
  /// In en, this message translates to:
  /// **'Goal is not scheduled for this day of the week'**
  String get goalNotScheduled;

  /// No description provided for @routineAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Routine already completed on this date'**
  String get routineAlreadyCompleted;

  /// No description provided for @calendarMarkAsComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as Complete'**
  String get calendarMarkAsComplete;

  /// No description provided for @calendarTitleHistory.
  ///
  /// In en, this message translates to:
  /// **'{name} - History'**
  String calendarTitleHistory(String name);

  /// No description provided for @calendarTapPastDate.
  ///
  /// In en, this message translates to:
  /// **'Tap any past date to mark as complete'**
  String get calendarTapPastDate;

  /// No description provided for @calendarTotalCompletions.
  ///
  /// In en, this message translates to:
  /// **'Total Completions'**
  String get calendarTotalCompletions;

  /// No description provided for @calendarCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get calendarCurrentStreak;

  /// No description provided for @goalCalendarErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading goal history: {error}'**
  String goalCalendarErrorLoading(String error);

  /// No description provided for @goalAddWorkSession.
  ///
  /// In en, this message translates to:
  /// **'Add work session'**
  String get goalAddWorkSession;

  /// No description provided for @goalCompletedCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'This goal is completed and cannot be edited'**
  String get goalCompletedCannotEdit;

  /// No description provided for @goalAddWorkFor.
  ///
  /// In en, this message translates to:
  /// **'Add \"{title}\" work for {date}'**
  String goalAddWorkFor(String title, String date);

  /// No description provided for @goalEnterValidMinutes.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number of minutes'**
  String get goalEnterValidMinutes;

  /// No description provided for @goalTapPastDate.
  ///
  /// In en, this message translates to:
  /// **'Tap any past date to add a work session'**
  String get goalTapPastDate;

  /// No description provided for @goalDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target: {minutes} min'**
  String goalDailyTarget(int minutes);

  /// No description provided for @todoListNoDateSection.
  ///
  /// In en, this message translates to:
  /// **'NO DATE'**
  String get todoListNoDateSection;

  /// No description provided for @todoSectionTomorrow.
  ///
  /// In en, this message translates to:
  /// **'TOMORROW'**
  String get todoSectionTomorrow;

  /// No description provided for @todoSectionDeadline.
  ///
  /// In en, this message translates to:
  /// **'DEADLINE'**
  String get todoSectionDeadline;

  /// No description provided for @todoSectionOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get todoSectionOverdue;

  /// No description provided for @todoSectionCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get todoSectionCompleted;

  /// No description provided for @todoTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo Types'**
  String get todoTypesTitle;

  /// No description provided for @todoTypeTomorrowDesc.
  ///
  /// In en, this message translates to:
  /// **'Tasks you plan to do tomorrow. Moves to overdue if not completed.'**
  String get todoTypeTomorrowDesc;

  /// No description provided for @todoTypeDeadlineDesc.
  ///
  /// In en, this message translates to:
  /// **'Tasks with a specific due date. Enable daily reminders to get notified every day.'**
  String get todoTypeDeadlineDesc;

  /// No description provided for @todoTypeNoDateTitle.
  ///
  /// In en, this message translates to:
  /// **'No Date'**
  String get todoTypeNoDateTitle;

  /// No description provided for @todoTypeNoDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Backlog tasks without a specific timeframe.'**
  String get todoTypeNoDateDesc;

  /// No description provided for @todoAboutTypes.
  ///
  /// In en, this message translates to:
  /// **'About todo types'**
  String get todoAboutTypes;

  /// No description provided for @todoListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Todos Yet'**
  String get todoListEmptyTitle;

  /// No description provided for @todoListEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first todo'**
  String get todoListEmptyDesc;

  /// No description provided for @todoListAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Todo'**
  String get todoListAddButton;

  /// No description provided for @todoListEmptyShort.
  ///
  /// In en, this message translates to:
  /// **'No todos yet\nTap + to create one'**
  String get todoListEmptyShort;

  /// No description provided for @tagsClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get tagsClearSelection;

  /// No description provided for @chatContextTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Context Too Large'**
  String get chatContextTooLarge;

  /// No description provided for @chatUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected Error'**
  String get chatUnexpectedError;

  /// No description provided for @chatContextExceedsLimit.
  ///
  /// In en, this message translates to:
  /// **'Your selected context exceeds the model\'s limit.'**
  String get chatContextExceedsLimit;

  /// No description provided for @chatSplitInfo.
  ///
  /// In en, this message translates to:
  /// **'We can split it into approximately {chunks} chunks and process them sequentially. The AI will receive all context before responding.'**
  String chatSplitInfo(int chunks);

  /// No description provided for @chatChunkingNote.
  ///
  /// In en, this message translates to:
  /// **'Note: This may take longer and cost more.'**
  String get chatChunkingNote;

  /// No description provided for @chatContinueChunking.
  ///
  /// In en, this message translates to:
  /// **'Continue with Chunking'**
  String get chatContinueChunking;

  /// No description provided for @chatAiContext.
  ///
  /// In en, this message translates to:
  /// **'AI Context'**
  String get chatAiContext;

  /// No description provided for @chatAiContextPreview.
  ///
  /// In en, this message translates to:
  /// **'AI Context Preview'**
  String get chatAiContextPreview;

  /// No description provided for @chatApiError.
  ///
  /// In en, this message translates to:
  /// **'API Error: {error}'**
  String chatApiError(String error);

  /// No description provided for @chatRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get chatRequestCancelled;

  /// No description provided for @chatApiKeysSettings.
  ///
  /// In en, this message translates to:
  /// **'API Keys Settings'**
  String get chatApiKeysSettings;

  /// No description provided for @chatAiCoach.
  ///
  /// In en, this message translates to:
  /// **'AI Coach'**
  String get chatAiCoach;

  /// No description provided for @chatUnexpectedErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get chatUnexpectedErrorRetry;

  /// No description provided for @chatErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get chatErrorRetry;

  /// No description provided for @chatChunkedError.
  ///
  /// In en, this message translates to:
  /// **'Error during chunked processing: {error}'**
  String chatChunkedError(String error);

  /// No description provided for @commonCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get commonCalendar;

  /// No description provided for @sessionStopGoal.
  ///
  /// In en, this message translates to:
  /// **'Stop Goal'**
  String get sessionStopGoal;

  /// No description provided for @messageGoToNotes.
  ///
  /// In en, this message translates to:
  /// **'Go to Notes'**
  String get messageGoToNotes;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Write your message here...'**
  String get composerHint;

  /// No description provided for @undoRedoHint.
  ///
  /// In en, this message translates to:
  /// **'Enter some text...'**
  String get undoRedoHint;

  /// No description provided for @productivityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get productivityLow;

  /// No description provided for @productivityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get productivityHigh;

  /// No description provided for @checkinAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get checkinAnalyticsTitle;

  /// No description provided for @checkinMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning Check-in'**
  String get checkinMorning;

  /// No description provided for @checkinEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening Check-in'**
  String get checkinEvening;

  /// No description provided for @checkinMorningShort.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get checkinMorningShort;

  /// No description provided for @checkinEveningShort.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get checkinEveningShort;

  /// No description provided for @checkinNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for selected period'**
  String get checkinNoData;

  /// No description provided for @insightsSaved.
  ///
  /// In en, this message translates to:
  /// **'Insights settings saved'**
  String get insightsSaved;

  /// No description provided for @insightsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable AI Insights'**
  String get insightsEnable;

  /// No description provided for @insightsInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval (minutes)'**
  String get insightsInterval;

  /// No description provided for @insightsContextWindow.
  ///
  /// In en, this message translates to:
  /// **'Context window (days)'**
  String get insightsContextWindow;

  /// No description provided for @insightsTokenLimit.
  ///
  /// In en, this message translates to:
  /// **'Token limit (approx)'**
  String get insightsTokenLimit;

  /// No description provided for @insightsQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get insightsQuietStart;

  /// No description provided for @insightsQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get insightsQuietEnd;

  /// No description provided for @insightsTestNow.
  ///
  /// In en, this message translates to:
  /// **'Test Insight Generation Now'**
  String get insightsTestNow;

  /// No description provided for @insightsFullContextJson.
  ///
  /// In en, this message translates to:
  /// **'Full Context JSON'**
  String get insightsFullContextJson;

  /// No description provided for @insightsSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get insightsSystemPrompt;

  /// No description provided for @insightsUserPrompt.
  ///
  /// In en, this message translates to:
  /// **'User Prompt (JSON)'**
  String get insightsUserPrompt;

  /// No description provided for @insightsNoneSaved.
  ///
  /// In en, this message translates to:
  /// **'No insights saved yet.'**
  String get insightsNoneSaved;

  /// No description provided for @insightsNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get insightsNoItems;

  /// No description provided for @insightsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Insights Settings'**
  String get insightsSettingsTitle;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @insightsGenerating.
  ///
  /// In en, this message translates to:
  /// **'🧪 Generating insight... check logs and notifications'**
  String get insightsGenerating;

  /// No description provided for @insightsTestCompleted.
  ///
  /// In en, this message translates to:
  /// **'✅ Test completed! Check logs for details'**
  String get insightsTestCompleted;

  /// No description provided for @insightsCharCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String insightsCharCount(int count);

  /// No description provided for @insightsNoTopic.
  ///
  /// In en, this message translates to:
  /// **'(no topic)'**
  String get insightsNoTopic;

  /// No description provided for @insightsRequiresInternet.
  ///
  /// In en, this message translates to:
  /// **'Requires internet connection and OpenAI API key to generate insights'**
  String get insightsRequiresInternet;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onbGetStarted;

  /// No description provided for @ob1Title.
  ///
  /// In en, this message translates to:
  /// **'Time is the only\nnon-renewable resource'**
  String get ob1Title;

  /// No description provided for @ob1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop spending it.\nStart investing it.'**
  String get ob1Subtitle;

  /// No description provided for @ob2Title.
  ///
  /// In en, this message translates to:
  /// **'Your Data. Your Device.'**
  String get ob2Title;

  /// No description provided for @ob2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Chrono works 100% offline.\nAll your data stays on your phone —\nprivate and always available.'**
  String get ob2Subtitle;

  /// No description provided for @ob2Footnote.
  ///
  /// In en, this message translates to:
  /// **'AI features may send your data to third-party services.'**
  String get ob2Footnote;

  /// No description provided for @ob3Title.
  ///
  /// In en, this message translates to:
  /// **'Your External Brain'**
  String get ob3Title;

  /// No description provided for @ob3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Writing isn\'t just recording — it\'s thinking.\nMaking notes has never been this easy.'**
  String get ob3Subtitle;

  /// No description provided for @ob4Title.
  ///
  /// In en, this message translates to:
  /// **'Unbreakable Discipline'**
  String get ob4Title;

  /// No description provided for @ob4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Routine is what makes us better every day.\nDaily reset. Persistent notifications.\nNo room for procrastination.'**
  String get ob4Subtitle;

  /// No description provided for @ob5Title.
  ///
  /// In en, this message translates to:
  /// **'Invest Your Time'**
  String get ob5Title;

  /// No description provided for @ob5Subtitle.
  ///
  /// In en, this message translates to:
  /// **'What gets measured, gets managed.\nDaily goals for deep work — see where your time goes\nand what still needs your attention.'**
  String get ob5Subtitle;

  /// No description provided for @ob6Title.
  ///
  /// In en, this message translates to:
  /// **'Your Notes Are\na Knowledge Base'**
  String get ob6Title;

  /// No description provided for @ob6Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Chat with AI for free — bring your own API key.\nFeed your notes as context to get insights\nbuilt on your own data.'**
  String get ob6Subtitle;

  /// No description provided for @ob6Footnote.
  ///
  /// In en, this message translates to:
  /// **'Requires your own API key.'**
  String get ob6Footnote;

  /// No description provided for @ob7Title.
  ///
  /// In en, this message translates to:
  /// **'Your Thinking Space'**
  String get ob7Title;

  /// No description provided for @ob7Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Great ideas need room to develop.\nCollect materials, shape thoughts, analyze —\neach workspace is a dedicated lab for your ideas.'**
  String get ob7Subtitle;

  /// No description provided for @ob8Title.
  ///
  /// In en, this message translates to:
  /// **'Measure Your Growth'**
  String get ob8Title;

  /// No description provided for @ob8Subtitle.
  ///
  /// In en, this message translates to:
  /// **'What you track, you improve.\nDaily score from your routines and goals.\nSpot trends, find patterns, keep rising.'**
  String get ob8Subtitle;

  /// No description provided for @paywallUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock Your\nFull Potential'**
  String get paywallUnlock;

  /// No description provided for @paywallOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get paywallOneTime;

  /// No description provided for @paywallSave.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallSave(int percent);

  /// No description provided for @paywallStartGrowing.
  ///
  /// In en, this message translates to:
  /// **'Start Growing'**
  String get paywallStartGrowing;

  /// No description provided for @paywallSeePlans.
  ///
  /// In en, this message translates to:
  /// **'See Plans'**
  String get paywallSeePlans;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get paywallRestore;

  /// No description provided for @paywallContinueFree.
  ///
  /// In en, this message translates to:
  /// **'Continue Free'**
  String get paywallContinueFree;

  /// No description provided for @planLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get planLifetime;

  /// No description provided for @planGeneric.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planGeneric;

  /// No description provided for @planYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Year} other{{count} Years}}'**
  String planYears(int count);

  /// No description provided for @planMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Month} other{{count} Months}}'**
  String planMonths(int count);

  /// No description provided for @planWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Week} other{{count} Weeks}}'**
  String planWeeks(int count);

  /// No description provided for @pfRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Routine Manager'**
  String get pfRoutineTitle;

  /// No description provided for @pfRoutineSub.
  ///
  /// In en, this message translates to:
  /// **'Build unbreakable daily habits'**
  String get pfRoutineSub;

  /// No description provided for @pfGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal Manager'**
  String get pfGoalTitle;

  /// No description provided for @pfGoalSub.
  ///
  /// In en, this message translates to:
  /// **'Track deep work sessions with timers'**
  String get pfGoalSub;

  /// No description provided for @pfTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo Manager'**
  String get pfTodoTitle;

  /// No description provided for @pfTodoSub.
  ///
  /// In en, this message translates to:
  /// **'Deadlines with daily reminders'**
  String get pfTodoSub;

  /// No description provided for @pfWorkspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get pfWorkspacesTitle;

  /// No description provided for @pfWorkspacesSub.
  ///
  /// In en, this message translates to:
  /// **'Organize ideas into focused labs'**
  String get pfWorkspacesSub;

  /// No description provided for @pfProductivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Productivity Index'**
  String get pfProductivityTitle;

  /// No description provided for @pfProductivitySub.
  ///
  /// In en, this message translates to:
  /// **'Daily score from your progress'**
  String get pfProductivitySub;

  /// No description provided for @pfAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Context'**
  String get pfAiTitle;

  /// No description provided for @pfAiSub.
  ///
  /// In en, this message translates to:
  /// **'Feed your notes to AI for deeper insights'**
  String get pfAiSub;

  /// No description provided for @pfAiNote.
  ///
  /// In en, this message translates to:
  /// **'Requires your own API key'**
  String get pfAiNote;

  /// No description provided for @paywallSubscriptionTerms.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Manage or cancel subscriptions in your App Store account settings.'**
  String get paywallSubscriptionTerms;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
