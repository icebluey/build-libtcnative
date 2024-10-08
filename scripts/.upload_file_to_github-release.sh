#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

set -e

_old_dir="$(pwd)"

if [[ "$#" == "0" ]]; then
    echo -e 'USAGE:\nbash '"$0"' --token TOKEN --user username --repo reponame --file filename --tag tagname\n'
    exit 1
fi

_token=""
while (( "$#" )); do
    case $1 in
        --token)
          _token="${2}"
          shift 2
          ;;
        --user)
          _username="${2}"
          shift 2
          ;;
        --repo)
          _reponame="${2}"
          shift 2
          ;;
        --file)
          _filename="${2}"
          _displayname="$(echo ${_filename} | awk -F/ '{print $NF}')"
          shift 2
          ;;
        --tag)
          _tagname="${2}"
          shift 2
          ;;
        --help|-h|*)
          echo -e 'USAGE:\nbash '"$0"' --token TOKEN --user username --repo reponame --file filename --tag tagname\n'
          exit 1
    esac
done

if [[ ! -f /usr/bin/github-release && ! -x /usr/bin/github-release ]]; then
    cd /tmp
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #_github_release_ver="$(wget -qO- 'https://github.com/github-release/github-release/releases' | grep -i '/github-release/github-release/releases/download/.*/linux-amd64-github-release.bz2' | sed 's|"|\n|g' | grep -i '/github-release/github-release/releases/download/.*/linux-amd64-github-release.bz2' | sort -V | uniq | tail -n 1)"
    #wget -q -c -t 0 -T 9 "https://github.com/${_github_release_ver}"
    wget -q -c -t 0 -T 9 "https://github.com/github-release/github-release/releases/download/v0.10.0/linux-amd64-github-release.bz2"
    bzip2 -d linux-amd64-github-release.bz2
    rm -fr /usr/bin/github-release
    sleep 1
    install -c -m 0755 linux-amd64-github-release /usr/bin/github-release
    sleep 1
    strip /usr/bin/github-release
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
fi

cd "${_old_dir}"

if wget -qO- "https://github.com/${_username}/${_reponame}" >/dev/null; then
    if ! wget -qO- "https://github.com/${_username}/${_reponame}/releases/tag/${_tagname}" >/dev/null; then
        sleep 60
    fi
    if ! wget -qO- "https://github.com/${_username}/${_reponame}/releases/tag/${_tagname}" >/dev/null; then
        GITHUB_TOKEN="${_token}" \
        /usr/bin/github-release release \
        --user "${_username}" \
        --repo "${_reponame}" \
        --tag "${_tagname}"
        sleep 60
    fi
else
    echo "'https://github.com/${_username}/${_reponame}'"' does not exist!'
    exit 1
fi

GITHUB_TOKEN="${_token}" \
/usr/bin/github-release upload \
--user "${_username}" \
--repo "${_reponame}" \
--file "${_filename}" \
--name "${_displayname}" \
--tag "${_tagname}"

_token=""
echo
echo "Upload ${_displayname} done"
echo
sleep 2
exit
