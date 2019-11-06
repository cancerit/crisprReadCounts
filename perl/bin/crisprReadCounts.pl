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
use Readonly qw(Readonly);

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

    if($options->{'pd'}){
	  ($plasmid, $plas_name) = get_counts($options->{'pd'}, $lib_seqs, $targeted_genes, $trim, $lib_seq_size);
    }else{
      ($plasmid, $plas_name) = get_plasmid_read_counts($options->{'p'});
    }

	$plas_name = $plas_name.".sample";


	my %lib = %$lib_seqs;
	my %genes = %$targeted_genes;
    my %plasmid_rc = %$plasmid if($plas_name);

	my ($seen_samp, $samp_name) = get_counts($options->{'d'}, $lib_seqs, $targeted_genes, $trim, $lib_seq_size);

	my %sample = %$seen_samp;

	open my $OUT, '>', $options->{'o'} or die 'Failed to open '.$options->{'o'};

	if($plas_name){
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\t".$plas_name."\n";

		foreach my $seq(keys %lib){
			foreach my $grna (@{$lib{$seq}}) {
				my $sample_count = $sample{$grna} || 0;
				my $plasmid_count = $plasmid_rc{$grna} || 0;
  				print  $OUT "$grna\t$genes{$grna}\t$sample_count\t$plasmid_count\n";
			}
  		}
	}else{
		print $OUT "sgRNA\tgene\t".$samp_name.".sample\n";

		foreach my $seq(keys %lib){
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
	return ($plasmid_name, \%plasmid);
}

sub get_counts {
  	my ($dir, $lib, $genes, $trim, $lib_seq_size) = @_;

	my %seen;
	my %bam_seqs;
	my $sample_name;
	my %lib_seqs = %$lib;
	my %targeted_genes = %$genes;

	opendir(DIR, $dir) or die "cannot open directory";
	my @docs = grep(/\.cram$/,readdir(DIR));
	foreach my $file (@docs) {
		$file = $dir.$file;

		#my $command = 'samtools view '.$options->{'i'};
		my $head_command = q{scramble -I cram -O bam }.$file.q{ | samtools view -H - | grep -e '^@RG'};
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

		my $command = 'scramble -I cram -O bam '.$file.' | samtools view -';
  		my $pid = open my $PROC, '-|', $command or croak "Could not fork: $OS_ERROR";

		my $start=0;
		my $stop=0;
		my $length=0;
		my $match_seq=0;

  		while( my $tmp = <$PROC> ) {
  			chomp($tmp);
  			my @data = split /\t/, $tmp;
 			my $cram_seq = $data[9];
            my $cram_seq_size = length($cram_seq);
		 
			if($data[1] % 32 >= 16){
 				my $revcomp = reverse($cram_seq);
   				$revcomp =~ tr/ACGTacgt/TGCAtgca/;
   				$cram_seq = $revcomp;
 			}

			if($trim && $trim>0){
				$cram_seq = substr $cram_seq, $trim, $lib_seq_size;
			}

			foreach my $grna (@{$lib_seqs{$cram_seq}}) {
				$seen{$grna}++;
				$match_seq++;
			}

  		}

	close $PROC;
	}

	return (\%seen, $sample_name);
}


sub option_builder {
	my ($factory) = @_;

	my %opts = ();

	my $result = &GetOptions (
		'h|help' => \$opts{'h'},
		'd|dir=s' => \$opts{'d'},
		'p|plas=s' => \$opts{'p'},
        'pd|plasdir' => \$opts{'pd'},
		'o|output=s' => \$opts{'o'},
		'l|library=s' => \$opts{'l'},
 		't|trim=s' => \$opts{'t'},
        'v|version'   => \$opts{'v'});

    if ($opts{'v'}) {
      print "Version: $VERSION\n";
      exit 0;
    }

   	pod2usage() if($opts{'h'});
	pod2usage(1) if(!$opts{'o'});
	pod2usage(q{(-d), (-l) and (-o) must be defined}) unless($opts{'d'}&&$opts{'l'}&&$opts{'o'});
    pod2usage(q{(-p) or (-pd) must be defined}) unless($opts{'pd'}||$opts{'p'});

	return \%opts;
}

__END__

=head1 NAME

crisprReadCounts.pl - counts reads in cram files

=head1 SYNOPSIS

crisprReadCounts.pl [-h] -d /your/input/directory/ -l /your/library/file -p /plasmid/readcount/directory/ -o output_file

  General Options:

	--help      (-h)	Brief documentation
	
	--dir       (-d)	Directory of sample cram files
	
	--plasdir   (-pd)	Plasmid cram file directory

    --plas   (-p)	Plasmid count tsv file
	
	--library	(-l)	Library csv file
	
	--output	(-o)	output file for read counts

=cut
