package Base::Function::cerfa_2 ;
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

use utf8 ;
use strict ;
use warnings ;
1 ;


sub visualize {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;
    
    my $content = '<div style="background-image: url(/images/cerfa/2033BNM1.png); height: 1479px; width: 960px">';

    my $sql = '' ;

    my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;

    $content .= '<pre>' . Data::Dumper::Dumper($result_set) . '</pre></div>' ;

    return $content

} #sub visualize


sub liste {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;
    
    my $gerer_href = '/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2&amp;gestion=0' ;

    my $content = '<table><tr><td><h3>Détail des calculs du document 2033-B (Compte de résultats simplifié)</h3></td><td><a class=nav href="' . $gerer_href . '" style="margin-left: 3ch;">Gérer</a></td></tr></table>';

    #pour les comptes de produits (credit_first=true), on calcule sum(credit-debit)
    #pour les comptes de charges (credit_first=false), on calcule sum(debit-credit)
    my $sql = '
with t1 as (
SELECT t1.id_entry, t1.id_item, t1.id_client, t1.fiscal_year, t1.credit_first, t2.numero_compte
FROM tblcerfa_2 t1 INNER JOIN tblcerfa_2_detail t2 using (id_entry)
WHERE t1.id_client = ? AND t1.fiscal_year = ?
), t3 as (
SELECT t1.id_item, t1.id_client, t1.fiscal_year, t1.numero_compte, CASE WHEN t1.credit_first = TRUE THEN coalesce(sum(credit - debit)/100::numeric,0) ELSE coalesce(sum(debit - credit)/100::numeric,0) END as total_compte
FROM t1 LEFT JOIN tbljournal t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.numero_compte = t2.numero_compte 
GROUP BY id_item, t1.id_client, t1.fiscal_year, t1.numero_compte, credit_first
ORDER BY t1.id_item, t1.numero_compte
)
SELECT t3.id_item, t3.numero_compte, t4.libelle_compte, to_char(t3.total_compte, \'999G999G999G990D00\') as total_compte, to_char(sum(t3.total_compte) over (partition by t3.id_item), \'999G999G999G990D00\') as total_item, row_number() over (partition by t3.id_item) as order_item
FROM t3 INNER JOIN tblcompte t4 using (id_client, fiscal_year, numero_compte)
' ;    
        
    my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;

    my $item_list = '' ;

    for ( @$result_set ) {

	#si c'est le premier enregistrement ajouter le id_item en header
	if ( $_->{order_item} eq '1' ) {

	    $item_list .= '
<li class=listitem3><div class=container><div class=spacer></div>
<span class=headerspan style="width: 15ch;">Case : ' . $_->{id_item} . '</span>
<span class=headerspan style="width: 23ch;">Montant : ' . $_->{total_item} . '</span>
<span class=headerspan style="width: 61ch;">&nbsp;</span>
<div class=spacer></div></div></li>' ;

	} #	if ( $_->{order_item} eq '1' ) 

	my $compte_href = '/'.$r->pnotes('session')->{racine}.'/compte?numero_compte=' . URI::Escape::uri_escape_utf8( $_->{numero_compte} ) . '&amp;libelle_compte=' . URI::Escape::uri_escape_utf8( $_->{libelle_compte} ) ;
	
	$item_list .= '
<li class=listitem3><div class=container><div class=spacer></div><a href="' . $compte_href . '">
<span class=blockspan style="width: 23ch;">&nbsp;</span>
<span class=blockspan style="width: 15ch;">' . $_->{numero_compte} . '</span>
<span class=blockspan style="width: 30ch;">' . $_->{libelle_compte} . '</span>
<span class=blockspan style="width: 15ch; text-align: right;">' . $_->{total_compte} . '</span>
</a><div class=spacer></div></div></li>' ;

    } #    for ( @$result_set ) 

    $content .= '<ul>' . $item_list . '</ul>' ;

    #liste des comptes utilisés mais non affectés
	
    return $content ;
	
} #sub liste


sub gestion {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my $sql ;

    #titre
    my $content = '<table><tr><td><h3>Gestion du document 2033-B (Compte de résultats simplifié - Cerfa n° 2)</h3></td><td><a href="/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2" style="margin-left: 3ch;">Retour</a></td></tr></table>';

    #l'utilisateur a demandé la suppression d'une case
    if ( defined $args->{delete_case} ) {

	#demander confirmation d'abord
	if ($args->{delete_case} eq '1' ) {

	    my $sql = 'DELETE FROM tblcerfa_2 WHERE id_item = ? AND id_client = ? AND fiscal_year = ?' ;

	    my @bind_array = ( $args->{id_item}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

	    $dbh->do($sql, undef, @bind_array) ;

	} else {
	    
	    my $oui_href = '/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2&amp;gestion=0&amp;delete_case=1&amp;id_item=' . $args->{id_item} ;

	    my $non_href = '/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2&amp;gestion=0' ;
	    
	    #si delete_case eq '0', demander la confirmation
	    $content .= '<h3 class=warning>Vraiment supprimer la case ' . $args->{id_item} . '?<a href="' . $oui_href . '" style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" style="margin-left: 3ch;">Non</a></h3>' ;

	}

    }#    if ( defined $args->{delete_case} ) 

    #l'utilisateur a demandé l'ajout d'une case; on n'enregistre que si le libellé n'est pas vide
    if ( defined $args->{add_case} and ( $args->{add_case} ) ) {

	$sql = 'INSERT INTO tblcerfa_2 (id_item, id_client, fiscal_year, credit_first) values (?, ?, ?, ?)' ;

	my @bind_array = ( $args->{add_case}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $args->{credit_first} ) ;

	eval { $dbh->do( $sql, undef, @bind_array ) } ;

	if ( $@ ) {
	    
	    if ( $@ =~ /unique_item_per_year/ ) {

		$content .= '<h3 class=warning>Cette case est déjà dans la liste</h3>'
		    
	    } else {
		
		$content .= '<h3 class=warning>' . $@ . '</h3>'

	    }
		
	} #	if ( $@ ) 

    } #        if ( defined $args->{add_case} and ( $args->{add_case} ) ) 
    
    #si l'utilisateur a demandé l'ajout d'un compte, procéder d'abord, si le libellé n'est pas vide
    if ( defined $args->{add_included_compte} and ( $args->{add_included_compte} ) ) {

	#on tente d'insérer le compte; s'il est déjà utilisé ou inconnu, les triggers sur tblcerfa_2_detail déclenchent une erreur
	$sql = 'INSERT into tblcerfa_2_detail (id_entry, numero_compte) values (?, ?)' ;
	
	my @bind_array = ( $args->{id_entry}, $args->{add_included_compte}) ;

	eval { $dbh->do( $sql, undef, @bind_array ) } ;

	if ( $@ ) {

	    if ( $@ =~ /account already in use/ ) {

		$content .= '<h3 class=warning>Ce numéro de compte est déjà inclus dans les calculs</h3>' ;

	    }  elsif ( $@ =~ /bad account number/ ) {

		$content .= '<h3 class=warning>Numéro de compte invalide : ' . $args->{add_included_compte} . '</h3>' ;
		
	    } else {
		
		$content .= '<h3 class=warning>' . $@ . '</h3>' ;

	    }
	    
	} # 	    if ( $@ ) {

	
    }#    if ( defined $args->{add_included_compte} and ( $args->{add_included_compte} ) ) 
    
    #si l'utilisateur a demandé la suppression d'un compte, procéder d'abord
    if ( defined $args->{remove_included_compte} ) {

	#on valide que la ligne supprimée appartient bien au client pour empêcher des requêtes malveillantes
	$sql = 'DELETE FROM tblcerfa_2_detail WHERE id_entry = ? and numero_compte = ? and id_entry in (select id_entry from tblcerfa_2 where id_client = ? and fiscal_year = ?)';

	my @bind_array = ( $args->{id_entry}, $args->{remove_included_compte}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

	$dbh->do( $sql, undef, @bind_array ) ;

    }
        
    $sql = '
with t1 as (SELECT t1.id_entry, id_item, id_client, fiscal_year, numero_compte
FROM tblcerfa_2 t1 LEFT JOIN tblcerfa_2_detail using (id_entry)
WHERE id_client = ? AND fiscal_year = ?
ORDER BY id_item
)
SELECT t1.id_entry, t1.id_item, t1.numero_compte, t2.libelle_compte, row_number() over (partition by t1.id_item order by t1.numero_compte) as order_item
FROM t1 LEFT JOIN tblcompte t2 ON t1.id_client = t2.id_client AND t1.fiscal_year = t2.fiscal_year AND t1.numero_compte = t2.numero_compte 
ORDER BY 2, 3
' ;

    my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;

    my ( $item_list, $used_accounts ) = ( '', '' ) ;

    for ( @$result_set ) {

	#si c'est le premier enregistrement ajouter le id_item en header
	if ( $_->{order_item} eq '1' ) {

	    #lien d'ajout d'un compte à la liste
	    my $add_compte_form = '
<input type=text name=add_included_compte>
<input type=hidden name=gestion value=0>
<input type=hidden name=form_id value=cerfa_2>
<input type=hidden name=id_entry value=' . $_->{id_entry} . '>
<input type=submit value=Valider>' ;

	    my $delete_case_link = '&nbsp;' ;
	    
	    unless ( $_->{numero_compte} ) { #si on a un compte dans la liste; suppression de la case impossible

		#lien de suppression d'une case
		my $delete_case_href = '/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2&amp;gestion=0&amp;delete_case=0&amp;id_item=' . $_->{id_item} ;

		#si le premier numéro de compte est vide, la case est vide
		#dans ce cas on affiche le lien de suppression
		$delete_case_link =  '<a href="' . $delete_case_href . '" style="margin-left: 3ch;"  title="Supprimer cette case">Supprimer cette case</a> ' ;

	    } #unless ( $_->{numero_compte} )
	    
	    $item_list .= '<hr><div><form action="/'.$r->pnotes('session')->{racine}.'/liasse_fiscale" method=POST><table><tr>
<td><h2>' . $_->{id_item} . '</h2></td><td class=classic style="padding-left: 3ch;">Ajouter un compte ' . $add_compte_form . '</td><td>' . $delete_case_link . '</td></tr></table></form></div>
' ;
	   
	} #	if ( $_->{order_item} eq '1' ) 

	if ( $_->{numero_compte} ) { #on a un compte dans la liste; l'afficher avec le lien de suppression du compte
	    
	#lien de suppression d'un compte de la liste
	my $delete_compte_href = '<a href="/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2&amp;gestion=0&amp;id_entry=' . $_->{id_entry} . '&amp;remove_included_compte=' . $_->{numero_compte} . '" title="Supprimer ce compte">Supprimer ce compte</a>' ;

	$used_accounts .= '
<tr>
<td style="padding-left: 3ch;">' . $_->{numero_compte} . '</td>
<td style="padding-left: 3ch; width: 50%; text-align: left;">' . $_->{libelle_compte} . '</td>
<td style="padding-left: 3ch;">' . $delete_compte_href. '</td>
</tr>' ;

	} #if ( $_->{numero_compte} )

	$item_list .= '<table style="width: 80%;">' . $used_accounts . '</table>' ;

	$used_accounts  = ''  ;
	
    } #    for ( @$result_set ) 

    #lien d'ajout d'une case à la liste
    my $add_case_form = '
<input type=text name=add_case style="width: 10ch;">
<input type=radio name=credit_first value=false checked>Charges
<input type=radio name=credit_first value=true>Produits
<input type=hidden name=gestion value=0>
<input type=hidden name=form_id value=cerfa_2>
<input type=submit value=Valider>' ;
	    
    $item_list .= '<div><form action="/'.$r->pnotes('session')->{racine}.'/liasse_fiscale" method=POST>
<ul>
<li class=listitem3><div class=container><div class=spacer></div>
<span class=headerspan style="width: 73ch; margin: 3ch; padding: 3ch;"><strong>Ajouter une case</strong>' . $add_case_form . '</span>
<div class=spacer></div></div></li>
</ul>
</form></div>
' ;

    $content .= $item_list ;

    #on construit une liste des comptes non enregistrés dans tblcerfa_2_detail
    $sql = 'SELECT t2.numero_compte, t2.libelle_compte, to_char(greatest(0, coalesce(sum(t1.debit - t1.credit), 0))/100::numeric, \'999G999G999G990D00\') as debit, to_char(greatest(0, coalesce(sum(t1.credit - t1.debit), 0))/100::numeric, \'999G999G999G990D00\') as credit
FROM tblcerfa_2_unused_accounts(?, ?) t2 left join tbljournal t1 using (numero_compte, id_client, fiscal_year)
group by t2.numero_compte, t2.libelle_compte' ;

    my @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
    
    my $unused_accounts_list = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

    #liste des comptes non utilisés
    $content .= '<h3>Comptes restant à inclure</h3>' ;

    my $rows = '<tr><td class=titre3 style="padding-left: 3ch;">Compte</td><td class=titre3 style="padding-left: 3ch;">Libellé</td><td class=titre3 style="padding-left: 3ch; text-align: right;">Débit</td><td class=titre3 style="padding-left: 3ch; text-align: right;">Crédit</td></tr>' ;
    
    for ( @$unused_accounts_list ) {

	$rows .= '<tr><td style="padding-left: 3ch;">' . $_->{numero_compte} . '</td><td style="padding-left: 3ch;">' . $_->{libelle_compte} . '</td><td style="padding-left: 3ch; text-align: right;">' . $_->{debit} . '</td><td style="padding-left: 3ch; text-align: right;">' . $_->{credit} . '</td></tr>' ;

    }

    $content .= '<table>' . $rows . '</table>' ;
    
    return $content ;
    
} #sub gestion

