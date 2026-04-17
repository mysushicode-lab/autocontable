package Base::Handler::journal;
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
use Encode::Guess;

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content ;
    my $req = Apache2::Request->new( $r ) ;
    
    #récupérer les arguments
    my (%args, @args) ;

    #recherche des paramètres de la requête
    @args = $req->param ;

    for ( @args ) {

	$args{ $_ } = Encode::decode_utf8( $req->param($_) ) ;

	#les double-quotes et les <> viennent interférer avec le html
	$args{ $_ } =~ tr/<>"/'/ ;

    }
    
    if ( defined $args{configuration} ) {
	
		#Ne pas modifier la liste des journaux si l'exercice est cloturé	
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
			$content = edit_journal_set( $r, \%args ) ; #éditer la liste des journaux
		} else {
			$content = open_journal( $r, \%args ) ;		#afficher la liste des journaux
		}

    } elsif ( defined $args{import} && $args{import} eq '0' || defined $args{import_file} && $args{import_file} eq '') {
		$content = import_form( $r, \%args ) ;
    } elsif ( defined $args{import} && $args{import} eq '1' && defined $args{import_file} && $args{import_file} ne '') {
		
		# Sauvegarder avant import est coché	
		if ( defined $args{backup} and $args{backup} eq '1' ) {
			my $db_name = $r->dir_config('db_name') ;
			my $db_host = $r->dir_config('db_host') ;
			my $db_user = $r->dir_config('db_user') ;
			my $db_mdp = $r->dir_config('db_mdp') ;
			my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
			# sauvegarde  bdd format dump
			system "PGPASSWORD=\"$db_mdp\" pg_dump -h \"$db_host\" -U \"$db_user\" -Fc -b -v \"$db_name\" -f \"/var/www/html/Compta/base/backup/backup_database.$date.dump\" 2>&1"; 
			# sauvegarde  bdd format sql
			#system "PGPASSWORD=\"$db_mdp\" pg_dump -h \"$db_host\" -O -x -U \"$db_user\" --format=plain -b -v \"$db_name\" -f \"/var/www/html/Compta/base/backup/backup_database.$date.sql\" 2>&1"; 
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Sauvegarde de la base donnée via pg_dump (backup_database.'.$date.'.dump)');
		}	

		my $dbh = $r->pnotes('dbh') ;
		my ( $sql, @bind_array ) ;
		#on a un fichier, traiter les données
		my $req = Apache2::Request->new( $r ) ;
		my $upload = $req->upload("import_file") or warn $!  ;
		my $upload_fh = $upload->fh() ;
		
		my $ecriture_liste = '' ;
		my $ecriture_liste_doc_1 = '' ;
		my $ecriture_liste_doc_2 = '' ;
		my $ecriture_liste_cat_doc_1 = '' ;
		my $ecriture_liste_cat_doc_2 = '' ;
		my $ecriture_fiscal = '' ;
		my $ecriture_date = '';
		my $ecriture_id_export = '';
		my $compte_liste = '';
		my $journaux_liste = '';
		my $journaux_type = '';
		my $new_export_id = '';
		my $ecriture_verif_export = '';
		my @exportdata = '';
		my $decoder_bom ='';
		my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);
		my $valid_data = 1 ; #on suppose que les données sont en UTF-8
		my $rowCount = 0 ;    
		
		#my $first_line = <$upload_fh>;
		while ( my $data = <$upload_fh>) {
			
			$rowCount = $rowCount+1;
			#next if $. == 1;
			
			if ($data =~ /journallib|JournalCode|JOURNALCODE|JOURNALLIB/i) {next;}
			chomp($data);

			#vérification de l'en-tête de fichier
			my $decoder = guess_encoding($data, 'utf8');
			$decoder = guess_encoding($data, 'UTF-8') unless ref $decoder;
			$decoder = guess_encoding($data, 'windows-1252') unless ref $decoder;
			$decoder = guess_encoding($data, 'iso-8859-1') unless ref $decoder;
			$decoder = guess_encoding($data, 'ascii') unless ref $decoder;
			$decoder = guess_encoding($data, 'cp1252') unless ref $decoder;

			die $decoder unless ref $decoder;

			$decoder_bom = $decoder->name;
			
		 	#vérifier qu'on a le bon en tête; sinon, avorter et envoyer message d'erreur
		    eval { $data = Encode::decode( $decoder_bom, $data, Encode::FB_CROAK ) };


		    if ( $@ ) { # input was not utf8
				$content .= '<h3 class=warning>Les données transmises ne sont pas au format UTF-8, importation impossible</h3>' ;		    
				#mettre valid_data à 0 pour empêcher l'importation
				$valid_data = 0 ;
				#inutile de continuer
				last ;
		    } 
		    
		    #remplacer les ' par '' pour postgres
		    $data =~ s/'/''/g ;
		    $data =~ s/,/./g ;


			if ($args{select_import} eq 'csv') {
				
				my @data = split ';', $data ;
				
				if (!defined $data[3]) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 4 : Date  est vide <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;	
				}
				
				if (!defined $data[4]) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 5 : Numéro de compte  est vide <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;	
				}
				
				if (($data[3] !~ (/^(?<year>[0-9]{4}).*(?<month>[0-9]{2}).*(?<day>[0-9]{2})$/) && (/^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/))) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 4 : Date  *** ' . $data[3]. ' *** n\'est pas au bon format <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;
				}
				
				if ( (substr( $data[4], 0, 1 ) !~ /\d/ )) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 5 : Numéro de compte  *** ' . $data[4]. ' *** est invalide et ne commence pas par un chiffre <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;
				}
				
				#il faut écrire NULL dans les champs vides, car sinon
				#les cases sont décalées à l'affichage par la chaîne vide ''
				# JournalCode				$data[0]
				# JournalLib				$data[1]
				# EcritureNum				$data[2]*
				if ( $data[2] ) { $data[2] = qq [ E'$data[2]' ] } else { $data[2] ='NULL' } ;
				# EcritureDate				$data[3]
				# CompteNum					$data[4]
				# CompteLib					$data[5]
				# id_paiement (libre)		$data[6]*
				if ( $data[6] ) { $data[6] = qq [ E'$data[6]' ] } else { $data[6] ='NULL' } ;
				# PieceRef					$data[7]*
				if ( $data[7] ) { $data[7] = qq [ E'$data[7]' ] } else { $data[7] ='NULL' } ;
				# EcritureLib				$data[8]
				# Debit						$data[9]
				# supprimer les espaces de formatage
				$data[9] =~ s/\s//g;
				# Credit 					$data[10]
				# supprimer les espaces de formatage
				$data[10] =~ s/\s//g;
				# EcritureLet 				$data[11]*
				if ( $data[11] ) { $data[11] = qq [ E'$data[11]' ] } else { $data[11] ='NULL' } ;
				# ecriturepointage			$data[12]*
				if ( $data[12] ) { $data[12] = qq [ E'$data[12]' ] } else { $data[12] ='NULL' } ;
				# documents1				$data[13]*
				if ( $data[13] ) { $data[13] = qq [ E'$data[13]' ] } else { $data[13] ='NULL' } ;
				# documents2				$data[14]*
				if ( $data[14] ) { $data[14] = qq [ E'$data[14]' ] } else { $data[14] ='NULL' } ;
				# date_creation 			$data[15]*
				if ( $data[15] ) { $data[15] = qq [ E'$data[15]' ] } else { $data[15] ='NULL' } ;
				# ValidDate 				$data[16]*	
				if ( $data[16] ) { $exportdata[16] = $data[16] ; $data[16] = qq [ E'$data[16]' ] ; } else { $data[16] ='NULL' } ;	    
				# exercice 					$data[17]*
				if ( $data[17] ) { $exportdata[17] = $data[17] ; } else { $data[17] ='NULL' } ;
				# id_export 				$data[18]*
				if ( $data[18] ) { $exportdata[18] = $data[18] ; $data[18] = qq [ E'$data[18]' ] ; } else { $data[18] ='NULL' } ;
				# doc1_date_reception		$data[19]*
				if ( $data[19] ) { $data[19] = qq [ E'$data[19]' ] } else { $data[19] ='NULL' } ;
				# doc1_libelle_cat_doc		$data[20]*
				if ( $data[20] ) { $data[20] = qq [ E'$data[20]' ] } else { $data[20] ='NULL' } ;
				# doc1_montant				$data[21]*
				if ( $data[21]) { $data[21] =~ s/\s//g};
				# doc1_date_upload			$data[22]*
				if ( $data[22] ) { $data[22] = qq [ E'$data[22]' ] } else { $data[22] ='NULL' } ;
				# doc1_last_fiscal_year_doc	$data[23]*
				if ( $data[23] ) { $data[23] = qq [ E'$data[23]' ] } else { $data[23] ='NULL' } ;
				# doc1_check_banque			$data[24]*
				if ( $data[24] ) { $data[24] = qq [ E'$data[24]' ] } else { $data[24] ='NULL' } ;
				# doc1_id_compte			$data[25]*
				if ( $data[25] ) { $data[25] = qq [ E'$data[25]' ] } else { $data[25] ='NULL' } ;
				# doc2_date_reception		$data[26]*
				if ( $data[26] ) { $data[26] = qq [ E'$data[26]' ] } else { $data[26] ='NULL' } ;
				# doc2_libelle_cat_doc		$data[27]*
				if ( $data[27] ) { $data[27] = qq [ E'$data[27]' ] } else { $data[27] ='NULL' } ;
				# doc2_montant				$data[28]*
				if ( $data[28]) { $data[28] =~ s/\s//g};
				# doc2_date_upload			$data[29]*
				if ( $data[29] ) { $data[29] = qq [ E'$data[29]' ] } else { $data[29] ='NULL' } ;
				# doc2_last_fiscal_year_doc	$data[30]*
				if ( $data[30] ) { $data[30] = qq [ E'$data[30]' ] } else { $data[30] ='NULL' } ;
				# doc2_check_banque			$data[31]*
				if ( $data[31] ) { $data[31] = qq [ E'$data[31]' ] } else { $data[31] ='NULL' } ;
				# doc2_id_compte			$data[32]*
				if ( $data[32] ) { $data[32] = qq [ E'$data[32]' ] } else { $data[32] ='NULL' } ;
				# date_export				$data[33]*
				if ( $data[33] ) { $exportdata[33] = $data[33] ; $data[33] = qq [ E'$data[33]' ] ; } else { $data[33] ='NULL' } ;
				# comptepart				$data[34]*
				if ( $data[34] ) { $data[34] = qq [ E'$data[34]' ] } else { $data[34] ='NULL' } ;
				# doc1_multi				$data[35]*
				if ( $data[35] ) { $data[34] = qq [ E'$data[35]' ] } else { $data[35] ='NULL' } ;
				# doc2_multi				$data[36]*
				if ( $data[36] ) { $data[36] = qq [ E'$data[36]' ] } else { $data[36] ='NULL' } ;
				# id_client					$r->pnotes('session')->{id_client} 
				# _session_id				$r->pnotes('session')->{_session_id} 
				# fiscal_year_offset		$r->pnotes('session')->{fiscal_year_offset} 
				# _token_id	$token_id   	$token_id
				# id_entry   				0	

				if ($data[1] =~ /ven/i){
				$journaux_type = 'Ventes';
				} elsif ($data[1] =~ /ac|fo/i){
				$journaux_type = 'Achats';
				} elsif ($data[1] =~ /cl/i){
				$journaux_type = 'Clôture';
				} elsif ($data[1] =~ /nou/i){
				$journaux_type = 'A-nouveaux';
				} elsif ($data[1] =~ /od|diver/i){
				$journaux_type = 'OD';
				} elsif ($data[1] =~ /ba|ca|pa/i){
				$journaux_type = 'Trésorerie';
				} 
				
				#INSERT INTO tblcompte (id_client, fiscal_year, numero_compte, libelle_compte)
				$compte_liste .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $r->pnotes('session')->{fiscal_year} . ', E\'' . $data[4] . '\', E\'' . $data[5] . '\')' ;
				
				#INSERT INTO tbljournal_liste (id_client, fiscal_year, code_journal, libelle_journal, type_journal)
				$journaux_liste .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $r->pnotes('session')->{fiscal_year} . ', E\'' . ($data[0]) . '\', E\'' . ($data[1]) . '\', E\'' .$journaux_type. '\')' ;
				
				#INSERT INTO tbldocuments_categorie (id_client, libelle_cat_doc )
				if (not($data[20] eq 'NULL')){
				$ecriture_liste_cat_doc_1 .= ',(' . $r->pnotes('session')->{id_client} . ',' . ( $data[20] ) . ')';
				}
				
				#INSERT INTO tbldocuments_categorie (id_client, libelle_cat_doc )
				if (not($data[27] eq 'NULL')){
				$ecriture_liste_cat_doc_2 .= ',(' . $r->pnotes('session')->{id_client} . ',' . ( $data[27] ) . ')';
				}
				
				#INSERT INTO tbldocuments (date_reception, id_name, libelle_cat_doc, montant, date_upload, last_fiscal_year, check_banque, id_compte, fiscal_year, id_client )
				if (not($data[13] eq 'NULL')){
				$ecriture_liste_doc_1 .= ',(' . ( $data[19] ) . ',' . ( $data[13] ) . ', ' . ( $data[20] ) . ', ' . ( $data[21] * 100 || '0' ) . ', ' . $data[22] . ',' . $data[23] . ', ' . $data[24] . ', ' . $data[25] . ', ' . $data[17] . ', ' . $r->pnotes('session')->{id_client} . ')' ;
				}
				
				#INSERT INTO tbldocuments (date_reception, id_name, libelle_cat_doc, montant, date_upload, last_fiscal_year, check_banque, id_compte, fiscal_year, id_client )
				if (not($data[14] eq 'NULL')){
				$ecriture_liste_doc_2 .= ',(' . ( $data[26] ) . ',' . ( $data[14] ) . ', ' . ( $data[27] ) . ', ' . ( $data[28] * 100 || '0' ) . ', ' . $data[29] . ',' . $data[30] . ', ' . $data[31] . ', ' . $data[32] . ', ' . $data[17] . ', ' . $r->pnotes('session')->{id_client} . ')' ;
				}
				
				#verif export (id_client, date_validation, fiscal_year, date_export )
				if (not($data[18] eq 'NULL') && not($data[33] eq 'NULL') && not($data[16] eq 'NULL')){
				
				$sql = 'SELECT id_export FROM tblexport WHERE id_client = ? and date_validation = ? and fiscal_year = ? and date_export = ?';
				@bind_array = ( $r->pnotes('session')->{id_client}, $exportdata[16], $exportdata[17], $exportdata[33] ) ;
				my $verif_export = ($dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0]) || '' ;
			
				if (not($verif_export eq '')) {
				$new_export_id = $verif_export;
				} else {
				$sql = 'INSERT INTO tblexport (id_client, date_export, fiscal_year, date_validation) VALUES (?, ?, ?, ?) returning id_export' ;
				@bind_array = ( $r->pnotes('session')->{id_client},  $exportdata[33], $exportdata[17], $exportdata[16] ) ;
				$new_export_id = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
				}	
				
				}
				
				#les montants débit/crédits sont enregistrés en numérique avec deux décimales dans tbljournal_import
				#il seront convertis en centimes ( * 100 ) par la fonction import_staging
				#INSERT INTO tbljournal_import (fiscal_year, libelle_journal, date_ecriture, id_paiement, numero_compte, id_facture, libelle, debit, credit, lettrage, pointage, documents1, documents2, num_mouvement, date_validation, id_client, _session_id, fiscal_year_offset, _token_id, id_entry, id_export)
				$ecriture_liste .= ',(' . $r->pnotes('session')->{fiscal_year} . ',E\'' . ( $data[1] ) . '\', E\'' . ( $data[3] ). '\', ' . ($data[6])  . ', E\'' . ( $data[4] ) . '\', ' . ($data[7]) . ',E\'' . ($data[8] ). '\', ' . ( $data[9] || '0' ) . ', ' . ( $data[10] || '0') . ', ' . ($data[11] ) . ', ' . ( $data[12] ) . ', ' . ($data[13]) . ', ' . ($data[14]) . ', ' . ($data[2]) . ', ' . ($data[16]) . ', ' . $r->pnotes('session')->{id_client} . ', \'' . $r->pnotes('session')->{_session_id} . '\', ' . $r->pnotes('session')->{fiscal_year_offset} . ', \'' . $token_id . '\', 0, ' .($new_export_id || 'NULL'). ')' ;
				$ecriture_fiscal = ($data[17]);
				
			} elsif ($args{select_import} eq 'fec') {
				

			#my @data = split (/\|/, $data) ;
			my $sep= '';
			my $separateur = '';
			
			my @comp_tab = split /\t/, $data;
            my @comp_pip = split /\|/, $data;
            my @comp_pvi = split /;/,  $data;
            my @comp_vir = split /,/,  $data;
            if    ( $#comp_tab >= 8 ) { $sep = "T"; }
            elsif ( $#comp_pip >= 8 ) { $sep = "P"; }
            elsif ( $#comp_vir >= 8 ) { $sep = "V"; }
            elsif ( $#comp_pvi >= 8 ) { $sep = "PV"; }
            
            
            if ( $sep eq "T" )  { $separateur = '\t'; }
			if ( $sep eq "P" )  { $separateur = '\|'; }
			if ( $sep eq "V" )  { $separateur = ','; }
			if ( $sep eq "PV" ) { $separateur = ';'; }
			
			my @data = split ' *' . $separateur . ' *', $data;
            
			if (!defined $data[3]) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 4 : Date  est vide <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;	
				}
				
				if (!defined $data[4]) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 5 : Numéro de compte  est vide <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;	
				}
				
				if (defined $data[3] && ($data[3] !~ (/^(?<year>[0-9]{4}).*(?<month>[0-9]{2}).*(?<day>[0-9]{2})$/) && $data[3] !~ (/^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/))) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 4 : Date  *** ' . $data[3]. ' *** n\'est pas au bon format <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;
				}
				
				if (defined $data[4] && (substr( $data[4], 0, 1 ) !~ /\d/ )) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 5 : Numéro de compte  *** ' . $data[4]. ' *** est invalide et ne commence pas par un chiffre <br><br> 
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>' ;		    
					$valid_data = 0 ;
					last ;
				}	
			
			# JournalCode			$data[0]
		    # JournalLib			$data[1]
		    # EcritureNum			$data[2]*
		    if ( $data[2] ) { $data[2] = qq [ E'$data[2]' ] } else { $data[2] ='NULL' } ;
		    # EcritureDate			$data[3]
		    # CompteNum				$data[4]
		    # CompteLib				$data[5]
		    # CompAuxNum	    	$data[6]*
		    if ( $data[6] ) { $data[6] = qq [ E'$data[6]' ] } else { $data[6] ='NULL' } ;
		    # CompAuxLib			$data[7]*
		    if ( $data[7] ) { $data[7] = qq [ E'$data[7]' ] } else { $data[7] ='NULL' } ;
		    # PieceRef				$data[8]*
		    if ( $data[8] ) { $data[8] = qq [ E'$data[8]' ] } else { $data[8] ='NULL' } ;
		    # PieceDate				$data[9]*
		    if ( $data[9] ) { $data[9] = qq [ E'$data[9]' ] } else { $data[9] ='NULL' } ;
		    # EcritureLib			$data[10]
		    # Debit					$data[11]
		    $data[11] =~ s/\s//g;
		    # Credit 				$data[12]
		    $data[12] =~ s/\s//g;
		    # EcritureLet 			$data[13]*
		    if ( $data[13] ) { $data[13] = qq [ E'$data[13]' ] } else { $data[13] ='NULL' } ;
		    # DateLet				$data[14]*
		    if ( $data[14] ) { $data[14] = qq [ E'$data[14]' ] } else { $data[14] ='NULL' } ;
		    # ValidDate 			$data[15]*
		    if ( $data[15] ) { $data[15] = qq [ E'$data[15]' ] } else { $data[15] ='NULL' } ;
		    # Montantdevise 		$data[16]*
		    if ( $data[16] ) { $data[16] = qq [ E'$data[16]' ] } else { $data[16] ='NULL' } ;
		    # Idevise				$data[17]*
		    if ( $data[17] ) { $data[17] = qq [ E'$data[17]' ] } else { $data[17] ='NULL' } ;
			
			if ($data[1] =~ /ven/i){
			$journaux_type = 'Ventes';
			} elsif ($data[1] =~ /ac|fo/i){
			$journaux_type = 'Achats';
			} elsif ($data[1] =~ /cl/i){
			$journaux_type = 'Clôture';
			} elsif ($data[1] =~ /nou/i){
			$journaux_type = 'A-nouveaux';
			} elsif ($data[1] =~ /od|diver/i){
			$journaux_type = 'OD';
			} elsif ($data[1] =~ /ba|ca|pa/i){
			$journaux_type = 'Trésorerie';
			} 
			
			#INSERT INTO tblcompte (id_client, fiscal_year, numero_compte, libelle_compte)
			$compte_liste .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $r->pnotes('session')->{fiscal_year} . ', E\'' . $data[4] . '\', E\'' . $data[5] . '\')' ;
			
			#INSERT INTO tbljournal_liste (id_client, fiscal_year, code_journal, libelle_journal, type_journal)
			$journaux_liste .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $r->pnotes('session')->{fiscal_year} . ', E\'' . ($data[0]) . '\', E\'' . ($data[1]) . '\', E\'' .$journaux_type. '\')' ;
	
			#les montants débit/crédits sont enregistrés en numérique avec deux décimales dans tbljournal_import
			#il seront convertis en centimes ( * 100 ) par la fonction import_staging
			#INSERT INTO tbljournal_import (fiscal_year, libelle_journal, date_ecriture, numero_compte, id_facture, libelle, debit, credit, lettrage, date_validation, id_client, _session_id, fiscal_year_offset, _token_id, id_entry)
			$ecriture_liste .= ',(' . $r->pnotes('session')->{fiscal_year} . ', E\'' . ($data[1]) . '\', E\'' . ($data[3]) . '\', E\'' . ($data[4])  . '\', ' . ( $data[8] ) . ', E\'' . ($data[10]) . '\', ' . ( $data[11] || '0' ) . ', ' . ( $data[12] || '0') . ', ' . ($data[13]) . ', ' . ( $data[15] ) . ', ' . $r->pnotes('session')->{id_client} . ', \'' . $r->pnotes('session')->{_session_id} . '\', ' . $r->pnotes('session')->{fiscal_year_offset} . ', \'' . $token_id . '\', 0)' ;
			$ecriture_fiscal = ($r->pnotes('session')->{fiscal_year});
	
			}
 		    
		} #		while (my $data = <$upload_fh>) 
		
		if ( $valid_data ) { # toutes les lignes ont été décodées avec succès
		    
		    if  ($ecriture_fiscal == $r->pnotes('session')->{fiscal_year}) { 
				

		    #on nettoie les éventuels imports précédents
		    $sql = 'DELETE FROM tbljournal_import where _session_id = ?' ;

		    $dbh->do( $sql, undef, ( $r->pnotes('session')->{_session_id} ) ) ;
		    
		    # Supprimer les données non validées de l'exercice en cours est coché
		    if ( defined $args{del_file} and $args{del_file} eq '1' ) {
			$sql = 'DELETE FROM tbljournal WHERE id_client = ? and fiscal_year = ? and id_export is NULL' ;
			eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) } ;
			}
			
			# Créer les journaux manquants est coché
			if ( defined $args{journaux_manquant} and $args{journaux_manquant} eq '1' ) {
				$sql = 'INSERT INTO tbljournal_liste (id_client, fiscal_year, code_journal, libelle_journal, type_journal) VALUES ' . substr( $journaux_liste, 1).'
				ON CONFLICT (id_client, fiscal_year, libelle_journal) DO NOTHING ';
				#insérer les données
				eval { $dbh->do( $sql ) } ;
				#gestion des erreurs
				if ( $@ ) {
				if ( $@ =~ /unique/ ) {
					$content .= '<h3 class=warning>Un des journaux importés existe déjà</h3>' ;		    
					} else { $content .= '<h3 class=warning>' . $@ . '</h3>' ;  }} 	
			}
			
			# Créer les comptes manquants est coché
			if ( defined $args{compte_manquant} and $args{compte_manquant} eq '1' ) {
				$sql = 'INSERT INTO tblcompte (id_client, fiscal_year, numero_compte, libelle_compte) VALUES ' . substr( $compte_liste, 1).'
				ON CONFLICT (id_client, fiscal_year, numero_compte) 
				DO NOTHING ';
				#insérer les données
				eval { $dbh->do( $sql ) } ;
				#gestion des erreurs
				if ( $@ ) {
				if ( $@ =~ /unique/ ) { $content .= '<h3 class=warning>Un des numéros de compte importés existe déjà</h3>';		    
					} else {$content .= '<h3 class=warning>' . $@ . '</h3>' ;}} 
			}

			if ($args{select_import} eq 'csv') {
				
			# JournalCode				$data[0]
		    # JournalLib				$data[1]
		    # EcritureNum				$data[2]*
		    # EcritureDate				$data[3]
		    # CompteNum					$data[4]
		    # CompteLib					$data[5]
		    # id_paiement (libre)		$data[6]*
		    # PieceRef					$data[7]*
		    # EcritureLib				$data[8]
		    # Debit						$data[9]
		    # Credit 					$data[10]
		    # EcritureLet 				$data[11]*
		    # ecriturepointage			$data[12]*
		    # documents1				$data[13]*
		    # documents2				$data[14]*
		    # date_creation 			$data[15]*
		    # ValidDate 				$data[16]*		    
		    # exercice 					$data[17]*
		    # id_export 				$data[18]*
		    # doc1_date_reception		$data[19]*
		    # doc1_libelle_cat_doc		$data[20]*
		    # doc1_montant				$data[21]*
		    # doc1_date_upload			$data[22]*
		    # doc1_last_fiscal_year_doc	$data[23]*
		    # doc1_check_banque			$data[24]*
		    # doc1_id_compte			$data[25]*
		    # doc2_date_reception		$data[26]*
		    # doc2_libelle_cat_doc		$data[27]*
		    # doc2_montant				$data[28]*
		    # doc2_date_upload			$data[29]*
		    # doc2_last_fiscal_year_doc	$data[30]*
		    # doc2_check_banque			$data[31]*
		    # doc2_id_compte			$data[32]*
		    # date_export				$data[33]*
		    # id_client					$r->pnotes('session')->{id_client} 
		    # _session_id				$r->pnotes('session')->{_session_id} 
		    # fiscal_year_offset		$r->pnotes('session')->{fiscal_year_offset} 
		    # _token_id	$token_id   	$token_id
		    # id_entry   				0	
			
		    #insertion des données de ecriture_liste_cat_doc_1 dans tbldocuments_categorie
		    $sql = 'INSERT INTO tbldocuments_categorie (id_client, libelle_cat_doc ) VALUES ' . substr($ecriture_liste_cat_doc_1, 1).'
		    ON CONFLICT (id_client, libelle_cat_doc) DO NOTHING' ;
		    #insérer les données
		    eval { $dbh->do( $sql ) } ;
		    if ( $@ ) {$content .= '<h3 class=warning>Erreur ecriture_liste_cat_doc_1 => ' . $@ . '</h3>' ;} 
		    
		    #insertion des données de ecriture_liste_cat_doc_2 dans tbldocuments_categorie
		    $sql = 'INSERT INTO tbldocuments_categorie (id_client, libelle_cat_doc ) VALUES ' . substr($ecriture_liste_cat_doc_2, 1).'
		    ON CONFLICT (id_client, libelle_cat_doc) DO NOTHING' ;
		    #insérer les données
		    eval { $dbh->do( $sql ) } ;
		    if ( $@ ) {$content .= '<h3 class=warning>Erreur ecriture_liste_cat_doc_2 => ' . $@ . '</h3>' ;}
		    
		    #insertion des données de ecriture_liste_doc_1 dans tbldocuments
			$sql = 'INSERT INTO tbldocuments (date_reception, id_name, libelle_cat_doc, montant, date_upload, last_fiscal_year, check_banque, id_compte, fiscal_year, id_client ) VALUES ' . substr( $ecriture_liste_doc_1, 1) .'
			ON CONFLICT (id_name, id_client) DO NOTHING'	;
			#insérer les données
			eval { $dbh->do( $sql ) } ;
			if ( $@ ) {$content .= '<h3 class=warning>Erreur ecriture_liste_doc_1 => ' . $@ . '</h3>' ;}
			
			#insertion des données de ecriture_liste_doc_2 dans tbldocuments
			$sql = 'INSERT INTO tbldocuments (date_reception, id_name, libelle_cat_doc, montant, date_upload, last_fiscal_year, check_banque, id_compte, fiscal_year, id_client ) VALUES ' . substr( $ecriture_liste_doc_2, 1) .'
			ON CONFLICT (id_name, id_client) DO NOTHING'	;
			#insérer les données
			eval { $dbh->do( $sql ) } ;
			if ( $@ ) {$content .= '<h3 class=warning>Erreur ecriture_liste_doc_2 => ' . $@ . '</h3>' ;}
			
			#insertion des données dans tbljournal_import
		    $sql = 'INSERT INTO tbljournal_import (fiscal_year, libelle_journal, date_ecriture, id_paiement, numero_compte, id_facture, libelle, debit, credit, lettrage, pointage, documents1, documents2, num_mouvement, date_validation, id_client, _session_id, fiscal_year_offset, _token_id, id_entry, id_export) VALUES '. substr($ecriture_liste,1) ;

				
			} elsif ($args{select_import} eq 'fec') {
				
			# JournalCode			$data[0]
		    # JournalLib			$data[1]
		    # EcritureNum			$data[2]*
		    # EcritureDate			$data[3]
		    # CompteNum				$data[4]
		    # CompteLib				$data[5]
		    # CompAuxNum	    	$data[6]*
		    # CompAuxLib			$data[7]*
		    # PieceRef				$data[8]*
		    # PieceDate				$data[9]*
		    # EcritureLib			$data[10]
		    # Debit					$data[11]
		    # Credit 				$data[12]
		    # EcritureLet 			$data[13]*
		    # DateLet				$data[14]*
		    # ValidDate 			$data[15]*
		    # Montantdevise 		$data[16]*
		    # Idevise				$data[17]*
		    # id_client				$r->pnotes('session')->{id_client} 
		    # _session_id			$r->pnotes('session')->{_session_id} 
		    # fiscal_year_offset	$r->pnotes('session')->{fiscal_year_offset} 
		    # _token_id	$token_id   $token_id
		    # id_entry   			0	
			
			#insertion des données dans tbljournal_import
		    $sql = 'INSERT INTO tbljournal_import (fiscal_year, libelle_journal, date_ecriture, numero_compte, id_facture, libelle, debit, credit, lettrage, date_validation, id_client, _session_id, fiscal_year_offset, _token_id, id_entry) VALUES ' . substr($ecriture_liste, 1) ;

			}

		    #insérer les données
		    eval { $dbh->do( $sql ) } ;

		    if ( $@ ) {

			$content .= '<h3 class=warning>Erreur tbljournal_import => ' . $@ . '</h3>' ;		    
			
		    } else {

			#les données sont dans tbljournal_import
			#lancer la procédure d'importation
			$sql = 'SELECT import_staging (?, ?, ?, ?)' ;
			
			eval { $dbh->selectall_arrayref( $sql, undef, ( $token_id, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD} ) ) } ;

			#erreur dans la procédure store_staging : l'afficher dans le navigateur
			if ( $@ ) {

			    if ( $@ =~ / NOT NULL (.*) date_ecriture / ) {

				$content .= '<h3 class=warning>Il faut une date valide - Enregistrement impossible</h3>' ;

			    } elsif ( $@ =~ /tbljournal_id_client_fiscal_year_numero_compte_fkey/ ) {

				$content .= '<h3 class=warning>Un numéro de compte est manquant - Enregistrement impossible</h3>' ;

				$sql = '
with t1 as (
select numero_compte from tblcompte where id_client = ? and fiscal_year = ?
)
select t2.libelle_journal, t2.date_ecriture, t2.id_paiement, t2.numero_compte, t2.id_facture, t2.libelle, t2.debit, t2.credit, t2.lettrage, t2.pointage, t2.documents1, t2.documents2
from tbljournal_import t2 left join t1 using (numero_compte)
where _token_id = ? and t1.numero_compte is null
' ;

				my $faulty_records = $dbh->selectall_arrayref( $sql, undef, (  $r->pnotes('session')->{id_client} ,  $r->pnotes('session')->{fiscal_year} , $token_id ) ) ;

				$content .= '<h4>Liste des enregistrements concernés :</h4>' ;
				
				$content .= '<pre>' . Data::Dumper::Dumper($faulty_records) . '</pre>' ;
								
			    } elsif ( $@ =~ / numero_compte / ) {

				$content .= '<h3 class=warning>Il faut un numéro de compte - Enregistrement impossible</h3>' ;

			    } elsif ( $@ =~ /tbljournal_id_client_fiscal_year_libelle_journal_fkey/ ) {

				$content .= '<h3 class=warning>Un journal est manquant - Enregistrement impossible</h3>' ;

				#on recherche le journal qui manque
				$sql = 'SELECT libelle_journal FROM tbljournal_import WHERE libelle_journal NOT IN (select libelle_journal from tbljournal_liste where id_client = ? and fiscal_year = ?) AND _token_id = ? GROUP BY libelle_journal' ;

				my $faulty_journal = $dbh->selectall_arrayref( $sql, undef, ( $r->pnotes('session')->{id_client} ,  $r->pnotes('session')->{fiscal_year} , $token_id ) ) ;

				$content .= '<h4>Manquant :</h4>' ;

				$content .= '<pre>' . Data::Dumper::Dumper($faulty_journal) . '</pre>' ;


			    } elsif ( $@ =~ /unbalanced total/ ) {

				$content .= '<h3 class=warning>Montants déséquilibrés - Enregistrement impossible</h3>' ;
				
			    } elsif ( $@ =~ /bad num mouvement/ ) {

				$content .= '<h3 class=warning>Attention numéro de mouvement déjà utilisé - Enregistrement impossible</h3>' ;
				
								
			    } elsif ( $@ =~ /unbalanced group/ ) {

				$content .= '<h3 class=warning>Groupe déséquilibré - Enregistrement impossible</h3>' ;

				$content .= '<p class=warning>Les écritures doivent être équilibrées par date et numéro de pièce et avoir le même libellé</p>' ;
				#on affiche les enregistrements fautifs
				$sql = '
select date_ecriture, id_facture, libelle, fiscal_year, id_client, libelle_journal
from tbljournal_import
where _token_id = ?
group by date_ecriture, id_facture, libelle, fiscal_year, id_client, libelle_journal
having sum(credit-debit) <> 0
' ;
#afficher les débits/crédits
# 				$sql = '
# select libelle_journal, date_ecriture, id_paiement, numero_compte, id_facture, libelle, to_char(debit/100::numeric, \'999999990D99\'), to_char(credit/100::numeric, \'999999990D99\')
# from tbljournal_import
# where _token_id = ?
# group by libelle_journal, date_ecriture, id_paiement, numero_compte, id_facture, libelle, to_char(debit/100::numeric, \'999999990D99\'), to_char(credit/100::numeric, \'999999990D99\')
# having sum(credit-debit) <> 0
# ' ;
				
				my $faulty_records = $dbh->selectall_arrayref( $sql, undef, ( $token_id ) ) ;
				
				$content .= '<h4>Liste des enregistrements concernés :</h4>' ;
				
				$content .= '<pre>' . Data::Dumper::Dumper($faulty_records) . '</pre>' ;
				

			    } elsif ( $@ =~ / bad fiscal year/ ) {

				$content .= '<h3 class=warning>Des dates d\'écriture ne sont pas dans l\'exercice en cours - Enregistrement impossible</h3>' ;

				$sql = '
select t2.libelle_journal, t2.date_ecriture, t2.id_paiement, t2.numero_compte, t2.id_facture, t2.libelle, t2.debit, t2.credit, t2.lettrage, t2.pointage , t2.documents1, t2.documents2
from tbljournal_import t2
where _token_id = ? and date_is_in_fiscal_year(t2.date_ecriture, ?, ?) = FALSE
' ;
				
				my $faulty_records = $dbh->selectall_arrayref( $sql, undef, ( $token_id, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}) ) ;

				$content .= '<h4>Liste des enregistrements concernés :</h4>' ;

				$content .= '<pre>' . Data::Dumper::Dumper($faulty_records) . '</pre>' ;

			    } elsif ( $@ =~ /archived/ ) {

				$content .= '<h3 class=warning>Des dates d\'écriture se trouvent dans un mois archivé - Enregistrement impossible</h3>' ;

				$sql = '
select t2.libelle_journal, t2.date_ecriture, t2.id_paiement, t2.numero_compte, t2.id_facture, t2.libelle, t2.debit, t2.credit, t2.lettrage, t2.pointage, t2.documents1, t2.documents2
from tbljournal_import t2
where _token_id = ? and to_char(t2.date_ecriture, \'MM\') in (select id_month from tbllocked_month where id_client =? and fiscal_year = ?)
' ;
				
				my $faulty_records = $dbh->selectall_arrayref( $sql, undef, ( $token_id, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

				$content .= '<h4>Liste des enregistrements concernés :</h4>' ;

				$content .= '<pre>' . Data::Dumper::Dumper($faulty_records) . '</pre>' ;

			    } else {
				
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;

			    } #	     if ( $@ =~ /date_ecriture/ ) 

			} else {
				
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Importation du fichier '.$args{import_file}.' ('. $decoder_bom .')');

				my $location = '/'.$r->pnotes('session')->{racine}.'/journal?import=2' ;
				$r->headers_out->set(Location => $location) ;
				return Apache2::Const::REDIRECT ;


			} #	if ( $@ ) 
			
		    } #		if ( $@ ) 	
		    
		} else {
		
		$content .= '<h3 class=warning>Les écritures ne sont pas dans le bon exercice (champ exercice du fichier en ' . $ecriture_fiscal .') pour un import dans l\'exercice '. $r->pnotes('session')->{fiscal_year}.'</h3>' ;
			
		}

		} #		if ( $valid_data ) {

    } else {

		#afficher la liste des journaux
		$content = open_journal( $r, \%args ) ;

    }
    
    $r->no_cache(1) ;
 
    $r->content_type('text/html; charset=utf-8') ;

    print $content ;

    return Apache2::Const::OK ;

}

sub month_selector {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    unless ( defined $args->{mois} ) {
	    $args->{mois} = 0  ; 
	    #$args->{mois} = $dbh->selectall_arrayref('SELECT to_char(CURRENT_DATE, \'MM\')')->[0]->[0] ;
    }
    
    my $sql = q { SELECT to_char((? || '-01-01')::date + ?::integer + (s.m || 'months')::interval, 'MM') FROM generate_series(0, 11) as s(m) } ;
    
    my @bind_array = ( $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset} ) ;

    my $month_set = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;

    my $class = ( $args->{mois} eq '0' ) ? 'linavselect' : 'linav' ;
    my $class_rec = ( defined $args->{recurrent} ) ? 'linavselect' : 'linav' ;
    my $class_eq = ( defined $args->{equilibre} ) ? 'linavselect' : 'linav' ;
    my $class_nolet = ( defined $args->{nonlettre} ) ? 'linavselect' : 'linav' ;
    #my $class_analyses = ( defined $args->{analyses} ) ? 'selecteditem' : 'nav' ;
    
    my $month_list = '
    <li><a class=' . $class . ' href="/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=0" title="Afficher tout">*</a></li>
	<li><a class=linav href="/'.$r->pnotes('session')->{racine}.'/journal" title="Reset des filtres">R</a></li>
	' ;

	
	
    for ( @$month_set ) {
		
	my $class = 'linav';
	
	my $month_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $_->[0] ;

	if 	(defined $args->{mois} && $args->{mois} eq $_->[0]) {
		$class= 'linavselect';
		$month_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '';
	}
		
	$month_list .= '
	<li><form action="'.$month_href.'" method=post>
	<a class=' . $class . ' href="#" onclick="parentNode.submit();">' . $_->[0] . '</a>
	<input type=hidden name="search_date" value="' . ($args->{search_date} || ''). '">
	<input type=hidden name="search_journal" value="' . ($args->{search_journal} || ''). '">
	<input type=hidden name="search_libre" value="' . ($args->{search_libre} || ''). '">
	<input type=hidden name="search_compte" value="' . ($args->{search_compte} || ''). '">
	<input type=hidden name="search_piece" value="' . ($args->{search_piece} || ''). '">
	<input type=hidden name="search_lib" value="' . ($args->{search_lib} || ''). '">
	<input type=hidden name="search_debit" value="' . ($args->{search_debit} || ''). '">
	<input type=hidden name="search_credit" value="' . ($args->{search_credit} || ''). '">
	<input type=hidden name="search_let" value="' . ($args->{search_let} || ''). '">
	<input type=hidden name="search_doc1" value="' . ($args->{search_doc1} || ''). '">
	<input type=hidden name="search_doc2" value="' . ($args->{search_doc2} || ''). '">
	<input type=hidden name="search_let" value="' . ($args->{search_let} || ''). '">
	<input type=hidden name="search1" value="' . ($args->{search1} || ''). '">
	</form></li>' ;
	
    } #    for ( @$month_set ) 

    my $recurrent_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&mois=0&recurrent=true' ;	
    if (defined $args->{recurrent} && $args->{recurrent} eq 'true') {
		$recurrent_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '' ;	
	}
	
	my $equilibre_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&mois=0&equilibre=true' ;	
    if (defined $args->{equilibre} && $args->{equilibre} eq 'true') {
		$equilibre_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '' ;	
	}
	
	my $nonlettre_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&mois=0&nonlettre=true' ;	
    if (defined $args->{nonlettre} && $args->{nonlettre} eq 'true') {
		$nonlettre_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '' ;	
	}

    $month_list .='
    <li><a class=' . $class_rec . ' href="'.$recurrent_href.'" title="écritures récurrentes">Récurrent</a></li>
	<li><a class=' . $class_eq . ' href="'.$equilibre_href.'" title="écritures lettrées et non équilibrées">Check1</a></li>
    <li><a class=' . $class_nolet . ' href="'.$nonlettre_href.'" title="écritures non lettrées des comptes de classe 4">Check2</a></li>
    ';

    my $content .= '<div class="menuN2"><ul class="main-nav2">' . $month_list . '</ul></div>' ;

    return $content ;
    
} #sub month_selector 

#/*—————————————— formulaire d'upload d'un fichier d'importation des écritures 	——————————————*/
sub import_form {
	# définition des variables
	my ( $r, $args ) = @_ ;
    my $content = '';
    
    ################ Affichage MENU ################
    $content .= display_journal_set( $r, $args ) ;
    $content .= month_selector( $r, $args ) ;
    ################ Affichage MENU ################
    
    #/************ ACTION DEBUT *************/
 
	if ( defined $args->{import_file} && $args->{import_file} eq '') {
		$content .= Base::Site::util::generate_error_message('Aucun fichier n\'a été sélectionné pour le téléchargement!');
	}
	
	# Bloquer si l'exercice est clos
	return ($content .= Base::Site::util::bloquer_exercice_clos($r)) if Base::Site::util::bloquer_exercice_clos($r);

	
	#/************ ACTION FIN *************/
	

	#choix des données à exporter
	my $id_select_import = '
	<select class="login-text" style ="width : 48%;" id=select_import name=select_import style="font-size:14px;">
		<option value="csv">CSV - Fichier compta-libre</option>
		<option selected value="fec">FEC - Fichier des écritures comptables</option>
	</select>
	' ;
    
	my $form_web .= '
		<fieldset class="pretty-box"><legend><h3 class="Titre09">Journaux - Importer des écritures</h3></legend>
		<div class="centrer">
		<div class=Titre10>Fichier à importer</div>
	    <div class="form-int">

			<form action="/'.$r->pnotes('session')->{racine}.'/journal?import=1" method=POST enctype="multipart/form-data">
			<label class="forms" style ="width : 51%;" for="select_import">Format</label>'.$id_select_import.'
			<label class="forms" style ="width : 51%;" for="backup">Sauvegarder avant import</label><input type="checkbox" style ="width : 48%;" id="backup" name="backup" checked value=1>
			<label class="forms" style ="width : 51%;" for="compte_manquant">Créer les comptes manquants</label><input type="checkbox" style ="width : 48%;" id="compte_manquant" name="compte_manquant" value=1 checked>
			<label class="forms" style ="width : 51%;" for="journaux_manquant">Créer les journaux manquants</label><input type="checkbox" style ="width : 48%;" id="journaux_manquant" name="journaux_manquant" value=1 checked>
			<label class="forms" style ="width : 51%;" for="del_file">Supprimer les données non validées de l\'exercice</label><input type="checkbox" style ="width : 48%;" id="del_file" name="del_file" value=1>
			<label class="forms" style ="width : 52%;" for="import_file">Fichier *</label><input type=file style ="width : 48%;" id=import_file name=import_file>	
			<br><br>
			<label class="forms" style ="width : 51%;" for="submit">&nbsp;</label><input id=submit type="submit" class="btn btn-gris" style ="width : 25%;" value="Cliquez ici pour envoyer">
			<p style="">(* : taille maximum 64Mo par fichier)</p>
			<input type=hidden name=open_journal value="Journal général">
			</form>
			
	    </div></div></fieldset>
		';
    
	$content .= '<div class="formulaire2">' . $form_web . '</div>' ;
    return $content ;

} #sub import_form

sub open_journal {
	
	#définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content = '';
    my $sousmenu = "";
    my ( $sql, @bind_array) ;
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

    # Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, [], [], []);
    
	################ Affichage MENU ################
    $content .= display_journal_set( $r, $args ) ;
    $content .= month_selector( $r, $args ) ;
    ################ Affichage MENU ################
        
	my @search = ('0') x 20;
	my @checked = ('0') x 10;
    
    #Récupérations des informations de la société
	my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
    
    #Si aucun journal définir sur Journal général
	unless ( defined $args->{open_journal} ) {
	    $args->{open_journal} = 'Journal général' ;
    }

	 if ( defined $args->{import} and $args->{import} eq '2' ) {			
		#pas de message d'erreur, l'import s'est bien passé
		#afficher la liste des journaux
		$content .= '<h3 class=warning>Les données ont été importées avec succès</h3>' ;
	}
	
    #pour le journal général, ajouter le lien d'importation des écritures
    if ( $args->{open_journal} eq 'Journal général' ) {

		my $import_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( 'Journal général' ) . '&amp;import=0' ;
	
		#masque certain menu si l'exercice est cloturé
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1' && !defined $args->{analyses}) {
			$sousmenu .= '
			<div style="text-align: left;" class="non-printable wrapper35"><a class="linavsolo" href="' . $import_href . '">Importer des écritures</a> <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'importexport_2\');" style="cursor: pointer;" class="linavsolo" >[?]</span></div>
			';
		}
		
    } else { #pour les autres, ajouter le lien vers la création d'une nouvelle entrée
	
		my $new_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=0&amp;nouveau' ;
		
		#masquer lien Nouvelle entrée si l'exercice est cloturé
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
			$sousmenu .= '
			<div style="text-align: left;" class="non-printable wrapper35"><a class=linavsolo href="' . $new_entry_href . '">Nouvelle entrée</a></div>';
		}
    }
    
	#####################################       
	# Manipulation des dates			#
	#####################################  

	# mettre la date du jour par défaut ou date de fin d'exercice
	my $date = localtime->strftime('%d/%m/%Y');
	my $date_1 = localtime->strftime('%Y-%m-%d');
	my $date_2 = $r->pnotes('session')->{Exercice_fin_YMD} ;
    my $date_3;
    if ($date_1 gt $date_2) {$date_3 = $date_2;} else {$date_3 = $date_1;}
    
    ##Mise en forme de la date de %Y-%m-%d vers 2000-02-29
	$date_3 = eval {Time::Piece->strptime($date_3, "%Y-%m-%d")->dmy("/")};

	#####################################       
	# Préparation à l'impression		#
	#####################################   

	#en tête impression
	$content .= '
		<div class="printable">
		<div style="float: left ">
		<address><strong>'.$parametre_set->[0]->{etablissement} . '</strong><br>
		' . ($parametre_set->[0]->{adresse_1} || '') . ' <br> ' . ($parametre_set->[0]->{code_postal} || '') . ' ' . ($parametre_set->[0]->{ville} || '') .'<br>
		SIRET : ' . $parametre_set->[0]->{siret}. '<br>
		</address></div>
		<div style="float: right; text-align: right;">
		Imprimé le ' . $date . '<br>
		<div>
		Exercice du '.$r->pnotes('session')->{Exercice_debut_DMY}.' 
		</div>
		au '.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>
		</div>
		<div style="width: 100%; text-align: center;"><h1>'.$args->{open_journal}.' au '.($date_3 ||'').'</h1>
		<div style="font-size: 9pt;">
		Etat exprimé en Euros</div>
		</div><br></div>' ;
    
    #####################################       
	# Filtrage							#
	##################################### 
    
    #ne pas ajouter la clause mois si $args->mois = 0
    my $month_clause = ( $args->{mois} eq '0' ) ? '' : ' AND to_char(date_ecriture, \'MM\') = ?' ;
    my $search_rec = ( defined $args->{recurrent} && $args->{recurrent} ne '' ) ? ' AND t1.recurrent = ?' : '' ;
    my $search_nonlet = ( defined $args->{nonlettre} && $args->{nonlettre} ne '' ) ? ' AND t1.lettrage is null and substring(t1.numero_compte from 1 for 1) = \'4\' AND SUBSTRING(t1.numero_compte FROM 1 FOR 2) != \'45\'' : '' ;
    
	my $search_eq = ( defined $args->{equilibre} && $args->{equilibre} ne '' ) ? ' AND t1.lettrage is not null
	AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? group by lettrage having sum(credit-debit) != 0)	
	' : '' ;

	my $search_doc1 = ( defined $args->{search_doc1} && $args->{search_doc1} eq 1) ? ' AND t1.documents1 IS NULL' : '' ;
    my $search_doc2 = ( defined $args->{search_doc2} && $args->{search_doc2} eq 1) ? ' AND t1.documents2 IS NULL' : '' ;
    my $search_lib = ( defined $args->{search_lib} && $args->{search_lib} ne '' ) ? ' AND t1.libelle ILIKE ?' : '' ;
    my $search_piece = ( defined $args->{search_piece} && $args->{search_piece} ne '' ) ? ' AND t1.id_facture ILIKE ?' : '' ;
    my $search_credit = ( defined $args->{search_credit} && $args->{search_credit} ne '') ? ' AND credit::TEXT ILIKE ? ' : '' ;
    my $search_debit = ( defined $args->{search_debit} && $args->{search_debit} ne '') ? ' AND debit::TEXT ILIKE ? ' : '' ;
    my $search_journal = ( defined $args->{search_journal} && $args->{search_journal} ne '' ) ? ' AND t1.libelle_journal ILIKE ?' : '' ;
    my $search_compte = ( defined $args->{search_compte} && $args->{search_compte} ne '' ) ? ' AND t1.numero_compte ILIKE ?' : '' ;
    my $search_let = ( defined $args->{search_let} && $args->{search_let} ne '' ) ? ' AND lettrage ILIKE ?' : '' ;
    my $search_libre = ( defined $args->{search_libre} && $args->{search_libre} ne '' ) ? ' AND id_paiement ILIKE ?' : '' ;
    my $search_date = ( defined $args->{search_date} && $args->{search_date} ne '' && $args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) ? ' AND t1.date_ecriture = ?' : '' ;
    my $search_date2 = ( defined $args->{search_date} && $args->{search_date} ne '' && not($args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/)) ? ' AND t1.date_ecriture::TEXT ILIKE ?' : '' ;
	my $search1 = ( defined $args->{search1} && $args->{search1} eq 1) ? ' and t1.documents1 NOT LIKE \'%\' || t1.id_facture || \'%\'' : '' ;
   
    if ( $args->{open_journal} eq 'Journal général' )  {
		$sql = '
		SELECT t2.date_validation, t1.id_entry, t1.id_line, t1.id_export, coalesce(t1.num_mouvement, \'&nbsp;\') as num_mouvement, t1.date_ecriture, t2.id_export, t1.libelle_journal, t1.numero_compte, t3.libelle_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, lettrage, pointage, recurrent
		FROM tbljournal t1
		LEFT JOIN tblexport t2 on t1.id_client = t2.id_client and t1.fiscal_year = t2.fiscal_year and t1.id_export = t2.id_export
		INNER JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.numero_compte = t3.numero_compte
		WHERE t1.id_client = ? AND t1.fiscal_year = ? '. $search_lib.' '. $search_piece.' '.$search_credit.' '.$search_debit.' '.$search_doc1.' '.$search_doc2.' '.$search_journal.' '.$search_compte.' '.$search_let.' '.$search_libre.' '.$search_date.' '.$search_date2.' ' . $month_clause . ' ' . $search_rec . ' ' . $search_eq . ' ' . $search_nonlet . ' ' .$search1. '
		ORDER BY length(t1.num_mouvement), t1.num_mouvement, t1.date_ecriture, CASE WHEN t1.libelle_journal ~* \'nouv|NOUV\' THEN 1 END, t1.id_entry, t1.id_facture, t1.libelle, t1.libelle_journal, t1.id_paiement, t1.numero_compte, t1.id_line
		' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
    } else {
		$sql = '
		SELECT t2.date_validation, t1.id_entry, t1.id_line, t1.id_export, coalesce(t1.num_mouvement, \'&nbsp;\') as num_mouvement, t1.date_ecriture, t2.id_export, t1.libelle_journal, t1.numero_compte, t3.libelle_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, lettrage, pointage, recurrent
		FROM tbljournal t1
		LEFT JOIN tblexport t2 on t1.id_client = t2.id_client and t1.fiscal_year = t2.fiscal_year and t1.id_export = t2.id_export
		INNER JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.numero_compte = t3.numero_compte
		WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.libelle_journal = ?  '. $search_lib.' '. $search_piece.' '.$search_credit.' '.$search_debit.' '.$search_doc1.' '.$search_doc2.' '.$search_journal.' '.$search_compte.' '.$search_let.' '.$search_libre.' '.$search_date.' '.$search_date2.' ' . $month_clause . ' ' . $search_rec . ' ' . $search_eq . ' ' . $search_nonlet . '
		ORDER BY length(t1.num_mouvement), t1.num_mouvement, t1.date_ecriture, CASE WHEN t1.libelle_journal ~* \'nouv|NOUV\' THEN 1 END, t1.id_entry, t1.id_facture, t1.libelle, t1.libelle_journal, t1.id_paiement, t1.numero_compte, t1.id_line
		' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{open_journal} ) ;
    }
    
    if (defined $args->{search_lib} && $args->{search_lib} ne ''){
	$search[1] = '%' . $args->{search_lib} . '%' ;
	push @bind_array, $search[1] unless ( $args->{search_lib} eq '') ;
	}
	
	if (defined $args->{search_piece} && $args->{search_piece} ne ''){
	$search[2] = '%' . $args->{search_piece} . '%' ;
    push @bind_array, $search[2] unless ( $args->{search_piece} eq '') ;
	}
	
	if (defined $args->{search_debit} && $args->{search_debit} ne ''){
	$search[3] = '%' . $args->{search_debit} . '%' ;
	push @bind_array, $search[3] unless ( $args->{search_debit} eq '') ;
	}
	
	if (defined $args->{search_credit} && $args->{search_credit} ne ''){
	$search[4] = '%' . $args->{search_credit} . '%' ;
	push @bind_array, $search[4] unless ( $args->{search_credit} eq '') ;
	}
	
	if (defined $args->{search_journal} && $args->{search_journal} ne ''){
	$search[5] = '%' . $args->{search_journal} . '%' ;
	push @bind_array, $search[5] unless ( $args->{search_journal} eq '') ;
	}
	
	if (defined $args->{search_compte} && $args->{search_compte} ne ''){
	$search[6] = '%' . $args->{search_compte} . '%' ;
	push @bind_array, $search[6] unless ( $args->{search_compte} eq '') ;
	}
	
	if (defined $args->{search_let} && $args->{search_let} ne ''){
	$search[7] = '%' . $args->{search_let} . '%' ;
	push @bind_array, $search[7] unless ( $args->{search_let} eq '') ;
	}
	
	if (defined $args->{search_libre} && $args->{search_libre} ne ''){
	$search[8] = '%' . $args->{search_libre} . '%' ;
	push @bind_array, $search[8] unless ( $args->{search_libre} eq '') ;
	}
	
	if (defined $args->{search_date} && $args->{search_date} ne '' && $args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) {
	$search[9] = $args->{search_date};
	push @bind_array, $search[9] unless ( $args->{search_date} eq '') ;
	}
	
	if (defined $args->{search_date} && $args->{search_date} ne '' && not($args->{search_date} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/)) {
	$search[10] = '%' . $args->{search_date} . '%' ;
	push @bind_array, $search[10] unless ( $args->{search_date} eq '') ;
	}
	
	if (defined $args->{recurrent} && $args->{recurrent} ne ''){
	push @bind_array, $args->{recurrent} unless ( $args->{recurrent} eq '' ) ;
	}
	
	if (defined $args->{equilibre} && $args->{equilibre} ne ''){
	$search[11] = $r->pnotes('session')->{id_client} ;	
	$search[12] = $r->pnotes('session')->{fiscal_year} ;	
	push @bind_array, $search[11] unless ( $args->{equilibre} eq '' ) ;
	push @bind_array, $search[12] unless ( $args->{equilibre} eq '' ) ;
	}
	
	if (defined $args->{search_doc1} && $args->{search_doc1} eq 1){
	$checked[1] = 'checked';
	} else {
	$checked[1] = '';
	}
	
	if (defined $args->{search_doc2} && $args->{search_doc2} eq 1){
	$checked[2] = 'checked';
	} else {
	$checked[2] = '';	
	}	

    #ne pas ajouter le paramètre mois si $args->mois = 0
    push @bind_array, $args->{mois} unless ( $args->{mois} eq '0' ) ;

    my $result_set = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, @bind_array ) ;

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Vérification $r->unparsed_uri() : '.$r->unparsed_uri().' et $r->uri : '.$r->the_request().' et $r->args :'.$r->args.'');

	###### Formulaires filtres analyses ######
    my $analyses = '';
	if (defined $args->{analyses}) {
		$analyses .= '
		<div class="wrapper35">

		<div class="form-int centrer">
			<form id="test" action="/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $args->{open_journal} ) . '&amp;mois=0&amp;analyses" method="post">
				<select onchange="submit()" class="login-text" style="width: 25%;" name="search1" id="select_journal">
					<option value="" selected="">--Sélectionner une requête--</option>
					<option value="search_doc1">Afficher les écritures sans doc1</option>
					<option value="search_doc2">Afficher les écritures sans doc2</option>
					<option value="1">Mauvaise référence de pièce dans le document</option>
				</select>
				<select onchange="submit()" class="login-text" style="width: 25%;" name="select_compte1" id="select_compte">
					<option value="" selected="">--Sélectionner une requête--</option>
					<option value="455100">455100 - Associé Compte courant</option>
					<option value="511200">511200 - Chèques à encaisser</option>
				</select>
				<input type="reset" onclick="submit()" class="btn btn-orange" value="Reset">
			</form>
		</div>
		';
	}
	
	#$content .= $analyses;

    #ligne d'en-têtes
    my $entry_list = '
	<li class="style1"><div class="headerspan2 centrer" style="padding-left: 0px;"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 3%;">#</span>
	<span class=headerspan style="width: 8%;">Date</span>
	<span class=headerspan style="width: 7%;">Journal</span>
	<span class=headerspan style="width: 7%;">Libre</span>
	<span class=headerspan style="width: 7%;">Compte</span>
	<span class=headerspan style="width: 14%;">Pièce</span>
	<span class=headerspan style="width: 26%;">Libellé</span>
	<span class=headerspan style="width: 8.5%;">Débit</span>
	<span class=headerspan style="width: 8.5%;">Crédit</span>
	<span class=headerspan style="width: 3.2%;">L</span>
	<span class=headerspan style="width: 0.5%;">&nbsp;</span>
	<span class=headerspan style="width: 2%;">&nbsp;</span>
	<span class=headerspan style="width: 2%;">&nbsp;</span>
	<span class=headerspan style="width: 2%;">&nbsp;</span>
	<div class=spacer></div></div></li>

	<li class="style1"><div class=headerspan2 style="padding-left: 0px;">  
	<form id="myForm" method=POST>
	<div class=flex-table><div class=spacer></div>
	<span class=displayspan_search style="width: 3.5%;">&nbsp;</span>
	<span class=displayspan_search style="width: 8%;"><input class=search type=text name="search_date" id="search_date" value="' . ($args->{search_date} || ''). '" pattern="(?:((?:0[1-9]|1[0-9]|2[0-9])\/(?:0[1-9]|1[0-2])|(?:30)\/(?!02)(?:0[1-9]|1[0-2])|31\/(?:0[13578]|1[02]))\/(?:19|20)[0-9]{2})" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\');submit()" ></span>
	<span class=displayspan_search style="width: 7%;"><input class=search type=text name="search_journal" id="search_journal" value="' . ($args->{search_journal} || ''). '" onchange="submit()" onclick="liste_search_journal(this.value)" list="journallist"><datalist id="journallist"></datalist></span>
	<span class=displayspan_search style="width: 7%;"><input class=search type=text name="search_libre" id="search_libre" value="' . ($args->{search_libre} || ''). '" onchange="submit()" onclick="liste_search_libre(this.value)" list="librelist"><datalist id="librelist"></datalist></span>
	<span class=displayspan_search style="width: 7%;" ><input class=search type=text name="search_compte" id="search_compte" value="' . ($args->{search_compte} || ''). '" onchange="submit()" onclick="liste_search_compte(this.value)" list="comptelist"><datalist id="comptelist"></datalist></span>
	<span class=displayspan_search style="width: 14%;"><input class=search type=text name="search_piece" id="search_piece" value="' . ($args->{search_piece} || ''). '" onchange="submit()" onclick="liste_search_piece(this.value, 6)" list="piecelist_6"><datalist id="piecelist_6"></datalist></span>
	<span class=displayspan_search style="width: 26%;"><input class=search type=text name="search_lib" id="search_lib" value="' . ($args->{search_lib} || ''). '" onchange="submit()" onclick="liste_search_libelle(this.value, 6)" list="libellelist_6"><datalist id="libellelist_6"></datalist></span>
	<span class=displayspan_search style="width: 8.5%; text-align: right;"><input class=search type=text name="search_debit" id="search_debit" value="' . ($args->{search_debit} || ''). '"  onchange="submit()"></span>
	<span class=displayspan_search style="width: 8.5%; text-align: right;"><input class=search type=text name="search_credit" id="search_credit" value="' . ($args->{search_credit} || ''). '" onchange="submit()"></span>
	<span class=displayspan_search style="width: 3.2%; text-align: right;"><input class=search type=text name="search_let" id="search_let" value="' . ($args->{search_let} || ''). '" onchange="submit()" onclick="liste_search_lettrage(this.value)" list="lettragelist"><datalist id="lettragelist"></datalist></span>
	<span class=displayspan_search style="width: 0.5%;">&nbsp;</span>
	<span class=displayspan_search style="width: 2%; text-align: center;"><input style="height: 3ch;" type=checkbox name="search_doc1" id="search_doc1" title="Afficher les écritures sans doc1" value=1  onchange="submit()" '.$checked[1].'></span>
	<span class=displayspan_search style="width: 2%; text-align: center;"><input style="height: 3ch;" type=checkbox name="search_doc2" id="search_doc2" title="Afficher les écritures sans doc2" value=1  onchange="submit()" '.$checked[2].'></span>
	<span class=displayspan_search style="width: 2%;">&nbsp;</span>
	<span style="width: 2.4%; margin-left : 0.5%;"></span>
	<div class=spacer></div></div></form></div></li>
	' ;

    my $id_entry = '' ;
    

	for ( @$result_set ) {

		#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
		
		if ( defined $id_entry ) { 
			unless ( $_->{id_entry} eq $id_entry ) {
				#lien de modification de l'entrée
				my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $_->{id_entry} ;
				#cas particulier de la première entrée de la liste : pas de liste précédente
				unless ( $id_entry ) {
					$entry_list .= '<li class=listitem3>' ;
				} else {
					$entry_list .= '</a></li><li class=listitem3>'
				}
			}
		}

		#marquer l'entrée en cours
		$id_entry = $_->{id_entry} ;

		my $http_link_documents1 = '<span class=blockspan style="width: 2%; text-align: center;"><img id="documents_'.$_->{id_line}.'" class="line_icon_hidden" height="16" width="16" title="Ouvrir le document1" src="/Compta/style/icons/documents.png" alt="document1"></span>';
		my $http_link_documents2 = '<span class=blockspan style="width: 2%; text-align: center;"><img id="releve_'.$_->{id_line}.'" class="line_icon_hidden" height="16" width="16" title="Ouvrir le document2" src="/Compta/style/icons/releve-bancaire.png" alt="releve-bancaire"></span>';
		my $http_link_ecriture_valide = '<span class=blockspan style="width: 2%; text-align: center;"><img id="valide_'.$_->{id_line}.'" class="line_icon_hidden" height="16" width="16" title="Validée le '. ($_->{date_validation} || '').'" src="/Compta/style/icons/cadena.png" alt="valide"></span>';
		
		#Affichage icon cadena si écriture validée
		if ($_->{date_validation}) {
		$http_link_ecriture_valide = '<span class=blockspan style="width: 2%; text-align: center;"><img id="valide_'.$_->{id_line}.'" class="line_icon_visible" height="16" width="16" title="Validée le '. ($_->{date_validation} || '').'" src="/Compta/style/icons/cadena.png" alt="valide"></span>';	
		}
		
		#Affichage lien docs1 si docs1
		if ( $_->{documents1} =~ /docx|odt|pdf|jpg/i ) { 
			my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?' ;
			my $id_name_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $_->{documents1} ) ;
			if ($id_name_documents->[0]->{id_name} || '') {
			$http_link_documents1 = '
			<a class=nav href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($id_name_documents->[0]->{id_name} || '').'">				
			<span class=blockspan style="width: 2%; text-align: center;"><img id="documents_'.$_->{id_line}.'" class="line_icon_visible" height="16" width="16" title="Ouvrir le document1" src="/Compta/style/icons/documents.png" alt="document1"></span></a>
			';
			}
		} 	
		
		#Affichage lien docs2 si docs2
		if ( $_->{documents2} =~ /docx|odt|pdf|jpg/i ) { 
			my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?' ;
			my $id_name_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $_->{documents2} ) ;
			if ($id_name_documents->[0]->{id_name} || '') {
			$http_link_documents2= '
			<a class=nav href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($id_name_documents->[0]->{id_name} || '').'">				
			<span class=blockspan style="width: 2%; text-align: center;"><img id="releve_'.$_->{id_line}.'" class="line_icon_visible" height="16" width="16" title="Ouvrir le document2" src="/Compta/style/icons/releve-bancaire.png" alt="releve-bancaire"></span></a>
			';	
			}
		} 	

		#lien de modification de l'entrée
		my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;mois=' . $args->{mois} . '&amp;id_entry=' . $_->{id_entry} ;
		
		$entry_list .= '
		<div class=flex-table><div class=spacer></div><a href="' . $id_entry_href . '" >
		<span class=blockspan style="width: 0.5%;">&nbsp;</span>
		<span class=blockspan style="width: 3%;">' . ($_->{num_mouvement} || '&nbsp;' ). '</span>
		<span class=blockspan style="width: 8%;">' . $_->{date_ecriture} . '</span>
		<span class=blockspan style="width: 7%;">' . $_->{libelle_journal} .'</span>
		<span class=blockspan style="width: 7%;">' . ($_->{id_paiement} || '&nbsp;' ) .'</span>
		<span class=blockspan style="width: 7%;" title="'. $_->{libelle_compte} .'">' . $_->{numero_compte} . '</span>
		<span class=blockspan style="width: 14%;">' . ($_->{id_facture} || '&nbsp;' ) . '</span>
		<span class=blockspan style="width: 26%;">' . ($_->{libelle} || '&nbsp;' ) . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">' . $_->{debit} . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">' .  $_->{credit} . '</span>
		<span class=blockspan style="width: 3.2%; text-align: right;">' .  ( $_->{lettrage} || '&nbsp;' ) . '</span>
		<span class=blockspan style="width: 0.5%;">&nbsp;</span>
		'.$http_link_documents1.'
		'.$http_link_documents2.'
		'.$http_link_ecriture_valide.'
		<div class=spacer></div></div>
		' ;

	} #    for ( @$result_set ) 

	
	
	if ( @$result_set ) {
		#on clot la liste s'il y avait au moins une entrée dans le journal
		$entry_list .= '</a></li>'  ;
	} else {
		$entry_list .= '<li class=style1><hr></li><div class="warnlite">*** Aucune écriture trouvée ***</div>';
	}

	$entry_list .=  '<li class=style1><hr></li>
	<li class=style1><div class=flex-table><div class=spacer></div>
	<span class=displayspan style="width: 72.5%; text-align: right; padding-right: 5%; font-weight: bold;">Total</span>
	<span class=displayspan style="width: 8.5%; text-align: right;">' . ( $result_set->[0]->{total_debit} || '0,00' ) . '</span>
	<span class=displayspan style="width: 8.5%; text-align: right;">' . ( $result_set->[0]->{total_credit} || '0,00' ) . '</span>
	<div class=spacer></div></li>' ;

	$content .= '<div class="wrapper">'.$sousmenu.'<ul class=wrapper1>' . $entry_list . '</ul></div>' ;
	
    return $content ;
    
} #sub open_journal

sub edit_journal_set {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array ) ;
    my $content = '';
    $content .= display_journal_set( $r, $args ) ;
    my $i = "1"; 
    my $line = "1"; 
    $args->{restart} = 'journal?configuration';
    
    #/************ ACTION DEBUT *************/

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Importer' 					  #
	#######################################################################
    if ( defined $args->{configuration} && defined $args->{import} && $args->{import} eq '1') {
		#envoi d'un fichier par l'utilisateur
		unless ( $args->{import_file} ) {		
			$content .= Base::Site::util::generate_error_message('Aucun fichier n\'a été sélectionné pour le téléchargement!');
		} else {
			#on a un fichier, traiter les données
			my $req = Apache2::Request->new( $r ) ;
			my $upload = $req->upload("import_file") or warn $!  ;
			my $upload_fh = $upload->fh() ;
			my $journal_liste = '' ;

			#on suppose que les données sont en UTF-8
			my $valid_data = 1 ;
			my $rowCount = 0 ;  
			
			while (my $data = <$upload_fh>) {
				
				$rowCount = $rowCount+1;
				
				if ($data =~ /journalcode|journallib|journaltype/ ) {next;}
				chomp($data);

				#vérifier qu'on a bien du utf8; sinon, avorter et envoyer message d'erreur
				eval { $data = Encode::decode( "utf8", $data, Encode::FB_CROAK ) };

				if ( $@ ) { # input was not utf8
					$content .= '<h3 class=warning>Les données transmises ne sont pas au format UTF-8, importation impossible</h3>' ;		    
					$valid_data = 0 ; #mettre valid_data à 0 pour empêcher l'importation
					last ; #inutile de continuer
				} 
				
				$data =~ s/'/''/g ; #remplacer les ' par '' pour postgres
				my @data = split ';', $data ;
				
				#$data[0] => journalcode
				#$data[1] => journallib
				#$data[2] => journaltype
				
				# Vérification du type de journal
				if (defined $data[2] && !($data[2] eq 'Achats' || $data[2] eq 'Ventes' || $data[2] eq 'Trésorerie' || $data[2] eq 'Clôture' || $data[2] eq 'OD' || $data[2] eq 'A-nouveaux')) {
					$content .= '<h3 class="warning centrer">ligne '.$rowCount.' => colonne 3 : Type de journal *** ' . $data[2]. ' *** n\'est pas reconnu<br><br> Sont autorisés => (Achats, Ventes, Trésorerie, Clôture, OD, A-nouveaux) 
					<br><br><a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3></h3>' ;		    
					$valid_data = 0 ;
					last ;
				}
				
				$journal_liste .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $r->pnotes('session')->{fiscal_year} . ', E\'' . $data[0] . '\', E\'' . $data[1] . '\', E\'' . $data[2] . '\')' ;

			} #		while (my $data = <$upload_fh>) 

			if ( $valid_data ) {
				
				#on retire la première virgule de $comte_liste
				$sql = 'INSERT INTO tbljournal_liste (id_client, fiscal_year, code_journal, libelle_journal, type_journal) VALUES ' . substr( $journal_liste, 1).'
				ON CONFLICT (id_client, fiscal_year, libelle_journal) 
				DO UPDATE SET (code_journal, type_journal) = (EXCLUDED.code_journal, EXCLUDED.type_journal)
				';
				#insérer les données
				eval { $dbh->do( $sql ) } ;

				if ( $@ ) {
					
					if ( $@ =~ /unique/ ) {
					$content .= '<h3 class=warning>Un des journaux importés existe déjà</h3>' ;		    
					} elsif ( $@ =~ /tbljournal_type/ ) {
					#regex last ()
					$@ =~ /[\s\S]*\((.*?)\)/;  
					$content .= '<h3 class="warning centrer">Mauvais type de journal !!! ' . $1. ' !!! <br><br> Sont autorisés => (Achats, Ventes, Trésorerie, Clôture, OD, A-nouveaux)</h3>' ;		    
					} elsif ( $@ =~ /CONFLICT|exist/ ) {
					$content .= '<h3 class="warning centrer">Erreurs détectées !! vérifier le format de vos données <br><br>
					<a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a>
					</h3>' ;		    
					} else {
					$content .= '<h3 class=warning>' . $@ . '</h3>' ;		    
					} #		    if ( $@ =~ /unique/ ) 
				} else {
				my $error_message = "Importation effectuée avec succès.";
				$content .= Base::Site::util::generate_error_message($error_message);
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Restauration des journaux à partir d\'un fichier pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');
				}
			} 
		} 
	} 
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    if ( defined $args->{configuration} && defined $args->{supprimer} && $args->{supprimer} eq '0') {
		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration&amp;supprimer=1&amp;code_journal=' . $args->{old_code_journal}.'&amp;libelle_journal=' . $args->{libelle_journal} ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le journal &quot;' . $args->{libelle_journal} . '&quot;?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif (defined $args->{configuration} && defined $args->{supprimer} && $args->{supprimer} eq '1') {
		#on empêche la suppression du journal des OD et journal CL de CLOTURE et journal AN A NOUVEAUX
		$sql = 'DELETE FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? AND libelle_journal = ? AND code_journal !~ \'OD\' AND code_journal !~ \'CL\' AND code_journal !~ \'AN\'' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{libelle_journal} ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /tbljournal_id_client_fiscal_year_libelle_journal_fkey/ ) {
				$content .= Base::Site::util::generate_error_message('Le journal n\'est pas vide : suppression impossible ') ;
			} else {
				$content .= Base::Site::util::generate_error_message('' . $@ . '') ;
			}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Suppression du journal '.$args->{libelle_journal}.' ');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}

	} 
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'ajouter' 					  #
	#######################################################################
    if ( defined $args->{configuration} && defined $args->{ajouter} && $args->{ajouter} eq '1') {
		
		$args->{type_journal} ||= undef ;
		$args->{code_journal} ||= undef ;
		$args->{libelle_journal} ||= undef ;
		
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{libelle_journal});
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{code_journal});
		
		if (!$args->{type_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement sélectionner un type de journal') ;
		} elsif (!$args->{code_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un code journal') ;
		} elsif (!$args->{libelle_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé journal') ;
		} else {
			#nouveau journal
			$sql = 'INSERT INTO tbljournal_liste (libelle_journal, id_client, fiscal_year, code_journal, type_journal) VALUES (?, ?, ?, ?, ?)' ;
			@bind_array = ( $args->{libelle_journal}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{code_journal}, $args->{type_journal} ) ;
			eval { $dbh->do( $sql, undef, @bind_array ) } ;
	    	
	    	if ( $@ ) {
				if ( $@ =~ /unique/ ) {
					$content .= Base::Site::util::generate_error_message('Ce nom de journal existe déjà : modification impossible') ;
				} else {
					$content .= Base::Site::util::generate_error_message('' . $@ . '') ;
				}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Ajout du journal '.$args->{code_journal}.' - '.$args->{libelle_journal}.' de type '.$args->{type_journal} .'');
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		
		}
	}
		
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'modifier' 					  #
	#######################################################################
	if ( defined $args->{configuration} && defined $args->{modifier} && $args->{modifier} eq '1') {
		$args->{new_type_journal} ||= undef ;
		$args->{new_code_journal} ||= undef ;
		$args->{new_libelle_journal} ||= undef ;
		
		
		if (!$args->{new_type_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement sélectionner un type de journal') ;
		} elsif (!$args->{new_code_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un code journal') ;
		} elsif (!$args->{new_libelle_journal}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé journal') ;
		} else {
			#mise à jour d'un libelle; empêcher la modification du journal des OD et journal CL de CLOTURE et journal AN A NOUVEAUX
			$sql = 'UPDATE tbljournal_liste set libelle_journal = ?, code_journal = ?, type_journal = ? WHERE id_client = ? AND fiscal_year = ? AND (libelle_journal = ? OR code_journal = ?) AND code_journal !~ \'OD\' AND code_journal !~ \'CL\' AND code_journal !~ \'AN\'' ;
			@bind_array = ( $args->{new_libelle_journal}, $args->{new_code_journal}, $args->{new_type_journal}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{old_libelle_journal}, $args->{old_code_journal} ) ;
			eval { $dbh->do( $sql, undef, @bind_array ) } ;
			
	    	if ( $@ ) {
				if ( $@ =~ /unique/ ) {
					$content = '<h3 class=warning>Ce nom de journal existe déjà : modification impossible</h3>' ;
				} else {
					$content .= '<h3 class=warning>' . $@ . '</h3>' ;
				}
			} else {
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
	}

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Reconduire' 					  #
	#######################################################################
	#attention aux débuts d'exercice décalés
    #pour l'affichage, l'exercice mentionné est "année N - année N+1"
    my $exercice_a_reconduire ;
    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
	$exercice_a_reconduire = ( $r->pnotes('session')->{fiscal_year} - 1 ) . '-' . $r->pnotes('session')->{fiscal_year} ;
    } else {
	$exercice_a_reconduire = $r->pnotes('session')->{fiscal_year} - 1 ;
    }
    if ( defined $args->{configuration} && defined $args->{reconduire} && $args->{reconduire} eq '0') {
		#1ère demande de reconduction; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration&amp;reconduire=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous reconduire les journaux de l\'exercice ' . $exercice_a_reconduire . '?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a>') ;
	} elsif ( defined $args->{configuration} && defined $args->{reconduire} && $args->{reconduire} eq '1') {
		#demande de reconduction confirmée
		$sql = '
		INSERT INTO tbljournal_liste (libelle_journal, id_client, fiscal_year, code_journal, type_journal) 
		SELECT libelle_journal, ?, ? , code_journal, type_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ?
		ON CONFLICT (id_client, fiscal_year, libelle_journal) DO NOTHING' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /tbljournal_client_year_libelle_journal_pk/ ) {
				$content .= '<h3 class=warning>Un ou des journaux de l\'année précédente existent déjà : reconduction impossible</h3>' ;
			} else {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}
		}  else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'journal.pm => Reconduction des journaux pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}
	    
    }
   
	#/************ ACTION FIN *************/
	
	#####################################       
	# Récupérations d'informations		#
	##################################### 
	
	#Requête tbljournal_type
	$sql = 'SELECT type_journal FROM tbljournal_type ORDER by type_journal' ;
    my $journal_type_set = $dbh->selectall_arrayref($sql, undef) ;
	my $type_journal = '<select class="login-text" style="width: 30%;" name=type_journal id=type_journal>' ;
	if (!($args->{type_journal})) {
	$type_journal .= '<option value="" selected>--Sélectionner le type de journal--</option>';	
	}
	for ( @$journal_type_set ) {
	$type_journal .= '<option ' . ( ( ($args->{type_journal} || '') eq $_->[0] ) ? 'selected' : '' ) . ' value="' . $_->[0] . '">' . $_->[0] . '</option>' ;
	}
	$type_journal .= '</select>' ;
	
	
	#Requête tbljournal_liste	
	my $journal_set = Base::Site::bdd::get_journaux($dbh, $r);

	############## Formulaire Ajouter un journal ##############	
    my $journal_list = '
    <fieldset  class="pretty-box"><legend><h3 class="Titre09">Gestion des journaux</h3></legend>
    <div class=centrer>
    
    	<form method="post">
		<input type="submit" class="btn btn-vert" style ="width : 30%;" formaction="journal&#63;configuration&amp;reconduire=0" value="Reconduire les journaux depuis l\'exercice ' . ( $exercice_a_reconduire ) . '">
		<input type="submit" class="btn btn-orange" style ="width : 30%;"  formaction="export&#63;id_mois=00&amp;id_export=0&amp;select_export=liste_journaux" value="Télécharger la liste des journaux pour l\'exercice en cours">
		</form>
		
		<br>
		
		<div class=Titre10>Importer les journaux <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'journaux_3\');" style="cursor: pointer;" >[?]</span></div>
		<div class="form-int">
			<form style ="display:inline;" action="/'.$r->pnotes('session')->{racine}.'/journal" method=POST enctype="multipart/form-data">
			<input type=hidden name=configuration value=>
			<input type=hidden name=import value=1>
			<input type=file name=import_file>
			<input type="submit" class="btn btn-gris" style ="width : 25%;" value="Cliquez ici pour envoyer">
			</form>
		</div>
    
        <div class=Titre10>Ajouter un journal</div>
		<div class="form-int">
			<form method="post" action=/'.$r->pnotes('session')->{racine}.'/journal?configuration>
			<div class=formflexN2>
			<input class="login-text" type=text placeholder="Entrer le code journal" name="code_journal" value="'.($args->{code_journal} || '').'" style="width: 15%;" required maxlength="3">
			<input class="login-text" type=text placeholder="Entrer le libellé journal" name="libelle_journal" value="'.($args->{libelle_journal} || '').'" style="width: 35%;" required >
			'.$type_journal.'
			<input type=hidden name="ajouter"  value=1>
			<input type=submit class="btn btn-vert" style ="width : 10%;" value=Valider>
			</div>
			</form>
		</div>
		
    ' ;
    
    #ligne des en-têtes
    $journal_list .= '
		<div class=Titre10>Modifier un journal existant</div>
		<ul class=wrapper10><li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<span class=headerspan style="width: 19%; text-align: center;">Code journal</span>
		<span class=headerspan style="width: 19%; text-align: center;">Libellé journal</span>
		<span class=headerspan style="width: 19%; text-align: center;">Type journal</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 4%;">&nbsp;</span>
		<span class=headerspan style="width: 0.3%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
    
    ############## Formulaire Modifier un journal existant ##############	
    for ( @$journal_set ) {
	my $reqline = ($line ++);	
		
	my $valider_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration&amp;modifier=1' ;
	my $delete_href = '/'.$r->pnotes('session')->{racine}.'/journal?configuration&amp;supprimer=0&amp;libelle_journal=' . URI::Escape::uri_escape_utf8($_->{libelle_journal}) ;
	my $delete_link = ( $_->{code_journal} eq 'OD' || $_->{code_journal} eq 'CL' || $_->{code_journal} eq 'AN') ? '<span class="displayspan" style="width: 4%; text-align: center;"><input type="image" class="line_icon_hidden" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>' : '<span class="blockspan" style="width: 4%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="24" width="24" alt="supprimer"></span>' ;
	my $disabled = ( $_->{code_journal} eq 'OD' || $_->{code_journal} eq 'CL' || $_->{code_journal} eq 'AN' ) ? ' disabled' : '' ;
	
	my $selected_type_journal= $_->{type_journal};
	my $type_journal_select = '<select onchange="findModif(this,'.$reqline.');" class="formMinDiv4" name=new_type_journal id=type_journal_'.$reqline.' ' . $disabled . '>';
	for ( @$journal_type_set ) {
	my $selected = ( $_->[0] eq ($selected_type_journal || '') ) ? 'selected' : '' ;
	$type_journal_select .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . '</option>' ;
	}
	if (!($_->{type_journal})) {
	$type_journal_select .= '<option value="" selected>--Sélectionner le type de journal--</option>' ;
	}
	$type_journal_select .= '</select>' ;	

	
	$journal_list .= '
		<li id="line_'.$reqline.'" class="style1">  
		<form class=flex1 method="post" action=/'.$r->pnotes('session')->{racine}.'/journal?configuration>
		<span class=displayspan style="width: 0.3%;">&nbsp;</span>
		<span class=displayspan style="width: 19%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name="new_code_journal" value="' . $_->{code_journal} . '" ' . $disabled . ' maxlength="3"></span>
		<span class=displayspan style="width: 19%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv4" type=text name="new_libelle_journal" value="' . $_->{libelle_journal} . '" ' . $disabled . '></span>
		<span class=displayspan style="width: 19%;">'.$type_journal_select.'</span>
		<span class="displayspan" style="width: 4%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valider_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="24" width="24" alt="valider"></span>
		' . $delete_link . '
		<input type=hidden name="old_code_journal" value="' . $_->{code_journal} . '">
		<input type=hidden name="old_libelle_journal" value="' . $_->{libelle_journal} . '">
		</form>
		</li>
	';

    } #    for ( @$journal_set ) {

    $journal_list .= '
	</ul>
	</fieldset>
	';
		
	$content .= '<div class="formulaire2" >' . $journal_list . '</div>' ;

    return $content ;
    
} #sub edit_journal_set 

#/*—————————————— Menu JOURNAL 	——————————————*/
sub display_journal_set {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my $content ;
	my $journal_list = '' ;

	if (defined $args->{search_journal} && $args->{search_journal} ne '') {
		$args->{open_journal} = $args->{search_journal};
	} elsif (defined $args->{open_journal} && $args->{open_journal} ne '') {
	} else {
		$args->{open_journal} = 'Journal général';
	}

    # Fonction pour récupérer les journaux
    my $journal_set = Base::Site::bdd::get_journaux($dbh, $r);
    
    for ( @{$journal_set} ) {
		
		my $class = 'men men3';
		my $categorie_class = ( ($args->{open_journal} eq URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) || $args->{open_journal} eq  $_->{libelle_journal} ) ? 'men3select' : '' );
		
		my $journal_href = '/'.$r->pnotes('session')->{racine}.'/journal?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) ;	
		
		if 	(defined $args->{open_journal} && ($args->{open_journal} eq $_->{libelle_journal} || $args->{open_journal} eq URI::Escape::uri_escape_utf8( $_->{libelle_journal} ))) {
			$class= 'men men3 men3select';
			$journal_href = '/'.$r->pnotes('session')->{racine}.'/journal' ;
		}
			
		$journal_list .= '
		<li><form action="'.$journal_href.'" method=post>
		<a class="' . $class . '" href="#" onclick="parentNode.submit();">' . $_->{libelle_journal} . '</a>
		<input type=hidden name="search_date" value="' . ($args->{search_date} || ''). '">
		<input type=hidden name="search_journal" value="' . ($args->{search_journal} || ''). '">
		<input type=hidden name="search_libre" value="' . ($args->{search_libre} || ''). '">
		<input type=hidden name="search_compte" value="' . ($args->{search_compte} || ''). '">
		<input type=hidden name="search_piece" value="' . ($args->{search_piece} || ''). '">
		<input type=hidden name="search_lib" value="' . ($args->{search_lib} || ''). '">
		<input type=hidden name="search_debit" value="' . ($args->{search_debit} || ''). '">
		<input type=hidden name="search_credit" value="' . ($args->{search_credit} || ''). '">
		<input type=hidden name="search_let" value="' . ($args->{search_let} || ''). '">
		<input type=hidden name="search_doc1" value="' . ($args->{search_doc1} || ''). '">
		<input type=hidden name="search_doc2" value="' . ($args->{search_doc2} || ''). '">
		<input type=hidden name="search_let" value="' . ($args->{search_let} || ''). '">
		<input type=hidden name="search1" value="' . ($args->{search1} || ''). '">
		</form></li>' ;

	}
	
	#lien vers la catégorie "journal général"
	my $journal_general_href = '/'.$r->pnotes('session')->{racine}.'/journal' ;
	my $journal_general_class = (($args->{open_journal} =~ /général/ && not(defined $args->{configuration})) ? 'men3select' : '' );
	my $journal_general_link = '<li><a class="men men3 ' . $journal_general_class  . '" href="'.$journal_general_href.'" >Journal Général</a></li>' ;
	
	#lien de modification des journaux
	my $journal_edit_class = ( (defined $args->{configuration} ) ? 'men1select' : '' );
	my $journal_edit_href = ( defined $args->{configuration} ) ? '' : '?configuration' ;
	my $journal_edit_link = '<li><a class="men men1 ' . $journal_edit_class . '" href="/'.$r->pnotes('session')->{racine}.'/journal'.$journal_edit_href.'" title="Gestion des journaux" >Modifier&nbsp;la&nbsp;liste</a></li>' ;
	
	#Ne pas afficher Modifier la liste si exercice cloturé
	if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
	$content .= '<div class="menu"><ul class="main-nav2">' . $journal_edit_link . $journal_general_link . $journal_list . '</ul></div>' ;
	} else {
	$content .= '<div class="menu"><ul class="main-nav2">' . $journal_general_link . $journal_list . '</ul></div>' ;
	}

    return $content ;

} #sub display_journal_set 

1 ;
