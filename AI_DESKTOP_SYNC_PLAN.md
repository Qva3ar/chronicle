# ИНСТРУКЦИЯ ДЛЯ ИИ-АГЕНТА: Проект "Chrono Desktop Sync"

**Цель:** Добавить десктопный клиент (macOS/Windows) к существующему Flutter-приложению Chrono. Десктоп подключается к телефону как к локальному серверу по Wi-Fi и позволяет **создавать заметки и работать с Workspaces**. Мобильное приложение при этом не должно сломаться.

**Ключевые ограничения:**
- Десктоп доступен **только пользователям с активной подпиской** (Adapty).
- Сервер на телефоне работает **только пока приложение открыто** (foreground). Это ожидаемое поведение.
- Scope десктопного UI намеренно узкий: только заметки (Records) и Workspaces. Никаких Goals, Routines, Check-ins и т.д.

---

## Архитектурное видение

Паттерн **Local API Host**:
1. **Mobile App (Host):** Поднимает HTTP/WebSocket сервер через `flutter_foreground_task` (держит процесс живым). Имеет эксклюзивный доступ к `sqflite`. Обрабатывает REST-запросы от десктопа.
2. **Desktop App (Client):** Не использует `sqflite`. Общается с телефоном через HTTP. UI только для заметок и Workspaces.
3. **Pairing:** QR-код генерируется на **десктопе**, сканируется телефоном. Токен + адрес десктопа зашиты в QR. Телефон отвечает своим адресом. Оба сохраняют токен.
4. **Подписка:** Телефон проверяет Adapty-статус перед каждым подключением. Без подписки сервер отклоняет все запросы с `403`.

---

## Минимизация рисков для мобильного приложения

**Главное правило:** Существующий код мобильного приложения трогается **минимально**. Сервер — это аддон, а не рефакторинг.

- Никакого переписывания data-слоя. Сервер вызывает существующие сервисы (`RecordService`, db методы) напрямую.
- Весь серверный код изолирован в `lib/desktop_server/` — отдельная папка, не затрагивает текущую структуру.
- Сервер стартует только при явном включении пользователем (toggle в настройках), не автоматически.
- Зависимости (`shelf`, `shelf_router`, `flutter_foreground_task`, `nsd`) добавляются в `pubspec.yaml`, но не ломают существующие импорты.

---

## Пошаговый план реализации

### Phase 1: HTTP-сервер на телефоне (Mobile Server)

**Задача:** Поднять минимальный сервер поверх существующего кода. Не рефакторить ничего лишнего.

1. Добавить в `pubspec.yaml`:
   - `shelf` + `shelf_router` — HTTP-сервер
   - `flutter_foreground_task` — удержание процесса на iOS/Android
   - `nsd` — mDNS авто-обнаружение в сети

2. Создать `lib/desktop_server/` со структурой:
   ```
   lib/desktop_server/
     server_service.dart       # старт/стоп сервера, foreground task
     server_router.dart        # маршруты API
     handlers/
       records_handler.dart    # GET /api/v1/records, POST /api/v1/records
       workspaces_handler.dart # GET /api/v1/workspaces, POST /api/v1/workspaces, etc.
     middleware/
       auth_middleware.dart    # проверка Bearer токена
       subscription_middleware.dart  # проверка Adapty подписки
   ```

3. API endpoints (минимальный набор для scope десктопа):
   ```
   GET    /api/v1/records          # список заметок
   POST   /api/v1/records          # создать заметку
   GET    /api/v1/records/:id      # одна заметка
   PATCH  /api/v1/records/:id      # редактировать
   DELETE /api/v1/records/:id      # удалить

   GET    /api/v1/workspaces       # список workspaces
   POST   /api/v1/workspaces       # создать workspace
   PATCH  /api/v1/workspaces/:id   # редактировать
   DELETE /api/v1/workspaces/:id   # удалить
   GET    /api/v1/workspaces/:id/records  # заметки workspace

   GET    /api/v1/tags             # теги (нужны при создании заметки)

   GET    /api/v1/health           # без авторизации — для проверки связи
   ```

4. Жизненный цикл:
   - Сервер стартует на `0.0.0.0:8765`
   - `flutter_foreground_task` показывает persistent notification "Chrono Desktop подключён"
   - При остановке сервера — notification убирается
   - Toggle в Settings (новая секция "Desktop Connection")

5. Версионирование: все пути через `/api/v1/` — обязательно, чтобы будущие изменения не сломали старых клиентов.

### Phase 2: Pairing (QR на десктопе, сканирование телефоном)

**Задача:** Безопасное сопряжение без ручного ввода IP.

**Схема flow:**
```
Десктоп                          Телефон
  │                                │
  ├─ генерирует одноразовый токен  │
  ├─ показывает QR:                │
  │   {ip: "192.168.1.5",          │
  │    port: 8766,                 │
  │    token: "abc123"}            │
  ├─ слушает на порту 8766 ───────►│ сканирует QR
  │                                ├─ POST http://192.168.1.5:8766/pair
  │◄───────────────────────────────┤   {phone_ip: "192.168.1.10",
  │                                │    phone_port: 8765,
  │                                │    token: "abc123"}
  ├─ сохраняет phone_ip:phone_port │
  ├─ сохраняет токен               ├─ сохраняет токен
  └─ QR экран закрывается          └─ готово к работе
```

**Детали:**
- Токен — криптографически случайный, 32 байта (`dart:math` SecureRandom).
- Хранение: `shared_preferences` на обоих устройствах.
- Инвалидация: кнопка "Отключить Desktop" в настройках телефона — удаляет токен, сервер перестаёт принимать соединения.
- mDNS (`nsd`): телефон транслирует `_chrono._tcp` → десктоп может найти телефон в сети без ввода IP (как fallback к QR, или как авто-реконнект).
- Android 12+: нужно `CHANGE_WIFI_MULTICAST_STATE` в `AndroidManifest.xml`.

### Phase 3: Проверка подписки

**Задача:** Десктоп-функция только для платных пользователей.

1. `subscription_middleware.dart` в каждом запросе:
   - Вызывает `AdaptyService` (уже есть в проекте через `adapty_flutter`) — проверяет активный paywall.
   - Если нет подписки → `403 Forbidden` с телом `{"error": "subscription_required"}`.
   - Кешировать статус на 5 минут, не ходить в Adapty на каждый запрос.

2. Десктопное приложение при получении `403`:
   - Показывает экран "Подписка не активна. Оформите подписку в мобильном приложении Chrono."
   - Никакого in-app purchase на десктопе — монетизация только через мобильное приложение.

### Phase 4: Real-time обновления (WebSockets)

**Задача:** Десктоп видит новые заметки, созданные на телефоне, без перезагрузки.

1. Добавить `shelf_web_socket` в зависимости.

2. Эндпоинт `ws://phone_ip:8765/ws`:
   - Десктоп подключается после pairing.
   - При Insert/Update/Delete в таблицах `record` или рабочих пространств — сервер рассылает событие:
     ```json
     {"event": "record_created", "id": 42}
     {"event": "record_updated", "id": 42}
     {"event": "record_deleted", "id": 42}
     {"event": "workspace_updated", "id": 5}
     ```
   - Десктоп по событию делает GET-запрос за актуальными данными (не передаём всю запись в событии — проще, надёжнее).

3. Мобильный UI не затрагивается: WebSocket-нотификации отправляются параллельно, вне UI-потока.

### Phase 5: Desktop Flutter App

**Задача:** Запустить и адаптировать UI под большой экран.

1. Добавить платформы:
   ```bash
   flutter create --platforms=macos,windows .
   ```

2. Исключить несовместимые плагины на Desktop (через platform checks):
   - `adapty_flutter` — не поддерживает Desktop. На десктопе `AdaptyService` возвращает заглушку (подписка проверяется на телефоне-сервере, не локально).
   - `flutter_local_notifications`, `workmanager`, `home_widget` — исключить через `dart:io Platform` checks или `kIsWeb`/platform guards в `main.dart`.

3. Структура Desktop UI (только два раздела):
   ```
   lib/desktop/
     desktop_app.dart          # точка входа для Desktop
     screens/
       pairing_screen.dart     # QR + статус подключения
       notes_screen.dart       # список заметок + создание
       workspaces_screen.dart  # workspaces
     services/
       remote_records_service.dart    # HTTP-клиент для records
       remote_workspaces_service.dart # HTTP-клиент для workspaces
       websocket_service.dart         # подписка на события
       pairing_service.dart           # хранение токена и адреса телефона
   ```

4. Navigation: `NavigationRail` (боковое меню) — два пункта: Заметки, Workspaces.

5. `main.dart` разделить по платформе:
   ```dart
   if (Platform.isMacOS || Platform.isWindows) {
     runApp(DesktopApp());
   } else {
     runApp(MobileApp()); // существующий код без изменений
   }
   ```

---

## Технические правила

1. **Не ломать мобильный режим:** Весь новый код — в `lib/desktop_server/` и `lib/desktop/`. Мобильный код не трогаем без крайней необходимости.
2. **Безопасность:** Никакие данные не отдаются без валидного токена (кроме `/api/v1/health`).
3. **Подписка:** `403` без активной подписки — без исключений.
4. **Сервер — опциональный:** Телефон работает полностью автономно. Сервер — дополнительная фича, которую юзер включает вручную.
5. **Минимальный API:** Только endpoints нужные для заметок и Workspaces. Не добавлять Goals, Routines и т.д. до явного запроса.
6. **Версионирование API:** Всегда `/api/v1/`. При breaking change — `/api/v2/`.
7. **iOS foreground:** Сервер держится через `flutter_foreground_task`. Документировать юзеру что телефон должен быть с открытым приложением.

---

## Ограничения платформ (известные)

| Пакет | iOS | Android | macOS | Windows |
|-------|-----|---------|-------|---------|
| `adapty_flutter` | ✅ | ✅ | ❌ | ❌ |
| `workmanager` | ✅ | ✅ | ❌ | ❌ |
| `home_widget` | ✅ | ✅ | ❌ | ❌ |
| `flutter_local_notifications` | ✅ | ✅ | ⚠️ | ⚠️ |
| `sqflite` | ✅ | ✅ | ✅* | ✅* |
| `shelf` | ✅ | ✅ | ✅ | ✅ |
| `nsd` | ✅ | ✅ | ✅ | ✅ |

*sqflite на Desktop требует `sqflite_common_ffi` — уже есть в `dev_dependencies`, перенести в `dependencies`.

---

## Порядок реализации (рекомендуемый)

1. **Phase 1** — сервер на телефоне. Тест: `curl http://phone_ip:8765/api/v1/health`.
2. **Phase 3** — middleware подписки. Тест: запрос без токена → 401, без подписки → 403.
3. **Phase 2** — pairing. Тест: QR на десктопе, сканирование, успешный GET /records.
4. **Phase 5** — Desktop Flutter UI с минимальным экраном заметок.
5. **Phase 4** — WebSockets в последнюю очередь, когда основное работает.
