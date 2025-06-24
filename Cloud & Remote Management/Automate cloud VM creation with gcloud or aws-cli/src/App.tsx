import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import CreateVM from './pages/CreateVM';
import VMList from './pages/VMList';
import Settings from './pages/Settings';
import { VMProvider } from './contexts/VMContext';

function App() {
  return (
    <VMProvider>
      <Router>
        <Layout>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/create" element={<CreateVM />} />
            <Route path="/vms" element={<VMList />} />
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </Layout>
      </Router>
    </VMProvider>
  );
}

export default App;