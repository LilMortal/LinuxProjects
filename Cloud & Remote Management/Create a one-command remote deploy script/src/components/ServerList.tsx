import React, { useState } from 'react';
import { Plus, Edit3, Trash2, Server, Circle, AlertCircle, CheckCircle, XCircle } from 'lucide-react';
import { ServerConfig } from '../types';

interface ServerListProps {
  servers: ServerConfig[];
  onServersChange: () => void;
}

const ServerList: React.FC<ServerListProps> = ({ servers, onServersChange }) => {
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingServer, setEditingServer] = useState<ServerConfig | null>(null);
  const [formData, setFormData] = useState<Partial<ServerConfig>>({
    name: '',
    host: '',
    port: 22,
    username: '',
    keyPath: '',
    password: '',
    description: '',
    tags: [],
  });

  const resetForm = () => {
    setFormData({
      name: '',
      host: '',
      port: 22,
      username: '',
      keyPath: '',
      password: '',
      description: '',
      tags: [],
    });
    setShowAddForm(false);
    setEditingServer(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const serverData = {
      ...formData,
      id: editingServer?.id || Date.now().toString(),
      status: 'unknown' as const,
    } as ServerConfig;

    try {
      const url = editingServer ? `/api/servers/${editingServer.id}` : '/api/servers';
      const method = editingServer ? 'PUT' : 'POST';
      
      await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(serverData),
      });
      
      onServersChange();
      resetForm();
    } catch (error) {
      console.error('Failed to save server:', error);
    }
  };

  const handleDelete = async (serverId: string) => {
    if (confirm('Are you sure you want to delete this server?')) {
      try {
        await fetch(`/api/servers/${serverId}`, { method: 'DELETE' });
        onServersChange();
      } catch (error) {
        console.error('Failed to delete server:', error);
      }
    }
  };

  const handleEdit = (server: ServerConfig) => {
    setEditingServer(server);
    setFormData(server);
    setShowAddForm(true);
  };

  const testConnection = async (serverId: string) => {
    try {
      await fetch(`/api/servers/${serverId}/test`, { method: 'POST' });
      onServersChange();
    } catch (error) {
      console.error('Failed to test connection:', error);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'online':
        return <CheckCircle className="h-4 w-4 text-green-400" />;
      case 'offline':
        return <XCircle className="h-4 w-4 text-red-400" />;
      default:
        return <AlertCircle className="h-4 w-4 text-yellow-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return 'text-green-400 bg-green-400/10 border-green-400/20';
      case 'offline':
        return 'text-red-400 bg-red-400/10 border-red-400/20';
      default:
        return 'text-yellow-400 bg-yellow-400/10 border-yellow-400/20';
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-3">
          <div className="bg-gradient-to-r from-green-500 to-blue-500 p-2 rounded-lg">
            <Server className="h-5 w-5 text-white" />
          </div>
          <div>
            <h2 className="text-xl font-semibold text-white">Server Management</h2>
            <p className="text-slate-400">Manage your deployment targets</p>
          </div>
        </div>
        <button
          onClick={() => setShowAddForm(true)}
          className="flex items-center space-x-2 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
        >
          <Plus className="h-4 w-4" />
          <span>Add Server</span>
        </button>
      </div>

      {/* Server Form */}
      {showAddForm && (
        <div className="bg-slate-700/30 p-6 rounded-lg border border-slate-600/30 mb-6">
          <h3 className="text-lg font-medium text-white mb-4">
            {editingServer ? 'Edit Server' : 'Add New Server'}
          </h3>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-slate-300 mb-1">Server Name</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm text-slate-300 mb-1">Host/IP Address</label>
                <input
                  type="text"
                  value={formData.host}
                  onChange={(e) => setFormData(prev => ({ ...prev, host: e.target.value }))}
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm text-slate-300 mb-1">Port</label>
                <input
                  type="number"
                  value={formData.port}
                  onChange={(e) => setFormData(prev => ({ ...prev, port: parseInt(e.target.value) }))}
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm text-slate-300 mb-1">Username</label>
                <input
                  type="text"
                  value={formData.username}
                  onChange={(e) => setFormData(prev => ({ ...prev, username: e.target.value }))}
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm text-slate-300 mb-1">SSH Key Path</label>
                <input
                  type="text"
                  value={formData.keyPath}
                  onChange={(e) => setFormData(prev => ({ ...prev, keyPath: e.target.value }))}
                  placeholder="~/.ssh/id_rsa"
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-300 mb-1">Password (if no key)</label>
                <input
                  type="password"
                  value={formData.password}
                  onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">Description</label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                rows={2}
                className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div className="flex justify-end space-x-3">
              <button
                type="button"
                onClick={resetForm}
                className="px-4 py-2 text-slate-400 hover:text-white transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
              >
                {editingServer ? 'Update Server' : 'Add Server'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Server List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {servers.map((server) => (
          <div key={server.id} className="bg-slate-700/30 p-4 rounded-lg border border-slate-600/30">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center space-x-3">
                <div className="bg-slate-600 p-2 rounded-lg">
                  <Server className="h-4 w-4 text-slate-300" />
                </div>
                <div>
                  <h3 className="font-medium text-white">{server.name}</h3>
                  <p className="text-sm text-slate-400">{server.host}:{server.port}</p>
                </div>
              </div>
              <div className="flex items-center space-x-1">
                <button
                  onClick={() => handleEdit(server)}
                  className="p-1 text-slate-400 hover:text-blue-400 transition-colors"
                >
                  <Edit3 className="h-4 w-4" />
                </button>
                <button
                  onClick={() => handleDelete(server.id)}
                  className="p-1 text-slate-400 hover:text-red-400 transition-colors"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-400">Status</span>
                <div className={`flex items-center space-x-1 px-2 py-1 rounded text-xs border ${getStatusColor(server.status)}`}>
                  {getStatusIcon(server.status)}
                  <span className="capitalize">{server.status}</span>
                </div>
              </div>
              
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-400">User</span>
                <span className="text-sm text-white">{server.username}</span>
              </div>

              {server.description && (
                <div className="pt-2 border-t border-slate-600/30">
                  <p className="text-sm text-slate-300">{server.description}</p>
                </div>
              )}

              {server.tags && server.tags.length > 0 && (
                <div className="flex flex-wrap gap-1 pt-2">
                  {server.tags.map((tag, index) => (
                    <span
                      key={index}
                      className="px-2 py-1 bg-blue-500/20 text-blue-300 text-xs rounded"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              )}

              <div className="pt-3 border-t border-slate-600/30">
                <button
                  onClick={() => testConnection(server.id)}
                  className="w-full px-3 py-2 bg-slate-600 hover:bg-slate-500 text-white text-sm rounded-lg transition-colors"
                >
                  Test Connection
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {servers.length === 0 && (
        <div className="text-center py-12">
          <Server className="h-12 w-12 text-slate-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-slate-400 mb-2">No servers configured</h3>
          <p className="text-slate-500 mb-4">Add your first deployment server to get started.</p>
          <button
            onClick={() => setShowAddForm(true)}
            className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
          >
            Add Your First Server
          </button>
        </div>
      )}
    </div>
  );
};

export default ServerList;