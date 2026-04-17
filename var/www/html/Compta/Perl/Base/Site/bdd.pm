package Base::Site::bdd;
#-----------------------------------------------------------------------------------------
#Version 1.10 - Juillet 1th, 2022
#-----------------------------------------------------------------------------------------
#	
#	Créé par picsou83 (https://github.com/picsou83)
#	
#-----------------------------------------------------------------------------------------
#Version History (Changelog)
#-----------------------------------------------------------------------------------------
#
##########################################################################################
#
#Ce logiciel est un programme informatique de comptabilité
#
#Ce logiciel est régi par la licence CeCILL-C soumise au droit français et
#respectant les principes de diffusion des logiciels libres. Vous pouvez
#utiliser, modifier et/ou redistribuer ce programme sous les conditions
#de la licence CeCILL-C telle que diffusée par le CEA, le CNRS et l'INRIA 
#sur le site "http://www.cecill.info".
#
#En contrepartie de l'accessibilité au code source et des droits de copie,
#de modification et de redistribution accordés par cette licence, il n'est
#offert aux utilisateurs qu'une garantie limitée.  Pour les mêmes raisons,
#seule une responsabilité restreinte pèse sur l'auteur du programme,  le
#titulaire des droits patrimoniaux et les concédants successifs.
#
#A cet égard  l'attention de l'utilisateur est attirée sur les risques
#associés au chargement,  à l'utilisation,  à la modification et/ou au
#développement et à la reproduction du logiciel par l'utilisateur étant 
#donné sa spécificité de logiciel libre, qui peut le rendre complexe à 
#manipuler et qui le réserve donc à des développeurs et des professionnels
#avertis possédant  des  connaissances  informatiques approfondies.  Les
#utilisateurs sont donc invités à charger  et  tester  l'adéquation  du
#logiciel à leurs besoins dans des conditions permettant d'assurer la
#sécurité de leurs systèmes et ou de leurs données et, plus généralement, 
#à l'utiliser et l'exploiter dans les mêmes conditions de sécurité. 
#
#Le fait que vous puissiez accéder à cet en-tête signifie que vous avez 
#pris connaissance de la licence CeCILL-C, et que vous en avez accepté les
#termes.
###########################################################################################
######              Module dédié aux interactions avec la base de données            ######
###### Ce module fournit des fonctions pour exécuter des requêtes SQL,               ######
###### récupérer et manipuler les données stockées dans une base de données,         ######
###### et effectuer d'autres opérations liées à la persistance des données.          ######
###### Mémo $info_societe->[0]->{etablissement}										 ######
###########################################################################################
use strict;  # Utilisation stricte des variables
use warnings;  # Activation des avertissements
# Modules externes utilisés dans le script
use Time::Piece;       # Gestion des dates et heures
use utf8;              # Encodage UTF-8
use Encode;            # Encodage de caractères
use Apache2::Const -compile => qw( OK REDIRECT ) ;
use DBI;			   # Connexion à la base de données

# Fonction pour récupérer le nombre d'écritures récurrentes ou les écritures récurrentes par année 
# Pour obtenir le compte en attente ($count_en_attente=>1)
#my $nb_recurrent_count = Base::Site::bdd::get_recurrent_data($r, $dbh, 0, 1);
# Pour obtenir les entrées de l'année courante ($count_en_attente=>0 et $year_offset=>0)
#my $recurrent_courantes = Base::Site::bdd::get_recurrent_data($r, $dbh, 0, 0);
# Pour obtenir les entrées de l'année précédente ($count_en_attente=>0 et $year_offset=>-1)
#my $recurrent_annee_precedente = Base::Site::bdd::get_recurrent_data($r, $dbh, -1, 0);
sub get_recurrent_data {
    my ($r, $dbh, $year_offset, $count_en_attente) = @_;

    my $sql;

    if ($count_en_attente) {
        $sql = '
            WITH t1 AS (
                SELECT id_entry, date_ecriture
                FROM tbljournal
                WHERE id_client = ? AND recurrent = true AND fiscal_year = ?
                GROUP BY id_entry, date_ecriture
            )
            SELECT COUNT(id_entry) FROM t1
        ';
    } else {
        $sql = '
            SELECT id_entry, date_ecriture
            FROM tbljournal
            WHERE id_client = ? AND recurrent = true AND fiscal_year = ?
            GROUP BY id_entry, date_ecriture
        ';
    }

    my $fiscal_year = $r->pnotes('session')->{fiscal_year} + $year_offset;
    my @bind_array = ($r->pnotes('session')->{id_client}, $fiscal_year);

    my $result;

    eval {
        if ($count_en_attente) {
            $result = $dbh->selectall_arrayref($sql, undef, @bind_array)->[0]->[0];
        } else {
            $result = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
        }
    };

    if ($@) {
        Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 'bdd.pm => get_recurrent_data => Erreur lors de la requête SQL : ' . $@ .'. ');
        return undef; # Indiquer une erreur
    }

    return $result;
}

# Fonction pour récupérer les documents (tous ou vérifier si $filename est present)
# my $documents = Base::Site::bdd::get_documents($dbh, $id_client, $fiscal_year, $filename);
sub get_documents {
    my ($dbh, $id_client, $fiscal_year, $filename) = @_;
    
    # Base de la requête SQL
    my $sql = 'SELECT id_name, fiscal_year FROM tbldocuments WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?)))';
    my @bind_array = ($id_client, $fiscal_year, $fiscal_year);
    
    # Ajout d'une condition si le nom de fichier est fourni
    if (defined $filename) {
        $sql .= ' AND id_name = ?';
        push @bind_array, $filename;
    }
    
    # Ajout de l'ordre de tri
    $sql .= ' ORDER BY id_name, date_reception';
    
    # Exécution de la requête
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# Fonction pour récupérer un document
# my $info_doc = Base::Site::bdd::get_info_doc($dbh, $id_client, $id_name);
#if ($info_doc) {my $doc_name = $info_doc->{id_name}; my $doc_fiscal = $info_doc->{fiscal_year}; }
sub get_info_doc {
    my ($dbh, $id_client, $id_name) = @_;
    my $sql = 'SELECT * FROM tbldocuments WHERE id_client = ? AND id_name = ?';
    my @bind_array = ($id_client, $id_name);
    my $result = $dbh->selectrow_hashref($sql, undef, @bind_array);
    return $result;  # Retourne le contenu du document (ou undef si non trouvé)
}

# Fonction pour récupérer les tblconfig_liste
# Exemple d'utilisation :
# my $query_tblconfig_liste = Base::Site::bdd::get_tblconfig_liste($dbh, $r, 'achats');
# my $query_tblconfig_liste = Base::Site::bdd::get_tblconfig_liste($dbh, $r, 'documents');
sub get_tblconfig_liste {
    my ($dbh, $r, $module) = @_;
    my $sql = 'SELECT * FROM tblconfig_liste WHERE id_client = ? AND module = ? ORDER by config_libelle';
    my @bind_array = ($r->pnotes('session')->{id_client}, $module);
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# my $email = Base::Site::bdd::get_locataires_courriel($dbh, $r, $tags_doc);
sub get_locataires_courriel {
    my ($dbh, $r, $tags_doc) = @_;
    
    my $sql = q{
        SELECT *
        FROM (
            SELECT DISTINCT ON(t1.tags_nom) t2.immo_archive, t1.id_client, t2.immo_contrat
            FROM tbldocuments_tags t1
            INNER JOIN tblimmobilier t2 ON t1.id_client = t2.id_client AND t1.tags_nom = t2.immo_contrat
            WHERE t1.id_client = ? AND t1.tags_doc = ?
        ) AS subquery
        JOIN tblimmobilier_locataire tl ON subquery.id_client = tl.id_client
            AND subquery.immo_contrat = tl.locataires_contrat
        WHERE tl.locataires_courriel IS NOT NULL
        LIMIT 1
    };

    my @bind_array = ($r->pnotes('session')->{id_client}, $tags_doc);
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_array);
    
    my $locataires_courriel = $sth->fetchrow_hashref();
    $sth->finish();

    return $locataires_courriel;
}

# my $email_info = Base::Site::bdd::get_locataires_info($dbh, $r, $contrat);
sub get_locataires_info {
    my ($dbh, $r, $contrat) = @_;
    
    my $sql = q{
		SELECT *
		FROM tblimmobilier_locataire tl
		INNER JOIN tblimmobilier t2 ON tl.id_client = t2.id_client 
			AND tl.locataires_contrat = t2.immo_contrat
		LEFT JOIN tblimmobilier_logement t3 ON tl.id_client = t3.id_client AND t2.immo_logement = t3.biens_ref
		WHERE tl.id_client = ?
			AND tl.locataires_contrat = ?
			AND tl.locataires_courriel IS NOT NULL
		LIMIT 1;
    };

    my @bind_array = ($r->pnotes('session')->{id_client}, $contrat);
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_array);
    
    my $locataires_info = $sth->fetchrow_hashref();
    $sth->finish();

    return $locataires_info;
}




# Fonction pour récupérer la liste des journaux ou un code_journal spécifique
# my $journaux = Base::Site::bdd::get_journaux($dbh, $r, $libelle_journal);
sub get_journaux {
    my ($dbh, $r, $libelle_journal) = @_;
    # Paramètres de base (client + année fiscale)
    my $sql;
    my @bind_array = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	# Si un libelle_journal est fourni, on récupère le code_journal correspondant
    if ($libelle_journal) {
        $sql = 'SELECT code_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? AND libelle_journal = ?';
        push @bind_array, $libelle_journal;
        return eval { $dbh->selectrow_array($sql, undef, @bind_array) } || undef;
    } 
    # Sinon, on récupère la liste complète des journaux
    else {
        $sql = 'SELECT * FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal';
        return eval { $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array) } || undef;
    }
}

# my $tblbilan = Base::Site::bdd::get_tblbilan($dbh, $r, $where);
sub get_tblbilan {
    my ($dbh, $r, $where) = @_;
    my @bind_array = ($r->pnotes('session')->{id_client});
    my $where_clause = '';
    
    if ($where && $where ne '') {
        $where_clause .= ' and bilan_form = ?';
        push @bind_array, $where;
    }
    
    my $sql = 'SELECT * FROM tblbilan WHERE id_client = ?';
    $sql .= $where_clause;
    $sql .= 'ORDER BY bilan_form';
    
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    
    return $content;
}

# my $tblbilan_code = Base::Site::bdd::get_tblbilan_code($dbh, $r, $args);
sub get_tblbilan_code {
    my ($dbh, $r, $args) = @_;

    my $where_clause = '';
    my @bind_array = ( $r->pnotes('session')->{id_client} );
    
    if ($args && $args->{formulaire}) {
        $where_clause .= ' and formulaire = ?';
        push @bind_array, $args->{formulaire};
    }

    if ($args && $args->{code}) {
        $where_clause .= ' and code = ?';
        push @bind_array, $args->{code};
    }
    
    my $sql = <<'SQL';
    SELECT *,
        COALESCE(
            (SELECT code
             FROM tblbilan_code AS tbl_next
             WHERE tbl_next.id_client = tblbilan_code.id_client
               AND tbl_next.formulaire = tblbilan_code.formulaire
               AND tbl_next.exercice NOT LIKE 'formule%'
               AND tbl_next.exercice <> 'divers'
               AND (
                    tbl_next.style_top > tblbilan_code.style_top
                    OR (tbl_next.style_top = tblbilan_code.style_top AND tbl_next.style_left > tblbilan_code.style_left)
                    OR (tbl_next.style_top = tblbilan_code.style_top AND tbl_next.style_left > tblbilan_code.style_left AND tbl_next.code > tblbilan_code.code)
                   )
             ORDER BY tbl_next.style_top ASC, tbl_next.style_left ASC, tbl_next.code ASC
             LIMIT 1),
        (SELECT code
         FROM tblbilan_code AS tbl_next
         WHERE tbl_next.id_client = tblbilan_code.id_client
           AND tbl_next.formulaire = tblbilan_code.formulaire
           AND tbl_next.exercice NOT LIKE 'formule%'
           AND tbl_next.exercice <> 'divers'
           AND tbl_next.code > tblbilan_code.code
         ORDER BY tbl_next.style_top ASC, tbl_next.style_left ASC, tbl_next.code ASC
         LIMIT 1),
        tblbilan_code.code
        ) AS next_code,
        COALESCE(
            (SELECT code
             FROM tblbilan_code AS tbl_prev
             WHERE tbl_prev.id_client = tblbilan_code.id_client
               AND tbl_prev.formulaire = tblbilan_code.formulaire
               AND tbl_prev.exercice NOT LIKE 'formule%'
               AND tbl_prev.exercice <> 'divers'
               AND (
                    tbl_prev.style_top < tblbilan_code.style_top
                    OR (tbl_prev.style_top = tblbilan_code.style_top AND tbl_prev.style_left < tblbilan_code.style_left)
                    OR (tbl_prev.style_top = tblbilan_code.style_top AND tbl_prev.style_left > tblbilan_code.style_left AND tbl_prev.code < tblbilan_code.code)
                   )
             ORDER BY tbl_prev.style_top DESC, tbl_prev.style_left DESC, tbl_prev.code DESC
             LIMIT 1),
        (SELECT code
         FROM tblbilan_code AS tbl_prev
         WHERE tbl_prev.id_client = tblbilan_code.id_client
           AND tbl_prev.formulaire = tblbilan_code.formulaire
           AND tbl_prev.exercice NOT LIKE 'formule%'
           AND tbl_prev.exercice <> 'divers'
           AND tbl_prev.code < tblbilan_code.code
         ORDER BY tbl_prev.style_top DESC, tbl_prev.style_left DESC, tbl_prev.code DESC
         LIMIT 1),
        tblbilan_code.code
        ) AS previous_code
    FROM tblbilan_code
    WHERE id_client = ? 
SQL

    $sql .= $where_clause;
    $sql .= 'ORDER BY style_top ASC, style_left ASC, code ASC';

    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}


# Fonction pour récupérer les catégories de documents
# my $categorie_document = Base::Site::bdd::get_categorie_document($dbh, $r);
sub get_categorie_document {
    my ($dbh, $r) = @_;
    my $sql = 'SELECT libelle_cat_doc FROM tbldocuments_categorie WHERE id_client= ? ORDER BY 1';
    my @bind_array = ($r->pnotes('session')->{id_client});
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# Requête pour récupérer les informations de la société
# Exemple d'utilisation :
# $info_societe->[0]->{etablissement}
# my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);
sub get_info_societe {
    my ($dbh, $r) = @_;
    my $sql = 'SELECT * FROM compta_client WHERE id_client = ?' ;
    my @bind_array = ($r->pnotes('session')->{id_client});
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# my $info_modele = Base::Site::bdd::get_template($dbh, $r, $where, $type); avec $type:email_body,email_objet,email_doc_search
sub get_template {
    my ($dbh, $r, $where, $type) = @_;
    
    my @bind_array = ($r->pnotes('session')->{id_client}, $type);
    my $where_clause = '';
    
    if ($where && $where ne '') {
        $where_clause .= ' AND template_name = ?';
        push @bind_array, $where;
    }
    
    my $sql = 'SELECT 
            tmpl.id_client, 
            tmpl.template_name, 
            tmpl.template_content, 
            tmpl.json_content 
        FROM tblmodel_template tmpl
        WHERE tmpl.id_client = ? 
        AND tmpl.template_type = ?';
        
    $sql .= $where_clause;
    
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    
    return $content;
}


# my $save_template = Base::Site::bdd::save_template($dbh, $r, $name, $content, $type, $json_content);
sub save_template {
    my ($dbh, $r, $name, $content, $type, $json_content) = @_;
    
    # Vérifier si json_content est défini et le convertir en JSON
    if (defined $json_content) {
        eval {
            # Tente de coder json_content en JSON
            my $json_encoder = JSON->new;
            $json_content = $json_encoder->encode($json_content);  # Encoder en JSON
        };
        if ($@) {
            return "Erreur lors de l'encodage JSON : $@";  # Gérer l'erreur d'encodage
        }
    } else {
        $json_content = undef;  # Assurez-vous que c'est undef si pas défini
    }
    
    my $sql = 'INSERT INTO tblmodel_template (id_client, template_name, template_content, template_type, json_content) 
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT (id_client, template_name, template_type) 
    DO UPDATE SET template_content = EXCLUDED.template_content, json_content = EXCLUDED.json_content';
    
    my @bind_array = ($r->pnotes('session')->{id_client}, $name, $content, $type, $json_content);
    
    eval {
        $dbh->do($sql, undef, @bind_array);
    };
    
    if ($@) {
        return $@;  # Retourner l'erreur en cas d'échec
    }
    
    return '';  # Retourner une chaîne vide en cas de succès
}

# my $delete_template = Base::Site::bdd::delete_template($dbh, $r, $modele_name, $type);
sub delete_template {
    my ($dbh, $r, $modele_name, $type) = @_;

    my $sql = 'DELETE FROM tblmodel_template 
    WHERE id_client = ? 
    AND template_name = ? 
    AND template_type = ?';
    
    my @bind_array = ($r->pnotes('session')->{id_client}, $modele_name, $type);
    
    eval {
        $dbh->do($sql, undef, @bind_array);
    };
    
    if ($@) {
        return $@;  # Retourner l'erreur en cas d'échec
    }
    
    return '';  # Retourner une chaîne vide en cas de succès
}

# Fonction pour récupérer les informations de toutes les sociétés
# détecte automatiquement si $args->{id_client} 
# my $all_societe = Base::Site::bdd::get_all_societe($dbh, $r, $args);
sub get_all_societe {
    my ($dbh, $r, $args) = @_;

    my $where_clause = '';
    my @bind_values;

    if ($args && $args->{id_client}) {
        $where_clause = ' WHERE id_client = ?';
        push @bind_values, $args->{id_client};
    }

    my $sql = 'SELECT * FROM compta_client' . $where_clause;
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_values);
    
    return $content;
}

# my $get_document_history = Base::Site::bdd::get_document_history($dbh, $r, $document_name);
sub get_document_history {
    my ($dbh, $r, $document_name) = @_;
    
    my $sql = 'SELECT * FROM tbldocuments_historique WHERE id_client = ? AND document_name = ? ORDER BY event_date ASC';
    my @bind_array = ($r->pnotes('session')->{id_client}, $document_name);
    
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    
    return $content;
}

# my $get_last_email_event_date = Base::Site::bdd::get_last_email_event_date($dbh, $r, $document_name);
sub get_last_email_event_date {
    my ($dbh, $r, $document_name) = @_;
    
    # Requête pour récupérer uniquement la date du dernier "Envoi par Email"
    my $sql_last_email_event = '
        SELECT event_description, DATE(event_date) AS event_date
        FROM tbldocuments_historique
        WHERE id_client = ? AND document_name = ? AND event_type = ?
        ORDER BY event_date DESC
        LIMIT 1';
    
    my @bind_params = ($r->pnotes('session')->{id_client}, $document_name, 'Envoi par Email');
    
    # Exécuter la requête et récupérer la date
    my $last_email_event_info = $dbh->selectrow_hashref($sql_last_email_event, undef, @bind_params);
    
    
    return $last_email_event_info;  # Renvoie la date sans l'heure ou undef si pas trouvé
}


# my $save_document_history = Base::Site::bdd::save_document_history($dbh, $id_client, $document_name, $event_type, $event_description, $user_id);
sub save_document_history {
    my ($dbh, $id_client, $document_name, $event_type, $event_description, $user_id) = @_;
    #Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 'bdd.pm => $document_name ' . $document_name .' et event_type ' . $event_type .' et event_description  ' . $event_description .' et user_id ' . $user_id .'');

    my $sql = 'INSERT INTO tbldocuments_historique (id_client, document_name, event_type, event_description, user_id, event_date) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP AT TIME ZONE \'Europe/Paris\')';
    my @bind_array = ($id_client, $document_name, $event_type, $event_description, $user_id);
    
    eval {
        $dbh->do($sql, undef, @bind_array);
    };

    if ($@) {
        return $@;  # Retourner le message d'erreur en cas d'échec
    }

    return '';  # Retourner une chaîne vide en cas de succès
}

# my $ensure_account_exists = Base::Site::bdd::ensure_account_exists($dbh, $r, $numero_compte, $libelle_compte);
sub ensure_account_exists {
    my ($dbh, $r, $numero_compte, $libelle_compte) = @_;

    # Informations de session
    my $id_client = $r->pnotes('session')->{id_client};
    my $fiscal_year = $r->pnotes('session')->{fiscal_year};

    # Vérifier si le compte existe et récupérer son libellé
    my $check_sql = '
        SELECT libelle_compte 
        FROM tblcompte 
        WHERE numero_compte = ? 
          AND id_client = ? 
          AND fiscal_year = ?
    ';
    my @check_bind = ($numero_compte, $id_client, $fiscal_year);

    my $existing_libelle;
    eval {
        $existing_libelle = $dbh->selectrow_array($check_sql, undef, @check_bind);
    };
    if ($@) {
        return "Erreur lors de la vérification du compte $numero_compte : $@";
    }

    # Si le compte existe
    if (defined $existing_libelle) {
            return '';  # Indique que le compte existe sans modification
    }

    # Si le compte n'existe pas, l'insérer
    my $insert_sql = '
        INSERT INTO tblcompte (numero_compte, libelle_compte, id_client, fiscal_year) 
        VALUES (?, ?, ?, ?)
    ';
    my @insert_bind = ($numero_compte, $libelle_compte, $id_client, $fiscal_year);

    eval {
        $dbh->do($insert_sql, undef, @insert_bind);
    };
    if ($@) {
        return "Erreur lors de l'insertion du compte $numero_compte : $@";
    }

    Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 
        "bdd.pm => ensure_account_exists => Nouveau compte inséré : $numero_compte - $libelle_compte.");
    return '';  # Indique qu'un nouveau compte a été inséré
}

# my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, $config_compte, $config_libelle, $config_journal);
sub ensure_payment_method_exists {
    my ($dbh, $r, $config_compte, $config_libelle, $config_journal) = @_;

    # Récupérer l'ID du client depuis la session
    my $id_client = $r->pnotes('session')->{id_client};

    # Vérifier si le mode de paiement existe déjà
    my $check_sql = '
        SELECT 1 
        FROM tblconfig_liste 
        WHERE id_client = ? 
          AND config_compte = ? 
          AND module = \'achats\'
    ';
    my @check_bind = ($id_client, $config_compte);

    my $exists;
    eval {
        $exists = $dbh->selectrow_array($check_sql, undef, @check_bind);
    };
    if ($@) {
        return "Erreur lors de la vérification du mode de paiement $config_compte : $@";
    }

    # Si le mode de paiement existe déjà, ne rien faire
    if ($exists) {
        return '';  # Indique que le mode de paiement existe
    }

    # Si le mode de paiement n'existe pas, l'insérer
    my $insert_sql = '
        INSERT INTO tblconfig_liste (id_client, config_libelle, config_compte, config_journal, module, masquer) 
        VALUES (?, ?, ?, ?, \'achats\', TRUE)
    ';
    my @insert_bind = ($id_client, $config_libelle, $config_compte, $config_journal);

    eval {
        $dbh->do($insert_sql, undef, @insert_bind);
    };
    if ($@) {
        return "Erreur lors de l'insertion du mode de paiement $config_compte : $@";
    }

    # Journaliser l'insertion du nouveau mode de paiement
    Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 
        "bdd.pm => Nouveau mode de paiement inséré : $config_compte - $config_libelle.");
    return '';  # Indique qu'un nouveau mode de paiement a été inséré
}


# my $delete_document_history = Base::Site::bdd::delete_document_history($dbh, $r, $id_num);
sub delete_document_history {
    my ($dbh, $r, $id_num) = @_;
    
    my $sql = 'DELETE FROM tbldocuments_historique WHERE id_num = ? AND id_client = ?';
    my @bind_array = ($id_num, $r->pnotes('session')->{id_client});
    
    $dbh->do($sql, undef, @bind_array);
}


# Fonction pour récupérer les informations email smtp
# my $smtp_get = Base::Site::bdd::get_email_smtp($dbh, $r, $args);
sub get_email_smtp {
    my ($dbh, $r, $args) = @_;

    my @bind_array = ($r->pnotes('session')->{id_client});

    my $sql = 'SELECT * FROM tblsmtp WHERE id_client = ?';
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    
    return $content;
}

# Fonction pour récupérer les informations de toutes les sociétés
# détecte automatiquement si $args->{id_client} 
# my $get_all_user = Base::Site::bdd::get_all_user($dbh, $r, $args);
sub get_all_user {
    my ($dbh, $r, $args) = @_;

    my $where_clause = '';
    my @bind_values;

    if ($args && $args->{username}) {
        $where_clause = ' WHERE username = ?';
        push @bind_values, $args->{username};
    }

    my $sql = 'SELECT * FROM compta_user' . $where_clause;
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_values);
    
    return $content;
}

# Fonction pour récupérer les informations des logements $info_societe->[0]->{etablissement}
# my $info_logement = Base::Site::bdd::get_immobilier_logements($dbh, $r, $archive);
sub get_immobilier_logements {
    my ($dbh, $r, $archive) = @_;

    my $archive_condition = "";
    if ($archive && $archive eq 1) {
        $archive_condition = "AND t1.biens_archive = true";
    } elsif ($archive && $archive eq 2) {
        $archive_condition = "AND t1.biens_archive = false";
    }

    my $sql = '
	SELECT DISTINCT biens_ref, biens_ref, t1.id_client, t1.fiscal_year, t1.biens_ref, t1.biens_nom, t1.biens_adresse, t1.biens_cp, t1.biens_ville, t1.biens_surface, t1.biens_compte, t1.biens_com1, t1.biens_com2, t1.biens_archive, t2.numero_compte, t2.libelle_compte
	FROM tblimmobilier_logement t1 
	LEFT JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.biens_compte = t2.numero_compte 
	WHERE t1.id_client = ? '.$archive_condition.'';

    my @bind_array = ($r->pnotes('session')->{id_client});
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}


# Fonction pour récupérer les informations des tags $info_societe->[0]->{etablissement}
# my $info_tags = Base::Site::bdd::get_tags_documents($dbh, $r);
sub get_tags_documents {
    my ($dbh, $r) = @_;
    #my $sql = 'SELECT DISTINCT tags_nom FROM tbldocuments_tags t1 LEFT JOIN tbldocuments t2 ON t1.id_client = t2.id_client AND t1.tags_doc = t2.id_name WHERE t1.id_client = ?' ;
    my $sql = '
    SELECT t1.tags_nom AS tags_nom
	FROM tbldocuments_tags t1
	WHERE t1.id_client = ?
	UNION
	SELECT t3.immo_contrat AS tags_nom
	FROM tblimmobilier t3
	WHERE t3.id_client = ?
	UNION
	SELECT t2.biens_ref AS tags_nom
	FROM tblimmobilier_logement t2
	WHERE t2.id_client = ?
	ORDER BY tags_nom ASC;';
    my @bind_array = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{id_client});
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# Fonction pour récupérer les informations des baux 
# my $info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, $archive, $args);
sub get_immobilier_baux {
    my ($dbh, $r, $archive, $args) = @_;

    my $archive_condition = "";
    if ($archive && $archive eq 1) {
        $archive_condition = "AND t1.immo_archive = true";
    } elsif ($archive && $archive eq 2) {
        $archive_condition = "AND t1.immo_archive = false";
    }
    
    my $where_clause = '';
    my @bind_array = ($r->pnotes('session')->{id_client});
    
    if ($args && $args->{immo_contrat}) {
        $where_clause = ' and immo_contrat = ?';
        push @bind_array, $args->{immo_contrat};
    }
    
    my $sql = 'SELECT * FROM tblimmobilier t1 
	LEFT JOIN tblimmobilier_logement t2 ON t1.id_client = t2.id_client AND t1.immo_logement = t2.biens_ref 
	LEFT JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.immo_compte = t3.numero_compte
	WHERE t1.id_client = ? '.$archive_condition.' '.$where_clause.'
	ORDER BY immo_contrat' ;
    
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);
    return $content;
}

# my $info_compte = Base::Site::bdd::get_immobilier_compte($dbh, $r, $immo_contrat); $info_compte->{immo_compte}
sub get_immobilier_compte {
    my ($dbh, $r, $immo_contrat) = @_;

    my @bind_array = ($r->pnotes('session')->{id_client}, $immo_contrat);

    my $sql = 'SELECT * FROM tblimmobilier 
               WHERE id_client = ? and immo_contrat = ?';

    # Récupérer un seul résultat
    my $content = $dbh->selectrow_hashref($sql, undef, @bind_array);

    return $content;
}

# Fonction pour sélectionner les années fiscales distinctes
# Exemple d'utilisation :
# my $parametres_fiscal_year = Base::Site::bdd::get_parametres_fiscal_year($dbh, $r->pnotes('session')->{id_client});
sub get_parametres_fiscal_year {
    my ($dbh, $id_client) = @_;
	# Requête SQL modifiée pour inclure l'année actuelle si elle n'est pas déjà présente
    my $sql = 'SELECT DISTINCT fiscal_year FROM tbljournal WHERE id_client = ? UNION SELECT ? AS fiscal_year ORDER BY fiscal_year';
    
    # Exécuter la requête avec l'année actuelle et récupérer les résultats sous forme de tableau de hachages
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, $id_client, (localtime())[5] + 1900);
    
    return $content;
}

# Fonction pour sélectionner les paramètres de règlements
# Exemple d'utilisation :
# my $parametres_reglements = Base::Site::bdd::get_parametres_reglements($dbh, $r);
# my ($reglement_journal, $reglement_compte, $libelle_compte) = Base::Site::bdd::get_parametres_reglements($dbh, $r, $libelle_search, $compte_search, $all);
sub get_parametres_reglements {
    my ($dbh, $r, $libelle_recherche, $compte_search, $all) = @_;

    # Construire dynamiquement la clause WHERE
    my $masquer_condition = $all ? '' : 'AND t1.masquer = \'f\'';
    
    # Construire la requête SQL
    my $sql = qq{
        SELECT DISTINCT 
            t1.config_libelle, 
            t1.config_compte, 
            t1.config_journal, 
            t1.module, 
            t1.masquer, 
            t2.libelle_compte 
        FROM tblconfig_liste t1
        LEFT JOIN tblcompte t2 
            ON t1.id_client = t2.id_client 
            AND t1.config_compte = t2.numero_compte
            AND t2.fiscal_year = ?
        WHERE 
            t1.id_client = ? 
            AND t1.module = 'achats'
            $masquer_condition
        ORDER BY t1.config_libelle
    };

    # Exécuter la requête SQL
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, 
        $r->pnotes('session')->{fiscal_year}, 
        $r->pnotes('session')->{id_client}
    );

    # Si un libellé spécifique est recherché, renvoyer les données correspondantes
    if (defined $libelle_recherche) {
        for my $row (@$content) {
            if ($row->{config_libelle} eq $libelle_recherche) {
                return ($row->{config_journal}, $row->{config_compte}, $row->{libelle_compte});
            }
        }
    }
    
    # Si un compte spécifique est recherché, renvoyer les données correspondantes
    elsif (defined $compte_search) {
        for my $row (@$content) {
            if ($row->{config_compte} eq $compte_search) {
                return ($row->{config_journal}, $row->{config_compte}, $row->{libelle_compte}, $row->{config_libelle});
            }
        }
    }

    # Retourner toutes les données si aucun critère de recherche n'est défini
    return $content;
}


# Fonction pour récupérer les comptes en fonction des numéros de compte spécifiés
# Exemple d'utilisation :
# my $compte_set = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $compte);
# avec $compte all ou vide pour tout les comptes ou bien sous la forme '706,5' séparé par | ; ou ,
sub get_comptes_by_classe {
    my ($dbh, $r, $comptes) = @_;
    # Si l'argument $comptes est défini comme 'all', récupérer tous les comptes
    if (!$comptes || $comptes eq 'all') {
        my $sql = "SELECT * FROM tblcompte WHERE id_client = ? AND fiscal_year = ? ORDER BY numero_compte, libelle_compte";
        my @params = ($r->pnotes('session')->{id_client},  $r->pnotes('session')->{fiscal_year});
        my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
        return $content;
    }
    # Découper la liste de numéros de compte en une liste d'éléments individuels
    my @compte_numbers = split /[,|;]/, $comptes;
    # Construire une liste de placeholders pour les numéros de compte dans la requête SQL
    my $placeholders = join ',', ('?') x @compte_numbers;
    # Construire la requête SQL avec les placeholders
    my $sql = "SELECT * FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND (";
    $sql .= join(' OR ', map { "substring(numero_compte from 1 for " . length($_) . ") = ?" } @compte_numbers);
    $sql .= ") ORDER by numero_compte, libelle_compte";
    my @params = ($r->pnotes('session')->{id_client},  $r->pnotes('session')->{fiscal_year}, @compte_numbers);
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    return $content;
}

# my $get_compte_info = Base::Site::bdd::get_compte_info($dbh, $r, $comptes);
sub get_compte_info {
    my ($dbh, $r, $comptes) = @_;
    my $sql = "SELECT * FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND numero_compte = ? ORDER BY numero_compte, libelle_compte";
    my @params = ($r->pnotes('session')->{id_client},  $r->pnotes('session')->{fiscal_year}, $comptes);
    my $content = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    return $content;
}

# Sélectionne dans tbljournal_staging un _token_id
#my $result_gen = Base::Site::bdd::get_token_ids($r, $dbh, '%recurrent%');
sub get_token_ids {
    my ($r, $dbh, $token_like) = @_;
    my $sql = 'SELECT DISTINCT _token_id FROM tbljournal_staging WHERE _token_id LIKE ? AND id_client = ? AND fiscal_year = ? ORDER BY _token_id';
    
    my $result_gen = eval {
        $dbh->selectall_arrayref($sql, { Slice => {} }, $token_like, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    };

    if ($@) {
        Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 'bdd.pm => get_token_ids => Erreur lors de la requête SQL : ' . $@ .'. ');
        return undef;
    }

    return $result_gen;
}

######################################################################   
# tbljournal_staging et record_staging								 #
######################################################################  

#Nettoie la table tbljournal_staging
#Base::Site::bdd::clean_tbljournal_staging( $r );
sub clean_tbljournal_staging {
    my ($r) = @_;

    my $dbh = $r->pnotes('dbh') ;
    my $fiscal_year = $r->pnotes('session')->{fiscal_year};
    my $session_id = $r->pnotes('session')->{_session_id};
    
    # Requête SQL pour supprimer les données
	my $sql = 'DELETE FROM tbljournal_staging WHERE _session_id = ? AND fiscal_year = ? AND _token_id NOT LIKE \'%recurrent%\' AND _token_id NOT LIKE \'%csv%\'';
    
    # Exécute la requête SQL avec le session_id en paramètre
    $dbh->do($sql, undef, $session_id, $fiscal_year);
}

#Supprime des éléments dans la table tbljournal_staging
#Base::Site::bdd::delete_tbljournal_staging($r, $dbh, '%recurrent%');
sub delete_tbljournal_staging {
    my ($r, $dbh, $token_like) = @_;
    #on supprime toutes les données concernant le LIKE dans tbljournal_staging pour cet utilisateur
	my $sql = 'DELETE FROM tbljournal_staging WHERE id_client = ? AND _token_id LIKE ?';
    # Exécute la requête SQL avec le session_id en paramètre
    my @bind_array = ($r->pnotes('session')->{id_client}, $token_like);
	$dbh->do( $sql, undef, @bind_array ) ;
}

#my ($return_entry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $_token_id);
sub call_record_staging {
    my ($dbh, $token_id, $id_entry) = @_;
    # Définir la valeur par défaut de $id_entry à 0 si elle n'est pas définie
    $id_entry //= 0;
    my $sql = 'SELECT record_staging(?, ?)';
    my $error_message;  # Variable pour stocker le message d'erreur
    my $return_identry;    # Variable pour stocker la valeur de retour
    my $content_ref = '';  # Initialiser $content_ref comme une chaîne vide

    # Utilisation de eval pour gérer les erreurs potentielles lors de l'exécution de la requête SQL
    eval {
        $return_identry = $dbh->selectall_arrayref($sql, undef, ($token_id, $id_entry))->[0]->[0];
    };

    if ($@) {
        $error_message = $@;  # Stocker le message d'erreur
    }

    if ($error_message) {
        # Gérer l'erreur en générant le contenu d'erreur dans $content_ref
        if ($error_message =~ / NOT NULL (.*) date_ecriture / ) {
            $content_ref .= 'Il faut une date valide - Enregistrement impossible';
        } elsif ($error_message =~ /tbljournal_id_client_fiscal_year_numero_compte_fkey/i ) {
			if ($error_message =~ /(.{7})\) is not present/) {
				my $missing_numero_compte = $1;
				$content_ref .= 'Un numéro de compte est invalide - Enregistrement impossible.<br> Numéro de compte manquant : '.$missing_numero_compte.'';
			} else {
				$content_ref .= 'Un numéro de compte est invalide - Enregistrement impossible';
			}
        } elsif ($error_message =~ /unbalanced/i ) {
            $content_ref .= 'Montants déséquilibrés - Enregistrement impossible';
        } elsif ($error_message =~ /tbljournal_liste/i ) {
            $content_ref .= 'Le journal est inexistant - Enregistrement impossible';
        } elsif ( $error_message =~ /Aucune/i ) {
			$content_ref .= 'Aucune écriture trouvée dans tbljournal_staging - Enregistrement impossible' ;
		} elsif ($error_message =~ /bad fiscal/i) {
            $content_ref .= 'La date d\'écriture n\'est pas dans l\'exercice en cours - Enregistrement impossible';
        } elsif ($error_message =~ /archived/i ) {
            $content_ref .= 'La date d\'écriture se trouve dans un mois archivé - Enregistrement impossible';
        } elsif ($error_message =~ /null value (.*) "numero_compte"/ )  {
            $content_ref .= 'Il faut un numéro de compte pour chaque ligne';
        } elsif ( $error_message =~ /tbljournal_documents2_id_client_fkey/ ) {
			if ( $error_message =~ /Key \(documents2, id_client\)=\(([^,]+), (\d+)\) is not present in table "tbldocuments"/ ) {
				my ($doc_name, $client_id) = ($1, $2);
				$content_ref .= 'Le document « '.$doc_name.' » est introuvable.<br> Veuillez vérifier et corriger la valeur du document 2.';
			} else {
				$content_ref .= 'Erreur de contrainte sur la table "tbldocuments" - Enregistrement impossible.<br>' . $error_message . '';
			}
		} elsif ( $error_message =~ /tbljournal_documents1_id_client_fkey/ ) {
			if ( $error_message =~ /Key \(documents1, id_client\)=\(([^,]+), (\d+)\) is not present in table "tbldocuments"/ ) {
				my ($doc_name, $client_id) = ($1, $2);
				$content_ref .= '<h3 class="warning">Le document « '.$doc_name.' » est introuvable.<br> Veuillez vérifier et corriger la valeur du document 1.';
			} else {
				$content_ref .= '<h3 class="warning">Erreur de contrainte sur la table "tbldocuments" - Enregistrement impossible.<br>' . $error_message . '';
			}
		} else {
            $content_ref .= '' . $error_message . '';
        }
    }

    # Renvoyer à la fois l'ID d'entrée et le contenu d'erreur sous forme de liste
    return ($return_identry, $content_ref);
}

#my $error_message_1 = Base::Site::bdd::call_insert_staging($dbh, \@bind_array1);
#$content .= "Erreur lors de l'insert_staging 1 : $error_message_1<br>" if $error_message_1;
#my $error_message_2 = Base::Site::bdd::call_insert_staging($dbh, \@bind_array2);
#$content .= "Erreur lors de l'insert_staging 2 : $error_message_2<br>" if $error_message_2;
sub call_insert_staging {
    my ($dbh, $bind_array_ref) = @_;
    my $sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, date_ecriture, libelle, numero_compte, lettrage, pointage, debit, credit, id_client, id_facture, id_paiement, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?, ?)';
  
    # Utilisation de eval pour gérer les erreurs potentielles lors de l'exécution de la requête SQL
    eval {
        $dbh->do($sql, undef, @$bind_array_ref);
    };

    if ($@) {
        return $@;  # Retourner le message d'erreur en cas d'échec
    }

    return '';  # Retourner une chaîne vide en cas de succès
}

# Fonction pour l'insertion dans la base de données avec record_staging dans tbljournal_staging
#my @bind_array1 = ( 
#$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte, undef, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, $args->{calcul_piece}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal, $token_id, ($args->{docs1} || undef), ($args->{docs2} || undef), 
#$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_fournisseur}, undef, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, $args->{calcul_piece}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal, $token_id, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
#my $insertion_1 = Base::Site::bdd::call_insert_record_staging($dbh, \@bind_array1, $token_id);
sub call_insert_record_staging {
    my ($dbh, $bind_array_ref, $token_id) = @_;
    
    my $error_message;  # Variable pour stocker le message d'erreur

	my $error_message_1 = call_insert_staging($dbh, $bind_array_ref);
	
	$error_message .= "Erreur lors de l'insert_staging : $error_message_1 <br>" if $error_message_1;

	my ($return_entry, $call_record_staging) = Base::Site::bdd::call_record_staging($dbh, $token_id);

	$error_message .= "Erreur lors de record_staging : $call_record_staging <br>" if $call_record_staging;
    
    if ($error_message) {
        return $error_message;  # Retourner le message d'erreur en cas d'échec
    }

    return '';  # Retourner une chaîne vide en cas de succès

}

# Fonction pour récupérer l'IS à payer depuis le compte 695000 Base::Site::bdd::get_is_from_account
sub get_is_from_account {
    my ($dbh, $r, $date, $account, $format) = @_;
    
    my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($date);
    
    $format //= 'FM999999999990';
    
    my $query = qq{
        SELECT solde_debit
        FROM calcul_balance(?, ?, ?, ?, ?, ?)
        WHERE (solde_debit NOT SIMILAR TO '0,00' 
               OR solde_credit NOT SIMILAR TO '0,00' 
               OR debit NOT SIMILAR TO '0,00' 
               OR credit NOT SIMILAR TO '0,00')
          AND numero_compte = ?
    };
    
    my $sth = $dbh->prepare($query);
    my @bind_array = ( $r->pnotes('session')->{id_client}, $year1, "$year1-$month1-$day1", $r->pnotes('session')->{id_client}, $year1, $format, $account ) ;

    $sth->execute(@bind_array);
    
    my $row = $sth->fetchrow_hashref;
    # Retourne le solde_debit comme l'IS à payer
    return $row->{solde_debit} // 0;
}

sub calculate_is_from_balance {
    my ($dbh, $r, $year) = @_;

    # Requête pour récupérer tous les soldes des comptes concernés sans filtrer sur numero_compte
    my $query = '
        SELECT numero_compte, solde_debit, solde_credit, classe_total_credit_solde, classe_total_debit_solde
        FROM calcul_balance(?, ?, ?, ?, ?, ?)
        WHERE (solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\')
    ';

    my $sth = $dbh->prepare($query);

    # Initialiser les sommes
    my $total_7 = 0;
    my $total_6 = 0;
    my $total_671200 = 0;
    my $total_635140 = 0;
    my $total_649000 = 0;
    my $total_119000 = 0;

    # Exécuter la requête
    $sth->execute(
        $r->pnotes('session')->{id_client}, 
        $year, "$year-12-31", 
        $r->pnotes('session')->{id_client}, 
        $year, 'FM999999999990D00'
    );

    # Itérer sur chaque ligne de résultat
    while (my $row = $sth->fetchrow_hashref) {
        # Nettoyer les données et les formater pour les calculs
        my $solde_credit = $row->{solde_credit} // 0;
        $solde_credit =~ s/,/./g; # Remplace les virgules par des points (si applicable)
        $solde_credit =~ s/[^0-9.-]//g; # Supprime tout caractère non numérique
        $row->{classe_total_debit_solde} =~ s/,/./g;
		$row->{classe_total_debit_solde} =~ s/[^0-9.-]//g;
		$row->{classe_total_credit_solde} =~ s/,/./g;
		$row->{classe_total_credit_solde} =~ s/[^0-9.-]//g;
        my $solde_debit = $row->{solde_debit} // 0;
        $solde_debit =~ s/,/./g;
        $solde_debit =~ s/[^0-9.-]//g;

        my $balance = 0;

        # Traitement pour les comptes spécifiques (695000, 671200, 635140)
        if ($row->{numero_compte} eq '695000' || $row->{numero_compte} eq '671200' || $row->{numero_compte} eq '635140') {
            # Utiliser solde_debit pour les comptes spécifiques
            $balance = $solde_debit;
            if ($row->{numero_compte} eq '671200') {
                $total_671200 = $balance;
            } elsif ($row->{numero_compte} eq '635140') {
                $total_635140 = $balance;
            } elsif ($row->{numero_compte} eq '119000') {
                $total_119000 = $balance;
            } elsif ($row->{numero_compte} eq '649000') {
                $total_649000 = $balance;
            }
        }
        # Traitement pour les comptes de classe 6 (charges)
        elsif ($row->{numero_compte} =~ /^6/) {
            $total_6 = $row->{classe_total_debit_solde} // 0;
        }
        # Traitement pour les comptes de classe 7 (revenus)
        elsif ($row->{numero_compte} =~ /^7/) {
            $total_7 = $row->{classe_total_credit_solde} // 0;
        }
    }

    # Calcul du bénéfice imposable
    my $benefice_imposable = $total_7 - $total_6 - $total_119000 - $total_671200 - $total_635140 - $total_649000;

    # Calcul de l'IS à payer
    my $montant_impot = 0;
    if ($benefice_imposable <= 42500) {
        $montant_impot = $benefice_imposable * 0.15; # 15% si bénéfice <= 42 500 €
    } else {
        # 15% sur les premiers 42 500 €
        $montant_impot = 42500 * 0.15;
        # 25% sur le reste
        $montant_impot += ($benefice_imposable - 42500) * 0.25;
    }
	
	# Arrondir l'impôt à payer à l'euro le plus proche (arrondi classique : inférieur à 0.5 ou supérieur à 0.5)
    $montant_impot = int($montant_impot + 0.5);

    # Retourne l'IS à payer (ou 0 si négatif)
    return $montant_impot > 0 ? $montant_impot : 0;
}




1;
