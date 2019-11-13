FROM  ubuntu:16.04 as builder

USER  root

ENV OPT /opt/wtsi-cgp
ENV PATH $OPT/bin:$PATH
ENV LD_LIBRARY_PATH $OPT/lib

ENV VER_BIODBHTS="2.10"
ENV VER_HTSLIB="1.9"
ENV VER_SAMTOOLS="1.9"

RUN apt-get -yq update
RUN apt-get install -yq --no-install-recommends\
  locales\
  cpanminus \
  build-essential\
  apt-transport-https\
  curl\
  libcurl4-gnutls-dev \
  libncurses5-dev \
  zlib1g-dev \
  libbz2-dev \
  liblzma-dev \
  pkg-config \
  libgd-dev \
  libdb-dev \
  ca-certificates

RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

ENV OPT /opt/wtsi-cgp
ENV PERL5LIB $OPT/lib/perl5
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

RUN mkdir -p $OPT/bin

# build tools from other repos
ADD build/opt-build.sh build/
RUN bash build/opt-build.sh $OPT

# build the tools in this repo, separate to reduce build time on errors
COPY . .
RUN bash build/opt-build-local.sh $OPT


FROM  ubuntu:16.04

LABEL maintainer="cgphelp@sanger.ac.uk"\
      uk.ac.sanger.cgp="Cancer, Ageing and Somatic Mutation, Wellcome Sanger Institute" \
      version="1.1.5" \
      description="crisprReadCounts"

RUN apt-get -yq update
RUN apt-get install -yq --no-install-recommends \
curl \
unattended-upgrades && \
unattended-upgrade -d -v && \
curl \
apt-get remove -yq unattended-upgrades && \
apt-get autoremove -yq

ENV OPT /opt/wtsi-cgp
ENV PATH $OPT/bin:$PATH
ENV PERL5LIB $OPT/lib/perl5
ENV LD_LIBRARY_PATH $OPT/lib
ENV LC_ALL C

RUN mkdir -p $OPT
COPY --from=builder $OPT $OPT

## USER CONFIGURATION
RUN adduser --disabled-password --gecos '' ubuntu && chsh -s /bin/bash && mkdir -p /home/ubuntu

USER    ubuntu
WORKDIR /home/ubuntu

CMD ["/bin/bash"]
