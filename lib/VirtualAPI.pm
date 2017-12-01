package VirtualAPI;

use strict;
use warnings;
use Data::Dumper;
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

use constant SERVER => 'HTTP::Server::Simple';

$Data::Dumper::Terse = 1;

sub new {
    my ($class, %params) = @_;

    my $self = {};
    $self->{$_} = $params{$_} for keys %params;
    bless $self => $class;

    return $self;
}

sub run {
    my $self = shift;

    my $port = $self->{'port'} || 8080;

    if (ref $self->{'urls'} ne 'ARRAY' || !scalar @{$self->{'urls'}}) {
        die "No urls given, nothing to do.";
    }

    no strict 'refs';
    if (scalar @ARGV) {
        $self->argv_urls();
        push @{$self->{'urls'}}, @{$self->{'argv'}} if (ref $self->{'argv'} eq 'ARRAY');
    }
    # Handle routes
    for my $url (@{$self->{'urls'}}) {
        if (ref $url ne 'HASH') {
            die "Wrong VirtualAPI url structure! See README.";
        }
        # Map given callback sub or default
        *{__PACKAGE__ . '::' . $url->{'route'}} = $url->{'cb'} || sub {
            my $cgi = shift;
            return if ! ref $cgi;

            my @header = ();
            if (ref $url->{'header'} eq 'ARRAY') {
                @header = @{$url->{'header'}};
            }
            else {
                push @header, $url->{'header'};
            }

            my $req_method = $cgi->request_method();
            my %req_headers = map { $_ => $cgi->http($_) } $cgi->http();

            my $start_html = $cgi->start_html($url->{'start_html'}) if $url->{'start_html'};
            my $h1 = $cgi->h1($url->{'h1'}) if $url->{'h1'};
            my $body = $cgi->body($url->{'body'}) if $url->{'body'};
            my $end_html = $cgi->end_html($url->{'end_html'}) if $url->{'end_html'};
            my $raw_content = $url->{'raw_content'} if $url->{'raw_content'};

            my @resp = grep $_, (
                $start_html,
                $h1,
                $body,
                $end_html,
                $raw_content,
            );

            print $cgi->header(@header), "$req_method\n", Dumper \%req_headers, @resp;
        };
    }

    my @urls = map { $_->{'route'} } @{$self->{'urls'}};
    # Show available routes
    print "Available routes are:\n", Dumper \@urls;
    # Show available handled subs
    # print "Route handles are:\n", Dumper \%{__PACKAGE__ . "::"};

    # Copy subs from SUPER class to run as __PACKAGE__
    my @subs = grep { defined &{SERVER . "::$_"} } keys %{SERVER . "::"};
    *{__PACKAGE__ . "::_$_"} = *{SERVER . "::$_"} for @subs;
    my $server = __PACKAGE__->_new($port);
    if ($self->{'background'}) {
        my $pid = $server->_background();
        print "Use 'kill $pid' to stop server.\n";
    }
    else {
        $server->_run();
    }
}

sub handle_request {
    my ($self, $cgi) = @_;

    my $path = $cgi->path_info();
    $path =~ s/\///;

    no strict 'refs';
    my $handler;
    # Handle url only if specified sub was generated by VirtualAPI
    if (*{__PACKAGE__ . '::' . $path}{CODE}) {
        $handler = \&{$path};
        # print $path, "\n"; # TODO: Fix $url->{'cb'} callback subs
    }

    if (ref $handler eq 'CODE') {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
    }
    else {
        print "HTTP/1.0 404 Not found\r\n";
        print(
            $cgi->header(),
            $cgi->start_html('Not found'),
            $cgi->h1('Not found'),
            $cgi->end_html(),
        );
    }
}

sub argv_urls {
    my $self = shift;

    # JSON is not mandatory, but required for gettings urls from json files
    my $json;
    eval {
        require JSON; $json = JSON->new();
    };

    return if ($@ || !$json);

    do {
        local $/ = undef;
        my @files = grep {
            my $file = $_;
            my @content;
            if (open my $fh => "<$file") {
                eval { @content = $json->decode(<$fh>); };
            }
            scalar @content # File is not empty
        } @ARGV;

        my @urls = map {
            my $file = $_;
            my $content;
            if (open my $fh => "<$file") {
                binmode $fh;
                eval { $content = $json->decode(<$fh>); };
            }
            $content
        } @files;

        $self->{'argv'} = \@urls;
    } while (0);
}

1;
