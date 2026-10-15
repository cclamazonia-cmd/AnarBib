// Empreintes SHA-256 et SHA-1 INCRÉMENTALES (NUMDIF D16, 15/10/2026 ; natives le 16/10).
// Session : File de candidats PDF.
//
// Pourquoi ici et pas crypto.subtle : crypto.subtle.digest veut tout le fichier
// d'un bloc. Le versement passe le PDF en flux, de la source au stockage, sans
// le tenir en mémoire (jusqu'à 500 Mo, la limite des seaux) : l'empreinte se
// calcule morceau par morceau, au passage. SHA-1 parce qu'une source MediaWiki
// (Anarchief, Wikisource) ne donne que lui : on le compare, et le SHA-256 se
// calcule au même premier téléchargement.
//
// NATIVES depuis le 16/10 (createHash de node:crypto, code Rust de l'Edge
// Runtime). La première version, en JavaScript pur, coûtait trop de CPU : la
// plateforme coupe un appel à 2 s de CPU (HTTP 546 WORKER_RESOURCE_LIMIT), et
// la fonction mourait vers 45-50 Mo — onze PDF d'Anarchief (43 à 98 Mo) ne
// passaient pas, même seuls. Mesuré le 16/10 dans l'image edge-runtime v1.77.1,
// limite dure de CPU posée par un service principal de banc, flux complet
// (fetch → empreintes → envoi), 98 Mo, poste sans instructions SHA :
//   JS pur          → coupé à 2 000 ms, dès 50 Mo
//   node:crypto     → passe sous 1 250 ms (coupé à 1 000 ms)
//   @std/crypto WASM→ passe sous 1 250 ms, un peu plus lent, et un import jsr:
//   sans empreinte  → passe sous 500 ms
// Les trois calculs rendent les mêmes empreintes sur les mêmes octets. Marge :
// environ 150-180 Mo par appel sur ce poste ; au-delà, un PDF retombera en 546
// (la limite des seaux, 500 Mo, reste plus haute que ce que l'appel encaisse).
// L'interface (update / hex) est celle de la version JS : index.ts n'a pas bougé.
// Garde : src/tests/numdif-empreintes.test.js (vecteurs connus, frontières de
// bloc, flux découpé n'importe comment).

import { createHash, type Hash } from 'node:crypto';

class Empreinte {
  private h: Hash;
  constructor(alg: 'sha256' | 'sha1') { this.h = createHash(alg); }
  update(donnees: Uint8Array): this { this.h.update(donnees); return this; }
  hex(): string { return this.h.digest('hex'); }
}

export class Sha256 extends Empreinte { constructor() { super('sha256'); } }
export class Sha1 extends Empreinte { constructor() { super('sha1'); } }
