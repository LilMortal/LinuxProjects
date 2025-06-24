export interface ServerConfig {
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  keyPath?: string;
  password?: string;
  description?: string;
  tags: string[];
  status: 'online' | 'offline' | 'unknown';
  lastChecked?: string;
}

export interface DeploymentConfig {
  serverId: string;
  repositoryUrl: string;
  branch: string;
  buildCommand?: string;
  deployPath: string;
  preDeployCommands: string[];
  postDeployCommands: string[];
  backupBeforeDeploy: boolean;
  restartServices: string[];
  environmentVariables: Record<string, string>;
  excludePatterns: string[];
}

export interface DeploymentLog {
  id: string;
  serverId: string;
  serverName: string;
  repositoryUrl: string;
  branch: string;
  status: 'pending' | 'running' | 'success' | 'failed';
  startTime: string;
  endTime?: string;
  duration?: number;
  logs: string[];
  error?: string;
  commitHash?: string;
  deployedBy: string;
}

export interface LogEntry {
  timestamp: string;
  level: 'info' | 'warn' | 'error' | 'debug';
  message: string;
  source: string;
  metadata?: Record<string, any>;
}