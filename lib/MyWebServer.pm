package MyWebServer;

use strict;
use warnings;

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

sub handle_request {
    my ($self, $cgi) = @_;

    my $path = $cgi->path_info();
    $path =~ s/\///;
    no strict 'refs';
    my $handler;
    if (*{__PACKAGE__ . '::' . $path}{CODE}) { # Handle url only if specified sub was generated in VirtualAPI
        $handler = \&{$path};
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

1;

__DATA__
# Start the server on port 8080:
my $pid = MyWebServer->new(8080)->run();

# Run in background:
my $pid = MyWebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";
