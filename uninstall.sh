#!/bin/bash

sha_for() {
    security find-certificate -Zc "$1"|grep ^SHA-1|awk '{print $3}'
}

rootsha=`sha_for "AltCA root"`
pkgcertsha=`sha_for "AltCA package root"`
codecertsha=`sha_for "AltCA code signing root"`

rootpem=`mktemp -t altca-uninstall`
security find-certificate -a -c 'AltCA root' -p > $rootpem

echo "Removing AltCA.org rules from the Gatekeeper security policy"
sudo spctl --remove --label "AltCA.org root"
echo "Removing certificates"

security remove-trusted-cert "$rootpem"
security delete-certificate -Z "$pkgcertsha"
security delete-certificate -Z "$codecertsha"
security delete-certificate -Z "$rootsha"

altcapkg=`pkgutil --pkgs=org.altca.installer`
if [ "$altcapkg" ] ; then
    echo "Detected AltCA.org installer package, uninstalling package."
    rm -rf /opt/AltCa
    pkgutil --forget $altcapkg
fi

echo "All done."
