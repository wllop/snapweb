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
#
fatal(){ echo ; echo "Error: $@" >&2;${E:+exit $E};}

check(){
if [ "$#" -lt 1 ]; then
  E= fatal "Error de parámetros."
fi

if ! [ -f $1 ]; then
  E=2 fatal "$1 debe ser un fichero"
fi

! [ -f /etc/snapweb/firmasAV.txt ] && touch /etc/snapweb/firmasAV.txt && chmod 644 /etc/snapweb/firmasAV.txt

total=0
i=0
for cad in $(cat /etc/snapweb/firmasAV.txt)
do
  nombre=$(echo $cad|cut -d: -f1)
  valor=$(echo $cad|cut -d: -f2)
  multi=$(echo -e $(cat $1)|grep -i "$nombre" |wc -l)
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
base=$(base_snap $1)
rutaabs=$(cat "$base/.rutaabs"|tr -s /)
len=$(echo ${#rutaabs})
param=$(echo $1/|tr -s /)
subdir=$(echo ${param:$len})
[ "$subdir" != "" ] && grep -m1 -iw "$subdir" /etc/snapweb/exclude_dir &>/dev/null && exit
}
#echo $1 $2 $3 >>/usr/local/snapweb/debug_w
orig=$1
base=$(base_snap $1) #/usr/local/snapweb/snap_back/rutadeldirectoriobase
len=$(cat $base/.ruta)
subdir=$(echo ${orig:$len})
rutaabs=$(cat "$base/.rutaabs"|tr -s /)
rutasnap=$(find $rutaabs/* -name snapweb -type d)
if [ -f $rutasnap/sitelock.conf ];then
  lock_on=$(cat $rutasnap/sitelock.conf )
else
lock_on=$(grep  -m1 -i "lock_on" /etc/snapweb/snapweb.conf|cut -d= -f2)
fi
if [ "$2" = "IN_IGNORED" ]; then #Puede pasar cuando se ha eliminado un fichero o directorio d forma "incontrolada"
  case "$lock_on" in   #Aquí $2 es el propio evento 
    0,2) #Monitorizar
     [ ! -e $1 ] && rm -fr $base/$subdir 2>/dev/null
     ;;
  esac
elif [ "$3" = "IN_CREATE,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
    case "$lock_on" in  #Tipo bloqueo
      0) #Monitorizar
           cp -pfr $1/$2 $base/$subdir/
           incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
            #Cuando pones un directorio en /incron.d automáticamente se monitoriza, no hay qu reiniciar!
           echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
           #line=$(grep -m1 -n "$1/$2" $incronpath|cut -d: -f1)  #Tiene q ser linea + d para usarlo en el sed d abajo.
           #while [ "$line" = "" ]; do
           # if mkdir /var/lock/snaplockci; then
          #      line="exit"
          #      rmdir /var/lock/snaplockci
          #  fi
          #  done      
  ;;
      1) #Bloqueado
         if [  -e  $base/$subdir/$2 ] ; then 
          #Es una restauración!!
          cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
          incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
            #Cuando pones un directorio en /incron.d automáticamente se monitoriza, no hay qu reiniciar!
          echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
         else
          buscar_excluidos $1/$2/
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
          mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
        fi
        #if [ $(pidof -x jack.sh| wc -w) -gt 2 ]; then 
        # exit
        #fi
        #service incron restart
        ;;
        2) #Automático
         cp -pfr $1/$2 $base/$subdir/
           incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
           echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
        #cp -pfr $1/$2 $base/$subdir/
        #incronpath="/etc/incron.d/$(echo $rutaabs|tr -d /)"
        #[ grep -m1 -n "$1/$2" $incronpath ] || echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">>$incronpath
        #if [ $(pidof -x jack.sh| wc -w) -gt 2 ]; then 
        # exit
        #fi
        #service incron restart
        ;;
    esac    
elif [ "$3" = "IN_DELETE,IN_ISDIR" ]; then #Carpeta borrada
  case "$lock_on" in  #Tipo bloqueo
    0) rm -fr $base/$subdir/$2
      #Elimino de incron!!
      #Busco si está en /etc/incron.d/raiz  $rutaabs!! /var/www...
      incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
      rm -fr $incronpath 2>/dev/null
      #line=$(grep -m1 -n "$1/$2" $incronpath|cut -d: -f1)  #Tiene q ser linea + d para usarlo en el sed d abajo.
      #while [ $line != "" ] ; do
      #if mkdir /var/lock/snaplock; then
      #    line+="d" &&  sed -i "$line" $incronpath 2>/dev/null
      #    line=""
      #    rm -fr /var/lock/snaplock
      #fi
      #done
      #rm -fr $incronpath 2>/dev/null
      #Eliminio linea
      #Ahora eliminio fichero del propio subdirectorio!!
      #incronsubpath="/etc/incron.d/$(echo $1/$2|tr -d /)"
      ;;
    1) #Recupero el directorio del repositorio que tengo en snap_back!!
      #Añado a la base los subdirectorios existentes
      #while [ ! -e $1/$2 ];
      #do   
      #Añado a la base los subdirectorios existentes 
      if [ -e $base/$subdir/$2 ];then
       #   #if [ ! -e $1 ];then
       cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
       incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
            #Cuando pones un directorio en /incron.d automáticamente se monitoriza, no hay qu reiniciar!
       echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
          
     #   service incron restart
     #   sleep 6
     #   fi
     # done
    #[ ! -e $1/$2 ] && cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log  &&service incron restart
    # diff $base/$subdir $1 >/dev/null 2>&1 && service incron restart || cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
      fi
      ;;
    2)
      rm -fr $base/$subdir/$2
      #Elimino de incron!!
      #Busco si está en /etc/incron.d/raiz  $rutaabs!! /var/www...
      incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
      rm -fr $incronpath 2>/dev/null
  ;;
  esac
elif [ "$3" = "IN_MOVED_TO,IN_ISDIR" ]; then #Nueva carpeta creada!
    #Activo el registro de la carpeta!
    case "$lock_on" in  #Tipo bloqueo
    0) cp -pfr $1/$2 $base/$subdir/
           incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
            #Cuando pones un directorio en /incron.d automáticamente se monitoriza, no hay qu reiniciar!
           echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
       ;;
    1) buscar_excluidos $1/$2/
      rm -fr $1/$2 2>>/usr/local/snapweb/msg.log
      ;;
    2) cp -pfr $1/$2 $base/$subdir/
           incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
            #Cuando pones un directorio en /incron.d automáticamente se monitoriza, no hay qu reiniciar!
           echo "$1/$2 IN_CREATE,IN_MOVED_TO,IN_MOVED_FROM,IN_DELETE,IN_CLOSE_WRITE /usr/local/snapweb/jack.sh \$@ \$# \$%">$incronpath
         
       ;;
    esac

elif [ "$3" = "IN_MOVED_FROM,IN_ISDIR" ]; then #Carpeta borrada
    case "$lock_on" in  #Tipo bloqueo
    0) rm -fr $base/$subdir/$2
      #Elimino de incron!!
      #Busco si está en /etc/incron.d/raiz  $rutaabs!! /var/www...
      incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
      rm -fr $incronpath 2>/dev/null
      ;;
    1) #Recupero el directorio del repositorio que tengo en snap_back!!
      buscar_excluidos $1/$2/
     if [ ! -e $1/$2 ]; then 
      if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
        if [ $(pidof -x jack.sh| wc -w) -gt 2 ]; then 
         exit
        fi
        if [ $(pidof -x jack.sh| wc -w) -gt 2 ]; then 
         exit
        fi
        service incron restart
      fi
     fi
     ;;
    2) rm -fr $base/$subdir/$2
      #Elimino de incron!!
      #Busco si está en /etc/incron.d/raiz  $rutaabs!! /var/www...
      incronpath="/etc/incron.d/$(echo $1$2|tr -d /)"
      rm -fr $incronpath 2>/dev/null
      ;;  
    esac
elif [ "$3" = "IN_CREATE" ]; then #Nuevo fichero
    #Activo el registro de la carpeta!
    case "$lock_on" in
      0)total=($(check $1/$2))
        #echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 10 ]; then #Controlar
        content=$(cat $1/$2)
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
          echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
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
       #nombre del fichero serÃ¡ la ruta absoluta, sustituyendo la / por :::
      buscar_excluidos $1/
      filesan=$(echo $1/$2|sed 's/\//:_:/g') #Para volver a obtener ruta absoluta sólo hace falta echo $filesan|sed 's/:_:/\//g|cut -d: -f2 ' 
      if [ -e /usr/local/snapweb/.changes/$filesan ];then
         rm -f /usr/local/snapweb/.changes/$filesan 
      fi
      mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
      mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
      total=($(check $1/$2))
       if [ ${total[0]} -gt 5 ]; then #Controlar
        content=$(cat $1/$2)
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
        echo "Estando bloqueado el site se ha  intentado crear el fichero $1/$2 con código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso. BLOQUEADO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
       else
        echo "Se ha creado el nuevo fichero $1/$2 cuando estaba habilitado el bloqueo del site."|mutt -s "SNAPWEB: Nuevo fichero bloqueado. " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 cuando estaba habilitado el bloqueo del site."|mail -s "SNAPWEB: Nuevo fichero bloqueado." $mail_destino 
       fi
      fi
      ;; #Fin lock=1
     2) if [  -e  $base/$subdir/$2 ] ; then 
       #Es una restauración!!
       cp -fpr  $base/$subdir/$2 $1
       exit
       else 
         total=($(check $1/$2)) #Automático!!
        #echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 5 ]; then #Controlar ##Si el valor es >5 se considera AMENAZA!! Por tanto a bloquear, aunque se almacena fichero en cuarentena.
         filesan=$(echo $1/$2|sed 's/\//:_:/g') #Cuarentena cambio / por :_: así tendré su posición absoluta cambiando :_: por / ;)
          if [ -e /usr/local/snapweb/.changes/$filesan ];then #Si existe versión anterior en cuarentena la elimino.
            rm -f /usr/local/snapweb/.changes/$filesan 
          fi
        content=$(cat $1/$2)
        mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log #Muevo a cuarentena
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
          echo "Se ha intentado crear el nuevo fichero $1/$2 con código sospecho:${total[*]}."|mutt -s "SNAPWEB: Fichero Bloqueado. AUTOMÁTICO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
        else
        cp -fpr $1/$2 $base/$subdir/  
        fi
      fi
        ;;
    esac
elif [ "$3" = "IN_MOVED_TO" ]; then #Nueva fichero nombre nuevo renombrado!       
    #Activo el registro de la carpeta!
    case "$lock_on" in
      0)total=($(check $1/$2))
        if [ ${total[0]} -gt 10 ]; then #Controlar
        content=$(cat $1/$2)
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
          echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
        fi
        cp -fpr $1/$2 $base/$subdir
        ;;    
    1)
      #Mirar si lo que se quiere crear es una restauraciÃ³n en modo lock_on
        buscar_excluidos $1/
        if [ ! -e $base/$subdir/$2 ];then
         rm -fr $1/$2 2>/dev/null #Redirecciono error por problemas con pureftpd
        else
          cp -fr $base/$subdir/$2 $1/$2
        fi
        ;;
    2) total=($(check $1/$2))
        if [ ${total[0]} -gt 5 ]; then #Controlar
        content=$(cat $1/$2)
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
        filesan=$(echo $1/$2|sed 's/\//:_:/g')
         if [ -e /usr/local/snapweb/.changes/$filesan ];then
             rm -f /usr/local/snapweb/.changes/$filesan 
          fi
        mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
         if [ ! -e $base/$subdir/$2 ];then
           echo "Se ha creado el nuevo fichero $1/$2 con código sospecho y ha sido puesto en cuarentena :${total[*]}."|mutt -s "SNAPWEB: Código sospechoso. AUTOMÁTICO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
         else ##Restauro 
           cp -f $base/$subdir/$2 $1/$2 2>/dev/null #Restauro por copia local!!
           echo "Se ha restaurado el fichero $1/$2 que tenía código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso restaurado. AUTOMÁTICO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
         fi 
        else
        cp -fpr $1/$2 $base/$subdir
        fi
        ;;   
    esac
elif [ "$3" = "IN_MODIFY" ]; then # fichero CAMBIADO!
    #Activo el registro de la carpeta!
     case "$lock_on" in
     0)total=($(check $1/$2))
        #echo ${total[0]} >>/usr/local/snapweb/msg.log
        if [ ${total[0]} -gt 10 ]; then #Controlar
        content=$(cat $1/$2)
        mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
          echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
        fi 
        cp -fpr $1/$2 $base/$subdir/
        ;;
    1)
      buscar_excluidos $1/
    #Mirar si HAY cambios 
      if  ! diff  $base/$subdir/$2 $1/$2 ;then 
       #Es una restauración!!
        cp -rfp $base/$subdir/$2 $1/ 2>>/usr/local/snapweb/msg.log
        exit
      fi 
      ;;
    2) total=($(check $1/$2))
        if [ ${total[0]} -gt 5 ]; then #Controlar
          content=$(cat $1/$2)
          filesan=$(echo $1/$2|sed 's/\//:_:/g')
            if [ -e /usr/local/snapweb/.changes/$filesan ];then
              rm -f /usr/local/snapweb/.changes/$filesan 
            fi
          mv $1/$2 /usr/local/snapweb/.changes/$filesan 2>>/usr/local/snapweb/msg.log
          mail_destino=$(grep -m1 "email=" /etc/snapweb/snapweb.conf|cut -d= -f2)
          if [ ! -e $base/$subdir/$2 ];then
              echo "Se ha modificado el fichero $1/$2 con código sospecho y ha sido puesto en cuarentena:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso. AUTOMÁTICO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
            else ##Restauro 
              cp -f $base/$subdir/$2 $1/$2 2>/dev/null #Restauro por copia local!!
              echo "Se ha restaurado el fichero $1/$2 que tenía código sospecho:${total[*]}."|mutt -s "SNAPWEB: Código sospechoso restaurado. AUTOMÁTICO " $mail_destino -a $1/$2 >/dev/null 2>&1 || echo "Se ha creado el nuevo fichero $1/$2 con código sospecho:${total[*]}. Contenido: $content"|mail -s "SNAPWEB: Código sospechoso." $mail_destino 
          fi 
        else
        cp -fpr $1/$2 $base/$subdir
        fi
        ;; 
    esac

elif [ "$3" = "IN_MOVED_FROM" ]; then #Fichero borrado o movido NOMBRE ANTIGUO!!
      case "$lock_on" in
      0) rm -fr $base/$subdir/$2
        ;;
      1)  buscar_excluidos $1/
      #Recupero el directorio del repositorio que tengo en snap_back!!
      #Añado a la base los subdirectorios existentes
        if [ ! -e $1/$2 ]; then 
         if [ -e $base/$subdir/$2 ];then
         cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
         fi
        fi
        ;;
      2) rm -fr $base/$subdir/$2
        ;;
      esac    
elif [ "$3" = "IN_DELETE" ]; then #Fichero borrado
   case "$lock_on" in
      0) rm -fr $base/$subdir/$2
        ;;
      1)  buscar_excluidos $1/
      #Recupero el directorio del repositorio que tengo en snap_back!!
      [ ! -e $1 ] && mkdir $1 && cp -frp $base/$subdir/*.* $1 
    if [ ! -e $1/$2 ]; then 
      #Añado a la base los subdirectorios existentes
        if [ -e $base/$subdir/$2 ];then
        cp -rfp $base/$subdir/$2 $1 2>>/usr/local/snapweb/msg.log
       
        fi
      fi 
      ;;
     2) rm -fr $base/$subdir/$2
      ;;
    esac   
fi
exit
