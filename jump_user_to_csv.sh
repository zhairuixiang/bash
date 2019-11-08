#!/bin/bash

memberfile=${1}
csvfile="${HOME}/jump/member.csv"
echo "id,名称,用户名,邮件,角色,微信,手机,有效,备注,用户组" > ${csvfile}

function report_csv () {
    while read name phone email
    do
        username=$(echo ${email} | awk '{print $NF}' | grep -o "^[^@]*")
        role="User"
        active="TRUE"
        comment=""
        group="Default"
        echo ",${name},${username},${email},${role},,${phone},${active},${comment},${group}" >> ${csvfile}
    done < ${memberfile}
}

report_csv
