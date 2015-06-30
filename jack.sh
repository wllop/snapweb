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
#Por lo visto, al menos en debian, cuando el script lo llama incrond, lo hace como comando $_ --> /sbin/start-stop-daemon
#Recibido de incron!
#$1 --> Ruta
#$2 --> Fichero
#$3 --> Evento

buscar_excluidos(){ #Comprueba si $1 está en la lista de directorios a excluir de la monitorización
IFS_OLD=$IFS
IFS=';'
for var in $(grep -i "exclude_dir" /etc/snapweb.conf|cut -d= -f2)
do
  if [ "$var" = "$1" ];then
      exit
  fi
done 
IFS=$IFS_OLD
}

lock_on=$(grep -i "lock_on" /etc/snapweb.conf|cut -d= -f2)
if [ "$3" = "IN_CREATE,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
      echo "Parametros: $1 (1) y $2 (2)">>/usr/local/snapweb/msg.log
    if [ "$lock_on" = "0" ];then

      #Actualizo snap_back
      echo "Nuevo Directorio: cp -pfr $1/$2 /usr/local/snapweb/snap_back$1/$2">>/usr/local/snapweb/msg.log
      cp -pfr $1/$2 /usr/local/snapweb/snap_back$1/$2
      buscar_excluidos $1/$2
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      service incron restart
    else
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
      if [  -e  /usr/local/snapweb/snap_back$1/$2 ] ; then 
       #Es una restauración!!
       cp -rfp /usr/local/snapweb/snap_back$1/$2 $1 2>>/usr/local/snapweb/msg.log
       service incron restart #Reiniciar servicio para actualizar inodos
      else
      #Probar el borrado del directorio con rmdir si no está vacío hay que ver qué hacemos. 
      #Crear una carpeta .changes con lo q haya cambiado.
      if [ ! -e /usr/local/snapweb/.changes ];then
         mkdir -p /usr/local/snapweb/.changes
         chmod 750 /usr/local/snapweb/.changes
      fi
       #nombre del fichero será la ruta absoluta, sustituyendo la / por :::
       filesan=$(echo $1/$2|sed 's/\//:_:/g')
      if [ -e /usr/local/snapweb/.changes/$filesan ];then
         rm -fr /usr/local/snapweb/.changes/$filesan 
      fi
       mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
     fi 
    fi
elif [ "$3" = "IN_DELETE,IN_ISDIR" ]; then #Carpeta borrada
   if [ "$lock_on" = "0" ];then
      rm -fr /usr/local/snapweb/snap_back$1/$2
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #Añado a la base los subdirectorios existentes
      if [ ! -e $1/$2 ]; then 
      #Añado a la base los subdirectorios existentes
       if [ -e /usr/local/snapweb/snap_back$1/$2 ];then
        cp -rfp /usr/local/snapweb/snap_back$1/$2 $1 2>>/usr/local/snapweb/msg.log
        service incron restart
        sleep 6
          if [ ! -e $1/$2 ]; then #Eliminación persistente!!!
          cp -rfp /usr/local/snapweb/snap_back$1/$2 $1 2>>/usr/local/snapweb/msg.log
          service incron restart
          fi
        fi
      fi
    fi
elif [ "$3" = "IN_MOVED_TO,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
    if [ "$lock_on" = "0" ];then
      cp -fpr $1/$2 /usr/local/snapweb/snap_back$1/$2
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      service incron restart
    else
      rm -fr $1/$2
    fi
elif [ "$3" = "IN_MOVED_FROM,IN_ISDIR" ]; then #Carpeta borrada
    if [ "$lock_on" = "0" ];then
      rm -fr /usr/local/snapweb/snap_back$1/$2 2>/dev/null
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      if [ ! -e $1/$2 ]; then 
      if [ -e /usr/local/snapweb/snap_back$1/$2 ];then
        cp -rfp /usr/local/snapweb/snap_back$1/$2 $1/$2 2>>/usr/local/snapweb/msg.log
        service incron restart
      fi
    fi
elif [ "$3" = "IN_CREATE" ]; then #Nueva carpeta creada!
    if [ "$lock_on" = "0" ];then
      #Actualizo snap_back
      echo "Nuevo Fichero: cp -pfr $1/$2 $base/$subdir/$2">>/usr/local/snapweb/msg.log
      cp -fpr $1/$2 /usr/local/snapweb/snap_back$1/$2
    else
      echo "Nuevo fichero con lock=1">>/usr/local/snapweb/msg.log     
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
      if [  -e  /usr/local/snapweb/snap_back$1/$2 ] ; then 
       #Es una restauración!!
       echo 
       exit
	    else
        echo "No es restuaración!! -e  /usr/local/snapweb/snap_back$1/$2">>/usr/local/snapweb/msg.log
      #Probar el borrado del directorio con rmdir si no está vacío hay que ver qué hacemos. 
      #Crear una carpeta .changes con lo q haya cambiado.
      if [ ! -e /usr/local/snapweb/.changes ];then
         mkdir -p /usr/local/snapweb/.changes
         chmod 750 /usr/local/snapweb/.changes
      fi
       #nombre del fichero será la ruta absoluta, sustituyendo la / por :::
      filesan=$(echo $1/$2|sed 's/\//:_:/g')
      if [ -e /usr/local/snapweb/.changes/$filesan ];then
         rm -f /usr/local/snapweb/.changes/$filesan 
      fi
       mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
     fi 
    fi
elif [ "$3" = "IN_MOVED_TO" ]; then #Nueva fichero eliminado!
    #Activo el registro de la carpeta!
    if [ "$lock_on" = "0" ];then
      cp -fpr $1/$2 /usr/local/snapweb/snap_back$1/$2
    else
       #Mirar si lo que se quiere crear es una restauración en modo lock_on
        rm -fr $1/$2 2>/dev/null #Redirecciono error por problemas con pureftpd
    fi
elif [ "$3" = "IN_CLOSE_WRITE" ]; then # fichero CAMBIADO!
    #Activo el registro de la carpeta!
     echo "Evento INCLOSE_WRITE lock_on=$lock_on">>/usr/local/snapweb/msg.log
    if [ "$lock_on" = "0" ];then
      if [ -d $1/$2 ];then
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      fi
      cp -fpr $1/$2 /usr/local/snapweb/snap_back$1/$2
    else
      #Mirar si HAY cambios 
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      if  ! diff  /usr/local/snapweb/snap_back$1/$2 $1/$2 ;then 
       #Es una restauración!!
        cp -rfp /usr/local/snapweb/snap_back$1/$2 $1/$2 2>>/usr/local/snapweb/msg.log
        exit
     fi 
    fi

elif [ "$3" = "IN_MOVED_FROM" ]; then #Fichero borrado o movido
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
    if [ "$lock_on" = "0" ];then
      #Elimino de la monitorización --> Pendiente
      rm -fr /usr/local/snapweb/snap_back$1/$2
      rm -fr /etc/incron.d/$(echo $1/$2|tr -d /) 2>/dev/null
    else
      #Añado a la base los subdirectorios existentes
      if [ ! -e $1/$2 ]; then 
      if [ -e /usr/local/snapweb/snap_back$1/$2 ];then
        cp -rfp /usr/local/snapweb/snap_back$1/$2 $1 2>>/usr/local/snapweb/msg.log
    fi
    fi
elif [ "$3" = "IN_DELETE" ]; then #Carpeta borrada
   if [ "$lock_on" = "0" ];then
      rm -fr /usr/local/snapweb/snap_back$1/$2
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      if [ ! -e $1/$2 ]; then 
      #Añado a la base los subdirectorios existentes
      if [ -e /usr/local/snapweb/snap_back$1/$2 ];then
        cp -rfp /usr/local/snapweb/snap_back$1/$2 $1 2>>/usr/local/snapweb/msg.log
      else
         rm -fr $1/$2
      fi
    fi 
  fi
fi
exit