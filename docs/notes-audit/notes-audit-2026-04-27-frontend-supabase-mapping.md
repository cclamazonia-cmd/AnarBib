
src/contexts/LibraryContext.jsx
JavaScript
·
1
 (1)
    (async () => {
      const { data, error } = await supabase
        .from('user_library_memberships')
        .select('library_id, role, is_primary, libraries(id, slug, name, short_name)')
        .eq('user_id', user.id)
        .eq('status', 'active');


src/pages/importacoes/ImportacoesPage.jsx
JavaScript
·
7
 (7)
        () => supabase.from('partner_catalog_sources_ui').select('*').limit(200),
        () => supabase.schema('ingest').from('partner_catalog_sources').select('*').limit(200),
        () => supabase.from('partner_catalog_import_runs_ui').select('*').order('requested_at', { ascending: false }).l…
        () => supabase.schema('ingest').from('partner_catalog_import_runs').select('*').order('created_at', { ascending…
      const { error: uploadErr } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: true });
        () => supabase.from('partner_catalog_import_rows_ui').select('*').eq('run_id', runId).order('row_no').limit(500…
        () => supabase.schema('ingest').from('partner_catalog_staging_rows').select('*').eq('run_id', runId).order('row…


src/pages/catalogacao/BookDraftForm.jsx
JavaScript
·
13
 (13)
      const { error } = await supabase.storage
        .from('covers')
        .upload(storagePath, coverFile, { upsert: true });
Show 12 more matches


src/pages/catalogacao/QueuePanel.jsx
JavaScript
·
12
 (12)
      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts')
          .select('id, titulo, subtitulo, autor, status, action, batch_id, published_book_id, bib_ref, updated_at')
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts')
          .select('id, preferred_name, sort_name, status, action, batch_id, published_author_id, updated_at')
        let q = supabase.from('exemplar_drafts')
      const { data: bk } = await supabase.from('book_drafts').select('id, titulo, autor, status, updated_at').eq('statu…
      const { data: au } = await supabase.from('author_drafts').select('id, preferred_name, status, updated_at').eq('st…
      const { data: ex } = await supabase.from('exemplar_drafts').select('id, tombo, target_bib_ref, status, updated_at…
        await supabase.from(tableFor(type)).update({ status: 'cancelled' }).eq('id', id);
      try { await supabase.from(tableFor(type)).update({ status: 'ready' }).eq('id', id); ok++; } catch {}
Show 4 more matches


src/pages/catalogacao/CatalogacaoPage.jsx
JavaScript
·
9
 (9)
        supabase.from('catalog_batches').select('id', { count: 'exact', head: true }).eq('status', 'open'),
        supabase.from('book_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('author_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('exemplar_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
      const { data } = await supabase.from('catalog_batches')
      const { error } = await supabase.from('catalog_batches').insert({
Show 1 more match


src/pages/public/AuthorPage.jsx
JavaScript
·
3
 (3)
      setLoading(true);
      try {
        const [authorRes, booksRes, transRes] = await Promise.all([
          supabase.from('authors').select('*').eq('id', id).single(),
          supabase.from('author_books_public').select('*').eq('author_id', id),
          supabase.from('author_translations').select('lang, biography').eq('author_id', id),
        ]);


src/pages/catalogacao/LabelSheetPrinter.jsx
JavaScript
·
1
 (1)
    setLoading(true);
    (async () => {
      const { data } = await supabase
        .from('v_exemplar_labels')
        .select('*')
        .eq('library_id', libraryId)
        .order('exemplar_id', { ascending: false });


src/pages/public/CriarContaPage.jsx
JavaScript
·
3
 (3)
        const { data: libs } = await supabase.from('libraries').select('id, slug, name');
        const { data: commons } = await supabase.from('library_commons').select('library_id, logo_url, logo_file_key');
        const { data: regs } = await supabase.from('library_regulation_documents').select('library_id').eq('is_active',…


src/pages/public/BookPage.jsx
JavaScript
·
3
 (3)
        const { data } = await supabase.from('v_book_detail_public_v2').select('*').eq('book_id', id).limit(1).maybeSin…
          const fb = await supabase.from('books').select('*').eq('id', id).maybeSingle();
                    const { error } = await supabase.from('user_wishlist').upsert({ user_id: user.id, book_id: book.id …


src/pages/catalogacao/AuthorDraftForm.jsx
JavaScript
·
8
 (8)
    try {
      const { data } = await supabase.from('author_drafts')
        .select('id, preferred_name, sort_name, status, action, published_author_id, batch_id, updated_at')
      setPhotoUploading(true);
      const { error } = await supabase.storage.from('authors').upload(storagePath, photoFile, { upsert: true });
      if (error) throw error;
      supabase.from('author_translations').select('lang, biography, author_id').eq('author_id', authorId)
        const { data, error } = await supabase.from('author_drafts').update(payload).eq('id', Number(f('id'))).select()…
        const { data, error } = await supabase.from('author_drafts').insert(payload).select().single();
        const { data: draft } = await supabase.from('author_drafts').select('*').eq('id', Number(data)).single();
              const { data } = await supabase.from('author_drafts').select('*').eq('id', d.id).single();
                      await supabase.from('author_translations').upsert({


src/pages/painel/PanelPage.jsx
JavaScript
·
6
 (6)
        const { data: tasksData } = await supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId…
                                await supabase.from('painel_internal_tasks').update({ status: e.target.value }).eq('id'…
                        const { error } = await supabase.from('profiles').update(updateData).eq('id', readerProfile.id);
                          await supabase.from('profiles').update({ is_restricted: false, restricted_reason: null }).eq(…
                            await supabase.from('profiles').update({ is_restricted: true, restricted_reason: restrictRe…
                    await supabase.from('painel_internal_tasks').update({ status: e.target.value }).eq('id', tk.task_id…


src/pages/account/AccountPage.jsx
JavaScript
·
7
 (7)
      const [profileRes, reservRes, consultRes, loansRes, histRes, svcRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', user.id).single(),
        apiQuery('my_reservations_active_v2'),
        apiQuery('my_reservations_history_v2'),
        supabase.from('library_service_state').select('*'),
      ]);
      const { data: notifData } = await supabase.from('user_notifications').select('*').eq('user_id', user.id).order('c…
      const { data: wishData } = await supabase.from('user_wishlist').select('*, books:book_id(id, titulo, autor, bib_r…
      const { data } = await supabase.from('library_regulation_documents')
      const { error } = await supabase.from('profiles').update({
                            await supabase.from('user_wishlist').delete().eq('id', w.id);


src/pages/biblioteca/BibliotecaPage.jsx
JavaScript
·
38
 (38)
        supabase.from('libraries').select('*').eq('id', libraryId).single(),
        supabase.from('library_commons').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_service_state').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_regulation_documents').select('*').eq('library_id', libraryId).order('created_at', { asc…
        supabase.from('library_circulation_policy_sets').select('*').eq('library_id', libraryId).eq('is_active', true).…
        supabase.from('library_document_governance').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('catalog_partners').select('*').order('display_name'),
        supabase.from('user_library_memberships').select('*, profiles:user_id(email, first_name, last_name)').eq('libra…
Show 30 more matches


src/pages/catalogacao/ExemplarDraftForm.jsx
JavaScript
·
5
 (5)
      const { data } = await supabase.from('exemplar_drafts')
      const { data } = await supabase.from('books')
        const { data, error } = await supabase.from('exemplar_drafts').update(payload).eq('id', Number(f('id'))).select…
        const { data, error } = await supabase.from('exemplar_drafts').insert(payload).select().single();
              const { data } = await supabase.from('exemplar_drafts').select('*').eq('id', d.id).single();


src/pages/catalogacao/CatalogPanel.jsx
JavaScript
·
7
 (7)
    (async () => {
      try {
        const [{ count: bk }, { count: au }, { count: ex }] = await Promise.all([
          supabase.from('books').select('id', { count: 'exact', head: true }),
          supabase.from('authors').select('id', { count: 'exact', head: true }),
          supabase.from('exemplares').select('id', { count: 'exact', head: true }),
        ]);
        let q = supabase.from('books')
        let q = supabase.from('authors')
        let q = supabase.from('exemplares')
      const { error } = await supabase.from(table).delete().eq('id', id);


src/pages/rede/RedePage.jsx
JavaScript
·
17
 (17)
      const { data: libs } = await supabase.from('libraries').select('id, name, slug, short_name, city, state, country,…
      const { data: commons } = await supabase.from('library_commons').select('library_id, display_name, contact_email,…
      const { data: svcStates } = await supabase.from('library_service_state').select('library_id, service_mode, allows…
          supabase.from('user_library_memberships').select('id', { count:'exact', head:true }).eq('library_id', lib.id)…
          supabase.from('user_library_memberships').select('id', { count:'exact', head:true }).eq('library_id', lib.id)…
          supabase.from('exemplares').select('id', { count:'exact', head:true }).eq('library_id', lib.id),
          supabase.from('emprestimos_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id).or('statu…
          supabase.from('emprestimos_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id),
Show 9 more matches


src/pages/public/SolicitarBibliotecaPage.jsx
JavaScript
·
1
 (1)
        confirm_contact: true,
      };
      const { data, error } = await supabase.from('library_requests').insert(payload).select().single();
      if (error) throw error;
      // Try to send notification


src/pages/public/ReaderPage.jsx
JavaScript
·
1
 (1)
      try {
        if (id) {
          const { data } = await supabase.from('books').select('titulo').eq('id', id).maybeSingle();
          if (data && !cancelled) setBookTitle(data.titulo || '');
        }


src/pages/public/CatalogPage.jsx
JavaScript
·
1
 (1)
  useEffect(() => {
    if (!libraryId || !isAuth) return;
    (async () => {
      const { data } = await supabase.from('library_regulation_documents')
        .select('storage_bucket, storage_path_public')
        .eq('library_id', libraryId).eq('is_active', true).eq('publication_status', 'publicado')
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
