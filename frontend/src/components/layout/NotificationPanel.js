import React from 'react';
import { Bell, CheckCircle, AlertCircle, Info, AlertTriangle, X, Trash2 } from 'lucide-react';
import { NOTIF_TYPES } from '../../context/NotificationContext';
import { formatDate } from '../../utils/formatHelpers';

const TYPE_CONFIG = {
  [NOTIF_TYPES.SUCCESS]: { icon: CheckCircle, color: 'text-green-500', bg: 'bg-green-50' },
  [NOTIF_TYPES.ERROR]:   { icon: AlertCircle, color: 'text-red-500',   bg: 'bg-red-50'   },
  [NOTIF_TYPES.WARNING]: { icon: AlertTriangle, color: 'text-yellow-500', bg: 'bg-yellow-50' },
  [NOTIF_TYPES.INFO]:    { icon: Info,         color: 'text-blue-500', bg: 'bg-blue-50'  },
};

const timeAgo = (date) => {
  const diff = Math.floor((Date.now() - new Date(date)) / 1000);
  if (diff < 60) return "À l'instant";
  if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)} h`;
  return formatDate(date);
};

const NotificationPanel = ({ panelRef, notifications, unreadCount, markRead, markAllRead, remove, clearAll }) => {
  return (
    <div className="absolute right-0 top-10 w-80 sm:w-96 bg-white rounded-xl border border-gray-100 z-50 flex flex-col max-h-[480px]">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
        <div className="flex items-center gap-2">
          <h3 className="text-sm font-semibold text-gray-900">Notifications</h3>
          {unreadCount > 0 && (
            <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-[10px] font-semibold rounded-full">{unreadCount}</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {unreadCount > 0 && (
            <button onClick={markAllRead} className="text-xs text-blue-600 hover:text-blue-700">Tout lire</button>
          )}
          {notifications.length > 0 && (
            <button onClick={clearAll} className="p-1 text-gray-300 hover:text-red-400 rounded">
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>
      <div className="overflow-y-auto flex-1 divide-y divide-gray-50">
        {notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10">
            <Bell className="w-7 h-7 mb-2 text-gray-300" />
            <p className="text-sm text-gray-400">Aucune notification</p>
          </div>
        ) : notifications.map((notif) => {
          const { icon: Icon, color, bg } = TYPE_CONFIG[notif.type] || TYPE_CONFIG[NOTIF_TYPES.INFO];
          return (
            <div
              key={notif.id}
              onClick={() => markRead(notif.id)}
              className={`flex gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors ${!notif.read ? 'bg-blue-50/30' : ''}`}
            >
              <div className={`mt-0.5 p-1.5 rounded-lg ${bg} shrink-0`}>
                <Icon className={`w-3.5 h-3.5 ${color}`} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <p className={`text-sm text-gray-900 ${!notif.read ? 'font-semibold' : 'font-medium'}`}>{notif.title}</p>
                  <button onClick={(e) => { e.stopPropagation(); remove(notif.id); }} className="text-gray-300 hover:text-gray-400 shrink-0">
                    <X className="w-3 h-3" />
                  </button>
                </div>
                <p className="text-xs text-gray-500 mt-0.5">{notif.message}</p>
                <p className="text-[10px] text-gray-400 mt-1">{timeAgo(notif.date)}</p>
              </div>
              {!notif.read && <div className="w-1.5 h-1.5 bg-blue-500 rounded-full mt-2 shrink-0" />}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default NotificationPanel;
