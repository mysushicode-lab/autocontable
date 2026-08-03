import React, { useEffect, useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
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
import Landing from './pages/landing';
import AuditLog from './pages/AuditLog';
import Integrations from './pages/Integrations';
import ClientPortal from './pages/ClientPortal';
import Onboarding from './pages/Onboarding';
import { getOnboardingStatus } from './api';
import Analytics from './pages/Analytics';
import PublicUpload from './pages/PublicUpload';

const queryClient = new QueryClient();

function ProtectedRoute({ children }) {
  const { user, token, loading } = useAuth();
  const navigate = useNavigate();
  const [checkingOnboarding, setCheckingOnboarding] = useState(true);
  const [onboardingComplete, setOnboardingComplete] = useState(false);

  useEffect(() => {
    if (user && token) {
      getOnboardingStatus()
        .then(data => {
          setOnboardingComplete(data.completed);
          if (!data.completed && window.location.pathname !== '/onboarding') {
            navigate('/onboarding');
          }
        })
        .catch(() => {
          setOnboardingComplete(true);
        })
        .finally(() => setCheckingOnboarding(false));
    }
  }, [user, token, navigate]);

  if (loading || checkingOnboarding) return <div className="min-h-screen flex items-center justify-center">Chargement...</div>;
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
          <Route path="/depot/:token" element={<PublicUpload />} />
          <Route path="/onboarding" element={
            <ProtectedRoute>
              <Onboarding />
            </ProtectedRoute>
          } />
          <Route path="/*" element={
            <ProtectedRoute>
              <Layout>
                <Routes>
                  <Route path="/portal" element={<ClientPortal />} />
                  <Route path="/portfolio" element={<Portfolio />} />
                  <Route path="/dashboard" element={<Dashboard />} />
                  <Route path="/invoices" element={<Invoices />} />
                  <Route path="/reconciliation" element={<Reconciliation />} />
                  <Route path="/integrations" element={<Integrations />} />
                  <Route path="/reports" element={<Reports />} />
                  <Route path="/analytics" element={<Analytics />} />
                  <Route path="/reference/:registration?" element={<VehicleHistory />} />
                  <Route path="/settings" element={<Settings />} />
                  <Route path="/audit" element={<AuditLog />} />
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
