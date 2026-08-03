export function validateSiret(siret) {
  const cleaned = siret.replace(/[\s-]/g, '');
  if (!cleaned) return { valid: false, error: null }; // empty is ok (optional field)
  if (!/^\d+$/.test(cleaned)) return { valid: false, error: 'Chiffres uniquement' };
  if (cleaned.length !== 14) return { valid: false, error: `14 chiffres requis (${cleaned.length}/14)` };

  // Luhn algorithm (double odd positions, 1-indexed)
  const siren = cleaned.slice(0, 9);
  let total = 0;
  for (let i = 0; i < 14; i++) {
    let n = parseInt(cleaned[i]);
    if (i % 2 === 0) { n *= 2; if (n > 9) n -= 9; } // Odd position (1-indexed)
    total += n;
  }
  if (total % 10 !== 0) return { valid: false, error: 'SIRET invalide (clé de contrôle)' };

  return { valid: true, error: null, siren: siren, formatted: `${cleaned.slice(0,3)} ${cleaned.slice(3,6)} ${cleaned.slice(6,9)} ${cleaned.slice(9)}` };
}
