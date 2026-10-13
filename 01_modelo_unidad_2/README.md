**EVOLUCIÓN DE LA UNIDAD 2.**

1. Se agregó "*FACT_DEVOLUCIONES*". Grano: una devolución de una línea de venta.
Se agregó porque "devoluciones por talla, color, producto y motivo" no se podía responder, poner "motivo" en FACT_VENTAS rompía el grano.

2. Se agregó "*DIM_MOTIVO_DEVOLUCION*". Dimensión con "*motivo_key*".
Para evitar el mismo motivo de las devoluciones escrito de formas diferentes.

3. Se agregó "*FACT_MOVIMIENTOS_LEALTAD*". Hecho con "*puntos_ganados*" y "*puntos_canjeados*".
Para poder analizar el uso de los puntos de los clientes.

4. "*DIM_CANAL*" con dos filtros. "*es_online*" y "*requiere_entrega_tienda*".
Para filtrar online contra click & collect sin comparar texto.

**CAMBIOS DE LA UNIDAD 3.**

5. "*DIM_PRODUCTO*" y "*costo_unitario*". Se agregó porque ninguna fuente traía costo, y sin él no hay rentabilidad.
6. "*FACT_VENTAS*", "*costo_inicial*" y "*margen_total*". El margen nunca puede quedar desincronizado.
7. "*FACT_VENTAS*" y "*estado_venta*". Para excluir cancelaciones de la rentabilidad.
8. "*FACT_VENTAS*", "*sucursal_venta_key*" y "*sucursal_entrega_key*". Para identificar la sucursal de cada venta y entrega.
