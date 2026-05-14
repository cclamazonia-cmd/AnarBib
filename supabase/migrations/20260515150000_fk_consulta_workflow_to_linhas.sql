-- =============================================================================
-- FK : consulta_item_workflow_v2 -> consulta_linhas_v2
-- =============================================================================
-- Permet PostgREST embedded select :
--   from("consulta_linhas_v2").select("wf:consulta_item_workflow_v2(...)")
--
-- Sans cette FK, l'embedding echoue avec :
--   "Could not find a relationship between 'consulta_linhas_v2'
--   and 'consulta_item_workflow_v2' in the schema cache"
--
-- La cle composite (consulta_id, line_no) est UNIQUE des deux cotes
-- (consulta_linhas_v2_unique_line + consulta_item_workflow_v2_unique_line).
--
-- ON DELETE CASCADE : si une ligne consulta est supprimee, son workflow disparait.
-- DEFERRABLE INITIALLY DEFERRED : permet d'inserer dans n'importe quel ordre
--                                 dans une transaction (utile pour les triggers).
-- =============================================================================

ALTER TABLE consulta_item_workflow_v2
  ADD CONSTRAINT fk_consulta_item_workflow_v2_to_linhas
  FOREIGN KEY (consulta_id, line_no)
  REFERENCES consulta_linhas_v2(consulta_id, line_no)
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED;

-- Forcer le reload du cache schema PostgREST pour exposer la nouvelle relation
NOTIFY pgrst, 'reload schema';