// Le formulaire de notice, côté base : envoi de la couverture, contributeur·rices,
// détection de doublon avant enregistrement, enregistrement du brouillon,
// publication, rechargement d'une notice (fillFromRecord), aperçu ISBD. Sorti de
// BookDraftForm.jsx tel quel (E6, 23/10/2026) ; les noms qu'il lit du formulaire
// sont ses entrées, ceux que le formulaire lit en retour sont rendus (calculés
// par @babel/traverse). Garde : src/tests/notice-sections-montees.test.jsx.
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { writeCoverThumb, cheminCapaNeuf, extensionCapa } from '@/lib/coverThumbs';
import { volumesDifferents } from '@/lib/volumes';
import { fichierSansMetadonnees } from '@/lib/imageMetadata';
import { NON_LOANABLE_TYPES, paquetIsbd } from '@/lib/catalogacao/bookDraft';

export function useNoticePersistance(p) {
  const {
    attachOcrPdf, confirmer, confirmSaved, contributors, coverFile, draftState, f, form, isArtigo,
    isAudio, isAudiovisual, isDigitalNative, isDossier, isNetworkAdmin, isRelatorio, isTese,
    isTract, isZine, materialType, ocrFileRef, onSaved, resetForm, set, setBookDupBusy,
    setBookDupLoading, setBookDupMatches, setContributors, setCoverCandidates, setCoverFile,
    setCoverUploading, setCreationChoice, setDigitalResources, setDraftState, setDupBanner,
    setDupModal, setEditionSugg, setForm, setFusionEdition, setImportedCheck, setIsbnDupHint,
    setLastPublished, setMsg, setSaving, setWork, setWorkNonce, showMsg, t, trackRetake, user,
  } = p;

  async function uploadCover() {
    if (!coverFile) return null;
    // P1 capas — clé de stockage stable (bib_ref || id), jamais 'new' :
    // un brouillon non sauvegardé n'a pas d'ancre stable et collisionnerait
    // sur books/new/ (perte de données). On exige une sauvegarde préalable.
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return null;
    }
    const ext = extensionCapa(coverFile.name);
    // Adresse NEUVE à chaque dépôt, jamais `upsert` : une image remplacée en
    // place restait servie une heure par le cache (coverThumbs.js, 28/09/2026).
    const storagePath = cheminCapaNeuf(stableKey, ext);

    setCoverUploading(true);
    try {
      // Le bucket est public : la capa part sans EXIF (GPS, appareil…), XMP,
      // IPTC ni commentaires — pixels inchangés (imageMetadata.js).
      const fichier = await fichierSansMetadonnees(coverFile);
      const { error } = await supabase.storage
        .from('covers')
        .upload(storagePath, fichier, { upsert: false });
      if (error) throw error;
      // Dérivé pour la grille du catalogue, produit depuis le fichier déjà en
      // mémoire (pas de retéléchargement). Best-effort : voir coverThumbs.js.
      await writeCoverThumb(storagePath, fichier);
      set('cover_object_path', storagePath);
      // Provenance de l'image qu'on vient d'envoyer : sans ça, elle héritait de
      // celle de la capa précédente (une candidate Open Library, par exemple).
      set('cover_source', 'manual');
      set('cover_license', '');
      setCoverFile(null);
      return storagePath;
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
      return null;
    } finally {
      setCoverUploading(false);
    }
  }

  // Synchronise le champ "autor" à partir des contributeurs
  function syncAutorFromContributors() {
    const named = contributors.filter(c => c.name.trim());
    if (!named.length) return;
    const _primary = named.find(c => c.is_primary) || named[0];
    set('autor', named.map(c => c.name.trim()).join(' ; '));
  }

  // Charge les contributeurs depuis la DB pour un draft existant.
  // Fallback (publishedBookId) : si le brouillon n'a aucun contributeur
  // structure (cas d'une reprise de livre publie, dont les book_contributors
  // ne sont pas copies dans le brouillon), on charge ceux du livre publie via
  // get_book_contributors_public -> lignes editables, sauvegardees au prochain
  // enregistrement du brouillon.
  // Remplit author_label (preferred_name) pour les lignes deja liees a une autorite.
  async function enrichAuthorLabels(rows) {
    const ids = [...new Set(rows.map(r => r.author_id).filter(Boolean))];
    if (!ids.length) return rows;
    try {
      const { data } = await supabase.from('authors').select('id, preferred_name').in('id', ids);
      const byId = new Map((data || []).map(a => [a.id, a.preferred_name]));
      return rows.map(r => r.author_id ? { ...r, author_label: byId.get(r.author_id) || '' } : r);
    } catch {
      return rows;
    }
  }

  async function loadContributors(draftId, publishedBookId = null) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_contributors')
        .select('*')
        .eq('draft_id', Number(draftId))
        .order('position', { ascending: true });
      if (error) throw error;
      if (data?.length) {
        setContributors(await enrichAuthorLabels(data.map(c => ({
          position: c.position,
          name: c.name || '',
          role: c.role || 'autor',
          is_primary: c.is_primary || false,
          author_id: c.author_id || null,
          author_label: '',
          nature: c.nature ?? null,        // H18
          role_code: c.role_code ?? null,  // H18 : code de fonction d'origine
        }))));
        return;
      }
      // Fallback : reprise d'un livre publie sans contributeurs de brouillon.
      if (publishedBookId) {
        // H18 : la table d'abord (nature, code d'origine, que la RPC publique
        // ne rend pas) ; la RPC en repli.
        let { data: pub, error: pubErr } = await supabase.from('book_contributors')
          .select('position, name, role, is_primary, author_id, nature, role_code')
          .eq('book_id', Number(publishedBookId))
          .order('position', { ascending: true });
        if (pubErr || !pub?.length) {
          ({ data: pub } = await supabase.rpc('get_book_contributors_public', { p_book_id: Number(publishedBookId) }));
        }
        if (Array.isArray(pub) && pub.length) {
          setContributors(await enrichAuthorLabels(pub.map(c => ({
            position: c.position,
            name: c.name || '',
            role: c.role || 'autor',
            is_primary: c.is_primary || false,
            author_id: c.author_id || null,
            author_label: '',
            nature: c.nature ?? null,
            role_code: c.role_code ?? null,
          }))));
        }
      }
    } catch (err) {
      console.warn('loadContributors error:', err);
    }
  }

  // Doublons de documents : detection (lecture seule, P2a)
  async function findBookDuplicates() {
    const bookId = f('published_book_id');
    if (!bookId) return;
    setBookDupLoading(true); setBookDupMatches(null);
    try {
      const { data, error } = await supabase.rpc('suggest_book_duplicates', { p_book_id: Number(bookId) });
      if (error) throw error;
      setBookDupMatches(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupLoading(false); }
  }

  // Regroupe la notice courante + un autre document comme éditions d'une même œuvre.
  async function groupAsEditions(otherBookId) {
    const bid = f('published_book_id'); if (!bid) return;
    setBookDupBusy(otherBookId);
    try {
      const { error } = await supabase.rpc('group_books_as_editions', { p_book_ids: [Number(bid), Number(otherBookId)] });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.grouped' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
      await findBookDuplicates(); // l'édition regroupée quitte les doublons
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // Sauvegarde les contributeurs (delete all + re-insert)
  async function saveContributors(draftId) {
    if (!draftId) return;
    const named = contributors.filter(c => c.name.trim());
    try {
      await supabase.from('book_draft_contributors').delete().eq('draft_id', Number(draftId));
      if (!named.length) return;
      const payload = named.map((c, i) => ({
        draft_id: Number(draftId),
        position: i + 1,
        name: c.name.trim(),
        role: c.role,
        is_primary: c.is_primary,
        author_id: c.author_id || null,
        // H18 : ne pas les perdre à l'enregistrement — et ne les envoyer que
        // lorsqu'elles portent une valeur : un écran publié avant la migration
        // ne doit pas échouer (colonne inconnue) après avoir effacé les lignes.
        ...(c.nature != null ? { nature: c.nature } : {}),
        ...(c.role_code != null ? { role_code: c.role_code } : {}),
      }));
      const { error } = await supabase.from('book_draft_contributors').insert(payload);
      if (error) throw error;
    } catch (err) {
      console.warn('saveContributors error:', err);
      throw err;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ISBD preparation (zones 0–8)
  // ═══════════════════════════════════════════════════════

  const ZONE_LABELS = {
    '0': t({id:'catalogacao.isbd.zone0'}),
    '1': t({id:'catalogacao.isbd.zone1'}),
    '2': t({id:'catalogacao.isbd.zone2'}),
    '3': t({id:'catalogacao.isbd.zone3'}),
    '4': t({id:'catalogacao.isbd.zone4'}),
    '5': t({id:'catalogacao.isbd.zone5'}),
    '6': t({id:'catalogacao.isbd.zone6'}),
    '7': t({id:'book.isbd.zone7'}),
    '8': t({id:'catalogacao.isbd.zone8'}),
  };

  // 18/10/2026 : plus de bouton « Préparer / Effacer l'ISBD ». L'aperçu du
  // panneau de révision suit la fiche en direct ; handleSave écrit le paquet
  // dans marc_json.anarbib_isbd à chaque enregistrement (paquetIsbd garde la
  // date tant que la description n'a pas changé). Comme à l'envoi, la zone 1
  // nomme les contributeurs nommés (dans l'ordre, « ; »), à défaut le texte d'auteur.
  const autorIsbd = contributors.filter((c) => (c.name || '').trim()).map((c) => c.name.trim()).join(' ; ');
  const isbdData = paquetIsbd({ ...form, autor: autorIsbd || f('autor') }, t, ZONE_LABELS);

  // ═══════════════════════════════════════════════════════
  // Duplicate detection (ISBN + title/author)
  // ═══════════════════════════════════════════════════════

  // Détecte un doublon probable AVANT la sauvegarde du brouillon.
  // Ne montre aucune UI : retourne { kind: 'isbn'|'approx', detail, bookId, score }
  // pour le meilleur candidat, sinon null (l'appelant ouvre la modale).
  //
  // Délègue à la RPC public.suggest_duplicates_for_fields (pg_trgm) : ISBN exact
  // + titre/auteur trigramme (tolère les variantes de titre), inter-bibliothèques.
  // Fonctionne aussi en ÉDITION d'une fiche publiée : p_exclude_book_id retire la
  // fiche elle-même et les paires déjà arbitrées « pas un doublon ».
  // Fail-open : toute erreur (RPC absente le temps du déploiement, réseau…) ->
  // null, on ne bloque jamais la sauvegarde.
  async function detectDuplicate() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();
    const excludeId = f('published_book_id') ? Number(f('published_book_id')) : null;

    if (!isbn && !title) return null; // rien a verifier

    try {
      const { data, error } = await supabase.rpc('suggest_duplicates_for_fields', {
        p_title: title || null,
        p_author: author || null,
        p_isbn: isbn || null,
        p_exclude_book_id: excludeId,
      });
      if (error) throw error;
      let suggestions = data || [];
      // Un autre VOLUME du même ensemble n'est pas un doublon, même ISBN (même
      // règle que publish_book_draft, lib/volumes.js). Sinon l'avertissement
      // poussait à enregistrer le volume 4 comme un exemplaire du volume 2.
      const idsIsbn = suggestions.filter((s) => s.match_kind === 'isbn').map((s) => s.book_id);
      if (f('volume').trim() && idsIsbn.length) {
        const { data: vols } = await supabase.from('books').select('id, volume').in('id', idsIsbn);
        const autres = new Set((vols || []).filter((b) => volumesDifferents(b.volume, f('volume'))).map((b) => b.id));
        suggestions = suggestions.filter((s) => !(s.match_kind === 'isbn' && autres.has(s.book_id)));
      }
      const top = suggestions[0];
      if (!top) return null;
      const detail = [
        top.titulo || '',
        top.ano ? `(${top.ano})` : '',
        top.bib_ref ? `ref. ${top.bib_ref}` : '',
        top.library_name || '',
      ].filter(Boolean).join(' · ');
      return {
        kind: top.match_kind === 'isbn' ? 'isbn' : 'approx',
        detail,
        bookId: top.book_id,
        score: top.score,
      };
    } catch (err) {
      console.warn('Duplicate check error:', err);
      return null; // fail-open
    }
  }

  // ═══════════════════════════════════════════════════════
  // Digital resources CRUD
  // ═══════════════════════════════════════════════════════

  async function loadDigitalResources(draftId) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_digital_resources')
        .select('*')
        .eq('book_draft_id', Number(draftId))
        .order('is_primary', { ascending: false })
        .order('id', { ascending: true });
      if (error) throw error;
      setDigitalResources(data || []);
    } catch (err) {
      console.warn('loadDigitalResources error:', err);
    }
  }

  // ── Draft state pill ───────────────────────────────────
  const statePills = {
    new: { label: t({id:'catalogacao.ui.newDraft'}), cls: 'info' },
    saved: { label: t({id:'catalogacao.state.saved'}), cls: 'ok' },
    dirty: { label: t({id:'catalogacao.msg.unsavedChanges'}), cls: 'warn' },
    ready: { label: t({id:'catalogacao.msg.readyToPublish'}), cls: 'ok' },
    published: { label: t({id:'catalogacao.msg.alreadyPublished'}), cls: 'ok' },
  };
  const pill = statePills[draftState] || statePills.new;

  // ── Save draft ─────────────────────────────────────────
  async function handleSave(e, { skipDupCheck = false } = {}) {
    e?.preventDefault();
    if (!f('titulo').trim()) { setMsg({ text: t({id:'catalogacao.msg.enterTitle'}), kind: 'error' }); return; }

    // Avertissement doublon — nouveaux brouillons ET mises à jour de fiches déjà
    // publiées (detectDuplicate exclut la fiche courante + les paires arbitrées
    // « pas un doublon »). On ouvre une modale centrée et on interrompt la
    // sauvegarde ; « Enregistrer quand même » rappelle handleSave avec skipDupCheck.
    if (!skipDupCheck) {
      const dup = await detectDuplicate();
      if (dup) { setDupModal(dup); return; }
    }

    setDupModal(null);
    setSaving(true);
    setMsg({ text: '', kind: '' });

    try {
      // Upload cover if file selected. Le chemin vient du RETOUR d'uploadCover :
      // `f()` lit l'état de CE rendu, d'avant l'envoi — la charge utile
      // repartait sans le chemin du fichier qu'on venait d'envoyer.
      const envoye = coverFile ? await uploadCover() : null;
      const isUpdate = !!f('id');
      // 18/10/2026 : le texte d'auteur part recomposé depuis les contributeurs, DANS cet envoi.
      // Il ne l'était qu'après (syncAutorFromContributors, plus bas) : le brouillon gardait le
      // texte d'avant, la publication le recopiait sur la notice — « Casamento Indissolúvel… »,
      // passée à Wilhelm Reich, restait trouvée par « Auteur : kropotkin ».
      const autorDesContributeurs = contributors
        .filter((c) => (c.name || '').trim())
        .map((c) => c.name.trim())
        .join(' ; ');
      // ISBD recalculé à chaque enregistrement (18/10/2026) : le paquet suit la
      // fiche sans clic ; sa date ne bouge que si une zone a changé. La zone 1
      // nomme le même auteur que la charge utile.
      const marcLu = f('marc_json') ? JSON.parse(f('marc_json')) : {};
      const marc = marcLu && typeof marcLu === 'object' && !Array.isArray(marcLu)
        ? { ...marcLu, anarbib_isbd: paquetIsbd({ ...form, autor: autorDesContributeurs || f('autor') }, t, ZONE_LABELS, marcLu.anarbib_isbd).data }
        : marcLu;
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_book_id: f('published_book_id') ? Number(f('published_book_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_book_id') ? 'update' : 'create',
        status: 'draft',
        // Œuvre parente (nouvelle édition) + exemplaires initiaux à la publication.
        // initial_copies_library_id n'est honoré côté serveur que pour un·e admin réseau.
        work_id: f('work_id') ? Number(f('work_id')) : null,
        initial_copies: Math.max(1, Math.min(50, parseInt(f('initial_copies'), 10) || 1)),
        initial_copies_library_id: (isNetworkAdmin && f('initial_copies_library_id')) ? f('initial_copies_library_id') : null,
        bib_ref: f('bib_ref') || null,
        titulo: f('titulo').trim(),
        subtitulo: f('subtitulo') || null,
        autor: autorDesContributeurs || f('autor') || null,
        edicao: f('edicao') || null,
        local_publicacao: f('local_publicacao') || null,
        editora: f('editora') || null,
        publisher_id: f('publisher_id') ? Number(f('publisher_id')) : null,
        ano: f('ano') || null,
        isbn: f('isbn') || null,
        issn: f('issn') || null,
        // #périodiques P7 : forcé à NULL hors fascicule/article — c'est aussi
        // ce qu'exige la garde G3, autant ne pas lui envoyer de quoi lever.
        serial_id: (materialType === 'periodico' || materialType === 'artigo') && f('serial_id')
          ? Number(f('serial_id')) : null,
        titulo_periodico: f('titulo_periodico') || null,
        volume: f('volume') || null,
        numero: f('numero') || null,
        fasciculo: f('fasciculo') || null,
        data_edicao: f('data_edicao') || null,
        periodicidade: f('periodicidade') || null,
        cdd: f('cdd') || null,
        idioma: f('idioma') || null,
        paginas: f('paginas') ? parseInt(f('paginas'), 10) || null : null,
        notas: f('notas') || null,
        tipo_material: materialType,
        circulation_default: NON_LOANABLE_TYPES.has(materialType) ? 'consulta' : (f('circulation_default') || 'emprestavel'),
        loanable: NON_LOANABLE_TYPES.has(materialType) ? false : (f('circulation_default') || 'emprestavel') !== 'consulta',
        colecao: f('colecao') || null,
        cover_object_path: envoye || f('cover_object_path') || null,
        // Provenance et licence suivent l'image (spec capas §4.3). Elles étaient
        // posées dans l'état et jamais envoyées : 0 capa attribuée sur 250.
        cover_source: envoye ? 'manual' : (f('cover_source') || null),
        cover_license: envoye ? null : (f('cover_license') || null),
        marc_json: marc,
        // Acquisition
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        owner_library: f('owner_library') || null,
        holder_library: f('holder_library') || null,
        owner_library_id: f('owner_library_id') || null,
        holder_library_id: f('holder_library_id') || null,
        source_label: f('source_label') || null,
        partner_source: f('partner_source') || null,
        source_record_id: f('source_record_id') || null,
        source_record_url: f('source_record_url') || null,
        import_format: f('import_format') || null,
        import_method: f('import_method') || null,
        provenance_note: f('provenance_note') || null,
        mutualization_status: f('mutualization_status') || null,
        // Material-specific
        tract_campaign: isTract ? (f('tract_campaign') || null) : null,
        emitter_org: isTract ? (f('emitter_org') || null) : null,
        approximate_date: isTract ? (f('approximate_date') || null) : null,
        diffusion_place: isTract ? (f('diffusion_place') || null) : null,
        recto_verso: isTract ? (f('recto_verso') || null) : null,
        physical_format: isTract ? (f('physical_format') || null) : null,
        print_technique: isTract ? (f('print_technique') || null) : null,
        physical_state: isTract ? (f('physical_state') || null) : null,
        audio_duration: isAudio ? (f('audio_duration') || null) : null,
        audio_support: isAudio ? (f('audio_support') || null) : null,
        audio_format: isAudio ? (f('audio_format') || null) : null,
        audio_language: isAudio ? (f('audio_language') || null) : null,
        audio_participants: isAudio ? (f('audio_participants') || null) : null,
        audio_recording_type: isAudio ? (f('audio_recording_type') || null) : null,
        audiovisual_duration: isAudiovisual ? (f('audiovisual_duration') || null) : null,
        audiovisual_support: isAudiovisual ? (f('audiovisual_support') || null) : null,
        audiovisual_language: isAudiovisual ? (f('audiovisual_language') || null) : null,
        audiovisual_director: isAudiovisual ? (f('audiovisual_director') || null) : null,
        audiovisual_participants: isAudiovisual ? (f('audiovisual_participants') || null) : null,
        audiovisual_subtitles: isAudiovisual ? (f('audiovisual_subtitles') || null) : null,
        audiovisual_access_note: isAudiovisual ? (f('audiovisual_access_note') || null) : null,
        distribuidora: isAudiovisual ? (f('distribuidora') || null) : null,
        gravadora: isAudio ? (f('gravadora') || null) : null,
        digital_native_url: isDigitalNative ? (f('digital_native_url') || null) : null,
        digital_native_access: isDigitalNative ? (f('digital_native_access') || null) : null,
        digital_native_restriction: isDigitalNative ? (f('digital_native_restriction') || null) : null,
        digital_native_usage: isDigitalNative ? (f('digital_native_usage') || null) : null,
        digital_native_file_note: isDigitalNative ? (f('digital_native_file_note') || null) : null,
        dossier_scope: isDossier ? (f('dossier_scope') || null) : null,
        dossier_period: isDossier ? (f('dossier_period') || null) : null,
        dossier_organizations: isDossier ? (f('dossier_organizations') || null) : null,
        dossier_context: isDossier ? (f('dossier_context') || null) : null,
        // Tese
        tese_university: isTese ? (f('tese_university') || null) : null,
        tese_advisor: isTese ? (f('tese_advisor') || null) : null,
        // Artigo
        artigo_source: isArtigo ? (f('artigo_source') || null) : null,
        artigo_volume: isArtigo ? (f('artigo_volume') || null) : null,
        artigo_issue: isArtigo ? (f('artigo_issue') || null) : null,
        artigo_pages: isArtigo ? (f('artigo_pages') || null) : null,
        // Relatorio
        relatorio_org: isRelatorio ? (f('relatorio_org') || null) : null,
        relatorio_recipient: isRelatorio ? (f('relatorio_recipient') || null) : null,
        relatorio_internal_notes: isRelatorio ? (f('relatorio_internal_notes') || null) : null,
        // Zine
        zine_print_run: isZine ? (f('zine_print_run') || null) : null,
        zine_technique: isZine ? (f('zine_technique') || null) : null,
        zine_format: isZine ? (f('zine_format') || null) : null,
        // Subjects (transversal)
        subjects: f('subjects') || null,
        updated_by: user?.id || null,
      };

      let result;
      if (isUpdate) {
        const id = payload.id;
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').update(payload).eq('id', id).select().single();
        if (error) throw error;
        result = data;
      } else {
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').insert(payload).select().single();
        if (error) throw error;
        result = data;
      }

      // B30 : l'écran montre ce que la base a GARDÉ, pas ce qui a été demandé.
      // Une notice d'avant B29 reçoit à l'enregistrement la bibliothèque de
      // son créateur (tg_drafts_library_fixed), et un rangement dans le lot
      // d'une autre bibliothèque est refusé en silence (le brouillon reste dans
      // son ancien lot) : sans cette relecture, le menu afficherait un lot que
      // la notice n'a pas.
      const lotDemande = String(f('batch_id') || '');
      const lotGarde = 'batch_id' in result ? String(result.batch_id || '') : lotDemande;
      setForm(prev => ({
        ...prev,
        id: String(result.id),
        batch_id: lotGarde,
        // le champ MARC JSON montre le paquet ISBD tel qu'il vient d'être écrit
        marc_json: marc ? JSON.stringify(marc, null, 2) : prev.marc_json,
        ...(result.owner_library_id ? { owner_library_id: result.owner_library_id, owner_library: result.owner_library || prev.owner_library } : {}),
      }));

      // Save contributors
      const warnings = [];
      if (lotGarde !== lotDemande) warnings.push(t({ id: 'error.batch.library_mismatch' }));
      try {
        syncAutorFromContributors();
        await saveContributors(result.id);
      } catch (contribErr) {
        warnings.push(t({id:'catalogacao.msg.contribWarning'}, {message: contribErr.message}));
      }

      // OCR (piste B) : rattache le PDF scanné déposé au brouillon créé.
      if (!isUpdate && ocrFileRef.current) {
        try {
          await attachOcrPdf(result.id, ocrFileRef.current);
          ocrFileRef.current = null;
          await loadDigitalResources(result.id);
        } catch (pdfErr) {
          warnings.push(t({ id: 'catalogacao.msg.ocrPdfWarning' }, { message: localizeError(pdfErr, t) }));
        }
      }

      setDraftState('saved');
      confirmSaved(
        warnings.length
          ? t({id:'catalogacao.msg.draftSavedWithWarnings'}, {warnings: warnings.join(' ; ')})
          : t({id:'catalogacao.msg.draftSaved'}),
        warnings.length ? 'warn' : 'ok',
      );
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Publish draft ──────────────────────────────────────
  async function handlePublish() {
    const draftId = f('id');
    if (!draftId) { showMsg(t({ id: 'catalogacao.msg.saveBeforePublish' }), 'error'); return; }

    // Validation côté client AVANT l'appel serveur (chantier B — UX immédiate)
    if (!f('titulo')?.trim()) {
      showMsg(t({ id: 'error.publish.titulo_required' }), 'error');
      return;
    }
    if (!f('bib_ref')?.trim()) {
      showMsg(t({ id: 'error.publish.bib_ref_required' }), 'error');
      return;
    }
    if (!f('tipo_material')?.trim()) {
      showMsg(t({ id: 'error.publish.tipo_material_required' }), 'error');
      return;
    }

    if (!(await confirmer({ message: t({id:'catalogacao.msg.publishConfirm'}), confirmLabel: t({ id: 'confirm.action.publish' }) }))) return;
    setDupBanner(null);

    try {
      // Mark as ready first + fige les paramètres œuvre/exemplaires les plus récents
      // (indépendamment d'une éventuelle sauvegarde antérieure). initial_copies_library_id
      // n'est de toute façon honoré côté serveur que pour un·e admin réseau.
      await supabase.from('book_drafts').update({
        status: 'ready',
        work_id: f('work_id') ? Number(f('work_id')) : null,
        initial_copies: Math.max(1, Math.min(50, parseInt(f('initial_copies'), 10) || 1)),
        initial_copies_library_id: (isNetworkAdmin && f('initial_copies_library_id')) ? f('initial_copies_library_id') : null,
      }).eq('id', Number(draftId));
      const { data: newBookId, error } = await supabase.rpc('publish_book_draft', { p_draft_id: Number(draftId) });
      if (error) throw error;

      // Try linking contributors to authors (publish_book_draft renvoie l'id du livre créé)
      const publishedId = newBookId || f('published_book_id');
      // H18 : une notice importée ne se rattache pas d'office aux autorités ;
      // ses rapprochements se proposent en révision du lot.
      let importee = false;
      try { const mj = JSON.parse(f('marc_json') || '{}'); importee = !!(mj && typeof mj === 'object' && 'ingest' in mj); } catch { importee = false; }
      if (publishedId && !importee) {
        try {
          await supabase.rpc('link_book_contributors_to_authors', { p_book_id: Number(publishedId) });
        } catch {}
      }

      // UX catalogage en série (2026-07) : après publication, on repart aussitôt
      // sur une fiche vierge pour enchaîner un nouveau brouillon. On capture le
      // titre et l'auteur·rice AVANT reset (resetForm les efface).
      const publishedTitle = f('titulo');
      const publishedAutor = f('autor');
      onSaved?.();
      resetForm();
      setCoverCandidates([]);
      setDupBanner(null);
      setIsbnDupHint(null);
      setWork(null);
      // 04/10/2026 : un seul encadré « Publié — et maintenant ? » remplace le
      // message, le toast, le bandeau « Ajouter un exemplaire ? » et la fenêtre
      // œuvre/édition qui revenait à chaque publication. La fenêtre ne s'ouvre
      // plus que sur « Nouveau document » (creationChoice non nul ici).
      setCreationChoice('work');
      let workId = null;
      if (publishedId) {
        try {
          const { data: pub } = await supabase.from('books').select('work_id').eq('id', Number(publishedId)).maybeSingle();
          workId = pub?.work_id || null;
        } catch { /* l'action « autre édition » sera simplement omise */ }
      }
      setLastPublished(publishedId ? { bookId: publishedId, draftId, title: publishedTitle, autor: publishedAutor, workId } : null);
      if (!publishedId) confirmSaved(t({ id: 'catalogacao.msg.bookPublishedNext' }, { title: publishedTitle }));
    } catch (err) {
      const raw = typeof err?.message === 'string' ? err.message : '';
      const code = raw.split(':', 1)[0].trim();
      if (code === 'isbn_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? Number(idPart) : null;
        setDupBanner({ bookId });
        showMsg('', '');
      } else if (code === 'bib_ref_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? idPart : '?';
        setDupBanner(null);
        showMsg(t({ id: 'catalogacao.msg.bibRefDuplicate' }, { bibRef: f('bib_ref') || '?', bookId }), 'error');
      } else {
        setDupBanner(null);
        showMsg(localizeError(err, t), 'error');
      }
    }
  }

  // ── Load existing draft ────────────────────────────────
  function fillFromRecord(record) {
    const r = record || {};
    trackRetake(r);
    setImportedCheck((c) => c + 1);   // H19 : relire les exemplaires importés
    // Les éditions suggérées et l'aperçu de fusion appartiennent à la notice
    // précédente : vu le 28/09, « Aucune édition à regrouper » restait affiché
    // sur la notice ouverte ensuite.
    setEditionSugg(null);
    setFusionEdition(null);
    setForm({
      id: String(r.id || ''),
      published_book_id: String(r.published_book_id || ''),
      batch_id: String(r.batch_id || ''),
      action: r.action || 'create',
      bib_ref: r.bib_ref || '',
      tipo_material: (r.tipo_material || 'livro').toLowerCase(),
      titulo: r.titulo || '',
      subtitulo: r.subtitulo || '',
      autor: r.autor || '',
      edicao: r.edicao || '',
      editora: r.editora || '',
      publisher_id: r.publisher_id ? String(r.publisher_id) : '',
      colecao: r.colecao || '',
      local_publicacao: r.local_publicacao || '',
      ano: r.ano || '',
      isbn: r.isbn || '',
      issn: r.issn || '',
      serial_id: r.serial_id != null ? String(r.serial_id) : '',
      titulo_periodico: r.titulo_periodico || '',
      volume: r.volume || '',
      numero: r.numero || '',
      fasciculo: r.fasciculo || '',
      data_edicao: r.data_edicao || '',
      periodicidade: r.periodicidade || '',
      cdd: r.cdd || '',
      idioma: r.idioma || '',
      paginas: r.paginas != null ? String(r.paginas) : '',
      loanable: String(r.loanable ?? true),
      circulation_default: r.loanable === false ? 'consulta' : (r.circulation_default || 'emprestavel'),
      notas: r.notas || '',
      subjects: r.marc_json?.anarbib_subjects?.join(' ; ') || '',
      cover_object_path: r.cover_object_path || '',
      cover_source: r.cover_source || '',
      cover_license: r.cover_license || '',
      marc_json: r.marc_json ? JSON.stringify(r.marc_json, null, 2) : '',
      acquisition_mode: r.acquisition_mode || '',
      acquisition_date: r.acquisition_date || '',
      owner_library: r.owner_library || '',
      holder_library: r.holder_library || '',
      owner_library_id: r.owner_library_id || '',
      holder_library_id: r.holder_library_id || '',
      source_label: r.source_label || '',
      partner_source: r.partner_source || '',
      source_record_id: r.source_record_id || '',
      source_record_url: r.source_record_url || '',
      import_format: r.import_format || '',
      import_method: r.import_method || '',
      provenance_note: r.provenance_note || '',
      mutualization_status: r.mutualization_status || '',
      tract_campaign: r.tract_campaign || '',
      emitter_org: r.emitter_org || '',
      approximate_date: r.approximate_date || '',
      diffusion_place: r.diffusion_place || '',
      recto_verso: r.recto_verso || '',
      physical_format: r.physical_format || '',
      print_technique: r.print_technique || '',
      physical_state: r.physical_state || '',
      audio_duration: r.audio_duration || '',
      audio_support: r.audio_support || '',
      audio_format: r.audio_format || '',
      audio_language: r.audio_language || '',
      audio_participants: r.audio_participants || '',
      audio_recording_type: r.audio_recording_type || '',
      audiovisual_duration: r.audiovisual_duration || '',
      audiovisual_support: r.audiovisual_support || '',
      audiovisual_language: r.audiovisual_language || '',
      audiovisual_director: r.audiovisual_director || '',
      audiovisual_participants: r.audiovisual_participants || '',
      audiovisual_subtitles: r.audiovisual_subtitles || '',
      audiovisual_access_note: r.audiovisual_access_note || '',
      distribuidora: r.distribuidora || '',
      gravadora: r.gravadora || '',
      digital_native_url: r.digital_native_url || '',
      digital_native_access: r.digital_native_access || '',
      digital_native_restriction: r.digital_native_restriction || '',
      digital_native_usage: r.digital_native_usage || '',
      digital_native_file_note: r.digital_native_file_note || '',
      dossier_scope: r.dossier_scope || '',
      dossier_period: r.dossier_period || '',
      dossier_organizations: r.dossier_organizations || '',
      dossier_context: r.dossier_context || '',
    });
    setDraftState(r.status === 'ready' ? 'ready' : (r.status === 'published' ? 'published' : (r.id ? 'saved' : 'new')));
    setMsg({ text: '', kind: '' });
    // Load contributors from DB if draft exists (fallback : livre publie repris)
    if (r.id) loadContributors(r.id, r.published_book_id);
    // Load digital resources
    if (r.id) loadDigitalResources(r.id);
  }

  return {
    fillFromRecord, findBookDuplicates, groupAsEditions, handlePublish, handleSave, isbdData,
    loadDigitalResources, pill, uploadCover, ZONE_LABELS,
  };
}
