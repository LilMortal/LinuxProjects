import React, { useState, useEffect } from 'react';
import { Server, Play, Settings, Activity, Shield, Terminal, Plus, Trash2, Edit3, CheckCircle, XCircle, Clock, AlertTriangle } from 'lucide-react';
import DeploymentForm from './components/DeploymentForm';
import ServerList from './components/ServerList';
import DeploymentHistory from './components/DeploymentHistory';
import LogViewer from './components/LogViewer';
import { DeploymentConfig, DeploymentLog, ServerConfig } from './types';

function App() {
  const [activeTab, setActiveTab] = useState('deploy');
  const [servers, setServers] = useState<ServerConfig[]>([]);
  const [deployments, setDeployments] = useState<DeploymentLog[]>([]);
  const [isDeploying, setIsDeploying] = useState(false);
  const [deploymentStatus, setDeploymentStatus] = useState<string>('');

  useEffect(() => {
    loadServers();
    loadDeploymentHistory();
  }, []);

  const loadServers = async () => {
    try {
      const response = await fetch('/api/servers');
      const data = await response.json();
      setServers(data);
    } catch (error) {
      console.error('Failed to load servers:', error);
    }
  };

  const loadDeploymentHistory = async () => {
    try {
      const response = await fetch('/api/deployments');
      const data = await response.json();
      setDeployments(data);
    } catch (error) {
      console.error('Failed to load deployment history:', error);
    }
  };

  const handleDeploy = async (config: DeploymentConfig) => {
    setIsDeploying(true);
    setDeploymentStatus('Initializing deployment...');
    
    try {
      const response = await fetch('/api/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(config),
      });
      
      const result = await response.json();
      
      if (response.ok) {
        setDeploymentStatus('Deployment completed successfully!');
        loadDeploymentHistory();
      } else {
        setDeploymentStatus(`Deployment failed: ${result.error}`);
      }
    } catch (error) {
      setDeploymentStatus(`Deployment error: ${error}`);
    } finally {
      setIsDeploying(false);
    }
  };

  const tabs = [
    { id: 'deploy', label: 'Deploy', icon: Play },
    { id: 'servers', label: 'Servers', icon: Server },
    { id: 'history', label: 'History', icon: Activity },
    { id: 'logs', label: 'Logs', icon: Terminal },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      {/* Header */}
      <header className="bg-slate-800/50 backdrop-blur-lg border-b border-slate-700/50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-3">
              <div className="bg-gradient-to-r from-blue-500 to-cyan-500 p-2 rounded-lg">
                <Server className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-white">RemoteDeploy</h1>
                <p className="text-sm text-slate-400">One-Command Deployment System</p>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <div className="flex items-center space-x-2 bg-slate-700/50 px-3 py-1 rounded-full">
                <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                <span className="text-sm text-slate-300">System Online</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav className="bg-slate-800/30 backdrop-blur-sm border-b border-slate-700/30">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 px-3 py-4 text-sm font-medium border-b-2 transition-all duration-200 ${
                    activeTab === tab.id
                      ? 'border-blue-400 text-blue-400'
                      : 'border-transparent text-slate-400 hover:text-slate-300 hover:border-slate-600'
                  }`}
                >
                  <Icon className="h-4 w-4" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Deployment Status */}
        {(isDeploying || deploymentStatus) && (
          <div className="mb-8">
            <div className={`p-4 rounded-lg border ${
              isDeploying 
                ? 'bg-blue-900/20 border-blue-500/30 text-blue-200'
                : deploymentStatus.includes('success')
                ? 'bg-green-900/20 border-green-500/30 text-green-200'
                : 'bg-red-900/20 border-red-500/30 text-red-200'
            }`}>
              <div className="flex items-center space-x-3">
                {isDeploying ? (
                  <Clock className="h-5 w-5 animate-spin" />
                ) : deploymentStatus.includes('success') ? (
                  <CheckCircle className="h-5 w-5" />
                ) : (
                  <XCircle className="h-5 w-5" />
                )}
                <span className="font-medium">{deploymentStatus}</span>
              </div>
            </div>
          </div>
        )}

        {/* Tab Content */}
        <div className="bg-slate-800/50 backdrop-blur-lg rounded-xl border border-slate-700/50 overflow-hidden">
          {activeTab === 'deploy' && (
            <DeploymentForm
              servers={servers}
              onDeploy={handleDeploy}
              isDeploying={isDeploying}
            />
          )}
          
          {activeTab === 'servers' && (
            <ServerList
              servers={servers}
              onServersChange={loadServers}
            />
          )}
          
          {activeTab === 'history' && (
            <DeploymentHistory deployments={deployments} />
          )}
          
          {activeTab === 'logs' && (
            <LogViewer />
          )}
        </div>
      </main>
    </div>
  );
}

export default App;