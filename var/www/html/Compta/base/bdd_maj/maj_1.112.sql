-- Rubrique 1: update Routines record_staging pour retourner _id_entry			
DROP FUNCTION public.record_staging(my_token_id text, my_id_entry integer);
CREATE FUNCTION public.record_staging(my_token_id text, my_id_entry integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE _id_entry integer;
BEGIN
-- Vérification si l'écriture avec token_id est présente dans tbljournal_staging
IF NOT EXISTS (SELECT 1 FROM tbljournal_staging WHERE _token_id = my_token_id) THEN
    RAISE EXCEPTION 'Aucune écriture trouvée dans tbljournal_staging pour token_id = %', my_token_id;
END IF;
-- Vérification de l'équilibre des montants
IF ( not (select sum(credit-debit) from tbljournal_staging where _token_id = $1) = 0 ) then RAISE EXCEPTION 'unbalanced'; END IF;
-- Supprimer les lignes où débit et crédit sont nuls
delete from tbljournal_staging where ( coalesce(debit, 0) + coalesce(credit, 0) = 0 and _token_id = my_token_id);
-- Si c'est une nouvelle entrée, id_entry = 0; lui affecter la nouvelle valeur
IF my_id_entry = 0 THEN
update tbljournal_staging set id_entry = (select nextval('tbljournal_id_entry_seq'::regclass)) where id_entry = 0 and _token_id = my_token_id;
ELSE
-- si c'est une mise à jour d'une entrée existante, il faut la supprimer
delete from tbljournal where id_entry = $2;
END IF;
-- pratiquer l'insertion proprement dite
insert into tbljournal (date_ecriture, id_facture, libelle, debit, credit, lettrage, id_line, id_entry, id_paiement, numero_compte, fiscal_year, id_client, libelle_journal, pointage, id_export, documents1, documents2, recurrent)
select date_ecriture, id_facture, libelle, debit, credit, lettrage, id_line, id_entry, id_paiement, numero_compte, fiscal_year, id_client, libelle_journal, pointage, id_export, documents1, documents2, recurrent
from tbljournal_staging where _token_id = $1;
-- si l'insertion s'est bien passée, on vide tbljournal_stagin
with t1 as (delete from tbljournal_staging where _token_id = $1
RETURNING id_entry)
select id_entry from t1 LIMIT 1 INTO _id_entry;
RETURN _id_entry;
END;
$_$;
ALTER FUNCTION public.record_staging(my_token_id text, my_id_entry integer) OWNER TO compta;
