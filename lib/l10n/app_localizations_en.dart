// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Goal Manager';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonExit => 'Exit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonError => 'Error';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonReset => 'Reset';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMainIntentionUpdated =>
      'Main intention updated successfully';

  @override
  String get settingsBackupRestore => 'Backup & Restore';

  @override
  String get settingsExportBackup => 'Export Backup';

  @override
  String get settingsExportBackupSubtitle => 'Save your data as JSON file';

  @override
  String get settingsImportBackup => 'Import Backup';

  @override
  String get settingsImportBackupSubtitle => 'Restore from a backup file';

  @override
  String get settingsTroubleshooting => 'Troubleshooting';

  @override
  String get settingsResetRoutines => 'Reset Routines';

  @override
  String get settingsResetRoutinesSubtitle =>
      'Mark all as not done, reschedule notifications';

  @override
  String get settingsResetRoutinesMessage =>
      'This will mark all routines as not done and reschedule notifications.\n\nStreak data will be preserved.';

  @override
  String get settingsRoutinesResetSuccess => 'Routines reset successfully';

  @override
  String get settingsResetGoals => 'Reset Goals';

  @override
  String get settingsResetGoalsSubtitle =>
      'Reset completion status and time spent';

  @override
  String get settingsResetGoalsMessage =>
      'This will reset all goal completion status, time spent, and stop active sessions.';

  @override
  String get settingsGoalsResetSuccess => 'Goals reset successfully';

  @override
  String get settingsDeleteAllGoals => 'Delete All Goals';

  @override
  String get settingsDeleteAllGoalsMessage =>
      'Are you sure? All goals will be permanently deleted.\n\nThis cannot be undone.';

  @override
  String get settingsAllGoalsDeleted => 'All goals deleted';

  @override
  String get settingsDeleteAllRoutines => 'Delete All Routines';

  @override
  String get settingsDeleteAllRoutinesMessage =>
      'Are you sure? All routines and their notifications will be permanently deleted.\n\nThis cannot be undone.';

  @override
  String get settingsAllRoutinesDeleted => 'All routines deleted';

  @override
  String get settingsDeleteAllRecords => 'Delete All Records';

  @override
  String get settingsDeleteAllRecordsSubtitle =>
      'Notes, tags, and all associated data';

  @override
  String get settingsDangerZone => 'Danger Zone';

  @override
  String get settingsDangerZoneDescription =>
      'These actions are irreversible. Make sure you have a backup.';

  @override
  String get settingsDeleteDataPermanently => 'Delete data permanently';

  @override
  String get settingsDebug => 'Debug';

  @override
  String get settingsPrintTags => 'Print Tags to Console';

  @override
  String get settingsTagsPrinted =>
      'Tags printed to debug console (flutter run / Logcat)';

  @override
  String get commonSend => 'Send';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonShow => 'Show';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonNew => 'New';

  @override
  String get commonSearch => 'Search';

  @override
  String get navGoals => 'Goals';

  @override
  String get navRoutines => 'Routines';

  @override
  String get navTodo => 'Todo';

  @override
  String get navTags => 'Tags';

  @override
  String get navWorkspace => 'Workspace';

  @override
  String get navAiChat => 'AI Chat';

  @override
  String get backupEmailBody => 'Here is the backup of all notes and tags.';

  @override
  String get backupEmailSubject => 'Backup of Notes';

  @override
  String get homeDeleteRecordTitle => 'Delete record';

  @override
  String get homeDeleteRecordMessage =>
      'Are you sure you want to delete this record?';

  @override
  String get homeChronoTagMissing =>
      'Chrono tag not found. Please restart the app.';

  @override
  String get homeChronoNoteAdded => 'Chrono note added';

  @override
  String homeChronoNoteFailed(String error) {
    return 'Failed to create Chrono note: $error';
  }

  @override
  String get homeChronoInfoTitle => 'Chronological notes';

  @override
  String get homeChronoInfoBody =>
      'The Chrono tag is for timeline notes — quick logs of what happens during your day:\n\n• visited a place\n• something happened\n• currently at a location\n• met someone\n\nUse the quick input to capture moments as they happen.';

  @override
  String get homeChronoQuickHint => 'Quick chrono note...';

  @override
  String get homeSearchHint => 'Search records...';

  @override
  String get homeFilterTooltip => 'Filter records';

  @override
  String get filterTitle => 'Filter Records';

  @override
  String get filterSubtitle => 'Select which types of records to show:';

  @override
  String get filterShowGoals => 'Show records from Goals';

  @override
  String get filterShowGoalsSubtitle =>
      'Include records created from goal sessions';

  @override
  String get filterShowRoutines => 'Show records from Routines';

  @override
  String get filterShowRoutinesSubtitle =>
      'Include records created from completed routines';

  @override
  String get filterShowTodos => 'Show records from Todos';

  @override
  String get filterShowTodosSubtitle =>
      'Include records created from completed todos';

  @override
  String get filterShowProductivity => 'Show Productivity Index';

  @override
  String get filterShowProductivitySubtitle =>
      'Include daily productivity score records';

  @override
  String get noteLocked => 'Note locked';

  @override
  String get noteUnlocked => 'Note unlocked';

  @override
  String get createNewTagTooltip => 'Create new tag';

  @override
  String get noTagsFound => 'No tags found';

  @override
  String get searchTagsHint => 'Search tags...';

  @override
  String get saveNoteFirst => 'Save the note first';

  @override
  String get writeYourNote => 'Write your note';

  @override
  String get cardSpaceButton => 'Space';

  @override
  String get newWorkspaceTitle => 'New workspace';

  @override
  String get workspaceNameHint => 'Name';

  @override
  String get createAndAdd => 'Create & Add';

  @override
  String addedToWorkspace(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String get addToWorkspaceTitle => 'Add to Workspace';

  @override
  String get noWorkspacesYet => 'No workspaces yet';

  @override
  String get tapNewToCreate => 'Tap \"New\" to create one';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonPreview => 'Preview';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get workspaceDeleteTitle => 'Delete workspace?';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '$count note',
      zero: 'No notes',
    );
    return '$_temp0';
  }

  @override
  String get workspacesTitle => 'Workspaces';

  @override
  String get workspaceEmptyTitle => 'No Workspaces Yet';

  @override
  String get workspaceEmptyHint =>
      'Tap + to create your first workspace.\nLink notes, write documents, and use AI to find related content.';

  @override
  String get workspaceCreateButton => 'Create Workspace';

  @override
  String get newWorkspaceTooltip => 'New workspace';

  @override
  String get workspaceChangeColor => 'Change color';

  @override
  String workspaceRemoveMessage(String name) {
    return 'This removes \"$name\" and its note links. Notes themselves are not deleted.';
  }

  @override
  String get editorWriteMarkdownHint => 'Write in Markdown…';

  @override
  String get editorNoLinkedNotes => 'No linked notes yet';

  @override
  String get editorTapAddHint => 'Tap \"Add\" to search or use AI';

  @override
  String get editorLinkedNotesTooltip => 'Linked notes';

  @override
  String get editorAddNotesTooltip => 'Add notes';

  @override
  String get editorChatDocNotes => 'Chat: doc + notes';

  @override
  String get editorChatDocOnly => 'Chat: doc only';

  @override
  String get editorChatIncludeNotes => 'AI Chat will include linked notes';

  @override
  String get editorChatDocumentOnly => 'AI Chat: document only';

  @override
  String get editorLinkedNotesTitle => 'Linked Notes';

  @override
  String get editorShowLess => 'Show less';

  @override
  String get editorShowMore => 'Show more…';

  @override
  String editorNoTagsSelected(int count) {
    return 'No tags selected — AI will scan $count notes.\nPick tags to narrow scope.';
  }

  @override
  String editorAiSearchFailed(String error) {
    return 'AI search failed: $error';
  }

  @override
  String get editorNoteAdded => 'Note added to workspace';

  @override
  String get editorFindNotes => 'Find Notes';

  @override
  String get editorTabSearch => 'Search';

  @override
  String get editorTabAiFind => 'AI Find';

  @override
  String get editorSearchNotesHint => 'Search notes…';

  @override
  String get editorNoNotesFound => 'No notes found';

  @override
  String get editorAllLinked => 'All matching notes already linked';

  @override
  String get editorDescribeLooking => 'Describe what you\'re looking for';

  @override
  String get editorAiPromptHint => 'e.g. Notes about productivity techniques';

  @override
  String get editorSearching => 'Searching…';

  @override
  String get editorFindWithAi => 'Find with AI';

  @override
  String get editorEnterPromptHint => 'Enter a prompt and tap Find';

  @override
  String get editorAllFoundLinked => 'All found notes already linked';

  @override
  String get editorLargeSearchTitle => 'Large search';

  @override
  String get commonContinue => 'Continue';

  @override
  String get editorRenameWorkspace => 'Rename workspace';

  @override
  String get editorWorkspaceColor => 'Workspace color';

  @override
  String get editorWorkspaceNotFound => 'Workspace not found';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonActions => 'Actions';

  @override
  String get tagEditTooltip => 'Edit tag';

  @override
  String get goalImportance => 'Importance';

  @override
  String get insightsOutsideContext => 'Outside context window';

  @override
  String errorCouldNotLaunch(String uri) {
    return 'Could not launch $uri';
  }

  @override
  String get drawerPremium => 'Chrono Premium';

  @override
  String get drawerPremiumTry => 'Try Premium';

  @override
  String get drawerPremiumActive => 'Active';

  @override
  String get drawerPremiumTrial => '3 days free';

  @override
  String get drawerSectionAiPrompts => 'AI & PROMPTS';

  @override
  String get drawerPrompts => 'Prompts';

  @override
  String get drawerGptSettings => 'GPT Settings';

  @override
  String get drawerSectionGeneral => 'GENERAL';

  @override
  String get drawerShowIntro => 'Show Intro';

  @override
  String get drawerPrivacyPolicy => 'Privacy Policy';

  @override
  String get drawerTermsOfUse => 'Terms of Use (EULA)';

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String get confirmDeleteAllMessage =>
      'Are you sure you want to delete all notes? This action cannot be undone.';

  @override
  String get allNotesDeleted => 'All notes have been deleted successfully.';

  @override
  String failedToDeleteNotes(String error) {
    return 'Failed to delete notes: $error';
  }

  @override
  String get apiAccessSettings => 'API Access Settings';

  @override
  String get selectModel => 'Select Model';

  @override
  String tokenLimit(String tpm) {
    return 'Token limit: $tpm';
  }

  @override
  String get openAiApiKey => 'OpenAI API Key';

  @override
  String get geminiApiKey => 'Gemini API Key';

  @override
  String get getOpenAiKey => 'Get OpenAI Key';

  @override
  String get getGeminiKey => 'Get Gemini Key';

  @override
  String apiResponseDelay(String delay) {
    return 'Response delay: $delay';
  }

  @override
  String get exportTitle => 'Export Backup';

  @override
  String get exportSelectData => 'Select data to include in your backup';

  @override
  String get exportSelectAtLeastOne => 'Please select at least one data type.';

  @override
  String get exportExporting => 'Exporting data...';

  @override
  String get exportReady => 'Backup ready! Choose how to save it.';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportSharedSuccess => 'Backup shared successfully!';

  @override
  String exportShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get exportEmailOpened => 'Email composer opened!';

  @override
  String get exportNoEmailApp =>
      'No email app found. Please use \'Share\' instead.';

  @override
  String exportEmailFailed(String error) {
    return 'Email failed: $error';
  }

  @override
  String get exportLabelNotes => 'Notes & Tags';

  @override
  String get exportLabelTodos => 'Todos';

  @override
  String get exportLabelInstructions => 'AI Instructions';

  @override
  String get exportCreateBackup => 'Create Backup';

  @override
  String get exportEmailButton => 'Email';

  @override
  String get exportShareButton => 'Share';

  @override
  String get exportBackupSubject => 'Chrono Data Backup';

  @override
  String exportBackupBody(String types) {
    return 'Here is the backup of your Chrono data including: $types.';
  }

  @override
  String get importTitle => 'Import Data';

  @override
  String get importPressButton => 'Press the button to import data.';

  @override
  String get importNoFileSelected => 'No file selected.';

  @override
  String get importReplaceTitle => 'Replace All Data?';

  @override
  String get importReplaceMessage =>
      'Import will DELETE all current data and replace it with backup.';

  @override
  String get importCurrentToDelete => 'Current data to be deleted:';

  @override
  String get importLabelNotes => 'Notes';

  @override
  String importTotalToDelete(int count) {
    return 'Total: $count items will be deleted';
  }

  @override
  String get importBackupWarning =>
      '⚠️ Make sure you have a backup before proceeding!';

  @override
  String get importDeleteAndImport => 'Delete & Import';

  @override
  String get importCancelled => 'Import cancelled.';

  @override
  String get importDeleting => 'Deleting current data...';

  @override
  String get importImporting => 'Importing...';

  @override
  String get importImportingRoutines => 'Importing routines...';

  @override
  String get importImportingGoals => 'Importing goals...';

  @override
  String get importImportingTodos => 'Importing todos...';

  @override
  String get importImportingReminders => 'Importing todo reminders...';

  @override
  String get importImportingInstructions => 'Importing instructions...';

  @override
  String get importImportingNotes => 'Importing notes and tags...';

  @override
  String get importImportingWorkspaces => 'Importing workspaces...';

  @override
  String importSuccessCount(int count) {
    return 'Import successful! Imported $count items.';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importSelectFile => 'Select File & Import';

  @override
  String get importWarningLong =>
      'Select a JSON backup file to import.\n\n⚠️ WARNING: Import will DELETE all current data and replace it with the backup.\n\nYou will see a confirmation screen before deletion.';

  @override
  String get promptsTitle => 'Prompts';

  @override
  String get promptsNewTitle => 'New Prompt';

  @override
  String get promptsEditTitle => 'Edit Prompt';

  @override
  String get promptsEnterText => 'Enter prompt text...';

  @override
  String get promptsOnTapBehavior => 'ON TAP BEHAVIOR';

  @override
  String get promptsCreate => 'Create Prompt';

  @override
  String get promptsSaveChanges => 'Save Changes';

  @override
  String get promptsDeleteTitle => 'Delete Prompt?';

  @override
  String promptsDeleteMessage(String text) {
    return 'Are you sure you want to delete \"$text\"?';
  }

  @override
  String get promptsSendInstantly => 'Send instantly';

  @override
  String get promptsSendInstantlyDesc => 'Sends the prompt immediately';

  @override
  String get promptsInsertToInput => 'Insert to input';

  @override
  String get promptsInsertToInputDesc => 'Pastes text for editing';

  @override
  String get promptsEmptyTitle => 'No Prompts Yet';

  @override
  String get promptsEmptyDesc =>
      'Create quick prompts to speed up your AI conversations. Tap + to get started.';

  @override
  String get promptsSendsInstantly => 'Sends instantly';

  @override
  String get promptsInsertsToInput => 'Inserts to input';

  @override
  String goalsErrorLoading(String error) {
    return 'Error loading goals: $error';
  }

  @override
  String goalDeletedSuccess(String title) {
    return 'Goal \"$title\" deleted successfully';
  }

  @override
  String goalErrorDeleting(String error) {
    return 'Error deleting goal: $error';
  }

  @override
  String goalErrorSaving(String error) {
    return 'Error saving goal: $error';
  }

  @override
  String get goalsHideCompleted => 'Hide completed goals';

  @override
  String get goalsShowCompleted => 'Show completed goals';

  @override
  String get goalCompleted => 'Completed';

  @override
  String get goalsEmptyTitle => 'No Goals Yet';

  @override
  String get goalsEmptyDesc =>
      'Create your first goal to start tracking your progress and building better habits.';

  @override
  String get goalsCreateFirst => 'Create Your First Goal';

  @override
  String get goalEditTitle => 'Edit Goal';

  @override
  String get goalNewTitle => 'New Goal';

  @override
  String get goalTitleLabel => 'Goal Title';

  @override
  String get goalTitleRequired => 'Please enter a goal title';

  @override
  String get goalHours => 'Hours';

  @override
  String get goalMinutes => 'Minutes';

  @override
  String get goalSessionDuration => 'Session Duration (minutes)';

  @override
  String get goalUpdate => 'Update Goal';

  @override
  String get goalCreate => 'Create Goal';

  @override
  String get goalSpecifyTime => 'Please specify at least some hours or minutes';

  @override
  String get goalTimeTarget => 'Time Target';

  @override
  String get goalSessionDurationHelper =>
      'How long each work session should be';

  @override
  String get validatorInvalid => 'Invalid';

  @override
  String get validatorRequired => 'Required';

  @override
  String get goalMinutesRange => '0-59';

  @override
  String get goalCannotDeleteActive =>
      'Cannot delete an active goal. Stop the session first.';

  @override
  String goalTimeSpent(String time) {
    return 'Time spent: $time';
  }

  @override
  String goalRunning(String time) {
    return 'Running: $time';
  }

  @override
  String get goalComplete => 'Complete';

  @override
  String get goalUncomplete => 'Uncomplete';

  @override
  String get goalDeleteTitle => 'Delete Goal';

  @override
  String goalDeleteMessage(String title) {
    return 'Are you sure you want to delete \"$title\"?\n\nThis action cannot be undone.';
  }

  @override
  String routineArchived(int count) {
    return 'Archived ($count)';
  }

  @override
  String get routineViewHistory => 'View completion history';

  @override
  String get routineDeleteTitle => 'Delete Routine';

  @override
  String routineDeleteMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get routinesEmptyTitle => 'No Routines Yet';

  @override
  String get routinesEmptyDesc =>
      'Create your first routine to build consistent daily habits and stay organized.';

  @override
  String get routinesCreateFirst => 'Create Your First Routine';

  @override
  String get routineSelectDay => 'Please select at least one day';

  @override
  String get routineEditTitle => 'Edit Routine';

  @override
  String get routineNewTitle => 'New Routine';

  @override
  String get routineNameLabel => 'Routine Name';

  @override
  String get routineNameRequired => 'Please enter a name';

  @override
  String get routineDaysOfWeek => 'Days of Week';

  @override
  String get routineRemindersPersistence => 'Reminders & Persistence';

  @override
  String get routineSchedule => 'Schedule';

  @override
  String get routineTime => 'Time';

  @override
  String get routineHideOtherDays => 'Hide other days';

  @override
  String get routineShowOtherDays => 'Show other days';

  @override
  String get routineOtherDays => 'Other days';

  @override
  String get routineDuration => 'Duration';

  @override
  String get routineInterval => 'Interval';

  @override
  String get routineAdditional => 'Additional';

  @override
  String get routineTrackStreak => 'Track streak';

  @override
  String get routineTrackStreakDesc =>
      'Display streak count when completing this routine';

  @override
  String routineErrorCreating(String error) {
    return 'Error creating routine record: $error';
  }

  @override
  String get commonMin => 'min';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get todoSelectDeadline => 'Please select a deadline date';

  @override
  String todoErrorSaving(String error) {
    return 'Error saving todo: $error';
  }

  @override
  String get todoEditTitle => 'Edit Todo';

  @override
  String get todoNewTitle => 'New Todo';

  @override
  String get todoTitleLabel => 'Title';

  @override
  String get todoTitleRequired => 'Please enter a title';

  @override
  String get todoNoDate => 'No date';

  @override
  String get todoSelectDeadlineDate => 'Select a deadline date';

  @override
  String get todoRemindTomorrow => 'Remind me tomorrow';

  @override
  String get todoRemindDaily => 'Remind me every day';

  @override
  String todoAtTime(String time) {
    return 'At $time';
  }

  @override
  String get todoUpdate => 'Update Todo';

  @override
  String get todoCreate => 'Create Todo';

  @override
  String get todoType => 'Type';

  @override
  String get todoTypeTomorrow => 'Tomorrow';

  @override
  String get todoTypeDeadline => 'Deadline';

  @override
  String get todoDeadlineDate => 'Deadline Date';

  @override
  String get todoPickDate => 'Pick date';

  @override
  String get todoNotification => 'Notification';

  @override
  String get todoRepeatNotifications => 'Repeat notifications';

  @override
  String get todoPeriodLabel => 'Period: ';

  @override
  String get todoEveryLabel => 'Every: ';

  @override
  String get commonChange => 'Change';

  @override
  String get todoNotifyOnDay => 'Get a notification on the day';

  @override
  String get todoNotifyDaily =>
      'Get a notification every day until the deadline';

  @override
  String todoNotificationPreview(int count, String period, String interval) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '$count notification',
    );
    return '$_temp0: starting $period before, every $interval';
  }

  @override
  String tagErrorSaving(String error) {
    return 'Error saving tag: $error';
  }

  @override
  String get tagSystemCannotDelete => 'System tags cannot be deleted';

  @override
  String get tagDeleteTitle => 'Tag deletion';

  @override
  String get tagDeleteMessage => 'Are you sure you want to delete this tag?';

  @override
  String get tagEditTitle => 'Edit Tag';

  @override
  String get tagCreateTitle => 'Create Tag';

  @override
  String get tagNameLabel => 'Tag Name';

  @override
  String get tagSystemNameCannotChange => 'System tag name cannot be changed';

  @override
  String get tagEnterName => 'Enter tag name';

  @override
  String get tagNameRequired => 'Please enter a tag name';

  @override
  String get tagColorLabel => 'Tag Color';

  @override
  String get productivityWeek => 'Week';

  @override
  String get productivityMonth => 'Month';

  @override
  String get productivityAllTime => 'All time';

  @override
  String get productivityNoActiveToday => 'No active routines or goals today';

  @override
  String get productivityCurrentStreak => 'current streak';

  @override
  String get productivityBestStreak => 'best streak';

  @override
  String get productivityRoutinesCompleted => 'Routines completed';

  @override
  String get productivityGoalProgress => 'Goal progress';

  @override
  String productivityDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get productivityNoData => 'No data for this period yet';

  @override
  String get productivityNoBreakdown => 'No breakdown available';

  @override
  String get productivityNoHistory => 'No history yet';

  @override
  String get productivityHistory => 'History';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonNoData => 'No data';

  @override
  String get commonAddedSuccess => 'Added successfully';

  @override
  String calendarErrorLoadingRoutine(String error) {
    return 'Error loading completion dates: $error';
  }

  @override
  String get calendarBackdateLimit =>
      'Can only backdate completions within the last 14 days';

  @override
  String calendarMarkCompleted(String name, String date) {
    return 'Mark \"$name\" as completed on $date?\n\nThis will update your streak accordingly.';
  }

  @override
  String get routineCompletionAdded => 'Routine completion added successfully';

  @override
  String get routineNotScheduled =>
      'Routine is not scheduled for this day of the week';

  @override
  String get goalNotScheduled =>
      'Goal is not scheduled for this day of the week';

  @override
  String get routineAlreadyCompleted =>
      'Routine already completed on this date';

  @override
  String get calendarMarkAsComplete => 'Mark as Complete';

  @override
  String calendarTitleHistory(String name) {
    return '$name - History';
  }

  @override
  String get calendarTapPastDate => 'Tap any past date to mark as complete';

  @override
  String get calendarTotalCompletions => 'Total Completions';

  @override
  String get calendarCurrentStreak => 'Current Streak';

  @override
  String goalCalendarErrorLoading(String error) {
    return 'Error loading goal history: $error';
  }

  @override
  String get goalAddWorkSession => 'Add work session';

  @override
  String get goalCompletedCannotEdit =>
      'This goal is completed and cannot be edited';

  @override
  String goalAddWorkFor(String title, String date) {
    return 'Add \"$title\" work for $date';
  }

  @override
  String get goalEnterValidMinutes => 'Please enter a valid number of minutes';

  @override
  String get goalTapPastDate => 'Tap any past date to add a work session';

  @override
  String goalDailyTarget(int minutes) {
    return 'Daily target: $minutes min';
  }

  @override
  String get goalRecordEditTitle => 'Edit Goal Session';

  @override
  String get goalRecordTimeSpentLabel => 'Time spent (minutes)';

  @override
  String get goalRecordTodayReadonly =>
      'Today\'s time is managed by the timer and can\'t be edited here.';

  @override
  String get goalRecordIndexUpdated => 'Productivity index updated';

  @override
  String get goalRecordStatusCompleted => 'Completed';

  @override
  String get goalRecordStatusDayEnded => 'Day ended';

  @override
  String get todoListNoDateSection => 'NO DATE';

  @override
  String get todoSectionTomorrow => 'TOMORROW';

  @override
  String get todoSectionDeadline => 'DEADLINE';

  @override
  String get todoSectionOverdue => 'OVERDUE';

  @override
  String get todoSectionCompleted => 'COMPLETED';

  @override
  String get todoTypesTitle => 'Todo Types';

  @override
  String get todoTypeTomorrowDesc =>
      'Tasks you plan to do tomorrow. Moves to overdue if not completed.';

  @override
  String get todoTypeDeadlineDesc =>
      'Tasks with a specific due date. Enable daily reminders to get notified every day.';

  @override
  String get todoTypeNoDateTitle => 'No Date';

  @override
  String get todoTypeNoDateDesc =>
      'Backlog tasks without a specific timeframe.';

  @override
  String get todoAboutTypes => 'About todo types';

  @override
  String get todoListEmptyTitle => 'No Todos Yet';

  @override
  String get todoListEmptyDesc => 'Tap + to create your first todo';

  @override
  String get todoListAddButton => 'Add Todo';

  @override
  String get todoListEmptyShort => 'No todos yet\nTap + to create one';

  @override
  String get tagsClearSelection => 'Clear selection';

  @override
  String get chatContextTooLarge => 'Context Too Large';

  @override
  String get chatUnexpectedError => 'Unexpected Error';

  @override
  String get chatContextExceedsLimit =>
      'Your selected context exceeds the model\'s limit.';

  @override
  String chatSplitInfo(int chunks) {
    return 'We can split it into approximately $chunks chunks and process them sequentially. The AI will receive all context before responding.';
  }

  @override
  String get chatChunkingNote => 'Note: This may take longer and cost more.';

  @override
  String get chatContinueChunking => 'Continue with Chunking';

  @override
  String get chatAiContext => 'AI Context';

  @override
  String get chatAiContextPreview => 'AI Context Preview';

  @override
  String chatApiError(String error) {
    return 'API Error: $error';
  }

  @override
  String get chatRequestCancelled => 'Request cancelled.';

  @override
  String get chatApiKeysSettings => 'API Keys Settings';

  @override
  String get chatAiCoach => 'AI Coach';

  @override
  String get chatUnexpectedErrorRetry =>
      'An unexpected error occurred. Please try again.';

  @override
  String get chatErrorRetry => 'An error occurred. Please try again.';

  @override
  String chatChunkedError(String error) {
    return 'Error during chunked processing: $error';
  }

  @override
  String get commonCalendar => 'Calendar';

  @override
  String get sessionStopGoal => 'Stop Goal';

  @override
  String get messageGoToNotes => 'Go to Notes';

  @override
  String get composerHint => 'Write your message here...';

  @override
  String get undoRedoHint => 'Enter some text...';

  @override
  String get productivityLow => 'Low';

  @override
  String get productivityHigh => 'High';

  @override
  String get checkinAnalyticsTitle => 'Analytics';

  @override
  String get checkinMorning => 'Morning Check-in';

  @override
  String get checkinEvening => 'Evening Check-in';

  @override
  String get checkinMorningShort => 'Morning';

  @override
  String get checkinEveningShort => 'Evening';

  @override
  String get checkinNoData => 'No data for selected period';

  @override
  String get insightsSaved => 'Insights settings saved';

  @override
  String get insightsEnable => 'Enable AI Insights';

  @override
  String get insightsInterval => 'Interval (minutes)';

  @override
  String get insightsContextWindow => 'Context window (days)';

  @override
  String get insightsTokenLimit => 'Token limit (approx)';

  @override
  String get insightsQuietStart => 'Quiet hours start';

  @override
  String get insightsQuietEnd => 'Quiet hours end';

  @override
  String get insightsTestNow => 'Test Insight Generation Now';

  @override
  String get insightsFullContextJson => 'Full Context JSON';

  @override
  String get insightsSystemPrompt => 'System Prompt';

  @override
  String get insightsUserPrompt => 'User Prompt (JSON)';

  @override
  String get insightsNoneSaved => 'No insights saved yet.';

  @override
  String get insightsNoItems => 'No items';

  @override
  String get insightsSettingsTitle => 'AI Insights Settings';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get insightsGenerating =>
      '🧪 Generating insight... check logs and notifications';

  @override
  String get insightsTestCompleted =>
      '✅ Test completed! Check logs for details';

  @override
  String insightsCharCount(int count) {
    return '$count characters';
  }

  @override
  String get insightsNoTopic => '(no topic)';

  @override
  String get insightsRequiresInternet =>
      'Requires internet connection and OpenAI API key to generate insights';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbGetStarted => 'Get Started';

  @override
  String get ob1Title => 'Time is the only\nnon-renewable resource';

  @override
  String get ob1Subtitle => 'Stop spending it.\nStart investing it.';

  @override
  String get ob2Title => 'Your Data. Your Device.';

  @override
  String get ob2Subtitle =>
      'Chrono works 100% offline.\nAll your data stays on your phone —\nprivate and always available.';

  @override
  String get ob2Footnote =>
      'AI features may send your data to third-party services.';

  @override
  String get ob3Title => 'Your External Brain';

  @override
  String get ob3Subtitle =>
      'Writing isn\'t just recording — it\'s thinking.\nMaking notes has never been this easy.';

  @override
  String get ob4Title => 'Unbreakable Discipline';

  @override
  String get ob4Subtitle =>
      'Routine is what makes us better every day.\nDaily reset. Persistent notifications.\nNo room for procrastination.';

  @override
  String get ob5Title => 'Invest Your Time';

  @override
  String get ob5Subtitle =>
      'What gets measured, gets managed.\nDaily goals for deep work — see where your time goes\nand what still needs your attention.';

  @override
  String get ob6Title => 'Your Notes Are\na Knowledge Base';

  @override
  String get ob6Subtitle =>
      'Chat with AI for free — bring your own API key.\nFeed your notes as context to get insights\nbuilt on your own data.';

  @override
  String get ob6Footnote => 'Requires your own API key.';

  @override
  String get ob7Title => 'Your Thinking Space';

  @override
  String get ob7Subtitle =>
      'Great ideas need room to develop.\nCollect materials, shape thoughts, analyze —\neach workspace is a dedicated lab for your ideas.';

  @override
  String get ob8Title => 'Measure Your Growth';

  @override
  String get ob8Subtitle =>
      'What you track, you improve.\nDaily score from your routines and goals.\nSpot trends, find patterns, keep rising.';

  @override
  String get paywallUnlock => 'Unlock Your\nFull Potential';

  @override
  String get paywallOneTime => 'One-time purchase';

  @override
  String paywallSave(int percent) {
    return 'Save $percent%';
  }

  @override
  String get paywallStartGrowing => 'Start Growing';

  @override
  String get paywallSeePlans => 'See Plans';

  @override
  String get paywallRestore => 'Restore Purchases';

  @override
  String get paywallContinueFree => 'Continue Free';

  @override
  String get planLifetime => 'Lifetime';

  @override
  String get planGeneric => 'Plan';

  @override
  String planYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Years',
      one: '1 Year',
    );
    return '$_temp0';
  }

  @override
  String planMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Months',
      one: '1 Month',
    );
    return '$_temp0';
  }

  @override
  String planWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Weeks',
      one: '1 Week',
    );
    return '$_temp0';
  }

  @override
  String get pfRoutineTitle => 'Routine Manager';

  @override
  String get pfRoutineSub => 'Build unbreakable daily habits';

  @override
  String get pfGoalTitle => 'Goal Manager';

  @override
  String get pfGoalSub => 'Track deep work sessions with timers';

  @override
  String get pfTodoTitle => 'Todo Manager';

  @override
  String get pfTodoSub => 'Deadlines with daily reminders';

  @override
  String get pfWorkspacesTitle => 'Workspaces';

  @override
  String get pfWorkspacesSub => 'Organize ideas into focused labs';

  @override
  String get pfProductivityTitle => 'Productivity Index';

  @override
  String get pfProductivitySub => 'Daily score from your progress';

  @override
  String get pfAiTitle => 'AI Context';

  @override
  String get pfAiSub => 'Feed your notes to AI for deeper insights';

  @override
  String get pfAiNote => 'Requires your own API key';

  @override
  String get paywallSubscriptionTerms =>
      'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Manage or cancel subscriptions in your App Store account settings.';
}
