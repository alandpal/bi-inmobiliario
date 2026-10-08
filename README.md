# BI inmobiliario · de FacturaPlus a un cuadro de mando en Power BI

Sistema de *business intelligence* para una empresa patrimonial inmobiliaria, construido con datos reales y publicado aquí anonimizado. Lee los ficheros de **FacturaPlus** (facturas, recibos, cobros y contratos en DBF), los ordena en una base de datos **PostgreSQL organizada por inmuebles**, comprueba que **cada euro queda contado y explicado**, y alimenta un **cuadro de mando de Power BI** con rentabilidad, ocupación, contratos y deuda.

```
FacturaPlus (DBF)  ─┐
Tres Excel de       ├─►  Notebook de carga  ─►  PostgreSQL  ─►  Power BI
referencia          ─┘   (lee, limpia, cuadra)   (por inmuebles)
```

El notebook solo **lee** del programa de facturación; nunca escribe en él.

## Qué hay en este repositorio

| Archivo o carpeta | Contenido |
|---|---|
| `carga_incremental_completa.ipynb` | El notebook: carga clientes, proveedores, contratos, facturas y cobros; reconcilia cobros y pagos; y cierra con un cuadre final |
| `esquema_base_datos.sql` | Esquema de PostgreSQL: tablas y vistas, con comentarios |
| `plantillas_excel/` | Plantillas vacías de los tres Excel de entrada (inmuebles, a qué inmueble pertenece cada artículo, y tipo de operación de cada artículo) |
| `power_bi/bi_inmobiliario.pbit` | Plantilla de Power BI con el modelo, las relaciones, las medidas y las páginas del informe, sin datos. Al abrirla pide conectar con PostgreSQL (`localhost`, base `bi_inmobiliario`) |
| `power_bi/modelo_y_medidas.md` | Tablas, relaciones, medidas DAX y columnas calculadas del modelo de Power BI |
| `power_bi/tema_corporativo.json` | Tema de colores del informe |

## Cómo funciona

- **Carga incremental.** Cada ejecución recalcula todo en memoria y solo escribe en la base lo que ha cambiado. Una factura se compara entera con una «huella» de todas sus líneas: si cambia una, se reescribe esa factura; si desaparece del origen, se elimina. Ante un origen leído a medias, un freno de seguridad detiene la carga en vez de borrar.
- **Tablas puente en Excel.** FacturaPlus identifica cada línea por artículo y etiqueta, no por inmueble. Tres Excel lo resuelven: el catálogo de inmuebles, a qué inmueble corresponde cada artículo y qué tipo de operación es. Se rellenan una vez y se actualizan solo cuando aparece algo nuevo; el notebook avisa de lo que no puede resolver.
- **Cobros y pagos.** Para cada factura calcula lo cobrado o pagado de verdad y lo que queda pendiente, siguiendo los mecanismos de compensación de recibos de FacturaPlus.
- **Contratos.** Se identifican por cliente, artículo y fecha de inicio, y se agrupan por vivienda: una vivienda con su garaje y su trastero cuenta como una sola unidad de negocio.
- **Cuadre final.** La última celda demuestra que todo lo facturado acaba imputado a un inmueble, a un motivo registrado o descartado con motivo, y que la suma cuadra al céntimo con los DBF y con la base de datos.

## Cómo ejecutarlo

1. **Requisitos:** Python 3 con `pandas` (2.2 o superior), `numpy`, `dbfread`, `openpyxl`, `SQLAlchemy`, `psycopg2` y Jupyter; y PostgreSQL.
2. **Crear la base:** `CREATE DATABASE bi_inmobiliario;` y ejecutar `esquema_base_datos.sql` sobre ella.
3. **Preparar los Excel:** copiar las plantillas de `plantillas_excel/` a la carpeta de trabajo, borrar las filas de ejemplo y rellenarlas (cada una trae una hoja LEEME).
4. **Configurar la Celda 1 del notebook:** rutas de los DBF y de los Excel, y nombre de la base. La contraseña no se escribe en el notebook: se lee de la variable de entorno `PGPASSWORD`.
5. **Ejecutar** con «Reiniciar y ejecutar todas las celdas».
6. **Comprobar** que la última línea de la Celda 12 dice `cuadra · avisos: 0 · sin clasificar: 0,00 €`.
7. **Power BI:** abrir `power_bi/bi_inmobiliario.pbit`, conectar a la base y actualizar. Algunos filtros de visuales usan nombres genéricos (`Promoción A`, `Promoción B`…): hay que cambiarlos por los de tus promociones e inmuebles. El modelo y las medidas están documentados en `power_bi/modelo_y_medidas.md`.

## Limitaciones conocidas

- **La calidad del dato manda.** Hay cosas que el sistema no puede arreglar si el dato de origen está mal introducido, y se corrigen en el programa de facturación, no en el código:
  - Dos contratos de una misma vivienda con un día de diferencia en la fecha de inicio salen como grupos distintos.
  - Las fechas de revisión de un contrato (aniversario del inicio) solo coinciden con su vencimiento si las fechas de inicio y fin están bien introducidas.
- **Identidad de un contrato.** Si se corrige en el origen el cliente, el artículo o la fecha de inicio, el notebook elimina el contrato antiguo y carga el nuevo. Si faltan más de 20 de golpe, se detiene sin borrar nada (`MAX_CONTRATOS_A_BORRAR`).
- **Facturas sin recibo.** Las facturas que no tienen ningún recibo en FacturaPlus aparecen como «Sin recibo, no evaluable»: no se pueden dar por cobradas ni por pendientes sin revisarlas.

## Autor y licencia

Albert Andrés Palop · [github.com/alandpal](https://github.com/alandpal)

Todos los derechos reservados. Ver [`LICENSE`](LICENSE).
