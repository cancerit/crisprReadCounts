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

	# TODO: validate inputs before doing anything
	my $trim = $options->{'t'};
	unless($trim) {$trim = 0};
	my $reverse_complementing = $options->{'rc'};

	my ($lib, $targeted_genes) = get_library($options->{'l'});

	my ($plasmid, $plas_name) = get_plasmid_read_counts($options->{'p'});

	my ($seen_samp, $samp_name) = get_counts($options->{'i'}, $options->{'r'}, $lib, $trim, $reverse_complementing);

	my %sample = %$seen_samp;

	open my $OUT, '>', $options->{'o'} or die 'Failed to open '.$options->{'o'};

	if($plas_name){
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\t".$plas_name."\n";

		foreach my $seq(sort keys %$lib){
			foreach my $grna (@{$lib->{$seq}->{'ids'}}) {
				my $sample_count = $sample{$grna} || 0;
				my $plasmid_count = $plasmid->{$grna} || 0;
				print  $OUT "$grna\t" . $targeted_genes->{$grna} . "\t$sample_count\t$plasmid_count\n";
			}
		}
	}else{
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\n";

		foreach my $seq(sort keys %$lib){
			foreach my $grna (@{$lib->{$seq}->{'ids'}}) {
				my $sample_count = $sample{$grna} || 0;
				print  $OUT "$grna\t" . $targeted_genes->{$grna} . "\t$sample_count\n";
			}
		}
	}

	close $OUT;
	return;
}

sub get_library {
	my ($lib_file) = @_;
	my %lib;
	my %targeted_genes;

	my $line_count = 0;
	if($lib_file){
		open my $LIB, '<', $lib_file or die 'Failed to open '.$lib_file;

	 	while(<$LIB>){
			$line_count += 1;
			my $lib_line = $_;
			chomp($lib_line);
			my @lib_data = split /\,/, $lib_line;
			if (scalar @lib_data < 3) {
				print "Line: $line_count does not have 3 columns.\n";
				exit 1;
			}
			my $id = $lib_data[0];
			my $gene = $lib_data[1];
			my $lib_seq = $lib_data[2];
			if ( $lib_seq !~ /^[ATGCatgc]+$/) {
				print "Sequence column contains non-DNA characters on line: $line_count.\n";
				exit 1;
			}
			$lib{$lib_seq}->{'length'} = length($lib_seq);
			push @{$lib{$lib_seq}->{'ids'}}, $id;
			$targeted_genes{$id} = $gene;
		}
		close $LIB;
	}
	return (\%lib,\%targeted_genes);
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
	my ($file, $ref_file, $lib, $trim, $reverse_complementing) = @_;

	# get sample name from the cram file
	my %seen;
	my $sample_name;
	my $head_command = q{samtools view -H -T } .$ref_file . ' ' .$file . q{ | grep -e '^@RG' -m 1};
	my $pid_head = open my $PROC_HEAD, '-|', $head_command or croak "Could not fork: $OS_ERROR";
	while( my $tmp = <$PROC_HEAD> ) {
		my @head = split /\t+/, $tmp;
		foreach my $val(@head){
			if($val =~ m/^SM/i){
				my($sm, $sample) = split /\:/, $val;
				$sample_name = $sample;
				last;
			}
		}
	}

	unless ($sample_name) {
		print 'Input CRAM file does not have a "@RG" line in header, or RG lines have no "SM" tag'.".\n";
		exit 1;
	}

	my %lib_seqs;
	foreach my $seq (keys %$lib) {
		my $seq_key = $seq;
		if ($reverse_complementing) {
			# reverse complementing guide RNA sequences instead of each read
			$seq_key = reverse($seq);
			$seq_key =~ tr/ACGTacgt/TGCAtgca/;
		}
		$lib_seqs{$seq_key} = $seq;
	}

	# assume library sequences are in same length
	my $lib_seq_size = length((keys %lib_seqs)[0]);

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

		if($reverse_complementing){
			$cram_seq = substr $cram_seq, -$trim-$lib_seq_size, $lib_seq_size;
		} else {
			$cram_seq = substr $cram_seq, $trim, $lib_seq_size;
		}

		my $matching_lib_seq = $lib_seqs{$cram_seq};
		if ($matching_lib_seq) {
			foreach my $grna (@{$lib->{$matching_lib_seq}->{'ids'}}) {
				$seen{$grna}++;
			}
		}
	}
	close $PROC;

	return (\%seen, $sample_name);
}


sub option_builder {
	my ($factory) = @_;

	my %opts = ();

	my $result = &GetOptions (
		'h|help'                => \$opts{'h'},
		'i|input=s'             => \$opts{'i'},
		'p|plasmid=s'           => \$opts{'p'},
		'o|output=s'            => \$opts{'o'},
		'l|library=s'           => \$opts{'l'},
		't|trim=i'              => \$opts{'t'},
		'rc|reverse-complement' => \$opts{'rc'},
		'r|ref=s'               => \$opts{'r'},
		'v|version'             => \$opts{'v'}
	);

	if ($opts{'v'}) {
		print "Version: $VERSION\n";
		exit 0;
	}

	pod2usage() if($opts{'h'});
	pod2usage(-message => "Required argument '-i | --input' is missing.", -exitval => 1) if(!$opts{'i'});
	pod2usage(-message => "Required argument '-l | --library' is missing.", -exitval => 1) if(!$opts{'l'});
	pod2usage(-message => "Required argument '-o | --output' is missing.", -exitval => 1) if(!$opts{'o'});
	pod2usage(-message => "Required argument '-r | --ref' is missing.", -exitval => 1)  if(!$opts{'r'});

	return \%opts;
}

__END__

=head1 NAME

crisprReadCounts.pl - counts reads in cram files

=head1 SYNOPSIS

crisprReadCounts.pl [-h] -i /your/input/file.cram -l /your/library/file -p /plasmid/readcount/file -o output_file

  General Options:

    --help                  (-h)   Brief documentation

    --dir                   (-i)   Input sample cram file

    --plas                  (-p)   Plasmid count tsv file

    --library               (-l)   Library csv file

    --output                (-o)   output file for read counts

    --ref                   (-r)   genome reference fa file

    --trim                  (-t)   Remove N bases of leading sequence

    --reverse-complement    (-rc)  Reverse complementing reads when mapping to guide sequences 
=cut
