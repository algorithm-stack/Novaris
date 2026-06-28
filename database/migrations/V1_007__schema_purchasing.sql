-- ==========================================================================================
-- NOVARIS ERP - SPRINT 7: MÓDULO DE COMPRAS (VERSION FINAL BLINDADA)
-- ==========================================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='Compras')
BEGIN
    EXEC('CREATE SCHEMA Compras');
END
GO

-- 1. SOLICITUD DE COMPRA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Compras.SolicitudCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    SolicitanteUsuarioId INT NOT NULL,
    CentroCostoId INT NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    Observacion NVARCHAR(MAX) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CreadoPor INT NOT NULL,
    CONSTRAINT PK_SolicitudCompra PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_SolCompra_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT FK_SolCompra_Usuario FOREIGN KEY (SolicitanteUsuarioId) REFERENCES Config.Usuario(Id),
    CONSTRAINT FK_SolCompra_CC FOREIGN KEY (TenantId, CentroCostoId) REFERENCES Finanzas.CentroCosto(TenantId, Id),
    CONSTRAINT CK_SolCompra_Estado CHECK (Estado IN ('BORRADOR', 'EN_APROBACION', 'APROBADA', 'RECHAZADA', 'CERRADA'))
);

CREATE TABLE Compras.SolicitudCompraDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    SolicitudCompraId BIGINT NOT NULL,
    ProductoId BIGINT NOT NULL,
    Cantidad DECIMAL(18,4) NOT NULL CHECK (Cantidad > 0),
    CantidadPendiente DECIMAL(18,4) NOT NULL CHECK (CantidadPendiente >= 0),
    EstadoLinea VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT PK_SolicitudCompraDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_SolDet_Header FOREIGN KEY (TenantId, SolicitudCompraId) REFERENCES Compras.SolicitudCompra(TenantId, Id),
    CONSTRAINT FK_SolDet_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id),
    CONSTRAINT CK_SolDet_Cant CHECK (CantidadPendiente <= Cantidad)
);

-- 2. COTIZACIONES Y COMPARATIVO
-- ------------------------------------------------------------------------------------------

CREATE TABLE Compras.CotizacionProveedor (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    ProveedorId BIGINT NOT NULL,
    FechaEmision DATE NOT NULL,
    ValidezHasta DATE NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    CONSTRAINT PK_CotizacionProveedor PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_CotProv_Prov FOREIGN KEY (TenantId, ProveedorId) REFERENCES CRM.Proveedor(TenantId, PersonaId)
);

CREATE TABLE Compras.ComparativoCotizacion (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    SolicitudCompraId BIGINT NOT NULL,
    ProveedorSeleccionadoId BIGINT NOT NULL,
    Justificacion NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Comparativo PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Comp_Sol FOREIGN KEY (TenantId, SolicitudCompraId) REFERENCES Compras.SolicitudCompra(TenantId, Id),
    CONSTRAINT FK_Comp_Prov FOREIGN KEY (TenantId, ProveedorSeleccionadoId) REFERENCES CRM.Proveedor(TenantId, PersonaId)
);

-- 3. ÓRDENES DE COMPRA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Compras.OrdenCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    ProveedorId BIGINT NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'EMITIDA',
    Total DECIMAL(18,4) NOT NULL CHECK (Total >= 0),
    FechaEsperada DATE NOT NULL,
    CONSTRAINT PK_OrdenCompra PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_OC_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT CK_OC_Estado CHECK (Estado IN ('BORRADOR', 'APROBADA', 'EMITIDA', 'EN_TRANSITO', 'PARCIALMENTE_RECIBIDA', 'RECIBIDA', 'FACTURADA', 'CERRADA', 'ANULADA'))
);

CREATE TABLE Compras.OrdenCompraDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    OrdenCompraId BIGINT NOT NULL,
    ProductoId BIGINT NOT NULL,
    Cantidad DECIMAL(18,4) NOT NULL CHECK (Cantidad > 0),
    CantidadRecibida DECIMAL(18,4) NOT NULL DEFAULT 0 CHECK (CantidadRecibida >= 0),
    CantidadFacturada DECIMAL(18,4) NOT NULL DEFAULT 0 CHECK (CantidadFacturada >= 0),
    CostoUnitarioFinal DECIMAL(18,4) NOT NULL CHECK (CostoUnitarioFinal >= 0),
    CONSTRAINT PK_OrdenCompraDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_OCDet_Header FOREIGN KEY (TenantId, OrdenCompraId) REFERENCES Compras.OrdenCompra(TenantId, Id),
    CONSTRAINT CK_OCDet_Rec CHECK (CantidadRecibida <= Cantidad),
    CONSTRAINT CK_OCDet_Fact CHECK (CantidadFacturada <= Cantidad)
);

-- 4. RECEPCIÓN Y FACTURACIÓN
-- ------------------------------------------------------------------------------------------

CREATE TABLE Compras.RecepcionCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    OrdenCompraId BIGINT NOT NULL,
    AlmacenId BIGINT NOT NULL,
    GuiaRemision VARCHAR(50) NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'ABIERTA',
    CONSTRAINT PK_Recepcion PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Rec_OC FOREIGN KEY (TenantId, OrdenCompraId) REFERENCES Compras.OrdenCompra(TenantId, Id),
    CONSTRAINT FK_Rec_Almacen FOREIGN KEY (TenantId, AlmacenId) REFERENCES Catalog.Almacen(TenantId, Id)
);

CREATE TABLE Compras.RecepcionCompraDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    RecepcionCompraId BIGINT NOT NULL,
    OrdenCompraDetalleId BIGINT NOT NULL,
    CantidadRecibida DECIMAL(18,4) NOT NULL CHECK (CantidadRecibida > 0),
    CantidadRechazada DECIMAL(18,4) NOT NULL DEFAULT 0,
    EstadoCalidad VARCHAR(20) NOT NULL DEFAULT 'APROBADO',
    CONSTRAINT PK_RecepcionDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_RecDet_Header FOREIGN KEY (TenantId, RecepcionCompraId) REFERENCES Compras.RecepcionCompra(TenantId, Id),
    CONSTRAINT FK_RecDet_OCDet FOREIGN KEY (TenantId, OrdenCompraDetalleId) REFERENCES Compras.OrdenCompraDetalle(TenantId, Id)
);

CREATE TABLE Compras.FacturaCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    OrdenCompraId BIGINT NOT NULL,
    Total DECIMAL(18,4) NOT NULL CHECK (Total >= 0),
    CONSTRAINT PK_FacturaCompra PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Fact_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id)
);

CREATE TABLE Compras.FacturaCompraDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    FacturaCompraId BIGINT NOT NULL,
    OrdenCompraDetalleId BIGINT NOT NULL,
    CantidadFacturada DECIMAL(18,4) NOT NULL CHECK (CantidadFacturada > 0),
    CONSTRAINT PK_FacturaDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_FactDet_Fact FOREIGN KEY (TenantId, FacturaCompraId) REFERENCES Compras.FacturaCompra(TenantId, Id),
    CONSTRAINT FK_FactDet_OCDet FOREIGN KEY (TenantId, OrdenCompraDetalleId) REFERENCES Compras.OrdenCompraDetalle(TenantId, Id)
);

-- 5. AUDITORÍA Y METRICAS IA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Compras.AprobacionCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    SolicitudCompraId BIGINT NOT NULL,
    UsuarioId INT NOT NULL,
    Estado VARCHAR(20) NOT NULL CHECK (Estado IN ('PENDIENTE', 'APROBADO', 'RECHAZADO')),
    CONSTRAINT PK_Aprobacion PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Apro_Usuario FOREIGN KEY (UsuarioId) REFERENCES Config.Usuario(Id)
);

CREATE TABLE Compras.HistorialEstadoCompra (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    EntidadTipo VARCHAR(50) NOT NULL,
    EntidadId BIGINT NOT NULL,
    EstadoAnterior VARCHAR(20) NOT NULL,
    EstadoNuevo VARCHAR(20) NOT NULL,
    FechaCambio DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    UsuarioId INT NOT NULL,
    CONSTRAINT PK_HistorialEstado PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Hist_Usuario FOREIGN KEY (UsuarioId) REFERENCES Config.Usuario(Id)
);

CREATE TABLE Compras.ProveedorScoreHistorico (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    ProveedorId BIGINT NOT NULL,
    FechaCalculo DATETIME2 NOT NULL,
    ScoreIA DECIMAL(5,2) NOT NULL,
    LeadTimePromedio INT NOT NULL,
    CONSTRAINT PK_ProvScore PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_ProvScore_Prov FOREIGN KEY (TenantId, ProveedorId) REFERENCES CRM.Proveedor(TenantId, PersonaId)
);

CREATE NONCLUSTERED INDEX IX_OC_Estado_Prov ON Compras.OrdenCompra (TenantId, Estado, ProveedorId);
CREATE NONCLUSTERED INDEX IX_OCDet_Orden ON Compras.OrdenCompraDetalle (TenantId, OrdenCompraId);
CREATE NONCLUSTERED INDEX IX_Recepcion_OC ON Compras.RecepcionCompra (TenantId, OrdenCompraId);
CREATE NONCLUSTERED INDEX IX_Factura_OC ON Compras.FacturaCompra (TenantId, OrdenCompraId);
CREATE NONCLUSTERED INDEX IX_ProvScore_Prov ON Compras.ProveedorScoreHistorico (TenantId, ProveedorId, FechaCalculo);
GO