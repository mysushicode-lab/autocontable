package Base::logout ;
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
use Apache2::Const -compile => qw( OK ) ;

sub handler {

    binmode(STDOUT, ":utf8") ;

    my $r = shift ;
	#utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $j = Apache2::Cookie::Jar->new($r) ;
    my $racine = $r->dir_config('racine') ;
    

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

	my $dbh = Compta::db_handle::get_dbh($db_name, $db_host, $db_user, $db_mdp) ;


	    my $sql = 'DELETE FROM sessions WHERE session_id = ?' ;

	    $dbh->do( $sql, { }, ( $r->pnotes('session')->{'_session_id'} ) ) ;

	}

    }
    
    my $version = $r->pnotes('session')->{version}; # Récupérer la version à partir des notes de la requête

    #signaler la sortie
    my $content .= '
<!DOCTYPE HTML>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link href="/Compta/style/style.css?v='.$version.'" rel="stylesheet" type="text/css">
</head>

<body class="login-body">


	<div class="login-container2">
    <img class="login-img" src="/Compta/style/icons/logo.png" alt="image" />
    <div class="login-form-input">
    <h1>Connexion</h1>
	<br><br><br><br>
	<h1 style="text-align: center;"><a href="/'.$racine.'/login">Reconnexion</a></h1>
	</div>
	
	<br><br><br><br>
	</div>
</body>

<div class=warning-rouge><h3>Votre session est close</h3></div>
</html> 
';

    
    $r->content_type('text/html; charset=utf-8') ;

    print $content ;

    return Apache2::Const::OK ;

}

1 ;
