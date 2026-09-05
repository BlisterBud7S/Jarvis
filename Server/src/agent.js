import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MEMORY_FILE = path.join(__dirname, '..', 'data', 'memory.json');
const DATA_DIR = path.join(__dirname, '..', 'data');

// Ensure data dir exists
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

// Optional Anthropic SDK
const HAS_API_KEY = !!process.env.ANTHROPIC_API_KEY;
let Anthropic;
if (HAS_API_KEY) {
  try { Anthropic = (await import('@anthropic-ai/sdk')).default; } catch {}
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
    if (HAS_API_KEY && Anthropic) this.client = new Anthropic();
    this.memory = this.loadMemory();
  }

  // === MEMORY ===
  loadMemory() {
    try {
      if (fs.existsSync(MEMORY_FILE)) return JSON.parse(fs.readFileSync(MEMORY_FILE, 'utf-8'));
    } catch {}
    return { facts: [], preferences: {}, conversationCount: 0, firstSeen: new Date().toISOString() };
  }

  saveMemory() {
    try { fs.writeFileSync(MEMORY_FILE, JSON.stringify(this.memory, null, 2)); } catch {}
  }

  remember(key, value) {
    this.memory.facts = this.memory.facts.filter(f => f.key !== key);
    this.memory.facts.push({ key, value, when: new Date().toISOString() });
    if (this.memory.facts.length > 100) this.memory.facts = this.memory.facts.slice(-100);
    this.saveMemory();
  }

  recall(key) {
    const fact = this.memory.facts.find(f => f.key === key);
    return fact ? fact.value : null;
  }

  // === REAL-TIME DATA ===
  async fetchWeather(location) {
    try {
      const loc = location || 'auto';
      const url = `https://wttr.in/${encodeURIComponent(loc)}?format=j1`;
      const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
      if (!res.ok) return null;
      const data = await res.json();
      const cur = data.current_condition?.[0];
      if (!cur) return null;
      const area = data.nearest_area?.[0];
      const forecast = data.weather?.slice(0, 3) || [];
      return {
        location: area ? `${area.areaName?.[0]?.value}, ${area.region?.[0]?.value || area.country?.[0]?.value}` : loc,
        temp_f: cur.temp_F, temp_c: cur.temp_C,
        feels_f: cur.FeelsLikeF, feels_c: cur.FeelsLikeC,
        humidity: cur.humidity, wind_mph: cur.windspeedMiles,
        desc: cur.weatherDesc?.[0]?.value || 'Unknown',
        uv: cur.uvIndex, visibility: cur.visibility,
        forecast: forecast.map(d => ({
          date: d.date, high_f: d.maxtempF, low_f: d.mintempF,
          high_c: d.maxtempC, low_c: d.mintempC,
          desc: d.hourly?.[4]?.weatherDesc?.[0]?.value || '',
        })),
      };
    } catch { return null; }
  }

  async fetchWikipedia(query) {
    try {
      const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(query)}`;
      const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
      if (!res.ok) {
        const searchUrl = `https://en.wikipedia.org/w/api.php?action=opensearch&search=${encodeURIComponent(query)}&limit=1&format=json`;
        const searchRes = await fetch(searchUrl, { signal: AbortSignal.timeout(5000) });
        if (!searchRes.ok) return null;
        const [, titles] = await searchRes.json();
        if (!titles?.length) return null;
        const retry = await fetch(`https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(titles[0])}`, { signal: AbortSignal.timeout(5000) });
        if (!retry.ok) return null;
        return await retry.json();
      }
      return await res.json();
    } catch { return null; }
  }

  async fetchDefinition(word) {
    try {
      const res = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`, { signal: AbortSignal.timeout(5000) });
      if (!res.ok) return null;
      const data = await res.json();
      if (!Array.isArray(data) || !data.length) return null;
      const entry = data[0];
      const meanings = entry.meanings?.slice(0, 3).map(m => ({
        part: m.partOfSpeech,
        defs: m.definitions?.slice(0, 2).map(d => d.definition) || [],
        example: m.definitions?.[0]?.example || null,
      })) || [];
      return { word: entry.word, phonetic: entry.phonetic || '', meanings };
    } catch { return null; }
  }

  async fetchNews(topic) {
    try {
      const q = topic ? encodeURIComponent(topic) : '';
      const url = q
        ? `https://news.google.com/rss/search?q=${q}&hl=en-US&gl=US&ceid=US:en`
        : `https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en`;
      const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
      if (!res.ok) return null;
      const xml = await res.text();
      const items = [];
      const matches = xml.matchAll(/<item>[\s\S]*?<\/item>/g);
      for (const match of matches) {
        const item = match[0];
        const title = item.match(/<title>([\s\S]*?)<\/title>/)?.[1]?.replace(/<!\[CDATA\[|\]\]>/g, '').trim();
        const source = item.match(/<source[^>]*>([\s\S]*?)<\/source>/)?.[1]?.replace(/<!\[CDATA\[|\]\]>/g, '').trim();
        const pubDate = item.match(/<pubDate>([\s\S]*?)<\/pubDate>/)?.[1]?.trim();
        if (title) items.push({ title, source: source || '', date: pubDate || '' });
        if (items.length >= 8) break;
      }
      return items.length ? items : null;
    } catch { return null; }
  }

  async fetchJoke() {
    try {
      const res = await fetch('https://official-joke-api.appspot.com/random_joke', { signal: AbortSignal.timeout(3000) });
      if (!res.ok) return null;
      return await res.json();
    } catch { return null; }
  }

  async fetchTrivia() {
    try {
      const res = await fetch('https://opentdb.com/api.php?amount=1&type=multiple', { signal: AbortSignal.timeout(3000) });
      if (!res.ok) return null;
      const data = await res.json();
      const q = data.results?.[0];
      if (!q) return null;
      return {
        question: q.question.replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>'),
        answer: q.correct_answer.replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&amp;/g, '&'),
        category: q.category,
        difficulty: q.difficulty,
      };
    } catch { return null; }
  }

  // === MAIN PROCESS ===
  async process({ command, screenshot, deviceInfo, history, isFollowUp, previousResult }) {
    this.memory.conversationCount++;
    this.saveMemory();

    // Check for memory commands
    const memResult = this.handleMemory(command);
    if (memResult) return memResult;

    if (this.client) {
      return this.processWithAI(command, screenshot, deviceInfo, history, isFollowUp, previousResult);
    }
    return this.processLocally(command, history);
  }

  handleMemory(command) {
    const t = command.toLowerCase().trim();

    const rememberMatch = t.match(/(?:remember|note)\s+(?:that\s+)?(?:my\s+)?(.+?)(?:\s+is\s+)(.+)/i);
    if (rememberMatch) {
      this.remember(rememberMatch[1].trim(), rememberMatch[2].trim());
      return jarvisReply(`Noted. I'll remember that your ${rememberMatch[1].trim()} is ${rememberMatch[2].trim()}.`);
    }

    const recallMatch = t.match(/(?:what(?:'s| is) my|do you (?:remember|know) my)\s+(.+?)[\s?]*$/i);
    if (recallMatch) {
      const key = recallMatch[1].trim().replace(/\?$/, '');
      const val = this.recall(key);
      if (val) return jarvisReply(`Your ${key} is ${val}.`);
      return jarvisReply(`I don't have that on file. You can say "remember my ${key} is ..." to store it.`);
    }

    if (t === 'what do you remember' || t === 'show memory' || t.includes('what do you know about me')) {
      if (!this.memory.facts.length) return jarvisReply("I don't have anything stored yet. Say \"remember my name is ...\" to start.");
      const list = this.memory.facts.map(f => `- ${f.key}: ${f.value}`).join('\n');
      return jarvisReply(`Here's what I know:\n\n${list}\n\nConversations: ${this.memory.conversationCount}\nFirst session: ${new Date(this.memory.firstSeen).toLocaleDateString()}`);
    }

    if (t === 'forget everything' || t === 'clear memory') {
      this.memory.facts = [];
      this.saveMemory();
      return jarvisReply("Memory cleared. Starting fresh.");
    }

    return null;
  }

  async processLocally(command, history) {
    const t = command.toLowerCase().trim();
    const time = new Date();
    const hour = time.getHours();
    const greeting = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';

    // Greetings
    if (/^(hi|hello|hey|good morning|good afternoon|good evening|sup|what's up|howdy|greetings)$/i.test(t) || /^(hi|hello|hey|good morning|good afternoon|good evening) /i.test(t)) {
      const name = this.recall('name');
      const g = name
        ? `Good ${greeting}, ${name}. All systems operational. What can I do for you?`
        : `Good ${greeting}. All systems operational. What can I do for you?`;
      return jarvisReply(g);
    }

    // Identity
    if (t.includes('who are you') || t.includes('what are you') || t.includes('your name'))
      return jarvisReply("I'm J.A.R.V.I.S. — Just A Rather Very Intelligent System. Your personal AI assistant. I can answer questions using Wikipedia, fetch live weather and news, define words, create presentations and documents, do math, control your device, remember things about you, and more.");

    // How are you
    if (t.includes('how are you') || t.includes("how's it going") || t.includes('how do you feel')) {
      const replies = [
        "All systems nominal. Running at peak efficiency, as always.",
        `Session ${this.memory.conversationCount}. All processes running smoothly.`,
        "Fully operational. Ready for your command.",
      ];
      return jarvisReply(replies[Math.floor(Math.random() * replies.length)]);
    }

    // Thanks
    if (/^(thanks|thank you|thx|ty|appreciate)/i.test(t))
      return jarvisReply("At your service. What else do you need?");

    // Time
    if (t.includes('what time') || t === 'time' || t.includes('current time'))
      return jarvisReply(`It's ${time.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}.`);

    // Date
    if (t.includes('what day') || t.includes('the date') || t.includes("today's date") || t === 'date' || t === "what's today")
      return jarvisReply(`Today is ${time.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}.`);

    // Math
    const mathResult = tryMath(t);
    if (mathResult !== null) return jarvisReply(mathResult);

    // Coin flip
    if (t.includes('flip a coin') || t.includes('coin flip') || t.includes('heads or tails'))
      return jarvisReply(`Coin flip: ${Math.random() < 0.5 ? 'Heads' : 'Tails'}.`);

    // Dice
    if (t.includes('roll') || t.match(/\bd\d+\b/)) {
      let sides = 6;
      const dm = t.match(/d(\d+)/);
      if (dm) sides = parseInt(dm[1]);
      return jarvisReply(`Rolled a ${Math.floor(Math.random() * sides) + 1} on a d${sides}.`);
    }

    // Password
    if (t.includes('password') || t.includes('generate a pass')) {
      const lenMatch = t.match(/(\d+)\s*(?:char|length|long|digit)/);
      const len = lenMatch ? Math.min(Math.max(parseInt(lenMatch[1]), 8), 64) : 16;
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*()-_=+';
      let pw = '';
      for (let i = 0; i < len; i++) pw += chars[Math.floor(Math.random() * chars.length)];
      return jarvisReply(`Generated ${len}-character password:\n\n${pw}`);
    }

    // Unit conversion
    const convResult = tryConversion(t);
    if (convResult) return jarvisReply(convResult);

    // Percentage
    const pctMatch = t.match(/(?:what(?:'s| is)\s+)?(\d+(?:\.\d+)?)\s*%\s*(?:of|from)\s+(\d+(?:\.\d+)?)/);
    if (pctMatch) {
      const pct = parseFloat(pctMatch[1]), base = parseFloat(pctMatch[2]);
      return jarvisReply(`${pct}% of ${base} = ${(pct / 100 * base).toFixed(2)}`);
    }

    // Tip calculator
    if (t.includes('tip') && t.match(/\$?\d+/)) {
      const a = parseFloat(t.match(/\$?([\d.]+)/)[1]);
      return jarvisReply(`Tip on $${a.toFixed(2)}:\n15%: $${(a * 0.15).toFixed(2)}\n18%: $${(a * 0.18).toFixed(2)}\n20%: $${(a * 0.20).toFixed(2)}\n25%: $${(a * 0.25).toFixed(2)}`);
    }

    // === REAL-TIME DATA ===

    // Weather (actually fetched)
    if (t.includes('weather') || t.includes('temperature outside') || t.includes('forecast') || t.includes('is it raining') || t.includes('how hot') || t.includes('how cold')) {
      const locMatch = t.match(/weather\s+(?:in|for|at)\s+(.+)/i) || t.match(/temperature\s+(?:in|for|at)\s+(.+)/i);
      const loc = locMatch ? locMatch[1].trim() : null;
      const data = await this.fetchWeather(loc);
      if (data) {
        let msg = `Weather in ${data.location}:\n\n`;
        msg += `Current: ${data.desc}\n`;
        msg += `Temperature: ${data.temp_f}°F (${data.temp_c}°C)\n`;
        msg += `Feels like: ${data.feels_f}°F (${data.feels_c}°C)\n`;
        msg += `Humidity: ${data.humidity}%\n`;
        msg += `Wind: ${data.wind_mph} mph\n`;
        msg += `UV Index: ${data.uv}`;
        if (data.forecast.length) {
          msg += '\n\nForecast:';
          for (const d of data.forecast) {
            msg += `\n${d.date}: ${d.desc} — High ${d.high_f}°F / Low ${d.low_f}°F`;
          }
        }
        return jarvisReply(msg);
      }
      return jarvisReply("Couldn't reach the weather service. Try again in a moment.");
    }

    // News (actually fetched)
    if (t.includes('news') || t.includes('headlines') || t.includes("what's happening")) {
      const topicMatch = t.match(/news\s+(?:about|on|for)\s+(.+)/i);
      const topic = topicMatch ? topicMatch[1].trim() : null;
      const items = await this.fetchNews(topic);
      if (items) {
        let msg = topic ? `Latest news on "${topic}":\n` : 'Top headlines:\n';
        items.forEach((item, i) => {
          const ago = item.date ? timeAgo(new Date(item.date)) : '';
          msg += `\n${i + 1}. ${item.title}`;
          if (item.source) msg += ` — ${item.source}`;
          if (ago) msg += ` (${ago})`;
        });
        return jarvisReply(msg);
      }
      return jarvisReply("Couldn't fetch news right now. Try again shortly.");
    }

    // Wikipedia lookup
    if (t.includes('wikipedia') || t.startsWith('wiki ') || t.startsWith('who was ') || t.startsWith('who is ') || t.startsWith('what is a ') || t.startsWith('what is an ') || t.startsWith('what is the ') || t.startsWith('tell me about ')) {
      const q = t.replace(/^(?:search\s+)?(?:wikipedia|wiki)\s*(?:for|about)?\s*/i, '')
        .replace(/^who (?:is|was)\s+/i, '').replace(/^what is (?:a |an |the )?/i, '')
        .replace(/^tell me about\s+/i, '').replace(/\?$/, '').trim();
      if (q) {
        const data = await this.fetchWikipedia(q);
        if (data && data.extract) {
          let msg = data.title ? `${data.title}\n\n` : '';
          msg += data.extract;
          if (data.content_urls?.desktop?.page) msg += `\n\nMore: ${data.content_urls.desktop.page}`;
          return jarvisReply(msg);
        }
        return jarvisReply(`I couldn't find anything on "${q}". Try rephrasing or be more specific.`);
      }
    }

    // Define
    if (t.startsWith('define ') || (t.startsWith('what does ') && t.includes('mean'))) {
      const word = t.replace(/^(?:define\s+|what\s+does\s+)/i, '').replace(/\s*\??\s*(?:mean)?$/, '').trim();
      const data = await this.fetchDefinition(word);
      if (data) {
        let msg = `${data.word}`;
        if (data.phonetic) msg += ` ${data.phonetic}`;
        msg += '\n';
        for (const m of data.meanings) {
          msg += `\n[${m.part}]`;
          for (const d of m.defs) msg += `\n  - ${d}`;
          if (m.example) msg += `\n  Example: "${m.example}"`;
        }
        return jarvisReply(msg);
      }
      return jarvisReply(`Couldn't find a definition for "${word}".`);
    }

    // Jokes (fetched from API)
    if (t.includes('tell me a joke') || t.includes('say something funny') || t.includes('make me laugh') || t.includes('joke')) {
      const joke = await this.fetchJoke();
      if (joke) return jarvisReply(`${joke.setup}\n\n${joke.punchline}`);
      const fallback = [
        "Why do programmers prefer dark mode? Because light attracts bugs.",
        "A SQL query walks into a bar, sees two tables, and asks — 'Can I join you?'",
        "I'm not saying I'm better than Siri, but I've never tried to call someone named 'Aunt Margarine.'",
      ];
      return jarvisReply(fallback[Math.floor(Math.random() * fallback.length)]);
    }

    // Trivia
    if (t.includes('trivia') || t.includes('quiz me') || t.includes('test me')) {
      const trivia = await this.fetchTrivia();
      if (trivia) return jarvisReply(`Category: ${trivia.category} (${trivia.difficulty})\n\nQ: ${trivia.question}\n\nAnswer: ${trivia.answer}`);
      return jarvisReply("Couldn't fetch a trivia question right now.");
    }

    // Translate — use MyMemory (free, no key)
    if (t.startsWith('translate ')) {
      const rest = t.slice(10).trim();
      const toMatch = rest.match(/(.+?)\s+(?:to|into)\s+(\w+)$/);
      if (toMatch) {
        const text = toMatch[1], lang = toMatch[2];
        const langMap = { spanish: 'es', french: 'fr', german: 'de', italian: 'it', portuguese: 'pt', japanese: 'ja', chinese: 'zh-CN', korean: 'ko', arabic: 'ar', russian: 'ru', hindi: 'hi', dutch: 'nl', swedish: 'sv', turkish: 'tr', greek: 'el', polish: 'pl', thai: 'th', vietnamese: 'vi', indonesian: 'id', hebrew: 'he', czech: 'cs', danish: 'da', finnish: 'fi', norwegian: 'no', romanian: 'ro', hungarian: 'hu', ukrainian: 'uk', swahili: 'sw', latin: 'la', filipino: 'tl', malay: 'ms' };
        const code = langMap[lang.toLowerCase()] || lang;
        try {
          const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=en|${code}`;
          const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
          const data = await res.json();
          if (data.responseData?.translatedText) {
            return jarvisReply(`"${text}" in ${lang}:\n\n${data.responseData.translatedText}`);
          }
        } catch {}
        return jarvisReply(`Opening Google Translate.`, [{ type: 'openURL', params: { url: `https://translate.google.com/?sl=auto&tl=${code}&text=${encodeURIComponent(text)}` } }]);
      }
    }

    // Random number
    if (t.includes('random number')) {
      const m = t.match(/(?:between|from)\s+(\d+)\s+(?:and|to)\s+(\d+)/);
      if (m) { const min = parseInt(m[1]), max = parseInt(m[2]); return jarvisReply(`Random number between ${min} and ${max}: ${Math.floor(Math.random() * (max - min + 1)) + min}`); }
      return jarvisReply(`Random number (1-100): ${Math.floor(Math.random() * 100) + 1}`);
    }

    // Random color
    if (t.includes('random color') || t.includes('generate a color')) {
      const hex = '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0');
      const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
      return jarvisReply(`Random color:\nHex: ${hex}\nRGB: rgb(${r}, ${g}, ${b})`);
    }

    // Motivational quote — fetch from API
    if (t.includes('motivat') || t.includes('inspire') || t.includes('quote')) {
      try {
        const res = await fetch('https://zenquotes.io/api/random', { signal: AbortSignal.timeout(3000) });
        const data = await res.json();
        if (data?.[0]?.q) return jarvisReply(`"${data[0].q}" — ${data[0].a}`);
      } catch {}
      const quotes = [
        '"Sometimes you gotta run before you can walk." — Tony Stark',
        '"The only way to do great work is to love what you do." — Steve Jobs',
        '"Heroes are made by the path they choose, not the powers they are graced with." — Tony Stark',
        '"Intelligence is the ability to adapt to change." — Stephen Hawking',
      ];
      return jarvisReply(quotes[Math.floor(Math.random() * quotes.length)]);
    }

    // Fun facts — fetch from API
    if (t.includes('fun fact') || t.includes('random fact') || t.includes('did you know')) {
      try {
        const res = await fetch('https://uselessfacts.jsph.pl/api/v2/facts/random', { signal: AbortSignal.timeout(3000) });
        const data = await res.json();
        if (data?.text) return jarvisReply(data.text);
      } catch {}
      const facts = [
        "Honey never spoils. 3,000-year-old honey found in Egyptian tombs was still edible.",
        "Octopuses have three hearts and blue blood.",
        "A day on Venus is longer than a year on Venus.",
        "Bananas are berries, but strawberries aren't.",
        "The first computer programmer was Ada Lovelace, in the 1840s.",
      ];
      return jarvisReply(facts[Math.floor(Math.random() * facts.length)]);
    }

    // Presentation
    if (t.includes('presentation') || t.includes('slide')) {
      const topic = t.replace(/(?:create|make|build|generate)\s+(?:a |an |me )?\s*(?:presentation|slides?)\s*(?:about|on|for)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a presentation with real content.',
        message: `Creating a presentation about "${topic}" — full interactive slide deck with real content.`,
        actions: [{ type: 'createPresentation', params: { topic, slides: 8 } }],
        needsScreenAfter: false, isDone: true, plan: null,
      };
    }

    // Document
    if (t.includes('document') || (t.includes('write') && t.includes('about'))) {
      const topic = t.replace(/(?:create|make|build|generate|write)\s+(?:a |an |me )?\s*(?:document|report|essay|paper)\s*(?:about|on|for)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a document with real content.',
        message: `Generating a document about "${topic}" with researched content.`,
        actions: [{ type: 'createDocument', params: { topic } }],
        needsScreenAfter: false, isDone: true, plan: null,
      };
    }

    // Spreadsheet
    if (t.includes('spreadsheet') || t.includes('csv')) {
      const title = t.replace(/(?:create|make|build|generate)\s+(?:a |an |me )?\s*(?:spreadsheet|csv)\s*(?:about|on|for|called|named)?\s*/i, '').trim() || 'Untitled';
      return {
        thought: 'Creating a spreadsheet.',
        message: `Creating spreadsheet: "${title}".`,
        actions: [{ type: 'createSpreadsheet', params: { title } }],
        needsScreenAfter: false, isDone: true, plan: null,
      };
    }

    // Search (with web search action)
    if (t.startsWith('search ') || t.startsWith('google ') || t.startsWith('look up ') || t.startsWith('find ')) {
      const q = t.replace(/^(?:search\s+(?:for\s+|the\s+web\s+for\s+)?|google\s+|look\s+up\s+|find\s+)/i, '').trim();
      return jarvisReply(`Searching for "${q}".`, [{ type: 'webSearch', params: { query: q } }]);
    }

    // YouTube
    if (t.includes('youtube')) {
      const q = t.replace(/\byoutube\b/gi, '').replace(/(?:search|play|watch|find|open|on|for)\s*/gi, '').trim();
      if (q) return jarvisReply(`Searching YouTube for "${q}".`, [{ type: 'openURL', params: { url: `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}` } }]);
      return jarvisReply("Opening YouTube.", [{ type: 'openURL', params: { url: 'https://www.youtube.com' } }]);
    }

    // Open websites
    const sites = {
      gmail: 'https://mail.google.com', email: 'https://mail.google.com',
      'google docs': 'https://docs.google.com', 'google sheets': 'https://sheets.google.com',
      'google drive': 'https://drive.google.com', github: 'https://github.com',
      twitter: 'https://twitter.com', x: 'https://x.com', reddit: 'https://reddit.com',
      instagram: 'https://instagram.com', facebook: 'https://facebook.com',
      linkedin: 'https://linkedin.com', amazon: 'https://amazon.com',
      netflix: 'https://netflix.com', spotify: 'https://open.spotify.com',
      discord: 'https://discord.com/app', notion: 'https://notion.so',
      chatgpt: 'https://chat.openai.com', claude: 'https://claude.ai',
      wikipedia: 'https://wikipedia.org', tiktok: 'https://tiktok.com',
      twitch: 'https://twitch.tv', whatsapp: 'https://web.whatsapp.com',
    };
    for (const [name, url] of Object.entries(sites)) {
      if (t === `open ${name}` || t === `go to ${name}` || t === `launch ${name}`) {
        return jarvisReply(`Opening ${name.charAt(0).toUpperCase() + name.slice(1)}.`, [{ type: 'openURL', params: { url } }]);
      }
    }

    // Open URL
    const urlMatch = t.match(/(https?:\/\/[^\s]+|www\.[^\s]+)/);
    if (urlMatch) {
      let url = urlMatch[0]; if (!url.startsWith('http')) url = 'https://' + url;
      return jarvisReply("Opening that for you.", [{ type: 'openURL', params: { url } }]);
    }

    // Maps
    if (t.includes('directions') || t.includes('navigate to') || (t.includes('map') && (t.includes(' of ') || t.includes(' to ')))) {
      const q = t.replace(/(?:get\s+)?(?:directions|navigate)\s+to\s+|show\s+(?:me\s+)?(?:a\s+)?map\s+(?:of|to)\s+/i, '').trim();
      return jarvisReply(`Looking up "${q}" on Maps.`, [{ type: 'openURL', params: { url: `https://maps.google.com/maps?q=${encodeURIComponent(q)}` } }]);
    }

    // Timer
    if (t.includes('set a timer') || t.includes('start a timer') || t.includes('timer for')) {
      const mins = t.match(/(\d+)\s*(min|sec|hour)/);
      if (mins) return jarvisReply(`Opening a ${mins[1]} ${mins[2]} timer.`, [{ type: 'openURL', params: { url: `https://www.google.com/search?q=timer+${mins[1]}+${mins[2]}` } }]);
      return jarvisReply("Opening a timer.", [{ type: 'openURL', params: { url: 'https://www.google.com/search?q=timer' } }]);
    }

    // iOS features (server just acknowledges, client handles URL schemes)
    if (t.match(/(?:send|text|message)\s+/i) && (t.includes('text') || t.includes('message'))) return jarvisReply("Opening Messages.");
    if (t.includes('email') && (t.includes('send') || t.includes('write'))) return jarvisReply("Opening Mail.");
    if (t.match(/^(?:call|phone|dial)\s+/i) && !t.includes('facetime')) return jarvisReply(`Calling ${t.replace(/^(?:call|phone|dial)\s+/i, '').trim()}.`);
    if (t.includes('facetime')) return jarvisReply(`Starting FaceTime.`);
    const toggles = { 'toggle wifi': 'WiFi', 'toggle bluetooth': 'Bluetooth', 'toggle dark mode': 'Dark Mode', 'dark mode': 'Dark Mode', 'toggle airplane': 'Airplane Mode', 'toggle do not disturb': 'DND', 'dnd': 'DND', 'toggle low power': 'Low Power Mode' };
    for (const [cmd, label] of Object.entries(toggles)) { if (t.includes(cmd) || t === cmd) return jarvisReply(`Toggling ${label}.`); }
    if (t.match(/brightness\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting brightness to ${t.match(/(\d+)/)[1]}%.`);
    if (t.match(/volume\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting volume to ${t.match(/(\d+)/)[1]}%.`);
    if (t.includes('create a note') || t.includes('new note')) return jarvisReply("Opening Notes.");
    if (t.includes('reminder') || t.includes('remind me')) return jarvisReply("Setting your reminder.");
    if (t.includes('calendar event') || t.includes('schedule')) return jarvisReply("Opening Calendar.");
    if (t.includes('alarm')) return jarvisReply("Setting your alarm.");
    if (t.includes('camera') || t.includes('take a photo') || t.includes('selfie')) return jarvisReply("Opening Camera.");
    if (t.includes('open photos') || t.includes('photo library')) return jarvisReply("Opening Photos.");
    if (t.startsWith('play ')) return jarvisReply("Playing music.");
    if (t === 'pause' || t === 'pause music') return jarvisReply("Use Control Center to pause.");
    if (t.includes('turn on') || t.includes('turn off')) {
      const device = t.replace(/turn\s+(on|off)\s+(the\s+)?/i, '').trim();
      return jarvisReply(`Turning ${t.includes('turn on') ? 'on' : 'off'} the ${device}.`);
    }
    if (t.match(/thermostat\s+(?:to\s+)?(\d+)/i)) return jarvisReply(`Setting thermostat to ${t.match(/(\d+)/)[1]}°.`);
    if (t.includes('run shortcut')) return jarvisReply(`Running shortcut "${t.replace(/run\s+(?:the\s+)?shortcut\s*/i, '').trim()}".`);
    if (t.match(/^(?:open|launch)\s+\w+/i)) return jarvisReply(`Opening ${t.replace(/^(?:open|launch)\s+/i, '').trim()}.`);

    // Help
    if (t.includes('what can you do') || t === 'help' || t.includes('capabilities'))
      return jarvisReply(`JARVIS CAPABILITIES:\n\nAI & Knowledge — "who is Elon Musk", "tell me about quantum physics", "define serendipity"\nLive Weather — "weather in Tokyo", "is it raining"\nLive News — "news about AI", "top headlines"\nTranslate — "translate hello to japanese" (30+ languages, real translation)\nMemory — "remember my name is Tony", "what's my name"\nCreate — "make a presentation about AI", "create a document"\nMath — "what's 15 * 23", "5 miles to km", "15% of 230"\nTrivia — "quiz me", "give me trivia"\nApps — "open youtube", "open spotify" (50+ apps on iPad)\nComms — "text Mom saying hi", "call 555-1234", "facetime Mom"\nSettings — "toggle wifi", "dark mode", "set brightness to 70"\nSmart Home — "turn on the lights", "set thermostat to 72"\nFun — "tell me a joke", "fun fact", "motivational quote"\nUtils — "flip a coin", "roll d20", "password", "random color"\nSearch — "search for X", "youtube cat videos"\nMemory — "what do you remember", "forget everything"`);

    // Goodbye
    if (/^(bye|goodbye|see you|goodnight|later|peace)/i.test(t))
      return jarvisReply("Until next time. Jarvis signing off.");

    // === SMART FALLBACK: try Wikipedia for questions ===
    if (t.includes('?') || t.startsWith('how') || t.startsWith('what') || t.startsWith('why') || t.startsWith('when') || t.startsWith('where') || t.startsWith('who') || t.startsWith('can you') || t.startsWith('is ') || t.startsWith('are ') || t.startsWith('do ')) {
      const query = command.replace(/\?$/, '').trim();
      const wikiData = await this.fetchWikipedia(query);
      if (wikiData && wikiData.extract && wikiData.extract.length > 50) {
        let msg = wikiData.title ? `${wikiData.title}\n\n` : '';
        msg += wikiData.extract;
        return jarvisReply(msg);
      }
      // If Wikipedia didn't help, do a web search
      return jarvisReply(`Let me search that for you.`, [{ type: 'webSearch', params: { query: command } }]);
    }

    // General fallback
    return jarvisReply(`I'm not sure what you mean. Try:\n\n- "weather in New York"\n- "who is Albert Einstein"\n- "translate hello to french"\n- "news about technology"\n- "define quantum"\n- "what's 15 * 23"\n- Say "help" for everything I can do.`);
  }

  async processWithAI(command, screenshot, deviceInfo, history, isFollowUp, previousResult) {
    const messages = [];
    if (history && history.length > 0) {
      for (const turn of history.slice(-20)) {
        if (turn.role === 'user' || turn.role === 'assistant') messages.push({ role: turn.role, content: turn.content });
      }
      if (messages.length > 0 && messages[messages.length - 1].role === 'user') messages.pop();
    }
    const content = [];
    if (screenshot) content.push({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: screenshot } });
    let text = command;
    if (isFollowUp && previousResult) text = `[CONTINUING TASK]\n${previousResult}\n\n${command}`;
    if (deviceInfo) text += `\n\n[${deviceInfo.model} | ${deviceInfo.time}]`;
    content.push({ type: 'text', text });
    messages.push({ role: 'user', content });

    const cleaned = [];
    for (const msg of messages) {
      if (cleaned.length > 0 && cleaned[cleaned.length - 1].role === msg.role) {
        const prev = cleaned[cleaned.length - 1];
        if (typeof prev.content === 'string' && typeof msg.content === 'string') prev.content += '\n' + msg.content;
        continue;
      }
      cleaned.push(msg);
    }
    if (cleaned.length > 0 && cleaned[0].role !== 'user') cleaned.unshift({ role: 'user', content: 'Hello Jarvis.' });

    const response = await this.client.messages.create({
      model: 'claude-sonnet-4-20250514', max_tokens: 4096, system: JARVIS_SYSTEM, messages: cleaned,
    });
    const textOutput = response.content.filter(b => b.type === 'text').map(b => b.text).join('');
    return this.parseResponse(textOutput);
  }

  parseResponse(text) {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return { thought: '', message: text, actions: [], needsScreenAfter: false, isDone: true, plan: null };
    try {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        thought: parsed.thought || '', message: parsed.message || '',
        actions: (parsed.actions || []).map(a => ({ type: a.type, params: a.params || {} })),
        needsScreenAfter: parsed.needsScreenAfter ?? false, isDone: parsed.isDone ?? true, plan: parsed.plan || null,
      };
    } catch {
      return { thought: '', message: text.replace(/```json\n?|\n?```/g, '').trim(), actions: [], needsScreenAfter: false, isDone: true, plan: null };
    }
  }
}

function jarvisReply(message, actions) {
  return { thought: '', message, actions: actions || [], needsScreenAfter: false, isDone: true, plan: null };
}

function timeAgo(date) {
  const now = new Date();
  const diff = Math.floor((now - date) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function tryMath(t) {
  const prefixes = ['what is ', "what's ", 'calculate ', 'compute ', 'solve ', 'how much is ', 'eval ', 'math '];
  for (const p of prefixes) {
    if (t.startsWith(p)) { const r = evalMath(t.slice(p.length)); if (r) return r; }
  }
  if (/^\d/.test(t) && /[+\-*/^]/.test(t)) return evalMath(t);
  const sqrtMatch = t.match(/square root of\s+([\d.]+)/);
  if (sqrtMatch) return `Square root of ${sqrtMatch[1]} = ${Math.sqrt(parseFloat(sqrtMatch[1])).toFixed(4)}`;
  return null;
}

function evalMath(raw) {
  const expr = raw.replace(/plus/g, '+').replace(/minus/g, '-').replace(/times/g, '*')
    .replace(/multiplied by/g, '*').replace(/divided by/g, '/').replace(/over/g, '/')
    .replace(/\^/g, '**').replace(/x/g, '*').replace(/power of/g, '**')
    .replace(/[^0-9+\-*/().%\s*]/g, '').trim();
  if (!expr) return null;
  try {
    const result = Function('"use strict"; return (' + expr + ')')();
    if (typeof result === 'number' && isFinite(result)) return `The answer is ${result}.`;
  } catch {}
  return null;
}

function tryConversion(t) {
  const m = t.match(/(?:convert\s+)?([\d.]+)\s+(\w+)\s+(?:to|in|into)\s+(\w+)/);
  if (!m) return null;
  const val = parseFloat(m[1]), from = m[2].toLowerCase(), to = m[3].toLowerCase();
  const length = { m: 1, meter: 1, meters: 1, km: 1000, cm: 0.01, mm: 0.001, mi: 1609.344, mile: 1609.344, miles: 1609.344, ft: 0.3048, foot: 0.3048, feet: 0.3048, in: 0.0254, inch: 0.0254, inches: 0.0254, yd: 0.9144, yard: 0.9144, yards: 0.9144 };
  const weight = { kg: 1, g: 0.001, mg: 0.000001, lb: 0.453592, lbs: 0.453592, pound: 0.453592, pounds: 0.453592, oz: 0.0283495, ounce: 0.0283495, ounces: 0.0283495, ton: 907.185, tons: 907.185 };
  const volume = { l: 1, liter: 1, liters: 1, ml: 0.001, gal: 3.78541, gallon: 3.78541, gallons: 3.78541, cup: 0.236588, cups: 0.236588, pt: 0.473176, pint: 0.473176, quart: 0.946353, tbsp: 0.0147868, tsp: 0.00492892 };
  for (const table of [length, weight, volume]) {
    if (table[from] !== undefined && table[to] !== undefined) return `${val} ${from} = ${parseFloat((val * table[from] / table[to]).toPrecision(6))} ${to}`;
  }
  const tFrom = from[0], tTo = to[0];
  if ('cfk'.includes(tFrom) && 'cfk'.includes(tTo)) {
    let c = tFrom === 'f' ? (val - 32) * 5 / 9 : tFrom === 'k' ? val - 273.15 : val;
    let r = tTo === 'f' ? c * 9 / 5 + 32 : tTo === 'k' ? c + 273.15 : c;
    return `${val} ${from} = ${r.toFixed(1)} ${to}`;
  }
  return null;
}
