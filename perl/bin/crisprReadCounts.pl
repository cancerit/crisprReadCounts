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

	my $plasmid;
	my $lib_seqs;
	my $targeted_genes;
	my $plas_name;
	my $lib_seq_size;
	my $trim;

	$trim = $options->{'t'};
	($lib_seqs, $targeted_genes, $lib_seq_size) = get_library($options->{'l'});

    	($plasmid, $plas_name) = get_plasmid_read_counts($options->{'p'});

	my %lib = %$lib_seqs;
	my %genes = %$targeted_genes;
    	my %plasmid_rc = %$plasmid if($plas_name);

	my ($seen_samp, $samp_name) = get_counts($options->{'i'}, $options->{'r'},$lib_seqs, $trim, $lib_seq_size);

	my %sample = %$seen_samp;

	open my $OUT, '>', $options->{'o'} or die 'Failed to open '.$options->{'o'};

	if($plas_name){
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\t".$plas_name."\n";

		foreach my $seq(sort keys %lib){
			foreach my $grna (@{$lib{$seq}}) {
				my $sample_count = $sample{$grna} || 0;
				my $plasmid_count = $plasmid_rc{$grna} || 0;
  				print  $OUT "$grna\t$genes{$grna}\t$sample_count\t$plasmid_count\n";
			}
  		}
	}else{
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\n";

		foreach my $seq(sort keys %lib){
			foreach my $grna (@{$lib{$seq}}) {
				my $sample_count = $sample{$grna} || 0;
  				print  $OUT "$grna\t$genes{$grna}\t$sample_count\n";
			}
  		}
	}

	close $OUT;
	return;
}

sub get_library {
	my ($lib_file) = @_;

	my %lib_seqs;
	my %targeted_genes;
	my $lib_seq_size=0;

	if($lib_file){
		open my $LIB, '<', $lib_file or die 'Failed to open '.$lib_file;

 	 	while(<$LIB>){
  			my $lib_line = $_;
  			chomp($lib_line);
  			my @lib_data = split /\,/, $lib_line;
 			my $id = $lib_data[0];
			my $gene = $lib_data[1];
  			my $lib_seq = $lib_data[2];
			$lib_seq_size = length($lib_seq);
  			push(@{$lib_seqs{$lib_seq}}, $id);
			$targeted_genes{$id} = $gene;
  		}

  		close $LIB;
	}

	return (\%lib_seqs,\%targeted_genes,$lib_seq_size);
}

sub get_plasmid_read_counts {
	my ($plasmid_file) = @_;

	my %plasmid;
	my $plasmid_name;

	if($plasmid_file){
		open my $RC, '<', $plasmid_file or die 'Failed to open '.$plasmid_file;

 	 	while(<$RC>){
  			my $line = $_;
  			chomp($line);
  			my @data = split /\t/, $line;
			unless($line =~ m/^sgRNA\tgene/i){
 				my $id = $data[0];
				my $gene = $data[1];
  				my $count = $data[2];
				$plasmid{$id} = $count;
			}else{
				$plasmid_name = $data[2];
			}
  		}

  		close $RC;
	}
	return (\%plasmid, $plasmid_name);
}

sub get_counts {
  	my ($file, $ref_file, $lib, $trim, $lib_seq_size) = @_;

	my %seen;
	my $sample_name;
	my %lib_seqs = %$lib;

	my $head_command = q{samtools view -H -T } .$ref_file . ' ' .$file . q{ | grep -e '^@RG'};
	my $pid_head = open my $PROC_HEAD, '-|', $head_command or croak "Could not fork: $OS_ERROR";
	while( my $tmp = <$PROC_HEAD> ) {
		my @head = split /\t+/, $tmp;
		foreach my $val(@head){
			if($val =~ m/^SM/i){
				my($sm, $sample) = split /\:/, $val;
				$sample_name = $sample;
				}
		}
	}

	my $command = 'samtools view -T '. $ref_file . ' ' .$file;
	my $pid = open my $PROC, '-|', $command or croak "Could not fork: $OS_ERROR";

	while( my $tmp = <$PROC> ) {
		chomp($tmp);
		my @data = split /\t/, $tmp;
		my $cram_seq = $data[9];
		my $cram_seq_size = length($cram_seq);

		# if the alignment is secondary, supplymentary or vendor failed, skip it!
		if($data[1] & 2816){
			next;
		}

		if($data[1] & 16){
			$cram_seq = reverse($cram_seq);
			$cram_seq =~ tr/ACGTacgt/TGCAtgca/;
		}

		if($trim && $trim>0){
			$cram_seq = substr $cram_seq, $trim, $lib_seq_size;
		}

		foreach my $grna (@{$lib_seqs{$cram_seq}}) {
			$seen{$grna}++;
		}
	}
	close $PROC;

	return (\%seen, $sample_name);
}


sub option_builder {
	my ($factory) = @_;

	my %opts = ();

	my $result = &GetOptions (
		'h|help' => \$opts{'h'},
		'i|dir=s' => \$opts{'i'},
		'p|plas=s' => \$opts{'p'},
		'o|output=s' => \$opts{'o'},
		'l|library=s' => \$opts{'l'},
 		't|trim=s' => \$opts{'t'},
		'r|ref=s' => \$opts{'r'},
                'v|version'   => \$opts{'v'});

    if ($opts{'v'}) {
      print "Version: $VERSION\n";
      exit 0;
    }

   	pod2usage() if($opts{'h'});
	pod2usage(1) if(!$opts{'o'});
	pod2usage(1) if(!$opts{'r'});
	pod2usage(q{(-i), (-l) and (-o) must be defined}) unless($opts{'i'}&&$opts{'l'}&&$opts{'o'});

	return \%opts;
}

__END__

=head1 NAME

crisprReadCounts.pl - counts reads in cram files

=head1 SYNOPSIS

crisprReadCounts.pl [-h] -i /your/input/file.cram -l /your/library/file -p /plasmid/readcount/file -o output_file

  General Options:

    --help      (-h)  Brief documentation

    --dir       (-i)  Input sample cram file

    --plas      (-p)  Plasmid count tsv file

    --library   (-l)  Library csv file

    --output    (-o)  output file for read counts

    --ref       (-r)  genome reference fa file

    --trim      (-t)  Remove N bases of leading sequence

=cut
