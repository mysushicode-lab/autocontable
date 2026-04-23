import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  LayoutDashboard, 
  FileText, 
  CreditCard, 
  BarChart3, 
  Car,
  Settings,
  Bell,
  Search
} from 'lucide-react';

const Layout = ({ children }) => {
  const location = useLocation();
  
  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: 'Tableau de Bord' },
    { path: '/invoices', icon: FileText, label: 'Factures' },
    { path: '/reconciliation', icon: CreditCard, label: 'Rapprochement' },
    { path: '/vehicles', icon: Car, label: 'Par Véhicule' },
    { path: '/reports', icon: BarChart3, label: 'Rapports' },
  ];

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 text-white flex flex-col">
        <div className="p-6 border-b border-slate-700">
          <h1 className="text-xl font-bold flex items-center gap-2">
            <Car className="w-6 h-6 text-blue-400" />
            Carrosserie Erik
          </h1>
          <p className="text-sm text-slate-400 mt-1">Gestion Comptable</p>
        </div>
        
        <nav className="flex-1 p-4">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition-colors ${
                  isActive 
                    ? 'bg-blue-600 text-white' 
                    : 'text-slate-300 hover:bg-slate-800'
                }`}
              >
                <Icon className="w-5 h-5" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        
        <div className="p-4 border-t border-slate-700">
          <button className="flex items-center gap-3 px-4 py-3 text-slate-300 hover:bg-slate-800 rounded-lg w-full">
            <Settings className="w-5 h-5" />
            Paramètres
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-white border-b px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input 
                type="text"
                placeholder="Rechercher une facture, immatriculation, fournisseur..."
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            <button className="relative p-2 text-gray-600 hover:bg-gray-100 rounded-lg">
              <Bell className="w-5 h-5" />
              <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
            </button>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold">
                CR
              </div>
              <div className="hidden md:block">
                <p className="font-medium">Erik</p>
                <p className="text-sm text-gray-500">Admin</p>
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
};

export default Layout;
