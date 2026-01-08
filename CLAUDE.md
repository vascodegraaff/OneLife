# OneLife - Screen Time Management App

## Project Overview

OneLife is an iOS screen time management app that leverages Apple's Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) to help users limit their app usage through shields, intentions, and schedules.

## Tech Stack

- **Language**: Swift 5
- **UI Framework**: SwiftUI
- **Target Platform**: iOS 15+
- **Key Frameworks**:
  - `FamilyControls` - Authorization and family activity selection
  - `ManagedSettings` - Shield configuration and app blocking
  - `DeviceActivity` - Activity monitoring and session management
  - `UserNotifications` - Break notifications

## Project Structure

```
OneLife/
├── ScreenTimeAPIDemo3/           # Main app target
│   ├── ContentView.swift         # Root view with TabView (Home, Apps, Schedule, Settings)
│   ├── FamilyControlModel.swift  # Core model for Family Controls authorization
│   ├── ScreenTimeAPIDemo3App.swift
│   ├── Managers/
│   │   ├── BlockingSessionManager.swift  # Manages blocking sessions
│   │   ├── ScheduleManager.swift         # Time-based schedule management with breaks
│   │   └── IntentionsManager.swift       # App intention management
│   ├── Models/
│   │   ├── AppIntention.swift    # Model for app usage intentions/limits
│   │   └── BlockSchedule.swift   # Model for time-based blocking schedules
│   ├── Shared/
│   │   └── AppGroupManager.swift # Cross-process data sharing via App Groups
│   └── Views/                    # SwiftUI views for various features
├── DeviceActivityMonitorExtension/  # Monitors sessions and re-applies shields
├── DeviceActivityReportExtension/   # Screen time reports
├── ShieldAction/                    # Handles shield button interactions
└── ShieldConfig/                    # Customizes shield appearance
```

## Key Concepts

### App Groups
- Suite name: `group.com.luminote.screentime`
- Used for sharing data between main app and extensions
- Uses Darwin notifications (`CFNotificationCenter`) for cross-process communication

### Token Identification
- `ApplicationToken` objects are identified using Base64-encoded `PropertyListEncoder` data
- This creates stable cross-process identifiers (hash values vary between processes)
- See `AppIntention.hashFromToken()` and `stableIdentifier(for:)` methods

### Shield Actions
- **Primary Button** ("Nevermind"): Closes shield, user stays focused
- **Secondary Button** ("Open App"): Removes shield temporarily, starts session timer

### Intentions
- Per-app limits: max opens per day, session duration
- Tracks current opens and streaks
- Daily counters reset automatically

### Schedules
- Time-based blocking (e.g., 10 PM - 7 AM)
- Supports overnight schedules that cross midnight
- Break system with configurable duration and notifications
- Per-schedule app exclusions

## Build & Run

Open `ScreenTimeAPIDemo3.xcodeproj` in Xcode. The app requires:
- iOS 15+ device (Simulator has limited Screen Time API support)
- Screen Time permission (requested on first launch)
- Notification permission (for break alerts)

## Extension Points

1. **DeviceActivityMonitorExtension**: Called when sessions start/end; re-applies shields when sessions expire
2. **ShieldActionExtension**: Handles user interactions with shield UI
3. **ShieldConfigurationExtension**: Customizes shield appearance per app
4. **DeviceActivityReportExtension**: Provides screen time usage reports

## Common Patterns

### Singleton Managers
All managers use the shared singleton pattern:
```swift
static let shared = ManagerName()
private init() { ... }
```

### Data Persistence
- Use `UserDefaults(suiteName:)` for App Group shared data
- Always call `synchronize()` after writes from extensions
- JSON encoding for complex types (intentions, schedules)
- PropertyList encoding for `FamilyActivitySelection`

### State Refresh
Main app refreshes data on:
- Scene phase changes (`.active`)
- `willEnterForegroundNotification`
- Darwin notification from extensions

## Debugging

- Shield action logs stored in shared UserDefaults (`shieldActionLogs` key)
- Access via Settings > Debug > Shield Action Logs
- Extensions use `os.log` with `.fault` level for Console visibility
