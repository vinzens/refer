FROM debian:bookworm as base

COPY asterisk /asterisk

RUN apt update
RUN apt install -y neovim build-essential curl libedit-dev autoconf automake binutils-dev cmark-gfm dahdi-source default-libmysqlclient-dev freetds-dev libasound2-dev libavcodec-dev libavdevice-dev libbluetooth-dev libc-client2007e-dev libcap-dev libcodec2-dev libcurl4-openssl-dev libedit-dev libfftw3-dev libgmime-3.0-dev libgsm1-dev libical-dev libiksemel-dev libjack-dev libjansson-dev libldap-dev liblua5.1-dev libncurses-dev libneon27-dev libnewt-dev libogg-dev libopencore-amrnb-dev libopencore-amrwb-dev libopenr2-dev libopus-dev libopusenc-dev libopusfile-dev libpopt-dev libpq-dev libpri-dev libradcli-dev libreadline-dev libresample1-dev libsdl-image1.2-dev libsndfile1-dev libsnmp-dev libspandsp-dev libspeex-dev libspeexdsp-dev libsqlite3-dev libsrtp2-dev libss7-dev libssl-dev libswscale-dev libsystemd-dev libtonezone-dev libunbound-dev liburiparser-dev libvo-amrwbenc-dev libvorbis-dev libxml2-dev libxslt1-dev perl portaudio19-dev unixodbc-dev uuid-dev zlib1g-dev

FROM base

WORKDIR /asterisk

COPY patch /patch

RUN patch -p1 < /patch/pjsip_external_refer.diff

RUN ./configure
RUN make menuselect.makeopts
RUN make install
