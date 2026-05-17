import React, { useEffect, useState } from 'react';
import { CreditCard, FileText, Plus, Trash2, AlertCircle } from 'lucide-react';
import { fetchPlanStatus, fetchStripePaymentMethods, fetchStripeInvoices, createStripePortalSession } from '../../api';

export const SettingsBilling = () => {
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [invoices, setInvoices] = useState([]);

  const handleManageBilling = async () => {
    try {
      const { url } = await createStripePortalSession();
      if (url) {
        window.location.href = url;
      }
    } catch (error) {
      console.error('Failed to create portal session:', error);
      alert('Erreur lors de l\'ouverture du portail de facturation.');
    }
  };

  useEffect(() => {
    const loadBillingData = async () => {
      try {
        const [planData, paymentMethodsData, invoicesData] = await Promise.all([
          fetchPlanStatus(),
          fetchStripePaymentMethods(),
          fetchStripeInvoices()
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
    return <div className="text-sm text-gray-500">Chargement...</div>;
  }

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isPro = planStatus?.plan_type === 'paid';
  const daysRemaining = planStatus?.days_remaining || 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Facturation</h2>
        <p className="text-sm text-gray-500 mt-1">Gérez vos informations de paiement et vos factures</p>
      </div>

      {/* Current Plan */}
      <div className="p-5 bg-white/70 backdrop-blur-md rounded-xl border border-gray-200">
        <h3 className="font-semibold text-gray-900 mb-3">Abonnement actuel</h3>
        {isPro ? (
          <div className="flex items-center gap-2 text-blue-600">
            <span className="font-medium">Plan Pro — 85,90€/mois</span>
          </div>
        ) : isTrial ? (
          <div className="flex items-center gap-2 text-orange-600">
            <AlertCircle className="w-5 h-5" />
            <span className="font-medium">Essai gratuit — {daysRemaining} jour{daysRemaining > 1 ? 's' : ''} restant{daysRemaining > 1 ? 's' : ''}</span>
          </div>
        ) : (
          <div className="text-gray-600">
            <span className="font-medium">Plan Standard</span>
          </div>
        )}
      </div>

      {/* Payment Methods */}
      <div className="p-5 bg-white/70 backdrop-blur-md rounded-xl border border-gray-200">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold text-gray-900">Méthodes de paiement</h3>
          <button onClick={handleManageBilling} className="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-700">
            <Plus className="w-4 h-4" />
            Gérer
          </button>
        </div>
        {paymentMethods.length === 0 ? (
          <p className="text-sm text-gray-500">Aucune méthode de paiement enregistrée</p>
        ) : (
          <div className="space-y-2">
            {paymentMethods.map((method) => (
              <div key={method.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <CreditCard className="w-5 h-5 text-gray-400" />
                  <span className="text-sm text-gray-700">•••• {method.last4}</span>
                </div>
                <button className="text-red-500 hover:text-red-600">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Invoices */}
      <div className="p-5 bg-white/70 backdrop-blur-md rounded-xl border border-gray-200">
        <h3 className="font-semibold text-gray-900 mb-3">Factures</h3>
        {invoices.length === 0 ? (
          <p className="text-sm text-gray-500">Aucune facture disponible</p>
        ) : (
          <div className="space-y-2">
            {invoices.map((invoice) => (
              <div key={invoice.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <FileText className="w-5 h-5 text-gray-400" />
                  <div>
                    <span className="text-sm text-gray-700">{invoice.number}</span>
                    <p className="text-xs text-gray-500">
                      {new Date(invoice.date * 1000).toLocaleDateString('fr-FR')}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-medium text-gray-900">
                    {invoice.amount.toFixed(2)}€
                  </span>
                  {invoice.hosted_invoice_url && (
                    <a
                      href={invoice.hosted_invoice_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:text-blue-700 text-sm"
                    >
                      Voir
                    </a>
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
