-- =====================================================================
-- NOVARIS ERP - SPRINT 1
-- Archivo: V1_001__schema_config.sql
-- Descripción: Creación de esquemas base y entidades de configuración
-- =====================================================================

-- 1. Creación de Esquemas
CREATE SCHEMA [Config];
GO
CREATE SCHEMA [Catalog];
GO

-- 2. Entidad: Tenant (MYPE/Empresa)
CREATE TABLE [Config].[Tenant] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [NombreComercial] NVARCHAR(150) NOT NULL,
    [MetodoCosteo] VARCHAR(20) NOT NULL,
    [FechaRegistro] DATETIME2 NOT NULL CONSTRAINT DF_Tenant_FechaRegistro DEFAULT (SYSDATETIME()),
    [Activo] BIT NOT NULL CONSTRAINT DF_Tenant_Activo DEFAULT (1),
    
    CONSTRAINT [PK_Config_Tenant] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [CHK_Tenant_MetodoCosteo] CHECK ([MetodoCosteo] IN ('FIFO', 'PROMEDIO'))
);
GO

-- 3. Entidad: Usuario
CREATE TABLE [Config].[Usuario] (
    [Id] INT IDENTITY(1,1) NOT NULL,
    [TenantId] INT NOT NULL,
    [NombreCompleto] NVARCHAR(200) NOT NULL,
    [Email] VARCHAR(150) NOT NULL,
    [PasswordHash] VARCHAR(255) NOT NULL,
    [Rol] VARCHAR(50) NOT NULL,
    [Activo] BIT NOT NULL CONSTRAINT DF_Usuario_Activo DEFAULT (1),
    [UltimoAcceso] DATETIME2 NULL,
    [FechaCreacion] DATETIME2 NOT NULL CONSTRAINT DF_Usuario_FechaCreacion DEFAULT (SYSDATETIME()),
    
    CONSTRAINT [PK_Config_Usuario] PRIMARY KEY NONCLUSTERED ([Id]),
    CONSTRAINT [FK_Usuario_Tenant] FOREIGN KEY ([TenantId]) REFERENCES [Config].[Tenant]([Id])
);
GO

-- Índices para Config.Usuario
CREATE CLUSTERED INDEX [CX_Config_Usuario_Tenant] ON [Config].[Usuario]([TenantId], [Id]);
CREATE UNIQUE NONCLUSTERED INDEX [UQ_Config_Usuario_EmailTenant] ON [Config].[Usuario]([TenantId], [Email]);
GO