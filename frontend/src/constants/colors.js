/**
 * Shared color palette for charts and UI
 * Ensures consistency across Dashboard, Reports, and other components
 */

export const CHART_COLORS = {
  // Primary palette
  blue: '#3b82f6',
  purple: '#8b5cf6',
  green: '#10b981',
  amber: '#f59e0b',
  gray: '#6b7280',
  red: '#ef4444',
  
  // Extended palette for larger datasets
  teal: '#14b8a6',
  indigo: '#6366f1',
  rose: '#f43f5e',
  cyan: '#06b6d4',
  lime: '#84cc16',
  orange: '#f97316',
  pink: '#ec4899',
  sky: '#0ea5e9',
  violet: '#8b5cf6',
  emerald: '#10b981',
};

// Array format for recharts
export const CHART_COLORS_ARRAY = [
  CHART_COLORS.blue,
  CHART_COLORS.purple,
  CHART_COLORS.green,
  CHART_COLORS.amber,
  CHART_COLORS.gray,
  CHART_COLORS.red,
  CHART_COLORS.teal,
  CHART_COLORS.indigo,
  CHART_COLORS.rose,
  CHART_COLORS.cyan,
  CHART_COLORS.lime,
  CHART_COLORS.orange,
];

// Status colors
export const STATUS_COLORS = {
  matched: { bg: 'bg-green-50', text: 'text-green-600', icon: '#10b981' },
  pending: { bg: 'bg-yellow-50', text: 'text-yellow-600', icon: '#f59e0b' },
  unmatched: { bg: 'bg-red-50', text: 'text-red-600', icon: '#ef4444' },
  processed: { bg: 'bg-blue-50', text: 'text-blue-600', icon: '#3b82f6' },
};

// KPI card colors
export const KPI_COLORS = {
  blue: 'bg-blue-50 text-blue-600',
  yellow: 'bg-yellow-50 text-yellow-600',
  red: 'bg-red-50 text-red-600',
  green: 'bg-green-50 text-green-600',
  purple: 'bg-purple-50 text-purple-600',
  gray: 'bg-gray-50 text-gray-600',
};
