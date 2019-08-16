#!/usr/bin/env perl

use strict;
use warnings;

if (($#ARGV + 1) != 1) {
    printf STDERR "usage: ./gen_txt SIZE\n";
    printf STDERR "  SIZE (e.g, 1K, 15M, 2G)\n";
    exit 1;
}

my $size = $ARGV[0];

my ($count, $unit) = ($size  =~ /^(\d+)(\w)?$/);

if (! defined $count) {
    printf STDERR "SIZE must be a number with optional unit\n";    
    exit 1;
}

my $nbytes = $count;
if (defined $unit) {
   $unit = lc $2; 
    if ($unit eq 'k') {
        $nbytes *= 1024;
    } elsif ($unit eq 'm') {
        $nbytes *= (1024 ** 2);
    } elsif ($unit eq 'g') {
        $nbytes *= (1014 ** 3); 
    } else {
        printf STDERR "error: SIZE unit must be K, M, or G\n";
        exit 1;
    }
}


my @chars = 'a'..'z';
my $i;
for ($i = 0; $i < $nbytes; $i++) {
    print $chars[$i % 26];
}
