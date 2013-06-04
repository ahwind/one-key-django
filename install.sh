#!/bin/bash
#20130603
#install django1.5
py_bin='/usr/local/python/bin'
get_ip=`/sbin/ifconfig |grep 'inet addr:'|egrep -v '127.0.0.1|255.255.255.255'|awk '{print $2}'|awk -F: '{print $2}'|head -n 1`
yum install pcre pcre-devel -y
rpm -ivh *.rpm
if [ $? -ne 0 ];then
echo "install failed"
exit
fi
#set django
tar zxvf Django-1.5.tar.gz
cd Django-1.5
$py_bin/python setup.py install
if [ $? -ne 0 ];then
echo "Django install failed"
exit
fi
cd ..
#setup uwsgi
tar zxvf uwsgi-1.9.5.tar.gz
cd uwsgi-1.9.5
$py_bin/python setup.py install
if [ $? -ne 0 ];then
echo "uwsgi install failed"
exit
fi
cp contrib/centos_init_script /etc/init.d/uwsgid
cd ..
rm -rf Django-1.5 uwsgi-1.9.5
echo -e "\033[1;36mInput Project Name(default 'mysite'):"
read -p "" mysite
if [  -z $mysite ];then
mysite=mysite
fi
echo -e "\033[36;1mstart project...................."
if [ ! -d /www ];then
mkdir /www
fi
cd /www
$py_bin/django-admin.py startproject $mysite
chmod +x /etc/init.d/uwsgid
cat << EOF > /www/${mysite}/uwsgi.ini
[uwsgi]
chdir = /www/${mysite}
module = ${mysite}.wsgi
socket = 127.0.0.1:8000
porcesses = 2
pidfile = /var/run/django_uwsgi.pid
master = True
workers = 4
daemonize = /www/logs/django_uwsgi.log
EOF
sed -i 's#PATH=.*#PATH=/usr/local/python/bin:$PATH#g' /etc/init.d/uwsgid
sed -i 's#^prog=.*#prog=/usr/local/python/bin/uwsgi#g' /etc/init.d/uwsgid
sed -i 's#^DAEMON_OPTS=.*#DAEMON_OPTS="--ini /www/'${mysite}'/uwsgi.ini"#g' /etc/init.d/uwsgid
#set nginx
cat << EOF > /usr/local/nginx/conf/django.conf
server
    {
        listen             80;
        server_name    $get_ip;

        location / {
                root    /www/$mysite/$mysite;
                default_type text/html;
                include uwsgi_params;
                uwsgi_pass 127.0.0.1:8000;
        }
        location ~/static {
                root /www/$mysite/;
        }

}
EOF
sed -i '/server$/i\\include django.conf;' /usr/local/nginx/conf/nginx.conf
/etc/init.d/nginx start
/etc/init.d/uwsgid start
if [ -n $get_ip ];then
echo -e "\033[36;1m#######################################"
echo -e "\033[36;1m##Now,you can visit "http://$get_ip/"##"
echo -e "\033[36;1m#######################################"
echo -e "\033[0m"
fi
