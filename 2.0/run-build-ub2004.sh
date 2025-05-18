#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2004 -itd ubuntu:20.04 bash
else
    docker run --rm --name ub2004 -itd ubuntu:20.04 bash
fi
sleep 2
docker exec ub2004 apt update -y
docker exec ub2004 apt upgrade -fy
docker exec ub2004 apt install -y bash vim wget ca-certificates curl
docker exec ub2004 /bin/ln -svf bash /bin/sh
docker exec ub2004 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp 2.0 ub2004:/home/
docker exec ub2004 /bin/bash /home/2.0/ub2004/.preinstall_ub2004
docker exec ub2004 /bin/bash /home/2.0/ub2004/build_tomcat-native-2.0_openssl-3_java11_ub2004.sh
mkdir -p /tmp/_output_assets
docker cp ub2004:/tmp/_output /tmp/_output_assets/

sleep 2
docker stop ub2004 || true
sleep 2
docker rm -f ub2004 || true
sleep 2

if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2004 -itd ubuntu:20.04 bash
else
    docker run --rm --name ub2004 -itd ubuntu:20.04 bash
fi
sleep 2
docker exec ub2004 apt update -y
docker exec ub2004 apt upgrade -fy
docker exec ub2004 apt install -y bash vim wget ca-certificates curl
docker exec ub2004 /bin/ln -svf bash /bin/sh
docker exec ub2004 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp 2.0 ub2004:/home/
docker exec ub2004 /bin/bash /home/2.0/ub2004/.preinstall_ub2004
docker exec ub2004 /bin/bash /home/2.0/ub2004/build_tomcat-native-2.0_openssl-3_java21_ub2004.sh
mkdir -p /tmp/_output_assets
docker cp ub2004:/tmp/_output /tmp/_output_assets/

exit

