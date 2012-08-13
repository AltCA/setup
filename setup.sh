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
	der=${pem}.der
	openssl x509 -in $pem -outform der -out $der
	security add-certificates $der
	if [ "$command" = "add-trusted-cert" ] ; then
	    security add-trusted-cert $der
	fi

	added=true
	if [ "$oldSha" ] ; then
	    if [ "$command" = "add-trusted-cert" ] ; then
		security remove-trusted-cert "$oldSha"
	    fi
	    security remove-certificates "$oldSha"
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
rootSha="$newSha"
update_cert_if_changed 'https://raw.github.com/AltCA/roots/master/codesign.pem'
update_cert_if_changed 'https://raw.github.com/AltCA/roots/master/package.pem'

echo "Removing old AltCA.org certificates from Gatekeeper"
sudo spctl --remove --label "AltCA.org root" \
    || echo "(Failed, this is probably the first run.)"
echo "Adding certificate \"$commonName\" to Gatekeeper"
sudo spctl --add --label "AltCA.org root" --anchor "$rootSha"


