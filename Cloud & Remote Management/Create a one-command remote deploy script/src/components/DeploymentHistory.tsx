import React from 'react';
import { Activity, CheckCircle, XCircle, Clock, GitBranch, User, Calendar, Timer } from 'lucide-react';
import { DeploymentLog } from '../types';

interface DeploymentHistoryProps {
  deployments: DeploymentLog[];
}

const DeploymentHistory: React.FC<DeploymentHistoryProps> = ({ deployments }) => {
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'success':
        return <CheckCircle className="h-4 w-4 text-green-400" />;
      case 'failed':
        return <XCircle className="h-4 w-4 text-red-400" />;
      case 'running':
        return <Clock className="h-4 w-4 text-blue-400 animate-spin" />;
      default:
        return <Clock className="h-4 w-4 text-yellow-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'success':
        return 'text-green-400 bg-green-400/10 border-green-400/20';
      case 'failed':
        return 'text-red-400 bg-red-400/10 border-red-400/20';
      case 'running':
        return 'text-blue-400 bg-blue-400/10 border-blue-400/20';
      default:
        return 'text-yellow-400 bg-yellow-400/10 border-yellow-400/20';
    }
  };

  const formatDuration = (seconds: number) => {
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  };

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  return (
    <div className="p-6">
      <div className="flex items-center space-x-3 mb-6">
        <div className="bg-gradient-to-r from-purple-500 to-pink-500 p-2 rounded-lg">
          <Activity className="h-5 w-5 text-white" />
        </div>
        <div>
          <h2 className="text-xl font-semibold text-white">Deployment History</h2>
          <p className="text-slate-400">Track your deployment activities</p>
        </div>
      </div>

      {deployments.length === 0 ? (
        <div className="text-center py-12">
          <Activity className="h-12 w-12 text-slate-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-slate-400 mb-2">No deployments yet</h3>
          <p className="text-slate-500">Your deployment history will appear here once you start deploying.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {deployments.map((deployment) => (
            <div key={deployment.id} className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center space-x-3">
                  <div className={`flex items-center space-x-1 px-2 py-1 rounded text-xs border ${getStatusColor(deployment.status)}`}>
                    {getStatusIcon(deployment.status)}
                    <span className="capitalize">{deployment.status}</span>
                  </div>
                  <div>
                    <h3 className="font-medium text-white">{deployment.serverName}</h3>
                    <p className="text-sm text-slate-400">
                      {deployment.repositoryUrl.split('/').pop()?.replace('.git', '')}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <div className="flex items-center space-x-1 text-sm text-slate-400">
                    <Calendar className="h-3 w-3" />
                    <span>{formatTimestamp(deployment.startTime)}</span>
                  </div>
                  {deployment.duration && (
                    <div className="flex items-center space-x-1 text-sm text-slate-400 mt-1">
                      <Timer className="h-3 w-3" />
                      <span>{formatDuration(deployment.duration)}</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-3">
                <div className="flex items-center space-x-2">
                  <GitBranch className="h-4 w-4 text-slate-400" />
                  <div>
                    <p className="text-sm text-slate-400">Branch</p>
                    <p className="text-sm text-white font-mono">{deployment.branch}</p>
                  </div>
                </div>
                
                {deployment.commitHash && (
                  <div className="flex items-center space-x-2">
                    <div className="w-4 h-4 bg-slate-600 rounded-full"></div>
                    <div>
                      <p className="text-sm text-slate-400">Commit</p>
                      <p className="text-sm text-white font-mono">{deployment.commitHash.substring(0, 8)}</p>
                    </div>
                  </div>
                )}

                <div className="flex items-center space-x-2">
                  <User className="h-4 w-4 text-slate-400" />
                  <div>
                    <p className="text-sm text-slate-400">Deployed by</p>
                    <p className="text-sm text-white">{deployment.deployedBy}</p>
                  </div>
                </div>
              </div>

              {deployment.error && (
                <div className="bg-red-900/20 border border-red-500/30 rounded-lg p-3 mb-3">
                  <p className="text-sm text-red-300 font-medium mb-1">Error:</p>
                  <p className="text-sm text-red-200 font-mono">{deployment.error}</p>
                </div>
              )}

              {deployment.logs && deployment.logs.length > 0 && (
                <details className="bg-slate-800/50 rounded-lg">
                  <summary className="p-3 cursor-pointer text-sm text-slate-300 hover:text-white">
                    View Deployment Logs ({deployment.logs.length} entries)
                  </summary>
                  <div className="px-3 pb-3 max-h-64 overflow-y-auto">
                    <pre className="text-xs text-slate-300 font-mono whitespace-pre-wrap">
                      {deployment.logs.join('\n')}
                    </pre>
                  </div>
                </details>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default DeploymentHistory;