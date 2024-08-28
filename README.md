# Desarrollo Parcial 1

Realizado por: 
- Daniel Hernández Valderrama - 2210235

## Configuración de Servidor DNS Maestro/Esclavo y Autenticación PAM en Apache
### Primera Parte: Configuracion de DNS Maestro y Esclavo

En la máquina seleccionada como Maestro, se instala Bind9 y sus utilidades Bind9utils

### 1. Instalar Bind9
  ```
  sudo apt-get install bind9 bind9utils
 ```

Una vez instalados, se creará una carpeta en etc llamada bind, ahí debemos entrar
   ```
 /etc/bind 
   ```

En este directorio se encontrarán algunos archivos por defecto que bien podríamos cambiar,
pero para este caso, debemos crear un archivo con el nombre db.<nombre_de_la_empresa>.com
y pegarle la información de db.0 de esta forma:

```
sudo cp db.0 db.AlterMega.com
```

### 2. Se debe modificar el archvio de forma que quede así:
```
;
; BIND data file for local loopback interface
;
$TTL    604800
@       IN      SOA     AlterMega.com. root.AlterMega.com. (
                              4         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.AlterMega.com.
ns      IN      A       192.168.50.3
maestro IN      CNAME   ns
master  IN      CNAME   ns
esclavo IN      A       192.168.50.2
slave   IN      CNAME   esclavo
```

Después de creado el archivo *db.*, procedemos a agregarlo a la configuración
del bind, ubicada en *named.conf.local* 

### 3. El archivo se modifica de la siguiente forma:
```
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";
/*Zona hacia Parcial1*/
zone "AlterMega.com" {
type master;
file "/etc/bind/db.AlterMega.com";
allow-transfer { 192.168.50.2; };
};
/*Zona inversa*/
zone "50.168.192.in-addr.arpa" {
type master;
file "/etc/bind/db.192";
};
```

Con esto, se estaría configurando el bind de la máquina para que sea identificado como
DNS Maestro. En la otra máquina, ha que configurar el mismo archivo, luego de haber instalado
el bind previamente y configurarlo como esclavo

## 4. Instalar Bind9 en el esclavo

```
sudo apt-get install bind9 bind9utils
```

Una vez se termine de instalar Bind9 y sus dependencias, procedemos a entrar al mismo directorio
que el maestro:
```
/etc/bind
```
Luego, entramos al archivo llamado *named.conf.local* 

### 5. Se configura para que la máquina 2 sea esclavo:

```
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";

zone "AlterMega.com" {
type slave;
masters {192.168.50.3; };
file "/var/cache/bind/db.AlterMega.com";
};

```
Con esto estaríamos configurando correctamente a la segunda máquina
como esclavo. Ahora, si una tercera máquina intenta acceder al DNS de
la máquina maestro, deberá consultar con el DNS de la máquina esclavo
primero, pues ahora ese DNS solo recibe consultas de la máquina esclavo.


## Configuracion de PAM y Apache
### Segunda Parte: Configuración de Autenticación PAM en Servidor Apache

Una vez terminada la configuracion de los servidores DNS en el maestro y esclavo,
se procede con la instalación y posterior configuración del apache y autenticación
PAM

### 1. Instalar apache2 en la máquina maestro

```
sudo apt-get install apache2
```

Ya intalado apache2 se nos crea un directorio llamado _apache2_, ubicado en:
```
/etc/apache2
```
Y se configura el archivo **_apache2.conf_** agregando el Directorio:

```
<Directory "/var/www/html/archivos_privados">
    AuthType Basic
    AuthName "Directorio Privado"
    Require valid-user
</Directory>
```

Ya configurado entramos en el directorio _sites-avalaible_ y configuramos el archivo **_000-default.conf_**

```
sudo vim /etc/apache2/sites-available/000-default.conf
```

Aquí agregamos la siguiente configuracion para agregar la autenticación PAM:

```
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
<Directory "/var/www/html/archivos_privados">
AuthType Basic
AuthName "private area"
AuthBasicProvider PAM
AuthPAMService apache
Require valid-user
</Directory>
</VirtualHost>

```

Luego, procedemos a modificar los archivos html que se van a mostrar una vez entren a :

```
/var/www/html
```
En esta ruta creamos el directorio ```/archivos_privados``` el cual contendrá el *index.html* privado,
para configurar esta función, accedemos al archivo **_000-default.conf_** y agregamos el siguiente codigo:

```
<Directory "/var/www/html/archivos_privados">
AuthType Basic
AuthName "private area"
AuthBasicProvider PAM
AuthPAMService apache
Require valid-user
</Directory>

```
Una vez configuradas las páginas que queremos proteger, podemos descargar el PAM

```
apt-get install libapache2-mod-authnz-pam
```
Cuando haya terminado de instalarse, debemos activar el módulo con la siguiente línea
```
a2enmod authnz_pam
```
Mostrará un proceso y al terminar de activar el módulo, podemos crear el archivo de la lista de excluidos ubicados en la carpeta pam.d

```
sudo vim /etc/pam.d/usuarios_denegados
```
El nombre del archivo puede variar según el gusto, pero hay que espcificarle el nombre más adelante a la configuración para que haga su
función. En cuanto al contenido del archivo, aquí deben colocar los nombres de los usuarios que no podrán tener acceso a las páginas
dentro de la carpeta *archivos_privados*

Un ejemplo podría ser:
```
denegado
alfonso
 ```
Luego, debemos crear un archivo llamado "*apache*", el cual tendrá la configuración de los usuarios denegados

```
sudo vim /etc/pam.d/apache
```

Dentro de ese archivo, colocamos lo siguiente:
```
(ingresa la lista)
auth required pam_unix.so
account required pam_unix.so

```
Autenticamos el acceso al servicio apache mediante las cuentas de ubuntu
```
groupadd shadow
usermod -a -G shadow www-data
chown root:shadow /etc/shadow
chmod g+r /etc/shadow'''
```

Para agregar usuarios, es necesario usar el super usuario para ejecutar el comando *adduser* sin problemas
```sudo -i``` Y luego ```adduser nombre_usuario```

Luego de haber hecho todo esto, se debe reiniciar el apache
```
sudo systemctl restart apache2
```

Y listo, ahora solo queda entrar al navegador, colocar la ip del maestro y ver la página. Para comprobar que el PAM
fue exitoso, también se puede acceder a la ubicación de la carpeta, por ejemplo: *http://192.168.50.3/archivos_privados*,
ahí debería aparecer una ventana pidiendo las credenciales (usuario y contraseña) y solamente dejará ingresar a los
usuarios registrados que no estén en el archivo *usuarios_denegados*

## Despliegue con ngrok
Para desplegar la página que previamente hicimos a una url temporal, podemeos utilizar el programa Ngrok que se puede
encontrar libremente en internet, para obtenerlo se pueden registrar y luego podrán elegir si instalarlo con zip o con
*choco*. 

Se descomprime el zip descargado dentro de la carpeta que contiene al vagrant y las máquinas, luego se ejecuta y dentro 
de su consola de comandos se escribe la configuración
```
ngrok config add-authtoken <token de inicio de sesión>
```

esa configuración solo se hará una vez por dispositivo. Luego, para generar la URL deberán colocar el siguiente comando
```
ngrok http 192.168.50.3:80
```

El programa mostrará cómo genera el URL y finalmente te dará el enlace temporal. Si deseas un enlace permanente, puedes
mejorar la cuenta pagando.
