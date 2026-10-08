# Modelo de Power BI: tablas, relaciones y medidas

Documento generado a partir de la plantilla del informe. Todo el texto es del modelo (nombres de tablas, columnas y fórmulas DAX); no contiene datos.

- Nivel de compatibilidad del modelo: 1606 · modo de las tablas: Importar · origen: PostgreSQL local (`localhost`, base `bi_inmobiliario`).

## 1 · Tablas

| Tabla | Origen | Columnas |
|---|---|---|
| `clientes` | consulta Power Query (PostgreSQL) | `id_cliente`, `ccodcli`, `nombre_completo`, `telefono1`, `telefono2`, `nif`, `email`, `tipo_documento`, `fecha_carga`, `fecha_actualiz` |
| `contratos` | consulta Power Query (PostgreSQL) | `id_contrato`, `id_cliente`, `id_inmueble`, `precio`, `fecha_inicio`, `fecha_fin`, `fecha_carga`, `cref`, `cprop`, `fecha_actualiz`, `id_grupo_contrato`, `Inquilinos del Grupo`*, `Promocion del Grupo`*, `Inmuebles del Grupo`* |
| `facturacion_clientes` | consulta Power Query (PostgreSQL) | `id_linea`, `documento`, `fecha`, `id_cliente`, `id_inmueble`, `importe_linea`, `fecha_carga`, `tipo_operacion` |
| `facturacion_proveedores` | consulta Power Query (PostgreSQL) | `id_linea`, `documento`, `numero_factura_proveedor`, `fecha`, `id_proveedor`, `id_inmueble`, `importe_linea`, `fecha_carga`, `tipo_operacion` |
| `inmuebles` | consulta Power Query (PostgreSQL) | `id_inmueble`, `promocion`, `tipo`, `descripcion`, `planta`, `puerta`, `num_dormitorios`, `num_banos`, `referencia_catastral`, `notas`, `fecha_actualiz`, `superficie_construida`, `terraza_patio_interior`, `superficie_terraza_patio_interior`, `finca_registral`, `direccion`, `municipio`, `codigo_postal`, `estado_especial`, `coste_adquisicion`, `fecha_adquisicion` |
| `proveedores` | consulta Power Query (PostgreSQL) | `id_proveedor`, `ccodpro`, `nombre_completo`, `telefono1`, `telefono2`, `nif`, `email`, `fecha_carga`, `fecha_actualiz` |
| `Calendario` | tabla calculada (DAX) | `Date`, `Año`, `Mes`, `Trimestre`, `Número de trimestre`, `Número de mes`, `Día` |
| `Medidas` | tabla calculada (DAX) | `Provisional` |
| `estado_cobro_clientes` | consulta Power Query (PostgreSQL) | `documento`, `id_cliente`, `fecha_factura`, `importe_total_con_iva`, `importe_cobrado`, `pendiente`, `fecha_cobro_completo`, `dias_hasta_cobro_completo`, `estado` |
| `estado_pago_proveedores` | consulta Power Query (PostgreSQL) | `documento`, `id_proveedor`, `fecha_factura`, `importe_total_con_iva`, `importe_pagado`, `pendiente`, `fecha_pago_completo`, `dias_hasta_pago_completo`, `estado` |
| `cobros_clientes` | consulta Power Query (PostgreSQL) | `documento`, `fecha_cobro`, `importe_cobro` |
| `pagos_proveedores` | consulta Power Query (PostgreSQL) | `documento`, `fecha_pago`, `importe_pago` |

`*` = columna calculada (DAX). La tabla `Medidas` solo contiene medidas; `Calendario` es la tabla de fechas.

## 2 · Relaciones

| Desde (muchos) | Hacia (uno) | Sentido del filtro | Activa |
|---|---|---|---|
| `contratos[id_cliente]` | `clientes[id_cliente]` | un sentido | sí |
| `contratos[id_inmueble]` | `inmuebles[id_inmueble]` | un sentido | sí |
| `facturacion_clientes[id_cliente]` | `clientes[id_cliente]` | un sentido | sí |
| `facturacion_clientes[id_inmueble]` | `inmuebles[id_inmueble]` | un sentido | sí |
| `facturacion_proveedores[id_inmueble]` | `inmuebles[id_inmueble]` | un sentido | sí |
| `facturacion_proveedores[id_proveedor]` | `proveedores[id_proveedor]` | un sentido | sí |
| `facturacion_clientes[fecha]` | `Calendario[Date]` | un sentido | sí |
| `facturacion_proveedores[fecha]` | `Calendario[Date]` | un sentido | sí |
| `contratos[fecha_inicio]` | `Calendario[Date]` | un sentido | sí |
| `estado_cobro_clientes[id_cliente]` | `clientes[id_cliente]` | un sentido | sí |
| `estado_pago_proveedores[id_proveedor]` | `proveedores[id_proveedor]` | un sentido | sí |
| `cobros_clientes[documento]` | `estado_cobro_clientes[documento]` | un sentido | sí |
| `pagos_proveedores[documento]` | `estado_pago_proveedores[documento]` | un sentido | sí |

Ninguna relación filtra en los dos sentidos: donde hace falta que una tabla filtre a otra en sentido contrario, se hace dentro de la fórmula con `CROSSFILTER` (ver columnas calculadas). Las tablas de cobros y pagos no se relacionan con el calendario: las medidas de deuda lo resuelven con `REMOVEFILTERS(Calendario)` y filtros sobre la columna de fecha.

## 3 · Tabla de fechas y columnas calculadas

### `contratos[Inquilinos del Grupo]`
```dax

IF(
    ISBLANK(contratos[id_grupo_contrato]),
    BLANK(),
    CALCULATE(
        CONCATENATEX(VALUES(clientes[nombre_completo]), clientes[nombre_completo], " y "),
        ALLEXCEPT(contratos, contratos[id_grupo_contrato]),
        CROSSFILTER(clientes[id_cliente], contratos[id_cliente], BOTH)
    )
)
```

### `contratos[Promocion del Grupo]`
```dax

IF(
    ISBLANK(contratos[id_grupo_contrato]),
    BLANK(),
    CALCULATE(
        CONCATENATEX(VALUES(inmuebles[promocion]), inmuebles[promocion], ", "),
        ALLEXCEPT(contratos, contratos[id_grupo_contrato]),
        CROSSFILTER(inmuebles[id_inmueble], contratos[id_inmueble], BOTH)
    )
)
```

### `contratos[Inmuebles del Grupo]`
```dax

IF(
    ISBLANK(contratos[id_grupo_contrato]),
    BLANK(),
    CALCULATE(
        CONCATENATEX(
            SUMMARIZE(inmuebles, inmuebles[descripcion], inmuebles[tipo]),
            inmuebles[descripcion],
            " + ",
            SWITCH(
                TRUE(),
                inmuebles[tipo] = "Vivienda", 0,
                inmuebles[tipo] = "Garaje", 1,
                inmuebles[tipo] = "Trastero", 2,
                99
            ),
            ASC
        ),
        ALLEXCEPT(contratos, contratos[id_grupo_contrato]),
        CROSSFILTER(inmuebles[id_inmueble], contratos[id_inmueble], BOTH)
    )
)
```

### `Calendario` (tabla calculada)
```dax

ADDCOLUMNS(
    CALENDARAUTO(),
    "Año", YEAR([Date]),
    "Número de trimestre", QUARTER([Date]),
    "Trimestre", "T" & QUARTER([Date]),
    "Número de mes", MONTH([Date]),
    "Mes", FORMAT([Date], "MMMM"),
    "Día", DAY([Date])
)
```

## 4 · Medidas

Se listan con su fórmula y su formato. Un formato «dinámico» es una expresión DAX que decide el formato según el contexto (se usa para añadir un aviso ⚠ al número).

### Cliente Activo (medida)
```dax

VAR TieneContratoActivo =
    CALCULATE(
        COUNTROWS(contratos),
        contratos[fecha_inicio] <= TODAY(),
        OR(ISBLANK(contratos[fecha_fin]), contratos[fecha_fin] >= TODAY())
    ) > 0
RETURN
IF(TieneContratoActivo, 1, 0)
```
Formato: `0`

### Cobrado acumulado
```dax

VAR FechaCorte = MAX(Calendario[Date])
RETURN
    CALCULATE(
        SUM(cobros_clientes[importe_cobro]),
        REMOVEFILTERS(Calendario),
        cobros_clientes[fecha_cobro] <= FechaCorte,
        estado_cobro_clientes[fecha_factura] <= FechaCorte,
        estado_cobro_clientes[estado] <> "Sin recibo, no evaluable"
    )
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Contratos que Vencen 30 dias
```dax

COUNTROWS(
    FILTER(
        VALUES(contratos[id_grupo_contrato]),
        VAR FinGrupo = CALCULATE(MAX(contratos[fecha_fin]), contratos[fecha_fin] >= TODAY())
        RETURN NOT ISBLANK(contratos[id_grupo_contrato]) && NOT ISBLANK(FinGrupo) && FinGrupo <= TODAY() + 30
    )
)
```
Formato: `0`

### Contratos que Vencen entre 31 y 60 días
```dax

COUNTROWS(
    FILTER(
        VALUES(contratos[id_grupo_contrato]),
        VAR FinGrupo = CALCULATE(MAX(contratos[fecha_fin]), contratos[fecha_fin] >= TODAY())
        RETURN NOT ISBLANK(contratos[id_grupo_contrato]) && NOT ISBLANK(FinGrupo) && FinGrupo > TODAY() + 30 && FinGrupo <= TODAY() + 60
    )
)
```
Formato: `0`

### Coste de adquisicion
```dax
SUM(inmuebles[coste_adquisicion])
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda 0-30 días
```dax

CALCULATE(
    SUM(estado_cobro_clientes[pendiente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"},
    FILTER(estado_cobro_clientes, DATEDIFF(estado_cobro_clientes[fecha_factura], TODAY(), DAY) <= 30)
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda 31-60 días
```dax

CALCULATE(
    SUM(estado_cobro_clientes[pendiente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"},
    FILTER(
        estado_cobro_clientes,
        VAR Dias = DATEDIFF(estado_cobro_clientes[fecha_factura], TODAY(), DAY)
        RETURN Dias > 30 && Dias <= 60
    )
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda 61-90 días
```dax

CALCULATE(
    SUM(estado_cobro_clientes[pendiente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"},
    FILTER(
        estado_cobro_clientes,
        VAR Dias = DATEDIFF(estado_cobro_clientes[fecha_factura], TODAY(), DAY)
        RETURN Dias > 60 && Dias <= 90
    )
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda a fecha
```dax

IF(
    MIN(Calendario[Date]) > TODAY(),
    BLANK(),
    [Facturado acumulado] - [Cobrado acumulado]
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda Más de 90 días
```dax

CALCULATE(
    SUM(estado_cobro_clientes[pendiente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"},
    FILTER(
        estado_cobro_clientes,
        DATEDIFF(estado_cobro_clientes[fecha_factura], TODAY(), DAY) > 90
    )
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Deuda Total Clientes Activos
```dax

VAR ClientesActivos =
    SELECTCOLUMNS(
        FILTER(
            contratos,
            contratos[fecha_inicio] <= TODAY() &&
            (ISBLANK(contratos[fecha_fin]) || contratos[fecha_fin] >= TODAY())
        ),
        "id_cliente", contratos[id_cliente]
    )
RETURN
CALCULATE(
    SUM(estado_cobro_clientes[pendiente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"},
    estado_cobro_clientes[id_cliente] IN ClientesActivos
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Dias Hasta Revision
```dax

VAR ProximaRevision = [Proxima Fecha Revision]
RETURN
    IF(
        ISBLANK(ProximaRevision),
        BLANK(),
        VAR Dias = DATEDIFF(TODAY(), ProximaRevision, DAY)
        RETURN IF(Dias >= 0, Dias, BLANK())
    )
```
Formato: `0`

### Dias Hasta Vencimiento
```dax

VAR FechaVencimiento = [Fecha de vencimiento]
RETURN
    IF(ISBLANK(FechaVencimiento), BLANK(), DATEDIFF(TODAY(), FechaVencimiento, DAY))
```
Formato: `0`

### Días medio de cobro (activos, con pendientes)
```dax

VAR ClientesActivos =
    SELECTCOLUMNS(
        FILTER(
            contratos,
            contratos[fecha_inicio] <= TODAY()
                && (ISBLANK(contratos[fecha_fin]) || contratos[fecha_fin] >= TODAY())
        ),
        "id_cliente", contratos[id_cliente]
    )
RETURN
AVERAGEX(
    FILTER(
        estado_cobro_clientes,
        estado_cobro_clientes[importe_total_con_iva] >= 0
            && estado_cobro_clientes[id_cliente] IN ClientesActivos
    ),
    IF(
        NOT(ISBLANK(estado_cobro_clientes[dias_hasta_cobro_completo])),
        estado_cobro_clientes[dias_hasta_cobro_completo],
        DATEDIFF(estado_cobro_clientes[fecha_factura], TODAY(), DAY)
    )
)
```

### Facturado acumulado
```dax

VAR FechaCorte = MAX(Calendario[Date])
RETURN
    CALCULATE(
        SUM(estado_cobro_clientes[importe_total_con_iva]),
        REMOVEFILTERS(Calendario),
        estado_cobro_clientes[fecha_factura] <= FechaCorte,
        estado_cobro_clientes[estado] <> "Sin recibo, no evaluable"
    )
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Fecha de vencimiento
```dax

CALCULATE(MAX(contratos[fecha_fin]), contratos[fecha_fin] >= TODAY())
```
Formato: `Short Date`

### Gasto Explotacion
```dax

CALCULATE(SUM(facturacion_proveedores[importe_linea]), facturacion_proveedores[tipo_operacion] = "GASTOS_EXPLOTACION")
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Gasto Mantenimiento
```dax

CALCULATE(SUM(facturacion_proveedores[importe_linea]), facturacion_proveedores[tipo_operacion] = "GASTOS_MANTENIMIENTO")
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Gastos de estructura
```dax
CALCULATE(SUM(facturacion_proveedores[importe_linea]), facturacion_proveedores[tipo_operacion] = "GASTOS_ESTRUCTURA")
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Gastos netos
```dax
[Gasto Explotacion] + [Gasto Mantenimiento] + [Impuestos y tasas] - [Gastos repercutidos a clientes]
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Gastos Netos Promedio
```dax

VAR FechaAdquisicion = MIN(inmuebles[fecha_adquisicion])
VAR Fin = [Última fecha de datos]
VAR FechaInicioVentana = MAX(FechaAdquisicion, EDATE(Fin, -72))
VAR Anios = DIVIDE(DATEDIFF(FechaInicioVentana, Fin, DAY), 365.25)
VAR GastosTotales =
    CALCULATE(
        [Gastos netos],
        REMOVEFILTERS(Calendario),
        facturacion_proveedores[fecha] > FechaInicioVentana,
        facturacion_clientes[fecha] > FechaInicioVentana
    )
RETURN
    DIVIDE(GastosTotales, Anios)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Gastos repercutidos a clientes
```dax
CALCULATE(
    SUM(facturacion_clientes[importe_linea]),
    facturacion_clientes[tipo_operacion] IN {"GASTOS_EXPLOTACION", "GASTOS_MANTENIMIENTO", "IMPUESTOS_TASAS"}
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Impuestos y tasas
```dax
CALCULATE(
    SUM(facturacion_proveedores[importe_linea]),
    facturacion_proveedores[tipo_operacion] = "IMPUESTOS_TASAS"
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso Alquiler
```dax

CALCULATE(SUM(facturacion_clientes[importe_linea]), facturacion_clientes[tipo_operacion] = "ALQUILER")
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso Alquiler Mes Actual
```dax

CALCULATE(
    [Ingreso Alquiler],
    YEAR(Calendario[Date]) = YEAR(TODAY()),
    MONTH(Calendario[Date]) = MONTH(TODAY())
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso Alquiler Mismo Mes Año Anterior
```dax

CALCULATE(
    [Ingreso Alquiler],
    YEAR(Calendario[Date]) = YEAR(TODAY()) - 1,
    MONTH(Calendario[Date]) = MONTH(TODAY())
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso Alquiler Último Año
```dax

VAR Fin = [Última fecha de datos]
VAR Inicio = Fin - 365
RETURN
    CALCULATE(
        [Ingreso Alquiler],
        REMOVEFILTERS(Calendario),
        facturacion_clientes[fecha] > Inicio,
        facturacion_clientes[fecha] <= Fin
    )
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso operativo neto (NOI)
```dax
[Ingreso Alquiler] - [Gastos netos]
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Ingreso por m²
```dax
DIVIDE(
    [Ingreso Alquiler Último Año],
    SUM(inmuebles[superficie_construida])
)
```

### Inmuebles Alquilados
```dax

VAR Hoy = TODAY()
VAR InmueblesValidos =
    FILTER(
        inmuebles,
        ((inmuebles[estado_especial] <> "Uso propio" && inmuebles[estado_especial] <> "Vendido")
            || ISBLANK(inmuebles[estado_especial]))
            && inmuebles[tipo] <> "Solar"
    )
RETURN
    CALCULATE(
        DISTINCTCOUNT(contratos[id_inmueble]),
        FILTER(
            contratos,
            contratos[fecha_inicio] <= Hoy
                && (contratos[fecha_fin] >= Hoy || ISBLANK(contratos[fecha_fin]))
        ),
        InmueblesValidos
    )
```
Formato: `0`

### Inmuebles en cartera
```dax

CALCULATE(
    DISTINCTCOUNT(inmuebles[id_inmueble]),
    inmuebles[estado_especial] <> "Vendido" || ISBLANK(inmuebles[estado_especial])
)
```
Formato: `0`

### Inmuebles Vacios
```dax
[Total Inmuebles Alquilables] - [Inmuebles Alquilados]
```
Formato: `0`

### Meses sin alquilar
```dax

SUMX(
    VALUES(inmuebles[id_inmueble]),
    VAR UltimoFin = CALCULATE(MAX(contratos[fecha_fin]), contratos[fecha_fin] < TODAY())
    VAR Desde = IF(ISBLANK(UltimoFin), CALCULATE(MIN(inmuebles[fecha_adquisicion])), UltimoFin)
    RETURN
        IF([Inmuebles Vacios] > 0 && NOT ISBLANK(Desde), DATEDIFF(Desde, TODAY(), MONTH))
)
```
Formato: `0`

### NOI Híbrido
```dax
[Ingreso Alquiler Último Año] - [Gastos Netos Promedio]
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Nº Clientes Morosos
```dax

CALCULATE(
    DISTINCTCOUNT(estado_cobro_clientes[id_cliente]),
    estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"}
)
```
Formato: `0`

### Nº Clientes Morosos (activos)
```dax

VAR ClientesMorosos =
    CALCULATETABLE(
        VALUES(estado_cobro_clientes[id_cliente]),
        estado_cobro_clientes[estado] IN {"Pendiente, sin cobros", "Parcialmente cobrada"}
    )
RETURN
COUNTROWS(
    FILTER(
        ClientesMorosos,
        VAR EsteCliente = estado_cobro_clientes[id_cliente]
        RETURN
            COUNTROWS(
                FILTER(
                    ALL(contratos),
                    contratos[id_cliente] = EsteCliente &&
                    contratos[fecha_inicio] <= TODAY() &&
                    (ISBLANK(contratos[fecha_fin]) || contratos[fecha_fin] >= TODAY())
                )
            ) > 0
    )
)
```
Formato: `0`

### Payback Años
```dax

VAR Hoy = TODAY()
VAR UltimaFecha = [Última fecha de datos]
VAR Base =
    ADDCOLUMNS(
        VALUES(inmuebles[id_inmueble]),
        "@Coste", [Coste de adquisicion],
        "@Noi", [NOI Híbrido],
        "@FechaAdq", CALCULATE(MIN(inmuebles[fecha_adquisicion])),
        "@Estado", CALCULATE(SELECTEDVALUE(inmuebles[estado_especial])),
        "@Recuperado",
            VAR FechaInicio = CALCULATE(MIN(inmuebles[fecha_adquisicion]))
            RETURN
                CALCULATE(
                    [Ingreso operativo neto (NOI)],
                    REMOVEFILTERS(Calendario),
                    DATESBETWEEN(Calendario[Date], FechaInicio, Hoy)
                ),
        "@Alquilado",
            CALCULATE(
                COUNTROWS(
                    FILTER(
                        contratos,
                        contratos[fecha_inicio] <= Hoy
                            && (ISBLANK(contratos[fecha_fin]) || contratos[fecha_fin] >= Hoy)
                    )
                )
            )
    )
VAR Evaluables =
    FILTER(
        Base,
        [@Estado] <> "Vendido"
            && [@Estado] <> "Uso propio"
            && [@Coste] > 0
            && NOT ISBLANK([@FechaAdq])
            && DATEDIFF([@FechaAdq], UltimaFecha, DAY) >= 365
    )
VAR HayAlquilados = COUNTROWS(FILTER(Evaluables, [@Alquilado] > 0)) > 0
VAR CosteTotal = SUMX(Evaluables, [@Coste])
VAR RecuperadoTotal = SUMX(Evaluables, [@Recuperado])
VAR NoiTotal = SUMX(Evaluables, [@Noi])
VAR Pendiente = CosteTotal - RecuperadoTotal
RETURN
    IF(
        COUNTROWS(Evaluables) = 0,
        BLANK(),
        IF(
            Pendiente <= 0,
            0,
            IF(HayAlquilados && NoiTotal > 0, DIVIDE(Pendiente, NoiTotal))
        )
    )
```
Formato dinámico:
```dax
VAR Antiguos =
    COUNTROWS(
        FILTER(
            VALUES(inmuebles[id_inmueble]),
            VAR F = CALCULATE(MIN(inmuebles[fecha_adquisicion]))
            VAR E = CALCULATE(SELECTEDVALUE(inmuebles[estado_especial]))
            RETURN NOT ISBLANK(F) && F < DATE(2011, 1, 1) && E <> "Vendido" && E <> "Uso propio"
        )
    )
VAR Aviso = IF(Antiguos > 0, " ⚠", "")
RETURN
    IF(
        [Payback Años] = 0,
        """Amortizado" & Aviso & """",
        "0.0"" años" & Aviso & """"
    )
```

### Proxima Fecha Revision
```dax

VAR TieneInmueble = NOT ISBLANK(MIN(contratos[id_inmueble]))
VAR FechaInicioGrupo = MIN(contratos[fecha_inicio])
VAR FechaFinVigente = 
    CALCULATE(
        MAX(contratos[fecha_fin]),
        FILTER(contratos, contratos[fecha_fin] >= TODAY() || ISBLANK(contratos[fecha_fin]))
    )
VAR TieneContratoVigente = NOT ISBLANK(FechaFinVigente)
VAR AniosTranscurridos = INT(YEARFRAC(FechaInicioGrupo, TODAY(), 1) + 0.001)
VAR ProximoAniversario = EDATE(FechaInicioGrupo, (AniosTranscurridos + 1) * 12)
RETURN 
    IF(
        TieneInmueble && TieneContratoVigente && ProximoAniversario <= FechaFinVigente,
        ProximoAniversario,
        BLANK()
    )
```
Formato: `Short Date`

### Rentabilidad Bruta %
```dax

DIVIDE(
    [Ingreso Alquiler Último Año],
    SUM(inmuebles[coste_adquisicion])
)
```
Formato: `0.00\ %;-0.00\ %;0.00\ %`

### Rentabilidad Neta %
```dax

VAR Fin = [Última fecha de datos]
VAR Inicio = Fin - 365
VAR NOIUltimoAnio =
    CALCULATE(
        [Ingreso operativo neto (NOI)],
        REMOVEFILTERS(Calendario),
        facturacion_clientes[fecha] > Inicio,
        facturacion_clientes[fecha] <= Fin,
        facturacion_proveedores[fecha] > Inicio,
        facturacion_proveedores[fecha] <= Fin
    )
RETURN
    DIVIDE(NOIUltimoAnio, SUM(inmuebles[coste_adquisicion]))
```
Formato: `0.00\ %;-0.00\ %;0.00\ %`

### Rentabilidad Neta % (12 meses)
```dax

VAR UltimaFecha = [Última fecha de datos]
VAR Fin = MIN(MAX(Calendario[Date]), UltimaFecha)
VAR Inicio = EDATE(Fin, -12)
VAR NOI12 =
    CALCULATE(
        [Ingreso operativo neto (NOI)],
        REMOVEFILTERS(Calendario),
        facturacion_clientes[fecha] > Inicio,
        facturacion_clientes[fecha] <= Fin,
        facturacion_proveedores[fecha] > Inicio,
        facturacion_proveedores[fecha] <= Fin
    )
VAR Coste =
    CALCULATE(
        SUM(inmuebles[coste_adquisicion]),
        FILTER(inmuebles, ISBLANK(inmuebles[fecha_adquisicion]) || inmuebles[fecha_adquisicion] <= Fin)
    )
RETURN
    IF(
        MIN(Calendario[Date]) > UltimaFecha || Inicio < DATE(2011, 1, 1),
        BLANK(),
        DIVIDE(NOI12, Coste)
    )
```
Formato: `0.00\ %;-0.00\ %;0.00\ %`

### ROI Acumulado %
```dax

VAR FechaInicio = MIN(inmuebles[fecha_adquisicion])
VAR NOIDesdeAdquisicion =
    CALCULATE(
        [Ingreso operativo neto (NOI)],
        REMOVEFILTERS(Calendario),
        DATESBETWEEN(Calendario[Date], FechaInicio, TODAY())
    )
RETURN
    IF(ISBLANK(FechaInicio), BLANK(), DIVIDE(NOIDesdeAdquisicion, SUM(inmuebles[coste_adquisicion]), 0))
```
Formato dinámico:
```dax
VAR Antiguos =
    COUNTROWS(
        FILTER(
            VALUES(inmuebles[id_inmueble]),
            VAR F = CALCULATE(MIN(inmuebles[fecha_adquisicion]))
            RETURN NOT ISBLANK(F) && F < DATE(2011, 1, 1)
        )
    )
RETURN
    IF(Antiguos > 0, "0.00\ %"" ⚠""", "0.00\ %")
```

### Tasa de Ocupacion
```dax
DIVIDE([Inmuebles Alquilados], [Total Inmuebles Alquilables])
```
Formato: `0.00\ %;-0.00\ %;0.00\ %`

### Total Inmuebles Alquilables
```dax

VAR InmueblesValidos =
    FILTER(
        inmuebles,
        ((inmuebles[estado_especial] <> "Uso propio" && inmuebles[estado_especial] <> "Vendido")
            || ISBLANK(inmuebles[estado_especial]))
            && inmuebles[tipo] <> "Solar"
    )
RETURN
    CALCULATE(DISTINCTCOUNT(inmuebles[id_inmueble]), InmueblesValidos)
```
Formato: `0`

### Total Pendiente (real)
```dax

CALCULATE(
    ROUND(SUM(estado_cobro_clientes[pendiente]), 2),
    estado_cobro_clientes[estado] <> "Sin recibo, no evaluable"
)
```
Formato: `#,0.00\ "€";-#,0.00\ "€";#,0.00\ "€"`

### Última fecha de datos
```dax
MAX(
    CALCULATE(MAX(facturacion_clientes[fecha]), ALL(facturacion_clientes)),
    CALCULATE(MAX(facturacion_proveedores[fecha]), ALL(facturacion_proveedores))
)
```
Formato: `General Date`

## 5 · Consultas de Power Query

### `clientes`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "clientes"]}[Data]
in
  #"Navegación 1"
```

### `contratos`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "contratos"]}[Data]
in
  #"Navegación 1"
```

### `facturacion_clientes`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "facturacion_clientes"]}[Data]
in
  #"Navegación 1"
```

### `facturacion_proveedores`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "facturacion_proveedores"]}[Data]
in
  #"Navegación 1"
```

### `inmuebles`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "inmuebles"]}[Data]
in
  #"Navegación 1"
```

### `proveedores`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "proveedores"]}[Data]
in
  #"Navegación 1"
```

### `estado_cobro_clientes`
```m
let
    Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
    public_estado_cobro_clientes = Origen{[Schema="public",Item="estado_cobro_clientes"]}[Data]
in
    public_estado_cobro_clientes
```

### `estado_pago_proveedores`
```m
let
    Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
    public_estado_pago_proveedores = Origen{[Schema="public",Item="estado_pago_proveedores"]}[Data]
in
    public_estado_pago_proveedores
```

### `cobros_clientes`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "cobros_clientes"]}[Data],
    #"Columnas quitadas" = Table.RemoveColumns(#"Navegación 1",{"id_cobro", "numero_cuota", "fecha_carga", "public.facturas_totales_clientes"})
in
  #"Columnas quitadas"
```

### `pagos_proveedores`
```m
let
  Origen = PostgreSQL.Database("localhost", "bi_inmobiliario"),
  #"Navegación 1" = Origen{[Schema = "public", Item = "pagos_proveedores"]}[Data],
    #"Columnas quitadas" = Table.RemoveColumns(#"Navegación 1",{"id_pago", "numero_cuota", "fecha_carga", "public.facturas_totales_proveedores"})
in
  #"Columnas quitadas"
```

## 6 · Páginas del informe y visuales

Solo se documentan el tipo de visual y los campos que usa; los valores de los filtros no se incluyen.

### Página «Inicio (portada)»

- **pageNavigator**

### Página «Situación patrimonial»

- **cardVisual**: [Tasa de Ocupacion]
- **cardVisual**: [Inmuebles Alquilados]
- **cardVisual**: [Inmuebles Vacios]
- **cardVisual**: [Total Inmuebles Alquilables]
- **barChart** «Inmuebles en cartera por tipo de inmueble»: inmuebles[tipo], [Inmuebles en cartera]
- **pivotTable** «Inmuebles vacios»: inmuebles[promocion], [Inmuebles Vacios], inmuebles[tipo], inmuebles[puerta], [Meses sin alquilar]
- **hundredPercentStackedBarChart** «Ocupación por tipo de inmueble»: inmuebles[tipo], [Inmuebles Alquilados], [Inmuebles Vacios]

### Página «Rentabilidad general»

- **pivotTable**: inmuebles[promocion], inmuebles[descripcion], [Ingreso Alquiler], [Ingreso operativo neto (NOI)], [Rentabilidad Bruta %], [Rentabilidad Neta %], [ROI Acumulado %], [Payback Años], [Coste de adquisicion]
- **barChart** «Rentabilidad neta por inmueble»: inmuebles[descripcion], [Rentabilidad Neta %]
- **barChart**: [Ingreso por m²], inmuebles[descripcion]
- **slicer**: inmuebles[tipo]

### Página «Rentabilidad general II»

- **lineChart**: Calendario[Año], [Rentabilidad Neta % (12 meses)], inmuebles[promocion]

### Página «Contratos»

- **tableEx**: contratos[id_grupo_contrato], [Dias Hasta Revision], [Proxima Fecha Revision], [Fecha de vencimiento], [Dias Hasta Vencimiento], contratos[Inquilinos del Grupo]
- **cardVisual**: [Contratos que Vencen 30 dias], [Contratos que Vencen entre 31 y 60 días]

### Página «Deudas»

- **tableEx** «Deuda por cliente»: clientes[nombre_completo], [Total Pendiente (real)]
- **cardVisual** «Deuda total»: [Total Pendiente (real)]
- **cardVisual**: [Nº Clientes Morosos]
- **cardVisual**: [Nº Clientes Morosos (activos)]
- **cardVisual**: [Deuda Total Clientes Activos]
- **donutChart** «Deuda por antigüedad de la factura»: [Deuda 0-30 días], [Deuda 31-60 días], [Deuda 61-90 días], [Deuda Más de 90 días]
- **lineChart**: [Deuda a fecha], None[Año], None[Mes]

### Página «Morosidad clientes activos»

- **tableEx** «Media de dias hasta el cobro de la factura desde su emisión»: clientes[nombre_completo], [Días medio de cobro (activos, con pendientes)]
- **tableEx** «Facturas pendientes de cobro a clientes vigentes»: estado_cobro_clientes[documento], estado_cobro_clientes[fecha_factura], estado_cobro_clientes[importe_total_con_iva], estado_cobro_clientes[importe_cobrado], estado_cobro_clientes[pendiente], clientes[nombre_completo]

### Página «Fras. pendientes de cobro»

- **tableEx** «Facturas pendientes de clientes»: clientes[nombre_completo], estado_cobro_clientes[documento], estado_cobro_clientes[fecha_factura], estado_cobro_clientes[pendiente], estado_cobro_clientes[importe_total_con_iva], estado_cobro_clientes[importe_cobrado]
