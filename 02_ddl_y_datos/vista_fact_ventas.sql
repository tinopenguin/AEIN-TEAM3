-- Vista que junta el FACT con sus DIM más usadas.
CREATE OR REPLACE VIEW VW_VENTAS_DETALLE AS
SELECT
    f.linea_id, f.orden_id, f.cantidad, f.venta_neta,
    f.costo_total, f.margen_total, f.estado_venta, p.producto_key,
    p.nombre AS producto_nombre, p.categoria, p.coleccion,
    sv.region AS region_venta, sv.nombre AS sucursal_nombre,
    c.nombre_canal, t.anio, t.trimestre
FROM FACT_VENTAS f
JOIN DIM_PRODUCTO p ON p.producto_key = f.producto_key
JOIN DIM_SUCURSAL_VENTA sv ON sv.sucursal_venta_key = f.sucursal_venta_key
JOIN DIM_CANAL c ON c.canal_key = f.canal_key
JOIN DIM_TIEMPO t ON t.fecha_key = f.fecha_key;
