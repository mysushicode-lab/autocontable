package Compta::db_handle ;
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

sub get_dbh {
    
    my ($db_name) = shift ;
    my ($db_host) = shift ;
    my ($db_user) = shift ;
    my ($db_mdp) = shift ;

    #paramètre d'affichage des dates; les caches de connection en tiennent compte
    my $preferred_datestyle = shift || 'iso' ;
    my $dbh = DBI->connect_cached( "DBI:Pg:dbname=$db_name;host=$db_host", $db_user, $db_mdp, {
	PrintError => 1,
    	RaiseError => 1,
    	AutoCommit => 1,
    	pg_bool_tf => 1,
	private_preferred_datestyle => $preferred_datestyle } )
    
    	or die "Cannot connect to db: $DBI::errstr" ;

    return $dbh ;

 }
 
 sub get_dbh_new {
    
    my ($db_name) = shift ;
    my ($db_host) = shift ;
    my ($db_user) = shift ;
    my ($db_mdp) = shift ;

    #paramètre d'affichage des dates; les caches de connection en tiennent compte
    my $preferred_datestyle = shift || 'iso' ;
    my $dbh = DBI->connect( "DBI:Pg:dbname=$db_name;host=$db_host", $db_user, $db_mdp, {
	PrintError => 1,
    	RaiseError => 1,
    	AutoCommit => 1,
    	pg_bool_tf => 1,
	private_preferred_datestyle => $preferred_datestyle } )
    
    	or die "Cannot connect to db: $DBI::errstr" ;

    return $dbh ;

 }

1 ;
