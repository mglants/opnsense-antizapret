#!/usr/local/bin/bash
set -e

HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"

source config/config.sh


awk -F ';' '{print $2}' temp/list.csv | sort -u | awk '/^$/ {next} /\\/ {next} /^[а-яА-Яa-zA-Z0-9\-_\.\*]*+$/ {gsub(/\*\./, ""); gsub(/\.$/, ""); print}' | grep -Fv 'bеllonа' | CHARSET=UTF-8 idn --no-tld | grep -Fv 'xn--' > result/hostlist_original.txt


# Generate zones from domains
# FIXME: nxdomain list parsing is disabled due to its instability on z-i
###cat exclude.txt temp/nxdomain.txt > temp/exclude.txt

for file in config/custom/{include,exclude}-{hosts,ips}-custom.txt; do
    basename=$(basename $file | sed 's|-custom.txt||')
    sort -u $file config/${basename}-dist.txt | uniq | awk 'NF' > temp/${basename}.txt
done
sort -u temp/include-hosts.txt result/hostlist_original.txt > temp/hostlist_original_with_include.txt

awk -F ';' '{split($1, a, /\|/); for (i in a) {print a[i]";"$2}}' temp/list.csv | \
 grep -f config/exclude-hosts-by-ips-dist.txt | awk -F ';' '{print $2}' >> temp/exclude-hosts.txt

gawk -f scripts/getzones.awk temp/hostlist_original_with_include.txt | grep -v -F -x -f temp/exclude-hosts.txt | sort -u > result/hostlist_zones.txt

if [[ "$RESOLVE_NXDOMAIN" == "yes" ]];
then
    timeout 2h scripts/resolve-dns-nxdomain.py result/hostlist_zones.txt > temp/nxdomain-exclude-hosts.txt
    cat temp/nxdomain-exclude-hosts.txt >> temp/exclude-hosts.txt
    gawk -f scripts/getzones.awk temp/hostlist_original_with_include.txt | grep -v -F -x -f temp/exclude-hosts.txt | sort -u > result/hostlist_zones.txt
fi

# Generate a list of IP addresses
awk -F';' '$1 ~ /\// {print $1}' temp/list.csv | perl -n -e 'print "$1\n" while /(([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2})/g' | sort -Vu > result/iplist_special_range.txt

awk -F ';' '($1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/) {gsub(/\|/, RS, $1); print $1}' temp/list.csv | \
    awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/' | sort -u > result/iplist_all.txt

awk -F ';' '($1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/) && (($2 == "" && $3 == "") || ($1 == $2)) {gsub(/\|/, RS); print $1}' temp/list.csv | \
    awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/' | sort -u > result/iplist_blockedbyip.txt

grep -F -v '33-4/2018' temp/list.csv | grep -F -v '33а-5536/2019' | \
    awk -F ';' '($1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/) && (($2 == "" && $3 == "") || ($1 == $2)) {gsub(/\|/, RS); print $1}' | \
    awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/' | sort -u > result/iplist_blockedbyip_noid2971.txt

awk -F ';' '$1 ~ /\// {print $1}' temp/list.csv | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}' | sort -u > result/blocked-ranges.txt

cat temp/include-ips.txt >> result/blocked-ranges.txt

# Generate knot-resolver aliases
echo 'blocked_hosts = {' > result/knot-aliases-alt.conf
while read -r line
do
    line="$line."
    echo "${line@Q}," >> result/knot-aliases-alt.conf
done < result/hostlist_zones.txt
echo '}' >> result/knot-aliases-alt.conf


# Print results
echo "Blocked domains: $(wc -l result/hostlist_zones.txt)" >&2
echo "iplist_all: $(wc -l result/iplist_all.txt)" >&2
echo "iplist_special_range: $(wc -l result/iplist_special_range.txt)" >&2
echo "iplist_blockedbyip: $(wc -l result/iplist_blockedbyip.txt)" >&2
echo "iplist_blockedbyip_noid2971: $(wc -l result/iplist_blockedbyip_noid2971.txt)" >&2

exit 0
