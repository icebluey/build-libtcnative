#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/tomcat-native/private'

set -e

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
}

_install_java8() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _java8_ver="$(wget -qO- 'https://github.com/icebluey/javabin/releases' | grep -i '/tree/v8' | sed 's|"|\n|g' | grep '^/.*/tree/v' | sed 's|.*/v||g' | sort -V | uniq | tail -n 1)"
    wget -q -c -t 9 -T 9 "https://github.com/icebluey/javabin/releases/download/v${_java8_ver}/jdk-${_java8_ver}-linux-x64.tar.gz.sha256"
    wget -q -c -t 9 -T 9 "https://github.com/icebluey/javabin/releases/download/v${_java8_ver}/jdk-${_java8_ver}-linux-x64.tar.gz"
    sha256sum -c "jdk-${_java8_ver}-linux-x64.tar.gz.sha256"
    rm -fr /usr/java/jdk
    rm -fr /usr/java/jdk1.8*
    install -m 0755 -d /usr/java
    tar -xof "jdk-${_java8_ver}-linux-x64.tar.gz" -C /usr/java/
    ln -sv "$(ls -d /usr/java/jdk1.8* | sed 's|.*/usr/java/||g' | sort -V | uniq | tail -n 1)" /usr/java/jdk
    JAVA_HOME=/usr/java/jdk
    export JAVA_HOME
    PATH=$JAVA_HOME/bin:$PATH
    export PATH
    CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
    export CLASSPATH
    echo
    java -version
    echo
    cd /tmp
    rm -fr "${_tmp_dir}"
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN' ; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN' ; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    cd /tmp/zstd
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_apr() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _apr_ver="$(wget -qO- 'https://apr.apache.org/download.cgi' | grep -i 'href="https://dlcdn.apache.org//apr/apr-[1-9].*\.tar\.bz2' | sed 's|"|\n|g' | grep -i 'http' | sed -e 's|.*apr-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://dlcdn.apache.org/apr/apr-${_apr_ver}.tar.bz2"
    tar -xof apr-*.tar*
    sleep 1
    rm -f apr-*.tar*
    cd apr-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
    --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include \
    --libdir=/usr/lib/x86_64-linux-gnu --libexecdir=/usr/libexec --localstatedir=/var \
    --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info \
    --enable-shared --enable-static --enable-threads --with-devrandom=/dev/urandom
    make -j$(nproc --all) all
    rm -fr /tmp/apr
    make DESTDIR=/tmp/apr install
    cd /tmp/apr
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/apr
    /sbin/ldconfig
}

_build_openssl33() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl33_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl33_ver}/openssl-${_openssl33_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl33
    make DESTDIR=/tmp/openssl33 install_sw
    cd /tmp/openssl33
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl33
    /sbin/ldconfig
}

_build_openssl35() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl35_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.5\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.5\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl35_ver}/openssl-${_openssl35_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl35
    make DESTDIR=/tmp/openssl35 install_sw
    cd /tmp/openssl35
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl35
    /sbin/ldconfig
}

###############################################################################

rm -fr /usr/lib/x86_64-linux-gnu/tomcat-native
_build_zlib
_build_brotli
_build_zstd
_build_apr
#_build_openssl33
_build_openssl35
_install_java8

JAVA_HOME=/usr/java/jdk
export JAVA_HOME
PATH=$JAVA_HOME/bin:$PATH
export PATH
CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export CLASSPATH

/sbin/ldconfig
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

#_tcn12_ver="$(wget -qO- 'https://tomcat.apache.org/download-native.cgi' | grep -i 'href="https://.*tomcat-native-1\.2\..*\.tar\.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^tomcat-native-1\.2\..*\.tar.gz$' | sed -e 's|tomcat-native-||g' -e 's|-.*||g' | sort -V | uniq | tail -n 1)"
_tcn13_ver="$(wget -qO- 'https://tomcat.apache.org/download-native.cgi' | grep -i 'href="https://.*tomcat-native-1\.3\..*\.tar\.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^tomcat-native-1\.3\..*\.tar.gz$' | sed -e 's|tomcat-native-||g' -e 's|-.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 9 -T 9 "https://dlcdn.apache.org/tomcat/tomcat-connectors/native/${_tcn13_ver}/source/tomcat-native-${_tcn13_ver}-src.tar.gz"
tar -xof tomcat-native-*.tar*
sleep 1
rm -f tomcat-native-*.tar*
cd tomcat-native-*
cd native
LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
sed '/TCN_OPENSSL_LIBS="/s| -Wl,-rpath,$use_openssl/$ssllibdir||g' -i configure
sed '/TCN_OPENSSL_LIBS="/s| -R$use_openssl/$ssllibdir||g' -i configure
./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
--sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include \
--libdir=/usr/lib/x86_64-linux-gnu --libexecdir=/usr/libexec --localstatedir=/var \
--sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info \
--with-java-home="${JAVA_HOME}"
sed 's| -R/usr/lib64||g' -i Makefile
sed 's| -R/usr/lib/x86_64-linux-gnu||g' -i Makefile
make all
rm -fr /tmp/tcn13
make DESTDIR=/tmp/tcn13 install
cd /tmp/tcn13
if [[ "$(pwd)" = '/' ]]; then
    echo
    printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
    printf '\e[01;31m%s\e[m\n' "quit"
    echo
    exit 1
else
    rm -fr lib64
    rm -fr lib
    chown -R root:root ./
fi
find usr/ -type f -iname '*.la' -delete
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    sleep 2
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
if [[ -d usr/lib/x86_64-linux-gnu ]]; then
    find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
    find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
fi
if [[ -d usr/lib64 ]]; then
    find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
    find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
fi
if [[ -d usr/sbin ]]; then
    find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
fi
if [[ -d usr/bin ]]; then
    find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
fi
echo
/bin/cp -af /usr/lib/x86_64-linux-gnu/tomcat-native/private/* usr/lib/x86_64-linux-gnu/
rm -f usr/lib/x86_64-linux-gnu/*.a
rm -fr /tmp/tomcat-native
sleep 2
cp -afr usr/lib/x86_64-linux-gnu /tmp/tomcat-native
echo
sleep 2
cd /tmp
tar -Jcvf /tmp/"tomcat-native-${_tcn13_ver}_openssl-${_openssl35_ver}_java8-1.ub2004.x86_64.tar.xz" tomcat-native
echo
sleep 2
cd /tmp
openssl dgst -r -sha256 tomcat-native-${_tcn13_ver}_openssl-${_openssl35_ver}_java8-1.ub2004.x86_64.tar.xz | sed 's|\*| |g' > tomcat-native-${_tcn13_ver}_openssl-${_openssl35_ver}_java8-1.ub2004.x86_64.tar.xz.sha256
rm -fr "${_tmp_dir}"
rm -fr /tmp/tcn13
rm -fr /tmp/tomcat-native

rm -fr /tmp/_output
install -m 0755 -d /tmp/_output
mv -v /tmp/tomcat-native*.tar* /tmp/_output/

echo
echo ' done'
echo
exit

