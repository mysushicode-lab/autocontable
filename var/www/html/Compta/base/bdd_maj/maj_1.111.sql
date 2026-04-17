-- Rubrique 1: Création de la table tblmodel_template
CREATE TABLE public.tblmodel_template (
    template_name TEXT NOT NULL,            			-- Nom unique du modèle
    id_client INTEGER NOT NULL,                         -- Référence au client
    template_content TEXT,                              -- Contenu chiffré du modèle
    template_type TEXT NOT NULL,                        -- Type du modèle ('message', 'objet', etc.)
    json_content JSONB,                                 -- Contenu additionnel en format JSON
    CONSTRAINT tblmodel_template_pk PRIMARY KEY (id_client, template_name, template_type),  -- Clé primaire modifiée
    CONSTRAINT tblmodel_template_id_client_fkey FOREIGN KEY (id_client)
        REFERENCES public.compta_client(id_client) ON DELETE CASCADE ON UPDATE CASCADE
);
ALTER TABLE public.tblmodel_template OWNER TO compta;

-- Rubrique 2: Création de la table tbldocuments_historique
CREATE TABLE public.tbldocuments_historique (
    id_num SERIAL PRIMARY KEY,
    id_client INTEGER NOT NULL,
    document_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_description TEXT,
    user_id TEXT NOT NULL,
    event_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT tbldocuments_historique_id_client_fkey FOREIGN KEY (id_client)
        REFERENCES public.compta_client(id_client) ON DELETE CASCADE ON UPDATE CASCADE
);
ALTER TABLE public.tbldocuments_historique OWNER TO compta;
ALTER TABLE ONLY public.tbldocuments_historique ADD CONSTRAINT tbldocuments_historique_id_client_document_name_fkey FOREIGN KEY (id_client, document_name) REFERENCES public.tbldocuments(id_client, id_name) ON DELETE CASCADE ON UPDATE CASCADE;
