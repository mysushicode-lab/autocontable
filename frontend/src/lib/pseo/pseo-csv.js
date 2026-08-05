export function parseCsv(raw) {
  const lines = raw.trim().split('\n').filter((l) => l && !l.startsWith('#'));
  if (lines.length < 2) return [];
  const headers = lines[0].split(',').map((h) => h.trim());
  return lines.slice(1).map((line) => {
    const values = line.split(',').map((v) => v.trim());
    return Object.fromEntries(headers.map((h, i) => [h, values[i] || '']));
  });
}
