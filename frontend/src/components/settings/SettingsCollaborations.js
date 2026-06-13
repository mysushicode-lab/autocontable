import React, { useState } from 'react';
import { UserPlus, Trash2, Edit, Save, X } from 'lucide-react';

export const SettingsCollaborations = ({ users, user, createUserMutation, deleteUserMutation, updateUserMutation, setSaveStatus }) => {
  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({ username: '', password: '', name: '', email: '', role: 'accountant' });
  const [editingUser, setEditingUser] = useState(null);
  const [editForm, setEditForm] = useState({ name: '', email: '' });
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  const [confirmText, setConfirmText] = useState('');

  const handleAddUser = (e) => {
    e.preventDefault();
    createUserMutation.mutate(newUser, {
      onSuccess: () => { setShowAddUser(false); setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' }); setSaveStatus({ type: 'success', message: 'Collaborateur ajouté' }); setTimeout(() => setSaveStatus(null), 3000); },
      onError: (error) => { const msg = error?.response?.data?.detail || (Array.isArray(error?.response?.data) ? error?.response?.data[0]?.msg : null) || error?.message || 'Erreur lors de la création'; setSaveStatus({ type: 'error', message: msg }); setTimeout(() => setSaveStatus(null), 3000); },
    });
  };

  const handleDeleteUser = (userId, username) => { setUserToDelete({ id: userId, username }); setConfirmText(''); setShowDeleteConfirm(true); };

  const confirmDeleteUser = () => {
    if (confirmText === userToDelete.username) {
      deleteUserMutation.mutate(userToDelete.id, {
        onSuccess: () => { setShowDeleteConfirm(false); setUserToDelete(null); setConfirmText(''); setSaveStatus({ type: 'success', message: 'Collaborateur supprimé' }); setTimeout(() => setSaveStatus(null), 3000); },
        onError: (error) => { setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la suppression' }); setTimeout(() => setSaveStatus(null), 3000); },
      });
    }
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    updateUserMutation.mutate({ userId: editingUser, data: editForm }, {
      onSuccess: () => { setEditingUser(null); setEditForm({ name: '', email: '' }); setSaveStatus({ type: 'success', message: 'Utilisateur mis à jour' }); setTimeout(() => setSaveStatus(null), 3000); },
      onError: (error) => { setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la mise à jour' }); setTimeout(() => setSaveStatus(null), 3000); },
    });
  };

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <div className="flex items-start justify-between gap-4 mb-6">
          <div>
            <h2 className="text-sm font-semibold text-gray-900 mb-1">Collaborations</h2>
            <p className="text-xs text-gray-500">Gérez les accès à votre espace de travail</p>
          </div>
          <button onClick={() => setShowAddUser(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 transition-colors shrink-0">
            <UserPlus className="w-3.5 h-3.5" />Inviter
          </button>
        </div>

        <p className="text-[9px] font-bold text-gray-400 uppercase tracking-widest mb-3">Membres ({users.length})</p>
        <div className="space-y-2">
          {users.map((u) => (
            <div key={u.id}>
              {editingUser === u.id ? (
                <form onSubmit={handleSaveEdit} className="flex items-center gap-3 p-3 bg-blue-50 rounded-md border border-blue-200">
                  <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-xs shrink-0">
                    {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 grid grid-cols-2 gap-2">
                    <input type="text" placeholder="Nom" className="px-2.5 py-1.5 bg-white border border-gray-200 rounded text-xs text-gray-900 focus:outline-none focus:border-blue-400 transition-colors" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} />
                    <input type="email" placeholder="Email" className="px-2.5 py-1.5 bg-white border border-gray-200 rounded text-xs text-gray-900 focus:outline-none focus:border-blue-400 transition-colors" value={editForm.email} onChange={(e) => setEditForm({ ...editForm, email: e.target.value })} />
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <button type="submit" disabled={updateUserMutation.isLoading} className="p-1.5 bg-blue-600 text-white rounded hover:bg-blue-500 disabled:opacity-50 transition-colors"><Save className="w-3 h-3" /></button>
                    <button type="button" onClick={() => { setEditingUser(null); setEditForm({ name: '', email: '' }); }} className="p-1.5 border border-gray-200 rounded text-gray-400 hover:bg-gray-100 transition-colors"><X className="w-3 h-3" /></button>
                  </div>
                </form>
              ) : (
                <div className="flex items-center justify-between p-3 bg-white rounded-md border border-gray-200 hover:border-gray-300 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-xs shrink-0">
                      {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-900">{u.name || u.username}</p>
                      <p className="text-xs text-gray-400">{u.email || u.username}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-1">
                    <button onClick={() => { setEditingUser(u.id); setEditForm({ name: u.name || '', email: u.email || '' }); }}
                      className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors"><Edit className="w-3.5 h-3.5" /></button>
                    {u.id !== user?.id && (
                      <button onClick={() => handleDeleteUser(u.id, u.username)}
                        className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors"><Trash2 className="w-3.5 h-3.5" /></button>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Add user form */}
      {showAddUser && (
        <div className="bg-white rounded-md p-6 border border-gray-200">
          <h3 className="text-sm font-semibold text-gray-900 mb-5">Nouveau collaborateur</h3>
          <form onSubmit={handleAddUser} className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1.5">Nom complet</label>
                <input type="text" placeholder="Jean Dupont" className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors" value={newUser.name} onChange={(e) => setNewUser({ ...newUser, name: e.target.value })} required />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1.5">Email (optionnel)</label>
                <input type="email" placeholder="jean@exemple.fr" className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors" value={newUser.email} onChange={(e) => setNewUser({ ...newUser, email: e.target.value })} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1.5">Nom d'utilisateur</label>
                <input type="text" placeholder="jean.dupont" className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors" value={newUser.username} onChange={(e) => setNewUser({ ...newUser, username: e.target.value })} required />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1.5">Rôle</label>
                <select className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 focus:outline-none focus:border-blue-400 transition-colors" value={newUser.role} onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}>
                  <option value="accountant">Comptable</option>
                  <option value="admin">Administrateur</option>
                </select>
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Mot de passe</label>
              <input type="password" placeholder="••••••••" className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors" value={newUser.password} onChange={(e) => setNewUser({ ...newUser, password: e.target.value })} required />
              <p className="text-[11px] text-gray-400 mt-1.5">8+ caractères, majuscule, minuscule, chiffre, caractère spécial</p>
            </div>
            <div className="flex gap-2 pt-1">
              <button type="submit" disabled={createUserMutation.isLoading}
                className="px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors">
                {createUserMutation.isLoading ? 'Création...' : 'Créer le compte'}
              </button>
              <button type="button" onClick={() => { setShowAddUser(false); setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' }); }}
                className="px-4 py-2 border border-gray-200 rounded-md text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors">Annuler</button>
            </div>
          </form>
        </div>
      )}

      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-md p-6 max-w-md w-full mx-4 border border-gray-200 shadow-lg">
            <h3 className="text-sm font-semibold text-gray-900 mb-1">Confirmer la suppression</h3>
            <p className="text-xs text-gray-500 mb-4">
              Pour supprimer <span className="font-medium text-gray-700">{userToDelete?.username}</span>, tapez son nom d'utilisateur :
            </p>
            <input type="text" value={confirmText} onChange={(e) => setConfirmText(e.target.value)} placeholder={userToDelete?.username}
              className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors mb-4" />
            <div className="flex gap-3 justify-end">
              <button onClick={() => { setShowDeleteConfirm(false); setUserToDelete(null); setConfirmText(''); }}
                className="px-3 py-1.5 border border-gray-200 rounded-md text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors">Annuler</button>
              <button onClick={confirmDeleteUser} disabled={confirmText !== userToDelete?.username}
                className="px-3 py-1.5 bg-red-600 text-white rounded-md text-xs font-medium hover:bg-red-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">Supprimer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
