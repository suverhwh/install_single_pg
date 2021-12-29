#!/bin/bash
#########################################################
# Function :Common tools                                #
# Platform :All Linux Based Platform                    #
# Date     :2021-11-25                                  #
# Author   :Will                                        #
# Contact  :huwnehao@mchz.com.cn                        #
# Company  :MeiChuang                                   #
#########################################################

echo 'postgres安装文件启动'
#postgresdir=/usr/local/pgsql-13/                            #bin目录
#postgresdatadir=/pgdata/pg13/data/                          #data目录
#mediedir=/media/postgresql-13.4.tar.gz                      #介质路径

read -p "please input your postgresql install directory:" postgresdir    #bin目录
read -p "please input your postgresql data directory:" postgresdatadir    #data目录

while true
do
if [ -d ${postgresdir} ];then
    break
fi
        mkdir -p ${postgresdir}
		chown -R postgres:postgres ${postgresdir}
    continue
done

while true
do
    read -p "please input your postgresql media directory:" mediedir             #介质路径
if [ -d ${mediedir} ];then
    #ls -l ${mediedir}
    ls -l /medias/pgmedia | awk '{print $9}'
    read -p "please choose your postgresql media:" pgsoftware
    break
fi
        echo -e "\033[31m No such file exist! Please input again: \033[0m"
    continue
done


OSVERSION=`cat /etc/redhat-release | awk '{print $4}'`

if [ ${OSVERSION:0:1} == '7' ]; then
   echo '关闭当前NetworkManager服务'
   systemctl stop NetworkManager.service
   echo '关闭NetworkManager服务自启动'
   systemctl disable NetworkManager.service
   echo '关闭当前防火墙服务'
   systemctl stop firewalld.service
   echo '关闭防火墙服务自启动'
   systemctl disable firewalld.service
else
   echo '关闭当前NetworkManager服务'
   service NetworkManager stop
   echo '关闭NetworkManager服务自启动'
   chkconfig NetworkManager off
   echo '关闭当前防火墙服务'
   service iptables stop
   echo '关闭防火墙服务自启动'
   chkconfig iptables off
fi
echo '关闭SELINUX服务'
if grep "SELINUX=disabled" /etc/selinux/config > /dev/null; then
   :
else
   sed -i '/SELINUX/{s/enforcing/disabled/}' /etc/selinux/config
fi
echo '备份yum源文件'
mkdir -p /etc/yum.repos.d/repobak/
mv /etc/yum.repos.d/* /etc/yum.repos.d/repobak/
echo '挂载中...'
mount /dev/cdrom /mnt/
touch /etc/yum.repos.d/dvd.repo
echo '配置本地yum源'
cat<<EOF >/etc/yum.repos.d/dvd.repo
[dvd]
name=dvd
baseurl=file:///mnt/
gpgcheck=0
enabled=1
EOF
yum clean all
yum makecache
echo '配置成功'
echo '安装所需要的依赖包'
yum -y install coreutils glib2 lrzsz mpstat dstat sysstat e4fsprogs xfsprogs ntp readline-devel zlib-devel openssl-devel pam-devel libxml2-devel libxslt-devel python-devel tcl-devel gcc make smartmontools flex bison perl-devel perl-ExtUtils* openldap-devel jadetex  openjade bzip2
#echo '配置主机ip'
#localipadd=`hostname -I|awk '{print $1}'`
#if grep `echo ${localipadd}` /etc/hosts > /dev/null; then
#    echo '已存在主机ip'
#else
#    echo "${localipadd} pg5432" >> /etc/hosts
#fi
echo '创建postgres用户'
arr=($(cat /etc/passwd|grep -v nologin|grep -v halt|grep -v shutdown|awk -F":" '{ print $1 }'))
flag=0
for i in ${arr[@]};do
if [ ${i} == 'postgres' ];then
    echo '已存在postgres用户,无须添加'
else
    flag=1
fi
done
if [ ${flag} == 1 ];then
    useradd postgres
else
    :
fi
echo '创建数据文件目录'
if [ -d ${postgresdatadir} ];then
    :
else
    mkdir -p ${postgresdatadir}
fi
chown -R postgres:postgres ${postgresdatadir}
echo '解压安装包'
FILETYPE=`file ${mediedir}/${pgsoftware} | awk '{print $2}'`
if [ ${FILETYPE} == 'gzip' ];then
    tar -zxvf ${mediedir}/${pgsoftware} -C ${postgresdir}
else
    tar -jxvf ${mediedir}/${pgsoftware} -C ${postgresdir}
fi

echo '初始化安装'
if [ ${FILETYPE} == 'gzip' ];then
    #cd ${mediedir%%.tar.gz}
	cd ${postgresdir}/${pgsoftware%%.tar.gz}
else
    #cd ${mediedir%%.tar.bz2}
	cd ${postgresdir}/${pgsoftware%%.tar.bz2}
fi
echo '编译安装'
./configure --prefix=${postgresdir} --enable-nls --with-perl --with-python --with-tcl --with-gssapi --with-openssl --with-pam --with-ldap --with-libxml --with-libxslt
make world
make install-world
echo '初始化数据目录'
#${postgresdir}/bin/initdb -D ${postgresdatadir}
#su - postgres -c ${postgresdir}'/bin/initdb -D '${postgresdatadir}
su - postgres -c "${postgresdir}/bin/initdb -D ${postgresdatadir}"
sed -i '/^PATH=/s@$@':${postgresdir}/bin'@' /home/postgres/.bash_profile
cat<<EOF >>/home/postgres/.bash_profile
export PGDATA=${postgresdatadir}
export LD_LIBRARY_PATH=${postgresdir}/lib
EOF


echo '备份初始化参数文件'
cp ${postgresdatadir}/postgresql.conf ${postgresdatadir}/postgresql.conf.bak

TOTALMEM=`free -g|awk NR==2|awk '{print $2}'`
EFFECTIVE_CACHE_SIZE=`echo "$TOTALMEM*1024*0.5"|bc|awk -F '[.]' '{print $1}'`
WORK_MEM=`echo "$TOTALMEM*1024*0.02"|bc|awk -F '[.]' '{print $1}'`
MAINTENANCE_WORK_MEM=`echo "$TOTALMEM*1024*0.0625"|bc|awk -F '[.]' '{print $1}'`
SHARED_BUFFERS=`echo "$TOTALMEM*1024*0.25"|bc|awk -F '[.]' '{print $1}'`
WAL_BUFFERS=`echo "$SHARED_BUFFERS*0.03125"|bc|awk -F '[.]' '{print $1}'`

if [ $MAINTENANCE_WORK_MEM -le 8192 ]; then
    :
else
    MAINTENANCE_WORK_MEM=8192
fi

declare -A dic
dic=(
[listen_addresses]='*'
[log_destination]='csvlog'
[logging_collector]='on' 
[log_statement]='mod' 
[effective_cache_size]=$EFFECTIVE_CACHE_SIZE'MB'
[work_mem]=$WORK_MEM'MB'
[maintenance_work_mem]=$MAINTENANCE_WORK_MEM'MB'
[shared_buffers]=$SHARED_BUFFERS'MB'
[wal_buffers]=$WAL_BUFFERS'MB'
[temp_buffers]='16MB'
[archive_mode]='off'
[min_wal_size]='128MB'
[max_wal_size]='2GB'
[wal_keep_size]='1GB'
[archive_command]='test ! -f /pgdata/archivedir/%f && cp %p /pgdata/archivedir/%f'
)

echo -e "\033[33m Parameters optimized based on the system \033[0m"
for key in $(echo ${!dic[*]})
do
echo "$key = '${dic[$key]}'" >> ${postgresdatadir}/postgresql.conf
done;
echo 'host    all             all             0.0.0.0/0               md5'>> ${postgresdatadir}/pg_hba.conf

echo '数据库安装成功！'
echo '数据库安装路径为:'${postgresdir}
echo '数据库数据目录为:'${postgresdatadir}
echo '启动数据库:'${postgresdir}/bin/pg_ctl start
