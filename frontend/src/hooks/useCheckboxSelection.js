import { useState, useCallback } from 'react';

const useCheckboxSelection = (items = [], idKey = 'id') => {
  const [selectedIds, setSelectedIds] = useState([]);

  const isSelected = useCallback(
    (item) => selectedIds.includes(item[idKey]),
    [selectedIds, idKey]
  );

  const toggleOne = useCallback((item) => {
    setSelectedIds((prev) =>
      prev.includes(item[idKey])
        ? prev.filter((id) => id !== item[idKey])
        : [...prev, item[idKey]]
    );
  }, [idKey]);

  const toggleAll = useCallback(() => {
    setSelectedIds((prev) =>
      prev.length === items.length ? [] : items.map((i) => i[idKey])
    );
  }, [items, idKey]);

  const clearSelection = useCallback(() => setSelectedIds([]), []);

  const allSelected = items.length > 0 && selectedIds.length === items.length;
  const someSelected = selectedIds.length > 0 && selectedIds.length < items.length;

  return { selectedIds, isSelected, toggleOne, toggleAll, clearSelection, allSelected, someSelected };
};

export default useCheckboxSelection;
