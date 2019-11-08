#!/bin/bash
##########Nginx日志切割
local_ip="192.168.2.128"
nginx_log_dir="/home/wwwlogs/nginx"
yesterday=$(date -d "1 day ago" +%Y%m%d)
access_log_name="access.log"
access_log_rotate="${access_log_name}-${yesterday}"
error_log_name="nginx_error.log"
error_log_rotate="${error_log_name}-${yesterday}"
if [ ! -d ${nginx_log_dir} ] ;then
    echo "${nginx_log_dir}日志文件目录不存在,请手动检查"
    exit 1
fi

function nginx_log_rotate () {
    cd ${nginx_log_dir}
    cp -f ${access_log_name} ${access_log_rotate}
    echo > ${access_log_name}
    gzip -9 ${access_log_rotate}
    cp -f ${error_log_name} ${error_log_rotate}
    echo > ${error_log_name}
    gzip -9 ${error_log_rotate}
}

nginx_log_rotate
mv ${nginx_log_dir}/*.gz /home/archived_log/nginx/${local_ip}
