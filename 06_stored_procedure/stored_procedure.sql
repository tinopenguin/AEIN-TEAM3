USE moda_urbana;
DROP PROCEDURE IF EXISTS sp_top5_rentabilidad_region;
DELIMITER $$

CREATE PROCEDURE sp_top5_rentabilidad_region(
    IN p_anio INT,
    IN p_trimestre INT
)
BEGIN
    DECLARE v_anio_ant INT;
    DECLARE v_trim_ant INT;

    -- Validación de parámetros (NULL o trimestre fuera de 1..4)
    IF p_anio IS NULL OR p_trimestre IS NULL
        OR p_trimestre NOT BETWEEN 1 AND 4 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parámetros inválidos';
    END IF;

    -- Periodo anterior: si es Q1, es Q4 del año pasado
    IF p_trimestre = 1 THEN
        SET v_anio_ant = p_anio - 1;
        SET v_trim_ant = 4;
    ELSE
        SET v_anio_ant = p_anio;
        SET v_trim_ant = p_trimestre - 1;
    END IF;

    WITH rent_actual AS (
        -- Etapa 1: rentabilidad por región de venta y variante en el periodo actual
        SELECT sv.region, p.producto_key, p.sku, p.nombre AS nombre_producto,
            p.talla, p.color, p.categoria,
            SUM(f.cantidad) AS unidades_actual,
            SUM(f.venta_neta) AS ventas_netas_actual,
            SUM(f.costo_total) AS costo_total_actual,
            SUM(f.margen_total) AS rentabilidad_actual
        FROM FACT_VENTAS f
        INNER JOIN DIM_PRODUCTO p ON p.producto_key = f.producto_key
        INNER JOIN DIM_SUCURSAL_VENTA sv ON sv.sucursal_venta_key = f.sucursal_venta_key
        INNER JOIN DIM_TIEMPO t ON t.fecha_key = f.fecha_key
        WHERE f.estado_venta = 'completada'
            AND t.anio = p_anio AND t.trimestre = p_trimestre
        GROUP BY sv.region, p.producto_key, p.sku, p.nombre, p.talla, p.color, p.categoria
    ),
    rent_anterior AS (
        -- Etapa 2: lo mismo para el periodo anterior
        SELECT sv.region, p.producto_key, SUM(f.margen_total) AS rentabilidad_anterior
        FROM FACT_VENTAS f
        INNER JOIN DIM_PRODUCTO p ON p.producto_key = f.producto_key
        INNER JOIN DIM_SUCURSAL_VENTA sv ON sv.sucursal_venta_key = f.sucursal_venta_key
        INNER JOIN DIM_TIEMPO t ON t.fecha_key = f.fecha_key
        WHERE f.estado_venta = 'completada'
            AND t.anio = v_anio_ant AND t.trimestre = v_trim_ant
        GROUP BY sv.region, p.producto_key
    ),
    comparativo_regional AS (
        -- Etapa 3: LEFT JOIN entre periodos, variaciones y ranking
        SELECT a.region,
            ROW_NUMBER() OVER (PARTITION BY a.region
        ORDER BY a.rentabilidad_actual DESC, a.producto_key ASC) AS posicion_region,
            a.producto_key, a.sku, a.nombre_producto, a.talla, a.color,
            a.rentabilidad_actual,
            COALESCE(b.rentabilidad_anterior, 0.00) AS rentabilidad_anterior,
            ROUND(a.rentabilidad_actual - COALESCE(b.rentabilidad_anterior, 0.00), 2) AS variacion_absoluta,
            CASE WHEN b.rentabilidad_anterior IS NULL OR b.rentabilidad_anterior = 0 THEN NULL
                ELSE ROUND(((a.rentabilidad_actual - b.rentabilidad_anterior) / NULLIF(b.rentabilidad_anterior, 0)) * 100, 2)
            END AS variacion_porcentual,
            CASE WHEN b.rentabilidad_anterior IS NULL THEN 'sin_dato_periodo_anterior'
                WHEN b.rentabilidad_anterior = 0 THEN 'base_cero_periodo_anterior'
                ELSE 'con_dato_periodo_anterior'
            END AS indicador_periodo_anterior
        FROM rent_actual a
        LEFT JOIN rent_anterior b ON b.region = a.region AND b.producto_key = a.producto_key
    )

    -- Etapa 4: Top 5 por región
    SELECT region, posicion_region, producto_key, sku, nombre_producto, talla, color,
        rentabilidad_actual, rentabilidad_anterior, variacion_absoluta,
        variacion_porcentual, indicador_periodo_anterior
    FROM comparativo_regional
    WHERE posicion_region <= 5
    ORDER BY region ASC, posicion_region ASC;
END$$

DELIMITER ;

-- =====================================================================
-- Llamadas de prueba (ejecutar una por una y guardar captura de cada salida)
-- =====================================================================
-- Prueba 1: Q2 2026 vs Q1 2026 -> deben salir las mismas 15 filas de la consulta final
CALL sp_top5_rentabilidad_region(2026, 2);

-- Prueba 2: Q1 2026 vs Q4 2025 -> sin ventas en Q4 2025, todas marcan 'sin_dato_periodo_anterior'
CALL sp_top5_rentabilidad_region(2026, 1);

-- Prueba 3: trimestre inválido -> Error 1644 'Parámetros inválidos'
-- CALL sp_top5_rentabilidad_region(2026, 5);

-- Prueba 4: parámetro nulo -> Error 1644 'Parámetros inválidos'
-- CALL sp_top5_rentabilidad_region(NULL, 2);
