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
