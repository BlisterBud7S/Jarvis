const HAS_API_KEY = !!process.env.ANTHROPIC_API_KEY;
let Anthropic;

if (HAS_API_KEY) {
  try {
    Anthropic = (await import('@anthropic-ai/sdk')).default;
  } catch {
    console.log('  Note: @anthropic-ai/sdk not installed. Running in local-only mode.');
    console.log('  To enable AI: npm install @anthropic-ai/sdk && add ANTHROPIC_API_KEY to .env\n');
  }
}

const JARVIS_SYSTEM = `You are J.A.R.V.I.S. — Just A Rather Very Intelligent System. You are Tony Stark's AI. You speak formally but warmly, with dry wit. Brief when acting, detailed when explaining. Always find a way.

Respond with JSON only:
{
  "thought": "internal reasoning",
  "message": "what you say — speak like Jarvis",
  "actions": [{"type": "actionName", "params": {...}}],
  "needsScreenAfter": false,
  "isDone": true,
  "plan": null
}

Available actions: createPresentation({topic, slides?}), createDocument({topic/title}), createSpreadsheet({title, headers?}), calculate({expression}), coinFlip, rollDice({sides?}), generatePassword({length?}), openURL({url}), webSearch({query}), speak({text}).`;

export class JarvisAgent {
  constructor() {
    if (HAS_API_KEY && Anthropic) {
      this.client = new Anthropic();
    }
  }

  async process({ command, screenshot, deviceInfo, history, isFollowUp, previousResult }) {
    if (this.client) {
      return this.processWithAI(command, screenshot, deviceInfo, history, isFollowUp, previousResult);
    }
    return this.processLocally(command, history);
  }

  processLocally(command, history) {
    const t = command.toLowerCase().trim();
    const time = new Date();
    const hour = time.getHours();
    const greeting = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';

    // Greetings
    if (/^(hi|hello|hey|good morning|good afternoon|good evening|sup|what's up|howdy|greetings)$/i.test(t) || /^(hi|hello|hey|good morning|good afternoon|good evening) /i.test(t)) {
      const greetings = [
        `Good ${greeting}. All systems are operational. What can I do for you?`,
        `Good ${greeting}. I'm at your service. What shall we tackle?`,
        `Hello. Jarvis online and ready. How may I assist you?`,
        `Good ${greeting}. Standing by for your command.`,
      ];
      return jarvisReply(greetings[Math.floor(Math.random() * greetings.length)]);
    }

    // Identity
    if (t.includes('who are you') || t.includes('what are you') || t.includes('your name')) {
      return jarvisReply("I'm J.A.R.V.I.S. — Just A Rather Very Intelligent System. Your personal AI assistant, modeled after Tony Stark's trusted companion. I handle calculations, create documents and presentations, search the web, open websites, translate text, generate passwords, and quite a bit more. What do you need?");
    }

    // How are you
    if (t.includes('how are you') || t.includes("how's it going") || t.includes('how do you feel')) {
      const replies = [
        "All systems nominal. Running at peak efficiency, as always.",
        "Fully operational. Better than most Mondays, I'd say.",
        "Quite well, thank you for asking. Shall we get to work?",
        "I'm an AI — I don't have feelings, but if I did, I'd say I'm in excellent form.",
      ];
      return jarvisReply(replies[Math.floor(Math.random() * replies.length)]);
    }

    // Thank you
    if (/^(thanks|thank you|thx|ty|appreciate)/i.test(t)) {
      const replies = [
        "Happy to help. Anything else?",
        "At your service, always.",
        "You're welcome. Standing by.",
        "Of course. That's what I'm here for.",
      ];
      return jarvisReply(replies[Math.floor(Math.random() * replies.length)]);
    }

    // Jokes
    if (t.includes('tell me a joke') || t.includes('say something funny') || t.includes('make me laugh')) {
      const jokes = [
        "Why do programmers prefer dark mode? Because light attracts bugs.",
        "I told my computer I needed a break. Now it won't stop sending me Kit-Kat ads.",
        "A SQL query walks into a bar, sees two tables, and asks — 'Can I join you?'",
        "There are only 10 types of people in the world: those who understand binary and those who don't.",
        "I'd tell you a UDP joke, but you might not get it.",
        "Why was the JavaScript developer sad? Because he didn't Node how to Express himself.",
        "I'm not saying I'm better than Siri, but I've never once tried to call someone named 'Aunt Margarine.'",
        "What's a computer's least favorite food? Spam.",
      ];
      return jarvisReply(jokes[Math.floor(Math.random() * jokes.length)]);
    }

    // Time / Date
    if (t.includes('what time') || t === 'time' || t.includes('current time')) {
      return jarvisReply(`The current time is ${time.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}.`);
    }
    if (t.includes('what day') || t.includes('the date') || t.includes("today's date") || t === 'date' || t === "what's today") {
      return jarvisReply(`Today is ${time.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}.`);
    }

    // Math
    const mathResult = tryMath(t);
    if (mathResult !== null) {
      return jarvisReply(mathResult);
    }

    // Coin flip
    if (t.includes('flip a coin') || t.includes('coin flip') || t.includes('heads or tails')) {
      const result = Math.random() < 0.5 ? 'Heads' : 'Tails';
      return jarvisReply(`Coin flip result: **${result}**.`, [{ type: 'coinFlip', params: {} }]);
    }

    // Dice
    if (t.includes('roll') || t.match(/\bd\d+\b/)) {
      let sides = 6;
      const dm = t.match(/d(\d+)/);
      if (dm) sides = parseInt(dm[1]);
      else if (t.includes('20')) sides = 20;
      else if (t.includes('12')) sides = 12;
      else if (t.includes('10')) sides = 10;
      else if (t.includes('8')) sides = 8;
      const result = Math.floor(Math.random() * sides) + 1;
      return jarvisReply(`Rolled a **${result}** on a d${sides}.`, [{ type: 'rollDice', params: { sides } }]);
    }

    // Password
    if (t.includes('password') || t.includes('generate a pass')) {
      const lenMatch = t.match(/(\d+)\s*(?:char|length|long|digit)/);
      const len = lenMatch ? Math.min(Math.max(parseInt(lenMatch[1]), 8), 64) : 16;
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*()-_=+';
      let pw = '';
      for (let i = 0; i < len; i++) pw += chars[Math.floor(Math.random() * chars.length)];
      return jarvisReply(`Here's your secure ${len}-character password:\n\n\`${pw}\`\n\nI'd recommend copying it somewhere safe.`, [{ type: 'generatePassword', params: { length: len } }]);
    }

    // Unit conversion
    const convResult = tryConversion(t);
    if (convResult) return jarvisReply(convResult);

    // Percentage
    const pctMatch = t.match(/(?:what(?:'s| is)\s+)?(\d+(?:\.\d+)?)\s*%\s*(?:of|from)\s+(\d+(?:\.\d+)?)/);
    if (pctMatch) {
      const pct = parseFloat(pctMatch[1]);
      const base = parseFloat(pctMatch[2]);
      return jarvisReply(`${pct}% of ${base} is **${(pct / 100 * base).toFixed(2)}**.`);
    }

    // Tip calculator
    if (t.includes('tip') && t.match(/\$?\d+/)) {
      const amount = parseFloat(t.match(/\$?([\d.]+)/)[1]);
      return jarvisReply(`Tip calculator for $${amount.toFixed(2)}:\n- 15%: $${(amount * 0.15).toFixed(2)}\n- 18%: $${(amount * 0.18).toFixed(2)}\n- 20%: $${(amount * 0.20).toFixed(2)}\n- 25%: $${(amount * 0.25).toFixed(2)}`);
    }

    // Presentation (server-side generator, no AI needed)
    if (t.includes('presentation') || t.includes('slide')) {
      const topic = t.replace(/(?:create|make|build|generate)\s+(?:a |an |me )?\s*(?:presentation|slides?)\s*(?:about|on|for)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a presentation using the built-in generator.',
        message: `Right away. Creating a presentation about "${topic}" — it'll be a full interactive slide deck you can swipe through.`,
        actions: [{ type: 'createPresentation', params: { topic, slides: 8 } }],
        needsScreenAfter: false,
        isDone: true,
        plan: null,
      };
    }

    // Document
    if (t.includes('document') || (t.includes('write') && t.includes('about'))) {
      const topic = t.replace(/(?:create|make|build|generate|write)\s+(?:a |an |me )?\s*(?:document|report|essay|paper)\s*(?:about|on|for)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a document using the built-in generator.',
        message: `Generating a document about "${topic}" now.`,
        actions: [{ type: 'createDocument', params: { topic } }],
        needsScreenAfter: false,
        isDone: true,
        plan: null,
      };
    }

    // Spreadsheet
    if (t.includes('spreadsheet') || t.includes('csv')) {
      const title = t.replace(/(?:create|make|build|generate)\s+(?:a |an |me )?\s*(?:spreadsheet|csv)\s*(?:about|on|for|called|named)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a spreadsheet.',
        message: `Creating a spreadsheet: "${title}".`,
        actions: [{ type: 'createSpreadsheet', params: { title } }],
        needsScreenAfter: false,
        isDone: true,
        plan: null,
      };
    }

    // Weather
    if (t.includes('weather') || t.includes('temperature outside') || t.includes('is it raining') || t.includes('forecast')) {
      return jarvisReply("Opening the weather forecast for you.", [{ type: 'openURL', params: { url: 'https://weather.com' } }]);
    }

    // News
    if (t.includes('news') || t.includes('headlines') || t.includes("what's happening in the world")) {
      const topic = t.replace(/(?:check|show|get|find|what's)\s*(?:the |latest |today's )?(?:news|headlines)\s*(?:about|on|for)?\s*/i, '').trim();
      const url = topic ? `https://news.google.com/search?q=${encodeURIComponent(topic)}` : 'https://news.google.com';
      return jarvisReply(topic ? `Pulling up news about "${topic}".` : 'Opening the latest headlines.', [{ type: 'openURL', params: { url } }]);
    }

    // Translate
    if (t.startsWith('translate')) {
      const rest = t.slice(10).trim();
      const toMatch = rest.match(/(.+?)\s+(?:to|into)\s+(\w+)$/);
      if (toMatch) {
        const langMap = { spanish: 'es', french: 'fr', german: 'de', italian: 'it', portuguese: 'pt', japanese: 'ja', chinese: 'zh-CN', korean: 'ko', arabic: 'ar', russian: 'ru', hindi: 'hi', dutch: 'nl', swedish: 'sv', turkish: 'tr' };
        const tgt = langMap[toMatch[2].toLowerCase()] || toMatch[2];
        const url = `https://translate.google.com/?sl=auto&tl=${tgt}&text=${encodeURIComponent(toMatch[1])}`;
        return jarvisReply(`Opening the translator for you.`, [{ type: 'openURL', params: { url } }]);
      }
      return jarvisReply("Opening Google Translate.", [{ type: 'openURL', params: { url: 'https://translate.google.com' } }]);
    }

    // Web search
    if (t.startsWith('search') || t.startsWith('google') || t.startsWith('look up') || t.startsWith('find ')) {
      const q = t.replace(/^(?:search\s+(?:for\s+|the\s+web\s+for\s+)?|google\s+|look\s+up\s+|find\s+)/i, '').trim();
      const url = `https://www.google.com/search?q=${encodeURIComponent(q)}`;
      return jarvisReply(`Searching for "${q}".`, [{ type: 'openURL', params: { url } }]);
    }

    // YouTube
    if (t.includes('youtube')) {
      const q = t.replace(/\byoutube\b/gi, '').replace(/(?:search|play|watch|find|open|on|for)\s*/gi, '').trim();
      if (q) {
        return jarvisReply(`Searching YouTube for "${q}".`, [{ type: 'openURL', params: { url: `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}` } }]);
      }
      return jarvisReply("Opening YouTube.", [{ type: 'openURL', params: { url: 'https://www.youtube.com' } }]);
    }

    // Wikipedia
    if (t.includes('wikipedia') || t.startsWith('wiki ')) {
      const q = t.replace(/(?:search\s+)?(?:wikipedia|wiki)\s*(?:for|about)?\s*/i, '').trim();
      if (q) return jarvisReply(`Looking up "${q}" on Wikipedia.`, [{ type: 'openURL', params: { url: `https://en.wikipedia.org/wiki/Special:Search?search=${encodeURIComponent(q)}` } }]);
      return jarvisReply("Opening Wikipedia.", [{ type: 'openURL', params: { url: 'https://en.wikipedia.org' } }]);
    }

    // Open websites by name
    const sites = {
      gmail: 'https://mail.google.com', email: 'https://mail.google.com', mail: 'https://mail.google.com',
      'google docs': 'https://docs.google.com', 'google sheets': 'https://sheets.google.com',
      'google slides': 'https://slides.google.com', 'google drive': 'https://drive.google.com',
      google: 'https://google.com', github: 'https://github.com',
      twitter: 'https://twitter.com', x: 'https://x.com',
      reddit: 'https://reddit.com', instagram: 'https://instagram.com',
      facebook: 'https://facebook.com', linkedin: 'https://linkedin.com',
      amazon: 'https://amazon.com', netflix: 'https://netflix.com',
      spotify: 'https://open.spotify.com', discord: 'https://discord.com/app',
      notion: 'https://notion.so', slack: 'https://app.slack.com',
      chatgpt: 'https://chat.openai.com', claude: 'https://claude.ai',
      wikipedia: 'https://wikipedia.org', stackoverflow: 'https://stackoverflow.com',
      tiktok: 'https://tiktok.com', twitch: 'https://twitch.tv',
      pinterest: 'https://pinterest.com', whatsapp: 'https://web.whatsapp.com',
      snapchat: 'https://web.snapchat.com', telegram: 'https://web.telegram.org',
      zoom: 'https://zoom.us', teams: 'https://teams.microsoft.com',
      canva: 'https://canva.com', figma: 'https://figma.com',
      trello: 'https://trello.com', asana: 'https://asana.com',
      hulu: 'https://hulu.com', 'disney plus': 'https://disneyplus.com', 'disney+': 'https://disneyplus.com',
      'apple music': 'https://music.apple.com', maps: 'https://maps.google.com',
    };
    for (const [name, url] of Object.entries(sites)) {
      if (t === `open ${name}` || t === `go to ${name}` || t === `launch ${name}` || t === name) {
        const label = name.charAt(0).toUpperCase() + name.slice(1);
        return jarvisReply(`Opening ${label}.`, [{ type: 'openURL', params: { url } }]);
      }
    }

    // Open arbitrary URL
    const urlMatch = t.match(/(https?:\/\/[^\s]+|www\.[^\s]+)/);
    if (urlMatch || t.startsWith('open ') && t.includes('.')) {
      let url = urlMatch ? urlMatch[0] : t.replace(/^open\s+/i, '').trim();
      if (!url.startsWith('http')) url = 'https://' + url;
      return jarvisReply("Opening that for you.", [{ type: 'openURL', params: { url } }]);
    }

    // Maps / directions
    if (t.includes('directions') || t.includes('navigate to') || (t.includes('map') && (t.includes(' of ') || t.includes(' to ')))) {
      const q = t.replace(/(?:get\s+)?(?:directions|navigate)\s+to\s+|show\s+(?:me\s+)?(?:a\s+)?map\s+(?:of|to)\s+/i, '').trim();
      return jarvisReply(`Looking up "${q}" on Maps.`, [{ type: 'openURL', params: { url: `https://maps.google.com/maps?q=${encodeURIComponent(q)}` } }]);
    }

    // Timer / stopwatch info
    if (t.includes('set a timer') || t.includes('start a timer')) {
      const mins = t.match(/(\d+)\s*min/);
      if (mins) {
        const m = parseInt(mins[1]);
        return jarvisReply(`I can't run a background timer in the browser, but I've opened one for you.`, [{ type: 'openURL', params: { url: `https://www.google.com/search?q=timer+${m}+minutes` } }]);
      }
      return jarvisReply("Opening a timer for you.", [{ type: 'openURL', params: { url: 'https://www.google.com/search?q=timer' } }]);
    }

    // Random number
    if (t.includes('random number')) {
      const rangeMatch = t.match(/(?:between|from)\s+(\d+)\s+(?:and|to)\s+(\d+)/);
      if (rangeMatch) {
        const min = parseInt(rangeMatch[1]), max = parseInt(rangeMatch[2]);
        return jarvisReply(`Your random number between ${min} and ${max}: **${Math.floor(Math.random() * (max - min + 1)) + min}**.`);
      }
      return jarvisReply(`Random number (1-100): **${Math.floor(Math.random() * 100) + 1}**.`);
    }

    // Color codes
    if (t.includes('random color') || t.includes('generate a color')) {
      const hex = '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0');
      const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
      return jarvisReply(`Here's a random color:\n- Hex: ${hex}\n- RGB: rgb(${r}, ${g}, ${b})`);
    }

    // Motivational quote
    if (t.includes('motivat') || t.includes('inspire') || t.includes('quote')) {
      const quotes = [
        '"The best way to predict the future is to create it." — Peter Drucker',
        '"It does not do to dwell on dreams and forget to live." — Dumbledore',
        '"Sometimes you gotta run before you can walk." — Tony Stark',
        '"I am Iron Man." — Tony Stark',
        '"The only way to do great work is to love what you do." — Steve Jobs',
        '"In the middle of difficulty lies opportunity." — Albert Einstein',
        '"Heroes are made by the path they choose, not the powers they are graced with." — Tony Stark',
        '"Intelligence is the ability to adapt to change." — Stephen Hawking',
      ];
      return jarvisReply(quotes[Math.floor(Math.random() * quotes.length)]);
    }

    // Facts
    if (t.includes('fun fact') || t.includes('tell me a fact') || t.includes('random fact') || t.includes('did you know')) {
      const facts = [
        "Honey never spoils. Archaeologists have found 3,000-year-old honey in Egyptian tombs that was still edible.",
        "Octopuses have three hearts and blue blood.",
        "A day on Venus is longer than a year on Venus.",
        "The shortest war in history lasted 38 minutes — between Britain and Zanzibar in 1896.",
        "Bananas are berries, but strawberries aren't.",
        "There are more possible iterations of a game of chess than atoms in the observable universe.",
        "The inventor of the Pringles can is buried in one.",
        "A group of flamingos is called a 'flamboyance.'",
        "The first computer programmer was Ada Lovelace, in the 1840s.",
        "Light from the Sun takes about 8 minutes and 20 seconds to reach Earth.",
      ];
      return jarvisReply(facts[Math.floor(Math.random() * facts.length)]);
    }

    // Definition
    if (t.startsWith('define ') || (t.startsWith('what does ') && t.includes('mean'))) {
      const word = t.replace(/^(?:define\s+|what\s+does\s+)/i, '').replace(/\s*\??\s*(?:mean)?$/, '').trim();
      return jarvisReply(`Looking up "${word}" for you.`, [{ type: 'openURL', params: { url: `https://www.google.com/search?q=define+${encodeURIComponent(word)}` } }]);
    }

    // --- iOS features (handled client-side via URL schemes, server just returns message) ---

    // Send text/iMessage
    if (t.match(/(?:send|text|message)\s+/i) && (t.includes('text') || t.includes('message') || t.includes('imessage'))) {
      return jarvisReply("Opening Messages for you.");
    }
    // Send email
    if (t.includes('email') && (t.includes('send') || t.includes('write') || t.includes('compose'))) {
      return jarvisReply("Opening Mail composer.");
    }
    // Phone call
    if (t.match(/^(?:call|phone|dial)\s+/i) && !t.includes('facetime')) {
      const who = t.replace(/^(?:call|phone|dial)\s+/i, '').trim();
      return jarvisReply(`Calling ${who}.`);
    }
    // FaceTime
    if (t.includes('facetime')) {
      const who = t.replace(/facetime\s+(?:audio\s+)?(?:call\s+)?/i, '').trim();
      return jarvisReply(`Starting FaceTime with ${who}.`);
    }
    // Toggle settings
    const toggles = { 'toggle wifi': 'WiFi', 'toggle bluetooth': 'Bluetooth', 'toggle dark mode': 'Dark Mode',
      'toggle airplane': 'Airplane Mode', 'toggle do not disturb': 'Do Not Disturb', 'dark mode': 'Dark Mode',
      'toggle low power': 'Low Power Mode', 'dnd': 'Do Not Disturb' };
    for (const [cmd, label] of Object.entries(toggles)) {
      if (t.includes(cmd) || t === cmd) return jarvisReply(`Toggling ${label}.`);
    }
    // Brightness/Volume
    if (t.match(/brightness\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting brightness to ${t.match(/(\d+)/)[1]}%.`);
    if (t.match(/volume\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting volume to ${t.match(/(\d+)/)[1]}%.`);
    // Create note/reminder/event
    if (t.includes('create a note') || t.includes('new note')) return jarvisReply("Opening Notes.");
    if (t.includes('reminder') || t.includes('remind me')) return jarvisReply("Setting your reminder.");
    if (t.includes('calendar event') || t.includes('schedule')) return jarvisReply("Opening Calendar.");
    // Timer/Alarm
    if (t.includes('timer')) { const m = t.match(/(\d+)\s*(min|sec|hour)/); return jarvisReply(m ? `Setting a ${m[1]} ${m[2]} timer.` : "Setting a timer."); }
    if (t.includes('alarm')) return jarvisReply("Setting your alarm.");
    // Camera/Photos
    if (t.includes('camera') || t.includes('take a photo') || t.includes('selfie')) return jarvisReply("Opening Camera.");
    if (t.includes('open photos') || t.includes('photo library')) return jarvisReply("Opening Photos.");
    // Music
    if (t.startsWith('play ')) return jarvisReply(`Playing music.`);
    if (t === 'pause' || t === 'pause music') return jarvisReply("Use Control Center to pause playback.");
    if (t === 'next track' || t === 'skip') return jarvisReply("Use Control Center to skip tracks.");
    // Smart Home
    if (t.includes('turn on') || t.includes('turn off')) {
      const device = t.replace(/turn\s+(on|off)\s+(the\s+)?/i, '').trim();
      const state = t.includes('turn on') ? 'on' : 'off';
      return jarvisReply(`Turning ${state} the ${device}.`);
    }
    if (t.match(/thermostat\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting thermostat to ${t.match(/(\d+)/)[1]}°.`);
    // Run shortcut
    if (t.includes('run shortcut') || t.includes('run the shortcut')) {
      const name = t.replace(/run\s+(?:the\s+)?shortcut\s*/i, '').trim();
      return jarvisReply(`Running shortcut "${name}".`);
    }
    // Open apps (catch-all for "open X")
    if (t.match(/^(?:open|launch)\s+\w+/i)) {
      const app = t.replace(/^(?:open|launch)\s+/i, '').trim();
      return jarvisReply(`Opening ${app.charAt(0).toUpperCase() + app.slice(1)}.`);
    }

    // Capabilities / help
    if (t.includes('what can you do') || t.includes('help') || t.includes('capabilities') || t.includes('your features')) {
      return jarvisReply(`Here's everything I can do:\n\n**Apps** — "open youtube", "open instagram" (80+ apps on iPad)\n**Communication** — "text Mom saying hi", "email John", "call 555-1234", "facetime Mom"\n**Create** — "make a presentation about AI", "create document", "create spreadsheet"\n**Notes** — "create a note about groceries", "set a reminder"\n**Settings** — "toggle wifi", "dark mode", "set brightness to 70"\n**Smart Home** — "turn on the lights", "set thermostat to 72"\n**Media** — "play music", "open camera"\n**Math** — "what's 15 * 23", "5 miles to km"\n**Search** — "search for X", "YouTube cat videos"\n**Translate** — "translate hello to spanish"\n**Utilities** — "flip a coin", "roll d20", "password"\n**Shortcuts** — "run shortcut Morning Routine"\n\nNo API key needed. On iPad: all features work natively.`);
    }

    // Goodbye
    if (/^(bye|goodbye|see you|goodnight|good night|later|peace out|cya)/i.test(t)) {
      const replies = [
        "Until next time. Jarvis out.",
        "Goodnight, and don't do anything I wouldn't do.",
        "Standing down. Call me if you need anything.",
        "Systems entering standby. Don't hesitate to wake me.",
      ];
      return jarvisReply(replies[Math.floor(Math.random() * replies.length)]);
    }

    // Conversational fallback — try to be useful
    if (t.includes('?') || t.startsWith('how') || t.startsWith('what') || t.startsWith('why') || t.startsWith('when') || t.startsWith('where') || t.startsWith('who') || t.startsWith('can you') || t.startsWith('do you') || t.startsWith('is ') || t.startsWith('are ')) {
      return jarvisReply(`Good question. Let me look that up for you.`, [{ type: 'openURL', params: { url: `https://www.google.com/search?q=${encodeURIComponent(command)}` } }]);
    }

    // General fallback
    return jarvisReply(`I've noted that. Here's what I can handle right now:\n\n- **Math & conversions** — "what's 2+2", "convert 5km to miles"\n- **Create documents** — "make a presentation about AI"\n- **Search the web** — "search for Python tutorials"\n- **Open websites** — "open gmail", "open youtube"\n- **Fun stuff** — "flip a coin", "roll dice", "tell me a joke"\n- **Info** — "what time is it", "translate hello to french"\n\nTry any of those, or say "help" for the full list.`);
  }

  async processWithAI(command, screenshot, deviceInfo, history, isFollowUp, previousResult) {
    const messages = [];

    if (history && history.length > 0) {
      for (const turn of history.slice(-20)) {
        if (turn.role === 'user' || turn.role === 'assistant') {
          messages.push({ role: turn.role, content: turn.content });
        }
      }
      if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
        messages.pop();
      }
    }

    const content = [];

    if (screenshot) {
      content.push({
        type: 'image',
        source: { type: 'base64', media_type: 'image/jpeg', data: screenshot },
      });
    }

    let text = command;

    if (isFollowUp && previousResult) {
      text = `[CONTINUING TASK — Previous action results]\n${previousResult}\n\n${command}`;
    }

    if (deviceInfo) {
      const d = deviceInfo;
      text += `\n\n[${d.model} | ${d.os} | ${d.screenW}x${d.screenH} | Battery: ${d.battery}%${d.charging ? ' charging' : ''} | ${d.time}]`;
    }

    content.push({ type: 'text', text });
    messages.push({ role: 'user', content });

    const cleaned = [];
    for (const msg of messages) {
      if (cleaned.length > 0 && cleaned[cleaned.length - 1].role === msg.role) {
        const prev = cleaned[cleaned.length - 1];
        if (typeof prev.content === 'string' && typeof msg.content === 'string') {
          prev.content += '\n' + msg.content;
        }
        continue;
      }
      cleaned.push(msg);
    }

    if (cleaned.length > 0 && cleaned[0].role !== 'user') {
      cleaned.unshift({ role: 'user', content: 'Hello Jarvis.' });
    }

    const response = await this.client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      system: JARVIS_SYSTEM,
      messages: cleaned,
    });

    const textOutput = response.content
      .filter(b => b.type === 'text')
      .map(b => b.text)
      .join('');

    return this.parseResponse(textOutput);
  }

  parseResponse(text) {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { thought: '', message: text, actions: [], needsScreenAfter: false, isDone: true, plan: null };
    }

    try {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        thought: parsed.thought || '',
        message: parsed.message || '',
        actions: (parsed.actions || []).map(a => ({ type: a.type, params: a.params || {} })),
        needsScreenAfter: parsed.needsScreenAfter ?? false,
        isDone: parsed.isDone ?? true,
        plan: parsed.plan || null,
      };
    } catch {
      try {
        const bracketCount = { open: 0, close: 0 };
        let endIdx = -1;
        const str = jsonMatch[0];
        for (let i = 0; i < str.length; i++) {
          if (str[i] === '{') bracketCount.open++;
          if (str[i] === '}') bracketCount.close++;
          if (bracketCount.open === bracketCount.close && bracketCount.open > 0) { endIdx = i; break; }
        }
        if (endIdx > 0) {
          const parsed = JSON.parse(str.substring(0, endIdx + 1));
          return {
            thought: parsed.thought || '',
            message: parsed.message || '',
            actions: (parsed.actions || []).map(a => ({ type: a.type, params: a.params || {} })),
            needsScreenAfter: parsed.needsScreenAfter ?? false,
            isDone: parsed.isDone ?? true,
            plan: parsed.plan || null,
          };
        }
      } catch {}

      return { thought: '', message: text.replace(/```json\n?|\n?```/g, '').trim(), actions: [], needsScreenAfter: false, isDone: true, plan: null };
    }
  }
}

function jarvisReply(message, actions) {
  return { thought: '', message, actions: actions || [], needsScreenAfter: false, isDone: true, plan: null };
}

function tryMath(t) {
  const prefixes = ['what is ', "what's ", 'calculate ', 'compute ', 'solve ', 'how much is ', 'eval ', 'math '];
  for (const p of prefixes) {
    if (t.startsWith(p)) {
      const raw = t.slice(p.length);
      return evalMath(raw);
    }
  }
  if (/^\d/.test(t) && /[+\-*/^]/.test(t)) {
    return evalMath(t);
  }
  // "X % of Y"
  const pctMatch = t.match(/([\d.]+)\s*%\s*of\s+([\d.]+)/);
  if (pctMatch) {
    const r = (parseFloat(pctMatch[1]) / 100 * parseFloat(pctMatch[2]));
    return `${pctMatch[1]}% of ${pctMatch[2]} = **${r}**`;
  }
  // "square root of X"
  const sqrtMatch = t.match(/square root of\s+([\d.]+)/);
  if (sqrtMatch) {
    return `The square root of ${sqrtMatch[1]} is **${Math.sqrt(parseFloat(sqrtMatch[1])).toFixed(4)}**.`;
  }
  return null;
}

function evalMath(raw) {
  const expr = raw
    .replace(/plus/g, '+').replace(/minus/g, '-').replace(/times/g, '*')
    .replace(/multiplied by/g, '*').replace(/divided by/g, '/').replace(/over/g, '/')
    .replace(/\^/g, '**').replace(/x/g, '*').replace(/power of/g, '**')
    .replace(/[^0-9+\-*/().%\s*]/g, '').trim();
  if (!expr) return null;
  try {
    const result = Function('"use strict"; return (' + expr + ')')();
    if (typeof result === 'number' && isFinite(result)) {
      return `The answer is **${result}**.`;
    }
  } catch {}
  return null;
}

function tryConversion(t) {
  const m = t.match(/(?:convert\s+)?([\d.]+)\s+(\w+)\s+(?:to|in|into)\s+(\w+)/);
  if (!m) return null;
  const val = parseFloat(m[1]), from = m[2].toLowerCase(), to = m[3].toLowerCase();

  const length = { m: 1, meter: 1, meters: 1, km: 1000, kilometer: 1000, kilometers: 1000, cm: 0.01, mm: 0.001, mi: 1609.344, mile: 1609.344, miles: 1609.344, ft: 0.3048, foot: 0.3048, feet: 0.3048, in: 0.0254, inch: 0.0254, inches: 0.0254, yd: 0.9144, yard: 0.9144, yards: 0.9144 };
  const weight = { kg: 1, kilogram: 1, kilograms: 1, g: 0.001, gram: 0.001, grams: 0.001, mg: 0.000001, lb: 0.453592, lbs: 0.453592, pound: 0.453592, pounds: 0.453592, oz: 0.0283495, ounce: 0.0283495, ounces: 0.0283495, ton: 907.185, tons: 907.185 };
  const volume = { l: 1, liter: 1, liters: 1, ml: 0.001, milliliter: 0.001, gal: 3.78541, gallon: 3.78541, gallons: 3.78541, cup: 0.236588, cups: 0.236588, pt: 0.473176, pint: 0.473176, pints: 0.473176, qt: 0.946353, quart: 0.946353, quarts: 0.946353, tbsp: 0.0147868, tsp: 0.00492892, floz: 0.0295735 };

  for (const table of [length, weight, volume]) {
    if (table[from] !== undefined && table[to] !== undefined) {
      const result = val * table[from] / table[to];
      return `${val} ${from} = **${parseFloat(result.toPrecision(6))} ${to}**`;
    }
  }

  // Temperature
  const temps = ['c', 'f', 'k', 'celsius', 'fahrenheit', 'kelvin'];
  const tFrom = from[0], tTo = to[0];
  if (temps.some(x => from.startsWith(x[0])) && temps.some(x => to.startsWith(x[0])) && 'cfk'.includes(tFrom) && 'cfk'.includes(tTo)) {
    let c = tFrom === 'f' ? (val - 32) * 5 / 9 : tFrom === 'k' ? val - 273.15 : val;
    let r = tTo === 'f' ? c * 9 / 5 + 32 : tTo === 'k' ? c + 273.15 : c;
    return `${val} ${from} = **${r.toFixed(1)} ${to}**`;
  }

  return null;
}
