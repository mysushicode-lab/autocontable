import { useEffect } from 'react';
import { fetchInvoices } from '../api';

/**
 * On mount, fetches all invoices and sets the month filter to the most recent invoice's month
 * if no month is currently selected.
 */
export const useAutoSelectRecentMonth = (selectedMonth, setSelectedMonth) => {
  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      try {
        const data = await fetchInvoices({});
        if (cancelled || !data?.invoices?.length) return;

        // Don't mutate the original array
        const mostRecent = [...data.invoices]
          .filter((inv) => inv.date)
          .sort((a, b) => new Date(b.date) - new Date(a.date))[0];

        if (mostRecent?.date && !selectedMonth) {
          const date = new Date(mostRecent.date);
          const year = date.getFullYear();
          const month = date.getMonth() + 1;
          setSelectedMonth(`${year}-${String(month).padStart(2, '0')}`);
        }
      } catch (error) {
        console.error('Error fetching most recent invoice:', error);
      }
    };
    run();
    return () => { cancelled = true; };
    // eslint-disable-next-line
  }, []);
};
