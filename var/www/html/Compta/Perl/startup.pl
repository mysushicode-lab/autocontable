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
#!/usr/bin/perl

# make sure we are in a sane environment.
#$ENV{MOD_PERL} or die "not running under mod_perl!" ;

#add my own library to @INC
#use lib qw(/home/lib) ;
use lib '/var/www/html/Compta/Perl/';

#use utf8 ;

use Apache2::Request () ;
use Apache2::RequestIO () ;
use Apache2::RequestRec () ;
use Apache2::SubRequest () ;
use Apache2::Response () ;
use Apache2::Upload () ;
use Encode () ;
use APR::Table () ;
use Apache2::Cookie () ;
use Apache2::Connection () ;
use URI::Escape() ;
use base qw(Apache2::Filter) ;
use Storable qw( nfreeze thaw ) ;
#use JSON::XS qw( encode_json decode_json ) ;
use DBI () ;
use DBD::Pg () ;
use CGI::Cookie () ;
use File::Basename () ;
use Carp qw(croak) ;
#format emails on 7bit characters
use MIME::Entity () ;
#dev only
use Data::Dumper () ;


1; #return true value
