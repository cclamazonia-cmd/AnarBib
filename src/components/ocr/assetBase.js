/**
 * assetBase.js — résout la base des assets tesseract selon l'environnement.
 *
 * Piste B (OCR navigateur). En dev : le vendor local servi par Vite. En prod :
 * le bucket public anarbib-media-public/ocr/ (assets gitignorés, déposés via
 * scripts/upload-ocr-assets.mjs). getPublicUrl est synchrone (pas de réseau).
 */
import { supabase } from '@/lib/supabase';

export const OCR_ASSET_BASE = import.meta.env.DEV
  ? '/vendor/tesseract'
  : supabase.storage.from('anarbib-media-public').getPublicUrl('ocr').data.publicUrl;
