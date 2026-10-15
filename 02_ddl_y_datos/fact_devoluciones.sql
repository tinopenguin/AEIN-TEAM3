-- Tabla de hechos de devoluciones[FACT_DEVOLUCIONES]
INSERT INTO fact_devoluciones (linea_id, producto_key, sucursal_key, fecha_key, motivo_key, cantidad_devuelta, monto_devuelto)
SELECT
    x.linea_id, x.producto_key, x.sucursal_venta_key,
    td.fecha_key, (x.linea_id % 8) + 1, x.cant_dev,
    ROUND(x.venta_neta / x.cantidad * x.cant_dev, 2)
FROM (
    SELECT
        f.linea_id, f.producto_key, f.sucursal_venta_key,
        f.cantidad, f.venta_neta, tv.fecha AS fecha_venta,
        LEAST(f.cantidad, 1 + (f.linea_id % 2)) AS cant_dev
    FROM fact_ventas f
    INNER JOIN dim_tiempo tv ON tv.fecha_key = f.fecha_key
    WHERE f.estado_venta = 'completada'
        AND f.linea_id % 17 = 0
) x
INNER JOIN dim_tiempo td
    ON td.fecha = LEAST(DATE_ADD(x.fecha_venta, INTERVAL 3 + (x.linea_id % 10) DAY), '2026-06-30')