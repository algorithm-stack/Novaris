-- ==========================================================================================
-- NOVARIS ERP - SPRINT 3: MÓDULO TRANSACCIONAL
-- SCRIPT DE MIGRACIÓN: V1_004__schema_transactions.sql
-- ROLES: Enterprise Software Architect, Tech Lead, ERP Solutions Architect & Senior DBA
-- ==========================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ------------------------------------------------------------------------------------------
-- 0. CREACIÓN DEL ESQUEMA TRANSACCIONES
-- ------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Transacciones')
BEGIN
    EXEC('CREATE SCHEMA Transacciones;');
END
GO

-- ------------------------------------------------------------------------------------------
-- 1. TABLAS DE CATÁLOGO / DOMINIO ESTÁTICO (NO MULTI-TENANT)
-- ------------------------------------------------------------------------------------------

CREATE TABLE Transacciones.EstadoDocumento (
    EstadoDocumentoId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    CONSTRAINT PK_EstadoDocumento PRIMARY KEY CLUSTERED (EstadoDocumentoId),
    CONSTRAINT UQ_EstadoDocumento_Nombre UNIQUE (Nombre)
);

CREATE TABLE Transacciones.TipoDocumento (
    TipoDocumentoId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Codigo VARCHAR(20) NOT NULL, -- Ej: 'FAC', 'BOL', 'COT', 'PED', 'NOTC', 'NOTD'
    CONSTRAINT PK_TipoDocumento PRIMARY KEY CLUSTERED (TipoDocumentoId),
    CONSTRAINT UQ_TipoDocumento_Codigo UNIQUE (Codigo)
);

-- Detalle 10: Creación de catálogo para Tipos de Relación entre Documentos
CREATE TABLE Transacciones.TipoRelacionDocumento (
    TipoRelacionDocumentoId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL, -- Ej: 'Referencia', 'Conversión Pedido', 'Nota de Crédito'
    CONSTRAINT PK_TipoRelacionDocumento PRIMARY KEY CLUSTERED (TipoRelacionDocumentoId),
    CONSTRAINT UQ_TipoRelacionDocumento_Nombre UNIQUE (Nombre)
);

CREATE TABLE Transacciones.Moneda (
    MonedaCodigo CHAR(3) NOT NULL, -- Código ISO 4217 (Ej: 'PEN', 'USD', 'EUR')
    Nombre VARCHAR(50) NOT NULL,
    Simbolo VARCHAR(5) NOT NULL,
    CONSTRAINT PK_Moneda PRIMARY KEY CLUSTERED (MonedaCodigo)
);

CREATE TABLE Transacciones.FuenteTipoCambio (
    FuenteTipoCambioId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL, -- Ej: 'SUNAT', 'BCR', 'Manual'
    CONSTRAINT PK_FuenteTipoCambio PRIMARY KEY CLUSTERED (FuenteTipoCambioId)
);

CREATE TABLE Transacciones.UnidadMedida (
    UnidadMedidaId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Sigla VARCHAR(10) NOT NULL, -- Ej: 'UND', 'CJ', 'PK', 'M', 'KG'
    CONSTRAINT PK_UnidadMedida PRIMARY KEY CLUSTERED (UnidadMedidaId)
);

CREATE TABLE Transacciones.Impuesto (
    ImpuestoId INT NOT NULL,
    Nombre VARCHAR(50) NOT NULL, -- Ej: 'IGV 18%', 'Exonerado', 'Inafecto'
    Porcentaje DECIMAL(5,2) NOT NULL, -- Ej: 18.00, 0.00
    CONSTRAINT PK_Impuesto PRIMARY KEY CLUSTERED (ImpuestoId)
);
GO

-- ------------------------------------------------------------------------------------------
-- SEED DATA: CARGA DE CATÁLOGOS BASE
-- ------------------------------------------------------------------------------------------
INSERT INTO Transacciones.EstadoDocumento (EstadoDocumentoId, Nombre) VALUES
(1, 'Borrador'), (2, 'Pendiente'), (3, 'Emitido'), (4, 'Pagado'), (5, 'Parcial'), (6, 'Anulado'), (7, 'Cerrado');

INSERT INTO Transacciones.TipoDocumento (TipoDocumentoId, Nombre, Codigo) VALUES
(1, 'Cotizacion', 'COT'), (2, 'Proforma', 'PRO'), (3, 'Pedido', 'PED'),
(4, 'Compra', 'COM'), (5, 'Venta', 'VEN'), (6, 'Nota de Credito', 'NCR'),
(7, 'Nota de Debito', 'NDB'), (8, 'Devolucion', 'DEV');

INSERT INTO Transacciones.TipoRelacionDocumento (TipoRelacionDocumentoId, Nombre) VALUES
(1, 'Referencia'), (2, 'Conversion Pedido'), (3, 'Nota de Credito / Afectacion'), (4, 'Nota de Debito / Afectacion');

INSERT INTO Transacciones.Moneda (MonedaCodigo, Nombre, Simbolo) VALUES
('PEN', 'Sol Peruano', 'S/'), ('USD', 'Dolar Estadounidense', '$'), ('EUR', 'Euro', '€');

INSERT INTO Transacciones.FuenteTipoCambio (FuenteTipoCambioId, Nombre) VALUES
(1, 'SUNAT'), (2, 'BCR'), (3, 'Manual');

INSERT INTO Transacciones.UnidadMedida (UnidadMedidaId, Nombre, Sigla) VALUES
(1, 'Unidad', 'UND'), (2, 'Caja', 'CJ'), (3, 'Pack', 'PK'), (4, 'Metro', 'M'), (5, 'Litro', 'L'), (6, 'Kilogramo', 'KG');

INSERT INTO Transacciones.Impuesto (ImpuestoId, Nombre, Porcentaje) VALUES
(1, 'IGV 18%', 18.00), (2, 'Exonerado', 0.00), (3, 'Inafecto', 0.00);
GO

-- ------------------------------------------------------------------------------------------
-- 2. TABLAS NÚCLEO TRANSACCIONAL (DISEÑO MULTI-TENANT SAAS CON PK COMPUESTA CLUSTERED)
-- ------------------------------------------------------------------------------------------

-- CONTROL DE SECUENCIAS FISCALES Y COMERCIALES (PREVIENE CONDICIONES DE CARRERA)
CREATE TABLE Transacciones.SerieCorrelativo (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    SucursalId INT NOT NULL,
    TipoDocumentoId INT NOT NULL,
    Serie VARCHAR(20) NOT NULL,
    CorrelativoActual BIGINT NOT NULL DEFAULT 0,
    Prefijo VARCHAR(10) NULL,
    CONSTRAINT PK_SerieCorrelativo PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_SerieCorrelativo_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_SerieCorrelativo_TipoDoc FOREIGN KEY (TipoDocumentoId) REFERENCES Transacciones.TipoDocumento(TipoDocumentoId),
    CONSTRAINT UQ_SerieCorrelativo_Emision UNIQUE (TenantId, SucursalId, TipoDocumentoId, Serie)
);

-- CABECERA UNIFICADA DE DOCUMENTOS
CREATE TABLE Transacciones.DocumentoHeader (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    SucursalId INT NOT NULL,
    AlmacenId INT NOT NULL,
    TipoDocumentoId INT NOT NULL,
    EstadoDocumentoId INT NOT NULL,
    Serie VARCHAR(20) NOT NULL,
    Correlativo VARCHAR(20) NOT NULL,
    
    -- Detalle 14: Restricciones de Claves Foráneas Explícitas
    ClienteId BIGINT NULL,
    ProveedorId BIGINT NULL,
    
    FechaEmision DATE NOT NULL,
    FechaVence DATE NULL, -- Detalle 3: Cambiado a NULL (no aplica estrictamente a boletas o POS rápido)
    MonedaCodigo CHAR(3) NOT NULL,
    TipoCambio DECIMAL(18,4) NOT NULL DEFAULT 1.0000,
    FuenteTipoCambioId INT NULL,
    
    SubTotal DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    TotalImpuestos DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    TotalDescuentos DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    TotalDocumento DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    
    Observacion NVARCHAR(1000) NULL,
    EsElectronico BIT NOT NULL DEFAULT 0,
    HashDocumento VARCHAR(128) NULL, -- Detalle 6: Cambiado de UUIDDocumento a HashDocumento (Enfoque SUNAT/Firma)
    
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    -- Detalle 5: Eliminado el campo 'UsuarioId' por redundancia. Prevalece CreadoPor / ActualizadoPor
    CreadoPor INT NOT NULL,
    ActualizadoPor INT NULL,
    
    -- Detalle 4 y 7: Trazabilidad y auditoría exacta de Anulación (en lugar de Eliminado lógicos)
    Anulado BIT NOT NULL DEFAULT 0,
    FechaAnulacion DATETIME2 NULL,
    UsuarioAnulacion INT NULL,

    CONSTRAINT PK_DocumentoHeader PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_DocumentoHeader_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_DocumentoHeader_TipoDoc FOREIGN KEY (TipoDocumentoId) REFERENCES Transacciones.TipoDocumento(TipoDocumentoId),
    CONSTRAINT FK_DocumentoHeader_Estado FOREIGN KEY (EstadoDocumentoId) REFERENCES Transacciones.EstadoDocumento(EstadoDocumentoId),
    CONSTRAINT FK_DocumentoHeader_Moneda FOREIGN KEY (MonedaCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT FK_DocumentoHeader_FuenteTC FOREIGN KEY (FuenteTipoCambioId) REFERENCES Transacciones.FuenteTipoCambio(FuenteTipoCambioId),
    
    -- Detalle 2 (Opción A): Las FK compuestas funcionan asumiendo la restricción UNIQUE(TenantId, Id) implementada en el Sprint anterior
    CONSTRAINT FK_DocumentoHeader_Cliente FOREIGN KEY (TenantId, ClienteId) REFERENCES Catalog.Cliente(TenantId, Id),
    CONSTRAINT FK_DocumentoHeader_Proveedor FOREIGN KEY (TenantId, ProveedorId) REFERENCES Catalog.Proveedor(TenantId, Id),
    CONSTRAINT FK_DocumentoHeader_Almacen FOREIGN KEY (TenantId, AlmacenId) REFERENCES Catalog.Almacen(TenantId, Id),
    
    -- Detalle 14: Restricción CHECK de mutua exclusión limpia
    CONSTRAINT CK_DocumentoHeader_Cliente_Proveedor CHECK (
        (ClienteId IS NOT NULL AND ProveedorId IS NULL) OR 
        (ClienteId IS NULL AND ProveedorId IS NOT NULL) OR 
        (ClienteId IS NULL AND ProveedorId IS NULL)
    ),
    CONSTRAINT UQ_DocumentoHeader_Numeracion UNIQUE (TenantId, SucursalId, TipoDocumentoId, Serie, Correlativo)
);

-- DETALLE DE LÍNEAS DE DOCUMENTO
CREATE TABLE Transacciones.DocumentoDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    OrdenLinea SMALLINT NOT NULL, -- Detalle 8: Agregado para conservar el orden visual en la grilla/impresión
    ProductoId BIGINT NOT NULL,
    LoteId BIGINT NULL,
    UnidadMedidaId INT NOT NULL,
    ImpuestoId INT NOT NULL,
    
    CantidadTransaccionada DECIMAL(18,4) NOT NULL,
    PrecioLista DECIMAL(18,4) NOT NULL,
    PrecioVenta DECIMAL(18,4) NOT NULL,
    CostoAdquisicionHistorico DECIMAL(18,4) NOT NULL,
    MontoImpuesto DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    MontoDescuento DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    TotalLinea DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    ObservacionLinea NVARCHAR(500) NULL, -- Detalle 9: Observaciones particulares por ítem de línea

    CONSTRAINT PK_DocumentoDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_DocumentoDetalle_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_DocumentoDetalle_Unidad FOREIGN KEY (UnidadMedidaId) REFERENCES Transacciones.UnidadMedida(UnidadMedidaId),
    CONSTRAINT FK_DocumentoDetalle_Impuesto FOREIGN KEY (ImpuestoId) REFERENCES Transacciones.Impuesto(ImpuestoId),
    
    -- Detalle 2 (Opción A): Integración Cruzada Segura por TenantId
    CONSTRAINT FK_DocumentoDetalle_Producto FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id),
    CONSTRAINT FK_DocumentoDetalle_Lote FOREIGN KEY (TenantId, LoteId) REFERENCES Operaciones.Lote(TenantId, Id),
    
    CONSTRAINT CK_DocumentoDetalle_Cantidad CHECK (CantidadTransaccionada > 0)
);

-- TRAZABILIDAD CRUZADA DE DOCUMENTOS (GRAFO)
CREATE TABLE Transacciones.DocumentoRelacion (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoOrigenId BIGINT NOT NULL,
    DocumentoDestinoId BIGINT NOT NULL,
    TipoRelacionDocumentoId INT NOT NULL, -- Detalle 10: Cambiado VARCHAR por FK al catálogo normalizado
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_DocumentoRelacion PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_DocumentoRelacion_HeaderOrigen FOREIGN KEY (TenantId, DocumentoOrigenId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_DocumentoRelacion_HeaderDestino FOREIGN KEY (TenantId, DocumentoDestinoId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_DocumentoRelacion_TipoRelacion FOREIGN KEY (TipoRelacionDocumentoId) REFERENCES Transacciones.TipoRelacionDocumento(TipoRelacionDocumentoId),
    CONSTRAINT CK_DocumentoRelacion_Distintos CHECK (DocumentoOrigenId <> DocumentoDestinoId)
);

-- RESERVAS LOGÍSTICAS DE APARTADO DE STOCK
CREATE TABLE Transacciones.ReservaStock (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    ProductoId BIGINT NOT NULL,
    LoteId BIGINT NOT NULL,
    CantidadReservada DECIMAL(18,4) NOT NULL,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FechaLiberacion DATETIME2 NULL,
    FechaExpiracion DATE NOT NULL,
    EstadoReserva VARCHAR(20) NOT NULL DEFAULT 'ACTIVA', -- 'ACTIVA', 'CONSUMIDA', 'EXPIRADA'
    UsuarioReservaId INT NOT NULL, -- Detalle 11: Agregado auditor de responsable de la reserva

    CONSTRAINT PK_ReservaStock PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_ReservaStock_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_ReservaStock_Producto FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id),
    CONSTRAINT FK_ReservaStock_Lote FOREIGN KEY (TenantId, LoteId) REFERENCES Operaciones.Lote(TenantId, Id),
    CONSTRAINT CK_ReservaStock_Cantidad CHECK (CantidadReservada > 0),
    CONSTRAINT CK_ReservaStock_Estados CHECK (EstadoReserva IN ('ACTIVA', 'CONSUMIDA', 'EXPIRADA'))
);

-- HISTORIAL DE CAMBIOS DE ESTADO DE DOCUMENTOS (AUDITORÍA INMUTABLE)
CREATE TABLE Transacciones.DocumentoEstadoHistorial (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    EstadoDocumentoId INT NOT NULL,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    UsuarioId INT NOT NULL,
    Observacion NVARCHAR(500) NULL,

    CONSTRAINT PK_DocumentoEstadoHistorial PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_DocumentoEstadoHistorial_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_DocumentoEstadoHistorial_Estado FOREIGN KEY (EstadoDocumentoId) REFERENCES Transacciones.EstadoDocumento(EstadoDocumentoId)
);

-- Detalle 15: Nueva tabla extendida contemplada para el Módulo de Almacenamiento de Adjuntos (Fase Transaccional/Fiscal)
CREATE TABLE Transacciones.DocumentoAdjunto (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    TipoAdjunto VARCHAR(20) NOT NULL, -- 'XML', 'CDR', 'PDF', 'GUIA_IMG', 'TICKET'
    NombreArchivo VARCHAR(255) NOT NULL,
    RutaAlmacenamiento VARCHAR(512) NOT NULL, -- URI absoluta hacia el Object Storage (AWS S3 / Azure Blob)
    HashValidacion CHAR(64) NULL, -- Resguardo SHA-256 para validación de inmutabilidad fiscal
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CreadoPor INT NOT NULL,

    CONSTRAINT PK_DocumentoAdjunto PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_DocumentoAdjunto_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT CK_DocumentoAdjunto_Tipo CHECK (TipoAdjunto IN ('XML', 'CDR', 'PDF', 'GUIA_IMG', 'TICKET'))
);
GO

-- ------------------------------------------------------------------------------------------
-- 3. CREACIÓN DE ÍNDICES DE RENDIMIENTO (ESTRATEGIA DBA DE BÚSQUEDA Y AISLAMIENTO)
-- ------------------------------------------------------------------------------------------

-- Índices de cobertura generales optimizados
CREATE NONCLUSTERED INDEX IX_DocumentoHeader_Busqueda 
ON Transacciones.DocumentoHeader (TenantId, FechaEmision, TipoDocumentoId)
INCLUDE (EstadoDocumentoId, TotalDocumento, ClienteId, ProveedorId);

-- Detalle 1: Corregido el error de compilación cambiando 'TotalLineas' por la columna real 'TotalLinea'
CREATE NONCLUSTERED INDEX IX_DocumentoDetalle_Header
ON Transacciones.DocumentoDetalle (TenantId, DocumentoHeaderId)
INCLUDE (ProductoId, LoteId, TotalLinea);

CREATE NONCLUSTERED INDEX IX_ReservaStock_Activas
ON Transacciones.ReservaStock (TenantId, LoteId, EstadoReserva)
INCLUDE (CantidadReservada)
WHERE EstadoReserva = 'ACTIVA';

-- Detalle 12: Índice de alto rendimiento para reportes e historial frecuente de Clientes
CREATE NONCLUSTERED INDEX IX_DocumentoHeader_ClienteReporte
ON Transacciones.DocumentoHeader (TenantId, ClienteId, FechaEmision)
INCLUDE (TipoDocumentoId, EstadoDocumentoId, TotalDocumento)
WHERE Anulado = 0;

-- Detalle 13: Índice de alto rendimiento para reportes e historial frecuente de Proveedores
CREATE NONCLUSTERED INDEX IX_DocumentoHeader_ProveedorReporte
ON Transacciones.DocumentoHeader (TenantId, ProveedorId, FechaEmision)
INCLUDE (TipoDocumentoId, EstadoDocumentoId, TotalDocumento)
WHERE Anulado = 0;
GO