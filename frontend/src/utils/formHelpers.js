export const handleChange = (form, setForm, key, value) => {
  setForm(prev => ({ ...prev, [key]: value }));
};

export const INPUT_CLASS = 'w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:border-blue-500 text-sm';
export const INPUT_CLASS_SM = 'w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:border-blue-500 text-sm';
