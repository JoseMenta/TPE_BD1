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
