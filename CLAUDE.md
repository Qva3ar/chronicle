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
- `intl` - Date formatting and internationalization

### Development Notes

- App uses custom color scheme (MyColors class)
- Proper lifecycle management for background timer operations
- Stream-based communication between components
- Comprehensive error handling with logging
- Database schema migrations preserve user data across updates