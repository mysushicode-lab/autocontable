package Base::Immobilier::gestionimmobiliere;
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

use strict;  			# Utilisation stricte des variables
use warnings;  			# Activation des avertissements
use utf8;              	# Encodage UTF-8 pour le script
use Base::Site::util;  	# Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   	# Interaction avec la base de données (SQL)
use Base::Site::menu;  # Module Menu
use PDF::API2;
use Apache2::Const -compile => qw( OK REDIRECT ) ;
use Apache2::Upload;
use File::Path 'mkpath' ;
use Time::Piece;

#/*—————————————— Action principale ——————————————*/
sub handler {
	
	binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content ;
    my $req = Apache2::Request->new($r) ;
	#récupérer les arguments
    my ( %args, @args, $sql, @bind_values ) ;
	#recherche des paramètres de la requête
    @args = $req->param ;
    my $id_client = $r->pnotes('session')->{id_client} ;
    my $message ;
    my $dbh = $r->pnotes('dbh') ;

    for (@args) {
	$args{$_} = Encode::decode_utf8( $req->param($_) ) ;
	#nix those sql injection/htmlcode attacks!
	$args{$_} =~ tr/<>;/-/ ;
	#les double-quotes et les <> viennent interférer avec le html
	$args{ $_ } =~ tr/<>"/'/ ;
    }
    
    if ( defined $args{logements} ) {
		
		$content = form_gestions_logements( $r, \%args ) ;
	
	} else {
		
		$content .= visualize( $r, \%args ) ;	
	
	}  

	$r->no_cache(1) ;
	$r->content_type('text/html; charset=utf-8') ;
	print $content ;
	return Apache2::Const::OK ;

}

#/*—————————————— Page principale de la gestion des baux ——————————————*/
sub visualize {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $id_client = $r->pnotes('session')->{id_client} ;
	my ($selected, $modified, $baux_list, $html_quittance) = ('', '', '', '');
	my $reqid = Base::Site::util::generate_reqline();
    $args->{restart} = 'gestionimmobiliere';
    $args->{baux} //= 1;  # Par défaut à 1
    $args->{archive} //= 0;  # Par défaut à 0

    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
	
	################ Affichage MENU ################
	$content .= display_menu_gestion_immobiliere( $r, $args ) ;
	################ Affichage MENU ################
	
    ############## Formulaire Gestion des baux : Liste des baux ##############
    $baux_list .= '<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des baux</h3></legend><div class="centrer">';
    
	$baux_list .= Affichage_list_baux( $r, $args) ;	
     
    if (defined $args->{baux} && $args->{baux} ne 0 && defined $args->{code} && $args->{code} ne '') {
		
		$baux_list .= '<hr class="mainPageTutoriel"><form id="menubaux" class="wrapper1" method="GET">';
		
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
			$baux_list .= '
			<!-- Catégorie Niveau 1 -->
			<div class="formflexN1 flex1" style="font-weight: bold;" id="importation_section_1">
				<input class="custom-radio" type="radio" id="immo_1" name="baux" value="1"' . (defined $args->{baux} && $args->{baux} eq '1' ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_1">Les écritures</label>
				<input class="custom-radio" type="radio" id="immo_2" name="baux" value="2"' . ((defined $args->{baux} && $args->{baux} eq '2') || defined $args->{id_loc} ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_2">Les locataires ou Garants</label>
				<input class="custom-radio" type="radio" id="immo_3" name="baux" value="3"' . ((defined $args->{baux} && $args->{baux} eq '3') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_3">Les documents</label>
				<input class="custom-radio" type="radio" id="immo_4" name="baux" value="4"' . ((defined $args->{baux} && $args->{baux} eq '4') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_4">Quittance</label>
				<input class="custom-radio" type="radio" id="immo_5" name="baux" value="5"' . ((defined $args->{baux} && $args->{baux} eq '5') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_5">Email</label>
				<input class="custom-radio" type="radio" id="immo_6" name="baux" value="6"' . ((defined $args->{baux} && $args->{baux} eq '6') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_6">Saisie Rapide</label>
			</div>
			';
		} else {
			$baux_list .= '
			<!-- Catégorie Niveau 1 -->
			<div class="formflexN1 flex1" style="font-weight: bold;" id="importation_section_1">
				<input class="custom-radio" type="radio" id="immo_1" name="baux" value="1"' . (defined $args->{baux} && $args->{baux} eq '1' ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_1">Les écritures</label>
				<input class="custom-radio" type="radio" id="immo_2" name="baux" value="2"' . ((defined $args->{baux} && $args->{baux} eq '2') || defined $args->{id_loc} ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_2">Les locataires ou Garants</label>
				<input class="custom-radio" type="radio" id="immo_3" name="baux" value="3"' . ((defined $args->{baux} && $args->{baux} eq '3') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_3">Les documents</label>
				<input class="custom-radio" type="radio" id="immo_5" name="baux" value="5"' . ((defined $args->{baux} && $args->{baux} eq '5') ? ' checked' : '') . ' onclick="submit();">
				<label for="immo_5">Email</label>
			</div>
			';
		}

		$baux_list .= '<input type=hidden name="code" value="' . $args->{code} . '" ><input type=hidden name="archive" value="' . $args->{archive} . '" ></form>';
			
		if (defined $args->{baux} && $args->{baux} eq 2 || defined $args->{id_loc})	{
			$baux_list .= Affichage_list_locataires( $r, $args) ;
		} elsif (defined $args->{baux} && $args->{baux} eq 3 || defined $args->{id_name}){
		    $baux_list .= Affichage_list_documents( $r, $args) ; 
		} elsif (defined $args->{baux} && $args->{baux} eq 5 || defined $args->{quittance}  )	{
			$html_quittance .= form_email( $r, $args ); 
		} elsif ($r->pnotes('session')->{Exercice_Cloture} ne '1' && (defined $args->{baux} && $args->{baux} eq 4 || defined $args->{quittance} )) {
			$html_quittance .= Affichage_quittance( $r, $args) ; 
		}  elsif ($r->pnotes('session')->{Exercice_Cloture} ne '1' && (defined $args->{baux} && $args->{baux} eq 6 || defined $args->{saisie_rapide} )) {
			$html_quittance .= form_rapide( $r, $args );
		} elsif (defined $args->{baux} && defined $args->{baux} eq 1 || defined $args->{quittance} || defined $args->{quittance_reference}) {
			$html_quittance .= Affichage_list_ecriture( $r, $args) ; 
		} 

	} elsif ((defined $args->{logements} && defined $args->{modifier}) && $args->{modifier} eq 1 && defined $args->{code} && $args->{code} eq '') {
	  $content .= Base::Site::util::generate_error_message('Impossible le bail n\'a pas été sélectionné') ;		
	}
	
	$content .= '</div></div></fieldset>
	<div class="wrapper-docs-entry" >' . $baux_list . $html_quittance . '</div>
	<script>
	focusAndChangeColor2("'.($args->{code} || '').'");
	</script>';

    return $content ;
    

} #sub visualize

#/*—————————————— Page Formulaire Gestions des logements ——————————————*/
sub form_gestions_logements {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content) ;
	my ($selected, $modified, $end) = ('', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    $args->{restart} = 'gestionimmobiliere?logements';
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

	######## Affichage MENU display_menu Début ######
	$content .= display_menu_gestion_immobiliere( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'dupliquer' 					  #
	#######################################################################
	if ( defined $args->{logements} && defined $args->{dupliquer} && $args->{dupliquer} eq '0' ) {
		$sql = 'SELECT biens_ref, biens_nom FROM tblimmobilier_logement WHERE id_client = ? and biens_ref = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($args->{biens_archive} || 'f').'&code=' . $args->{code}.'&modifier=1' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($args->{biens_archive} || 'f').'&code=' . $args->{code}.'&dupliquer=1&ajouter=0' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous dupliquer le logement '.$args->{code}.' - '.($result_set->[0]->{biens_nom}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{logements} && defined $args->{dupliquer} && $args->{dupliquer} eq '1' ) {
		$sql = 'SELECT * FROM tblimmobilier_logement WHERE id_client = ? and biens_ref = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		$args->{code} = undef;
		$args->{biens_compte} = $result_set->[0]->{biens_compte} || undef;
		$args->{biens_nom} = $result_set->[0]->{biens_nom} || undef;
        $args->{biens_adresse} = $result_set->[0]->{biens_adresse} || undef;
        $args->{biens_cp} = $result_set->[0]->{biens_cp} || undef;
        $args->{biens_ville} = $result_set->[0]->{biens_ville} || undef;
        $args->{biens_surface} = $result_set->[0]->{biens_surface} || undef;
        $args->{biens_com1} = $result_set->[0]->{biens_com1} || undef;
        $args->{biens_com2} = $result_set->[0]->{biens_com2} || undef;
	}
		
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    #demande de suppression; afficher lien d'annulation/confirmation
	if ( defined $args->{logements} && defined $args->{supprimer} && $args->{supprimer} eq '0' ) {
		$sql = 'SELECT biens_ref, biens_nom FROM tblimmobilier_logement WHERE id_client = ? and biens_ref = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($result_set->[0]->{biens_archive} || 'f').'&code=' . $args->{code}.'&modifier=1' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($result_set->[0]->{biens_archive} || 'f').'&code=' . $args->{code}.'&supprimer=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le logement '.$args->{code}.' - '.($result_set->[0]->{biens_nom}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{logements} && defined $args->{supprimer} && $args->{supprimer} eq '1' ) {
			if (defined $args->{code} && $args->{code} eq '') {
				$content .= Base::Site::util::generate_error_message('Impossible le logement n\'a pas été sélectionné') ;	
			} else {	
				my $sql = 'SELECT biens_ref, biens_nom FROM tblimmobilier_logement WHERE id_client = ? and biens_ref = ?';
				my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
				#demande de suppression confirmée
				$sql = 'DELETE FROM tblimmobilier_logement WHERE biens_ref = ? AND id_client = ?' ;
				@bind_array = ( $args->{code}, $r->pnotes('session')->{id_client} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					if ( $@ =~ /NOT NULL/ ) {
					$content .= Base::Site::util::generate_error_message('Impossible le nom du logement est vide') ;
					} elsif ( $@ =~ /existe|already exists/ ){
					$content .= Base::Site::util::generate_error_message('Le logement avec le code '.$args->{code}.' existe déjà') ;
					}  elsif ( $@ =~ /toujours|referenced/ ) {
					$content .= Base::Site::util::generate_error_message('Suppression impossible : le logement est utilisé dans un bail') ;
					} else {
					$content .= Base::Site::util::generate_error_message($@);
					}
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Suppression du logement '.$args->{code}.' - '.($result_set->[0]->{biens_nom}|| '').'');
					$args->{restart} = 'gestionimmobiliere?logements';
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé 
				}
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{logements} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_libelle(\$args->{biens_nom}, \$args->{biens_adresse}, \$args->{biens_ville}, \$args->{biens_com1}, \$args->{biens_com2});
        $args->{code} ||= undef;
        $args->{biens_nom} ||= undef;
        $args->{biens_adresse} ||= undef;
        $args->{biens_cp} ||= undef;
        $args->{biens_ville} ||= undef;
        $args->{biens_surface} ||= undef;
        $args->{biens_archive} ||= undef;
        $args->{biens_compte} ||= undef;
        $args->{biens_com1} ||= undef;
        $args->{biens_com2} ||= undef;

		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [19, $args->{code}], [20, $args->{biens_nom}], [21, $args->{biens_surface}]);
			
		if ($erreur) {
			$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			$args->{ajouter} = 0;
		} else {
			$sql = 'INSERT INTO tblimmobilier_logement (id_client, fiscal_year, biens_ref, biens_compte, biens_nom, biens_adresse, biens_cp, biens_ville, biens_surface, biens_archive, biens_com1, biens_com2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
			@bind_array = (
				$r->pnotes('session')->{id_client},
				$r->pnotes('session')->{fiscal_year},
				$args->{code},
				$args->{biens_compte},
				$args->{biens_nom},
				$args->{biens_adresse},
				$args->{biens_cp},
				$args->{biens_ville},
				$args->{biens_surface},
				($args->{biens_archive} || 'f'),
				$args->{biens_com1},
				$args->{biens_com2}
			);
			eval { $dbh->do($sql, undef, @bind_array) };

			if ( $@ ) {
				$args->{ajouter} = 0;
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom et un code de logement') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Le logement avec le code '.$args->{code}.' existe déjà !!') ;
				} else {$content .= Base::Site::util::generate_error_message($@);}
			} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Ajout du logement '.$args->{code}.' - '.$args->{biens_nom}.'');
			$args->{restart} = 'gestionimmobiliere?logements='.($args->{biens_archive} || 'f').'&code=' . $args->{code}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}	
		}

	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				  #
	#######################################################################
    if ( defined $args->{logements} && defined $args->{maj} && $args->{maj} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_libelle(\$args->{biens_nom}, \$args->{biens_adresse}, \$args->{biens_ville}, \$args->{biens_com1}, \$args->{biens_com2});
        $args->{code} ||= undef;
        $args->{biens_nom} ||= undef;
        $args->{biens_adresse} ||= undef;
        $args->{biens_cp} ||= undef;
        $args->{biens_ville} ||= undef;
        $args->{biens_surface} ||= undef;
        $args->{biens_archive} ||= undef;
        $args->{biens_compte} ||= undef;
        $args->{biens_com1} ||= undef;
        $args->{biens_com2} ||= undef;
        
		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [19, $args->{code}], [20, $args->{biens_nom}], [21, $args->{biens_surface}]);
		if ($erreur) {
			$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
		} else {
	    # Préparer la requête SQL pour la mise à jour de l'utilisateur
	    $sql = 'UPDATE tblimmobilier_logement set fiscal_year = ?, biens_ref = ?, biens_compte = ?, biens_nom = ?, biens_adresse = ?, biens_cp = ?, biens_ville = ?, biens_surface = ? , biens_archive = ?, biens_com1 = ?, biens_com2 = ? where id_client = ? and biens_ref = ? ' ;
	    @bind_array = ( $r->pnotes('session')->{fiscal_year}, $args->{code}, $args->{biens_compte}, $args->{biens_nom}, $args->{biens_adresse}, $args->{biens_cp}, $args->{biens_ville}, $args->{biens_surface}, ($args->{biens_archive} || 'f') , $args->{biens_com1}, $args->{biens_com2}, $r->pnotes('session')->{id_client}, $args->{old_code}) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$args->{modifier} = 1;
				if ( $@ =~ /NOT NULL/ ) {
				$content .= Base::Site::util::generate_error_message('Impossible le nom du logement est vide') ;
				} elsif ($@ =~ /tblimmobilier_logement_id_client_fiscal_year_biens_compte_fkey/i ) {
				if ($@ =~ /(.{7})\) is not present/) {
				my $missing_numero_compte = $1;
				$content .= Base::Site::util::generate_error_message('Un numéro de compte est invalide - Enregistrement impossible.<br> Numéro de compte manquant : '.$missing_numero_compte.'');
				} else {
				$content .= Base::Site::util::generate_error_message('Un numéro de compte est invalide - Enregistrement impossible');
				}
			} elsif ( $@ =~ /existe|already exists/ ){
				$content .= Base::Site::util::generate_error_message('Le logement avec le code '.$args->{code}.' existe déjà') ;
				}  elsif ( $@ =~ /toujours|referenced/ ) {
				$content .= Base::Site::util::generate_error_message('Suppression impossible : le logement est utilisé dans un bail') ;
				} else {
				$content .= Base::Site::util::generate_error_message($@);}
			} else {
				$args->{restart} = 'gestionimmobiliere?logements='.($args->{biens_archive} || 'f').'&modifier=1&code=' . $args->{code}.'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
		}
	}

    #/************ ACTION FIN *************/
    
    my $biens_list .= '
	<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des logements</h3></legend><div class="centrer">
		<form id="menulogement" class="wrapper1" action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere method="GET">
			<div class="formflexN1 flex1" style="font-weight: bold;" id="logement_section_1">
				<input class="custom-radio" type="radio" id="logement_1" name="logements" value="f"' . (defined $args->{logements} && $args->{logements} ne 't' ? ' checked' : '') . ' onclick="submit();">
				<label for="logement_1">Logements en cours</label>
				<input class="custom-radio" type="radio" id="logement_2" name="logements" value="t"' . (defined $args->{logements} && $args->{logements} eq 't' ? ' checked' : '') . ' onclick="submit();">
				<label for="logement_2">Logements archivés</label>
			</div>
		</form>';
	
	if (defined $args->{logements} && defined $args->{ajouter}) {
		my $forms_new_logement = '<fieldset class="centrer Titre09 pretty-box"> '.form_nouveau_logement( $r, $args).'</fieldset><br>' ; 
		$biens_list .= $forms_new_logement ; 
    }
    
    my $info_logement = '';
    my $var_archive = '';
    
    if (defined $args->{logements} && $args->{logements} eq 't') {
		$info_logement = Base::Site::bdd::get_immobilier_logements($dbh, $r, 1);
		$var_archive = 'archivés';
	} else {
		$info_logement = Base::Site::bdd::get_immobilier_logements($dbh, $r, 2);
		$var_archive = 'en cours';
	}
    
    $biens_list .= '	
    	<div class="Titre10"><span class=check>
			<a href="gestionimmobiliere?logements&ajouter" title="Cliquer pour ajouter un logement" class="label3">
			Ajouter un logement<span class="plus">+</span></a></span>
			<div class="centrer"> Liste des logements '.$var_archive.'</div>
		</div>';
		
		#ligne des en-têtes Frais en cours
		$biens_list .= '
		<ul class="wrapper100"><li class="style1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 8%;text-align: left">Code</span>
		<span class=headerspan style="width: 14%;text-align: left">Nom du bien</span>
		<span class=headerspan style="width: 14%;text-align: left">Compte Produit</span>
		<span class=headerspan style="width: 25%;text-align: left">Adresse</span>
		<span class=headerspan style="width: 9%;text-align: left">CP</span>
		<span class=headerspan style="width: 14%;text-align: left">Ville</span>
		<span class=headerspan style="width: 8%;text-align: left">Surface</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<div class=spacer></div></li>
		' ;
    
	if (@$info_logement) {

		for ( @$info_logement ) {
			
			my $reqline = ($reqid ++);
			my $dupliquer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($_->{biens_archive} || 'f').'&code='.($_->{biens_ref} || '').'&modifier=1&amp;dupliquer=0' ;
			my $supprimer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($_->{biens_archive} || 'f').'&code='.($_->{biens_ref} || '').'&modifier=1&amp;supprimer=0' ;
	
			my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{biens_doc1}, 1);

			my $logement_ref_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements='.($_->{biens_archive} || 'f').'&code=' . ($_->{biens_ref} || '').'&modifier=1' ;
			#ligne d'en-têtes
			$biens_list .= '
				<li class=listitem3 id="line_'.($_->{biens_ref} || '').'"><a href="' . $logement_ref_href . '"><span class=displayspan2><div class=flex-table><div class=spacer></div>
				<span class=blockspan style="width: 0.5%;text-align: left;">&nbsp;</span>
				<span class=blockspan style="width: 8%;text-align: left">' . ( $_->{biens_ref} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 14%;text-align: left">' . ( $_->{biens_nom} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 14%;text-align: left" title="'. ($_->{libelle_compte} || '&nbsp;' ).'">' . ( $_->{biens_compte} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 25%;text-align: left">' . ($_->{biens_adresse} || '&nbsp;' ). '</span>
				<span class=blockspan style="width: 9%;text-align: left">' . ($_->{biens_cp} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 14%;text-align: left">' . ( $_->{biens_ville} || '&nbsp;') . '</span>
				<span class=blockspan style="width: 8%;text-align: left">' . ($_->{biens_surface} || '&nbsp;'). '</span>
				</a>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<form method="post"><span class="blockspan" style="width: 2%;">'.$http_link_documents1.'</span></form>
				<form method="post"><span class=blockspan style="width: 2%;"><input type="image" src="/Compta/style/icons/duplicate.png" style="border: 0;" height="14" width="14" alt="dupliquer" formaction="' . $dupliquer_href . '" onclick="submit()" title="Dupliquer le logement"></span></form>
				<form method="post"><span class=blockspan style="width: 2%;"><input type="image" src="/Compta/style/icons/delete.png" style="border: 0;" height="14" width="14" alt="supprimer" formaction="' . $supprimer_href . '" onclick="submit()" title="Supprimer le logement" ></span></form>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<div class=spacer></div></div></li>
			' ;
		}
		$biens_list .= '</ul>';
	} else {
		$biens_list .= '<div class="warnlite">*** Aucun logement trouvé ***</div>';
	}


	if ((defined $args->{logements} && ((defined $args->{modifier}) && $args->{modifier}) || (defined $args->{supprimer} && $args->{supprimer} eq 0)) eq 1 && defined $args->{code} && $args->{code} ne '') {

		$biens_list .= form_nouveau_logement( $r, $args) ; 
		$biens_list .= Affichage_list_documents( $r, $args) ; 
		$end .= '<script>
		focusAndChangeColor2("'.$args->{code}.'");
		</script>';
	
	} elsif ((defined $args->{logements} && defined $args->{modifier}) && $args->{modifier} eq 1 && defined $args->{code} && $args->{code} eq '') {
	  $content .= Base::Site::util::generate_error_message('Impossible le logement n\'a pas été sélectionné') ;		
	}
	
	$biens_list .= '</div></div></fieldset>';

	$content .= '<div class="wrapper-docs-entry" >' . $biens_list . $end . '</div>' ;

    return $content ;
    
} #sub form_gestions_logements 

#/*—————————————— Page Formulaire nouveau bail ——————————————*/
sub form_nouveau_bail {
	
	# définition des variables
    my ( $r, $args, $result_set ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($form_html, $item_num, $baux_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    my $sql = 'SELECT * FROM tblimmobilier WHERE id_client = ? and immo_contrat = ?';
	$result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };

    # Génération formulaire choix du compte client
	my $compte1 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '411');
	my $selected_compte = ((defined($args->{immo_compte}) && $args->{immo_compte} ne '') || $result_set->[0]->{immo_compte}) ? ($args->{immo_compte} || $result_set->[0]->{immo_compte}) : undef;
	my ($form_name_compte, $form_id_compte)  = ('immo_compte', 'immo_compte_'.$reqid.'');
	my $onchange_compte = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"';
	my $compte_client = Base::Site::util::generate_compte_selector($compte1, $reqid, $selected_compte, $form_name_compte, $form_id_compte, $onchange_compte, 'class="respinput"', '');

	# Génération formulaire choix du logement	
	my $info_logement = Base::Site::bdd::get_immobilier_logements($dbh, $r);
	my $selected_logement = ((defined($args->{immo_logement}) && $args->{immo_logement} ne '') || $result_set->[0]->{immo_logement}) ? ($args->{immo_logement} || $result_set->[0]->{immo_logement}) : undef;
	my $onchange_logement = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'gestionimmobiliere?logements&ajouter=0\'};\"";
	my ($form_name_logement, $form_id_logement) = ('immo_logement', 'immo_logement_'.$reqid.'');
	my $search_logement = Base::Site::util::generate_immobilier_logement($info_logement, $reqid, $selected_logement, $form_name_logement, $form_id_logement, $onchange_logement, 'class="respinput"', '');
	
	my $echeance_select .= '<select class="respinput" name="immo_entry" id="immo_entry">';
	for my $day (1..31) {
		my $formatted_day = sprintf("%02d", $day);  # Formater avec deux chiffres
		$echeance_select .= '<option value="' . $day . '" ' .
			((defined $args->{immo_entry} && $args->{immo_entry} eq $day) ||
			 (defined $result_set->[0]->{immo_entry} && $result_set->[0]->{immo_entry} eq $day) ?
			 'selected' : '') .
			 ' >' . $formatted_day . '</option>';
	}
	$echeance_select .= '</select>';
	
	#on regarde s'il existe des baux enregistrées pour l'année en cours
	$sql = 'SELECT immo_contrat FROM tblimmobilier WHERE id_client = ? ORDER BY 1 DESC LIMIT 1' ;
	my $result_contrat_set =  eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client})} ; 
			
	# Trouver le plus grand numéro existant
	if (@$result_contrat_set) {
		for (@$result_contrat_set) {
			if (defined $_->{immo_contrat} && $_->{immo_contrat} =~ /(\d{3})$/) {
				my $last_three_digits = $1;
				if ($last_three_digits =~ /\d/) {
					$item_num = int($last_three_digits) if int($last_three_digits) >= $item_num;
				}
			}
		}
		$item_num++; # Incrémenter le numéro
	}

	if (defined $args->{modifier}) {
		$numero_piece = ((defined($args->{code}) && $args->{code} ne '') || defined $result_set->[0]->{immo_contrat}) ? ($args->{code} || $result_set->[0]->{immo_contrat}) : undef;
	} else {
		$numero_piece = sprintf("BAV%03d", $item_num); # Formater comme "BI0V" suivi de deux chiffres
	}
	
	my $immo_loyer = Base::Site::util::affichage_montant((defined $args->{immo_loyer} || defined $result_set->[0]->{immo_loyer}) ? ($args->{immo_loyer} || $result_set->[0]->{immo_loyer}/100 || '0.00') : '0.00');
	my $immo_depot = Base::Site::util::affichage_montant((defined $args->{immo_depot} || defined $result_set->[0]->{immo_depot}) ? ($args->{immo_depot} || $result_set->[0]->{immo_depot}/100 || '0.00') : '0.00');

	my $date_options = 'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');" required';
	my $date_options2 = 'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"';

	my @champs = (
		["input", "Référence", "code", "flex-10", "respinput", "resplabel", "text", "required", "$numero_piece"],
		["input", "Date de début", "immo_date1", "flex-10", "respinput", "resplabel", "text", $date_options, defined $result_set->[0]->{immo_date1} ? $result_set->[0]->{immo_date1} : ""],
		["input", "Date de fin", "immo_date2", "flex-10", "respinput", "resplabel", "text", $date_options2, defined $result_set->[0]->{immo_date2} ? $result_set->[0]->{immo_date2} : ""],
		["input", "Libellé", "immo_libelle", "flex-21", "respinput", "resplabel", "text", "required", defined $result_set->[0]->{immo_libelle} ? $result_set->[0]->{immo_libelle} : ""],
		["select", "Logement", "immo_logement", "flex-21", "respinput", "resplabel", "text", '', defined $search_logement ? $search_logement : ""],
		["select", "Compte client", "immo_compte", "flex-21", "respinput", "resplabel", "text", "", defined $compte_client ? $compte_client : ""],
		["input", "Loyer", "immo_loyer", "flex-10", "respinput", "resplabel", "text", 'onchange="format_number(this);"', "$immo_loyer"],
		["input", "Dépôt garantie", "immo_depot", "flex-10", "respinput", "resplabel", "text", 'onchange="format_number(this);"', "$immo_depot"],
		["select", "Echéance", "immo_entry", "flex-10", "respinput", "resplabel", "text", "", defined $echeance_select ? $echeance_select : ""],
		["input", "Commentaire 1", "immo_com1", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{immo_com1} ? $result_set->[0]->{immo_com1} : ""],
		["input", "Commentaire 2", "immo_com2", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{immo_com2} ? $result_set->[0]->{immo_com2} : ""],
		["input", "Archiver", "immo_archive", "flex-15", "checkinput", "resplabel", "checkbox", 'title="Cocher pour archiver" '. (defined $result_set->[0]->{immo_archive} && $result_set->[0]->{immo_archive} eq "t" ? "checked" : "").'', "t"],
		["input", "&nbsp;", "submit_bail", "flex-10", "respbtn btn-vert", "resplabel", "submit", "", "Valider"]
	);
	
	if (defined $args->{modifier}) {
		# Formulaire Modification du bail
		$baux_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?baux=1&amp;code='. ($args->{code}||'').'&archive='. ($args->{archive}||'').'" title="fermer la fenêtre" class="label3">
				<span>[X]</span></a></span>
				<div class="centrer green"> Modification du bail : '. $args->{code}.' - '.($result_set->[0]->{immo_libelle}|| '').' </div>
			</div>

			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=0>
			<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=maj value="1">
			<input type=hidden name=archive value="'.($args->{archive} || 0).'">
			<input type=hidden name=old_code value="'.($result_set->[0]->{immo_contrat}|| '').'" >
			</form>
			<br>
		' ;
		
	} else {
		# Formulaire nouveau bail
		$baux_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="centrer green"> Enregistrement d\'un nouveau bail </div>
			</div>
			
			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=0&ajouter=1>
			<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			</form>
			<br>
		';
	}
	
	return $baux_list;
}

#/*—————————————— Page Formulaire nouveau logement ——————————————*/
sub form_nouveau_logement {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    
    my $reqid = Base::Site::util::generate_reqline();
    my ($form_html, $item_num, $biens_list, $numero_piece) = ('','1', '', '');
    
    # On regarde s'il existe des logements enregistrés
	my $sql = 'SELECT biens_ref FROM tblimmobilier_logement WHERE id_client = ? ORDER BY 1 DESC';
	my $result_compte_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}) };
	
	$sql = 'SELECT * FROM tblimmobilier_logement WHERE id_client = ? and biens_ref = ?';
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };

	# Trouver le plus grand numéro existant
	if (@$result_compte_set) {
		for (@$result_compte_set) {
			if (defined $_->{biens_ref} && $_->{biens_ref} =~ /(\d{2})$/) {
				my $last_two_digits = $1;
				if ($last_two_digits =~ /\d/) {
					$item_num = int($last_two_digits) if int($last_two_digits) >= $item_num;
				}
			}
		}

		# Incrémenter le numéro
		$item_num++;
	}

	if (defined $args->{modifier}) {
		$numero_piece = ((defined($args->{code}) && $args->{code} ne '') || $result_set->[0]->{biens_ref}) ? ($args->{code} || $result_set->[0]->{biens_ref}) : undef;
	} else {
		# Formater comme "BI0V" suivi de deux chiffres
		$numero_piece = sprintf("BI0V%02d", $item_num);
	}

    # Génération formulaire choix du compte de produit	
	my $compte1 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '7');
	my $selected_compte = ((defined($args->{biens_compte}) && $args->{biens_compte} ne '') || $result_set->[0]->{biens_compte}) ? ($args->{biens_compte} || $result_set->[0]->{biens_compte}) : undef;
	my ($form_name_compte, $form_id_compte)  = ('biens_compte', 'biens_compte');
	my $onchange_compte = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"';
	my $compte_produit = Base::Site::util::generate_compte_selector($compte1, $reqid, $selected_compte, $form_name_compte, $form_id_compte, $onchange_compte, 'class="respinput"', '');
	
	# Génération formulaire choix de documents	
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $selected1 = ((defined($args->{biens_doc1}) && $args->{biens_doc1} ne '') || $result_set->[0]->{biens_doc1}) ? ($args->{biens_doc1} || $result_set->[0]->{biens_doc1}) : undef;
	my $selected2 = ((defined($args->{biens_modbail}) && $args->{biens_modbail} ne '') || $result_set->[0]->{biens_modbail} )? ($args->{biens_modbail} || $result_set->[0]->{biens_modbail}) : undef;
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my ($form_name1, $form_id1, $class_value1, $style1) = ('biens_doc1', 'docs1', 'class="respinput"', '');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);
	my ($form_name2, $form_id2, $class_value2, $style2) = ('biens_modbail', 'docs2', 'class="respinput"', '');
	my $document_select2 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected2, $form_name2, $form_id2, $onchange1, $class_value2, $style2);

	my @champs = (
		["input", "Code", "code", "flex-10", "respinput", "resplabel", "text", "required", "$numero_piece"],
		["input", "Nom du bien", "biens_nom", "flex-21", "respinput", "resplabel", "text", "required", defined $result_set->[0]->{biens_nom} ? $result_set->[0]->{biens_nom} : ""],
		["input", "Adresse", "biens_adresse", "flex-21", "respinput", "resplabel", "text", "", defined $result_set->[0]->{biens_adresse} ? $result_set->[0]->{biens_adresse} : ""],
		["input", "Code postal", "biens_cp", "flex-10", "respinput", "resplabel", "text", 'pattern="[0-9]+" title="Code postale composé de chiffre."', defined $result_set->[0]->{biens_cp} ? $result_set->[0]->{biens_cp} : ""],
		["input", "Ville", "biens_ville", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{biens_ville} ? $result_set->[0]->{biens_ville} : ""],
		["input", "Surface (m²)", "biens_surface", "flex-10", "respinput", "resplabel", "text", 'pattern="[0-9]+" title="Surface composée de chiffre."', defined $result_set->[0]->{biens_surface} ? $result_set->[0]->{biens_surface} : ""],
		["select", "Compte de Produit", "biens_compte", "flex-21", "respinput", "resplabel", "text", "", defined $compte_produit ? $compte_produit : ""],
		["input", "Commentaire 1", "biens_com1", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{biens_com1} ? $result_set->[0]->{biens_com1} : ""],
		["input", "Commentaire 2", "biens_com2", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{biens_com2} ? $result_set->[0]->{biens_com2} : ""],
		["input", "Archiver", "biens_archive", "flex-15", "checkinput", "resplabel", "checkbox", 'title="Cocher pour archiver" '. (defined $result_set->[0]->{biens_archive} && $result_set->[0]->{biens_archive} eq "t" ? "checked" : "").'', "t"],
		["input", "&nbsp;", "submit_biens", "flex-10", "respbtn btn-vert", "resplabel", "submit", "", "Valider"]
	);

	if (defined $args->{modifier}) {
		# Formulaire Modification du logement
		$biens_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?logements" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="centrer"> Modification du logement : '. $args->{code}.' - '.($result_set->[0]->{biens_nom}|| '').' </div>
			</div>

			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?logements>
			<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=maj value="1">
			<input type=hidden name=old_code value="'.($result_set->[0]->{biens_ref}|| '').'" >
			</form>
			<br>
		' ;
		
	} else {
		# Formulaire nouveau logement
		$biens_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?logements" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="green centrer"> Enregistrement d\'un nouveau logement </div>
			</div>
			
			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?logements>
			<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=ajouter value="1">
			</form>
			<br>
		';
	
	}
	
	return $biens_list;
}

#/*—————————————— Page Formulaire nouveau locataires ou garants ——————————————*/
sub form_nouveau_loc {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($form_html, $item_num, $loc_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
	my $sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and id_loc = ?';
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{id_loc}) };
		
    # Trouver le numéro du bail
	if (defined $args->{code} && $args->{code} =~ /(\d{3})$/) {
		my $last_three_digits = $1;
		if ($last_three_digits =~ /\d/) {
			$item_num = int($last_three_digits) if int($last_three_digits) >= $item_num;
		}
	}
	
	if (defined $args->{modifier}) {
		$numero_piece = ((defined($args->{locataires_ref}) && $args->{locataires_ref} ne '') || $result_set->[0]->{locataires_ref}) ? ($args->{locataires_ref} || $result_set->[0]->{locataires_ref}) : undef;
	} else {
		# Formater comme "BI0V" suivi de deux chiffres
		$numero_piece = sprintf("LOCV%03d", $item_num); # Formater comme "LOCV" suivi de trois chiffres
	}

	# Génération formulaire choix de documents	
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $selected1 = ((defined($args->{locataires_doc1}) && $args->{locataires_doc1} ne '') || $result_set->[0]->{locataires_doc1}) ? ($args->{locataires_doc1} || $result_set->[0]->{locataires_doc1}) : undef;
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my ($form_name1, $form_id1, $class_value1, $style1) = ('locataires_doc1', 'locataires_doc1', 'class="respinput"', '');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);
	
	# Sélection du type
	my $select_type = '<select class="respinput" name="locataires_type" id="locataires_type">
    <option value="Locataire" '.(((defined $args->{locataires_type} && $args->{locataires_type} eq "Locataire") || (defined $result_set->[0]->{locataires_type} && $result_set->[0]->{locataires_type} eq "Locataire"))  ? ' selected' : '').' >Locataire</option>
    <option value="Garant" '.(((defined $args->{locataires_type} && $args->{locataires_type} eq "Garant") || (defined $result_set->[0]->{locataires_type} && $result_set->[0]->{locataires_type} eq "Garant")) ? ' selected' : '').' >Garant</option>
    </select>';
	
	# Sélection de la civilité
	my $select_civilite = '<select class="respinput" name="locataires_civilite" id="locataires_civilite">
    <option value="Mr" '.(((defined $args->{locataires_civilite} && $args->{locataires_civilite} eq "Mr") || (defined $result_set->[0]->{locataires_civilite} && $result_set->[0]->{locataires_civilite} eq "Mr")) ? ' selected' : '').' >Mr</option>
    <option value="Mme" '.(((defined $args->{locataires_civilite} && $args->{locataires_civilite} eq "Mme") || (defined $result_set->[0]->{locataires_civilite} && $result_set->[0]->{locataires_civilite} eq "Mme")) ? ' selected' : '').' >Mme</option>
    </select>';
    
    my $date_options = 'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"';

	my @champs = (
		["input", "Référence", "locataires_ref", "flex-10", "respinput", "resplabel", "text", "required", "$numero_piece"],
		["select", "Type", "locataires_type", "flex-10", "respinput", "resplabel", "text", "", $select_type],
		["select", "Civilité", "locataires_civilite", "flex-10", "respinput", "resplabel", "text", "", $select_civilite],
		["input", "Nom", "locataires_nom", "flex-10", "respinput", "resplabel", "text", "required", defined $result_set->[0]->{locataires_nom} ? $result_set->[0]->{locataires_nom} : ""],
		["input", "Prénom", "locataires_prenom", "flex-10", "respinput", "resplabel", "text", "required", defined $result_set->[0]->{locataires_prenom} ? $result_set->[0]->{locataires_prenom} : ""],
		["input", "Adresse", "locataires_adresse", "flex-21", "respinput", "resplabel", "text", "", defined $result_set->[0]->{locataires_adresse} ? $result_set->[0]->{locataires_adresse} : ""],
		["input", "Code postal", "locataires_cp", "flex-10", "respinput", "resplabel", "text", 'pattern="[0-9]+"', defined $result_set->[0]->{locataires_cp} ? $result_set->[0]->{locataires_cp} : ""],
		["input", "Ville", "locataires_ville", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{locataires_ville} ? $result_set->[0]->{locataires_ville} : ""],
		["input", "Date naissance", "locataires_naissance_date", "flex-10", "respinput", "resplabel", "text", $date_options, defined $result_set->[0]->{locataires_naissance_date} ? $result_set->[0]->{locataires_naissance_date} : ""],
		["input", "Lieu naissance", "locataires_naissance_lieu", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{locataires_naissance_lieu} ? $result_set->[0]->{locataires_naissance_lieu} : ""],
		["input", "Téléphone", "locataires_telephone", "flex-10", "respinput", "resplabel", "text", "",, defined $result_set->[0]->{locataires_telephone} ? $result_set->[0]->{locataires_telephone} : ""],
		["input", "Courriel", "locataires_courriel", "flex-21", "respinput", "resplabel", "text", "", defined $result_set->[0]->{locataires_courriel} ? $result_set->[0]->{locataires_courriel} : ""],
		["input", "Commentaire 1", "locataires_com1", "flex-15", "respinput", "resplabel", "text", "", defined $result_set->[0]->{locataires_com1} ? $result_set->[0]->{locataires_com1} : ""],
		["input", "&nbsp;", "submit_loc", "flex-10", "respbtn btn-vert", "resplabel", "submit", "", "Valider"]
	);
	
	if (defined $args->{modifierloc}) {
		# Formulaire Modification du locataire
		$loc_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?baux=2&code=' . ($args->{code} || '').'&archive=' . ($args->{archive}).'" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="green centrer"> Modification du locataire : '.($result_set->[0]->{locataires_nom}|| '').' '.($result_set->[0]->{locataires_prenom}|| '').' </div>
			</div>
			
			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=2&code=' . ($args->{code} || '').'&id_loc='.($result_set->[0]->{id_loc}|| '').'&modifierloc=0>
			<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=update value="1">
			<input type=hidden name=archive value="'.($args->{archive} || 0).'">
			</form>
			<br>
		' ;
		
	} else {
		# Formulaire nouveau locataire
		$loc_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?baux=2&code=' . ($args->{code} || '').'" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="green centrer"> Enregistrement d\'un nouveau locataire ou garant pour le bail ' . ($args->{code} || '').' </div>
			</div>
			
		<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=2&code=' . ($args->{code} || '').'>
		<div class="respform">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=ajout value="1">
			<input type=hidden name=archive value="'.($args->{archive} || 0).'">
			</form>
			<br>
		';
	
	}
	
	return $loc_list;
}

#/*—————————————— Formulaire Ajout de Tag ——————————————*/
sub forms_ajouter_tag {
	
	# définition des variables
	my ( $r, $args, $new_tag_href ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors) ;
	my ($content, $id_entry, $contenu_web_ecri_rec) = ('', '', '');
	my $reqid = Base::Site::util::generate_reqline();
	
	# Génération formulaire choix de documents
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $onchange_type = 'onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};"';
	my ($form_name_doc1, $form_id_doc1) = ('tags_doc', 'tags_doc_'.$reqid.'');
	my $selected_document1 = (defined($args->{tags_doc}) && $args->{tags_doc} ne '') || (defined($args->{id_name}) && defined($args->{label8}) && $args->{label8} eq '1') ? ($args->{tags_doc} || $args->{id_name}) : undef;
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected_document1, $form_name_doc1, $form_id_doc1, $onchange_type, 'class=respinput', '');

	my $hidden = '';
	
	if (defined $args->{logements}) {
		$hidden = '<input type=hidden name="logements" value="'.($args->{logements} || '').'">
		<input type=hidden name="modifier" value=1>';
	} elsif (defined $args->{baux}) {
		$hidden = '<input type=hidden name="baux" value="'.($args->{baux} || '').'">';
	}
	
	# Formulaire de génération des écritures récurrentes 	
	my $tag_list = '
    <div class="warninf">
		<form action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere method="POST">
		<div class="respform" style="justify-content: center;">
			<div class="flex-25"><input class="respinput" type=text placeholder="Entrer ou sélectionner le nom du tag" name="tags_nom" value="'.($args->{code} || '').'" required onclick="liste_search_tag(this.value)" list="taglist"><datalist id="taglist"></datalist></span></div>
			<div class="flex-25">'.$document_select1.'</div>
			<input type=hidden name="add_tag" value=1>
			<input type=hidden name="archive" value='.($args->{archive} || 0).'>
			<input type=hidden name="code" value='.($args->{code} || '').'>
			'.$hidden.'
			<div class="flex-21"><input type=submit class="respbtn btn-vert" value=Ajouter ></div>
		</div>
		</form>
	</div>
    ' ;
		
	$content .= ($tag_list || '') ;

	return $content ;

}#sub forms_ajouter_tag 

#/*—————————————— Formulaire Supprimer de Tag ——————————————*/
sub forms_supprime_tag {
	
	# définition des variables
	my ( $r, $args, $add_tag_href ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors) ;
	my ($content, $id_entry, $contenu_web_ecri_rec) = ('', '', '');
	my $reqid = Base::Site::util::generate_reqline();
	
	#Requête tbldocuments => Recherche de la liste des documents enregistrés
	$sql = '
	SELECT t1.id_name, t2.tags_nom FROM tbldocuments t1
	LEFT JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client and t1.id_name = t2.tags_doc
	WHERE t1.id_client = ? AND (t1.fiscal_year = ? OR (t1.multi = \'t\' AND (t1.last_fiscal_year IS NULL OR t1.last_fiscal_year >= ?)))
    AND EXISTS (
        SELECT 1 
        FROM tbldocuments_tags t3 
        WHERE t3.id_client = t1.id_client 
            AND t3.tags_doc = t1.id_name 
            AND t3.tags_nom = ?
    )
	ORDER BY t2.tags_nom, t1.id_name' ;
	my $array_of_documents_tags;	
	my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}, $args->{code}) ;
    eval { $array_of_documents_tags = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 )} ;
    my $tags_select = '<select class=respinput name=del_tags id=del_tags>
	<option value="" selected>--Sélectionner le tag--</option>' ;
	for ( @$array_of_documents_tags ) {
	$tags_select .= '<option value="' . $_->{tags_nom} . ',' . $_->{id_name} . '">' . $_->{tags_nom} . ' - ' . $_->{id_name} . '</option>' ;
	}
	$tags_select .= '</select>' ;
	
	my $hidden = '';
	
	if (defined $args->{logements}) {
		$hidden = '<input type=hidden name="logements" value="'.($args->{logements} || '').'">
		<input type=hidden name="modifier" value=1>';
	} elsif (defined $args->{baux}) {
		$hidden = '<input type=hidden name="baux" value="'.($args->{baux} || '').'">';
	}
	
	# Formulaire de génération des écritures récurrentes 	
	my $tag_list = '
    <div class="warninf">

		<form action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere method="POST">
		<div class="respform" style="justify-content: center;">
			<div class="flex-30">'.$tags_select.'</div>
			<input type=hidden name="supprimer_tag" value=1>
			<input type=hidden name="archive" value='.($args->{archive} || 0).'>
			<input type=hidden name="code" value='.($args->{code} || '').'>
			'.$hidden.'
			<div class="flex-21"><input type=submit class="respbtn btn-vert" value=Supprimer ></div>
		</div>
		</form>

	</div>
    ' ;
		
	$content .= ($tag_list || '') ;

	return $content ;

}#sub forms_supprime_tag 
		
#/*—————————————— Page Action quittance ——————————————*/
sub action_quittance {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my (@bind_array, $content, $item_num, $loc_list, $numero_piece, $sql, $equilibre, $difference, $libelle_journal) = ('', '','1', '', '', '', '', '', '');
    my $reqid = Base::Site::util::generate_reqline();
	if ( defined $args->{baux} && defined $args->{ajouter3} && $args->{ajouter3} ne '' && !$args->{ventiler}) {
	$args->{baux} = 1;
				
	$sql = 'SELECT * FROM tbljournal WHERE id_client = ? and fiscal_year = ?
	AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND id_line = ?);';
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $args->{ajouter3}) ;
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array) };
	
	if (@$result_set) {
		# Initialiser les totaux de débit et crédit
		my $total_debit = 0;
		my $total_credit = 0;
		my ($year, $month, $lib, $idfacture, $lettrage, $latest_date, $lib_description);

		# Parcourir les résultats de la requête
		foreach my $row (@$result_set) {
			$idfacture = $row->{id_facture} if $row->{id_line} eq $args->{ajouter3};
			$lib = $row->{libelle} if $row->{credit} == 0;
			$lettrage = $row->{lettrage};
			# Ajouter les montants de débit et crédit aux totaux
			$total_debit += $row->{debit};
			$total_credit += $row->{credit};
			
			# Convertir les dates en objets Time::Piece pour une comparaison correcte
			my $current_date = Time::Piece->strptime($row->{date_ecriture}, "%d/%m/%Y") if $row->{id_line} eq $args->{ajouter3};
			my $latest_date_obj = Time::Piece->strptime($latest_date, "%d/%m/%Y") if $latest_date;

			# Vérifier si la date de la ligne actuelle est plus récente que la date précédente
			if (defined $current_date && (!$latest_date_obj || $current_date > $latest_date_obj)) {
				$latest_date = $row->{date_ecriture};
			}
		}
		
			my $dateform1 = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{2})";
			my $dateform2 = "(?<month>0[1-9]|1[0-2])/(?<year>[0-9]{4})";
			
			

			if ($lib =~ /$dateform2/) {
				$year = $+{year};
				$month = $+{month};
				$lib_description = 'la quittance';
			} elsif ($lib =~ /$dateform1/) {
				$year = $+{year};
				$lib_description = 'la quittance';
			} elsif ($lib =~ /caution/i) {
				my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($latest_date);
				$year = $year1;
				$month = $month1;
				$args->{type_quittance} = 'caution' if !defined $args->{type_quittance};
				$lib_description = 'le reçu de caution';
			} elsif ($lib =~ /charge/i) {
				$lib_description = 'les charges';
				$month = 13;
				$args->{type_quittance} = 'charge' if !defined $args->{type_quittance};
				$year = $r->pnotes('session')->{fiscal_year};
			} else {
				$lib_description = '';
			}
		
		my $select_month = '<select style="width: 15%;" class="forms2_input" name="select_month" id="select_month_'.$reqid.'">
		' .	join('', map { "<option value='" . sprintf("%02d", $_) . "'" . ((defined $month && $month eq sprintf("%02d", $_)) || (defined($args->{select_month}) && $args->{select_month} eq sprintf("%02d", $_)) ? ' selected' : '') . '>' . (split(';', 'Janvier;Février;Mars;Avril;Mai;Juin;Juillet;Août;Septembre;Octobre;Novembre;Décembre;Annuelle'))[$_-1] . '</option>' } 1..13) .
		'</select>';
		
		my $type_quittance = Base::Site::util::generate_simple_select('type_quittance', 'type_quittance', 'forms2_input', [['mensuel', 'Quittance mensuelle'], ['charge', 'Quittance charge'], ['caution', 'Reçu caution']], $args->{type_quittance}, '', 'style="width: 17%;"');

		my $parametres_fiscal_year = Base::Site::bdd::get_parametres_fiscal_year($dbh, $r->pnotes('session')->{id_client});
		my $selected_fiscal_year = ((defined $year && $year ne '') || (defined($args->{select_year}) && $args->{select_year} ne '')) ? ($year || $args->{select_year} ) : undef;
		my ($onchange_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year) = ('', 'select_year', 'select_year_'.$reqid.'');
		my $search_fiscal_year = Base::Site::util::generate_fiscal_year($parametres_fiscal_year, $reqid, $selected_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year, $onchange_fiscal_year, 'class="forms2_input"', 'style="width: 15%;"', 0); 

		my $categorie_document = Base::Site::bdd::get_categorie_document($dbh, $r);
		my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'};\"";
		my $selected1 = (defined($args->{libelle_cat_doc}) && $args->{libelle_cat_doc} ne '') ? ($args->{libelle_cat_doc} ) : 'Temp';
		my ($form_name1, $form_id1) = ('libelle_cat_doc', 'libelle_cat_doc_'.$reqid.'');
		my $document_cat_select = Base::Site::util::generate_doc_cat_selector($categorie_document, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style ="width : 17%;"');

		my @champs = (
		["select", "Type", "type_quittance", "flex-21", "respinput", "resplabel", "text", '', defined $type_quittance ? $type_quittance : ""],
		["select", "Mois", "select_month", "flex-21", "respinput", "resplabel", "text", "", defined $select_month ? $select_month : ""],
		["select", "Année", "select_year", "flex-21", "respinput", "resplabel", "text", "", defined $search_fiscal_year ? $search_fiscal_year : ""]
		);
	
		# Vérifier l'équilibre
		if ($total_debit == $total_credit) {
			$equilibre = 'Les écritures sont équilibrées avec un total débit de '.Base::Site::util::affichage_montant($total_debit/100).'€ et un total crédit de '.Base::Site::util::affichage_montant($total_credit/100).'€.
			<br>Souhaitez-vous générer '.($lib_description||'').' pour le logement '.$args->{code}.' ('.$idfacture.') ?
			<br>
			<form method=POST class="wrapper1" >
			<div class="formflexN2">
			<label style="width: 17%;" class="forms2_label" for="type_quittance">Type</label>
			<label style="width: 15%;" class="forms2_label" for="select_month">Période</label>
			<label style="width: 15%;" class="forms2_label" for="select_year">Année</label>
			<label style="width: 17%;" class="forms2_label" for="select_cat">Catégorie</label>
			<label style="width: 30%;" class="forms2_label" for="bypass">Générer le document sans le visualiser ?</label>
			</div>

			<div class="formflexN2">
				'.$type_quittance.'
				'.$select_month.'
				'.$search_fiscal_year.'
				'.$document_cat_select.'
				<input style="margin: 5px; width: 30%; height: 4ch; display: block;" type="checkbox" id="bypass" title="Cocher cette case permet de générer le document sans le vérifier." name="bypass" value="1" checked="">
				<input type=hidden name=lettrage value="'.($args->{ajouter3} || '').'">
				<input type=hidden name=idfacture value="'.$idfacture.'">
				<input type=hidden name="AR" value="'.($latest_date || '').'">
				<input type=hidden name="archive" value='.($args->{archive} || 0).'>
			</div>
			<br>
				<input type="submit" class="button-link" style ="width : 5%;" formaction="gestionimmobiliere?baux=4&code=' . $args->{code}.'&archive=' . $args->{archive}.'" value="Oui">
				<input type="submit" class="button-link" style ="width : 5%;"  formaction="gestionimmobiliere?baux=1&code=' . $args->{code}.'&archive=' . $args->{archive}.'" value="Non">
			
			</form>';
		} elsif ($total_credit <= $total_debit) {
			$equilibre = 'La quittance ne peut être générée car la totalité du règlement n\'est pas présente. <br>Total débit de '.Base::Site::util::affichage_montant($total_debit/100).'€ pour un total crédit de '.Base::Site::util::affichage_montant($total_credit/100).'€.';
		} else {
			my $non_href = 'gestionimmobiliere?baux=1&code='.($args->{code} || '').'&archive='.($args->{archive} || 0).'' ;
			my $oui_href = 'gestionimmobiliere?baux=1&code=' . $args->{code}.'&archive='.($args->{archive} || 0).'&ajouter3='.$args->{ajouter3}.'&ventiler='.$lettrage.'' ;
			$equilibre = 'Les écritures ne sont pas équilibrées avec un total débit de '.Base::Site::util::affichage_montant($total_debit/100).'€ et un total crédit de '.Base::Site::util::affichage_montant($total_credit/100).'€.
			<br>Souhaitez-vous ventiler l\'écriture pour assurer l\'équilibre entre le débit et le crédit ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>';
		}
	} else {
		$equilibre = 'L\'écriture sélectionnée ne possède pas de lettrage !';
	}

	$content .= Base::Site::util::generate_error_message($equilibre) ;
	
	} elsif ( defined $args->{baux} && defined $args->{ajouter3} && defined $args->{ventiler}) {
		
		$args->{baux} = 1;
		my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);
		
		#Nettoie la table tbljournal_staging
		Base::Site::bdd::clean_tbljournal_staging( $r );
		
		$sql = 'SELECT * FROM tbljournal WHERE id_client = ? and fiscal_year = ?
		AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND id_line = ?);';
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $args->{ajouter3}) ;
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array) };
		
		# Initialiser les totaux
		my $total_debit = 0;
		my $total_credit = 0;
		my $recup_debit = 0;
		my $view_debit = 0;
		my $difference = 0;
		my $identry;
			
		if (@$result_set) {
			# Parcourir les résultats de la requête
			foreach my $row (@$result_set) {
				$recup_debit = $row->{debit} if $row->{credit} == 0;
				$identry = $row->{id_entry} if $row->{id_line} eq $args->{ajouter3};
				$view_debit = $row->{credit} if $row->{id_line} eq $args->{ajouter3};
				$total_debit += $row->{debit};
				$total_credit += $row->{credit};
			}
			# Calculer la différence entre débit et crédit
			$difference = $total_credit - $total_debit ;
			$recup_debit = $view_debit - $difference;
			
		}

		#$content .= Base::Site::util::generate_error_message('valeur $idline "'.$idline.'" $total_credit "'.$total_credit.'" et $total_debit "'.$total_debit.'" $difference "'.$difference.'" et $recup_debit "'.$recup_debit.'"') ;
		
		#duplique id_entry
		$sql = '
		INSERT INTO tbljournal_staging (_session_id, id_entry, id_line, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, id_export, lettrage, pointage, recurrent, _token_id ) SELECT ?, t1.id_entry, t1.id_line, t1.id_client, t1.fiscal_year, ?, ?, ?, t1.libelle_journal, t1.numero_compte, t1.date_ecriture, t1.id_paiement, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, t1.id_export, t1.lettrage, t1.pointage, t1.recurrent, ?
		FROM tbljournal t1 
		WHERE t1.id_entry = ? ORDER BY id_line
		' ;
		@bind_array = ( $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $token_id, $identry ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		
		#duplique id_line d'id_entry et remplace par la difference
		$sql = '
		INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, id_export, pointage, recurrent, _token_id ) SELECT ?, t1.id_entry, t1.id_client, t1.fiscal_year, ?, ?, ?, t1.libelle_journal, t1.numero_compte, t1.date_ecriture, t1.id_paiement, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, ?, t1.id_export, t1.pointage, t1.recurrent, ?
		FROM tbljournal t1 
		WHERE t1.id_line = ?
		' ;
		@bind_array = ( $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $difference, $token_id, $args->{ajouter3} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		
		#modifie id_line d'id_entry avec la valeur de debit
		$sql = 'UPDATE tbljournal_staging SET credit = ? where _token_id = ? and id_line = ?' ;
		@bind_array = ( $recup_debit, $token_id, $args->{ajouter3}) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
		
		my ($return_entry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $token_id, $identry);
		
		if ( $error_message ) {
			$content .= Base::Site::util::generate_error_message($error_message);	
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Ventilation de l\'écriture '.$identry.'');
			$args->{restart} = 'gestionimmobiliere?baux&code='.($args->{code} || '').'&archive=' . $args->{archive}.'&ajouter3='.($args->{ajouter3} || '').'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}    
		
	}
    
    return $content;
}

#/*—————————————— Page Affichage Liste des baux en cours BAUX=0——————————————*/
sub Affichage_list_baux {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($html, $sql, @bind_array) = ('', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    my $archive_href = $args->{archive} || 0;
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'dupliquer baux' 				  #
	#######################################################################
	if ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{dupliquer} && $args->{dupliquer} eq '0' ) {
		$sql = 'SELECT * FROM tblimmobilier WHERE id_client = ? and immo_contrat = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=1&amp;code=' . $args->{code}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&amp;code=' . $args->{code}.'&amp;dupliquer=1&amp;ajouter=0' ;
		$html .= Base::Site::util::generate_error_message('Voulez-vous dupliquer le bail '.$args->{code}.' - '.($result_set->[0]->{immo_libelle}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{dupliquer} && $args->{dupliquer} eq '1' ) {
		$sql = 'SELECT * FROM tblimmobilier WHERE id_client = ? and immo_contrat = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		my $loyer = $result_set->[0]->{immo_loyer}/100;
		my $depot = $result_set->[0]->{immo_depot}/100;
		Base::Site::util::formatter_montant_et_libelle(\$loyer, undef);
		Base::Site::util::formatter_montant_et_libelle(\$depot, undef);
		$args->{code} = undef;
        $args->{immo_libelle} = $result_set->[0]->{immo_libelle} || undef;
        $args->{immo_compte} = $result_set->[0]->{immo_compte} || undef;
        $args->{immo_logement} = $result_set->[0]->{immo_logement} || undef;
        $args->{immo_locataire} = $result_set->[0]->{immo_locataire} || undef;
        $args->{immo_date1} = $result_set->[0]->{immo_date1} || undef;
        $args->{immo_date2} = $result_set->[0]->{immo_date2} || undef;
        $args->{immo_com1} = $result_set->[0]->{immo_com1} || undef;
        $args->{immo_com2} = $result_set->[0]->{immo_com2} || undef;
        $args->{immo_entry} = $result_set->[0]->{immo_entry} || undef;
        $args->{immo_loyer} = $loyer || undef;
        $args->{immo_depot} = $depot || undef;
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer baux' 					  #
	#######################################################################
    #demande de suppression; afficher lien d'annulation/confirmation
	if ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{supprimer} && $args->{supprimer} eq '0' ) {
		$sql = '
		SELECT * FROM tblimmobilier t1
		LEFT JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client  AND t1.immo_contrat = t2.tags_nom
		WHERE t1.id_client = ? and immo_contrat = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
		my $count = scalar @$result_set;
		
		if (defined $result_set->[0]->{tags_nom}){
			$html .= Base::Site::util::generate_error_message('Impossible de supprimer le bail '.$args->{code}.', il existe des documents liés au tag #'.$args->{code}.'') ;
		} else {
			my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=1&archive=' . $args->{archive}.'' ;
			my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&code=' . $args->{code}.'&archive=' . $args->{archive}.'&supprimer=1' ;
			$html .= Base::Site::util::generate_error_message('Voulez-vous supprimer le bail '.$args->{code}.' - '.($result_set->[0]->{immo_libelle}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
		}
		
	} elsif ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{supprimer} && $args->{supprimer} eq '1' ) {
			if (defined $args->{code} && $args->{code} eq '') {
				$html .= Base::Site::util::generate_error_message('Impossible le bail n\'a pas été sélectionné') ;	
			} else {	
				my $sql = 'SELECT * FROM tblimmobilier WHERE id_client = ? and immo_contrat = ?';
				my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
				#demande de suppression confirmée
				$sql = 'DELETE FROM tblimmobilier WHERE id_client = ? AND immo_contrat = ?' ;
				@bind_array = ( $r->pnotes('session')->{id_client}, $args->{code} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					if ($@ =~ /viole la contrainte|violates/) {
						$html .= Base::Site::util::generate_error_message('Impossible de supprimer le bail '.$args->{code}.', celui-ci est référencé');
					} else {
						$html .= Base::Site::util::generate_error_message(Encode::decode_utf8($@));
					}
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Suppression du bail '.$args->{code}.' - '.($result_set->[0]->{immo_libelle}|| '').'');
					$args->{restart} = 'gestionimmobiliere';
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé 
				}
		}
	}
	
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' nouveau bail		  #
	#######################################################################
    if ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_libelle(\$args->{immo_libelle}, \$args->{immo_com1}, \$args->{immo_com2});
        $args->{code} ||= undef;
        $args->{immo_libelle} ||= undef;
        $args->{immo_compte} ||= undef;
        $args->{immo_logement} ||= undef;
        $args->{immo_locataire} ||= undef;
        $args->{immo_date1} ||= undef;
        $args->{immo_date2} ||= undef;
        $args->{immo_archive} ||= undef;
        $args->{immo_com1} ||= undef;
        $args->{immo_com2} ||= undef;
        $args->{immo_entry} ||= undef;
        $args->{immo_loyer} ||= undef;
        $args->{immo_depot} ||= undef;

		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [22, $args->{immo_logement}], [23, $args->{code}], [20, $args->{immo_libelle}]);
			
		if ($erreur) {
			$html .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
		} else {
			$sql = 'INSERT INTO tblimmobilier (id_client, fiscal_year, immo_contrat, immo_libelle, immo_compte, immo_logement, immo_locataire, immo_date1, immo_date2, immo_archive, immo_com1, immo_com2, immo_entry, immo_loyer, immo_depot ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
			@bind_array = (
				$r->pnotes('session')->{id_client},
				$r->pnotes('session')->{fiscal_year},
				$args->{code},
				$args->{immo_libelle},
				$args->{immo_compte},
				$args->{immo_logement},
				$args->{immo_locataire},
				$args->{immo_date1},
				$args->{immo_date2},
				($args->{immo_archive} || 'f'),
				$args->{immo_com1},
				$args->{immo_com2},
				$args->{immo_entry},
				$args->{immo_loyer}*100,
				$args->{immo_depot}*100
			);
			eval { $dbh->do($sql, undef, @bind_array) };

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$html .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom et un code de logement') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$html .= Base::Site::util::generate_error_message('Le bail avec le code '.$args->{code}.' existe déjà !!') ;
				} else {$html .= Base::Site::util::generate_error_message($@);}
			} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Ajout du bail '.$args->{code}.' - '.$args->{immo_libelle}.'');
			$args->{restart} = 'gestionimmobiliere?baux=1&code=' . $args->{code}.'&archive=' . $args->{archive}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}	
		}

	}

   ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				  #
	#######################################################################
    if ( defined $args->{baux} && $args->{baux} eq 0 && defined $args->{maj} && $args->{maj} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_montant_et_libelle(\$args->{immo_loyer}, undef);
		Base::Site::util::formatter_montant_et_libelle(\$args->{immo_depot}, undef);
		Base::Site::util::formatter_libelle(\$args->{immo_libelle}, \$args->{immo_com1}, \$args->{immo_com2});
        $args->{code} ||= undef;
        $args->{immo_libelle} ||= undef;
        $args->{immo_compte} ||= undef;
        $args->{immo_logement} ||= undef;
        $args->{immo_locataire} ||= undef;
        $args->{immo_date1} ||= undef;
        $args->{immo_date2} ||= undef;
        $args->{immo_archive} ||= 'f';
        $args->{immo_com1} ||= undef;
        $args->{immo_com2} ||= undef;
        $args->{immo_entry} ||= undef;
        $args->{immo_loyer} ||= undef;
        $args->{immo_depot} ||= undef;
        
            
		if (defined $args->{immo_archive} && $args->{immo_archive} eq 't') {
			$args->{restart} = 'gestionimmobiliere?baux=0&code=' . $args->{code}.'&modifier=1&archive=1';
		} else {
			$args->{restart} = 'gestionimmobiliere?baux=0&code=' . $args->{code}.'&modifier=1';
		}
        
		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [23, $args->{code}], [22, $args->{immo_logement}], [20, $args->{immo_libelle}]);
		if ($erreur) {
			$html .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			
		} else {
	    # Préparer la requête SQL pour la mise à jour de l'utilisateur
	    $sql = 'UPDATE tblimmobilier set fiscal_year = ?, immo_contrat = ?, immo_libelle = ?, immo_compte = ?, immo_logement = ?, immo_locataire = ?, immo_date1 = ?, immo_date2 = ? , immo_archive = ? , immo_com1 = ?, immo_com2 = ?, immo_entry = ?, immo_loyer = ?, immo_depot = ? where id_client = ? and immo_contrat = ? ' ;
	    @bind_array = ( $r->pnotes('session')->{fiscal_year}, $args->{code}, $args->{immo_libelle}, $args->{immo_compte}, $args->{immo_logement}, $args->{immo_locataire}, $args->{immo_date1}, $args->{immo_date2}, ($args->{immo_archive} || 'f'), $args->{immo_com1}, $args->{immo_com2}, $args->{immo_entry}, $args->{immo_loyer}*100, $args->{immo_depot}*100, $r->pnotes('session')->{id_client}, $args->{old_code}) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$html .= Base::Site::util::generate_error_message('Impossible le nom du bail est vide') ;
				} elsif ( $@ =~ /existe|already exists/ ){
				$html .= Base::Site::util::generate_error_message('Le bail avec le code '.$args->{code}.' existe déjà') ;
				} else {
				$html .= Base::Site::util::generate_error_message($@);}
			} else {
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
		}
	}
	
	$html .= '
		<form id="menulogement" class="wrapper1" action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere method="POST">
		<div class="formflexN1 flex1" style="font-weight: bold;" id="logement_section_1">
		<input class="custom-radio" type="radio" id="baux_1" name="archive" value="0" ' .(defined $args->{baux} && (!defined $args->{archive} || (defined $args->{archive} && $args->{archive} eq '0')) ? 'checked' : '') . ' onclick="submit();">
		<label for="baux_1">Baux en cours</label>
		<input class="custom-radio" type="radio" id="baux_2" name="archive" value="1" ' .(defined $args->{archive} && $args->{archive} eq '1' ? ' checked' : '') . ' onclick="submit();">
		<label for="baux_2">Baux archivés</label>
		</div>
	</form>';
	
	my $info_tblimmobilier = '';
    my $var_archive = '';
    
    if (defined $args->{archive} && $args->{archive} eq 1) {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 1);
		$var_archive = 'archivés';
	} else {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 2);
		$var_archive = 'en cours';
	}
	
    $html .= '<div class="Titre10">
	<span class=check><a href="gestionimmobiliere?baux=0&ajouter" title="Cliquer pour ajouter un bail" class="label3">
	Ajouter un bail de location<span class="plus">+</span></a></span>
	<div class="centrer"> Liste des baux '.$var_archive.'</div></div>
	';
	
	#ligne des en-têtes Frais en cours
	$html .= '
	<ul class="wrapper100">
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 0.5%;">&nbsp;</span>
	<span class=headerspan style="width: 9%;text-align: left">Référence</span>
	<span class=headerspan style="width: 10%;text-align: left">Date de début</span>
	<span class=headerspan style="width: 10%;text-align: left">Date de fin</span>
	<span class=headerspan style="width: 20%;text-align: left">Libellé</span>
	<span class=headerspan style="width: 14%;text-align: left">Logement</span>
	<span class=headerspan style="width: 9%;text-align: right">Compte</span>
	<span class=headerspan style="width: 9%;text-align: right">Loyer</span>
	<span class=headerspan style="width: 9%;text-align: right">Dépôt</span>
	<span class=headerspan style="width: 9.5%;">&nbsp;</span>
	<div class=spacer></div></div></li>
	' ;

 	if (@$info_tblimmobilier) {
		for ( @$info_tblimmobilier ) {
			
			my $dupliquer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&code='.($_->{immo_contrat}||'').'&dupliquer=0&archive='.$archive_href.'' ;
			my $supprimer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&code='.($_->{immo_contrat}||'').'&supprimer=0&archive='.$archive_href.'' ;
			my $modifier_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&code=' .($_->{immo_contrat}||'').'&modifier=1&archive='.$archive_href.'' ;
			my $item_href = $args->{baux} || 1;
			$item_href = 1 if $item_href == 0;
			
			my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{immo_doc1}, 1);
						
			my $baux_ref_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux='.$item_href.'&amp;code=' . $_->{immo_contrat}.'&archive='.$archive_href.'';
			
			#ligne d'en-têtes
			$html .= '
				<li class=listitem3 id="line_'.$_->{immo_contrat}.'"><a href="' . $baux_ref_href . '">
				<div class=flex-table><div class=spacer></div>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<span class=blockspan style="width: 9%;text-align: left">' . ( $_->{immo_contrat} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 10%;text-align: left">' . ( $_->{immo_date1} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 10%;text-align: left">' . ( $_->{immo_date2} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 20%;text-align: left">' . ( $_->{immo_libelle} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 14%;text-align: left">' . ($_->{immo_logement} .'-'. $_->{biens_nom}   || '&nbsp;' ). '</span>
				<span class=blockspan style="width: 9%;text-align: right" title="'.($_->{libelle_compte} || '').'">' . ( $_->{immo_compte} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 9%;text-align: right">' . (Base::Site::util::affichage_montant($_->{immo_loyer}/100) || '0.00' ). '</span>
				<span class=blockspan style="width: 9%;text-align: right">' . (Base::Site::util::affichage_montant($_->{immo_depot}/100) || '0.00' ). '</span>
				</a>
				<span class=blockspan style="width: 1.5%;">&nbsp;</span>
				<form method="post"><span class="blockspan image" style="width: 2%;"><input type="image" src="/Compta/style/icons/modifier.png" style="border: 0;" height="14" width="14" alt="modifier" formaction="' . $modifier_href . '" onclick="submit()" title="Modifier"></span></form>
				<form method="post"><span class="blockspan" style="width: 2%;">'.$http_link_documents1.'</span></form>
				<form method="post"><span class=blockspan style="width: 2%;"><input type="image" src="/Compta/style/icons/duplicate.png" style="border: 0;" height="14" width="14" alt="dupliquer" formaction="' . $dupliquer_href . '" onclick="submit()" title="Dupliquer"></span></form>
				<form method="post"><span class=blockspan style="width: 2%;"><input type="image" src="/Compta/style/icons/delete.png" style="border: 0;" height="14" width="14" alt="supprimer" formaction="' . $supprimer_href . '" onclick="submit()" title="Supprimer" ></span></form>
				<div class=spacer></div></div></li>
			' ;
		}
		$html .= '</ul>';
	}  else {
		$html .= '<div class="warnlite">*** Aucun bail trouvé ***</div>';
	}
	
	if (defined $args->{baux} && $args->{baux} eq 0 && defined $args->{modifier} && $args->{modifier} eq 1 && defined $args->{code} && $args->{code} ne '') {
		$html .= form_nouveau_bail( $r, $args) ; 
	}
	
	if (defined $args->{baux} && $args->{baux} eq 0 && defined $args->{ajouter}){
		$html .= '<fieldset class="centrer Titre09 pretty-box"> '.form_nouveau_bail( $r, $args ).'</fieldset><br>' ; 
	} 
    
	return $html;
}

#/*—————————————— Page Affichage Liste des écritures BAUX=1 ——————————————*/
sub Affichage_list_ecriture {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($html, $sql) = ('', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Générer' la quittance	 				  #
	#######################################################################
	if ( defined $args->{baux} && $args->{baux} eq 1 && defined $args->{ajouter3} && $args->{ajouter3} && $r->pnotes('session')->{Exercice_Cloture} ne '1') {
		$html .= action_quittance( $r, $args) ; 
	}
    
    $html .= '<div class="Titre10"><div class="centrer"> Liste des écritures </div></div>' ;
	
	$sql = 'SELECT * FROM tblimmobilier WHERE id_client = ? and immo_contrat = ?';
	my $result_logement = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
	
	if (defined $result_logement->[0]->{immo_compte} && $result_logement->[0]->{immo_compte} ne '') {
			
		my ( $lettrage_href, $lettrage_link, $lettrage_input, $lettrage_base ) ;
    	my ( $pointage_href, $pointage_link, $pointage_input, $pointage_base ) ; 	
    
		$sql = '
		SELECT t1.id_entry, t1.id_line, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, t1.documents1 as documents1, t1.documents2 as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, t1.debit as debit_brut, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, id_export, to_char((sum(credit-debit) over(PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle))/100::numeric, \'999G999G999G990D00\') as solde, lettrage, pointage
		FROM tbljournal t1
		WHERE t1.id_client = ? AND t1.fiscal_year = ? AND numero_compte = ? 
		ORDER BY numero_compte, date_ecriture, id_facture, libelle, id_line
		' ;

		my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $result_logement->[0]->{immo_compte} ) ;
		my $result_compte_fourn_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
		
		my $id_entry = '' ;
		my $id_entry_href = '' ;
			
		$html .= '<form method="post"><input type=hidden name="archive" value='.($args->{archive} || 0).'><ul>';
			
		# Générer une liste de tous les mois de l'année
		my @mois_de_l_annee = (1..13);
		# Tableau des noms des mois
		my @noms_des_mois = qw(Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre Annuelle);
			
		my $select_month .= '<select name="month_select_" id="month_select_">';	
		$select_month .= '<option value="" selected>-- choix ----</option>';	
		$select_month .= '<option value="charge" >Charge</option>';	
		for my $month (1..13) {
			$select_month .= '<option value="' . $month . '">' . $noms_des_mois[$month - 1] . '</option>';
		}
		$select_month .= '</select>';	
			
		$pointage_base = '<input type=checkbox id=id value=value style="vertical-align: middle;" onclick="pointage(this, \'' . ($result_logement->[0]->{immo_compte} || '&nbsp;'). '\')">' ;
    	$lettrage_base = '<input type=text id=id style="margin-left: 0.5em; padding: 0; width: 7ch; height: 1em; text-align: right;" value=value placeholder=&rarr; oninput="lettrage(this, \'' . ($result_logement->[0]->{immo_compte} || '&nbsp;') . '\')">' ;
		my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $result_logement->[0]->{immo_compte} ) .'';
		
		#ligne d'en-têtes
		$html .= '
		<li class="style1"><div class=flex-table><div class=spacer></div>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<span class=headerspan style="width: 8%; text-align: left;">Date</span>
		<span class=headerspan style="width: 8%; text-align: left;">Journal</span>
		<span class=headerspan style="width: 11%; text-align: left;">Pièce</span>
		<span class=headerspan style="width: 25%; text-align: left;">Libellé</span>
		<span class=headerspan style="width: 8%; text-align: right;">Débit</span>
		<span class=headerspan style="width: 8%; text-align: right;">Crédit</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 7%; text-align: right;">Lettrage</span>
		<span class=headerspan style="width: 5%;">&nbsp;</span>
		<span class=headerspan style="width: 8%; text-align: right;">Solde</span>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<div class=spacer></div></div></li>
		' ;
			
		for ( @$result_compte_fourn_set ) {
				
			my $creer = '&nbsp;';
					
			#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
			unless ($_->{id_entry} eq $id_entry ) {
				#cas particulier de la première entrée de la liste : pas de liste précédente
				unless ( $id_entry ) {
					$html .= '<li id="line_'.$reqid.'" class="listitem3">';
				} else {
					$html .= '</a></li><li class="listitem3">';
				}
			}
			
			#marquer l'entrée en cours
			$id_entry = $_->{id_entry} ;
				
			#lien de modification de l'entrée
			my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry}.'';
				
			my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents1}, 1);
			my $http_link_documents2 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents2}, 2);
			
			
			$sql = 'SELECT id_client FROM tbllocked_month 
			WHERE id_client = ? and ( id_month = to_char(?::date, \'MM\') ) AND fiscal_year = ?';
			@bind_array = ( $r->pnotes('session')->{id_client}, $_->{date_ecriture}, $r->pnotes('session')->{fiscal_year}) ;
			my $result_block = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
	
				
			my $lettrage_pointage = '&nbsp;';
			my $lettrage_id = 'id=' . $_->{id_line}.'';
			( $lettrage_input = $lettrage_base ) =~ s/id=id/$lettrage_id/ ;
			my $lettrage_value = ( $_->{lettrage} ) ? 'value=' . $_->{lettrage} : '' ;
			$lettrage_input =~ s/value=value/$lettrage_value/ ;
			
			if (defined $result_block && $result_block eq $r->pnotes('session')->{id_client}) {
			$lettrage_pointage .= ( $_->{lettrage} || '&nbsp;' );
			} else {
			$lettrage_pointage .= $lettrage_input ;
			}
	
			if ($_->{debit_brut} == 0 && (!$_->{documents1} || $_->{documents1} eq '') && $r->pnotes('session')->{Exercice_Cloture} ne '1') {
				$creer = '<a href="gestionimmobiliere?baux=1&code='.($args->{code} || '').'&ajouter3='.($_->{id_line}).'&archive='.$args->{archive}.'" title="Cliquer pour générer la quittance" class="label3">Générer</a>';
			}
		
			$html .= '
			<div class=flex-table><div class=spacer></div><a href="' . $id_entry_href . '">
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan style="width: 8%; text-align: left;">' . $_->{date_ecriture} . '</span>
			<span class=displayspan style="width: 8%; text-align: left;">' . $_->{libelle_journal} .'</span>
			<span class=displayspan style="width: 11%; text-align: left;">' . $_->{id_facture} . '</span>
			<span class=displayspan style="width: 25%; text-align: left;">' . $_->{libelle} . '</span>
			</a>
			<span class=displayspan style="width: 8%; text-align: right;">' . $_->{debit} . '</span>
			<span class=displayspan style="width: 8%; text-align: right;">' .  $_->{credit} . '</span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan style="width: 7%;">' . $lettrage_pointage . '</span>
			<span class=displayspan style="width: 0.5%;">&nbsp;</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents1 . '</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents2 . '</span>
			<span class=displayspan style="width: 8%; text-align: right;">' . $_->{solde} . '</span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan style="width: 4%;">'.$creer.'</span>
			<div class=spacer></div></div>
			' ;
		}
			
		#on clot la liste s'il y avait au moins une entrée dans le journal
		$html .= '</a></li>' if ( @$result_compte_fourn_set ) ;
		# Add a submit button to the form
		$html .= '</ul></form>';
	} else {
		#aucune écriture
		$html .= Base::Site::util::generate_error_message('*** Aucune écriture à afficher. ***
		<br> Veuillez vérifier qu\'un compte client <a class="nav" href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=0&code=' . $args->{code}.'&modifier=1&archive=' . $args->{archive}.'">(cliquer ici)</a> a bien été sélectionné sur le bail et qu\'il existe des écritures pour ce compte. ') ;
	}
	
		
	return $html;
}

#/*—————————————— Page Affichage Liste des Locataires et Garants BAUX=2 ——————————————*/
sub Affichage_list_locataires {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($content, $sql, @bind_array) = ('', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajout' nouveau locataire/garant#
	#######################################################################
    if ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{ajout} && $args->{ajout} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_libelle(\$args->{locataires_nom}, \$args->{locataires_prenom}, \$args->{locataires_adresse}, \$args->{locataires_ville}, \$args->{locataires_naissance_lieu}, \$args->{locataires_com1}, \$args->{locataires_com2});
        
        $args->{code} ||= undef;
		$args->{locataires_ref} ||= undef;
		$args->{locataires_contrat} ||= undef;
		$args->{locataires_type} ||= undef;
		$args->{locataires_civilite} ||= undef;
		$args->{locataires_nom} ||= undef;
		$args->{locataires_prenom} ||= undef;
		$args->{locataires_adresse} ||= undef;
		$args->{locataires_cp} ||= undef;
		$args->{locataires_ville} ||= undef;
		$args->{locataires_naissance_date} ||= undef;
		$args->{locataires_naissance_lieu} ||= undef;
		$args->{locataires_telephone} ||= undef;
		$args->{locataires_courriel} ||= undef;
		$args->{locataires_doc1} ||= undef;
		$args->{locataires_com1} ||= undef;
		$args->{locataires_com2} ||= undef;

		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [24, $args->{locataires_prenom}], [23, $args->{locataires_ref}], [20, $args->{locataires_nom}]);
			
		if ($erreur) {
			$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
		} else {
			$sql = 'INSERT INTO tblimmobilier_locataire (id_client, fiscal_year, locataires_ref, locataires_contrat, locataires_type, locataires_civilite, locataires_nom, locataires_prenom, locataires_adresse, locataires_cp, locataires_ville, locataires_naissance_date, locataires_naissance_lieu, locataires_telephone, locataires_courriel, locataires_com1, locataires_com2 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
			@bind_array = (
				$r->pnotes('session')->{id_client},
				$r->pnotes('session')->{fiscal_year},
				$args->{locataires_ref},
				$args->{code},
				$args->{locataires_type},
				$args->{locataires_civilite},
				$args->{locataires_nom},
				$args->{locataires_prenom},
				$args->{locataires_adresse},
				$args->{locataires_cp},
				$args->{locataires_ville},
				$args->{locataires_naissance_date},
				$args->{locataires_naissance_lieu},
				$args->{locataires_telephone},
				$args->{locataires_courriel},
				$args->{locataires_com1},
				$args->{locataires_com2}
			);
			eval { $dbh->do($sql, undef, @bind_array) };

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom et un prénom') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Cet enregistrement existe déjà !!') ;
				} else {$content .= Base::Site::util::generate_error_message($@);}
			} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Ajout du '.$args->{locataires_type}.' '.$args->{locataires_civilite}.' '.$args->{locataires_nom}.' pour le Bail '.$args->{code}.'');
			$args->{restart} = 'gestionimmobiliere?baux=2&code=' . $args->{code}.'&archive=' . $args->{archive}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}	
		}
	}
    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer locataire' 		  #
	#######################################################################
    #demande de suppression; afficher lien d'annulation/confirmation
	if ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{supprimerloc} && $args->{supprimerloc} eq '0' ) {
		$sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and id_loc = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{id_loc}) };
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&archive=' . $args->{archive}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&id_loc=' . $args->{id_loc}.'&supprimerloc=1&archive=' . $args->{archive}.'' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le locataire '.($result_set->[0]->{locataires_nom}|| '').' '.($result_set->[0]->{locataires_prenom}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{supprimerloc} && $args->{supprimerloc} eq '1' ) {
			if (defined $args->{id_loc} && $args->{id_loc} eq '') {
				$content .= Base::Site::util::generate_error_message('Impossible le locataire n\'a pas été sélectionné') ;	
			} else {	
				$sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and id_loc = ?';
				my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{id_loc}) };
				#demande de suppression confirmée
				$sql = 'DELETE FROM tblimmobilier_locataire WHERE id_client = ? AND id_loc = ?' ;
				@bind_array = ( $r->pnotes('session')->{id_client}, $args->{id_loc} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					$content .= Base::Site::util::generate_error_message($@);
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Suppression du locataire '.($result_set->[0]->{locataires_nom}|| '').' '.($result_set->[0]->{locataires_prenom}|| '').'');
				}
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'dupliquer loc' 				  #
	#######################################################################
	if ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{dupliquerloc} && $args->{dupliquerloc} eq '0' ) {
		$sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and id_loc = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{id_loc}) };
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&archive=' . $args->{archive}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&id_loc=' . $args->{id_loc}.'&dupliquerloc=1&ajout=0&archive=' . $args->{archive}.'' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous dupliquer le locataire '.($result_set->[0]->{locataires_nom}|| '').' '.($result_set->[0]->{locataires_prenom}|| '').' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{dupliquerloc} && $args->{dupliquerloc} eq '1' ) {
		$sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and id_loc = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{id_loc}) };
		$args->{locataires_ref} = $result_set->[0]->{locataires_ref} || undef;
		$args->{locataires_contrat} = $result_set->[0]->{locataires_contrat} || undef;
		$args->{locataires_type} = $result_set->[0]->{locataires_type} || undef;
		$args->{locataires_civilite} = $result_set->[0]->{locataires_civilite} || undef;
		$args->{locataires_nom} = $result_set->[0]->{locataires_nom} || undef;
		$args->{locataires_prenom} = $result_set->[0]->{locataires_prenom} || undef;
		$args->{locataires_adresse} = $result_set->[0]->{locataires_adresse} || undef;
		$args->{locataires_cp} = $result_set->[0]->{locataires_cp} || undef;
		$args->{locataires_ville} = $result_set->[0]->{locataires_ville} || undef;
		$args->{locataires_naissance_date} = $result_set->[0]->{locataires_naissance_date} || undef;
		$args->{locataires_naissance_lieu} = $result_set->[0]->{locataires_naissance_lieu} || undef;
		$args->{locataires_telephone} = $result_set->[0]->{locataires_telephone} || undef;
		$args->{locataires_courriel} = $result_set->[0]->{locataires_courriel} || undef;
		$args->{locataires_doc1} = $result_set->[0]->{locataires_doc1} || undef;
		$args->{locataires_com1} = $result_set->[0]->{locataires_com1} || undef;
		$args->{locataires_com2} = $result_set->[0]->{locataires_com2} || undef;

	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				  #
	#######################################################################
    if ( defined $args->{baux} && $args->{baux} eq 2 && defined $args->{update} && $args->{update} eq '1' ) {
		my $erreur= '';
		Base::Site::util::formatter_libelle(\$args->{locataires_nom}, \$args->{locataires_prenom}, \$args->{locataires_adresse}, \$args->{locataires_ville}, \$args->{locataires_naissance_lieu}, \$args->{locataires_com1}, \$args->{locataires_com2});
		$args->{locataires_ref} ||= undef;
		$args->{locataires_contrat} ||= undef;
		$args->{locataires_type} ||= undef;
		$args->{locataires_civilite} ||= undef;
		$args->{locataires_nom} ||= undef;
		$args->{locataires_prenom} ||= undef;
		$args->{locataires_adresse} ||= undef;
		$args->{locataires_cp} ||= undef;
		$args->{locataires_ville} ||= undef;
		$args->{locataires_naissance_date} ||= undef;
		$args->{locataires_naissance_lieu} ||= undef;
		$args->{locataires_telephone} ||= undef;
		$args->{locataires_courriel} ||= undef;
		$args->{locataires_doc1} ||= undef;
		$args->{locataires_com1} ||= undef;
		$args->{locataires_com2} ||= undef;
        
		$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [24, $args->{locataires_prenom}], [23, $args->{locataires_ref}], [20, $args->{locataires_nom}]);
		if ($erreur) {
			$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			$args->{modifierloc} = 0;
		} else {
	    # Préparer la requête SQL pour la mise à jour de l'utilisateur
		$sql = 'UPDATE tblimmobilier_locataire SET locataires_ref=?, locataires_type=?, locataires_civilite=?, locataires_nom=?, locataires_prenom=?, locataires_adresse=?, locataires_cp=?, locataires_ville=?, locataires_naissance_date=?, locataires_naissance_lieu=?, locataires_telephone=?, locataires_courriel=?, locataires_com1=?, locataires_com2=? WHERE id_loc=? and id_client=?';
		@bind_array = ($args->{locataires_ref}, $args->{locataires_type}, $args->{locataires_civilite}, $args->{locataires_nom}, $args->{locataires_prenom}, $args->{locataires_adresse}, $args->{locataires_cp}, $args->{locataires_ville}, $args->{locataires_naissance_date}, $args->{locataires_naissance_lieu}, $args->{locataires_telephone}, $args->{locataires_courriel}, $args->{locataires_com1}, $args->{locataires_com2}, $args->{id_loc}, $r->pnotes('session')->{id_client});
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				$args->{modifierloc} = 0;
				if ( $@ =~ /NOT NULL/ ) {
				$content .= Base::Site::util::generate_error_message('Impossible le nom du locataire est vide') ;
				} elsif ( $@ =~ /existe|already exists/ ){
				$content .= Base::Site::util::generate_error_message('Le locataire avec le code '.$args->{id_loc}.' existe déjà') ;
				} else {
				$content .= Base::Site::util::generate_error_message($@);}
			}
		}
	}
		
	$content .= '
	<div class="Titre10"><span class=check>
	<a href="gestionimmobiliere?baux=2&code='.($args->{code} || '').'&ajout&archive='.$args->{archive}.'" title="Cliquer pour ajouter un locataire ou garant" class="label3">
	Ajouter un locataire ou garant<span class="plus">+</span></a></span>
	<div class="centrer"> Liste des Locataires et Garants </div></div>' ;
			
	$sql = 'SELECT * FROM tblimmobilier_locataire WHERE id_client = ? and locataires_contrat = ? ORDER BY id_loc';
	my $result_locataires = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}) };
	
	#ligne des en-têtes Frais en cours
	$content .= '
	<ul class="wrapper100">  
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 0.5%;">&nbsp;</span>
	<span class=headerspan style="width: 8%;text-align: left">Référence</span>
	<span class=headerspan style="width: 8%;text-align: left">Type</span>
	<span class=headerspan style="width: 7%;text-align: left">Civilité</span>
	<span class=headerspan style="width: 9%;text-align: left">Nom</span>
	<span class=headerspan style="width: 9%;text-align: left">Prénom</span>
	<span class=headerspan style="width: 10%;text-align: left">Date naissance</span>
	<span class=headerspan style="width: 10%;text-align: left">Lieu naissance</span>
	<span class=headerspan style="width: 10%;text-align: left">Téléphone</span>
	<span class=headerspan style="width: 19%;text-align: left">Courriel</span>
	<span class=headerspan style="width: 9.5%;">&nbsp;</span>
	<div class=spacer></div></div></li>
	' ;
		
	if (@$result_locataires) {

		for ( @$result_locataires ) {
				
			my $dupliquer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&id_loc='.($_->{id_loc}).'&dupliquerloc=0&archive='.$args->{archive}.'' ;
			my $modifier_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&id_loc='.($_->{id_loc}).'&modifierloc=0&archive='.$args->{archive}.'' ;
			my $supprimer_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=2&code=' . $args->{code}.'&id_loc='.($_->{id_loc}).'&supprimerloc=0&archive='.$args->{archive}.'' ;

			my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{locataires_doc1}, 1);

			#ligne d'en-têtes
			$content .= '
			<li class=style1 id="line_'.$_->{id_loc}.'">
			<div class=flex-table><div class=spacer></div>
			<span class=displayspan style="width: 0.5%;">&nbsp;</span>
			<span class=displayspan style="width: 8%;text-align: left">' . ( $_->{locataires_ref} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 8%;text-align: left">' . ( $_->{locataires_type} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 7%;text-align: left">' . ( $_->{locataires_civilite} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 9%;text-align: left">' . ( $_->{locataires_nom} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 9%;text-align: left">' . ( $_->{locataires_prenom} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 10%;text-align: left">' . ( $_->{locataires_naissance_date} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 10%;text-align: left">' . ( $_->{locataires_naissance_lieu} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 10%;text-align: left">' . ( $_->{locataires_telephone} || '&nbsp;' ) . '</span>	
			<span class=displayspan style="width: 19%;text-align: left">' . ( $_->{locataires_courriel} || '&nbsp;' ) . '</span>
			<span class=displayspan style="width: 1.5%;">&nbsp;</span>
			<form method="post"><span class="displayspan image" style="width: 2%;"><input type="image" src="/Compta/style/icons/modifier.png" style="border: 0;" height="14" width="14" alt="modifier" formaction="' . $modifier_href . '" onclick="submit()" title="Modifier"></span></form>
			<form method="post"><span class=displayspan style="width: 2%;">'.$http_link_documents1.'</span></form>
			<form method="post"><span class=displayspan style="width: 2%;"><input type="image" src="/Compta/style/icons/duplicate.png" style="border: 0;" height="14" width="14" alt="dupliquer" formaction="' . $dupliquer_href . '" onclick="submit()" title="Dupliquer"></span></form>
			<form method="post"><span class=displayspan style="width: 2%;"><input type="image" src="/Compta/style/icons/delete.png" style="border: 0;" height="14" width="14" alt="supprimer" formaction="' . $supprimer_href . '" onclick="submit()" title="Supprimer"></span></form>
			<div class=spacer></div></div></li>' ;
		}
		$content .= '</ul>';
	}   else {
		$content .= '<div class="warnlite">*** Aucun locataire ou garant trouvé ***</div>';
	}
	
	if (defined $args->{modifierloc} && defined $args->{id_loc} && $args->{id_loc} ne '') {
		$content .= form_nouveau_loc( $r, $args) ; 
	} elsif (defined $args->{ajout}) {
		$content .= '<fieldset  class="centrer Titre09 pretty-box"> '.form_nouveau_loc( $r, $args).'</fieldset><br>' ; 
	}
	
	return $content;
}

#/*—————————————— Page Affichage Liste des documents BAUX=3 ——————————————*/
sub Affichage_list_documents {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($content, $sql) = ('', '');
    my $reqid = Base::Site::util::generate_reqline();
    my $line = "1"; 
    
    if (defined $args->{logements}) {
		$args->{restart} = 'gestionimmobiliere?logements='.($args->{logements} || '').'&code='.$args->{code}.'&modifier=1';
	} elsif (defined $args->{baux}) {
		$args->{restart} = 'gestionimmobiliere?baux=3&code='.$args->{code}.'&archive=' . $args->{archive}.'';
	}
	
	$content .= '<div class="Titre10"><div class="centrer"> Liste des documents avec le Tag <a class="nav2" href="docs?tags='.($args->{code} || '').'">#'.($args->{code} || '').'</a></div></div>' ;
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter tag' 				  #
	#######################################################################
    if ( defined $args->{add_tag} && $args->{add_tag} eq '1' ) {
		
		my $lib = $args->{tags_nom} || undef ;
		Base::Site::util::formatter_libelle(\$lib);

		if (defined $args->{tags_nom} && $lib eq '') {
			$content .= Base::Site::util::generate_error_message('Impossible le nom du tag est vide !');
			$args->{ajouter_tag} = '';
		} elsif ((defined $args->{tags_doc} && $args->{tags_doc} eq '') || !defined $args->{tags_doc}) {
			$content .= Base::Site::util::generate_error_message('Impossible aucun document n\'a été sélectionné !');
			$args->{ajouter_tag} = '';
		} else {
	
	    #ajouter une catégorie
	    $sql = 'INSERT INTO tbldocuments_tags (tags_nom, tags_doc, id_client) values (?, ?, ?)' ;
	    my @bind_array = ( $args->{tags_nom}, $args->{tags_doc}, $r->pnotes('session')->{id_client} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut renseigner le nom du nouveau tag de document') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Le tag "'.$args->{tags_nom}.'" existe déjà pour ce document') ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Ajout du tag "'.$args->{tags_nom}.'" pour le document '.$args->{tags_doc}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
		}
    }
    	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'supprimer tag' 				  #
	#######################################################################
    if ( defined $args->{supprimer_tag} && $args->{supprimer_tag} eq '1' ) {
		my @delete_tags = defined $args->{del_tags} ? split /,/, $args->{del_tags} : ();
		
		if (defined $delete_tags[0] && $delete_tags[0] eq '' || !defined $delete_tags[0]) {
			$content .= Base::Site::util::generate_error_message('Impossible le nom du tag est vide !');
		} elsif ((defined $delete_tags[1] && $delete_tags[1] eq '') || !defined $delete_tags[1]) {
			$content .= Base::Site::util::generate_error_message('Impossible il faut sélectionner un document !');
		} else {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tbldocuments_tags WHERE tags_nom = ? AND id_client = ? AND tags_doc = ?' ;
			my @bind_array = ( $delete_tags[0], $r->pnotes('session')->{id_client}, $delete_tags[1] ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
				} elsif ( $@ =~ /toujours|referenced/ ) {
				$content .= '<h3 class=warning>Suppression impossible : le tag '.$delete_tags[0].' est encore utilisé dans un document </h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'gestionimmobiliere.pm => Suppression du tag "'.($delete_tags[0] || '').'" du document '.($delete_tags[1] || '').'');
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé	
			}
		}
    }
	
	$sql = '
	SELECT DISTINCT tags_nom
	FROM tbldocuments_tags
	WHERE tags_doc IN (
		SELECT tags_doc
		FROM tbldocuments_tags
		WHERE id_client = ? AND tags_nom = ? ) AND id_client = ? AND tags_nom != ?';
	my @bind_array_2 = ( $r->pnotes('session')->{id_client}, $args->{code}, $r->pnotes('session')->{id_client}, $args->{code}) ;	
	my $tag_documents = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_2 )} ;
	
	
	my @current_tags = defined $args->{tags} ? split /,/, $args->{tags} : ();
	# Vérifier si l'élément $args->{code} est présent dans @current_tags
    unless (grep { $_ eq $args->{code} } @current_tags) {
        push @current_tags, $args->{code};
    }
	
	my $new_tag_class = ( defined $args->{ajouter_tag} ) ? 'men1select' : '' ;
	my $new_tag_href = ( defined $args->{ajouter_tag} ) ? ''.$args->{restart}.'' : ''.$args->{restart}.'&ajouter_tag' ;
	my $new_tag_link = '<li><a class="men men1 '.$new_tag_class.'" href="'.$new_tag_href.'" title="Ajouter un tag à un document" >Ajouter #Tag</a></li>' ;
	
	my $del_tag_class = ( defined $args->{supprimer_tag} ) ? 'men1select' : '' ;
	my $del_tag_href = ( defined $args->{supprimer_tag} ) ? ''.$args->{restart}.'' : ''.$args->{restart}.'&supprimer_tag' ;
	my $del_tag_link = '<li><a class="men men1 '.$del_tag_class.'" href="'.$del_tag_href.'" title="Supprimer le tag d\'un document" >Supprimer #Tag</a></li>' ;

	$content .= '<ul class="main-nav2"> '.$new_tag_link . $del_tag_link .'<li><span class="separator"> | </span></li>' ;
	
	if ($tag_documents) {

		my $tags_param = $args->{tags};
		# Utilisation d'un ensemble pour stocker les tags uniques
		my %unique_tags;

		# Récupération des résultats et stockage des tags uniques
		foreach my $row (@$tag_documents) {
			my $tag_nom = $row->{tags_nom};
			$unique_tags{$tag_nom} = 1; # Stockage dans l'ensemble
		}
		my @sorted_tags = sort keys %unique_tags;
		# Traitement des tags triés
		foreach my $tags_nom (@sorted_tags) {
				
			my @updated_tags = @current_tags;
			my $categorie_href='';
			my $categorie_class='';
				
			# Vérifier si le tag est déjà dans la liste des tags
			my $tag_in_list = 0;
			for my $tag (@current_tags) {
				if ($tag eq URI::Escape::uri_escape_utf8($tags_nom) || $tag eq $tags_nom) {
					$tag_in_list = 1;
					last;
				}
			}

			# Si le tag est déjà dans la liste des tags, le retirer
			if ($tag_in_list) {
				@updated_tags = grep { $_ ne URI::Escape::uri_escape_utf8($tags_nom) && $_ ne $tags_nom } @current_tags;
			} else {
				push @updated_tags, URI::Escape::uri_escape_utf8($tags_nom);
			}

			my $tags_param = join ',', @updated_tags;
			my $tags_href = '/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=3&code='.($args->{code} || '').'&tags=' . URI::Escape::uri_escape_utf8($tags_param);

			my $tags_class = '';
			if ($tag_in_list) {
				$tags_class = "men2select";
			}
				
			$content .= '<li><a class="men men2 '.$tags_class.'" href="' . $tags_href . '" >#' . $tags_nom . '</a></li>';
		}
	}
	$content .= '</ul>';
	
	#Afficher le formulaire ajouter tag
	if (defined $args->{ajouter_tag}) {$content .= forms_ajouter_tag( $r, $args, $new_tag_href ).'<br>';}
	if (defined $args->{supprimer_tag}) {$content .= forms_supprime_tag( $r, $args, $del_tag_href ).'<br>';}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' le document		  #
	#######################################################################
    if ( defined $args->{supprimer_doc} && $args->{supprimer_doc} eq '0' ) {
		my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.'&id_name=' . ( URI::Escape::uri_escape_utf8( $args->{id_name} ) || '' ) . '&supprimer_doc=1' ;
		my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.'&id_name=' . ( URI::Escape::uri_escape_utf8( $args->{id_name} ) || '' ) . '' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous  supprimer le document ' . $args->{id_name} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
    } elsif ( defined $args->{supprimer_doc} && $args->{supprimer_doc} eq '1' ) {
		$content .= Base::Site::util::verify_and_delete_document($dbh, $r, $args, 0, $args->{restart});
	} 
	
	# Construisez la clause WHERE pour la requête PostgreSQL
	my $search_tags = '';
	my $count_tags = 0;
	my $having_tags = '';
	my $string_tags = '';
	my @placeholders;
		
	if (@current_tags && @current_tags ne '') {
		$search_tags = ' AND (';
		for my $tag (@current_tags) {
			$search_tags .= 't2.tags_nom ILIKE ? OR ';
			push @placeholders, '%' . $tag . '%';
			$count_tags++;
		}
		$search_tags =~ s/ OR $/)/; # Supprimez le dernier 'OR' et fermez la parenthèse
		$having_tags = 'HAVING COUNT(DISTINCT t2.tags_nom) ='.$count_tags.'';
		$string_tags = ', (SELECT STRING_AGG(tags_nom, \', \') FROM tbldocuments_tags WHERE tags_doc = t1.id_name) AS tags';
	}
			
	#Requête tbldocuments => Recherche de la liste des documents enregistrés
	$sql = '
	SELECT t1.id_name, t1.date_reception, t1.multi, t1.check_banque, to_char(t1.montant/100::numeric, \'999G999G999G990D00\') as montant, t1.libelle_cat_doc, t1.fiscal_year, to_char((sum(t1.montant/100) over())::numeric, \'999G999G999G990D00\') as total_montant 
	FROM tbldocuments t1
	INNER JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client and t1.id_name = t2.tags_doc
	WHERE t1.id_client = ? AND (t1.fiscal_year = ? OR (t1.multi = \'t\' AND (t1.last_fiscal_year IS NULL OR t1.last_fiscal_year >= ?))) '.$search_tags.'
	GROUP BY t1.id_name, 
		t1.date_reception, 
		t1.multi, 
		t1.check_banque, 
		t1.montant, 
		t1.libelle_cat_doc, 
		t1.fiscal_year
	'. $having_tags .'
	ORDER BY t1.date_reception, t1.id_name' ;
	my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
	if (@current_tags){push @bind_array_1, @placeholders ;} 
	my $result_documents = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 )} ;
		
	#ligne des en-têtes Frais en cours
		$content .= '
		<ul class="wrapper100">  
		<li class="style1">
		<div class="spacer"></div>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<span class=headerspan style="width: 15%; text-align: left;">Date</span>
		<span class=headerspan style="width: 55.4%; text-align: left;">Nom</span>
		<span class=headerspan style="width: 15%; text-align: left;">Catégorie</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2.5%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<div class="spacer"></div>
		</li>' ;	
		
	if (@$result_documents) {

		
		for ( @{ $result_documents } ) {
			my $reqline = ($line ++);	
			
			my $get_last_email_event_date = Base::Site::bdd::get_last_email_event_date($dbh, $r, $_->{id_name});
			my $statut = '<span class=displayspan style="width: 2.5%; text-align: center;"><img id="email_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Envoyer le document par mail" src="/Compta/style/icons/encours.png" alt="email"></span>';

			if ($get_last_email_event_date){
				my $event_description = $get_last_email_event_date->{event_description};
				my $event_date = $get_last_email_event_date->{event_date};
				$statut = '<span class="displayspan" style="width: 2.5%; text-align: center;"><img id="email_'.$reqline.'" title="'.$event_description.' le '.$event_date.'" src="/Compta/style/icons/valider.png" height="16" width="16" alt="statut"></span>';
			}
				
			my $http_link_banque_valide = '<img class="redimmage nav" title="Validée le '. (defined $_->{date_validation}).'" style="border: 0;" src="/Compta/style/icons/cadena.png" alt="valide">' ;
			my $check_value = ( $_->{check_banque} eq 'f' ) ? '<span class="displayspan" style="width: 2%; text-align: center;"><img class="line_icon_hidden" id="statut_'.$reqline.'" title="Check complet" src="/Compta/style/icons/icone-valider.png" height="16" width="16" alt="check_value"></span>' : '<span class="displayspan" style="width: 2%; text-align: center;"><img id="statut_'.$reqline.'" title="Check complet" src="/Compta/style/icons/icone-valider.png" height="16" width="16" alt="check_value"></span>' ;
			my $check_multi = ( $_->{multi} eq 'f' ) ? '<span class="displayspan" style="width: 2%; text-align: center;"><img id="multi_'.$reqline.'" class="line_icon_hidden" title="documents multi-exercice" src="/Compta/style/icons/multi.png" height="16" width="16" alt="check_multi"></span>' : '<span class="displayspan" style="width: 2%; text-align: center;"><img id="multi_'.$reqline.'" title="documents multi-exercice" src="/Compta/style/icons/multi.png" height="16" width="16" alt="check_multi"></span>' ;
			
			my $check_send_href = $args->{restart}.'&id_name=' . ( URI::Escape::uri_escape_utf8( $_->{id_name} ) || '' ) . '&email' ;
			my $check_send = '<a class=nav href="' . $check_send_href . '">'.$statut.'</a>';
			
			#lien de modification de l'entrée
			my $id_name_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $_->{id_name} ;
			my $disp_doc_href = $args->{restart}.'&id_name=' . ( URI::Escape::uri_escape_utf8( $_->{id_name} ) || '' ) . '' ;
			my $suppress_href = '';
			my $suppress_link = '<span class=blockspan style="width: 2%; text-align: center;"><img id="supprimer_'.$reqline.'" class="line_icon_hidden" height="16" width="16" title="Supprimer" src="/Compta/style/icons/delete.png" alt="supprimer"></span>';
			my $download_href = '/Compta/base/documents/' . $r->pnotes('session')->{id_client} . '/'.$_->{fiscal_year}.'/'. $_->{id_name}  ;
			my $img_link = '<a class=nav href="' . $id_name_href . '"><span class=blockspan style="width: 2%; text-align: center;"><img id="visualiser_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Modifier le document" src="/Compta/style/icons/documents.png" alt="visualiser"></span></a>';
					
			if ($r->pnotes('session')->{Exercice_Cloture} ne 1 && $_->{multi} eq 'f') {
				$suppress_href = $args->{restart}.'&id_name=' . ( URI::Escape::uri_escape_utf8( $_->{id_name} ) || '' ) . '&supprimer_doc=0' ;
				$suppress_link = '<a class=nav href="' . $suppress_href . '"><span class=blockspan style="width: 2%; text-align: center;"><img id="supprimer_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Supprimer" src="/Compta/style/icons/delete.png" alt="supprimer"></span></a>';
			}
			
			#ligne d'en-têtes
			$content .= '
			<li id="line_'.$_->{id_name}.'" class=listitem3><a href="' . $disp_doc_href . '">
			<div class=spacer></div>
			<span class=blockspan style="width: 1%;">&nbsp;</span>
			<span class=blockspan style="width: 15%; text-align: left;">' . ( $_->{date_reception} || '&nbsp;' ). '</span>
			<span class=blockspan style="width: 55.4%; text-align: left;">' . ( $_->{id_name} || '&nbsp;' ) . '</span>
			<span class=blockspan style="width: 15%; text-align: left;">' . ( $_->{libelle_cat_doc} || '&nbsp;') . '</span>
			<span class=blockspan style="width: 2%;">&nbsp;</span>
			' .$check_send . '
			' . $img_link . '
			' . $suppress_link . '
			' . $check_value . '
			' . $check_multi . '
			<span class=blockspan style="width: 1%;">&nbsp;</span>
			<div class=spacer></div>
			</a></li>' ;
		}
		$content .= '</ul>';
		
		if (defined $args->{email} ){
			$content .= ''.form_email( $r, $args ).'';
		}
				
		if (defined $args->{code} && defined $args->{id_name} && $args->{id_name} ne ''){
			my $sql = 'SELECT fiscal_year FROM tbldocuments WHERE id_client = ? AND id_name = ?';
			my @bind_array = ($r->pnotes('session')->{id_client}, $args->{id_name});
			my $result_fiscal = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
			if ($result_fiscal) {
				#Affichage du document
				$content .= '<div class="centrer"><div class="Titre10">Affichage du document</div>
				<br><iframe src="/Compta/base/documents/'. $r->pnotes('session')->{id_client}.'/'.$result_fiscal.'/'.$args->{id_name}.'" width="1280" height="1280" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%; " allowfullscreen> </iframe></div>' ; 
				$content .= '<script>
				focusAndChangeColor2("'.$args->{id_name}.'");
				</script>';
			}
		}

	}  else {
		#aucun locataire ou garant n'existent
		#$content .= Base::Site::util::generate_error_message('*** Aucun document lié à ce tag ***') ;
		$content .= '<div class="warnlite">*** Aucun document trouvé ***</div>';
	}

	return $content;
}

#/*—————————————— Page Affichage Formulaire quittance BAUX=4 ——————————————*/
sub Affichage_quittance {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($content, $item_num, $numero_piece, $sql, @bind_array, $month, $year) = ('','1', '', '', '', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    my @var_N = ('') x 30; #$var_N[1]
    my ($result_credit, $result_debit, $count_credit, $count_debit) = (undef, undef, 0, 0);
    
    	#/************ ACTION DEBUT *************/

	####################################################################### 
	#Quittance => l'utilisateur a cliqué sur le bouton 'Imprimer'	 	 #
	#######################################################################
	if ( defined $args->{baux} && $args->{baux} eq 4 && defined $args->{imprimer} ) {
		
		my $location = export_pdf( $r, $args ); ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		$content .= '
		<script type="text/javascript">
		 function Open(){window.open("'.$location.'", "blank");}
		Open();
		</script>';
		}
	}
	
	####################################################################### 
	#Quittance => l'utilisateur a cliqué sur générer la quittance 		  #
	#######################################################################
	if ( defined $args->{baux} && $args->{baux} eq 4 && defined $args->{generer} && $args->{generer} eq 'Oui') {
		
		my $location = export_pdf( $r, $args );
			
		#si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
			
			my $name_file= '';
			my $reference = $args->{code} || '';
			my $idfacture = $args->{idfacture} || '';
			
			if (defined $args->{type_quittance} && $args->{type_quittance} eq 'mensuel' && defined $args->{idfacture} && $args->{idfacture} ne ''){
				$name_file = ''.$args->{idfacture}.'_Quittance_'.$args->{biens_nom}.'_Loyer_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'charge' && defined $args->{idfacture} && $args->{idfacture} ne ''){
				$name_file = ''.$args->{idfacture}.'_Quittance_'.$args->{biens_nom}.'_Charge_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'caution' && defined $args->{idfacture} && $args->{idfacture} ne ''){
				$name_file = ''.$args->{idfacture}.'_RECU_'.$args->{biens_nom}.'_DEPOT_GARANTIE_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'mensuel'){
				$name_file = 'Quittance_'.$args->{biens_nom}.'_Loyer_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'charge'){
				$name_file = 'Quittance_'.$args->{biens_nom}.'_Charge_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'caution'){
				$name_file = '_RECU_'.$args->{biens_nom}.'_DEPOT_GARANTIE_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			} else {
				$name_file = '_RECU_'.$args->{biens_nom}.'_Divers_'.$args->{select_month}.'_'.$args->{select_year}.'_'.$args->{varloc}.'.pdf';
			}
			
			#Génération nom de fichier BQ2022-01_01_Quittance_VILLA_2_Loyer_01_2022_MARTINEZ_FLAIS.pdf
			# Remplacer modifier espace et _
			$name_file =~ s/\s+/_/g;
			Base::Site::util::formatter_montant_et_libelle(undef, \$name_file);
			
			my $sql = 'SELECT id_name FROM tbldocuments WHERE id_client = ? AND id_name = ?';
			my @bind_array = ($r->pnotes('session')->{id_client}, $name_file);
			my $result_name = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

			if (!$result_name && $name_file ne '' || defined $args->{ecraser} && $args->{ecraser} eq 1) {
				
				my $doc_categorie = 'Temp';
				if (defined $args->{libelle_cat_doc} && $args->{libelle_cat_doc} ne ''){
					$doc_categorie = $args->{libelle_cat_doc} ;
				}
				#Insertion du nom du document dans la table tbldocuments
				$sql = 'INSERT INTO tbldocuments ( id_client, id_name, fiscal_year, libelle_cat_doc, date_reception, date_upload )
				VALUES ( ? , ? , ? , ?, ?, CURRENT_DATE)
				ON CONFLICT (id_client, id_name ) DO NOTHING
				RETURNING id_name' ;
				my $sth = $dbh->prepare($sql) ;
				eval { $sth->execute( $r->pnotes('session')->{id_client}, $name_file, $r->pnotes('session')->{fiscal_year}, $doc_categorie, $args->{AR} )} ;
				if ( $@ ) {
					$content .= Base::Site::util::generate_error_message($@);
				}
				
				#Insert le tag "Quittance"
				my $tag2 = 'Quittance';
				$sql = 'INSERT INTO tbldocuments_tags (tags_nom, tags_doc, id_client) values (?, ?, ?)' ;
				@bind_array = ( $tag2, $name_file, $r->pnotes('session')->{id_client} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					$content .= Base::Site::util::generate_error_message($@);		    
				}
				
				#Insert le tag "référence du bail"
				$sql = 'INSERT INTO tbldocuments_tags (tags_nom, tags_doc, id_client) values (?, ?, ?)' ;
				@bind_array = ( $reference, $name_file, $r->pnotes('session')->{id_client} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					$content .= Base::Site::util::generate_error_message($@);		    
				}
				
				if (defined $args->{lettrage} && $args->{lettrage} ne ''){
					$sql = 'UPDATE tbljournal set documents1 = ? WHERE id_client = ? AND fiscal_year = ? AND documents1 is null AND id_entry = (select id_entry from tbljournal WHERE id_client = ? AND id_line = ?)';
					@bind_array = ( $name_file, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $args->{lettrage} ) ;
					$dbh->do( $sql, undef, @bind_array ) ;
				}

				#Récupérer le pdf généré
				my $pdf_file = $r->document_root() . $location;
				my $pdf = PDF::API2->open($pdf_file);
				
				#définition répertoire
				my $base_dir = $r->document_root() . '/Compta/base/documents/' ;
				my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$r->pnotes('session')->{fiscal_year}. '/' ;

				#Enregistrer le pdf
				my $export_pdf_file = $archive_dir . $name_file;
				$pdf->saveas($export_pdf_file);
				
				my $event_type = 'Création';
				my $event_description = 'Le document a été créé par '.$r->pnotes('session')->{username}.'';
				my $save_document_history = Base::Site::bdd::save_document_history($dbh, $r->pnotes('session')->{id_client}, $name_file, $event_type, $event_description, $r->pnotes('session')->{username});
          
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm =>	Génération du document ' .($name_file || '') . ' dans la catégorie '.($args->{libelle_cat_doc} || '').'');
				
				#Redirection
				$args->{restart} = 'gestionimmobiliere?baux=3&code='.$reference.'&archive=' . $args->{archive}.'&id_name='.$name_file.'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			
			} elsif ($result_name) {
				$content .= Base::Site::util::generate_error_message('Impossible le document '.$result_name.' existe déjà !') ;
			} 
		}
	}		
	
	#/************ ACTION FIN *************/
    
    $args->{select_year} //= $r->pnotes('session')->{fiscal_year};
    $args->{select_month} //= sprintf("%02d", localtime->mon);
    $args->{type_quittance} //= 'mensuel';
    $args->{immo_contrat} = $args->{code} || undef;
    
    my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);
	
	my $info_tblimmobilier = '';
    if (defined $args->{archive} && $args->{archive} eq 1 ) {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 1, $args);
	} else {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 2, $args);
	}
	
	if (defined $args->{lettrage} && $args->{lettrage} ne '') {
	
		$sql = 'SELECT * FROM tbljournal WHERE id_client = ? and fiscal_year = ? AND credit = 0
		AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND id_line = ?)
		ORDER BY date_ecriture;';
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $args->{lettrage}) ;
		$result_credit = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array) };
			
		$sql = 'SELECT * FROM tbljournal WHERE id_client = ? and fiscal_year = ? AND debit = 0
		AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND id_line = ? )
		ORDER BY date_ecriture;';
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $args->{lettrage}) ;
		$result_debit = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array) };
			
		$count_credit = scalar @$result_credit;
		$count_debit = scalar @$result_debit;
	}
	
	my $current_date = localtime;
	my $result_date = Base::Site::util::transformation_mois($args->{select_year}, $args->{select_month});
	my $periode = $args->{AY} || (''.($result_date->{nom_mois} //'').' '.($args->{select_year} // '').'');
	my $date_debut = $args->{AZ} || $result_date->{date_debut} ;
	my $date_fin = $args->{BA} || $result_date->{date_fin};
	my $ref_contrat = $args->{code} // '';
	my $date_emission = $args->{AR} || $current_date->strftime("%d/%m/%Y");

	my $select_month = '<select style="width: 15%;" class="forms2_input" name="select_month" id="select_month_'.$reqid.'">
	' .	join('', map { "<option value='" . sprintf("%02d", $_) . "'" . ((defined $month && $month eq sprintf("%02d", $_)) || (defined($args->{select_month}) && $args->{select_month} eq sprintf("%02d", $_)) ? ' selected' : '') . '>' . (split(';', 'Janvier;Février;Mars;Avril;Mai;Juin;Juillet;Août;Septembre;Octobre;Novembre;Décembre;Annuelle'))[$_-1] . '</option>' } 1..13) .
	'</select>';
		
	my $type_quittance = Base::Site::util::generate_simple_select('type_quittance', 'type_quittance', 'forms2_input', [['mensuel', 'Quittance mensuelle'], ['charge', 'Quittance charge'], ['caution', 'Reçu caution'], ['appelcharge', 'Appel de charge'],], $args->{type_quittance}, '', 'style="width: 22%;"');
	
	my $categorie_document = Base::Site::bdd::get_categorie_document($dbh, $r);
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'};\"";
	my $selected1 = (defined($args->{libelle_cat_doc}) && $args->{libelle_cat_doc} ne '') ? ($args->{libelle_cat_doc} ) : 'Temp';
	my ($form_name1, $form_id1) = ('libelle_cat_doc', 'libelle_cat_doc_'.$reqid.'');
	my $document_cat_select = Base::Site::util::generate_doc_cat_selector($categorie_document, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style ="width : 17%;"');

	my $parametres_fiscal_year = Base::Site::bdd::get_parametres_fiscal_year($dbh, $r->pnotes('session')->{id_client});
	my $selected_fiscal_year = ((defined $year && $year ne '') || (defined($args->{select_year}) && $args->{select_year} ne '')) ? ($year || $args->{select_year} ) : undef;
	my ($onchange_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year) = ('', 'select_year', 'select_year_'.$reqid.'');
	my $search_fiscal_year = Base::Site::util::generate_fiscal_year($parametres_fiscal_year, $reqid, $selected_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year, $onchange_fiscal_year, 'class="forms2_input"', 'style="width: 15%;"', 0); 
		
	$sql = 'SELECT * FROM tblimmobilier_locataire t1
	LEFT JOIN tblimmobilier t2 ON t1.id_client = t2.id_client AND t1.locataires_contrat = t2.immo_contrat
	LEFT JOIN tblimmobilier_logement t3 ON t1.id_client = t3.id_client AND t2.immo_logement = t3.biens_ref
	WHERE t1.id_client = ? AND t1.locataires_contrat = ? AND t1.locataires_type = ? ORDER BY id_loc';
	my $result_locataire = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}, 'Locataire') };
	
	my $loc_1 = defined $result_locataire->[0]->{locataires_nom} ? ''.$result_locataire->[0]->{locataires_civilite} .' '.	$result_locataire->[0]->{locataires_nom} .' '.$result_locataire->[0]->{locataires_prenom} : '';
	my $loc_2 = defined $result_locataire->[1]->{locataires_nom} ? 'et '.$result_locataire->[1]->{locataires_civilite} .' '.	$result_locataire->[1]->{locataires_nom} .' '.$result_locataire->[1]->{locataires_prenom} : '';
	my $email = defined $info_societe->[0]->{courriel} ? "Email: " . ($info_societe->[0]->{courriel} // '') . "" : "";
	my $addresseloc = ($info_tblimmobilier->[0]->{biens_adresse}||'') .' - '.	($info_tblimmobilier->[0]->{biens_nom}||'');
	my $cpville = ($info_tblimmobilier->[0]->{biens_cp}||'') .' '. ($info_tblimmobilier->[0]->{biens_ville}||''); 
	my $lot = 'Lot (Réf. '.($info_tblimmobilier->[0]->{immo_logement}||'').')';
	my $lotdesc = ($info_tblimmobilier->[0]->{biens_ville}||'')  .' - '. ($info_tblimmobilier->[0]->{biens_nom}||'');
	my $codeloc = ($result_locataire->[0]->{locataires_ref} ||'');
	my $nomloc = ($result_locataire->[0]->{locataires_civilite}||'') .' '. ($result_locataire->[0]->{locataires_nom}||'').' '. (defined $result_locataire->[1]->{locataires_nom} ? "et ".$result_locataire->[1]->{locataires_civilite} ." ".	$result_locataire->[1]->{locataires_nom}." ": "");
	my $varloc = ($result_locataire->[0]->{locataires_nom}||'').''.(defined $result_locataire->[1]->{locataires_nom} ? "_".$result_locataire->[1]->{locataires_nom}."": "");
	my $date_echeance = $args->{AS} || (''.sprintf("%02d", ($info_tblimmobilier->[0]->{immo_entry} || 5)).'/'.($result_date->{mois_for} ||'').'/'.($args->{select_year} ||'').'');
	my $fin = $args->{textareafin} || 'La présente quittance ne libère l\'occupant que pour la période indiquée et annule tout reçu à valoir. Elle n\'est pas libératoire des loyers antérieurs impayés et est délivrée sous réserve de toutes instances judiciaires en cours.';
	
	my ($appel_loyer, $title, $desc, $def_periode ) = ('', '', '', '');
	# Initialiser les variables pour les dates, libellés et montants
	my ($var_facture_date_1, $var_facture_date_2, $var_facture_date_3, $var_facture_date_4) = (($args->{facture_date_1} || $date_echeance || $current_date->strftime("%d/%m/%Y")), $args->{facture_date_2}, $args->{facture_date_3}, $args->{facture_date_4} );
	my ($var_facture_libelle_1, $var_facture_libelle_2, $var_facture_libelle_3, $var_facture_libelle_4) = ('', $args->{facture_libelle_2}, $args->{facture_libelle_3}, $args->{facture_libelle_4} );
	my ($var_facture_montant_1, $var_facture_montant_2, $var_facture_montant_3, $var_facture_montant_4) = ('', $args->{facture_montant_2}, $args->{facture_montant_3}, $args->{facture_montant_4} );
	my ($var_paiement_date_1, $var_paiement_date_2, $var_paiement_date_3, $var_paiement_date_4, $var_paiement_date_5, $var_paiement_date_6) = ($args->{paiement_date_1}, $args->{paiement_date_2}, $args->{paiement_date_3}, $args->{paiement_date_4}, $args->{paiement_date_5}, $args->{paiement_date_6} );
	my ($var_paiement_libelle_1, $var_paiement_libelle_2, $var_paiement_libelle_3, $var_paiement_libelle_4, $var_paiement_libelle_5, $var_paiement_libelle_6) = ($args->{paiement_libelle_1}, $args->{paiement_libelle_2}, $args->{paiement_libelle_3}, $args->{paiement_libelle_4}, $args->{paiement_libelle_5}, $args->{paiement_libelle_6} );
	my ($var_paiement_debit_1, $var_paiement_debit_2, $var_paiement_debit_3, $var_paiement_debit_4, $var_paiement_debit_5, $var_paiement_debit_6) = ($args->{paiement_debit_1}, $args->{paiement_debit_2}, $args->{paiement_debit_3}, $args->{paiement_debit_4}, $args->{paiement_debit_5}, $args->{paiement_debit_6} );
	my ($var_paiement_credit_1, $var_paiement_credit_2, $var_paiement_credit_3, $var_paiement_credit_4, $var_paiement_credit_5, $var_paiement_credit_6) = ($args->{paiement_credit_1}, $args->{paiement_credit_2}, $args->{paiement_credit_3}, $args->{paiement_credit_4}, $args->{paiement_credit_5}, $args->{paiement_credit_6} );
	
	if (defined($args->{select_month}) && $args->{select_month} eq 13) {
		$periode = $args->{AY} || ('Année '.($args->{select_year} // '').'');
		$date_debut = $args->{AZ} || ('01/01/'.($args->{select_year}//'').'') ;
		$date_fin = $args->{BA} || ('31/12/'.($args->{select_year}//'').'') ;
	}
	
	if (defined $args->{type_quittance} && $args->{type_quittance} eq 'mensuel'){
		$appel_loyer = 'APPEL DE LOYER '.(uc($result_date->{nom_mois}) //'').' '.($args->{select_year} // '').'';
		$title = 'QUITTANCE DE LOYER';
		$desc = 'du loyer';
		$var_facture_libelle_1 = $args->{facture_libelle_1} || 'Loyer '.(($result_date->{nom_mois}) //'').' '.($args->{select_year} // '').'';
		$var_facture_montant_1 = ($args->{facture_montant_1}) || (Base::Site::util::affichage_montant(($info_tblimmobilier->[0]->{immo_loyer} || 0)/100)) || ('0.00');
		$def_periode = 'pour la période du '.$date_debut.' au '.$date_fin.' ';
	} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'charge'){
		$appel_loyer = 'APPEL DE CHARGE '.($result_date->{nom_mois} //'').' '.($args->{select_year} // '').'';
		$title = 'REÇU DE PAIEMENT';
		$var_facture_libelle_1 = $args->{facture_libelle_1} || 'Charge '.(($result_date->{nom_mois}) //'').' '.($args->{select_year} // '').'';
		$var_facture_montant_1 = $args->{facture_montant_1} || '0.00';
		$desc = 'des charges';
		$def_periode = 'pour la période du '.$date_debut.' au '.$date_fin.' ';
	} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'caution'){
		$appel_loyer = 'APPEL DU DÉPÔT DE GARANTIE';
		$title = 'REÇU DE PAIEMENT';
		$var_facture_libelle_1 = $args->{facture_libelle_1} || 'Dépôt de garantie';
		$desc = 'du dépôt de garantie';
		$var_facture_montant_1 = $args->{facture_montant_1} || Base::Site::util::affichage_montant($info_tblimmobilier->[0]->{immo_depot}/100) || '0.00';
		$fin = 'Le dépôt de garantie sera restitué à la fin du bail, dans les conditions et les délais définis à l\'article 22 de la loi du 6 juillet 1989.';
		$periode = '';
		$date_debut = '';
		$date_fin = '';
	} elsif (defined $args->{type_quittance} && $args->{type_quittance} eq 'appelcharge'){
		$appel_loyer = 'APPEL DE CHARGE '.($result_date->{nom_mois} //'').' '.($args->{select_year} // '').'';
		$title = 'APPEL DE CHARGE';
		$var_facture_libelle_1 = $args->{facture_libelle_1} || 'Taxe d\'enlèvement des ordures ménagères '.($args->{select_year} // '').'';
		$desc = '';
		$var_facture_montant_1 = $args->{facture_montant_1} || '0.00';
		$fin = '';
		$periode = 'annuelle';
		$date_debut = '01/01/'.($args->{select_year}//'').'';
		$date_fin = '31/12/'.($args->{select_year}//'').'';
	} 

	#Si lettrage est renseigné
	if (defined $result_credit && @$result_credit) {
		# Initialiser les totaux de débit et crédit
		my $total_debit = 0;
		my $total_credit = 0;

		# Parcourir les résultats de la requête
		my $count = 1;
		foreach my $row (@$result_credit) {
			$total_debit += $row->{debit};
			$total_credit += $row->{credit};

			# Utiliser des structures conditionnelles pour assigner les valeurs en fonction de $count
			if ($count == 1) {
				$var_facture_date_1 = $args->{facture_date_1} || $row->{date_ecriture};
				$var_facture_libelle_1 = $args->{facture_libelle_1} || $row->{libelle};
				$var_facture_montant_1 = $args->{facture_montant_1} || Base::Site::util::affichage_montant($row->{debit}/100);
			} elsif ($count == 2) {
				$var_facture_date_2 = $args->{facture_date_2} || $row->{date_ecriture};
				$var_facture_libelle_2 = $args->{facture_libelle_2} || $row->{libelle};
				$var_facture_montant_2 = $args->{facture_montant_2} || Base::Site::util::affichage_montant($row->{debit}/100);
			} elsif ($count == 3) {
				$var_facture_date_3 = $args->{facture_date_3} || $row->{date_ecriture};
				$var_facture_libelle_3 = $args->{facture_libelle_3} || $row->{libelle};
				$var_facture_montant_3 = $args->{facture_montant_3} || Base::Site::util::affichage_montant($row->{debit}/100);
			} elsif ($count == 4) {
				$var_facture_date_4 = $args->{facture_date_4} || $row->{date_ecriture};
				$var_facture_libelle_4 = $args->{facture_libelle_4} || $row->{libelle};
				$var_facture_montant_4 = $args->{facture_montant_4} || Base::Site::util::affichage_montant($row->{debit}/100);
			}

			$count++;
		}
	}
	
	#Si lettrage est renseigné
	if (defined $result_debit && @$result_debit) {
		# Parcourir les résultats de la requête
		my $count = 1;
		foreach my $row (@$result_debit) {

			# Utiliser des structures conditionnelles pour assigner les valeurs en fonction de $count
			if ($count == 1) {
				$var_paiement_date_1 = $args->{paiement_date_1} || $row->{date_ecriture};
				$var_paiement_libelle_1 = $args->{paiement_libelle_1} || $row->{libelle};
				$var_paiement_credit_1 = $args->{paiement_credit_1} || Base::Site::util::affichage_montant($row->{credit}/100);
			} elsif ($count == 2) {
				$var_paiement_date_2 = $args->{paiement_date_2} || $row->{date_ecriture};
				$var_paiement_libelle_2 = $args->{paiement_libelle_2} || $row->{libelle};
				$var_paiement_credit_2 = $args->{paiement_credit_2} || Base::Site::util::affichage_montant($row->{credit}/100);
			} elsif ($count == 3) {
				$var_paiement_date_3 = $args->{paiement_date_3} || $row->{date_ecriture};
				$var_paiement_libelle_3 = $args->{paiement_libelle_3} || $row->{libelle};
				$var_paiement_credit_3 = $args->{paiement_credit_3} || Base::Site::util::affichage_montant($row->{credit}/100);
			} elsif ($count == 4) {
				$var_paiement_date_4 = $args->{paiement_date_4} || $row->{date_ecriture};
				$var_paiement_libelle_4 = $args->{paiement_libelle_4} || $row->{libelle};
				$var_paiement_credit_4 = $args->{paiement_credit_4} || Base::Site::util::affichage_montant($row->{credit}/100);
			}

			$count++;
		}
	}
	
	if (defined $args->{type_quittance} && $args->{type_quittance} eq 'caution'){
		$date_echeance = $var_facture_date_1;
	} 
	
	my $lib = 'Je soussigné, '.($info_societe->[0]->{etablissement} || '') .', bailleur du logement situé au '.($info_tblimmobilier->[0]->{biens_adresse}||'') .' - '.($info_tblimmobilier->[0]->{biens_nom}||'').' '.($info_tblimmobilier->[0]->{biens_cp}||'') .' '. ($info_tblimmobilier->[0]->{biens_ville}||'').', déclare avoir reçu de '.($result_locataire->[0]->{locataires_civilite}||'') .' '.($result_locataire->[0]->{locataires_nom}||'') .' '.($result_locataire->[0]->{locataires_prenom}||'').' '.(defined $loc_2 && $loc_2 ne '' ? $loc_2.' ' : '').'la somme de '.($args->{facture_total} || '0.00').' euros ('.(Base::Site::util::number_to_fr($var_facture_montant_1, '€') || '').'), au titre '.$desc.' '.$def_periode.'et '. (defined $loc_2 && $loc_2 ne '' ? 'leur' : 'lui') .' en donne quittance.';
	
	my $print_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=4&amp;code=' . $args->{code}.'&imprimer&archive=' . $args->{archive}.'';
	my $generate_href = '/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?baux=4&amp;code=' . $args->{code}.'&generer=Oui&archive=' . $args->{archive}.'';
	
	my $generate_link = '<input type="submit" id=submit4 class="btn btn-orange" formaction="' . $generate_href . '" value="Générer le pdf" >';
	
	#masquer lien Générer PDF si l'exercice est cloturé
	if ($r->pnotes('session')->{Exercice_Cloture} eq '1') {	$generate_link = '';}

    $content .= '
	<div class="Titre10 centrer"><a class=aperso2>Génération de la quittance</a></div>
	
	<div class="formulaire4">
	
		<form method="post" action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=4&code=' . $args->{code}.'>
			<div class="formflexN2">
			'.$type_quittance.'
			'.$select_month.'
			'.$search_fiscal_year.'
			'. $document_cat_select .'
			<input type=hidden name="archive" value='.($args->{archive} || 0).'>
			<input type="submit" class="btn btn-vert" value="Valider" >
		</form>
		
		<form id="generateform" method="post">
			<input type="submit" id=submit3 class="btn btn-bleuf" formaction="' . $print_href . '" value="Visualiser le pdf" >
			'.$generate_link.'
		</div>
			<input type="hidden" name="biens_nom" value="'. ($info_tblimmobilier->[0]->{biens_nom}||'').'">
			<input type="hidden" name="varloc" value="'. ($varloc||'').'">
			<input type="hidden" name="idfacture" value="'. ($args->{idfacture} || '').'">
			<input type="hidden" name="lettrage" value="'. ($args->{lettrage} || '').'">
			<input type="hidden" name="select_month" value="'. ($args->{select_month} || '').'">
			<input type="hidden" name="type_quittance" value="'. ($args->{type_quittance} || '').'">
			<input type="hidden" name="libelle_cat_doc" value="'. ($args->{libelle_cat_doc} || '').'">
			<input type="hidden" name="select_year" value="'. ($args->{select_year} || '').'">
			<input type="hidden" name="archive" value="'. ($args->{archive} || 0).'">
			</div>
			
			<div class=quittance>
			<div class=signature></div>
	';

	my $var_y = 60;

	my @form_data = (
    { x => 402, y => 57, width => 330, style => "text-align: center; font-weight: bold;font-size: 16px;", name => "AA", text => $args->{AA} || $title, modifier => 1 },
    { x => 45, y => 41, width => 325, style => "text-align: center; font-weight: bold;", name => "AB", text => "Bailleur", modifier => 0 },
	{ x => 50, y => ($var_y += 18), width => 325, style => "text-align: left; font-weight: bold;font-size: 14px;", name => "AC", text => $info_societe->[0]->{etablissement} // "", modifier => 0 },
	{ x => 50, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 12px;", name => "AD", text => $info_societe->[0]->{adresse_1} // "", modifier => 0 },
	{ x => 50, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 12px;", name => "AE", text => ($info_societe->[0]->{code_postal} // ''). ' ' . ($info_societe->[0]->{ville} // ''), modifier => 0 },
	{ x => 50, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 12px;", name => "AF", text => "SIRET: ".($info_societe->[0]->{siret} // '') . "", modifier => 0 },
	{ x => 50, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 12px;", name => "AG", text => $email, modifier => 0 },
	{ x => 45, y => 41, width => 325, style => "text-align: center; font-weight: bold;", name => "AH", text => "Bailleur", modifier => 0 },
	{ x => 405, y => ($var_y = 150), width => 325, style => "text-align: left;font-size: 14px;", name => "AI", text => $loc_1 // '', modifier => 0 },
	{ x => 405, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 14px;", name => "AJ", text => $loc_2 // '', modifier => 0 },
	{ x => 405, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 14px;", name => "AK", text => $addresseloc // '', modifier => 0 },
	{ x => 405, y => ($var_y += 18), width => 325, style => "text-align: left;font-size: 14px;", name => "AL", text => $cpville // '', modifier => 0 },
	{ x => 45, y => 274, width => 325, style => "text-align: center; font-weight: bold;font-size: 10px;", name => "AM", text => "Références à rappeler avec toute correspondance", modifier => 0 },
	{ x => 45, y => 210, width => 325, style => "text-align: center; font-weight: bold;font-size: 14px;", name => "AN", text => $args->{AN} || $appel_loyer, modifier => 1 },
	{ x => 45, y => 236, width => 110, style => "text-align: center; font-weight: bold;font-size: 11px;", name => "AO", text => "Date d'émission", modifier => 0 },
	{ x => 165, y => 236, width => 108, style => "text-align: center; font-weight: bold;font-size: 11px;", name => "AP", text => "Date d'échéance", modifier => 0 },
	{ x => 280, y => 236, width => 85, style => "text-align: center; font-weight: bold;font-size: 11px;", name => "AQ", text => "Réf. Contrat", modifier => 0 },
	{ x => 45, y => 253, width => 110, style => "text-align: center; font-size: 12px;", name => "AR", text => $date_emission, modifier => 1 },
	{ x => 165, y => 253, width => 108, style => "text-align: center; font-size: 12px;", name => "AS", text => $date_echeance, modifier => 1 },
	{ x => 280, y => 256, width => 85, style => "text-align: center; font-size: 12px;", name => "AT", text => $ref_contrat // '', modifier => 0 },
	{ x => 45, y => 312, width => 325, style => "text-align: center; font-weight: bold;", name => "AU", text => $lot, modifier => 0 },
	{ x => 400, y => 312, width => 165, style => "text-align: center; font-weight: bold;", name => "AV", text => "Période", modifier => 0 },
	{ x => 572, y => 312, width => 80, style => "text-align: center; font-weight: bold;", name => "AW", text => "Début", modifier => 0 },
	{ x => 656, y => 312, width => 80, style => "text-align: center; font-weight: bold;", name => "AX", text => "Fin", modifier => 0 },
	{ x => 400, y => 329, width => 165, style => "text-align: center; font-size: 12px;", name => "AY", text => $periode, modifier => 1 },
	{ x => 572, y => 329, width => 80, style => "text-align: center; font-size: 12px;", name => "AZ", text => $date_debut, modifier => 1 },
	{ x => 656, y => 329, width => 80, style => "text-align: center; font-size: 12px;", name => "BA", text => $date_fin, modifier => 1 },
	{ x => 45, y => 332, width => 325, style => "text-align: center; font-size: 12px;", name => "BB", text => $lotdesc, modifier => 0 },
	{ x => 400, y => 358, width => 80, style => "text-align: center; font-weight: bold;", name => "BC", text => "Code", modifier => 0 },
	{ x => 489, y => 358, width => 247, style => "text-align: center; font-weight: bold;", name => "BD", text => "Locataire (s)", modifier => 0 },
	{ x => 400, y => 378, width => 80, style => "text-align: center; font-size: 12px;", name => "BE", text => $codeloc, modifier => 0 },
	{ x => 489, y => 378, width => 247, style => "text-align: center; font-size: 12px;", name => "BF", text => $nomloc, modifier => 0 },
	{ x => 45, y => 425, width => 110, style => "text-align: center; font-weight: bold;", name => "BG", text => "Date", modifier => 0 },
	{ x => 161, y => 425, width => 407, style => "text-align: center; font-weight: bold;", name => "BH", text => "Référence", modifier => 0 },
	{ x => 572, y => 425, width => 164, style => "text-align: center; font-weight: bold;", name => "BI", text => "Montant", modifier => 0 },
	{ x => 488, y => 533, width => 80, style => "text-align: center; font-weight: bold;", name => "BJ", text => "TOTAL", modifier => 0 },
	{ x => 45, y => 693, width => 691, style => "text-align: center; font-weight: bold;", name => "BK", text => "DETAIL DES PAIEMENTS", modifier => 0 },
	{ x => 45, y => 712, width => 110, style => "text-align: center; font-weight: bold;", name => "BL", text => "Date", modifier => 0 },
	{ x => 161, y => 712, width => 408, style => "text-align: center; font-weight: bold;", name => "BM", text => "Mode de paiement / référence", modifier => 0 },
	{ x => 572, y => 712, width => 80, style => "text-align: center; font-weight: bold;", name => "BN", text => "Remb.", modifier => 0 },
	{ x => 655, y => 712, width => 83, style => "text-align: center; font-weight: bold;", name => "BO", text => "Montant", modifier => 0 },
	{ x => 572, y => 847, width => 80, style => "text-align: center; font-weight: bold;", name => "BP", text => "TOTAL", modifier => 0 },
	{ x => 47, y => 443, width => 110, style => "text-align: center; font-size: 12px;", name => "facture_date_1", text => $var_facture_date_1, modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 161, y => 443, width => 407, style => "text-align: left; font-size: 12px;", name => "facture_libelle_1", text => $var_facture_libelle_1, modifier => 1 },
	{ x => 572, y => 443, width => 164, style => "text-align: right; font-size: 12px;", name => "facture_montant_1", text => $var_facture_montant_1, modifier => 1, onchange => 'onchange="format_number(this);calcul_facture_total_quittance();"' },
	{ x => 47, y => 462, width => 110, style => "text-align: center; font-size: 12px;", name => "facture_date_2", text => $var_facture_date_2 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 161, y => 462, width => 407, style => "text-align: left; font-size: 12px;", name => "facture_libelle_2", text => $var_facture_libelle_2 // '', modifier => 1 },
	{ x => 572, y => 462, width => 164, style => "text-align: right; font-size: 12px;", name => "facture_montant_2", text => $var_facture_montant_2 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_facture_total_quittance();"' },
	{ x => 47, y => 481, width => 110, style => "text-align: center; font-size: 12px;", name => "facture_date_3", text => $var_facture_date_3 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 161, y => 481, width => 407, style => "text-align: left; font-size: 12px;", name => "facture_libelle_3", text => $var_facture_libelle_3 // '', modifier => 1 },
	{ x => 572, y => 481, width => 164, style => "text-align: right; font-size: 12px;", name => "facture_montant_3", text => $var_facture_montant_3 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_facture_total_quittance();"' },
	{ x => 47, y => 500, width => 110, style => "text-align: center; font-size: 12px;", name => "facture_date_4", text => $var_facture_date_4 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 161, y => 500, width => 407, style => "text-align: left; font-size: 12px;", name => "facture_libelle_4", text => $var_facture_libelle_4 // '', modifier => 1 },
	{ x => 572, y => 500, width => 164, style => "text-align: right; font-size: 12px;", name => "facture_montant_4", text => $var_facture_montant_4 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_facture_total_quittance();"' },
	{ x => 572, y => 530, width => 164, style => "text-align: right; font-weight: bold;", name => "facture_total", text => $args->{facture_total} // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_facture_total_quittance();"' },
	{ x => 47, y => 730, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_1", text => $var_paiement_date_1 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 730, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_1", text => $var_paiement_libelle_1 // '', modifier => 1 },
	{ x => 571, y => 730, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_1", text => $var_paiement_debit_1 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 730, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_1", text => $var_paiement_credit_1 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 47, y => 749, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_2", text => $var_paiement_date_2 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 749, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_2", text => $var_paiement_libelle_2 // '', modifier => 1 },
	{ x => 571, y => 749, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_2", text => $var_paiement_debit_2 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 749, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_2", text => $var_paiement_credit_2 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 47, y => 768, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_3", text => $var_paiement_date_3 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 768, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_3", text => $var_paiement_libelle_3 // '', modifier => 1 },
	{ x => 571, y => 768, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_3", text => $var_paiement_debit_3 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 768, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_3", text => $var_paiement_credit_3 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 47, y => 787, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_4", text => $var_paiement_date_4 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 787, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_4", text => $var_paiement_libelle_4 // '', modifier => 1 },
	{ x => 571, y => 787, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_4", text => $var_paiement_debit_4 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 787, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_4", text => $var_paiement_credit_4 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 47, y => 806, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_5", text => $var_paiement_date_5 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 806, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_5", text => $var_paiement_libelle_5 // '', modifier => 1 },
	{ x => 571, y => 806, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_5", text => $var_paiement_debit_5 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 806, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_5", text => $var_paiement_credit_5 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 47, y => 825, width => 111, style => "text-align: center; font-size: 12px;", name => "paiement_date_6", text => $var_paiement_date_6 // '', modifier => 1, onchange=>'pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');"' },
	{ x => 162, y => 825, width => 406, style => "text-align: left; font-size: 12px;", name => "paiement_libelle_6", text => $var_paiement_libelle_6 // '', modifier => 1 },
	{ x => 571, y => 825, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_debit_6", text => $var_paiement_debit_6 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 655, y => 825, width => 81, style => "text-align: right; font-size: 12px;", name => "paiement_credit_6", text => $var_paiement_credit_6 // '', modifier => 1, onchange => 'onchange="format_number(this);calcul_paiement_total_quittance();"' },
	{ x => 160, y => 877, width => 460, style => "text-align: center; font-weight: bold;font-size: 14px;", name => "BR", text => $info_societe->[0]->{etablissement} // "", modifier => 1 },
	{ x => 160, y => 900, width => 460, style => "text-align: center; font-size: 12px;", name => "BS", text => "Le gérant", modifier => 1 },
	{ x => 655, y => 844, width => 82, style => "text-align: right; font-weight: bold;", name => "paiement_total", text => $args->{paiement_total} // '', modifier => 1 },
	);
	
	$content .='<textarea id="textareamilieu" name="textareamilieu" class=respinput2 style="position: absolute; width: 693px; left: 45px; top: 575px; height: 90px; text-align: left; font-weight: bold; background-color: #c2e7ff;">'.$lib.'</textarea>';
	$content .='<textarea id="textareafin" name="textareafin" class=respinput2 style="position: absolute; font-style: italic; font-size: 9.8px; width: 693px; left: 45px; top: 1035px; height: 40px; text-align: left; font-weight: bold; background-color: #c2e7ff;">'.$fin.'</textarea>';
	foreach my $field (@form_data) {
		if (defined $field->{modifier} && $field->{modifier} eq 1) {
		$content .= '<input type="text" id="' . $field->{name} . '" name="' . $field->{name} . '" value="' . $field->{text} . '" class=respinput2 style="background-color: #c2e7ff; position: absolute; ' . ($field->{style}) . ' width: ' . ($field->{width}) . 'px; left: ' . ($field->{x}) . 'px; top: ' . ($field->{y}) . 'px;" ' . ($field->{onchange} || '') . '>';
		} else {
		$content .= '<span class="displayspan" style="position: absolute; ' . ($field->{style}) . ' width: ' . ($field->{width}) . 'px; left: ' . ($field->{x}) . 'px; top: ' . ($field->{y}) . 'px;">' . $field->{text} . '</span>';
		} 
	}
	
	$content .= '</form><script>calcul_facture_total_quittance();calcul_paiement_total_quittance();</script>';
	
	if (defined $args->{bypass} && $args->{bypass} eq 1) {
		$content .= '<script>document.getElementById("submit4").click();</script>';
	}

	return $content;
}

#/*—————————————— Export PDF Champ——————————————*/
sub export_pdf {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;

	my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);
	$args->{immo_contrat} = $args->{code} // undef;
	
	my $info_tblimmobilier = '';
    if (defined $args->{archive} && $args->{archive} eq 1) {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 1, $args);
	} else {
		$info_tblimmobilier = Base::Site::bdd::get_immobilier_baux($dbh, $r, 2, $args);
	}
	
    my $pdf = PDF::API2->new(); # Création d'un nouveau document PDF
    my $page = $pdf->page; # Création d'une nouvelle page
    $page->mediabox('A4'); # Définition du format
    my $image_path = '/var/www/html/Compta/images/pdf/quittance.jpeg'; # Image de fond
	my $signature_path = '/var/www/html/Compta/images/pdf/signature.jpeg'; # Image de fond
	    
	my $image_object = $pdf->image_jpeg($image_path);
	my $signature_object = $pdf->image_jpeg($signature_path);

    my $gfx = $page->gfx;
	$gfx->image($image_object, 0, 0, 595.276, 841.890);  # Taille A4 en points (1 point = 1/72 pouce)
	$gfx->image($signature_object, ((34+552-150) / 2), 61, 140, 100);  # Taille A4 en points (1 point = 1/72 pouce)


	my $font = $pdf->corefont('Helvetica');
	my $font_bold = $pdf->corefont('Helvetica-Bold');
	my $font_italic = $pdf->corefont('Helvetica-Oblique');
	my $font_bold_italic = $pdf->corefont('Helvetica-BoldOblique');

	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor('#000');
	$text->fillcolor('#000');
	
	my $result_date = Base::Site::util::transformation_mois($args->{select_year}, $args->{select_month});
	my $periode = $args->{AY} || '';
	my $date_debut = $args->{AZ} || '';
	my $date_fin = $args->{BA} || '';
	my $ref_contrat = $args->{code} || '';

	my $title = $args->{AA} || '';
	my $appel_loyer = $args->{AN} || '';
	my $date_emission = $args->{AR} || '';
	my $date_echeance = $args->{AS} || '';
	my $lib = $args->{textareamilieu} || '';
	my $fin = $args->{textareafin} || '';
	my $societe1 = $args->{BR} || '';
	my $societe2 = $args->{BS} || '';
	my $facture_date_1 = $args->{facture_date_1} || '';
	my $facture_montant_1 = defined $args->{facture_montant_1} && $args->{facture_montant_1} ne '' ? Base::Site::util::affichage_montant_V2($args->{facture_montant_1}) . ' €' : '';
	my $facture_libelle_1 = $args->{facture_libelle_1} || '';
	my $facture_date_2 = $args->{facture_date_2} || '';
	my $facture_montant_2 = defined $args->{facture_montant_2} && $args->{facture_montant_2} ne '' ? Base::Site::util::affichage_montant_V2($args->{facture_montant_2}) . ' €' : '';
	my $facture_libelle_2 = $args->{facture_libelle_2} || '';
	my $facture_date_3 = $args->{facture_date_3} || '';
	my $facture_montant_3 = defined $args->{facture_montant_3} && $args->{facture_montant_3} ne '' ? Base::Site::util::affichage_montant_V2($args->{facture_montant_3}) . ' €' : '';
	my $facture_libelle_3 = $args->{facture_libelle_3} || '';
	my $facture_date_4 = $args->{facture_date_4} || '';
	my $facture_montant_4 = defined $args->{facture_montant_4} && $args->{facture_montant_4} ne '' ? Base::Site::util::affichage_montant_V2($args->{facture_montant_4}) . ' €' : '';
	my $facture_libelle_4 = $args->{facture_libelle_4} || '';
	my $facture_total = defined $args->{facture_total} && $args->{facture_total} ne '' ? Base::Site::util::affichage_montant_V2($args->{facture_total}) . ' €' : '';
	my $paiement_date_1 = $args->{paiement_date_1} || '';
	my $paiement_credit_1 = defined $args->{paiement_credit_1} && $args->{paiement_credit_1} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_1}) . ' €' : '';
	my $paiement_debit_1 = defined $args->{paiement_debit_1} && $args->{paiement_debit_1} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_1}) . ' €' : '';
	my $paiement_libelle_1 = $args->{paiement_libelle_1} || '';
	my $paiement_date_2 = $args->{paiement_date_2} || '';
	my $paiement_credit_2 = defined $args->{paiement_credit_2} && $args->{paiement_credit_2} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_2}) . ' €' : '';
	my $paiement_debit_2 = defined $args->{paiement_debit_2} && $args->{paiement_debit_2} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_2}) . ' €' : '';
	my $paiement_libelle_2 = $args->{paiement_libelle_2} || '';
	my $paiement_date_3 = $args->{paiement_date_3} || '';
	my $paiement_credit_3 = defined $args->{paiement_credit_3} && $args->{paiement_credit_3} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_3}) . ' €' : '';
	my $paiement_debit_3 = defined $args->{paiement_debit_3} && $args->{paiement_debit_3} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_3}) . ' €' : '';
	my $paiement_libelle_3 = $args->{paiement_libelle_3} || '';
	my $paiement_date_4 = $args->{paiement_date_4} || '';
	my $paiement_credit_4 = defined $args->{paiement_credit_4} && $args->{paiement_credit_4} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_4}) . ' €' : '';
	my $paiement_debit_4 = defined $args->{paiement_debit_4} && $args->{paiement_debit_4} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_4}) . ' €' : '';
	my $paiement_libelle_4 = $args->{paiement_libelle_4} || '';
	my $paiement_date_5 = $args->{paiement_date_5} || '';
	my $paiement_credit_5 = defined $args->{paiement_credit_5} && $args->{paiement_credit_5} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_5}) . ' €' : '';
	my $paiement_debit_5 = defined $args->{paiement_debit_5} && $args->{paiement_debit_5} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_5}) . ' €' : '';
	my $paiement_libelle_5 = $args->{paiement_libelle_5} || '';
	my $paiement_date_6 = $args->{paiement_date_6} || '';
	my $paiement_credit_6 = defined $args->{paiement_credit_6} && $args->{paiement_credit_6} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_credit_6}) . ' €' : '';
	my $paiement_debit_6 = defined $args->{paiement_debit_6} && $args->{paiement_debit_6} ne '' ? Base::Site::util::affichage_montant_V2($args->{paiement_debit_6}) . ' €' : '';
	my $paiement_libelle_6 = $args->{paiement_libelle_6} || '';
	my $paiement_total = defined $args->{paiement_total} && ($args->{paiement_total} ne '0.00' ) ? Base::Site::util::affichage_montant_V2($args->{paiement_total}) . ' €' : '';
	
	$sql = 'SELECT * FROM tblimmobilier_locataire t1
	LEFT JOIN tblimmobilier t2 ON t1.id_client = t2.id_client AND t1.locataires_contrat = t2.immo_contrat
	LEFT JOIN tblimmobilier_logement t3 ON t1.id_client = t3.id_client AND t2.immo_logement = t3.biens_ref
	WHERE t1.id_client = ? AND t1.locataires_contrat = ? AND t1.locataires_type = ? ORDER BY id_loc';
	my $result_locataire = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{code}, 'Locataire') };
	
	my $loc_1 = defined $result_locataire->[0]->{locataires_nom} ? ''.$result_locataire->[0]->{locataires_civilite} .' '.	$result_locataire->[0]->{locataires_nom} .' '.$result_locataire->[0]->{locataires_prenom} : '';
	my $loc_2 = defined $result_locataire->[1]->{locataires_nom} ? 'et '.$result_locataire->[1]->{locataires_civilite} .' '.	$result_locataire->[1]->{locataires_nom} .' '.$result_locataire->[1]->{locataires_prenom} : '';
	my $email = defined $info_societe->[0]->{courriel} ? "Email: " . ($info_societe->[0]->{courriel} // '') . "" : "";
	my $addresseloc = ($info_tblimmobilier->[0]->{biens_adresse}||'') .' - '.	($info_tblimmobilier->[0]->{biens_nom}||'');
	my $cpville = ($info_tblimmobilier->[0]->{biens_cp}||'') .' '. ($info_tblimmobilier->[0]->{biens_ville}||''); 
	my $lot = 'Lot (Réf. '.($info_tblimmobilier->[0]->{immo_logement}||'').')';
	my $lotdesc = ($info_tblimmobilier->[0]->{biens_ville}||'')  .' - '. ($info_tblimmobilier->[0]->{biens_nom}||'');
	my $codeloc = ($result_locataire->[0]->{locataires_ref} ||'');
	my $nomloc = ($result_locataire->[0]->{locataires_civilite}||'') .' '. ($result_locataire->[0]->{locataires_nom}||'').' '. (defined $result_locataire->[1]->{locataires_nom} ? "et ".$result_locataire->[1]->{locataires_civilite} ." ".	$result_locataire->[1]->{locataires_nom}." ": "");

	my $fin1 = 'La présente quittance ne libère l\'occupant que pour la période indiquée et annule tout reçu à valoir. Elle n\'est pas libératoire';
	my $fin2 = 'des loyers antérieurs impayés et est délivrée sous réserve de toutes instances judiciaires en cours.';

	my @info_list = (
        { x => (295 + 550) / 2, y => 785, font => $font_bold, size => 20, text => $title, center => 1 },
        { x => (34 + 278) / 2, y => 801.5, font => $font_bold, size => 12, text => "Bailleur", center => 1 },
        { x => 40, y => 774, font => $font_bold, size => 12, text => $info_societe->[0]->{etablissement} // "", center => 0 },
        { x => 40, y => 760, font => $font, size => 10, text => $info_societe->[0]->{adresse_1} // "", center => 0 },
        { x => 40, y => 746, font => $font, size => 10, text => ($info_societe->[0]->{code_postal} // ''). ' ' . ($info_societe->[0]->{ville} // ''), center => 0 },
		{ x => 40, y => 732, font => $font, size => 10, text => "SIRET: ".($info_societe->[0]->{siret} // '') . "", center => 0 },
		{ x => 40, y => 718, font => $font, size => 10, text => $email, center => 0 },
		{ x => (34 + 120) / 2, y => 656, font => $font_bold, size => 10, text => "Date d'émission", center => 1 },
		{ x => (120 + 209) / 2, y => 656, font => $font_bold, size => 10, text => "Date d'échéance", center => 1 },
		{ x => (209+ 278) / 2, y => 656, font => $font_bold, size => 10, text => "Réf. Contrat", center => 1 },
		{ x => (34 + 120) / 2, y => 642, font => $font, size => 10, text => $date_emission, center => 1 },
		{ x => (120 + 209) / 2, y => 642, font => $font, size => 10, text => $date_echeance, center => 1 },
		{ x => (209+ 278) / 2, y => 642, font => $font, size => 10, text => $ref_contrat, center => 1 },
		{ x => (34 + 278) / 2, y => 630, font => $font_bold, size => 8, text => "Références à rappeler avec toute correspondance", center => 1 },
		{ x => (34 + 278) / 2, y => 671, font => $font_bold, size => 12, text => $appel_loyer, center => 1 },
		{ x => 305, y => 717, font => $font, size => 12, text => $loc_1 // '', center => 0 },
		{ x => 305, y => 700, font => $font, size => 12, text => $loc_2 // '', center => 0 },
		{ x => 305, y => 683, font => $font, size => 12, text => $addresseloc // '', center => 0 },
		{ x => 305, y => 666, font => $font, size => 12, text => $cpville // '', center => 0 },
		{ x => (34 + 278) / 2, y => 599, font => $font_bold, size => 10, text => $lot, center => 1 },
		{ x => (297 + 427) / 2, y => 599, font => $font_bold, size => 10, text => "Période", center => 1 },
		{ x => (428 + 490) / 2, y => 599, font => $font_bold, size => 10, text => "Début", center => 1 },
		{ x => (490 + 552) / 2, y => 599, font => $font_bold, size => 10, text => "Fin", center => 1 },
		{ x => (297 + 427) / 2, y => 585, font => $font, size => 10, text => $periode, center => 1 },
		{ x => (427 + 490) / 2, y => 585, font => $font, size => 10, text => $date_debut, center => 1 },
		{ x => (490 + 552) / 2, y => 585, font => $font, size => 10, text => $date_fin, center => 1 },
		{ x => (34 + 278) / 2, y => 585, font => $font, size => 10, text => $lotdesc, center => 1 },
		{ x => (297 + 363) / 2, y => 564, font => $font_bold, size => 10, text => "Code", center => 1 },
		{ x => (363 + 552) / 2, y => 564, font => $font_bold, size => 10, text => "Locataire (s)", center => 1 },
		{ x => (297 + 363) / 2, y => 550, font => $font, size => 10, text => $codeloc, center => 1 },
		{ x => (363 + 552) / 2, y => 550, font => $font, size => 10, text => $nomloc, center => 1 },
		{ x => (34 + 120) / 2, y => 515, font => $font_bold, size => 10, text => "Date", center => 1 },
		{ x => (34 + 427) / 2, y => 515, font => $font_bold, size => 10, text => "Référence", center => 1 },
		{ x => (428 + 552) / 2, y => 515, font => $font_bold, size => 10, text => "Montant", center => 1 },
		{ x => (363 + 427) / 2, y => 433, font => $font_bold, size => 10, text => "TOTAL", center => 1 },
		{ x => 546, y => 433, font => $font, size => 10, text => $facture_total, center => 2 },
		{ x => (34 + 552) / 2, y => 313, font => $font_bold, size => 10, text => "DETAIL DES PAIEMENTS", center => 1 },
		{ x => (34 + 120) / 2, y => 299, font => $font_bold, size => 10, text => "Date", center => 1 },
		{ x => (120 + 427) / 2, y => 299, font => $font_bold, size => 10, text => "Mode de paiement / référence", center => 1 },
		{ x => (428 + 490) / 2, y => 299, font => $font_bold, size => 10, text => "Remb.", center => 1 },
		{ x => (489 + 552) / 2, y => 299, font => $font_bold, size => 10, text => "Montant", center => 1 },
		{ x => (428 + 490) / 2, y => 198, font => $font_bold, size => 10, text => "TOTAL", center => 1 },
		{ x => (34 + 120) / 2, y => 499, font => $font, size => 10, text => $facture_date_1, center => 1 },
		{ x => 126, y => 499 , font => $font, size => 10, text => $facture_libelle_1, center => 0 },
		{ x => 546, y => 499 , font => $font, size => 10, text => $facture_montant_1, center => 2 },
		{ x => (34 + 120) / 2, y => 484, font => $font, size => 10, text => $facture_date_2, center => 1 },
		{ x => 126, y => 484 , font => $font, size => 10, text => $facture_libelle_2, center => 0 },
		{ x => 546, y => 484 , font => $font, size => 10, text => $facture_montant_2, center => 2 },
		{ x => (34 + 120) / 2, y => 469, font => $font, size => 10, text => $facture_date_3, center => 1 },
		{ x => 126, y => 469 , font => $font, size => 10, text => $facture_libelle_3, center => 0 },
		{ x => 546, y => 469 , font => $font, size => 10, text => $facture_montant_3, center => 2 },
		{ x => (34 + 120) / 2, y => 454, font => $font, size => 10, text => $facture_date_4, center => 1 },
		{ x => 126, y => 454 , font => $font, size => 10, text => $facture_libelle_4, center => 0 },
		{ x => 546, y => 454 , font => $font, size => 10, text => $facture_montant_4, center => 2 },
		{ x => (34 + 120) / 2, y => 284, font => $font, size => 10, text => $paiement_date_1, center => 1 },
		{ x => 126, y => 284, font => $font, size => 10, text => $paiement_libelle_1, center => 0 },
		{ x => 484, y => 284, font => $font, size => 10, text => $paiement_debit_1, center => 2 },
		{ x => 546, y => 284, font => $font, size => 10, text => $paiement_credit_1, center => 2 },
		{ x => (34 + 120) / 2, y => 270, font => $font, size => 10, text => $paiement_date_2, center => 1 },
		{ x => 126, y => 270, font => $font, size => 10, text => $paiement_libelle_2, center => 0 },
		{ x => 484, y => 270, font => $font, size => 10, text => $paiement_debit_2, center => 2 },
		{ x => 546, y => 270, font => $font, size => 10, text => $paiement_credit_2, center => 2 },
		{ x => (34 + 120) / 2, y => 256, font => $font, size => 10, text => $paiement_date_3, center => 1 },
		{ x => 126, y => 256, font => $font, size => 10, text => $paiement_libelle_3, center => 0 },
		{ x => 484, y => 256, font => $font, size => 10, text => $paiement_debit_3, center => 2 },
		{ x => 546, y => 256, font => $font, size => 10, text => $paiement_credit_3, center => 2 },
		{ x => (34 + 120) / 2, y => 242, font => $font, size => 10, text => $paiement_date_4, center => 1 },
		{ x => 126, y => 242, font => $font, size => 10, text => $paiement_libelle_4, center => 0 },
		{ x => 484, y => 242, font => $font, size => 10, text => $paiement_debit_4, center => 2 },
		{ x => 546, y => 242, font => $font, size => 10, text => $paiement_credit_4, center => 2 },
		{ x => (34 + 120) / 2, y => 228, font => $font, size => 10, text => $paiement_date_5, center => 1 },
		{ x => 126, y => 228, font => $font, size => 10, text => $paiement_libelle_5, center => 0 },
		{ x => 484, y => 228, font => $font, size => 10, text => $paiement_debit_5, center => 2 },
		{ x => 546, y => 228, font => $font, size => 10, text => $paiement_credit_5, center => 2 },
		{ x => (34 + 120) / 2, y => 214, font => $font, size => 10, text => $paiement_date_6, center => 1 },
		{ x => 126, y => 214, font => $font, size => 10, text => $paiement_libelle_6, center => 0 },
		{ x => 484, y => 214, font => $font, size => 10, text => $paiement_debit_6, center => 2 },
		{ x => 546, y => 214, font => $font, size => 10, text => $paiement_credit_6, center => 2 },
		{ x => 546, y => 198, font => $font, size => 10, text => $paiement_total, center => 2 },
		{ x => (34 + 552) / 2, y => 175, font => $font_bold, size => 10, text => $societe1, center => 1 },
		{ x => (34 + 552) / 2, y => 164, font => $font_italic, size => 9, text => $societe2, center => 1 },
    );
					
    # Ajout des informations à la page { x => 40, y => 400, font => $font, size => 10, text => $lib, center => 3 },
    for my $info (@info_list) {
        $text->translate($info->{x}, $info->{y});
        $text->font($info->{font}, $info->{size});
        
        if ($info->{center} eq 1) {
            $text->text_center($info->{text});
        } elsif ($info->{center} eq 0) {
            $text->text($info->{text});
        } elsif ($info->{center} eq 2) {
            $text->text_right($info->{text});
        } elsif ($info->{center} eq 3) {
            $text->paragraph($info->{text}, 506, 10);
        }
    }
	
	# Paragraphe textarea milieu
	$text->lead(15);
    $text->font($font_bold, 11);
    $text->translate(34, 395);
	$text->paragraph($lib, 490, 200 );
	
	# Paragraphe textarea fin
	$text->lead(15);
    $text->font($font_bold_italic, 9);
    $text->translate(35, 49);
	$text->paragraph($fin, 489, 200 );

	#Enregistrer le pdf
	my $file = '/Compta/images/pdf/quittancetest.pdf';
	my $pdf_file = $r->document_root() . $file;
	$pdf->saveas($pdf_file);

	return $file ;

} #sub export_pdf 

#/*—————————————— Menu Notes de Frais ——————————————*/
sub display_menu_gestion_immobiliere {
	
	#########################################	
	#définition des variables				#
	#########################################
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my $content ;
	my ($baux_en_cours_link, $baux_archive_link, $logement_en_cours, $logement_archive) = ('', '', '', '');

	#########################################	
	#définition des liens					#
	#########################################
	#lien vers la catégorie "Tous les Baux"
	my $all_baux_class = defined $args->{piece_ref} || ((!defined $args->{nouveau}) && (!defined $args->{logements}) && (!defined $args->{infobailleur})) ? 'linavselect' : 'linav';
	my $all_baux_link = '<li><a class=' . $all_baux_class  . ' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere" >Gestion des Baux</a></li>' ;
	
	#lien vers la création d'un nouveau bail
	my $logements_class = ( defined $args->{logements} ) ? 'linavselect' : 'linav' ;
	my $logements_link = '<li><a class='.$logements_class.' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements">Gestion des logements</a></li>' ;
	
	my $baux_en_cours_class = defined $args->{piece_ref} || ((!defined $args->{nouveau}) && (!defined $args->{archive}) && (!defined $args->{logements}) && (!defined $args->{infobailleur})) ? 'linavselect' : 'linav';
	my $baux_archive_class = ( defined $args->{archive} && !defined $args->{logements}) ? 'linavselect' : 'linav' ;
	
	my $logement_en_cours_class = ( defined $args->{logements} && (!defined $args->{biens_archive}) ) ? 'linavselect' : 'linav' ;
	my $logement_archive_class = ( defined $args->{logements} && defined $args->{biens_archive} ) ? 'linavselect' : 'linav' ;
	
	
	if ( defined $args->{logements} ) {
		$logement_en_cours = '<li><a class='.$logement_en_cours_class.' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements">Logements en cours</a></li>' ;
		$logement_archive = '<li><a class='.$logement_archive_class.' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?logements&biens_archive">Logements archivés</a></li>' ;
	} else {
		$baux_en_cours_link = '<li><a class='.$baux_en_cours_class.' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere">Baux en cours</a></li>' ;
		$baux_archive_link = '<li><a class='.$baux_archive_class.' href="/'.$r->pnotes('session')->{racine}.'/gestionimmobiliere?archive">Baux archivés</a></li>' ;
	}
	
	#<div class="menuN2"><ul class="main-nav2">'.$baux_en_cours_link . $baux_archive_link . $logement_en_cours . $logement_archive . '</ul></div>
	
	#########################################	
	#génération du menu						#
	#########################################
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '
	<div class="menu"><ul class="main-nav2">' . $all_baux_link . $logements_link . '</ul></div>
	' ;
	} else {
	$content .= '<div class="menu"><ul class="main-nav2"></ul></div>' ;
	}

    return $content ;

} #sub display_menu_gestion_immobiliere 

sub form_email {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;
    
    if (defined $args->{baux} && $args->{baux} eq 3){
		$args->{restart} = 'gestionimmobiliere?baux='.$args->{baux}.'&code='.$args->{code}.'&archive=' . $args->{archive}.'&id_name=' . ($args->{id_name} || '') . '&email';
	} elsif (defined $args->{baux} && $args->{baux} eq 5){
		$args->{restart} = 'gestionimmobiliere?baux='.$args->{baux}.'&code='.$args->{code}.'&archive=' . $args->{archive}.'&email';
	}

	$content .= Base::Site::util::form_email( $r, $args );
	
	return $content;
	
}

sub form_rapide {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;
    
    my $info_compte = Base::Site::bdd::get_immobilier_compte($dbh, $r, $args->{code});
    
    if ($info_compte) {
		if (defined $args->{scenario} && ($args->{scenario} eq 'depot_garantie' || $args->{scenario} eq 'remboursement_depot_garantie')) {
		$args->{montant} = sprintf("%.2f", $info_compte->{immo_depot}/100);
		}
		$args->{compte_client} = $info_compte->{immo_compte};
		$args->{compte_client2} = $info_compte->{immo_compte};
		$args->{compte_autres} = $info_compte->{immo_compte};
	}
    
    #my $forms_saisie_rapide .= '<fieldset class="pretty-box centrer">'.Base::Site::menu::forms_paiement_saisie( $r, $args, $dbh ).'</fieldset><br>';
	
	$content .= Base::Site::menu::forms_paiement_saisie( $r, $args, $dbh );
	
	return $content;
	
}

1 ;
