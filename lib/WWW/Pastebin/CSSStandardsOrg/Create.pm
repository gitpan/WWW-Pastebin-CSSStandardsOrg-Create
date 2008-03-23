package WWW::Pastebin::CSSStandardsOrg::Create;

use warnings;
use strict;

our $VERSION = '0.001';

use Carp;
use WWW::Mechanize;
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    paste_uri
    error
    mech
);

use overload q|""| => sub { shift->paste_uri };

my %Expire_Number_for = (
    'day'       => 1,
    'week'      => 2,
    'month'     => 3,
    'quarter'   => 4,
    'year'      => 5,
    'never'     => 6,
);

my %Valid_Langs = map { $_ => 1 } qw( none css html4strict javascript xml );

sub new {
    my $self = bless {}, shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;
    $args{mech}    ||= WWW::Mechanize->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.12)'
                    .' Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12',
    );

    $self->mech( $args{mech} );

    return $self;
}

sub paste {
    my ( $self, $content ) = splice @_, 0, 2;

    $self->$_(undef) for qw(paste_uri error);

    return $self->_set_error('first argument to paste() is not defined')
        unless defined $content;

    return $self->_set_error('pastebin accepts only 20+ characters pastes')
        unless length $content > 20;

    croak "Must have even number of optional arguments to paste()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;
    %args = (
        content     => $content,
        name        => '',
        expire      => 'week',
        desc        => '',
        lang        => 'none',

        %args,
    );
    $args{ $_ } = lc delete $args{ $_ } for qw(lang expire);

    exists $Expire_Number_for{ $args{expire} }
        or return $self->_set_error(
            q|Invalid 'expire' parameter specified. Must be one of: |
                . join q|, |, keys %Expire_Number_for
        );

    exists $Valid_Langs{ $args{lang} }
        or return $self->_set_error(
            q|Invalid 'lang' parameter specified. Must be one of: |
                . join q|, |, keys %Valid_Langs
        );

    my $mech = $self->mech;

    $mech->get('http://paste.css-standards.org');
    $mech->success
        or return $self->_set_error($mech->req->status_line, 'net');

    $mech->form_with_fields('code')
        or return $self->_set_error('Paste form was not found');

    my $set = $mech->set_visible(
        $args{name},
        [ textarea  => $args{content} ],
        [ textarea  => $args{desc}    ],
    );
    $set == 3
        or return $self->_set_error("Failed to set all fields (only $set)");

    $mech->select( 'timeout', { n => $Expire_Number_for{ $args{expire} } } )
        or return $self->_set_error('Failed to set expire');
    $mech->select( 'syntax', $args{lang} )
        or return $self->_set_error('Failed to set lang');

    $mech->click('paste')->is_success
        or return $self->_set_error($mech->req->status_line, 'net');

    my $uri = $mech->uri;
    "$uri" eq 'http://paste.css-standards.org/'
        and return $self->_set_error('For some reason could not paste');

    return $self->paste_uri( $uri );
}

sub _set_error {
    my ( $self, $error, $type ) = @_;
    $error = 'Network error: ' . $error
        if defined $type and $type eq 'net';

    $self->error( $error );
    return;
}

1;
__END__


=head1 NAME

WWW::Pastebin::CSSStandardsOrg::Create - create new pastes on http://paste.css-standards.org/ website

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WWW::Pastebin::CSSStandardsOrg::Create;

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new;

    $paster->paste( 'text to paste', expire => 'day', )
        or die $paster->error;

    printf "Your paste is located on: $paster\n";

=head1 DESCRIPTION

The module provides means of pasting large texts into
L<http://paste.css-standards.org/> pastebin site.

=head1 CONSTRUCTOR

=head2 new

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new;

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new( timeout => 10 );

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new(
        mech => WWW::Mechanize->new( agent => '007', timeout => 10 ),
    );

Bakes and returns a fresh WWW::Pastebin::CSSStandardsOrg::Create object. Takes two
I<optional> arguments which are as follows:

=head3 timeout

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new( timeout => 10 );

Takes a scalar as a value which is the value that will be passed to
the L<WWW::Mechanize> object to indicate connection timeout in seconds.
B<Defaults to:> C<30> seconds

=head3 mech

    my $paster = WWW::Pastebin::CSSStandardsOrg::Create->new(
        mech => WWW::Mechanize->new( agent => '007', timeout => 10 ),
    );

If a simple timeout is not enough for your needs feel free to specify
the C<mech> argument which takes a L<WWW::Mechanize> object as a value.
B<Defaults to:> plain L<WWW::Mechanize> object with C<timeout> argument
set to whatever WWW::Pastebin::CSSStandardsOrg::Create's C<timeout> argument
is set to as well as C<agent> argument is set to mimic FireFox.

=head1 METHODS

=head2 paste

    my $uri = $paster->paste('some long text')
        or die $paster->error;

    my $uri2 = $paster->paste(
        'some long text',
        name        => 'Zoffix',
        expire      => 'never',
        desc        => 'some codes',
        lang        => 'css',
    ) or die $paster->error;

Instructs the object to create a new paste. If an error occured during
pasting the method will return either C<undef> or an empty list
depending on the context and the error will be available via C<error()>
method. On success returns a L<URI> object poiting to the newly created
paste (see also C<uri()> method). The first argument is
I<mandatory> content of your paste. The rest are optional arguments which
are passed in a key/value pairs. B<Note:> pastebin blocks pastes which
are shorter than 20 characters. The module will return an error if your
text is shorter. The optional arguments are as follows:

=head3 name

    { name    => 'Zoffix' }

B<Optional>. Takes a scalar as an argument which specifies the name of the
poster or
the titles of the paste. B<Defaults to:> empty string, which in turn results
to word C<Stuff> being the title of the paste. B<Defaults to:> empty string
which in turn results to 'Anonymous' as a name.

=head3 expire

    { expire => 'never' }

B<Optional>. When your paste should expire. B<Defaults to:> C<week>.
Valid values are:

=over 10

=item day

Expire in 24 hours

=item week

Expire in 7 days

=item month

Expire in a month

=item quarter

Expire in three months

=item year

Expire in a year

=item never

Paste should never expire.

=back

=head3 desc

    { desc => 'some codes' }

B<Optional>. The description of the paste. B<Defaults to:> empty string.

=head3 lang

    { lang => 'css' }

B<Optional>. Specifies the (computer) language of the paste, in other
words what syntax highlights to use. B<Defaults to:> C<none>. Valid values
are:

=over 10

=item none

No highlights, raw text.

=item css

CSS code.

=item html4strict

HTML 4.01 Strict code.

=item javascript

Javascript code

=item xml

XML (XHTML) code

=back

=head2 error

    $paster->paste( 'text to paste' )
        or die $paster->error;

If an error occured during
the call to C<paste()> method it will return either C<undef> or an empty list
depending on the context and the error will be available via C<error()>.
Takes no arguments, returns a human parsable message explaining why
C<paste()> failed.

=head2 paste_uri

    my $last_uri = $paster->paste_uri;

    print "Paste can be found on $paster\n";

Must be called after a successfull call to C<paste()>. Takes no arguments,
returns a L<URI> object poiting to the newly created
paste, i.e. the return value of the last call to C<paste()>. This method
is overloaded for C<q|""|> thus you can simply interpolated your object
in a string to obtain the URI to new paste.

=head2 mech

    my $old_mech = $paster->mech;

    $paster->mech( WWW::Mechanize->new( agent => 'blah' ) );

Returns a L<WWW::Mechanize> object used for pasting. When called with an
optional argument (which must be a L<WWW::Mechanize> object) will use it
in any subsequent C<paste()> calls.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-pastebin-cssstandardsorg-create at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Pastebin-CSSStandardsOrg-Create>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Pastebin::CSSStandardsOrg::Create

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Pastebin-CSSStandardsOrg-Create>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Pastebin-CSSStandardsOrg-Create>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Pastebin-CSSStandardsOrg-Create>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Pastebin-CSSStandardsOrg-Create>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

