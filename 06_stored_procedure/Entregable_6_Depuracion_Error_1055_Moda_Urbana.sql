-- ============================================================================
-- MATERIA: Business Intelligence | UNIDAD 3: Consultas SQL empresariales con IA
-- EMPRESA: Moda Urbana
-- ENTREGABLE 6: Depuración del Error de Agrupación 1055 (ONLY_FULL_GROUP_BY)
-- MOTOR: MySQL 8.0
-- ============================================================================

-- 1. Asegurar que la sesión de MySQL 8 tenga activo el modo estricto ONLY_FULL_GROUP_BY
SET SESSION sql_mode = CONCAT(@@sql_mode, ',ONLY_FULL_GROUP_BY');
SELECT @@SESSION.sql_mode AS modo_sql_activo;

-- ============================================================================
-- 2. CONSULTA CON ERROR DE AGRUPACIÓN INCOMPLETA (PROVOCA EL ERROR 1055)
-- ============================================================================
-- Contexto del error en Moda Urbana:
-- El analista desea consultar la rentabilidad del 2do trimestre de 2026 por
-- región y producto, mostrando también el identificador de la variante
-- (`p.producto_key`), el `p.sku`, la `p.talla` y el `p.color`.
-- Sin embargo, en la cláusula GROUP BY únicamente agrupa por `sv.region` y
-- `p.nombre` (nombre comercial del modelo, p. ej. 'Bota Urbana').
-- Como en DIM_PRODUCTO existen dos variantes por cada `p.nombre` (talla M/Negro
-- y talla L/Azul), `p.nombre` NO es clave primaria ni determina funcionalmente
-- a `p.producto_key`, `p.sku`, `p.talla` ni `p.color`.
-- ============================================================================

SELECT
    sv.region,
    p.producto_key,
    p.sku,
    p.nombre AS nombre_producto,
    p.talla,
    p.color,
    SUM(f.margen_total) AS rentabilidad_q2
FROM FACT_VENTAS f
INNER JOIN DIM_PRODUCTO p
    ON p.producto_key = f.producto_key
INNER JOIN DIM_SUCURSAL_VENTA sv
    ON sv.sucursal_venta_key = f.sucursal_venta_key
INNER JOIN DIM_TIEMPO t
    ON t.fecha_key = f.fecha_key
WHERE f.estado_venta = 'completada'
  AND t.anio = 2026
  AND t.trimestre = 2
GROUP BY
    sv.region,
    p.nombre;

-- ============================================================================
-- 3. MENSAJE DE ERROR 1055 CONSERVADO DE MYSQL 8.0
-- ============================================================================
/*
ERROR 1055 (42000): Expression #2 of SELECT list is not in GROUP BY clause and
contains nonaggregated column 'moda_urbana.p.producto_key' which is not
functionally dependent on columns in GROUP BY clause; this is incompatible
with sql_mode=only_full_group_by
*/

-- ============================================================================
-- 4. CONSULTA CORREGIDA Y VALIDADA (COHERENTE CON EL GRANO DE VARIANTE)
-- ============================================================================
-- Explicación de la corrección:
-- Para que la agrupación sea coherente con el grano de `DIM_PRODUCTO` y de
-- `FACT_VENTAS` en Moda Urbana (donde cada fila representa una variante de
-- talla y color vendida), se incluyen en el `GROUP BY` todas las columnas
-- descriptivas no agregadas de la variante (`sv.region`, `p.producto_key`,
-- `p.sku`, `p.nombre`, `p.talla`, `p.color`). Así cada grupo representa de
-- manera unívoca una combinación (Región, Variante SKU) y `SUM(f.margen_total)`
-- suma exactamente las líneas de venta de esa variante sin ambigüedad.
-- ============================================================================

SELECT
    sv.region,
    p.producto_key,
    p.sku,
    p.nombre AS nombre_producto,
    p.talla,
    p.color,
    SUM(f.margen_total) AS rentabilidad_q2
FROM FACT_VENTAS f
INNER JOIN DIM_PRODUCTO p
    ON p.producto_key = f.producto_key
INNER JOIN DIM_SUCURSAL_VENTA sv
    ON sv.sucursal_venta_key = f.sucursal_venta_key
INNER JOIN DIM_TIEMPO t
    ON t.fecha_key = f.fecha_key
WHERE f.estado_venta = 'completada'
  AND t.anio = 2026
  AND t.trimestre = 2
GROUP BY
    sv.region,
    p.producto_key,
    p.sku,
    p.nombre,
    p.talla,
    p.color
ORDER BY
    sv.region ASC,
    rentabilidad_q2 DESC,
    p.producto_key ASC;
