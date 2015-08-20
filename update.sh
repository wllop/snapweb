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
fatal(){ echo ; echo "Error: $@" >&2;${E:+exit $E};}
installed(){ type -p "$1" 2>/dev/null >/dev/null;}
[ -d .git ] && git pull || E=1 fatal "Para poder lanzar la actualización de SnapWeb a través de update.sh, debe estar ubicado en el directorio del repositorio git." 
if ruta=$(type -p snapweb.sh); then 
  if ! diff -rq ./snapweb.sh $ruta >/dev/null 2>&1 ;then
   cp -f ./snapweb.sh $ruta
  fi
else
   echo "Snapweb no está incluido en la variable PATH."
   read -n 1 -p "¿Desea incluirlo en /usr/local/sbin (S/n)" res
   if [ "res" != "n" ]; then
    cp -f ./snapweb.sh /usr/local/sbin/snapweb.sh
   fi
fi
if ! diff -rq ./jack.sh /usr/local/snapweb/jack.sh >/dev/null 2>&1;then
   cp -f ./jack.sh /usr/local/snapweb/jack.sh
fi

if ! diff -rq ./firmasAV.txt /etc/firmasAV.txt >/dev/null 2>&1;then
   echo "Los ficheros de firmas del repositorio y el que tiene ubicado en /etc/ son distintos."
   read  -p "¿Desea que combine ambos archivos: (S/n)" res
   if [ "res" != "n" ]; then
    cat firmasAV.txt /etc/firmasAV.txt|sort|uniq>/etc/firmasAV.txt
   fi
fi
