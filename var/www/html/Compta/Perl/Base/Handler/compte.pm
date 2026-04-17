package Base::Handler::compte ;
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
#	Vincent Veyron - Aôut 2016 (https://compta.libremen.com/)
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
use PDF::API2;         	# Manipulation de fichiers PDF
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
    
    if ( defined $args{numero_compte} ) {

	#rapprochement bancaire pour les comptes de classe 5
	if ( defined $args{rapprochement} ) {
	    
	    $content = rapprochement( $r, \%args ) ;
	    
	} else {

	    $content = visiter_un_compte( $r, \%args ) ; 

	}
	
    } elsif ( defined $args{configuration} || defined $args{reconduire}) {
	
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {
		#éditer la liste des comptes
		$content = edit_compte_set( $r, \%args ) ;
		} else {
		$content = liste_des_comptes( $r, \%args ) ;
		}
	
    } elsif ( defined $args{reports} && $args{reports} ne '') {
	
		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	

			if ( $args{reports} eq '0' ) {
				$content = reports( $r, \%args ) ; 
			} else {
				reports( $r, \%args ) ;
				#rediriger l'utilisateur vers le formulaire de saisie d'une entrée pour validation
				my $location = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=A%20NOUVEAUX&id_entry=0&redo=0&_token_id=' . $args{_token_id} ;
				$r->headers_out->set(Location => $location) ;
				return Apache2::Const::REDIRECT ;
			}
		
		} else {
			$content = liste_des_comptes( $r, \%args ) ;
		}

    } elsif ( defined $args{cloture} && $args{cloture} ne '') {

		if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
			
			#première demande de cloture des comptes
			if ( $args{cloture} eq '0') {
				$content = cloture( $r, \%args ) ; 
			} else {
				#l'utilisateur a confirmé la demande de cloture
				#on génère les écritures de solde des comptes et de calcul du résultat
				#que l'on place dans journal_staging
				cloture( $r, \%args ) ;
				#rediriger l'utilisateur vers le formulaire de saisie d'une entrée pour validation
				my $location = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=CLOTURE&id_entry=0&redo=0&_token_id=' . $args{_token_id} ;
				$r->headers_out->set(Location => $location) ;
				return Apache2::Const::REDIRECT ;
			}
		
		} else {
			$content = liste_des_comptes( $r, \%args ) ;
		}
	
    } elsif ( defined $args{balance} ) {

		#l'utilisateur a cliqué sur le lien de téléchargement de la balance
		#le rediriger vers le fichier généré par sub balance
		if ( defined $args{download} ) {
			my $location = balance( $r, \%args ) ;
			#si un message d'erreur est renvoyé par sub balance, il contient class=warning
			if ( $location =~ /warning/ ) {
				$content .= $location ;
			} else {
				#adresse du fichier précédemment généré
				$r->headers_out->set(Location => $location) ;
				#rediriger le navigateur vers le fichier
				$r->status(Apache2::Const::REDIRECT) ;
				return Apache2::Const::REDIRECT ;
			} #	    if ( $location =~ /warning/ )

		} else {
			#afficher la balance
			$content = balance( $r, \%args ) ; 
		} #	if ( defined $args{download} ) 

    } elsif ( defined $args{grandlivre} ) {
	    #afficher le grandlivre
	    $content = grandlivre( $r, \%args ) ; 
   } else {
		$content = liste_des_comptes( $r, \%args ) ;
   }
    
    $r->no_cache(1) ;
    $r->content_type('text/html; charset=utf-8') ;
    print $content ;
    return Apache2::Const::OK ;
}

sub historique_du_compte {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $content, $sql, $fiscal_year, $entry_list ) = ( '', '', 0, '' ) ;

    $entry_list = '' ;
    
    #appliquer le filtre => ecriture de clôture
	my $display_ecriture_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? '' : 'AND libelle_journal NOT LIKE \'%CLOTURE%\'' ;

    if ( defined $args->{historique} ) {

	my $title = ( $args->{historique} eq 'detail' ) ? 'Historique détaillé' : 'Historique résumé' ;
	
	$entry_list .= '<li style="list-style: none; margin: 0;"><h2>' . $title . '</h2></li>';

	$sql = 'with t1 as (
SELECT id_client, fiscal_year, numero_compte, id_entry, id_line, date_ecriture, libelle_journal, coalesce(id_facture, \'&nbsp;\') as id_facture, coalesce(id_paiement, \'&nbsp;\') as id_paiement, coalesce(libelle, \'&nbsp;\') as libelle, debit/100::numeric as debit, credit/100::numeric as credit, lettrage, pointage
FROM tbljournal
WHERE id_client = ? and fiscal_year <> ? AND numero_compte = ? '.$display_ecriture_cloture.'
) 
SELECT t1.fiscal_year, t1.numero_compte, regexp_replace(t2.libelle_compte, \'\\s\', \'&nbsp;\', \'g\') as libelle_compte, id_entry, id_line, date_ecriture, libelle_journal, coalesce(id_facture, \'&nbsp;\') as id_facture, coalesce(id_paiement, \'&nbsp;\') as id_paiement, coalesce(libelle, \'&nbsp;\') as libelle, to_char(debit, \'999G999G999G990D00\') as debit, to_char(credit, \'999G999G999G990D00\') as credit, lettrage, pointage, to_char(sum(debit) over (PARTITION BY fiscal_year), \'999G999G999G990D00\') as total_debit, to_char(sum(credit) over (PARTITION BY fiscal_year), \'999G999G999G990D00\') as total_credit, to_char(sum(credit-debit) over (PARTITION BY fiscal_year ORDER BY date_ecriture, id_line), \'999G999G999G990D00\') as solde
FROM t1 INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
ORDER BY fiscal_year DESC, date_ecriture, id_line
     ' ;  	
	
	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{numero_compte} ) ;

	my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

	my ( $total_credit, $total_debit, $total_solde ) = ( '0,00', '0,00', '0,00' ) ;
	
	for ( @$result_set ) {

	    if ( $_->{fiscal_year} != $fiscal_year ) {
		
		#pas de recap avant d'avoir parcouru le premier exercice
		unless ( $fiscal_year eq '0' ) {
			
		$entry_list .=  '
		<li class=listitem3><hr></li>
		<li class=lineflex1><div class=spacer></div>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;">&nbsp;</span>
		<span class=displayspan style="width: 12%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 28.5%; text-align: right;">Total</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_debit . '</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_credit . '</span>
		<span class=displayspan style="width: 7.4%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_solde . '</span>
		<div class=spacer></div>
		</li>' ;

		} #	    unless ( $fiscal_year eq '0' ) 

		$fiscal_year = $_->{fiscal_year} ;

		#pour les exercices décalés, afficher l'année de début et celle de fin
		my $complement = ( $r->pnotes('session')->{fiscal_year_offset} eq '0' ) ? '' : '-' . ( $fiscal_year + 1 ) ;
		
		#en-têtes du compte : on affiche l'exercice considéré
		$entry_list .= '<li style="list-style: none; margin: 0;"><h3>Exercice '. $_->{fiscal_year} . $complement . '</h3></li>' ;
	
	#on affiche les titres pour l'historique détaillé seulement
	$entry_list .= '
	<li class=lineflex1><div class=spacer></div>
	<span class=headerspan style="width: 9%;">Date</span>
	<span class=headerspan style="width: 9%;">Journal</span>
	<span class=headerspan style="width: 7%;">Libre</span>
	<span class=headerspan style="width: 12%;">Pièce</span>
	<span class=headerspan style="width: 28.5%;">Libellé</span>
	<span class=headerspan style="width: 9%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 9%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 7.4%; text-align: left;">&nbsp;</span>
	<span class=headerspan style="width: 9%; text-align: right;">Solde</span>
	<div class=spacer></div>
	</li>' if ( $args->{historique} eq 'detail' ) ;

	    } #	    if ( $_->{fiscal_year} != $fiscal_year )
	    
	    #on affiche les lignes d'écritures pour l'historique détaillé seulement
	    $entry_list .= '
		<li class=listitem3>
		<div class=spacer></div>
		<span class=blockspan style="width: 9%;">' . $_->{date_ecriture} . '</span>
		<span class=blockspan style="width: 9%;">' . $_->{libelle_journal} . '</span>
		<span class=blockspan style="width: 7%;">' . $_->{id_paiement} . '</span>
		<span class=blockspan style="width: 12%;">' . $_->{id_facture} . '</span>
		<span class=blockspan style="width: 28.5%;">' . $_->{libelle} . '</span>
		<span class=blockspan style="width: 9%; text-align: right;">' . $_->{debit} . '</span>
		<span class=blockspan style="width: 9%; text-align: right;">' . $_->{credit} . '</span>
		<span class=blockspan style="width: 7.4%;">&nbsp;</span>
		<span class=blockspan style="width: 9%; text-align: right;">' . $_->{solde} . '</span>
		<div class=spacer></div>
		</li>' if ( $args->{historique} eq 'detail' ) ;

	    #les totaux sont repris en début de boucle, juste avant de commencer le compte suivant
	    $total_debit = $_->{total_debit} ;
	    $total_credit = $_->{total_credit} ;
	    $total_solde = $_->{solde} ;
	    
	} #    for ( @$result_set ) 
		
		#recap du dernier compte de la liste, qui n'est pas dans la boucle
		$entry_list .=  '
		<li class=listitem3><hr></li>
		<li class=lineflex1><div class=spacer></div>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;">&nbsp;</span>
		<span class=displayspan style="width: 12%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 28.5%; text-align: right;">Total</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_debit . '</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_credit . '</span>
		<span class=blockspan style="width: 7.4%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_solde . '</span>
		<div class=spacer></div>
		</li>' ;

	$content .= '<div class="wrapper-docs"><ul>' . $entry_list . '</ul></div>' ;

    } #    if ( defined $args->{historique} ) 
    
    return $content ;

} #sub historique_du_compte

sub reports {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content, $en_attente_count ) ;
	
	################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args ) ;
	################ Affichage MENU ################
	
    if ( $args->{reports} eq '0' ) {
		
	#
	$sql = q [
	with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? GROUP BY id_entry)
	SELECT count(id_entry) FROM t1
	] ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} -1 ) ;
	
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	if ($en_attente_count eq '0') {
	
		$content .= Base::Site::util::generate_error_message('Attention : il n\'existe aucune écriture pour l\'exercice précédent.<br>
		Le report ne peut pas être effectuée') ;	
		
		return $content ;
		
	} else {		

	my $message2 = 'Voulez-vous reprendre les soldes de l\'exercice précédent ?' ;
	my $message3 = '
		<div class=wrapper-forms>
		<fieldset class="pretty-box"><legend><h3>Options</h3></legend>
		<label style="width : 70%;" class="forms" for="reconduirejournaux">Reconduire automatiquement les journaux depuis l\'exercice précédent ?</label>
		<input type="checkbox" style ="width : 20%;" id="reconduirejournaux" name="reconduirejournaux" value=1 checked>
		<br>
		<label style="width : 70%;" class="forms" for="reconduirecomptes">Reconduire automatiquement les comptes depuis l\'exercice précédent ?</label>
		<input type="checkbox" style ="width : 20%;" id="reconduirecomptes" name="reconduirecomptes" value=1 checked>
		</fieldset>
		</div>
		<input type=hidden name="reports" value=1>
	' ;
	my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'reports', '', $message3, 1);
	$content .= Base::Site::util::generate_error_message($confirmation_message);
	return $content ;
	}

    } else {
		
	my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);

	$args->{_token_id} = $token_id ;	

	my $ecriture_debut_exercice = 'A.N. au '.$r->pnotes('session')->{Exercice_debut_DMY};
    
    # supprimer d'abord les données éventuellement présentes dans tbljournal_staging pour cet utilisateur	
	Base::Site::bdd::clean_tbljournal_staging( $r );
	
	#reconduction des journaux
	if (defined $args->{reconduirejournaux} && $args->{reconduirejournaux} eq 1){
	$sql = '
	INSERT INTO tbljournal_liste (libelle_journal, id_client, fiscal_year, code_journal, type_journal) 
	SELECT libelle_journal, ?, ? , code_journal, type_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ?
	ON CONFLICT (id_client, fiscal_year, libelle_journal) DO NOTHING' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Reconduction des journaux pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');
	}
	
	#création du journal A NOUVEAUX pour les écritures d A NOUVEAUX
	my $var_lib_journal = 'A NOUVEAUX';
	my $var_code_journal = 'AN';
	my $var_type_journal = 'A-nouveaux';
	my $sql = 'INSERT INTO tbljournal_liste (id_client, fiscal_year, libelle_journal, code_journal, type_journal) VALUES (?, ?, ?, ?, ?)
	ON CONFLICT (id_client, fiscal_year, libelle_journal) DO NOTHING' ;
	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $var_lib_journal, $var_code_journal, $var_type_journal ) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	
	#reconduction des comptes
	if (defined $args->{reconduirecomptes} && $args->{reconduirecomptes} eq 1){
	$sql = '
	INSERT INTO tblcompte (numero_compte, libelle_compte, default_id_tva, contrepartie, id_client, fiscal_year) 
	SELECT numero_compte, libelle_compte, default_id_tva, contrepartie, ?, ? FROM tblcompte WHERE id_client = ? AND fiscal_year = ?
	ON CONFLICT (id_client, fiscal_year, numero_compte) DO NOTHING' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Reconduction des comptes pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');
	}
	

	#création des comptes 110 et 119 s'ils n'existent pas
	my $var_compte_110 = '110000';
	my $var_compte_119 = '119000';
	my $var_comptelib_110 = 'Report à nouveau - solde créditeur';
	my $var_comptelib_119 = 'Report à nouveau - solde débiteur';

	$sql = '
	INSERT INTO tblcompte (numero_compte, libelle_compte, id_client, fiscal_year)  VALUES (?, ?, ?, ?)
	ON CONFLICT (id_client, fiscal_year, numero_compte) DO NOTHING' ;
	@bind_array = ( $var_compte_110, $var_comptelib_110, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	
	@bind_array = ( $var_compte_119, $var_comptelib_119, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;

	$sql = q {
with t1 as (
SELECT numero_compte, libelle_compte, sum(credit - debit) as solde 
FROM tbljournal INNER JOIN tblcompte using (id_client, fiscal_year, numero_compte ) 
WHERE id_client = ? and fiscal_year = ? AND substring(numero_compte from 1 for 1)::integer in (1, 2, 3, 4, 5)
GROUP BY numero_compte, libelle_compte HAVING sum(debit - credit) != 0
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, debit, credit, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, ?, ?, numero_compte, 'A NOUVEAUX', -least(0, solde), greatest(0, solde), ?
FROM t1
} ;
	
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1,
			   $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset},
			   $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD},
			   $r->pnotes('session')->{id_client}, $r->pnotes('session')->{Exercice_debut_YMD}, $ecriture_debut_exercice, $args->{_token_id}
	    ) ;

	$dbh->do( $sql, undef, @bind_array ) ;
	
	return ;
	    
    } #    if ( $args->{reports} eq '0' ) 

} #sub reports 

sub cloture {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content, $en_attente_count ) ;
    
    ################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args ) ;
	################ Affichage MENU ################
	
	$sql = q [
	with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? GROUP BY id_entry)
	SELECT count(id_entry) FROM t1
	] ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	if ($en_attente_count eq '0') {
	
		$content .= Base::Site::util::generate_error_message('Attention : il n\'existe aucune écriture pour l\'exercice en cours.<br>
		La cloture ne peut pas être effectuée') ;	
		
		return $content ;
		
	} elsif ( $args->{cloture} eq '0' || $args->{cloture} eq '') {

		my $message2 = 'Cette action solde les comptes de classe 6 et 7 et calcule le résultat de l\'exercice.
		<br>Elle est réversible par suppression de l\'écriture insérée dans le journal des OD.
		<br><br>Voulez-vous vraiment clôturer les comptes ?' ;
		my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'cloture', '', '', 1);
		$content .= Base::Site::util::generate_error_message($confirmation_message);

		return $content ;

    } else {
  
	#création du journal Clôture pour les écritures de Clôture
	my $var_lib_journal = 'CLOTURE';
	my $var_code_journal = 'CL';
	my $var_type_journal = 'Clôture';
	my $sql = 'INSERT INTO tbljournal_liste (id_client, fiscal_year, libelle_journal, code_journal, type_journal) VALUES (?, ?, ?, ?, ?)
	ON CONFLICT (id_client, fiscal_year, libelle_journal) DO NOTHING' ;
	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $var_lib_journal, $var_code_journal, $var_type_journal ) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	
	#création des comptes 120 et 129 s'ils n'existent pas
	my $var_compte_120 = '120000';
	my $var_compte_129 = '129000';
	my $var_comptelib_120 = 'Résultat de l\'exercice - bénéfice';
	my $var_comptelib_129 = 'Résultat de l\'exercice - perte';

	$sql = '
	INSERT INTO tblcompte (numero_compte, libelle_compte, id_client, fiscal_year)  VALUES (?, ?, ?, ?)
	ON CONFLICT (id_client, fiscal_year, numero_compte) DO NOTHING' ;
	@bind_array = ( $var_compte_120, $var_comptelib_120, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	
	@bind_array = ( $var_compte_129, $var_comptelib_129, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
	eval { $dbh->do( $sql, undef, @bind_array ) } ;
	
    # supprimer d'abord les données éventuellement présentes dans tbljournal_staging pour cet utilisateur	
	Base::Site::bdd::clean_tbljournal_staging( $r );

	my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);

	$args->{_token_id} = $token_id ;
	
	#recherche des soldes des comptes de classe 6 et 7
	$sql = q {
with t1 as (
SELECT numero_compte, sum(debit - credit) as solde 
FROM tbljournal 
WHERE id_client = ? and fiscal_year = ? AND substring(numero_compte from 1 for 1) = '6' 
GROUP BY numero_compte 
HAVING sum(debit - credit) > 0
UNION SELECT numero_compte, sum(credit - debit) as solde 
FROM tbljournal 
WHERE id_client = ? and fiscal_year = ? AND substring(numero_compte from 1 for 1) = '7'  
GROUP BY numero_compte 
HAVING sum(credit - debit) > 0
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, id_facture, debit, credit, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, ((?||'-01-01')::date + '1 year'::interval)::date -1 + ?::integer, 'Clôture', numero_compte, 'CLOTURE', 'N/A', case when substring(numero_compte from 1 for 1) = '6' then 0 else solde end, case when substring(numero_compte from 1 for 1) = '6' then solde else 0 end, ?
from t1
} ;

	@bind_array = ( 
	    $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, 
	    $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},
	    $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset},
	    $args->{_token_id}
) ;

	$dbh->do( $sql, undef, @bind_array ) ;
	
	
	#########################################	
	#Vérification des comptes 120 et 129	#
	#########################################
	$sql = 'SELECT sum(debit - credit) as resultat , (select numero_compte from tblcompte where id_client = 1 and fiscal_year = ? and substring(numero_compte from 1 for 3) = \'129\' )FROM tbljournal_staging WHERE _token_id = ?';
	my $calcul_resultat = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{fiscal_year}, $args->{_token_id} ) ) ;
	my $calcul_resultat_compte = 120;
		
	if (defined $calcul_resultat->[0]->{numero_compte}) {
	if ((defined $calcul_resultat->[0]->{resultat} && $calcul_resultat->[0]->{resultat} < 0) && (defined $calcul_resultat->[0]->{numero_compte} && $calcul_resultat->[0]->{numero_compte} =~ /129/) ) {
		$calcul_resultat_compte = 129;
	} } 
		

	#les soldes sont calculés et placés dans tbljournal_staging
	#calculer le résultat et l'insérer au débit/crédit de 120 si 129 existe pas ou bien au débit de 129 s'il existe
	$sql = q {
with t1 as (
SELECT sum(debit - credit) as resultat FROM tbljournal_staging WHERE _token_id = ?
)
INSERT INTO tbljournal_staging (_session_id, id_entry, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, id_client, date_ecriture, libelle, numero_compte, libelle_journal, id_facture, debit, credit, _token_id)
SELECT ?, 0, ?, ?, ?, ?, ?, ((?||'-01-01')::date + '1 year'::interval)::date -1 + ?::integer, 'Clôture', (select numero_compte from tblcompte where id_client = ? and fiscal_year = ? and substring(numero_compte from 1 for 3) = ?), 'CLOTURE', 'N/A', -least(0, resultat), greatest(0, resultat), ?
from t1
} ;

	@bind_array = ( $args->{_token_id}, $r->pnotes('session')->{_session_id}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $calcul_resultat_compte, $args->{_token_id} ) ;
	    
	$dbh->do( $sql, undef, @bind_array ) ;
	
	Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Clôture des comptes pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');

	return ;

    }
    	    
} #sub cloture 

sub rapprochement {

    my ( $r, $args ) = @_ ;
    $args->{leur_solde} ||= 0 ;
    my $dbh = $r->pnotes('dbh') ;

    ( my $return_href = $r->unparsed_uri() ) =~ s/&rapprochement=0(.*)// ;

    my $content = '<table><tr><td><h2>Rapprochement</h2></td><td><a class=linav href="' . $return_href .'" >Retour</a></td></tr></table>' ;

    my $sql ;
    
    #on veut les deux paramètres de la requête
    unless ( $args->{date_rapprochement} ) {

	my $date_rapprochement_input = '<tr><th style="text-align: right;">Date du rapprochement</th><td><input name=date_rapprochement onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')"></td></tr>';

	my $solde_input = '<tr><th style="text-align: right;">Solde du compte</th><td><input name=leur_solde></td></tr>' ;

	$content .= '<form action="' . $r->uri() . '"><p>
	<input type=hidden name=numero_compte value="' . ($args->{numero_compte} || '') . '">
	<input type=hidden name=libelle_compte value="' . ($args->{libelle_compte} || '')  . '">
	<input type=hidden name="racine" id="racine" value="' . $r->pnotes('session')->{racine} . '">
	<input type=hidden name=rapprochement value=0></p><table>' . $date_rapprochement_input . $solde_input . '</table><p class=submit><input type=submit value=Valider></p></form>' ;

      	return $content ;
	
    } #    unless ( $args->{date_rapprochement} )

    #En-tête
    $content .= '<h2>Compte ' . $args->{numero_compte} . ' - État de rapprochement au ' . $args->{date_rapprochement} . '</h2>' ;
    
    #on fait faire le travail de conversion des inputs/outputs localisés par postgresql via to_number 
    $sql = 'SELECT to_number(?, \'999999999999D99\') as leur_solde_numeric' ;    

    my @bind_array = ( $args->{leur_solde} ) ;

    my $leur_solde_set ;

    eval { $leur_solde_set = $dbh->selectall_arrayref( $sql, { Slice => { } } , @bind_array ) } ;

    if ( $@ ) {
	
	if ( $@ =~ / numeric / ) {

	    $content .= '<h3 class=warning>Solde non valide : ' . $args->{leur_solde} . '</h3>' ;

	    return $content ;

	} else {

	    $content .= '<h3 class=warning>' . $@ . '</h3>' ;

	    return $content ;
	    
	} #	if ( $@ =~ / numeric / ) 

    } #    if ( $@ ) 

    #on affiche $args->{leur_solde} tel qu'on l'a reçu
    my $not_in_their_book = '<li class=listitem3>
<div class=container><div class=spacer></div>
<strong>
<span class=headerspan style="width: 62ch;">Leur solde</span>
<span class=headerspan style="width: 15ch; text-align: right;">&nbsp;</span>
<span class=headerspan style="width: 15ch; text-align: right;">' . $args->{leur_solde} . '</span>
</strong>
<div class=spacer></div></div></li>
' ;

    $not_in_their_book .= '<li class=listitem3><hr></li><li class=listitem3>
<div class=container><div class=spacer></div>
<strong>
<span class=blockspan style="width: 100%;">À passer par eux :</span>
</strong>
<div class=spacer></div></div></li>
' ;

    #ligne d'en-têtes
    $not_in_their_book .= '<li class=listitem3>
<div class=container><div class=spacer></div>
<i>
<span class=blockspan style="width: 12ch;">Date</span>
<span class=blockspan style="width: 15ch;">Paiement</span>
<span class=blockspan style="width: 35ch;">Libellé</span>
<span class=blockspan style="width: 15ch; text-align: right;">Débit</span>
<span class=blockspan style="width: 15ch; text-align: right;">Crédit</span>
</i>
<div class=spacer></div></div></li>
' ;

    #liste des écritures non pointées
    #on réutilise total_debit et total_credit dans les calculs. Pour éviter une reconversion hasardeuse,
    #on calcule deux versions : numerique et formatée. la version formatée est affichée dans la page web
    $sql = '
SELECT t1.id_line, date_ecriture, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.libelle, \'&nbsp;\') as libelle, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit, to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, (sum(t1.debit) over())/100::numeric as total_debit, (sum(t1.credit) over())/100::numeric as total_credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit_formatted, to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit_formatted
FROM tbljournal t1 
WHERE t1.id_client = ? and t1.fiscal_year = ? and t1.numero_compte = ? and date_ecriture <= ? and pointage = false ORDER BY date_ecriture
' ;

    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{numero_compte}, $args->{date_rapprochement} ) ;

    my $unchecked_set ;
    
    eval { $unchecked_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	    
    if ( $@ ) {
	
	if ( $@ =~ / date / ) {

	    $content .= '<h3 class=warning>Date non valide : ' . $args->{date_rapprochement} . '</h3>' ;

	    return $content ;
	    
	} else {

	    $content .= '<h3 class=warning>' . $@ . '</h3>' ;

	    return $content ;
	    
	} #	if ( $@ =~ / date / )

    } #    if ( $@ ) 

    for ( @$unchecked_set ) {
	#
	#Attention! les colonnes débit et crédit sont inversées
	#on liste les écritures qu'ils n'ont pas passées, en inversant les colonnes
	#
	$not_in_their_book .= '<li class=listitem3>
<div class=container><div class=spacer></div>
<span class=blockspan style="width: 12ch;">' . $_->{date_ecriture} . '</span>
<span class=blockspan style="width: 15ch;">' . $_->{id_paiement} . '</span>
<span class=blockspan style="width: 35ch;">' . $_->{libelle} . '</span>
<span class=blockspan style="width: 15ch; text-align: right;">' . $_->{credit} . '</span>
<span class=blockspan style="width: 15ch; text-align: right;">' . $_->{debit} . '</span>
<div class=spacer></div></div></li>' ;

    } #	for ( @$result_set ) 

   $sql = '
SELECT to_char(?::numeric, \'999G999G999G990D00\') as total_debit, to_char(?::numeric, \'999G999G999G990D00\') as total_credit
	';

    my $total_set ;

    @bind_array = ( $unchecked_set->[0]->{total_debit}, $unchecked_set->[0]->{total_credit} ) ;

    eval { $total_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
    
    if ( $@ ) {
	
	$content .= '<h3 class=warning>' . $@ . '</h3>' ;

	return $content ;
	
    } #    if ( $@ ) 

    #ligne de total des écritures à passer par eux
    $not_in_their_book .= '<li class=listitem3>
<div class=container><div class=spacer></div>
<strong>
<span class=blockspan style="width: 12ch;">&nbsp;</span>
<span class=blockspan style="width: 15ch;">&nbsp;</span>
<span class=blockspan style="width: 35ch; text-align: right;">Total</span>
<span class=blockspan style="width: 15ch; text-align: right;">' . $unchecked_set->[0]->{total_credit_formatted} . '</span>
<span class=blockspan style="width: 15ch; text-align: right;">' . $unchecked_set->[0]->{total_debit_formatted} . '</span>
</strong>
<div class=spacer></div></div></li>
<li class=listitem3><hr></li>
' ;
    
    #leur solde corrigé
    my $their_corrected_set ;

    #on calcul ici leur solde corrigé des opérations non passées par eux
    $sql = 'SELECT to_char(?::numeric + ?::numeric - ?::numeric, \'999G999G999G990D00\') as their_corrected' ;

    @bind_array = ( $leur_solde_set->[0]->{leur_solde_numeric} , $unchecked_set->[0]->{total_debit} , $unchecked_set->[0]->{total_credit} ) ;

    eval { $their_corrected_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;

    $not_in_their_book .= '<li class=listitem3>
<div class=container><div class=spacer></div>
<strong>
<span class=headerspan style="width: 62ch">Leur solde corrigé</span>
<span class=headerspan style="width: 15ch; text-align: right;">&nbsp;</span>
<span class=headerspan style="width: 15ch; text-align: right;" id="their_corrected">' . $their_corrected_set->[0]->{their_corrected} . '</span>
</strong>
<div class=spacer></div></div></li>' ;
    
    #notre solde; il nous faut inverser l'opération normale crédit - débit, puisque nous comparons avec leur solde
    $sql = 'SELECT to_char(sum(debit - credit)/100::numeric, \'999G999G999G990D00\') as notre_solde
FROM tbljournal t1 
WHERE t1.id_client = ? and t1.fiscal_year = ? and t1.numero_compte = ? and date_ecriture <= ? 
	';
    
    @bind_array =  ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{numero_compte}, $args->{date_rapprochement} ) ;
    
    my $notre_solde_set = $dbh->selectall_arrayref( $sql, { Slice => { } } , @bind_array ) ;
    
    $not_in_their_book .= '<li class=listitem3>
<div class=container><div class=spacer></div>
<strong>
<span class=headerspan style="width: 62ch;">Notre solde</span>
<span class=headerspan style="width: 15ch; text-align: right;">&nbsp;</span>
<span class=headerspan style="width: 15ch; text-align: right;" id="notre_solde">' . $notre_solde_set->[0]->{notre_solde} . '</span>
</strong>
<div class=spacer></div></div></li>' ;
    
    $content .= '<div style="width: 97ch;"><ul>' . $not_in_their_book . '</ul></div>' ;

    #message de résultat
    if ( $notre_solde_set->[0]->{notre_solde} eq $their_corrected_set->[0]->{their_corrected} ) {

	$content .= '<h3 style="text-align: center;">Rapprochement exact</h3>' ;

    } else {

	#Erreur de rapprochement; dans ce cas, afficher en rouge les montants "notre_solde" et "their_corrected"
	$content .= '<h3 class=warning style="text-align: center;">Erreur de rapprochement</h3><script>document.getElementById("notre_solde").style.color = "red";document.getElementById("their_corrected").style.color = "red";</script>' ;
	
    }

    return $content ;

} #sub rapprochement

sub edit_compte_set {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array ) ;
    my $content = '' ;
    my $line = "1"; 
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
    	
    ################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args, 1 ) ;
	################ Affichage MENU ################
	
	#Requête compta_client sur les informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);

	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    if ( defined $args->{configuration} && defined $args->{supprimer} && $args->{supprimer} eq '0' ) {
		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;supprimer=1&amp;delete_numero=' . $args->{delete_numero}.'&amp;classe=' . ($args->{classe} || '') ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le compte &quot;' . $args->{delete_numero} . '&quot;?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
	} elsif ( defined $args->{configuration} && defined $args->{supprimer} && $args->{supprimer} eq '1' ) {
		$sql = 'DELETE FROM tblcompte WHERE id_client = ? and fiscal_year = ? and numero_compte = ?' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{delete_numero} ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /tbljournal_id_client_fiscal_year_numero_compte_fkey/ ) {
			$content .= Base::Site::util::generate_error_message('Le compte n\'est pas vide : suppression impossible') ;
			} else {
			$content .= Base::Site::util::generate_error_message('' . $@ . '') ;
			}
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Suppression du compte '.$args->{delete_numero}.' ');
		}

	}
    
    #attention aux débuts d'exercice décalés
    #pour l'affichage, l'exercice mentionné est "année N - année N+1"
    my $exercice_a_reconduire ;
    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
	$exercice_a_reconduire = ( $r->pnotes('session')->{fiscal_year} - 1 ) . '-' .  $r->pnotes('session')->{fiscal_year}
    } else {
	$exercice_a_reconduire = $r->pnotes('session')->{fiscal_year} - 1 ;
    }

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Reconduire' 					  #
	#######################################################################
    if ( defined $args->{configuration} && defined $args->{reconduire} && $args->{reconduire} eq '0') {
		#1ère demande de reconduction; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;reconduire=1' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous reconduire les comptes de l\'exercice ' . $exercice_a_reconduire . '?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
	} elsif ( defined $args->{configuration} && defined $args->{reconduire} && $args->{reconduire} eq '1') {
		#reconduire les comptes
		$sql = '
		INSERT INTO tblcompte (numero_compte, libelle_compte, default_id_tva, contrepartie, id_client, fiscal_year) 
		SELECT numero_compte, libelle_compte, default_id_tva, contrepartie, ?, ? FROM tblcompte WHERE id_client = ? AND fiscal_year = ?
		ON CONFLICT (id_client, fiscal_year, numero_compte) DO NOTHING' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			if ( $@ =~ /tblcompte_client_year_numero_compte_pk/ ) {
			$content .= '<h3 class=warning>Des comptes de l\'année précédente existent déjà : reconduction impossible</h3>' ;
			} else {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}
		}
			
		if (not($parametre_set->[0]->{id_tva_regime} eq 'franchise')) {
			#reconduire les formulaires cerfa
			$sql = '
			INSERT INTO tblcerfa (id_item, id_client, fiscal_year, form_number, credit_first, included_compte) 
			SELECT id_item, ?, ?, form_number, credit_first, included_compte FROM tblcerfa WHERE id_client = ? AND fiscal_year = ?
			ON CONFLICT (id_item, id_client, fiscal_year) DO NOTHING' ;

			#on commence par tblcerfa_2
			$sql = '
			INSERT INTO tblcerfa_2 (id_item, id_client, fiscal_year, credit_first) 
			SELECT id_item, ?, ?, credit_first FROM tblcerfa_2 WHERE id_client = ? AND fiscal_year = ?
			ON CONFLICT (id_item, id_client, fiscal_year) DO NOTHING' ;

			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;

			eval { $dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			}  else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Reconduction de la liste de compte pour l\'exercice '.$r->pnotes('session')->{fiscal_year}.'');
			}

			#on continue avec tblcerfa_2_detail
			$sql = '
			with t1 as (
			SELECT id_entry, id_item
				   FROM tblcerfa_2 WHERE id_client = ? AND fiscal_year = ?),
			t2 as (
				   SELECT id_item, numero_compte
					  FROM tblcerfa_2 INNER JOIN tblcerfa_2_detail using (id_entry)
					  WHERE id_client = ? AND fiscal_year = ?)
			insert into tblcerfa_2_detail (id_entry, numero_compte)
			select t1.id_entry, t2.numero_compte from t1 inner join t2 using (id_item);
			' ;

			@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} - 1 ) ;

			eval { $dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {   
			$content .= '<h3 class=warning>' . $@ . '</h3>' ;
			} 
			
		}
			
	} 

	####################################################################### 
	# L'utilisateur a cliqué sur le bouton 'Importer'
	#######################################################################
	if ( defined $args->{configuration} && defined $args->{import} && $args->{import} eq '1' ) {

		# Vérifier si un fichier a été fourni
		unless ( $args->{import_file} ) {			
			$content .= Base::Site::util::generate_error_message('Aucun fichier n\'a été sélectionné pour le téléchargement!');
		} else {
			# Récupérer et traiter le fichier
			my $req = Apache2::Request->new( $r );
			my $upload = $req->upload("import_file") or warn $!;
			my $upload_fh = $upload->fh();

			my $rowCount = 0;
			my $error_count = 0;
			my @errors;
			my $valid_data = 1; # On suppose que les données sont en UTF-8

			# Préparer la requête SQL
			my $sql = '
	INSERT INTO tblcompte (id_client, fiscal_year, numero_compte, libelle_compte, contrepartie, default_id_tva)
	VALUES (?, ?, ?, ?, ?, ?)
	ON CONFLICT (id_client, fiscal_year, numero_compte)
	DO UPDATE SET libelle_compte = EXCLUDED.libelle_compte,
				  default_id_tva = CASE 
									 WHEN EXCLUDED.default_id_tva = 0.00 THEN tblcompte.default_id_tva 
									 ELSE EXCLUDED.default_id_tva 
								   END,
				  contrepartie = EXCLUDED.contrepartie;
	';

			my $sth = $dbh->prepare($sql);

			# Lire le fichier ligne par ligne
			while (my $data = <$upload_fh>) {
				$rowCount++;

				# Ignorer les en-têtes
				next if $data =~ /comptenum|comptelib|contrepartie|default_id_tva/;
				chomp($data);

				# Vérifier l'encodage UTF-8
				eval { $data = Encode::decode( "utf8", $data, Encode::FB_CROAK ) };
				if ($@) {
					push @errors, "Ligne $rowCount : Encodage non UTF-8.";
					$valid_data = 0;
					$error_count++;
					next;
				}

				# Validation et nettoyage des données
				my @fields = split(';', $data);
				foreach (@fields) { s/^\s+|\s+$//g } # Supprimer les espaces blancs

				my ($numero_compte, $libelle_compte, $contrepartie, $default_id_tva) = @fields[0, 1, 2, 3];
				
				# Validation des numéros de compte
				unless ($numero_compte && $numero_compte =~ /^\d{2,}[A-Z0-9]*$/i) {
					push @errors, "Ligne $rowCount : Numéro de compte invalide ($numero_compte). Doit commencer par au moins deux chiffres.";
					$error_count++;
					next;
				}

				# Gérer les valeurs par défaut
				$libelle_compte ||= undef;
				$contrepartie ||= undef;

				# Validation et ajustement du taux de TVA
				if (defined $default_id_tva && $default_id_tva ne '') {
					if ($default_id_tva !~ /^\d+(\.\d{1,2})?$/ || $default_id_tva > 99.99 || $default_id_tva < 0) {
						push @errors, "Ligne $rowCount : Taux de TVA invalide ($default_id_tva). Attendu : entre 0.00 et 99.99.";
						$default_id_tva = 0.00; # Remplacer par défaut
					}
				} else {
					$default_id_tva = 0.00; # Par défaut si absent
				}

				# Exécuter la requête SQL pour insérer ou mettre à jour
				eval {
					$sth->execute(
						$r->pnotes('session')->{id_client},
						$r->pnotes('session')->{fiscal_year},
						$numero_compte,
						$libelle_compte,
						$contrepartie,
						$default_id_tva
					);
				};
				if ($@) {
					push @errors, "Ligne $rowCount : Erreur SQL ($@).";
					$error_count++;
					next;
				}
			}


			# Générer le rapport de l'importation
			my $summary = "<h3>Résultat de l'importation</h3>
	<ul>
		<li class=listitem3><strong>Total de lignes traitées :</strong> $rowCount</li>
		<li class=listitem3><strong>Erreurs :</strong> $error_count</li>
	</ul>";

			if (@errors) {
				$summary .= "<h4>Liste des erreurs</h4><ul>";
				$summary .= "<li class=listitem3>$_</li>" for @errors;
				$summary .= "</ul>";
			}

			$content .= Base::Site::util::generate_error_message($summary);
			
			# Ajouter une entrée dans les logs
			Base::Site::logs::logEntry(
				"#### INFO ####",
				$r->pnotes('session')->{username},
				'compte.pm => Importation des comptes pour l\'exercice ' 
				. $r->pnotes('session')->{fiscal_year} . ''
			);
		}
	}


    ########################################################################################## 
	#l'utilisateur a ajouter																 #
	##########################################################################################
    if ( defined $args->{configuration} && defined $args->{ajouter} && $args->{ajouter} eq '1') {

		$args->{new_numero_compte} ||= undef ;
		$args->{libelle_compte} ||= undef ;
		
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{libelle_compte});
		Base::Site::util::formatter_montant_et_libelle(undef, \$args->{new_numero_compte});
		
		if (!$args->{new_numero_compte}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un numéro de compte') ;
		} elsif (!$args->{libelle_compte}) {
		$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé de compte') ;
		} else {
			
			#nouveau compte
			$sql = 'INSERT INTO tblcompte (numero_compte, libelle_compte, contrepartie, id_client, fiscal_year) VALUES (?, ?, ?, ?, ?)' ;
			@bind_array = ( $args->{new_numero_compte}, $args->{libelle_compte}, ($args->{contrepartie} || undef), $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

			#on vérifie que le numéro de compte commence bien par un chiffre
			if ( substr( $args->{new_numero_compte}, 0, 1 ) =~ /\d/ ) {
				
				eval { $dbh->do( $sql, undef, @bind_array ) } ;

				if ( $@ ) {
					if ( $@ =~ /tblcompte_client_year_numero_compte_pk/ ) {
						my $message = "Ce numéro de compte existe déjà." ;
						$content .= '<h3 class=warning>' . $message . '</h3>' ;
					} else { 
					$content .= '<h3 class=warning>' . $@ . '</h3>' ;
					}
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => Création du compte '.$args->{new_numero_compte}.' - ' .$args->{libelle_compte} .' contrepartie '. ($args->{contrepartie} || '' ).' ');
				}

			} else {
				$content .= '<h3 class=warning>Le numéro de compte doit commencer par un chiffre - Enregistrement impossible</h3>' ;
			}
		
		}
    }
   
    ########################################################################################## 
	#l'utilisateur a modifier un compte; 													 #
	##########################################################################################
    if ( defined $args->{configuration} && defined $args->{modifier} && $args->{modifier} eq '1') {

		#supprime les espaces de début et de fin de ligne
		$args->{libelle_compte} =~ s/^\s+|\s+$//g;
		
		#mise à jour d'un compte existant; les comptes de classe 7 ont une valeur default_id_tva, pour les autres mettre à 0
		$sql = 'UPDATE tblcompte set numero_compte = ?, libelle_compte = ?, default_id_tva = ?, contrepartie = ? WHERE id_client = ? and fiscal_year = ? and numero_compte = ?' ;
		#$args->{libelle_compte} = Encode::encode_utf8($args->{libelle_compte});
		@bind_array = ( $args->{new_numero_compte}, $args->{libelle_compte}, $args->{default_id_tva} || 0, ($args->{contrepartie} || undef), $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{old_numero_compte} ) ;

		#on vérifie que le numéro de compte commence bien par un chiffre
		if ( substr( $args->{new_numero_compte}, 0, 1 ) =~ /\d/ ) {
			eval { $dbh->do( $sql, undef, @bind_array ) } ;

			if ( $@ ) {
				if ( $@ =~ /tblcompte_client_year_numero_compte_pk/ ) {
					my $message = "Ce numéro de compte existe déjà." ;
					$content .= '<h3 class=warning>' . $message . '</h3>' ;
				} else { 
					$content .= '<h3 class=warning>' . $@ . '</h3>' ;
				}
			} 

		} else {
			$content .= '<h3 class=warning>Le numéro de compte doit commencer par un chiffre - Enregistrement impossible</h3>' ;
		}
    }

	my $bdd_filter_classe = ( defined $args->{classe} && $args->{classe} ne '') ? 'AND substring(numero_compte from 1 for 1)  = \''.$args->{classe}.'\'' : '' ;
	my $bdd_filter_classe_end = ( defined $args->{classe} ) ? ')' : '' ;

    #Requête tblcompte
    $sql = 'SELECT numero_compte, libelle_compte, default_id_tva, contrepartie FROM tblcompte WHERE id_client = ? '.$bdd_filter_classe.' AND fiscal_year = ? ORDER by numero_compte' ;
    my $compte_set = $dbh->selectall_arrayref($sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

    my ( $compte_list, $class ) = ( '', '' ) ;

	#select_compte4
	$sql = 'SELECT numero_compte, libelle_compte FROM tblcompte WHERE id_client = ? AND fiscal_year = ? ORDER BY 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $compte_req4 = $dbh->selectall_arrayref( $sql, { }, @bind_array ) ;
	my $select_compte4 = '<select class="login-text" name=contrepartie id=contrepartie style="width: 30%;">' ;
	$select_compte4 .= '<option value="">--contrepartie--</option>' ;
	for ( @$compte_req4 ) {
	$select_compte4 .= '<option value="' . $_->[0] . '" >' . $_->[0] . ' - ' .$_->[1].'</option>' ;
	}
	$select_compte4 .= '<option value="" selected>--contrepartie--</option>' ;
	
	#lien d'importation d'un fichier de comptes
    my $import_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;import=0' ;
    my $import_link = '<a class=nav href="' . $import_href . '" style="margin-left: 2%;">Importer</a> ' ;
    
    $compte_list .= '
    <fieldset  class="pretty-box"><legend><h3 class="Titre09">Gestion des comptes</h3></legend>
    <div class=centrer>
		
		<form method="post">
		<input type="submit" class="btn btn-vert" style ="width : 30%;" formaction="compte&#63;configuration&amp;reconduire=0" value="Reconduire les comptes depuis l\'exercice ' . ( $exercice_a_reconduire ) . '">
		<input type="submit" class="btn btn-orange" style ="width : 30%;"  formaction="export&#63;id_mois=00&amp;id_export=0&amp;select_export=liste_comptes" value="Télécharger la liste des comptes pour l\'exercice en cours">
		</form>
		
		<br>
		
		<div class=Titre10>Importer les comptes <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'Comptes_2\');" style="cursor: pointer;" >[?]</span></div>
		<div class="form-int">
			<form style ="display:inline;" action="/'.$r->pnotes('session')->{racine}.'/compte" method=POST enctype="multipart/form-data">
			<input type=hidden name=configuration value=>
			<input type=hidden name=import value=1>
			<input type=file name=import_file>
			<input type="submit" class="btn btn-gris" style ="width : 25%;" value="Cliquez ici pour envoyer">
			</form>
		</div>
    
        <div class=Titre10>Ajouter un compte</div>
		<div class="form-int">
			<form action="/'.$r->pnotes('session')->{racine}.'/compte?configuration" method=POST>
			<div class=formflexN2>
			<input type=hidden name="ajouter" value="1">
			<input class="login-text" type=text name="new_numero_compte" value="" placeholder="Entrer le numéro du compte" style="width: 20%;" required>
			<input class="login-text" type=text name="libelle_compte" placeholder="Entrer le libellé du compte" value="" style="width: 30%;" required>
			'.$select_compte4.'
			<input type=submit class="btn btn-vert" style ="width : 10%;" value=Valider>
			</div>
			</form>
		</div>
    
		<div class=Titre10>Modifier les comptes existants</div>
		<ul class=wrapper10>
		
		
    ' ;

    for ( @$compte_set ) {
		
	my $reqline = ($line ++);	
		
	#select_compte4
	my $selected_compte4 = $_->{contrepartie};
	$select_compte4 = '<select onchange="findModif(this,'.$reqline.');" class="formMinDiv2" name=contrepartie id=contrepartie_'.$reqline.' >' ;
	$select_compte4 .= '<option value="">--contrepartie--</option>' ;
	for ( @$compte_req4 ) {
	my $selected = ( $_->[0] eq ($selected_compte4 || '') ) ? 'selected' : '' ;
	$select_compte4 .= '<option value="' . $_->[0] . '" ' . $selected . '>' . $_->[0] . ' - ' .$_->[1].'</option>' ;
	}
	if (!($_->{contrepartie})) {
	$select_compte4 .= '<option value="" selected>--contrepartie--</option>' ;
	}
	$select_compte4 .= '</select>' ;	
	

	#afficher le type de compte
	unless ( substr($_->{numero_compte}, 0, 1)  eq $class) {
		
		if (substr($_->{numero_compte}, 0, 1) eq 1) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 1 - COMPTES DE CAPITAUX</span></a><div class="spacer"></div></li>' ;
		} elsif (substr($_->{numero_compte}, 0, 1) eq 2) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 2 - COMPTES D\'IMMOBILISATIONS</span></a><div class="spacer"></div></li>' ;
		} elsif (substr($_->{numero_compte}, 0, 1) eq 4) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 4 - COMPTES DE TIERS</span></a><div class="spacer"></div></li>' ;
		} elsif (substr($_->{numero_compte}, 0, 1) eq 5) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 5 - COMPTES FINANCIERS</span></a><div class="spacer"></div></li>' ;
		} elsif (substr($_->{numero_compte}, 0, 1) eq 6) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 6 - COMPTES DE CHARGES</span></a><div class="spacer"></div></li>' ;
		} elsif (substr($_->{numero_compte}, 0, 1) eq 7) {
		$compte_list .= '<li class="style1"><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='. substr($_->{numero_compte}, 0, 1) .'"><div class="spacer"></div><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 7 - COMPTES DE PRODUITS</span></a><div class="spacer"></div></li>' ;
		} 

	    #$compte_list .= '<tr><th><span class=headerspan style="width: 100%;">Classe ' . substr($_->{numero_compte}, 0, 1) . '</span></th></tr>' ;

	    $class = substr($_->{numero_compte}, 0, 1) ;

	} #    for ( @$compte_set ) 

	my $delete_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;supprimer=0&amp;delete_numero=' . $_->{numero_compte} ;
	my $valid_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;modifier=1' ;
	my $delete_link = '<span class="blockspan" style="width: 3%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" height="16" width="16" alt="supprimer"></span>' ;
	
	my $view_tva = '<img class="redimmage" style="width: 8ch; " src="/Compta/style/icons/vide.png" alt="">';
	if (not($parametre_set->[0]->{id_tva_regime} eq 'franchise')) {
		$view_tva = default_id_tva( $r, $_->{default_id_tva}, $_->{numero_compte}, $reqline );
	}
	
	$compte_list .= '
	<li id="line_'.$reqline.'" class="style1">
	<div class="spacer"></div> 
	<form class=flex1  method=POST>
	<span class=displayspan style="width: 0.5%;">&nbsp;</span>
	<span class=displayspan style="width: 15%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="new_numero_compte" value="' . $_->{numero_compte} . '" ></span>
	<span class=displayspan style="width: 35%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="libelle_compte" onkeyup="verif(this);" value="' . $_->{libelle_compte} . '" ></span>
	<span class=displayspan style="width: 35%;">'.$select_compte4.'</span>
	<span class=displayspan style="width: 2%;">&nbsp;</span>
	<span class="displayspan" style="width: 3%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="16" width="16" alt="valider"></span>
	' . $delete_link . '
	<span class=displayspan style="width: 10%;">'.$view_tva.'</span>
	<span class=displayspan style="width: 0.5%;">&nbsp;</span>
	<input type=hidden name="configuration" value=>
	<input type=hidden name=classe value='.($args->{classe} || '').'>
	<input type=hidden name="old_numero_compte" value="' . $_->{numero_compte} . '">
	</form>
	<div class="spacer"></div>
	</li>' ;

    } #    for ( @$compte_set )
    
    $compte_list .= '
    </ul>
	</fieldset>
	';

    $content .= '<div class="formulaire2">' . $compte_list . '</div>' ;
	
    return $content ;

} #sub edit_compte_set

sub default_id_tva {

    my ( $r, $default_id_tva, $numero_compte, $reqline ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my $content = '' ;

    return $content unless ( substr( $numero_compte, 0, 1 ) eq '7' ) ;
    
    my $sql = 'SELECT id_tva FROM tbltva ORDER BY 1' ;

    my $tva_set = $dbh->selectall_arrayref( $sql ) ;

    my $option_set ;

    for ( @$tva_set ) {

	my $selected = ( $_->[0] eq $default_id_tva ) ? 'selected' : '' ;

	$option_set .= '<option ' . $selected . ' value="' . $_->[0] . '">' . $_->[0] . '</option>' ;

    }
    
    $content = '<select name=default_id_tva style="width: 8ch; margin-left: 1em;" oninput="findModif(this,'.$reqline.');">' . $option_set . '</select>' ;

    return $content ;

} #sub default_tva 

sub visiter_un_compte {
	
	#affiche le contenu d'un compte
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($sql,@bind_array) ;
    my $date = localtime->strftime('%d/%m/%Y');
    my $content = '' ;
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
    
    ################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args ) ;
	################ Affichage MENU ################
	
	#Récupérations des informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
    my $date_entry = $args->{grandlivre1} || $r->pnotes('session')->{Exercice_fin_YMD};
    $args->{libelle_compte} = Base::Site::bdd::get_compte_info($dbh, $r, $args->{numero_compte})->[0]->{libelle_compte} || 'Compte inexistant';
      
    ##Mise en forme de la date dans $args->{balance} de %Y-%m-%d vers 2000-02-29
	my $date_grandlivre_select = eval {Time::Piece->strptime($date_entry, "%Y-%m-%d")->dmy("/")};
    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }
    
    	#l'utilisateur a cliqué sur le bouton 'Imprimer'
	if ( defined $args->{numero_compte} && defined $args->{imprimer}) {
		
		my $location = export_pdf_grandlivre( $r, $args );
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
    
#####################################       
# Préparation à l'impression		#
##################################### 
	
	my ($print_title, $disp_title, $style_title)  = ('', '', '');
	if (defined $args->{numero_compte} && $args->{numero_compte} ne '0') {
		$print_title = 'Position de compte au ';
		$disp_title = 'Synthèse pour le compte N° '.$args->{numero_compte}.' - '.$args->{libelle_compte}.'';
		$style_title = 'left';
	} else {
		$print_title = 'Grand livre au ';
		$disp_title = 'Total';
		$style_title = 'right';
	}
	
	$content .= '
		<div class="printable">
		<div style="float: left ">
		<address><strong>'.$parametre_set->[0]->{etablissement} . '</strong><br>
		' . ($parametre_set->[0]->{adresse_1} || '') . ' <br> ' . ($parametre_set->[0]->{code_postal} || '') . ' ' . ($parametre_set->[0]->{ville} || '') .'<br>
		SIRET : ' . $parametre_set->[0]->{siret} . '<br>
		</address></div>
		<div style="float: right; text-align: right;">
		Imprimé le ' . $date . '<br>
		<div>
		Exercice du '.$r->pnotes('session')->{Exercice_debut_DMY}.' 
		</div>
		au '.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>
		</div>
		<div style="width: 100%; text-align: center;"><h1>'.$print_title.' '.($date_grandlivre_select|| '').'</h1>
		<div >
		Etat exprimé en Euros</div>
		</div><br></div>' ;
	
	#gestion des options
	my $checked = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? 'checked' : '' ;
    
    #gestion des filtres classe
	my $var_input_classe = ( defined $args->{classe} && $args->{classe} ne '') ? '<input type=hidden name=classe id=classe value="' . $args->{classe} . '">' : '' ;
	my $var_input_bdd_histo = ( defined $args->{historique} && $args->{historique} ne '') ? '<input type=hidden name=historique id=historique value="' . $args->{historique} . '">' : '' ;
	my $bdd_filter_classe = ( defined $args->{classe} && $args->{classe} ne '') ? 'classe = \''.$args->{classe}.'\' AND (' : '' ;
	my $bdd_filter_classe_end = ( defined $args->{classe} && $args->{classe} ne '' ) ? ')' : '' ;
    
    # Préservation du filtre écriture de cloture si défini
    my $var_input_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1') ? '&amp;ecriture_cloture=1' : '' ;
	# Préservation du filtre de pointage si défini
	my $var_input_pointage = (defined $args->{pointage} && $args->{pointage} ne '') ? '&amp;pointage=' . $args->{pointage} : '';
	# Préservation du filtre de lettrage si défini
	my $var_input_lettrage = (defined $args->{lettrage} && $args->{lettrage} ne '') ? '&amp;lettrage=' . $args->{lettrage} : '';
	# Préservation du filtre de classe si défini
	my $var_input_classe2 = (defined $args->{classe} && $args->{classe} ne '') ? '&amp;classe=' . $args->{classe} : '';
	
	my $print_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte='.$args->{numero_compte}.''.$var_input_cloture.'&amp;classe=' . ($args->{classe} || '') . '&amp;imprimer';
	my $print_link = '<li><a class=linav href="' . $print_href . '" title="Exporter en format pdf le grand livre" >Export pdf</a></li>' ;
	
    #définition des liens des classes 
	#my $print_link ='<li><a class="linav" href="#" onClick="window.print();return false" >Imprimer</a></li>' ;
	my $classeall_link = '<li><a class=' . ( ((!defined $args->{classe} && !defined $args->{lettrage} && !defined $args->{pointage} && (defined $args->{numero_compte} && $args->{numero_compte} eq '0') )|| (defined $args->{classe} && $args->{classe} eq '' && !defined $args->{lettrage} && !defined $args->{pointage} && (defined $args->{numero_compte} && $args->{numero_compte} eq '0'))) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.''.$var_input_cloture.'" >Toutes</a></li>' ;
	my $classe_temp = defined $args->{classe} ? $args->{classe} : '';
	
	# Gestion du menu pour Lettrées
	my $lettree_menu = '<li><a class=' . (((defined $args->{lettrage} && $args->{lettrage} eq 'not null')) ? 'linavselect' : 'linav' ) .
    ' href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte='.$args->{numero_compte}.'&amp;grandlivre1='.$date_entry.''.$var_input_cloture .
    (defined $args->{lettrage} && $args->{lettrage} eq 'not null' ? '' : '&amp;lettrage=not%20null') . $var_input_pointage . $var_input_classe2 .'" >Lettrées</a></li>';

	# Gestion du menu pour Non Lettrées
	my $nonlettree_menu = '<li><a class=' . (((defined $args->{lettrage} && $args->{lettrage} eq 'null')) ? 'linavselect' : 'linav' ) .
    ' href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte='.$args->{numero_compte}.'&amp;grandlivre1='.$date_entry.''.$var_input_cloture .
    (defined $args->{lettrage} && $args->{lettrage} eq 'null' ? '' : '&amp;lettrage=null') . $var_input_pointage . $var_input_classe2 .'" >Non Lettrées</a></li>';

	# Gestion du menu pour Pointées
	my $pointe_menu = '<li><a class=' . (((defined $args->{pointage} && $args->{pointage} eq 'true')) ? 'linavselect' : 'linav' ) .
    ' href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte='.$args->{numero_compte}.'&amp;grandlivre1='.$date_entry.''.$var_input_cloture .
    (defined $args->{pointage} && $args->{pointage} eq 'true' ? '' : '&amp;pointage=true') . $var_input_lettrage . $var_input_classe2 .'" >Pointées</a></li>';

	# Gestion du menu pour Non Pointées
	my $nonpointe_menu = '<li><a class=' . (((defined $args->{pointage} && $args->{pointage} eq 'false')) ? 'linavselect' : 'linav' ) .
    ' href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte='.$args->{numero_compte}.'&amp;grandlivre1='.$date_entry.''.$var_input_cloture .
    (defined $args->{pointage} && $args->{pointage} eq 'false' ? '' : '&amp;pointage=false') . $var_input_lettrage . $var_input_classe2 .'" >Non Pointées</a></li>';
    
	
	# Si la classe est définie, redirige toujours vers 'Toutes'
	my $href_classe = (defined $args->{classe} && $args->{classe} =~ /^[1-7]$/)
    ? 'href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.''.$var_input_cloture.'"'
    : 'href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.'&amp;classe='.$classe_temp.$var_input_cloture.'"';
	    
	# Génération dynamique des liens pour chaque classe (1 à 7) avec redirection vers 'Toutes' si la classe est déjà sélectionnée
	my $classe_links = '';
	foreach my $i (1..7) {
		my $href = (defined $args->{classe} && $args->{classe} eq $i)
			? '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.''.$var_input_cloture.''
			: '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.'&amp;classe='.$i.''.$var_input_cloture.'';
		
		$classe_links .= '<li><a class=' . (($args->{classe} && $args->{classe} eq $i) ? 'linavselect' : 'linav') . ' href="' . $href . '" title="Filtrer sur les comptes de Classe '.$i.'" >Classe '.$i.'</a></li>';
	}

	my %classes = (
		1 => 'DE LA CLASSE 1 - COMPTES DE CAPITAUX',
		2 => 'DE LA CLASSE 2 - COMPTES D\'IMMOBILISATIONS',
		3 => 'DE LA CLASSE 3 - COMPTES DE STOCKS',
		4 => 'DE LA CLASSE 4 - COMPTES DE TIERS',
		5 => 'DE LA CLASSE 5 - COMPTES FINANCIERS',
		6 => 'DE LA CLASSE 6 - COMPTES DE CHARGES',
		7 => 'DE LA CLASSE 7 - COMPTES DE PRODUITS',
	);

	#génération du menu
	$content .= '<div class="menuN2"><ul class="main-nav2">' . $classeall_link . $classe_links . $lettree_menu . $nonlettree_menu . $pointe_menu . $nonpointe_menu . $print_link . '</ul></div>' ;
    
    #formulaire date + options
	$content .= '
	<div style="padding-bottom: 3px" class="non-printable">
	<form method="get">
	<label style="font-weight: bold; text-align: right; color: #5f6368;pointer-events: none;" for="grandlivre1">Grand livre au</label>
	<input type=hidden name=numero_compte value='.($args->{numero_compte} || 0).'>
	<input class=linav type="date" name=grandlivre1 id=grandlivre1 value="' . $date_entry . '" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')" required >
	<input class=linav type=submit value=Valider>
	'.$var_input_classe.'
	'.$var_input_bdd_histo.'
	<input class=linav type=button value="Options..." style="" onclick="showButtons();">
	<input style="vertical-align: middle !important; margin-left: 2ch;" type="checkbox" id="ecriture_cloture" name="ecriture_cloture" title="Tenir compte des écritures de clôture" value="1" '.$checked.'>
	<label style="font-weight: normal; text-align: right;" for="ecriture_cloture" id="ecriture_cloture_label">Tenir compte des écritures de clôture</label>
	</form></div>' ;
    
    
    if ( defined $args->{pointer_tout} ) {

		#1ère demande de pointage généralisé; afficher lien d'annulation/confirmation
		if ( $args->{pointer_tout} eq '0' ) {

			my $non_href = '/base/compte?numero_compte=' . $args->{numero_compte} . '&pointage=0' ;
			my $oui_href = '/base/compte?numero_compte=' . $args->{numero_compte} . '&pointer_tout=1' ;
			$content .= '<h3 class=warning>Vraiment pointer toutes les lignes?<a href="' . $oui_href . '" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" style="margin-left: 3ch;">Non</a></h3>' ;

		} else {

			#demande de pointage généralisé confirmée
			$sql = 'UPDATE tbljournal set pointage = TRUE WHERE id_client = ? and fiscal_year = ? and numero_compte = ? and pointage = FALSE' ;

			eval { $dbh->do( $sql, undef, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{numero_compte} ) ) } ;

			if ( $@ ) {

			$content .= '<h3 class=warning>' . $@ . '</h3>' ;

			}
			
		} #	    if ( $args->{pointer_tout} eq '0' )

    } #	if ( defined $args->{pointer_tout} ) 

    my $return_href = '/base/compte' ;

    my ( $lettrage_input, $lettrage_base ) ;
    
    my ( $pointage_input, $pointage_base ) ; 
    
    $args->{base_uri} = $r->unparsed_uri() ;

    #effacer les options de $args->{base_uri} pour garder une base propre
    $args->{base_uri} =~ s/&pointage=(.*)|&lettrage=(.*)|&historique=(.*)// ;

    my $rapprochement_link = '<a class=linav href="' . $args->{base_uri} . '&amp;rapprochement=0' . '">Rapprochement</a>' ;

    #ajout éventuel d'une condition à la clause WHERE pour l'affichage de pointée|lettrées/non pointées|lettrées/toutes
    my $lettrage_condition = '' ;
    my $pointage_condition = '' ;

    $pointage_base = '<input class=non-printable type=checkbox id=id value=value style="vertical-align: middle;" onclick="pointage(this, \'' . $args->{numero_compte} . '\')">' ;
    
	if (defined $args->{pointage} && ($args->{pointage} eq 'true' or $args->{pointage} eq 'false')) {

	$pointage_condition = ' AND pointage = ' . $args->{pointage}.' ' ;

    } #    if (defined $args->{pointage} ) 

    $lettrage_base = '<input class=non-printable type=text id=id style="margin-left: 0.5em; padding: 0; width: 7ch; height: 1em; text-align: right;" value=value placeholder=&rarr; oninput="lettrage(this, \'' . $args->{numero_compte} . '\')">' ;

    if (defined $args->{lettrage} && ($args->{lettrage} eq 'null' or $args->{lettrage} eq 'not null' or $args->{lettrage} eq '0')) {

	$lettrage_condition = ' AND lettrage IS ' . $args->{lettrage}.' ' ;
	    
    } #    if (defined $arg{lettrage} ) 

    my $class1 = 'linav' ;
    my $class2 = 'linav' ;
    my $var_input_historique_sum = '&historique=summary';
    my $var_input_historique_det = '&historique=detail';
    
	if ( defined $args->{historique} && $args->{historique} eq 'summary' ){
		$class1 = 'linavselect';
		$var_input_historique_sum = '';
	}
	
	if ( defined $args->{historique} && $args->{historique} eq 'detail' ) {
		$class2 = 'linavselect';
		$var_input_historique_det = '';
	}
	
	my $var_input_historique = ( defined $args->{historique} ) ? '&amp;historique='.$args->{historique}.'' : '' ;
	
    my $historique_link = '
    <a class=' . $class1 . ' href="' . $r->uri . '?numero_compte=' . ($args->{numero_compte} || '') . ''.$var_input_historique_sum.''.$var_input_cloture.'" >Historique résumé</a>
    <a class=' . $class2 . ' href="' . $r->uri . '?numero_compte=' . ($args->{numero_compte} || '') . ''.$var_input_historique_det.''.$var_input_cloture.'" >Historique détaillé</a>' ;
    
    #contenu du/des compte(s); on limite la clause where si on a un numero_compte
    my $numero_compte_condition = ( $args->{numero_compte} ) ? ' AND numero_compte = ? ' : '' ;
    
    $bdd_filter_classe = ( defined $args->{classe} && $args->{classe} ne '') ? 'AND substring(numero_compte from 1 for 1)  = \''.$args->{classe}.'\'' : '' ;
	$bdd_filter_classe_end = ( defined $args->{classe} ) ? ')' : '' ;
	#appliquer le filtre => ecriture de clôture
	my $display_ecriture_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? '' : 'AND libelle_journal NOT LIKE \'%CLOTURE%\'' ;
    
	
    $sql = '
	with t1 as (
	SELECT id_client, fiscal_year, numero_compte, id_entry, id_line, date_ecriture, libelle_journal, coalesce(id_facture, \'&nbsp;\') as id_facture, coalesce(id_paiement, \'&nbsp;\') as id_paiement, coalesce(libelle, \'&nbsp;\') as libelle, debit/100::numeric as debit, credit/100::numeric as credit, lettrage, pointage
	FROM tbljournal
	WHERE id_client = ? and fiscal_year = ?  AND date_ecriture <= ? ' . $pointage_condition . $lettrage_condition . $numero_compte_condition . $bdd_filter_classe . $display_ecriture_cloture .'
	ORDER BY numero_compte, date_ecriture, id_facture, libelle, id_line
	) 
	SELECT t1.numero_compte, regexp_replace(t2.libelle_compte, \'\\s\', \'&nbsp;\', \'g\') as libelle_compte, id_entry, id_line, date_ecriture, libelle_journal, coalesce(id_facture, \'&nbsp;\') as id_facture, coalesce(id_paiement, \'&nbsp;\') as id_paiement, coalesce(libelle, \'&nbsp;\') as libelle, to_char(debit, \'999G999G999G990D00\') as debit, to_char(credit, \'999G999G999G990D00\') as credit, lettrage, pointage, to_char(sum(debit) over (PARTITION BY numero_compte), \'999G999G999G990D00\') as total_debit, to_char(sum(credit) over (PARTITION BY numero_compte), \'999G999G999G990D00\') as total_credit, to_char(sum(credit-debit) over (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle), \'999G999G999G990D00\') as solde
	FROM t1 INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte)
	ORDER BY numero_compte, date_ecriture, id_facture, libelle, id_line
	' ;  
    
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry ) ;
    
    #si numero_compte != 0, on veut un seul compte
    #on utilise numero_compte=0 pour afficher le journal général
    push @bind_array, $args->{numero_compte} if ( $args->{numero_compte} ) ;
    
    my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

    #ligne d'en-têtes
    my $entry_list = '' ;

    #pas trouvé de moyen évident de formater les résultats à zéro conformément à la locale avec perl
    #si postgres ne retourne aucun résultat, ne rien afficher laisse une sorte de doute
    #du coup, on affiche dans ce cas un 0 simple, immédiatement compréhensible
    #un peu dérangeant car le format n'est pas localisé, mais qui va visiter des comptes vides de toutes façons?
    my ( $total_credit, $total_debit, $total_solde ) = ( '0,00', '0,00', '0,00' ) ;

    my $class_description = '';
	if (defined $args->{classe} && exists $classes{$args->{classe}}) {
		$class_description = $classes{$args->{classe}};
	}
    #titre du Grand Livre
    $entry_list .= '<li style="list-style: none; margin-bottom: 1%;"><h2 class=Titre09>GRAND LIVRE '.$class_description.'</h2>' if ($args->{numero_compte} eq '0' ) ;
	    
    #pour un seul compte, il faut placer l'en-tête et les options de pointage/lettrage
    if ( $args->{numero_compte} ) {
	
	my $position_compte = '';
	my $libelle_compte = ( $args->{libelle_compte} =~ s/\s/&nbsp;/g ) ;
	my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $args->{numero_compte} ) ;
	
	my $position_link = '<a class=linavselect href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&amp;grandlivre1='.$date_entry.''.$var_input_cloture.'" >Position de compte</a>' ;
	
	
	$entry_list .= '
	<li style="list-style: none; margin: 0;"><h2><a href="' . ($compte_href || '') . '"  style="color: black; text-decoration: none;">Compte N° '. $args->{numero_compte} . '&nbsp;[&nbsp;'. $args->{libelle_compte} . '&nbsp;]</a></h2></li>
	<li class=lineflex1><div class=spacer></div></li>
	<li style="list-style: none; margin: 0;" class="menu">' . $position_link . $rapprochement_link . $historique_link . '</li>
	<li class=lineflex1><div class=spacer></div></li>
	<li style="list-style: none; margin: 0;" class="menu">&nbsp;</li>
	' ;

	$entry_list .= '
	<li class=lineflex1><div class=spacer></div>
	<span class=headerspan style="width: 9%;">Date</span>
	<span class=headerspan style="width: 9%;">Journal</span>
	<span class=headerspan style="width: 7%;">Libre</span>
	<span class=headerspan style="width: 12%;">Pièce</span>
	<span class=headerspan style="width: 28.5%;">Libellé</span>
	<span class=headerspan style="width: 9%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 9%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 7.4%; text-align: left;">&nbsp;</span>
	<span class=headerspan style="width: 9%; text-align: right;">Solde</span>
	<div class=spacer></div>
	</li>
	' ;

    }
    
    for ( @$result_set ) {

	#changement de numero_compte : mettre un recap et l'en-tête du compte suivant
	unless ( $_->{numero_compte} eq $args->{numero_compte} ) {
		
	    #pas de recap avant d'avoir parcouru le premier compte
	    unless ( $args->{numero_compte} eq '0' ) {

		$entry_list .=  '
		<li class=listitem3><hr></li>
		<li class=lineflex1><div class=spacer></div>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 9%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;">&nbsp;</span>
		<span class=displayspan style="width: 12%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 28.5%; text-align: right;">Total</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_debit . '</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_credit . '</span>
		<span class=displayspan style="width: 7.4%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_solde . '</span>
		<div class=spacer></div>
		</li>' ;

	    } #	    unless ( $args->{numero_compte} eq '0' ) 
		
		my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $_->{numero_compte} ) ;

	    #en-têtes du compte
	    $entry_list .= '
	    <li style="list-style: none; margin: 0;">
	    <h3><a href="' . ($compte_href || '') . '"  style="color: black; text-decoration: none;">Compte N° '. $_->{numero_compte} . ' [ '. $_->{libelle_compte} . ' ]</a></h3>
	    </li>' ;

		$entry_list .= '
		<li class=lineflex1><div class="spacer"></div>
		<span class=headerspan style="width: 9%;">Date</span>
		<span class=headerspan style="width: 9%;">Journal</span>
		<span class=headerspan style="width: 7%;">Libre</span>
		<span class=headerspan style="width: 12%;">Pièce</span>
		<span class=headerspan style="width: 28.5%;">Libellé</span>
		<span class=headerspan style="width: 9%; text-align: right;">Débit</span>
		<span class=headerspan style="width: 9%; text-align: right;">Crédit</span>
		<span class=headerspan style="width: 7.4%;">&nbsp;</span>
		<span class=headerspan style="width: 9%; text-align: right;">Solde</span>
		<div class=spacer></div>
		</li>
		';


	    $args->{numero_compte} = $_->{numero_compte} ;
	    
	} #	unless ( $_->{numero_compte} eq $args->{numero_compte} )
	
	$sql = 'SELECT id_client FROM tbllocked_month 
	WHERE id_client = ? and ( id_month = to_char(?::date, \'MM\') ) AND fiscal_year = ?';
	@bind_array = ( $r->pnotes('session')->{id_client}, $_->{date_ecriture}, $r->pnotes('session')->{fiscal_year}) ;
	my $result_block = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

	my $lettrage_pointage = '&nbsp;' ;
	
	#l'id_line de la checkox de pointage commence par pointage_ pour être différente de id_line sur l'input de lettrage
	my $pointage_id = 'id=pointage_' . $_->{id_line} ;
	
	( $pointage_input = $pointage_base ) =~ s/id=id/$pointage_id/ ;

	my $pointage_value = ( $_->{pointage} eq 't' ) ? 'checked' : '' ;

	$pointage_input =~ s/value=value/$pointage_value/ ;
	
	if (defined $result_block && $result_block eq $r->pnotes('session')->{id_client}) {
	$lettrage_pointage .= ( $_->{pointage} eq 't' ) ? '<img class="redimmage nav" title="Check complet" src="/Compta/style/icons/icone-valider.png" alt="valide">' : '&nbsp;' ;
	} else {
	$lettrage_pointage .= $pointage_input ;
	}
	
	my $lettrage_id = 'id=' . $_->{id_line} ;

	( $lettrage_input = $lettrage_base ) =~ s/id=id/$lettrage_id/ ;
	
	my $lettrage_value = ( $_->{lettrage} ) ? 'value=' . $_->{lettrage} : '' ;

	$lettrage_input =~ s/value=value/$lettrage_value/ ;

	if (defined $result_block && $result_block eq $r->pnotes('session')->{id_client}) {
	$lettrage_pointage .= ( $_->{lettrage} || '&nbsp;' );
	} else {
	$lettrage_pointage .= $lettrage_input ;
	}

	#lien vers le formulaire d'édition de l'entrée considérée
	my $journal_href = '/base/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . URI::Escape::uri_escape_utf8( $_->{id_entry} ) ;

	$entry_list .= '
	<li class=listitem3>
	<div class=spacer></div>
	<a class=listitem3 href="' . $journal_href . '">
		<span class=blockspan style="width: 9%;">' . $_->{date_ecriture} . '</span>
		<span class=blockspan style="width: 9%;">' . $_->{libelle_journal} . '</span>
		<span class=blockspan style="width: 7%;">' . ($_->{id_paiement} || '&nbsp;' ) . '</span>
		<span class=blockspan style="width: 12%;">' . ($_->{id_facture} || '&nbsp;' ) . '</span>
		<span class=blockspan style="width: 28.5%;">' . ($_->{libelle} || '&nbsp;' ) . '</span>
		<span class=blockspan  style="width: 9%; text-align: right;">' . $_->{debit} . '</span>
		<span class=blockspan style="width: 9%; text-align: right;">' . $_->{credit} . '</span>
	</a>
	<span class=blockspan style="width: 0.5%;">&nbsp;</span>
	<span class="blockspan" style="width: 6.9%;">' . ($lettrage_pointage || '&nbsp;') . '</span>
	<span class=blockspan style="width: 9%; text-align: right;">' . $_->{solde} . '</span>
	<div class=spacer></div>
	</li>' ;

	#les totaux sont repris en début de boucle, juste avant de commencer le compte suivant
	$total_debit = $_->{total_debit} ;
	$total_credit = $_->{total_credit} ;
	$total_solde = $_->{solde};

    } #    for ( @$result_set ) 
	
	unless (@$result_set ) {
		
		$entry_list .= '<div class="warnlite">*** Aucune écriture trouvée ***</div><li class=style1><hr></li>';
		$content .= '<div class="wrapper-docs"><ul>' . $entry_list . '</ul></div>' ;

	} else {
		
		#recap du dernier compte de la liste, qui n'est pas dans la boucle
		$entry_list .=  '
		<li class=listitem3><hr></li>
		<li class=lineflex1><div class=spacer></div>
		<span class="displayspan bold" style="width: 65.5%; text-align: '.$style_title.';">'.$disp_title.'</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_debit . '</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_credit . '</span>
		<span class=displayspan style="width: 7.4%;">&nbsp;</span>
		<span class="displayspan bold" style="width: 9%; text-align: right;">' . $total_solde . '</span>
		<div class=spacer></div></li>';
	
		$content .= '<div class="wrapper-docs"><ul>' . $entry_list . '</ul></div>' ;
		$content .= historique_du_compte( $r, $args ) ;
	}

    return $content ;
    
} #sub visiter_un_compte 

sub liste_des_comptes {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;
    my $content;

    ################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args ) ;
	################ Affichage MENU ################
    
    #liste des comptes
    my $sql = 'SELECT numero_compte, substring(numero_compte from \'^.\') as classe, libelle_compte, default_id_tva FROM tblcompte WHERE id_client = ? AND fiscal_year = ? ORDER by numero_compte' ;

    my $compte_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ) ;

    my $compte_list = '' ;
    
    my $classe = '' ;
    
    for ( @$compte_set ) {
	
	#afficher la classe si on change de classe
	unless ( $_->{classe} eq $classe ) {

		if ($_->{classe} eq 1) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 1 - COMPTES DE CAPITAUX</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 2) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 2 - COMPTES D\'IMMOBILISATIONS</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 3) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 3 - COMPTES DE STOCKS</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 4) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 4 - COMPTES DE TIERS</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 5) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 5 - COMPTES FINANCIERS</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 6) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 6 - COMPTES DE CHARGES</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 7) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 7 - COMPTES DE PRODUITS</span></a><div class=spacer></div></div></li>' ;
		} 
			
		$classe = $_->{classe} ;

	}

	#lien vers le contenu du compte
	my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $_->{numero_compte} ) ;
	
	#ligne du compte
	$compte_list .= '<li class=listitem3><div class=container style="margin-left: 1ch;"><div class=spacer></div><a href="' . $compte_href . '"><span class=blockspan>
<span class=blockspan style="width: 20ch;">' . $_->{numero_compte} . '</span>
<span class=blockspan style="width: 80ch;">' . $_->{libelle_compte} . '</span>
</span></a><div class=spacer></div></div></li>' ;

    } #    for ( @$compte_set ) {
    
    if ( !@$compte_set ) {
		#aucun compte n'existe
		$content .= Base::Site::util::generate_error_message('
		*** Aucun compte enregistré ***
		<br><br>
		<a class=nav href="compte?configuration">Ajouter des comptes</a>
		<br><br>
		<a class=nav href="compte?configuration&reconduire=0">Reconduire les comptes de l\'exercice précédent</a>') ;
	}

   $content .= '<div class="wrapper-compte" ><ul class=wrapper>' . $compte_list . '</ul></div>' ;
    
    return $content ;

} #sub liste_des_comptes 

#/*—————————————— Module Balance ——————————————*/
sub balance {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content, $varbalance ) ;
    my $date = localtime->strftime('%d/%m/%Y');

    #Récupérations des informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
    
	#l'utilisateur a cliqué sur le bouton 'Imprimer'
	if ( defined $args->{balance} && defined $args->{imprimer}) {
		
		my $location = export_pdf_balance( $r, $args ); ;
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
#####################################       
# Manipulation des dates			#
#####################################  

    my $date_entry = $args->{balance} || $r->pnotes('session')->{Exercice_fin_YMD};
    
    ##Mise en forme de la date dans $args->{balance} de %Y-%m-%d vers 2000-02-29
	my $date_balance_select = eval {Time::Piece->strptime($date_entry, "%Y-%m-%d")->dmy("/")};
	
    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }
    
#####################################       
# Préparation à l'impression		#
#####################################   
	#Titre impression de la balance
    if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$varbalance = 'de clôture';
	} else {
	$varbalance = 'générale';
	}

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
		<div style="width: 100%; text-align: center;"><h1>Balance '.$varbalance.' au '.($date_balance_select ||'').'</h1>
		<div style="font-size: 9pt;">
		Etat exprimé en Euros</div>
		</div></div>' ;

    #les 5 premiers paramètres dont on a besoin pour la fonction calcul_balance dans postgresql
    #sont placés tout de suite dans @bind_array; le 6ème paramètre (le format désiré pour les chiffres
    #selon qu'on affiche le résultat à l'écran ou qu'on l'écrit dans un fichier à télécharger)
    #est ajouté plus bas
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

    #if $args->{download} est présent, l'utilisateur a cliqué sur le lien de téléchargement
    if ( defined $args->{download} ) {

	#il faut passer par $1 pour untainter les paramètres
	#ces derniers sont ordonnés comme @bind_array

	#$args->{balance} a été accepté par postgresql en entrée de procédure
	#laquelle efface le lien de téléchargement en cas de date non valide
	#on peut donc prendre le paramètre tel quel, on sait qu'il est bon
	#il serait souhaitable de l'ajouter au chemin vers le fichier à télécharger
	#mais les différents formats de date possibles rendent le chemin trop aléatoire
	$args->{balance} =~ /(.*)/ ;
	
	my $param_2 = $1 ;

	$r->pnotes('session')->{id_client} =~ /(\d+)/ ;

	my $param_0 = $1 ;

	my $param_3 = $1 ;
	
	$r->pnotes('session')->{fiscal_year} =~ /(\d\d\d\d)/ ;

	my $param_1 = $1 ;

	my $param_4 = $1 ;

	#le format que doit utiliser postgres pour afficher les nombres
	#on ne met pas de séparateur de milliers pour ne pas affoler les tableurs
	#on utilise le séparateur décimal local (D); on force l'affichage sur deux décimales et du premier zéro (0D00)
	#on supprime les éléments vides du formatage (FM)
	my $param_5 = 'FM999999999990D00' ;

	#le fichier csv à générer
	#il faut faire un untaint du suffixe de session
	substr($r->pnotes('session')->{_session_id}, 0, 10) =~ /(.*)/ ;
	
	my $file_name = 'balance_' . $1 . '.csv' ;
	    
	my $location = '/Compta/base/downloads/' . $file_name ;

	my $file_path = $r->document_root() . $location ;

	#les colonnes de calculs cumulés par classe présentes dans calcul_balance() ne sont pas incluses
	#il faut ajouter les quotes autour de $param_2 et $param_5 pour éviter une erreur de type
	$sql = qq{\\copy (select numero_compte, libelle_compte, debit, credit, solde_debit, solde_credit from calcul_balance($param_0, $param_1, '$param_2', $param_3, $param_4, '$param_5')) to '$file_path' with csv header delimiter ';'} ;

	#nécessaire pour éviter l'erreur Insecure $ENV{PATH} while running with -T switch
	$ENV{'PATH'} = '/bin:/usr/bin' ;
	
	my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";

	#
	#add BOM
	#
	
	my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $r->document_root() . $location) ;

	system( @args ) == 0 or die "Bad BOM: $?";
	
	return $location ;

    } else { #	demande d'affichage de la balance		

	my $download_href = $r->uri . '?balance=' . $date_entry . '&download=0' ;
	my $balance_cloture_href = $r->uri . '?balance=' . $date_entry . '&affichagecloture=1' ;
	my $download_link = '<a class=linav href="' . $download_href . '" title="Télécharger la balance général au ' . $date_entry . '" id="download_balance_link">Télécharger</a>' ;
	
	my $print_href = '/'.$r->pnotes('session')->{racine}.'/compte?balance=' . $date_entry . '&amp;ecriture_cloture=' . ($args->{ecriture_cloture} || 0). '&amp;imprimer';
	my $print_link = '<a class=linav href="' . $print_href . '" title="Exporter en format pdf la balance générale au ' . $date_entry . '" >Export pdf</a>' ;
	
	my $balance_cloture_link = '<a href="' . $balance_cloture_href . '" title="Balance de clôture">balance de clôture</a>' ;

	#fonction javascript qui efface le lien de téléchargement si l'utilisateur modifie la date
	#ce dernier doit alors cliquer sur 'Valider' pour que le lien réapparaisse avec la nouvelle date
	# + document.getElementById => affichage des options via le bouton
	$content .= '
	<script>
	function hide_download_balance_link() {document.getElementById("download_balance_link").style.visibility = "hidden";}
	</script>' ;
	
	my $checked = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? 'checked' : '' ;
	
	#titre
	$content .= '
	<div style="padding-top: 3px" class="menu non-printable">
	<form action="/'.$r->pnotes('session')->{racine}.'/compte">
	<label style="font-weight: bold;font-size: 1em; text-align: right; color: #5f6368;" for="balance">Balance générale au </label>
	<input class=linav type="date" name=balance id=balance value="' . $date_entry . '" oninput="hide_download_balance_link()" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')">
	</td><input class=linav type=submit value=Valider>
	<input class=linav type=button value="Options..." style="" onclick="showButtons();">
	<input style="vertical-align: middle !important; margin-left: 2ch;" type="checkbox" id="ecriture_cloture" name="ecriture_cloture" title="Tenir compte des écritures de clôture" value="1" '.$checked.'>
	<label style="font-weight: normal; text-align: right;" for="ecriture_cloture" id="ecriture_cloture_label">Tenir compte des écritures de clôture</label>
	<td style="margin-left: 2ch;">' . $download_link . $print_link .'
	</form></div>' ;
	
	#en-têtes
	my $compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><h4>
<span class=displayspan style="width: 55%;">&nbsp;</span>
<span class=displayspan style="width: 11%; text-align: right;">Sommes</span>
<span class=displayspan style="width: 11%; text-align: right;">&nbsp;</span>
<span class=displayspan style="width: 11%; text-align: right;">Soldes</span>
<span class=displayspan style="width: 11%; text-align: right;">&nbsp;</span></h4>
<div class=spacer></div></div></li>' ;

	$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div>
<span class=displayspan style="width: 55%;">&nbsp;</span>
<span class=displayspan style="width: 11%; text-align: right;">Débit</span>
<span class=displayspan style="width: 11%; text-align: right;">Crédit</span>
<span class=displayspan style="width: 11%; text-align: right;">Débit</span>
<span class=displayspan style="width: 11%; text-align: right;">Crédit</span>
<div class=spacer></div></div></li>' ;

	#liste des comptes avec les calculs de soldes
	#il faut ajouter le format que l'on souhaite pour l'affichage web à @bind_array
	push @bind_array, 'FM999G999G999G990D00' ;
	
	if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$sql = 'select * from calcul_balance_cloture(?, ?, ?, ?, ?, ?) WHERE solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\'';
	} else {
	$sql = 'select * from calcul_balance(?, ?, ?, ?, ?, ?) WHERE solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\'';
	}
	
	my $compte_set ;

	#à ce stade, la date de calcul de la balance a été formatée en iso
	eval { $compte_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	
	if ( $@ ) {
	    if ( $@ =~ / date/ ) {
		#erreur de date; dans ce cas, ne pas afficher le lien de téléchargement
		$content .= Base::Site::util::generate_error_message('Date non valide : ' . $date_entry. '');
		$content .= '<script>document.getElementById("download_balance_link").style.visibility = "hidden";</script>' ;
	    } else {
		$content .= Base::Site::util::generate_error_message($@) ;
	    }
	} #    if ( $@ ) 
	
	# définition des variables
	my ( $classe, $classe_solde_line, $tot_classe_6, $tot_classe_7, $tot_perte_129, $tot_gain_119)  = ( '', '' ) ;
	
	#$content .= '<pre>' . Data::Dumper::Dumper($compte_set) . '</pre></div>' ;

	my $numero_compte = '' ;
	my $compte_href = '' ;
	
	if (@$compte_set) {
		for ( @$compte_set ) {
			
			#afficher la classe si on change de classe
			unless ( $_->{classe} eq $classe ) {

			$compte_list .= $classe_solde_line ;

			if ($_->{classe} eq 1) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 1 - COMPTES DE CAPITAUX</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 2) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 2 - COMPTES D\'IMMOBILISATIONS</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 3) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 3 - COMPTES DE STOCKS</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 4) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 4 - COMPTES DE TIERS</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 5) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 5 - COMPTES FINANCIERS</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 6) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 6 - COMPTES DE CHARGES</span></a><div class=spacer></div></div></li>' ;
			} elsif ($_->{classe} eq 7) {
			$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$_->{classe}.'"><span class=headerspan style="width: 100%; font-size: larger;">CLASSE 7 - COMPTES DE PRODUITS</span></a><div class=spacer></div></div></li>' ;
			} 
				
			$classe = $_->{classe} ;

			}
			
			
			if ( defined $numero_compte ) { 
		
			unless ( $_->{numero_compte} eq $numero_compte ) {

			#lien vers le contenu du compte
			$compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $_->{numero_compte} ) . '';

			#cas particulier de la première entrée de la liste : pas de liste précédente
			unless ( $numero_compte ) {

			$compte_list .= '<li class=listitem3>' ;

			} else {
					
			$compte_list .= '</a></li><li class=listitem3>'

			} #	    unless ( $id_entry ) 

		} #	unless ( $_->{id_entry} eq $id_entry ) 
		
		}

		#marquer l'entrée en cours
		$numero_compte = $_->{numero_compte} ;
			

			#ligne du compte
			$compte_list .= '
			<div class=flex-table><div class=spacer></div><a href="' . $compte_href . '">
			<span class=blockspan style="width: 10%;">' . $_->{numero_compte} . '</span>
			<span class=blockspan style="width: 45%;">' . $_->{libelle_compte} . '</span>
			<span class=blockspan style="width: 11%; text-align: right;">' . $_->{debit} . '</span>
			<span class=blockspan style="width: 11%; text-align: right;">' . $_->{credit} . '</span>
			<span class=blockspan style="width: 11%; text-align: right;">' . $_->{solde_debit} . '</span>
			<span class=blockspan style="width: 11%; text-align: right;">' . $_->{solde_credit} . '</span>
			<div class=spacer></div></div>
			' ;
			
			# remplacer résultat à 0 par un espace
			if ($_->{classe_total_credit_solde_dif} eq '0,00') {
			$_->{classe_total_credit_solde_dif} = '&nbsp' ;	
			}
			
			if ($_->{classe_total_debit_solde_dif} eq '0,00') {
			$_->{classe_total_debit_solde_dif} = '&nbsp' ;	
			}
			
	############# DEBUG##########
			#my $num1 = $_->{classe_total_credit_solde_dif} ;
			#$content .= '<pre>' . $num1 . '</pre></div>';
	############# DEBUG##########
			
			# Calcul du solde des comptes de classe
			my $classe_solde_debit_solde = '' ;
			my $classe_solde_credit_solde = '';
			(my $classe_total_debit_solde = $_->{classe_total_debit_solde}) =~ s/[^a-zA-Z0-9]//g;
			(my $classe_total_credit_solde = $_->{classe_total_credit_solde}) =~ s/[^a-zA-Z0-9]//g;
			my $classe_solde_debit_temp = $classe_total_debit_solde - $classe_total_credit_solde;
			my $classe_solde_credit_temp = $classe_total_credit_solde - $classe_total_debit_solde ;
			
			# Mise en forme des résultats
			if ($classe_solde_debit_temp > $classe_solde_credit_temp) {
			($classe_solde_debit_solde = sprintf( "%.2f",$classe_solde_debit_temp/100)) =~ s/\./\,/g;
			$classe_solde_debit_solde =~ s/\B(?=(...)*$)/ /g ;
			$classe_solde_credit_solde = '' ;
			} 
			if ($classe_solde_debit_temp < $classe_solde_credit_temp){
			($classe_solde_credit_solde = sprintf( "%.2f",$classe_solde_credit_temp/100)) =~ s/\./\,/g ;
			$classe_solde_credit_solde =~ s/\B(?=(...)*$)/ /g ;
			$classe_solde_debit_solde = '' ;
			}
			
			# passage des résultats aux variables
			if ( $_->{classe} =~ /6/) { 
			($tot_classe_6 = $classe_solde_debit_solde) =~ s/[^a-zA-Z0-9]//g;
			}
			
			if ( $_->{classe} =~ /7/) { 
			($tot_classe_7 = $classe_solde_credit_solde) =~ s/[^a-zA-Z0-9]//g;
			}
			
			# récupération du solde des comptes de cloture
			if (substr( $_->{numero_compte}, 0, 3 ) =~ /129/ ) {
			$tot_perte_129 = $_->{solde_debit} ;
			} 
			
			if ((substr( $_->{numero_compte}, 0, 3 ) =~ /119/) ) {
			$tot_gain_119 = $_->{solde_credit} ;
			} 
			
			#affichage Total classe
			$classe_solde_line = '</a></li><li class="submit_balance style1"><div class=flex-table><div class=spacer></div>
			<span class=displayspan style="width: 55%; text-align: right;">Total classe ' . $_->{classe} . '</span>
			<span class=displayspan style="width: 11%; text-align: right;">' .  $_->{classe_total_debit} . '</span>
			<span class=displayspan style="width: 11%; text-align: right;">' .  $_->{classe_total_credit}. '</span>
			<span class=displayspan style="width: 11%; text-align: right;">' . $_->{classe_total_debit_solde_dif} . '</span>
			<span class=displayspan style="width: 11%; text-align: right;">' . $_->{classe_total_credit_solde_dif} . '</span>
			<div class=spacer></div></div></li>' ;
			
		} #    for ( @$compte_set ) {
		
		#on clot la liste s'il y avait au moins une entrée dans le journal
		$compte_list .= '</a></li>' if ( @$compte_set ) ;

		#ajouter la dernière ligne des sous-totaux par classe
		$compte_list .= $classe_solde_line ;

		#affichage Total Balance
		my $grand_total_line = '
		<li class="style1"><span class=displayspan style="width: 100%;">&nbsp;</span></li><li class="style1">
		<span class=displayspan style="width: 55%; text-align: right; font-weight:bold;">Total Balance&nbsp;</span>
		<span class=displayspan style="width: 11%; text-align: right; font-weight:bold;">' . ( $compte_set->[0]->{grand_total_debit} || 0 ) . '</span>
		<span class=displayspan style="width: 11%; text-align: right; font-weight:bold;">' . ( $compte_set->[0]->{grand_total_credit} || 0 ) . '</span>
		<span class=displayspan style="width: 11%; text-align: right; font-weight:bold;">' . ( $compte_set->[0]->{grand_total_debit_solde} || 0 ) . '</span>
		<span class=displayspan style="width: 11%; text-align: right; font-weight:bold;">' . ( $compte_set->[0]->{grand_total_credit_solde} || 0 ) . '</span>
		</li><li class="style1"><span class=displayspan style="width: 100%;">&nbsp;</span></li>
		' ;

		# si $@ est défini, la requête a échoué, il n'y a pas de grand total à afficher
		$compte_list .= $grand_total_line unless ( $@ ) ;
		
		#Calcul du résultat comptable
		my ($total_pain_gain, $colour_resultat_N, $desc_resultat);
		
		$total_pain_gain = ( $tot_classe_7 || 0) - ($tot_classe_6 || 0);
		$total_pain_gain = sprintf( "%.2f",$total_pain_gain/100) ;
		
		if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
			if (defined $tot_perte_129 && ($tot_perte_129 =~/\d/) && $tot_perte_129 ne '0,00') {
			$total_pain_gain = $tot_perte_129 ;
			$colour_resultat_N = 'color: red;';
			$desc_resultat = 'Perte de ';
			} else {
				if (defined $tot_gain_119 && ($tot_gain_119 =~/\d/) && $tot_gain_119 ne '0,00') {
				$total_pain_gain = $tot_gain_119 ;	 
				$colour_resultat_N = 'color: green;';
				$desc_resultat = 'Bénéfice de ';
				} else {
				
				if ($total_pain_gain > 0) {
				$colour_resultat_N = 'color: green;';
				$desc_resultat = 'Bénéfice de ';
				} 
				elsif ($total_pain_gain < 0) {
				$total_pain_gain = $total_pain_gain * -1;	
				$colour_resultat_N = 'color: red;';
				$desc_resultat = 'Perte de ';
				} 
				
				}
			}	
		} else {
		
		if ($total_pain_gain > 0) {
		$colour_resultat_N = 'color: green;';
		$desc_resultat = 'Bénéfice de ';
		} 
		elsif ($total_pain_gain < 0) {
		$total_pain_gain = $total_pain_gain * -1;	
		$colour_resultat_N = 'color: red;';
		$desc_resultat = 'Perte de ';
		} 
		
		}
		
		$total_pain_gain =~ s/\./\,/g ;
		$total_pain_gain =~ s/\B(?=(...)*$)/ /g ;
		

		my $style_resultat2 = '<span>' . $total_pain_gain . ' Euros</span></span>';
		my $style_resultat3 = ( defined $colour_resultat_N && defined $desc_resultat ) ? '<span style="'. $colour_resultat_N .'">'. $desc_resultat .' ' . $total_pain_gain . ' Euros</span></span>' : $style_resultat2 ;

		#affichage du résultat comptable
		my $perte_gain_provisoire  = '<li class="style1" style="font-weight:bold; ">
		<span class=displayspan style="width: 100%; text-align: left; background-color:#ddefef;">Résultat au '.($date_balance_select || '').' : 
		'.$style_resultat3.'
		</li>' ;

		$compte_list .= $perte_gain_provisoire unless ( $@ ) ;
		
		$content .= '<div class="wrapper-balance"><ul class=wrapper>' . $compte_list . '</ul></div>' ;
		
	} else {
		$content .= Base::Site::util::generate_error_message('
		*** Aucune information à afficher ***
		<br><br>
		<a class=nav href="journal?configuration">Ajouter des journaux</a>
		<br>
		<a class=nav href="compte?configuration">Ajouter des comptes</a>
		<p>Ajouter des écritures</p>') ;
	}

	return $content ;
    }
    
} #sub balance

#/*—————————————— Export PDF Complet balance ——————————————*/
sub export_pdf_balance {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	
	# PDF
	my $pdf = PDF::API2->new;

	#$pdf->mediabox('A4'); => Format A4
	$pdf->mediabox(595, 842);
	#format A4 paysage landscape
	#$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 40;
	my $page_bottom_margin = 40;
	my $page_left_margin = 40;
	my $page_right_margin = 40;
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
	my $line_width_basic = 1;
	my $line_width_bold = 2;
	
	# Ajout Page depuis template
	my $page = _add_pdf_page_balance( $r, $args , $pdf);

	# Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor($color_black);
	$text->fillcolor($color_black);
	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 4.5;
	my $cur_row_left = 7;
	my $cur_row_right = 7;
	my $cur_row_middle = 0.5;


		# Save the position of the thick line under the quotation heading
		my $header_bottom_line_row = $cur_row;
		
		my $cur_column_units_count = 0;
		
		#espace en tête
		my $colonne_1_count = 14;
		my $colonne_1_name = 'N° de compte';
		my $colonne_2_count = 38;
		my $colonne_2_name = 'Intitulé du compte';
		my $colonne_3_count = 12;
		my $colonne_3_name = 'Cumul débit';
		my $colonne_4_count = 12;
		my $colonne_4_name = 'Cumul crédit';
		my $colonne_5_count = 12;
		my $colonne_5_name = 'Solde débit';
		my $colonne_6_count = 12;
		my $colonne_6_name = 'Solde crédit';
		
	
	# Generate content object for text
	my $font_size = 11;
	$text->font($font, $font_size);
	my $text_height = $font_size;

	my ($books, $content, $varbalance) ;
	
	#####################################       
	# Manipulation des dates			#
	#####################################  
	my $date = localtime->strftime('%d/%m/%Y');
	my $date_entry = $args->{balance} || $r->pnotes('session')->{Exercice_fin_YMD};
    
    ##Mise en forme de la date dans $args->{balance} de %Y-%m-%d vers 2000-02-29
	my $date_balance_select = eval {Time::Piece->strptime($date_entry, "%Y-%m-%d")->dmy("/")};
	
    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }

	my $date_balance_select2 = eval {
    my $datetemp = Time::Piece->strptime($date_entry, "%Y-%m-%d");
    
    # Tableau des noms des mois en français
    my @mois = (
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    );

    # Formatage de la date en utilisant les valeurs obtenues
    my $datej = sprintf("%d %s %d", $datetemp->mday, $mois[$datetemp->mon - 1], $datetemp->year);

    $datej; # Retourner la date formatée
	};
	
    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

    #liste des comptes avec les calculs de soldes
	#il faut ajouter le format que l'on souhaite pour l'affichage web à @bind_array
	push @bind_array, 'FM999999999990D00' ;
	
	if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$sql = 'select * from calcul_balance_cloture(?, ?, ?, ?, ?, ?) WHERE solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\'';
	} else {
	$sql = 'select * from calcul_balance(?, ?, ?, ?, ?, ?) WHERE solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\'';
	}
	
	my $result_set = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => datadumper 1' . Data::Dumper::Dumper($result_set) . ' ');
			
    $cur_row ++;
    
    # définition des variables
	my ( $grand_total_debit, $grand_total_credit, $grand_total_debit_solde, $grand_total_credit_solde, $first_class, $current_class, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $classe, $book, $test, $classe_solde_line, $tot_classe_6, $tot_classe_7, $tot_perte_129, $tot_gain_119)  = ( '', '' ) ;
	my $max_rows_per_page = 49;
	my $count = scalar @$result_set;
    my $row_index = 0;
    my $row_alterne = 0;
	my $rows_on_page = 0;
	my $current_page = 1;
	my $is_last_record = 0; # Variable pour suivre si c'est le dernier enregistrement


    ############## RÉCUPÉRATION DU RÉSULTAT DE LA REQUÊTE ##############


		while (my $book = shift @$result_set) {
			my $frais_montant;
			my $class = $book->{classe};
			
			# Ajouter une nouvelle page si le nombre de lignes dépasse $max_rows_per_page
			if ($rows_on_page > $max_rows_per_page) {
				$current_page++;
				$rows_on_page = 0;
				$row_alterne = 0;
				$cur_row--;
				dessiner_lignes($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black);

				# Si ce n'est pas la première page, ajouter une nouvelle page
				if ($current_page != 1) {
					my $page = _add_pdf_page_balance($r, $args, $pdf);
					$gfx = $page->gfx;  # Objets graphiques
					$text = $page->text; # Objets texte
					$text->strokecolor($color_black); # Couleur texte noir par défaut
					$text->fillcolor($color_black);
					# Ligne de départ LEFT RIGHT MIDDLE
					$cur_row = 5.5;
					$cur_row_left = 7;
					$cur_row_right = 7;
					$cur_row_middle = 0.5;
					$cur_column_units_count = 0;
				}
			}
			
			# Si la classe a changé, afficher le total pour la classe précédente
			if (defined $current_class && defined $class && $current_class ne $class && $current_class ne '') {
				afficher_total_classe($text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $text, $book, $current_class, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_3_count, $colonne_4_count, $colonne_5_count, $colonne_6_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_bold, $font_size_tableau);
				$cur_row ++;
				$rows_on_page++;
				$row_index++;
				$count++;
				$row_alterne = 0;
				# Ajouter une nouvelle page si le nombre de lignes dépasse $max_rows_per_page
				if ($rows_on_page > $max_rows_per_page) {
					$current_page++;
					$rows_on_page = 0;
					$row_alterne = 0;
					$cur_row--;
					dessiner_lignes($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black);
					# Si ce n'est pas la première page, ajouter une nouvelle page
					if ($current_page != 1) {
						my $page = _add_pdf_page_balance($r, $args, $pdf);
						$gfx = $page->gfx;  # Objets graphiques
						$text = $page->text; # Objets texte
						$text->strokecolor($color_black); # Couleur texte noir par défaut
						$text->fillcolor($color_black);
						# Ligne de départ LEFT RIGHT MIDDLE
						$cur_row = 5.5;
						$cur_row_left = 7;
						$cur_row_right = 7;
						$cur_row_middle = 0.5;
						$cur_column_units_count = 0;
					}
				}
			}
			
			# Appliquer la mise en forme pour chaque enregistrement
			# ...
			
			# Les lignes sont peintes en alternance
			if ($row_alterne % 2 == 1) {
				$gfx->rectxy(
					$render_start_x+0.5,
					$render_start_y - $unit_height * $cur_row,
					$render_end_x-0.5,
					$render_start_y - $unit_height * ($cur_row - 1)
				);
				$gfx->fillcolor('#eee');
				$gfx->fill;
			} 
			
			# $book->{numero_compte}
			if ($book->{numero_compte}) {
				$text->translate(
				  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text($book->{numero_compte});
			}
			$cur_column_units_count += $colonne_1_count;

			# $args->{libelle_compte}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{libelle_compte}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book->{libelle_compte} || ''), 0, 47));
			}
			$cur_column_units_count += $colonne_2_count;

			# $book->{debit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{debit} && $book->{debit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_3_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s', formater_nombre($book->{debit})));
			}
			$cur_column_units_count += $colonne_3_count;

			# $book->{credit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{credit} && $book->{credit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_4_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s',formater_nombre($book->{credit})));
			}
			$cur_column_units_count += $colonne_4_count;

			# $book->{solde_debit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{solde_debit} && $book->{solde_debit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_5_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s', formater_nombre($book->{solde_debit})));
			}
			$cur_column_units_count += $colonne_5_count;

			# $book->{solde_credit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{solde_credit} && $book->{solde_credit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_6_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s',formater_nombre($book->{solde_credit})));
			}
			
			$cur_column_units_count = 0;
			  
			$cur_row ++;
			
		# Calcul du solde des comptes de classe
        my $classe_solde_debit_solde = '' ;
		my $classe_solde_credit_solde = '';
		my $classe_total_debit_solde ;
		my $classe_total_credit_solde;
		if (exists $book->{classe_total_debit_solde}) {
		my $classe_total_debit_solde = $book->{classe_total_debit_solde};
			$classe_total_debit_solde =~ s/[^a-zA-Z0-9]//g;
		}
		if (exists $book->{classe_total_debit_solde}) {
		$classe_total_credit_solde = $book->{classe_total_credit_solde};
			$classe_total_credit_solde =~ s/[^a-zA-Z0-9]//g;
		}
		my $classe_solde_debit_temp = ($classe_total_debit_solde || 0) - ($classe_total_credit_solde || 0);
		my $classe_solde_credit_temp = ($classe_total_credit_solde || 0) - ($classe_total_debit_solde || 0) ;
		
		# Mise en forme des résultats
		if ($classe_solde_debit_temp > $classe_solde_credit_temp) {
		($classe_solde_debit_solde = sprintf( "%.2f",$classe_solde_debit_temp/100)) =~ s/\./\,/g;
		$classe_solde_debit_solde =~ s/\B(?=(...)*$)/ /g ;
		$classe_solde_credit_solde = '&nbsp' ;
		} 
		if ($classe_solde_debit_temp < $classe_solde_credit_temp){
		($classe_solde_credit_solde = sprintf( "%.2f",$classe_solde_credit_temp/100)) =~ s/\./\,/g ;
		$classe_solde_credit_solde =~ s/\B(?=(...)*$)/ /g ;
		$classe_solde_debit_solde = '&nbsp' ;
		}
		
		# Mettre à jour la classe actuelle
		$classe_total_debit = $book->{classe_total_debit};
		$classe_total_credit = $book->{classe_total_credit};
		$classe_total_debit_solde_dif = $book->{classe_total_debit_solde_dif};
		$classe_total_credit_solde_dif = $book->{classe_total_credit_solde_dif};
		
		if ( $book->{classe} =~ /6/) { 
		($tot_classe_6 = $book->{classe_total_debit_solde_dif}) =~ s/[^a-zA-Z0-9]//g;
		}
		
		if ( $book->{classe} =~ /7/) { 
		($tot_classe_7 = $book->{classe_total_credit_solde_dif}) =~ s/[^a-zA-Z0-9]//g;
		}
		
		#affichage Total Balance
		$grand_total_debit = $book->{grand_total_debit} || '0,00' ;
		$grand_total_credit = $book->{grand_total_credit} || '0,00' ;
		$grand_total_debit_solde = $book->{grand_total_debit_solde} || '0,00' ;
		$grand_total_credit_solde = $book->{grand_total_credit_solde} || '0,00' ;
		
		# récupération du solde des comptes de cloture
		if (substr( $book->{numero_compte}, 0, 3 ) =~ /129/ ) {
		$tot_perte_129 = $book->{solde_debit} ;
		} 
		if ((substr( $book->{numero_compte}, 0, 3 ) =~ /119/) ) {
		$tot_gain_119 = $book->{solde_credit} ;
		} 

		# Mettre à jour les variables de classe actuelles
		$current_class = $class;
		$rows_on_page++;
		$row_index++;
		$row_alterne++;
		
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => $row_index ' . ($row_index || 0) . ' et $count ' . ($count || 0));

		# Vérifier si c'est le dernier enregistrement
		if ($row_index == $count) {
			$is_last_record = 1;
		}
		
	}
	
		# Vérifier si c'est le dernier enregistrement
		if ($is_last_record && $rows_on_page > 0) {
			#!!! Ajouter le total de la dernière classe !!!#
			afficher_total_classe($text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $text, $book, $current_class, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_3_count, $colonne_4_count, $colonne_5_count, $colonne_6_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_bold, $font_size_tableau);
			$cur_row++;
			$rows_on_page++;
			$row_index++;
			$count++;
			

			#!!! Ajouter le total de la balance !!!#
			# Ligne TOP en tête
			# background 1ère Ligne Decoration en tête
			$gfx->rectxy(
				$render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
				$render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
			);
			$gfx->fillcolor('#808080');
			$gfx->fill;

			# 1ère Ligne Decoration en tête
			$gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
			$gfx->hline($render_end_x);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;

			# Total classe
			$text->translate($render_start_x + $cur_column_units_count * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
			$text->font($font_bold, $font_size_tableau);
			$text->text('Total Balance');
			$cur_column_units_count += 52;

			my @column_counts = ($colonne_3_count, $colonne_4_count, $colonne_5_count, $colonne_6_count);
			my @totals = ($grand_total_debit, $grand_total_credit, $grand_total_debit_solde, $grand_total_credit_solde);

			for (my $i = 0; $i < scalar(@column_counts); $i++) {
				$gfx->poly(
					$render_start_x + $cur_column_units_count * $unit_width,
					$render_start_y - $unit_height * $cur_row,
					$render_start_x + $cur_column_units_count * $unit_width,
					$render_start_y - $unit_height * ($cur_row - 1)
				);
				$gfx->linewidth($line_width_basic);
				$gfx->strokecolor($color_black);
				$gfx->stroke;

				if ($totals[$i] && $totals[$i] ne '0,00') {
					$text->translate(
						$render_start_x + $cur_column_units_count * $unit_width + ($column_counts[$i] * $unit_width) - $text_left_padding,
						$render_start_y - $unit_height * $cur_row + $text_bottom_padding
					);
					$text->font($font_bold, $font_size_tableau);
					# Aligner la chaîne de caractères avec des zéros à gauche
					$text->text_right(sprintf('%15s', formater_nombre($totals[$i])));
				}

				$cur_column_units_count += $column_counts[$i];
			}

			$cur_column_units_count = 0;

			# 1ère Ligne Decoration en tête
			$gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
			$gfx->hline($render_end_x);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;

			$cur_row++;
			
			#!!! Ajouter le Calcul du résultat comptable !!!#
		
			my $desc_resultat;
			# Calcul de l'expression en tenant compte de la possibilité de valeurs non définies
			my $total_pain_gain = (defined($tot_classe_7) ? ($tot_classe_7 / 100) : 0) - (defined($tot_classe_6) ? ($tot_classe_6 / 100) : 0);
		
			if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
				if (defined $tot_perte_129 && ($tot_perte_129 =~/\d/) && $tot_perte_129 ne '0,00') {
					$total_pain_gain = $tot_perte_129 ;
					$desc_resultat = 'Perte de ';
				} else {
					if (defined $tot_gain_119 && ($tot_gain_119 =~/\d/) && $tot_gain_119 ne '0,00') {
						$total_pain_gain = $tot_gain_119 ;	 
						$desc_resultat = 'Bénéfice de ';
					} else {
						if ($total_pain_gain > 0) {
							$desc_resultat = 'Bénéfice de ';
						} elsif ($total_pain_gain < 0) {
							$total_pain_gain = $total_pain_gain * -1;	
							$desc_resultat = 'Perte de ';
						} 
					}
				}	
			} else {
				if ($total_pain_gain > 0 ) {
					$desc_resultat = 'Bénéfice de ';
				} elsif ($total_pain_gain < 0 ) {
					$total_pain_gain = $total_pain_gain * -1;	
					$desc_resultat = 'Perte de ';
				} 
			}
	
			$total_pain_gain = formater_nombre($total_pain_gain) ;

			#affichage du résultat comptable
			my $perte_gain_provisoire  = 'Résultat au '.($date_balance_select2 || '').' : '. ($desc_resultat || '') .' ' . $total_pain_gain . ' Euros' ;

			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => $tot_classe_6 ' . ($tot_classe_6 || 0) . ' et $tot_classe_7 ' . ($tot_classe_7 || 0) .' et $total_pain_gain ' . ($total_pain_gain || 0).' et ::: ' . ($perte_gain_provisoire || 0));
			
			# Ligne TOP en tête
			# background 1ère Ligne Decoration en tête
			$gfx->rectxy(
				$render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
				$render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
			);
			$gfx->fillcolor('#808080');
			$gfx->fill;

			# 1ère Ligne Decoration en tête
			$gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
			$gfx->hline($render_end_x);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;

			# Total classe
			$text->translate($render_start_x + $cur_column_units_count * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
			$text->font($font_bold, $font_size_tableau);
			$text->text(''.$perte_gain_provisoire.'');
			$cur_column_units_count += 52;		
			
			# 1ère Ligne Decoration en tête
			$gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
			$gfx->hline($render_end_x);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			
			dessiner_lignes($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black);

		}
		
	# HEADER ET FOOTER
	foreach my $pagenum (1 .. $pdf->pages) {
		my $page = $pdf->openpage($pagenum);
		my $font = $pdf->corefont('Helvetica');

		# détection format de la page
		(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;

		# Calcul des coordonnées du milieu bas de la page
		my $middle_x = ($urx + $llx) / 2;
		my $middle_y = $lly + 20;  # Décalage de 20 unités vers le haut

		# count nb pages
		my $totalpages = $pdf->pages;

		# add page number text
		my $txt = $page->text;
		$txt->strokecolor('#000000');
		$txt->font($font, 8);
		$txt->translate($middle_x, $middle_y);
		$txt->text_center('- ' . $pagenum . ' / ' . $totalpages . ' -');
	}

	# Sauvegarde du PDF
	my $file = '/Compta/images/pdf/print.pdf';
	my $pdf_file = $r->document_root() . $file;
	$pdf->saveas($pdf_file);

	return $file ;
	
}#sub export_pdf_balance 

#/*—————————————— Modéle page balance ——————————————*/
sub _add_pdf_page_balance {
	# définition des variables
	my ( $r, $args, $pdf ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $varbalance ) ;
	my $date = localtime->strftime('%d/%m/%Y');
	
	#Titre impression de la balance
    if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$varbalance = 'de Clôture';
	} else {
	$varbalance = 'Générale';
	}
	
	# Obtention de la date actuelle
	my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
	$year += 1900; # Ajout de 1900 pour obtenir l'année correcte
	$mon += 1; # Ajout de 1 au mois car les mois sont indexés à partir de 0

	# Tableau des noms des mois en français
	my @mois = (
		'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
		'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
	);

	# Formatage de la date en utilisant les valeurs obtenues
	my $datej = sprintf("%d %s %d", $mday, $mois[$mon - 1], $year);

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper($args) . ' ');

    ############## Récupérations d'informations ##############
    #Récupérations des informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
	
    #$pdf->mediabox('A4'); => Format A4
	$pdf->mediabox(595, 842);
	#format A4 paysage landscape
	#$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 40;
	my $page_bottom_margin = 40;
	my $page_left_margin = 40;
	my $page_right_margin = 40;
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
	
	# Color list
	my $color_black = '#000';

	# Line width
	my $line_width_basic = 1;
	my $line_width_bold = 2;
	
	
    my $page = $pdf->page();
    
    # Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor('#000');
	$text->fillcolor('#000');

	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 13;
	my $cur_row_left = 1.25;
	my $cur_row_right = 1.25;
	my $cur_row_middle = 0.5;
	
	# Dessiner la ligne supérieure
	$gfx->move($render_start_x-0.5, $render_start_y-0.5);
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_basic);
	# Rendre la couleur de la ligne un peu plus claire que le noir
	$gfx->strokecolor($color_black);
	$gfx->stroke;

	############## INFO SOCIETE DROITE ##############
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Balance '.$varbalance .' éditée le '.$datej.'');
	$cur_row_right += 1;
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Exercice : '.$r->pnotes('session')->{Exercice_debut_DMY}.' - '.$r->pnotes('session')->{Exercice_fin_DMY}.'');
	$cur_row_right += 1;
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Montant exprimé en euros');
	$cur_row_right += 1;

	
	############## INFO SOCIETE DROITE ##############

	############## INFO SOCIETE GAUCHE ##############
	# etablissement
	my $sender_company_name = ''.$parametre_set->[0]->{etablissement} . '';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font_bold, $font_size_default);
	$text->text($sender_company_name);
	$cur_row_left += 1;
	# Adresse
	my $sender_addr = '' . ($parametre_set->[0]->{adresse_1} || '') . '';
	my $sender_zip_code = '' . ($parametre_set->[0]->{code_postal} || ''). ' ' . ($parametre_set->[0]->{ville} || '').'';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_addr.' - '.$sender_zip_code);
	$cur_row_left += 1;
	# Siret
	my $sender_siret = 'SIRET : ' . $parametre_set->[0]->{siret} . '';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_siret);
	$cur_row_left += 3;
	############## INFO SOCIETE GAUCHE ##############


	# Ligne de départ LEFT RIHT MIDDLE
	$cur_row = 3.5;
	$cur_row_left = 7;
	$cur_row_right = 7;
	$cur_row_middle = 0.5;


		# Save the position of the thick line under the quotation heading
		my $header_bottom_line_row = $cur_row;

		# Ligne TOP en tête
		# background 1ère Ligne Decoration en tête
		$gfx->rectxy(
		  $render_start_x, $render_start_y-$unit_height * $cur_row,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row + 1)
		);
		$gfx->fillcolor('#b2b2b2');
		$gfx->fill;
		
		# 1ère Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_basic);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row += 1;
		
		my $cur_column_units_count = 0;
		
		#espace en tête
		my $colonne_1_count = 14;
		my $colonne_1_name = 'N° de compte';
		my $colonne_2_count = 38;
		my $colonne_2_name = 'Intitulé du compte';
		my $colonne_3_count = 12;
		my $colonne_3_name = 'Cumul débit';
		my $colonne_4_count = 12;
		my $colonne_4_name = 'Cumul crédit';
		my $colonne_5_count = 12;
		my $colonne_5_name = 'Solde débit';
		my $colonne_6_count = 12;
		my $colonne_6_name = 'Solde crédit';
		############## ENTÊTE TABLEAU ##############
		# colonne_1_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_1_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_1_name);
		$cur_column_units_count += $colonne_1_count;
		# colonne_2_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_2_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_2_name);
		$cur_column_units_count += $colonne_2_count;
		# colonne_3_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_3_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_3_name);
		$cur_column_units_count += $colonne_3_count;
		# colonne_4_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_4_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_4_name);
		$cur_column_units_count += $colonne_4_count;
		# colonne_5_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_5_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_5_name);
		$cur_column_units_count += $colonne_5_count;
		# colonne_6_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_6_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_6_name);
		$cur_column_units_count = 0;
		############## ENTÊTE TABLEAU ##############
		
		# 2ème Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * ($cur_row));
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_basic);
		$gfx->strokecolor($color_black);
		$gfx->stroke;

    return $page;
}#sub _add_pdf_page_balance

#/*—————————————— Template total classe balance ——————————————*/
sub afficher_total_classe {
    my ($text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $text, $book, $current_class, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_3_count, $colonne_4_count, $colonne_5_count, $colonne_6_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_bold, $font_size_tableau) = @_;

    my @column_counts = ($colonne_3_count, $colonne_4_count, $colonne_5_count, $colonne_6_count);
    my @totals = ($classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif);

    # Ligne TOP en tête
    # background 1ère Ligne Decoration en tête
    $gfx->rectxy(
        $render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
        $render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
    );
    $gfx->fillcolor('#b2b2b2');
    $gfx->fill;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    # Total classe
    $text->translate($render_start_x + $cur_column_units_count * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
    $text->font($font_bold, $font_size_tableau);
    $text->text("Total des comptes de classe $current_class");
    $cur_column_units_count += 52;

    for (my $i = 0; $i < scalar(@column_counts); $i++) {
        $gfx->poly(
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * $cur_row,
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * ($cur_row - 1)
        );
        $gfx->linewidth($line_width_basic);
        $gfx->strokecolor($color_black);
        $gfx->stroke;

        if ($totals[$i] && $totals[$i] ne '0,00') {
            $text->translate(
                $render_start_x + $cur_column_units_count * $unit_width + ($column_counts[$i] * $unit_width) - $text_left_padding,
                $render_start_y - $unit_height * $cur_row + $text_bottom_padding
            );
            $text->font($font_bold, $font_size_tableau);
            # Aligner la chaîne de caractères avec des zéros à gauche
            $text->text_right(sprintf('%15s', formater_nombre($totals[$i])));
        }

        $cur_column_units_count += $column_counts[$i];
    }

    $cur_column_units_count = 0;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    $cur_row++;
}

#/*—————————————— Export PDF Complet grandlivre ——————————————*/
sub export_pdf_grandlivre {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array ) ;
	
	# PDF
	my $pdf = PDF::API2->new;

	#$pdf->mediabox('A4'); => Format A4
	#$pdf->mediabox(595, 842);
	#format A4 paysage landscape
	$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 40;
	my $page_bottom_margin = 40;
	my $page_left_margin = 40;
	my $page_right_margin = 40;
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
	my $line_width_basic = 1;
	my $line_width_bold = 2;
	
	# Ajout Page depuis template
	my $page = _add_pdf_page_grandlivre( $r, $args , $pdf);

	# Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor($color_black);
	$text->fillcolor($color_black);
	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 4.5;
	my $cur_row_left = 7;
	my $cur_row_right = 7;
	my $cur_row_middle = 0.5;


		# Save the position of the thick line under the quotation heading
		my $header_bottom_line_row = $cur_row;
		
		my $cur_column_units_count = 0;
		
		#espace en tête
		my $colonne_1_count = 7;
		my $colonne_1_name = 'Date';
		my $colonne_2_count = 9;
		my $colonne_2_name = 'Journal';
		my $colonne_3_count = 11;
		my $colonne_3_name = 'Pièce';
		my $colonne_4_count = 34;
		my $colonne_4_name = 'Libellé';
		my $colonne_5_count = 8.5;
		my $colonne_5_name = 'Débit';
		my $colonne_6_count = 8.5;
		my $colonne_6_name = 'Crédit';
		my $colonne_7_count = 8.5;
		my $colonne_7_name = 'Solde débit';
		my $colonne_8_count = 8.5;
		my $colonne_8_name = 'Solde crédit';
		my $colonne_9_count = 5;
		my $colonne_9_name = 'L';
		
	
	# Generate content object for text
	my $font_size = 11;
	$text->font($font, $font_size);
	my $text_height = $font_size;

	my $books ;
	my $content ;
	
	#####################################       
	# Manipulation des dates			#
	#####################################  

	my $date = localtime->strftime('%d/%m/%Y');
	my $date_entry = $args->{grandlivre} || $r->pnotes('session')->{Exercice_fin_YMD};
    
	##Mise en forme de la date dans $args->{grandlivre} de %Y-%m-%d vers 2000-02-29
	my $date_grandlivre_select = eval {Time::Piece->strptime($date_entry, "%Y-%m-%d")->dmy("/")};
	
	my $date_grandlivre_select2 = eval {
    my $datetemp = Time::Piece->strptime($date_entry, "%Y-%m-%d");
    
    # Tableau des noms des mois en français
    my @mois = (
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    );

    # Formatage de la date en utilisant les valeurs obtenues
    my $datej = sprintf("%d %s %d", $datetemp->mday, $mois[$datetemp->mon - 1], $datetemp->year);

    $datej; # Retourner la date formatée
	};

    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }
    
    #appliquer le filtre => Classe
    my ($filter_classe_dest) = (  defined $args->{classe} && $args->{classe} ne '' ) ? ' AND substring(numero_compte from 1 for 1) = ?' : '' ;
    #appliquer le filtre => ecriture de clôture
	my $display_ecriture_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? '' : 'AND libelle_journal NOT LIKE \'%CLOTURE%\'' ;
    
		$sql = '
		SELECT t1.date_ecriture, t1.libelle_journal, t1.id_facture, t1.libelle, t1.lettrage, t1.numero_compte, 
			   CASE WHEN t1.debit - t1.credit >= 0 THEN to_char(t1.debit/100::numeric, \'FM999999999990D00\') ELSE \'0.00\' END as debit,
			   CASE WHEN t1.credit - t1.debit >= 0 THEN to_char(t1.credit/100::numeric, \'FM999999999990D00\') ELSE \'0.00\' END as credit,
			   CASE WHEN SUM(t1.debit - t1.credit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line) >= 0
					THEN to_char(SUM(t1.debit - t1.credit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line)/100::numeric, \'FM999999999990D00\')
					ELSE \'0.00\' END as total_debit,
			   CASE WHEN SUM(t1.credit - t1.debit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line) >= 0
					THEN to_char(SUM(t1.credit - t1.debit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line)/100::numeric, \'FM999999999990D00\')
					ELSE \'0.00\' END as total_credit,
			   cb.debit AS cb_debit, cb.classe_total_credit_solde_dif AS cb_classe_total_credit_solde_dif, cb.classe_total_debit_solde_dif AS cb_classe_total_debit_solde_dif, cb.grand_total_debit AS cb_grand_total_debit, cb.grand_total_credit AS cb_grand_total_credit, cb.grand_total_debit_solde AS cb_grand_total_debit_solde, cb.grand_total_credit_solde AS cb_grand_total_credit_solde, cb.libelle_compte AS libelle_compte, cb.classe AS classe, cb.credit AS cb_credit, cb.solde_debit AS cb_solde_debit, cb.solde_credit AS cb_solde_credit, cb.classe_total_debit AS cb_classe_total_debit, cb.classe_total_credit AS cb_classe_total_credit, cb.classe_total_debit_solde AS cb_classe_total_debit_solde, cb.classe_total_credit_solde AS cb_classe_total_credit_solde
		FROM (
		  SELECT t1.*, SUM(debit) OVER (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle, id_line) as total_debit,
						SUM(credit) OVER (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle, id_line) as total_credit
		  FROM tbljournal t1
		  WHERE t1.id_client = ? AND t1.fiscal_year = ? AND date_ecriture <= ? '.$filter_classe_dest.' '.$display_ecriture_cloture.'
		) t1
		LEFT JOIN tblexport t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.id_export = t2.id_export
		LEFT JOIN tbljournal_liste t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t1.libelle_journal = t4.libelle_journal
		LEFT JOIN calcul_balance_cloture(?, ?, ?, ?, ?, \'FM999999999990D00\') cb ON t1.numero_compte = cb.numero_compte
		ORDER BY t1.numero_compte, t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line;
		' ;	 

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;	
	
	# Vérification de $args->{classe} et ajout à @bind_array si présent et non vide
	if (defined $args->{classe} && $args->{classe} ne '') {
		my $index = 3;  # Index où insérer $args->{classe} dans @bind_array
		splice(@bind_array, $index, 0, $args->{classe});
	}
	
	my $result_set = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => datadumper 1' . Data::Dumper::Dumper($result_set) . ' ');
			
    $cur_row ++;
    
    # définition des variables
	my ( $libcompte, $grand_total_debit, $grand_total_credit, $grand_total_debit_solde, $grand_total_credit_solde, $first_class, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $classe, $compte, $book, $test, $classe_solde_line, $tot_classe_6, $tot_classe_7, $tot_perte_129, $tot_gain_119)  = ( '', '' ) ;
	my ($current_libcompte, $current_compte, $current_classe) = ('', '', '');
	my $max_rows_per_page = 31;
	my $count = scalar @$result_set;
    my $row_index = 0;
    my $row_alterne = 0;
	my $rows_on_page = 0;
	my $current_page = 1;
	my $is_last_record = 0; # Variable pour suivre si c'est le dernier enregistrement
	
	# Initialisation des variables de totaux
	my ($cb_classe_total_debit, $cb_classe_total_credit, $cb_classe_total_credit_solde_dif, $cb_classe_total_debit_solde_dif, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $cb_grand_total_debit, $cb_grand_total_credit, $cb_grand_total_debit_solde, $cb_grand_total_credit_solde ) = (0, 0, 0, 0);
	
	
    ############## RÉCUPÉRATION DU RÉSULTAT DE LA REQUÊTE ##############
	#date_ecriture	libelle_journal	id_facture	libelle	lettrage	numero_compte	debit	credit	total_debit	total_credit	cb_debit	cb_credit	cb_solde_debit	cb_solde_credit	cb_classe_total_debit	cb_classe_total_credit	cb_classe_total_debit_solde	cb_classe_total_credit_solde

		while (my $book = shift @$result_set) {
			my $frais_montant;
			my $classe = $book->{classe};
			my $compte = $book->{numero_compte};
			my $libcompte = $book->{libelle_compte};
			
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);

			# Si la compte a changé, afficher le total pour la compte précédent
			if (defined $current_compte && defined $compte && $current_compte ne $compte && $current_compte ne '') {
				afficher_total_compte($current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
				$cur_row ++;
				$rows_on_page++;
				$row_index++;
				$count++;
				$row_alterne = 0;
				
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);

			}
			
			# Si la classe a changé, afficher le total pour la classe précédente
			if (defined $current_classe && defined $classe && $current_classe ne $classe && $current_classe ne '') {
				afficher_total_classe_grandlivre($cb_classe_total_debit, $cb_classe_total_credit, $cb_classe_total_credit_solde_dif, $cb_classe_total_debit_solde_dif, $current_classe, $current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
				$cur_row ++;
				$rows_on_page++;
				$row_index++;
				$count++;
				$row_alterne = 0;
				
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);

			}
			
			# Afficher le titre pour une nouvelle classe
            if ($classe ne $current_classe) {
                $current_classe = $classe;
                afficher_titre_classe($current_classe, $classe, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
				$cur_row ++;
				$rows_on_page++;
				$row_index++;
				$count++;
				$row_alterne = 0;
				
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);

			 }
			
			# Afficher le titre pour un nouveau compte
            if ($compte ne $current_compte) {
                $current_compte = $compte;
                $current_libcompte = $libcompte;
                afficher_titre_compte($current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
				$cur_row ++;
				$rows_on_page++;
				$row_index++;
				$count++;
				$row_alterne = 0;
				
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);

			 }

			# Appliquer la mise en forme pour chaque enregistrement
			# ...
			
			# Les lignes sont peintes en alternance
			if ($row_alterne % 2 == 1) {
				$gfx->rectxy(
					$render_start_x+0.5,
					$render_start_y - $unit_height * $cur_row,
					$render_end_x-0.5,
					$render_start_y - $unit_height * ($cur_row - 1)
				);
				$gfx->fillcolor('#eee');
				$gfx->fill;
			} 
			
			# $book->{date_ecriture}
			if ($book->{date_ecriture}) {
				$text->translate(
				  $render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				  $render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text($book->{date_ecriture});
			}
			$cur_column_units_count += $colonne_1_count;

			# $args->{libelle_journal}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{libelle_journal}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book->{libelle_journal} || ''), 0, 10));
			}
			$cur_column_units_count += $colonne_2_count;
			
			# $args->{id_facture}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{id_facture}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book->{id_facture} || ''), 0, 15));
			}
			$cur_column_units_count += $colonne_3_count;
			
			# $args->{libelle}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{libelle}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book->{libelle} || ''), 0, 58));
			}
			$cur_column_units_count += $colonne_4_count;

			# $book->{debit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{debit} && $book->{debit} ne '0.00' && $book->{debit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_5_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s', formater_nombre($book->{debit})));
			}
			$cur_column_units_count += $colonne_5_count;

			# $book->{credit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{credit} && $book->{credit} ne '0.00' && $book->{credit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_6_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s',formater_nombre($book->{credit})));
			}
			$cur_column_units_count += $colonne_6_count;

			# $book->{total_debit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{total_debit} && $book->{total_debit} ne '0.00' && $book->{total_debit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_7_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s', formater_nombre($book->{total_debit})));
			}
			$cur_column_units_count += $colonne_7_count;

			# $book->{total_credit}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{total_credit} && $book->{total_credit} ne '0.00' && $book->{total_credit} ne '0,00') {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + ($colonne_8_count * $unit_width)-$text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				# Aligner la chaîne de caractères avec des zéros à gauche
				$text->text_right(sprintf('%15s',formater_nombre($book->{total_credit})));
			}
			$cur_column_units_count += $colonne_8_count;
			
			# $args->{lettrage}
			$gfx->poly(
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * $cur_row,
			$render_start_x + $cur_column_units_count * $unit_width,
			$render_start_y-$unit_height * ($cur_row - 1)
			);
			$gfx->linewidth($line_width_basic);
			$gfx->strokecolor($color_black);
			$gfx->stroke;
			if ($book->{lettrage}) {
				$text->translate(
				$render_start_x + $cur_column_units_count * $unit_width + $text_left_padding,
				$render_start_y-$unit_height * $cur_row + $text_bottom_padding
				);
				$text->font($font, $font_size_tableau);
				$text->text(substr(($book->{lettrage} || ''), 0, 10));
			}
			$cur_column_units_count = 0;
			  
			$cur_row ++;
			
		$cb_debit = $book->{cb_debit};
		$cb_credit = $book->{cb_credit};
		$cb_solde_debit = $book->{cb_solde_debit};
		$cb_solde_credit = $book->{cb_solde_credit};
		$cb_grand_total_debit = $book->{cb_grand_total_debit};
		$cb_grand_total_credit = $book->{cb_grand_total_credit};
		$cb_grand_total_debit_solde = $book->{cb_grand_total_debit_solde};
		$cb_grand_total_credit_solde = $book->{cb_grand_total_credit_solde};
		$cb_classe_total_debit = $book->{cb_classe_total_debit};
		$cb_classe_total_credit = $book->{cb_classe_total_credit};
		$cb_classe_total_credit_solde_dif = $book->{cb_classe_total_credit_solde_dif};
		$cb_classe_total_debit_solde_dif = $book->{cb_classe_total_debit_solde_dif};

		# Mettre à jour les variables de classe actuelles
		$current_classe = $classe;
		$current_compte = $compte;
		$current_libcompte = $libcompte;
		$rows_on_page++;
		$row_index++;
		$row_alterne++;
		
		#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'compte.pm => $row_index ' . ($row_index || 0) . ' et $count ' . ($count || 0));

		# Vérifier si c'est le dernier enregistrement
		if ($row_index == $count) {
			$is_last_record = 1;
		}
		
	}
	
		# Vérifier si c'est le dernier enregistrement
		if ($is_last_record && $rows_on_page > 0) {
			
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);
			
			#!!! Ajouter le total du dernier compte !!!#
			afficher_total_compte($current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
			$cur_row++;
			$rows_on_page++;
			$row_index++;
			$count++;
			
			# check_ajout_nouvelle_page et récupération des nouvelles valeurs
			($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);
			
			#!!! Ajouter le total de la dernière classe !!!#
			afficher_total_classe_grandlivre($cb_classe_total_debit, $cb_classe_total_credit, $cb_classe_total_credit_solde_dif, $cb_classe_total_debit_solde_dif, $current_classe, $current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau);
			$cur_row ++;
			$rows_on_page++;
			$row_index++;
			$count++;
			
			if (defined $args->{classe} && $args->{classe} ne '') {
				$cur_row = $cur_row -1 ;
			} else {
				
				# check_ajout_nouvelle_page et récupération des nouvelles valeurs
				($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $page) = check_ajout_nouvelle_page($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text);
			
				#!!! Ajouter le Total Grand Livre !!!#
				# Ligne TOP en tête
				# background 1ère Ligne Decoration en tête
				$gfx->rectxy(
					$render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
					$render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
				);
				$gfx->fillcolor('#808080');
				$gfx->fill;

				# 1ère Ligne Decoration en tête
				$gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
				$gfx->hline($render_end_x);
				$gfx->linewidth($line_width_basic);
				$gfx->strokecolor($color_black);
				$gfx->stroke;

				# Total classe
				$text->translate($render_start_x + $cur_column_units_count * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
				$text->font($font_bold, 11); # 11 pour font size
				$text->text('Total Grand Livre');
				$cur_column_units_count += 61;

				my @column_counts = ($colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count);
				my @totals = ($cb_grand_total_debit, $cb_grand_total_credit, $cb_grand_total_debit_solde, $cb_grand_total_credit_solde);

				for (my $i = 0; $i < scalar(@column_counts); $i++) {
					$gfx->poly(
						$render_start_x + $cur_column_units_count * $unit_width,
						$render_start_y - $unit_height * $cur_row,
						$render_start_x + $cur_column_units_count * $unit_width,
						$render_start_y - $unit_height * ($cur_row - 1)
					);
					$gfx->linewidth($line_width_basic);
					$gfx->strokecolor($color_black);
					$gfx->stroke;

					if ($totals[$i] && $totals[$i] ne '0,00') {
						$text->translate(
							$render_start_x + $cur_column_units_count * $unit_width + ($column_counts[$i] * $unit_width) - $text_left_padding,
							$render_start_y - $unit_height * $cur_row + $text_bottom_padding
						);
						$text->font($font_bold, $font_size_tableau);
						# Aligner la chaîne de caractères avec des zéros à gauche
						$text->text_right(sprintf('%15s', formater_nombre($totals[$i])));
					}

					$cur_column_units_count += $column_counts[$i];
				}	
			
				$cur_column_units_count = 0;
			}
			
			dessiner_lignes($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black);
			
			

		}
		
	# HEADER ET FOOTER
	foreach my $pagenum (1 .. $pdf->pages) {
		my $page = $pdf->openpage($pagenum);
		my $font = $pdf->corefont('Helvetica');

		# détection format de la page
		(my $llx, my $lly, my $urx, my $ury) = $page->get_mediabox;

		# Calcul des coordonnées du milieu bas de la page
		my $middle_x = ($urx + $llx) / 2;
		my $middle_y = $lly + 20;  # Décalage de 20 unités vers le haut

		# count nb pages
		my $totalpages = $pdf->pages;

		# add page number text
		my $txt = $page->text;
		$txt->strokecolor('#000000');
		$txt->font($font, 8);
		$txt->translate($middle_x, $middle_y);
		$txt->text_center('- ' . $pagenum . ' / ' . $totalpages . ' -');
	}

	# Sauvegarde du PDF
	my $file = '/Compta/images/pdf/print.pdf';
	my $pdf_file = $r->document_root() . $file;
	$pdf->saveas($pdf_file);

	return $file ;
	
}#sub export_pdf_grandlivre 

#/*—————————————— Modéle page grandlivre ——————————————*/
sub _add_pdf_page_grandlivre {
	# définition des variables
	my ( $r, $args, $pdf ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $vargrandlivre ) ;
	my $date = localtime->strftime('%d/%m/%Y');
	
	#Titre impression du grand livre
    if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$vargrandlivre = 'de Clôture';
	} else {
	$vargrandlivre = 'Général';
	}
	
	# Obtention de la date actuelle
	my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
	$year += 1900; # Ajout de 1900 pour obtenir l'année correcte
	$mon += 1; # Ajout de 1 au mois car les mois sont indexés à partir de 0

	# Tableau des noms des mois en français
	my @mois = (
		'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
		'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
	);

	# Formatage de la date en utilisant les valeurs obtenues
	my $datej = sprintf("%d %s %d", $mday, $mois[$mon - 1], $year);

	#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => datadumper : ' . Data::Dumper::Dumper($args) . ' ');

    ############## Récupérations d'informations ##############
    #Récupérations des informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
	
    #$pdf->mediabox('A4'); => Format A4
	#$pdf->mediabox(595, 842);
	#format A4 paysage landscape
	$pdf->mediabox(842, 595);
	# Get paper size
	my @page_size_infos = $pdf->mediabox;
	my $page_width = $page_size_infos[2];
	my $page_height = $page_size_infos[3];
	# Page margin
	my $page_top_margin = 40;
	my $page_bottom_margin = 40;
	my $page_left_margin = 40;
	my $page_right_margin = 40;
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
	
	# Color list
	my $color_black = '#000';

	# Line width
	my $line_width_basic = 1;
	my $line_width_bold = 2;
	
	
    my $page = $pdf->page();
    
    # Graphic drawing
	my $gfx = $page->gfx;
	# Text drawing
	my $text = $page->text;
	#Couleur texte noir par default
	$text->strokecolor('#000');
	$text->fillcolor('#000');

	# Ligne de départ LEFT RIHT MIDDLE
	my $cur_row = 13;
	my $cur_row_left = 1.25;
	my $cur_row_right = 1.25;
	my $cur_row_middle = 0.5;
	
	# Dessiner la ligne supérieure
	$gfx->move($render_start_x-0.5, $render_start_y-0.5);
	$gfx->hline($render_end_x);
	$gfx->linewidth($line_width_basic);
	# Rendre la couleur de la ligne un peu plus claire que le noir
	$gfx->strokecolor($color_black);
	$gfx->stroke;

	############## INFO SOCIETE DROITE ##############
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Grand Livre '.$vargrandlivre.' édité le '.$datej.'');
	$cur_row_right += 1;
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Exercice : '.$r->pnotes('session')->{Exercice_debut_DMY}.' - '.$r->pnotes('session')->{Exercice_fin_DMY}.'');
	$cur_row_right += 1;
	$text->translate($render_end_x-5, $render_start_y-$unit_height * $cur_row_right + $text_bottom_padding);
	$text->font($font, $font_size_default);
	$text->text_right('Montant exprimé en euros');
	$cur_row_right += 1;

	
	############## INFO SOCIETE DROITE ##############

	############## INFO SOCIETE GAUCHE ##############
	# etablissement
	my $sender_company_name = ''.$parametre_set->[0]->{etablissement} . '';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font_bold, $font_size_default);
	$text->text($sender_company_name);
	$cur_row_left += 1;
	# Adresse
	my $sender_addr = '' . ($parametre_set->[0]->{adresse_1} || '') . '';
	my $sender_zip_code = '' . ($parametre_set->[0]->{code_postal} || ''). ' ' . ($parametre_set->[0]->{ville} || '').'';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_addr.' - '.$sender_zip_code);
	$cur_row_left += 1;
	# Siret
	my $sender_siret = 'SIRET : ' . $parametre_set->[0]->{siret} . '';
	$text->translate(
	  $render_start_x+5, $render_start_y-$unit_height * $cur_row_left + $text_bottom_padding
	);
	$text->font($font, $font_size_default);
	$text->text($sender_siret);
	$cur_row_left += 3;
	############## INFO SOCIETE GAUCHE ##############


	# Ligne de départ LEFT RIHT MIDDLE
	$cur_row = 3.5;
	$cur_row_left = 7;
	$cur_row_right = 7;
	$cur_row_middle = 0.5;


		# Save the position of the thick line under the quotation heading
		my $header_bottom_line_row = $cur_row;

		# Ligne TOP en tête
		# background 1ère Ligne Decoration en tête
		$gfx->rectxy(
		  $render_start_x, $render_start_y-$unit_height * $cur_row,
		  $render_end_x, $render_start_y-$unit_height * ($cur_row + 1)
		);
		$gfx->fillcolor('#b2b2b2');
		$gfx->fill;
		
		# 1ère Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * $cur_row);
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_basic);
		$gfx->strokecolor($color_black);
		$gfx->stroke;
		$cur_row += 1;
		
		my $cur_column_units_count = 0;
		
		#espace en tête
		my $colonne_1_count = 7;
		my $colonne_1_name = 'Date';
		my $colonne_2_count = 9;
		my $colonne_2_name = 'Journal';
		my $colonne_3_count = 11;
		my $colonne_3_name = 'Pièce';
		my $colonne_4_count = 34;
		my $colonne_4_name = 'Libellé';
		my $colonne_5_count = 8.5;
		my $colonne_5_name = 'Débit';
		my $colonne_6_count = 8.5;
		my $colonne_6_name = 'Crédit';
		my $colonne_7_count = 8.5;
		my $colonne_7_name = 'Solde débit';
		my $colonne_8_count = 8.5;
		my $colonne_8_name = 'Solde crédit';
		my $colonne_9_count = 5;
		my $colonne_9_name = 'L';
		
		############## ENTÊTE TABLEAU ##############
		# colonne_1_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_1_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_1_name);
		$cur_column_units_count += $colonne_1_count;
		# colonne_2_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_2_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_2_name);
		$cur_column_units_count += $colonne_2_count;
		# colonne_3_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_3_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_3_name);
		$cur_column_units_count += $colonne_3_count;
		# colonne_4_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_4_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_4_name);
		$cur_column_units_count += $colonne_4_count;
		# colonne_5_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_5_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_5_name);
		$cur_column_units_count += $colonne_5_count;
		# colonne_6_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_6_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_6_name);
		$cur_column_units_count += $colonne_6_count;
		# colonne_7_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_7_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_7_name);
		$cur_column_units_count += $colonne_7_count;
		# colonne_8_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_8_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_8_name);
		$cur_column_units_count += $colonne_8_count;
		# colonne_9_count
		$text->translate($render_start_x + $cur_column_units_count * $unit_width + ($colonne_9_count * $unit_width/2), $render_start_y-$unit_height * $cur_row + $text_bottom_padding);
		$text->font($font_bold, $font_size_tableau);
		$text->text_center($colonne_9_name);
		$cur_column_units_count = 0;
		############## ENTÊTE TABLEAU ##############
		
		# 2ème Ligne Decoration en tête 
		$gfx->move($render_start_x, $render_start_y-$unit_height * ($cur_row));
		$gfx->hline($render_end_x);
		$gfx->linewidth($line_width_basic);
		$gfx->strokecolor($color_black);
		$gfx->stroke;

    return $page;
}#sub _add_pdf_page_grandlivre

#/*—————————————— Template total compte grandlivre ——————————————*/
sub afficher_total_compte {
    my ($current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau) = @_;

    my @column_counts = ($colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count);
    my @totals = ($cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit);
    
    # Ligne TOP en tête
    # background 1ère Ligne Decoration en tête
    $gfx->rectxy(
        $render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
        $render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
    );
    $gfx->fillcolor('#eee');  # Couleur blanche pour le remplissage
    $gfx->fill;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    # Total compte
    $text->translate($render_start_x + ($cur_column_units_count+1) * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
    $text->font($font_bold, $font_size_tableau);
    $text->text("Total du compte $current_compte - $current_libcompte");
    $cur_column_units_count += 61;

    for (my $i = 0; $i < scalar(@column_counts); $i++) {
        $gfx->poly(
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * $cur_row,
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * ($cur_row - 1)
        );
        $gfx->linewidth($line_width_basic);
        $gfx->strokecolor($color_black);
        $gfx->stroke;

        if ($totals[$i] && $totals[$i] ne '0,00') {
            $text->translate(
                $render_start_x + $cur_column_units_count * $unit_width + ($column_counts[$i] * $unit_width) - $text_left_padding,
                $render_start_y - $unit_height * $cur_row + $text_bottom_padding
            );
            $text->font($font_bold, $font_size_tableau);
            # Aligner la chaîne de caractères avec des zéros à gauche
            $text->text_right(sprintf('%15s', formater_nombre($totals[$i])));
        }

        $cur_column_units_count += $column_counts[$i];
    }

    $cur_column_units_count = 0;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    $cur_row++;
}

#/*—————————————— Template titre compte grandlivre ——————————————*/
sub afficher_titre_compte {
    my ($current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau) = @_;

    # Ligne TOP en tête
    # background 1ère Ligne Decoration en tête
    $gfx->rectxy(
        $render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
        $render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
    );
    $gfx->fillcolor('#b2b2b2');
    $gfx->fill;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    # Titre compte
    $text->translate($render_start_x + ($cur_column_units_count+1) * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
    $text->font($font_bold, $font_size_tableau);
    $text->text("$current_compte - $current_libcompte");

    $cur_column_units_count = 0;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    $cur_row++;
}

#/*—————————————— Template titre classe grandlivre ——————————————*/
sub afficher_titre_classe {
    my ($current_classe, $classe, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau) = @_;
	
		my $lib_titre_classe = ''; 
	
		if ($current_classe eq 1) {
		$lib_titre_classe .= 'CLASSE 1 - COMPTES DE CAPITAUX' ;
		} elsif ($current_classe eq 2) {
		$lib_titre_classe .= 'CLASSE 2 - COMPTES D\'IMMOBILISATIONS' ;	
		} elsif ($current_classe eq 3) {
		$lib_titre_classe .= 'CLASSE 3 - COMPTES DE STOCKS' ;	
		} elsif ($current_classe eq 4) {
		$lib_titre_classe .= 'CLASSE 4 - COMPTES DE TIERS' ;	
		} elsif ($current_classe eq 5) {
		$lib_titre_classe .= 'CLASSE 5 - COMPTES FINANCIERS' ;		
		} elsif ($current_classe eq 6) {
		$lib_titre_classe .= 'CLASSE 6 - COMPTES DE CHARGES' ;		
		} elsif ($current_classe eq 7) {
		$lib_titre_classe .= 'CLASSE 7 - COMPTES DE PRODUITS' ;		
		}
		
    # Ligne TOP en tête
    # background 1ère Ligne Decoration en tête
    $gfx->rectxy(
        $render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
        $render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
    );
    $gfx->fillcolor('#b2b2b2');
    $gfx->fill;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    # Titre compte
    $text->translate($render_start_x + ($cur_column_units_count+1) * $unit_width + $text_left_padding, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
    $text->font($font_bold, $font_size_tableau);
    $text->text("$lib_titre_classe");

    $cur_column_units_count = 0;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    $cur_row++;
}

#/*—————————————— Template total classe grandlivre ——————————————*/
sub afficher_total_classe_grandlivre {
    my ($cb_classe_total_debit, $cb_classe_total_credit, $cb_classe_total_credit_solde_dif, $cb_classe_total_debit_solde_dif, $current_classe, $current_page, $current_libcompte, $cb_debit, $cb_credit, $cb_solde_debit, $cb_solde_credit, $text_left_padding, $rows_on_page, $gfx, $render_end_x, $line_width_basic, $color_black, $font_bold, $text, $book, $current_compte, $classe_total_debit, $classe_total_credit, $classe_total_debit_solde_dif, $classe_total_credit_solde_dif, $colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count, $render_start_x, $render_start_y, $cur_row, $cur_column_units_count, $unit_width, $unit_height, $text_bottom_padding, $font_size_tableau) = @_;

    my @column_counts = ($colonne_5_count, $colonne_6_count, $colonne_7_count, $colonne_8_count, $colonne_9_count);
    my @totals = ($cb_classe_total_debit, $cb_classe_total_credit, $cb_classe_total_debit_solde_dif, $cb_classe_total_credit_solde_dif);

    # Ligne TOP en tête
    # background 1ère Ligne Decoration en tête
    $gfx->rectxy(
        $render_start_x + 0.6, $render_start_y - $unit_height * ($cur_row - 1),
        $render_end_x - 0.6, $render_start_y - $unit_height * ($cur_row)
    );
    $gfx->fillcolor('#808080');
    $gfx->fill;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * ($cur_row - 1));
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    # Total classe
    $text->translate($render_end_x-350, $render_start_y - $unit_height * $cur_row + $text_bottom_padding);
    $text->font($font_bold, 11); # 11 pour font size
    $text->text_right("Total classe $current_classe");
    $cur_column_units_count += 61;

    for (my $i = 0; $i < scalar(@column_counts); $i++) {
        $gfx->poly(
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * $cur_row,
            $render_start_x + $cur_column_units_count * $unit_width,
            $render_start_y - $unit_height * ($cur_row - 1)
        );
        $gfx->linewidth($line_width_basic);
        $gfx->strokecolor($color_black);
        $gfx->stroke;

        if ($totals[$i] && $totals[$i] ne '0,00') {
            $text->translate(
                $render_start_x + $cur_column_units_count * $unit_width + ($column_counts[$i] * $unit_width) - $text_left_padding,
                $render_start_y - $unit_height * $cur_row + $text_bottom_padding
            );
            $text->font($font_bold, $font_size_tableau);
            # Aligner la chaîne de caractères avec des zéros à gauche
            $text->text_right(sprintf('%15s', formater_nombre($totals[$i])));
        }

        $cur_column_units_count += $column_counts[$i];
    }

    $cur_column_units_count = 0;

    # 1ère Ligne Decoration en tête
    $gfx->move($render_start_x, $render_start_y - $unit_height * $cur_row);
    $gfx->hline($render_end_x);
    $gfx->linewidth($line_width_basic);
    $gfx->strokecolor($color_black);
    $gfx->stroke;

    $cur_row++;
}

#/*—————————————— Template ligne fin document ——————————————*/
sub dessiner_lignes {
    my ($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black) = @_;

	# Dessiner la ligne inférieure après la dernière ligne d'un enregistrement
	$gfx->move($render_start_x - 0.5, $render_start_y - $unit_height * $cur_row);
	$gfx->hline($render_end_x + 0.5);
	$gfx->linewidth($line_width_basic);
				
	# Dessiner la ligne à droite
	$gfx->move($render_end_x, $render_start_y);
	$gfx->line($render_end_x, $render_start_y - $unit_height * $cur_row);
	$gfx->linewidth($line_width_basic);
		
	# Dessiner la ligne à gauche
	$gfx->move($render_start_x, $render_start_y);
	$gfx->line($render_start_x, $render_start_y - $unit_height * $cur_row);
	$gfx->linewidth($line_width_basic);
		
	# Rendre la couleur de la ligne un peu plus claire que le noir
	$gfx->strokecolor($color_black);
	$gfx->stroke;
	
}

#/*—————————————— Fonction vérification besoin ajout page ——————————————*/
sub check_ajout_nouvelle_page {
    my ($current_page, $rows_on_page, $row_index, $count, $row_alterne, $cur_row_left, $cur_row_right, $cur_row_middle, $cur_column_units_count, $gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black, $max_rows_per_page, $r, $args, $pdf, $text) = @_;

    # Ajouter une nouvelle page si le nombre de lignes dépasse $max_rows_per_page
    if ($rows_on_page > $max_rows_per_page) {
        $current_page++;
        $rows_on_page = 0;
        $row_alterne = 0;
        $cur_row--;

        dessiner_lignes($gfx, $render_start_x, $render_start_y, $render_end_x, $cur_row, $unit_height, $line_width_basic, $color_black);

        # Si ce n'est pas la première page, ajouter une nouvelle page
        if ($current_page != 1) {
            my $new_page = _add_pdf_page_grandlivre($r, $args, $pdf);
            $gfx = $new_page->gfx;  # Objets graphiques
            $text = $new_page->text; # Objets texte
            $text->strokecolor($color_black); # Couleur texte noir par défaut
            $text->fillcolor($color_black);
            # Ligne de départ LEFT RIGHT MIDDLE
            $cur_row = 5.5;
            $cur_row_left = 7;
            $cur_row_right = 7;
            $cur_row_middle = 0.5;
            $cur_column_units_count = 0;

            return ($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text, $new_page);  # Retourner les nouvelles valeurs et la nouvelle page
        }
    }

    return ($current_page, $rows_on_page, $row_alterne, $cur_row, $gfx, $text);  # Retourner les valeurs inchangées
}

#/*—————————————— Fonction split array ——————————————*/
sub split_by {
	my ($num, @arr) = @_;
	my @sub_arrays;

	while (@arr) {
		push(@sub_arrays, [splice @arr, 0, $num]);
	}

	return @sub_arrays;
}#sub split_by

#/*—————————————— Module grandlivre ——————————————*/
sub grandlivre {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array ) ;
    my $date = localtime->strftime('%d/%m/%Y');
	my $content ;
	
	################ Affichage MENU ################
    $content .= display_menu_compte( $r, $args ) ;
	################ Affichage MENU ################
	
    #Récupérations des informations de la société
    my $parametre_set = Base::Site::bdd::get_info_societe($dbh, $r);
	  
	#l'utilisateur a cliqué sur le bouton 'Imprimer'
	if ( defined $args->{grandlivre} && defined $args->{imprimer}) {
		
		my $location = export_pdf_grandlivre( $r, $args );
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
	  
#####################################       
# Manipulation des dates			#
#####################################  
	
    my $date_entry = $args->{grandlivre} || $r->pnotes('session')->{Exercice_fin_YMD};
    
    ##Mise en forme de la date dans $args->{balance} de %Y-%m-%d vers 2000-02-29
	my $date_grandlivre_select = eval {Time::Piece->strptime($date_entry, "%Y-%m-%d")->dmy("/")};
	
    #on affiche un message d'erreur si la date fournie est incompréhensible
    if ( $@ ) {
	if ( $@ =~ /type date/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} elsif  ( $@ =~ /parsing time/ ) {
	    $content = Base::Site::util::generate_error_message('Mauvaise date : ' . $date_entry . '') ;
	} else {
	    $content = Base::Site::util::generate_error_message($@) ;
	}
    }
    
#####################################       
# Préparation à l'impression		#
##################################### 

	$content .= '
		<div class="printable">
		<div style="float: left ">
		<address><strong>'.$parametre_set->[0]->{etablissement} . '</strong><br>
		' . ($parametre_set->[0]->{adresse_1} || '') . ' <br> ' . ($parametre_set->[0]->{code_postal} || '') . ' ' . ($parametre_set->[0]->{ville} || '') .'<br>
		SIRET : ' . $parametre_set->[0]->{siret} . '<br>
		</address></div>
		<div style="float: right; text-align: right;">
		Imprimé le ' . $date . '<br>
		<div>
		Exercice du '.$r->pnotes('session')->{Exercice_debut_DMY}.' 
		</div>
		au '.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>
		</div>
		<div style="width: 100%; text-align: center;"><h1>Grand livre au '.($date_grandlivre_select|| '').'</h1>
		<div >
		Etat exprimé en Euros</div>
		</div></div>' ;

    #les 5 premiers paramètres dont on a besoin pour la fonction calcul_balance dans postgresql
    #sont placés tout de suite dans @bind_array; le 6ème paramètre (le format désiré pour les chiffres
    #selon qu'on affiche le résultat à l'écran ou qu'on l'écrit dans un fichier à télécharger)
    #est ajouté plus bas
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	
	#gestion des options
	my $checked = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? 'checked' : '' ;
	
	#gestion des filtres classe
	my $var_input_classe = ( defined $args->{classe} && $args->{classe} ne '') ? '<input class="inputtest" type=hidden name=classe id=classe value="' . $args->{classe} . '">' : '' ;
	my $bdd_filter_classe = ( defined $args->{classe} && $args->{classe} ne '') ? 'classe = \''.$args->{classe}.'\' AND (' : '' ;
	my $bdd_filter_classe_end = ( defined $args->{classe} && $args->{classe} ne '' ) ? ')' : '' ;
	
	################ Affichage MENU ################
    $content .= display_classe_compte( $r, $args ) ;
	################ Affichage MENU ################
	
	#formulaire date + options
	$content .= '
	<div style="padding-bottom: 3px" class="non-printable">
	<form action="/'.$r->pnotes('session')->{racine}.'/compte">
	<label style="font-weight: bold; text-align: right; color: #5f6368;pointer-events: none;" for="grandlivre">Grand livre au </label>
	<input class=linav type="date" name=grandlivre id=grandlivre value="' . $date_entry . '" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')">
	</td><input class=linav type=submit value=Valider>
	<input class=linav type=button value="Options..." style="" onclick="showButtons();">
	<input style="vertical-align: middle !important; margin-left: 2ch;" type="checkbox" id="ecriture_cloture" name="ecriture_cloture" title="Tenir compte des écritures de clôture" value="1" '.$checked.'>
	<label style="font-weight: normal; text-align: right;" for="ecriture_cloture" id="ecriture_cloture_label">Tenir compte des écritures de clôture</label>
	<td style="margin-left: 2ch;">
	</form></div>' ;
	
	#liste des comptes avec les calculs de soldes
	#il faut ajouter le format que l'on souhaite pour l'affichage web à @bind_array
	push @bind_array, 'FM999999999990D00' ;
	
	#
	if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
	$sql = 'select * from calcul_balance_cloture(?, ?, ?, ?, ?, ?) WHERE '.$bdd_filter_classe.' solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\''.$bdd_filter_classe_end.'';
	} else {
	$sql = 'select * from calcul_balance(?, ?, ?, ?, ?, ?) WHERE '.$bdd_filter_classe.' solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\''.$bdd_filter_classe_end.'';
	}
	
	my $compte_set ;

	#à ce stade, la date de calcul de la balance a été formatée en iso
	eval { $compte_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	
	if ( $@ ) {
	    if ( $@ =~ / date/ ) {
		#erreur de date; dans ce cas, ne pas afficher le lien de téléchargement
		$content .= '<h3 class=warning>Date non valide : ' . $date_entry. '</h3>' ;
	    } else {
		$content .= '<h3 class=warning>' . $@ . '</h3>' ;
	    }
	} #    if ( $@ ) 

	#définition des variables
	my ( $filter_classe_dest, $compte_list, $classe, $numero_compte, $classe_solde_line, $tot_classe_6, $tot_classe_7, $tot_perte_129, $tot_gain_119, $classe_compte_line)  = ( '', '' ) ;

	#########################################	
	#compte_set - Début						#
	#########################################	

	for ( @$compte_set ) {

	#appliquer le filtre => Classe
    my ($filter_classe_dest) = (  defined $args->{classe} && $args->{classe} ne '') ? ' AND substring(numero_compte from 1 for 1) = ?' : '' ;
    #appliquer le filtre => ecriture de clôture
	my $display_ecriture_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1' ) ? '' : 'AND libelle_journal NOT LIKE \'%CLOTURE%\'' ;
    
	my $sql = '

		SELECT t1.date_ecriture, t2.date_validation, t1.id_entry, t1.libelle_journal, t1.id_facture, t1.libelle, t1.lettrage, t1.numero_compte, coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture, coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1, coalesce(t1.documents2, \'&nbsp;\') as documents2, lettrage, pointage ,
			   CASE WHEN t1.debit - t1.credit >= 0 THEN to_char(t1.debit/100::numeric, \'FM999999999990D00\') ELSE \'0.00\' END as debit,
			   CASE WHEN t1.credit - t1.debit >= 0 THEN to_char(t1.credit/100::numeric, \'FM999999999990D00\') ELSE \'0.00\' END as credit,
			   CASE WHEN SUM(t1.debit - t1.credit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line) >= 0
					THEN to_char(SUM(t1.debit - t1.credit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line)/100::numeric, \'FM999999999990D00\')
					ELSE \'0,00\' END as total_debit,
			   CASE WHEN SUM(t1.credit - t1.debit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line) >= 0
					THEN to_char(SUM(t1.credit - t1.debit) OVER (PARTITION BY t1.numero_compte ORDER BY t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line)/100::numeric, \'FM999999999990D00\')
					ELSE \'0,00\' END as total_credit,
			   cb.debit AS cb_debit, cb.classe_total_credit_solde_dif AS cb_classe_total_credit_solde_dif, cb.classe_total_debit_solde_dif AS cb_classe_total_debit_solde_dif, cb.grand_total_debit AS cb_grand_total_debit, cb.grand_total_credit AS cb_grand_total_credit, cb.grand_total_debit_solde AS cb_grand_total_debit_solde, cb.grand_total_credit_solde AS cb_grand_total_credit_solde, cb.libelle_compte AS libelle_compte, cb.classe AS classe, cb.credit AS cb_credit, cb.solde_debit AS cb_solde_debit, cb.solde_credit AS cb_solde_credit, cb.classe_total_debit AS cb_classe_total_debit, cb.classe_total_credit AS cb_classe_total_credit, cb.classe_total_debit_solde AS cb_classe_total_debit_solde, cb.classe_total_credit_solde AS cb_classe_total_credit_solde
		FROM (
		  SELECT t1.*, SUM(debit) OVER (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle, id_line) as total_debit,
						SUM(credit) OVER (PARTITION BY numero_compte ORDER BY date_ecriture, id_facture, libelle, id_line) as total_credit
		  FROM tbljournal t1
		  WHERE t1.id_client = ? AND t1.fiscal_year = ? AND date_ecriture <= ? AND numero_compte = ? '.$display_ecriture_cloture.'
		) t1
		LEFT JOIN tblexport t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.id_export = t2.id_export
		LEFT JOIN tbljournal_liste t4 ON t1.id_client = t4.id_client AND t1.fiscal_year = t4.fiscal_year AND t1.libelle_journal = t4.libelle_journal
		LEFT JOIN calcul_balance(?, ?, ?, ?, ?, \'FM999999999990D00\') cb ON t1.numero_compte = cb.numero_compte
		ORDER BY t1.numero_compte, t1.date_ecriture, t1.id_facture, t1.libelle, t1.id_line;
	' ;	  
	
		my $classe_href = '/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&amp;classe=' . $_->{classe} ;
		
		#entête $compte_colonne
		my $compte_colonne = '
			<li class=headerspan2><div class=spacer></div>
			<span class=headerspan style="width: 8%;">Date</span>
			<span class=headerspan style="width: 8%;">Journal</span>
			<span class=headerspan style="width: 12%;">Pièce</span>
			<span class=headerspan style="width: 28.5%;">Libellé</span>
			<span class=headerspan style="width: 8.5%; text-align: right;">Débit</span>
			<span class=headerspan style="width: 8.5%; text-align: right;">Crédit</span>
			<span class=headerspan style="width: 8.5%; text-align: right;">Solde Débit</span>
			<span class=headerspan style="width: 8.5%; text-align: right;">Solde Crédit</span>
			<span class=headerspan style="width: 1.2%; text-align: center;">&nbsp;</span>
			<span class=headerspan style="width: 1.2%; text-align: center;">&nbsp;</span>
			<span class=headerspan style="width: 1.2%; text-align: center;">&nbsp;</span>
			<span class=headerspan style="width: 2.7%; text-align: center;">L</span>
			<span class=headerspan style="width: 1.2%; text-align: center;">P</span>
			<span class=headerspan style="width: 1.2%; text-align: center;">V</span>
			<div class=spacer></div></li>
			' ;
	
	    #lien vers le contenu du compte
	    my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?classe='. $_->{classe} . '&amp;numero_compte=' . URI::Escape::uri_escape_utf8( $_->{numero_compte} ) ;
		
		#colonne total compte
		my $totalcompte_colonne = '
		<li class="totalcompte listitem3"><div class=spacer></div>
		<a href="' . $compte_href . '">
		<span class=blockspan style="width: 56.5%;text-align: left;">Total Compte ' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">'.(($_->{debit} ne '0.00' && $_->{debit} ne '0,00') ? formater_nombre($_->{debit}) : '&nbsp;') . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">'.(($_->{credit} ne '0.00' && $_->{credit} ne '0,00') ? formater_nombre($_->{credit}) : '&nbsp;') . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">'.(($_->{solde_debit} ne '0.00' && $_->{solde_debit} ne '0,00') ? formater_nombre($_->{solde_debit}) : '&nbsp;') . '</span>
		<span class=blockspan style="width: 8.5%; text-align: right;">'.(($_->{solde_credit} ne '0.00' && $_->{solde_credit} ne '0,00') ? formater_nombre($_->{solde_credit}) : '&nbsp;') . '</span>
		</a></li>' ;
		
		#entête libellé colonne
		my $libcompte_colonne = '<li class="compte listitem3"><div class=flex-table><div class=spacer></div><a href="' . $compte_href . '">
	  	<span class=blockspan style="width: 56.5%;">Compte ' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '</span>
	  	<span class=blockspan style="width: 33%;">&nbsp;</span>
	  	</a><div class=spacer></div></div></li>' ;

		unless (defined $classe && $_->{classe} eq $classe)  {
			
		if ( defined $classe_solde_line ) {
			$compte_list .= $classe_solde_line ;
			}	
		
		if ($_->{classe} eq 1) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 1 - COMPTES DE CAPITAUX</span></a><div class=spacer></div></div></li>' ;
		} elsif ($_->{classe} eq 2) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 2 - COMPTES D\'IMMOBILISATIONS</span></a><div class=spacer></div></div></li>' ;	
		} elsif ($_->{classe} eq 3) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 3 - COMPTES DE STOCKS</span></a><div class=spacer></div></div></li>' ;	
		} elsif ($_->{classe} eq 4) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 4 - COMPTES DE TIERS</span></a><div class=spacer></div></div></li>' ;	
		} elsif ($_->{classe} eq 5) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 5 - COMPTES FINANCIERS</span></a><div class=spacer></div></div></li>' ;		
		} elsif ($_->{classe} eq 6) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 6 - COMPTES DE CHARGES</span></a><div class=spacer></div></div></li>' ;		
		} elsif ($_->{classe} eq 7) {
		$compte_list .= '<li class="style1"><div class=flex-table><div class=spacer></div><a href="' . $classe_href . '"><span class=classenum>CLASSE 7 - COMPTES DE PRODUITS</span></a><div class=spacer></div></div></li>' ;		
		}
		
		$compte_list .= $compte_colonne ;
	    } 

	    #afficher le numero de compte si on change de compte
	    unless ( defined $numero_compte && $_->{numero_compte} eq $numero_compte ) {
		#lien vers le contenu du compte
	    $compte_list .= $libcompte_colonne;
		$numero_compte = $_->{numero_compte} ;
	    } #    for ( @$numero_compte_set ) 
	    
		$classe = $_->{classe} ;

	
#########################################	

	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $numero_compte , $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $date_entry, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;	
	my $result_set = eval {$dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) } ;
	my $detail_list = '';
	
	for ( @$result_set ) {
	my $http_link_ecriture_valide = '<img class="redimmage nav" title="Validée le '. (defined $_->{date_validation}).'" style="border: 0;" src="/Compta/style/icons/cadena.png" alt="valide">' ;
	
	my $ecriture_validee = (defined $_->{date_validation} eq '') ? '' : '<img class="redimmage nav" title="Validée le '. $_->{date_validation}.'" src="/Compta/style/icons/cadena.png" alt="valide">';
	
	my $http_link_documents1 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents1}, 1);
	my $http_link_documents2 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents2}, 2);
		
	#lien vers le formulaire d'édition de l'entrée considérée
	my $journal_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . URI::Escape::uri_escape_utf8( $_->{id_entry} ) ;
	my $pointage_value = ( $_->{pointage} eq 't' ) ? '<img class="redimmage nav" title="Check complet" src="/Compta/style/icons/icone-valider.png" alt="valide">' : '' ;
			
	$compte_list .= '
<li class="displayspan2 listitem3"><div class=flex-table><div class=spacer></div><a href="' . $journal_href . '">
<span class=blockspan style="width: 8%;">' . $_->{date_ecriture} . '</span>
<span class=blockspan style="width: 8%;">' . $_->{libelle_journal} .'</span>
</a>
<span class=blockspan style="width: 12%;">' . $_->{id_facture} . '</span>
<a href="' . $journal_href . '">
<span class=blockspan style="width: 28.5%;">' . $_->{libelle} . '</span>
<span class=blockspan style="width: 8.5%; text-align: right;">' . (($_->{debit} && $_->{debit} ne '0.00' && $_->{debit} ne '0,00') ? formater_nombre($_->{debit}) : '&nbsp;') . '</span>
<span class=blockspan style="width: 8.5%; text-align: right;">' . (($_->{credit} && $_->{credit} ne '0.00' && $_->{credit} ne '0,00') ? formater_nombre($_->{credit}) : '&nbsp;') . '</span>
<span class=blockspan style="width: 8.5%; text-align: right;">' . (($_->{total_debit} && $_->{total_debit} ne '0.00' && $_->{total_debit} ne '0,00' ) ? formater_nombre($_->{total_debit}) : '&nbsp;') . '</span>
<span class=blockspan style="width: 8.5%; text-align: right;">' . (($_->{total_credit} && $_->{total_credit} ne '0.00' && $_->{total_credit} ne '0,00' ) ? formater_nombre($_->{total_credit}) : '&nbsp;') . '</span>
</a>
<span class=blockspan style="width: 1.2%; text-align: center;">&nbsp;</span>
<span class=blockspan style="width: 1.2%; text-align: center;">' . ($http_link_documents1 || '&nbsp;' ). '</span>
<span class=blockspan style="width: 1.2%; text-align: center;">' . ($http_link_documents2 || '&nbsp;' ). '</span>
<span class=blockspan style="width: 2.7%; text-align: center;">' .( $_->{lettrage} || '&nbsp;' ) . '</span>
<span class=blockspan style="width: 1.2%; text-align: center;">' .( $pointage_value || '&nbsp;' ). '</span>
<span class=blockspan style="width: 1.2%; text-align: center;">' .( $ecriture_validee || '&nbsp;' ). '</span>
<div class=spacer></div></div></li>' ;
    } #    for ( @$result_set ) 
		
        # Calcul du solde des comptes de classe
        my $classe_solde_debit_solde = '' ;
		my $classe_solde_credit_solde = '';
		(my $classe_total_debit_solde = $_->{classe_total_debit_solde}) =~ s/[^a-zA-Z0-9]//g;
		(my $classe_total_credit_solde = $_->{classe_total_credit_solde}) =~ s/[^a-zA-Z0-9]//g;
		my $classe_solde_debit_temp = $classe_total_debit_solde - $classe_total_credit_solde;
		my $classe_solde_credit_temp = $classe_total_credit_solde - $classe_total_debit_solde ;
		
		# Mise en forme des résultats
		if ($classe_solde_debit_temp > $classe_solde_credit_temp) {
		($classe_solde_debit_solde = sprintf( "%.2f",$classe_solde_debit_temp/100)) =~ s/\./\,/g;
		$classe_solde_debit_solde =~ s/\B(?=(...)*$)/ /g ;
		$classe_solde_credit_solde = '' ;
		} 
		if ($classe_solde_debit_temp < $classe_solde_credit_temp){
		($classe_solde_credit_solde = sprintf( "%.2f",$classe_solde_credit_temp/100)) =~ s/\./\,/g ;
		$classe_solde_credit_solde =~ s/\B(?=(...)*$)/ /g ;
		$classe_solde_debit_solde = '' ;
		}
		
		if (not(substr( $_->{numero_compte}, 0, 3 ) =~ /129|119/) ) {
		# passage des résultats aux variables
		if ( $_->{classe} =~ /6/) { 
		($tot_classe_6 = $classe_solde_debit_solde) =~ s/[^a-zA-Z0-9]//g;
		}
		
		if ( $_->{classe} =~ /7/) { 
		($tot_classe_7 = $classe_solde_credit_solde) =~ s/[^a-zA-Z0-9]//g;
		}
		
		}
		
		# récupération du solde des comptes de cloture
		if (substr( $_->{numero_compte}, 0, 3 ) =~ /129/ ) {
		$tot_perte_129 = $_->{solde_debit} ;
		} 
		
		if (substr( $_->{numero_compte}, 0, 3 ) =~ /119/ ) {
		$tot_gain_119 = $_->{solde_credit} ;
		} 
		
		$compte_list .= $totalcompte_colonne;

  		$classe_solde_line = '<li class=submit2><div class=spacer></div>
		<span class=displayspan style="font-size: larger;  text-align : right; width: 56.5%;">Total classe ' . $_->{classe} . '</span>
		<span class=displayspan style="width: 8.5%; text-align: right;">' . (($_->{classe_total_debit} && $_->{classe_total_debit} ne '0.00' && $_->{classe_total_debit} ne '0,00') ? formater_nombre($_->{classe_total_debit}) : '&nbsp;') . '</span>
		<span class=displayspan style="width: 8.5%; text-align: right;">' . (($_->{classe_total_credit} && $_->{classe_total_credit} ne '0.00' && $_->{classe_total_credit} ne '0,00') ? formater_nombre($_->{classe_total_credit}) : '&nbsp;') . '</span>
		<span class=displayspan style="width: 8.5%; text-align: right;">' . (($_->{classe_total_debit_solde_dif} && $_->{classe_total_debit_solde_dif} ne '0.00' && $_->{classe_total_debit_solde_dif} ne '0,00') ? formater_nombre($_->{classe_total_debit_solde_dif}) : '&nbsp;') . '</span>
		<span class=displayspan style="width: 8.5%; text-align: right;">' . (($_->{classe_total_credit_solde_dif} && $_->{classe_total_credit_solde_dif} ne '0.00' && $_->{classe_total_credit_solde_dif} ne '0,00') ? formater_nombre($_->{classe_total_credit_solde_dif}) : '&nbsp;') . '</span>
		
		<div class=spacer></div>
		<div class=spacer></div></li>
		' ;
		
	} #    for ( @$compte_set ) {
	
	if (defined $classe_solde_line) {
	$compte_list .= $classe_solde_line ;
	}
	
	my $grand_total_line ;

	if (defined $compte_set->[0]->{grand_total_debit} != 0 || defined $compte_set->[0]->{grand_total_credit} != 0 ||
	defined $compte_set->[0]->{grand_total_debit_solde} != 0 || defined $compte_set->[0]->{grand_total_credit_solde} != 0 ){
		
	#grand_total
	my $grand_total_line = '<li class="style1">
<span class=displayspan style="width: 56.5%; text-align: right; color: black; font-weight: bold; font-size: larger;  text-align : left;">Total Grand Livre</span>
<span class=displayspan style="width: 8.5%; text-align: right; color: black; font-weight: bold;">' . ( $compte_set->[0]->{grand_total_debit} || 0 ) . '</span>
<span class=displayspan style="width: 8.5%; text-align: right; color: black; font-weight: bold;">' . ( $compte_set->[0]->{grand_total_credit} || 0 ) . '</span>
<span class=displayspan style="width: 8.5%; text-align: right; color: black; font-weight: bold;">' . ( $compte_set->[0]->{grand_total_debit_solde} || 0 ) . '</span>
<span class=displayspan style="width: 8.5%; text-align: right; color: black; font-weight: bold;">' . ( $compte_set->[0]->{grand_total_credit_solde} || 0 ) . '</span>
<span class=displayspan style="width: 15.4%;">&nbsp;</span>
<div class=spacer></div>
<div class=spacer></div></li><li class="style1"><span class=displayspan style="width: 100%;">&nbsp;</span></li>' ;


	if (not(defined $args->{classe} && $args->{classe} =~ /1|2|3|4|5|6|7/)) {
		
	
	#Calcul du résultat comptable
	my ($total_pain_gain, $colour_resultat_N, $desc_resultat);
	
	$total_pain_gain = ( $tot_classe_7 || 0) - ($tot_classe_6 || 0);
	$total_pain_gain = sprintf( "%.2f",$total_pain_gain/100) ;
	
	if (defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq 1) {
		if (defined $tot_perte_129 && ($tot_perte_129 =~/\d/) && $tot_perte_129 ne '0,00') {
		$total_pain_gain = $tot_perte_129 ;
		$colour_resultat_N = 'color: red;';
		$desc_resultat = 'Perte de ';
		} else {
			if (defined $tot_gain_119 && ($tot_gain_119 =~/\d/) && $tot_gain_119 ne '0,00') {
			$total_pain_gain = $tot_gain_119 ;	 
			$colour_resultat_N = 'color: green;';
			$desc_resultat = 'Bénéfice de ';
			} else {
			
			if ($total_pain_gain > 0) {
			$colour_resultat_N = 'color: green;';
			$desc_resultat = 'Bénéfice de ';
			} 
			elsif ($total_pain_gain < 0) {
			$total_pain_gain = $total_pain_gain * -1;	
			$colour_resultat_N = 'color: red;';
			$desc_resultat = 'Perte de ';
			} 
			
			}
		}	
	} else {
	
	if ($total_pain_gain > 0) {
	$colour_resultat_N = 'color: green;';
	$desc_resultat = 'Bénéfice de ';
	} 
	elsif ($total_pain_gain < 0) {
	$total_pain_gain = $total_pain_gain * -1;	
	$colour_resultat_N = 'color: red;';
	$desc_resultat = 'Perte de ';
	} 
	
	}
	
	$total_pain_gain =~ s/\./\,/g ;
	$total_pain_gain =~ s/\B(?=(...)*$)/ /g ;
	

	#affichage du résultat comptable
	my $perte_gain_provisoire  = '<li class="style1" style="font-weight:bold; ">
	<span class=displayspan style="width: 100%; text-align: left; background-color:#ddefef;">Résultat comptable au '.$date_grandlivre_select.': 
	<span style="'.($colour_resultat_N || '').'">'.($desc_resultat|| '').' ' . ($total_pain_gain || 0) . ' Euros</span></span>
	</li>' ;
	
	# si $@ est défini, la requête a échoué, il n'y a pas de grand total à afficher
	$compte_list .= $grand_total_line unless ( $@ ) ;
	$compte_list .= $perte_gain_provisoire unless ( $@ ) ;	
	}
	
	}
	
	unless ($compte_list ) {
		$content .= Base::Site::util::generate_error_message('
		*** Aucune information à afficher ***
		<br><br>
		<a class=nav href="journal?configuration">Ajouter des journaux</a>
		<br>
		<a class=nav href="compte?configuration">Ajouter des comptes</a>
		<p>Ajouter des écritures</p>') ;

	} else {
		$content .= '<div class="wrapper"><ul class="wrapper style1">' . $compte_list . '</ul></div>' ;
	}
	 
	return $content ;

} #sub grandlivre

#/*—————————————— Fonction Formater le nombre avec deux décimales et des séparateurs de milliers et de millions ——————————————*/
sub formater_nombre {
    my $nombre = shift;
    
    # Remplacer la virgule par un point
    $nombre =~ s/,/./g;

    # Formater le nombre avec deux décimales et des séparateurs de milliers et de millions
    my $nombre_formate = sprintf("%.2f", $nombre);
    $nombre_formate =~ s/(?<=\d)(?=(\d{3})+(?!\d))/ /g;
    if (length($nombre_formate) > 6) {
        $nombre_formate =~ s/(?<=\d{3})(?=(\d{3})+(?!\d))/,/g;
    }

    # Remplacer les points par des virgules
    $nombre_formate =~ s/\./,/g;

    return $nombre_formate;
}

#/*—————————————— Menu des classes ——————————————*/
sub display_classe_compte {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    
    unless ( defined $args->{classe}) {$args->{classe} = '' ;} 	
    unless ( defined $args->{grandlivre}) {$args->{grandlivre} = 0 ;} 
    unless ( defined $args->{ecriture_cloture}) {$args->{ecriture_cloture} = 0 ;} 
    
    my $print_href = '/'.$r->pnotes('session')->{racine}.'/compte?grandlivre='.$args->{grandlivre}.'&amp;ecriture_cloture=' . $args->{ecriture_cloture} . '&amp;classe=' . $args->{classe} . '&amp;imprimer';
	my $print_link = '<li><a class=linav href="' . $print_href . '" title="Exporter en format pdf le grand livre" >Export pdf</a></li>' ;
	
	# Préservation du filtre écriture de cloture si défini
    my $var_input_cloture = ( defined $args->{ecriture_cloture} && $args->{ecriture_cloture} eq '1') ? '&amp;ecriture_cloture=1' : '' ;
    
	# Génération dynamique des liens pour chaque classe (1 à 7) avec redirection vers 'Toutes' si la classe est déjà sélectionnée
	my $classe_links = '';
	foreach my $i (1..7) {
		my $href = (defined $args->{classe} && $args->{classe} eq $i)
			? '/'.$r->pnotes('session')->{racine}.'/compte?grandlivre='.$args->{grandlivre}.''.$var_input_cloture.''
			: '/'.$r->pnotes('session')->{racine}.'/compte?grandlivre='.$args->{grandlivre}.'&amp;classe='.$i.''.$var_input_cloture.'';
		
		$classe_links .= '<li><a class=' . ((defined $args->{classe} && $args->{classe} eq $i) ? 'linavselect' : 'linav') . ' href="' . $href . '" title="Filtrer sur les comptes de Classe '.$i.'" >Classe '.$i.'</a></li>';
	}

	#définition des liens des classes 
	my $classeall_link = '<li><a class=' . ( ($args->{grandlivre} =~ /0/ && $args->{classe} eq '') ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre='.$args->{grandlivre}.''.$var_input_cloture.'" >Toutes</a></li>' ;

	#génération du menu
	my $content .= '<div class="menuN2"><ul class="main-nav2">' . $classeall_link . $classe_links . $print_link . '</ul></div>' ;
    
    return $content ;

} #sub display_classe_compte 

#$compte_list .= generate_compte_list($r, $_->{classe});
sub generate_classe_list_content {
    my ($r, $classe) = @_;

    my %classe_labels = (
        1 => "CLASSE 1 - COMPTES DE CAPITAUX",
        2 => "CLASSE 2 - COMPTES D'IMMOBILISATIONS",
        3 => "CLASSE 3 - COMPTES DE STOCKS",
        4 => "CLASSE 4 - COMPTES DE TIERS",
        5 => "CLASSE 5 - COMPTES FINANCIERS",
        6 => "CLASSE 6 - COMPTES DE CHARGES",
        7 => "CLASSE 7 - COMPTES DE PRODUITS"
    );

    if (exists $classe_labels{$classe}) {
        return '<li class="style1"><div class=flex-table><div class=spacer></div><a href="/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0&classe='.$classe.'"><span class=classenum>' . $classe_labels{$classe} . '</span></a><div class=spacer></div></div></li>';
    }

    return '';  # Retourne une chaîne vide si la classe n'existe pas
}

#/*—————————————— Menu des comptes ——————————————*/
sub display_menu_compte {

    my ( $r, $args, $dispclasse ) = @_ ;
    $dispclasse //= 0;
    my $dbh = $r->pnotes('dbh') ;
    my $content;

	#définition des liens
	my $edit_list_class = ( defined $args->{configuration} || defined $args->{reconduire} || defined $args->{supprimer} ) ? 'linavselect' : 'linav' ;
	my $grand_livre1_class = ( defined $args->{numero_compte} ) ? 'linavselect' : 'linav' ;
	my $grand_livre2_class = ( defined $args->{grandlivre} ) ? 'linavselect' : 'linav' ;
	my $reports_class = ( defined $args->{reports} && $args->{reports} ne '') ? 'linavselect ' : 'linav' ;
	my $cloture_class = ( defined $args->{cloture} && $args->{cloture} ne '' ) ? 'linavselect' : 'linav' ;
    my $edit_list_href = '/'.$r->pnotes('session')->{racine}.'/compte?configuration' ;
    my $grand_livre1_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=0' ;
    my $grand_livre2_href = '/'.$r->pnotes('session')->{racine}.'/compte?grandlivre=0' ;
    my $cloture_href = '/'.$r->pnotes('session')->{racine}.'/compte?cloture=0' ;
    my $reports_href = '/'.$r->pnotes('session')->{racine}.'/compte?reports=0' ;
    
    my $edit_list_link = '<li><a class='.$edit_list_class.' href="' . $edit_list_href . '">Configuration</a></li>' ;
    my $grand_livre1_link = '<li><a class='.$grand_livre1_class.' href="' . $grand_livre1_href. '">Grand&nbsp;Livre V1</a></li>' ;
    my $grand_livre2_link = '<li><a class='.$grand_livre2_class.' href="' . $grand_livre2_href. '" >Grand&nbsp;Livre V2</a></li>' ;
    my $cloture_link = '<li><a class='.$cloture_class.' href="' . $cloture_href. '" >Clôture</a></li>' ;
    my $reports_link = '<li><a class='.$reports_class.' href="' . $reports_href. '" >Reports</a></li>' ;

	#génération du menu
    if ($r->pnotes('session')->{Exercice_Cloture} ne '1') {	
	$content .= '<div class="menu"><ul class="main-nav2">' . $edit_list_link . $grand_livre1_link . $grand_livre2_link . $reports_link . $cloture_link .'</ul></div>' ;
	} else {
	$content .= '<div class="menu"><ul class="main-nav2">' . $grand_livre1_link . $grand_livre2_link .'</ul></div>' ;	
	}
	
	if (defined $dispclasse && $dispclasse eq 1) {
		my $classeall_link = '<li><a class=' . ( ((defined $args->{configuration} && !defined $args->{classe}) || defined $args->{classe} && $args->{classe} eq '') ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration" >Toutes</a></li>' ;
		my $classe1_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /1/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=1" >Classe 1</a></li>' ;
		my $classe2_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /2/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=2" >Classe 2</a></li>' ;
		my $classe3_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /3/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=3" >Classe 3</a></li>' ;
		my $classe4_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /4/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=4" >Classe 4</a></li>' ;
		my $classe5_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /5/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=5" >Classe 5</a></li>' ;
		my $classe6_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /6/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=6" >Classe 6</a></li>' ;
		my $classe7_link = '<li><a class=' . ( (defined $args->{classe} && $args->{classe} =~ /7/ ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/compte?configuration&amp;classe=7" >Classe 7</a></li>' ;
		#Filtrage classe
		$content .= '<div class="menuN2"><ul class="main-nav2">' . $classeall_link . $classe1_link . $classe2_link . $classe3_link . $classe4_link . $classe5_link . $classe6_link . $classe7_link . '</ul></div>' ;
	}
	


    return $content ;

} #sub display_menu_compte 

1 ;
