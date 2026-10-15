USE moda_urbana;

DROP PROCEDURE IF EXISTS sp_top_rentabilidad_region;

DELIMITER $$

CREATE PROCEDURE sp_top_rentabilidad_region(
    IN p_anio INT, -- año del trimestre actual
    IN p_trimestre INT, -- trimestre actual (1 a 4)
    IN p_top_n INT -- cuántas variantes por región
)

BEGIN
    DECLARE v_anio_ant INT;
    DECLARE v_trim_ant INT;

    -- 1) Validación de parámetros
    IF p_anio IS NULL OR p_trimestre IS NULL OR p_top_n IS NULL
        OR p_trimestre < 1 OR p_trimestre > 4 OR p_top_n < 1 
            THEN SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parametros invalidos: trimestre debe ser 1-4 y top_n >= 1';
    END IF;

    -- 2) Trimestre anterior (si el actual es Q1, el anterior es Q4 del año previo)
    IF p_trimestre = 1 THEN
        SET v_anio_ant = p_anio - 1;
        SET v_trim_ant = 4;
    ELSE
        SET v_anio_ant = p_anio;
        SET v_trim_ant = p_trimestre - 1;
    END IF;

    -- 3) Lógica validada con parámetros
    WITH rent_actual AS (
        SELECT
            sv.region, p.producto_key, p.sku,
            p.nombre AS nombre_producto, p.talla, p.color,
            SUM(f.margen_total) AS rentabilidad_actual

        FROM FACT_VENTAS f
        INNER JOIN DIM_PRODUCTO p ON p.producto_key = f.producto_key
        INNER JOIN DIM_SUCURSAL_VENTA sv ON sv.sucursal_venta_key = f.sucursal_venta_key
        INNER JOIN DIM_TIEMPO t ON t.fecha_key = f.fecha_key

        WHERE f.estado_venta = 'completada'
            AND t.anio = p_anio
            AND t.trimestre = p_trimestre

        GROUP BY sv.region, p.producto_key, p.sku, p.nombre, p.talla, p.color
    ),

    rent_anterior AS (
        SELECT
            sv.region, f.producto_key,
            SUM(f.margen_total) AS rentabilidad_anterior

        FROM FACT_VENTAS f
        INNER JOIN DIM_SUCURSAL_VENTA sv ON sv.sucursal_venta_key = f.sucursal_venta_key
        INNER JOIN DIM_TIEMPO t ON t.fecha_key = f.fecha_key

        WHERE f.estado_venta = 'completada'
            AND t.anio = v_anio_ant
            AND t.trimestre = v_trim_ant

        GROUP BY sv.region, f.producto_key
    ),

    comparativo AS (
        SELECT
            a.region,
            ROW_NUMBER() OVER (
                PARTITION BY a.region
                ORDER BY a.rentabilidad_actual DESC, a.producto_key ASC
            ) AS posicion_region,
            a.producto_key, a.sku, a.nombre_producto,
            a.talla, a.color, a.rentabilidad_actual,
            COALESCE(b.rentabilidad_anterior, 0.00) AS rentabilidad_anterior,
            ROUND(a.rentabilidad_actual - COALESCE(b.rentabilidad_anterior, 0.00), 2) AS variacion_absoluta,

            CASE
                WHEN b.rentabilidad_anterior IS NULL OR b.rentabilidad_anterior = 0 THEN NULL
                ELSE ROUND((a.rentabilidad_actual - b.rentabilidad_anterior) / b.rentabilidad_anterior * 100, 2)
            END AS variacion_porcentual,

            CASE
                WHEN b.rentabilidad_anterior IS NULL THEN 'sin_dato_periodo_anterior'
                WHEN b.rentabilidad_anterior = 0 THEN 'base_cero_periodo_anterior'
                ELSE 'con_dato_periodo_anterior'
            END AS indicador_periodo_anterior

        FROM rent_actual a
        LEFT JOIN rent_anterior b
            ON b.region = a.region
            AND b.producto_key = a.producto_key
    )

    SELECT
        region, posicion_region, producto_key, sku, nombre_producto, talla, color,
        rentabilidad_actual, rentabilidad_anterior,
        variacion_absoluta, variacion_porcentual, indicador_periodo_anterior
    FROM comparativo
    WHERE posicion_region <= p_top_n
    ORDER BY region ASC, posicion_region ASC;
END$$

DELIMITER ;

-- Pruebas: 

CALL sp_top_rentabilidad_region(2026, 2, 5);
CALL sp_top_rentabilidad_region(2026, 2, 3);
CALL sp_top_rentabilidad_region(2026, 1, 5);
-- CALL sp_top_rentabilidad_region(2026, 5, 5);