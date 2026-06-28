-- =====================================================================
-- SCRIPT DE MIGRACIÓN: V1_003__schema_operations.sql
-- MÓDULO: OPERACIONES (CONTROL DE STOCK, LOTES Y TRAZABILIDAD KARDEX)
-- ESTADO: DEFINITIVO / CONGELADO PARA PRODUCCIÓN (REVISIÓN POST-AUDITORÍA)
-- =====================================================================

PRINT 'Iniciando creación/actualización del esquema de Operaciones...';
GO

-- ---------------------------------------------------------------------
-- 1. ENTIDAD: LOTE (Control transaccional y trazabilidad de inventario)
-- ---------------------------------------------------------------------
PRINT 'Creando tabla Operaciones.Lote...';
GO

CREATE TABLE [Operaciones].[Lote] (
    [Id]                 BIGINT IDENTITY(1,1) NOT NULL,
    [TenantId]           INT                  NOT NULL,
    [ProductoId]         BIGINT               NOT NULL,
    [NumeroLote]         VARCHAR(50)          NULL,     -- NULL representa productos genéricos sin lote de fábrica
    
    -- OPTIMIZACIÓN DE ALMACENAMIENTO: Uso estricto de DATE (3 bytes) en lugar de DATETIME2 (8 bytes)
    [FechaFabricacion]   DATE                 NULL,
    [FechaVencimiento]   DATE                 NULL,     -- Crítico para lógica FIFO/FEFO en el ERP
    
    [CantidadInicial]    DECIMAL(18,4)        NOT NULL CONSTRAINT [CHK_Lote_CantidadInicial_Minima] CHECK ([CantidadInicial] >= 0),
    [CantidadDisponible] DECIMAL(18,4)        NOT NULL CONSTRAINT [CHK_Lote_CantidadDisponible_Minima] CHECK ([CantidadDisponible] >= 0),
    
    -- REFACTORIZACIÓN SEMÁNTICA: Nombre generalizado para ingresos por compras, ajustes, producción o inventario inicial
    [CostoAdquisicion]   DECIMAL(18,4)        NOT NULL CONSTRAINT [CHK_Lote_CostoAdquisicion_Minimo] CHECK ([CostoAdquisicion] >= 0),
    
    -- ESTADO SIMPLIFICADO: Control estándar de ciclo de vida del registro
    [Estado]             VARCHAR(20)          NOT NULL CONSTRAINT [DF_Lote_Estado] DEFAULT ('ACTIVO'),
    
    -- UBICACIÓN LOGÍSTICA SINTÉTICA (Ej: "A-03-02-15" -> Pasillo A, Rack 03, Nivel 02, Posición 15)
    [UbicacionFisica]    NVARCHAR(100)        NULL,
    
    [FechaRegistro]      DATETIME2            NOT NULL CONSTRAINT [DF_Lote_FechaRegistro] DEFAULT (SYSDATETIME()),
    
    -- CONTROL DE CONCURRENCIA OPTIMISTA: Requerido exclusivamente en Lote debido a las actualizaciones concurrentes de stock.
    [RowVersion]         ROWVERSION           NOT NULL,

    -- Clave Primaria declarada como NONCLUSTERED para habilitar ordenamiento físico óptimo vía CLUSTERED INDEX.
    CONSTRAINT [PK_Operaciones_Lote] PRIMARY KEY NONCLUSTERED ([Id]),

    -- Llaves Foráneas (Multi-inquilino estricto)
    CONSTRAINT [FK_Lote_Tenant] FOREIGN KEY ([TenantId]) 
        REFERENCES [Config].[Tenant] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT [FK_Lote_Producto] FOREIGN KEY ([ProductoId]) 
        REFERENCES [Catalog].[Producto] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    -- Validación complementaria para evitar inconsistencia de consumo de stock
    CONSTRAINT [CHK_Lote_Consistencia_Cantidades] CHECK ([CantidadDisponible] <= [CantidadInicial]),

    -- Restricción CHECK de dominio para el Estado del Lote (Simplificado a requerimiento)
    CONSTRAINT [CHK_Lote_Estado] CHECK ([Estado] IN ('ACTIVO', 'ANULADO'))
);
GO

-- ---------------------------------------------------------------------
-- ÍNDICES ESTRATÉGICOS: OPERACIONES.LOTE
-- ---------------------------------------------------------------------

-- Índice Clustered Compuesto: Ordenación física optimizada para RLS (Row-Level Security) y extracción automática FIFO/FEFO
CREATE CLUSTERED INDEX [CX_Operaciones_Lote_FIFO] ON [Operaciones].[Lote] (
    [TenantId] ASC, 
    [ProductoId] ASC, 
    [FechaVencimiento] ASC,
    [Id] ASC
);
GO

-- Índice UNIQUE Filtrado: Impide registrar duplicados del mismo número de lote para un mismo producto e inquilino.
-- Permite múltiples valores NULL (productos sin lote), resolviendo la limitación nativa de SQL Server.
CREATE UNIQUE NONCLUSTERED INDEX [UX_Operaciones_Lote_Numero] ON [Operaciones].[Lote] (
    [TenantId] ASC,
    [ProductoId] ASC,
    [NumeroLote] ASC
)
WHERE [NumeroLote] IS NOT NULL;
GO

-- Índice Non-Clustered de Cobertura: Optimiza las búsquedas del core logístico al segregar lotes activos por inquilino.
CREATE NONCLUSTERED INDEX [IX_Operaciones_Lote_Estado] ON [Operaciones].[Lote] (
    [TenantId], 
    [Estado]
) 
INCLUDE ([ProductoId], [CantidadDisponible], [UbicacionFisica]);
GO


-- ---------------------------------------------------------------------
-- 2. ENTIDAD: KARDEX (Historial inmutable de movimientos de stock)
-- ---------------------------------------------------------------------
PRINT 'Creando tabla Operaciones.Kardex...';
GO

CREATE TABLE [Operaciones].[Kardex] (
    [Id]                     BIGINT IDENTITY(1,1) NOT NULL,
    [TenantId]               INT                  NOT NULL,
    [ProductoId]             BIGINT               NOT NULL,
    [LoteId]                 BIGINT               NULL,     -- Permite NULL si el producto no trabaja con control de lotes
    [AlmacenId]              INT                  NOT NULL,
    [UsuarioId]              INT                  NOT NULL,
    [TipoMovimiento]         VARCHAR(30)          NOT NULL,
    [Cantidad]               DECIMAL(18,4)        NOT NULL,
    [StockAnterior]          DECIMAL(18,4)        NOT NULL,
    [StockPosterior]         DECIMAL(18,4)        NOT NULL,
    [CostoUnitarioCalculado] DECIMAL(18,4)        NOT NULL, -- Base para métodos de valuación (FIFO / Promedio Ponderado)
    [CostoTotalMovimiento]   DECIMAL(18,4)        NOT NULL,
    [FechaMovimiento]        DATETIME2            NOT NULL CONSTRAINT [DF_Kardex_FechaMovimiento] DEFAULT (SYSDATETIME()),
    
    -- Desacoplamiento de Trazabilidad Documental (Auditoría cruzada entre módulos)
    [DocumentoOrigen]        VARCHAR(50)          NULL,     -- Módulo de negocio emisor
    [TipoDocumento]          VARCHAR(50)          NULL,     -- Tipo de comprobante comercial/fiscal o interno
    [DocumentoReferenciaId]  BIGINT               NULL,     -- ID del documento en su respectiva tabla/módulo
    
    -- Estado del flujo del Kardex (Inmutabilidad del registro)
    -- Los registros NUNCA se eliminan ni modifican. Si una operación se revierte o anula en el ERP, 
    -- este estado pasa a 'ANULADO' y se genera obligatoriamente un nuevo registro compensatorio (contra-asiento).
    [Estado]                 VARCHAR(20)          NOT NULL CONSTRAINT [DF_Kardex_Estado] DEFAULT ('ACTIVO'),
    [Observacion]            NVARCHAR(500)        NULL,
    
    -- [RowVersion] REMOVIDO EXPRESAMENTE: Esta entidad es Append-Only; los bloqueos optimistas son innecesarios.

    -- Clave Primaria declarada como NONCLUSTERED para inyectar Clustered adaptado a consultas analíticas periódicas.
    CONSTRAINT [PK_Operaciones_Kardex] PRIMARY KEY NONCLUSTERED ([Id]),

    -- Restricciones de Integridad Referencial (Llaves Foráneas)
    CONSTRAINT [FK_Kardex_Tenant] FOREIGN KEY ([TenantId]) 
        REFERENCES [Config].[Tenant] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT [FK_Kardex_Producto] FOREIGN KEY ([ProductoId]) 
        REFERENCES [Catalog].[Producto] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT [FK_Kardex_Lote] FOREIGN KEY ([LoteId]) 
        REFERENCES [Operaciones].[Lote] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT [FK_Kardex_Almacen] FOREIGN KEY ([AlmacenId]) 
        REFERENCES [Catalog].[Almacen] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT [FK_Kardex_Usuario] FOREIGN KEY ([UsuarioId]) 
        REFERENCES [Config].[Usuario] ([Id]) ON DELETE NO ACTION ON UPDATE NO ACTION,

    -- Restricciones CHECK de Salvaguarda Física y Consistencia Contable
    CONSTRAINT [CHK_Kardex_Cantidad_Positiva] CHECK ([Cantidad] > 0),
    CONSTRAINT [CHK_Kardex_StockAnterior] CHECK ([StockAnterior] >= 0),
    CONSTRAINT [CHK_Kardex_StockPosterior] CHECK ([StockPosterior] >= 0),
    
    -- PROTECCIÓN INTEGRIDAD FINANCIERA: Asegura que no se inserten costos negativos que corrompan reportes de valorización
    CONSTRAINT [CHK_Kardex_CostoTotalMovimiento] CHECK ([CostoTotalMovimiento] >= 0),
    
    -- CHECK de Estado de Registro Inmutable
    CONSTRAINT [CHK_Kardex_Estado] CHECK ([Estado] IN ('ACTIVO', 'ANULADO')),
    
    -- CHECK de Tipos de Movimiento permitidos en el Core Logístico
    CONSTRAINT [CHK_Kardex_TipoMovimiento] CHECK ([TipoMovimiento] IN (
        'ENTRADA', 
        'SALIDA', 
        'AJUSTE', 
        'TRANSFERENCIA', 
        'DEVOLUCION_COMPRA', 
        'DEVOLUCION_VENTA', 
        'INVENTARIO_INICIAL'
    )),

    -- CHECK de Módulos Origen: Ampliado con 'PRODUCCION' (V2) y 'DEVOLUCION' (Trazabilidad limpia)
    CONSTRAINT [CHK_Kardex_DocumentoOrigen] CHECK ([DocumentoOrigen] IN (
        'COMPRA', 
        'VENTA', 
        'AJUSTE', 
        'TRANSFERENCIA', 
        'IMPORTACION', 
        'INVENTARIO_INICIAL',
        'PRODUCCION',
        'DEVOLUCION'
    )),

    -- CHECK de Comprobantes: Excluye 'ORDEN_COMPRA' (No genera afectación física de inventario) e incluye 'SIN_DOCUMENTO'
    CONSTRAINT [CHK_Kardex_TipoDocumento] CHECK ([TipoDocumento] IN (
        'FACTURA', 
        'BOLETA', 
        'GUIA_REMISION', 
        'NOTA_CREDITO', 
        'NOTA_DEBITO', 
        'OTRO',
        'SIN_DOCUMENTO'
    ))
);
GO

-- ---------------------------------------------------------------------
-- ÍNDICES ESTRATÉGICOS: OPERACIONES.KARDEX
-- ---------------------------------------------------------------------

-- Índice Clustered: Alineación física óptima por inquilino y orden cronológico.
-- Maximiza el performance del cálculo de saldos y costos usando ventanas de tiempo.
CREATE CLUSTERED INDEX [CX_Operaciones_Kardex_Consulta] ON [Operaciones].[Kardex] (
    [TenantId] ASC, 
    [ProductoId] ASC, 
    [FechaMovimiento] ASC, 
    [Id] ASC
);
GO

-- Índice Non-Clustered de Cobertura Documental: Acelera auditorías internas y conciliaciones por transacción origen.
CREATE NONCLUSTERED INDEX [IX_Operaciones_Kardex_Trazabilidad] ON [Operaciones].[Kardex] (
    [TenantId],
    [DocumentoOrigen],
    [DocumentoReferenciaId]
) 
INCLUDE ([Cantidad], [CostoTotalMovimiento], [Estado]);
GO

PRINT 'Entidades del esquema de Operaciones finalizadas con éxito.';
GO