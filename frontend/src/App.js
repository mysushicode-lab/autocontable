import React from 'react';
import { NotificationProvider } from './context/NotificationContext';
import { AuthProvider, useAuth } from './context/AuthContext';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Invoices from './pages/Invoices';
import Reconciliation from './pages/Reconciliation';
import Reports from './pages/Reports';
import VehicleHistory from './pages/VehicleHistory';
import Settings from './pages/Settings';
import Login from './pages/Login';

const queryClient = new QueryClient();

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="min-h-screen flex items-center justify-center">Chargement...</div>;
  if (!user) return <Navigate to="/login" />;
  return children;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <NotificationProvider>
      <AuthProvider>
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/*" element={
            <ProtectedRoute>
              <Layout>
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/invoices" element={<Invoices />} />
                  <Route path="/reconciliation" element={<Reconciliation />} />
                  <Route path="/reports" element={<Reports />} />
                  <Route path="/vehicles/:registration?" element={<VehicleHistory />} />
                  <Route path="/settings" element={<Settings />} />
                </Routes>
              </Layout>
            </ProtectedRoute>
          } />
        </Routes>
      </Router>
      </AuthProvider>
      </NotificationProvider>
    </QueryClientProvider>
  );
}

export default App;
