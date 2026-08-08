/**
 * Onboarding state persistence utilities
 */

export function getStorageKey() {
  const token = localStorage.getItem('auth_token');
  if (!token) return 'onboarding_state';
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return `onboarding_state_${payload.sub || payload.user_id || ''}`;
  } catch {
    return 'onboarding_state';
  }
}

export function loadOnboardingState() {
  try {
    // Clean legacy unscoped key from previous versions
    localStorage.removeItem('onboarding_state');

    const saved = localStorage.getItem(getStorageKey());
    if (!saved) return null;

    return JSON.parse(saved);
  } catch (err) {
    console.error('Failed to restore onboarding state:', err);
    return null;
  }
}

export function saveOnboardingState(state) {
  try {
    localStorage.setItem(getStorageKey(), JSON.stringify(state));
  } catch (err) {
    console.error('Failed to save onboarding state:', err);
  }
}

export function clearOnboardingState() {
  try {
    localStorage.removeItem(getStorageKey());
  } catch (err) {
    console.error('Failed to clear onboarding state:', err);
  }
}
