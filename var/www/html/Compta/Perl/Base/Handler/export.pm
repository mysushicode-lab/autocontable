package Base::Handler::export ;
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

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content = '<div class=menu>';
    my $req = Apache2::Request->new( $r ) ;
	my $dbh = $r->pnotes('dbh') ;
	
    #récupérer les arguments
    my (%args, @args) ;
    
    #recherche des paramètres de la requête
    @args = $req->param ;
    for ( @args ) {
	$args{ $_ } = Encode::decode_utf8( $req->param($_) ) ;
	#les double-quotes et les <> viennent interférer avec le html
	$args{ $_ } =~ tr/<>"/'/ ;
    }
 
 	############################################################# 
	#l'utilisateur a demandé l'archivage d'un mois			    #
	#############################################################
    if ( defined $args{archive_this} ) {
	my $en_attente_count = '';
	my $sql ;
	my @bind_array ;
	
	if 	($args{id_month} eq 'ALL' ){
	
	#on calcule début de l'année + fiscal_year_offset + 1 année - 1 jour
	$sql = q [
	with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND id_export IS NULL AND libelle_journal NOT LIKE '%CLOTURE%'
	AND date_ecriture <= ((? || '-01-01')::date + '1 year'::interval)::date -1
	GROUP BY id_entry)
	SELECT count(id_entry) FROM t1
	] ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year} ) ;
	
	
		
	} else {
		
	#on calcule début de l'année + fiscal_year_offset + 1 année - 1 jour
	$sql = q [
	with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND id_export IS NULL AND libelle_journal NOT LIKE '%CLOTURE%'
	AND date_ecriture <= ((? || '-' || ? || '-01')::date + '1 month'::interval)::date -1
	GROUP BY id_entry)
	SELECT count(id_entry) FROM t1
	] ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year},$args{id_month} ) ;
	
	}
	
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	if (not($en_attente_count eq '0')) {
	
		$content .= '<h3 class="warning centrer">Attention : il existe ' . $en_attente_count . ' écriture(s) non validéee(s) sur l\'exercice.<br>
		La clôture ne peut pas être effectuée</h3>' ;	
	
	} else {
		
	if ( $args{archive_this} eq '0' ) { #première demande; confirmation requise

	    my $oui_href = '/'.$r->pnotes('session')->{racine}.'/export?archive_this=1&id_month=' . $args{id_month} ;

	    my $non_href = '/'.$r->pnotes('session')->{racine}.'/export' ;
	    
	    my $message ;
	    
	    if 	($args{id_month} eq 'ALL' ){

	    $message = '
<p class=warning>Vous allez enclencher la clôture des données pour tous les mois de l\'année <br><br>
Il ne sera plus possible d\'ajouter, modifier, ou supprimer des écritures pour tous ces mois<br>
Continuer ?<br> <a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a> <a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a></p>
' ;
	} else {
		$message = '
<p class=warning>Vous allez enclencher l\'archivage des données pour le mois de <br><strong>' . $args{pretty_month} . ' (' . $args{id_month} . ')</strong><br>
Il ne sera plus possible d\'ajouter, modifier, ou supprimer des écritures pour ce mois<br>
Continuer ? <br><a href="' . $oui_href . '" class=nav  style="margin-left: 3ch;">Oui</a> <a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a></p>
' ;
	}
	    $content .= $message ;
	    
	} else { #demande confirmée, déclencher l'archivage du mois
		
		if 	($args{id_month} eq 'ALL' ){
			foreach my $i (1..12) {
			my $t = Time::Piece->strptime($i, "%m");
			my $format_date = $t->strftime("%m");
			my $sql = 'INSERT INTO tbllocked_month (id_client, fiscal_year, id_month) VALUES (?, ?, ?)
			ON CONFLICT (id_client, fiscal_year, id_month) DO NOTHING
			' ;
			my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $format_date ) ;
			my $dbh = $r->pnotes('dbh') ;
			eval { $dbh->do($sql, undef, @bind_array) } ;
				if ( $@ ) {
				$content .= '<h3 class=warning>' . $@ . '</h3>' ;
				} #	    if ( $@ ) {
			}	
		} else {
			my $sql = 'INSERT INTO tbllocked_month (id_client, fiscal_year, id_month) VALUES (?, ?, ?)' ;
			my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args{id_month} ) ;
			my $dbh = $r->pnotes('dbh') ;
	        eval { $dbh->do($sql, undef, @bind_array) } ;
			if ( $@ ) {
			#si l'utilisateur fait un reload juste après un archivage
			#ça déclenche la contrainte de clé primaire
			my $message = ( $@ =~ /unique/ ) ? 'Le mois '.$args{id_month}.' est déjà bloqué' : $@ ;
			$content .= '<h3 class=warning>' . $message . '</h3>' ;	
			}
		}

	} #	if ( $archive_this eq '0' ) {
	
	}
	
    } #    if ( defined $args{archive_this} ) {
    
    ############################################################# 
	#l'utilisateur a demandé les écritures validées				#
	############################################################# 
      if ( defined $args{id_export} && not(defined $args{select_export})) {

	    #création du fichier à télécharger
	    my $location = Base::Handler::export::data_file_v3( $r, \%args ) ;

	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {

		$content .= $location ;

	    } else {

		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		
		return Apache2::Const::REDIRECT ;
		
	    } #	    if ( $location =~ /warning/ )
	
    } #    if ( defined $args{id_export} ) 
    
    ############################################################# 
	#l'utilisateur a demandé le fec								#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'fec' ) {	
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::fec_file( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args->{fec} ) {
    
    ############################################################# 
	#l'utilisateur a demandé l'export all v1					#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'all_exercice_v1' ) {
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::data_file_v1( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{id_export} ) 
    
    ############################################################# 
	#l'utilisateur a demandé l'export all v2					#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'all_exercice_v2' ) {
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::data_file_v3( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{id_export} ) 
    
    #####################################################################
	#l'utilisateur a demandé l'export des données concernant les docs	#
	##################################################################### 
    if ( defined $args{select_export} && $args{select_export} eq 'all_docs' ) {
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::data_docs( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub data_file, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{id_export} ) 
    
    ############################################################# 
	#l'utilisateur a demandé l'export de la liste des comptes	#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'liste_comptes' ) {	
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::compte_list( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub compte_list, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
 	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{compte_list} )

    ############################################################# 
	#l'utilisateur a demandé l'export de la liste tblbilan		#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'tblbilan' ) {	
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::export_tblbilan( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub compte_list, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
 	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{compte_list} )

    ############################################################# 
	#l'utilisateur a demandé l'export de la liste des journaux	#
	############################################################# 
    if ( defined $args{select_export} && $args{select_export} eq 'liste_journaux' ) {	
	    #création du fichier à télécharger
	    my $location = Base::Handler::export::journal_list( $r, \%args ) ;
	    #si un message d'erreur est renvoyé par sub journal_list, il contient class=warning
	    if ( $location =~ /warning/ ) {
		$content .= $location ;
 	    } else {
		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		return Apache2::Const::REDIRECT ;
	    } #	    if ( $location =~ /warning/ )
    } #    if ( defined $args{compte_list} )


    if ( defined $args{new_export} ) {

	#première demande d'archivage incrémentiel
	#afficher la liste des exportations en attente et demander confirmation
	if ( $args{new_export} eq '0' ) {

	    $content .= new_export( $r, \%args ) ;
	 
	} else {

	    #création du fichier à télécharger
	    my $location = Base::Handler::export::new_export( $r, \%args ) ;

	    #si un message d'erreur est renvoyé par sub new_export, il contient class=warning
	    if ( $location =~ /warning/ ) {

		$content .= $location ;

	    } else {

		#adresse du fichier précédemment généré
		$r->headers_out->set(Location => $location) ;
		
		#rediriger le navigateur vers le fichier
		$r->status(Apache2::Const::REDIRECT) ;
		
		return Apache2::Const::REDIRECT ;
		
	    } #	    if ( $location =~ /warning/ )
   
	} #	if ( $args{new_export} eq '0' ) 
	
    } #    if ( defined $args{new_export} )
    
    $content .= menu( $r, \%args ) ;
    $content .= '</div>';
    
    $r->no_cache(1) ;
 
    $r->content_type('text/html; charset=utf-8') ;

    print $content ;

    return Apache2::Const::OK ;

}

sub new_export {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;
 
    #1ère demande de suppression; afficher lien d'annulation/confirmation
    if ( $args->{new_export} eq '0' ) {

	my $sql = '
with t1 as ( SELECT id_entry FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND id_export IS NULL AND date_ecriture <= ? AND libelle_journal NOT LIKE \'%CLOTURE%\' GROUP BY id_entry)
SELECT count(id_entry) FROM t1
' ;

	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{validation} ) ;

	my $en_attente_count = '';
	
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;

    if ( $@ ) {
	if ( $@ =~ / NOT NULL (.*) date / ) {

	    $content .= '<h3 class=warning>Il faut une date valide - Enregistrement impossible</h3>' ;

	    return $content ;

	} else {

	    $content .= '<h3 class=warning>' . $@ . '</h3>' ;

	    return $content ;
	    
	} #	if ( $@ =~ / numeric / ) 
	}
	
	my $t = Time::Piece->strptime($args->{validation}, "%Y-%m-%d");
	my $format_date = $t->strftime("%d/%m/%Y");

	my $non_href = '/'.$r->pnotes('session')->{racine}.'/export' ;

	my $oui_href = '/'.$r->pnotes('session')->{racine}.'/export?new_export=1&validation='.$args->{validation}.'' ;

	my $confirm = ( $en_attente_count eq '0' ) ? '' : '. Les exporter?<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav  style="margin-left: 3ch;">Non</a>' ;
	
	$content .= '<h3 id=warning class="warning centrer" >!!! IMPORTANT !!!</p>
La validation des écritures a pour objectif le blocage des écritures.
Elle va incrémenter un numéro d’ordre, affecter un numéro de pièce automatique si celui-ci n\'est pas présent, et enregistre
la date du jour comme date de validation.
Aucune correction sur ces écritures ne pourra être effectuée.
Cependant de nouvelles saisies sur la période restent possibles.</p>
Il est conseillé de faire une <a href="/'.$r->pnotes('session')->{racine}.'/parametres?sauvegarde">sauvegarde</a> avant la validation des écritures.<br><br>
Il y a ' . $en_attente_count . ' écritures en attente d\'exportation en date du '.$format_date.' ' . $confirm . '</h3>' ;
	
	return $content ;

    } else {
		
	my $sql = 'SELECT id_client, date_export, fiscal_year, date_validation FROM tblexport WHERE id_client = ? and fiscal_year = ?' ;
	my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $verif_export = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;
	
	$sql = 'SELECT num_mouvement FROM tbljournal WHERE id_client = ? and fiscal_year = ? and num_mouvement is not NULL
	order by length(num_mouvement) desc, num_mouvement desc
	limit 1';
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	my $verif_number = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
	
	$sql = 'SELECT last_value FROM public.tbljournal_id_num_mouvement_seq';
	my $verif_seq = $dbh->selectall_arrayref( $sql, undef )->[0]->[0] ;
	
	$sql = 'SELECT last_value FROM public.tblexport_id_export_seq';
	my $verif_exportseq = $dbh->selectall_arrayref( $sql, undef )->[0]->[0] ;
	
	#GRANT ALL ON SEQUENCE public.tbljournal_id_num_mouvement_seq TO "www-data";
	#GRANT USAGE, SELECT ON SEQUENCE public.tbljournal_id_num_mouvement_seq TO "www-data";
	if (not(@{$verif_export}) && not($verif_number)) {
		
	$sql = 'SELECT setval(\'public.tbljournal_id_num_mouvement_seq\', 1, false)';		
	#$sql = 'ALTER SEQUENCE public.tbljournal_id_num_mouvement_seq RESTART WITH 1';
	#$sql = 'SELECT setval(public.tbljournal_id_num_mouvement_seq, 1, FALSE)';
	eval { $dbh->do( $sql, undef) } ;

	} elsif (not($verif_number eq 'NULL') && $verif_number != $verif_seq && $verif_number > $verif_seq){
	$sql = 'SELECT setval(\'public.tbljournal_id_num_mouvement_seq\', '.($verif_number + 1).', FALSE)';
	eval { $dbh->do( $sql, undef) } ;
		
	}
	
	#if ($verif_export eq undef) {
	#my $sql = 'ALTER SEQUENCE tbljournal_id_num_mouvement_seq RESTART WITH 1';
	#insérer les données
	#$dbh->do( $sql ) ;
	#}	
	

	#récupérer l'id du nouvel export
	$sql = 'INSERT INTO tblexport (id_client, date_export, fiscal_year, date_validation) VALUES (?, ?, ?, CURRENT_DATE) returning id_export' ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $args->{validation}, $r->pnotes('session')->{fiscal_year} ) ;

	my $new_export_id = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

	$sql = '
	with t1 as (
	select  id_facture, id_entry, date_ecriture, fiscal_year, id_client, num_mouvement, id_export, libelle_journal
	from tbljournal
	WHERE id_client = ? and fiscal_year = ? and id_export is NULL AND date_ecriture <= ? AND libelle_journal NOT LIKE \'%CLOTURE%\'
	GROUP BY id_entry, id_facture, date_ecriture, fiscal_year, id_client, num_mouvement, id_export, libelle_journal
	ORDER BY date_ecriture, CASE WHEN libelle_journal ~* \'nouv|NOUV\' THEN 1 END, id_facture, id_entry, libelle_journal
	),
	t2 as (
	select nextval(\'tbljournal_id_num_mouvement_seq\'::regclass) as my_id_num_mouvement, date_ecriture as my_date_ecriture, fiscal_year as my_fiscal_year, id_client as my_id_client, id_entry as my_id_entry, num_mouvement as my_num_mouvement
	from t1
	)
	UPDATE tbljournal SET num_mouvement = t2.my_id_num_mouvement, id_export = ?
	FROM t2
	WHERE date_ecriture = t2.my_date_ecriture and fiscal_year = t2.my_fiscal_year and id_client = t2.my_id_client and id_entry = my_id_entry
	' ; 

	@bind_array = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  $args->{validation}, $new_export_id  ) ;
	$dbh->do( $sql, undef, @bind_array ) ;
	
		    if ( $@ ) {

		my $content .= '<h3 class=warning>' . $@ . '</h3>' ;

	    return $content ;

	    }
	
	
	my $location = '/'.$r->pnotes('session')->{racine}.'/export' ;

	return $location ;
	    
    } #    if ( $args->{new_export} eq '0' )
    
} #sub new_export

sub menu {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    
    #SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT#
    #
	#choix des données à exporter
	#
	my $var_fec = '';
	unless (defined $args->{select_export}) {
	$args->{select_export} = 'fec';
	}
	my $id_select_export = '<select class="login-text" name=select_export style="font-size:14px;">
	<option ' . ( ( $args->{select_export} eq 'liste_journaux' ) ? 'selected' : '' ) . ' value="liste_journaux">CSV - Liste des journaux pour l\'exercice en cours</option>
	<option ' . ( ( $args->{select_export} eq 'liste_comptes' ) ? 'selected' : '' ) . ' value="liste_comptes">CSV - Liste des comptes pour l\'exercice en cours</option>
	<option ' . ( ( $args->{select_export} eq 'fec' ) ? 'selected' : '' ) . ' value="fec" >FEC - Fichier des écritures comptables (Article A47 A-1)</option>
	<option ' . ( ( $args->{select_export} eq 'all_exercice_v2' ) ? 'selected' : '' ) . ' value="all_exercice_v2">CSV - Fichier de toutes les écritures pour l\'exercice en cours</option>
	</select>
	' ;
	#SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT SELECT#
    
    #	<option ' . ( ( $args->{select_export} eq 'all_docs' ) ? 'selected' : '' ) . ' value="all_docs">CSV - Fichier de toutes les données concernant les documents pour l\'exercice en cours</option>
	
	if ($args->{select_export} eq 'fec') {
	$var_fec = '';	
	}
    
    my $content .= '
    <fieldset class="pretty-box"><legend><h3 class="Titre09">Gestions des données</h3></legend>
	<div class="centrer">
	<div class="Titre10 centrer">Exportations des données <span title="Cliquer pour ouvrir l\'aide" id="help-link1" onclick="SearchDocumentation(\'base\', \'importexport_1\');" style="cursor: pointer;" >[?]</span></div>
     <div class="form-int">
     <form action=/'.$r->pnotes('session')->{racine}.'/export>
    '.$id_select_export.'
    <input type=hidden name=id_mois value="00">
    <input type=hidden name=id_export value="0">
    <br><br>
	<input type=submit class="btn btn-vert" style ="width : 25%;" value=Télécharger>
	</form></div>
    ' ;

   #mettre la date du jour par défaut ou date de fin d'exercice
    if ( (!defined $args->{validation}) || not($args->{validation} =~ /^(?<year>[0-9]{4})-(?<month>[0-9]{2})-(?<day>[0-9]{2})$/ )) {
	my $date_1 = localtime->strftime('%Y-%m-%d');
	my $date_2 = $r->pnotes('session')->{Exercice_fin_YMD} ;
	if ($date_1 gt $date_2) {$args->{validation} = $date_2;} else {$args->{validation} = $date_1;}
    } 
    
    
    #on avorte la procédure si la date fournie est incompréhensible
    if ( $@ ) {
		if ( $@ =~ /type date/ ) {
			$content = '<h3 class=warning>Mauvaise date : ' . $args->{validation} . '</h3>' ;
		} else {
			$content = '<h3 class=warning>' . $@ . '</h3>' ;
		}
	return $content ;
	}

    $content .= '<div class="Titre10 centrer">Validation des écritures <span title="Cliquer pour ouvrir l\'aide" id="help-link2" onclick="SearchDocumentation(\'base\', \'ecriturescomptables_7\');" style="cursor: pointer;" >[?]</span></div>' ;

    my $title_pending = 'Valide et bloque toutes les écritures non encore validée; de nouvelles écritures peuvent être ajoutées pour toutes dates' ;

   	#titre
	$content .= '
	<div class="form-int">
	<h4>Validation des écritures non validées</h4>
	<ul class="wrapper centrer">
	<li style="text-align: center; list-style: none;" class="test">
	<form action="/'.$r->pnotes('session')->{racine}.'/export">
	

	<label class="forms" style="font-weight: normal; text-align: right;" for="validation">Valider jusqu\'au</label>
	<input class="login-text" style ="width : 20%;" type="date" name=validation id=validation value="' . $args->{validation} . '" onchange="format_date(this, \'' . $r->pnotes('session')->{preferred_datestyle} . '\')">
	<input type=hidden name=new_export id=new_export value="0">
	<input type=hidden name="racine" id="racine" value="' . $r->pnotes('session')->{racine} . '">
	<input type=submit class="btn btn-vert" style ="width : 15%;" value=Valider>
	<br>
	</form>
	</li>
	</ul>' ;

    $content .= '<h4>Historique des écritures validées</h4><br>' ;
    $content .= historique($r);
	
	$content .= '<div class="Titre10 centrer">Clôtures des journaux <span title="Cliquer pour ouvrir l\'aide" id="help-link3" onclick="SearchDocumentation(\'base\', \'journaux_4\');" style="cursor: pointer;" >[?]</span></div>' ;

	$content .= '<h4>Clôtures annuelles</h4>' ;
	
	my $archive_this_link = '/'.$r->pnotes('session')->{racine}.'/export?archive_this=0&id_month=ALL&pretty_month=ALL' ; 
	
	 	#titre
	$content .= '
	<div class="form-int">
	<ul class="wrapper centrer">
	<li style="text-align: center; list-style: none;" class="test">
	<form action="/'.$r->pnotes('session')->{racine}.'/export">
	<label class="forms" style="width : 50%; font-weight: normal; text-align: right;" for="validation">Clôturer tous les mois de l\'exercice</label>
	<input type=hidden name=archive_this id=archive_this value="0">
	<input type=hidden name=id_month id=id_month value="ALL">
	<input type=hidden name=pretty_month id=pretty_month value="ALL">
	<input type=submit class="btn btn-vert" style ="width : 15%;" value=Valider>
	<br>
	</form>
	</li>
	</ul>' ;
	
    $content .= '<h4>Clôtures mensuelles</h4>' ;

    my $sql = q [
WITH t1 as (
SELECT to_char((? || '-01-01')::date + ?::integer + (s.m || 'months')::interval, 'MM') AS id_month,
to_char((? || '-01-01')::date + ?::integer + (s.m || 'months')::interval, 'TMMonth') AS pretty_month
       FROM generate_series(0, 11) AS s(m)),
t2 as (
       SELECT id_month, date_locked FROM tbllocked_month WHERE id_client = ? AND fiscal_year = ?
	      )
SELECT t1.id_month, t1.pretty_month, t2.id_month, t2.date_locked
FROM t1 LEFT JOIN t2 USING (id_month)
] ;

    my @bind_array = ( $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}  ) ;

    my $month_set = $dbh->selectall_arrayref( $sql, undef, @bind_array ) ;

    my $rows = '<tr><th colspan=2>Mois</th><th>Date d\'archivage</th><th colspan=2>Télécharger</th></tr>' ;

    for ( @$month_set ) {
	
	#régler l'alternance des liens 
	#si id_month est null, fournir un lien vers l'archivage
	#sinon, le mois est déjà archivé
	#dans ce cas, fournir les liens vers le téléchargement des données aux formats FEC et base
	my $pretty_month = $_->[1] ;

	my $archive_this_link = '/'.$r->pnotes('session')->{racine}.'/export?archive_this=0&id_month=' . $_->[0] . '&pretty_month=' . $_->[1] ; 

	my $id_month = ( defined $_->[2] ) ? $_->[0] : '<a href="' . $archive_this_link . '">' . $_->[0] . '</a>' ;

	my $date_locked = ( defined $_->[2] ) ? $_->[3] : '&nbsp;' ;

	my $download_fec_link = ( defined $_->[2] ) ? '<a href="/'.$r->pnotes('session')->{racine}.'/export?select_export=fec&id_mois=' . $id_month . '" title="Télécharger les données au format FEC">FEC</a>' : '&nbsp;' ;

	my $download_data_link = ( defined $_->[2] ) ? '<a href="/'.$r->pnotes('session')->{racine}.'/export?id_export=0&id_mois=' . $id_month . '" title="Télécharger toutes les données enregistrées sur la période">Données</a>' : '&nbsp;' ;
	
	$rows .= '<tr><td>' . $pretty_month . '</td><td>' . $id_month . '</td><td class=caseRepere>'. $date_locked . '</td><td>' . $download_fec_link . '</td><td>' . $download_data_link . '</td></tr>' ;
 
    } #    for ( @$month_set ) 
    
    
    $content .= '<table>' . $rows . '</table></div>' ;

   my $content2 .= '<div class="formulaire1">' . $content . '</div>' ;
		
    return $content2 ;
    
} #sub menu 

sub historique {

    my $r = shift ;

    my $dbh = $r->pnotes('dbh') ;

    my $content ;

    my $sql = 'SELECT id_export, date_export, date_validation FROM tblexport WHERE id_client = ? AND fiscal_year = ? ORDER by date_export DESC, id_export DESC' ;

    my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
    
    my $historique = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

    my $export_list = '' ;
    
    for ( @$historique ) {

	my $export_href = '/'.$r->pnotes('session')->{racine}.'/export?id_export=' . $_->{id_export} . '&id_mois=00' ;
	
	$export_list .= '<li class=listitem3><div class=container style="margin-left: 1ch;"><div class=spacer></div>
	<a href="' . $export_href . '">
	<span class=blockspan style="width: 100%;">Ecritures validées jusqu\'au ' . $_->{date_export} . ' : date de validation le ' . $_->{date_validation} . '</span>
	</a>
	<div class=spacer></div></div></li>' ;

    }

    $content .= '<ul class=wrapper>' . $export_list . '</ul>' ;

    return $content ;
    
} #sub historique 

sub compte_list {
	
	my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

    #pour toutes les variables de la commande d'exportation
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $ENV{'PATH'} = '/bin:/usr/bin' ;
    
    $r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $fiscal_year = $1 ;

    my $fiscal_year_clause = ' and fiscal_year = ' . $fiscal_year ;

    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;

    my $session_id = $1 ;
    
    my $file = '/Compta/base/downloads/listes_comptes_' . $fiscal_year . '_export_' . $date . '.csv' ;

    my $location = $r->document_root() . $file ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' id_client = ' . $1 ;
    
    #create file
    my $sql = qq {\\copy ( SELECT numero_compte as "CompteNum", libelle_compte as "CompteLib", contrepartie, default_id_tva
FROM tblcompte
WHERE $id_client_clause $fiscal_year_clause ORDER BY 1 ) to '$location' with null as '' delimiter ';' csv header
} ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";
	
    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;

} #sub compte_list

sub journal_list {
	
	my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

    #pour toutes les variables de la commande d'exportation
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $ENV{'PATH'} = '/bin:/usr/bin' ;
    
    $r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $fiscal_year = $1 ;

    my $fiscal_year_clause = ' and fiscal_year = ' . $fiscal_year ;

    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;

    my $session_id = $1 ;
    
    my $file = '/Compta/base/downloads/listes_journaux_' . $fiscal_year . '_export_' . $date . '.csv' ;

    my $location = $r->document_root() . $file ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' id_client = ' . $1 ;
    
    #create file
    my $sql = qq {\\copy ( SELECT code_journal as "JournalCode", libelle_journal as "JournalLib", type_journal as "JournalType"
FROM tbljournal_liste
WHERE $id_client_clause $fiscal_year_clause ORDER BY 1 ) to '$location' with null as '' delimiter ';' csv header
} ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";
	
    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;

} #sub journal_list

sub data_file_v1 {

    my ( $r, $args )  = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my $content ;

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $session_id = $1 ;
    
    my $file = '/Compta/base/downloads/' . $date . '_v1.csv' ;

    my $location = $r->document_root( ) . $file ;

    #Insecure $ENV{PATH} while running with -T switch
    $ENV{'PATH'} = '/bin:/usr/bin' ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' id_client = ' . $1 ;

    $args->{id_export} =~ /(\d+)/ ;
    
    my $id_export_clause ;

    if ( $args->{id_export} eq '0' ) {

	$r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	
	my $fiscal_year = $1 ;
	
	$id_export_clause = ' and fiscal_year = ' . $fiscal_year ;

    } else {

	$id_export_clause = ' and id_export = ' . $1 ;

    } #    if ( $args->{id_export} eq '0' )

    #attention aux exercices décalés : afficher "année N - année N+1" pour les exercices décalés
    my $exercice ;

    $r->pnotes('session')->{fiscal_year} =~ /(\d\d\d\d)/ ;

    $exercice = $1 ;

    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
	
	$exercice = $exercice . '.' . ( $1 + 1 ) ;

    }

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $args->{id_mois} =~ /([0-9]+)/ ;

    my $id_mois = $1 ;

    #on peut servir toutes les écritures, ou un mois archivé
    my $month_clause = ( $id_mois eq '00' ) ? '' : ' AND to_char(date_ecriture, \'MM\') = \'' . $id_mois . '\'' ;

    my $sub_query = qq { 
SELECT id_entry, date_ecriture as date, id_facture as "numéro de pièce", libelle as libellé, to_char(debit/100::numeric, '999999999990D00') as débit, to_char(credit/100::numeric, '999999999990D00') as crédit, lettrage, id_paiement as libre, numero_compte as "numéro de compte", $exercice as exercice, libelle_journal as journal, pointage 
FROM tbljournal 
WHERE $id_client_clause $id_export_clause $month_clause
ORDER BY 1, 2, 3
} ;

    #create file
    my $sql = qq {\\copy ( $sub_query ) to '$location' with  null as '' delimiter ';' csv header } ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";

    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;
        
} #sub data_file_v1

sub data_file_v2 {

    my ( $r, $args )  = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my $content ;

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $session_id = $1 ;
    
    my $file = '/Compta/base/downloads/' . $date . '_v2.csv' ;

    my $location = $r->document_root( ) . $file ;

    #Insecure $ENV{PATH} while running with -T switch
    $ENV{'PATH'} = '/bin:/usr/bin' ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' id_client = ' . $1 ;

    $args->{id_export} =~ /(\d+)/ ;
    
    my $id_export_clause ;

    if ( $args->{id_export} eq '0' ) {

	$r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	
	my $fiscal_year = $1 ;
	
	$id_export_clause = ' and fiscal_year = ' . $fiscal_year ;

    } else {

	$id_export_clause = ' and id_export = ' . $1 ;

    } #    if ( $args->{id_export} eq '0' )

    #attention aux exercices décalés : afficher "année N - année N+1" pour les exercices décalés
    my $exercice ;

    $r->pnotes('session')->{fiscal_year} =~ /(\d\d\d\d)/ ;

    $exercice = $1 ;

    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
	
	$exercice = $exercice . '.' . ( $1 + 1 ) ;

    }

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $args->{id_mois} =~ /([0-9]+)/ ;

    my $id_mois = $1 ;

    #on peut servir toutes les écritures, ou un mois archivé
    my $month_clause = ( $id_mois eq '00' ) ? '' : ' AND to_char(date_ecriture, \'MM\') = \'' . $id_mois . '\'' ;

    my $sub_query = qq { 
SELECT libelle_journal as journal, date_ecriture, id_paiement as libre, numero_compte as "numéro de compte", id_facture as "numéro de pièce", libelle as libellé, to_char(debit/100::numeric, '999999999990D00') as débit, to_char(credit/100::numeric, '999999999990D00') as crédit, lettrage, pointage, documents1, documents2, $exercice as exercice, num_mouvement, date_creation
FROM tbljournal 
WHERE $id_client_clause $id_export_clause $month_clause
ORDER BY length(num_mouvement), num_mouvement
} ;

    #create file
    my $sql = qq {\\copy ( $sub_query ) to '$location' with  null as '' delimiter ';' csv header } ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";

    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;
        
} #sub data_file_v2

sub data_docs {

    my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

    #pour toutes les variables de la commande d'exportation
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $ENV{'PATH'} = '/bin:/usr/bin' ;
    
    $r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $fiscal_year = $1 ;

    my $fiscal_year_clause = ' and fiscal_year = ' . $fiscal_year ;

    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;

    my $session_id = $1 ;
    
    my $file = '/Compta/base/downloads/listes_docs_' . $fiscal_year . '_export_' . $date . '.csv' ;

    my $location = $r->document_root() . $file ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' id_client = ' . $1 ;

    #create file
    my $sql = qq {\\copy ( SELECT date_reception, id_name as "Nom", libelle_cat_doc, to_char(montant/100::numeric, '999999999990D00') as montant, fiscal_year, date_upload, last_fiscal_year, check_banque, id_client
FROM tbldocuments
WHERE $id_client_clause $fiscal_year_clause ORDER BY 1 ) to '$location' with null as '' delimiter ';' csv header
} ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";

    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;
        
} #sub data_docs

sub fec_file {
#écrire le fichier des écritures comptables art. A 47 A-1 du code des impôts

    my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

    #nom du fichier attendu sous la forme siretFECAAAAMMJJ
    #AAAAMMJJ = la date de clôture de l'exercice comptable
    my $date_fin_exercice = $r->pnotes('session')->{Exercice_fin_YMD} ;
	$date_fin_exercice =~ tr/-//d;

    my $sql = qq {SELECT siret FROM compta_client WHERE id_client = ?} ;

    my $name_set = $dbh->selectall_arrayref( $sql, undef, ( $r->pnotes('session')->{id_client} ) ) ;
    
	# ne prendre que les 9 premiers caractères du SIRET pour le SIREN
    my $siret = substr($name_set->[0]->[0], 0, 9) ;

    my $file_name = $siret . 'FEC' . $date_fin_exercice ;

    #pour les fichiers FEC mensuels, ajouter le numéro du mois au fichier (ref : https://bofip.impots.gouv.fr/bofip/9028-PGP)
    unless ( $args->{id_mois} eq '00' ) {

	$args->{id_mois} =~ /(\d\d)/ ;
	    
	$file_name .= '_' . $1 ;

    }
    
    $file_name .= '.txt';
    
    my $location = '/Compta/base/downloads/' . $file_name ;

    #on peut servir toutes les écritures, ou un mois archivé
    my $month_clause = ( $args->{id_mois} eq '00' ) ? '' : ' AND to_char(t1.date_ecriture, \'MM\') = \'' . $args->{id_mois} . '\'' ;

    $sql = qq {
SELECT t4.code_journal as "JournalCode", t1.libelle_journal as "JournalLib", t1.num_mouvement as "EcritureNum", to_char(t1.date_ecriture, 'YYYYMMDD') as "EcritureDate", t1.numero_compte as "CompteNum", translate(t2.libelle_compte,'ç','c') as "CompteLib", '' as "CompAuxNum", '' as "CompAuxLib", coalesce(t1.id_facture, \'N/A\') as "PieceRef", CASE WHEN t1.documents1 IS NOT NULL THEN to_char(t3.date_reception, 'YYYYMMDD') ELSE to_char(t1.date_ecriture, 'YYYYMMDD') END as "PieceDate", t1.libelle as "EcritureLib", to_char(t1.debit/100::numeric, 'FM999999999990D00') as "Debit", to_char(t1.credit/100::numeric, 'FM999999999990D00') as "Credit", t1.lettrage as "EcritureLet", CASE WHEN t1.lettrage IS NOT NULL THEN to_char(t5.date_validation, 'YYYYMMDD') ELSE '' END as "DateLet", to_char(t5.date_validation, 'YYYYMMDD') as "ValidDate", '' as "Montantdevise", '' as "Idevise"
FROM tbljournal t1 
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
LEFT JOIN tbldocuments t3 on t1.id_client = t3.id_client and t1.documents1 = t3.id_name
LEFT JOIN tbljournal_liste t4 on t1.id_client = t4.id_client and t1.fiscal_year = t4.fiscal_year and t1.libelle_journal = t4.libelle_journal
LEFT JOIN tblexport t5 on t1.id_client = t5.id_client and t1.fiscal_year = t5.fiscal_year and t1.id_export = t5.id_export
WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.libelle_journal NOT LIKE '%CLOTURE%' $month_clause
ORDER BY length(t1.num_mouvement), t1.num_mouvement
} ;

    my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
    
    #execution de la requête
    my $sth = $dbh->prepare($sql) ;

    eval { $sth->execute( @bind_array ) } ;

    if ( $@ ) {

	#en cas d'erreur, le module de destination reconnait 'warning' et affiche le message d'erreur
	$location = '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">' . $@ . '</h3>' ;

    } else {

	my $records_array = $sth->fetchall_arrayref() ;

	#création des en-têtes de colonne
	my ($column_headers_txt, @column_headers) ;

	#liste des colonnes, par ordre d'apparition à l'écran ; fournie par le hash ad-hoc dans DBI.pm
	push @column_headers, sort {$sth->{NAME_hash}{$a}<=>$sth->{NAME_hash}{$b}} keys %{$sth->{NAME_hash}} ;

	#en-tête txt
	$column_headers_txt = join "|", @column_headers ;

	#début du listing
	my $records_table ;

	#ligne des en-têtes
	$records_table .= $column_headers_txt . "\r\n" ;

	for ( @{$records_array} ) {

	    #initialiser les éléments vides pour supprimer l'erreur 'unitialized value'
	    foreach my $value ( @{$_} ) { $value ||= '' } ;

	    my $line_txt = join "|",  @{$_} ;

	    $records_table .= $line_txt . "\r\n" ;

	}

	$content .= $records_table;
	
	#création du fichier d'exportation
	my $export_file =  $r->document_root() . $location;

	open (my $fh, ">:encoding(UTF-8)", $export_file) or die "Impossible d'ouvrir le fichier $export_file : $!" ;

	#ajouter le BOM pour que les tableurs s'ouvrent avec le bon encodage (utf8)
	#on peut aussi utiliser chr(65279);
	#MS-Office a besoin de ça pour identifier l'encodage
	#print $fh chr(0xFEFF) ;

	print $fh $content ;

	close $fh ;

    } #    if ( $@ )

    return $location ;

}

sub data_file_v3 {

    my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content;

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $r->pnotes('session')->{_session_id} =~ /([a-zA-Z0-9_]+)/ ;
	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 
    my $session_id = $1 ;

    #Insecure $ENV{PATH} while running with -T switch
    $ENV{'PATH'} = '/bin:/usr/bin' ;

    $r->pnotes('session')->{id_client} =~ /(\d+)/ ;

    my $id_client_clause = ' t1.id_client = ' . $1 ;

    $args->{id_export} =~ /(\d+)/ ;
    
    my $id_export_clause ;
    
    my $file_name = 'ALL_'.$r->pnotes('session')->{fiscal_year}.'_au_' . $date ;
    
    #pour les fichiers FEC mensuels, ajouter le numéro du mois au fichier (ref : https://bofip.impots.gouv.fr/bofip/9028-PGP)
    unless ( $args->{id_mois} eq '00' ) {

	$args->{id_mois} =~ /(\d\d)/ ;
	    
	$file_name .= '_Mois_' . $1 ;

    }
    
    $file_name .= '.csv';
    
    my $file = '/Compta/base/downloads/' . $file_name ;

   if ( $args->{id_export} eq '0' ) {

	$r->pnotes('session')->{fiscal_year} =~ /(\d+)/ ;
	
	my $fiscal_year = $1 ;
	
	$id_export_clause = ' and t1.fiscal_year = ' . $fiscal_year ;
	
    } else {
		
	$id_export_clause = ' and t1.id_export = ' . $1 ;
	
	my $sql = '
	SELECT date_export FROM tblexport WHERE id_export = ? 
	' ;

	my @bind_array = ( $args->{id_export} ) ;

	my $date_exportation = '';
	
	eval { $date_exportation = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;	
	
	$date_exportation =~ s/\//_/g;

	$file = '/Compta/base/downloads/ALL_'.$r->pnotes('session')->{fiscal_year}.'_au_' . $date_exportation . '_v3.csv' ;
	
    } 
    
    my $location = $r->document_root( ) . $file ;

    #attention aux exercices décalés : afficher "année N - année N+1" pour les exercices décalés
    my $exercice ;

    $r->pnotes('session')->{fiscal_year} =~ /(\d\d\d\d)/ ;

    $exercice = $1 ;

    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
	
	$exercice = $exercice . '.' . ( $1 + 1 ) ;

    }

    #pour toutes les variables de la commande d'exportation ($session_id, $id_client_clause et $id_export_clause)
    #Insecure dependency in system while running with -T switch
    #faire un match et utiliser $1
    $args->{id_mois} =~ /([0-9]+)/ ;

    my $id_mois = $1 ;

    #on peut servir toutes les écritures, ou un mois archivé
    my $month_clause = ( $id_mois eq '00' ) ? '' : ' AND to_char(t1.date_ecriture, \'MM\') = \'' . $id_mois . '\'' ;

#, t2.contrepartie as ComptePart, t3.multi as doc1_multi, t4.multi as doc2_multi, t1.recurrent as "recurrent"
    my $sub_query = qq { 
SELECT t6.code_journal as "JournalCode", t1.libelle_journal as "JournalLib", t1.num_mouvement as "EcritureNum", t1.date_ecriture as "EcritureDate", t1.numero_compte as "CompteNum", translate(t2.libelle_compte,'ç','c') as "CompteLib", t1.id_paiement as "Libre", t1.id_facture as "PieceRef", t1.libelle as "EcritureLib", to_char(t1.debit/100::numeric, '999999999990D00') as "Debit", to_char(t1.credit/100::numeric, '999999999990D00') as "Credit", t1.lettrage as "EcritureLet", t1.pointage as "EcriturePointage", t1.documents1, t1.documents2, t1.date_creation, t5.date_validation as "ValidDate", $exercice as "exercice", t1.id_export, t3.date_reception as doc1_date_reception, t3.libelle_cat_doc as doc1_libelle_cat_doc, to_char(t3.montant/100::numeric, '999999999990D00') as doc1_montant, t3.date_upload as doc1_date_upload, t3.last_fiscal_year as doc1_last_fiscal_year_doc, t3.check_banque as doc1_check_banque, t3.id_compte as doc1_id_compte, t4.date_reception as doc2_date_reception, t4.libelle_cat_doc as doc2_libelle_cat_doc, to_char(t4.montant/100::numeric, '999999999990D00') as doc2_montant, t4.date_upload as doc2_date_upload, t4.last_fiscal_year as doc2_last_fiscal_year_doc, t4.check_banque as doc2_check_banque, t4.id_compte as doc2_id_compte, t5.date_export as date_export
FROM tbljournal t1
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte)  
LEFT JOIN tbldocuments t3 on t1.id_client = t3.id_client and t1.documents1 = t3.id_name 
LEFT JOIN tbldocuments t4 on t1.id_client = t4.id_client and t1.documents2 = t4.id_name 
LEFT JOIN tblexport t5 on t1.id_client = t5.id_client and t1.fiscal_year = t5.fiscal_year and t1.id_export = t5.id_export 
LEFT JOIN tbljournal_liste t6 on t1.id_client = t6.id_client and t1.fiscal_year = t6.fiscal_year and t1.libelle_journal = t6.libelle_journal
WHERE $id_client_clause $id_export_clause $month_clause 
ORDER BY length(t1.num_mouvement), t1.num_mouvement 
} ; 

    #create file
    my $sql = qq {\\copy ( $sub_query ) to '$location' with  null as '' delimiter ';' csv header } ;

    my $db_name = $r->dir_config('db_name') ;
	my $db_host = $r->dir_config('db_host') ;
    my $db_user = $r->dir_config('db_user') ;
    my $db_mdp = $r->dir_config('db_mdp') ;

	system ("PGPASSWORD=\"$db_mdp\" psql -h \"$db_host\" -U \"$db_user\" -d \"$db_name\" -c \"$sql\"") == 0 or die "Bad copy: $?";

    #add BOM
    my @args = ( 'sed', '-i', '1s/^/\xef\xbb\xbf/', $location) ;

    system( @args ) == 0 or die "Bad BOM: $?";

    return $file ;
        
} #sub data_file_v3

sub fec_file_engagement {
#écrire le fichier des écritures comptables art. A 47 A-1 du code des impôts

    my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

    #nom du fichier attendu sous la forme siretFECAAAAMMJJ
    #AAAAMMJJ = la date de clôture de l'exercice comptable
    my $date_fin_exercice = $r->pnotes('session')->{Exercice_fin_YMD} ;
	$date_fin_exercice =~ tr/-//d;

    my $sql = qq {SELECT siret FROM compta_client WHERE id_client = ?} ;

    my $name_set = $dbh->selectall_arrayref( $sql, undef, ( $r->pnotes('session')->{id_client} ) ) ;
    
	# ne prendre que les 9 premiers caractères du SIRET pour le SIREN
    my $siret = substr($name_set->[0]->[0], 0, 9) ;

    my $file_name = $siret . 'FEC' . $date_fin_exercice ;

    #pour les fichiers FEC mensuels, ajouter le numéro du mois au fichier (ref : https://bofip.impots.gouv.fr/bofip/9028-PGP)
    unless ( $args->{id_mois} eq '00' ) {

	$args->{id_mois} =~ /(\d\d)/ ;
	    
	$file_name .= '_' . $1 ;

    }
    
    $file_name .= '.txt';
    
    my $location = '/Compta/base/downloads/' . $file_name ;

    #on peut servir toutes les écritures, ou un mois archivé
    my $month_clause = ( $args->{id_mois} eq '00' ) ? '' : ' AND to_char(t1.date_ecriture, \'MM\') = \'' . $args->{id_mois} . '\'' ;

    $sql = qq {
SELECT t1.libelle_journal as "JournalCode", t1.libelle_journal as "JournalLib", t1.num_mouvement as "EcritureNum", to_char(t1.date_ecriture, 'YYYYMMDD') as "EcritureDate", CASE WHEN substring(t1.numero_compte from 1 for 3) IN ('401','411') THEN substring(t1.numero_compte from 1 for 3)::integer*1000 ELSE t1.numero_compte::integer END as "CompteNum", translate(t2.libelle_compte,'ç','c') as "CompteLib", '' as "CompAuxNum", '' as "CompAuxLib", coalesce(t1.id_facture, \'N/A\') as "PieceRef", to_char(t3.date_reception, 'YYYYMMDD') as "PieceDate", t1.libelle as "EcritureLib", to_char(t1.debit/100::numeric, 'FM999999999990D00') as "Debit", to_char(t1.credit/100::numeric, 'FM999999999990D00') as "Credit", t1.lettrage as "EcritureLet", '' as "DateLet", to_char(t5.date_validation, 'YYYYMMDD') as "ValidDate", '' as "Montantdevise", '' as "Idevise"
FROM tbljournal t1 
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
LEFT JOIN tbldocuments t3 on t1.id_client = t3.id_client and t1.fiscal_year = t3.fiscal_year and t1.documents1 = t3.id_name
LEFT JOIN tblexport t5 on t1.id_client = t5.id_client and t1.fiscal_year = t5.fiscal_year and t1.id_export = t5.id_export
WHERE t1.id_client = ? AND t1.fiscal_year = ? AND libelle_journal NOT LIKE '%CLOTURE%' $month_clause
ORDER BY length(t1.num_mouvement), t1.num_mouvement
} ;

    my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
    
    #execution de la requête
    my $sth = $dbh->prepare($sql) ;

    eval { $sth->execute( @bind_array ) } ;

    if ( $@ ) {

	#en cas d'erreur, le module de destination reconnait 'warning' et affiche le message d'erreur
	$location = '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">' . $@ . '</h3>' ;

    } else {

	my $records_array = $sth->fetchall_arrayref() ;

	#création des en-têtes de colonne
	my ($column_headers_txt, @column_headers) ;

	#liste des colonnes, par ordre d'apparition à l'écran ; fournie par le hash ad-hoc dans DBI.pm
	push @column_headers, sort {$sth->{NAME_hash}{$a}<=>$sth->{NAME_hash}{$b}} keys %{$sth->{NAME_hash}} ;

	#en-tête txt
	$column_headers_txt = join "|", @column_headers ;

	#début du listing
	my $records_table ;

	#ligne des en-têtes
	$records_table .= $column_headers_txt . "\r\n" ;

	for ( @{$records_array} ) {

	    #initialiser les éléments vides pour supprimer l'erreur 'unitialized value'
	    foreach my $value ( @{$_} ) { $value ||= '' } ;

	    my $line_txt = join "|",  @{$_} ;

	    $records_table .= $line_txt . "\r\n" ;

	}

	$content .= $records_table;
	
	#création du fichier d'exportation
	my $export_file =  $r->document_root() . $location;

	open (my $fh, ">:encoding(UTF-8)", $export_file) or die "Impossible d'ouvrir le fichier $export_file : $!" ;

	#ajouter le BOM pour que les tableurs s'ouvrent avec le bon encodage (utf8)
	#on peut aussi utiliser chr(65279);
	#MS-Office a besoin de ça pour identifier l'encodage
	#print $fh chr(0xFEFF) ;

	print $fh $content ;

	close $fh ;

    } #    if ( $@ )

    return $location ;

}

sub export_tblbilan {
    my ( $r, $args )  = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $content ;

	my $date = localtime->strftime('%d_%m_%Y-%Hh%M'); 

    my $file_name = 'ALL_'.($args->{formulaire} || 'UNDEF').'_au_' . $date.'.csv' ;
    my $location = '/Compta/base/downloads/' . $file_name ;

    my $sql = qq {
	SELECT t1.bilan_desc as "FormDesc", t1.bilan_doc as "FormDoc",	t1.bilan_width as "FormWidth", t1.bilan_height as "FormHeight",t1.bilan_disp as "FormDisp", t2.code as "Code", t2.description as "CodeDisp", t2.title as "CodeTitle", t2.style_top as "CodeTop", t2.style_left as "CodeLeft", t2.style_width as "CodeWidth", t2.style_height as "CodeHeight", t2.exercice as "CodeExercice", t3.compte_mini as "CompteMini", t3.compte_maxi  as "CompteMaxi",	t3.compte_journal  as "CompteJournal", t3.solde_type as "CompteType",	t3.si_debit as "CompteSideb", t3.si_credit as "CompteSicre", t3.si_soustraire as "CompteSoustraire"
	FROM tblbilan t1 
	LEFT JOIN tblbilan_code t2 ON t1.id_client = t2.id_client AND t1.bilan_form = T2.formulaire 
	LEFT JOIN tblbilan_detail t3 ON t1.id_client = t3.id_client AND t2.code = t3.code AND t2.formulaire = T3.formulaire 
	WHERE t1.id_client = ? AND t1.bilan_form = ?
	ORDER BY t2.code
	} ;

    my @bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire} ) ;
    my $sth = $dbh->prepare($sql) ;
    eval { $sth->execute( @bind_array ) } ;

    if ( $@ ) {
		#en cas d'erreur, le module de destination reconnait 'warning' et affiche le message d'erreur
		$location = '<h3 class=warning style="margin: 2.5em; padding: 2.5em;">' . $@ . '</h3>' ;
    } else {

		my $records_array = $sth->fetchall_arrayref() ;

		#création des en-têtes de colonne
		my ($column_headers_txt, @column_headers) ;

		#liste des colonnes, par ordre d'apparition à l'écran ; fournie par le hash ad-hoc dans DBI.pm
		push @column_headers, sort {$sth->{NAME_hash}{$a}<=>$sth->{NAME_hash}{$b}} keys %{$sth->{NAME_hash}} ;

		#en-tête txt
		$column_headers_txt = join ";", @column_headers ;

		#début du listing
		my $records_table ;

		#ligne des en-têtes
		$records_table .= $column_headers_txt . ";\r\n" ;

		for ( @{$records_array} ) {

			#initialiser les éléments vides pour supprimer l'erreur 'unitialized value'
			foreach my $value ( @{$_} ) { $value ||= '' } ;

			my $line_txt = join ";",  @{$_} ;

			$records_table .= $line_txt . ";\r\n" ;

		}

		$content .= $records_table;
		
		#création du fichier d'exportation
		my $export_file =  $r->document_root() . $location;

		open (my $fh, ">:encoding(UTF-8)", $export_file) or die "Impossible d'ouvrir le fichier $export_file : $!" ;

		print $fh $content ;

		close $fh ;

    } #    if ( $@ )

    return $location ;
}

1 ;
