#!/usr/bin/env bash
set -euo pipefail

NAMESPACE_P=potatostack
NAMESPACE_M=potatostack-monitoring
NAMESPACE_A=argocd

declare -A SECRETS
SECRETS["$NAMESPACE_P:gitea-tls"]=git.lepotato.local
SECRETS["$NAMESPACE_P:vaultwarden-tls"]=vault.lepotato.local
SECRETS["$NAMESPACE_P:immich-tls"]=photos.lepotato.local
SECRETS["$NAMESPACE_P:fileserver-tls"]=fileserver.lepotato.local
SECRETS["$NAMESPACE_P:homepage-tls"]=dashboard.lepotato.local
SECRETS["$NAMESPACE_A:argocd-tls"]=argocd.lepotato.local
SECRETS["$NAMESPACE_M:netdata-tls"]=netdata.lepotato.local

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

for key in "${!SECRETS[@]}"; do
  ns=${key%%:*}
  name=${key##*:}
  host=${SECRETS[$key]}
  echo "Creating self-signed TLS for $host in $ns/$name"
  mkdir -p "$tmpdir/$name"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/CN=$host" \
    -keyout "$tmpdir/$name/tls.key" \
    -out "$tmpdir/$name/tls.crt" >/dev/null 2>&1
  kubectl -n "$ns" create secret tls "$name" \
    --key "$tmpdir/$name/tls.key" --cert "$tmpdir/$name/tls.crt" \
    --dry-run=client -o yaml | kubectl apply -f -
done

echo "TLS secrets created. Consider mapping hosts to \"$(minikube ip)\" in /etc/hosts."
