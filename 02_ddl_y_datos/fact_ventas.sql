-- 1,000 líneas de venta repartidas entre clientes, productos, sucursales, cana y fecha. [FACT_VENTAS]:
INSERT INTO FACT_VENTAS (orden_id, cliente_key, producto_key, sucursal_venta_key, sucursal_entrega_key, canal_key, fecha_key, cantidad, precio_lista_total, descuento_total, venta_neta, costo_total, tipo_precio, estado_venta)
WITH RECURSIVE secuencia AS (
    SELECT 1 AS i UNION ALL
    SELECT i + 1 FROM secuencia WHERE i < 1080
),
base AS (
    SELECT
        i,
        1000 + CEIL(i / 1.5) AS orden_id,
        1 + (i % 30) AS cliente_key,
        1 + (i % 20) AS producto_key,
        1 + (i % 6) AS sucursal_venta_key,
        1 + (i % 4) AS canal_key,
        DATE('2026-01-01') + INTERVAL (i % 181) DAY AS fecha_venta,
        1 + (i % 3) AS cantidad,
        CASE i % 5 
            WHEN 0 THEN 'regular'
            WHEN 1 THEN 'promocion' 
            WHEN 2 THEN 'promocion'
            ELSE 'liquidacion' END AS tipo_precio,
        CASE i % 5 
            WHEN 0 THEN 0.00
            WHEN 1 THEN 0.10 
            WHEN 2 THEN 0.15
            ELSE 0.30 END AS descuento_pct
    FROM secuencia
)
SELECT
    b.orden_id, b.cliente_key, b.producto_key, b.sucursal_venta_key,
    
    /* misma sucursal si el canal no requiere entrega en tienda; si sí,
       se entrega en la sucursal siguiente (JOIN a DIM_CANAL para leerlo) */
    CASE WHEN can.requiere_entrega_tienda THEN 1 + ((b.sucursal_venta_key) % 6)
        ELSE b.sucursal_venta_key END AS sucursal_entrega_key, b.canal_key,
    CAST(DATE_FORMAT(b.fecha_venta, '%Y%m%d') AS UNSIGNED) AS fecha_key, b.cantidad,

    /* SUBCONSULTA: obtiene el costo de esa variante 
        directamente de DIM_PRODUCTO para construir el precio de lista */
    ROUND((SELECT costo_unitario FROM DIM_PRODUCTO p WHERE p.producto_key = b.producto_key) / 0.60
        * b.cantidad, 2) AS precio_lista_total,
    ROUND((SELECT costo_unitario FROM DIM_PRODUCTO p WHERE p.producto_key = b.producto_key) / 0.60
        * b.cantidad * b.descuento_pct, 2) AS descuento_total,
    ROUND((SELECT costo_unitario FROM DIM_PRODUCTO p WHERE p.producto_key = b.producto_key) / 0.60
        * b.cantidad * (1 - b.descuento_pct), 2) AS venta_neta,
    ROUND((SELECT costo_unitario FROM DIM_PRODUCTO p WHERE p.producto_key = b.producto_key)
        * b.cantidad, 2) AS costo_total, b.tipo_precio,
    CASE 
        WHEN b.i % 20 = 0 THEN 'cancelada' 
        ELSE 'completada' END AS estado_venta
FROM base b
JOIN DIM_CANAL can ON can.canal_key = b.canal_key;
