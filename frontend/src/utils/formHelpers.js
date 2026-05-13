export const handleChange = (form, setForm, key, value) => {
  setForm(prev => ({ ...prev, [key]: value }));
};
