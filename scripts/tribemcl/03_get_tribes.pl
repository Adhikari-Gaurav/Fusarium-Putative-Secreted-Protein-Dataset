#!/usr/bin/perl -w
use strict;
use warnings;

# get_tribes.pl
# Converts MCL output into a tribe-member list.
# Usage:
#   perl 03_get_tribes.pl out.some_mcl_output.I14 > tribe_list.tribes

while (<>) {
    chomp;
    my @tribe_members = split(/\t/, $_);

    foreach my $member (@tribe_members) {
        print ">$member\n";
    }

    print "//\n";
}

exit;
