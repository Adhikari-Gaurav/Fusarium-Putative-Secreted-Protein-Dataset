#!/usr/bin/perl -w
use strict;
use warnings;

#--------------------------------------------------------------------------
# fetch_tribe_members.pl
#--------------------------------------------------------------------------
# Extracts sequences for tribe members from the input sequence file.
# Uses output from get_tribes.pl and the fasta file used for MCL analysis.
# joe.win@tsl.ac.uk
#--------------------------------------------------------------------------

# BASE_DIR override: BASE_DIR=/path/to/your/project perl 04_fetch_tribe_members.pl
my $base_dir = $ENV{'BASE_DIR'} || '.';

# Paths
my $seqNamesFile = "$base_dir/tribemcl_putative_secreted/putative_secreted_e10_mcl.tribes";
my $fasta        = "$base_dir/combined_putative_secreted_proteins.fasta";

unless (-e $seqNamesFile) { die "Can't open $seqNamesFile: $!" }
unless (-e $fasta)        { die "Can't open $fasta: $!" }

# Reads in the names of the sequences to retrieve into an array.
my @seqNames = ();
open (NAMES, $seqNamesFile) || die "Can't open $seqNamesFile: $!";
my $query;
while (<NAMES>) {
    chomp;
    next if (/^\s*$/);
    if (/^\/\//) {
        push (@seqNames, "\/\/");
        next;
    }
    ($query) = split (" ");
    push (@seqNames, $query);
}
close NAMES;

my $header = "";
my $seq = "";
my %sequences = ();
my $unique_ID = 0;
my $inSequence = 0;

open (FASTA, "$fasta") || die "Can't open $fasta: $!";
while (<FASTA>) {
    chomp;
    if (/^>/) {
        if ($inSequence) {
            ($unique_ID) = split (" ", $header);
            $seq = $header."\n".$seq."\n";
            $sequences{$unique_ID} = $seq;
            $seq = "";
            $unique_ID = 0;
            $inSequence = 0;
        }
        if (!$inSequence) {
            $header = $_;
            $inSequence = 1;
        }
    } else {
        $seq .= $_;
    }
}

# capture the last sequence entry
($unique_ID) = split (" ", $header);
$seq = $header."\n".$seq."\n";
$sequences{$unique_ID} = $seq;
close FASTA;
$seq = "";

print "$seqNamesFile\n";
$seqNamesFile =~ /(.*)\..*/;
my ($outFile) = $1;
print "$outFile\n";

my $seqCount = 0;
my @notFound = ();
my @seqSoFar = ();
my $groupCount = 0;
my $newOutFile = "$outFile"."_tribes\.faa";
open (OUT, ">$newOutFile") || die "Can't create output file $outFile: $!";

foreach my $name(@seqNames) {
    if ($name =~ /^\/\//) {
        $groupCount++;
        foreach $seq(@seqSoFar) {
            $seq =~ s/>/>Tribe$groupCount\_/;
            print OUT "$seq";
        }
        print OUT "\n\n";
        undef @seqSoFar;
        next;
    }
    if (exists ($sequences{$name})) {
        print "Found: $name\n";
        push (@seqSoFar, "$sequences{$name}");
        $seqCount++;
    } else {
        $name .= "\n";
        push (@notFound, $name);
    }
}
close OUT;

print "\nTotal sequences found: $seqCount\n";
if (@notFound) {
    print "Can't find...\n";
    print @notFound;
}

exit;
