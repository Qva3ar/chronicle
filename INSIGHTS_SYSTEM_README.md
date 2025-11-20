# AI Insights System

This document explains how the Chrono “AI Insights” feature works end‑to‑end so that another engineer (or AI assistant) can reason about it quickly, extend it safely, and debug issues without reverse‑engineering the codebase.

## 1. Product Purpose
- **Goal:** Periodically synthesize the user’s recent activity (notes, goals, routines, signals) into a short coaching tip.
- **Delivery:** Insights can appear as push notifications and in‑app banners. As of Nov 2025, we always send a notification for each stored insight.
- **Cadence:** Controlled by the “interval minutes” setting (15–720). Each scheduled run generates at most one insight and immediately schedules the next run.

## 2. Key Components
| Responsibility | File |
| --- | --- |
| User settings UI & preview | `lib/screens/settings/insights_settings_screen.dart` |
| **Background worker (WorkManager)** | `lib/background/task_dispatcher.dart` |
| Context gathering & settings loading | `lib/ai/context_builder.dart` |
| OpenAI client & throttling | `lib/ai/ai_client.dart` |
| Insight generation + storage | `lib/ai/insight_engine.dart` |
| Notifications & quiet hours | `lib/services/notification_service.dart` |
| Banner rendering on home page | `lib/widgets/insight_banner.dart` |
| SQLite schema & helpers | `lib/db_manager.dart` |

## 3. Data & Control Flow
1. **Initialization**
   - `main.dart` loads persisted API creds (`GPTNoteBindService`), opens the database, initializes notifications/timer services, and calls `BackgroundTaskManager.initialize()` to set up the unified WorkManager dispatcher.
   - `BackgroundTaskManager.scheduleInsightGeneration()` registers the periodic background task when insights are enabled.
   - `InsightsSettingsScreen` persists values into `app_settings` and calls `BackgroundTaskManager.scheduleInsightGeneration()` to update the background task schedule.

2. **Scheduling (WorkManager)**
   - Scheduling via `Workmanager.registerPeriodicTask()` manages periodic insight generation.
   - **Android:** Uses WorkManager/JobScheduler for reliable background execution.
   - **iOS:** Uses BGTaskScheduler via the same plugin.
   - Minimum interval is 15 minutes with a network connectivity constraint.
   - The unified callback (`backgroundTaskDispatcher`) runs in a background isolate and handles all background tasks including insights, daily reset, session completion, and routine notifications.

3. **Context Building (`ContextBuilder`)**
   - Reads from `app_settings`, `ai_interest_signals`, `ai_context_summaries`, `goals`, `routines`, and `record` tables.
   - Truncates notes to respect a rough token budget (`tokenLimitApprox * 4` chars).
   - Picks a “primary goal” (priority: explicit primary → active goal → first goal) and produces both a Dart map and a `context_json` string for hashing.

4. **De-duplication**
   - `InsightEngine` hashes `context_json` (FNV-1a 64-bit). If the same hash already produced an insight within 24 hours the run is skipped, which prevents spam during quiet periods even if the job fires frequently.

5. **Model Call & Fallback**
   - `AiClient.completeJson()` enforces API key/model availability, rate-limits to 20 req/min, and retries with exponential backoff.
   - The model must respond with a JSON string containing at least `title`, `body`, `tags`, `should_notify`, `score`, `urgency`, `ttl_hours`.
   - If JSON parsing fails we fall back to a generic “Идея для фокуса” with the raw text truncated to 280 characters and `should_notify` previously defaulted to `false`.

6. **Storage & Notification Decisions**
   - Insights are written to `ai_insights` with: title, body, tags JSON, score, urgency, `source_context_hash`, `delivered_as`, `delivered_at`, `expires_at`, `dismissed_at`.
   - **Nov 2025 change:** `should_notify` is now hard-coded to `true`, so every stored insight is tagged as `'notification'` and will request a push (`NotificationService.showInsightNotification`). Quiet hours can still suppress the actual notification.

7. **User-Facing Surfaces**
   - **Notifications:** `NotificationService` enforces quiet hours (based on `app_settings.quiet_hours_*`). On tap it opens a modal bottom sheet via `navigatorKey`.
   - **Home Banner:** `InsightBanner` queries the freshest non-expired, non-dismissed row and displays title/body. Dismiss adds a timestamp to `insight_dismissed_at`.
   - **Settings Screen:** Shows interest-signal previews and the “Stored insights (last 50)” list for debugging.

## 4. Database Schema Summary
Relevant tables/columns (see `lib/db_manager.dart` for complete definitions):

| Table | Columns |
| --- | --- |
| `app_settings` | `insight_enabled`, `insight_interval_minutes`, `insight_context_days`, `insight_token_limit`, `quiet_hours_start`, `quiet_hours_end`, `primary_goal_id`, `main_intention_text` |
| `ai_insights` | `_id`, `title`, `body`, `tags`, `score`, `urgency`, `source_context_hash`, `delivered_as`, `delivered_at`, `dismissed_at`, `expires_at` |
| `ai_interest_signals` | `_id`, `source`, `topic`, `intent`, `confidence`, `created_at`, … |

`DatabaseHelper` ensures the schema exists and seeds default settings (insights enabled, 60‑minute interval).

## 5. Configuration & User Controls
- **Enable/disable insights:** `SwitchListTile` in settings toggles `insight_enabled`. When off, jobs are cancelled and `_insightJobCallback` returns early.
- **Interval:** Integer minutes with validation (15–720). Impacts the Android alarm schedule.
- **Context window & token limit:** Affect how many historical records feed the prompt; larger windows increase processing time.
- **Quiet hours:** Start/end `HH:mm`. Notifications during this window are suppressed (no DB changes).
- **Manual regeneration:** Saving settings triggers `InsightEngine.generateAndStoreInsight()` immediately for quick feedback.

## 6. Error Handling & Observability
- **Logging tags:** Look for `[InsightJob]`, `[Insights]`, `AiClient`, `NotificationService`, `InsightBanner`.
- **Network/API errors:** Network calls in background may fail due to Android Doze mode or battery optimization. The system gracefully handles this by logging `📡 Network unavailable - will retry on next scheduled run` and skipping that run. Next alarm is still scheduled.
- **Fallback payloads:** Logged as `[Insights] Failed to parse JSON, using fallback payload.` Usually caused by invalid API responses or blank replies.
- **Notifications suppressed:** Log `🔕 Quiet hours active` before returning.
- **Banner blank:** Means no rows satisfy "not expired & not dismissed". Check the settings debug list to confirm DB contents.

### Background Execution (WorkManager)

**✅ IMPROVED:** As of Nov 2025, the app uses **WorkManager** for reliable cross-platform background tasks.

**Advantages of WorkManager:**
- ✅ **Reliable network access** in background (better than AndroidAlarmManager)
- ✅ **Cross-platform:** Works on both Android and iOS
- ✅ **Battery-aware:** System schedules tasks intelligently
- ✅ **Automatic retry:** Failed tasks are retried with exponential backoff
- ✅ **Network constraints:** Only runs when internet is available

**Platform-Specific Behavior:**

**Android (WorkManager):**
- Uses JobScheduler/WorkManager API
- Runs reliably even when app is closed
- Respects Doze mode but gets execution windows
- Minimum interval: 15 minutes
- Network calls work properly in background isolate

**iOS (BGTaskScheduler):**
- Uses Background Fetch/BGTaskScheduler
- Execution controlled by iOS (opportunistic)
- Best effort - iOS decides when to run based on usage patterns
- More reliable if user opens app regularly
- Minimum interval: 15 minutes (enforced by workmanager package)

**Expected Behavior:**
- ✅ **Manual trigger:** Always works immediately when app is open
- ✅ **Background tasks (Android):** Reliable execution at scheduled intervals
- ⚠️ **Background tasks (iOS):** Opportunistic - iOS decides optimal timing
- ✅ **Network errors:** Automatic retry with exponential backoff
- ✅ **Battery optimization:** Works even with optimization enabled (Android 12+)

**For Best Results:**
1. **Android:** Just enable insights - WorkManager handles the rest
2. **iOS:** Open the app occasionally to increase background task priority
3. **Both platforms:** Ensure app has notification permissions
4. **Testing:** Use "Test Insight Generation Now" button for immediate results

**Troubleshooting:**
- Check logs for `[InsightWorker]` tags
- Failed network requests will automatically retry
- Background tasks may be delayed if battery is very low
- iOS: Background tasks execute more frequently if user engages with app regularly

## 7. Extending the System
- **Custom notification rules:** Adjust the `shouldNotify` logic in `insight_engine.dart` (currently hard‑coded true). Could be tied to `score`, `urgency`, or user preference.
- **Additional context sources:** Enhance `ContextBuilder` to pull more tables, but keep token budgets in mind.
- **Retry/resilience:** Consider moving the “schedule next run” call into a `finally` block so network failures do not halt the pipeline.
- **Cross‑platform support:** Currently `InsightJob` is Android-only. iOS would need background fetch / push support plus equivalent notification handling.

## 8. Manual Testing Checklist

1. Set API key & model via the API key popup (stored in `SharedPreferences` by `GPTNoteBindService`).
2. In Insight Settings, enable insights, set interval to 15 minutes, quiet hours blank.
3. Save settings (watch logs for `[BackgroundTaskManager] ✅ Insight generation scheduled`).
4. Click "Test Insight Generation Now" button:
   - Watch logs for `[InsightGeneration] 🔄 Starting insight generation`
   - Verify notification appears immediately
   - Check "Stored insights" list shows new entry
5. **Android:** Wait 15 minutes, verify background task fires (`[TaskDispatcher] 🔄 Background task started: com.chrono.insight_generation`)
6. **iOS:** Background task execution is opportunistic - may not fire exactly on schedule
7. Verify:
   - Push notification arrives (outside quiet hours).
   - Home banner shows the same text after returning to the app.
   - Settings screen "Stored insights" list updates with `delivered_as = notification`.
8. Toggle insights off → confirm `[BackgroundTaskManager] ℹ️ Insight generation disabled` appears.

Keeping this flow in mind should let any contributor – human or AI – reason about expected behavior, diagnose discrepancies, and implement new functionality confidently.

