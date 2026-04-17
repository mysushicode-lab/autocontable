package Base::Site::bilan;
#-----------------------------------------------------------------------------------------
#Version 1.10 - Juillet 1th, 2022
#-----------------------------------------------------------------------------------------
#	
#	Créé par picsou83 (https://github.com/picsou83)
#	
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
#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => datadumper : ' . Data::Dumper::Dumper($data_ref_n1) . ' ');

use strict;  		   # Utilisation stricte des variables
use warnings;  		   # Activation des avertissements
use Time::Piece;       # Manipulation de dates et heures
use utf8;              # Encodage UTF-8 pour le script
use Base::Site::util;  # Utilitaires généraux et Génération d'éléments HTML de formulaire
use Base::Site::bdd;   # Interaction avec la base de données (SQL)
use Apache2::Const -compile => qw( OK REDIRECT );  # Importation de constantes Apache
use Encode;            # Encodage de caractères

sub handler {

    binmode(STDOUT, ":utf8") ;

    my $r = shift ;
	#utilisation des logs
    Base::Site::logs::redirect_sig($r->pnotes('session')->{debug});
    my $content ;

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
   
	if ( defined $args{analyses}) {

	    $content = form_analyses( $r, \%args ) ;

	} elsif ( defined $args{options}) {

	    $content = list_options( $r, \%args ) ;

	} else {
		
		$content = principal( $r, \%args ) ;
	
	}

    $r->no_cache(1) ;
    
    $r->content_type('text/html; charset=utf-8') ;

    print $content ;

    return Apache2::Const::OK ;

}

sub principal {
	
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content) ;
    
    ######## Affichage MENU display_compte_set ######
    $content .= display_menu_formulaire( $r, $args ) ;

	#Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}

    # Récupère tous les arguments et les transforme en champs cachés HTML pour un formulaire. A utiliser avec : ' . $hidden_fields_form1 . '
	my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, [], [], []);
	
	unless ( defined $args->{nom} && $args->{nom} ne '') {
	    $args->{nom} = 'Bilan' ;
    }
    
    my $nom;
	
	if (defined $args->{nom} && lc($args->{nom}) eq lc('bilan')){
		
		$content .= bilan( $r, $args) ;
		
	} elsif (defined $args->{nom} && ($nom = lc($args->{nom})) && ($nom eq 'compte de résultat' || $nom eq 'résultat' || $nom eq 'resultat')) {
		
		$content .= resultat( $r, $args) ;
		
	} else {
		
		$content .= formulaire( $r, $args) ;
	
	}
	
	return $content ;
}

sub formulaire {
	
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my %data;
    my $time_diff_month_N1;

	my ($data_ref, $data_ref_n1) = calculer_formulaire($r, $args, $dbh, $args->{nom});

    #Récupérations des informations
    my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);
	my $tblbilan = Base::Site::bdd::get_tblbilan($dbh, $r, $args->{nom});
	
	#calcul nb mois exercice
	my $date_month_start = Time::Piece->strptime( $r->pnotes('session')->{Exercice_debut_YMD}, "%Y-%m-%d" );
	my $date_month_end = Time::Piece->strptime( $r->pnotes('session')->{Exercice_fin_YMD}, "%Y-%m-%d" );
	my $dateN1_month_end = Time::Piece->strptime( $r->pnotes('session')->{Exercice_fin_DMY_N1}, "%d/%m/%Y" );
	my $time_diff_month = int((($date_month_end - $date_month_start)->months)+ 0.5);

	if ($info_societe->[0]->{date_fin} eq $r->pnotes('session')->{Exercice_fin_DMY_N1}) {
	my $date_month_startN1 = Time::Piece->strptime( $info_societe->[0]->{date_debut}, "%d/%m/%Y" );
	$time_diff_month_N1 = int((($dateN1_month_end - $date_month_startN1)->months)+ 0.5);	
	} else {
	my $time_diff_month_N1 = $time_diff_month;
	}

	$content .= '
	<div class="non-printable">
	<h3 class="page-subtitle">'.($tblbilan->[0]->{bilan_desc} ||'').'</h3></div>
	<div class="wrapper-forms" style="background-image: url('.($tblbilan->[0]->{bilan_doc} ||'').');width:'.($tblbilan->[0]->{bilan_width} ||'960').'px; height:'.($tblbilan->[0]->{bilan_height} ||'1500').'px;position:relative">
	';
		
	# Boucle pour générer les balises HTML à partir des clés de $data_ref correspondant à l'année en cours
	foreach my $id (keys %$data_ref) {
		my $exercice = $data_ref->{$id}{exercice} || '';
		next unless $exercice eq 'compteN' || $exercice eq 'formuleN' || $exercice eq 'divers';
		
		if ($exercice eq 'divers') {
			if ($data_ref->{$id}{title} =~ /#info_societe/) {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$info_societe->[0]->{etablissement} . ' - SIRET : ' . $info_societe->[0]->{siret} . '</div>';
			} elsif ($data_ref->{$id}{title} =~ /#exercice/) {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$r->pnotes('session')->{Exercice_fin_DMY}.'</div>';
			} elsif ($data_ref->{$id}{title} =~ /#exercice_N1/) {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$r->pnotes('session')->{Exercice_fin_DMY_N1}.'</div>';
			} elsif ($data_ref->{$id}{title} =~ /#nbmois/) {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$time_diff_month.'</div>';
			} elsif ($data_ref->{$id}{title} =~ /#nbmois_N1/) {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$time_diff_month_N1.'</div>';
			} else {
				$content .= '<div id='.$id.' class="general-value" '. ($data_ref->{$id}{style}||'') .'>'.$data_ref->{$id}{titleb} . '</div>';
			} 
		} else {
			my $style = $data_ref->{$id}{style} || '';
			my $title = $data_ref->{$id}{title} || '';
			my $value = format_value($data_ref->{$id}{var});
			$content .= "<div id=$id class='general-value' $style $title>$value</div>";
		}
	}

	# Boucle pour générer les balises HTML à partir des clés de $data_ref_n1 correspondant à l'année précédente
	foreach my $id (keys %$data_ref_n1) {
		my $exercice = $data_ref_n1->{$id}{exercice} || '';
		next unless $exercice eq 'compteN1' || $exercice eq 'formuleN1';
		my $style = $data_ref_n1->{$id}{style} || '';
		my $title = $data_ref_n1->{$id}{title} || '';
		my $value = format_value($data_ref_n1->{$id}{var});
		$content .= "<div id=$id class='general-value' $style $title>$value</div>";
	}

	$content .= '</div>';
    return $content ;
    
} #sub formulaire

sub bilan {
	
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $numero_compte = '0';
    my $date = localtime->strftime('%d/%m/%Y');

	my ($data_ref, $data_ref_n1) = calculer_formulaire($r, $args, $dbh, $args->{nom}); #$data_ref->{AA}{title}
	
	#Récupérations des informations bdd
    my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);

	$content .= '
		<div class="printable">
		<div style="float: left ">
		<address><strong>'.$info_societe->[0]->{etablissement} . '</strong><br>
		' . ($info_societe->[0]->{adresse_1} || '') . ' <br> ' . ($info_societe->[0]->{code_postal} || ''). ' ' . ($info_societe->[0]->{ville} || '').'<br>
		SIRET : ' . $info_societe->[0]->{siret} . '<br>
		</address></div>
		<div style="float: right; text-align: right;">
		Imprimé le ' . $date . '<br>
		<div>
		Exercice du '.$r->pnotes('session')->{Exercice_debut_DMY}.' 
		</div>
		au '.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>
		</div>
		<div style="width: 100%; text-align: center;"><h1>Bilan au '.$r->pnotes('session')->{Exercice_fin_DMY}.'</h1>
		<div >
		Etat exprimé en Euros</div>
		</div><br></div>' ;

		my $compte_list .= '
		<fieldset class="pretty-box"><legend><h3>BILAN</h3></legend>
		<div class=flex-table><div class=spacer></div>
		<div class="bilan bilan_niveau0_actif"><div class=bilan_rubriques_actif><h2>ACTIF</h2></div><div class=data_titre_actif_bilan ><h4>Brut</h4></div><div class=data_titre_actif_bilan><h4>Amort.<br>prov.</h4></div><div class=data_titre_actif_bilan ><h4>'.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>Net</h4></div><div class=data_titre_actif_bilan ><h4>'.$r->pnotes('session')->{Exercice_fin_DMY_N1}.'<br>Net</h4></div></div>
		<div class="bilan bilan_niveau0_passif"><div class=bilan_rubriques_passif><h2>PASSIF</h2></div><div class=data_titre_passif_bilan  ><h4>'.$r->pnotes('session')->{Exercice_fin_DMY}.'</h4></div><div class=data_titre_passif_bilan ><h4>'.$r->pnotes('session')->{Exercice_fin_DMY_N1}.'</h4></div></div></div>
		';
		
		my @sections = (
			{ niveau=>  '3', title_actif => '<h4>ACTIF IMMOBILISÉ</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>CAPITAUX PROPRES</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Immobilisations incorporelles :', style_actif => 'style="font-weight: bold;"', rubriques_actif => [], title_passif => 'Capital social', style_passif => 'style="font-weight: bold;"', rubriques_passif => ['FA', 'GA'] },
			{ niveau=>  '1', title_actif => '- Fonds commercial', style_actif => 'style="padding-left: 5px;"', rubriques_actif => ['AA', 'BA', 'CA', 'DA'], title_passif => 'Ecart de réévaluation', style_passif => '', rubriques_passif => ['FB', 'GB'] },
			{ niveau=>  '1', title_actif => '- Autres immobilisations incorporelles', style_actif => 'style="padding-left: 5px;"', rubriques_actif => ['AB', 'BB', 'CB', 'DB'], title_passif => 'Réserves :', style_passif => 'style="font-weight: bold;"', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Immobilisations corporelles', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AC', 'BC', 'CC', 'DC'], title_passif => '- Réserve légale', style_passif => 'style="padding-left: 5px;"', rubriques_passif => ['FC', 'GC'] },
			{ niveau=>  '1', title_actif => 'Immobilisations financières', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AD', 'BD', 'CD', 'DD'], title_passif => '- Réserves réglementées', style_passif => 'style="padding-left: 5px;"', rubriques_passif => ['FD', 'GD'] },
			{ niveau=>  '1', title_actif => '&nbsp;', style_actif => '', rubriques_actif => [], title_passif => '- Autres réserves', style_passif => 'style="padding-left: 5px;"', rubriques_passif => ['FE', 'GE'] },
			{ niveau=>  '1', title_actif => '&nbsp;', style_actif => '', rubriques_actif => [], title_passif => 'Report à nouveau', style_passif => '', rubriques_passif => ['FF', 'GF'] },
			{ niveau=>  '1', title_actif => '&nbsp;', style_actif => '', rubriques_actif => [], title_passif => 'Résultat de l\'exercice (Bénéfice ou Perte)', style_passif => 'style="font-weight: bold;"', rubriques_passif => ['FG', 'GG'] },
			{ niveau=>  '1', title_actif => '&nbsp;', style_actif => '', rubriques_actif => [], title_passif => 'Provisions réglementées', style_passif => 'style="font-weight: bold;"', rubriques_passif => ['FH', 'GH'] },
			{ niveau=>  '2', title_actif => 'TOTAL I', style_actif => 'style="text-align: right; font-weight: bold;  padding-right: 5px;"', rubriques_actif => ['AE', 'BE', 'CE', 'DE'], title_passif => 'TOTAL I', style_passif => 'style="text-align: right; font-weight: bold;  padding-right: 5px;"', rubriques_passif => ['FJ', 'GJ'] },
			{ niveau=>  '1', title_actif => '&nbsp;', style_actif => '', rubriques_actif => [], title_passif => 'Provisions pour risques et charges (II)', style_passif => 'style="font-weight: bold;"', rubriques_passif => ['FK', 'GK'] },
			{ niveau=>  '3', title_actif => '<h4>ACTIF CIRCULANT</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>DETTES</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Stocks et en cours', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AF', 'BF', 'CF', 'DF'], title_passif => 'Emprunts et dettes assimilées', style_passif => '', rubriques_passif => ['FL', 'GL'] },
			{ niveau=>  '1', title_actif => 'Stocks de marchandises', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AG', 'BG', 'CG', 'DG'], title_passif => 'Avances, acomptes reçus sur commandes en cours', style_passif => '', rubriques_passif => ['FM', 'GM'] },
			{ niveau=>  '1', title_actif => 'Avances et acomptes versés sur commandes', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AH', 'BH', 'CH', 'DH'], title_passif => 'Dettes fournisseurs et comptes rattachés', style_passif => '', rubriques_passif => ['FN', 'GN'] },
			{ niveau=>  '1', title_actif => 'Créances :', style_actif => 'style="font-weight: bold;"', rubriques_actif => [], title_passif => 'Autres dettes', style_passif => '', rubriques_passif => ['FP', 'GP'] },
			{ niveau=>  '1', title_actif => '- Créances clients et comptes rattachés', style_actif => 'style="padding-left: 5px;"', rubriques_actif => ['AJ', 'BJ', 'CJ', 'DJ'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => '- Autres créances', style_actif => 'style="padding-left: 5px;"', rubriques_actif => ['AK', 'BK', 'CK', 'DK'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Valeurs mobilières de placement', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AL', 'BL', 'CL', 'DL'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Disponibilités', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AM', 'BM', 'CM', 'DM'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '2', title_actif => 'TOTAL II', style_actif => 'style="text-align: right; font-weight: bold;  padding-right: 5px;"', rubriques_actif => ['AQ', 'BQ', 'CQ', 'DQ'], title_passif => 'TOTAL III', style_passif => 'style="text-align: right; font-weight: bold;  padding-right: 5px;"', rubriques_passif => ['FR', 'GR'] },
			{ niveau=>  '1', title_actif => 'Charges constatées d\'avance (III)', style_actif => 'style="font-weight: bold;"', rubriques_actif => ['AP', 'BP', 'CP', 'DP'], title_passif => 'Produits constatés d\'avance (IV)', style_passif => 'style="font-weight: bold;"', rubriques_passif => ['FQ', 'GQ'] },
			{ niveau=>  '4', title_actif => 'TOTAL GENERAL (I+II+III)', style_actif => 'style="text-align: right; font-weight: bold; padding-right: 5px;"', rubriques_actif => ['AR', 'BR', 'CR', 'DR'], title_passif => 'TOTAL GENERAL (I+II+III+IV)', style_passif => 'style="text-align: right; font-weight: bold; padding-right: 5px;"', rubriques_passif => ['FS', 'GS'] },
		);
		
		$compte_list .= generate_bilan_list(\@sections, $data_ref, $data_ref_n1);
		$compte_list .= '</fieldset>';
		$content .= '<div class="wrapper">' . $compte_list . '</div>' ;
		
    return $content ;
	
} #sub bilan 

sub generate_bilan_list {
    my ($sections, $data_ref, $data_ref_n1) = @_;

    my $compte_list = '';

    foreach my $section (@$sections) {
        $compte_list .= '<div class="flex-table"><div class="spacer"></div>';
        if ($section->{niveau} eq '1') {$compte_list .= '<div class="bilan fenetre_bilan_data_actif">' }
        elsif ($section->{niveau} eq '2') {$compte_list .= '<div class="bilan bilan_total1_actif">' }
        elsif ($section->{niveau} eq '3') {$compte_list .= '<div class="bilan bilan_niveau1_actif">' }
        elsif ($section->{niveau} eq '4') {$compte_list .= '<div class="bilan bilan_total2_actif">' };
        $compte_list .= '<div class="bilan_rubriques_actif" ' . $section->{style_actif} . '>' . $section->{title_actif} . '</div>';

        foreach my $case (@{ $section->{rubriques_actif} }) {
            my $var_value = $case =~ /^[DG]/ ? ($data_ref_n1->{$case}{var} || 0) : ($data_ref->{$case}{var} || 0);
            $compte_list .= '<div title="Case ' . $case . ' => ' . format_value($var_value) . '" class="data_actif_bilan">' . format_arrondie($var_value) . '</div>';
        }

        $compte_list .= '</div>';
        if ($section->{niveau} eq '1') {$compte_list .= '<div class="bilan fenetre_bilan_data_passif">' }
        elsif ($section->{niveau} eq '2') {$compte_list .= '<div class="bilan bilan_total1_passif">' }
        elsif ($section->{niveau} eq '3') {$compte_list .= '<div class="bilan bilan_niveau1_passif">' }
        elsif ($section->{niveau} eq '4') {$compte_list .= '<div class="bilan bilan_total2_passif">' };
        $compte_list .= '<div class="bilan_rubriques_passif" ' . $section->{style_passif} . ' >' . $section->{title_passif} . '</div>';

        foreach my $case (@{ $section->{rubriques_passif} }) {
            my $var_value = $case =~ /^[DG]/ ? ($data_ref_n1->{$case}{var} || 0) : ($data_ref->{$case}{var} || 0);
            
			my ($colour_resultat_N, $colour_resultat_N1) = ('','');

			if ($case eq 'FG') {$colour_resultat_N = ($data_ref->{$case}{var} || 0) > 0 ? 'style="color: green;"' : (($data_ref->{$case}{var} || 0) < 0 ? 'style="color: red;"' : '');}
			if ($case eq 'GG') {$colour_resultat_N1 = ($data_ref_n1->{$case}{var} || 0) > 0 ? 'style="color: green;"' : (($data_ref_n1->{$case}{var} || 0) < 0 ? 'style="color: red;"' : '');}
			if ($case eq 'FJ') {$colour_resultat_N = ($data_ref->{$case}{var} || 0) > 0 ? 'style="color: green;"' : (($data_ref->{$case}{var} || 0) < 0 ? 'style="color: red;"' : '');}
			if ($case eq 'GJ') {$colour_resultat_N1 = ($data_ref_n1->{$case}{var} || 0) > 0 ? 'style="color: green;"' : (($data_ref_n1->{$case}{var} || 0) < 0 ? 'style="color: red;"' : '');}
			
			$compte_list .= '<div title="Case ' . $case . ' => ' . format_value($var_value) . '" class="data_passif_bilan" '.$colour_resultat_N.' '.$colour_resultat_N1.'>' . format_arrondie($var_value) . '</div>';
		}

        $compte_list .= '</div></div>';
    }

    return $compte_list;
}

sub generate_resultat_list {
    my ($sections, $data_ref, $data_ref_n1) = @_;

    my $compte_list = '';

    foreach my $section (@$sections) {
        $compte_list .= '<div class="flex-table"><div class="spacer"></div>';
        if ($section->{niveau} eq '1') {$compte_list .= '<div class="resultat fenetre_data_resultat" ><div class="rubriques_resultat" >' }
        elsif ($section->{niveau} eq '2') {$compte_list .= '<div class="resultat total_3_resultat"><div class="rubriques_resultat" >' }
        elsif ($section->{niveau} eq '3') {$compte_list .= '<div class="resultat titre_1_resultat"><div class="rubriques_resultat" >' }
        elsif ($section->{niveau} eq '4') {$compte_list .= '<div class="resultat total_4_resultat"><div class="rubriques_resultat" style="text-align: right;">' };
        $compte_list .= '' . $section->{title_actif} . '</div>';

        foreach my $case (@{ $section->{rubriques_actif} }) {
            my $var_value = $case =~ /^[DGE]/ ? ($data_ref_n1->{$case}{var} || 0) : ($data_ref->{$case}{var} || 0);
            $compte_list .= '<div title="Case ' . $case . ' => ' . format_value($var_value) . '" class="data_resultat" ' . ($section->{style_actif} || '') . '>' . format_arrondie($var_value) . '</div>';
        }
        $compte_list .= '</div>';
                
        if ($section->{niveau} eq '1') {$compte_list .= '<div class="resultat fenetre_data_resultat" style="float : right;"><div class="rubriques_resultat" ' . ($section->{style_passif_2} || ''). ' >' }
        elsif ($section->{niveau} eq '2') {$compte_list .= '<div class="resultat total_3_resultat" style="float : right;"><div class="rubriques_resultat" >' }
        elsif ($section->{niveau} eq '3') {$compte_list .= '<div class="resultat titre_1_resultat" style="float : right;"><div class="rubriques_resultat" >' }
        elsif ($section->{niveau} eq '4') {$compte_list .= '<div class="resultat total_4_resultat" style="float : right;"><div class="rubriques_resultat" style="text-align: right;">' };
        $compte_list .= '' . $section->{title_passif} . '</div>';

        foreach my $case (@{ $section->{rubriques_passif} }) {
            my $var_value = $case =~ /^[DGE]/ ? ($data_ref_n1->{$case}{var} || 0) : ($data_ref->{$case}{var} || 0);

			$compte_list .= '<div title="Case ' . $case . ' => ' . format_value($var_value) . '" class="data_resultat" ' . ($section->{style_passif} || '') . ' >' . format_arrondie($var_value) . '</div>';
		}

        $compte_list .= '</div></div>';
    }

    return $compte_list;
}

sub resultat {
	
	my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    my $numero_compte = '0';
    
    my ($data_ref, $data_ref_n1) = calculer_formulaire($r, $args, $dbh, $args->{nom}); #$data_ref->{AA}{title}
  
	# Préparation à l'impression
 	my $date = localtime->strftime('%d/%m/%Y');

	#Récupérations des informations bdd
    my $info_societe = Base::Site::bdd::get_info_societe($dbh, $r);

	$content .= '
		<div class="printable">
		<div style="float: left ">
		<address><strong>'.$info_societe->[0]->{etablissement} . '</strong><br>
		' . ($info_societe->[0]->{adresse_1} || '') . ' <br> ' . ($info_societe->[0]->{code_postal} || ''). ' ' . ($info_societe->[0]->{ville} || '').'<br>
		SIRET : ' . $info_societe->[0]->{siret} . '<br>
		</address></div>
		<div style="float: right; text-align: right;">
		Imprimé le ' . $date . '<br>
		<div>
		Exercice du '.$r->pnotes('session')->{Exercice_debut_DMY}.' 
		</div>
		au '.$r->pnotes('session')->{Exercice_fin_DMY}.'<br>
		</div>
		<div style="width: 100%; text-align: center;"><h1>Compte de Résultat au '.$r->pnotes('session')->{Exercice_fin_DMY}.'</h1>
		<div >
		Etat exprimé en Euros</div>
		</div><br></div>' ;
		
		my $compte_list .= '
		<fieldset class="pretty-box"><legend><h3>COMPTE DE RESULTAT</h3></legend>
		<div class=flex-table><div class=spacer></div>
		<div class="resultat titre_0_resultat"><div class=data_title_resultat><h3>CHARGES</h3></div><div class=data_resultat><h3>'.$r->pnotes('session')->{Exercice_fin_DMY}.'</h3></div><div class=data_resultat><h3>'.$r->pnotes('session')->{Exercice_fin_DMY_N1}.'</h3></div></div>
		<div class="resultat titre_0_resultat" style="float : right;"><div class=data_title_resultat><h3>PRODUITS</h3></div><div class=data_resultat><h3>'.$r->pnotes('session')->{Exercice_fin_DMY}.'</h3></div><div class=data_resultat><h3>'.$r->pnotes('session')->{Exercice_fin_DMY_N1}.'</h3></div></div></div>
		';
		
		my @sections = (
			{ niveau=>  '3', title_actif => '<h4>CHARGES D\'EXPLOITATION</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>PRODUITS D\'EXPLOITATION</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Achats de marchandises', style_actif => '', rubriques_actif => ['BJ', 'DJ'], title_passif => 'Ventes de marchandises', style_passif => '', rubriques_passif => ['BA', 'DA'] },
			{ niveau=>  '1', title_actif => 'Variations de stocks de marchandises', style_actif => '', rubriques_actif => ['BK', 'DK'], title_passif => 'Production Vendue :', style_passif_2 => 'style="font-weight: bold;"', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Achats d\'approvisionnements', style_actif => '', rubriques_actif => ['BL', 'DL'], title_passif => '- biens', style_passif_2 => 'style="padding-left: 5px;"', rubriques_passif => ['BB', 'DB'] },
			{ niveau=>  '1', title_actif => 'Variations de stocks d\'Approvisionnements', style_actif => '', rubriques_actif => ['BM', 'DM'], title_passif => '- services', style_passif_2 => 'style="padding-left: 5px;"', rubriques_passif => ['BC', 'DC'] },
			{ niveau=>  '1', title_actif => 'Autres charges externes', style_actif => '', rubriques_actif => ['BN', 'DN'], title_passif => 'Production Stockée', style_passif => '', rubriques_passif => ['BD', 'DD'] },
			{ niveau=>  '1', title_actif => 'Impôts taxes et versements assimilés', style_actif => '', rubriques_actif => ['BP', 'DP'], title_passif => 'Production Immobilisée', style_passif => '', rubriques_passif => ['BE', 'DE'] },
			{ niveau=>  '1', title_actif => 'Rémunérations du personnel', style_actif => '', rubriques_actif => ['BQ', 'DQ'], title_passif => 'Subventions d\'exploitation', style_passif => '', rubriques_passif => ['BF', 'DF'] },
			{ niveau=>  '1', title_actif => 'Charges sociales', style_actif => '', rubriques_actif => ['BR', 'DR'], title_passif => 'Autres produits d\'exploitation', style_passif => '', rubriques_passif => ['BG', 'DG'] },
			{ niveau=>  '1', title_actif => 'Dotations aux Amortissements et Dépréciations', style_actif => '', rubriques_actif => ['BS', 'DS'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Dotations aux provisions', style_actif => '', rubriques_actif => ['BT', 'DT'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Autres charges d\'exploitation', style_actif => '', rubriques_actif => ['BU', 'DU'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '2', title_actif => 'Total charges d\'exploitation', style_actif => '', rubriques_actif => ['BV', 'DV'], title_passif => 'Total produits d\'exploitation', style_passif => '', rubriques_passif => ['BH', 'DH'] },
			{ niveau=>  '2', title_actif => 'Résultat d\'exploitations (excédent)', style_actif => 'style="color: green;"', rubriques_actif => ['BW1', 'DW1'], title_passif => 'Résultat d\'exploitations (déficit)', style_passif => 'style="color: red;"', rubriques_passif => ['BW2', 'DW2'] },
			{ niveau=>  '3', title_actif => '<h4>CHARGES FINANCIERES</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>PRODUITS FINANCIERS</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Charges financières', style_actif => '', rubriques_actif => ['BZ', 'DZ'], title_passif => 'Produits financiers', style_passif => '', rubriques_passif => ['BX', 'DX'] },
			{ niveau=>  '2', title_actif => 'Résultat financier (excédent)', style_actif => 'style="color: green;"', rubriques_actif => ['CP1', 'EP1'], title_passif => 'Résultat financier (déficit)', style_passif => 'style="color: red;"', rubriques_passif => ['CP2', 'EP2'] },
			{ niveau=>  '2', title_actif => 'Résultat courant avant impôts (excédent)', style_actif => 'style="color: green;"', rubriques_actif => ['CQ1', 'EQ1'], title_passif => 'Résultat courant avant impôts (déficit)', style_passif => 'style="color: red;"', rubriques_passif => ['CQ2', 'EQ2'] },
			{ niveau=>  '3', title_actif => '<h4>CHARGES EXCEPTIONNELLES</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>PRODUITS EXCEPTIONNELS</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '1', title_actif => 'Charges exceptionnelles', style_actif => '', rubriques_actif => ['CA', 'EA'], title_passif => 'Produits exceptionnels', style_passif => '', rubriques_passif => ['BY', 'DY'] },
			{ niveau=>  '2', title_actif => 'Résultat exceptionnel (excédent)', style_actif => 'style="color: green;"', rubriques_actif => ['CR1', 'ER1'], title_passif => 'Résultat exceptionnel (déficit)', style_passif => 'style="color: red;"', rubriques_passif => ['CR2', 'ER2'] },
			{ niveau=>  '1', title_actif => 'Impôts sur les bénéfices', style_actif => '', rubriques_actif => ['CB', 'EB'], title_passif => '&nbsp;', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '3', title_actif => '<h4>&nbsp;</h4>', style_actif => '', rubriques_actif => [], title_passif => '<h4>&nbsp;</h4>', style_passif => '', rubriques_passif => [] },
			{ niveau=>  '2', title_actif => 'Total des charges', style_actif => '', rubriques_actif => ['CT', 'ET'], title_passif => 'Total des produits', style_passif => '', rubriques_passif => ['CS', 'ES'] },
			{ niveau=>  '2', title_actif => 'Résultat général (excédent)', style_actif => 'style="color: green;"', rubriques_actif => ['CC1', 'EC1'], title_passif => 'Résultat général (déficit)', style_passif => 'style="color: red;"', rubriques_passif => ['CC2', 'EC2'] },
			{ niveau=>  '4', title_actif => '<h4>TOTAL GENERAL</h4>', style_actif => 'style="margin: 0.4em 0;"', rubriques_actif => ['CU', 'EU'], title_passif => '<h4>TOTAL GENERAL</h4>', style_passif => 'style="margin: 0.4em 0;"', rubriques_passif => ['CV', 'EV'] },
		);
		
		$compte_list .= generate_resultat_list(\@sections, $data_ref, $data_ref_n1);
		$compte_list .= '</fieldset>';
		$content .= '<div class="wrapper">' . $compte_list . '</div>' ;
		
    return $content ;	

	    
} #sub resultat 

#/*—————————————— Page analyses ——————————————*/
sub form_analyses {

	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
    
	################ Affichage MENU ################
	$content .= display_menu_formulaire( $r, $args ) ;
	################ Affichage MENU ################
	
	#####################################       
	# Menu chekbox
	#####################################   
	#définition des variables
	my @checked = ('0') x 30;
	my @dispcheck = ('0') x 30;
	
	my $forms_check1 = '<div class="card"> '.forms_check1( $r, $args ).'</div>' ; 
	my $forms_check2 = '<div class="card"> '.forms_check2( $r, $args ).'</div>' ; 
	my $forms_check3 = '<div class="card"> '.forms_check3( $r, $args ).'</div>' ; 
	my $forms_check4 = '<div class="card"> '.forms_check4( $r, $args ).'</div>' ; 
	my $forms_check5 = '<div class="card"> '.forms_check5( $r, $args ).'</div>' ; 
	my $forms_check6 = '<div class="card"> '.forms_check6( $r, $args ).'</div>' ; 
	my $forms_check7 = '<div class="card"> '.forms_check7( $r, $args ).'</div>' ; 
	my $forms_check8 = '<div class="card"> '.forms_check8( $r, $args ).'</div>' ; 
	my $forms_check9 = '<div class="card"> '.forms_check9( $r, $args ).'</div>' ; 
	my $forms_check10 = '<div class="card"> '.forms_check10( $r, $args ).'</div>' ; 
	my $forms_check11 = '<div class="card"> '.forms_check11( $r, $args ).'</div>' ;
	my $forms_check12 = '<div class="card"> '.forms_check12( $r, $args ).'</div>' ;
	my $forms_check13 = '<div class="card"> '.forms_check13( $r, $args ).'</div>' ;
	my $forms_check14 = '<div class="card"> '.forms_check14( $r, $args ).'</div>' ;
	my $forms_check15 = '<div class="card"> '.forms_check15( $r, $args ).'</div>' ;
	my $forms_check16 = '<div class="card"> '.forms_check16( $r, $args ).'</div>' ;
	my $forms_check17 = '<div class="card"> '.forms_check17( $r, $args ).'</div>' ;
	my $forms_check18 = '<div class="card"> '.forms_check18( $r, $args ).'</div>' ;
	my $forms_check19 = '<div class="card"> '.forms_check19( $r, $args ).'</div>' ;
	my $forms_check20 = '<div class="card"> '.forms_check20( $r, $args ).'</div>' ;
	
	# Initialisation des cases à cocher et Génération des champs cachés
	my $hiden_menu = '';
	for my $i (1..20) {
		$checked[$i] = (defined $args->{"menu$i"} && $args->{"menu$i"} eq 1) ? 'checked' : '';
		$hiden_menu .= '<input type=hidden name="menu' . $i . '" value="' . ($args->{"menu$i"} || '') . '">';
	}
	
	# Déclaration de $filtre comme une chaîne vide
	my $filtre = '
	<div class=centrer>
	<div class="formflexN4">';

	# Liste des menus et de leurs identifiants
	my @menus = (
		{ id => 1, label => "PieceRef ≠ doc" },
		{ id => 9, label => "PieceRef vide ?" },
		{ id => 15, label => "Rupture numéro" },
		{ id => 16, label => "Rupture Pièce" },
		{ id => 17, label => "Doublon Pièce" },
		{ id => 2, label => "58 soldé ?" },
		{ id => 4, label => "47 soldé ?" },
		{ id => 5, label => "12 soldé ?" },
		{ id => 3, label => "lettrage déséquilibré" },
		{ id => 8, label => "6063 > 500€" },
		{ id => 10, label => "caisse > 1000€" },
		{ id => 11, label => "6* créditeur ?" },
		{ id => 12, label => "7* débiteur ?" },
		{ id => 19, label => "41* créditeur ?" },
		{ id => 20, label => "40* débiteur ?" },
		{ id => 13, label => "455 débiteur ?" },
		{ id => 14, label => "51* créditeur ?" },
		{ id => 18, label => "Sans doc1" },
		{ id => 7, label => "PieceDate ≠ exercice" },
		{ id => 6, label => "PieceDate <= Ecriture" }
	);

	# Génération des formulaires
	foreach my $menu (@menus) {
		my $id = $menu->{id};
		my $label = $menu->{label};
		
		$filtre .= qq(
			<form method="post" action=") . $r->unparsed_uri() . qq(">
				<label for="check$id" class="forms2_label">$label</label>
				<input id="check$id" type="checkbox" class="demo5" ) . ($checked[$id] // '') . qq( onchange="submit()" name="menu$id" value=1>
				<label for="check$id" class="forms2_label"></label>
				<input type="hidden" name="menu$id" value=0>
				$hiden_menu
			</form>
		);
	}

	$filtre .= '</div>';
	
	if (defined $args->{menu1} && $args->{menu1} eq 1) {$dispcheck[1] = $forms_check1;} else {$dispcheck[1] = '';}
	if (defined $args->{menu2} && $args->{menu2} eq 1) {$dispcheck[2] = $forms_check2;} else {$dispcheck[2] = '';}
	if (defined $args->{menu3} && $args->{menu3} eq 1) {$dispcheck[3] = $forms_check3;} else {$dispcheck[3] = '';}
	if (defined $args->{menu4} && $args->{menu4} eq 1) {$dispcheck[4] = $forms_check4;} else {$dispcheck[4] = '';}
	if (defined $args->{menu5} && $args->{menu5} eq 1) {$dispcheck[5] = $forms_check5;} else {$dispcheck[5] = '';}
	if (defined $args->{menu6} && $args->{menu6} eq 1) {$dispcheck[6] = $forms_check6;} else {$dispcheck[6] = '';}
	if (defined $args->{menu7} && $args->{menu7} eq 1) {$dispcheck[7] = $forms_check7;} else {$dispcheck[7] = '';}
	if (defined $args->{menu8} && $args->{menu8} eq 1) {$dispcheck[8] = $forms_check8;} else {$dispcheck[8] = '';}
	if (defined $args->{menu9} && $args->{menu9} eq 1) {$dispcheck[9] = $forms_check9;} else {$dispcheck[9] = '';}
	if (defined $args->{menu10} && $args->{menu10} eq 1) {$dispcheck[10] = $forms_check10;} else {$dispcheck[10] = '';}
	if (defined $args->{menu11} && $args->{menu11} eq 1) {$dispcheck[11] = $forms_check11;} else {$dispcheck[11] = '';}
	if (defined $args->{menu12} && $args->{menu12} eq 1) {$dispcheck[12] = $forms_check12;} else {$dispcheck[12] = '';}
	if (defined $args->{menu13} && $args->{menu13} eq 1) {$dispcheck[13] = $forms_check13;} else {$dispcheck[13] = '';}
	if (defined $args->{menu14} && $args->{menu14} eq 1) {$dispcheck[14] = $forms_check14;} else {$dispcheck[14] = '';}
	if (defined $args->{menu15} && $args->{menu15} eq 1) {$dispcheck[15] = $forms_check15;} else {$dispcheck[15] = '';}
	if (defined $args->{menu16} && $args->{menu16} eq 1) {$dispcheck[16] = $forms_check16;} else {$dispcheck[16] = '';}
	if (defined $args->{menu17} && $args->{menu17} eq 1) {$dispcheck[17] = $forms_check17;} else {$dispcheck[17] = '';}
	if (defined $args->{menu18} && $args->{menu18} eq 1) {$dispcheck[18] = $forms_check18;} else {$dispcheck[18] = '';}
	if (defined $args->{menu19} && $args->{menu19} eq 1) {$dispcheck[19] = $forms_check19;} else {$dispcheck[19] = '';}
	if (defined $args->{menu20} && $args->{menu20} eq 1) {$dispcheck[20] = $forms_check20;} else {$dispcheck[20] = '';}
	
	$content .= '	
		<div class="wrapper-docs-entry">
			<fieldset class="pretty-box"><legend><h3 class="Titre09">Analyses des données comptables</h3></legend>
			'.$filtre.'
				<div class=centrer>
				' . $dispcheck[15] . $dispcheck[16] . $dispcheck[17] . $dispcheck[1] . $dispcheck[9] . $dispcheck[2] . $dispcheck[4]. $dispcheck[3] . $dispcheck[5] . $dispcheck[8] . $dispcheck[10] . $dispcheck[11] . $dispcheck[12] . $dispcheck[19] . $dispcheck[20] . $dispcheck[13] . $dispcheck[14] . $dispcheck[18] . $dispcheck[7] . $dispcheck[6] .'
				</div>
			</fieldset>
		</div>' ;
	
    return $content ;
    
} #sub form_analyses 

#Rupture Séquence écritures
sub forms_check15 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;

	# Requête Plusieurs références de pièces dans un seul document ##############
	$sql = q {
	WITH numbered_entries AS (
  SELECT
    id_entry,
    id_facture,
    date_ecriture,
    fiscal_year,
    id_client,
    num_mouvement,
    id_export,
    libelle_journal,
    ROW_NUMBER() OVER (ORDER BY num_mouvement::bigint) AS row_num
  FROM
    tbljournal
  WHERE
    id_client = ?
    AND fiscal_year = ?
    AND num_mouvement <> ''
  GROUP BY
    id_entry,
    id_facture,
    date_ecriture,
    fiscal_year,
    id_client,
    num_mouvement,
    id_export,
    libelle_journal
),
expected_sequences AS (
  SELECT
    MIN(row_num::bigint) AS min_num,
    MAX(row_num::bigint) AS max_num
  FROM
    numbered_entries
)
SELECT
  gs.number::text AS missing_sequence
FROM
  expected_sequences
  CROSS JOIN generate_series(min_num, max_num) AS gs(number)
LEFT JOIN
  numbered_entries ne ON gs.number::text = ne.num_mouvement
WHERE
  ne.num_mouvement IS NULL
ORDER BY
  gs.number::text;
			} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
    if (!defined $args->{menu15} && scalar(@$resultat1) > 0) {$args->{menu15} = '1';}

	my $formlist .='<div class=Titre10>Vérification de rupture dans la numérotation des écritures</div>
	';
	


	if (scalar(@$resultat1) > 0) {
	$content .=	$formlist;
	foreach my $element (@{$resultat1}) {
    # Parcours du hachage et affichage des paires clé-valeur
    foreach my $cle (keys %{$element}) {
        my $valeur = $element->{$cle};
        $content .= '<br><div ><span style="color: red;">!!! Attention rupture dans la numérotation : il manque le numéro '.$valeur.' !!!</span></div>';
    }
	}
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}
	
    return $content ;

} #sub forms_check15

# Rupture Séquence id_facture
# Vérification des formulaires 16
sub forms_check16 {
    my ($r, $args) = @_;
    my $dbh = $r->pnotes('dbh');
    my ($sql, @bind_array, $content, $rupture_messages);

    # Requête pour vérification des ruptures de séquences
    $sql = q {
        SELECT DISTINCT id_facture
        FROM tbljournal
        WHERE id_facture ~ '^\w{2}\d{4}-\d{2}_\d+$'
        AND id_client = ?
        AND fiscal_year = ?
        ORDER BY id_facture;
    };

    my $sth = $dbh->prepare($sql);

    # Remplacer les valeurs des paramètres client et année fiscale par les valeurs appropriées
    my $client = $r->pnotes('session')->{id_client};
    my $year = $r->pnotes('session')->{fiscal_year};

    $sth->execute($client, $year);

    # Construction du contenu HTML
    my $formlist = '<div class=Titre10>Vérification de rupture dans la numérotation des pièces</div>';

    my %sequences;

    while (my ($result) = $sth->fetchrow_array) {
        # Convertir en UTF-8 avant l'affichage
        my $decoded_result = decode('utf-8', $result);

        # Extraire le code de journal et le mois
        my ($code_journal, $month) = $decoded_result =~ /^(\w{2})(\d{4}-\d{2})/;

        # Extraire le numéro après le dernier tiret (-)
        my ($sequence_num) = $decoded_result =~ /_(\d+)$/;

        if (defined $code_journal && defined $month && defined $sequence_num) {
            push @{$sequences{$code_journal}{$month}}, $sequence_num;
        }
    }

    foreach my $code_journal (keys %sequences) {
        foreach my $month (keys %{$sequences{$code_journal}}) {
            my @sequence_nums = sort {$a <=> $b} @{$sequences{$code_journal}{$month}};
            my $previous_sequence = 0;

            foreach my $sequence_num (@sequence_nums) {
                if ($sequence_num != $previous_sequence + 1) {
                    my $missing_sequence = $previous_sequence + 1;
                    while ($missing_sequence < $sequence_num) {
                        my $missing_facture = sprintf("%s%s_%02d", $code_journal, $month, $missing_sequence);
                        $rupture_messages .= '<br><div><span style="color: red;">!!! Attention rupture dans la numérotation : il manque le numéro '.$missing_facture.' !!!</span></div>';
                        $missing_sequence++;
                    }
                }
                $previous_sequence = $sequence_num;
            }
        }
    }

    if ($rupture_messages) {
        if (!defined $args->{menu16}) {$args->{menu16} = '1';}
        return $formlist . $rupture_messages;
    } else {
        return $formlist . '<br><div class="intro2"><h3>Conforme</h3></div>';
    }
}

# Doublon id_facture
# Vérification des formulaires 17
sub forms_check17 {
    my ($r, $args) = @_;
    my $dbh = $r->pnotes('dbh');

    # Requête SQL pour récupérer id_facture et documents1
    my $sql = q {
        SELECT id_facture, documents1
        FROM tbljournal
        WHERE id_client = ?
          AND fiscal_year = ?
        ORDER BY id_facture;
    };

    my $sth = $dbh->prepare($sql);

    # Paramètres client et année fiscale
    my $client = $r->pnotes('session')->{id_client};
    my $year = $r->pnotes('session')->{fiscal_year};

    $sth->execute($client, $year);

    # Stockage des informations pour traitement
    my %facture_docs;
    my $inconsistent_messages = '';

    while (my ($id_facture, $documents1) = $sth->fetchrow_array) {
        next unless defined $id_facture && defined $documents1;

        # Nettoyer les espaces ou caractères invisibles avant la comparaison
        $id_facture =~ s/\s+//g;  # Enlève tous les espaces blancs
        $documents1 =~ s/\s+//g;   # Enlève tous les espaces blancs

        # Ajouter le document à la liste des documents pour ce id_facture
        push @{$facture_docs{$id_facture}}, $documents1;
    }

    # Vérification de la cohérence des documents associés (s'il y a des doublons dans les documents)
    foreach my $id_facture (keys %facture_docs) {
        my %unique_docs = map { $_ => 1 } @{$facture_docs{$id_facture}};
        if (keys %unique_docs > 1) {
            # Doublon détecté
            my $all_docs = join(', ', keys %unique_docs);
            $inconsistent_messages .= qq{
                <br><div><span style="color: red;">
                !!! Le numéro de pièce <a href="menu?search=1&search_piece=$id_facture" class=nav > $id_facture</a> est associé à des documents différents : <br> $all_docs !!!
                </span></div>
            };
        } 
    }

    # Générer le rapport HTML
    my $results = '<div class=Titre10>Vérification de la cohérence des documents1 associés aux numéros de pièces</div>';

    if ($inconsistent_messages) {
		if (!defined $args->{menu17}) {$args->{menu17} = '1';}
        return $results . $inconsistent_messages;
    } else {
        return $results . '<br><div class="intro2"><h3>Conforme : Tous les documents sont cohérents</h3></div>';
    }
}


# Vérification des formulaires 18
sub forms_check18 {
    # définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, @bind_array, $content ) ;
    
    # Requête pour les écritures sans documents1
    $sql = q{
SELECT * FROM tbljournal t1 WHERE t1.fiscal_year = ? and t1.id_client = ? 
AND t1.documents1 IS NULL AND t1.libelle_journal NOT LIKE '%CLOTURE%' AND t1.libelle_journal NOT LIKE '%NOUV%'
ORDER BY length(t1.num_mouvement), t1.num_mouvement, t1.date_ecriture, t1.id_entry, t1.id_facture, t1.libelle, t1.libelle_journal, t1.id_paiement, t1.numero_compte, t1.id_line 
    } ;

    my $resultat1 = eval { 
        $dbh->selectall_arrayref( $sql, { Slice => { } }, 
            ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) 
        ) 
    };
    
    if (!defined $args->{menu18} && scalar(@$resultat1) > 0) {
        $args->{menu18} = '1';
    }

    my $formlist .= '<div class="Titre10">Liste des écritures sans Document1 associé</div>' ;

    if (scalar(@$resultat1) > 0) {
        $content .= Template_1($r, $args, $dbh, $resultat1, $formlist);
    } else {
        $content .= $formlist . '<br><div class="intro2"><h3>Aucune écriture sans document trouvé</h3></div>';
    }

    return $content;
}


#Mauvaise référence de pièce dans le document<
sub forms_check1 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;

	# Requête Plusieurs références de pièces dans un seul document ##############
	$sql = q {
select distinct * from tbljournal t1
WHERE  t1.fiscal_year = ?  and t1.id_client = ? and  t1.documents1 not like '%' || t1.id_facture || '%' 
order by date_ecriture
			} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu1} && scalar(@$resultat1) > 0) {$args->{menu1} = '1';}

	my $formlist .='<div class=Titre10>Mauvaise référence de pièce dans le document</div>
	<span class="memoinfo">La référence Pièce de l\'écriture ne correspond pas à celle contenu dans le nom du document1</span>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}
	
    return $content ;

} #sub forms_check1

#Le compte 58 est apuré
sub forms_check2 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Le compte 58 est apuré ##############
	$sql = q {
with t1 as (select fiscal_year, id_client, numero_compte
from tbljournal where fiscal_year = ? and id_client = ? and substring(numero_compte from 1 for 2) IN ('58')
group by fiscal_year, id_client, numero_compte
having sum(credit-debit) != 0)
select distinct * from t1
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.numero_compte = t2.numero_compte
			} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu2} && scalar(@$resultat1) > 0) {$args->{menu2} = '1';}

	my $formlist .='<div class=Titre10>Contrôler les comptes de virements internes (58) qui doivent être soldés</div>';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check2

#écritures lettrées et non équilibrées
sub forms_check3 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête écritures lettrées et non équilibrées ##############
	$sql = q {
		SELECT distinct * FROM tbljournal t1
LEFT JOIN tblexport t2 on t1.id_client = t2.id_client and t1.fiscal_year = t2.fiscal_year and t1.id_export = t2.id_export
INNER JOIN tblcompte t3 ON t1.id_client = t3.id_client AND t1.fiscal_year = t3.fiscal_year AND t1.numero_compte = t3.numero_compte
WHERE t1.id_client = ? AND t1.fiscal_year = ? AND t1.lettrage is not null
AND lettrage IN (SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? group by lettrage having sum(credit-debit) != 0)
ORDER BY t1.date_ecriture
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year} )) };
    if (!defined $args->{menu3} && scalar(@$resultat1) > 0) {$args->{menu3} = '1';}

	my $formlist .='<div class=Titre10>Contrôler les écritures lettrées et non équilibrées</div>';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check3

#Les comptes 471 à 475 sont apurés
sub forms_check4 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Les comptes 471 à 475 sont apurés ##############
	$sql = q {
with t1 as (select fiscal_year, id_client, numero_compte
from tbljournal where fiscal_year = ? and id_client = ? and substring(numero_compte from 1 for 3) IN ('471','472','473','474','475')
group by fiscal_year, id_client, numero_compte
having sum(credit-debit) != 0)
select distinct * from t1
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.numero_compte = t2.numero_compte
			} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu4} && scalar(@$resultat1) > 0) {$args->{menu4} = '1';}

	my $formlist .='<div class=Titre10>Contrôler les comptes d’attente (471 à 475) qui doivent être soldés</div>';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check4

#Les comptes 120 et 129 sont apurés
sub forms_check5 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Les comptes 120 et 129 sont apurés ##############
	$sql = q {
with t1 as (select fiscal_year, id_client, numero_compte
from tbljournal where fiscal_year = ? and id_client = ? and substring(numero_compte from 1 for 3) IN ('120','129') AND libelle_journal NOT LIKE '%CLOTURE%'
group by fiscal_year, id_client, numero_compte
having sum(credit-debit) != 0)
select distinct * from t1
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.numero_compte = t2.numero_compte
			} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu4} && scalar(@$resultat1) > 0) {$args->{menu5} = '1';}

	my $formlist .='<div class=Titre10>Les comptes de résultats de l\'exercice (120 et 129) doivent être soldés</div>
	<span class="memoinfo">Les comptes 120 et 129 doivent être remis à zéro (soldés) pour recevoir le résultat de l\'exercice en cours</span>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check5

#PieceDate <= EcritureDate
sub forms_check6 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête PieceDate <= EcritureDate ##############
	$sql = q {
SELECT * FROM tbljournal t1
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
LEFT JOIN tbldocuments t3 on t1.id_client = t3.id_client and t1.documents1 = t3.id_name
LEFT JOIN tbljournal_liste t4 on t1.id_client = t4.id_client and t1.fiscal_year = t4.fiscal_year and t1.libelle_journal = t4.libelle_journal
LEFT JOIN tblexport t5 on t1.id_client = t5.id_client and t1.fiscal_year = t5.fiscal_year and t1.id_export = t5.id_export
WHERE t1.fiscal_year = ? and t1.id_client = ?AND t1.libelle_journal NOT LIKE '%CLOTURE%' and date_reception::date > date_ecriture::date
ORDER BY length(t1.num_mouvement), t1.num_mouvement, t1.date_ecriture, CASE WHEN t1.libelle_journal ~* 'nouv|NOUV' THEN 1 END, t1.id_entry, t1.id_facture, t1.libelle, t1.libelle_journal, t1.id_paiement, t1.numero_compte, t1.id_line 
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu6} && scalar(@$resultat1) > 0) {$args->{menu6} = '1';}

	my $formlist .='<div class=Titre10>La date d\'écriture est antérieure à celle de la pièce (date du document)</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check6

#PieceDate ≠ exercice
sub forms_check7 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête PieceDate ≠ exercice ##############
	$sql = q {
SELECT * FROM tbljournal t1
INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
LEFT JOIN tbldocuments t3 on t1.id_client = t3.id_client and t1.documents1 = t3.id_name
LEFT JOIN tbljournal_liste t4 on t1.id_client = t4.id_client and t1.fiscal_year = t4.fiscal_year and t1.libelle_journal = t4.libelle_journal
LEFT JOIN tblexport t5 on t1.id_client = t5.id_client and t1.fiscal_year = t5.fiscal_year and t1.id_export = t5.id_export
WHERE t1.fiscal_year = ? and t3.multi = 'f' and t1.id_client = ? AND t1.libelle_journal NOT LIKE '%CLOTURE%' and (date_reception::date > ? or date_reception::date < ?)
ORDER BY length(t1.num_mouvement), t1.num_mouvement, t1.date_ecriture, CASE WHEN t1.libelle_journal ~* 'nouv|NOUV' THEN 1 END, t1.id_entry, t1.id_facture, t1.libelle, t1.libelle_journal, t1.id_paiement, t1.numero_compte, t1.id_line 
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{Exercice_fin_YMD}, $r->pnotes('session')->{Exercice_debut_YMD}) ) };
    if (!defined $args->{menu7} && scalar(@$resultat1) > 0) {$args->{menu7} = '1';}

	my $formlist .='<div class=Titre10>La date de la pièce (date du document) n\'appartient pas à l\'exercice '.$r->pnotes('session')->{fiscal_year}.'</div>
	<span class="memoinfo">Les documents cochés comme "Multi" (disponibles pour tous les exercices) ne sont pas affichés.</span>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check7

#Présence en 6063 "petit équipement" d'écritures > 500 euros HT
sub forms_check8 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête PieceDate ≠ exercice ##############
	$sql = q {
with t1 as (select * from tbljournal where fiscal_year = ? and id_client = ? and substring(numero_compte from 1 for 4) IN ('6063') AND libelle_journal NOT LIKE '%CLOTURE%'
and debit > 50000)
select distinct * from t1
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.id_entry = t2.id_entry
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu8} && scalar(@$resultat1) > 0) {$args->{menu8} = '1';}

	my $formlist .='<div class=Titre10>Présence en 6063 "petit équipement" d\'écritures > 500 euros HT</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check8

#Présence d'une référence de pièce pour chaque écriture
sub forms_check9 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Présence d'une référence de pièce pour chaque écriture ##############
	$sql = q {
select * from tbljournal where fiscal_year = ? AND id_client = ? AND id_facture IS NULL
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu9} && scalar(@$resultat1) > 0) {$args->{menu9} = '1';}

	my $formlist .='<div class=Titre10>Liste des écritures sans référence de pièce</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check9

#Présence d'écriture correspondant potientiellement à un encaissement ou à un paiement en espèce supérieur à 1000€
sub forms_check10 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Présence d'écriture correspondant potientiellement à un encaissement ou à un paiement en espèce supérieur à 1000€ ##############
	$sql = q {
with t1 as (select * from tbljournal where fiscal_year = ? and id_client = ? and substring(numero_compte from 1 for 2) IN ('53') AND libelle_journal NOT LIKE '%CLOTURE%'
and (credit > 100000 or debit > 100000))
select distinct * from t1
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.id_entry = t2.id_entry
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu10} && scalar(@$resultat1) > 0) {$args->{menu10} = '1';}

	my $formlist .='<div class=Titre10>Encaissement ou paiement en espèce supérieur à 1000€</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check10

#Pas de compte 6*  avec un solde créditeur.
sub forms_check11 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Pas de compte 6*  avec un solde créditeur. ##############
	$sql = q {
with t1 as(SELECT fiscal_year, id_client, id_entry, (sum(credit-debit) over (PARTITION BY id_entry))::numeric as solde_crediteur, (sum(debit-credit) over (PARTITION BY id_entry))::numeric as solde_debiteur FROM tbljournal
WHERE fiscal_year = ? and id_client = ? AND libelle_journal NOT LIKE '%CLOTURE%' 
and substring(numero_compte from 1 for 1) IN ('6')
ORDER BY numero_compte, date_ecriture, id_line)
select * from t1 
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.id_entry = t2.id_entry
where solde_crediteur > 0
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu11} && scalar(@$resultat1) > 0) {$args->{menu11} = '1';}

	my $formlist .='<div class=Titre10>Écriture avec un compte de charge (6*) présentant un solde créditeur.</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check11

#Pas de compte 41*  avec un solde créditeur.
sub forms_check19 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Préparer la requête pour obtenir les soldes des comptes 41* avec un solde créditeur
	$sql = q {
with t1 as (select * from calcul_balance(?, ?, ?, ?, ?, 'FM999G999G999G990D00') 
WHERE solde_debit NOT SIMILAR TO '0,00' OR solde_credit NOT SIMILAR TO '0,00' OR debit NOT SIMILAR TO '0,00' OR credit NOT SIMILAR TO '0,00')
select * from t1 where substring(numero_compte from 1 for 2) IN ('41') and solde_credit NOT SIMILAR TO '0,00'
} ;
    
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_fin_DMY}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
    if (!defined $args->{menu19} && scalar(@$resultat1) > 0) {$args->{menu19} = '1';}
	
	my $formlist .='<div class=Titre10>Écriture avec un compte client (41*) présentant un solde créditeur.</div>
		<span class="memoinfo">Les éventuelles dettes clients (acomptes notamment) devraient figurer en 419.</span>';
	
	# Si des résultats existent, les afficher
    if (scalar(@$resultat1) > 0) {
		# Boucle pour afficher chaque compte
		foreach my $compte (@$resultat1) {
			$formlist .= '<div style="margin-bottom: 10px;"><span style="font-weight: bold;color: red;">Vérifier le compte : <a href="compte?numero_compte=' . $compte->{numero_compte} . '" class="nav">'.$compte->{numero_compte}.' - '.$compte->{libelle_compte}.'</a> présentant un solde créditeur de ' . $compte->{solde_credit} . '€</span></div>';
		}
    } else {
        # Si aucun résultat, afficher un message conforme
        $formlist .= '<br><div class="intro2"><h3>Conforme</h3></div>';
    }
    
    return $formlist;
} #sub forms_check19

#Pas de compte 40*  avec un solde débiteur.
sub forms_check20 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Pas de compte 40*  avec un solde débiteur. ##############
	$sql = q {
with t1 as (select * from calcul_balance(?, ?, ?, ?, ?, 'FM999G999G999G990D00') 
WHERE solde_debit NOT SIMILAR TO '0,00' OR solde_credit NOT SIMILAR TO '0,00' OR debit NOT SIMILAR TO '0,00' OR credit NOT SIMILAR TO '0,00')
select * from t1 where substring(numero_compte from 1 for 2) IN ('40') and solde_debit NOT SIMILAR TO '0,00'
} ;

    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_fin_DMY}, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
    if (!defined $args->{menu20} && scalar(@$resultat1) > 0) {$args->{menu20} = '1';}

	my $formlist .='<div class=Titre10>Écriture avec un compte fournisseur (40*) présentant un solde débiteur.</div>
	<span class="memoinfo">Les éventuelles créances fournisseur (acomptes notamment) devraient figurer en 409.</span>';
	
	if (scalar(@$resultat1) > 0) {
		# Boucle pour afficher chaque compte
		foreach my $compte (@$resultat1) {
			$formlist .= '<div style="margin-bottom: 10px;"><span style="font-weight: bold;color: red;">Vérifier le compte : <a href="compte?numero_compte=' . $compte->{numero_compte} . '" class="nav">'.$compte->{numero_compte}.' - '.$compte->{libelle_compte}.'</a> présentant un solde débiteur de ' . $compte->{solde_debit} . '€</span></div>';
		}
	} else {
		# Si aucun résultat, afficher un message conforme
		$formlist .= '<br><div class="intro2"><h3>Aucun compte fournisseur (40*) avec un solde débiteur détecté.</h3></div>';
	}


    return $formlist ;

} #sub forms_check20

#Pas de compte 7*  avec un solde débiteur.
sub forms_check12 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Pas de compte 7*  avec un solde débiteur. ##############
	$sql = q {
with t1 as(SELECT fiscal_year, id_client, id_entry, (sum(credit-debit) over (PARTITION BY id_entry))::numeric as solde_crediteur, (sum(debit-credit) over (PARTITION BY id_entry))::numeric as solde_debiteur FROM tbljournal
WHERE fiscal_year = ? and id_client = ? AND libelle_journal NOT LIKE '%CLOTURE%' 
and substring(numero_compte from 1 for 1) IN ('7')
ORDER BY numero_compte, date_ecriture, id_line)
select * from t1 
INNER JOIN tbljournal t2 ON t1.fiscal_year = t2.fiscal_year and t1.id_client = t2.id_client and t1.id_entry = t2.id_entry
where solde_debiteur > 0
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{id_client}) ) };
    if (!defined $args->{menu12} && scalar(@$resultat1) > 0) {$args->{menu12} = '1';}

	my $formlist .='<div class=Titre10>Écriture avec un compte de produit (7*) présentant un solde débiteur.</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	$content .= Template_1 ($r, $args, $dbh, $resultat1, $formlist );
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check12

#Pas de listes de comptes bancaires avec un solde créditeur pour les comptes 51*
sub forms_check14 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Pas de listes de comptes bancaires avec un solde créditeur pour les comptes 51* ##############
	$sql = q {
with t1 as (select * from calcul_balance(?, ?, ?, ?, ?, 'FM999G999G999G990D00') 
WHERE solde_debit NOT SIMILAR TO '0,00' OR solde_credit NOT SIMILAR TO '0,00' OR debit NOT SIMILAR TO '0,00' OR credit NOT SIMILAR TO '0,00')
select * from t1 where substring(numero_compte from 1 for 2) IN ('51') and solde_credit NOT SIMILAR TO '0,00'
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_fin_YMD},$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
    if (!defined $args->{menu14} && scalar(@$resultat1) > 0) {$args->{menu14} = '1';}

	my $formlist .='<div class=Titre10>Écriture avec un compte bancaire (51*) présentant un solde créditeur.</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	for ( @$resultat1 ) {
	$content .= $formlist.'<br><div class="intro3">Attention le compte "' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '" présente un solde créditeur de ' . $_->{solde_credit} . '€ !!!</div>';
	}
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check14

#Pas de compte 455* présentant un solde débiteur.
sub forms_check13 {
   	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	
	# Requête Pas de compte 455* présentant un solde débiteur. ##############
	$sql = q {
with t1 as (select * from calcul_balance(?, ?, ?, ?, ?, 'FM999G999G999G990D00') 
WHERE solde_debit NOT SIMILAR TO '0,00' OR solde_credit NOT SIMILAR TO '0,00' OR debit NOT SIMILAR TO '0,00' OR credit NOT SIMILAR TO '0,00')
select * from t1 where substring(numero_compte from 1 for 3) IN ('455') and solde_debit NOT SIMILAR TO '0,00'
} ;
    my $resultat1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_fin_YMD},$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
    if (!defined $args->{menu13} && scalar(@$resultat1) > 0) {$args->{menu13} = '1';}

	my $formlist .='<div class=Titre10>Écriture avec un compte d\'associés (455*) présentant un solde débiteur.</div>
	';
	
	if (scalar(@$resultat1) > 0) {
	for ( @$resultat1 ) {
	$content .= $formlist.'<br><div class="intro3">Attention le compte "' . $_->{numero_compte} . ' - ' . $_->{libelle_compte} . '" présente un solde débiteur de ' . $_->{solde_debit} . '€ !!!</div>';
	}
	} else {
	$content .= $formlist.'<br><div class="intro2"><h3>Conforme</h3></div>';	
	}

    return $content ;

} #sub forms_check13

#/*—————————————— Modéle 1 ——————————————*/
sub Template_1 {
   	# définition des variables
	my ( $r, $args, $dbh, $resultat1, $formlist ) = @_ ;

	############## ligne d'en-têtes ##############	
    my $entry_list .= '
    <br>
    <ul class="wrapper style1">
	<li class="style1"><div class=flex-table><div class=spacer></div>
	<span class=headerspan style="width: 7.5%;">Date</span>
	<span class=headerspan style="width: 7.5%;">Journal</span>
	<span class=headerspan style="width: 7.5%;">Libre</span>
	<span class=headerspan style="width: 7.5%;">Compte</span>
	<span class=headerspan style="width: 10%;">Pièce</span>
	<span class=headerspan style="width: 29.9%;">Libellé</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Débit</span>
	<span class=headerspan style="width: 7.5%; text-align: right;">Crédit</span>
	<span class=headerspan style="width: 1%;">&nbsp;</span>
	<span class=headerspan style="width: 6%;">Lettrage</span>
	<span class=headerspan style="width: 1%;">&nbsp;</span>
	<span class=headerspan style="width: 3%;">&nbsp;</span>
	<span class=headerspan style="width: 3%;">&nbsp;</span>
	<span class=headerspan style="width: 1%; text-align: right;">&nbsp;</span>
	<div class=spacer></div></div></li>
	' ;
	
	my $id_entry = '';

    for ( @$resultat1 ) {
	#si on est dans une nouvelle entrée, clore la précédente et ouvrir la suivante
		unless ($_->{id_entry} eq $id_entry ) {

			#lien de modification de l'entrée
			my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry} ;

			#cas particulier de la première entrée de la liste : pas de liste précédente
			unless ( $id_entry ) {
				$entry_list .= '<li class=listitem3>' ;
			} else {
				$entry_list .= '</a></li><li class=listitem3>'
			} #	    unless ( $id_entry ) 

		} #	unless ( $_->{id_entry} eq $id_entry )

	#marquer l'entrée en cours
	$id_entry = $_->{id_entry} ;
	
	my $http_link_documents1 = '<span class=blockspan style="width: 2%; text-align: center;"><img id="documents_'.$_->{id_line}.'" class="line_icon_hidden" height="16" width="16" title="Ouvrir le document1" src="/Compta/style/icons/documents.png" alt="document1"></span>';
	my $http_link_documents2 = '<span class=blockspan style="width: 2%; text-align: center;"><img id="releve_'.$_->{id_line}.'" class="line_icon_hidden" height="16" width="16" title="Ouvrir le document2" src="/Compta/style/icons/releve-bancaire.png" alt="releve-bancaire"></span>';
	#Affichage lien docs1 si docs1
	if ( ($_->{documents1} || '') =~ /docx|odt|pdf|jpg/i ) { 
		my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?' ;
		my $id_name_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $_->{documents1} ) ;
		if ($id_name_documents->[0]->{id_name} || '') {
		$http_link_documents1 = '<a class=nav href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($id_name_documents->[0]->{id_name} || '').'">				
		<span class=blockspan style="width: 3%; text-align: center;"><img id="documents_'.$_->{id_line}.'" class="line_icon_visible" height="16" width="16" title="Ouvrir le document1" src="/Compta/style/icons/documents.png" alt="document1"></span></a>';
		}
	} 	
	#Affichage lien docs2 si docs2
	if ( ($_->{documents2} || '') =~ /docx|odt|pdf|jpg/i ) { 
	    my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?' ;
		my $id_name_documents = $dbh->selectall_arrayref( $sql, { Slice => { } }, $_->{documents2} ) ;
		if ($id_name_documents->[0]->{id_name} || '') {
		$http_link_documents2= '<a class=nav href="/'.$r->pnotes('session')->{racine}.'/docsentry?id_name='.($id_name_documents->[0]->{id_name} || '').'">				
		<span class=blockspan style="width: 3%; text-align: center;"><img id="releve_'.$_->{id_line}.'" class="line_icon_visible" height="16" width="16" title="Ouvrir le document2" src="/Compta/style/icons/releve-bancaire.png" alt="releve-bancaire"></span></a>';	
		}
	} 	
	
	#joli formatage de débit/crédit
	( my $debit = sprintf( "%.2f", $_->{debit}/100 ) ) =~ s/\./\,/g; 
	$debit =~ s/\B(?=(...)*$)/ /g ;
	( my $credit = sprintf( "%.2f", $_->{credit}/100 ) ) =~ s/\./\,/g; 
	$credit =~ s/\B(?=(...)*$)/ /g ;
	
	#lien de modification de l'entrée
	my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8( $_->{libelle_journal} ) . '&amp;id_entry=' . $_->{id_entry} ;
	
	$entry_list .= '
	<div class=flex-table><div class=spacer></div><a href="' . $id_entry_href . '">
	<span class=displayspan style="width: 7.5%;">' . $_->{date_ecriture} . '</span>
	<span class=displayspan style="width: 7.5%;">' . $_->{libelle_journal} .'</span>
	<span class=displayspan style="width: 7.5%;">' . ($_->{id_paiement} || '&nbsp;') . '</span>
	<span class=displayspan style="width: 7.5%;">' . $_->{numero_compte} . '</span>
	<span class=displayspan style="width: 10%;">' . ($_->{id_facture} || '&nbsp;') . '</span>
	<span class=displayspan style="width: 29.9%;">' . ($_->{libelle} || '&nbsp;') . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' . $debit . '</span>
	<span class=displayspan style="width: 7.5%; text-align: right;">' .  $credit . '</span>
	<span class=displayspan style="width: 1%;">&nbsp;</span>
	<span class=displayspan style="width: 6%;">' . ($_->{lettrage} || '&nbsp;') . '</span>
	<span class=displayspan style="width: 1%;">&nbsp;</span>
	'.$http_link_documents1.'
	'.$http_link_documents2.'
	<span class=displayspan style="width: 1%; text-align: right;">&nbsp;</span>
	</a>
	<div class=spacer></div></div>
	' ;

	}
	
	#on clot la liste s'il y avait au moins une entrée dans le journal
    $entry_list .= '</a></li>' if ( @$resultat1 ) ;
	
    $formlist .= ''. $entry_list.'</ul>';

    return $formlist ;

} #sub forms_check1

#my ($data_ref, $data_ref_n1) = calculer_formulaire($r, $args, $dbh, '2033A');
sub calculer_formulaire {
    my ($r, $args, $dbh, $form) = @_;
    my (%data, %data_n1, $sql, $result_set, $result_set_N1);
    
    my $dateN1_ymd = Time::Piece->strptime( $r->pnotes('session')->{Exercice_fin_DMY_N1}, "%d/%m/%Y" )->ymd;

	my $verifsql1 = 'SELECT COUNT(compte_journal) FROM tblbilan_detail WHERE id_client = ? AND formulaire = ? AND compte_journal IS NOT NULL';
	my $result_sql1 = eval { $dbh->selectrow_array($verifsql1, undef, $r->pnotes('session')->{id_client}, $form) };
	my $verifsql2 = 'SELECT COUNT(exercice) FROM tblbilan_code WHERE id_client = ? AND formulaire = ? AND exercice like \'%N1%\'';
	my $result_sql2 = eval { $dbh->selectrow_array($verifsql2, undef, $r->pnotes('session')->{id_client}, $form) };
	
	if ($result_sql1 eq 0) {
	
		$sql = 'select * from calcul_balance(?, ?, ?, ?, ?, \'FM999999999990D00\') 
		WHERE solde_debit NOT SIMILAR TO \'0,00\' OR solde_credit NOT SIMILAR TO \'0,00\' OR debit NOT SIMILAR TO \'0,00\' OR credit NOT SIMILAR TO \'0,00\'';
		# Exécuter la requête SQL pour l'année 
		$result_set = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{Exercice_fin_YMD},$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}) ) };
		# Traitement des résultats de l'année en cours
		Traiter_formulaire($r, $args, $dbh, $result_set, $form, \%data);
	
	} else {
		$sql = '
		with t1 as (SELECT id_client, fiscal_year, numero_compte, id_entry, id_line, date_ecriture, libelle_journal, debit/100::numeric as debit, credit/100::numeric as credit FROM tbljournal WHERE id_client = ? and fiscal_year = ? AND libelle_journal NOT LIKE \'%CLOTURE%\'
		ORDER BY numero_compte, date_ecriture, id_line) 
		SELECT t1.numero_compte, id_entry, id_line, date_ecriture, t1.libelle_journal, to_char(debit, \'FM999999999990D00\') as debit, to_char(credit, \'FM999999999990D00\') as credit, to_char(sum(credit-debit) over (PARTITION BY numero_compte), \'FM999999999990D00\') as solde_crediteur, to_char(sum(debit-credit) over (PARTITION BY numero_compte), \'FM999999999990D00\') as solde_debiteur
		FROM t1 INNER JOIN tblcompte t2 using (id_client, fiscal_year, numero_compte) 
		' ; 
		$result_set = $dbh->selectall_arrayref( $sql, { Slice => { } },($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year})) ;
		# Traitement des résultats de l'année en cours
		Traiter_formulaire($r, $args, $dbh, $result_set, $form, \%data);
	} 

	if ($result_sql2 eq 0) {

	} else {
		# Exécuter la requête SQL pour l'année précédente (N-1)  
		$result_set_N1 = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, (($r->pnotes('session')->{fiscal_year} ) -1), $dateN1_ymd,$r->pnotes('session')->{id_client}, (($r->pnotes('session')->{fiscal_year} ) -1)) ) };

		# Traitement des résultats de l'année précédente (N-1)
		Traiter_formulaire($r, $args, $dbh, $result_set_N1, $form, \%data_n1);
	}

    return (\%data, \%data_n1);
}

sub Traiter_formulaire {
    my ($r, $args, $dbh, $result_set, $form, $data) = @_;
    
    my $sql = '
	SELECT t1.*, t2.compte_mini, t2.compte_maxi, t2.compte_journal, t2.solde_type, t2.si_debit, t2.si_credit, t2.si_soustraire
	FROM tblbilan_code t1
	LEFT JOIN tblbilan_detail t2 ON t1.id_client = t2.id_client AND t1.code = t2.code AND t1.formulaire = T2.formulaire 
	WHERE t1.id_client = ? AND t1.formulaire = ?
    ORDER BY t1.code';
		
	# Exécuter la requête SQL
	my $result_options = eval { $dbh->selectall_arrayref( $sql, { Slice => { } }, ($r->pnotes('session')->{id_client}, $form) ) };

    foreach my $item (@$result_set) {
		
		$item->{'solde_debit'} = defined($item->{'solde_debit'}) ? $item->{'solde_debit'} =~ s/,/./r : undef;
		$item->{'solde_credit'} = defined($item->{'solde_credit'}) ? $item->{'solde_credit'} =~ s/,/./r : undef;
		$item->{'debit'} = defined($item->{'debit'}) ? $item->{'debit'} =~ s/,/./r : undef;
		$item->{'credit'} = defined($item->{'credit'}) ? $item->{'credit'} =~ s/,/./r : undef;

		foreach my $row (@$result_options) {
			my $code       = $row->{'code'};
			my $title      = $row->{'title'};
			my $exercice  = $row->{'exercice'};
			my $compte_mini = $row->{'compte_mini'};
			my $compte_maxi = $row->{'compte_maxi'};
			my $compte_journal = $row->{'compte_journal'};
			my $exclude_journal = defined($row->{'compte_journal'}) && $row->{'compte_journal'} =~ /!/ ? 1 : 0;
			# Supprimer le ! de $compte_journal s'il est présent
			$compte_journal =~ s/^!// if defined $compte_journal;
			my $solde_type = $row->{'solde_type'};
			my $si_debit = $row->{'si_debit'};
			my $si_credit = $row->{'si_credit'};
			my $si_soustraire = $row->{'si_soustraire'};
			
			my $numero_compte = $item->{'numero_compte'};
			$numero_compte =~ s/\D//g;  # Supprimer tous les caractères non numériques
			# Remplir avec des zéros à droite pour avoir 6 chiffres
			if (length($numero_compte) < 6) {
				$numero_compte .= '0' x (6 - length($numero_compte));
			}

            my $solde_debit   = $item->{'solde_debit'} || 0;
            my $solde_credit  = $item->{'solde_credit'} || 0;
            my $libelle_journal = $item->{'libelle_journal'};
            my $debit   = $item->{'debit'} || 0;
            my $credit  = $item->{'credit'} || 0;
            $data->{$code}{var} //= 0;
            $data->{$code}{title} = 'title="Case '.($row->{'code'} || '').' => '.($row->{'title'} || '').'"';
            $data->{$code}{style} = 'style="top: '.($row->{'style_top'}|| '').'px; left: '.($row->{'style_left'}|| '').'px; width: '.($row->{'style_width'}|| '0').'px; height: '.($row->{'style_height'}|| '').'px;"';
			$data->{$code}{exercice} = $row->{'exercice'};
			$data->{$code}{titleb} = $row->{'title'} || '';

            # Vérifiez si le numéro de compte satisfait les critères récupérés de la table
            if (defined $compte_mini) {
				
				my $num_digits_mini = length($compte_mini); # Détermine le nombre de chiffres à prendre en compte
				my $num_digits_maxi = length($compte_maxi); # Détermine le nombre de chiffres à prendre en compte
				# Prend les premiers $num_digits chiffres du numéro de compte
				my $first_digits_mini = substr($numero_compte, 0, $num_digits_mini);
				my $first_digits_maxi = substr($numero_compte, 0, $num_digits_maxi);
				
			if ($first_digits_mini >= $compte_mini && $first_digits_maxi <= $compte_maxi &&
				(!defined $compte_journal || 
				 (defined $compte_journal && $exclude_journal eq 0 && $libelle_journal =~ /$compte_journal/) ||
				 (defined $compte_journal && $exclude_journal eq 1 && $libelle_journal !~ /$compte_journal/))) {

					# Utilisez les critères récupérés pour déterminer l'action appropriée
					if ($si_debit eq 't' && $solde_type eq 'solde_debit' && $solde_debit > 0) {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $debit - $credit) : ($data->{$code}{var} += $debit - $credit);
					} elsif ($si_credit eq 't' && $solde_type eq 'solde_credit' && $solde_credit > 0) {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $credit - $debit) : ($data->{$code}{var} += $credit - $debit);
					} elsif ($si_debit eq 'f' && $solde_type eq 'solde_debit') {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $debit - $credit) : ($data->{$code}{var} += $debit - $credit);
					} elsif ($si_credit eq 'f' && $solde_type eq 'solde_credit') {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $credit - $debit) : ($data->{$code}{var} += $credit - $debit);
					} elsif ($solde_type eq 'montant_debit') {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $debit) : ($data->{$code}{var} += $debit);
					} elsif ($solde_type eq 'montant_credit') {
						$si_soustraire eq 't' ? ($data->{$code}{var} -= $credit) : ($data->{$code}{var} += $credit);
						#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => $si_soustraire ' . $si_soustraire .' $code '.$code.' et $credit '.$credit.' et $debit '.$debit.' total $data->{$code}{var} '.$data->{$code}{var}.'');
					}
				}
            } elsif (defined $title && $title ne '') {
				my $title = $row->{'title'} || '';
my $total = 0;
my $operator = '+';

# Étape 1 : Vérification si la ligne commence par "si ... alors"
if ($title =~ /^si\s+/) {
    # Traitement des conditions "si ... alors"
    if ($title =~ /^si\s+(.+?)\s+(sup|inf)\s+(\d+)\s+alors\s+(.+)$/) {
        my $condition_expr = $1;  # Expression à évaluer avant la condition
        my $condition_operator = $2;  # 'sup' ou 'inf'
        my $threshold = $3;  # Seuil
        my $then_expr = $4;  # Ce qui doit être fait si la condition est vraie

        # Remplacer les variables dans l'expression de condition par leurs valeurs
        $condition_expr =~ s/(\w+)/$data->{$1}{var} || 0/ge;
        my $condition_result = eval $condition_expr;  # Calcul de la condition

        # Vérification de la condition
        if (($condition_operator eq 'sup' && $condition_result > $threshold) || 
            ($condition_operator eq 'inf' && $condition_result < $threshold)) {
            # Si la condition est vraie, on effectue l'opération après "alors"
            $then_expr =~ s/(\w+)/$data->{$1}{var} || 0/ge;
            $total = eval $then_expr;  # Effectuer le calcul dans l'expression après "alors"
        } else {
            $total = 0;  # Condition non remplie, résultat = 0
        }
    }
    
    # Supprimer la portion "si ... alors" traitée de la chaîne
    $title =~ s/^si\s+.+\s+(sup|inf)\s+\d+\s+alors\s+.+//;
}

# Étape 2 : Si après "si ... alors" il reste des opérations à faire (+ ou -)
my @cases = split /\s*([-+])\s*/, $title;  # Divise la formule en morceaux individuels

foreach my $case (@cases) {
    if ($case eq '+' || $case eq '-') {
        $operator = $case;  # Met à jour l'opérateur actuel
    } else {
        # Applique l'opérateur + ou - sur la valeur de la case
        if ($operator eq '+') {
            $total += ($data->{$case}{var} || 0);  # Ajoute la valeur de la case si l'opérateur est '+'
        } elsif ($operator eq '-') {
            $total -= ($data->{$case}{var} || 0);  # Soustrait la valeur de la case si l'opérateur est '-'
        }
    }
}

# Mise à jour du résultat pour le code donné
$data->{$code}{var} = $total;

			}
		}
    }

}

sub format_value {
    my ($value) = @_;
    if (defined($value) && $value =~ /\d/) {
        if ($value > 0 && $value < 999999999999999) {
            $value = sprintf("%.2f", $value );
            #$value =~ s/\./\,/g; 
        } elsif ($value < 0 && $value > -999999999999999) {
            $value = sprintf("%.2f", $value );
            #$value =~ s/\./\,/g;
        } else {
            $value = '';
        }
    } else {
        $value = '';
    }
    return $value;
}

sub format_arrondie {
    my ($value) = @_;
    if (defined($value) && $value =~ /\d/) {
        if ($value > 0 && $value < 999999999999999) {
            $value = int($value + 0.5) ;
            $value =~ s/\B(?=(...)*$)/ /g ;
            #$value =~ s/\./\,/g; 
        } elsif ($value < 0 && $value > -999999999999999) {
            $value = int($value - 0.5) ;
            $value =~ s/\B(?=(...)*$)/ /g ;
            #$value =~ s/\./\,/g;
        } else {
            $value = '&nbsp;';
        }
    } else {
        $value = '&nbsp;';
    }
    return $value;
}

#/*—————————————— Page principale des options ——————————————*/
sub list_options {
	
	# définition des variables
	my ( $r, $args ) = @_ ;
	my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
	my $id_client = $r->pnotes('session')->{id_client} ;
	my $line = "1"; 
	
	#Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
    
	################ Affichage MENU ################
	$content .= display_menu_formulaire( $r, $args ) ;
	################ Affichage MENU ################
	
	#/************ ACTION DEBUT *************/
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter le formulaire 1' 	  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '1' ) {
		
		$args->{bilan_form} ||= undef;
		$args->{bilan_desc} = defined($args->{bilan_desc}) ? ($args->{bilan_desc} =~ s/^\s+|\s+$//gr eq '' ? undef : $args->{bilan_desc}) : undef;
		$args->{bilan_disp} ||= 'f';
		$args->{bilan_doc} ||= undef;
		$args->{bilan_width} ||= undef;
		$args->{bilan_height} ||= undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{bilan_form}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'INSERT INTO tblbilan (id_client, bilan_form, bilan_desc, bilan_doc, bilan_width, bilan_height, bilan_disp) values (?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $args->{bilan_form}, $args->{bilan_desc}, $args->{bilan_doc}, $args->{bilan_width}, $args->{bilan_height}, $args->{bilan_disp}) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$content .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$content .= Base::Site::util::generate_error_message('Le formulaire '.($args->{bilan_form} || '').' existe déjà') ;
				} else {$content .= Base::Site::util::generate_error_message($@);}
			} else {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout formulaire '.($args->{bilan_form} || '').'');
				#Redirection
				$args->{restart} = 'bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{bilan_form}).'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Modifier le formulaire 01' 	  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '01' ) {
		
		$args->{formulaire} ||= undef;
		$args->{bilan_desc} = defined($args->{bilan_desc}) ? ($args->{bilan_desc} =~ s/^\s+|\s+$//gr eq '' ? undef : $args->{bilan_desc}) : undef;
		$args->{bilan_disp} ||= 'f';
		$args->{bilan_doc} ||= undef;
		$args->{bilan_width} ||= undef;
		$args->{bilan_height} ||= undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{formulaire}] );
		if ($erreur) {
		$content .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'UPDATE tblbilan SET bilan_desc = ?, bilan_doc = ?, bilan_width = ?, bilan_height = ?, bilan_disp = ? WHERE id_client = ? and bilan_form = ?' ;
			@bind_array = ( $args->{bilan_desc}, $args->{bilan_doc}, $args->{bilan_width}, $args->{bilan_height}, $args->{bilan_disp}, $r->pnotes('session')->{id_client}, $args->{formulaire}) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				$content .= Base::Site::util::generate_error_message($@);
			} else {
				#Redirection
				$args->{restart} = 'bilan?options&formulaire='.(URI::Escape::uri_escape_utf8($args->{formulaire})||'').'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer le formulaire 02' 	  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '02' ) {

		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}) ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=03&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}).'' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le formulaire ' . $args->{formulaire}.' ?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
	} 
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer le formulaire 03' 	  #
	#######################################################################
	if ( defined $args->{options} && $args->{options} eq '03' ) {
		$sql = 'DELETE FROM tblbilan WHERE id_client = ? and bilan_form = ?' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire}) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			$content .= Base::Site::util::generate_error_message('' . $@ . '') ;
		} else {
			Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => Suppression du formulaire ' . $args->{formulaire}.' ');
			#Redirection
			$args->{restart} = 'bilan?options';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}

	}
   
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Importer' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '05' && defined $args->{formulaire} && $args->{formulaire} ne '') {
		$content .= process_import( $r, $args) ;

	}
	
    #/************ ACTION FIN *************/
	
	$content .= '<div class="wrapper-docs-entry">
    <fieldset class="pretty-box">
    <legend><h3 class="Titre09">Gestion des Options</h3></legend>
    <div class="centrer">';
    
    if (defined $args->{options} && $args->{options} eq '0'){
		$content .= form_nouveau_formulaire( $r, $args  ) ;
	} elsif (defined $args->{options} && ($args->{options} eq '04' || $args->{options} eq '05')){
		$content .= form_importer_formulaire( $r, $args  ) ;
	}
		
    $content .= '<div class="Titre10">
	<span class=check><a href="bilan?options=0" title="Cliquer pour ajouter un nouveau formulaire" class="label3">
	Ajouter un formulaire<span class="plus">+</span></a></span>
    <div class="centrer"> Liste des formulaires</div></div>
	';

	my $tblbilan = Base::Site::bdd::get_tblbilan($dbh, $r);
    
    ############## MISE EN FORME DEBUT ##############
    
    #gestion des options

	#Requête de la liste des Tags de documents
	my $tags = '
	<ul class="main-nav2">';

	for (@{$tblbilan}) {
			if (defined $_->{bilan_form} && $_->{bilan_form} ne '') {
				my $tags_nom = $_->{bilan_form};
				my $tags_href = '/' . $r->pnotes('session')->{racine} . '/bilan?options&formulaire=' . URI::Escape::uri_escape_utf8($_->{bilan_form});
				my $tags_class = '';
				if ( defined $args->{formulaire} && $args->{formulaire} eq $_->{bilan_form}) {
				$tags_class = "men2select";
				$tags_href = '/' . $r->pnotes('session')->{racine} . '/bilan?options';
				}
			
				$tags .= '<li><a class="men men2 '.$tags_class.'" href="' . $tags_href . '" >' . $tags_nom . '</a></li>';
			}
	}
	

	if (!@$tblbilan) {
		$content .= '<div class="warnlite">*** Aucun formulaire trouvé ***</div>';
	}
	$tags .= '</ul></div>';
		
	$content .= $tags;

	if (defined $args->{formulaire} && $args->{formulaire} ne ''){
		
		$sql = 'SELECT * FROM tblbilan WHERE id_client = ? and bilan_form = ?';
		my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{formulaire}) };

		#ligne des en-têtes
		$content .= '<ul class="wrapper10">
		<li class="style2 ">
		<div class="spacer"></div>
			<span class=headerspan style="width: 0.5%;">&nbsp;</span>
			<span class=headerspan style="width: 10%;  text-align: center;">Formulaire</span>
			<span class=headerspan style="width: 26%;  text-align: center;">Description</span>
			<span class=headerspan style="width: 22%;  text-align: center;">Document</span>
			<span class=headerspan style="width: 7%;  text-align: center;">Width</span>
			<span class=headerspan style="width: 7%;  text-align: center;">Height</span>
			<span class=headerspan style="width: 5%;  text-align: center;">Afficher</span>
			<span class=headerspan style="width: 22.5%;  text-align: center;">&nbsp;</span>
		<div class="spacer"></div>
		</li>
	' ;
		
		for ( @$result_set ) {
			
			my $delete_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=02&formulaire=' . URI::Escape::uri_escape_utf8($_->{bilan_form}) ;
			my $valid_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=01&formulaire=' . URI::Escape::uri_escape_utf8($_->{bilan_form}) ;
			my $export_href = '/'.$r->pnotes('session')->{racine}.'/export?select_export=tblbilan&formulaire=' . URI::Escape::uri_escape_utf8($_->{bilan_form}) ;
			my $import_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=04&formulaire=' . URI::Escape::uri_escape_utf8($_->{bilan_form}) ;
							
			$content .= '
			<li id="line_'.(URI::Escape::uri_escape_utf8($_->{bilan_form}) || '').'" class="style1">
			<div class="spacer"></div> 
			<form method=POST>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan style="width: 10%;"><input class="formMinDiv2" type=text name="bilan_form" value="' . ($_->{bilan_form} || '') . '" disabled></span>
			<span class=displayspan style="width: 26%;"><input class="formMinDiv2" placeholder="Entrer la description du formulaire" type=text name="bilan_desc" value="' . ($_->{bilan_desc} || '')  . '" ></span>
			<span class=displayspan style="width: 22%;"><input class="formMinDiv2" placeholder="Entrer le chemin du formulaire" type=text name="bilan_doc" value="' . ($_->{bilan_doc} || '')  . '" ></span>
			<span class=displayspan style="width: 7%;"><input class="formMinDiv2" placeholder="Width ex:960" title="Entrer la position width du formulaire" type=text name="bilan_width" value="' . ($_->{bilan_width} || '') . '" pattern="[0-9]*"></span>
			<span class=displayspan style="width: 7%;"><input class="formMinDiv2" placeholder="Height ex:1323" title="Entrer la position height du formulaire" type=text name="bilan_height" value="' . ($_->{bilan_height} || '') . '" pattern="[0-9]*"></span>
			<span class=displayspan style="width: 3%; text-align: center; "><input type="checkbox" name="bilan_disp" title="Cocher pour afficher le formulaire" value="on" ' . (defined $_->{bilan_disp} && $_->{bilan_disp} eq 't' ? ' checked' : '') . '><input type=hidden name="bilan_disp" value="off" ></span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan ><input type="submit" formaction="' . $valid_href . '" style="color:black;" title="Modifier le formulaire" class="btn-vert" value="Modifier"></span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan><input type="submit" formaction="' . $delete_href . '" style="color:black;" title="Supprimer le formulaire" class="btn-rouge" value="Supprimer"></span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan><input type="submit" formaction="' . $export_href . '" style=" color: black;" title="Exporter les données du formulaire" class="btn-orange" value="Exporter"></span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			<span class=displayspan><input type="submit" formaction="' . $import_href . '" style=" color: black;" title="Importer les données du formulaire" class="btn-gris" value="Importer"></span>
			<span class=displayspan style="width: 1%;">&nbsp;</span>
			</form>
			<div class="spacer"></div>
			</li>' ;	
		}
	
	}
	
	$content .= '</ul>';

	if ( defined $args->{options} && $args->{options} ne '' && $args->{options} =~ /^(10|11|12|13|14|15)$/ ) {
		$content .= New_comptes( $r, $args  ) ;
		$content .= '<hr style="margin: 1em 0 1em 0;" class="mainPageTutoriel">' ;
		$content .= Display_comptes( $r, $args  ) ;
	} 
	
	if ( defined $args->{formulaire} && $args->{formulaire} ne '') {
		$content .= form_new_options( $r, $args  ) ;
		$content .= form_options_formulaires( $r, $args ) ;
	}
	
	$content .= '</div></div>';
	$content .= '<script>
				focusAndChangeColor3("'.($args->{code}||'').'");
				</script>';
	return $content ;

} #sub visualize

#/*—————————————— Importation tblbilan ——————————————*/
sub process_import {
    my ($r, $args) = @_;
    my $content = '';
    my $dbh = $r->pnotes('dbh') ;

    unless ($args->{import_file} || $args->{import_file2} ) {
        $content .= Base::Site::util::generate_error_message('Aucun fichier n\'a été sélectionné pour le téléchargement!');
    } else {
		
		my $upload_fh;
		if ($args->{import_file2}) {
			# Si un chemin de fichier est spécifié dans les arguments, ouvrez-le
			open($upload_fh, '<', $args->{import_file2}) or do {
				$content .= Base::Site::util::generate_error_message('Impossible d\'ouvrir le fichier '.$args->{import_file2}.' : '.$!.' ');
				return $content; 
			};
		
		} else {
			my $req = Apache2::Request->new($r);
			my $upload = $req->upload("import_file") or do {
				$content .= Base::Site::util::generate_error_message('Impossible d\'ouvrir le fichier '.$args->{import_file}.' : '.$!.' ');
				return $content; 
			};
			$upload_fh = $upload->fh();
		}
		
        my $tblbilan_code = '';
        my $tblbilan_detail = '';
        my $tblbilan = '';
        my $valid_data = 1;
        my $rowCount = 0;
        # Initialisation d'un dictionnaire pour suivre les valeurs déjà ajoutées à tblbilan_code
		my %seen_values;

        while (my $data = <$upload_fh>) {
            $rowCount = $rowCount + 1;
            if ($data =~ /FormDesc|FormDoc|Code/) { next; }
            chomp($data);
            eval { $data = Encode::decode("utf8", $data, Encode::FB_CROAK) };
            if ($@) {
                $content .= '<h3 class=warning>Les données transmises ne sont pas au format UTF-8, importation impossible</h3>';
                $valid_data = 0;
                last;
            }

			my $sep= '';
			my $separateur = '';
			
			my @comp_tab = split /\t/, $data;
            my @comp_pip = split /\|/, $data;
            my @comp_pvi = split /;/,  $data;
            my @comp_vir = split /,/,  $data;
            if    ( $#comp_tab >= 8 ) { $sep = "T"; }
            elsif ( $#comp_pip >= 8 ) { $sep = "P"; }
            elsif ( $#comp_vir >= 8 ) { $sep = "V"; }
            elsif ( $#comp_pvi >= 8 ) { $sep = "PV"; }
            
            if ( $sep eq "T" )  { $separateur = '\t'; }
			if ( $sep eq "P" )  { $separateur = '\|'; }
			if ( $sep eq "V" )  { $separateur = ','; }
			if ( $sep eq "PV" ) { $separateur = ';'; }
			
			my @data = split ' *' . $separateur . ' *', $data;

            if (!defined $data[3]) {
                $content .= '<h3 class="warning centrer">ligne ' . $rowCount . ' => colonne 4 : Code est vide <br><br> <a href="menu#importations" style="margin-left: 3ch;">Aide sur les importations</a></h3>';
                $valid_data = 0;
                last;
            }

			# Formatage des données pour les champs
			foreach my $i (0..19) {  # Boucle sur les index de 0 à 19 (20 colonnes)
				if (!defined $data[$i] || $data[$i] eq '') {
					$data[$i] = 'NULL';  # Mettre à NULL si la valeur est vide ou non définie
				} else {
					$data[$i] = $dbh->quote($data[$i]);  # Envelopper la valeur
				}
			}
            
            # On importe pas dans tblbilan_detail s'il n'y a rien à importer !
            if (defined $data[13] && $data[13] eq 'NULL' && defined $data[14] && $data[14] eq 'NULL' && defined $data[15] && $data[15] eq 'NULL' && defined $data[16] && $data[16] eq 'NULL' && defined $data[17] && $data[17] eq 'NULL' && defined $data[18] && $data[18] eq 'NULL' && defined $data[19] && $data[19] eq 'NULL') {
               
			} else {
				#INSERT INTO tblbilan_detail (id_client, formulaire, code, compte_mini, compte_maxi, compte_journal, solde_type, si_debit, si_credit, si_soustraire)
				$tblbilan_detail .= ',(' . $r->pnotes('session')->{id_client} . ', ' . $dbh->quote($args->{formulaire}) . ', ' . $data[5] . ', ' . $data[13] . ', ' . $data[14] . ',  ' . $data[15] . ',  ' . $data[16] . ',  ' . $data[17] . ', ' . $data[18] . ',  ' . $data[19] . ' )';
			}
			
			# #INSERT INTO tblbilan_code (id_client, formulaire, code, exercice, description, title, style_top, style_left, style_width, style_height)
			my $value_to_insert = ',(' . $r->pnotes('session')->{id_client} . ', ' . $dbh->quote($args->{formulaire}) . ', ' . $data[5] . ', ' . $data[12] . ', ' . $data[6] . ', ' . $data[7] . ', ' . $data[8] . ', ' . $data[9] . ', ' . $data[10] . ', ' . $data[11] . ')';
			
			# Vérifier si la valeur à insérer a déjà été ajoutée
			unless ($seen_values{$value_to_insert}) {
				$tblbilan_code .= $value_to_insert;

				# Marquer la valeur comme ajoutée dans le dictionnaire
				$seen_values{$value_to_insert} = 1;
			}
			
            #INSERT INTO tblbilan (id_client, bilan_form, bilan_desc, bilan_doc, bilan_width, bilan_height, bilan_disp)
            my $limit_1_tblbilan = ',(' . $r->pnotes('session')->{id_client} . ', ' . $dbh->quote($args->{formulaire}) . ', ' . $data[0] . ', ' . $data[1] . ', ' . $data[2] . ', ' . $data[3] . ', ' . $data[4] . ')';
			
			# Vérifier si la valeur à insérer a déjà été ajoutée
			unless ($seen_values{$limit_1_tblbilan}) {
				$tblbilan .= $limit_1_tblbilan;

				# Marquer la valeur comme ajoutée dans le dictionnaire
				$seen_values{$limit_1_tblbilan} = 1;
			}


        }

        if ($valid_data) {
            
            #Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => datadumper ' . Data::Dumper::Dumper($tblbilan_detail) . ' ');
			
			# Insertion des données de tblbilan
            my $sql = '
            INSERT INTO tblbilan (id_client, bilan_form, bilan_desc, bilan_doc, bilan_width, bilan_height, bilan_disp ) VALUES ' . substr($tblbilan, 1) . '
			ON CONFLICT (id_client, bilan_form) DO UPDATE SET
			bilan_desc = excluded.bilan_desc,
			bilan_doc = excluded.bilan_doc,
			bilan_width = excluded.bilan_width,
			bilan_height = excluded.bilan_height,
			bilan_disp = excluded.bilan_disp
			';
            # Insérer les données
            eval { $dbh->do($sql) };
            if ($@) { $content .= '<h3 class=warning>Erreur tblbilan => ' . $@ . '</h3>'; }
            
            # Insertion des données de tblbilan_code dans tblbilan_code
            $sql = '
            INSERT INTO tblbilan_code (id_client, formulaire, code, exercice, description, title, style_top, style_left, style_width, style_height ) VALUES ' . substr($tblbilan_code, 1) . '
			ON CONFLICT (id_client, formulaire, code) DO UPDATE SET
			exercice = excluded.exercice,
			description = excluded.description,
			title = excluded.title,
			style_top = excluded.style_top,
			style_left = excluded.style_left,
			style_width = excluded.style_width,
			style_height = excluded.style_height
            ';
            # Insérer les données
            eval { $dbh->do($sql) };
            if ($@) { $content .= '<h3 class=warning>Erreur tblbilan_code => ' . $@ . '</h3>'; }
			
            # Insertion des données de tblbilan_detail dans tblbilan_detail
            $sql = '
            INSERT INTO tblbilan_detail (id_client, formulaire, code, compte_mini, compte_maxi, compte_journal, solde_type, si_debit, si_credit, si_soustraire ) VALUES ' . substr($tblbilan_detail, 1) . '
			ON CONFLICT (id_client, formulaire, code, compte_mini, compte_maxi) DO UPDATE SET
			compte_journal = excluded.compte_journal,
			solde_type = excluded.solde_type,
			si_debit = excluded.si_debit,
			si_credit = excluded.si_credit,
			si_soustraire = excluded.si_soustraire
            ';
            # Insérer les données
            eval { $dbh->do($sql) };
            if ($@) { $content .= '<h3 class=warning>Erreur tblbilan_detail => ' . $@ . '</h3>'; }

            Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => Restauration du formulaire ' . $args->{formulaire} . ' à partir d\'un fichier.');
        }
    }
    return $content;
}

#/*—————————————— Page Formulaire nouveau  ——————————————*/
sub form_nouveau_formulaire {
	
	# définition des variables
    my ( $r, $args) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ($form_html, $item_num, $baux_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    my $sql = 'SELECT * FROM tblbilan WHERE id_client = ? and bilan_form = ?';
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{bilan_form}) };

	my @champs = (
		["input", "Formulaire", "bilan_form", "flex-10", "respinput", "resplabel", "text", "required", defined $result_set->[0]->{bilan_form} ? $result_set->[0]->{bilan_form} : ""],
		["input", "Description", "bilan_desc", "flex-21", "respinput", "resplabel", "text", "", defined $result_set->[0]->{bilan_desc} ? $result_set->[0]->{bilan_desc} : ""],
		["input", "Afficher", "bilan_disp", "flex-10", "checkinput", "resplabel", "checkbox", 'title="Cocher pour afficher" '. (defined $result_set->[0]->{bilan_disp} && $result_set->[0]->{bilan_disp} eq "t" ? "checked" : "").'', "t"],
		["input", "&nbsp;", "submit_bail", "flex-10", "respbtn btn-vert", "resplabel", "submit", "", "Ajouter"]
	);
	
	if (defined $args->{modifier}) {
		# Formulaire Modification du bail
		$baux_list .= '
			<div class="Titre10"><span class=check2>
				<a href="gestionimmobiliere?baux=1&amp;code='. ($args->{code}||'').'&archive='. ($args->{archive}||'').'" title="fermer la fenêtre" class="label3">
				<span>[X]</span></a></span>
				<div class="centrer green"> Modification du bail : '. $args->{code}.' - '.($result_set->[0]->{immo_libelle}|| '').' </div>
			</div>

			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=0>
			<div class="respform2">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			<input type=hidden name=maj value="1">
			<input type=hidden name=archive value="'.($args->{archive} || 0).'">
			<input type=hidden name=old_code value="'.($result_set->[0]->{immo_contrat}|| '').'" >
			</form>
			<br>
		' ;
		
	} else {
		# Formulaire nouveau
		$baux_list .= '
			<div class="Titre10"><span class=check2>
				<a href="bilan?options" title="fermer la fenêtre" class="label3">
				<span >[X]</span></a></span>
				<div class="centrer green"> Enregistrement d\'un nouveau formulaire </div>
			</div>
			
			<form method=POST action=/' . $r->pnotes('session')->{racine} . '/bilan?options=1>
			<div class="respform2">
			'.Base::Site::util::generate_form_html($r, $args, @champs).'
			</div>
			</form>
			<br>
		';
	}
	
	return $baux_list;
}

#/*—————————————— Page Formulaire nouveau  ——————————————*/
sub form_importer_formulaire {
	# définition des variables
    my ( $r, $args) = @_ ;
    
	# Formulaire nouveau
	my $content .= '
		<div class=Titre10>Importer les données dans le formulaire '.$args->{formulaire}.' <a class=nav href="/'.$r->pnotes('session')->{racine}.'/menu#comptes" style="text-decoration: none; color: white;">[?]</a>
		<span class="check2">
				<a href="bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'" title="fermer la fenêtre" class="label3">
				<span>[X]</span></a></span></div>
		<div class="form-int">
			<form style ="display:inline;" action="/'.$r->pnotes('session')->{racine}.'/bilan?options=05&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'" method=POST enctype="multipart/form-data">
			<input type=file name=import_file>
			<input type="submit" class="btn btn-gris" style ="width : 25%;" value="Cliquez ici pour envoyer">
			</form>
		</div>
		<br>
		';
	
	return $content;
}

#/*—————————————— Page Formulaire nouvelle options ——————————————*/
sub form_new_options {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
    my ($form_html, $item_num, $html_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    if ( defined $args->{options} && $args->{options} eq '10' ) {
		
		$args->{description} = undef;
		$args->{title}  = undef;
		$args->{style_top}  = undef;
		$args->{style_left}  = undef;
		$args->{style_width}  = undef;
		$args->{style_height}  = undef;
		$args->{exercice}  = undef;
		
	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '4' ) {
		$args->{title} = undef;
		$args->{style_top} = undef;
		$args->{style_left} = undef;
		$args->{style_width} = undef;
		$args->{style_height} = undef;
		$args->{exercice} = undef;
		$args->{description} = undef;

		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}) ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=5&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}).'&code=' . $args->{code}.'' ;
		$html_list .= Base::Site::util::generate_error_message('Voulez-vous supprimer le code ' . $args->{code}.' dans le formulaire ' . $args->{formulaire}.' ?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
	} 
    
	# Sélection Exercice
	my $select_exercice = '<select class="formMinDiv2" name="exercice" id="exercice">
	<option value="compteN" '.((defined $args->{exercice} && $args->{exercice} eq "compteN")  ? ' selected' : '').' >Compte N</option>
	<option value="compteN1" '.((defined $args->{exercice} && $args->{exercice} eq "compteN1") ? ' selected' : '').' >Compte N-1</option>
	<option value="formuleN" '.((defined $args->{exercice} && $args->{exercice} eq "formuleN")  ? ' selected' : '').' >Formule N</option>
	<option value="formuleN1" '.((defined $args->{exercice} && $args->{exercice} eq "formuleN1") ? ' selected' : '').' >Formule N-1</option>
	<option value="divers" '.((defined $args->{exercice} && $args->{exercice} eq "divers") ? ' selected' : '').' >Divers</option>
	</select>';
	
	#ligne des en-têtes Frais en cours
    $html_list .= '
		<div class="Titre10 centrer"><a href="bilan?options&formulaire=' . (URI::Escape::uri_escape_utf8($args->{formulaire})||'').'" style="color: white; text-decoration: none;">Gestion des codes dans le formulaire ' . ($args->{formulaire}||'').'</a></div>
		<ul class="wrapper100">
		<li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<span class=headerspan style="width: 7%; text-align: center;">Code</span>
		<span class=headerspan style="width: 30%; text-align: center;">Description</span>
		<span class=headerspan style="width: 8%; text-align: center;">Exercice</span>
		<span class=headerspan style="width: 24%; text-align: center;">Title</span>
		<span class=headerspan style="width: 5%; text-align: center;">Top</span>
		<span class=headerspan style="width: 5%; text-align: center;">Left</span>
		<span class=headerspan style="width: 5%; text-align: center;">Width</span>
		<span class=headerspan style="width: 5%; text-align: center;">Height</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 2%;">&nbsp;</span>
		<span class=headerspan style="width: 1%;">&nbsp;</span>
		<div class=spacer></div></li>' ;
		
	$html_list .= '
		<li class="style1">   
		<div class="spacer"></div> 
		<form method=POST action=/' . $r->pnotes('session')->{racine} . '/bilan?options=2>
		<span class=displayspan style="width: 1%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;"><input class="formMinDiv2" type=text name="code" value="' . ($args->{code}  || '') . '" ></span>
		<span class=displayspan style="width: 30%;"><input class="formMinDiv2" type=text name="description" value="' . ($args->{description} || '')  . '" ></span>
		<span class=displayspan style="width: 8%;">'.$select_exercice.'</span>
		<span class=displayspan style="width: 24%;"><input class="formMinDiv2" type=text name="title" value="' . ($args->{title} || '')  . '" ></span>
		<span class=displayspan style="width: 5%;"><input class="formMinDiv2" type=text name="style_top" value="' . ($args->{style_top} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input class="formMinDiv2" type=text name="style_left" value="' . ($args->{style_left} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input class="formMinDiv2" type=text name="style_width" value="' . ($args->{style_width} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input class="formMinDiv2" type=text name="style_height" value="' . ($args->{style_height} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan style="width: 2%;">&nbsp;</span>
		<span class=displayspan style="width: 6%;"><input type="submit" style="color:black;" class="btn-vert" value="Ajouter"></span>
		<span class=displayspan style="width: 1%;">&nbsp;</span>
		<input type=hidden name="formulaire" value="'.($args->{formulaire}|| '').'" >
		</form>
		<div class="spacer"></div>
		</li></ul><hr style="margin: 1em 0 1em 0;" class="mainPageTutoriel">' ;

	return $html_list;
}

#/*—————————————— Page Formulaire modification options ——————————————*/
sub form_options_formulaires {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
    my ($form_html, $item_num, $html_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    my $line = "1"; 
    
    #/************ ACTION DEBUT *************/
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '2' ) {
		
		$args->{formulaire} ||= undef;
		$args->{code} ||= undef;
		$args->{description} = defined($args->{description}) ? ($args->{description} =~ s/^\s+|\s+$//gr eq '' ? undef : Base::Site::util::formatter_montant_et_libelle(undef, \$args->{description})) : undef;
		$args->{title} ||= undef;
		$args->{style_top} ||= undef;
		$args->{style_left} ||= undef;
		$args->{style_width} ||= undef;
		$args->{style_height} ||= undef;
		$args->{exercice} ||= undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{formulaire}], [27, $args->{code}] );
		if ($erreur) {
		$html_list .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'INSERT INTO tblbilan_code (id_client, formulaire, code, description, title, style_top, style_left, style_width, style_height, exercice) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code}, $args->{description}, $args->{title}, $args->{style_top}, $args->{style_left}, $args->{style_width}, $args->{style_height}, $args->{exercice} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$html_list .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$html_list .= Base::Site::util::generate_error_message('Le code '.($args->{code} || '').' du formulaire '.($args->{formulaire} || '').' existe déjà') ;
				} elsif ( $@ =~ /is not present/ ) {$html_list .= Base::Site::util::generate_error_message('Le formulaire '.($args->{formulaire} || '').' n\'existe pas') ;
				} else {$html_list .= Base::Site::util::generate_error_message($@);}
			} else {
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout du code '.($args->{code} || '').' au formulaire '.($args->{formulaire} || '').'');
				#Redirection
				$args->{restart} = 'bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Supprimer' 					  #
	#######################################################################
	if ( defined $args->{options} && $args->{options} eq '5' ) {
		$sql = 'DELETE FROM tblbilan_code WHERE id_client = ? and formulaire = ? and code = ?' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code} ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			$html_list .= Base::Site::util::generate_error_message('' . $@ . '') ;
		} else {
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => Suppression du code ' . $args->{code}.' dans le formulaire ' . $args->{formulaire}.' ');
			#Redirection
			$args->{restart} = 'bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}

	}
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'modifier' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '3' ) {
		
		$args->{formulaire} ||= undef;
		$args->{code} ||= undef;
		$args->{newcode} ||= undef;
		$args->{title} ||= undef;
		$args->{style_top} ||= undef;
		$args->{style_left} ||= undef;
		$args->{style_width} ||= undef;
		$args->{style_height} ||= undef;
		$args->{exercice} ||= undef;
		$args->{description} = defined($args->{description}) ? ($args->{description} =~ s/^\s+|\s+$//gr eq '' ? undef : Base::Site::util::formatter_montant_et_libelle(undef, \$args->{description})) : undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{formulaire}], [26, $args->{code}] );
		if ($erreur) {
		$html_list .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'UPDATE tblbilan_code set formulaire = ?, code = ?, description= ?, title= ?, style_top= ?, style_left= ?, style_width= ?, style_height= ?, exercice = ?
			WHERE id_client = ? and formulaire = ? and code = ?' ;
			@bind_array = ( $args->{formulaire}, $args->{newcode}, $args->{description}, $args->{title}, $args->{style_top}, $args->{style_left}, $args->{style_width}, $args->{style_height}, $args->{exercice}, $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$html_list .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$html_list .= Base::Site::util::generate_error_message('Le code '.($args->{code} || '').' du formulaire '.($args->{formulaire} || '').' existe déjà') ;
				} else {$html_list .= Base::Site::util::generate_error_message($@);}
			} else {
			#Redirection
			$args->{restart} = 'bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
    
    #/************ ACTION FIN *************/
    
	$sql = 'SELECT * FROM tblbilan_code WHERE id_client = ? and formulaire = ? ORDER BY style_top, style_left, code, description, code';
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{formulaire}) };
	
	#ligne des en-têtes Frais en cours
    $html_list .= '<ul class="wrapper100">' ;
	
	for ( @$result_set ) {
		
		my $var_link = 'les comptes';
		my $var_options = 10;
		if (defined $_->{link} && $_->{link} eq "Formule") {
			$var_link = 'la formule';
			$var_options = 11;
		}
		
		if (defined $args->{options} && $args->{options} eq 10 && defined $args->{code} && $args->{code} eq $_->{code} ) {
			
		}	
		
		my $reqline = ($line ++);	
		
		# Sélection Exercice
		my $select_exercice = '<select oninput="findModif(this,'.$reqline.');" class="formMinDiv2" name="exercice" id="exercice_'.$reqline.'">
		<option value="compteN" '.((defined $_->{exercice} && $_->{exercice} eq "compteN")  ? ' selected' : '').' >Compte N</option>
		<option value="compteN1" '.((defined $_->{exercice} && $_->{exercice} eq "compteN1") ? ' selected' : '').' >Compte N-1</option>
		<option value="formuleN" '.((defined $_->{exercice} && $_->{exercice} eq "formuleN")  ? ' selected' : '').' >Formule N</option>
		<option value="formuleN1" '.((defined $_->{exercice} && $_->{exercice} eq "formuleN1") ? ' selected' : '').' >Formule N-1</option>
		<option value="divers" '.((defined $_->{exercice} && $_->{exercice} eq "divers") ? ' selected' : '').' >Divers</option>
		</select>';
			
		my $delete_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=4&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}) ;
		my $dupliquer_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}) ;
		my $valid_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=3&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}) ;
		my $edit_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options='.$var_options.'&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}).'&code=' . $_->{code} ;
		my $edit_link = '<a href="'.$edit_href.'"><span class="displayspan" style="width: 2%; text-align: center;"><img id="documents_'.$reqline.'" class="line_icon_visible" height="14" width="14" title="Modifier '.$var_link.'" src="/Compta/style/icons/modifier.png" alt="modifier"></span></a>';
		my $duplicate_link = '<span class="displayspan" style="width: 2%; text-align: center;"><input id="dup_'.$reqline.'" class=line_icon_visible type="image" formaction="' . $dupliquer_href . '" title="Dupliquer la ligne" src="/Compta/style/icons/duplicate.png" type="submit" height="14" width="14" alt="dupliquer"></span>';
		my $delete_link = '<span class="displayspan" style="width: 2%; text-align: center;"><input id="del_'.$reqline.'" class=line_icon_visible type="image" formaction="' . $delete_href . '" title="Supprimer la ligne" src="/Compta/style/icons/delete.png" type="supprimer" height="14" width="14" alt="supprimer"></span>';
		
						
		$html_list .= '
		<li id="line_'.($_->{code} || $reqline).'" class="style1">
		<div class="spacer"></div> 
		<form method=POST>
		<span class=displayspan style="width: 1%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="newcode" value="' . ($_->{code}  || '') . '" ></span>
		<span class=displayspan style="width: 30%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="description" value="' . ($_->{description} || '')  . '" ></span>
		<span class=displayspan style="width: 8%;">'.$select_exercice.'</span>
		<span class=displayspan style="width: 24%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="title" value="' . ($_->{title} || '')  . '" ></span>
		<span class=displayspan style="width: 5%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="style_top" value="' . ($_->{style_top} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="style_left" value="' . ($_->{style_left} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="style_width" value="' . ($_->{style_width} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 5%;"><input oninput="findModif(this,'.$reqline.');" class="formMinDiv2" type=text name="style_height" value="' . ($_->{style_height} || '')  . '" pattern="[0-9]*"></span>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		' .$edit_link. '
		<span class="displayspan" style="width: 2%; text-align: center;"><input id="valid_'.$reqline.'" class=line_icon_hidden type="image" formaction="' . $valid_href . '" title="Valider les modifications" src="/Compta/style/icons/valider.png" type="submit" height="14" width="14" alt="valider"></span>
		' . $delete_link . '
		' . $duplicate_link . '
		<span class=displayspan style="width: 1%;">&nbsp;</span>
		<input type="hidden" name="code" value="' . ($_->{code}  || '') . '">
		<input type="hidden" name="formulaire" value="' . ($_->{formulaire}  || '') . '">
		</form>
		<div class="spacer"></div>
		</li>' ;	
	
	}

	$html_list .= '</ul>';

	return $html_list;
}

#/*—————————————— Page Formulaire nouveau compte ——————————————*/
sub New_comptes {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
    my ($form_html, $item_num, $html_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    
    if ( defined $args->{options} && $args->{options} eq '10' ) {
		
		$args->{description} = undef;
		$args->{exercice} = undef;
		$args->{title}  = undef;
		$args->{style_top}  = undef;
		$args->{style_left}  = undef;
		$args->{style_width}  = undef;
		$args->{style_height}  = undef;
		$args->{link}  = undef;
		
	}
    
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'Ajouter' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '12' ) {
		
		$args->{formulaire} ||= undef;
		$args->{code} ||= undef;
		$args->{compte_mini} ||= undef;
		$args->{compte_maxi} ||= undef;
		$args->{compte_journal} ||= undef;
		$args->{solde_type} ||= undef;
		$args->{si_debit} ||= undef;
		$args->{si_credit} ||= undef;
		$args->{si_soustraire} ||= undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{formulaire}], [27, $args->{code}] );
		if ($erreur) {
		$html_list .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'INSERT INTO tblbilan_detail (id_client, formulaire, code, compte_mini, compte_maxi, compte_journal, solde_type, si_debit, si_credit, si_soustraire) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)' ;
			@bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code}, $args->{compte_mini}, $args->{compte_maxi}, $args->{compte_journal}, $args->{solde_type}, $args->{si_debit}, $args->{si_credit}, $args->{si_soustraire} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$html_list .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$html_list .= Base::Site::util::generate_error_message('La ligne avec le N°compte mini '.($args->{compte_mini} || '').' et N°compte maxi '.($args->{compte_maxi} || '').' existe déjà') ;
				} else {$html_list .= Base::Site::util::generate_error_message($@);}
			} else {
				#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'ndf.pm => Ajout du code '.($args->{code} || '').' au formulaire '.($args->{formulaire} || '').'');
				#Redirection
				$args->{restart} = 'bilan?options=10&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'&code='.$args->{code}.'';
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'demande supprimer'			  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '14' ) {
		$args->{formulaire} ||= undef;
		$args->{code} ||= undef;

		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=10&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}).'&code=' . $args->{code};
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=15&formulaire=' . URI::Escape::uri_escape_utf8($args->{formulaire}).'&code=' . $args->{code}.'&compte_mini=' . ($args->{old_mini}||'').'&compte_maxi=' . ($args->{old_maxi}||'');
		$html_list .= Base::Site::util::generate_error_message('Voulez-vous supprimer le compte ' . ($args->{old_mini}||'').' dans le formulaire ' . ($args->{formulaire}||'').' ?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
		
		$args->{compte_mini} = undef;
		$args->{compte_maxi} = undef;
		$args->{compte_journal} = undef;
		$args->{solde_type} = undef;
		$args->{si_debit} = undef;
		$args->{si_credit} = undef;
		$args->{si_soustraire} = undef;
	} 
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'valider Supprimer' 			  #
	#######################################################################
	if ( defined $args->{options} && $args->{options} eq '15' ) {
		$sql = 'DELETE FROM tblbilan_detail WHERE id_client = ? and formulaire = ? and code = ? and compte_mini = ? and compte_maxi = ?' ;
		@bind_array = ( $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code}, $args->{compte_mini}, $args->{compte_maxi} ) ;
		eval { $dbh->do( $sql, undef, @bind_array ) } ;

		if ( $@ ) {
			$html_list .= Base::Site::util::generate_error_message('' . $@ . '') ;
		} else {
			#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'bilan.pm => Suppression du code ' . $args->{code}.' dans le formulaire ' . $args->{formulaire}.' ');
			#Redirection
			$args->{restart} = 'bilan?options=10&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'&code='.$args->{code}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
		}

	}
	
	my $tblbilan_code = Base::Site::bdd::get_tblbilan_code($dbh, $r, $args);

	#ligne des en-têtes Frais en cours
    $html_list .= '
    	<div class="Titre10 centrer"><span class=check2>
    	<a class=hideLink title="Fermer la fenêtre" href="bilan?options&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'"><span>[X]</a></span>
		<a class=hideLink title="Afficher le code précédent" href="bilan?options=10&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'&code='.($tblbilan_code->[0]->{previous_code} || ''.$args->{code}.'').'"><span>[&#9664;]</a></span> Gestion des comptes pour le code ' . $args->{code}.' <a class=hideLink title="Afficher le code suivant" href="bilan?options=10&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'&code='.($tblbilan_code->[0]->{next_code} || ''.$args->{code}.'').'"><span>[&#9654;]</a></span>
		</div>
	' ;

	$html_list .= '
	<ul class="wrapper100">
		<li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 7%; text-align: center;">N° mini</span>
		<span class=headerspan style="width: 7%; text-align: center;">N° maxi</span>
		<span class=headerspan style="width: 9%; text-align: center;">Journal</span>
		<span class=headerspan style="width: 12%; text-align: center;">Solde Débit-Crédit</span>
		<span class=headerspan style="width: 12%; text-align: center;">Solde Crédit-Débit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Montant Débit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Montant Crédit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Si solde Déb.</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Si solde Créd.</span>
		<span class=headerspan style="width: 8%; text-align: center;">Soustraire</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 6%;">&nbsp;</span>
		<div class=spacer></div></li>
		
		<li class="style1">   
		<div class="spacer"></div> 
		<form method=POST action=/' . $r->pnotes('session')->{racine} . '/bilan?options=12&formulaire='.(URI::Escape::uri_escape_utf8($args->{formulaire}) || '').'&code='.($args->{code}|| '').'>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;"><input class="formMinDiv2" placeholder="N°compte mini" type=text name="compte_mini" value="' . ($args->{compte_mini} || '')  . '" required></span>
		<span class=displayspan style="width: 7%;"><input class="formMinDiv2" placeholder="N°compte maxi" type=text name="compte_maxi" value="' . ($args->{compte_maxi} || '')  . '" required></span>
		<span class=displayspan style="width: 9%;"><input class="formMinDiv2" placeholder="Journal" type=text name="compte_journal" value="' . ($args->{compte_journal} || '')  . '"></span>
		<span class="displayspan" style="width: 12%; text-align: center;"><input type="radio" name="solde_type" title="Solde Débit - Crédit" value="solde_debit" checked></span>
		<span class="displayspan" style="width: 12%; text-align: center;"><input type="radio" name="solde_type" title="Solde Crédit - Débit" value="solde_credit"></span>
		<span class="displayspan" style="width: 9.5%; text-align: center;"><input type="radio" name="solde_type" title="Montant débit" value="montant_debit"></span>
		<span class="displayspan" style="width: 9.5%; text-align: center;"><input type="radio" name="solde_type" title="Montant crédit" value="montant_credit"></span>
		<span class=displayspan style="width: 9.5%; text-align: center; "><input type="checkbox" name="si_debit" title="Ne prendre en compte que si le solde est débiteur" value="on" ><input type=hidden name="si_debit" value="off" ></span>
		<span class=displayspan style="width: 9.5%; text-align: center; "><input type="checkbox" name="si_credit" title="Ne prendre en compte que si le solde est créditeur" value="on" ><input type=hidden name="si_credit" value="off" ></span>
		<span class=displayspan style="width: 8%; text-align: center; "><input type="checkbox" name="si_soustraire" title="Soustraire la valeur de ce compte" value="on" ><input type=hidden name="si_soustraire" value="off" ></span>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan style="width: 6%;"><input type="submit" style="color:black;" class="btn-vert" value="Ajouter"></span>
		</form>
		<div class="spacer"></div>
		</li></ul>' ;

	return $html_list;
}

#/*—————————————— Page Formulaire liste comptes ——————————————*/
sub Display_comptes {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
	my ( $sql, @bind_array, $content ) ;
    my ($form_html, $item_num, $html_list, $numero_piece) = ('','1', '', '');
    my $reqid = Base::Site::util::generate_reqline();
    my $line = "1"; 
    
    #/************ ACTION DEBUT *************/
    
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton 'modifier' 					  #
	#######################################################################
    if ( defined $args->{options} && $args->{options} eq '13' ) {
		
		$args->{formulaire} ||= undef;
		$args->{code} ||= undef;
		$args->{compte_mini} ||= undef;
		$args->{compte_maxi} ||= undef;
		$args->{compte_journal} ||= undef;
		$args->{solde_type} ||= undef;
		$args->{si_debit} ||= undef;
		$args->{si_credit} ||= undef;
		$args->{si_soustraire} ||= undef;
		
		my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args, [25, $args->{formulaire}], [26, $args->{code}] );
		if ($erreur) {
		$html_list .= Base::Site::util::generate_error_message($erreur);
		} else {
		
			#ajouter un nouveau formulaire
			$sql = 'UPDATE tblbilan_detail set formulaire = ?, code = ?, compte_mini= ?, compte_maxi= ?, compte_journal= ?, solde_type= ?, si_debit= ?, si_credit = ?, si_soustraire = ?
			WHERE id_client = ? and formulaire = ? and code = ? and compte_mini = ? and compte_maxi = ?' ;
			@bind_array = ( $args->{formulaire}, $args->{code}, $args->{compte_mini}, $args->{compte_maxi}, $args->{compte_journal}, $args->{solde_type}, $args->{si_debit}, $args->{si_credit}, $args->{si_soustraire}, $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code}, $args->{old_mini}, $args->{old_maxi} ) ;
			eval {$dbh->do( $sql, undef, @bind_array ) } ;
			
			if ( $@ ) {
				if ( $@ =~ /NOT NULL/ ) {$html_list .= Base::Site::util::generate_error_message('Il faut obligatoirement un libellé') ;
				} elsif ( $@ =~ /existe|already exists/ ) {$html_list .= Base::Site::util::generate_error_message('Le code '.($args->{code} || '').' du formulaire '.($args->{formulaire} || '').' existe déjà') ;
				} else {$html_list .= Base::Site::util::generate_error_message($@);}
			} else {
			#Redirection
			$args->{restart} = 'bilan?options=10&formulaire='.URI::Escape::uri_escape_utf8($args->{formulaire}).'&code='.$args->{code}.'';
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé
			}
		}
    }
    
    #/************ ACTION FIN *************/
    
	$sql = 'SELECT * FROM tblbilan_detail WHERE id_client = ? and formulaire = ? and code= ? ORDER BY compte_mini';
	my $result_set = eval { $dbh->selectall_arrayref($sql, { Slice => {} }, $r->pnotes('session')->{id_client}, $args->{formulaire}, $args->{code}) };
	
	my $tblbilan_code = Base::Site::bdd::get_tblbilan_code($dbh, $r, $args);
	
	#ligne des en-têtes
    $html_list .= '
    <ul class="wrapper100">
    <li class="lineflex1">
	<h4 style="color: black; text-decoration: none;">Liste des comptes pour le code ' . $args->{code}.' =>  '.($tblbilan_code->[0]->{title} || '').'</h4>
	</li>
	<li class="lineflex1">   
		<div class=spacer></div>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 7%; text-align: center;">N° mini</span>
		<span class=headerspan style="width: 7%; text-align: center;">N° maxi</span>
		<span class=headerspan style="width: 9%; text-align: center;">Journal</span>
		<span class=headerspan style="width: 12%; text-align: center;">Solde Débit-Crédit</span>
		<span class=headerspan style="width: 12%; text-align: center;">Solde Crédit-Débit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Montant Débit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Montant Crédit</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Si solde Déb.</span>
		<span class=headerspan style="width: 9.5%; text-align: center;">Si solde Créd.</span>
		<span class=headerspan style="width: 8%; text-align: center;">Soustraire</span>
		<span class=headerspan style="width: 0.5%;">&nbsp;</span>
		<span class=headerspan style="width: 6%;">&nbsp;</span>
		<div class=spacer></div></li>
	' ;
	
	for ( @$result_set ) {

		my $reqline = ($line ++);	
		
		my $delete_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=14&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}).'&code=' . $_->{code}.'';
		my $valid_href = '/'.$r->pnotes('session')->{racine}.'/bilan?options=13&formulaire=' . URI::Escape::uri_escape_utf8($_->{formulaire}).'&code=' . $_->{code}.'';
		my $delete_link = '<span class="displayspan" style="width: 2%; text-align: center;"><input type="image" formaction="' . $delete_href . '" title="Supprimer" src="/Compta/style/icons/delete.png" type="submit" style="margin: 2px; border: 0;" height="16" width="16" alt="supprimer"></span>' ;

		$html_list .= '
		<li class="style1">
		<div class="spacer"></div> 
		<form method=POST>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class=displayspan style="width: 7%;"><input class="formMinDiv2" type=text name="compte_mini" value="' . ($_->{compte_mini} || '')  . '" ></span>
		<span class=displayspan style="width: 7%;"><input class="formMinDiv2" type=text name="compte_maxi" value="' . ($_->{compte_maxi} || '')  . '" ></span>
		<span class=displayspan style="width: 9%;"><input class="formMinDiv2" type=text name="compte_journal" value="' . ($_->{compte_journal} || '')  . '" ></span>
		<span class="displayspan" style="width: 12%; text-align: center;"><input type="radio" name="solde_type" title="Solde Débit - Crédit" value="solde_debit" ' . (defined $_->{solde_type} && $_->{solde_type} eq 'solde_debit' ? ' checked' : '') . '></span>
		<span class="displayspan" style="width: 12%; text-align: center;"><input type="radio" name="solde_type" title="Solde Crédit - Débit" value="solde_credit" ' . (defined $_->{solde_type} && $_->{solde_type} eq 'solde_credit' ? ' checked' : '') . '></span>
		<span class="displayspan" style="width: 9.5%; text-align: center;"><input type="radio" name="solde_type" title="Montant débit" value="montant_debit" ' . (defined $_->{solde_type} && $_->{solde_type} eq 'montant_debit' ? ' checked' : '') . '></span>
		<span class="displayspan" style="width: 9.5%; text-align: center;"><input type="radio" name="solde_type" title="Montant crédit" value="montant_credit" ' . (defined $_->{solde_type} && $_->{solde_type} eq 'montant_credit' ? ' checked' : '') . '></span>
		<span class=displayspan style="width: 9.5%; text-align: center; "><input type="checkbox" name="si_debit" title="Ne prendre en compte que si le solde est débiteur" value="on" ' . (defined $_->{si_debit} && $_->{si_debit} eq 't' ? ' checked' : '') . '><input type=hidden name="si_debit" value="off" ></span>
		<span class=displayspan style="width: 9.5%; text-align: center; "><input type="checkbox" name="si_credit" title="Ne prendre en compte que si le solde est créditeur" value="on" ' . (defined $_->{si_credit} && $_->{si_credit} eq 't' ? ' checked' : '') . '><input type=hidden name="si_credit" value="off" ></span>
		<span class=displayspan style="width: 8%; text-align: center; "><input type="checkbox" name="si_soustraire" title="Soustraire la valeur de ce compte" value="on" ' . (defined $_->{si_soustraire} && $_->{si_soustraire} eq 't' ? ' checked' : '') . '><input type=hidden name="si_soustraire" value="off" ></span>
		<span class=displayspan style="width: 0.5%;">&nbsp;</span>
		<span class="displayspan" style="width: 2%; text-align: center;"><input id="valider_'.$reqline.'" type="image" formaction="' . $valid_href . '" title="Valider" src="/Compta/style/icons/valider.png" type="submit" height="16" width="16" alt="valider"></span>
		' . $delete_link . '
		<span class=displayspan style="width: 2%;">&nbsp;</span>
		<input type="hidden" name="old_mini" value="'.$_->{compte_mini}.'">
		<input type="hidden" name="old_maxi" value="'.$_->{compte_maxi}.'">
		</form>
		<div class="spacer"></div>
		</li>' ;	
	}
	
	$html_list .= '</ul>';

	return $html_list;
}

sub display_menu_formulaire {

    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my $tblbilan = Base::Site::bdd::get_tblbilan($dbh, $r);
    my $content = '';
    my $tags = '';
    
	unless ( defined $args->{options} || defined $args->{analyses} || defined $args->{nom}) {
	    $args->{nom} = 'Bilan' ;
    }
  
	#lien d'analyses de datas comptables
	my $analyses_class = ( (defined $args->{analyses} ) ? 'linavselect' : 'linav' );
	my $analyses_link = '<li><a class=' . $analyses_class . ' href="/'.$r->pnotes('session')->{racine}.'/bilan?analyses">Analyses</a></li>' ;
	
	my $print_link ='<li><a class="linav" href="#" onClick="window.print();return false" >Imprimer</a></li>' ;
	my $options_link = '<li><a class=' . ( (defined $args->{options} ) ? 'linavselect' : 'linav' ) . ' href="/'.$r->pnotes('session')->{racine}.'/bilan?options" >Options</a></li>' ;

	for (@{$tblbilan}) {
			if (defined $_->{bilan_form} && $_->{bilan_form} ne '' && $_->{bilan_disp} eq 't') {
				my $tags_nom = $_->{bilan_form};
				my $tags_href = '/' . $r->pnotes('session')->{racine} . '/bilan?nom=' . URI::Escape::uri_escape_utf8($_->{bilan_form});
				my $tags_class = 'linav';
				if ( defined $args->{nom} && $args->{nom} eq $_->{bilan_form}) {
				$tags_class = "linavselect";
				}
			
				$tags .= '<li><a class="'.$tags_class.'" href="' . $tags_href . '" >' . $tags_nom . '</a></li>';
			}
	}
    
    $content .= '<div class="menu"><ul class="main-nav2">' . $tags . $analyses_link . $print_link . $options_link .'</ul></div>';
    
    return $content ;

} #sub display_menu_formulaire 

1 ;
