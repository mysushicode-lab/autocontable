package Base::Site::util;
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

# Ce module regroupe des fonctions utilitaires et des formulaires partagés,
# destinés à être utilisés dans diverses parties de l'application.
use strict;  # Utilisation stricte des variables
use warnings;  # Activation des avertissements
use utf8;              # Encodage UTF-8 pour le script
use Apache2::Const -compile => qw( OK REDIRECT ) ; # Importation de constantes Apache
use Time::Piece;       # Manipulation de dates et heures
use URI::Escape;       # Encodage et décodage d'URLs
use MIME::Base64;
use HTML::Entities;
use Encode;

my %NUMBER_NAMES = (
    0    => 'zéro',
    1    => 'un',
    2    => 'deux',
    3    => 'trois',
    4    => 'quatre',
    5    => 'cinq',
    6    => 'six',
    7    => 'sept',
    8    => 'huit',
    9    => 'neuf',
    10   => 'dix',
    11   => 'onze',
    12   => 'douze',
    13   => 'treize',
    14   => 'quatorze',
    15   => 'quinze',
    16   => 'seize',
    17   => 'dix-sept',
    18   => 'dix-huit',
    19   => 'dix-neuf',
    20   => 'vingt',
    30   => 'trente',
    40   => 'quarante',
    50   => 'cinquante',
    60   => 'soixante',
    70   => 'soixante',
    80   => 'quatre-vingt',
    90   => 'quatre-vingt',
    100  => 'cent',
    1e3  => 'mille',
    1e6  => 'million',
    1e9  => 'milliard',
    1e12 => 'billion',        # un million de millions
    1e18 => 'trillion',       # un million de billions
    1e24 => 'quatrillion',    # un million de trillions
    1e30 => 'quintillion',    # un million de quatrillions
    1e36 => 'sextillion',     # un million de quintillions,
                              # the sextillion is the biggest legal unit
);

my %ORDINALS = (
    1 => 'premier',
    5 => 'cinqu',
    9 => 'neuv',
);

######################################################################   
# Utilitaires														 #
######################################################################  

# Fonction pour le déchiffrement XOR
# Cette fonction déchiffre une chaîne de caractères encodée en utilisant une clé XOR.
# Elle prend le texte encodé ($text) et la clé de déchiffrement ($key) en entrée.
# Elle retourne le texte déchiffré.
# Utilisation :
#   my $script_value = ...;   # Script encodé
#   my $script_encode = Base::Site::util::encode_xor_and_base64($script_value, "your_secret_key"); # Encryptage XOR + base64
sub encode_xor_and_base64 {
    my ($text, $key) = @_;
    my $encryptedText = "";
    for (my $i = 0; $i < length($text); $i++) {
        $encryptedText .= chr(ord(substr($text, $i, 1)) ^ ord(substr($key, $i % length($key), 1)));
    }
    
    my $base64Text = encode_base64($encryptedText);
    
    return $base64Text;
}

#   my $script_value = ...;   # Script encodé
#   my $script_decode = Base::Site::util::encode_xor_and_base64($script_value, "your_secret_key"); # Décryptage XOR + base64
sub decode_xor_and_base64 {
    my ($base64_text, $key) = @_;
    
    my $encryptedText = decode_base64($base64_text);
    
    my $decryptedText = "";
    for (my $i = 0; $i < length($encryptedText); $i++) {
        $decryptedText .= chr(ord(substr($encryptedText, $i, 1)) ^ ord(substr($key, $i % length($key), 1)));
    }
    
    return $decryptedText;
}

sub decryptTextArea {
    my ($hex_encrypted_text, $key) = @_;

    # Convertir le texte hexadécimal en texte lisible
    my $encrypted_text = hexToString($hex_encrypted_text);

    # Décryptage XOR
    my $decrypted_text = decryptXOR($encrypted_text, $key);
    
    # Utilisation de $decrypted_text comme nécessaire
    return $decrypted_text;
}

sub decryptXOR {
    my ($text, $key) = @_;
    my $decrypted_text = "";
    my $key_length = length($key);
    for (my $i = 0; $i < length($text); $i++) {
        $decrypted_text .= chr(ord(substr($text, $i, 1)) ^ ord(substr($key, $i % $key_length, 1)));
    }
    return $decrypted_text;
}

sub hexToString {
    my ($hex) = @_;
    my $string = '';
    for (my $i = 0; $i < length($hex) - 1; $i += 2) {
        $string .= chr(hex(substr($hex, $i, 2)));
    }
    return $string;
}


#Base::Site::util::affichage_montant($args->{immo_loyer});
sub affichage_montant {
    my ($montant) = @_;

    # Vérifier si $montant est défini
    unless (defined $montant) {
        return "0.00";
    }
    
    #$montant =~ s/\s//g;

    # Utiliser sprintf pour formater le montant avec deux décimales
    my $montant_formate = sprintf("%.2f", $montant);
    
    # Ajouter des espaces pour séparer les milliers
    $montant_formate =~ s/\B(?=(...)*$)/ /g;

    return $montant_formate;
}

#Base::Site::util::affichage_montant_V2($args->{immo_loyer});
sub affichage_montant_V2 {
    my ($montant) = @_;

    # Vérifier si $montant est défini
    unless (defined $montant) {
        return "0.00";
    }
    
	$montant =~ s/\s//g;

    # Utiliser sprintf pour formater le montant avec deux décimales
    my $montant_formate = sprintf("%.2f", $montant);
    
    $montant_formate =~ tr/./,/;
    
    # Ajouter des espaces pour séparer les milliers
    $montant_formate =~ s/\B(?=(...)*$)/ /g;

    return $montant_formate;
}

#Base::Site::util::formatter_montant(\$montant);
sub formatter_montant {
    for my $montant_ref (@_) {
        if (defined $montant_ref && ref($montant_ref) eq 'SCALAR') {
            my $montant = $$montant_ref;
            $montant ||= '0.00';
            $montant =~ s/,/./;
            $montant =~ s/\s//g;
            $$montant_ref = $montant;
        }
    }
}

#Base::Site::util::formatter_libelle(\$montant);
sub formatter_libelle {
    for my $libelle_ref (@_) {
        if (defined $libelle_ref && ref($libelle_ref) eq 'SCALAR') {
            my $libelle = $$libelle_ref;
            if (defined $libelle) {
                $libelle =~ s/^\s+|\s+$//g;
                $libelle =~ s/\s{2,}/ /g;
                $$libelle_ref = $libelle;
            }
        }
    }
}






# Cette fonction prend en entrée un hashref ($args) contenant les clés 'montant' et 'libelle'.
# Elle formate le montant et le libellé selon les spécifications suivantes :
# 1. Si 'montant' est nul ou non défini, le remplace par '0.00'.
# 2. Remplace la virgule par le point dans 'montant'.
# 3. Supprime les espaces de présentation dans 'montant'.
# 4. Supprime les espaces de début et de fin de ligne dans 'libelle'.
# Cette fonction formate le montant et le libellé selon des spécifications définies.
#Base::Site::util::formatter_montant_et_libelle(\$args->{montant}, \$args->{libelle});
#Base::Site::util::formatter_montant_et_libelle(undef, \$libelle);
#Base::Site::util::formatter_montant_et_libelle(\$args->{montant}, undef);
sub formatter_montant_et_libelle {
    my ($montant_ref, $libelle_ref) = @_;

    if (defined $montant_ref) {
        # Déreference l'argument pour travailler directement avec la variable
        my $montant = $$montant_ref;
        # Mise en forme du montant pour enregistrement en bdd
        # Ne pas laisser des montants nulls : mettre un zéro
        $montant ||= '0.00';
        # Remplacer la virgule par le point dans les montants soumis
        $montant =~ s/,/./ ;
        # Enlever les espaces de présentation
        $montant =~ s/\s//g ;
        # Réaffecte la valeur formatée à la référence originale
        $$montant_ref = $montant;
    }

    if (defined $libelle_ref) {
        # Déreference l'argument pour travailler directement avec la variable
        my $libelle = $$libelle_ref;
        # Supprime les espaces de début et de fin de ligne
        $libelle =~ s/^\s+|\s+$//g;
        # Supprime les espaces consécutifs supérieurs à 1 dans le libellé
        $libelle =~ s/\s{2,}/ /g;
        # Réaffecte la valeur formatée à la référence originale
        $$libelle_ref = $libelle;
    }
}

#use Base::Site::util;
#$args->{restart} = 'docs?docscategorie=' . $doc_categorie;
#Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
#return Apache2::Const::OK;  # Indique que le traitement est terminé
sub restart {
	my ( $r, $args ) = @_ ;
	my $location = '/'.$r->pnotes('session')->{racine}.'/'.($args->{restart} || '').'' ;
	$r->headers_out->set(Location => $location) ;
	$r->status(Apache2::Const::REDIRECT) ;
	return Apache2::Const::REDIRECT ;  
} #sub sub_restart

# Générez un identifiant unique aléatoire
# my $reqid = Base::Site::util::generate_reqline();
sub generate_reqline {
    my $reqline = int(rand(10000));  
    return $reqline;
}

# Générer un nouveau token_id unique
sub generate_unique_token_id {
    my ($r, $dbh) = @_;
    my $token_id;
    do {
        $token_id = join "", map +(0..9,"a".."z","A".."Z")[rand(10+26*2)], 1..32;
    } while (is_token_id_used($r, $dbh, $token_id));
    return $token_id;
}

# Fonction pour vérifier si un token_id est déjà utilisé dans la base de données
sub is_token_id_used {
    my ($r, $dbh, $token_id) = @_;
    my $sql = 'SELECT 1 FROM tbljournal_staging WHERE _token_id = ? AND id_client = ? AND fiscal_year = ?';
    my $count = $dbh->selectrow_array($sql, undef, $token_id, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    return $count ? 1 : 0;
}

# Fonction pour construire l'URL d'Adminer avec le mot de passe sécurisé
#Base::Site::util::build_adminer_url();
sub build_adminer_url {
	my ( $r ) = @_ ;
    
    # Obtenez l'hôte du serveur à partir de l'en-tête Host
    my $host = $r->headers_in->{'Host'};

    # Construisez l'URL d'Adminer avec l'hôte, le nom d'utilisateur et le mot de passe sécurisé
    my $adminer_url = "http://$host/Compta/adminer.php?pgsql=localhost&username=compta&db=comptalibre&ns=public&password";

    return $adminer_url;

}

######################################################################   
# Générer Formulaire select	: simple								 #
######################################################################  
#my $typecompta = Base::Site::util::generate_simple_select('typecompta', 'typecompta', 'login-text', [['engagement', 'Comptabilité d\'engagement'], ['tresorerie', 'Comptabilité de trésorerie']], undef, undef, '');
sub generate_simple_select {
    my ($name, $idname, $class, $options, $selected_arg, $selected_societe, $joker, $selected_defaut) = @_;
	
	my $joker_attr = defined $joker && $joker ne '' ? qq{$joker} : '';
    my $select_html = qq{<select class="$class" name="$name" id="$idname" $joker_attr>};

    for my $option (@$options) {
        my ($value, $label) = ref $option eq 'ARRAY' ? @$option : ($option, $option);
        my $selected = ($selected_arg && $selected_arg eq $value) || ($selected_societe && $selected_societe eq $value) || (!$selected_arg && !$selected_societe && $selected_defaut && $selected_defaut eq $value) ? 'selected' : '';
        $select_html .= qq{<option $selected value="$value">$label</option>};
    }

    $select_html .= '</select>';
    return $select_html;
}
######################################################################   


# Cette fonction génère un lien HTML pour un document en fonction de son nom.
# Si le document est de type docx, odt, pdf ou jpg et existe dans la base de données,
# elle crée un lien vers la page de détails du document avec une icône de document.
# Sinon, elle renvoie un lien vers la page générale des documents avec l'étiquette "DOC".
#my $http_link_documents1 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents1}, 1);
#my $http_link_documents2 = Base::Site::util::generate_document_link($r, $args, $dbh, $_->{documents2}, 2);
sub generate_document_link {
    my ($r, $args, $dbh, $document_name, $icon) = @_;

    my $default_icon = '<span class="blockspan" style="width: 2%; display: inline-block;">&nbsp;</span>';
	
    if (defined $document_name && $document_name =~ /docx|odt|pdf|jpg/i ) {
        my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?';
        my $id_name_documents = $dbh->selectall_arrayref($sql, { Slice => {} }, $document_name);
        if ($id_name_documents->[0]->{id_name} || '') {
            my $icon = ($icon && $icon eq '2') ? 'releve-bancaire.png' : 'documents.png';
            return '<a class=nav style="margin-left: 0ch;" href="/' . $r->pnotes('session')->{racine} . '/docsentry?id_name=' . $id_name_documents->[0]->{id_name} . '"><img height="16" width="16" style="border: 0;" src="/Compta/style/icons/' . $icon . '" alt="documents" title="Ouvrir ' . $id_name_documents->[0]->{id_name} . '"></a>';
        }
    }
    return $default_icon; # Retourne la valeur par défaut si aucun résultat ou si le format du document n'est pas pris en charge
}

sub generate_document_link_2 {
    my ($r, $args, $dbh, $document_name, $icon) = @_;
	
    my $default_icon = '<input type="image" src="/Compta/style/icons/vide.png" class=image alt="vide">';

    if (defined $document_name && $document_name =~ /docx|odt|pdf|jpg/i ) {
        my $sql = 'SELECT id_name FROM tbldocuments WHERE id_name = ?';
        my $id_name_documents = $dbh->selectall_arrayref($sql, { Slice => {} }, $document_name);
        if ($id_name_documents->[0]->{id_name} || '') {
            my $icon = ($icon && $icon eq '2') ? 'releve-bancaire.png' : 'documents.png';
            my $doc_href = '/'.$r->pnotes('session')->{racine}.'/docsentry?id_name=' . $id_name_documents->[0]->{id_name} . '' ;
            return '<input type="image" src="/Compta/style/icons/' . $icon . '" class=image alt="open" formaction="' . $doc_href . '" onclick="submit()" title="Ouvrir ' . $id_name_documents->[0]->{id_name} . '">';
        }
    }
    return $default_icon; # Retourne la valeur par défaut si aucun résultat ou si le format du document n'est pas pris en charge
}

######################################################################   
# Générer Formulaire select	: avancé								 #
###################################################################### 

# Exemple pour un sélecteur de document en format HTML
#my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
#my ($selected1, $form_name1, $form_id1, $class_value1, $style1) = ('', 'doc1_'.$reqid.'', 'doc1_'.$reqid.'', 'class="formMinDiv2"', '');
#my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
#my $select_document = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, $class_value1, $style1);

# Exemple pour un sélecteur de compte en format HTML
#my $bdd_compte4 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '4');
#my $bdd_compte6 = Base::Site::bdd::get_comptes_by_classe($dbh, $r, '6');
#my ($selected2, $form_name2, $form_id2)  = ('', 'csv4_'.$reqid.'', 'csv4_'.$reqid.'');
#my $onchange2 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
#my $select_classe4 = Base::Site::util::generate_compte_selector($bdd_compte4, $reqid, $selected2, $form_name2, $form_id2, $onchange2, 'class="formMinDiv2"', '');
#my ($selected3, $form_name3, $form_id3) = ('', 'csv6_'.$reqid.'', 'csv6_'.$reqid.'');
#my $onchange3 = "onchange=\"if(this.selectedIndex == 0){document.location.href='compte?configuration'};Yellobri(this,$reqid);\"";
#my $select_classe6 = Base::Site::util::generate_compte_selector($bdd_compte6, $reqid, $selected3, $form_name3, $form_id3, $onchange3, 'class="formMinDiv2"', '');

# Modèle formulaire
sub generate_selector {
    my ($options, $selected_var, $form_name, $form_id, $default_option_label, $default_create_label, $onchange_value, $class_value, $style) = @_;

    my $content = '<select ' . ($onchange_value || '') . ' ' . ($class_value || '') . ' ' . ($style || '') . ' name="' . $form_name . '" id="' . $form_id . '">';

	if (defined $default_create_label && $default_create_label ne '' ) {
        $content .= '<option class="opt1" value="">' . $default_create_label . '</option>';
    }
    
    if (defined $default_option_label && $default_option_label ne '') {
        if (!defined $selected_var || defined $selected_var && $selected_var eq '') {
            $content .= '<option value="" selected>' . $default_option_label . '</option>';
        } else {
            $content .= '<option value="">' . $default_option_label . '</option>';
        }
    }
    
    foreach my $item (@$options) {
        my $value = $item->{value};
        my $label = $item->{label};
        my $selected = ($value eq ($selected_var || '')) ? 'selected' : '';
        $content .= '<option value="' . $value . '" ' . $selected . '>' . $label . '</option>';
    }
    
    $content .= '</select>';
    return $content;
}

# Formulaire HTML sélection de compte
sub generate_compte_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{numero_compte}, label => $_->{numero_compte} . ' - ' . $_->{libelle_compte} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un compte--', 'Créer un compte', $onchange_value, $class_value, $style);
}

# Formulaire HTML sélection de logement module immobilier
#my $info_logement = Base::Site::bdd::get_immobilier_logements($dbh, $r);
#my $selected_logement = (defined($args->{biens_ref}) && $args->{biens_ref} ne '') ? ($args->{biens_ref} ) : undef;
#my ($form_name_logement, $form_id_logement) = ('search_logement', 'search_logement_'.$reqid.'');
#my $search_logement = Base::Site::util::generate_immobilier_logement($info_logement, $reqid, $selected_logement, $form_name_logement, $form_id_logement, '', 'class="forms2_input"', 'style="width: 15%;"');
sub generate_immobilier_logement {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{biens_ref}, label => $_->{biens_ref} . ' - ' . $_->{biens_nom} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un logement--', 'Créer un logement', $onchange_value, $class_value, $style);
}

# Formulaire HTML sélection de tags module document
#my $info_tags = Base::Site::bdd::get_tags_documents($dbh, $r);
#my $selected_tags = (defined($args->{tags_nom}) && $args->{tags_nom} ne '') ? ($args->{tags_nom} ) : undef;
#my ($form_name_tags, $form_id_tags) = ('tags_nom', 'tags_nom_'.$reqid.'');
#my $search_tags = Base::Site::util::generate_tags_choix($info_tags, $reqid, $selected_tags, $form_name_tags, $form_id_tags, '', 'class="forms2_input"', 'style="width: 15%;"');
sub generate_tags_choix {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{tags_nom}, label => $_->{tags_nom} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un tag--', 'Créer un tag', $onchange_value, $class_value, $style);
}

# Formulaire HTML sélection de baux module immobilier
#my $info_baux = Base::Site::bdd::get_immobilier_baux($dbh, $r, $archive, $args);
#my $selected_baux = (defined($args->{biens_ref}) && $args->{biens_ref} ne '') ? ($args->{biens_ref} ) : undef;
#my ($form_name_baux, $form_id_baux) = ('search_logement', 'search_logement_'.$reqid.'');
#my $search_baux = Base::Site::util::generate_immobilier_baux($info_baux, $reqid, $selected_baux, $form_name_baux, $form_id_baux, '', 'class="forms2_input"', 'style="width: 15%;"');
sub generate_immobilier_baux {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{immo_contrat}, label => $_->{immo_contrat} . ' - ' . $_->{immo_libelle} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un bail--', 'Ajouter un bail', $onchange_value, $class_value, $style);
}

# Formulaire HTML sélection de modéle de mail
#my $info_modele_mail = Base::Site::bdd::get_template($dbh, $r, '', 'email_body');
#my $selected_mail = (defined($args->{modele_name}) && $args->{modele_name} ne '') ? ($args->{modele_name} ) : undef;
#my ($form_name_modele, $form_id_modele) = ('modele_name', 'modele_name_'.$reqid.'');
#my $search_modele_mail = Base::Site::util::generate_modele_mail($info_modele_mail, $reqid, $selected_mail, $form_name_modele, $form_id_modele, '', 'class="forms2_input"', 'style="width: 15%;"');
sub generate_modele_mail {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{template_name}, label => $_->{template_name} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un modèle--', "", $onchange_value, $class_value, $style);
}

#my $journaux = Base::Site::bdd::get_journaux($dbh, $r);
#my $selected_journal = (defined($args->{search_fiscal_year}) && $args->{search_fiscal_year} ne '') ? ($args->{search_fiscal_year} ) : undef;
#my $onchange_journal= "onchange=\"if(this.selectedIndex == 0){document.location.href='journal?configuration'};\"";
#my ($form_name_journal, $form_id_journal) = ('search_fiscal_year', 'search_fiscal_year_'.$reqid.'');
#my $search_journal = Base::Site::util::generate_journal_selector($journaux, $reqid, $selected_journal, $form_name_journal, $form_id_journal, $onchange_journal, 'class="forms2_input"', 'style="width: 8%;"');
# Formulaire HTML sélection de journaux
sub generate_journal_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

	my $var_data = [
        map { { value => $_->{libelle_journal}, label => $_->{libelle_journal} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un journal--', 'Créer un journal', $onchange_value, $class_value, $style);
}

#Requête et Formulaire Recherche de la liste des documents enregistrés
#my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};Yellobri(this,$reqid);\"";
#my $selected1 = (defined($args->{docs2}) && $args->{docs2} ne '') || (defined($args->{id_name}) && defined($args->{label9}) && $args->{label9} eq '1') ? ($args->{docs2} || $args->{id_name}) : undef;
#my ($form_name1, $form_id1) = ('docs2', 'docs2_'.$reqid.'');
#my $document_select1 = Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style ="width : 25%;"');
# Formulaire HTML sélection de document
sub generate_document_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

    my $var_data = [
        map { { value => $_->{id_name}, label => $_->{id_name} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner un document--', 'Ajouter un document', $onchange_value, $class_value, $style);
}

#Requête et Formulaire Recherche de la liste des catégories de documents
#my $categorie_document = Base::Site::bdd::get_categorie_document($dbh, $r);
#my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?categorie\'};\"";
#my $selected1 = (defined($args->{libelle_cat_doc}) && $args->{libelle_cat_doc} ne '') ? ($args->{libelle_cat_doc} ) : undef;
#my ($form_name1, $form_id1) = ('libelle', 'libelle_'.$reqid.'');
#my $document_select1 = Base::Site::util::generate_doc_cat_selector($categorie_document, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style ="width : 25%;"');
sub generate_doc_cat_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

    my $var_data = [
        map { { value => $_->{libelle_cat_doc}, label => $_->{libelle_cat_doc} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Sélectionner une catégorie--', 'Ajouter une catégorie', $onchange_value, $class_value, $style);
}

#Requête et Formulaire Règlements
#my $resultat_tblconfig = Base::Site::bdd::get_parametres_reglements($dbh, $r);
#my $selected3 = (defined($args->{select_achats}) && $args->{select_achats} ne '') ? ($args->{select_achats} ) : undef;
#my ($form_name3, $form_id3) = ('select_achats', 'select_achats_'.$reqid.'');
#my $onchange3 = "onchange=\"if(this.selectedIndex == 0){document.location.href='parametres?achats'};Yellobri(this,$reqid);\"";
#my $select_achats = Base::Site::util::generate_reglement_selector($resultat_tblconfig, $reqid, $selected3, $form_name3, $form_id3, $onchange3, 'class="forms2_input"', 'style="width: 15%;"');
# Formulaire HTML sélection de document
sub generate_reglement_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

    my $var_data = [
        map { { value => $_->{config_libelle}, label => $_->{config_libelle} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, '--Choix Réglement--', 'Ajouter un Réglement', $onchange_value, $class_value, $style);
}

#Requête et Formulaire all société
#my $all_societe = Base::Site::bdd::get_all_societe($dbh, $r);
#my $selected_societe = (defined($args->{societe}) && $args->{societe} ne '') ? ($args->{societe} ) : undef;
#my ($form_name_societe, $form_id_societe) = ('societe', 'societe');
#my $societe_select = Base::Site::util::generate_societe_selector($all_societe, $reqid, $selected_societe, $form_name_societe, $form_id_societe, '', 'class="forms2_input"', 'style="width: 15%;"');
sub generate_societe_selector {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

    my $var_data = [
        map { { value => $_->{id_client}, label => $_->{id_client} . ' - ' . $_->{etablissement} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, undef, undef, $onchange_value, $class_value, $style);
}

#Requête et Formulaire all username
#my $get_all_user = Base::Site::bdd::get_all_user($dbh, $r);
#my $selected_user = (defined($args->{username}) && $args->{username} ne '') ? ($args->{username} ) : undef;
#my ($form_name_user, $form_id_user) = ('username', 'username');
#my $utilisateurs_select = Base::Site::util::generate_user_selector($get_all_user, undef, $selected_user, $form_name_user, $form_id_user, '', 'class="forms2_input"', '');
sub generate_user_selector {
    my ($requete_bdd, $reqline, $selected_user, $form_name, $form_id, $onchange_value, $class_value, $style) = @_;

    my $var_data = [
        map { { value => $_->{username}, label => $_->{username}  } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_user, $form_name, $form_id, undef, undef, $onchange_value, $class_value, $style);
}

#Requête et Formulaire Fiscalyear
#$include_all_option, et si vous le définissez à 1 (vrai), l'option "Tous les exercices" sera incluse
#my $parametres_fiscal_year = Base::Site::bdd::get_parametres_fiscal_year($dbh, $r->pnotes('session')->{id_client});
#my $selected_fiscal_year = (defined($args->{search_fiscal_year}) && $args->{search_fiscal_year} ne '') ? ($args->{search_fiscal_year} ) : undef;
#my ($onchange_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year) = ('', 'search_fiscal_year', 'search_fiscal_year_'.$reqid.'');
#my $search_fiscal_year = Base::Site::util::generate_fiscal_year($parametres_fiscal_year, $reqid, $selected_fiscal_year, $form_name_fiscal_year, $form_id_fiscal_year, $onchange_fiscal_year, 'class="forms2_input"', 'style="width: 8%;"', 1);
# Formulaire HTML sélection de Fiscal Year
sub generate_fiscal_year {
    my ($requete_bdd, $reqline, $selected_var, $form_name, $form_id, $onchange_value, $class_value, $style, $include_all_option) = @_;

	my $var_data = [
        ($include_all_option ? { value => '', label => 'Tous les exercices' } : ()), # Option pour tous les exercices si $include_all_option est vrai
        map { { value => $_->{fiscal_year}, label => $_->{fiscal_year} } }
        @$requete_bdd
    ];

    return generate_selector($var_data, $selected_var, $form_name, $form_id, undef, undef, $onchange_value, $class_value, $style);
}

# Fonction pour générer un message d'erreur avec une classe de style "warning"
#$content .= Base::Site::util::generate_error_message($message);
sub generate_error_message {
    my ($message) = @_;
    return qq(<div class="warning" style="font-size: 1.17em; font-weight: bold; text-align: center;">$message</div>);
}

# Fonction pour ajouter une classe CSS de surbrillance à la ligne en erreur
sub highlight_error_line {
    my ($line_id) = @_;
    # Ajoute une classe CSS pour la surbrillance à l'élément de ligne en erreur en utilisant JavaScript
    my $script = <<SCRIPT;
<script>
    var element = document.getElementById("$line_id");
    if (element) {
        element.classList.add('highlighted-line');
    }
</script>
SCRIPT
    return $script;
}

#Fonction pour générer le débogage des variables $args et $r->args 
#if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
sub debug_args {
    my ($args, $r_args) = @_;
    my $content;

	# Titre du mode dump activé
    $content .= '<div style="border: 1px solid #ccc; padding: 10px; background-color: #f9f9f9;"><h2 style="color: #ff0000;">Mode dump activé <a class="aperso" title="Cliquer ici pour désactiver le mode dump" href="parametres?utilisateurs=0&modification_utilisateur=1&dump=2&focus=1" id="dumpLink2">#Désactiver</a></h2><hr>';
        
        # Si $args est un hachage (HASH), générer un affichage structuré
        if (defined $args && ref($args) eq 'HASH') {
            my @sorted_args = sort keys %$args;
            my $formatted_args_output .= '<h2>Contenu de $args</h2>';
            $formatted_args_output .= '<pre>';
            foreach my $key (@sorted_args) {
                $formatted_args_output .= "<strong>$key:</strong> " . (defined $args->{$key} ? $args->{$key} : 'UNDEFINED') . "\n";
            }
            $formatted_args_output .= '</pre>';
            $content .= $formatted_args_output;
        }
        else {
            # Si $args n'est pas un hachage (HASH), afficher en mode Data::Dumper
            $content .= '<hr><h2>Contenu de $args</h2>';
            $content .= '<pre>';
            $content .= Data::Dumper::Dumper($args);
            $content .= '</pre>';
        }

        # Si $r_args est un hachage (HASH), générer un affichage structuré
        if (defined $r_args && ref($r_args) eq 'HASH') {
            my @sorted_r_args = sort keys %$r_args;
            my $formatted_r_args_output .= '<hr><h2>Paramètres de la requête</h2>';
            $formatted_r_args_output .= '<pre>';
            foreach my $key (@sorted_r_args) {
                $formatted_r_args_output .= "<strong>$key:</strong> " . (defined $r_args->{$key} ? $r_args->{$key} : 'UNDEFINED') . "<br>";
            }
            $formatted_r_args_output .= '</pre>';
            $content .= $formatted_r_args_output;
        }
        else {
            # Si $r_args n'est pas un hachage (HASH), afficher en mode Data::Dumper
            $content .= '<hr><h2>Paramètres de la requête</h2>';
            $content .= '<pre>';
            $content .= Data::Dumper::Dumper($r_args);
            $content .= '</pre>';
            
        }
        
        $content .= '</div>';

    return $content;
}

# Cette fonction génère une chaîne de champs cachés HTML à partir d'un hash de données.
# Elle permet de supprimer des clés (également avec *), d'ajouter de nouvelles clés et de modifier des clés existantes.
#my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, [], [], []);
#my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['key_to_remove'], [['new_key1', 'valeur1'], ['new_key2', 'valeur2']], [['existing_key1', 'modified_value1']]);
#my $hidden_fields_form = Base::Site::util::create_hidden_fields_form($args, ['test*'], [], []);
sub create_hidden_fields_form {
    my ($args, $keys_to_remove, $keys_to_add, $key_value_pairs_to_modify) = @_;

    # Supprimez les clés spécifiées de $args
    delete @$args{@$keys_to_remove};
    
    # Supprimez les clés qui commencent par une chaîne spécifiée (par exemple, "test*")
    foreach my $prefix (@$keys_to_remove) {
        delete @$args{grep /^$prefix/, keys %$args};
    }

    # Ajoutez les clés spécifiées à $args (si la liste n'est pas vide)
    @$args{@$keys_to_add} = (1) x scalar @$keys_to_add if @$keys_to_add;

    # Modifiez les clés spécifiées dans $args (si la liste n'est pas vide)
    foreach my $pair (@$key_value_pairs_to_modify) {
        my ($key, $value) = @$pair;
        $args->{$key} = $value;
    }

    # Créez la chaîne $hidden_fields_form avec les arguments restants
    my $hidden_fields_form = join '', map {
        my $value = defined $args->{$_} ? $args->{$_} : '';
        qq{<input type="hidden" name="$_" value="$value">}
    } keys %$args;

    return $hidden_fields_form;
}

# $result_date->{date_debut}  $result_date->{date_fin} $result_date->{nom_mois}
#my $result_date = Base::Site::util::transformation_mois($args->{select_year}, $args->{select_month});
sub transformation_mois {
    my ($annee, $mois) = @_;
    my @noms_des_mois = qw(Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre Année);
	
	
	
    # Vérifier si le numéro de mois est valide
    if ($mois >= 1 && $mois <= 13) {
		
		# Récupérer le nom du mois à partir du tableau et le convertir en majuscules
        my $nom_mois = $noms_des_mois[$mois - 1];
		if ($mois eq 13) {$mois = 12;}

		# Construire la date du premier jour du mois
		my $date_debut = Time::Piece->strptime("$annee-$mois-01", "%Y-%m-%d");
		# Formater la date du mois
		my $month_offset = Time::Piece->strptime("$annee-$mois", "%Y-%m");
		my $month_offset_two = $month_offset->strftime("%m");
		# Calculer le dernier jour du mois
		my $date_fin = $month_offset->month_last_day;

        # Formater le numéro de mois avec deux chiffres
        my $mois_formatte = sprintf("%02d", $mois);

        # Formater les dates au format souhaité
        my $date_debut_formattee = '01/'.$month_offset_two.'/'.$annee ;
        my $date_fin_formattee   = $date_fin.'/'.$month_offset_two.'/'.$annee;
        
        # Retourner un hash contenant toutes les informations
        return {
            date_debut => $date_debut_formattee,
            date_fin   => $date_fin_formattee,
            nom_mois   => $nom_mois,
            mois_for   => $mois_formatte,
        };
    } else {
       return {};
    }
}

#my ($year1, $month1, $day1) = Base::Site::util::extract_date_components($date_str1);
# Fonction pour extraire les composants (année, mois, jour) d'une date
# Vérifie la cohérence de la date avec plusieurs formats
# Si aucun format n'est OK, retourne la date du jour
sub extract_date_components {
    my ($date_str) = @_;
    
    # Vérifier si $date_str est défini
    unless (defined $date_str && $date_str ne '') {
        warn "Date string is undefined or empty";
        return Time::Piece->new()->ymd;  # Retourne la date du jour par défaut
    }

    my ($year, $month, $day) = (undef, undef, undef);  # Initialisez avec des valeurs par défaut undef

    # Liste des expressions régulières correspondant à différents formats de date
    my @regex_formats = (
        qr/^(?:\d{4}-\d{2}-\d{2})$/,
        qr/^(?:\d{2}-\d{2}-\d{2})$/,
        qr/^(?:\d{8})$/,
        qr/^(?:\d{4}\/\d{2}\/\d{2})$/,
        qr/^(?:\d{2}\/\d{2}\/\d{4})$/,
        qr/^(?:\d{2}\/\d{2}\/\d{2})$/,
        qr/^(?:\d{4}\/\d{2})$/,
        qr/^(?:\d{6})$/,
        qr/^(?:\d{8})$/,
        # Ajoutez d'autres formats de date si nécessaire
    );

    # Pré-validation de la chaîne de date
    my $is_valid = 0;
    foreach my $regex_format (@regex_formats) {
        if ($date_str =~ $regex_format) {
            $is_valid = 1;
            last;
        }
    }

    if ($is_valid) {
        # Parcourt les expressions régulières pour essayer de les analyser
        foreach my $regex_format (@regex_formats) {
            if ($date_str =~ $regex_format) {
                if ($date_str =~ /\b(\d{4})-(\d{2})-(\d{2})\b/) {
                    ($year, $month, $day) = ($1, $2, $3);
                } elsif ($date_str =~ /\b(\d{2})-(\d{2})-(\d{2})\b/) {
                    ($year, $month, $day) = (20 . $1, $2, $3);
                } elsif ($date_str =~ /\b(\d{8})\b/) {
                    ($year, $month, $day) = ($1 =~ /^(\d{4})(\d{2})(\d{2})$/);
                } elsif ($date_str =~ /\b(\d{4})\/(\d{2})\/(\d{2})\b/) {
                    ($year, $month, $day) = ($1, $2, $3);
                } elsif ($date_str =~ /\b(\d{2})\/(\d{2})\/(\d{4})\b/) {
                    ($year, $month, $day) = ($3, $2, $1);
                } elsif ($date_str =~ /\b(\d{2})\/(\d{2})\/(\d{2})\b/) {
                    ($year, $month, $day) = (20 . $3, $2, $1);
                } elsif ($date_str =~ /\b(\d{4})\/(\d{2})\b/) {
                    ($year, $month, $day) = ($1, $2, 1);  # Par défaut, le jour est défini sur 1
                } elsif ($date_str =~ /\b(\d{6})\b/) {
                    ($year, $month, $day) = ($1 =~ /^(\d{4})(\d{2})(\d{2})$/);
                }
                last;  # Sort de la boucle dès qu'un format est trouvé
            }
        }

        # Vérification de la cohérence de la date
        if (defined $year && defined $month && defined $day) {
            if ($month > 12 || $month < 1 || $day < 1 || $day > 31) {
				# Date invalide, retourne la date du jour au format Time::Piece
                return Time::Piece->strptime("$year-$month-$day", "%Y-%m-%d");
         
            }

            if (($month == 4 || $month == 6 || $month == 9 || $month == 11) && $day > 30) {
				# Date invalide, retourne la date du jour au format Time::Piece
                return Time::Piece->strptime("$year-$month-$day", "%Y-%m-%d");
         
            }

            if ($month == 2) {
                if ($day > 29 || ($day == 29 && !($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)))) {
				# Date invalide, retourne la date du jour au format Time::Piece
                return Time::Piece->strptime("$year-$month-$day", "%Y-%m-%d");
         
                }
            }

            # Date OK, retourne les composants
            return ($year, $month, $day);
        }
    }

    # Si aucun format valide n'a été trouvé, retourne la date du jour au format Time::Piece
	return Time::Piece->strptime("$year-$month-$day", "%Y-%m-%d");
}

# Fonction pour vérifier les arguments obligatoires en fonction d'un masque binaire
# 1=>compte_fournisseur, 2=>select_achats, 3=>montant, 4=>compte_client, 5=>compte_comptant, 6=> id_compte_1_select, 7=> id_compte_2_select, 8=>date_comptant
#if ($erreur) {$content .= $erreur;  # Affichez le message d'erreur#} else {# Le traitement réussi ou continuez avec d'autres actions }
#my $erreur = Base::Site::util::verifier_args_obligatoires($r, $args,1, [2, 'valeur2'], 3, [10, 'valeur10']);
sub verifier_args_obligatoires {
    my ($r, $args, @types) = @_;

    my %types_to_check = map { ref($_) eq 'ARRAY' ? $_->[0] : $_ => 1 } @types;  # Crée un hachage pour les types à vérifier
    my %custom_values = map { ref($_) eq 'ARRAY' ? ($_->[0] => $_->[1]) : () } @types;  # Crée un hachage pour les valeurs personnalisées

    my @errors;
	my $id_href = '<a title="Cliquer ici pour modifier les journaux" href="journal?configuration">Journaux =&gt; Modifier la liste</a>';
	
    # Vérifier les arguments en fonction de la liste de types
    push @errors, 'Impossible le compte fournisseur n\'a pas été sélectionné' if ($types_to_check{1} && ($custom_values{1} ? $custom_values{1} : ($args->{compte_fournisseur} || '')) eq '');
    push @errors, 'Impossible le mode de paiement n\'a pas été sélectionné' if ($types_to_check{2} && ($custom_values{2} ? $custom_values{2} : ($args->{select_achats} || '')) eq '');
    push @errors, 'Impossible le montant est à 0.00' if ($types_to_check{3} && ($custom_values{3} ? $custom_values{3} : ($args->{montant} || '0.00')) eq '0.00');
    push @errors, 'Impossible le montant n\'est pas un chiffre valide' if ($types_to_check{3} && ($custom_values{3} ? $custom_values{3} : ($args->{montant} || '0.00')) =~ s/\s+//gr !~ /^\d+(\.\d+)?$/);
    push @errors, 'Impossible le compte client n\'a pas été sélectionné' if ($types_to_check{4} && ($custom_values{4} ? $custom_values{4} : ($args->{compte_client} || '')) eq '');
    push @errors, 'Impossible le compte fournisseur n\'a pas été sélectionné' if ($types_to_check{5} && ($custom_values{5} ? $custom_values{5} : ($args->{compte_comptant} || '')) eq '');
    push @errors, 'Impossible le compte de départ n\'a pas été sélectionné' if ($types_to_check{6} && ($custom_values{6} ? $custom_values{6} : ($args->{id_compte_1_select} || $args->{select_achats} || '')) eq '');
    push @errors, 'Impossible le compte de destination n\'a pas été sélectionné' if ($types_to_check{7} && ($custom_values{7} ? $custom_values{7} : ($args->{id_compte_2_select} || '')) eq '');
    push @errors, 'Impossible le compte de charge n\'a pas été sélectionné' if ($types_to_check{9} && ($custom_values{9} ? $custom_values{9} : ($args->{compte_depense} || '')) eq '');
    push @errors, 'Impossible le libellé est vide' if ($types_to_check{10} && ($custom_values{10} ? $custom_values{10} : (defined $args->{libelle} ? ($args->{libelle} =~ s/^\s+|\s+$//gr) : '')) eq '');
	push @errors, 'Impossible le compte de produit n\'a pas été sélectionné' if ($types_to_check{11} && ($custom_values{11} ? $custom_values{11} : ($args->{compte_produit} || '')) eq '');
	push @errors, 'Impossible le compte de charge n\'a pas été sélectionné' if ($types_to_check{12} && ($custom_values{12} ? $custom_values{12} : ($args->{compte_charge} || '')) eq '');
	push @errors, 'Impossible le compte fournisseur n\'a pas été sélectionné' if ($types_to_check{13} && ($custom_values{13} ? $custom_values{1} : ($args->{compte_fournisseur2} || '')) eq '');
	push @errors, 'Impossible le compte client n\'a pas été sélectionné' if ($types_to_check{14} && ($custom_values{14} ? $custom_values{14} : ($args->{compte_client2} || '')) eq '');
	push @errors, 'Impossible, aucun journal de type "Achats" n\'a été trouvé.<br>Cliquez ici pour configurer le type de journal : '.$id_href.'' if ($types_to_check{15} && ($custom_values{15} ? $custom_values{15} : ($args->{lib_journal_achats} || '')) eq '');
	push @errors, 'Impossible, aucun journal de type "Ventes" n\'a été trouvé.<br>Cliquez ici pour configurer le type de journal : '.$id_href.'' if ($types_to_check{16} && ($custom_values{16} ? $custom_values{16} : ($args->{lib_journal_ventes} || '')) eq '');    
	push @errors, 'Impossible le compte n\'a pas été sélectionné' if ($types_to_check{17} && ($custom_values{17} ? $custom_values{17} : ($args->{compte_autres} || '')) eq '');
	push @errors, 'Impossible le montant n\'est pas un chiffre valide' if ($types_to_check{18} && ($custom_values{18} ? $custom_values{18} : ($args->{montant} || '0.00')) !~ /^\d+(\.\d+)?$/);
    push @errors, 'Impossible le code est vide' if ($types_to_check{19} && ($custom_values{19} ? $custom_values{19} : (defined $args->{biens_ref} ? ($args->{biens_ref} =~ s/^\s+|\s+$//gr) : '')) eq '');
    push @errors, 'Impossible le nom est vide' if ($types_to_check{20} && ($custom_values{20} ? $custom_values{20} : (defined $args->{biens_nom} ? ($args->{biens_nom} =~ s/^\s+|\s+$//gr) : '')) eq '');  
    push @errors, 'Impossible la surface (m²) n\'est pas un chiffre valide' if ($types_to_check{21} && ($custom_values{21} ? $custom_values{21} : ($args->{biens_surface} || '0.00')) !~ /^\d+(\.\d+)?$/);
    push @errors, 'Impossible le logement n\'a pas été sélectionné' if ($types_to_check{22} && ($custom_values{22} ? $custom_values{22} : ($args->{immo_logement} || '')) eq '');
	push @errors, 'Impossible la référence est vide' if ($types_to_check{23} && ($custom_values{23} ? $custom_values{23} : (defined $args->{immo_contrat} ? ($args->{immo_contrat} =~ s/^\s+|\s+$//gr) : '')) eq '');
    push @errors, 'Impossible le prénom est vide' if ($types_to_check{24} && ($custom_values{24} ? $custom_values{24} : (defined $args->{locataires_prenom} ? ($args->{locataires_prenom} =~ s/^\s+|\s+$//gr) : '')) eq '');  
    push @errors, 'Impossible le formulaire est vide' if ($types_to_check{25} && ($custom_values{25} ? $custom_values{25} : (defined $args->{formulaire} ? ($args->{formulaire} =~ s/^\s+|\s+$//gr) : '')) eq '');  
    push @errors, 'Impossible la description est vide' if ($types_to_check{26} && ($custom_values{26} ? $custom_values{26} : (defined $args->{description} ? ($args->{description} =~ s/^\s+|\s+$//gr) : '')) eq '');  
    push @errors, 'Impossible le code est vide' if ($types_to_check{27} && ($custom_values{27} ? $custom_values{27} : (defined $args->{code} ? ($args->{code} =~ s/^\s+|\s+$//gr) : '')) eq '');  
       
    if ($types_to_check{8} && ($custom_values{8} ? $custom_values{8} : ($args->{date_comptant} || '')) =~ /^(\d{2}[-\/]\d{2}[-\/]\d{4}|\d{4}[-\/]\d{2}[-\/]\d{2})$/) {
        my ($annee_date) = ($custom_values{8} ? $custom_values{8} : ($args->{date_comptant} || '')) =~ /(\d{4})/;
        my $annee_fiscale = $r->pnotes('session')->{fiscal_year};
        push @errors, 'L\'année de la date de comptabilité ne correspond pas à l\'année fiscale en cours' if $annee_date ne $annee_fiscale;
    }

    # Générer un message d'erreur unique en concaténant toutes les erreurs
    return join("<br>", @errors) if @errors;

    # Aucune erreur, retourne une chaîne vide
    return '';
}

#my $message2 = '*** Date: ' . ($args->{date_comptant} || '') . ' Compte: ' . ($args->{compte_comptant} || '') . ' Libellé: ' . ($args->{libelle} || '') . ' Montant: ' . ($args->{montant} || '') . '€ Journal: ' . ($args->{select_achats} || '') . ' ? ***';
#my $confirmation_message = Base::Site::util::create_confirmation_message($r, $message2, 'achat_comptant', $args->{achat_comptant}, $hidden_fields);
#$content .= Base::Site::util::generate_error_message($confirmation_message);
sub create_confirmation_message {
    my ($r, $message2, $name, $value, $hidden_fields, $valeur) = @_;
    
    $valeur //= 1;  # Affecte 1 à $value si $value est undef
	my $link_href = $r->uri;
    my $message .= '
		'.$message2.'
        <form method="POST" action="' . $link_href . '">
        <button type="submit" style="width: 5%;" class="button-link" name="'.$name.'" value="'.$valeur.'" style="margin-left: 3em;">Oui</button>
        <button type="submit" style="width: 5%;" class="button-link" name="'.$name.'" value="" style="margin-left: 3em;">Non</button>
        ' . $hidden_fields . '
        </form>';

   if ($r->method eq 'POST' && defined $value && ($value == 1 || $value == 2 || $value == 6 || $value == 7)) {
		
        $r->headers_out->set(Location => ($link_href = $r->uri =~ s/docsentry/menu/r));
        return Apache2::Const::REDIRECT;
    }

    return $message;
}

# Préparation insertion dans tbljournal_staging de transfert_compte
# $type=>1)record_staging 2)tbljournal_staging 
# $role=>1)transfert 2)comptant 3)client 4)fournisseur 5)recette 6)dépense
#$content .= Base::Site::util::preparation_action_staging($r, $args, $dbh, 1, 1);
sub preparation_action_staging {
    my ($r, $args, $dbh, $type, $role) = @_;
    my ($content, $message, $pointage, $pointage2) = ('', '', 'f', 'f');
    my ($token_id1, $token_id2, @bind_array1, @bind_array2, $sql);
    my $type_piece = '';
    my $journal_info = Base::Site::util::get_journal_info($r, $dbh);
	my $lib_journal_achats = $journal_info->{'Achats'};
	my $lib_journal_ventes = $journal_info->{'Ventes'};

    #Type 2 pour enregistrement dans tbljournal_staging mais pas dans tbljournal
    if (defined $type && $type eq 2) {
		my $token_id_temp1 = Base::Site::util::generate_unique_token_id($r, $dbh);
		my $token_id_temp2 = Base::Site::util::generate_unique_token_id($r, $dbh);
		$token_id1 = 'csv-'.$token_id_temp1 ;
		$token_id2 = 'csv-'.$token_id_temp2 ;
		$type_piece = 2;
		$pointage2 = 't';
	#Type 1 pour enregistrement dans tbljournal_staging et dans tbljournal	
	} else {
		$token_id1 = Base::Site::util::generate_unique_token_id($r, $dbh);
		$token_id2 = Base::Site::util::generate_unique_token_id($r, $dbh);	
	}
	
    # Récupère les paramètres de règlement pour le libellé spécifique.
    my ($reglement_journal_1, $reglement_compte_1, $reglement_journal_2, $reglement_compte_2) = ('', '', '', '');
    my $parametres_reglements = Base::Site::bdd::get_parametres_reglements($dbh, $r, undef, undef ,1);
    my $lib_specifique_1 = $args->{select_achats} || $args->{id_compte_1_select} || '';
    my $lib_specifique_2 = $args->{id_compte_2_select} || '';
    foreach my $row (@$parametres_reglements) {
        if ($row->{config_libelle} eq $lib_specifique_1) {$reglement_journal_1 = $row->{config_journal};$reglement_compte_1 = $row->{config_compte};}
        if ($row->{config_libelle} eq $lib_specifique_2) {$reglement_journal_2 = $row->{config_journal};$reglement_compte_2 = $row->{config_compte};}
    }
    
    # Cette fonction formate le montant et le libellé selon des spécifications définies.
	Base::Site::util::formatter_montant_et_libelle(\$args->{montant}, \$args->{libelle});
    
    # Génére numéro pièce et si type_piece=>2 alors recherche également dans tbljournal_staging
    if (!defined $args->{piece} || $args->{piece} eq '') {
		if (defined $role && ($role eq 2 || $role eq 9 || $role eq 7)) { # Calcul numéro pièce pour recette et comptant et le journal Vente
			$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, $lib_journal_ventes, $args->{date_comptant}, $type_piece);
		} elsif (defined $role && ($role eq 10 || $role eq 8 )) {# Calcul numéro pièce pour dépense et comptant et le journal Achats
			$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, $lib_journal_achats, $args->{date_comptant}, $type_piece);
		} else {
			$args->{piece} = Base::Site::util::generate_piece_number($r, $dbh, $args, $reglement_journal_1, $args->{date_comptant}, $type_piece);
		}
	}

    # $role=>1)transfert 5 vers 58 + 58 vers 5
    if (defined $role && $role eq 1) {
		my $lettrage = Base::Site::util::get_lettrage($r, $dbh, '580000');
		$message = 'Saisie rapide (Transfert entre deux comptes financiers) =>
     	1/2 (Banque 1 - Virement interne) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: 580000, Compte crédit: '.($reglement_compte_1 || '' ).', Journal: '.($reglement_journal_1 || '' ).'
    	2/2 (Virement interne - Banque 2) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($reglement_compte_2 || '' ).', Compte crédit: 580000, Journal: '.($reglement_journal_2 || '' ).'';
		@bind_array1 = (
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, 0, $args->{montant} * 100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef),
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, '580000', $lettrage, $pointage, $args->{montant} * 100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef)
		);
		@bind_array2 = (
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, '580000', $lettrage, $pointage, 0, $args->{montant} * 100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_2, $token_id2, ($args->{docs1} || undef), ($args->{docs2} || undef),
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_2, undef, $pointage, $args->{montant} * 100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_2, $token_id2, ($args->{docs1} || undef), ($args->{docs2} || undef) );

	# $role=>2)comptant 5 vers 401 + 401 vers 6
	} elsif (defined $role && $role eq 2) {
    	my $lettrage = Base::Site::util::get_lettrage($r, $dbh, $args->{compte_comptant});
		$message = 'Saisie rapide d\'un paiement comptant => Date: ' .($args->{date_comptant} || '') . ' Montant: ' . ($args->{montant} || '') .'€ Libellé: ' . ($args->{libelle} || '') .' Compte: '. ($reglement_compte_1 || '') .' Journal: '.($reglement_journal_1 || '').'';
		@bind_array1 = ( 
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_comptant}, $lettrage, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, 'ACHATS', $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_charge_comptant}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, 'ACHATS', $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
		@bind_array2 = ( 
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_comptant}, $lettrage, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1} || undef), ($args->{docs2} || undef), 
			$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
	
	# $role=>3)client 411 vers 5
	} elsif (defined $role && $role eq 3) {
		$message = 'Saisie rapide (Recette - Règlement client) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($reglement_compte_1 || '' ).', Compte crédit: '.($args->{compte_client} || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
		@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_client}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
	
	# $role=>11)compte 4 vers 5
	} elsif (defined $role && $role eq 11) {
		$message = 'Saisie rapide (Recette - Autres entrées d\'argent) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($reglement_compte_1 || '' ).', Compte crédit: '.($args->{compte_autres} || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_autres}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
		
	# $role=>4)fournisseur 401 vers 5
	} elsif (defined $role && $role eq 4) {
    	$message = 'Saisie rapide (Dépense - Règlement fournisseur) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_fournisseur} || '' ).', Compte crédit: '.($reglement_compte_1 || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = (
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_fournisseur}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef) ) ;
	
	# $role=>12)compte 4 vers 5
	}elsif (defined $role && $role eq 12) {
    	$message = 'Saisie rapide (Dépense - Autres sorties d\'argent) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_autres} || '' ).', Compte crédit: '.($reglement_compte_1 || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = (
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_autres}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef) ) ;
	
	# $role=>5)recette 5 vers 7
	} elsif (defined $role && $role eq 5) {
    	$message = 'Saisie rapide (Recette - Recette) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($reglement_compte_1 || '' ).', Compte crédit: '.($args->{compte_produit} || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef),
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_produit}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef) );
		
	# $role=>6)dépense 5 vers 6
	} elsif (defined $role && $role eq 6) {
    	$message = 'Saisie rapide (Dépense - Dépense) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_charge} || '' ).', Compte crédit: '.($reglement_compte_1 || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_charge}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
	
	# $role=>7)client 411 vers 7
	} elsif (defined $role && $role eq 7) {
    	$message = 'Saisie rapide (Recette - Facture client) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_client2} || '' ).', Compte crédit: '.($args->{compte_produit} || '' ).', Journal: '.($lib_journal_ventes || '' ).'';
    	@bind_array1 = (
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_client2}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_ventes, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_produit}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_ventes, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef) ) ;
		
	# $role=>8)fournisseur 401 vers 6
	} elsif (defined $role && $role eq 8) {
    	$message = 'Saisie rapide (Dépense - Facture fournisseur) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_charge} || '' ).', Compte crédit: '.($args->{compte_fournisseur2} || '' ).', Journal: '.($lib_journal_achats || '' ).'';
     	@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_fournisseur2}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_achats, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_charge}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_achats, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
	
	# $role=>9)client 411 vers 7 + 411 vers 5
	}  elsif (defined $role && $role eq 9) {
		my $lettrage = Base::Site::util::get_lettrage($r, $dbh, $args->{compte_client2});
    	$message = 'Saisie rapide (Recette - Recette Comptant) =>
     	1/2 (Recette - Facture client) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_client2} || '' ).', Compte crédit: '.($args->{compte_produit} || '' ).', Journal: '.($lib_journal_ventes || '' ).'
    	2/2 (Recette - Règlement client) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($reglement_compte_1 || '' ).', Compte crédit: '.($args->{compte_client2} || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
		@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_client2}, $lettrage, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_ventes, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_produit}, undef, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_ventes, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef) ) ;
		@bind_array2 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_client2}, $lettrage, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1}|| undef), ($args->{docs2}|| undef),
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1} || undef), ($args->{docs2} || undef) ) ;
	
	# $role=>10)fournisseur 401 vers 6 + 401 vers 5
	} elsif (defined $role && $role eq 10) {
		my $lettrage = Base::Site::util::get_lettrage($r, $dbh, $args->{compte_fournisseur2});
    	$message = 'Saisie rapide (Dépense - Dépense Comptant) =>
    	1/2 (Dépense - Facture fournisseur) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_charge} || '' ).', Compte crédit: '.($args->{compte_fournisseur2} || '' ).', Journal: '.($lib_journal_achats || '' ).'
    	2/2 (Dépense - Règlement fournisseur) => Date: ' .($args->{date_comptant} || '' ). ', Montant: ' . ($args->{montant} || '' ) .'€, Libellé: ' . ($args->{libelle} || '' ) .', Compte débit: '.($args->{compte_fournisseur2} || '' ).', Compte crédit: '.($reglement_compte_1 || '' ).', Journal: '.($reglement_journal_1 || '' ).'';
    	@bind_array1 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_fournisseur2}, $lettrage, $pointage, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_achats, $token_id1, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_charge}, undef, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $lib_journal_achats, $token_id1, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
		@bind_array2 = ( 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $args->{compte_fournisseur2}, $lettrage, $pointage, $args->{montant}*100, 0, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1} || undef), ($args->{docs2} || undef), 
		$r->pnotes('session')->{_session_id}, 0, $args->{date_comptant}, $args->{libelle}, $reglement_compte_1, undef, $pointage2, 0, $args->{montant}*100, $r->pnotes('session')->{id_client}, ($args->{piece} || undef), ($args->{libre} || undef), $r->pnotes('session')->{fiscal_year}, $r->pnotes('session')->{fiscal_year_offset}, $r->pnotes('session')->{Exercice_debut_YMD}, $r->pnotes('session')->{Exercice_fin_YMD}, $reglement_journal_1, $token_id2, ($args->{docs1}|| undef), ($args->{docs2}|| undef) ) ;
	
	} 

    #Type 2 pour enregistrement que dans tbljournal_staging mais pas dans tbljournal
    if (defined $type && $type eq 2) {
		
		my $error_message_1 = Base::Site::bdd::call_insert_staging($dbh, \@bind_array1);
		$content .= Base::Site::util::generate_error_message("Erreur lors de l'insertion 1 : $error_message_1<br>") if $error_message_1;
		
		if (defined $role && ($role ne 3 && $role ne 4 && $role ne 5 && $role ne 6 && $role ne 7 && $role ne 8)) {
			my $error_message_2 = Base::Site::bdd::call_insert_staging($dbh, \@bind_array2);
			$content .= Base::Site::util::generate_error_message("Erreur lors de l'insertion 2 : $error_message_2<br>") if $error_message_2;
			return $content;
		}
	} else {

		# Appeler la fonction pour la première insertion
		my $insertion_1 = Base::Site::bdd::call_insert_record_staging($dbh, \@bind_array1, $token_id1);

		# Vérifier s'il y a une erreur lors de la première insertion
		if ($insertion_1) {
			$content .= Base::Site::util::generate_error_message($insertion_1);
			# Retourner le contenu à l'appelant
			return $content;
		} else {
			
			if (defined $role && ($role eq 3|| $role eq 4 || $role eq 5 || $role eq 6 || $role eq 7 || $role eq 8 || $role eq 11 || $role eq 12)) {
				Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => '.$message.'');
				#$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name=' . $args->{id_name} : 'journal?open_journal=' . ($reglement_journal_1 || '');
				$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name=' . $args->{id_name} : 'menu?search=1&search_piece=' . ($args->{piece} || '').'&search_lib=' . ($args->{libelle} || '');
				Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
				return Apache2::Const::OK;  # Indique que le traitement est terminé
			} else {
				# La première insertion est réussie, effectuer la deuxième insertion
				my $insertion_2 = Base::Site::bdd::call_insert_record_staging($dbh, \@bind_array2, $token_id2);

				# Vérifier s'il y a une erreur lors de la deuxième insertion
				if ($insertion_2) {
					$content .= Base::Site::util::generate_error_message($insertion_2);
					# Retourner le contenu à l'appelant
					return $content;
				} else {
					Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'menu.pm => '.$message.'');
					#$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name=' . $args->{id_name} : 'journal?open_journal=' . ($reglement_journal_1 || '');
					$args->{restart} = defined $args->{id_name} && $args->{id_name} ne '' ? 'docsentry?id_name=' . $args->{id_name} : 'menu?search=1&search_piece=' . ($args->{piece} || '').'&search_lib=' . ($args->{libelle} || '');
					Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
					return Apache2::Const::OK;  # Indique que le traitement est terminé
				}
			}
		}
	}
}


######################################################################   
# Générer numéro de pièce / lettrage								 #
######################################################################  

#my $lettrage = Base::Site::util::get_lettrage($r, $dbh, $args->{compte_comptant});
sub get_lettrage {
    my ($r, $dbh, $compte) = @_;

    my $sql_total = 'SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND lettrage IS NOT NULL ORDER BY length(lettrage) DESC, lettrage DESC LIMIT 1';
    my @bind_array_total = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    my $lettrage_total = $dbh->selectall_arrayref($sql_total, undef, @bind_array_total)->[0]->[0];

    my $sql_comptant = 'SELECT lettrage FROM tbljournal WHERE id_client = ? AND fiscal_year = ? AND numero_compte = ? AND lettrage IS NOT NULL ORDER BY length(lettrage) DESC, lettrage DESC LIMIT 1';
    my @bind_array_comptant = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $compte);
    my $lettrage = $dbh->selectall_arrayref($sql_comptant, undef, @bind_array_comptant)->[0]->[0];

	if ( $lettrage ) {
		$lettrage++ ;
	} else {
		if ($lettrage_total) {
			my $lettrage_sub = substr( $lettrage_total, 0, 2 );
			$lettrage = ++$lettrage_sub.'01';
		} else {
			$lettrage = 'AA01' ;
		}	
	}
		
    return $lettrage;
}

#my $numero_piece = Base::Site::util::generate_piece_number($r, $dbh, $args, $reglement_journal, $date_operation);
##Optionnel : Type2 tbljournal et tbljournal_staging et Type1 tbljournal 	 
sub generate_piece_number {
    my ( $r, $dbh, $args, $reglement_journal, $date, $type) = @_;

    my $sql = 'SELECT libelle_journal, code_journal FROM tbljournal_liste WHERE id_client = ? AND fiscal_year = ? ORDER BY libelle_journal';
    my @bind_array = ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    my $journal_code_set = $dbh->selectall_arrayref($sql, undef, @bind_array);

    my $journal = '';
    for (@$journal_code_set) {
        if ($reglement_journal eq $_->[0]) {
            $journal = $_->[1];
            last;
        }
    }
	
	my ($year, $month, $day) = Base::Site::util::extract_date_components($date);

    my $item_num = 1;
    
    #Type2 tbljournal et tbljournal_staging	
	if (defined $type && $type eq 2) {
		$sql = '
		SELECT id_facture as item_number, extract(month from ?::date) as month_number, extract(year from ?::date) as year_number
		FROM tbljournal
		WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ? AND substring(id_facture from 8 for 2) = ?
		UNION
		SELECT id_facture as item_number, extract(month from ?::date) as month_number, extract(year from ?::date) as year_number
		FROM tbljournal_staging
		WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ? AND substring(id_facture from 8 for 2) = ?
		ORDER BY item_number DESC
		LIMIT 1';	

	@bind_array = ( 
		$args->{date_comptant}, $args->{date_comptant}, $journal, 
		$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $reglement_journal, $month,
		$args->{date_comptant}, $args->{date_comptant}, $journal, 
		$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $reglement_journal, $month
	);

	#Type1 tbljournal
	} else {
		$sql = '
		SELECT id_facture as item_number, extract(month from ?::date) as month_number, extract(year from ?::date) as year_number
		FROM tbljournal
		WHERE id_facture NOT LIKE \'%MULTI%\' and substring(id_facture from 1 for 2) LIKE ? and id_client = ? and fiscal_year = ? and libelle_journal = ? AND substring(id_facture from 8 for 2) = ?
		ORDER BY 1 DESC LIMIT 1';	

	@bind_array = ( 
		$args->{date_comptant}, $args->{date_comptant}, $journal, 
		$r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $reglement_journal, $month
	);

	}

 my $calcul_piece = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);

    for (@$calcul_piece) {
        if (substr($_->{item_number}, 10, 2) =~ /\d/ && substr($_->{item_number}, 0, 2) eq $journal) {
            $item_num = int(substr($_->{item_number}, 10, 2)) + 1;
        }
    }

    if ($item_num < 10) {
        $item_num = "0" . $item_num;
    }

    my $numero_piece = $journal . $year . '-' . $month . '_' . $item_num;
    return $numero_piece;
} # generate_piece_number

#Vérification si des écritures n'en pas encore été générée dans tbljournal_staging 
#my ($verif_list, $entry_list) = Base::Site::util::check_and_format_ecritures_tbljournal_staging($dbh, $r, $args, 'ecriture_recurrente', '%recurrent%');
sub check_and_format_ecritures_tbljournal_staging {
     my ($dbh, $r, $args, $fonction, $token_like, $hidden_fields) = @_;

    my $verif_list = '';
    my $entry_list = '';
    my $varname = '';

    my $sql = '
        SELECT t1.id_entry, t1.id_export, t1.date_ecriture, t1.libelle_journal, t1.numero_compte,
        coalesce(t1.id_paiement, \'&nbsp;\') as id_paiement, coalesce(t1.id_facture, \'&nbsp;\') as id_facture,
        coalesce(t1.libelle, \'&nbsp;\') as libelle, coalesce(t1.documents1, \'&nbsp;\') as documents1,
        coalesce(t1.documents2, \'&nbsp;\') as documents2, to_char(t1.debit/100::numeric, \'999G999G999G990D00\') as debit,
        to_char(t1.credit/100::numeric, \'999G999G999G990D00\') as credit, to_char((sum(t1.debit) over())/100::numeric, \'999G999G999G990D00\') as total_debit,
        to_char((sum(t1.credit) over())/100::numeric, \'999G999G999G990D00\') as total_credit, lettrage, pointage, recurrent, _token_id
        FROM tbljournal_staging t1
        WHERE t1._token_id LIKE ? AND id_client = ? AND fiscal_year = ?
        ORDER BY date_ecriture, id_facture, _token_id, numero_compte, libelle ';

    my @bind_array = ($token_like, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
    my $result_gen = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind_array);

    if (@$result_gen) {
        $verif_list .= '<div class="Titre10 centrer"><a class=aperso2 id=rec >Ecritures générées en attente de validation</a></div><br>';

        $verif_list .= '
            <form action="' . $r->uri() . '" method="post">
            <ul class="wrapper style1">
            <li class="style1"><div class=flex-table><div class=spacer></div>
            <span class=headerspan style="width: 9%;">Date</span>
            <span class=headerspan style="width: 8%;">Libre</span>
            <span class=headerspan style="width: 8%;">Journal</span>
            <span class=headerspan style="width: 8%;">Compte</span>
            <span class=headerspan style="width: 12%;">Pièce</span>
            <span class=headerspan style="width: 28.9%;">Libellé</span>
            <span class=headerspan style="width: 8%; text-align: right;">Débit</span>
            <span class=headerspan style="width: 8%; text-align: right;">Crédit</span>
            <span class=headerspan style="width: 5%; text-align: center;">&nbsp;</span>
            <span class=headerspan style="width: 5%; text-align: center;">&nbsp;</span>
            <div class=spacer></div></div></li>
        ';

        my $token_entry = '';
        my $id_entry_href;

        for (@$result_gen) {
            if (defined $token_entry) {
                unless ($_->{_token_id} eq $token_entry) {
                    my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8($_->{libelle_journal}) . '&amp;mois=0&amp;id_entry=' . $_->{id_entry}. '&amp;_token_id=' . $_->{_token_id};

                    unless ($token_entry) {
                        $entry_list .= '<li class=listitem3>' ;
                    } else {
                        $entry_list .= '</a></li><li class=listitem3>';
                    }
                }
            }

            my $http_link_documents1 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents1}, 1);
            my $http_link_documents2 = Base::Site::util::generate_document_link_2($r, $args, $dbh, $_->{documents2}, 2);

            $token_entry = $_->{_token_id};

            my ($docsentry);
            if (defined $args->{id_name} && $args->{id_name} ne '') {
                $docsentry = '&amp;id_name=' . ($args->{id_name} || '') . '';
                $varname = $args->{id_name};
            }

            my $id_entry_href = '/'.$r->pnotes('session')->{racine}.'/entry?open_journal=' . URI::Escape::uri_escape_utf8($_->{libelle_journal}) . '&amp;mois=0&amp;id_entry=' . $_->{id_entry} . ($docsentry || ''). '&amp;_token_id=' . $_->{_token_id};

            $sql = 'SELECT libelle_compte FROM tblcompte WHERE id_client = ? AND fiscal_year = ? AND numero_compte like ? ORDER BY 1 DESC LIMIT 1';
            my $libelle_compte_set = $dbh->selectall_arrayref($sql, { Slice => {} }, ($r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year}, $_->{numero_compte}));

            $entry_list .= '
                <div class=flex-table><div class=spacer></div><a href="' . ($id_entry_href || ''). '" >
                <span class=displayspan style="width: 9%;">' . ($_->{date_ecriture} || '&nbsp;') . '</span>
                <span class=displayspan style="width: 8%;">' . ($_->{id_paiement}  || '&nbsp;') . '</span>
                <span class=displayspan style="width: 8%;">' . ($_->{libelle_journal}  || '&nbsp;') .'</span>
                <span class=displayspan style="width: 8%;" title="'. ($libelle_compte_set->[0]->{libelle_compte}  || '&nbsp;') .'">' . ($_->{numero_compte}  || '&nbsp;') . '</span>
                <span class=displayspan style="width: 12%;">' . ($_->{id_facture}  || '&nbsp;') . '</span>
                <span class=displayspan style="width: 28.9%;">' . ($_->{libelle} || '&nbsp;') . '</span>
                <span class=displayspan style="width: 8%; text-align: right;">' . $_->{debit} . '</span>
                <span class=displayspan style="width: 8%; text-align: right;">' .  $_->{credit} . '</span>
                <span class=displayspan style="width: 2%;">&nbsp;</span></a>
                <span class=displayspan style="width: 2%;">' . $http_link_documents1 . '</span>
                <span class=displayspan style="width: 2%;">' . $http_link_documents2 . '</span>
                <div class=spacer>
                </div>
                </div>
            ';
        }

        $entry_list .= '</li>' if (@$result_gen);
        
        $entry_list .= '
            </ul>
            <div class="form-int" style="display: flex; align-items:center; justify-content: flex-end;">
				<input type="hidden" name="id_name" value="'.$varname.'">
				<button type="submit" class="btn btn-vert" style="width: 250px;" name="'.$fonction.'" value="4">Valider toutes les écritures</button>
				<button type="submit" class="btn btn-rouge" style="width: 250px;" name="'.$fonction.'" value="5">Supprimer toutes les écritures</button>
				'.($hidden_fields || '').'
			</form>

            </div>
        ';
    }

    return ($verif_list, $entry_list);
}

sub traiter_ligne {
    my ($r, $dbh, $line, $montant, $type, @errors) = @_;

    my %args;
    my $result;

    if ($type eq 'transfert') {
        %args = (
            id_compte_1_select => $line->{id_compte_1_select},
            id_compte_2_select => $line->{id_compte_2_select},
            montant            => $montant,
            date_comptant      => $line->{date_comptant},
            libelle            => $line->{libelle},
            piece              => defined $line->{piece} ? $line->{piece} : undef,
            libre              => defined $line->{libre} ? $line->{libre} : undef,
            docs1              => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2              => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name            => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 1);
    } elsif ($type eq 'recette1') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_produit         	=> $line->{compte_produit},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre              		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 5);
    } elsif ($type eq 'recette2') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_produit         	=> $line->{compte_produit},
            compte_client2         	=> $line->{compte_client},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre              		=> defined $line->{libre} ? $line->{libre} : undef,        
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 7);
    } elsif ($type eq 'recette3') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_produit         	=> $line->{compte_produit},
            compte_client2         	=> $line->{compte_client},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 9);
    } elsif ($type eq 'depense1') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_charge         	=> $line->{compte_charge},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 6);
    } elsif ($type eq 'depense2') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_charge         	=> $line->{compte_charge},
            compte_fournisseur2     => $line->{compte_fournisseur},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 8);
    } elsif ($type eq 'depense3') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_charge         	=> $line->{compte_charge},
            compte_fournisseur2     => $line->{compte_fournisseur},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 10);
    }elsif ($type eq 'reglement_client') {
        %args = (
            select_achats   => $line->{select_achats},
            compte_client   => $line->{compte_comptant},
            montant         => $montant,
            date_comptant   => $line->{date_comptant},
            libelle         => $line->{libelle},
            piece           => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1           => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2           => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name         => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 3);
    } elsif ($type eq 'reglement_fournisseur') {
        %args = (
            select_achats           => $line->{select_achats},
            compte_fournisseur      => $line->{compte_comptant},
            montant                 => $montant,
            date_comptant           => $line->{date_comptant},
            libelle                 => $line->{libelle},
            piece                   => defined $line->{piece} ? $line->{piece} : undef,
            libre             		=> defined $line->{libre} ? $line->{libre} : undef,
            docs1                   => defined $line->{docs1} ? $line->{docs1} : undef,
            docs2                   => defined $line->{docs2} ? $line->{docs2} : undef,
            id_name                 => defined $line->{id_name} ? $line->{id_name} : undef,
        );

        $result = Base::Site::util::preparation_action_staging($r, \%args, $dbh, 2, 4);
    }

    if ($result) {
        push @errors, "Une erreur est survenue lors du traitement de la ligne $line->{lineid}<br>$result";
    } else {
        #$content .= "<p>Traitement réussi pour la ligne $line->{lineid}</p>";
    }
    
    return @errors;
}

#Détecte le type de fichier (CSV ou OFX) à partir du contenu donné.
#my $type = Base::Site::util::detect_csv_type_and_ofx($csv_data);
sub detect_csv_type_and_ofx {
    my ($csv_data) = @_;
    my $found_type = '';

    my @csv_lines = split(/\n/, $csv_data);
	my $header_line = $csv_lines[0];  # Première ligne du CSV contient les en-têtes

    $header_line =~ s/\s+//g;
    $header_line =~ s/"//g;

    my %configurations = (
        'csv-paypal' => { keywords => ["Date", "Net", "Nom"] },
        'boursorama' => { keywords => ["dateOp", "dateVal", "label"] }
        # Ajoutez d'autres configurations ici
    );

	if ($csv_data =~ /<OFX>/i && $csv_data =~ /<\/OFX>/i) {
		#Base::Site::logs::logEntry("#### INFO ####", 'TEST', 'util.pm => un OFX');
        $found_type = 'ofx';  # Le contenu contient à la fois les balises <OFX> et </OFX>
    # Vérification si le contenu ressemble à une structure CSV
    } elsif (scalar(@csv_lines) >= 2 && $header_line =~ /^("[^"]*"|[^,]+)(,("[^"]*"|[^,]+))*$/) {
		#Base::Site::logs::logEntry("#### INFO ####", 'TEST', 'util.pm => un CSV');
        foreach my $type (keys %configurations) {
            my $all_found = 1;

            foreach my $keyword (@{$configurations{$type}{keywords}}) {
                unless ($header_line =~ /$keyword,?/) {
                    $all_found = 0;
                    last;
                }
            }

            if ($all_found) {
                $found_type = $type;
                last;
            } else {
				$found_type = "Inconnu"; # Par défaut, non trouvé
			}
        }
    # Vérification si le contenu contient à la fois les balises <OFX> et </OFX> dans la copie    
    } else {
		#Base::Site::logs::logEntry("#### INFO ####", 'TEST', 'util.pm => un Inconnu');
		$found_type = "Inconnu";  # Par défaut, non trouvé
	}
    
    return $found_type;
}



#Fonction Finance::OFX::Parse::Simple
#my $result = Base::Site::util::parse_scalar($ofx_data); 
sub parse_scalar {
    my $ofx      = shift or return;
    my @results  = (); # to be returned
    
    my $decimal_separator = $ENV{MON_DECIMAL_POINT} || do
    {
	eval 'use POSIX qw(locale_h)';
	my $loc = eval {localeconv()} || {};
	$loc->{mon_decimal_point} || $loc->{decimal_point} || '.';
    };

    # Grab the FID if it exists. For credit card statements, this will exist in
    # place of the BANKID and it will be used instead.
    my $FID = undef;
    my $ACCTTYPE = undef;
    if($ofx =~ m/.*<FID>(\d*)<.*/) {
    $FID=$1;
    $ACCTTYPE = 'Credit Card';
    } elsif($ofx =~ m/.*<FI>\s*<ORG>(.+)<\/ORG>\s*<\/FI>/) {
    $FID=$1;
    $ACCTTYPE = 'Credit Card';
    }

  transaction_group:
    while ($ofx =~ m!(<(?:CC)?STMTTRNRS>(.+?)</(?:CC)?STMTTRNRS>)!sg)
    {
	my ($all,$statements) = ($1,$2);

	my $this = { account_id => undef, transactions => [] };
	
	my $account_id = do
	{
	    my $aa = 0;
	    
	    if ($all =~ m:<ACCTID>([^<]+?)\s*<:s)
	    {
		$aa = $1;
	    }
	    $aa;
	}
	or do {warn "No ACCTID found"; next transaction_group};

	$this->{account_id} = $account_id;

    my $bank_id = do
    {
       my $aa = 0;

       if ($all =~ m:<BANKID>([^<]+?)\s*<:s)
       {
       $aa = $1;
       }
       if($aa == 0 && defined($FID)) {
       $aa = $FID;
       }
        $aa;
    }
    or do {warn "No BANKID found"; next transaction_group};

    $this->{bank_id} = $bank_id;

    my $balance_info = do
    {
       my $aa = "";
       my $bal = undef;
       my $date= undef;

        if ($all =~ m:<LEDGERBAL>(.*)</LEDGERBAL>:s)
        {
           $aa = $1;
           $aa =~ s/\s*//g;
           ($bal = $aa) =~ s/.*<BALAMT>([-+]?\d+\.?\d*).*/$1/;
           ($date = $aa) =~ s/.*<DTASOF>(\d+\.?\d*).*/$1/;
        }
       {balance => $bal, date => $date};
    }
    or do {warn "No LEDGERBAL found"; next transaction_group};

    $this->{balance_info} = $balance_info;

    my $acct_type = do
    {
        my $aa = 0;

        if ($all =~ m:<ACCTTYPE>([^<]+?)\s*<:s)
        {
        $aa = $1;
        } elsif(defined($ACCTTYPE)) {
        $aa = $ACCTTYPE;
        }
        $aa;
    }
    or do {warn "No ACCTTYPE found"; next transaction_group};

    $this->{acct_type} = $acct_type;

	while ($statements =~ m/<BANKTRANLIST>(.+?)<\/BANKTRANLIST>/sg)
	{
	    my $trans = $1;
        if($trans =~ m/<DTEND>(\d+)/g) {
        $this->{endDate} = $1;
        }

	    while ($trans =~ m/<STMTTRN>(.+?)<\/STMTTRN>/sg)
	    {
		my $s = $1;
		
        my ($y,$m,$d) = $s =~ m/<DTPOSTED>\s*(\d\d\d\d)(\d\d)(\d\d)/s ? ($1,$2,$3) : ('','','');

 		my $amount = undef;

		if ($s =~ m/<TRNAMT>\s*([-+])?\s*        # positive-negative sign $1
		    (?:(\d+)                             # whole numbers $2
		     (?:\Q$decimal_separator\E(\d\d?)?)? # optionally followed by fractional number $3
		     |                                   # or
		     \Q$decimal_separator\E(\d\d?))      # just the fractional part $4
		    /sx)
		{
		    my $posneg = $1 || "";
		    my $whole  = $2 || 0;
		    my $frac   = $3 || $4 || 0;

		    $amount = sprintf("%.2f", ($whole + ("0.$frac" / 1)) * (($posneg eq '-') 
									  ? -1 
									  : 1));
		}

		my $fitid = $s =~ m/<FITID>([^\r\n<]+)/s ? $1 : '';

		my $trntype = $s =~ m/<TRNTYPE>([^\r\n<]+)/s ? $1 : '';

		my $checknum = $s =~ m/<CHECKNUM>([^\r\n<]+)/s ? $1 : '';

		my $name = $s =~ m/<NAME>([^\r\n<]+)/s ? $1 : '';
		my $memo = do
		{
		    my $w = "";
		    if ($s =~ m/<MEMO>([^\r\n<]+)/s)
		    {
			$w = $1;
		    }
		    $w;
		};
		push @{$this->{transactions}}, {amount => $amount, date => "$y-$m-$d",
						checknum => $checknum, trntype => $trntype,
						fitid  => $fitid,  name => $name, memo => $memo};
	    }
	}
	push @results, $this;
    }
    return \@results;
}

#Function pour récupérer le type de journal Achats et Ventes
#my $journal_info = Base::Site::util::get_journal_info($r, $dbh);
# Accès aux informations des journaux
#my $lib_journal_achats = $journal_info->{'Achats'};
#my $lib_journal_ventes = $journal_info->{'Ventes'};
sub get_journal_info {
    my ($r, $dbh) = @_;

    my $journaux = Base::Site::bdd::get_journaux($dbh, $r);

    my $journal_info = {
        'Achats' => '',
        'Ventes' => '',
    };

    foreach my $row (@$journaux) {
        my $type = $row->{type_journal};
        if (exists $journal_info->{$type}) {
            $journal_info->{$type} = $row->{libelle_journal};
        }
    }

    return $journal_info;
}

##my $table_html = Base::Site::util::generate_custom_table(\@data);
sub generate_custom_table {
    my ($args) = @_;

    my $table_html = '<ul class="wrapper style1">';

    # Entête du tableau
    $table_html .= '<li class="style1"><div class=flex-table><div class=spacer></div>';
    $table_html .= '<span class=headerspan style="width: 1%; text-align: center;">&nbsp;</span>';
    $table_html .= '<span class=headerspan style="width: 9%;">Date</span>';
    $table_html .= '<span class=headerspan style="width: 9%;">Journal</span>';
    $table_html .= '<span class=headerspan style="width: 9%;">Compte</span>';
    $table_html .= '<span class=headerspan style="width: 15%;">Pièce</span>';
    $table_html .= '<span class=headerspan style="width: 37%;">Libellé</span>';
    $table_html .= '<span class=headerspan style="width: 9%; text-align: right;">Débit</span>';
    $table_html .= '<span class=headerspan style="width: 9%; text-align: right;">Crédit</span>';
    $table_html .= '<span class=headerspan style="width: 1%; text-align: center;">&nbsp;</span>';
    $table_html .= '<div class=spacer></div></div></li>';

    # Lignes de données
    for my $entry (@$args) {
        $table_html .= '<li><div style="font-size: 15px;" class=flex-table><div class=spacer></div>';
        $table_html .= '<span class=displayspan style="width: 1%;">&nbsp;</span>';
        $table_html .= '<span class=displayspan style="width: 9%;">' . ($entry->{date_comptant} || '') . '</span>';
        $table_html .= '<span class=displayspan style="width: 9%;">' . ($entry->{journal} || '') . '</span>';
        $table_html .= '<span class=displayspan style="width: 9%;">' . ($entry->{compte} || '') . '</span>';
        $table_html .= '<span class=displayspan style="width: 15%;">' . ($entry->{piece} || '') . '</span>';
        $table_html .= '<span class=displayspan style="width: 37%;">' . ($entry->{libelle} || '') . '</span>';
        $table_html .= '<span class=displayspan style="width: 9%; text-align: right;">' . ($entry->{debit} || '') . '€</span>';
        $table_html .= '<span class=displayspan style="width: 9%; text-align: right;">' . ($entry->{credit} || '') . '€</span>';
        $table_html .= '<span class=displayspan style="width: 1%;">&nbsp;</span>';
        $table_html .= '<div class=spacer></div></div></li>';
    }

    $table_html .= '</ul>';

    return $table_html;
}

#Base::Site::util::generer_tableau($r, 'Journal d\'OD', [
#    [455, 'Associé Compte courant', 'INTERET CCA 202*', '', 'Montant net (60€)'],
#    [4425, 'État – Impôts et taxes', 'INTERET CCA 202*', '', 'Part impôts (30€)'],
#    [6615, 'Intérêt des comptes courants', 'INTERET CCA 202*', 'Montant brut des intérêts (90€)', ''],
#]);
sub generer_tableau {
    my ($type_journal, $donnees) = @_;  # Obtenir les paramètres de la fonction

    my $resultat = '<div class="wrappertable"><div class="table"><div class="caption">' . $type_journal . '</div>';
    $resultat .= '<div class="row header"><div class="cell" style="width:7%">Comptes</div><div class="cell" style="width:25%">Intitulé</div><div class="cell" style="width:43%">Libellé</div><div class="cell" style="width:10%">Débit</div><div class="cell" style="width:10%">Crédit</div></div>';

    # Générer les lignes du tableau à partir des données
    for my $row (@$donnees) {
        $resultat .= '<div class="row">';
        for my $cell (@$row) {
            $resultat .= '<div class="cell" data-title="Comptes">' . $cell . '</div>';
        }
        $resultat .= '</div>';
    }

    $resultat .= '</div></div>';  # Fermer les balises de fermeture du tableau

    return $resultat;
}

#my $form_html_result = Base::Site::util::generate_form_html($r, $args, @champs);
#my @champs = (["input/select", "LibelléLabel", "inputname", "flex-10", "respinput", "resplabel", "text", "options", "$numero_piece"],...);
sub generate_form_html {
    my ($r, $args, @champs) = @_;

    my $form_html = '';
    
    	foreach my $champ (@champs) {
		my ($type, $label, $name, $flex, $input_class, $label_class, $input_type, $options, $default_value) = @$champ;
		my $valeur = defined $args->{$name} ? $args->{$name} : (defined $default_value ? $default_value : "");

		if ($type eq "select") {
			$form_html .= qq{
				<div class="$flex">
					<label class="$label_class" for="$name">$label</label>
					$default_value
				</div>
			};
		} else {
			$form_html .= qq{
				<div class="$flex">
					<label class="$label_class" for="$name">$label</label>
					<input class="$input_class" type="$input_type" id="$name" name="$name" value="$valeur" $options/>
				</div>
			};
		}
	}

	return $form_html;
}

#Base::Site::util::number_to_fr
sub number_to_fr {
    my ($number, $currency_symbol, $decim) = @_;
    my @fr_string = ();
    my ($centimes, $fin) = (undef, undef);
    $currency_symbol //= '';
    
    $number =~ s/\s//g;
	
	if (defined $decim && $decim eq 1 && $currency_symbol eq '€') {
		if ($number == 1) {
			$fin = 'centime';
		} else {
			$fin = 'centimes';
		}
	} elsif ((defined $decim && $decim eq 0 || !$decim ) && $currency_symbol eq '€'){
		if ($number == 1) {
			$fin = 'euro';
		} else {
			$fin = 'euros';
		}
	}
	
    #Base::Site::logs::logEntry("#### INFO ####", 'Raf', 'util.pm => Montant à traiter number 1 '.$number.'');
    
    $number ||= '0.00';
    $number =~ s/,/./;

    # Test if $number is really a number, or return undef, from perldoc
    # -q numbers
    $number =~ s/_//g; # Allow for '_' separating figures
    if ( $number !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ ) {
        warn("Invalid number format: '$number'");
        return;
    }

    if ( $number > ( 1e75 - 1 ) ) {
        warn("Number '$number' too big to be represented as string");
        return;
    }
   
    return $NUMBER_NAMES{0} if $number == 0;
    
    # Add the 'minus' string if the number is negative.
  
    if ($number < 0) {
    push @fr_string, 'moins';
    $number = abs $number;
	}

    # We deal with decimal numbers by calling number2fr twice, once for
    # the integer part, and once for the decimal part.
    if ( $number != int $number ) {

        # XXX Ugly Hack.
        ( my $decimal ) = $number =~ /\.(\d+)/;
        
        push @fr_string, number_to_fr( int $number, $currency_symbol ), 'virgule';

        # Decimal numbers are correctly interpreted
        # https://github.com/sebthebert/Lingua-FR-Numbers/commit/89b717da8950d183488c6d93c7d5e638628ef13f
        
        if ( $decimal =~ s/^(0+([1-9][0-9]*))$/$2/ ) {
            my $decimal_power = 10**length $1;
            last unless $decimal_power;
            my $fr_decimal;
            $fr_decimal = number_to_fr($decimal, $currency_symbol, 1) . '';
            #$fr_decimal .= ordinate_to_fr($decimal_power, $currency_symbol, 1);
            #$fr_decimal .= 's' if $decimal > 1;
            push @fr_string, $fr_decimal;
        } else {
            push @fr_string, number_to_fr($decimal, $currency_symbol, 1)  ;
        }
        return join ( ' ', @fr_string );
    } 

    # First, we split the number by 1000 blocks
    # i.e:
    #   $block[0] => 0    .. 999      => centaines
    #   $block[1] => 1000 .. 999_999  => milliers
    #   $block[2] => 1e6  .. 999_999_999 => millions
    #   $block[3] => 1e9  .. 1e12-1      => milliards
    my @blocks;
    while ($number) {
        push @blocks, $number % 1000;
        $number = int $number / 1000;
    }
    @blocks = reverse @blocks;

    # We then go through each block, starting from the greatest
    # (..., billions, millions, thousands)
    foreach ( 0 .. $#blocks ) {

        # No need to spell numbers like 'zero million'
        next if $blocks[$_] == 0;

        my $number = $blocks[$_];

        # Determine the 'size' of the block
        my $power = 10**( ( $#blocks - $_ ) * 3 );
        my $hundred = int( $blocks[$_] / 100 );
        my $teens   = int( $blocks[$_] % 100 / 10 );
        my $units   = $blocks[$_] % 10;

        # Process hundred numbers 'inside' the block
        # (ie. 235 in 235000 when dealing with thousands.)

        # Hundreds
        if ($hundred) {
            my $fr_hundred;

            # We don't say 'un cent'
            $fr_hundred = $NUMBER_NAMES{$hundred} . ' '
              unless $hundred == 1;

            $fr_hundred .= $NUMBER_NAMES{100};

            # Cent prend un 's' quand il est multiplié par un autre
            # nombre et qu'il termine l'adjectif numéral.
            $fr_hundred .= 's'
              if ( $hundred > 1 && !$teens && !$units && $_ == $#blocks );

            push @fr_string, $fr_hundred;
        }

        # Process number below 100
        my $fr_decimal;

        # No tens
        $fr_decimal = $NUMBER_NAMES{$units}
          if ( $units && !$teens )
          &&    # On ne dit pas 'un mille' (A bit awkward to put here)
          !( $number == 1 && ( $power == 1000 ) );

        # Cas spécial pour les 80
        # On dit 'quatre-vingts' mais 'quatre-vingt-deux'
        if ( $teens == 8 ) {
            $fr_decimal = $units
              ? $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units}
              : $NUMBER_NAMES{ $teens * 10 } . 's';
        }

        # Cas spécial pour les nombres en 70 et 90
        elsif ( $teens == 7 || $teens == 9 ) {
            $units += 10;
            if ( $teens == 7 && $units == 11 ) {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . ' et ' . $NUMBER_NAMES{$units};
            }
            else {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units};
            }

        }

        # Un nombre s'écrit avec un trait d'union sauf s'il est associé
        # à 'cent' ou à 'mille'; ou s'il est relié par 'et'.
        # Nombres écrits avec des 'et': 21, 31, 51, 61, 71
        elsif ($teens) {
            if ( $teens == 1 ) {
                $fr_decimal = $NUMBER_NAMES{ $teens * 10 + $units };
            }
            elsif ( $units == 1 || $units == 11 ) {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . ' et ' . $NUMBER_NAMES{$units};
            }
            elsif ( $units == 0 ) {
                $fr_decimal = $NUMBER_NAMES{ $teens * 10 };
            }
            else {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units};
            }
        }
		
        push @fr_string, $fr_decimal if $fr_decimal ;

        # Processing thousands, millions, billions, ...
        if ( $power >= 1e3 ) {
            my $fr_power;

            if ( exists $NUMBER_NAMES{$power} ) {
                $fr_power = $NUMBER_NAMES{$power};

                # Billion, milliard, etc. prennent un 's' au pluriel
                $fr_power .= 's' if $number > 1 && $power >= 1e6;

                push @fr_string, $fr_power;
            }

            # If the power we're looking dealing with doesn't exists
            # (ie. 1e15, 1e21) we multiply by the lowest power we have,
            # starting at 1e6.
            else {
                my $sub_power;
                my $pow_diff = 1;
                do {
                    $pow_diff *= 1_000_000;
                    $sub_power = $power / $pow_diff;
                } until exists $NUMBER_NAMES{$sub_power};

                # If the power_diff doesn't exists (for really big
                # numbers), we do the same dance.
                unless ( exists $NUMBER_NAMES{$pow_diff} ) {

                }
                $fr_power = $NUMBER_NAMES{$pow_diff};
                $fr_power .= 's' if $number > 1;
                $fr_power .= " de $NUMBER_NAMES{$sub_power}s";

                # XXX Ugly hack - some architecture output "million de billion" instead of "trillion"
                $fr_power =~ s/million(s)? de billions?/trillion$1/g;

                push @fr_string, $fr_power;
            }
        }

        next;
    }

    return join ( ' ', @fr_string, $fin);
}

sub ordinate_to_fr {
    my ($number, $currency_symbol, $decim) = @_;

    unless ( $number > 0 ) {
        carp('Ordinates must be strictly positive');
        return;
    }
    return $ORDINALS{1} if $number == 1;

    my $ordinal    = number_to_fr($number, $currency_symbol);
    my $last_digit = $number % 10;

    if ( $last_digit != 1 && exists $ORDINALS{$last_digit} ) {
        my $replace = number_to_fr($last_digit, $currency_symbol);
        $ordinal =~ s/$replace$/$ORDINALS{$last_digit}/;
    }

    $ordinal =~ s/e?$/ième/;
    $ordinal =~ s/vingtsième/vingtième/;    # Bug #1772
    $ordinal;
}

sub delete_document {
    my ($r, $args, $dbh, $doc, $restart) = @_;
    my @errors;
     
    if (defined $doc && $doc ne '') {
        my $sql = 'DELETE FROM tbldocuments WHERE id_name = ? AND id_client = ?';
        my $rows_deleted;
        eval { $rows_deleted = $dbh->do($sql, {}, ($doc, $r->pnotes('session')->{id_client})) };

        # si une erreur est survenue ou aucun enregistrement n'a été supprimé, ne pas toucher au fichier
        if ($@ or !$rows_deleted) {
            if ($@ =~ /viole la contrainte|violates/) {
                push @errors, 'Impossible de supprimer le document, celui-ci est référencé sur une écriture';
            } else {
                push @errors, Encode::decode_utf8($@);
            }
        } else {
            # la suppression de la référence du document dans tbldocuments a réussi, supprimer le fichier
            my $base_dir = $r->document_root() . '/Compta/base/documents';
            my $archive_dir = $base_dir . '/' . $r->pnotes('session')->{id_client} . '/' . $r->pnotes('session')->{fiscal_year} . '/';

            my $archive_file = $archive_dir . $doc;
            # suppression du fichier
            unlink $archive_file;

            Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'util.pm => Suppression du document ' . $doc);
            # Redirection
            $args->{restart} = $restart || 'docs?docscategorie=' . ($args->{docscategorie} || '');
            Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
            return Apache2::Const::OK;  # Indique que le traitement est terminé
        }
    } else {
        push @errors, 'Impossible le nom du document n\'a pas été renseigné';
    }
    
	return join('; ', @errors) if @errors;
}

#Raccourci entre module note de frais et gestion immobilière
#my $disp_ndf = Base::Site::util::disp_lien_tag($args, $dbh, $r);
sub disp_lien_tag {
    my ($args, $dbh, $r, $compte) = @_;
    
    $compte ||= '';

    my $disp_ndf = '<ul class=main-nav3>';

    # Requête Gestion Immo BAIL tbldocuments_tags
    my $sql = '
        SELECT DISTINCT ON(t1.tags_nom) t1.tags_nom, t2.immo_archive  
        FROM tbldocuments_tags t1
        INNER JOIN tblimmobilier t2 ON t1.id_client = t2.id_client AND t1.tags_nom = t2.immo_contrat
        WHERE t1.tags_doc = ? OR t2.immo_compte = ?';
    my $result_immo_vail = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{id_name}, $compte);
    if ($result_immo_vail->[0]->{tags_nom}) {
        my $ndf_href = '/' . $r->pnotes('session')->{racine} . '/gestionimmobiliere?baux=3&code=' . ($result_immo_vail->[0]->{tags_nom} || '') . '&archive='.(($result_immo_vail->[0]->{immo_archive} eq 't') ? 1 : 0 ).'';
        $disp_ndf .= '<li><a class="label green" title="Voir le bail ' . ($result_immo_vail->[0]->{tags_nom} || '') . '" href="' . $ndf_href . '"> ' . $result_immo_vail->[0]->{tags_nom} . '</a></li>';
    }
    
	#Requête info NDF tblndf 
	$sql = '
	SELECT DISTINCT ON(t1.piece_entry) t1.piece_entry, t1.piece_ref, t1.id_client, t1.fiscal_year, t2.documents1
	FROM tblndf t1
	INNER JOIN tbljournal t2 ON t1.id_client = t2.id_client AND t1.piece_entry = t2.id_entry
	WHERE t2.id_entry=? OR t2.documents1= ?';
	my $result_ndf_entry = $dbh->selectall_arrayref( $sql, { Slice =>{ } }, $args->{id_entry}, $args->{id_name} ) ;
	if ($result_ndf_entry->[0]->{piece_ref}) {
		my $ndf_href = '/'.$r->pnotes('session')->{racine}.'/notesdefrais?piece_ref=' . ($result_ndf_entry->[0]->{piece_ref} || ''). '' ;
		$disp_ndf .= '<li class=style1><a class="label green" title="Voir la note de frais associée" href="'.$ndf_href.'"> '.$result_ndf_entry->[0]->{piece_ref}.'</a></li>'; 
	}

    # Requête info NDF frais en cours by id_name
    $sql = '
        SELECT DISTINCT ON(t1.piece_ref) t1.piece_ref, t1.frais_doc, t1.id_client, t1.fiscal_year
        FROM tblndf_detail t1
        INNER JOIN tbldocuments t2 ON t1.id_client = t2.id_client AND t1.frais_doc = t2.id_name
        WHERE t2.id_name=?';
    my $result_ndf_doc = $dbh->selectall_arrayref($sql, { Slice => {} }, $args->{id_name});
    for (@$result_ndf_doc) {
        my $ndf_href = '/' . $r->pnotes('session')->{racine} . '/notesdefrais?piece_ref=' . ($_->{piece_ref} || '') . '';
        $disp_ndf .= '<li><a class="label green" title="Voir la note de frais associée" href="' . $ndf_href . '"> ' . $_->{piece_ref} . '</a></li>';
    }
    
    $disp_ndf .= '</ul>';
    
    return $disp_ndf;
}

#my $sql_file = '/var/www/html/Compta/base/backup/maj_1.109.sql';
#my $rubrique_num = 1;
#if (Base::Site::util::import_sql_section($dbh, $r, $sql_file, $rubrique_num)) {
sub import_sql_section {
    my ($dbh, $r, $sql_file, $rubrique_num) = @_;

    # Tentative d'ouverture du fichier SQL en lecture
    open(my $fh, '<', $sql_file) or do {
        # En cas d'échec, journaliser l'erreur
        Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "util.pm => Impossible d'ouvrir le fichier '$sql_file' : $!");
        return 0;  # Retourner un échec
    };

    my $section_found = 0;  # Indicateur pour suivre si la section correspondante a été trouvée
    my $current_section = "";  # Initialisation du contenu de la section

    # Parcourir le fichier ligne par ligne
    while (my $line = <$fh>) {
        # Si la ligne correspond au début de la rubrique demandée
        if ($line =~ /^-- Rubrique $rubrique_num/) {
            $section_found = 1;  # Marquer que la rubrique a été trouvée
            next;  # Passer à la prochaine ligne sans inclure la ligne de titre
        }
        # Si la section correspondante a été trouvée et que la ligne n'est pas le début d'une autre rubrique
        elsif ($section_found && $line !~ /^-- Rubrique \d+/) {
            $current_section .= $line;  # Ajouter la ligne à la section courante
        }
        # Si la section correspondante a été trouvée et que la ligne est le début d'une autre rubrique
        elsif ($section_found && $line =~ /^-- Rubrique \d+/) {
            last;  # Arrêter la lecture du fichier
        }
    }

    close($fh);  # Fermer le fichier

    # Si la section correspondante a été trouvée
    if ($section_found) {
        eval { $dbh->do($current_section, undef) };
        if ($@) {
            # En cas d'erreur lors de l'exécution SQL, journaliser l'erreur
            Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "util.pm => Erreur lors de l'exécution SQL : $@");
            return 0;  # Retourner un échec
        } else {
            return 1;  # Retourner un succès
        }
    } else {
        # Si la rubrique demandée n'a pas été trouvée, journaliser l'erreur
        Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "util.pm => Rubrique $rubrique_num non trouvée dans le fichier '$sql_file'");
        return 0;  # Retourner un échec
    }
}

# Bloquer si l'exercice est clos
#return ($content .= Base::Site::util::bloquer_exercice_clos($r)) if Base::Site::util::bloquer_exercice_clos($r);
sub bloquer_exercice_clos {
    my ($r) = @_;
	
	my $message = '';

    if ($r->pnotes('session')->{Exercice_Cloture} eq '1') {
		$message .= Base::Site::util::generate_error_message(
		'*** Impossible d\'effectuer cette action car l\'exercice est clos ***
        <p>Pour accéder à la documentation, veuillez cliquer <a href="/'.$r->pnotes('session')->{racine}.'/">ici</a>:</p>
        </h3>');
    }

    return $message;
}


sub send_email {
    my ($r, $smtp_secu, $smtp_vers, $smtp_nom, $smtp_mail, $smtp_to, $smtp_Subject, $smtp_body, $smtp_server, $smtp_port, $smtp_user, $smtp_pass, $attachments) = @_;
	my $dbh = $r->pnotes('dbh') ;
	my $security_option = '';  # Option de sécurité SMTP
	my $tls_version_option = '';  # Option de version TLS/SSL
	
	# Décrypter le contenu HTML
    my $decode_body = Base::Site::util::decryptTextArea($smtp_body,"your_secret_key");
    my $decode_objet = Base::Site::util::decryptTextArea($smtp_Subject,"your_secret_key");
	my $decoded_html_content = decode_entities($decode_body);
	my $decoded_html_objet = decode_entities($decode_objet);
	
	my ($updated_html, $updated_decrypt_objet) = process_filename($r, '', $decoded_html_content, $decoded_html_objet);
		
	my $html = $updated_html ;
	my $decrypt_objet = $updated_decrypt_objet;
	
	# Définir le chemin du fichier temporaire
	my $temp_file_path = "/var/www/html/Compta/base/logs/mail_temp.html";

	# Ouvrir le fichier temporaire en écriture
	open(my $temp_file, ">:encoding(UTF-8)", $temp_file_path) or die "Impossible d'ouvrir le fichier temporaire : $!";

	# Écrire le contenu HTML dans le fichier temporaire
	print $temp_file $html;

	# Fermer le fichier temporaire
	close $temp_file;

	my $from = '"'.$smtp_nom.'" <'.$smtp_mail.'>';  # Définition de l'adresse e-mail de l'expéditeur 

	# Construction de l'option de sécurité SMTP
	if ($smtp_secu eq 'tls') {
		$security_option = '-tls';
	} elsif ($smtp_secu eq 'ssl') {
		$security_option = '-tlsc';
	}
	
	# Détermination automatique de l'option de sécurité en fonction du port
	if ($smtp_port == 587) {
		$security_option = '-tls';  # Si le port est 587, utilisez TLS
	} elsif ($smtp_port == 465) {
		$security_option = '-tlsc';  # Si le port est 465, utilisez SSL
		# Construction de l'option de version TLS/SSL
		if ($smtp_vers eq '1.2') {
			$tls_version_option = '--tls-protocol tlsv1_2';
		} elsif ($smtp_vers eq '1.3') {
			$tls_version_option = '--tls-protocol tlsv1_3';
		}
	}
	
	# Récupérer les pièces jointes à partir des arguments
    my @attachments = @$attachments;
    
    # Encodage du sujet en MIME-Q pour le rendre compatible avec tous les clients de messagerie
	my $subject_encoded = encode('MIME-Q', $decrypt_objet);  

	# Construire la commande swaks
	my $command = "swaks --to '$smtp_to' --h-From '$from' --header \"Subject: $subject_encoded\" ";

	# Exécute la commande swaks avec les paramètres fournis
    #my $command = "swaks --to $smtp_to --h-From '$from' --header \"Subject: $decrypt_objet\" ";
    #$command .= "--attach-type text/html --attach-body \@$temp_file_path ";  # Corps de l'email en HTML depuis le fichier temporaire
	$command .= "--body \@$temp_file_path --header \"Content-Type: text/html; charset=UTF-8\" ";

    foreach my $attachment (@attachments) {
		#Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, 'util.pm => $attachment' . $attachment .' ');
		my $info_doc = Base::Site::bdd::get_info_doc($dbh, $r->pnotes('session')->{id_client}, $attachment);
		my $link_doc = '/var/www/html/Compta/base/documents/' . $r->pnotes('session')->{id_client}.'/'.$info_doc->{fiscal_year} .'/'.$info_doc->{id_name}.'';
		#if ($info_doc) {my $doc_name = $info_doc->{id_name}; my $doc_fiscal = $info_doc->{fiscal_year}; }
		#my $fileattach = '/var/www/html/Compta/images/pdf/print.pdf';
        if (-e $link_doc) {  # Vérifie si le fichier existe
			my $filename = $info_doc->{id_name};  # Nom du fichier réel
			$command .= "--attach \"$link_doc\" --attach-name \"$filename\" --attach-type application/pdf ";
		}
		#$command .= "--attach $link_doc ";
    }

    $command .= "-s $smtp_server:$smtp_port $security_option $tls_version_option ";
    $command .= "-au $smtp_user -ap $smtp_pass ";
    # Ajoute l'option pour spécifier que le corps de l'email est du HTML
    #$command .= '--add-header "MIME-Version: 1.0" --add-header "Content-Type: text/html; charset=UTF-8"';

	# Exécute la commande swaks avec les paramètres fournis
    #my $command = "swaks --to $smtp_to --h-From '$from' --header \"Subject: $smtp_Subject\" --body \@/$temp_file_path  ";

    #$command .= "--attach $attachment " if $attachment;  # Ajout de la pièce jointe si elle est spécifiée
    #$command .= "-s $smtp_server:$smtp_port $security_option $tls_version_option -au $smtp_user -ap $smtp_pass";

     # Ajouter un journal pour voir la commande exécutée
    #Base::Site::logs::logEntry("DEBUG", $r->pnotes('session')->{username}, "util.pm => Command: $command");

    my $pid = fork();
    if (not defined $pid) {
        Base::Site::logs::logEntry("ERROR", $r->pnotes('session')->{username}, "Impossible de créer un processus fils via fork : $!");
        return;
    }

    my $id_client = $r->pnotes('session')->{id_client};

    if ($pid) {
		Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "L'e-mail est en cours d'envoi à $smtp_to.");
        return 1;  # E-mail en cours d'envoi
    } else {
        # Processus fils : rétablir la connexion DBI et exécuter la commande swaks
        my ($db_name) = $r->dir_config('db_name');
        my ($db_host) = $r->dir_config('db_host');
        my ($db_user) = $r->dir_config('db_user');
        my ($db_mdp) = $r->dir_config('db_mdp');
        my $dbh_child = Compta::db_handle::get_dbh_new($db_name, $db_host, $db_user, $db_mdp);
        
        # Check if DB connection is valid
        if (!$dbh_child || !$dbh_child->ping) {
            Base::Site::logs::logEntry("#### CRITIQUE ####", $r->pnotes('session')->{username}, "Failed to create or ping DB connection in child process.");
            exit(1);
        }

        my $output = `$command 2>&1`;

        if ($? == 0) {
            Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "L'e-mail a été envoyé avec succès à $smtp_to.");
            foreach my $attachment (@attachments) {
                my $event_type = 'Envoi par Email';
                my $event_description = "L'e-mail a été envoyé avec succès à $smtp_to";
                my $user_name = $r->pnotes('session')->{username};
                my $save_document_history = Base::Site::bdd::save_document_history($dbh_child, $id_client, $attachment, $event_type, $event_description, $user_name);
                if ($save_document_history && $save_document_history ne '') {
                    Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "Erreur lors de l'enregistrement de l'historique après succès: $save_document_history");
                }
            }
			$dbh_child->disconnect if $dbh_child; # Fermeture de la connexion DBI dans le processus fils
            exit(0);
        } else {
            my $message_erreur = '';
            if ($output =~ /553-5.1.3 (.+)/) {
                $message_erreur .= " => Adresse e-mail mal formatée";
            } elsif ($output =~ /535-5.7.8 (.+)/) {
                $message_erreur .= " => Échec de l'authentification";
            } elsif ($output =~ /550-5.1.1 (.+)/) {
                $message_erreur .= " => L'adresse e-mail destinataire n'existe pas";
            } elsif ($output =~ /554-5.7.1 (.+)/) {
                $message_erreur .= " => Transaction non autorisée ou blocage par le serveur";
            } elsif ($output =~ /421-4.7.0 (.+)/) {
                $message_erreur .= " => Tentative de livraison ultérieure (Service temporairement indisponible)";
            } else {
                $message_erreur .= " => Erreur inconnue";
            }
            Base::Site::logs::logEntry("ERROR", $r->pnotes('session')->{username}, "Erreur lors de l'envoi de l'e-mail: $message_erreur. Sortie: $output");

            foreach my $attachment (@attachments) {
                my $event_type = 'Échec d\'envoi par Email';
                my $event_description = "Échec de l'envoi de l'e-mail à $smtp_to.";
                my $save_document_history = Base::Site::bdd::save_document_history($dbh_child, $id_client, $attachment, $event_type, $event_description, $r->pnotes('session')->{username});
                if ($save_document_history && $save_document_history ne '') {
                    Base::Site::logs::logEntry("#### WARNING ####", $r->pnotes('session')->{username}, "Erreur lors de l'enregistrement de l'historique après échec: $save_document_history");
                }
            }
            $dbh_child->disconnect if $dbh_child; # Fermeture de la connexion DBI dans le processus fils
            exit(1);
        }
    }
}

# Appeler la fonction verify_and_delete_document
#my $content .= Base::Site::util::verify_and_delete_document($dbh, $r, $args);
sub verify_and_delete_document {
    my ($dbh, $r, $args, $check_tags, $restart) = @_;

    # Récupérer les informations nécessaires
    my $id_client = $r->pnotes('session')->{id_client};
    my $id_name = $args->{id_name};
    
    # Requête tbldocuments => Recherche si le document existe dans une écriture
    my $sql_journal = 'SELECT id_entry, libelle_journal 
                       FROM tbljournal 
                       WHERE id_client = ? AND (documents1 = ? OR documents2 = ?) 
                       GROUP BY id_entry, libelle_journal';
    my $verify_entry_doc = $dbh->selectall_arrayref($sql_journal, { Slice => {} }, 
        $id_client, $id_name, $id_name);

    # Requête tblndf_detail => Recherche si le document existe dans une note de frais
    my $sql_ndf = 'SELECT frais_doc, piece_ref 
                   FROM tblndf_detail 
                   WHERE id_client = ? AND frais_doc = ? 
                   GROUP BY frais_doc, piece_ref';
    my $verify_ndf_doc = $dbh->selectall_arrayref($sql_ndf, { Slice => {} }, 
        $id_client, $id_name);

    # Vérification optionnelle des tags
    my $verify_tag_doc = [];
    if ($check_tags) {
        my $sql_tag = 'SELECT tags_doc, tags_nom 
                       FROM tbldocuments_tags 
                       WHERE id_client = ? AND tags_doc = ? 
                       GROUP BY tags_doc, tags_nom';
        $verify_tag_doc = $dbh->selectall_arrayref($sql_tag, { Slice => {} }, 
            $id_client, $id_name);
    }

    my $content = '';

    # Empêcher id_name vide ou inexistant
    if (@{$verify_entry_doc} || @{$verify_ndf_doc} || @{$verify_tag_doc}) {
        $content .= '<div class="warning" style="font-size: 1.17em; font-weight: bold; text-align: center;">';
        $content .= 'Impossible de supprimer le document, celui-ci est référencé :<br>';

        if (@{$verify_entry_doc}) {
            $content .= '<br>Écritures concernées : ';
            foreach my $entry (@{$verify_entry_doc}) {
                my $libelle_journal = $entry->{libelle_journal} // 'N/A';
                my $id_entry = $entry->{id_entry} // 'N/A';
                $content .= '<a class="nav" href="entry?open_journal=' . URI::Escape::uri_escape_utf8($libelle_journal) . '&id_entry=' . $id_entry . '">' . $id_entry . '</a> ';
            }
        }

        if (@{$verify_ndf_doc}) {
            $content .= '<br>Notes de frais concernées : ';
            foreach my $entry (@{$verify_ndf_doc}) {
                my $piece_ref = $entry->{piece_ref} // 'N/A';
                $content .= '<a class="nav" href="notesdefrais?piece_ref=' . URI::Escape::uri_escape_utf8($piece_ref) . '">' . $piece_ref . '</a> ';
            }
        }
        
        if (@{$verify_tag_doc}) {
            $content .= '<br>Tags concernés : ';
            foreach my $entry (@{$verify_tag_doc}) {
                my $tag_ref = $entry->{tags_nom} // 'N/A';
                $content .= '<a class="nav" href="docs?tags=' . URI::Escape::uri_escape_utf8($tag_ref) . '">' . $tag_ref . '</a> ';
            }
        }

        $content .= '</div>';
    } else {
        my $sql_delete = 'DELETE FROM tbldocuments WHERE id_name = ? AND id_client = ?';
        my $rows_deleted;
        eval {
            $rows_deleted = $dbh->do($sql_delete, {}, $id_name, $id_client);
        };

        # Si un problème est survenu ou aucun enregistrement n'a été supprimé, ne pas toucher au fichier
        if ($@ or !$rows_deleted) {
            if ($@ =~ /viole la contrainte|violates/) {
                $content .= Base::Site::util::generate_error_message('Impossible de supprimer le document, celui-ci est référencé sur une écriture');
            } else {
                $content .= Base::Site::util::generate_error_message(Encode::decode_utf8($@));
            }
        } else {
            # La suppression de la référence du document dans tbldocuments a réussi, supprimer le fichier
            my $base_dir = $r->document_root() . '/Compta/base/documents';
            my $archive_dir = $base_dir . '/' . $id_client . '/' . $r->pnotes('session')->{fiscal_year} . '/';
            my $archive_file = $archive_dir . $id_name;

            # Suppression du fichier
            unlink $archive_file;

            Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, "doc.pm => Suppression du document $id_name");
            
            # Redirection
            $args->{restart} = $restart || 'docs?docscategorie=' . ($args->{docscategorie} || '');
            Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
            return Apache2::Const::OK;  # Indique que le traitement est terminé
        }
    }

    return $content;
}

#Base::Site::util::to_json($array_of_documents);
sub to_json {
    my ($array_ref) = @_;
    my $json = '[';
    foreach my $doc (@$array_ref) {
        my $escaped_id_name = encode_entities($doc->{id_name});
        $json .= '{';
        $json .= '"id_name":"' . $escaped_id_name . '"';
        $json .= '},';
    }
    # Remove trailing comma and close the array
    $json =~ s/,$//;
    $json .= ']';
    return $json;
}

sub form_email {
	
	# définition des variables
    my ( $r, $args ) = @_ ;
    my $dbh = $r->pnotes('dbh') ;
    my ( $sql, $option_set, @bind_array, $content, $document_select1) ;
    my $statut= '';
    
    #Fonction pour générer le débogage des variables $args et $r->args 
	if ($r->pnotes('session')->{dump} == 1) {$content .= Base::Site::util::debug_args($args, $r->args);}
	
    # Génération du formulaire de choix de documents.
    my $reqid = Base::Site::util::generate_reqline();
    my $array_of_documents = Base::Site::bdd::get_documents($dbh, $r->pnotes('session')->{id_client}, $r->pnotes('session')->{fiscal_year});
	
    if (defined $args->{select_modele_name} && $args->{select_modele_name} ne '' && $args->{email} ne '3' && $args->{email} ne '2' && $args->{email} ne '7') {
		my $verif_email_body_mail = Base::Site::bdd::get_template($dbh, $r, $args->{select_modele_name}, 'email_body');
		my $verif_email_objet_mail = Base::Site::bdd::get_template($dbh, $r, $args->{select_modele_name}, 'email_objet');
		$args->{encrypted_body} = $verif_email_body_mail->[0]->{template_content} ;
		$args->{encrypted_objet} = $verif_email_objet_mail->[0]->{template_content} ;
		$args->{modele_name} = $verif_email_body_mail->[0]->{template_name} ;
	} elsif (defined $args->{select_modele_name} && $args->{select_modele_name} eq '' && $args->{email} ne '3' && $args->{email} ne '2' && $args->{email} ne '7') {
		$args->{encrypted_body} = undef;
		$args->{encrypted_objet} = undef;
		$args->{modele_name} = undef;
	}
	
    # Encode array_of_documents en JSON manuellement
    my $json_documents = Base::Site::util::to_json($array_of_documents);

	 # Décrypter le contenu HTML
    my $html = $args->{encrypted_body} ? Base::Site::util::decryptTextArea($args->{encrypted_body},"your_secret_key") : '';
	my $decrypt_objet = $args->{encrypted_objet} ? Base::Site::util::decryptTextArea($args->{encrypted_objet},"your_secret_key") : '';
	
	if (defined $args->{code} && $args->{code} ne '') {
		my $email_info = Base::Site::bdd::get_locataires_info($dbh, $r, $args->{code});
		
		if (!$args->{to}) {
			$args->{to} = $email_info->{locataires_courriel};
		}
		my $villa;
		my $annee = $r->pnotes('session')->{fiscal_year};
		
		if (defined $email_info->{biens_nom} && $email_info->{biens_nom} ne '') {
			$villa = $email_info->{biens_nom};
		}
            
        # Remplacement dynamique dans le HTML
        if (defined $villa) {
            $html =~ s/<span class="dynamic-value" data-marker="NOMDUBIEN" [^>]*><span class="dynamic-text">\{\{NOMDUBIEN\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$villa/g;
            $decrypt_objet =~ s/<span class="dynamic-value" data-marker="NOMDUBIEN" [^>]*><span class="dynamic-text">\{\{NOMDUBIEN\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$villa/g;
        }
        if (defined $annee) {
            $html =~ s/<span class="dynamic-value" data-marker="ANNEEAAAA" [^>]*><span class="dynamic-text">\{\{ANNEEAAAA\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$annee/g;
            $decrypt_objet =~ s/<span class="dynamic-value" data-marker="ANNEEAAAA" [^>]*><span class="dynamic-text">\{\{ANNEEAAAA\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$annee/g;
        }
		
	}
	
	if (defined $args->{id_name} && $args->{id_name} ne '' && !defined $args->{docs1}) {

		my $onchange1 = "onchange=\"if(this.selectedIndex == 0){document.location.href=\'docs?nouveau\'};\"";
		my $selected1 = (defined($args->{id_name})) ? ($args->{id_name}) : undef;
		my ($form_name1, $form_id1) = ('docs_100', 'docs_100');
		$document_select1 .='<div>';
		$document_select1 .= Base::Site::util::generate_document_selector($array_of_documents, $reqid, $selected1, $form_name1, $form_id1, $onchange1, 'class="forms2_input"', 'style ="width : 50%;"');
		$document_select1 .='<button type="button" class="btnform2 delete-tag" onclick="removeDocumentSelector(this)">Supprimer</button></div>';
		
		my $email = Base::Site::bdd::get_locataires_courriel($dbh, $r, $args->{id_name});
		
		if (!$args->{to}) {
			if (defined $email->{locataires_courriel} && $email->{locataires_courriel} ne '') {
				$args->{to} = $email->{locataires_courriel};
			}
		}
		
		if ($html eq '') {
			
			my $locataires_contrat = '';
			
			if (defined $email->{locataires_contrat} && $email->{locataires_contrat} ne '') {
				$locataires_contrat = $email->{locataires_contrat};
			}
			my ($updated_html, $updated_decrypt_objet) = process_filename($r, $args->{id_name}, $html, $decrypt_objet, $locataires_contrat);
			
			$html = $updated_html;
			$decrypt_objet = $updated_decrypt_objet;
		}
		
		my $get_last_email_event_date = Base::Site::bdd::get_last_email_event_date($dbh, $r, $args->{id_name});
		
		if ($get_last_email_event_date){
			my $event_description = $get_last_email_event_date->{event_description};
			my $event_date = $get_last_email_event_date->{event_date};
			$statut = '<span class="memoinfo">'.$event_description.' le '.$event_date.'</span>';
		}
			
	}

	#/************ ACTION DEBUT *************/

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton envoyer						  #
	#######################################################################
    if ( defined $args->{email} && $args->{email} eq '2' ) {
		
		my $smtp_temp = Base::Site::bdd::get_email_smtp($dbh, $r, $args);
		
		my $smtp_server = $smtp_temp->[0]->{smtp_serveur} || '';
		my $smtp_nom = $smtp_temp->[0]->{smtp_nom} || '';
		my $smtp_mail = $smtp_temp->[0]->{smtp_mail} || '';
		my $smtp_secu = $smtp_temp->[0]->{smtp_secu} || '';
		my $smtp_vers = $smtp_temp->[0]->{smtp_vers} || '';
		my $smtp_port = $smtp_temp->[0]->{smtp_port} || '';
		my $smtp_user = $smtp_temp->[0]->{smtp_user} || '';
		my $smtp_pass = $smtp_temp->[0]->{smtp_pass} || '';
		my $smtp_to = $args->{to} || '';
		my $smtp_From = $smtp_temp->[0]->{smtp_mail} || '';
		my $smtp_body = $args->{encrypted_body} || '';
		my $smtp_Subject = $args->{encrypted_objet} || '';

		# Récupérer les documents
		my $attachments = get_docs($args);

		my $result = Base::Site::util::send_email($r, $smtp_secu, $smtp_vers, $smtp_nom, $smtp_mail, $smtp_to, $smtp_Subject, $smtp_body, $smtp_server, $smtp_port, $smtp_user, $smtp_pass, $attachments);
		if ($result =~ /Échec/) {
			# Affiche le message d'erreur en cas d'échec d'envoi de l'e-mail
			$content .= Base::Site::util::generate_error_message($result);
		} else {
			# Autres traitements en cas de succès
			$content .= Base::Site::util::generate_error_message("L'e-mail est en cours d'envoi vers $smtp_to.");
		}

    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton enregistrer le modèle			  #
	#######################################################################
    } elsif ( defined $args->{email} && $args->{email} eq '3' ) {
		
		my $email_name = $args->{modele_name} || '';
		Base::Site::util::formatter_libelle(\$email_name);

		if (defined $email_name && $email_name ne ''){
			
			my $email_message = $args->{encrypted_body} || '';
			my $email_objet = $args->{encrypted_objet} || '';
			
			# Enregistrer le corps du message (email_body)
			my $save_email_template = Base::Site::bdd::save_template($dbh, $r, $email_name, $email_message, 'email_body');
			my $save_email_objet_template = Base::Site::bdd::save_template($dbh, $r, $email_name, $email_objet, 'email_objet');
			
			if ($save_email_template && $save_email_objet_template) {
				# Afficher un message d'erreur en cas d'échec
				$content .= Base::Site::util::generate_error_message($save_email_template);
			} else {
				# Déterminer si c'est une mise à jour ou un nouvel enregistrement
				my $message = ($args->{select_modele_name} eq $args->{modele_name}) ? 'mise à jour' : 'enregistré';
				$content .= Base::Site::util::generate_error_message("Le Modèle $email_name a été $message avec succès.");
			}

		} else {
			$content .= Base::Site::util::generate_error_message("Impossible le nom du modèle est vide");
		} 

	
    ####################################################################### 
	#l'utilisateur a cliqué sur le bouton supprimer le modèle			  #
	#######################################################################
    } elsif ( defined $args->{email} && $args->{email} eq '4' ) {
		
		my $email_name = $args->{modele_name} || '';
		Base::Site::util::formatter_libelle(\$email_name);
		
		if (defined $args->{modele_name} && $args->{modele_name} ne ''){

		#1ère demande de suppression; afficher lien d'annulation/confirmation
		my $non_href = '/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.'' ;
		my $oui_href = '/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.'=5&amp;modele_name=' . $args->{modele_name}.'' ;
		$content .= Base::Site::util::generate_error_message('Voulez-vous supprimer le modèle ' . $email_name . ' ?
		<br><a href="' . $oui_href . '" class=nav style="margin-left: 3ch;">Oui</a><a href="' . $non_href . '" class=nav style="margin-left: 3ch;">Non</a></h3>') ;
	} else {
			$content .= Base::Site::util::generate_error_message("Impossible un modèle n'a pas été sélectionné");
		} 
	
	} elsif ( defined $args->{email} && $args->{email} eq '5' ) {

	   if (defined $args->{modele_name} && $args->{modele_name} ne ''){
		   
			my $delete_email_body_template = Base::Site::bdd::delete_template($dbh, $r, $args->{modele_name}, 'email_body');
			my $delete_email_objet_template = Base::Site::bdd::delete_template($dbh, $r, $args->{modele_name}, 'email_objet');
			Base::Site::util::restart($r, $args);  # Appeler la fonction restart du module utilitaire
			return Apache2::Const::OK;  # Indique que le traitement est terminé

		} else {
			$content .= Base::Site::util::generate_error_message("Impossible un modèle n'a pas été sélectionné");
		} 
	
	####################################################################### 
	#l'utilisateur a cliqué sur le bouton Prévisualiser					  #
	#######################################################################	
	} elsif ( defined $args->{email} && $args->{email} eq '7' ) {
		
		my ($updated_html, $updated_decrypt_objet) = process_filename($r, $args->{id_name}, $html, $decrypt_objet);
		
		$html = $updated_html ;
		$decrypt_objet = $updated_decrypt_objet;
		
	}

	# Formulaire HTML sélection de modéle de mail
	my $info_modele_mail = Base::Site::bdd::get_template($dbh, $r, '', 'email_body');
	my $onchange_modele = 'onchange="this.form.submit()"';
	my $selected_mail = (defined($args->{modele_name}) && $args->{modele_name} ne '') ? ($args->{modele_name} ) : undef;
	my ($form_name_modele, $form_id_modele) = ('select_modele_name', 'select_modele_name_'.$reqid.'');
	my $search_modele_mail = Base::Site::util::generate_modele_mail($info_modele_mail, $reqid, $selected_mail, $form_name_modele, $form_id_modele, $onchange_modele, 'class="forms2_input"', 'style="width: 25%;"');

	$content .= '
	
	<link rel="stylesheet" href="/Compta/style/fontello/css/fontello.css">
	
	<div class="Titre10 centrer">Envoyer un email</div>
	'.$statut.'
	<div class="form-int">
		<form action=/'.$r->pnotes('session')->{racine}.'/'.$args->{restart}.' method=POST onsubmit="encryptTxtArea(\'editor\', \'encrypted_body\', \'objet\', \'encrypted_objet\');">
		<div class="flex-checkbox">
				'.$search_modele_mail.'
				<input style="width: 30%;" class="forms2_input " type="text" name="modele_name" id="modele_name" value="'.($args->{modele_name} || '') .'" placeholder="Nom du modèle" />
				<input type="submit" id="submit10" class="btn btn-orange" formaction="' . $args->{restart} . '=3" value="Enregistrer" title="Enregistrer le modèle" >
                <input type="submit" id="submit11" class="btn btn-rouge" formaction="' . $args->{restart} . '=4" value="Supprimer" title="Supprimer le modèle">
		</div>

        <hr class="mainPageTutoriel">
		
        <div class=flex-checkbox>
        <label style="width: 40%;" class="forms2_label" for="to">Destinataire :</label>
        </div>  
        
        <div class=flex-checkbox>
        <div class="forms2_label" >&nbsp;</div>
        <input class="forms2_input" style="width: 93%;" type="email" name="to" id="to" value="'.($args->{to} || '' ).'" />
        </div>    
        
        <div class=flex-checkbox>
        <div style="width: 60%;text-align: left;" class="forms2_label" >Objet :</div>
        </div>  
        
        <div class=flex-checkbox>
        <div id="objet" style="width: 93%; text-align: left;" class="forms_focus" contenteditable="true">' . ($decrypt_objet || '') . '</div>
        </div>   
        
        
        <div class=flex-checkbox>
        <div style="width: 100%;" class="forms2_label" >Message :</div>
        </div>   
        <br> 
        
        <div class="centrer" style="width: 93%; margin: 0 auto;">
            <div id="toolbar">
                <button type="button" data-command="bold"><i class="icon-bold"></i></button>
                <button type="button" data-command="italic"><i class="icon-italic"></i></button>
                <button type="button" data-command="underline"><i class="icon-underline"></i></button>
                <div id="colorPickerContainer">
                    <button type="button" onclick="toggleColorPicker()"><i class="icon-brush"></i></button>
                    <input type="color" id="colorPicker" onchange="changeTextColor(event)">
                </div>
                <button type="button" data-command="justifyLeft"><i class="icon-align-left"></i></button>
                <button type="button" data-command="justifyCenter"><i class="icon-align-center"></i></button>
                <button type="button" data-command="justifyRight"><i class="icon-align-right"></i></button>
                <button type="button" data-command="insertUnorderedList"><i class="icon-list-bullet"></i></button>
                <button type="button" data-command="insertOrderedList"><i class="icon-list-numbered"></i></button>
                <div class="select-container">
                    <select id="title" onchange="changeHeading(this.value)">
                        <option value="p">Normal</option>
                        <option value="h1">Titre 1</option>
                        <option value="h2">Titre 2</option>
                        <option value="h3">Titre 3</option>
                    </select>
                </div>
                  <div class="select-container">
                        <select id="dynamic-values" onchange="insertMarker()">
                            <option value="">Valeur dynamique</option>
                            <option value="NOMDUBIEN">Nom du bien</option>
                            <option value="MOISMM">Mois (format MM)</option>
                            <option value="ANNEEAAAA">Année (format AAAA)</option>
                            <option value="MOISLETTRE">Mois en toutes lettres</option>
                            <!-- Ajoutez d\'autres options ici -->
                        </select>
                    </div>
            </div>

            <div id="editor" class="forms_focus" contenteditable="true" style="border: 1px solid #ccc; padding: 10px; min-height: 200px;text-align: left;">' . ($html || '') . '</div>
            <input type="hidden" name="encrypted_body" id="encrypted_body">
            <input type="hidden" name="encrypted_objet" id="encrypted_objet">
            <input type="hidden" id="docCounter" name="docCounter" value="1">
        </div>
           
        <div class=flex-checkbox>
            <div style="width: 100%;" class="forms2_label">Liste des pièces jointes :</div>
        </div>   
            
            <div id="document_selectors"><br>
            '.($document_select1 || '').'
            
            </div>
            
            <br>
            
            <div class="formflexN2">
                <button class="btnform2 valid-tag" type="button" onclick="addDocumentSelector()">Ajouter une pièce jointe</button>
            </div>
            
            <div class="formflexN3">
                <input type="submit" id="submit9" style="width: 25%;" class="btn btn-vert" formaction="' . $args->{restart} . '=2" value="Envoyer le mail">
				<input type="submit" id="submit90" style="width: 25%;" class="btn btn-gris" formaction="' . $args->{restart} . '=7" value="Prévisualiser">
            
            </div>
            <br>
        </form>
        
        </div>

	';

	
	$content .= '
	<script>
	
	var array_of_documents = ' . $json_documents . ';
	var docCounter = 1;

	const toolbarButtons = document.querySelectorAll("#toolbar button");
	const colorPicker = document.getElementById("colorPicker");

	toolbarButtons.forEach(button => {
		button.addEventListener("click", () => {
			toggleActive(button);
			const command = button.dataset.command;
			const arg = button.dataset.arg;
			execCommand(command, arg);
		});
	});
	
	function isSelectionInsideEditor(editor, selection) {
		var node = selection.anchorNode;

		// Vérifier si le nœud d\'ancrage (anchorNode) est bien un enfant de l\'éditeur
		while (node) {
			if (node === editor) {
				return true;
			}
			node = node.parentNode;
		}
		return false;
	}
	
	document.getElementById("objet").addEventListener("paste", function(e) {
				// Empêcher l\'événement de collage par défaut
				e.preventDefault();

				// Récupérer le texte brut du presse-papier
				const text = (e.clipboardData || window.clipboardData).getData("text");

				// Insérer le texte brut dans la div
				document.execCommand("insertText", false, text);
	});
	
	function insertMarker() {
    var select = document.getElementById("dynamic-values");
    var marker = select.value;
    if (marker) {
        var editor = document.getElementById("editor");
        var objet = document.getElementById("objet");
        // Sélectionner tous les éléments dont l\'ID commence par "mot_"
        var mots = document.querySelectorAll(\'[id^="mot_"]\');
        var selection = window.getSelection();
        
        // Vérifier si la sélection est à l\'intérieur de l\'élément editor, objet ou un des éléments "mot_"
        var isInEditor = isSelectionInsideEditor(editor, selection);
        var isInObjet = isSelectionInsideEditor(objet, selection);
        var isInMot = Array.from(mots).some(mot => isSelectionInsideEditor(mot, selection));

        if (!isInEditor && !isInObjet && !isInMot) {
            alert("Veuillez placer le curseur dans la zone d\'édition, dans l\'objet, ou dans un mot_ pour insérer une valeur dynamique.");
            select.value = "";  // Réinitialiser le menu déroulant
            return;
        }

        var range = selection.getRangeAt(0);

        // Créer un conteneur pour la valeur dynamique avec une croix de suppression
        var span = document.createElement("span");
        span.className = "dynamic-value"; // Ajouter une classe pour le style CSS
        span.setAttribute("data-marker", marker); // Stocker la valeur du marker dans l\'attribut data
        span.innerHTML = `<span class="dynamic-text">{{${marker}}}</span><span class="delete-marker" onclick="deleteMarker(event)">×</span>`;

        // Style pour le span
        span.style.backgroundColor = "#c2e7ff";
        span.style.fontWeight = "bold";
        span.style.borderRadius = "3px";
        span.style.padding = "0 3px";

        // Rendre le span non éditable
        span.setAttribute("contenteditable", "false");

        range.deleteContents();
        range.insertNode(span);

        // Réinitialiser la sélection et la valeur du menu déroulant
        range.setStartAfter(span);
        range.setEndAfter(span);
        selection.removeAllRanges();
        selection.addRange(range);
        select.value = "";  // Réinitialiser le menu déroulant
    }
}

	function deleteMarker(event) {
		event.stopPropagation(); // Empêcher la propagation de l\'événement
		var markerElement = event.target.parentNode; // Récupérer le conteneur span.dynamic-value
		markerElement.parentNode.removeChild(markerElement); // Supprimer l\'élément
	}

	function execCommand(command, arg = null) {
		var selection = window.getSelection();
		var anchorNode = selection.anchorNode;

		// Fonction pour remonter dans les parents et récupérer la div parente avec un ID
		function getParentDivId(node) {
			while (node) {
				if (node.nodeType === 1 && node.tagName.toLowerCase() === \'div\' && node.id) {
					return node.id;
				}
				node = node.parentNode;
			}
			return null;
		}

		// Récupérer l\'ID de la div parente
		var parentDivId = getParentDivId(anchorNode);

		// Vérifier dans quel élément (editor ou objet) se trouve la sélection
		if (parentDivId === "editor") {

			if (command === "formatBlock") {
				document.execCommand("formatBlock", false, arg);
			} else {
				document.execCommand(command, false, arg);
			}

		} else if (parentDivId === "objet") {
			return;
		} else if (parentDivId.startsWith("mot_")) {
			return;
		}

	}

	function toggleActive(button) {
		button.classList.toggle("active");
	}

	function toggleColorPicker() {
		var editor = document.getElementById("editor");
		var selection = window.getSelection();

		// Vérifier si la sélection est à l\'intérieur de l\'éditeur
		if (isSelectionInsideEditor(editor, selection)) {
			colorPicker.click();
		}
	}

	function changeTextColor(event) {
		const color = event.target.value;
		var editor = document.getElementById("editor");
		var selection = window.getSelection();

		// Vérifier si la sélection est à l\'intérieur de l\'éditeur
		if (isSelectionInsideEditor(editor, selection)) {
			execCommand("foreColor", color);
		}
	}

	function changeHeading(heading) {
		var editor = document.getElementById("editor");
		var selection = window.getSelection();

		// Vérifier si la sélection est à l\'intérieur de l\'éditeur
		if (isSelectionInsideEditor(editor, selection)) {
			execCommand("formatBlock", heading);
		}
		
	}
		
	function addDocumentSelector() {
        var docSelectorsDiv = document.getElementById("document_selectors");
        var newSelect = generateDocumentSelector(array_of_documents, docCounter, "", "docs_" + docCounter, "docs_" + docCounter, "", "class=forms2_input", "style=\'width: 50%;\'");
        var deleteButton = \'<button type="button" class="btnform2 delete-tag" onclick="removeDocumentSelector(this)">Supprimer</button>\';
        docSelectorsDiv.insertAdjacentHTML("beforeend", "<div>" + newSelect + deleteButton + "</div>");
        docCounter++;
          
        // Mettre à jour le compteur de sélecteurs
		document.getElementById("docCounter").value = docCounter;
    }

    function removeDocumentSelector(button) {
        var docSelectorDiv = button.parentNode;
        docSelectorDiv.parentNode.removeChild(docSelectorDiv);
    }

    function generateDocumentSelector(array_of_documents, reqid, selected_document, form_name, form_id, onchange_type, class_attr, style_attr) {
        var options = array_of_documents.map(function(doc) {
			var selected = (doc.id_name === selected_document) ? "selected" : "";
            return "<option value=\'" + doc.id_name + "\' " + selected + ">" + doc.id_name + "</option>";
        }).join("");
        return "<select name=\'" + form_name + "\' id=\'" + form_id + "\' " + onchange_type + " " + class_attr + " " + style_attr + ">" + options + "</select>";
    }

  	function toggleConfigSections() {
		var configTypeSelect = document.getElementById("smtp_type");
		var smtpConfigSection = document.getElementById("smtp_config");
		var apiConfigSection = document.getElementById("api_config");

		if (configTypeSelect.value === "smtp") {
			smtpConfigSection.style.display = "block";
			apiConfigSection.style.display = "none";
		} else if (configTypeSelect.value === "api") {
			smtpConfigSection.style.display = "none";
			apiConfigSection.style.display = "block";
		}
	}

	</script>';

    return $content ;
    
} #sub form_email 

# Fonction de transformation de config_libelle en une regex utilisable
sub transform_libelle_to_regex {
    my ($config_libelle) = @_;

    # Pour MOISMM : on échappe également les accolades et on double les backslashes
    $config_libelle =~ s/<span class="dynamic-value" data-marker="MOISMM"[^>]*><span class="dynamic-text">\{\{MOISMM\}\}<\/span><span class="delete-marker"[^>]*>×<\/span><\/span>/(\\d{2})/g;

    # Pour ANNEEAAAA : idem, on échappe les accolades
    $config_libelle =~ s/<span class="dynamic-value" data-marker="ANNEEAAAA"[^>]*><span class="dynamic-text">\{\{ANNEEAAAA\}\}<\/span><span class="delete-marker"[^>]*>×<\/span><\/span>/(\\d{4})/g;
	
	return $config_libelle;
}

sub process_filename {
    my ($r, $filename, $html, $decrypt_objet, $code) = @_;
    my $dbh = $r->pnotes('dbh');

    my $filename_verify = $filename // '';
    
    my $code_verify = $code // '';

    # Requête pour récupérer les libellés configurés
    my $resultat = Base::Site::bdd::get_tblconfig_liste($dbh, $r, 'email');

    foreach my $item (@$resultat) {
        my $config_compte = $item->{config_compte};
        my $config_libelle = $item->{config_libelle};
        
        next unless $config_compte && $config_libelle;  # S'assurer que les valeurs existent

        # Déchiffrement du libellé
        my $decrypt_mot_temp = Base::Site::util::decryptTextArea($config_libelle, "your_secret_key");

        # Transformer le libellé en expression régulière
        my $regex_pattern = transform_libelle_to_regex($decrypt_mot_temp);
        
        #Base::Site::logs::logEntry("### ERROR ###", 'UTIL', 'process_filename 1: $regex_pattern ' . $regex_pattern .' et  filename_verify '.$filename_verify);
        
        # Tester si le filename correspond au modèle
        if ($filename_verify =~ /$regex_pattern/) {
			
			#Base::Site::logs::logEntry("### ERROR ###", 'UTIL', 'process_filename 2: $regex_pattern ' . $regex_pattern);
                
			
			if ($html eq '') { 
				
				my $verif_email_body_mail = Base::Site::bdd::get_template($dbh, $r, $config_compte, 'email_body');
				my $verif_email_objet_mail = Base::Site::bdd::get_template($dbh, $r, $config_compte, 'email_objet');
				my $encrypted_body = $verif_email_body_mail->[0]->{template_content} ;
				my $encrypted_objet = $verif_email_objet_mail->[0]->{template_content} ;
				my $modele_name = $verif_email_body_mail->[0]->{template_name} ;
				
				$html = Base::Site::util::decryptTextArea($encrypted_body,"your_secret_key");
				$decrypt_objet = Base::Site::util::decryptTextArea($encrypted_objet,"your_secret_key");

			}
			
            # Récupérer tous les groupes capturés dynamiquement
            my @captures = ($filename_verify =~ /$regex_pattern/);

            # Log si aucune capture n'a été faite
            unless (@captures) {
                Base::Site::logs::logEntry("### ERROR ###", 'UTIL', 'process_filename: Pas de captures pour le fichier ' . $filename_verify);
                next;
            }
            
            my $email_info = Base::Site::bdd::get_locataires_info($dbh, $r, $code_verify);
		
			# Variables pour stocker les captures spécifiques
            my ($villa, $mois);
		
			my $annee = $r->pnotes('session')->{fiscal_year};
		
			if (defined $email_info->{biens_nom} && $email_info->{biens_nom} ne '') {
				$villa = $email_info->{biens_nom};
			}

            # Identifier les captures selon leur format
            foreach my $capture (@captures) {
                if ($capture =~ /^\d{2}$/) {
                    # Si c'est un nombre à 2 chiffres, c'est probablement le mois
                    $mois = $capture;
                } elsif ($capture =~ /^\d{4}$/) {
                    # Si c'est un nombre à 4 chiffres, c'est probablement l'année
                    $annee = $capture;
                }
            }

            # Conversion du mois en lettres (seulement si $mois est défini)
            my $moislettre = '';
            if (defined $mois) {
                my %mois_en_lettres = (
                    '01' => 'de janvier', '02' => 'de février', '03' => 'de mars', '04' => 'd\'avril',
                    '05' => 'de mai', '06' => 'de juin', '07' => 'de juillet', '08' => 'd\'août',
                    '09' => 'de septembre', '10' => 'd\'octobre', '11' => 'de novembre', '12' => 'de décembre'
                );
                $moislettre = $mois_en_lettres{$mois} // '';
            }

            # Remplacement dynamique dans le HTML
            if (defined $villa) {
                $html =~ s/<span class="dynamic-value" data-marker="NOMDUBIEN" [^>]*><span class="dynamic-text">\{\{NOMDUBIEN\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$villa/g;
                $decrypt_objet =~ s/<span class="dynamic-value" data-marker="NOMDUBIEN" [^>]*><span class="dynamic-text">\{\{NOMDUBIEN\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$villa/g;
            }
            if (defined $mois) {
                $html =~ s/<span class="dynamic-value" data-marker="MOISMM" [^>]*><span class="dynamic-text">\{\{MOISMM\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$mois/g;
                $decrypt_objet =~ s/<span class="dynamic-value" data-marker="MOISMM" [^>]*><span class="dynamic-text">\{\{MOISMM\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$mois/g;

                # Remplacement du mois en lettres
                $html =~ s/<span class="dynamic-value" data-marker="MOISLETTRE" [^>]*><span class="dynamic-text">\{\{MOISLETTRE\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$moislettre/g;
                $decrypt_objet =~ s/<span class="dynamic-value" data-marker="MOISLETTRE" [^>]*><span class="dynamic-text">\{\{MOISLETTRE\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$moislettre/g;
            }
            if (defined $annee) {
                $html =~ s/<span class="dynamic-value" data-marker="ANNEEAAAA" [^>]*><span class="dynamic-text">\{\{ANNEEAAAA\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$annee/g;
                $decrypt_objet =~ s/<span class="dynamic-value" data-marker="ANNEEAAAA" [^>]*><span class="dynamic-text">\{\{ANNEEAAAA\}\}<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>/$annee/g;
            }
        }
    }
    
    # Nettoyage : Supprimer tous les spans restants
    $html =~ s/<span class="dynamic-value" [^>]*>.*?<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>//g;
    $decrypt_objet =~ s/<span class="dynamic-value" [^>]*>.*?<\/span><span class="delete-marker" [^>]*>×<\/span><\/span>//g;

    return ($html, $decrypt_objet);
}

sub get_docs {
    my $args = shift;
    my @docs;
    
    foreach my $key (keys %$args) {
        if ($key =~ /^docs_/ && $key ne 'docs_doc_entry') {
            push @docs, $args->{$key};
            #Base::Site::logs::logEntry("#### INFO ####", "Test", 'util.pm => $key "' . ($key || '') .'" et $args->{$key} "' . ($args->{$key}|| '') .'" ');
        }
    }
    
    return \@docs;
}

# Fonction pour ajouter des mois à une date donnée
sub add_months {
    my ($year, $month, $day, $months_to_add) = @_;
    
    $month += $months_to_add;
    while ($month > 12) {
        $month -= 12;
        $year++;
    }
    
    # Ajuste le jour si nécessaire (par exemple, si le mois ajouté n'a pas autant de jours)
    my $last_day_of_month = last_day_of_month($year, $month);
    if ($day > $last_day_of_month) {
        $day = $last_day_of_month;
    }

    return sprintf("%04d-%02d-%02d", $year, $month, $day);
}

# Fonction pour obtenir le dernier jour du mois
sub last_day_of_month {
    my ($year, $month) = @_;
    if ($month == 2) {
        return ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)) ? 29 : 28;  # Février bissextile
    } elsif ($month == 4 || $month == 6 || $month == 9 || $month == 11) {
        return 30;
    } else {
        return 31;
    }
}

# Fonction pour calculer le 2e jour ouvré suivant le 1er mai
sub calculate_second_working_day {
    my ($year, $month, $day) = @_;
    
    # Calcul du premier jour de Mai
    my $first_day_of_may = sprintf("%04d-%02d-%02d", $year, $month, $day);
    my ($y, $m, $d) = split /-/, $first_day_of_may;

    # Jour de la semaine du 1er mai (1=Dimanche, 2=Lundi, ..., 7=Samedi)
    my $dow = (localtime(time + ($y - 1900) * 365.25 * 86400 + ($m - 1) * 30.4375 * 86400 + $d * 86400))[6] + 1;
    $dow = 7 if $dow == 0;  # Localtime retourne 0 pour Dimanche, on le met à 7 pour simplifier

    # Calcul du 2e jour ouvré
    my $days_added = 0;
    my $second_working_day = $first_day_of_may;

    while ($days_added < 2) {
        # Si c'est un jour ouvré (Lundi-Vendredi), on incrémente
        if ($dow != 1 && $dow != 7) {
            $days_added++;
        }
        $dow = ($dow % 7) + 1;  # Passer au jour suivant
        $second_working_day = add_one_day($y, $m, $d);
        ($y, $m, $d) = split /-/, $second_working_day;
    }

    return $second_working_day;
}

# Fonction pour ajouter un jour à une date
sub add_one_day {
    my ($year, $month, $day) = @_;
    
    $day++;
    my $last_day = last_day_of_month($year, $month);
    if ($day > $last_day) {
        $day = 1;
        $month++;
        if ($month > 12) {
            $month = 1;
            $year++;
        }
    }
    
    return sprintf("%04d-%02d-%02d", $year, $month, $day);
}

#référence recherchée n\'existe pas
#$content .= Base::Site::util::ref_existe_pas($r); 
sub ref_existe_pas {
    my ($r) = @_;
	my $content = '
		<section class="wrapper centrer">
			<div class="four_zero_four_bg">
				<h1>OOPS!</h1>
			</div>
		
			<div class="contant_box_404">
				<h3 class="h2">La référence recherchée n\'existe pas</h3>
				<p>Pour accéder à la documentation cliquer ci-dessous!</p>
				<a href="/'.$r->pnotes('session')->{racine}.'/" class="link_404">Menu</a>
			</div>
		</section>' ;
		return $content ;
}
	
1;
