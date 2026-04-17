package Base::Handler::entry ;
#-----------------------------------------------------------------------------------------
#Version 1.10 - Juillet 1th, 2022
#-----------------------------------------------------------------------------------------
#	
#	Modifié par picsou83 (https://github.com/picsou83)
#	
#-----------------------------------------------------------------------------------------
#Version initiale - Aôut 2016
#-----------------------------------------------------------------------------------------
#	Copyright ou © ou Copr.
#	Vincent Veyron - Aôut 2016 (https://github.com/picsou83)
#	vincent.veyron@libremen.org
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

use strict;  			# Utilisation stricte des variables
use warnings;  			# Activation des avertissements
use utf8;       		# Encodage UTF-8 pour le script
use Base::Site::util;   # Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;    # Interaction avec la base de données (SQL)
use Apache2::Const -compile => qw( OK REDIRECT ) ; # Importation de constantes Apache

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $req = Apache2::Request->new( $r ) ;
    my $content = '';
    my ($lien) = $r->dir_config('lien') ; 
    
    #récupérer les arguments
    my (%args, @args) ;

    #recherche des paramètres de la requête
    @args = $req->param ;

    for ( @args ) {

	$args{ $_ } = Encode::decode_utf8( $req->param($_) ) ;

	#les double-quotes et les <> viennent interférer avec le html
	$args{ $_ } =~ tr/<>"/'/ ;

    }

    #mois n'est pas toujours défini
    $args{mois} ||= 0 ;
    
    $r->no_cache(1) ;
    
	$content .= edit_entry( $r, \%args ) ;
    
    $r->content_type('text/html; charset=utf-8') ;
    print $content ;
    return Apache2::Const::OK ;

}

sub edit_entry {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    $args->{_token_id} ||= Base::Site::util::generate_unique_token_id($r, $dbh);
	my ( $sql, @bind_array, $content ) ;
	my @check = ('') x 10;
	my $redirect = 'journal?open_journal='.($args->{open_journal} || '').'';
	my $reffourn;
	
	################ Affichage MENU journal ################
	$content .= Base::Handler::journal::display_journal_set( $r, $args ) ;
	################ Affichage MENU journal################
	
	#Fonction pour générer le débogage des variables $args et $r->args si dump == 1  
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}


    #########################################	
	#définition des liens du menu			#
	#########################################	
    #lien de retour vers le journal
    my $return_href1 = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} ;
	my $return_link1 = '<a class=nav href="' . $return_href1 . '" style="margin-left: 3ch;">Retour journal</a>';
	#lien de retour vers la page précédente
	my $return_href2 = 'javascript:history.go(-1)';
	my $return_href3 ;
	my $return_link2 = '<a class=nav href="' . $return_href2 . '" style="margin-left: 3ch;">Retour arrière</a>';
	
	# si la requête provient du module docsentry
	if (defined $args->{docs} && ($args->{docs} ne '')) {
		$check[1] = '&amp;docs=' . $args->{docs} . '';
		$redirect = 'docsentry?id_name='.$args->{docs}.'';
	} 
	
	# si la requête provient d'une écriture récurrente		
	if (defined $args->{_token_id} && ($args->{_token_id} =~ /recurrent/)) {
		if (defined $args->{id_name} && $args->{id_name} ne '') {
			$check[4] = '&amp;id_name=' . $args->{id_name}.'';
			$return_href3 = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{id_name}.'&amp;ecriture_recurrente=' ; 
			$redirect = 'docsentry?id_name='.$args->{id_name}.'&amp;ecriture_recurrente=';
		} else {
			$return_href3 = '/'.$r->pnotes('session')->{racine}.'/menu?ecriture_recurrente' ;
			$redirect = 'menu?ecriture_recurrente';
		}
		$check[3] = '&amp;_token_id=' . $args->{_token_id}.'';
		#Afficher le lien retour écritures récurrentes si écritures récurrentes

	# si la requête provient d'une écriture import csv ocr qif		
	} elsif (defined $args->{_token_id} && ($args->{_token_id} =~ /csv/)) {
		if (defined $args->{id_name} && $args->{id_name} ne '') {
			$check[4] = '&amp;id_name=' . $args->{id_name}.'';
			$return_href3 = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{id_name}.'&amp;csv=' ; 
			$redirect = 'docsentry?id_name='.$args->{id_name}.'&amp;csv=';
		} else {
			$return_href3 = '/'.$r->pnotes('session')->{racine}.'/menu?menu10=1' ;
			$redirect = 'menu?menu10=1';
		}
		$check[3] = '&amp;_token_id=' . $args->{_token_id}.'';
		#Afficher le lien retour écritures récurrentes si écritures récurrentes
	}
	
	#/************ REDIRECTION SI MAUVAISE ENTREE DEBUT *************/
	
	# Empêcher si l'exercice est clos
	if ($r->pnotes('session')->{Exercice_Cloture} eq '1' && defined $args->{nouveau}) {
		return ($content .= Base::Site::util::bloquer_exercice_clos($r)) if Base::Site::util::bloquer_exercice_clos($r);
	}

	#Empêcher id_entry vide 
	if (!defined $args->{id_entry} || $args->{id_entry} eq ''){
		$content .= Base::Site::util::ref_existe_pas($r);
		return $content ;
	}
	
	#Requête tbljournal => Recherche présence de l'écriture
    $sql = 'SELECT id_entry, fiscal_year FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND id_entry = ?' ;
    my $array_of_identry = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{id_entry} ) ;
	
	#Empêcher id_entry vide ou existe pas
	if (!$array_of_identry->[0]->{id_entry} && $args->{id_entry} ne 0){
		$content .= Base::Site::util::ref_existe_pas($r);
		return $content ;

	#Empêcher id_entry0 si pas nouveau et si token_id non valide
	} elsif (!defined $args->{nouveau} && defined $args->{_token_id} && defined $args->{id_entry} && $args->{id_entry} eq 0){
		
		#Requête tbljournal => Recherche présence de donnée via id_entry 0 et _token_id
		$sql = 'SELECT _token_id FROM tbljournal_staging WHERE id_client = ? AND fiscal_year = ? AND id_entry = \'0\' AND _token_id = ?' ;
		my $array_of_identry0 = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  $args->{_token_id} ) ;
	
		if (!$array_of_identry0->[0]->{_token_id} ) {	
			$content .= Base::Site::util::ref_existe_pas($r);
			return $content ;
		}
	}
	
	#/************ REDIRECTION SI MAUVAISE ENTREE FIN *************/

	my $subtitle = ( $args->{id_entry} eq '0' ) ? 'Nouvelle entrée' : 'Édition d\'une entrée' ;
	
    #/************ ACTION DEBUT *************/
    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	if ( defined $args->{supprimer} && $args->{supprimer} eq '0') {
		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;redo=1&amp;_token_id=' . $args->{_token_id} . $check[1];
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/entry?supprimer=1&amp;id_entry=' . $args->{id_entry} . '&amp;open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . $check[1] . $check[3] . $check[4] ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer cette écriture ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>');
	} elsif ( defined $args->{supprimer} && $args->{supprimer} eq '1') {
		# Empêcher si l'exercice est clos
		if ($r->pnotes('session')->{Exercice_Cloture} eq '1') {
			return ($content .= Base::Site::util::bloquer_exercice_clos($r)) if Base::Site::util::bloquer_exercice_clos($r);
		}
		if (($args->{_token_id} =~ /recurrent/) || ($args->{_token_id} =~ /csv/)) {
			#demande de suppression confirmée 
			$sql = 'DELETE FROM tbljournal_staging WHERE id_client = ? and fiscal_year = ? and _token_id = ?' ;
			eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{_token_id} ) ) } ;
		} else {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tbljournal WHERE id_client = ? and fiscal_year = ? and id_entry = ?' ;
			eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{id_entry} ) ) } ;
			#Null value pour module ndf
			$sql = 'UPDATE tblndf SET piece_entry = NULL WHERE id_client = ? and fiscal_year = ? and piece_entry = ?' ;
			eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{id_entry} ) ) } ;
		}
			
		if ( $@ ) {
			my $message = ( $@ =~ /archived/ )? 'La date d\'écriture se trouve dans un mois archivé - Enregistrement impossible' : $@ ;
			$content .= '<h3 class=warning>' . $message . '</h3>' ;
		} else {
			#rediriger l'utilisateur vers la page d'accueil	
			my $location = '/'.$r->pnotes('session')->{racine}.'/'.$redirect.'' ; 
			$r->headers_out->set(Location => $location) ;
			#rediriger le navigateur vers le fichier
			$r->status(Apache2::Const::REDIRECT) ;
			return Apache2::Const::REDIRECT ; 	
		}
	}
	
	############################################################ 
	#l'utilisateur a cliqué sur le bouton 'Règlement'		   #
	############################################################ 
    if ( defined $args->{paiement} && $args->{paiement} eq '0') {
		
		$sql = 'SELECT id_line, numero_compte FROM tbljournal_staging WHERE _token_id = ? AND substring(numero_compte from 1 for 1) IN (\'4\') ORDER BY id_line' ;
		my $result_set = eval {$dbh->selectall_arrayref( $sql, { Slice =>{ } }, ( $args->{_token_id} ) ) };
		
		if (!$result_set->[0]->{numero_compte}) {
			$content .= '<h3 class=warning>Aucun comptes de tiers (classe 4) - Enregistrement d\'un réglement impossible !!</h3>' ;	
			undef $args->{paiement};
		} elsif (!defined $args->{select_achats} || (defined $args->{select_achats} && $args->{select_achats} eq '')){
			$content .= '<h3 class=warning>Le journal de paiement n\'est pas configuré - Enregistrement impossible</h3>' ;	
			undef $args->{paiement};
		} else {
			$sql = 'SELECT config_libelle, config_compte, config_journal, module FROM tblconfig_liste WHERE id_client = ? and config_libelle = ? AND module = \'achats\'' ;
			my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{select_achats} ) ) ;
			$args->{open_journal} = $resultat->[0]->{config_journal};
			
			my $reglement_journal = $resultat->[0]->{config_journal};
			my $reglement_compte = $resultat->[0]->{config_compte};

			$sql = 'DELETE FROM tbljournal_staging WHERE _token_id = ?' ;
			@bind_array = ( $args->{_token_id} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} 
	
			$sql = '
			INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_facture, libelle, documents1, documents2, debit, credit, lettrage, pointage, _token_id ) SELECT ?, 0, t1.id_client, t1.fiscal_year, ?::integer, ?, ?, ?, t1.numero_compte, t1.date_ecriture, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.credit, t1.debit, t1.lettrage, t1.pointage, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? AND substring(numero_compte from 1 for 1) IN (\'4\')
			UNION SELECT ?, 0, t1.id_client, t1.fiscal_year, ?::integer, ?::date, ?::date, ?, ?, t1.date_ecriture, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, t1.lettrage, t1.pointage, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? AND substring(numero_compte from 1 for 1) IN (\'4\')
			' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal, $args->{_token_id}, $args->{id_entry}, $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal, $reglement_compte, $args->{_token_id}, $args->{id_entry} ) ;
			$args->{id_entry} = 0 ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
				return $content ;
			} 
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'dupliquer' 					  #
	#######################################################################
	if ( defined $args->{dupliquer} and $args->{dupliquer} eq '0' ) {
		#1ère demande d'extourne, demander confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;redo=1&amp;_token_id=' . $args->{_token_id} ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;dupliquer=1&amp;_token_id=' . $args->{_token_id} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous dupliquer cette écriture ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>');
	} elsif ( defined $args->{dupliquer} and $args->{dupliquer} eq '1' ) {
		#demande de duplication confirmée
		$sql = 'UPDATE tbljournal_staging SET id_entry = 0, id_line = nextval(\'tbljournal_id_line_seq\'::regclass) WHERE _token_id = ?' ;
		@bind_array = ( $args->{_token_id} ) ;
		$args->{id_entry} = 0 ;	
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'extourner' 					  #
	#######################################################################
	if ( defined $args->{extourner} and $args->{extourner} eq '0' ) {
		#1ère demande d'extourne, demander confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;redo=1&amp;_token_id=' . $args->{_token_id} ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=OD&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;extourner=1&amp;_token_id=' . $args->{_token_id} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous extourner cette écriture ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>');
	} elsif( defined $args->{extourner} and $args->{extourner} eq '1' ) {
		$sql = 'UPDATE tbljournal_staging SET id_entry = 0, id_line = nextval(\'tbljournal_id_line_seq\'::regclass), libelle = \'extourne \' || libelle, libelle_journal = \'OD\', credit = debit, debit = credit WHERE _token_id = ?' ;
		@bind_array = ( $args->{_token_id} ) ;
		$args->{id_entry} = 0 ;	
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
    }
    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'déplacer' 					  #
	#######################################################################
	if ( defined $args->{deplacer} ) {
		if (!defined $args->{journal_select} || (defined $args->{journal_select} && $args->{journal_select} eq '')){
			$content .= Base::Site::util::generate_error_message('Veuillez sélectionner un journal - Enregistrement impossible');
			undef $args->{deplacer};
		} else {
			$args->{open_journal} = $args->{journal_select} ;
			$sql = 'UPDATE tbljournal_staging set libelle_journal = ? WHERE id_entry = ? AND _token_id = ?' ;
			@bind_array = ( $args->{journal_select}, $args->{id_entry}, $args->{_token_id} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} 
		}
	}
    
    ################################################################################# 
	#l'utilisateur a cliqué sur le lien '+' dans la dernière ligne du formulaire  	#
	#################################################################################
    if ( defined $args->{new_line} ) {
		#l'utilisateur a cliqué sur le lien '+' dans la dernière ligne du formulaire : ajouter une ligne; on utilise date_ecriture, id_paiement et id_facture en cours dans tbljournal_staging
		$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, libelle_journal, date_ecriture, id_paiement, id_facture, fiscal_year_offset, fiscal_year_start, fiscal_year_end, documents1, documents2, _token_id) SELECT ?, ?, ?, ?, ?, date_ecriture, id_paiement, id_facture, ?, fiscal_year_start, fiscal_year_end, documents1, documents2, ? FROM tbljournal_staging WHERE _token_id = ? GROUP BY date_ecriture, id_paiement, id_facture, fiscal_year_offset, fiscal_year_start, fiscal_year_end, documents1, documents2' ;
		@bind_array = ( $r->pnotes('session')->{_session_id}, $args->{id_entry}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{open_journal}, $r->pnotes('session')->{fiscal_year_offset}, $args->{_token_id}, $args->{_token_id} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} else {
		$args->{redo} = 1 ;
		}

    #################################################################################  
	#l'utilisateur a cliqué sur le lien  '-' en début de ligne  					#
	#################################################################################
    } elsif ( defined $args->{delete_line} ) {
		#l'utilisateur a cliqué sur le lien '-' en début de ligne : supprimer cette ligne
		$sql = 'DELETE FROM tbljournal_staging WHERE id_line = ?' ;
		@bind_array = ( $args->{delete_line} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} else {
		$args->{redo} = 1 ;
		}
	}
	
	############################# 
	#MAJ INSERT staging doc		#
	############################# 
	if ( defined $args->{maj_staging} and $args->{maj_staging} eq '1' ) {
		#update date de debut d'exercice si la valeur n'est pas renseignée
		$sql = 'UPDATE tbljournal_staging SET date_ecriture = ? where _token_id = ? AND date_ecriture IS NULL' ;
		@bind_array = ( $r->pnotes('session')->{Exercice_debut_YMD}, $args->{_token_id}) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
		
		#update le choix du document	
		$sql = 'UPDATE tbljournal_staging SET documents1 = ?, documents2 = ? WHERE _token_id = ?' ;
		@bind_array = ( ($args->{docs1} || undef), ($args->{docs2} || undef), $args->{_token_id} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
		$args->{redo} = 1 ;
	}
    
    ############################################################ 
	#l'utilisateur a cliqué sur 'Valider'					   #
	############################################################ 
    if ( defined $args->{validate_this} ) {
		
		# Empêcher si l'exercice est clos
		if ($r->pnotes('session')->{Exercice_Cloture} eq '1') {
			return ($content .= Base::Site::util::bloquer_exercice_clos($r));
		}
		
		#Requête tbljournal => Recherche présence de donnée _token_id dans tbljournal_staging
		$sql = 'SELECT _token_id FROM tbljournal_staging WHERE id_client = ? AND fiscal_year = ? AND _token_id = ?' ;
		my $array_of_token_id = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  $args->{_token_id} ) ;
		
		if (!$array_of_token_id->[0]->{_token_id} ) {	
			$content .= Base::Site::util::ref_existe_pas($r);
			return $content ;
		}

		my $dbh = $r->pnotes('dbh') ;
	
		#record_staging est la fonction postgres d'enregistrement des données de tbljournal_staging dans tbljournal
		#elle ne prend pas les lignes où debit = credit = 0
		#elle insère les nouvelles données, en remplaçant les anciennes dans le cas d'une modification
		#elle vide tbljournal_staging si l'opération s'est bien passée
		my ($return_identry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $args->{_token_id}, $args->{id_entry});
	
		#erreur dans la procédure store_staging : l'afficher dans le navigateur
		if ( $error_message ) {
			$content .= Base::Site::util::generate_error_message($error_message);
			$args->{redo} = 1 ;	
		} else {
			my $location;
			if ($args->{id_entry} ne 0) {
				#les modifications de tbljournal_staging sont passées dans tbljournal; rediriger vers le journal
				$location = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&mois=' . $args->{mois}.'&id_entry='.$args->{id_entry} ;
				#Pour les écritures récurrentes rediriger vers le menu
			} elsif ($args->{_token_id} =~ /recurrent/) {
				if (defined $args->{id_name} && $args->{id_name} ne '') {
					$location = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{id_name}.'&amp;ecriture_recurrente=' ; 
				} else {
					$location = '/'.$r->pnotes('session')->{racine}.'/menu?ecriture_recurrente' ;
				}
			} elsif ($args->{_token_id} =~ /csv/) {
				if (defined $args->{id_name} && $args->{id_name} ne '') {
					$location = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{id_name}.'&amp;csv=' ; 
				} else {
					$location = '/'.$r->pnotes('session')->{racine}.'/menu?menu10=1' ;
				}
			} else {
				$location = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&mois=' . $args->{mois} ;
			}
		
			$r->headers_out->set(Location => $location) ;
			#rediriger le navigateur vers le fichier
			$r->status(Apache2::Const::REDIRECT) ;
	        return Apache2::Const::REDIRECT ;
		}

	############################################################ 
	#l'utilisateur a cliqué sur 'Nouveau'					   #
	############################################################ 
	# $args->{id_entry} eq '0'concerne une nouvelle entrée	
	#insérer les données de l'entrée dans tbljournal_staging
	#si $args->{id_entry} eq '0' et $args->{nouveau}, nouvelle entrée, préparer un enregistrement vierge
	#on crée trois lignes pour les journaux de type Fournisseurs ou Ventes, 2 lignes pour les autres
	} elsif ( defined $args->{id_entry} && $args->{id_entry} eq '0' && defined $args->{nouveau} ) { 
		#Récupérations des informations de la société
		$sql = 'SELECT id_tva_regime FROM compta_client WHERE id_client = ?' ;
		my $parametre_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
			
		#nouvelle entrée d'un journal Fourn ou Ventes qui n'est pas en franchise de TVA
		if ( not($parametre_set->[0]->{id_tva_regime} eq 'franchise') && ($args->{open_journal} =~ /^Fourn|Ventes|ACHAT|VENTE/ )) {
		
			if ((defined $args->{docs1}) && (defined $args->{docs2})) {	
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $args->{docs2}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $args->{docs2}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $args->{docs2} ) ;
			} elsif (defined $args->{docs1}) {
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1} ) ;
			} elsif (defined $args->{docs2}) { 
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs2}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs2} ) ;
			} else {
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id} ) ;
			}
			
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} else {$args->{redo} = 1 ;}
				
		#nouvelle entrée des autres journaux	
		} else {
			
			if ((defined $args->{docs1}) && (defined $args->{docs2})) {	
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $args->{docs2}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $args->{docs2} ) ;
			} elsif (defined $args->{docs1}) {
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs1} ) ;
			} elsif (defined $args->{docs2}) { 
				$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?, ?)' ;
				@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs2}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $args->{docs2} ) ;
			} else {
			$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ? ,?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id}, $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{open_journal}, $args->{_token_id} ) ;
			}
			
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} else {$args->{redo} = 1 ;}
		}

	#si $args->{redo} existe, l'utilisateur a cliqué sur 'Valider', mais record_staging a avorté; 
	#dans ce cas on préserve les modifications; sinon on efface tbljournal_staging et on le renseigne à nouveau
	} elsif ( !defined $args->{redo} ) {
		
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'entry.pm => id_entry : '.$args->{id_entry}.' et _token_id : '.$args->{_token_id}.'');
		
		################################################################################# 
		# $args->{id_entry} > '0'concerne une entrée existante			 				#
		#################################################################################
		#modification d'une entrée existante; récupérer les données dans tbljournal et les placer dans tbljournal_staging
		#on insère dans l'ordre d'enregistrement pour préserver la présentation préférée de l'utilisateur
		$sql = '
		INSERT INTO tbljournal_staging (_session_id, id_entry, id_line, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, id_export, lettrage, pointage, recurrent, _token_id ) SELECT ?, t1.id_entry, t1.id_line, t1.id_client, t1.fiscal_year, ?, ?, ?, t1.libelle_journal, t1.numero_compte, t1.date_ecriture, t1.id_paiement, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, t1.id_export, t1.lettrage, t1.pointage, t1.recurrent, ?
		FROM tbljournal t1 
		WHERE t1.id_entry = ? AND t1.fiscal_year = ? ORDER BY id_line
		' ;
		@bind_array = ( $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{_token_id}, $args->{id_entry}, $r->pnotes('session')->{fiscal_year} ) ;
			
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
	}
	
    #########################################	
	#génération du menu						#
	#########################################
    $content .= '
		<div class="wrapper-entry">
    	<fieldset class=pretty-box>
    	<legend style="display: flex; align-items:center; ">
    	<a class="Titre09 decoff" class=nav href="' . $return_href1 . '" >
		<h2 title="Retour journal ' . URI::Escape::uri_escape_utf8( ($args->{open_journal} || '') ) . '" >Journal : ' . ($args->{open_journal} || '') . '
		</a></h2>
		<a title="Retour arrière" class="aperso" href="' . $return_href2 . '">#retour</a>
    	</legend>
		<div class=centrer>
		
		<div class=Titre10>' . $subtitle . '</div>
	';

    #################################################################################  
	#Suite d'entry 												  					#
	#################################################################################
    
	################################################################# 
	# update des champs documents 1 et 2 			 				#
	#################################################################
    $sql = '
	SELECT t1.id_line, t1.documents1, t1.documents2
	FROM tbljournal_staging t1 
	WHERE t1._token_id = ? 
	ORDER BY id_line
	' ;
    
    my $result_set_doc = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, ( $args->{_token_id} ) ) ;

     
		my $vardoc1 = undef;
		my $vardoc2 = undef;

		if ($args->{id_entry} != '0') { 
			
			if (not(defined $args->{docs1})) {
			if (not(defined $result_set_doc->[0]->{documents1} )) {
			} else {
			$vardoc1 = $result_set_doc->[0]->{documents1};	
			}} else {
			$vardoc1 = $args->{docs1};	
			}

			if (not(defined $args->{docs2})) {
			if (not(defined $result_set_doc->[0]->{documents2} )) {
			} else {
			$vardoc2 = $result_set_doc->[0]->{documents2};	
			}} else {
			$vardoc2 = $args->{docs2};	
			}

	#update docs
	$sql = 'UPDATE tbljournal_staging SET documents1 = ?, documents2 = ? WHERE _token_id = ? and id_line = ?' ;
	@bind_array = ( $vardoc1, $vardoc2, $args->{_token_id}, $args->{id_line} ) ;
	$dbh->do( $sql, { Slice =>{ } }, @bind_array ) ;
		} 
	
	################################################################# 
	# affichage de  tbljournal_staging				 				#
	#################################################################
	
    #récupérer les données de tbljournal_staging dans l'ordre de row_number pour un affichage correct
    $sql = '
	SELECT t1.id_line, date_ecriture, t1.id_paiement, t1.numero_compte, t1.id_facture, t1.libelle, t1.libelle_journal, t1.documents1, t1.documents2, t1.debit/100::numeric as debit, t1.credit/100::numeric as credit, row_number() over ( ORDER BY id_line ) as row_number, (sum(debit) over ())/100::numeric as total_debit, (sum(credit) over ())/100::numeric as total_credit, id_export
	FROM tbljournal_staging t1 
	WHERE t1._token_id = ? 
	ORDER BY id_line
	' ;
    my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, ( $args->{_token_id} ) ) ;
  
	$sql = 'SELECT id_client FROM tbllocked_month 
	WHERE id_client = ? and ( id_month = to_char(?::date, \'MM\') ) AND fiscal_year = ?';
	@bind_array = ( $r->pnotes('session')->{id_client}, $result_set->[0]->{date_ecriture}, $r->pnotes('session')->{fiscal_year}) ;
	my $result_block = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
	
	my $do_not_edit;
	
	if (defined $result_set->[0]->{id_export} && $result_set->[0]->{id_export} ne 'null') {
		$do_not_edit = 1;
	} else {
		$do_not_edit = 0;	
	}	
	
	if (defined $result_block && $result_block eq $r->pnotes('session')->{id_client}) {
		$do_not_edit = 2;
	}
		
	#on ne doit pas déplacer des écritures dans CLOTURE pour ne pas perturber les états grand livre et balance
	my $do_not_move = ( $result_set->[0]->{libelle_journal} eq 'CLOTURE' ) ? 1 : 0 ;
	
    #ligne des en-têtes
    my $entry_table = '
<li class="style1">   
<div class=flex-table><div class=spacer></div>
<span class=headerspan style="width: 2%;">&nbsp;</span>
<span class=headerspan style="width: 6%;">Date</span>
<span class=headerspan style="width: 6%;">Libre</span>
<span class=headerspan style="width: 6%;">Compte</span>
<span class=headerspan style="width: 9%;">Pièce</span>
<span class=headerspan style="width: 20%;">Libellé</span>
<span class=headerspan style="width: 7%; text-align: right;">Débit</span>
<span class=headerspan style="width: 7%; text-align: right;">Crédit</span>
<span class=headerspan style="width: 16.5%; text-align: center;">Documents 1</span>
<span class=headerspan style="width: 16.5%; text-align: center;">Documents 2</span>
<span class=headerspan style="width: 2%;">&nbsp;</span>
<span class=headerspan style="width: 1.8%;">&nbsp;</span>
<div class=spacer></div></div></li>
' ;

    #variable de stockage du numero de chaque ligne pour la suivante
    my $previous_line_number = 0 ;

    for ( @$result_set ) {
	
	#joli formatage de débit/crédit
	( my $debit = sprintf( "%.2f", $_->{debit} ) ) =~ s/\B(?=(...)*$)/ /g ;

	( my $credit = sprintf( "%.2f", $_->{credit} ) ) =~ s/\B(?=(...)*$)/ /g ;

	my ( $plus_link, $minus_link ) = ( '', '<a href="" style="text-decoration: none; margin-right: .5em; font-size: larger;" tabindex="-1">&nbsp;</a>' ) ;
	
	#sur toutes les lignes après la deuxième ligne, ajouter le lien '-'
	if ( $_->{row_number} > 2 ) {
	    
	    my $minus_link_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;delete_line=' . $_->{id_line} . '&amp;_token_id=' . $args->{_token_id};

	    $minus_link = '<a class=nav href="' . $minus_link_href . '" style="text-decoration: none; margin-right: .5em; font-size: larger;" title="Supprimer la ligne">-</a>' ;
	    		
	} #	if ( $_->{row_number} > 2 ) 

	#modifié pour la dernière ligne, dans le cas ( defined $args->{new_line} )
	my $numero_compte_autofocus = '' ;
	
	#on veut ajouter le lien '+' sur la dernière ligne
	if ( $_->{row_number} == ( @$result_set ) ) {
	    
	    my $plus_link_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;new_line=0&amp;_token_id=' . $args->{_token_id} ;

	    $plus_link = '<a class=nav href="' . $plus_link_href . '" style="text-decoration: none; margin-left: .5em; font-size: larger;" title="Ajouter une ligne">+</a>' ;

	    #place l'autofocus sur l'input numero_compte de la dernière ligne quand l'utilisateur a cliqué sur '+'
	    $numero_compte_autofocus = ' autofocus' if ( defined $args->{new_line} ) ;
	    
	} #	if ( $_->{row_number} == $last_line ) 
	
	#fonction de copie du contrôle de la ligne précédente pour libellé; insérer à partir de la 2ème ligne
	my $copy_previous_input = ( $_->{row_number} > 1 ) ? ' oninput="copy_previous_input(this, ' . $previous_line_number . ')" placeholder=&rarr;' : '' ;

	#date écriture modifiable sur la 1ère ligne; on recopie la valeur sur les lignes suivantes; l'autofocus est mis sauf si $args->{new_line} existe
	my $autofocus = ( defined $args->{new_line} ) ? '' : ' autofocus' ;
	
	my $date_ecriture_is_active = ( $_->{row_number} > 1 ) ? ' disabled' : ' onblur=verifdt(this) onchange=verifdt(this) ' . $autofocus ;
	
	my $date_ecriture = '<input style="width: 100%;" type=text name="date_ecriture" id="date_ecriture_' . $_->{id_line} . '" value="' . ( $_->{date_ecriture} || '' ) . '" ' . $date_ecriture_is_active . '>' ;

	#facture modifiable sur la 1ère ligne; on recopie la valeur sur les lignes suivantes
	my $facture_is_active = ( $_->{row_number} > 1 ) ? 'disabled' : 'onchange="stage(this)"' ;

	#option de calcul du numero de piece sur la première ligne
	my $calculer_id_facture = ( $_->{row_number} == 1 ) ? 'oninput="calculer_id_facture(this, \'' . ($args->{open_journal} || '') . '\')" placeholder=&rarr;' : '' ;

	my $facture = '<input style="width: 100%;" type=text name="id_facture" id="id_facture_' . $_->{id_line} . '" value="' . ( $_->{id_facture} || '' ) . '"' . $facture_is_active . $calculer_id_facture . '>' ;
	
	#pour un journal de type 'Banque', ajouter la colonne id_paiement; modifiable en 1ère ligne, valeur recopier lignes suivantes
	my $id_paiement_is_active = ( $_->{row_number} > 1 ) ? 'disabled' : 'onchange="stage(this)"' ;
	
	#option de sélection nom du docs sur la première ligne
	my $select_name_docs = ( $_->{row_number} == 1 ) ? 'oninput="renseigner_doc(this.value, ' . $_->{id_line} . ')" list="doclist_' . $_->{id_line} . '" ' : '' ;
	
	#option de sélection libre id_paiement sur la première ligne
	my $select_libre_name = ( $_->{row_number} == 1 ) ? 'oninput="renseigner_libre(this.value, ' . $_->{id_line} . ')" list="librelist_' . $_->{id_line} . '" ' : '' ;
	
	#ligne modifiable sur la 1ère ligne; on recopie la valeur sur les lignes suivantes
	my $ligne_is_active = ( $_->{row_number} > 1 ) ? 'disabled' : ' onchange="stage(this)"' ;
	
	# affiche l'intitulé du compte dans une bulle
	$sql = 'SELECT libelle_compte FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND numero_compte like ? ORDER BY 1 DESC LIMIT 1';
	my $libelle_compte_set = $dbh->selectall_arrayref(  $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $_->{numero_compte} ) ) ;


#<span class=displayspan style="width: 20%;"><input style="width: 100%;" type=text onkeyup="verif(this);" name="libelle" id="libelle_' . $_->{id_line} . '" value="' . ( $_->{libelle} || '' ) . '" ' . $ligne_is_active . '></span>
	
	if ( defined $do_not_edit && ($do_not_edit eq 1|| $do_not_edit eq 2) ) {
		$entry_table .= '
		<li class="style1">  
		<div class=flex-table><div class=spacer></div>
		<span class=displayspan style="width: 2%;">&nbsp;</span>
		<span class=displayspan style="width: 6%;"><input style="width: 100%;" type=text name="date_ecriture" id="date_ecriture_' . $_->{id_line} . '" value="' . ( $_->{date_ecriture} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 6%;"><input style="width: 100%;" type=text name="id_paiement" id="id_paiement_' . $_->{id_line} . '" value="' . ( $_->{id_paiement} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 6%;"><input style="width: 100%;" title="'. ($libelle_compte_set->[0]->{libelle_compte} || '') .'" type=text name="numero_compte_' . $_->{id_line} . '" id="numero_compte_' . $_->{id_line} . '" value="' . ( $_->{numero_compte} || '') . '" disabled></span>
		<span class=displayspan style="width: 9%;"><input style="width: 100%;" type=text name="id_facture" id="id_facture_' . $_->{id_line} . '" value="' . ( $_->{id_facture} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 20%;"><input style="width: 100%;" type=text name="libelle" id="libelle_' . $_->{id_line} . '" value="' . ( $_->{libelle} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 7%;"><input style="width: 100%; text-align: right;" type=text name="debit" id="debit_' . $_->{id_line} . '" value="' . $debit . '" disabled></span>
		<span class=displayspan style="width: 7%;"><input style="width: 100%; text-align: right;" type=text name="credit" id="credit_' . $_->{id_line} . '" value="' . $credit . '"  disabled></span>
		<span class=displayspan style="width: 16.5%;"><input style="width: 100%;" type=text name="documents1" id="documents1_' . $_->{id_line} . '" value="' . ( $_->{documents1} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 16.5%;"><input style="width: 100%;" type=text name="documents2" id="documents2_' . $_->{id_line} . '" value="' . ( $_->{documents2} || '' ) . '" disabled></span>
		<span class=displayspan style="width: 2%;">&nbsp;</span>
		<div class=spacer></div></div></li>
		' ;	
	} else {
		$entry_table .= '
		<li class="style1">  
		<div class=flex-table><div class=spacer></div>
		<span class=displayspan style="width: 2%;">' . $minus_link . '</span>
		<span class=displayspan style="width: 6%;">' . $date_ecriture . '</span>
		<span class=displayspan style="width: 6%;"><input style="width: 100%;" type=text name="id_paiement" id="id_paiement_' . $_->{id_line} . '" value="' . ( $_->{id_paiement} || '' ) . '" ' . $ligne_is_active . $select_libre_name . '><datalist id="librelist_' . $_->{id_line} . '"></datalist></span>
		<span class=displayspan style="width: 6%;"><input style="width: 100%;" title="'. ($libelle_compte_set->[0]->{libelle_compte} || '') .'" type=text name="numero_compte_' . $_->{id_line} . '" id="numero_compte_' . $_->{id_line} . '" list="datalist_compte_' . $_->{id_line} . '" value="' . ( $_->{numero_compte} || '') . '" oninput="renseigner_compte(this.value, ' . $_->{id_line} . ')" onchange="stage(this)"' . $numero_compte_autofocus . ' required><datalist id="datalist_compte_' . $_->{id_line} . '"></datalist></span>
		<span class=displayspan style="width: 9%;">' . $facture . '</span>
		<span class=displayspan style="width: 20%;"><input style="width: 100%;" type=text name="libelle" id="libelle_' . $_->{id_line} . '" value="' . ( $_->{libelle} || '' ) . '" ' . $copy_previous_input . ' onchange="stage(this)" required></span>
		<span class=displayspan style="width: 7%;"><input style="width: 100%; text-align: right;" type=text name="debit" id="debit_' . $_->{id_line} . '" value="' . $debit . '" onchange="format_and_stage(this)"></span>
		<span class=displayspan style="width: 7%;"><input style="width: 100%; text-align: right;" type=text name="credit" id="credit_' . $_->{id_line} . '" value="' . $credit . '"  onchange="format_and_stage(this)"></span>
		<span class=displayspan style="width: 16.5%;"><input style="width: 100%;" type=text name="documents1" id="documents1_' . $_->{id_line} . '" value="' . ( $_->{documents1} || '' ) . '" ' . $ligne_is_active . $select_name_docs . '><datalist id="doclist_' . $_->{id_line} . '"></datalist></span>
		<span class=displayspan style="width: 16.5%;"><input style="width: 100%;" type=text name="documents2" id="documents2_' . $_->{id_line} . '" value="' . ( $_->{documents2} || '' ) . '" ' . $ligne_is_active . $select_name_docs . '></span>
		<span class=displayspan style="width: 2%;">' . $plus_link . '</span>
		<div class=spacer></div></div></li>
		' ;	
	}


	#stocker le numero de la ligne en cours pour permettre une copie javascript de sa valeur par la ligne suivante
	$previous_line_number = $_->{id_line} ;
	
    } #    for ( @$result_set )

    ( my $total_debit = sprintf( "%.2f", $result_set->[0]->{total_debit} || 0) ) =~ s/\B(?=(...)*$)/ /g ;

    ( my $total_credit = sprintf( "%.2f", $result_set->[0]->{total_credit} || 0) ) =~ s/\B(?=(...)*$)/ /g ;
    
     my $total_line =  '<li class="style1"><div class=flex-table><div class=spacer></div>
<span class=displayspan style="width: 2%;">&nbsp;</span>
<span class=displayspan style="width: 6%;">&nbsp;</span>
<span class=displayspan style="width: 6%;">&nbsp;</span>
<span class=displayspan style="width: 6%;">&nbsp;</span>
<span class=displayspan style="width: 9%;">&nbsp;</span>
<span class=displayspan style="width: 20%; text-align: right; padding-right: 2%;">Total</span>
<span class=displayspan style="width: 7%; "><input style="width: 100%; text-align: right;" id="total_debit" value="' . $total_debit . '" disabled></span>
<span class=displayspan style="width: 7%; "><input style="width: 100%; text-align: right;" id="total_credit" value="' . $total_credit . '" disabled></span>
<div class=spacer></div></div></li>' ;
    

    my $solde_line =  '<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 2%;">&nbsp;</span>
	<span class=displayspan style="width: 6%;">&nbsp;</span>
	<span class=displayspan style="width: 6%;">&nbsp;</span>
	<span class=displayspan style="width: 6%;">&nbsp;</span>
	<span class=displayspan style="width: 9%;">&nbsp;</span>
	<span class=displayspan style="width: 20%; text-align: right; padding-right: 2%;">Solde (crédit - débit)</span>
	<span class=displayspan style="width: 7%; ">&nbsp;</span>
	<span class=displayspan style="width: 7%; "><input style="width: 100%; text-align: right;" id="total_solde" value="0.00" disabled></span>
	<div class=spacer></div></div></li>' ;

	my $ligne_espace = '<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 100%;">&nbsp;</span>
	<div class=spacer></div></div></li>' ;

    $entry_table .= $total_line . $solde_line . $ligne_espace ;
    
    ################################################################# 
	# affichage des documents						 				#
	#################################################################
	
		#lien d'ouverture des documents 
		my $affiche_docs1 = '&nbsp';
		my $affiche_docs2 = '&nbsp';
		my $http_link_documents1 = undef ;
		my $http_link_documents2 = undef ;
		my $temp_docs1 = '';
		my $temp_docs2 = '';
		
		
	
		if (not(defined $args->{docs1})) {
		if (not(defined $result_set->[0]->{documents1} )) {
			$args->{docs1} = undef ;
			$http_link_documents1 = '&nbsp;' ;
		} else {
			$args->{docs1} =  $result_set->[0]->{documents1};
			my $info_doc = Base::Site::bdd::get_info_doc($dbh, $r->pnotes('session')->{id_client}, $args->{docs1});
			if (not defined $info_doc) {
				# Document non trouvé en base de données
				$http_link_documents1 = '';
				$affiche_docs1 = '<p class="warning">Le document « '.$args->{docs1}.' » est introuvable.<br> Veuillez vérifier et corriger la valeur du document 1.</p>';
				$temp_docs1 = '';
			} else {
				$http_link_documents1 ='<a class=nav style="margin-left: 0ch;" tabindex="-1" href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$result_set->[0]->{documents1}.'">Ouvrir Doc</a>' ;
				$sql = 'SELECT id_name, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?' ;
				my $documents1_fiscal_year = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{docs1} ) ;
				$affiche_docs1 = '<iframe src="/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$documents1_fiscal_year->[0]->{fiscal_year} .'/'.$result_set->[0]->{documents1}.'" width="900" height="1200" style="border:1px solid #CCC; border-width:1px; margin-bottom:1px; max-width: 100%; " allowfullscreen></iframe>';
				$temp_docs1 = '<input type=hidden name=docs1 value="'.$args->{docs1}.'">';
			}
		}} elsif (not($args->{docs1} eq '')) {
			$sql = 'SELECT id_name, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?' ;
			my $documents1_fiscal_year = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{docs1} ) ;
			$http_link_documents1 ='<a class=nav style="margin-left: 0ch;" tabindex="-1" href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{docs1}.'">Ouvrir Doc</a>' ;
			$affiche_docs1 = '<iframe src="/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$documents1_fiscal_year->[0]->{fiscal_year} .'/'.$args->{docs1}.'" width="900" height="1200" style="border:1px solid #CCC; border-width:1px; margin-bottom:1px; max-width: 100%; " allowfullscreen></iframe>';
			$temp_docs1 = '<input type=hidden name=docs1 value="'.$args->{docs1}.'">';
		}
			
		if (not(defined $args->{docs2}) ) {
		if (not(defined $result_set->[0]->{documents2} )) {
			$args->{docs2} = undef ;
			$http_link_documents2 = '&nbsp;' ;
		} else {
			$args->{docs2} =  $result_set->[0]->{documents2};
			my $info_doc = Base::Site::bdd::get_info_doc($dbh, $r->pnotes('session')->{id_client}, $args->{docs2});
			if (not defined $info_doc) {
				# Document non trouvé en base de données
				$http_link_documents2 = '';
				$affiche_docs2 = '<p class="warning">Le document « '.$args->{docs2}.' » est introuvable.<br> Veuillez vérifier et corriger la valeur du document 2.</p>';
				$temp_docs2 = '';
			} else {
				$http_link_documents2 ='<a class=nav style="margin-left: 0ch;" tabindex="-1" href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$result_set->[0]->{documents2}.'">Ouvrir Doc</a>' ;
				$sql = 'SELECT id_name, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?' ;
				my $documents2_fiscal_year = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{docs2} ) ;
				$affiche_docs2 = '<iframe src="/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$documents2_fiscal_year->[0]->{fiscal_year} .'/'.$result_set->[0]->{documents2}.'" width="900" height="1200" style="border:1px solid #CCC; border-width:1px; margin-bottom:1px; max-width: 100%; " allowfullscreen></iframe>';
				$temp_docs2 = '<input type=hidden name=docs2 value="'.$args->{docs2}.'" >';
			}
		}} elsif (not($args->{docs2} eq '')) {
			$sql = 'SELECT id_name, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?' ;
			my $documents2_fiscal_year = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{docs2} ) ;
			$http_link_documents2 ='<a class=nav style="margin-left: 0ch;" tabindex="-1" href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$args->{docs2}.'">Ouvrir Doc</a>' ;
			$affiche_docs2 = '<iframe src="/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$documents2_fiscal_year->[0]->{fiscal_year} .'/'.$args->{docs2}.'" width="900" height="1200" style="border:1px solid #CCC; border-width:1px; margin-bottom:1px; max-width: 100%; " allowfullscreen></iframe>';
			$temp_docs2 = '<input type=hidden name=docs2 value="'.$args->{docs2}.'" >';
   		}
    
    
    
    ################################################################# 
	# définition des liens des boutons actions		 				#
	#################################################################

    #lien vers Extourner
    my $extourne_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;extourner=0&amp;redo=1&amp;_token_id=' . $args->{_token_id} ;
    my $extourne_link = ( $args->{id_entry} eq '0' ) ? '&nbsp;' : '<a class=nav href="' . $extourne_href . '" tabindex="-1">Extourner</a>' ;

    #lien vers Dupliquer
    my $duplicate_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;dupliquer=0&amp;redo=1&amp;_token_id=' . $args->{_token_id} ;
    my $duplicate_link = ( $args->{id_entry} eq '0' ) ? '&nbsp;' : '<a class=nav href="' . $duplicate_href . '" tabindex="-1">Dupliquer</a>' ;

    #lien de suppression
    my $delete_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} . '&amp;supprimer=0&amp;redo=1&amp;_token_id=' . $args->{_token_id} . $check[1] . $check[4];
    my $delete_link =  ( $args->{id_entry} eq '0' && $args->{_token_id} !~ /recurrent|ocr/ ) ? '&nbsp;' : '<a class=nav href="' . $delete_href . '" tabindex="-1" style="margin-left: 3ch;">Supprimer</a>' ;
    
	###Formulaire de déplacement
	##Requête tbljournal_liste pour formulaire déplacement journal
	$sql = 'SELECT libelle_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? AND libelle_journal not like ? ORDER by libelle_journal' ;
    my $journal_set = $dbh->selectall_arrayref($sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{open_journal} ) ) ;
	my $journal_select = '<select style="width: 75%;" name=journal_select id=journal_select>
	<option value="" selected>--Déplacer--</option>' ;
	for ( @$journal_set ) {
	$journal_select .= '<option value="' . $_->[0] . '">' . $_->[0] . '</option>' ;
	}
	$journal_select .= '</select>' ;
	my $journal_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} .' &amp;deplacer=0&amp;redo=1&amp;_token_id=' . $args->{_token_id};
	my $journal_link = '&nbsp;' ; 
	if ( $args->{id_entry} ne '0' || defined $args->{deplacer} ) {
		$journal_link = ''.$journal_select.'<input type="submit" class="btnform2 vert" formaction="'. $journal_href . '" value="OK">';	
	}
	
	###Formulaire d'enregistrement d'un paiement
	##Requête tblconfig_liste => Choix Réglement
    $sql = 'SELECT config_libelle, config_compte, config_journal, module FROM tblconfig_liste WHERE id_client = ? AND module = \'achats\' ORDER by config_libelle ' ;
    my $resultat_tblconfig = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
    #select_achats
	my $select_achats = '<select name=select_achats id=select_achats>' ;
	$select_achats .= '<option value="" selected>--Choix Réglement--</option>' ;
	for ( @$resultat_tblconfig ) {
	$select_achats .= '<option value="' . $_->{config_libelle} . '">' . $_->{config_libelle} . '</option>' ;
	}
	$select_achats .= '</select>' ;
	my $paiement_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $args->{id_entry} .' &amp;paiement=0&amp;redo=1&amp;_token_id=' . $args->{_token_id};
    my $paiement_link = '&nbsp;' ;
    if ( $args->{open_journal} =~ /^Fourn|Ventes|ACHAT|VENTE/ and $args->{id_entry} ne '0' ) {
		$paiement_link = ''.$select_achats.'<input type="submit" class="btnform2 vert" 	formaction="'. $paiement_href . '" value="OK">';
    }

	#Requête écriture récurrente
	my ( $recurrent_href, $recurrent_link, $recurrent_input, $recurrent_base ) ;
	$sql = '
	SELECT t1.id_entry, t1.recurrent
	FROM tbljournal t1
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND id_entry = ?
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{id_entry} ) ;
	my $result_recurrent_id = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
	
	
    my $pointagerec = '&nbsp;' ;
	$recurrent_base = '<input type=checkbox id=id value=value style="vertical-align: middle;" title="écriture récurrente" onclick="pointagerecurrent(this, \'' . ($args->{_token_id}). '\', \'' . ($args->{id_entry}). '\')">' ;
	my $recurrent_id = 'id=recurrent_' . $args->{id_entry} ;
	( $recurrent_input = $recurrent_base ) =~ s/id=id/$recurrent_id/ ;
	my $recurrent_value = ( ($result_recurrent_id->[0]->{recurrent} || '') eq 't') ? 'checked' : '' ;
	$recurrent_input =~ s/value=value/$recurrent_value/ ;
	$pointagerec = $recurrent_input ;
	
    ################################################################# 
	# Régles d'affichage des boutons actions		 				#
	#################################################################
    
    #si l'écriture a été exportée, elle n'est pas modifiable : submit line sans bouton Valider
    my $submit_line ;

    if ( defined $do_not_edit && $do_not_edit eq 1 ) {
		
$submit_line = '
<div class="flex-table submit"><div class=spacer></div>
<span class=displayspan style="width: 0.1%;">&nbsp;</span>
<span class=displayspan style="width: 7%; text-align: center;">' . $extourne_link . '</span>
<span class=displayspan style="width: 7%; text-align: center;">' . $duplicate_link . '</span>
<span class=displayspan style="width: 15%; text-align: center;">' . $paiement_link . '</span>
<span class=displayspan style="width: 35%; text-align: center; color: red; font-weight : bold;">Enregistrement exporté - Non modifiable</span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;') . '</span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;') . '</span>
<div class=spacer></div></div>' ;

    } elsif ( defined $do_not_edit && $do_not_edit eq 2) {
    
    	$submit_line = '
<div class="flex-table submit"><div class=spacer></div>
<span class=displayspan style="width: 2%;">&nbsp;</span>
<span class=displayspan style="width: 10%; text-align: center;">&nbsp;</span>
<span class=displayspan style="width: 17%; text-align: center;">&nbsp;</span>
<span class=displayspan style="width: 35%; text-align: center; color: red; font-weight : bold;">Enregistrement exporté - Non modifiable</span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;'). '</span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;'). '</span>
<div class=spacer></div></div>' ;	
    
    } elsif ( defined $do_not_move && $do_not_move eq 1) {

$submit_line = '
<div class="flex-table submit"><div class=spacer></div>
<span class=displayspan style="width: 0.1%;">&nbsp;</span>
<span class=displayspan style="width: 10%; text-align: center;">' . $extourne_link . '</span>
<span class=displayspan style="width: 10%; text-align: center;">' . $duplicate_link . '</span>
<span class=displayspan style="width: 10%; text-align: center;">' . $delete_link . '</span>
<span class=displayspan style="width: 20%;">&nbsp;</span>
<span class=displayspan style="width: 6%; text-align: center;">&nbsp;</span>
<span class=displayspan style="width: 7%; text-align: right;"><input type=submit name="validate_this" id="validate_this" value="Valider"></span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;') . '</span>
<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;') . '</span>
<div class=spacer></div></div>' ;

	} elsif (defined $args->{_token_id} && $args->{_token_id} =~ /recurrent|ocr/) {
		
	$submit_line = '
	<div class="flex-table submit"><div class=spacer></div>
	<span class=displayspan style="width: 11%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 18%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 20%; text-align: center;">' . $delete_link . '</span>
	<span class=displayspan style="width: 7%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 7%; text-align: right;"><input type=submit name="validate_this" id="validate_this" value="Valider"></span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;'). '</span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;'). '</span>
	<div class=spacer></div></div>' ;	
		
	} elsif ((defined $args->{maj_staging} && $args->{maj_staging} eq 1) || defined $args->{deplacer}) {
		
	$submit_line = '
	<div class="flex-table submit"><div class=spacer></div>
	<span class=displayspan style="width: 2%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 12%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 18%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 6%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 7%; text-align: right;"><input type=submit name="validate_this" id="validate_this" value="Valider"></span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;'). '</span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;'). '</span>
	<div class=spacer></div></div>' ;	
		
	} else {  
		  
	$submit_line = '
	<div class="flex-table submit"><div class=spacer></div>
	<span class=displayspan style="width: 0.1%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%; text-align: center;">' . $extourne_link . '</span>
	<span class=displayspan style="width: 7.5%; text-align: center;">' . $duplicate_link . '</span>
	<span class=displayspan style="width: 11.5%; text-align: center;">' . $journal_link . '</span>
	<span class=displayspan style="width: 9%; text-align: center;">' . $delete_link . '</span>
	<span class=displayspan style="width: 14.5%; text-align: center;">' . $paiement_link . '</span>
	<span class=displayspan style="width: 6%; text-align: center;">&nbsp;</span>
	<span class=displayspan style="width: 7%; text-align: right;"><input type=submit name="validate_this" id="validate_this" value="Valider"></span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents1 || '&nbsp;') . '</span>
	<span class=displayspan style="width: 16.5%; text-align: center;">' . ($http_link_documents2 || '&nbsp;') . '</span>
	<span class=displayspan style="width: 3%;">' . $pointagerec . '</span>
	<div class=spacer></div></div>' ;

    } #    if ( $do_not_edit ) {
    

    $content .= '
    
    <ul class="wrapper2 style1">
    ' . $entry_table . '
    </ul>
    <form class="wrapper2bis" action="/'.$r->pnotes('session')->{racine}.'/entry" method=post>
    ' . $submit_line. '
	<input type=hidden name="preferred_datestyle" id="preferred_datestyle" value="' . $r->pnotes('session')->{preferred_datestyle} . '">
	<input type=hidden name="racine" id="racine" value="' . $r->pnotes('session')->{racine} . '">
	<input type=hidden name="fiscal_year" id="fiscal_year" value="' . $r->pnotes('session')->{fiscal_year} . '">
	<input type=hidden name="open_journal" id="open_journal" value="' . $args->{open_journal} . '">
	<input type=hidden name="mois" id="mois" value="' . $args->{mois} . '">
	<input type=hidden name="id_entry" value="' . $args->{id_entry} . '">
	<input type=hidden name="id_name" value="' . ($args->{id_name} || '') . '">
	<input type=hidden name="_token_id" id="_token_id" value="' . $args->{_token_id} . '">
	</form>
    ' ;

	#div d'affichage des messages d'erreur
    $content .= '<div id="bad_input"></div>' ;

    ################################################################# 
	# génération du choix de documents				 				#
	#################################################################

	#recherche de la liste des documents enregistrés
    $sql = '
    SELECT id_name
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception
	' ;	
    
    my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 ) ;
	my $id_name;
    
    my $document_select1 = '<select name=docs1 style="width: 100%;">
    <option value="">--Sélectionner le document 1--</option>
    ' ;
    my $document_select2 = '<select name=docs2 style="width: 100%;">
    <option value="">--Sélectionner le document 2--</option>
    ' ;

    for ( @$array_of_documents )   {
		unless ( $_->{id_name} eq (defined $id_name )) {
		my $selected1 = '';
		my $selected2 = '';
		
		if (not(defined $args->{docs1})) {
		} else {
		$selected1 = ( $_->{id_name} eq ( ($args->{docs1})) ) ? 'selected' : '' ;	
		}	
			
		if (not(defined $args->{docs2})) {
		} else {
		$selected2 = ( $_->{id_name} eq ( ($args->{docs2})) ) ? 'selected' : '' ;	
		}
			
		$document_select1 .= '
		<option value="' . $_->{id_name} . '" ' . $selected1 . '>' . $_->{id_name} . '</option>		
		' ;
		$document_select2 .= '
		<option value="' . $_->{id_name} . '" ' . $selected2 . '>' . $_->{id_name} . '</option>		
		' ;		
	    }
		$id_name = $_->{id_name} ;	
    }
    
    	if (not(defined $args->{docs1})) {
	    $document_select1 .= '<option value="" selected>--Sélectionner le document 1--</option>' ;	
		} else {
		$document_select1 .= '<option value="">--Sélectionner le document 1--</option>' ;	
		}
		
		if (not(defined $args->{docs2})) {
		$document_select2 .= '<option value="" selected>--Sélectionner le document 2--</option>' ;	
		} else {
		$document_select2 .= '<option value="">--Sélectionner le document 2--</option>' ;		
		}
    
    $document_select1 .= '</select>' ;
    $document_select2 .= '</select>' ;
    
    my $display_doc_1 .= '
    <form action=/'.$r->pnotes('session')->{racine}.'/entry>
    <input type=hidden name=open_journal value="'.$args->{open_journal}.'">
	<input type=hidden name=mois value="0" style="width: 100%;">
	<input type=hidden name=_token_id value="'.$args->{_token_id}.'">
	<input type=hidden name=maj_staging value="1">
	<input type=hidden name="id_entry" value="' . $args->{id_entry} . '">
	<input type=hidden name="id_name" value="' . ($args->{id_name} || '') . '">
	<input type=hidden name=redo value="1">
	'.$temp_docs2.'
    <table><tr>
	<td style="text-align: left; width: 70%;">' . $document_select1 . '</td>
	<td>&nbsp;</td>
	<td style="text-align: right;"><input type=submit value=Ouvrir></td>
	</tr></table></form>
	' ;

    my $display_doc_2 .= '
    <form action=/'.$r->pnotes('session')->{racine}.'/entry>
    <input type=hidden name=open_journal value="'.$args->{open_journal}.'" style="width: 100%;">
	<input type=hidden name=mois value="0" style="width: 100%;">
	<input type=hidden name=_token_id value="'.$args->{_token_id}.'" style="width: 100%;">
	<input type=hidden name="id_entry" value="' . $args->{id_entry} . '">
	<input type=hidden name=maj_staging value="1" style="width: 100%;">
	<input type=hidden name=redo value="1">
	<input type=hidden name="id_name" value="' . ($args->{id_name} || '') . '">
	'.$temp_docs1.'
    <table ><tr>
	<td style="text-align: left; width: 70%;">' . $document_select2 . '</td>
	<td>&nbsp;</td><td style="text-align: right;"><input type=submit value=Ouvrir></td>
	</tr></table></form>
	' ;
	

    ################################################################# 
	# ENTREES DU COMPTE FOURNISSEUR				 					#
	#################################################################
	
  
    $sql = qq {
SELECT t1.id_client, t1.fiscal_year, t1.numero_compte,  t2.libelle_compte
FROM tbljournal_staging t1 
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
WHERE t1._token_id = ? AND (substring(numero_compte from 1 for 1) IN ('4') OR substring(numero_compte from 1 for 2) IN ('58') OR substring(numero_compte from 1 for 3) IN ('511'))
} ;

	my $result_compte_4 = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, ( $args->{_token_id} ) ) ;
	
	if ( @$result_compte_4 && ($args->{id_entry} ne '0')) {
		
	my ( $lettrage_href, $lettrage_link, $lettrage_input, $lettrage_base ) ;
    
    my ( $pointage_href, $pointage_link, $pointage_input, $pointage_base ) ; 	
	
	$sql = '
	SELECT t1.id_entry, t1.id_line, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, id_export, to_char((sum(credit-debit) over(PARTITION BY numero_compte ORDER BY date_ecriture, libelle, libelle_journal, id_paiement, id_entry, id_line))/100::numeric, \'999G999G999G990D00\') as solde, lettrage, pointage
	FROM tbljournal t1
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND numero_compte = ?
	ORDER BY date_ecriture, id_facture, id_entry, libelle, id_line, id_paiement, libelle_journal
	' ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $result_compte_4->[0]->{numero_compte} ) ;
	my $result_compte_fourn_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
	
	$pointage_base = '<input type=checkbox id=id value=value style="vertical-align: middle;" onclick="pointage(this, \'' . ($result_compte_4->[0]->{numero_compte} || '&nbsp;'). '\')">' ;
    
    $lettrage_base = '<input type=text id=id style="margin-left: 0.5em; padding: 0; width: 7ch; height: 1em; text-align: right;" value=value placeholder=&rarr; oninput="lettrage(this, \'' . ($result_compte_4->[0]->{numero_compte} || '&nbsp;') . '\')">' ;
	my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $result_compte_4->[0]->{numero_compte} ) ;

	################################################################# 
	# REFERENCE NDF								 					#
	#################################################################
	
	my $disp_ndf = Base::Site::util::disp_lien_tag($args, $dbh, $r, $result_compte_4->[0]->{numero_compte});

	#Titre Compte Fournisseur
    $reffourn .= '
    <div class=Titre10>Compte de Tiers :&nbsp;<a href="' . ($compte_href || '') . '" class=nav2 >'. ($result_compte_4->[0]->{numero_compte} || '&nbsp;') .' - '. ($result_compte_4->[0]->{libelle_compte} || '&nbsp;').'</a>&nbsp;&nbsp;<span title="Cliquer pour masquer" id="hideLink" onclick="toggleList(\'fournisseur\');" style="cursor: pointer;">[▼]</span></div>
	'.$disp_ndf.'
	<br>
	';
	
	#ligne d'en-têtes
    my $entryfourn .= '
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 7.5%;">Date</span>
	<span class=headerspan style="width: 7.5%;">Journal</span>
	<span class=headerspan style="width: 7.5%;">Libre</span>
	<span class=headerspan style="width: 7.5%;">Compte</span>
	<span class=headerspan style="width: 8.5%;">Pièce</span>
	<span class=headerspan style="width: 29.9%;">Libellé</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 9%;">Lettrage</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Solde</span>
	<div class=spacer></div></div></li>
	' ;

	my $id_entry = '' ;

	for ( @$result_compte_fourn_set ) {
		
		#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
		unless ($_->{id_entry} eq $id_entry ) {

			#lien de modification de l'entrée
			my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry}.'&amp;docs='.($array_of_documents->[0]->{id_name} || '') ;

			#cas particulier de la première entrée de la liste : pas de liste précédente
			unless ( $id_entry ) {
				$entryfourn .= '<li class=listitem3>' ;
			} else {
				$entryfourn .= '</a></li><li class=listitem3>'
			} #	    unless ( $id_entry ) 

		} #	unless ( $_->{id_entry} eq $id_entry )

	#marquer l'entrée en cours
	$id_entry = $_->{id_entry} ;
	
	#lien de modification de l'entrée
	my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry}.'&amp;docs='.($array_of_documents->[0]->{id_name} ||'') ;

	my $lettrage_pointage = '&nbsp;' ;
	
	#l'id_line de la checkox de pointage commence par pointage_ pour être différente de id_line sur l'input de lettrage
	my $pointage_id = 'id=pointage_' . $_->{id_line} ;
	
	( $pointage_input = $pointage_base ) =~ s/id=id/$pointage_id/ ;

	my $pointage_value = ( $_->{pointage} eq 't' ) ? 'checked' : '' ;

	$pointage_input =~ s/value=value/$pointage_value/ ;

	#$lettrage_pointage = $pointage_input ;
	
	my $lettrage_id = 'id=' . $_->{id_line} ;

	( $lettrage_input = $lettrage_base ) =~ s/id=id/$lettrage_id/ ;
	
	my $lettrage_value = ( $_->{lettrage} ) ? 'value=' . $_->{lettrage} : '' ;

	$lettrage_input =~ s/value=value/$lettrage_value/ ;
	
	if ( defined $do_not_edit && ($do_not_edit eq 2 || $do_not_edit eq 1)) {
	$lettrage_pointage = ( $_->{lettrage} || '&nbsp;' );
	} else {
	$lettrage_pointage .= $lettrage_input ;
	}
	
	$entryfourn .= '
	<div class=flex-table><div class=spacer></div><a href="' . $id_entry_href . '">
	<span class=displayspan style="width: 7.5%;">' . $_->{date_ecriture} . '</span>
	<span class=displayspan style="width: 7.5%;">' . $_->{libelle_journal} .'</span>
	<span class=displayspan style="width: 7.5%;">' . $_->{id_paiement} . '</span>
	<span class=displayspan style="width: 7.5%;">' . $_->{numero_compte} . '</span>
	<span class=displayspan style="width: 8.5%;">' . $_->{id_facture} . '</span>
	<span class=displayspan style="width: 29.9%;">' . $_->{libelle} . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . $_->{debit} . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' .  $_->{credit} . '</span>
	</a>
	<span class=displayspan style="width: 9%;">' . $lettrage_pointage . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . $_->{solde} . '</span>
	<div class=spacer></div></div>
	' ;
	
	

    } #    for ( @$result_set ) }
    
	
    #on clot la liste s'il y avait au moins une entrée dans le journal
    $entryfourn .= '</a></li>' if ( @$result_set ) ;

    #pour le journal général, ajouter la colonne libelle_journal
    #$libelle_journal = ( $args->{open_journal} eq 'Journal général' ) ? '<span class=blockspan style="width: 25ch;">&nbsp;</span>' : '' ;
    
    $entryfourn .=  '<li class=style1><hr></li>
    <li class=style1><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 7.5%;">&nbsp;</span>
	<span class=displayspan style="width: 8.5%;">&nbsp;</span>
	<span class=displayspan style="width: 29.9%; text-align: right;">Total</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . ( $result_compte_fourn_set->[0]->{total_debit} || 0 ) . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . ( $result_compte_fourn_set->[0]->{total_credit} || 0 ) . '</span>
	<div class=spacer></div></div></li>' ;
	
	$reffourn .= '<ul id=fournisseur class="wrapper2 style1">'.$entryfourn .'</ul><br>' ;
	
	} # AFFICHAGE ENTREES DU COMPTE FOURNISSEUR

    my $refdoc .= '
    </ul><br>
    <div class=Titre10>Affichage des documents <span title="Cliquer pour masquer" id="hideLink" onclick="toggleList(\'docu\');"  style="cursor: pointer;">  [▼]</span></div>
    <div id=docu><div class="doc1left"><fieldset><legend>Document 1</legend>
    ' . $display_doc_1 . '</form>
   '.$affiche_docs1.'
	</div>
	<div class="doc2right"><fieldset><legend>Document 2</legend>
	' . $display_doc_2 . '</form>
	'.$affiche_docs2.'
	</div></fieldset></div>
	' ; 
	
	$content .= ($reffourn || '') . ($refdoc || '');
	
    return $content ;
    
} #sub edit_entry 

1 ;
