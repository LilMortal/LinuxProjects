import React, { useState } from 'react';
import { Play, Plus, Trash2, GitBranch, Server, Folder, Terminal, Shield, Settings } from 'lucide-react';
import { DeploymentConfig, ServerConfig } from '../types';

interface DeploymentFormProps {
  servers: ServerConfig[];
  onDeploy: (config: DeploymentConfig) => void;
  isDeploying: boolean;
}

const DeploymentForm: React.FC<DeploymentFormProps> = ({ servers, onDeploy, isDeploying }) => {
  const [config, setConfig] = useState<DeploymentConfig>({
    serverId: '',
    repositoryUrl: '',
    branch: 'main',
    buildCommand: 'npm run build',
    deployPath: '/var/www/html',
    preDeployCommands: [],
    postDeployCommands: [],
    backupBeforeDeploy: true,
    restartServices: [],
    environmentVariables: {},
    excludePatterns: ['.git', 'node_modules', '.env'],
  });

  const [newPreCommand, setNewPreCommand] = useState('');
  const [newPostCommand, setNewPostCommand] = useState('');
  const [newService, setNewService] = useState('');
  const [newEnvKey, setNewEnvKey] = useState('');
  const [newEnvValue, setNewEnvValue] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!config.serverId || !config.repositoryUrl) {
      alert('Please select a server and provide a repository URL');
      return;
    }
    onDeploy(config);
  };

  const addPreCommand = () => {
    if (newPreCommand.trim()) {
      setConfig(prev => ({
        ...prev,
        preDeployCommands: [...prev.preDeployCommands, newPreCommand.trim()]
      }));
      setNewPreCommand('');
    }
  };

  const addPostCommand = () => {
    if (newPostCommand.trim()) {
      setConfig(prev => ({
        ...prev,
        postDeployCommands: [...prev.postDeployCommands, newPostCommand.trim()]
      }));
      setNewPostCommand('');
    }
  };

  const addService = () => {
    if (newService.trim()) {
      setConfig(prev => ({
        ...prev,
        restartServices: [...prev.restartServices, newService.trim()]
      }));
      setNewService('');
    }
  };

  const addEnvironmentVariable = () => {
    if (newEnvKey.trim() && newEnvValue.trim()) {
      setConfig(prev => ({
        ...prev,
        environmentVariables: {
          ...prev.environmentVariables,
          [newEnvKey.trim()]: newEnvValue.trim()
        }
      }));
      setNewEnvKey('');
      setNewEnvValue('');
    }
  };

  const selectedServer = servers.find(s => s.id === config.serverId);

  return (
    <div className="p-6">
      <div className="flex items-center space-x-3 mb-6">
        <div className="bg-gradient-to-r from-blue-500 to-purple-500 p-2 rounded-lg">
          <Play className="h-5 w-5 text-white" />
        </div>
        <div>
          <h2 className="text-xl font-semibold text-white">Deploy Application</h2>
          <p className="text-slate-400">Configure and execute your deployment</p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Server Selection */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Server className="h-4 w-4 text-blue-400" />
            <label className="text-sm font-medium text-slate-200">Target Server</label>
          </div>
          <select
            value={config.serverId}
            onChange={(e) => setConfig(prev => ({ ...prev, serverId: e.target.value }))}
            className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            required
          >
            <option value="">Select a server...</option>
            {servers.map(server => (
              <option key={server.id} value={server.id}>
                {server.name} ({server.host})
              </option>
            ))}
          </select>
          {selectedServer && (
            <div className="mt-2 text-sm text-slate-400">
              {selectedServer.description}
            </div>
          )}
        </div>

        {/* Repository Configuration */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <GitBranch className="h-4 w-4 text-green-400" />
            <label className="text-sm font-medium text-slate-200">Repository Configuration</label>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-slate-300 mb-1">Repository URL</label>
              <input
                type="url"
                value={config.repositoryUrl}
                onChange={(e) => setConfig(prev => ({ ...prev, repositoryUrl: e.target.value }))}
                placeholder="https://github.com/user/repo.git"
                className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">Branch</label>
              <input
                type="text"
                value={config.branch}
                onChange={(e) => setConfig(prev => ({ ...prev, branch: e.target.value }))}
                placeholder="main"
                className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>

        {/* Build & Deploy Configuration */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Folder className="h-4 w-4 text-orange-400" />
            <label className="text-sm font-medium text-slate-200">Build & Deploy Configuration</label>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-slate-300 mb-1">Build Command</label>
              <input
                type="text"
                value={config.buildCommand}
                onChange={(e) => setConfig(prev => ({ ...prev, buildCommand: e.target.value }))}
                placeholder="npm run build"
                className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">Deploy Path</label>
              <input
                type="text"
                value={config.deployPath}
                onChange={(e) => setConfig(prev => ({ ...prev, deployPath: e.target.value }))}
                placeholder="/var/www/html"
                className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>
          </div>
          <div className="mt-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={config.backupBeforeDeploy}
                onChange={(e) => setConfig(prev => ({ ...prev, backupBeforeDeploy: e.target.checked }))}
                className="rounded border-slate-600 bg-slate-800 text-blue-500 focus:ring-blue-500"
              />
              <span className="text-sm text-slate-300">Create backup before deployment</span>
            </label>
          </div>
        </div>

        {/* Pre-Deploy Commands */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Terminal className="h-4 w-4 text-purple-400" />
            <label className="text-sm font-medium text-slate-200">Pre-Deploy Commands</label>
          </div>
          <div className="space-y-2">
            {config.preDeployCommands.map((command, index) => (
              <div key={index} className="flex items-center space-x-2">
                <code className="flex-1 bg-slate-800 px-3 py-2 rounded text-sm text-green-300 font-mono">
                  {command}
                </code>
                <button
                  type="button"
                  onClick={() => setConfig(prev => ({
                    ...prev,
                    preDeployCommands: prev.preDeployCommands.filter((_, i) => i !== index)
                  }))}
                  className="p-2 text-red-400 hover:bg-red-500/20 rounded"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            <div className="flex items-center space-x-2">
              <input
                type="text"
                value={newPreCommand}
                onChange={(e) => setNewPreCommand(e.target.value)}
                placeholder="Enter command..."
                className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addPreCommand())}
              />
              <button
                type="button"
                onClick={addPreCommand}
                className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
              >
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Post-Deploy Commands */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Terminal className="h-4 w-4 text-cyan-400" />
            <label className="text-sm font-medium text-slate-200">Post-Deploy Commands</label>
          </div>
          <div className="space-y-2">
            {config.postDeployCommands.map((command, index) => (
              <div key={index} className="flex items-center space-x-2">
                <code className="flex-1 bg-slate-800 px-3 py-2 rounded text-sm text-green-300 font-mono">
                  {command}
                </code>
                <button
                  type="button"
                  onClick={() => setConfig(prev => ({
                    ...prev,
                    postDeployCommands: prev.postDeployCommands.filter((_, i) => i !== index)
                  }))}
                  className="p-2 text-red-400 hover:bg-red-500/20 rounded"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            <div className="flex items-center space-x-2">
              <input
                type="text"
                value={newPostCommand}
                onChange={(e) => setNewPostCommand(e.target.value)}
                placeholder="Enter command..."
                className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addPostCommand())}
              />
              <button
                type="button"
                onClick={addPostCommand}
                className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
              >
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Services to Restart */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Settings className="h-4 w-4 text-yellow-400" />
            <label className="text-sm font-medium text-slate-200">Services to Restart</label>
          </div>
          <div className="space-y-2">
            {config.restartServices.map((service, index) => (
              <div key={index} className="flex items-center space-x-2">
                <span className="flex-1 bg-slate-800 px-3 py-2 rounded text-sm text-white">
                  {service}
                </span>
                <button
                  type="button"
                  onClick={() => setConfig(prev => ({
                    ...prev,
                    restartServices: prev.restartServices.filter((_, i) => i !== index)
                  }))}
                  className="p-2 text-red-400 hover:bg-red-500/20 rounded"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            <div className="flex items-center space-x-2">
              <input
                type="text"
                value={newService}
                onChange={(e) => setNewService(e.target.value)}
                placeholder="nginx, apache2, pm2..."
                className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addService())}
              />
              <button
                type="button"
                onClick={addService}
                className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
              >
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Environment Variables */}
        <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
          <div className="flex items-center space-x-2 mb-3">
            <Shield className="h-4 w-4 text-emerald-400" />
            <label className="text-sm font-medium text-slate-200">Environment Variables</label>
          </div>
          <div className="space-y-2">
            {Object.entries(config.environmentVariables).map(([key, value], index) => (
              <div key={index} className="flex items-center space-x-2">
                <span className="bg-slate-800 px-3 py-2 rounded text-sm text-blue-300 font-mono">
                  {key}
                </span>
                <span className="text-slate-400">=</span>
                <span className="flex-1 bg-slate-800 px-3 py-2 rounded text-sm text-white font-mono">
                  {value}
                </span>
                <button
                  type="button"
                  onClick={() => {
                    const newEnvVars = { ...config.environmentVariables };
                    delete newEnvVars[key];
                    setConfig(prev => ({ ...prev, environmentVariables: newEnvVars }));
                  }}
                  className="p-2 text-red-400 hover:bg-red-500/20 rounded"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            <div className="flex items-center space-x-2">
              <input
                type="text"
                value={newEnvKey}
                onChange={(e) => setNewEnvKey(e.target.value)}
                placeholder="Variable name..."
                className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <input
                type="text"
                value={newEnvValue}
                onChange={(e) => setNewEnvValue(e.target.value)}
                placeholder="Variable value..."
                className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addEnvironmentVariable())}
              />
              <button
                type="button"
                onClick={addEnvironmentVariable}
                className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
              >
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Deploy Button */}
        <div className="flex justify-end">
          <button
            type="submit"
            disabled={isDeploying || !config.serverId || !config.repositoryUrl}
            className="flex items-center space-x-2 px-6 py-3 bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700 disabled:from-slate-600 disabled:to-slate-700 text-white font-medium rounded-lg transition-all duration-200 disabled:cursor-not-allowed"
          >
            <Play className={`h-4 w-4 ${isDeploying ? 'animate-spin' : ''}`} />
            <span>{isDeploying ? 'Deploying...' : 'Deploy Now'}</span>
          </button>
        </div>
      </form>
    </div>
  );
};

export default DeploymentForm;