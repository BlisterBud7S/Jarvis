# JARVIS — AI That Controls Your iPad

Like Iron Man's Jarvis. You talk, it acts. Full autonomous control over your iPad.

## What Jarvis Can Do

**Everything.** Here's a taste:

| You say | Jarvis does |
|---------|------------|
| "Open Instagram" | Opens Instagram instantly |
| "Text Mom I'll be late" | Opens Messages, fills in recipient and text |
| "Search YouTube for how to make pasta" | Opens YouTube with search results |
| "Turn on dark mode and lower brightness to 30%" | Toggles dark mode, sets brightness |
| "Play some chill music on Spotify" | Opens Spotify, searches for chill music |
| "Set a timer for 10 minutes" | Creates a 10-minute timer |
| "Send an email to john@email.com about the meeting" | Composes email with subject and body |
| "Create a reminder to buy groceries tomorrow" | Creates the reminder |
| "FaceTime Sarah" | Starts a FaceTime call |
| "Open WiFi settings" | Navigates directly to WiFi settings |
| "What's on my screen?" | Analyzes current screen and describes it |
| "Turn off Bluetooth, enable Do Not Disturb, and lower volume" | Chains all 3 actions in sequence |

## Architecture

```
You speak/type
      │
      ▼
┌─────────────────────────────────┐
│       iPad App (SwiftUI)        │
│                                 │
│  ┌───────┐  ┌───────────────┐  │
│  │ Voice │  │ Screen Capture│  │
│  │ Input │  │   (AI Vision) │  │
│  └───┬───┘  └───────┬───────┘  │
│      │              │          │
│      ▼              ▼          │
│  ┌──────────────────────────┐  │
│  │     Action Executor      │  │
│  │  60+ URL schemes         │  │
│  │  iOS Shortcuts bridge    │  │
│  │  System APIs             │  │
│  │  Media controls          │  │
│  └──────────────────────────┘  │
└──────────────┬──────────────────┘
               │ HTTPS
               ▼
┌─────────────────────────────────┐
│    Server (Node.js + Claude)    │
│                                 │
│  ┌──────────────────────────┐  │
│  │    Autonomous Agent      │  │
│  │                          │  │
│  │  SEE → THINK → ACT →    │  │
│  │  VERIFY → REPEAT         │  │
│  │                          │  │
│  │  Plans multi-step tasks  │  │
│  │  Analyzes screenshots    │  │
│  │  Chains complex actions  │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

## The Agent Loop

Jarvis doesn't just respond — it **thinks and acts autonomously**:

1. **SEE** — Captures your iPad screen (optional, for context)
2. **THINK** — Claude AI understands what you want and plans the steps
3. **ACT** — Executes actions: opens apps, types text, changes settings
4. **VERIFY** — Takes another screenshot to confirm the action worked
5. **REPEAT** — If the task isn't done, loops back to step 1

This means Jarvis can handle complex, multi-step tasks without you lifting a finger.

## 60+ Actions

### Apps (80+ apps via URL schemes)
Safari, YouTube, Instagram, WhatsApp, Spotify, Netflix, TikTok, Discord, Slack, Zoom, Chrome, Gmail, Notion, Reddit, Twitter/X, Telegram, Snapchat, Pinterest, LinkedIn, Facebook, Messenger, Uber, Amazon, PayPal, and every built-in Apple app.

### Communication
- Send iMessages, WhatsApp messages
- Compose and send emails
- Make phone calls, FaceTime (video + audio)

### Media
- Play/pause/skip music
- Control volume
- Take photos, record video
- Record screen

### Settings & System
- Brightness, volume
- WiFi, Bluetooth, Airplane Mode
- Dark Mode, Low Power Mode, Do Not Disturb
- Navigate to any Settings page
- Lock screen

### Productivity
- Create notes, reminders, calendar events
- Set timers, alarms, stopwatch
- Spotlight search

### Search
- Google, YouTube, Maps, App Store — opens results directly

### Shortcuts
- Run ANY iOS Shortcut by name — this extends Jarvis to literally anything

## Quick Start

### 1. Server Setup
```bash
cd Server
npm install
cp config/env.example .env
# Edit .env — add your ANTHROPIC_API_KEY
npm start
```

### 2. iPad App
Open `JarvisApp/` in Xcode, build & run on your iPad.
In Settings tab, enter your server URL and API key.

### 3. Shortcuts (for full control)
Create these shortcuts in the iOS Shortcuts app to unlock deep system control:
- **Toggle WiFi** / **Toggle Bluetooth** / **Toggle Dark Mode**
- **Toggle Low Power** / **Toggle Do Not Disturb** / **Toggle Airplane Mode**
- **Set Timer** / **Set Alarm** / **Open App**
- **Create Note** / **Create Reminder** / **Create Calendar Event**
- **Play Music** / **Speak Text** / **Record Screen**

See `Shortcuts/README.md` for step-by-step instructions.

## Tech Stack
- **iPad App**: Swift, SwiftUI, Speech framework, AVFoundation, MediaPlayer
- **Server**: Node.js, Express, Claude API (Anthropic)
- **AI**: Claude Sonnet for understanding + vision + action planning

## Requirements
- iPad running iPadOS 17+
- Mac with Xcode 15+ (to build the app)
- Node.js 20+
- Anthropic API key
