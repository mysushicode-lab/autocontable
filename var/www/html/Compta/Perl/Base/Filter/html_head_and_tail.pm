package Base::Filter::html_head_and_tail ;
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
use Apache2::Const -compile => qw( OK DECLINED REDIRECT);

sub handler {

    my $f = shift ;
    my $r = $f->r ;
    my $racine = $r->dir_config('racine') ;
    
    #traiter toutes les URL contenant /$racine; 
    #rejeter le login puisqu'on a pas encore de session, et le logout puisqu'on a plus de session; on laisse aussi passer les xmlhttprequests
    if ( ( $r->uri !~ /$racine/ ) or ( $r->uri =~ /login|logout|xmlhttprequest/ ) ) {

	return Apache2::Const::DECLINED ;

    } elsif ( $r->uri =~ /downloads/ ) {

	#force le navigateur a télécharger le dossier plutôt que l'ouvrir directement
	$r->headers_out->set('Content-Disposition' => 'attachment' ) ;

	return Apache2::Const::DECLINED ;
		
    } else {
		
	#accumulation du contenu des invocations précédentes du filtre
	my $content = $f->ctx ;

	while ($f->read(my $buffer)) {

	    #pour la 1ère invocation, on veut positionner le menu
	    unless ( defined $content ) { 
		
		my $dbh = $r->pnotes('dbh') ;
		my ( $sql, $option_set, @bind_array ) ;	
		my $sql = 'SELECT * FROM compta_client WHERE id_client = ?' ;
		my $societe_get = $dbh->selectall_arrayref( $sql, { Slice => { } }, $r->pnotes('session')->{id_client} ) ;	
		
		my ($exercice, $display_parameters, $display_modify, $display_tva, $display_immobilier) ;

		#en-tête de page : lien vers le choix de fiscal_year
		my $fiscal_year_href = '/'.$racine.'/fiscal_year?fiscal_year' ;
		
		# afficher l'onglet paramétres pour l'utilisateur superadmin
		if ( $r->pnotes('session')->{username} eq 'superadmin') {
		$display_parameters = '<li><a class=' . ( ($r->uri =~ /parametres/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/parametres">' . Encode::encode_utf8('Paramètres') . '</a></li>';
		$display_modify	= '/'.$racine.'/parametres?utilisateurs=0&amp;modification_utilisateur=1&amp;selection_utilisateur=' . Encode::decode_utf8($r->user()) . '';
		}
		
		# afficher l'onglet tva si id_tva_regime != franchise
		if (not( $societe_get->[0]->{id_tva_regime} eq 'franchise')) {
		$display_tva = '<li><a class=' . ( ($r->uri =~ /tva/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/tva">TVA</a></li>';
		}
		
		# afficher l'onglet grestion immobilier si immobilier = 1
		if (not( $societe_get->[0]->{immobilier} eq 'f')) {
		$display_immobilier = '<li><a class=' . ( ($r->uri =~ /gestionimmobiliere/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/gestionimmobiliere">' .Encode::encode_utf8('Gestion immobilière').'</a></li>';
		}
		
		if ( $r->pnotes('session')->{fiscal_year_offset} ) {

		    $exercice = ($r->pnotes('session')->{fiscal_year} -1 ). '-' . ( $r->pnotes('session')->{fiscal_year}  ) ;
		    
		} else {

		    $exercice = $r->pnotes('session')->{fiscal_year}
		    
		}
		
		# Première version avec le nom de l'établissement
		my $header_normal = '<h2 style="margin: 4px 0px 4px 0px;"><a class="title11" title="Cliquer ici pour changer d\'exercice" class="newtitle" href="' . $fiscal_year_href . '">' . $societe_get->[0]->{etablissement} . ' : ' . Encode::encode_utf8('Exercice ') . $exercice . '</a></h3>';
		# Seconde version sans le nom de l'établissement
		my $header_small = '<h2 style="margin: 4px 0px 4px 0px;"><a class="title11" title="Cliquer ici pour changer d\'exercice" class="newtitle" href="' . $fiscal_year_href . '">' . Encode::encode_utf8('Exercice ') . $exercice . '</a></h3>';
		
		my $list_normal = '
		<ul class="main-nav">
		<li><a class=' . ( (($r->uri =~ /journal|entry/ ) && not($r->uri =~ /docsentry/)) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/journal">Journaux</a></li>
		<li><a class=' . ( ($r->uri =~ /compte/ && $r->args !~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte">Comptes</a></li>
		<li><a class=' . ( ($r->uri =~ /docs/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/docs">Documents</a></li>
		<li><a class=' . ( ($r->args =~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte?balance=0">Balance</a></li>
		<li><a class=' . ( ($r->uri =~ /notesdefrais/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/notesdefrais">Notes frais</a></li>
		'.$display_parameters.'
		'.$display_tva.'
		<li><a class=' . ( ($r->uri =~ /export/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/export">Export</a></li>
		<li><a class=' . ( ($r->uri =~ /bilan/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/bilan">Bilan</a></li>
		'.$display_immobilier.'
		</ul>
		';
		
		my $selectmenu = '<li><a class=' . ( (($r->uri =~ /journal|entry/ ) && not($r->uri =~ /docsentry/)) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/journal">Journaux</a></li>
		<li><a class=' . ( ($r->uri =~ /compte/ && $r->args !~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte">Comptes</a></li>
		<li><a class=' . ( ($r->uri =~ /docs/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/docs">Documents</a></li>';
		
		if ($r->args =~ /balance/ ){
		$selectmenu .= '<li><a class=' . ( ($r->args =~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte?balance=0">Balance</a></li>';
		} elsif ($r->uri =~ /gestionimmobiliere/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /gestionimmobiliere/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/gestionimmobiliere">' .Encode::encode_utf8('Gestion immobilière').'</a></li>';
		} elsif ($r->uri =~ /notesdefrais/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /notesdefrais/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/notesdefrais">Notes frais</a></li>';
		} elsif ($r->uri =~ /export/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /export/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/export">Export</a></li>';
		} elsif ($r->uri =~ /bilan/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /bilan/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/bilan">Bilan</a></li>';
		} elsif ($r->uri =~ /tva/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /tva/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/tva">TVA</a></li>';
		} elsif ($r->uri =~ /parametres/ ) {
		$selectmenu .= '<li><a class=' . ( ($r->uri =~ /parametres/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/parametres">' . Encode::encode_utf8('Paramètres') . '</a></li>';		
		} else {
		$selectmenu .= '<li><a class=' . ( ($r->args =~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte?balance=0">Balance</a></li>';
		}
		
		my $list_small = '
		<div class="praimary-menu">
        <ul class="main-nav">
        '.$selectmenu.'
        <li><a class=newnav href="#">...</a>
		<ul class=ulmenu>
		<li><a class=' . ( ($r->args =~ /balance/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/compte?balance=0">Balance</a></li>
		<li><a class=' . ( ($r->uri =~ /notesdefrais/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/notesdefrais">Notes frais</a></li>
		'.$display_parameters.'
		'.$display_tva.'
		<li><a class=' . ( ($r->uri =~ /export/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/export">Export</a></li>
		<li><a class=' . ( ($r->uri =~ /bilan/ ) ? 'newselecteditem' : 'newnav' ) . ' href="/'.$racine.'/bilan">Bilan</a></li>
		'.$display_immobilier.'
          </ul>
          </li>
          </ul>
        </div>
        ';
        
		$content = '
		
	<link rel="stylesheet" href="/Compta/style/fontello/css/fontello.css">
	<div class="topbox">

	<div style="position: absolute; right: auto; left: 5px;">
		<a href="/'.$racine.'/" title="Cliquer ici pour retourner vers le menu principal"><img width="65" class="logo" src="/Compta/style/icons/logo.png" alt="Logo"></a>
	</div>
	
	<div style="position: absolute; left: auto; right: 5px;">
		<ul style="margin-top: 9px; list-style-type: none; ">
		<li class="style1"><a class=linavsolo title="' . Encode::encode_utf8('Cliquer ici pour modifier le compte de l\'utilisateur').'" style="font-size: 1.1em; font-weight: 700; text-decoration: none; padding: 0rem 0.2rem 0rem 1rem;" href="'.$display_modify.'"><i class="icon-user"></i></a><a class=linavsolo title="' . Encode::encode_utf8('Cliquer ici pour modifier le compte de l\'utilisateur').'" style="font-size: 1.1em; font-weight: 700; text-decoration: none; " href="'.$display_modify.'">' . Encode::decode_utf8($r->user()) . '</a> </li>
		<li class="style1"><a class=linavsolo title="' . Encode::encode_utf8('Cliquer ici pour se déconnecter').'" style="font-size: 1.1em; color: red; text-decoration: none;padding: 0rem 0.2rem 0rem 1rem;" href="/'.$racine.'/parametres?logout"><i class="icon-logout" ></i></a><a class=linavsolo style="font-size: 1.1em; font-weight: 700; text-decoration: none;" href="/'.$racine.'/#version">v'.$r->pnotes('session')->{version}.'</a></li>
		</ul>
	</div>

	<div class=centrer>
		<div class="display-on-large">'.$header_normal. $list_normal.' </div>
		<div class="display-on-small">'.$header_small. $list_small.' </div>
	</div>
</div>

    ' ;

	    } #	    unless ( defined $content ) {
	    
	    #ajouter le contenu des buckets brigades de cette invocation
	    $content .= $buffer  ;

	} #	while ($f->read(my $buffer)) 

	#on arrive à la fin du contenu
	if ($f->seen_eos) {
	    
	    $content = Encode::decode_utf8( $content ) . '</div>' ;
	    
	    #<head> section de la page html
	    my $html_head = html_head( $r ) ;

	    #</body> tag
	    my $html_tail = html_tail( $r ) ;

	    $content = $html_head . $content . $html_tail ;

	    #reset du header 'Content-Length'
	    my $len = length $content ;

	    $f->r->headers_out->set('Content-Length', $len) ;

	    $f->print($content) if defined $content ;

	} else {

	    #ce n'est pas fini, on stocke dans l'accumulateur
	    $f->ctx($content) if defined $content ;

	} #	if ($f->seen_eos) 
	
	return Apache2::Const::OK ;

    } #     if ( ( $r->uri !~ /'.$racine.'/ ) or ( $r->uri =~ /login|logout/ ) ) {
    
}


1 ;


sub html_head {

    my $r = shift;
	my $version = $r->pnotes('session')->{version}; # Récupérer la version à partir des notes de la requête

    #on utilise html 5
    my $content = qq | <!DOCTYPE html> 
<html lang=fr>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <link href="/Compta/style/style.css?v=$version" rel="stylesheet" type="text/css">
  <link rel="icon" href="/Compta/style/icons/logo.ico" type="image/x-icon">
  <link href="/Compta/style/print.css" rel="stylesheet" type="text/css" media="print">
  <script src="/Compta/javascript/entry.js"></script>
  <title>Wiki</title>
</head>

<body> | ;
    
    return $content ;

}


sub html_tail {

    my $r = shift; 

    my $content ;
    
    #inclure le dump de la session dans la page? le paramètre session->{dump} est réglé dans le headerparser get_session_id.pm
if ($r->pnotes('session')->{dump} == 1) {
    my $session_data = $r->pnotes('session');
    my @sorted_keys = sort keys %$session_data;
    # Titre du mode dump activé
    $content .= '<div style="border: 1px solid #ccc; padding: 10px; background-color: #f9f9f9;"><h2 style="color: #ff0000;">Mode dump activé <a class="aperso" title="Cliquer ici pour désactiver le mode dump" href="parametres?utilisateurs=0&modification_utilisateur=1&dump=2&focus=1" id="dumpLink">#Désactiver</a></h2><hr>';
    my $formatted_output .= '<h2>Paramètre session->{dump}</h2>';
    $formatted_output .= '<pre>';
    foreach my $key (@sorted_keys) {
        $formatted_output .= "<strong>$key:</strong> $session_data->{$key}\n";
    }
    $formatted_output .= '</pre>';
    $formatted_output .= '</div>';
    # Ajoutez $formatted_output à $content à l'endroit souhaité
    $content .= $formatted_output;
}



    $content .= '</body></html>' ;

    return $content ;

}
