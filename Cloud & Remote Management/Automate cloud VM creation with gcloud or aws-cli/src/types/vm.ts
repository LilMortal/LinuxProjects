export type CloudProvider = 'aws' | 'gcp';
export type VMStatus = 'running' | 'stopped' | 'pending' | 'terminating';

export interface VM {
  id: string;
  name: string;
  provider: CloudProvider;
  region: string;
  instanceType: string;
  status: VMStatus;
  publicIP: string | null;
  privateIP: string;
  createdAt: Date;
  tags: string[];
  keyPair?: string;
  securityGroups?: string[];
  imageId?: string;
}

export interface CreateVMRequest {
  name: string;
  provider: CloudProvider;
  region: string;
  instanceType: string;
  imageId: string;
  keyPair: string;
  securityGroups: string[];
  tags: string[];
}

export type VMAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_VMS'; payload: VM[] }
  | { type: 'ADD_VM'; payload: VM }
  | { type: 'UPDATE_VM'; payload: VM }
  | { type: 'DELETE_VM'; payload: string }
  | { type: 'UPDATE_STATS' };