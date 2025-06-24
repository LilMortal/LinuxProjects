import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import winston from 'winston';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import fs from 'fs/promises';
import { NodeSSH } from 'node-ssh';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'remote-deploy' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ],
});

// Create logs directory if it doesn't exist
try {
  await fs.mkdir('logs', { recursive: true });
} catch (error) {
  // Directory might already exist
}

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// In-memory storage (in production, use a database)
let servers = [];
let deployments = [];
let logs = [];

// Helper function to add log entry
const addLog = (level, message, source, metadata = {}) => {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    source,
    metadata
  };
  logs.unshift(logEntry);
  // Keep only last 1000 logs
  if (logs.length > 1000) {
    logs = logs.slice(0, 1000);
  }
  logger.log(level, message, { source, ...metadata });
};

// API Routes

// Servers
app.get('/api/servers', (req, res) => {
  res.json(servers);
});

app.post('/api/servers', (req, res) => {
  const server = {
    ...req.body,
    id: Date.now().toString(),
    status: 'unknown',
    lastChecked: new Date().toISOString()
  };
  servers.push(server);
  addLog('info', `Server added: ${server.name}`, 'server-management', { serverId: server.id });
  res.json(server);
});

app.put('/api/servers/:id', (req, res) => {
  const index = servers.findIndex(s => s.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: 'Server not found' });
  }
  servers[index] = { ...servers[index], ...req.body };
  addLog('info', `Server updated: ${servers[index].name}`, 'server-management', { serverId: req.params.id });
  res.json(servers[index]);
});

app.delete('/api/servers/:id', (req, res) => {
  const index = servers.findIndex(s => s.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: 'Server not found' });
  }
  const server = servers[index];
  servers.splice(index, 1);
  addLog('info', `Server deleted: ${server.name}`, 'server-management', { serverId: req.params.id });
  res.json({ success: true });
});

app.post('/api/servers/:id/test', async (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) {
    return res.status(404).json({ error: 'Server not found' });
  }

  const ssh = new NodeSSH();
  
  try {
    await ssh.connect({
      host: server.host,
      port: server.port,
      username: server.username,
      privateKeyPath: server.keyPath,
      password: server.password,
    });
    
    await ssh.execCommand('echo "Connection test successful"');
    ssh.dispose();
    
    server.status = 'online';
    server.lastChecked = new Date().toISOString();
    
    addLog('info', `Connection test successful for ${server.name}`, 'connection-test', { serverId: server.id });
    res.json({ success: true, status: 'online' });
  } catch (error) {
    server.status = 'offline';
    server.lastChecked = new Date().toISOString();
    
    addLog('error', `Connection test failed for ${server.name}: ${error.message}`, 'connection-test', { 
      serverId: server.id, 
      error: error.message 
    });
    res.json({ success: false, status: 'offline', error: error.message });
  }
});

// Deployments
app.get('/api/deployments', (req, res) => {
  res.json(deployments);
});

app.post('/api/deploy', async (req, res) => {
  const config = req.body;
  const server = servers.find(s => s.id === config.serverId);
  
  if (!server) {
    return res.status(404).json({ error: 'Server not found' });
  }

  const deploymentId = Date.now().toString();
  const deployment = {
    id: deploymentId,
    serverId: server.id,
    serverName: server.name,
    repositoryUrl: config.repositoryUrl,
    branch: config.branch,
    status: 'running',
    startTime: new Date().toISOString(),
    logs: [],
    deployedBy: 'admin' // In production, get from auth
  };

  deployments.unshift(deployment);
  addLog('info', `Deployment started for ${server.name}`, 'deployment', { deploymentId, serverId: server.id });

  // Start deployment process asynchronously
  deployApp(deployment, config, server).catch(error => {
    deployment.status = 'failed';
    deployment.error = error.message;
    deployment.endTime = new Date().toISOString();
    deployment.duration = Math.floor((new Date(deployment.endTime) - new Date(deployment.startTime)) / 1000);
    
    addLog('error', `Deployment failed for ${server.name}: ${error.message}`, 'deployment', { 
      deploymentId, 
      serverId: server.id,
      error: error.message 
    });
  });

  res.json({ success: true, deploymentId });
});

async function deployApp(deployment, config, server) {
  const ssh = new NodeSSH();
  const deployLog = (message) => {
    deployment.logs.push(`[${new Date().toISOString()}] ${message}`);
    addLog('info', message, 'deployment-process', { deploymentId: deployment.id });
  };

  try {
    deployLog('Connecting to server...');
    await ssh.connect({
      host: server.host,
      port: server.port,
      username: server.username,
      privateKeyPath: server.keyPath,
      password: server.password,
    });

    deployLog('Connected successfully');

    // Create backup if requested
    if (config.backupBeforeDeploy) {
      deployLog('Creating backup...');
      const backupPath = `${config.deployPath}.backup.${Date.now()}`;
      await ssh.execCommand(`cp -r ${config.deployPath} ${backupPath}`);
      deployLog(`Backup created at ${backupPath}`);
    }

    // Run pre-deploy commands
    if (config.preDeployCommands.length > 0) {
      deployLog('Running pre-deploy commands...');
      for (const command of config.preDeployCommands) {
        deployLog(`Executing: ${command}`);
        const result = await ssh.execCommand(command);
        if (result.stderr) {
          deployLog(`Warning: ${result.stderr}`);
        }
        if (result.stdout) {
          deployLog(result.stdout);
        }
      }
    }

    // Clone/pull repository
    deployLog('Deploying application...');
    const tempDir = `/tmp/deploy-${Date.now()}`;
    
    deployLog('Cloning repository...');
    await ssh.execCommand(`git clone -b ${config.branch} ${config.repositoryUrl} ${tempDir}`);
    
    // Get commit hash
    const commitResult = await ssh.execCommand(`cd ${tempDir} && git rev-parse HEAD`);
    deployment.commitHash = commitResult.stdout.trim();

    // Build application if build command is provided
    if (config.buildCommand) {
      deployLog('Building application...');
      const buildResult = await ssh.execCommand(`cd ${tempDir} && ${config.buildCommand}`);
      if (buildResult.stderr) {
        deployLog(`Build warnings: ${buildResult.stderr}`);
      }
    }

    // Set environment variables
    if (Object.keys(config.environmentVariables).length > 0) {
      deployLog('Setting environment variables...');
      const envContent = Object.entries(config.environmentVariables)
        .map(([key, value]) => `${key}=${value}`)
        .join('\n');
      await ssh.execCommand(`echo "${envContent}" > ${tempDir}/.env`);
    }

    // Deploy files
    deployLog('Copying files to deployment directory...');
    await ssh.execCommand(`rsync -av --delete ${tempDir}/ ${config.deployPath}/`);

    // Run post-deploy commands
    if (config.postDeployCommands.length > 0) {
      deployLog('Running post-deploy commands...');
      for (const command of config.postDeployCommands) {
        deployLog(`Executing: ${command}`);
        const result = await ssh.execCommand(`cd ${config.deployPath} && ${command}`);
        if (result.stderr) {
          deployLog(`Warning: ${result.stderr}`);
        }
        if (result.stdout) {
          deployLog(result.stdout);
        }
      }
    }

    // Restart services
    if (config.restartServices.length > 0) {
      deployLog('Restarting services...');
      for (const service of config.restartServices) {
        deployLog(`Restarting ${service}...`);
        await ssh.execCommand(`sudo systemctl restart ${service}`);
      }
    }

    // Cleanup
    deployLog('Cleaning up temporary files...');
    await ssh.execCommand(`rm -rf ${tempDir}`);

    ssh.dispose();

    deployment.status = 'success';
    deployment.endTime = new Date().toISOString();
    deployment.duration = Math.floor((new Date(deployment.endTime) - new Date(deployment.startTime)) / 1000);
    
    deployLog('Deployment completed successfully!');
    addLog('info', `Deployment completed successfully for ${server.name}`, 'deployment', { 
      deploymentId: deployment.id,
      serverId: server.id,
      duration: deployment.duration
    });

  } catch (error) {
    ssh.dispose();
    deployment.status = 'failed';
    deployment.error = error.message;
    deployment.endTime = new Date().toISOString();
    deployment.duration = Math.floor((new Date(deployment.endTime) - new Date(deployment.startTime)) / 1000);
    
    deployLog(`Deployment failed: ${error.message}`);
    throw error;
  }
}

// Logs
app.get('/api/logs', (req, res) => {
  res.json(logs);
});

app.delete('/api/logs', (req, res) => {
  logs = [];
  addLog('info', 'Logs cleared', 'log-management');
  res.json({ success: true });
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../dist')));
  
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../dist/index.html'));
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  addLog('info', `Server started on port ${PORT}`, 'system');
});

export default app;