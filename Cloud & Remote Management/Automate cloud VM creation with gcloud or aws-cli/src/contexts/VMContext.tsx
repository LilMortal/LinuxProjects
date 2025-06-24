import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { VM, VMAction, CloudProvider } from '../types/vm';

interface VMState {
  vms: VM[];
  loading: boolean;
  error: string | null;
  stats: {
    total: number;
    running: number;
    stopped: number;
    aws: number;
    gcp: number;
  };
}

interface VMContextType extends VMState {
  dispatch: React.Dispatch<VMAction>;
  createVM: (vm: Omit<VM, 'id' | 'createdAt'>) => void;
  deleteVM: (id: string) => void;
  startVM: (id: string) => void;
  stopVM: (id: string) => void;
}

const VMContext = createContext<VMContextType | undefined>(undefined);

const initialState: VMState = {
  vms: [
    {
      id: '1',
      name: 'web-server-prod',
      provider: 'aws',
      region: 'us-east-1',
      instanceType: 't3.medium',
      status: 'running',
      publicIP: '54.123.45.67',
      privateIP: '10.0.1.15',
      createdAt: new Date('2024-01-15T10:30:00Z'),
      tags: ['production', 'web'],
    },
    {
      id: '2',
      name: 'database-staging',
      provider: 'gcp',
      region: 'us-central1-a',
      instanceType: 'n2-standard-2',
      status: 'running',
      publicIP: '35.123.45.67',
      privateIP: '10.128.0.3',
      createdAt: new Date('2024-01-14T15:45:00Z'),
      tags: ['staging', 'database'],
    },
    {
      id: '3',
      name: 'analytics-dev',
      provider: 'aws',
      region: 'us-west-2',
      instanceType: 't3.large',
      status: 'stopped',
      publicIP: null,
      privateIP: '10.0.2.20',
      createdAt: new Date('2024-01-12T09:15:00Z'),
      tags: ['development', 'analytics'],
    },
  ],
  loading: false,
  error: null,
  stats: {
    total: 0,
    running: 0,
    stopped: 0,
    aws: 0,
    gcp: 0,
  },
};

function vmReducer(state: VMState, action: VMAction): VMState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload, loading: false };
    case 'SET_VMS':
      return { ...state, vms: action.payload, loading: false };
    case 'ADD_VM':
      return { ...state, vms: [...state.vms, action.payload] };
    case 'UPDATE_VM':
      return {
        ...state,
        vms: state.vms.map(vm => vm.id === action.payload.id ? action.payload : vm),
      };
    case 'DELETE_VM':
      return {
        ...state,
        vms: state.vms.filter(vm => vm.id !== action.payload),
      };
    case 'UPDATE_STATS':
      const stats = state.vms.reduce(
        (acc, vm) => ({
          total: acc.total + 1,
          running: acc.running + (vm.status === 'running' ? 1 : 0),
          stopped: acc.stopped + (vm.status === 'stopped' ? 1 : 0),
          aws: acc.aws + (vm.provider === 'aws' ? 1 : 0),
          gcp: acc.gcp + (vm.provider === 'gcp' ? 1 : 0),
        }),
        { total: 0, running: 0, stopped: 0, aws: 0, gcp: 0 }
      );
      return { ...state, stats };
    default:
      return state;
  }
}

export function VMProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(vmReducer, initialState);

  useEffect(() => {
    dispatch({ type: 'UPDATE_STATS' });
  }, [state.vms]);

  const createVM = (vmData: Omit<VM, 'id' | 'createdAt'>) => {
    dispatch({ type: 'SET_LOADING', payload: true });
    
    // Simulate API call
    setTimeout(() => {
      const newVM: VM = {
        ...vmData,
        id: Date.now().toString(),
        createdAt: new Date(),
      };
      dispatch({ type: 'ADD_VM', payload: newVM });
      dispatch({ type: 'SET_LOADING', payload: false });
    }, 2000);
  };

  const deleteVM = (id: string) => {
    dispatch({ type: 'SET_LOADING', payload: true });
    
    setTimeout(() => {
      dispatch({ type: 'DELETE_VM', payload: id });
      dispatch({ type: 'SET_LOADING', payload: false });
    }, 1000);
  };

  const startVM = (id: string) => {
    const vm = state.vms.find(v => v.id === id);
    if (vm) {
      dispatch({
        type: 'UPDATE_VM',
        payload: { ...vm, status: 'running' },
      });
    }
  };

  const stopVM = (id: string) => {
    const vm = state.vms.find(v => v.id === id);
    if (vm) {
      dispatch({
        type: 'UPDATE_VM',
        payload: { ...vm, status: 'stopped' },
      });
    }
  };

  return (
    <VMContext.Provider value={{
      ...state,
      dispatch,
      createVM,
      deleteVM,
      startVM,
      stopVM,
    }}>
      {children}
    </VMContext.Provider>
  );
}

export function useVM() {
  const context = useContext(VMContext);
  if (context === undefined) {
    throw new Error('useVM must be used within a VMProvider');
  }
  return context;
}