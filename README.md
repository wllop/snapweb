# SNAPWEB
# Snapweb Project: Congela tu web!!
SnapWeb permite la monitorización de directorios impidiendo, en su caso, cambios en el mismo. Además, dispone de distintos tipos de bloqueos, permitiendo incluso, el análisis en tiempo real de malware.
Actualmente la versión de testing sólo dispone de 2 tipos modos: Bloqueado y No Bloqueado.

USO:

snapweb.sh [-d] /ruta/a/monitorizar

OPCIONES:
-d --> Deja de monitorizar la ruta pasada como parámetro. NO elimina la ruta pasada como parámetro, pero sí la copia de respaldo utilizada por snapweb ubicada en /usr/local/snapweb/snap_back

CONFIGURACIÓN:
Fichero /etc/snapweb.conf

lock_on= 0 (Bloqueo desactivado)    |   1 (Bloqueo activado)
	
	lock_on = 0 --> SnapWeb permite y monitoriza cambios en el directorio pasado como parámetro.

	lock_on = 1 --> SnapWeb impedirá cambios en el directorio pasado como parámetro. Dicho bloqueo afectará también a los distintos archivos y subdirectorios que contenga. Con este modo garantizamos la integridad de los ficheros de nuestro site.



exclude_dir=/ruta/dir1;/ruta/dir2 [opcional]

	Indicaremos el directorio/s que queremos excluir de la monitorización. Esta opción es especialmente interesante para permitir que, con el modo bloqueado activo, se puedan realizar ciertos cambios en algunas carpetas (caché, códigos captcha, etc.). Debe indicar su direccionamiento absoluto.

Próximas mejoras:
	* Modo automático: Analiza en tiempo real cualquier cambio, categoriza dichos cambios y decide qué hacer.
 
	* Modo semiautomático:
 
	* Configuración del modo por site: Ahora los modos de bloqueo pueden indicarse por site, en vez de un único tipo de bloqueo para todos los sites albergados.
	* Administración y monitorización de snapweb vía App.


Cualquier comentario, error o mejora enviadlo a wllop@esat.es. 
Muchas gracias!!
@wllop