package Base::Handler::liasse_fiscale;
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
use warnings ;
use utf8 ;
use Apache2::Const -compile => qw( OK REDIRECT ) ;
use Base::Function::cerfa_2 ;

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
	#utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content = '<h2>Liasse Fiscale</h2>' ;

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

    #servir par défaut le cerfa n° 2
    $args{form_id} ||= 'cerfa_2' ;

    if ( $args{form_id} eq 'cerfa_2' ) {
	
	if ( defined $args{visualize} ) {

	    $content .= Base::Function::cerfa_2::visualize( $r, \%args ) ;

	} elsif ( defined $args{gestion} ) {

	    $content .= Base::Function::cerfa_2::gestion( $r, \%args ) ;

	} else {
	    
	    $content .= Base::Function::cerfa_2::liste( $r, \%args ) ;

	}

    } else {


	$content .= '<h3>Menu</h3>' ;

	$content .= '<p><a href=/'.$r->pnotes('session')->{racine}.'/liasse_fiscale?form_id=cerfa_2>Cerfa n° 2</a></p>' ;
	
    }#    if ( $args{form_number} eq '2' )

    
    $r->no_cache(1) ;
    
    $r->content_type('text/html; charset=utf-8') ;

    print $content ;

    return Apache2::Const::OK ;

}


1 ;

