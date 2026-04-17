package Base::Site::logs;
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

use strict ;
use Time::Piece;
use warnings ;
use utf8 ;

#Exemples d'tilisation du module
#Base::Site::logs::logEntry("#### INFO ####", $r->pnotes('session')->{username}, 'Importer des écritures');
#Base::Site::logs::logEntry("#### DEBUG ####", $r->pnotes('session')->{username}, 'menu.pm => OCR : Correspondance avec Levenshtein trouvée pour '.$libelle.' avec '.$used_words.' mots sur '.$num_words.' mots. Niveau de Levenshtein : '.$levenshtein_threshold) if $r->pnotes('session')->{debug} eq 1;
         
#use Exporter qw/import/;
#our @EXPORT_OK = qw/logEntry redirect_sig/;

use Apache2::Const -compile => qw( OK REDIRECT ) ;

sub redirect_sig {
	
	binmode STDOUT, ':utf8';
	binmode STDERR, ':utf8';
	my $r = shift ;
	my $debug_all = $r || 0;
	
my %MESS;

if ($debug_all eq '1') {

	$SIG{__WARN__} = sub {
		my $message = shift;
		return if $MESS{$message}++;
		logEntry("### WARNING ###", "SYSTEM", $message);
	};

	$SIG{__DIE__} = sub {
		my $message = shift;
		return if $MESS{$message}++;
		logEntry("##### DIE #####", "SYSTEM", $message);
		if($^S) {
			# We're in an eval {} and don't want log
			# this message but catch it later
			return;
		}
	};

} else {
	$SIG{__WARN__} = sub {
		if($^S) {
			# We're in an eval {} and don't want log
			# this message but catch it later
			return;
		}
	  };

	$SIG{__DIE__} = sub {
		if($^S) {
			# We're in an eval {} and don't want log
			# this message but catch it later
			return;
		}
	};	
}

}

sub logEntry {
	  my ($level, $user, $error_code) = @_;
	  # Chemin des logs
	  my $logFile = '/var/www/html/Compta/base/logs/Compta.log';
      open(my $lout,">>:encoding(UTF-8)", $logFile) or die "Can't open $logFile: $!";
	  my $time = localtime->strftime('%d-%m-%Y %H:%M:%S');
      chomp $error_code;
      print $lout "$time $level $user: $error_code\n";
      close $lout;
      exit if $error_code eq "DIE"; #Prevents perl from further processing the die.
  }
  
  
  

1 ;
