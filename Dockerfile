FROM python:3.8-slim-buster AS builder

RUN apt-get update \
    && apt-get install -y wget ca-certificates gnupg2 \
    && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

RUN echo "deb http://apt.llvm.org/buster/ llvm-toolchain-buster-11 main" >> /etc/apt/sources.list \
    && echo "deb-src http://apt.llvm.org/buster/ llvm-toolchain-buster-11 main" >> /etc/apt/sources.list \
    && apt-get update

RUN apt-get install -y make remake git tar pkg-config gfortran \
        clang-11 clang-tools-11 \
        libclang-common-11-dev libclang-11-dev libclang1-11 \
        clang-format-11 clangd-11 \
        libc++-11-dev libc++abi-11-dev libomp-11-dev \
        libbz2-dev libicu-dev \
        libstdc++-8-dev \
	libpng-dev libjpeg62-turbo-dev libzip-dev libssl-dev \
    && ln -s /usr/bin/clang++-11 /usr/bin/clang++ \
    && ln -s /usr/bin/clang-11 /usr/bin/clang

RUN cd /tmp \
    && wget https://github.com/Kitware/CMake/releases/download/v3.18.4/cmake-3.18.4.tar.gz \
    && tar -xf cmake-3.18.4.tar.gz \
    && cd cmake-3.18.4 \
    && env CC=clang CXX=clang++ ./bootstrap --prefix=/usr/local -- -DCMAKE_BUILD_TYPE:STRING=Release \
    && remake -j $(nproc) \
    && remake install \
    && cd /tmp \
    && rm -rf ./*

RUN cd /tmp \
    && git clone --depth 1 https://github.com/flame/blis.git \
    && cd blis \
    && CC=clang-11 CXX=clang++-11 PYTHON=python3 ./configure --enable-cblas --enable-threading=openmp auto \
    && remake -j $(nproc) \
    && remake check -j $(nproc) \
    && remake install \
    && cd /tmp \
    && rm -rf ./*

RUN cd /tmp \
    && wget https://downloads.sourceforge.net/project/boost/boost/1.74.0/boost_1_74_0.tar.bz2 \
    && tar -xf boost_1_74_0.tar.bz2 \
    && cd /tmp/boost_1_74_0 \
    && CXX=clang++ ./bootstrap.sh --with-toolset=clang --prefix=/usr/local -with-icu --show-libraries \
    && ./b2 --help \
    && cd /tmp/boost_1_74_0 \
    && CXX=clang++ ./b2 --prefix=/usr/local --build-type=minimal \
        toolset=clang variant=release link=shared runtime-link=shared \
        cxxstd=11 cxxflags="-std=c++11 -stdlib=libstdc++" linkflags="-stdlib=libstdc++" \
        -j $(nproc) install \
    && cd /tmp/boost_1_74_0 \
    && CXX=clang++ ./b2 --prefix=/usr/local --build-type=minimal --with-test \
        toolset=clang variant=release link=shared runtime-link=shared \
        cxxstd=11  cxxflags="-std=c++11 -stdlib=libstdc++" linkflags="-stdlib=libstdc++" \
        -j $(nproc) install \
    && cd /tmp \
    && rm -rf ./*

RUN pip3 install Cython \
    && cd /tmp \
    && wget https://github.com/numpy/numpy/releases/download/v1.19.4/numpy-1.19.4.tar.gz \
    && tar -xf numpy-1.19.4.tar.gz \
    && cd numpy-1.19.4 \
    && CC=clang CXX=clang++ python3 setup.py build -j $(nproc) install --prefix=/usr/local --single-version-externally-managed --root=/

RUN mkdir /src \
    && cd /src \
    && git clone --depth 1 https://github.com/ruslo/polly.git
