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
#  limitations under the License.
## Incluido en jack.sh para el análisis de malware!
#
#fatal(){ echo ; echo "Error: $@" >&2;${E:+exit $E};}
function check(){
if [ "$#" -lt 1]; then
	E=1 fatal "Error de parámetros."
fi

if ! [ -f $1 ]; then
	E=2 fatal "$1 debe ser un fichero"
fi

if ! [ -f /etc/firmasAV.txt ];then
    E=3 fatal "Debe existir el fichero de firmas /etc/firmasAV.txt"
fi
total=0
i=0
for cad in $(cat /etc/firmasAV.txt)
do
  nombre=$(echo $cad|cut -d: -f1)
  valor=$(echo $cad|cut -d: -f2)
  grep "$nombre" $1 >/dev/null 2>&1&&total=$[$total + $valor]
done
echo "$total"
}
