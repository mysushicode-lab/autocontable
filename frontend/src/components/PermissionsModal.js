'use client';

import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { X, UserPlus, Trash2, Mail, Copy, Check } from 'lucide-react';
import { fetchDossierPermissions, grantPermission, revokePermission, fetchUsers } from '../api';
import { INPUT_CLASS } from '../utils/formHelpers';
import { usePlanGate } from '../hooks/usePlanGate';

const PermissionsModal = ({ clientFileId, clientFileName, contactEmail, onClose }) => {
  const queryClient = useQueryClient();
  const [selectedUserId, setSelectedUserId] = useState('');
  const [permissionLevel, setPermissionLevel] = useState('read_write');
  const [inviteEmail, setInviteEmail] = useState(contactEmail || '');
  const [invitePermissionLevel, setInvitePermissionLevel] = useState('read_write');
  const [showInviteForm, setShowInviteForm] = useState(false);
  const [invitationLink, setInvitationLink] = useState(null);
  const [copySuccess, setCopySuccess] = useState(false);
  const { billing, canAccess } = usePlanGate();
  const hasAccess = billing ? canAccess('permissions') : false;

  const { data: permissionsData, isLoading: loadingPermissions } = useQuery({
    queryKey: ['dossier-permissions', clientFileId],
    queryFn: () => fetchDossierPermissions(clientFileId),
    enabled: !!clientFileId && hasAccess,
  });

  const { data: usersData, isLoading: loadingUsers } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
    enabled: hasAccess,
  });

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

  const inviteMutation = useMutation({
    mutationFn: () => {
      const token = localStorage.getItem('auth_token');
      return fetch('/api/permissions/invite', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: inviteEmail,
          client_file_id: clientFileId,
          permission_level: invitePermissionLevel,
        }),
      }).then(r => r.json());
    },
    onSuccess: (data) => {
      setInvitationLink(data.join_url);
    },
    onError: (err) => console.error('Erreur invitation:', err),
  });

  const handleCopyLink = async () => {
    if (!invitationLink) return;
    try {
      await navigator.clipboard.writeText(invitationLink);
      setCopySuccess(true);
      setTimeout(() => setCopySuccess(false), 2000);
    } catch (err) {
      console.error('Erreur copie:', err);
    }
  };

  const handleGrant = (e) => {
    e.preventDefault();
    if (selectedUserId) {
      grantMutation.mutate();
    }
  };

  const handleInvite = (e) => {
    e.preventDefault();
    if (inviteEmail) {
      inviteMutation.mutate();
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
      <div className="bg-white rounded-md p-6 w-full max-w-2xl">
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
                          disabled={revokeMutation.isPending}
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
                    className={INPUT_CLASS}
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
                    className={INPUT_CLASS}
                  >
                    <option value="read_only">Lecture seule</option>
                    <option value="read_write">Lecture/Écriture</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
                <button
                  type="submit"
                  disabled={!selectedUserId || grantMutation.isPending}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-500 text-sm font-medium disabled:opacity-50 flex items-center gap-2"
                >
                  <UserPlus className="w-4 h-4" />
                  {grantMutation.isPending ? 'Ajout...' : 'Ajouter'}
                </button>
              </form>
            </div>

            <div>
              {invitationLink ? (
                <div className="p-4 bg-green-50 border border-green-200 rounded-md space-y-3">
                  <h3 className="text-sm font-semibold text-green-900">Lien d'invitation généré</h3>
                  <div className="flex items-center gap-2">
                    <input
                      type="text"
                      value={invitationLink}
                      readOnly
                      className={`${INPUT_CLASS} flex-1`}
                    />
                    <button
                      type="button"
                      onClick={handleCopyLink}
                      className="p-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition"
                    >
                      {copySuccess ? (
                        <Check className="w-4 h-4" />
                      ) : (
                        <Copy className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                  <p className="text-xs text-green-700">Valide pendant 7 jours. Partagez ce lien avec la PME.</p>
                  <button
                    type="button"
                    onClick={() => {
                      setInvitationLink(null);
                      setInviteEmail(contactEmail || '');
                      setInvitePermissionLevel('read_write');
                    }}
                    className="w-full px-4 py-2 border border-green-300 text-green-700 rounded-md hover:bg-green-50 text-sm font-medium"
                  >
                    Générer un autre lien
                  </button>
                </div>
              ) : (
                <>
                  <button
                    onClick={() => setShowInviteForm(!showInviteForm)}
                    className="flex items-center gap-2 px-4 py-2 bg-green-50 text-green-700 border border-green-200 rounded-md hover:bg-green-100 text-sm font-medium w-full justify-center"
                  >
                    <Mail className="w-4 h-4" />
                    {showInviteForm ? 'Annuler invitation' : 'Inviter une PME'}
                  </button>

                  {showInviteForm && (
                    <form onSubmit={handleInvite} className="mt-3 p-4 bg-green-50 border border-green-200 rounded-md space-y-3">
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">Email de la PME</label>
                        <input
                          type="email"
                          value={inviteEmail}
                          onChange={(e) => setInviteEmail(e.target.value)}
                          className={INPUT_CLASS}
                          placeholder="pme@example.com"
                          required
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">Niveau d'accès</label>
                        <select
                          value={invitePermissionLevel}
                          onChange={(e) => setInvitePermissionLevel(e.target.value)}
                          className={INPUT_CLASS}
                        >
                          <option value="read_only">Lecture seule</option>
                          <option value="read_write">Lecture/Écriture (recommandé)</option>
                        </select>
                      </div>
                      <button
                        type="submit"
                        disabled={!inviteEmail || inviteMutation.isPending}
                        className="w-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-500 text-sm font-medium disabled:opacity-50"
                      >
                        {inviteMutation.isPending ? 'Envoi en cours...' : 'Générer lien d\'invitation'}
                      </button>
                    </form>
                  )}
                </>
              )}
            </div>

            <div className="flex justify-end pt-4">
              <button
                onClick={onClose}
                className="px-4 py-2 border text-gray-700 rounded-md text-sm font-medium"
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
