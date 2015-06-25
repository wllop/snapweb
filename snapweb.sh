#/bin/bash
#Copyright 2015 Walter Llop Masia @wllop
#Variables y sanitizamos $1 para poder crear el fichero en /etc/incron.d/$1 sin las /
filesan=$(echo $1|tr -d /)
filetmp=/tmp/JACK$filesan
#Comprobamos que está el módulo incron
incrond -? 2>/dev/null
if [ $? -ne 0 ];  then
 echo "Es necesario instalar el servicio incron en su sistema"
 echo s|apt-get install incron
 if [ $? -ne 0 ];then
   echo "Se ha producido un problema al instalar el servicio incron"
   echo "Consulte con su administrador :P"
   exit
 fi
fi

#Comprobamos parámetros.
if [ ! -d $1 ] || [ "$1" == "" ] || [ "$1" == "-h"];
then
  echo "La sintaxis es:"
  echo "snapweb.sh /ruta/web"
  exit
fi

#Compruebo que el directorio de las snap exista
if [ ! -d /usr/local/snapweb/snap_back ]; then
   mkdir -p /usr/local/snapweb/snap_back
   chmod 750 /usr/local/snapweb/snap_back
fi

if [ ! -d "/usr/local/snapweb/snap_back/$filesan" ]; #Preparamos screenshots
then
   cp -pfr $1 /usr/local/snapweb/snap_back/$filesan
   echo "<?php mail(\"wllop@esat.es\",\"SECURITY REPORT - Nueva Firma\",\"Se ha creado una firma del directorio $1\");?>">$filetmp
   php $filetmp
   rm -fr $filetmp
else
   if [ -e /usr/local/snapweb/snap_back/$filesan.2 ]; then
       rm -fr /usr/local/snapweb/snap_back/$filesan.2 
   fi
   mv -f /usr/local/snapweb/snap_back/$filesan /usr/local/snapweb/snap_back/$filesan.2
   cp -fpr $1 /usr/local/snapweb/snap_back/$filesan
   echo "<?php mail(\"wllop@esat.es\",\"SECURITY REPORT - Nueva Firma\",\"Se ha creado una firma del directorio $1, se ha copiado un historial de dicho directorio.\");?>">$filetmp
   php $filetmp
   rm -fr $filetmp
fi
#Comprobamos que jack.sh estuviera en /usr/local/snapweb/snap_back, sino copiamos o bajamos con wget
if [ ! -e /usr/local/snapweb/jack.sh ]; then
	if [ -e ./jack.sh ]; then
		cp -f ./jack.sh /usr/local/snapweb
		chmod a+x /usr/local/snapweb/jack.sh
	else
		echo "Descargando...."
		wget -nv -T 15 http://desa.webnet.es/snapweb/jack.sh -O /usr/local/snapweb/jack.sh >/dev/null 2>/dev/null
		if [ ! -e /usr/local/snapweb/jack.sh ]; then
			echo "Error: No ha sido posible obtener el fichero jack.sh. Inténtelo más tarde. Gracias."
			exit
		fi 
		chmod a+x /usr/local/snapweb/jack.sh
	fi
fi 

#Damos de alta el fichero en el directorio /etc/incron.d
if [ ! -e /etc/snapweb.conf ];
  then
    echo "Descargando fichero de configuracion...."
    wget -nv -T 15 http://desa.webnet.es/snapweb/snapweb.conf -O /etc/snapweb.conf >/dev/null 2>/dev/null
    if [ ! -e /etc/snapweb.conf ]; then
      echo "Error: No ha sido posible obtener el fichero de configuracion snapweb.cfg. Inténtelo más tarde. Gracias."
      exit
    fi 
fi

if [ -e /etc/incron.d/$filesan ];
then
   rm -f /etc/incron.d/$filesan*
fi
for file in $(find $1 -type d)
do 
 echo "$file IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$filesan
done

#Comprobar que la copia y el orginal son idénticos.
if diff -rq $1 /usr/local/snapweb/snap_back/$filesan; then
	echo "Registro del directorio $1 realizado con éxito."
else
	echo "Hay diferencias entre el directorio $1 y el snapshot creado. Vuelva a lanzar el script."
fi

service incron restart

