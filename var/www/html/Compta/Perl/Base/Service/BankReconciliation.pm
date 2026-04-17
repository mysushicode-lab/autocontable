package Base::Service::BankReconciliation;
#-----------------------------------------------------------------------------------------
# Module de rapprochement bancaire automatique
# 
# Utilité métier : Associer les factures aux opérations bancaires par matching intelligent
# (Date + Montant + Fournisseur)
#-----------------------------------------------------------------------------------------

use strict;
use warnings;
use utf8;
use Encode;
use List::Util qw(min max);
use Date::Parse;

#/*—————————————— Matching Facture ↔ Opération Bancaire ——————————————*/
# Algorithme principal de rapprochement
sub match_invoices_to_bank_operations {
    my ($bank_operations, $invoices, $tolerance_jours) = @_;
    
    $tolerance_jours ||= 3;  # Tolérance de 3 jours par défaut
    
    my @matches;       # Correspondances trouvées
    my @unmatched_ops; # Opérations sans facture
    my @unmatched_inv; # Factures sans opération
    
    # Marquer les éléments déjà appariés
    my %matched_bank;
    my %matched_inv;
    
    foreach my $op (@$bank_operations) {
        next if $matched_bank{$op->{id}};
        
        my $best_match = undef;
        my $best_score = 0;
        
        foreach my $inv (@$invoices) {
            next if $matched_inv{$inv->{id}};
            
            # Calcul du score de correspondance (0-100)
            my $score = calculate_match_score($op, $inv, $tolerance_jours);
            
            if ($score > $best_score && $score >= 70) {  # Seuil 70%
                $best_score = $score;
                $best_match = $inv;
            }
        }
        
        if ($best_match) {
            push @matches, {
                bank_operation => $op,
                invoice        => $best_match,
                score          => $best_score,
                status         => 'matched'
            };
            $matched_bank{$op->{id}} = 1;
            $matched_inv{$best_match->{id}} = 1;
        } else {
            push @unmatched_ops, $op;
        }
    }
    
    # Factures non appariées
    foreach my $inv (@$invoices) {
        push @unmatched_inv, $inv unless $matched_inv{$inv->{id}};
    }
    
    return {
        matches       => \@matches,
        unmatched_ops => \@unmatched_ops,
        unmatched_inv => \@unmatched_inv
    };
}

#/*—————————————— Calcul Score de Matching ——————————————*/
sub calculate_match_score {
    my ($op, $inv, $tolerance_jours) = @_;
    
    my $score = 0;
    
    # 1. Matching Date (40 points max)
    my $date_score = match_dates($op->{date}, $inv->{date}, $tolerance_jours);
    $score += $date_score * 40;
    
    # 2. Matching Montant (40 points max)
    my $amount_score = match_amounts($op->{montant}, $inv->{montant});
    $score += $amount_score * 40;
    
    # 3. Matching Fournisseur (20 points max)
    my $supplier_score = match_suppliers($op->{libelle}, $inv->{fournisseur});
    $score += $supplier_score * 20;
    
    return $score;
}

#/*—————————————— Matching Dates ——————————————*/
sub match_dates {
    my ($date1, $date2, $tolerance) = @_;
    
    return 0 unless $date1 && $date2;
    
    # Parser les dates (format ISO: YYYY-MM-DD)
    my $time1 = str2time($date1);
    my $time2 = str2time($date2);
    
    return 0 unless $time1 && $time2;
    
    my $diff_days = abs($time1 - $time2) / (24 * 3600);
    
    if ($diff_days == 0) {
        return 1;  # Match parfait
    } elsif ($diff_days <= $tolerance) {
        return 1 - ($diff_days / ($tolerance + 1));  # Score dégressif
    } else {
        return 0;  # Hors tolérance
    }
}

#/*—————————————— Matching Montants ——————————————*/
sub match_amounts {
    my ($amount1, $amount2) = @_;
    
    return 0 unless defined $amount1 && defined $amount2;
    
    # Normaliser (valeur absolue car débit/crédit)
    my $amt1 = abs($amount1);
    my $amt2 = abs($amount2);
    
    # Tolérance de 0.01€ pour arrondis
    my $diff = abs($amt1 - $amt2);
    
    if ($diff < 0.01) {
        return 1;  # Match parfait
    } elsif ($diff < 1.00) {
        return 0.8;  # Proche (erreur d'arrondi)
    } elsif ($diff < 5.00) {
        return 0.5;  # Tolérable
    } else {
        return 0;  # Trop différent
    }
}

#/*—————————————— Matching Fournisseurs ——————————————*/
sub match_suppliers {
    my ($libelle_op, $fournisseur_inv) = @_;
    
    return 0 unless $libelle_op && $fournisseur_inv;
    
    my $text1 = lc($libelle_op);
    my $text2 = lc($fournisseur_inv);
    
    # Nettoyer les chaînes
    for ($text1, $text2) {
        s/[^a-z0-9]//g;  # Garder uniquement alphanumérique
    }
    
    # Distance de Levenshtein normalisée
    my $distance = levenshtein_distance($text1, $text2);
    my $max_len = max(length($text1), length($text2));
    
    return 0 if $max_len == 0;
    
    my $similarity = 1 - ($distance / $max_len);
    
    # Bonus si un mot clé est présent dans les deux
    my @keywords = ('leroy', 'merlin', 'amazon', 'orange', 'sfr', 'edf', 'engie', 'free', 'bouygues');
    foreach my $keyword (@keywords) {
        if ($text1 =~ /$keyword/ && $text2 =~ /$keyword/) {
            $similarity = 1;  # Match parfait sur mot clé
            last;
        }
    }
    
    return $similarity;
}

#/*—————————————— Distance de Levenshtein ——————————————*/
sub levenshtein_distance {
    my ($s, $t) = @_;
    
    my ($len1, $len2) = (length($s), length($t));
    return $len2 if ($len1 == 0);
    return $len1 if ($len2 == 0);
    
    my %d;
    
    for (my $i = 0; $i <= $len1; $i++) {
        $d{$i}{0} = $i;
    }
    for (my $j = 0; $j <= $len2; $j++) {
        $d{0}{$j} = $j;
    }
    
    for (my $i = 1; $i <= $len1; $i++) {
        my $s_i = substr($s, $i - 1, 1);
        for (my $j = 1; $j <= $len2; $j++) {
            my $cost = ($s_i eq substr($t, $j - 1, 1)) ? 0 : 1;
            $d{$i}{$j} = min(
                $d{$i - 1}{$j} + 1,      # suppression
                $d{$i}{$j - 1} + 1,      # insertion
                $d{$i - 1}{$j - 1} + $cost  # substitution
            );
        }
    }
    
    return $d{$len1}{$len2};
}

#/*—————————————— Génération Écriture de Rapprochement ——————————————*/
sub generate_reconciliation_entry {
    my ($match, $compte_banque, $journal) = @_;
    
    my $op = $match->{bank_operation};
    my $inv = $match->{invoice};
    
    # Déterminer le compte contrepartie
    my $compte_contrepartie = $inv->{compte_fournisseur} || '401000';
    
    my $entry = {
        date_ecriture   => $op->{date},
        libelle         => $inv->{libelle} || ($inv->{fournisseur} . ' - Facture ' . $inv->{numero}),
        journal         => $journal,
        documents1      => $inv->{document_id},    # ID de la facture
        documents2      => $op->{document_id},     # ID du relevé
        
        lignes => [
            {
                numero_compte => $compte_contrepartie,
                debit         => ($op->{montant} > 0) ? 0 : abs($op->{montant}),
                credit        => ($op->{montant} > 0) ? $op->{montant} : 0,
            },
            {
                numero_compte => $compte_banque,
                debit         => ($op->{montant} > 0) ? $op->{montant} : 0,
                credit        => ($op->{montant} > 0) ? 0 : abs($op->{montant}),
            }
        ]
    };
    
    return $entry;
}

#/*—————————————— Interface Web - Liste des Matchs ——————————————*/
sub generate_match_table {
    my ($matches, $unmatched_ops, $unmatched_inv) = @_;
    
    my $html = '<div class="reconciliation-container">';
    
    # Section: Matchs trouvés
    if (@$matches) {
        $html .= '<h3 class="success">Correspondances trouvées (' . scalar(@$matches) . ')</h3>';
        $html .= '<table class="data-table">';
        $html .= '<tr><th>Date Op</th><th>Fournisseur</th><th>Montant</th><th>Facture</th><th>Score</th><th>Action</th></tr>';
        
        foreach my $match (@$matches) {
            my $op = $match->{bank_operation};
            my $inv = $match->{invoice};
            
            my $score_class = ($match->{score} >= 90) ? 'high-match' : ($match->{score} >= 70) ? 'medium-match' : 'low-match';
            
            $html .= '<tr>';
            $html .= '<td>' . $op->{date} . '</td>';
            $html .= '<td>' . $op->{libelle} . '</td>';
            $html .= '<td>' . sprintf('%.2f', $op->{montant}) . ' €</td>';
            $html .= '<td>' . $inv->{fournisseur} . '<br><small>' . $inv->{numero} . '</small></td>';
            $html .= '<td class="' . $score_class . '">' . int($match->{score}) . '%</td>';
            $html .= '<td><input type="checkbox" name="validate_match" value="' . $op->{id} . '_' . $inv->{id} . '" checked> Valider</td>';
            $html .= '</tr>';
        }
        
        $html .= '</table>';
    }
    
    # Section: Opérations sans facture
    if (@$unmatched_ops) {
        $html .= '<h3 class="warning">Opérations sans facture (' . scalar(@$unmatched_ops) . ')</h3>';
        $html .= '<ul>';
        foreach my $op (@$unmatched_ops) {
            $html .= '<li>' . $op->{date} . ' - ' . $op->{libelle} . ' : ' . sprintf('%.2f', $op->{montant}) . ' €</li>';
        }
        $html .= '</ul>';
    }
    
    # Section: Factures sans opération
    if (@$unmatched_inv) {
        $html .= '<h3 class="info">Factures sans opération bancaire (' . scalar(@$unmatched_inv) . ')</h3>';
        $html .= '<ul>';
        foreach my $inv (@$unmatched_inv) {
            $html .= '<li>' . $inv->{date} . ' - ' . $inv->{fournisseur} . ' : ' . sprintf('%.2f', $inv->{montant}) . ' €</li>';
        }
        $html .= '</ul>';
    }
    
    $html .= '</div>';
    
    return $html;
}

1;

__END__

=head1 NAME

Base::Service::BankReconciliation - Rapprochement bancaire automatique factures/relevés

=head1 SYNOPSIS

    use Base::Service::BankReconciliation;
    
    # Opérations bancaires extraites du relevé PDF
    my @bank_ops = (
        { id => 1, date => '2024-03-15', libelle => 'PAIEMENT LEROY MERLIN', montant => -1250.00 },
        { id => 2, date => '2024-03-18', libelle => 'VIR SFR', montant => -49.99 },
    );
    
    # Factures extraites des PDF/email
    my @invoices = (
        { id => 'F1', date => '2024-03-15', fournisseur => 'LEROY MERLIN', numero => 'FAC-1234', montant => 1250.00 },
    );
    
    # Matching automatique
    my $result = Base::Service::BankReconciliation::match_invoices_to_bank_operations(
        \@bank_ops, 
        \@invoices, 
        3  # Tolérance 3 jours
    );
    
    # Générer les écritures validées
    foreach my $match (@{$result->{matches}}) {
        my $entry = Base::Service::BankReconciliation::generate_reconciliation_entry(
            $match, 
            '512000',  # Compte banque
            'BQ'       # Journal
        );
        # Insérer dans tbljournal...
    }

=cut
