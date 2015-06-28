#/bin/bash
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
      if buscar_excluidos $1; then
         echo "Directorio Excluido: $1"
         exit
      else
      	echo "No está en excluidos"
      fi  
