export const STORAGE_ACCESS = 'em_access_token';
export const STORAGE_REFRESH = 'em_refresh_token';
export const STORAGE_USER = 'em_user';
export const STORAGE_WALLET = 'em_selected_wallet_id';
export const STORAGE_THEME = 'em_theme_mode';

const raw = import.meta.env.VITE_API_BASE_URL as string | undefined;
export const API_BASE = (raw?.replace(/\/$/, '') || '/api') as string;
