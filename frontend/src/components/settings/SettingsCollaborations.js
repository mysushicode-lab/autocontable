import React, { useState } from 'react';
import { Users, UserPlus, Trash2, Edit, Save, X } from 'lucide-react';

export const SettingsCollaborations = ({ users, user, createUserMutation, deleteUserMutation, updateUserMutation, setSaveStatus }) => {
  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({ username: '', password: '', name: '', email: '', role: 'accountant' });
  const [editingUser, setEditingUser] = useState(null);
  const [editForm, setEditForm] = useState({ name: '', email: '' });

  const handleAddUser = (e) => {
    e.preventDefault();
    createUserMutation.mutate(newUser, {
      onSuccess: () => {
        setShowAddUser(false);
        setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' });
        setSaveStatus({ type: 'success', message: 'Collaborateur ajouté' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la création' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  const handleDeleteUser = (userId, username) => {
    if (confirm(`Supprimer l'utilisateur ${username} ?`)) {
      deleteUserMutation.mutate(userId, {
        onSuccess: () => {
          setSaveStatus({ type: 'success', message: 'Collaborateur supprimé' });
          setTimeout(() => setSaveStatus(null), 3000);
        },
        onError: (error) => {
          setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la suppression' });
          setTimeout(() => setSaveStatus(null), 3000);
        },
      });
    }
  };

  const handleEditUser = (u) => {
    setEditingUser(u.id);
    setEditForm({ name: u.name || '', email: u.email || '' });
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    updateUserMutation.mutate({ userId: editingUser, data: editForm }, {
      onSuccess: () => {
        setEditingUser(null);
        setEditForm({ name: '', email: '' });
        setSaveStatus({ type: 'success', message: 'Utilisateur mis à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la mise à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  const handleCancelEdit = () => {
    setEditingUser(null);
    setEditForm({ name: '', email: '' });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold text-gray-900">Collaborations</h2>
          <p className="text-sm text-gray-500 mt-1">Gérez les accès à votre espace de travail</p>
        </div>
        <button onClick={() => setShowAddUser(true)}
          className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 flex items-center gap-2 text-sm font-medium">
          <UserPlus className="w-4 h-4" />Inviter
        </button>
      </div>

      <div>
        <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Membres ({users.length})</p>
        <div className="space-y-2">
          {users.map((u) => (
            <div key={u.id}>
              {editingUser === u.id ? (
                <form onSubmit={handleSaveEdit} className="flex items-center gap-3 p-3 bg-blue-50 rounded-xl border border-blue-200">
                  <div className="w-9 h-9 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
                    {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 grid grid-cols-2 gap-2">
                    <input type="text" placeholder="Nom" className="px-2.5 py-1.5 border rounded-md text-sm" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} />
                    <input type="email" placeholder="Email" className="px-2.5 py-1.5 border rounded-md text-sm" value={editForm.email} onChange={(e) => setEditForm({ ...editForm, email: e.target.value })} />
                  </div>
                  <div className="flex gap-1">
                    <button type="submit" disabled={updateUserMutation.isLoading} className="p-1.5 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"><Save className="w-3.5 h-3.5" /></button>
                    <button type="button" onClick={handleCancelEdit} className="p-1.5 bg-gray-400 text-white rounded-md hover:bg-gray-500"><X className="w-3.5 h-3.5" /></button>
                  </div>
                </form>
              ) : (
                <div className="flex items-center justify-between p-3 bg-white rounded-xl border border-gray-200 hover:border-gray-300 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
                      {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <p className="font-medium text-gray-900 text-sm">{u.name || u.username}</p>
                      <p className="text-xs text-gray-400">{u.email || u.username} • {u.role === 'admin' ? 'Administrateur' : 'Comptable'}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5">
                    {u.role === 'admin' && <span className="px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded-full text-xs font-medium">Admin</span>}
                    <button onClick={() => handleEditUser(u)} className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-md"><Edit className="w-3.5 h-3.5" /></button>
                    {u.id !== user?.id && (
                      <button onClick={() => handleDeleteUser(u.id, u.username)} className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md"><Trash2 className="w-3.5 h-3.5" /></button>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {showAddUser && (
        <div className="p-5 bg-gray-50 rounded-xl border border-gray-200">
          <h3 className="font-semibold text-gray-900 mb-4">Nouveau collaborateur</h3>
          <form onSubmit={handleAddUser} className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <input type="text" placeholder="Nom complet" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.name} onChange={(e) => setNewUser({ ...newUser, name: e.target.value })} required />
              <input type="text" placeholder="Nom d'utilisateur" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.username} onChange={(e) => setNewUser({ ...newUser, username: e.target.value })} required />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <input type="email" placeholder="Email (optionnel)" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.email} onChange={(e) => setNewUser({ ...newUser, email: e.target.value })} />
              <select className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.role} onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}>
                <option value="accountant">Comptable</option>
                <option value="admin">Administrateur</option>
              </select>
            </div>
            <input type="password" placeholder="Mot de passe" className="w-full px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.password} onChange={(e) => setNewUser({ ...newUser, password: e.target.value })} required />
            <div className="flex gap-2 pt-1">
              <button type="submit" disabled={createUserMutation.isLoading} className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium disabled:opacity-50">
                {createUserMutation.isLoading ? 'Création...' : 'Créer le compte'}
              </button>
              <button type="button" onClick={() => { setShowAddUser(false); setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' }); }} className="px-4 py-2 border border-gray-200 rounded-md text-sm hover:bg-gray-100">Annuler</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};
