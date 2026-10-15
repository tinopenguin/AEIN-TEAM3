-- ============================================================================
-- MATERIA: Business Intelligence | UNIDAD 3: Consultas SQL empresariales con IA
-- EMPRESA: Moda Urbana
-- ENTREGABLE 5: Consulta SQL (Versión Inicial IA y Versión Final Validada)
-- MOTOR: MySQL 8.0
-- ============================================================================

-- ============================================================================
-- PARTE 0: NOTA DE SINCRONIZACIÓN DDL UNIDAD 3 (EJECUTAR SI LA BASE ESTÁ VACÍA)
-- Asegura que las tablas creadas coincidan exactamente con los scripts de carga
-- de la carpeta 2/ (dim_canal.sql, dim_cliente.sql, dim_producto.sql,
-- dim_sucursal_venta.sql, dim_sucursal_entrega.sql, dim_tiempo.sql, fact_ventas.sql)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS moda_urbana;
USE moda_urbana;

CREATE TABLE IF NOT EXISTS DIM_TIEMPO(
    fecha_key INT PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    trimestre INT NOT NULL,
    temporada_comercial VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS DIM_CANAL(
    canal_key INT AUTO_INCREMENT PRIMARY KEY,
    nombre_canal VARCHAR(30) NOT NULL,
    es_online BOOLEAN NOT NULL,
    requiere_entrega_tienda BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS DIM_CLIENTE(
    cliente_key INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    nivel_lealtad VARCHAR(30),
    ciudad VARCHAR(30) NOT NULL,
    genero_opcional VARCHAR(20),
    fecha_alta DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS DIM_SUCURSAL_VENTA(
    sucursal_venta_key INT AUTO_INCREMENT PRIMARY KEY,
    sucursal_id INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    ciudad VARCHAR(30) NOT NULL,
    region VARCHAR(30) NOT NULL,
    tipo_tienda VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS DIM_SUCURSAL_ENTREGA(
    sucursal_entrega_key INT AUTO_INCREMENT PRIMARY KEY,
    sucursal_id INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    ciudad VARCHAR(30) NOT NULL,
    region VARCHAR(30) NOT NULL,
    tipo_tienda VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS DIM_PRODUCTO(
    producto_key INT AUTO_INCREMENT PRIMARY KEY,
    variante_id INT NOT NULL,
    sku VARCHAR(30) NOT NULL,
    talla VARCHAR(10) NOT NULL,
    color VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(60) NOT NULL,
    coleccion VARCHAR(60) NOT NULL,
    temporada VARCHAR(30) NOT NULL,
    marca VARCHAR(30) NOT NULL,
    costo_unitario DECIMAL(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS FACT_VENTAS(
    linea_id INT AUTO_INCREMENT PRIMARY KEY,
    orden_id INT NOT NULL,
    cliente_key INT NOT NULL,
    producto_key INT NOT NULL,
    sucursal_venta_key INT NOT NULL,
    sucursal_entrega_key INT NOT NULL,
    canal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    cantidad INT NOT NULL,
    precio_lista_total DECIMAL(10, 2) NOT NULL,
    descuento_total DECIMAL(10, 2) NOT NULL,
    venta_neta DECIMAL(10, 2) NOT NULL,
    costo_total DECIMAL(10, 2) NOT NULL,
    margen_total DECIMAL(10, 2) GENERATED ALWAYS AS (venta_neta - costo_total) STORED,
    tipo_precio VARCHAR(30) NOT NULL,
    estado_venta VARCHAR(20) NOT NULL,
    FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key),
    FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key),
    FOREIGN KEY (sucursal_venta_key) REFERENCES DIM_SUCURSAL_VENTA(sucursal_venta_key),
    FOREIGN KEY (sucursal_entrega_key) REFERENCES DIM_SUCURSAL_ENTREGA(sucursal_entrega_key),
    FOREIGN KEY (canal_key) REFERENCES DIM_CANAL(canal_key),
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key)
);


-- ============================================================================
-- PARTE 1: VERSIÓN INICIAL GENERADA POR LA IA (CONSERVADA COMO EVIDENCIA)
-- ============================================================================
-- Observaciones detectadas por el equipo durante la revisión crítica (Paso 5):
-- 1. La IA utilizó una sola CTE con agregación condicional y aplicó RANK() sin
--    criterio de desempate determinístico (en Región Norte SKU-0006 y SKU-0019
--    empatan con $5,760.00; si un empate ocurre en la posición 5, RANK() puede
--    devolver más de 5 filas por región).
-- 2. La IA omitió las columnas de variante (sku, talla, color) que en Moda Urbana
--    distinguen cada producto_key dentro de DIM_PRODUCTO.
-- 3. La IA no separó las CTEs por trimestre mediante LEFT JOIN explícito como lo
--    establece el documento de Definiciones de Negocio del equipo, y su etiqueta
--    de caso especial no utilizaba el identificador 'sin_dato_periodo_anterior'.
-- ============================================================================

EXPLAIN
WITH ventas_trimestrales_ia AS (
    SELECT
        sv.region,
        p.producto_key,
        p.nombre AS nombre_producto,
        SUM(CASE WHEN t.trimestre = 2 THEN (f.venta_neta - f.costo_total) ELSE 0 END) AS rentabilidad_q2,
        SUM(CASE WHEN t.trimestre = 1 THEN (f.venta_neta - f.costo_total) ELSE NULL END) AS rentabilidad_q1
    FROM FACT_VENTAS f
    INNER JOIN DIM_PRODUCTO p
        ON f.producto_key = p.producto_key
    INNER JOIN DIM_SUCURSAL_VENTA sv
        ON f.sucursal_venta_key = sv.sucursal_venta_key
    INNER JOIN DIM_TIEMPO t
        ON f.fecha_key = t.fecha_key
    WHERE f.estado_venta = 'completada'
      AND t.anio = 2026
      AND t.trimestre IN (1, 2)
    GROUP BY
        sv.region,
        p.producto_key,
        p.nombre
),
ranking_ia AS (
    SELECT
        region,
        RANK() OVER (PARTITION BY region ORDER BY rentabilidad_q2 DESC) AS posicion,
        producto_key,
        nombre_producto,
        rentabilidad_q2,
        COALESCE(rentabilidad_q1, 0) AS rentabilidad_q1,
        (rentabilidad_q2 - COALESCE(rentabilidad_q1, 0)) AS variacion_absoluta,
        ROUND(
            ((rentabilidad_q2 - rentabilidad_q1) / NULLIF(rentabilidad_q1, 0)) * 100,
            2
        ) AS variacion_porcentual,
        CASE
            WHEN rentabilidad_q1 IS NULL OR rentabilidad_q1 = 0 THEN 'Sin datos en Q1'
            ELSE 'Con datos en Q1'
        END AS estado_comparacion
    FROM ventas_trimestrales_ia
    WHERE rentabilidad_q2 > 0
)
SELECT *
FROM ranking_ia
WHERE posicion <= 5
ORDER BY region, posicion;


-- ============================================================================
-- PARTE 2: VERSIÓN FINAL VALIDADA POR EL EQUIPO (MODA URBANA - MYSQL 8.0)
-- ============================================================================
-- Mejoras aplicadas y validadas:
-- 1. Uso de la métrica generada oficial `f.margen_total` (definida como
--    `venta_neta - costo_total` en FACT_VENTAS).
-- 2. Dos CTEs independientes por periodo (`rent_q2` y `rent_q1`) unidas mediante
--    `LEFT JOIN` por `(region, producto_key)`, cumpliendo literalmente la regla
--    documentada en `Definiciones. Act 3. Moda Urbana.pdf`.
-- 3. Inclusión de `p.producto_key`, `p.sku`, `p.nombre`, `p.talla` y `p.color`
--    para respetar el grano de variante de producto de Moda Urbana.
-- 4. Uso de `ROW_NUMBER() OVER (PARTITION BY q2.region ORDER BY q2.rentabilidad_q2 DESC, q2.producto_key ASC)`
--    para garantizar estrictamente máximo 5 productos por región y desempate
--    determinístico (resuelve el empate de $5,760.00 en Región Norte entre
--    SKU-0006 y SKU-0019).
-- 5. Protección contra división entre cero con `NULLIF(q1.rentabilidad_q1, 0)` y
--    marcador exacto `'sin_dato_periodo_anterior'` cuando un producto no registra
--    ventas completadas en Q1 2026.
-- ============================================================================

WITH rent_q2 AS (
    -- Etapa 1: Rentabilidad acumulada por región de origen y variante en Q2 2026
    SELECT
        sv.region,
        p.producto_key,
        p.sku,
        p.nombre AS nombre_producto,
        p.talla,
        p.color,
        p.categoria,
        SUM(f.cantidad) AS unidades_q2,
        SUM(f.venta_neta) AS ventas_netas_q2,
        SUM(f.costo_total) AS costo_total_q2,
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
        p.color,
        p.categoria
),
rent_q1 AS (
    -- Etapa 2: Rentabilidad acumulada por región de origen y variante en Q1 2026
    SELECT
        sv.region,
        p.producto_key,
        SUM(f.cantidad) AS unidades_q1,
        SUM(f.venta_neta) AS ventas_netas_q1,
        SUM(f.costo_total) AS costo_total_q1,
        SUM(f.margen_total) AS rentabilidad_q1
    FROM FACT_VENTAS f
    INNER JOIN DIM_PRODUCTO p
        ON p.producto_key = f.producto_key
    INNER JOIN DIM_SUCURSAL_VENTA sv
        ON sv.sucursal_venta_key = f.sucursal_venta_key
    INNER JOIN DIM_TIEMPO t
        ON t.fecha_key = f.fecha_key
    WHERE f.estado_venta = 'completada'
      AND t.anio = 2026
      AND t.trimestre = 1
    GROUP BY
        sv.region,
        p.producto_key
),
comparativo_regional AS (
    -- Etapa 3: Unión LEFT JOIN entre Q2 y Q1, cálculo de variaciones y ranking por región
    SELECT
        q2.region,
        ROW_NUMBER() OVER (
            PARTITION BY q2.region
            ORDER BY q2.rentabilidad_q2 DESC, q2.producto_key ASC
        ) AS posicion_region,
        q2.producto_key,
        q2.sku,
        q2.nombre_producto,
        q2.talla,
        q2.color,
        q2.rentabilidad_q2,
        COALESCE(q1.rentabilidad_q1, 0.00) AS rentabilidad_q1,
        ROUND(q2.rentabilidad_q2 - COALESCE(q1.rentabilidad_q1, 0.00), 2) AS variacion_absoluta,
        CASE
            WHEN q1.rentabilidad_q1 IS NULL OR q1.rentabilidad_q1 = 0 THEN NULL
            ELSE ROUND(
                ((q2.rentabilidad_q2 - q1.rentabilidad_q1) / NULLIF(q1.rentabilidad_q1, 0)) * 100,
                2
            )
        END AS variacion_porcentual,
        CASE
            WHEN q1.rentabilidad_q1 IS NULL THEN 'sin_dato_periodo_anterior'
            WHEN q1.rentabilidad_q1 = 0 THEN 'base_cero_periodo_anterior'
            ELSE 'con_dato_periodo_anterior'
        END AS indicador_periodo_anterior
    FROM rent_q2 q2
    LEFT JOIN rent_q1 q1
        ON q1.region = q2.region
       AND q1.producto_key = q2.producto_key
)
-- Etapa 4: Filtro final del Top 5 por cada región
SELECT
    region,
    posicion_region,
    producto_key,
    sku,
    nombre_producto,
    talla,
    color,
    rentabilidad_q2,
    rentabilidad_q1,
    variacion_absoluta,
    variacion_porcentual,
    indicador_periodo_anterior
FROM comparativo_regional
WHERE posicion_region <= 5
ORDER BY
    region ASC,
    posicion_region ASC;


-- ============================================================================
-- PARTE 3: CONSULTAS DE CONTROL Y VALIDACIÓN DE RESULTADOS (PASO 6)
-- ============================================================================

-- Control 1: Conteo de líneas por estado_venta y trimestre (verifica grano sin duplicados)
SELECT
    t.anio,
    t.trimestre,
    f.estado_venta,
    COUNT(*) AS total_lineas,
    SUM(f.venta_neta) AS suma_venta_neta,
    SUM(f.costo_total) AS suma_costo_total,
    SUM(f.margen_total) AS suma_margen_total
FROM FACT_VENTAS f
INNER JOIN DIM_TIEMPO t
    ON t.fecha_key = f.fecha_key
GROUP BY
    t.anio,
    t.trimestre,
    f.estado_venta
ORDER BY
    t.trimestre,
    f.estado_venta;

-- Control 2: Muestra controlada manual para el Producto #1 de Región Norte
-- (producto_key = 11, SKU-0011, Bota Urbana M Negro)
SELECT
    t.trimestre,
    COUNT(*) AS num_lineas,
    SUM(f.cantidad) AS unidades_vendidas,
    SUM(f.venta_neta) AS venta_neta_total,
    SUM(f.costo_total) AS costo_total,
    SUM(f.margen_total) AS rentabilidad_margen
FROM FACT_VENTAS f
INNER JOIN DIM_SUCURSAL_VENTA sv
    ON sv.sucursal_venta_key = f.sucursal_venta_key
INNER JOIN DIM_TIEMPO t
    ON t.fecha_key = f.fecha_key
WHERE f.estado_venta = 'completada'
  AND t.anio = 2026
  AND sv.region = 'Región Norte'
  AND f.producto_key = 11
GROUP BY
    t.trimestre
ORDER BY
    t.trimestre;
