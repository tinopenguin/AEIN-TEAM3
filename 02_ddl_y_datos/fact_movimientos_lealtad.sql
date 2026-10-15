-- Acumulación y canje de puntos [FACT_MOVIMIENTOS_LEALTAD]
INSERT INTO fact_movimientos_lealtad (orden_id, cliente_key, fecha_key, puntos_ganados, puntos_canjeados, tipo_movimiento)
SELECT
    f.orden_id, f.cliente_key, f.fecha_key,
    FLOOR(f.venta_neta / 10), 0, 'ganancia'
FROM fact_ventas f
WHERE f.estado_venta = 'completada'
ORDER BY f.linea_id;

INSERT INTO fact_movimientos_lealtad (orden_id, cliente_key, fecha_key, puntos_ganados, puntos_canjeados, tipo_movimiento)
SELECT
    f.orden_id, f.cliente_key, f.fecha_key, 0,
    CASE c.nivel_lealtad 
        WHEN 'oro' THEN 100 
        ELSE 50 END, 'canje'
FROM fact_ventas f
INNER JOIN dim_cliente c ON c.cliente_key = f.cliente_key
WHERE f.estado_venta = 'completada'
    AND f.linea_id % 15 = 0
    AND c.nivel_lealtad IN ('plata', 'oro')
ORDER BY f.linea_id;