#!/usr/bin/perl

##########LICENCE##########
# Copyright (c) 2014-2019 Genome Research Ltd.
#
# Author: Cancer Genome Project cgpit@sanger.ac.uk
#
# This file is part of crisprReadCounts.
#
# crisprReadCounts is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
##########LICENCE##########

BEGIN {
  use Cwd qw(abs_path);
  use File::Basename;
  unshift (@INC,dirname(abs_path($0)).'/../lib');
};

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use Carp;
use English qw( -no_match_vars );

use Sanger::CGP::crispr;

{
  	my $options = option_builder();
	run($options);
}

sub run {
  	my ($options) = @_;

	my $has_plasmid = $options->{'p'};

	my ($samp_name, $plas_name, $sample, $plasmid, $targeted_genes) = get_sample_read_counts($options);

	my %genes = %$targeted_genes;
    my %plasmid_rc = %$plasmid if($has_plasmid && $has_plasmid ne 'NA');
	my %sample_rc = %$sample;

	open my $OUT, '>', $options->{'o'} or die 'Failed to open '.$options->{'o'};

	if($has_plasmid && $has_plasmid ne 'NA'){
		print $OUT "sgRNA\tgene\t".$samp_name."\t".$plas_name."\n";

		foreach my $id(keys %sample_rc){
			my $rc_samp = $sample_rc{$id};
  			print  $OUT "$id\t$genes{$id}\t$rc_samp\t$plasmid_rc{$id}\n";
  		}
	}else{
		print $OUT "sgRNA\tgene\t".$samp_name."\n";

		foreach my $id(keys %sample_rc){
			my $rc_samp = $sample_rc{$id};
  			print  $OUT "$id\t$genes{$id}\t$rc_samp\n";
  		}
	}

	close $OUT;
	return;
}

sub get_sample_read_counts {
	my ($options) = @_;

	my %sample;
	my %plasmid;
	my %targeted_genes;
	my $sample_name;
	my $plasmid_name;

	my $file_locs = $options->{'i'};

    my @files = split /\,/, $file_locs;

	foreach my $file(@files){
		print "$file\n";
		my $FH;
		if($file =~ m/\.gz/i){
			open $FH, "gunzip -c $file|" or croak "$OS_ERROR\n\t Occurred when opening gzipped $file\n";
		}else{
			open $FH, '<', $file or die 'Failed to open '.$file;
		}
		while(<$FH>){
			my $line = $_;
			chomp $line;
  			my @data = split /\t/, $line;
			unless($line =~ m/^sgRNA\tgene/i){
 				my $id = $data[0];
				my $gene = $data[1];
  				my $samp_count = $data[2];
				my $plas_count = $data[3];
				$sample{$id} += $samp_count;
				$plasmid{$id} = $plas_count;
				$targeted_genes{$id} = $gene;
			}else{
				$sample_name = $data[2];
				$plasmid_name = $data[3];
			}
  		}
		close $FH;
	}

	return ($sample_name, $plasmid_name, \%sample, \%plasmid, \%targeted_genes);
}

sub option_builder {
	my ($factory) = @_;

	my %opts = ();

	my $result = &GetOptions (
		'h|help'      => \$opts{'h'},
		'o|output=s'  => \$opts{'o'},
		'i|input=s'   => \$opts{'i'},
        'p|plasmid=s' => \$opts{'p'},
        'v|version'   => \$opts{'v'});

    if ($opts{'v'}) {
      print "Version: $VERSION\n";
      exit 0;
    }

   	pod2usage() if($opts{'h'});
	pod2usage(1) if(!$opts{'o'});
	pod2usage(q{(-i) must be defined}) unless($opts{'i'});

	return \%opts;
}

__END__

=head1 NAME

crisprReadCounts.pl - QC of CRISPR/CAS9 data

=head1 SYNOPSIS

crisprReadCounts.pl [-h] -o /your/output/file -i file1,file2,file3,file4 -p y

  General Options:

    --help          (-h)	Brief documentation

    --input	    (-i)	Comma separated list of input files

    --output	    (-o)	Output file

    --output	    (-p)	Has plasmid counts (y)

    --version	    (-v)	Version

=cut
