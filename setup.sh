#!/bin/bash

########## LICENCE ##########
# Copyright (c) 2014-2019 Genome Research Ltd.
#
# Author: CASM/Cancer IT <cgphelp@sanger.ac.uk>
#
# This file is part of AscatNGS.
#
# AscatNGS is free software: you can redistribute it and/or modify it under
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
########## LICENCE ##########

# Update info in README.md if changed

get_file () {
# output, source
  if hash curl 2>/dev/null; then
    curl -sS -o $1 -L $2
  else
    wget -nv -O $1 $2
  fi
}


INST_PATH=$1

if [[ $# -eq 2 ]] ; then
  CGP_PERLLIBS=$2
fi

# get current directory
INIT_DIR=`pwd`

set -eu

# cleanup inst_path
mkdir -p $INST_PATH/bin
cd $INST_PATH
INST_PATH=`pwd`
cd $INIT_DIR

# make sure that build is self contained
PERLROOT=$INST_PATH/lib/perl5

# allows user to knowingly specify other PERL5LIB areas.
if [ -z ${CGP_PERLLIBS+x} ]; then
  PERL5LIB="$PERLROOT"
else
  PERL5LIB="$PERLROOT:$CGP_PERLLIBS"
fi

export PERL5LIB=$PERL5LIB

#add bin path for install tests
export PATH=$INST_PATH/bin:$PATH

#create a location to build dependencies
SETUP_DIR=$INIT_DIR/install_tmp
mkdir -p $SETUP_DIR

cd $SETUP_DIR

## grab cpanm and stick in workspace, then do a self upgrade into bin:
get_file $SETUP_DIR/cpanm https://cpanmin.us/
perl $SETUP_DIR/cpanm -l $INST_PATH App::cpanminus
CPANM=`which cpanm`
echo $CPANM

cd $INIT_DIR/perl

echo -n "Installing Perl prerequisites ..."
if ! ( perl -MExtUtils::MakeMaker -e 1 >/dev/null 2>&1); then
    echo
    echo "WARNING: Your Perl installation does not seem to include a complete set of core modules.  Attempting to cope with this, but if installation fails please make sure that at least ExtUtils::MakeMaker is installed.  For most users, the best way to do this is to use your system's package manager: apt, yum, fink, homebrew, or similar."
fi

$CPANM -v --mirror http://cpan.metacpan.org --notest -l $INST_PATH/ --installdeps . < /dev/null

echo -n "Installing crisprReadCounts ..."
get_file share/ascat/ascat.R $ASCAT_SRC
perl Makefile.PL INSTALL_BASE=$INST_PATH
make
make test
make install
rm share/ascat/ascat.R

# cleanup all junk
rm -rf $SETUP_DIR

echo
echo
echo "Please add the following to beginning of path:"
echo "  $INST_PATH/bin"
echo "Please add the following to beginning of PERL5LIB:"
echo "  $PERLROOT"
echo

exit 0
