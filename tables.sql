-- Tablas

CREATE TABLE cliente_tp
(
    dni       TEXT,
    nombre    TEXT,
    direccion TEXT,
    telefono  TEXT,
    codigo    INT check ( codigo > 0 ) PRIMARY KEY,
    UNIQUE (dni)
);

CREATE TABLE prestamo_tp
(
    importe INT check ( importe > 0 ),
    codigo INT check ( codigo > 0 ) PRIMARY KEY ,
    fecha DATE,
    cod_cliente INT,
    FOREIGN KEY (cod_cliente) REFERENCES cliente_tp(codigo) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE cuota_tp
(
    numero_couta INT check ( numero_couta > 0 ),
    importe INT check ( importe > 0 ),
    fecha DATE,
    cod_prestamo INT,
    PRIMARY KEY (numero_couta,cod_prestamo),
    FOREIGN KEY (cod_prestamo) REFERENCES prestamo_tp(codigo) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE backup_tp
(
    dni TEXT,
    nombre TEXT,
    monto_prestamos INT check ( monto_prestamos > 0 ),
    monto_pago_cuotas INT check ( monto_pago_cuotas >= 0 ),
    cant_prestamos INT check ( cant_prestamos >= 0 ),
    ind_pagos_pendientes BOOLEAN,
    fecha TIMESTAMP,
    PRIMARY KEY (dni,fecha)
)

/*
INSTRUCTIVO PARA CARGAR DATOS EN CSV

** = Si queremos correr todo en pampero, sino podemos darle run en DataGrip

    Descargar los csv y ponerlos en una carpeta "BD1-Grupo2"
    ** Poner dentro tambien el archivo sql

    Abrir una terminal en el CWD y pasar los CSV a pampero
        scp -r ./BD1-Grupo2 gfrancois@pampero.itba.edu.ar:./

    Conectarse con Pampero
        ssh usuario@pampero.itba.edu.ar -L 8888:bd1.it.itba.edu.ar:5432

    Revisar que esten los documentos:
        cd BD1-Grupo2
        ls
    Deberia indicar: clientes_banco.csv  pagos_cuotas.csv  prestamos_banco.csv **tables.sql

   ** Correr el sql para generar las tablas (solo una vez)
        psql -h bd1.it.itba.edu.ar -U usuario -f tables.sql PROOF

    Conectarse con postgresql
        psql -h bd1.it.itba.edu.ar -U usuario PROOF

    Copiar los datos
        \copy cliente_tp(Codigo,Dni,Telefono,Nombre,Direccion) FROM clientes_banco.csv csv delimiter ',' header;
        \copy prestamo_tp(Codigo,Fecha,cod_cliente,Importe) FROM prestamos_banco.csv csv delimiter ',' header;
        \copy cuota_tp(numero_couta,cod_prestamo,Importe,Fecha) FROM pagos_cuotas.csv csv delimiter ',' header;

    Verificar que se cargaron los datos desde datagrip

    salir de postgresql
        exit

    salir de la carpeta
        cd ..

    Mantenerse en pampero para utilizar las tablas desde DataGrip
 */

/*
VERIFICAR QUE SE CARGO
select *
from cliente_tp;


select *
from prestamo_tp;

select *
from cuota_tp;
 */