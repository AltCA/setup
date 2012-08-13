#!/bin/bash -e

# !!! WARNING !!!
# This is EXPERIMENTAL code, and it modifies the security policy of your
# system. It may damage or compromise the security of your system.

update_cert_if_changed() {
    url="$1"
    command="$2"
    pem=`mktemp -t altca-setup`
    curl -sfo $pem "$url"
    commonName=`openssl asn1parse -in $pem -i|grep -1 ':commonName'|grep UTF8STRING|cut -f 4 -d :|uniq|tail -1`
    newSha=`openssl x509 -in $pem -sha1 -noout -fingerprint | cut -f 2 -d = | sed -e 's/://g'`
    echo "Downloaded certificate \"$commonName\" with fingerprint $newSha"
    oldSha=`sha_for "$commonName"`
    added=false
    replaced=false
    if [ "$oldSha" != "$newSha" ] ; then
	security $command $pem
	added=true
	if [ "$oldSha" ] ; then
	    rmcommand=`echo "$command" | sed -e 's/add-/remove-/'`
	    security $rmcommand "$oldSha"
	    replaced=true
	fi
    fi
    if $replaced ; then
	echo "Replaced certificate \"$commonName\" (old fingerprint: $oldSha, new fingerprint: $newSha)"
    elif $added ; then
	echo "Added new certificate \"$commonName\" with fingerprint $newSha"
    fi
}

sha_for() {
    security find-certificate -Zc "$1"|grep ^SHA-1|awk '{print $3}'
}

update_cert_if_changed 'https://raw.github.com/AltCA/roots/master/root.pem' add-trusted-cert
echo "Adding certificate \"$commonName\" to Gatekeeper"
sudo spctl --add --label "AltCA.org root" --anchor "$newSha"

update_cert_if_changed 'https://raw.github.com/AltCA/roots/master/codesign.pem' add-certificates
update_cert_if_changed 'https://raw.github.com/AltCA/roots/master/package.pem' add-certificates

