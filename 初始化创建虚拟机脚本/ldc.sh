#!/bin/bash
LANG=zh_CN.UTF-8
yum -y install expect  &> /dev/null
pass=Taren1
eth=eth0
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
	read -p "输入虚拟机IP：192.168." ip1
	#read -p "输入虚拟机网卡：" eth
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
		IPADDR="192.168.$ip1"
		PREFIX=24" > /tmp/ifcfg-$eth
	virt-copy-in  -d $VMNUM /tmp/ifcfg-$eth /etc/sysconfig/network-scripts/
		echo " "
		echo "$VMNUM已经设置ip: 192.168.$ip1"
	virsh start $VMNUM
  done
fi

#检测
while :  &> /dev/null
do
echo "虚拟机开启中...请您稍等～"
ping -c 2 192.168.$ip1  &> /dev/null
if [ $? -eq 0 ];then
	break 
elif [ $? -ne 0 ];then
	sleep 10	
fi
done




read -p "请您先初始化配置(y/n)" liu
if [ "$liu" == "y" ];then
echo "正在为您进行系统初始化，请勿中断......！"
fi
echo "1.正在初始化配置-更改您的主机名"
sleep 5
echo "2.正在初始化配置-更改您的YUM源"
sleep 5
echo "3.正在初始化配置-更改您的selinux为disabled"
sleep 5
echo "4.正在初始化配置-更改您的防火墙为trusted"
sleep 5
echo "5.正在初始化整体最后配置，请耐心等待"





expect << EOF  &> /dev/null
set time 2
spawn ssh -X root@192.168.$ip1
expect "(yes/no)?" { send "yes\n"; exp_continue }
expect "password" { send "$pass\r" }
expect "password" { send "$pass\r"; exp_continue}
expect "]#" 
#搭建YUM:
send "rm -rf /etc/yum.repos.d/*\r"
send "cd /etc/yum.repos.d/\r"
send "touch /etc/yum.repos.d/liu.repo\r"
send "echo \[liu\] >> /etc/yum.repos.d/liu.repo\r" 
send "echo name=liu >> /etc/yum.repos.d/liu.repo\r"
send "echo enable=1 >> /etc/yum.repos.d/liu.repo\r"
send "echo baseurl=http://192.168.4.254/rhel7.2 >> /etc/yum.repos.d/liu.repo\r"
send "echo gpgcheck=0 >> /etc/yum.repos.d/liu.repo\r"
send "yum clean all\r"
#修改selinux和防火墙
send "sed -i \"s/\.\*/$VMNUM/\" /etc/hostname \r"
send "firewall-cmd --set-default-zone=trusted\r"
send "systemctl stop firewall \r"
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
else  echo "恭喜您，系统已经为您初始化完毕,请您享用"
fi
