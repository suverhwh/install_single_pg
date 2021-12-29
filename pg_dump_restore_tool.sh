#!/bin/bash
#########################################################
# Function :Common tools                                #
# Platform :All Linux Based Platform                    #
# Date     :2021-03-26                                  #
# Author   :Will                                        #
# Contact  :huwnehao@mchz.com.cn                        #
# Company  :MeiChuang                                   #
#########################################################
echo "-------物理备份恢复小工具已启动-------
******************************
1备份
2恢复
e退出程序
******************************
"
read -p "请选择功能编号:" num1

while true
do
    read -p "请输入数据库安装目录:" pghome
if [ -d ${pghome} ];then
    break
fi
	echo "安装目录不存在,请重新输入:"
    continue
done

while true
do
    read -p "请输入数据库端口号:" pgport
	expr ${pgport} "+" 10 &> /dev/null
if [ $? -eq 0 ];then
    break
fi
	echo "输入非法端口号,请重新输入"
    continue
done	
			

echo ""
case "$num1" in
    1)
	read -p '请输入需要备份的数据库名:' dbname
	echo "
	1全库备份
	2备份数据
	3备份结构
	4备份schema
	5备份表
	e退出程序
	"
	read -p "请选择功能编号:" num2
	
	case "$num2" in
	    1)
        ${pghome}/bin/pg_dump -d ${dbname} -Fd -j 10 -Z -v -f pg_dump_$(date +%Y%m%d%H) -p ${pgport}
        ;;
        2)
        ${pghome}/bin/pg_dump -d ${dbname} -Fd -j 10 -Z -v -a -f pg_dump_$(date +%Y%m%d%H)_2 -p ${pgport}
        ;;
	    3)
	    ${pghome}/bin/pg_dump -d ${dbname} -Z 5 -v -s -Fc -f pg_dump_$(date +%Y%m%d%H)_c -p ${pgport}
		;;
		4)
		read -p '请输入需要备份的schema:' schemaname
		read -p "是否只需要备份该schema下的表结构?" answer
        case $answer in
        Y | y)
              ${pghome}/bin/pg_dump -d ${dbname} -n ${schemaname} -v  -f -s pg_dump_$(date +%Y%m%d%H)_c_s.sql -p ${pgport};;
        N | n)
              ${pghome}/bin/pg_dump -d ${dbname} -n ${schemaname} -v  -f pg_dump_$(date +%Y%m%d%H)_c_s.sql -p ${pgport};;
        *)
             echo "错误的选项,程序退出"
			 exit 0;;
        
        esac
		;;
		5)
		read -p '请输入需要备份的table:' tblname
		read -p "备份表结构[s];备份表数据[a];默认回车以备份全表:" answer
        case $answer in
        s | S)
              ${pghome}/bin/pg_dump -Fc -s -t ${tblname} -d ${dbname} -f pg_dump_$(date +%Y%m%d%H)_c_t_s.sql -p ${pgport};;
        a | A)
              ${pghome}/bin/pg_dump -Fc -a -t ${tblname} -d ${dbname} -f pg_dump_$(date +%Y%m%d%H)_c_t_a.sql -p ${pgport};;
        *)
			${pghome}/bin/pg_dump -Fc -t ${tblname} -d ${dbname} -f pg_dump_$(date +%Y%m%d%H)_c_t.sql -p ${pgport};;
        
        esac
		;;
	    e)
        exit 0
        ;;
	esac
	;;
	2)
	echo "
	1全库恢复
	2恢复数据
	3恢复结构
	4恢复schema
	5恢复表
	e退出程序
	"
	echo '----检索到当前目录下存在的备份源----'
	ls -lrt|grep pg_dump|grep [0-9,a-z]|awk '{print $9}'
	echo '------------------------------------'
	read -p '请选择备份源:' restoredir
	read -p '请输入需要还原的数据库名:' dbname
	read -p '请输入需要还原的数据库用户名:' username
	read -p "请选择功能编号:" num3
	
	case "$num3" in
	    1)
        ${pghome}/bin/pg_restore -d ${dbname} -j 10 -v -c --if-exists ${restoredir} -p ${pgport}
        ;;
        2)
        ${pghome}/bin/pg_restore -d ${dbname} -j 10 -v -a ${restoredir} -p ${pgport}
        ;;
	    3)
	    ${pghome}/bin/pg_restore -d ${dbname} -v -c ${restoredir} -p ${pgport}
		;;
		4)
		${pghome}/bin/psql -d ${dbname} -U ${username} -p ${pgport} < ${restoredir}
		;;
		5)
		read -p '请输入需要恢复的table:' tblname
		read -p "恢复表结构[s];恢复表数据[a];默认回车以恢复全表:" answer
        case $answer in
        s | S)
              ${pghome}/bin/pg_restore -s -t ${tblname} -d ${dbname} ${restoredir} -p ${pgport};;
        a | A)
              ${pghome}/bin/pg_restore -a -t ${tblname} -d ${dbname} ${restoredir} -p ${pgport};;
        *)
            ${pghome}/bin/pg_restore -t ${tblname} -d ${dbname} ${restoredir} -p ${pgport};;
        
        esac
		;;
	    e)
        exit 0
        ;;
	esac
	;;
esac