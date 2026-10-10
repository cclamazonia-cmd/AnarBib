// src/hooks/useDebounce.js — E6, Catalogue public, lot 1 (10/10/2026) : sorti de CatalogPage.jsx tel quel.
import { useState, useEffect } from 'react';

export function useDebounce(value, delay = 400) {
  const [d, setD] = useState(value);
  useEffect(() => { const t = setTimeout(() => setD(value), delay); return () => clearTimeout(t); }, [value, delay]);
  return d;
}
