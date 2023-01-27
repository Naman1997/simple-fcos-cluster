#!/bin/bash
set -e
K0S_VERSION=`curl https://api.github.com/repos/k0sproject/k0s/releases/latest -s | jq .name -r`
FCOS_VERSION=`curl https://builds.coreos.fedoraproject.org/prod/streams/stable/releases.json -s | jq -r --arg name "$1" 'last(.releases[].version)'`
jq -n --arg fcos_version "$FCOS_VERSION" --arg k0s_version "$K0S_VERSION" '{"fcos_version":$fcos_version, "k0s_version":$k0s_version}'