import { CheckCircle, Clock, AlertCircle, XCircle, Link, Unlink } from 'lucide-react';

export const INVOICE_STATUS = {
  matched: {
    label: 'Rapproché',
    color: 'text-green-600',
    bg: 'bg-green-50',
    border: 'border-green-200',
    dot: 'bg-green-500',
    icon: CheckCircle,
  },
  processed: {
    label: 'Traité',
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    border: 'border-blue-200',
    dot: 'bg-blue-500',
    icon: CheckCircle,
  },
  pending: {
    label: 'En attente',
    color: 'text-yellow-600',
    bg: 'bg-yellow-50',
    border: 'border-yellow-200',
    dot: 'bg-yellow-400',
    icon: Clock,
  },
  unmatched: {
    label: 'Non rapproché',
    color: 'text-red-500',
    bg: 'bg-red-50',
    border: 'border-red-200',
    dot: 'bg-red-500',
    icon: XCircle,
  },
};

export const TRANSACTION_STATUS = {
  matched: {
    label: 'Rapproché',
    color: 'text-green-600',
    bg: 'bg-green-50',
    border: 'border-green-200',
    icon: Link,
  },
  unmatched: {
    label: 'Non rapproché',
    color: 'text-gray-500',
    bg: 'bg-gray-50',
    border: 'border-gray-200',
    icon: Unlink,
  },
  pending: {
    label: 'En attente',
    color: 'text-yellow-600',
    bg: 'bg-yellow-50',
    border: 'border-yellow-200',
    icon: Clock,
  },
};

export const CLIENT_FILE_STATUS = {
  active: {
    label: 'Actif',
    color: 'text-green-600',
    bg: 'bg-green-50',
    border: 'border-green-200',
    dot: 'bg-green-500',
  },
  inactive: {
    label: 'Inactif',
    color: 'text-gray-400',
    bg: 'bg-gray-50',
    border: 'border-gray-200',
    dot: 'bg-gray-300',
  },
  archived: {
    label: 'Archivé',
    color: 'text-orange-500',
    bg: 'bg-orange-50',
    border: 'border-orange-200',
    dot: 'bg-orange-400',
  },
};

export const getInvoiceStatus = (status) =>
  INVOICE_STATUS[status] || INVOICE_STATUS.pending;

export const getTransactionStatus = (status) =>
  TRANSACTION_STATUS[status] || TRANSACTION_STATUS.unmatched;

export const getClientFileStatus = (isActive) =>
  isActive ? CLIENT_FILE_STATUS.active : CLIENT_FILE_STATUS.inactive;
