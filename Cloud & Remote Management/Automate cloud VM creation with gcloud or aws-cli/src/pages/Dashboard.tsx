import React from 'react';
import { 
  Server, 
  Play, 
  Square, 
  Cloud, 
  TrendingUp,
  Activity,
  DollarSign,
  Users
} from 'lucide-react';
import { useVM } from '../contexts/VMContext';
import { format } from 'date-fns';

const Dashboard: React.FC = () => {
  const { vms, stats } = useVM();

  const recentVMs = vms
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 5);

  const statCards = [
    {
      title: 'Total VMs',
      value: stats.total,
      icon: Server,
      color: 'bg-blue-500',
      change: '+12%',
      trend: 'up'
    },
    {
      title: 'Running',
      value: stats.running,
      icon: Play,
      color: 'bg-green-500',
      change: '+8%',
      trend: 'up'
    },
    {
      title: 'Stopped',
      value: stats.stopped,
      icon: Square,
      color: 'bg-orange-500',
      change: '-3%',
      trend: 'down'
    },
    {
      title: 'Monthly Cost',
      value: '$247',
      icon: DollarSign,
      color: 'bg-purple-500',
      change: '+5%',
      trend: 'up'
    }
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-600 mt-1">Overview of your cloud infrastructure</p>
        </div>
        <div className="flex items-center space-x-3 bg-white px-4 py-2 rounded-lg shadow-sm border">
          <Activity className="w-5 h-5 text-green-500" />
          <span className="text-sm font-medium text-gray-700">All systems operational</span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat, index) => (
          <div key={index} className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow duration-200">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600 mb-1">{stat.title}</p>
                <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
              </div>
              <div className={`${stat.color} p-3 rounded-lg`}>
                <stat.icon className="w-6 h-6 text-white" />
              </div>
            </div>
            <div className="mt-4 flex items-center">
              <TrendingUp className={`w-4 h-4 mr-1 ${
                stat.trend === 'up' ? 'text-green-500' : 'text-red-500'
              }`} />
              <span className={`text-sm font-medium ${
                stat.trend === 'up' ? 'text-green-600' : 'text-red-600'
              }`}>
                {stat.change}
              </span>
              <span className="text-sm text-gray-500 ml-1">from last month</span>
            </div>
          </div>
        ))}
      </div>

      {/* Charts and Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Provider Distribution */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Provider Distribution</h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
                <span className="text-sm font-medium text-gray-700">AWS</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-32 bg-gray-200 rounded-full h-2">
                  <div 
                    className="bg-orange-500 h-2 rounded-full" 
                    style={{ width: `${(stats.aws / stats.total) * 100}%` }}
                  ></div>
                </div>
                <span className="text-sm text-gray-600 w-8">{stats.aws}</span>
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                <span className="text-sm font-medium text-gray-700">Google Cloud</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-32 bg-gray-200 rounded-full h-2">
                  <div 
                    className="bg-blue-500 h-2 rounded-full" 
                    style={{ width: `${(stats.gcp / stats.total) * 100}%` }}
                  ></div>
                </div>
                <span className="text-sm text-gray-600 w-8">{stats.gcp}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Recent VMs */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent VMs</h3>
          <div className="space-y-3">
            {recentVMs.map((vm) => (
              <div key={vm.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center space-x-3">
                  <div className={`w-2 h-2 rounded-full ${
                    vm.status === 'running' ? 'bg-green-500' : 'bg-gray-400'
                  }`}></div>
                  <div>
                    <p className="text-sm font-medium text-gray-900">{vm.name}</p>
                    <p className="text-xs text-gray-500">{vm.provider.toUpperCase()} • {vm.region}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className={`text-xs font-medium ${
                    vm.status === 'running' ? 'text-green-600' : 'text-gray-500'
                  }`}>
                    {vm.status}
                  </p>
                  <p className="text-xs text-gray-500">
                    {format(new Date(vm.createdAt), 'MMM dd')}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl shadow-lg p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold mb-2">Ready to scale your infrastructure?</h3>
            <p className="text-blue-100">Deploy new VMs across AWS and Google Cloud with just a few clicks</p>
          </div>
          <div className="flex space-x-3">
            <button className="bg-white text-blue-600 px-4 py-2 rounded-lg font-medium hover:bg-blue-50 transition-colors duration-200">
              Create VM
            </button>
            <button className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors duration-200 border border-blue-400">
              View All
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;