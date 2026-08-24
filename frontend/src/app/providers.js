'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, useEffect } from 'react';
import { AuthProvider } from '@/context/AuthContext';
import { ClientFileProvider } from '@/context/ClientFileContext';
import { initializeAnalytics } from '@/lib/services/analytics/init';

export default function Providers({ children }) {
  useEffect(() => { initializeAnalytics(); }, []);

  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: { staleTime: 60 * 1000, retry: 1 },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <ClientFileProvider>
          {children}
        </ClientFileProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}
