package Base::Site::menu;
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
use Base::Service::EmailReceiver;  # Import des factures depuis email IMAP
use Base::Service::BankReconciliation;  # Rapprochement bancaire automatique
use Apache2::URI;      # Manipulation d'URLs pour Apache
use Apache2::Upload;   # Gestion des téléchargements de fichiers
use Apache2::Request;  # Traitement des requêtes HTTP pour Apache
use Apache2::Const -compile => qw( OK DECLINED REDIRECT );  # Importation de constantes Apache
use URI::Escape;       # Encodage et décodage d'URLs
use PDF::API2;         # Manipulation de fichiers PDF
use Time::Piece;       # Manipulation de dates et heures
use MIME::Base64;      # Encodage et décodage MIME
use utf8;              # Encodage UTF-8 pour le script
use Encode;            # Encodage de caractères
use List::Util qw(min first);  # Fonctions utilitaires pour les listes
use HTML::Entities;
use JSON;
use File::Path qw(mkpath);


sub handler {

    binmode(STDOUT, ":utf8") ;  # Configuration de la sortie standard en mode UTF-8
    my $r = shift ;  # Récupération de l'objet de requête Apache

    # Utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});

    my $content = '';  # Initialisation d'une variable pour le contenu de la réponse
    my $req = Apache2::Request->new( $r );  # Création d'un objet Apache2::Request pour gérer la requête

    # Récupérer les arguments de la requête
    my (%args, @args);

    # Recherche des paramètres de la requête
    @args = $req->param;

    for (@args) {
        $args{$_} = Encode::decode_utf8( $req->param($_) );

        # Remplacement de certaines balises pour éviter des conflits avec le HTML
        $args{$_} =~ tr/<>"/'/;
    }

    if (defined $args{journal})  {
        # Construction d'une URL de redirection basée sur les paramètres
        my $location = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' .
                       URI::Escape::uri_escape_utf8( $args{journal} ) . '&amp;id_entry=0&amp;nouveau' ;

        $r->headers_out->set(Location => $location);

        return Apache2::Const::REDIRECT;  # Redirection HTTP
    }
    
    # Vérifier si la mise à jour de la base de données a déjà été effectuée
    unless ($r->pnotes('session')->{db_update_done}) {
        # Si elle n'a pas été effectuée, faire la mise à jour
        verif_bdd_update($r, \%args);
        # Mettre à jour la session pour indiquer que la mise à jour a été effectuée
        $r->pnotes('session')->{db_update_done} = 1;
        Base::Handler::parametres::freeze_session( $r ) ;
    }

    # Appel de la fonction principal() pour générer le contenu de la réponse
    $content = principal( $r, \%args );
    
    $r->no_cache(1);  # Désactivation de la mise en cache

    $r->content_type('text/html; charset=utf-8');  # Définition du type de contenu de la réponse

    print $content;  # Impression du contenu de la réponse

    return Apache2::Const::OK;  # Fin du traitement avec succès
}

sub principal {
	
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content) ;
	
	#Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

    # Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	#####################################       
	# Manipulation des dates			#
	#####################################  
	my $date_comptant;
	#en 1ère arrivée, mettre la date du jour par défaut ou date de fin d'exercice
	my $date_1 = localtime->strftime('%Y-%m-%d');
	my $date_2 = $r->pnotes('session')->{Exercice_fin_YMD} ;
	if ($date_1 gt $date_2) {$date_comptant = $date_2; $args->{date_time} = eval {Time::Piece->strptime($date_2, "%Y-%m-%d")->dmy("/")}; } else {$date_comptant = $date_1; $args->{date_time} = eval {Time::Piece->strptime($date_1, "%Y-%m-%d")->dmy("/")};}
	
	my $contenu_web_doc .= '
	<div class="card">
	<p class="card-text"></p>
    <br/><a style="margin-left: 1ch;" class="decoff" href="/'.$r->pnotes('session')->{racine}.'/docs?import=0">Importer les données</a>
    </div>';

	my $contenu_web_param .= '
	<div class="card">
	<div class="Titre10 centrer"><a class=aperso2 href="/'.$r->pnotes('session')->{racine}.'/parametres">Paramètres</a></div>
    <p class="card-text"></p>
    <a style="margin-left: 1ch;" class="decoff" href="/'.$r->pnotes('session')->{racine}.'/parametres?societes">Gestion des sociétés</a>
	<br/><a style="margin-left: 1ch;" class="decoff" href="/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs">Gestion des utilisateurs</a>
    <br/><a style="margin-left: 1ch;" class="decoff" href="/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde">Gestion des sauvegardes</a>
    <br/><a style="margin-left: 1ch;" class="decoff" href="/'.$r->pnotes('session')->{racine}.'/parametres?logs">Logs</a>
    </div>
    ';
    
    #####################################       
	# Menu chekbox
	#####################################   
	#définition des variables
	my @checked = ('0') x 20;
	my @dispcheck = ('0') x 20;
	my $retour_href = 'javascript:history.go(-1)';
	my @menu_items;
    
    #checked par défault menu01
    unless (defined $args->{menu01}) {$args->{menu01} = 1;}
	
	if (defined $args->{menu01} && $args->{menu01} eq 1) {$checked[1] = 'checked';} else {$checked[1] = '';}
	if ((defined $args->{menu02} && $args->{menu02} eq 1 || defined $args->{search})) {$checked[2] = 'checked';} else {$checked[2] = '';}
	if ((defined $args->{menu03} && $args->{menu03} eq 1) || defined $args->{ecriture_recurrente}) {$checked[3] = 'checked';} else {$checked[3] = '';}
	if ((defined $args->{menu08} && $args->{menu08} eq 1) || defined $args->{interet_cca}) {$checked[8] = 'checked';} else {$checked[8] = '';}
	if (defined $args->{menu09} && $args->{menu09} eq 1) {$checked[9] = 'checked';} else {$checked[9] = '';}
	if ((defined $args->{menu11} && $args->{menu11} eq 1) || defined $args->{importer}) {$checked[11] = 'checked';} else {$checked[11] = '';}
	if ((defined $args->{menu12} && $args->{menu12} eq 1) || defined $args->{saisie_rapide}) {$checked[12] = 'checked';} else {$checked[12] = '';}
	
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {		
		@menu_items = (
		{ label => 'Documentation', index => '01' },
		{ label => 'Rechercher', index => '02' },
		{ label => 'Saisie Rapide', index => '12' },
		{ label => 'Écr. récurrentes', index => '03' },
		{ label => 'Intérêts CCA', index => '08' },
		{ label => 'CSV/OFX/OCR', index => '11' },
		{ label => 'Import Email', index => '13' },
		);
	} else {
		@menu_items = (
		{ label => 'Documentation', index => '01' },
		{ label => 'Rechercher', index => '02' },
		);
	}

	my $fiche_client .= '<div class=centrer><div class="flex-checkbox">';
	
	foreach my $item (@menu_items) {
		$fiche_client .= '
			<form method="post" action=/'.$r->pnotes('session')->{racine}.'/menu>
				<label for="check' . $item->{index} . '" class="forms2_label">' . $item->{label} . '</label>
				<input id="check' . $item->{index} . '" type="checkbox" class="demo5" '.$checked[$item->{index}].' onchange="submit()" name="menu' . $item->{index} . '" value=1>
				<label for="check' . $item->{index} . '" class="forms2_label"></label>
				<input type=hidden name="menu' . $item->{index} . '" value=0 >';
		
		foreach my $other_item (@menu_items) {
			$fiche_client .= '<input type=hidden name="menu' . $other_item->{index} . '" value="' . ($args->{'menu' . $other_item->{index}} || '') . '">';
		}
		
		#Garder les args si ajout de "Rechercher"
		if ($item->{index} =~ /^(01)$/) {
			$fiche_client .= '' . $hidden_fields_form . '</form>';
		} else {
			$fiche_client .= '</form>';	
		}
		
	}

	$fiche_client .= '</div></div>';

	my $forms_ecri_rec = '<div class="card"> '.forms_ecri_rec( $r, $args ).'</div>' ; 
	my $forms_ocr = '<div class="card"> '.forms_ocr( $r, $args ).'</div>' ; 
	my $forms_search = '<div class="card"> '.forms_search( $r, $args ).'</div>' ; 
	my $forms_paiement_saisie = '<div class="card"> '.forms_paiement_saisie( $r, $args, $dbh ).'</div>' ; 
	my $forms_interet_cca = '<div class="card"> '.forms_interet_cca( $r, $args ).'</div>' ;
	my $forms_importer = '<div class="card"> '.forms_importer( $r, $args ).'</div>' ;
	my $forms_email_import = '<div class="card"> '.forms_email_import( $r, $args ).'</div>' ;
	
	my $forms_documentation = forms_documentation( $r, $args ) ; 

	if (defined $args->{menu01} && $args->{menu01} eq 1) {$dispcheck[1] = $forms_documentation;} else {$dispcheck[1] = '';}
	if ((defined $args->{menu02} && $args->{menu02} eq 1) || defined $args->{search}) {$dispcheck[2] = $forms_search;} else {$dispcheck[2] = '';}
	if ((defined $args->{menu03} && $args->{menu03} eq 1) || defined $args->{ecriture_recurrente}) {$dispcheck[3] = $forms_ecri_rec;} else {$dispcheck[3] = '';}
	if ((defined $args->{menu08} && $args->{menu08} eq 1) || defined $args->{interet_cca}) {$dispcheck[8] = $forms_interet_cca;} else {$dispcheck[8] = '';} 
	if ((defined $args->{menu11} && $args->{menu11} eq 1) || defined $args->{importer}) {$dispcheck[11] = $forms_importer;} else {$dispcheck[11] = '';} 
	if ((defined $args->{menu12} && $args->{menu12} eq 1) || defined $args->{saisie_rapide}) {$dispcheck[12] = $forms_paiement_saisie;} else {$dispcheck[12] = '';} 
	if ((defined $args->{menu13} && $args->{menu13} eq 1) || defined $args->{email_import}) {$dispcheck[13] = $forms_email_import;} else {$dispcheck[13] = '';}

	if ($r->pnotes('session')->{type_compta} eq 'tresorerie') {
	$content .= '<div class="wrapper100">'. $fiche_client . $dispcheck[2] . $dispcheck[3] . $dispcheck[11] . $dispcheck[8] . $dispcheck[12] . $dispcheck[13] . $dispcheck[1] . '</div>' ;
	} elsif ($r->pnotes('session')->{Exercice_Cloture} ne '1') {		
	$content .= '<div class="wrapper100">' . $fiche_client . $dispcheck[2] . $dispcheck[3] . $dispcheck[12] . $dispcheck[8] . $dispcheck[11] . $dispcheck[13] . $dispcheck[1] .'</div>' ;
	} else {
	$content .= '<div class="wrapper100">' . $fiche_client . $dispcheck[2] . $dispcheck[1] .'</div>' ;
	}

    return $content ;

}#sub principal

#/*—————————————— Formulaire Ecritures récurrentes ——————————————*/
sub forms_ecri_rec {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors) ;
	my ($content, $id_entry, $contenu_web_ecri_rec) = ('', '', '');
	my $reqid = Base::Site::util::generate_reqline();
	
	# Sélection du mois
	my $select_month = '<select class="forms2_input" style="width: 13%;" name="select_month" id="select_month_'.$reqid.'">' .
    join('', map { "<option value='" . sprintf("%02d", $_) . "'" . (defined($args->{select_month}) && $args->{select_month} eq sprintf("%02d", $_) ? ' selected' : '') . '>' . (split(';', 'Janvier;Février;Mars;Avril;Mai;Juin;Juillet;Août;Septembre;Octobre;Novembre;Décembre'))[$_-1] . '</option>' } 1..12) .
    '</select>';

	# Génération formulaire choix de documents	
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $selected1 = (defined($args->{docs1}) && $args->{docs1} ne '') || (defined($args->{id_name}) && defined($args->{label8}) && $args->{label8} eq '1') ? ($args->{docs1} || $args->{id_name}) : undef;
	my $selected2 = (defined($args->{docs2}) && $args->{docs2} ne '') || (defined($args->{id_name}) && defined($args->{label9}) && $args->{label9} eq '1') ? ($args->{docs2} || $args->{id_name}) : undef;
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my ($form_name1, $form_id1, $class_value1, $style1) = ('docs1', 'docs1_'.$reqid.'', 'class="forms2_input"', 'style="width: 26%;"');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);
	my ($form_name2, $form_id2, $class_value2, $style2) = ('docs2', 'docs2_'.$reqid.'', 'class="forms2_input"', 'style="width: 26%;"');
	my $document_select2 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected2, $form_name2, $form_id2, $onchange1, $class_value2, $style2);

	############## MISE EN FORME DEBUT ##############
	
	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	#/************ ACTION DEBUT *************/
 
	#demande confirmation génération ecriture_recurrente 											  
	#menu?select_month=12&ecriture_recurrente=0
	if ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '0' ) {
		
		# Fonction pour récupérer le nombre d'écritures récurrentes ou les écritures récurrentes par année
		my $nb_recurrent_count = Base::Site::bdd::get_recurrent_data($r, $dbh, 0, 1);
		
		if (defined $nb_recurrent_count && $nb_recurrent_count != 0) {
			my %mois = ( '01' => 'Janvier', '02' => 'Février', '03' => 'Mars', '04' => 'Avril', '05' => 'Mai', '06' => 'Juin', '07' => 'Juillet', '08' => 'Août', '09' => 'Septembre', '10' => 'Octobre', '11' => 'Novembre', '12' => 'Décembre' );
			my $message2 = 'Voulez-vous vraiment générer les ' . ($nb_recurrent_count || '') .' écritures récurrentes pour ' . $mois{$args->{select_month}} .' ?' ;
			my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ecriture_recurrente', $args->{ecriture_recurrente}, $hidden_fields, 1);
			$content .= Base::Site::util::generate_error_message($confirmation_message);
			
		} else {
			
			my $message2 = 'Il n\'y a aucune écriture récurrente de paramétrée sur cette exercice. <br> 
			Voulez-vous importer les écritures récurrentes de l\'exercice précédent ?' ;
			my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ecriture_recurrente', $args->{ecriture_recurrente}, $hidden_fields, 2);
			$content .= Base::Site::util::generate_error_message($confirmation_message);
	
		}
		
	# enregistrement des écritures récurrentes	
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '1' ) {

		# Fonction pour récupérer le nombre d'écritures récurrentes ou les écritures récurrentes par année
		my $recurrent_courantes = Base::Site::bdd::get_recurrent_data($r, $dbh, 0, 0);

		foreach ( @{$recurrent_courantes} ) {
	
			my $token_id_temp = Base::Site::util::generate_unique_token_id($r, $dbh);	
			my $token_id = 'recurrent-'.$token_id_temp ;
		
			my $day = substr($_->{date_ecriture},0,2);
			my $date = $r->pnotes('session')->{fiscal_year}.'-'.$args->{select_month}.'-'.$day;
			my $yyyy = $r->pnotes('session')->{fiscal_year}; 
			my $mm = $args->{select_month}; 
			my $from = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{4})";  
			my $to = $mm.'/'.$yyyy;
			
	        if (not($date =~ /(?:19|20)[0-9]{2}-(?:(?:0[1-9]|1[0-2])-(?:0[1-9]|1[0-9]|2[0-9])|(?:(?!02)(?:0[1-9]|1[0-2])-(?:30))|(?:(?:0[13578]|1[02])-31))/)) {
			$date = $r->pnotes('session')->{fiscal_year}.'-'.$args->{select_month}.'-05';	
			}
					
			$sql = '
			INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, _token_id ) SELECT ?, ?, t1.id_client, t1.fiscal_year, ?, ?, ?, t1.libelle_journal, t1.numero_compte, ?, t1.id_paiement, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? ORDER BY id_line' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $date, $token_id, $_->{id_entry} ) ;

			$dbh->do( $sql, undef, @bind_array ) ;
	
			#update le choix du document
			
			if ((defined $args->{docs2}) && (not($args->{docs2} eq ''))) {
				$sql = 'UPDATE tbljournal_staging SET documents2 = ? WHERE _token_id = ? AND documents2 is not null' ;
				@bind_array = ( ($args->{docs2} || undef), $token_id ) ;
				$dbh->do( $sql, undef, @bind_array ) ;	
			} 
			
			if ((defined $args->{docs1}) && (not($args->{docs1} eq ''))) {
				$sql = 'UPDATE tbljournal_staging SET documents1 = ? WHERE _token_id = ? AND documents1 is not null' ;
				@bind_array = ( ($args->{docs1} || undef), $token_id ) ;
				$dbh->do( $sql, undef, @bind_array ) ;	
			} 
			
			#Ajout de la périodicité dans le libellé de l'écriture
			if ( defined $args->{add_periodicite} and $args->{add_periodicite} eq '1' ) {

				$sql = 'SELECT id_line, libelle FROM tbljournal_staging WHERE _token_id = ? ORDER BY id_line' ;

				my $resultat_lib = $dbh->selectall_arrayref( $sql, { Slice => { } }, $token_id) ;

				foreach ( @{$resultat_lib} ) {
 	
					my $lib = $_->{libelle} ;
					my $dateform1 = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{2})";
					my $dateform2 = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{4})";
      
					if ($lib =~ /(?:0[1-9]|1[0-2])\/(?<year>[0-9]{4})/) {
					$lib =~s/$dateform2/$to/ig;
					} elsif ($lib =~ /(?:0[1-9]|1[0-2])\/(?<year>[0-9]{2})/) {
					$lib =~s/$dateform1/$to/ig;
					}
	
					#update du libellé 	
					$sql = 'UPDATE tbljournal_staging SET libelle = ? WHERE _token_id = ? and id_line = ?' ;
					@bind_array = ( $lib, $token_id, $_->{id_line}  ) ;
					$dbh->do( $sql, undef, @bind_array ) ;
	
				}#Fin foreach ( @{$resultat_lib})
				
			}#Fin $args->{add_periodicite}

		}#Fin foreach ( @{$recurrent_courantes})
	
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures récurrentes : Génération des écritures pour le mois ' . $args->{select_month} .'. Les écritures sont désormais en attente de validation.');
	
	# enregistrement des écritures récurrentes de l'exercice précédent	
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '2' ) {
		
		# Fonction pour récupérer le nombre d'écritures récurrentes ou les écritures récurrentes par année
		my $recurrent_annee_precedente = Base::Site::bdd::get_recurrent_data($r, $dbh, -1, 0);
		
		foreach ( @{$recurrent_annee_precedente} ) {
	
			my $token_id_temp = Base::Site::util::generate_unique_token_id($r, $dbh);	
			my $token_id = 'recurrent-'.$token_id_temp ;
		
			my $day = substr($_->{date_ecriture},0,2);
			my $date = $r->pnotes('session')->{fiscal_year}.'-'.$args->{select_month}.'-'.$day;
			my $yyyy = $r->pnotes('session')->{fiscal_year}; 
			my $mm = $args->{select_month}; 
			my $from = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{4})";  
			my $to = $mm.'/'.$yyyy;
			
			if (not($date =~ /(?:19|20)[0-9]{2}-(?:(?:0[1-9]|1[0-2])-(?:0[1-9]|1[0-9]|2[0-9])|(?:(?!02)(?:0[1-9]|1[0-2])-(?:30))|(?:(?:0[13578]|1[02])-31))/)) {
			$date = $r->pnotes('session')->{fiscal_year}.'-'.$args->{select_month}.'-05';	
			}
	
			$sql = '
			INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, _token_id ) SELECT ?, ?, t1.id_client, t1.fiscal_year + 1, ?, ?, ?, t1.libelle_journal, t1.numero_compte, ?, t1.id_paiement, t1.id_facture, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? ORDER BY id_line' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $date, $token_id, $_->{id_entry} ) ;

			$dbh->do( $sql, undef, @bind_array ) ;
	
			#update le choix du document
			
			if ((defined $args->{docs2}) && (not($args->{docs2} eq ''))) {
				$sql = 'UPDATE tbljournal_staging SET documents2 = ? WHERE _token_id = ? AND documents2 is not null' ;
				@bind_array = ( ($args->{docs2} || undef), $token_id ) ;
				$dbh->do( $sql, undef, @bind_array ) ;	
			} 
			
			if ((defined $args->{docs1}) && (not($args->{docs1} eq ''))) {
				$sql = 'UPDATE tbljournal_staging SET documents1 = ? WHERE _token_id = ? AND documents1 is not null' ;
				@bind_array = ( ($args->{docs1} || undef), $token_id ) ;
				$dbh->do( $sql, undef, @bind_array ) ;	
			} 
			
			#Ajout de la périodicité dans le libellé de l'écriture
			if ( defined $args->{add_periodicite} and $args->{add_periodicite} eq '1' ) {

				$sql = 'SELECT id_line, libelle FROM tbljournal_staging WHERE _token_id = ? ORDER BY id_line' ;

				my $resultat_lib = $dbh->selectall_arrayref( $sql, { Slice => { } }, $token_id) ;

				foreach ( @{$resultat_lib} ) {
 	
					my $lib = $_->{libelle} ;
					my $dateform1 = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{2})";
					my $dateform2 = "(?:0[1-9]|1[0-2])/(?<year>[0-9]{4})";
      
					if ($lib =~ /(?:0[1-9]|1[0-2])\/(?<year>[0-9]{4})/) {
					$lib =~s/$dateform2/$to/ig;
					} elsif ($lib =~ /(?:0[1-9]|1[0-2])\/(?<year>[0-9]{2})/) {
					$lib =~s/$dateform1/$to/ig;
					}
	
					#update du libellé 	
					$sql = 'UPDATE tbljournal_staging SET libelle = ? WHERE _token_id = ? and id_line = ?' ;
					@bind_array = ( $lib, $token_id, $_->{id_line}  ) ;
					$dbh->do( $sql, undef, @bind_array ) ;
	
				}#Fin foreach ( @{$resultat_lib})
				
			}#Fin $args->{add_periodicite}

		}#Fin foreach ( @{$recurrent_annee_precedente})
	
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures récurrentes : Génération des écritures pour le mois ' . $args->{select_month} .' depuis l\'exercice précédent. Les écritures sont désormais en attente de validation.');
    	
	#demande confirmation validation des ecritures recurrentes	
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '4' ) {
		
		my $message2 = 'Souhaitez-vous réellement valider toutes les écritures récurrentes en attente de validation ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ecriture_recurrente', $args->{ecriture_recurrente}, $hidden_fields, 7);
		$content .= Base::Site::util::generate_error_message($confirmation_message);

	#demande confirmation suppression des ecritures recurrentes		
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '5' ) {
		
		my $message2 = 'Souhaitez-vous réellement supprimer toutes les écritures récurrentes en attente de validation ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ecriture_recurrente', $args->{ecriture_recurrente}, $hidden_fields, 6);
		$content .= Base::Site::util::generate_error_message($confirmation_message);
		
	# Suppression des écritures
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '6' ) {	
	
		Base::Site::bdd::delete_tbljournal_staging($r, $dbh, '%recurrent%');
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures récurrentes : Suppression de toutes les écritures qui étaient en attente de validation.');
	
	# Validation des écritures
	} elsif ( defined $args->{ecriture_recurrente} and $args->{ecriture_recurrente} eq '7' ) {
		
		my $result_gen = Base::Site::bdd::get_token_ids($r, $dbh, '%recurrent%');
		
		foreach ( @{$result_gen} ) {
			my $_token_id = $_->{_token_id};
			my ($return_entry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $_token_id);
			push @errors, $error_message if $error_message;
		}
		
		# Après avoir traité toutes les lignes
		if (@errors) {
			$contenu_web_ecri_rec .= Base::Site::util::generate_error_message(join('<br>', @errors));
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures récurrentes : Toutes les écritures qui étaient en attente de validation ont été validées avec succès.');
			$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name='.$args->{id_name}.'&ecriture_recurrente' :'menu?ecriture_recurrente';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
	}
	
	# Formulaire de génération des écritures récurrentes 	
	$contenu_web_ecri_rec .= '
		<div class="Titre10 centrer"><a class=aperso2>Générer les écritures récurrentes</a></div>
		<form class=wrapper1 action="' . $r->uri() . '?ecriture_recurrente=0" method="POST">
    
		<div class=formflexN2>
        <label style="width: 13%;" class="forms2_label" for="select_month_'.$reqid.'">Sélectionner le mois</label>
		<label style="width: 26%;" class="forms2_label" for="docs1_'.$reqid.'">Modifier document 1</label>
		<label style="width: 26%;" class="forms2_label" for="docs2_'.$reqid.'">Modifier document 2</label>
		<label style="width: 33%;" class="forms2_label" for="periodicite_'.$reqid.'">Indiquer la périodicité dans le libellé de l\'écriture ?</label>
		</div>
       
		<div class=formflexN2>
        ' . $select_month . '
        ' . $document_select1 . '
        ' . $document_select2 . '
        <input style="margin: 5px; width: 33%; height: 4ch; display: block;" type="checkbox" id="periodicite_'.$reqid.'" name="add_periodicite" value=1 checked>
        </div>
        
		<div class=formflexN3>
		<input type=submit id="submit_'.$reqid.'" style="width: 10%;" class="btn btn-vert" value=Générer>
		</div>
		' . $hidden_fields . '
		</form>';
		
	#Vérification si des écritures n'en pas encore été générée dans tbljournal_staging 
	my ($verif_list, $entry_list) = Base::Site::util::check_and_format_ecritures_tbljournal_staging($dbh, $r, $args, 'ecriture_recurrente', '%recurrent%', $hidden_fields);

	$content .= $contenu_web_ecri_rec;
	
	$content .= ($verif_list || '') . ($entry_list || '') ;

	return $content ;
	############## MISE EN FORME FIN ##############

}#sub forms_ecri_rec 		

#/*—————————————— Formulaire OCR Reconnaissance optique de caractères ——————————————*/
sub forms_ocr {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors, @token, $token_id) ;
	my ($content, $id_entry, $message) = ('', '', '');
	my $reqid = Base::Site::util::generate_reqline();
	
	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	################################################################# 
	# génération du choix de documents				 				#
	#################################################################

	# Génération formulaire choix de documents	
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $selected1 = (defined($args->{docs2}) && $args->{docs2} ne '') || (defined($args->{id_name}) && defined($args->{label9}) && $args->{label9} eq '1') ? ($args->{docs2} || $args->{id_name}) : undef;
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my ($form_name1, $form_id1, $class_value1, $style1) = ('docs2', 'docs2_'.$reqid.'', 'class="forms2_input"', 'style="width: 26%;"');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);

	############## MISE EN FORME DEBUT ##############
	# Formulaire de génération des écritures via OCR	
	my $contenu_web_ecri_rec .= '
		<div class="Titre10 centrer"><a class=aperso2>Reconnaissance optique de caractères</a></div>
		<form class=wrapper1 action="' . $r->uri() . '?ocr=0" method="POST">
    
		<div class=formflexN2>
		<label style="width: 26%;" class="forms2_label" for="docs2_'.$reqid.'">Sélectionner le document</label>
		</div>
       
		<div class=formflexN2>
        ' . $document_select1 . '
		</div>
        
		<div class=formflexN3>
		<input type=submit id=submit_'.$reqid.' style="width: 10%;" class="btn btn-vert" value=Générer>
		</div>

		<input type=hidden name="id_name" value="'.($args->{id_name} || '').'">
		</form>';

	#/************ ACTION DEBUT *************/
 
	# Demande de confirmation génération écriture récurrente
	# Menu OCR désactivé
	if (defined $args->{ocr} and $args->{ocr} eq '0') {

		# On interdit les documents vides
		if (!$args->{docs2}) {
			$message .= 'Il est obligatoire de sélectionner un document';
		} else {
			
			# Appeler la sous-routine et stocker le message retourné ainsi que les lignes traitées
			my ($message_resultat, $ref_tableau_lignes) = function_ocr($dbh, $r, $args);

			# Afficher ou afficher le message de résultat
			$message .= $message_resultat;
		}

		$content .= Base::Site::util::generate_error_message($message);

	# enregistrement des écritures récurrentes	
	} elsif ( defined $args->{ocr} and $args->{ocr} eq '1' ) {
			
		# Appeler la sous-routine et stocker le message retourné ainsi que les lignes traitées
		my ($message_resultat, $ref_tableau_lignes) = function_ocr($dbh, $r, $args);

		# Process and use the array of line data
		foreach my $line_data (@$ref_tableau_lignes) {
				my $date_operation = $line_data->{'date_operation'};
				my $date_valeur = $line_data->{'date_valeur'};
				my $libelle = $line_data->{'libelle'};
				my $debit = $line_data->{'debit'}*100;
				my $credit = $line_data->{'credit'}*100;

		
	# Utilisation du sous-programme
	my $resultat = fetch_data_with_increasing_levenshtein($dbh, $r, $libelle, $debit, $credit);
	
	my $token_id_temp = Base::Site::util::generate_unique_token_id($r, $dbh);    
	my $token_id = 'ocr-'.$token_id_temp ;

    # Si la chaîne est vide, passer à l'itération suivante
    if (not defined $resultat) {
        next; # Passer à l'itération suivante
    }

	my $numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $resultat->[0][7], $date_operation, 2);
		
	foreach my $row (@$resultat) {
		my $id_entry = $row->[0];
		my $numero_compte = $row->[1];
		my $classe = substr($numero_compte, 0, 1);
		my $date_ecriture = $row->[2];
		my $libelle_ecriture = $row->[3];
		my $debit_ecriture = $row->[4];
		my $credit_ecriture = $row->[5];
		my $id_facture_ecriture = $row->[6] || '';
		my $libelle_journal_ecriture = $row->[7];
		my $pointage = 0;  # Initialisation du pointage à "false"

		my ($credit_staging,$debit_staging,$numpiece_staging);
		
		# On vérifie que le numéro de compte commence par un chiffre
		if (substr($numero_compte, 0, 1) eq 5) {
			$pointage = 1;  # Mettre le pointage à "true"
			if ($debit != 0) {
				$credit_staging = $debit;
				$debit_staging = 0;
			} elsif ($credit != 0) {
				$credit_staging = 0;
				$debit_staging = $credit;
			}
		} else {
		$credit_staging = $credit;
		$debit_staging = $debit;
		}
		
		# Si id_facture ne contient pas "MULTI"
		if ($id_facture_ecriture !~ /MULTI/) {
			$numpiece_staging = $numero_piece;
		} else {
			$numpiece_staging = $id_facture_ecriture;
		}
		
		#création des comptes 471 s'ils n'existent pas
		my $var_compte_471 = '471000';
		my $var_comptelib_471 = 'Comptes d’attente';

		$sql = '
		INSERT INTO tblcompte (numero_compte, libelle_compte, id_client, fiscal_year)  VALUES (?, ?, ?, ?)
		ON CONFLICT (id_client, fiscal_year, numero_compte) DO NOTHING' ;
		@bind_array = ( $var_compte_471, $var_comptelib_471, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;
				
		$sql = '
		INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, _token_id, pointage ) SELECT ?, ?, t1.id_client, ?, ?, ?, ?, t1.libelle_journal, ?, ?, t1.id_paiement, ?, ?, 
		    CASE WHEN t1.documents1 NOT LIKE \'%MULTI%\' THEN NULL ELSE t1.documents1 END, t1.documents2, ?, ?, ?, ?
		FROM tbljournal t1 
		WHERE t1.id_entry = ? AND SUBSTRING(t1.numero_compte from 1 for 1) = ? ORDER BY id_line' ;
		@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $numero_compte, $date_operation, $numpiece_staging, $libelle, $debit_staging, $credit_staging, $token_id, $pointage, $id_entry, $classe ) ;

		$dbh->do( $sql, undef, @bind_array ) ;
		
		if ((defined $args->{docs2}) && (not($args->{docs2} eq ''))) {
			$sql = 'UPDATE tbljournal_staging SET documents2 = ? WHERE _token_id = ? AND documents2 is not null' ;
			@bind_array = ( ($args->{docs2} || undef), $token_id ) ;
			$dbh->do( $sql, undef, @bind_array ) ;	
		} 
			
		push @token, $token_id;
		#$message .= 'date_operation ' . $date_operation.', $libelle ' . $libelle.',id_entry: ' .$id_entry.', numero_compte: ' .$numero_compte.', date_ecriture: ' .$date_ecriture.', libelle: ' .$libelle.', debit: ' .$debit.', credit: ' .$credit.'<br>';
    
	}

		}

	#$content .= '<h3 class=warning style="margin: 2.5em; padding: 2.5em; text-align: center;">' . $message . '</h3>';
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Génération des écritures du document '.$args->{docs2}.'. Les écritures sont désormais en attente de validation.');

		my $varmenu = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name='.$args->{id_name}.'&ocr=' :'menu?menu10=1';
		$args->{restart} = $varmenu;
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 

	#demande confirmation validation des ecritures ocr	
	} elsif ( defined $args->{ocr} and $args->{ocr} eq '4' ) {
		
		my $message2 = 'Souhaitez-vous réellement valider toutes les écritures en attente de validation générées via OCR ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ocr', $args->{ocr}, $hidden_fields, 7);
		$content .= Base::Site::util::generate_error_message($confirmation_message);

	#demande confirmation suppression des ecritures ocr		
	} elsif ( defined $args->{ocr} and $args->{ocr} eq '5' ) {
		
		my $message2 = 'Souhaitez-vous réellement supprimer toutes les écritures en attente de validation générées via OCR ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ocr', $args->{ocr}, $hidden_fields, 6);
		$content .= Base::Site::util::generate_error_message($confirmation_message);
		
	#suppression des ecritures ocr	
	} elsif ( defined $args->{ocr} and $args->{ocr} eq '6' ) {	
	
		Base::Site::bdd::delete_tbljournal_staging($r, $dbh, '%ocr%');
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Suppression de toutes les écritures qui étaient en attente de validation.');
	
	#validation des ecritures ocr
	} elsif ( defined $args->{ocr} and $args->{ocr} eq '7' ) {
		
		my $result_gen = Base::Site::bdd::get_token_ids($r, $dbh, '%ocr%');
		
		foreach ( @{$result_gen} ) {
			my $_token_id = $_->{_token_id};
			my ($return_entry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $_token_id);
			push @errors, $error_message if $error_message;
		}
		
		# Après avoir traité toutes les lignes
		if (@errors) {
			$contenu_web_ecri_rec .= Base::Site::util::generate_error_message(join('<br>', @errors));
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Toutes les écritures qui étaient en attente de validation ont été validées avec succès.');
			$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name='.$args->{id_name}.'&ecriture_recurrente' :'menu?ocr';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
	}
	
	#Vérification si des écritures n'en pas encore été générée dans tbljournal_staging 
	my ($verif_list, $entry_list) = Base::Site::util::check_and_format_ecritures_tbljournal_staging($dbh, $r, $args, 'ocr', '%ocr%');

	$content .= $contenu_web_ecri_rec;
	
	$content .= ($verif_list || '') . ($entry_list || '') ;

	return $content ;
	############## MISE EN FORME FIN ##############

}#sub forms_ocr		

#/*—————————————— Formulaire Import Email IMAP ——————————————*/
# Import automatique : si la config est complète, l'import se lance tout seul à l'ouverture
# Anti-duplicata : ne réimporte jamais un document déjà présent en base
sub forms_email_import {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ($content, $message) = ('', '');
	my $reqid = Base::Site::util::generate_reqline();
	my $client_id = $r->pnotes('session')->{id_client};
	
	# Récupérer configuration email sauvegardée
	my $email_config = get_email_config_for_menu($dbh, $client_id);
	my $config_complete = ($email_config->{imap_server} && $email_config->{imap_username} && $email_config->{imap_password}) ? 1 : 0;
	
	#/************ IMPORT AUTOMATIQUE *************/
	# Si la config est complète ET qu'on n'est PAS en train de modifier la config
	# → lancer l'import automatiquement à chaque ouverture du panneau
	if ($config_complete && !defined $args->{email_config}) {
		$message = run_auto_import($r, $dbh, $email_config);
	}
	
	#/************ SAUVEGARDE CONFIG *************/
	# L'utilisateur a soumis le formulaire de configuration
	if (defined $args->{email_config} && $args->{email_config} eq 'save') {
		
		unless ($args->{imap_server} && $args->{imap_username} && $args->{imap_password}) {
			$message = 'Tous les champs sont obligatoires (serveur, email, mot de passe)';
		} else {
			# Sauvegarder TOUTE la config (y compris mot de passe)
			save_email_config_for_menu($dbh, $client_id, {
				imap_server   => $args->{imap_server},
				imap_username => $args->{imap_username},
				imap_password => $args->{imap_password},
				imap_port     => $args->{imap_port} || 993,
				imap_ssl      => $args->{imap_ssl} // 1,
			});
			
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 
				'menu.pm => Configuration email IMAP sauvegardée');
			
			# Recharger la config et lancer l'import immédiatement
			$email_config = get_email_config_for_menu($dbh, $client_id);
			$message = 'Configuration sauvegardée. ' . run_auto_import($r, $dbh, $email_config);
		}
	}

	############## MISE EN FORME DEBUT ##############
	my $contenu_web_ecri_rec = '';
	
	if ($config_complete && !defined $args->{email_config}) {
		# Mode automatique : afficher résultat + bouton pour modifier la config
		$contenu_web_ecri_rec .= '
		<div class="Titre10 centrer"><a class=aperso2>Import Factures Email (automatique)</a></div>
		<div class="form-int">
		<p><strong>Compte email :</strong> ' . ($email_config->{imap_username} || '') . '</p>
		<p><strong>Serveur :</strong> ' . ($email_config->{imap_server} || '') . '</p>
		</div>';
		
		if ($message) {
			$contenu_web_ecri_rec .= Base::Site::util::generate_error_message($message);
		}
		
		# Bouton modifier la config
		$contenu_web_ecri_rec .= '
		<form class=wrapper1 action="' . $r->uri() . '" method="POST">
		<input type=hidden name="menu13" value="1">
		<input type=hidden name="email_config" value="edit">
		<div class=formflexN3 style="margin-top: 1em;">
		<input type=submit style="width: 30%;" class="btn btn-orange" value="Modifier la configuration">
		</div>
		</form>';
		
	} else {
		# Mode configuration : afficher le formulaire complet
		$contenu_web_ecri_rec .= '
		<div class="Titre10 centrer"><a class=aperso2>Configuration Import Email (IMAP)</a></div>
		<form class=wrapper1 action="' . $r->uri() . '" method="POST">
		<input type=hidden name="menu13" value="1">
		<input type=hidden name="email_config" value="save">
		
		<div class=formflexN2>
		<label style="width: 40%;" class="forms2_label">Serveur IMAP: <input type="text" name="imap_server" value="' . ($email_config->{imap_server} || 'imap.gmail.com') . '" class="forms2_input" style="width: 60%;"></label>
		<label style="width: 40%;" class="forms2_label">Email: <input type="email" name="imap_username" value="' . ($email_config->{imap_username} || '') . '" class="forms2_input" style="width: 60%;"></label>
		</div>
		
		<div class=formflexN2>
		<label style="width: 40%;" class="forms2_label">Mot de passe: <input type="password" name="imap_password" value="' . ($email_config->{imap_password} || '') . '" class="forms2_input" style="width: 60%;"></label>
		<label style="width: 40%;" class="forms2_label">Port: <input type="number" name="imap_port" value="' . ($email_config->{imap_port} || '993') . '" class="forms2_input" style="width: 60%;"></label>
		</div>
		
		<div class=formflexN2 style="margin-top: 1em;">
		<label style="width: 40%;"><input type="checkbox" name="imap_ssl" value="1" ' . (($email_config->{imap_ssl} // 1) ? 'checked' : '') . '> SSL/TLS</label>
		</div>
		
		<div class=formflexN3 style="margin-top: 1.5em;">
		<input type=submit id=submit_'.$reqid.' style="width: 30%;" class="btn btn-vert" value="Sauvegarder et importer">
		</div>

		</form>';
		
		if ($message) {
			$contenu_web_ecri_rec .= Base::Site::util::generate_error_message($message);
		}
	}

	return $contenu_web_ecri_rec ;

}#sub forms_email_import

#/*—————————————— Import automatique (appelé sans intervention utilisateur) ——————————————*/
sub run_auto_import {
	my ($r, $dbh, $email_config) = @_;
	
	my $message = '';
	
	# Configuration IMAP depuis config sauvegardée
	my $imap_config = {
		server   => $email_config->{imap_server},
		port     => $email_config->{imap_port} || 993,
		username => $email_config->{imap_username},
		password => $email_config->{imap_password},
		ssl      => $email_config->{imap_ssl} // 1,
		folder   => 'INBOX',
	};
	
	# Configuration stockage
	my $storage_config = {
		base_dir    => $r->document_root() . '/Compta/base/documents/',
		client_id   => $r->pnotes('session')->{id_client},
		fiscal_year => $r->pnotes('session')->{fiscal_year},
	};
	
	# Lancer l'import (anti-duplicata géré par EmailReceiver)
	my @imported;
	eval {
		@imported = @{Base::Service::EmailReceiver::process_inbox_and_save(
			$imap_config,
			$storage_config,
			$dbh
		)};
	};
	
	if ($@) {
		$message = 'Erreur connexion email: ' . $@;
		Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 
			'menu.pm => Import email auto erreur: ' . $@);
	} elsif (scalar(@imported) > 0) {
		$message = scalar(@imported) . ' nouvelle(s) facture(s) importée(s) automatiquement.';
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 
			'menu.pm => Import email auto: ' . $message);
	} else {
		$message = 'Aucune nouvelle facture trouvée.';
	}
	
	return $message;
}

# Fonction utilitaire: récupérer config email (y compris mot de passe)
sub get_email_config_for_menu {
	my ($dbh, $client_id) = @_;
	
	my $sql = 'SELECT config_libelle, config_compte FROM tblconfig_liste 
			   WHERE id_client = ? AND module = ?';
	my $rows = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $client_id, 'email_imap') };
	
	my %config;
	if ($rows) {
		foreach my $row (@$rows) {
			$config{$row->{config_libelle}} = $row->{config_compte};
		}
	}
	
	$config{imap_port} = int($config{imap_port}) if $config{imap_port};
	$config{imap_ssl} = (defined $config{imap_ssl} && ($config{imap_ssl} eq '1' || $config{imap_ssl} eq 't')) ? 1 : 0;
	
	return \%config;
}

# Fonction utilitaire: sauvegarder TOUTE la config email (y compris mot de passe)
sub save_email_config_for_menu {
	my ($dbh, $client_id, $config) = @_;
	
	foreach my $key (keys %$config) {
		my $sql_delete = 'DELETE FROM tblconfig_liste WHERE id_client = ? AND module = ? AND config_libelle = ?';
		$dbh->do($sql_delete, undef, $client_id, 'email_imap', $key);
		
		if (defined $config->{$key} && $config->{$key} ne '') {
			my $sql_insert = 'INSERT INTO tblconfig_liste (id_client, module, config_libelle, config_compte) VALUES (?, ?, ?, ?)';
			$dbh->do($sql_insert, undef, $client_id, 'email_imap', $key, $config->{$key});
		}
	}
}

#/*—————————————— Formulaire Saisie d'un paiement (1 écriture) ——————————————*/
sub forms_paiement_saisie {

	# définition des variables
	my ( $r, $args, $dbh ) = @_ ;
    my ( $sql, @bind_array, $content ) ;
	my $reqid = Base::Site::util::generate_reqline();
	
    #my $http_link = (defined $args->{id_name} && $args->{id_name} ne '') ? 'docsentry?id_name=' . $args->{id_name}.'&' : 'menu?';
   
	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	# récupération des variables de docsentry.pm
	my ($date_comptant, $montant_entry);
	if (defined $args->{date_doc_entry}) {$date_comptant = $args->{date_doc_entry} ;}
	if (defined $args->{montant_doc_entry}) {$montant_entry = $args->{montant_doc_entry} ;}
	
	# Récupérer la valeur de la méthode d'importation actuelle
	my $current_saisie_method_level1 = $args->{saisie_method_level1} || 'recette';  # Par défaut à 'file'
	my $current_saisie_method = $args->{saisie_method} || 'recette_1';  # Par défaut à 'file'
	
	my $checkbox_value = $args->{check_comptant} // '0';
    my $checked = $checkbox_value eq '1' ? 'checked' : '';
    
 	#/************ ACTION DEBUT *************/

	# Gestion des options Saisie rapide d'une tâche comptable (http://172.17.0.2/base/menu?saisie_rapide&scenario=reprise_depreciation)
	if ( defined $args->{saisie_rapide} and defined $args->{scenario} and $args->{scenario} ne '' ) {
		
		if (not defined $args->{date_comptant}){
		#en 1ère arrivée, mettre la date du jour par défaut ou date de fin d'exercice
		my $date_1 = localtime->strftime('%Y-%m-%d');
		my $date_2 = $r->pnotes('session')->{Exercice_fin_YMD} ;
		if ($date_1 gt $date_2) {$args->{date_comptant} = eval {Time::Piece->strptime($date_2, "%Y-%m-%d")->dmy("/")}; } else {$args->{date_comptant} = eval {Time::Piece->strptime($date_1, "%Y-%m-%d")->dmy("/")};}
		}
		
		#Ligne1512 pour les options du select 
		if ( $args->{scenario} eq 'reprise_depreciation' ) {
			$args->{depense_4_Link} = 1;
			$args->{depense_4} = 'Le client règle finalement une créance douteuse ou litigieuse, cette écriture va annuler la dépréciation qui avait été constatée :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Crédit :</strong> 78174 – Reprise sur dépréciation des créances (Mode de paiement => Reprise provision)</p>
			<p><strong>Débit :</strong> 491 – Dépréciations des comptes clients (Compte de tiers)</p>
			<br>Ensuite, il est nécessaire de constater le règlement de cette créance via Débit 512-Banque et Crédit 416-Clients douteux</p>';
			if ($args->{saisie_rapide} eq '') {
				my $ensure_account_exists = Base::Site::bdd::ensure_account_exists($dbh, $r, '781740', 'Reprise provision sur créances');
				my $ensure_account_exists_491 = Base::Site::bdd::ensure_account_exists($dbh, $r, '491000', 'Dépréciations des comptes clients');
				if ($ensure_account_exists && $ensure_account_exists ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 781740 : Reprise provision sur créances");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 781740 : Reprise provision sur créances');
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '781740', 'Reprise provision', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du mode de paiement Reprise provision");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Reprise provision');
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '781740', 1);
						$args->{select_achats} = $param_libelle;
						$args->{compte_autres} = '491000';
						$args->{libelle}       = 'Reprise dépréciation suite réglement';
						$current_saisie_method = 'depense_4';
						$current_saisie_method_level1 = 'depense';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'depreciation' ) {
			$args->{recette_4_Link} = 1;
			$args->{recette_4} = 'En fin d’exercice, si une forte probabilité de perte sur une créance client est identifiée, cette écriture permet de comptabiliser une provision pour dépréciation des créances clients :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Débit :</strong> 68174 – Dotations aux dépréciations des créances (Mode de paiement => Dotations dépréciations)</p>
			<p><strong>Crédit :</strong> 491 – Dépréciations des comptes clients (Compte de tiers)</p>
			<br><strong>Étape préalable :</strong> Avoir transféré la créance identifiée comme douteuse dans un compte 416 « Clients douteux » via Débit 416-Clients douteux et Crédit 411-Clients.</p>';
			if ($args->{saisie_rapide} eq '') {
				my $ensure_account_exists = Base::Site::bdd::ensure_account_exists($dbh, $r, '681740', 'Dotations aux dépréciations des créances');
				my $ensure_account_exists_491 = Base::Site::bdd::ensure_account_exists($dbh, $r, '491000', 'Dépréciations des comptes clients');
				if ($ensure_account_exists && $ensure_account_exists ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 681740 : Dotations aux dépréciations des créances");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 681740 : Dotations aux dépréciations des créances');
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '681740', 'Dotations dépréciations', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du mode de paiement Dotations dépréciations");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Dotations dépréciations');
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '681740', 1);
						$args->{select_achats} = $param_libelle;
						$args->{compte_autres} = '491000';
						$args->{libelle}       = 'Provision dépréciation créance client X';
						$current_saisie_method = 'recette_4';
						$current_saisie_method_level1 = 'recette';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'transfert_client_douteux' ) {
			$args->{recette_2_Link} = 1;
			$args->{recette_2} = 'Lorsqu’une créance client devient douteuse, il faut la transférer en comptabilité dans le compte dédié :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Débit :</strong> 416 – Clients douteux (Mode de paiement => Clients douteux 416)</p>
			<p><strong>Crédit :</strong> 411 – Clients (Compte clients)</p>
			<br><strong>Étape suivante :</strong> comptabiliser une dépréciation via Débit 681740-Dotations aux dépréciation et Crédit 491-Dépréciations des comptes clients.</p>';
			if ($args->{saisie_rapide} eq '') {
				my $ensure_account_exists_416 = Base::Site::bdd::ensure_account_exists($dbh, $r, '416000', 'Clients douteux');
				if ($ensure_account_exists_416 && $ensure_account_exists_416 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username},"menu.pm => Erreur lors de l'enregistrement du compte 41600 : Clients douteux");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 41600 : Clients douteux ');
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '416000', 'Clients douteux 416', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username},"menu.pm => Erreur lors de l'enregistrement du mode de paiement Transfert Clients douteux");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Transfert Clients douteux');
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '416000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{libelle}       = 'Transfert en Clients douteux';
						$current_saisie_method = 'recette_2';
						$current_saisie_method_level1 = 'recette';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'depot_garantie' ) {
			$args->{depense_4_Link} = 1;
			$args->{depense_4} = 'Permet de comptabiliser l\'appel d\'un dépôt de garantie d\'un client :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Crédit :</strong> 165 – Dépôts et cautionnements reçus (Mode de paiement => Dépôt de garantie)</p>
			<p><strong>Débit :</strong> 411 – Clients (Compte client)</p>';
			if ($args->{saisie_rapide} eq '') {
				my $ensure_account_exists_165 = Base::Site::bdd::ensure_account_exists($dbh, $r, '165000', 'Dépôts et cautionnements reçus');
				if ($ensure_account_exists_165 && $ensure_account_exists_165 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 
						"menu.pm => Erreur lors de l'enregistrement des comptes 165 : Dépôts et cautionnements reçus");
					$content .= Base::Site::util::generate_error_message(
						'Erreur lors de l\'enregistrement des comptes 165 : Dépôts et cautionnements reçus'
					);
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '165000', 'Dépôt de garantie', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 
							"menu.pm => Erreur lors de l'enregistrement du mode de paiement Dépôt de garantie");
						$content .= Base::Site::util::generate_error_message(
							'Erreur lors de l\'enregistrement du mode de paiement Dépôt de garantie'
						);
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '165000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{libelle}       = 'Appel dépôt de garantie';
						$current_saisie_method = 'depense_4';
						$current_saisie_method_level1 = 'depense';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'remboursement_depot_garantie' ) {
			$args->{recette_2_Link} = 1;
			$args->{recette_2} = 'Permet de comptabiliser le remboursement total d’un dépôt de garantie au client :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Débit :</strong> 165 – Dépôts et cautionnements reçus (Mode de paiement => Dépôt de garantie)</p>
			<p><strong>Crédit :</strong> 411 – Clients (Compte de tiers)</p>
			<br><strong>Étape suivante :</strong> Remboursement en banque, ou retenu impayé ou retenu dégradation.</p>';
			if ($args->{saisie_rapide} eq '') {
				my $ensure_account_exists_165 = Base::Site::bdd::ensure_account_exists($dbh, $r, '165000', 'Dépôts et cautionnements reçus');
				if ($ensure_account_exists_165 && $ensure_account_exists_165 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 
						"menu.pm => Erreur lors de l'enregistrement des comptes 165 : Dépôts et cautionnements reçus");
					$content .= Base::Site::util::generate_error_message(
						'Erreur lors de l\'enregistrement des comptes 165 : Dépôts et cautionnements reçus'
					);
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '165000', 'Remboursement dépôt de garantie', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 
							"menu.pm => Erreur lors de l'enregistrement du mode de paiement Remboursement dépôt de garantie");
						$content .= Base::Site::util::generate_error_message(
							'Erreur lors de l\'enregistrement du mode de paiement Remboursement dépôt de garantie'
						);
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '165000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{libelle}       = 'Remboursement dépôt de garantie client';
						$current_saisie_method = 'recette_2';
						$current_saisie_method_level1 = 'recette';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'creance_irrecouvrable' ) {
			$args->{depense_1_Link} = 1;
			$args->{depense_1} = 'Lorsqu’une créance est définitivement jugée irrécouvrable, cette écriture permet de la comptabiliser comme une perte :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Crédit :</strong> 416 - Clients douteux (Mode de paiement => Clients douteux 416)</p>
			<p><strong>Débit :</strong> 654 - Perte sur créances irrécouvrables (Compte de charge)</p>
			<br><strong>Étape préalable :</strong> Si la créance avait fait l’objet d’une dépréciation, il convient de la reprendre.</p>
			';
			if ($args->{saisie_rapide} eq '') {
				# Validation et création des comptes nécessaires
				my $ensure_account_exists_654 = Base::Site::bdd::ensure_account_exists($dbh, $r, '654000', 'Perte sur créances irrécouvrables');
				my $ensure_account_exists_416 = Base::Site::bdd::ensure_account_exists($dbh, $r, '416000', 'Clients douteux');
				if ($ensure_account_exists_654 && $ensure_account_exists_654 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 654000 : Perte sur créances irrécouvrables");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 654000 : Perte sur créances irrécouvrables');
				} elsif ($ensure_account_exists_416 && $ensure_account_exists_416 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 416000 : Clients douteux");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 416000 : Clients douteux');
				} else {
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '416000', 'Clients douteux 416', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username},"menu.pm => Erreur lors de l'enregistrement du mode de paiement Clients douteux 416");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Clients douteux 416');
					} else {
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '416000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{compte_charge} = '654000';
						$args->{libelle}       = 'Perte sur créance client irrécouvrable';
						$current_saisie_method = 'depense_1';
						$current_saisie_method_level1 = 'depense';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'impot_benefices' ) {
			$args->{depense_1_Link} = 1;
			$args->{depense_1} = 'Cette écriture comptabilise l\'évaluation de l’impôt sur les bénéfices N lors de la clôture de l\'exercice:</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Crédit :</strong> 444 - État, Impôts sur les bénéfices (Mode de paiement => Impôts sur les bénéfices)</p>
			<p><strong>Débit :</strong> 695 - Impôts sur les bénéfices (Compte de charge)</p>
			';
			my $calcul_impot = Base::Site::bdd::calculate_is_from_balance($dbh, $r, $r->pnotes('session')->{fiscal_year});
			if ($args->{saisie_rapide} eq '') {
				# Validation et création des comptes nécessaires
				my $ensure_account_exists_695 = Base::Site::bdd::ensure_account_exists($dbh, $r, '695000', 'Impôts sur les bénéfices');
				my $ensure_account_exists_444 = Base::Site::bdd::ensure_account_exists($dbh, $r, '444000', 'État, Impôts sur les bénéfices');
				# Vérification des comptes
				if ($ensure_account_exists_695 && $ensure_account_exists_695 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 695000 : Impôts sur les bénéfices");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 695000 : Impôts sur les bénéfices');
				} elsif ($ensure_account_exists_444 && $ensure_account_exists_444 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 444000 : État, Impôts sur les bénéfices");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 444000 : État, Impôts sur les bénéfices');
				} else {
					# Validation du mode de paiement
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '444000', 'Impôts sur les bénéfices', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du mode de paiement Impôts sur les bénéfices");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Impôts sur les bénéfices');
					} else {
						# Création de la pièce comptable
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '444000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{compte_charge} = '695000';
						$args->{libelle}       = 'Comptabilisation de l\'impôt sur les bénéfices';
						$current_saisie_method = 'depense_1';
						$current_saisie_method_level1 = 'depense';
						$args->{montant} = $calcul_impot || '';
						$args->{aidemontant} = 'L\'impôt sur les sociétés est calculé en soustrayant les soldes des comptes de charges (classe 6), du déficit (compte 695000), des pénalités (compte 671200), et des autres comptes spécifiques du chiffre d\'affaires (classe 7), puis en appliquant un taux de 15% sur les premiers 42 500 € de bénéfice et 25% sur le reste, avec un arrondi final à l\'euro le plus proche.';
					}
				}
			}
		} elsif ( $args->{scenario} eq 'avis_imposition' ) {
			$args->{depense_1_Link} = 1;
			$args->{depense_1} = 'Cette écriture comptabilise une charge d\'impôt (provision ou avis) :</p>
			<p>(Journal OD – Opérations diverses)</p>
			<p><strong>Crédit :</strong> 447 - État, Taxes à payer (Mode de paiement => Provision/Avis d\'impôts)</p>
			<p><strong>Débit :</strong> 635 - Impôts et taxes (Compte de charge)</p>';
			
			if ($args->{saisie_rapide} eq '') {
				# Validation et création des comptes nécessaires
				my $ensure_account_exists_635 = Base::Site::bdd::ensure_account_exists($dbh, $r, '635000', 'Impôts et taxes');
				my $ensure_account_exists_447 = Base::Site::bdd::ensure_account_exists($dbh, $r, '447000', 'État, Taxes à payer');
				
				# Vérification des comptes
				if ($ensure_account_exists_635 && $ensure_account_exists_635 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 635000 : Impôts et taxes");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 635000 : Impôts et taxes');
				} elsif ($ensure_account_exists_447 && $ensure_account_exists_447 ne '') {
					Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du compte 447000 : État, Taxes à payer");
					$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du compte 447000 : État, Taxes à payer');
				} else {
					# Validation du mode de paiement pour le compte 447
					my $ensure_payment_method_exists = Base::Site::bdd::ensure_payment_method_exists($dbh, $r, '447000', 'Provision/Avis d\'impôts', 'OD');
					if ($ensure_payment_method_exists && $ensure_payment_method_exists ne '') {
						Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "menu.pm => Erreur lors de l'enregistrement du mode de paiement Avis d'imposition");
						$content .= Base::Site::util::generate_error_message('Erreur lors de l\'enregistrement du mode de paiement Avis d\'imposition');
					} else {
						# Création de la pièce comptable
						$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $args->{date_comptant});
						my ($param_journal, $param_compte, $param_libcompte, $param_libelle) = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, '447000', 1);
						$args->{select_achats} = $param_libelle;
						$args->{compte_charge} = '635000';
						$args->{libelle}       = 'Réception avis d\'imposition';
						$current_saisie_method = 'depense_1';
						$current_saisie_method_level1 = 'depense';
					}
				}
			}
		}




	}
	
	# Récupérer le journal, compte et libellé compte du mode de paiement 
	my ($param_journal, $param_compte, $param_libcompte) = Base::Site::bdd::get_parametres_reglements($dbh, $r, $args->{select_achats}, undef, 1);
	my $journal_info = Base::Site::util::get_journal_info($r, $dbh);
	my $lib_journal_achats = $journal_info->{'Achats'};
	my $lib_journal_ventes = $journal_info->{'Ventes'};
	$args->{lib_journal_ventes} = $journal_info->{'Ventes'};
	$args->{lib_journal_achats} = $journal_info->{'Achats'};
	
	#demande confirmation achat_comptant 								
	#menu?date_comptant=2020-12-31&compte_comptant=401CAAE&libelle=test&montant=100.00&select_achats=default_caisse_journal%21%21CAISSE&docs1=&docs2=&achat_comptant=0
    if ( defined $args->{saisie_rapide} and $args->{saisie_rapide} eq '0' ) {
		
		my $erreur= '';
		
		if ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_1' ) {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (2, 3, 8, 10, 11));
			
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2;
				# Demande Création écriture Recette 1 écritures (Compte trésorerie)	
				$message2 = 'Voulez-vous vraiment créer l\'écriture de recette suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$debit = $args->{montant};
					} elsif ($i == 2) {$compte = $args->{compte_produit};$credit = $args->{montant};} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}
			
			
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_2') {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (2, 3, 4, 8, 10));
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2 = 'Voulez-vous vraiment créer l\'écriture du réglement client suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {	$compte = $args->{compte_client}; 	$credit = $args->{montant};
					} elsif ($i == 2) {		$debit = $args->{montant}; } 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_4') {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (2, 3, 17, 8, 10));
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2 = 'Voulez-vous vraiment créer l\'écriture autre entrée d\'argent suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {	$compte = $args->{compte_autres}; 	$credit = $args->{montant};
					} elsif ($i == 2) {		$debit = $args->{montant}; } 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_6' ) {
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (14, 16, 2, 3, 8, 10, 11));
			
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2;
				my $compte_client2 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_client2});
				my $compte_produit = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_produit});
				# Demande Création écriture Recette 2 écritures (Client + comptant)
				$message2 .= 'Voulez-vous vraiment créer les écritures suivantes :<br><br>';
				my @data = ();
				for my $i (1 .. 4) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$journal = $lib_journal_ventes;$debit = $args->{montant};$compte = $args->{compte_client2};
					} elsif ($i == 2) {$journal = $lib_journal_ventes;$compte = $args->{compte_produit};$credit = $args->{montant};
					} elsif ($i == 3) {$compte = $args->{compte_client2};$credit = $args->{montant};
					} elsif ($i == 4) {$debit = $args->{montant};} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_5' ) {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (14, 16, 3, 8, 10, 11));	
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2;
				my $compte_client2 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_client2});
				my $compte_produit = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_produit});
				$message2 = 'Voulez-vous vraiment créer l\'écriture de recette suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $lib_journal_ventes || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$debit = $args->{montant};$compte = $args->{compte_client2};
					} elsif ($i == 2) {$compte = $args->{compte_produit};$credit = $args->{montant};} 
					push @data, {
					date_comptant => $args->{date_comptant} || '&nbsp;',
					journal => $journal,
					compte => $compte,
					piece => $args->{piece} || '&nbsp;',
					libelle => $args->{libelle} || '&nbsp;',
					debit => $debit,
					credit => $credit,
					scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}
			
		} if ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_1' ) {
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (2, 3, 8, 10, 12));
			
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				# Demande Création écriture dépense 1 écritures (Compte Trésorerie)
				my $message2 = 'Voulez-vous vraiment créer l\'écriture de dépense suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$credit = $args->{montant};
					} elsif ($i == 2) {$compte = $args->{compte_charge};$debit = $args->{montant};} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
						};
					}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_2') {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (1, 2, 3, 8, 10));
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2 = 'Voulez-vous vraiment créer l\'écriture de réglement fournisseur suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {	$compte = $args->{compte_fournisseur}; 	$debit = $args->{montant};
					} elsif ($i == 2) { 	$credit = $args->{montant};	} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);		
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_4') {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (17, 2, 3, 8, 10));
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2 = 'Voulez-vous vraiment créer l\'écriture autre sortie d\'argent suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {	$compte = $args->{compte_autres}; 	$debit = $args->{montant};
					} elsif ($i == 2) {		$credit = $args->{montant}; } 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_6' ) {
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (13, 15, 2, 3, 8, 10, 12));
			# Demande Création écriture dépense 2 écritures (Fournisseur + comptant)
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2;
				my $compte_client2 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_client2});
				my $compte_produit = Base::Site::bdd::get_comptes_by_classe($dbh, $r, $args->{compte_produit});
				# Demande Création écriture Recette 2 écritures (Client + comptant)
				$message2 .= 'Voulez-vous vraiment créer les écritures suivantes :<br><br>';
				my @data = ();
				for my $i (1 .. 4) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$journal=$lib_journal_achats;$credit = $args->{montant};$compte = $args->{compte_fournisseur2};
					} elsif ($i == 2) {$journal=$lib_journal_achats;$compte = $args->{compte_charge};$debit = $args->{montant};
					} elsif ($i == 3) {$compte = $args->{compte_fournisseur2};$debit = $args->{montant};
					} elsif ($i == 4) {$credit = $args->{montant};} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}

				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}

		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_5' ) {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (15, 3, 8, 10, 12));
			# Demande Création écriture dépense 1 écritures (Fournisseur)	
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				my $message2 = 'Voulez-vous vraiment créer l\'écriture de dépense suivante : <br><br>';
				my @data = ();
				for my $i (1 .. 2) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $lib_journal_achats || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {$credit = $args->{montant};$compte = $args->{compte_fournisseur2};
					} elsif ($i == 2) {$compte = $args->{compte_charge};$debit = $args->{montant};} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
						};
					}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}
			
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'transfert_1' ) {
			
			$erreur = Base::Site::util::verifier_args_obligatoires($r, $args, (3, 6, 7, 8, 10));
			if ($erreur) {
				$content .= Base::Site::util::generate_error_message($erreur);  # Affichez le message d'erreur
			} else {
				# Récupérer le journal, compte et libellé compte du mode de paiement 
				my ($param_journal2, $param_compte2, $param_libcompte2) = Base::Site::bdd::get_parametres_reglements($dbh, $r, $args->{id_compte_2_select});
				my $message2 .= 'Voulez-vous vraiment créer les écritures suivantes de transfert entre compte:<br><br>';
				my @data = ();
				for my $i (1 .. 4) {
					my ($compte, $journal, $debit, $credit) = ($param_compte || '&nbsp;', $param_journal || '&nbsp;', '0.00', '0.00');
					if ($i == 1) {		$credit = $args->{montant};	
					} elsif ($i == 2) {	$debit = $args->{montant};	$compte = '580000';
					} elsif ($i == 3) {	$credit = $args->{montant};	$compte = '580000';			$journal = $param_journal2;
					} elsif ($i == 4) {	$debit = $args->{montant};	$compte = $param_compte2;	$journal = $param_journal2;} 
					push @data, {
						date_comptant => $args->{date_comptant} || '&nbsp;',
						journal => $journal ,
						compte => $compte,
						piece => $args->{piece} || '&nbsp;',
						libelle => $args->{libelle} || '&nbsp;',
						debit => $debit,
						credit => $credit,
						scenario => $args->{scenario} || '',
					};
				}
				$message2 .= Base::Site::util::generate_custom_table(\@data);
			 #. ($args->{id_compte_2_select} || '') 
				my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'saisie_rapide', $args->{saisie_rapide}, $hidden_fields);
				$content .= Base::Site::util::generate_error_message($confirmation_message);
			}
			
		}

    } elsif ( defined $args->{saisie_rapide} and $args->{saisie_rapide} eq '1' ) {
		
		if ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_1' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 5);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_6' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 9);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_2' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 3);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_4' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 11);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'recette_5' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 7);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_1' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 6);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_6' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 10);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_2' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 4);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_4' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 12);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'depense_5' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 8);
		} elsif ( defined $args->{saisie_method} and $args->{saisie_method} eq 'transfert_1' ) {
			$content .=	Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 1);			
		}
		
	}
	
	#/************ ACTION FIN *************/
			
	#####################################       
	# Récupérations d'informations		#
	#####################################  
	
	my $compte1 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '165,7');
	my ($selected1, $form_name1, $form_id1)  = ($args->{compte_produit}, 'compte_produit', 'compte_produit_'.$reqid.'');
	my $onchange1 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"';
	my $compte_produit = Base::Site::util::generate_compte_selector($compte1, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style="width: 18%;"');
	my $onchange2 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"';
	my $compte2 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '6');
	my ($selected2, $form_name2, $form_id2)  = ($args->{compte_charge}, 'compte_charge', 'compte_charge_'.$reqid.'');
	my $compte_charge = Base::Site::util::generate_compte_selector($compte2, $reqid, $selected2, $form_name2, $form_id2, $onchange2, 'class="forms2_input"', 'style="width: 18%;"');

	#Requête et Formulaire numero compte 4 et ??
	my $bdd_compte_autres = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '4');
	my $selected_autres = (defined($args->{compte_autres}) && $args->{compte_autres} ne '') ? ($args->{compte_autres} ) : undef;
	my ($form_name_autres, $form_id_autres )  = ('compte_autres', 'compte_autres_'.$reqid.'');
	my $onchange_autres = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};if (this.selectedIndex != 0 && this.value !== \'\') { select_contrepartie(this, \'compte_produit_' . $reqid . '\');}First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');"';
	my $compte_autres = Base::Site::util::generate_compte_selector($bdd_compte_autres, $reqid, $selected_autres, $form_name_autres, $form_id_autres, $onchange_autres, 'class="forms2_input"', 'style="width: 18%;"');
	
	#Requête et Formulaire numero compte 41
	my $bdd_compte4 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '41');
	my $selected4 = (defined($args->{compte_client}) && $args->{compte_client} ne '') ? ($args->{compte_client} ) : undef;
	my $selected42 = (defined($args->{compte_client2}) && $args->{compte_client2} ne '') ? ($args->{compte_client2} ) : undef;
	my ($form_name4, $form_id4 )  = ('compte_client', 'compte_client_'.$reqid.'');
	my $onchange4 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};if (this.selectedIndex != 0 && this.value !== \'\') { select_contrepartie(this, \'compte_produit_' . $reqid . '\');}First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');"';
	my $compte_client = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected4, $form_name4, $form_id4, $onchange4, 'class="forms2_input"', 'style="width: 18%;"');
	my $compte_client2 = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected42, 'compte_client2', 'compte_client2_'.$reqid.'', $onchange4, 'class="forms2_input"', 'style="width: 18%;"');
	
	#Requête et Formulaire numero compte 40
	my $bdd_compte5 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '40,44');
	my $selected5 = (defined($args->{compte_fournisseur}) && $args->{compte_fournisseur} ne '') ? ($args->{compte_fournisseur} ) : undef;
	my $selected52 = (defined($args->{compte_fournisseur2}) && $args->{compte_fournisseur2} ne '') ? ($args->{compte_fournisseur2} ) : undef;
	my ($form_name5, $form_id5)  = ('compte_fournisseur', 'compte_fournisseur_'.$reqid.'');
	my $onchange5 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};if (this.selectedIndex != 0 && this.value !== \'\') { select_contrepartie(this, \'compte_charge_' . $reqid . '\');}First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');"';
	my $compte_fournisseur = Base::Site::util::generate_compte_selector($bdd_compte5, $reqid, $selected5, $form_name5, $form_id5, $onchange5, 'class="forms2_input"', 'style="width: 18%;"');
	my $compte_fournisseur2 = Base::Site::util::generate_compte_selector($bdd_compte5, $reqid, $selected52, 'compte_fournisseur2', 'compte_fournisseur2_'.$reqid.'', $onchange5, 'class="forms2_input"', 'style="width: 18%;"');
	
	#Requête et Formulaire Règlements
	my $result_reglement_set;
	if ( defined $args->{saisie_rapide} and defined $args->{scenario} and $args->{scenario} ne '' ) {
		$result_reglement_set = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, undef, 1);
	} else {
		$result_reglement_set = Base::Site::bdd::get_parametres_reglements($dbh, $r);
	}
    my $selected3 = (defined($args->{select_achats}) && $args->{select_achats} ne '') ? ($args->{select_achats} ) : undef;
    my ($form_name3, $form_id3) = ('select_achats', 'select_achats_'.$reqid.'');
	my $onchange3 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'parametres?achats\'};First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');"';
	my $select_achats = Base::Site::util::generate_reglement_selector($result_reglement_set, $reqid, $selected3, $form_name3, $form_id3, $onchange3, 'class="forms2_input"', 'style="width: 13%;"');
	
	my $selected6 = (defined($args->{id_compte_2_select}) && $args->{id_compte_2_select} ne '') ? ($args->{id_compte_2_select} ) : undef;
    my ($form_name6, $form_id6) = ('id_compte_2_select', 'id_compte_2_select_'.$reqid.'');
	my $id_compte_2_select = Base::Site::util::generate_reglement_selector($result_reglement_set, $reqid, $selected6, $form_name6, $form_id6, '', 'class="forms2_input"', 'style="width: 13%;"');

    # Génération formulaire choix de documents
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $onchange_type = 'onchange="if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};"';
	my ($form_name_doc1, $form_id_doc1) = ('docs1', 'docs1_'.$reqid.'');
	my ($form_name_doc2, $form_id_doc2) = ('docs2', 'docs2_'.$reqid.'');
	my $selected_document1 = (defined($args->{docs1}) && $args->{docs1} ne '') || (defined($args->{id_name}) && defined($args->{label8}) && $args->{label8} eq '1') ? ($args->{docs1} || $args->{id_name}) : undef;
	my $selected_document2 = (defined($args->{docs2}) && $args->{docs2} ne '') || (defined($args->{id_name}) && defined($args->{label9}) && $args->{label9} eq '1') ? ($args->{docs2} || $args->{id_name}) : undef;
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected_document1, $form_name_doc1, $form_id_doc1, $onchange_type, 'class=forms2_input', 'style="width: 26%;"');
	my $document_select2 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected_document2, $form_name_doc2, $form_id_doc2, $onchange_type, 'class=forms2_input', 'style="width: 26%;"');
	
	if ( defined $args->{saisie_method} and $args->{saisie_method} eq 'comptant' ) {
		# Récupère le type de journal Achats et calcul le numéro de pièce.
		my ($lib_journal, $code_journal, $numero_piece) = ('', '', '');
		my $journaux = Base::Site::bdd::get_journaux($dbh, $r);
		for my $row (@$journaux) {if ($row->{type_journal} eq 'Achats') {($lib_journal, $code_journal) = ($row->{libelle_journal}, $row->{code_journal});last;}}
		if (defined $args->{date_comptant} && $args->{date_comptant} ne '') {
		$numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $lib_journal, $args->{date_comptant});
		} elsif (defined $date_comptant && $date_comptant ne '') {
		$numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $lib_journal, $date_comptant);	
		}
	}
	
	my ($recette_n2, $depense_n2, $compte_client_engagement ,$compte_fournisseur_engagement, $label_engagement, $input_reg_client, $input_reg_fournisseur, $check_comptant, $label_check) = ('', '', '' , '', '', '', '', '', '');
	if ($r->pnotes('session')->{type_compta} eq 'engagement') {
		$compte_client_engagement = $compte_client2;
		$compte_fournisseur_engagement = $compte_fournisseur2;
		$label_engagement = '<label id="label3" style="width: 18%;" class="forms2_label" for="'.$form_id2.'">Compte</label>';
		#$label_check = '<label id="label4" style="width: 5%;" class="forms2_label" for="check_comptant">Comptant</label>';
		$input_reg_client = '<input class="custom-radio" type="radio" id="saisie_client" name="saisie_method" value="client"' . ($current_saisie_method eq 'client' ? ' checked' : '') . ' onclick="ToggleMenu()">
		<label for="saisie_client">Règl. Client</label> ';
		$input_reg_fournisseur = '<input class="custom-radio" type="radio" id="saisie_fournisseur" name="saisie_method" value="fournisseur"' . ($current_saisie_method eq 'fournisseur' ? ' checked' : '') . ' onclick="ToggleMenu()">
		<label for="saisie_fournisseur">Règl. Fournisseur</label> ';
		#$check_comptant = '<input title="Cocher pour générer automatiquement les écritures bancaires associées." style="margin: 5px 5px;width: 5%; height: 4ch;" type="checkbox" id="check_comptant" name="check_comptant" value=1 '.$checked.'>
		#<input type="hidden" name="check_comptant" value="0">';
		$recette_n2 = '
				<input  class="custom-radio2" type="radio" id="saisie_recette_6" name="saisie_method" value="recette_6"' . ($current_saisie_method eq 'recette_6' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette_6\');">
				<label for="saisie_recette_6">Recette Comptant</label>
				<input class="custom-radio2" type="radio" id="saisie_recette_5" name="saisie_method" value="recette_5"' . ($current_saisie_method eq 'recette_5' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette_5\');">
				<label for="saisie_recette_5">Facture client</label>
				<input class="custom-radio2" type="radio" id="saisie_recette_2" name="saisie_method" value="recette_2"' . ($current_saisie_method eq 'recette_2' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette_2\');">
				<label for="saisie_recette_2">Règlement client</label>';
		$depense_n2 = '
				<input class="custom-radio2" type="radio" id="saisie_depense_6" name="saisie_method" value="depense_6"' . ($current_saisie_method eq 'depense_6' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense_6\');">
				<label for="saisie_depense_6">Dépense Comptant</label>
				<input class="custom-radio2" type="radio" id="saisie_depense_5" name="saisie_method" value="depense_5"' . ($current_saisie_method eq 'depense_5' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense_5\');">
				<label for="saisie_depense_5">Facture fournisseur</label>
				<input class="custom-radio2" type="radio" id="saisie_depense_2" name="saisie_method" value="depense_2"' . ($current_saisie_method eq 'depense_2' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense_2\');">
				<label for="saisie_depense_2">Règlement fournisseur</label>';
       
	}	
	############## MISE EN FORME DEBUT ##############
	
	my $contenuAide_default = "Texte par défaut ici.";
	my %contenuAide = (
    'recette_1' => $args->{recette_1} || 'Permet d\'enregistrer la recette sur le compte financier (classe 5) et créditer le compte de produit (classe 7).<p>(Journal du mode de paiement)</p><p><strong>Débit :</strong> 512000 – Banque (Compte financier)<br><strong>Crédit :</strong> 706000 – Prestation (Compte de produit)</p>',
    'recette' => $args->{recette} || 'Permet d\'enregistrer la recette sur le compte financier (classe 5) et créditer le compte de produit (classe 7).<p>(Journal du mode de paiement)</p><p><strong>Débit :</strong> 512000 – Banque (Compte financier)<br><strong>Crédit :</strong> 706000 – Prestation (Compte de produit)</p>',
    'recette_2' => $args->{recette_2} || 'Permet d\'enregistrer le règlement du client sur le compte financier (classe 5) et créditer son compte client 411.<p>(Journal du mode de paiement)</p><p><strong>Débit :</strong> 512000 – Banque (Compte financier)<br><strong>Crédit :</strong> 411100 – Client Toto (Compte de client)</p>',
    'recette_5' => $args->{recette_5} || 'Permet d\'enregistrer la facture du client sur son compte 411 et créditer le compte de produit (classe 7).<p>(Journal de Ventes)</p><p><strong>Débit :</strong> 411100 – Client Toto (Compte de client)</p><p><strong>Crédit :</strong> 706000 – Prestation (Compte de produit)</p>',
    'recette_6' => $args->{recette_6} || 'Permet d\'enregistrer deux écritures en une seule opération (lettrées automatiquement), la facture du client et son règlement :<p>1) Saisie de la facture du client sur son compte 411 et crédit du compte de produit (classe 7).</p><p>(Journal de Ventes)</p><p><strong>Débit :</strong> 411100 – Client Toto (Compte de client)</p><p><strong>Crédit :</strong> 706000 – Prestation (Compte de produit)</p><p>2) Saisie du règlement du client sur le compte financier (classe 5) et crédit de son compte client 411.</p><p>(Journal du mode de paiement)</p><p><strong>Débit :</strong> 512000 – Banque (Compte financier)</p><p><strong>Crédit :</strong> 411100 – Client Toto (Compte de client)</p>',
    'recette_4' => $args->{recette_4} || 'Permet d\'enregistrer une autre entrée d\'argent sur le compte financier (classe 5) et créditer un autre compte. (ex: apport d\'un associé)<p>(Journal du mode de paiement)</p><p><strong>Débit :</strong> 512000 – Banque (Compte financier)</p><p><strong>Crédit :</strong> 455000 – Associé (Compte courant de l\'associé)</p>',
    'depense_1' => $args->{depense_1} || 'Permet d\'enregistrer la dépense sur le compte financier (classe 5) et débiter le compte de charge (classe 6).<p>(Journal du mode de paiement)</p><p><strong>Crédit :</strong> 512000 – Prestation (Compte financier)</p><p><strong>Débit :</strong> 626100 – Frais postaux (Compte de charge)</p>',
    'depense' => $args->{depense} || 'Permet d\'enregistrer la dépense sur le compte financier (classe 5) et débiter le compte de charge (classe 6).<p>(Journal du mode de paiement)</p><p><strong>Crédit :</strong> 512000 – Prestation (Compte financier)</p><p><strong>Débit :</strong> 626100 – Frais postaux (Compte de charge)</p>',
    'depense_2' => $args->{depense_2} || 'Permet d\'enregistrer le règlement de la facture sur le compte financier (classe 5) et débiter le compte fournisseur 401.<p>(Journal du mode de paiement)</p><p><strong>Crédit :</strong> 512000 – Prestation (Compte financier)</p><p><strong>Débit :</strong> 401000 – Fournisseur (Compte fournisseur)</p>',
    'depense_5' => $args->{depense_5} || 'Permet d\'enregistrer la facture du fournisseur sur son compte 401 et débiter le compte de charge (classe 6).<p>(Journal d\'Achats)</p><p><strong>Crédit :</strong> 401100 – Fournisseur LM (Compte fournisseur)</p><p><strong>Débit :</strong> 626100 – Frais postaux (Compte de charge)</p>',
    'depense_6' => $args->{depense_6} || 'Permet d\'enregistrer deux écritures en une seule opération (lettrées automatiquement), la facture du fournisseur et son règlement :<p>1) Saisie de la facture du fournisseur sur son compte 401 et débit du compte de charge (classe 6).</p><p>(Journal d\'Achats)</p><p><strong>Crédit :</strong> 401100 – Fournisseur LM (Compte fournisseur)</p><p><strong>Débit :</strong> 626100 – Frais postaux (Compte de charge)</p><p>2) Saisie du règlement du fournisseur sur le compte financier (classe 5) et débit de son compte fournisseur 411.</p><p>(Journal du mode de paiement)</p><p><strong>Crédit :</strong> 512000 – Banque (Compte financier)</p><p><strong>Débit :</strong> 401100 – Fournisseur LM (Compte fournisseur)</p>',
    'depense_4' => $args->{depense_4} || 'Permet d\'enregistrer une autre sortie d\'argent sur le compte financier (classe 5) et débiter un autre compte. (ex: remboursement d\'un associé)<p>(Journal du mode de paiement)</p><p><strong>Crédit :</strong> 512000 – Banque (Compte financier)</p><p><strong>Débit :</strong> 455000 – Associé (Compte courant de l\'associé)</p>',
    'transfert_1' => $args->{transfert_1} || 'Permet d\'enregistrer les deux écritures de transfert passant par le compte d\'attente 580000 – Virement Interne grâce à une seule opération avec lettrage automatique.<p>1) Saisie de la première écriture depuis le compte Banque1 vers 580000 – Virement Interne</p><p>(Journal du mode de paiement 1)</p><p><strong>Crédit :</strong> 512100 – Banque 1 (Compte financier)</p><p><strong>Débit :</strong> 580000 – Virement Interne (compte virement interne)</p><p>2) Saisie de la deuxième écriture depuis 580000 – Virement Interne vers le compte Banque2</p><p>(Journal du mode de paiement 2)</p><p><strong>Crédit :</strong> 580000 – Virement Interne (compte virement interne)</p><p><strong>Débit :</strong> 512200 – Banque 2 (Compte financier)</p>',
	'transfert' => $args->{transfert} || 'Permet d\'enregistrer les deux écritures de transfert passant par le compte d\'attente 580000 – Virement Interne grâce à une seule opération avec lettrage automatique.<p>1) Saisie de la première écriture depuis le compte Banque1 vers 580000 – Virement Interne</p><p>(Journal du mode de paiement 1)</p><p><strong>Crédit :</strong> 512100 – Banque 1 (Compte financier)</p><p><strong>Débit :</strong> 580000 – Virement Interne (compte virement interne)</p><p>2) Saisie de la deuxième écriture depuis 580000 – Virement Interne vers le compte Banque2</p><p>(Journal du mode de paiement 2)</p><p><strong>Crédit :</strong> 580000 – Virement Interne (compte virement interne)</p><p><strong>Débit :</strong> 512200 – Banque 2 (Compte financier)</p>',
	);


	$args->{contenuAide} = \%contenuAide;
	$args->{contenuAide_default} = $contenuAide_default;

	# Ajout de la section JavaScript pour gérer l'affichage conditionnel
	my $contenu_web_ach_comptant .= '<script>
			
			const aideMessages = ' . to_json($args->{contenuAide}) . ';
			const contenuAideDefault = ' . to_json($args->{contenuAide_default}) . ';
			var scenario = ' . to_json($args->{scenario}) . ';

			function ToggleMenu(typeOperation) {
			
			let recette_1_Link = ' . to_json($args->{recette_1_Link}) . ' || 0;;
			let recette_2_Link = ' . to_json($args->{recette_2_Link}) . ' || 0;;
			let recette_4_Link = ' . to_json($args->{recette_4_Link}) . ' || 0;;
			let recette_5_Link = ' . to_json($args->{recette_5_Link}) . ' || 0;;
			let recette_6_Link = ' . to_json($args->{recette_6_Link}) . ' || 0;;
			let depense_1_Link = ' . to_json($args->{depense_1_Link}) . ' || 0;;
			let depense_2_Link = ' . to_json($args->{depense_2_Link}) . ' || 0;;
			let depense_4_Link = ' . to_json($args->{depense_4_Link}) . ' || 0;;
			let depense_5_Link = ' . to_json($args->{depense_5_Link}) . ' || 0;;
			let depense_6_Link = ' . to_json($args->{depense_6_Link}) . ' || 0;;
			let transfert_1_Link = ' . to_json($args->{transfert_1_Link}) . ' || 0;;
			let idname = ' . to_json($args->{id_name}) . ' || 0;;

			var select0 = document.getElementById("compte_charge_'.$reqid.'");
			var select1 = document.getElementById("compte_charge_'.$reqid.'");
            var select2 = document.getElementById("compte_produit_'.$reqid.'");
            var select3 = document.getElementById("compte_client_'.$reqid.'");
            var select4 = document.getElementById("compte_fournisseur_'.$reqid.'");
            var select5 = document.getElementById("id_compte_2_select_'.$reqid.'");
            var select6 = document.getElementById("compte_client2_'.$reqid.'");
            var select7 = document.getElementById("compte_fournisseur2_'.$reqid.'");
            var select8 = document.getElementById("compte_autres_'.$reqid.'");
            var select9 = document.getElementById("select_achats_'.$reqid.'");
			var labelElement1 = document.getElementById("label1");
            var labelElement2 = document.getElementById("label2");
            var labelElement3 = document.getElementById("label3");
            var labelElement4 = document.getElementById("label4");
            var memo1 = document.getElementById("memo1");
            
            // Liste des éléments
			const selectElements = [select0, select1, select2, select3, select4, select5, select6, select7, select8, select9];
			
			// Récupérer tous les champs <input> de type text
			var inputTextElements = document.querySelectorAll(\'input[type="text"]\'); // Correction ici

			// Réinitialisation des éléments <select> et des champs dans le formulaire avec l\'id "saisie_rapide"
			function resetSelects() {
				// Cibler le formulaire avec l\'id "saisierapide"
				const form = document.getElementById("saisierapide");
				
				// Si le formulaire existe
				if (form && Number(scenario) !== 0) {
					// Sélectionner tous les éléments <select> à l\'intérieur de ce formulaire
					const selectElements = form.querySelectorAll("select");
					selectElements.forEach((select) => {
						if (select) {
							select.selectedIndex = 1; // Réinitialiser le select (index 1 pour conserver une sélection par défaut)
						}
					});
					
					// Sélectionner tous les éléments <input> de type text à l\'intérieur du formulaire
					const inputTextElements = form.querySelectorAll(\'input[type="text"]\'); // Utiliser des guillemets simples pour l\'attribut
					inputTextElements.forEach((input) => {
						input.value = ""; // Réinitialiser la valeur de l\'input text
					});
				}
			}

			
            // Fonction pour réinitialiser les sections visibles et afficher la section choisie
			function resetImportationSections(sectionToDisplay) {
				document.getElementById("saisierapide").reset();
				document.getElementById("importation_section_2").style.display = "none";
				document.getElementById("importation_section_3").style.display = "none";
				document.getElementById("importation_section_4").style.display = "none";
				document.getElementById(sectionToDisplay).style.display = "flex";
			}
			
			// Mettez à jour le contenu de la section d\'aide en fonction du type d\'opération.
			var sectionAide = document.getElementById("aideDynamique");
			// Définir le contenu d\'aide selon l\'opération, ou par défaut
			var contenuAide = aideMessages[typeOperation] || contenuAideDefault;

			function configureSelectDisplay(selectElements, visibleIndices) {
				selectElements.forEach((el, index) => {
					if (el) el.style.display = visibleIndices.includes(index) ? "block" : "none";
				});
			}
			
			function configureLabels(labelConfigs) {
				// Configurations par défaut des labels
				const defaultConfigs = {
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de produit", width: "18%" },
					"label3": { text: "Compte client", width: "18%" },
					"label4": { text: "Autre", width: "18%" }
				};

				// Appliquer les configurations des labels
				for (const id in defaultConfigs) {
					const label = document.getElementById(id);
					if (label) {
						const config = defaultConfigs[id];
						const customConfig = labelConfigs[id]; // Récupérer les configs personnalisées

						if (customConfig) {
							// Utiliser le texte personnalisé et la largeur fournis
							label.textContent = customConfig.text || config.text; 
							label.style.width = customConfig.width || config.width;
							label.style.display = ""; // Afficher le label
						} else {
							// Masquer le label si non configuré
							label.style.display = "none";
						}
					}
				}
			}

			if (typeOperation === "recette_1" || typeOperation === "recette") {
				resetImportationSections("importation_section_2");
				if (Number(recette_1_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_recette_1").checked = true;
				document.getElementById("saisie_recette").checked = true;
				configureSelectDisplay(selectElements, [2, 9]); // Affiche select2 et select9
                configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de produit", width: "18%" }
				});

			} else if (typeOperation === "recette_2") {
				resetImportationSections("importation_section_2");
				if (Number(recette_2_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_recette_2").checked = true;
				document.getElementById("saisie_recette").checked = true;
				configureSelectDisplay(selectElements, [3, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte client", width: "18%" }
				});

			} else if (typeOperation === "recette_5") {
				resetImportationSections("importation_section_2");
				if (Number(recette_5_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_recette_5").checked = true;
				document.getElementById("saisie_recette").checked = true;
				configureSelectDisplay(selectElements, [2, 6]);
				configureLabels({
					"label2": { text: "Compte de produit", width: "18%" },
					"label3": { text: "Compte client", width: "18%" }
				});
			} else if (typeOperation === "recette_6") {
				resetImportationSections("importation_section_2");
				if (Number(recette_6_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_recette_6").checked = true;
				document.getElementById("saisie_recette").checked = true;
				configureSelectDisplay(selectElements, [2, 6, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de produit", width: "18%" },
					"label3": { text: "Compte client", width: "18%" }
				});
			} else if (typeOperation === "recette_4") {
				resetImportationSections("importation_section_2");
				if (Number(recette_4_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_recette_4").checked = true;
				document.getElementById("saisie_recette").checked = true;
				configureSelectDisplay(selectElements, [8, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de tiers", width: "18%" }
				});
			} else if (typeOperation === "depense_1" || typeOperation === "depense") {
				resetImportationSections("importation_section_3");
				if (Number(depense_1_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_depense").checked = true;
				document.getElementById("saisie_depense_1").checked = true;
				configureSelectDisplay(selectElements, [1, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de charge", width: "18%" }
				});
			} else if (typeOperation === "depense_2") {
				resetImportationSections("importation_section_3");
				if (Number(depense_2_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_depense").checked = true;
				document.getElementById("saisie_depense_2").checked = true;
				configureSelectDisplay(selectElements, [4, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte fournisseur", width: "18%" }
				});
			} else if (typeOperation === "depense_5") {
				resetImportationSections("importation_section_3");
				if (Number(depense_5_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_depense").checked = true;
				document.getElementById("saisie_depense_5").checked = true;
				configureSelectDisplay(selectElements, [1, 7]);
				configureLabels({
					"label2": { text: "Compte de charge", width: "18%" },
					"label3": { text: "Compte fournisseur", width: "18%" }
				});
			} else if (typeOperation === "depense_6") {
				resetImportationSections("importation_section_3");
				if (Number(depense_6_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_depense").checked = true;
				document.getElementById("saisie_depense_6").checked = true;
				configureSelectDisplay(selectElements, [1, 7, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de charge", width: "18%" },
					"label3": { text: "Compte fournisseur", width: "18%" }
				});
			} else if (typeOperation === "depense_4") {
				resetImportationSections("importation_section_3");
				if (Number(depense_4_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_depense").checked = true;
				document.getElementById("saisie_depense_4").checked = true;
				configureSelectDisplay(selectElements, [8, 9]);
				configureLabels({
					"label1": { text: "Mode de paiement", width: "13%" },
					"label2": { text: "Compte de tiers", width: "18%" }
				});
			} else if (typeOperation === "transfert_1" || typeOperation === "transfert") {
				resetImportationSections("importation_section_4");
				if (Number(transfert_1_Link) !== 1) {resetSelects();}
				document.getElementById("saisie_transfert").checked = true;
				document.getElementById("saisie_transfert_1").checked = true;
				configureSelectDisplay(selectElements, [5, 9]);
				configureLabels({
					"label1": { text: "Transfert de :", width: "13%" },
					"label2": { text: "vers :", width: "13%" }
				});
			}  else {
				// Réinitialiser si aucun type d\'opération
				configureSelectDisplay([]);
				configureLabels({});
			}

			// Mettez à jour le contenu de la section d\'aide.
			if (sectionAide) {
				sectionAide.innerHTML = contenuAide;
			}
			// 
		}
		
		// Réinitialiser au texte par défaut
		function resetAide() {
			const sectionAide = document.getElementById("aideDynamique");
			if (sectionAide) {
				sectionAide.innerHTML = contenuAideDefault;
			}
		}

        </script>';
	
	  #          '.$input_reg_client .'
      #      '.$input_reg_fournisseur .'
      
	$contenu_web_ach_comptant .= '
	<div class="Titre10 centrer">Saisie rapide <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'ecriturescomptables_6\');" style="cursor: pointer;" >[?]</span></div>
	
	<div class=centrer>				
	<form id="menu-scenarios" action="' . $r->uri() . '?saisie_rapide" method="POST">
		<select style="width: 50%;" class="forms2_input" id="scenario" name="scenario" onchange="this.form.submit();" required>
			<option value="">-- Saisie rapide d\'une tâche comptable --</option>
			<option value="depot_garantie" ' . (defined $args->{scenario} && $args->{scenario} eq "depot_garantie" ? 'selected' : '') . '>Saisie d\'un dépôt de garantie (C: 165 Banque, D: 411 Clients)</option>
			<option value="remboursement_depot_garantie" ' . (defined $args->{scenario} && $args->{scenario} eq "remboursement_depot_garantie" ? 'selected' : '') . '>Remboursement d\'un dépôt de garantie (D: 165 Banque, C: 411 Clients)</option>
			<option value="transfert_client_douteux" ' . (defined  $args->{scenario} && $args->{scenario} eq "transfert_client_douteux" ? 'selected' : '') . '>Transfert en Clients douteux (D: 416 Douteux, C: 411 Clients)</option>
			<option value="depreciation" ' . (defined  $args->{scenario} && $args->{scenario} eq "depreciation" ? 'selected' : '') . '>Dépréciation d\'une Créance Client (D: 68174 Dotation, C: 491 Provisions)</option>
			<option value="reprise_depreciation" ' . (defined  $args->{scenario} && $args->{scenario} eq "reprise_depreciation" ? 'selected' : '') . '>Reprise de Dépréciation sur Créance (C: 78174 Reprise, D: 491 Provisions)</option>
			<option value="creance_irrecouvrable" ' . (defined $args->{scenario} && $args->{scenario} eq "creance_irrecouvrable" ? 'selected' : '') . '>Créance irrécouvrable (C: 416 Clients douteux, D: 654 Perte sur créances)</option>
			<option value="impot_benefices" ' . (defined $args->{scenario} && $args->{scenario} eq "impot_benefices" ? 'selected' : '') . '>Evaluation de l\'Impôt sur les bénéfices (C: 444 État, D: 695 Impôts sur bénéfices)</option>
			<option value="avis_imposition" ' . (defined $args->{scenario} && $args->{scenario} eq "avis_imposition" ? 'selected' : '') . '>Provision et avis d\'imposition (C: 447 Autres impôts, D: 635 Compte de charge impôt)</option>
		</select>
	' . $hidden_fields . '
	</form>
	</div>
	
	<div id="memo10" class="flex1 centrer" ><div class="memoinfo2">Le mode de paiement détermine le journal et le compte de trésorerie qui seront utilisés.</div></div>
    
    <form id="saisierapide" class=wrapper1 action="' . $r->uri() . '?saisie_rapide=0" method="POST">
    		
    		<!-- Catégorie Niveau 1 -->
    		<div class="formflexN1 flex1" style="font-weight: bold;" id="importation_section_1">
				<input  class="custom-radio" type="radio" id="saisie_recette" name="saisie_method_level1" value="recette"' . ($current_saisie_method_level1 eq 'recette' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette\');">
				<label for="saisie_recette">Recette (entrée d\'argent)</label>
				<input class="custom-radio" type="radio" id="saisie_depense" name="saisie_method_level1" value="depense"' . ($current_saisie_method_level1 eq 'depense' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense\');">
				<label for="saisie_depense">Dépense (sortie d\'argent)</label>
				<input class="custom-radio" type="radio" id="saisie_transfert" name="saisie_method_level1" value="transfert"' . ($current_saisie_method_level1 eq 'transfert' ? ' checked' : '') . ' onclick="ToggleMenu(\'transfert\');">
				<label for="saisie_transfert">Transfert entre compte</label>
			</div>

			<!-- Catégorie "Recette Entrée d\'argent" - Niveau 2 -->
			<div class="formflexN1 flex1" style="font-weight: bold; display:none;" id="importation_section_2">
				<input  class="custom-radio2" type="radio" id="saisie_recette_1" name="saisie_method" value="recette_1"' . ($current_saisie_method eq 'recette_1' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette_1\');">
				<label for="saisie_recette_1">Recette</label>
				'.$recette_n2.'
				<input class="custom-radio2" type="radio" id="saisie_recette_4" name="saisie_method" value="recette_4"' . ($current_saisie_method eq 'recette_4' ? ' checked' : '') . ' onclick="ToggleMenu(\'recette_4\');">
				<label for="saisie_recette_4">Autres entrées d\'argent</label>
			</div>
			
			<!-- Catégorie "Dépense Sortie d\'argent" - Niveau 2 -->
			<div class="formflexN1 flex1" style="font-weight: bold; display:none;" id="importation_section_3">
				<input class="custom-radio2" type="radio" id="saisie_depense_1" name="saisie_method" value="depense_1"' . ($current_saisie_method eq 'depense_1' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense_1\');">
				<label for="saisie_depense_1">Dépense</label>
				'.$depense_n2.'
				<input class="custom-radio2" type="radio" id="saisie_depense_4" name="saisie_method" value="depense_4"' . ($current_saisie_method eq 'depense_4' ? ' checked' : '') . ' onclick="ToggleMenu(\'depense_4\');">
				<label for="saisie_depense_4">Autres sorties d\'argent</label>
			</div>
		
			<!-- Catégorie "Transfert entre comptes" - Niveau 2 -->
			<div class="formflexN1 flex1" style="font-weight: bold; display:none;" id="importation_section_4">
					<input class="custom-radio2" type="radio" id="saisie_transfert_1" name="saisie_method" value="transfert_1"' . ($current_saisie_method eq 'transfert_1' ? ' checked' : '') . ' onclick="ToggleMenu(\'transfert_1\');">
					<label for="saisie_transfert_1">Transfert entre deux comptes financiers</label>
			</div>
    
    <div class=formflexN2>
        <label style="width: 10%;" class="forms2_label" for="date_'.$reqid.'">Date</label>
        <label id="label1" style="width: 13%;" class="forms2_label" for="'.$form_id3.'">Mode de paiement</label>
		<label id="label2" style="width: 18%;" class="forms2_label" for="'.$form_id2.'">Compte</label>
		<label style="width: 32%;" class="forms2_label" for="libelle_'.$reqid.'">Libellé</label>
		<label style="width: 10%;" class="forms2_label" for="montant_'.$reqid.'">Montant</label>
		'. $label_check.'
	</div>
	
	<div class=formflexN2>
		<input class="forms2_input" style="width: 10%;" type="text" name=date_comptant id=date_'.$reqid.' value="' . ($args->{date_comptant} || $date_comptant || '') . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');" required>
		' . $select_achats . '
		' . $compte_charge . $compte_produit  . $compte_client . $compte_fournisseur . $id_compte_2_select . $compte_autres .'
		<input class="forms2_input" style="width: 32%;" type=text id="libelle_'.$reqid.'" name=libelle value="'.($args->{libelle}|| '').'" required onclick="liste_search_libelle(this.value, \''.$reqid.'\')" list="libellelist_'.$reqid.'"><datalist id="libellelist_'.$reqid.'"></datalist>
		<input class="forms2_input" style="width: 10%;" type=text id="montant_'.$reqid.'" name=montant value="'.($args->{montant} || $montant_entry || '').'" onchange="format_number(this)" title="'.($args->{aidemontant} || '') .'" required/>
		'.$check_comptant.'
	</div>

	<div class=formflexN2>
		'.$label_engagement.'
        <label style="width: 26%;" class="forms2_label" for="'.$form_id4.'" >Documents 1</label>
        <label style="width: 26%;" class="forms2_label" for="'.$form_id5.'">Documents 2</label>
        <label style="width: 15%;" class="forms2_label" for="calcul_piece_'.$reqid.'">Pièce</label>
        <label style="width: 10%;" class="forms2_label" for="submit_'.$reqid.'">&nbsp;</label>
    </div>    
    
    <div class=formflexN2>
		' . $compte_client_engagement . $compte_fournisseur_engagement .'   
		' . $document_select1 . '
		' . $document_select2 . '
		<input class="forms2_input" style="width: 15%;" type=text id=calcul_piece_'.$reqid.' name=piece value="'.($args->{piece} || '').'" required/>
		<input type=submit id="submit_'.$reqid.'" style="width: 10%;" class="btn btn-vert" value=Valider>
	</div>
		
	' . $hidden_fields . '
	</form>
	<div class="flex1 centrer" ><div id="aideDynamique" class="memoinfo2"></div></div>

	<div id="memo2" class="flex1 centrer" style="display:none"><div class="memoinfo2">
			<p class="style3 bold">Le mode de paiement détermine le journal et le compte de trésorerie qui seront utilisés.</p>
			<hr class="mainPageTutoriel">
			<p class="style3 bold">Saisie d\'une dépense via une écriture comptable (Journal de type "Trésorerie") :</p>
			<p class="style3">Crédit du compte financier (ex: "512 - Banque") et débit du compte de charge ( ex: "626100 - Frais postaux").</p>
			<br>
	</div></div>
	
	<script>ToggleMenu(\''.$current_saisie_method.'\');</script>
	';
	

	$content .= $contenu_web_ach_comptant;

    return $content ;
	############## MISE EN FORME FIN ##############

} #sub forms_paiement_saisie 	
 
#/*—————————————— Formulaire recherche d'écriture ——————————————*/
sub forms_search {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @where_conditions) ;
	my ($content, $end) = ('', '') ;
	my $reqid = Base::Site::util::generate_reqline();
	# Créez un tableau pour stocker les clauses WHERE conditionnelles
    my @bind_values = ($r->pnotes('session')->{id_client});
    
    # Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	if ( defined $args->{reset} && $args->{reset} eq 1) {
		$hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['search*', 'reset'], [], []);
	}

	#####################################       
	# Requête SQL						#
	#####################################  
	
	#recherche de la liste des documents enregistrés
    $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, check_banque, last_fiscal_year, id_compte FROM tbldocuments WHERE id_name = ? AND id_client = ?' ;
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $args->{id_name}, $r->pnotes('session')->{id_client} ) ;
	
	my $bdd_compte = Base::Site::bdd::get_comptes_by_classe($dbh, $r, 'all');
	my $selected2 = (defined($args->{search_compte}) && $args->{search_compte} ne '') ? $args->{search_compte} : undef;
	my $onchange2 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};\"";
	my ($form_name2, $form_id2)  = ('search_compte', 'search_compte_'.$reqid.'');
	my $compte_all = Base::Site::util::generate_compte_selector($bdd_compte, $reqid, $selected2, $form_name2, $form_id2, $onchange2, 'class="forms2_input"', 'style="width: 18%;"');
	
	if (!defined $args->{search_fiscal_year}) { $args->{search_fiscal_year} = $r->pnotes('session')->{fiscal_year};};
	my $parametres_fiscal_year = Base::Site::bdd::get_parametres_fiscal_year($dbh, $r->pnotes('session')->{id_client});
	my $selected_fiscal_year = (defined($args->{search_fiscal_year}) && $args->{search_fiscal_year} ne '') ? ($args->{search_fiscal_year} ) : undef;
	my ($onchange_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year) = ('', 'search_fiscal_year', 'search_fiscal_year_'.$reqid.'');
	my $search_fiscal_year = Base::Site::util::generate_fiscal_year($parametres_fiscal_year, $reqid, $selected_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year, $onchange_fiscal_year, 'class="forms2_input"', 'style="width: 8%;"', 1);
	
	my $journaux = Base::Site::bdd::get_journaux($dbh, $r);
	my $selected_journal = (defined($args->{search_journal}) && $args->{search_journal} ne '') ? ($args->{search_journal} ) : undef;
	my $onchange_journal= "onchange=\"if(this.selectedIndex == 0){document.location.href='journal?configuration'};\"";
	my ($form_name_journal, $form_id_journal) = ('search_journal', 'search_journal_'.$reqid.'');
	my $search_journal = Base::Site::util::generate_journal_selector($journaux, $reqid, $selected_journal, $form_name_journal, $form_id_journal, $onchange_journal, 'class="forms2_input"', 'style="width: 8%;"');

	#####################################       
	#Rechercher des entrées du journal
	#####################################    
	my $propo_list .= '';
	
	#Formulaire => l'utilisateur a cliqué sur 'Dupliquer'	
	if ( defined $args->{search} && defined $args->{copyentry} && $args->{copyentry} ne '' && !(defined $args->{confirm_copy} && $args->{confirm_copy} eq "Oui")) {
		
		my $copyentry = $args->{copyentry};
		my $message = '';

		# Lorsque l'utilisateur clique sur "Non"
		if (defined $args->{confirm_copy} && $args->{confirm_copy} eq "Non") {
			$hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['copyentry','confirm_copy'], [], []);
		} else {
			
			$sql = 'SELECT id_entry, date_ecriture, libelle_journal, numero_compte, libelle FROM tbljournal WHERE id_client = ? AND id_entry = ?';
			my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{copyentry} ) ) ;
			
			$message .= 'Voulez-vous vraiment dupliquer cette écriture ? <br>
			*** Date: ' . $resultat->[0]->{date_ecriture} . ' - Journal : ' . $resultat->[0]->{libelle_journal} . ' - Compte : ' . $resultat->[0]->{numero_compte} . ' - Libellé : ' . $resultat->[0]->{libelle} . ' ***';

			# Dans votre formulaire de confirmation (confirm), utilisez la méthode POST pour soumettre les données
			$message .= '<form method="POST" action="' . $r->unparsed_uri() . '">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_copy" value="Oui" style="margin-left: 3em;">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_copy" value="Non" style="margin-left: 3em;">
					' . $hidden_fields_form . '
					</form>';

			$end .= '
					<script>
					focusAndChangeColor("'.$args->{copyentry}.'");
					</script>
			';

			$content .= Base::Site::util::generate_error_message($message);

		}
    

	} elsif ( defined $args->{search} && defined $args->{confirm_copy} && $args->{confirm_copy} eq "Oui") {
		
		my ($token_id, $libelle_journal);
		
		#Nettoie la table tbljournal_staging
		Base::Site::bdd::clean_tbljournal_staging( $r );
		
		$sql = 'SELECT id_entry, date_ecriture, libelle_journal FROM tbljournal WHERE id_client = ? AND id_entry = ? GROUP BY id_entry, date_ecriture, libelle_journal';
		my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{copyentry} ) ) ;
		
		foreach ( @{$resultat} ) {
			
			$token_id = Base::Site::util::generate_unique_token_id($r, $dbh);	
			$libelle_journal = $_->{libelle_journal};
		
			# Extraction de la date d'origine $_->{date_ecriture}
			my ($year, $month, $day) = Base::Site::util::extract_date_components($_->{date_ecriture});
			my $yyyy = $r->pnotes('session')->{fiscal_year};
			my $date = ''.$yyyy.'-'.$month.'-'.$day.'';
			
			my $numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $libelle_journal, $date);
		
			$sql = '
			INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, _token_id ) SELECT ?, ?, t1.id_client, ?, ?, ?, ?, t1.libelle_journal, t1.numero_compte, ?, t1.id_paiement, ?, t1.libelle, t1.documents1, t1.documents2, t1.debit, t1.credit, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? ORDER BY id_line' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $date, $numero_piece, $token_id, $_->{id_entry} ) ;

			$dbh->do( $sql, undef, @bind_array ) ;
	
		}#Fin foreach ( @{$resultat})

		$args->{restart} = 'entry?open_journal='.URI::Escape::uri_escape_utf8($libelle_journal).'&id_entry=0&redo=0&_token_id=' . $token_id ;
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 

	#Formulaire => l'utilisateur a cliqué sur 'Supprimer'	
	} elsif ( defined $args->{search} && defined $args->{deleteentry} && $args->{deleteentry} ne '' && !(defined $args->{confirm_delete} && $args->{confirm_delete} eq "Oui")) {
		
		my $deleteentry = $args->{deleteentry};
		my $message = '';

		# Lorsque l'utilisateur clique sur "Non"
		if (defined $args->{confirm_delete} && $args->{confirm_delete} eq "Non") {
			$hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['deleteentry','confirm_delete'], [], []);
		} else {
			
			$sql = 'SELECT id_entry, date_ecriture, libelle_journal, numero_compte, libelle FROM tbljournal WHERE id_client = ? AND id_entry = ?';
			my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{deleteentry} ) ) ;
			
			$message .= 'Voulez-vous vraiment supprimer cette écriture ? <br>
			*** Date: ' . $resultat->[0]->{date_ecriture} . ' - Journal : ' . $resultat->[0]->{libelle_journal} . ' - Compte : ' . $resultat->[0]->{numero_compte} . ' - Libellé : ' . $resultat->[0]->{libelle} . ' ***';

			# Dans votre formulaire de confirmation (confirm), utilisez la méthode POST pour soumettre les données
			$message .= '<form method="POST" action="' . $r->unparsed_uri() . '">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_delete" value="Oui" style="margin-left: 3em;">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_delete" value="Non" style="margin-left: 3em;">
					' . $hidden_fields_form . '
					</form>';

			$end .= '
					<script>
					focusAndChangeColor("'.$args->{deleteentry}.'");
					</script>
			';

			$content .= Base::Site::util::generate_error_message($message);
		}

	} elsif ( defined $args->{search} && defined $args->{confirm_delete} && $args->{confirm_delete} eq "Oui") {
		
		$sql = 'SELECT * FROM tbljournal WHERE id_client = ? AND id_entry = ?';
		my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{deleteentry} ) ) ;
		my ($montant, $compte_debit, $compte_credit) = ('', '', '');
		if ($resultat->[0]->{debit} != 0) {
			$montant = $resultat->[0]->{debit};
			$compte_debit = ($resultat->[0]->{numero_compte} || '');
			$compte_credit = ($resultat->[1]->{numero_compte} || '') ;
		} else {
			$montant = $resultat->[0]->{credit};
			$compte_credit = ($resultat->[0]->{numero_compte} || '') ;
			$compte_debit = ($resultat->[1]->{numero_compte} || '');
		}
		my $message_delete = 'Date: ' .($resultat->[0]->{date_ecriture} || '' ). ', Montant: ' . ($montant/100 || '' ) .'€, Libellé: ' . ($resultat->[0]->{libelle} || '' ) .', Compte débit: '.($compte_debit || '' ).', Compte crédit: '.($compte_credit || '' ).', Journal: '.($resultat->[0]->{libelle_journal} || '' ).'';
    	
		#demande de suppression confirmée
		$sql = 'DELETE FROM tbljournal WHERE id_client = ? and fiscal_year = ? and id_entry = ?' ;
		eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{deleteentry} ) ) } ;
		#Null value pour module ndf
		$sql = 'UPDATE tblndf SET piece_entry = NULL WHERE id_client = ? and fiscal_year = ? and piece_entry = ?' ;
		eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{deleteentry} ) ) } ;

		if ( $@ ) {
			my $message = ( $@ =~ /archived/ )? 'La date d\'écriture se trouve dans un mois archivé - Enregistrement impossible' : $@ ;
			$content .= '<h3 class=warning>' . $message . '</h3>' ;
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Suppression de l\'écriture => '.$message_delete.'');
			$hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['deleteentry','confirm_delete'], [], []);
		}

	#Formulaire => l'utilisateur a cliqué sur 'Extourner'	
	} elsif ( defined $args->{search} && defined $args->{extourneentry} && $args->{extourneentry} ne '' && !(defined $args->{confirm_extourne} && $args->{confirm_extourne} eq "Oui")) {
		
		my $extourneentry = $args->{extourneentry};
		my $message = '';

		# Lorsque l'utilisateur clique sur "Non"
		if (defined $args->{confirm_extourne} && $args->{confirm_extourne} eq "Non") {
			$hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['extourneentry','confirm_extourne'], [], []);
		} else {
			
			$sql = 'SELECT id_entry, date_ecriture, libelle_journal, numero_compte, libelle FROM tbljournal WHERE id_client = ? AND id_entry = ?';
			my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{extourneentry} ) ) ;
			
			$message .= 'Voulez-vous vraiment extourner cette écriture ? <br>
			*** Date: ' . ($resultat->[0]->{date_ecriture} || ''). ' - Journal : ' . ($resultat->[0]->{libelle_journal} || '') . ' - Compte : ' . ($resultat->[0]->{numero_compte}|| '') . ' - Libellé : ' . ($resultat->[0]->{libelle}|| '') . ' ***';

			# Dans votre formulaire de confirmation (confirm), utilisez la méthode POST pour soumettre les données
			$message .= '<form method="POST" action="' . $r->unparsed_uri() . '">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_extourne" value="Oui" style="margin-left: 3em;">
					<input type="submit" style="width : 5%;" class="button-link" name="confirm_extourne" value="Non" style="margin-left: 3em;">
					' . $hidden_fields_form . '
					</form>';

			$end .= '
					<script>
					focusAndChangeColor("'.$args->{extourneentry}.'");
					</script>
			';

			$content .= Base::Site::util::generate_error_message($message);

		}
    

	} elsif ( defined $args->{search} && defined $args->{confirm_extourne} && $args->{confirm_extourne} eq "Oui") {
		
		my ($token_id, $libelle_journal);
		
		#Nettoie la table tbljournal_staging
		Base::Site::bdd::clean_tbljournal_staging( $r );
		
		$sql = 'SELECT id_entry, date_ecriture, libelle_journal FROM tbljournal WHERE id_client = ? AND id_entry = ? GROUP BY id_entry, date_ecriture, libelle_journal';
		my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{extourneentry} ) ) ;
		
		foreach ( @{$resultat} ) {
			
			$token_id = Base::Site::util::generate_unique_token_id($r, $dbh);	
			$libelle_journal = 'OD';
		
			# Extraction de la date d'origine $_->{date_ecriture}
			my ($year, $month, $day) = Base::Site::util::extract_date_components($_->{date_ecriture});
			my $yyyy = $r->pnotes('session')->{fiscal_year};
			my $date = ''.$yyyy.'-'.$month.'-'.$day.'';
			
			my $numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $libelle_journal, $date);
		
			$sql = '
			INSERT INTO tbljournal_staging (_session_id, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, date_ecriture, id_paiement, id_facture, libelle, documents1, documents2, debit, credit, _token_id ) SELECT ?, ?, t1.id_client, ?, ?, ?, ?, \'OD\', t1.numero_compte, ?, t1.id_paiement, ?, CONCAT(\'Extourne \', t1.libelle), t1.documents1, t1.documents2, t1.credit, t1.debit, ?
			FROM tbljournal t1 
			WHERE t1.id_entry = ? ORDER BY id_line' ;
			@bind_array = ( $r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $date, $numero_piece, $token_id, $_->{id_entry} ) ;

			$dbh->do( $sql, undef, @bind_array ) ;
	
		}#Fin foreach ( @{$resultat})

		$args->{restart} = 'entry?open_journal='.URI::Escape::uri_escape_utf8($libelle_journal).'&id_entry=0&redo=0&_token_id=' . $token_id ;
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 

	} 

	#L'utilisateur a cliqué sur Rechercher
	if (defined $args->{search} && $args->{search} eq 1) {
		
		# Ajoutez la condition search_fiscal_year si elle est définie et non vide
		if (defined $args->{search_fiscal_year} && $args->{search_fiscal_year} ne '') {
			@where_conditions = 't1.fiscal_year = ?';
			push @bind_values, $args->{search_fiscal_year};
		}
		
		if (defined $args->{search_date} && $args->{search_date} ne '') {
			push @where_conditions, 't1.date_ecriture = ?';
			push @bind_values, $args->{search_date};
		}
		
		if (defined $args->{search_recurrent} && $args->{search_recurrent} ne '') {
			push @where_conditions, 't1.recurrent = ?';
			push @bind_values, $args->{search_recurrent};
		}
 
		if (defined $args->{search_lib} && $args->{search_lib} ne '') {
			push @where_conditions, 't1.libelle ILIKE ?';
			push @bind_values, '%' . $args->{search_lib} . '%';
		}
		
		if (defined $args->{search_piece} && $args->{search_piece} ne '') {
			push @where_conditions, 't1.id_facture ILIKE ?';
			push @bind_values, '%' . $args->{search_piece} . '%';
		}

		if (defined $args->{search_compte} && $args->{search_compte} ne '') {
			push @where_conditions, 't1.numero_compte = ?';
			push @bind_values, $args->{search_compte};
		}
		
		if (defined $args->{search_journal} && $args->{search_journal} ne '') {
			push @where_conditions, 't1.libelle_journal = ?';
			push @bind_values, $args->{search_journal};
		}
		
		if (defined $args->{search_montant} && $args->{search_montant} ne '') {
			my $montant_operator_number = $args->{search_montant_operator} || 1; # Utilisez 1 par défaut (égal à)
			
			# Définissez un tableau de correspondance entre les numéros d'opérateur et les opérateurs de comparaison
			my @operator_mapping = (
				"=",   # 1: Égal à
				"<",   # 2: Inférieur à
				">",   # 3: Supérieur à
				# Ajoutez d'autres correspondances au besoin
			);

			# Récupérez l'opérateur de comparaison en fonction du numéro
			my $montant_operator = $operator_mapping[$montant_operator_number - 1] || "="; # Par défaut, utilisez "Égal à"
			
			my $montant = $args->{search_montant};
			Base::Site::util::formatter_montant_et_libelle(\$montant, undef);
			
			if ($montant_operator_number eq 2 || $montant_operator_number eq 3) {
				push @where_conditions, '((t1.debit::NUMERIC = 0 AND t1.credit::NUMERIC '.$montant_operator.' ?) OR (t1.credit::NUMERIC = 0 AND t1.debit::NUMERIC '.$montant_operator.' ?))';
			} else {
				push @where_conditions, '(t1.debit::NUMERIC '.$montant_operator.' ? OR t1.credit::NUMERIC '.$montant_operator.' ?)';
			}
			push @bind_values, ($montant*100), ($montant*100); # En centimes

		}

		# Rejoignez les conditions WHERE en une seule chaîne avec des AND
		my $where_clause = join(' AND ', @where_conditions) if @where_conditions;

		# Requête SQL
		my $sql = '
			SELECT t1.id_entry, t1.id_export, t1.fiscal_year, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, t3.libelle_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit
			FROM tbljournal t1
			INNER JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.numero_compte = t3.numero_compte
			WHERE t1.id_client = ?';

		$sql .= " AND $where_clause" if $where_clause;

		$sql .= ' ORDER BY t1.fiscal_year DESC, date_ecriture, id_entry, id_line';

		# Exécutez la requête SQL avec les valeurs liées
		my $result_set = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_values);

		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'docsentry.pm => Rechercher montant: '.$args->{search_montant}.' date : '.$args->{search_date}.' libellé : '.$args->{search_lib}.' compte : '.$args->{search_compte}.' fiscal_year : '.$args->{search_fiscal_year}.'');
		
		if (@$result_set) {
			$propo_list .= '<form method="post" action="' . $r->unparsed_uri() . '"><ul class="wrapper style1">' ;

			my $id_entry = '' ;
			my $current_fiscal_year = '';
			my $previous_fiscal_year = '';
			
			for ( @$result_set ) {
				
				my $reqid = Base::Site::util::generate_reqline();
			
				if (defined $_->{fiscal_year}) {
				$current_fiscal_year = $_->{fiscal_year};

				# Vérifiez si l'exercice a changé
				if ($current_fiscal_year ne $previous_fiscal_year) {
					# Fermez la liste précédente s'il y en avait une
					if ($previous_fiscal_year) {
						$propo_list .= '</li>';
					}

					# Ajoutez une ligne avec le nom de l'exercice et l'en-tête du tableau
					$propo_list .= '
					<li class="style1"><div class="flex-table"><div class="spacer"></div><span class="classenum">Exercice : ' . $current_fiscal_year . '</span><div class="spacer"></div></div></li>
					<li class="style1"><div class=flex-table><div class=spacer></div>
					<span class=headerspan style="width: 8%;">Date</span>
					<span class=headerspan style="width: 8%;">Journal</span>
					<span class=headerspan style="width: 8%;">Libre</span>
					<span class=headerspan style="width: 8%;">Compte</span>
					<span class=headerspan style="width: 12%;">Pièce</span>
					<span class=headerspan style="width: 28.9%;">Libellé</span>
					<span class=headerspan style="width: 8%; text-align: right;">Débit</span>
					<span class=headerspan style="width: 8%; text-align: right;">Crédit</span>
					<span class=headerspan style="width: 1%; text-align: center;">&nbsp;</span>
					<span class=headerspan style="width: 2.5%; text-align: center;">&nbsp;</span>
					<span class=headerspan style="width: 2.5%; text-align: center;">&nbsp;</span>
					<span class=headerspan style="width: 2.5%; text-align: center;">&nbsp;</span>
					<span class=headerspan style="width: 2.5%; text-align: center;">&nbsp;</span>
					<div class=spacer></div></div></li>';
				}
			}
				
			
			#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
			unless ( $_->{id_entry} eq $id_entry ) {

				#lien de modification de l'entrée
				my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry} ;

				#cas particulier de la première entrée de la liste : pas de liste précédente
				unless ( $id_entry ) {
				$propo_list .= '<li class=listitem3 id="line_'.$_->{id_entry}.'">' ;
				} else {
				$propo_list .= '</li><li class=listitem3 id="line_'.$_->{id_entry}.'">'
				} #	    unless ( $id_entry ) 

			} #	unless ( $_->{id_entry} eq $id_entry ) 

			#marquer l'entrée en cours
			$id_entry = $_->{id_entry} ;
			
			my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents1}, 1);
			my $http_link_documents2 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents2}, 2);
			
			my ($disabled_duplicate, $disabled_delete, $disabled_extourne) = ('', '', '');
			if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
				$disabled_duplicate = '<input type="image" src="/Compta/style/icons/duplicate.png" class=image alt="dupliquer" data-id-entry="'.$id_entry.'" onclick="document.getElementById(\'copyentry\').value = \''.$id_entry.'\';" title="Dupliquer l\'écriture">';
				$disabled_extourne = '<input type="image" src="/Compta/style/icons/inverser2.png" class=image alt="extourner" data-id-entry="'.$id_entry.'" onclick="document.getElementById(\'extourneentry\').value = \''.$id_entry.'\';" title="Extourner l\'écriture">';
			
			}

			#lien de modification de l'entrée
			my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry} ;
			
			# Déterminez si le lien doit être ouvert ou fermé
			my $entry_link_open = $current_fiscal_year eq $r->pnotes('session')->{fiscal_year} ? '<a href="' . ($id_entry_href || '') . '" >' : '';
			my $entry_link_close = $current_fiscal_year eq $r->pnotes('session')->{fiscal_year} ? '</a>' : '';
			
			if (($current_fiscal_year eq $r->pnotes('session')->{fiscal_year}) && (!defined $_->{id_export})){
				$disabled_delete = '<input type="image" src="/Compta/style/icons/delete.png" class=image alt="supprimer" data-id-entry="'.$id_entry.'" onclick="document.getElementById(\'deleteentry\').value = \''.$id_entry.'\';" title="Supprimer l\'écriture">';
			}
			
			$propo_list .= '
			<div class=flex-table><div class=spacer></div>'.$entry_link_open.'
			<span class=displayspan style="width: 8%;">' . $_->{date_ecriture} . '</span>
			<span class=displayspan style="width: 8%;">' . $_->{libelle_journal} .'</span>
			<span class=displayspan style="width: 8%;">' . $_->{id_paiement} . '</span>
			<span class=displayspan style="width: 8%;" title="'. $_->{libelle_compte} .'">' . $_->{numero_compte} . '</span>
			<span class=displayspan style="width: 12%;">' . $_->{id_facture} . '</span>
			<span class=displayspan style="width: 28.9%;">' . $_->{libelle} . '</span>
			<span class=displayspan style="width: 8%; text-align: right;">' . $_->{debit} . '</span>
			<span class=displayspan style="width: 8%; text-align: right;">' .  $_->{credit} . '</span>
			</a>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents1 . '</span>
			<span class=displayspan style="width: 2%;">' . $http_link_documents2 . '</span>
			<span class=displayspan style="width: 2%;">'.$disabled_duplicate.'</span>
			<span class=displayspan style="width: 2%;">'.$disabled_extourne.'</span>
			<span class=displayspan style="width: 2%;">'.$disabled_delete.'</span>
			<div class=spacer>
			</div>
			</div>' . $entry_link_close.'
			' ;

			# Mettez à jour l'exercice précédent
			$previous_fiscal_year = $current_fiscal_year;
			
			} #    for ( @$result_set ) 

			#on clot la liste s'il y avait au moins une entrée dans le journal
			#$propo_list .= '</a></li>' if ( @$result_set ) ;
			# Fermez la dernière liste
			$propo_list .= '</li>' if $previous_fiscal_year;

			#pour le journal général, ajouter la colonne libelle_journal
			#$libelle_journal = ( $args->{open_journal} eq 'Journal général' ) ? '<span class=blockspan style="width: 25ch;">&nbsp;</span>' : '' ;
			
			$propo_list .=  '<li ><hr></li>
			<li ><div class=flex-table><div class=spacer></div>
			<span class=displayspan style="width: 8%;">&nbsp;</span>
			<span class=displayspan style="width: 8%;">&nbsp;</span>
			<span class=displayspan style="width: 8%;">&nbsp;</span>
			<span class=displayspan style="width: 8%;">&nbsp;</span>
			<span class=displayspan style="width: 12%;">&nbsp;</span>
			<span class="displayspan bold" style="width: 29.9%; text-align: right;">Total</span>
			<span class="displayspan bold" style="width: 8%; text-align: right;">' . ( $result_set->[0]->{total_debit} || 0 ) . '</span>
			<span class="displayspan bold" style="width: 8%; text-align: right;">' . ( $result_set->[0]->{total_credit} || 0 ) . '</span>
			</span><div class=spacer></div><input type="hidden" name="deleteentry" id="deleteentry" value=""><input type="hidden" name="copyentry" id="copyentry" value=""><input type="hidden" name="extourneentry" id="extourneentry" value="">' . $hidden_fields_form . '</li></ul>
			</form>';
		}
	
	unless ($propo_list) {
		$propo_list .= Base::Site::util::generate_error_message('Aucun résultat à afficher ...');
	}
	
	}

	############## MISE EN FORME DEBUT ##############

	my $contenu_search .= '
	
	<div class="Titre10 centrer">Rechercher des entrées du journal</div>

	<form class=wrapper1 action="' . $r->uri() . '?search=1" method="POST">
	<div class=formflexN2>
		<label style="width: 7%;" class="forms2_label" for="search_date_'.$reqid.'">Date</label>
		<label style="width: 8%;" class="forms2_label" for="search_journal_'.$reqid.'">Journal</label>
        <label style="width: 18%;" class="forms2_label" for="search_compte_'.$reqid.'">Compte</label>
        <label style="width: 9%;" class="forms2_label" for="search_piece_'.$reqid.'">Pièce</label>
        <label style="width: 29%;" class="forms2_label" for="search_lib_'.$reqid.'">Libellé</label>
        <label style="width: 13%;" class="forms2_label" for="search_montant_'.$reqid.'">Montant</label>
        <label style="width: 8%;" class="forms2_label" for="search_fiscal_year_'.$reqid.'">Année fiscale</label>
		<label style="width: 5%;" class="forms2_label" for="search_recurrent">Récurrent</label>
    </div>    
    
    <div class=formflexN2>        
		<input class="forms2_input" style="width: 7%;" type=text id="search_date_'.$reqid.'" name=search_date value="' . ($args->{search_date} || ''). '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')"/>
		' .  $search_journal . '
		' .  $compte_all . '											
		<input class="forms2_input" style="width: 9%;" type=text id="search_piece_'.$reqid.'" name=search_piece value="' . ($args->{search_piece} || ''). '" onclick="liste_search_piece(this.value, \''.$reqid.'\')" list="piecelist_'.$reqid.'"><datalist id="piecelist_'.$reqid.'"></datalist>
		<input class="forms2_input" style="width: 29%;" type=text id="search_lib_'.$reqid.'" name=search_lib value="' . ($args->{search_lib} || ''). '" onclick="liste_search_libelle(this.value, \''.$reqid.'\')" list="libellelist_'.$reqid.'"><datalist id="libellelist_'.$reqid.'"></datalist>
		<select style="width: 3%;" class="forms2_input" name="search_montant_operator" id="search_montant_operator_'.$reqid.'">
			<option value="1" ' . ($args->{search_montant_operator} && $args->{search_montant_operator} eq "1" ? 'selected' : '') . '>=</option>
			<option value="2" ' . ($args->{search_montant_operator} && $args->{search_montant_operator} eq "2" ? 'selected' : '') . '>&lt;</option>
			<option value="3" ' . ($args->{search_montant_operator} && $args->{search_montant_operator} eq "3" ? 'selected' : '') . '>&gt;</option>
		</select>
		<input class="forms2_input" style="width: 10%;" type=text id="search_montant_'.$reqid.'" name=search_montant onchange="format_number(this);" value="' . ($args->{search_montant} || ''). '" />
		' .  $search_fiscal_year .'
		<input style="border: 1px solid #ced4da;border-radius: 5px;margin: 5px; width: 5%; height: 4ch; display: block;" type="checkbox" id="search_recurrent" name="search_recurrent" title="Cocher pour voir les écritures récurrentes." value="t" '.	((defined $args->{search_recurrent} && $args->{search_recurrent} eq 't') ? 'checked' : '').'>
	</div>
    
	' . $hidden_fields_form . '

	<div class=formflexN3>
	<input type=submit id="submit_'.$reqid.'" style="width: 10%;" class="btn btn-vert" value="Rechercher">
	<button type="submit" style="width: 10%;" class="btn btn-orange" name="reset" value="1" style="margin-left: 3em;">Réinitialiser</button>
	</div>

	</form>
	';
	
	$content .= $contenu_search . $propo_list .  $end;

    return $content ;
    ############## MISE EN FORME FIN ##############
    
} #sub forms_search 

#/*—————————————— Formulaire Interet CCA ——————————————*/
sub forms_interet_cca {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	my ($content, $selected) = ('', '');
	my $reqid = Base::Site::util::generate_reqline();
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);	

	####################################################################### 
	#Formulaire 1 => l'utilisateur a cliqué sur le bouton 'Imprimer'	  #
	#######################################################################
	if ( defined $args->{interet_cca} && defined $args->{imprimer}) {
		my $location = export_pdf2( $r, $args ); ;
		$hidden_fields = Base::Site::util::create_hidden_fields_form($args, ['imprimer'], [], []);
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
	#Formulaire 1 => l'utilisateur a cliqué sur le bouton 'Comptabiliser' #
	#######################################################################
    if ( defined $args->{interet_cca} && defined $args->{comptabiliser} && $args->{comptabiliser} eq '0') {
		
		my $message2 = 'Voulez-vous vraiment comptabiliser les intérêts des comptes courants d\'associés ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'comptabiliser', $args->{comptabiliser}, $hidden_fields, 1);
		$content .= Base::Site::util::generate_error_message($confirmation_message);
		
	} elsif ( defined $args->{interet_cca} && defined $args->{comptabiliser} && $args->{comptabiliser} eq '1') {
	
		#Nettoie la table tbljournal_staging
		Base::Site::bdd::clean_tbljournal_staging( $r );
		
		my $numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, 'OD', $r->pnotes('session')->{Exercice_fin_YMD});
		
		#Génération nom de fichier
		my $name_file = $numero_piece.'_decompte_interets_cc_'.(Time::Piece->strptime($r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d")->dmy("_")).'.pdf';
		# Remplacer modifier espace et _
		$name_file =~ s/\s+/_/g;
		
		my $doc_categorie = 'Temp';
		#Insertion du nom du document dans la table tbldocuments
		$sql = 'INSERT INTO tbldocuments ( id_client, id_name, fiscal_year, libelle_cat_doc, date_reception, date_upload )
		VALUES ( ? , ? , ? , ?, ?, CURRENT_DATE)
		ON CONFLICT (id_client, id_name ) DO NOTHING
		RETURNING id_name' ;
		my $sth = $dbh->prepare($sql) ;
		eval { $sth->execute( $r->pnotes('session')->{id_client}, $name_file, $r->pnotes('session')->{fiscal_year}, $doc_categorie, $r->pnotes('session')->{Exercice_fin_YMD} )} ;

		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm =>	Vérification de valeur regroupkm ' .($args->{regroupkm} || '') . ' ');

		#mise en forme montant pour enregistrement en bdd
		foreach my $value_numbers ( $args->{total_2777}, $args->{total_c455}, $args->{total_interet}) {
			# Cette fonction formate le montant et le libellé selon des spécifications définies.
			Base::Site::util::formatter_montant_et_libelle(\$value_numbers, undef);
		}

		$args->{libelle} = 'Décompte Intérêts CC '.$r->pnotes('session')->{Exercice_fin_DMY}.'';
		
		#Génération de l'écriture
		$sql = 'INSERT INTO tbljournal_staging (_session_id, id_entry, date_ecriture, libelle, numero_compte, lettrage, debit, credit, id_client, id_facture, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, _token_id, documents1, documents2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?)' ;
		@bind_array = ( 
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{libelle}, $args->{select_compte}, undef, 0, $args->{total_c455}*100, $r->pnotes('session')->{id_client}, $numero_piece, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, 'OD', $token_id, ($name_file || undef), ($args->{docs2} || undef),
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{libelle}, '442500', undef, 0, $args->{total_2777}*100, $r->pnotes('session')->{id_client}, $numero_piece, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, 'OD', $token_id, ($name_file || undef), ($args->{docs2} || undef),
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{Exercice_fin_YMD}, $args->{libelle}, '661500', undef, $args->{total_interet}*100, 0, $r->pnotes('session')->{id_client}, $numero_piece, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, 'OD', $token_id, ($name_file || undef), ($args->{docs2}|| undef) 
		);
		$dbh->do( $sql, undef, @bind_array ) ;
		
		$args->{numero_piece} = $numero_piece;
			
		my $location = export_pdf2( $r, $args );
			
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
                
		my ($return_identry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $token_id);
	
		#erreur dans la procédure store_staging : l'afficher dans le navigateur
		if ( $error_message ) {
			$content .= Base::Site::util::generate_error_message($error_message);	
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm =>	Comptabilisation des intérêts des comptes courants d\'associés au '.$r->pnotes('session')->{Exercice_fin_DMY}.' .');
			$args->{restart} = 'entry?open_journal=OD&mois=0&id_entry=' . $return_identry.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}    
	}
    
	#####################################       
	# Requête SQL						#
	#####################################  

	my $bdd_compte4 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '451,455');
	my $selected2 = (defined($args->{select_compte}) && $args->{select_compte} ne '') ? ($args->{select_compte} ) : undef;
	my ($onchange2, $form_name2, $form_id2)  = ('onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};"', 'select_compte', 'select_compte_'.$reqid.'');
	my $compte_tiers = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected2, $form_name2, $form_id2, $onchange2, 'class="forms2_input"', 'style="width: 30%"');
	
	############## Choix Sélection du nombre de jour 360 ou 365 ou 366 ##############	
	my $date_debut = Time::Piece->strptime($r->pnotes('session')->{Exercice_debut_YMD}, "%Y-%m-%d");
    # Ajouter une année à la date pour obtenir le 1er janvier de l'année suivante
	my $date_suivante = $date_debut->add_years(1);
	# Calculer la différence en jours entre les deux dates
	my $nombre_jours = ($date_suivante - $date_debut) / (24 * 60 * 60);
	
	# Sélection du nombre de jour 360 ou 365 ou 366
	my $select_nbday = '<select class="forms2_input" style="width: 20%" name=select_nbday id="select_nbday_'.$reqid.'">
	<option value="360" ' . ((defined $args->{select_nbday} && $args->{select_nbday} eq "360") ? ' selected' : '') . '>360</option>
	<option value="'.$nombre_jours.'" ' . ((defined $args->{select_nbday} && $args->{select_nbday} eq $nombre_jours || !defined $args->{select_nbday}) ? ' selected' : '') . '>'.$nombre_jours.'</option>
	</select>' ;
	
	#####################################       
	#Rechercher des entrées du journal
	#####################################    
	my $propo_list .= '';

	
	if (defined $args->{select_compte} && $args->{select_compte} ne '') {
	
	$sql = '
	SELECT t1.id_entry, t1.date_ecriture, t1.libelle_journal, t1.numero_compte,t2.libelle_compte, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, to_char((sum(t1.credit-t1.debit) over (PARTITION BY t1.numero_compte ORDER BY date_ecriture, id_facture, libelle))/100::numeric, \'999G999G999G990D00\') as solde, (sum(t1.credit-t1.debit) over (PARTITION BY t1.numero_compte ORDER BY date_ecriture, id_facture, libelle))/100::numeric as solde2
	FROM tbljournal t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.numero_compte = t2.numero_compte
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.numero_compte = ?
	ORDER BY date_ecriture, id_entry, id_line
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{select_compte}) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
	
	if (@$result_set) {
	
		$propo_list .= '
		<div class="Titre10 centrer">Calcul des Intérêts (en €)</div>
		<br>
		<ul class="wrapper style1">
	   ' ;

		#ligne d'en-têtes
		$propo_list .= '
		<li class="style1"><div class=flex-table><div class=spacer></div>
		<span class=headerspan style="width: 1%; ">&nbsp;</span>
		<span class=headerspan style="width: 8%;">Date</span>
		<span class=headerspan style="width: 8%;">Compte</span>
		<span class=headerspan style="width: 12%;">Pièce</span>
		<span class=headerspan style="width: 30%;text-align: left;">Libellé</span>
		<span class=headerspan style="width: 8%; text-align: right;">Débit</span>
		<span class=headerspan style="width: 8%; text-align: right;">Crédit</span>
		<span class=headerspan style="width: 8%; text-align: right;">Solde</span>
		<span class=headerspan style="width: 8%; text-align: right;">Nb Jours</span>
		<span class=headerspan style="width: 8%; text-align: right;">Intérêts</span>
		<span class=headerspan style="width: 1%; ">&nbsp;</span>
		<div class=spacer></div></div></li>
		' ;

		my $date_calcul = '';
		my $solde = '';
		my $date_prec;
		my $date_en_cours = '';
		my $date_nb_jour = '';
		my $date_fin = Time::Piece->strptime($r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d");
		my $date_n1 = Time::Piece->strptime($result_set->[1]->{date_ecriture}, "%d/%m/%Y");
		my $calcul_interet = 0;
		my $total_interet = 0;
		my $solde_prec = 0;
		
		##Mise en forme de la date dans Exercice_fin_YMD de %Y-%m-%d vers 29/02/2000
		my $date_fin_dmy = eval {Time::Piece->strptime($r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d")->dmy("/")};
		
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper(@$result_set) . ' ');

		my $id_entry = '' ;
		my $id_entry_href;
		
		for ( @$result_set ) {
			
			if ( defined $id_entry ) { 
				unless ( $_->{id_entry} eq $id_entry ) {
					#lien de modification de l'entrée
					$id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry} ;
					#cas particulier de la première entrée de la liste : pas de liste précédente
					unless ( $id_entry ) {
						$propo_list .= '<li class=listitem3>' ;
					} else {
						$propo_list .= '</a></li><li class=listitem3>'
					}
				}
		
			}
			
			if ($result_set && defined $_->{date_ecriture} && $_->{date_ecriture} ne '') {
				$date_en_cours = Time::Piece->strptime($_->{date_ecriture}, "%d/%m/%Y");
				if ($date_prec) {
				if ($date_en_cours eq $date_fin && $date_prec ne $date_fin){
					$date_nb_jour = ($date_en_cours - $date_prec)->days + 1;	
				} else {
					$date_nb_jour = ($date_en_cours - $date_prec)->days ;	
				}
				
				} else {
				$date_nb_jour = ($date_debut - $date_en_cours)->days ;
				}
				$calcul_interet = (($date_nb_jour * $solde_prec * $args->{taux})/100)/$args->{select_nbday};

				if(($calcul_interet=~/\d/) && ($calcul_interet >= 0) && ($calcul_interet < 999999999999999)){
				$total_interet += $calcul_interet;
				}
				($calcul_interet = sprintf( "%.2f",$calcul_interet)) =~ s/\./\,/g;
				$calcul_interet =~ s/\B(?=(...)*$)/ /g ;
				$solde_prec = $_->{solde2} || 0;
				$date_prec = Time::Piece->strptime($_->{date_ecriture}, "%d/%m/%Y");	
				
				$propo_list .= '
				<div class=flex-table><div class=spacer></div><a href="' . ($id_entry_href || ''). '" >
				<span class=displayspan style="width: 1%; ">&nbsp;</span>
				<span class=displayspan style="width: 8%;">' . $_->{date_ecriture} . '</span>
				<span class=displayspan style="width: 8%;">' . ($_->{numero_compte} || '&nbsp;') . '</span>
				<span class=displayspan style="width: 12%;">' . ($_->{id_facture} || '&nbsp;'). '</span>
				<span class=displayspan style="width: 30%; text-align: left;">' . ($_->{libelle} || '&nbsp;') . '</span>
				<span class=displayspan style="width: 8%; text-align: right;">' . ($_->{debit} || '&nbsp;') . '</span>
				<span class=displayspan style="width: 8%; text-align: right;">' .  ($_->{credit} || '&nbsp;') . '</span>
				<span class=displayspan style="width: 8%; text-align: right;">' .  ($_->{solde} || '&nbsp;') . '</span>
				<span class=displayspan style="width: 8%; text-align: right;">'.$date_nb_jour.'</span>
				<span class=displayspan style="width: 8%; text-align: right;">'.$calcul_interet.'</span>
				<span class=displayspan style="width: 1%; ">&nbsp;</span>
				<div class=spacer>
				</div>
				</div>
				' ;
			}

			#marquer l'entrée en cours
			$id_entry = $_->{id_entry} ;

		} #    for ( @$result_set ) 
    
    $args->{last31} = 0;
    
    if ($date_en_cours eq $date_fin){
	#on clot la liste s'il y avait au moins une entrée dans le journal
    $propo_list .= '</a></li>' if ( @$result_set ) ;	
    $args->{last31} = 1;
	} else {
		
	$date_nb_jour = ($date_fin - $date_en_cours)->days + 1;
    $calcul_interet = (($date_nb_jour * $solde_prec * $args->{taux})/100)/$args->{select_nbday};
    if(($calcul_interet=~/\d/) && ($calcul_interet >= 0) && ($calcul_interet < 999999999999999)){
	$total_interet += $calcul_interet;
	}
    ($calcul_interet = sprintf( "%.2f",$calcul_interet)) =~ s/\./\,/g;
	$calcul_interet =~ s/\B(?=(...)*$)/ /g ;	
	#on clot la liste s'il y avait au moins une entrée dans le journal
    $propo_list .= '</a></li>
    <li>
    <div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 1%; ">&nbsp;</span>
	<span class=displayspan style="width: 8%;">'.$date_fin_dmy.'</span>
	<span class=displayspan style="width: 8%;">&nbsp;</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 30%; text-align: left;">&nbsp;</span>
	<span class=displayspan style="width: 8%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 8%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 8%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 8%; text-align: right;">'.$date_nb_jour.'</span>
	<span class=displayspan style="width: 8%; text-align: right;">'.$calcul_interet.'</span>
	<span class=displayspan style="width: 1%; ">&nbsp;</span>
	<div class=spacer>
	</div>
	</div>
    </li>
    ' if ( @$result_set ) ;	
	}
	
	
	my $ab = ($total_interet * 12.8)/100;
	my $qg = ($total_interet * 9.2)/100;
	my $qh = ($total_interet * 7.5)/100;
	my $aai = ($total_interet * 0.5)/100;

	# Préparation calculs des totaux avec arrondies
	foreach my $value_numbers ( 
	#variable
	$ab, $qg, $qh, $aai) {
	$value_numbers =~ s/\,/\./g;
	if(($value_numbers=~/\d/) && ($value_numbers >= 0) && ($value_numbers < 999999999999999)){
	$value_numbers = int(($value_numbers)+ 0.5) ;
	} elsif (($value_numbers=~/\d/) && ($value_numbers < 0) && ($value_numbers > -999999999999999)) {
	$value_numbers = int(($value_numbers)- 0.5) ;
	} else { 
	$value_numbers = '0';
	}}
	
	my $total_2777 = $ab + $qg + $qh + $aai;
	my $total_c455 = $total_interet - ($ab + $qg + $qh + $aai) ;
	
	($args->{ab} = sprintf( "%.2f",$ab)) =~ s/\./\,/g;
	$args->{ab} =~ s/\B(?=(...)*$)/ /g ;
	($args->{qg} = sprintf( "%.2f",$qg)) =~ s/\./\,/g;
	$args->{qg} =~ s/\B(?=(...)*$)/ /g ;
	($args->{qh} = sprintf( "%.2f",$qh)) =~ s/\./\,/g;
	$args->{qh} =~ s/\B(?=(...)*$)/ /g ;
	($args->{aai} = sprintf( "%.2f",$aai)) =~ s/\./\,/g;
	$args->{aai} =~ s/\B(?=(...)*$)/ /g ;
	($args->{total_2777} = sprintf( "%.2f",$total_2777)) =~ s/\./\,/g;
	$args->{total_2777} =~ s/\B(?=(...)*$)/ /g ;
	($args->{total_c455} = sprintf( "%.2f",$total_c455)) =~ s/\./\,/g;
	$args->{total_c455} =~ s/\B(?=(...)*$)/ /g ;
	($args->{total_interet} = sprintf( "%.2f",$total_interet)) =~ s/\./\,/g;
	$args->{total_interet} =~ s/\B(?=(...)*$)/ /g ;
	
	my $print_href = '/'.$r->pnotes('session')->{racine}.'/menu?imprimer';
	my $comptabilisation_href = '/'.$r->pnotes('session')->{racine}.'/menu?comptabiliser=0';
    
    $propo_list .=  '
    <li class=listitem3><hr></li>
    
    <li><div class=spacer></div>
    <span class=displayspan style="width: 1%; ">&nbsp;</span>
	<span class=displayspan style="width: 8%;">&nbsp;</span>
	<span class=displayspan style="width: 8%;">&nbsp;</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 30%; text-align: right; font-weight: bold;">Total</span>
	<span class=displayspan style="width: 8%; text-align: right; font-weight: bold;">' . ( $result_set->[0]->{total_debit} || 0 ) . '</span>
	<span class=displayspan style="width: 8%; text-align: right; font-weight: bold;">' . ( $result_set->[0]->{total_credit} || 0 ) . '</span>
	<span class=displayspan style="width: 8%;">&nbsp;</span>
	<span class=displayspan style="width: 8%;">&nbsp;</span>
	<span class=displayspan style="width: 8%;text-align: right; font-weight: bold;" >'.$args->{total_interet}.'</span>
	<span class=displayspan style="width: 1%; ">&nbsp;</span>
	</span><div class=spacer></li>

	<li><br></li>

	<li><br></li>
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 57%;text-align: center;font-weight: bold;">Formulaire 2777</span>
	<span class=displayspan style="width: 12%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 29%; text-align: center;font-weight: bold;">Écritures comptables correspondantes</span>

	<div class=spacer></div></div></li>
	
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 2%; ">&nbsp;</span>
	<span class=headerspan style="width: 6%; ">Case</span>
	<span class=headerspan style="width: 35%; text-align: left;">Description</span>
	<span class=headerspan style="width: 7%;text-align: right; ">Taux</span>
	<span class=headerspan style="width: 7%;text-align: right; ">Montant</span>
	<span class=headerspan style="width: 2%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 10%; text-align: right;">&nbsp;</span>
	<span class=headerspan style="width: 9%;text-align: right; ">Compte</span>
	<span class=headerspan style="width: 9%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 9%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 2%; ">&nbsp;</span>
	<div class=spacer></div></div></li>
	

	<li><div class=spacer></div>
    <span class=displayspan style="width: 2%; ">&nbsp;</span>
    <span class=displayspan style="width: 6%;">AB</span>
	<span class=displayspan style="width: 35%;text-align: left;">Intérêts, arrérages et produits de toute nature</span>
	<span class=displayspan style="width: 7%;text-align: right;">12,80%</span>
	<span class=displayspan style="width: 7%;text-align: right;">'.$args->{ab}.'</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;">'.($args->{select_compte} || '').'</span>
	<span class=displayspan style="width: 9%; text-align: right;">0,00</span>
	<span class=displayspan style="width: 9%; text-align: right; ">' . ( $args->{total_c455} || 0 ) . '</span>
	<span class=displayspan style="width: 2%; ">&nbsp;</span>
	</span><div class=spacer></li>
	
	<li><div class=spacer></div>
    <span class=displayspan style="width: 2%; ">&nbsp;</span>
    <span class=displayspan style="width: 6%;">QG</span>
	<span class=displayspan style="width: 35%;text-align: left;">Contribution sociale</span>
	<span class=displayspan style="width: 7%;text-align: right;">9,20%</span>
	<span class=displayspan style="width: 7%;text-align: right;">'.$args->{qg}.'</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;">442500</span>
	<span class=displayspan style="width: 9%; text-align: right;">0,00</span>
	<span class=displayspan style="width: 9%; text-align: right; ">' . ( $args->{total_2777} || 0 ) . '</span>
	<span class=displayspan style="width: 2%; ">&nbsp;</span>
	</span><div class=spacer></li>
	
	<li><div class=spacer></div>
    <span class=displayspan style="width: 2%; ">&nbsp;</span>
    <span class=displayspan style="width: 6%;">QH</span>
	<span class=displayspan style="width: 35%;text-align: left;">solidarité</span>
	<span class=displayspan style="width: 7%;text-align: right;">7,50%</span>
	<span class=displayspan style="width: 7%;text-align: right;">'.$args->{qh}.'</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;">661500</span>
	<span class=displayspan style="width: 9%; text-align: right;">'.$args->{total_interet}.'</span>
	<span class=displayspan style="width: 9%; text-align: right; ">0,00</span>
	<span class=displayspan style="width: 2%; ">&nbsp;</span>
	</span><div class=spacer></li>
	
	<li><div class=spacer></div>
    <span class=displayspan style="width: 2%; ">&nbsp;</span>
    <span class=displayspan style="width: 6%;">AAI</span>
	<span class=displayspan style="width: 35%;text-align: left;">Contribution remboursement dette sociale</span>
	<span class=displayspan style="width: 7%;text-align: right;">0,50%</span>
	<span class=displayspan style="width: 7%;text-align: right;">'.$args->{aai}.'</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;font-weight: bold;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;font-weight: bold;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;font-weight: bold; ">&nbsp;</span>
	<span class=displayspan style="width: 2%; ">&nbsp;</span>
	</span><div class=spacer></li>
	
	<li style="width: 59%;"><hr></li>
	
	<li><div class=spacer></div>
    <span class=displayspan style="width: 2%; ">&nbsp;</span>
    <span class=displayspan style="width: 6%;">&nbsp;</span>
	<span class=displayspan style="width: 35%;text-align: right;font-weight: bold;">Total</span>
	<span class=displayspan style="width: 7%;text-align: right;font-weight: bold;">30%</span>
	<span class=displayspan style="width: 7%;text-align: right;font-weight: bold;">'.$args->{total_2777}.'</span>
	<span class=displayspan style="width: 12%;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right;">&nbsp;</span>
	<span class=displayspan style="width: 9%; text-align: right; ">&nbsp;</span>
	<span class=displayspan style="width: 2%; ">&nbsp;</span>
	</span><div class=spacer></li>
	</ul>
	
	<form class=wrapper1 method="post" >
		<div class=formflexN3>
		<input type="submit" id=submit3 style="width: 10%;" class="btn btn-bleuf" formaction="' . $print_href . '" value="Imprimer" >
		<input type="submit" class="btn btn-noir" style="width : 10%;" formaction="' . $comptabilisation_href . '" value="Comptabiliser">
		</div>
		<input type=hidden name=menu08 value="1">
		<input type=hidden name="menu01" value=0 >
		<input type=hidden name=interet_cca value="1" >
		<input type=hidden name=taux value="' . ($args->{taux} || ''). '">
		<input type=hidden name=select_nbday value="' . ($args->{select_nbday} || ''). '">
		<input type=hidden name=select_compte value="' . ($args->{select_compte} || ''). '">
		<input type=hidden name=ab value="' . ($args->{ab} || ''). '">
		<input type=hidden name=qg value="' . ($args->{qg} || ''). '">
		<input type=hidden name=qh value="' . ($args->{qh} || ''). '">
		<input type=hidden name=aai value="' . ($args->{aai} || ''). '">
		<input type=hidden name=total_2777 value="' . ($args->{total_2777} || ''). '">
		<input type=hidden name=total_c455 value="' . ($args->{total_c455} || ''). '">
		<input type=hidden name=total_interet value="' . ($args->{total_interet} || ''). '">
		<input type=hidden name=last31 value="' . $args->{last31} . '">
	</form>

	' ;
	
	} else {
	$propo_list .= Base::Site::util::generate_error_message('Aucune écriture n\'a été trouvée, il n\'y a rien à calculer.');
	}
    
	} elsif (defined $args->{select_compte} && $args->{select_compte} eq '') { 
			
	$propo_list .= Base::Site::util::generate_error_message('Aucun compte n\'a été sélectionné, il n\'y a rien à calculer.');	
		
	} 

	############## MISE EN FORME DEBUT ##############
	
	#taux au 31/12/2022
	if (!$args->{taux} && $r->pnotes('session')->{Exercice_fin_YMD} eq '2022-12-31'){
	$args->{taux} = 2.21;	
	}
	#taux au 31/12/2021
	if (!$args->{taux} && $r->pnotes('session')->{Exercice_fin_YMD} eq '2021-12-31'){
	$args->{taux} = 1.17;	
	}
	
	my $contenu_search .= '
	
	<div class="Titre10 centrer">Génération des intérêts des comptes courants d\'associés </div>

	<form class=wrapper1 method=POST action=/'.$r->pnotes('session')->{racine}.'/menu>
	<div class=flex-checkbox>
	    <label style="width: 15%;" class="forms2_label" for="taux_'.$reqid.'">Taux à appliquer</label>
	    <label style="width: 20%;" class="forms2_label" for="select_nbday_'.$reqid.'">Nb jour dans l\'année</label>
        <label style="width: 33%;" class="forms2_label" for="select_compte_'.$reqid.'">Compte</label>
		<label style="width: 10%;" class="forms2_label" for="submit_'.$reqid.'">&nbsp;</label>
    </div>    
    
    <div class=flex-checkbox>
	<input class="forms2_input" style="width: 15%;" type=text id="taux_'.$reqid.'" name=taux value="' . ($args->{taux} || ''). '" required/>        
	' .  $select_nbday . '
	' .  $compte_tiers . '
	<input type=submit id="submit_'.$reqid.'" style="width: 10%;" class="btn btn-vert" value=Rechercher>	
    </div>
    <input type=hidden name=interet_cca value="1" >
	</form>
	';	
		
	$content .= $contenu_search . $propo_list;

    return $content ;
    ############## MISE EN FORME FIN ##############
    
} #sub forms_interet_cca

#/*—————————————— Formulaire Import CSV et OFX et OCR ——————————————*/
sub forms_importer {
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content, @errors, $type) ;
	my ($selected, $form_1 , $form_2, $form_3, $result) = ('', '', '', '', '');
    my $req = Apache2::Request->new($r);
    my $reqid = Base::Site::util::generate_reqline();
	my $journal_info = Base::Site::util::get_journal_info($r, $dbh);
	my $lib_journal_achats = $journal_info->{'Achats'};
	my $lib_journal_ventes = $journal_info->{'Ventes'};

    #Requête Postgresql
	my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	my $bdd_compte4 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '4,5112');
	my $bdd_compte411 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '41');
	my $bdd_compte401 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '40');
	my $bdd_compte6 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '6');
	my $bdd_compte7 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '165,7');
	my $result_reglement_set = Base::Site::bdd::get_parametres_reglements($dbh, $r);
													
    # Récupérer la valeur de la méthode d'importation actuelle
	my $current_import_method = $args->{import_method} || 'file';  # Par défaut à 'file'
	# Récupérer le journal, compte et libellé compte du mode de paiement 
	my ($param_journal, $param_compte, $param_libcompte) = Base::Site::bdd::get_parametres_reglements($dbh, $r, $args->{select_achats});
	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields_form1 = Base::Site::util::create_hidden_fields_form($args, [], [], []);
   
    #/************ ACTION DEBUT *************/
    

	if (defined $args->{importer} && defined $args->{select_achats} ) {
		
		my $csv_data;
		
		# Si la méthode d'importation est un fichier
		if ($args->{importer} eq '0' && $args->{import_method} eq 'file') {
				my $upload = $req->upload('import_file');
				if ($upload) {
					my $upload_fh = $upload->fh;
					$csv_data = do { local $/; <$upload_fh> };
					#Détecte le type de fichier (CSV ou OFX) à partir du contenu donné.
					$type = Base::Site::util::detect_csv_type_and_ofx($csv_data);
					if ($type eq "Inconnu") {push @errors, "Le contenu du champ de texte ne ressemble ni à une structure CSV valide avec au moins deux lignes, ni à une structure OFX valide.";} else {
					$current_import_method = 'textarea';
					$args->{encrypted_script_csv} = Base::Site::util::encode_xor_and_base64($csv_data, "your_secret_key");  # Encryptage XOR
					$hidden_fields_form1 = Base::Site::util::create_hidden_fields_form($args, ['import_file'], [], [['import_method', 'textarea']]);
					}
				} else {
					push @errors, "Aucun fichier n'a été téléchargé. Veuillez télécharger un fichier avant de continuer.";
				}
				
			# Si la méthode d'importation est un textarea, vérifie si le contenu est vide	
		} elsif ($args->{import_method} eq 'textarea') {
				#$content .= '<h3>Contenu brut du fichier ou textarea : <pre>' . $args->{encrypted_script_csv} . '</pre></h3>';
				my $encrypted_base64_script = $args->{encrypted_script_csv};
				#my $encoded_script = decode_base64($encrypted_base64_script); # Décodage Base64
				my $decrypted_script = Base::Site::util::decode_xor_and_base64($encrypted_base64_script, "your_secret_key");  # Décryptage XOR
				#$csv_data = $args->{csv_content};
				$csv_data = $decrypted_script;
				if (!defined $csv_data or $csv_data eq '') {
					push @errors, "Le contenu du champ de texte est vide. Veuillez saisir un texte avant de soumettre le formulaire.";
				} else {
					#Détecte le type de fichier (CSV ou OFX) à partir du contenu donné.
					$type = Base::Site::util::detect_csv_type_and_ofx($csv_data);
					if ($type eq "Inconnu") {push @errors, "Le contenu du champ de texte ne ressemble ni à une structure CSV valide avec au moins deux lignes, ni à une structure OFX valide.";}
				}
		} elsif ($args->{import_method} eq 'ocr') {
			# On interdit les documents vides
			if (!$args->{docs2}) {
				push @errors,"La sélection d'un document est obligatoire. Veuillez choisir un document avant de poursuivre.";
			} else {
				# Appeler la sous-routine et stocker le message retourné ainsi que les lignes traitées
				my ($message_resultat, $csv_data) = function_ocr($dbh, $r, $args);
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper ' . Data::Dumper::Dumper(@$csv_data) . ' ');
				if ($message_resultat){
					push @errors, $message_resultat;
				} else {
					$type = "ocr";
				}
			}
		}
			
		# On interdit les documents vides
		if (!$args->{select_achats}) {
			push @errors, " La sélection d'un règlement est obligatoire. Veuillez choisir un règlement avant de poursuivre.";
		} else {
			#Si nous avons un fichier de type csv-paypal
			if (defined $type && $type ne '' && $type ne 'Inconnu' && defined $args->{select_achats}) {
				if ($type eq 'csv-paypal'){
					$form_2 .= process_csv_and_generate_html_form($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $csv_data, $type);   
				} elsif ($type eq 'boursorama'){
					$form_2 .= process_csv_and_generate_html_form($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $csv_data, $type);   
				} elsif ($type eq 'ofx'){
					my $result = Base::Site::util::parse_scalar($csv_data); 
					$form_2 .= process_csv_and_generate_html_form($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $result, $type);   
					#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper ' . Data::Dumper::Dumper(@$result) . ' ');
				} elsif ($type eq 'ocr'){
					my ($message_resultat, $csv_data) = function_ocr($dbh, $r, $args);
					#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper ' . Data::Dumper::Dumper(@$csv_data) . ' ');
					$form_2 .= process_csv_and_generate_html_form($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $csv_data, $type);   

				} else {
					push @errors, "Format non reconnu.";
				}
			}
		}
	} 
	
	#Traiter la sélection des écritures pour enregistrement dans tbljournal_staging
	if (defined $args->{importer} and $args->{importer} eq '1') {
		
		my @selected_lines;  # Tableau pour stocker les lignes sélectionnées

		# Parcours des paramètres de la requête pour trouver les lignes sélectionnées
		foreach my $param_name (keys %$args) {
			if ($param_name =~ /^selected_checkbox_(\d+)$/ && $args->{$param_name} eq 'on') {
				my $line_number = $1;
				my $lineid = 'line_' . $line_number;

				# Vérification si la case à cocher est cochée
				if ($args->{$param_name}) {
					# Création d'un hash de données pour la ligne sélectionnée
					my %selected_line = (
						date_comptant => $args->{"date_$line_number"},
						libelle => $args->{"csv_libelle_$line_number"},
						credit => $args->{"csv_credit_$line_number"},
						debit => $args->{"csv_debit_$line_number"},
						docs2 => $args->{docs2},
						journal => $args->{select_achats},
						select_achats => $args->{select_achats},
						piece => $args->{"calcul_piece_$line_number"},
						libre => $args->{"libre_$line_number"},
						compte_comptant => $args->{"csv4_$line_number"},
						compte_client => $args->{"csv41_$line_number"},
						compte_fournisseur => $args->{"csv40_$line_number"},
						compte_charge => $args->{"csv6_$line_number"},
						compte_produit => $args->{"csv7_$line_number"},
						docs1 => $args->{"docs1_$line_number"},
						id_name => $args->{id_name},
						type => $args->{"select_type_$line_number"},
						check_comptant => $args->{"selected_comptant_$line_number"},
						id_compte_1_select => $args->{"select_reglement_1_$line_number"},
						id_compte_2_select => $args->{"select_reglement_2_$line_number"},
						lineid => $lineid,
					);

					# Supprime les espaces de début et de fin de ligne
					$selected_line{libelle} =~ s/^\s+|\s+$//g;
					# Supprime les espaces consécutifs supérieurs à 1 dans le libellé
					$selected_line{libelle} =~ s/\s{2,}/ /g;

					# Ajout des données de la ligne sélectionnée au tableau
					push @selected_lines, \%selected_line;
				}
			}
		}

		# Tri des lignes sélectionnées par date (avant la boucle d'affichage)
		@selected_lines = sort { $a->{date_comptant} cmp $b->{date_comptant} } @selected_lines;
		
		my @errors;  # Tableau pour stocker les erreurs
		
		# Affichage des données des lignes sélectionnées triées par date
		foreach my $line (@selected_lines) {
			#$content .= 'Date: '.$line->{date}.', Nom: '.$line->{libelle}.', Debit: '.$line->{debit}.', Crédit: '.$line->{credit}.', Docs2: '.$line->{docs2}.' select_achat: '.$line->{achats}.' selected_csv6: '.$line->{compte6}.' selected_csv4: '.$line->{compte4}.' selected_csv41: '.$line->{compte41}.' selected_csv40: '.$line->{compte40}.' selected_type: '.$line->{type}.' $selected_reglement_1 : '.$line->{reglement_1}.' $selected_reglement_2 : '.$line->{reglement_2}.' selected_doc1: '.$line->{doc1}.'<br>';
			
			my $montant = ($line->{debit} != 0) ? $line->{debit} : ($line->{credit} != 0) ? $line->{credit} : 0;
			
		if ($line->{type} eq 'transfert') {
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([6,$line->{id_compte_1_select}], [7,$line->{id_compte_2_select}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'depense' && $line->{check_comptant} eq 'on'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([15,$lib_journal_achats], [12,$line->{compte_charge}], [1,$line->{compte_fournisseur}], [2,$line->{select_achats}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'depense' && $line->{check_comptant} eq 'off'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([12,$line->{compte_charge}], [2,$line->{select_achats}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'recette' && $line->{check_comptant} eq 'on'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([16,$lib_journal_ventes], [11,$line->{compte_produit}], [4,$line->{compte_client}], [2,$line->{select_achats}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'recette' && $line->{check_comptant} eq 'off'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([11,$line->{compte_produit}], [2,$line->{select_achats}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'reglement_client'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([2,$line->{select_achats}], [17,$line->{compte_comptant}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} elsif ($line->{type} eq 'reglement_fournisseur'){
				my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, ([17,$line->{compte_comptant}], [2,$line->{select_achats}], [3,$montant], [8,$line->{date_comptant}], [10,$line->{libelle}]));
				if ($erreur) {
					push @errors, "Ligne ".substr($line->{lineid}, -2). ": <br>".$erreur." <br>";
					$form_3 .= Base::Site::util::highlight_error_line($line->{lineid});
				}
			} 
		}
		
		# Si aucune erreur n'a été trouvée, effectuer le traitement pour toutes les lignes
		if (!@errors) {
			foreach my $line (@selected_lines) {
					my $montant = ($line->{debit} != 0) ? $line->{debit} : ($line->{credit} != 0) ? $line->{credit} : 0;
				
				if ($line->{type} eq 'transfert') {
					@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'transfert', @errors);
				} elsif ($line->{type} eq 'recette' && $line->{check_comptant} eq 'off') {
						@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'recette1', @errors);
				} elsif ($line->{type} eq 'recette' && $line->{check_comptant} eq 'on') {
					@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'recette3', @errors);
				} elsif ($line->{type} eq 'depense' && $line->{check_comptant} eq 'off') {
						@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'depense1', @errors);
				} elsif ($line->{type} eq 'depense' && $line->{check_comptant} eq 'on') {
					@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'depense3', @errors);
				} elsif ($line->{type} eq 'reglement_client') {
					@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'reglement_client', @errors);
				} elsif ($line->{type} eq 'reglement_fournisseur') {
					@errors = Base::Site::util::traiter_ligne($r, $dbh, $line, $montant, 'reglement_fournisseur', @errors);
				}
			}
		}

		# Après avoir traité toutes les lignes
		if (@errors) {
			# Afficher les erreurs à l'utilisateur
			$form_3 .= Base::Site::util::generate_error_message(join('<br>', @errors));
		} else {
			# Aucune erreur, vous pouvez afficher un message de succès ou effectuer d'autres actions.
			$hidden_fields_form1 = Base::Site::util::create_hidden_fields_form($args, [], [], [['importer', '0']]);
		}

	#demande confirmation validation des ecritures importer	
	} elsif ( defined $args->{importer} and $args->{importer} eq '4' ) {
		
		my $message2 = 'Souhaitez-vous réellement valider toutes les écritures en attente de validation ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'importer', $args->{importer}, $hidden_fields_form1, 7);
		$content .= Base::Site::util::generate_error_message($confirmation_message);
		
	#demande confirmation suppression des ecritures importer		
	} elsif ( defined $args->{importer} and $args->{importer} eq '5' ) {
	
		my $message2 = 'Souhaitez-vous réellement supprimer toutes les écritures en attente de validation ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'importer', $args->{importer}, $hidden_fields_form1, 6);
		$content .= Base::Site::util::generate_error_message($confirmation_message);
	
	#suppression des ecritures
	} elsif ( defined $args->{importer} and $args->{importer} eq '6' ) {	
		
		Base::Site::bdd::delete_tbljournal_staging($r, $dbh, '%csv%');
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures csv : Suppression de toutes les écritures qui étaient en attente de validation.');
	
	#validation des ecritures
	} elsif ( defined $args->{importer} and $args->{importer} eq '7' ) {
				
		my $result_gen = Base::Site::bdd::get_token_ids($r, $dbh, '%csv%');
		
		foreach ( @{$result_gen} ) {
			my $_token_id = $_->{_token_id};
			my ($return_entry, $error_message) = Base::Site::bdd::call_record_staging($dbh, $_token_id);
			push @errors, $error_message if $error_message;
		}

		# Après avoir traité toutes les lignes
		if (@errors) {
			$form_3 .= Base::Site::util::generate_error_message(join('<br>', @errors));
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Écritures csv : Toutes les écritures qui étaient en attente de validation ont été validées avec succès.');
			$args->{restart} = ((defined $args->{id_name} && $args->{id_name} ne '') || (defined $args->{docs2} && $args->{docs2} ne '')) ? 'docsentry?id_name='.($args->{id_name}||$args->{docs2}).'&importer=' : 'menu?importer';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
	}

	#/************ ACTION FIN *************/
	
	if (@errors) {
		$content .= Base::Site::util::generate_error_message(join('<br>', @errors));
	}
	#####################################       
	# Récupérations d'informations		#
	#####################################  


	#Requête et Formulaire Recherche de la liste des documents enregistrés
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
	my $selected1 = (defined($args->{docs2}) && $args->{docs2} ne '') || (defined($args->{id_name}) && defined($args->{label9}) && $args->{label9} eq '1') ? ($args->{docs2} || $args->{id_name}) : undef;
	my ($form_name1, $form_id1) = ('docs2', 'docs2_'.$reqid.'');
	my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input" ', 'style ="width : 25%;"');

    #Requête et Formulaire Règlements
    my $resultat_tblconfig = Base::Site::bdd::get_parametres_reglements($dbh, $r);
    my $selected3 = (defined($args->{select_achats}) && $args->{select_achats} ne '') ? ($args->{select_achats} ) : undef;
    my ($form_name3, $form_id3) = ('select_achats', 'select_achats_'.$reqid.'');
	my $onchange3 = "onchange=\"if(this.selectedIndex == 0){document.location.href='parametres?achats'};\"";
	my $select_achats = Base::Site::util::generate_reglement_selector($resultat_tblconfig, $reqid, $selected3, $form_name3, $form_id3, $onchange3, 'class="forms2_input"', 'style="width: 15%;"');

	#####################################       
	# Formulaire HTML					#
	##################################### 
	
    # Ajout de la section JavaScript pour gérer l'affichage conditionnel
    #$form_3 .= '<script>
    #    //var helpLink3 = document.getElementById("help-link3");
	#	// Gérer l\'événement lorsque la souris survole le lien
	#	helpLink3.addEventListener("mouseover", function () {
	#	memo10.style.display = "flex";
	#	});
	#	// Gérer l\'événement lorsque la souris quitte le lien
	#	helpLink3.addEventListener("mouseout", function () {
	#	memo10.style.display = "none";
	#	});
	#	if (document.getElementById("ocr_section").style.display === "block") {
	#		document.getElementById("labeldoc2").textContent = "Sélectionner le document pour l\'OCR";
	#	} else {
	#		document.getElementById("labeldoc2").textContent = "Documents 2";
	#	}
	#	</script>';
		
    $form_1 .= '<script>

        function toggleImportMethod() {
            var fileSection = document.getElementById("file_section");
            var OCRSection = document.getElementById("ocr_section");
            var textareaSection = document.getElementById("textarea_section");
            var fileRadio = document.getElementById("file_radio");
            var textareaRadio = document.getElementById("textarea_radio");
            var OCRRadio = document.getElementById("ocr_radio");
            var labelDoc2 = document.getElementById("labeldoc2");

            if (fileRadio.checked) {
                fileSection.style.display = "block";
                textareaSection.style.display = "none";
                OCRSection.style.display = "none";
                labelDoc2.textContent = "Documents 2";
            } else if (textareaRadio.checked) {
                fileSection.style.display = "none";
                textareaSection.style.display = "block";
                OCRSection.style.display = "none";
                labelDoc2.textContent = "Documents 2";
            } else if (OCRRadio.checked) {
                fileSection.style.display = "none";
                OCRSection.style.display = "block";
                textareaSection.style.display = "none";
                labelDoc2.textContent = "Sélectionner le document pour l\'OCR";
            }
        }
		
		</script>';
		
	my $var_idname = '';
	if (defined $args->{id_name} && $args->{id_name} ne ''){$var_idname = 'id_name='.$args->{id_name}.'&amp;';}
		
	#1er Formulaire importation du fichier
    $form_1 .= '
		<div class="Titre10 centrer">Importation de relevé bancaire en CSV ou OFX ou via OCR </div>
        
        <div id="memo10" class="flex1 centrer" ><div class="memoinfo2">Le mode de paiement détermine le journal et le compte de trésorerie qui seront utilisés.</div></div>
        
        <div class="form-int">
        <form id=test action="' . $r->uri() . '?'.$var_idname.'importer=0" method="POST" enctype="multipart/form-data" onsubmit="encryptTextArea();" accept-charset="UTF-8">
				
			<div class=formflexN2>
			<label style="width: 15%;" class="forms2_label"  for="select_achats_'.$reqid.'">Mode de paiement</label>
			<label style="width: 35%;" class="forms2_label"  for="file_radio">Méthode d\'importation</label>
			<label id="labeldoc2" style="width: 25%;" class="forms2_label" for="docs2_'.$reqid.'">Documents 2 </label>
			</div>   
    
			<div class=formflexN2>
			' . $select_achats . '  
			<div style ="width : 35%; " class="formflexN1 flex1" style="font-weight: bold;" id="importation_section">
				<input class="custom-radio" type="radio" id="file_radio" name="import_method" value="file"' . ($current_import_method eq 'file' ? ' checked' : '') . ' onclick="toggleImportMethod()">
				<label for="file_radio">Fichier</label>
				<input class="custom-radio" type="radio" id="textarea_radio" name="import_method" value="textarea"' . ($current_import_method eq 'textarea' ? ' checked' : '') . ' onclick="toggleImportMethod()">
				<label for="textarea_radio">Textarea</label>
				<input class="custom-radio" type="radio" id="ocr_radio" name="import_method" value="ocr"' . ($current_import_method eq 'ocr' ? ' checked' : '') . ' onclick="toggleImportMethod()">
				<label for="ocr_radio">OCR</label>
            </div>
            ' . $document_select1 . '
			</div>
			
			<div class=formflexN2> 
				<div class="formflexN1 centrer" id="file_section"' . ($current_import_method eq 'file' ? ' style="display: block;"' : 'style="display: none;"') . '>
                    <label  for="import_file"></label>
                    <input type="file" id="import_file" name="import_file">
                </div>
                <div class="formflexN1 centrer" id="textarea_section"' . ($current_import_method eq 'textarea' ? ' style="display: block;"' : 'style="display: none;"') . '>
                    <label  for="csv_content">Contenu CSV ou OFX :</label>
                    <pre><textarea id="csv_content" name="csv_content" rows="7" cols="175" >' . ($current_import_method eq 'textarea' ? Base::Site::util::decode_xor_and_base64($args->{encrypted_script_csv}, "your_secret_key") : '') . '</textarea></pre>
                </div>
                <div class="formflexN1 centrer" id="ocr_section"' . ($current_import_method eq 'ocr' ? ' style="display: block;"' : 'style="display: none;"') . '>
				</div>
			</div>
				
			<div class="formflexN3">
				<input type="submit" id="submit_'.$reqid.'" style="width: 15%;" class="btn btn-gris" value="Importer">
			</div>
					<input type="hidden" name="id_name" value="'.($args->{id_name} || '').'">
                    <input type="hidden" name="encrypted_script_csv" id="encrypted_script_csv">
                    <input type="hidden" name="menu11" value="1">
                    <input type="hidden" name="label11" value="'.($args->{label11} || '').'">
                    
					
        </form></div>';
        
	#Vérification si des écritures importer n'en pas encore été générée dans tbljournal_staging 
	my ($verif_list, $entry_list) = Base::Site::util::check_and_format_ecritures_tbljournal_staging($dbh, $r, $args, 'importer', '%csv%', $hidden_fields_form1);

    $content .= $form_1 . $form_2. $form_3;
    $content .= ($verif_list || '') . ($entry_list || '') ;
    return $content;
}

# Définitions des sidebars			#
##################################### 
#/*—————————————— side_bar_1 => Premiers pas ——————————————*/
sub side_bar_1 {
	my ( $r ) = @_ ;
	my $content = "
		<li class='titre-link'>Premiers pas</li>
		<li><a href='#introduction'>Fonctionnement général</a></li>
		<li><a href='#journaux'>Journaux</a></li>
		<li><a href='#comptes'>Comptes</a></li>
		<li><a href='#documents'>Documents</a></li>
		<li><a href='#ecriturescomptables'>Ecritures comptables</a></li>
		<li><a href='#parametres'>Paramètres</a></li>
		<li><a href='#tva'>Déclaration de TVA</a></li>
	";
	 return $content ;
} #sub side_bar_1 

#/*—————————————— side_bar_2 => Courant ——————————————*/
sub side_bar_2 {
	my $content = "
 		<li class='titre-link' >Courant</li>
 		<li><a href='#affectation'>Affectation du résultat</a></li>
		<li><a href='#cca'>Comptes Courants Associés</a></li>
		<li><a href='#creances'>Les Créances</a></li>
		<li><a href='#ecarts'>Ecarts de règlement</a></li>
		<li><a href='#immobiliere'>Ecritures Immobilières</a></li>
		<li><a href='#declaration'>Les déclarations</a></li>
		<li><a href='#impots'>Les impôts</a></li>
		<li><a href='#paiement'>Les Paiements</a></li>
		<li><a href='#travaux_periodiques'>Travaux periodiques</a></li>
	";
	 return $content ;
} #sub side_bar_new 

#/*—————————————— side_bar_3 => Utilitaires  ——————————————*/
sub side_bar_3 {
	my $content = "
		<li class='titre-link'>Utilitaires</li>    
		<li><a href='#importexport'>Import/Export</a></li>
	";
	 return $content ;
} #sub side_bar_new 

#/*—————————————— side_bar_4 => Exercice Comptable  ——————————————*/
sub side_bar_4 {
	my $content = "
		<li class='titre-link'>Exercice Comptable</li> 
		<li><a href='#reconduite'>Début d'exercice</a></li>
		<li><a href='#cloture'>Clôture d'exercice</a></li>
		<li><a href='#prepcloture'>Check-list avant clôture</a></li>
	";
	 return $content ;
} #sub side_bar_4 

#/*—————————————— side_bar_5 => Utilitaires  ——————————————*/
sub side_bar_5 {
	my $content = "
		<li class='titre-link'>Paramétrage</li> 
		<li><a href='#version'>Gestion des versions</a></li>
	";
	 return $content ;
} #sub side_bar_5 

# Définitions des articles			#
#####################################  
#/*—————————————— articles_bar1 => Premiers pas ——————————————*/
sub articles_bar1 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my @hidden = ('0') x 40;
	my @section = ('0') x 40;
	my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
	my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);

	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 
    
    # sélection du journal pour formulaire
    $sql = 'SELECT libelle_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $journal_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;
	my $journal_entree = '<select style="margin-left: 1ch;" name=journal>' ;
	for ( @$journal_set ) {
	$journal_entree .= '<option value="' . $_->{libelle_journal} . '">' . $_->{libelle_journal} . '</option>' ;
	}
	$journal_entree .= '</select>' ;

#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";

	if ($r->pnotes('session')->{type_compta} eq 'tresorerie') {	
		$section[1] = '
		<p class="title1">Saisie rapide</p>
		<p>La saisie rapide simplifie la comptabilisation des écritures.
		<br><a href="parametres?achats"><strong>Paramètres =&gt; Mode paiement</strong></a> détermine le journal et le compte de trésorerie qui seront utilisés.</strong>
		<br><p>Lors de l\'importation de relevé bancaire en CSV ou OFX ou via OCR vous retrouverez :</p>
		<ul><li><strong>Recette</strong> pour compte financier (D5) vers compte de produit (C7).</li>
		<li><strong>Autres entrées d\'argent</strong> pour compte financier (D5) vers compte de tiers (C4).</li>
		<li><strong>Dépense</strong> pour compte financier (C5) vers compte de charge &nbsp;(D6).</li>
		<li><strong>Autres sorties d\'argent</strong> pour compte financier (C5) vers compte de tiers (D4).</li>
		<li><strong>Transfert entre compte</strong> pour enregistrer les deux écritures de transfert passant par le compte d\'attente 580000 – Virement Interne grâce à une seule opération avec lettrage automatique.</li>
		</ul>
		<br><p>Voici les différents types de saisie disponibles.</p>
		<ul class="summary">
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_recette\')">Saisie de Type "Recette"</a></li>
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_depense\')">Saisie de Type "Dépense"</a></li>
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_transfert\')">Saisie de Type "Transfert entre compte"</a></li>
		</ul>
		<hr class="mainPageTutoriel">
		<details id="type_recette" class="warningdoc" open=""><summary class="title1">Saisie de Type "Recette"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Recette => Permet d\'enregistrer la recette sur le compte financier (classe 5) et créditer le compte de produit (classe 7).</p>
			' . Base::Site::util::generer_tableau('Journal de type "Banque"', [
				[512, 'Banque', 'Réglement Client Toto', 'Montant', ''],
				[706, 'Prestations de services', 'Réglement Client Toto', '', 'Montant'],
			]) . '
			<p class="classp">Autres entrées d\'argent => Permet d\'enregistrer une autre entrée d\'argent sur le compte financier (classe 5) et créditer un autre compte.</p>
			<p>Exemple: un apport d\'un associé</p>
				' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[455, 'Associé', 'Apport associé', '', 'Montant'],
				[512, 'Banque', 'Apport associé', 'Montant', ''],
			]) . '
		</details>
		
		<details id="type_depense" class="alert" open=""><summary class="title1">Saisie de Type "Dépense"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Dépense => Permet d\'enregistrer la dépense sur le compte financier (classe 5) et débiter le compte de charge (classe 6).</p>
			' . Base::Site::util::generer_tableau('Journal de type "Banque"', [
				[512, 'Banque', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
				[626100, 'Frais postaux', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
			]) . '
			<p class="classp">Autres sorties d\'argent => Permet d\'enregistrer une autre sortie d\'argent sur le compte financier (classe 5) et débiter un autre compte.</p>
			<p>Exemple: remboursement d\'un associé</p>
			' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[455, 'Associé', 'Remboursement associé', 'Montant', ''],
				[512, 'Banque', 'Remboursement associé', '', 'Montant'],
			]) . '
		</details>
		
		<details id="type_transfert" class="alerte" open=""><summary class="title1">Saisie de Type "Transfert entre compte"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Saisie d\'un transfert entre compte via deux écritures comptables :</p>
			<p>Pour virer de l’argent d’un compte bancaire à l’autre en comptabilité, vous devez impérativement passer par un compte d’attente "580000 – Virement Interne".
			<br>En utilisant "Transfert entre compte", vous allez générer les deux écritures en une seule fois.</p>
			<p>Saisie de la première écriture depuis le compte Banque1 vers 580000 </p>
			' . Base::Site::util::generer_tableau('Journal de type "Banque1"', [
				[512100, 'Banque 1', 'Transfert entre compte', '', 'Montant'],
				[580000, 'Virement Interne', 'Transfert entre compte', 'Montant', ''],
			]) . '
			<p>Saisie de la deuxième écriture depuis 580000 vers le compte Banque2</p>
				' . Base::Site::util::generer_tableau('Journal de type "Banque2"', [
				[580000, 'Virement Interne', 'Transfert entre compte', '', 'Montant'],
				[512200, 'Banque 2', 'Transfert entre compte', 'Montant', ''],
			]) . '
		</details>

		';
	} else {
		$section[1] = '
		<p class="title1">Saisie rapide</p>
		<p>La saisie rapide simplifie la comptabilisation des écritures.
		<br><a href="parametres?achats"><strong>Paramètres =&gt; Mode paiement</a> détermine le journal et le compte de trésorerie qui seront utilisés.</strong>
		<br>Assurez-vous de bien renseigner un journal de type "Achats" et "Ventes" parmi les journaux disponibles (<a href="journal?configuration">Journaux =&gt; Modifier la liste</a>), car ils seront automatiquement utilisés lors de la saisie d\'une créance/dette et d\'un paiement comptant.
		<br><p>Lors de l\'importation de relevé bancaire en CSV ou OFX ou via OCR vous retrouverez :</p>
		<ul><li><strong>Recette</strong> pour compte financier (D5) vers compte de produit (C7).</li>
		<li><strong>Autres entrées d\'argent</strong> pour compte financier (D5) vers compte de tiers (C4).</li>
		<li><strong>Dépense</strong> pour compte financier (C5) vers compte de charge &nbsp;(D6).</li>
		<li><strong>Autres sorties d\'argent</strong> pour compte financier (C5) vers compte de tiers (D4).</li>
		<li><strong>Case à cocher Paiement comptant</strong> pour la création de deux écritures en une seule opération avec lettrage automatique, la facture et son réglement. Cette option est disponible pour Recette et Dépense</li>
		<li><strong>Transfert entre compte</strong> pour enregistrer les deux écritures de transfert passant par le compte d\'attente 580000 – Virement Interne grâce à une seule opération avec lettrage automatique.</li>
		</ul>
		<p>Voici les différents types de saisie disponibles.</p>
		<ul class="summary">
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_recette\')">Saisie de Type "Recette"</a></li>
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_depense\')">Saisie de Type "Dépense"</a></li>
		<li><a class="summary" href="javascript:void(0);" onclick="scrollToDetail(\'type_transfert\')">Saisie de Type "Transfert entre compte"</a></li>
		</ul>
		
		<hr class="mainPageTutoriel">
		
		<details id="type_recette" class="warningdoc" open=""><summary class="title1">Saisie de Type "Recette"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Recette => Permet d\'enregistrer la recette sur le compte financier (classe 5) et créditer le compte de produit (classe 7).</p>
			' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[512, 'Banque', 'Réglement Client Toto', 'Montant', ''],
				[706, 'Prestations de services', 'Réglement Client Toto', '', 'Montant'],
			]) . '
			<p class="classp">Recette Comptant => Permet d\'enregistrer deux écritures en une seule opération (lettrées automatiquement), la facture du client et son réglement.</p>
			<p>Saisie de la facture du client sur son compte 411 et crédit du compte de produit (classe 7).</p>
			' . Base::Site::util::generer_tableau('Journal de type "Ventes"', [
				[411, 'Client', 'Réglement Client Toto', 'Montant', ''],
				[706, 'Prestations de services', 'Réglement Client Toto', '', 'Montant'],
			]) . '
			<p>Saisie du règlement du client sur le compte financier (classe 5) et crédit de son compte client 411.</p>
				' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[411, 'Client', 'Réglement Client Toto', '', 'Montant'],
				[512, 'Banque', 'Réglement Client Toto', 'Montant', ''],
			]) . '
			<p class="classp">Facture client => Permet d\'enregistrer la facture du client sur son compte 411 et créditer le compte de produit (classe 7).</p>
			' . Base::Site::util::generer_tableau('Journal de type "Ventes"', [
				[411, 'Client', 'Réglement Client Toto', 'Montant', ''],
				[706, 'Prestations de services', 'Réglement Client Toto', '', 'Montant'],
			]) . '
			<p class="classp">Règlement client => Permet d\'enregistrer le règlement du client sur le compte financier (classe 5) et créditer son compte client 411.</p>
				' . Base::Site::util::generer_tableau('Journal de type "Banque"', [
				[411, 'Client', 'Réglement Client Toto', '', 'Montant'],
				[512, 'Banque', 'Réglement Client Toto', 'Montant', ''],
			]) . '
			<p class="classp">Autres entrées d\'argent => Permet d\'enregistrer une autre entrée d\'argent sur le compte financier (classe 5) et créditer un autre compte.</p>
			<p>Exemple: un apport d\'un associé</p>
				' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[455, 'Associé', 'Apport associé', '', 'Montant'],
				[512, 'Banque', 'Apport associé', 'Montant', ''],
			]) . '
		</details>
		
		<details id="type_depense" class="alert" open=""><summary class="title1">Saisie de Type "Dépense"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Dépense => Permet d\'enregistrer la dépense sur le compte financier (classe 5) et débiter le compte de charge (classe 6).</p>
			' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[512, 'Banque', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
				[626100, 'Frais postaux', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
			]) . '
			<p class="classp">Dépense Comptant => Permet d\'enregistrer deux écritures en une seule opération (lettrées automatiquement), la facture du fournisseur et son réglement.</p>
			<p>Saisie de la dette sur le compte fournisseur</p>
			' . Base::Site::util::generer_tableau('Journal de type "Achats"', [
				[411, 'Client', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
				[626100, 'Frais postaux', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
			]) . '
			<p>Saisie du règlement de la dette depuis la banque sur le compte fournisseur</p>
				' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[411, 'Client', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
				[512, 'Banque', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
			]) . '
			<p class="classp">Facture fournisseur => Permet d\'enregistrer la facture du fournisseur sur son compte 401 et débiter le compte de charge (classe 6).</p>
			' . Base::Site::util::generer_tableau('Journal de type "Achats"', [
				[411, 'Client', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
				[626100, 'Frais postaux', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
			]) . '
			<p class="classp">Règlement fournisseur => Permet d\'enregistrer le règlement de la facture sur le compte financier (classe 5) et débiter le compte fournisseur 401.</p>
			' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[411, 'Client', 'Réglement Fournisseur Leroy Merlin', 'Montant', ''],
				[512, 'Banque', 'Réglement Fournisseur Leroy Merlin', '', 'Montant'],
			]) . '
			<p class="classp">Autres sorties d\'argent => Permet d\'enregistrer une autre sortie d\'argent sur le compte financier (classe 5) et débiter un autre compte.</p>
			<p>Exemple: remboursement d\'un associé</p>
			' . Base::Site::util::generer_tableau('Journal du mode de paiement', [
				[455, 'Associé', 'Remboursement associé', 'Montant', ''],
				[512, 'Banque', 'Remboursement associé', '', 'Montant'],
			]) . '
		</details>
		
		<details id="type_transfert" class="alerte" open=""><summary class="title1">Saisie de Type "Transfert entre compte"</summary>
		<hr class="mainPageTutoriel">
			<p class="classp">Saisie d\'un transfert entre compte via deux écritures comptables :</p>
			<p>Pour virer de l’argent d’un compte bancaire à l’autre en comptabilité, vous devez impérativement passer par un compte d’attente "580000 – Virement Interne".
			<br>En utilisant "Transfert entre compte", vous allez générer les deux écritures en une seule fois.</p>
			<p>Saisie de la première écriture depuis le compte Banque1 vers 580000</p>
			' . Base::Site::util::generer_tableau('Journal de l\'établissement financier 1', [
				[512100, 'Banque 1', 'Transfert entre compte', '', 'Montant'],
				[580000, 'Virement Interne', 'Transfert entre compte', 'Montant', ''],
			]) . '
			<p>Saisie de la deuxième écriture depuis 580000 vers le compte Banque2</p>
				' . Base::Site::util::generer_tableau('Journal de l\'établissement financier 2', [
				[580000, 'Virement Interne', 'Transfert entre compte', '', 'Montant'],
				[512200, 'Banque 2', 'Transfert entre compte', 'Montant', ''],
			]) . '
		</details>

		';
	}
	
	#Génération mémo date
	$content .= generate_memo($r);

	
	#<img style='width:75%;min-width:800px;' src=\"/Compta/images/menu/ecriture5.png\" alt=\"ecriture5\"></li>
	#cat_1 premier pas
    $content .= "
    <section id='introduction' class='main-section'>
		<header class='header'><h3>Fonctionnement général</h3></header><hr class='hrperso'>
			<p>compta.libremen.com est un outil d\'enregistrement et de restitution d\'écritures comptables.</p>
			<p>Son utilisation suppose que l\'utilisateur possède les connaissances minimales d\'un aide-comptable.</p>
			<p>il existe une séparation physique entre les exercices. Le changement d'exercice se fait en cliquant en haut de la page sur le titre <a href='fiscal_year?fiscal_year'> ".$info_societe->[0]->{etablissement}." - Exercice ".$r->pnotes('session')->{fiscal_year}."</a>.
			L'utilisateur peut travailler sur plusieurs onglets à la fois mais toujours dans le même exercice. Si l'utilisateur souhaite travailler sur deux exercices différents en même temps, il doit utiliser deux navigateurs différents, un pour chaque exercice</p>
			<p>Le menu principal contenant cette documentation est disponible à tout moment via clic sur l'icône de la balance en haut à gauche.</p>
			<p><a href='' title='Retour vers Menu'><img height='50' width='64' src='/Compta/style/icons/logo.png' alt='Logo'></a></p>
	".$hidden[21]."
	".$hidden[20]."
	</section>
	
	<section id='journaux' class='main-section'>
			<header class='header'><h3>Journaux</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
			<hr class='mainPageTutoriel'>
			<ul class='summary'>
				<li><a class='summary' href='#journaux_1'>Fonctionnalités disponibles dans le menu \"Journaux\"</a></li>
				<li><a class='summary' href='#journaux_2'>Options de filtre</a></li>
				<li><a class='summary' href='#journaux_3'>Importation et exportation de la liste des journaux</a></li>
				<li><a class='summary' href='#journaux_4'>Clôture des journaux</a></li>
			</ul>
			<hr class='mainPageTutoriel'>
			
			   <div id='journaux_1'>
					<p class='title1'>Fonctionnalités disponibles dans le menu \"Journaux\"</p>
					<ul>
			<li><p><a href='journal'>Journaux</a> affiche le Journal Général, qui est constitué de l'ensemble des écritures des journaux auxiliaires.</p></li>
			<li><form action=/".$r->pnotes('session')->{racine}."/menu >Toutes les écritures sont inscrites dans les journaux auxiliaires, en utilisant le lien 'Nouvelle entrée' en haut à gauche de chaque journal
			(Accès rapide => " . $journal_entree . "
			<input type=submit style='width: 17ch;' class='btnform2 vert' value='Nouvelle Entrée'> )</form></li>
			<li><p><a href='journal?configuration'>Journaux -> Modifier la liste</a> offre la possibilité d'ajouter, modifier, importer, exporter, reconduire et supprimer des journaux, ainsi que de définir le type de journal. Cette dernière information est cruciale dans le cadre d'une comptabilité d'engagement, car elle permet de spécifier les journaux en tant que 'Achats' et 'Ventes'.</p></li>
			<li><p>Les journaux de type 'Achats' et 'Ventes' offrent une fonction d'enregistrement automatique des paiements dans le journal de votre choix, avec reprise des dates, des libellés et des montants de débit/crédit inversés.
			<br>Pour cela, cliquer dans l'écriture et utiliser le lien '--Choix Règlement--' du formulaire de saisie .</p></li>
			<li><p>Seuls les journaux OD, CLOTURE et A-NOUVEAUX sont obligatoires et non modifiables</p></li>
			<li><p><a href='journal?open_journal=Journal%20général&import=0'>Journaux -> Journal Général -> Importer des écritures</a> offre la possibilité d'importer des données depuis un fichier FEC ou CSV. Il permet également avant l'importation, de sauvegarder, créer les comptes manquants, créer les journaux manquants et supprimer les données non validées de l'exercice.</p></li>
			<li><a href='journal?configuration&reconduire=0'>Journaux -> Modifier la liste -> Reconduire les journaux de l'exercice précédent</a> permet de reconduire en début d'exercice la liste des journaux.</li>
			</ul>
				</div>
				
			<hr class='mainPageTutoriel'>
					
					<div id='journaux_2'>
					<p class='title1'>Options de filtre</p>
					<p>Voici les différents filtres de recherche :</p>
					<ul>
					<li><p><a href='journal'>Journaux => R</a> permet de réinitialiser les filtres de recherche (* <strong>R</strong> 01 02 03 04 ...).</p></li>
					<li><p><a href='journal?open_journal=Journal%20général&mois=0&equilibre=true'>Journaux -> check1</a> permet de filtrer les écritures lettrées mais non équilibrées.</p></li>
					<li><p><a href='journal?open_journal=Journal%20général&mois=0&nonlettre=true'>Journaux -> check2</a> permet de filtrer les écritures non lettrées des comptes de classe 4.</p></li>
					<li><p><a href='journal?open_journal=Journal%20général&mois=0&recurrent=true'>Journaux -> Récurrent</a> permet de filtrer les écritures servant à générer des écritures récurrentes.</p></li>
					</ul>
				</div>
				
				<hr class='mainPageTutoriel'>	
				
			<div id='journaux_3'>
				<p class='title1'>Importation et exportation de la liste des journaux</p>
				<p> <a href='journal?configuration'>Journaux -> Modifier la liste</a> permet d'importer, exporter et modifier la liste des journaux.</p>
				<p><strong>Caractéristiques du fichier :</strong></p>
				  <ul><li>Le fichier doit être encodé en UTF-8, avec ou sans en-tête.</li> 
				  <li>Il doit contenir au moins trois valeurs séparées par un \";\" (point-virgule).</li>
				  <li>Tous les champs précédés d'une étoile (*) ne peuvent pas être vides.</li>
				  <li>Le code journal ne peut comporter que deux caractères.</li>
				  <li>Voici les différents type de journaux disponibles : Achats/A-nouveaux/Clôture/OD/Trésorerie/Ventes.</li></ul>
				<div class='table'>
				  <div class='caption'>Exemple du format de fichier à utiliser</div>
				  <div class='row header'>
					<div class='cell' style='width: 30%'>Nom du champ</div>
					<div class='cell' style='width: 30%'>Type de données</div>
					<div class='cell' style='width: 30%'>Remarques</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'><strong>*journalcode</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Code journal sur 2 caractères.</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'><strong>*journallib</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé du journal</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'><strong>*journaltype</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Type de journal</div>
				  </div>
				  
				</div>
				
				<p><strong>Exemple de fichier :</strong></p>
				<p>
				journalcode;journallib;journaltype
				<br>AC;ACHATS;Achats
				<br>AN;A NOUVEAUX;A-nouveaux
				<br>BQ;BANQUE;Trésorerie
				<br>CA;CAISSE;Trésorerie
				<br>CL;CLOTURE;Clôture
				<br>OD;OD;OD
				<br>PY;PAYPAL;Trésorerie
				<br>VE;VENTES;Ventes
				</p>
        
			</div>
    
			<hr class='mainPageTutoriel'>
		
			<div id='journaux_4'>	
			<p class=title1>Clôture des journaux</p>
			<p>Via le menu <a href=export>Export => Clôtures => Clôtures annuelles</a>, vous pouvez procéder à la clôture de vos journaux comptables de deux manières :</p>
			<ul>
			  <li><strong>Clôture annuelle</strong> : Cette option permet de bloquer la saisie et la modification des écritures pour tous les journaux sur l'ensemble de l'exercice.</li>
			  <li><strong>Clôture mensuelle</strong> : Cette option permet de bloquer la saisie et la modification des écritures pour un mois spécifique uniquement.</li>
			</ul>
			<p>Pour archiver les écritures d’un mois clôturé, procédez comme suit :</p>
			<p>- Cliquez sur le <strong>numéro du mois</strong> dans la section Clôtures mensuelles.
			  <br>- Les écritures du mois sélectionné seront archivées et peuvent être téléchargées sous deux formats :
			  <ul>
				<li><strong>FEC</strong> : Format conforme à l’article A47 A-1 du livre des procédures fiscales.</li>
				<li><strong>Données</strong> : Fichier contenant toutes les informations enregistrées dans le logiciel pour le mois sélectionné.</li>
			  </ul>
			</p>
			</div>
			
			<hr class='mainPageTutoriel'>
			
	".$hidden[21]."
	".$hidden[20]."
	</section>
	
	<section id='comptes' class='main-section'>
			<header class='header'><h3>Comptes</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
			<hr class='mainPageTutoriel'>
			<ul class='summary'>
				<li><a class='summary' href='#Comptes_1'>Fonctionnalités disponibles dans le menu \"Comptes\"</a></li>
				<li><a class='summary' href='#Comptes_2'>Importation et exportation de la liste des comptes</a></li>
			</ul>
			<hr class='mainPageTutoriel'>
			
			   <div id='Comptes_1'>
					<p class='title1'>Fonctionnalités disponibles dans le menu \"Comptes\"</p>
					<ul>
						<li><p><a href='compte'>Comptes</a> affiche tous les comptes enregistrés pour l'exercice en cours.</p></li>
						<li><p><a href='compte?configuration'>Comptes -> Configuration</a> offre la possibilité d'ajouter, modifier, importer, exporter, reconduire et supprimer des comptes.
						 Il permet également de choisir un compte de contrepartie qui sera automatiquement utilisé lors de la sélection dudit compte dans les formulaires de saisie rapide et d'import de relevé.</p></li>
						<li><a href='compte?configuration&reconduire=0'>Comptes => Configuration => Reconduire</a> permet de reconduire en début d'année la liste des comptes.</li>
						<li><p><a href='compte?numero_compte=0'>Comptes -> Grand Livre V1</a> permet d'afficher le grand livre avec la possibilité de lettrer dynamiquement les comptes.</p></li>
						<li><p><a href='compte?grandlivre'>Comptes -> Grand Livre V2</a>  propose un format différent du grand livre avec la possibilité d'exporter en version PDF.</p></li>
						<li><p><a href='compte?reports=0'>Comptes -> Reports</a> permet de reporter les soldes des comptes de bilan au début d'un nouvel exercice et offre la possibilité de reconduire la liste des comptes et des journaux en sélectionnant les options correspondantes.</p></li>
						<li><p>En cliquant sur le nom d'un compte dans les sections Compte ou Grand Livre, vous pouvez consulter les soldes et les écritures des exercices précédents grâce aux liens \"Historique résumé\" et \"Historique détaillé\".</p></li>
						<li><p><a href='compte?cloture=0'>Comptes -> Clôture</a> permet de clôturer les comptes en fin d'exercice.</p></li>
					</ul>
				</div>
				
			<hr class='mainPageTutoriel'>
				
			<div id='Comptes_2'>
				<p class='title1'>Importation et exportation de la liste des comptes</p>
				<p> <a href='compte?configuration'>Comptes => Configuration</a> permet d'importer, exporter et modifier la liste des comptes.</p>
				<p><strong>Caractéristiques du fichier :</strong></p>
				  <ul><li>Le fichier doit être encodé en UTF-8, avec ou sans en-tête.</li> 
				  <li>Il doit contenir au moins deux valeurs séparées par un \";\" (point-virgule).</li>
				  <li>Tous les champs précédés d'une étoile (*) ne peuvent pas être vides.</li>
				   <li>Les comptes peuvent comporter autant de décimales que souhaité.</li></ul>
				<div class='table'>
				  <div class='caption'>Exemple du format de fichier à utiliser</div>
				  <div class='row header'>
					<div class='cell' style='width: 30%'>Nom du champ</div>
					<div class='cell' style='width: 30%'>Type de données</div>
					<div class='cell' style='width: 30%'>Remarques</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'><strong>*comptenum</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Numéro de compte</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'><strong>*comptelib</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé du compte</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'>contrepartie</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Compte de contrepartie</div>
				  </div>
				  <div class='row'>
					<div class='cell' style='width: 30%'>default_id_tva</div>
					<div class='cell' style='width: 30%'>Numérique</div>
					<div class='cell' style='width: 30%'>Taux de TVA</div>
				  </div>
				</div>
				
				<p><strong>Exemple de fichier :</strong></p>
				<p>
				comptenum;comptelib;contrepartie;default_id_tva
				<br>101000;Capital Social;
				<br>110000;Report à nouveau - solde créditeur;
				<br>119000;Report à nouveau - solde débiteur;
				<br>120000;Résultat de l'exercice - bénéfice;
				<br>129000;Résultat de l'exercice - perte;
				<br>401POS;LA POSTE;626000
				<br>708800;Autres produits d'activités annexes;;20
				</p>
        
			</div>
    
			<hr class='mainPageTutoriel'>
		".$hidden[21]."
		".$hidden[20]."
	</section>
	
	<section id='documents' class='main-section'>
			<header class='header'><h3>Documents</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
			
			<hr class=mainPageTutoriel>
		
				<ul class=summary>
				<li><a class=summary href='#Documents_1' >Gestion des documents</a></li>
				<li><a class=summary href='#Documents_2' >Actions Spécifiques sur un document</a></li>
				</ul>
		
			<hr class=mainPageTutoriel>
		
				<div id='Documents_1'>	
				<p class=title1>Gestion des documents</p>
				<ul>
				<li><p><a href='docs'>Documents</a> affiche tous les documents enregistrés sur l'exercice en cours.</p></li>
				<li><p><a href='docs?nouveau'>Documents => Ajouter</a> offre la possibilité d'ajouter un ou plusieurs documents, lesquels seront automatiquement placés dans la catégorie Temp (catégorie obligatoire et non modifiable).</p></li>
				<li><p><a href='docs?nouveau'>Documents -> Ajouter -> Configuration des règles automatiques</a> permet d'attribuer le nouveau document à une catégorie spécifique et un compte en fonction des mots présents dans le nom des fichiers.</p></li>
				<li><p><a href='docs?categorie'>Documents => Catégorie</a> offre la possibilité d'ajouter, modifier, supprimer les catégories de document.</p></li>
				<li><p><a href='docs?tag'>Documents -> #Tags</a> permet d'ajouter, de modifier et de supprimer des tags associés à des documents, offrant ainsi la possibilité de filtrer ces documents par tag.</p></li>
				</ul>
				</div>	
			
			<hr class=mainPageTutoriel>
			
				<div id='Documents_2'>	
				<p class=title1>Actions Spécifiques sur un document</p>
				<ul>
				<li><p><strong><a href='#ecriturescomptables_4'>Saisie rapide -></a></strong> permet d'ajouter rapidement des écritures depuis un document.<p>
				<li><p><strong>CSV/OFX/OCR</strong> permet d'importer rapidement des écritures depuis un document.<p></li>
				<li><p><strong>Historique des évènements</strong> permet d'afficher le suivi détaillé des actions liées au document.<p></li>
				<li><p><strong>Email</strong> permet d'envoyer un email avec le document en pièce jointe.<p></li>
				<li><p><strong>doc1 -></strong> Remplit automatiquement le champ Document 1 des formulaires avec le nom du document.</p></li>
				<li><p><strong>doc2 -></strong> Remplit automatiquement le champ Document 2 des formulaires avec le nom du document.</p></li>
				<li><p>Les documents cochés <strong>Multi</strong> sont disponibles pour les tous les exercices tant que <strong>Last exercice</strong> n'est pas renseigné</p></li>
				<li><p>Si un numéro de compte est spécifié (par exemple 512100), vous pouvez pointer les écritures liées à ce document et correspondant à ce compte. Cela permet de vérifier que le Total Pointé correspond correctement au total du relevé.</p></li>
				</ul>

				</div>	
			
			<hr class=mainPageTutoriel>

	".$hidden[21]."
	".$hidden[20]."
	</section>
	
	<section id='ecriturescomptables' class='main-section'>
		<header class='header'><h3>Ecritures Comptables</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
			
		<hr class=mainPageTutoriel>
		
		<ul class=summary>
		<li><a class=summary href='#ecriturescomptables_1' >Gestion des écritures</a></li>
		<li><a class=summary href='#ecriturescomptables_2' >Formulaire de saisie</a></li>
		<li><a class=summary href='#ecriturescomptables_3' >Raccourcis clavier</a></li>
		<li><a class=summary href='#ecriturescomptables_4' >Les écritures récurrentes</a></li>
		<li><a class=summary href='#ecriturescomptables_5' >Lettrage et Pointage</a></li>
		<li><a class=summary href='#ecriturescomptables_6' >Saisie rapide</a></li>
		<li><a class=summary href='#ecriturescomptables_7' >Validation des écritures</a></li>
		</ul>
		
		<hr class=mainPageTutoriel>
		
			<div id='ecriturescomptables_1'>	
			<p class=title1>Gestion des écritures</p>
			<ul>
			<li><p>Pour saisir une nouvelle écriture : <a href='journal'>Journaux</a> => Choisir un journal => Cliquer sur \"Nouvelle entrée\" </p>
			</li><li><p>Les écritures peuvent être déplacées d'un journal à un autre via le lien 'Déplacer' du formulaire de saisie</p>
			</li><li><p>Elles peuvent également être extournées et dupliquées via le lien 'Extourner' et 'Dupliquer' du même formulaire</p>
			</li><li><p><strong>Documents 1 est la pièce comptable obligatoire </strong>(la date de documents 1 est utilisée pour la génération du FEC).</p>
			</li><li><p>Documents 2 est une pièce complémentaire non utilisée pour la génération du FEC (exemple un relevé bancaire).
			</li>
			</ul>
			</div>	
			
		<hr class=mainPageTutoriel>
		
			<div id='ecriturescomptables_2'>	
			<p class=title1>Formulaire de saisie</p>
			<p>Le formulaire de saisie est accessible en cliquant sur une écriture à partir des différents modules disponibles tels que Journaux, Rechercher, Référence d'écritures dans un document et Grand livre.</p>
			<p><strong>Édition d'une entrée</strong></p>
			<p>Les fonctions visibles dans la bande jaune permettent d'enregistrer automatiquement un règlement pour les écritures de Type 'Achats' ou 'Ventes', de dupliquer l'écriture, de l'extourner, de la déplacer dans un journal différent, et de la supprimer</p>
			<p><strong>Compte de Tiers</strong></p>
			<p>S'affiche automatiquement pour les écritures contenant un compte de classe 4 et affiche toutes les écritures relatives à ce compte, offrant la possibilité de les lettrer.</p>
			<p><strong>Affichage des documents</strong>
			<p>Affiche les documents 1 et 2 définis dans l'écriture.</p>
			</div>
		
		<hr class=mainPageTutoriel>
		
		<div id='ecriturescomptables_3'>	
		<p class=title1>Raccourcis clavier</p>
		<p><strong>Date :</strong> il est possible de saisir par exemple \"0225\" (JJMM, sans les guillemets); la date sera automatiquement complétée avec l'année en cours et formatée pour obtenir 2020-02-25 ou 05/02/2020, suivant l'option d'affichage sélectionnée par l'utilisateur dans le menu 'Paramètres'</p>
		<p><strong>Compte :</strong> taper les premiers chiffres pour obtenir une fenêtre déroulante affichant les comptes disponibles. Seuls les comptes enregistrés dans le menu 'Comptes' pour l'exercice en cours sont acceptés</p>
		<p><strong>Pièce :</strong> le symbole '&rarr;' indique un calcul automatique du numéro; taper \"Espace\";</p>
		<p><strong>Libellé :</strong> le symbole '&rarr;' indique une recopie automatique de la ligne précédente; taper \"Espace\"</p>
		<p>Les cases au fond grisé reproduisent automatiquement la valeur de la ligne précédente</p>
		<p>Les lignes dont le débit et le crédit valent O (zéro) sont ignorées lors de la validation</p>
		<p>Les signes '+' et '-' sur les côtés du formulaire permettent respectivement d'ajouter et de retirer une ligne</p>
		<p>Pour la saisie, plusieurs formats et séparateurs sont acceptés : 2020-02-25 ou 25/02/2020 ou 25#02#2020 ou 2020 02 25. <br>
		L'année doit être écrite sur 4 chiffres</p>
		</div>
	
		<hr class=mainPageTutoriel>	
		
			<div id='ecriturescomptables_4'>	
			<p class=title1>Les écritures récurrentes</p>
			<ul>
			<li><p>Pour qu'un écriture soit définie comme écriture récurrente cocher la case à droite et valider<p>		
			<img style='width:75%;min-width:800px;' src=\"/Compta/images/menu/ecriture2.png\" alt=\"ecriture2\">
			</li><li><p>Pour lister les écritures servant à générer les écritures récurrentes => <a href='journal?open_journal=Journal%20général&mois=0&recurrent=true'>Journaux => Journal Général => Récurrent</a></p>
			</li>
			</li><li><p>Pour générer les écritures récurrentes => <a href='menu?&amp;menu03=1'>Menu => Ecritures récurrentes</a>
			</li><li>Les écritures générées sont en attente de validation. Cliquer sur une écriture pour la modifier et la valider ou sur \"Valider toutes les écritures\" pour toutes les valider en même temps.</p>
			</li>
			</ul>
			</div>
			
		<hr class=mainPageTutoriel>		
			
			<div id='ecriturescomptables_5'>	
			<p class=title1>Lettrage et Pointage</p>
			<p>Tous les comptes peuvent être pointés, lettrés et rapprochés</p> 
			<ul>
			<li><p>Pointage est disponible depuis le module Documents si un compte est sélectionné.</p>
			</li><li><p>Lettrage est disponible depuis les écritures comptables pour les comptes de classe 4.</p>
			</li><li><p>La numérotation automatique du lettrage fonctionne par journal sous la forme : VE2022-01_01 avec CODEJOURNALANNEE-MOIS_NUMERO </p>
			</li><li><p>Lettrage et Pointage sont également disponible pour toutes les écritures sous <a href='compte?numero_compte=0'>Comptes => Grand Livre</a>.</p>
			</li>
			</ul>
			</div>	
		
		<hr class=mainPageTutoriel>	
		
			<div id='ecriturescomptables_6'>
			
			".$section[1]."
			
			</div>
			
		<hr class=mainPageTutoriel>
		
			<div id='ecriturescomptables_7'>	
			<p class=title1>Validation des écritures</p>
			<p>Via le menu <a href=export>Export => Validation des écritures</a>, vous pouvez valider les écritures comptables. La validation des écritures a pour objectif le blocage des écritures. Voici les actions effectuées lors de la validation :</p>
			<ul>
			<li>Un <strong>numéro d’ordre</strong> est attribué automatiquement aux écritures validées.</li>
			<li>Un <strong>numéro de pièce automatique</strong> est affecté si celui-ci n’est pas déjà présent.</li>
			<li>La <strong>date de validation</strong> correspond à la date du jour où la validation est effectuée.</li>
			</ul>
			<p><strong>Important :</strong> Une fois validées, les écritures ne peuvent plus être corrigées. Cependant, vous pouvez toujours ajouter de nouvelles écritures pour la même période.</p>
			</div>
			
		<hr class=mainPageTutoriel>	
		
	".$hidden[21]."
	".$hidden[20]."
	</section>
                
    </div>
            
	<section id='parametres' class='main-section'>
		<header class='header'><h3>Paramètres</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		
		<hr class=mainPageTutoriel>
		
			<ul class=summary>
			<li><a class=summary href='#parametres_1' >Fiche sociétés</a></li>
			<li><a class=summary href='#parametres_2' >Utilisateurs</a></li>
			<li><a class=summary href='#parametres_3' >Sauvegarde & restauration</a></li>
			<li><a class=summary href='#parametres_4' >Mode Paiement</a></li>
			<li><a class=summary href='#parametres_5' >Email</a></li>
			<li><a class=summary href='#parametres_6' >Logs</a></li>
			</ul>
		
		<hr class=mainPageTutoriel>
		
			<div id='parametres_1'>	
			<p class=title1>Fiche sociétés</p>
			<p>Le module <a href='parametres?societes'>Fiche sociétés</a> permet de modifier les informations de la société ou de créer une nouvelle société.</p>
			<ul>
			<li><p>Lors de la <a href='parametres?societe=0&modification_societe=1'>modification</a> il est possible de définir les dates du premier exercice fiscal, le type de comptabilité (engagement ou trésorerie) et le régime de TVA</p></li>
			<li><p>Il existe trois régimes de TVA : normal, simplifié ou franchise en base et deux options de calcul de la TVA due : débits ou encaissements; voir le chapitre <a href=\"index.html#ca3\">Déclaration de TVA (formulaire CA3)</a>; la période de calcul peut être mensuelle ou trimestrielle</p></li>
			<li><p>L'option 'Journal de TVA' permet de sélectionner le journal d'enregistrement des écritures résultant du calcul de la TVA due</p></li>
			</ul>
			</div>	
			
		<hr class=mainPageTutoriel>
		
			<div id='parametres_2'>	
			<p class=title1>Utilisateurs</p>
			<p>Le module <a href='parametres?utilisateurs'>Utilisateurs</a> permet de modifier les paramétres d'un utilisateur ou d'en créer un nouveau.</p>
			<ul>
			<li><p><strong>Société de rattachement</strong> permet de définir la société de rattachement.</p></li>
			<li><p><strong>Activer le mode debug log</strong> permet d'ajouter davantage de logs à des fins de débogage.</p></li>
			<li><p><strong>Activer le mode dump</strong> permet de générer des dumps de résultats pour le débogage.</p></li>
			<li><p><strong>Affichage des dates </strong> permet de régler le format d'affichage des dates ( AAAA-MM-JJ ou JJ/MM/AAAA).
			<li><p>L'utilisateur superadmin est le seul utilisateur pouvant accéder aux paramétres de toutes les sociétés</p></li>
			</ul>
			</div>	
			
		<hr class=mainPageTutoriel>
		
			<div id='parametres_3'>	
			<p class=title1>Sauvegarde & restauration</p>
			<p>L'outil de <a href='parametres?sauvegarde'>Sauvegarde & restauration</a> simplifie le processus de sauvegarde et de restauration de la base de données ainsi que de l'application, y compris les documents.</p>

            <p><strong>Sauvegarde & restauration de la Base de Données</strong></p>
            <ul>
                <li>Lancer une Sauvegarde : permet d'effectuer une sauvegarde complète de la base de données.</li>
                <li>Restaurer la Sauvegarde : permet de restaurer la base de données.</li>
            </ul>

            <p><strong>Sauvegarde & restauration de l'Application (y compris les Documents)</strong></p>
            <ul>
                <li>Lancer une Sauvegarde : permet d'effectuer une sauvegarde complète de l'application, incluant les documents.</li>
                <li>Restaurer la Sauvegarde : permet de restaurer l'application avec la possiblité de supprimer toutes les données avant restauration et également la possibilité de ne pas écraser les fichiers existants plus récents ou de même date</li>
            </ul>
            <p><strong>Ajouter un fichier</strong> : permet de charger un fichier de sauvegarde préalablement créé.</p>
		</div>
			
		<hr class=mainPageTutoriel>
		
			<div id='parametres_4'>	
			<p class=title1>Mode Paiement</p>
			<p><a href='parametres?achats'>Mode Paiement</a> permet de configurer les modes de paiement des achats. Cette configuration est essentielle, car elle sera automatiquement utilisée lors de la saisie rapide des écritures, de l'importation de fichiers CSV/OFX/OCR, ou du choix du règlement, en associant automatiquement le journal et le compte correspondant.</p>
			</div>	
			
		<hr class=mainPageTutoriel>

		<div id='parametres_5'>    
			<p class=title1>Gestion des paramètres Email</p>
			<p><a href='parametres?email'>Gestion des paramètres Email</a> permet de configurer divers aspects liés à l'envoi d'emails, y compris la configuration SMTP, les règles automatiques, et la gestion des modèles d'emails.</p>

			<p><strong>Configuration SMTP</strong></p>
			<ul>
				<li>Configurer SMTP : permet de définir les paramètres nécessaires pour l'envoi d'emails via un serveur SMTP externe.</li>
			</ul>

			<p><strong>Configuration des règles automatiques</strong></p>
			<ul>
				<li><strong>Définir les mots-clés</strong> : Permet de programmer des mots-clés qui seront automatiquement recherchés dans le nom du document. Si un mot-clé est trouvé, un modèle d'email correspondant est appliqué automatiquement.</li>
				<li><strong>Variables dynamiques</strong> : Lors de l'application d'un modèle d'email, il est possible d'utiliser les variables suivantes, provenant des informations du module Gestion immobilière, disponibles sous 'valeur dynamique' de la barre d'outils d'envoi d'email :
					<ul>
						<li><strong>Nom du bien</strong> : Le nom du bien ou du document lié à l'email.</li>
						<li><strong>Mois (format MM)</strong> : Le mois du document au format deux chiffres (MM).</li>
						<li><strong>Année (format AAA)</strong> : L'année du document au format quatre chiffres (AAAA).</li>
						<li><strong>Mois en toutes lettres</strong> : Le mois du document écrit en toutes lettres (par exemple : 'Janvier', 'Février').</li>
					</ul>
				</li>
			</ul>

			<p><strong>Formulaire d'envoi d'email</strong></p>
			<ul>
				<li>Enregistrer un email dans un modèle : permet de sauvegarder l'email envoyé dans un modèle, afin de le réutiliser ultérieurement.</li>
			</ul>
		</div>

			
		<hr class=mainPageTutoriel>
		
			<div id='parametres_6'>	
			<p class=title1>Logs</p>
			<ul>
			<li><p><a href='parametres?logs'>Logs</a> permet d'afficher les logs de l'application</p>
			</li>
			</ul>
			</div>	
			
		<hr class=mainPageTutoriel>
		
	".$hidden[21]."
	".$hidden[20]."
	</section>	
	
	<section id='tva' class='main-section'>
	<header class='header'><h3>Déclaration de TVA</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
		<hr class=mainPageTutoriel>
		
			<ul class=summary>
			<li><a class=summary href='#tva_1' >Option 'TVA sur encaissements'</a></li>
			<li><a class=summary href='#tva_2' >Option 'TVA sur débits'</a></li>
			<li><a class=summary href='#tva_3' >Calcul du formulaire CA3</a></li>
			</ul>
		
		<hr class=mainPageTutoriel>
		
			<p>Le calcul de la TVA exigible se base sur les taux de TVA enregistrés dans les comptes de classe 7 <a href='compte?configuration'>(Comptes -> Configuration)</a>. Il peut ensuite être effectué sur les débits ou sur les encaissements, selon l'option choisie dans <a href='parametres?societe&modification_societe=1'>Paramètres -> Fiches sociétés -> TVA</a>.</p>

			<div id='tva_1'>	
			<p class=title1>Option 'TVA sur encaissements'</p>
			<p>La TVA collectée est calculée sur la période à partir des comptes 7 qui sont lettrés et non pointés.</p>
			<p>Pour une déclaration conforme, il est nécessaire de :</p>
			<ul>
			<li>Lettrer les comptes clients après encaissement de la facture. Le lettrage doit être enregistré dans les comptes 7 concernés.</li>
			<li><a href='tva'>Calculer la TVA</a> due et valider l'opération.</li>
			<li>Pointer les écritures des comptes de classe 7 précédemment lettrées pour qu'elles n'apparaissent plus dans les déclarations suivantes.</li>
			</ul>
			</div>	
		<hr class=mainPageTutoriel>
		<div id='tva_2'>	
			<p class=title1>Option 'TVA sur débits'</p>
			<p>La TVA due est calculée sur l'ensemble des factures enregistrées dans la période considérée.</p>
			<p>Il est possible d'enregistrer des ventes de services (TVA exigible à l'encaissement) en utilisant des comptes d'attente :</p>
			<ul>
			<li>Créer un ou plusieurs comptes 418 ('Ventes non taxables'), un compte 44578 ('TVA collectée non exigible'), et des comptes 7 paramétrés à 0% de TVA, terminés par '*'.</li>
			<li>Enregistrer les ventes dans ces comptes d'attente.</li>
			<li>Lors du règlement, extourner l'écriture initiale et enregistrer la vente dans les comptes 411, 4457, et les comptes de classe 7 normaux à la date du règlement.</li>
			<li><a href='tva'>Calculer la TVA</a> due et valider l'opération.</li>
			</ul>
			</div>	
		<hr class=mainPageTutoriel>	
		<div id='tva_3'>	
			<p class=title1>Calcul du formulaire CA3</p>
			<ul>
				<li><a href='tva'>calculer le formulaire CA3 (déclaration de TVA)</a> , sélectionnez la période à déclarer, puis cliquez sur 'Valider'. Le logiciel affiche une réplique partielle du formulaire 3310CA3, visible sur impots.gouv.fr, avec un calcul des champs principaux à renseigner.</li>
				<li>Les périodes de déclaration concernent la période en cours ainsi que celle de l'année précédente. Il est important de noter que le formulaire de calcul de TVA ne peut pas être utilisé pour des dates antérieures de plus de 12 mois, mais des écritures antérieures peuvent être enregistrées manuellement.</li>
				<li>En cliquant sur 'Valider' en bas du formulaire, les écritures nécessaires sont affichées dans le formulaire de saisie d'écriture et peuvent être modifiées si besoin.</li>
			</ul>
		</div>
		<hr class=mainPageTutoriel>	
	".$hidden[21]."
	".$hidden[20]."
	</section>  
    ";
    
	
	 return $content ;
} #sub articles_bar1 

#/*—————————————— articles_bar2 => Courant ——————————————*/
sub articles_bar2 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my @hidden = ('0') x 40;

	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 

#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";
	
	#cat_2 Courant - affectation du résultat  
	my $content .= "
	<section id='affectation' class='main-section'>
    	<header class='header'><h3>Affectation du résultat</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#affectation_1' >Comptabilisation de l'affectation du résultat dans une société</a></li>
		<li><a class=summary href='#affectation_2' >Comptabilisation de l'affectation du résultat dans une entreprise individuelle</a></li>
		<li><a class=summary href='#affectation_3' >Comptabilisation de l'affectation du résultat dans une association</a></li>
		</ul>
		
    <hr class=mainPageTutoriel>
			
	<p>Lorsque vous clôturez votre exercice, les comptes de charges et de produits sont soldés et le montant du résultat est enregistré dans le compte « résultat » (n°120 si c’est un bénéfice, 129 si c’est une perte). Cette affectation est automatique dans la procédure de clôture.</p>
    <p>Une deuxième écriture devra être passée, au cours de l’exercice suivant, après la tenue de l’assemblée générale annuelle, pour affecter ce résultat.</p>
	<p>L'affectation dépend de votre structure juridique et des décisions prises.</p>
	
	<hr class=mainPageTutoriel>

	
    <details id=affectation_1 class=warningdoc open><summary class=title1>Comptabilisation de l'affectation du résultat dans une société</summary>
	<hr class=mainPageTutoriel>
	
	<p>
	Dans une société, le résultat est affecté en fonction de la décision de l'assemblée générale prise au plus tard dans les 6 mois de la fin de l'exercice. Si le résultat est une perte, il est généralement affecté au compte N° 119... \"report à nouveau (solde débiteur)\". Si le résultat est un bénéfice, il peut être affecté en :
	</p>
			
<ul><li><h4>Report à nouveau (solde créditeur) : N° 110...</h4></li></ul>
	
	<p class=tab1>
	Le report à nouveau permet aux associés ou actionnaires de décider de laisser tout ou partie des bénéfices en report à nouveau, ce qui signifie que le montant reste en instance d'affectation jusqu'à la prochaine assemblée. Un report à nouveau créditeur est donc constaté, il pourra être distribué en dividendes, apurer les déficits antérieurs ou postérieurs, affecté en réserves, augmenter le capital.
	</p>

	<ul><li><h4>Réserves : N° 106...</h4></li></ul>
	<p class=tab1>	Une partie du bénéfice doit être obligatoirement affecté à la \"Réserve légale\", compte N° 106100 (5 % du bénéfice jusqu'à ce que la réserve atteigne 10 % du capital).
	<br>Les autres réserves 1068 sont des sommes mises à la disposition de la société qui en principe ne peuvent pas être touchées par les associés. Elles permettent de valoriser les capitaux propres.
	</p>

	<ul><li><h4>Associés, Dividendes à Payer : N° 457...</h4></li></ul>
	<p class=tab1>Le compte 457 Associés - dividende à payer est un compte temporaire, l'inscription ne vaut pas paiement et n'entraîne pas l'exigibilité des retenues à la source ( Le paiement des dividendes devra s’effectuer dans les 9 mois suivant la clôture de l’exercice et permettra de solder le compte 457)</p>

	<p>
	Généralement les bénéfices sont comptabilisés en report à nouveau en début d'activité afin que ceux-ci épongent d'éventuels déficits. Une fois que le report à nouveau est assez conséquent, il peut être utile de doter les autres réserves. Le cas échéant il vous reste la possibilité de les distribuer sous forme de dividendes.
Il est toujours possible de distribuer les autres réserves en dividendes (sauf si vos statuts l'en empêche) ou d'imputer des déficits dessus mais ce n'est par définition pas le but des autres réserves.
	</p>
	<p>En cas de déficits ultérieurs, au niveau de la présentation du bilan vous pouvez décider de :
<br>- laisser les autres réserves et comptabiliser un report à nouveau débiteur
<br>- diminuer les autres réserves du montant du déficit
<br>Si vous optez pour la première option, les bénéfices futurs devront être utilisés en priorité pour apurer le report à nouveau débiteur avant d'envisager une distribution de dividendes ou doter de nouveau les autres réserves.

Deuxième chose, il faudra surveiller également que vos capitaux propres ne soient pas inférieurs à la moitié du capital social.</p>

	
	<hr class=mainPageTutoriel>
	<p class=classp>Cas d'un bénéfice avec RAN N-1 bénéficaire</p>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD / date de l'assemblée générale</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>110</div>
		  <div class='cell' data-title='Intitulé'>Report à nouveau N-1 (créditeur)</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>120</div>
		  <div class='cell' data-title='Intitulé'>Résultat de l'exercice - bénéfice</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>1061</div>
		  <div class='cell' data-title='Intitulé'>Réserve légale</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>limite 10% du capital</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>1063</div>
		  <div class='cell' data-title='Intitulé'>Réserves statuaires</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>1068</div>
		  <div class='cell' data-title='Intitulé'>Autres réserves</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>110</div>
		  <div class='cell' data-title='Intitulé'>Report à nouveau - solde créditeur</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>119</div>
		  <div class='cell' data-title='Intitulé'>Report à nouveau - solde débiteur</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>457</div>
		  <div class='cell' data-title='Intitulé'>Associés - dividende à payer</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	<p class=classp>Cas d'un bénéfice avec RAN N-1 déficitaire</p>
	
	<p >Exemple : Affectation du bénéfice de 1500 € pour solder le RAN N-1 débiteur de 1000€ , 100€ pour la réserve légale, 100€ en autres réserves et dividendes à payer pour le solde </p>
	
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD / date de l'assemblée générale</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>120</div>
		  <div class='cell' data-title='Intitulé'>Résultat de l'exercice - bénéfice</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>1500</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>119</div>
		  <div class='cell' data-title='Intitulé'>Report à nouveau - solde débiteur</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>1000</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>1061</div>
		  <div class='cell' data-title='Intitulé'>Réserve légale</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>100</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>1068</div>
		  <div class='cell' data-title='Intitulé'>Autres réserves</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>100</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>457</div>
		  <div class='cell' data-title='Intitulé'>Associés - dividende à payer</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>300</div>
		</div>
	</div></div>
	<hr class=mainPageTutoriel>
	
	<p class=classp>Cas d'une perte</p>
	
	<p>Lorsque le résultat est une perte, il est très souvent affecté dans le compte « report à nouveau » dans l’attente de bénéfices futurs qui viendront le compenser.
			</p>
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD / date de l'assemblée générale</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>129</div>
		  <div class='cell' data-title='Intitulé'> Résultat de l'exercice - pertes</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>1000</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>119</div>
		  <div class='cell' data-title='Intitulé'>Report à nouveau - solde débiteur</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>1000</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>

		
	</div></div>
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=affectation_2 class=alert open><summary class=title1>Comptabilisation de l'affectation du résultat dans une entreprise individuelle</summary>
	<hr class=mainPageTutoriel>
	
	<p>
	Dans une entreprise individuelle, le résultat est généralement affecté dans le \"compte de l'exploitant\" N° 10800000, le 1er jour du nouvel exercice.
	</p>
	<hr class=mainPageTutoriel>
	<p class=classp>Cas d'un bénéfice</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD / date de l'assemblée générale</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>120</div>
		  <div class='cell' data-title='Intitulé'>Résultat de l'exercice - bénéfice</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>1500</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>101</div>
		  <div class='cell' data-title='Intitulé'>Capital individuelle</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat/div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>1500</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	<p class=classp>Cas d'un déficit</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD / date de l'assemblée générale</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>129</div>
		  <div class='cell' data-title='Intitulé'>Résultat de l'exercice - perte</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>1500</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>101</div>
		  <div class='cell' data-title='Intitulé'>Capital individuelle</div>
		  <div class='cell' data-title='Libellé'>Affectation du résultat</div>
		  <div class='cell' data-title='Débit'>1500</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	</details>
	
	<details id=affectation_3 class=info open><summary class=title1>Comptabilisation de l'affectation du résultat dans une association</summary>
	<hr class=mainPageTutoriel>
	
	<p>
	Dans une association, la distribution de dividendes est impossible. Le Résultat vient donc augmenter ou diminuer le \"report à nouveau\", les \"réserves\" ou le \"fonds associatif\" (compte N° 10200000).
	</p>
		
	<hr class=mainPageTutoriel>
	
	</details>

	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	";
	
	
	#cat_2 Courant Section comptes courants associés
	$content .= "
	<section id='cca' class='main-section'>
		<header class='header'><h3>Comptes Courants Associés</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#cca_1' >Comptabilisation des intérêts des comptes courants associés</a></li>
		<li><a class=summary href='#cca_2' >Remboursement d'un compte courant d'associé</a></li>
		</ul>
		<hr class=mainPageTutoriel>

    <details id=cca_1 class=warningdoc open><summary class=title1>Comptabilisation des intérêts des comptes courants associés</summary>

	<hr class=mainPageTutoriel>
	
	<p>Lors du versement des intérêts des comptes courants associés</p> 
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>455</div>
		  <div class='cell' data-title='Intitulé'>Associé Compte courant</div>
		  <div class='cell' data-title='Libellé'>INTERET CCA 202*</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant net (60€)</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>4425</div>
		  <div class='cell' data-title='Intitulé'>État – Impôts et taxes</div>
		  <div class='cell' data-title='Libellé'>INTERET CCA 202*</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Part impôts (30€)</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>6615</div>
		  <div class='cell' data-title='Intitulé'>Intérêt des comptes courants</div>
		  <div class='cell' data-title='Libellé'>INTERET CCA 202*</div>
		  <div class='cell' data-title='Débit'>Montant brut des intérêts (90€)</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>
	
	<p>Par la suite, lorsque l’état prélève le montant</p> 
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de l'établissement financier</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>51</div>
		  <div class='cell' data-title='Intitulé'>Etablissement financier</div>
		  <div class='cell' data-title='Libellé'>Prélevement SIE</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Part impôts (30€)</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>4425</div>
		  <div class='cell' data-title='Intitulé'>État – Impôts et taxes</div>
		  <div class='cell' data-title='Libellé'>Prélevement SIE</div>
		  <div class='cell' data-title='Débit'>Part impôts (30€)</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>
	<hr class=mainPageTutoriel>
	</details>
	
	
	<details id=cca_2 class=alerte open><summary class=title1>Remboursement d'un compte courant d'associé</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de l'établissement financier</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>51</div>
		  <div class='cell' data-title='Intitulé'>Etablissement financier</div>
		  <div class='cell' data-title='Libellé'>virement cca du</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
				<div class='row'>
		  <div class='cell' data-title='Comptes'>455</div>
		  <div class='cell' data-title='Intitulé'>Associé Compte courant</div>
		  <div class='cell' data-title='Libellé'>virement cca du </div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	";
	
	#cat_2 Courant Section Créances douteuses ou irrécouvrables
	$content .= "
	<section id='creances' class='main-section'>
		<header class='header'><h3>Les Créances</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#creances_1' >Créances douteuses et litigieuses</a></li>
		<li><a class=summary href='#creances_2' >Créances irrécouvrables</a></li>
		</ul>
		<hr class=mainPageTutoriel>

    <details id=creances_1 class=warningdoc open><summary class=title1>Créances douteuses et litigieuses</summary>

	<hr class=mainPageTutoriel>
	
	<p>Les créances deviennent « douteuses » lorsque les clients rencontrent des difficultés de trésorerie et ne sont pas en mesure de régler leurs dettes.</p>
 
	<p>En fin d’exercice, les créances impayées nécessitent donc la mise en place de provisions pour dépréciation de créances clients. </p>
	
	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=transfert_client_douteux'>1) Transférer la créance dans un compte 416 « clients douteux »</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>416</div>
		  <div class='cell' data-title='Intitulé'>Clients douteux ou litigieux</div>
		  <div class='cell' data-title='Libellé'>Constatation créance douteuse Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Clients</div>
		  <div class='cell' data-title='Libellé'>Constatation créance douteuse Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>

	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=depreciation'>2) Ajouter une écriture de dépréciation afin d’anticiper une perte probable.</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>68174</div>
		  <div class='cell' data-title='Intitulé'>Dotations aux provisions pour dépréciation des créances</div>
		  <div class='cell' data-title='Libellé'>Dépréciation de la créance de Mr X</div>
		  <div class='cell' data-title='Débit'>% du Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>491</div>
		  <div class='cell' data-title='Intitulé'>Provisions pour dépréciation des comptes de clients</div>
		  <div class='cell' data-title='Libellé'>Dépréciation de la créance de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>% du Montant Total</div>
		</div>
	</div></div>
	
	<p>Chaque année, l’entreprise va devoir ajuster le montant de la provision via ajout,annulation ou réduction de la dépréciation. </p>

	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=reprise_depreciation'>3) Annulation ou réduction de la dépréciation.</a></p>
	
	<p>Si le client règle finalement une créance douteuse ou litigieuse, il faut annuler la dépréciation :</p>
	
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>491</div>
		  <div class='cell' data-title='Intitulé'>Provisions pour dépréciation des comptes de clients</div>
		  <div class='cell' data-title='Libellé'>Annulation de la dépréciation Mr X</div>
		  <div class='cell' data-title='Débit'>Montant de la dépréciation</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>78174</div>
		  <div class='cell' data-title='Intitulé'>Reprises sur dépréciation des créances</div>
		  <div class='cell' data-title='Libellé'>Annulation de la dépréciation Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant de la dépréciation</div>
		</div>
	</div></div>
	
	<p>Puis constater le règlement de cette créance</p>
	
	<div class=wrappertable>
		<div class=table>
			<div class=caption>Journal de banque</div>
			<div class=row >
				<div class=cell>Comptes</div>
				<div class=cell>Intitulé</div>
				<div class=cell>Libellé</div>
				<div class=cell>Débit</div>
				<div class=cell>Crédit</div>
			</div>
			<div class=row>
				<div class=cell data-title='Comptes'>512</div>
				<div class=cell data-title='Intitulé'>Banque</div>
				<div class=cell data-title='Libellé'>Règlement de la créance de Mr X</div>
				<div class=cell data-title='Débit'>Montant TTC de la créance</div>
				<div class=cell data-title='Crédit'></div>
			</div>
			<div class=row>
				<div class=cell data-title='Comptes'>416</div>
				<div class=cell data-title='Intitulé'>Clients douteux ou litigieux</div>
				<div class=cell data-title='Libellé'>Règlement de la créance de Mr X</div>
				<div class=cell data-title='Débit'></div>
				<div class=cell data-title='Crédit'>Montant TTC de la créance</div>
			</div>
		</div>
	</div>

	
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=creances_2 class=alerte open><summary class=title1>Créances irrécouvrables</summary>

	<hr class=mainPageTutoriel>
	
	<p>Lorsque la créance est définitivement perdue (en cas de disparition du débiteur par exemple), elle devient irrécouvrable.
	
	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=reprise_depreciation'>Si la créance avait fait l’objet d’une dépréciation, il convient de la reprendre :</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>491</div>
		  <div class='cell' data-title='Intitulé'>Provisions pour dépréciation des comptes de clients</div>
		  <div class='cell' data-title='Libellé'>Reprise de la dépréciation de la créance de Mr X</div>
		  <div class='cell' data-title='Débit'>% du Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>78174</div>
		  <div class='cell' data-title='Intitulé'>Reprises sur dépréciation des créances</div>
		  <div class='cell' data-title='Libellé'>Reprise de la dépréciation de la créance de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>% du Montant Total</div>
		</div>
	</div></div>
	
	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=creance_irrecouvrable'>La créance est considérée comme définitivement irrécouvrable :</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>654</div>
		  <div class='cell' data-title='Intitulé'>Pertes sur créances irrécouvrables</div>
		  <div class='cell' data-title='Libellé'>Pertes sur créances irrécouvrables</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>416</div>
		  <div class='cell' data-title='Intitulé'>Clients douteux ou litigieux</div>
		  <div class='cell' data-title='Libellé'>Pertes sur créances irrécouvrables</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
	</div></div>
	
	<p>Attention : le caractère irrécouvrable de la créance doit être prouvé.</p>

	
	
	<hr class=mainPageTutoriel>
	
	</details>
	
	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	";
	
	#cat_2 Courant section ecarts de reglement DEBUT
	$content .= "
	<section id='ecarts' class='main-section'>
	<header class='header'><h3>Ecarts de règlement</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#ecarts_1' >Ecarts de règlement positifs</a></li>
		<li><a class=summary href='#ecarts_2' >Ecarts de règlement négatifs</a></li>
		</ul>
		<hr class=mainPageTutoriel>

    <details id=ecarts_1 class=warningdoc open><summary class=title1>Ecarts de règlement positifs</summary>

	<hr class=mainPageTutoriel>
	<p>
	La différence de règlement, lorsqu’elle est en faveur de l’entreprise, est dite positive. Il pourra s’agir des cas suivants :
	<p> une entreprise reçoit sur son compte bancaire une somme plus importante de la part de son client</p>	
	<p> une entreprise paie à son fournisseur un montant moindre que celui figurant sur la facture</p>	
	<p> une entreprise s’acquitte de ses cotisations sociales pour une somme légèrement inférieure à celle figurant dans ses comptes (de
l’ordre de quelques centimes).</p>	
	</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>401/411</div>
		  <div class='cell' data-title='Intitulé'>Fournisseurs/Clients</div>
		  <div class='cell' data-title='Libellé'>écart de réglement</div>
		  <div class='cell' data-title='Débit'>écart</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>758</div>
		  <div class='cell' data-title='Intitulé'>Produits divers gestion courante</div>
		  <div class='cell' data-title='Libellé'>écart de réglement</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>écart</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=ecarts_2 class=alerte open><summary class=title1>Ecarts de règlement négatifs</summary>

	<hr class=mainPageTutoriel>
	<p>
	A l’inverse, lorsque les différences de règlement sont en la défaveur de l’entreprise, ils sont négatifs. Il s’agit principalement des cas
suivants :
<p>une entreprise perçoit de la part de son client une somme moindre que celle figurant sur la facture de vente,</p>
<p>une entreprise règle une somme plus importante à son fournisseur que celui figurant sur la facture d’achat,</p>
<p>une entreprise s’acquitte de ses cotisations sociales pour une somme légèrement supérieure à celle figurant dans ses comptes.</p>
	</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>658</div>
		  <div class='cell' data-title='Intitulé'>Fournisseur</div>
		  <div class='cell' data-title='Libellé'>écart de réglement</div>
		  <div class='cell' data-title='Débit'>écart</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>401/411</div>
		  <div class='cell' data-title='Intitulé'>Fournisseurs/Clients</div>
		  <div class='cell' data-title='Libellé'>écart de réglement</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>écart</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	

	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>

	";	#cat_2 Courant section ecarts de reglement FIN
	
	
	#cat_2 Courant section Ecritures Immobilières Début
	$content .= "
	<section id='immobiliere' class='main-section'>
	<header class='header'><h3>Ecritures Immobilières</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#immobiliere_1' >Comptabilisation du dépôt de garantie</a></li>
		<li><a class=summary href='#immobiliere_2' >Remboursement d’une assurance suite à un sinistre</a></li>
		</ul>
		<hr class=mainPageTutoriel>

    <details id=immobiliere_1 class=warningdoc open><summary class=title1>Comptabilisation du dépôt de garantie</summary>

	<hr class=mainPageTutoriel>
	<p>Le dépôt de garantie constitue comptablement pour une SCI :<br>
	- une somme d’argent conservée en banque durant toute la durée du bail<br>
	- une dette envers son locataire et qui devra lui être remboursée à la fin du bail.</p>

	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=depot_garantie'>Comptabilisation du dépot de garantie locataires.</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de VENTE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>165</div>
		  <div class='cell' data-title='Intitulé'>Dépôt et cautionnements reçus</div>
		  <div class='cell' data-title='Libellé'>Dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de BANQUE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>
	
	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=remboursement_depot_garantie'>Comptabilisation du remboursement intégral du dépôt de garantie :</a></p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>165</div>
		  <div class='cell' data-title='Intitulé'>Dépôt et cautionnements reçus</div>
		  <div class='cell' data-title='Libellé'>Remboursement du dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement du dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de BANQUE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement du dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Remboursement du dépot de garantie de Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<hr class=mainPageTutoriel>
	
	<p class=classp>Caution reçue et non remboursée pour loyer impayé (en totalité) :</p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>165</div>
		  <div class='cell' data-title='Intitulé'>Dépôt et cautionnements reçus</div>
		  <div class='cell' data-title='Libellé'>Retenu impayé dépot de garantie Mr X</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Retenu impayé dépot de garantie Mr X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de VENTE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Retenu impayé caution MrX</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>706</div>
		  <div class='cell' data-title='Intitulé'>Loyers impayés</div>
		  <div class='cell' data-title='Libellé'>Retenu impayé caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<hr class=mainPageTutoriel>
	
	<p class=classp>Caution reçue et non remboursée pour dégradation (en totalité)  :</p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>165</div>
		  <div class='cell' data-title='Intitulé'>Dépôt et cautionnements reçus</div>
		  <div class='cell' data-title='Libellé'>Retenu dégradation caution MrX</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Retenu dégradation caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de VENTE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Retenu dégradation caution MrX</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>791</div>
		  <div class='cell' data-title='Intitulé'>Transferts de charges</div>
		  <div class='cell' data-title='Libellé'>Retenu dégradation caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<hr class=mainPageTutoriel>
	
	<p class=classp>caution reçue et non remboursée (partiellement) :</p>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>165</div>
		  <div class='cell' data-title='Intitulé'>Dépôt et cautionnements reçus</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de VENTE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'>Retenu dégradation</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>791</div>
		  <div class='cell' data-title='Intitulé'>Transferts de charges</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Retenu dégradation</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de VENTE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'>Retenu loyer impayé</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>706</div>
		  <div class='cell' data-title='Intitulé'>Loyers impayés</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Retenu loyer impayé</div>
		</div>
	</div></div>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de BANQUE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant remboursé</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Remboursement partiel caution MrX</div>
		  <div class='cell' data-title='Débit'>Montant remboursé</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>
	
	<hr class=mainPageTutoriel>
	
	
	
	</details>
	
	<details id=immobiliere_2 class=alerte open><summary class=title1>Remboursement d’une assurance suite à un sinistre</summary>

	<hr class=mainPageTutoriel>
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de BANQUE</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Remboursement assurance suite sinistre</div>
		  <div class='cell' data-title='Débit'>Montant Total</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>791</div>
		  <div class='cell' data-title='Intitulé'>Transferts de charges d'exploitation</div>
		  <div class='cell' data-title='Libellé'>Remboursement assurance suite sinistre</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant Total</div>
		</div>
	</div></div>

	<hr class=mainPageTutoriel>
	
	</details>
	

	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>

	";	#cat_2 Courant section Comptabilité Immobilière FIN
	
	
	
	#cat_2 Courant - les déclarations  
	$content .= "
	<section id='declaration' class='main-section'>
		<header class='header'><h3>Les déclarations</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
    
    	<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#declaration_1' >Déclaration 2777 : Intérêts et Dividendes (15 du mois qui suit le paiement)</a></li>
		<li><a class=summary href='#declaration_2' >Déclaration 2561 : IFU (avant le 15/02)</a></li>
		<li><a class=summary href='#declaration_3' >Déclaration de la Liasse fiscale (avant le 01/05)</a></li>
		<li><a class=summary href='#declaration_4' >Déclaration 2572 : Relevé de solde IS (avant le 15/05)</a></li>
		<li><a class=summary href='#declaration_5' >Déclaration 2571 : Paiement d'acomptes IS et CRL</a></li>
		
		</ul>
		<hr class=mainPageTutoriel>

    <details id=declaration_1 class=warningdoc open><summary class=title1>Déclaration 2777 : Intérêts et Dividendes</summary>

	<hr class=mainPageTutoriel>
	<p><strong>Objet : </strong>Déclaration des paiements d'intérêts des comptes courants d'associés ou bien le paiement des dividendes.</p>
	<p><strong>Date limite : </strong>La déclaration doit être produite le 15 du mois suivant le paiement. Par exemple, pour un versement au 31 décembre, la déclaration doit être effectuée avant le 15 janvier.</p>
	
	<p><strong>Autres informations importantes : </strong></p>
	<p>* La déclaration 2777 réalise la collecte du prélèvement forfaitaire sur les revenus distribués, au taux de 12,8%, ce qui permet donc d’arriver au taux global de 30% (soit 17,2% + 12,8%) constituant le prélèvement forfaitaire unique ou PFU.</p>
	<p>* Le paiement du PFU se fait par prélèvement en ligne sur le compte de la société</p>
	<p>* Le contribuable aura la possibilité de renoncer au mécanisme du prélèvement forfaitaire à 12,8% lors du dépôt de sa déclaration d’impôt sur le revenu.</p>
	
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=declaration_2 class=alerte open><summary class=title1>Déclaration 2561 : IFU</summary>

	<hr class=mainPageTutoriel>
	<p><strong>Objet : </strong>Déclaration de la société récapitulant les revenus de capitaux mobiliers (intérêts et dividendes) versés à leurs associés au titre de l’année civile précédente</p>
	<p><strong>Date limite : </strong>La déclaration doit être déposée une fois par an, en N+1, avant le 15 février.</p>
	
	<p><strong>Autres informations importantes : </strong></p>
	
	<p>* L'IFU est un document récapitulatif des revenus de capitaux mobiliers de l'année versés à chaque bénéficiaire.</p>
	<p>* Accessible via <a href='https://www.impots.gouv.fr/'>l'espace professionnel impots.gouv.fr</a> et via le lien \"Tiers déclarants\" (rubrique \"Mes services\" puis \"Déclarer\") après votre adhésion et activation du service \"Tiers déclarants\" sur votre espace professionnel.</p>
	<p><strong>Mémo remplissage : </strong></p>
	<p><strong>- Les dividendes => </strong>Dans la « case AY » indiquer le montant brut des dividendes versés (c’est-à-dire avant paiement de l’impôt et des prélèvements sociaux).</p>
	<p><strong>- Les intérêts de compte courant d’associé => </strong>Dans la « case AR » indiquer le montant brut des intérêts de compte courant d’associé versés.</p>
	<p><strong>- Les prélèvements sociaux => </strong>Dans la « case DQ » indiquer le montant brut des dividendes et intérêts de compte courant versés à l’associé.
	</p>
	<p><strong>- Le prélèvement forfaitaire non libératoire (PFNL) => </strong>Dans la « case AD » indiquer le montant du PFNL de 12,80% qui a été prélevé à la source lors du versement des dividendes et des intérêts de compte courant. Il s’agit du montant figurant sur la déclaration 2777. Cette case doit rester vide uniquement si l’associé a demandé à être dispensé du PFNL.</p>
	
	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=declaration_3 class=info open><summary class=title1>Déclaration de la Liasse fiscale</summary>

	<hr class=mainPageTutoriel>
	<p><strong>Objet : </strong>Dépôt obligatoire des documents comptables auprès des services fiscaux..</p>
	<p><strong>Date limite : </strong>La déclaration doit être déposée au plus tard le 2e jour ouvré suivant le 1er mai.</p>
	
	<p><strong>Autres informations importantes : </strong></p>
	
	<p>* La liasse fiscale est composée du bilan et du compte de résultat de l’année écoulée, ainsi que d'un formulaire de déclaration du résultat de l’exercice précédent et des tableaux annexes.</p>
	<p>* Elle sert à calculer l’impôt dû par l’entreprise et permet aux services fiscaux de vérifier ses obligations.</p>
	
	<p><strong>Mémo remplissage : </strong></p>
<ul class=summary>
		<li><a class=summary href='#liasse_fiscale_1' >Quelle liasse fiscale ?</a></li>
		<li><a class=summary href='#liasse_fiscale_2' >Générer la liasse fiscale gratuitement via TELEDEC</a></li>
		<li><a class=summary href='#liasse_fiscale_3' >Les points clés de la liasse fiscale</a></li>
		</ul>
		
		<hr class=mainPageTutoriel>
		
		<div class=intro2>
		<p>Le pré-remplissages des formulaires <a href='bilan?liasse2033A'>2033A</a> <a href='bilan?liasse2033B'>2033B</a> et <a href='bilan?liasse2033C'>2033C</a> sont disponibles via le menu Bilan (<a href='bilan?liasse2033A'>Bilan => 2033A / 2033B / 2033C</a>)</p>
		</div>	
				
		<hr class=mainPageTutoriel>
			
		<div id='liasse_fiscale_1'>	
		<p class=title1>Quelle liasse fiscale ?</p>
		<p>À l’IS, il existe deux régimes : <strong>R</strong>égime <strong>S</strong>implifié ou <strong>R</strong>égime <strong>N</strong>ormal.</p>
		<ul><li><h4>Cas 1 : régime simplifié d’imposition (RS)</h4></li></ul>
		
		<p>Si vous êtes en régime simplifié d’imposition, votre liasse fiscale est la 2065 et les annexes à déclarer sont les formulaires 2033 A, B, C, D, E, F, G.</p>
		
		<p>Vous avez la possibilité d'effectuer la déclarations de résultats directement sur votre compte \"professionnel\" sur <a href='https://www.impots.gouv.fr/accueil'>impots.gouv.fr</a> => Rubrique \"Déclarer résultat\" ou par par l’intermédiaire d’un partenaire EDI (mode EDI-TDFC)</p>
	
		<p>Important : Le régime simplifié d’imposition ne concerne que les entreprises dont le chiffre d’affaires HT est inférieur à :</p>
		<ul><li>238 000 € pour les activités de prestation de services.</li>
		<li>789 000 € pour les autres activités (vente de marchandises, hébergement).</li></ul>
		<p><div class='label yellow'>Remarque :</div> l’intérêt unique mais essentiel du régime simplifié d’imposition est l’allégement des formalités fiscales de fin d’année</p>

		<ul><li><h4>Cas 2 : régime normal d’imposition (RN)</h4></li></ul>

		<p>Si vous dépassez les seuils ci dessus, vous êtes en régime normal d’imposition, votre liasse fiscale est la 2065 et les annexes à déclarer sont les formulaires 2050 à 2057, 2058 A, B, C et 2059 A, B, C, D, E, F, G.
		</p>
		<p>Concernant la déclarations de résultats, vous êtes dans l'obligation de passer par l’intermédiaire d’un partenaire EDI (mode EDI-TDFC)</p>
		<p><div class='label yellow'>Conseil :</div> ne choisissez le régime normal que si vous dépassez les seuils de chiffre d’affaires.</p>	
		

		</div>	
			
			<hr class=mainPageTutoriel>
		
			<div id='liasse_fiscale_2'>	
			<p class=title1>Générer la liasse fiscale gratuitement via TELEDEC</p>
			<p>Vous pouvez réaliser gratuitement votre liasse fiscale avec édition papier via <a href='https://www.teledec.fr/se-connecter'>TELEDEC</a></p>
			<p>TELEDEC est un partenaire EDI agréé par l'état seul la télédéclaration est payante</p>
			<p>Après avoir terminé la comptabilité de votre exercice télécharger la balance via le menu balance (<a href='compte?balance=0'>Balance => Télécharger</a>)     </p>	
			<p>Depuis TELEDEC, confirmer les informations de l'exercice et de la liasse fiscale, puis cliquer sur Autres actions => Remplir cette liasse à partir d'un logiciel comptable => sélectionner le fichier de balance et cliquer sur importer</p>
			<p>Il ne vous reste qu'à vous laissez guider dans les étapes de vérification et génération de la liasse fiscale.</p>
			</div>		
			
			<hr class=mainPageTutoriel>		
			
			<div id='liasse_fiscale_3'>	
			<p class=title1>Les points clés de la liasse fiscale</p>
			<ul><li><h4>Le formulaire 2033A</h4></li></ul>
			<p class=tab1>Ne pas oublier la case 195 \"Dont dettes à plus d'un an\" avec par exemple le montant du capital restant dû du crédit immobilier en date de fin d'exercice</p>
			<ul><li><h4>Le formulaire 2033B</h4></li></ul>
			<ul><li><h4>Le formulaire 2033C</h4></li></ul>
			</div>	
	
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=declaration_4 class=alert open><summary class=title1>Déclaration 2572 : Relevé de solde IS</summary>

	<hr class=mainPageTutoriel>
	
	<p><strong>Objet : </strong>Déclaration du solde d'IS et de contributions assimilées (exemple : CRL) à payer ou demande de remboursement d'un excédent d'IS.</p>
	<p><strong>Date limite : </strong>
	
	<p>* Cas d'un impôt inférieur à 3 000 € : La déclaration doit être déposée au plus tard le 15 mai de l'année N+1 pour une société dont l’exercice se termine le 31 décembre.</p>
	<p>* Cas d'un impôt supérieur à 3 000 € : Pour le premier exercice se terminant le 31 décembre 2023, le paiement de l’IS doit être effectué le 15 mai 2024 en une seule fois (formulaire 2572), ainsi qu'un acompte le 15 mars 2024 en prévision de l’exercice de 2024.</p>

	<p><strong>Autres informations importantes : </strong></p>
	
	<p>* Le relevé de solde IS doit être accompagné du règlement de l'impôt dû, le cas échéant.</p>
	<p>* Les paiements d'impôts peuvent être effectués en ligne via le portail impots.gouv.fr ou par chèque bancaire, virement ou prélèvement automatique.</p>	
	
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=declaration_5 class=warningdoc open>
  <summary class=title1>Déclaration 2571 : Paiement d'acomptes IS</summary>
  
	<hr class=mainPageTutoriel>
  
  <p><strong>Objet : </strong>Déclaration et paiement des acomptes d'impôt sur les sociétés (IS).</p>
  
  <p><strong>Date limite : </strong></p>
  <ul>
    <li>Premier acompte : à régler au plus tard le 15 mars de l'année en cours pour les sociétés clôturant leur exercice le 31 décembre.</li>
    <li>Deuxième acompte : à régler au plus tard le 15 juin.</li>
    <li>Troisième acompte : à régler au plus tard le 15 septembre.</li>
    <li>Quatrième acompte : à régler au plus tard le 15 décembre (inclut également l'acompte de Contribution sur les Revenus Locatifs - CRL, le cas échéant).</li>
  </ul>
  
  <p><strong>Autres informations importantes : </strong></p>
  <ul>
    <li>Les acomptes sont calculés en fonction de l’impôt sur les sociétés dû au titre de l'exercice précédent.</li>
    <li>Un acompte n'est pas exigible si le montant de l'IS dû pour l'exercice précédent est inférieur à 3 000 €.</li>
    <li>Les paiements peuvent être effectués en ligne via le portail impots.gouv.fr ou par chèque bancaire, virement ou prélèvement automatique.</li>
    <li>Le formulaire 2571 doit être correctement complété et accompagné du règlement des acomptes, le cas échéant.</li>
  </ul>
  
	<hr class=mainPageTutoriel>
</details>


	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	";
	
	#cat_2 Courant - Les impôts  
	$content .= "
	<section id='impots' class='main-section'>
    	<header class='header'><h3>Les impôts</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		<hr class=mainPageTutoriel>
		<ul class=summary>
		<li><a class=summary href='#impots_1' >Comptabilisation de l'impôt sur les bénéfices</a></li>
		<li><a class=summary href='#impots_2' >Comptabilisation des autres impôts et taxes (TF)</a></li>
		<li><a class=summary href='#impots_3' >Comptabilisation de la Contribution annuelle sur les Revenus Locatifs (CRL)</a></li>
		<li><a class=summary href='#impots_4' >Le compte de charge impôt à utiliser</a></li>
		</ul>
		
    <hr class=mainPageTutoriel>
			
	
    <details id=impots_1 class=warningdoc open><summary class=title1>Comptabilisation de l'impôt sur les bénéfices</summary>
	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors du versement des acomptes (IS >3000€) </p>
	<p>Le 1er acompte calculé sur les bénéfices N-2 doit être payé le 15 mars
	<br>Le 2ème acompte calculé sur les bénéfices N-1 ainsi que la régularisation du 1er acompte doivent être payés le 15 juin
	<br>Le 3ème acompte calculé sur les bénéfices N-1 doit être payé le 15 septembre
	<br>Le 4ème acompte calculé sur les bénéfices N-1 doit être payé le 15 décembre 
	</p>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>444</div>
		  <div class='cell' data-title='Intitulé'>État - Impôt sur les bénéfices</div>
		  <div class='cell' data-title='Libellé'>Acompte impot X</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>

		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Acompte impot X</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>

	</div></div>	

	<hr class=mainPageTutoriel>
	
	<p class=classp> <a class='nav2' href='menu?saisie_rapide&scenario=impot_benefices'>Lors de la clôture de l'exercice</a></p>
	
	<p >Le 31 décembre (fin d'exercice), l'impôt sur les bénéfices N doit être évalué :</p>
	
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>695</div>
		  <div class='cell' data-title='Intitulé'>Impôts sur les bénéfices</div>
		  <div class='cell' data-title='Libellé'>Impôts sur les bénéfices</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>444</div>
		  <div class='cell' data-title='Intitulé'>État - Impôt sur les bénéfices</div>
		  <div class='cell' data-title='Libellé'>Impôts sur les bénéfices</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		
	</div></div>
	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors du paiement du solde d'impôt</p>
	
	<p>Le 31 mars N+1, le solde de l'impôt sur les sociétés de N doit être liquidé</p>
	
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal de banque</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>444</div>
		  <div class='cell' data-title='Intitulé'>État - Impôt sur les bénéfices</div>
		  <div class='cell' data-title='Libellé'>Solde impot</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>

		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Solde impot</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>

		
	</div></div>
	<hr class=mainPageTutoriel>
	</details>
	
	<details id=impots_2 class=alert open><summary class=title1>Comptabilisation des autres impôts et taxes</summary>
	<hr class=mainPageTutoriel>
	
	<p>La comptabilisation des impôts et taxes s'opère en 2 temps, lors de la réception de l'avis d'imposition et lors du paiement de l'impôt.
	</p>
	
	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors de la réception de l'avis d'imposition</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'achats</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>63</div>
		  <div class='cell' data-title='Intitulé'>Compte de charge impôt</div>
		  <div class='cell' data-title='Libellé'>Taxe foncière</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>447</div>
		  <div class='cell' data-title='Intitulé'>Autres impôts, taxes et versements assimilés</div>
		  <div class='cell' data-title='Libellé'>Taxe foncière</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors du paiement d'un acompte ou du solde</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>447</div>
		  <div class='cell' data-title='Intitulé'>Autres impôts, taxes et versements assimilés</div>
		  <div class='cell' data-title='Libellé'>Taxe foncière</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>

		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>Taxe foncière</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=impots_3 class=alerte open><summary class=title1>Comptabilisation de la Contribution annuelle sur les Revenus Locatifs (CRL)</summary>
	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors de la réception de l'avis d'imposition</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal d'achats</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>63513</div>
		  <div class='cell' data-title='Intitulé'>Compte de charge impôt</div>
		  <div class='cell' data-title='Libellé'>CRL</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>447</div>
		  <div class='cell' data-title='Intitulé'>Autres impôts, taxes et versements assimilés</div>
		  <div class='cell' data-title='Libellé'>CRL</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	<p class=classp>Lors du paiement d'un acompte ou du solde</p>	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>447</div>
		  <div class='cell' data-title='Intitulé'>Autres impôts, taxes et versements assimilés</div>
		  <div class='cell' data-title='Libellé'>CRL</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>

		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>CRL</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	
	<p class=classp>Lors de la clôture de l'exercice</p>
	
	<p >Il faut constater en fin d’exercice une charge à payer (provision) :</p>
	
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>63513</div>
		  <div class='cell' data-title='Intitulé'>CRL</div>
		  <div class='cell' data-title='Libellé'>provision CRL</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>4486</div>
		  <div class='cell' data-title='Intitulé'>Etat Charges à payer</div>
		  <div class='cell' data-title='Libellé'>provision CRL</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		
	</div></div>
		
		<p >Il faut extourner l’écriture en début d’exercice :</p>
	
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>63513</div>
		  <div class='cell' data-title='Intitulé'>CRL</div>
		  <div class='cell' data-title='Libellé'>extourne provision CRL</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>4486</div>
		  <div class='cell' data-title='Intitulé'>Etat Charges à payer</div>
		  <div class='cell' data-title='Libellé'>extourne provision CRL</div>
		  <div class='cell' data-title='Débit'>Montant</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		
	</div></div>
	
	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=impots_4 class=info open><summary class=title1>Le compte de charge impôt à utiliser</summary>
	<hr class=mainPageTutoriel>
	
	<p>
	Le compte 63 à utiliser dépend de la base de calcul de l'impôt et/ou de son organisme collecteur :
	</p>
	<ul>
	<li><strong>631. Impôts, taxes et versements assimilés sur rémunérations (administrations des impôts)</strong> : taxe d'apprentissage, taxe sur les salaires, participation des employeurs à la formation professionnelle continue, cotisation pour défaut d'investissement obligatoire dans la construction ;</li>
	<li><strong>633. Impôts, taxes et versements assimilés sur rémunérations (autres organismes)</strong> : versements libératoires ouvrant droit à l'exonération de la taxe d'apprentissage, participation des employeurs à l'effort de construction lorsqu'il s'agit de versements à fonds perdu, participation des employeurs à la formation professionnelle continue lorsque les dépenses sont libératoires ;</li>
	<li><strong>635. Autres impôts, taxes et versements assimilés (administrations des impôts)</strong> : taxe foncière, taxe sur les émissions de CO2, taxe en fonction de l'ancienneté des véhicules, contribution économique territoriale (cotisation foncière des entreprises et cotisation sur la valeur ajoutée des entreprises) ;
	</li>
	<li><strong>637. Autres impôts, taxes et versements assimilés (autres organismes)</strong> :contribution sociale de solidarité</li>
	</ul>
		
	<hr class=mainPageTutoriel>
	
	</details>
	
	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	";
	
	#cat_2 Courant section paiementcheque
	$content .= "
	<section id='paiement' class='main-section'>
	<header class='header'><h3>Les Paiements</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
	    <hr class=mainPageTutoriel>
	    
	    <p><strong>Paiement Chèque :</strong></p>
		<ul class=summary>
		<li><a class=summary href='#paiementcheque_1' >Comptabilisation en tant que vendeur => Réglement du client par chèque</a></li>
		<li><a class=summary href='#paiementcheque_2' >Comptabilisation en tant qu'acheteur => Réglement au fournisseur par chèque</a></li>
		</ul>
		<p><strong>Paiement Espèce :</strong></p>
		<ul class=summary>
		<li><a class=summary href='#paiementespece_1' >Comptabilisation en tant que vendeur => Réglement du client en espèce</a></li>
		<li><a class=summary href='#paiementespece_2' >Comptabilisation en tant qu'acheteur => Réglement au fournisseur en espèce</a></li>
		</ul>
		<p><strong>Paiement Virement :</strong></p>
		<ul class=summary>
		<li><a class=summary href='#paiementvirement_1' >Comptabilisation en tant que vendeur => Réglement du client par virement</a></li>
		<li><a class=summary href='#paiementvirement_2' >Comptabilisation en tant qu'acheteur => Réglement au fournisseur en virement</a></li>
		</ul>
		
	<hr class=mainPageTutoriel>
	<p class=title1>Paiement Chèque :</p>
	
    <details id=paiementcheque_1 class=warningdoc open><summary class=title1>Comptabilisation en tant que vendeur => Réglement du client par chèque</summary>
	

	<p class=classp>Cas avec utilisation directe du compte 512 banque</p>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque / date de paiement</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>n° de remise de chèque en banque</div>
		  <div class='cell' data-title='Débit'>Montant chèque</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>n° de remise de chèque en banque</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant chèque</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	<p class=classp>Cas avec utilisation du compte intermédiaire 5112 chèques à encaisser</p>
	
	<p>D’abord : À chaque fois que l’entreprise réceptionne le chèque d’un client</p>
		
	<div class='wrappertable'><div class='table'>
		<div class='caption'>Journal d'OD (ou de chèque à encaisser) / date de paiement</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>5112</div>
		  <div class='cell' data-title='Intitulé'>Chèque à encaisser</div>
		  <div class='cell' data-title='Libellé'>N° du chèque de client</div>
		  <div class='cell' data-title='Débit'>Montant chèque</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>N° du chèque de client</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Montant chèque</div>
		</div>
	</div></div>

	<p>Ensuite : Lors de la remise en banque d’un ensemble de chèques reçus des clients</p> 
	
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque / date de remise des chèques</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>n° de remise de chèque en banque</div>
		  <div class='cell' data-title='Débit'>Total remise</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>5112</div>
		  <div class='cell' data-title='Intitulé'>Chèques à encaisser</div>
		  <div class='cell' data-title='Libellé'>n° de remise de chèque en banque</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>Total remise</div>
		</div>
	</div></div><hr class=mainPageTutoriel>
	
	</details>
	
	<details id=paiementcheque_2 class=alerte open><summary class=title1>Comptabilisation en tant qu'acheteur => Réglement au fournisseur par chèque</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de banque / date de paiement</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>401</div>
		  <div class='cell' data-title='Intitulé'>Fournisseur</div>
		  <div class='cell' data-title='Libellé'>n° de chèque</div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>512</div>
		  <div class='cell' data-title='Intitulé'>Banque</div>
		  <div class='cell' data-title='Libellé'>n° de chèque</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<hr class=mainPageTutoriel>
	<p class=title1>Paiement Espèce :</p>
	
	<details id=paiementespece_1 class=warningdoc open><summary class=title1>Comptabilisation en tant que vendeur => Réglement du client en espèce</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de caisse</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>530</div>
		  <div class='cell' data-title='Intitulé'>Caisse</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=paiementespece_2 class=alerte open><summary class=title1>Comptabilisation en tant qu'acheteur => Réglement au fournisseur en espèce</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de caisse</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>401</div>
		  <div class='cell' data-title='Intitulé'>Fournisseur</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>530</div>
		  <div class='cell' data-title='Intitulé'>Caisse</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<hr class=mainPageTutoriel>
	<p class=title1>Paiement Virement :</p>
	
	<details id=paiementvirement_1 class=warningdoc open><summary class=title1>Comptabilisation en tant que vendeur => Réglement du client par virement</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de l'établissement financier</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>51</div>
		  <div class='cell' data-title='Intitulé'>Etablissement financier</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>411</div>
		  <div class='cell' data-title='Intitulé'>Client</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
	
	<details id=paiementvirement_2 class=alerte open><summary class=title1>Comptabilisation en tant qu'acheteur => Réglement au fournisseur en virement</summary>

	<hr class=mainPageTutoriel>
		
	<div class='wrappertable'><div class='table'><div class='caption'>Journal de l'établissement financier</div>
		<div class='row header'>
		  <div class='cell'>Comptes</div>
		  <div class='cell'>Intitulé</div>
		  <div class='cell'>Libellé</div>
		  <div class='cell'>Débit</div>
		  <div class='cell'>Crédit</div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>401</div>
		  <div class='cell' data-title='Intitulé'>Fournisseur</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'>net à payer</div>
		  <div class='cell' data-title='Crédit'></div>
		</div>
		<div class='row'>
		  <div class='cell' data-title='Comptes'>51</div>
		  <div class='cell' data-title='Intitulé'>Etablissement financier</div>
		  <div class='cell' data-title='Libellé'>n° facture réglée</div>
		  <div class='cell' data-title='Débit'></div>
		  <div class='cell' data-title='Crédit'>net à payer</div>
		</div>
	</div></div>	

	<hr class=mainPageTutoriel>
	
	</details>
		
	<br>	
	".$hidden[22]."
	".$hidden[20]."
	</section>
	
		";
		
		
	#cat_2 Courant Section travaux_periodiques
	$content .= "
		<section id='travaux_periodiques' class='main-section'>
		<header class='header'><h3>Travaux periodiques</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		<p>Voici la check-list des tâches à faire tous les mois</p>
		  <ul class=checklist>
		  <li>Saisir les pièces comptables</li>
		  <li>Saisir les opérations de banque</li>
		  <li>Lettrer les comptes clients</li>
		  <li>Lettrer les comptes de tiers</li>
		  <li>Lettrer les comptes 467 débiteurs/créditeurs</li>
		  <li>Vérifier le solde du compte 471 qui doit être à 0 €</li>
		  <li>Vérifier le solde du compte 580 qui doit être à 0 €</li>
		  <li>Faire le rapprochement bancaire</li>
		</ul>
	".$hidden[22]."
	".$hidden[20]."
	</section>	
	";	
	
	 return $content ;
} #sub articles_bar2 

#/*—————————————— articles_bar3 => Utilitaires ——————————————*/
sub articles_bar3 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my @hidden = ('0') x 40;

	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 

#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";
	
	#cat_2 Courant Section comptes courants associés
	my $content .= "
	
	<section id='importexport' class='main-section'>
		<header class='header'><h3>Import/Export</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		
		<hr class=mainPageTutoriel>
		
			<ul class=summary>
			<li><a class=summary href='#importexport_1' >Exportation de fichier</a></li>
			<li><a class=summary href='#importexport_2' >Importation de fichier</a></li>
			</ul>

			<hr class=mainPageTutoriel>
		
			<div id='importexport_1'>	
			<p class=title1>Exportation de fichier</p>
			<p>Le menu <a href='export'>Export => Exportations des données</a> permet d'exporter et d'archiver les écritures enregistrées dans la base</p>
			<h4>Valeurs possibles pour le type d'exportation :</h4>
			<ul>
			  <li>CSV - Liste des journaux pour l'exercice en cours : Permet d'exporter la liste des journaux actifs pour l'exercice en cours.</li>
			  <li>CSV - Liste des comptes pour l'exercice en cours : Permet d'exporter la liste des comptes comptables utilisés durant l'exercice en cours.</li>
			  <li>FEC - Fichier des écritures comptables (Article A47 A-1) : Fichier d'exportation conforme aux dispositions de l'article A47 A-1 du livre des procédures fiscales, contenant toutes les écritures enregistrées dans l'exercice.</li>
			  <li>CSV - Fichier de toutes les écritures pour l'exercice en cours : Permet d'exporter l'ensemble des données comptables enregistrées dans la base pour l'exercice en cours au format CSV.</li>
			</ul>
			</div>
		
			<hr class=mainPageTutoriel>
			
			<div id='importexport_2'>
			<p class='title1'>Importation de fichier</p>
			<p><a href='journal?open_journal=Journal%20général&import=0'>Journaux => Journal Général => Importer des écritures</a> permet d'importer des écritures comptables au format FEC ou CSV.</p>
			<p>Avant l'importation, il est possible d'activer certains paramètres en cochant des cases :</p>
			<ul>
				<li><strong>Sauvegarder avant import :</strong> Permet de sauvegarder une copie des données existantes avant l'importation.</li>
				<li><strong>Créer les comptes manquants :</strong> Ajoute automatiquement les comptes qui ne sont pas encore enregistrés.</li>
				<li><strong>Créer les journaux manquants :</strong> Ajoute automatiquement les journaux qui ne sont pas encore enregistrés.</li>
				<li><strong>Supprimer les données non validées de l'exercice :</strong> Supprime les données non validées dans l'exercice en cours avant d'importer les nouvelles données.</li>
			</ul>
			<p><strong>Caractéristiques du fichier :</strong></p>
			<ul>
				<li>Le fichier doit être encodé en UTF-8, avec ou sans en-tête.</li>
				<li>Il doit contenir au moins deux valeurs séparées par un ; (point-virgule), | (barre verticale), ou , (virgule).</li>
				<li>Tous les champs précédés d'une étoile (*) ne peuvent pas être vides.</li>
				<li>Les montants (Débit, Crédit) peuvent comporter des décimales.</li>
				<li><strong>Les écritures doivent être équilibrées par date, numéro de pièce et libellé.</strong></li>
				<li>L'importation des écritures est totale, si aucune erreur n'est détectée. Sinon, aucune écriture n'est importée, et un message d'erreur affiche la liste des écritures empêchant l'importation.</li>
			</ul>
			
			<hr class=mainPageTutoriel>
			
			<div class='table'>
				<div class='caption'>Exemple du format de fichier FEC à utiliser</div>
				<div class='row header'>
					<div class='cell' style='width: 30%'>Nom du champ</div>
					<div class='cell' style='width: 30%'>Type de données</div>
					<div class='cell' style='width: 30%'>Remarques</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*JournalCode</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Code du journal (ex. : AN, OD)</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*JournalLib</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé du journal</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>EcritureNum</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Numéro de l'écriture</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*EcritureDate</strong></div>
					<div class='cell' style='width: 30%'>Date</div>
					<div class='cell' style='width: 30%'>Date de l'écriture (format AAAAMMJJ)</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*CompteNum</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Numéro de compte</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*CompteLib</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé du compte</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>CompAuxNum</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Numéro de compte auxiliaire</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>CompAuxLib</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé du compte auxiliaire</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>PieceRef</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Référence de la pièce</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>PieceDate</div>
					<div class='cell' style='width: 30%'>Date</div>
					<div class='cell' style='width: 30%'>Date de la pièce (format AAAAMMJJ)</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'><strong>*EcritureLib</strong></div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Libellé de l'écriture</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>Debit</div>
					<div class='cell' style='width: 30%'>Numérique</div>
					<div class='cell' style='width: 30%'>Montant au débit</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>Credit</div>
					<div class='cell' style='width: 30%'>Numérique</div>
					<div class='cell' style='width: 30%'>Montant au crédit</div>
				</div>
				 <div class='row'>
					<div class='cell' style='width: 30%'>EcritureLet</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Lettrage de l'écriture</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>DateLet</div>
					<div class='cell' style='width: 30%'>Date</div>
					<div class='cell' style='width: 30%'>Date de lettrage (format AAAAMMJJ)</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>ValidDate</div>
					<div class='cell' style='width: 30%'>Date</div>
					<div class='cell' style='width: 30%'>Date de validation de l'écriture (format AAAAMMJJ)</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>Montantdevise</div>
					<div class='cell' style='width: 30%'>Numérique</div>
					<div class='cell' style='width: 30%'>Montant dans une devise étrangère</div>
				</div>
				<div class='row'>
					<div class='cell' style='width: 30%'>Idevise</div>
					<div class='cell' style='width: 30%'>Texte</div>
					<div class='cell' style='width: 30%'>Identifiant de la devise utilisée</div>
				</div>
			</div>
			
			<hr class=mainPageTutoriel>
			
			<p><strong>Exemple de fichier FEC :</strong></p>
			<p>
			JournalCode|JournalLib|EcritureNum|EcritureDate|CompteNum|CompteLib|CompAuxNum|CompAuxLib|PieceRef|PieceDate|EcritureLib|Debit|Credit|EcritureLet|DateLet|ValidDate|Montantdevise|Idevise
			<br>BQ|Banque|1|20240101|5121CRA|CR AGRICOLE|||A01|20240101|PPRO domiciliation 1TR|0,00|187,20|||20241107||
			<br>BQ|Banque|1|20240101|401PPRO|PUBLI-PROV|||A01|20240101|PPRO domiciliation 1TR|187,20|0,00|||20241107||
			<br>FR|Fournisseurs|2|20240101|4456600|TVA DEDUCTIBLE|||A01|20240101|PPRO domiciliation 1TR|31,20|0,00|||20241107||
			<br>FR|Fournisseurs|2|20240101|611010|Serveurs|||A01|20240101|PPRO domiciliation 1TR|0,00|20,00|||20241107||
			</p>
			
			<hr class=mainPageTutoriel>
			
			<p><strong>Exemple de fichier CSV :</strong></p>
			<p>
			<p>journalcode;journallib;ecriturenum;ecrituredate;comptenum;comptelib;libre;pieceref;ecriturelib;debit;credit;ecriturelet;ecriturepointage;documents1;documents2;date_creation;validdate;exercice;id_export;doc1_date_reception;doc1_libelle_cat_doc;doc1_montant;doc1_date_upload;doc1_last_fiscal_year_doc;doc1_check_banque;doc1_id_compte;doc2_date_reception;doc2_libelle_cat_doc;doc2_montant;doc2_date_upload;doc2_last_fiscal_year_doc;doc2_check_banque;doc2_id_compte;date_export
			<br>BQ;Banque;1;2024-01-01;5121CRA;CR AGRICOLE;;A01;PPRO domiciliation 1TR;            0,00;          187,20;;f;;;2024-05-24;2024-11-07;2024;1;;;;;;;;;;;;;;;2024-11-07
			<br>BQ;Banque;1;2024-01-01;401PPRO;PUBLI-PROV;;A01;PPRO domiciliation 1TR;          187,20;            0,00;;f;;;2024-05-24;2024-11-07;2024;1;;;;;;;;;;;;;;;2024-11-07
			<br>FR;Fournisseurs;2;2024-01-01;613210;Domiciliation;;A01;PPRO domiciliation 1TR;          156,00;            0,00;;f;;;2024-06-18;2024-11-07;2024;1;;;;;;;;;;;;;;;2024-11-07
			<br>FR;Fournisseurs;2;2024-01-01;611010;Serveurs;;A01;PPRO domiciliation 1TR;            0,00;           20,00;;f;;;2024-06-18;2024-11-07;2024;1;;;;;;;;;;;;;;;2024-11-07
			</p>
		</div>

			
		<hr class=mainPageTutoriel>
		
	".$hidden[23]."
	".$hidden[20]."
	</section>	
  	
  	";	
	
	 return $content ;
} #sub articles_bar3 

#/*—————————————— articles_bar4 => Exercice Comptable ——————————————*/
sub articles_bar4 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my @hidden = ('0') x 40;

	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 

#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";
	
	#cat_4 Exercice Comptable
	my $content .= "

	<section id='reconduite' class='main-section'>
		<header class='header'><h3>Début d'exercice</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
		<hr class=mainPageTutoriel>
		
		<ul class=summary>
		<li><a class=summary href='#reconduite_1' >Nouvel exercice comptable</a></li>
		<li><a class=summary href='#reconduite_2' >Premier exercice comptable</a></li>
		</ul>
		
		<hr class=mainPageTutoriel>
		
		<div id='reconduite_1'>	
		<p class=title1>Nouvel exercice comptable</p>
		<p>En début d'un nouvel exercice, il faut reprendre le plan comptable de l'année précédente (les journaux et les comptes) et générer les à nouveaux (écritures d'ouverture qui reprennent le solde des comptes de bilan de la CLASSES 1 à 5) :</p>
 		<p>Toutes ces actions sont disponibles depuis le menu <a href='compte?reports=0'>Comptes => Reports</a>.</p>

		<hr class=mainPageTutoriel>	
	
		<div id='reconduite_2'>	
		<p class=title1>Premier exercice comptable</p>
		<p>Dans le cas d'un premier exercice, il vous faut :</p>
		<ul>
		<li>Créer vos journaux depuis le Menu <a href='journal?configuration'>Journaux => Modifier la liste</a> (voir le chapitre <a href='#journaux'>Journaux</a>)</li>
		<li>Créer vos comptes depuis le Menu <a href='compte?configuration'>Comptes => Configuration</a> (voir le chapitre <a href='#comptes'>Comptes</a>)</li>
		</ul>
	
		<hr class=mainPageTutoriel>	
		".$hidden[24]."
		".$hidden[20]."
	</section>
		
	<section id='cloture' class='main-section'>
		<header class='header'><h3>Clôture d'exercice</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>

		<hr class=mainPageTutoriel>
		
		<ul class=summary>
		<li><a class=summary href='#cloture_2' >Procédure de clôture</a></li>
		</ul>
		
		<hr class=mainPageTutoriel>
		
		<div id='cloture_2'>	
		<p class=title1>Procédure de clôture</p>
		<ul><li><h4>Analyses des données comptables</h4></li></ul>
		<p>Via le menu <a href='bilan?analyses'>Bilan => Analyses</a><br>
		Ce module permet de lancer une série de vérifications comptables afin de détecter d'éventuelles anomalies.</p>
		</p>
		<ul><li><h4>Sauvegarder les données</h4></li></ul>
		<p>Via le menu <a href='parametres?sauvegarde'>Sauvegarde & restauration => Sauvegarde & restauration database</a></p>
		<ul><li><h4>Valider les écritures</h4></li></ul>
		<p>Via le menu <a href='export'>Export => Validation des écritures.</a><br>
		La validation des écritures a pour objectif le blocage des écritures. Elle va incrémenter un numéro d’ordre, affecter un numéro de pièce automatique si celui-ci n'est pas présent, et enregistre la date du jour comme date de validation. Aucune correction sur ces écritures ne pourra être effectuée. Cependant de nouvelles saisies sur la période restent possibles.</p>
		<ul><li><h4>Clôturer les comptes</h4></li></ul>
		<p>Via le menu <a href='compte?cloture=0'>Comptes => Clôture</a><br>
		La clôture des comptes solde les comptes de classe 6 et 7, calcule le résultat et l'inscrit au compte 12000 ou 12900 selon que le résultat de l'exercice est positif (excédent / bénéfice) ou négatif (déficit / perte). (les comptes sont créés automatiquement s'ils n'existent pas)<br>
		Les opérations effectuées sont d'abord affichées dans le formulaire de saisie d'une écriture pour validation. L'opération est réversible par suppression de l'OD enregistrée, si les journaux n'ont pas été cloturés.</p>
		<ul><li><h4>Editer les documents comptables</h4></li></ul>
		<p>lancer toutes les éditions de type grand livre, journaux, balances</p>
		<ul><li><h4>Exporter le FEC</h4></li></ul>
		<p>Via le menu <a href='export'>Export => Exportations des données => FEC - Fichier des écritures comptables (Article A47 A-1)</a><br>
		<p><div class=\"label red\">Attention !</div> L'archivage est obligatoire pour toutes les comptabilités informatisées de toutes les structures, dès lors qu'elles sont soumises à l'impôts. A défaut, l'entreprise s'expose à des sanctions en cas de contrôle fiscal.</p>
		<ul><li><h4>Clôturer les journaux</h4></li></ul>
		<p>Via le menu <a href='export?archive_this=0&id_month=ALL&pretty_month=ALL'>Export => Clôtures => Clôtures annuelles</a><br>
		La clôture des journaux consiste à bloquer la saisie et la modification des écritures pour tous les journaux.</p>
		
		
		<hr class=mainPageTutoriel>	
		".$hidden[24]."
		".$hidden[20]."
	</section>
	
	<section id='prepcloture' class='main-section'>
		<header class='header'><h3>Check-list avant clôture</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
		<hr class=mainPageTutoriel>
		
		<ul class=summary>
		<li><a class=summary href='#prepcloture_1' >Contrôles d'ensemble</a></li>
		<li><a class=summary href='#prepcloture_2' >Trésorerie</a></li>
		<li><a class=summary href='#prepcloture_3' >Achats</a></li>
		<li><a class=summary href='#prepcloture_4' >Ventes</a></li>
		<li><a class=summary href='#prepcloture_5' >Stocks</a></li>
		<li><a class=summary href='#prepcloture_6' >Immobilisations</a></li>
		<li><a class=summary href='#prepcloture_7' >Personnel</a></li>
		<li><a class=summary href='#prepcloture_8' >Etat</a></li>
		<li><a class=summary href='#prepcloture_9' >Capitaux</a></li>
		</ul>
		
	<hr class=mainPageTutoriel>
			
		<div id='prepcloture_1'>	
		<p class=title1>Contrôles d'ensemble</p>
		<ul>
		<li>Contrôler les comptes d’attente (471 à 475) qui doivent être soldés</li>
		<li>Contrôler les comptes de virements internes (58) qui doivent être soldés</li>
		<li>Contrôler par sondages que les enregistrements comptables s’appuient sur une pièce justificative et que l'imputation comptable est correcte </li>
		<li>Contrôler la cohérence des principaux ratios par rapport à ceux de l’exercice précédent</li>
		<li>Tous les soldes des comptes des classes 1, 2, 3, 4, et 5 doivent être justifiés, c'est à dire qu'ils doivent être expliqués facilement à l'aide 
		d'une ou plusieurs pièces comptables telles que factures, déclaration sociale ou fiscale, releve, tableau.
		</ul>
		</div>	
			
	<hr class=mainPageTutoriel>
	
		<div id='prepcloture_2'>	
		<p class=title1>Trésorerie</p>
		<ul>
		<li>Contrôler et justifier les comptes de trésorerie (banques, caisses, CCP)</li>
		<li>Contrôler les états de rapprochement si les règlements sont enregistrés d'après les pièces
		(talons de chèques, effets de commerce, avis de virement et de prélèvement, etc.)</li>
		<li>Contrôler par épreuve l’absence de soldes créditeurs en caisse au cours de l’exercice</li>
		<li>Contrôler l’état des valeurs mobilières avec la comptabilité</li>
		<li>Contrôler les tableaux d’amortissement des emprunts avec la comptabilité. Les soldes des comptes d'emprunt (16) doivent correspondre au capital restant dû à la clôture de l'exercice.</li>
		</ul>
		</div>		
			
	<hr class=mainPageTutoriel>		
	
		<div id='prepcloture_3'>	
		<p class=title1>Achats</p>
		<ul>
		<li>Analyser les principaux comptes d’achats afin de détecter d’éventuelles anomalies qui pourraient justifier des contrôles complémentaires</li>
		<li>Contrôler les comptes des fournisseurs (40) débiteurs (ils doivent en principe présenter un solde créditeur et les éventuelles créances fournisseurs (acomptes notamment) devraient figurer en 409</li>
		<li>Contrôler la cohérence du ratio fournisseurs</li>
		<li>Contrôler la correcte séparation des exercices</li>
		<li>Contrôler la concordance entre la comptabilité et les contrats et échéanciers pour crédit-bail, loyer, assurances …</li>
		<li>S’assurer que les comptes de charges ne contiennent pas des biens susceptibles de constituer des immobilisations</li>
		</ul>
		</div>			
		
	<hr class=mainPageTutoriel>	
	
		<div id='prepcloture_4'>	
		<p class=title1>Ventes</p>
		<ul>
		<li>Contrôler par épreuve le dénouement en N+1 de certaines créances clients significatives</li>
		<li>Contrôler les créances douteuses et leur dépréciation</li>
		<li>Contrôler la cohérence du ration crédit clients</li>
		<li>Contrôler la correcte séparation des exercices</li>
		<li>Contrôler les comptes clients (41) créditeurs (ils doivent en principe présenter un solde débiteur et les éventuelles dettes clients (acomptes notamment) en 419</li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	
	
		<div id='prepcloture_5'>	
		<p class=title1>Stocks</p>
		<ul>
		<li>Les comptes de stocks et en-cours (classe 3) doivent traduire la valeur des stocks et en-cours après inventaire, à la clôture de l'exercice</li>
		<li>Contrôler, par épreuves, l’application de la méthode de valorisation annoncée et de dépréciation</li>
		<li>Contrôler la cohérence du montant des en-cours avec la facturation de l’exercice suivant</li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	

		<div id='prepcloture_6'>	
		<p class=title1>Immobilisations</p>
		<ul>
		<li>Contrôler les soldes des comptes d'immobilisation (20, 21, 22) pour qu'il corresponde à la valeur brute
		en fin d'exercice fournie par le tableau des immobilisations. Les amortissements (28) doivent correspondre au cumul des amortissements
		en fin d'exercice fourni par le tableau des	immobilisations.</li>
		<li>Contrôler les mouvements des immobilisations financières</li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	
	
		<div id='prepcloture_7'>	
		<p class=title1>Personnel</p>
		<ul>
		<li>Contrôler le rapprochement entre les salaires comptabilisés et la DADS/DSN</li>
		<li>Contrôler les soldes des dettes fiscales et sociales avec les déclarations de la dernière période</li>
		<li>Apprécier le taux global de charges sociales </li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	
	
		<div id='prepcloture_8'>	
		<p class=title1>Etat</p>
		<ul>
		<li>Contrôler le rapprochement du chiffre d’affaires déclaré en TVA avec la comptabilité</li>
		<li>Contrôler le calcul du résultat fiscal et de l’IS (écriture d'évaluation de l’impôt sur les bénéfices N)</li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	
	
		<div id='prepcloture_9'>	
		<p class=title1>Capitaux</p>
		<ul>
		<li>Vérifier l’affectation du résultat N-1 (les comptes 120 et 129 doivent être soldés)</li>
		<li>Vérifier la bonne application des décisions des assemblées</li>
		</ul>
		</div>	
		
	<hr class=mainPageTutoriel>	
	
	".$hidden[24]."
	".$hidden[20]."
	</section>
	
	";	
	
	 return $content ;
} #sub articles_bar4 

#/*—————————————— articles_bar5 => Utilitaires ——————————————*/
sub articles_bar5 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my @hidden = ('0') x 40;

	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 

#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";
	
	#cat_5 Paramètrage
	my $content .= "
	
  	<section id='version' class='main-section'>
    <header class='header'><h3>Gestion des versions</h3><a class='aperso' href='#top'>#back to top</a></header><hr class='hrperso'>
	
	<section id='timeline' class='timeline-outer'>
   
      <div class='row'>
        <div class='col s12 m12 l12'>
          <ul class='timeline'>
            
            <li class='event' data-date='2015/Present'>
				<h3>Juillet 2022 Version 1.1</h3>
              <p>Version modifiée par picsou83 (<a href='https://github.com/picsou83/compta.libremen.com/wiki/Roadmap'>https://github.com/picsou83/compta.libremen.com/wiki/Roadmap</a>) </p>
            </li>
           
            
            
            <li class='event' data-date='2010/2012'>
            <h3>Mars 2021 Version 1.0</h3>
            <p>Version initiale de Vincent Veyron - Aôut 2016 (<a href='https://compta.libremen.com/'>https://compta.libremen.com/</a>) </p>
            </li>
            
          </ul>
        </div>
      </div>
    ".$hidden[24]."
	".$hidden[20]."
	</section>
	
	</section>
	";	
	
	 return $content ;
} #sub articles_bar5 

#/*—————————————— Formulaire documentation ——————————————*/
sub forms_documentation {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content  ) ;
	my @hidden = ('0') x 40;
	my $href_cat = 'href="/'.$r->pnotes('session')->{racine}.'/"> '; 
	my $href_cat1 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat1=1"> '; 
    my $href_cat2 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat2=1"> '; 
    my $href_cat3 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat3=1"> '; 
    my $href_cat4 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat4=1"> '; 
    my $href_cat5 = 'href="/'.$r->pnotes('session')->{racine}.'/?cat5=1"> '; 

	#checked par défault 
    unless (defined $args->{cat1} || defined $args->{cat2} || defined $args->{cat3} || defined $args->{cat4} || defined $args->{cat5}) {$args->{cat1} = 1; $args->{cat2} = 1; $args->{cat3} = 1; $args->{cat4} = 1; $args->{cat5} = 1;}


#####################################       
# Menu sidebar documentation		#
#####################################  
	$hidden[21] = "<div><a class='label grey' ".$href_cat1."Premiers pas</a><div class='pull-right'>";
	$hidden[22] = "<div><a class='label blue' ".$href_cat2."Courant</a><div class='pull-right'>";
	$hidden[23] = "<div><a class='label blue' ".$href_cat3."Utilitaires</a><div class='pull-right'>";
	$hidden[24] = "<div><a class='label blue' ".$href_cat4."Exercice Comptable</a><div class='pull-right'>";
	$hidden[25] = "<div><a class='label blue' ".$href_cat5."Paramètrage</a><div class='pull-right'>";
	$hidden[20] = "
		<a class='label grey' ".$href_cat1."Premiers pas</a> 
		<a class='label blue' ".$href_cat2."Courant</a> 
		<a class='label green' ".$href_cat3."Utilitaires</a> 
		<a class='label cyan' ".$href_cat4."Exercice Comptable</a> 
		<a class='label yellow' ".$href_cat5."Paramètrage</a> 
		<a class='label red' ".$href_cat."Toutes</a>        
		</div>";
		
	if (defined $args->{cat1} && $args->{cat1} eq 1) {$hidden[11] = side_bar_1($r) } else {$hidden[11] = '';}
	if (defined $args->{cat2} && $args->{cat2} eq 1) {$hidden[12] = side_bar_2() } else {$hidden[12] = '';}
	if (defined $args->{cat3} && $args->{cat3} eq 1) {$hidden[13] = side_bar_3() } else {$hidden[13] = '';}
	if (defined $args->{cat4} && $args->{cat4} eq 1) {$hidden[14] = side_bar_4() } else {$hidden[14] = '';}
	if (defined $args->{cat5} && $args->{cat5} eq 1) {$hidden[15] = side_bar_5() } else {$hidden[15] = '';}
  
  	#fonction javascript scroll menu
	my $side_bar .= '
	<script>

	window.addEventListener("load", () => {
	
	const sections = Array.from(document.querySelectorAll("section[id]"));
	
	var observer = new IntersectionObserver(function (entries) {

			entries.forEach(entry => {
				const section = entry.target;
				const sectionId = section.id;
				const sectionLink = document.querySelector(`a[href="#${sectionId}"]`);
				
				var intersecting = typeof entry.isIntersecting === \'boolean\' ?
                entry.isIntersecting : (entry.intersectionRatio > 0)
                sectionLink && sectionLink.classList.toggle(\'active\', intersecting)
			//sectionLink.parentElement.classList.add(\'active\');
			});
		
		}, {
            root: null,
            rootMargin: \'-150px 0px -150px 0px\',
			threshold: [0, 0.25, 0.75, 1]
        })
        
	sections && sections.forEach(section => observer.observe(section));
	
	});

	</script>' ;
	
	my $autofocus = 'autofocus';
	
	if ((defined $args->{menu02} && $args->{menu02} eq 1) || 
		(defined $args->{menu03} && $args->{menu03} eq 1) ||
		(defined $args->{menu04} && $args->{menu04} eq 1) ||
		(defined $args->{menu05} && $args->{menu05} eq 1) ||
		(defined $args->{menu06} && $args->{menu06} eq 1) ||
		(defined $args->{menu07} && $args->{menu07} eq 1) ||
		(defined $args->{menu08} && $args->{menu08} eq 1) || 
		(defined $args->{menu09} && $args->{menu09} eq 1) || 
		(defined $args->{menu10} && $args->{menu10} eq 1) ||
		(defined $args->{menu11} && $args->{menu11} eq 1) ||
		(defined $args->{menu12} && $args->{menu12} eq 1) ||
		(defined $args->{ecriture_recurrente}) 			||
		(defined $args->{saisie_rapide}) 			||
		(defined $args->{importer} && $args->{importer} =~ /^[45]$/) ||
		(defined $args->{ocr}) 			||
		(defined $args->{search}) 			||
		(defined $args->{interet_cca}) 	
		) {$autofocus = '';} else {$autofocus = 'autofocus';}
	

	#class='docs-sidebar'
	$side_bar .= "
    <div class='sidebar'><nav class='section-nav'><ul class='nav' style='padding: 0px; margin-top: 5px; list-style-type: none;'>
	".$hidden[11]."
	".$hidden[12]."
	".$hidden[13]."
	".$hidden[14]."
	".$hidden[15]."

	</nav></ul></nav></div>
    <main class='menu-contenu' id='main-doc'>    
    <div style='position: sticky; top: 64px;height: 45px;width: 100%;background-color : white;'>
    <input style='width: 100%;' class='login-text' type='text' id='Search' onkeyup='searchFunction2()'
	placeholder='Saisissez le terme de recherche..' title='Rechercher' ".$autofocus." >	
	</div>
	
	<div style='position: sticky; top: 100px; background-color: #fff;     text-align: center; padding-top: 5px;
    padding-bottom: 1%;'>
	".$hidden[20]."
	
	<div class='posts'>
    
    <!-- A single blog post -->
    "; 
		
	if (defined $args->{cat1} && $args->{cat1} eq 1) {$hidden[1] = articles_bar1( $r, $args )} else {$hidden[1] = '';}
	if (defined $args->{cat2} && $args->{cat2} eq 1) {$hidden[2] = articles_bar2( $r, $args )} else {$hidden[2] = '';}
	if (defined $args->{cat3} && $args->{cat3} eq 1) {$hidden[3] = articles_bar3( $r, $args )} else {$hidden[3] = '';}
	if (defined $args->{cat4} && $args->{cat4} eq 1) {$hidden[4] = articles_bar4( $r, $args )} else {$hidden[4] = '';}
	if (defined $args->{cat5} && $args->{cat5} eq 1) {$hidden[5] = articles_bar5( $r, $args )} else {$hidden[5] = '';}
	
	my $documentation .= '</div><div class="flex">' . $side_bar . $hidden[1] . $hidden[2] . $hidden[3] . $hidden[4] . $hidden[5] . '</main></div>' ;
				
	$content .= $documentation;

    return $content ;
    ############## MISE EN FORME FIN ##############
    
} #sub forms_documentation 

#/*—————————————— Vérification BDD && update	——————————————*/
sub verif_bdd_update {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	#Requête all tables and all Columns
	#'data_type' => 'integer',
    #'position' => 1,
    #'table_name' => 'compta_client',
    #'max_length' => 32,
    #'is_nullable' => 'NO',
    #'table_schema' => 'public',
    #'column_name' => 'id_client',
    #'default_value' => 'nextval(\'compta_client_id_client_seq\'::regclass)'
	$sql = '
		select table_schema, table_name, ordinal_position as position, column_name, data_type,
		case when character_maximum_length is not null
		then character_maximum_length 
		else numeric_precision end as max_length,
		is_nullable, 
		column_default as default_value
		from information_schema.columns
		where table_schema not in (\'information_schema\', \'pg_catalog\')
		order by table_schema, 
        table_name,
        ordinal_position 
    ' ;

	my $array_all_bdd = $dbh->selectall_arrayref( $sql, { Slice => { } }) ;
	
	# Ajouter la catégorie 'Temp' (si elle n'existe pas déjà)
	my $insert_sql = 'INSERT INTO tbldocuments_categorie (libelle_cat_doc, id_client) VALUES (?, ?) ON CONFLICT DO NOTHING';
	eval { $dbh->do($insert_sql, undef, ('Temp', $r->pnotes('session')->{id_client})) };
	
	#ajout colonne immobilier suite MAJ 1.109
	my @compta_client_immobilier = grep { $_->{table_name} eq 'compta_client' && $_->{column_name} eq 'immobilier' } @{$array_all_bdd};
    if (!@compta_client_immobilier) {
	$sql = 'ALTER TABLE compta_client ADD COLUMN IF NOT EXISTS "immobilier" BOOLEAN NOT NULL DEFAULT FALSE';		
	eval { $dbh->do( $sql, undef) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la colonne "immobilier" dans la table compta_client');
	}
	
	#ajout colonne courriel suite MAJ 1.109
	my @compta_client_courriel = grep { $_->{table_name} eq 'compta_client' && $_->{column_name} eq 'courriel' } @{$array_all_bdd};
    if (!@compta_client_courriel) {
	$sql = 'ALTER TABLE compta_client ADD COLUMN IF NOT EXISTS "courriel" TEXT';		
	eval { $dbh->do( $sql, undef) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la colonne "courriel" dans la table compta_client');
	}
	
	#ajout colonne module suite MAJ 1.103
	my @tblconfig_liste_module = grep { $_->{table_name} eq 'tblconfig_liste' && $_->{column_name} eq 'module' } @{$array_all_bdd};
    if (!@tblconfig_liste_module) {
	$sql = 'ALTER TABLE tblconfig_liste ADD COLUMN IF NOT EXISTS "module" TEXT';		
	eval { $dbh->do( $sql, undef) } ;
	$sql = 'UPDATE tblconfig_liste SET module = \'achats\' WHERE module is null' ;
	eval {$dbh->do( $sql, undef) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.103 : Ajout de la colonne "module" dans la table tblconfig_liste');
	}
	
	#ajout colonne "masquer" module suite MAJ 1.108
	my @tblconfig_liste_module2 = grep { $_->{table_name} eq 'tblconfig_liste' && $_->{column_name} eq 'masquer' } @{$array_all_bdd};
    if (!@tblconfig_liste_module2) {
	$sql = 'ALTER TABLE tblconfig_liste ADD COLUMN IF NOT EXISTS "masquer" BOOLEAN NOT NULL DEFAULT FALSE';		
	eval { $dbh->do( $sql, undef) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.108 : Ajout de la colonne "masquer" dans la table tblconfig_liste');
	}
	
	#ajout colonne multi suite MAJ 1.105
	my @tbldocuments_multi = grep { $_->{table_name} eq 'tbldocuments' && $_->{column_name} eq 'multi' } @{$array_all_bdd};
	if (!@tbldocuments_multi) {
		$sql = 'ALTER TABLE tbldocuments ADD COLUMN IF NOT EXISTS "multi" BOOLEAN NOT NULL DEFAULT FALSE';		
		eval { $dbh->do( $sql, undef) } ;
		$sql = 'UPDATE tbldocuments SET multi = \'t\' WHERE libelle_cat_doc = \'Inter-exercice\'' ;
		eval {$dbh->do( $sql, undef) } ;
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la colonne "multi" dans la table tbldocuments');
	}
	
	#ajout table tblndf_bareme suite MAJ 1.105
	my @tblndf_bareme = grep { $_->{table_name} eq 'tblndf_bareme' } @{$array_all_bdd};
	if (!@tblndf_bareme) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '1')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tblndf_bareme');
		}
	}
	
	#ajout table tblndf_frais suite MAJ 1.105
	my @tblndf_frais = grep { $_->{table_name} eq 'tblndf_frais' } @{$array_all_bdd};
	if (!@tblndf_frais) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '2')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tblndf_frais');
		}
	}
	
	#ajout table tblndf_bareme suite MAJ 1.105
	my @tblndf_vehicule = grep { $_->{table_name} eq 'tblndf_vehicule' } @{$array_all_bdd};
	if (!@tblndf_vehicule) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '3')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tblndf_vehicule');
		}
	}

	#ajout table tbljournal_type suite MAJ 1.105
	my @tbljournal_type = grep { $_->{table_name} eq 'tbljournal_type' } @{$array_all_bdd};
	if (!@tbljournal_type) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '4')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tbljournal_type');
		}
	}
	
	#ajout table tblndf suite MAJ 1.105
	my @tblndf = grep { $_->{table_name} eq 'tblndf' } @{$array_all_bdd};
	if (!@tblndf) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '5')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tblndf');
		}
	}
	
	#ajout table tbldocuments_tags suite MAJ 1.109
	my @tbldocuments_tags = grep { $_->{table_name} eq 'tbldocuments_tags' } @{$array_all_bdd};
	if (!@tbldocuments_tags) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '1')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tbldocuments_tags (Rubrique 1)');
		}
	}
	
	#ajout table tblimmobilier_logement suite MAJ 1.109
	my @tblimmobilier_logement = grep { $_->{table_name} eq 'tblimmobilier_logement' } @{$array_all_bdd};
	if (!@tblimmobilier_logement) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '2')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblimmobilier_logement (Rubrique 2)');
		}
	}
	
	#ajout table tblbilan suite MAJ 1.109
	my @tblbilan = grep { $_->{table_name} eq 'tblbilan' } @{$array_all_bdd};
	if (!@tblbilan) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '3')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblbilan (Rubrique 3)');
		}
	}
	
	#ajout table tblbilan_code suite MAJ 1.109
	my @tblbilan_code = grep { $_->{table_name} eq 'tblbilan_code' } @{$array_all_bdd};
	if (!@tblbilan_code) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '4')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblbilan_code (Rubrique 4)');
		}
	}
	
	#ajout table tblbilan_detail suite MAJ 1.109
	my @tblbilan_detail = grep { $_->{table_name} eq 'tblbilan_detail' } @{$array_all_bdd};
	if (!@tblbilan_detail) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '5')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblbilan_detail (Rubrique 5)');
		}
	}

	#ajout table tblimmobilier suite MAJ 1.109
	my @tblimmobilier = grep { $_->{table_name} eq 'tblimmobilier' } @{$array_all_bdd};
	if (!@tblimmobilier) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '6')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblimmobilier (Rubrique 6)');
		}
	}
	
	#ajout table tblimmobilier_locataire suite MAJ 1.109
	my @tblimmobilier_locataire = grep { $_->{table_name} eq 'tblimmobilier_locataire' } @{$array_all_bdd};
	if (!@tblimmobilier_locataire) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '7')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout de la table tblimmobilier_locataire (Rubrique 7)');
		}
	}
	
	#update Routines delete_account_data MAJ 1.109
	$sql = 'SELECT routine_definition FROM information_schema.routines WHERE routine_type=\'FUNCTION\' AND specific_schema=\'public\' AND routine_name LIKE \'delete_account_data\'' ;
	my $routine_definition = $dbh->selectall_arrayref( $sql, undef )->[0]->[0] ;
	
	if (!($routine_definition =~ /tblndf/ )) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.109.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '8')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Update Routines delete_account_data pour prise en compte des nouvelles tables (Rubrique 8)');
		}
	}
	
	# Vérification tblndf_id_client_fiscal_year_piece_compte_fkey MAJ 1.111
	my $sql_check_constraint = q{
		SELECT confupdtype
		FROM pg_constraint
		WHERE conname = 'tblndf_id_client_fiscal_year_piece_compte_fkey'
	};

	my $constraint_state = $dbh->selectrow_array($sql_check_constraint);
	
	# 'a' signifie NO ACTION pour confupdtype
	if (!defined $constraint_state || $constraint_state eq 'a') {
		eval {
			
			if (defined $constraint_state) {
				# La contrainte existe, on la supprime
				$dbh->do('ALTER TABLE tblndf DROP CONSTRAINT tblndf_id_client_fiscal_year_piece_compte_fkey');
			}
        
			# Ajouter la contrainte avec ON UPDATE CASCADE et ON DELETE CASCADE
			my $sql_add_constraint = q{
				ALTER TABLE tblndf ADD CONSTRAINT tblndf_id_client_fiscal_year_piece_compte_fkey 
				FOREIGN KEY (id_client, fiscal_year, piece_compte) 
				REFERENCES tblcompte(id_client, fiscal_year, numero_compte) 
				ON UPDATE CASCADE
			};
			$dbh->do($sql_add_constraint);

			};
		if ($@) {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Échec de la modification de la contrainte: '.$@.'');
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Modification de la contrainte tblndf_id_client_fiscal_year_piece_compte_fkey avec ON UPDATE CASCADE');
		}
	}

	# Vérification et ajout de l'extension fuzzystrmatch MAJ 1.108
	my $extension_name = 'fuzzystrmatch';
	my $extension_sql = 'CREATE EXTENSION IF NOT EXISTS ' . $extension_name . ';';
	
	my $sql_check_extension = q{SELECT extname FROM pg_extension WHERE extname = 'fuzzystrmatch'};
	my $extension_exists = $dbh->selectrow_array($sql_check_extension);

	if (!$extension_exists) {
		eval { $dbh->do($extension_sql) };
		if ($@) {
			# Gérer l'erreur si la création de l'extension échoue
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Ajout de l\'extension fuzzystrmatch dans la base de données suite MAJ 1.108');
		}
	}
	
	# Vérification et ajout de l'extension unaccent MAJ 1.108
	my $unaccent_extension_name = 'unaccent';
	my $unaccent_extension_sql = 'CREATE EXTENSION IF NOT EXISTS ' . $unaccent_extension_name . ';';

	my $sql_check_unaccent_extension = q{SELECT extname FROM pg_extension WHERE extname = ?};
	my $unaccent_extension_exists = $dbh->selectrow_array($sql_check_unaccent_extension, undef, $unaccent_extension_name);

	if (!$unaccent_extension_exists) {
		eval { $dbh->do($unaccent_extension_sql) };
		if ($@) {
			# Gérer l'erreur si la création de l'extension échoue
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Ajout de l\'extension unaccent dans la base de données suite MAJ 1.108');
		}
	}
	
	#ajout table tblndf_detail suite MAJ 1.105
	my @tblndf_detail = grep { $_->{table_name} eq 'tblndf_detail' } @{$array_all_bdd};
	if (!@tblndf_detail) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '6')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Ajout de la table tblndf');
		}
	}
	
	#ajout table tblsmtp suite MAJ 1.110
	my @tblsmtp = grep { $_->{table_name} eq 'tblsmtp' } @{$array_all_bdd};
	if (!@tblsmtp) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.110.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '1')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.110 : Ajout de la table tblsmtp');
		}
	}
	
	#ajout table tblmodel_template suite MAJ 1.111
	my @tblmodel_template = grep { $_->{table_name} eq 'tblmodel_template' } @{$array_all_bdd};
	if (!@tblmodel_template) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.111.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '1')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Ajout de la table tblmodel_template');
		}
	}

	# Suppression de la table tblemail_modele si elle existe suite MAJ 1.111
	my @tblemail_modele = grep { $_->{table_name} eq 'tblemail_modele' } @{$array_all_bdd};
	if (@tblemail_modele) {
		my $drop_sql = 'DROP TABLE IF EXISTS tblemail_modele';
		$dbh->do($drop_sql);
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Suppression de la table tblemail_modele');
	}

	# Suppression de la table tbltva_periode si elle existe suite MAJ 1.111
	my @tbltva_periode = grep { $_->{table_name} eq 'tbltva_periode' } @{$array_all_bdd};
	if (@tbltva_periode) {
		# Suppression de la contrainte compta_client_id_tva_periode_fkey de la table compta_client
		my $drop_constraint_sql = 'ALTER TABLE compta_client DROP CONSTRAINT IF EXISTS compta_client_id_tva_periode_fkey';
		$dbh->do($drop_constraint_sql);
		my $drop_sql = 'DROP TABLE IF EXISTS tbltva_periode';
		$dbh->do($drop_sql);
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Suppression de la table tbltva_periode');
	}
	
	# Suppression de la table tbltva_option si elle existe suite MAJ 1.111
	my @tbltva_option = grep { $_->{table_name} eq 'tbltva_option' } @{$array_all_bdd};
	if (@tbltva_option) {
		# Suppression de la contrainte compta_client_id_tva_option_fkey de la table compta_client
		my $drop_constraint_sql = 'ALTER TABLE compta_client DROP CONSTRAINT IF EXISTS compta_client_id_tva_option_fkey';
		$dbh->do($drop_constraint_sql);
		my $drop_sql = 'DROP TABLE IF EXISTS tbltva_option';
		$dbh->do($drop_sql);
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Suppression de la table tbltva_option');
	}
	
	#ajout table tbldocuments_historique suite MAJ 1.111
	my @tbldocuments_historique = grep { $_->{table_name} eq 'tbldocuments_historique' } @{$array_all_bdd};
	if (!@tbldocuments_historique) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.111.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '2')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.111 : Ajout de la table tbldocuments_historique');
		}
	}
	
	#update Routines record_staging pour retourner _id_entry suite MAJ 1.105
	$sql = 'SELECT routine_definition FROM information_schema.routines WHERE routine_type=\'FUNCTION\' AND specific_schema=\'public\' AND routine_name LIKE \'record_staging\'	' ;
	my $routine_def_record_staging = $dbh->selectall_arrayref( $sql, undef )->[0]->[0] ;
	
	if (!($routine_def_record_staging =~ /DECLARE/ )) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.105.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '7')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.105 : Update Routines record_staging pour retourner _id_entry');
		}
	}
	
	#Mise à jour de la routine record_staging pour s'assurer que token_id existe dans tbljournal_staging avant suppression => MAJ 1.112
	if (!($routine_def_record_staging =~ /IF NOT EXISTS/ )) {
		my $sql_file = '/var/www/html/Compta/base/bdd_maj/maj_1.112.sql';
		if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, '1')) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => Mise à jour de la routine record_staging pour s\'assurer que token_id existe dans tbljournal_staging avant suppression');
		}
	}

	#Ajout des formulaires 2033A 2033B 2033C Bilan et Compte de résultat suite MAJ 1.109
	my $tblbilan = Base::Site::bdd::get_tblbilan($dbh, $r);
	if (!@$tblbilan) {
	$args->{formulaire} = 'Bilan';
	$args->{import_file2} = '/var/www/html/Compta/base/bdd_maj/ALL_Bilan_11_03_2024.csv';
	$content .= Base::Site::bilan::process_import($r, $args);
	$args->{formulaire} = '2033A';
	$args->{import_file2} = '/var/www/html/Compta/base/bdd_maj/ALL_2033A_11_03_2024.csv';
	$content .= Base::Site::bilan::process_import($r, $args);
	$args->{formulaire} = '2033B';
	$args->{import_file2} = '/var/www/html/Compta/base/bdd_maj/ALL_2033B_11_03_2024.csv';
	$content .= Base::Site::bilan::process_import($r, $args);
	$args->{formulaire} = '2033C';
	$args->{import_file2} = '/var/www/html/Compta/base/bdd_maj/ALL_2033C_11_03_2024.csv';
	$content .= Base::Site::bilan::process_import($r, $args);
	$args->{formulaire} = 'Compte de résultat';
	$args->{import_file2} = '/var/www/html/Compta/base/bdd_maj/ALL_Resultat_11_03_2024.csv';
	$content .= Base::Site::bilan::process_import($r, $args);
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => MAJ 1.109 : Ajout des formulaires 2033A 2033B 2033C Bilan et Compte de résultat');
	}
	
	# Définition des répertoires et chemins des fichiers
	my $base_dir = $r->document_root() . '/Compta/base/documents';
	my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/' . $r->pnotes('session')->{fiscal_year} . '/';
	my $backup_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/backup/';
	# Vérification de l'existence des répertoires, sinon création
	mkpath($archive_dir) unless -d $archive_dir;
	mkpath($backup_dir) unless -d $backup_dir;
   
    return $content ;

} #sub verif_bdd_update 

#/*—————————————— Export PDF Complet——————————————*/
sub export_pdf2 {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	my $book2 ;
	
	############## Récupérations d'informations ##############
	#Requête des informations concernant les entrées du compte sélectionné
	$sql = '
	SELECT t1.id_entry, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, t2.libelle_compte, t1.id_facture as id_facture, t1.libelle as libelle, t1.documents1 as documents1, t1.documents2 as documents2, t1.debit/100::numeric as debit, t1.credit/100::numeric as credit, (sum(t1.debit) over())/100::numeric as total_debit, (sum(t1.credit) over())/100::numeric as total_credit, (sum(t1.credit-t1.debit) over (PARTITION BY t1.numero_compte ORDER BY date_ecriture, id_facture, libelle))/100::numeric as solde
	FROM tbljournal t1
	INNER JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.numero_compte = t2.numero_compte
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.numero_compte = ?
	ORDER BY date_ecriture, id_entry, id_line
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{select_compte}) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
		
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
	my $font_italic = $pdf->corefont('Georgia-Italic', -encode=>'latin1');
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
	my $cur_row = 9;
	my $cur_row_left = 6;
	my $cur_row_right = 6;
	my $cur_row_middle = -0.5;
	
	############## INFO TIERS GAUCHE PAGE 1 ##############
	# Libellé
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Libellé : Décompte Intérêts CC '.$r->pnotes('session')->{Exercice_fin_DMY}.'');
	$cur_row_left += 1;
	# Tiers
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Tiers : '.($result_set->[0]->{numero_compte}|| '').' - '.($result_set->[0]->{libelle_compte}|| '').'');
	$cur_row_left += 1;
	# Taux
	$text->translate($render_start_x, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Taux : '.$args->{taux}.' %');
	$cur_row_left += 1.75;

	$cur_row_left += 1;

	############## INFO TIERS GAUCHE PAGE 1 ##############
	
	##Mise en forme de la date dans Exercice_fin_YMD de %Y-%m-%d vers 29/02/2000
	my $date_fin_dmy = eval {Time::Piece->strptime($r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d")->dmy("/")};
    
    if (defined $args->{last31} && $args->{last31} eq 0) {
    #ajouter valeur array dans requête
	push @$result_set, {
		'total_credit' => '',
		'credit' => '',
		'id_entry' => 'LAST',
		'date_ecriture' => ''.$date_fin_dmy.'',
		'libelle_compte' => '',
		'numero_compte' => '',
		'documents1' => '',
		'libelle' => '',
		'documents2' => ' ',
		'debit' => '',
		'id_facture' => '',
		'total_debit' => '',
		'solde' => '',
		'libelle_journal' => ''
	};
	}
	my $count_result_set = scalar(@$result_set);	
	
	#split les resultats de la requête
	my $rows_count = $count_result_set; # NOMBRE LIGNE requête
	my $first_line_number = $rows_count;# NOMBRE LIGNE TABLEAU 1ERE PAGE
	my $second_line_number = 20;
	my $third_line_number = 20;
	my $numberofarrays = 17; # NOMBRE LIGNE TABLEAU AUTRES PAGES
	my $addpage = 0 ;
	
	if ($rows_count > 17 && $rows_count < 45){
		if ($rows_count > 17 && $rows_count < 25) {$first_line_number=24;$addpage=1;} else {$first_line_number=24;$numberofarrays=24;}
	} elsif ($rows_count > 44 && $rows_count < 49){
		$first_line_number=24;$numberofarrays=24;$second_line_number=24;$addpage=1;
	} elsif ($rows_count >= 49){
		$first_line_number=24;$numberofarrays=27;$second_line_number=27;$addpage=1;
	}

	my @del = splice @$result_set, $first_line_number; #ENLEVER first_line_number pour 1erpage
	my @new4 = split_by($numberofarrays,@del); #spliter par numberofarrays
	
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
		my $compte_units_count = 6;
		my $piece_units_count = 11.5;
		my $libelle_units_count = 40.5;
		my $debit_units_count = 7;
		my $credit_units_count = 7;
		my $solde_units_count = 7;
		my $nbjours_units_count = 7;
		my $interet_units_count = 7;
		my $depense_units_count = 1;
		my $bareme_units_count = 1;
		my $km_units_count = 1;
		my $montant_units_count = 1;
		
		#APPEL create_entete
		create_entete($r, $args, $pdf, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count);
		
		$cur_row ++;

		my $date_prec ;
		my $calcul_interet = 0;
		my $total_interet = 0;
		my $solde_prec = 0;
		my $date_nb_jour = 0;	
		my $date_en_cours = '';
		my $date_debut = Time::Piece->strptime($r->pnotes('session')->{Exercice_debut_YMD}, "%Y-%m-%d");
		my $date_fin = Time::Piece->strptime($r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d");
		my $date_n1 = Time::Piece->strptime($result_set->[1]->{date_ecriture}, "%d/%m/%Y");

		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper ' . Data::Dumper::Dumper(@$result_set) . ' ');
		
		############## RECUPERATION RESULTAT REQUETE ##############
		for (my $row = 0; $row < $first_line_number; $row ++) {
			
			my $book2 = $result_set->[$row];
		
			if ($book2 && defined $book2->{date_ecriture} && $book2->{date_ecriture} ne '') {
				$date_en_cours = Time::Piece->strptime($book2->{date_ecriture}, "%d/%m/%Y");
				if ($date_prec) {
					if ($date_en_cours eq $date_fin && $date_prec ne $date_fin){
						$date_nb_jour = ($date_en_cours - $date_prec)->days + 1;	
					} else {
						$date_nb_jour = ($date_en_cours - $date_prec)->days ;	
					}
				} else {
				$date_nb_jour = ($date_debut - $date_en_cours)->days ;
				}
				$calcul_interet = (($date_nb_jour * $solde_prec * $args->{taux})/100)/$args->{select_nbday};
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => calcul_interet '.$calcul_interet.' et $date_nb_jour'.$date_nb_jour.' et $_->{solde} '.$_->{solde}.' et taux '.$args->{taux}.'');
				if(($calcul_interet=~/\d/) && ($calcul_interet >= 0) && ($calcul_interet < 999999999999999)){
				$total_interet += $calcul_interet;
				}
				($calcul_interet = sprintf( "%.2f",$calcul_interet)) =~ s/\./\,/g;
				$calcul_interet =~ s/\B(?=(...)*$)/ /g ;
				$solde_prec = $book2->{solde} ;
				$date_prec = Time::Piece->strptime($book2->{date_ecriture}, "%d/%m/%Y");
			}

			my ($debit,$credit, $solde);
			
			if ($book2 && defined $book2->{debit} && $book2->{debit} ne '') {
			($debit = sprintf( "%.2f", $book2->{debit} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}

			if ($book2 && defined $book2->{credit} && $book2->{credit} ne '') {
			($credit = sprintf( "%.2f", $book2->{credit} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}

			if ($book2 && defined $book2->{solde} && $book2->{solde} ne '') {
			($solde = sprintf( "%.2f", $book2->{solde} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}
			
		Template_pdf_requete ($r, $args, $pdf, $book2, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count,
		$color_black, $line_width_basic, $line_width_bold, $cur_column_units_count,$debit,$credit, $solde,
		$row, $date_nb_jour, $calcul_interet );

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
		$cur_row = 5;
		
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

		#APPEL create_entete
		create_entete($r, $args, $pdf, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count);
		
		$cur_row ++;
		
		$rows_count = $second_line_number; # NOMBRE LIGNE TABLEAU

		############## RECUPERATION RESULTAT REQUETE ##############
		for (my $row = 0; $row < $rows_count; $row ++) {

			my $book2 = $_->[$row];
		
			if ($book2 && defined $book2->{date_ecriture} && $book2->{date_ecriture} ne '') {
			$date_en_cours = Time::Piece->strptime($book2->{date_ecriture}, "%d/%m/%Y");
				if ($date_prec) {
					if ($date_en_cours eq $date_fin && $date_prec ne $date_fin){
						$date_nb_jour = ($date_en_cours - $date_prec)->days + 1;	
					} else {
						$date_nb_jour = ($date_en_cours - $date_prec)->days ;	
					}
				} else {
				$date_nb_jour = ($date_debut - $date_en_cours)->days ;
				}
			$calcul_interet = (($date_nb_jour * $solde_prec * $args->{taux})/100)/$args->{select_nbday};
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => calcul_interet '.$calcul_interet.' et $date_nb_jour'.$date_nb_jour.' et $_->{solde} '.$_->{solde}.' et taux '.$args->{taux}.'');
			if(($calcul_interet=~/\d/) && ($calcul_interet >= 0) && ($calcul_interet < 999999999999999)){
			$total_interet += $calcul_interet;
			}
			($calcul_interet = sprintf( "%.2f",$calcul_interet)) =~ s/\./\,/g;
			$calcul_interet =~ s/\B(?=(...)*$)/ /g ;
			
			$solde_prec = $book2->{solde} ;
			$date_prec = Time::Piece->strptime($book2->{date_ecriture}, "%d/%m/%Y");
				
			}

			my ($debit,$credit, $solde);
			if ($book2 && defined $book2->{debit} && $book2->{debit} ne '') {
			($debit = sprintf( "%.2f", $book2->{debit} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}
			if ($book2 && defined $book2->{credit} && $book2->{credit} ne '') {
			($credit = sprintf( "%.2f", $book2->{credit} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}
			if ($book2 && defined $book2->{solde} && $book2->{solde} ne '') {
			($solde = sprintf( "%.2f", $book2->{solde} ) ) =~ s/\B(?=(...)*$)/ /g ;
			}
			
		Template_pdf_requete ($r, $args, $pdf, $book2, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count,
		$color_black, $line_width_basic, $line_width_bold, $cur_column_units_count,$debit,$credit, $solde,
		$row, $date_nb_jour, $calcul_interet );

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
	
	( my $total_montant = sprintf( "%.2f", ($total_interet || 0) ) ) =~ s/\B(?=(...)*$)/ /g ;
	
	# TOTAL1
	my $price_total_no_tax_label = 'TOTAL';
	$text->translate($render_start_x + ($date_units_count + $compte_units_count + $piece_units_count + $libelle_units_count + $debit_units_count + $credit_units_count + $solde_units_count ) * $unit_width + ($nbjours_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font_bold, $font_size_tableau);
	$text->text_center($price_total_no_tax_label);
	$text->translate($render_end_x, $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
	$text->font($font_bold, $font_size_tableau);
	$text->text_right(''.$total_montant.' ');
	$cur_row += 2;
	
	if ($addpage eq 1) {
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
	$cur_row = 7;
	}
	
	# APPEL create_ecri_compta
	create_ecri_compta ($r, $args, $pdf, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count,
		$color_black, $line_width_basic, $line_width_bold, $total_montant) ;
	
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

#/*—————————————— Fonction split array ——————————————*/
sub split_by {
	my ($num, @arr) = @_;
	my @sub_arrays;

	while (@arr) {
		push(@sub_arrays, [splice @arr, 0, $num]);
	}

	return @sub_arrays;
}#sub split_by

#/*—————————————— Modéle page ——————————————*/
sub _add_pdf_page {
	# définition des variables
	my ( $r, $args, $pdf ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper($args) . ' ');

    ############## Récupérations d'informations ##############
	#Requête des informations concernant la note de frais
	#Requête des informations concernant les entrées du compte sélectionné
	$sql = '
	SELECT t1.id_entry, t1.date_ecriture, t1.libelle_journal, t1.numero_compte, t1.id_facture as id_facture, t1.libelle as libelle, t1.documents1 as documents1, t1.documents2 as documents2, t1.debit/100::numeric as debit, t1.credit/100::numeric as credit, (sum(t1.debit) over())/100::numeric as total_debit, (sum(t1.credit) over())/100::numeric as total_credit, (sum(t1.credit-t1.debit) over (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle))/100::numeric as solde
	FROM tbljournal t1
	WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.numero_compte = ?
	ORDER BY date_ecriture, id_entry, id_line
	' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{select_compte}) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;
	my $count_result_set = scalar(@$result_set);
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
	my $font_italic = $pdf->corefont('Georgia-Italic', -encode=>'latin1');
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
	$gfx->move($render_start_x+280, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$gfx->hline($render_end_x-280);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 1.5;
	# Titre
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font_bold, 20);
	$text->text_center('Calcul des Intérêts');
	$cur_row_middle += 1;
	# Titre piece_ref
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font, 10);
	$text->text_center('Du '.$r->pnotes('session')->{Exercice_debut_DMY}.' au '.$r->pnotes('session')->{Exercice_fin_DMY}.' ');
	$cur_row_middle += 0.25;
	# Top thick line
	$gfx->move($render_start_x+280, $render_start_y-$unit_height * $cur_row_middle);
	$gfx->hline($render_end_x-280);
	$gfx->linewidth(2);
	$gfx->stroke;
	$cur_row_middle += 1;
	# Com
	$text->translate(421, $render_start_y-$unit_height * $cur_row_middle + $text_bottom_padding);
	$text->font($font_italic, 8);
	$text->text_center('Montant exprimé en euros');
	
	############## TITRE MIDDLE ##############

	############## INFO SOCIETE DROITE ##############
	# piece_date et id_facture
	$text->translate($render_start_x + 86.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Date : '.$r->pnotes('session')->{Exercice_fin_DMY}.'');
	$cur_row_right += 1;
	$text->translate($render_start_x + 86.5 * $unit_width, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text('Pièce: '.($args->{numero_piece} || '').'');
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

#/*—————————————— Modéle entête ——————————————*/
sub create_entete {
	# définition des variables
	my ($r, $args, $pdf, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count) = @_ ;
		
		#espace en tête
		my $cur_column_units_count = 0;

		############## ENTÊTE TABLEAU ##############
		# Date
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($date_units_count * $unit_width/3), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text('Date');
		$cur_column_units_count += $date_units_count;
		# Compte
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($compte_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Compte');
		$cur_column_units_count += $compte_units_count;
		# Pièce
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($piece_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Pièce');
		$cur_column_units_count += $piece_units_count;
		# Libellé
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($libelle_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Libellé');
		$cur_column_units_count += $libelle_units_count;
		# Débit
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($debit_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Débit');
		$cur_column_units_count += $debit_units_count;
		# Crédit
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($credit_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Crédit');
		$cur_column_units_count += $credit_units_count;
		# Solde
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($solde_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Solde');
		$cur_column_units_count += $solde_units_count;
		# Nb Jours
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($nbjours_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Nb Jours');
		$cur_column_units_count += $nbjours_units_count;
		# Intérêts
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($interet_units_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Intérêts');
		$cur_column_units_count = 0;
		############## ENTÊTE TABLEAU ##############
    
} #Create_entete {

#/*—————————————— Modéle entête ——————————————*/
sub create_ecri_compta {
	# définition des variables
	my ($r, $args, $pdf, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count,
		$color_black, $line_width_basic, $line_width_bold, $total_montant ) = @_ ;
	
	############## SECTION FORMULAIRE ECRITURE COMPTA ##############
		#espace en tête
		my $section_start = 2;
		my $section_form = 55;
		my $section_form_case = 6;
		my $section_form_description = 35;
		my $section_form_taux = 7;
		my $section_form_montant = 7;
		my $section_dummy = 16;
		my $section_compta = 25;
		my $section_compta_compte = 8;
		my $section_compta_debit = 8;
		my $section_compta_credit = 8;
		my $section_end = 2;
		
		# section_form
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form * $unit_width/2), $render_start_y-$unit_height * ($cur_row -0.15) + $text_bottom_padding);
		$text->font($font_italic, $font_size_default);
		$text->text_center('Formulaire 2777');
		# Ligne 1 TOP trait section_form
		$gfx->rectxy($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form) * $unit_width, $render_start_y-$unit_height * ($cur_row + 1));
		$gfx->fillcolor('# eee');
		$gfx->fill;
		$gfx->move($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form) * $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		# section_compta
		$text->translate($render_start_x + ($section_start + $section_form + $section_dummy) * $unit_width + ($section_compta * $unit_width/2) , $render_start_y-$unit_height * ($cur_row -0.15) + $text_bottom_padding);
		$text->font($font_italic, $font_size_default);
		$text->text_center('Écritures comptables correspondantes');
		# Ligne 1 TOP trait section_compta
		$gfx->rectxy($render_start_x + ($section_start + $section_form + $section_dummy) * $unit_width, $render_start_y-$unit_height * $cur_row,
		$render_start_x + + ($section_start + $section_form + $section_dummy + $section_compta)* $unit_width, $render_start_y-$unit_height * ($cur_row + 1));
		$gfx->fillcolor('# eee');
		$gfx->fill;
		$gfx->move($render_start_x + ($section_start + $section_form + $section_dummy) * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form + $section_dummy + $section_compta)* $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		
		$cur_row += 1;
		
		#$section_form_case
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form_case * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Case');
		#$section_form_description
		$text->translate($render_start_x + ($section_start + $section_form_case ) * $unit_width + ($section_form_description * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Description');
		#section_form_taux
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description ) * $unit_width + ($section_form_taux * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Taux');
		#section_form_montant
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width + ($section_form_montant * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Montant');
		#section_compta_compte
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy) * $unit_width + ($section_compta_compte * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Compte');
		#section_compta_debit
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy+ $section_compta_compte) * $unit_width + ($section_compta_debit * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Débit');
		#section_compta_credit
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy+ $section_compta_compte + $section_compta_debit) * $unit_width + ($section_compta_credit * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_default);
		$text->text_center('Crédit');
		
		# Ligne 2 TOP trait section_form
		$gfx->move($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form) * $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		# Ligne 2 TOP trait section_compta
		$gfx->move($render_start_x + ($section_start + $section_form + $section_dummy) * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form + $section_dummy + $section_compta)* $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		
		$cur_row += 1;
		
 		#Line fond gris
		$gfx->rectxy($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form) * $unit_width, $render_start_y-$unit_height * ($cur_row + 1));
		$gfx->fillcolor('# eee');
		$gfx->fill;
		#section_form_case Line
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form_case * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('AB');
		#section_form_description Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 0.9)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case ) * $unit_width + (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text('Intérêts, arrérages et produits de toute nature');
		#section_form_taux Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 0.9)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description ) * $unit_width + (($section_form_taux -1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('12,80%');
		#section_form_montant Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 0.9)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width + (($section_form_montant-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{ab}.'');
		#section_compta_compte Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 0.9)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy) * $unit_width + ($section_compta_compte * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('455100');
		#section_compta_debit Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 0.9)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width + (($section_compta_debit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('0,00');
		#section_compta_credit Line
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width + (($section_compta_credit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{total_c455}.'');
		
		$cur_row += 1;
		
		#section_form_case Line
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form_case * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('QG');
		#section_form_description Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case ) * $unit_width + (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text('Contribution sociale');
		#section_form_taux Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description ) * $unit_width + (($section_form_taux -1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('9,20%');
		#section_form_montant Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width + (($section_form_montant-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{qg}.'');
		#section_compta_compte Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy) * $unit_width + ($section_compta_compte * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('442500');
		#section_compta_debit Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width + (($section_compta_debit -1)* $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('0,00');
		#section_compta_credit Line
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width + (($section_compta_credit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{total_2777}.'');
		
		$cur_row += 1;
		
		#Line fond gris
		$gfx->rectxy($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form) * $unit_width, $render_start_y-$unit_height * ($cur_row + 1));
		$gfx->fillcolor('# eee');
		$gfx->fill;
 
		#section_form_case Line
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form_case * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('QH');
		#section_form_description Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case ) * $unit_width + (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text('Solidarité');
		#section_form_taux Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description ) * $unit_width + (($section_form_taux -1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('7,50%');
		#section_form_montant Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width + (($section_form_montant-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{qh}.'');
		#section_compta_compte Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy) * $unit_width + ($section_compta_compte * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('661500');
		#section_compta_debit Line
		$gfx->poly(
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte) * $unit_width + (($section_compta_debit -1)* $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{total_interet}.'');
		#section_compta_credit Line
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width + (($section_compta_credit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('0,00');	
		
		# Ligne 2 TOP trait section_compta
		$gfx->move($render_start_x + ($section_start + $section_form + $section_dummy) * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form + $section_dummy + $section_compta)* $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		
		$cur_row += 1;
		
		#section_form_case Line
		$text->translate($render_start_x + ($section_start ) * $unit_width + ($section_form_case * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_center('AAI');
		#section_form_description Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case ) * $unit_width + (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text('Contribution remboursement dette sociale');
		#section_form_taux Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description ) * $unit_width + (($section_form_taux -1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right('0,50%');
		#section_form_montant Line
		$gfx->poly(
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * $cur_row,
		$render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width,
		$render_start_y-$unit_height * ($cur_row - 1)
		);
		$gfx->linewidth(1.5);
		$gfx->strokecolor('# ccc');
		$gfx->stroke;
		$text->translate($render_start_x + ($section_start + $section_form_case + $section_form_description + $section_form_taux) * $unit_width + (($section_form_montant-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font, $font_size_tableau);
		$text->text_right(''.$args->{aai}.'');
		
		# Ligne 2 TOP trait section_form
		$gfx->move($render_start_x + $section_start * $unit_width, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_start_x + ($section_start + $section_form) * $unit_width);
		$gfx->linewidth($line_width_bold);
		$gfx->strokecolor($color_black);
		$gfx->stroke;		
		
		#section_compta_compte
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy) * $unit_width + ($section_compta_compte * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_default);
		$text->text_center('TOTAL');
		#section_compta_debit Line
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte ) * $unit_width + (($section_compta_debit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_right(''.$total_montant.'');
		#section_compta_credit Line
		$text->translate($render_start_x + ($section_start + 1 + $section_form + $section_dummy + $section_compta_compte + $section_compta_debit) * $unit_width + (($section_compta_credit-1) * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_right(''.$total_montant.'');	

		$cur_row += 1;
		
		# TOTAL section_form_description
		$text->translate($render_start_x + ($section_start + $section_form_case + + $section_form_description ) * $unit_width - (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_default);
		$text->text_right('TOTAL');
		# TOTAL section_form_taux
		$text->translate($render_start_x + ($section_start + $section_form_case + + $section_form_description + $section_form_taux ) * $unit_width - (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_default);
		$text->text_right('30%');
		# TOTAL section_form_montant
		$text->translate($render_start_x + ($section_start + $section_form_case + + $section_form_description + $section_form_taux + $section_form_montant ) * $unit_width - (1 * $unit_width), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_default);
		$text->text_right(''.$args->{total_2777}.'');

		############## SECTION FORMULAIRE ECRITURE COMPTA##############	
}

#/*—————————————— Modéle entête ——————————————*/
sub Template_pdf_requete {
	# définition des variables
	my ($r, $args, $pdf, $book2, $page, $gfx, $text, $cur_row, $font, $font_bold, $font_italic, $render_start_x, 
		$render_start_y, $render_end_x, $render_end_y, $unit_width, $unit_height , $text_left_padding, $text_bottom_padding,
		$font_size_default, $font_size_tableau, $date_units_count, $compte_units_count, $piece_units_count,
		$libelle_units_count, $debit_units_count, $credit_units_count, $solde_units_count, $nbjours_units_count,
		$interet_units_count, $depense_units_count, $bareme_units_count, $km_units_count, $montant_units_count,
		$color_black, $line_width_basic, $line_width_bold, $cur_column_units_count,$debit,$credit, $solde,
		$row, $date_nb_jour, $calcul_interet ) = @_ ;
		
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
			if ($book2->{date_ecriture}) {
				$text->translate(
				  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text($book2->{date_ecriture});
			}
			$cur_column_units_count += $date_units_count;

			# Compte
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book2->{numero_compte}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($compte_units_count * $unit_width/2.5) + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_center($book2->{numero_compte});
			}
			$cur_column_units_count += $compte_units_count;
			
			# Pièce
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book2->{id_facture}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book2->{id_facture} || ''), 0, 56 ));
			}
			$cur_column_units_count += $piece_units_count;
			

			# Libellé
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width ,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book2->{libelle}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr($book2->{libelle}, 0, 59));
			}
			$cur_column_units_count += $libelle_units_count;

			# Débit
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($debit) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($debit_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($debit);
			}
			$cur_column_units_count += $debit_units_count;
			  
			# Crédit
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($credit) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($credit_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($credit);
			}
			$cur_column_units_count += $credit_units_count;
			
			# Solde
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($solde) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($solde_units_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($solde);
			}
			$cur_column_units_count += $solde_units_count;
			
			# Nb jours
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book2->{date_ecriture}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + (($nbjours_units_count -1) * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right($date_nb_jour);
			}
			$cur_column_units_count += $nbjours_units_count;

			# Intérêts
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth(1.5);
			$gfx->strokecolor('# ccc');
			$gfx->stroke;
			if ($book2->{date_ecriture}) {
				$text->translate(
				$render_end_x,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text_right(''.$calcul_interet.' ');
			}
			$cur_column_units_count = 0;	
	
	
}

#/*—————————————— Menu 	——————————————*/
sub display_menu {

   my ( $r, $args ) = @_ ;
    
	unless ( defined $args->{tag2} || defined $args->{tag3} || defined $args->{tag4} || defined $args->{tag5} ) {
		$args->{tag1} = '' ;
	} 	
 	
#########################################	
#Filtrage du Menu - Début				#
#########################################		
	my $tag1_link = '<a class=' . ( (defined $args->{tag1} ) ? 'selecteditem' : 'nav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/?tag1" style="margin-left: 3ch;">Premiers pas</a>' ;
	my $tag2_link = '<a class=' . ( (defined $args->{tag2} ) ? 'selecteditem' : 'nav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/?tag2" style="margin-left: 3ch;">Courant</a>' ;
	my $tag3_link = '<a class=' . ( (defined $args->{tag3} ) ? 'selecteditem' : 'nav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/?tag3" style="margin-left: 3ch;">Utilitaires</a>' ;
	my $tag4_link = '<a class=' . ( (defined $args->{tag4} ) ? 'selecteditem' : 'nav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/?tag4" style="margin-left: 3ch;">Paramétrage</a>' ;
	my $tag5_link = '<a class=' . ( (defined $args->{tag5} ) ? 'selecteditem' : 'nav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/?tag5" style="margin-left: 3ch;">Fin d\'exercice</a>' ;
	my $content .= '<div class="menu"><li style="list-style: none; margin: 0;">' . $tag1_link . $tag2_link . $tag3_link . $tag4_link . $tag5_link .'</li></div>' ;

#########################################	
#Filtrage du Menu - Fin					#
#########################################
    
    return $content ;

} #sub display_menu_formulaire 

#/*—————————————— Fonction OCR ——————————————*/
sub function_ocr {
    my ($dbh, $r, $args) = @_;

    my $message = '';  # Initialize the message variable
    my @result_array;

    my $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?';
    my $array_of_documents = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{docs2});

    my $base_dir = $r->document_root() . '/Compta/base/documents/';
    my $archive_dir = $base_dir . $r->pnotes('session')->{id_client} . '/' . $array_of_documents->[0]->{fiscal_year} . '/';
    my $pdf_file = $archive_dir . $args->{docs2};
	
	# Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields = Base::Site::util::create_hidden_fields_form($args, [], [], []);

    # Détection du type de document
    my $doc_type = detect_document_type($pdf_file);
    
    if ($doc_type eq 'facture') {
        return process_invoice_pdf($dbh, $r, $args, $pdf_file);
    } elsif ($doc_type eq 'releve_bancaire') {
        return process_bank_statement_pdf($dbh, $r, $args, $pdf_file);
    } else {
        $message = 'Type de document non reconnu. Documents supportés: relevés bancaires (Crédit Agricole), factures PDF<br>';
        return ($message, \@result_array);
    }
}

# Detection automatique du type de document
sub detect_document_type {
    my ($pdf_file) = @_;
    
    my $pdf_text = `pdftotext -layout "$pdf_file" - 2>/dev/null`;
    
    # Detection facture
    if ($pdf_text =~ /(facture|invoice|factuur|rechnung)/i) {
        return 'facture';
    }
    
    # Detection releve bancaire
    if ($pdf_text =~ /(crédit agricole|relevé de compte|bank statement)/i) {
        return 'releve_bancaire';
    }
    
    return 'inconnu';
}

# Traitement des factures PDF
sub process_invoice_pdf {
    my ($dbh, $r, $args, $pdf_file) = @_;
    
    my $message = '';
    my @result_array;
    
    my $pdf_text = `pdftotext -layout "$pdf_file" - 2>/dev/null`;
    my @lines = split(/\n/, $pdf_text);
    
    # Extraction des champs facture
    my $facture_data = extract_invoice_fields(\@lines);
    
    if ($facture_data->{montant_total} > 0) {
        my %line_data = (
            'date_operation' => $facture_data->{date_facture},
            'date_valeur' => $facture_data->{date_facture},
            'libelle' => $facture_data->{fournisseur} . ' - Facture ' . $facture_data->{numero_facture},
            'debit' => $facture_data->{montant_total},
            'credit' => 0,
            'type' => 'facture',
            'details' => $facture_data
        );
        push @result_array, \%line_data;
        
        $message = 'Facture reconnue: ' . $facture_data->{fournisseur} . ' - Montant: ' . $facture_data->{montant_total} . ' EUR<br>';
    } else {
        $message = 'Facture détectée mais montant non trouvé<br>';
    }
    
    return ($message, \@result_array);
}

# Extraction des champs d'une facture
sub extract_invoice_fields {
    my ($lines_ref) = @_;
    
    my %data = (
        fournisseur => '',
        numero_facture => '',
        date_facture => '',
        montant_total => 0,
        montant_ht => 0,
        tva => 0
    );
    
    my $full_text = join(' ', @$lines_ref);
    
    # Extraction numero facture
    if ($full_text =~ /(facture|invoice)\s*[N°#]?\s*(\d+)/i) {
        $data{numero_facture} = $2;
    }
    
    # Extraction date (formats: DD/MM/YYYY, YYYY-MM-DD, etc.)
    if ($full_text =~ /(\d{2})[\/\.\-](\d{2})[\/\.\-](\d{4})/) {
        $data{date_facture} = "$3-$2-$1";  # Format ISO: YYYY-MM-DD
    } elsif ($full_text =~ /(\d{4})[\/\.\-](\d{2})[\/\.\-](\d{2})/) {
        $data{date_facture} = "$1-$2-$3";
    }
    
    # Extraction montant total (chercher patterns comme "Total TTC", "Montant total", etc.)
    if ($full_text =~ /(total\s+ttc|montant\s+total|total\s+facture).*?(\d{1,3}(?:\s?\d{3})*,\d{2})/i) {
        my $montant_str = $2;
        $montant_str =~ s/\s//g;
        $montant_str =~ s/,/./;
        $data{montant_total} = sprintf("%.2f", $montant_str);
    }
    
    # Extraction fournisseur (premiere ligne avec SIRET ou denomination)
    foreach my $line (@$lines_ref) {
        if ($line =~ /(SIRET|SIREN|RCS).*?(\d{9,14})/) {
            # Ligne precedente ou actuelle contient le nom du fournisseur
            $data{fournisseur} = extract_supplier_name($lines_ref, $line);
            last;
        }
    }
    
    return \%data;
}

# Extraction du nom du fournisseur
sub extract_supplier_name {
    my ($lines_ref, $siret_line) = @_;
    
    for (my $i = 0; $i < scalar(@$lines_ref); $i++) {
        if ($lines_ref->[$i] eq $siret_line && $i > 0) {
            # Retourner la ligne precedente comme nom de fournisseur
            my $nom = $lines_ref->[$i - 1];
            $nom =~ s/^\s+|\s+$//g;  # Trim
            return $nom if length($nom) > 2;
        }
    }
    
    return 'Fournisseur inconnu';
}

# Traitement des relevés bancaires (fonction originale extraite)
sub process_bank_statement_pdf {
    my ($dbh, $r, $args, $pdf_file) = @_;
    
    my $message = '';
    my @result_array;
    my $total_debit = 0;
    my $total_credit = 0;
    my $totdeb = 0;
    my $totcred = 0;
    my $credit_agricole_found = 0;
    my $date_arrete;
    my $annee;

    my $pdf_text = `pdftotext -layout "$pdf_file" -`;
    my @lines = split(/\n/, $pdf_text);

			foreach my $line (@lines) {
	
				$line = decode('utf8', $line);  # Décoder la chaîne en UTF-8
				
				if ($line =~ /CREDIT AGRICOLE/i) {$credit_agricole_found = 1;}

				if ($line =~ /Date d'arrêté : (\d{2}) ([^\s]+) (\d{4})/) {
					my $day = $1;
					my $month_str = $2;
					my $year = $3;

					my %month_map = (
						'Janvier' => '01', 'Février' => '02', 'Mars' => '03', 'Avril' => '04',
						'Mai' => '05', 'Juin' => '06', 'Juillet' => '07', 'Août' => '08',
						'Septembre' => '09', 'Octobre' => '10', 'Novembre' => '11', 'Décembre' => '12'
					);

					my $month = $month_map{$month_str};
					$date_arrete = sprintf("%04d-%02d-%02d", $year, $month, $day);
					$annee = $year;  # Affecter la valeur de l'année
					#$message .= "date arrêté : $date_arrete";
				} 

				if ($credit_agricole_found && $line =~ /^\s*((\d{2}\.\d{2}) (\d{2}\.\d{2}))\s+(.+?)\s+((?:\d+\s)?\d+\,\d+)\s+(\S+)\s*$/) {
				
					my $full_date = $1;
					my $date_operation = $2;
					my $date_valeur = $3;
					my $libelle = $4;
					my $montant_raw = $5;

					my ($jour_op, $mois_op) = split(/\./, $date_operation);
					my ($jour_val, $mois_val) = split(/\./, $date_valeur);
					$date_operation = $annee.'-'.$mois_op.'-'.$jour_op;
					$date_valeur = $annee.'-'.$mois_val.'-'.$jour_val;
					
					my $montant = $montant_raw;
					$montant =~ s/\s|,//g;  # Supprimer les espaces et les virgules
					$montant =~ s/\D//g;  # Supprimer tous les caractères non-numériques
					$montant = sprintf("%.2f", $montant / 100);  # Convertir le montant en nombre décimal avec deux décimales

					my $distance = index($line, $montant_raw) - index($line, $libelle);

					# Supprimer les espaces consécutifs supérieurs à 1 dans le libellé
					$libelle =~ s/\s{2,}/ /g;

					if ($libelle !~ /\Q$montant\E/ && length($libelle) <= 65 && index($montant_raw, substr($libelle, 0, 65)) == -1) {
						my ($debit, $credit) = $distance >= 65 && $distance <= 103 ? ($montant, 0) : (0, $montant);
						#$message .= 'Ligne: Date Opération: '.$date_operation.', Date Valeur: '.$date_valeur.', Libellé: '.$libelle.', Débit: '.$debit.', Crédit: '.$credit.'<br>';
                        my %line_data = (
						'date_operation' => $date_operation,
						'date_valeur' => $date_valeur,
						'libelle' => $libelle,
						'debit' => $debit,
						'credit' => $credit,
						);

					push @result_array, \%line_data; 
            
						$total_debit += $debit;
						$total_credit += $credit;
					}
				} elsif ($line =~ /\bTotal des opérations\s+(\d{1,3}(?:\s\d{3})*),(\d{2})\s+(\d{1,3}(?:\s\d{3})*),(\d{2})/) {
					
					$totdeb = $1 . $2;
					$totcred = $3 . $4;
					$totdeb =~ s/\s|,//g;  # Supprimer les espaces et les virgules
					$totdeb =~ s/\D//g;  # Supprimer tous les caractères non-numériques
					$totdeb = sprintf("%.2f", $totdeb / 100);  # Convertir le montant en nombre décimal avec deux décimales
					$totcred =~ s/\s|,//g;  # Supprimer les espaces et les virgules
					$totcred =~ s/\D//g;  # Supprimer tous les caractères non-numériques
					$totcred = sprintf("%.2f", $totcred / 100);  # Convertir le montant en nombre décimal avec deux décimales
					#$message .= 'Total Débit attendu: '.$totdeb.', Total Crédit attendu: '.$totcred.'<br>';
				}
			}

			$total_debit = sprintf("%.2f", $total_debit);  # Formater en nombre décimal avec deux décimales
			$total_credit = sprintf("%.2f", $total_credit);  # Formater en nombre décimal avec deux décimales
			#$message .= 'Total Débit: '.$total_debit.', Total Crédit: '.$total_credit.'<br>';

			if ($credit_agricole_found && $total_debit == $totdeb && $total_credit == $totcred && ($total_debit != 0 || $total_credit != 0)) {
   
			#$message .= 'Le document '.$args->{docs2} .' est un relevé Crédit Agricole.<br>
			#				 Les totaux sont en conformité et correspondent avec Total Débit: '.$totdeb.' et Total Crédit '.$totcred.'<br><br>';
				
			#my $message2 = 'Voulez-vous générer les écritures via la reconnaissance optique de caractères pour ce document ?' ;
			#my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'ocr', $args->{ocr}, $hidden_fields, 1);
			#$message .= $confirmation_message;	
					
			} else {
				$message .= 'Le document n\'est pas conforme. Voici les relevés pris en charge : Crédit Agricole <br>';
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Total Débit: '.$total_debit.', Total Crédit: '.$total_credit. ' ');
			}

    return ($message, \@result_array); # Return the message and array reference
}

sub fetch_data_with_increasing_levenshtein {
    my ($dbh, $r, $libelle, $debit, $credit) = @_;
    
    # Déclarations de variables
    my $max_retries = 18;                   # Nombre maximal de réessais pour la recherche Levenshtein
    my $max_retries_montant = 3;           # Nombre maximal de réessais pour la recherche sur le montant
    my $def_levenshtein_increment = 4;     # Incrément pour le niveau de Levenshtein
    my $def_levenshtein = 4;               # Niveau de Levenshtein par défaut
    my @words = split(/\s+/, $libelle);    # Diviser le libellé en mots individuels
    my $debit_condition = ($debit != 0) ? 1 : 0;      # Vérifier si le débit est non nul
    my $credit_condition = ($credit != 0) ? 1 : 0;    # Vérifier si le crédit est non nul
    my $montant = 0;
    if ($debit != 0 || $credit != 0) {
        $montant = ($debit != 0) ? $debit : $credit;  # Déterminer le montant en fonction du débit ou du crédit
    }

    # Initialisation des variables
    my $retries = 0;                       # Compteur de réessais
    my $resultat = [];                     # Résultats initiaux
    my $resultat_levenshtein = [];         # Résultats Levenshtein
    my $levenshtein_level = 0;             # Variable pour suivre le niveau de distance de Levenshtein
    my $correspondance_trouvee = 0;        # Indicateur de correspondance trouvée
    my $echec_levenshtein = 0;             # Niveau de Levenshtein auquel la recherche a échoué
    my $results = [];                      # Résultats de la requête SQL
    
    my $num_words = scalar @words;         # Nombre total de mots dans le libellé

	# Boucle principale pour essayer différentes combinaisons de mots et niveaux de Levenshtein
    for (my $i = $num_words; $i >= 1; $i--) {
		# Calculer les combinaisons de mots pour cette itération
        my @combinations;
        for (my $j = 0; $j <= $num_words - $i; $j++) {
            @combinations = @words[$j..$j+$i-1]; # Sélectionner les mots pour la combinaison
            #my $combinations_string = join(" AND ", map { "libelle ILIKE '%$_%'" } @combinations);
            my $combinations_string = join(" AND ", map { "unaccent(lower(libelle)) ILIKE unaccent(lower('%$_%'))" } @combinations);

			# Construire la requête SQL pour la recherche basée sur les combinaisons de mots
            my $sql = q{
                SELECT id_entry, numero_compte, date_ecriture, libelle, debit, credit, id_facture, id_paiement, libelle_journal, lettrage, documents1
                FROM tbljournal
                WHERE id_client = ?
                AND (} . $combinations_string . q{)
                ORDER BY CASE WHEN EXTRACT(YEAR FROM date_ecriture) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 0 ELSE 1 END,
                         ABS(date_ecriture - CURRENT_DATE),
                         date_ecriture
            };

            $results = $dbh->selectall_arrayref($sql, undef, ($r->pnotes('session')->{id_client}));
			
			# Vérifier si des résultats ont été trouvés
            if (@$results) {
				
				my $used_words = $i;
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Correspondance trouvée pour '.$libelle.' avec '.$used_words.' mots sur '.$num_words.' mots.');
				$correspondance_trouvee = 1;
				my $levenshtein_threshold = $def_levenshtein;
				
				# Boucle interne pour tester différents niveaux de Levenshtein
                while ($levenshtein_threshold <= $max_retries * $def_levenshtein_increment) {
                    my $retries_montant = 1;

                    my $sql = q{
                        SELECT id_entry, numero_compte, date_ecriture, libelle, debit, credit, id_facture, id_paiement, libelle_journal, lettrage, documents1
                        FROM tbljournal
                        WHERE id_client = ?
                        AND id_entry IN (
                        SELECT id_entry
                        FROM tbljournal
                        WHERE id_client = ?
                        AND (} . join(" OR ", map { "unaccent(lower(libelle)) ILIKE unaccent(lower('%$_%'))" } @words[0..$i-1]) . q{)
						} . ($retries_montant < $max_retries_montant ? 'AND (debit = ? OR credit = ?)' : '') . q{
						AND levenshtein(unaccent(lower(libelle))::text, unaccent(lower(?::text))::text) <= ?
                        AND SUBSTRING(numero_compte from 1 for 1) = '5'
                        AND (
							(? != 0 AND credit != 0) OR
							(? != 0 AND debit != 0)
						)
                        ORDER BY
                            CASE 
                                WHEN EXTRACT(YEAR FROM date_ecriture) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 0 
                                ELSE 1 
                            END, 
                            ABS(date_ecriture - CURRENT_DATE), 
                            date_ecriture
                        LIMIT 1
                        )
                        ORDER BY
                        CASE 
                            WHEN EXTRACT(YEAR FROM date_ecriture) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 0 
                            ELSE 1 
                        END, 
                        ABS(date_ecriture - CURRENT_DATE), 
                        date_ecriture;
                    };
                    
                    my @params = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{id_client});
                    push @params, ($montant, $montant) if $retries_montant < $max_retries_montant;
                    push @params, ($libelle, $levenshtein_threshold, $debit, $credit);

                    $resultat_levenshtein = $dbh->selectall_arrayref($sql, undef, @params);
				
				# Vérifier si des résultats ont été trouvés avec Levenshtein
                if (@$resultat_levenshtein) {
                    my $used_words = $i;
                    #Base::Site::logs::logEntry("#### DEBUG ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Correspondance avec Levenshtein trouvée pour '.$libelle.' avec '.$used_words.' mots sur '.$num_words.' mots. Niveau de Levenshtein : '.$levenshtein_threshold) if $r->pnotes('session')->{debug} eq 1;
                    $correspondance_trouvee = 1;
                    return $resultat_levenshtein;
                }

                    $levenshtein_threshold += $def_levenshtein_increment;
                    $retries_montant += 1;
                    $levenshtein_level = $levenshtein_threshold;
                }

                if (@$resultat_levenshtein) {
                    last;
                }
            } else {
            $echec_levenshtein = $levenshtein_level;  # Enregistrement du niveau de Levenshtein d'échec
			}
        }

        if (@$results) {
            last;
        }
    }

    if (@$resultat_levenshtein) {
        return $resultat_levenshtein;  # Retourne le résultat si trouvé via la vérification Levenshtein
    } else {
		#Aucun résultat trouvé 
        #Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Aucun résultat trouvé pour '.$libelle.' après '.$echec_levenshtein.' niveaux de Levenshtein.');
        #return undef;
        
        my $sql = q{
        SELECT id_entry, 
           CASE 
               WHEN SUBSTRING(numero_compte from 1 for 1) != '5' THEN '471000'
               ELSE numero_compte
           END as numero_compte,
           date_ecriture, 
           libelle, 
           debit, 
           credit, 
           id_facture,
           id_paiement,
           libelle_journal, 
           lettrage,
           documents1
    FROM tbljournal
    WHERE id_client = ?
    AND id_entry IN (
        SELECT id_entry
        FROM tbljournal
        WHERE id_client = ?
        AND SUBSTRING(numero_compte from 1 for 1) = '5'
        AND (
        (? != 0 AND credit != 0) OR
        (? != 0 AND debit != 0)
    )
        ORDER BY
            CASE 
                WHEN EXTRACT(YEAR FROM date_ecriture) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 0 
                ELSE 1 
            END, 
            ABS(date_ecriture - CURRENT_DATE), 
            date_ecriture
        LIMIT 1
    )
    ORDER BY
    CASE 
        WHEN EXTRACT(YEAR FROM date_ecriture) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 0 
        ELSE 1 
    END, 
    ABS(date_ecriture - CURRENT_DATE), 
    date_ecriture;   
    };
                    
    my $resultat_471 = $dbh->selectall_arrayref($sql, undef, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{id_client}, $debit, $credit);
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper(@$resultat_471) . ' ');

	return $resultat_471;			 
        
    }
}

# Traite différents fichiers CSV et génère un formulaire HTML à partir des données CSV
#$form_2 .= process_csv_and_generate_html_form($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $csv_data, $csv_type);   
sub process_csv_and_generate_html_form {
    my ($dbh, $r, $args, $array_of_documents, $bdd_compte4, $bdd_compte411, $bdd_compte401, $bdd_compte6, $bdd_compte7, $result_reglement_set, $hidden_fields_form1, $csv_data, $type) = @_;
	my ($debit, $credit, $form_2, $var_montant, $var_libelle, $var_date);
	
	# Récupère les paramètres de règlement pour un libellé spécifique.	
    my ($reglement_journal, $reglement_compte) = ('', '');
    my $parametres_reglements = Base::Site::bdd::get_parametres_reglements($dbh, $r);
    for my $row (@$parametres_reglements) {
        if ($row->{config_libelle} eq $args->{select_achats}) {
            ($reglement_journal, $reglement_compte) = ($row->{config_journal}, $row->{config_compte});
            last;
        }
    }
	
	my $seq_number = 1501; # Initialiser une variable pour le chiffre séquentiel
				
	# Définir les styles et les libellés des colonnes
	my %columnStylesAndLabels = (
	'Colonne01' => { 'style' => 'width: 0.3%; text-align: center;', 'label' => '&nbsp;' },
	'Colonne02' => { 'style' => 'width: 10%; text-align: center;', 'label' => 'Type' },
	'Colonne03' => { 'style' => 'width: 7%; text-align: center;', 'label' => 'Date' },
	'Colonne04' => { 'style' => 'width: 14%; text-align: center;', 'label' => 'Compte' },
	'Colonne05' => { 'style' => 'width: 14%; text-align: center;', 'label' => 'Destination' },
	'Colonne06' => { 'style' => 'width: 2%; display: grid; ', 'label' => '&nbsp;' },
	'Colonne07' => { 'style' => 'width: 9%; text-align: center;', 'label' => 'Pièce' },
	'Colonne08' => { 'style' => 'width: 16.3%; text-align: center;', 'label' => 'Libellé' },
	'Colonne09' => { 'style' => 'width: 6%; text-align: center;', 'label' => 'Dépense' },
	'Colonne10' => { 'style' => 'width: 6%; text-align: center;', 'label' => 'Recette' },
	'Colonne11' => { 'style' => 'width: 14%; text-align: center;', 'label' => 'Documents' },
	'Colonne12' => { 'style' => 'width: 3%; display: grid; ', 'label' => '&nbsp;' },
	'Colonne13' => { 'style' => 'width: 0.3%;', 'label' => '&nbsp;' }
	); 
	
	my $message_compta = '';
	if ($r->pnotes('session')->{type_compta} eq 'tresorerie') {
		$message_compta = '';
	} else {
		$message_compta = '<strong>Case à cocher Paiement comptant</strong> pour la création de deux écritures en une seule opération (lettrées automatiquement), la facture et son réglement.';
	}
	

	# Créer le code HTML pour l'en-tête du tableau
	$form_2 .= '
	<div class="Titre10 centrer">Sélection des écritures <span title="Cliquer pour ouvrir l\'aide" id="help-link2" style="cursor: pointer;" onclick="SearchDocumentation(\'base\', \'ecriturescomptables_4\');">[?]</span></div>
	<div class="memoinfo2">
	<strong>Recette</strong> pour compte financier (D5) vers compte de produit (C7) || <strong>Autres entrées d\'argents</strong> pour compte financier (D5) vers compte de tiers (C4).<br>
	<strong>Dépense</strong> pour compte financier (C5) vers compte de charge &nbsp;(D6) || <strong>Autres sorties d\'argents</strong> pour compte financier (C5) vers compte de tiers (D4).<br>
	'.$message_compta.'
	</div>
	
	<form class="form-int" action="' . $r->uri() . '" method="POST" enctype="multipart/form-data">
	<ul class="wrapper10"><li class="lineflex1">   
	<div class=spacer></div>';
	foreach my $column (sort keys %columnStylesAndLabels) {
		my $style = $columnStylesAndLabels{$column}{'style'};
		my $displayLabel = $columnStylesAndLabels{$column}{'label'} || '&nbsp;';
		$form_2 .= '<span class=headerspan style="' . $style . '">' . $displayLabel . '</span>';
	}
	$form_2 .= '<div class=spacer></div></li>';

	$form_2 .= '<script>
	
	function addNewOption(input,reqid) {
		var select = document.getElementById("docs1_"+ reqid);
		var fileName = input.files[0].name;

		// Ajouter une nouvelle option avec le nom du fichier
		var newOption = document.createElement("option");
		newOption.value = fileName;
		newOption.text = fileName;

		// Ajouter la nouvelle option à la liste déroulante
		select.add(newOption);

		// Sélectionner la nouvelle option
		select.value = fileName;

		// Supprimer l\'option "Sélectionner un document" si nécessaire
		//var selectOption = select.options[0];
		//if (selectOption.value === "") {
		//	select.remove(selectOption.index);
		//}
	}

	//SelectFichier(this);
	function SelectFichier(select,reqid) {
		if (select.selectedIndex === 0) {
			// Si "Ajouter un document" est sélectionné, déclencher la boîte de dialogue de sélection de fichiers
			document.getElementById("fichier_" + reqid).click();
		}
	}
	
	function ShowInitialForm(reqid) {
		
		var select = document.getElementById("select_type_" + reqid);
		var selectedType = select.options[select.selectedIndex].value;
		var csv_debit = document.getElementById("csv_debit_" + reqid);
		var csv_credit = document.getElementById("csv_credit_" + reqid);
		var typecompta = document.getElementById("type_compta_" + reqid).value;
        var select40 = document.getElementById("csv40_" + reqid);
        var select4 = document.getElementById("csv4_" + reqid);
        var select41 = document.getElementById("csv41_" + reqid);

		var newSelectedValue;

		if (typecompta === "engagement") {
			if (csv_debit.value !== "0") {
				if (select4.value !== "") {
				newSelectedValue = "reglement_fournisseur";
				} else {
				newSelectedValue = "depense";
				}
			} else if (csv_credit.value !== "0") {
				if (select4.value !== "") {
				newSelectedValue = "reglement_client";
				} else {
				newSelectedValue = "recette";
				}
			}  else {
				newSelectedValue = selectedType;
			}
		} else if (typecompta === "tresorerie") {
			if (csv_debit.value !== "0") {
				newSelectedValue = "depense";
			} else if (csv_credit.value !== "0") {
				newSelectedValue = "recette";
			} else {
				newSelectedValue = selectedType;
			}       
		} else {
			newSelectedValue = selectedType;
		}

		select.value = newSelectedValue;
	}
	
	function showForm(reqid) {
		var select = document.getElementById("select_type_" + reqid);
		var selectedType = select.options[select.selectedIndex].value;
		var csv_debit = document.getElementById("csv_debit_" + reqid);
		var csv_credit = document.getElementById("csv_credit_" + reqid);
		var typecompta = document.getElementById("type_compta_" + reqid).value;
		var selectcheck = document.getElementById("select_comptant_" + reqid);
		
		//recette depense recette_comptant depense_comptant
		// Vous pouvez ajouter ici la logique pour afficher ou masquer les formulaires en fonction du type sélectionné
		// Assurez-vous que chaque formulaire a un identifiant unique pour le ciblage

		// Exemple de logique pour afficher/masquer des formulaires en fonction du type
		if (selectedType === "transfert") {
			document.getElementById("select_reglement_1_" + reqid).style.display = "inline-block";
			document.getElementById("select_reglement_2_" + reqid).style.display = "inline-block";
			// Masquer les autres formulaires
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "none");
			document.getElementById("csv4_" + reqid) && (document.getElementById("csv4_" + reqid).style.display = "none");
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "none");
			document.getElementById("select_comptant_" + reqid) && (document.getElementById("select_comptant_" + reqid).style.display = "none");
			document.getElementById("csv6_" + reqid).style.display = "none";
			document.getElementById("csv7_" + reqid).style.display = "none";
		} else if (selectedType === "reglement_client") {
			document.getElementById("csv6_" + reqid).style.display = "none";
			document.getElementById("csv7_" + reqid).style.display = "none";
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "none");
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "none");
			document.getElementById("select_reglement_1_" + reqid).style.display = "none";
			document.getElementById("select_comptant_" + reqid) && (document.getElementById("select_comptant_" + reqid).style.display = "none");
			document.getElementById("csv4_" + reqid).style.display = "inline-block";
			document.getElementById("select_reglement_2_" + reqid).style.display = "none";
		} else if (selectedType === "reglement_fournisseur") {
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "none");
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "none");
			document.getElementById("csv6_" + reqid).style.display = "none";
			document.getElementById("csv7_" + reqid).style.display = "none";
			document.getElementById("select_reglement_1_" + reqid).style.display = "none";
			document.getElementById("select_comptant_" + reqid) && (document.getElementById("select_comptant_" + reqid).style.display = "none");
			document.getElementById("csv4_" + reqid).style.display = "inline-block";
			document.getElementById("select_reglement_2_" + reqid).style.display = "none";
		} else if (selectedType === "recette") {
			//var newSelectedValue = "recette"; 
			//select.value = newSelectedValue;
			if (selectcheck && selectcheck.checked) {
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "inline-block");
			} else {
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "none");
			}
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "none");
			document.getElementById("csv4_" + reqid) && (document.getElementById("csv4_" + reqid).style.display = "none");
			
			document.getElementById("select_comptant_" + reqid) && (document.getElementById("select_comptant_" + reqid).style.display = "inline-block");
			document.getElementById("csv6_" + reqid).style.display = "none";
			document.getElementById("csv7_" + reqid).style.display = "inline-block";
			document.getElementById("select_reglement_1_" + reqid).style.display = "none";
			document.getElementById("select_reglement_2_" + reqid).style.display = "none";
		} else if (selectedType === "depense") {
			//var newSelectedValue = "depense"; 
			//select.value = newSelectedValue;
			if (selectcheck && selectcheck.checked) {
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "inline-block");
			} else {
			document.getElementById("csv40_" + reqid) && (document.getElementById("csv40_" + reqid).style.display = "none");
			}
			document.getElementById("csv4_" + reqid) && (document.getElementById("csv4_" + reqid).style.display = "none");
			document.getElementById("csv41_" + reqid) && (document.getElementById("csv41_" + reqid).style.display = "none");
			document.getElementById("select_comptant_" + reqid) && (document.getElementById("select_comptant_" + reqid).style.display = "inline-block");
			document.getElementById("csv6_" + reqid).style.display = "inline-block";
			document.getElementById("csv7_" + reqid).style.display = "none";
			document.getElementById("select_reglement_1_" + reqid).style.display = "none";
			document.getElementById("select_reglement_2_" + reqid).style.display = "none";
		}
	}
	</script>';
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper ' . Data::Dumper::Dumper($csv_data) . ' ');

	if ($args->{importer} eq '0' && $type eq 'csv-paypal') {
		
		# Supprimer la séquence de caractères BOM si elle existe
		$csv_data =~ s/^\x{FEFF}//;
		# Décodez les données du fichier CSV en UTF-8 pour gérer correctement le BOM
		$csv_data = decode('UTF-8', $csv_data);
		# Diviser les lignes CSV en un tableau
		my @csv_lines = split /\r?\n/, $csv_data;
		
			
		# Traiter chaque ligne du contenu CSV
		foreach my $line (@csv_lines) {
			
			my $reqid = $seq_number++;
			    
			if ($type eq 'csv-paypal') {
				# Ignorer certaines lignes (peut être personnalisé)
				next if $line =~ /"Annulation de suspension de compte standard"|"Suspension de compte pour autorisation en cours"|"Description"/;

				# Supprimer les guillemets autour des valeurs CSV
				$line =~ s/^"|"$//g;

				my ($date, $heure, $fuseau, $description, $devise, $brut, $frais, $montant, $solde, $num_transaction, $email_exp, $libelle, $nom_banque, $compte_banque, $montant_frais, $tva, $num_facture, $num_transaction_ref) = split /","/, $line;
				
				# Si le champ "Name" est vide et la description contient "cashback", ajouter "Prime Cashback PayPal" dans le champ "Name"
				if ($libelle eq "" && $description =~ /cashback/i) {
					$libelle = "Prime Cashback PayPal";
				}
				
				# Vérification du signe et attribution de crédit ou débit
				Base::Site::util::formatter_montant_et_libelle(\$montant, \$libelle);
				if ($montant < 0) {
					$debit = sprintf("%.2f", abs($montant));
					$credit = 0;
				} else {
					$debit = 0;
					$credit = sprintf("%.2f", $montant);
				}
				
				$var_date = $date;
				$var_libelle = $libelle;
				
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => $libelle : "' . $var_libelle. '" et $var_date : "' . $var_date. '" et $debit : "' . $debit. '" et $credit : "' . $credit. '"');
			
				
				$form_2 .= generate_foreach_form($dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set, $reqid, %columnStylesAndLabels);

				
			} elsif ($type eq 'boursorama') {
				# Ignorer certaines lignes (peut être personnalisé)
				next if $line =~ /dateOp|dateVal/;

				# Supprimer les guillemets doubles autour des valeurs CSV
				$line =~ s/"//g;
				my ($dateOp, $dateVal, $label, $category, $categoryParent, $montant, $comment, $accountNum, $accountLabel, $accountbalance) = split /;/, $line;
				
				# Vérification du signe et attribution de crédit ou débit
				Base::Site::util::formatter_montant_et_libelle(\$montant, \$label);
				if ($montant < 0) {
					$debit = sprintf("%.2f", abs($montant));
					$credit = 0;
				} else {
					$debit = 0;
					$credit = sprintf("%.2f", $montant);
				}

				my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($dateOp);
				$var_date = sprintf("%02d/%02d/%04d", $day1, $month1, $year1);
				$var_libelle = $label;
				
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "menu.pm => \$var_date : \"$var_date\", \$var_libelle : \"$var_libelle\", \$label : \"$label\", \$category : \"$category\", \$categoryParent : \"$categoryParent\", \$montant : \"$montant\", \$comment : \"$comment\", \$accountNum : \"$accountNum\", \$accountLabel : \"$accountLabel\", \$accountbalance : \"$accountbalance\"");
			   
			} elsif ($type eq 'autre_type') {
				# Ajoutez ici la logique pour d'autres types de CSV
			} 


		}
	
	} elsif ($args->{importer} eq '0' && $type eq 'ofx') {
		
		foreach my $transaction (@$csv_data) {
			my $acct_type = $transaction->{'acct_type'};
			my $account_id = $transaction->{'account_id'};
			my $endDate = $transaction->{'endDate'};
			my $bank_id = $transaction->{'bank_id'};

			# Accédez aux transactions à l'intérieur de la structure
			my $transactions = $transaction->{'transactions'};
			# Inversez l'ordre des transactions
			@$transactions = reverse(@$transactions);

			foreach my $transaction_detail (@$transactions) {
				
				my $reqid = $seq_number++;
				my $amount = $transaction_detail->{'amount'};
				my $dateOp = $transaction_detail->{'date'};
				my $trntype = $transaction_detail->{'trntype'};
				my $var_libelle = $transaction_detail->{'memo'};
				my $fitid = $transaction_detail->{'fitid'};
				my $checknum = $transaction_detail->{'checknum'};
				my $name = $transaction_detail->{'name'};
			
				Base::Site::util::formatter_montant_et_libelle(\$amount, \$var_libelle);
					if ($amount < 0) {
						$debit = sprintf("%.2f", abs($amount));
						$credit = 0;
					} else {
						$debit = 0;
						$credit = sprintf("%.2f", $amount);
					}
					
				my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($dateOp);
				$var_date = sprintf("%02d/%02d/%04d", $day1, $month1, $year1);
			
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => $libelle : "' . $var_libelle. '" et $var_date : "' . $var_date. '" et $debit : "' . $debit. '" et $credit : "' . $credit. '"');
				$form_2 .= generate_foreach_form($dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set, $reqid, %columnStylesAndLabels);

			}
		}

	} elsif ($args->{importer} eq '0' && $type eq 'ocr') {
		

		# Process and use the array of line data
		foreach my $line_data (@$csv_data) {
				my $reqid = $seq_number++;
				my $date_operation = $line_data->{'date_operation'};
				my $date_valeur = $line_data->{'date_valeur'};
				my $var_libelle = $line_data->{'libelle'};
				my $debit = $line_data->{'debit'};
				my $credit = $line_data->{'credit'};
				
				Base::Site::util::formatter_montant_et_libelle(undef, \$var_libelle);
				
				my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($date_operation);
				$var_date = sprintf("%02d/%02d/%04d", $day1, $month1, $year1);

				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => $libelle : "' . $var_libelle. '" et $var_date : "' . $var_date. '" et $debit : "' . $debit. '" et $credit : "' . $credit. '"');
				$form_2 .= generate_foreach_form($dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set, $reqid, %columnStylesAndLabels);
				
		}
		
		
	} else {
		
		my %args = %$args;  # Convertissez la référence de hachage en un vrai hachage

		# Utilisez grep pour filtrer et trier les clés du hachage qui correspondent au modèle
		my @filtered_keys = sort grep { /^select_reglement_1_\d+$/ } keys %args;
		
		foreach my $key (@filtered_keys) {
			if ($key =~ /^select_reglement_1_(\d+)$/) {
				my $numero = $1;  # Extrait le numéro du modèle
				my $reqid = $numero;
				my $var_libelle = $args->{"csv_libelle_$numero"};
				my $var_date = $args->{"date_$numero"};
				my $debit = $args->{"csv_debit_$numero"};
				my $credit = $args->{"csv_credit_$numero"};

				# Utilisez les valeurs extraites pour effectuer le traitement souhaité
				$form_2 .= generate_foreach_form($dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set, $reqid, %columnStylesAndLabels);
			}
		}
	}
			
	# Fin code HTML pour le formulaire de lignes sélectionnées
	$form_2 .= '
		</ul>
		<input type="hidden" name="importer" value="1">
		' . $hidden_fields_form1 . '
		<div class=formflexN3><input type="submit" class="btn btn-gris" value="Traiter la sélection"></div>   
		<div class=spacer></div></form><br>';	

    return $form_2;
}

# Appeler la fonction pour générer le formulaire de sélection des en-têtes
#my $header_selection_form = generate_csv_header_selection_form($r, $args, $csv_data, $hidden_fields_form1);
sub generate_csv_header_selection_form {
    my ($r, $args, $csv_data, $hidden_fields_form1) = @_;
    my $reqid = Base::Site::util::generate_reqline();
    my $generate_select;
    
    # Supprimer la séquence de caractères BOM si elle existe
    $csv_data =~ s/^\x{FEFF}//;

    # Décodez les données du fichier CSV en UTF-8 pour gérer correctement le BOM
    $csv_data = decode('UTF-8', $csv_data);
    
    my @csv_lines = split(/\n/, $csv_data);
    
    # Affichez les cinq premières lignes du fichier CSV
    my $csv_preview = join("\n", @csv_lines[0..4]);
    my $header_line = shift @csv_lines;  # Première ligne du CSV contient les en-têtes
    
    # Supprimer les guillemets autour des valeurs CSV
    #$header_line =~ s/^"|"$//g;
    
    my $csv_separator = Base::Site::util::detect_csv_separator($header_line);

    # Découper les en-têtes en utilisant le séparateur CSV détecté
    my @headers = split /$csv_separator/, $header_line;
    
    $generate_select .= '<option value="" selected>--Sélectionner l\'en-tête correspondante.--</option>';
    
    # Créer les options pour le menu déroulant Date
    foreach my $header (@headers) {
        $generate_select .= "<option value=\"$header\">$header</option>";
    }
    
    $hidden_fields_form1 = Base::Site::util::create_hidden_fields_form($args, [], [], [['import_method', 'textarea']]);

    my $form_html = '
    <div class="form-int"><form action="' . $r->unparsed_uri() . '" method="POST" onsubmit="encryptTextArea();" accept-charset="UTF-8">
    
    		<div class=formflexN2>
			<label style="width: 20%;" class="forms2_label"  for="csv_select_date_'.$reqid.'">En-tête Date :</label>
			<label style="width: 20%;" class="forms2_label" for="csv_select_libelle_'.$reqid.'">En-tête Libellé :</label>
			<label style="width: 20%;" class="forms2_label"  for="csv_select_montant_'.$reqid.'">En-tête Montant :</label>
			</div>   
    
			<div class=formflexN2>
			<select class="login-text" style ="width : 20%;" name="csv_select_date" id="csv_select_date_'.$reqid.'">'.$generate_select.'</select>
			<select class="login-text" style ="width : 20%;" name="csv_select_libelle" id="csv_select_libelle_'.$reqid.'">'.$generate_select.'</select>
			<select class="login-text" style ="width : 20%;" name="csv_select_montant" id="csv_select_montant_'.$reqid.'">'.$generate_select.'</select>
			</div>
			
			<div class="formflexN3">
			<input type="submit" id="submit_'.$reqid.'" style="width: 15%;" class="btn btn-orange" value="Traiter les données">
		</div>
            ' . $hidden_fields_form1.'
        </form></div>
			
	';		



   
   $form_html .= '
        <h3>Aperçu des cinq premières lignes du fichier CSV :</h3>
		<table border="1" style="font-size: 9px;">
		<tr>';

    # Créer les lignes du tableau avec le contenu de $csv_preview
    foreach my $line (split /\n/, $csv_preview) {
        # Supprimer les guillemets autour des valeurs CSV
        $line =~ s/^"|"$//g;
        my @values = split /$csv_separator/, $line;
        $form_html .= '<tr>';
        foreach my $value (@values) {
            $form_html .= "<td>$value</td>";
        }
        $form_html .= '</tr>';
    }

    $form_html .= '</table>';

    return $form_html;
}

#my $resultat_form = generate_foreach_form(%columnStylesAndLabels, $seq_number, $dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set);
sub generate_foreach_form {
    my ($dbh, $r, $args, $var_libelle, $var_date, $debit, $credit, $array_of_documents, $bdd_compte4, $bdd_compte401, $bdd_compte411, $bdd_compte6, $bdd_compte7, $result_reglement_set, $reqid, %columnStylesAndLabels) = @_;
		
    my ($numero_piece, $libre, $selected2, $selected3, $selected6, $selected7, $selected8, $init_java) = ('', '', '', '', '', '', '', '');
    
    my $selected1 = $args->{'docs1_'.$reqid} // undef;
    
    if ($args->{importer} eq '0') {
		
		my $resultat_levenshtein = fetch_data_with_increasing_levenshtein($dbh, $r, $var_libelle, $debit * 100, $credit * 100);
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper : ' . Data::Dumper::Dumper(@$resultat_levenshtein) . ' ');
		
		$init_java = 'ShowInitialForm('.$reqid.');';
		
		foreach my $row (@$resultat_levenshtein) {
			my $numero_compte = $row->[1];  # Accès à l'élément à l'indice 1 dans le tableau interne
			my $id_facture_ecriture = $row->[6] || '';
			$libre = $row->[7];
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => datadumper : nom '.$nom.' et numero compte ' . $numero_compte . ' ');
			if ($numero_compte =~ /^(6)/) {$selected3 = $numero_compte;}
			if ($numero_compte =~ /^(7)/) {$selected8 = $numero_compte;}
			if ($numero_compte =~ /^(4)/) {
				
				$selected2 = $numero_compte;
				if ($numero_compte =~ /^(40)/) {$selected7 = $numero_compte;}
				if ($numero_compte =~ /^(41)/) {$selected6 = $numero_compte;}
					
				my $sql = 'SELECT numero_compte, libelle_compte, default_id_tva, contrepartie FROM tblcompte WHERE numero_compte = ? AND id_client = ? AND fiscal_year = ? ORDER by numero_compte';
				my $compte_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ($numero_compte, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}));
				# Vérifiez s'il y a des résultats
				if (scalar(@$compte_set) > 0) {
					my $contrepartie = $compte_set->[0]->{contrepartie} // '';
					if ($contrepartie =~ /^(6)/ && $selected3 eq '') {$selected3 = $contrepartie;}
					if ($contrepartie =~ /^(7)/ && $selected8 eq '') {$selected8 = $contrepartie;}
				}	
			
			}
			# Si id_facture ne contient pas "MULTI"
			if ($id_facture_ecriture =~ /MULTI/) {
				$numero_piece = $id_facture_ecriture; #Numéro pièce
				$selected1 = $row->[10]; #Documents1
			} 
			
		}
	
	}

	if (defined($args->{'csv6_'.$reqid}) && $args->{'csv6_'.$reqid} ne '') {$selected3 = $args->{'csv6_'.$reqid} // undef;} 
	if (defined($args->{'csv7_'.$reqid}) && $args->{'csv7_'.$reqid} ne '') {$selected8 = $args->{'csv7_'.$reqid} // undef;} 
	if (defined($args->{'csv4_'.$reqid}) && $args->{'csv4_'.$reqid} ne '') {$selected2 = $args->{'csv4_'.$reqid} // undef ;} 
	if (defined($args->{'csv41_'.$reqid}) && $args->{'csv41_'.$reqid} ne '') {$selected6 = $args->{'csv41_'.$reqid} // undef; }  
	if (defined($args->{'csv40_'.$reqid}) && $args->{'csv40_'.$reqid} ne '') {$selected7 = $args->{'csv40_'.$reqid} // undef;}
	if (defined($args->{'libre_'.$reqid}) && $args->{'libre_'.$reqid} ne '') {$libre = $args->{'libre_'.$reqid} // undef;}
	if (defined($args->{'date_'.$reqid}) && $args->{'date_'.$reqid} ne '') {$var_date = $args->{'date_'.$reqid};} 
	if (defined($args->{'calcul_piece_'.$reqid}) && $args->{'calcul_piece_'.$reqid} ne '') {$numero_piece = $args->{'calcul_piece_'.$reqid};} 
	if (defined($args->{'csv_libelle_'.$reqid}) && $args->{'csv_libelle_'.$reqid} ne '') {$var_libelle = $args->{'csv_libelle_'.$reqid};} 
	if (defined($args->{'csv_debit_'.$reqid}) && $args->{'csv_debit_'.$reqid} ne '') {$debit = $args->{'csv_debit_'.$reqid};} 
	if (defined($args->{'csv_credit_'.$reqid}) && $args->{'csv_credit_'.$reqid} ne '') {$credit = $args->{'csv_credit_'.$reqid};} 					

	
	my ($form_name1, $form_id1, $class_value1, $style1) = ('docs1_'.$reqid.'', 'docs1_'.$reqid.'', 'class="formMinDiv2"', '');
	my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};Yellobri(this,$reqid);\"";
	#my $onchange1 = "onchange=\"if(this.selectedIndex == 0){SelectFichier(this,$reqid);};Yellobri(this,$reqid);\"";
	my $select_document = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);
					
	my ($form_name3, $form_id3) = ('csv6_'.$reqid.'', 'csv6_'.$reqid.'');
	my $onchange3 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
	my $select_classe6 = Base::Site::util::generate_compte_selector($bdd_compte6, $reqid, $selected3, $form_name3, $form_id3, $onchange3, 'class="formMinDiv2"', '');

	my ($form_name8, $form_id8) = ('csv7_'.$reqid.'', 'csv7_'.$reqid.'');
	my $onchange8 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
	my $select_classe7 = Base::Site::util::generate_compte_selector($bdd_compte7, $reqid, $selected8, $form_name8, $form_id8, $onchange8, 'class="formMinDiv2"', '');

	#my $selected_value = (defined($args->{'select_type_'.$reqid}) && $args->{'select_type_'.$reqid} ne '') ? $args->{'select_type_'.$reqid} : 'auto';
	my $selected_value= '';
	my $checkbox_value_comptant = $args->{'selected_comptant_'.$reqid} // '';
    my $checked_comptant = $checkbox_value_comptant eq 'on' ? 'checked' : '';
	
	my ($id_select_type, $id_select_type_depense, $id_select_type_recette, $select_classe4, $select_classe411, $select_classe401, $colonne12, $display_credit, $display_debit) = ('', '', '', '', '', '', '', '', '');
	
	if ($r->pnotes('session')->{type_compta} eq 'tresorerie') {
		$id_select_type_recette = '
		<select class="formMinDiv2" id="select_type_'.$reqid.'" name="select_type_'.$reqid.'" style="font-size:14px;" onchange="showForm('.$reqid.');">
			<option value="recette" '.($selected_value eq 'recette' ? 'selected' : '').' >Recette</option>
			<option value="reglement_client" '.($selected_value eq 'reglement_client' ? 'selected' : '').' >Autres entrées d\'argent</option>
			<option value="transfert" '.($selected_value eq 'transfert' ? 'selected' : '').' >Transfert entre compte</option>
		</select>';
		
		$id_select_type_depense = '
		<select class="formMinDiv2" id="select_type_'.$reqid.'" name="select_type_'.$reqid.'" style="font-size:14px;" onchange="showForm('.$reqid.');">
			<option value="depense" '.($selected_value eq 'depense' ? 'selected' : '').' >Dépense</option>
			<option value="reglement_fournisseur" '.($selected_value eq 'reglement_fournisseur' ? 'selected' : '').' >Autres sorties</option>
			<option value="transfert" '.($selected_value eq 'transfert' ? 'selected' : '').' title="Transfert d\'argent entre les comptes C51* => D58 => C58 => D51*">Transfert entre compte</option>
		</select>';
		
		$colonne12 = '<input type="hidden" name="selected_comptant_'.$reqid.'" value="off">
		<input type="hidden" id="type_compta_'.$reqid.'" value="' . $r->pnotes('session')->{type_compta} . '">';
            
	} else {
		
		#my ($form_name2, $form_id2)  = ('csv4_'.$reqid.'', 'csv4_'.$reqid.'');
		#my $onchange2 = "onchange=\"if (this.selectedIndex != 0) { select_contrepartie(this, 'csv6_".$reqid."')};if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
		#$select_classe4 = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected2, $form_name2, $form_id2, $onchange2, 'class="formMinDiv2"', '');
		
		$colonne12 = '<input type="checkbox" id="select_comptant_'.$reqid.'" name="selected_comptant_'.$reqid.'" title="Cocher si c\'est un paiement comptant." value="on" onchange="showForm('.$reqid.');" '.$checked_comptant.'>
            <input type="hidden" name="selected_comptant_'.$reqid.'" value="off">
            <input type="hidden" id="type_compta_'.$reqid.'" value="' . $r->pnotes('session')->{type_compta} . '">';
		
		my ($form_name6, $form_id6)  = ('csv41_'.$reqid.'', 'csv41_'.$reqid.'');
		my $onchange6 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};if (this.selectedIndex != 0 && this.value !== '') { select_contrepartie(this, 'csv7_$reqid');}Yellobri(this,$reqid);\"";
		$select_classe411 = Base::Site::util::generate_compte_selector($bdd_compte411, $reqid, $selected6, $form_name6, $form_id6, $onchange6, 'class="formMinDiv2"', '');
						
		my ($form_name7, $form_id7)  = ('csv40_'.$reqid.'', 'csv40_'.$reqid.'');
		my $onchange7 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};if (this.selectedIndex != 0 && this.value !== '') { select_contrepartie(this, 'csv6_$reqid');}Yellobri(this,$reqid);\"";
		$select_classe401 = Base::Site::util::generate_compte_selector($bdd_compte401, $reqid, $selected7, $form_name7, $form_id7, $onchange7, 'class="formMinDiv2"', '');

		$id_select_type_depense = '
		<select class="formMinDiv2" id="select_type_'.$reqid.'" name="select_type_'.$reqid.'" style="font-size:14px;" onchange="showForm('.$reqid.');">
			<option value="depense" '.($selected_value eq 'depense' ? 'selected' : '').' >Dépense</option>
			<option value="reglement_fournisseur" '.($selected_value eq 'reglement_fournisseur' ? 'selected' : '').' >Autres sorties</option>
			<option value="transfert" '.($selected_value eq 'transfert' ? 'selected' : '').' >Transfert entre compte</option>
		</select>';
		
		$id_select_type_recette = '
		<select class="formMinDiv2" id="select_type_'.$reqid.'" name="select_type_'.$reqid.'" style="font-size:14px;" onchange="showForm('.$reqid.');">
			<option value="recette" '.($selected_value eq 'recette' ? 'selected' : '').' >Recette</option>
			<option value="reglement_client" '.($selected_value eq 'reglement_client' ? 'selected' : '').' >Autres entrées</option>
			<option value="transfert" '.($selected_value eq 'transfert' ? 'selected' : '').' >Transfert entre compte</option>
		</select>';
	}

    my ($form_name4, $form_id4) = ('select_reglement_1_'.$reqid.'', 'select_reglement_1_'.$reqid.'');
    my $onchange4 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'parametres?achats\'};"';
    my $selected4 = $args->{'select_reglement_1_'.$reqid} // undef;
    my $form_reglement_1 = Base::Site::util::generate_reglement_selector($result_reglement_set, $reqid, $selected4, $form_name4, $form_id4, $onchange4, 'class="formMinDiv2"', '');
	
	my ($form_name70, $form_id70)  = ('csv4_'.$reqid.'', 'csv4_'.$reqid.'');
	my $onchange70 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
	$select_classe4 = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected2, $form_name70, $form_id70, $onchange70, 'class="formMinDiv2"', '');

    my $onchange5 = 'onchange="if(this.selectedIndex == 0){document.location.href=\'parametres?achats\'};"';
    my $selected5 = $args->{'select_reglement_2_'.$reqid} // undef;
    my ($form_name5, $form_id5) = ('select_reglement_2_'.$reqid.'', 'select_reglement_2_'.$reqid.'');
    my $form_reglement_2 = Base::Site::util::generate_reglement_selector($result_reglement_set, $reqid, $selected5, $form_name5, $form_id5, $onchange5, 'class="formMinDiv2"', '');

    my $checkbox_value = $args->{'selected_checkbox_'.$reqid} // 'on';
    my $checked = $checkbox_value eq 'on' ? 'checked' : '';
    
    if ($debit eq 0) {$display_debit = 'hide';$id_select_type = $id_select_type_recette;
	} elsif ($credit eq 0) {$display_credit = 'hide';$id_select_type = $id_select_type_depense;}
       
    my %columnData = (
        'Colonne01' => '&nbsp;',
        'Colonne02' => ''.$id_select_type.'',
        'Colonne03' => '<input onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');Yellobri(this,'.$reqid.');" class=formMinDiv2 type=text name="date_'.$reqid.'" id="date_'.$reqid.'" value="' . $var_date . '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" >',
        'Colonne04' => ''.$select_classe4 .''.$select_classe401 .''.$select_classe411 .''. $form_reglement_1.'',
        'Colonne05' => ''.$select_classe6 .''.$select_classe7 .''. $form_reglement_2.'',
        'Colonne06' => ''.$colonne12.'',
        'Colonne07' => '<input onkeypress="Yellobri(this,'.$reqid.');" class=formMinDiv2 type=text id="calcul_piece_'.$reqid.'" name="calcul_piece_'.$reqid.'" value="' . ($numero_piece || '') . '"  style="text-align: center" placeholder="---auto---">',
        'Colonne08' => '<input onkeypress="Yellobri(this,'.$reqid.');" class=formMinDiv2 type=text name="csv_libelle_'.$reqid.'" value="' . $var_libelle . '">',
        'Colonne09' => '<input class="formMinDiv2 '.$display_debit.'" style="text-align: right;" type=text name="csv_debit_'.$reqid.'" id="csv_debit_' . $reqid . '" value="' . $debit . '" onchange="Yellobri(this,'.$reqid.');format_number(this);">',
        'Colonne10' => '<input class="formMinDiv2 '.$display_credit.'" style="text-align: right;" type=text name="csv_credit_'.$reqid.'" id="csv_credit_' . $reqid . '" value="' . $credit . '" onchange="Yellobri(this,'.$reqid.');format_number(this);">',
        'Colonne11' => ''.$select_document.'',
        'Colonne12' => '<input type="checkbox"  name="selected_checkbox_'.$reqid.'" title="Sélectionner la ligne pour traitement" value="on" '.$checked.'>
            <input type="hidden" name="selected_checkbox_'.$reqid.'" value="off">
            <input type="hidden" name="libre_'.$reqid.'" value="'.($libre || '').'">
            <input type="file" id="fichier_'.$reqid.'" name="fichier_'.$reqid.'" style="display: none;" onchange="addNewOption(this,'.$reqid.');">',
        'Colonne13' => '&nbsp;',
    );

    my $form = '<li id="line_'.$reqid.'" class="lineflex1" ><div class=spacer></div>';

    foreach my $column (sort keys %columnStylesAndLabels) {
        my $style = $columnStylesAndLabels{$column}{'style'};
        my $data = $columnData{$column} || '';
        $form .= '<span class=displayspan style="' . $style . '">' . $data . '</span>';
    }
    
    

    $form .= '<div class=spacer></div></li>
        <script>
            // Appeler showForm avec le type par défaut
            '.$init_java.'
            showForm('.$reqid.');
        </script>';
    
    return $form;
}

# Fonction pour générer le contenu personnalisé mémo date
sub generate_memo {
    my ($r) = @_;

    # Requête à la base de données pour obtenir les paramètres de la société
    my $dbh = $r->pnotes('dbh');
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);

    # Accès direct à la session
    my $session = $r->pnotes('session');
    my $franchise_tva = ($parametre_set->[0]->{id_tva_regime} eq 'franchise') ? 1 : 0;
	my $type_compta = ($parametre_set->[0]->{type_compta} eq 'engagement') ? 1 : 0;
    # Extraction des dates importantes
    my ($year, $month, $day) = Base::Site::util::extract_date_components($session->{Exercice_fin_DMY}); # Exercice de l'année N
    my ($month1, $day1) = Base::Site::util::extract_date_components($session->{Exercice_fin_DMY});
    
    # Date de clôture de l'exercice N-1
    my ($year_N1, $month_N1, $day_N1) = Base::Site::util::extract_date_components($session->{Exercice_fin_DMY_N1});
	
	# Vérification du montant de l'IS à payer pour l'exercice N-1 (récupéré du compte 695000)
    my $is_n1_to_pay = Base::Site::bdd::get_is_from_account($dbh, $r, $session->{Exercice_fin_DMY_N1}, '695000');
    
    # Calcul de la date limite 6 mois après la clôture de l'exercice N-1
    my $date_6mois_apres = Base::Site::util::add_months($year_N1, $month_N1, $day_N1, 6);

    # Calcul du 2e jour ouvré suivant le 1er mai (de l'année N)
    my $second_working_day = Base::Site::util::calculate_second_working_day($session->{fiscal_year}, 5, 1);

    # Liste des événements dynamiques
    my @events = (
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-01-15",
            title     => 'Déclaration 2777 : Intérêts et Dividendes',
            action    => '15 du mois suivant le paiement',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-02-15",
            title     => 'Déclaration 2561 : IFU',
            action    => 'Annuel, en N+1, avant le 15 février.',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-03-15",
            title     => 'Déclaration 2571 : Acomptes IS',
            action    => 'Première acompte d\'IS.',
            condition => sub { $is_n1_to_pay >= 3000 }, #Que si IS N-1 est < à 3000
        },
        {
            id        => 'declaration',
            date      => "$second_working_day",
            title     => 'Déclaration 2065 : Liasse fiscale',
            action    => 'Au plus tard le 2e jour ouvré suivant le 1er mai',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-05-15",
            title     => 'Déclaration 2572 : Relevé de solde IS',
            action    => 'Déclaration et paiement du solde (IS et CRL) avant le 15 Mai',
            condition => sub { 1 }, 
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-06-15",
            title     => 'Déclaration 2571 : Acomptes IS',
            action    => 'Deuxième acompte d\'IS.',
            condition => sub { $is_n1_to_pay >= 3000 }, #Que si IS N-1 est < à 3000
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-06-30",
            title     => 'Assemblée Générale',
            action    => 'Annuel, dans les 6 mois suivant la clôture.',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-06-30",
            title     => 'Déclaration des biens immobiliers',
            action    => 'Obligatoire pour tous les propriétaires',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-09-15",
            title     => 'Déclaration 2571 : Acomptes IS',
            action    => 'Troisième acompte d\'IS.',
            condition => sub { $is_n1_to_pay >= 3000 }, #Que si IS N-1 est < à 3000
        },
        {
            id        => 'declaration',
            date      => "$session->{fiscal_year}-12-15",
            title     => 'Déclaration 2571 : Acomptes IS & CRL',
            action    => 'Quatrième acompte d\'IS et/ou Premier acompte CRL.',
            condition => sub { 1 }, # Toujours visible
        },
        {
            id        => 'prepcloture',
            date      => "$session->{fiscal_year}-12-31",
            title     => 'Clôture des Comptes',
            action    => 'Voir la check-list avant clôture.',
            condition => sub { 1 }, # Toujours visible
        },
    );

    # Génération du contenu HTML
    my $html = '<br><div class="memo-container"><div class="memo-timeline">';
    foreach my $event (@events) {
        next unless $event->{condition}->(); # Vérifie la condition d'affichage
        my ($year, $month, $day) = split /-/, $event->{date};
        my $formatted_date = sprintf("%02d/%02d/%04d", $day, $month, $year);
        $html .= qq{
            <a href="#$event->{id}" class="memo-event" data-date="$event->{date}">
                <div class="memo-date centrer">$formatted_date</div>
                <div class="memo-separator"></div>
                <div class="memo-due-date">$event->{title}</div>
                <div class="memo-action">$event->{action}</div>
            </a>
        };
    }
    $html .= '</div></div><br>';
    $html .= "<script>
    // Récupérer la date actuelle
    const today = new Date();
    const currentYear = today.getFullYear(); // Année actuelle
    const currentMonth = today.getMonth(); // Mois actuel (0 = janvier, 11 = décembre)
    
    // Calculer la date dans 30 jours
    const thirtyDaysFromNow = new Date(today);
    thirtyDaysFromNow.setDate(today.getDate() + 15); // Ajouter 30 jours

    // Sélectionner toutes les cartes
    const memoEvents = document.querySelectorAll('.memo-event');

    // Parcourir chaque carte et comparer la date
    memoEvents.forEach(event => {
        const eventDate = new Date(event.getAttribute('data-date')); // Convertir la date de l'événement

        // Comparer la date de l'événement avec la date actuelle et la date limite (30 jours à partir d'aujourd'hui)
        if (eventDate >= today && eventDate <= thirtyDaysFromNow) {
            // Si l'événement est dans les 30 prochains jours, ajouter la classe 'upcoming'
            event.classList.add('upcoming');
        }
        // Si la date de l'événement est dépassée, ajouter la classe 'past'
        else if (eventDate < today) {
            event.classList.add('past');
        }
    });
</script>

";
    return $html;
}


1 ;
