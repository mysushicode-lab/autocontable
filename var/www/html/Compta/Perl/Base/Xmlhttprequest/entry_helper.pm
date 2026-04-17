package Base::Xmlhttprequest::entry_helper ;
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

use strict ;
use utf8 ;
use Apache2::Const -compile => qw(OK REDIRECT) ;
use Base::Site::util;  # Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   # Interaction avec la base de données (SQL)

sub handler {

    binmode(STDOUT, ":utf8") ;

    my $r = shift ;
	#utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    
    my $content = '' ;
			    
    my $req = Apache2::Request->new($r) ;

    #récupérer les arguments
    my %args ;

    for ( $req->param ) {

	$args{$_} = Encode::decode_utf8( $req->param($_) ) ;

	#nix those sql injection/htmlcode attacks!
	$args{$_} =~ tr/<>;/-/ ;

	#les double-quotes viennent interférer avec le html
	$args{$_} =~ tr/"/'/ ;

    }

    if ( defined $args{stage} ) {
	$content .= stage( $r, \%args ) ;
    }
	 
    if ( defined $args{numero_compte_datalist} ) {
	$content .= numero_compte_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{name_doc_datalist} ) {
	$content .= name_doc_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{name_libre_datalist} ) {
	$content .= name_libre_datalist( $r, \%args ) ;
    }

    if ( defined $args{calculer_numero_piece} ) {
	$content .= calculer_numero_piece( $r, \%args ) ;
    }
    
    if ( defined $args{calculer_num_piece} ) {
	$content .= calculer_num_piece( $r, \%args ) ;
    }
    
    if ( defined $args{select_contrepartie} ) {
	$content .= select_contrepartie( $r, \%args ) ;
    }
    
    if ( defined $args{search_journal_datalist} ) {
	$content .= search_journal_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{search_journal_datalist} ) {
	$content .= search_journal_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{search_cat_doc_datalist} ) {
	$content .= search_cat_doc_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{search_tag_datalist} ) {
	$content .= search_tag_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{convert_chiffre_texte} ) {
	$content .= convert_chiffre_texte( $r, \%args ) ;
    }
    
    if ( defined $args{search_libfrais_datalist} ) {
	$content .= search_libfrais_datalist( $r, \%args ) ;
    }

    if ( defined $args{search_compte_datalist} ) {
	$content .= search_compte_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{search_piece_datalist} ) {
	$content .= search_piece_datalist( $r, \%args ) ;
    }
    
    if ( defined $args{search_libelle_datalist} ) {
	$content .= search_libelle_datalist( $r, \%args ) ;
    }
  
    if ( defined $args{search_lettrage_datalist} ) {
	$content .= search_lettrage_datalist( $r, \%args ) ;
    }

    $r->content_type('text/plain; charset=utf-8') ;

    $r->no_cache(1) ;

    $r->print($content) ;

    return Apache2::Const::OK ;

}

#valide un input
sub stage {

    my ( $r, $args ) = @_;

    my $content = '' ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $column_name, $id_line ) = split( /_([^_]+)$/, $args->{stage} ) ;

    #cas de date_ecriture|paiement|pièce : mettre à jour tous les champs
    my ( $sql, @bind_array ) = ( '', '' ) ;
    
    #pour debit/credit, on enregistre des nombres entiers : multiplier la valeur par 100
    if ( $column_name =~ /debit|credit/ ) {

	$args->{value} *= 100 ;

    }
	
	if ( $column_name =~ /date_ecriture/ ) {

		# Supprime les espaces en début/fin
		$args->{value} =~ s/^\s+|\s+$//g;

		# Vérifie que le format est au moins cohérent : jj/mm/aaaa ou aaaa-mm-jj (séparateur / ou -)
		if ( $args->{value} =~ /^(\d{2}[-\/]\d{2}[-\/]\d{4}|\d{4}[-\/]\d{2}[-\/]\d{2})$/ ) {
			
			my ($annee, $mois, $jour);

			# Cas 1 : Format YYYY-MM-DD ou YYYY/MM/DD
			if ( $args->{value} =~ /^(\d{4})[-\/](\d{2})[-\/](\d{2})$/ ) {
				($annee, $mois, $jour) = ($1, $2, $3);
			}
			# Cas 2 : Format DD-MM-YYYY ou DD/MM/YYYY
			elsif ( $args->{value} =~ /^(\d{2})[-\/](\d{2})[-\/](\d{4})$/ ) {
				($jour, $mois, $annee) = ($1, $2, $3);
			}

			# Vérification stricte que la date existe (en utilisant Time::Local)
			eval {
				require Time::Local;
				Time::Local::timelocal(0, 0, 0, $jour, $mois - 1, $annee); # Lève une erreur si invalide
			};
			if ($@) {
				# Date invalide (ex: 31/02/2024)
				$content = 'signal_bad_date_input("' . $args->{stage} . '", "invalid_date");';
				return $content;
			}

			# Normalisation au format ISO pour comparaison lexicographique
			my $date_norm = sprintf("%04d-%02d-%02d", $annee, $mois, $jour);

			# Récupération des bornes de l'exercice depuis la session
			my $debut = $r->pnotes('session')->{Exercice_debut_YMD};
			my $fin   = $r->pnotes('session')->{Exercice_fin_YMD};

			# Vérification si la date est comprise dans l'exercice fiscal
			if ( $date_norm lt $debut || $date_norm gt $fin ) {
				# Date hors exercice fiscal
				$content = 'signal_bad_date_input("' . $args->{stage} . '", "fiscal");';
				return $content;
			}

			# Si tout est ok, mise à jour dans la base
			$sql = 'UPDATE tbljournal_staging SET ' . $column_name . ' = ? WHERE _token_id = ?';
			@bind_array = ( $args->{value} || undef, $args->{_token_id} );

		} else {
			# Format incorrect
			$content = 'signal_bad_date_input("' . $args->{stage} . '", "fiscal");';
			return $content;
		}
	} elsif (( $column_name =~ /id_paiement|id_facture|documents/ )) {
		
	#supprime les espaces de début et de fin de ligne
	$args->{value} =~ s/^\s+|\s+$//g;

	$sql = 'UPDATE tbljournal_staging set ' . $column_name . ' = ? WHERE _token_id = ?' ;

	@bind_array = ( $args->{value} || undef, $args->{_token_id} ) ;

    } else {
		
	#supprime les espaces de début et de fin de ligne
	$args->{value} =~ s/^\s+|\s+$//g;	
	
	$sql = 'UPDATE tbljournal_staging set ' . $column_name . ' = ? WHERE id_line = ? AND _token_id = ?' ;

	#passer undef dans le cas d'un libelle vide afin de préserver le NULL dans la table
	$args->{value} = undef if ( $column_name =~ /libel|documents|id_paiement/ and !$args->{value} ) ;
	
	@bind_array = ( $args->{value}, $id_line, $args->{_token_id} ) ;
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'entry_helper.pm => Variable : _session_id : '.($r->pnotes('session')->{_session_id} || undef).' et Colonne :'.($column_name || undef).' et value : '.($args->{value} || undef).' et _token_id : '.($args->{_token_id} || undef).' et $id_line : '.($id_line || undef).'');

	
    }
    eval { $dbh->do( $sql, { }, ( @bind_array ) ) } ;

    if ( $@ ) {
		
	if ( $@ =~ / bad fiscal year/ ) {
		
	#update refusé : renvoyer un message d'erreur à l'utilisateur
	$content = 'signal_bad_date_input("' . $args->{stage} . '", "fiscal");' ;
		
	} else {
				
	#update refusé : renvoyer un message d'erreur à l'utilisateur
	$content = 'signal_bad_input("' . $args->{stage} . '");' ;
	}
	
    } else {
	
	#l'insertion dans tbljournal_staging s'est bien passée; il faut faire un reset de l'attribut class dans les cas de correction d'un bad_input
	$content = 'rehab_bad_input("' . $args->{stage} . '");' ;
	
	#pour date_ecriture, id_paiement, id_facture, modifier les autres lignes
	if ( $column_name =~ /date_ecriture|id_paiement|id_facture|documents/ ) {

	    #il faut faire un stage(input) pour chaque ligne
	    $content .= 'for (i = 1; i < document.getElementsByName("' . $column_name .'").length; i++) {document.getElementsByName("'. $column_name .'")[i].value=document.getElementById("' . $column_name .'_' . $id_line . '").value};stage(document.getElementById("debit_' . $id_line . '"));' ;
	    
	}

	#pour les comptes 4456 (tva déductible), renseigner le champ débit par affectation du solde à la colonne débit
	if ( $column_name =~ /numero_compte/ ) {

	    $content .= 'if (document.getElementById("' . $args->{stage} . '").value.match("4456")) {document.getElementById("debit_' . $id_line . '").value=document.getElementById("total_solde").value;document.getElementById("total_solde").value=0;stage(document.getElementById("debit_' . $id_line . '"));};'

	} 

	#on doit toujours vérifier la balance de l'opération
	$content .= 'check_balance();' ;
	
    } #    if ( $@ ) 
	
    return $content ;
        
} #sub stage

#renseigne la datalist pour l'input numero_compte
sub numero_compte_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT numero_compte, libelle_compte FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND numero_compte ilike \'' . $args->{numero_compte_datalist} . '%\' ORDER BY numero_compte' ;

    my $option_list = '' ;
    
    #éviter de prendre *tous* les comptes quand $args->{numero_compte} est vide
    if ( $args->{numero_compte_datalist} ) {
	
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . ' - ' . $_->[1] . '";datalist_compte_' . $args->{id_line} . '.appendChild(option);' ;

	} #    for ( @$recordset ) 

    } #    if ( $args->{numero_compte} ) 

    #fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("datalist_compte_' . $args->{id_line} . '");' ;
    
    $content .= $option_list ;

    return $content ;

} #sub id_compte_datalist 

#renseigne la datalist pour l'input name_doc
sub name_doc_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
    
    my $sql = 'SELECT id_name FROM tbldocuments WHERE id_client= ? AND fiscal_year = ? AND id_name ilike \'' . $args->{name_doc_datalist} . '%\'ORDER BY id_name' ;

    my $option_list = '' ;
    
    #éviter de prendre *tous* les documents quand $args->{id_name} est vide
    if ( $args->{name_doc_datalist} ) {
	
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";doclist_' . $args->{id_line} . '.appendChild(option);' ;
	} #    for ( @$recordset ) 

    } #    if ( $args->{id_name} ) 

    #fonction de nettoyage de doclist_ 
    $content .= 'clearChildren("doclist_' . $args->{id_line} . '");' ;
    
    $content .= $option_list ;

    return $content ;

} #sub id_doc_datalist 

#calcule un nouveau numero de pièce pour une facture fournisseur ou une vente
sub calculer_numero_piece {
#utilise calculer_id_facture dans entry.js et dans entry.pm

    my ($r, $args) = @_ ;
    my $content = '' ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array ) ;
    my ($journal, $month, $year) = '';
    
    #journal
	$sql = 'SELECT libelle_journal, code_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal' ;
	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $journal_set = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
	
	for ( @$journal_set ) {
	if ($args->{open_journal} =~ $_->[0]) {
		$journal = $_->[1];	
		} 
	}
		
	if ((defined $args->{date_ecriture}) && $args->{date_ecriture} =~ /^(?<year>[0-9]{4}).*(?<month>[0-9]{2}).*(?<day>[0-9]{2})$/) {
	$month= substr($args->{date_ecriture},5,2);
    $year= substr($args->{date_ecriture},0,4);		
	} elsif (( defined $args->{date_ecriture}) && $args->{date_ecriture} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) {
	$month= substr($args->{date_ecriture},3,2);
    $year= substr($args->{date_ecriture},6,4);	
	}
	
    my $item_num = 1;
	
	#on regarde s'il existe des factures enregistrées pour le mois et l'année de la date d'enregistrement
	$sql = '
	SELECT id_facture as item_number, extract(month from ?::date) as month_number, extract(year from ?::date) as year_number
	FROM tbljournal
	WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ? AND substring(id_facture from 8 for 2) = ?
	ORDER BY 1 DESC LIMIT 1
	' ;
	

	@bind_array = ( $args->{date_ecriture}, $args->{date_ecriture}, $journal, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{open_journal}, $month ) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ; 
	
    #insecure dependency in sprintf if padding_zeroes is used directly from sessions
   ( my $padding_zeroes = $r->pnotes('session')->{padding_zeroes} ) =~ /(\d)/ ;
   
    for ( @$result_set ) {
			
		if (substr( $_->{item_number}, 10, 2 ) =~ /\d/ && substr( $_->{item_number}, 0, 2 ) =~ /$journal/) {
		$item_num = int(substr( $_->{item_number}, 10, 2 )) + 1	;
		} 
		}

		if ($result_set->[0]->{month_number} eq '1') {
			$month = '01';
		} elsif ($result_set->[0]->{month_number} eq '2') {
			$month = '02';
		} elsif ($result_set->[0]->{month_number} eq '3') {
			$month = '03';
		} elsif ($result_set->[0]->{month_number} eq '4') {
			$month = '04';
		} elsif ($result_set->[0]->{month_number} eq '5') {
			$month = '05';
		} elsif ($result_set->[0]->{month_number} eq '6') {
			$month = '06';
		} elsif ($result_set->[0]->{month_number} eq '7') {
			$month = '07';
		} elsif ($result_set->[0]->{month_number} eq '8') {
			$month = '08';
		} elsif ($result_set->[0]->{month_number} eq '9') {
			$month = '09';
		} elsif ($result_set->[0]->{month_number} eq '10') {
			$month = '10';
		} elsif ($result_set->[0]->{month_number} eq '11') {
			$month = '11';
		} elsif ($result_set->[0]->{month_number} eq '12') {
			$month = '12';
		}
		
		if ($item_num<10) {	$item_num="0".$item_num; }
	
		my $numero_piece = $journal . $year . '-' . $month . '_' . $item_num ;
	
	    #my $format ='%0' . $1 . 'd' ;
	    #my $numero_piece = $journal . $r->pnotes('session')->{fiscal_year} . '-' . $month . '_' . sprintf("$format", $item_num );
		#my $numero_piece = $journal . $year . '-' . $month . '_' . sprintf("$format", $item_num );

	    #on ajoute stage(input) pour Chrome qui ne déclenche pas onchange après on input
	    $content = $args->{calculer_numero_piece} . '.value="' . $numero_piece . '";stage(document.getElementById("' . $args->{calculer_numero_piece} . '"));' ;

    
    return $content ;
    
} #sub calculer_numero_piece 

#calcule un nouveau numero de pièce pour une facture fournisseur ou une vente
sub calculer_num_piece {
#utilise calculer_id_facture dans entry.js et dans entry.pm

    my ($r, $args) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content  ) ;

    my ($journal, $month, $year) = '';
  
	#récupération journal de réglement et compte de réglement
	$sql = 'SELECT config_libelle, config_compte, config_journal, module FROM tblconfig_liste WHERE id_client = ? and config_libelle = ? AND module = \'achats\'' ;
    my $resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $args->{calculer_num_piece} ) ) ;
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'entry_helper.pm => $args->{calculer_num_piece} '.$args->{calculer_num_piece}.'');
				
	my $reglement_journal = defined $args->{lib_journal} && length($args->{lib_journal}) > 0 ? $args->{lib_journal} : $resultat->[0]->{config_journal};
	my $reglement_compte = $resultat->[0]->{config_compte};

	#Récupérer code_journal
	my $journal_code_set = Base::Site::bdd::get_journaux($dbh, $r);
	for ( @$journal_code_set ) {if ($reglement_journal =~ $_->{libelle_journal}) {$journal = $_->{code_journal};}}  

	if ((defined $args->{date_ecriture}) && $args->{date_ecriture} =~ /^(?<year>[0-9]{4}).*(?<month>[0-9]{2}).*(?<day>[0-9]{2})$/) {
	$month= substr($args->{date_ecriture},5,2);
    $year= substr($args->{date_ecriture},0,4);		
	} elsif (( defined $args->{date_ecriture}) && $args->{date_ecriture} =~ /^(?<day>[0-9]{2}).*(?<month>[0-9]{2}).*(?<year>[0-9]{4})$/) {
	$month= substr($args->{date_ecriture},3,2);
    $year= substr($args->{date_ecriture},6,4);	
	}
	
    my $item_num = 1;
    
	#on regarde s'il existe des factures enregistrées pour le mois et l'année de la date d'enregistrement
	$sql = '
	SELECT id_facture as item_number, extract(month from ?::date) as month_number, extract(year from ?::date) as year_number
	FROM tbljournal
	WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ? AND substring(id_facture from 8 for 2) = ?
	ORDER BY 1 DESC LIMIT 1
	' ;
	
	@bind_array = ( $args->{date_ecriture}, $args->{date_ecriture}, $journal, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $reglement_journal, $month ) ;
	my $calcul_piece = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;     
  
	for ( @$calcul_piece ) {
	if (substr( $_->{item_number}, 10, 2 ) =~ /\d/ && substr( $_->{item_number}, 0, 2 ) =~ /$journal/) {
	$item_num = int(substr( $_->{item_number}, 10, 2 )) + 1	;} 
	} 

	if ($item_num<10) {	$item_num="0".$item_num; }

	my $numero_piece = $journal . $year . '-' . $month . '_' . $item_num ;
    
    # Mettre à jour directement la valeur du champ en JavaScript
    $content = "
        var field = document.getElementById('calcul_piece_" . $args->{numero_id} . "');
        var numeroPieceInitial = '" . $numero_piece . "'; // Stockez le numéro de pièce initial
        field.value = numeroPieceInitial;
        // Stockez la valeur dans une variable globale
		window.numeroPieceInitial = numeroPieceInitial;
    ";
	
    return $numero_piece ;
    
} #sub calculer_num_piece 

#sélectionne le compte de charge en contrepartie du compte fournisseur 401
sub select_contrepartie {

    my ($r, $args) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content  ) ;

	$sql = 'SELECT numero_compte, libelle_compte, default_id_tva, contrepartie FROM tblcompte WHERE numero_compte = ? AND id_client = ? AND fiscal_year = ? ORDER by numero_compte' ;
    
    my $compte_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $args->{select_contrepartie}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	my $contrepartie_select = $compte_set->[0]->{contrepartie};
	
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'entry_helper.pm => Variable : '.$args->{select_contrepartie}.' et : '.$contrepartie_select.'');
	
    # Mettre à jour directement la valeur du champ en JavaScript
    $content = "
        var field = document.getElementById('" . $args->{numero_id} . "');
        field.value = '" . $contrepartie_select . "';
    ";
    
    if (@$compte_set && $compte_set->[0]->{contrepartie} ne '') {
        my $contrepartie_select = $compte_set->[0]->{contrepartie};

        # Mettre à jour directement la valeur du champ en JavaScript
        $content = "
            var field = document.getElementById('" . $args->{numero_id} . "');
            field.value = '" . $contrepartie_select . "';
        ";
    } else {
        # Aucun compte de contrepartie trouvé ou contrepartie est vide, ne pas appliquer de JavaScript
        $content = "";
    }
    
    return $content ;
    
} #sub select_contrepartie

#renseigne la datalist pour l'input name_libre
sub name_libre_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT id_paiement FROM tbljournal WHERE id_paiement is not NULL and id_client = ? AND fiscal_year = ? GROUP BY id_paiement ORDER BY id_paiement' ;

    my $option_list = '' ;
    
    #éviter de prendre *tous* les enregistrements quand $args->{name_libre_datalist} est vide
    if ( $args->{name_libre_datalist} ) {
	
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";librelist_' . $args->{id_line} . '.appendChild(option);' ;

	} #    for ( @$recordset ) 

    } #    if ( $args->{name_libre_datalist} ) 

    #fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("librelist_' . $args->{id_line} . '");' ;
    
    $content .= $option_list ;

    return $content ;

} #sub name_libre_datalist 

#renseigne la datalist pour l'input search_journal_datalist
sub search_journal_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT libelle_journal FROM tbljournal WHERE libelle_journal is not NULL and id_client = ? AND fiscal_year = ? GROUP BY libelle_journal ORDER BY libelle_journal' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";journallist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("journallist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_journal_datalist 

#renseigne la datalist pour l'input search_cat_doc_datalist
sub search_cat_doc_datalist {

    my ( $r, $args ) = @_;
    my $content = '' ;
    my $dbh = $r->pnotes('dbh') ;
    my $recordset = Base::Site::bdd::get_categorie_document($dbh, $r);
    my $option_list = '' ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->{libelle_cat_doc} . '";option.label = "' . $_->{libelle_cat_doc} . '";catdoclist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("catdoclist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_cat_doc_datalist 

#renseigne la datalist pour l'input search_tag_datalist
sub search_tag_datalist {

    my ( $r, $args ) = @_;
    my $content = '' ;
    my $dbh = $r->pnotes('dbh') ;
    my $recordset = Base::Site::bdd::get_tags_documents($dbh, $r);
    my $option_list = '' ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->{tags_nom} . '";option.label = "' . $_->{tags_nom} . '";taglist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("taglist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_tag_datalist 


#renseigne la datalist pour l'input search_libre_datalist
sub search_libre_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT id_paiement FROM tbljournal WHERE id_paiement is not NULL and id_client = ? AND fiscal_year = ? GROUP BY id_paiement ORDER BY id_paiement' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";librelist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("librelist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_libre_datalist 

#renseigne la datalist pour l'input search_compte_datalist
sub search_compte_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT numero_compte FROM tbljournal WHERE numero_compte is not NULL and id_client = ? AND fiscal_year = ? GROUP BY numero_compte ORDER BY numero_compte' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";comptelist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("comptelist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_compte_datalist 

#renseigne la datalist pour l'input search_piece_datalist
sub search_piece_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT id_facture FROM tbljournal WHERE id_facture is not NULL and id_client = ? AND fiscal_year = ? GROUP BY id_facture ORDER BY id_facture' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";piecelist_' . $args->{id_nb} . '.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("piecelist_' . $args->{id_nb} . '");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_piece_datalist 

#renseigne la datalist pour l'input search_libelle_datalist
sub search_libelle_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT libelle FROM tbljournal WHERE libelle is not NULL and id_client = ? AND fiscal_year = ? GROUP BY libelle ORDER BY libelle' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";libellelist_' . $args->{id_nb} . '.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("libellelist_' . $args->{id_nb} . '");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_libelle_datalist 

#renseigne la datalist pour l'input search_libfrais_datalist
sub search_libfrais_datalist {

    my ( $r, $args ) = @_;
    my $content = '' ;
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT frais_libelle, frais_quantite FROM tblndf_detail WHERE frais_libelle is not NULL and id_client = ? GROUP BY frais_libelle, frais_quantite ORDER BY frais_libelle' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.text="'.$_->[1].'Km";libfrais_' . $args->{id_nb} . '.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("libfrais_' . $args->{id_nb} . '");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_libfrais_datalist 


#renseigne la datalist pour l'input search_lettrage_datalist
sub search_lettrage_datalist {

    my ( $r, $args ) = @_;

    my $content = '' ;
    
    my $dbh = $r->pnotes('dbh') ;
	
    my $sql = 'SELECT lettrage FROM tbljournal WHERE lettrage is not NULL and id_client = ? AND fiscal_year = ? GROUP BY lettrage ORDER BY lettrage' ;

    my $option_list = '' ;
    
	my $recordset = $dbh->selectall_arrayref( $sql, { }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

	for ( @$recordset ) {

	    #Create a new <option> element.
	    $option_list .= 'var option=document.createElement(\'option\');option.value="' . $_->[0] . '";option.label = "' . $_->[0] . '";lettragelist.appendChild(option);' ;

	} #    for ( @$recordset ) 
	
	#fonction de nettoyage de datalist_compte 
    $content .= 'clearChildren("lettragelist");' ;
	
    $content .= $option_list ;

    return $content ;

} #sub search_lettrage_datalist 

#convertir un chiffre en toute lettre convert_chiffre_texte
sub convert_chiffre_texte {
#utilise convert_chiffre_texte dans entry.js

    my ($r, $args) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content  ) ;

	my $letter = Base::Site::util::number_to_fr($args->{convert_chiffre_texte}, '€');
	my $somme = sprintf( "%.2f", $args->{convert_chiffre_texte} ) ;
	my $vartextarea = $args->{textarea} || '';
	
	# Vérifier si la valeur entre parenthèses est présente et la remplacer
	$vartextarea =~ s/\(([^)]+)\)/\($letter\)/g;
	
	# Vérifier si la somme en chiffre est présente et la remplacer
    #$vartextarea =~ s/\b(\d+\.\d+)\b/\($somme\)/g;
    # Vérifier si la somme en chiffre est présente et la remplacer
	#$vartextarea =~ s/\b(\d+\.\d+)\b/$somme/g;
    
    #Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'entry_helper.pm => Variable : '.$args->{convert_chiffre_texte}.' et : '.$letter.' et '.$vartextarea.'');
	
	# Mettre à jour directement la valeur du champ en JavaScript
    $content = '
    var field = document.getElementById("textareamilieu");
    field.value = "'. $vartextarea . '"; 
    ';

    return $content ;
    
} #sub convert_chiffre_texte 

1 ;
