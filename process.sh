#!/usr/local/bin/bash
set -e


cp result/knot-aliases-alt.conf /usr/local/etc/knot-resolver/knot-aliases-alt.conf
service kresd stop
sleep 3
service kresd start


pfctl -t antizapret -T add -f result/blocked-ranges.txt


exit 0
