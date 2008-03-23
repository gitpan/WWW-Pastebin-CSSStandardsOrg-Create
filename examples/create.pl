#!/usr/bin/env perl

use strict;
use warnings;

use lib '../lib';
use WWW::Pastebin::CSSStandardsOrg::Create;

my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new;

$paster->paste( 'text'x20, expire => 'day', )
    or die $paster->error;

printf "Your paste is located on: $paster\n";