package Base::Service::EmailReceiver;
#-----------------------------------------------------------------------------------------
# Module de réception d'emails IMAP pour extraction automatique de factures
# 
# Utilité métier : Récupérer les factures PDF envoyées par email et les intégrer
# automatiquement dans le système comptable
# 
# Anti-duplicata : Vérifie dans tbldocuments si le fichier a déjà été importé
# Scan complet : Parcourt TOUS les emails (lus et non lus)
#-----------------------------------------------------------------------------------------

use strict;
use warnings;
use utf8;
use Encode;
use Net::IMAP::Simple;
use Net::IMAP::Simple::SSL;
use Email::MIME;
use Email::Address;
use File::Path 'mkpath';
use File::Basename;
use Time::Piece;
use Digest::MD5 qw(md5_hex);

#/*—————————————— Configuration IMAP ——————————————*/
# Récupère TOUS les emails avec pièces jointes PDF (lus et non lus, anti-duplicata)
sub fetch_invoice_emails {
    my ($config, $dbh) = @_;
    
    my %default_config = (
        server   => 'imap.gmail.com',
        port     => 993,
        username => '',
        password => '',
        ssl      => 1,
        folder   => 'INBOX',
    );
    
    # Fusion config
    $config = { %default_config, %$config };
    
    my @invoices;  # Tableau des factures trouvées
    
    # Connexion IMAP
    my $imap = connect_imap($config);
    return \@invoices unless $imap;
    
    # Récupérer la liste des documents déjà importés (anti-duplicata)
    my %already_imported;
    if ($dbh && $config->{client_id}) {
        my $sql = 'SELECT id_name FROM tbldocuments WHERE id_client = ? AND libelle_cat_doc = ?';
        my $rows = $dbh->selectcol_arrayref($sql, undef, $config->{client_id}, 'Facture_Email');
        %already_imported = map { $_ => 1 } @$rows if $rows;
    }
    
    # Sélection du dossier
    my $nb_messages = $imap->select($config->{folder});
    
    if ($nb_messages > 0) {
        # Parcourir TOUS les messages (lus et non lus)
        for my $msg_id (1 .. $nb_messages) {
            my $email_data = process_email($imap, $msg_id, $config);
            
            foreach my $attachment (@$email_data) {
                # Générer un identifiant unique basé sur le contenu (anti-duplicata)
                my $content_hash = md5_hex($attachment->{content});
                my $unique_id = $attachment->{date} . '_' . $content_hash . '_' . $attachment->{filename};
                $unique_id =~ s/[^a-zA-Z0-9._-]/_/g;
                
                # Vérifier si déjà importé
                next if $already_imported{$unique_id};
                
                # Stocker l'identifiant unique pour le nommage
                $attachment->{unique_id} = $unique_id;
                push @invoices, $attachment;
            }
        }
    }
    
    $imap->quit;
    
    return \@invoices;
}

#/*—————————————— Connexion IMAP ——————————————*/
sub connect_imap {
    my ($config) = @_;
    
    my $imap;
    
    if ($config->{ssl}) {
        $imap = Net::IMAP::Simple::SSL->new($config->{server}, port => $config->{port});
    } else {
        $imap = Net::IMAP::Simple->new($config->{server}, port => $config->{port});
    }
    
    unless ($imap) {
        warn "Impossible de se connecter au serveur IMAP: $config->{server}";
        return undef;
    }
    
    # Authentification
    unless ($imap->login($config->{username}, $config->{password})) {
        warn "Échec de l'authentification IMAP pour: $config->{username}";
        return undef;
    }
    
    return $imap;
}

#/*—————————————— Traitement d'un email ——————————————*/
sub process_email {
    my ($imap, $msg_id, $config) = @_;
    
    my @attachments;
    
    # Récupérer le contenu brut
    my $lines = $imap->get($msg_id);
    return \@attachments unless $lines;
    
    # Parser l'email
    my $email = Email::MIME->new(join('', @$lines));
    
    # Informations de l'email
    my $subject = decode_mime_header($email->header('Subject')) || '(Pas de sujet)';
    my $from    = decode_mime_header($email->header('From')) || '';
    my $date    = $email->header('Date') || '';
    
    # Extraire l'adresse email de l'expéditeur
    my @addresses = Email::Address->parse($from);
    my $sender_email = @addresses ? $addresses[0]->address : $from;
    
    # Parcourir les pièces jointes
    $email->walk_parts(sub {
        my ($part) = @_;
        
        # Vérifier si c'est une pièce jointe
        my $disposition = $part->header('Content-Disposition') || '';
        return unless $disposition =~ /attachment/i;
        
        # Récupérer le nom du fichier
        my $filename = $part->filename || '';
        return unless $filename;
        
        $filename = decode_mime_header($filename);
        
        # Ne garder que les PDF
        return unless $filename =~ /\.pdf$/i;
        
        # Vérifier si c'est une facture (nom ou contenu)
        return unless is_likely_invoice($filename, $subject);
        
        # Récupérer le contenu
        my $content = $part->body;
        
        push @attachments, {
            filename     => $filename,
            content      => $content,
            subject      => $subject,
            from         => $from,
            sender_email => $sender_email,
            date         => parse_email_date($date),
            size         => length($content),
        };
    });
    
    return \@attachments;
}

#/*—————————————— Détection si c'est une facture ——————————————*/
sub is_likely_invoice {
    my ($filename, $subject) = @_;
    
    my $text = lc($filename . ' ' . $subject);
    
    # Mots-clés facture
    my @invoice_keywords = qw(
        facture invoice rechnung factuur 
        billing bill payment paiement
    );
    
    foreach my $keyword (@invoice_keywords) {
        return 1 if $text =~ /\b$keyword\b/;
    }
    
    return 0;
}

#/*—————————————— Décodage MIME ——————————————*/
sub decode_mime_header {
    my ($header) = @_;
    return '' unless defined $header;
    
    # Décoder l'encodage MIME (ex: =?UTF-8?Q?...?=)
    $header =~ s/=\?([^?]+)\?(.)\?([^?]+)\?=/
        my ($charset, $encoding, $data) = ($1, $2, $3);
        if ($encoding eq 'Q') {
            $data =~ s/_/ /g;
            $data =~ s/=([0-9A-Fa-f]{2})/chr(hex($1))/ge;
        } elsif ($encoding eq 'B') {
            require MIME::Base64;
            $data = MIME::Base64::decode_base64($data);
        }
        Encode::decode($charset, $data);
    /ge;
    
    return $header;
}

#/*—————————————— Parsing date email ——————————————*/
sub parse_email_date {
    my ($date_str) = @_;
    
    return localtime->strftime('%Y-%m-%d') unless $date_str;
    
    # Format email standard: Wed, 15 Mar 2024 14:30:00 +0100
    if ($date_str =~ /(\d{1,2})\s+(\w{3})\s+(\d{4})/) {
        my %months = (
            'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4,
            'May' => 5, 'Jun' => 6, 'Jul' => 7, 'Aug' => 8,
            'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12
        );
        
        my $day = $1;
        my $month = $months{$2} || 1;
        my $year = $3;
        
        return sprintf('%04d-%02d-%02d', $year, $month, $day);
    }
    
    return localtime->strftime('%Y-%m-%d');
}

#/*—————————————— Stockage des pièces jointes ——————————————*/
sub save_email_attachment {
    my ($attachment, $storage_config) = @_;
    
    my $base_dir = $storage_config->{base_dir};
    my $client_id = $storage_config->{client_id};
    my $fiscal_year = $storage_config->{fiscal_year} || localtime->year;
    
    # Créer le répertoire de stockage
    my $archive_dir = "$base_dir/$client_id/$fiscal_year/";
    unless (-d $archive_dir) {
        mkpath($archive_dir) or die "Impossible de créer $archive_dir: $!";
    }
    
    # Utiliser l'identifiant unique comme nom de fichier (anti-duplicata)
    my $final_filename;
    if ($attachment->{unique_id}) {
        $final_filename = $attachment->{unique_id};
        # S'assurer que le fichier a une extension .pdf
        $final_filename .= '.pdf' unless $final_filename =~ /\.pdf$/i;
    } else {
        # Fallback: nettoyer le nom + timestamp
        my $filename = $attachment->{filename};
        $filename =~ s/[^a-zA-Z0-9._-]/_/g;
        my $timestamp = localtime->strftime('%Y%m%d_%H%M%S');
        $final_filename = $timestamp . '_' . $filename;
    }
    
    my $filepath = $archive_dir . $final_filename;
    
    # Écrire le fichier
    open(my $fh, '>:raw', $filepath) or die "Impossible d'écrire $filepath: $!";
    print $fh $attachment->{content};
    close($fh);
    
    return {
        filepath     => $filepath,
        filename     => $final_filename,
        original_name => $attachment->{filename},
        size         => $attachment->{size},
        sender       => $attachment->{sender_email},
        email_date   => $attachment->{date},
        subject      => $attachment->{subject},
    };
}

#/*—————————————— Intégration complète ——————————————*/
sub process_inbox_and_save {
    my ($imap_config, $storage_config, $dbh) = @_;
    
    # Passer client_id dans la config IMAP pour l'anti-duplicata
    $imap_config->{client_id} = $storage_config->{client_id};
    
    # Récupérer tous les exercices du client pour détecter le bon fiscal_year
    my $exercises = get_client_exercises($dbh, $storage_config->{client_id});
    
    # 1. Récupérer les factures depuis l'email (tous les emails, anti-duplicata via BDD)
    my $invoices = fetch_invoice_emails($imap_config, $dbh);
    
    my @saved_invoices;
    
    foreach my $invoice (@$invoices) {
        # Détecter le bon exercice fiscal selon la date de l'email/facture
        my $fiscal_year = detect_fiscal_year($invoice->{date}, $exercises, $storage_config->{fiscal_year});
        
        # Mettre à jour le storage_config avec le fiscal_year détecté pour ce document
        my $doc_storage_config = { %$storage_config, fiscal_year => $fiscal_year };
        
        # 2. Sauvegarder le fichier PDF dans le bon répertoire d'exercice
        my $file_info = save_email_attachment($invoice, $doc_storage_config);
        $file_info->{fiscal_year} = $fiscal_year;
        
        # 3. Insérer dans la base de données tbldocuments avec le bon fiscal_year
        if ($dbh && $file_info) {
            my $doc_id = insert_document_db($dbh, $file_info, $doc_storage_config);
            $file_info->{document_id} = $doc_id if $doc_id;
        }
        
        push @saved_invoices, $file_info;
    }
    
    return \@saved_invoices;
}

#/*—————————————— Insertion Base de Données ——————————————*/
sub insert_document_db {
    my ($dbh, $file_info, $config) = @_;
    
    my $sql = qq{
        INSERT INTO tbldocuments 
        (id_client, id_name, fiscal_year, libelle_cat_doc, date_reception, date_upload, id_compte, email_source)
        VALUES (?, ?, ?, ?, ?, CURRENT_DATE, ?, ?)
        ON CONFLICT (id_client, id_name) DO NOTHING
        RETURNING id_name
    };
    
    my $sth = $dbh->prepare($sql);
    my $result = eval {
        $sth->execute(
            $config->{client_id},
            $file_info->{filename},
            $config->{fiscal_year},
            'Facture_Email',  # Catégorie
            $file_info->{email_date},
            $config->{default_account} || '',
            $file_info->{sender}
        );
    };
    
    if ($@) {
        warn "Erreur insertion document: $@";
        return undef;
    }
    
    my $row = $sth->fetchrow_hashref;
    return $row ? $row->{id_name} : undef;
}

#/*—————————————— Récupération des exercices d'un client ——————————————*/
# Récupère tous les exercices fiscaux d'un client pour détecter le bon
sub get_client_exercises {
    my ($dbh, $client_id) = @_;
    
    return [] unless $dbh && $client_id;
    
    # Récupérer les exercices depuis la table des documents/journaux
    # On prend les fiscal_year distincts avec les dates min/max des écritures
    my $sql = q{
        SELECT 
            fiscal_year,
            MIN(date_ecriture) as debut_exercice,
            MAX(date_ecriture) as fin_exercice
        FROM tbljournal 
        WHERE id_client = ? AND date_ecriture IS NOT NULL
        GROUP BY fiscal_year
        ORDER BY fiscal_year DESC
    };
    
    my $exercises = eval {
        $dbh->selectall_arrayref($sql, { Slice => {} }, $client_id)
    };
    
    if ($@ || !$exercises || !@$exercises) {
        # Fallback: créer un exercice par défaut basé sur l'année courante
        my $current_year = localtime->year;
        return [{
            fiscal_year => $current_year,
            debut_exercice => "$current_year-01-01",
            fin_exercice => "$current_year-12-31"
        }];
    }
    
    return $exercises;
}

#/*—————————————— Détection de l'exercice selon la date ——————————————*/
# Trouve le fiscal_year approprié pour une date donnée
sub detect_fiscal_year {
    my ($date_str, $exercises, $default_year) = @_;
    
    return $default_year unless $date_str && $exercises && @$exercises;
    
    # Parser la date (format: YYYY-MM-DD)
    my ($year, $month, $day);
    if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
        ($year, $month, $day) = ($1, $2, $3);
    } elsif ($date_str =~ /^(\d{2})\/(\d{2})\/(\d{4})$/) {
        ($year, $month, $day) = ($3, $2, $1);
    } else {
        return $default_year;
    }
    
    my $target_date = sprintf('%04d-%02d-%02d', $year, $month, $day);
    
    # Chercher l'exercice qui contient cette date
    foreach my $ex (@$exercises) {
        my $debut = $ex->{debut_exercice} || $ex->{fiscal_year} . '-01-01';
        my $fin = $ex->{fin_exercice} || $ex->{fiscal_year} . '-12-31';
        
        if ($target_date ge $debut && $target_date le $fin) {
            return $ex->{fiscal_year};
        }
    }
    
    # Si pas trouvé, retourner l'année de la date (création implicite)
    return $year;
}

1;

__END__

=head1 NAME

Base::Service::EmailReceiver - Module de réception d'emails pour extraction de factures

=head1 SYNOPSIS

    use Base::Service::EmailReceiver;
    
    # Configuration IMAP
    my $imap_config = {
        server   => 'imap.gmail.com',
        username => 'factures@entreprise.com',
        password => 'mot_de_passe_app',
    };
    
    # Configuration stockage
    my $storage_config = {
        base_dir     => '/var/www/html/Compta/base/documents/',
        client_id    => 1,
        fiscal_year  => 2024,
    };
    
    # Traitement automatique
    my $invoices = Base::Service::EmailReceiver::process_inbox_and_save(
        $imap_config, 
        $storage_config, 
        $dbh
    );

=head1 DESCRIPTION

Ce module permet de récupérer automatiquement les factures PDF envoyées par email
et de les intégrer dans le système comptable compta.libremen.com.

=cut
