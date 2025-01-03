#!/usr/bin/env sh

DIR=$(cd `dirname $0` && pwd)

# Install action
cp ${DIR}/dnsproxy /etc/rc.d/dnsproxy
chmod +x /etc/rc.d/dnsproxy
cp ${DIR}/rc-dnsproxy /etc/rc.conf.d/dnsproxy
service dnsproxy enable
cp ${DIR}/rc-kresd /etc/rc.conf.d/kresd
service kresd enable
ln -Fs ${DIR}/actions_antiz.conf /usr/local/opnsense/service/conf/actions.d/actions_antiz.conf

# Reload config daemon
service configd restart

# Initially fetch data file
${DIR}/../doall.sh
