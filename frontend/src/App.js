import React from 'react';
import { Navigate } from 'react-router-dom';
import { NotificationProvider } from './context/NotificationContext';
import { FilterProvider } from './context/FilterContext';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ClientFileProvider } from './context/ClientFileContext';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Invoices from './pages/Invoices';
import Reconciliation from './pages/Reconciliation';
import Reports from './pages/Reports';
import VehicleHistory from './pages/VehicleHistory';
import Settings from './pages/Settings';
import Portfolio from './pages/Portfolio';
import Login from './pages/Login';
import Signup from './pages/Signup';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import Landing from './pages/Landing';

const queryClient = new QueryClient();

function ProtectedRoute({ children }) {
  const { user, token, loading } = useAuth();
  if (loading) return <div className="min-h-screen flex items-center justify-center">Chargement...</div>;
  if (!user || !token) return <Navigate to="/login" />;
  return children;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
      <ClientFileProvider>
      <NotificationProvider>
      <FilterProvider>
      <Router future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/reset-password" element={<ResetPassword />} />
          <Route path="/*" element={
            <ProtectedRoute>
              <Layout>
                <Routes>
                  <Route path="/portfolio" element={<Portfolio />} />
                  <Route path="/dashboard" element={<Dashboard />} />
                  <Route path="/invoices" element={<Invoices />} />
                  <Route path="/reconciliation" element={<Reconciliation />} />
                  <Route path="/reports" element={<Reports />} />
                  <Route path="/reference/:registration?" element={<VehicleHistory />} />
                  <Route path="/settings" element={<Settings />} />
                </Routes>
              </Layout>
            </ProtectedRoute>
          } />
        </Routes>
      </Router>
      </FilterProvider>
      </NotificationProvider>
      </ClientFileProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}

export default App;
