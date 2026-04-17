package Base::Handler::tva ;
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

#use DBD::Pg ;

sub handler {

    binmode(STDOUT, ":utf8") ;

    my $r = shift ;
	#utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
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

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;

    #si on a total_tva_brute_due, l'utilisateur a cliqué sur 'Valider' dans le formulaire
    #on enregistre les valeurs dans journal_staging et on affiche le formulaire de saisie d'une écriture
    if ( defined $args{total_tva_brute_due} ) {
	
		Base::Site::bdd::clean_tbljournal_staging( $r );

	#insérer les données de l'entrée dans tbljournal_staging
	#on passe :
	#total_tva_brute_due au debit de 445710
	#total_tva_déductible_4456 au crédit de 445660 - offset de 44567 (crédit à reporter)
	#total_tva_déductible_44567 au crédit de 445670
	#total_tva_déductible_4458 au crédit de 445810 (acomptes)
	#si total_tva_nette_due est > 0
	#total_tva_nette_due au crédit 445510

	my $token_id = Base::Site::util::generate_unique_token_id($r, $dbh);


	if ( $args{total_tva_nette_due} > 0 ) {
				
	    $sql = '
INSERT INTO tbljournal_staging (_session_id, date_ecriture, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, id_facture, libelle, debit, credit, _token_id) VALUES (?, CURRENT_DATE, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?)
' ;
	    
	    @bind_array = ( 
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44571}, 'CA3', $args{nom_periode}, $args{total_tva_brute_due} * 100 , 0, $token_id,
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44566}, 'CA3', $args{nom_periode}, 0, $args{total_tva_deductible_4456} * 100 - $args{total_tva_deductible_44567} * 100, $token_id,
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44581}, 'CA3', $args{nom_periode}, 0, $args{total_tva_deductible_4458} * 100, $token_id,
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44551}, 'CA3', $args{nom_periode}, 0, $args{total_tva_nette_due} * 100, $token_id,
		$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44567}, 'CA3', $args{nom_periode}, 0, $args{total_tva_deductible_44567} * 100, $token_id
) ;

    
	} else {
	    #si total_tva_nette_due est < 0
	    #on doit retirer le montant déjà enregistré dans la ligne 22 (report du crédit de tva apparaissant ligne 27 de la précédente déclaration)
	    #- (total_tva_deductible_44567 + total_tva_nette_due) au debit de 445670
	    $sql = '
INSERT INTO tbljournal_staging (_session_id, date_ecriture, id_entry, id_client, fiscal_year, fiscal_year_offset, fiscal_year_start, fiscal_year_end, libelle_journal, numero_compte, id_facture, libelle, debit, credit, _token_id) VALUES (?, CURRENT_DATE, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?, ?, ?), (?, CURRENT_DATE, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, ?, ?)
' ;

	    @bind_array = ( 
$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44571}, 'CA3', $args{nom_periode}, $args{total_tva_brute_due} * 100 , 0, $token_id,
$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44566}, 'CA3', $args{nom_periode}, 0, ( $args{total_tva_deductible_4456} - $args{total_tva_deductible_44567} ) * 100, $token_id,
$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44581}, 'CA3', $args{nom_periode}, 0, $args{total_tva_deductible_4458} * 100, $token_id,
$r->pnotes('session')->{_session_id}, 0, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $args{journal_tva}, $args{44567}, 'CA3', $args{nom_periode}, - ( $args{total_tva_deductible_44567} + $args{total_tva_nette_due} ) * 100, 0, $token_id
) ;

	} #	( if $args{total_tva_nette_due > 0 ) {
	
	$dbh->do($sql, undef, @bind_array) ;

	#rediriger l'utilisateur vers le formulaire de saisie d'une écriture
	my $location = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $args{journal_tva} ). '&id_entry=0&redo=0&_token_id=' . $token_id ;
	
	$r->headers_out->set(Location => $location) ;

	return Apache2::Const::REDIRECT ;

    } else {

	my $content .= '' ;
	
	#on recherche à chaque fois les options tva pour être sûr que ce sont les bonnes
    my $option_set = Base::Site::bdd::get_info_societe($dbh, $r);

	$args{id_tva_periode} = $option_set->[0]->{id_tva_periode} ;

	$args{id_tva_option} = $option_set->[0]->{id_tva_option} ;

	$args{journal_tva} = $option_set->[0]->{journal_tva} ;

	#on recherche les comptes d'écriture des opérations de TVA, qui peuvent être codés sur 5 décimales ou plus
	$sql = q {
with t1 as (
SELECT numero_compte FROM tblcompte WHERE substring(numero_compte from 1 for 5) = '44566' AND id_client = ? AND fiscal_year = ? ORDER BY numero_compte limit 1 ),
t2 as (
SELECT numero_compte FROM tblcompte WHERE substring(numero_compte from 1 for 5) = '44567' AND id_client = ? AND fiscal_year = ? ORDER BY numero_compte limit 1 ),
t3 as (
SELECT numero_compte FROM tblcompte WHERE substring(numero_compte from 1 for 5) = '44581' AND id_client = ? AND fiscal_year = ? ORDER BY numero_compte limit 1 ),
t4 as (
SELECT numero_compte FROM tblcompte WHERE substring(numero_compte from 1 for 5) = '44551' AND id_client = ? AND fiscal_year = ? ORDER BY numero_compte limit 1 ),
t5 as (
SELECT numero_compte FROM tblcompte WHERE substring(numero_compte from 1 for 5) = '44571' AND id_client = ? AND fiscal_year = ? ORDER BY numero_compte limit 1 )
SELECT t1.numero_compte as "44566", t2.numero_compte as "44567", t3.numero_compte as "44581", t4.numero_compte as "44551", t5.numero_compte as "44571" 
FROM t1, t2, t3, t4, t5
} ;

	@bind_array = ( 
$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  
$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  
$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  
$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year},  
$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}
) ;

	my $compte_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

	unless ( $compte_set->[0]->{44566} ) {

	    $content = '<div class="wrapper100"><div class="warning"><h3>Un de ces comptes est manquant :</h3>
<ul>
<li>44551 TVA à décaisser</li>
<li>44566 TVA sur autres biens et services</li>
<li>44567 Crédit de TVA à reporter</li>
<li>44571 TVA collectée</li>
<li>44581 Acomptes de TVA</li>
</ul>
<p>Veuillez vérifier la liste des comptes
</div></div>
' ;
	 
	} else {

	    $args{44551} = $compte_set->[0]->{44551} ;
	    $args{44566} = $compte_set->[0]->{44566} ;
	    $args{44567} = $compte_set->[0]->{44567} ;
	    $args{44571} = $compte_set->[0]->{44571} ;
	    $args{44581} = $compte_set->[0]->{44581} ;
	    
	    $content .= periode( $r, \%args ) ;

	}

	if ( defined $args{fin_periode} ) {
#BUG : in fiscal_year = n-1 and fin_periode = n, calcule sur fin_periode = n-2
	    #on vérifie si la période est dans l'année fiscale en cours (fin_periode - 1 jour)
	    #sinon, on utilise l'année fiscale précédente
	    $sql = 'SELECT date_is_in_fiscal_year(?::date - 1, ?::date, ?::date)' ;

	    @bind_array = ( $args{fin_periode} , $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD} ) ;

	    $args{fiscal_year} = ( $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] eq 't' ) ? $r->pnotes('session')->{fiscal_year} : $r->pnotes('session')->{fiscal_year} - 1 ;
	    
	    $content .= declaration( $r, \%args ) ;
	    
	}

	$r->no_cache(1) ;
	
	$r->content_type('text/html; charset=utf-8') ;

	print $content ;

	return Apache2::Const::OK ;

    } #    if ( defined $args{total_tva_brute_due} ) 
    
}


1 ;


sub declaration {

    my ( $r, $args ) = @_ ;

    my ( $content, $tva_nette_due ) ;

    if ( defined $args->{nom_periode} ) {

	my $lines = '' ;

	$lines .= '<tr><td class=titre1 colspan=4>A - MONTANT DES OPÉRATIONS RÉALISÉES</td></tr>' ;

	$lines .= operations_imposables( $r, $args ) ;

	$lines .= operations_non_imposables( $r, $args ) ;

	$lines .= '<tr><td class=titre1 colspan=4>B - DÉCOMPTE DE LA TVA À PAYER</td></tr>' ;

	$lines .= tva_brute( $r, $args ) ;

	$lines .= tva_deductible( $r, $args ) ;

	#on calcule la tva nette 
	$args->{total_tva_nette_due} = $args->{total_tva_brute_due} - ( $args->{total_tva_deductible_4456} + $args->{total_tva_deductible_4458} ) ;
	
	$lines .= '<tr><td class=titre1 colspan=4>CREDITS</td></tr>' ;

	$lines .= credits( $args->{total_tva_nette_due} ) ;

	$lines .= '<tr><td class=titre1 colspan=4>TAXE A PAYER</td></tr>' ;

	$lines .= taxe_a_payer( $args->{total_tva_nette_due} ) ;
	
	$content .= '<table style="margin: auto; width: 60%;">' . $lines . '</table>' ;

	$content .= entry_form_data( $r, $args ) ;

    }
    
    return $content ;

} #sub declaration 


sub entry_form_data {

    my ( $r, $args ) = @_ ;

    my $content = '
<form action=/'.$r->pnotes('session')->{racine}.'/tva>
<input type=hidden name=nom_periode value=' . $args->{nom_periode} . '>
<input type=hidden name=total_tva_nette_due value=' . $args->{total_tva_nette_due} . '>
<input type=hidden name=total_tva_brute_due value=' . $args->{total_tva_brute_due} . '>
<input type=hidden name=total_tva_deductible_4456 value=' . $args->{total_tva_deductible_4456} . '>
<input type=hidden name=total_tva_deductible_44567 value=' . $args->{total_tva_deductible_44567} . '>
<input type=hidden name=total_tva_deductible_4458 value=' . $args->{total_tva_deductible_4458} . '>
<input type=hidden name=44551 value=' . $args->{44551} . '>
<input type=hidden name=44566 value=' . $args->{44566} . '>
<input type=hidden name=44567 value=' . $args->{44567} . '>
<input type=hidden name=44571 value=' . $args->{44571} . '>
<input type=hidden name=44581 value=' . $args->{44581} . '>
<input type=hidden name=journal_tva value="' . $args->{journal_tva} . '">
<p class=submit style="text-align: center;"><input type=submit value="Valider Formulaire 3310CA3">
</form>
' ;

    return $content ;
    
} #sub entry_form_data


sub taxe_a_payer {
 
    my $total_tva_nette_due = shift ;

    my $debit = ( $total_tva_nette_due > 0 ) ? $total_tva_nette_due : '' ;

    $debit =~ s/\B(?=(...)*$)/ /g ;

    my $content .= '<tr><td class=caseRepere>25</td><td class=caseBase colspan=2>TVA nette due (ligne 16 - ligne 23)</td><td class=caseARemplir>' . $debit . '</td></tr>' ;

    return $content ;
    
} #sub taxe_a_payer


sub credits {
 
    my $total_tva_nette_due = shift ;

    my $credit = ( $total_tva_nette_due < 0 ) ? -$total_tva_nette_due : '' ;

    $credit =~ s/\B(?=(...)*$)/ /g ;
    
    my $content .= '<tr><td class=caseRepere>25</td><td class=caseBase colspan=2>Crédit de TVA (ligne 23 - ligne 16)</td><td class=caseARemplir>' . $credit . '</td></tr>' ;

    return $content ;
    
} #sub credits


sub tva_deductible {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;
    
    #taxes sur le chiffre d'affaires déductibles; dans tous les cas,
    #on prend la différence entre debit et credit des écritures jusqu'à la fin de la période
    $sql = q {
with t1 as (
SELECT substring(numero_compte from 1 for 5) as tva_deduct_line, sum(debit - credit)/100 as montant
FROM tbljournal INNER JOIN tblcompte using (id_client, fiscal_year, numero_compte)
WHERE substring(numero_compte from 1 for 4) = '4456' AND id_client = ? AND fiscal_year = ? AND date_ecriture <= ? 
group by substring(numero_compte from 1 for 5)
)
SELECT tva_deduct_line, to_char(montant, '999G999G990') as montant, sum(montant) over () as total_tva_deductible_4456 from t1
} ;

    @bind_array = ( $r->pnotes('session')->{id_client}, $args->{fiscal_year}, $args->{fin_periode} ) ;
    
    my $result_set = $dbh->selectall_hashref( $sql, 'tva_deduct_line', { Slice => { } }, @bind_array ) ;

    #on ne peut pas savoir quelles variantes de TVA seront présentes dans le hash, mais le total_tva_brute_due est identique dans tous les cas 
    #on prend toutes les lignes pour extraire la valeur
    my $total_tva_deductible_4456 = 0; 
    
    for ( keys %$result_set ) { $total_tva_deductible_4456 = $result_set->{$_}->{total_tva_deductible_4456} };

    #conserver le total pour les calculs
    $args->{total_tva_deductible_4456} = $total_tva_deductible_4456 ; 

    #on a besoin du montant de report du crédit pour le compenser dans les écritures
    $args->{total_tva_deductible_44567} = $result_set->{'44567'}->{montant} || 0 ;
    
    #le mettre en forme pour l'affichage
    $total_tva_deductible_4456 =~ s/\B(?=(...)*$)/ /g ;

    my $content = '<tr><td class=titre2 colspan=4>TVA DÉDUCTIBLE</td></tr>' ;
	
    $content .= '<tr><td class=caseRepere>19</td><td class=caseBase colspan=2>Biens constituant des immobilisations</td><td class=caseARemplir>' . ( $result_set->{'44562'}->{montant} || '' ) . '</td></tr>' ;

    $content .= '<tr><td class=caseRepere>20</td><td class=caseBase colspan=2>Autres biens et services</td><td class=caseARemplir>' . ( $result_set->{'44566'}->{montant} || '' ) . '</td></tr>' ;

    $content .= '<tr><td class=caseRepere>21</td><td class=caseBase colspan=2>Autres TVA à déduire</td><td class=caseARemplir>' . ( $result_set->{'44563'}->{montant} || '' ) . '</td></tr>' ;

    $content .= '<tr><td class=caseRepere>22</td><td class=caseBase colspan=2>Report du crédit apparaissant ligne 27 de la précédente déclaration</td><td class=caseARemplir>' . ( $result_set->{'44567'}->{montant} || '' ) . '</td></tr>' ;

    #Taxes sur le CA à régulariser ou en attente
    $sql = q { 
SELECT substring(numero_compte from 1 for 4) as tva_deduct_line, sum(debit - credit)/100 as total_tva_deductible_4458
FROM tbljournal INNER JOIN tblcompte using (id_client, fiscal_year, numero_compte)
WHERE substring(numero_compte from 1 for 4) = '4458' AND id_client = ? AND fiscal_year = ? AND date_ecriture <= ?
group by substring(numero_compte from 1 for 4)
} ;
   
    @bind_array = ( $r->pnotes('session')->{id_client}, $args->{fiscal_year}, $args->{fin_periode} ) ;
    
    $result_set = $dbh->selectall_hashref( $sql, 'tva_deduct_line', { Slice => { } }, @bind_array ) ;

    my $total_tva_deductible_4458 = $result_set->{'4458'}->{total_tva_deductible_4458} || 0 ;

    #conserver le total pour les calculs
    $args->{total_tva_deductible_4458} = $total_tva_deductible_4458 ;

    #le mettre en forme pour l'affichage
    $total_tva_deductible_4458 =~ s/\B(?=(...)*$)/ /g ;
    
    $content .= '<tr><td class=caseRepere>2C</td><td class=caseBase colspan=2>Sommes à imputer, y compris acomptes congés</td><td class=caseARemplir>' . ( $total_tva_deductible_4458 || '' ) . '</td></tr>' ;

    #ligne récapitulative
    my $total_tva_deductible = $args->{total_tva_deductible_4456} + $args->{total_tva_deductible_4458} ;

    #la mettre en forme pour l'affichage
    $total_tva_deductible =~ s/\B(?=(...)*$)/ /g ;

    $content .= '<tr><td class=caseRepere>23</td><td class=caseBase colspan=2><strong>Total TVA deductible</strong></td><td class=caseARemplir>' . ( $total_tva_deductible || '' ) . '</td></tr>' ;
    
    return $content ;

} #sub tva_deductible 


sub tva_brute {
    
    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;

    my $where_clause ;

    if ( $args->{id_tva_option} eq 'encaissements' ) {
	
	#on recherche les écritures antérieures à la date butoir qui sont pointées et non lettrées
	$where_clause = ' AND date_ecriture <= ? AND pointage = FALSE AND lettrage is not null ' ;

	@bind_array = ( $r->pnotes('session')->{id_client}, $args->{fin_periode} ) ;

    } else {

	#on recherche toutes les écritures dans la période recherchée
	if ( $args->{id_tva_periode} eq 'trimestrielle' ) {
	    
	    $where_clause = ' AND fiscal_year = ? AND to_char(date_ecriture, \'Q\') = to_char(?::date, \'Q\') ' ;

	} else {

	    $where_clause = ' AND fiscal_year = ? AND to_char(date_ecriture, \'MM\') = to_char(?::date, \'MM\') ' ;
	    
	} #	if ( $args->{id_tva_periode} eq 'trimestrielle' )

	@bind_array = ( $r->pnotes('session')->{id_client}, $args->{fiscal_year}, $args->{fin_periode} ) ;
	
    } #    if ( $args->{id_tva_option} eq 'encaissements' )  

    $sql = q { 
with t1 as (
SELECT default_id_tva, sum(credit) as base_ht, sum(credit) * default_id_tva/100 as taxe_due
FROM tbljournal INNER JOIN tblcompte using (id_client, fiscal_year, numero_compte)
WHERE substring(numero_compte from 1 for 1) = '7' AND substring(numero_compte from length(numero_compte) for 1) not like '*' AND id_client = ? } . $where_clause . q { AND default_id_tva > 0
group by default_id_tva
),
t2 as ( SELECT unnest(ARRAY[20.00, 5.50, 10.00, 8.50, 2.10]) as default_id_tva )
SELECT t2.default_id_tva, to_char(t1.base_ht/100, '999G999G990') as base_ht, to_char(t1.taxe_due/100, '999G999G990') as taxe_due, (sum(t1.taxe_due) over ()/100)::integer as total_tva_brute_due FROM t1 RIGHT JOIN t2 using (default_id_tva) 
} ;

    my $result_set = $dbh->selectall_hashref( $sql, 'default_id_tva', { Slice => { } }, @bind_array ) ;

    #on ne peut pas savoir quelles variantes de TVA seront présentes dans le hash, mais le total_tva_brute_due est identique dans tous les cas 
    #on prend toutes les lignes pour extraire la valeur
    my $total_tva_brute_due ;

    for ( keys %$result_set ) { $total_tva_brute_due = $result_set->{$_}->{total_tva_brute_due} };

    #éviter uninitialized value s'il n'y a rien à déclarer
    $total_tva_brute_due ||= 0 ;
    
    #conserver le total pour le calcul
    $args->{total_tva_brute_due} = $total_tva_brute_due ;

    #le mettre en forme pour l'affichage
    $total_tva_brute_due =~ s/\B(?=(...)*$)/ /g ;
    
    my $content = '<tr><td class=titre2 colspan=4>TVA BRUTE</td></tr>' ;

    $content .= '<tr><td class=titre3 colspan=2>OPÉRATIONS RÉALISÉES EN FRANCE METROPOLITAINE</td><td class=titre3>Base hors taxe</td><td class=titre3>Taxe due</td></tr>' ;

    $content .= '<tr><td class=caseRepere>08</td><td class=caseBase>Taux normal 20%</td><td class=caseARemplir>' . ( $result_set->{'20.00'}->{base_ht} || '' ) . '</td><td class=champCalcule>' . ( $result_set->{'20.00'}->{taxe_due} || 0 ) . '</td></tr>' ;
    
    $content .= '<tr><td class=caseRepere>09</td><td class=caseBase>Taux réduit 5.5%</td><td class=caseARemplir>' . ( $result_set->{'5.50'}->{base_ht} || '' ) . '</td><td class=champCalcule>' . ( $result_set->{'5.50'}->{taxe_due} || 0 ) . '</td></tr>' ;

    $content .= '<tr><td class=caseRepere>09B</td><td class=caseBase>Taux réduit 10%</td><td class=caseARemplir>' . ( $result_set->{'10.00'}->{base_ht} || '' ) . '</td><td class=champCalcule>' . ( $result_set->{'10.00'}->{taxe_due} || 0 ) . '</td></tr>' ;

    $content .= '<tr><td class=titre3 colspan=2>OPÉRATIONS RÉALISÉES DANS LES DOM</td><td class=titre3>Base hors taxe</td><td class=titre3>Taxe due</td></tr>' ;

    $content .= '<tr><td class=caseRepere>10</td><td class=caseBase>Taux normal 8.5%</td><td class=caseARemplir>' . ( $result_set->{'8.50'}->{base_ht} || '' ) . '</td><td class=champCalcule>' . ( $result_set->{'8.50'}->{taxe_due} || 0 ) . '</td></tr>' ;
    
    $content .= '<tr><td class=caseRepere>11</td><td class=caseBase>Taux réduit 2.1%</td><td class=caseARemplir>' . ( $result_set->{'2.10'}->{base_ht} || '' ) . '</td><td class=champCalcule>' . ( $result_set->{'2.10'}->{taxe_due} || 0 ) . '</td></tr>' ;

    $content .= '<tr><td class=caseRepere>16</td><td class=caseBase colspan=2>Total de la TVA brute due</td><td class=champCalcule>' . ( $total_tva_brute_due || '' ) . '</td></tr>' ;
    
    return $content ;

} #sub tva_brute 


sub operations_non_imposables {
   
    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;
    
    my $where_clause ;

    if ( $args->{id_tva_option} eq 'encaissements' ) {
	
	#on recherche les écritures antérieures à la date butoir qui sont lettrées mais non pointées
	$where_clause = ' AND date_ecriture <= ? AND pointage = FALSE AND lettrage IS NOT NULL ' ;

    } else {

	#on recherche toutes les écritures dans la période recherchée
	if ( $args->{id_tva_periode} eq 'trimestrielle' ) {
	    
	    $where_clause = ' AND to_char(date_ecriture, \'Q\') = to_char(?::date, \'Q\') ' ;

	} else {

	    $where_clause = ' AND to_char(date_ecriture, \'MM\') = to_char(?::date, \'MM\') ' ;
	    
	} #	if ( $args->{id_tva_periode} eq 'trimestrielle' )
	
    } #    if ( $args->{id_tva_option} eq 'encaissements' )  

    #autres opérations réalisées non imposables : default_id_tva = 0
    $sql = q { SELECT to_char(coalesce(sum(t1.credit)/100, 0), '999G999G990') FROM tbljournal t1 INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) WHERE substring(t1.numero_compte from 1 for 1) = '7' AND id_client = ? AND substring(numero_compte from length(numero_compte) for 1) not like '*' AND fiscal_year = ? } . $where_clause . q { and t2.default_id_tva = 0 } ;
    
    @bind_array = ( $r->pnotes('session')->{id_client}, $args->{fiscal_year}, $args->{fin_periode} ) ;
    
    my $total = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

    my $content = '<tr><td class=titre2 colspan=4>OPERATIONS NON IMPOSABLES</td></tr>' ;

    $content .= '<tr><td class=caseRepere>05</td><td class=caseBase colspan=2>Autres opérations non imposables</td><td class=caseARemplir>' . ( $total || '' ) . '</td></tr>' ;

    return $content ;

} #sub operations_non_imposables 


sub operations_imposables {
   
    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;

    my $where_clause ;

    if ( $args->{id_tva_option} eq 'encaissements' ) {
	
	#on recherche les écritures antérieures à la date butoir qui sont lettrées et non pointées
	$where_clause = ' AND date_ecriture <= ? AND pointage = FALSE AND lettrage IS NOT NULL ' ;

    } else {

	#on recherche toutes les écritures dans la période recherchée
	if ( $args->{id_tva_periode} eq 'trimestrielle' ) {
	    
	    $where_clause = ' AND to_char(date_ecriture, \'Q\') = to_char(?::date, \'Q\') ' ;

	} else {

	    $where_clause = ' AND to_char(date_ecriture, \'MM\') = to_char(?::date, \'MM\') ' ;
	    
	} #	if ( $args->{id_tva_periode} eq 'trimestrielle' )
	
    } #    if ( $args->{id_tva_option} eq 'encaissements' )  
    
    #opérations réalisées imposables : default_id_tva > 0
    $sql = q { SELECT to_char(coalesce(sum(t1.credit)/100, 0), '999G999G990') FROM tbljournal t1 INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) WHERE substring(t1.numero_compte from 1 for 1) = '7' AND id_client = ? AND fiscal_year = ? } . $where_clause . q { and t2.default_id_tva > 0 } ;
    
    @bind_array = ( $r->pnotes('session')->{id_client}, $args->{fiscal_year}, $args->{fin_periode} ) ;
    
    my $total = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

    my $content = '<tr><td class=titre2 colspan=4>OPERATIONS IMPOSABLES (HT)</td></tr>' ;

    $content .= '<tr><td class=caseRepere>01</td><td class=caseBase colspan=2>Ventes, prestations de service</td><td class=caseARemplir>' . ( $total || '' ) . '</td></tr>' ;

    return $content ;

} #sub operations_imposables


sub periode {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my $content = '' ;
    
    my ( $sql, @bind_array ) ;
    
    #recherche des périodes de déclaration
    #value est le jour d'après la fin de la période de déclaration (01-04 pour 1TR/Mars)
    #option est le nom de la période à déclarer
    if ( $args->{id_tva_periode} eq 'mensuelle' ) {
    
	$sql = q { SELECT date_trunc('MONTH', current_date - (s.m || 'months')::interval)::DATE - 1 as value, to_char(date_trunc('MONTH', current_date - (s.m || 'months')::interval)::DATE - '1 day'::interval, 'TMMonth') || to_char(date_trunc('MONTH', current_date - (s.m || 'months')::interval)::DATE - '1 day'::interval, ' YYYY') as option from generate_series(-1, 11) as s(m) } 

    } else {

	$sql = q { SELECT date_trunc('QUARTER', current_date - (s.m * 3 || 'months')::interval)::DATE - 1 as value, to_char(date_trunc('QUARTER', current_date - (s.m * 3 || 'months')::interval)::DATE - '1 day'::interval, 'QTR') || to_char(date_trunc('QUARTER', current_date - (s.m * 3 || 'months')::interval)::DATE - '1 day'::interval, ' YYYY') as option from generate_series(-1,3) as s(m) }
    
    } #    if ( $args->{id_tva_periode} eq 'mensuelle' ) 

    my $select_periode = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( ) ) ;

    my $select_box = '' ;
    
    #on sélectionne par défaut le premier de la liste, qui correspond normalement à la période à déclarer à la date du jour
    #sauf si l'utilisateur a déjà sélectionné une période
    my $selected = ( defined $args->{fin_periode} ) ? '' : 'selected' ;

    #on passe le nom de la période dans le hidden input qui va bien
    my $nom_periode = ( defined $args->{fin_periode} ) ? '' : $select_periode->[0]->{option} ;
    
    for ( @$select_periode ) {

	$selected = ( defined $args->{fin_periode} and $args->{fin_periode} eq $_->{value} ) ? 'selected' : '' ;

	$nom_periode =  $_->{option} if ( defined $args->{fin_periode} and $args->{fin_periode} eq $_->{value} ) ;
	
	$select_box .= '<option ' . $selected . ' value="' . $_->{value} . '">' . $_->{option} . '</option>' ;

    }

    #script de mise à jour de la valeur de input nom_periode, si l'utilisateur ne choisit pas la première option
    $content = '<script>
var update_nom_periode = function(input) {

document.getElementById("nom_periode").value = input.options[input.selectedIndex].text

}

</script>' ;

    $content .= '<div class="wrapper100 centrer"><form action="/'.$r->pnotes('session')->{racine}.'/tva" method=post>
<h3 class=submit>Période 
<select id=fin_periode name=fin_periode onchange="update_nom_periode(this)">' . $select_box . '</select> 
<input type=hidden name=id_tva_option value="' . $args->{id_tva_option} . '">
<input type=hidden name=id_tva_periode value="' . $args->{id_tva_periode} . '">
<input type=hidden id=nom_periode name=nom_periode value="' . $nom_periode . '">
<input type=submit value="Calculer Formulaire 3310CA3"> <a href="/'.$r->pnotes('session')->{racine}.'/menu#tva" class="decoff">(Aide)</a></h3>
</form></div>' ;

    return $content ;

} #sub periode 


