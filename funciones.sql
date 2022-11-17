
/*
-- --------------------------------------------------------------------------------------------
-- INSTRUCTIVO PARA CARGAR DATOS DE UN .CSV
-- --------------------------------------------------------------------------------------------
Para la importación de datos resulta necesario contar con acceso a PostgreSQL mediante algún servidor  (En nuestro caso utilizamos Pampero) y una terminal o consola para generar comandos de forma local

En primer lugar tenemos que crear una carpeta local llamada “BD1-Grupo2”
	$ mkdir ./BD1-Grupo2
	$ cd BD1-Grupo2

Una vez dentro, tenemos que descargar los archivos .csv y el archivo tables.sql provisto por los alumnos, el contenido debería resultar el siguiente

	$ ls
clientes_banco.csv  pagos_cuotas.csv  prestamos_banco.csv  tables.sql

Desde la terminal pasar los .csv y .sql pampero
        $ scp -r ./BD1-Grupo2 gfrancois@pampero.itba.edu.ar:./

Conectarse con Pampero
       $ ssh usuario@pampero.itba.edu.ar -L 8888:bd1.it.itba.edu.ar:5432

Revisar que estén los documentos que intentamos pasar
        $ cd BD1-Grupo2
        $ ls
clientes_banco.csv  pagos_cuotas.csv  prestamos_banco.csv tables.sql

Correr el archivo .sql para generar las tablas y generar el trigger
        $ psql -h bd1.it.itba.edu.ar -U usuario -f tables.sql PROOF

Conectarse con postgresql
        $ psql -h bd1.it.itba.edu.ar -U usuario PROOF

Copiar los datos de los .csv a las tablas previamente creadas
	\copy cliente_tp(Codigo,Dni,Telefono,Nombre,Direccion) FROM clientes_banco.csv csv delimiter ',' header;

	\copy prestamo_tp(Codigo,Fecha,cod_cliente,Importe) FROM prestamos_banco.csv csv delimiter ',' header;

	\copy cuota_tp(numero_couta,cod_prestamo,Importe,Fecha) FROM pagos_cuotas.csv csv delimiter ',' header;

para verificar que se cargaron los datos realizamos un comando sql como:
select *
from cliente_tp;
select *
from cuota_tp;
select *
from prestamo_tp;

salir de postgresql
	$ exit

salir de la carpeta
	$ cd ..

Mantenerse en pampero si se quiere acceder a tablas desde DataGrip
 */

-- --------------------------------------------------------------------------------------------
-- TABLA PARA Cliente_banco.csv
-- --------------------------------------------------------------------------------------------
CREATE TABLE cliente_tp
(
    dni       TEXT NOT NULL,
    nombre    TEXT,
    direccion TEXT,
    telefono  TEXT,
    codigo    INT check ( codigo > 0 ) PRIMARY KEY,
    UNIQUE (dni)
);


-- --------------------------------------------------------------------------------------------
-- TABLA PARA Prestamo_banco.csv
-- --------------------------------------------------------------------------------------------
CREATE TABLE prestamo_tp
(
    importe INT check ( importe > 0 ),
    codigo INT check ( codigo > 0 ) PRIMARY KEY ,
    fecha DATE,
    cod_cliente INT,
    FOREIGN KEY (cod_cliente) REFERENCES cliente_tp(codigo) ON DELETE CASCADE ON UPDATE CASCADE
);


-- --------------------------------------------------------------------------------------------
-- TABLA PARA pagos_cuota.csv
-- --------------------------------------------------------------------------------------------
CREATE TABLE cuota_tp
(
    numero_cuota INT check ( numero_cuota > 0 ),
    importe INT check ( importe > 0 ),
    fecha DATE,
    cod_prestamo INT,
    PRIMARY KEY (numero_cuota,cod_prestamo),
    FOREIGN KEY (cod_prestamo) REFERENCES prestamo_tp(codigo) ON DELETE CASCADE ON UPDATE CASCADE
);


-- --------------------------------------------------------------------------------------------
-- TABLA PARA manejo del Trigger
-- --------------------------------------------------------------------------------------------
CREATE TABLE backup_tp
(
    dni TEXT,
    nombre TEXT,
    telefono TEXT,
    cant_prestamos INT check ( cant_prestamos >= 0 ),
    monto_prestamos INT check ( monto_prestamos >= 0 ),
    monto_pago_cuotas INT check ( monto_pago_cuotas >= 0 ),
    ind_pagos_pendientes BOOLEAN,
    fecha TIMESTAMP,
    PRIMARY KEY (dni,fecha)
);


-- --------------------------------------------------------------------------------------------
-- monto_de_prestamo_pagado: Dado el codigo de un prestamo, obtiene el monto pagado hasta el momento de dicho prestamo
-- --------------------------------------------------------------------------------------------
-- Argumentos:
--  prestamo: codigo del prestamo
-- --------------------------------------------------------------------------------------------
-- Devuelve el monto pagado o 0 si aun no se pago alguna cuota
-- --------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monto_de_prestamo_pagado(prestamo prestamo_tp.codigo%type)
RETURNS cuota_tp.importe%type AS $$
DECLARE
    monto_pagado cuota_tp.importe%type;
BEGIN
    SELECT coalesce(sum(importe), 0) INTO monto_pagado
    FROM cuota_tp
    WHERE cod_prestamo = prestamo;
    RETURN monto_pagado;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------------------------------------------
-- cliente_borrado_trigger: Trigger que se ejecutara al intentar borrar un cliente
-- --------------------------------------------------------------------------------------------
-- Argumentos:
--
-- --------------------------------------------------------------------------------------------
-- Si el cliente a borrar existe, crea una tupla con la informacion correspondiente en la tabla backup_tp
-- Si el cliente a borrar no existe, lo ignora y sigue con la proxima tupla
-- --------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cliente_borrado_trigger()
RETURNS TRIGGER AS $$
DECLARE
    --  Creamos un cursor que itere por los prestamos pedidos por el cliente
    cPrestamo CURSOR FOR
        SELECT *
        FROM prestamo_tp
        WHERE cod_cliente = old.codigo;

    rPrestamo RECORD;

    cant_prestamos INT;
    monto_prestamos prestamo_tp.importe%type;
    monto_pagado cuota_tp.importe%type;
    pagos_pendientes BOOLEAN;

    monto_prestamo_pagado cuota_tp.importe%type;
    existe_cliente INT;
BEGIN
    cant_prestamos = 0;
    monto_prestamos = 0;
    monto_pagado = 0;
    pagos_pendientes = FALSE;

    -- Verificamos que existe el cliente que deseamos borrar
    SELECT count(*) INTO existe_cliente
    FROM cliente_tp
    WHERE codigo = old.codigo;

    -- Si no existe, se retorna (se ignora el trigger y se continua con el proximo)
    IF(existe_cliente = 0) THEN
        RETURN old;
    END IF;

    -- Si existe, entonces iteraremos por sus prestamos
    OPEN cPrestamo;

    LOOP
        FETCH cPrestamo INTO rPrestamo;
        EXIT WHEN NOT FOUND;

        -- Obtenemos el monto pagado hasta el momento del prestamo
        monto_prestamo_pagado = monto_de_prestamo_pagado(rPrestamo.codigo);
        -- Si al menos uno de los prestamos no se pago del todo, entonces el booleano se setara en true
        IF (monto_prestamo_pagado < rPrestamo.importe) THEN
            pagos_pendientes = TRUE;
        END IF;
        -- Actualizamos la cantidad de prestamos, el importe de los prestamos pedidos y el monto pagado entre todos ellos
        cant_prestamos = cant_prestamos + 1;
        monto_prestamos = monto_prestamos + rPrestamo.importe;
        monto_pagado = monto_pagado + monto_prestamo_pagado;
    END LOOP;

    -- Cerramos el cursor
    CLOSE cPrestamo;

    -- Insertamos la tupla del cliente en backup (consideramos el timestamp del momento de realizar el borrado)
    INSERT INTO backup_tp VALUES (old.dni, old.nombre, old.telefono, cant_prestamos, monto_prestamos, monto_pagado, pagos_pendientes, CURRENT_TIMESTAMP);

    -- Retornamos old para seguir con la proxima tupla (terminacion NORMAL)
    RETURN old;
END;
$$ LANGUAGE plpgsql;

-- El trigger se tiene que ejecutar sobre cada cliente a borrar (FOR EACH ROW)
-- Y se debe ejecutar antes del borrado, porque si se usa AFTER las tuplas de prestamo y cuota ya se habran borrado debido a la restriccion ON DELETE CASCADE
CREATE TRIGGER cliente_borrado
BEFORE DELETE ON cliente_tp
FOR EACH ROW
EXECUTE PROCEDURE cliente_borrado_trigger();
