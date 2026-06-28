-- ==========================================================================================
-- NOVARIS ERP - SPRINT 5: MÓDULO CRM Y PERSONAS (VERSIÓN FINAL CONSOLIDADA)
-- ==========================================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='CRM')
BEGIN
    EXEC('CREATE SCHEMA CRM');
END
GO

-- 1. IDENTIDAD MAESTRA: PERSONA
-- ------------------------------------------------------------------------------------------

CREATE TABLE CRM.Persona (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    TipoPersona VARCHAR(10) NOT NULL, -- NATURAL, JURIDICA
    TipoDocumento VARCHAR(20) NOT NULL, -- DNI, RUC, CE, PASAPORTE, OTRO
    DocumentoIdentidad VARCHAR(20) NOT NULL,
    NombreComercial NVARCHAR(200) NOT NULL,
    PaginaWeb VARCHAR(255) NULL,
    FechaNacimiento DATE NULL,
    Genero VARCHAR(10) NULL, -- M, F, OTRO
    EstadoCivil VARCHAR(20) NULL,
    ActividadEconomica NVARCHAR(100) NULL,
    CorreoElectronico VARCHAR(150) NULL,
    Telefono VARCHAR(50) NULL,
    Observacion NVARCHAR(MAX) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CreadoPor INT NOT NULL,
    FechaActualizacion DATETIME2 NULL,
    ActualizadoPor INT NULL,
    CONSTRAINT PK_Persona PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Persona_Tenant FOREIGN KEY (TenantId) REFERENCES Config.Tenant(Id),
    CONSTRAINT CK_Persona_Tipo CHECK (TipoPersona IN ('NATURAL', 'JURIDICA')),
    CONSTRAINT CK_Persona_Doc CHECK (TipoDocumento IN ('DNI', 'RUC', 'CE', 'PASAPORTE', 'OTRO')),
    CONSTRAINT UQ_Persona_Doc UNIQUE (TenantId, DocumentoIdentidad)
);

CREATE TABLE CRM.Direccion (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    TipoDireccion VARCHAR(20) NOT NULL, -- FISCAL, ENTREGA, COBRANZA, SUCURSAL, OTRO
    EsPrincipal BIT NOT NULL DEFAULT 0,
    DireccionCompleta NVARCHAR(500) NOT NULL,
    UbigeoCodigo VARCHAR(10) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Direccion PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Direccion_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Direccion_Tipo CHECK (TipoDireccion IN ('FISCAL', 'ENTREGA', 'COBRANZA', 'SUCURSAL', 'OTRO'))
);

CREATE TABLE CRM.Contacto (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    NombreCompleto NVARCHAR(150) NOT NULL,
    Cargo NVARCHAR(100) NULL,
    CorreoElectronico VARCHAR(150) NULL,
    Telefono VARCHAR(50) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Contacto PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Contacto_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id)
);

-- 2. ESPECIALIZACIONES DE PERSONA
-- ------------------------------------------------------------------------------------------

CREATE TABLE CRM.Cliente (
    TenantId INT NOT NULL,
    PersonaId BIGINT NOT NULL,
    EstadoCliente VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    RiesgoCredito VARCHAR(20) NOT NULL DEFAULT 'BAJO',
    LimiteCredito DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    UltimaCompra DATETIME2 NULL,
    TotalCompras DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    FrecuenciaCompra INT NOT NULL DEFAULT 0,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Cliente PRIMARY KEY CLUSTERED (TenantId, PersonaId),
    CONSTRAINT FK_Cliente_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Cliente_Estado CHECK (EstadoCliente IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO'))
);

CREATE TABLE CRM.Proveedor (
    TenantId INT NOT NULL,
    PersonaId BIGINT NOT NULL,
    EstadoProveedor VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    Calificacion INT NOT NULL DEFAULT 5,
    PlazoPagoDias INT NOT NULL DEFAULT 30,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Proveedor PRIMARY KEY CLUSTERED (TenantId, PersonaId),
    CONSTRAINT FK_Proveedor_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Proveedor_Estado CHECK (EstadoProveedor IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO'))
);

CREATE TABLE CRM.Lead (
    TenantId INT NOT NULL,
    PersonaId BIGINT NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'NUEVO', 
    Origen VARCHAR(50) NOT NULL,
    ScoreConversion INT NOT NULL DEFAULT 0,
    ValorEsperado DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
    FechaIngreso DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FechaConversion DATETIME2 NULL,
    FechaUltimoContacto DATETIME2 NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Lead PRIMARY KEY CLUSTERED (TenantId, PersonaId),
    CONSTRAINT FK_Lead_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Lead_Estado CHECK (Estado IN ('NUEVO', 'CONTACTADO', 'CALIFICADO', 'CONVERTIDO', 'DESCARTADO'))
);

-- 3. GESTIÓN COMERCIAL E IA
-- ------------------------------------------------------------------------------------------

CREATE TABLE CRM.Oportunidad (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    LeadId BIGINT NULL,
    VendedorId INT NOT NULL,
    Titulo NVARCHAR(200) NOT NULL,
    Estado VARCHAR(20) NOT NULL,
    Probabilidad DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    ValorEsperado DECIMAL(18,4) NOT NULL,
    ValorPonderado AS (ValorEsperado * (Probabilidad / 100.0)) PERSISTED,
    FechaEstimadaCierre DATE NOT NULL,
    Competidor NVARCHAR(100) NULL,
    Observacion NVARCHAR(MAX) NULL,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FechaActualizacion DATETIME2 NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Oportunidad PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Oportunidad_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Oportunidad_Estado CHECK (Estado IN ('PROSPECCION', 'PROPUESTA', 'NEGOCIACION', 'GANADA', 'PERDIDA')),
    CONSTRAINT CK_Oportunidad_Probabilidad CHECK (Probabilidad BETWEEN 0 AND 100)
);

CREATE TABLE CRM.HistorialScoreIA (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    FechaCalculo DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    HealthScore INT NOT NULL,
    RiskScore INT NOT NULL,
    ChurnProbability DECIMAL(5,4) NOT NULL,
    CustomerLifetimeValue DECIMAL(18,4) NOT NULL,
    RFMScore VARCHAR(10) NOT NULL,
    ModeloIA VARCHAR(50) NOT NULL,
    VersionModelo VARCHAR(20) NOT NULL,
    CONSTRAINT PK_HistorialScoreIA PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_HSIA_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id)
);

-- 4. INTERACCIONES, MENSAJES Y TAGS
-- ------------------------------------------------------------------------------------------

CREATE TABLE CRM.Actividad (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    TipoActividad VARCHAR(20) NOT NULL,
    Prioridad VARCHAR(10) NOT NULL,
    Estado VARCHAR(20) NOT NULL,
    DuracionMinutos INT NULL,
    FechaActividad DATETIME2 NOT NULL,
    FechaSeguimiento DATETIME2 NULL,
    Resultado NVARCHAR(MAX) NULL,
    UsuarioResponsable INT NOT NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Actividad PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Actividad_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Actividad_Tipo CHECK (TipoActividad IN ('LLAMADA', 'EMAIL', 'VISITA', 'REUNION', 'WHATSAPP', 'SMS', 'TAREA')),
    CONSTRAINT CK_Actividad_Prioridad CHECK (Prioridad IN ('ALTA', 'MEDIA', 'BAJA'))
);

CREATE TABLE CRM.Mensaje (
    TenantId INT NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL,
    PersonaId BIGINT NOT NULL,
    TipoCanal VARCHAR(20) NOT NULL,
    Estado VARCHAR(20) NOT NULL,
    Contenido NVARCHAR(MAX) NOT NULL,
    FechaEnvio DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Mensaje PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Mensaje_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT CK_Mensaje_Canal CHECK (TipoCanal IN ('WHATSAPP', 'EMAIL', 'SMS', 'PUSH', 'TELEGRAM')),
    CONSTRAINT CK_Mensaje_Estado CHECK (Estado IN ('PENDIENTE', 'ENVIADO', 'LEIDO', 'ERROR'))
);

CREATE TABLE CRM.Segmento (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(255) NULL,
    ColorHex VARCHAR(7) NULL,
    CONSTRAINT PK_Segmento PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE CRM.PersonaSegmento (
    TenantId INT NOT NULL,
    PersonaId BIGINT NOT NULL,
    SegmentoId INT NOT NULL,
    CONSTRAINT PK_PersonaSegmento PRIMARY KEY CLUSTERED (TenantId, PersonaId, SegmentoId),
    CONSTRAINT FK_PS_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT FK_PS_Segmento FOREIGN KEY (TenantId, SegmentoId) REFERENCES CRM.Segmento(TenantId, Id)
);

CREATE TABLE CRM.Tag (
    TenantId INT NOT NULL,
    Id INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    ColorHex VARCHAR(7) NULL,
    CONSTRAINT PK_Tag PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE CRM.PersonaTag (
    TenantId INT NOT NULL,
    PersonaId BIGINT NOT NULL,
    TagId INT NOT NULL,
    CONSTRAINT PK_PersonaTag PRIMARY KEY CLUSTERED (TenantId, PersonaId, TagId),
    CONSTRAINT FK_PT_Persona FOREIGN KEY (TenantId, PersonaId) REFERENCES CRM.Persona(TenantId, Id),
    CONSTRAINT FK_PT_Tag FOREIGN KEY (TenantId, TagId) REFERENCES CRM.Tag(TenantId, Id)
);

-- 5. ÍNDICES DE ALTO RENDIMIENTO
-- ------------------------------------------------------------------------------------------

CREATE UNIQUE NONCLUSTERED INDEX UX_Persona_Correo ON CRM.Persona (TenantId, CorreoElectronico) WHERE CorreoElectronico IS NOT NULL;
CREATE UNIQUE NONCLUSTERED INDEX UX_Persona_Telefono ON CRM.Persona (TenantId, Telefono) WHERE Telefono IS NOT NULL;
CREATE NONCLUSTERED INDEX IX_Lead_Estado ON CRM.Lead (TenantId, Estado);
CREATE NONCLUSTERED INDEX IX_Lead_Score ON CRM.Lead (TenantId, ScoreConversion);
CREATE NONCLUSTERED INDEX IX_Cliente_Riesgo ON CRM.Cliente (TenantId, RiesgoCredito);
CREATE NONCLUSTERED INDEX IX_Oportunidad_Estado_Fecha ON CRM.Oportunidad (TenantId, Estado, FechaEstimadaCierre);
CREATE NONCLUSTERED INDEX IX_Oportunidad_Vendedor ON CRM.Oportunidad (TenantId, VendedorId);
CREATE NONCLUSTERED INDEX IX_Actividad_Persona_Fecha ON CRM.Actividad (TenantId, PersonaId, FechaActividad);
CREATE NONCLUSTERED INDEX IX_Mensaje_Persona_Canal ON CRM.Mensaje (TenantId, PersonaId, TipoCanal);
GO