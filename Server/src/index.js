import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { CommandHandler } from './command-handler.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

const authenticate = (req, res, next) => {
  const secret = process.env.API_SECRET;
  if (!secret) return next();

  const auth = req.headers.authorization;
  if (!auth || auth !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

const commandHandler = new CommandHandler();

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.post('/api/command', authenticate, async (req, res) => {
  try {
    const { command, screenshot, deviceInfo, conversationHistory } = req.body;

    if (!command) {
      return res.status(400).json({ error: 'No command provided' });
    }

    const result = await commandHandler.process({
      command,
      screenshot,
      deviceInfo,
      conversationHistory: conversationHistory || [],
    });

    res.json(result);
  } catch (error) {
    console.error('Command error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(port, () => {
  console.log(`Jarvis server running on port ${port}`);
});
