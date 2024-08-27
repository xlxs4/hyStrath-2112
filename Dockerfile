# Base system requirements and environment setup
FROM ubuntu:20.04 as base

# Silent and unobtrusive, see man 7 debconf.
ENV DEBIAN_FRONTEND=noninteractive

# Set up locales just in case.
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment &&\
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&\
echo "LANG=en_US.UTF-8" >> /etc/locale.conf &&\ 
apt-get update && apt-get install -y --no-install-recommends locales &&\
locale-gen en_US.UTF-8 && \
update-locale && \
rm -rf /var/lib/apt/lists/*

# Install system requirements.
RUN apt-get update && apt-get install -y --no-install-recommends \
wget \
git \
software-properties-common \
build-essential \
flex \
libfl-dev \
bison \
cmake \
zlib1g-dev \
libboost-system-dev \
libboost-thread-dev \
libscotch-dev \
libcgal-dev \
libopenmpi-dev \
openmpi-bin \
gnuplot \
libreadline-dev \
libncurses-dev \
libxt-dev \ 
freeglut3-dev \
bc \
rsync && \
rm -rf /var/lib/apt/lists/*

# Qt4 was deprecated in Ubuntu Focal, replaced with Qt5.
RUN add-apt-repository ppa:rock-core/qt4 && \
apt-get update && apt-get install -y --no-install-recommends \
qt4-dev-tools \
libqt4-dev \
libqt4-opengl-dev \
libqtwebkit-dev && \
rm -rf /var/lib/apt/lists/*

# Build OpenFOAM.
# Downgrade gcc and g++ to version 7.
# Also the libfl-dev thing
RUN apt-get update && apt-get install -y --no-install-recommends \
g++-7 \
gcc-7 && \
yes '' | update-alternatives --force --all && \
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
update-alternatives --config gcc && \
update-alternatives --config g++ && \
rm -rf /var/lib/apt/lists/*

# Downloading and building OpenFOAM and ThirdParty
FROM base as openfoam

WORKDIR /home/OpenFOAM/

RUN wget 'https://sourceforge.net/projects/openfoam/files/v1706/OpenFOAM-v1706.tgz' && \
tar -xzf OpenFOAM-v1706.tgz && \
rm -rf OpenFOAM-v1706.tgz && \
wget 'https://sourceforge.net/projects/openfoam/files/v1706/ThirdParty-v1706.tgz' && \
tar -xzf ThirdParty-v1706.tgz && \
rm -rf ThirdParty-v1706.tgz

ENV HOME /home
ENV WM_PROJECT_DIR /home/OpenFOAM/OpenFOAM-v1706
WORKDIR ${WM_PROJECT_DIR}

RUN . ${WM_PROJECT_DIR}/etc/bashrc && \
./Allwmake

# Installing Hystrath.
FROM openfoam as hystrath

ENV WM_PROJECT_USER_DIR ${WM_PROJECT_DIR}/foam
WORKDIR ${WM_PROJECT_USER_DIR}

COPY install.sh ${WM_PROJECT_USER_DIR}
RUN git clone https://github.com/hystrath/hyStrath.git --branch master --single-branch && \
mv -f install.sh hyStrath/install.sh

WORKDIR ${WM_PROJECT_USER_DIR}/hyStrath
RUN . ${WM_PROJECT_DIR}/etc/bashrc && \
./install.sh 4 2>/dev/null

RUN echo '#!/bin/bash\n\
source ${WM_PROJECT_DIR}/etc/bashrc\n\
exec "$@"' > /entrypoint.sh \
&& chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
