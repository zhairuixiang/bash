#!/bin/bash

group_name=${1}
inventory="/srv/ansible/allhost"
hostfile="${HOME}/jump/hostfile"
csvfile="${HOME}/jump/${group_name}.csv"
cat ${inventory} | sed -n '/^\['${group_name}'\]/,/^\[/p' | awk -F"[ ]|[=]" '/^[^\[]/ && /^[^#]/{print $3,$1}' > ${hostfile}
echo "id,IP,主机名,协议,端口,系统平台,网域,激活,管理用户,公网IP,资产编号,制造商,型号,序列号,CPU型号,CPU数量,CPU核数,CPU总数,内存,硬盘大小,硬盘信息,操作系统,系统版本,系统架构,主机名原始,创建者,备注" > ${csvfile}

function report_csv () {
    while read ip host
    do
        hostip=${ip}
        hostname=${host}
        protocol="ssh"
        port="22"
        sys_plat="Linux"
        domain=""
        active="TRUE"
        admin_user="开发测试环境ops"
        pub_net_ip=""
        asset_num=""
        echo ",${hostip},${hostname},${protocol},${port},${sys_plat},,${active},${admin_user},,,,,,,,,,,,,,,,,,," >> ${csvfile}
    done < ${hostfile}
}

report_csv
