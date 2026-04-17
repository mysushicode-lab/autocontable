package Base::Handler::parametres;
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
use utf8;              	# Encodage UTF-8 pour le script
use Base::Site::util;  	# Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   	# Interaction avec la base de données (SQL)
use Time::Piece;       	# Manipulation de dates et heures
use Apache2::Const -compile => qw( OK REDIRECT ) ;
use Apache2::Upload;
use Apache2::Request;
use Apache2::RequestUtil;
use File::Path ;
use Fcntl qw< LOCK_EX SEEK_END >;
use URI::Escape;
use MIME::Base64;
use Encode;
use HTML::Entities;

sub handler {

	binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content = '' ;
    my $req = Apache2::Request->new($r, MAX_BODY => "1000000000M") ;
    #récupérer les arguments
    my ( %args, @args, $sql, @bind_values ) ;
    #recherche des paramètres de la requête
    @args = $req->param ;

    for (@args) {
	$args{$_} = Encode::decode_utf8( $req->param($_) ) ;
	#nix those sql injection/htmlcode attacks!
	$args{$_} =~ tr/<>;/-/ ;
	#les double-quotes et les <> viennent interférer avec le html
	$args{ $_ } =~ tr/<>"/'/ ;
    }
    
    unless (not( $r->pnotes('session')->{username} eq 'superadmin' )) {
		
		if ( defined $args{societes} ) {

	    $content = societes( $r, \%args ) ;

		} elsif ( defined $args{sauvegarde}) {

			$content = sauvegarde( $r, \%args ) ;

		} elsif ( defined $args{utilisateurs}) {

			$content = utilisateurs( $r, \%args ) ;
		
		} elsif ( defined $args{achats}) {

			$content = form_edit_mode_paiement( $r, \%args ) ;
		
		} elsif ( defined $args{email}) {

			$content = form_email( $r, \%args ) ;
		
		} elsif ( defined $args{logs}) {

			$content = logs( $r, \%args ) ;
		
		} elsif ( defined $args{dev}) {

			$content = dev( $r, \%args ) ;
		
		} elsif ( defined $args{logout}) {

			$content = logout( $r, \%args ) ;
		
		} else {
			$content = societes( $r, \%args ) ;
		}

	} else {
		
		if (not(defined $args{logout})){
		$content = '<div class=warning><h3>Vous n\'êtes pas autorisé à afficher cette page </h3></div>' ;
		} else {
		$content = logout( $r, \%args ) ;	
		}
	
	}
     
    $r->no_cache(1) ;
    $r->content_type('text/html; charset=utf-8') ;
    print $content ;
    return Apache2::Const::OK ;
}

sub sauvegarde {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;
    $args->{restart} = 'parametres?sauvegarde';

	######## Affichage MENU display_menu Début ######
	   $content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
	#/************ ACTION DEBUT *************/
	
	#définition du répertoire contenant les sauvegardes	
	my $chemin = '/Compta/base/backup/' ;
	#$repertoire /var/www/html/Compta/base/backup/
	my $repertoire = $r->document_root() . $chemin ;
	chdir $repertoire ;
	unless ( -d $repertoire ) {
		mkpath $repertoire or die "can't do mkpath : $!" ;
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton télécharger le fichier		  #
	#######################################################################
	if ( defined $args->{bt_download} and $args->{bt_download} eq '1' and defined $args->{name_fichier} ) {
		my $location = $chemin . $args->{name_fichier} ;
		my $export_file =  $r->document_root() . $location;

		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	}

	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Sauvegarder bdd' 			  #
	#######################################################################
	if ( defined $args->{bt_backup} and  $args->{bt_backup} eq '1' ) {
			
		my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
		# sauvegarde  bdd format dump
		system "PGPASSWORD=\"$db_mdp\" pg_dump -h \"$db_host\" -U \"$db_user\" -Fc -b -v \"$db_name\" -f $repertoire\"backup_database.$date.dump\" 2>&1"; 
		# sauvegarde  bdd format sql
		#system "PGPASSWORD=\"$db_mdp\" pg_dump -h \"$db_host\" -O -x -U \"$db_user\" --format=plain -b -v \"$db_name\" -f $repertoire\"backup_database.$date.sql\" 2>&1"; 

		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Sauvegarde de la base donnée via pg_dump (backup_database.'.$date.'.dump)');
		
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Sauvegarder appli' 			  #
	#######################################################################
	if ( defined $args->{bt_backup_perl} and  $args->{bt_backup_perl} eq '1' ) {
		
		my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
		$content .= '<h3 class=warning>Sauvegarde en cours merci de patienter .........</h3>' ;
		system "tar cvzpf  \"/var/www/html/Compta/base/backup/backup_appli.$date.tar.gz\"  --exclude=/var/www/html/Compta/base/backup/* /var/www/html/Compta/ &"; 

		if ( $? == 0 ) {
		sleep 2;
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Sauvegarde de l\'appli (backup_appli.'.$date.'.tar.gz)');
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
	}	
		
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Restaurer bdd' 				  #
	#######################################################################	
	#première demande de restauration d'une sauvegarde; réclamer confirmation
	if ( defined $args->{bt_restore} and $args->{bt_restore} eq '0' and defined $args->{name_fichier} ) {
	    my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde=&amp;bt_restore=1&amp;name_fichier=' . $args->{name_fichier} . '' ;
	    my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde' ;
	    $content .= Base::Site::util::generate_error_message('Voulez-vous restaurer la sauvegarde ' . $args->{name_fichier} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
	} elsif ( defined $args->{bt_restore} and  $args->{bt_restore} eq '1' ) {
		my $location = $chemin . $args->{name_fichier} ;
		my $export_file =  $r->document_root() . $location;
			
		# restauration 
		eval {
			system "PGPASSWORD=\"compta\" dropdb --force -h localhost -U compta --maintenance-db=template1 --if-exists comptalibre"
		} or do {
			system "PGPASSWORD=\"compta\" createdb -h localhost -U compta -T template1 comptalibre";
			system "PGPASSWORD=\"compta\" pg_restore -c -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" \"$export_file\" "; 
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Restauration de '.$args->{name_fichier}.' via pg_restore');
			my $location = '/'.$r->pnotes('session')->{racine}.'/logout' ;
			$r->headers_out->set(Location => $location) ;
			#rediriger le navigateur vers le fichier
			$r->status(Apache2::Const::REDIRECT) ;
			#return Apache2::Const::REDIRECT ;  
			exit(1);
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Restaurer appli' 			  #
	#######################################################################	
	#première demande de restauration d'une sauvegarde; réclamer confirmation
	if ( defined $args->{bt_restore_perl} and $args->{bt_restore_perl} eq '0' and defined $args->{name_fichier} ) {
	    my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde=&amp;bt_restore_perl=1&amp;name_fichier=' . $args->{name_fichier} . '&amp;recent=' . ($args->{recent} || '0') . '&amp;del=' . ($args->{del} || '0') . '' ;
	    my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde' ;
	    $content .= Base::Site::util::generate_error_message('Voulez-vous restaurer la sauvegarde ' . $args->{name_fichier} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
	} elsif ( defined $args->{bt_restore_perl} and  $args->{bt_restore_perl} eq '1' ) {
		my $keep_newer_files = ( defined $args->{recent} and $args->{recent} eq '1' ) ? '--keep-newer-files' : '' ;
		my $location = $chemin . $args->{name_fichier} ;
		my $export_file =  $r->document_root() . $location;
			
		if (defined $args->{del} and $args->{del} eq '1'){
			rmtree "/var/www/html/Compta/base/documents/";
			rmtree "/var/www/html/Compta/base/downloads/";
		}
			
		my $rc = system("tar xfP \"$export_file\" $keep_newer_files -C / 2>&1");
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Restauration de '.$args->{name_fichier}.' via tar (keep_newer_files = '.$args->{recent}.';del = '.$args->{del}.')');
	}
	
	####################################################################### 
	#Suppression de fichier							 					  #
	#######################################################################	
	#première demande de suppression d'une sauvegarde; réclamer confirmation
	if ( defined $args->{bt_remove} and $args->{bt_remove} eq '0' and defined $args->{name_fichier} ) {
	    my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde=&amp;bt_remove=1&amp;name_fichier=' . $args->{name_fichier} . '' ;
	    my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde' ;
	    $content .= Base::Site::util::generate_error_message('Voulez-vous supprimer la sauvegarde ' . $args->{name_fichier} .' ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;
	} elsif ( defined $args->{bt_remove} and $args->{bt_remove} eq '1' ) {
		my $repertoire = $r->document_root() . $chemin ;
		my $sauvegarde_file = $repertoire . $args->{name_fichier} ;
	    #suppression du fichier
	    unlink $sauvegarde_file ;
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Suppression du fichier '.$args->{name_fichier}.'');
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 
	}
	
	
	#####################################################################       
	#l'utilisateur a envoyé un nouveau fichier de dump à enregistrer	#
	#####################################################################   
	if ( defined $args->{bt_add} and $args->{bt_add} eq '1' and defined $args->{bt_name_file} and not($args->{bt_name_file} eq '')) {
		
		#on a un fichier, traiter les données
		my $req = Apache2::Request->new( $r ) ;
		#file handle du document uploadé
		my $upload = $req->upload("bt_name_file") or warn $! ;
		my $upload_fh = $upload->fh() ;

	    my $repertoire = $r->document_root() . $chemin ;
	    chdir $repertoire ;
		my $sauvegarde_file = $repertoire . $args->{bt_name_file} ;

    
	    open (my $fh, ">", $sauvegarde_file) or die "Impossible d'ouvrir le fichier $sauvegarde_file : $!" ;
	    
	    #récupération des données du fichier
	    while ( my $data = <$upload_fh> ) {
		print $fh $data ;
	    }

	    close $fh ;

	    #l'enregistrement s'est bien passé, on peut retourner à la liste des documents
	    undef $args->{bt_add} ;

    } #	if ( defined $args{bt_add} and $args{bt_add} eq '1'  )
    
	#/************ ACTION FIN *************/
	
	opendir (my $rep_fh, $repertoire) or die "impossible d'ouvrir le repertoire $repertoire\n";
	my @file_rep = grep { !/^\.\.?$/ } readdir($rep_fh);
	closedir ($rep_fh);
 
	my $nom_fichier .= '<select class="login-text" name=name_fichier id=name_fichier>' ;
	my $nom_fichier_perl .= '<select  class="login-text" name=name_fichier id=name_fichier_perl>' ;

	foreach my $nom (@file_rep) {
		if ( -f "$repertoire/$nom" and $nom =~ /\.dump$/i) {
			$nom_fichier .= '<option value="' . $nom . '">' . $nom . '</option>' ; 
		} elsif ( -f "$repertoire/$nom" and $nom =~ /\.gz$/i) {
			$nom_fichier_perl .= '<option value="' . $nom . '">' . $nom . '</option>' ;
		}
	}
	
	$nom_fichier .= '</select>' ;
	$nom_fichier_perl .= '</select>' ;
	
	############## Formulaire Gestion des sauvegardes ##############	
	my $contenu_web .= '
		<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des sauvegardes</h3></legend>
		<div class="centrer">
		
			<div class=Titre10>Sauvegarde & restauration de la Base de Données</div>
			<div class="form-int">
				<form action=/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde>
				<input type=hidden name=sauvegarde value=>
				<input type=hidden name=bt_backup value=1>
				<button style ="width : 25%;" class="btn btn-vert">Lancer une sauvegarde</button>
				</form>
				<br><hr><br>
				<form method="post">
				<label class="forms" for="name_fichier">Sauvegardes disponibles</label>
				'.$nom_fichier.'
				<br><br>
				<input type="submit" class="btn btn-vert" style ="width : 25%;" formaction="parametres&#63;sauvegarde=&amp;bt_download=1" value="Télécharger la sauvegarde">
				<input type="submit" class="btn btn-orange" style ="width : 25%;"  formaction="parametres&#63;sauvegarde=&amp;bt_restore=0" value="Restaurer la sauvegarde">
				<input type="submit" class="btn btn-rouge" style ="width : 25%;" formaction="parametres&#63;sauvegarde=&amp;bt_remove=0" value="Supprimer la sauvegarde">
				</form>
			</div>
		
			<div class=Titre10>Sauvegarde & restauration de l\'Application (y compris les Documents)</div>
			<div class="form-int">
				<form action=/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde>
				<input type=hidden name=sauvegarde value=>
				<input type=hidden name=bt_backup_perl value=1>
				<button class="btn btn-vert" style ="width : 25%;">Lancer une sauvegarde</button>
				</form>
				<br><hr><br>
				<form style ="display:inline;" method="post">
				<label class="forms" style ="width : 39%;" for="name_fichier_perl">Sauvegardes disponibles</label>
				'.$nom_fichier_perl.'
				<label class="forms" style ="width : 74%;" for="del">Supprimer les données avant restauration ?</label><input type="checkbox" style ="width : 25%;" id="del" name="del" value=1>
				<label class="forms" style ="width : 74%;" for="recent">Ne pas écraser les fichiers existants plus récents ou de même date</label><input type="checkbox" style ="width : 25%;" id="recent" name="recent" checked value=1>
				<br><br>
				<input type="submit" class="btn btn-vert" style ="width : 25%;" formaction="parametres&#63;sauvegarde=&amp;bt_download=1" value="Télécharger la sauvegarde">
				<input type="submit" class="btn btn-orange" style ="width : 25%;" formaction="parametres&#63;sauvegarde=&amp;bt_restore_perl=0" value="Restaurer la sauvegarde">
				<input type="submit" class="btn btn-rouge" style ="width : 25%;" formaction="parametres&#63;sauvegarde=&amp;bt_remove=0" value="Supprimer la sauvegarde">
				</form>
			</div>
	   
			<div class=Titre10>Ajouter un fichier</div>
			<div class="form-int">
				<form style ="display:inline;" action=/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde method=POST enctype="multipart/form-data">
				<input type=file name=bt_name_file>
				<br><br>
				<input type=hidden name=sauvegarde value=>
				<input type=hidden name=bt_add value=1>
				<input type="submit" class="btn btn-gris" style ="width : 25%;" value="Ajouter le fichier">
				</form>
			</div>
	   
	   </div></fieldset>
	';
	
	$content .= '<div class="formulaire1">' . $contenu_web . '</div>' ;
    return $content ;
    
} #sub sauvegarde 

sub societes {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, $option_set, @bind_array, $content ) ;
    $args->{restart} = 'parametres?societes';
    	
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
	
	######## Affichage MENU display_menu Début ######
	   $content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
    $args->{societes} ||= 0 ;
    
    if (!defined $args->{id_client}) {
	$args->{id_client} = $r->pnotes('session')->{id_client};	
	}
	
	#/************ ACTION DEBUT *************/
	
	#Requête compta_client
	my $societe_get = Base::Site::bdd::get_all_societe($dbh, $r, $args);
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	#1ère demande de suppression; afficher lien d'annulation/confirmation
	if ( defined $args->{societes} && defined $args->{supprimer_societe} && $args->{supprimer_societe} eq '0' ) {
	my $non_href = '/'.$r->pnotes('session')->{racine}.'/parametres?societe=0&amp;id_client=' . $args->{id_client} ;
	my $oui_href = '/'.$r->pnotes('session')->{racine}.'/parametres?societe=0&amp;supprimer_societe=1&amp;id_client=' . $args->{id_client} ;
	$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer la société : '.$societe_get->[0]->{id_client}.' - ' . $societe_get->[0]->{etablissement} . '?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	
	#2emes demande de suppression; afficher lien d'annulation/confirmation
	} elsif ( defined $args->{societes} && defined $args->{supprimer_societe} && $args->{supprimer_societe} eq '1' ) {
	my $non_href = '/'.$r->pnotes('session')->{racine}.'/parametres?societe=0&amp;id_client=' . $args->{id_client} ;
	my $oui_ofcourse_href = '/'.$r->pnotes('session')->{racine}.'/parametres?societe=0&amp;supprimer_societe_ofcourse=1&amp;id_client=' . $args->{id_client} ;
	$content .= '<h3 class=warning>êtes-vous sûr et certain de vouloir supprimer la société : '.$societe_get->[0]->{id_client}.' - ' . $societe_get->[0]->{etablissement} . '?<a href="' . $non_href . '" style="margin-left: 3ch;">Non</a><a href="' . $oui_ofcourse_href . '" style="margin-left: 3ch;">Oui</a></h3>' ;
	}
	
	#l'utilisateur a cliqué sur le bouton 'Supprimer', supprimer l'enregistrement
    if ( defined $args->{societes} && defined $args->{supprimer_societe_ofcourse} && $args->{supprimer_societe_ofcourse} eq '1' ) {
		my $nb_societe_count = '';	
		#on vérifie combien il y a de société dans la base
		$sql = 'SELECT count(id_client) FROM compta_client';

		eval { $nb_societe_count = $dbh->selectall_arrayref( $sql, undef, () )->[0]->[0] } ;
	
		if ($nb_societe_count == '1') {
			$content .= Base::Site::util::generate_error_message('Attention : il n\'existe qu\'une société dans la base, impossible de la supprimer') ;
		} else {
			$sql = 'SELECT delete_account_data (?)' ;
			@bind_array = ( $args->{id_client} ) ;
			eval { $dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /tbljournal_id_client_fiscal_year_numero_compte_fkey/ ) {
					$content .= Base::Site::util::generate_error_message('Le compte n\'est pas vide : suppression impossible') ;
				} elsif ( $@ =~ /still referenced/ ) {
					$content .= Base::Site::util::generate_error_message('L\'utilisateur superadmin est lié à la société : suppression impossible !
					<br><br>
					<a class=nav href="parametres?utilisateurs=0&modification_utilisateur=1&selection_utilisateur=superadmin">Cliquer ici pour modifier la Société de rattachement de l\'utilisateur superadmin</a>
					') ;
				} else {
					$content .= Base::Site::util::generate_error_message($@) ;
				}	
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Suppression de la société '.$societe_get->[0]->{id_client}.' - ' . $societe_get->[0]->{etablissement} . '');
				if ($r->pnotes('session')->{id_client} eq $args->{id_client}) {
					$args->{restart} = 'logout';
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé 
				}
			}
		}
	}
    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'creation' 					  #
	#######################################################################
	if ( defined $args->{societes} && defined $args->{creer} && $args->{creer} eq '1' ) {
		
		$sql = 'INSERT INTO compta_client (id_client, etablissement, immobilier, courriel, siret, padding_zeroes, fiscal_year_start, id_tva_periode, id_tva_option, id_tva_regime, adresse_1, code_postal, ville, date_debut, date_fin, type_compta)
		VALUES (nextval(\'compta_client_id_client_seq\'), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id_client';
		my $sth = $dbh->prepare($sql) ;
		my @bind_array = ( $args->{etablissement}, $args->{immobilier}, $args->{courriel} || undef, $args->{siret}, $args->{padding_zeroes}, $args->{fiscal_year_start}, $args->{id_tva_periode} || undef, $args->{id_tva_option} || undef, $args->{id_tva_regime} || undef, $args->{adresse_1} || undef, $args->{code_postal} || undef, $args->{ville} || undef, $args->{date_debut} || undef, $args->{date_fin} || undef, $args->{type_compta} || undef) ;
		my $next_id_client ;
		eval { $next_id_client = $dbh->selectall_arrayref( $sql, undef, ( @bind_array ) )->[0]->[0] } ;
		
		if ( $@ ) {
			if ( $@ =~ /journal_tva/ ) {
			$content .= '<h3 class=warning>Il faut créer au moins un journal. Vous pouvez reconduire les journaux de l\'année précédente dans Journaux -> Modifier la liste</h3>' ;
			} else {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}
		} else {
			#ajouter la catégorie Temp dans documents
			my $var_cat_doc = 'Temp';
			$sql = 'INSERT INTO tbldocuments_categorie (libelle_cat_doc, id_client) values (?, ?)' ;
			@bind_array = ( $var_cat_doc, $next_id_client ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;	
			
			if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Création de la société '.$next_id_client.' - ' . $args->{etablissement} . '');
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
		} 	
    } #    if ( $args->{creation} eq '1' ) 
    
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton valider les modifications		  #
	#######################################################################
    if ( defined $args->{societes} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
		$sql = 'UPDATE compta_client set etablissement = ?, immobilier = ?, courriel = ?, siret = ?, padding_zeroes = ?, fiscal_year_start = ?, date_debut = ?, date_fin = ?, adresse_1 = ?, code_postal = ?, ville = ?, journal_tva = ?, id_tva_periode = ?, id_tva_option = ?, id_tva_regime = ?, type_compta = ? WHERE id_client = ? ' ;
		my @bind_array = ( $args->{etablissement}, $args->{immobilier}, $args->{courriel} || undef, $args->{siret}, $args->{padding_zeroes}, $args->{fiscal_year_start}, $args->{date_debut} || undef, $args->{date_fin} || undef, $args->{adresse_1} || undef, $args->{code_postal} || undef, $args->{ville} || undef, $args->{journal_tva} || 'OD', $args->{id_tva_periode} || undef, $args->{id_tva_option} || undef, $args->{id_tva_regime} || undef, $args->{type_compta} || undef, $args->{id_client} ) ;
		eval { $dbh->do( $sql, undef, ( @bind_array ) ) } ;
		
		if ( $@ ) {
			if ( $@ =~ /journal_tva/ ) {
			$content .= '<h3 class=warning>Il faut créer au moins un journal. Vous pouvez reconduire les journaux de l\'année précédente dans Journaux -> Modifier la liste</h3>' ;
			} else {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}
		} else {
			$args->{new_fiscal_year} = $r->pnotes('session')->{fiscal_year};
			Base::Handler::fiscal_year::refresh_date( $r, $args );
		}
    } 
    
    #####################################       
	# Récupérations d'informations		#
	##################################### 
	
	#Requête compta_client
	$societe_get = Base::Site::bdd::get_all_societe($dbh, $r, $args);
	
    my $all_societe = Base::Site::bdd::get_all_societe($dbh, $r);
	my $selected_societe = ((defined($args->{id_client}) && $args->{id_client} ne '') || $societe_get->[0]->{id_client} ) ? ($args->{id_client} || $societe_get->[0]->{id_client} ) : undef;
	my ($form_name_societe, $form_id_societe) = ('id_client', 'id_client');
	my $societe_select = Base::Site::util::generate_societe_selector($all_societe, undef, $selected_societe, $form_name_societe, $form_id_societe, '', 'class="login-text"', 'style="width: 30%;"');

    my $var_id_tva_regime = (defined $societe_get->[0]->{id_tva_regime} && $societe_get->[0]->{id_tva_regime} eq 'franchise' && !defined $args->{creation_societe}) ? 'style="display:none;"' : 'onchange="ModSelected(this,\'submit6\');"' ;

	# Option TVA
    my $id_tva_option_select = Base::Site::util::generate_simple_select('id_tva_option', 'id_tva_option', 'login-text', [['encaissements', 'encaissements'], ['débits', 'débits']], $args->{id_tva_option}, $args->{modification_societe} ? $societe_get->[0]->{id_tva_option} : "", $var_id_tva_regime);
	# Option module immobilier
    my $id_module_immobilier = Base::Site::util::generate_simple_select('immobilier', 'immobilier', 'login-text', [['f', 'Non'], ['t', 'Oui']], $args->{immobilier}, $args->{modification_societe} ? $societe_get->[0]->{immobilier} : "", 'onchange="ModSelected(this,\'submit5\');"', 'f');
	# Type compta
	my $type_compta = Base::Site::util::generate_simple_select('type_compta', 'type_compta', 'login-text', [['engagement', 'Comptabilité d\'engagement'], ['tresorerie', 'Comptabilité de trésorerie']], $args->{type_compta}, $args->{modification_societe} ? $societe_get->[0]->{type_compta} : "", 'onchange="ModSelected(this);"');
	# Régime TVA
	my $id_tva_regime_select = Base::Site::util::generate_simple_select('id_tva_regime', 'id_tva_regime', 'login-text', [['normal', 'Réel normal de TVA'], ['simplifié', 'Réel simplifié de TVA'], ['franchise', 'Franchise en base de TVA']], $args->{id_tva_regime}, $args->{modification_societe} ? $societe_get->[0]->{id_tva_regime} : "", 'onchange="ModSelected(this,\'submit6\');"');
	# Période TVA
	my $id_tva_periode_select = Base::Site::util::generate_simple_select('id_tva_periode', 'id_tva_periode', 'login-text', ['mensuelle', 'trimestrielle'], $args->{id_tva_periode}, $args->{modification_societe} ? $societe_get->[0]->{id_tva_periode} : "", $var_id_tva_regime);
	# Fiscal year start format
	my $select_fiscal_year_start = Base::Site::util::generate_simple_select('fiscal_year_start', 'fiscal_year_start', 'login-text', [['01-01', '1er Janvier'],['01-02', '1er Février'],['01-03', '1er Mars'],['01-04', '1er Avril'],['01-05', '1er Mai'],['01-06', '1er Juin'],['01-07', '1er Juillet'],['01-08', '1er Août'],['01-09', '1er Septembre'],['01-10', '1er Octobre'],['01-11', '1er Novembre'],['01-12', '1er Décembre']], $args->{fiscal_year_start}, $args->{modification_societe} ? $societe_get->[0]->{fiscal_year_start} : "", 'onchange="ModSelected(this);"');


    ############## Formulaire Gestion des sociétés ##############	
    my $fiche_client .= '
		<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des sociétés</h3></legend>
		<div class="centrer">
		
		<form class="gooflex2" method=POST>
		<input type="submit" class="respbtn btn-vert flex-21" formaction="parametres&#63;societe&amp;creation_societe=1" value="Créer une nouvelle société" >
		</form>


		<div class=Titre10>Modifier une société existante</div>
		<div class="form-int">
		<form method=POST>
		<input type=hidden name=societe value=0>
		'.$societe_select.'
		<br><br>
		
		<input type=submit class="btn btn-gris" style ="width : 25%;" formaction="parametres&#63;societe&amp;modification_societe=1" value=Modifier>
		<input type=submit class="btn btn-rouge" style ="width : 25%;" formaction="parametres&#63;societe&amp;supprimer_societe=0" value="Supprimer" >
		<br><br>
		
		</form></div>

  	';

 	if ((defined $args->{creation_societe}) && ($args->{creation_societe} eq 1)) {
		
		#formatage des numéros de pièces
		my $padding_zeroes_options = '' ;
		$sql = q { select s.p as value, case when padding_zeroes = s.p then 'selected' else '' end as selected from generate_series(2, 5) s(p), compta_client where id_client = ? } ;
		$option_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;
		for ( @$option_set ) {
			my $pattern = '%0' . $_->{value} . 'd' ;
			$padding_zeroes_options .= '<option ' . $_->{selected} . ' value="' . $_->{value} . '">A' . sprintf( $pattern, 1)  . ', A' . sprintf( $pattern, 2)  . '...</option>' ;
		}
		my $padding_zeroes_select = '<select class="login-text" name=padding_zeroes id=padding_zeroes>' . $padding_zeroes_options . '</select>' ;

		#construire la table des paramètres
		$fiche_client .= '
			<div class=Titre10>Création d\'une nouvelle société</div>
			<div class="form-int">
			<form action=/'.$r->pnotes('session')->{racine}.'/parametres method=POST>
			<label class="forms para" for="etablissement">Nom de l\'entreprise :</label><input class="login-text" type=text name=etablissement id=etablissement required/>
			<label class="forms para" for="adresse_1">Adresse :</label><input class="login-text" type=text name=adresse_1  id=adresse_1 />
			<label class="forms para" for="code_postal">Code postal :</label><input class="login-text" type=text name=code_postal id=code_postal />
			<label class="forms para" for="ville">Ville :</label><input class="login-text" type=text name=ville id=ville />
			<label class="forms para" for="ville">Courriel :</label><input class="login-text" type=text name=courriel id=courriel />
			<label class="forms para" for="siret">Siret :</label><input class="login-text" type=text name=siret id=siret required/>
			<label class="forms para" for="fiscal_year_start">Début d\'exercice :</label>' . $select_fiscal_year_start. '
			<label class="forms para" for="date_debut">Date de début du 1er exercice :</label><input class="login-text" type="text" placeholder="Entrer la date au format jj/mm/aaaa" title="Entrer la date au format jj/mm/aaaa" name=date_debut required="" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})"/>
			<label class="forms para" for="date_fin">Date de fin du 1er exercice :</label><input class="login-text" type="text" placeholder="Entrer la date au format jj/mm/aaaa" title="Entrer la date au format jj/mm/aaaa" name=date_fin required="" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})"/>
			<label class="forms para" for="typecompta">Système comptable :</label>' . $type_compta. '
			<br><label class="forms para" for="submit1"></label><input type=submit id=submit1 style="width: 50ch;" class="btn btn-vert" value=Valider > <br>		
			</div>
			<div class=Titre10>Divers</div>
			<div class="form-int">
			<br>
			<label class="forms para" for="immobilier">Module gestion immobilière  :</label>' . $id_module_immobilier . '
			<label class="forms para" for="padding_zeroes">Numérotation des pièces :</label>' . $padding_zeroes_select . '
			<br><label class="forms para" for="submit2"></label><input type=submit id=submit2 style="width: 50ch;" class="btn btn-vert" value=Valider> <br>		
			</div>
			<div class=Titre10>TVA</div>
			<div class="form-int">
			<br>
			<label class="forms para" for="id_tva_regime">Régime de TVA :</label>' . $id_tva_regime_select . '
			<label class="forms para" for="id_tva_option">TVA collectée :</label>' . $id_tva_option_select . '
			<label class="forms para" for="id_tva_periode">Périodicité de la TVA :</label>' . $id_tva_periode_select . '
			<input type=hidden name=creer value=1>
			<br>
			<label class="forms para" for="submit3"></label><input type=submit id=submit3 style="width: 50ch;" class="btn btn-vert" value=Valider>
			<br>
			</form></div>
			';	
	} elsif ((defined $args->{modification_societe}) && ($args->{modification_societe} eq 1)) {
		
		$societe_get = Base::Site::bdd::get_all_societe($dbh, $r, $args);
    
		for ( @$societe_get ) {

			#formatage des numéros de pièces
			my $padding_zeroes_options = '' ;
			$sql = q { select s.p as value, case when padding_zeroes = s.p then 'selected' else '' end as selected from generate_series(2, 5) s(p), compta_client where id_client = ? } ;
			$option_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $args->{id_client} ) ) ;
			for ( @$option_set ) {
				my $pattern = '%0' . $_->{value} . 'd' ;
				$padding_zeroes_options .= '<option ' . $_->{selected} . ' value="' . $_->{value} . '">A' . sprintf( $pattern, 1)  . ', A' . sprintf( $pattern, 2)  . '...</option>' ;
			}
			my $padding_zeroes_select = '<select onchange="ModSelected(this,\'submit5\');" class="login-text" name=padding_zeroes id=padding_zeroes>' . $padding_zeroes_options . '</select>' ;

			#journal_tva
			$sql = 'SELECT libelle_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal' ;
			my @bind_array = ( $args->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
			my $journal_set = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
			my $journal_tva_select = '<select class="login-text" name=journal_tva id=journal_tva '.$var_id_tva_regime.'>' ;
			for ( @$journal_set ) {
			my $selected = ( $_->[0] eq $societe_get->[0]->{journal_tva} ) ? 'selected' : '' ;
			$journal_tva_select .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
			}
			$journal_tva_select .= '</select>' ;
			
			my $selected = '';		

			$fiche_client .= '
			<div class=Titre10>Modification de la société : ' . $_->{id_client} . ' - ' . $_->{etablissement} . '</div>
			<div class="form-int">
			<form action=/'.$r->pnotes('session')->{racine}.'/parametres method=POST>
			<label class="forms para" for="etablissement">Nom de l\'entreprise :</label><input oninput="ModSelected(this);" class="login-text" type=text name=etablissement id=etablissement value="' . $_->{etablissement} . '"  required />
			<label class="forms para" for="adresse_1">Adresse :</label><input oninput="ModSelected(this);" class="login-text" type=text name=adresse_1 id=adresse_1 value="' . ($_->{adresse_1} || ''). '" />
			<label class="forms para" for="code_postal">Code postal :</label><input oninput="ModSelected(this);" class="login-text" type=text name=code_postal id=code_postal value="' . ($_->{code_postal}|| '') . '" />
			<label class="forms para" for="ville">Ville :</label><input oninput="ModSelected(this);" class="login-text" type=text name=ville id=ville value="' . ($_->{ville}|| '') . '" />
			<label class="forms para" for="courriel">Courriel :</label><input oninput="ModSelected(this);" class="login-text" type=text name=courriel id=courriel value="' . ($_->{courriel}|| '') . '" />
			<label class="forms para" for="siret">Siret :</label><input oninput="ModSelected(this);" class="login-text" type=text name=siret id=siret value="' . ($_->{siret} || ''). '" required />
			<label class="forms para" for="fiscal_year_start">Début d\'exercice :</label>'.$select_fiscal_year_start.'
			<label class="forms para" for="date_debut">Date de début du 1er exercice :</label><input oninput="ModSelected(this);format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');" class="login-text" type=text name=date_debut id=date_debut value="' . ($_->{date_debut}|| '') . '" required pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})"/>
			<label class="forms para" for="date_fin">Date de fin du 1er exercice :</label><input oninput="ModSelected(this);format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');" class="login-text" type=text name=date_fin id=date_fin value="' . ($_->{date_fin} || ''). '" required pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})"/>
			<label class="forms para" for="type_compta">Système comptable :</label>'.$type_compta.'
			<br><label class="forms para" for="submit1"></label><input type=submit id=submit1 style="width: 50ch;" class="btn btn-vert" value=Valider> <br>		
			
			</div>
			<div class=Titre10>Divers</div>
			<div class="form-int">
			
			<br>
			<label class="forms para" for="immobilier">Module gestion immobilière :</label>' . $id_module_immobilier . '
			<label class="forms para" for="padding_zeroes">Numérotation des pièces :</label>' . $padding_zeroes_select . '
			<br><label class="forms para" for="submit5"></label><input type=submit id=submit5 style="width: 50ch;" class="btn btn-vert" value=Valider> <br>		
			</div>
			<div class=Titre10>TVA</div>
			<div class="form-int">
			<br>
			<label class="forms para" for="id_tva_regime">Régime de TVA :</label>' . $id_tva_regime_select . '
			<label class="forms para" for="id_tva_option" '.$var_id_tva_regime.'>TVA collectée :</label>' . $id_tva_option_select . '
			<label class="forms para" for="id_tva_periode" '.$var_id_tva_regime.'>Périodicité de la TVA :</label>' . $id_tva_periode_select . '
			<label class="forms para" for="padding_zeroes" '.$var_id_tva_regime.'>Journal de TVA :</label>' . $journal_tva_select . '
			<input type=hidden name=modifier value=1>
			<input type=hidden name=modification_societe value=1>
			<input type=hidden name=id_client value=' .($_->{id_client}) . '>
			<br>
			<label class="forms para" for="submit6"></label><input type=submit id=submit6 style="width: 50ch;" class="btn btn-vert" value=Valider>
			<br>
	   
			</form></div>
			
			</fieldset>
		
			';
		}
	}
		
	$content .= '<div class="formulaire1" >' . $fiche_client . '</div>' ;

    return $content ;
    
} #sub societes 

sub form_email {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, $option_set, @bind_array) ;
    my ($content, $selected, $line) = ('', '', '1');
    $args->{restart} = 'parametres?email';

    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
	
	######## Affichage MENU display_menu Début ######
	$content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
	#/************ ACTION DEBUT *************/
	
	# Passage en boulean t ou f 
	if (defined $args->{masquer} && $args->{masquer} eq '1') {
		$args->{masquer} = 't';
	} else {$args->{masquer} = 'f';}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	#1ère demande de suppression; afficher lien d'annulation/confirmation
    if ( defined $args->{email} && defined $args->{supprimer} && $args->{supprimer} eq '0') {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/parametres?email' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/parametres?email&amp;supprimer=1&amp;mot=' . $args->{mot} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer la recherche du mot ' . Base::Site::util::decryptTextArea($args->{mot},"your_secret_key") . '?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{email} && defined $args->{supprimer} && $args->{supprimer} eq '1') {
			#DELETE FROM tblconfig_liste
			$sql = 'DELETE FROM tblconfig_liste WHERE config_libelle = ? AND id_client = ? AND module = \'email\'' ;
			@bind_array = ( $args->{mot}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>le libellé ne peut être vide</h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton valider les modifications		  #
	#######################################################################
    if ( defined $args->{email} && $args->{email} eq '1' ) {

	$sql = <<'SQL';
    INSERT INTO tblsmtp (id_client, smtp_type, smtp_nom, smtp_mail, smtp_serveur, smtp_port, smtp_user, smtp_pass, smtp_secu, smtp_vers, smtp_api_id, smtp_api_secret)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (id_client)
    DO UPDATE SET
        smtp_type = EXCLUDED.smtp_type,
        smtp_nom = EXCLUDED.smtp_nom,
        smtp_mail = EXCLUDED.smtp_mail,
        smtp_serveur = EXCLUDED.smtp_serveur,
        smtp_port = EXCLUDED.smtp_port,
        smtp_user = EXCLUDED.smtp_user,
        smtp_pass = EXCLUDED.smtp_pass,
        smtp_secu = EXCLUDED.smtp_secu,
        smtp_vers = EXCLUDED.smtp_vers,
        smtp_api_id = EXCLUDED.smtp_api_id,
        smtp_api_secret = EXCLUDED.smtp_api_secret;
SQL
		my @bind_array = ($r->pnotes('session')->{id_client}, $args->{smtp_type}, $args->{smtp_nom}, $args->{smtp_mail} || undef, $args->{smtp_serveur}, $args->{smtp_port}, $args->{smtp_user}, $args->{smtp_pass}, $args->{smtp_secu} || undef, $args->{smtp_vers} || undef, $args->{smtp_api_id} || undef, $args->{smtp_api_secret} || undef) ;
		eval { $dbh->do( $sql, undef, ( @bind_array ) ) } ;
		
		if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
		} 
    }
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{email} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {

		#on interdit moot vide
		if (!$args->{encrypted_mot}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un mot à rechercher') ;
		} elsif (!$args->{select_modele}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un modèle') ;
		} else {
			#INSERT INTO tblconfig_liste
			$sql = 'INSERT INTO tblconfig_liste (config_libelle, config_compte, id_client, module) values (?, ?, ?, \'email\')' ;
			@bind_array = ( $args->{encrypted_mot}, $args->{select_modele}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>Il faut obligatoirement un mot à rechercher</h3>' ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= '<h3 class=warning>Ce mot existe déjà</h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
		}
    }
    
    ####################################################################### 	
	#l'utilisateur a cliqué sur 'Valider'  								  #
	#######################################################################
    if ( defined $args->{email} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
	    
   	    #UPDATE tblconfig_liste
	    $sql = 'UPDATE tblconfig_liste set config_libelle = ?, config_compte = ?, masquer = ? where id_client = ? AND config_libelle = ? AND module = \'email\'' ;
	    @bind_array = ( $args->{encrypted_mot}, $args->{select_mod}, $args->{masquer}, $r->pnotes('session')->{id_client}, $args->{old_mot} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>le mot à rechercher ne peut être vide</h3>' ;
			} else {$content .= '<h3 class=warning>valeur $args->{masquer} '.$args->{masquer}.' et ' . $@ . '</h3>' ;}
		} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
    }
    
	#/************ ACTION FIN *************/
	

	#####################################       
	# Récupérations d'informations		#
	#####################################  
		
	#Requête tblconfig_liste
	my $resultat = Base::Site::bdd::get_tblconfig_liste($dbh, $r, 'email');
	
	############## Formulaire Configuration SMTP ##############	
   
    #Requête tblsmtp
	my $smtp_get = Base::Site::bdd::get_email_smtp($dbh, $r, $args);

	# Type mail
	#my $config_type = Base::Site::util::generate_simple_select('config_type', 'config_type', 'login-text', [['smtp', 'SMTP'], ['api', 'Gmail API']], $societe_get->[0]->{config_type}, '', 'onchange="toggleConfigSections();"', 'smtp');
	my $config_type = Base::Site::util::generate_simple_select('smtp_type', 'smtp_type', 'login-text', [['smtp', 'SMTP']], $smtp_get->[0]->{smtp_type}, '', 'style="width: 15%;"', 'smtp');
	
	# Tls
    my $type_tls = Base::Site::util::generate_simple_select('type_tls', 'type_tls', 'login-text', [['t', 'Oui'], ['n', 'Non']], $smtp_get->[0]->{type_tls}, "", '', 't');

	# Tls Version
    my $version_tls = Base::Site::util::generate_simple_select('smtp_vers', 'smtp_vers', 'login-text', [['1.2', 'TLS 1.2'], ['1.3', 'TLS 1.3']], $smtp_get->[0]->{smtp_vers}, "", 'style="width: 30%;" onchange="ModSelected(this, \'submit8\');"', '1.2');

	# smtp_security
    my $smtp_security = Base::Site::util::generate_simple_select('smtp_secu', 'smtp_secu', 'login-text', [['tls', 'TLS'], ['ssl', 'SSL'], ['none', 'Aucune']], $smtp_get->[0]->{smtp_secu}, "", 'style="width: 30%;" onchange="ModSelected(this, \'submit8\');"', 'TLS');

    my $fiche_client .= '
    <fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des paramètres Email</h3></legend>
    <div class="centrer"> 	';
	
	
	$fiche_client .= '
	<div class=Titre10>Configuration SMTP <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'parametres_5\');" style="cursor: pointer;" >[?]</span></div>
	<div class="form-int"><form action=/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.'=1 method=POST>

		<div class=formflexN2>
		<label style="width: 14%;text-align:center; " class="forms para" for="smtp_type">Type :</label>
        <label  style="width: 40%;text-align:center;" class="forms para" for="smtp_nom">Nom de l\'expéditeur :</label>
        <label style="width: 40%;text-align:center;" class="forms para" for="smtp_mail">Mail de l\'expéditeur :</label>
		</div>

		<div class=formflexN2>
		'.$config_type.'
		<input style="width: 40%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=text name=smtp_nom id=smtp_nom value="' . ($smtp_get->[0]->{smtp_nom} || '') . '"  required />
		<input style="width: 40%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=text name=smtp_mail id=smtp_mail value="' . ($smtp_get->[0]->{smtp_mail} || ''). '" required/>
		</div>	
		
		<!-- Champs de configuration SMTP -->
		<div id="smtp_config" class="config_section">
		<div class=formflexN2>
		<label style="width: 20%;text-align:center;" class="forms para" for="smtp_serveur">Serveur SMTP :</label>
		<label style="width: 15%;text-align:center;" class="forms para" for="smtp_port">Port SMTP :</label>
		<label style="width: 30%;text-align:center;" class="forms para" for="smtp_user">Utilisateur SMTP :</label>
		<label style="width: 30%;text-align:center;" class="forms para" for="smtp_pass">Mot de passe SMTP :</label>
		</div>
		
		<div class=formflexN2>
		<input style="width: 20%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=text name=smtp_serveur id=smtp_serveur value="' . ($smtp_get->[0]->{smtp_serveur}|| '') . '" required/>
		<input style="width: 15%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=text name=smtp_port id=smtp_port value="' . ($smtp_get->[0]->{smtp_port}|| '') . '" required/>
		<input style="width: 30%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=text name=smtp_user id=smtp_user value="' . ($smtp_get->[0]->{smtp_user} || ''). '" required />
		<input style="width: 30%;" oninput="ModSelected(this, \'submit8\');" class="login-text" type=password name=smtp_pass id=smtp_pass value="' . ($smtp_get->[0]->{smtp_pass} || ''). '" required />
		</div>
		
		<div class=formflexN2>
		<label style="width: 30%;text-align:center;" class="forms para" for="smtp_secu">Sécurité SMTP :</label>
		<label style="width: 30%;text-align:center;" class="forms para" for="smtp_vers">Version TLS/SSL :</label>
		<label style="width: 30%;text-align:center;" class="forms para" for="submit8"></label>
		</div>
		
		<div class=formflexN2>
		'.$smtp_security.'
		'.$version_tls.'
		<input style="width: 30%;" type=submit id=submit8 style="width: 50ch;" class="btn btn-vert" value=Valider>
		</div>
	</div>
	
	<!-- Champs de configuration API -->
    <div id="api_config" class="config_section" style="display: none;">
		<label class="forms para" for="smtp_api_id">Client ID :</label><input class="login-text" type=text name=smtp_api_id id=smtp_api_id value="' . ($smtp_get->[0]->{smtp_api_id} || ''). '" />
		<label class="forms para" for="smtp_api_secret">Client Secret :</label><input class="login-text" type=text name=smtp_api_secret id=smtp_api_secret value="' . ($smtp_get->[0]->{smtp_api_secret} || ''). '" />
    </div>

	<br>

	</form></div>
	';
	
	my $decrypt_mot = '';
	
	# Formulaire HTML sélection de modéle de mail
	my $reqid = Base::Site::util::generate_reqline();
	my $info_modele_mail = Base::Site::bdd::get_template($dbh, $r, '', 'email_body');
	my $onchange_modele = '';
	my $selected_mail = (defined($args->{select_modele}) && $args->{select_modele} ne '') ? ($args->{select_modele} ) : undef;
	my ($form_name_modele, $form_id_modele) = ('select_modele', 'select_modele'.$reqid.'');
	my $search_modele_mail = Base::Site::util::generate_modele_mail($info_modele_mail, $reqid, $selected_mail, $form_name_modele, $form_id_modele, $onchange_modele, 'class="forms2_input"', 'style="width: 25%;"');
	
	############## Formulaire ajout d'une règle automatique ##############	
	my $formlist .='
			
		<div class=Titre10>Configuration des règles automatiques</div>
		<div class="form-int">
			<form method=POST onsubmit="encryptTxtArea(\'mot_form\', \'encrypted_mot\');">
			<div class=flex-checkbox>
			<div id="mot_form" style="width: 60%; text-align: left;" class="forms_focus" contenteditable="true" >' . ($decrypt_mot || '') . '</div>
			' . $search_modele_mail . '
			<input type=hidden name="encrypted_mot" id="encrypted_mot">
			<input type=hidden name="ajouter" value=1>
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
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 65%; text-align: center;">Format des mots à rechercher</span>
		<span class=headerspan style="width: 20%; text-align: center;">Modèle</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<div class=spacer></div></li>
		<script>
    // Fonction pour ajouter des écouteurs d\'événements de collage sur un élément spécifié
    function addPasteListener(element) {
        element.addEventListener("paste", function(e) {
            // Empêcher l\'événement de collage par défaut
            e.preventDefault();

            // Récupérer le texte brut du presse-papier
            const text = (e.clipboardData || window.clipboardData).getData("text");

            // Insérer le texte brut dans l\'élément
            document.execCommand("insertText", false, text);
        });
    }

    // Fonction pour observer les changements dans un élément spécifié
    function observeEditableDiv(divId, reqline) {
        var targetNode = document.getElementById(divId);

        if (!targetNode) {
            console.warn(\'Élément non trouvé : \' + divId);
            return;
        }

        // Ajout de l\'écouteur de collage à l\'élément cible
        addPasteListener(targetNode);

        // Options de l\'observateur (ce que nous voulons observer)
        var config = { childList: true, subtree: true, characterData: true };

        // Callback exécuté à chaque modification du DOM
        var callback = function(mutationsList, observer) {
            for (var mutation of mutationsList) {
                if (mutation.type === \'childList\' || mutation.type === \'characterData\') {
                    // Appeler la fonction de modification à chaque changement détecté
                    findModif(targetNode, reqline);
                }
            }
        };

        // Créer un observateur de mutation
        var observer = new MutationObserver(callback);

        // Commencer à observer le targetNode avec les options définies
        observer.observe(targetNode, config);
    }

</script>
	' ;
	
	############## génération des formulaires modifications des régles de mails existants ##############
    if (@$resultat) {
		for ( @$resultat ) {
			
			my $reqline = ($line ++);	

			my $delete_href = 'parametres&#63;email&amp;supprimer=0&amp;mot=' . URI::Escape::uri_escape_utf8($_->{config_libelle}) ;
			my $delete_link = '<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>';
			my $valid_href = 'parametres&#63;email&amp;modifier=1&amp;old_mot=' . URI::Escape::uri_escape_utf8( $_->{config_libelle} ) ;
				
			# Formulaire HTML sélection de modéle de mail
			my $selected_mail = $_->{config_compte};
			my $onchange_mod = 'onchange="findModif(this,'.$reqline.');"';
			my ($form_name_modele, $form_id_modele) = ('select_mod', 'select_mod'.$reqline.'');
			my $search_mod_mail = Base::Site::util::generate_modele_mail($info_modele_mail, $reqline, $selected_mail, $form_name_modele, $form_id_modele, $onchange_mod, 'class="forms2_input"', 'style="width: 20%;"');
			
			my $decrypt_mot_temp = $_->{config_libelle} ? Base::Site::util::decryptTextArea($_->{config_libelle},"your_secret_key") : '';

			#gestion des options checkcheck_banque
			my $check_value = ( $_->{masquer} eq 't' ) ? 'checked' : '' ;

			#Formulaire Modifier les modes de règlement existants
			$formlist .= '
				<li id="line_'.$reqline.'" class="style1">  
				<form class=flex1 method="post" action=/'.$r->pnotes('session')->{racine}.'/parametres?email onsubmit="encryptTxtArea(\'mot_'.$reqline.'\', \'encrypted_mot_'.$reqline.'\');">
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				<div id="mot_'.$reqline.'" style="width: 65%;text-align: left;" onkeyup="findModif(this,'.$reqline.');" class="displayspan forms_focus" contenteditable="true" >' . ($decrypt_mot_temp || '') . '</div>
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				'.$search_mod_mail.'
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				<span class="displayspan" style="width: 4%; text-align: center;"><input class="forms2_input" onchange="findModif(this,'.$reqline.');" title="désactiver la recherche pour ce mot" style="margin: 5px; width: 50%; height: 4ch; display: block;" type="checkbox" id="masquer_'.$reqline.'" name="masquer" value="1" '.$check_value.'></span>
				<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider" ></span>
				'.$delete_link.'
				<input type=hidden id="old_mot_'.$reqline.'" name="old_mot" value="'.$_->{config_libelle}.'">
				<input type=hidden name="encrypted_mot" id="encrypted_mot_'.$reqline.'">
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				</form>
				</li>
				<script>observeEditableDiv(\'mot_'.$reqline.'\', \''.$reqline.'\');</script>' ;
		}
		$formlist .= '</ul>';
	
	} else {
		$formlist .= '<div class="warnlite">*** Aucune Règle trouvée ***</div>';
	}
	
		
	$content .= '<div class="formulaire1" >' . $fiche_client . $formlist . Base::Site::util::form_email( $r, $args ) . '</fieldset></div></div>' ;

	
}

sub form_edit_mode_paiement {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	$args->{restart} = 'parametres?achats';
	my $selected = '';
	my $line = "1"; 

	################ Affichage MENU ################
	$content .= display_menu( $r, $args ) ;
	################ Affichage MENU ################
	
	#/************ ACTION DEBUT *************/
	
	# Passage en boulean t ou f 
	if (defined $args->{masquer} && $args->{masquer} eq '1') {
		$args->{masquer} = 't';
	} else {$args->{masquer} = 'f';}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	#1ère demande de suppression; afficher lien d'annulation/confirmation
    if ( defined $args->{achats} && defined $args->{supprimer} && $args->{supprimer} eq '0') {
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/parametres?achats' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/parametres?achats&amp;supprimer=1&amp;libelle=' . $args->{libelle} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le mode de paiement ' . $args->{libelle} . '?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{achats} && defined $args->{supprimer} && $args->{supprimer} eq '1') {
			#DELETE FROM tblconfig_liste
			$sql = 'DELETE FROM tblconfig_liste WHERE config_libelle = ? AND id_client = ? AND module = \'achats\'' ;
			@bind_array = ( $args->{libelle}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>le libellé ne peut être vide</h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{achats} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{libelle1});
		
		#on interdit libelle vide
		if (!$args->{select_journal1}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un journal') ;
		} elsif (!$args->{libelle1}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
		} elsif (!$args->{select_compte1}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un compte') ;
		} else {
			#INSERT INTO tblconfig_liste
			$sql = 'INSERT INTO tblconfig_liste (config_libelle, config_compte, config_journal, id_client, module) values (?, ?, ?, ?, \'achats\')' ;
			@bind_array = ( $args->{libelle1}, $args->{select_compte1}, $args->{select_journal1}, $r->pnotes('session')->{id_client} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>Il faut obligatoirement un libellé</h3>' ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= '<h3 class=warning>Ce libellé existe déjà</h3>' ;
				} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé 
			}
		}
    }
    
    ####################################################################### 	
	#l'utilisateur a cliqué sur 'Valider'  								  #
	#######################################################################
    if ( defined $args->{achats} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
	    
   	    #UPDATE tblconfig_liste
	    $sql = 'UPDATE tblconfig_liste set config_libelle = ?, config_compte = ?, config_journal = ?, masquer = ? where id_client = ? AND config_libelle = ? AND module = \'achats\'' ;
	    @bind_array = ( $args->{libelle}, $args->{select_compte}, $args->{select_journal}, $args->{masquer}, $r->pnotes('session')->{id_client}, $args->{old_libelle} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
	    
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>le libellé ne peut être vide</h3>' ;
			} else {$content .= '<h3 class=warning>valeur $args->{masquer} '.$args->{masquer}.' et ' . $@ . '</h3>' ;}
		} else {
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
    }
    
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	#####################################  
		
	#Requête tblconfig_liste
	my $resultat = Base::Site::bdd::get_tblconfig_liste($dbh, $r, 'achats');
	
	#Requête tbljournal_liste
	$sql = 'SELECT libelle_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $journal_req = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
	
    #Formulaire Sélectionner un journal
	my $select_journal = '<select class="login-text" style="width: 25%;" name=select_journal1 id=select_journal
	onchange="if(this.selectedIndex == 0){document.location.href=\'journal?configuration\'}">' ;
	$select_journal .= '<option class="opt1" value="">Créer un journal</option>' ;
	$select_journal .= '<option value="" selected>--Sélectionner un journal--</option>' ;
	for ( @$journal_req ) {
	if 	(defined $args->{select_journal1}) {
	$selected = ( $_->[0] eq $args->{select_journal1} ) ? 'selected' : '' ;
	}			
	$select_journal .= '<option value="' . $_->[0] . '" '.$selected.'>' . $_->[0] . '</option>' ;
	}
	$select_journal .= '</select>' ;
		
	#Formulaire Sélectionner un compte
	my $compte_req = Base::Site::bdd::get_comptes_by_classe($dbh, $r, 'all');
	my $select_compte = '<select class="login-text" style="width: 25%;" name=select_compte1 id=select_compte
	onchange="if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'}">' ;
	$select_compte .= '<option class="opt1" value="">Créer un compte</option>' ;
	$select_compte .= '<option value="" selected>--Sélectionner un compte--</option>' ;
	for ( @$compte_req ) {
	if 	(defined $args->{select_compte1}) {
	$selected = ( $_->{numero_compte} eq $args->{select_compte1} ) ? 'selected' : '' ;
	}			
	$select_compte .= '<option value="' . $_->{numero_compte} . '" '.$selected.'>' . ($_->{numero_compte}) . ' - ' .($_->{libelle_compte}).'</option>' ;
	}
	$select_compte .= '</select>' ;
    
    ############## Formulaire Configuration du mode de paiement ##############	
    my $formulaire = '
		<fieldset class="pretty-box"><legend><h3 class="Titre09">Configuration du mode de paiement</h3></legend>
		<div class=centrer>
			<div class=Titre10>Ajouter un mode de paiement <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'parametres_4\');" style="cursor: pointer;" >[?]</span></div>
			<div class="form-int">
				<form method="post" action=/'.$r->pnotes('session')->{racine}.'/parametres?achats>
					<div class=formflexN2>
					<input class="login-text" style="width: 25%;" type=text placeholder="Entrer le libellé" id=libelle name="libelle1" value="'.($args->{libelle1} || '').'" required>
					' . $select_journal . '
					' . $select_compte . '
					<input type=submit class="btn btn-vert" value=Ajouter style="width: 15%;">
					<input type=hidden name="ajouter" value=1>
					</div>
				</form>
			</div>
			
		
    ' ;
    
    #ligne des en-têtes
    $formulaire .= '
		<div class=Titre10>Modifier les modes de paiement existants</div>
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 25%; text-align: center;">Libellé</span>
		<span class=headerspan style="width: 25%; text-align: center;">Journal</span>
		<span class=headerspan style="width: 25%; text-align: center;">Compte</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
    
    ############## génération des formulaires modifications des règlements existants ##############
    if (@$resultat) {
		for ( @$resultat ) {
			
			my $reqline = ($line ++);	

			my $delete_href = 'parametres&#63;achats&amp;supprimer=0&amp;libelle=' . URI::Escape::uri_escape_utf8($_->{config_libelle}) ;
			my $delete_link = '<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>';
			my $valid_href = 'parametres&#63;achats&amp;modifier=1&amp;old_libelle=' . URI::Escape::uri_escape_utf8( $_->{config_libelle} ) ;
			my $disabled = ( $_->{config_libelle} eq 'Temp' ) ? ' disabled' : '' ;
				
			#select_journal
			my $selected_journal = $_->{config_journal};
			my $select_journal = '<select class="formMinDiv4" name=select_journal id=select_journal_'.$reqline.' 
			onchange="findModif(this,'.$reqline.');if(this.selectedIndex == 0){document.location.href=\'journal?configuration\'};">' ;
			$select_journal .= '<option class="opt1" value="">Créer un journal</option>' ;
			$select_journal .= '<option value="">--Sélectionner un journal--</option>' ;
			for ( @$journal_req ) {
			my $selected = ( $_->[0] eq $selected_journal) ? 'selected' : '' ;
			$select_journal .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
			}
			$select_journal .= '</select>' ;

			#select_compte
			my $selected_compte = $_->{config_compte};
			my $select_compte = '<select class="formMinDiv4" name=select_compte id=select_compte_'.$reqline.' 
			onchange="findModif(this,'.$reqline.');if(this.selectedIndex == 0){document.location.href=\'compte?configuration\'};">' ;
			$select_compte .= '<option class="opt1" value="">Créer un compte</option>' ;
			$select_compte .= '<option value="">--Sélectionner un compte--</option>' ;
			for ( @$compte_req ) {
			my $selected = ( $_->{numero_compte} eq $selected_compte ) ? 'selected' : '' ;
			$select_compte .= '<option value="' . $_->{numero_compte} . '" ' . $selected . '>' . ($_->{numero_compte}) . ' - ' .($_->{libelle_compte}).'</option>' ;
			}
			$select_compte .= '</select>' ;	
			
			#gestion des options checkcheck_banque
			my $check_value = ( $_->{masquer} eq 't' ) ? 'checked' : '' ;

			#Formulaire Modifier les modes de règlement existants
			$formulaire .= '
				<li id="line_'.$reqline.'" class="style1">  
				<form class=flex1 method="post" action=/'.$r->pnotes('session')->{racine}.'/parametres?achats>
				<span class=displayspan style="width: 0.3%;">&nbsp;</span>
				<span class=displayspan style="width: 25%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name=libelle value="' . $_->{config_libelle} . '" ' . $disabled . '/></span>
				<span class=displayspan style="width: 25%;">'.$select_journal.'</span>
				<span class=displayspan style="width: 25%;">'.$select_compte.'</span>
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				<span class="displayspan" style="width: 4%; text-align: center;"><input class="forms2_input" onchange="findModif(this,'.$reqline.');" title="désactiver le mode de paiement" style="margin: 5px; width: 50%; height: 4ch; display: block;" type="checkbox" id="masquer" name="masquer" value="1" '.$check_value.'></span>
				<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider" '.$disabled.'></span>
				'.$delete_link.'
				<input type=hidden name="old_libelle" value="'.$_->{config_libelle}.'">
				<span class=displayspan style="width: 0.5%;">&nbsp;</span>
				</form>
				</li>' ;
		}
		$formulaire .= '</ul></fieldset>';
	
	} else {
		$formulaire .= '<div class="warnlite">*** Aucun mode de paiement trouvé ***</div>';
	}	

	$content .= '<div class="formulaire2">' . $formulaire . '</div>' ;

    return $content ;
    
    ############## MISE EN FORME FIN ##############
    
} #sub form_edit_mode_paiement 

sub utilisateurs {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content) ;
    my $selected = '';
    $args->{restart} = 'parametres?utilisateurs';
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

	######## Affichage MENU display_menu Début ######
	$content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
    if (not(defined $args->{username})) {
	$args->{username} = $r->pnotes('session')->{username};	
	}

	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    #demande de suppression; afficher lien d'annulation/confirmation
	if ( defined $args->{utilisateurs} && defined $args->{supprimer} ) {
		
		#on interdit username/userpass vide
		$args->{username} ||= undef ;
		$args->{userpass} ||= undef ;
		
		if (defined $args->{supprimer} && $args->{supprimer} eq '0') { 
			my $non_href = '/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs' ;
			my $oui_href = '/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs&amp;supprimer=1&amp;username=' . $args->{username} ;
			$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer l\'utilisateur ' . $args->{username} . '?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
		} elsif (defined $args->{supprimer} && $args->{supprimer} eq '1') {
			if (defined $args->{username} && $args->{username} eq 'superadmin') {
			$content .= Base::Site::util::generate_error_message('Impossible de supprimer l\'utilisateur SUPERADMIN !!!') ;	
			} else {
				#demande de suppression confirmée
				$sql = 'DELETE FROM compta_user WHERE username = ? AND NOT username = \'superadmin\'' ;
				@bind_array = ( $args->{username} ) ;
				eval {$dbh->do( $sql, undef, @bind_array ) } ;
				if ( $@ ) {
					$content .= '<h3 class=warning>' . $@ . '</h3>' ;
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Suppression de l\'utilisateur '.$args->{username}.'');
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé 
				}
			}
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{utilisateurs} && defined $args->{ajouter} && $args->{ajouter} eq '1' ) {
		
		#on interdit username/userpass vide
		$args->{username} ||= undef ;
		$args->{userpass} ||= undef ;
	
		#si le nom n'est pas renseigné, mettre l'e-mail
		$args->{nom} ||= $args->{username} ;
		
	    #ajouter un utilisateur
	    $sql = 'INSERT INTO compta_user (is_main, username, userpass, nom, prenom, preferred_datestyle, id_client, debug, dump) values (0, ?, ?, ?, ?, ?, ?, ?, ?)' ;
	    @bind_array = ( $args->{username}, $args->{userpass}, $args->{nom}, $args->{prenom}, $args->{preferred_datestyle}, $args->{select_client}, $args->{debug_select}, $args->{dump_select} ) ;
	    eval {$dbh->do( $sql, undef, @bind_array ) } ;
		
		if ( $@ ) {
			if ( $@ =~ /NOT NULL/ ) {$content .= '<h3 class=warning>Il faut obligatoirement un libellé</h3>' ;
			} elsif ( $@ =~ /existe|already exists/ ) {$content .= '<h3 class=warning>L\'utilisateur '.$args->{username}.' existe déjà !!</h3>' ;
			} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
		} else {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Création de l\'utilisateur '.$args->{username}.'');
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 
		}
	}
	
	####################################################################### 
	#l'utilisateur a cliqué sur 'Valider' la modification 				  #
	#######################################################################
    if ( defined $args->{utilisateurs} && defined $args->{modifier} && $args->{modifier} eq '1' ) {
		# Vérifier si l'utilisateur tente de renommer le superadmin
		if (($args->{selection_utilisateur} eq 'superadmin') && (not($args->{username} eq 'superadmin'))) {
			$content .= '<div class=warning><h3>Impossible de renommer l\'identifiant de superadmin !!!</h3></div>' ;	
		} else {
	    # Préparer la requête SQL pour la mise à jour de l'utilisateur
	    $sql = 'UPDATE compta_user set username = ?, userpass = ?, preferred_datestyle = ?, nom = ?, prenom = ?, id_client = ? , debug = ? , dump = ? where username = ? ' ;
	    @bind_array = ( $args->{username}, $args->{userpass}, $args->{preferred_datestyle}, $args->{nom}, $args->{prenom}, $args->{select_client}, $args->{debug_select}, $args->{dump_select}, $args->{selection_utilisateur}  ) ;
		eval {$dbh->do( $sql, undef, @bind_array ) } ;
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {
				$content .= '<h3 class=warning>Il faut renseigner E-mail et Mot de passe</h3>' ;
				} elsif ( $@ =~ /existe|already exists/ ){
				$content .= '<h3 class=warning>L\'utilisateur existe déjà</h3>' ;
				} else {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;}
			} else {
				if ($args->{username} eq $r->pnotes('session')->{username}) {
					 # Mettre à jour les données de session si l'utilisateur met à jour son propre compte
            		$r->pnotes('session')->{preferred_datestyle} = $args->{preferred_datestyle} || $r->pnotes('session')->{preferred_datestyle} ;
					$r->pnotes('session')->{dump} = $args->{dump_select} ;
					$r->pnotes('session')->{debug} = $args->{debug_select} ;
					Base::Site::logs::redirect_sig(defined $args->{debug} && $args->{debug} eq '1' ? 1 : 0);
					freeze_session( $r ) ;
					$args->{restart} = 'parametres?utilisateurs&modification_utilisateur=1';
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé
				}
			} #	if ( $@ ) 
		}
	}
    
    #/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	##################################### 
	
	$sql = 'SELECT id_client, username, userpass, preferred_datestyle, coalesce(nom, \'\') as nom, coalesce(prenom, \'\') as prenom, is_main, debug, dump FROM compta_user WHERE username = ? ' ;
	my $client_get = $dbh->selectall_arrayref( $sql, { Slice => { } }, ($args->{username} ) ) ;
	
	#Requête sélection des utilisateurs
	my $get_all_user = Base::Site::bdd::get_all_user($dbh, $r);
	my $selected_user = ((defined($args->{selection_utilisateur}) && $args->{selection_utilisateur} ne '') || defined $args->{username} || $client_get->[0]->{username}) ? ($args->{selection_utilisateur} || $args->{username} || $client_get->[0]->{username} ) : undef;
	my ($form_name_user, $form_id_user) = ('username', 'username');
	my $utilisateurs_select = Base::Site::util::generate_user_selector($get_all_user, undef, $selected_user, $form_name_user, $form_id_user, '', 'class="login-text"', 'style="width: 20%"');
	
	#Requête sélection des sociétés 
	my $all_societe = Base::Site::bdd::get_all_societe($dbh, $r);
	my $selected_societe = ((defined($args->{select_client}) && $args->{select_client} ne '') || $client_get->[0]->{id_client}) ? ($args->{select_client} || $client_get->[0]->{id_client} ) : undef;
	my ($form_name_societe, $form_id_societe) = ('select_client', 'select_client');
	my $societe_select = Base::Site::util::generate_societe_selector($all_societe, undef, $selected_societe, $form_name_societe, $form_id_societe, 'onchange="Yelloback(this.id);ModSelected(this);"', 'class="login-text"', '');
    
	# sélection préférence d'affichage des dates 
    my $datestyle_select = Base::Site::util::generate_simple_select('preferred_datestyle', 'preferred_datestyle', 'login-text', [['iso', 'AAAA-MM-JJ'], ['SQL, dmy', 'JJ/MM/AAAA']], $args->{modification_utilisateur} ? $args->{preferred_datestyle} : "", $args->{modification_utilisateur} ? $client_get->[0]->{preferred_datestyle} : "", 'onchange="Yelloback(this.id);ModSelected(this);"', 'SQL, dmy');
    #sélection mode debug 
    my $debug_select = Base::Site::util::generate_simple_select('debug_select', 'debug_select', 'login-text', [['1', 'Oui'], ['2', 'Non']], $args->{debug_select}, $args->{modification_utilisateur} ? $client_get->[0]->{debug} : "", 'onchange="Yelloback(this.id);ModSelected(this);"', '2');
    
    #sélection mode dump
	if (defined $args->{dump} && $args->{dump} eq 2) { $args->{dump_select} = 2;}
    my $dump_select = Base::Site::util::generate_simple_select('dump_select', 'dump_select', 'login-text', [['1', 'Oui'], ['2', 'Non']], $args->{dump_select}, $args->{modification_utilisateur} ? $client_get->[0]->{dump} : "", 'onchange="Yelloback(this.id);ModSelected(this);"', '2');

    my $delete_href = 'parametres&#63;utilisateurs&amp;supprimer=0' ;
	my $delete_link = '<input type="submit" class="btn btn-rouge" style ="width : 25%;" formaction="' . $delete_href . '" value="Supprimer" >' ;	

   
	############## Formulaire Gestion des utilisateurs ##############	
    my $client_list .= '

		<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des utilisateurs</h3></legend>
		<div class="centrer">
		
		<form class="gooflex2" method=POST>
		<input type="submit" class="respbtn btn-vert flex-21" formaction="parametres&#63;utilisateurs&amp;creation_utilisateur=1" value="Créer un nouvel utilisateur" >
		</form>
	  
		<div class=Titre10>Modifier un utilisateur existant</div>
		<div class="form-int">
		<form method=POST>
		<input type=hidden name=societe value=0>
		'.$utilisateurs_select.'
		<br><br>
		
		<input type=submit class="btn btn-gris" style ="width : 25%;" formaction="parametres&#63;utilisateurs&amp;modification_utilisateur=1" value=Modifier>
		'.$delete_link	.'
		<br><br>
		
		</form></div>
 	';
 	
 	if ((defined $args->{creation_utilisateur}) && ($args->{creation_utilisateur} eq 1)) {
		#formulaire nouvel utilisateur	
		$client_list .= '
    	<div class=Titre10>Création d\'un nouvel utilisateur</div>
		<div class="form-int">
		<form method=POST action=/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs>
		
		
        <label class="forms para" for="username">Identifiant :</label>
        <input class="login-text" placeholder="Entrer l\'identifiant" type=text name=username id=username2 value="" required/>
        <label class="forms para" for="userpass">Mot de passe :</label>
	    <input class="login-text" placeholder="Entrer le mot de passe" type=text name=userpass id=userpass value="" required/>
	    <label class="forms para" for="nom">Nom :</label>
		<input placeholder="Entrer le nom de l\'utilisateur" class="login-text" type=text name=nom id=nom value="" />
		<label class="forms para" for="nom">Prénom :</label>
		<input placeholder="Entrer le prénom de l\'utilisateur" class="login-text" type=text name=prenom id=prenom value="" />
		<label class="forms para" for="preferred_datestyle">Affichage des dates :</label>
		' . $datestyle_select . '
		<label class="forms para" for="preferred_datestyle">Société de rattachement :</label>
		' . $societe_select . '
		<label class="forms para" for="debug">Activer le mode debug log :</label>
		' . $debug_select . '
		<label class="forms para" for="dump">Activer le mode dump :</label>
		' . $dump_select . '
		<input type=hidden name=ajouter value=1>
		<br><br>
		<label class="forms para" for="submit7"></label>
		<input type=submit id=submit7 style="width: 50ch;" class="btn btn-vert" value=Ajouter>
		</form>
		<br>
		' ;
	
	} elsif ((defined $args->{modification_utilisateur}) && ($args->{modification_utilisateur} eq 1)) {
    
		$client_list .= '
		<div class=Titre10>Modification de l\'utilisateur : '. $args->{username}.'</div>
		<div class="form-int">
		' ;

		$sql = 'SELECT id_client, username, userpass, preferred_datestyle, coalesce(nom, \'\') as nom, coalesce(prenom, \'\') as prenom, is_main, debug, dump FROM compta_user WHERE username = ? ' ;

		my $client_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ($args->{username} ) ) ;

		for ( @$client_set ) {

			my $disabled = ( $_->{username} eq 'superadmin' ) ? ' disabled' : '' ;
			
			$client_list .= '
			<form method=POST action=/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs>
			<label class="forms para" for="username">E-mail :</label>
			<input oninput="ModSelected(this);Yelloback(this.id);" class="login-text" type=text name=username id=username value="' . $_->{username} . '" '.$disabled.'/>
			<label class="forms para" for="userpass">Mot de passe :</label>
			<input oninput="ModSelected(this);Yelloback(this.id);" class="login-text" type=text name=userpass id=userpass value="' . $_->{userpass} . '" />
			<label class="forms para" for="nom">Nom :</label>
			<input oninput="ModSelected(this);Yelloback(this.id);" class="login-text" type=text name=nom id=nom value="' . $_->{nom} . '" />
			<label class="forms para" for="prenom">Prénom :</label>
			<input oninput="ModSelected(this);Yelloback(this.id);" class="login-text" type=text name=prenom id=prenom value="' . $_->{prenom} . '" />
			<label class="forms para" for="preferred_datestyle">Affichage des dates :</label>
			' . $datestyle_select . '
			<label class="forms para" for="preferred_datestyle">Société de rattachement :</label>
			' . $societe_select . '
			<label class="forms para" for="debug">Activer le mode debug log:</label>
			' . $debug_select . '
			<label class="forms para" for="dump">Activer le mode dump :</label>
			' . $dump_select . '
			<br><br>
			<label class="forms para" for="submit1"></label>
			<input type=hidden name=selection_utilisateur value="'.$_->{username}.'">
			<input type=hidden name=modifier value=1>
			<input type=hidden name=modification_utilisateur value=1>
			<input type=submit id=submit1 style="width: 50ch;" class="btn btn-vert" formaction="parametres&#63;utilisateurs" value=Valider>
			</div>
			</form>
			';
		}
	
	}
	
	# Vérifiez si l'argument "dump" est défini
	if (defined $args->{dump} && $args->{dump} eq 2) {
		# Effectuez l'action de mise au point ici
		$client_list .= '
		<script>
		// Fonction pour mettre le focus sur un élément et changer sa couleur
		function focusAndChangeColor() {
			var selectElement = document.getElementById("dump_select");
			Yelloback(selectElement.id)
			selectElement.focus();
			ModSelected(selectElement);
		  
		}
		focusAndChangeColor();
		</script>
		';

	}


    $client_list .= '</div></div></fieldset>';
	$content .= '<div class="formulaire1" >' . $client_list . '</div>' ;

    return $content ;
    
} #sub utilisateurs 

sub freeze_session {
    my $r = shift ;
    my $dbh = $r->pnotes('dbh') ;
    #il faut mettre à jour la session
    my $sql = 'update sessions set serialized_session = ?  where session_id = ?';
    my $serialized = Storable::nfreeze($r->pnotes('session'));
    my $sth = $dbh->prepare($sql);
    $sth->bind_param( 1, $serialized,  { pg_type => DBD::Pg::PG_BYTEA } );
    $sth->bind_param( 2, $r->pnotes('session')->{_session_id} );
    $sth->execute();
}#sub freeze_session

sub logout {
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array ) ;
    my $confirm_logout_href = '/'.$r->pnotes('session')->{racine}.'/logout' ;
	my $deny_logout_href = '/'.$r->pnotes('session')->{racine}.'/compte' ;
	my $content .= '<div class="menu" >';
	$content .= Base::Site::util::generate_error_message('Voulez-vous fermer la session de l\'utilisateur ' . $r->pnotes('session')->{'username'} .' ?<br><a class=nav href="' . $confirm_logout_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_logout_href . '" style="margin-left: 3em;">Non</a>') ;
	$content .= '</div>';
	return $content ;
}#sub logout

sub logs {
    # définition des variables
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $lines_to_show = $args->{lines} || 150;  # Nombre de lignes à afficher
    $args->{restart} = 'parametres?logs';
    
	######## Affichage MENU display_menu Début ######
	$content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########

	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'purger les logs' 			  #
	#######################################################################
	#première demande de purge des logs; réclamer confirmation
	if ( defined $args->{purge} and $args->{purge} eq '0') {
	    my $confirm_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?logs=&amp;purge=1' ;
	    my $deny_delete_href = '/'.$r->pnotes('session')->{racine}.'/parametres?logs' ;
	    $content .= Base::Site::util::generate_error_message('Voulez-vous purger les logs ?<br><a class=nav href="' . $confirm_delete_href . '" style="margin-left: 3em;">Oui</a><a class=nav href="' . $deny_delete_href . '" style="margin-left: 3em;">Non</a>') ;

	} elsif ( defined $args->{purge} and $args->{purge} eq '1' ) {
		my $fichier = $r->document_root() . '/Compta/base/logs/Compta.log' ;
	    #purge du fichier de log
	    open (my $fh, ">:encoding(UTF-8)", $fichier) or die "Impossible d'ouvrir le fichier $fichier : $!" ;
	    close ($fh);
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'parametres.pm => Purge du fichier de log');
		Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
		return Apache2::Const::OK;  # Indique que le traitement est terminé 
	}
	
	#/************ ACTION FIN *************/
		
	############## Formulaire Gestion des logs ##############		
	my $contenu_web .= '
		<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des logs</h3></legend>
		<div style="width: max-content;">
		<div >
	';
	
    # Affichage des logs
	my $chars_to_show = $args->{chars} || 7500;  # Nombre de caractères à afficher
    my $log_content = '';
    my @recent_lines;  # Déclaration de la variable

    my $log_file = "/var/www/html/Compta/base/logs/Compta.log";

    open my $fh, "<:encoding(UTF-8)", $log_file or die "Impossible d'ouvrir le fichier $log_file : $!";

    my $seek_offset = $chars_to_show >= 5000 ? -$chars_to_show : 0;
    seek $fh, $seek_offset, 2;  # Se déplacer à partir de la fin

    while (my $line = <$fh>) {
        chomp $line;
        $log_content .= "<br>$line";
    }

    close $fh;

    my $formatted_logs = '<fieldset class="pretty-box"><legend><h3 class="Titre09">Gestion des logs</h3></legend><div style="width: max-content;"><div >' . $log_content . '</div></div></fieldset>';

    my $load_more_link = '';
    my $purge_link = '<a style="width : 25%;" class="btn btn-rouge" href="/' . $r->pnotes('session')->{racine} . '/parametres?logs&amp;purge=0">Purger les logs</a>';

    if ($chars_to_show >= 5000) {
        $load_more_link = '<a style="width : 25%;" class="btn btn-orange" href="/' . $r->pnotes('session')->{racine} . '/parametres?logs&chars=' . ($chars_to_show + 5000) . '">Afficher plus</a>';
    }

    $content .= '<div class="wrapper">' . $formatted_logs . '</div><div class="wrapper centrer">' . $load_more_link . $purge_link .'</div>';

    return $content;
}

sub dev{

	# définition des variables
	my ( $r, $args ) = @_ ;
    my $req = Apache2::Request->new($r);
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $modified_script = "";  # Initialisation de la variable
    $args->{restart} = 'parametres?logs';

    
	######## Affichage MENU display_menu Début ######
	$content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	
	################################################################# 
	# génération du choix de documents				 				#
	#################################################################

	#recherche de la liste des documents enregistrés
    $sql = '
    SELECT id_name, fiscal_year
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception' ;	
    
    my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 ) ;
	my ($id_name, $document_select1);
	
	# Sélection par default du "choix docs1" 
	if (!defined $args->{docs1} && (!defined $args->{docs_doc_entry} && !defined $args->{label8})){
    $document_select1 = '<select class="login-text" style="width: 40%;" name=docs1 id=docs14>
    <option value="" selected>--Sélectionner le document--</option>' ;
	} else {
    $document_select1 = '<select class="login-text" style="width: 40%;" name=docs1 id=docs14>
    <option value="" >--Sélectionner le document--</option>' ;
	}
	
    for ( @$array_of_documents )   {
		unless ( $_->{id_name} eq (defined $id_name )) {
			my $fiscal_year = defined $_->{fiscal_year} ? $_->{fiscal_year} : '';  # Initialisation avec une valeur par défaut si non définie
			my $selected1 = (($_->{id_name} eq ($args->{docs1} || '')) || ($_->{id_name} eq ($args->{docs_doc_entry} || '') && ($args->{label8} || '') eq 1)) ? 'selected' : '' ;
			$document_select1 .= '<option value="' . $_->{id_name} . '" '.$selected1.'>' . $_->{id_name} . '</option>' ;
	    }
		$id_name = $_->{id_name} ;	
    }
    
    $document_select1 .= '</select>' ;


       #/************ ACTION DEBUT *************/
    
    if (defined $args->{bt_test_script} && $args->{bt_test_script} eq '1') {
		my $req = Apache2::Request->new($r);
		my $selected_document = $req->param('docs1');  # Récupérer le document sélectionné
        my $encrypted_base64_script = $req->param('encrypted_script');
        my $encoded_script = decode_base64($encrypted_base64_script); # Décodage Base64
        my $decrypted_script = decode_xor($encoded_script, "your_secret_key");  # Décryptage XOR
		#$content .= '<div class="info">Contenu du textarea decrypted_script:<br><pre>' . $decrypted_script . '</pre></div>';


    if ($decrypted_script) {
        my $output_file = '/var/www/html/Compta/base/logs/script_output.pl';
        
	if ($selected_document) {
		my $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?';
		my $array_of_documents = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{docs1});
		my $base_dir = $r->document_root() . '/Compta/base/documents/';
		my $archive_dir = $base_dir . $r->pnotes('session')->{id_client} . '/' . $array_of_documents->[0]->{fiscal_year} . '/';

		# Modifier le script pour inclure le chemin du fichier PDF
		my $pdf_path = $archive_dir . $selected_document;

		$modified_script = $decrypted_script;
		#$modified_script =~ s/my \$pdf_content = \$ARGV\[0\];/my \$pdf_content = "$pdf_path";/;
		
		$modified_script =~ s/(my \$pdf_(?:file|content|path) = )\S+;/$1"$pdf_path";/;
		#$content .= '<div class="info">Contenu textarea avec documents :<br><pre>' . $modified_script . '</pre></div>';

		# Écrire le script modifié dans un fichier temporaire
		open my $fh, '>:utf8', $output_file or die "Impossible d'ouvrir le fichier $output_file : $!";
		print $fh $modified_script;
		close $fh;
	} else {
		$modified_script = $decrypted_script;
		# Écrire le script déchiffré dans un fichier temporaire
		open my $fh, '>:utf8', $output_file or die "Impossible d'ouvrir le fichier $output_file : $!";
		print $fh $decrypted_script;
		close $fh;
    }
    
    # Mettre à jour la sortie modifiée
	$content .= '<script>document.getElementById("scriptOutput").textContent = ' . encode_entities($modified_script) . ';</script>';
	
        
		# Rendre le fichier exécutable
		system("chmod +x $output_file");

        # Exécuter le script Perl en utilisant la fonction open et capturer la sortie
        my $output = qx(/usr/bin/perl $output_file);
        
		if ($?) {
			$content .= '<div class="error">Erreur lors de l\'exécution du script : ' . $! . '<br>Sortie du script :<br><pre>' . encode_entities($output) . '</pre></div>';
		}
        
        # Convertir la sortie en UTF-8 pour un affichage correct
		$output = decode('utf-8', $output);
		

        # Supprimer le fichier de sortie temporaire
        unlink $output_file;


        # Afficher le résultat dans une div avec la classe "warning"
        $content .= '
        <div class="warning">
        <div style="text-align: center;"><button onclick="copyOutput()">Copier la sortie</button></div><br>
        Sortie du script :<br><pre id="scriptOutputOriginal">' . encode_entities($output) . '</pre></div>';
    } else {
        $content .= '<div class="error">Aucun script Perl fourni.</div>';
    }
    }

    #/************ ACTION FIN *************/
    
    ############## Formulaire Gestion des tests de dev ##############
    my $contenu_web .= '
<script>
function encryptTextArea() {
    var key = "your_secret_key";
    var text = document.getElementById("script").value;

    // Chiffrement XOR
    var encryptedText = encryptXOR(text, key);

    // Encodage en base64
    var base64Text = btoa(encryptedText);

    // Mettre le texte encodé en base64 dans le champ de formulaire caché
    document.getElementById("encrypted_script").value = base64Text;
    
}

function encryptXOR(text, key) {
    var encryptedText = "";
    for (var i = 0; i < text.length; i++) {
        encryptedText += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return encryptedText;
}

function copyOutput() {
    var modifiedScript = document.getElementById("script").value; // Récupérer le contenu modifié du script dans le textarea
    var originalOutput = document.getElementById("scriptOutputOriginal").textContent;
    
    var textArea = document.createElement("textarea");
    textArea.value = "Script Modifié :\n" + modifiedScript + "\n\nSortie Origine :\n" + originalOutput;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);
    alert("La sortie a été copiée !");
}

function updateDownloadLink(scriptContent) {
    var downloadButton = document.getElementById("downloadButton");
    var encodedScriptContent = encodeURIComponent(scriptContent);
    
    downloadButton.setAttribute("href", "data:text/plain;charset=utf-8," + encodedScriptContent);
    downloadButton.setAttribute("download", "script_perl.pl");
}

function copyTextToClipboard(text) {
    var textArea = document.createElement("textarea");
    textArea.value = text;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);
}

function downloadScript() {
    var scriptContent = document.getElementById("script").value;

    // Demander le nom de fichier à l\'utilisateur
    var suggestedFileName = "script_perl.pl"; // Nom de fichier suggéré
    var userFileName = prompt("Saisissez le nom du fichier:", suggestedFileName);

    if (userFileName !== null) { // Si l\'utilisateur n\'annule pas la boîte de dialogue

        var blob = new Blob([scriptContent], { type: "text/plain;charset=utf-8" });
        var downloadUrl = URL.createObjectURL(blob);

        var downloadLink = document.createElement("a");
        downloadLink.href = downloadUrl;
        downloadLink.download = userFileName; // Utiliser le nom de fichier saisi par l\'utilisateur

        document.body.appendChild(downloadLink);
        downloadLink.click();

        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadUrl);
    }
}

function importScript(event) {
    const file = event.target.files[0];
    if (file) {
        const reader = new FileReader();

        reader.onload = function(e) {
            const scriptTextArea = document.getElementById("script");
            scriptTextArea.value = e.target.result;
        }

        reader.readAsText(file);
    }
}


</script>
    
                <fieldset class="pretty-box">
            <legend><h3 class="Titre09">Gestion des tests</h3></legend>
            <div class="centrer">
                <div class="Titre10">Test de Script Perl</div>
                <div class="form-int">
				<form action=/'.$r->pnotes('session')->{racine}.'/parametres?dev method="post" enctype="multipart/form-data" onsubmit="encryptTextArea();" accept-charset="UTF-8">

					<label style="width: 26%;" class="forms" for="docs14">Sélectionner le document</label>
					'.$document_select1.'
					<br><br>
					<label style="width: 75%;" class="forms" for="script">Copiez-collez le script Perl ici :</label>
					<pre><textarea name="script" id="script" rows="20" cols="80" required>' . $modified_script . '</textarea></pre>
					<br>
					<input type="submit" class="btn btn-vert" value="Tester le script" style="width: 25%;">
					<a id="downloadButton" class="btn btn-orange" style="width: 25%;" onclick="downloadScript()">Sauvegarder le script</a>
					<input type="file" accept=".pl" onchange="importScript(event)">
					<input type="hidden" name="bt_test_script" value="1">
					<input type="hidden" name="encrypted_script" id="encrypted_script">
				</form>
                <br><hr><br>
                <!-- lien vers Adminer -->
                <a href="' . Base::Site::util::build_adminer_url($r) . '" target="_blank">Ouvrir Adminer</a>
                
                </div>
            </div>
        </fieldset>
    ';

    $content .= '<div class="formulaire1">' . $contenu_web . '</div>';
    return $content;
}

sub dev2 {

	# définition des variables
	my ( $r, $args ) = @_ ;
    my $req = Apache2::Request->new($r);
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $modified_script = "";  # Initialisation de la variable
    $args->{restart} = 'parametres?logs';

    
	######## Affichage MENU display_menu Début ######
	$content .= display_menu( $r, $args ) ;
	######## Affichage MENU display_menu Fin ########
	################################################################# 
	# génération du choix de documents				 				#
	#################################################################

	#recherche de la liste des documents enregistrés
    $sql = '
    SELECT id_name, fiscal_year
    FROM tbldocuments 
	WHERE id_client = ? AND (fiscal_year = ? OR (multi = \'t\' AND (last_fiscal_year IS NULL OR last_fiscal_year >= ?))) ORDER BY id_name, date_reception' ;	
    
    my @bind_array_1 = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year}) ;	
    my $array_of_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array_1 ) ;
	my ($id_name, $document_select1);
	
	# Sélection par default du "choix docs1" 
	if (!defined $args->{docs1} && (!defined $args->{docs_doc_entry} && !defined $args->{label8})){
    $document_select1 = '<select class="login-text" style="width: 40%;" name=docs1 id=docs14>
    <option value="" selected>--Sélectionner le document--</option>' ;
	} else {
    $document_select1 = '<select class="login-text" style="width: 40%;" name=docs1 id=docs14>
    <option value="" >--Sélectionner le document--</option>' ;
	}
	
    for ( @$array_of_documents )   {
		unless ( $_->{id_name} eq (defined $id_name )) {
			my $fiscal_year = defined $_->{fiscal_year} ? $_->{fiscal_year} : '';  # Initialisation avec une valeur par défaut si non définie
			my $selected1 = (($_->{id_name} eq ($args->{docs1} || '')) || ($_->{id_name} eq ($args->{docs_doc_entry} || '') && ($args->{label8} || '') eq 1)) ? 'selected' : '' ;
			$document_select1 .= '<option value="' . $_->{id_name} . '" '.$selected1.'>' . $_->{id_name} . '</option>' ;
	    }
		$id_name = $_->{id_name} ;	
    }
    
    $document_select1 .= '</select>' ;


       #/************ ACTION DEBUT *************/
    
    if (defined $args->{bt_test_script} && $args->{bt_test_script} eq '1') {
		my $req = Apache2::Request->new($r);
		my $selected_document = $req->param('docs1');  # Récupérer le document sélectionné
        my $encrypted_base64_script = $req->param('encrypted_script');
        my $encoded_script = decode_base64($encrypted_base64_script); # Décodage Base64
        my $decrypted_script = Base::Site::util::decode_xor_and_base64($encoded_script, "your_secret_key");  # Décryptage XOR
		#$content .= '<div class="info">Contenu du textarea decrypted_script:<br><pre>' . $decrypted_script . '</pre></div>';

    if ($decrypted_script) {
        my $output_file = '/var/www/html/Compta/base/logs/script_output.pl';
        
	if ($selected_document) {
		my $sql = 'SELECT id_name, date_reception, montant/100::numeric as montant, libelle_cat_doc, fiscal_year, last_fiscal_year FROM tbldocuments WHERE id_name = ?';
		my $array_of_documents = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{docs1});
		my $base_dir = $r->document_root() . '/Compta/base/documents/';
		my $archive_dir = $base_dir . $r->pnotes('session')->{id_client} . '/' . $array_of_documents->[0]->{fiscal_year} . '/';

		# Modifier le script pour inclure le chemin du fichier PDF
		my $pdf_path = $archive_dir . $selected_document;

		$modified_script = $decrypted_script;
		#$modified_script =~ s/my \$pdf_content = \$ARGV\[0\];/my \$pdf_content = "$pdf_path";/;
		
		$modified_script =~ s/(my \$pdf_(?:file|content|path) = )\S+;/$1"$pdf_path";/;
		#$content .= '<div class="info">Contenu textarea avec documents :<br><pre>' . $modified_script . '</pre></div>';

		# Écrire le script modifié dans un fichier temporaire
		open my $fh, '>:utf8', $output_file or die "Impossible d'ouvrir le fichier $output_file : $!";
		print $fh $modified_script;
		close $fh;
	} else {
		$modified_script = $decrypted_script;
		# Écrire le script déchiffré dans un fichier temporaire
		open my $fh, '>:utf8', $output_file or die "Impossible d'ouvrir le fichier $output_file : $!";
		print $fh $decrypted_script;
		close $fh;
    }
    
    # Mettre à jour la sortie modifiée
	$content .= '<script>document.getElementById("scriptOutput").textContent = ' . encode_entities($modified_script) . ';</script>';
	
        
		# Rendre le fichier exécutable
		system("chmod +x $output_file");

		# Exécuter le script Perl en utilisant la fonction open et capturer la sortie et le code de sortie
		my $output = qx(/usr/bin/perl $output_file 2>&1);  # Capture à la fois la sortie standard et les erreurs

		if ($?) {
			my $exit_code = $? >> 8;  # Obtenir le code de sortie du processus
			my $error_message = "Erreur lors de l'exécution du script (Code de sortie : $exit_code):\n$output";
			#$content .= '<div class="error">' . encode_entities($error_message) . '</div>';
		}
		
        # Convertir la sortie en UTF-8 pour un affichage correct
		$output = decode('utf-8', $output);

        # Supprimer le fichier de sortie temporaire
        unlink $output_file;

        # Afficher le résultat dans une div avec la classe "warning"
        $content .= '
        <div class="warning">
        <div style="text-align: center;"><button onclick="copyOutput()">Copier la sortie</button></div><br>
        Sortie du script :<br><pre id="scriptOutputOriginal">' . encode_entities($output) . '</pre></div>';
    } else {
        $content .= '<div class="error">Aucun script Perl fourni.</div>';
    }
    }

    #/************ ACTION FIN *************/
    
    ############## Formulaire Gestion des tests de dev ##############
    my $contenu_web .= '
<script>
function encryptTextArea() {
    var key = "your_secret_key";
    var text = document.getElementById("script").value;

    // Chiffrement XOR
    var encryptedText = encryptXOR(text, key);

    // Encodage en base64
    var base64Text = btoa(encryptedText);

    // Mettre le texte encodé en base64 dans le champ de formulaire caché
    document.getElementById("encrypted_script").value = base64Text;
    
}

function encryptXOR(text, key) {
    var encryptedText = "";
    for (var i = 0; i < text.length; i++) {
        encryptedText += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return encryptedText;
}

function copyOutput() {
    var modifiedScript = document.getElementById("script").value; // Récupérer le contenu modifié du script dans le textarea
    var originalOutput = document.getElementById("scriptOutputOriginal").textContent;
    
    var textArea = document.createElement("textarea");
    textArea.value = "Script Modifié :\n" + modifiedScript + "\n\nSortie Origine :\n" + originalOutput;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);
    alert("La sortie a été copiée !");
}

function updateDownloadLink(scriptContent) {
    var downloadButton = document.getElementById("downloadButton");
    var encodedScriptContent = encodeURIComponent(scriptContent);
    
    downloadButton.setAttribute("href", "data:text/plain;charset=utf-8," + encodedScriptContent);
    downloadButton.setAttribute("download", "script_perl.pl");
}

function copyTextToClipboard(text) {
    var textArea = document.createElement("textarea");
    textArea.value = text;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);
}

function downloadScript() {
    var scriptContent = document.getElementById("script").value;

    // Demander le nom de fichier à l\'utilisateur
    var suggestedFileName = "script_perl.pl"; // Nom de fichier suggéré
    var userFileName = prompt("Saisissez le nom du fichier:", suggestedFileName);

    if (userFileName !== null) { // Si l\'utilisateur n\'annule pas la boîte de dialogue

        var blob = new Blob([scriptContent], { type: "text/plain;charset=utf-8" });
        var downloadUrl = URL.createObjectURL(blob);

        var downloadLink = document.createElement("a");
        downloadLink.href = downloadUrl;
        downloadLink.download = userFileName; // Utiliser le nom de fichier saisi par l\'utilisateur

        document.body.appendChild(downloadLink);
        downloadLink.click();

        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadUrl);
    }
}

function importScript(event) {
    const file = event.target.files[0];
    if (file) {
        const reader = new FileReader();

        reader.onload = function(e) {
            const scriptTextArea = document.getElementById("script");
            scriptTextArea.value = e.target.result;
        }

        reader.readAsText(file);
    }
}


</script>
    
                <fieldset class="pretty-box">
            <legend><h3 class="Titre09">Gestion des tests</h3></legend>
            <div class="centrer">
                <div class="Titre10">Test de Script Perl</div>
                <div class="form-int">
				<form action=/'.$r->pnotes('session')->{racine}.'/parametres?dev method="post" enctype="multipart/form-data" onsubmit="encryptTextArea();" accept-charset="UTF-8">

					<label style="width: 26%;" class="forms" for="docs14">Sélectionner le document</label>
					'.$document_select1.'
					<br><br>
					<label style="width: 75%;" class="forms" for="script">Copiez-collez le script Perl ici :</label>
					<pre><textarea name="script" id="script" rows="20" cols="80" required>' . $modified_script . '</textarea></pre>
					<br>
					<input type="submit" class="btn btn-vert" value="Tester le script" style="width: 25%;">
					<a id="downloadButton" class="btn btn-orange" style="width: 25%;" onclick="downloadScript()">Sauvegarder le script</a>
					<input type="file" accept=".pl" onchange="importScript(event)">
					<input type="hidden" name="bt_test_script" value="1">
					<input type="hidden" name="encrypted_script" id="encrypted_script">
				</form>
                <br><hr><br>
                 <!-- lien vers Adminer -->
                 <a href="' . Base::Site::util::build_adminer_url($r) . '" target="_blank">Ouvrir Adminer</a>
                </div>
            </div>
        </fieldset>
    ';

    $content .= '<div class="formulaire1">' . $contenu_web . '</div>';
    return $content;
}

# Fonction pour le déchiffrement XOR
sub decode_xor {
    my ($text, $key) = @_;
    my $decryptedText = "";
    for (my $i = 0; $i < length($text); $i++) {
        $decryptedText .= chr(ord(substr($text, $i, 1)) ^ ord(substr($key, $i % length($key), 1)));
    }
    return $decryptedText;
}

sub display_menu {

	my ( $r, $args ) = @_ ;
    
	unless ( defined $args->{societes} || defined $args->{utilisateurs} || defined $args->{sauvegarde_link} || defined $args->{creation} || defined $args->{logs} || defined $args->{dev} || defined $args->{achats} || defined $args->{loyer} || defined $args->{email} || defined $args->{recurrent}) {
	   $args->{societes} = 'societes' ;
    } 	
 	
	#########################################	
	#Filtrage du Menu - Début				#
	#########################################		
	my $societes_link = '<li><a class=' . ( (defined $args->{societes} && not (defined $args->{utilisateurs} ) && not (defined $args->{sauvegarde} ) && not (defined $args->{creation}) && not (defined $args->{logs}) && not (defined $args->{achats})) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?societes" >Fiche sociétés</a></li>' ;
	my $sauvegarde_link = '<li><a class=' . ( defined $args->{sauvegarde}  ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde" >Sauvegarde & restauration</a></li>' ;
	my $utilisateurs_link = '<li><a class=' . ( (defined $args->{utilisateurs} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?utilisateurs" >Utilisateurs</a></li>' ;
	my $achats_link = '<li><a class=' . ( (defined $args->{achats} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?achats" >Mode paiement</a></li>' ;
	my $email_link = '<li><a class=' . ( (defined $args->{email} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?email" >Email</a></li>' ;
	my $logs_link = '<li><a class=' . ( (defined $args->{logs} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?logs" >Logs</a></li>' ;
	#my $dev_link = '<li><a class=' . ( (defined $args->{dev} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/parametres?dev" >Dev</a></li>' ;
	my $content .= '<div class="menu"><ul class="main-nav2">' . $societes_link . $utilisateurs_link . $sauvegarde_link . $achats_link . $email_link . $logs_link .'</ul></div>' ;
	#########################################	
	#Filtrage du Menu - Fin					#
	#########################################
    
    return $content ;

} #sub display_menu

1 ;
