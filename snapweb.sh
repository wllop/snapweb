#/bin/bash
#
# Copyright 2015 Walter LLop Masiá @wllop
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
## Agradecimientos:
# Óscar García Amor
#################### I N O T I F Y 
#Aumento el número de ficheros a monitorizar (si es necesario)!!
#sysctl -w fs.inotify.max_user_watches=524288
#sysctl -p 
#Miro si en el fichero /etc/sysctl.conf ya está el valor dado de alta, sino, lo doy.d
#echo fs.inotify.max_user_watches=524288 >>/etc/sysctl.conf
# sudo sysctl fs.inotify.max_user_watches= with your preferred value at the end.
#Permanently:
#Replace the value within the /proc/sys/fs/inotify/max_user_watches file with your own, i.e echo 524288 | sudo tee -a /proc/sys/fs/inotify/max_user_watches.
#Default value=8192!! 32bits
####################################
##Funciones
installed(){ type -p "$1" 2>/dev/null >/dev/null;}
fatal(){ echo ; echo "Error: $@" >&2;${E:+exit $E};}
help () {
clear
echo "La sintaxis es:"
echo "snapweb.sh [-d] | [-l] /ruta/web"
echo " -d /ruta/web --> Desactiva la monitorización del directorio pasado como parámetro."
echo " -l --> Lista los directorios que están siendo monitorizados por SnapWeb."
exit
}
totales(){ ##Total de ficheros en un directorio - Recursivo
[ ! -d $1 ] && echo 0 && exit
total=0
for fich in $(find $1 -xdev -type f 2>/dev/null)
do
  total=$[$total + 1]
done
echo $total
}
list () {
echo "Directorios monitorizados:"
echo "--------------------------"
total=0
ftotales=0
for dir in $(find /usr/local/snapweb/snap_back/* -maxdepth 0 -type d|grep -v "\.2")
do
	ruta=$(cat $dir/.rutaabs)
  echo "$ruta"
  total=$(totales $ruta)
  ftotales=$[$ftotales + $total]
  echo "      Ficheros monitorizados:$total"
  echo
done
if [ "$dir" = "" ]; then
   echo "No hay directorios monitorizados"
fi
inototal=$(cat /proc/sys/fs/inotify/max_user_watches)
echo "Actualmente están monitorizados $ftotales ficheros de $inototal."
echo "--------------------------"
exit
}

clear
#Mail destino donde se recibirá el informe de firma de snapweb

#Variables y sanitizamos $1 para poder crear el fichero en /etc/incron.d/$1 sin las /
filesan=$(echo $1|tr -d /)
filetmp=/tmp/JACK$filesan
#Comprobamos que está el módulo incron
if ! installed incrond ; then
  echo "Es necesario disponder del servicio incron instalado en su sistema. "
  if installed apt-get; then
      read -n 1 -p "¿Quieres que lo instale automáticamente? (s/n):" var
       if [ "$var" = "s" ]; then
              echo s|apt-get install incron || E=1 fatal "El servicio incron no ha podido instalarse."
       else
              E=2 fatal "Intente ejecutar snapweb.sh una vez tenga instalado el servicio incron."
          exit
       fi
  fi
fi

[ ! -d /usr/local/snapweb ] && mkdir -p -m 750 /usr/local/snapweb 
#Comprobamos que jack.sh estuviera en /usr/local/snapweb/snap_back, sino copiamos o bajamos con wget
if [ ! -e /usr/local/snapweb/jack.sh ]; then
  [ -e $PWD/jack.sh ] && cp -f $PWD/jack.sh /usr/local/snapweb 2>/dev/null >/dev/null && chmod a+x /usr/local/snapweb/jack.sh 2>/dev/null >/dev/null || E=3 fatal "Es necesario el fichero jack.sh para continuar."
fi 

#Damos de alta el fichero de configuración en /etc/snapweb.conf y obtenemos cuenta email.
if [ ! -e /etc/snapweb/snapweb.conf ]; then
  [ -e $PWD/etc/snapweb/snapweb.conf ] && cp -f $PWD/etc/snapweb/snapweb.conf /etc/snapweb/snapweb.conf || E=4 fatal "No ha sido posible obtener el fichero de configuracion snapweb.conf, inténtelo más tarde. Gracias."
else
  mail_destino=$(grep "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
fi
if [ "$mail_destino" = "" ];then
  read -p "Por favor, introduzca la dirección de correo electrónico que recibirá las notificaciones de Snapweb: " mail_destino
  sed -i "s/email=/email=$mail_destino/g" /etc/snapweb/snapweb.conf
fi  
#Damos de alta el fichero de firmas en /etc/snapweb/firmasAV.txt
if [ ! -e /etc/snapweb/firmasAV.txt ]; then
  [ -e $PWD/etc/snapweb/firmasAV.txt ] && cp -f $PWD/etc/snapweb/firmasAV.txt /etc/snapweb/firmasAV.txt || E=5 fatal "No ha sido posible obtener el fichero de firmas firmasAV.txt, inténtelo más tarde. Gracias."
fi

#Compruebo la opción -d
if [ "$1" = "-d" ];then
  if [ ! -d $2 ] || [ "$2" = "" ]; then
    echo "La ruta pasada como parámetro NO es un directorio."
    exit;
  fi
  filesan=$(echo $2|tr -d /)
  if [ -d "/usr/local/snapweb/snap_back/$filesan" ];then #Compruebo que exista snap_back
     rm -fr /etc/incron.d/$filesan* 2>/usr/local/snapweb/msg.log
     if [ "$?" -eq 0 ];then
       rm -fr /usr/local/snapweb/snap_back/$filesan 2>/usr/local/snapweb/snap_back/msg.log
        if [ "$?" -eq 0 ];then
          echo "Se ha deshabilitado correctamente la monitorización de $2."
          echo "Se ha deshabilitado la monitorización sobre el directorio $2"|mail -s "SNAPWEB: Firma eliminada." $mail_destino
          exit
        fi
      fi
      E=5 fatal "Algo ha fallado al intentar deshabilitar el directorio $2. Inténtelo otra vez!"
  fi
 E=6 fatal "El directorio $2 no está siendo monitorizado."
fi

#Comprobamos ayuda.
if [ "$1" == "" ] || [ "$1" == "-h" ];
then
  help
fi

#Comprobamos listado
if [ "$1" == "-l" ]; then
	list
fi

#Compruebo que $1 sea un directorio.

if [ ! -d $1 ];
	then
	echo "La ruta pasada como parámetro NO es un directorio."
    exit;
fi

#Compruebo que el directorio de las snap exista
[ ! -d /usr/local/snapweb/snap_back ] && mkdir -p -m 750 /usr/local/snapweb/snap_back 2>/dev/null

if [ ! -d "/usr/local/snapweb/snap_back/$filesan" ]; #Preparamos screenshots
then
   cp -pfr $1 /usr/local/snapweb/snap_back/$filesan
   ruta=$1
   echo "${#ruta}">/usr/local/snapweb/snap_back/$filesan/.ruta #Con esto convertiremos rutas absolutas en relativas a snap_back
   echo "$ruta">/usr/local/snapweb/snap_back/$filesan/.rutaabs
   echo "Se ha creado una nueva firma del directorio $1"|mail -s "SNAPWEB: Nueva Firma" $mail_destino
else
   [ -e /usr/local/snapweb/snap_back/$filesan.2 ] && rm -fr /usr/local/snapweb/snap_back/$filesan.2 
   ruta=$1
   mv -f /usr/local/snapweb/snap_back/$filesan /usr/local/snapweb/snap_back/$filesan.2
   cp -fpr $1 /usr/local/snapweb/snap_back/$filesan
   echo "${#ruta}">/usr/local/snapweb/snap_back/$filesan/.ruta #Con esto convertiremos rutas absolutas en relativas a snap_back
   echo "Se ha creado una firma del directorio $1"|mail -s "SNAPWEB: Firma reemplazada" $mail_destino
fi

[ -e /etc/incron.d/$filesan ] && rm -f /etc/incron.d/$filesan*
#Excluyos los directorios indicados en la variable exclude_dir
excl_dire=$(grep exclude_dir /etc/snapweb/snapweb.conf|cut -d= -f2)
if [ "$excl_dire" != "" ]; then
  patt=$(echo "$excl_dire"|sed 's/;/ -e /g')
  patt="grep -v -e $patt"
  for file in $(find $1 -type d | $patt)
   do 
    echo "$file IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$filesan
   done
else
  for file in $(find $1 -type d $patt)
do 
 echo "$file IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$filesan
done
fi

#Comprobar que la copia y el orginal son idénticos.
if diff -rq $1 /usr/local/snapweb/snap_back/$filesan|grep -v .ruta >/dev/null 2>&1; then
  echo "Hay diferencias entre el directorio $1 y el snapshot creado. Vuelva a lanzar el script."
else
  echo "Registro del directorio $1 realizado con éxito."
fi
if ! type -p snapweb.sh; then
   echo "Snapweb no está incluido en la variable PATH."
   read -n 1 -p "¿Desea incluirlo en /usr/local/sbin (S/n)" res
   if [ "res" != "n" ]; then
    cp -f ./snapweb.sh /usr/local/sbin/snapweb.sh
   fi
fi
service incron restart

