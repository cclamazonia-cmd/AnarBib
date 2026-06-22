// src/lib/chromaprintFingerprint.js
// Chantier #AUDIO-fonds — P3c. Wrapper autour de la glue WASM de @unimusic/chromaprint
// (MIT), SANS le top-level await de son index.js (incompatible avec la cible de build
// Vite es2020 → on n'élève pas la cible globale pour une feature optionnelle). On importe
// la glue Emscripten directement et on initialise le module Chromaprint à la demande.
// Logique de fingerprint reprise de @unimusic/chromaprint/dist/index.js (config par
// défaut : empreinte compressée, 120 s max, algorithme Default).
// Session : Fonds sonores

let modulePromise = null;

// Initialisation paresseuse et unique du module WASM (pas de top-level await).
function getModule() {
  if (!modulePromise) {
    modulePromise = import('@unimusic/chromaprint/dist/chromaprint.js')
      .then((m) => (m.default || m)());
  }
  return modulePromise;
}

async function decodeAudio(buffer) {
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) throw new Error('error.audio.fingerprintRequired');
  const ac = new AC();
  try {
    return await ac.decodeAudioData(buffer);
  } finally {
    if (ac.close) ac.close();
  }
}

// Float32 [-1,1] → Int16 entrelacé, plafonné à maxDuration secondes.
function toInt16(audioBuffer, maxDuration) {
  const channels = audioBuffer.numberOfChannels;
  const length = Math.min(audioBuffer.length, Math.floor(maxDuration * audioBuffer.sampleRate));
  const pcm = new Int16Array(length * channels);
  for (let ch = 0; ch < channels; ch++) {
    const data = audioBuffer.getChannelData(ch);
    for (let i = 0; i < length; i++) {
      const s = Math.max(-1, Math.min(1, data[i]));
      pcm[i * channels + ch] = s * 32767;
    }
  }
  return pcm;
}

/**
 * Calcule l'empreinte Chromaprint (base64 compressée, compatible AcoustID) d'un
 * fichier audio fourni en ArrayBuffer.
 * @param {ArrayBuffer} arrayBuffer - octets bruts du fichier audio
 * @returns {Promise<{fingerprint: string, duration: number}>} durée en secondes
 */
export async function computeChromaprint(arrayBuffer) {
  const Module = await getModule();
  // decodeAudioData « détache » le buffer → on lui passe une copie.
  const decoded = await decodeAudio(arrayBuffer.slice(0));
  const duration = Math.round(decoded.duration);
  const sampleRate = decoded.sampleRate;
  const channels = decoded.numberOfChannels;
  const pcm = toInt16(decoded, 120);

  const ctx = Module._chromaprint_new(1); // 1 = ChromaprintAlgorithm.Default
  if (!ctx) throw new Error('error.audio.fingerprintRequired');
  try {
    if (!Module._chromaprint_start(ctx, sampleRate, channels)) {
      throw new Error('error.audio.fingerprintRequired');
    }
    const dataPtr = Module._malloc(pcm.length * 2); // 2 octets / int16
    try {
      Module.HEAP16.set(pcm, dataPtr / 2);
      if (!Module._chromaprint_feed(ctx, dataPtr, pcm.length)) {
        throw new Error('error.audio.fingerprintRequired');
      }
      if (!Module._chromaprint_finish(ctx)) {
        throw new Error('error.audio.fingerprintRequired');
      }
      const fpPtr = Module._malloc(4);
      if (!Module._chromaprint_get_fingerprint(ctx, fpPtr)) {
        Module._free(fpPtr);
        throw new Error('error.audio.fingerprintRequired');
      }
      const cStr = Module.HEAP32[fpPtr / 4];
      const fingerprint = Module.UTF8ToString(cStr);
      Module._free(cStr);
      Module._free(fpPtr);
      if (!fingerprint || !(duration > 0)) throw new Error('error.audio.fingerprintRequired');
      return { fingerprint, duration };
    } finally {
      Module._free(dataPtr);
    }
  } finally {
    Module._chromaprint_free(ctx);
  }
}
