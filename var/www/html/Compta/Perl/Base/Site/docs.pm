package Base::Site::docs;
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

use strict; 		 	# Utilisation stricte des variables
use warnings;  			# Activation des avertissements
use utf8;             	# Encodage UTF-8 pour le script
use Encode;           	# Encodage de caractères
# Modules externes utilisés dans le script
use Base::Site::util;  	# Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   	# Interaction avec la base de données (SQL)
use Apache2::Upload;   	# Gestion des téléchargements de fichiers
use Apache2::Request;  	# Traitement des requêtes HTTP pour Apache
use Apache2::Const -compile => qw( OK REDIRECT );  # Importation de constantes Apache
use File::Path 'mkpath' ;
use Time::Piece;       	# Manipulation de dates et heures
use PDF::API2;         	# Manipulation PDF
use IPC::Run3;         	# Exécution commandes externes (pdftotext)


#/*—————————————— Action principale ——————————————*/
sub handler {
    # Activation de la gestion de l'UTF-8 pour la sortie
    binmode(STDOUT, ":utf8");
    # Récupération de la requête Apache
    my $r = shift;
    # Utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    
    # Déclaration des variables
    my $content;
    my $req = Apache2::Request->new($r);

    # Récupération des paramètres de la requête
    my (%args, @args, $sql, @bind_values, $message);
    @args = $req->param;
    # Récupération de la connexion à la base de données depuis la session
    my $dbh = $r->pnotes('dbh');

    for (@args) {
		$args{$_} = Encode::decode_utf8( $req->param($_) ) ;
		# Prévention contre les attaques SQL injection et HTML code
		$args{$_} =~ tr/<>;/-/ ;
		# Prévention contre les problèmes avec les double-quotes et les <>
		$args{ $_ } =~ tr/<>"/'/ ;
    }
    
    if (defined $args{categorie}) {
        # Affichage du formulaire de catégorie
        $content = form_categorie($r, \%args);
    } elsif (defined $args{tag}) {
        # Affichage du formulaire de tags
        $content = form_tags($r, \%args);
    } elsif (defined $args{nouveau}) {
        # Affichage du formulaire de nouveaux documents
        $content = form_new_docs($r, \%args);
    } else {
        # Affichage de la visualisation par défaut
        $content .= visualize($r, \%args);
    }
	
	# Configuration de la réponse HTTP
    $r->no_cache(1);
    $r->content_type('text/html; charset=utf-8');
    # Envoi du contenu généré
    print $content;
    # Indication que la requête est terminée avec succès
    return Apache2::Const::OK;

}

#/*—————————————— Page principale des documents ——————————————*/
sub visualize {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $id_client = $r->pnotes('session')->{id_client} ;
	my @search = ('0') x 15;
	my @checked = ('0') x 10;
	my $line = "1"; 
	
	#Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);

    #les documents sont placés dans /var/www/html/Compta/base/documents/*id_client*/*fiscal_year*/
	my $repository = $r->document_root() . '/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$r->pnotes('session')->{fiscal_year} .'/';

	my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
	my @bind_array_2 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}, $args->{docscategorie}) ;

	#appliquer le filtre Catégorie si $args->{docscategorie}<>0
    my ($filter_categorie_dest) = (  $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/) ) ? (' AND t1.libelle_cat_doc = ?') : ( '', '' ) ;
    @bind_array = (  $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/)) ? (@bind_array_2) : (@bind_array_1) ;
   
    my $search_date = ( defined $args->{search_date} && $args->{search_date} ne '' && $args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) ? ' AND date_reception = ?' : '' ;
    my $search_montant = ( defined $args->{search_montant} && $args->{search_montant} ne '') ? ' AND t1.montant::TEXT ILIKE ? ' : '' ;
    my $search_categorie = ( defined $args->{search_categorie} && $args->{search_categorie} ne '' ) ? ' AND t1.libelle_cat_doc ILIKE ?' : '' ;
	my $search_name = ( defined $args->{search_name} && $args->{search_name} ne '' ) ? ' AND t1.id_name ILIKE ?' : '' ;
	my $search_check = ( defined $args->{search_check} && $args->{search_check} eq 1) ? ' AND t1.check_banque = \'t\'' : '' ;
    my $search_multi = ( defined $args->{search_multi} && $args->{search_multi} eq 1) ? ' AND t1.multi = \'t\'' : '' ;
    
    # Obtenez les tags actuels à partir de $args->{tags}
	my @current_tags = defined $args->{tags} ? split /,/, $args->{tags} : ();
	# Construisez la clause WHERE pour la requête PostgreSQL
	my $search_tags = '';
	my $count_tags = 0;
	my $having_tags = '';
	my $inner_tags = '';
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
		$inner_tags = 'INNER JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client and t1.id_name = t2.tags_doc';
		$string_tags = ', (SELECT STRING_AGG(tags_nom, \', \') FROM tbldocuments_tags WHERE tags_doc = t1.id_name) AS tags';
	}
    
	#Requête tbldocuments => Recherche de la liste des documents enregistrés
	$sql = '
	SELECT t1.id_name, t1.date_reception, t1.multi, t1.check_banque, to_char(t1.montant/100::numeric, \'999G999G999G990D00\') as montant, t1.libelle_cat_doc, t1.fiscal_year, to_char((sum(t1.montant) over()) / 100.0, \'999G999G999G990D00\') as total_montant 
	FROM tbldocuments t1
	'. $inner_tags .'
	WHERE t1.id_client = ? AND (t1.fiscal_year = ? OR (t1.multi = \'t\' AND (t1.last_fiscal_year IS NULL OR t1.last_fiscal_year >= ?))) '.$filter_categorie_dest.' '.$search_date.' '.$search_montant.' '.$search_categorie.' '.$search_name.' '.$search_check.' '.$search_multi.' '.$search_tags.'
	GROUP BY t1.id_name, 
         t1.date_reception, 
         t1.multi, 
         t1.check_banque, 
         t1.montant, 
         t1.libelle_cat_doc, 
         t1.fiscal_year
	'. $having_tags .'
	ORDER BY t1.date_reception, t1.id_name
	' ;
	
	#Filtrage
	if (defined $args->{search_date} && $args->{search_date} ne '' && $args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) {
	$search[9] = $args->{search_date};
	push @bind_array, $search[9] unless ( $args->{search_date} eq '') ;
	}
	
	if (defined $args->{search_date} && $args->{search_date} ne '' && not($args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/)) {
	$search[10] = '%' . $args->{search_date} . '%' ;
	push @bind_array, $search[10] unless ( $args->{search_date} eq '') ;
	}
	
	if (defined $args->{search_montant} && $args->{search_montant} ne ''){
	$search[4] = '%' . $args->{search_montant} . '%' ;
	push @bind_array, $search[4] unless ( $args->{search_montant} eq '') ;
	}
	
	if (defined $args->{search_categorie} && $args->{search_categorie} ne ''){
	$search[5] = '%' . $args->{search_categorie} . '%' ;
	push @bind_array, $search[5] unless ( $args->{search_categorie} eq '') ;
	}
  
  	if (defined $args->{search_name} && $args->{search_name} ne ''){
	$search[5] = '%' . $args->{search_name} . '%' ;
	push @bind_array, $search[5] unless ( $args->{search_name} eq '') ;
	}
	
	if (defined $args->{search_check} && $args->{search_check} eq 1){
	$checked[1] = 'checked';
	} else {
	$checked[1] = '';
	}
	
	if (defined $args->{search_multi} && $args->{search_multi} eq 1){
	$checked[2] = 'checked';
	} else {
	$checked[2] = '';	
	}
	
	if (defined $args->{tags} && $args->{tags} ne ''){
	push @bind_array, @placeholders unless ( $args->{tags} eq '') ;
	}		
	
	my $array_of_documents;	

    eval { $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )} ;
    
    ################ Affichage MENU ################
	$content .= display_menu_docs( $r, $args, $array_of_documents) ;
	################ Affichage MENU ################

	#/************ ACTION DEBUT *************/

	#######################################################################  
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	####################################################################### 
    if ( defined $args->{supprimer} and $args->{supprimer} eq '0' ) {
		
		my $message2 = 'Voulez-vous supprimer supprimer le document ' . $args->{id_name} .' ?' ;

		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'supprimer', $args->{supprimer}, $hidden_fields, 1);
		$content .= Base::Site::util::generate_error_message($confirmation_message);

    } elsif ( defined $args->{supprimer} and $args->{supprimer} eq '1' ) {
		
		$content .= Base::Site::util::verify_and_delete_document($dbh, $r, $args, 1);

	} #	if ( defined $args{supprimer} and $args{supprimer} eq '1' )

    ############## MISE EN FORME DEBUT ##############
    
	############## Formulaire Liste des documents ##############	
	my $entry_list .= '
		<li class="listitem3 centrer">
		<div class="spacer"></div>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 10%;">Date</span>
		<span class=headerspan style="width: 55%;">Nom</span>
		<span class=headerspan style="width: 14%;">Catégorie</span>
		<span class=headerspan style="width: 10%;">Montant</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<div class="spacer"></div>
		</li>
		
		<li class="style1"><div class=headerspan2 style="padding-left: 0px;">  
		<form id="myForm" method=POST>
		<div class=spacer></div>
		<span class=displayspan_search style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan_search style="width: 10%;"><input class=search type=text name="search_date" id="search_date" value="' . ($args->{search_date} || ''). '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');submit()" ></span>
		<span class=displayspan_search style="width: 55%;"><input class=search type=text name="search_name" id="search_name" value="' . ($args->{search_name} || ''). '" onchange="submit()"></span>
		<span class=displayspan_search style="width: 14%;"><input class=search type=text name="search_categorie" id="search_categorie" value="' . ($args->{search_categorie} || ''). '" onchange="submit()" onclick="liste_search_cat_doc(this.value)" list="catdoclist"><datalist id="catdoclist"></datalist></span>
		<span class=displayspan_search style="width: 10%; text-align: right;"><input class=search type=text name="search_montant" id="search_montant" value="' . ($args->{search_montant} || ''). '" onchange="submit()"></span>
		<span class=displayspan_search style="width: 2%;">&nbsp;</span>
		<span class=displayspan_search style="width: 2%; text-align: center;"></span>
		<span class=displayspan_search style="width: 2%; text-align: center;"></span>
		<span class=displayspan_search style="width: 2%; text-align: center;"><input type=checkbox name="search_check" id="search_check" title="Afficher les documents pointés" value=1  onchange="submit()" '.$checked[1].'></span>
		<span class=displayspan_search style="width: 2%; text-align: center;"><input type=checkbox name="search_multi" id="search_multi" title="Afficher les documents multi-exercice" value=1  onchange="submit()" '.$checked[2].'></span>
		<span class=displayspan_search style="width: 0.5%;">&nbsp;</span>
		<div class=spacer></div>
		</form></div></li>
	' ;

    if ( @{ $array_of_documents } ) {
		
		for ( @{ $array_of_documents } ) {
			my $reqline = ($line ++);
			
			my $get_last_email_event_date = Base::Site::bdd::get_last_email_event_date($dbh, $r, $_->{id_name});
			my $statut = '<span class=displayspan style="width: 1.75%; text-align: center;"><img id="email_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Envoyer le document par mail" src="/Compta/style/icons/encours.png" alt="email"></span>';

			if ($get_last_email_event_date){
				my $event_description = $get_last_email_event_date->{event_description};
				my $event_date = $get_last_email_event_date->{event_date};
				$statut = '<span class="displayspan" style="width: 1.75%; text-align: center;"><img id="email_'.$reqline.'" title="'.$event_description.' le '.$event_date.'" src="/Compta/style/icons/valider.png" height="16" width="16" alt="statut"></span>';
			}	
			
			my $check_send_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . ( URI::Escape::uri_escape_utf8( $_->{id_name} ) || '' ) . '&email' ;
			my $check_send = '<a class=nav href="' . $check_send_href . '">'.$statut.'</a>';
			
			my $http_link_banque_valide = '<img class="redimmage nav" title="Validée le '. (defined $_->{date_validation}).'" style="border: 0;" src="/Compta/style/icons/cadena.png" alt="valide">' ;
			my $check_value = ( $_->{check_banque} eq 'f' ) ? '<span class="displayspan" style="width: 1.75%; text-align: center;"><img class="line_icon_hidden" id="statut_'.$reqline.'" title="Check complet" src="/Compta/style/icons/icone-valider.png" height="16" width="16" alt="check_value"></span>' : '<span class="displayspan" style="width: 2%; text-align: center;"><img id="statut_'.$reqline.'" title="Check complet" src="/Compta/style/icons/icone-valider.png" height="16" width="16" alt="check_value"></span>' ;
			my $check_multi = ( $_->{multi} eq 'f' ) ? '<span class="displayspan" style="width: 1.75%; text-align: center;"><img id="multi_'.$reqline.'" class="line_icon_hidden" title="documents multi-exercice" src="/Compta/style/icons/multi.png" height="16" width="16" alt="check_multi"></span>' : '<span class="displayspan" style="width: 2%; text-align: center;"><img id="multi_'.$reqline.'" title="documents multi-exercice" src="/Compta/style/icons/multi.png" height="16" width="16" alt="check_multi"></span>' ;

			#lien de modification de l'entrée
			my $id_name_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $_->{id_name} ;
			my $suppress_href = '';
			my $suppress_link = '<span class=blockspan style="width: 1.75%; text-align: center;"><img id="supprimer_'.$reqline.'" class="line_icon_hidden" height="16" width="16" title="Supprimer" src="/Compta/style/icons/delete.png" alt="supprimer"></span>';
			my $download_href = '/Compta/base/documents/' . $r->pnotes('session')->{id_client} . '/'.$_->{fiscal_year}.'/'. $_->{id_name}  ;
			my $img_link = '<a class=nav href="' . $download_href . '"><span class=blockspan style="width: 1.75%; text-align: center;"><img id="visualiser_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Visualiser le document" src="/Compta/style/icons/documents.png" alt="visualiser"></span></a>';
			
			if ($r->pnotes('session')->{Exercice_Cloture} ne 1 && $_->{multi} eq 'f') {
			$suppress_href = '/'.$r->pnotes('session')->{racine}.'/docs?docscategorie='.$args->{docscategorie}.'&amp;id_name=' . ( URI::Escape::uri_escape_utf8( $_->{id_name} ) || '' ) . '&amp;supprimer=0' ;
			$suppress_link = '<a class=nav href="' . $suppress_href . '"><span class=blockspan style="width: 1.75%; text-align: center;"><img id="supprimer_'.$reqline.'" class="line_icon_visible" height="16" width="16" title="Supprimer" src="/Compta/style/icons/delete.png" alt="supprimer"></span></a>';
			}
			
			#ligne d'en-têtes
			$entry_list .= '
				<li class=listitem3><a href="' . $id_name_href . '">
				<div class=spacer></div>
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<span class=blockspan style="width: 10%;">' . $_->{date_reception} . '</span>
				<span class=blockspan style="width: 55%;">' . ( $_->{id_name} || '&nbsp;' ) . '</span>
				<span class=blockspan style="width: 14%;">' . ( $_->{libelle_cat_doc} || '&nbsp;') . '</span>
				<span class=blockspan style="width: 10%; text-align: right;">' . ( $_->{montant} || '&nbsp;') . '</span>
				<span class=blockspan style="width: 1%;">&nbsp;</span>
				' . $check_send . '
				' . $img_link . '
				' . $suppress_link . '
				' . $check_value . '
				' . $check_multi . '
				<span class=blockspan style="width: 0.5%;">&nbsp;</span>
				<div class=spacer></div>
				</a></li>
			' ;
		}

		$entry_list .=  '
		<li class=style1 ><hr></li>
		<li class=style1 >
		<div class=spacer></div>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan style="width: 79%; text-align: right;">Total</span>
		<span class=displayspan style="width: 10%; text-align: right;">' . ( $array_of_documents->[0]->{total_montant} || 0 ) . '</span>
		<span class=displayspan style="width: 10%;">&nbsp;</span>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<div class=spacer></div>
		</li>' ;

		$content .= '<ul class=wrapper-docs>' . $entry_list . '</ul></main>' ;

	} else {

		#repository absent, aucun fichier n'a été créé
		$content .= '<ul class=wrapper-docs>' . $entry_list . '
		<li class=style1 ><hr></li>
		<li class=style1 >
		<div class=spacer></div>
		<span class=displayspan style="width: 100%; text-align: center;">'.Base::Site::util::generate_error_message('Aucun document enregistré').'</span>
		<div class=spacer></div>
		</li></ul></main>' ;


	} #    if ( @( $array_of_files ) )
	############## MISE EN FORME FIN ##############
		
} #sub visualize

#/*—————————————— Page Formulaire modification catégorie de document ——————————————*/
sub form_categorie {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $categorie_list ;
	$args->{restart} = 'docs?categorie';
	my $line = "1"; 
    
	################ Affichage MENU ################
	$content .= display_menu_docs( $r, $args ) ;
	################ Affichage MENU ################

	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' la catégorie		  #
	#######################################################################
	#1ère demande de suppression; afficher lien d'annulation/confirmation
    if ( defined $args->{categorie} && defined $args->{supprimer} && $args->{supprimer} eq '0' ) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/docs?categorie' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/docs?categorie&amp;supprimer=1&amp;libelle_cat_doc=' . ($args->{libelle_cat_doc} || '') ;
		my $message = 'Vraiment supprimer la catégorie ' . $args->{libelle_cat_doc} . '?<a href="' . $oui_href . '" class="button-link" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class="button-link" style="margin-left: 3ch;">Non</a>' ;
		$content .= Base::Site::util::generate_error_message($message);
	} elsif ( defined $args->{categorie} && defined $args->{supprimer} && $args->{supprimer} eq '1' ) {
		#demande de suppression confirmée
		$sql = 'DELETE FROM tbldocuments_categorie WHERE libelle_cat_doc = ? AND id_client = ?' ;
		@bind_array = ( $args->{libelle_cat_doc}, $r->pnotes('session')->{id_client} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {
			$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
			} elsif ( $@ =~ /toujours|referenced/ ) {
			$content .= '<h3 class=warning>Suppression impossible : la catégorie '.$args->{libelle_cat_doc}.' est encore utilisée dans un document </h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Suppression de la catégorie de document '.$args->{libelle_cat_doc}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' la catégorie		  #
	#######################################################################
    if ( defined $args->{categorie} && defined $args->{valide_doc} && $args->{valide_doc} eq '1' ) {
		#on interdit libelle vide
		$args->{libelle_cat_doc} ||= undef ;
	
	    #ajouter une catégorie
	    $sql = 'INSERT INTO tbldocuments_categorie (libelle_cat_doc, id_client) values (?, ?)' ;
	    @bind_array = ( $args->{libelle_cat_doc}, $r->pnotes('session')->{id_client} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>Il faut renseigner le nom de la nouvelle catégorie de document</h3>' ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= '<h3 class=warning>Cette catégorie existe déjà</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Ajout de la catégorie de document '.$args->{libelle_cat_doc}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
    }
    
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification de la catégorie #
	#######################################################################
    if ( defined $args->{categorie} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
	    
   	    #modifier une catégorie
	    $sql = 'UPDATE tbldocuments_categorie set libelle_cat_doc = ? where id_client = ? AND libelle_cat_doc = ? ' ;
	    @bind_array = ( $args->{new_libelle_cat_doc}, $r->pnotes('session')->{id_client}, $args->{old_libelle_cat_doc} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
    }
	
	#/************ ACTION FIN *************/
	
	############## MISE EN FORME DEBUT ##############

    $sql = 'SELECT libelle_cat_doc FROM tbldocuments_categorie WHERE id_client = ? order by libelle_cat_doc' ;

    my $categorie_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
	
    my $doc_list = '

    <fieldset  class="pretty-box"><legend><h3 class="Titre09">Gestion des catégories de documents</h3></legend>
    <div class=centrer>
    
        <div class=Titre10>Ajouter une nouvelle catégorie</div>
		<div class="form-int">
			<form method=POST action=/'.$r->pnotes('session')->{racine}.'/docs?categorie>
			<input class="login-text" type=text placeholder="Entrer le libellé de la catégorie" name="libelle_cat_doc" value="" style="width: 40ch;" required >
			<input type=hidden name="valide_doc" value=1>
			<input type=submit class="btn btn-vert" value=Ajouter style="width: 15%;">
			</form>
		</div>
    
		<br>
    
		<div class=Titre10>Modifier une catégorie existante</div>
		
    ' ;
    
    #ligne des en-têtes
    $doc_list .= '
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 30%; text-align: center;">Libellé</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
    
    for ( @$categorie_set ) {
		my $reqline = ($line ++);
		
		my $delete_href = 'docs&#63;categorie&amp;supprimer=0&amp;libelle_cat_doc=' . URI::Escape::uri_escape_utf8($_->{libelle_cat_doc}) ;
	
		my $delete_link = ( $_->{libelle_cat_doc} eq 'Temp' ) ? '<span class="blockspan" style="width: 4%; text-align: center;"></span>' : 
		'<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>' ;

		my $valid_href = 'docs&#63;categorie&amp;modifier=1&amp;old_libelle_cat_doc=' . URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) ;
		my $disabled = ( $_->{libelle_cat_doc} eq 'Temp' ) ? ' disabled' : '' ;
		
		$doc_list .= '
		<li id="line_'.$reqline.'" class="style1">  
		<form class=flex1 method=POST action=/'.$r->pnotes('session')->{racine}.'/docs?categorie>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 30%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name=new_libelle_cat_doc value="' . $_->{libelle_cat_doc} . '" ' . $disabled . ' /></span>
		<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider" '.$disabled.'></span>
		'.$delete_link.'
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		</form>
		</li>
		' ;
	}
    
    $doc_list .= '</ul></fieldset>';
		
	$content .= '<div class="formulaire2">' . $doc_list . '</div>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_categorie 

#/*—————————————— Page Formulaire modification tags de document ——————————————*/
sub form_tags {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content, $categorie_list, $erreur ) ;
	$args->{restart} = 'docs?tag';
	my $line = "1"; 
	my $reqid = Base::Site::util::generate_reqline();
	
	#Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
    
	################ Affichage MENU ################
	$content .= display_menu_docs( $r, $args ) ;
	################ Affichage MENU ################

	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	#1ère demande de suppression; afficher lien d'annulation/confirmation
    if ( defined $args->{tag} && defined $args->{supprimer} && $args->{supprimer} eq '0' ) {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/docs?tag' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/docs?tag&amp;supprimer=1&amp;tags_nom=' . ($args->{tags_nom} || '') ;
		my $message = 'Voulez-vous supprimer le tag ' . $args->{tags_nom} . '?<a href="' . $oui_href . '" class="button-link" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class="button-link" style="margin-left: 3ch;">Non</a>' ;
		$content .= Base::Site::util::generate_error_message($message);
	} elsif ( defined $args->{tag} && defined $args->{supprimer} && $args->{supprimer} eq '1' ) {
		#demande de suppression confirmée
		$sql = 'DELETE FROM tbldocuments_tags WHERE tags_nom = ? AND id_client = ?' ;
		@bind_array = ( $args->{tags_nom}, $r->pnotes('session')->{id_client} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {
			$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
			} elsif ( $@ =~ /toujours|referenced/ ) {
			$content .= '<h3 class=warning>Suppression impossible : le tag '.$args->{tags_nom}.' est encore utilisé dans un document </h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Suppression du tag de document '.$args->{tags_nom}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{tag} && defined $args->{add_tag} && $args->{add_tag} eq '1' ) {
		
		my $lib = $args->{tags_nom} || undef ;
		Base::Site::util::formatter_libelle(\$lib);

		if (defined $args->{tags_nom} && $lib eq '') {
			$content .= Base::Site::util::generate_error_message('Impossible le nom du tag est vide !');
		} elsif ((defined $args->{tags_doc} && $args->{tags_doc} eq '') || !defined $args->{tags_doc}) {
			$content .= Base::Site::util::generate_error_message('Impossible il faut sélectionner un document !');
		} else {
	
	    #ajouter une catégorie
	    $sql = 'INSERT INTO tbldocuments_tags (tags_nom, tags_doc, id_client) values (?, ?, ?)' ;
	    @bind_array = ( $args->{tags_nom}, $args->{tags_doc}, $r->pnotes('session')->{id_client} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut renseigner le nom du nouveau tag de document') ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Le tag "'.$args->{tags_nom}.'" existe déjà pour ce document') ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Ajout du tag "'.$args->{tags_nom}.'" pour le document '.$args->{tags_doc}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
		}
    }
  
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'supprimer le tag'		  	  #
	#######################################################################
    if ( defined $args->{tag} && defined $args->{supprimer_tag} && $args->{supprimer_tag} eq '0' ) {
		my @delete_tags = defined $args->{del_tags} ? split /,/, $args->{del_tags} : ();
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/docs?tag' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/docs?tag&amp;supprimer_tag=1&amp;tags_nom=' . ($delete_tags[0] || '').'&amp;tags_doc=' . ($delete_tags[1] || '') ;
		my $message = 'Voulez-vous supprimer le tag ' . $delete_tags[0] . ' du document ' . $delete_tags[1] . ' ?<a href="' . $oui_href . '" class="button-link" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class="button-link" style="margin-left: 3ch;">Non</a>' ;
		$content .= Base::Site::util::generate_error_message($message);
	} elsif ( defined $args->{tag} && defined $args->{supprimer_tag} && $args->{supprimer_tag} eq '1' ) {
		#demande de suppression confirmée
		$sql = 'DELETE FROM tbldocuments_tags WHERE tags_nom = ? AND id_client = ? AND tags_doc = ?' ;
		@bind_array = ( $args->{tags_nom}, $r->pnotes('session')->{id_client}, $args->{tags_doc} ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {
			$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
			} elsif ( $@ =~ /toujours|referenced/ ) {
			$content .= '<h3 class=warning>Suppression impossible : le tag '.$args->{tags_nom}.' est encore utilisé dans un document </h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Suppression du tag "'.$args->{tags_nom}.'" du document '.$args->{tags_doc}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
    }
     
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification de la catégorie #
	#######################################################################
    if ( defined $args->{tag} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
		
		my $lib = $args->{new_tags_nom} || undef ;
		Base::Site::util::formatter_libelle(\$lib);
	    
   	    #modifier une catégorie
	    $sql = 'UPDATE tbldocuments_tags set tags_nom = ? where id_client = ? AND tags_nom = ? ' ;
	    @bind_array = ( $lib, $r->pnotes('session')->{id_client}, $args->{old_tags_nom} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>le nom ne peut être vide</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé	
		}
    }
	
	#/************ ACTION FIN *************/
	
	############## MISE EN FORME DEBUT ##############

    $sql = 'SELECT DISTINCT tags_nom FROM tbldocuments_tags WHERE id_client = ? order by tags_nom' ;
    my $tags_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
    
    # Génération formulaire choix de documents
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $onchange_type = 'onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};"';
	my ($form_name_doc1, $form_id_doc1) = ('tags_doc', 'tags_doc_'.$reqid.'');
	my $selected_document1 = (defined($args->{tags_doc}) && $args->{tags_doc} ne '') || (defined($args->{id_name}) && defined($args->{label8}) && $args->{label8} eq '1') ? ($args->{tags_doc} || $args->{id_name}) : undef;
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected_document1, $form_name_doc1, $form_id_doc1, $onchange_type, 'class=respinput', '');
	
	my $info_tags = Base::Site::bdd::get_tags_documents($dbh, $r);
	my $onchange_tags = 'onchange="if(this.selectedIndex == 0){document.location.href=\'docs?tag\'};"';
	my $selected_tags = (defined($args->{lie_tags_nom}) && $args->{lie_tags_nom} ne '') ? ($args->{lie_tags_nom} ) : undef;
	my ($form_name_tags, $form_id_tags) = ('lie_tags_nom', 'lie_tags_nom_'.$reqid.'');
	my $search_tags = Base::Site::util::generate_tags_choix($info_tags, $reqid, $selected_tags, $form_name_tags, $form_id_tags, $onchange_tags, 'class="respinput"', 'required');
	
	#Requête tbldocuments => Recherche de la liste des documents enregistrés
	$sql = 'SELECT t1.id_name, t2.tags_nom FROM tbldocuments t1
	LEFT JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client and t1.id_name = t2.tags_doc
	WHERE t1.id_client = ? AND (t1.fiscal_year = ? OR (t1.multi = \'t\' AND (t1.last_fiscal_year IS NULL OR t1.last_fiscal_year >= ?))) AND t2.tags_nom is not null
	ORDER BY t1.date_reception, t1.id_name' ;
	my $array_of_documents_tags;	
	my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;
    eval { $array_of_documents_tags = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 )} ;
    my $tags_select = '<select class=respinput name=del_tags id=del_tags>
	<option value="" selected>--Sélectionner le tag--</option>' ;
	for ( @$array_of_documents_tags ) {
	$tags_select .= '<option value="' . $_->{tags_nom} . ',' . $_->{id_name} . '">' . $_->{tags_nom} . ' - ' . $_->{id_name} . '</option>' ;
	}
	$tags_select .= '</select>' ;
		
    my $tag_list = '
    <fieldset  class="pretty-box"><legend><h3 class="Titre09">Gestion des tags de documents</h3></legend>
    <div class=centrer>
    

        <div class=Titre10>Ajouter un nouveau tag</div>
		<form method=POST action=/'.$r->pnotes('session')->{racine}.'/docs?tag>
		<div class="respform" style="justify-content: center;">
			<div class="flex-25"><input class="respinput" type=text placeholder="Entrer ou sélectionner le nom du tag" name="tags_nom" value="" required onclick="liste_search_tag(this.value)" list="taglist"><datalist id="taglist"></datalist></span></div>
			<div class="flex-25">'.$document_select1.'</div>
			<input type=hidden name="add_tag" value=1>
			<div class="flex-21"><input type=submit class="respbtn btn-vert" value=Ajouter ></div>
		</div>
		</form>
		
		<div class=Titre10>Supprimer un tag d\'un document</div>
		<form method=POST action=/'.$r->pnotes('session')->{racine}.'/docs?tag>
		<div class="respform" style="justify-content: center;">
			<div class="flex-30">'.$tags_select.'</div>
			<input type=hidden name="supprimer_tag" value=0>
			<div class="flex-21"><input type=submit class="respbtn btn-vert" value=Supprimer ></div>
		</div>
		</form>
		
    ' ;
    
    #ligne des en-têtes
    $tag_list .= '
    	<div class=Titre10>Modifier un tag existant</div>
	</div>	
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 30%; text-align: center;">Nom du tag</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
    
    for ( @$tags_set ) {
		my $reqline = ($line ++);
		
		my $valid_href = 'docs&#63;tag&amp;modifier=1&amp;old_tags_nom=' . URI::Escape::uri_escape_utf8( $_->{tags_nom} ) ;
		my $disabled = ( $_->{tags_nom} eq 'Temp' ) ? ' disabled' : '' ;
		
		$tag_list .= '
		<li id="line_'.$reqline.'" class="style1">  
		<form class=flex1 method=POST action=/'.$r->pnotes('session')->{racine}.'/docs?tag>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 30%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name=new_tags_nom value="' . $_->{tags_nom} . '" ' . $disabled . ' /></span>
		<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider" '.$disabled.'></span>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		</form>
		</li>
		' ;
	}
    
    $tag_list .= '</ul></fieldset>';
		
	$content .= '<div class="formulaire2">' . $tag_list . '</div>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_categorie 

#/*—————————————— Page Formulaire nouveau document ——————————————*/
sub form_new_docs {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $req = Apache2::Request->new($r) ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $line = "1"; 
	$args->{restart} = 'docs?nouveau';
    
	################ Affichage MENU ################
	$content .= display_menu_docs( $r, $args ) ;
	################ Affichage MENU ################
	
	# Empêcher si l'exercice est clos
	if ($r->pnotes('session')->{Exercice_Cloture} eq '1') {
		return ($content .= Base::Site::util::bloquer_exercice_clos($r)) if Base::Site::util::bloquer_exercice_clos($r);
	}
	
	############## Formulaire Ajout d'un document ##############
	my $formlist .='
		<div class=Titre10>Ajout d\'un document</div>
			<div class="form-int">
				<form action="/'.$r->pnotes('session')->{racine}.'/docs" method=POST enctype="multipart/form-data">
					<label class="bold" for="recupdate">Récupérer date dans le nom du fichier au format yyyy_mm_dd ou dd_mm_yyyy ?</label>
					<input type="checkbox" style ="width : 19%;" id="recupdate" name="recupdate" value=1 checked>
					<br><br>
					 <input type="file" name="document" multiple>
					<input type=hidden name=nouveau value=1>
					<input type=hidden name=id_client value="' . $r->pnotes('session')->{id_client} . '">
					<input type=hidden name=fiscal_year value="'.$r->pnotes('session')->{fiscal_year}.'">
					<input type=submit class="btn btn-vert" value=Valider style ="width : 10%;">
				</form>
			</div>
	';
	
	#/************ ACTION DEBUT *************/
	
	################################################################       
	#l'utilisateur a envoyé un nouveau document à enregistrer	   #
	################################################################    
	if ( defined $args->{nouveau} and $args->{nouveau} eq '1'  ) {
	
	# récupération des fichiers uploadés
    my @uploads = $req->upload('document') ;
    my $doc_categorie = 'Temp';
    my $success = 1; # Indicateur de succès initialisé à vrai
    
	#envoi d'un fichier par l'utilisateur
	unless ( $args->{document} ) {
		#pas de fichier!
		$content .= '<h3 class=warning>Aucun fichier n\'a été sélectionné pour le téléchargement!</h3>' ;
	} else {

			
		 foreach my $upload (@uploads) {
			 
			my $upload_fh = $upload->fh() ;
			my $filename = $upload->filename;
			 
			# Ne conserver que l'extension pour le nom du fichier
			$filename =~ m/\.([^.]+)$/;  # Modification de la regex

			#on met en minuscule l'extension; s'il n'y en a pas, on met 'inconnu'; on supprime les caractères bizarres, non alphanumériques
			( $args->{extension} = lc( $1 || 'inconnu' ) ) =~ s/[^a-zA-Z0-9]//g ;
			
			my $utf8_filename = Encode::decode('utf8', $filename);  # Conversion en UTF-8


			
			
			my $doc_date = '';
			my $id_compte = '';
	
			#Requête tblconfig_liste
			$sql = 'SELECT config_libelle, config_compte, config_journal, module FROM tblconfig_liste WHERE id_client = ? AND module = \'documents\' ORDER by config_libelle' ;
			my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) );
			
			for ( @$resultat ) {
			if ( $utf8_filename =~ $_->{config_libelle}) { $doc_categorie = $_->{config_journal}; $id_compte = $_->{config_compte}} 
			}
	
			my $fmt1 = '(?<y>\d\d\d\d)_(?<m>\d\d)_(?<d>\d\d)';
			my $fmt2 = '(?<d>\d\d)_(?<m>\d\d)_(?<y>\d\d\d\d)';
		
			#vérification si une date au format yyyy-mm-dd est dans le nom du fichier et si recupdate est coché
			if ( $utf8_filename =~ m{$fmt2} && (defined $args->{recupdate} && $args->{recupdate} eq '1')){
				$doc_date =  "$+{y}-$+{m}-$+{d}\n";
			} elsif ( $utf8_filename =~ m{$fmt1} && (defined $args->{recupdate} && $args->{recupdate} eq '1') ){
				$doc_date =  "$+{y}-$+{m}-$+{d}\n";
			} else {
				#date par défaut du document=date du jour si pas de date fournie
				$doc_date = $dbh->selectall_arrayref('SELECT CURRENT_DATE')->[0]->[0] ;
			}
			
			#insertion dans la table
			$sql = 'INSERT INTO tbldocuments ( id_client, id_name, fiscal_year, libelle_cat_doc, date_reception, date_upload, id_compte ) VALUES ( ? , ? , ? , ?, ?, CURRENT_DATE, ?) RETURNING id_name' ;
			my $sth = $dbh->prepare($sql) ;
			my $insert_result = eval { $sth->execute( $args->{id_client}, $utf8_filename , $args->{fiscal_year}, $doc_categorie, $doc_date, $id_compte )};

			#afficher l'erreur si l'insertion ne se fait pas
			if ( $@ ) {
				if ( $@ =~ /existe|already exists|duplicate/ ) {
					$content .= '<h3 class=warning>Un document existe avec le même nom '.$utf8_filename.' - Enregistrement impossible</h3>' ;
				} else {
					$content .= '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">' . Encode::decode_utf8( $@ ) . '&'.$args->{id_client}.'&'.$utf8_filename.'&date'.$doc_date.'</h3>' ;
				}
				$success = 0; # Indicateur de succès mis à faux en cas d'erreur
			} else {

				#contient l'id_name document nouvellement enregistré
				my $returned_record = $sth->fetchrow_hashref ;

				$args->{id_client} =~ /(\d+)/ ;

				my $id_client = $1 ;
				my $archive_dir = '';
				
				my $base_dir = $r->document_root() . '/Compta/base/documents/' ;
				chdir $base_dir ;

				$archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/'.$r->pnotes('session')->{fiscal_year}. '/' ;

				unless ( -d $archive_dir ) {
				#créer archive_dir
				mkpath $archive_dir or die "can't do mkpath : $!" ;
				}

				#fichier de stockage = archive_dir/id_name.extension
				my $archive_file = $archive_dir . '/' .  $utf8_filename;
				
				open (my $fh, ">", $archive_file) or die "Impossible d'ouvrir le fichier $archive_file : $!" ;

				#récupération des données du fichier
				while ( my $data = <$upload_fh> ) {
				print $fh $data ;
				}

				close $fh ;

				#l'enregistrement s'est bien passé, on peut retourner à la liste des documents
				undef $args->{nouveau} ;
				
				my $event_type = 'Importation';
                my $event_description = 'Le document a été importé avec succès.';
                my $save_document_history = Base::Site::bdd::save_document_history($dbh, $r->pnotes('session')->{id_client}, $utf8_filename, $event_type, $event_description, $r->pnotes('session')->{username});
                
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Ajout du document '.$utf8_filename.' ');

			}

			}
			
			# Si tous les enregistrements ont été avec succès, effectuer la redirection
			if ($success) {
				$args->{restart} = 'docs?docscategorie=' . $doc_categorie;
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
	}

    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    elsif ( defined $args->{nouveau} && defined $args->{delete} ) {
		
		#1ère demande de suppression; afficher lien d'annulation/confirmation
		if ( defined $args->{nouveau} && defined $args->{delete} && $args->{delete} eq '0' ) {
			my $non_href = '/'.$r->pnotes('session')->{racine}.'/docs?nouveau' ;
			my $oui_href = '/'.$r->pnotes('session')->{racine}.'/docs?nouveau&amp;documents=1&amp;delete=1&amp;libelle=' . $args->{libelle} ;
			$content .= '<h3 class=warning>Vraiment supprimer la régle ' . $args->{libelle} . '?<a href="' . $oui_href . '" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" style="margin-left: 3ch;">Non</a></h3>' ;
		} elsif ( defined $args->{nouveau} && defined $args->{delete} && $args->{delete} eq '1' ) {
			#demande de suppression confirmée
			$sql = 'DELETE FROM tblconfig_liste WHERE config_libelle = ? AND id_client = ? AND module = \'documents\'' ;
			@bind_array = ( $args->{libelle}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>le libellé ne peut être vide</h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Suppression de la règle contenant le mot '.$args->{libelle}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}    	
	
	} #    if ( $args->{delete} ) 
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    elsif ( defined $args->{nouveau} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		#on interdit libelle vide
		$args->{libelle1} ||= undef ;
	
	    #ajouter une catégorie
	    $sql = 'INSERT INTO tblconfig_liste (config_libelle, config_compte, config_journal, id_client, module) values (?, ?, ?, ?, \'documents\')' ;
	    @bind_array = ( $args->{libelle1}, ($args->{select_compte} || undef), ($args->{select_journal} || undef), $r->pnotes('session')->{id_client} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>Il faut obligatoirement un libellé</h3>' ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= '<h3 class=warning>Ce libellé existe déjà</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Ajout de la règle contenant le mot '.$args->{libelle1}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
	 }
    
    ####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification de la catégorie #
	#######################################################################
    elsif ( defined $args->{nouveau} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
   	    #modifier une catégorie
	    $sql = 'UPDATE tblconfig_liste set config_libelle = ?, config_compte = ?, config_journal = ? where id_client = ? AND config_libelle = ? AND module = \'documents\'' ;
	    @bind_array = ( $args->{libelle}, $args->{select_compte}, $args->{select_journal}, $r->pnotes('session')->{id_client}, $args->{old_libelle} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>le libellé ne peut être vide</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'doc.pm => Modification de la règle contenant le mot '.$args->{libelle}.'');
   		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
	 }
	
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	##################################### 
	
	#Requête tblconfig_liste
	$sql = 'SELECT config_libelle, config_compte, config_journal, module FROM tblconfig_liste WHERE id_client = ? AND module = \'documents\' ORDER by config_libelle' ;
    my $resultat;
    eval {$resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) };
    
	#Requête catégories de documents
    $sql = 'SELECT libelle_cat_doc FROM tbldocuments_categorie WHERE id_client= ? ORDER BY libelle_cat_doc' ;
    @bind_array = ( $r->pnotes('session')->{id_client} ) ;
	my $journal_req = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
	
	#Formulaire Sélectionner une catégorie
	my $select_journal = '<select class="login-text" style="width: 25%;" name=select_journal id=select_journal1 required
	onchange="if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'}">' ;
	$select_journal .= '<option class="opt1" value="">Créer une catégorie</option>' ;
	$select_journal .= '<option value="" selected>--Sélectionner une catégorie--</option>' ;
	for ( @$journal_req ) {
	$select_journal .= '<option value="' . $_->[0] . '">' . $_->[0] . '</option>' ;
	}
	$select_journal .= '</select>' ;

	#Formulaire Sélectionner un compte
	$sql = 'SELECT numero_compte, libelle_compte FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND substring(numero_compte from 1 for 2) IN (\'51\',\'46\') ORDER BY 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $compte_req = $dbh->selectall_arrayref( $sql, { }, @bind_array ) ;
	my $select_compte = '<select class="login-text" style="width: 25%;" name=select_compte id=select_compte1
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}">' ;
	$select_compte .= '<option class="opt1" value="">Créer un compte</option>' ;
	$select_compte .= '<option value="" selected>--Sélectionner un compte--</option>' ;
	for ( @$compte_req ) {
	$select_compte .= '<option value="' . $_->[0] . '">' . $_->[0] . ' - ' .$_->[1].'</option>' ;
	}
	$select_compte .= '</select>' ;
		
	############## Formulaire ajout d'une règle automatique ##############	
	$formlist .='
			
		<div class=Titre10>Configuration des règles automatiques</div>
		<div class="form-int">
			<form method="post">
			<div class=formflexN2>
			<input class="login-text" style="width: 25%;" type=text placeholder="Valeur à rechercher" id=libelle name="libelle1" value="" required>
			' . $select_journal . '
			' . $select_compte . '
			<input type=hidden name="ajouter" value=1>
			<input type=hidden name=nouveau value=>
			<input type=submit class="btn btn-vert" style ="width : 10%;" value=Ajouter>
			</div>
			</form>
		</div>
		<hr>
	';	
	
	#ligne des en-têtes
    $formlist .= '
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 25%; text-align: center;">Mot à rechercher</span>
		<span class=headerspan style="width: 25%; text-align: center;">Catégorie</span>
		<span class=headerspan style="width: 25%; text-align: center;">Compte</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
	
	############## génération des formulaires modifications des règles automatiques ##############	
    for ( @$resultat ) {
		my $reqline = ($line ++);	
		my $delete_href = 'docs&#63;nouveau&amp;delete=0&amp;libelle=' . URI::Escape::uri_escape_utf8($_->{config_libelle}) ;
		my $valid_href = 'docs&#63;nouveau&amp;maj=1&amp;modifier=1&amp;supprimer=0&amp;old_libelle=' . URI::Escape::uri_escape_utf8( $_->{config_libelle} ) ;
		my $delete_link = '<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>';
	
		#Sélectionner une catégorie
		my $selected_journal = ($_->{config_journal} || 'azertyuiop');;
		my $select_journal = '<select onchange="findModif(this,'.$reqline.');if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'};" class="formMinDiv4" name=select_journal id=select_journal_'.$reqline.'>' ;
		$select_journal .= '<option class="opt1" value="">Créer une catégorie</option>' ;
		$select_journal .= '<option value="">--Sélectionner une catégorie--</option>' ;
		for ( @$journal_req ) {
		my $selected = ( $_->[0] eq $selected_journal) ? 'selected' : '' ;
		$select_journal .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
		}
		if (!($_->{config_journal})) {
		$select_journal .= '<option value="" selected>--Sélectionner une catégorie--</option>' ;
		}
		$select_journal .= '</select>' ;

		#Sélectionner un compte
		my $selected_compte = ($_->{config_compte} || 'azertyuiop');
		my $select_compte = '<select onchange="findModif(this,'.$reqline.');if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};" class="formMinDiv4" name=select_compte id=select_compte_'.$reqline.'>' ;
		$select_compte .= '<option class="opt1" value="">Créer un compte</option>' ;
		$select_compte .= '<option value="">--Sélectionner un compte--</option>' ;
		for ( @$compte_req ) {
		my $selected = ( $_->[0] eq $selected_compte ) ? 'selected' : '' ;
		$select_compte .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . ' - ' .$_->[1].'</option>' ;
		}
		if (!($_->{config_compte})) {
		$select_compte .= '<option value="" selected>--Sélectionner un compte--</option>' ;
		}
		$select_compte .= '</select>' ;

		$formlist .= '
		<li id="line_'.$reqline.'" class="style1">  
		<form class=flex1 method="post">
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 25%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name=libelle value="' . $_->{config_libelle} . '" /></span>
		<span class=displayspan style="width: 25%;">'.$select_journal.'</span>
		<span class=displayspan style="width: 25%;">'.$select_compte.'</span>
		<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider"></span>
		'.$delete_link.'
		<input type=hidden name="old_libelle" value='.$_->{config_libelle}.'>
		<input type=hidden name=nouveau value=>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		</form>
		</li>
		' ;
	}
	
    $formlist .= '</ul></fieldset></div>';

	$content .= '	
		<div class="formulaire2">
			<fieldset class="pretty-box"><legend><h3 class="Titre09">Enregistrement d\'un nouveau document</h3></legend>
				<div class=centrer>
				' . $formlist . '
				</div>
			</fieldset>
		</div>
	' ;

    return $content ;
    
} #sub form_new_docs 

#/*—————————————— Menu des catégories de document (old )——————————————*/
sub display_menu_docs_old {

	#définition des variables
	my ( $r, $args, $array_of_documents ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	unless ( defined $args->{docscategorie} ) {
		$args->{docscategorie} = 'Tous%20documents' ;
	}
	my $libelle_cat_doc ||= 0 ;
	my ($content, $categorie_list, $categorie_list2) = '' ;

	#########################################	
	#définition des liens					#
	#########################################
	
	my $tags_param = '';  # Initialisez la variable avec une chaîne vide par défaut
	# Vérifiez si $args->{tags} est défini et affectez-le à $tags_param
	if (defined $args->{tags}) {$tags_param = $args->{tags};}
	# Maintenant, vous pouvez utiliser la fonction split en toute sécurité
	my @tags = split /,/, $tags_param;

	#lien vers la création d'un nouveau document
	my $new_doc_class = ( defined $args->{nouveau} ) ? 'active' : 'section-ina' ;
	my $new_doc_link = '<li><a class="'.$new_doc_class.'" href="/'.$r->pnotes('session')->{racine}.'/docs?nouveau" title="Ajouter un nouveau document" >Ajouter des documents</a></li>' ;
	
	#lien vers la création d'un nouveau document
	my $new_doc_class2 = ( defined $args->{nouveau} ) ? 'linavselect' : 'linav' ;
	my $new_doc_link2 = '<li><a class="'.$new_doc_class2.'" href="/'.$r->pnotes('session')->{racine}.'/docs?nouveau" title="Ajouter un nouveau document" >Ajouter des documents</a></li>' ;
	
	#lien vers la catégorie "Tous les documents"
	my $all_doc_class = (($args->{docscategorie} =~ /Tous/ && not(defined $args->{categorie}) && not(defined $args->{tag}) && not(defined $args->{nouveau})) ? 'active' : 'section-ina' );
	my $all_doc_link = '<li><a class="' . $all_doc_class  . '" href="/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=Tous" >Tous&nbsp;les&nbsp;documents</a></li>' ;

	#lien vers la catégorie "Tous les documents"
	my $all_doc_class2 = (($args->{docscategorie} =~ /Tous/ && not(defined $args->{categorie}) && not(defined $args->{tag}) && not(defined $args->{nouveau})) ? 'linavselect' : 'linav' );
	my $all_doc_link2 = '<li><a class="' . $all_doc_class2  . '" href="/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=Tous" >Tous&nbsp;les&nbsp;documents</a></li>' ;

	#Requête de la liste des Catégories de documents
	my $sql = 'SELECT libelle_cat_doc FROM tbldocuments_categorie WHERE id_client= ? ORDER BY 1' ;
	my $cat_docs = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;

	for ( @{$cat_docs} ) {
		my $categorie_href = '/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=' . URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) ;
		my $categorie_class = ( ($args->{docscategorie} eq URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) || $args->{docscategorie} eq  $_->{libelle_cat_doc} ) ? 'active' : 'section-ina' );
		$categorie_list .= '<li><a class="' . $categorie_class . '" href="' . $categorie_href . '" >' . $_->{libelle_cat_doc} . '</a></li>' ;
	} #    for ( @$cat_docs ) {	
	
	#lien de modification des catégories de document
	my $cat_docs_edit_class = ( (defined $args->{categorie} ) ? 'active' : 'section-ina' );
	my $cat_docs_edit_link = '<li><a class="' . $cat_docs_edit_class . '" href="/'.$r->pnotes('session')->{racine}.'/docs?categorie" >Modifier&nbsp;les&nbsp;catégories</a></li>' ;
    
    #lien de modification des catégories de document
	my $cat_docs_edit_class2 = ( (defined $args->{categorie} ) ? 'linavselect' : 'linav' );
	my $cat_docs_edit_link2 = '<li><a class="' . $cat_docs_edit_class2 . '" href="/'.$r->pnotes('session')->{racine}.'/docs?categorie" >Modifier&nbsp;les&nbsp;catégories</a></li>' ;
	
	#lien de modification des catégories de document
	my $tag_docs_edit_class = ( (defined $args->{tag} ) ? 'linavselect' : 'linav' );
	my $tag_docs_edit_link = '<li><a class=' . $tag_docs_edit_class . ' href="/'.$r->pnotes('session')->{racine}.'/docs?tag" >Modifier&nbsp;les&nbsp;tags</a></li>' ;
	
	# Définissez une liste de classes de couleur prédéfinies
	my @color_classes;
	for my $i (1..18) {
		push @color_classes, "tag-$i";
	}
	
	for ( @{$cat_docs} ) {
		my $random_index = int(rand(scalar @color_classes));
		my $categorie_color_class = $color_classes[$random_index];
		my $categorie_href = '';

		if ($args->{docscategorie} eq $_->{libelle_cat_doc}) {
			$categorie_href = '/'.$r->pnotes('session')->{racine}.'/docs' ;
		} else {
			$categorie_href = '/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=' . URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) ;	
		}
		
		my $categorie_class = ( ($args->{docscategorie} eq URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) || $args->{docscategorie} eq  $_->{libelle_cat_doc} ) ? "linavselect" : "linav" );
		$categorie_list2 .= '<li><a class="'.$categorie_class.'" href="' . $categorie_href . '" >' . $_->{libelle_cat_doc} . '</a></li>';
		
	} #    for ( @$cat_docs ) {	

	#<a class="tag-a" href="/'.$r->pnotes('session')->{racine}.'/docs"><span class="tag tag-javascript tag-lg">Catégorie</span></a>
	#<a class="tag-a" href="/'.$r->pnotes('session')->{racine}.'/docs"><span class="tag tag-javascript tag-lg">#Tags</span></a>
	#Requête de la liste des Tags de documents
	my $tags = '
	<div class="menuN2"><ul class="main-nav2">
	'.$categorie_list2.'
	</ul>
	<ul class="main-nav2">';
	
	#my $info_tags = Base::Site::bdd::get_tags_documents($dbh, $r);
	my @current_tags = defined $args->{tags} ? split /,/, $args->{tags} : ();

	for (@{$array_of_documents}) {
		if (defined $_->{tags_nom} && $_->{tags_nom} ne '') {
			my $random_index = int(rand(scalar @color_classes));
			my $tag_color_class = $color_classes[$random_index];
			my $tags_nom = $_->{tags_nom}; # Nom du tag

			my @updated_tags = @current_tags;

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
			my $tags_href = '/' . $r->pnotes('session')->{racine} . '/docs?tags=' . URI::Escape::uri_escape_utf8($tags_param);

			# Construire la classe des tags
			my $tags_class = '';
			if ($tag_in_list) {
				$tags_class = "linavselect";
			} else {
				$tags_class = "linav";
			}

			# Ajouter le lien au HTML des tags
			$tags .= '<li><a class="'.$tags_class.'" href="' . $tags_href . '" >#' . $tags_nom . '</a></li>';
		}
	}
	$tags .= '</ul></div>';

	#########################################	
	#génération du menu						#
	#########################################
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '
	<div class="menu"><ul class="main-nav2">
	' . $new_doc_link2 . '
	' . $cat_docs_edit_link2 . '
	' . $tag_docs_edit_link . '
	' . $all_doc_link2 . '
	</ul></div>
	'.$tags.'
	<div class="flex">
	<main style="width: 100%;">' ;
	} else {
	$content .= '
	<div class="menu"><ul class="main-nav2">
	' . $all_doc_link2 . '
	</ul></div>
	<div class="flex">
	<main style="width: 100%;">' ;	
	}

    return $content ;

} #sub display_menu_docs_old 

#/*—————————————— Menu des catégories de document ——————————————*/
sub display_menu_docs {

	#définition des variables
	my ( $r, $args, $array_of_documents) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my $libelle_cat_doc ||= 0 ;
	my ($content, $categorie_list) = '' ;
	my $id_name_docs;
	
	if (defined $args->{id_name}) {
		my $sql = 'SELECT id_name, libelle_cat_doc, fiscal_year, id_client FROM tbldocuments WHERE id_client = ? AND id_name = ?';
		eval { $id_name_docs = $dbh->selectrow_hashref($sql, { Slice => {} }, ($r->pnotes('session')->{id_client}, $args->{id_name})) };
	}
	
	if (defined $args->{search_categorie} && $args->{search_categorie} ne '') {
		$args->{docscategorie} = $args->{search_categorie};
	} elsif (defined $args->{docscategorie} && $args->{docscategorie} ne '') {
	} elsif (defined $args->{id_name} && $args->{id_name} ne '') {
		$args->{docscategorie} = $id_name_docs->{libelle_cat_doc};
	} else {
		$args->{docscategorie} = 'Tous%20documents';
	}
	
	my $tags_param = '';  # Initialisez la variable avec une chaîne vide par défaut
	# Vérifiez si $args->{tags} est défini et affectez-le à $tags_param
	if (defined $args->{tags}) {$tags_param = $args->{tags};}
	# Maintenant, vous pouvez utiliser la fonction split en toute sécurité
	my @tags = split /,/, $tags_param;
	
	# Initialisation du filtre de catégorie en fonction de la valeur de 'docscategorie'
	my $filter_categorie_dest = (defined $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/)) ? 'AND t1.libelle_cat_doc = ?' : '';

	# Requête pour récupérer la liste des tags des documents enregistrés
	my $sql = 'SELECT t2.tags_nom FROM tbldocuments t1
			   LEFT JOIN tbldocuments_tags t2 ON t1.id_client = t2.id_client AND t1.id_name = t2.tags_doc
			   WHERE t1.id_client = ? AND (t1.fiscal_year = ? OR (t1.multi = \'t\' AND (t1.last_fiscal_year IS NULL OR t1.last_fiscal_year >= ?)))
			   AND t2.tags_nom IS NOT NULL ' . $filter_categorie_dest . '
			   GROUP BY t2.tags_nom
			   ORDER BY t2.tags_nom';

	my $array_of_documents_tags;
	my @bind_array_1 = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year});

	# Ajout de la valeur de 'docscategorie' à la liste des paramètres liés à la requête si nécessaire
	push @bind_array_1, $args->{docscategorie} if (defined $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/));

	# Exécution de la requête SQL
	eval { $array_of_documents_tags = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array_1) };

	#########################################	
	#définition des liens					#
	#########################################		
	#lien vers la catégorie "Tous les documents"
	my $all_doc_class = ((defined $args->{docscategorie} && $args->{docscategorie} =~ /Tous/ && not(defined $args->{categorie}) && not(defined $args->{tag}) && not(defined $args->{nouveau})) ? 'men3select' : '' );
	my $all_doc_link = '<li><a class="men men3 ' . $all_doc_class  . '" href="/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=Tous" title="Afficher tous les documents" >Tous&nbsp;les&nbsp;documents</a></li>' ;
		
	#lien vers la création d'un nouveau document
	my $new_doc_class = ( defined $args->{nouveau} ) ? 'men1select' : '' ;
	my $new_doc_href = ( defined $args->{nouveau} ) ? '' : '?nouveau' ;
	my $new_doc_link = '<li><a class="men men1 '.$new_doc_class.'" href="/'.$r->pnotes('session')->{racine}.'/docs'.$new_doc_href.'" title="Ajouter un nouveau document" >Ajouter</a></li>' ;
		
	#Requête de la liste des Catégories de documents
	my $cat_docs = Base::Site::bdd::get_categorie_document($dbh, $r);

	for ( @{$cat_docs} ) {
		my $categorie_href='/'.$r->pnotes('session')->{racine}.'/docs?docscategorie=' . URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) ;	
		my $categorie_class = ( (defined $args->{docscategorie} && ($args->{docscategorie} eq URI::Escape::uri_escape_utf8( $_->{libelle_cat_doc} ) || $args->{docscategorie} eq  $_->{libelle_cat_doc} )) ? 'men3select' : '' );
		$categorie_list .= '<li><a class="men men3 ' . $categorie_class . '" href="' . $categorie_href . '" >' . $_->{libelle_cat_doc} . '</a></li>' ;
	} #    for ( @$cat_docs ) {	
	
	#lien de modification des catégories de document
	my $cat_docs_edit_class = ( (defined $args->{categorie} ) ? 'men1select' : '' );
	my $cat_docs_edit_href = ( defined $args->{categorie} ) ? '' : '?categorie' ;
	my $cat_docs_edit_link = '<li><a class="men men1 ' . $cat_docs_edit_class . '" href="/'.$r->pnotes('session')->{racine}.'/docs'.$cat_docs_edit_href.'" title="Modifier les catégories de document" >Catégorie</a></li>' ;
	
	#lien de modification des catégories de document
	my $tag_docs_edit_class = ( (defined $args->{tag} ) ? 'men1select' : '' );
	my $tag_docs_edit_href = ( (defined $args->{tag} ) ? '' : '?tag' );
	my $tag_docs_edit_link = '<li><a class="men men1 ' . $tag_docs_edit_class . '" href="/'.$r->pnotes('session')->{racine}.'/docs'.$tag_docs_edit_href.'" title="Modifier les tags de document">#Tags</a></li>
	' ;
	
	# Définissez une liste de classes de couleur prédéfinies
	my @color_classes;
	for my $i (1..18) {
		push @color_classes, "tag-$i";
	}
	
	#Requête de la liste des Tags de documents
	my $tags = '
	<div class="menuN2">
	<ul class="main-nav2">';
	
	#my $info_tags = Base::Site::bdd::get_tags_documents($dbh, $r);
	my @current_tags = defined $args->{tags} ? split /,/, $args->{tags} : ();

	if (defined $args->{tags} && $args->{tags} ne '') {
		my $tags_param = $args->{tags};
		# Utilisation d'un ensemble pour stocker les tags uniques
		my %unique_tags;

		for my $document (@{$array_of_documents}) {
			my $id_name = $document->{id_name};

			my $sql = "SELECT tags_nom FROM tbldocuments_tags WHERE id_client = ? AND tags_doc = ?";
			my $array_of_tags;
			my @bind_array = ($r->pnotes('session')->{id_client}, $id_name);

			eval { $array_of_tags = $dbh->selectall_arrayref($sql, {Slice => {}}, @bind_array) };

			# Récupération des résultats et stockage des tags uniques
			foreach my $row (@$array_of_tags) {
				my $tag_nom = $row->{tags_nom};
				$unique_tags{$tag_nom} = 1; # Stockage dans l'ensemble
			}
		}
		
		# Tri des tags par ordre alphabétique
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
			my $tags_href = '';
			
			if (defined $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/)) {
				$tags_href = '/' . $r->pnotes('session')->{racine} . '/docs?docscategorie=' . URI::Escape::uri_escape_utf8( $args->{docscategorie} ).'&tags=' . URI::Escape::uri_escape_utf8($tags_param);
			} else {
				$tags_href = '/' . $r->pnotes('session')->{racine} . '/docs?tags=' . URI::Escape::uri_escape_utf8($tags_param);
			}

			my $tags_class = '';
			if ($tag_in_list) {
				$tags_class = "men2select";
			}
			
			$tags .= '<li><a class="men men2 '.$tags_class.'" href="' . $tags_href . '" >#' . $tags_nom . '</a></li>';
		}
		
	} else {
		# Afficher pour tous les documents tous les tags
		for (@{$array_of_documents_tags}) {
			if (defined $_->{tags_nom} && $_->{tags_nom} ne '') {
			my $tags_nom = $_->{tags_nom};
				
			my $tags_href = '';
			
			if (defined $args->{docscategorie} && ($args->{docscategorie} !~ /Tous/)) {
				$tags_href = '/' . $r->pnotes('session')->{racine} . '/docs?docscategorie=' . URI::Escape::uri_escape_utf8( $args->{docscategorie} ).'&tags=' . URI::Escape::uri_escape_utf8($tags_nom);
			} else {
				$tags_href = '/' . $r->pnotes('session')->{racine} . '/docs?tags=' . URI::Escape::uri_escape_utf8($tags_nom);
			}
			
			$tags .= '<li><a class="men men2" href="' . $tags_href . '" >#' . $tags_nom . '</a></li>';
			}
		}
	}

	$tags .= '</ul></div>';
	
	#########################################	
	#génération du menu						#
	#########################################
	if (defined $args->{id_name}) {	
	$content .= '<div class="menu"><ul class="main-nav2">' . $new_doc_link . $cat_docs_edit_link . $tag_docs_edit_link . '<li><span class="separator"> | </span></li>'. $all_doc_link . ($categorie_list || '') . '</ul></div>' ;
	} elsif ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '<div class="menu"><ul class="main-nav2">' . $new_doc_link . $cat_docs_edit_link . $tag_docs_edit_link . '<li><span class="separator"> | </span></li>'. $all_doc_link . ($categorie_list || '') . '</ul></div>
	'.$tags.'' ;
	} else {
	$content .= '<div class="menu"><ul class="main-nav2">' . $all_doc_link . ($categorie_list || '') . '</ul></div>
	'.$tags.'' ;
	}

    return $content ;

} #sub display_menu_docs

#/*—————————————— Extraction texte PDF ——————————————*/
# Extrait le texte d'un fichier PDF pour traitement OCR
sub extract_pdf_text {
    my ($pdf_path) = @_;
    
    return undef unless -f $pdf_path;
    return undef unless $pdf_path =~ /\.pdf$/i;
    
    my $text = '';
    
    # Méthode 1: Utiliser pdftotext (poppler-utils) - plus rapide
    if (-x '/usr/bin/pdftotext') {
        my ($stdin, $stdout, $stderr);
        run3(['/usr/bin/pdftotext', '-layout', $pdf_path, '-'], \$stdin, \$stdout, \$stderr);
        $text = $stdout if $stdout;
    }
    
    # Méthode 2: Utiliser PDF::API2 si pdftotext échoue
    if (!$text) {
        eval {
            my $pdf = PDF::API2->open($pdf_path);
            if ($pdf) {
                for my $page_num (1..$pdf->pages) {
                    my $page = $pdf->openpage($page_num);
                    # Note: PDF::API2 ne permet pas l'extraction texte directe
                    # C'est pourquoi on préfère pdftotext
                }
            }
        };
    }
    
    return $text;
}

1 ;
