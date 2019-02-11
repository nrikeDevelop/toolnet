#!/bin/bash
#
# nrikeDevlelo
# Script create to fast configuration
#


#FUNCTIONS
#get public ip 
IP_PUBLIC=$(wget -qO- ipinfo.io/ip)
IP_PRIVATE="$(hostname -I)"
#IP_LAN=$(nmcli device show | grep IP4.ADDRESS | head -n1 | tr -s " " " " | cut -d " " -f 2 | cut -d "/" -f 1)
IP_LAN=`echo $(hostname -I | cut -d"." -f1,2,3).0/24 `

args=("$@")

#BIND
PATH_NAMEDCONF="/etc/bind/named.conf"

FILE_EXTERNAL_VIEW="db.external.conf"
FILE_INTERNAL_VIEW="db.internal.conf"

PATH_NAMEDCONFLOCAL="/etc/bind/named.conf.allzones"

PATH_EXTERNAL_ZONES="/etc/bind/named.conf.external.zones"
PATH_INTERNAL_ZONES="/etc/bind/named.conf.internal.zones"

#NGINX
PATH_NGINX_SITES_AVAILABLE="/etc/nginx/sites-available/"
PATH_NGINX_SITES_ENABLED="/etc/nginx/sites-enabled/"

#echo Number of arguments: $#
#echo 1st argument: ${args[0]}
#echo 2nd argument: ${args[1]}


##print with color
NC='\033[0m' # No Color
function echo_e(){
	case $1 in 
		red)	echo -e "\033[0;31m$2 ${NC} " ;;
		green) 	echo -e "\033[0;32m$2 ${NC} " ;;
		yellow) echo -e "\033[0;33m$2 ${NC} " ;;
		blue)	echo -e "\033[0;34m$2 ${NC} " ;;
		purple)	echo -e "\033[0;35m$2 ${NC} " ;;
		cyan) 	echo -e "\033[0;36m$2 ${NC} " ;;
		*) echo $1;;
	esac
}

function logo(){
cat << "LOGO" 

MYLOGO

LOGO
}

function is_installed(){
	PACKAGE=$1

	dpkg -s $1 &> /dev/null

	if [ ! $? -eq 0 ]; then
		echo_e red "[-] $PACKAGE  not installed..."
		apt-get install -y $PACKAGE
		echo_e green "[+]  $PACKAGE  is installed"
	fi

}

function yes_or_not(){
	case "$1" in 
	y|Y ) return 0;;
	* ) return 1;;
	esac
}

function is_root(){

if [ $(id -u) = 0 ]
then
	#CHECK PACKAGE 
	is_installed curl
	is_installed bind9
	is_installed letsencrypt
	is_installed certbot
	is_installed python-certbot-nginx  
	is_installed python3-certbot 
	is_installed python3-certbot-nginx  
	is_installed nginx
	is_installed php-fpm 
	is_installed php-mysql
	is_installed tree
else
	echo "You must be root to acces"
	exit 1
fi 
}

function is_valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# If run directly, execute some tests.
if [[ "$(basename $0 .sh)" == 'valid_ip' ]]; then
    ips='
        4.2.2.2
        a.b.c.d
        192.168.1.1
        0.0.0.0
        255.255.255.255
        255.255.255.256
        192.168.0.1
        192.168.0
        1234.123.123.123
        '
    for ip in $ips
    do
        if valid_ip $ip; then stat='good'; else stat='bad'; fi
        printf "%-20s: %s\n" "$ip" "$stat"
    done
fi

function die(){
	exit 0;
}

#FUNCTIONS MENU
function add_domain(){
	
	DOMAIN=${args[1]}
	IP_PUBLIC_INTRODUCED=${args[2]}

	if [ ! $DOMAIN ]
	then
		echo -ne "[+] Introduce your domain : "
		read DOMAIN
	fi

	PATH_VIEWS="/etc/bind/views/$DOMAIN/"

	if [ -d $PATH_VIEWS ]
	then 
		echo_e red "[-] Domain already exists"
		echo_e yellow "[-] You can add CNAME in this domain"
		die
	else
		mkdir -p $PATH_VIEWS
	fi

	if [ ! $IP_PUBLIC_INTRODUCED ]
	then
		IP_PUBLIC_INTRODUCED=$IP_PUBLIC
		echo ""
		echo "Your private network is 	"$IP_PRIVATE
		echo "Your private IP is 		"$IP_LAN	
		echo "Your public IP is 		"$IP_PUBLIC_INTRODUCED
		echo ""
		echo -ne "Use this public ip ? (y/n) :"
		read option 
		if ! yes_or_not $option
		then 
			echo ""
			echo -ne "Introduce your public ip :"
			read NEW_IP

			if ! is_valid_ip $NEW_IP
			then
				rm -r $PATH_VIEWS
				echo_e red "[-] IP $IP_PRIVATE_INTRODUCED it is wrong" 
				die
			fi

	        IP_PUBLIC_INTRODUCED=$NEW_IP
		fi
	fi

		echo_e yellow "[+]  $PATH_VIEWS  creating..." 
		mkdir -p $PATH_VIEWS

		cd $PATH_VIEWS
		echo '$ORIGIN '$DOMAIN'.'							>>$FILE_EXTERNAL_VIEW
		echo '$TTL	86400'									>>$FILE_EXTERNAL_VIEW
		echo '@	IN	SOA	ns1. root.localhost. ('				>>$FILE_EXTERNAL_VIEW
		echo 			'1		; Serial'					>>$FILE_EXTERNAL_VIEW
		echo 			'604800		; Refresh'				>>$FILE_EXTERNAL_VIEW
		echo 			'86400		; Retry'				>>$FILE_EXTERNAL_VIEW
		echo 			'2419200		; Expire'			>>$FILE_EXTERNAL_VIEW
		echo 			'86400 )	; Negative Cache TTL'	>>$FILE_EXTERNAL_VIEW
		echo ';'											>>$FILE_EXTERNAL_VIEW
		echo '@	IN	NS	ns1'								>>$FILE_EXTERNAL_VIEW
		echo '@	IN	PTR	mail'								>>$FILE_EXTERNAL_VIEW
		echo '@	IN	MX	10 mail'							>>$FILE_EXTERNAL_VIEW
		echo "ns1	IN	A	$IP_PUBLIC_INTRODUCED"			>>$FILE_EXTERNAL_VIEW
		echo "mail	IN	A	$IP_PUBLIC_INTRODUCED"			>>$FILE_EXTERNAL_VIEW

		echo_e green "[+] $PATH_VIEWS$FILE_EXTERNAL_VIEW  added" 

		echo '$ORIGIN '$DOMAIN'.'							>>$FILE_INTERNAL_VIEW
		echo '$TTL	86400'									>>$FILE_INTERNAL_VIEW
		echo '@	IN	SOA	ns1. root.localhost. ('				>>$FILE_INTERNAL_VIEW
		echo 			'1		; Serial'					>>$FILE_INTERNAL_VIEW
		echo 			'604800		; Refresh'				>>$FILE_INTERNAL_VIEW
		echo 			'86400		; Retry'				>>$FILE_INTERNAL_VIEW
		echo 			'2419200		; Expire'			>>$FILE_INTERNAL_VIEW
		echo 			'86400 )	; Negative Cache TTL'	>>$FILE_INTERNAL_VIEW
		echo ';'											>>$FILE_INTERNAL_VIEW
		echo '@	IN	NS	ns1'								>>$FILE_INTERNAL_VIEW
		echo '@	IN	PTR	mail'								>>$FILE_INTERNAL_VIEW
		echo '@	IN	MX	10 mail'							>>$FILE_INTERNAL_VIEW
		echo 'ns1	IN	A	'$IP_PRIVATE					>>$FILE_INTERNAL_VIEW
		echo 'mail	IN	A	'$IP_PRIVATE					>>$FILE_INTERNAL_VIEW

		echo_e green "[+] $PATH_VIEWS$FILE_INTERNAL_VIEW  added"

		
		rm -r $PATH_NAMEDCONF
		echo 'include "/etc/bind/named.conf.options";'>>$PATH_NAMEDCONF
		echo 'include "/etc/bind/named.conf.allzones";'>>$PATH_NAMEDCONF


		if [ ! -f $PATH_NAMEDCONFLOCAL ]
		then
		echo '
		view "external" {
			match-clients { any; };
			allow-recursion { any; };
			recursion no;
				include "'$PATH_EXTERNAL_ZONES'";
				include "/etc/bind/named.conf.default-zones";
		};

		acl interna { 
			'$IP_PRIVATE'; 
			localhost; 
		};

		view internal {
			match-clients { interna; };
			allow-recursion { any; };  
				include "'$PATH_INTERNAL_ZONES'"; 
				include "/etc/bind/named.conf.default-zones";
		};' >>$PATH_NAMEDCONFLOCAL
				
		fi

		#ADD EXTERNAL AND INTERNAL ZONES
EXTERNAL_ZONES=$PATH_VIEWS"external-zones"

echo 'include "'$EXTERNAL_ZONES'";' >> $PATH_EXTERNAL_ZONES	

echo '
zone "'$DOMAIN'" {
	type master;
	file "'$PATH_VIEWS$FILE_EXTERNAL_VIEW'";
};' >> $EXTERNAL_ZONES	

INTERNAL_ZONES=$PATH_VIEWS"internal-zones"

echo 'include "'$INTERNAL_ZONES'";' >> $PATH_INTERNAL_ZONES

echo '
zone "'$DOMAIN'" {
	type master;
	file "'$PATH_VIEWS$FILE_INTERNAL_VIEW'";
};' >> $INTERNAL_ZONES		


		echo_e green "[+] Configuration finished" 
		
		sudo service bind9 stop
		sudo service bind9 start

		echo_e yellow "[?] Check your domain ns1.$DOMAIN" 
		echo_e yellow "[?] ex: dig ns1.$DOMAIN @127.0.0.1" 
		echo_e yellow "[?] ex: dig mx $DOMAIN @127.0.0.1" 


	
	die
}

function remove_domain(){
	DOMAIN=${args[1]}
	
	#CHECK DOMAIN
	if [ ! $DOMAIN ]
	then
		echo -ne "[+] Introduce domain : "
		read DOMAIN
	fi

	PATH_VIEWS="/etc/bind/views/$DOMAIN"
	if [ ! -d $PATH_VIEWS ]
	then 
		echo_e red "[-] Domain $DOMAIN not found" 
		die
	fi
	
	rm -r $PATH_VIEWS
	cat $PATH_EXTERNAL_ZONES | grep -v "/$DOMAIN/" > $PATH_EXTERNAL_ZONES".BACKUP"
	rm $PATH_EXTERNAL_ZONES 
	mv $PATH_EXTERNAL_ZONES".BACKUP" $PATH_EXTERNAL_ZONES

	cat $PATH_INTERNAL_ZONES | grep -v "/$DOMAIN/" > $PATH_INTERNAL_ZONES".BACKUP"
	rm $PATH_INTERNAL_ZONES 
	mv $PATH_INTERNAL_ZONES".BACKUP" $PATH_INTERNAL_ZONES

	service bind9 restart

	echo_e red "[-] Domain $DOMAIN has been removed" 	
}

function add_cname(){
	DOMAIN=${args[1]}
	CNAME=${args[2]}
	IP_PRIVATE_INTRODUCED=${args[3]}

	#GET DATA IF IT IS NOT INTRODUCED

	#CHECK DOMAIN
	if [ ! $DOMAIN ]
	then
		echo -ne "[+] Introduce domain : "
		read DOMAIN
	fi

	PATH_VIEWS="/etc/bind/views/$DOMAIN/"
	if [ ! -d $PATH_VIEWS ]
	then 
		echo_e red "[-] Domain $DOMAIN not found" 
		die
	fi

	#CHECK CNAME
	if [ ! $CNAME ]
	then
		echo -ne "[+] Introduce CNAME : "
		read CNAME
	fi

	CNAME_EXIST=$(cat /etc/bind/views/$DOMAIN/db.external.conf | grep -P "$CNAME\t" | tr -s "\t" "_")
	if [ ! -z $CNAME_EXIST ]
	then
		echo_e red "[-] CNAME $CNAME already exist" 
		die
	fi

	#CHECK IP
	if [ ! $IP_PRIVATE_INTRODUCED ]
	then
		echo -ne "[+] Introduce private IP : "
		read IP_PRIVATE_INTRODUCED
	fi

	if ! is_valid_ip $IP_PRIVATE_INTRODUCED 
	then 
		echo_e red "[-] IP $IP_PRIVATE_INTRODUCED it is wrong" 
		die
	fi

	#ALL CHECKED TRUE
	echo ''$CNAME'	IN	CNAME	ns1' >> $PATH_VIEWS$FILE_EXTERNAL_VIEW
	echo ''$CNAME'	IN	A	'$IP_PRIVATE_INTRODUCED'' >> $PATH_VIEWS$FILE_INTERNAL_VIEW

	echo_e green "[+] Reconfigured $PATH_VIEWS$FILE_EXTERNAL_VIEW " 
	echo_e green "[+] Reconfigured $PATH_VIEWS$FILE_INTERNAL_VIEW " 
	echo_e yellow "[?] Check your domain $CNAME.$DOMAIN" 
	echo_e yellow "[?] ex: dig $CNAME.$DOMAIN @127.0.0.1" 

	service bind9 restart
}

function remove_cname(){
	DOMAIN=${args[1]}
	CNAME=${args[2]}

	#CHECK DOMAIN
	if [ ! $DOMAIN ]
	then
		echo -ne "[+] Introduce domain : "
		read DOMAIN
	fi

	PATH_VIEWS="/etc/bind/views/$DOMAIN/"
	if [ ! -d $PATH_VIEWS ]
	then 
		echo_e red "[-] Domain $DOMAIN not found" 
		die
	fi

	#CHECK CNAME
	if [ ! $CNAME ]
	then
		echo -ne "[+] Introduce CNAME : "
		read CNAME
	fi

	CNAME_EXIST=$(cat /etc/bind/views/$DOMAIN/db.external.conf | grep -P "$CNAME\t" | tr -s "\t" "_")
	if [ -z $CNAME_EXIST ]
	then
		echo_e red "[-] CNAME $CNAME not exist" 
		die
	fi


	PATH_VIEWS="/etc/bind/views/$DOMAIN/"
	

	cat $PATH_VIEWS$FILE_EXTERNAL_VIEW | grep -v $CNAME > $PATH_VIEWS$FILE_EXTERNAL_VIEW".BACKUP"
	rm $PATH_VIEWS$FILE_EXTERNAL_VIEW
	mv $PATH_VIEWS$FILE_EXTERNAL_VIEW".BACKUP" $PATH_VIEWS$FILE_EXTERNAL_VIEW

	cat $PATH_VIEWS$FILE_INTERNAL_VIEW | grep -v $CNAME > $PATH_VIEWS$FILE_INTERNAL_VIEW".BACKUP"
	rm $PATH_VIEWS$FILE_INTERNAL_VIEW
	mv $PATH_VIEWS$FILE_INTERNAL_VIEW".BACKUP" $PATH_VIEWS$FILE_INTERNAL_VIEW

	service bind9 restart
	echo_e yellow "[-] CNAME $CNAME has been removed" 

}

function create_http_proxy(){

	DOMAIN=${args[1]}
	CNAME=${args[2]}
	IP_REDIRECT=${args[3]}

	#CHECK DOMAIN
	if [ ! $DOMAIN ]
	then
		echo -ne "[+] Introduce DOMAIN of the servername : "
		read DOMAIN
	fi

	#CHECK CNAME
	if [ ! $CNAME ]
	then
		echo -ne "[+] Introduce CNAME of the servername : "
		read CNAME
	fi
	
	for i in $(ls /etc/bind/views/ )
	do
		echo $i
		#CHECK DOMAIN
		if [[ $i == $DOMAIN ]]
		then
			#CHECK CNAME
			CHECKCNAME=$(cat /etc/bind/views/$DOMAIN/$FILE_EXTERNAL_VIEW | grep $CNAME )
			if [ -z $(echo $CHECKCNAME | tr -s " " "_") ]
			then
				#NOT EXIST
				echo_e red "[-] CNAME $CNAME is not exist in your DNS" 
				die
			fi 

			#CHECK IF EXIST IN NGINX
			if [ -f $PATH_NGINX_SITES_ENABLED'http_proxy.'$SERVERNAME ]
			then
				echo_e red "[-] $PATH_NGINX_SITES_AVAILABLEhttp_proxy.$SERVERNAME already exist"
				die
			fi

			#CHECK IP_REDIRECT
			if [ ! $IP_REDIRECT ]
			then
				echo -ne "[+] Introduce redirect ip : "
				read IP_REDIRECT
			fi

			if ! is_valid_ip $IP_REDIRECT 
			then
				echo_e red "[-] IP $IP_REDIRECT it is wrong" 
				die
			fi
echo '
server {
    listen 80;
    server_name '$CNAME'.'$DOMAIN';
    location / {
	proxy_set_header Host  $host;
    proxy_set_header X-Real-IP $remote_addr;
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-Proto $scheme;
	proxy_pass http://'$IP_REDIRECT';

	}

}' > $PATH_NGINX_SITES_AVAILABLE"http_proxy."$CNAME"."$DOMAIN

		ln -s $PATH_NGINX_SITES_AVAILABLE"http_proxy."$CNAME"."$DOMAIN $PATH_NGINX_SITES_ENABLED
		service nginx reload

		echo_e yellow "[+] $PATH_NGINX_SITES_AVAILABLE""http_proxy.$SERVERNAME created"
		echo_e yellow "[+] $PATH_NGINX_SITES_ENABLED""http_proxy.$SERVERNAME created"
		echo_e green "[+] nginx has been configured"
	
		die
		fi
	done
	echo_e red "[-] Domain is not exist in your DNS"
}

function create_https_proxy(){

	DOMAIN=${args[1]}
	CNAME=${args[2]}
	IP_REDIRECT=${args[3]}
	WEB_ROOT=${args[4]}

	if [ ! $DOMAIN ]
	then
		echo_e red "[-] Introduce DOMAIN CNAME IP_REDIRECT WEB_ROOT";
		die();
	fi

	if [ ! $CNAME ]
	then
		echo_e red "[-] Introduce DOMAIN CNAME IP_REDIRECT WEB_ROOT";
		die();
	fi

	if [ ! $IP_REDIRECT ]
	then
		echo_e red "[-] Introduce DOMAIN CNAME IP_REDIRECT WEB_ROOT";
		die();
	fi

	if [ ! $WEB_ROOT ]
	then
		echo_e red "[-] Introduce DOMAIN CNAME IP_REDIRECT WEB_ROOT";
		die();
	fi

	create_http_proxy()
	
	certbot certonly --cert-name $DOMAIN --renew-by-default -a webroot -n --expand --webroot-path=$WEB_ROOT -d $CNAME.$DOMAIN

	rm $PATH_NGINX_SITES_AVAILABLE"http_proxy."$CNAME"."$DOMAIN

echo '
server {
        listen         80;
        server_name '$CNAME'.'$DOMAIN';
        #return         301 https://$host$request_uri;
        return 301 		https://'$CNAME'.'$DOMAIN';
}

server {
        listen 443;
        server_name '$CNAME'.'$DOMAIN';

        ssl_certificate /etc/letsencrypt/live/'$DOMAIN'/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/'$DOMAIN'/privkey.pem;
        ssl on;

        location / {
                proxy_set_header Host  $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;

                proxy_pass http://'$IP_REDIRECT';
        }
}' > $PATH_NGINX_SITES_AVAILABLE"https_proxy."$CNAME"."$DOMAIN

service nginx restart

}

function create_http_container(){
	SERVERNAME=${args[1]}
	PATH_CONTAINER=${args[2]}

	#CHECK SERVERNAME
	if [ ! $SERVERNAME ]
	then
		echo -ne "[+] Introduce ServerName : "
		read SERVERNAME
	fi

	if [ -f $PATH_NGINX_SITES_AVAILABLE"http_container.$SERVERNAME" ]
	then
		echo_e red "[-] $SERVERNAME configuration already exists"
		die
	fi

	#CHECK PATH
	if [ ! $PATH_CONTAINER ]
	then
		echo -ne "[+] Introduce web path : "
		read PATH_CONTAINER
	fi

	if [ ! -d $PATH_CONTAINER ]
	then 
		echo_e red "[-] $PATH_CONTAINER not exist"
		mkdir -p $PATH_CONTAINER
echo '
<h1>HTTP WEB CONTAINER</h1>
<p>
Copy web content on '$PATH_CONTAINER'
<br>
happy coding
</p>
' > $PATH_CONTAINER"/index.html"
		echo_e green "[+] $PATH_CONTAINER has been created"
	fi

VERSION_FPM=$(php --version | grep  "PHP 7" | tr -s " " "_"| cut -d "_" -f 2 | cut -d"." -f 1,2);
echo '
server{
	listen 80 ;
	root '$PATH_CONTAINER';
	index index.html index.htm index.nginx-debian.html index.php;
	server_name '$SERVERNAME';
	error_page  404     /404.html;
	error_page  403     /403.html;
    error_page  405     =200 $uri;
	
	location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php'$VERSION_FPM'-fpm.sock;
    }

}' > $PATH_NGINX_SITES_AVAILABLE"http_container.$SERVERNAME"

		ln -s $PATH_NGINX_SITES_AVAILABLE"http_container.$SERVERNAME" $PATH_NGINX_SITES_ENABLED
		service php$VERSION_FPM-fpm start

		service nginx reload
		echo_e green "[+] nginx configurated"
		echo_e green "[+] Visit http://$SERVERNAME"



}

function create_https_container(){
	create_http_container
	SERVERNAME=${args[1]}
	PATH_CONTAINER=${args[2]}

	echo $PATH_CONTAINER

	certbot --authenticator webroot --installer nginx --webroot-path $PATH_CONTAINER -d $SERVERNAME --email webroot@gmail.com --agree-tos --redirect
	echo_e yellow "[?] If SSL error, try command : "
	echo_e yellow "[?] certbot --authenticator webroot --installer nginx --webroot-path PATH_CONTAINER -d SERVERNAME --email webroot@gmail.com --agree-tos --redirect"
	echo_e yellow "[+] Configuration https finalized"
}

function show-bind-structure(){
	OPTION=${args[1]}
	case $OPTION in
		"all")
		tree /etc/bind/ | grep -v "db.0" | grep -v "db.255" | grep -v "db.127" | grep -v "db.empty" | grep -v "db.local" | grep -v "bind.keys" | grep -v "named.conf.option" | grep -v "named.conf.local" | grep -v "rndc.key" | grep -v "named.conf.default-zones" | grep -v "zones.rfc1918"
		die ;;
		"simple")
		tree -L 2 /etc/bind/ | grep -v "db.0" | grep -v "db.255" | grep -v "db.127" | grep -v "db.empty" | grep -v "db.local" | grep -v "bind.keys" | grep -v "named.conf.option" | grep -v "named.conf.local" | grep -v "rndc.key" | grep -v "named.conf.default-zones" | grep -v "zones.rfc1918"
		die ;;
		*)
		echo_e red "[-] Not option selected"
		;;
	esac


}

function install(){

	if [ -f "/usr/sbin/toolnet" ]
	then 
		rm -r /usr/sbin/toolnet
		cp ./toolnet.sh /usr/sbin/toolnet
	else
		cp ./toolnet.sh /usr/sbin/toolnet
	fi	
	echo_e green "[+] bindgenerator installed in /usr/sbin like toolnet "
}


function helper(){

	#logo
echo '
bindgenerator 
	[BIND OPTIONS]
	--add-domain			[domain_name] [ip]
	--add-cname 			[domain_name] [cname] [ip]
	--remove-domain			[domain_name]
	--remove-cname			[domain_name] [cname]
	--show-bind-structure		[all|simple] 
	
	[NGINX OPTIONS]
	--create-http-proxy		[domain_name] [cname] [ip]
	--create-http-container		[nameserver] [path_web]
	--create-https-container	[nameserver] [path_web] {only in online server}	

	[COMMON OPTIONS]
	--install 
	--remove-all 

'	
	die 
}

function init_menu(){
	case ${args[0]} in
		"--help"|"-h")
			helper ;;
		"--add-domain")
			add_domain 
			die	;;
		"--remove-domain")
			remove_domain
			die;;
		"--add-cname")
			add_cname
			die;;
		"--remove-cname")
			remove_cname
			die;;
		"--create-http-proxy")
			create_http_proxy
			die;;
		"--create-https-proxy")
			
			die;;
		"--create-http-container")
			create_http_container
			die;;
		"--create-https-container")
			create_https_container
			die;;
		"--show-bind-structure")
			show-bind-structure
			die;;
		"--install")
			install
			die ;;
		"--remove-all")
			echo_e yellow "[?] reinstall bind"
			echo_e yellow "[?] reinstall nginx"
			echo_e yellow "[?] rm -r /etc/bind/"
			echo_e yellow "[?] rm -r /etc/nginx/sites-available/*"
			echo_e yellow "[?] rm -r /etc/nginx/sites-enabled/*"
			echo_e yellow "[?] rm -r /var/www/html/*"

			echo -ne "[+] Are you sure? (y/n): "
			read OPTION
			if yes_or_not $OPTION
			then
			
					rm -r /etc/bind/
					apt-get purge bind9 --autoremove -y
					apt-get install bind9 -y

					apt-get purge nginx --autoremove -y
					apt-get install nginx -y

					service nginx restart
					service bind9 restart

					rm -r /var/www/html/*
					rm -r /etc/nginx/sites-available/*
					rm -r /etc/nginx/sites-enabled/*


				echo ""
				echo_e red " [+] All droped"
				echo ""
			fi
			die ;;
		*)
		helper 
		die ;;

	esac
}

#MAIN

##CHECK ROOT
is_root
echo 
init_menu 
