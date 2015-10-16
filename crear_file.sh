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
#!/bin/bash
nombre="borrar"
echo "Dame el primer numero"
read inicio
echo "Dame el 2º numero"
read final
if [ $inicio -ge $final ]; then
   echo "El 1er numero mayor que el 2º!, nos vamos fuera"
   exit 1
fi
for i in $(seq $inicio $final); 
do 
   fichero=""
   fichero=$nombre$i
   touch $fichero
done 