package Base::Xmlhttprequest::lettrage ;
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

	#remplacer les charactères nuisibles au code html
	$args{$_} =~ tr/<>"/'/ ;

    }

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;
    

	


    
    if ( defined $args{pointage} || defined $args{pointagerecurrent}) {
	
	if ( defined $args{pointage}) {	
	$sql = 'UPDATE tbljournal SET pointage = ? WHERE id_line = ? AND id_client = ? AND fiscal_year = ?' ;

	#l'id_line de la checkox de pointage commence par pointage_ pour être différente de id_line sur l'input de lettrage
	$args{id_line} =~ s/pointage_// ;
	
	@bind_array =  ( $args{pointage} , $args{id_line}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	
	}
	if ( defined $args{pointagerecurrent}) {
	
	$sql = 'UPDATE tbljournal_staging SET recurrent	= ? WHERE id_entry = ? AND id_client = ? AND _token_id = ? AND fiscal_year = ?' ;

	#l'id_line de la checkox de recurrent commence par recurrent_ pour être différent de id_line sur l'input de lettrage et pointage
	$args{id_line} =~ s/recurrent_// ;
	
	@bind_array =  ( $args{pointagerecurrent} , $args{id_entry}, $r->pnotes('session')->{id_client}, $args{id_token}, $r->pnotes('session')->{fiscal_year} ) ;

	

	}




    } else {

	#$sql = 'UPDATE tbljournal SET lettrage = ? WHERE id_entry = (select id_entry from tbljournal where id_line = ?) AND id_client = ? AND fiscal_year = ?' ;
	$sql = 'UPDATE tbljournal SET lettrage = ? WHERE id_line = ? AND id_client = ? AND fiscal_year = ?' ;

	#si l'utilisateur envoie \s, faire un lettrage automatique
	if ( $args{lettrage} =~/^\s/ ) {

	    $args{lettrage} = lettrage_automatique( $r, \%args ) ;

	    $content = 'document.getElementById("' . $args{id_line} . '").value="' . $args{lettrage} . '";' ;
		
	}
	

	#@bind_array = ( $args{lettrage} || undef , $args{id_line}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;
	@bind_array = ( $args{lettrage} || undef , $args{id_line}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} ) ;


    } #    if ( defined $args{pointage} ) 
    
   
	my $recordset = $dbh->do( $sql, { }, @bind_array ) ;
    

    $r->content_type('text/plain; charset=utf-8') ;

    $r->no_cache(1) ;

    $r->print($content) ;
    
    return Apache2::Const::OK ;

}


1 ;


sub lettrage_automatique {

    my ( $r, $args ) = @_ ;

    my $dbh = $r->pnotes('dbh') ;

    my ( $sql, @bind_array ) ;

    #informations de la ligne
    $sql = 'SELECT id_facture, libelle, debit, credit, coalesce(lettrage, \'\') as lettrage, id_line, id_entry, id_paiement, numero_compte, libelle_journal FROM tbljournal t1 WHERE id_line = ?' ;

    my $pointed_line = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $args->{id_line} ) ) ;

    #recherche du lettrage existant pour ce compte
    $sql = 'SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND lettrage IS NOT NULL ORDER BY length(lettrage) DESC, lettrage DESC LIMIT 1' ;
    @bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ;
    
    my $lettrage_total = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;
    
    $sql = 'SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND numero_compte = ? AND lettrage IS NOT NULL ORDER BY length(lettrage) DESC, lettrage DESC LIMIT 1' ;
	@bind_array = ( $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $pointed_line->[0]->{numero_compte} ) ;
	
	my $lettrage = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] ;

    if ( $lettrage ) {

	$lettrage++ ;

    } else {
	
	if ($lettrage_total) {
	
	my $lettrage_sub = substr( $lettrage_total, 0, 2 );
	$lettrage = ++$lettrage_sub.'01';

    } else {
	
	$lettrage = 'AA02' ;
    }	
	

    }

    return $lettrage ;
    
} #sub lettrage_automatique 
