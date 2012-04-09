#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances(); # qr/^\D+(?!3\.0)\d/

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 20*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new( 
        autodie => 0,
        #log => [qw[debug]],
        @_
    );
};

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($firefox_instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::Firefox';

# First get a clean check without the changed headers
my ($site,$estatus) = ($server->url,200);
my $res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

my $ua = "WWW::Mechanize::Firefox $0 $$";
my $ref = 'http://example.com';
$mech->add_header(
    'Referer' => $ref,
    'X-WWW-Mechanize-Firefox' => "$WWW::Mechanize::Firefox::VERSION",
);

$mech->agent( $ua );

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

# Now check for the changes
my $headers = $mech->selector('#request_headers', single => 1)->{innerHTML};
like $headers, qr!^Referer: \Q$ref\E$!m, "We sent the correct Referer header";
like $headers, qr!^User-Agent: \Q$ua\E$!m, "We sent the correct User-Agent header";
like $headers, qr!^X-WWW-Mechanize-Firefox: \Q$WWW::Mechanize::Firefox::VERSION\E$!m, "We can add completely custom headers";
# diag $mech->content;

$mech->delete_header(
    'X-WWW-Mechanize-Firefox',
);
$mech->add_header(
    'X-Another-Header' => 'Oh yes',
);

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

# Now check for the changes
my $headers = $mech->selector('#request_headers', single => 1)->{innerHTML};
like $headers, qr!^Referer: \Q$ref\E$!m, "We sent the correct Referer header";
like $headers, qr!^User-Agent: \Q$ua\E$!m, "We sent the correct User-Agent header";
unlike $headers, qr!^X-WWW-Mechanize-Firefox: !m, "We can delete cometely custom headers";
like $headers, qr!^X-Another-Header: !m, "We can add other headers and still keep the current header settings";
# diag $mech->content;

# Now check that the custom headers go away if we uninstall them
$mech->reset_headers();

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

# Now check for the changes
$headers = $mech->selector('#request_headers', single => 1)->{innerHTML};
#diag $headers;
unlike $headers, qr!^Referer: \Q$ref\E$!m, "We restored the old Referer header";
unlike $headers, qr!^User-Agent: \Q$ua\E$!m, "We restored the old User-Agent header";
unlike $headers, qr!^X-WWW-Mechanize-Firefox: \Q$WWW::Mechanize::Firefox::VERSION\E$!m, "We can remove completely custom headers";
unlike $headers, qr!^X-Another-Header: !m, "We can remove other headers ";
# diag $mech->content;
});