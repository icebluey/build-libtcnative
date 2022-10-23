#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

CFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CFLAGS
CXXFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CXXFLAGS
LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

if [ -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h ]; then
    /usr/bin/mv -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h.orig
fi

set -e

if ! grep -q -i '^1:.*docker' /proc/1/cgroup; then
    echo
    echo ' Not in a container!'
    echo
    exit 1
fi

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

_build_apr() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _apr_ver="$(wget -qO- 'https://apr.apache.org/download.cgi' | grep -i 'href="https://dlcdn.apache.org//apr/apr-[1-9].*\.tar\.bz2' | sed 's|"|\n|g' | grep -i 'http' | sed -e 's|.*apr-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://dlcdn.apache.org/apr/apr-${_apr_ver}.tar.bz2"
    tar -xof "apr-${_apr_ver}.tar.bz2"
    sleep 1
    rm -f "apr-${_apr_ver}.tar.bz2"
    cd "apr-${_apr_ver}"
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
    --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include \
    --libdir=/usr/lib64 --libexecdir=/usr/libexec --localstatedir=/var \
    --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info
    make all
    rm -fr /tmp/apr
    make DESTDIR=/tmp/apr install
    cd /tmp/apr
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/sbin ]]; then
        file usr/sbin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        file usr/bin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
    elif [[ -d usr/lib64/ ]]; then
        find usr/lib64/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
        find usr/lib64/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
    fi
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    echo
    sleep 2
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    /sbin/ldconfig
}

_build_openssl111() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl111_ver="$(wget -qO- 'https://www.openssl.org/source/' | grep 'href="openssl-1.1.1' | sed 's|"|\n|g' | grep -i '^openssl-1.1.1.*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.openssl.org/source/openssl-${_openssl111_ver}.tar.gz"
    tar -xof "openssl-${_openssl111_ver}.tar.gz"
    sleep 1
    rm -f "openssl-${_openssl111_ver}.tar.gz"
    cd "openssl-${_openssl111_ver}"
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --openssldir=/etc/pki/tls \
    enable-ec_nistp_64_gcc_128 \
    zlib enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make all
    rm -fr /tmp/openssl111
    make DESTDIR=/tmp/openssl111 install_sw
    cd /tmp/openssl111
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/sbin ]]; then
        file usr/sbin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        file usr/bin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
    elif [[ -d usr/lib64/ ]]; then
        find usr/lib64/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
        find usr/lib64/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
    fi
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    echo
    rm -fr /usr/include/openssl
    sleep 2
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    /sbin/ldconfig
}

_build_apr
_build_openssl111
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

_tcn12_ver="$(wget -qO- 'https://tomcat.apache.org/download-native.cgi' | grep -i 'href="https://.*tomcat-native-1\.2\..*\.tar\.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^tomcat-native-1\.2\..*\.tar.gz$' | sed -e 's|tomcat-native-||g' -e 's|-.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 9 -T 9 "https://dlcdn.apache.org/tomcat/tomcat-connectors/native/${_tcn12_ver}/source/tomcat-native-${_tcn12_ver}-src.tar.gz"
tar -xof "tomcat-native-${_tcn12_ver}-src.tar.gz"
sleep 1
rm -f "tomcat-native-${_tcn12_ver}-src.tar.gz"
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
--libdir=/usr/lib64 --libexecdir=/usr/libexec --localstatedir=/var \
--sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info \
--with-java-home="${JAVA_HOME}"
sed 's| -R/usr/lib64||g' -i Makefile
make all
rm -fr /tmp/tcn12
make DESTDIR=/tmp/tcn12 install
cd /tmp/tcn12
find usr/ -type f -iname '*.la' -delete
if [[ -d usr/sbin ]]; then
    file usr/sbin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
fi
if [[ -d usr/bin ]]; then
    file usr/bin/* | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' /usr/bin/strip '{}'
fi
if [[ -d usr/lib/x86_64-linux-gnu ]]; then
    find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
    find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
elif [[ -d usr/lib64/ ]]; then
    find usr/lib64/ -iname 'lib*.so*' -type f -exec /usr/bin/strip "{}" \;
    find usr/lib64/ -iname '*.so' -type f -exec /usr/bin/strip "{}" \;
fi
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
cp -a /tmp/apr/usr/lib64/lib*.so* usr/lib64/
cp -a /tmp/openssl111/usr/lib64/lib*.so* usr/lib64/
rm -f usr/lib64/*.a
rm -fr /tmp/tomcat-native
sleep 2
cp -afr usr/lib64 /tmp/tomcat-native
echo
sleep 2
cd /tmp
tar -Jcvf /tmp/"libtcnative-${_tcn12_ver}_openssl-${_openssl111_ver}_java8-1.el7.x86_64.tar.xz" tomcat-native
echo
sleep 2
cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/apr /tmp/openssl111 /tmp/tcn12 /tmp/tomcat-native
echo
echo ' done'
echo
exit

