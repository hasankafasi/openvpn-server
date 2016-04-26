#!/bin/bash

if [[ "$USER" != 'root' ]]; then
	echo "Islemi root olarak yapiniz"
	exit
fi


if [[ ! -e /dev/net/tun ]]; then
	echo "TUN/TAP acik degil"
	exit
fi


newclient () {
	cp /usr/share/doc/openvpn*/*ample*/sample-config-files/client.conf ~/$1.ovpn
	sed -i "/ca ca.crt/d" ~/$1.ovpn
	sed -i "/cert client.crt/d" ~/$1.ovpn
	sed -i "/key client.key/d" ~/$1.ovpn
	echo "<ca>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/2.0/keys/ca.crt >> ~/$1.ovpn
	echo "</ca>" >> ~/$1.ovpn
	echo "<cert>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/2.0/keys/$1.crt >> ~/$1.ovpn
	echo "</cert>" >> ~/$1.ovpn
	echo "<key>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/2.0/keys/$1.key >> ~/$1.ovpn
	echo "</key>" >> ~/$1.ovpn
}


IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)

if [[ -e /etc/openvpn/server.conf ]]; then
	while :
	do
	clear
		echo "OpenVPN servisi kurulmus."
		echo ""
		echo "Ne yapmak istiyorsunuz?"
		echo "   1) Yeni bir kullanici icin ekle"
		echo "   2) OpenVPN servisini sil"
		echo "   3) Cikis"
		read -p "Lutfen birini seciniz [1-4]: " option
		case $option in
			1) 
			echo ""
			echo "Lutfen bir kullanici adi yazin"
			echo "Lutfen ozel karakter barindirmayan tek kelime olsun"
			read -p "Kullanici Adi: " -e -i client CLIENT
			cd /etc/openvpn/easy-rsa/2.0/
			source ./vars
			export KEY_CN="$CLIENT"
			export EASY_RSA="${EASY_RSA:-.}"
			"$EASY_RSA/pkitool" --pass $CLIENT
			newclient "$CLIENT"
			echo ""
			echo "Kullanici $CLIENT eklensi, sertifikasi root dizininde ~/$CLIENT.ovpn seklinde olacak"
			exit
			;;
			2) 
			echo ""
			read -p "OpenVPN servisini kaldirmak istiyor musunuz? [y/n]: " -e -i n REMOVE
			if [[ "$REMOVE" = 'y' ]]; then
				if [[ "$OS" = 'debian' ]]; then
					apt-get remove --purge -y openvpn openvpn-blacklist
				else
					yum remove openvpn -y
				fi
				rm -rf /etc/openvpn
				rm -rf /usr/share/doc/openvpn*
				sed -i '/--dport 53 -j REDIRECT --to-port/d' $RCLOCAL
				sed -i '/iptables -t nat -A POSTROUTING -s 10.8.0.0/d' $RCLOCAL
				echo ""
				echo "OpenVPN kaldirildi!"
			else
				echo ""
				echo "Kaldirma iptal edildi!"
			fi
			exit
			;;
			3) exit;;
		esac
	done
else
	clear
	echo 'Welcome to this quick OpenVPN "road warrior" installer'
	echo ""
	echo "I need to ask you a few questions before starting the setup"
	echo "You can leave the default options and just press enter if you are ok with them"
	echo ""
	echo "First I need to know the IPv4 address of the network interface you want OpenVPN"
	echo "listening to."
	read -p "IP address: " -e -i $IP IP
	echo ""
	echo "What port do you want for OpenVPN?"
	read -p "Port: " -e -i 1194 PORT
	echo ""
	echo "Do you want OpenVPN to be available at port 53 too?"
	echo "This can be useful to connect under restrictive networks"
	read -p "Listen at port 53 [y/n]: " -e -i n ALTPORT
	echo ""
	echo "Do you want to enable internal networking for the VPN?"
	echo "This can allow VPN clients to communicate between them"
	read -p "Allow internal networking [y/n]: " -e -i n INTERNALNETWORK
	echo ""
	echo "What DNS do you want to use with the VPN?"
	echo "   1) Current system resolvers"
	echo "   2) OpenDNS"
	read -p "DNS [1-2]: " -e -i 1 DNS
	echo ""
	echo "Finally, tell me your name for the client cert"
	echo "Please, use one word only, no special characters"
	read -p "Client name: " -e -i client CLIENT
	echo ""
	echo "Okay, that was all I needed. We are ready to setup your OpenVPN server now"
	read -n1 -r -p "Press any key to continue..."
		if [[ "$OS" = 'debian' ]]; then
		apt-get update
		apt-get install openvpn iptables openssl -y
	else

		yum install epel-release -y
		yum install openvpn iptables openssl wget -y
	fi

	if [[ -d /etc/openvpn/easy-rsa/2.0/ ]]; then
		rm -f /etc/openvpn/easy-rsa/2.0/
	fi

	wget --no-check-certificate -O ~/easy-rsa.tar.gz https://github.com/OpenVPN/easy-rsa/archive/2.2.2.tar.gz
	tar xzf ~/easy-rsa.tar.gz -C ~/
	mkdir -p /etc/openvpn/easy-rsa/2.0/
	cp ~/easy-rsa-2.2.2/easy-rsa/2.0/* /etc/openvpn/easy-rsa/2.0/
	rm -rf ~/easy-rsa-2.2.2
	rm -rf ~/easy-rsa.tar.gz
	cd /etc/openvpn/easy-rsa/2.0/

	cp -u -p openssl-1.0.0.cnf openssl.cnf

	. /etc/openvpn/easy-rsa/2.0/vars
	. /etc/openvpn/easy-rsa/2.0/clean-all

	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --initca $*

	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --server server

	export KEY_CN="$CLIENT"
	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --pass $CLIENT

	. /etc/openvpn/easy-rsa/2.0/build-dh

	cd /usr/share/doc/openvpn*/*ample*/sample-config-files
	if [[ "$OS" = 'debian' ]]; then
		gunzip -d server.conf.gz
	fi
	cp server.conf /etc/openvpn/
	cd /etc/openvpn/easy-rsa/2.0/keys
	cp ca.crt ca.key dh2048.pem server.crt server.key /etc/openvpn
	cd /etc/openvpn/

	sed -i 's|dh dh1024.pem|dh dh2048.pem|' server.conf
	sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' server.conf
	sed -i "s|port 1194|port $PORT|" server.conf

	case $DNS in
		1) 
		grep -v '#' /etc/resolv.conf | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
			sed -i "/;push \"dhcp-option DNS 208.67.220.220\"/a\push \"dhcp-option DNS $line\"" server.conf
		done
		;;
		2)
		sed -i 's|;push "dhcp-option DNS 208.67.222.222"|push "dhcp-option DNS 208.67.222.222"|' server.conf
		sed -i 's|;push "dhcp-option DNS 208.67.220.220"|push "dhcp-option DNS 208.67.220.220"|' server.conf
		;;
	esac

	if [[ "$ALTPORT" = 'y' ]]; then
		iptables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-port $PORT
		sed -i "1 a\iptables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-port $PORT" $RCLOCAL
	fi

	if [[ "$OS" = 'debian' ]]; then
		sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
	else

		sed -i 's|net.ipv4.ip_forward = 0|net.ipv4.ip_forward = 1|' /etc/sysctl.conf

		if ! grep -q "net.ipv4.ip_forward=1" "/etc/sysctl.conf"; then
			echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
		fi
	fi

	echo 1 > /proc/sys/net/ipv4/ip_forward

	if [[ "$INTERNALNETWORK" = 'y' ]]; then
		iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP
		sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP" $RCLOCAL
	else
		iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP
		sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP" $RCLOCAL
	fi

	if [[ "$OS" = 'debian' ]]; then

		if pgrep systemd-journal; then
			systemctl restart openvpn@server.service
		else
			/etc/init.d/openvpn restart
		fi
	else
		if pgrep systemd-journal; then
			systemctl restart openvpn@server.service
			systemctl enable openvpn@server.service
		else
			service openvpn restart
			chkconfig openvpn on
		fi
	fi


	sed -i "s|remote my-server-1 1194|remote $IP $PORT|" /usr/share/doc/openvpn*/*ample*/sample-config-files/client.conf

	newclient "$CLIENT"
	echo ""
	echo "Finished!"
	echo ""
	echo "Your client config is available at ~/$CLIENT.ovpn"
	echo "If you want to add more clients, you simply need to run this script another time!"
fi
