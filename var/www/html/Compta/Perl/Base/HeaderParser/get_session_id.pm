package Base::HeaderParser::get_session_id ;
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
use strict;
use warnings;
use Apache2::Const -compile => qw( OK DECLINED REDIRECT);

sub handler  {

    my $r = shift ;
    
    my $racine = $r->dir_config('racine') ;

    #on suppose que la session n'est pas valide, jusqu'à preuve du contraire
    my $redirect_to_login = 1 ;

    #ne pas traiter les URL non concernées
    return Apache2::Const::DECLINED if  ( ( $r->uri !~ /$racine/ ) or ( $r->uri =~ /login|data/ ) ) ;

    my $j = Apache2::Cookie::Jar->new($r) ;

    #get cookie from request headers
    my $cookie = $j->cookies('session') ;         

    #c'est le cookie qui permet d'identifier la session
    if (defined $cookie) {

	#cookie string : session=123456
	my ($key,$session_id) = split (/=/,$cookie) ;

	my %session = ( ) ;

	#ne continuer que si on a une clé de session
	if ( $session_id ) {

	my ($db_name) = $r->dir_config('db_name') ;
    my ($db_host) = $r->dir_config('db_host') ;
    my ($db_user) = $r->dir_config('db_user') ;;
    my ($db_mdp) = $r->dir_config('db_mdp') ;

	my $dbh = Compta::db_handle::get_dbh($db_name, $db_host, $db_user, $db_mdp, 'iso') ;
		
    my $sql = 'select serialized_session, session_id from sessions where session_id = ?' ;

	    my $serialized = ${ $dbh->selectall_arrayref( $sql, { }, ( $session_id ) ) }[0][0] ;

	    #si on a bien une session
	    if ( defined $serialized ) {

		#enregistrer la session dans pnotes
		$r->pnotes('session' => Storable::thaw( $serialized ) ) ;

		#set user pour la traçabilité ( %u dans les logs )
		$r->user( $r->pnotes('session')->{username} ) ;

		#si l'utilisateur a un datestyle différend de iso, reset du db_handle
		unless ( $r->pnotes('session')->{preferred_datestyle} eq 'iso' ) {

			$dbh = Compta::db_handle::get_dbh($db_name, $db_host, $db_user, $db_mdp, $r->pnotes('session')->{preferred_datestyle}) ;
		}

		#puisqu'on utilise connect_cached dans db_handle.pm, la session utilisée peut ne pas être au bon datestyle
		#si elle est neuve; lui passer le paramètre de datestyle;
		$dbh->do( 'SET datestyle TO ?', undef, ( $r->pnotes('session')->{preferred_datestyle} ) ) ;

		#passer la db_handle dans pnotes
		$r->pnotes('dbh' => $dbh) ;
		
		#autoriser l'entrée
		$redirect_to_login = 0 ;
		
		#si vrai dump = 1, affiche le contenu de la session en bas de page dans le filtre html_head_and_tail.pm
		#$r->pnotes('session')->{dump} = 1 ;

	    } #  if ( defined $serialized ) 

	} # if ($session_id)

    }  # if (defined $cookie) 

    #si la session n'a pas été validée, rediriger vers login
    if ($redirect_to_login) {

	my $location = '/'.$racine.'/login' ;

	$r->headers_out->set(Location => $location) ;

	return Apache2::Const::REDIRECT ;

    } else {
		
	return Apache2::Const::OK ;

    }

}

1;
