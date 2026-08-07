'use client';

import ProtectedRoute from '@/components/ProtectedRoute';
import Layout from '@/components/Layout';
import { NotificationProvider } from '@/context/NotificationContext';
import { FilterProvider } from '@/context/FilterContext';
import { ClientFileProvider } from '@/context/ClientFileContext';

export default function DashboardLayout({ children }) {
  return (
    <ProtectedRoute>
      <ClientFileProvider>
        <NotificationProvider>
          <FilterProvider>
            <Layout>{children}</Layout>
          </FilterProvider>
        </NotificationProvider>
      </ClientFileProvider>
    </ProtectedRoute>
  );
}
