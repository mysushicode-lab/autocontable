import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { X, UserPlus, Trash2 } from 'lucide-react';
import { fetchDossierPermissions, grantPermission, revokePermission, fetchUsers } from '../api';

const PermissionsModal = ({ clientFileId, clientFileName, onClose }) => {
  const queryClient = useQueryClient();
  const [selectedUserId, setSelectedUserId] = useState('');
  const [permissionLevel, setPermissionLevel] = useState('read_write');

  const { data: permissionsData, isLoading: loadingPermissions } = useQuery(
    ['dossier-permissions', clientFileId],
    () => fetchDossierPermissions(clientFileId),
    { enabled: !!clientFileId }
  );

  const { data: usersData, isLoading: loadingUsers } = useQuery('users', fetchUsers);

  const permissions = permissionsData?.permissions || [];
  const allUsers = usersData?.users || [];
  const assignedUserIds = new Set(permissions.map((p) => p.user_id));
  const availableUsers = allUsers.filter((u) => !assignedUserIds.has(u.id) && u.role !== 'admin');

  const grantMutation = useMutation({
    mutationFn: () => grantPermission(parseInt(selectedUserId), clientFileId, permissionLevel),
    onSuccess: () => {
      queryClient.invalidateQueries(['dossier-permissions', clientFileId]);
      setSelectedUserId('');
      setPermissionLevel('read_write');
    },
  });

  const revokeMutation = useMutation({
    mutationFn: (userId) => revokePermission(userId, clientFileId),
    onSuccess: () => {
      queryClient.invalidateQueries(['dossier-permissions', clientFileId]);
    },
  });

  const handleGrant = (e) => {
    e.preventDefault();
    if (selectedUserId) {
      grantMutation.mutate();
    }
  };

  return createPortal(
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center p-4"
      style={{
        backgroundColor: '#ffffff',
        backgroundImage: 'radial-gradient(circle, #d1d5db 1px, transparent 1px)',
        backgroundSize: '20px 20px',
      }}
    >
      <div className="pointer-events-none fixed inset-0" style={{ background: 'radial-gradient(ellipse at center, transparent 25%, white 100%)' }} />
      <div className="bg-white rounded-md p-6 w-full max-w-2xl shadow-md">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">
            Permissions - {clientFileName}
          </h2>
          <button onClick={onClose} className="p-1 text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        {loadingPermissions || loadingUsers ? (
          <div className="text-center py-8 text-gray-500">Chargement...</div>
        ) : (
          <div className="space-y-6">
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Utilisateurs avec accès</h3>
              {permissions.length === 0 ? (
                <p className="text-sm text-gray-500">Aucun utilisateur assigné. Les admins ont accès à tous les dossiers.</p>
              ) : (
                <div className="space-y-2">
                  {permissions.map((perm) => (
                    <div key={perm.user_id} className="flex items-center justify-between p-3 border rounded-md">
                      <div>
                        <div className="font-medium text-sm">{perm.name || perm.username}</div>
                        <div className="text-xs text-gray-500">{perm.email}</div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-xs text-gray-600">
                          {perm.permission_level === 'read_only' && 'Lecture seule'}
                          {perm.permission_level === 'read_write' && 'Lecture/Écriture'}
                          {perm.permission_level === 'admin' && 'Admin'}
                        </span>
                        <button
                          onClick={() => revokeMutation.mutate(perm.user_id)}
                          disabled={revokeMutation.isLoading}
                          className="p-1 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Ajouter un utilisateur</h3>
              <form onSubmit={handleGrant} className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <select
                    value={selectedUserId}
                    onChange={(e) => setSelectedUserId(e.target.value)}
                    className="px-3 py-2 border rounded text-sm"
                    required
                  >
                    <option value="">Sélectionner un utilisateur</option>
                    {availableUsers.map((user) => (
                      <option key={user.id} value={user.id}>
                        {user.name || user.username} ({user.email})
                      </option>
                    ))}
                  </select>
                  <select
                    value={permissionLevel}
                    onChange={(e) => setPermissionLevel(e.target.value)}
                    className="px-3 py-2 border rounded text-sm"
                  >
                    <option value="read_only">Lecture seule</option>
                    <option value="read_write">Lecture/Écriture</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
                <button
                  type="submit"
                  disabled={!selectedUserId || grantMutation.isLoading}
                  className="px-4 py-2 bg-gray-900 text-white rounded-md hover:bg-gray-800 text-sm font-medium disabled:opacity-50 flex items-center gap-2"
                >
                  <UserPlus className="w-4 h-4" />
                  {grantMutation.isLoading ? 'Ajout...' : 'Ajouter'}
                </button>
              </form>
            </div>

            <div className="flex justify-end pt-4">
              <button
                onClick={onClose}
                className="px-4 py-2 border text-gray-700 rounded-md hover:bg-gray-50 text-sm font-medium"
              >
                Fermer
              </button>
            </div>
          </div>
        )}
      </div>
    </div>,
    document.body
  );
};

export default PermissionsModal;
