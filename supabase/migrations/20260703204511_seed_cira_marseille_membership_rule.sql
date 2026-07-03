-- #36 — Activer la cotisation du CIRA Marseille (décision Xavier + CIRA, 2026-07-03).
-- Cotisation annuelle, année CIVILE (jan–déc), minimum 30 EUR, requise pour la
-- circulation. Référence la biblio par slug (portable). Idempotent.
insert into public.library_membership_rules
  (library_id, name, description, amount_min, amount_suggested, currency,
   period_type, period_anchor, is_required, is_active, display_order)
select l.id,
       'Cotisation annuelle CIRA Marseille',
       'Cotisation annuelle (année civile janvier-décembre), minimum 30 EUR. Ouvre le droit d''emprunter jusqu''à 5 documents pour 3 mois.',
       30, 30, 'EUR',
       'annual'::membership_period_type,
       'calendar'::membership_period_anchor,
       true, true, 0
from public.libraries l
where l.slug = 'cira-marseille'
  and not exists (
    select 1 from public.library_membership_rules r
    where r.library_id = l.id and r.name = 'Cotisation annuelle CIRA Marseille'
  );
