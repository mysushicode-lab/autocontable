import React from 'react';
import DropdownButton from '../DropdownButton';

const LinkModal = ({ linkModal, linkSearch, setLinkSearch, linkMonthFilter, setLinkMonthFilter, showLinkMonthDropdown, setShowLinkMonthDropdown, linkMonthButtonRef, periodMonths, unmatchedInvoices, bankOnly, linkSelectedId, setLinkSelectedId, submitManualLink }) => {
  const isTx2Inv = linkModal.type === 'tx2inv';
  const listItems = isTx2Inv ? unmatchedInvoices : bankOnly;
  
  // Filter by month if selected
  const monthFiltered = linkMonthFilter 
    ? listItems.filter(item => {
        const itemDate = isTx2Inv ? item.invoice?.date : item.date;
        if (!itemDate) return false;
        const date = new Date(itemDate);
        const itemMonth = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
        return itemMonth === linkMonthFilter;
      })
    : listItems;
  
  const filtered = monthFiltered
    .filter(item => {
      if (!linkSearch) return true;
      const text = isTx2Inv
        ? `${item.invoice?.supplier || ''} ${item.invoice?.number || ''} ${item.invoice?.amount || ''}`
        : `${item.description || ''} ${item.amount || ''}`;
      return text.toLowerCase().includes(linkSearch.toLowerCase());
    })
    .sort((a, b) => {
      const na = isTx2Inv ? (a.invoice?.supplier || '') : (a.description || '');
      const nb = isTx2Inv ? (b.invoice?.supplier || '') : (b.description || '');
      return na.localeCompare(nb, 'fr');
    });
  
  // Generate month options for the modal
  const linkMonthOptions = [
    { value: '', label: 'Tous les mois' },
    ...periodMonths
  ];

  return (
    <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
      <div className="bg-white rounded-md shadow-xl p-6 w-full max-w-md mx-4 flex flex-col" style={{ maxHeight: '80vh' }}>
        <h3 className="font-semibold text-gray-900 mb-1">
          {isTx2Inv ? 'Lier à une facture' : 'Lier à un paiement bancaire'}
        </h3>
        <p className="text-xs text-gray-500 mb-3 break-words">{linkModal.label}</p>
        <div className="flex gap-2 mb-2">
          <input
            autoFocus
            type="text"
            value={linkSearch}
            onChange={e => setLinkSearch(e.target.value)}
            placeholder="Rechercher..."
            className="flex-1 px-3 py-2 border rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <DropdownButton
            label={linkMonthOptions.find(o => o.value === linkMonthFilter)?.label || 'Mois'}
            value={linkMonthFilter}
            options={linkMonthOptions}
            onChange={setLinkMonthFilter}
            isOpen={showLinkMonthDropdown}
            onToggle={() => setShowLinkMonthDropdown(!showLinkMonthDropdown)}
            buttonRef={linkMonthButtonRef}
            width="120px"
          />
        </div>
        <p className="text-xs text-gray-400 mb-2">{filtered.length} résultat{filtered.length !== 1 ? 's' : ''}</p>
        <div className="overflow-y-auto flex-1 space-y-1 mb-4">
          {filtered.length === 0 && (
            <p className="text-sm text-gray-400 text-center py-4">
              {isTx2Inv ? 'Aucune facture non rapprochée trouvée' : 'Aucun paiement trouvé'}
            </p>
          )}
          {filtered.map(item => {
            const id = isTx2Inv ? item.id : (item.db_id || item.id);
            const selected = linkSelectedId === id;
            return isTx2Inv ? (
              <button
                key={id}
                onClick={() => setLinkSelectedId(id)}
                className={`w-full text-left px-3 py-2 rounded-md border text-sm transition-colors ${
                  selected ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'
                }`}
              >
                <span className="font-medium">{item.invoice?.supplier || '—'}</span>
                <span className="text-gray-500 ml-2">{item.invoice?.number}</span>
                <span className="float-right font-bold text-gray-800">{item.invoice?.amount?.toLocaleString('fr-FR')} €</span>
                <div className="text-xs text-gray-400 mt-0.5">{item.invoice?.date ? new Date(item.invoice.date).toLocaleDateString('fr-FR') : '—'}</div>
              </button>
            ) : (
              <button
                key={id}
                onClick={() => setLinkSelectedId(id)}
                className={`w-full text-left px-3 py-2 rounded-md border text-sm transition-colors ${
                  selected ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'
                }`}
              >
                <span className="font-medium break-words block">{item.description || '—'}</span>
                <span className={`float-right font-bold ${ item.amount < 0 ? 'text-red-600' : 'text-green-700'}`}>{item.amount?.toLocaleString('fr-FR')} €</span>
                <div className="text-xs text-gray-400 mt-0.5">{item.date ? new Date(item.date).toLocaleDateString('fr-FR') : '—'}</div>
              </button>
            );
          })}
        </div>
        <div className="flex gap-2 justify-end border-t pt-3">
          <button onClick={() => setLinkModal(null)} className="px-4 py-2 text-sm text-gray-600 border rounded-md hover:bg-gray-50">Annuler</button>
          <button onClick={submitManualLink} disabled={!linkSelectedId} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-40">Lier</button>
        </div>
      </div>
    </div>
  );
};

export default LinkModal;
