-- ==========================================================================================
-- NOVARIS ERP - V1_008__schema_sales.sql (VERSION FINAL CONSOLIDADA)
-- ==========================================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='Ventas')
BEGIN
    EXEC('CREATE SCHEMA Ventas');
END
GO

-- 1. COTIZACIONES Y PEDIDOS
-- ------------------------------------------------------------------------------------------

CREATE TABLE Ventas.CotizacionVenta (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, DocumentoHeaderId BIGINT NOT NULL, ClienteId BIGINT NOT NULL, VendedorId INT NOT NULL, 
    Estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR' CHECK(Estado IN ('BORRADOR', 'ENVIADA', 'APROBADA', 'RECHAZADA', 'VENCIDA')), 
    Total DECIMAL(18,4) NOT NULL CHECK(Total >= 0),
    CONSTRAINT PK_CotizacionVenta PRIMARY KEY CLUSTERED (TenantId, Id), 
    CONSTRAINT FK_CotV_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id), 
    CONSTRAINT FK_CotV_Cli FOREIGN KEY (TenantId, ClienteId) REFERENCES CRM.Cliente(TenantId, PersonaId)
);

CREATE TABLE Ventas.CotizacionVentaDetalle (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, CotizacionVentaId BIGINT NOT NULL, ProductoId BIGINT NOT NULL, 
    Cantidad DECIMAL(18,4) NOT NULL CHECK(Cantidad > 0), PrecioUnitario DECIMAL(18,4) NOT NULL CHECK(PrecioUnitario >= 0), Descuento DECIMAL(18,4) DEFAULT 0 CHECK(Descuento >= 0),
    CONSTRAINT PK_CotizacionVentaDetalle PRIMARY KEY CLUSTERED (TenantId, Id), 
    CONSTRAINT FK_CotVD_Header FOREIGN KEY (TenantId, CotizacionVentaId) REFERENCES Ventas.CotizacionVenta(TenantId, Id),
    CONSTRAINT FK_CotVD_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id)
);

CREATE TABLE Ventas.PedidoVenta (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, DocumentoHeaderId BIGINT NOT NULL, ClienteId BIGINT NOT NULL, 
    Estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK(Estado IN ('PENDIENTE', 'RESERVADO', 'EN_PROCESO', 'COMPLETADO', 'ANULADO')), 
    Total DECIMAL(18,4) NOT NULL CHECK(Total >= 0),
    CONSTRAINT PK_PedidoVenta PRIMARY KEY CLUSTERED (TenantId, Id), 
    CONSTRAINT FK_PedV_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id)
);

CREATE TABLE Ventas.ReservaVenta (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PedidoVentaId BIGINT NOT NULL, ProductoId BIGINT NOT NULL, 
    Cantidad DECIMAL(18,4) NOT NULL CHECK(Cantidad > 0), Estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK(Estado IN ('ACTIVA', 'LIBERADA', 'CANCELADA')),
    CONSTRAINT PK_ReservaVenta PRIMARY KEY CLUSTERED (TenantId, Id), 
    CONSTRAINT FK_ResV_Ped FOREIGN KEY (TenantId, PedidoVentaId) REFERENCES Ventas.PedidoVenta(TenantId, Id),
    CONSTRAINT FK_ResV_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id)
);

-- 2. LOGÍSTICA: PICKING, PACKING, DESPACHO Y ENTREGA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Ventas.Picking (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PedidoVentaId BIGINT NOT NULL, 
    Estado VARCHAR(20) DEFAULT 'PENDIENTE' CHECK(Estado IN ('PENDIENTE', 'EN_PROCESO', 'COMPLETADO')),
    CONSTRAINT PK_Picking PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_Pick_Ped FOREIGN KEY (TenantId, PedidoVentaId) REFERENCES Ventas.PedidoVenta(TenantId, Id)
);

CREATE TABLE Ventas.PickingDetalle (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PickingId BIGINT NOT NULL, ProductoId BIGINT NOT NULL, LoteId BIGINT NOT NULL, 
    Cantidad DECIMAL(18,4) NOT NULL CHECK(Cantidad > 0), Ubicacion VARCHAR(50) NULL,
    CONSTRAINT PK_PickingDetalle PRIMARY KEY CLUSTERED (TenantId, Id), 
    CONSTRAINT FK_PickD_Pick FOREIGN KEY (TenantId, PickingId) REFERENCES Ventas.Picking(TenantId, Id),
    CONSTRAINT FK_PickD_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id),
    CONSTRAINT FK_PickD_Lote FOREIGN KEY (TenantId, LoteId) REFERENCES Operaciones.Lote(TenantId, Id)
);

CREATE TABLE Ventas.Packing (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PickingId BIGINT NOT NULL, PesoTotal DECIMAL(18,4) DEFAULT 0 CHECK(PesoTotal >= 0),
    Estado VARCHAR(20) DEFAULT 'PENDIENTE' CHECK(Estado IN ('PENDIENTE', 'COMPLETADO')),
    CONSTRAINT PK_Packing PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_Pack_Pick FOREIGN KEY (TenantId, PickingId) REFERENCES Ventas.Picking(TenantId, Id)
);

CREATE TABLE Ventas.PackingDetalle (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PackingId BIGINT NOT NULL, ProductoId BIGINT NOT NULL, Cantidad DECIMAL(18,4) NOT NULL CHECK(Cantidad > 0),
    CONSTRAINT PK_PackingDetalle PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_PackD_Pack FOREIGN KEY (TenantId, PackingId) REFERENCES Ventas.Packing(TenantId, Id),
    CONSTRAINT FK_PackD_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id)
);

CREATE TABLE Ventas.Despacho (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PackingId BIGINT NOT NULL, GuiaRemision VARCHAR(50) NOT NULL, 
    Estado VARCHAR(20) DEFAULT 'EMITIDO' CHECK(Estado IN ('EMITIDO', 'EN_TRANSITO', 'ENTREGADO')),
    CONSTRAINT PK_Despacho PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_Desp_Pack FOREIGN KEY (TenantId, PackingId) REFERENCES Ventas.Packing(TenantId, Id)
);

CREATE TABLE Ventas.EntregaCliente (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, DespachoId BIGINT NOT NULL, FechaEntrega DATETIME2 NOT NULL, RecibidoPor NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_EntregaCliente PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_Ent_Desp FOREIGN KEY (TenantId, DespachoId) REFERENCES Ventas.Despacho(TenantId, Id)
);

-- 3. FACTURACIÓN Y COBRANZA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Ventas.FacturaVenta (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, DocumentoHeaderId BIGINT NOT NULL, PedidoVentaId BIGINT NOT NULL, Total DECIMAL(18,4) NOT NULL CHECK(Total >= 0),
    CONSTRAINT PK_FacturaVenta PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_FactV_Header FOREIGN KEY (TenantId, DocumentoHeaderId) REFERENCES Transacciones.DocumentoHeader(TenantId, Id)
);

CREATE TABLE Ventas.FacturaVentaDetalle (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, FacturaVentaId BIGINT NOT NULL, ProductoId BIGINT NOT NULL, 
    Cantidad DECIMAL(18,4) NOT NULL CHECK(Cantidad > 0), PrecioUnitario DECIMAL(18,4) NOT NULL CHECK(PrecioUnitario >= 0),
    CONSTRAINT PK_FacturaVentaDetalle PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_FactVD_Fact FOREIGN KEY (TenantId, FacturaVentaId) REFERENCES Ventas.FacturaVenta(TenantId, Id),
    CONSTRAINT FK_FactVD_Prod FOREIGN KEY (TenantId, ProductoId) REFERENCES Catalog.Producto(TenantId, Id)
);

CREATE TABLE Ventas.CobranzaVenta (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, FacturaVentaId BIGINT NOT NULL, MontoTotal DECIMAL(18,4) NOT NULL CHECK(MontoTotal > 0),
    CONSTRAINT PK_CobranzaVenta PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_CobV_Fact FOREIGN KEY (TenantId, FacturaVentaId) REFERENCES Ventas.FacturaVenta(TenantId, Id)
);

CREATE TABLE Ventas.CobranzaVentaDetalle (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, CobranzaVentaId BIGINT NOT NULL, MontoPagado DECIMAL(18,4) NOT NULL CHECK(MontoPagado > 0), MetodoPago VARCHAR(20) NOT NULL,
    CONSTRAINT PK_CobranzaVentaDetalle PRIMARY KEY CLUSTERED (TenantId, Id), CONSTRAINT FK_CobVD_Cob FOREIGN KEY (TenantId, CobranzaVentaId) REFERENCES Ventas.CobranzaVenta(TenantId, Id)
);

-- 4. IA Y ANALÍTICA (CAMPOS PARA MODELOS PREDICTIVOS)
-- ------------------------------------------------------------------------------------------

CREATE TABLE Ventas.VendedorScoreHistorico (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, VendedorId INT NOT NULL, FechaCalculo DATETIME2 NOT NULL, 
    ScoreIA DECIMAL(5,2) NOT NULL, OTIF DECIMAL(5,2) NOT NULL, FillRate DECIMAL(5,2) NOT NULL, 
    TicketPromedio DECIMAL(18,4) NOT NULL, MargenPromedio DECIMAL(5,2) NOT NULL, Cancelaciones INT NOT NULL,
    CONSTRAINT PK_VendedorScore PRIMARY KEY CLUSTERED (TenantId, Id)
);

-- 5. ÍNDICES ESTRATÉGICOS
-- ------------------------------------------------------------------------------------------

CREATE NONCLUSTERED INDEX IX_Pedido_Cliente ON Ventas.PedidoVenta (TenantId, ClienteId);
CREATE NONCLUSTERED INDEX IX_Factura_DocHeader ON Ventas.FacturaVenta (TenantId, DocumentoHeaderId);
CREATE NONCLUSTERED INDEX IX_Reserva_Producto ON Ventas.ReservaVenta (TenantId, ProductoId);
CREATE NONCLUSTERED INDEX IX_Picking_Producto ON Ventas.PickingDetalle (TenantId, ProductoId);
CREATE NONCLUSTERED INDEX IX_Despacho_Guia ON Ventas.Despacho (TenantId, GuiaRemision);
GO