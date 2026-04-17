package Base::Handler::fiscal_year;
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

use strict;  # Utilisation stricte des variables
use warnings;  # Activation des avertissements
use Time::Piece;       # Manipulation de dates et heures
use Base::Site::util;  # Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   # Interaction avec la base de données (SQL)
use utf8;              # Encodage UTF-8 pour le script
use Apache2::Const -compile => qw( OK REDIRECT ) ;

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    #utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content = '<div class="wrapper100"><div class="centrer"><h2>Sélectionnez l\'exercice</h2></div>' ;

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

    #si on a une nouvelle année fiscale, l'enregistrer dans la session et rediriger vers /'.$r->pnotes('session')->{racine}.'/journaux
    if ( defined $args{new_fiscal_year} ) {

		refresh_date( $r, \%args ) ;
		#rediriger l'utilisateur vers la page d'accueil
		my $location = '/'.$r->pnotes('session')->{racine}.'/' ;
		$r->headers_out->set(Location => $location) ;
		return Apache2::Const::REDIRECT ;

    } else {

		$content .= select_fiscal_year( $r, \%args ) ;
		$content .= '</div>';
		$r->no_cache(1) ;
		$r->content_type('text/html; charset=utf-8') ;
		print $content ;
		return Apache2::Const::OK ;

    }
    
}

sub refresh_date {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, @errors) ;
	my ($date_fin_exercice_N, $date_fin_exercice_N1, $date_debut_exercice_N, $date_fin_exercice_N_bis, $date_debut_exercice_N_bis);
	
	#recherche de l'offset pour l'année considérée
	$sql = '
	SELECT (?::integer || \'-\' || fiscal_year_start)::date - (?::integer || \'-01-01\')::date as fiscal_year_offset, date_debut, date_fin, fiscal_year_start 
	FROM compta_client 
	WHERE id_client = ?
	' ;

	@bind_array = ( $args->{new_fiscal_year}, $args->{new_fiscal_year}, $r->pnotes('session')->{id_client} ) ;
	my $result_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array ) ;

    #Récupérer date de fin d'exercice
    if ( $result_set->[0]->{fiscal_year_offset} ) {
		my $month_offset = Time::Piece->strptime($result_set->[0]->{fiscal_year_offset}, "%m"); # Formate la date mois de fiscal_year_offset (mois précédent)
		my $month_offset_two = $month_offset->strftime("%m"); # Formate la date mois de fiscal_year_offset de 1 digit vers 2 (mois précédent)
		my $month_offset_last_day = $month_offset->month_last_day; # Calcul le dernier jours du mois de fiscal_year_offset du mois précédent
		$date_fin_exercice_N = $month_offset_last_day.'/'.$month_offset_two.'/'.($args->{new_fiscal_year}+1);
		$date_fin_exercice_N_bis = ($args->{new_fiscal_year}+1).'-'.$month_offset_two.'-'.$month_offset_last_day;	
		$date_fin_exercice_N1 = $month_offset_last_day.'/'.$month_offset_two.'/'.($args->{new_fiscal_year} );
	} else {
		$date_fin_exercice_N = '31/12/'.$args->{new_fiscal_year} ;
		$date_fin_exercice_N_bis = $args->{new_fiscal_year} .'-12-31';
		$date_fin_exercice_N1 = '31/12/'. ($args->{new_fiscal_year} - 1);
    }
    
    #Récupérer date de début d'exercice
	if 	($result_set->[0]->{date_fin} eq $date_fin_exercice_N) {
		$date_debut_exercice_N = $result_set->[0]->{date_debut};
		$date_debut_exercice_N_bis = Time::Piece->strptime( $date_debut_exercice_N, "%d/%m/%Y" )->ymd;
	} else {
		$date_debut_exercice_N = $result_set->[0]->{fiscal_year_start}. '/'. ($args->{new_fiscal_year}) ;
		$date_debut_exercice_N =~ s/-/\//g;	
		$date_debut_exercice_N_bis = Time::Piece->strptime( $date_debut_exercice_N, "%d/%m/%Y" )->ymd;
	}
	
	# #si fiscal_year_offset > 0, la fin de l'exercice est toujours dans l'année suivante
	if ( $result_set->[0]->{fiscal_year_offset} > 0 ) {
		$args->{new_fiscal_year} ++ ;
	}	
	
	#les 12 mois sont bloqués ? si oui on est sur un exercice cloturé
	$sql = q [
	with t1 as ( SELECT id_client FROM tbllocked_month WHERE id_client = ? AND fiscal_year = ?)
	SELECT count(id_client) FROM t1
	] ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $args->{new_fiscal_year} ) ;
	my $en_attente_count;
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	$r->pnotes('session')->{Exercice_Cloture} = ($en_attente_count eq '12') ? 1 : 0;
	$r->pnotes('session')->{fiscal_year_offset} = $result_set->[0]->{fiscal_year_offset};
	$r->pnotes('session')->{fiscal_year} = $args->{new_fiscal_year};
	$r->pnotes('session')->{Exercice_fin_DMY} = $date_fin_exercice_N;
	$r->pnotes('session')->{Exercice_fin_YMD} = $date_fin_exercice_N_bis;
	$r->pnotes('session')->{Exercice_debut_DMY} = $date_debut_exercice_N;
	$r->pnotes('session')->{Exercice_debut_YMD} = $date_debut_exercice_N_bis;
	$r->pnotes('session')->{Exercice_fin_DMY_N1} = $date_fin_exercice_N1;
	# supprimer d'abord les données éventuellement présentes dans tbljournal_staging pour cet utilisateur	
	#Base::Site::bdd::clean_tbljournal_staging( $r );
	Base::Handler::parametres::freeze_session( $r ) ;
	return; # Fin de la fonction
}

sub select_fiscal_year {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $create_date ;
    
    #paramètres généraux du client
    my $sql = 'SELECT (EXTRACT(YEAR FROM date_fin)) AS datecreate FROM compta_client WHERE id_client = ?' ;
    my $resultdate_set = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $r->pnotes('session')->{id_client} ) ) ;

    if ( $r->pnotes('session')->{fiscal_year_offset} ) {
		$create_date = $resultdate_set->[0]->{datecreate} - 1 ;	
		#on veut la liste des années fiscales depuis la date de création jusqu'à l'année en cours
		$sql = 'SELECT s.a FROM generate_series('. $create_date.', (SELECT EXTRACT(YEAR FROM CURRENT_DATE))::integer) AS s(a) ORDER BY 1 DESC';
	} else {
		$create_date = $resultdate_set->[0]->{datecreate} ;	
		#on veut la liste des années fiscales depuis la date de création jusqu'à l'année en cours
		$sql = 'SELECT s.a FROM generate_series('. $create_date.', (SELECT EXTRACT(YEAR FROM CURRENT_DATE))::integer) AS s(a) ORDER BY 1 DESC';
	}
    

    my $result_set = $dbh->selectall_arrayref( $sql ) ;
    my $list_of_fiscal_years = '<ul style="list-style: none; text-align: center;">' ;
    
    for ( @$result_set ) {

		my $new_fiscal_year_href = '/'.$r->pnotes('session')->{racine}.'/fiscal_year?new_fiscal_year=' . $_->[0] ; 
		#si l'exercice ne commence pas en Janvier, on affiche "année N - année N+1"
		my $new_exercice ;

		if  ( $r->pnotes('session')->{fiscal_year_offset} ) {
			$new_exercice = $_->[0] . '-' . ( $_->[0] + 1 ) ;
		} else {
			$new_exercice = $_->[0] ;
		}
		
		$list_of_fiscal_years .= '<li class="centrer listitem3"><a class=nav href="' . $new_fiscal_year_href . '"><h2>' . $new_exercice . '</h2></a></li>' ;
    }

    $list_of_fiscal_years .= '</ul>' ;
    return $list_of_fiscal_years

} #sub select_fiscal_year 

1;
