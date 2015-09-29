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
IFS_OLD=$IFS
IFS='$\n'
base=$(base_snap $1)
rutaabs=$(cat "$base/.rutaabs"|tr -s /)
len=$(echo ${#rutaabs})
param=$(echo $1/|tr -s /)
subdir=$(echo ${param:$len})
grep -iw "$subdir" /etc/snapweb/exclude_dir &>/dev/null && exit

#for var in $(grep -i "exclude_dir" /etc/snapweb/snapweb.conf|cut -d= -f2)
#do
#  echo "var:$var"
#  echo "Rutaabs:$rutaabs$var"
#  if [ "$rutaabs$var" = "$1" ];then
#      echo "Sale">>/usr/local/snapweb/msg2.log
#      exit
#  elif [ "$rutaabs$var/" = "$1" ];then
#      echo "Sale">>/usr/local/snapweb/msg2.log
#      exit 
#  fi
#done 
IFS=$IFS_OLD
}
buscar_excluidos $1
echo "Esto no debe salir!!"
