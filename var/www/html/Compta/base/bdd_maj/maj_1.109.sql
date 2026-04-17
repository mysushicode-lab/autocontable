-- Rubrique 1: Création de la table tbldocuments_tags
CREATE TABLE public.tbldocuments_tags (
			id_client integer NOT NULL,
			tags_nom text NOT NULL,
			tags_doc text NOT NULL
);
ALTER TABLE public.tbldocuments_tags OWNER TO compta;
ALTER TABLE ONLY public.tbldocuments_tags ADD CONSTRAINT tbldocuments_tags_id_client_tags_nom_tags_doc PRIMARY KEY (id_client, tags_nom, tags_doc);
ALTER TABLE ONLY public.tbldocuments_tags ADD CONSTRAINT tbldocuments_tags_id_client_tags_doc_fkey FOREIGN KEY (id_client, tags_doc) REFERENCES public.tbldocuments(id_client, id_name) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY public.tbldocuments_tags ADD CONSTRAINT tbldocuments_tags_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE ON DELETE CASCADE;
	
-- Rubrique 2: Création de la table tblimmobilier_logement
CREATE TABLE public.tblimmobilier_logement (
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			biens_ref text NOT NULL,
			biens_nom text NOT NULL,
			biens_adresse text,
			biens_cp integer,
			biens_ville text,
			biens_surface integer,
			biens_compte text,
			biens_com1 text,
			biens_com2 text,
			biens_archive boolean DEFAULT false NOT NULL
);
ALTER TABLE public.tblimmobilier_logement OWNER TO compta;
ALTER TABLE ONLY public.tblimmobilier_logement ADD CONSTRAINT tblimmobilier_logement_id_client_biens_ref PRIMARY KEY (id_client, biens_ref);
ALTER TABLE ONLY public.tblimmobilier_logement ADD CONSTRAINT tblimmobilier_logement_id_client_fiscal_year_biens_compte_fkey FOREIGN KEY (id_client, fiscal_year, biens_compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblimmobilier_logement ADD CONSTRAINT tblimmobilier_logement_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
		
-- Rubrique 3: Création de la table tblbilan
CREATE TABLE public.tblbilan (
			id_client integer NOT NULL,
			bilan_form text NOT NULL,
			bilan_desc text,
			bilan_doc text,
			bilan_width integer,
			bilan_height integer,
			bilan_disp boolean DEFAULT false
);
ALTER TABLE public.tblbilan OWNER TO compta;
ALTER TABLE ONLY public.tblbilan ADD CONSTRAINT tblbilan_id_client_form PRIMARY KEY (id_client, bilan_form);
ALTER TABLE ONLY public.tblbilan ADD CONSTRAINT tblbilan_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 4: Création de la table tblbilan_code		
CREATE TABLE public.tblbilan_code (
			id_client integer NOT NULL,
			formulaire text NOT NULL,
			code text NOT NULL,
			exercice text NOT NULL,
			description text,
			title text,
			style_top integer,
			style_left integer,
			style_width integer,
			style_height integer
		);
ALTER TABLE public.tblbilan_code OWNER TO compta;
ALTER TABLE ONLY public.tblbilan_code ADD CONSTRAINT tblbilan_code_id_client_formulaire_code PRIMARY KEY (id_client, formulaire, code);
ALTER TABLE ONLY public.tblbilan_code ADD CONSTRAINT tblbilan_code_id_client_formulaire_fkey FOREIGN KEY (id_client, formulaire) REFERENCES public.tblbilan(id_client, bilan_form) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY public.tblbilan_code ADD CONSTRAINT tblbilan_code_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
		
-- Rubrique 5: Création de la table tblbilan_detail
CREATE TABLE public.tblbilan_detail (
			id_client integer NOT NULL,
			formulaire text NOT NULL,
			code text NOT NULL,
			compte_mini text NOT NULL,
			compte_maxi text NOT NULL,
			compte_journal text,
			solde_type text NOT NULL,
			si_debit boolean DEFAULT false,
			si_credit boolean DEFAULT false,
			si_soustraire boolean DEFAULT false
		);
ALTER TABLE public.tblbilan_detail OWNER TO compta;
ALTER TABLE ONLY public.tblbilan_detail ADD CONSTRAINT tblbilan_detail_id_client_form_code_mini_maxi_pkey PRIMARY KEY (id_client, formulaire, code, compte_mini, compte_maxi );
ALTER TABLE ONLY public.tblbilan_detail ADD CONSTRAINT tblbilan_detail_id_client_form_code_fkey FOREIGN KEY (id_client, formulaire, code) REFERENCES public.tblbilan_code(id_client, formulaire, code) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY public.tblbilan_detail ADD CONSTRAINT tblbilan_detail_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
		
-- Rubrique 6: Création de la table tblimmobilier
CREATE TABLE public.tblimmobilier (
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			immo_contrat text NOT NULL,
			immo_libelle text NOT NULL,
			immo_logement text NOT NULL,
			immo_locataire text,
			immo_compte text,
			immo_loyer integer,
			immo_depot integer,
			immo_date1 date,
			immo_date2 date,
			immo_entry integer,
			immo_com1 text,
			immo_com2 text,
			immo_archive boolean DEFAULT false NOT NULL
		);
ALTER TABLE public.tblimmobilier OWNER TO compta;
ALTER TABLE ONLY public.tblimmobilier ADD CONSTRAINT tblimmobilier_id_client_immo_contrat_ref PRIMARY KEY (id_client, immo_contrat);
ALTER TABLE ONLY public.tblimmobilier ADD CONSTRAINT tblimmobilier_id_client_biens_ref_fkey FOREIGN KEY (id_client, immo_logement) REFERENCES public.tblimmobilier_logement(id_client, biens_ref) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblimmobilier ADD CONSTRAINT tblimmobilier_id_client_fiscal_year_piece_compte_fkey FOREIGN KEY (id_client, fiscal_year, immo_compte) REFERENCES public.tblcompte(id_client, fiscal_year, numero_compte) ON UPDATE CASCADE;
ALTER TABLE ONLY public.tblimmobilier ADD CONSTRAINT tblimmobilier_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 7: Création de la table tblimmobilier_locataire		
CREATE TABLE public.tblimmobilier_locataire (
			id_loc integer NOT NULL,
			id_client integer NOT NULL,
			fiscal_year integer NOT NULL,
			locataires_ref text NOT NULL,
			locataires_contrat text NOT NULL,
			locataires_type text NOT NULL,
			locataires_civilite text NOT NULL,
			locataires_nom text NOT NULL,
			locataires_prenom text NOT NULL,
			locataires_adresse text,
			locataires_cp integer,
			locataires_ville text,
			locataires_naissance_date date,
			locataires_naissance_lieu text,
			locataires_telephone text,
			locataires_courriel text,
			locataires_com1 text,
			locataires_com2 text
		);
ALTER TABLE public.tblimmobilier_locataire OWNER TO compta;
CREATE SEQUENCE public.tblimmobilier_locataire_id_loc_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;
ALTER TABLE public.tblimmobilier_locataire_id_loc_seq OWNER TO compta;
ALTER SEQUENCE public.tblimmobilier_locataire_id_loc_seq OWNED BY public.tblimmobilier_locataire.id_loc;
ALTER TABLE ONLY public.tblimmobilier_locataire ALTER COLUMN id_loc SET DEFAULT nextval('public.tblimmobilier_locataire_id_loc_seq'::regclass);
ALTER TABLE ONLY public.tblimmobilier_locataire ADD CONSTRAINT tblimmobilier_locataire_id_loc_id_client_ref PRIMARY KEY (id_loc, id_client);
ALTER TABLE ONLY public.tblimmobilier_locataire ADD CONSTRAINT tblimmobilier_locataire_id_client_locataires_contrat_fkey FOREIGN KEY (id_client, locataires_contrat) REFERENCES public.tblimmobilier(id_client, immo_contrat) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY public.tblimmobilier_locataire ADD CONSTRAINT tblimmobilier_locataire_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;

-- Rubrique 8: update Routines
DROP FUNCTION public.delete_account_data(id_client integer);
CREATE FUNCTION public.delete_account_data(id_client integer) RETURNS void
LANGUAGE sql
AS $_$
update tbljournal set id_export = null where id_client = $1;	
delete from tbllocked_month where id_client = $1;	
delete from tblexport where id_client = $1;	
delete from tbljournal where id_client = $1;
delete from tbljournal_liste where id_client = $1;
delete from tblbilan_detail where id_client = $1;
delete from tblbilan_code where id_client = $1;
delete from tblbilan where id_client = $1;
delete from tblimmobilier_locataire where id_client = $1;
delete from tblimmobilier where id_client = $1;
delete from tblimmobilier_logement where id_client = $1;
delete from tblndf where id_client = $1;
delete from tblndf_vehicule where id_client = $1;
delete from tblndf_bareme where id_client = $1;
delete from tbldocuments where id_client = $1;
delete from tbldocuments_categorie where id_client = $1;
delete from tblcompte where id_client = $1;
delete from tbljournal_liste where id_client = $1;
delete from tbljournal_staging where id_client = $1;
delete from tblcerfa_2_detail where id_entry in (select id_entry from tblcerfa_2 where id_client = $1);
delete from tblcerfa_2 where id_client = $1;
delete from compta_user where id_client = $1 and username != 'superadmin' ;
delete from compta_client where id_client = $1;
$_$;
ALTER FUNCTION public.delete_account_data(id_client integer) OWNER TO compta;
