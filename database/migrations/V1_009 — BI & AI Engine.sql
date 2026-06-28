-- ==========================================================================================
-- NOVARIS ERP - SPRINT 9: BI & AI ENGINE (MASTER ENTERPRISE SCHEMA)
-- ==========================================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='BI')
BEGIN
    EXEC('CREATE SCHEMA BI');
END
GO

-- 1. MLOPS & GOBIERNO DE MODELOS
-- ------------------------------------------------------------------------------------------

CREATE TABLE BI.AIModel (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Nombre VARCHAR(100) NOT NULL, Tipo VARCHAR(50) NOT NULL, Activo BIT DEFAULT 1,
    CONSTRAINT PK_AIModel PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE BI.AIModelVersion (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, AIModelId BIGINT NOT NULL, VersionTag VARCHAR(20) NOT NULL,
    CONSTRAINT PK_AIModelVersion PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_ModVer_Mod FOREIGN KEY (TenantId, AIModelId) REFERENCES BI.AIModel(TenantId, Id)
);

CREATE TABLE BI.DatasetRegistry (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Nombre VARCHAR(100) NOT NULL, VersionDatos VARCHAR(20) NOT NULL, QueryOrigen NVARCHAR(MAX) NOT NULL,
    CONSTRAINT PK_DatasetRegistry PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE BI.ModelTraining (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, AIModelVersionId BIGINT NOT NULL, DatasetId BIGINT NOT NULL,
    TrainingStart DATETIME2 NOT NULL, TrainingEnd DATETIME2, DurationMS BIGINT,
    CONSTRAINT PK_ModelTraining PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Train_Ver FOREIGN KEY (TenantId, AIModelVersionId) REFERENCES BI.AIModelVersion(TenantId, Id),
    CONSTRAINT FK_Train_Data FOREIGN KEY (TenantId, DatasetId) REFERENCES BI.DatasetRegistry(TenantId, Id)
);

CREATE TABLE BI.ModelMetrics (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, ModelTrainingId BIGINT NOT NULL,
    MetricaNombre VARCHAR(50) NOT NULL, Valor DECIMAL(18,6) NOT NULL, FechaCalculo DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ModelMetrics PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Met_Train FOREIGN KEY (TenantId, ModelTrainingId) REFERENCES BI.ModelTraining(TenantId, Id)
);

-- 2. FEATURE STORE & INTERFAZ DE INFERENCIA
-- ------------------------------------------------------------------------------------------

CREATE TABLE BI.FeatureDefinition (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Nombre VARCHAR(100) NOT NULL, Descripcion NVARCHAR(255), TipoDato VARCHAR(20),
    CONSTRAINT PK_FeatureDefinition PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE BI.FeatureStore (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, FeatureDefinitionId BIGINT NOT NULL, EntidadTipo VARCHAR(50) NOT NULL, EntidadId BIGINT NOT NULL, FeatureValor FLOAT NOT NULL, FechaCalculo DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_FeatureStore PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_FeatStore_Def FOREIGN KEY (TenantId, FeatureDefinitionId) REFERENCES BI.FeatureDefinition(TenantId, Id)
);

CREATE TABLE BI.FeatureImportance (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, AIModelVersionId BIGINT NOT NULL, FeatureDefinitionId BIGINT NOT NULL, ScoreImportance DECIMAL(5,4),
    CONSTRAINT PK_FeatureImportance PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_FeatImp_Ver FOREIGN KEY (TenantId, AIModelVersionId) REFERENCES BI.AIModelVersion(TenantId, Id),
    CONSTRAINT FK_FeatImp_Feat FOREIGN KEY (TenantId, FeatureDefinitionId) REFERENCES BI.FeatureDefinition(TenantId, Id)
);

CREATE TABLE BI.Prediction (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, AIModelVersionId BIGINT NOT NULL, 
    EntidadTipo VARCHAR(50) NOT NULL, EntidadId BIGINT NOT NULL, ValorPredicho FLOAT NOT NULL, Confianza DECIMAL(5,4), FechaPrediccion DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Prediction PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Pred_Ver FOREIGN KEY (TenantId, AIModelVersionId) REFERENCES BI.AIModelVersion(TenantId, Id)
);

CREATE TABLE BI.AIInferenceLog (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, PredictionId BIGINT NOT NULL, UsuarioId INT, InputData NVARCHAR(MAX), OutputData NVARCHAR(MAX), LatenciaMS BIGINT,
    CONSTRAINT PK_AIInferenceLog PRIMARY KEY CLUSTERED (TenantId, Id),
    CONSTRAINT FK_Log_Pred FOREIGN KEY (TenantId, PredictionId) REFERENCES BI.Prediction(TenantId, Id)
);

-- 3. AUTOMATIZACIÓN, ALERTAS Y CONTROL
-- ------------------------------------------------------------------------------------------

CREATE TABLE BI.SmartAlert (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, Severidad VARCHAR(20), Estado VARCHAR(20) DEFAULT 'ABIERTA' CHECK(Estado IN ('ABIERTA', 'EN_PROCESO', 'RESUELTA', 'DESCARTADA')), 
    EntidadTipo VARCHAR(50), EntidadId BIGINT, Mensaje NVARCHAR(MAX),
    CONSTRAINT PK_SmartAlert PRIMARY KEY CLUSTERED (TenantId, Id)
);

CREATE TABLE BI.Scheduler (
    TenantId INT NOT NULL, Id BIGINT IDENTITY(1,1) NOT NULL, NombreTarea VARCHAR(100) NOT NULL, FrecuenciaCron VARCHAR(50), 
    Activo BIT DEFAULT 1, Estado VARCHAR(20), UltimoResultado NVARCHAR(MAX), Intentos INT DEFAULT 0, ProximaEjecucion DATETIME2,
    CONSTRAINT PK_Scheduler PRIMARY KEY CLUSTERED (TenantId, Id)
);

-- 4. ÍNDICES ESTRATÉGICOS (FORTUNE 500 PERFORMANCE)
-- ------------------------------------------------------------------------------------------

CREATE NONCLUSTERED INDEX IX_Prediction_Entidad ON BI.Prediction (TenantId, EntidadTipo, EntidadId);
CREATE NONCLUSTERED INDEX IX_AIInferenceLog_Prediction ON BI.AIInferenceLog (TenantId, PredictionId);
CREATE NONCLUSTERED INDEX IX_FeatStore_Entidad ON BI.FeatureStore (TenantId, EntidadTipo, EntidadId);
CREATE NONCLUSTERED INDEX IX_ModelMetrics_Training ON BI.ModelMetrics (TenantId, ModelTrainingId);
CREATE NONCLUSTERED INDEX IX_Scheduler_Ultima ON BI.Scheduler (TenantId, Id); -- Optimizado para el polling del worker
GO