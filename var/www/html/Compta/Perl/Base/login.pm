package Base::login ;
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
###########################################################################################

use utf8 ;
use Storable qw( nfreeze thaw );
use Time::Piece;
use strict ;
use Apache2::Const -compile=> qw( OK NOT_FOUND REDIRECT SERVER_ERROR ) ;
#use DBD::Pg;

sub handler {

    binmode(STDOUT, ":utf8") ;
    my $r = shift ;
    $r->no_cache(1) ;

    my $content ;
    my $racine = $r->dir_config('racine') ;
    my $version = '1.114' ;

    #variable de désactivation de la base : normalement à 0
    #mettre une valeur non nulle pour afficher un message d'attente
    my $maintenance_mode = 0 ;

    if ( $maintenance_mode ) {

	$content .= '<div style="text-align:center; margin: 5em;"><h3 class=warning>L\'accès à la base de données est désactivé pour permettre des opérations de maintenance</h3><p>Merci de bien vouloir ré-essayer ultérieurement</p></div>' ;

	$r->content_type('text/html; charset=utf-8') ;

	print $content ;

	return Apache2::Const::OK ;

    }
    
    my $req = Apache2::Request->new($r) ;

    #autorisation d'entrer refusée par défaut
    my $valid_user = 0 ;

    my ( $dbh, $sql, $username, $type_compta, $id_client, $preferred_datestyle, $fiscal_year_start, $fiscal_year, $fiscal_year_offset, $padding_zeroes, $days_to_close, $date_debut, $date_fin, $date_fin_2, $debug, $dump) ;
    
    #hash for query string's arguments
    my %args ;
    my @args = $req->param ;

    #si on a un login/pwd, le valider
    if ( @args ) {
	
	for ( @args ) {

	    $args{$_} = Encode::decode_utf8( $req->param($_) ) ;
	    #nix those sql injection/htmlcode attacks!
	    $args{$_} =~ tr/<>;/-/ ;
	    #les double-quotes viennent interférer avec le html
	    $args{$_} =~ tr/"/'/ ;

	}

	#valider l'utilisateur si on a bien les deux paramètres
	if ( $args{login} && $args{pwd} ) {
		
	my ($db_name) = $r->dir_config('db_name') ;
    my ($db_host) = $r->dir_config('db_host') ;
    my ($db_user) = $r->dir_config('db_user') ;
    my ($db_mdp) = $r->dir_config('db_mdp') ;
     

	$dbh = Compta::db_handle::get_dbh($db_name, $db_host, $db_user, $db_mdp) ;

		my $user_data ='';
		
		if ($args{login} eq 'superadmin') {

	    $sql = '
		with t1 as (
		SELECT id_client, type_compta, extract(YEAR FROM CURRENT_DATE) as fiscal_year, fiscal_year_start, padding_zeroes, (extract(YEAR FROM CURRENT_DATE) || \'-\' || fiscal_year_start )::date - ( extract(YEAR FROM CURRENT_DATE) || \'-01-01\')::date as fiscal_year_offset, (extract(YEAR FROM CURRENT_DATE) || \'-\' || fiscal_year_start )::date - CURRENT_DATE as days_to_close, date_debut, date_fin, to_char(date_fin, \'YYYY-MM-DD\') as date_fin_2
		FROM compta_client
		WHERE id_client = ?),
		t2 as (
		SELECT username, preferred_datestyle, debug , dump FROM compta_user WHERE username = ? AND userpass = ? AND is_main = 1)
		SELECT t1.id_client, t1.type_compta, t1.fiscal_year, t1.padding_zeroes, t1.fiscal_year_offset, t1.days_to_close, t2.username, t2.preferred_datestyle, t2.debug, t2.dump, t1.fiscal_year_start, t1.date_debut, t1.date_fin
		FROM t1, t2
		' ;	
		
		$user_data = $dbh->selectall_arrayref( $sql, { Slice => { } }, ($args{societe}, $args{login}, $args{pwd}) ) ;	
		
		} else {
		
	    #recherche dans la liste des utilisateurs; on commence la session dans l'année fiscale en cours par défaut
	    #si validation n'est pas nul, le compte n'a pas été validé
	    $sql = '
		SELECT username, id_client, type_compta, preferred_datestyle, debug, dump, extract(YEAR FROM CURRENT_DATE) as fiscal_year, fiscal_year_start, padding_zeroes, (extract(YEAR FROM CURRENT_DATE) || \'-\' || fiscal_year_start )::date - ( extract(YEAR FROM CURRENT_DATE) || \'-01-01\')::date as fiscal_year_offset, (extract(YEAR FROM CURRENT_DATE) || \'-\' || fiscal_year_start )::date - CURRENT_DATE as days_to_close, date_debut, date_fin, to_char(date_fin, \'YYYY-MM-DD\') as date_fin_2
		FROM compta_user INNER JOIN compta_client using(id_client)
		WHERE username = ? 
		AND userpass = ?
		AND id_client = ?
		and validation is null
		' ;	
		
		$user_data = $dbh->selectall_arrayref( $sql, { Slice => { } }, ( $args{login}, $args{pwd}, $args{societe} ) ) ;
		
		}
		
	    if ( @{ $user_data } ) { #on a trouvé un utilisateur

		( $valid_user, $type_compta, $username, $id_client, $preferred_datestyle, $fiscal_year, $fiscal_year_start, $fiscal_year_offset, $padding_zeroes, $days_to_close, $date_debut, $date_fin, $date_fin_2, $debug , $dump) = ( 1, $user_data->[0]->{type_compta}, $user_data->[0]->{username}, $user_data->[0]->{id_client}, $user_data->[0]->{preferred_datestyle}, $user_data->[0]->{fiscal_year}, $user_data->[0]->{fiscal_year_start}, $user_data->[0]->{fiscal_year_offset}, $user_data->[0]->{padding_zeroes}, $user_data->[0]->{days_to_close}, $user_data->[0]->{date_debut}, $user_data->[0]->{date_fin}, $user_data->[0]->{date_fin_2}, $user_data->[0]->{debug}, $user_data->[0]->{dump}) ;
		
	    }

	} #if ( $args{login} && $args{pwd} ) {

    } #  if ( @args ) {

#    if ( $valid_user ) {  #si l'utilisateur est valide, envoyer vers la page d'accueil de la base
    if ( $valid_user and $username !~/educand/ ) {  #si l'utilisateur est valide, envoyer vers la page d'accueil de la base

	#
	#création de la session initiale
	#

	#n° de session généré par rand, pour le passer dans le cookie; ce numéro sert de nom au fichier de stockage de la session
	my $date = localtime->strftime('%Y-%m-%d_'); 
	my $session_id_temp = join "", map +(0..9,"a".."z","A".."Z")[rand(10+26*2)], 1..26 ;
	my $session_id = $date.$session_id_temp ;
	    
	my %session = (
           '_session_id' => $session_id
	     ) ;

	$session{id_client} = $id_client ;
	
	$session{type_compta} = $type_compta ;
	
	$session{username} = $username ;

	$session{preferred_datestyle} = $preferred_datestyle ;
	
	$session{dump} = $dump ;
	
	#définition de la version
	$session{version} = $version ;
	
	$session{db_update_done} = 0 ;
	
	$session{debug} = $debug ;
	$session{racine} = $racine ;
	
	my ($date_fin_exercice_N, $date_fin_exercice_N1, $date_debut_exercice_N, $date_fin_exercice_N_bis, $date_debut_exercice_N_bis)  ;

    #Récupérer date de fin d'exercice
    if ( $fiscal_year_offset ) {
	# Formate la date mois de fiscal_year_offset (mois précédent)
	my $month_offset = Time::Piece->strptime($fiscal_year_offset, "%m");
	# Formate la date mois de fiscal_year_offset de 1 digit vers 2 (mois précédent)
	my $month_offset_two = $month_offset->strftime("%m");
	# Calcul le dernier jours du mois de fiscal_year_offset du mois précédent
	my $month_offset_last_day = $month_offset->month_last_day;
	$date_fin_exercice_N = $month_offset_last_day.'/'.$month_offset_two.'/'.($fiscal_year+1);
	$date_fin_exercice_N_bis = ($fiscal_year+1).'-'.$month_offset_two.'-'.$month_offset_last_day;	
	$date_fin_exercice_N1 = $month_offset_last_day.'/'.$month_offset_two.'/'.($fiscal_year );
    } else {
	$date_fin_exercice_N = '31/12/'.$fiscal_year ;
	$date_fin_exercice_N_bis = $fiscal_year .'-12-31';
	$date_fin_exercice_N1 = '31/12/'. ($fiscal_year - 1);
    }
    
    #Récupérer date de début d'exercice
	if 	($date_fin eq $date_fin_exercice_N) {
	$date_debut_exercice_N = $date_debut;
	$date_debut_exercice_N_bis = Time::Piece->strptime( $date_debut, "%d/%m/%Y" )->ymd;
	} else {
	$date_debut_exercice_N = $fiscal_year_start . '/'. ($fiscal_year) ;
	$date_debut_exercice_N =~ s/-/\//g;	
	$date_debut_exercice_N_bis = Time::Piece->strptime( $date_debut_exercice_N, "%d/%m/%Y" )->ymd;
	}

	#pour les exercices commençant un autre mois (fiscal_year_offset > 0), exercice = fiscal_year + 1 
	#car on emploie la FIN de l'année fiscale pour désigner l'exercice
	#dans ce cas, vérifier si on a passé la date de début du nouvel exercice au moment du login
	#si $days_to_close est négatif, on est dans le bon fiscal_year
	#si $days_to_close est positif, il faut retirer une année à $fiscal_year pour se placer d'entrée dans le bon exercice
	if ( $fiscal_year_offset > 0 ) {
		
	    if ( $days_to_close > 0 ) {

		#dans ce cas, faire un re-calcul de fiscal_year_offset, qui peut être faussé par les années bissextiles
		$sql = '
		SELECT (?::integer || \'-\' || fiscal_year_start )::date - (?::integer || \'-01-01\')::date as fiscal_year_offset
		FROM compta_user INNER JOIN compta_client using(id_client)
		WHERE username = ? AND userpass = ? and validation is null
		' ;

		my @bind_array = ( $fiscal_year, $fiscal_year, $args{login}, $args{pwd} ) ;
		
		$fiscal_year_offset = $dbh->selectall_arrayref( $sql, { Slice => { } }, @bind_array )->[0]->{fiscal_year_offset} ;

	    } else {
			
		$fiscal_year ++ ;	
		
		}

	} #	if ( $fiscal_year_offset > 0 ) 
	
	#les 12 mois sont bloqués ? si oui on est sur un exercice cloturé
	$sql = q [
	with t1 as ( SELECT id_client FROM tbllocked_month WHERE id_client = ? AND fiscal_year = ?)
	SELECT count(id_client) FROM t1
	] ;

	my @bind_array = ( $id_client, $fiscal_year ) ;
	my $en_attente_count;
	
	eval { $en_attente_count = $dbh->selectall_arrayref( $sql, undef, @bind_array )->[0]->[0] } ;
	
	if ($en_attente_count eq '12') {
	
	$session{Exercice_Cloture} = 1 ;
		
	} else {
	$session{Exercice_Cloture} = 0 ;	
	}	
	
	$session{Exercice_fin_DMY} = $date_fin_exercice_N ;
	$session{Exercice_fin_YMD} = $date_fin_exercice_N_bis ;
	
	$session{Exercice_fin_DMY_N1} = $date_fin_exercice_N1 ;
	
	$session{Exercice_debut_DMY} = $date_debut_exercice_N ;
	$session{Exercice_debut_YMD} = $date_debut_exercice_N_bis ;
	
	$session{fiscal_year} = $fiscal_year ;

	$session{fiscal_year_offset} = $fiscal_year_offset ;
	
	$session{padding_zeroes} = $padding_zeroes ;
	
	#passer la référence de la session à pnotes, pour utilisation par la suite de la requête
	$r->pnotes( 'session' => \%session ) ;

	my $serialized = Storable::nfreeze \%session  ;

	$sql = 'INSERT INTO sessions (session_id, serialized_session) VALUES (?, ?)' ;

	my @bind_values = ($session_id, $serialized) ;
	
	my $sth = $dbh->prepare($sql) ;

	$sth->bind_param( 1, $session_id ) ;

	#l'argument pg_type est nécessaire pour le driver
	$sth->bind_param( 2, $serialized,  { pg_type => DBD::Pg::PG_BYTEA } ) ;

	$sth->execute() ;

	#on met à jour last_connection_date dans aspro_client
	$sql = 'UPDATE compta_client set last_connection_date = CURRENT_DATE where id_client = ?';

	@bind_values = ($session{id_client}) ;
	
	$dbh->do( $sql, undef, @bind_values ) ;
	
	#on nettoie les données éventuellement présentes dans tbljournal_staging pour cet utilisateur
	$sql = 'DELETE FROM tbljournal_staging WHERE id_client = ? AND (substr(_session_id, 0, 11)::date != CURRENT_DATE) AND _token_id NOT LIKE \'%recurrent%\' AND _token_id NOT LIKE \'%csv%\'';
	@bind_values = ($session{id_client}) ;
	$dbh->do( $sql, undef, @bind_values ) ;

	#on nettoie les données éventuellement présentes dans tbljournal_import pour cet utilisateur
	$sql = 'DELETE FROM tbljournal_import WHERE id_client = ? AND (substr(_session_id, 0, 11)::date != CURRENT_DATE)';
	@bind_values = ($session{id_client}) ;
	$dbh->do( $sql, undef, @bind_values ) ;
	
	#on utilise $r->hostname pour servir différents noms de site
	#il faut ajouter un point devant le nom pour avoir 2 points comme spécifié dans CGI.pm
	my $hostname = $r->hostname() ;
	
	#envoyer le cookie base
	my $cookie = CGI::Cookie->new(-name  => 'session',
 				      -value => $session_id,
				      -domain => $hostname
	    ) ;
	    
	# Créez le cookie "racine" dans javascript
	my $base_cookie = CGI::Cookie->new(
		-name => 'racine',
		-value => $racine,
		-domain => $hostname
	);

	# Créez le cookie "session" dans javascript
	my $cookie = CGI::Cookie->new(-name  => 'session',
 				      -value => $session_id,
				      -domain => $hostname
	    ) ;

 	$r->err_headers_out->add('Set-Cookie' => $cookie) ;
 	$r->err_headers_out->add('Set-Cookie' => $base_cookie) ;

	#rediriger l'utilisateur vers la page d'accueil
	my $location = '/'.$racine.'/' ;

	$r->headers_out->set(Location => $location) ;

	return Apache2::Const::REDIRECT ;

    } else {  #utilisateur non valide, renvoyer le formulaire
	
	my $error_login = ( $args{login} ) ? '<div class=warning-rouge ><h3>Mauvais identifiant ou mot de passe</h3></div>' : '' ;

	#formulaire de login
	$content .= login_form( $r, \%args, $error_login, $version );

	$r->content_type('text/html; charset=utf-8') ;

	print $content ;

	return Apache2::Const::OK ;

    } #    if ( $valid_user )
    
}

1 ;

sub login_form {

    my ($r , $args, $error, $version ) = @_;

    $args->{login} ||= '' ;
    
    my ( $sql, $option_set) ;
    my ($message, $error_login ) = ('', '');
	
	my ($db_name) = $r->dir_config('db_name') ;
    my ($db_host) = $r->dir_config('db_host') ;
    my ($db_user) = $r->dir_config('db_user') ;;
    my ($db_mdp) = $r->dir_config('db_mdp') ;
    my $racine = $r->dir_config('racine') ;

	my $dbh = Compta::db_handle::get_dbh($db_name, $db_host, $db_user, $db_mdp) ;
	
    #
    #selection de l'établissement
    #
    $sql = 'SELECT etablissement, id_client FROM compta_client' ;
    my $societe_set = $dbh->selectall_arrayref( $sql, { Slice => { } }) ;
    my $societe_select = '<select class="login-text" name=societe>' ;
    for ( @$societe_set ) {
	my $selected = ( $_->{id_client} eq $args->{societe} ) ? 'selected' : '' ;
	$societe_select .= '<option value="' . $_->{id_client} . '" ' . $selected . '>'.$_->{id_client}.' - ' . $_->{etablissement} . '</option>' ;
    }

    $societe_select .= '</select>' ;
    
   	if (  $societe_set->[0]->{etablissement} eq 'Compta-Libre' ) {

	    $args->{login} = 'superadmin' ;

	    $args->{pwd} = 'admin' ;

	}
    
    #si la requête contenait le paramètre nom_utilisateur, 
    #signaler qu'on a pas trouvé d'utilisateur valide correspondant
    #my $error_login = ( $args->{login} ) ? '<div class=warning-rouge ><h3>Mauvais identifiant ou mot de passe</h3></div>' : '' ;


    my $content = q |
<!DOCTYPE HTML>

<html  style ="height: 100%;" lang="fr">
<head>
<title>Login</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link href="/Compta/style/style.css?v=| . $version . q |" rel="stylesheet" type="text/css">
</head>

<body class="login-body">
	<div class="login-container2">
		<form action="/| . $racine . q |/login" method=POST>
			<img class="login-img" src="/Compta/style/icons/logo.png" alt="image">
				<div class="login-form-input">
				<h1>Connexion</h1>
				<input class="login-text" type="text" placeholder="Entrer l'identifiant" name=login id=login value="| . $args->{login} . q |" required >
				<br>
				<input class="login-password" type="password" placeholder="Entrer le mot de passe" name=pwd id=pwd value="| . $args->{pwd} . q |" required >
				| . $societe_select . q |
				<br><br><br>
				<input class="btnform1 vert" style ="width : 59%; padding: 10px 10px;" type=submit value="Connexion" name=submit><br>
				</div>
		</form>
	<br><br><br><br>| . $message. q |
	</div>
</body>

| . $error . q |
</html> |;

}
