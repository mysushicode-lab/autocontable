-- Rubrique 1: Création de la table tblndf_bareme
CREATE TABLE IF NOT EXISTS public.tblndf_bareme (
		id_client integer NOT NULL,
		fiscal_year integer NOT NULL,
		vehicule text NOT NULL,
		puissance text NOT NULL,
		distance1 numeric,
		distance2 numeric,
		prime2 numeric,
		distance3 numeric
);
ALTER TABLE public.tblndf_bareme OWNER TO compta;
ALTER TABLE ONLY public.tblndf_bareme ADD CONSTRAINT tblndf_bareme_id_client_fiscal_year_vehicule_puissance PRIMARY KEY (id_client, fiscal_year, vehicule, puissance);
ALTER TABLE ONLY public.tblndf_bareme ADD CONSTRAINT tblndf_bareme_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
		
-- Rubrique 2: Création de la table tblndf_frais
CREATE TABLE public.tblndf_frais (
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			intitule text NOT NULL,
			compte text NOT NULL,
			tva numeric(4,2) DEFAULT '0'::numeric NOT NULL
);
ALTER TABLE public.tblndf_frais OWNER TO compta;
ALTER TABLE ONLY public.tblndf_frais ADD CONSTRAINT tblndf_frais_id_client_fiscal_year_intitule_compte_tva PRIMARY KEY (id_client, fiscal_year, intitule, compte, tva);
ALTER TABLE ONLY public.tblndf_frais ADD CONSTRAINT tblndf_frais_id_client_fiscal_year_compte_fkey FOREIGN KEY (id_client, fiscal_year, compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_frais ADD CONSTRAINT tblndf_frais_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 3: Création de la table	tblndf_vehicule	
CREATE TABLE public.tblndf_vehicule (
				id_client integer NOT NULL,
				fiscal_year integer NOT NULL,
				vehicule text NOT NULL,
				puissance text NOT NULL,
				vehicule_name text NOT NULL,
				numero_compte text NOT NULL,
				documents text,
				id_vehicule integer NOT NULL,
				electrique boolean DEFAULT false NOT NULL
);
ALTER TABLE public.tblndf_vehicule OWNER TO compta;
CREATE SEQUENCE public.tblndf_vehicule_id_vehicule_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;
ALTER TABLE public.tblndf_vehicule_id_vehicule_seq OWNER TO compta;
ALTER SEQUENCE public.tblndf_vehicule_id_vehicule_seq OWNED BY public.tblndf_vehicule.id_vehicule;
ALTER TABLE ONLY public.tblndf_vehicule ALTER COLUMN id_vehicule SET DEFAULT nextval('public.tblndf_vehicule_id_vehicule_seq'::regclass);
ALTER TABLE ONLY public.tblndf_vehicule	ADD CONSTRAINT tblndf_vehicule_id_client_fiscal_year_vehicule_puissance_vehicu UNIQUE (id_client, fiscal_year, vehicule, puissance, vehicule_name);
ALTER TABLE ONLY public.tblndf_vehicule ADD CONSTRAINT tblndf_vehicule_id_vehicule_id_client_fiscal_year PRIMARY KEY (id_vehicule, id_client, fiscal_year);
ALTER TABLE ONLY public.tblndf_vehicule ADD CONSTRAINT tblndf_vehicule_id_client_documents_fkey FOREIGN KEY (id_client, documents) REFERENCES public.tbldocuments(id_client, id_name) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_vehicule	ADD CONSTRAINT tblndf_vehicule_id_client_fiscal_year_numero_compte_fkey FOREIGN KEY (id_client, fiscal_year, numero_compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_vehicule	ADD CONSTRAINT tblndf_vehicule_id_client_fiscal_year_vehicule_puissance_fkey FOREIGN KEY (id_client, fiscal_year, vehicule, puissance) REFERENCES public.tblndf_bareme(id_client, fiscal_year, vehicule, puissance) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_vehicule	ADD CONSTRAINT tblndf_vehicule_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 4: Création de la table	tbljournal_type		
CREATE TABLE public.tbljournal_type (type_journal text NOT NULL);
ALTER TABLE public.tbljournal_type OWNER TO compta;
INSERT INTO tbljournal_type VALUES ('Achats'),('Ventes'),('Trésorerie'),('Clôture'),('OD'),('A-nouveaux');
ALTER TABLE ONLY public.tbljournal_type	ADD CONSTRAINT tbljournal_type_type_journal PRIMARY KEY (type_journal);
ALTER TABLE ONLY public.tbljournal_liste ADD CONSTRAINT tbljournal_liste_type_journal_fkey FOREIGN KEY (type_journal) REFERENCES public.tbljournal_type(type_journal) ON UPDATE CASCADE;

-- Rubrique 5: Création de la table tblndf				
CREATE TABLE public.tblndf (
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			piece_ref text NOT NULL,
			piece_date date NOT NULL,
			piece_compte text NOT NULL,
			piece_libelle text NOT NULL,
			piece_entry integer,
			id_vehicule integer,
			com1 text,
			com2 text,
			com3 text
);
ALTER TABLE public.tblndf OWNER TO compta;
ALTER TABLE ONLY public.tblndf ADD CONSTRAINT tblndf_id_client_fiscal_year_piece_ref PRIMARY KEY (id_client, fiscal_year, piece_ref);
ALTER TABLE ONLY public.tblndf ADD CONSTRAINT tblndf_id_client_fiscal_year_id_vehicule_fkey FOREIGN KEY (id_client, fiscal_year, id_vehicule) REFERENCES public.tblndf_vehicule(id_client, fiscal_year, id_vehicule);
ALTER TABLE ONLY public.tblndf ADD CONSTRAINT tblndf_id_client_fiscal_year_piece_compte_fkey FOREIGN KEY (id_client, fiscal_year, piece_compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf ADD CONSTRAINT tblndf_id_client_fkey1 FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 6: Création de la table tblndf_detail	
CREATE TABLE public.tblndf_detail (
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			piece_ref text NOT NULL,
			frais_date date NOT NULL,
			frais_compte text NOT NULL,
			frais_libelle text NOT NULL,
			frais_quantite integer,
			frais_montant integer DEFAULT 0 NOT NULL,
			frais_doc text,
			frais_line integer NOT NULL,
			frais_bareme numeric
);
ALTER TABLE public.tblndf_detail OWNER TO compta;
CREATE SEQUENCE public.tblndf_detail_frais_line_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;
ALTER TABLE public.tblndf_detail_frais_line_seq OWNER TO compta;
ALTER SEQUENCE public.tblndf_detail_frais_line_seq OWNED BY public.tblndf_detail.frais_line;
ALTER TABLE ONLY public.tblndf_detail ALTER COLUMN frais_line SET DEFAULT nextval('public.tblndf_detail_frais_line_seq'::regclass);
ALTER TABLE ONLY public.tblndf_detail ADD CONSTRAINT tblndf_detail_pkey PRIMARY KEY (frais_line);
ALTER TABLE ONLY public.tblndf_detail ADD CONSTRAINT tblndf_detail_id_client_fiscal_year_piece_ref_fkey FOREIGN KEY (id_client, fiscal_year, piece_ref) REFERENCES public.tblndf(id_client, fiscal_year, piece_ref) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY public.tblndf_detail ADD CONSTRAINT tblndf_id_client_fiscal_year_frais_compte_fkey FOREIGN KEY (id_client, fiscal_year, frais_compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_detail ADD CONSTRAINT tblndf_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblndf_detail ADD CONSTRAINT tblndf_id_client_frais_doc_fkey FOREIGN KEY (id_client, frais_doc) REFERENCES public.tbldocuments(id_client, id_name) ON UPDATE CASCADE;

-- Rubrique 7: update Routines record_staging pour retourner _id_entry			
DROP FUNCTION public.record_staging(my_token_id text, my_id_entry integer);
CREATE FUNCTION public.record_staging(my_token_id text, my_id_entry integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE _id_entry integer;
BEGIN
IF ( not (select sum(credit-debit) from tbljournal_staging where _token_id = $1) = 0 ) then RAISE EXCEPTION 'unbalanced'; END IF;
-- supprimer les champs où débit et crédit sont nulls
delete from tbljournal_staging where ( coalesce(debit, 0) + coalesce(credit, 0) = 0 and _token_id = my_token_id);
-- si c'est une nouvelle entrée, id_entry = 0; lui affecter la nouvelle valeur
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
