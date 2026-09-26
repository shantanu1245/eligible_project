# LeadFlow CRM — Complete Routes & Navigation Guide

This document maps all routes, screens, modal interactions, and navigation transitions in the project to eliminate token-heavy codebase searches.

---

## 1. High-Level Navigation Flow

```mermaid
flowchart TD
    MAIN[main.dart: LeadFlowCRM] --> LOGIN[LoginScreen]
    LOGIN -- "handleLogin() [pushReplacement]" --> DASH[DashboardScreen (Shell Controller)]

    subgraph "Bottom Navigation Bar (currentIndex)"
        DASH -- "Index 0" --> TAB_DASH[Dashboard Overview]
        DASH -- "Index 1" --> TAB_LEADS[LeadsScreen]
        DASH -- "Index 2" --> TAB_FOLLOWUPS[FollowupsScreen]
        DASH -- "Index 3" --> TAB_ANALYTICS[AnalyticsScreen]
        DASH -- "Index 4" --> TAB_MORE[MoreScreen]
    end

    TAB_DASH -- "LeadCard Click [push]" --> DETAIL[LeadDetailsScreen]
    TAB_LEADS -- "LeadCard Click [push]" --> DETAIL[LeadDetailsScreen]

    TAB_MORE -- "Campaigns item [push]" --> CAMPAIGNS[CampaignsScreen]
    TAB_MORE -- "Team item [push]" --> TEAM[TeamScreen]
    TAB_MORE -- "Tasks item [push]" --> TASKS[TasksScreen]
    TAB_MORE -- "Logout Dialog -> Confirm [pushAndRemoveUntil]" --> LOGIN

    subgraph "Modals & Action Dialogs"
        TASKS -- "FAB [showDialog]" --> DIALOG_TASK[Add Task Dialog]
        TEAM -- "FAB [showDialog]" --> DIALOG_MEMBER[Add Member Dialog]
        TAB_FOLLOWUPS -- "FAB [showModalBottomSheet]" --> SHEET_FOLLOWUP[Create Follow-up Sheet]
        TAB_MORE -- "Logout Button [showDialog]" --> DIALOG_LOGOUT[Confirm Logout Dialog]
    end

    subgraph "Pending / Stub Routes (0-byte files)"
        TAB_MORE -.-> STUB_PROFILE[profile_screen.dart]
        TAB_MORE -.-> STUB_NOTIF[notifications_screen.dart]
        TAB_MORE -.-> STUB_INTEG[integrations_screen.dart]
        TAB_LEADS -.-> STUB_ADDLEAD[add_lead_screen.dart]
    end
```

---

## 2. Route Registry

| Screen / Destination | Source Location | Trigger / User Action | Navigation Method | Parameters / State |
|---|---|---|---|---|
| **`LoginScreen`** | `lib/main.dart` | App startup (`home:`) | Initial route | None |
| **`DashboardScreen`** | `login_screen.dart` | "Sign In" button click | `Navigator.pushReplacement` | MaterialPageRoute |
| **`Dashboard Tab (0)`** | `app_bottom_navigation.dart` | Tap "Home" icon | `setState(() => currentIndex = 0)` | Tab switch |
| **`Leads Tab (1)`** | `app_bottom_navigation.dart` | Tap "Leads" icon | `setState(() => currentIndex = 1)` | Passes `leads: leads` list |
| **`Follow-ups Tab (2)`**| `app_bottom_navigation.dart` | Tap "Follow-ups" icon | `setState(() => currentIndex = 2)` | Tab switch |
| **`Analytics Tab (3)`** | `app_bottom_navigation.dart` | Tap "Analytics" icon | `setState(() => currentIndex = 3)` | Tab switch |
| **`More Tab (4)`** | `app_bottom_navigation.dart` / Dashboard avatar | Tap "More" icon or user avatar | `setState(() => currentIndex = 4)` | Tab switch |
| **`LeadDetailsScreen`** | `widgets/lead_card.dart` | Tap on any `LeadCard` | `Navigator.push` | `lead: Lead` object |
| **`CampaignsScreen`** | `more_screen.dart` | Tap "Campaigns" tile | `Navigator.push` | MaterialPageRoute |
| **`TeamScreen`** | `more_screen.dart` | Tap "Team" tile | `Navigator.push` | MaterialPageRoute |
| **`TasksScreen`** | `more_screen.dart` | Tap "Tasks" tile | `Navigator.push` | MaterialPageRoute |
| **`LoginScreen` (Logout)**| `more_screen.dart` | Confirm dialog logout | `Navigator.pushAndRemoveUntil` | Clears navigation stack |

---

## 3. Modals, Sheets, and Dialog Triggers

| Modal / Dialog | Host Screen | Trigger Element | Dismiss Action |
|---|---|---|---|
| **Add Task Dialog** | `lib/screens/tasks_screen.dart` | FloatingActionButton (`+ Add Task`) | `Navigator.pop(dialogContext)` on Cancel or "Add Task" |
| **Add Member Dialog** | `lib/screens/team_screen.dart` | FloatingActionButton (`+ Add Member`) | `Navigator.pop(dialogContext)` on Cancel or "Add Member" |
| **Create Follow-up Sheet** | `lib/screens/followups_screen.dart` | FloatingActionButton (`+`) | `Navigator.pop(context)` on "Create Follow-up" button |
| **Logout Confirmation** | `lib/screens/more_screen.dart` | "Logout" outlined button | `Navigator.pop(context)` (Cancel) or `pushAndRemoveUntil(LoginScreen)` |

---

## 4. Current Stub Routes (Not Yet Wired)

The following files exist in `lib/screens/` as **0-byte stub files** and do not currently have active navigation handlers:

| File Path | Intended Purpose | Referencing Location | Current Behavior |
|---|---|---|---|
| `lib/screens/add_lead_screen.dart` | Form to create a new CRM lead | Planned from `lead_screen.dart` | Empty file. No FAB/button wired yet. |
| `lib/screens/notifications_screen.dart` | Notification center & history | Dashboard AppBar bell icon & MoreScreen tile | Bell icon has empty `onPressed: () {}`. |
| `lib/screens/profile_screen.dart` | User profile & credentials edit | MoreScreen -> "Profile" tile | Tile has empty `onTap: () {}`. |
| `lib/screens/integrations_screen.dart` | Meta / WhatsApp / Zapier configs | MoreScreen -> "Integrations" tiles | Tiles have empty `onTap: () {}`. |

---

## 5. Recommended GoRouter Route Spec (For Future Implementation)

When migrating to declarative routing, use the following schema:

```dart
// Suggested GoRouter configuration
final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    ShellRoute(
      builder: (c, s, child) => DashboardShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (c, s) => const DashboardView()),
        GoRoute(path: '/leads', builder: (c, s) => const LeadsScreen()),
        GoRoute(path: '/followups', builder: (c, s) => const FollowupsScreen()),
        GoRoute(path: '/analytics', builder: (c, s) => const AnalyticsScreen()),
        GoRoute(path: '/more', builder: (c, s) => const MoreScreen()),
      ],
    ),
    GoRoute(
      path: '/lead-detail/:id',
      builder: (c, s) => LeadDetailsScreen(leadId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/campaigns', builder: (c, s) => const CampaignsScreen()),
    GoRoute(path: '/team', builder: (c, s) => const TeamScreen()),
    GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen()),
  ],
);
```
