import React, { useState, useEffect } from 'react';
import { Terminal, Download, Trash2, Filter, Search, RefreshCw } from 'lucide-react';
import { LogEntry } from '../types';

const LogViewer: React.FC = () => {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [filteredLogs, setFilteredLogs] = useState<LogEntry[]>([]);
  const [filterLevel, setFilterLevel] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(false);

  useEffect(() => {
    loadLogs();
  }, []);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (autoRefresh) {
      interval = setInterval(loadLogs, 5000);
    }
    return () => clearInterval(interval);
  }, [autoRefresh]);

  useEffect(() => {
    filterLogs();
  }, [logs, filterLevel, searchTerm]);

  const loadLogs = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/api/logs');
      const data = await response.json();
      setLogs(data);
    } catch (error) {
      console.error('Failed to load logs:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const filterLogs = () => {
    let filtered = logs;

    if (filterLevel !== 'all') {
      filtered = filtered.filter(log => log.level === filterLevel);
    }

    if (searchTerm) {
      filtered = filtered.filter(log =>
        log.message.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.source.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    setFilteredLogs(filtered);
  };

  const clearLogs = async () => {
    if (confirm('Are you sure you want to clear all logs?')) {
      try {
        await fetch('/api/logs', { method: 'DELETE' });
        setLogs([]);
      } catch (error) {
        console.error('Failed to clear logs:', error);
      }
    }
  };

  const downloadLogs = () => {
    const logsText = filteredLogs.map(log => 
      `[${log.timestamp}] ${log.level.toUpperCase()} ${log.source}: ${log.message}`
    ).join('\n');
    
    const blob = new Blob([logsText], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `deployment-logs-${new Date().toISOString().split('T')[0]}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const getLevelColor = (level: string) => {
    switch (level) {
      case 'error':
        return 'text-red-400 bg-red-400/10';
      case 'warn':
        return 'text-yellow-400 bg-yellow-400/10';
      case 'info':
        return 'text-blue-400 bg-blue-400/10';
      case 'debug':
        return 'text-slate-400 bg-slate-400/10';
      default:
        return 'text-slate-300 bg-slate-300/10';
    }
  };

  const getLevelIcon = (level: string) => {
    switch (level) {
      case 'error':
        return '❌';
      case 'warn':
        return '⚠️';
      case 'info':
        return 'ℹ️';
      case 'debug':
        return '🔍';
      default:
        return '📝';
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-3">
          <div className="bg-gradient-to-r from-slate-600 to-slate-500 p-2 rounded-lg">
            <Terminal className="h-5 w-5 text-white" />
          </div>
          <div>
            <h2 className="text-xl font-semibold text-white">System Logs</h2>
            <p className="text-slate-400">Monitor deployment activities and system events</p>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <label className="flex items-center space-x-2 text-sm text-slate-300">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="rounded border-slate-600 bg-slate-800 text-blue-500 focus:ring-blue-500"
            />
            <span>Auto-refresh</span>
          </label>
          
          <button
            onClick={loadLogs}
            disabled={isLoading}
            className="p-2 bg-slate-600 hover:bg-slate-500 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
          
          <button
            onClick={downloadLogs}
            className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
          >
            <Download className="h-4 w-4" />
          </button>
          
          <button
            onClick={clearLogs}
            className="p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30 mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex items-center space-x-2">
            <Filter className="h-4 w-4 text-slate-400" />
            <select
              value={filterLevel}
              onChange={(e) => setFilterLevel(e.target.value)}
              className="bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="all">All Levels</option>
              <option value="error">Error</option>
              <option value="warn">Warning</option>
              <option value="info">Info</option>
              <option value="debug">Debug</option>
            </select>
          </div>
          
          <div className="flex-1 flex items-center space-x-2">
            <Search className="h-4 w-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search logs..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
          
          <div className="text-sm text-slate-400">
            Showing {filteredLogs.length} of {logs.length} entries
          </div>
        </div>
      </div>

      {/* Logs Display */}
      <div className="bg-slate-900/50 rounded-lg border border-slate-700/50 overflow-hidden">
        {filteredLogs.length === 0 ? (
          <div className="p-8 text-center">
            <Terminal className="h-12 w-12 text-slate-600 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-slate-400 mb-2">No logs found</h3>
            <p className="text-slate-500">
              {logs.length === 0 
                ? 'No deployment logs available yet.'
                : 'No logs match your current filter criteria.'
              }
            </p>
          </div>
        ) : (
          <div className="max-h-96 overflow-y-auto">
            <div className="space-y-1">
              {filteredLogs.map((log, index) => (
                <div
                  key={index}
                  className="flex items-start space-x-3 p-3 hover:bg-slate-800/30 transition-colors"
                >
                  <div className="flex-shrink-0 text-lg">
                    {getLevelIcon(log.level)}
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center space-x-2 mb-1">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${getLevelColor(log.level)}`}>
                        {log.level.toUpperCase()}
                      </span>
                      <span className="text-xs text-slate-400 font-mono">
                        {new Date(log.timestamp).toLocaleString()}
                      </span>
                      <span className="text-xs text-slate-500">
                        {log.source}
                      </span>
                    </div>
                    
                    <p className="text-sm text-slate-200 font-mono whitespace-pre-wrap">
                      {log.message}
                    </p>
                    
                    {log.metadata && Object.keys(log.metadata).length > 0 && (
                      <details className="mt-2">
                        <summary className="text-xs text-slate-400 cursor-pointer hover:text-slate-300">
                          Show metadata
                        </summary>
                        <pre className="mt-1 text-xs text-slate-400 font-mono bg-slate-800/50 p-2 rounded">
                          {JSON.stringify(log.metadata, null, 2)}
                        </pre>
                      </details>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default LogViewer;