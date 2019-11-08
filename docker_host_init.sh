#!/bin/bash

deploy_user=deploy

###新建deploy用户并赋予sudo
id $deploy_user || useradd $deploy_user

if grep -q "^${deploy_user}" /etc/sudoers ;then
    sed -i -r 's@(^'$deploy_user'.*NOPASSWD: ).*@\1ALL@' /etc/sudoers
else
    echo "${deploy_user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

###安装docker-ce
cat > /etc/yum.repos.d/zhaoyou-docker.repo <<-'EOF'
[zhaoyou-docker-ce]
name=Docker CE Stable - $basearch 51zhaoyou
baseurl=http://yum.tech.51zhaoyou.com/51zhaoyou/docker/7/x86_64/
enabled=1
gpgcheck=0
EOF
which docker || yum -y install docker-ce
systemctl start docker.service && echo "docker启动成功"

###添加jenkins公钥，实现免密访问
jenkins_pubkey='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJ9a5v9/rFoY2bURrAq0Uloj8S1PxGzsLFAfgEdsyiKdOTZCRcv41qiSdArdJ1NVwSj6/ywLqaURrbO0B/X4JiWei4AEm0Nuewz44xKiPQhVkTWipLK5h/elX3KAbRNlCZmT+N4VQuSsOgz61S6PKEsFJ2k4jPx2XdtvwjJ2vvy6hERlSGQO1UPTCIYHKsCuRDKmiHotvwGFG4/6Eu2JW57egwJ2Kcbrh6vewinDTixOFOGhGsJzQ1cJMqWfHuepJq7qLd7L0UjJXQL5u1iR8AP4rUPRwSdoqe507yxq29mKjGlrtzW2EwGuHvldlyT9VzdF4qZ5cvBX917xZ4c1ed jenkins@jenkins-server'

cd /home/$deploy_user
[ -d .ssh ] || mkdir .ssh
echo $jenkins_pubkey >> .ssh/authorized_keys
chown -R $deploy_user.$deploy_user .ssh
chmod 700 .ssh
chmod 600 .ssh/authorized_keys

###安装ansible所依赖的docker-compose模块
pip install docker-compose
