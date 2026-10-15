-- DIM_TIEMPO -> es para poder analizr por temporada comercial.
CREATE TABLE DIM_TIEMPO(
    fecha_key INT PRIMARY KEY,   
    fecha DATE NOT NULL UNIQUE,
    anio INT NOT NULL,
    mes INT NOT NULL,
    trimestre INT NOT NULL,
    temporada_comercial  VARCHAR(30)
);

-- DIM_CANAL -> es para poder analizar por canal de venta.
CREATE TABLE DIM_CANAL(
    canal_key INT AUTO_INCREMENT PRIMARY KEY,
    nombre_canal VARCHAR(30) NOT NULL UNIQUE,
    es_online BOOLEAN NOT NULL,
    requiere_entrega_tienda BOOLEAN NOT NULL
);

-- DIM_CLIENTE -> tabla para analizar la información más relevante de los clientes.
CREATE TABLE DIM_CLIENTE(
    cliente_key INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL UNIQUE,
    nivel_lealtad VARCHAR(20),
    ciudad VARCHAR(60),
    genero_opcional VARCHAR(20),
    fecha_alta DATE
);

-- DIM_SUCURSAL_VENTA / DIM_SUCURSAL_ENTREGA
-- Mismas sucursales físicas en ambas tablas, con el mismo sucursal_id; deben cargarse siempre en pareja.
CREATE TABLE DIM_SUCURSAL_VENTA(
    sucursal_venta_key INT AUTO_INCREMENT PRIMARY KEY,
    sucursal_id INT NOT NULL UNIQUE,
    nombre VARCHAR(80),
    ciudad VARCHAR(60),
    region VARCHAR(60) NOT NULL,
    tipo_tienda VARCHAR(30)
);

CREATE TABLE DIM_SUCURSAL_ENTREGA(
    sucursal_entrega_key INT AUTO_INCREMENT PRIMARY KEY,
    sucursal_id INT NOT NULL UNIQUE,
    nombre VARCHAR(80),
    ciudad VARCHAR(60),
    region VARCHAR(60) NOT NULL,
    tipo_tienda  VARCHAR(30)
);

-- DIM_PRODUCTO -> Una fila = una variante (talla y color) de un producto. Costo_unitario es dato SIMULADO.
CREATE TABLE DIM_PRODUCTO(
    producto_key INT AUTO_INCREMENT PRIMARY KEY,
    variante_id INT NOT NULL UNIQUE,
    sku VARCHAR(30),
    talla VARCHAR(10),
    color VARCHAR(30),
    nombre VARCHAR(120) NOT NULL,
    categoria VARCHAR(60),
    coleccion VARCHAR(60),
    temporada VARCHAR(30),
    marca VARCHAR(60),
    costo_unitario DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_costo_no_negativo CHECK (costo_unitario >= 0)
);

-- DIM_CUPON -> relación con FACT_VENTAS.
CREATE TABLE DIM_CUPON(
    cupon_key INT AUTO_INCREMENT PRIMARY KEY,
    tipo VARCHAR(30) NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CONSTRAINT chk_cupon_vigencia CHECK (fecha_fin >= fecha_inicio)
);

-- DIM_MOTIVO_DEVOLUCION -> evita motivos en texto libre.
CREATE TABLE DIM_MOTIVO_DEVOLUCION(
    motivo_key INT AUTO_INCREMENT PRIMARY KEY,
    descripcion_motivo VARCHAR(60) NOT NULL UNIQUE,
    categoria_motivo VARCHAR(40) NOT NULL
);

-- FACT_VENTAS:
-- Métricas aditivas: cantidad, precio_lista_total, descuento_total,
-- venta_neta, costo_total, margen_total.
-- margen_total es GENERATED: nunca puede quedar distinto de venta_neta - costo_total.
-- orden_id es atributo degenerado (trazabilidad al sistema origen, sin FK porque no existe DIM_ORDEN).
CREATE TABLE FACT_VENTAS(
    linea_id INT AUTO_INCREMENT PRIMARY KEY,
    orden_id INT NOT NULL,
    cliente_key INT NOT NULL,
    producto_key INT NOT NULL,
    sucursal_venta_key INT NOT NULL,
    sucursal_entrega_key INT NOT NULL,
    canal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    cupon_key INT NULL,
    cantidad INT NOT NULL,
    precio_lista_total DECIMAL(12,2) NOT NULL,
    descuento_total DECIMAL(12,2) NOT NULL,
    venta_neta DECIMAL(12,2) NOT NULL,
    costo_total DECIMAL(12,2) NOT NULL,
    margen_total DECIMAL(12,2) GENERATED ALWAYS AS (venta_neta - costo_total) STORED,
    tipo_precio VARCHAR(15) NOT NULL,
    estado_venta VARCHAR(20) NOT NULL DEFAULT 'completada',

    CONSTRAINT fk_venta_cliente FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key),
    CONSTRAINT fk_venta_producto FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key),
    CONSTRAINT fk_venta_sucursal_venta FOREIGN KEY (sucursal_venta_key) REFERENCES DIM_SUCURSAL_VENTA(sucursal_venta_key),
    CONSTRAINT fk_venta_sucursal_entrega FOREIGN KEY (sucursal_entrega_key) REFERENCES DIM_SUCURSAL_ENTREGA(sucursal_entrega_key),
    CONSTRAINT fk_venta_canal FOREIGN KEY (canal_key) REFERENCES DIM_CANAL(canal_key),
    CONSTRAINT fk_venta_fecha FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key),
    CONSTRAINT fk_venta_cupon FOREIGN KEY (cupon_key) REFERENCES DIM_CUPON(cupon_key),

    CONSTRAINT chk_tipo_precio CHECK (tipo_precio IN ('regular', 'liquidacion', 'promocion')),
    CONSTRAINT chk_estado_venta CHECK (estado_venta IN ('completada', 'cancelada')),
    CONSTRAINT chk_montos_no_negativos
        CHECK (precio_lista_total >= 0 AND descuento_total >= 0 AND venta_neta >= 0 AND costo_total >= 0),
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0)
);

-- FACT_DEVOLUCIONES:
-- linea_id enlaza con la línea de venta devuelta. 
-- Producto_key se conserva como llave para analizar devoluciones por talla, color y producto; debe coincidir con el de la línea (se valida).
-- sucursal_key = sucursal donde se procesó la devolución; referencia DIM_SUCURSAL_VENTA.
CREATE TABLE FACT_DEVOLUCIONES(
    devolucion_key INT AUTO_INCREMENT PRIMARY KEY,
    linea_id INT NOT NULL,
    producto_key INT NOT NULL,
    sucursal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    motivo_key INT NOT NULL,
    cantidad_devuelta INT NOT NULL,
    monto_devuelto DECIMAL(12,2) NOT NULL,

    CONSTRAINT fk_dev_linea FOREIGN KEY (linea_id) REFERENCES FACT_VENTAS(linea_id),
    CONSTRAINT fk_dev_producto FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key),
    CONSTRAINT fk_dev_sucursal FOREIGN KEY (sucursal_key) REFERENCES DIM_SUCURSAL_VENTA(sucursal_venta_key),
    CONSTRAINT fk_dev_fecha FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key),
    CONSTRAINT fk_dev_motivo FOREIGN KEY (motivo_key) REFERENCES DIM_MOTIVO_DEVOLUCION(motivo_key),

    CONSTRAINT chk_dev_cantidad CHECK (cantidad_devuelta > 0),
    CONSTRAINT chk_dev_monto CHECK (monto_devuelto >= 0)
);

-- FACT_MOVIMIENTOS_LEALTAD
-- Un movimiento de puntos por fila. orden_id es degenerado.
CREATE TABLE FACT_MOVIMIENTOS_LEALTAD(
    movimiento_key INT AUTO_INCREMENT PRIMARY KEY,
    orden_id INT NOT NULL,
    cliente_key INT NOT NULL,
    fecha_key INT NOT NULL,
    puntos_ganados INT NOT NULL DEFAULT 0,
    puntos_canjeados INT NOT NULL DEFAULT 0,
    tipo_movimiento VARCHAR(15) NOT NULL,

    CONSTRAINT fk_lealtad_cliente FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key),
    CONSTRAINT fk_lealtad_fecha FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key),

    CONSTRAINT chk_lealtad_tipo CHECK (tipo_movimiento IN ('ganancia', 'canje')),
    CONSTRAINT chk_lealtad_puntos CHECK (puntos_ganados >= 0 AND puntos_canjeados >= 0)
);

-- ÍNDICES
-- Crea un índice por cada FK; estos índices adicionales y cubren los patrones de consulta más frecuentes del negocio.
CREATE INDEX idx_fact_producto_fecha ON FACT_VENTAS(producto_key, fecha_key);
CREATE INDEX idx_fact_sucursal_fecha ON FACT_VENTAS(sucursal_venta_key, fecha_key);
CREATE INDEX idx_fact_estado_fecha ON FACT_VENTAS(estado_venta, fecha_key); 
CREATE INDEX idx_fact_orden ON FACT_VENTAS(orden_id);
CREATE INDEX idx_dev_producto_fecha  ON FACT_DEVOLUCIONES(producto_key, fecha_key);
CREATE INDEX idx_lealtad_cliente_fecha ON FACT_MOVIMIENTOS_LEALTAD(cliente_key, fecha_key);