-- ============================================================
-- ESQUEMA COMPLETO — BI inmobiliario
-- Base de datos PostgreSQL del proyecto (la crea y mantiene el notebook).
-- Orden: tablas sin dependencias primero, vistas al final.
-- ============================================================

-- ─── Tablas base, sin dependencias ───────────────────────────

CREATE TABLE clientes (
    id_cliente        SERIAL PRIMARY KEY,
    ccodcli           VARCHAR NOT NULL UNIQUE,
    nombre_completo   VARCHAR,
    telefono1         VARCHAR,
    telefono2         VARCHAR,
    nif               VARCHAR,
    email             VARCHAR,
    tipo_documento    VARCHAR,
    fecha_carga       TIMESTAMP NOT NULL DEFAULT now(),
    fecha_actualiz    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE proveedores (
    id_proveedor      SERIAL PRIMARY KEY,
    ccodpro           VARCHAR NOT NULL UNIQUE,
    nombre_completo   VARCHAR,
    telefono1         VARCHAR,
    telefono2         VARCHAR,
    nif               VARCHAR,
    email             VARCHAR,
    fecha_carga       TIMESTAMP NOT NULL DEFAULT now(),
    fecha_actualiz    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE inmuebles (
    id_inmueble                        VARCHAR PRIMARY KEY,
    promocion                          VARCHAR,
    tipo                               VARCHAR,
    descripcion                        VARCHAR,
    planta                             VARCHAR,
    puerta                             VARCHAR,
    superficie_construida              NUMERIC,
    num_dormitorios                    SMALLINT,
    num_banos                          SMALLINT,
    terraza_patio_interior             SMALLINT,
    superficie_terraza_patio_interior  NUMERIC,
    finca_registral                    VARCHAR,
    referencia_catastral               VARCHAR,
    direccion                          VARCHAR,
    municipio                          VARCHAR,
    codigo_postal                      VARCHAR,
    estado_especial                    VARCHAR,
    notas                              TEXT,
    fecha_actualiz                     TIMESTAMP NOT NULL DEFAULT now(),
    coste_adquisicion                  NUMERIC,
    fecha_adquisicion                  DATE
);

CREATE TABLE articulos_tipo_operacion (
    cref            VARCHAR PRIMARY KEY,
    tipo_operacion  VARCHAR NOT NULL,
    fecha_actualiz  TIMESTAMP NOT NULL DEFAULT now()
);

-- ─── Tablas con dependencias de primer nivel ────────────────

CREATE TABLE articulos_inmuebles (
    cref            VARCHAR NOT NULL,
    cprop           VARCHAR NOT NULL DEFAULT '',
    id_inmueble     VARCHAR REFERENCES inmuebles(id_inmueble),
    fecha_actualiz  TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (cref, cprop)
);

CREATE TABLE contratos (
    id_contrato        SERIAL PRIMARY KEY,
    id_cliente         INTEGER REFERENCES clientes(id_cliente),
    id_inmueble        VARCHAR REFERENCES inmuebles(id_inmueble),
    cref               VARCHAR,
    cprop              VARCHAR NOT NULL DEFAULT '',
    precio             NUMERIC,
    fecha_inicio       DATE,
    fecha_fin          DATE,
    fecha_carga        TIMESTAMP NOT NULL DEFAULT now(),
    fecha_actualiz     TIMESTAMP NOT NULL DEFAULT now(),
    id_grupo_contrato  VARCHAR
);

CREATE TABLE facturacion_clientes (
    id_linea        SERIAL PRIMARY KEY,
    documento       VARCHAR NOT NULL,
    fecha           DATE,
    id_cliente      INTEGER REFERENCES clientes(id_cliente),
    id_inmueble     VARCHAR REFERENCES inmuebles(id_inmueble),
    tipo_operacion  VARCHAR,
    importe_linea   NUMERIC,
    fecha_carga     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE facturacion_proveedores (
    id_linea                  SERIAL PRIMARY KEY,
    documento                 VARCHAR NOT NULL,
    numero_factura_proveedor  VARCHAR,
    fecha                     DATE,
    id_proveedor              INTEGER REFERENCES proveedores(id_proveedor),
    id_inmueble               VARCHAR REFERENCES inmuebles(id_inmueble),
    tipo_operacion            VARCHAR,
    importe_linea             NUMERIC,
    fecha_carga               TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE facturas_totales_clientes (
    documento               VARCHAR PRIMARY KEY,
    importe_total_con_iva   NUMERIC,
    fecha_factura           DATE,
    documento_original      VARCHAR REFERENCES facturas_totales_clientes(documento),
    fecha_carga             TIMESTAMP NOT NULL DEFAULT now(),
    tiene_recibo            BOOLEAN
);

CREATE TABLE facturas_totales_proveedores (
    documento               VARCHAR PRIMARY KEY,
    importe_total_con_iva   NUMERIC,
    fecha_factura           DATE,
    documento_original      VARCHAR REFERENCES facturas_totales_proveedores(documento),
    fecha_carga             TIMESTAMP NOT NULL DEFAULT now(),
    tiene_recibo            BOOLEAN
);

-- ─── Tablas de segundo nivel ─────────────────────────────────

CREATE TABLE cobros_clientes (
    id_cobro        SERIAL PRIMARY KEY,
    documento       VARCHAR REFERENCES facturas_totales_clientes(documento),
    numero_cuota    INTEGER,
    fecha_cobro     DATE,
    importe_cobro   NUMERIC,
    fecha_carga     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE pagos_proveedores (
    id_pago         SERIAL PRIMARY KEY,
    documento       VARCHAR REFERENCES facturas_totales_proveedores(documento),
    numero_cuota    INTEGER,
    fecha_pago      DATE,
    importe_pago    NUMERIC,
    fecha_carga     TIMESTAMP NOT NULL DEFAULT now()
);

-- ============================================================
-- VISTAS
-- ============================================================

CREATE VIEW inmuebles_estado AS
SELECT
    id_inmueble, promocion, tipo, descripcion, planta, puerta,
    superficie_construida, num_dormitorios, num_banos,
    terraza_patio_interior, superficie_terraza_patio_interior,
    finca_registral, referencia_catastral, direccion, municipio,
    codigo_postal, estado_especial, notas, fecha_actualiz,
    CASE
        WHEN estado_especial IN ('Vendido', 'Uso propio') THEN estado_especial
        WHEN EXISTS (
            SELECT 1 FROM contratos c
            WHERE c.id_inmueble = i.id_inmueble
              AND (c.fecha_fin >= CURRENT_DATE OR c.fecha_fin IS NULL)
        ) THEN 'Alquilado'
        ELSE 'Vacío'
    END AS estado_actual
FROM inmuebles i;

CREATE VIEW estado_cobro_clientes AS
WITH cabecera_documento AS (
    SELECT documento, MIN(id_cliente) AS id_cliente, MIN(fecha) AS fecha_factura
    FROM facturacion_clientes
    GROUP BY documento
)
SELECT
    ft.documento,
    cd.id_cliente,
    COALESCE(ft.fecha_factura, cd.fecha_factura) AS fecha_factura,
    ft.importe_total_con_iva,
    COALESCE(SUM(c.importe_cobro), 0) AS importe_cobrado,
    ft.importe_total_con_iva - COALESCE(SUM(c.importe_cobro), 0) AS pendiente,
    MAX(c.fecha_cobro) FILTER (WHERE (ft.importe_total_con_iva - (
        SELECT SUM(c2.importe_cobro) FROM cobros_clientes c2
        WHERE c2.documento = ft.documento AND c2.fecha_cobro <= c.fecha_cobro
    )) <= 0.01) AS fecha_cobro_completo,
    MAX(c.fecha_cobro) FILTER (WHERE (ft.importe_total_con_iva - (
        SELECT SUM(c2.importe_cobro) FROM cobros_clientes c2
        WHERE c2.documento = ft.documento AND c2.fecha_cobro <= c.fecha_cobro
    )) <= 0.01) - COALESCE(ft.fecha_factura, cd.fecha_factura) AS dias_hasta_cobro_completo,
    CASE
        WHEN ft.importe_total_con_iva >= 0 AND abs(ft.importe_total_con_iva - COALESCE(SUM(c.importe_cobro), 0)) <= 0.01 THEN 'Cobrada'
        WHEN ft.importe_total_con_iva >= 0 AND NOT ft.tiene_recibo THEN 'Sin recibo, no evaluable'
        WHEN ft.importe_total_con_iva >= 0 AND COALESCE(SUM(c.importe_cobro), 0) = 0 THEN 'Pendiente, sin cobros'
        WHEN ft.importe_total_con_iva >= 0 THEN 'Parcialmente cobrada'
        WHEN abs(ft.importe_total_con_iva - COALESCE(SUM(c.importe_cobro), 0)) <= 0.01 THEN 'Saldada'
        WHEN NOT ft.tiene_recibo THEN 'Sin recibo, no evaluable'
        WHEN COALESCE(SUM(c.importe_cobro), 0) = 0 THEN 'Pendiente'
        ELSE 'Parcialmente saldada'
    END AS estado
FROM facturas_totales_clientes ft
LEFT JOIN cabecera_documento cd ON ft.documento = cd.documento
LEFT JOIN cobros_clientes c ON ft.documento = c.documento
GROUP BY ft.documento, cd.id_cliente, ft.fecha_factura, cd.fecha_factura, ft.importe_total_con_iva, ft.tiene_recibo;

CREATE VIEW estado_pago_proveedores AS
WITH cabecera_documento AS (
    SELECT documento, MIN(id_proveedor) AS id_proveedor, MIN(fecha) AS fecha_factura
    FROM facturacion_proveedores
    GROUP BY documento
)
SELECT
    ft.documento,
    cd.id_proveedor,
    COALESCE(ft.fecha_factura, cd.fecha_factura) AS fecha_factura,
    ft.importe_total_con_iva,
    COALESCE(SUM(p.importe_pago), 0) AS importe_pagado,
    ft.importe_total_con_iva - COALESCE(SUM(p.importe_pago), 0) AS pendiente,
    MAX(p.fecha_pago) FILTER (WHERE (ft.importe_total_con_iva - (
        SELECT SUM(p2.importe_pago) FROM pagos_proveedores p2
        WHERE p2.documento = ft.documento AND p2.fecha_pago <= p.fecha_pago
    )) <= 0.01) AS fecha_pago_completo,
    MAX(p.fecha_pago) FILTER (WHERE (ft.importe_total_con_iva - (
        SELECT SUM(p2.importe_pago) FROM pagos_proveedores p2
        WHERE p2.documento = ft.documento AND p2.fecha_pago <= p.fecha_pago
    )) <= 0.01) - COALESCE(ft.fecha_factura, cd.fecha_factura) AS dias_hasta_pago_completo,
    CASE
        WHEN ft.importe_total_con_iva >= 0 AND abs(ft.importe_total_con_iva - COALESCE(SUM(p.importe_pago), 0)) <= 0.01 THEN 'Pagada'
        WHEN ft.importe_total_con_iva >= 0 AND NOT ft.tiene_recibo THEN 'Sin recibo, no evaluable'
        WHEN ft.importe_total_con_iva >= 0 AND COALESCE(SUM(p.importe_pago), 0) = 0 THEN 'Pendiente, sin pagos'
        WHEN ft.importe_total_con_iva >= 0 THEN 'Parcialmente pagada'
        WHEN abs(ft.importe_total_con_iva - COALESCE(SUM(p.importe_pago), 0)) <= 0.01 THEN 'Saldada'
        WHEN NOT ft.tiene_recibo THEN 'Sin recibo, no evaluable'
        WHEN COALESCE(SUM(p.importe_pago), 0) = 0 THEN 'Pendiente'
        ELSE 'Parcialmente saldada'
    END AS estado
FROM facturas_totales_proveedores ft
LEFT JOIN cabecera_documento cd ON ft.documento = cd.documento
LEFT JOIN pagos_proveedores p ON ft.documento = p.documento
GROUP BY ft.documento, cd.id_proveedor, ft.fecha_factura, cd.fecha_factura, ft.importe_total_con_iva, ft.tiene_recibo;
