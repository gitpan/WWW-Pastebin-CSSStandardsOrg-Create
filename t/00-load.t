#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN {
    use_ok('Carp');
    use_ok('WWW::Mechanize');
    use_ok('Class::Data::Accessor');
    use_ok( 'WWW::Pastebin::CSSStandardsOrg::Create' );
}

diag( "Testing WWW::Pastebin::CSSStandardsOrg::Create $WWW::Pastebin::CSSStandardsOrg::Create::VERSION, Perl $], $^X" );

my $o = WWW::Pastebin::CSSStandardsOrg::Create->new;
isa_ok($o,'WWW::Pastebin::CSSStandardsOrg::Create');
can_ok($o,qw(_set_error error paste_uri paste new mech));
isa_ok($o->mech, 'WWW::Mechanize');