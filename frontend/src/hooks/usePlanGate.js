import { useQuery } from '@tanstack/react-query';
import { fetchBillingUsage } from '../api';

export const FEATURE_PLAN_MAP = {
  reconciliation: 'pro',
  integrations: 'pro',
  whatsapp: 'pro',
  portal_client: 'pro',
  analytics: 'pro',
  audit_log: 'cabinet',
  custom_pcg: 'cabinet',
  webhooks: 'cabinet',
  auto_push: 'cabinet',
  permissions: 'reseau',
  api_access: 'reseau',
};

export const usePlanGate = () => {
  const { data: billing } = useQuery('billing-usage', fetchBillingUsage, {
    staleTime: 60000,
    retry: false,
  });

  const canAccess = (feature) => {
    if (!billing || !billing.features) return true; // Allow if billing not loaded yet
    return billing.features.includes(feature);
  };

  const getRequiredPlan = (feature) => {
    return FEATURE_PLAN_MAP[feature] || 'pro';
  };

  return { canAccess, getRequiredPlan, billing };
};
