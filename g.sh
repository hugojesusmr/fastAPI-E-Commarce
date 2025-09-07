#!/bin/bash

# --- Configuración (¡Ajusta estas variables según tus necesidades!) ---

# Detalles del servidor SFTP
SFTP_USER="your_sftp_username"       # <--- CAMBIA ESTO
SFTP_HOST="your_sftp_host"           # <--- CAMBIA ESTO (ej., sftp.example.com o IP)
SFTP_PORT="22"                       # Puerto SFTP, usualmente 22
SFTP_REMOTE_PATH="/path/to/sftp/zips/" # <--- CAMBIA ESTO (ej., /remote/data/uploads/)

# Detalles del contenedor MySQL
MYSQL_CONTAINER_NAME="my_mysql_container" # <--- CAMBIA ESTO (Nombre de tu contenedor Docker/Podman MySQL)
MYSQL_ROOT_USER="root"                   # <--- USUARIO ROOT DE MYSQL (o uno con permisos de CREATE DATABASE/TABLE)
MYSQL_ROOT_PASSWORD="your_mysql_root_password" # <--- CONTRASEÑA DEL USUARIO ROOT DE MYSQL

# Usuario MySQL para LOAD DATA INFILE (debe tener privilegios INSERT y FILE)
# Puede ser el mismo que MYSQL_ROOT_USER si lo deseas, pero se recomienda un usuario con menos privilegios.
MYSQL_USER="your_mysql_user"             # <--- CAMBIA ESTO (Usuario MySQL para inserciones)
MYSQL_PASSWORD="your_mysql_password"     # <--- CAMBIA ESTO (Contraseña del usuario MySQL para inserciones)

# Base de datos y tabla donde se insertarán los datos
DB_NAME="your_database_name"             # <--- CAMBIA ESTO (Nombre de la DB a crear/usar)
TABLE_NAME="your_table_name"            # <--- CAMBIA ESTO (Nombre de la tabla a crear/usar)

# Delimitador de columnas en tus archivos CSV
CSV_DELIMITER=","

# Tipo de dato por defecto para las columnas de la tabla (VARCHAR(255) es un buen comodín)
DEFAULT_COLUMN_TYPE="VARCHAR(255)"

# Ruta dentro del contenedor MySQL donde los archivos CSV serán copiados temporalmente
# Esta ruta debe ser accesible por el servidor MySQL (ej. /var/lib/mysql-files/)
MYSQL_CONTAINER_DATA_PATH="/var/lib/mysql-files/"

# Directorios locales
LOCAL_DOWNLOAD_PATH="/tmp/sftp_downloads_$$/" # Directorio temporal para ZIPs descargados
TEMP_UNZIP_DIR="/tmp/unzip_temp_$$/"        # Directorio temporal para descompresión de ZIPs
# --- NUEVA VARIABLE: Carpeta para ZIPs procesados ---
PROCESSED_ZIPS_ARCHIVE_PATH="/path/to/local/processed_zips/" # <--- CAMBIA ESTO: Ruta donde se archivarán los ZIPs procesados

# Archivo de registro para guardar los nombres de los ZIPs ya procesados
PROCESSED_LOG_FILE="processed_zips.log"

# Archivo de registro para toda la salida del script
SCRIPT_LOG_FILE="script_sftp_mysql.log"

# --- Variables de estado internas del script ---
TABLE_CREATED=false # Bandera para saber si la tabla ya fue creada en esta ejecución

# --- Importar funciones auxiliares ---
# Asegúrate de que este archivo esté en el mismo directorio o proporciona la ruta completa.
# Si el archivo de funciones está en un subdirectorio, por ejemplo 'lib/', usa 'source "./lib/sftp_mysql_functions.sh"'
source "./sftp_mysql_functions.sh" || { echo "Error: No se pudo cargar el archivo de funciones 'sftp_mysql_functions.sh'. Saliendo."; exit 1; }

# Registrar la función de limpieza para que se ejecute al salir (incluso si hay errores)
trap cleanup EXIT

# --- Ejecución principal del script ---

# Iniciar un nuevo archivo de log o añadir a uno existente
# Se usa ">" para sobrescribir el log cada vez que se ejecuta el script.
# Si prefieres añadir al log existente, cambia ">" por ">>".
> "$SCRIPT_LOG_FILE"

log_message "--- Iniciando proceso de SFTP ZIP a MySQL Directo ---"
log_message "Buscando ZIPs en SFTP: $SFTP_USER@$SFTP_HOST:$SFTP_REMOTE_PATH"
log_message "Insertando datos en MySQL: $DB_NAME.$TABLE_NAME en contenedor '$MYSQL_CONTAINER_NAME'"
log_message "Archivo de registro de procesados: '$PROCESSED_LOG_FILE'"
log_message "Salida del script registrada en: '$SCRIPT_LOG_FILE'"
log_message "------------------------------------------------------------------"

# 1. Crear directorios temporales locales y de archivo
mkdir -p "$LOCAL_DOWNLOAD_PATH" || { log_message "Error: No se pudo crear el directorio local de descarga '$LOCAL_DOWNLOAD_PATH'. Saliendo."; exit 1; }
mkdir -p "$TEMP_UNZIP_DIR" || { log_message "Error: No se pudo crear el directorio temporal de descompresión '$TEMP_UNZIP_DIR'. Saliendo."; exit 1; }
# --- NUEVA LÍNEA: Crear el directorio de archivo ---
mkdir -p "$PROCESSED_ZIPS_ARCHIVE_PATH" || { log_message "Error: No se pudo crear el directorio de archivo '$PROCESSED_ZIPS_ARCHIVE_PATH'. Saliendo."; exit 1; }

# 2. Asegurarse de que el archivo de registro de procesados exista
touch "$PROCESSED_LOG_FILE" || { log_message "Error: No se pudo crear/acceder al archivo de registro '$PROCESSED_LOG_FILE'. Saliendo."; exit 1; }

# 3. Descargar todos los archivos .zip desde SFTP
log_message "Descargando archivos ZIP desde SFTP..."
sftp -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<EOF >> "$SCRIPT_LOG_FILE" 2>&1
  cd "$SFTP_REMOTE_PATH"
  get *.zip "$LOCAL_DOWNLOAD_PATH"
  # Opcional: Descomenta la línea de abajo para eliminar los ZIPs del SFTP después de una descarga exitosa
  # rm *.zip
  bye
EOF

if [ $? -ne 0 ]; then
    log_message "ERROR: Falló la descarga de archivos ZIP desde SFTP. Por favor, verifica credenciales, host, ruta y puerto SFTP."
    exit 1
fi
log_message "Archivos ZIP descargados a: $LOCAL_DOWNLOAD_PATH"
log_message "------------------------------------------------------------------"

# --- Configuración inicial de MySQL (se ejecuta una vez al inicio del script) ---
log_message "Realizando configuración inicial de permisos de usuario MySQL y verificando secure_file_priv..."

# Verificar y otorgar privilegio FILE y acceso remoto al MYSQL_USER
# Esto es crucial para LOAD DATA INFILE y evitar "Access denied" por host
GRANT_SQL="GRANT FILE ON *.* TO '$MYSQL_USER'@'%';"
execute_mysql_root_command "$GRANT_SQL"
if [ $? -eq 0 ]; then
    log_message "  Privilegio FILE otorgado a '$MYSQL_USER'@'%'."
else
    log_message "  ADVERTENCIA: No se pudo otorgar el privilegio FILE a '$MYSQL_USER'@'%'. Si el usuario ya existe con privilegios FILE o el error es por host, esto es normal. Si no, podría ser un problema de permisos de ROOT_USER."
    # Intentar asegurar que el usuario exista con acceso '%' si no se pudo otorgar FILE
    execute_mysql_root_command "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';"
    execute_mysql_root_command "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$MYSQL_USER'@'%';" # Otorgar permisos sobre la DB objetivo
    execute_mysql_root_command "FLUSH PRIVILEGES;"
fi

# Verificar el valor de secure_file_priv
SECURE_FILE_PRIV_CMD="SHOW VARIABLES LIKE 'secure_file_priv';"
SECURE_FILE_PRIV_VALUE=$(execute_mysql_root_command "$SECURE_FILE_PRIV_CMD" | grep -oP "secure_file_priv\s+\K.*")
log_message "  Valor de 'secure_file_priv' en MySQL: '$SECURE_FILE_PRIV_VALUE'"
if [[ "$SECURE_FILE_PRIV_VALUE" == "NULL" ]]; then
    log_message "  ADVERTENCIA: 'secure_file_priv' es NULL. Esto significa que LOAD DATA INFILE NO funcionará."
    log_message "  Considera modificar tu configuración de MySQL (my.cnf) para establecerlo a un directorio como '/var/lib/mysql-files/'."
elif [[ -n "$SECURE_FILE_PRIV_VALUE" && "$MYSQL_CONTAINER_DATA_PATH" != *"$SECURE_FILE_PRIV_VALUE"* ]]; then
    log_message "  ADVERTENCIA: 'MYSQL_CONTAINER_DATA_PATH' ('$MYSQL_CONTAINER_DATA_PATH') no está dentro del directorio permitido por 'secure_file_priv' ('$SECURE_FILE_PRIV_VALUE'). Esto podría causar fallos en LOAD DATA INFILE."
fi

log_message "Configuración inicial de MySQL completada."
log_message "------------------------------------------------------------------"


# 8. Iterar sobre cada archivo ZIP descargado, extraer CSV e insertar en MySQL
find "$LOCAL_DOWNLOAD_PATH" -maxdepth 1 -name "*.zip" -print0 | while IFS= read -r -d $'\0' zip_file; do
    zip_filename=$(basename "$zip_file") # Obtener solo el nombre del archivo ZIP
    
    log_message "Procesando ZIP: $zip_filename"

    # 8.1. Validar si el archivo ZIP ya fue procesado
    if grep -qF "$zip_filename" "$PROCESSED_LOG_FILE"; then
        log_message "  -> '$zip_filename' YA FUE PROCESADO anteriormente. Saltando."
        continue # Ir al siguiente ZIP en el bucle
    fi

    # Extraer el nombre base del archivo ZIP (sin extensión) para el directorio temporal
    zip_basename_no_ext=$(basename "$zip_file" .zip)
    current_unzip_path="${TEMP_UNZIP_DIR}${zip_basename_no_ext}/"
    mkdir -p "$current_unzip_path" || { log_message "Error: No se pudo crear el subdirectorio temporal '$current_unzip_path'. Saltando este ZIP."; continue; }
    
    # 8.2. Detectar el nombre del CSV dentro del ZIP
    internal_csv_name=$(unzip -Z1 "$zip_file" | grep -i "\.csv$" | head -n 1)

    if [ -z "$internal_csv_name" ]; then
        log_message "  ADVERTENCIA: No se encontró ningún archivo .csv dentro de '$zip_file'. Saltando este ZIP."
        rm -rf "$current_unzip_path" # Limpiar el directorio temporal de este ZIP
        continue # Ir al siguiente ZIP
    fi
    
    log_message "  -> CSV interno detectado: '$internal_csv_name'"

    # 8.3. Descomprimir el archivo CSV detectado en su subdirectorio temporal local
    unzip -o "$zip_file" "$internal_csv_name" -d "$current_unzip_path" > /dev/null
    
    if [ $? -ne 0 ]; then
        log_message "  ERROR: Falló la descompresión de '$zip_file' para '$internal_csv_name'. Saltando este ZIP."
        rm -rf "$current_unzip_path"
        continue
    fi

    internal_csv_file_path="${current_unzip_path}${internal_csv_name}"
    
    if [ ! -f "$internal_csv_file_path" ]; then
        log_message "  ADVERTENCIA: El archivo CSV '$internal_csv_name' no se extrajo correctamente o no se encontró en '$zip_file' dentro del temporal. Saltando."
        rm -rf "$current_unzip_path"
        continue
    fi

    # --- 8.4. CREAR BASE DE DATOS Y TABLA (Solo una vez por ejecución del script) ---
    if [ "$TABLE_CREATED" = false ]; then
        log_message "Intentando crear/verificar la base de datos y tabla..."
        
        # Leer el encabezado del CSV para generar la sentencia CREATE TABLE
        CSV_HEADER=$(head -n 1 "$internal_csv_file_path")
        if [ -z "$CSV_HEADER" ]; then
            log_message "  ERROR: El primer archivo CSV '$internal_csv_file_path' está vacío o no tiene encabezado. No se puede crear la tabla. Saltando este ZIP."
            rm -rf "$current_unzip_path"
            continue
        fi
        log_message "  Encabezado del CSV para inferencia de tabla: '$CSV_HEADER'"

        # Generar la sentencia CREATE TABLE
        IFS="$CSV_DELIMITER" read -ra COLUMNS <<< "$CSV_HEADER"
        SQL_COLUMNS=""
        for col_name in "${COLUMNS[@]}"; do
            clean_col_name=$(echo "$col_name" | sed 's/[^a-zA-Z0-9_]//g' | tr '[:upper:]' '[:lower:]')
            if [ -z "$clean_col_name" ]; then
                log_message "  ADVERTENCIA: Se encontró un nombre de columna vacío después de limpiar. Saltando."
                continue
            fi
            if [ -n "$SQL_COLUMNS" ]; then
                SQL_COLUMNS+=","
            fi
            SQL_COLUMNS+="`$clean_col_name` $DEFAULT_COLUMN_TYPE"
        done

        if [ -z "$SQL_COLUMNS" ]; then
            log_message "  ERROR: No se pudieron extraer nombres de columna válidos del encabezado del CSV. No se puede crear la tabla. Saltando este ZIP."
            rm -rf "$current_unzip_path"
            continue
        fi

        # --- MODIFICACIÓN CLAVE: Añadir columna 'id' como PRIMARY KEY AUTO_INCREMENT ---
        CREATE_TABLE_SQL="CREATE TABLE IF NOT EXISTS \`$DB_NAME\`.\`$TABLE_NAME\` (
          \`id\` INT AUTO_INCREMENT PRIMARY KEY,
          $SQL_COLUMNS
        );"
        # -----------------------------------------------------------------------------

        # Crear la base de datos (si no existe)
        log_message "  Creando base de datos '$DB_NAME' (si no existe)..."
        execute_mysql_root_command "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
        if [ $? -ne 0 ]; then
            log_message "  ERROR: No se pudo crear la base de datos '$DB_NAME'. Verifique permisos de MYSQL_ROOT_USER. Saltando este ZIP."
            rm -rf "$current_unzip_path"
            continue
        fi
        log_message "  Base de datos '$DB_NAME' asegurada."

        # Crear la tabla en la base de datos
        log_message "  Creando tabla '$TABLE_NAME' en la base de datos '$DB_NAME' (si no existe)..."
        execute_mysql_root_db_command "$DB_NAME" "$CREATE_TABLE_SQL"
        if [ $? -ne 0 ]; then
            log_message "  ERROR: No se pudo crear la tabla '$TABLE_NAME' en la base de datos '$DB_NAME'. Verifique permisos de MYSQL_ROOT_USER o estructura de tabla. SQL: $CREATE_TABLE_SQL"
            rm -rf "$current_unzip_path"
            continue
        fi
        log_message "  Tabla '$TABLE_NAME' creada/verificada con éxito en '$DB_NAME'."
        TABLE_CREATED=true # Marcar que la tabla ya fue manejada para esta ejecución
    else
        log_message "  La base de datos y tabla ya fueron verificadas/creadas en esta ejecución."
    fi

    # 8.5. Copiar el CSV extraído al contenedor MySQL
    CONTAINER_CSV_FILENAME=$(basename "$internal_csv_file_path")
    CONTAINER_FULL_PATH="${MYSQL_CONTAINER_DATA_PATH}${CONTAINER_CSV_FILENAME}"

    log_message "  -> Copiando '$internal_csv_file_path' a '$MYSQL_CONTAINER_NAME:$CONTAINER_FULL_PATH'..."
    docker cp "$internal_csv_file_path" "$MYSQL_CONTAINER_NAME:$CONTAINER_FULL_PATH" >> "$SCRIPT_LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log_message "  ERROR: Falló la copia del archivo '$internal_csv_file_path' al contenedor MySQL. Saltando este ZIP."
        rm -rf "$current_unzip_path"
        continue
    fi
    log_message "  -> Archivo copiado al contenedor."

    # 8.6. Asegurar permisos de lectura para el archivo copiado dentro del contenedor
    log_message "  -> Asegurando permisos de lectura para el archivo en el contenedor..."
    docker exec "$MYSQL_CONTAINER_NAME" chmod 644 "$CONTAINER_FULL_PATH" >> "$SCRIPT_LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log_message "  ADVERTENCIA: No se pudieron establecer los permisos de lectura para '$CONTAINER_FULL_PATH' en el contenedor. Esto podría causar un fallo en LOAD DATA INFILE."
    fi

    # 8.7. Insertar datos en MySQL usando LOAD DATA INFILE (usando MYSQL_USER y MYSQL_PWD)
    log_message "  -> Insertando datos de '$CONTAINER_FULL_PATH' en '$DB_NAME.$TABLE_NAME' usando LOAD DATA INFILE..."
    # --- Modificado para usar IGNORE, lo cual funciona bien con PRIMARY KEY/UNIQUE KEY ---
    LOAD_SQL="LOAD DATA INFILE '$CONTAINER_FULL_PATH' IGNORE INTO TABLE \`$DB_NAME\`.\`$TABLE_NAME\` FIELDS TERMINATED BY '$CSV_DELIMITER' ENCLOSED BY '\"' LINES TERMINATED BY '\n' IGNORE 1 LINES;"
    
    execute_mysql_user_command "$LOAD_SQL"
    if [ $? -ne 0 ]; then
        log_message "  ERROR: Falló la inserción de datos para '$zip_filename' en MySQL. Revisa el formato del CSV, la estructura de la tabla, y los permisos/host de MYSQL_USER (privilegio FILE)."
        # Intentar eliminar el archivo del contenedor incluso si la inserción falló
        docker exec "$MYSQL_CONTAINER_NAME" rm "$CONTAINER_FULL_PATH" >> "$SCRIPT_LOG_FILE" 2>&1
        rm -rf "$current_unzip_path"
        continue
    fi
    log_message "  -> Datos de '$zip_filename' insertados con éxito."

    # 8.8. Eliminar el archivo CSV del contenedor MySQL después de la inserción exitosa
    log_message "  -> Eliminando archivo temporal del contenedor: '$CONTAINER_FULL_PATH'"
    docker exec "$MYSQL_CONTAINER_NAME" rm "$CONTAINER_FULL_PATH" >> "$SCRIPT_LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log_message "  ADVERTENCIA: No se pudo eliminar el archivo '$CONTAINER_FULL_PATH' del contenedor MySQL."
    fi

    # 8.9. Registrar el archivo ZIP como procesado (¡solo si todo fue exitoso hasta aquí!)
    echo "$zip_filename" >> "$PROCESSED_LOG_FILE"
    log_message "  -> '$zip_filename' REGISTRADO como procesado."
    
    # --- NUEVA LÓGICA: Mover el archivo ZIP procesado a la carpeta de archivo ---
    log_message "  -> Moviendo '$zip_filename' a la carpeta de archivo: '$PROCESSED_ZIPS_ARCHIVE_PATH'"
    mv "$zip_file" "$PROCESSED_ZIPS_ARCHIVE_PATH" >> "$SCRIPT_LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log_message "  ADVERTENCIA: No se pudo mover el archivo ZIP '$zip_filename' a la carpeta de archivo '$PROCESSED_ZIPS_ARCHIVE_PATH'. El archivo podría permanecer en el directorio de descarga."
    fi
    # -------------------------------------------------------------------------
    
    # Eliminar el subdirectorio temporal local de este ZIP
    rm -rf "$current_unzip_path"
done

log_message "------------------------------------------------------------------"
log_message "Proceso completado."
log_message "Todos los archivos procesados han sido insertados en MySQL y movidos a la carpeta de archivo."
log_message "Revisa '$SCRIPT_LOG_FILE' para detalles y posibles advertencias."
log_message "--- Script finalizado ---"