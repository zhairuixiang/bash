#!/bin/bash
if [[ $1 == "aliyun" ]] ;then
    ansible_hosts="/srv/ansible_aliyun/allhosts"
    cd /srv/ansible_aliyun
    hosts_file="/home/ops/zabbix_hosts/hosts_aliyun"
    zabbix_ip="172.21.4.50"
    #[ -f $ansible_hosts ] || exit 2
    #awk -F"[ ]|[=]" '/^[^\[]/ && /^[^#]/{print $3,$1}' $ansible_hosts > $hosts_file
    awk -F"[ ]|[=]" '/^(pre|prd)/{print $3,$1}' allhosts pre/hosts production/hosts  | sort -u | sort -t' ' -k2 > $hosts_file
    sed -i -r -e '1i \127.0.0.1   localhost   prd-ops-zabbix-172-21-4-50-aliyun-hd2' \
          -e '1i \172.21.4.50 prd-ops-zabbix-172-21-4-50-aliyun-hd2' \
          -e '1i \192.168.2.190 yum.tech.51zhaoyou.com' \
		  $hosts_file
else
    ansible_hosts="/srv/ansible/allhost"
    hosts_file="/home/ops/zabbix_hosts/hosts"
    zabbix_ip="192.168.2.109"
    [ -d $ansible_hosts ] || exit 2
    awk -F"[ ]|[=]" '/^[^\[]/ && /^[^#]/{print $3,$1}' $ansible_hosts > $hosts_file
    sed -i -r -e '1i \127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4' \
          -e '1i \::1         localhost localhost.localdomain localhost6 localhost6.localdomain6' \
          -e '1i \192.168.2.48 prd-bank-front-end-machine-2-48-pbs-sh' \
          -e '1i \192.168.2.188 prd-nc-app-2-188-pbs-sh' \
          -e '1i \192.168.2.189 prd-nc-db-2-189-pbs-sh' \
          -e '1i \192.168.2.132 prd-nc-front-end-machine-2-132-pbs-sh' \
		  $hosts_file
fi
/usr/local/bin/ansible -i $ansible_hosts prd-ops-zabbix-172-21-4-50-aliyun-hd2 -b -m copy -a "src=$hosts_file dest=/etc/hosts mode=644"
#scp -rp $hosts_file root@${zabbix_ip}:/etc/hosts
