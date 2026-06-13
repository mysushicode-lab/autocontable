import React, { useEffect, useState } from 'react';
import { CreditCard, FileText, Plus, Trash2, AlertCircle, ExternalLink } from 'lucide-react';
import { fetchPlanStatus, fetchStripePaymentMethods, fetchStripeInvoices, createStripePortalSession } from '../../api';
import { formatDate } from '../../utils/formatHelpers';

export const SettingsBilling = () => {
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [invoices, setInvoices] = useState([]);

  const handleManageBilling = async () => {
    try {
      const { url } = await createStripePortalSession();
      if (url) window.location.href = url;
    } catch (error) {
      console.error('Failed to create portal session:', error);
      alert("Erreur lors de l'ouverture du portail de facturation.");
    }
  };

  useEffect(() => {
    const loadBillingData = async () => {
      try {
        const [planData, paymentMethodsData, invoicesData] = await Promise.all([
          fetchPlanStatus(), fetchStripePaymentMethods(), fetchStripeInvoices()
        ]);
        setPlanStatus(planData);
        setPaymentMethods(paymentMethodsData.payment_methods || []);
        setInvoices(invoicesData.invoices || []);
      } catch (error) {
        console.error('Failed to load billing data:', error);
      } finally {
        setLoading(false);
      }
    };
    loadBillingData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-5 h-5 border-2 border-gray-200 border-t-blue-500 rounded-full animate-spin" />
      </div>
    );
  }

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isPro = planStatus?.plan_type === 'paid';
  const daysRemaining = planStatus?.days_remaining || 0;

  return (
    <div className="space-y-4">

      {/* Current Plan */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Facturation</h2>
        <p className="text-xs text-gray-500 mb-6">Gérez vos informations de paiement et vos factures</p>

        <div className="flex items-center justify-between p-4 bg-gray-50 rounded-md border border-gray-200">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-md bg-blue-50 border border-blue-100 flex items-center justify-center shrink-0">
              <CreditCard className="w-4 h-4 text-blue-500" />
            </div>
            <div>
              {isPro ? (
                <>
                  <p className="text-sm font-medium text-gray-900">Plan Pro</p>
                  <p className="text-xs text-gray-500">85,90€ / mois</p>
                </>
              ) : isTrial ? (
                <>
                  <p className="text-sm font-medium text-gray-900">Essai gratuit</p>
                  <p className="text-xs text-gray-500">{daysRemaining} jour{daysRemaining > 1 ? 's' : ''} restant{daysRemaining > 1 ? 's' : ''}</p>
                </>
              ) : (
                <>
                  <p className="text-sm font-medium text-gray-900">Plan Standard</p>
                  <p className="text-xs text-gray-500">Gratuit</p>
                </>
              )}
            </div>
          </div>
          <span className={`text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded border ${
            isPro ? 'text-green-600 bg-green-50 border-green-200' : isTrial ? 'text-orange-600 bg-orange-50 border-orange-200' : 'text-gray-500 bg-gray-100 border-gray-200'
          }`}>
            {isPro ? 'Actif' : isTrial ? 'Essai' : 'Standard'}
          </span>
        </div>

        {!isTrial && !isPro && (
          <div className="mt-3 flex items-center gap-2 px-3 py-2 bg-orange-50 border border-orange-200 rounded-md text-xs text-orange-600">
            <AlertCircle className="w-3.5 h-3.5 shrink-0" />
            Votre essai gratuit est expiré. Passez au plan Pro pour continuer.
          </div>
        )}
      </div>

      {/* Payment Methods */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <div className="flex items-center justify-between mb-5">
          <div>
            <h3 className="text-sm font-semibold text-gray-900 mb-0.5">Méthodes de paiement</h3>
            <p className="text-xs text-gray-500">Cartes et moyens de paiement enregistrés</p>
          </div>
          <button onClick={handleManageBilling}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-gray-50 border border-gray-200 rounded-md text-xs font-medium text-gray-700 transition-colors">
            <ExternalLink className="w-3 h-3" />Gérer
          </button>
        </div>
        {paymentMethods.length === 0 ? (
          <p className="text-xs text-gray-400">Aucune méthode de paiement enregistrée</p>
        ) : (
          <div className="space-y-2">
            {paymentMethods.map((method) => (
              <div key={method.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-md border border-gray-100">
                <div className="flex items-center gap-3">
                  <CreditCard className="w-4 h-4 text-gray-400" />
                  <span className="text-sm text-gray-700">•••• {method.last4}</span>
                </div>
                <button className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Invoice history */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Historique des factures</h3>
        {invoices.length === 0 ? (
          <p className="text-xs text-gray-400">Aucune facture disponible</p>
        ) : (
          <div className="space-y-0.5">
            {invoices.map((invoice) => (
              <div key={invoice.id} className="flex items-center justify-between py-3 border-b border-gray-100 last:border-0">
                <div className="flex items-center gap-3">
                  <FileText className="w-3.5 h-3.5 text-gray-400 shrink-0" />
                  <div>
                    <p className="text-sm text-gray-700">{invoice.number}</p>
                    <p className="text-[10px] text-gray-400">{formatDate(new Date(invoice.date * 1000))}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-sm text-gray-900">{invoice.amount.toFixed(2)}€</span>
                  {invoice.hosted_invoice_url && (
                    <a href={invoice.hosted_invoice_url} target="_blank" rel="noopener noreferrer"
                      className="text-[10px] text-gray-400 hover:text-gray-700 transition-colors">Voir</a>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
