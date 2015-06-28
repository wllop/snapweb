#/bin/bash
buscar_excluidos(){ #Comprueba si $1 está en la lista de directorios a excluir de la monitorización
IFS_OLD=$IFS
IFS=';'
for var in $(grep -i "exclude_dir" /etc/snapweb.conf|cut -d= -f2)
do
  if [ "$var" = "$1"];then
      exit
  fi
done 
IFS=$IFS_OLD
}
  buscar_excluidos $1
  echo "continuamos"
