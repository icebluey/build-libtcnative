#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
docker run --cpus="2.0" --rm --name ub2004 -itd ubuntu:20.04 bash
sleep 2
docker exec ub2004 apt update -y
#docker exec ub2004 apt upgrade -fy
docker exec ub2004 apt install -y bash vim wget ca-certificates curl
docker exec ub2004 /bin/ln -svf bash /bin/sh
docker exec ub2004 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp 2.0 ub2004:/home/
docker exec ub2004 /bin/bash /home/2.0/ub2004/.preinstall_ub2004
docker exec ub2004 /bin/bash /home/2.0/ub2004/build_tomcat-native-2.0_openssl-3.3_java11_ub2004.sh
_tcnative_ver="$(docker exec ub2004 ls -1 /tmp/ | grep -i '^tomcat-native-.*gz$' | sed -e 's|tomcat-native-||g' -e 's|_openssl.*||g')"
_ssl_ver="$(docker exec ub2004 ls -1 /tmp/ | grep -i '^tomcat-native-.*gz$' | sed -e 's|.*openssl-||g' -e 's|_java.*||g')"
rm -fr /home/.tmp
mkdir /home/.tmp
docker cp ub2004:/tmp/"tomcat-native-${_tcnative_ver}_openssl-${_ssl_ver}_java11-1.ub2004.x86_64.tar.gz" /home/.tmp/
docker cp ub2004:/tmp/"tomcat-native-${_tcnative_ver}_openssl-${_ssl_ver}_java11-1.ub2004.x86_64.tar.gz".sha256 /home/.tmp/
exit
