import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { JarvisAgent } from './agent.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const agent = new JarvisAgent();

app.use(cors());
app.use(express.json({ limit: '20mb' }));

const auth = (req, res, next) => {
  const secret = process.env.API_SECRET;
  if (!secret) return next();
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token !== secret) return res.status(401).json({ error: 'Unauthorized' });
  next();
};

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', version: '2.0.0', agent: 'jarvis' });
});

app.post('/api/agent', auth, async (req, res) => {
  try {
    const result = await agent.process(req.body);
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

app.listen(port, () => {
  console.log(`Jarvis AI server running on port ${port}`);
  console.log(`Endpoints:`);
  console.log(`  GET  /api/health`);
  console.log(`  POST /api/agent`);
});
