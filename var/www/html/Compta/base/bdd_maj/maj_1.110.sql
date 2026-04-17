-- Rubrique 1: Création de la table tblsmtp
CREATE TABLE public.tblsmtp (
			id_client integer NOT NULL,
			smtp_type text,
			smtp_nom text,
			smtp_mail text,
			smtp_serveur text,
			smtp_port integer,
			smtp_user text,
			smtp_pass text,
			smtp_secu text,
			smtp_vers text,
			smtp_api_id text,
			smtp_api_secret text
);
ALTER TABLE public.tblsmtp OWNER TO compta;
ALTER TABLE ONLY public.tblsmtp ADD CONSTRAINT tblsmtp_id_client PRIMARY KEY (id_client);
ALTER TABLE ONLY public.tblsmtp ADD CONSTRAINT tblsmtp_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.compta_client(id_client) ON UPDATE CASCADE;
