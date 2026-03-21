# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application called "Chrono" - a goal-oriented note-taking and task management app with AI integration. The app allows users to create records (notes), organize them with tags, track goals with time management, manage routines, and interact with GPT for note processing.

## Development Commands

### Flutter Commands
- `flutter run` - Run the app on connected device/emulator
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter test` - Run unit tests
- `flutter clean` - Clean build artifacts
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Update dependencies

### Debugging
- `flutter doctor` - Check Flutter environment setup
- `flutter devices` - List connected devices
- `flutter logs` - View device logs

## Architecture Overview

### Core Components

**Database Layer (lib/db_manager.dart)**
- SQLite database using sqflite package
- Database version: 22
- Tables: tags, record, record_tag, instructions, routines, goals, sessions
- Comprehensive CRUD operations with proper error handling
- Database migrations handled through version upgrades

**Main Data Models**
- `Record` - Core note/record entity with text, title, tags, timestamps
- `Goal` - Time-tracked goals with sessions and completion tracking  
- `Tag` - Categories for organizing records with colors
- `Routine` - Scheduled recurring tasks
- `Instruction` - GPT interaction prompts

**Key Services**
- `RecordService` - Business logic for record operations
- `TimerService` - Goal session timing and background handling
- `GPTNoteBindService` - AI integration for note processing
- `NotificationService` - Local notifications for routines
- `DataExporter` - Import/export functionality

### UI Structure

**Main Screens**
- `HomePage` - Primary record list with search, filtering, and grouping
- `CardDetailPage` - Record create/edit interface
- `GoalsScreen` - Goal management with time tracking
- `RoutineManagerScreen` - Daily routine management
- `ChatPage` - GPT integration interface

**Key UI Patterns**
- Bottom sheet modals for secondary actions
- Grouped list view for chronological record display
- Real-time updates using streams and listeners
- Tag-based filtering and search functionality

### Data Flow

1. **Records**: Created via FloatingActionButton → CardDetailPage → DatabaseHelper → HomePage refresh
2. **Goals**: Time tracking via TimerService with background persistence
3. **Import/Export**: JSON-based data exchange with email integration
4. **GPT Integration**: API key management → chat interface → note processing

### Key Dependencies
- `sqflite` - Local SQLite database
- `provider` - State management
- `grouped_list` - Chronological record display
- `dart_openai` - GPT API integration
- `flutter_local_notifications` - Routine reminders
- `workmanager` - Background task management
- `intl` - Date formatting and internationalization

### Background Task System

**Unified WorkManager Dispatcher** (`lib/background/task_dispatcher.dart`)
- Session completion timers
- Daily reset at midnight
- Routine notifications with retries
- AI insight generation

**Important:** All background tasks use WorkManager. AndroidAlarmManager has been fully removed.

### Development Notes

- App uses custom color scheme (MyColors class)
- Proper lifecycle management for background timer operations
- Stream-based communication between components
- Comprehensive error handling with logging
- Database schema migrations preserve user data across updates

## Documentation Files

For detailed documentation on specific systems, see:

- **[DAILY_RESET_README.md](DAILY_RESET_README.md)** - Daily reset system, routine streak logic, and critical implementation details
- **[PRODUCTIVITY_INDEX_README.md](PRODUCTIVITY_INDEX_README.md)** - Productivity index calculation, Banner/note sync, backdating, and when to call createOrUpdateDailyRecord
- **[TIMER_SYSTEM_README.md](TIMER_SYSTEM_README.md)** - Goal session timing and background task handling
- **[INSIGHTS_SYSTEM_README.md](INSIGHTS_SYSTEM_README.md)** - AI insights generation system
- **[NOTIFICATION_DEBUG_GUIDE.md](NOTIFICATION_DEBUG_GUIDE.md)** - Debugging notification issues
- **[MIUI_SETUP_GUIDE.md](MIUI_SETUP_GUIDE.md)** - Setup guide for MIUI devices

## Git Commit Guidelines

**IMPORTANT:** When creating git commits for this project:
- Do NOT include "Generated with Claude Code" footer
- Do NOT add "Co-Authored-By: Claude" attribution
- Keep commit messages concise and focused on the actual changes

## Important Implementation Notes

### Routine Reset Methods ⚠️

When working with daily reset, **always use the correct method**:

✅ **CORRECT for daily reset:**
```dart
await db.resetRoutinesDoneStatus();  // Only resets isDone flag
```

❌ **WRONG for daily reset:**
```dart
await routineService.resetRoutine(routine.id);  // Uses toggleRoutineDone - will corrupt streaks!
```

**Why:** `toggleRoutineDone()` is designed for user undo actions and will restore `previousStreak` if called on the same day as completion. This will break routine streaks during midnight reset. See [DAILY_RESET_README.md](DAILY_RESET_README.md) for details.

### Goal Completion

Goals are **daily recurring tasks** like routines:
- When completed during the day, app creates a record/note
- At midnight, `completedAt` is cleared so goal can be worked on again
- `timeSpentSeconds` resets to 0 for fresh daily timer