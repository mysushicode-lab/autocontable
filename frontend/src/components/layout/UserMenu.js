'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { MessageSquare, ExternalLink } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useAuthImage } from '../../hooks/useAuthImage';

const UserMenu = ({ profileMenuRef, profileMenuOpen, setProfileMenuOpen }) => {
  const router = useRouter();
  const { logout, user } = useAuth();
  const profilePhotoSrc = useAuthImage(user?.profile_photo ? `${user.profile_photo}` : null);

  return (
    <div className="relative ml-0.5" ref={profileMenuRef}>
      <button
        onClick={() => setProfileMenuOpen(v => !v)}
        className="w-6 h-6 rounded-full overflow-hidden shrink-0 ring-1 ring-transparent hover:ring-blue-300 transition-all"
      >
        {profilePhotoSrc
          ? <img src={profilePhotoSrc} alt="" className="w-full h-full object-cover" />
          : <div className="w-full h-full bg-blue-600 flex items-center justify-center text-white text-[10px] font-semibold">
              {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || 'U'}
            </div>
        }
      </button>
      {profileMenuOpen && (
        <div className="absolute right-0 top-9 w-56 bg-white rounded-xl border border-gray-100 overflow-hidden z-[110]">
          <div className="px-4 py-3 border-b border-gray-100">
            <p className="text-sm font-semibold text-gray-900">{user?.name || user?.username || 'Utilisateur'}</p>
            <p className="text-xs text-gray-400">{user?.email || ''}</p>
          </div>
          <div className="p-1">
            <button
              onClick={() => { router.push('/settings'); setProfileMenuOpen(false); }}
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
            >
              Paramètres
            </button>
            <a
              href="mailto:support@autocontable.com"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
              onClick={() => setProfileMenuOpen(false)}
            >
              <MessageSquare size={14} className="text-gray-400 shrink-0" />
              <span className="flex-1">Assistance</span>
              <ExternalLink size={12} className="text-gray-300 shrink-0" />
            </a>
            <div className="border-t border-gray-100 mt-1 pt-1">
              <button
                onClick={() => { logout(); router.push('/login'); setProfileMenuOpen(false); }}
                className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-500 hover:bg-red-50 rounded-lg transition-colors"
              >
                Déconnexion
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default UserMenu;
