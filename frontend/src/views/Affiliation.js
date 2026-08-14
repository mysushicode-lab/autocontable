'use client';

import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Gift, Copy, Check, Users, TrendingUp, CreditCard, ExternalLink } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import api from '../api/client';

const fetchAffiliate = async () => {
  const res = await api.get('/api/affiliates/me');
  return res.data;
};

const registerAffiliate = async () => {
  const res = await api.post('/api/affiliates/register');
  return res.data;
};

const fetchReferrals = async () => {
  const res = await api.get('/api/affiliates/referrals');
  return res.data;
};

const fetchConnectStatus = async () => {
  const res = await api.get('/api/affiliates/connect-status');
  return res.data;
};

const startConnectOnboard = async () => {
  const res = await api.post('/api/affiliates/connect-onboard');
  return res.data;
};

const Affiliation = () => {
  const queryClient = useQueryClient();
  const [copied, setCopied] = useState(false);
  const searchParams = useSearchParams();

  const { data: affiliate, isLoading, error } = useQuery({
    queryKey: ['affiliate-me'],
    queryFn: fetchAffiliate,
    retry: false,
  });

  const { data: referrals } = useQuery({
    queryKey: ['affiliate-referrals'],
    queryFn: fetchReferrals,
    enabled: !!affiliate,
  });

  const { data: connectStatus } = useQuery({
    queryKey: ['affiliate-connect-status'],
    queryFn: fetchConnectStatus,
    enabled: !!affiliate,
  });

  const registerMutation = useMutation({
    mutationFn: registerAffiliate,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['affiliate-me'] }),
  });

  const connectMutation = useMutation({
    mutationFn: startConnectOnboard,
    onSuccess: (data) => { window.location.href = data.url; },
  });

  useEffect(() => {
    if (searchParams.get('stripe') === 'complete') {
      queryClient.invalidateQueries({ queryKey: ['affiliate-connect-status'] });
    }
  }, [searchParams, queryClient]);

  const copyLink = () => {
    const url = `${window.location.origin}/signup?ref=${affiliate.code}`;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (isLoading) {
    return <div className="text-sm text-gray-500">Chargement...</div>;
  }

  if (error?.response?.status === 404) {
    return (
      <div className="max-w-lg mx-auto text-center space-y-6 flex flex-col items-center justify-center min-h-[calc(100vh-8rem)] -mt-16">
        <div className="relative w-16 h-16 mx-auto">
          <div className="w-16 h-16 rounded-full flex items-center justify-center border border-gray-200">
            <img src="/factpilot-logo.svg" alt="" className="w-9 h-9" />
          </div>
          <div className="absolute -bottom-1 -right-1 w-7 h-7 rounded-full flex items-center justify-center bg-blue-500/80 backdrop-blur-md border border-blue-400/50">
            <Gift className="w-3.5 h-3.5 text-white" />
          </div>
        </div>
        <h1 className="text-2xl font-bold text-gray-900">Programme d'affiliation</h1>
        <p className="text-gray-600">
          Gagnez 20% de commission sur chaque client que vous parrainez.
          Partagez votre lien, et recevez une commission quand ils passent sur un plan payant.
        </p>
        <button
          onClick={() => registerMutation.mutate()}
          disabled={registerMutation.isPending}
          className="px-6 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium disabled:opacity-50"
        >
          {registerMutation.isPending ? 'Inscription...' : 'Devenir affilié'}
        </button>
      </div>
    );
  }

  if (!affiliate) return null;

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <h1 className="text-xl font-bold text-gray-900">Programme d'affiliation</h1>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
            <Users className="w-4 h-4" />
            <span>Filleuls</span>
          </div>
          <p className="text-2xl font-bold">{affiliate.referrals_count}</p>
          <p className="text-xs text-gray-400">{affiliate.referrals_converted} convertis</p>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
            <TrendingUp className="w-4 h-4" />
            <span>Gagné</span>
          </div>
          <p className="text-2xl font-bold">{affiliate.total_earned.toFixed(2)} &euro;</p>
          <p className="text-xs text-gray-400">Commission {(affiliate.commission_rate * 100).toFixed(0)}%</p>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
            <Gift className="w-4 h-4" />
            <span>Payé</span>
          </div>
          <p className="text-2xl font-bold">{affiliate.total_paid.toFixed(2)} &euro;</p>
          <p className="text-xs text-gray-400">En attente: {(affiliate.total_earned - affiliate.total_paid).toFixed(2)} &euro;</p>
        </div>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <label className="text-sm font-medium text-gray-700 mb-2 block">Votre lien de parrainage</label>
        <div className="flex gap-2">
          <input
            readOnly
            value={`${typeof window !== 'undefined' ? window.location.origin : ''}/signup?ref=${affiliate.code}`}
            className="flex-1 px-3 py-2 border border-gray-200 rounded-md text-sm bg-gray-50"
          />
          <button
            onClick={copyLink}
            className="px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
          >
            {copied ? <Check className="w-4 h-4 text-green-600" /> : <Copy className="w-4 h-4 text-gray-600" />}
          </button>
        </div>
        <p className="text-xs text-gray-400 mt-2">Code: {affiliate.code}</p>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-1">
              <CreditCard className="w-4 h-4" />
              <span>Compte bancaire</span>
            </div>
            {connectStatus?.onboarding_complete ? (
              <p className="text-xs text-green-600">Connecté — les commissions sont versées automatiquement chaque mois.</p>
            ) : (
              <p className="text-xs text-gray-400">Connectez votre compte pour recevoir vos commissions automatiquement.</p>
            )}
          </div>
          {!connectStatus?.onboarding_complete && (
            <button
              onClick={() => connectMutation.mutate()}
              disabled={connectMutation.isPending}
              className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 font-medium disabled:opacity-50"
            >
              <ExternalLink className="w-3.5 h-3.5" />
              {connectMutation.isPending ? 'Chargement...' : 'Connecter ma banque'}
            </button>
          )}
        </div>
      </div>

      {referrals && referrals.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="px-4 py-3 border-b border-gray-100">
            <h2 className="text-sm font-medium text-gray-700">Historique des parrainages</h2>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Email</th>
                <th className="text-left px-4 py-2 font-medium">Statut</th>
                <th className="text-right px-4 py-2 font-medium">Commission</th>
                <th className="text-right px-4 py-2 font-medium">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {referrals.map((r) => (
                <tr key={r.id}>
                  <td className="px-4 py-2 text-gray-700">{r.email || '-'}</td>
                  <td className="px-4 py-2">
                    <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                      r.status === 'converted' ? 'bg-green-50 text-green-700' :
                      r.status === 'paid' ? 'bg-blue-50 text-blue-700' :
                      'bg-yellow-50 text-yellow-700'
                    }`}>
                      {r.status === 'converted' ? 'Converti' : r.status === 'paid' ? 'Payé' : 'En attente'}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-right text-gray-700">{r.commission_amount.toFixed(2)} &euro;</td>
                  <td className="px-4 py-2 text-right text-gray-400">{new Date(r.created_at).toLocaleDateString('fr-FR')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default Affiliation;
