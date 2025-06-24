import React, { useState } from 'react';
import { 
  Settings as SettingsIcon, 
  Key, 
  Cloud, 
  Shield, 
  Bell,
  Save,
  TestTube,
  AlertCircle,
  CheckCircle,
  Eye,
  EyeOff
} from 'lucide-react';

const Settings: React.FC = () => {
  const [activeTab, setActiveTab] = useState('credentials');
  const [showAwsSecret, setShowAwsSecret] = useState(false);
  const [showGcpKey, setShowGcpKey] = useState(false);
  const [settings, setSettings] = useState({
    aws: {
      accessKeyId: 'AKIA***************',
      secretAccessKey: '************************',
      region: 'us-east-1',
    },
    gcp: {
      projectId: 'my-cloud-project',
      serviceAccountKey: '************************',
      region: 'us-central1',
    },
    notifications: {
      emailAlerts: true,
      slackWebhook: '',
      vmStatusChanges: true,
      costAlerts: true,
      costThreshold: 100,
    },
    security: {
      sessionTimeout: 30,
      requireMfa: false,
      ipWhitelist: '',
      auditLogging: true,
    },
  });

  const [testResults, setTestResults] = useState<Record<string, 'success' | 'error' | null>>({
    aws: null,
    gcp: null,
  });

  const tabs = [
    { id: 'credentials', label: 'Cloud Credentials', icon: Key },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'security', label: 'Security', icon: Shield },
  ];

  const handleInputChange = (section: string, field: string, value: string | boolean | number) => {
    setSettings(prev => ({
      ...prev,
      [section]: {
        ...prev[section as keyof typeof prev],
        [field]: value,
      },
    }));
  };

  const testConnection = async (provider: 'aws' | 'gcp') => {
    setTestResults(prev => ({ ...prev, [provider]: null }));
    
    // Simulate API test
    setTimeout(() => {
      const success = Math.random() > 0.3; // 70% success rate for demo
      setTestResults(prev => ({ 
        ...prev, 
        [provider]: success ? 'success' : 'error' 
      }));
    }, 2000);
  };

  const saveSettings = () => {
    // Simulate save operation
    console.log('Settings saved:', settings);
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center space-x-3">
        <div className="flex items-center justify-center w-10 h-10 bg-gradient-to-r from-purple-500 to-pink-600 rounded-lg">
          <SettingsIcon className="w-6 h-6 text-white" />
        </div>
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Settings</h1>
          <p className="text-gray-600">Configure your cloud automation preferences</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Navigation */}
        <div className="lg:col-span-1">
          <nav className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <ul className="space-y-2">
              {tabs.map((tab) => (
                <li key={tab.id}>
                  <button
                    onClick={() => setActiveTab(tab.id)}
                    className={`w-full flex items-center space-x-3 px-4 py-3 text-left rounded-lg transition-colors ${
                      activeTab === tab.id
                        ? 'bg-gradient-to-r from-blue-500 to-purple-600 text-white'
                        : 'text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    <tab.icon className="w-5 h-5" />
                    <span className="font-medium">{tab.label}</span>
                  </button>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        {/* Content */}
        <div className="lg:col-span-3">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            {activeTab === 'credentials' && (
              <div className="space-y-8">
                <div>
                  <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center">
                    <Cloud className="w-5 h-5 mr-2 text-blue-500" />
                    Cloud Credentials
                  </h2>
                  
                  {/* AWS Credentials */}
                  <div className="bg-orange-50 border border-orange-200 rounded-lg p-6 mb-6">
                    <div className="flex items-center justify-between mb-4">
                      <h3 className="text-lg font-medium text-gray-900 flex items-center">
                        <div className="w-6 h-6 bg-orange-500 rounded mr-2"></div>
                        Amazon Web Services
                      </h3>
                      <div className="flex items-center space-x-2">
                        <button
                          onClick={() => testConnection('aws')}
                          className="px-3 py-1 text-sm bg-orange-100 text-orange-700 rounded-lg hover:bg-orange-200 transition-colors flex items-center space-x-1"
                        >
                          <TestTube className="w-4 h-4" />
                          <span>Test</span>
                        </button>
                        {testResults.aws === 'success' && (
                          <CheckCircle className="w-5 h-5 text-green-500" />
                        )}
                        {testResults.aws === 'error' && (
                          <AlertCircle className="w-5 h-5 text-red-500" />
                        )}
                      </div>
                    </div>
                    
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Access Key ID
                        </label>
                        <input
                          type="text"
                          value={settings.aws.accessKeyId}
                          onChange={(e) => handleInputChange('aws', 'accessKeyId', e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Secret Access Key
                        </label>
                        <div className="relative">
                          <input
                            type={showAwsSecret ? 'text' : 'password'}
                            value={settings.aws.secretAccessKey}
                            onChange={(e) => handleInputChange('aws', 'secretAccessKey', e.target.value)}
                            className="w-full px-4 py-3 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                          />
                          <button
                            type="button"
                            onClick={() => setShowAwsSecret(!showAwsSecret)}
                            className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                          >
                            {showAwsSecret ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                          </button>
                        </div>
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Default Region
                        </label>
                        <select
                          value={settings.aws.region}
                          onChange={(e) => handleInputChange('aws', 'region', e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                        >
                          <option value="us-east-1">US East (N. Virginia)</option>
                          <option value="us-west-2">US West (Oregon)</option>
                          <option value="eu-west-1">Europe (Ireland)</option>
                          <option value="ap-southeast-1">Asia Pacific (Singapore)</option>
                        </select>
                      </div>
                    </div>
                  </div>

                  {/* GCP Credentials */}
                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
                    <div className="flex items-center justify-between mb-4">
                      <h3 className="text-lg font-medium text-gray-900 flex items-center">
                        <div className="w-6 h-6 bg-blue-500 rounded mr-2"></div>
                        Google Cloud Platform
                      </h3>
                      <div className="flex items-center space-x-2">
                        <button
                          onClick={() => testConnection('gcp')}
                          className="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors flex items-center space-x-1"
                        >
                          <TestTube className="w-4 h-4" />
                          <span>Test</span>
                        </button>
                        {testResults.gcp === 'success' && (
                          <CheckCircle className="w-5 h-5 text-green-500" />
                        )}
                        {testResults.gcp === 'error' && (
                          <AlertCircle className="w-5 h-5 text-red-500" />
                        )}
                      </div>
                    </div>
                    
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Project ID
                        </label>
                        <input
                          type="text"
                          value={settings.gcp.projectId}
                          onChange={(e) => handleInputChange('gcp', 'projectId', e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Default Region
                        </label>
                        <select
                          value={settings.gcp.region}
                          onChange={(e) => handleInputChange('gcp', 'region', e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        >
                          <option value="us-central1">US Central (Iowa)</option>
                          <option value="us-west1">US West (Oregon)</option>
                          <option value="europe-west1">Europe West (Belgium)</option>
                          <option value="asia-east1">Asia East (Taiwan)</option>
                        </select>
                      </div>
                      <div className="md:col-span-2">
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Service Account Key (JSON)
                        </label>
                        <div className="relative">
                          <textarea
                            rows={4}
                            value={settings.gcp.serviceAccountKey}
                            onChange={(e) => handleInputChange('gcp', 'serviceAccountKey', e.target.value)}
                            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            placeholder="Paste your service account key JSON here..."
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'notifications' && (
              <div className="space-y-6">
                <div>
                  <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center">
                    <Bell className="w-5 h-5 mr-2 text-purple-500" />
                    Notification Settings
                  </h2>
                  
                  <div className="space-y-6">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-medium text-gray-900">Email Alerts</h3>
                        <p className="text-sm text-gray-500">Receive email notifications for important events</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.notifications.emailAlerts}
                          onChange={(e) => handleInputChange('notifications', 'emailAlerts', e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Slack Webhook URL
                      </label>
                      <input
                        type="url"
                        value={settings.notifications.slackWebhook}
                        onChange={(e) => handleInputChange('notifications', 'slackWebhook', e.target.value)}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        placeholder="https://hooks.slack.com/services/..."
                      />
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-medium text-gray-900">VM Status Changes</h3>
                        <p className="text-sm text-gray-500">Get notified when VMs start, stop, or fail</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.notifications.vmStatusChanges}
                          onChange={(e) => handleInputChange('notifications', 'vmStatusChanges', e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-medium text-gray-900">Cost Alerts</h3>
                        <p className="text-sm text-gray-500">Receive alerts when spending exceeds threshold</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.notifications.costAlerts}
                          onChange={(e) => handleInputChange('notifications', 'costAlerts', e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>

                    {settings.notifications.costAlerts && (
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          Monthly Cost Threshold ($)
                        </label>
                        <input
                          type="number"
                          value={settings.notifications.costThreshold}
                          onChange={(e) => handleInputChange('notifications', 'costThreshold', parseInt(e.target.value))}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                          min="0"
                        />
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'security' && (
              <div className="space-y-6">
                <div>
                  <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center">
                    <Shield className="w-5 h-5 mr-2 text-green-500" />
                    Security Settings
                  </h2>
                  
                  <div className="space-y-6">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Session Timeout (minutes)
                      </label>
                      <select
                        value={settings.security.sessionTimeout}
                        onChange={(e) => handleInputChange('security', 'sessionTimeout', parseInt(e.target.value))}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value={15}>15 minutes</option>
                        <option value={30}>30 minutes</option>
                        <option value={60}>1 hour</option>
                        <option value={240}>4 hours</option>
                      </select>
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-medium text-gray-900">Require Multi-Factor Authentication</h3>
                        <p className="text-sm text-gray-500">Add an extra layer of security to your account</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.security.requireMfa}
                          onChange={(e) => handleInputChange('security', 'requireMfa', e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        IP Whitelist (comma-separated)
                      </label>
                      <textarea
                        rows={3}
                        value={settings.security.ipWhitelist}
                        onChange={(e) => handleInputChange('security', 'ipWhitelist', e.target.value)}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        placeholder="192.168.1.0/24, 10.0.0.0/8"
                      />
                      <p className="mt-1 text-sm text-gray-500">
                        Leave empty to allow access from any IP address
                      </p>
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-medium text-gray-900">Audit Logging</h3>
                        <p className="text-sm text-gray-500">Log all user actions for security auditing</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={settings.security.auditLogging}
                          onChange={(e) => handleInputChange('security', 'auditLogging', e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Save Button */}
            <div className="mt-8 pt-6 border-t border-gray-200">
              <div className="flex justify-end">
                <button
                  onClick={saveSettings}
                  className="px-6 py-3 bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200 font-medium flex items-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>Save Settings</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;