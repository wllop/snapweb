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

row_count(){ #Para poder ir eliminado "directorios" hasta encontrar la base
  IFS_OLD=$IFS
  IFS=$/
  i=$(echo $1|wc -w)
  IFS=$IFS_OLD
  return $i
}

base_snap(){ #Saber el directorio base_snap que está en snap_back
  temp=$(echo $1|tr -d /)
  if [ -d /usr/local/snapweb/snap_back/$temp ];then
    echo "/usr/local/snapweb/snap_back/$temp"
  else
  row_count $1
  filas=$?
  base_snap $(echo $1|cut -d/ -f1-$filas )
  fi
}
base_incron(){ #Devuelvo el directorio base de incron!
  temp=$(echo $1|tr -d /)
  for fich in $(ls /etc/incron.d)
  do
    if echo $temp|grep $fich >/dev/null;
      then
        echo "/etc/init.d/$fich" 
      fi
  done
}
buscar_excluidos(){ #Comprueba si $1 está en la lista de directorios a excluir de la monitorización
IFS_OLD=$IFS
IFS=;
for var in $(grep -i "exclude_dir" /etc/snapweb.conf|cut -d=-f2)
do
  if [ "$var" = "$1"];then
       echo 0
       exit
  fi
done 
echo 1
IFS=$IFS_OLD
}
lock_on=$(grep -i "lock_on=" /etc/snapweb.conf|cut -d= -f2)
if [ "$3" = "IN_CREATE,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
      basei=base_incron $1
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
    if [ "$lock_on" = "0" ];then
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      #echo "Se ha creado el directorio: $1/$2">>/usr/local/snapweb/msg.log
      #Compruebo que el directorio no esté en la lista de exluidos
      if buscar_excluidos $2; then
         echo "Directorio Excluido: $2" >>/usr/local/snapweb/exclude.log
         exit
      fi  
      #Actualizo snap_back
      echo "Nuevo Directorio: cp -pfr $1/$2 $base/$subdir/$2">>/usr/local/snapweb/msg.log
      cp -fpr $1/$2 $base/$subdir/$2
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      service incron restart
    else
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
      if [  -e  $base/$subdir/$2 ] ; then 
       #Es una restauración!!
       cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
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
      #Elimino de la monitorización --> Pendiente
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      #service incron restart
      #Actualizo snap_back
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      rm -fr $base/$subdir/$2
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      echo "Se ha eliminado el directorio: $1/$2">>/usr/local/snapweb/msg.log
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #echo "Recibido: $1 - $2 - $3 - $4">>/usr/local/snapweb/msg.log
      if [ ! -e $1/$2 ]; then 
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      #echo "Filas1: $filas1 y Filas2: $filas2">>/usr/local/snapweb/msg.log
      #Añado a la base los subdirectorios existentes
      subdir=$(echo $1|cut -d/ -f$filas1- )
      echo "Ruta final:$base/$subdir/$2">>/usr/local/snapweb/msg.log
        if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        echo "Se ha intentado eliminar el directorio: $1/$2, aunque se ha restaurado correctamente!">>/usr/local/snapweb/msg.log
        service incron restart
        else
        echo "Se ha eliminado el directorio: $1/$2 y no ha podido ser restaurado ya que no hay copia en backup">>/usr/local/snapweb/msg.log
        fi
      fi
    fi
elif [ "$3" = "IN_MOVED_TO,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
    if [ "$lock_on" = "0" ];then
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      cp -fpr $1/$2 $base/$subdir/$2
      echo "Se ha renombrado el directorio $1/$2 $base/$subdir/$2">>/usr/local/snapweb/msg.log
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      service incron restart
    else
      rm -fr $1/$2
      echo "Se ha eliminado un directorio que había sido creado tras mover carpeta">>/usr/local/snapweb/msg.log
    fi
elif [ "$3" = "IN_MOVED_FROM,IN_ISDIR" ]; then #Carpeta borrada
    if [ "$lock_on" = "0" ];then
      #Elimino de la monitorización --> Pendiente
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      rm -fr $base/$subdir/$2 2>/dev/null
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #echo "Recibido: $1 - $2 - $3 - $4">>/usr/local/snapweb/msg.log
      if [ ! -e $1/$2 ]; then 
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      #echo "Filas1: $filas1 y Filas2: $filas2">>/usr/local/snapweb/msg.log
      #Añado a la base los subdirectorios existentes
      subdir=$(echo $1|cut -d/ -f$filas1- )
      echo "Ruta final:$base/$subdir/$2">>/usr/local/snapweb/msg.log
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1/$2 2>>/usr/local/snapweb/msg.log
        echo "Se ha intentado mover el directorio: $1/$2, aunque se ha restaurado correctamente!">>/usr/local/snapweb/msg.log
        service incron restart
      else
        echo "Se ha movido el directorio: $1/$2 y no ha podido ser restaurado ya que no hay copia en backup">>/usr/local/snapweb/msg.log
      fi
      fi
    fi
elif [ "$3" = "IN_CREATE" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
    if [ "$lock_on" = "0" ];then
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      #echo "Se ha creado el directorio: $1/$2">>/usr/local/snapweb/msg.log
      #Actualizo snap_back
      echo "Nuevo Fichero: cp -pfr $1/$2 $base/$subdir/$2">>/usr/local/snapweb/msg.log
      cp -fpr $1/$2 $base/$subdir/$2
    else
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
      if [  -e  $base/$subdir/$2 ] ; then 
       #Es una restauración!!
       cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
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
         rm -f /usr/local/snapweb/.changes/$filesan 
      fi
       mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
     fi 
    fi
elif [ "$3" = "IN_MOVED_TO" ]; then #Nueva fichero eliminado!
    base=$(base_snap $1)
    row_count $base
    filas1=$(echo $[$? + 1])
    subdir=$(echo $1|cut -d/ -f$filas1- ) 
    #Activo el registro de la carpeta!
    if [ "$lock_on" = "0" ];then
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      cp -fpr $1/$2 $base/$subdir/$2
      echo "Se ha creado / eliminado el fichero que se ha movido/creado: $1/$2">>/usr/local/snapweb/msg.log
    else
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
            echo "Se ha Evento:$3 creado / eliminado el fichero que se ha movido/creado: $1/  -- $2">>/usr/local/snapweb/msg.log
            echo "Base: $base Subdir: $subdir: $1/$2">>/usr/local/snapweb/msg.log 
      #if [  -e  $base/$subdir/$2 ]; then 
       #Es una restauración!!
     #   cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
     # elif  diff $base/$subdir/$2 $1/$2; thennano
     #   echo "Ya se ha restaurado!!" >>/usr/local/snap_back/msg.local
     # else
      #Probar el borrado del directorio con rmdir si no está vacío hay que ver qué hacemos. 
      #Crear una carpeta .changes con lo q haya cambiado.
      #if [ ! -e /usr/local/snapweb/.changes ];then
       #  mkdir -p /usr/local/snapweb/.changes
       #  chmod 750 /usr/local/snapweb/.changes
      #fi
       #nombre del fichero será la ruta absoluta, sustituyendo la / por :::
       #filesan=$(echo $1/$2|sed 's/\//:_:/g')
      #if [ -e /usr/local/snapweb/.changes/$filesan ];then
        #rm -fr /usr/local/snapweb/.changes/$filesan 
      #fi
      #mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
        rm -fr $1/$2 2>/dev/null #Redirecciono error por problemas con pureftpd
        echo "Se ha eliminado un fichero que había sido creado tras eliminar fichero: $base/$subdir/$2   -- $1/$2">>/usr/local/snapweb/msg.log
     #fi 
    fi
elif [ "$3" = "IN_CLOSE_WRITE" ]; then # fichero CAMBIADO!
    #Activo el registro de la carpeta!
    base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
    if [ "$lock_on" = "0" ];then
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      echo "Se ha eliminado el fichero que se ha movido/creado: $1/$2">>/usr/local/snapweb/msg.log
      cp -fpr $1/$2 $base/$subdir/$2
  
    else
      #Mirar si HAY cambios 
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      if  ! diff  $base/$subdir/$2 $1/$2 ;then 
       #Es una restauración!!
        cp -rfp $base/$subdir/$2 $1/$2 2>>/usr/local/snapweb/msg.log
      else
      echo "diff Evento:$3 $base/$subdir/$2 $1/$2">>/usr/local/snapweb/msg.log
    
      exit;
      #Probar el borrado del directorio con rmdir si no está vacío hay que ver qué hacemos. 
      #Crear una carpeta .changes con lo q haya cambiado.
      #if [ ! -e /usr/local/snapweb/.changes ];then
       #  mkdir -p /usr/local/snapweb/.changes
       #  chmod 750 /usr/local/snapweb/.changes
      #fi
       #nombre del fichero será la ruta absoluta, sustituyendo la / por :::
       #filesan=$(echo $1/$2|sed 's/\//:_:/g')
      #if [ -e /usr/local/snapweb/.changes/$filesan ];then
        #rm -fr /usr/local/snapweb/.changes/$filesan 
      #fi
      #mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
        rm -fr $1/$2 2>/dev/null #Redirecciono error por problemas con pureftpd
        echo "Se ha eliminado un fichero que había sido creado tras eliminar fichero">>/usr/local/snapweb/msg.log
     fi 
    fi

elif [ "$3" = "IN_MOVED_FROM" ]; then #Fichero borrado o movido
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
    if [ "$lock_on" = "0" ];then
      #Elimino de la monitorización --> Pendiente
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      rm -fr $base/$subdir/$2
      echo "Se ha borrado el fichero: $1/$2">>/usr/local/snapweb/msg.log
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #echo "Recibido: $1 - $2 - $3 - $4">>/usr/local/snapweb/msg.log
      #echo "Filas1: $filas1 y Filas2: $filas2">>/usr/local/snapweb/msg.log
      #Añado a la base los subdirectorios existentes
      if [ ! -e $1/$2 ]; then 
      echo "Ruta final:$base/$subdir/$2">>/usr/local/snapweb/msg.log
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        echo "Se ha intentado borrar el fichero: $1/$2, aunque se ha restaurado correctamente!">>/usr/local/snapweb/msg.log
       else
        echo "Se ha borrado el directorio: $1/$2 y no ha podido ser restaurado ya que no hay copia en backup">>/usr/local/snapweb/msg.log
      fi
    fi
    fi
elif [ "$3" = "IN_DELETE" ]; then #Carpeta borrada
   if [ "$lock_on" = "0" ];then
      #Elimino de la monitorización --> Pendiente
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      #service incron restart
      #Actualizo snap_back
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      subdir=$(echo $1|cut -d/ -f$filas1- )
      rm -fr $base/$subdir/$2
      #echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$1/\$2 \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
      echo "Se ha eliminado el directorio: $1/$2">>/usr/local/snapweb/msg.log
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #echo "Recibido: $1 - $2 - $3 - $4">>/usr/local/snapweb/msg.log
      if [ ! -e $1/$2 ]; then 
      base=$(base_snap $1)
      row_count $base
      filas1=$(echo $[$? + 1])
      #echo "Filas1: $filas1 y Filas2: $filas2">>/usr/local/snapweb/msg.log
      #Añado a la base los subdirectorios existentes
      subdir=$(echo $1|cut -d/ -f$filas1- )
      echo "Ruta final:$base/$subdir/$2">>/usr/local/snapweb/msg.log
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        echo "Se ha intentado eliminar el directorio: $1/$2, aunque se ha restaurado correctamente!">>/usr/local/snapweb/msg.log
      else
         rm -fr $1/$2
        echo "Se ha eliminado el directorio: $1/$2 y no ha podido ser restaurado ya que no hay copia en backup">>/usr/local/snapweb/msg.log
      fi
    fi 
  fi
fi
exit

#Falta eliminar de la monitorización los directorios borrados.
#Hay que reflejar en /snap_back los cambios que están permitidos!!
