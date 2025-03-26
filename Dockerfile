FROM ubuntu:25.04

#
# This Dockerfile for AFLplusplus uses Ubuntu 25.04 plucky and
# installs LLVM 14 for afl-clang-lto support.
#
# GCC 11 is used instead of 12 because genhtml for afl-cov doesn't like it.
#

LABEL "maintainer"="AFL++ team <afl@aflplus.plus>"
LABEL "about"="AFLplusplus container image"

### Comment out to enable these features
# Only available on specific ARM64 boards
ENV NO_CORESIGHT=1
# Possible but unlikely in a docker container
ENV NO_NYX=1

### Only change these if you know what you are doing:
# Current recommended LLVM version is 16.
# Added LLVM version #20
ENV LLVM_VERSION=20
# GCC 12 is producing compile errors for some targets so we stay at GCC 11
ENV GCC_VERSION=11

### No changes beyond this point unless you know what you are doing :)

ARG DEBIAN_FRONTEND=noninteractive

ENV NO_ARCH_OPT=1
ENV IS_DOCKER=1

RUN apt-get update && \
    apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends \
        wget ca-certificates apt-utils && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        make cmake automake meson ninja-build bison flex \
        git xz-utils bzip2 jupp nano bash-completion less vim joe ssh psmisc \
        python3 python3-dev python3-pip python-is-python3 \
        python3.13 python3.13-dev python3.13-venv \
        libtool libtool-bin libglib2.0-dev \
        apt-transport-https gnupg dialog \
        gnuplot-nox libpixman-1-dev bc \
        gcc-${GCC_VERSION} g++-${GCC_VERSION} gcc-${GCC_VERSION}-plugin-dev gdb lcov \
        clang-${LLVM_VERSION} clang-tools-${LLVM_VERSION} libc++1-${LLVM_VERSION} \
        libc++-${LLVM_VERSION}-dev libc++abi1-${LLVM_VERSION} libc++abi-${LLVM_VERSION}-dev \
        libclang1-${LLVM_VERSION} libclang-${LLVM_VERSION}-dev \
        libclang-common-${LLVM_VERSION}-dev libclang-rt-${LLVM_VERSION}-dev libclang-cpp${LLVM_VERSION} \
        libclang-cpp${LLVM_VERSION}-dev liblld-${LLVM_VERSION} \
        liblld-${LLVM_VERSION}-dev liblldb-${LLVM_VERSION} liblldb-${LLVM_VERSION}-dev \
        libllvm${LLVM_VERSION} libomp-${LLVM_VERSION}-dev libomp5-${LLVM_VERSION} \
        lld-${LLVM_VERSION} lldb-${LLVM_VERSION} llvm-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev llvm-${LLVM_VERSION}-runtime llvm-${LLVM_VERSION}-tools \
        $([ "$(dpkg --print-architecture)" = "amd64" ] && echo gcc-${GCC_VERSION}-multilib gcc-multilib) \
        $([ "$(dpkg --print-architecture)" = "arm64" ] && echo libcapstone-dev) && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 0 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 0 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_VERSION} 0 && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${LLVM_VERSION} 0 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${LLVM_VERSION} 0

RUN wget -qO- https://sh.rustup.rs | CARGO_HOME=/etc/cargo sh -s -- -y -q --no-modify-path
ENV PATH=$PATH:/etc/cargo/bin

RUN apt-get clean -y

ENV LLVM_CONFIG=llvm-config-${LLVM_VERSION}
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_TRY_AFFINITY=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

RUN git clone --depth=1 https://github.com/vanhauser-thc/afl-cov && \
    (cd afl-cov && make install) && \
    rm -rf afl-cov

RUN git clone --recursive https://github.com/AFLplusplus/AFLplusplus

WORKDIR /AFLplusplus
COPY . .

ARG CC=gcc-$GCC_VERSION
ARG CXX=g++-$GCC_VERSION
ARG TEST_BUILD

RUN sed -i.bak 's/^	-/	/g' GNUmakefile && \
    make clean && \
    make distrib && \
    ([ "${TEST_BUILD}" ] || (make install)) && \
    mv GNUmakefile.bak GNUmakefile

RUN echo "set encoding=utf-8" > /root/.vimrc && \
    echo ". /etc/bash_completion" >> ~/.bashrc && \
    echo 'alias joe="joe --wordwrap --joe_state -nobackup"' >> ~/.bashrc && \
    echo "export PS1='[AFL++ \h] \w \$ '" >> ~/.bashrc

# Setting up OGHarn
WORKDIR /
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl software-properties-common lsb-release build-essential \
        libgoogle-glog-dev tzdata pkg-config ccache doctest-dev bear \
        gpg zip unzip tar lld && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean

RUN dpkg -l | grep libgoogle-glog-dev && \
    dpkg -l | grep llvm-20

RUN mkdir -p /OGHarn
COPY . /OGHarn
RUN if [ -d "/OGHarn/extras/multiplier" ]; then rm -rf "/OGHarn/extras/multiplier"; fi && \
    mkdir -p /OGHarn/extras/multiplier
WORKDIR /OGHarn/extras/multiplier
RUN mkdir src build install

RUN bash -c 'if [[ ! -f "/OGHarn/extras/multiplier/install/bin/activate" ]]; then \
    python3.13 -m venv "/OGHarn/extras/multiplier/install"; \
    fi && \
    . "/OGHarn/extras/multiplier/install/bin/activate"'

RUN git clone https://github.com/trailofbits/multiplier.git src/multiplier

RUN cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="./install" \
    -DCMAKE_LINKER_TYPE=LLD \
    -DCMAKE_C_COMPILER="$(which clang)" \
    -DCMAKE_CXX_COMPILER="$(which clang++)" \
    -DMX_ENABLE_INSTALL=ON \
    -DMX_ENABLE_PYTHON_BINDINGS=ON \
    -DLLVM_CONFIG=/usr/bin/llvm-config \
    -DLLVM_DIR=/usr/lib/llvm-20/lib/cmake/llvm/ \
    -DCMAKE_LINKER=$(which lld) \
    -GNinja \
    "./src/multiplier"

RUN ninja install

WORKDIR /OGHarn/extras
