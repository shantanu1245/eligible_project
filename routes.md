# Eligible CRM — Complete Routes & Navigation Guide

This document maps all routes, screens, modal interactions, and navigation transitions in the project to eliminate token-heavy codebase searches.

---

## 1. High-Level Navigation Flow

```mermaid
flowchart TD
    MAIN[main.dart: EligibleCRMApp] --> LOGIN[LoginScreen]
    
    subgraph "Login Options"
        LOGIN -- "Credentials or [👑 Admin]" --> DASH_ADMIN[DashboardScreen (Admin: Shantanu)]
        LOGIN -- "Credentials or [💼 Executive 1]" --> DASH_EXEC1[DashboardScreen (Exec: Amit)]
        LOGIN -- "Credentials or [💼 Executive 2]" --> DASH_EXEC2[DashboardScreen (Exec: Priya)]
    end

    subgraph "Navigation Shell (AppDrawer & BottomNav)"
        DASH_ADMIN & DASH_EXEC1 & DASH_EXEC2 --> SHELL[Shell Views]
        SHELL -- "Index 0" --> TAB_DASH[Dashboard Overview]
        SHELL -- "Index 1" --> TAB_LEADS[LeadsScreen (Role-Filtered)]
        SHELL -- "Index 2" --> TAB_FOLLOWUPS[FollowupsScreen]
        SHELL -- "Index 3" --> TAB_ANALYTICS[AnalyticsScreen]
        SHELL -- "Index 4" --> TAB_MORE[MoreScreen (Role-Gated)]
    end

    subgraph "Admin-Only Routes & Modals"
        TAB_DASH -- "Allot Leads Alert" --> ALLOT[LeadAllotmentScreen]
        TAB_LEADS -- "Allot Button in AppBar" --> ALLOT
        DRAWER[AppDrawer] -- "Lead Allotment Menu" --> ALLOT
        TAB_MORE -- "Lead Allotment Tile" --> ALLOT
        ALLOT -- "Tap Allot / Reassign" --> SHEET_ALLOT[Allotment BottomSheet]
        ALLOT -- "Bulk Allot Selected" --> SHEET_BULK[Bulk Allotment Sheet]
        DRAWER -- "Team Menu" --> TEAM[TeamScreen]
        DRAWER -- "Campaigns Menu" --> CAMPAIGNS[CampaignsScreen]
    end

    TAB_DASH & TAB_LEADS -- "LeadCard Click [push]" --> DETAIL[LeadDetailsScreen]
    DETAIL -- "Admin: Reassign Dropdown" --> REASSIGN[In-place Allotment]
    
    DRAWER & TAB_MORE -- "Tasks Click [push]" --> TASKS[TasksScreen]
    DRAWER & TAB_MORE -- "Logout [pushAndRemoveUntil]" --> LOGIN
```

---

## 2. Route Registry

| Screen / Destination | Source Location | Trigger / User Action | Navigation Method | Parameters / State | Role Restriction |
|---|---|---|---|---|---|
| **`LoginScreen`** | `lib/main.dart` | App startup (`home:`) | Initial route | None | Public |
| **`DashboardScreen`** | `login_screen.dart` | Sign In or Quick Demo Button | `Navigator.pushReplacement` | `user: UserModel` | Dynamic |
| **`AppDrawer`** | `dashboard_screen.dart` | Hamburger icon on AppBar | `Scaffold.of(context).openDrawer()` | `user, leads, callbacks` | Dynamic |
| **`LeadAllotmentScreen`** | Dashboard alert / Drawer / MoreScreen / LeadsScreen | "Allot Leads" button | `Navigator.push` | `leads, onLeadsUpdated` | **Admin Only** |
| **`LeadDetailsScreen`** | `widgets/lead_card.dart` | Tap on any `LeadCard` | `Navigator.push` | `lead, currentUser, onLeadUpdated` | Everyone (Admin has reassign dropdown) |
| **`Leads Tab (1)`** | `app_bottom_navigation.dart` / Drawer | Tap "Leads" | `setState(() => currentIndex = 1)` | Shows `visibleLeads` | Dynamic (Execs only see their allotted leads) |
| **`Follow-ups Tab (2)`**| `app_bottom_navigation.dart` / Drawer | Tap "Follow-ups" | `setState(() => currentIndex = 2)` | Tab switch | Everyone |
| **`Analytics Tab (3)`** | `app_bottom_navigation.dart` / Drawer | Tap "Analytics" | `setState(() => currentIndex = 3)` | Tab switch | Everyone |
| **`More Tab (4)`** | `app_bottom_navigation.dart` / Drawer | Tap "More" | `setState(() => currentIndex = 4)` | `user: widget.user` | Dynamic |
| **`CampaignsScreen`** | `more_screen.dart` or `app_drawer.dart` | Tap "Campaigns" | `Navigator.push` | MaterialPageRoute | **Admin Only** |
| **`TeamScreen`** | `more_screen.dart` or `app_drawer.dart` | Tap "Team" | `Navigator.push` | MaterialPageRoute | **Admin Only** |
| **`TasksScreen`** | `more_screen.dart` or `app_drawer.dart` | Tap "Tasks" | `Navigator.push` | MaterialPageRoute | Everyone |
| **`LoginScreen` (Logout)**| `more_screen.dart` or `app_drawer.dart` | Confirm logout | `Navigator.pushAndRemoveUntil` | Clears navigation stack | Everyone |

---

## 3. Modals, Sheets, and Dialog Triggers

| Modal / Dialog | Host Screen | Trigger Element | Dismiss Action |
|---|---|---|---|
| **Auto-Fill Credentials Dialog** | `screens/login_screen.dart` | "Tap to Fill ID & Password" action card | `Navigator.pop(context)` on role card tap or close icon |
| **Single Lead Allotment Sheet** | `screens/lead_allotment_screen.dart` | "Allot" / "Reassign" button on lead row | `Navigator.pop(context)` on executive selection |
| **Bulk Allotment Sheet** | `screens/lead_allotment_screen.dart` | "Allot (N)" button in AppBar | `Navigator.pop(context)` on executive selection |
| **Add Task Dialog** | `screens/tasks_screen.dart` | FloatingActionButton (`+ Add Task`) | `Navigator.pop(dialogContext)` |
| **Add Member Dialog** | `screens/team_screen.dart` | FloatingActionButton (`+ Add Member`) | `Navigator.pop(dialogContext)` |
| **Create Follow-up Sheet** | `screens/followups_screen.dart` | FloatingActionButton (`+`) | `Navigator.pop(context)` |
| **Logout Confirmation** | `screens/more_screen.dart` & `widgets/app_drawer.dart` | "Logout" button | `Navigator.pop(context)` or `pushAndRemoveUntil(LoginScreen)` |

---

## 4. Current Stub Routes (0-byte Files)

| File Path | Intended Purpose | Referencing Location | Current Behavior |
|---|---|---|---|
| `lib/screens/add_lead_screen.dart` | Form to create a new CRM lead | FAB on `lead_screen.dart` | Empty file. FAB currently has empty callback. |
| `lib/screens/notifications_screen.dart` | Notification center & history | Dashboard AppBar bell icon & MoreScreen tile | Empty file. Icon has empty `onPressed`. |
| `lib/screens/profile_screen.dart` | User profile & credentials edit | MoreScreen -> "Profile" tile | Empty file. Tile has empty `onTap`. |
| `lib/screens/integrations_screen.dart` | Meta / WhatsApp / Zapier configs | MoreScreen -> "Integrations" tiles | Empty file. Tile has empty `onTap`. |
