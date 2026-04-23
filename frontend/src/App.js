import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Invoices from './pages/Invoices';
import Reconciliation from './pages/Reconciliation';
import Reports from './pages/Reports';
import VehicleHistory from './pages/VehicleHistory';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <Layout>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/invoices" element={<Invoices />} />
            <Route path="/reconciliation" element={<Reconciliation />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/vehicles/:registration?" element={<VehicleHistory />} />
          </Routes>
        </Layout>
      </Router>
    </QueryClientProvider>
  );
}

export default App;
