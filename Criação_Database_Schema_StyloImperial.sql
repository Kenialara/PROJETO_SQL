USE StyloImperial;
GO

/* ============================================================
   Limpeza do schema: drop em ordem de dependência (evita erro de FK)
   ============================================================ */
IF OBJECT_ID('dbo.Fato_Vendas', 'U')   IS NOT NULL DROP TABLE dbo.Fato_Vendas;
IF OBJECT_ID('dbo.Dim_Clientes', 'U')  IS NOT NULL DROP TABLE dbo.Dim_Clientes;
IF OBJECT_ID('dbo.Dim_Produtos', 'U')  IS NOT NULL DROP TABLE dbo.Dim_Produtos;
IF OBJECT_ID('dbo.Dim_Fretes', 'U')    IS NOT NULL DROP TABLE dbo.Dim_Fretes;
IF OBJECT_ID('dbo.Dim_Cidades', 'U')   IS NOT NULL DROP TABLE dbo.Dim_Cidades;
IF OBJECT_ID('dbo.Dim_Canal', 'U')     IS NOT NULL DROP TABLE dbo.Dim_Canal;
GO

/* ============================================================
   1) Dim_Canal: dimensão de canais de venda
   ============================================================ */
CREATE TABLE dbo.Dim_Canal (
    ID_CANAL    INT PRIMARY KEY,
    NM_CANAL    VARCHAR(50) NOT NULL
);
GO

/* ============================================================
   2) Dim_Cidades: dimensão geográfica (cidade/UF/país/região)
   ============================================================ */
CREATE TABLE dbo.Dim_Cidades (
    ID_CIDADE   INT PRIMARY KEY,
    NM_CIDADE   VARCHAR(150) NOT NULL,
    UF          VARCHAR(2)   NOT NULL,
    PAIS        VARCHAR(50)  NOT NULL,
    REGIAO      VARCHAR(25)  NOT NULL
);
GO

/* ============================================================
   3) Dim_Clientes: cadastro de clientes, vinculada à cidade
   ============================================================ */
CREATE TABLE dbo.Dim_Clientes (
    ID_CLI      INT PRIMARY KEY,
    TP_PESSOA   VARCHAR(11),
    CPF_CNPJ    VARCHAR(14) NOT NULL,
    NM_CLI      VARCHAR(500) NOT NULL,
    ENDERECO    VARCHAR(500),
    ID_CIDADE   INT NOT NULL,
    DT_NASC     DATE,
    RENDA       DECIMAL(10,2),
    DESC_GEN    VARCHAR(15),
    EMAIL       VARCHAR(45) NOT NULL,
    CONTATO     VARCHAR(30),
    DT_CAD      DATE NOT NULL,
    DT_ATUAL    DATE NOT NULL,
    FOREIGN KEY (ID_CIDADE) REFERENCES dbo.Dim_Cidades(ID_CIDADE)
);
GO

/* ============================================================
   4) Dim_Fretes: atributos de transporte/frete
   ============================================================ */
CREATE TABLE dbo.Dim_Fretes (
    ID_FRETE        INT PRIMARY KEY,
    DISTANCIA_KM    DECIMAL(10,2),
    VLR_KM_ROD      DECIMAL(10,2),
    MOTORISTA       VARCHAR(150) NOT NULL
);
GO

/* ============================================================
   5) Dim_Produtos: catálogo de produtos (nome, categoria, custo)
   ============================================================ */
CREATE TABLE dbo.Dim_Produtos (
    ID_PROD     INT PRIMARY KEY,
    NM_PROD     VARCHAR(150) NOT NULL,
    CATG_PROD   VARCHAR(50),
    VLR_CUSTO   DECIMAL(10,2)
);
GO

/* ============================================================
   6) Fato_Vendas: granularidade item de pedido/nota; medidas e FKs
   ============================================================ */
CREATE TABLE dbo.Fato_Vendas (
    ID_VENDA    INT IDENTITY(1,1) PRIMARY KEY,
    ID_FRETE    INT NULL,
    NUM_PEDIDO  VARCHAR(100) NOT NULL,
    NUM_NOTA    VARCHAR(100) NOT NULL,
    ID_CLI      INT NOT NULL,
    DT_PEDIDO   DATE NOT NULL,
    DT_CANCEL   DATE NULL,
    DT_NOTA     DATE NOT NULL,
    ID_PROD     INT NOT NULL,
    QTD_PROD    INT NOT NULL,
    VLR_UNIT    DECIMAL(10,2) NOT NULL,
    VLR_DESC    DECIMAL(10,2) NOT NULL,
    VLR_FRETE   DECIMAL(10,2) NOT NULL,
    VLR_TOTAL   DECIMAL(10,2) NOT NULL,
    FORMA_PG    VARCHAR(15),
    STATUS      VARCHAR(20),
    ID_CANAL    INT NOT NULL,
    DT_ENTREGA  DATE NOT NULL,
    FOREIGN KEY (ID_FRETE) REFERENCES dbo.Dim_Fretes(ID_FRETE),
    FOREIGN KEY (ID_CLI)   REFERENCES dbo.Dim_Clientes(ID_CLI),
    FOREIGN KEY (ID_PROD)  REFERENCES dbo.Dim_Produtos(ID_PROD),
    FOREIGN KEY (ID_CANAL) REFERENCES dbo.Dim_Canal(ID_CANAL)
);
GO
