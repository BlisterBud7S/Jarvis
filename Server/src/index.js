import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { JarvisAgent } from './agent.js';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = process.env.PORT || 3000;
const agent = new JarvisAgent();

// Generated files directory
const filesDir = path.join(__dirname, '..', 'generated');
if (!fs.existsSync(filesDir)) fs.mkdirSync(filesDir, { recursive: true });

app.use(cors());
app.use(express.json({ limit: '20mb' }));

// Serve web client
app.use(express.static(path.join(__dirname, '..', 'public')));

// Serve generated files
app.use('/files', express.static(filesDir));

const auth = (req, res, next) => {
  const secret = process.env.API_SECRET;
  if (!secret) return next();
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token !== secret) return res.status(401).json({ error: 'Unauthorized' });
  next();
};

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', version: '2.0.0', agent: 'jarvis', web: true });
});

app.post('/api/agent', auth, async (req, res) => {
  try {
    const result = await agent.process(req.body);
    // Process actions server-side for web clients
    if (result.actions && result.actions.length > 0) {
      result.actionResults = [];
      for (const action of result.actions) {
        const ar = executeWebAction(action, req);
        result.actionResults.push(ar);
      }
    }
    res.json(result);
  } catch (err) {
    console.error('Agent error:', err);
    res.status(500).json({
      thought: '',
      message: "Something went wrong on my end. Try again.",
      actions: [],
      needsScreenAfter: false,
      isDone: true,
      plan: null,
    });
  }
});

// Document generation API
app.post('/api/generate/presentation', auth, (req, res) => {
  const { topic, slides = 8, theme = 'jarvis' } = req.body;
  const html = generatePresentation(topic, slides, theme);
  const filename = `presentation_${Date.now()}.html`;
  fs.writeFileSync(path.join(filesDir, filename), html);
  res.json({ success: true, file: filename, url: `/files/${filename}` });
});

app.post('/api/generate/document', auth, (req, res) => {
  const { topic, title } = req.body;
  const html = generateDocument(topic || title || 'Untitled');
  const filename = `document_${Date.now()}.html`;
  fs.writeFileSync(path.join(filesDir, filename), html);
  res.json({ success: true, file: filename, url: `/files/${filename}` });
});

app.post('/api/generate/spreadsheet', auth, (req, res) => {
  const { title, headers, rows } = req.body;
  const csv = generateSpreadsheet(title || 'Untitled', headers, rows);
  const filename = `spreadsheet_${Date.now()}.csv`;
  fs.writeFileSync(path.join(filesDir, filename), csv);
  res.json({ success: true, file: filename, url: `/files/${filename}` });
});

app.get('/api/files', auth, (_req, res) => {
  const files = fs.readdirSync(filesDir).map(f => ({
    name: f,
    url: `/files/${f}`,
    size: fs.statSync(path.join(filesDir, f)).size,
    created: fs.statSync(path.join(filesDir, f)).birthtime,
  }));
  res.json(files);
});

// Math API
app.post('/api/calculate', (req, res) => {
  const { expression } = req.body;
  try {
    const sanitized = expression.replace(/[^0-9+\-*/().%\s^]/g, '').replace(/\^/g, '**');
    const result = Function('"use strict"; return (' + sanitized + ')')();
    res.json({ result: Number(result), expression });
  } catch {
    res.json({ result: null, error: 'Could not evaluate', expression });
  }
});

// Catch-all — serve web client
app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`\n  ╔══════════════════════════════════════╗`);
  console.log(`  ║     J.A.R.V.I.S. Server v2.0.0      ║`);
  console.log(`  ╠══════════════════════════════════════╣`);
  console.log(`  ║  Local:  http://localhost:${port}        ║`);
  console.log(`  ║  Web UI: http://localhost:${port}        ║`);
  console.log(`  ╚══════════════════════════════════════╝\n`);
  console.log(`  Open on your iPad: http://<your-mac-ip>:${port}`);
  console.log(`  Then: Share → Add to Home Screen\n`);
});

// Web action executor
function executeWebAction(action, req) {
  const { type, params = {} } = action;
  const baseUrl = `${req.protocol}://${req.get('host')}`;

  switch (type) {
    case 'createPresentation': {
      const topic = params.topic || params.title || 'Untitled';
      const slides = params.slides || 8;
      const html = generatePresentation(topic, slides);
      const filename = `presentation_${Date.now()}.html`;
      fs.writeFileSync(path.join(filesDir, filename), html);
      return { type, success: true, message: `Presentation created`, url: `${baseUrl}/files/${filename}` };
    }
    case 'createDocument': {
      const topic = params.topic || params.title || 'Untitled';
      const html = generateDocument(topic);
      const filename = `document_${Date.now()}.html`;
      fs.writeFileSync(path.join(filesDir, filename), html);
      return { type, success: true, message: `Document created`, url: `${baseUrl}/files/${filename}` };
    }
    case 'createSpreadsheet': {
      const title = params.title || 'Untitled';
      const csv = generateSpreadsheet(title, params.headers?.split?.(','), []);
      const filename = `spreadsheet_${Date.now()}.csv`;
      fs.writeFileSync(path.join(filesDir, filename), csv);
      return { type, success: true, message: `Spreadsheet created`, url: `${baseUrl}/files/${filename}` };
    }
    case 'calculate': {
      try {
        const expr = (params.expression || params.query || '').replace(/[^0-9+\-*/().%\s^]/g, '').replace(/\^/g, '**');
        const result = Function('"use strict"; return (' + expr + ')')();
        return { type, success: true, message: `${params.expression} = ${result}` };
      } catch {
        return { type, success: false, message: 'Could not evaluate' };
      }
    }
    case 'coinFlip':
      return { type, success: true, message: `Coin flip: ${Math.random() < 0.5 ? 'Heads' : 'Tails'}` };
    case 'rollDice': {
      const sides = params.sides || 6;
      return { type, success: true, message: `Rolled a ${Math.floor(Math.random() * sides) + 1} (d${sides})` };
    }
    case 'generatePassword': {
      const len = params.length || 16;
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*';
      let pw = '';
      for (let i = 0; i < len; i++) pw += chars[Math.floor(Math.random() * chars.length)];
      return { type, success: true, message: `Password: ${pw}` };
    }
    default:
      return { type, success: true, message: `Action ${type} noted` };
  }
}

// Presentation generator
function generatePresentation(topic, slideCount = 8) {
  const slides = [];
  slides.push({ title: topic, content: 'An Interactive Presentation', isTitle: true });

  const sections = [
    'Introduction', 'Background & Context', 'Key Concepts',
    'Analysis', 'Current Trends', 'Challenges',
    'Solutions & Opportunities', 'Future Outlook', 'Conclusion',
    'Key Takeaways', 'References', 'Q&A',
  ];

  for (let i = 0; i < Math.min(slideCount - 1, sections.length); i++) {
    slides.push({ title: sections[i], content: `Key points about ${sections[i].toLowerCase()} regarding ${topic}.`, isTitle: false });
  }

  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${topic} - Presentation</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,system-ui,sans-serif;background:#0a0a1a;color:#e0e0e8;overflow:hidden;height:100vh;touch-action:pan-y}
.slide{position:absolute;top:0;left:0;width:100%;height:100%;display:flex;flex-direction:column;justify-content:center;align-items:center;padding:60px;opacity:0;transform:translateX(100%);transition:all 0.5s ease}
.slide.active{opacity:1;transform:translateX(0)}
.slide.prev{opacity:0;transform:translateX(-100%)}
.slide.title-slide{background:linear-gradient(135deg,#0a0a2e,#1a0a3e)}
.slide:not(.title-slide){background:linear-gradient(180deg,#0a0a1a,#12121f)}
h1{font-size:clamp(28px,5vw,56px);font-weight:700;text-align:center;background:linear-gradient(90deg,#00e5ff,#7c4dff);-webkit-background-clip:text;-webkit-text-fill-color:transparent;margin-bottom:20px}
h2{font-size:clamp(22px,4vw,40px);font-weight:600;color:#00e5ff;margin-bottom:24px;text-align:center}
p{font-size:clamp(16px,2.5vw,24px);line-height:1.6;text-align:center;max-width:800px;color:#b0b0c0}
.subtitle{font-size:clamp(18px,3vw,28px);color:#8888a0}
.nav{position:fixed;bottom:30px;left:0;right:0;display:flex;justify-content:center;gap:12px;z-index:10}
.nav button{padding:10px 24px;border:1px solid #333;border-radius:24px;background:rgba(20,20,30,0.8);color:#e0e0e8;font-size:14px;cursor:pointer;backdrop-filter:blur(10px)}
.nav button:active{background:#00e5ff;color:#000}
.counter{position:fixed;top:20px;right:20px;font-size:14px;color:#555}
.progress{position:fixed;top:0;left:0;height:3px;background:linear-gradient(90deg,#00e5ff,#7c4dff);transition:width 0.5s}
</style></head><body>
<div class="progress" id="progress"></div>
<div class="counter" id="counter"></div>
${slides.map((s, i) => `<div class="slide${i === 0 ? ' active' : ''}${s.isTitle ? ' title-slide' : ''}" id="s${i}">
${s.isTitle ? `<h1>${s.title}</h1><p class="subtitle">${s.content}</p>` : `<h2>${s.title}</h2><p>${s.content}</p>`}
</div>`).join('\n')}
<div class="nav">
<button onclick="go(-1)">&#9664; Prev</button>
<button onclick="go(1)">Next &#9654;</button>
</div>
<script>
let cur=0;const total=${slides.length};
function go(d){const n=cur+d;if(n<0||n>=total)return;
document.getElementById('s'+cur).className='slide'+(d>0?' prev':'');
cur=n;document.getElementById('s'+cur).className='slide active';
document.getElementById('counter').textContent=(cur+1)+'/'+total;
document.getElementById('progress').style.width=((cur+1)/total*100)+'%'}
document.getElementById('counter').textContent='1/'+total;
document.getElementById('progress').style.width=(1/total*100)+'%';
let tx=0;document.addEventListener('touchstart',e=>tx=e.touches[0].clientX);
document.addEventListener('touchend',e=>{const d=e.changedTouches[0].clientX-tx;if(Math.abs(d)>50)go(d<0?1:-1)});
document.addEventListener('keydown',e=>{if(e.key==='ArrowRight')go(1);if(e.key==='ArrowLeft')go(-1)});
</script></body></html>`;
}

// Document generator
function generateDocument(topic) {
  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${topic}</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,'Times New Roman',serif;background:#fafaf8;color:#1a1a1a;padding:40px 20px;max-width:800px;margin:0 auto;line-height:1.8}
h1{font-size:32px;font-weight:700;text-align:center;margin-bottom:8px;color:#111}
.meta{text-align:center;color:#666;font-size:14px;margin-bottom:40px;border-bottom:1px solid #ddd;padding-bottom:20px}
h2{font-size:22px;margin:32px 0 12px;color:#222;border-bottom:2px solid #00b8d4;padding-bottom:6px;display:inline-block}
p{font-size:16px;margin-bottom:16px;text-align:justify}
@media(prefers-color-scheme:dark){
body{background:#1a1a1a;color:#ddd}
h1{color:#eee}h2{color:#ccc}.meta{color:#888;border-color:#333}
}
@media print{body{padding:0;font-size:12pt}}
</style></head><body>
<h1>${topic}</h1>
<div class="meta">Generated by J.A.R.V.I.S. — ${new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</div>
<h2>Introduction</h2>
<p>This document provides a comprehensive overview of ${topic}. The following sections cover key aspects, current developments, and important considerations.</p>
<h2>Background</h2>
<p>Understanding the context and history of ${topic} is essential for a complete picture. This section outlines the foundational concepts and their evolution over time.</p>
<h2>Key Points</h2>
<p>The most important aspects of ${topic} include its core principles, practical applications, and the factors that influence its development and adoption.</p>
<h2>Analysis</h2>
<p>A detailed analysis reveals important patterns and insights about ${topic}. These findings have implications for stakeholders and decision-makers alike.</p>
<h2>Conclusion</h2>
<p>${topic} remains a significant area of interest with ongoing developments. Continued attention and adaptation will be crucial moving forward.</p>
</body></html>`;
}

// Spreadsheet generator
function generateSpreadsheet(title, headers, rows) {
  const h = headers || ['Column A', 'Column B', 'Column C'];
  let csv = h.join(',') + '\n';
  if (rows && rows.length) {
    rows.forEach(r => { csv += r.join(',') + '\n'; });
  }
  return csv;
}
