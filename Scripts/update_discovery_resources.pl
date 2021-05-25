#!/usr/bin/perl -w

use strict;
use warnings;

my @stubs = ("server_list.json", "organization_list.json");
my @public_keys = (
    "RWRtBSX1alxyGX+Xn3LuZnWUT0w//B6EmTJvgaAxBMYzlQeI+jdrO6KF",
    "RWQKqtqvd0R7rUDp0rWzbtYPA3towPWcLDCl7eY9pBMMI/ohCmrS0WiM"
    );

sub ensure_in_path {
    `which @_`;
    if ($?) {
        die "@_ not found\n";
    }
}

sub run {
    print "Running: @_\n";
    system @_;
}

ensure_in_path("curl");
ensure_in_path("minisign");

my @unverified_stubs = ();
foreach my $stub (@stubs) {
    print "$stub:\n\n";
    run "curl -s -o EduVPN-redesign/Resources/Discovery/$stub https://disco.eduvpn.org/v2/$stub";
    run "curl -s -o ${stub}.minisig https://disco.eduvpn.org/v2/${stub}.minisig";
    my $is_verified = 0;
    foreach my $key (@public_keys) {
        run "minisign -V -x ./${stub}.minisig -P $key -m EduVPN-redesign/Resources/Discovery/${stub}";
        if ($? == 0) {
            print "\nVerified $stub with public key $key\n\n";
            $is_verified = 1;
            last;
        }
    }
    if (!$is_verified) {
        print "\nUnable to verify $stub\n";
        push @unverified_stubs, $stub;
    }
    print "\n";
}

if (@unverified_stubs) {
    die "Unable to verify: ", join(", ", @unverified_stubs,), "\n";
}
