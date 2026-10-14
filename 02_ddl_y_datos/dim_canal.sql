-- Genera un catálogo de canales fijo de 4 filas. [DIM_CANAL]:
INSERT INTO DIM_CANAL (nombre_canal, es_online, requiere_entrega_tienda) VALUES
('tienda física', FALSE, FALSE),
('app', TRUE, FALSE),
('e-commerce', TRUE, FALSE),
('click & collect', TRUE, TRUE);
