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
mail_destino="wllop@esat.es"
fatal(){ echo ; echo "Error: $@" >&2;${E:+exit $E};}

check(){
if [ "$#" -lt 1]; then
  E= fatal "Error de parámetros."
fi

if ! [ -f $1 ]; then
  E=2 fatal "$1 debe ser un fichero"
fi

! [ -f /etc/firmasAV.txt ] && touch /etc/firmasAV.txt && chmod 644 /etc/firmasAV.txt

total=0
i=0
for cad in $(cat /etc/firmasAV.txt)
do
  nombre=$(echo $cad|cut -d: -f1)
  valor=$(echo $cad|cut -d: -f2)
  multi=$(grep "$nombre" $1 |wc -l)
  [ "$multi" -gt 0 ] && total=$[$total + ($valor * $multi) ]&&str="$str - $nombre"
done
echo "$total $str"
}
row_count(){ #Para poder ir eliminado "directorios" hasta encontrar la base
  IFS_OLD=$IFS
  IFS=$/
  i=$(echo $1|wc -w)
  IFS=$IFS_OLD
  return $i
}

base_snap(){ #Saber el directorio base_snap que está en snap_back
  temp=$(echo $1|tr -d /)
  if [ "$1" = "/" ];then
    echo ""
  elif [ -d /usr/local/snapweb/snap_back/$temp ];then
    echo "/usr/local/snapweb/snap_back/$temp"
  else
  row_count $1
  filas=$?
  base_snap $(echo $1|cut -d/ -f1-$filas )
  fi
}
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
orig=$1
base=$(base_snap $1) #/usr/local/snapweb/snap_back/rutadeldirectoriobase
len=$(cat $base/.ruta)
subdir=$(echo ${orig:$len})
lock_on=$(grep -i "lock_on" /etc/snapweb.conf|cut -d= -f2)
if [ "$3" = "IN_CREATE,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
    case "$lock_on" in  #Tipo bloqueo
      0) #Monitorizar
        buscar_excluidos $1
        cp -pfr $1/$2 $base/$subdir/
        echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
        ;;
      1) #Bloqueado
        if [  -e  $base/$subdir/$2 ] ; then 
          #Es una restauraciÃ³n!!
          cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
          service incron restart #Reiniciar servicio para actualizar inodos
        else
          #Crear una carpeta .changes con lo q haya cambiado.
          if [ ! -e /usr/local/snapweb/.changes ];then
             mkdir -p /usr/local/snapweb/.changes
            chmod 750 /usr/local/snapweb/.changes
          fi
          #nombre del fichero serÃ¡ la ruta absoluta, sustituyendo la / por :::
          filesan=$(echo $1/$2|sed 's/\//:_:/g')
          if [ -e /usr/local/snapweb/.changes/$filesan ];then
            rm -fr /usr/local/snapweb/.changes/$filesan 
          fi
          buscar_excluidos $1
          mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
        fi
        ;;
    esac    
elif [ "$3" = "IN_DELETE,IN_ISDIR" ]; then #Carpeta borrada
   if [ "$lock_on" = "0" ];then
      rm -fr $base/$subdir/$2
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #Añado a la base los subdirectorios existentes
      while [ ! -e $1/$2 ];
      do   
       #Añado a la base los subdirectorios existentes 
       if [ -e $base/$subdir/$2 ] && [ ! -e $1/$2 ];then
        #if [ ! -e $1 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        service incron restart
        sleep 6
        fi
      done
  fi
elif [ "$3" = "IN_MOVED_TO,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
     buscar_excluidos $1
     if [ "$lock_on" = "0" ];then
      cp -fpr $1/$2 $base/$subdir/
      echo "$1/$2 IN_MOVED_TO,IN_MOVED_FROM,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>/etc/incron.d/$(echo $1/$2|tr -d /)
    else
      rm -fr $1/$2 2>>/usr/local/snapweb/msg.log
    fi

elif [ "$3" = "IN_MOVED_FROM,IN_ISDIR" ]; then #Carpeta borrada
    if [ "$lock_on" = "0" ];then
      rm -fr $base/$subdir/$2 2>/dev/null
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      if [ ! -e $1/$2 ]; then 
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        service incron restart
      fi
    fi
  fi
elif [ "$3" = "IN_CREATE" ]; then #Nuevo fichero
    #Activo el registro de la carpeta!
    case "$lock_on" in
      0)total=($(check $1/$2))
        echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 0 ]; then #Controlar
          echo "Se ha creado un nuevo fichero con código sospecho:${total[*]}"|mail -s "SNAPWEB: Código sospechoso " $mail_destino
        fi
        cp -fpr $1/$2 $base/$subdir/
        ;;
      1) #Mirar si lo que se quiere crear es una restauración en modo lock_on
      if [  -e  $base/$subdir/$2 ] ; then 
       #Es una restauración!!
       cp -fpr  $base/$subdir/$2 $1
       exit
	    else
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
      ;; #Fin lock=1
    esac
elif [ "$3" = "IN_MOVED_TO" ]; then #Nueva fichero eliminado!
    #Activo el registro de la carpeta!
    case "$lock_on" in
      0)total=($(check $1/$2))
        echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 0 ]; then #Controlar
          echo "Se ha creado un nuevo fichero con código sospecho:${total[*]}"|mail -s "SNAPWEB: Código sospechoso " $mail_destino
        fi
        cp -fpr $1/$2 $base/$subdir
        ;;    
    1)
      #Mirar si lo que se quiere crear es una restauración en modo lock_on
        if [ ! -e $base/$subdir/$2 ];then
         rm -fr $1/$2 2>/dev/null #Redirecciono error por problemas con pureftpd
        fi
        ;;
    esac
elif [ "$3" = "IN_CLOSE_WRITE" ]; then # fichero CAMBIADO!
    #Activo el registro de la carpeta!
     case "$lock_on" in
     0)total=($(check $1/$2))
        echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 0 ]; then #Controlar
          echo "Se ha añadido al fichero $1/$2 información con código sospecho:${total[*]}"|mail -s "SNAPWEB: Código sospechoso " $mail_destino
        fi 
        cp -fpr $1/$2 $base/$subdir/
        ;;
    1)
      #Mirar si HAY cambios 
      if  ! diff  $base/$subdir/$2 $1/$2 ;then 
       #Es una restauración!!
        cp -rfp $base/$subdir/$2 $1/ 2>>/usr/local/snapweb/msg.log
        exit
      fi 
      ;;
    esac

elif [ "$3" = "IN_MOVED_FROM" ]; then #Fichero borrado o movido
    if [ "$lock_on" = "0" ];then
      #Elimino de la monitorización --> Pendiente
      rm -fr $base/$subdir/$2
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #Añado a la base los subdirectorios existentes
      if [ ! -e $1/$2 ]; then 
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
    fi
    fi
  fi
elif [ "$3" = "IN_DELETE" ]; then #Fichero borrado
   if [ "$lock_on" = "0" ];then
      rm -fr $base/$subdir/$2
    else
      #Recupero el directorio del repositorio que tengo en snap_back!!
      if [ ! -e $1/$2 ]; then 
      #Añado a la base los subdirectorios existentes
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
      else
         rm -fr $1/$2
      fi
    fi 
  fi
fi
exit