// @vitest-environment jsdom
//
// CHEMIN DÉPÔT : src/tests/session-end-notice.test.js
//
// « J'ai été déconnecté pour inactivité de plus d'une heure, mais cela
// n'apparaît que certaines fois, ou pendant un temps limité. »
//
// Les deux moitiés du symptôme avaient la même racine : l'explication ne
// vivait QUE dans le `?reason=idle` de l'URL, écrit par un seul chemin de
// code — le minuteur arrivant au bout alors que l'application est encore
// ouverte. Elle mourait au premier rechargement (« un temps limité ») et
// n'était jamais écrite quand la session s'éteignait autrement (« certaines
// fois ») : navigateur fermé, onglet recréé, storage vidé — or les tokens de
// l'équipe vivent en sessionStorage, donc ce cas est le plus banal des deux.
//
// Ces tests portent sur le marqueur persistant qui remplace la query string.

import { describe, it, expect, beforeEach } from 'vitest';
import {
  markSessionAlive,
  noteSessionEnded,
  clearSessionAlive,
  clearSessionEndNotice,
  readSessionEndNotice,
  NOTICE_MAX_AGE_MS,
  DEFAULT_IDLE_MS,
} from '@/lib/sessionEndNotice';

const MINUTE = 60 * 1000;
const T0 = 1_800_000_000_000; // instant de référence arbitraire mais fixe

describe("dire pourquoi la session s'est terminée", () => {
  beforeEach(() => {
    localStorage.clear();
    clearSessionEndNotice(); // remet aussi l'anti-rebond du battement à zéro
  });

  it('ne dit rien quand il n’y a rien à dire', () => {
    expect(readSessionEndNotice({ now: T0 })).toBe(null);
  });

  it('dit l’inactivité quand le minuteur l’a prononcée', () => {
    noteSessionEnded('idle', T0);
    expect(readSessionEndNotice({ now: T0 + MINUTE })).toBe('idle');
  });

  it('le dit encore après un rechargement — c’est tout l’objet du marqueur', () => {
    noteSessionEnded('idle', T0);
    // Un rechargement ne fait rien perdre à localStorage : on relit, simplement.
    expect(readSessionEndNotice({ now: T0 + 5 * MINUTE })).toBe('idle');
    expect(readSessionEndNotice({ now: T0 + 30 * MINUTE })).toBe('idle');
  });

  it('conclut à l’inactivité même si personne n’était là pour la prononcer', () => {
    // Le cas réel le plus fréquent : la session meurt à la fermeture du
    // navigateur, aucun code de l'app ne tourne, rien n'est « prononcé ».
    // Seul subsiste l'horodatage de la dernière activité.
    markSessionAlive(T0);
    expect(readSessionEndNotice({ now: T0 + 61 * MINUTE })).toBe('idle');
  });

  it('ne confond pas une fermeture rapide avec une heure d’inactivité', () => {
    markSessionAlive(T0);
    expect(readSessionEndNotice({ now: T0 + 10 * MINUTE })).toBe('closed');
  });

  it('place la frontière exactement au seuil du minuteur', () => {
    markSessionAlive(T0);
    expect(readSessionEndNotice({ now: T0 + DEFAULT_IDLE_MS - 1 })).toBe('closed');
    expect(readSessionEndNotice({ now: T0 + DEFAULT_IDLE_MS })).toBe('idle');
  });

  it('se tait quand l’explication est trop vieille pour expliquer quoi que ce soit', () => {
    markSessionAlive(T0);
    expect(readSessionEndNotice({ now: T0 + NOTICE_MAX_AGE_MS + MINUTE })).toBe(null);

    localStorage.clear();
    noteSessionEnded('idle', T0);
    expect(readSessionEndNotice({ now: T0 + NOTICE_MAX_AGE_MS + MINUTE })).toBe(null);
  });

  it('n’explique rien à qui s’est déconnecté·e volontairement', () => {
    markSessionAlive(T0);
    clearSessionAlive(); // ce que fait signOut()
    expect(readSessionEndNotice({ now: T0 + 2 * 60 * MINUTE })).toBe(null);
  });

  it('garde l’avis du minuteur malgré le nettoyage que signOut fait juste après', () => {
    // Ordre réel dans IdleTimerGuard : noteSessionEnded('idle') PUIS signOut(),
    // qui appelle clearSessionAlive(). Si ce nettoyage emportait l'avis, le
    // symptôme reviendrait à l'identique.
    noteSessionEnded('idle', T0);
    clearSessionAlive();
    expect(readSessionEndNotice({ now: T0 + MINUTE })).toBe('idle');
  });

  it('oublie tout à la reconnexion', () => {
    noteSessionEnded('idle', T0);
    clearSessionEndNotice(); // ce que fait AuthContext au SIGNED_IN
    expect(readSessionEndNotice({ now: T0 + MINUTE })).toBe(null);
  });

  it('n’écrit pas le battement à chaque clic', () => {
    markSessionAlive(T0);
    markSessionAlive(T0 + 1000); // ignoré : moins de 30 s après le précédent
    // Si la seconde écriture avait eu lieu, la dernière activité daterait de
    // T0+1000 et l'écart au seuil serait décalé d'autant.
    expect(readSessionEndNotice({ now: T0 + DEFAULT_IDLE_MS })).toBe('idle');
  });

  it('survit à un storage illisible plutôt que de casser la page', () => {
    localStorage.setItem('anarbib:session:ended', '{ ceci n’est pas du JSON');
    expect(readSessionEndNotice({ now: T0 })).toBe(null);
  });
});
