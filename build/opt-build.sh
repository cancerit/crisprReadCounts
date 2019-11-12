#! /bin/bash

set -xe

if [[ -z "${TMPDIR}" ]]; then
  TMPDIR=/tmp
fi

set -u

if [ "$#" -lt "1" ] ; then
  echo "Please provide an installation path such as /opt/ICGC"
  exit 1
fi

# get path to this script
SCRIPT_PATH=`dirname $0`;
SCRIPT_PATH=`(cd $SCRIPT_PATH && pwd)`

# get the location to install to
INST_PATH=$1
mkdir -p $1
INST_PATH=`(cd $1 && pwd)`
echo $INST_PATH

# get current directory
INIT_DIR=`pwd`

CPU=`grep -c ^processor /proc/cpuinfo`
if [ $? -eq 0 ]; then
  if [ "$CPU" -gt "6" ]; then
    CPU=6
  fi
else
  CPU=1
fi
echo "Max compilation CPUs set to $CPU"

SETUP_DIR=$INIT_DIR/install_tmp
mkdir -p $SETUP_DIR/distro # don't delete the actual distro directory until the very end
mkdir -p $INST_PATH/bin
cd $SETUP_DIR

## HTSLIB (tar.bz2)
if [ ! -e $SETUP_DIR/htslib.success ]; then
  rm -rf htslib
  mkdir -p htslib
  curl -sSL --retry 10 https://github.com/samtools/htslib/releases/download/${VER_HTSLIB}/htslib-${VER_HTSLIB}.tar.bz2 > distro.tar.bz2
  tar --strip-components 1 -C htslib -jxf distro.tar.bz2
  cd htslib
  ./configure --enable-plugins --enable-libcurl --prefix=$INST_PATH
  make clean
  make -j$CPU
  make install
  cd $SETUP_DIR
  rm -rf distro.*
  touch $SETUP_DIR/htslib.success
fi

## SAMTOOLS (tar.bz2)
if [ ! -e $SETUP_DIR/samtools.success ]; then
  curl -sSL --retry 10 https://github.com/samtools/samtools/releases/download/${VER_SAMTOOLS}/samtools-${VER_SAMTOOLS}.tar.bz2 > distro.tar.bz2
  rm -rf distro/*
  tar --strip-components 1 -C distro -xjf distro.tar.bz2
  cd distro
  ./configure --enable-plugins --enable-libcurl --with-htslib=$INST_PATH --prefix=$INST_PATH
  make clean
  make -j$CPU all
  make install
  cd $SETUP_DIR
  rm -rf distro.* distro/*
  touch $SETUP_DIR/samtools.success
fi

## Bio::DB::HTS (tar.gz)
if [ ! -e $SETUP_DIR/Bio-DB-HTS.success ]; then
  ## add perl deps
  cpanm --no-wget --no-interactive --notest --mirror http://cpan.metacpan.org -l $INST_PATH Module::Build
  cpanm --no-wget --no-interactive --notest --mirror http://cpan.metacpan.org -l $INST_PATH XML::Parser
  cpanm --no-wget --no-interactive --notest --mirror http://cpan.metacpan.org -l $INST_PATH Bio::Root::Version

  curl -sSL --retry 10 https://github.com/Ensembl/Bio-DB-HTS/archive/${VER_BIODBHTS}.tar.gz > distro.tar.gz
  rm -rf distro/*
  tar --strip-components 1 -C distro -zxf distro.tar.gz
  cd distro
  perl Build.PL --install_base=$INST_PATH --htslib=$INST_PATH
  ./Build
  ./Build test
  ./Build install
  cd $SETUP_DIR
  rm -rf distro.* distro/*
  touch $SETUP_DIR/Bio-DB-HTS.success
fi
