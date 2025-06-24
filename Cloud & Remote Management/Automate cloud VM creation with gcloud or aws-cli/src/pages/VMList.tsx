import React, { useState } from 'react';
import { 
  Server, 
  Play, 
  Square, 
  Trash2, 
  MoreVertical,
  Search,
  Filter,
  RefreshCw,
  ExternalLink,
  Copy,
  Edit
} from 'lucide-react';
import { useVM } from '../contexts/VMContext';
import { format } from 'date-fns';
import { VM, CloudProvider, VMStatus } from '../types/vm';

const VMList: React.FC = () => {
  const { vms, loading, startVM, stopVM, deleteVM } = useVM();
  const [searchTerm, setSearchTerm] = useState('');
  const [providerFilter, setProviderFilter] = useState<CloudProvider | 'all'>('all');
  const [statusFilter, setStatusFilter] = useState<VMStatus | 'all'>('all');
  const [selectedVMs, setSelectedVMs] = useState<string[]>([]);

  const filteredVMs = vms.filter(vm => {
    const matchesSearch = vm.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         vm.region.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         vm.tags.some(tag => tag.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesProvider = providerFilter === 'all' || vm.provider === providerFilter;
    const matchesStatus = statusFilter === 'all' || vm.status === statusFilter;
    
    return matchesSearch && matchesProvider && matchesStatus;
  });

  const getStatusColor = (status: VMStatus) => {
    switch (status) {
      case 'running':
        return 'bg-green-100 text-green-800 border-green-200';
      case 'stopped':
        return 'bg-gray-100 text-gray-800 border-gray-200';
      case 'pending':
        return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      case 'terminating':
        return 'bg-red-100 text-red-800 border-red-200';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  const getProviderColor = (provider: CloudProvider) => {
    return provider === 'aws' 
      ? 'bg-orange-100 text-orange-800 border-orange-200'
      : 'bg-blue-100 text-blue-800 border-blue-200';
  };

  const handleSelectVM = (vmId: string) => {
    setSelectedVMs(prev => 
      prev.includes(vmId) 
        ? prev.filter(id => id !== vmId)
        : [...prev, vmId]
    );
  };

  const handleSelectAll = () => {
    setSelectedVMs(
      selectedVMs.length === filteredVMs.length 
        ? [] 
        : filteredVMs.map(vm => vm.id)
    );
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Virtual Machines</h1>
          <p className="text-gray-600 mt-1">Manage your cloud infrastructure</p>
        </div>
        <div className="flex items-center space-x-3">
          <button className="flex items-center space-x-2 px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
            <RefreshCw className="w-4 h-4" />
            <span>Refresh</span>
          </button>
          <button className="flex items-center space-x-2 px-4 py-2 bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200">
            <Server className="w-4 h-4" />
            <span>Create VM</span>
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex flex-col lg:flex-row lg:items-center space-y-4 lg:space-y-0 lg:space-x-6">
          {/* Search */}
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Search VMs by name, region, or tags..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          {/* Provider Filter */}
          <div className="flex items-center space-x-2">
            <Filter className="w-4 h-4 text-gray-400" />
            <select
              value={providerFilter}
              onChange={(e) => setProviderFilter(e.target.value as CloudProvider | 'all')}
              className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="all">All Providers</option>
              <option value="aws">AWS</option>
              <option value="gcp">Google Cloud</option>
            </select>
          </div>

          {/* Status Filter */}
          <div className="flex items-center space-x-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as VMStatus | 'all')}
              className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="all">All Status</option>
              <option value="running">Running</option>
              <option value="stopped">Stopped</option>
              <option value="pending">Pending</option>
              <option value="terminating">Terminating</option>
            </select>
          </div>
        </div>
      </div>

      {/* VM Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={selectedVMs.length === filteredVMs.length && filteredVMs.length > 0}
                onChange={handleSelectAll}
                className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              <span className="text-sm text-gray-700">
                {selectedVMs.length > 0 ? `${selectedVMs.length} selected` : 'Select all'}
              </span>
            </label>
          </div>
          
          {selectedVMs.length > 0 && (
            <div className="flex items-center space-x-2">
              <button className="px-3 py-1 text-sm bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors">
                Start Selected
              </button>
              <button className="px-3 py-1 text-sm bg-orange-100 text-orange-700 rounded-lg hover:bg-orange-200 transition-colors">
                Stop Selected
              </button>
              <button className="px-3 py-1 text-sm bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors">
                Delete Selected
              </button>
            </div>
          )}
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  VM Details
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Provider & Region
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Instance Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  IP Addresses
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Created
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredVMs.map((vm) => (
                <tr key={vm.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-3">
                      <input
                        type="checkbox"
                        checked={selectedVMs.includes(vm.id)}
                        onChange={() => handleSelectVM(vm.id)}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <div>
                        <div className="text-sm font-medium text-gray-900">{vm.name}</div>
                        <div className="flex flex-wrap gap-1 mt-1">
                          {vm.tags.map((tag, index) => (
                            <span
                              key={index}
                              className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800"
                            >
                              {tag}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-2">
                      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium border ${getProviderColor(vm.provider)}`}>
                        {vm.provider.toUpperCase()}
                      </span>
                      <span className="text-sm text-gray-500">{vm.region}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {vm.instanceType}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="space-y-1">
                      <div className="flex items-center space-x-2">
                        <span className="text-xs text-gray-500">Public:</span>
                        {vm.publicIP ? (
                          <div className="flex items-center space-x-1">
                            <span className="text-sm text-gray-900">{vm.publicIP}</span>
                            <button
                              onClick={() => copyToClipboard(vm.publicIP!)}
                              className="text-gray-400 hover:text-gray-600"
                            >
                              <Copy className="w-3 h-3" />
                            </button>
                          </div>
                        ) : (
                          <span className="text-sm text-gray-400">N/A</span>
                        )}
                      </div>
                      <div className="flex items-center space-x-2">
                        <span className="text-xs text-gray-500">Private:</span>
                        <div className="flex items-center space-x-1">
                          <span className="text-sm text-gray-900">{vm.privateIP}</span>
                          <button
                            onClick={() => copyToClipboard(vm.privateIP)}
                            className="text-gray-400 hover:text-gray-600"
                          >
                            <Copy className="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium border ${getStatusColor(vm.status)}`}>
                      {vm.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format(new Date(vm.createdAt), 'MMM dd, yyyy')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex items-center justify-end space-x-2">
                      {vm.status === 'running' ? (
                        <button
                          onClick={() => stopVM(vm.id)}
                          className="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                          title="Stop VM"
                        >
                          <Square className="w-4 h-4" />
                        </button>
                      ) : (
                        <button
                          onClick={() => startVM(vm.id)}
                          className="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                          title="Start VM"
                        >
                          <Play className="w-4 h-4" />
                        </button>
                      )}
                      <button
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="Edit VM"
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => deleteVM(vm.id)}
                        className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Delete VM"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                      {vm.publicIP && (
                        <button
                          className="p-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors"
                          title="Connect via SSH"
                        >
                          <ExternalLink className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredVMs.length === 0 && (
          <div className="text-center py-12">
            <Server className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No VMs found</h3>
            <p className="mt-1 text-sm text-gray-500">
              {searchTerm || providerFilter !== 'all' || statusFilter !== 'all'
                ? 'Try adjusting your search or filters'
                : 'Get started by creating your first VM'}
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default VMList;