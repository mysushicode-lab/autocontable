import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { useParams } from 'react-router-dom';
import {
  Car,
  FileText,
  Wrench,
  Calendar,
  DollarSign,
  Search,
  ArrowLeft,
  Download
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';
import { fetchVehicleHistory } from '../api';

const VehicleHistory = () => {
  const { registration } = useParams();
  const [searchPlate, setSearchPlate] = useState(registration || '');
  const [activeRegistration, setActiveRegistration] = useState(registration || '');

  const { data: currentVehicle, isFetching, isError } = useQuery(
    ['vehicle-history', activeRegistration],
    () => fetchVehicleHistory(activeRegistration),
    { enabled: !!activeRegistration }
  );

  const handleSearch = () => {
    const plate = searchPlate.toUpperCase().trim();
    setActiveRegistration(plate);
  };

  const spendingHistory = (currentVehicle?.history || [])
    .slice()
    .reverse()
    .map((item) => ({
      month: item.date ? new Date(item.date).toLocaleDateString('fr-FR', { month: 'short' }) : '-',
      amount: item.amount || 0,
    }));

  const categorySummary = Object.entries(currentVehicle?.categories || {});

  if (!currentVehicle) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <h1 className="text-2xl font-bold text-gray-900">Historique par Véhicule</h1>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border p-8 text-center">
          <Car className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-gray-900 mb-2">
            Rechercher un véhicule
          </h2>
          <p className="text-gray-500 mb-6">
            Entrez une immatriculation pour voir l'historique des réparations et factures
          </p>
          
          <div className="flex justify-center gap-3 max-w-md mx-auto">
            <input 
              type="text"
              placeholder="AB-123-CD"
              className="flex-1 px-4 py-3 border rounded-lg text-center uppercase text-lg tracking-wider"
              value={searchPlate}
              onChange={(e) => setSearchPlate(e.target.value)}
              maxLength={9}
            />
            <button 
              onClick={handleSearch}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2"
            >
              <Search className="w-5 h-5" />
              Rechercher
            </button>
          </div>
          
          {/* Immatriculations récentes */}
          <div className="mt-8">
            {isFetching && <p className="text-sm text-gray-500">Recherche en cours...</p>}
            {isError && activeRegistration && (
              <p className="text-sm text-red-500">Aucun historique trouvé pour cette immatriculation.</p>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button 
            onClick={() => {
              setActiveRegistration('');
              setSearchPlate('');
            }}
            className="p-2 hover:bg-gray-100 rounded-lg"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
              <Car className="w-6 h-6 text-blue-600" />
              {currentVehicle.registration}
            </h1>
            <p className="text-gray-500">Historique fournisseur lié au véhicule</p>
          </div>
        </div>
        <ExportPdfButton currentVehicle={currentVehicle} />
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Dépenses</p>
              <p className="text-2xl font-bold text-gray-900">
                {currentVehicle.total_spent.toLocaleString('fr-FR')} €
              </p>
            </div>
            <div className="p-3 bg-blue-50 rounded-lg">
              <DollarSign className="w-5 h-5 text-blue-600" />
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Interventions</p>
              <p className="text-2xl font-bold text-gray-900">
                {currentVehicle.intervention_count}
              </p>
            </div>
            <div className="p-3 bg-green-50 rounded-lg">
              <Wrench className="w-5 h-5 text-green-600" />
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Dernière visite</p>
              <p className="text-2xl font-bold text-gray-900">
                {currentVehicle.last_visit ? new Date(currentVehicle.last_visit).toLocaleDateString('fr-FR') : '-'}
              </p>
            </div>
            <div className="p-3 bg-yellow-50 rounded-lg">
              <Calendar className="w-5 h-5 text-yellow-600" />
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dépenses sur le temps */}
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Évolution des Dépenses</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={spendingHistory}>
                <XAxis dataKey="month" />
                <YAxis />
                <Tooltip formatter={(value) => `${value} €`} />
                <Line 
                  type="monotone" 
                  dataKey="amount" 
                  stroke="#3b82f6" 
                  strokeWidth={2}
                  dot={{ fill: '#3b82f6' }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Historique des factures */}
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Historique des Interventions</h3>
          <div className="space-y-4">
            {currentVehicle.history.map((invoice, index) => (
              <div key={index} className="flex items-start gap-4 p-4 bg-gray-50 rounded-lg">
                <div className="p-2 bg-blue-100 rounded-lg">
                  <FileText className="w-5 h-5 text-blue-600" />
                </div>
                <div className="flex-1">
                  <p className="font-medium text-gray-900">{invoice.description}</p>
                  <div className="flex items-center gap-4 mt-1 text-sm text-gray-500">
                    <span>{invoice.date ? new Date(invoice.date).toLocaleDateString('fr-FR') : '-'}</span>
                    <span className="px-2 py-0.5 bg-gray-200 rounded text-xs">
                      {invoice.category}
                    </span>
                    <span className="font-mono text-xs">{invoice.invoice_number}</span>
                  </div>
                </div>
                <div className="font-semibold text-gray-900">
                  {invoice.amount.toLocaleString('fr-FR')} €
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Récapitulatif par catégorie */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <h3 className="font-semibold text-gray-900 mb-4">Répartition des Coûts</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {categorySummary.map(([cat, values]) => (
            <div key={cat} className="p-4 bg-gray-50 rounded-lg text-center">
              <p className="text-sm text-gray-600">{cat}</p>
              <p className="text-lg font-semibold text-gray-900 mt-1">
                {values.amount.toLocaleString('fr-FR')} €
              </p>
              <p className="text-xs text-gray-500 mt-1">
                {values.count} facture(s)
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const ExportPdfButton = ({ currentVehicle }) => {
  const [isGenerating, setIsGenerating] = useState(false);

  const generatePDF = async () => {
    if (!currentVehicle) return;

    setIsGenerating(true);

    try {
      const doc = new jsPDF();
      const today = new Date().toLocaleDateString('fr-FR');

      // Header
      doc.setFontSize(20);
      doc.text('Carrosserie Erik - Historique Véhicule', 14, 20);

      doc.setFontSize(12);
      doc.text(`Immatriculation: ${currentVehicle.registration}`, 14, 35);
      doc.text(`Date d'export: ${today}`, 14, 45);

      // Stats summary
      doc.setFontSize(14);
      doc.text('Résumé', 14, 60);

      doc.setFontSize(11);
      doc.text(`Total Dépenses: ${currentVehicle.total_spent.toLocaleString('fr-FR')} €`, 14, 70);
      doc.text(`Nombre d'interventions: ${currentVehicle.intervention_count}`, 14, 78);
      doc.text(`Dernière visite: ${currentVehicle.last_visit ? new Date(currentVehicle.last_visit).toLocaleDateString('fr-FR') : '-'}`, 14, 86);

      // Table with interventions
      const tableData = currentVehicle.history.map((inv) => [
        inv.date ? new Date(inv.date).toLocaleDateString('fr-FR') : '-',
        inv.description || '-',
        inv.category || '-',
        inv.invoice_number || '-',
        `${inv.amount?.toLocaleString('fr-FR') || 0} €`,
      ]);

      doc.setFontSize(14);
      doc.text('Détail des Interventions', 14, 105);

      doc.autoTable({
        startY: 110,
        head: [['Date', 'Description', 'Catégorie', 'N° Facture', 'Montant']],
        body: tableData,
        theme: 'striped',
        headStyles: { fillColor: [59, 130, 246] },
        styles: { fontSize: 10, cellPadding: 2 },
        columnStyles: {
          0: { cellWidth: 25 },
          1: { cellWidth: 'auto' },
          2: { cellWidth: 35 },
          3: { cellWidth: 30 },
          4: { cellWidth: 25, halign: 'right' },
        },
      });

      // Category breakdown
      const finalY = doc.lastAutoTable.finalY || 150;
      doc.setFontSize(14);
      doc.text('Répartition par Catégorie', 14, finalY + 15);

      const categoryData = Object.entries(currentVehicle.categories || {}).map(([cat, vals]) => [
        cat,
        `${vals.amount?.toLocaleString('fr-FR') || 0} €`,
        `${vals.count} facture(s)`,
      ]);

      doc.autoTable({
        startY: finalY + 20,
        head: [['Catégorie', 'Montant', 'Nombre']],
        body: categoryData,
        theme: 'striped',
        headStyles: { fillColor: [16, 185, 129] },
        styles: { fontSize: 10 },
      });

      // Save
      doc.save(`historique_${currentVehicle.registration}_${today.replace(/\//g, '-')}.pdf`);
    } catch (error) {
      alert('Erreur lors de la génération du PDF: ' + error.message);
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <button
      onClick={generatePDF}
      disabled={isGenerating}
      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50"
    >
      <Download className="w-4 h-4" />
      {isGenerating ? 'Génération...' : 'Export PDF'}
    </button>
  );
};

export default VehicleHistory;
