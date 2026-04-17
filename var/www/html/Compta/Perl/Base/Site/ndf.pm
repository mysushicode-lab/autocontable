package Base::Site::ndf;
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
    
	if ( defined $args{edit_cat_doc_set} ) {
		
	$content = form_edit_cat_doc( $r, \%args ) ;
	
	} elsif ( defined $args{new_document} ) {
		
	$content = form_new_docs( $r, \%args ) ;
	
	} elsif ( defined $args{baremekm} ) {
		
	$content = form_baremekm( $r, \%args ) ;
	
	} elsif ( defined $args{vehicule} ) {
		
	$content = form_vehicule( $r, \%args ) ;
	
	} else {
		
	$content .= visualize( $r, \%args ) ;	
	
	}  

	$r->no_cache(1) ;
	$r->content_type('text/html; charset=utf-8') ;
	print $content ;
	return Apache2::Const::OK ;

}

#/*—————————————— Page principale des notes de frais ——————————————*/
sub visualize {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $id_client = $r->pnotes('session')->{id_client} ;
	my @search = ('0') x 15;
	my $line = "1"; 
    
	################ Affichage MENU ################
	$content .= display_menu_ndf( $r, $args ) ;
	################ Affichage MENU ################
	
	$content .= '<div class="wrapper-docs-entry">
    <fieldset class="pretty-box">
    <legend><h3 class="Titre09">Gestion des notes de frais</h3></legend>
    <div class="centrer">';
        
    if ( defined $args->{nouveau} && $r->pnotes('session')->{Exercice_Cloture} ne '1') {
		$content .= form_new_nds( $r, $args  ) ;
	}
	
	$content .= '<div class="Titre10">';
	
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '<span class=check><a href="notesdefrais?nouveau" title="Cliquer pour ajouter une note de frais" class="label3">Ajouter une note de frais<span class="plus">+</span></a></span>' ;
	}
    
    $content .= '<div class="centrer"> Liste des notes de frais</div></div>';
    
    #SELECT frais_line, piece_ref, frais_date, frais_compte, frais_libelle, frais_quantite, frais_montant, frais_doc
	#Requête liste des notes de frais
	$sql = '
	SELECT DISTINCT ON(t1.piece_ref) t1.piece_ref, t1.piece_date, t1.piece_compte, t1.id_vehicule, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t5.documents1, to_char(t3.frais_montant/100::numeric, \'999G999G999G990D00\') as total, t3.frais_quantite::integer as totalkm
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN (
	SELECT piece_ref, id_client, fiscal_year, sum(frais_montant) frais_montant, sum(frais_quantite) frais_quantite FROM tblndf_detail GROUP BY piece_ref, id_client, fiscal_year ) 
	t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.piece_ref = t3.piece_ref
	INNER JOIN tblcompte t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t1.piece_compte = t4.numero_compte
	LEFT JOIN (SELECT DISTINCT ON(id_entry) id_entry, id_client, fiscal_year, id_facture, documents1 FROM tbljournal) t5 ON t1.id_client = t5.id_client AND t1.fiscal_year = t5.fiscal_year AND t1.piece_entry = t5.id_entry
	WHERE t1.id_client = ? AND t1.fiscal_year = ?
	ORDER BY t1.piece_ref
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    
    ############## MISE EN FORME DEBUT ##############
    
    #gestion des options

	my $entry_list .= '
		<li class="style2 ">
		<div class="spacer"></div>
			<span class=headerspan style="width: 0.5%;">&nbsp;</span>
			<span class=headerspan style="width: 10%;">Référence</span>
			<span class=headerspan style="width: 9%;">Date</span>
			<span class=headerspan style="width: 28%;">Tiers</span>
			<span class=headerspan style="width: 28%;">Libellé</span>
			<span class=headerspan style="width: 8%;text-align: right;">KM</span>
			<span class=headerspan style="width: 8%;text-align: right;">Montant</span>
			<span class=headerspan style="width: 0.5%;">&nbsp;</span>
			<span class=headerspan style="width: 2.5%;">&nbsp;</span>
			<span class=headerspan style="width: 2.5%;">&nbsp;</span>
			<span class=headerspan style="width: 2.5%;">&nbsp;</span>
			<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<div class="spacer"></div>
		</li>
	' ;

	for ( @{ $array_of_notes } ) {
		my $reqline = ($line ++);	
		my $statut = '<span class="displayspan" style="width: 2.5%; text-align: center;"><img id="statut_'.$reqline.'" title="en cours" src="/Compta/style/icons/encours.png" height="16" width="16" alt="statut"></span>';
		my $class = 'line_icon_hidden';
		if ($_->{piece_entry} ){
		$class = 'line_icon_visible';	
		$statut = '<span class="displayspan" style="width: 2.5%; text-align: center;"><img id="statut_'.$reqline.'" title="Comptabilisée" src="/Compta/style/icons/valider.png" height="16" width="16" alt="statut"></span>';
		}	
	
		
			#piece_ref, piece_date, piece_compte,	piece_libelle, piece_entry
			my $piece_ref_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref=' . $_->{piece_ref} ;
			#ligne d'en-têtes
			$entry_list .= '
				<li class=listitem3 id="line_'.($_->{piece_ref} || '').'"><a href="' . $piece_ref_href . '"><span class=displayspan2><div class=flex-table><div class=spacer></div>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<span class=blockspan style="width: 10%;">' . ( $_->{piece_ref} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 9%;">' . $_->{piece_date} . '</span>
				<span class=blockspan style="width: 28%;">' . $_->{piece_compte} . ' - ' . $_->{libelle_compte} . '</span>
				<span class=blockspan style="width: 28%;">' . ( $_->{piece_libelle} || '&nbsp;') . '</span>
				<span class=blockspan style="width: 8%;text-align: right;">' . ($_->{totalkm} || '&nbsp;'). '</span>
				<span class=blockspan style="width: 8%;text-align: right;">' . ($_->{total} || '&nbsp;'). '</span>
				</a>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				'.$statut.'
				<a class=nav href="/'.$r->pnotes('session')->{racine}.'/entry?open_journal=OD&id_entry='.($_->{piece_entry} || '').'">
				<span class="displayspan" style="width: 2.5%; text-align: center;"><img id="valider_'.$reqline.'" class='.$class.' title="Voir l\'écriture comptable associée" src="/Compta/style/icons/lien.png" height="16" width="16" alt="valider"></span></a>
				<a class=nav href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($_->{documents1} || '').'">
				<span class="displayspan" style="width: 2.5%; text-align: center;"><img id="documents_'.$reqline.'" class='.$class.' title="Voir le document associé" src="/Compta/style/icons/documents.png" height="16" width="16" alt="documents"></span></a>
				</a>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<div class=spacer></div></div></li></span>
			' ;
		}
		
		if ( !@$array_of_notes ) {
			#aucun compte n'existe
			$content .= Base::Site::util::generate_error_message('
			*** Aucune note de frais n\'a été créée. ***
			<br><br>
			<a class=nav href="notesdefrais?nouveau">Ajouter une note de frais</a>
			') ;
		} else {
		$entry_list .=  '<li class=style1><hr></li>' ;
		$content .= '<ul class=wrapper100>' . $entry_list . '</ul>' ;
		}
		
		if ( !defined $args->{nouveau} && defined $args->{piece_ref} && $args->{piece_ref} ne '') {
			$content .= form_gestion_frais( $r, $args ) ;
		}
		
		$content .= '</div></div>
		<script>
		focusAndChangeColor2("'.($args->{piece_ref} || '').'");
		</script>';

		return $content ;

} #sub visualize

#/*—————————————— Page Formulaire nouvelle note de frais ——————————————*/
sub form_new_nds {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $selected = '';
	
	#/************ ACTION DEBUT *************/
	
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{nouveau} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		#on interdit libelle vide

		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{piece_libelle});
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [17, $args->{piece_compte}], [8, $args->{piece_date}], [10, $args->{piece_libelle}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter une note de frais
			$sql = 'INSERT INTO tblndf (id_client, fiscal_year, piece_ref, piece_date, piece_compte, piece_libelle) values (?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}, $args->{piece_date}, $args->{piece_compte} , $args->{piece_libelle} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Cette note de frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@);}
			}
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout de la note de frais '.$args->{piece_ref}.' - '. $args->{piece_libelle} .'');
			
			#Redirection
			$args->{restart} = 'notesdefrais?piece_ref='.$args->{piece_ref}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		
		}
    }
    
	#/************ ACTION FIN *************/
	
	#on regarde s'il existe des NDF enregistrées pour l'année en cours
	my $item_num = 1;
	$sql = 'SELECT piece_ref FROM tblndf WHERE id_client = ? and fiscal_year = ? ORDER BY 1 DESC LIMIT 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $result_set =  eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ; 
	
	    for ( @$result_set ) {
			if (substr( $_->{piece_ref}, 8, 4 ) =~ /\d/) {
			$item_num = int(substr( $_->{piece_ref}, 8, 4 )) + 1	;
			} 
		}
	
	if ($item_num<1000 && $item_num>=100) {$item_num="0".$item_num; }	
	elsif ($item_num<100 && $item_num>=10) {$item_num="00".$item_num; }
	elsif ($item_num<10) {	$item_num="000".$item_num; }
	my $numero_piece = 'NF'.$r->pnotes('session')->{fiscal_year} . '-' . $item_num ;

	
	#numero compte et libelle compte tiers
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 3) IN (\'421\',\'455\',\'467\',\'108\') ORDER by libelle_compte' ;
    my $compte_tiers_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_tiers = '<select class="respinput" style="width: 30%" name=piece_compte id=compte_tiers
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}"
	>' ;
	$compte_tiers .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_tiers .= '<option value="" selected>--Sélectionner--</option>' ;
	for ( @$compte_tiers_set ) {
	if 	(defined $args->{piece_compte}) {
	$selected = ( $_->{numero_compte} eq $args->{piece_compte} ) ? 'selected' : '' ;
	}			
	$compte_tiers .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_tiers .= '</select>' ;
	
	############## Formulaire Ajout d'une nouvelle note de frais ##############
	$content .= '	
		<fieldset class="centrer Titre09 pretty-box">
		
		<div class="Titre10"><span class=check2>
			<a href="notesdefrais" title="fermer la fenêtre" class="label3">
			<span >[X]</span></a></span>
			<div class="green centrer"> Enregistrement d\'une nouvelle note de frais </div>
		</div>

			<form class=wrapper1 action="/'.$r->pnotes('session')->{racine}.'/notesdefrais?nouveau" method=POST enctype="multipart/form-data">

				<div class=formflexN2>
				<label class="forms2_label" style="width: 15%;" for="piece_ref">Référence</label>
				<label class="forms2_label" style="width: 10%;" for="date_comptant20">Date</label>
				<label class="forms2_label" style="width: 30%;" for="compte_tiers">Tiers</label>
				<label class="forms2_label" style="width: 35%;" for="libelle4">Libellé</label>
				</div>
				
				<div class=formflexN2>
				<input class="respinput" style="width: 15%" type=text id=piece_ref name=piece_ref value="'.($numero_piece || '').'" readonly/>
				<input class="respinput" style="width: 10%;" type="text" name=piece_date id=date_comptant20 value="' . ($args->{piece_date} || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" required>
				' . $compte_tiers . '
				<input class="respinput" style="width: 35%;" type=text id=libelle4 name=piece_libelle value="'.($args->{piece_libelle}|| '').'" required onclick="liste_search_libelle(this.value, 4)" list="libellelist_4"><datalist id="libellelist_4"></datalist>
				</div>
				
				<div class=formflexN3>
				<input type=submit id=submit style="width: 10%;" class="btn btn-vert" value=Ajouter>
				</div>
				
				<input type=hidden name=id_client value="' . $r->pnotes('session')->{id_client} . '">
				<input type=hidden name=fiscal_year value="'.$r->pnotes('session')->{fiscal_year}.'">
				<input type=hidden name=ajouter value="1">
					
			</form>

		</fieldset><br>
	' ;

    return $content ;
    
} #sub form_new_docs 

#/*—————————————— Page Gestion des Notes de Frais ——————————————*/
sub form_gestion_frais {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array) ;
	map { ($_) = '' } my ($content, $selected, $disabled, $submit_enabled_1, $submit_enabled_2);
  	$args->{_token_id} ||= Base::Site::util::generate_unique_token_id($r, $dbh);
  	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur le bouton 'Supprimer' 	  #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{supprimer} && $args->{supprimer} eq '0' && !defined $args->{frais_line}) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'&amp;supprimer=1&amp;piece_libelle='.$args->{piece_libelle}.'';
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer la note de frais ' . $args->{piece_ref} . ' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{piece_ref} && defined $args->{supprimer} && $args->{supprimer} eq '1' && !defined $args->{frais_line}) {
			
			#demande de suppression confirmée
			$sql = 'DELETE FROM tblndf WHERE piece_ref = ? AND id_client = ? AND fiscal_year = ?' ;
			@bind_array = ( $args->{piece_ref}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Suppression de la note frais ' . $args->{piece_ref} . ' - '.$args->{piece_libelle}.'');
				
				#Redirection
				$args->{restart} = 'notesdefrais';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé	

			}

	}
    
    ####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur le bouton 'Comptabiliser' #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{comptabiliser} && $args->{comptabiliser} eq '0' && !defined $args->{frais_line}) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'' ;

		#Choix par défault du journal OD
		$args->{select_journal} = 'OD';
		
		#Requête tbljournal_liste
		$sql = 'SELECT libelle_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
		my $journal_req = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
		
		#Formulaire Sélectionner un journal
		my $select_journal = '<select class="login-text" style="width: 20%;" name=select_journal id=select_journal
		onchange="if(this.selectedIndex == 0){document.location.href=\'journal?configuration\'}">' ;
		$select_journal .= '<option class="opt1" value="">Créer un journal</option>' ;
		for ( @$journal_req ) {
		if 	(defined $args->{select_journal}) {
		$selected = ( $_->[0] eq $args->{select_journal} ) ? 'selected' : '' ;
		}			
		$select_journal .= '<option value="' . $_->[0] . '" '.$selected.'>' . $_->[0] . '</option>' ;
		}
		$select_journal .= '</select>' ;
		
		my $form_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais' ;

		$content .= '
	
	
		<h3 class="warning centrer">
		<form action="'.$form_href.'">
		<input type=hidden name="piece_ref" value="'.$args->{piece_ref}.'">
		Voulez-vous comptabiliser la note de frais ' . $args->{piece_ref} . ' ? 
		<br><br>
		<a style="margin-left: 3ch;" class=nav  href="javascript:{};" onclick="parentNode.submit();">Oui</a>
		<a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>

		<div class=wrapper-forms>
		<fieldset class="pretty-box"><legend><h3>Options</h3></legend>
		<label style="width : 40%;" class="forms" for="regroupkm">Regrouper les écritures par comptes ?</label>
		<input type="checkbox" style ="width : 20%;" id="regroupkm" name="regroupkm" value=1 checked>
		<br>
		<label style="width : 40%;" class="forms" for="select_journal">Journal de destination </label>
		' . $select_journal . '
		</fieldset>
		</div>
		<input type=hidden name="comptabiliser" value=1>
		<input type=hidden name="piece_libelle" value="'.$args->{piece_libelle}.'">
		<input type=hidden name="piece_date" value="'.$args->{piece_date}.'">
		</form>
		</h3>' ;

	
	} elsif ( defined $args->{piece_ref} && defined $args->{comptabiliser} && $args->{comptabiliser} eq '1' && !defined $args->{frais_line}) {
	
		if ($args->{select_journal} eq '') {
			$content .= Base::Site::util::generate_error_message('Impossible de comptabiliser l\'écriture - Veuillez sélectionner un journal');
		} else {
	
	#Requête tbljournal_liste code_journal
	my $journal_req = Base::Site::bdd::get_journaux($dbh, $r, $args->{select_journal});

    # supprimer d'abord les données éventuellement présentes dans tbljournal_staging pour cet utilisateur	
	Base::Site::bdd::clean_tbljournal_staging( $r );

	#CALCUL NUMERO DE PIECE
	$sql = 'select COALESCE((
	SELECT TO_CHAR(substring(id_facture from 11 for 2)::integer + 1, \'FM00\') as item_number
	FROM tbljournal	WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ?
	AND substring(id_facture from 8 for 2)::NUMERIC = (SELECT EXTRACT(MONTH FROM piece_date::date)::NUMERIC FROM tblndf WHERE piece_ref = ?)
	ORDER BY 1 DESC LIMIT 1)
	, \'01\')';
	@bind_array = ( $journal_req, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{select_journal}, $args->{piece_ref} ) ;
	my $select_calcul_piece = eval {$dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;     
	$sql = 'SELECT TO_CHAR(piece_date::date, \'MM\') as month,  TO_CHAR(piece_date::date, \'YYYY\') as year FROM tblndf WHERE id_client = ? and fiscal_year = ? and piece_ref = ?';
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref} ) ;
	my $select_month_year = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ; 
	my $numero_piece = $journal_req.$select_month_year->[0]->{year}.'-'.$select_month_year->[0]->{month}.'_'.$select_calcul_piece ;	
	
	#Génération nom de fichier
	my $name_file = $numero_piece.'_'.$args->{piece_libelle}.'.pdf';
	# Remplacer modifier espace et _
	$name_file =~ s/\s+/_/g;
	
	my $doc_categorie = 'Temp';
	#Insertion du nom du document dans la table tbldocuments
	$sql = 'INSERT INTO tbldocuments ( id_client, id_name, fiscal_year, libelle_cat_doc, date_reception, date_upload )
	VALUES ( ? , ? , ? , ?, ?, CURRENT_DATE)
	ON CONFLICT (id_client, id_name ) DO NOTHING
	RETURNING id_name' ;
	my $sth = $dbh->prepare($sql) ;
	eval { $sth->execute( $r->pnotes('session')->{id_client}, $name_file, $r->pnotes('session')->{fiscal_year}, $doc_categorie, $args->{piece_date} )} ;

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm =>	Vérification de valeur regroupkm ' .($args->{regroupkm} || '') . ' ');
	
	if (defined $args->{regroupkm} && $args->{regroupkm} eq 1) {
		$sql = q {
with t4 as (
SELECT DISTINCT ON (t1.frais_compte) t1.frais_compte , (sum(frais_montant) over (PARTITION BY frais_compte))::numeric as total_montant, (sum(frais_quantite) over (PARTITION BY frais_compte))::numeric as total_quantite, t1.id_client, t3.piece_ref, t3.piece_date, t3.piece_compte, t3.piece_libelle, t1.fiscal_year, t1.frais_date, t1.frais_libelle, (sum(t1.frais_montant) over())::numeric as total
FROM tblndf_detail t1
INNER JOIN tblndf t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.piece_ref = t3.piece_ref
WHERE t1.id_client = ? and t1.fiscal_year = ? and t1.piece_ref = ?
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, debit, credit, id_facture, documents1, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, piece_date, piece_libelle, frais_compte, ?, total_montant, '0', ?, ?, ?
FROM t4
} ;
	
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref},
		$r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset},
		$r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD},
		$r->pnotes('session')->{id_client}, $args->{select_journal}, $numero_piece, $name_file, $args->{_token_id}
		) ;

		$dbh->do( $sql, undef, @bind_array ) ;	
	
	} else {
	$sql = q {
with t4 as (	
SELECT t1.id_client, t3.piece_ref, t3.piece_date, t3.piece_compte, t3.piece_libelle, t1.fiscal_year, t1.frais_date, t1.frais_compte, t1.frais_libelle, t1.frais_montant, (sum(t1.frais_montant) over())::numeric as total
FROM tblndf_detail t1
INNER JOIN tblndf t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.piece_ref = t3.piece_ref
WHERE t1.id_client = ? and t1.fiscal_year = ? and t1.piece_ref = ?
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, debit, credit, id_facture, documents1, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, piece_date, piece_libelle, frais_compte, ?, frais_montant, '0', ?, ?, ?
FROM t4
} ;
	
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref},
		$r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset},
		$r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD},
		$r->pnotes('session')->{id_client}, $args->{select_journal}, $numero_piece, $name_file, $args->{_token_id}
		) ;

		$dbh->do( $sql, undef, @bind_array ) ;
		
	}

	$sql = q {
with t6 as (
SELECT DISTINCT ON (t1.piece_ref) t1.piece_ref, t1.id_client, t1.piece_date, t1.piece_compte, t1.piece_libelle, t1.fiscal_year, (sum(t3.frais_montant) over())::numeric as total
FROM tblndf t1
INNER JOIN tblndf_detail t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.piece_ref = t3.piece_ref
WHERE t1.id_client = ? and t1.fiscal_year = ? and t1.piece_ref = ?
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, debit, credit, id_facture, documents1, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, piece_date, piece_libelle, piece_compte, ?, '0', total, ?, ?, ?
FROM t6
} ;
	
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref},
		$r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset},
		$r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD},
		$r->pnotes('session')->{id_client}, $args->{select_journal}, $numero_piece, $name_file, $args->{_token_id}
	    ) ;

		$dbh->do( $sql, undef, @bind_array ) ;
		
		my ($return_identry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $args->{_token_id}, 0);
	
		#erreur dans la procédure store_staging : l'afficher dans le navigateur
		if ( $error_message ) {
			$content .= Base::Site::util::generate_error_message($error_message);
		} else {
			
			$sql = 'UPDATE tblndf set piece_entry = ? WHERE id_client = ? and fiscal_year = ? and piece_ref = ?';
			@bind_array = ( $return_identry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref} ) ;
			$dbh->do( $sql, undef, @bind_array ) ;
			
			my $location = export_pdf2( $r, $args );
			
			#Récupérer le pdf généré
			my $pdf_file = $r->document_root() . $location;
			my $pdf = PDF::API2->open($pdf_file);
			
			#définition répertoire
			my $base_dir = $r->document_root() . '/Compta/base/documents' ;
			my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$r->pnotes('session')->{fiscal_year}. '/' ;

			#Enregistrer le pdf
			my $export_pdf_file = $archive_dir . $name_file;
			$pdf->saveas($export_pdf_file);
			
			my $event_type = 'Création';
			my $event_description = 'Le document a été créé par '.$r->pnotes('session')->{username}.'';
			my $save_document_history = Base::Site::bdd::save_document_history($dbh, $r->pnotes('session')->{id_client}, $name_file, $event_type, $event_description, $r->pnotes('session')->{username});
          
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm =>	Comptabilisation de la note de frais ' .($args->{piece_ref} || '') . ' ');
			
			#Redirection
			$args->{restart} = 'entry?open_journal='.$args->{select_journal}.'&mois=0&id_entry=' . $return_identry.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé

		}    
	}

	}
    
    ####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur le bouton 'Imprimer'	  #
	#######################################################################
	if ( defined $args->{piece_ref} && defined $args->{imprimer} && !defined $args->{frais_line}) {
		
		my $location = export_pdf2( $r, $args ); ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		#adresse du fichier précédemment généré
		#$r->headers_out->add(Location => $location) ;
		#$r->next(Location => $location) ;
		#$r->headers_out->add(target => '_blank') ;
		#rediriger le navigateur vers le fichier
		#$r->status(Apache2::Const::REDIRECT) ;
		#return Apache2::Const::REDIRECT ;
		#return '<A HREF="' . $location . '" target ="_blanc">"test"</A>';
		#ouvrir dans une nouvelle fenêtre
		$content .= '
		<script type="text/javascript">
		 function Open(){window.open("'.$location.'", "blank");}
		Open();
		</script>';
		}
	}
    
    ####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur 'Valider' la modification #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{modifier} && $args->{modifier} eq '1' && !defined $args->{frais_line} ) {
		
		#undef si valeur est non renseignée
		$args->{choix_vehicule} ||= undef ;
		$args->{com1} ||= undef ;
		$args->{com2} ||= undef ;
		$args->{com3} ||= undef ;
		
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{piece_libelle});
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [17, $args->{piece_compte}], [8, $args->{piece_date}], [10, $args->{piece_libelle}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} else {
			#modifier piece_date piece_compte piece_libelle
			$sql = 'UPDATE tblndf set piece_date = ?, piece_compte = ?, piece_libelle = ?, id_vehicule = ?, com1 = ?, com2 = ?, com3 = ? where id_client = ? AND fiscal_year = ? AND piece_ref = ? ' ;
			@bind_array = ( $args->{piece_date}, $args->{piece_compte}, $args->{piece_libelle}, $args->{choix_vehicule},$args->{com1}, $args->{com2}, $args->{com3}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}  ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitule') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Cette note de frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@);}
			}
		}
    }
	
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t5.id_facture, t5.documents1, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	LEFT JOIN (SELECT DISTINCT ON(id_entry) id_entry, id_client, fiscal_year, id_facture, documents1 FROM tbljournal) t5 ON t1.id_client = t5.id_client AND t1.fiscal_year = t5.fiscal_year AND t1.piece_entry = t5.id_entry
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
	
	#Requête total km vehicule
	$sql = 'SELECT (sum(t2.frais_quantite) over())::integer as total_quantite
	FROM tblndf t1
	INNER JOIN (SELECT frais_quantite, id_client, fiscal_year, piece_ref FROM tblndf_detail) t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_ref = t2.piece_ref
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.id_vehicule = ? and t1.piece_entry IS NOT NULL limit 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_notes->[0]->{id_vehicule}) ;
	my $array_count_detail = eval {$dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0]} ;
	
	#Requête tbldocuments => Recherche de la liste des documents enregistrés
    $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, check_banque, multi, last_fiscal_year, id_compte FROM tbldocuments WHERE id_name = ? AND id_client = ?' ;
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, ($args->{id_name}  || $array_of_notes->[0]->{documents1} || ''), $r->pnotes('session')->{id_client} ) ;
    
	#Empêcher piece_ref vide ou existe pas
	if (!$args->{piece_ref} || !$array_of_notes->[0]->{piece_ref}){
		$content .= Base::Site::util::ref_existe_pas($r);
		return $content ;
	}
	
	#Requête => Formulaire 1 => Compte de Tiers
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 3) IN (\'421\',\'455\',\'467\',\'108\') ORDER by libelle_compte' ;
    my $compte_tiers_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_tiers = '<select '.$disabled.' class="forms2_input" style="width: 21%;" name=piece_compte id=compte_tiers
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};ModSelected(this);">' ;
	$compte_tiers .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_tiers .= '<option value="" >--Sélectionner--</option>' ;
	for ( @$compte_tiers_set ) {
	$selected = ( $_->{numero_compte} eq $array_of_notes->[0]->{piece_compte} ) ? 'selected' : '' ;
	$compte_tiers .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_tiers .= '</select>' ;
	
	#Requête => Formulaire 1 => Sélectionner le véhicule
	$sql = 'SELECT vehicule, puissance, vehicule_name, numero_compte, id_vehicule FROM tblndf_vehicule WHERE id_client = ? AND fiscal_year = ? AND numero_compte = ? ORDER by vehicule_name' ;
    my $vehicule_client_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_notes->[0]->{piece_compte} ) ) ;
	my $vehicule_client = '<select '.$disabled.' class="forms2_input" style="width: 19%;" name=choix_vehicule id=choix_vehicule
	onchange="if(this.selectedIndex == 0){document.location.href=\'notesdefrais?vehicule\'};ModSelected(this);">' ;
	$vehicule_client .= '<option class="opt1" value="">Ajouter un véhicule</option>' ;
	if (!$array_of_notes->[0]->{id_vehicule}) {
	$vehicule_client .= '<option value="" selected>--Sélectionner le véhicule--</option>' ;	
	} else {
	$vehicule_client .= '<option value="" >--Sélectionner le véhicule--</option>' ;		
	}
	for ( @$vehicule_client_set ) {
	my $check = $_->{id_vehicule};	
	$selected = ( $check eq ($array_of_notes->[0]->{id_vehicule} || '')) ? 'selected' : '' ;
	$vehicule_client .= '<option value="' . $_->{id_vehicule} . '" '.$selected.'>'. $_->{vehicule_name} .' ('. $_->{puissance} .')</option>' ;
	}
	$vehicule_client .= '</select>' ;	
	
	#Requête tblndf_detail
	$sql = 'SELECT id_client, fiscal_year, piece_ref, frais_date, frais_compte, frais_libelle, frais_bareme, frais_quantite, to_char(frais_montant/100::numeric, \'999G999G999G990D00\') as montant, to_char((sum(frais_montant) over())/100::numeric, \'999G999G999G990D00\') as total_montant, frais_doc, frais_line FROM tblndf_detail WHERE id_client = ? AND fiscal_year = ? AND piece_ref = ?' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;
	my $array_tblndf_detail = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;

    # si véhicule électrique majore de 20% le barême km
	my $elec_co = 1;
	if (defined $array_of_notes->[0]->{electrique} && $array_of_notes->[0]->{electrique} eq 't') {
		$elec_co = 1.2;
	}
	
    #Affichage info kilomètres cumulés véhicules
    my $display_info_km_total = '';
    if ($array_of_notes->[0]->{id_vehicule}) {
	$display_info_km_total = '<span class="memoinfo">'.($array_count_detail || 0).' kilomètres cumulés en '.$r->pnotes('session')->{fiscal_year}.' pour le véhicule '.$array_of_notes->[0]->{vehicule_name}.' ('. $array_of_notes->[0]->{puissance} .')</span>';
	}
	
	#Bloquer la modification de la note de frais si celle-ci est comptabilisée (via submit)
	my $delete_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;supprimer=0';
	my $print_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;imprimer';
	my $valid_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;modifier=1';
	my $nouvelle_depense_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;depense';
	my $nouvelle_depensekm_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;km';
	my $comptabilisation_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref} || '').'&amp;comptabiliser=0';
	if ($array_of_notes->[0]->{piece_entry}){
	my $ecriture_compta_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=OD&id_entry='.($array_of_notes->[0]->{piece_entry} || '').'';
	my $docs_compta_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($array_of_notes->[0]->{documents1} || '').'';	
	$disabled = 'disabled';
	$submit_enabled_2 = '
	<input type="submit" class="btn btn-orange" style="width : 25%;" formaction="' . $ecriture_compta_href . '" value="Voir l\'écriture comptable associée">
	<input type="submit" class="btn btn-gris" style="width : 25%;" formaction="' . $docs_compta_href . '" value="Voir le document">
	';
	} else {
	$submit_enabled_1 = '
	<input type="submit" id=submit1 style="width: 10%;" class="btn btn-vert" formaction="' . $valid_href . '" value=Modifier>
	<input type="submit" id=submit2 style="width: 10%;" class="btn btn-rouge" formaction="' . $delete_href . '" value="Supprimer" >
	<input type="submit" id=submit3 style="width: 10%;" class="btn btn-bleuf" formaction="' . $print_href . '" value="Imprimer" >
	<input type="submit" class="btn btn-noir" style="width : 10%;" formaction="' . $comptabilisation_href . '" value="Comptabiliser">
	';
	$submit_enabled_2 = '
	<input type="submit" class="btn btn-orange" style="width : 18%;" formaction="' . $nouvelle_depense_href . '" value="Nouvelle dépense">
	<input type="submit" class="btn btn-gris" style="width : 18%;" formaction="' . $nouvelle_depensekm_href . '" value="Nouveau frais kilométrique">
	';			
	}
    
	############## Formulaire 1 Modification de la note de frais ##############	 
    my $formulaire = '
    <div class=centrer>
        <div class=Titre10>Modification de la note de frais <a class=nav2 href="/base/notesdefrais?piece_ref='.($args->{piece_ref} || '').'">'.($args->{piece_ref} || '').'</a></div>
			'.$display_info_km_total.'
			<form class=wrapper10 method="post" >
				<div class=formflexN2>
				<label class="bold" style="width: 12%;" for="piece_ref">Référence</label>
				<label class="bold" style="width: 10%;" for="date_comptant20">Date</label>
				<label class="bold" style="width: 21%;" for="compte_tiers">Tiers</label>
				<label class="bold" style="width: 33%;" for="libelle4">Libellé</label>
				<label class="bold" style="width: 19%;" for="choix_vehicule">Véhicule</label>
				</div>
				
				<div class=formflexN2>
				<label class="bold" style="width: 33%;" for="com1"></label>
				<label class="bold" style="width: 33%;" for="com2"></label>
				<label class="bold" style="width: 33%;" for="com3"></label>
				</div>
				
				<div class=formflexN2>
				<input '.$disabled.'  class="forms2_input" style="width: 12%;" type=text id=piece_ref name=piece_ref value="'.($args->{piece_ref} || '').'" readonly/>
				<input '.$disabled.'  class="forms2_input" style="width: 10%;" type="text" name=piece_date id=date_comptant20 value="' . ($args->{piece_date} || $array_of_notes->[0]->{piece_date} || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" oninput="ModSelected(this);format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');" required>
				' . $compte_tiers . '
				<input '.$disabled.' oninput="ModSelected(this);" class="forms2_input" style="width: 33%;" type=text id=libelle4 name=piece_libelle value="'.($args->{piece_libelle} || $array_of_notes->[0]->{piece_libelle}|| '').'" required >
				' . $vehicule_client . '
				</div>
				
				<div class=formflexN2>
				<input '.$disabled.' oninput="ModSelected(this);" placeholder="Commentaire 1" class="forms2_input" style="width: 33%;" type=text id=com1 name=com1 value="'.($array_of_notes->[0]->{com1}|| '').'" >
				<input '.$disabled.' oninput="ModSelected(this);" placeholder="Commentaire 2" class="forms2_input" style="width: 33%;" type=text id=com2 name=com2 value="'.($array_of_notes->[0]->{com2}|| '').'" >
				<input '.$disabled.' oninput="ModSelected(this);" placeholder="Commentaire 3" class="forms2_input" style="width: 33%;" type=text id=com3 name=com3 value="'.($array_of_notes->[0]->{com3}|| '').'" >
				</div>
				
				<div class=formflexN3>
				'.$submit_enabled_1.'
				</div>
			
				<input type=hidden name=id_client value="' . $r->pnotes('session')->{id_client} . '">
				<input type=hidden name=fiscal_year value="'.$r->pnotes('session')->{fiscal_year}.'">
				<input type=hidden name=id_vehicule value="' . ($array_of_notes->[0]->{id_vehicule} || '') . '">
			</form>
			<hr>
			<form class=wrapper10 method="post">
			'.$submit_enabled_2.'
			</form>
    ' ;
    
    $args->{piece_date} = $array_of_notes->[0]->{piece_date};
    
    ############## Formulaire 2 Nouvelle dépense ##############	
	my $new_depense = '';
	if (defined $args->{depense} ) {
	$new_depense .= form_nouvelle_depense( $r, $args );
    }
    
    ############## Formulaire 3 Nouveau frais kilométrique ##############	
	my $new_depensekm = '';
	if (defined $args->{km} ) {
	$new_depensekm .= form_nouvelle_depense_km( $r, $args );
    }
    
    $formulaire .= '
    '.$new_depense .'
	'.$new_depensekm .'
	';
    
    #Formulaire Frais en cours
    $formulaire .= form_gestion_frais_en_cours( $r, $args );
    
	#####################################       
	#Affichage du document
	#####################################    
    my $display_doc = '' ;

    if (@$array_of_documents) {
		$display_doc .= '
		<div class=Titre10>Affichage du document <a class=nav2 href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.$array_of_documents->[0]->{id_name}.'">'. $array_of_documents->[0]->{id_name} .'</a></div>
		<br>
		<iframe  src="/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$array_of_documents->[0]->{fiscal_year} .'/'.$array_of_documents->[0]->{id_name}.'" width="1280" height="1280" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%; " allowfullscreen> </iframe>
		' ; 	
	}
	
	$content .= '' . $formulaire . $display_doc .'<br>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_gestion_frais 

#/*—————————————— Page Formulaire Frais en cours ——————————————*/
sub form_gestion_frais_en_cours {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array) ;
  	my $line = "1"; 
  	map { ($_) = '' } my ($content, $selected, $disabled, $none );
  	my $reqid = Base::Site::util::generate_reqline();

	#/************ ACTION DEBUT *************/
  
    ####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur 'Valider' la modification #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{modifier} && $args->{modifier} eq '1' && defined $args->{frais_line} ) {
		
	    $args->{frais_quantite} ||= undef;
	    $args->{frais_bareme} ||= undef;

		Base::Site::util::formatter_montant_et_libelle(\$args->{frais_montant}, \$args->{frais_libelle});
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [3, $args->{frais_montant}], [18, $args->{frais_montant}], [9, $args->{frais_compte}], [8, $args->{frais_date}], [10, $args->{frais_libelle}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} elsif ($args->{frais_date} gt $args->{piece_date}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement que la date de la note de frais soit postérieure à la date de la dépense !') ;
		} else {
			if ($args->{frais_quantite} && $args->{frais_bareme}) { 
			#ajouter une note de frais
			$sql = 'UPDATE tblndf_detail SET frais_date = ?, frais_compte = ?, frais_libelle = ?, frais_quantite = ?, frais_bareme = ?, frais_montant = ?, frais_doc = ? WHERE id_client = ? AND fiscal_year = ? and piece_ref = ? and frais_line = ?' ;
			@bind_array = ( $args->{frais_date}, $args->{frais_compte} , $args->{frais_libelle}, ($args->{frais_quantite} || undef), ($args->{frais_bareme} || undef), $args->{frais_montant}*100 , ($args->{frais_doc} || undef), $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}, $args->{frais_line} ) ;
			} else {
			$sql = 'UPDATE tblndf_detail SET frais_date = ?, frais_compte = ?, frais_libelle = ?, frais_quantite = ?, frais_bareme = ?, frais_montant = ?, frais_doc = ? WHERE id_client = ? AND fiscal_year = ? and piece_ref = ? and frais_line = ?' ;
			@bind_array = ( $args->{frais_date}, $args->{frais_compte} , $args->{frais_libelle}, ($args->{frais_quantite} || undef), ($args->{frais_bareme} || undef), $args->{frais_montant}*100 , ($args->{frais_doc} || undef), $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}, $args->{frais_line} ) ;
			}
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			}
		}
    }
	
	####################################################################### 
	#Formulaire 3 => l'utilisateur a cliqué sur 'Dupliquer' 			  #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{dupliquer} && $args->{dupliquer} eq '1' && defined $args->{frais_line} ) {
		
			#dupliquer une note de frais
			$sql = '
			INSERT INTO tblndf_detail (id_client, fiscal_year, piece_ref, frais_date, frais_compte, frais_libelle, frais_quantite, frais_montant, frais_doc, frais_bareme ) SELECT t1.id_client, t1.fiscal_year, t1.piece_ref, t1.frais_date, t1.frais_compte, t1.frais_libelle, t1.frais_quantite, t1.frais_montant, t1.frais_doc, t1.frais_bareme
			FROM tblndf_detail t1 
			WHERE t1.frais_line = ?
			' ;
			@bind_array = ( $args->{frais_line}) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			}
    }
	
	################################################################################### 
	#Formulaire 3 => l'utilisateur a cliqué sur le bouton 'Supprimer' la dépense 	  #
	###################################################################################
    if ( defined $args->{piece_ref} && defined $args->{supprimer} && $args->{supprimer} eq '0' && defined $args->{frais_line}) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'&amp;supprimer=1&amp;frais_line='.$args->{frais_line}.'';
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer la dépense : Date: '.($args->{frais_date} || '') .' Compte: '.($args->{frais_compte} || '').' Libellé: '.($args->{frais_libelle}|| '') .' Montant: '.($args->{frais_montant}|| '') .' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{piece_ref} && defined $args->{supprimer} && $args->{supprimer} eq '1' && defined $args->{frais_line}) {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tblndf_detail WHERE frais_line = ? AND id_client = ? AND fiscal_year = ?' ;
			@bind_array = ( $args->{frais_line}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
				#Redirection
				$args->{restart} = 'notesdefrais?piece_ref='.$args->{piece_ref}.'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}

	}
	
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
	
	#Empêcher modification de la note de frais si comptabilisé
	my $mask = 'submit';
	if ($array_of_notes->[0]->{piece_entry}){
	$disabled = 'disabled';
	$mask = 'hidden';
	$none = 'display: none;';
	}
	
    # si véhicule électrique majore de 20% le barême km
	my $elec_co = 1;
	if (defined $array_of_notes->[0]->{electrique} && $array_of_notes->[0]->{electrique} eq 't') {
		$elec_co = 1.2;
	}

	#Requête formulaire compte	
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 1) IN (\'6\') ORDER by numero_compte, libelle_compte' ;
    my $compte_classe6_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	
	#Requête tblndf_detail
	$sql = 'SELECT id_client, fiscal_year, piece_ref, frais_date, frais_compte, frais_libelle, frais_bareme, frais_quantite, (sum(frais_quantite) over())::integer as total_km, frais_montant/100::numeric as montant, to_char((sum(frais_montant) over())/100::numeric, \'999G999G999G990D00\') as total_montant, frais_doc, frais_line FROM tblndf_detail WHERE id_client = ? AND fiscal_year = ? AND piece_ref = ? ORDER BY frais_date, frais_compte, frais_libelle ' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;
	my $array_tblndf_detail = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;

	#Requête tbldocuments
	$sql = '
    SELECT id_name
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception' ;	
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;
	
	#ligne des en-têtes Frais en cours
    my $formulaire .= '
		<div class=Titre10>Frais en cours</div>
		<ul class="wrapper10"><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 6.3%;">Date</span>
		<span class=headerspan style="width: 22%; text-align: center;">Dépense</span>
		<span class=headerspan style="width: 30%; text-align: center;">Libellé frais</span>
		<span class=headerspan style="width: 6%; text-align: center;">Baréme</span>
		<span class=headerspan style="width: 6%; text-align: center;">KM</span>
		<span class=headerspan style="width: 6%; text-align: center;">Montant</span>
		<span class=headerspan style="width: 15%;">Documents</span>
		<span class=headerspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=headerspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=headerspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
	
	for ( @$array_tblndf_detail ) {
		
	my $reqline = ($line ++);
		
	#joli formatage de débit/crédit
    (my $montant = sprintf( "%.2f",  $_->{montant} ) ) =~ s/\B(?=(...)*$)/ /g ;	
	
    #Requête => Formulaire 3 => Sélectionner le barème
	my $puissance_client = '
	<input '.$disabled.' class=formMinDiv2 onchange="findTotal(this); findModif(this,'.$reqline.');" style="text-align: right;" type="text" name="frais_bareme" value="' .  ($_->{frais_bareme} || ''). '" id="frais_bareme_' . $reqline . '" list="bareme_list_' . $reqline . '">
	<datalist id="bareme_list_' . $reqline . '">
		<option value="' . ($array_of_notes->[0]->{distance1} * $elec_co ) . '">Jusqu\'à 5000 km - d x ' . (($array_of_notes->[0]->{distance1} * $elec_co) ). '</option>
		<option value="' . ($array_of_notes->[0]->{distance2} * $elec_co ) . '">de 5001 à 20000 km - d x ' . (($array_of_notes->[0]->{distance2} * $elec_co) ) . ' + ' . ($array_of_notes->[0]->{prime2} ) . '</option>
		<option value="' . ($array_of_notes->[0]->{distance3} * $elec_co ) . '">Au-delà de 20000 km - d x ' . (($array_of_notes->[0]->{distance3} * $elec_co) ). '</option>
	</datalist>
	';
	
	#Formulaire Sélectionner un document
	my $selected_docs1 = $_->{frais_doc};
	my $doc_class1 = 'class="blockspan"';
	my $doc_class2 = 'class="line_icon_visible"';
	# Sélection par default du "choix docs1" 
	my $select_document = '<select '.$disabled.' onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};findModif(this,'.$reqline.');" class=formMinDiv2 name=frais_doc id=frais_doc_'.$reqline.'>' ;
    $select_document .= '<option class="opt1" value="">Ajouter un document</option>' ;
	if (!defined $_->{frais_doc}){
	$doc_class1 = 'class="displayspan"';
	$doc_class2 = 'class="line_icon_hidden"';
    $select_document .= '<option value="" selected>--Sélectionner un document--</option>' ;
	} else {
    $select_document .= '<option value="">--Sélectionner un document--</option>' ;
	}
	for ( @$array_of_documents )   {
	my $selected = ( $_->{id_name} eq ($selected_docs1 || '') ) ? 'selected' : '' ;
	$select_document .= '<option value="' . $_->{id_name} . '" '.$selected.'>' . $_->{id_name} . '</option>' ;
    }
    $select_document .= '</select>' ;
	
	#select_compte6
	my $selected_compte6 = $_->{frais_compte};
	my $compte_classe6 = '<select '.$disabled.' onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};findModif(this,'.$reqline.');" class=formMinDiv2 name=frais_compte id=frais_compte_'.$reqline.'>' ;
	$compte_classe6 .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_classe6 .= '<option value="">--Sélectionner le compte de charge--</option>' ;
	for ( @$compte_classe6_set ) {
	my $selected = ( $_->{numero_compte} eq ($selected_compte6 || '') ) ? 'selected' : '' ;
	$compte_classe6 .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_classe6 .= '</select>' ;
		
	my $delete_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref}).'&amp;supprimer=0&amp;frais_line=' . $_->{frais_line} ;
	my $dupliquer_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref}).'&amp;dupliquer=1&amp;frais_line=' . $_->{frais_line} ;
	my $valid_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref}).'&amp;modifier=1&amp;frais_line=' . $_->{frais_line} ;
	my $http_link_documents1 = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.($args->{piece_ref}).'&amp;id_name='.($selected_docs1 || '') ;
	
	$formulaire .= '
		<li id="line_'.$reqline.'" class="style1" >  
		<div class=spacer></div>
		<form class="lineflex2" method="post">
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 6.3%;"><input onchange="findModif(this,'.$reqline.');format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');" '.$disabled.' class=formMinDiv2 type=text name="frais_date" value="' . $_->{frais_date} . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" ></span>
		<span class=displayspan style="width: 22%;">'.$compte_classe6.'</span>
		<span class=displayspan style="width: 30%;"><input '.$disabled.' oninput="findModif(this,'.$reqline.');" class=formMinDiv2 type=text name="frais_libelle" onkeyup="verif(this);" value="' . $_->{frais_libelle} . '" onclick="liste_search_libfrais(this.value, \''.$reqline.'\')" list="libfrais_'.$reqline.'"><datalist id="libfrais_'.$reqline.'"></datalist></span>
		<span class=displayspan style="width: 6%;">'.$puissance_client.'></span>
		<span class=displayspan style="width: 6%;"><input '.$disabled.' class=formMinDiv2 onchange="findTotal(this); findModif(this,'.$reqline.');" style="text-align: right;" type=text name="frais_quantite" id="frais_quantite_' . $reqline . '" value="' .  ($_->{frais_quantite} || '') . '"  ></span>
		<span class=displayspan style="width: 6%;"><input '.$disabled.' class=formMinDiv2 style="text-align: right;" type=text name="frais_montant" id="frais_montant_' . $reqline . '" value="' . $montant . '" onchange="findModif(this,'.$reqline.');format_number(this);"></span>
		<span class=displayspan style="width: 15%;">'.$select_document.'</span>
		<span class="displayspan" style="width: 2%; text-align: center;'.$none.'"><input '.$disabled.' id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider la ligne" src="/Compta/style/icons/valider.png" style="'.$none.'" type="'.$mask.'" height="16" width="16" alt="valider"></span>
		<span class="blockspan" style="width: 2%; text-align: center;'.$none.'"><input '.$disabled.' type="image" formaction="' . $delete_href . '" title="Supprimer la ligne" src="/Compta/style/icons/delete.png" style="margin: 2px; border: 0;'.$none.'" type="'.$mask.'" height="16" width="16" alt="supprimer"></span>
		<span class="blockspan" style="width: 2%; text-align: center;'.$none.'"><input '.$disabled.' type="image" formaction="' . $dupliquer_href . '" title="Dupliquer la ligne" src="/Compta/style/icons/duplicate.png" style="margin: 2px; border: 0;'.$none.'" type="'.$mask.'" height="16" width="16" alt="dupliquer"></span>
		<span '.$doc_class1.' style="width: 2%; text-align: center;"><input '.$doc_class2.' type="image" formaction="' . $http_link_documents1.'" title="Afficher le document" src="/Compta/style/icons/documents.png" type="submit" height="16" width="16" alt="document"></span>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<input '.$disabled.' type=hidden name=id_vehicule value="'.($array_of_notes->[0]->{id_vehicule} || '').'">
		</form>
		<div class=spacer></div></li>' ;
		
	}
	
	#Formulaire Total
	$formulaire .=  '<li class=style1><br></li><li class=style1><hr></li>
    <li class=lineflex1><div class=spacer></div>
    	<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 6.3%;">&nbsp;</span>
		<span class=displayspan style="width: 22%; text-align: center;">&nbsp;</span>
		<span class=displayspan style="width: 30%; text-align: center;">&nbsp;</span>
		<span class=displayspan style="width: 6%; text-align: right; padding-right: 8px; font-weight: bold;">Total</span>
		<span class=displayspan style="width: 6%; text-align: right; padding-right: 4px; font-weight: bold;">' . ( $array_tblndf_detail->[0]->{total_km} || 0 ) . '</span>
		<span class=displayspan style="width: 6%; text-align: right; padding-right: 4px; font-weight: bold;">' . ( $array_tblndf_detail->[0]->{total_montant} || 0 ) . '</span>
		<span class=displayspan style="width: 15%; ">&nbsp;</span>
		<span class=displayspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=displayspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=displayspan style="width: 2%;'.$none.'">&nbsp;</span>
		<span class=displayspan style="width: 2%;">&nbsp;</span>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>' ;

	$formulaire .= '</ul>';

	$content .= $formulaire ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_gestion_frais_en_cours 

#/*—————————————— Page Formulaire nouvelle depense KM ——————————————*/
sub form_nouvelle_depense_km {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
  	my $selected = '';
  	my $reqid = Base::Site::util::generate_reqline();
	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#Formulaire 3 => l'utilisateur a cliqué sur 'Ajouter' la dépense KM   #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{km} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		
	    Base::Site::util::formatter_montant_et_libelle(\$args->{frais_montant}, \$args->{frais_libelle});
	    
	    my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [9, $args->{frais_compte}], [8, $args->{frais_date}], [10, $args->{frais_libelle}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} elsif ($args->{frais_date} gt $args->{piece_date}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement que la date de la note de frais soit postérieure à la date de la dépense !') ;
		} elsif (!$args->{frais_montant} || $args->{frais_montant} eq '0.00' ) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un montant différent de zéro !') ;
		} else {
		
			#ajouter une note de frais
			$sql = 'INSERT INTO tblndf_detail (id_client, fiscal_year, piece_ref, frais_date, frais_compte, frais_libelle, frais_bareme, frais_quantite, frais_montant, frais_doc) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}, $args->{frais_date}, $args->{frais_compte} , $args->{frais_libelle}, ($args->{frais_bareme} || undef), ($args->{frais_quantite} || undef), $args->{frais_montant}*100 , ($args->{frais_doc} || undef) ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
			#Redirection
			$args->{restart} = 'notesdefrais?piece_ref='.$args->{piece_ref}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
	
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;

	my $check_6521 ;
	#Requête => Formulaire 2 et Formulaire 3 => Sélectionner compte classe 6
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 1) IN (\'6\') ORDER by numero_compte, libelle_compte' ;
    my $compte_classe6_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_classe6 = '<select class="forms2_input" style="width: 15%;" name=frais_compte id=frais_compte
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}">' ;
	$compte_classe6 .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_classe6 .= '<option value="" >--Sélectionner le compte de charge--</option>' ;
	for ( @$compte_classe6_set ) {
	$selected = '';	
	if 	(defined $args->{frais_compte}) {
	my $check = $_->{numero_compte};	
	$selected = ( $check eq $args->{frais_compte} ) ? 'selected' : '' ;
	} elsif (defined $args->{km} && substr($_->{numero_compte}, 0, 4) =~ /6251/) {
	$selected = 'selected'  ;
	$check_6521 = 'OK';
	} 				
	$compte_classe6 .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	if (!defined $args->{frais_compte} && !defined $check_6521) {
	$compte_classe6 .= '<option value="" selected>--Sélectionner le compte de charge--</option>' ;
	}
	$compte_classe6 .= '</select>' ;	
	
	#Requête => Formulaire 2 et 3 => Sélectionner un document
	$sql = '
    SELECT id_name
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception' ;	
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;
    my $document_select1 = '<select class="forms2_input" style="width: 15%;" name=frais_doc id=frais_doc
    onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'}">' ;	
    $document_select1 .= '<option class="opt1" value="">Ajouter un document</option>' ;
    $document_select1 .= '<option value="" selected>-- Sélectionner --</option>' ;
    for ( @$array_of_documents )   {
	$selected = '';	
	if 	(defined $args->{frais_doc}) {
	my $check = $_->{id_name};	
	$selected = ( $check eq $args->{frais_doc} ) ? 'selected' : '' ;
	} 
	$document_select1 .= '<option value="' . $_->{id_name} . '" '.$selected.'>' . $_->{id_name} . '</option>' ;
    }
    $document_select1 .= '</select>' ;
    
    
    ############## Formulaire 3 Nouvelle dépense KM ##############	
	# si véhicule électrique majore de 20% le barême km
	my $elec_co = 1;
	if ($array_of_notes->[0]->{electrique} eq 't') {
		$elec_co = 1.2;
	}
	
	#Formulaire 3 => fonction javascript qui calcul frais_quantite * bareme
	my $new_depensekm = '';

    #Requête => Formulaire 3 => Sélectionner le barème
	my $puissance_client = '
	<input class="forms2_input" value="'.($args->{frais_bareme}|| '').'" onchange="findTotal(this)" style="width: 7%;" type="text" name="frais_bareme" id="frais_bareme_99999" list="bareme_list">
	<datalist id="bareme_list">
		<option value="' . ($array_of_notes->[0]->{distance1} * $elec_co ) . '">Jusqu\'à 5000 km - d x ' . (($array_of_notes->[0]->{distance1} * $elec_co) ). '</option>
		<option value="' . ($array_of_notes->[0]->{distance2} * $elec_co ) . '">de 5001 à 20000 km - d x ' . (($array_of_notes->[0]->{distance2} * $elec_co) ) . ' + ' . ($array_of_notes->[0]->{prime2}) . '</option>
		<option value="' . ($array_of_notes->[0]->{distance3} * $elec_co ) . '">Au-delà de 20000 km - d x ' . (($array_of_notes->[0]->{distance3} * $elec_co)). '</option>
	</datalist>
	';

	############## Formulaire 3 Nouveau frais kilométrique ##############	
		if (!$array_of_notes->[0]->{id_vehicule}) {
		$new_depensekm .= Base::Site::util::generate_error_message('Il faut sélectionner un véhicule pour ajouter des frais kilométriques !') ;	
		} else {	
			$new_depensekm .= '
			<div class=Titre10>Nouveau frais kilométrique</div>
				<div class="formflexN1">
					<form method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'>
						<div class=formflexN2>
						<label class="forms2_label" style="width: 7%;" for="frais_date">Date</label>
						<label class="forms2_label" style="width: 15%;" for="frais_compte">Dépense</label>
						<label class="forms2_label" style="width: 35%;" for="frais_libelle">Libellé frais</label>
						<label class="forms2_label" style="width: 7%;" for="frais_bareme_99999">Baréme</label>
						<label class="forms2_label" style="width: 7%;" for="frais_quantite_99999">KM</label>
						<label class="forms2_label" style="width: 7%;" for="frais_montant_99999">Montant</label>
						<label class="forms2_label" style="width: 15%;" for="frais_doc" >Documents</label>
						</div>
					
						<div class=formflexN2>
						<input class="forms2_input" style="width: 7%;" type="text" name=frais_date id=frais_date value="' . ($args->{frais_date} || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" required>
						' . $compte_classe6 . '
						<input class="forms2_input" style="width: 35%;" type=text id=frais_libelle name=frais_libelle value="'.($args->{frais_libelle}|| '').'" required onclick="liste_search_libfrais(this.value, \''.$reqid.'\')" list="libfrais_'.$reqid.'"><datalist id="libfrais_'.$reqid.'"></datalist>
						' . $puissance_client . '
						<input class="forms2_input" onchange="findTotal(this);" style="width: 7%;" type=text id="frais_quantite_99999" name=frais_quantite value="'.($args->{frais_quantite} || '').'" />
						<input class="forms2_input" style="width: 7%;" type=text id="frais_montant_99999" name=frais_montant value="'.($args->{frais_montant} || '').'" onchange="format_number(this)" required/>
						' . $document_select1 . '
						</div>
						<input type=submit id=submit style="width: 10%;" class="btn btn-vert" value=Ajouter>
						<input type=hidden name="km" value=>
						<input type=hidden name="ajouter" value=1>
					</form>
			</div>
			';
		}

	$content .= $new_depensekm ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_nouvelle_depense_km 

#/*—————————————— Page Formulaire nouvelle depense  ——————————————*/
sub form_nouvelle_depense {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
  	my $selected = '';
    
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#Formulaire 2 => l'utilisateur a cliqué sur 'Ajouter' la dépense      #
	#######################################################################
    if ( defined $args->{piece_ref} && defined $args->{depense} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		
	    Base::Site::util::formatter_montant_et_libelle(\$args->{frais_montant}, \$args->{frais_libelle});
	    
	    my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [9, $args->{frais_compte}], [8, $args->{frais_date}], [10, $args->{frais_libelle}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} elsif ($args->{frais_date} gt $args->{piece_date}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement que la date de la note de frais soit postérieure à la date de la dépense !') ;
		} elsif (!$args->{frais_montant} || $args->{frais_montant} eq '0.00' ) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un montant différent de zéro !') ;
		} else {
		
			#ajouter une note de frais
			$sql = 'INSERT INTO tblndf_detail (id_client, fiscal_year, piece_ref, frais_date, frais_compte, frais_libelle, frais_montant, frais_doc) values (?, ?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}, $args->{frais_date}, $args->{frais_compte} , $args->{frais_libelle}, $args->{frais_montant}*100 , ($args->{frais_doc} || undef) ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
			#Redirection
			$args->{restart} = 'notesdefrais?piece_ref='.$args->{piece_ref}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
	
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    
	#Requête => Formulaire 2 et Formulaire 3 => Sélectionner compte classe 6
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 1) IN (\'6\') ORDER by numero_compte, libelle_compte' ;
    my $compte_classe6_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_classe6 = '<select class="forms2_input" style="width: 20%;" name=frais_compte id=frais_compte
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}">' ;
	$compte_classe6 .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_classe6 .= '<option value="" selected>--Sélectionner le compte de charge--</option>' ;
	for ( @$compte_classe6_set ) {
	$selected = '';	
	if 	(defined $args->{frais_compte}) {
	my $check = $_->{numero_compte};	
	$selected = ( $check eq $args->{frais_compte} ) ? 'selected' : '' ;
	}			
	$compte_classe6 .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_classe6 .= '</select>' ;	
	
	#Requête => Formulaire 2 et 3 => Sélectionner un document
	$sql = '
    SELECT id_name
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception' ;	
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;
    my $document_select1 = '<select class="forms2_input" style="width: 20%;" name=frais_doc id=frais_doc
    onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'}">' ;
    $document_select1 .= '<option class="opt1" value="">Ajouter un document</option>' ;
    $document_select1 .= '<option value="" selected>-- Sélectionner --</option>' ;
    for ( @$array_of_documents )   {
	$selected = '';	
	if 	(defined $args->{frais_doc}) {
	my $check = $_->{id_name};	
	$selected = ( $check eq $args->{frais_doc} ) ? 'selected' : '' ;
	} 
	$document_select1 .= '<option value="' . $_->{id_name} . '" '.$selected.'>' . $_->{id_name} . '</option>' ;
    }
    $document_select1 .= '</select>' ;
	
	############## Formulaire 2 Nouvelle dépense ##############	
	my $new_depense = '
		<div class=Titre10>Nouvelle dépense</div>
		<div class="formflexN1">
			<form method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref='.$args->{piece_ref}.'>
				<div class=formflexN2>
				<label class="forms2_label" style="width: 7%;" for="frais_date">Date</label>
				<label class="forms2_label" style="width: 20%;" for="frais_compte">Dépense</label>
				<label class="forms2_label" style="width: 30%;" for="frais_libelle">Libellé frais</label>
				<label class="forms2_label" style="width: 7%;" for="frais_montant">Montant</label>
				<label class="forms2_label" style="width: 20%;" for="frais_doc" >Documents</label>
				</div>
			
				<div class=formflexN2>
				<input class="forms2_input" style="width: 7%;" type="text" name=frais_date id=frais_date value="' . ($args->{frais_date} || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" required>
				' . $compte_classe6 . '
				<input class="forms2_input" style="width: 30%;" type=text id=frais_libelle name=frais_libelle value="'.($args->{frais_libelle}|| '').'" required >
				<input class="forms2_input" style="width: 7%;" type=text id=frais_montant name=frais_montant value="'.($args->{frais_montant} || '').'" onchange="format_number(this);" required/>
				' . $document_select1 . '
				</div>
				<input type=submit id=submit style="width: 10%;" class="btn btn-vert" value=Ajouter>
				<input type=hidden name="depense" value=>
				<input type=hidden name="ajouter" value=1>
				</form>
		</div>
		';

	$content .= $new_depense ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_nouvelle_depense

#/*—————————————— Page Barème kilométrique ——————————————*/
sub form_baremekm {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $categorie_list ;
    
	################ Affichage MENU ################
	$content .= display_menu_ndf( $r, $args ) ;
	################ Affichage MENU ################
	
	#/************ ACTION DEBUT *************/
	
	#1ère demande d'update bareme km, afficher lien d'annulation/confirmation
	if ( defined $args->{update} && $args->{update} eq '0' ) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?baremekm' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;baremekm&amp;update=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous mettre à jour les barèmes kilométriques ' . $r->pnotes('session')->{fiscal_year} . ' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{update} && $args->{update} eq '1' ) {
		
		form_majbaremekm( $r, $args );
		
	}
	
	
	if ( defined $args->{majbarem} && $args->{majbarem} eq '1' ) {
	
		$sql = 'UPDATE tblndf_bareme set distance1 = ?, distance2 = ?, prime2 = ?, distance3 = ? WHERE id_client = ? AND fiscal_year = ? AND vehicule = ? AND puissance = ?
				';	

		@bind_array = ( $args->{new_distance1}, $args->{new_distance2}, $args->{new_prime2}, $args->{new_distance3}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{vehicule}, $args->{puissance} ) ;

		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Update Barème kilométrique '.$args->{vehicule}.' avec '.$args->{puissance}.'');
		
		#Redirection
		$args->{restart} = 'notesdefrais?baremekm';
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé
	}
	
	#/************ ACTION FIN *************/
	
	############## MISE EN FORME DEBUT ##############

    $sql = 'SELECT vehicule, puissance, distance1, distance2, prime2, distance3 FROM tblndf_bareme WHERE id_client = ? AND fiscal_year = ? ORDER by puissance' ;
    my $resultat;
    eval {$resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) };
    
    #MAJ valeurs Barème kilométrique
    if (!(@$resultat)) {
		#Redirection
		$args->{restart} = 'notesdefrais?baremekm&update=1';
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé	
	}
    
    my $new_href = 'notesdefrais&#63;baremekm&amp;update=0' ;
    my $new_link = '<input type="submit" class="btn btn-vert" style ="width : 50%;" formaction=' . $new_href . ' value="Mise à jour Barème kilométrique '.$r->pnotes('session')->{fiscal_year}.'" >' ;
    	
    
    my $formulaire = '
    <fieldset class="pretty-box"><legend><h3 class="Titre09">Barème kilométrique '.$r->pnotes('session')->{fiscal_year}.'</h3></legend>
    <div class=centrer>
    <form class=wrapper1 method="post">
    '.$new_link.'
    </form>

    ';
    
    #ligne des en-têtes Automobile
    my $formulaire_auto = '
		<div class=Titre10>Barème kilométrique applicable aux voitures (en €)</div>
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 20%;">Puissance fiscale</span>
		<span class=headerspan style="width: 20%; text-align: center;">Jusqu\'à 5000 km</span>
		<span class=headerspan style="width: 16%; text-align: center;">de 5001 à 20000 km</span>
		<span class=headerspan style="width: 20%; text-align: center;">Au-delà de 20000 km</span>
		<span class=headerspan style="width: 20%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
	
	#ligne des en-têtes deux-roues < 50 cc
    my $formulaire_2roues_50cc = '
		<span class="memoinfo">Pour les véhicules électriques, le montant des frais de déplacement calculés est majoré de 20 %.</span>
		<br>
		<div class=Titre10>Barème kilométrique applicable aux deux-roues (en €)</div>
		<br>
	
		<div style="font-weight: bold;">Vélomoteurs, cyclomoteurs (jusqu\'à 50 cm3)</div>
		 <ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 1.99%;">&nbsp;</span>
		<span class=headerspan style="width: 20%;">Puissance fiscale</span>
		<span class=headerspan style="width: 20%; text-align: center;">Jusqu\'à 3000 km</span>
		<span class=headerspan style="width: 16%; text-align: center;">de 3001 à 6000 km</span>
		<span class=headerspan style="width: 20%; text-align: center;">Au-delà de 6000 km</span>
		<span class=headerspan style="width: 20%;">&nbsp;</span>
		<span class=headerspan style="width: 1.99%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
	
	#ligne des en-têtes deux-roues > 1CV
    my $formulaire_2roues_1cv = '
		<br><hr><br>
    	<div style="font-weight: bold; ">Scooters, motocyclettes (au-delà de 50 cm3)</div>
		 <ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 1.99%;">&nbsp;</span>
		<span class=headerspan style="width: 20%;">Puissance fiscale</span>
		<span class=headerspan style="width: 20%; text-align: center;">Jusqu\'à 3000 km</span>
		<span class=headerspan style="width: 16%; text-align: center;">de 3001 à 6000 km</span>
		<span class=headerspan style="width: 20%; text-align: center;">Au-delà de 6000 km</span>
		<span class=headerspan style="width: 20%;">&nbsp;</span>
		<span class=headerspan style="width: 1.99%;">&nbsp;</span>
		<div class=spacer></div></li>
    ' ;
	
    for ( @$resultat ) {
		
		if ($_->{vehicule} eq 'Automobile') {

			$formulaire_auto .= '
			<li class="style1">  
			<div class=flex-table><div class=spacer></div>
			<form action="/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;baremekm" method=POST>
			<span class=displayspan style="width: 2%;">&nbsp;</span>
			<span class=displayspan style="width: 20%;">' . $_->{puissance} . '</span>
			<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance1" value="' . $_->{distance1} . '" style="width: 25%;"></span>
			<span class=displayspan style="width: 8%;">(d x <input type=text name="new_distance2" value="' . $_->{distance2} . '" style="width: 50%;"></span>
			<span class=displayspan style="width: 8%;">) + <input type=text name="new_prime2" value="' . $_->{prime2} . '" style="width: 50%;"></span>
			<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance3" value="' . $_->{distance3} . '" style="width: 25%;"></span>
			<span class=displayspan style="width: 20%;"><input type=submit value=Modifier style="width: 50%;"></span>
			<span class=displayspan style="width: 2%;">&nbsp;</span>
			<input type=hidden name="old_distance1" value="' . $_->{distance1} . '">
			<input type=hidden name="old_distance2" value="' . $_->{distance2} . '">
			<input type=hidden name="old_distance3" value="' . $_->{distance3} . '">
			<input type=hidden name="old_prime2" value="' . $_->{prime2} . '">
			<input type=hidden name="majbarem" value=1>
			<input type=hidden name="vehicule" value="' . $_->{vehicule} . '">
			<input type=hidden name="puissance" value="' . $_->{puissance} . '">
			</form>
			<div class=spacer></div></div></li>
			' ;
			
		} else {
		
			if ($_->{puissance} eq '50CC et moins') {
		
				$formulaire_2roues_50cc .= '
				<li class="style1">  
				<div class=flex-table><div class=spacer></div>
				<form action="/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;baremekm" method=POST>
				<span class=displayspan style="width: 2%;">&nbsp;</span>
				<span class=displayspan style="width: 20%;">' . $_->{puissance} . '</span>
				<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance1" value="' . $_->{distance1} . '" style="width: 25%;"></span>
				<span class=displayspan style="width: 8%;">(d x <input type=text name="new_distance2" value="' . $_->{distance2} . '" style="width: 50%;"></span>
				<span class=displayspan style="width: 8%;">) + <input type=text name="new_prime2" value="' . $_->{prime2} . '" style="width: 50%;"></span>
				<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance3" value="' . $_->{distance3} . '" style="width: 25%;"></span>
				<span class=displayspan style="width: 20%;"><input type=submit value=Modifier style="width: 50%;"></span>
				<span class=displayspan style="width: 2%;">&nbsp;</span>
				<input type=hidden name="old_distance1" value="' . $_->{distance1} . '">
				<input type=hidden name="old_distance2" value="' . $_->{distance2} . '">
				<input type=hidden name="old_distance3" value="' . $_->{distance3} . '">
				<input type=hidden name="old_prime2" value="' . $_->{prime2} . '">
				<input type=hidden name="majbarem" value=1>
				<input type=hidden name="vehicule" value="' . $_->{vehicule} . '">
				<input type=hidden name="puissance" value="' . $_->{puissance} . '">
				</form>
				<div class=spacer></div></div></li>
				' ;	
			
			
			} else {
		
				$formulaire_2roues_1cv .= '
				<li class="style1">  
				<div class=flex-table><div class=spacer></div>
				<form action="/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;baremekm" method=POST>
				<span class=displayspan style="width: 2%;">&nbsp;</span>
				<span class=displayspan style="width: 20%;">' . $_->{puissance} . '</span>
				<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance1" value="' . $_->{distance1} . '" style="width: 25%;"></span>
				<span class=displayspan style="width: 8%;">(d x <input type=text name="new_distance2" value="' . $_->{distance2} . '" style="width: 50%;"></span>
				<span class=displayspan style="width: 8%;">) + <input type=text name="new_prime2" value="' . $_->{prime2} . '" style="width: 50%;"></span>
				<span class=displayspan style="width: 20%;">d x <input type=text name="new_distance3" value="' . $_->{distance3} . '" style="width: 25%;"></span>
				<span class=displayspan style="width: 20%;"><input type=submit value=Modifier style="width: 50%;"></span>
				<span class=displayspan style="width: 2%;">&nbsp;</span>
				<input type=hidden name="old_distance1" value="' . $_->{distance1} . '">
				<input type=hidden name="old_distance2" value="' . $_->{distance2} . '">
				<input type=hidden name="old_distance3" value="' . $_->{distance3} . '">
				<input type=hidden name="old_prime2" value="' . $_->{prime2} . '">
				<input type=hidden name="majbarem" value=1>
				<input type=hidden name="vehicule" value="' . $_->{vehicule} . '">
				<input type=hidden name="puissance" value="' . $_->{puissance} . '">
				</form>
				<div class=spacer></div></div></li>
				' ;
	
			}
		}
	}
	
	$formulaire_auto .= '</ul>' ;
	$formulaire_2roues_50cc .= '</ul>' ;
	$formulaire_2roues_1cv .= '</ul>' ;

	$content .= '<div class="formulaire2">' . $formulaire . $formulaire_auto . $formulaire_2roues_50cc . $formulaire_2roues_1cv .'</div><br></div></fieldset>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_baremekm 

#/*—————————————— Page Gestion Véhicule ——————————————*/
sub form_vehicule {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $reqid = Base::Site::util::generate_reqline();
  	my $line = "1"; 
  	my $selected = '';
  	my $http_link_documents1 ;
    
	################ Affichage MENU ################
	$content .= display_menu_ndf( $r, $args ) ;
	################ Affichage MENU ################
	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#UPDATE																  #
	#######################################################################
	
	#1ère demande d'update bareme km, afficher lien d'annulation/confirmation
	if ( defined $args->{vehicule} && defined $args->{update} && $args->{update} eq '0' ) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;vehicule&amp;update=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous reconduire les véhicules de l\'exercice précédent ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{vehicule} && defined $args->{update} && $args->{update} eq '1' ) {
		
		#demande de reconduction confirmée
		$sql = '
		INSERT INTO tblndf_vehicule (id_client, fiscal_year, vehicule, puissance, vehicule_name, numero_compte, documents, electrique)
		SELECT ?, ?, vehicule, puissance, vehicule_name, numero_compte, documents, electrique FROM tblndf_vehicule WHERE id_client = ? AND fiscal_year = ?
		ON CONFLICT (id_client, fiscal_year, vehicule, puissance, vehicule_name ) DO NOTHING' ;

		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;

		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom de véhicule') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce véhicule existe déjà') ;
			} else {$content .= Base::Site::util::generate_error_message($@) ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Reconduction des véhicules de l\'exercice précédent '.($r->pnotes('session')->{fiscal_year} - 1).'');
			#Redirection
			$args->{restart} = 'notesdefrais?vehicule';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
			
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    if ( defined $args->{vehicule} && defined $args->{delete} && $args->{delete} eq '0') {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule&amp;delete=1&amp;id_vehicule=' . $args->{id_vehicule}.'&amp;vehicule_name=' . $args->{vehicule_name} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le véhicule ' . $args->{vehicule_name} . '?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{vehicule} && defined $args->{delete} && $args->{delete} eq '1') {
		#demande de suppression confirmée
		$sql = 'DELETE FROM tblndf_vehicule WHERE id_vehicule = ? AND id_client = ? AND fiscal_year = ?' ;
		@bind_array = ( $args->{id_vehicule}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom de véhicule') ;
			} elsif ( $@ =~ /toujours|referenced/ ) {
			$content .= Base::Site::util::generate_error_message('Suppression impossible : le véhicule est utilisé dans une note de frais') ;
			} else {$content .= Base::Site::util::generate_error_message($@) ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Suppression du véhicule '.$args->{vehicule_name}.'');
			#Redirection
			$args->{restart} = 'notesdefrais?vehicule';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{vehicule} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
			
			# split $args->{select_vehicule}
			my @Split_1 = split('!!', $args->{select_vehicule1});
			#récupére [0] select_vehicule1 et [1] select_puissance1
			$args->{vehicule} = $Split_1[0] ;
			$args->{puissance} = $Split_1[1] ;
			
			# split $args->{select_compte}
			my @Split_2 = split('!!', $args->{select_compte1});
			#récupére [0] select_vehicule1 et [1] select_puissance1
			$args->{numero_compte} = $Split_2[0] ;
			$args->{libelle_compte} = $Split_2[1] ;
		
		#on interdit libelle vide
		if (!$args->{vehicule_name1}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom de véhicule') ;
		} elsif (!$args->{vehicule} && !$args->{puissance}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement sélectionner le type de véhicule') ;
		} elsif (!$args->{numero_compte} && !$args->{libelle_compte}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement sélectionner le propriétaire du véhicule') ;
		} else {

			#ajouter un véhicule
			$sql = 'INSERT INTO tblndf_vehicule (id_client, fiscal_year, vehicule, puissance, vehicule_name, numero_compte, documents, electrique) values (?, ?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{vehicule}, $args->{puissance}, $args->{vehicule_name1}, $args->{numero_compte}, ($args->{documents} || undef), ($args->{electrique} || 'false') ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom de véhicule') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce véhicule existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout du véhicule: '.$args->{vehicule_name1}.' ('.$args->{vehicule}.' - ' . $args->{puissance}.') pour le compte '.$args->{numero_compte}.' - '.$args->{libelle_compte}.' doc : '.( $args->{documents} || '').'');
				#Redirection
				$args->{restart} = 'notesdefrais?vehicule';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
    
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				 #
	#######################################################################
    if ( defined $args->{vehicule} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
		
		# split $args->{select_vehicule}
		my @Split_1 = split('!!', $args->{select_vehicule});
		#récupére [0] select_vehicule1 et [1] select_puissance1
		$args->{vehicule} = $Split_1[0] ;
		$args->{puissance} = $Split_1[1] ;
		
		# split $args->{select_compte}
		my @Split_2 = split('!!', $args->{select_compte});
		#récupére [0] select_vehicule1 et [1] select_puissance1
		$args->{numero_compte} = $Split_2[0] ;
		$args->{libelle_compte} = $Split_2[1] ;
	    
   	    #modifier une catégorie vehicule, puissance, vehicule_name, numero_compte
	    $sql = 'UPDATE tblndf_vehicule set vehicule = ?, puissance = ?, vehicule_name = ?, numero_compte = ?, documents = ?, electrique = ? where id_vehicule = ? AND id_client = ? AND fiscal_year = ?' ;
	    @bind_array = ( $args->{vehicule}, $args->{puissance}, $args->{vehicule_name}, $args->{numero_compte}, ($args->{documents} || undef), ($args->{electrique} || 'false'), $args->{id_vehicule}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un nom de véhicule') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce véhicule existe déjà') ;
			} else {$content .= Base::Site::util::generate_error_message($@) ;}
		} else {
			#Redirection
			$args->{restart} = 'notesdefrais?vehicule';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
    }
    
    
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête tblndf_vehicule => Sélection des véhicules existants
    $sql = 'SELECT vehicule, puissance, vehicule_name, numero_compte, documents, electrique, id_vehicule FROM tblndf_vehicule WHERE id_client = ? AND fiscal_year = ? ORDER by vehicule_name' ;
    my $resultat;
    eval {$resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) };
    
   	#Requête tblndf_bareme => vehicule et puissance dans Barème kilométriquevehicule
    $sql = 'SELECT vehicule, puissance, distance1, distance2, prime2, distance3 FROM tblndf_bareme WHERE id_client = ? AND fiscal_year = ? ORDER by vehicule, puissance' ;
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $vehicule_req = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
	
	#MAJ valeurs Barème kilométrique
    if (!(@$vehicule_req)) {
		form_majbaremekm( $r, $args );
		#Redirection
		$args->{restart} = 'notesdefrais?vehicule';
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé        
	}
	
    #Formulaire Sélectionner un véhicule
	my $select_vehicule = '<select class="login-text" style="width: 24%;" name=select_vehicule1 id=select_vehicule>' ;
	$select_vehicule .= '<option value="" selected>-- Sélectionner --</option>' ;
	for ( @$vehicule_req ) {
	if 	(defined $args->{select_vehicule1}) {
	my $check = ''.$_->[0].'!!'.$_->[1].'';	
	$selected = ( $check eq $args->{select_vehicule1} ) ? 'selected' : '' ;
	}			
	$select_vehicule .= '<option value="' . $_->[0] . '!!' . $_->[1] . '" '.$selected.'>' . $_->[0] . ' - ' . $_->[1] . '</option>' ;
	}
	$select_vehicule .= '</select>' ;
	
	#Formulaire Sélectionner le propriétaire du véhicule
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 3) IN (\'421\',\'455\',\'467\',\'108\') ORDER by libelle_compte' ;
    my $compte_client_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_client = '<select class="forms2_input" style="width: 24%;" name=select_compte1 id=select_compte
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}">' ;
	$compte_client .= '<option class="opt1" value="">Créer un compte</option>' ;
	$compte_client .= '<option value="" selected>-- Sélectionner --</option>' ;
	for ( @$compte_client_set ) {
	if 	(defined $args->{select_compte1}) {
	my $check = ''.$_->{numero_compte}.'!!'.$_->{libelle_compte}.'';	
	$selected = ( $check eq $args->{select_compte1} ) ? 'selected' : '' ;
	}				
	$compte_client .= '<option value="' . $_->{numero_compte} . '!!' . $_->{libelle_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_client .= '</select>' ;	
	
    my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    my $onchangedoc1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my $docu_select = (defined($args->{documents}) && $args->{documents} ne '') ? ($args->{docs2} || $args->{id_name}) : undef;
	my ($form_doc1, $form_iddoc1) = ('documents', 'documents');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $docu_select, $form_doc1, $form_iddoc1, $onchangedoc1, 'class="forms2_input"', 'style ="width : 24%;"');

	my $new_href = 'notesdefrais&#63;vehicule&amp;update=0' ;
    my $new_link = '<input type="submit" class="btn btn-vert" style ="width : 37%;" formaction=' . $new_href . ' value="Reconduire les véhicules de l\'exercice précédent '.($r->pnotes('session')->{fiscal_year} - 1).'" >' ;
    	
	############## Formulaire Gestion des véhicules ##############	
    my $formulaire = '
    <fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des véhicules</h3></legend>
    <div class=centrer>
		<form class=wrapper1 method="post">
		'.$new_link.'
		</form>

        <div class=Titre10>Ajouter un véhicule</div>

		<form class=wrapper10 method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule>
		
		<div class=formflexN2>
		<label class="forms2_label" style="width: 24%;" for="vehicule_name">Nom du véhicule</label>
		<label class="forms2_label" style="width: 24%;" for="select_vehicule">Type de véhicule</label>
		<label class="forms2_label" style="width: 24%;" for="select_compte">Propriétaire du véhicule</label>
		<label class="forms2_label" style="width: 24%;" for="documents">Document</label>
		<label class="forms2_label" style="width: 2%;" for="electrique">#</label>
		</div>

        <div class=formflexN2>
        <input class="login-text" style="width: 24%;" type=text id=vehicule_name name="vehicule_name1" value="'.($args->{vehicule_name1} || '').'" required>
        ' . $select_vehicule . '
		' . $compte_client . '
		' . $document_select1 . '
 		<input class="login-text" style="width: 2%; height: 4ch;" title="Véhicule électrique ?" type="checkbox" id="electrique" name="electrique" value="true">
		</div>
		
		<div class=formflexN3>
		<input type=submit style="width: 10%;" class="btn btn-vert" value=Ajouter>
		</div>
		
		<input type=hidden name="ajouter" value=1>
		</form>
		
		<span class="memoinfo">Pour les véhicules électriques, cocher la case #</span>

    <div class=Titre10>Modifier les véhicules existants</div>

    <ul class=wrapper10>
    ' ;
    
    for ( @$resultat ) {
		
	my $reqline = ($line ++);

	my $electrique_value = ( $_->{electrique} eq 't' ) ? 'checked' : '' ;
	my $delete_href = 'notesdefrais&#63;vehicule&amp;delete=0&amp;vehicule_name=' . URI::Escape::uri_escape_utf8($_->{vehicule_name}) ;
	my $delete_link = '<input type="submit" style="width: 7%;" class="btn btn-rouge" formaction="' . $delete_href . '" value="Supprimer" >' ;
	my $valid_href = 'notesdefrais&#63;vehicule&amp;modifier=1&amp;old_vehicule_name=' . URI::Escape::uri_escape_utf8( $_->{vehicule_name} ) ;
		
    #Requête select_vehicule
    my $selected_vehicule = $_->{puissance};
	my $select_vehicule = '<select onchange="findModif(this,'.$reqline.');" class="formMinDiv4" name=select_vehicule id=select_vehicule_'.$reqline.'>' ;
	for ( @$vehicule_req ) {
	my $selected = ( $_->[1] eq $selected_vehicule) ? 'selected' : '' ;
	$select_vehicule .= '<option value="' . $_->[0] . '!!' . $_->[1] . '" ' . $selected . '>' . $_->[0] . ' - ' . $_->[1] . '</option>' ;
	}
	$select_vehicule .= '</select>' ;
	
	#Requête select_compte
	my $selected_compte = $_->{numero_compte};
	my $select_compte = '<select class="formMinDiv4" name=select_compte id=select_compte_'.$reqline.'
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};findModif(this,'.$reqline.');">' ;
	$select_compte .= '<option class="opt1" value="">Créer un compte</option>' ;
	$select_compte .= '<option value="">--Sélectionner le propriétaire du véhicule--</option>' ;
	for ( @$compte_client_set ) {
	my $selected = ( $_->{numero_compte} eq $selected_compte ) ? 'selected' : '' ;
	$select_compte .= '<option value="' . $_->{numero_compte} . '!!'.$_->{libelle_compte}. '" ' . $selected . '>' . ($_->{numero_compte}) . ' - ' .($_->{libelle_compte}).'</option>' ;
	}
	$select_compte .= '</select>' ;	
	
	#Formulaire Sélectionner un document
	my $selected_docs1 = $_->{documents};
	my $doc_select = undef;
	my $doc_class1 = 'class="blockspan"';
	my $doc_class2 = 'class="line_icon_visible"';
	my $documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $_->{documents});
	
	if (!defined $_->{documents}){
	$doc_class1 = 'class="displayspan"';
	$doc_class2 = 'class="line_icon_hidden"';
	$doc_select = undef;
	} elsif ( !@$documents){
		$doc_select = undef;
	} else {
		$doc_select = $_->{documents};
	}

	$http_link_documents1 = 'docsentry?id_name='.($selected_docs1 || '').'' ;
	
	my $onchangedoc = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};findModif(this,'.$reqline.');\"";
	my ($form_doc, $form_iddoc) = ('documents', 'documents_'.$reqid.'');
	my $select_document = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $doc_select, $form_doc, $form_iddoc, $onchangedoc, 'class="formMinDiv4"', '');

	
	############## Formulaire modification du véhicule ##############
	$formulaire .= '
		<li id="line_'.$reqline.'" class="style1">  
		<div class=formMinDiv1><div class=spacer></div>
        <form class=flex2 method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 19%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name=vehicule_name value="' . $_->{vehicule_name} . '"/></span>
		<span class=displayspan style="width: 19%;">'.$select_vehicule.'</span>
		<span class=displayspan style="width: 20%;">'.$select_compte.'</span>
		<span class=displayspan style="width: 19%;">'.$select_document.'</span>
		<span class="blockspan" style="width: 4%; text-align: center;"><input onchange="findModif(this,'.$reqline.');" class="formMinDiv4" style="height: 4ch;" title="Véhicule électrique ?" type="checkbox" id="electrique_'.$reqline.'" name="electrique" value="true" '.$electrique_value.'></span>
		<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider"></span>
		<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>
		<span '.$doc_class1.' style="width: 4%; text-align: center;"><input '.$doc_class2.' type="image" height="24" width="24" formaction="' . $http_link_documents1.'" title="Ouvrir le document" src="/Compta/style/icons/documents.png" type="submit" alt="document"></span>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<input type=hidden name="old_vehicule_name" value="'.$_->{vehicule_name}.'">
		<input type=hidden name="id_vehicule" value="'.$_->{id_vehicule}.'">
		</form>
		<div class=spacer></div></div></li>
		' ;

	}
	
    $formulaire .= '</ul></fieldset>';

	$content .= '<div class="formulaire2">' . $formulaire . '</div>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_vehicule 

#/*—————————————— Page Gestion Types de Frais ——————————————*/
sub form_types_frais {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
  	my $line = "1"; 
  	my $selected = '';
    
	################ Affichage MENU ################
	$content .= display_menu_ndf( $r, $args ) ;
	################ Affichage MENU ################
	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#UPDATE																  #
	#######################################################################
	
	#1ère demande d'update bareme km, afficher lien d'annulation/confirmation
	if ( defined $args->{types_frais} && defined $args->{update} && $args->{update} eq '0' ) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais&#63;types_frais&amp;update=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous reconduire les types de frais de l\'exercice précédent ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{types_frais} && defined $args->{update} && $args->{update} eq '1' ) {
		#demande de reconduction confirmée
		$sql = '
		INSERT INTO tblndf_frais (id_client, fiscal_year, intitule, compte, tva)
		SELECT ?, ?, intitule, compte, tva FROM tblndf_frais WHERE id_client = ? AND fiscal_year = ?
		ON CONFLICT (id_client, fiscal_year, intitule, compte, tva) DO NOTHING' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitulé de frais') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce type de frais existe déjà') ;
			} else {$content .= Base::Site::util::generate_error_message($@) ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Reconduction des types de frais de l\'exercice précédent '.($r->pnotes('session')->{fiscal_year} - 1).'');
			#Redirection
			$args->{restart} = 'notesdefrais?types_frais';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    if ( defined $args->{types_frais} && defined $args->{delete} && $args->{delete} eq '0') {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais&amp;delete=1&amp;intitule=' . $args->{intitule}.'&amp;compte=' . $args->{compte}.'&amp;tva=' . $args->{tva} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer => Intitulé : ' . $args->{intitule} . ' Compte : ' . $args->{compte} . ' tva :' . $args->{tva} . ' ?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{types_frais} && defined $args->{delete} && $args->{delete} eq '1') {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tblndf_frais WHERE intitule = ? AND compte = ? AND tva = ? AND id_client = ? AND fiscal_year = ?' ;
			@bind_array = ( $args->{intitule}, $args->{compte}, $args->{tva}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitulé de frais') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Suppression d\'un type de frais : Intitulé : ' . $args->{intitule} . ' Compte : ' . $args->{compte} . ' Tva : ' . $args->{tva} . '');
				#Redirection
				$args->{restart} = 'notesdefrais?types_frais';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}

	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{types_frais} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		
		#ne pas laisser des montants nulls : mettre un zéro
	    $args->{select_tva1} ||= '0.00';
	
		# split $args->{select_compte}
		my @Split_2 = split('!!', $args->{select_compte1});
		#récupére [0] numero_compte et [1] libelle_compte
		$args->{numero_compte} = $Split_2[0] ;
		$args->{libelle_compte} = $Split_2[1] ;
		
		#on interdit libelle vide
		if (!$args->{intitule}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitulé') ;
		} elsif (!$args->{numero_compte} && !$args->{libelle_compte}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement sélectionner un compte de charge') ;
		} else {
			
			#ajouter une catégorie
			$sql = 'INSERT INTO tblndf_frais (id_client, fiscal_year, intitule, compte, tva) values (?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{intitule}, $args->{numero_compte}, $args->{select_tva1}  ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitulé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce type de frais existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@) ;}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout d\'un type de frais : Intitulé : '.$args->{intitule}.' Compte : '.$args->{numero_compte}.' - '.$args->{libelle_compte}.' Tva : '. $args->{select_tva1} .'');
				#Redirection
				$args->{restart} = 'notesdefrais?types_frais';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
    
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				 #
	#######################################################################
    if ( defined $args->{types_frais} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
		
		#ne pas laisser des montants nulls : mettre un zéro
	    $args->{tva} ||= '0.00';
		
		# split $args->{select_compte}
		my @Split_2 = split('!!', $args->{select_compte});
		#récupére [0] select_vehicule1 et [1] select_puissance1
		$args->{numero_compte} = $Split_2[0] ;
		$args->{libelle_compte} = $Split_2[1] ;
	    
   	    #modifier une catégorie vehicule, puissance, vehicule_name, numero_compte
	    $sql = 'UPDATE tblndf_frais set intitule = ?, compte = ?, tva = ? where id_client = ? AND fiscal_year = ? AND intitule = ? AND compte = ? AND tva = ?' ;
	    @bind_array = ( $args->{intitule}, $args->{numero_compte}, $args->{tva}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{old_intitule}, $args->{old_compte}, $args->{old_tva}  ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un intitule') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Ce type de frais existe déjà') ;
			} else {$content .= Base::Site::util::generate_error_message($@) ;}
		} else {
			#Redirection
			$args->{restart} = 'notesdefrais?types_frais';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
    }
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	#Requête tblndf_frais => Sélection des types de frais
    $sql = 'SELECT intitule, compte, tva FROM tblndf_frais WHERE id_client = ? AND fiscal_year = ? ORDER by intitule, compte, tva' ;
    my $resultat;
    eval {$resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) };
    
	#Requête tbltva => Sélectionner tva
	$sql = 'SELECT id_tva FROM tbltva ORDER BY 1' ;
    my $tva_set = $dbh->selectall_arrayref( $sql ) ;
    my $option_set = '<select class="forms2_input" style="width: 20%;" name=select_tva1 id=select_tva1>' ;
    $option_set .= '<option value="" selected>--Sélectionner le taux de TVA--</option>' ;
    for ( @$tva_set ) {
	if 	(defined $args->{select_tva1}) {
	my $check = $_->[0];	
	$selected = ( $check eq $args->{select_tva1} ) ? 'selected' : '' ;	
	}
	$option_set .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
    }
    $option_set .= '</select>' ;
	
	#Formulaire Sélectionner compte classe 6
	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 1) IN (\'6\') ORDER by numero_compte, libelle_compte' ;
    my $compte_client_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;
	my $compte_client = '<select class="forms2_input" style="width: 30%;" name=select_compte1 id=select_compte>' ;
	$compte_client .= '<option value="" selected>--Sélectionner le compte de charge--</option>' ;
	for ( @$compte_client_set ) {
	if 	(defined $args->{select_compte1}) {
	my $check = ''.$_->{numero_compte}.'!!'.$_->{libelle_compte}.'';	
	$selected = ( $check eq $args->{select_compte1} ) ? 'selected' : '' ;
	}				
	$compte_client .= '<option value="' . $_->{numero_compte} . '!!' . $_->{libelle_compte} . '" '.$selected.'>' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</option>' ;
	}
	$compte_client .= '</select>' ;	
	
	my $new_href = 'notesdefrais&#63;types_frais&amp;update=0' ;
    my $new_link = '<input type="submit" class="btn btn-vert" style ="width : 50%;" formaction=' . $new_href . ' value="Reconduire les types de frais de l\'exercice précédent '.($r->pnotes('session')->{fiscal_year} - 1).'" >' ;
    	
	############## Formulaire Gestion des types de frais ##############	
    my $formulaire = '
    <fieldset class="pretty-box"><legend><h3 class="Titre09">Types de frais</h3></legend>
    <div class=centrer>
		<br>
		<form method="post">
		'.$new_link.'
		</form>
		<br>
        <div class=Titre10>Ajouter un type de frais</div>
		<div class="form-int">
        <form method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais>
        <input class="login-text" style="width: 25%;" type=text placeholder="Entrer l\'intitule" id=intitule name="intitule" value="'.($args->{intitule} || '').'" required>
        ' . $compte_client . '
        ' . $option_set . '
		<input type=hidden name="ajouter" value=1>
		<br><br>
		<input type=submit class="btn btn-vert" value=Ajouter>
		</form></div>

    <div class=Titre10>Modifier les types de frais existants</div>
    <div class="form-int">
    ' ;
    
    for ( @$resultat ) {
		
	my $reqline = ($line ++);	

	my $delete_href = 'notesdefrais&#63;types_frais&amp;delete=0&amp;intitule=' . URI::Escape::uri_escape_utf8($_->{intitule}).'&amp;compte='.$_->{compte}.'&amp;tva='.$_->{tva} ;
	my $delete_link = '<input type="submit" style="width: 7%;" class="btn btn-rouge" formaction="' . $delete_href . '" value="Supprimer" >' ;
	my $valid_href = 'notesdefrais&#63;types_frais&amp;modifier=1' ;
	
	#Requête tbltva => Sélectionner tva
    my $selected_tva = $_->{tva};
	my $select_tva = '<select class="login-text" style="width: 10%;" name=tva id=select_tva_'.$reqline.'>' ;
	for ( @$tva_set) {
	my $selected = ( $_->[0] eq $selected_tva) ? 'selected' : '' ;
	$select_tva .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
	}
	$select_tva .= '</select>' ;
	
	#Requête select_compte
	my $selected_compte = $_->{compte};
	my $select_compte = '<select class="login-text" name=select_compte id=select_compte_'.$reqline.' style="width: 30%;">' ;
	for ( @$compte_client_set ) {
	my $selected = ( $_->{numero_compte} eq $selected_compte ) ? 'selected' : '' ;
	$select_compte .= '<option value="' . $_->{numero_compte} . '!!'.$_->{libelle_compte}. '" ' . $selected . '>' . ($_->{numero_compte}) . ' - ' .($_->{libelle_compte}).'</option>' ;
	}
	$select_compte .= '</select>' ;	

	
	############## Formulaire modification du véhicule ##############
	$formulaire .= '
        <form class=flex2 method="post" action=/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais>
		<input class="login-text" type=text name=intitule style="width: 25%;" value="' . $_->{intitule} . '"/>
		'.$select_compte.'
		'.$select_tva.'
		<input type="submit" style="width: 7%;" class="btn btn-vert" formaction="' . $valid_href . '" value=Valider>
		'.$delete_link.'
		<input type=hidden name="old_intitule" value="'.$_->{intitule}.'">
		<input type=hidden name="old_compte" value="'.$_->{compte}.'">
		<input type=hidden name="old_tva" value="'.$_->{tva}.'">
		</form>
		' ;
	}
	
    $formulaire .= '</div></fieldset>';

	$content .= '<div class="wrapper">' . $formulaire . '</div>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_types_frais 

#/*—————————————— Page MAJ Barème kilométrique ——————————————*/
sub form_majbaremekm {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;

    $sql = 'SELECT vehicule, puissance, distance1, distance2, prime2, distance3 FROM tblndf_bareme WHERE id_client = ? AND fiscal_year = ? ORDER by puissance' ;
    my $resultat;
    eval {$resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) };
    
    #MAJ valeurs Barème kilométrique
    if (!(@$resultat) || $args->{update} eq 1) {
		
	my $fiscal_year = $r->pnotes('session')->{fiscal_year};
	my $vehicleData;

	if ($fiscal_year eq '2023' || $fiscal_year eq '2024') {
		$vehicleData = [
			['Automobile', '3CV et moins', 0.529, 0.316, 1065, 0.37],
			['Automobile', '4CV', 0.606, 0.34, 1330, 0.407],
			['Automobile', '5CV', 0.636, 0.357, 1395, 0.427],
			['Automobile', '6CV', 0.665, 0.374, 1457, 0.447],
			['Automobile', '7CV et plus', 0.697, 0.394, 1515, 0.47],
			['deux-roues', '50CC et moins', 0.315, 0.079, 711, 0.198],
			['deux-roues', '1 ou 2CV', 0.395, 0.099, 891, 0.248],
			['deux-roues', '3,4 ou 5CV', 0.468, 0.082, 1158, 0.275],
			['deux-roues', 'Supérieur à 5CV', 0.606, 0.079, 1583, 0.343]
		];
	} elsif ($fiscal_year eq '2022') {
		$vehicleData = [
			['Automobile', '3CV et moins', 0.502, 0.3, 1007, 0.35],
			['Automobile', '4CV', 0.575, 0.323, 1262, 0.387],
			['Automobile', '5CV', 0.603, 0.339, 1320, 0.405],
			['Automobile', '6CV', 0.631, 0.355, 1382, 0.425],
			['Automobile', '7CV et plus', 0.661, 0.374, 1435, 0.446],
			['deux-roues', '50CC et moins', 0.299, 0.07, 458, 0.162],
			['deux-roues', '1 ou 2CV', 0.375, 0.094, 845, 0.234],
			['deux-roues', '3,4 ou 5CV', 0.444, 0.078, 1099, 0.261],
			['deux-roues', 'Supérieur à 5CV', 0.575, 0.075, 1502, 0.325]
		];
	} else {
		$vehicleData = [
			['Automobile', '3CV et moins', 0.502, 0.3, 1007, 0.35],
			['Automobile', '4CV', 0.575, 0.323, 1262, 0.387],
			['Automobile', '5CV', 0.603, 0.339, 1320, 0.405],
			['Automobile', '6CV', 0.631, 0.355, 1382, 0.425],
			['Automobile', '7CV et plus', 0.661, 0.374, 1435, 0.446],
			['deux-roues', '50CC et moins', 0.299, 0.07, 458, 0.162],
			['deux-roues', '1 ou 2CV', 0.375, 0.094, 845, 0.234],
			['deux-roues', '3,4 ou 5CV', 0.444, 0.078, 1099, 0.261],
			['deux-roues', 'Supérieur à 5CV', 0.575, 0.075, 1502, 0.325]
		];
	}

	my $sql = 'INSERT INTO tblndf_bareme (id_client, fiscal_year, vehicule, puissance, distance1, distance2, prime2, distance3) VALUES';

	foreach my $data (@$vehicleData) {
		$sql .= '('.$r->pnotes('session')->{id_client}.', '.$fiscal_year.', \''.$data->[0].'\', \''.$data->[1].'\', '.$data->[2].', '.$data->[3].', '.$data->[4].', '.$data->[5].'),';
	}

	chop($sql) if substr($sql, -1) eq ',';
	$sql .= ' ON CONFLICT (id_client, fiscal_year, vehicule, puissance) DO UPDATE SET (distance1, distance2, prime2, distance3) = (EXCLUDED.distance1, EXCLUDED.distance2, EXCLUDED.prime2, EXCLUDED.distance3)';
	
	eval { $dbh->do( $sql, undef) } ;	
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Update Barème kilométrique '.$r->pnotes('session')->{fiscal_year}.'');
	
	}

    return $content ;
    
    
} #sub form_majbaremekm 

#/*—————————————— Export PDF Champ——————————————*/
sub export_pdf {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	my ( $pdf, $page, $text, $raleway, $firstname, $lastname ) ;

    my $filepdf = '/Compta/images/pdf/proof.pdf';
    my $locationpdf = $r->document_root() . $filepdf ;
	#LECTURE POSITION FORMULAIRE EXCEL
    my $filecsv = '/Compta/images/pdf/proof.csv';
    my $locationcsv = $r->document_root() . $filecsv ;
    my %data;
    
    #si le fichier existe
	if (-e $locationcsv) {
		open(my $fh, '<', $locationcsv) or die "Can't read file '$locationcsv' [$!]\n";
		my $header = <$fh>;
		chomp $header;
		my @header = split /,/, $header;
		while (my $line = <$fh>) {
			chomp $line;
			my %row;
			@row{@header} = split /,/, $line;
			my $key = $row{code};
			$data{$key} = \%row;
			#variable sous la forme
			#$data{AA}{code}
			#$data{AA}{MatriceE}
			#$data{AA}{MatriceF}
			#$data{AA}{var}
		}
	}
	
	$pdf = PDF::API2->open($locationpdf);
	$page = $pdf->openpage(1);
	$page->mediabox(8.5*72,11*72);
 
	$text = $page->text();
	$raleway = $pdf->ttfont($r->document_root() .'/Compta/style/fonts/raleway-normal.ttf');
	$text->font($raleway,12);
	$text->fillcolor('#000000'); 
	$firstname = 'Raf';
	$lastname = 'PENCH';
	 
	$text->translate($data{AA}{MatriceE},$data{AA}{MatriceF});
	$text->text($firstname);
	 
	$text->translate($data{AB}{MatriceE},$data{AB}{MatriceF});
	$text->text($lastname);
	 
	$pdf->saveas($r->document_root() . '/Compta/images/pdf/1040.pdf');

    return ;

} #sub export_pdf 

#/*—————————————— Export PDF Complet——————————————*/
sub export_pdf2 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	my $books ;
	
	############## Récupérations d'informations ##############
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t5.id_facture, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	LEFT JOIN (SELECT DISTINCT ON(id_entry) id_entry, id_client, fiscal_year, id_facture FROM tbljournal) t5 ON t1.id_client = t5.id_client AND t1.fiscal_year = t5.fiscal_year AND t1.piece_entry = t5.id_entry
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    #Requête tblndf_detail
	$sql = 'SELECT t1.id_client,  t1.fiscal_year,  t1.piece_ref,  t1.frais_date,  t1.frais_compte, t2.libelle_compte, t1.frais_libelle,  t1.frais_bareme,  t1.frais_quantite, t1.frais_montant/100::numeric as frais_montant, (sum( t1.frais_quantite) over())::integer as total_quantite, (sum( t1.frais_montant) over())/100::numeric as total_montant,  t1.frais_doc,  t1.frais_line
	FROM tblndf_detail t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.frais_compte = t2.numero_compte
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.piece_ref = ? 
	ORDER BY t1.frais_date, t1.frais_compte, t1.frais_libelle ' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;
	my $array_tblndf_detail = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
	#Récupérations des informations de la société
    $sql = 'SELECT etablissement, siret, date_debut, date_fin, padding_zeroes, fiscal_year_start, id_tva_periode, id_tva_option, adresse_1, code_postal, ville, journal_tva FROM compta_client WHERE id_client = ?' ;
    my $parametre_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
	#Requête total km vehicule
	$sql = 'SELECT (sum(t2.frais_quantite) over())::integer as total_quantite
	FROM tblndf t1
	INNER JOIN (SELECT frais_quantite, id_client, fiscal_year, piece_ref FROM tblndf_detail) t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_ref = t2.piece_ref
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.id_vehicule = ? and t1.piece_entry IS NOT NULL limit 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_notes->[0]->{id_vehicule}) ;
	my $array_count_detail = eval {$dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0]} ;

	############## Récupérations d'informations ##############

	
	############## DEFINITION DES VALEURS ##############
	# PDF
	my $pdf = PDF::API2->new;

	#$pdf->mediabox('A4'); => Format A4
	#$pdf->mediabox(595, 842); => format A4 portrait Unite points
	#format A4 paysage landscape
	$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 48;
	my $page_bottom_margin = 48;
	my $page_left_margin = 48;
	my $page_right_margin = 48;
	#Définition des coordonnées de départ et de fin x et y
	my $render_start_x = $page_left_margin;
	my $render_start_y = $page_height - 1 - $page_top_margin;
	my $render_end_x = $page_width - 1 - $page_right_margin;
	my $render_end_y = $page_bottom_margin;

	my $font = $pdf->corefont('Helvetica');
	my $font_bold = $pdf->corefont('Helvetica-Bold');
	# Font size-default
	my $font_size_default = 10;
	my $font_size_tableau = 9;
	# Format Tableau
	# Set the minimum unit of height and width, the minimum unit of width is divided into 100
	my $unit_height = 14;
	my $unit_width = ($render_end_x-$render_start_x)/100;
	# Text drawing padding
	my $text_bottom_padding = 3;
	my $text_left_padding = 3;

	# Color list
	my $color_black = '#000';

	# Line width
	my $line_width_basic = 0.3;
	my $line_width_bold = 2;

	# Ajout Page depuis template
	my $page = _add_pdf_page( $r, $args , $pdf);

	# Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor($color_black);
	$text->fillcolor($color_black);
	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 12;
	my $cur_row_left = 6;
	my $cur_row_right = 6;
	my $cur_row_middle = -0.5;
	
	############## INFO TIERS GAUCHE PAGE 1 ##############
	# Libellé
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Libellé : '.$array_of_notes->[0]->{piece_libelle});
	$cur_row_left += 1;
	# Tiers
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Tiers : '.$array_of_notes->[0]->{piece_compte}.' - '.$array_of_notes->[0]->{libelle_compte}.'');
	$cur_row_left += 1;

	if ($array_of_notes->[0]->{vehicule_name}){
		# Véhicule
		$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text('Véhicule : '.$array_of_notes->[0]->{vehicule_name}.' ('.$array_of_notes->[0]->{puissance}.')');
		$cur_row_left += 1;
		############## INFO VEHICULE DROITE PAGE 1##############

		# Véhicule
		my $vehicule_disp = 'Barème kilométrique ' . $r->pnotes('session')->{fiscal_year} . ' (en €)';
		$text->translate($render_start_x + 58 * $unit_width + (43.5 * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center($vehicule_disp);
	
		# background en-tête
		$gfx->rectxy(
		  $render_end_x-300, $render_start_y-$unit_height * $cur_row_right,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row_right + 2)
		);
		$gfx->fillcolor('# eee');
		$gfx->fill;
	
		#Ligne en-tête debut
		$gfx->move($render_end_x-300, $render_start_y-$unit_height * $cur_row_right);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row_right += 1;
		
		#en tête
		my $vehicule_column_count = 58;
		my $var1_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var1_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Jusqu\'à 5000 km');
		$vehicule_column_count += $var1_units_count;
		my $var2_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var2_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('de 5001 à 20000 km');
		$vehicule_column_count += $var2_units_count;
		my $var3_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var3_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Au-delà de 20000 km');
		$cur_row_right += 1;
		$vehicule_column_count = 58;
		
		#Ligne en-tête fin
		$gfx->move($render_end_x-300, $render_start_y-$unit_height * $cur_row_right);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;

		# var1
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var1_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance1}.'');
		$vehicule_column_count += $var1_units_count;

		# var2
		$gfx->poly(
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * $cur_row_right,
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row_right - 2)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var2_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance2}.' + '.$array_of_notes->[0]->{prime2}.'');
		$vehicule_column_count += $var2_units_count;
	  
		# var3
		$gfx->poly(
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * $cur_row_right,
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row_right - 2)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var3_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance3}.'');
		$cur_row_right += 1;
		# Total KM
		$text->translate($render_start_x + 58 * $unit_width + (43.5 * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center(''.($array_tblndf_detail->[0]->{total_quantite}|| '0').' kilomètres dans cette note VS '.($array_count_detail || '0').' kilomètres cumulés en '.$r->pnotes('session')->{fiscal_year}.'');

		#Formule des frais kilométriques de ce véhicule en 2022
		############## INFO VEHICULE DROITE PAGE 1##############
	} 

	#for my $line (split /\n+/, $summary) {
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com1} || ''));
	if ($array_of_notes->[0]->{com1}) {
	$cur_row_left += 1;
	}
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com2} || ''));
	if ($array_of_notes->[0]->{com2}) {
	$cur_row_left += 1;
	}
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com3} || ''));
	if ($array_of_notes->[0]->{com3}) {
	$cur_row_left += 1;
	}
	############## INFO TIERS GAUCHE PAGE 1 ##############
	
	#split les resultats de la requête
	my $rows_count = 20; # NOMBRE LIGNE TABLEAU 1ERE PAGE
	my $numberofarrays = 27; # NOMBRE LIGNE TABLEAU AUTRES PAGES
	my @del = splice @$array_tblndf_detail, $rows_count; 
	my @new4 = split_by($numberofarrays,@del);

		# Ligne TOP
		# background 1ère Ligne Decoration en tête
		$gfx->rectxy(
		  $render_start_x, $render_start_y-$unit_height * $cur_row,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row + 1)
		);
		$gfx->fillcolor('# eee');
		$gfx->fill;
		# 1ère Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row += 1;

		# Save the position of the thick line under the quotation heading
		my $header_bottom_line_row = $cur_row;
		my $cur_column_units_count = 0;

		#espace en tête
		my $date_units_count = 7;
		my $depense_units_count = 31;
		my $libelle_units_count = 44;
		my $bareme_units_count = 6;
		my $km_units_count = 5;
		my $montant_units_count = 7;
		############## ENTÊTE TABLEAU ##############
		# Date
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($date_units_count * $unit_width/3), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text('Date');
		$cur_column_units_count += $date_units_count;
		# Dépense
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($depense_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Dépense');
		$cur_column_units_count += $depense_units_count;
		# Libellé
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($libelle_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Libellé');
		$cur_column_units_count += $libelle_units_count;
		# Baréme
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Baréme');
		$cur_column_units_count += $bareme_units_count;
		# KM
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('KM');
		$cur_column_units_count += $km_units_count;
		# Montant
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($montant_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Montant');
		$cur_column_units_count = 0;
		############## ENTÊTE TABLEAU ##############

		$cur_row ++;

		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => nb de valeur scalar: '. scalar(@new).' et datadumper '. scalar(@$array_tblndf_detail).' <hr> et datadumper 1' . Data::Dumper::Dumper($new[1]) . ' <hr> et datadumper 2' . Data::Dumper::Dumper($new[2]) . '');
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => valeur scalar(@$array_tblndf_detail): '. scalar(@$array_tblndf_detail) );

		############## RECUPERATION RESULTAT REQUETE ##############
		for (my $row = 0; $row < $rows_count; $row ++) {
			
			my $book = $array_tblndf_detail->[$row];

			my $frais_montant;
			
			if ($book && defined $book->{frais_montant} && $book->{frais_montant} ne '') {
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper 1' . Data::Dumper::Dumper($book) . ' ');
			($frais_montant = sprintf( "%.2f", $book->{frais_montant} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}
			
			# Lines are painted alternately
			if ($row % 2 == 1) {
				$gfx->rectxy(
				$render_start_x,
				$render_start_y-$unit_height * $cur_row,
				$render_end_x,
				$render_start_y-$unit_height * ($cur_row - 1),
				);
				$gfx->fillcolor('# eee');
				$gfx->fill;
			}
			  
			# Date
			if ($book->{frais_date}) {
				$text->translate(
				  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text($book->{frais_date});
			}
			$cur_column_units_count += $date_units_count;

			# Dépense
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_compte}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr((($book->{frais_compte} || '') . ' - '. ($book->{libelle_compte} || '')), 0, 56 ));
			}
			$cur_column_units_count += $depense_units_count;

			# Libellé
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_libelle}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr($book->{frais_libelle}, 0, 64));
			}
			$cur_column_units_count += $libelle_units_count;

			# Baréme
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_bareme}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($book->{frais_bareme});
			}
			$cur_column_units_count += $bareme_units_count;
			  
			# KM
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_quantite}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($book->{frais_quantite});
			}
			$cur_column_units_count += $km_units_count;

			# Montant
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_montant}) {
				$text->translate(
				$render_end_x,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($frais_montant.' €');
			}
			$cur_column_units_count = 0;

			$cur_row ++;
		}
		
		############## RECUPERATION RESULTAT REQUETE ##############
		# 2ème Ligne décoration En tête
		$gfx->move($render_start_x, $render_start_y-$unit_height * $header_bottom_line_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		
		# si plus de 20 lignes pages 1 génération nouvelle page de 27 lignes 
		foreach (@new4) {
		
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => First ligne '.$pg_cnt.' dumper ' . Data::Dumper::Dumper($_) . ' ');
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => X ligne '.$pg_cnt.' ');
		
		# Ajout Page depuis template
		$page = _add_pdf_page( $r, $args , $pdf);
		
		# Graphic drawing
		$gfx = $page->gfx;
		# Text drawing
		$text = $page->text;
		#Couleur texte noir par default
		$text->strokecolor($color_black);
		$text->fillcolor($color_black);
		# Ligne de départ nouvelle page
		my $cur_row = 5;
		
		# Ligne TOP
		# background 1ère Ligne Decoration en tête
		$gfx->rectxy(
		  $render_start_x, $render_start_y-$unit_height * $cur_row,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row + 1)
		);
		$gfx->fillcolor('# eee');
		$gfx->fill;
		# 1ère Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row += 1;

		# Save the position of the thick line under the quotation heading
		$header_bottom_line_row = $cur_row;
		$cur_column_units_count = 0;

		############## ENTÊTE TABLEAU ##############
		# Date
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($date_units_count * $unit_width/3), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text('Date');
		$cur_column_units_count += $date_units_count;
		# Dépense
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($depense_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Dépense');
		$cur_column_units_count += $depense_units_count;
		# Libellé
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($libelle_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Libellé');
		$cur_column_units_count += $libelle_units_count;
		# Baréme
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Baréme');
		$cur_column_units_count += $bareme_units_count;
		# KM
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('KM');
		$cur_column_units_count += $km_units_count;
		# Montant
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($montant_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Montant');
		$cur_column_units_count = 0;
		############## ENTÊTE TABLEAU ##############

		$cur_row ++;
		
		$rows_count = 27; # NOMBRE LIGNE TABLEAU

		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => nb de valeur scalar: '. scalar(@new).' et datadumper '. scalar(@$array_tblndf_detail).' <hr> et datadumper 1' . Data::Dumper::Dumper($new[1]) . ' <hr> et datadumper 2' . Data::Dumper::Dumper($new[2]) . '');
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => valeur scalar(@$array_tblndf_detail): '. scalar(@$array_tblndf_detail) );

		############## RECUPERATION RESULTAT REQUETE ##############
		for (my $row = 0; $row < $rows_count; $row ++) {
			my $book =  $_->[$row];
			
			my $frais_montant;
			if ($book && defined $book->{frais_montant} && $book->{frais_montant} ne '') {
			($frais_montant = sprintf( "%.2f", $book->{frais_montant} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}

			# Lines are painted alternately
			if ($row % 2 == 1) {
				$gfx->rectxy(
				$render_start_x,
				$render_start_y-$unit_height * $cur_row,
				$render_end_x,
				$render_start_y-$unit_height * ($cur_row - 1),
				);
				$gfx->fillcolor('# eee');
				$gfx->fill;
			}
			  
			# Date
			if ($book->{frais_date}) {
				$text->translate(
				  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text($book->{frais_date});
			}
			$cur_column_units_count += $date_units_count;

			# Dépense
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_compte}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr((($book->{frais_compte} || '') . ' - '. ($book->{libelle_compte} || '')), 0, 54 ));
			}
			$cur_column_units_count += $depense_units_count;

			# Libellé
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_libelle}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr($book->{frais_libelle}, 0, 64));
			}
			$cur_column_units_count += $libelle_units_count;

			# Baréme
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_bareme}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($book->{frais_bareme});
			}
			$cur_column_units_count += $bareme_units_count;
			  
			# KM
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_quantite}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($book->{frais_quantite});
			}
			$cur_column_units_count += $km_units_count;

			# Montant
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book->{frais_montant}) {
				$text->translate($render_end_x,$render_start_y-$unit_height * $cur_row + $text_bottom_padding);
				$text->font($font, $font_size_tableau);
				$text->text_right($frais_montant.' €');
			}
			  $cur_column_units_count = 0;

			  $cur_row ++;
		}
		
		############## RECUPERATION RESULTAT REQUETE ##############
		# 2ème Ligne décoration En tête
		$gfx->move($render_start_x, $render_start_y-$unit_height * $header_bottom_line_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
	}  
	
	#Ecriture sur dernière page en cours
	$gfx = $page->gfx;
	$text = $page->text;
	$text->strokecolor($color_black);
	$text->fillcolor($color_black);
	
	# Ligne épaisse Séparation Total
	$gfx->move($render_start_x, $render_start_y-$unit_height * ($cur_row - 1));
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_bold);
	$gfx->strokecolor($color_black);
	$gfx->stroke;
	
	( my $total_montant = sprintf( "%.2f", ($array_tblndf_detail->[0]->{total_montant} || 0) ) ) =~ s/\B(?=(...)*$)/ /g ;
	
	# TOTAL1
	my $price_total_no_tax_label = 'TOTAL';
	$text->translate($render_start_x + ($date_units_count + $depense_units_count + $libelle_units_count + $bareme_units_count) * $unit_width + ($km_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font_bold, $font_size_tableau);
	$text->text_center($price_total_no_tax_label);
	$text->translate($render_end_x, $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_tableau);
	$text->text_right($total_montant.' €');
	$cur_row += 0;

	#Requête info NDF frais en cours
	$sql = '
	SELECT distinct ON(t1.frais_doc) t1.frais_doc, t3.fiscal_year as doc_year, t1.id_client,  t1.fiscal_year,  t1.piece_ref,  t1.frais_date,  t1.frais_compte, t2.libelle_compte, t1.frais_libelle,  t1.frais_bareme,  t1.frais_quantite,  to_char(t1.frais_montant/100::numeric, \'999G999G999G990D00\') as frais_montant, (sum( t1.frais_quantite) over())::integer as total_quantite, to_char((sum( t1.frais_montant) over())/100::numeric, \'999G999G999G990D00\') as total_montant,  t1.frais_line
	FROM tblndf_detail t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.frais_compte = t2.numero_compte
	INNER JOIN tbldocuments t3 ON t1.id_client = t3.id_client AND t1.frais_doc = t3.id_name
	WHERE piece_ref = ?';
	my $result_ndf_doc = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, $args->{piece_ref} ) ;
	
	#Ajout des documents des frais en cours
	for (@$result_ndf_doc) {

		#définition répertoire du pdf à récupérer
		my $base_dir = $r->document_root() . '/Compta/base/documents/' ;
		my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$_->{doc_year}. '/' ;
		my $pdf_file = $archive_dir . $_->{frais_doc};
		my $frais_date = $_->{frais_date} ;
		my $frais_compte = $_->{frais_compte} ;
		my $libelle_compte = $_->{libelle_compte} ;
		my $frais_libelle = $_->{frais_libelle} ;
		
		# Vérification de l'existence du fichier PDF
		unless (-e $pdf_file) {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'Le fichier PDF '.$pdf_file.' de la ligne de frais "'.($_->{frais_libelle}|| '').'" n\'existe pas. ');
			next; # Passer au document suivant
		}

		my $input_pdf = eval { PDF::API2->open($pdf_file) };
		if ($@) {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'Erreur lors de l\'ouverture du fichier PDF '.$pdf_file.' de la ligne de frais "'.($_->{frais_libelle}|| '').'" : '.$@.' ');
			next; # Passer au document suivant
		}

		my @pages = 1 .. $input_pdf->pages;

		my $count = 0;
		
		if ( scalar @pages > 0 ) {

            foreach ( @pages ) {
				
				my $page = $pdf->importpage($input_pdf, $_, 0);
				
				# détection format de la page
				(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;
				
				my $render_start_y_page = $ury - 1 - $page_top_margin;
				my $render_end_x_page = $urx - 1 - $page_right_margin;
				
				$gfx = $page->gfx;
				$text = $page->text;
				$text->strokecolor($color_black);
				$text->fillcolor($color_black);
				$text->translate($render_end_x_page, 18);
				$text->font($font, 8);
				$text->text_right(''.$frais_date.' : '.$frais_compte.' - '.$libelle_compte.' : '.$frais_libelle.'' );
            }
        }

	}

	# HEADER ET FOOTER
	foreach my $pagenum (1 .. $pdf->pages) {

		my $page = $pdf->openpage($pagenum);
		my $font = $pdf->corefont('Helvetica');
		
		# détection format de la page
		(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;
		my $render_end_x_page = $urx - 1 - $page_right_margin;
		
		#count nb pages
		my $pages = $pdf->pages;
		my $totalpages += $pages;
		
		$gfx = $page->gfx;
		$text = $page->text;
		$text->strokecolor($color_black);
		$text->fillcolor($color_black);
		$text->translate($render_end_x_page, 28);
		$text->font($font, 8);
		$text->text_right( 'page '.$pagenum.' / '.$totalpages.'' );
  
	}

	#Enregistrer le pdf
	my $file = '/Compta/images/pdf/print.pdf';
	my $pdf_file = $r->document_root() . $file;
	$pdf->saveas($pdf_file);

	return $file ;

}#sub export_pdf2 

#/*—————————————— Export PDF Complet v3——————————————*/
sub export_pdf3 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	my $books ;
	
	############## Récupérations d'informations ##############
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t5.id_facture, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	LEFT JOIN (SELECT DISTINCT ON(id_entry) id_entry, id_client, fiscal_year, id_facture FROM tbljournal) t5 ON t1.id_client = t5.id_client AND t1.fiscal_year = t5.fiscal_year AND t1.piece_entry = t5.id_entry
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    #Requête tblndf_detail
	$sql = 'SELECT t1.id_client,  t1.fiscal_year,  t1.piece_ref,  t1.frais_date,  t1.frais_compte, t2.libelle_compte, t1.frais_libelle,  t1.frais_bareme,  t1.frais_quantite,  to_char(t1.frais_montant/100::numeric, \'999G999G999G990D00\') as frais_montant, (sum( t1.frais_quantite) over())::integer as total_quantite, to_char((sum( t1.frais_montant) over())/100::numeric, \'999G999G999G990D00\') as total_montant,  t1.frais_doc,  t1.frais_line
	FROM tblndf_detail t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.frais_compte = t2.numero_compte
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.piece_ref = ? 
	ORDER BY t1.frais_date, t1.frais_compte, t1.frais_libelle ' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;
	my $array_tblndf_detail = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
	#Récupérations des informations de la société
    $sql = 'SELECT etablissement, siret, date_debut, date_fin, padding_zeroes, fiscal_year_start, id_tva_periode, id_tva_option, adresse_1, code_postal, ville, journal_tva FROM compta_client WHERE id_client = ?' ;
    my $parametre_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
	#Requête total km vehicule
	$sql = 'SELECT (sum(t2.frais_quantite) over())::integer as total_quantite
	FROM tblndf t1
	INNER JOIN (SELECT frais_quantite, id_client, fiscal_year, piece_ref FROM tblndf_detail) t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_ref = t2.piece_ref
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.id_vehicule = ? and t1.piece_entry IS NOT NULL limit 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $array_of_notes->[0]->{id_vehicule}) ;
	my $array_count_detail = eval {$dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0]} ;

	############## Récupérations d'informations ##############

	
	############## DEFINITION DES VALEURS ##############
	# PDF
	my $pdf = PDF::API2->new;

	# Paper size A4 setting
	#$pdf->mediabox('A4'); => Format A4
	#$pdf->mediabox(595, 842); => format A4 portrait Unite points
	#format A4 paysage landscape
	$pdf->mediabox(842, 595);

	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];

	# Page margin
	my $page_top_margin = 48;
	my $page_bottom_margin = 48;
	my $page_left_margin = 49;
	my $page_right_margin = 49;

	# Loading TrueType fonts that support Japanese-normal fonts and bold fonts
	my $true_type_font_file = $r->document_root() .'/Compta/style/fonts/Roboto-Regular.ttf';
	my $font = $pdf->ttfont($true_type_font_file);
	my $true_type_font_bold_file = $r->document_root() .'/Compta/style/fonts/Roboto-Bold.ttf';
	my $font_bold = $pdf->ttfont($true_type_font_bold_file);

	# Font size-default
	my $font_size_default = 10;
	my $font_size_tableau = 9;

	# Start drawing x coordinate
	my $render_start_x = $page_left_margin;

	# Start drawing y coordinate
	my $render_start_y = $page_height - 1- $page_top_margin;

	# End of drawing x coordinate
	my $render_end_x = $page_width - 1- $page_right_margin;

	# Drawing end y coordinate
	my $render_end_y = $page_bottom_margin;

	# Format Tableau
	# Set the minimum unit of height and width, the minimum unit of width is divided into 100
	my $unit_height = 14;
	my $unit_width = ($render_end_x-$render_start_x)/100;

	# Text drawing padding
	my $text_bottom_padding = 3;
	my $text_left_padding = 3;

	# Width of recipient company column
	my $receive_company_end_tds_count = 55;

	# Start position of billing company column
	my $send_company_start_tds_count = 66.5;

	# Color list
	my $color_black = '# 000';

	# Line width
	my $line_width_basic = 0.3;
	my $line_width_bold = 2;

	# Page
	my $page = $pdf->page();

	#$page->rotate(90);

	# Graphic drawing
	my $gfx = $page->gfx;

	# Text drawing
	my $text = $page->text;

	#Couleur texte noir par default
	$text->strokecolor($color_black);
	$text->fillcolor($color_black);

	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 12;
	my $cur_row_left = 0;
	my $cur_row_right = 0;
	my $cur_row_middle = -0.5;

	############## TITRE MIDDLE ##############
	# Top thick line
	$gfx->move($render_start_x+285, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$gfx->hline($render_end_x-285);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 1.5;
	# Titre
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font_bold, 20);
	$text->text_center('Note de frais');
	$cur_row_middle += 1;
	# Titre piece_ref
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font, 10);
	$text->text_center($array_of_notes->[0]->{piece_ref});
	$cur_row_middle += 0.25;
	# Top thick line
	$gfx->move($render_start_x+285, $render_start_y-$unit_height * $cur_row_middle);
	$gfx->hline($render_end_x-285);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 0.5;
	############## TITRE MIDDLE ##############

	############## INFO SOCIETE DROITE ##############
	# Date de début
	#$text->translate($render_end_x, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	#$text->font($font, $font_size_default);
	#$text->text_right('Date : '.$array_of_notes->[0]->{piece_date}.'');
	#$cur_row_right += 1;
	# piece_ref
	$text->translate($render_start_x + 87.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Date : '.$array_of_notes->[0]->{piece_date});
	$cur_row_right += 1;
	$text->translate($render_start_x + 87.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Pièce: '.($array_of_notes->[0]->{id_facture} || ''));
	$cur_row_right += 5;
	############## INFO SOCIETE DROITE ##############

	############## INFO SOCIETE GAUCHE ##############
	# etablissement
	my $sender_company_name = ''.$parametre_set->[0]->{etablissement} . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_company_name);
	$cur_row_left += 1;
	# Adresse
	my $sender_addr = '' . ($parametre_set->[0]->{adresse_1} || '') . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_addr);
	$cur_row_left += 1;
	# code postale
	my $sender_zip_code = '' . ($parametre_set->[0]->{code_postal} || ''). ' ' . ($parametre_set->[0]->{ville} || '').'';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_zip_code);
	$cur_row_left += 1;
	# Siret
	my $sender_siret = 'SIRET : ' . $parametre_set->[0]->{siret} . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_siret);
	$cur_row_left += 3;
	############## INFO SOCIETE GAUCHE ##############

	############## INFO TIERS GAUCHE ##############
	# Libellé
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Libellé : '.$array_of_notes->[0]->{piece_libelle});
	$cur_row_left += 1;
	# Tiers
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Tiers : '.$array_of_notes->[0]->{piece_compte}.' - '.$array_of_notes->[0]->{libelle_compte}.'');
	$cur_row_left += 1;

	if ($array_of_notes->[0]->{vehicule_name}){
		# Véhicule
		$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text('Véhicule : '.$array_of_notes->[0]->{vehicule_name}.' ('.$array_of_notes->[0]->{puissance}.')');
		$cur_row_left += 1;
		############## INFO VEHICULE DROITE ##############

		#my $date_units_count = 8;
		#$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($date_units_count * $unit_width/3), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		#$$vehicule_column_count += $date_units_count;

		# Véhicule
		my $vehicule_disp = 'Barème kilométrique ' . $r->pnotes('session')->{fiscal_year} . ' (en €)';
		$text->translate($render_start_x + 58 * $unit_width + (43.5 * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center($vehicule_disp);
	
		# background en-tête
		$gfx->rectxy(
		  $render_end_x-300, $render_start_y-$unit_height * $cur_row_right,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row_right + 2)
		);
		$gfx->fillcolor('# eee');
		$gfx->fill;
	
		#Ligne en-tête debut
		$gfx->move($render_end_x-300, $render_start_y-$unit_height * $cur_row_right);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row_right += 1;
		
		#en tête
		my $vehicule_column_count = 58;
		my $var1_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var1_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Jusqu\'à 5000 km');
		$vehicule_column_count += $var1_units_count;
		my $var2_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var2_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('de 5001 à 20000 km');
		$vehicule_column_count += $var2_units_count;
		my $var3_units_count = 14;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var3_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Au-delà de 20000 km');
		$cur_row_right += 1;
		$vehicule_column_count = 58;
		
		#Ligne en-tête fin
		$gfx->move($render_end_x-300, $render_start_y-$unit_height * $cur_row_right);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		
		
		# var1
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var1_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance1}.'');
		$vehicule_column_count += $var1_units_count;

		# var2
		$gfx->poly(
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * $cur_row_right,
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row_right - 2)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var2_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance2}.' + '.$array_of_notes->[0]->{prime2}.'');
		$vehicule_column_count += $var2_units_count;
	  
		# var3
		$gfx->poly(
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * $cur_row_right,
		$render_start_x + $vehicule_column_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row_right - 2)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + $vehicule_column_count * $unit_width + ($var3_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('d * '.$array_of_notes->[0]->{distance3}.'');
		$cur_row_right += 1;
		# Total KM
		$text->translate($render_start_x + 58 * $unit_width + (43.5 * $unit_width/2), $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center(''.($array_tblndf_detail->[0]->{total_quantite}|| '0').' kilomètres dans cette note VS '.($array_count_detail || '0').' kilomètres cumulés en '.$r->pnotes('session')->{fiscal_year}.'');

		#Formule des frais kilométriques de ce véhicule en 2022
		############## INFO VEHICULE DROITE ##############
	} 

	#for my $line (split /\n+/, $summary) {
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com1} || ''));
	if ($array_of_notes->[0]->{com1}) {
	$cur_row_left += 1;
	}
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com2} || ''));
	if ($array_of_notes->[0]->{com2}) {
	$cur_row_left += 1;
	}
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text(($array_of_notes->[0]->{com3} || ''));
	if ($array_of_notes->[0]->{com3}) {
	$cur_row_left += 1;
	}
 
	############## INFO TIERS GAUCHE ##############
	# Ligne TOP
	#$gfx->move($render_start_x+135, $render_start_y-$unit_height * $cur_row);
	#$gfx->hline($render_end_x-135);
	#$gfx->linewidth(4);
	#$gfx->stroke;
	#$cur_row += 2;
	# background 1ère Ligne Decoration en tête
	$gfx->rectxy(
	  $render_start_x, $render_start_y-$unit_height * $cur_row,
	  $render_end_x, $render_start_y-$unit_height * ($cur_row + 1)
	);
	$gfx->fillcolor('# eee');
	$gfx->fill;

	# 1ère Ligne Decoration en tête 
	$gfx->move($render_start_x, $render_start_y-$unit_height * $cur_row);
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_bold);
	$gfx->strokecolor($color_black);
	$gfx->stroke;
	$cur_row += 1;

	# Save the position of the thick line under the quotation heading
	my $header_bottom_line_row = $cur_row;
	my $cur_column_units_count = 0;

	############## ENTÊTE TABLEAU ##############
	# Date
	my $date_units_count = 8;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($date_units_count * $unit_width/3), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Date');
	$cur_column_units_count += $date_units_count;
	# Dépense
	my $depense_units_count = 30;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($depense_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_center('Dépense');
	$cur_column_units_count += $depense_units_count;
	# Libellé
	my $libelle_units_count = 44;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($libelle_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_center('Libellé');
	$cur_column_units_count += $libelle_units_count;
	# Baréme
	my $bareme_units_count = 6;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_center('Baréme');
	$cur_column_units_count += $bareme_units_count;
	# KM
	my $km_units_count = 5;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_center('KM');
	$cur_column_units_count += $km_units_count;
	# Montant
	my $montant_units_count = 7;
	$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($montant_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_center('Montant');
	$cur_column_units_count = 0;
	############## ENTÊTE TABLEAU ##############

	$cur_row ++;
	# NOMBRE LIGNE TABLEAU
	my $rows_count = 20;
	
	#split les resultats de la requête
	my $numberofarrays = 20;
	my @new = split_by($numberofarrays,@$array_tblndf_detail);
	
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => nb de valeur scalar: '. scalar(@new).' et datadumper '. scalar(@$array_tblndf_detail).' <hr> et datadumper 1' . Data::Dumper::Dumper($new[1]) . ' <hr> et datadumper 2' . Data::Dumper::Dumper($new[2]) . '');

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => valeur scalar(@$array_tblndf_detail): '. scalar(@$array_tblndf_detail) );

	############## RECUPERATION RESULTAT REQUETE ##############
	for (my $row = 0; $row < $rows_count; $row ++) {
		my $book = $array_tblndf_detail->[$row];
		  
		# Lines are painted alternately
		if ($row % 2 == 1) {
			$gfx->rectxy(
			$render_start_x,
			$render_start_y-$unit_height * $cur_row,
			$render_end_x,
			$render_start_y-$unit_height * ($cur_row - 1),
			);
			$gfx->fillcolor('# eee');
			$gfx->fill;
		}
		  
		# Date
		if ($book) {
			$text->translate(
			  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
			  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text($book->{frais_date});
		}
		$cur_column_units_count += $date_units_count;

		# Dépense
		$gfx->poly(
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		if ($book) {
			$text->translate(
			$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
			$render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text(substr((($book->{frais_compte} || '') . ' - '. ($book->{libelle_compte} || '')), 0, 54 ));
		}
		$cur_column_units_count += $depense_units_count;

		# Libellé
		$gfx->poly(
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		if ($book) {
			$text->translate(
			$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
			$render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text_justified(substr( $book->{frais_libelle}, 0, 64));
		}
		$cur_column_units_count += $libelle_units_count;

		# Baréme
		$gfx->poly(
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		if ($book) {
			$text->translate(
			$render_start_x + $cur_column_units_count * $unit_width + ($bareme_units_count * $unit_width)-$text_left_padding,
			$render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text_right($book->{frais_bareme});
		}
		$cur_column_units_count += $bareme_units_count;
		  
		# KM
		$gfx->poly(
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		if ($book) {
			$text->translate(
			$render_start_x + $cur_column_units_count * $unit_width + ($km_units_count * $unit_width)-$text_left_padding,
			$render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text_right($book->{frais_quantite});
		}
		$cur_column_units_count += $km_units_count;

		# Montant
		$gfx->poly(
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + $cur_column_units_count * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		if ($book) {
			$text->translate(
			$render_start_x + $cur_column_units_count * $unit_width + ($montant_units_count * $unit_width)-$text_left_padding,
			$render_start_y-$unit_height * $cur_row + $text_bottom_padding
			);
			$text->font($font, $font_size_tableau);
			$text->text_right($book->{frais_montant}.' €');
		}
		  $cur_column_units_count = 0;

		  $cur_row ++;
	}
	
	############## RECUPERATION RESULTAT REQUETE ##############
	# 2ème Ligne décoration En tête
	$gfx->move($render_start_x, $render_start_y-$unit_height * $header_bottom_line_row);
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_bold);
	$gfx->strokecolor($color_black);
	$gfx->stroke;

	# Ligne épaisse Séparation Total
	$gfx->move($render_start_x, $render_start_y-$unit_height * ($cur_row - 1));
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_bold);
	$gfx->strokecolor($color_black);
	$gfx->stroke;

	# TOTAL1
	my $price_total_no_tax_label = 'TOTAL';
	#$text->translate($render_start_x + ($date_units_count + $depense_units_count + $libelle_units_count + $bareme_units_count) * $unit_width + $text_left_padding, $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->translate($render_start_x + ($date_units_count + $depense_units_count + $libelle_units_count + $bareme_units_count) * $unit_width + ($km_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font_bold, $font_size_default);
	$text->text_center($price_total_no_tax_label);
	$text->translate($render_end_x, $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font_bold, $font_size_default);
	$text->text_right($array_tblndf_detail->[0]->{total_montant}.' €');
	$cur_row += 0;


	# Add a page to the end of the document
	#$page = $pdf->page();

	#Requête info NDF frais en cours
	$sql = '
	SELECT distinct ON(t1.frais_doc) t1.frais_doc, t3.fiscal_year as doc_year, t1.id_client,  t1.fiscal_year,  t1.piece_ref,  t1.frais_date,  t1.frais_compte, t2.libelle_compte, t1.frais_libelle,  t1.frais_bareme,  t1.frais_quantite,  to_char(t1.frais_montant/100::numeric, \'999G999G999G990D00\') as frais_montant, (sum( t1.frais_quantite) over())::integer as total_quantite, to_char((sum( t1.frais_montant) over())/100::numeric, \'999G999G999G990D00\') as total_montant,  t1.frais_line
	FROM tblndf_detail t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.frais_compte = t2.numero_compte
	INNER JOIN tbldocuments t3 ON t1.id_client = t3.id_client AND t1.frais_doc = t3.id_name
	WHERE piece_ref = ?';
	my $result_ndf_doc = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, $args->{piece_ref} ) ;
	
	for (@$result_ndf_doc) {

		#définition répertoire du pdf à récupérer
		my $base_dir = $r->document_root() . '/Compta/base/documents/' ;
		my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$_->{doc_year}. '/' ;
		my $pdf_file = $archive_dir . $_->{frais_doc};
		my $input_pdf = PDF::API2->open($pdf_file);
		my @pages = 1 .. $input_pdf->pages;
		my $frais_date = $_->{frais_date} ;
		my $frais_compte = $_->{frais_compte} ;
		my $libelle_compte = $_->{libelle_compte} ;
		my $frais_libelle = $_->{frais_libelle} ;
		my $count = 0;
		
		if ( scalar @pages > 0 ) {

            foreach ( @pages ) {
				
				my $page = $pdf->importpage($input_pdf, $_, 0);
				
				# détection format de la page
				(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;
				
				my $render_start_y_page = $ury - 1 - $page_top_margin;
				my $render_end_x_page = $urx - 1 - $page_right_margin;
				
				my $txt = $page->text;
				
				$txt->strokecolor('#000000');
				$txt->translate($render_end_x_page, 18);
				$txt->font($font, 8);
				$txt->text_right(''.$frais_date.' : '.$frais_compte.' - '.$libelle_compte.' : '.$frais_libelle.'' );
				#$txt->textlabel($urx-100, $ury-30, $pdf->corefont('Arial'), 12, 'a text here');
            }
        }

	}

	# HEADER ET FOOTER
	foreach my $pagenum (1 .. $pdf->pages) {

		my $page = $pdf->openpage($pagenum);
		my $font = $pdf->corefont('Helvetica');
		
		# détection format de la page
		(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;
		my $render_end_x_page = $urx - 1 - $page_right_margin;
		
		#count nb pages
		my $pages = $pdf->pages;
		my $totalpages += $pages;
		
		# add page number text
		my $txt = $page->text;
		
		#$txt->textlabel($urx-100, $ury-30, $pdf->corefont('Arial'), 12, 'a text here');
		
		$txt->strokecolor('#000000');
		$txt->translate($render_end_x_page, 28);
		$txt->font($font, 8);
		$txt->text_right( 'page '.$pagenum.' / '.$totalpages.'' );
  
	}

	#Enregistrer le pdf
	my $file = '/Compta/images/pdf/print.pdf';
	my $pdf_file = $r->document_root() . $file;
	$pdf->saveas($pdf_file);

	return $file ;

}#sub export_pdf3

#/*—————————————— Fonction split array ——————————————*/
sub split_by {
	my ($num, @arr) = @_;
	my @sub_arrays;

	while (@arr) {
		push(@sub_arrays, [splice @arr, 0, $num]);
	}

	return @sub_arrays;
}#sub split_by

#/*—————————————— Modéle page NDF ——————————————*/
sub _add_pdf_page {
	# définition des variables
	my ( $r, $args, $pdf ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper($args) . ' ');

    ############## Récupérations d'informations ##############
	#Requête des informations concernant la note de frais
	$sql = '
	SELECT t1.piece_ref, t1.piece_date, t1.piece_compte, t2.libelle_compte, t1.piece_libelle, t1.piece_entry, t5.id_facture, t1.id_vehicule, t1.com1, t1.com2, t1.com3, t3.vehicule, t3.vehicule_name, t3.puissance,  COALESCE(t3.electrique,false) as electrique, COALESCE(t4.distance1,0) as distance1, COALESCE(t4.distance2,0) as distance2, COALESCE(t4.distance3,0) as distance3, COALESCE(t4.prime2,0) as prime2
	FROM tblndf t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.piece_compte = t2.numero_compte
	LEFT JOIN tblndf_vehicule t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.id_vehicule = t3.id_vehicule
	LEFT JOIN tblndf_bareme t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t3.vehicule = t4.vehicule AND t3.puissance = t4.puissance
	LEFT JOIN (SELECT DISTINCT ON(id_entry) id_entry, id_client, fiscal_year, id_facture FROM tbljournal) t5 ON t1.id_client = t5.id_client AND t1.fiscal_year = t5.fiscal_year AND t1.piece_entry = t5.id_entry
	WHERE t1.id_client = ? AND t1.fiscal_year = ? and t1.piece_ref = ?
	ORDER BY piece_ref' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{piece_ref}) ;	
    my $array_of_notes = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    #Récupérations des informations de la société
    $sql = 'SELECT etablissement, siret, date_debut, date_fin, padding_zeroes, fiscal_year_start, id_tva_periode, id_tva_option, adresse_1, code_postal, ville, journal_tva FROM compta_client WHERE id_client = ?' ;
    my $parametre_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
	
    #$pdf->mediabox('A4'); => Format A4
	#$pdf->mediabox(595, 842); => format A4 portrait Unite points
	#format A4 paysage landscape
	$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 48;
	my $page_bottom_margin = 48;
	my $page_left_margin = 48;
	my $page_right_margin = 48;
	#Définition des coordonnées de départ et de fin x et y
	my $render_start_x = $page_left_margin;
	my $render_start_y = $page_height - 1- $page_top_margin;
	my $render_end_x = $page_width - 1- $page_right_margin;
	my $render_end_y = $page_bottom_margin;

	my $font = $pdf->corefont('Helvetica');
	my $font_bold = $pdf->corefont('Helvetica-Bold');
	# Font size-default
	my $font_size_default = 10;
	my $font_size_tableau = 9;
	# Format Tableau
	# Set the minimum unit of height and width, the minimum unit of width is divided into 100
	my $unit_height = 14;
	my $unit_width = ($render_end_x-$render_start_x)/100;
	# Text drawing padding
	my $text_bottom_padding = 3;
	my $text_left_padding = 3;

    my $page = $pdf->page();
    
    # Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor('#000');
	$text->fillcolor('#000');

	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 12;
	my $cur_row_left = 0;
	my $cur_row_right = 0;
	my $cur_row_middle = -0.5;

	############## TITRE MIDDLE ##############
	# Top thick line
	$gfx->move($render_start_x+285, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$gfx->hline($render_end_x-285);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 1.5;
	# Titre
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font_bold, 20);
	$text->text_center('Note de frais');
	$cur_row_middle += 1;
	# Titre piece_ref
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font, 10);
	$text->text_center($array_of_notes->[0]->{piece_ref});
	$cur_row_middle += 0.25;
	# Top thick line
	$gfx->move($render_start_x+285, $render_start_y-$unit_height * $cur_row_middle);
	$gfx->hline($render_end_x-285);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 0.5;
	############## TITRE MIDDLE ##############

	############## INFO SOCIETE DROITE ##############
	# piece_date et id_facture
	$text->translate($render_start_x + 87.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Date : '.$array_of_notes->[0]->{piece_date});
	$cur_row_right += 1;
	$text->translate($render_start_x + 87.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Pièce: '.($array_of_notes->[0]->{id_facture} || ''));
	$cur_row_right += 5;
	############## INFO SOCIETE DROITE ##############

	############## INFO SOCIETE GAUCHE ##############
	# etablissement
	my $sender_company_name = ''.$parametre_set->[0]->{etablissement} . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_company_name);
	$cur_row_left += 1;
	# Adresse
	my $sender_addr = '' . ($parametre_set->[0]->{adresse_1} || '') . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_addr);
	$cur_row_left += 1;
	# code postale
	my $sender_zip_code = '' . ($parametre_set->[0]->{code_postal} || ''). ' ' . ($parametre_set->[0]->{ville} || '').'';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_zip_code);
	$cur_row_left += 1;
	# Siret
	my $sender_siret = 'SIRET : ' . $parametre_set->[0]->{siret} . '';
	$text->translate(
	  $render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_siret);
	$cur_row_left += 3;
	############## INFO SOCIETE GAUCHE ##############

    return $page;
}#sub _add_pdf_page

#/*—————————————— Menu Notes de Frais ——————————————*/
sub display_menu_ndf {
	
	#########################################	
	#définition des variables				#
	#########################################
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my $content ;

	#########################################	
	#définition des liens					#
	#########################################
	#lien vers la catégorie "Toutes les notes de frais"
	my $all_notes_class = defined $args->{piece_ref} || ((!defined $args->{vehicule}) && (!defined $args->{baremekm})) ? 'linavselect' : 'linav';
	my $all_notes_link = '<li><a class=' . $all_notes_class  . ' href="/'.$r->pnotes('session')->{racine}.'/notesdefrais">Gestion des notes de frais</a></li>' ;
	
	#lien vers la gestion Type de frais
	my $types_frais_class = ( defined $args->{types_frais} && !defined $args->{piece_ref}) ? 'linavselect' : 'linav' ;
	my $types_frais_link = '<li><a class='.$types_frais_class.' href="/'.$r->pnotes('session')->{racine}.'/notesdefrais?types_frais=0" >Types de frais</a></li>' ;
		
	#lien vers la gestion Véhicule
	my $vehicule_class = ( defined $args->{vehicule} && !defined $args->{piece_ref}) ? 'linavselect' : 'linav' ;
	my $vehicule_link = '<li><a class='.$vehicule_class.' href="/'.$r->pnotes('session')->{racine}.'/notesdefrais?vehicule" >Véhicule</a></li>' ;
		
	#lien vers Employés & Associés
	my $tiers_class = ( defined $args->{tiers} && !defined $args->{piece_ref}) ? 'linavselect' : 'linav' ;
	my $tiers_link = '<li><a class='.$tiers_class.' href="/'.$r->pnotes('session')->{racine}.'/notesdefrais?tiers" >Employés & Associés</a></li>' ;
		
	#lien vers Barème kilométrique
	my $baremekm_class = ( defined $args->{baremekm} && !defined $args->{piece_ref}) ? 'linavselect' : 'linav' ;
	my $baremekm_link = '<li><a class='.$baremekm_class.' href="/'.$r->pnotes('session')->{racine}.'/notesdefrais?baremekm" >Barème kilométrique</a></li>' ;
		

	#########################################	
	#génération du menu						#
	#########################################
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '<div class="menu"><ul class="main-nav2">' . $all_notes_link . $vehicule_link . $baremekm_link .'</ul></div>' ;
	} else {
	$content .= '<div class="menu"><ul class="main-nav2"></ul></div>' ;
	}

    return $content ;

} #sub display_menu_ndf 

1 ;
