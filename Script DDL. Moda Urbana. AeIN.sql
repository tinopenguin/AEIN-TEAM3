-- 1) DIM_TIEMPO.
-- Propia del Data Mart, es para poder analizar por temporada comercial.
CREATE TABLE DIM_TIEMPO(
    fecha_key INT PRIMARY KEY, 
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    trimestre INT NOT NULL,
    temporada_comercial VARCHAR(30) NOT NULL -- "Primavera-Verano", "Otoño-Invierno".
);

-- 2) DIM_CANAL.
-- Tabla propia del Data Mart, es para poder analizar por canal de venta.
CREATE TABLE DIM_CANAL(
    canal_key INT PRIMARY KEY,
    nombre_canal VARCHAR(30) NOT NULL, -- "tienda física", "e-commerce", etc.
    es_online BOOLEAN NOT NULL,
    requiere_entrega_linea BOOLEAN NOT NULL -- true si la venta requiere entrega de la línea, false si es click & collect.
);

-- 3) DIM_CLIENTE.
-- Tabla para analizar la información más relevante de los clientes.
CREATE TABLE DIM_CLIENTE(
    cliente_key INT PRIMARY KEY,
    cliente_id INT NOT NULL, -- ID natural de origen del cliente.
    nivel_lealtad VARCHAR(30),
    ciudad VARCHAR(30) NOT NULL,
    genero_opcional VARCHAR(20),
    fecha_alta DATE NOT NULL
);

-- 4) DIM_SUCURSAL.
-- Referenciada dos veces en FACT_VENTAS (venta y entrega) para distinguir entre venta online 
-- y click & collect.
CREATE TABLE DIM_SUCURSAL(
    sucursal_key INT PRIMARY KEY,
    sucursal_id INT NOT NULL, -- ID natural de origen de la sucursal.
    nombre VARCHAR(30) NOT NULL,
    ciudad VARCHAR(30) NOT NULL,
    region VARCHAR(30) NOT NULL,
    tipo_tienda VARCHAR(30) NOT NULL
);

-- 5) DIM_PRODUCTO.
-- Combinación de Variantes y Productos. Analiza por variante y no solo por producto general.
CREATE TABLE DIM_PRODUCTO(
    producto_key INT PRIMARY KEY,
    variante_id INT NOT NULL, -- ID natural de origen de la variante.
    sku VARCHAR(30) NOT NULL,
    talla VARCHAR(10) NOT NULL,
    color VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(60) NOT NULL,
    coleccion VARCHAR(60) NOT NULL,
    temporada VARCHAR(30) NOT NULL,
    marca VARCHAR(30) NOT NULL
);

-- 6) DIM_CUPON.
-- Tabla opcional ya que no toda venta usa cupón.
CREATE TABLE DIM_CUPON(
    cupon_key INT PRIMARY KEY,
    cupon_id INT NOT NULL, -- ID natural de origen del cupón.
    tipo VARCHAR(30) NOT NULL,
    valor DECIMAL(10, 2) NOT NULL
);

-- 7) DIM_MOTIVO_DEVOLUCION.
-- Tabla para analizar los motivos de devolución.
CREATE TABLE DIM_MOTIVO_DEVOLUCION(
    motivo_key INT PRIMARY KEY,
    descripcion_motivo VARCHAR(100) NOT NULL,
    categoria_motivo VARCHAR(30) NOT NULL
);

-- 8) FACT_VENTAS.
-- Grano: una fila = variante vendida.
/* Métricas:
    - cantidad -> Unidades vendidas.
    - precio_lista_total -> Valor de la línea al precio original.
    - descuento_total -> Monto total descontado de la línea.
    - venta_neta -> Monto real vendido. */
CREATE TABLE FACT_VENTAS(
    linea_id INT PRIMARY KEY,
    orden_id INT NOT NULL,
    cliente_key INT NOT NULL,
    producto_key INT NOT NULL,
    sucursal_venta_key INT NOT NULL,
    sucursal_entrega_key INT NOT NULL,
    canal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    cupon_key INT NULL,
    cantidad INT NOT NULL,
    precio_lista_total DECIMAL(10, 2) NOT NULL, -- precio_lista * cantidad
    descuento_total DECIMAL(10, 2) NOT NULL, -- descuento * cantidad
    venta_neta DECIMAL(10, 2) NOT NULL, -- precio_venta * cantidad
    tipo_precio VARCHAR(30) NOT NULL, -- "regular", "liquidación", "promoción", etc.

    -- Definición de las llaves foráneas:
    FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key), -- cliente_key -> DIM_CLIENTE.cliente_key
    FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key), -- producto_key -> DIM_PRODUCTO.producto_key
    FOREIGN KEY (sucursal_venta_key) REFERENCES DIM_SUCURSAL(sucursal_key), -- sucursal_venta_key -> DIM_SUCURSAL.sucursal_key
    FOREIGN KEY (sucursal_entrega_key) REFERENCES DIM_SUCURSAL(sucursal_key), -- sucursal_entrega_key -> DIM_SUCURSAL.sucursal_key
    FOREIGN KEY (canal_key) REFERENCES DIM_CANAL(canal_key), -- canal_key -> DIM_CANAL.canal_key
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key), -- fecha_key -> DIM_TIEMPO.fecha_key
    FOREIGN KEY (cupon_key) REFERENCES DIM_CUPON(cupon_key), -- cupon_key -> DIM_CUPON.cupon_key
    
    -- Script para que "tipo_precio" diferencie entre precio "regular", "liquidación" y "promoción".
    CONSTRAINT chk_tipo_precio CHECK (tipo_precio IN ('regular', 'liquidacion', 'promocion')),
);

-- 9) FACT_MOVIMIENTO_LEALTAD.
-- Grano: una fila = movimiento de puntos de lealtad.
CREATE TABLE FACT_MOVIMIENTO_LEALTAD(
    movimiento_key INT PRIMARY KEY,
    cliente_key INT NOT NULL,
    fecha_key INT NOT NULL,
    orden_id INT NOT NULL,
    puntos_ganados INT NOT NULL,
    puntos_canjeados INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL, -- "ganancia", "canje", "ajuste", etc.

    -- Definición de las llaves foráneas:
    FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key), -- cliente_key -> DIM_CLIENTE.cliente_key
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key) -- fecha_key -> DIM_TIEMPO.fecha_key
);

-- 10) FACT_DEVOLUCIONES.
-- Grano: una fila = variante devuelta.
CREATE TABLE FACT_DEVOLUCIONES(
    devolucion_key INT PRIMARY KEY,
    producto_key INT NOT NULL,
    sucursal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    motivo_key INT NOT NULL, -- Llave foránea a DIM_MOTIVO_DEVOLUCION.
    linea_id INT NOT NULL, -- Llave foránea a FACT_VENTAS.
    tipo_movimiento VARCHAR(30) NOT NULL, -- "devolución", "reemplazo", etc.
    importe_devuelto DECIMAL(10, 2) NOT NULL,

    -- Definición de las llaves foráneas:
    FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key), -- producto_key -> DIM_PRODUCTO.producto_key
    FOREIGN KEY (sucursal_key) REFERENCES DIM_SUCURSAL(sucursal_key), -- sucursal_venta_key -> DIM_SUCURSAL.sucursal_key
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key), -- fecha_key -> DIM_TIEMPO.fecha_key
    FOREIGN KEY (motivo_key) REFERENCES DIM_MOTIVO_DEVOLUCION(motivo_key), -- motivo_key -> DIM_MOTIVO_DEVOLUCION.motivo_key
    FOREIGN KEY (linea_id) REFERENCES FACT_VENTAS(linea_id) -- linea_id -> FACT_VENTAS.linea_id
);