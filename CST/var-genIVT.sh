#! /usr/bin/perl -w
use strict;

if ( $#ARGV+1 != 2 && $#ARGV+1 != 3 ) {
	print "\nUsage: $0 <loadaadr> <aligned_image_size> [<entry>]\n\n";
	exit;
}

my $loadaddr = hex(shift);
my $img_size = hex(shift);

print "\nloadaddr: $loadaddr\nimg_size: $img_size\n\n";

my $entry = $loadaddr + 0x1000;
if ( $#ARGV+1 == 1 ) {
	$entry = hex(shift);
}

my $ivt_addr = $loadaddr + $img_size;
my $csf_addr = $ivt_addr + 0x20;

print "\n ivt_addr: $ivt_addr \n csf_addr: $csf_addr\n\n";

open(my $out, '>:raw', 'ivt.bin') or die "Unable to open: $!";
print $out pack("V", 0x412000D1); # IVT Header
print $out pack("V", $entry); # Jump Location
print $out pack("V", 0x0); # Reserved
print $out pack("V", 0x0); # DCD pointer
print $out pack("V", 0x0); # Boot Data
print $out pack("V", $ivt_addr); # Self Pointer
print $out pack("V", $csf_addr); # CSF Pointer
print $out pack("V", 0x0); # Reserved
close($out);
