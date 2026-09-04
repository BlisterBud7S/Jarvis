# Jarvis - AI iPad Controller

An AI-powered assistant that can control your iPad through voice and text commands.
It can open apps, type text, navigate the UI, manage settings, and automate workflows.

## Architecture

```
┌─────────────────────────────────────────────┐
│              iPad (Jarvis App)               │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐ │
│  │  Chat   │  │ Screen   │  │  Action    │ │
│  │  UI     │──│ Capture  │──│  Executor  │ │
│  └─────────┘  └──────────┘  └────────────┘ │
│       │                          │          │
│  ┌─────────┐              ┌────────────┐   │
│  │ Voice   │              │ Shortcuts  │   │
│  │ Input   │              │ Bridge     │   │
│  └─────────┘              └────────────┘   │
│       │                          │          │
└───────┼──────────────────────────┼──────────┘
        │         HTTPS            │
        ▼                          ▼
┌─────────────────────────────────────────────┐
│            Jarvis Server (Node.js)          │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Claude  │  │ Action   │  │  Device    │ │
│  │ AI Core │──│ Planner  │──│  Registry  │ │
│  └─────────┘  └──────────┘  └────────────┘ │
└─────────────────────────────────────────────┘
```

## Components

### iPad App (SwiftUI)
- **Chat Interface** - Natural language input (text + voice)
- **Screen Capture** - Takes screenshots for AI to understand current state
- **Action Executor** - Executes planned actions on the device
- **Shortcuts Bridge** - Integrates with iOS Shortcuts for deep automation
- **Accessibility Engine** - Uses iOS accessibility APIs for UI interaction

### Server (Node.js + Claude API)
- **AI Core** - Uses Claude to understand commands and plan actions
- **Action Planner** - Breaks down complex commands into executable steps
- **Vision Analysis** - Analyzes screenshots to understand device state

## Capabilities

| Category | Actions |
|----------|---------|
| **Apps** | Open, close, switch between apps |
| **Text** | Type text, dictate, copy/paste |
| **Navigation** | Tap, swipe, scroll, go back/home |
| **Settings** | Toggle WiFi, Bluetooth, brightness, volume |
| **Media** | Play/pause music, take photos |
| **Communication** | Send messages, make calls, compose emails |
| **Automation** | Run Shortcuts, chain multiple actions |
| **Web** | Open URLs, search, bookmark |

## Setup

### 1. Server
```bash
cd Server
npm install
cp config/env.example .env
# Add your ANTHROPIC_API_KEY to .env
npm start
```

### 2. iPad App
Open `JarvisApp/Jarvis.xcodeproj` in Xcode, set your server URL in Settings, and run on your iPad.

### 3. Shortcuts
Import the shortcuts from the `Shortcuts/` folder to enable deep device control.

## Requirements
- iPad running iPadOS 17+
- Node.js 20+
- Claude API key (Anthropic)
