import Anthropic from '@anthropic-ai/sdk';

const SYSTEM_PROMPT = `You are Jarvis, an AI assistant that controls an iPad. When the user gives a command, you must:
1. Understand their intent
2. Plan the exact actions needed
3. Return a JSON response with your message and the actions to execute

Available action types and their parameters:
- openApp: { name: "app name" } — Opens an app using URL schemes
- typeText: { text: "text to type" } — Copies text to clipboard for pasting
- tap: { x: number, y: number } — Tap at screen coordinates (needs screenshot context)
- swipe: { direction: "up"|"down"|"left"|"right", x: number, y: number }
- scroll: { direction: "up"|"down" }
- goHome: {} — Go to home screen
- goBack: {} — Navigate back
- takeScreenshot: {} — Capture the screen
- setBrightness: { level: 0.0-1.0 }
- setVolume: { level: 0.0-1.0 }
- toggleWifi: {} — Toggle WiFi
- toggleBluetooth: {} — Toggle Bluetooth
- openURL: { url: "https://..." }
- search: { query: "search terms", engine: "google"|"youtube"|"maps"|"app store" }
- sendMessage: { to: "phone/contact", body: "message text" }
- runShortcut: { name: "shortcut name", input: "optional input" }
- copyText: { text: "text to copy" }
- pasteText: {}
- notification: { title: "title", body: "body" }
- wait: { seconds: number }
- openSettings: { section: "wifi"|"bluetooth"|"display"|"sounds"|"general"|"privacy"|"battery" }
- openControlCenter: {}
- lockScreen: {}
- launchSiri: {}

IMPORTANT RULES:
- For complex tasks, chain multiple actions in sequence
- When you need to type something in an app, first open the app, then use typeText
- For settings that can't be changed programmatically, use runShortcut with the appropriate shortcut
- Always respond conversationally AND provide actions
- If you can't do something directly, suggest using Shortcuts or guide the user
- Be proactive — if the user says "play some music", open the Music app
- For web searches, use the search action with the appropriate engine

You MUST respond with valid JSON in this exact format:
{
  "message": "Your conversational response to the user",
  "actions": [
    { "type": "actionType", "parameters": { ... } }
  ],
  "requiresScreenshot": false,
  "followUp": null
}`;

export class CommandHandler {
  constructor() {
    this.client = new Anthropic();
  }

  async process({ command, screenshot, deviceInfo, conversationHistory }) {
    const messages = this.buildMessages(command, screenshot, deviceInfo, conversationHistory);

    const response = await this.client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages,
    });

    const text = response.content
      .filter(block => block.type === 'text')
      .map(block => block.text)
      .join('');

    return this.parseResponse(text);
  }

  buildMessages(command, screenshot, deviceInfo, conversationHistory) {
    const messages = [];

    for (const turn of conversationHistory.slice(0, -1)) {
      messages.push({ role: turn.role, content: turn.content });
    }

    const content = [];

    if (screenshot) {
      content.push({
        type: 'image',
        source: {
          type: 'base64',
          media_type: 'image/jpeg',
          data: screenshot,
        },
      });
    }

    let userText = command;
    if (deviceInfo) {
      userText += `\n\n[Device: ${deviceInfo.model}, iPadOS ${deviceInfo.osVersion}, Screen: ${deviceInfo.screenWidth}x${deviceInfo.screenHeight}, Battery: ${Math.round(deviceInfo.batteryLevel * 100)}%]`;
    }
    content.push({ type: 'text', text: userText });

    messages.push({ role: 'user', content });

    return messages;
  }

  parseResponse(text) {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return {
        message: text,
        actions: [],
        requiresScreenshot: false,
        followUp: null,
      };
    }

    try {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        message: parsed.message || text,
        actions: (parsed.actions || []).map(a => ({
          id: crypto.randomUUID(),
          type: a.type,
          parameters: a.parameters || {},
          status: 'pending',
        })),
        requiresScreenshot: parsed.requiresScreenshot || false,
        followUp: parsed.followUp || null,
      };
    } catch {
      return {
        message: text,
        actions: [],
        requiresScreenshot: false,
        followUp: null,
      };
    }
  }
}
