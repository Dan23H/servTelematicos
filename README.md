# Desarrollo Parcial 2

Realizado por: 
- Daniel Hernández Valderrama - 2210235

## Primera parte del primer punto: Configuración de servicio FTP Seguro

En la máquina seleccionada como maquina2, se instala vsftpd

### 1. Instalar vsftpd
  ```
  sudo apt-get install vsftpd
 ```

### 2. Configurar archivo de configuración de FTP
Una vez instalados, se creará un archivo en etc llamado vsftpd.conf, ahí debemos entrar
   ```
 sudo vim /etc/vsftpd.conf 
   ```
En este archivo se encontrarán algunas configuraciones por defecto que debemos modificar
para habilidar el modo seguro de FTP, en este caso, es necesario buscar y descomentar un
parámetro llamado "write_enable=YES" y agregar algunas líneas de la siguiente forma:

```
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES

write_enable=YES

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

ftpd_banner=Welcome to blah FTP service.

# Usar el certificado que se haya creado anteriormente o usar uno por defecto.
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.key
ssl_enable=YES

# Forzar el uso del SSL
require_ssl_reuse=NO
force_local_logins_ssl=YES
force_local_data_ssl=YES

# Configurar rango de puertos pasivos
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO

# Configurar la IP pública del firewall
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=192.168.50.4
pasv_promiscuous=YES
```

En esta vista previa, he eliminado todos los comentarios para que sea más cómodo identificar
los cambios; se deberán agregar las líneas para forzar el uso del SSL, configurar los puertos
pasivos y configurar la ip pública del firewall.

## Segunda parte del primer punto: Configuración del Firewall
Una vez configurado el archivo de vsftp en la máquina2, debemos configurar el firewall en la máquina1
para que permita redirigir todo el tráfico de FTP hacia la máquina2, que contiene las configuraciones
del mismo servicio.


### 1. Configurar permisos de UFW
En la máquina1 se debe utilizar el siguiente comando:
```
sudo ufw status
```

Nos mostrará si el firewall está activo, posteriormente debemos encenderlo y habilitar los puertos necesarios:

```
sudo ufw enable
```

```
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 22/tcp
sudo ufw allow 40000:50000/tcp
```

Con esto estaríamos permitiendo el uso del FTP y los puertos pasivos del FTP o, en otras palabras, el FTP seguro.
Ahora solo queda reiniciar el servicio para que se apliquen los cambios:
```
sudo systemctl restart vsftpd
```

### 2. Configurar la redirección
Ahora, será necesario modificar los parámetros de redirección en el firewall, para eso debemos entrar en la siguiente
ruta:

```
sudo vim /etc/default/ufw
```

Luego, debemos buscar el parámetro DEFAULT_FORWARD_POLICY="DROP" y modificar el permiso así:
```
DEFAULT_FORWARD_POLICY="ACCEPT"
```

Guardamos y entramos a la siguiente ruta:
```
sudo vim /etc/ufw/sysctl.conf
```

Aquí buscamos un parámetro llamado "net/ipv4/ip_forward=1" y lo descomentamos, debería quedar así:
```
#
# Configuration file for setting network variables. Please note these settings
# override /etc/sysctl.conf and /etc/sysctl.d. If you prefer to use
# /etc/sysctl.conf, please adjust IPT_SYSCTL in /etc/default/ufw. See
# Documentation/networking/ip-sysctl.txt in the kernel source code for more
# information.
#

# Uncomment this to allow this host to route packets between interfaces
net/ipv4/ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1

# Disable ICMP redirects. ICMP redirects are rarely used but can be used in
# MITM (man-in-the-middle) attacks. Disabling ICMP may disrupt legitimate
# traffic to those sites.
net/ipv4/conf/all/accept_redirects=0
net/ipv4/conf/default/accept_redirects=0
net/ipv6/conf/all/accept_redirects=0
net/ipv6/conf/default/accept_redirects=0

# ...
```

Con esto estaríamos habilitando el redireccionamiento en IPv4.
Ahora es necesario modificar las reglas de redirección, para eso entramos a la
siguiente ruta:
```
sudo vim /etc/ufw/before.rules
```

Y agregamos en la parte superior algunas líneas de la siguiente forma:
```
#
# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#

*nat
:POSTROUTING ACCEPT [0:0]

# Redirigir tráfico FTP seguro (puerto 21)
-A PREROUTING -p tcp --dport 21 -j DNAT --to-destination 192.168.50.5:21

# No enmascarar tráfico local
-A POSTROUTING -s 192.168.50.0/24 -o eth1 -j MASQUERADE
-A POSTROUTING -s 192.168.1.0/24 -o eth1 -j MASQUERADE
COMMIT

# Don't delete these required lines, otherwise there will be errors (...)
```

Con todo esto, ya debería quedar la redirección desde los puertos 21 de cualquier máquina hasta
el puerto 21 de la máquina que tiene el servicio de FTP Seguro. Ahora solo queda reiniciar el 
servicio de la siguiente forma:
```
sudo ufw disable && sudo ufw enable
```

## Segundo punto: Firewall para máquinas esclavo-maestro
En la rama parcial1 está la configuración de las máquinas esclavo-maestro, por lo que voy a omitir
esa explicación y pasaré directamente con la configuración del firewall, hay que tener en cuenta
que debe verificar que los archivos resolv.conf dentro de la carpeta /etc/ deben apuntar hacia la
otra máquina, un ejemplo: máquina1 >> máquina2 y máquina2 >> máquina1.

### 1. Configuración del firewall
En la máquina1, la que tiene el firewall del punto anterior, agregamos los siguientes permisos:
```
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

De esta forma estaríamos permitiendo el tráfico de DNS. Ahora solo queda configurarlo, para eso
debemos añadir algunas reglas.

### 2. Configuración de redireccionamiento
```
sudo vim /etc/ufw/before.rules
```

Aquí agregamos dos líneas que redirigan del puerto 53 tcp y udp al puerto 53 de la máquina esclavo:
```
#
# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#

*nat
:POSTROUTING ACCEPT [0:0]

# Redirigir tráfico FTP seguro (puerto 21)
-A PREROUTING -p tcp --dport 21 -j DNAT --to-destination 192.168.50.5:21

# Redirigir tráfico al puerto 53 de la máquina esclavo
-A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 192.168.50.2:53
-A PREROUTING -p udp --dport 53 -j DNAT --to-destination 192.168.50.2:53

# No enmascarar tráfico local
-A POSTROUTING -s 192.168.50.0/24 -o eth1 -j MASQUERADE
-A POSTROUTING -s 192.168.1.0/24 -o eth1 -j MASQUERADE
COMMIT
```

Para comprobarlo, deberás utilizar el comando:
```
nslookup maestro.AlterMega.com 192.168.50.4
```

Y debería poder resolver el URL, apuntando a la máquina maestro así:
```
Server:         192.168.50.4
Address:        192.168.50.4#53

maestro.AlterMega.com   canonical name = ns.AlterMega.com.
Name:   ns.AlterMega.com
Address: 192.168.50.3
```

## Tercer Punto: DNS sobre TLS
