import React, { useState } from 'react';
import { 
  Cloud, 
  Server, 
  Shield, 
  Key, 
  Tag,
  AlertCircle,
  CheckCircle,
  Loader
} from 'lucide-react';
import { useVM } from '../contexts/VMContext';
import { CloudProvider } from '../types/vm';

const CreateVM: React.FC = () => {
  const { createVM, loading } = useVM();
  const [formData, setFormData] = useState({
    name: '',
    provider: 'aws' as CloudProvider,
    region: '',
    instanceType: '',
    imageId: '',
    keyPair: '',
    securityGroups: [''],
    tags: [''],
  });

  const [errors, setErrors] = useState<Record<string, string>>({});
  const [success, setSuccess] = useState(false);

  const awsRegions = [
    { value: 'us-east-1', label: 'US East (N. Virginia)' },
    { value: 'us-west-2', label: 'US West (Oregon)' },
    { value: 'eu-west-1', label: 'Europe (Ireland)' },
    { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
  ];

  const gcpRegions = [
    { value: 'us-central1-a', label: 'US Central (Iowa)' },
    { value: 'us-west1-a', label: 'US West (Oregon)' },
    { value: 'europe-west1-b', label: 'Europe West (Belgium)' },
    { value: 'asia-east1-a', label: 'Asia East (Taiwan)' },
  ];

  const awsInstanceTypes = [
    { value: 't3.micro', label: 't3.micro (1 vCPU, 1 GB RAM)', cost: '$8.76/month' },
    { value: 't3.small', label: 't3.small (2 vCPU, 2 GB RAM)', cost: '$17.52/month' },
    { value: 't3.medium', label: 't3.medium (2 vCPU, 4 GB RAM)', cost: '$35.04/month' },
    { value: 't3.large', label: 't3.large (2 vCPU, 8 GB RAM)', cost: '$70.08/month' },
  ];

  const gcpInstanceTypes = [
    { value: 'n2-standard-1', label: 'n2-standard-1 (1 vCPU, 4 GB RAM)', cost: '$24.27/month' },
    { value: 'n2-standard-2', label: 'n2-standard-2 (2 vCPU, 8 GB RAM)', cost: '$48.55/month' },
    { value: 'n2-standard-4', label: 'n2-standard-4 (4 vCPU, 16 GB RAM)', cost: '$97.09/month' },
  ];

  const validateForm = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) newErrors.name = 'VM name is required';
    if (!formData.region) newErrors.region = 'Region is required';
    if (!formData.instanceType) newErrors.instanceType = 'Instance type is required';
    if (!formData.imageId.trim()) newErrors.imageId = 'Image ID is required';
    if (!formData.keyPair.trim()) newErrors.keyPair = 'Key pair is required';

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;

    setSuccess(false);
    
    const vmData = {
      ...formData,
      status: 'pending' as const,
      publicIP: null,
      privateIP: `10.0.1.${Math.floor(Math.random() * 255)}`,
      tags: formData.tags.filter(tag => tag.trim()),
      securityGroups: formData.securityGroups.filter(sg => sg.trim()),
    };

    createVM(vmData);
    setSuccess(true);
    
    // Reset form after successful submission
    setTimeout(() => {
      setFormData({
        name: '',
        provider: 'aws',
        region: '',
        instanceType: '',
        imageId: '',
        keyPair: '',
        securityGroups: [''],
        tags: [''],
      });
      setSuccess(false);
    }, 3000);
  };

  const handleArrayInput = (field: 'tags' | 'securityGroups', index: number, value: string) => {
    const newArray = [...formData[field]];
    newArray[index] = value;
    setFormData({ ...formData, [field]: newArray });
  };

  const addArrayItem = (field: 'tags' | 'securityGroups') => {
    setFormData({ 
      ...formData, 
      [field]: [...formData[field], ''] 
    });
  };

  const removeArrayItem = (field: 'tags' | 'securityGroups', index: number) => {
    const newArray = formData[field].filter((_, i) => i !== index);
    setFormData({ ...formData, [field]: newArray });
  };

  const regions = formData.provider === 'aws' ? awsRegions : gcpRegions;
  const instanceTypes = formData.provider === 'aws' ? awsInstanceTypes : gcpInstanceTypes;

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center space-x-3">
        <div className="flex items-center justify-center w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg">
          <Server className="w-6 h-6 text-white" />
        </div>
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Create New VM</h1>
          <p className="text-gray-600">Deploy a new virtual machine to AWS or Google Cloud</p>
        </div>
      </div>

      {/* Success Message */}
      {success && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 flex items-center space-x-3">
          <CheckCircle className="w-5 h-5 text-green-500" />
          <span className="text-green-700 font-medium">VM creation initiated successfully!</span>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-8">
        {/* Basic Configuration */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center">
            <Cloud className="w-5 h-5 mr-2 text-blue-500" />
            Basic Configuration
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">VM Name</label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors ${
                  errors.name ? 'border-red-300' : 'border-gray-300'
                }`}
                placeholder="e.g., web-server-prod"
              />
              {errors.name && (
                <p className="mt-1 text-sm text-red-600 flex items-center">
                  <AlertCircle className="w-4 h-4 mr-1" />
                  {errors.name}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Cloud Provider</label>
              <select
                value={formData.provider}
                onChange={(e) => setFormData({ 
                  ...formData, 
                  provider: e.target.value as CloudProvider,
                  region: '',
                  instanceType: ''
                })}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="aws">Amazon Web Services (AWS)</option>
                <option value="gcp">Google Cloud Platform (GCP)</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Region</label>
              <select
                value={formData.region}
                onChange={(e) => setFormData({ ...formData, region: e.target.value })}
                className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                  errors.region ? 'border-red-300' : 'border-gray-300'
                }`}
              >
                <option value="">Select a region</option>
                {regions.map((region) => (
                  <option key={region.value} value={region.value}>
                    {region.label}
                  </option>
                ))}
              </select>
              {errors.region && (
                <p className="mt-1 text-sm text-red-600 flex items-center">
                  <AlertCircle className="w-4 h-4 mr-1" />
                  {errors.region}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Instance Type</label>
              <select
                value={formData.instanceType}
                onChange={(e) => setFormData({ ...formData, instanceType: e.target.value })}
                className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                  errors.instanceType ? 'border-red-300' : 'border-gray-300'
                }`}
              >
                <option value="">Select instance type</option>
                {instanceTypes.map((type) => (
                  <option key={type.value} value={type.value}>
                    {type.label} - {type.cost}
                  </option>
                ))}
              </select>
              {errors.instanceType && (
                <p className="mt-1 text-sm text-red-600 flex items-center">
                  <AlertCircle className="w-4 h-4 mr-1" />
                  {errors.instanceType}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Image and Security */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center">
            <Shield className="w-5 h-5 mr-2 text-green-500" />
            Image and Security
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Image ID</label>
              <input
                type="text"
                value={formData.imageId}
                onChange={(e) => setFormData({ ...formData, imageId: e.target.value })}
                className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                  errors.imageId ? 'border-red-300' : 'border-gray-300'
                }`}
                placeholder={formData.provider === 'aws' ? 'ami-0123456789abcdef0' : 'ubuntu-2004-lts'}
              />
              {errors.imageId && (
                <p className="mt-1 text-sm text-red-600 flex items-center">
                  <AlertCircle className="w-4 h-4 mr-1" />
                  {errors.imageId}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Key Pair</label>
              <input
                type="text"
                value={formData.keyPair}
                onChange={(e) => setFormData({ ...formData, keyPair: e.target.value })}
                className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                  errors.keyPair ? 'border-red-300' : 'border-gray-300'
                }`}
                placeholder="my-key-pair"
              />
              {errors.keyPair && (
                <p className="mt-1 text-sm text-red-600 flex items-center">
                  <AlertCircle className="w-4 h-4 mr-1" />
                  {errors.keyPair}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Security Groups and Tags */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <Shield className="w-4 h-4 mr-2 text-orange-500" />
              Security Groups
            </h3>
            {formData.securityGroups.map((sg, index) => (
              <div key={index} className="flex items-center space-x-2 mb-3">
                <input
                  type="text"
                  value={sg}
                  onChange={(e) => handleArrayInput('securityGroups', index, e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="security-group-name"
                />
                {formData.securityGroups.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeArrayItem('securityGroups', index)}
                    className="px-3 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  >
                    Remove
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              onClick={() => addArrayItem('securityGroups')}
              className="text-blue-600 hover:text-blue-700 font-medium text-sm"
            >
              + Add Security Group
            </button>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <Tag className="w-4 h-4 mr-2 text-purple-500" />
              Tags
            </h3>
            {formData.tags.map((tag, index) => (
              <div key={index} className="flex items-center space-x-2 mb-3">
                <input
                  type="text"
                  value={tag}
                  onChange={(e) => handleArrayInput('tags', index, e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="tag-name"
                />
                {formData.tags.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeArrayItem('tags', index)}
                    className="px-3 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  >
                    Remove
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              onClick={() => addArrayItem('tags')}
              className="text-blue-600 hover:text-blue-700 font-medium text-sm"
            >
              + Add Tag
            </button>
          </div>
        </div>

        {/* Submit Button */}
        <div className="flex justify-end space-x-4">
          <button
            type="button"
            className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-3 bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200 font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
          >
            {loading ? (
              <>
                <Loader className="w-4 h-4 animate-spin" />
                <span>Creating VM...</span>
              </>
            ) : (
              <>
                <Server className="w-4 h-4" />
                <span>Create VM</span>
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default CreateVM;