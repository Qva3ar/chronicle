// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Менеджер целей';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonExit => 'Выход';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonYes => 'Да';

  @override
  String get commonNo => 'Нет';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonError => 'Ошибка';

  @override
  String get commonSettings => 'Настройки';

  @override
  String get commonReset => 'Сбросить';

  @override
  String errorWithMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsMainIntentionUpdated => 'Главная цель успешно обновлена';

  @override
  String get settingsBackupRestore => 'Резервное копирование';

  @override
  String get settingsExportBackup => 'Экспорт резервной копии';

  @override
  String get settingsExportBackupSubtitle => 'Сохранить данные в файл JSON';

  @override
  String get settingsImportBackup => 'Импорт резервной копии';

  @override
  String get settingsImportBackupSubtitle =>
      'Восстановить из файла резервной копии';

  @override
  String get settingsTroubleshooting => 'Устранение неполадок';

  @override
  String get settingsResetRoutines => 'Сбросить рутины';

  @override
  String get settingsResetRoutinesSubtitle =>
      'Отметить все как невыполненные, перепланировать уведомления';

  @override
  String get settingsResetRoutinesMessage =>
      'Все рутины будут отмечены как невыполненные, а уведомления перепланированы.\n\nДанные о сериях сохранятся.';

  @override
  String get settingsRoutinesResetSuccess => 'Рутины успешно сброшены';

  @override
  String get settingsResetGoals => 'Сбросить цели';

  @override
  String get settingsResetGoalsSubtitle =>
      'Сбросить статус выполнения и затраченное время';

  @override
  String get settingsResetGoalsMessage =>
      'Это сбросит статус выполнения всех целей, затраченное время и остановит активные сессии.';

  @override
  String get settingsGoalsResetSuccess => 'Цели успешно сброшены';

  @override
  String get settingsDeleteAllGoals => 'Удалить все цели';

  @override
  String get settingsDeleteAllGoalsMessage =>
      'Вы уверены? Все цели будут удалены безвозвратно.\n\nЭто действие нельзя отменить.';

  @override
  String get settingsAllGoalsDeleted => 'Все цели удалены';

  @override
  String get settingsDeleteAllRoutines => 'Удалить все рутины';

  @override
  String get settingsDeleteAllRoutinesMessage =>
      'Вы уверены? Все рутины и их уведомления будут удалены безвозвратно.\n\nЭто действие нельзя отменить.';

  @override
  String get settingsAllRoutinesDeleted => 'Все рутины удалены';

  @override
  String get settingsDeleteAllRecords => 'Удалить все записи';

  @override
  String get settingsDeleteAllRecordsSubtitle =>
      'Заметки, теги и все связанные данные';

  @override
  String get settingsDangerZone => 'Опасная зона';

  @override
  String get settingsDangerZoneDescription =>
      'Эти действия необратимы. Убедитесь, что у вас есть резервная копия.';

  @override
  String get settingsDeleteDataPermanently => 'Безвозвратно удалить данные';

  @override
  String get settingsDebug => 'Отладка';

  @override
  String get settingsPrintTags => 'Вывести теги в консоль';

  @override
  String get settingsTagsPrinted =>
      'Теги выведены в консоль отладки (flutter run / Logcat)';

  @override
  String get commonSend => 'Отправить';

  @override
  String get commonApply => 'Применить';

  @override
  String get commonShow => 'Показать';

  @override
  String get commonGotIt => 'Понятно';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonNew => 'Новый';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get navGoals => 'Цели';

  @override
  String get navRoutines => 'Рутины';

  @override
  String get navTodo => 'Задачи';

  @override
  String get navTags => 'Теги';

  @override
  String get navWorkspace => 'Пространства';

  @override
  String get navAiChat => 'AI-чат';

  @override
  String get backupEmailBody => 'Вот резервная копия всех заметок и тегов.';

  @override
  String get backupEmailSubject => 'Резервная копия заметок';

  @override
  String get homeDeleteRecordTitle => 'Удалить запись';

  @override
  String get homeDeleteRecordMessage =>
      'Вы уверены, что хотите удалить эту запись?';

  @override
  String get homeChronoTagMissing =>
      'Тег Chrono не найден. Перезапустите приложение.';

  @override
  String get homeChronoNoteAdded => 'Заметка Chrono добавлена';

  @override
  String homeChronoNoteFailed(String error) {
    return 'Не удалось создать заметку Chrono: $error';
  }

  @override
  String get homeChronoInfoTitle => 'Хронологические заметки';

  @override
  String get homeChronoInfoBody =>
      'Тег Chrono — для заметок на временной шкале, быстрых записей о том, что происходит в течение дня:\n\n• посетили место\n• что-то произошло\n• сейчас находитесь где-то\n• встретили кого-то\n\nИспользуйте быстрый ввод, чтобы фиксировать моменты по мере их появления.';

  @override
  String get homeChronoQuickHint => 'Быстрая заметка chrono...';

  @override
  String get homeSearchHint => 'Поиск записей...';

  @override
  String get homeFilterTooltip => 'Фильтр записей';

  @override
  String get filterTitle => 'Фильтр записей';

  @override
  String get filterSubtitle => 'Выберите, какие типы записей показывать:';

  @override
  String get filterShowGoals => 'Показывать записи из целей';

  @override
  String get filterShowGoalsSubtitle =>
      'Включать записи, созданные из сессий целей';

  @override
  String get filterShowRoutines => 'Показывать записи из рутин';

  @override
  String get filterShowRoutinesSubtitle =>
      'Включать записи, созданные из выполненных рутин';

  @override
  String get filterShowTodos => 'Показывать записи из задач';

  @override
  String get filterShowTodosSubtitle =>
      'Включать записи, созданные из выполненных задач';

  @override
  String get filterShowProductivity => 'Показывать индекс продуктивности';

  @override
  String get filterShowProductivitySubtitle =>
      'Включать записи ежедневного индекса продуктивности';

  @override
  String get noteLocked => 'Заметка заблокирована';

  @override
  String get noteUnlocked => 'Заметка разблокирована';

  @override
  String get createNewTagTooltip => 'Создать тег';

  @override
  String get noTagsFound => 'Теги не найдены';

  @override
  String get searchTagsHint => 'Поиск тегов...';

  @override
  String get saveNoteFirst => 'Сначала сохраните заметку';

  @override
  String get writeYourNote => 'Напишите заметку';

  @override
  String get cardSpaceButton => 'Пространство';

  @override
  String get newWorkspaceTitle => 'Новое пространство';

  @override
  String get workspaceNameHint => 'Название';

  @override
  String get createAndAdd => 'Создать и добавить';

  @override
  String addedToWorkspace(String name) {
    return 'Добавлено в «$name»';
  }

  @override
  String get addToWorkspaceTitle => 'Добавить в пространство';

  @override
  String get noWorkspacesYet => 'Пока нет пространств';

  @override
  String get tapNewToCreate => 'Нажмите «Новый», чтобы создать';

  @override
  String get commonRename => 'Переименовать';

  @override
  String get commonFilter => 'Фильтр';

  @override
  String get commonPreview => 'Просмотр';

  @override
  String get timeJustNow => 'Только что';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes мин назад';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours ч назад';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days дн назад';
  }

  @override
  String get workspaceDeleteTitle => 'Удалить пространство?';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заметки',
      many: '$count заметок',
      few: '$count заметки',
      one: '$count заметка',
      zero: 'Нет заметок',
    );
    return '$_temp0';
  }

  @override
  String get workspacesTitle => 'Пространства';

  @override
  String get workspaceEmptyTitle => 'Пока нет пространств';

  @override
  String get workspaceEmptyHint =>
      'Нажмите +, чтобы создать первое пространство.\nСвязывайте заметки, пишите документы и используйте ИИ для поиска связанного контента.';

  @override
  String get workspaceCreateButton => 'Создать пространство';

  @override
  String get newWorkspaceTooltip => 'Новое пространство';

  @override
  String get workspaceChangeColor => 'Изменить цвет';

  @override
  String workspaceRemoveMessage(String name) {
    return 'Это удалит «$name» и его связи с заметками. Сами заметки не удаляются.';
  }

  @override
  String get editorWriteMarkdownHint => 'Пишите в Markdown…';

  @override
  String get editorNoLinkedNotes => 'Пока нет связанных заметок';

  @override
  String get editorTapAddHint =>
      'Нажмите «Добавить» для поиска или используйте ИИ';

  @override
  String get editorLinkedNotesTooltip => 'Связанные заметки';

  @override
  String get editorAddNotesTooltip => 'Добавить заметки';

  @override
  String get editorChatDocNotes => 'Чат: документ + заметки';

  @override
  String get editorChatDocOnly => 'Чат: только документ';

  @override
  String get editorChatIncludeNotes =>
      'AI-чат будет учитывать связанные заметки';

  @override
  String get editorChatDocumentOnly => 'AI-чат: только документ';

  @override
  String get editorLinkedNotesTitle => 'Связанные заметки';

  @override
  String get editorShowLess => 'Свернуть';

  @override
  String get editorShowMore => 'Показать ещё…';

  @override
  String editorNoTagsSelected(int count) {
    return 'Теги не выбраны — ИИ просмотрит $count заметок.\nВыберите теги, чтобы сузить область.';
  }

  @override
  String editorAiSearchFailed(String error) {
    return 'Ошибка ИИ-поиска: $error';
  }

  @override
  String get editorNoteAdded => 'Заметка добавлена в пространство';

  @override
  String get editorFindNotes => 'Найти заметки';

  @override
  String get editorTabSearch => 'Поиск';

  @override
  String get editorTabAiFind => 'ИИ-поиск';

  @override
  String get editorSearchNotesHint => 'Поиск заметок…';

  @override
  String get editorNoNotesFound => 'Заметки не найдены';

  @override
  String get editorAllLinked => 'Все подходящие заметки уже связаны';

  @override
  String get editorDescribeLooking => 'Опишите, что вы ищете';

  @override
  String get editorAiPromptHint => 'напр. Заметки о техниках продуктивности';

  @override
  String get editorSearching => 'Поиск…';

  @override
  String get editorFindWithAi => 'Найти с помощью ИИ';

  @override
  String get editorEnterPromptHint => 'Введите запрос и нажмите «Найти»';

  @override
  String get editorAllFoundLinked => 'Все найденные заметки уже связаны';

  @override
  String get editorLargeSearchTitle => 'Большой поиск';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get editorRenameWorkspace => 'Переименовать пространство';

  @override
  String get editorWorkspaceColor => 'Цвет пространства';

  @override
  String get editorWorkspaceNotFound => 'Пространство не найдено';

  @override
  String get commonSubmit => 'Отправить';

  @override
  String get commonUpdate => 'Обновить';

  @override
  String get commonActions => 'Действия';

  @override
  String get tagEditTooltip => 'Изменить тег';

  @override
  String get goalImportance => 'Важность';

  @override
  String get insightsOutsideContext => 'Вне окна контекста';

  @override
  String errorCouldNotLaunch(String uri) {
    return 'Не удалось открыть $uri';
  }

  @override
  String get drawerPremium => 'Chrono Premium';

  @override
  String get drawerPremiumTry => 'Попробовать Premium';

  @override
  String get drawerPremiumActive => 'Активна';

  @override
  String get drawerPremiumTrial => '3 дня бесплатно';

  @override
  String get drawerSectionAiPrompts => 'ИИ И ПРОМПТЫ';

  @override
  String get drawerPrompts => 'Промпты';

  @override
  String get drawerGptSettings => 'Настройки GPT';

  @override
  String get drawerSectionGeneral => 'ОБЩЕЕ';

  @override
  String get drawerShowIntro => 'Показать введение';

  @override
  String get drawerPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get drawerTermsOfUse => 'Условия использования (EULA)';

  @override
  String get confirmDeleteTitle => 'Подтвердите удаление';

  @override
  String get confirmDeleteAllMessage =>
      'Вы уверены, что хотите удалить все заметки? Это действие нельзя отменить.';

  @override
  String get allNotesDeleted => 'Все заметки успешно удалены.';

  @override
  String failedToDeleteNotes(String error) {
    return 'Не удалось удалить заметки: $error';
  }

  @override
  String get apiAccessSettings => 'Настройки доступа к API';

  @override
  String get selectModel => 'Выберите модель';

  @override
  String tokenLimit(String tpm) {
    return 'Лимит токенов: $tpm';
  }

  @override
  String get openAiApiKey => 'Ключ API OpenAI';

  @override
  String get geminiApiKey => 'Ключ API Gemini';

  @override
  String get getOpenAiKey => 'Получить ключ OpenAI';

  @override
  String get getGeminiKey => 'Получить ключ Gemini';

  @override
  String apiResponseDelay(String delay) {
    return 'Задержка до ответа: $delay';
  }

  @override
  String get exportTitle => 'Экспорт резервной копии';

  @override
  String get exportSelectData => 'Выберите данные для резервной копии';

  @override
  String get exportSelectAtLeastOne => 'Выберите хотя бы один тип данных.';

  @override
  String get exportExporting => 'Экспорт данных...';

  @override
  String get exportReady =>
      'Резервная копия готова! Выберите способ сохранения.';

  @override
  String exportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get exportSharedSuccess => 'Резервная копия успешно отправлена!';

  @override
  String exportShareFailed(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get exportEmailOpened => 'Почтовый клиент открыт!';

  @override
  String get exportNoEmailApp =>
      'Почтовое приложение не найдено. Используйте «Поделиться».';

  @override
  String exportEmailFailed(String error) {
    return 'Ошибка отправки письма: $error';
  }

  @override
  String get exportLabelNotes => 'Заметки и теги';

  @override
  String get exportLabelTodos => 'Задачи';

  @override
  String get exportLabelInstructions => 'ИИ-инструкции';

  @override
  String get exportCreateBackup => 'Создать копию';

  @override
  String get exportEmailButton => 'Почта';

  @override
  String get exportShareButton => 'Поделиться';

  @override
  String get exportBackupSubject => 'Резервная копия данных Chrono';

  @override
  String exportBackupBody(String types) {
    return 'Вот резервная копия ваших данных Chrono, включая: $types.';
  }

  @override
  String get importTitle => 'Импорт данных';

  @override
  String get importPressButton => 'Нажмите кнопку, чтобы импортировать данные.';

  @override
  String get importNoFileSelected => 'Файл не выбран.';

  @override
  String get importReplaceTitle => 'Заменить все данные?';

  @override
  String get importReplaceMessage =>
      'Импорт УДАЛИТ все текущие данные и заменит их резервной копией.';

  @override
  String get importCurrentToDelete => 'Текущие данные, которые будут удалены:';

  @override
  String get importLabelNotes => 'Заметки';

  @override
  String importTotalToDelete(int count) {
    return 'Всего: $count элементов будет удалено';
  }

  @override
  String get importBackupWarning =>
      '⚠️ Убедитесь, что у вас есть резервная копия!';

  @override
  String get importDeleteAndImport => 'Удалить и импортировать';

  @override
  String get importCancelled => 'Импорт отменён.';

  @override
  String get importDeleting => 'Удаление текущих данных...';

  @override
  String get importImporting => 'Импорт...';

  @override
  String get importImportingRoutines => 'Импорт рутин...';

  @override
  String get importImportingGoals => 'Импорт целей...';

  @override
  String get importImportingTodos => 'Импорт задач...';

  @override
  String get importImportingReminders => 'Импорт напоминаний...';

  @override
  String get importImportingInstructions => 'Импорт инструкций...';

  @override
  String get importImportingNotes => 'Импорт заметок и тегов...';

  @override
  String get importImportingWorkspaces => 'Импорт пространств...';

  @override
  String importSuccessCount(int count) {
    return 'Импорт успешен! Импортировано $count элементов.';
  }

  @override
  String importFailed(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get importSelectFile => 'Выбрать файл и импортировать';

  @override
  String get importWarningLong =>
      'Выберите файл резервной копии JSON для импорта.\n\n⚠️ ВНИМАНИЕ: Импорт УДАЛИТ все текущие данные и заменит их резервной копией.\n\nПеред удалением вы увидите экран подтверждения.';

  @override
  String get promptsTitle => 'Промпты';

  @override
  String get promptsNewTitle => 'Новый промпт';

  @override
  String get promptsEditTitle => 'Редактировать промпт';

  @override
  String get promptsEnterText => 'Введите текст промпта...';

  @override
  String get promptsOnTapBehavior => 'ПОВЕДЕНИЕ ПРИ НАЖАТИИ';

  @override
  String get promptsCreate => 'Создать промпт';

  @override
  String get promptsSaveChanges => 'Сохранить изменения';

  @override
  String get promptsDeleteTitle => 'Удалить промпт?';

  @override
  String promptsDeleteMessage(String text) {
    return 'Вы уверены, что хотите удалить «$text»?';
  }

  @override
  String get promptsSendInstantly => 'Отправлять сразу';

  @override
  String get promptsSendInstantlyDesc => 'Отправляет промпт немедленно';

  @override
  String get promptsInsertToInput => 'Вставить в поле ввода';

  @override
  String get promptsInsertToInputDesc => 'Вставляет текст для редактирования';

  @override
  String get promptsEmptyTitle => 'Пока нет промптов';

  @override
  String get promptsEmptyDesc =>
      'Создавайте быстрые промпты, чтобы ускорить общение с ИИ. Нажмите +, чтобы начать.';

  @override
  String get promptsSendsInstantly => 'Отправляет сразу';

  @override
  String get promptsInsertsToInput => 'Вставляет в поле ввода';

  @override
  String goalsErrorLoading(String error) {
    return 'Ошибка загрузки целей: $error';
  }

  @override
  String goalDeletedSuccess(String title) {
    return 'Цель «$title» успешно удалена';
  }

  @override
  String goalErrorDeleting(String error) {
    return 'Ошибка удаления цели: $error';
  }

  @override
  String goalErrorSaving(String error) {
    return 'Ошибка сохранения цели: $error';
  }

  @override
  String get goalsHideCompleted => 'Скрыть выполненные цели';

  @override
  String get goalsShowCompleted => 'Показать выполненные цели';

  @override
  String get goalCompleted => 'Выполнено';

  @override
  String get goalsEmptyTitle => 'Пока нет целей';

  @override
  String get goalsEmptyDesc =>
      'Создайте первую цель, чтобы отслеживать прогресс и формировать полезные привычки.';

  @override
  String get goalsCreateFirst => 'Создать первую цель';

  @override
  String get goalEditTitle => 'Редактировать цель';

  @override
  String get goalNewTitle => 'Новая цель';

  @override
  String get goalTitleLabel => 'Название цели';

  @override
  String get goalTitleRequired => 'Введите название цели';

  @override
  String get goalHours => 'Часы';

  @override
  String get goalMinutes => 'Минуты';

  @override
  String get goalSessionDuration => 'Длительность сессии (минуты)';

  @override
  String get goalUpdate => 'Обновить цель';

  @override
  String get goalCreate => 'Создать цель';

  @override
  String get goalSpecifyTime => 'Укажите хотя бы часы или минуты';

  @override
  String get goalTimeTarget => 'Целевое время';

  @override
  String get goalSessionDurationHelper =>
      'Насколько длинной должна быть каждая рабочая сессия';

  @override
  String get validatorInvalid => 'Неверно';

  @override
  String get validatorRequired => 'Обязательно';

  @override
  String get goalMinutesRange => '0-59';

  @override
  String get goalCannotDeleteActive =>
      'Нельзя удалить активную цель. Сначала остановите сессию.';

  @override
  String goalTimeSpent(String time) {
    return 'Затрачено времени: $time';
  }

  @override
  String goalRunning(String time) {
    return 'Идёт: $time';
  }

  @override
  String get goalComplete => 'Выполнить';

  @override
  String get goalUncomplete => 'Отменить выполнение';

  @override
  String get goalDeleteTitle => 'Удалить цель';

  @override
  String goalDeleteMessage(String title) {
    return 'Вы уверены, что хотите удалить «$title»?\n\nЭто действие нельзя отменить.';
  }

  @override
  String routineArchived(int count) {
    return 'В архиве ($count)';
  }

  @override
  String get routineViewHistory => 'История выполнения';

  @override
  String get routineDeleteTitle => 'Удалить рутину';

  @override
  String routineDeleteMessage(String name) {
    return 'Вы уверены, что хотите удалить «$name»?';
  }

  @override
  String get routinesEmptyTitle => 'Пока нет рутин';

  @override
  String get routinesEmptyDesc =>
      'Создайте первую рутину, чтобы формировать стабильные ежедневные привычки.';

  @override
  String get routinesCreateFirst => 'Создать первую рутину';

  @override
  String get routineSelectDay => 'Выберите хотя бы один день';

  @override
  String get routineEditTitle => 'Редактировать рутину';

  @override
  String get routineNewTitle => 'Новая рутина';

  @override
  String get routineNameLabel => 'Название рутины';

  @override
  String get routineNameRequired => 'Введите название';

  @override
  String get routineDaysOfWeek => 'Дни недели';

  @override
  String get routineRemindersPersistence => 'Напоминания и настойчивость';

  @override
  String get routineSchedule => 'Расписание';

  @override
  String get routineTime => 'Время';

  @override
  String get routineHideOtherDays => 'Скрыть другие дни';

  @override
  String get routineShowOtherDays => 'Показать другие дни';

  @override
  String get routineOtherDays => 'Другие дни';

  @override
  String get routineDuration => 'Длительность';

  @override
  String get routineInterval => 'Интервал';

  @override
  String get routineAdditional => 'Дополнительно';

  @override
  String get routineTrackStreak => 'Отслеживать серию';

  @override
  String get routineTrackStreakDesc =>
      'Показывать счётчик серии при выполнении этой рутины';

  @override
  String routineErrorCreating(String error) {
    return 'Ошибка создания записи рутины: $error';
  }

  @override
  String get commonMin => 'мин';

  @override
  String get dayMon => 'Пн';

  @override
  String get dayTue => 'Вт';

  @override
  String get dayWed => 'Ср';

  @override
  String get dayThu => 'Чт';

  @override
  String get dayFri => 'Пт';

  @override
  String get daySat => 'Сб';

  @override
  String get daySun => 'Вс';

  @override
  String get todoSelectDeadline => 'Выберите дату дедлайна';

  @override
  String todoErrorSaving(String error) {
    return 'Ошибка сохранения задачи: $error';
  }

  @override
  String get todoEditTitle => 'Редактировать задачу';

  @override
  String get todoNewTitle => 'Новая задача';

  @override
  String get todoTitleLabel => 'Название';

  @override
  String get todoTitleRequired => 'Введите название';

  @override
  String get todoNoDate => 'Без даты';

  @override
  String get todoSelectDeadlineDate => 'Выберите дату дедлайна';

  @override
  String get todoRemindTomorrow => 'Напомнить завтра';

  @override
  String get todoRemindDaily => 'Напоминать каждый день';

  @override
  String todoAtTime(String time) {
    return 'В $time';
  }

  @override
  String get todoUpdate => 'Обновить задачу';

  @override
  String get todoCreate => 'Создать задачу';

  @override
  String get todoType => 'Тип';

  @override
  String get todoTypeTomorrow => 'Завтра';

  @override
  String get todoTypeDeadline => 'Дедлайн';

  @override
  String get todoDeadlineDate => 'Дата дедлайна';

  @override
  String get todoPickDate => 'Выбрать дату';

  @override
  String get todoNotification => 'Уведомление';

  @override
  String get todoRepeatNotifications => 'Повторять уведомления';

  @override
  String get todoPeriodLabel => 'Период: ';

  @override
  String get todoEveryLabel => 'Каждые: ';

  @override
  String get commonChange => 'Изменить';

  @override
  String get todoNotifyOnDay => 'Получить уведомление в этот день';

  @override
  String get todoNotifyDaily => 'Получать уведомление каждый день до дедлайна';

  @override
  String todoNotificationPreview(int count, String period, String interval) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count уведомления',
      many: '$count уведомлений',
      few: '$count уведомления',
      one: '$count уведомление',
    );
    return '$_temp0: начиная за $period, каждые $interval';
  }

  @override
  String tagErrorSaving(String error) {
    return 'Ошибка сохранения тега: $error';
  }

  @override
  String get tagSystemCannotDelete => 'Системные теги нельзя удалить';

  @override
  String get tagDeleteTitle => 'Удаление тега';

  @override
  String get tagDeleteMessage => 'Вы уверены, что хотите удалить этот тег?';

  @override
  String get tagEditTitle => 'Редактировать тег';

  @override
  String get tagCreateTitle => 'Создать тег';

  @override
  String get tagNameLabel => 'Название тега';

  @override
  String get tagSystemNameCannotChange =>
      'Название системного тега нельзя изменить';

  @override
  String get tagEnterName => 'Введите название тега';

  @override
  String get tagNameRequired => 'Введите название тега';

  @override
  String get tagColorLabel => 'Цвет тега';

  @override
  String get productivityWeek => 'Неделя';

  @override
  String get productivityMonth => 'Месяц';

  @override
  String get productivityAllTime => 'Всё время';

  @override
  String get productivityNoActiveToday =>
      'Сегодня нет активных рутин или целей';

  @override
  String get productivityCurrentStreak => 'текущая серия';

  @override
  String get productivityBestStreak => 'лучшая серия';

  @override
  String get productivityRoutinesCompleted => 'Выполнено рутин';

  @override
  String get productivityGoalProgress => 'Прогресс целей';

  @override
  String productivityDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get productivityNoData => 'Пока нет данных за этот период';

  @override
  String get productivityNoBreakdown => 'Разбивка недоступна';

  @override
  String get productivityNoHistory => 'Пока нет истории';

  @override
  String get productivityHistory => 'История';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonNoData => 'Нет данных';

  @override
  String get commonAddedSuccess => 'Успешно добавлено';

  @override
  String calendarErrorLoadingRoutine(String error) {
    return 'Ошибка загрузки дат выполнения: $error';
  }

  @override
  String get calendarBackdateLimit =>
      'Отмечать выполнение задним числом можно только за последние 14 дней';

  @override
  String calendarMarkCompleted(String name, String date) {
    return 'Отметить «$name» как выполненную $date?\n\nЭто соответственно обновит вашу серию.';
  }

  @override
  String get routineCompletionAdded => 'Выполнение рутины успешно добавлено';

  @override
  String get routineNotScheduled =>
      'Рутина не запланирована на этот день недели';

  @override
  String get routineAlreadyCompleted =>
      'Рутина уже отмечена выполненной в этот день';

  @override
  String get calendarMarkAsComplete => 'Отметить выполненной';

  @override
  String calendarTitleHistory(String name) {
    return '$name — история';
  }

  @override
  String get calendarTapPastDate =>
      'Нажмите на любую прошедшую дату, чтобы отметить выполнение';

  @override
  String get calendarTotalCompletions => 'Всего выполнений';

  @override
  String get calendarCurrentStreak => 'Текущая серия';

  @override
  String goalCalendarErrorLoading(String error) {
    return 'Ошибка загрузки истории цели: $error';
  }

  @override
  String get goalAddWorkSession => 'Добавить рабочую сессию';

  @override
  String get goalCompletedCannotEdit =>
      'Эта цель выполнена и не может быть изменена';

  @override
  String goalAddWorkFor(String title, String date) {
    return 'Добавить работу над «$title» за $date';
  }

  @override
  String get goalEnterValidMinutes => 'Введите корректное количество минут';

  @override
  String get goalTapPastDate =>
      'Нажмите на любую прошедшую дату, чтобы добавить рабочую сессию';

  @override
  String goalDailyTarget(int minutes) {
    return 'Дневная цель: $minutes мин';
  }

  @override
  String get todoListNoDateSection => 'БЕЗ ДАТЫ';

  @override
  String get todoSectionTomorrow => 'ЗАВТРА';

  @override
  String get todoSectionDeadline => 'ДЕДЛАЙН';

  @override
  String get todoSectionOverdue => 'ПРОСРОЧЕНО';

  @override
  String get todoSectionCompleted => 'ВЫПОЛНЕНО';

  @override
  String get todoTypesTitle => 'Типы задач';

  @override
  String get todoTypeTomorrowDesc =>
      'Задачи, которые вы планируете сделать завтра. Переходят в просроченные, если не выполнены.';

  @override
  String get todoTypeDeadlineDesc =>
      'Задачи с конкретным сроком. Включите ежедневные напоминания, чтобы получать уведомления каждый день.';

  @override
  String get todoTypeNoDateTitle => 'Без даты';

  @override
  String get todoTypeNoDateDesc => 'Задачи из бэклога без конкретного срока.';

  @override
  String get todoAboutTypes => 'О типах задач';

  @override
  String get todoListEmptyTitle => 'Пока нет задач';

  @override
  String get todoListEmptyDesc => 'Нажмите +, чтобы создать первую задачу';

  @override
  String get todoListAddButton => 'Добавить задачу';

  @override
  String get todoListEmptyShort => 'Пока нет задач\nНажмите +, чтобы создать';

  @override
  String get tagsClearSelection => 'Очистить выбор';

  @override
  String get chatContextTooLarge => 'Слишком большой контекст';

  @override
  String get chatUnexpectedError => 'Непредвиденная ошибка';

  @override
  String get chatContextExceedsLimit =>
      'Выбранный контекст превышает лимит модели.';

  @override
  String chatSplitInfo(int chunks) {
    return 'Мы можем разбить его примерно на $chunks частей и обработать последовательно. ИИ получит весь контекст перед ответом.';
  }

  @override
  String get chatChunkingNote =>
      'Примечание: это может занять больше времени и стоить дороже.';

  @override
  String get chatContinueChunking => 'Продолжить с разбиением';

  @override
  String get chatAiContext => 'Контекст ИИ';

  @override
  String get chatAiContextPreview => 'Предпросмотр контекста ИИ';

  @override
  String chatApiError(String error) {
    return 'Ошибка API: $error';
  }

  @override
  String get chatRequestCancelled => 'Запрос отменён.';

  @override
  String get chatApiKeysSettings => 'Настройки API-ключей';

  @override
  String get chatAiCoach => 'ИИ-коуч';

  @override
  String get chatUnexpectedErrorRetry =>
      'Произошла непредвиденная ошибка. Попробуйте снова.';

  @override
  String get chatErrorRetry => 'Произошла ошибка. Попробуйте снова.';

  @override
  String chatChunkedError(String error) {
    return 'Ошибка при поблочной обработке: $error';
  }

  @override
  String get commonCalendar => 'Календарь';

  @override
  String get sessionStopGoal => 'Остановить цель';

  @override
  String get messageGoToNotes => 'Перейти к заметкам';

  @override
  String get composerHint => 'Напишите сообщение здесь...';

  @override
  String get undoRedoHint => 'Введите текст...';

  @override
  String get productivityLow => 'Низкий';

  @override
  String get productivityHigh => 'Высокий';

  @override
  String get checkinAnalyticsTitle => 'Аналитика';

  @override
  String get checkinMorning => 'Утренний чек-ин';

  @override
  String get checkinEvening => 'Вечерний чек-ин';

  @override
  String get checkinMorningShort => 'Утро';

  @override
  String get checkinEveningShort => 'Вечер';

  @override
  String get checkinNoData => 'Нет данных за выбранный период';

  @override
  String get insightsSaved => 'Настройки инсайтов сохранены';

  @override
  String get insightsEnable => 'Включить ИИ-инсайты';

  @override
  String get insightsInterval => 'Интервал (минуты)';

  @override
  String get insightsContextWindow => 'Окно контекста (дни)';

  @override
  String get insightsTokenLimit => 'Лимит токенов (примерно)';

  @override
  String get insightsQuietStart => 'Начало тихих часов';

  @override
  String get insightsQuietEnd => 'Конец тихих часов';

  @override
  String get insightsTestNow => 'Проверить генерацию инсайтов сейчас';

  @override
  String get insightsFullContextJson => 'Полный контекст JSON';

  @override
  String get insightsSystemPrompt => 'Системный промпт';

  @override
  String get insightsUserPrompt => 'Пользовательский промпт (JSON)';

  @override
  String get insightsNoneSaved => 'Инсайты ещё не сохранены.';

  @override
  String get insightsNoItems => 'Нет элементов';

  @override
  String get insightsSettingsTitle => 'Настройки ИИ-инсайтов';

  @override
  String get commonNotSet => 'Не задано';

  @override
  String get insightsGenerating =>
      '🧪 Генерация инсайта... смотрите логи и уведомления';

  @override
  String get insightsTestCompleted => '✅ Тест завершён! Подробности в логах';

  @override
  String insightsCharCount(int count) {
    return '$count символов';
  }

  @override
  String get insightsNoTopic => '(без темы)';

  @override
  String get insightsRequiresInternet =>
      'Для генерации инсайтов требуется интернет-соединение и ключ API OpenAI';

  @override
  String get onbSkip => 'Пропустить';

  @override
  String get onbNext => 'Далее';

  @override
  String get onbGetStarted => 'Начать';

  @override
  String get ob1Title => 'Время — единственный\nневосполнимый ресурс';

  @override
  String get ob1Subtitle => 'Хватит его тратить.\nНачните его инвестировать.';

  @override
  String get ob2Title => 'Ваши данные. Ваше устройство.';

  @override
  String get ob2Subtitle =>
      'Chrono работает на 100% офлайн.\nВсе ваши данные остаются на телефоне —\nприватно и всегда доступно.';

  @override
  String get ob2Footnote =>
      'Функции ИИ могут отправлять ваши данные сторонним сервисам.';

  @override
  String get ob3Title => 'Ваш внешний мозг';

  @override
  String get ob3Subtitle =>
      'Письмо — это не просто запись, это мышление.\nДелать заметки ещё никогда не было так просто.';

  @override
  String get ob4Title => 'Несокрушимая дисциплина';

  @override
  String get ob4Subtitle =>
      'Рутина — это то, что делает нас лучше каждый день.\nЕжедневный сброс. Настойчивые уведомления.\nНикакого места для прокрастинации.';

  @override
  String get ob5Title => 'Инвестируйте своё время';

  @override
  String get ob5Subtitle =>
      'Что измеряется, тем можно управлять.\nЕжедневные цели для глубокой работы — видьте, куда уходит время\nи что ещё требует внимания.';

  @override
  String get ob6Title => 'Ваши заметки —\nбаза знаний';

  @override
  String get ob6Subtitle =>
      'Общайтесь с ИИ бесплатно — со своим ключом API.\nПередавайте заметки как контекст, чтобы получать инсайты,\nоснованные на ваших данных.';

  @override
  String get ob6Footnote => 'Требуется ваш собственный ключ API.';

  @override
  String get ob7Title => 'Ваше пространство для мыслей';

  @override
  String get ob7Subtitle =>
      'Великим идеям нужно место для развития.\nСобирайте материалы, оформляйте мысли, анализируйте —\nкаждое пространство — лаборатория для ваших идей.';

  @override
  String get ob8Title => 'Измеряйте свой рост';

  @override
  String get ob8Subtitle =>
      'Что отслеживаете, то улучшаете.\nЕжедневная оценка на основе рутин и целей.\nЗамечайте тренды, находите закономерности, растите.';

  @override
  String get paywallUnlock => 'Раскройте свой\nполный потенциал';

  @override
  String get paywallOneTime => 'Разовая покупка';

  @override
  String paywallSave(int percent) {
    return 'Экономия $percent%';
  }

  @override
  String get paywallStartGrowing => 'Начать расти';

  @override
  String get paywallSeePlans => 'Посмотреть планы';

  @override
  String get paywallRestore => 'Восстановить покупки';

  @override
  String get paywallContinueFree => 'Продолжить бесплатно';

  @override
  String get planLifetime => 'Навсегда';

  @override
  String get planGeneric => 'План';

  @override
  String planYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '1 год',
    );
    return '$_temp0';
  }

  @override
  String planMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '1 месяц',
    );
    return '$_temp0';
  }

  @override
  String planWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недели',
      many: '$count недель',
      few: '$count недели',
      one: '1 неделя',
    );
    return '$_temp0';
  }

  @override
  String get pfRoutineTitle => 'Менеджер рутин';

  @override
  String get pfRoutineSub => 'Формируйте несокрушимые ежедневные привычки';

  @override
  String get pfGoalTitle => 'Менеджер целей';

  @override
  String get pfGoalSub => 'Отслеживайте сессии глубокой работы с таймерами';

  @override
  String get pfTodoTitle => 'Менеджер задач';

  @override
  String get pfTodoSub => 'Дедлайны с ежедневными напоминаниями';

  @override
  String get pfWorkspacesTitle => 'Пространства';

  @override
  String get pfWorkspacesSub => 'Организуйте идеи в отдельные лаборатории';

  @override
  String get pfProductivityTitle => 'Индекс продуктивности';

  @override
  String get pfProductivitySub => 'Ежедневная оценка вашего прогресса';

  @override
  String get pfAiTitle => 'Контекст ИИ';

  @override
  String get pfAiSub => 'Передавайте заметки ИИ для более глубоких инсайтов';

  @override
  String get pfAiNote => 'Требуется ваш собственный ключ API';

  @override
  String get paywallSubscriptionTerms =>
      'Подписки автоматически продлеваются, если не отменить их не менее чем за 24 часа до окончания текущего периода. Оплата за продление списывается в течение 24 часов до окончания текущего периода. Управлять подписками и отменять их можно в настройках вашей учётной записи App Store.';
}
