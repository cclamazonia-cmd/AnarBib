import { Component } from 'react';
import { isChunkLoadError, reloadOnceForStaleChunk, hardReloadClearingSW } from '@/lib/chunkReload';

// Filet de sécurité de rendu. Aujourd'hui l'app n'a AUCUN error boundary : la
// moindre erreur de rendu (ou un chunk lazy en 404 après déploiement) fait
// planter tout l'arbre React en silence → écran figé/blanc, refresh manuel
// obligatoire. Ce boundary :
//   - sur une erreur de chunk : recharge une fois (cf. lib/chunkReload). Le
//     handler 'vite:preloadError' de main.jsx intercepte le cas usuel AVANT
//     que ça remonte ici ; ce composant reste le filet pour les cas résiduels.
//   - sur toute autre erreur : affiche un écran lisible avec bouton « Recarregar »
//     plutôt qu'un écran blanc muet.
//
// Textes en pt-BR (locale par défaut de l'app, cf. la page 404 de App.jsx) —
// un boundary de classe ne peut pas consommer le hook react-intl.
export class ErrorBoundary extends Component {
  state = { error: null };

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error) {
    if (isChunkLoadError(error)) reloadOnceForStaleChunk();
  }

  render() {
    const { error } = this.state;
    if (!error) return this.props.children;

    const chunk = isChunkLoadError(error);
    return (
      <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted, #9a93a6)' }}>
        <h1 style={{ color: 'var(--brand-text, #f5f2ea)', marginBottom: 10 }}>
          {chunk ? 'Atualização disponível' : 'Algo deu errado'}
        </h1>
        <p style={{ marginBottom: 20 }}>
          {chunk
            ? 'Uma nova versão do aplicativo foi publicada. Recarregue para continuar.'
            : 'Ocorreu um erro inesperado nesta página.'}
        </p>
        <button
          onClick={() => hardReloadClearingSW()}
          style={{
            font: 'inherit', fontWeight: 600, cursor: 'pointer',
            padding: '10px 20px', borderRadius: 10,
            border: '1px solid var(--brand-panel-border, rgba(255,255,255,.18))',
            background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))',
            color: 'var(--brand-text, #f5f2ea)',
          }}
        >
          Recarregar
        </button>
      </div>
    );
  }
}

export default ErrorBoundary;
