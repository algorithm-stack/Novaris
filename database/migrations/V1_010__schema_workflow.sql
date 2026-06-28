-- ==========================================================================================
-- NOVARIS ERP - SPRINT 10: WORKFLOW, ORQUESTACIÓN Y AUTOMATIZACIÓN (PRODUCTION READY)
-- ==========================================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='Workflow')
BEGIN
    EXEC('CREATE SCHEMA Workflow');
END
GO

-- 1. ENGINE DE WORKFLOW Y EJECUCIÓN
-- ------------------------------------------------------------------------------------------

CREATE TABLE Workflow.WorkflowDefinition (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Nombre VARCHAR(100) NOT NULL, 
    FechaRegistro DATETIME2 DEFAULT SYSDATETIME(), CreadoPor INT NOT NULL, Activo BIT DEFAULT 1,
    CONSTRAINT PK_WorkflowDef PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT UQ_WfDef_Nombre UNIQUE (TenantId, Nombre),
    CONSTRAINT FK_WfDef_Usuario FOREIGN KEY (TenantId, CreadoPor) REFERENCES Config.Usuario(TenantId, Id)
);

CREATE TABLE Workflow.WorkflowVersion (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, WorkflowDefinitionId BIGINT NOT NULL, VersionTag VARCHAR(20) NOT NULL,
    CONSTRAINT PK_WorkflowVer PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_WfVer_Def FOREIGN KEY (TenantId, WorkflowDefinitionId) REFERENCES Workflow.WorkflowDefinition(TenantId, Id)
);

CREATE TABLE Workflow.WorkflowInstance (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, WorkflowVersionId BIGINT NOT NULL, EntidadTipo VARCHAR(50), EntidadId BIGINT,
    CONSTRAINT PK_WorkflowInst PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_WfInst_Ver FOREIGN KEY (TenantId, WorkflowVersionId) REFERENCES Workflow.WorkflowVersion(TenantId, Id)
);

CREATE TABLE Workflow.WorkflowStepExecution (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, WorkflowInstanceId BIGINT NOT NULL, UsuarioId INT NOT NULL,
    Estado VARCHAR(20) CHECK(Estado IN ('PENDIENTE', 'EJECUTANDO', 'COMPLETADO', 'RECHAZADO', 'ERROR')), 
    Comentarios NVARCHAR(MAX), FechaRegistro DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_WfStepExec PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_WfSE_Inst FOREIGN KEY (TenantId, WorkflowInstanceId) REFERENCES Workflow.WorkflowInstance(TenantId, Id),
    CONSTRAINT FK_WfSE_Usuario FOREIGN KEY (TenantId, UsuarioId) REFERENCES Config.Usuario(TenantId, Id)
);

-- 2. EVENTOS, JOBS Y AUDITORÍA
-- ------------------------------------------------------------------------------------------

CREATE TABLE Workflow.EventLog (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, EventoNombre VARCHAR(100) NOT NULL, Payload NVARCHAR(MAX),
    Estado VARCHAR(20) DEFAULT 'PENDIENTE' CHECK(Estado IN ('PENDIENTE', 'PROCESADO', 'ERROR')),
    FechaRegistro DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EventLog PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE Workflow.JobQueue (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Payload NVARCHAR(MAX), Prioridad INT DEFAULT 1,
    Estado VARCHAR(20) DEFAULT 'PENDIENTE' CHECK(Estado IN ('PENDIENTE', 'PROCESANDO', 'FINALIZADO', 'ERROR')),
    Worker VARCHAR(50), DuracionMS BIGINT,
    CONSTRAINT PK_JobQueue PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE Workflow.AuditTrail (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Tabla VARCHAR(50) NOT NULL, RegistroId BIGINT NOT NULL, 
    Campo VARCHAR(50) NOT NULL, ValorAnterior NVARCHAR(MAX), ValorNuevo NVARCHAR(MAX), 
    UsuarioId INT NOT NULL, FechaRegistro DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_AuditTrail PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Audit_Usuario FOREIGN KEY (TenantId, UsuarioId) REFERENCES Config.Usuario(TenantId, Id)
);

-- 3. NOTIFICACIONES Y LOGS FUNCIONALES
-- ------------------------------------------------------------------------------------------

CREATE TABLE Workflow.NotificationTemplate (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Nombre VARCHAR(100) NOT NULL, BodyTemplate NVARCHAR(MAX) NOT NULL,
    CONSTRAINT PK_NotifTemplate PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT UQ_NotifTmpl_Nombre UNIQUE (TenantId, Nombre)
);

CREATE TABLE Workflow.Notification (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, TemplateId BIGINT NOT NULL, Estado VARCHAR(20) DEFAULT 'PENDIENTE',
    CONSTRAINT PK_Notif PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Notif_Tmpl FOREIGN KEY (TenantId, TemplateId) REFERENCES Workflow.NotificationTemplate(TenantId, Id)
);

CREATE TABLE Workflow.BusinessProcessLog (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, ProcesoNombre VARCHAR(100) NOT NULL, UsuarioId INT NOT NULL,
    Accion VARCHAR(50), FechaRegistro DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ProcLog PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_ProcLog_Usuario FOREIGN KEY (TenantId, UsuarioId) REFERENCES Config.Usuario(TenantId, Id)
);

-- 4. SCHEDULER
-- ------------------------------------------------------------------------------------------

CREATE TABLE Workflow.Scheduler (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, NombreTarea VARCHAR(100) NOT NULL, 
    Activo BIT DEFAULT 1, Estado VARCHAR(20) DEFAULT 'IDLE' CHECK(Estado IN ('IDLE', 'RUNNING', 'ERROR')),
    ProximaEjecucion DATETIME2 NOT NULL, UltimaEjecucion DATETIME2,
    CONSTRAINT PK_Scheduler PRIMARY KEY CLUSTERED (TenantId, Id)
);

-- 5. ÍNDICES DE ALTO RENDIMIENTO
-- ------------------------------------------------------------------------------------------

CREATE NONCLUSTERED INDEX IX_WorkflowInstance_Entidad ON Workflow.WorkflowInstance (TenantId, EntidadTipo, EntidadId);
CREATE NONCLUSTERED INDEX IX_AuditTrail_Tabla ON Workflow.AuditTrail (TenantId, Tabla, RegistroId);
CREATE NONCLUSTERED INDEX IX_Scheduler_Polling ON Workflow.Scheduler (TenantId, Activo, ProximaEjecucion);
CREATE NONCLUSTERED INDEX IX_EventLog_Estado ON Workflow.EventLog (TenantId, Estado);
GO