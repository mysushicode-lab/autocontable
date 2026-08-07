import { useQuery } from '@tanstack/react-query';
import { fetchBillingUsage } from '../api';

export const FEATURE_PLAN_MAP = {
  reconciliation: 'starter',
  integrations: 'pro',
  whatsapp: 'pro',
  portal_client: 'pro',
  analytics: 'pro',
  audit_log: 'cabinet',
  custom_pcg: 'reseau',
  webhooks: 'reseau',
  auto_push: 'cabinet',
  permissions: 'cabinet',
  api_access: 'cabinet',
};

export const usePlanGate = () => {
  const { data: billing, isLoading } = useQuery({
    queryKey: ['billing-usage'],
    queryFn: fetchBillingUsage,
    staleTime: 60000,
    retry: false
  });

  const canAccess = (feature) => {
    if (!billing || !billing.features) return false;
    return billing.features.includes(feature);
  };

  const getRequiredPlan = (feature) => {
    return FEATURE_PLAN_MAP[feature] || 'pro';
  };

  return { canAccess, getRequiredPlan, billing, isLoading };
};
