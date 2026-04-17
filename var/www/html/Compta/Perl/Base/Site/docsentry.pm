package Base::Site::docsentry ;
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
##########################################################################################

use strict;  # Utilisation stricte des variables
use warnings;  # Activation des avertissements
use Base::Site::util;  # Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   # Interaction avec la base de données (SQL)
use utf8;              # Encodage UTF-8 pour le script
use Base::Site::menu;  # Module Menu
use Base::Site::docs;  # Module Documents
use Apache2::Const -compile => qw( OK REDIRECT );  # Importation de constantes Apache
use URI::Escape;       # Encodage et décodage d'URLs
use HTML::Entities;
use MIME::Base64;
use File::Path qw(mkpath);
use File::Copy;
use PDF::API2;         	# Manipulation de fichiers PDF

sub handler {

    my $r = shift;
    
    binmode(STDOUT, ":utf8");
    
    # Utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    
    my $req = Apache2::Request->new( $r ) ;

    # Récupération des paramètres de la requête
    my %args;

    for my $param ($req->param) {
        my $value = Encode::decode_utf8($req->param($param));
        # Remplacez les double-quotes et les <> par des guillemets simples
        $value =~ tr/<>"/'/;
        $args{$param} = $value;
    }

    my $content = visualize($r, \%args);
    
    $r->no_cache(1) ;
    $r->content_type('text/html; charset=utf-8') ;
    $r->print($content);
    return Apache2::Const::OK ;
}

sub visualize {

    my ($r, $args) = @_ ;
    #récupérer les arguments
    my (%args, @args) ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $memo = '';
	my $reqid = Base::Site::util::generate_reqline();
	# Assurez-vous que $args->{id_name} est correctement encodé
	my $encoded_id_name = uri_escape_utf8($args->{id_name} || '');

   	################ Affichage MENU ################
    $content .= Base::Site::docs::display_menu_docs( $r, $args ) ;
	################ Affichage MENU ################
	
	#Fonction pour générer le débogage des variables $args et $r->args si dump == 1  
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
	
	#Requête tbldocuments => Recherche des informations des documents
    $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, check_banque, multi, last_fiscal_year, id_compte FROM tbldocuments WHERE id_name = ? AND id_client = ?' ;
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{id_name}, $r->pnotes('session')->{id_client} ) ;
    
    my $id_name_docs;
	
	# Recherche next_document et previous_document
	if (defined $args->{id_name}) {
		$sql = '
		WITH CurrentDocument AS (
		SELECT id_name, libelle_cat_doc AS category, fiscal_year, id_client 
		FROM tbldocuments
		WHERE id_client = ? AND id_name = ? LIMIT 1
		),
		DocumentList AS (
			SELECT id_name, 
				   LEAD(id_name) OVER (ORDER BY date_reception, id_name) AS next_document,
				   LAG(id_name) OVER (ORDER BY date_reception, id_name) AS previous_document,
				   date_reception
			FROM tbldocuments
			WHERE id_client = (SELECT id_client FROM CurrentDocument)
				  AND libelle_cat_doc = (SELECT category FROM CurrentDocument)
				  AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?)))
		)
		SELECT id_name AS current_document_id,
			   previous_document,
			   next_document,
			   date_reception
		FROM DocumentList
		WHERE id_name = (SELECT id_name FROM CurrentDocument)
		ORDER BY date_reception, id_name;';

		my @bind_array = ($r->pnotes('session')->{id_client}, $args->{id_name}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year});

		# Exécution de la requête SQL
		eval { $id_name_docs = $dbh->selectrow_hashref($sql, { Slice => {} }, @bind_array) };
	}
	
    #Empêcher id_name vide ou existe pas
	if (!$args->{id_name} || !$array_of_documents->[0]->{id_name}){
		$content .= Base::Site::util::ref_existe_pas($r);
		return $content ;
	}
	
	# Récupération info depuis lien tblimmobilier pour la saisie_rapide
	if (defined $args->{label4} && $args->{label4} eq 1) {
		$sql = '
			SELECT DISTINCT ON(t1.tags_nom) t1.tags_nom, t2.immo_compte, t2.immo_depot 
			FROM tbldocuments_tags t1
			INNER JOIN tblimmobilier t2 ON t1.id_client = t2.id_client AND t1.tags_nom = t2.immo_contrat
			WHERE t1.tags_doc = ?';
		my $result_immo_vail = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{id_name});
		if ($result_immo_vail->[0]->{tags_nom}) {
			if (defined $args->{scenario} && ($args->{scenario} eq 'depot_garantie' || $args->{scenario} eq 'remboursement_depot_garantie')) {
			$args->{montant} = sprintf("%.2f", $result_immo_vail->[0]->{immo_depot}/100);
			}
			$args->{compte_client} = $result_immo_vail->[0]->{immo_compte};
			$args->{compte_client2} = $result_immo_vail->[0]->{immo_compte};
			$args->{compte_autres} = $result_immo_vail->[0]->{immo_compte};
		}
	}
	
	if (defined $array_of_documents->[0]->{id_compte} && $array_of_documents->[0]->{id_compte} ne '') {
		my $compte_pay = Base::Site::bdd::get_is_from_account($dbh, $r,($array_of_documents->[0]->{date_reception} || ''), ($array_of_documents->[0]->{id_compte} || ''), 'FM999999999990D00');
		$memo = "<div class='memoinfo2'>Solde du compte ".$array_of_documents->[0]->{id_compte}." au ".$array_of_documents->[0]->{date_reception}." : <strong>".($compte_pay || '0,00')."</strong></div><br>";
	}
    
	my $libelle_cat_doc ||= 0 ;
	my $categorie_list = '' ;

	#/************ ACTION DEBUT *************/
	
	#######################################################################  
	#première demande de renommer le document via référence pièce	      #
	####################################################################### 
	if ( defined $args->{id_name} && defined $args->{renommer} and $args->{renommer} eq '0' ) {
		my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;fiscal_year='.$args->{fiscal_year}.'&amp;renommer=1' ;
		my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous renommer le document ' . $args->{id_name} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
    } elsif ( defined $args->{id_name} && defined $args->{renommer} and $args->{renommer} eq '1' && $args->{id_name} ne '' ) {
	
		#requête nombre id_facture
		my $docs_count = '';
		$sql = '
		with t1 as ( SELECT id_facture FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND (documents1 = ?) GROUP BY id_facture)
		SELECT count(id_facture) as count FROM t1' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_documents->[0]->{id_name} ) ;
		eval { $docs_count = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
		
		# si aucune référence	
		if ($docs_count->[0]->{count} eq '0') {
			$content .= '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">Impossible car il n\'existe aucune écriture ayant pour référence ce document.</h3>' ;
		#si il y a qu'une référence renommage possible
		} elsif ($docs_count->[0]->{count} eq '1') {
				
				my $id_facture;
				$sql = '
				with t1 as ( SELECT id_facture FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND (documents1 = ?) GROUP BY id_facture)
				SELECT id_facture FROM t1
				' ;
				@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_documents->[0]->{id_name} ) ;
				eval { $id_facture = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
				
				if ($args->{id_name} =~ /$id_facture/ ) {
					$content .= '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">Le nom du document '.$args->{id_name}.' contient déjà le numéro de pièce '.$id_facture.' </h3>' ;	
				} else {
					my $new_name = $args->{id_name};
					# Vérification et remplacement du numéro de pièce dans le nom du document
				  if ($new_name =~ /^(.*?)(\d{4})-(\d{2})_(\d{2})_(.*?)\.pdf$/) {
						# Extraire les parties du nom du document
						my ($prefix, $annee, $mois, $numero, $nom) = ($1, $2, $3, $4, $5);
						# Construire le nouveau nom du document avec le nouveau numéro de pièce
						$new_name = $id_facture . '_' . $nom . '.pdf';
					} else {
						# Si le format n'est pas conforme, ajouter simplement le numéro de pièce
						$new_name = $id_facture . '_' . $new_name;
					}
					#Requête numéro piéce
					$sql = 'UPDATE tbldocuments set id_name = ? WHERE id_client = ? AND id_name = ? ' ;
					@bind_array = ( $new_name, $r->pnotes('session')->{id_client}, $args->{id_name} ) ;
					eval { $dbh->do( $sql, undef, ( @bind_array) ) } ;
			
					if ( $@ ) {
						$content .= '<h3 class=warning>' . $@ . '</h3>' ;
					} else {
						#la modification de la référence du document dans tbldocuments a réussi, renommer le fichier
						my $base_dir = $r->document_root() . '/Compta/base/documents' ;
						my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$args->{fiscal_year}. '/' ;
						my $archive_file = $archive_dir . $args->{id_name} ;
						my $newarchive_file = $archive_dir . $new_name ;
						#renommer le fichier
						rename $archive_file, $newarchive_file;
						# $new_name est correctement encodé
						my $encoded_new_name = uri_escape_utf8($new_name || '');
			
						#Redirection
						$args->{restart} = 'docsentry?id_name='. $encoded_new_name .'';
						Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
						return Apache2::Const::OK;  # Indique que le traitement est terminé
					}
				}
		# si plusieurs références		
		} else {
			$content .= '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">Impossible car '.$docs_count->[0]->{count} .' références existent pour ce document.</h3>' ;	
		}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' un tag				  #
	#######################################################################
    if ( defined $args->{id_name} && defined $args->{add_tag} && $args->{add_tag} eq '1' ) {
		
		my $lib = $args->{tags_nom} || undef ;
		Base::Site::util::formatter_libelle(\$lib);

		if (defined $args->{tags_nom} && $lib eq '') {
			$content .= Base::Site::util::generate_error_message('Impossible le nom du tag est vide !');
		} elsif ((defined $args->{id_name} && $args->{id_name} eq '') || !defined $args->{id_name}) {
			$content .= Base::Site::util::generate_error_message('Impossible il faut sélectionner un document !');
		} else {
			#ajouter une catégorie
			$sql = 'INSERT INTO tbldocuments_tags (tags_nom, tags_doc, id_client) values (?, ?, ?)' ;
			@bind_array = ( $args->{tags_nom}, $args->{id_name}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut renseigner le nom du nouveau tag de document') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Le tag "'.$args->{tags_nom}.'" existe déjà pour ce document') ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docentry.pm => Ajout du tag "'.$args->{tags_nom}.'" pour le document '.$args->{id_name}.'');
			}
		}
    }
  
	#######################################################################  
	#première demande de suppression d'un document; réclamer confirmation #
	####################################################################### 
    if ( defined $args->{id_name} && defined $args->{supprimer} and $args->{supprimer} eq '0' ) {
		my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;supprimer=1' ;
		my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous  supprimer le document ' . $args->{id_name} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
    } elsif ( defined $args->{id_name} && defined $args->{supprimer} and $args->{supprimer} eq '1' ) {
		
		$content .= Base::Site::util::verify_and_delete_document($dbh, $r, $args, 1);
	}
      
    #######################################################################  
	#première demande de suppression d'un document; réclamer confirmation #
	####################################################################### 
    if ( defined $args->{id_name} && defined $args->{supprimer_tag} and $args->{supprimer_tag} eq '0' ) {
		my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;supprimer_tag=1&amp;tags_nom=' . ($args->{tags_nom} || '').'' ;
		my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous  supprimer le tag ' . ($args->{tags_nom} || '').' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
    } elsif ( defined $args->{id_name} && defined $args->{supprimer_tag} and $args->{supprimer_tag} eq '1' ) {
		
		if ( defined $args->{id_name} && $args->{id_name} ne '') {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tbldocuments_tags WHERE tags_nom = ? AND id_client = ? and tags_doc = ?' ;
			@bind_array = ( $args->{tags_nom}, $r->pnotes('session')->{id_client}, $args->{id_name} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
				} elsif ( $@ =~ /toujours|referenced/ ) {
				$content .= '<h3 class=warning>Suppression impossible : le tag '.$args->{tags_nom}.' est encore utilisé dans un document </h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docentry.pm => Supression du tag "'.$args->{tags_nom}.'" pour le document '.$args->{id_name}.'');
			}
		}
	}
         
	################################################################################### 
	# l'utilisateur a cliqué sur le bouton 'Valider', enregistrer les modifications	  #
	###################################################################################
    if ( defined $args->{id_name} && defined $args->{modifier} and $args->{modifier} eq '1' ) {
			
		Base::Site::util::formatter_montant_et_libelle(\$args->{montant}, undef);
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [18, $args->{montant}]);
		
		if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
		} else {

			if (defined $args->{new_last_fiscal_year} && $args->{new_last_fiscal_year} eq '') {$args->{new_last_fiscal_year} = undef ;}
			if (defined $args->{compte_comptant} && $args->{compte_comptant} eq '') {$args->{compte_comptant} = undef ;}
			if (defined $args->{check_banque} && $args->{check_banque} eq '1') {
			$args->{check_banque} = 't';
			} else {$args->{check_banque} = 'f';}
			
			#si checkbox multi est on $args->{multi} eq '1' donc true || si off disabled de fiscal_year
			if ((defined $args->{multi} && $args->{multi} eq '1') || ((defined $args->{old_multi} && $args->{old_multi} eq 't') && ($args->{fiscal_year} ne $r->pnotes('session')->{fiscal_year} ))) {
			$args->{multi} = 't';
			} else {$args->{multi} = 'f';} 
			

			$sql = 'UPDATE tbldocuments set id_name = ?, date_reception = ?, montant = ?, libelle_cat_doc = ?, last_fiscal_year = ? , check_banque = ?, multi = ?, id_compte = ? WHERE id_client = ? AND id_name = ? ' ;
			@bind_array = ( $args->{new_id_name}, $args->{date_reception}, $args->{montant}*100, $args->{libelle}, $args->{new_last_fiscal_year}, $args->{check_banque}, $args->{multi}, $args->{compte_comptant}, $r->pnotes('session')->{id_client}, $args->{old_id_name} ) ;
			eval { $dbh->do( $sql, undef, ( @bind_array) ) } ;
			
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docsentry.pm => Mise à jour du document : '.$args->{old_id_name}.' en : '.$args->{new_id_name}.'');
		
			if ( $@ ) {
			if ( $@ =~ / NOT NULL (.*) date_reception / ) {
			 $content .= '<h3 class=warning>Il faut une date valide - Enregistrement impossible</h3>' ;
			} elsif ( $@ =~ /duplicate/ ) {
				$content .= '<h3 class=warning>Enregistrement impossible car un fichier existe déjà avec le même nom</h3>' ;
			} else {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}
			} else {
			
			#la modification de la référence du document dans tbldocuments a réussi, renommer le fichier
			my $base_dir = $r->document_root() . '/Compta/base/documents' ;
			my $archive_dir = '' ;
			
				if (defined $args->{multi} && $args->{multi} eq 't' ) {
				$archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$args->{fiscal_year}. '/' ;
				} else {
				$archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$r->pnotes('session')->{fiscal_year}. '/' ;
				}
			
			my $archive_file = $archive_dir . $args->{old_id_name} ;
			my $newarchive_file = $archive_dir . $args->{new_id_name} ;
			#renommer le fichier
			rename $archive_file, $newarchive_file;
			my $encoded_new_id_name = uri_escape_utf8($args->{new_id_name} || '');
			
			#Redirection
			$args->{restart} = 'docsentry?id_name='. $encoded_new_id_name .'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
	    

	}  
	
	#####################################################################################  
	#première demande de suppression d'un historique de document; réclamer confirmation #
	##################################################################################### 
    if ( defined $args->{delete_event} && !defined $args->{supprimer} ) {
		my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;delete_event='.$args->{delete_event}.'&amp;supprimer=2' ;
		my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;historique' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer cet événement ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
    } elsif ( defined $args->{delete_event} && defined $args->{supprimer} and $args->{supprimer} eq '2' ) {
		
		$content .= Base::Site::bdd::delete_document_history($dbh, $r, $args->{delete_event});

	}

	#/************ ACTION FIN *************/
	
	############## MISE EN FORME DEBUT ##############
	my ($new_entree_docs1_href, $new_entree_docs2_href, $new_href );
	
	#désactivation modifications des documents multi-exercice
   	my $disabled_link = ( $array_of_documents->[0]->{fiscal_year} eq $r->pnotes('session')->{fiscal_year} ) ? '' : 'disabled' ;
  	my $readonly_link = ( $array_of_documents->[0]->{fiscal_year} eq $r->pnotes('session')->{fiscal_year} ) ? '' : 'readonly' ;
   	my $disabled_link2 = ( ($array_of_documents->[0]->{fiscal_year} eq $r->pnotes('session')->{fiscal_year}) || $array_of_documents->[0]->{multi} eq 'f') ? '' : 'disabled' ;
    $args->{do_not_edit} = $disabled_link;
    
	my $message_exercice_cloture = '';
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
		$new_entree_docs1_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=BANQUE&amp;mois=0&amp;id_entry=0&amp;nouveau&amp;docs1='.$array_of_documents->[0]->{id_name}.'' ;
		$new_entree_docs2_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=BANQUE&amp;mois=0&amp;id_entry=0&amp;nouveau&amp;docs2='.$array_of_documents->[0]->{id_name}.'' ;
		$new_href = '/'.$r->pnotes('session')->{racine}.'/docs?new_document=0' ;
	} else {
		$new_entree_docs1_href = '#' ;
		$new_entree_docs2_href = '#' ;
		$new_href = '#' ;
		$disabled_link = 'disabled';
		$readonly_link = 'readonly';
		$message_exercice_cloture = '<br><div class="flex-table submit"><span class=displayspan style="width: 100%; text-align: center; color: red; font-weight : bold;">Modification du nom et de la date impossible car il existe des enregistrements liés exportés</span><br></div><br>';
	}
	
	my $retour_href = 'javascript:history.go(-1)';
	
	my $compte1 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '51,46');
	my ($selected1, $form_name1, $form_id1)  = (($args->{compte_comptant} || $array_of_documents->[0]->{id_compte}), 'compte_comptant', 'compte_comptant');
	my $onchange1 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"';
	my $compte_comptant = Base::Site::util::generate_compte_selector($compte1, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style="width: 14%;"');
	
    #liste des Catégories de documents
    $sql = 'SELECT libelle_cat_doc FROM tbldocuments_categorie WHERE id_client= ? ORDER BY libelle_cat_doc' ;
    @bind_array = ( $r->pnotes('session')->{id_client} ) ;
    my $categorie_set = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
    my $categorie_select = '<select class="forms2_input" style="width: 12%;" name=libelle id=libelle 
    onchange="if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'}">' ;
	$categorie_select .= '<option class="opt1" value="">Créer une catégorie</option>' ;
    for ( @$categorie_set  ) {
	my $selected = ( $_->[0] eq $array_of_documents->[0]->{libelle_cat_doc} ) ? 'selected' : '' ;
	$categorie_select .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
    }
    $categorie_select .= '</select>' ;
    
    #
    #construire la table des paramètres
    #
    #joli formatage de débit/crédit
    (my $montant = sprintf( "%.2f", $array_of_documents->[0]->{montant} ) ) =~ s/\B(?=(...)*$)/ /g ;

	#####################################       
	#Sélection des entrées du journal
	#####################################    

	$sql = '
	with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND (documents1 = ? OR documents2 = ?) GROUP BY id_entry)
	SELECT count(id_entry) FROM t1
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_documents->[0]->{id_name}, $array_of_documents->[0]->{id_name} ) ;
	my $docs_count = '';
	eval { $docs_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	$sql = '
	SELECT t1.id_entry, t1.id_line, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, t3.libelle_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, id_export, to_char((sum(credit-debit) over(PARTITION BY t1.numero_compte ORDER BY date_ecriture, libelle, libelle_journal, id_paiement, id_entry, id_line))/100::numeric, \'999G999G999G990D00\') as solde, lettrage, pointage
	FROM tbljournal t1
	INNER JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.numero_compte = t3.numero_compte
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND (t1.documents1 = ? OR t1.documents2 = ?)
	ORDER BY date_ecriture, id_facture, libelle, libelle_journal, id_paiement, id_entry, id_line
	' ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_documents->[0]->{id_name}, $array_of_documents->[0]->{id_name} ) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
    
    my ( $lettrage_href, $lettrage_link, $lettrage_input, $lettrage_base ) ;
    my ( $pointage_href, $pointage_link, $pointage_input, $pointage_base ) ;
    
    #on ne doit pas modifier des écritures exportées
    my $do_not_edit = ( $result_set->[0]->{id_export} ) ? 1 : 0 ;
        	
	if ( $do_not_edit eq 1 ) {
	$disabled_link = 'disabled' ;
   	$readonly_link = 'readonly' ;
	} 
    
    #####################################       
	# Menu chekbox
	#####################################   
	#définition des variables
	my @checked = ('0') x 15;
	my @dispcheck = ('0') x 15;
	my @actions;
    
    #checked par défault label1 et 2
    unless (defined $args->{label1}) {$args->{label1} = 1;}
	unless (defined $args->{label2}) {$args->{label2} = 1;}
	unless (defined $args->{label9}) {$args->{label9} = 1;}
	
	#Référence
	if (defined $args->{label1} && $args->{label1} eq 1) {$checked[1] = 'checked';} else {$checked[1] = '';}
	#Affichage
	if (defined $args->{label2} && $args->{label2} eq 1) {$checked[2] = 'checked';} else {$checked[2] = '';}
	#Historique des évènements
	if (defined $args->{label13} && $args->{label13} eq 1 || defined $args->{delete_event} || defined $args->{historique}) {$checked[14] = 'checked';} else {$checked[14] = '';}
	#Email
	if (defined $args->{label15} && $args->{label15} eq 1 || defined $args->{email}) {$checked[15] = 'checked';} else {$checked[15] = '';}
	#Rechercher
	if (defined $args->{label3} && $args->{label3} eq 1) {$checked[3] = 'checked';} else {$checked[3] = '';}
	#Saisie Rapide
	if ((defined $args->{label4} && $args->{label4} eq 1) || defined $args->{saisie_rapide}) {$checked[4] = 'checked';} else {$checked[4] = '';}
	#doc1
	if (defined $args->{label8} && $args->{label8} eq 1) {$checked[8] = 'checked';} else {$checked[8] = '';}
	#doc2
	if (defined $args->{label9} && $args->{label9} eq 1) {$checked[9] = 'checked';} else {$checked[9] = '';}
	#Ecritures récurrentes
	if ((defined $args->{label10} && $args->{label10} eq 1) || defined $args->{ecriture_recurrente}) {$checked[10] = 'checked';} else {$checked[10] = '';}
	#Ecritures csv
	if ((defined $args->{label11} && $args->{label11} eq 1) || defined $args->{csv}) {$checked[11] = 'checked';} else {$checked[11] = '';}

	# Tableau associatif pour les actions et les libellés quand l'exercice n'est pas clôturé
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {		
		@actions = (
		{ label => 'Référence', name => 'label1', index => 1 },
		{ label => 'Affichage', name => 'label2', index => 2 },
		{ label => 'Historique', name => 'label13', index => 14 },
		{ label => 'Email', name => 'label15', index => 15 },
		{ label => 'Rechercher', name => 'label3', index => 3 },
		{ label => 'Saisie Rapide', name => 'label4', index => 4 },
		{ label => 'doc1', name => 'label8', index => 8 },
		{ label => 'doc2', name => 'label9', index => 9 },
		{ label => 'Écr. récurrentes', name => 'label10', index => 10 },
		{ label => 'CSV/OFX/OCR', name => 'label11', index => 11 },
		);
	# Tableau associatif pour les actions et les libellés quand l'exercice est clôturé	
	} else {
		@actions = (
		{ label => 'Référence', name => 'label1', index => 1 },
		{ label => 'Affichage', name => 'label2', index => 2 },
		{ label => 'Historique', name => 'label13', index => 14 },
		{ label => 'Email', name => 'label15', index => 15 },
		{ label => 'Rechercher', name => 'label3', index => 3 },
		);
	}

	my $fiche_client .= '
	<fieldset class=pretty-box>
		<legend style="display: flex; align-items:center; ">
			<h3 class="Titre09">Gestion des documents</h3>
			<a title="Création d\'une nouvelle entrée en doc1" class="aperso" href="' . $new_entree_docs1_href . '">#new_entrée_docs1</a>
			<a title="Création d\'une nouvelle entrée en doc2" class="aperso" href="' . $new_entree_docs2_href . '">#new_entrée_docs2</a>
			<a title="Retour arrière" class="aperso" href="' . $retour_href . '">#retour</a>
		</legend>
		
		<div class=centrer>
			<div class="flex-checkbox">
	';

	# Ajout des champs cachés pour toutes les actions
	foreach my $action (@actions) {
		$fiche_client .= '<input type=hidden name="' . $action->{name} . '" value="' . ($args->{$action->{name}} || '') . '">';
	}

	foreach my $action (@actions) {
		$fiche_client .= '
		<form method="post" action=/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '>
			<label for="check' . $action->{index} . '" class="forms2_label">' . $action->{label} . '</label>
			<input id="check' . $action->{index} . '" type="checkbox" class="demo5" '.$checked[$action->{index}].' onchange="submit()" name="' . $action->{name} . '" value=1>
			<label for="check' . $action->{index} . '" class="forms2_label"></label>
			<input type=hidden name="' . $action->{name} . '" value=0 >';
		
		foreach my $other_action (@actions) {
			if ($other_action->{name} ne $action->{name}) {
				$fiche_client .= '<input type=hidden name="' . $other_action->{name} . '" value="' . ($args->{$other_action->{name}} || '') . '">';
			}
		}
		$fiche_client .= '</form>';
	}
	
	my $precedent ='<div class="arrow-left">&nbsp;</div>';
	my $suivant ='<div class="arrow-right">&nbsp;</div>';
	
	if ($id_name_docs->{previous_document}) {
		$precedent = '<div class="arrow-left"><a class="hideLink" title="Afficher le document précédent" href="docsentry?id_name=' . URI::Escape::uri_escape_utf8($id_name_docs->{previous_document} || '') . '">[&#9664;]</a></div>';
	}

	if ($id_name_docs->{next_document}) {
		$suivant = '<div class="arrow-right"><a class="hideLink" title="Afficher le document suivant" href="docsentry?id_name=' . URI::Escape::uri_escape_utf8($id_name_docs->{next_document} || '') . '">[&#9654;]</a></div>';
	}

	$fiche_client .= '</div><div class=Titre10>
	'.$precedent.'
	Modification du document <a class=nav2 href="docsentry?id_name='.$encoded_id_name.'">'.$args->{id_name}.'</a> (Exercice '.$array_of_documents->[0]->{fiscal_year}.')
	'.$suivant.'
	</div>';

    #####################################       
	#Formulaire du document
	#####################################    
    
    #gestion des options checkcheck_banque
	my $check_value = ( $array_of_documents->[0]->{check_banque} eq 't' ) ? 'checked' : '' ;
	my $check_value_multi = ( $array_of_documents->[0]->{multi} eq 't' ) ? 'checked' : '' ;
    
    #Gestion des écritures Multi-exercice
    my $display_last_exercice = '' ;
    my $display_label_exercice = '' ;
    if ( $array_of_documents->[0]->{multi} eq 't' ) {
		$display_last_exercice  = '<input class="forms2_input" style="width: 8%;" type=text id=new_last_fiscal_year name=new_last_fiscal_year value="' . ($array_of_documents->[0]->{last_fiscal_year} || '') . '" />';
		$display_label_exercice = '<label style="width: 8%;" class="forms2_label" for="new_last_fiscal_year">Last Exercice</label>';
	}
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docsentry.pm => id_name : '.$array_of_documents->[0]->{id_name}.' multi '.$array_of_documents->[0]->{multi}.' check_banque '.$array_of_documents->[0]->{check_banque}.'');
	my $encoded_name_array = uri_escape_utf8($array_of_documents->[0]->{id_name} || '');
	
	my $delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;supprimer=0' ;
	my $valid_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;modifier=1' ;
	my $rename_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;renommer=0' ;
	my $mail_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;email' ;

	my $submit_delete = '';
	my $submit_rename = '';
	if ($array_of_documents->[0]->{fiscal_year} eq $r->pnotes('session')->{fiscal_year} ) {
		$submit_delete = '<input type="submit" class="btn btn-rouge" style="width: 15%;" formaction="' . $delete_href . '" value="Supprimer" >';
		$submit_rename = '<input type="submit" class="btn btn-orange" style ="width : 15%;" title="Renommer le fichier pour prendre en compte le numéro de pièce" formaction="' . $rename_href .'" value="Renommer">';
	}
	
	# Requête pour récupérer la liste des tags du document
	$sql = 'SELECT t2.tags_nom FROM tbldocuments t1
			   LEFT JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client AND t1.id_name = t2.tags_doc
			   WHERE t1.id_client = ? AND t1.id_name = ? and t2.tags_nom is not null
			   GROUP BY t2.tags_nom
			   ORDER BY t2.tags_nom';
	my $array_of_documents_tags;
	my @bind_array_1 = ($r->pnotes('session')->{id_client},  $args->{id_name});
	eval { $array_of_documents_tags = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array_1) };
	my $add_tag_href = '';
	my $class_tag = 'men1';
	if (defined $args->{ajouter_tag} && $args->{ajouter_tag} eq 0) {
		$add_tag_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'' ;
		$class_tag = 'men1select';
	} else {
		$add_tag_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;ajouter_tag=0' ;
	}
	my $tag_list .= '<div class="tag-list">
	<span class="tag-item2"><a class="men '.$class_tag.'" href="' . $add_tag_href . '">Ajouter un #Tag</a></span>' ;
	if ( @{$array_of_documents_tags}) {
		for ( @{$array_of_documents_tags} ) {
			my $categorie_href= '/'.$r->pnotes('session')->{racine}.'/docs?tags=' . URI::Escape::uri_escape_utf8( $_->{tags_nom}  ) ;
			my $delete_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='. $encoded_name_array .'&amp;supprimer_tag=0&amp;tags_nom=' . URI::Escape::uri_escape_utf8( $_->{tags_nom}  ) ;
			$tag_list .= '
				<span class="tag-item">
					<a class="men men2" href="' . $categorie_href . '">' . $_->{tags_nom} . '</a>
					<a class="delete-tag" href="' . $delete_href . '" title="Supprimer le Tag ' . $_->{tags_nom} . '">Supprimer</a>
				</span>';
		}
	}
	$tag_list .= '</div>';
	
	$fiche_client .= '
	<form class=wrapper10 method="post" action=/'.$r->pnotes('session')->{racine}.'/docsentry>
	
	<div class=formflexN2>
		<label style="width: 3%;" class="forms2_label" for="check_banque">OK</label>
		<label style="width: 6.5%;" class="forms2_label" for="date_reception">Date</label>
		<label style="width: 36%;" class="forms2_label" for="new_id_name">Nom</label>
		<label style="width: 12%;" class="forms2_label" for="libelle">Catégorie</label>
		<label style="width: 6.5%;" class="forms2_label" for="montant">Montant</label>
		<label style="width: 14%;" class="forms2_label" for="compte_comptant">Compte</label>
		<label style="width: 3%;" class="forms2_label" for="multi">Multi</label>
		'.$display_label_exercice.'
	</div>
	
	<div class=formflexN2>
        <input class="forms2_input" style="width: 3%; height: 4ch; " type="checkbox" id="check_banque" name="check_banque" value="1" '.$check_value.' '.$disabled_link.'>
    	<input class="forms2_input" style="width: 6.5%;" type="text" id=date_reception name=date_reception value="' . ($array_of_documents->[0]->{date_reception} || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" '.$readonly_link.' />
		<input class="forms2_input" style="width: 36%;" type=text id=new_id_name name=new_id_name value="' . ($array_of_documents->[0]->{id_name} || '') . '" '.$readonly_link.' />
		' . $categorie_select . '
        <input class="forms2_input" style="width: 6.5%;" type=text id=montant name=montant value="' . $montant . '" onchange="format_number(this);" '.$readonly_link.'/>
		' .  $compte_comptant . '
        <input class="forms2_input" style="width: 3%; height: 4ch; " type="checkbox" id="multi" name="multi" value="1" '.$check_value_multi.' '.$disabled_link2.'>
		'.$display_last_exercice.'
    </div>
            
	<div class=formflexN3>
		<input type="submit" id=submit class="btn btn-vert" style="width: 15%;" formaction="' . $valid_href . '" value="Valider">
		'.$submit_delete.'
		'.$submit_rename.'
	</div>
		
    <input type=hidden name=old_id_name value="'. ($array_of_documents->[0]->{id_name}  || '').'" >
    <input type=hidden name=fiscal_year value="'. ($array_of_documents->[0]->{fiscal_year}  || '').'" >
    <input type=hidden name="old_multi" value="' . ($array_of_documents->[0]->{multi}  || ''). '">
    <input type=hidden name="label1" value="' . ($args->{label1} || ''). '">
	<input type=hidden name="label2" value="' . ($args->{label2} || ''). '">
	<input type=hidden name="label3" value="' . ($args->{label3} || ''). '">
	<input type=hidden name="label4" value="' . ($args->{label4} || ''). '">
	<input type=hidden name="label8" value="' . ($args->{label8} || ''). '">
	<input type=hidden name="label9" value="' . ($args->{label9} || ''). '">
	<input type=hidden name="label10" value="' . ($args->{label10} || ''). '">
	<input type=hidden name="label11" value="' . ($args->{label11} || ''). '">
	<input type=hidden name="label13" value="' . ($args->{label13} || ''). '">
	<input type=hidden name="label15" value="' . ($args->{label15} || ''). '">
   
    <br>
    '.$message_exercice_cloture.' 
	</form> 
	'.$tag_list.'
	' ;	

    #####################################       
	#Affichage des références comptables
	#####################################   
    
    my $disp_ndf = Base::Site::util::disp_lien_tag($args, $dbh, $r);

 	#ligne d'en-têtes
    my $entry_list .= '
    <div class=Titre10>Référence <span title="Cliquer pour masquer" id="hideLink1" onclick="toggleList(\'reference\');" style="cursor: pointer;">[▼]</span></div>
	'.$disp_ndf.'
	<br>
    <ul id=reference class="wrapper style1">
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 7.5%;">Date</span>
	<span class=headerspan style="width: 7.5%;">Journal</span>
	<span class=headerspan style="width: 7.5%;">Libre</span>
	<span class=headerspan style="width: 7.5%;">Compte</span>
	<span class=headerspan style="width: 11.5%;">Pièce</span>
	<span class=headerspan style="width: 29.9%;">Libellé</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 7%;">Pointage</span>
	<span class=headerspan style="width: 2%; text-align: center;">&nbsp;</span>
	<span class=headerspan style="width: 2%; text-align: center;">&nbsp;</span>
	<span class=headerspan style="width: 2%; text-align: center;">&nbsp;</span>
	<div class=spacer></div></div></li>' ;

	my $id_entry = '' ;
	
	if ($docs_count != '0') {
    
		for ( @$result_set ) {

			#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
			unless ($_->{id_entry} eq $id_entry ) {

				#lien de modification de l'entrée
				my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry}.'&amp;docs='.$array_of_documents->[0]->{id_name} ;

				#cas particulier de la première entrée de la liste : pas de liste précédente
				unless ( $id_entry ) {
					$entry_list .= '<li class=listitem3>' ;
				} else {
					$entry_list .= '</a></li><li class=listitem3>'
				} #	    unless ( $id_entry ) 

			} #	unless ( $_->{id_entry} eq $id_entry )

			#marquer l'entrée en cours
			$id_entry = $_->{id_entry} ;
			
			#pour le journal général, ajouter la colonne libelle_journal
			#my $libelle_journal = ( $args->{open_journal} eq 'Journal général' ) ? '<span class=blockspan style="width: 25ch;">' . $_->{libelle_journal} . '</span>' : '' ;
		
			my $http_link_documents1 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents1}, 1);
			my $http_link_documents2 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents2}, 2);
		
			#lien de modification de l'entrée
			my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry}.'&amp;docs='.$array_of_documents->[0]->{id_name} ;

			my $lettrage_pointage = '&nbsp;' ;
			
			if ($_->{numero_compte} eq ($array_of_documents->[0]->{id_compte} || '')) {
				$pointage_base = '<input type=checkbox id=id value=value style="vertical-align: middle;" onchange="location.reload()" onclick="pointage(this, \'' . ($_->{numero_compte} || '&nbsp;'). '\')">' ;
				$lettrage_base = '<input type=text id=id style="margin-left: 0.5em; padding: 0; width: 7ch; height: 1em; text-align: right;" value=value placeholder=&rarr; oninput="lettrage(this, \'' . ($_->{numero_compte} || '&nbsp;') . '\')">' ;
				
				#l'id_line de la checkox de pointage commence par pointage_ pour être différente de id_line sur l'input de lettrage
				my $pointage_id = 'id=pointage_' . $_->{id_line} ;
				( $pointage_input = $pointage_base ) =~ s/id=id/$pointage_id/ ;
				my $pointage_value = ( $_->{pointage} eq 't' ) ? 'checked' : '' ;
				$pointage_input =~ s/value=value/$pointage_value/ ;
				
				$sql = 'SELECT id_client FROM tbllocked_month 
				WHERE id_client = ? and ( id_month = to_char(?::date, \'MM\') ) AND fiscal_year = ?';
				@bind_array = ( $r->pnotes('session')->{id_client}, $_->{date_ecriture}, $r->pnotes('session')->{fiscal_year}) ;
				my $result_block = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
				
				#Modifier le pointage que si le mois n'est pas bloqué
				if (defined $result_block && $result_block eq $r->pnotes('session')->{id_client}) {
				$lettrage_pointage = ( $_->{pointage} eq 't' ) ? '<img class="redimmage nav" title="Check complet" src="/Compta/style/icons/icone-valider.png" alt="valide">' : '&nbsp;' ;
				} else {
				$lettrage_pointage = $pointage_input ;
				}
				
				my $lettrage_id = 'id=' . $_->{id_line} ;
				( $lettrage_input = $lettrage_base ) =~ s/id=id/$lettrage_id/ ;
				my $lettrage_value = ( $_->{lettrage} ) ? 'value=' . $_->{lettrage} : '' ;
				$lettrage_input =~ s/value=value/$lettrage_value/ ;
				#$lettrage_pointage .= $lettrage_input ;
			}
		
			$entry_list .= '
			<div class=flex-table><div class=spacer></div><a href="' . $id_entry_href . '">
			<span class=displayspan style="width: 7.5%;">' . $_->{date_ecriture} . '</span>
			<span class=displayspan style="width: 7.5%;">' . $_->{libelle_journal} .'</span>
			<span class=displayspan style="width: 7.5%;">' . ($_->{id_paiement} || '&nbsp;') . '</span>
			<span class=displayspan style="width: 7.5%;" title="'. $_->{libelle_compte} .'">' . $_->{numero_compte} . '</span>
			<span class=displayspan style="width: 11.5%;">' . $_->{id_facture} . '</span>
			<span class=displayspan style="width: 29.9%;">' . $_->{libelle} . '</span>
			<span class=displayspan style="width: 7.5%; text-align: right;">' . $_->{debit} . '</span>
			<span class=displayspan style="width: 7.5%; text-align: right;">' .  $_->{credit} . '</span>
			</a>
			<span class=displayspan style="width: 5%;">' . $lettrage_pointage . '</span>
			<span class=blockspan style="width: 2%;">&nbsp;</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents1 . '</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents2 . '</span>
			<div class=spacer></div></div>';
		} #    for ( @$result_set )
	}
	
    #on clot la liste s'il y avait au moins une entrée dans le journal
    $entry_list .= '</a></li>' if ( @$result_set ) ;

    $entry_list .=  '<li class=style1><hr></li>
    <li class=style1><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 11.5%;">&nbsp;</span>
	<span class=displayspan style="width: 29.9%; text-align: right;">Total</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . ( $result_set->[0]->{total_debit} || 0 ) . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . ( $result_set->[0]->{total_credit} || 0 ) . '</span>
	<div class=spacer></div></li>' ;

	$sql = '
	SELECT t1.id_entry, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit
	FROM tbljournal t1
	WHERE pointage = \'t\' AND numero_compte = ? AND t1.id_client = ? AND t1.fiscal_year = ? AND (t1.documents1 = ? OR t1.documents2 = ?)
	' ;
	my @bind_array2 = ( $array_of_documents->[0]->{id_compte}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_documents->[0]->{id_name}, $array_of_documents->[0]->{id_name} ) ;
	my $result_set512 = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array2 ) ;
 
    $entry_list .=  '<li class=style1><br></li>
    <li class=style1><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 11.5%;">&nbsp;</span>
	<span class=displayspan style="width: 29.9%; text-align: right; font-weight: bold;">Total Pointé</span>
	<span class=displayspan style="width: 7.5%; text-align: right; font-weight: bold;">' . ( $result_set512->[0]->{total_debit} || 0 ) . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right; font-weight: bold;">' . ( $result_set512->[0]->{total_credit} || 0 ) . '</span>
	</span><div class=spacer></div></li></ul>
	'.$memo.'
	' ;

	#####################################       
	#Affichage du document
	#####################################    
	
	my $display_doc = affichage_doc( $r, $args, $array_of_documents );
	
	#id="pdf-js-viewer" src="/pdf/web/viewer.html?file=/Compta/base/documents/
	
	#####################################       
	#Affichage Historique des évènements
	#####################################    
    my $display_histo .= '
   <div class=Titre10>Historique des évènements <span title="Cliquer pour masquer" id="hideLink3" onclick="toggleList(\'hideLinkhist\');" style="cursor: pointer;">[▼]</span></div>
	<br>
    <ul id=hideLinkhist class="wrapper style1">
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 20%;">Utilisateur</span>
	<span class=headerspan style="width: 20%;">Evènement</span>
	<span class=headerspan style="width: 35%;">Description</span>
	<span class=headerspan style="width: 20%;">Date</span>
	<span class=headerspan style="width: 2%; text-align: center;">&nbsp;</span>
	<span class=headerspan style="width: 3%; text-align: center;">&nbsp;</span>
	<div class=spacer></div></div></li>' ;
	
	my $array_of_events = Base::Site::bdd::get_document_history($dbh, $r, $array_of_documents->[0]->{id_name});

	if ( @{ $array_of_events } ) {
		my $line = 0;
		
		for ( @{ $array_of_events } ) {
			my $reqline = ($line++);
			my $formatted_date = substr($_->{event_date}, 0, 19);
			my $event_description = ( $_->{event_description} || '&nbsp;' );
			my $delete_event_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $encoded_id_name . '&amp;delete_event=' . $_->{id_num};
			my $delete_event_link = '<a class=nav href="' . $delete_event_href . '"><span class=blockspan style="width: 2%; text-align: center;"><img id="supprimer_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Supprimer" src="/Compta/style/icons/delete.png" alt="supprimer"></span></a>';
			
			# Ligne d'en-têtes pour chaque événement
			$display_histo .= '
				<li class=listitem3 id="line_'.$_->{id_num}.'">
				<div class=spacer></div>
				<span class=blockspan style="width: 20%;">' . $_->{user_id} . '</span>
				<span class=blockspan style="width: 20%;">' . $_->{event_type} . '</span>
				<span class=blockspan style="width: 35%;">' . $event_description . '</span>
				<span class=blockspan style="width: 20%;">' . $formatted_date . '</span>
				' . $delete_event_link . '
				<div class=spacer></div>
				</li>
			';
		}

	} else {
		# Aucun événement enregistré
		$display_histo .= '<li class="warnlite">*** Aucun événement enregistré ***</li>';
	}

	$display_histo .= '<li class=style1><hr></li></ul></main>
	<script>
	focusAndChangeColor2("'.($args->{delete_event} || '').'");
	</script>';

	#passage de variable aus formulaires Base::Site::menu::forms_
	$args->{date_doc_entry} ||= $array_of_documents->[0]->{date_reception};
	$args->{montant_doc_entry} ||= $montant;
	$args->{docs_doc_entry} ||= $array_of_documents->[0]->{id_name};
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docsentry.pm => date $array_of_documents->[0]->{montant}: '.$montant );

	my $forms_saisie_rapide .= '<fieldset class="pretty-box centrer">'.Base::Site::menu::forms_paiement_saisie( $r, $args, $dbh ).'</fieldset><br>';
	my $forms_search .= '<fieldset class="pretty-box centrer">'.Base::Site::menu::forms_search( $r, $args ).'</fieldset><br>';
	my $forms_ecri_rec .= '<fieldset class="pretty-box centrer">'.Base::Site::menu::forms_ecri_rec( $r, $args ).'</fieldset><br>';
	my $forms_importer .= '<fieldset class="pretty-box centrer">'.Base::Site::menu::forms_importer( $r, $args ).'</fieldset><br>';
	my $forms_tag .= '<fieldset class="pretty-box centrer">'.forms_tag( $r, $args ).'</fieldset><br>';
	my $forms_email .= '<fieldset class="pretty-box centrer">'.form_email( $r, $args ).'</fieldset><br>';
	
	if (defined $args->{label1} && $args->{label1} eq 1) {$dispcheck[1] = $entry_list;} else {$dispcheck[1] = '';}
	if (defined $args->{label2} && $args->{label2} eq 1) {$dispcheck[2] = $display_doc;} else {$dispcheck[2] = '';}
	if (defined $args->{label13} && $args->{label13} eq 1 || defined $args->{delete_event}|| defined $args->{historique}) {$dispcheck[14] = $display_histo;} else {$dispcheck[14] = '';}
	#if (defined $args->{label3} && $args->{label3} eq 1) {$dispcheck[3] = $search_entry . $propo_list;} else {$dispcheck[3] = '';}
	if (defined $args->{label3} && $args->{label3} eq 1) {$dispcheck[3] = $forms_search;} else {$dispcheck[3] = '';}
	if (defined $args->{label4} && $args->{label4} eq 1 || defined $args->{saisie_rapide}) {$dispcheck[4] = $forms_saisie_rapide;} else {$dispcheck[4] = '';}
	if ((defined $args->{label10} && $args->{label10} eq 1) || defined $args->{ecriture_recurrente}) {$dispcheck[10] = $forms_ecri_rec;} else {$dispcheck[10] = '';}
	if ((defined $args->{label11} && $args->{label11} eq 1) || defined $args->{csv}) {$dispcheck[11] = $forms_importer;} else {$dispcheck[11] = '';}
	if ((defined $args->{label12} && $args->{label12} eq 1) || defined $args->{ajouter_tag}) {$dispcheck[12] = $forms_tag;} else {$dispcheck[12] = '';}
	if (defined $args->{label15} && $args->{label15} eq 1 || defined $args->{email} ) {$dispcheck[15] = $forms_email;} else {$dispcheck[15] = '';}
	
	
    $content .= '<div class="wrapper-docs-entry">' . $fiche_client . $dispcheck[12] . $dispcheck[15] . $dispcheck[14] . $dispcheck[3] . $dispcheck[10] . $dispcheck[11] . $dispcheck[4] . $dispcheck[1] .  $dispcheck[2] .  '</div>' ;
	
    return $content ;
    
} #sub visualize 

#/*—————————————— Formulaire Ajout de Tag ——————————————*/
sub forms_tag {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors) ;
	my ($content, $id_entry, $contenu_web_ecri_rec) = ('', '', '');
	my $reqid = Base::Site::util::generate_reqline();
	my $encoded_id_name = uri_escape_utf8($args->{id_name} || '');
	my $confirm_add_href = 'docsentry?id_name=' . $encoded_id_name . '' ;

	# Formulaire de génération des écritures récurrentes 	
	my $tag_list = '
    <div class=centrer>
        <div class=Titre10>Ajouter un nouveau tag</div>
		<form method=POST action=/'.$r->pnotes('session')->{racine}.'/'.$confirm_add_href.'>
		<div class="respform" style="justify-content: center;">
			<div class="flex-25"><input class="respinput" type=text placeholder="Entrer ou sélectionner le nom du tag" name="tags_nom" value="" required onclick="liste_search_tag(this.value)" list="taglist"><datalist id="taglist"></datalist></span></div>
			<input type=hidden name="add_tag" value=1>
			<div class="flex-21"><input type=submit class="respbtn btn-vert" value=Ajouter ></div>
		</div>
		</form>
	</div>
    ' ;
		
	$content .= ($tag_list || '') ;

	return $content ;

}#sub forms_tag 

sub is_valid_pdf {
    my ($file_path) = @_;
    open my $fh, '<', $file_path or return 0;
    read $fh, my $header, 5;  # Lire les 5 premiers caractères
    close $fh;
    return $header eq '%PDF-';
}

# Fonction pour vérifier si un fichier est une image valide
sub is_valid_image {
    my $file_path = shift;
    return $file_path =~ /\.(jpg|jpeg|bmp|png)$/i && -e $file_path;
}

sub form_email {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $content ;
    my $encoded_id_name = uri_escape_utf8($args->{id_name} || '');
	
    $args->{restart} = 'docsentry?id_name=' . $encoded_id_name . '&email';
	
	$content .= Base::Site::util::form_email( $r, $args );
	
	return $content;
	
}

sub affichage_doc {
	
	# définition des variables
    my ( $r, $args, $array_of_documents) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    # Construction HTML avec gestion des boutons via JavaScript
	my $display_doc = '<div class=Titre10>Affichage du document 
	<span title="Cliquer pour masquer" id="hideLink2" onclick="toggleList(\'displaydoc\');" style="cursor: pointer;">[▼]</span></div>';
    
    # Définition des répertoires et chemins des fichiers
	my $base_dir = $r->document_root() . '/Compta/base/documents';
	my $client_id = $r->pnotes('session')->{id_client};
	my $doc_insert = $args->{inserer_document};
	my $fiscal_year = $r->pnotes('session')->{fiscal_year};
	my $archive_dir = $base_dir . '/' . $client_id . '/' . $fiscal_year . '/';
	my $backup_dir = $base_dir . '/' . $client_id . '/backup/';
	my $existing_file_path = $archive_dir . $args->{id_name};  # Fichier à modifier
	my $backup_file_path = $backup_dir . $args->{id_name} . ".bak";  # Sauvegarde de l'ancien fichier
		
    #/************ ACTION DEBUT *************/
    
    #######################################################################
	# Empécher de modifier un fichier multi-exercice					  #
	#######################################################################
    
    if ((defined $args->{inserer_document} || defined $args->{supprimer_page} || $args->{deplacer_page} ) && defined $args->{do_not_edit} && $args->{do_not_edit} eq 'disabled' && $r->pnotes('session')->{Exercice_Cloture} ne '1') {
		my $error_message = "Ce document ne peut être modifié car il appartient à un exercice comptable clôturé.";
		$display_doc .= Base::Site::util::generate_error_message($error_message);
	}

	#######################################################################
	# Manipulation du fichier PDF : ajout d'un document ou image à une position #
	#######################################################################

	elsif (defined $args->{id_name} && defined $args->{inserer_document} ) {

		my $info_doc = Base::Site::bdd::get_info_doc($dbh, $r->pnotes('session')->{id_client}, $doc_insert);
		my $doc_fiscal = $info_doc->{fiscal_year};
		my $archive_dir_add = $base_dir . '/' . $client_id . '/' . $doc_fiscal . '/';

		# Chemin complet des fichiers
		my $new_file_path = $archive_dir_add . $args->{inserer_document};  # Nouveau fichier à ajouter
		
		# Vérification de l'existence et de la validité des fichiers PDF
		if (!$info_doc || $doc_fiscal eq '' ) {
			my $error_message = "Erreur : Le fichier à insérer '$new_file_path' est introuvable ou invalide.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);

		# Vérification de l'existence et de la validité des fichiers PDF
		} elsif (!(-e $existing_file_path && is_valid_pdf($existing_file_path))) {
			my $error_message = "Erreur : Le fichier existant '$existing_file_path' est introuvable ou invalide.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
		}
		elsif (!(-e $new_file_path)) {
			my $error_message = "Erreur : Le fichier à insérer '$new_file_path' est introuvable.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
		}
		else {
			# Vérification du type du fichier à insérer (si c'est une image)
			my $image_extensions = qr/\.(jpg|jpeg|png|gif|bmp)$/i;
			my $is_image = $new_file_path =~ $image_extensions;

			# Sauvegarder l'ancien fichier dans le répertoire backup (si c'est un PDF)
			eval {
				copy($existing_file_path, $backup_file_path) or die "Impossible de sauvegarder le fichier.";
			};
			if ($@) {
				my $error_message = "Erreur lors de la sauvegarde du fichier : $@";
				$display_doc .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
			}
			else {
				# Si le fichier à insérer est une image, ajouter une page au PDF
				if ($is_image) {
					# Ouvrir le fichier PDF existant
					my $pdf_existing = eval { PDF::API2->open($existing_file_path) };
					if ($@ || !$pdf_existing) {
						my $error_message = "Erreur : Impossible d'ouvrir le fichier existant '$existing_file_path'.";
						$display_doc .= Base::Site::util::generate_error_message($error_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
					}
					else {
						# Ajouter une nouvelle page au PDF
						my $pdf_new = PDF::API2->new();
						my $page;
						
						if (defined $args->{position} && $args->{position} eq 'debut') {
							$page = $pdf_existing->page(1);
						} else {
							$page = $pdf_existing->page();
						}
						
						# Définir la taille de la page A4
						$page->mediabox(0, 0, 595.27, 841.89);

						my $image_file = $new_file_path;
						my $image_object;

						# Ajouter l'image à la nouvelle page selon son format
						if ($new_file_path =~ /\.jpg$|\.jpeg$/i) {
							$image_object = $pdf_existing->image_jpeg($image_file);  # Ajouter image JPEG
						} elsif ($new_file_path =~ /\.png$/i) {
							$image_object = $pdf_existing->image_png($image_file);   # Ajouter image PNG
						} elsif ($new_file_path =~ /\.gif$/i) {
							$image_object = $pdf_existing->image_gif($image_file);   # Ajouter image GIF
						} elsif ($new_file_path =~ /\.bmp$/i) {
							$image_object = $pdf_existing->image_bmp($image_file);   # Ajouter image BMP
						}
						
						# Content object needed to insert an image
						my $gfx = $page->gfx;

						# Taille de la page A4 en points (en 72 DPI)
						my $a4_width = 595.27;  # Largeur d'une page A4
						my $a4_height = 841.89;  # Hauteur d'une page A4

						# Pourcentages des marges (par exemple, 5% pour la marge gauche, 10% pour la marge droite)
						my $margin_left_percentage = 0.05;  # 5% de la largeur de la page
						my $margin_right_percentage = 0.05;  # 5% de la largeur de la page
						my $margin_top_percentage = 0.10;  # 5% de la hauteur de la page
						my $margin_bottom_percentage = 0.10;  # 5% de la hauteur de la page

						# Calculer les marges en points (en multipliant par la taille de la page)
						my $margin_left = $a4_width * $margin_left_percentage;
						my $margin_right = $a4_width * $margin_right_percentage;
						my $margin_top = $a4_height * $margin_top_percentage;
						my $margin_bottom = $a4_height * $margin_bottom_percentage;

						# Calculer les dimensions disponibles pour l'image avec les marges
						my $available_width = $a4_width - $margin_left - $margin_right;
						my $available_height = $a4_height - $margin_top - $margin_bottom;
						
						# Obtenez les dimensions de l'image
						my $image_width = $image_object->width();
						my $image_height = $image_object->height();

						# Calculer si l'image est trop grande pour la page, et ajuster sa taille si nécessaire
						my $scale_factor = 1;

						if ($image_width > $available_width || $image_height > $available_height) {
							# Calculer les facteurs de mise à l'échelle pour la largeur et la hauteur
							my $scale_width = $available_width / $image_width;
							my $scale_height = $available_height / $image_height;

							# Le facteur de mise à l'échelle sera le plus petit des deux pour maintenir les proportions
							$scale_factor = ($scale_width < $scale_height) ? $scale_width : $scale_height;
						}

						# Calculer les nouvelles dimensions de l'image après mise à l'échelle
						my $scaled_width = $image_width * $scale_factor;
						my $scaled_height = $image_height * $scale_factor;

						# Calculer la position pour centrer l'image avec marges, en prenant en compte l'échelle
						my $x = $margin_left + ($available_width - $scaled_width) / 2;  # Centrer horizontalement avec marges
						my $y = $margin_top + ($available_height - $scaled_height) / 2;  # Centrer verticalement avec marges

						# Insérer l'image redimensionnée et centrée sur la page avec marges
						$gfx->image($image_object, $x, $y, $scaled_width, $scaled_height );

						# Sauvegarder le fichier combiné avec l'image ajoutée
						eval {
							$pdf_existing->saveas($existing_file_path);
						};
						if ($@) {
							my $error_message = "Erreur lors de l'ajout de l'image au fichier : $@";
							$display_doc .= Base::Site::util::generate_error_message($error_message);
							Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
						} else {
							# Fermer les fichiers PDF
							$pdf_existing->end();
							 # Message de succès
								my $display_success = "Le document a été mis à jour avec succès en ajoutant le fichier " . $args->{inserer_document} . " ";
								$display_doc .= Base::Site::util::generate_error_message($display_success);

								# Enregistrement de l'événement dans l'historique des documents
								my $event_type = 'Ajout de document';
								my $event_description = "Le document a été ajouté avec succès.";
								my $save_document_history = Base::Site::bdd::save_document_history(
									$dbh, 
									$client_id, 
									$args->{id_name}, 
									$event_type, 
									$event_description, 
									$r->pnotes('session')->{username}
								);
							Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "docentry.pm => Image ajoutée avec succès au fichier '$existing_file_path'.");
						}
					}
				}
				else {
					# Ouvrir les fichiers PDF existant et nouveau (si ce n'est pas une image)
					my $pdf_existing = eval { PDF::API2->open($existing_file_path) };
					if ($@ || !$pdf_existing) {
						my $error_message = "Erreur : Impossible d'ouvrir le fichier existant '$existing_file_path'.";
						$display_doc .= Base::Site::util::generate_error_message($error_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
					}
					else {
						my $pdf_new = eval { PDF::API2->open($new_file_path) };
						if ($@ || !$pdf_new) {
							my $error_message = "Erreur : Impossible d'ouvrir le fichier à insérer '$new_file_path'.";
							$display_doc .= Base::Site::util::generate_error_message($error_message);
							Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
						}
						else {
							# Récupérer le nombre de pages des deux fichiers
							my $page_count_existing = $pdf_existing->pages();
							my $page_count_new = $pdf_new->pages();

							# Déterminer la position d'insertion
							my $position = $args->{position} || 'fin';  # Par défaut, insérer à la fin

							# Créer un nouveau fichier PDF combiné
							my $pdf_combined = PDF::API2->new();

							eval {
								if ($position eq 'debut') {
									# Ajouter d'abord les pages du nouveau fichier
									for my $page_number (1 .. $page_count_new) {
										$pdf_combined->importpage($pdf_new, $page_number);
									}
									# Ajouter ensuite les pages du fichier existant
									for my $page_number (1 .. $page_count_existing) {
										$pdf_combined->importpage($pdf_existing, $page_number);
									}
								} else {
									# Ajouter d'abord les pages du fichier existant
									for my $page_number (1 .. $page_count_existing) {
										$pdf_combined->importpage($pdf_existing, $page_number);
									}
									# Ajouter ensuite les pages du nouveau fichier
									for my $page_number (1 .. $page_count_new) {
										$pdf_combined->importpage($pdf_new, $page_number);
									}
								}

								# Sauvegarder le fichier combiné sous le même nom
								$pdf_combined->saveas($existing_file_path);
							};
							if ($@) {
								my $error_message = "Erreur lors de la sauvegarde du fichier combiné : $@";
								$display_doc .= Base::Site::util::generate_error_message($error_message);
								Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
							} else {
								# Fermer les fichiers PDF
								$pdf_existing->end();
								$pdf_new->end();
								$pdf_combined->end();

								# Message de succès
								my $display_success = "Le document a été mis à jour avec succès en ajoutant le fichier '" . $args->{inserer_document} . "' ";
								$display_doc .= Base::Site::util::generate_error_message($display_success);

								# Enregistrement de l'événement dans l'historique des documents
								my $event_type = 'Ajout de document';
								my $event_description = "Le document a été ajouté avec succès.";
								my $save_document_history = Base::Site::bdd::save_document_history(
									$dbh, 
									$client_id, 
									$args->{id_name}, 
									$event_type, 
									$event_description, 
									$r->pnotes('session')->{username}
								);

								# Log de l'importation réussie
								Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "docentry.pm => Ajout du document '" . $args->{inserer_document} . "' au fichier '" . $args->{id_name} . "'.");
							}
						}
					}
				}
			}
		}
	}

	#######################################################################
	# Manipulation du fichier PDF : suppression de pages d'un document PDF
	#######################################################################

	elsif (defined $args->{id_name} && defined $args->{supprimer_page} ) {

		# Vérification de l'existence et de la validité du fichier PDF
		if (!(-e $existing_file_path && is_valid_pdf($existing_file_path))) {
			my $error_message = "Erreur : Le fichier existant '$existing_file_path' est introuvable ou invalide.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
		} else {
			# Sauvegarde de l'ancien fichier dans le répertoire backup
			eval {
				copy($existing_file_path, $backup_file_path) or die "Impossible de sauvegarder le fichier.";
			};
			if ($@) {
				my $error_message = "Erreur lors de la sauvegarde du fichier : $@";
				$display_doc .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
			} else {
				# Décoder les pages à supprimer
				my $supprimer_page = $args->{supprimer_page};  # Pages à supprimer (ex: 2,3,5-8)
				$supprimer_page = uri_unescape($supprimer_page);  # Décoder l'URL

				# Initialiser le tableau de pages à supprimer
				my @pages_to_delete;

				# Traitement de la chaîne de pages à supprimer
				foreach my $range (split(',', $supprimer_page)) {
					if ($range =~ /(\d+)-(\d+)/) {
						push @pages_to_delete, $_ for $1..$2;  # Plage de pages
					} else {
						push @pages_to_delete, $range;  # Page unique
					}
				}

				# Enlever les doublons (en utilisant un hash pour garantir l'unicité)
				my %seen;
				@pages_to_delete = grep { !$seen{$_}++ } @pages_to_delete;

				# Ouvrir le fichier PDF existant
				my $pdf_existing = eval { PDF::API2->open($existing_file_path) };
				if ($@ || !$pdf_existing) {
					my $error_message = "Erreur : Impossible d'ouvrir le fichier '$existing_file_path'.";
					$display_doc .= Base::Site::util::generate_error_message($error_message);
					Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
				} else {
					# Récupérer le nombre total de pages du PDF
					my $total_pages = $pdf_existing->pages();

					# Vérifier les pages à supprimer avant de procéder
					my @invalid_pages;
					foreach my $page_num (@pages_to_delete) {
						if ($page_num > $total_pages || $page_num < 1) {
							push @invalid_pages, $page_num;
						}
					}

					# Afficher un message si certaines pages sont invalides
					if (@invalid_pages) {
						my $invalid_message = "Erreur : Les pages suivantes ne peuvent pas être supprimées car elles n'existent pas dans le document : " . join(", ", @invalid_pages);
						$display_doc .= Base::Site::util::generate_error_message($invalid_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $invalid_message);
					}

					# Créer un nouveau PDF pour la sauvegarde
					my $pdf_new = PDF::API2->new();

					# Copier les pages restantes (celles qui ne sont pas à supprimer)
					for my $page_num (1..$total_pages) {
						unless (grep { $_ == $page_num } @pages_to_delete) {
							# Copier la page dans le nouveau fichier PDF
							$pdf_new->import_page($pdf_existing, $page_num, $page_num);
						}
					}

					# Sauvegarder le fichier PDF modifié
					eval {
						$pdf_new->saveas($existing_file_path);
					};
					if ($@) {
						my $error_message = "Erreur lors de la suppression des pages dans le fichier : $@";
						$display_doc .= Base::Site::util::generate_error_message($error_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
					} else {
						# Message de succès
						my $display_success = "Le document a été mis à jour avec succès en supprimant les pages spécifiées.";
						$display_doc .= Base::Site::util::generate_error_message($display_success);

						# Enregistrement de l'événement dans l'historique des documents
						my $event_type = 'Suppression de pages';
						my $event_description = "Le document a été mis à jour avec succès.";
						my $save_document_history = Base::Site::bdd::save_document_history(
							$dbh, 
							$client_id, 
							$args->{id_name}, 
							$event_type, 
							$event_description, 
							$r->pnotes('session')->{username}
						);

						# Log de la suppression réussie
						Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "docentry.pm => Pages supprimées avec succès du fichier $existing_file_path.");
					}
					# Fermer les fichiers PDF
					$pdf_existing->end();
					$pdf_new->end();
				}
			}
		}
	}

	#######################################################################
	# Manipulation du fichier PDF : déplacement de pages d'un document PDF
	#######################################################################

	elsif (defined $args->{id_name} && defined $args->{deplacer_page} && defined $args->{to}) {

		# Vérification de l'existence et de la validité du fichier PDF
		if (!(-e $existing_file_path && is_valid_pdf($existing_file_path))) {
			my $error_message = "Erreur : Le fichier existant '$existing_file_path' est introuvable ou invalide.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
		} else {
			# Sauvegarde de l'ancien fichier dans le répertoire backup
			eval {
				copy($existing_file_path, $backup_file_path) or die "Impossible de sauvegarder le fichier.";
			};
			if ($@) {
				my $error_message = "Erreur lors de la sauvegarde du fichier : $@";
				$display_doc .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
			} else {
				# Récupérer les pages à déplacer
				my $deplacer_page = $args->{deplacer_page};  # Page à déplacer (ex: 1)
				my $destination_page = $args->{to};          # Page de destination (ex: 3)

				# Vérifier que les pages sont valides
				$deplacer_page = int($deplacer_page);
				$destination_page = int($destination_page);

				# Ouvrir le fichier PDF existant
				my $pdf_existing = eval { PDF::API2->open($existing_file_path) };
				if ($@ || !$pdf_existing) {
					my $error_message = "Erreur : Impossible d'ouvrir le fichier '$existing_file_path'.";
					$display_doc .= Base::Site::util::generate_error_message($error_message);
					Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
				} else {
					# Récupérer le nombre total de pages du PDF
					my $total_pages = $pdf_existing->pages();

					# Vérification de la page à déplacer
					if ($deplacer_page < 1 || $deplacer_page > $total_pages) {
						my $error_message = "Erreur : La page à déplacer ($deplacer_page) n'existe pas dans le document.";
						$display_doc .= Base::Site::util::generate_error_message($error_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
					} else {
						# Vérification de la page de destination
						if ($destination_page < 1 || $destination_page > $total_pages) {
							my $error_message = "Erreur : La page de destination ($destination_page) n'est pas valide.";
							$display_doc .= Base::Site::util::generate_error_message($error_message);
							Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
						} else {
							# Créer un nouveau PDF pour la sauvegarde
							my $pdf_new = PDF::API2->new();

							# Importer toutes les pages, sauf celle à déplacer
							my @pages_to_import;
							for my $page_num (1..$total_pages) {
								if ($page_num != $deplacer_page) {
									push @pages_to_import, $page_num;
								}
							}

							# Créer une nouvelle liste des pages à insérer
							my @pages_to_insert;
							if ($destination_page > $total_pages) {
								# Si la page de destination est au-delà de la dernière page, on l'ajoute à la fin
								push @pages_to_insert, $deplacer_page;
							} else {
								# Sinon, on insère la page déplacée à la position souhaitée
								push @pages_to_insert, $deplacer_page;
							}

							# Insérer les pages dans le nouveau PDF
							foreach my $page_num (@pages_to_import) {
								$pdf_new->import_page($pdf_existing, $page_num, $page_num);
							}

							# Insérer la page déplacée à la bonne position
							if ($destination_page <= @pages_to_import) {
								$pdf_new->import_page($pdf_existing, $deplacer_page, $destination_page);
							} else {
								$pdf_new->import_page($pdf_existing, $deplacer_page, @pages_to_import + 1);
							}

							# Sauvegarder le fichier PDF modifié
							eval {
								$pdf_new->saveas($existing_file_path);
							};
							if ($@) {
								my $error_message = "Erreur lors du déplacement des pages dans le fichier : $@";
								$display_doc .= Base::Site::util::generate_error_message($error_message);
								Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
							} else {
								# Message de succès
								my $display_success = "Le document a été mis à jour avec succès en déplaçant la page spécifiée.";
								$display_doc .= Base::Site::util::generate_error_message($display_success);

								# Enregistrement de l'événement dans l'historique des documents
								my $event_type = 'Déplacement de page';
								my $event_description = "La page a été déplacée avec succès.";
								my $save_document_history = Base::Site::bdd::save_document_history(
									$dbh, 
									$client_id, 
									$args->{id_name}, 
									$event_type, 
									$event_description, 
									$r->pnotes('session')->{username}
								);

								# Log de la suppression réussie
								Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "docentry.pm => Page déplacée avec succès du fichier '$existing_file_path'.");
							}
							# Fermer les fichiers PDF
							$pdf_existing->end();
							$pdf_new->end();
						}
					}
				}
			}
		}
	}

	###########################################################################
	# Fonction : Transformer une image en fichier PDF contenant cette image
	###########################################################################
	elsif (defined $args->{id_name} && defined $args->{transformer}) {

		# Vérification de l'extension du fichier image
		if ($args->{id_name} =~ /\.(jpe?g|png|gif|tiff?|bmp)$/i) {
			
			# Créer le nouveau nom en enlevant l'extension de l'image et en y ajoutant ".pdf"
			my $new_name = $args->{id_name};
			$new_name =~ s/\.(jpe?g|png|gif|tiff?|bmp)$/\.pdf/i;  # Remplace l'extension par .pdf

			# Définir les chemins des fichiers
			my $image_file_path = $archive_dir . $args->{id_name};

			# Vérifier si le fichier image existe
			if (-e $image_file_path) {
				# Chemin pour le fichier PDF
				my $pdf_file_path = $archive_dir . $new_name ;

				eval {
					
					# Ajouter une nouvelle page au PDF
					my $pdf = PDF::API2->new();
					my $page = $pdf->page();
						
					# Définir la taille de la page A4
					$page->mediabox(0, 0, 595.27, 841.89);

					my $image_file = $image_file_path;
					my $image_object;

					# Ajouter l'image à la nouvelle page selon son format
					if ($image_file_path =~ /\.jpg$|\.jpeg$/i) {
						$image_object = $pdf->image_jpeg($image_file);  # Ajouter image JPEG
					} elsif ($image_file_path =~ /\.png$/i) {
						$image_object = $pdf->image_png($image_file);   # Ajouter image PNG
					} elsif ($image_file_path =~ /\.gif$/i) {
						$image_object = $pdf->image_gif($image_file);   # Ajouter image GIF
					} elsif ($image_file_path =~ /\.bmp$/i) {
						$image_object = $pdf->image_bmp($image_file);   # Ajouter image BMP
					}
						
					# Content object needed to insert an image
					my $gfx = $page->gfx;

					# Taille de la page A4 en points (en 72 DPI)
					my $a4_width = 595.27;  # Largeur d'une page A4
					my $a4_height = 841.89;  # Hauteur d'une page A4

					# Pourcentages des marges (par exemple, 5% pour la marge gauche, 10% pour la marge droite)
					my $margin_left_percentage = 0.05;  # 5% de la largeur de la page
					my $margin_right_percentage = 0.05;  # 5% de la largeur de la page
					my $margin_top_percentage = 0.10;  # 5% de la hauteur de la page
					my $margin_bottom_percentage = 0.10;  # 5% de la hauteur de la page

					# Calculer les marges en points (en multipliant par la taille de la page)
					my $margin_left = $a4_width * $margin_left_percentage;
					my $margin_right = $a4_width * $margin_right_percentage;
					my $margin_top = $a4_height * $margin_top_percentage;
					my $margin_bottom = $a4_height * $margin_bottom_percentage;

					# Calculer les dimensions disponibles pour l'image avec les marges
					my $available_width = $a4_width - $margin_left - $margin_right;
					my $available_height = $a4_height - $margin_top - $margin_bottom;
						
					# Obtenez les dimensions de l'image
					my $image_width = $image_object->width();
					my $image_height = $image_object->height();

					# Calculer si l'image est trop grande pour la page, et ajuster sa taille si nécessaire
					my $scale_factor = 1;

					if ($image_width > $available_width || $image_height > $available_height) {
						# Calculer les facteurs de mise à l'échelle pour la largeur et la hauteur
						my $scale_width = $available_width / $image_width;
						my $scale_height = $available_height / $image_height;

						# Le facteur de mise à l'échelle sera le plus petit des deux pour maintenir les proportions
						$scale_factor = ($scale_width < $scale_height) ? $scale_width : $scale_height;
					}

					# Calculer les nouvelles dimensions de l'image après mise à l'échelle
					my $scaled_width = $image_width * $scale_factor;
					my $scaled_height = $image_height * $scale_factor;

					# Calculer la position pour centrer l'image avec marges, en prenant en compte l'échelle
					my $x = $margin_left + ($available_width - $scaled_width) / 2;  # Centrer horizontalement avec marges
					my $y = $margin_top + ($available_height - $scaled_height) / 2;  # Centrer verticalement avec marges

					# Insérer l'image redimensionnée et centrée sur la page avec marges
					$gfx->image($image_object, $x, $y, $scaled_width, $scaled_height );

					# Sauvegarder le PDF
					$pdf->saveas($pdf_file_path);
				};

				# Si une erreur s'est produite lors de la conversion, afficher un message
				if ($@) {
					my $error_message = "Erreur lors de la conversion de l'image en PDF: $@";
					$display_doc .= Base::Site::util::generate_error_message($error_message);
					Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
				} else {
					# Mise à jour du nom du fichier dans la base de données
					my $sql = 'UPDATE tbldocuments SET id_name = ? WHERE id_client = ? AND id_name = ?';
					my @bind_array = ($new_name, $r->pnotes('session')->{id_client}, $args->{id_name});
					eval { $dbh->do($sql, undef, @bind_array) };

					if ($@) {
						# Gérer les erreurs de mise à jour
						if ($@ =~ /NOT NULL (.*) date_reception/) {
							$display_doc .= Base::Site::util::generate_error_message('Il faut une date valide - Enregistrement impossible');
						} elsif ($@ =~ /duplicate/) {
							$display_doc .= Base::Site::util::generate_error_message('Enregistrement impossible car un fichier existe déjà avec le même nom');
						} else {
							$display_doc .= Base::Site::util::generate_error_message($@);
						}
					} else {
						# Message de succès
						my $display_success = "Le document a été transformé avec succès.";
						$display_doc .= Base::Site::util::generate_error_message($display_success);

						# Enregistrement de l'événement dans l'historique des documents
						my $event_type = 'Transformation en pdf';
						my $event_description = "Le document a été transformé avec succès.";
						my $save_document_history = Base::Site::bdd::save_document_history(
							$dbh, 
							$r->pnotes('session')->{id_client}, 
							$new_name, 
							$event_type, 
							$event_description, 
							$r->pnotes('session')->{username}
						);

						# Log de la suppression réussie
						Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "docentry.pm => Image transformée avec succès.");
							
						# Rediriger avec le nouveau nom
						$args->{restart} = 'docsentry?id_name=' . uri_escape_utf8($new_name);
						Base::Site::util::restart($r, $args);
						return Apache2::Const::OK;
					}
				}
			} else {
				my $error_message = "Erreur : Le fichier existant ".$args->{id_name}." est introuvable ou invalide.";
				$display_doc .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
			}
		}
	}

	#######################################################################
	# Manipulation du fichier PDF : rotation d'une ou plusieurs pages
	#######################################################################

	elsif (defined $args->{id_name} && defined $args->{rotation} && defined $args->{angle}) {

		# Vérification de l'existence et de la validité du fichier PDF
		if (!(-e $existing_file_path && is_valid_pdf($existing_file_path))) {
			my $error_message = "Erreur : Le fichier existant '$existing_file_path' est introuvable ou invalide.";
			$display_doc .= Base::Site::util::generate_error_message($error_message);
			Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
		} else {
			# Sauvegarde de l'ancien fichier dans le répertoire backup
			eval {
				copy($existing_file_path, $backup_file_path) or die "Impossible de sauvegarder le fichier.";
			};
			if ($@) {
				my $error_message = "Erreur lors de la sauvegarde du fichier : $@";
				$display_doc .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
			} else {
				# Récupérer les arguments
				my $rotation_angle = $args->{angle};  # Doit être un multiple de 90 (90, 180, 270)
				my $page_number = $args->{rotation};  # Numéro de la page à pivoter

				# Vérifier que les arguments sont valides
				$rotation_angle = int($rotation_angle);
				$page_number = int($page_number);

				if ($rotation_angle % 90 != 0) {
					my $error_message = "Erreur : L'angle de rotation ($rotation_angle) doit être un multiple de 90.";
					$display_doc .= Base::Site::util::generate_error_message($error_message);
					Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
				} else {
					# Ouvrir le fichier PDF existant
					my $pdf_existing = eval { PDF::API2->open($existing_file_path) };
					if ($@ || !$pdf_existing) {
						my $error_message = "Erreur : Impossible d'ouvrir le fichier '$existing_file_path'.";
						$display_doc .= Base::Site::util::generate_error_message($error_message);
						Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
					} else {
						# Récupérer le nombre total de pages du PDF
						my $total_pages = $pdf_existing->pages();

						# Vérification que la page existe
						if ($page_number < 1 || $page_number > $total_pages) {
							my $error_message = "Erreur : La page spécifiée ($page_number) n'existe pas.";
							$display_doc .= Base::Site::util::generate_error_message($error_message);
							Base::Site::logs::logEntry("#### ERROR ####", $r->pnotes('session')->{username}, $error_message);
						} else {
							
							eval {
								my $page = $pdf_existing->openpage($page_number);

								# Calcul de la nouvelle rotation
								my $new_rotation = ($rotation_angle) % 360;

								$page->rotate($new_rotation);
								
								#Base::Site::logs::logEntry("#### DEBUG ####", "Rotation actuelle (raw): " . ($page->rotate() // 'undef'));

								# Sauvegarde du PDF
								$pdf_existing->saveas($existing_file_path);
							};

							if ($@) {
								my $error_message = "Erreur lors de la rotation de la page : $@";
								$display_doc .= Base::Site::util::generate_error_message($error_message);

							} else {
								# Message de succès
								my $success_message = "La page $page_number a été pivotée de $rotation_angle° avec succès.";
								$display_doc .= Base::Site::util::generate_error_message($success_message);
								
								# Enregistrement de l'événement dans l'historique des documents
								my $event_type = 'Modification du pdf';
								my $event_description = "La page $page_number a été pivotée de $rotation_angle°.";
								my $save_document_history = Base::Site::bdd::save_document_history(
									$dbh, 
									$r->pnotes('session')->{id_client}, 
									$args->{id_name}, 
									$event_type, 
									$event_description, 
									$r->pnotes('session')->{username}
								);
							}
							# Fermer le fichier PDF
							$pdf_existing->end();
						}
					}
				}
			}
		}
	}

	#/************ ACTION FIN *************/
	
	# Générer un identifiant unique basé sur l'heure ou un autre facteur
	my $timestamp = time();  # Utiliser l'heure actuelle en secondes depuis l'époque
	
	my $document_select10;
	my $array_all_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $onchange10 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my $selected10 = (defined($args->{docs_100})) ? ($args->{docs_100}) : undef;
	my ($form_name10, $form_id10) = ('docs_100', 'docs_100');
	$document_select10 .='<div>';
	$document_select10 .= Base::Site::util::generate_document_selector($array_all_documents, '150', $selected10, $form_name10, $form_id10, $onchange10, 'class="forms2_input"', 'style ="width : 40%;"');

	
	if (defined $args->{do_not_edit} && $args->{do_not_edit} ne 'disabled' && $r->pnotes('session')->{Exercice_Cloture} ne '1') {
		
		my $file_name = $args->{id_name};

		###########################################################################
		# Vérifier si l'extension du fichier correspond à une image
		###########################################################################

		if ($file_name =~ /\.(jpe?g|png|gif|tiff?|bmp)$/i) {

			$display_doc .= '
			<div class="tag-list">
				<span class="tag-item2">
					<button id="btn-transform" class="men men3" onclick="toggleOptions(\'transform\')">Transformer en PDF</button>
				</span>
			</div>
			<div id="options-container" style="display: none;"></div>';

			# Ajout du JavaScript pour gérer l'affichage et l'action
			$display_doc .= '
			<script>
				let activeMenu = ""; // Variable pour suivre quel bouton est actif

				function toggleOptions(action) {
					const container = document.getElementById("options-container");
					const transformButton = document.getElementById("btn-transform");

					// Réinitialiser tous les boutons à leur état initial
					transformButton.className = "men men3";

					// Si le bouton cliqué est déjà actif, masquer le conteneur et réinitialiser
					if (activeMenu === action) {
						container.style.display = "none";
						activeMenu = ""; // Désactiver tout
						return;
					}

					// Sinon, afficher les options spécifiques et activer le bouton correspondant
					activeMenu = action;
					container.style.display = "block";

					if (action === "transform") {
						transformButton.className = "men men3 men3select";
						container.innerHTML = `
						<div class="flex-checkbox">
							<div style="width: 100%;" class="forms2_label">Souhaitez-vous transformer ce fichier image en PDF ?</div>
						</div>   
						<div>
							<button type="button" class="btnform2 valid-tag" onclick="confirmTransform()">Oui</button>
							<button type="button" class="btnform2 cancel-tag" onclick="cancelTransform()">Non</button>
						</div>
						`;
					}
				}
				
				function confirmTransform() {
					// Construire l\'URL pour transformer le fichier en PDF
					const baseHref = "docsentry?id_name=" + encodeURIComponent("' . $file_name . '");
					const transformHref = baseHref + "&transformer"; // Action pour transformer en PDF

					// Rediriger l\'utilisateur vers l\'URL générée
					window.location.href = transformHref;
				}
				
				function cancelTransform() {
					// Réinitialiser le conteneur et masquer les options
					document.getElementById("options-container").style.display = "none";
					activeMenu = ""; // Désactiver tout

					// Modifier la classe du bouton "Transformer en PDF" pour le restaurer à son état initial
					const transformButton = document.getElementById("btn-transform");
					transformButton.className = "men men3"; // Restaurer la classe initiale
				}

			</script>';

		} else {
		
			$display_doc .= '
			<div class="tag-list">
				<span class="tag-item2">
					<button id="btn-add" class="men men3" onclick="toggleOptions(\'add\')">Insérer un document</button>
				</span>
				<span class="tag-item2">
					<button id="btn-delete" class="men men3" onclick="toggleOptions(\'delete\')">Supprimer des pages</button>
				</span>
				<span class="tag-item2">
					<button id="btn-move" class="men men3" onclick="toggleOptions(\'move\')">Déplacer des pages</button>
				</span>
				 <span class="tag-item2">
					<button id="btn-rotate" class="men men3" onclick="toggleOptions(\'rotate\')">Pivoter des pages</button>
				</span>
			</div>
			<div id="options-container" style="display: none;"></div>';
			
			# Ajout du JavaScript pour gérer l'affichage des options et les classes dynamiques
			$display_doc .= '
			<script>
			let activeMenu = ""; // Variable pour suivre quel bouton est actif

			function toggleOptions(action) {
				const container = document.getElementById("options-container");
				const addButton = document.getElementById("btn-add");
				const deleteButton = document.getElementById("btn-delete");
				const moveButton = document.getElementById("btn-move");
				const rotateButton = document.getElementById("btn-rotate");

				// Réinitialiser tous les boutons à leur état initial
				addButton.className = "men men3";
				deleteButton.className = "men men3";
				moveButton.className = "men men3";
				rotateButton.className = "men men3";

				// Si le bouton cliqué est déjà actif, masquer le conteneur et réinitialiser
				if (activeMenu === action) {
					container.style.display = "none";
					activeMenu = ""; // Désactiver tout
					return;
				}

				// Sinon, afficher les options spécifiques et activer le bouton correspondant
				activeMenu = action;
				container.style.display = "block";

				if (action === "add") {
					addButton.className = "men men3 men3select";
					container.innerHTML = `
					<div class=flex-checkbox>
					<div style="width: 100%;" class="forms2_label">Choix du document à insérer et position par rapport au fichier actuel:</div>
					</div>   
					<div id="document_selectors">'.($document_select10 || '').'
					<input type="radio" name="position" value="debut"> Début 
					<input type="radio" name="position" value="fin" checked> Fin 
					<button type="button" class="btnform2 valid-tag" onclick="handleAddPage(this)">Ajouter</button>
					</div>
					<br>
					`;
				} else if (action === "delete") {
					deleteButton.className = "men men3 men3select";
					container.innerHTML = `
					<div class="flex-checkbox">
						<div style="width: 100%;" class="forms2_label">Choix des pages à supprimer (Exemple: 2,3,5-8) :</div>
					</div>
					<div>
						<label for="page-number">Numéros de page :</label>   
						<input style="width: 10%;" class="forms2_input" type="text" id="page-number" placeholder="Exemple: 2,3,5-8">
						<button type="button" class="btnform2 delete-tag" onclick="validateAndHandleDelete()">Supprimer</button>
					</div>
					<br>
					`;
				} else if (action === "move") {
						moveButton.className = "men men3 men3select";
						container.innerHTML = `
							<div class=flex-checkbox>
							<div style="width: 100%;" class="forms2_label">Choix de la page à déplacer :</div>
							</div>
							<div>
							<label for="move-from">Numéro de la page à déplacer:</label>   
							<input style="width: 10%;" class="forms2_input" type="number" id="move-from" min="1">
							<label for="move-to">Position cible:</label>
							<input style="width: 10%;" class="forms2_input" type="number" id="move-to" min="1">
							<button type="button" class="btnform2 valid-tag" onclick="handleMovePage(this)">Déplacer</button>
							</div>
							<br>
						`;
					} else if (action === "rotate") {
						rotateButton.className = "men men3 men3select";
						container.innerHTML = `
						<div class="flex-checkbox">
							<div style="width: 100%;" class="forms2_label">Choix des pages à pivoter :</div>
						</div>
						<div>
							<label for="rotate-page">Numéros de page :</label>
							<input style="width: 10%;" class="forms2_input" type="text" id="rotate-page">
							<label for="rotate-degree">Degrés de rotation:</label>
							<select style="width: 10%;" id="rotate-degree">
								<option value="90">90°</option>
								<option value="180">180°</option>
								<option value="270">270°</option>
							</select>
							<button type="button" class="btnform2 valid-tag" onclick="handleRotatePage()">Pivoter</button>
						</div>
						<br>`;
					}
				}
			
			function handleAddPage() {
				const fileInput = document.getElementById("docs_100"); // Récupère le champ de sélection
				const positionRadios = document.getElementsByName("position"); // Récupère tous les boutons radio pour la position
				let positionValue = "fin"; // Valeur par défaut si rien n\'est sélectionné

				// Parcourt les boutons radio pour récupérer la position sélectionnée
				for (let i = 0; i < positionRadios.length; i++) {
					if (positionRadios[i].checked) {
						positionValue = positionRadios[i].value; // Récupère la valeur de la position sélectionnée
					}
				}

				if (fileInput && fileInput.value) {
					// Construire l\'URL avec les paramètres nécessaires
					const baseHref = "docsentry?id_name=" + encodeURIComponent("' . $array_of_documents->[0]->{id_name} . '");
					const addHref = baseHref + 
						"&inserer_document=" + encodeURIComponent(fileInput.value) + 
						"&position=" + encodeURIComponent(positionValue); // Ajoute la position à l\'URL

					// Rediriger l\'utilisateur vers l\'URL générée
					window.location.href = addHref;
				} else {
					alert("Veuillez sélectionner un document.");
				}
			}

			function handleDeletePage() {
				const pageNumber = document.getElementById("page-number").value;
				if (pageNumber) {
					// Construire l\'URL avec les paramètres nécessaires
					const baseHref = "docsentry?id_name=" + encodeURIComponent("' . $array_of_documents->[0]->{id_name} . '"); // Utiliser l\'id_name du document
					const deleteHref = baseHref + "&supprimer_page=" + encodeURIComponent(pageNumber);
					// Rediriger l\'utilisateur vers l\'URL générée
					window.location.href = deleteHref;
				} else {
					alert("Veuillez entrer un numéro de page.");
				}
			}

			function handleMovePage() {
				const from = document.getElementById("move-from").value;
				const to = document.getElementById("move-to").value;
				if (from && to) {
					// Construire l\'URL avec les paramètres nécessaires
					const baseHref = "docsentry?id_name=" + encodeURIComponent("' . $array_of_documents->[0]->{id_name} . '"); // Utiliser l\'id_name du document
					const moveHref = baseHref + "&deplacer_page=" + encodeURIComponent(from) + "&to=" + encodeURIComponent(to) ;
					// Rediriger l\'utilisateur vers l\'URL générée
					window.location.href = moveHref;
				} else {
					alert("Veuillez entrer les numéros de pages.");
				}
			}
			
			// Fonction pour valider le format et exécuter l\'action de suppression
			function validateAndHandleDelete() {
				const input = document.getElementById("page-number").value.trim();
				const regex = /^(\d+(-\d+)?)(,(\d+(-\d+)?))*$/; // Chiffre, chiffre-chiffre ou liste séparée par virgules

				if (!regex.test(input)) {
					alert("Veuillez entrer un format valide : chiffres séparés par des virgules (Exemple : 2,3,5-8).");
					return;
				}

				// Appel de la fonction de suppression après validation
				handleDeletePage(input);
			}
			
			function handleRotatePage() {
				const pageInput = document.getElementById("rotate-page").value.trim();
				const degreeSelect = document.getElementById("rotate-degree").value;

				if (pageInput) {
					// Construire l\'URL avec les paramètres nécessaires
					const baseHref = "docsentry?id_name=" + encodeURIComponent("' . $array_of_documents->[0]->{id_name} . '");
					const rotateHref = baseHref + "&rotation=" + encodeURIComponent(pageInput) + "&angle=" + encodeURIComponent(degreeSelect);
					// Rediriger l\'utilisateur vers l\'URL générée
					window.location.href = rotateHref;
				} else {
					alert("Veuillez entrer les numéros de pages à pivoter.");
				}
			}
			</script>';
		
		}
	}

	$display_doc .= '
	<br><div class=centrer id=displaydoc>
		<iframe src="/Compta/base/documents/' . $r->pnotes('session')->{id_client} . '/' . $array_of_documents->[0]->{fiscal_year} . '/' . $array_of_documents->[0]->{id_name} . '?t=' . $timestamp . '"
			width="1280" 
			height="1280" 
			style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" 
			allowfullscreen>
		</iframe>
	</div>';

	return $display_doc;
	
}
	

1 ;
