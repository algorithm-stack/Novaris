-- =====================================================================
-- NOVARIS ERP - SPRINT 1
-- Archivo: V1_002__schema_catalog.sql
-- Descripción: Creación de entidades del Catálogo de Operaciones
-- =====================================================================

-- 1. Entidad: Categoria
CREATE TABLE [Catalog].[Categoria] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Categoria_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Catalog_Categoria] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Categoria_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id])
);
CREATE CLUSTERED INDEX [CX_Catalog_Categoria_Tenant] ON [Catalog].[Categoria]([TenantId], [Id]);
GO

-- 2. Entidad: Marca
CREATE TABLE [Catalog].[Marca] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Marca_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Catalog_Marca] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Marca_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id])
);
CREATE CLUSTERED INDEX [CX_Catalog_Marca_Tenant] ON [Catalog].[Marca]([TenantId], [Id]);
GO

-- 3. Entidad: UnidadMedida
CREATE TABLE [Catalog].[UnidadMedida] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [Codigo] VARCHAR(10) NOT NULL,
    [Nombre] NVARCHAR(50) NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_UnidadMedida_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Catalog_UnidadMedida] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_UnidadMedida_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id])
);
CREATE CLUSTERED INDEX [CX_Catalog_UnidadMedida_Tenant] ON [Catalog].[UnidadMedida]([TenantId], [Id]);
GO

-- 4. Entidad: Impuesto
CREATE TABLE [Catalog].[Impuesto] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Tasa] DECIMAL(5,2) NOT NULL,
    [Tipo] VARCHAR(20) NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Impuesto_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Catalog_Impuesto] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Impuesto_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id]),
    CONSTRAINT [CHK_Impuesto_Tipo] CHECK ([Tipo] IN ('IGV', 'EXONERADO', 'INAFECTO', 'OTRO'))
);
CREATE CLUSTERED INDEX [CX_Catalog_Impuesto_Tenant] ON [Catalog].[Impuesto]([TenantId], [Id]);
GO

-- 5. Entidad: Almacen
CREATE TABLE [Catalog].[Almacen] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Ubicacion] NVARCHAR(255) NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Almacen_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Catalog_Almacen] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Almacen_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id])
);
CREATE CLUSTERED INDEX [CX_Catalog_Almacen_Tenant] ON [Catalog].[Almacen]([TenantId], [Id]);
GO

-- 6. Entidad: Producto
CREATE TABLE [Catalog].[Producto] (
    [Id] BIGINT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [SKU] VARCHAR(50) NOT NULL,
    [CodigoBarras] VARCHAR(50) NULL,
    [CodigoInterno] VARCHAR(50) NULL,
    [Nombre] NVARCHAR(200) NOT NULL,
    [Descripcion] NVARCHAR(500) NULL,
    [TipoProducto] VARCHAR(30) NOT NULL,
    [CategoriaId] INT NULL,
    [MarcaId] INT NULL,
    [UnidadMedidaId] INT NOT NULL,
    [ImpuestoId] INT NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT (1),
    [FechaCreacion] DATETIME2 NOT NULL CONSTRAINT DF_Producto_FechaCreacion DEFAULT (SYSDATETIME()),
    [FechaActualizacion] DATETIME2 NOT NULL CONSTRAINT DF_Producto_FechaActualizacion DEFAULT (SYSDATETIME()),
    
    CONSTRAINT [PK_Catalog_Producto] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Producto_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id]),
    CONSTRAINT [FK_Producto_Categoria] FOREIGN KEY ([CategoriaId]) REFERENCES [Catalog].[Categoria]([Id]),
    CONSTRAINT [FK_Producto_Marca] FOREIGN KEY ([MarcaId]) REFERENCES [Catalog].[Marca]([Id]),
    CONSTRAINT [FK_Producto_UnidadMedida] FOREIGN KEY ([UnidadMedidaId]) REFERENCES [Catalog].[UnidadMedida]([Id]),
    CONSTRAINT [FK_Producto_Impuesto] FOREIGN KEY ([ImpuestoId]) REFERENCES [Catalog].[Impuesto]([Id]),
    CONSTRAINT [CHK_Producto_Tipo] CHECK ([TipoProducto] IN ('PERECIBLE', 'NO_PERECIBLE', 'SERVICIO', 'MATERIA_PRIMA'))
);
GO

-- Índices Críticos para Catalog.Producto
-- Agrupa físicamente los productos por empresa para escaneos de inventario ultrarrápidos
CREATE CLUSTERED INDEX [CX_Catalog_Producto_Tenant] ON [Catalog].[Producto]([TenantId], [Id]);

-- Acelera la búsqueda de productos en el Punto de Venta (POS) al escanear códigos
CREATE NONCLUSTERED INDEX [IX_Catalog_Producto_SKU] ON [Catalog].[Producto]([TenantId], [SKU]);
CREATE NONCLUSTERED INDEX [IX_Catalog_Producto_Codigos] ON [Catalog].[Producto]([TenantId], [CodigoBarras], [CodigoInterno]);
GO