#!/bin/bash
LANG=zh_CN.UTF-8
yum -y install expect  &> /dev/null

#新建虚拟机函数
clone () {

ID='0123456789'
NUM=$[RANDOM%10]
NUM1=$[RANDOM%10]
NUM2=$[RANDOM%10]
liua=${ID:$NUM:2}
ROOM=${ID:$NUM1:1}
IP=${ID:$NUM2:1}
echo $IP $liua $ROOM

#cp -r rh7_template.img /var/lib/libvirt/images  &> /dev/null

IMG_DIR=/var/lib/libvirt/images
BASEVM=rh7_template
#ROOM=`sed  -n "1p" /etc/hostname |  sed -r 's/(room)([0-9]{1,})(.*)/\2/'`
#IP=`sed  -n "1p" /etc/hostname |   sed -r 's/(.*)([0-9]+)(.*)/\2/'`

read -p "请输入虚拟机名: " VMNUM

if [ -z "${VMNUM}" ]; then
    echo "You must input a number."
    exit 65
fi

NEWVM=${VMNUM}

if [ -e $IMG_DIR/${NEWVM}.img ]; then
    echo "File exists."
    exit 68
fi

echo -en "Creating Virtual Machine disk image......\t"
qemu-img create -f qcow2 -b $IMG_DIR/.${BASEVM}.img $IMG_DIR/${NEWVM}.img &> /dev/null
echo -e "\e[32;1m[OK]\e[0m"


#virsh dumpxml ${BASEVM} > /tmp/myvm.xml
cat rhel7.xml > /tmp/myvm.xml
sed -i "/<name>${BASEVM}/s/${BASEVM}/${NEWVM}/" /tmp/myvm.xml
sed -i "/uuid/s/<uuid>.*<\/uuid>/<uuid>$(uuidgen)<\/uuid>/" /tmp/myvm.xml
sed -i "/${BASEVM}\.img/s/${BASEVM}/${NEWVM}/" /tmp/myvm.xml

sed -i "/mac /s/a1/${ROOM}/" /tmp/myvm.xml
sed -i "/mac /s/a2/${IP}/" /tmp/myvm.xml
sed -i "/mac /s/a3/${liua}/" /tmp/myvm.xml

sed -i "/mac /s/b1/${ROOM}/" /tmp/myvm.xml
sed -i "/mac /s/b2/${IP}/" /tmp/myvm.xml
sed -i "/mac /s/b3/${liua}/" /tmp/myvm.xml

sed -i "/mac /s/c1/${ROOM}/" /tmp/myvm.xml
sed -i "/mac /s/c2/${IP}/" /tmp/myvm.xml
sed -i "/mac /s/c3/${liua}/" /tmp/myvm.xml

sed -i "/mac /s/d1/${ROOM}/" /tmp/myvm.xml
sed -i "/mac /s/d2/${IP}/" /tmp/myvm.xml
sed -i "/mac /s/d3/${liua}/" /tmp/myvm.xml

echo -en "Defining new virtual machine......\t\t"
virsh define /tmp/myvm.xml &> /dev/null
echo -e "\e[32;1m[OK]\e[0m"
}


#新建虚拟机
read -p "是否需要新建虚拟机?（y/n）" vhost
if [ "$vhost" == "y" ];then
echo "Installing dependency packages. Please ensure that YUM works properly!"
yum -y install libguestfs-tools-c  
for host in $vhost
do 
clone
	read -p "输入虚拟机IP：" ip1
	read -p "输入虚拟机网卡：" eth
#设置ip
	UUID=`uuidgen`
	echo "
		TYPE=Ethernet
		BOOTPROTO=none
		DEFROUTE=yes
		IPV4_FAILURE_FATAL=no
		IPV6INIT=yes
		IPV6_AUTOCONF=yes
		IPV6_DEFROUTE=yes
		IPV6_FAILURE_FATAL=no
		NAME=$eth
		DEVICE=$eth
		ONBOOT=yes
		UUID=$UUID
		IPADDR=$ip1
		PREFIX=24" > /tmp/ifcfg-$eth
	virt-copy-in  -d $VMNUM /tmp/ifcfg-$eth /etc/sysconfig/network-scripts/
		echo " "
		echo "$VMNUM已经设置ip: $ip1"
	virsh start $VMNUM
  done
#检测
while :  &> /dev/null
do
echo "等待虚拟机开机"
ping -c 2 $ip1  &> /dev/null
if [ $? -eq 0 ];then
	break 
elif [ $? -ne 0 ];then
	sleep 20	
fi
done
fi

echo "更改主机名"
echo "更改YUM源"
echo "修改selinux为disabled"
echo "修改防火墙为trusted"
read -p "是否需要初始化配置？(y/n)" liu
if [ "$liu" == "y" ];then
read -p "请输入IP：" ip
if [ -z "$ip" ];then
	echo "请输入IP！"
	exit
fi
ping -c 1 $ip &> /dev/null
if [ $? -ne 0 ];then
	echo "Unable to connect to this IP"
	exit
fi

stty cbreak -echo  #密文密码
read -p "输入密码：" pass  
stty -cbreak echo
if [ -z "$pass" ];then
	echo "密码不能为空"
	exit
fi

#判断用户输入几位密码，并输出几个*
pass_s=$(echo ${#pass} )
for i in $(seq $pass_s)
do
	echo -e "*\c"
done
echo ""

#read -p "是否需要修改主机名：(y/n)" name_b
#if [ "$name_b" == "y" ];then
	read -p "请输入主机名：" name
	if [ -z "$name" ];then
		echo "Please enter the host name！"
		exit
	fi
#fi
read -p "请输入YUM源" baseurl

echo " "
echo "初始化系统状态，请勿中断！"

expect << EOF  &> /dev/null
set time 2
spawn ssh -X root@$ip
expect "(yes/no)?" { send "yes\n"; exp_continue }
expect "password" { send "$pass\r" }
expect "password" { send "$pass\r"; exp_continue}
expect "]#" 
#搭建YUM
send "rm -rf /etc/yum.repos.d/*\r"
send "cd /etc/yum.repos.d/\r"
send "touch /etc/yum.repos.d/liu.repo\r"
send "echo \[liu\] >> /etc/yum.repos.d/liu.repo\r" 
send "echo name=liu >> /etc/yum.repos.d/liu.repo\r"
send "echo enable=1 >> /etc/yum.repos.d/liu.repo\r"
send "echo baseurl=$baseurl >> /etc/yum.repos.d/liu.repo\r"
send "echo gpgcheck=0 >> /etc/yum.repos.d/liu.repo\r"
send "yum clean all\r"
#修改selinux和防火墙
send "sed -i \"s/\.\*/$name/\" /etc/hostname \r"
send "firewall-cmd --set-default-zone=trusted\r"
send "setenforce 0\r"
send "sed -i \"/\^SELINUX=/s/\.\*/SELINUX=disabled/\" /etc/selinux/config\r"
#添加检测项
send "yum repolist \| awk -F \" \" \'/\^repolist/\{print \"可用软件包：\" $\(2\)\}\' \> /tmp/1.log\r"
send "awk -F \"=\" \'\/\^SELINUX=\/\{print \"SELINUX状态\：\" $\(2\)\}' /etc/selinux/config \>\> /tmp/1.log\r"
send "hostname \| awk \'\{print \"主机名\：\" $\(1\)\}\' \>\> /tmp/1.log\r"
send "firewall-cmd --list-all \| awk -F \"(\" \'/default/\{print \"防火墙状态：\" $\(1\)\}\' \>\> /tmp/1.log\r"
send "exit\r"
expect eof
EOF
if [ $? -ne 0 ];then
	echo "Password error！"
	exit
fi
#下载日志
expect << EOF &> /dev/null
set time 8
spawn scp -r root@$ip:/tmp/1.log  /tmp/
expect "password" { send "$pass\r" }
send "exit\r"
expect eof
EOF

echo "-------------"
cat /tmp/1.log 
fi

pwd_a=$(pwd)

#定义安装的软件包
read -p "是否需要安装软件包？(y/n)" start_a
start () {
if [ "$start_a" == "y" ];then
#---定格写，TAB会报错！----将安装脚本发送给对端-----
expect << EOF  &> /dev/null
set time 8
spawn scp -r $pwd_a root@$ip:/opt/
expect "password" { send "$pass\r" }
send "exit\r"
expect eof
EOF
	echo "-----安装列表--------"
	echo "(1)LAMP初始环境"
	echo "(2)LNMP初始环境"
	echo "(3)varnish"
	echo "(4)squid"
	echo "(5)nginx"
	echo "(6)tomcat"
	echo "(7)httpd"
	echo "(8)memcheck"
	echo "(9)redis没做好"
	echo "(10)mariadb"
	echo "(11)session共享库"
	echo "(20)退出！"
elif [  -z "$start_a" ];then
	echo "Exited！"
	exit
else 
	echo "Exited！"
	exit
fi
}

choice () {
	while :
	do 
		start
		read -p "please enter a number：" choice_a
		if [ ! -z "$choice_a"  ];then
			break
		fi
	done
}

#定义软件安装函数
#LAMP的基本安装
lamp () {
expect << EOF
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
set timeout -1
send "yum -y install httpd\r"
set timeout -1
send "yum -y install php  php-mysql\r"
set timeout -1
send "yum -y install mariadb mariadb-server mariadb-devel\r"
send "systemctl restart httpd php-fpm mariadb; systemctl enable httpd php-fpm mariadb\r"
send "exit\r"
expect eof
EOF
}
#LNMP的基本安装
lnmp () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb \r"
set timeout -1
send "/bin/bash mariadb.sh\r"
set timeout -1
send "/bin/bash nginx.sh\r"
set timeout -1
send "/bin/bash php.sh\r"
send "exit\r"
expect eof
EOF
}
#varnish的基本安装
varnish () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb\r"
set timeout -1
send "/bin/bash varnish.sh\r"
send "exit\r"
expect eof
EOF
}
#nginx的基本安装
nginx () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb\r"
set timeout -1
send "/bin/bash nginx.sh\r"
send "exit\r"
expect eof
EOF
}
#tomcat的基本安装
tomcat () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb\r"
set timeout -1
send "/bin/bash tomcat_java.sh\r"
send "exit\r"
expect eof
EOF
}
#memcheck的基本安装
memcheck () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb\r"
set timeout -1
send "/bin/bash memcached_php.sh\r"
send "exit\r"
expect eof
EOF
}
#session共享库的基本安装
session () {
expect << EOF
set time 8
spawn ssh -X root@$ip
expect "password" { send "$pass\r" }
expect "]#" 
send "cd /opt/liupb\r"
set timeout -1
send "/bin/bash session.sh\r"
send "exit\r"
expect eof
EOF
}

#调用函数
while :
do
choice
case $choice_a in 
1)
	lamp;;
2)
	lnmp;;
3)
	varnish;;
4)
	session;;
5)
	nginx;;
6)
	tomcat;;
7)		
	httpd;;
8)
	memcheck;;
9)	
	redis;;
10)
	mariadb;;
11)
	session;;
20)	
	exit;;
esac
done
