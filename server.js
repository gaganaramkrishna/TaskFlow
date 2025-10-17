const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0'; // Listen on all interfaces

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage
let tasks = [
  {
    id: uuidv4(),
    title: 'Welcome to TaskFlow!',
    completed: false,
    createdAt: new Date().toISOString()
  },
  {
    id: uuidv4(),
    title: 'Add your first task',
    completed: true,
    createdAt: new Date().toISOString()
  }
];

// Routes
app.get('/api/tasks', (req, res) => {
  res.json({
    success: true,
    data: tasks.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
  });
});

app.post('/api/tasks', (req, res) => {
  const { title } = req.body;
  
  if (!title || title.trim() === '') {
    return res.status(400).json({
      success: false,
      message: 'Task title is required'
    });
  }

  const newTask = {
    id: uuidv4(),
    title: title.trim(),
    completed: false,
    createdAt: new Date().toISOString()
  };

  tasks.push(newTask);
  
  res.status(201).json({
    success: true,
    data: newTask
  });
});

app.put('/api/tasks/:id', (req, res) => {
  const { id } = req.params;
  const { title, completed } = req.body;
  
  const taskIndex = tasks.findIndex(task => task.id === id);
  
  if (taskIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Task not found'
    });
  }

  if (title !== undefined) tasks[taskIndex].title = title;
  if (completed !== undefined) tasks[taskIndex].completed = completed;

  res.json({
    success: true,
    data: tasks[taskIndex]
  });
});

app.delete('/api/tasks/:id', (req, res) => {
  const { id } = req.params;
  
  const taskIndex = tasks.findIndex(task => task.id === id);
  
  if (taskIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Task not found'
    });
  }

  tasks.splice(taskIndex, 1);
  
  res.json({
    success: true,
    message: 'Task deleted successfully'
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'TaskFlow Backend'
  });
});

// Start server
app.listen(PORT, HOST, () => {
  console.log(`🚀 TaskFlow Backend running on http://${HOST}:${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`📍 Network URL: http://${getLocalIP()}:${PORT}/health`);
});

// Function to get local IP address
function getLocalIP() {
  const interfaces = require('os').networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const interface of interfaces[name]) {
      if (interface.family === 'IPv4' && !interface.internal) {
        return interface.address;
      }
    }
  }
  return 'localhost';
}