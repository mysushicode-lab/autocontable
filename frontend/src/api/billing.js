import api from './client';

export const fetchBillingUsage = async () => {
  const { data } = await api.get('/api/billing/usage');
  return data;
};

export const fetchPricingTiers = async () => {
  const { data } = await api.get('/api/billing/pricing');
  return data;
};

export const createCheckoutSession = async (planType) => {
  const response = await api.post('/api/stripe/create-checkout-session', { plan_type: planType });
  return response.data;
};

export const verifySession = async (sessionId) => {
  const response = await api.get(`/api/stripe/verify-session/${sessionId}`);
  return response.data;
};

export const createPortalSession = async () => {
  const response = await api.post('/api/stripe/create-portal-session');
  return response.data;
};

export const fetchPaymentMethods = async () => {
  const response = await api.get('/api/stripe/payment-methods');
  return response.data;
};

export const fetchStripeInvoices = async () => {
  const response = await api.get('/api/stripe/invoices');
  return response.data;
};

export const checkFeatureAccess = async (feature) => {
  const { data } = await api.get(`/api/billing/can-access/${feature}`);
  return data;
};

// Aliases for backward compatibility
export const createStripeCheckoutSession = createCheckoutSession;
export const verifyStripeSession = verifySession;
export const createStripePortalSession = createPortalSession;
export const fetchStripePaymentMethods = fetchPaymentMethods;
