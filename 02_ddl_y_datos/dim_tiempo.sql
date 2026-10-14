-- Genera un día por fila del 2026-01-01 al 2026-06-30. [DIM_TIEMPO]:
INSERT INTO DIM_TIEMPO (fecha_key, fecha, anio, mes, trimestre, temporada_comercial)
WITH RECURSIVE dias AS (
    SELECT DATE('2026-01-01') AS fecha UNION ALL
    SELECT fecha + INTERVAL 1 DAY FROM dias WHERE fecha < '2026-06-30'
)
SELECT
    CAST(DATE_FORMAT(fecha, '%Y%m%d') AS UNSIGNED),
    fecha, YEAR(fecha), MONTH(fecha), QUARTER(fecha),
    CASE WHEN MONTH(fecha) <= 3 THEN 'Otoño-Invierno' ELSE 'Primavera-Verano' END
FROM dias;
