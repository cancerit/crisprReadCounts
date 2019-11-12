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


use ExtUtils::MakeMaker;

WriteMakefile(
  NAME          => 'crisprReadCounts',
  LICENSE       => 'agpl_3', # http://search.cpan.org/~dagolden/CPAN-Meta-2.142690/lib/CPAN/Meta/Spec.pm#license
  VERSION_FROM  => 'lib/Sanger/CGP/crispr.pm',
  EXE_FILES     => [qw( bin/crisprReadCounts.pl
                        bin/crisprMergeResults.pl)],
			
  PREREQ_PM     => {
                     'Try::Tiny' => 0.24,
		     'Const::Fast' => 0.014,
                   }
);

