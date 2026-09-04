# Jarvis Shortcuts — Full iPad Control

These iOS Shortcuts are how Jarvis extends beyond its app sandbox to control everything on your iPad. Create each one in the Shortcuts app exactly as described.

## Required Shortcuts

### System Toggles
Each of these is a single-action shortcut:

| Shortcut Name | Action to Add |
|--------------|---------------|
| Toggle WiFi | Set Wi-Fi → Toggle |
| Toggle Bluetooth | Set Bluetooth → Toggle |
| Toggle Dark Mode | Set Appearance → Toggle |
| Toggle Low Power | Set Low Power Mode → Toggle |
| Toggle Do Not Disturb | Set Focus → Do Not Disturb → Toggle |
| Toggle Airplane Mode | Set Airplane Mode → Toggle |
| Record Screen | Start/Stop Screen Recording |

### App Launcher
**Name:** `Open App`
1. Add "Shortcut Input" → receive Text
2. Add "Open App" → set to Shortcut Input

### Timers & Alarms
**Name:** `Set Timer`
1. Shortcut Input → receive Text (the number of minutes)
2. Start Timer → Duration: Shortcut Input minutes

**Name:** `Set Alarm`
1. Shortcut Input → receive Text (time like "7:00 AM")
2. Create Alarm → Time: Shortcut Input

### Notes & Reminders
**Name:** `Create Note`
1. Shortcut Input → receive Text
2. Create Note → Body: Shortcut Input

**Name:** `Create Reminder`
1. Shortcut Input → receive Text
2. Add New Reminder → Title: Shortcut Input

**Name:** `Create Calendar Event`
1. Shortcut Input → receive Text
2. Add New Event → Title: Shortcut Input

### Media
**Name:** `Play Music`
1. Shortcut Input → receive Text (song/artist/playlist name)
2. Search Apple Music → query: Shortcut Input
3. Play Music

**Name:** `Play Playlist`
1. Shortcut Input → receive Text
2. Find Music → Playlist Name is Shortcut Input
3. Play Music

### Communication
**Name:** `Speak Text`
1. Shortcut Input → receive Text
2. Speak Text → Text: Shortcut Input

**Name:** `Send Email`
1. Shortcut Input → receive Text (format: "to|subject|body")
2. Split Text → by "|"
3. Send Email → To: item 1, Subject: item 2, Body: item 3

**Name:** `Make Call`
1. Shortcut Input → receive Text (phone number)
2. Call → Number: Shortcut Input

### System Info
**Name:** `Get Battery`
1. Get Battery Level
2. Show Result

**Name:** `Get IP Address`
1. Get Current IP Address
2. Show Result

### Advanced
**Name:** `Run JavaScript`
1. Shortcut Input → receive Text
2. Run JavaScript on Web Page → Script: Shortcut Input
(Useful for web automation)

**Name:** `Open URL In Safari`
1. Shortcut Input → receive Text (URL)
2. Open URLs → URL: Shortcut Input

## Custom Shortcuts

You can create ANY shortcut and Jarvis can run it by name. Just tell Jarvis:
> "Run my Morning Routine shortcut"

Ideas for custom shortcuts:
- **Morning Routine**: Turn off DND → Set brightness to 80% → Open Weather → Speak today's forecast
- **Night Mode**: Set brightness to 20% → Enable DND → Toggle Dark Mode → Set timer for 8 hours
- **Work Mode**: Open Slack → Open Calendar → Enable DND → Set timer for 2 hours
- **Meeting Prep**: Open Zoom → Mute notifications → Set timer for meeting duration

## Setup Tips

1. Name shortcuts EXACTLY as shown — Jarvis matches by name
2. Test each shortcut manually before using with Jarvis
3. Enable "Allow Untrusted Shortcuts" in Settings → Shortcuts if needed
4. Grant all permissions when prompted (contacts, calendar, etc.)

## The Jarvis Keyboard

For Jarvis to type directly into any app's text fields, you also need to enable the Jarvis Keyboard:

1. Go to Settings → General → Keyboard → Keyboards → Add New Keyboard
2. Select "Jarvis" from the list
3. Tap on "Jarvis" and enable "Allow Full Access"
4. When you want Jarvis to type something, switch to the Jarvis keyboard (globe icon)

With the Jarvis Keyboard active, Jarvis types character-by-character directly into whatever text field is focused — Notes, Safari, Messages, any app.
