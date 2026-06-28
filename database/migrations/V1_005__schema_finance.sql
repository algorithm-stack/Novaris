-- ==========================================================================================
-- NOVARIS ERP - SPRINT 4: MÓDULO FINANCIERO Y CONTABLE (VERSIÓN 4.0 - PRODUCCIÓN FINAL)
-- ==========================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. CATÁLOGOS FINANCIEROS
-- ------------------------------------------------------------------------------------------

CREATE TABLE Finanzas.CentroCosto (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    Codigo VARCHAR(20) NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    PresupuestoAsignado DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    Activo BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CreadoPor INT NOT NULL,
    CONSTRAINT PK_CentroCosto PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_CentroCosto_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT UQ_CentroCosto_Codigo UNIQUE (TenantId, Codigo)
);

CREATE TABLE Finanzas.FormaPago (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Tipo VARCHAR(20) NOT NULL,
    OrdenVisual INT NOT NULL DEFAULT 0,
    RequiereReferencia BIT NOT NULL DEFAULT 0,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_FormaPago PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_FormaPago_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT CK_FormaPago_Tipo CHECK (Tipo IN ('EFECTIVO', 'BANCO', 'BILLETERA_DIGITAL', 'CREDITO', 'OTRO'))
);

CREATE TABLE Finanzas.CuentaBancaria (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    NombreBanco VARCHAR(100) NOT NULL,
    Titular VARCHAR(150) NOT NULL,
    RUC VARCHAR(20) NULL,
    NumeroCuenta VARCHAR(50) NOT NULL,
    CCI VARCHAR(50) NULL,
    SWIFT VARCHAR(20) NULL,
    IBAN VARCHAR(50) NULL,
    MonedaCodigo CHAR(3) NOT NULL,
    TipoCuenta VARCHAR(20) NOT NULL,
    Activo BIT NOT NULL DEFAULT 1,
    Estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    SaldoActual DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_CuentaBancaria PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_CuentaBancaria_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_CuentaBancaria_Moneda FOREIGN KEY (MonedaCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT CK_CuentaBancaria_Estado CHECK (Estado IN ('ACTIVA', 'SUSPENDIDA', 'CERRADA', 'BLOQUEADA')),
    CONSTRAINT CK_CuentaBancaria_Tipo CHECK (TipoCuenta IN ('CORRIENTE', 'AHORROS', 'RECAUDACION', 'CREDITO'))
);

CREATE TABLE Finanzas.TipoCambioHistorico (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    Fecha DATE NOT NULL,
    MonedaOrigenCodigo CHAR(3) NOT NULL,
    MonedaDestinoCodigo CHAR(3) NOT NULL,
    Compra DECIMAL(18,4) NOT NULL,
    Venta DECIMAL(18,4) NOT NULL,
    FuenteTipoCambioId INT NOT NULL,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CreadoPor INT NOT NULL,
    CONSTRAINT PK_TipoCambioHistorico PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_TCH_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_TCH_MonOrigen FOREIGN KEY (MonedaOrigenCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT FK_TCH_MonDestino FOREIGN KEY (MonedaDestinoCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT FK_TCH_Fuente FOREIGN KEY (FuenteTipoCambioId) REFERENCES Transacciones.FuenteTipoCambio(FuenteTipoCambioId)
);

-- 2. TRANSACCIONES FINANCIERAS
-- ------------------------------------------------------------------------------------------

CREATE TABLE Finanzas.Pago (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    NumeroOperacionPrincipal VARCHAR(100) NULL,
    TipoPago VARCHAR(10) NOT NULL,
    ClienteId BIGINT NULL,
    ProveedorId BIGINT NULL,
    MonedaCodigo CHAR(3) NOT NULL,
    MontoTotal DECIMAL(18,4) NOT NULL,
    FechaPago DATE NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'PROCESADO',
    Observacion NVARCHAR(500) NULL,
    CreadoPor INT NOT NULL,
    Anulado BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_Pago PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Pago_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_Pago_Moneda FOREIGN KEY (MonedaCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT FK_Pago_Cliente FOREIGN KEY (TenantId, ClienteId) REFERENCES Catalog.Cliente(TenantId, Id),
    CONSTRAINT FK_Pago_Proveedor FOREIGN KEY (TenantId, ProveedorId) REFERENCES Catalog.Proveedor(TenantId, Id),
    CONSTRAINT CK_Pago_Tipo CHECK (TipoPago IN ('COBRO', 'PAGO')),
    CONSTRAINT CK_Pago_Estado CHECK (Estado IN ('PROCESADO', 'ANULADO'))
);

CREATE TABLE Finanzas.PagoDetalle (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PagoId BIGINT NOT NULL,
    DocumentoHeaderId BIGINT NOT NULL,
    SaldoAnteriorDocumento DECIMAL(18,4) NOT NULL,
    MontoAplicado DECIMAL(18,4) NOT NULL,
    MontoMora DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    SaldoPosteriorDocumento DECIMAL(18,4) NOT NULL,
    CONSTRAINT PK_PagoDetalle PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_PagoDetalle_Pago FOREIGN KEY (TenantId, PagoId) REFERENCES Finanzas.Pago(TenantId, Id),
    CONSTRAINT FK_PagoDetalle_Doc FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id),
    CONSTRAINT CK_PagoDetalle_Saldos CHECK (SaldoAnteriorDocumento >= 0 AND SaldoPosteriorDocumento >= 0)
);

CREATE TABLE Finanzas.MovimientoBanco (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    CuentaBancariaId INT NOT NULL,
    CentroCostoId INT NULL,
    TipoMovimiento VARCHAR(10) NOT NULL,
    Monto DECIMAL(18,4) NOT NULL,
    SaldoAnterior DECIMAL(18,4) NOT NULL,
    SaldoPosterior DECIMAL(18,4) NOT NULL,
    FechaMovimiento DATE NOT NULL,
    NumeroOperacion VARCHAR(100) NULL,
    Observacion NVARCHAR(500) NULL,
    Conciliado BIT NOT NULL DEFAULT 0,
    FechaConciliacion DATETIME2 NULL,
    UsuarioConciliacion INT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    CreadoPor INT NOT NULL,
    CONSTRAINT PK_MovimientoBanco PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_MB_Cuenta FOREIGN KEY (TenantId, CuentaBancariaId) REFERENCES Finanzas.CuentaBancaria(TenantId, Id),
    CONSTRAINT FK_MB_CC FOREIGN KEY (TenantId, CentroCostoId) REFERENCES Finanzas.CentroCosto(TenantId, Id),
    CONSTRAINT CK_MB_Tipo CHECK (TipoMovimiento IN ('INGRESO', 'EGRESO')),
    CONSTRAINT CK_MB_Estado CHECK (Estado IN ('ACTIVO', 'ANULADO')),
    CONSTRAINT CK_MB_Saldos CHECK (SaldoAnterior >= 0 AND SaldoPosterior >= 0)
);

CREATE TABLE Finanzas.MovimientoCaja (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    CentroCostoId INT NULL,
    MonedaCodigo CHAR(3) NOT NULL,
    Concepto VARCHAR(200) NOT NULL,
    Monto DECIMAL(18,4) NOT NULL,
    SaldoAnterior DECIMAL(18,4) NOT NULL,
    SaldoPosterior DECIMAL(18,4) NOT NULL,
    FechaMovimiento DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    Estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    CreadoPor INT NOT NULL,
    CONSTRAINT PK_MovimientoCaja PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_MC_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_MC_CC FOREIGN KEY (TenantId, CentroCostoId) REFERENCES Finanzas.CentroCosto(TenantId, Id),
    CONSTRAINT FK_MC_Moneda FOREIGN KEY (MonedaCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT CK_MC_Estado CHECK (Estado IN ('ACTIVO', 'ANULADO')),
    CONSTRAINT CK_MC_Saldos CHECK (SaldoAnterior >= 0 AND SaldoPosterior >= 0)
);

CREATE TABLE Finanzas.ComprobantePago (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PagoId BIGINT NOT NULL,
    FormaPagoId INT NOT NULL,
    Monto DECIMAL(18,4) NOT NULL,
    NumeroReferencia VARCHAR(100) NULL,
    CONSTRAINT PK_ComprobantePago PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_CP_Pago FOREIGN KEY (TenantId, PagoId) REFERENCES Finanzas.Pago(TenantId, Id),
    CONSTRAINT FK_CP_Forma FOREIGN KEY (TenantId, FormaPagoId) REFERENCES Finanzas.FormaPago(TenantId, Id)
);

CREATE TABLE Finanzas.MovimientoContable (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    NumeroAsiento VARCHAR(20) NOT NULL,
    FechaContable DATE NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    CuentaContable VARCHAR(50) NOT NULL,
    CentroCostoId INT NULL,
    MonedaCodigo CHAR(3) NOT NULL,
    Debe DECIMAL(18,4) NOT NULL,
    Haber DECIMAL(18,4) NOT NULL,
    TipoCambio DECIMAL(18,4) NOT NULL,
    DocumentoReferenciaId BIGINT NULL,
    OrigenModulo VARCHAR(50) NOT NULL,
    Glosa NVARCHAR(500) NULL,
    CONSTRAINT PK_MovimientoContable PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_MCont_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT FK_MCont_CC FOREIGN KEY (TenantId, CentroCostoId) REFERENCES Finanzas.CentroCosto(TenantId, Id),
    CONSTRAINT FK_MCont_Moneda FOREIGN KEY (MonedaCodigo) REFERENCES Transacciones.Moneda(MonedaCodigo),
    CONSTRAINT CK_MCont_Estado CHECK (Estado IN ('BORRADOR', 'CONTABILIZADO', 'ANULADO')),
    CONSTRAINT CK_MCont_DebeHaber CHECK (Debe > 0 OR Haber > 0)
);

-- 4. ÍNDICES DE ALTO RENDIMIENTO
-- ------------------------------------------------------------------------------------------

CREATE NONCLUSTERED INDEX IX_DocumentoHeader_Estado_Fecha 
ON Transacciones.DocumentoHeader (TenantId, EstadoDocumentoId, FechaEmision)
INCLUDE (TotalDocumento);

CREATE NONCLUSTERED INDEX IX_FormaPago_Orden 
ON Finanzas.FormaPago (TenantId, OrdenVisual);

CREATE NONCLUSTERED INDEX IX_Pago_Fecha 
ON Finanzas.Pago (TenantId, FechaPago);
GO