-- 30 clientes [DIM_CLIENTE]:
INSERT INTO DIM_CLIENTE (cliente_id, nivel_lealtad, ciudad, genero_opcional, fecha_alta)
WITH RECURSIVE n AS (
    SELECT 1 AS i UNION ALL
    SELECT i + 1 FROM n WHERE i < 30
)
SELECT
    i,
    CASE 
        WHEN i % 3 = 0 THEN 'oro' 
        WHEN i % 3 = 1 THEN 'plata' 
        ELSE 'bronce' END,
    CASE i % 4 
        WHEN 0 THEN 'Ciudad de México' 
        WHEN 1 THEN 'Monterrey'
        WHEN 2 THEN 'Guadalajara' 
        ELSE 'Saltillo' END,
    CASE 
        WHEN i % 2 = 0 THEN 'femenino' 
        ELSE 'masculino' END,
    DATE('2024-01-01') + INTERVAL (i * 10) DAY
FROM n;
