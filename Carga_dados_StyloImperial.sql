/* ============================================================
   Sessão e transação: evitar contagens intermediárias e abortar em erro
   ============================================================ */
USE StyloImperial;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

/* ============================================================
   Limpeza segura: DELETE em ordem de dependência para resetar dados
   ============================================================ */
IF OBJECT_ID('dbo.Fato_Vendas','U')   IS NOT NULL DELETE FROM dbo.Fato_Vendas;
IF OBJECT_ID('dbo.Dim_Clientes','U')  IS NOT NULL DELETE FROM dbo.Dim_Clientes;
IF OBJECT_ID('dbo.Dim_Produtos','U')  IS NOT NULL DELETE FROM dbo.Dim_Produtos;
IF OBJECT_ID('dbo.Dim_Fretes','U')    IS NOT NULL DELETE FROM dbo.Dim_Fretes;
IF OBJECT_ID('dbo.Dim_Cidades','U')   IS NOT NULL DELETE FROM dbo.Dim_Cidades;
IF OBJECT_ID('dbo.Dim_Canal','U')     IS NOT NULL DELETE FROM dbo.Dim_Canal;

/* ============================================================
   Dim_Canal: carga mínima de referência
   ============================================================ */
INSERT INTO dbo.Dim_Canal (ID_CANAL, NM_CANAL)
VALUES (1,'PRESENCIAL'), (2,'ONLINE');

/* ============================================================
   Dim_Cidades: amostra de 10 cidades (região de Uberlândia)
   ============================================================ */
INSERT INTO dbo.Dim_Cidades (ID_CIDADE, NM_CIDADE, UF, PAIS, REGIAO)
VALUES
(1,'UBERLANDIA','MG','BRASIL','TRIANGULO-MINEIRO'),
(2,'ARAGUARI','MG','BRASIL','TRIANGULO-MINEIRO'),
(3,'UBERABA','MG','BRASIL','TRIANGULO-MINEIRO'),
(4,'ARAPORA','MG','BRASIL','TRIANGULO-MINEIRO'),
(5,'MONTE CARMELO','MG','BRASIL','TRIANGULO-MINEIRO'),
(6,'PATROCINIO','MG','BRASIL','TRIANGULO-MINEIRO'),
(7,'INDIANOPOLIS','MG','BRASIL','TRIANGULO-MINEIRO'),
(8,'TUPACIGUARA','MG','BRASIL','TRIANGULO-MINEIRO'),
(9,'ARAXA','MG','BRASIL','ALTO PARANAIBA'),
(10,'ITUIUTABA','MG','BRASIL','TRIANGULO-MINEIRO');

/* ============================================================
   Dim_Produtos: 25 itens sintéticos com categorias e custo
   ============================================================ */
;WITH nP AS (
  SELECT TOP (25) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  FROM sys.all_objects
)
INSERT INTO dbo.Dim_Produtos (ID_PROD, NM_PROD, CATG_PROD, VLR_CUSTO)
SELECT
  rn,
  CONCAT('PRODUTO ', rn),
  CASE ((rn-1) % 9)
    WHEN 0 THEN 'SOFÁ'
    WHEN 1 THEN 'CAMA'
    WHEN 2 THEN 'MESA'
    WHEN 3 THEN 'CADEIRA'
    WHEN 4 THEN 'ESTANTE'
    WHEN 5 THEN 'ARMÁRIO'
    WHEN 6 THEN 'CRISTALEIRA'
    WHEN 7 THEN 'APARADOR'
    ELSE 'BALANCO'
  END,
  CAST(ROUND(150 + ((rn*137) % 4500) + ((rn%7)*9.75), 2) AS DECIMAL(10,2))
FROM nP;

/* ============================================================
   Dim_Clientes: 350 registros com distribuição controlada (cidade/TP pessoa/faixa etária/gênero/renda)
   ============================================================ */
DECLARE @hoje DATE = '2025-08-31';

;WITH nC AS (
  SELECT TOP (350)
         ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  FROM sys.all_objects
),
S AS (
  SELECT 
    nc.rn,
    CASE WHEN nc.rn % 5 = 0 THEN 'JURIDICA' ELSE 'FISICA' END AS TP_PESSOA,
    CASE WHEN nc.rn <= 228 THEN 1 ELSE 2 + ((nc.rn-229) % 9) END AS ID_CIDADE_ALVO,
    ABS(CHECKSUM(nc.rn))        AS seed,
    ABS(CHECKSUM(nc.rn,'rng1')) AS seed1,
    ABS(CHECKSUM(nc.rn,'rng2')) AS seed2
  FROM nC nc
)
INSERT INTO dbo.Dim_Clientes
(ID_CLI, TP_PESSOA, CPF_CNPJ, NM_CLI, ENDERECO, ID_CIDADE, DT_NASC, RENDA, DESC_GEN, EMAIL, CONTATO, DT_CAD, DT_ATUAL)
SELECT
  s.rn,
  s.TP_PESSOA,
  CASE WHEN s.TP_PESSOA = 'JURIDICA'
       THEN '10' + RIGHT('000000000000' + CONVERT(VARCHAR(12), (s.rn*6673) % 1000000000000), 12)
       ELSE RIGHT('00000000000' + CONVERT(VARCHAR(11), (s.rn*7919) % 100000000000), 11)
  END,
  CASE WHEN s.TP_PESSOA = 'JURIDICA' THEN CONCAT('EMPRESA ', s.rn) ELSE CONCAT('CLIENTE ', s.rn) END,
  CONCAT('RUA ', (s.rn*13)%999, ', ', 10 + (s.rn%200)),
  s.ID_CIDADE_ALVO,
  CASE 
    WHEN s.TP_PESSOA = 'JURIDICA' THEN NULL
    ELSE
      DATEFROMPARTS(
        YEAR(@hoje) -
          CASE 
            WHEN (s.seed % 100) < 13 THEN (18 + (s.seed1 % 7))
            WHEN (s.seed % 100) < 39 THEN (25 + (s.seed1 % 10))
            WHEN (s.seed % 100) < 65 THEN (35 + (s.seed1 % 10))
            WHEN (s.seed % 100) < 82 THEN (45 + (s.seed1 % 10))
            WHEN (s.seed % 100) < 95 THEN (55 + (s.seed1 % 10))
            ELSE                    (65 + (s.seed1 % 16))
          END,
        ((s.seed2 % 12) + 1),
        ((s.seed2 % 28) + 1)
      )
  END,
  CASE WHEN s.TP_PESSOA = 'JURIDICA' THEN NULL
       ELSE CAST(ROUND(1800 + ((s.rn*37)%15000) + ((s.rn%9)*111.11), 2) AS DECIMAL(10,2))
  END,
  CASE WHEN s.TP_PESSOA = 'JURIDICA' THEN NULL
       ELSE CASE WHEN s.seed % 100 < 52 THEN 'MASC' ELSE 'FEM' END
  END,
  LOWER(CONCAT(CASE WHEN s.TP_PESSOA = 'JURIDICA' THEN 'empresa' ELSE 'cliente' END, s.rn, '@exemplo.com')),
  '34' + RIGHT('999000000' + CONVERT(VARCHAR(9), 100000 + (s.rn*777)), 9),
  DATEADD(DAY, -((s.rn*5)%180), @hoje),
  @hoje
FROM S s;

/* ============================================================
   Dim_Fretes: 550 registros sintéticos; variabilidade de distância/valor e 3 motoristas
   ============================================================ */
;WITH nF AS (
  SELECT TOP (550) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  FROM sys.all_objects
)
INSERT INTO dbo.Dim_Fretes (ID_FRETE, DISTANCIA_KM, VLR_KM_ROD, MOTORISTA)
SELECT
  rn,
  CAST(10 + ((rn*9) % 350) AS DECIMAL(10,2)),
  CAST(1.50 + ((rn % 8) * 0.45) AS DECIMAL(10,2)),
  CASE (rn % 3) WHEN 0 THEN 'ANTONIO' WHEN 1 THEN 'MARCELO' ELSE 'ROBERTO' END
FROM nF;

/* ============================================================
   Ajuste estrutural: permitir DT_ENTREGA nula (itens cancelados)
   ============================================================ */
IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Fato_Vendas')
      AND name = 'DT_ENTREGA'
      AND is_nullable = 0
)
BEGIN
    ALTER TABLE dbo.Fato_Vendas
      ALTER COLUMN DT_ENTREGA DATE NULL;
END;

/* ============================================================
   Fato_Vendas: 1000 linhas sintéticas com regras de negócio, distribuição de canal, status venda, calculo de frete e precificação
   ============================================================ */
DECLARE @startDate DATE = '2023-01-01';
DECLARE @endDate   DATE = '2025-08-31';
DECLARE @days INT = DATEDIFF(DAY, @startDate, @endDate) + 1;

;WITH nums AS (
  SELECT 1 AS rn
  UNION ALL
  SELECT rn + 1 FROM nums WHERE rn < 1000
),
base AS (
  SELECT
    rn,
    CASE WHEN rn <= 200 THEN 2 ELSE 1 END AS ID_CANAL,
    CASE WHEN rn % 10 = 0 THEN 'CANCELADA' ELSE 'CONFIRMADA' END AS STATUS,
    CASE (rn % 4) WHEN 0 THEN 'PIX' WHEN 1 THEN 'CREDITO' WHEN 2 THEN 'DEBITO' ELSE 'BOLETO' END AS FORMA_PG,
    ((rn-1) % 25) + 1 AS ID_PROD,
    CASE WHEN rn <= 200
         THEN (1 + ((rn-1) % 350))
         ELSE CASE WHEN ((rn-201) % 10) < 6
                   THEN (1 + ((rn-201) % 228))
                   ELSE (229 + ((rn-201) % 122))
              END
    END AS ID_CLI,
    ((rn-1) % 550) + 1 AS ID_FRETE_SUG,
    CASE WHEN rn > 200 AND ((rn-201) % 20) < 9 THEN 1 ELSE 0 END AS SEM_FRETE_CANAL1,
    ((rn-1) % 8) + 1 AS QTD_PROD,
    DATEADD(DAY, (rn-1) % @days, @startDate) AS DT_PEDIDO,
    DATEADD(DAY, rn % 2, DATEADD(DAY, (rn-1) % @days, @startDate)) AS DT_NOTA,
    DATEADD(DAY, 1 + (rn % 7), DATEADD(DAY, (rn-1) % @days, @startDate)) AS DT_ENTREGA_SUG
  FROM nums
),
calc AS (
  SELECT
    b.*,
    p.VLR_CUSTO,
    CAST(
      CASE WHEN p.VLR_CUSTO*1.15 > p.VLR_CUSTO/0.85
           THEN p.VLR_CUSTO*1.15 ELSE p.VLR_CUSTO/0.85 END
      AS DECIMAL(10,2)
    ) AS VLR_UNIT_OK,
    f.ID_FRETE,
    f.DISTANCIA_KM,
    f.VLR_KM_ROD
  FROM base b
  JOIN dbo.Dim_Produtos p ON p.ID_PROD = b.ID_PROD
  LEFT JOIN dbo.Dim_Fretes f ON f.ID_FRETE = b.ID_FRETE_SUG
)
INSERT INTO dbo.Fato_Vendas
(
  ID_FRETE, NUM_PEDIDO, NUM_NOTA, ID_CLI, DT_PEDIDO, DT_CANCEL, DT_NOTA,
  ID_PROD, QTD_PROD, VLR_UNIT, VLR_DESC, VLR_FRETE, VLR_TOTAL, FORMA_PG, STATUS, ID_CANAL, DT_ENTREGA
)
SELECT
  CASE 
    WHEN c.STATUS='CANCELADA' THEN NULL
    WHEN c.ID_CANAL=1 AND c.SEM_FRETE_CANAL1=1 THEN NULL
    ELSE c.ID_FRETE
  END,
  'P' + RIGHT('00000000' + CONVERT(VARCHAR(20), c.rn), 8),
  'N' + RIGHT('00000000' + CONVERT(VARCHAR(20), c.rn), 8),
  c.ID_CLI,
  c.DT_PEDIDO,
  CASE WHEN c.STATUS='CANCELADA' THEN DATEADD(DAY, c.rn % 2, c.DT_PEDIDO) ELSE NULL END,
  c.DT_NOTA,
  c.ID_PROD,
  c.QTD_PROD,
  c.VLR_UNIT_OK,
  CAST(
    CASE 
      WHEN c.FORMA_PG IN ('PIX','DEBITO')
        THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
      ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
    END
  AS DECIMAL(10,2)),
  CAST(
    CASE 
      WHEN c.STATUS='CANCELADA' THEN 0
      WHEN c.ID_CANAL=1 AND c.SEM_FRETE_CANAL1=1 THEN 0
      ELSE
        CASE 
          WHEN ROUND( ( (c.QTD_PROD * c.VLR_UNIT_OK)
                       - (CASE WHEN c.FORMA_PG IN ('PIX','DEBITO')
                               THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
                               ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
                          END)
                     ) * 0.1764705882, 2) < ROUND(ISNULL(c.DISTANCIA_KM,0) * ISNULL(c.VLR_KM_ROD,0), 2)
          THEN ROUND( ( (c.QTD_PROD * c.VLR_UNIT_OK)
                       - (CASE WHEN c.FORMA_PG IN ('PIX','DEBITO')
                               THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
                               ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
                          END)
                     ) * 0.1764705882, 2)
          ELSE ROUND(ISNULL(c.DISTANCIA_KM,0) * ISNULL(c.VLR_KM_ROD,0), 2)
        END
    END
  AS DECIMAL(10,2)),
  CAST(ROUND(
      (c.QTD_PROD * c.VLR_UNIT_OK)
      - (CASE WHEN c.FORMA_PG IN ('PIX','DEBITO')
              THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
              ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
         END)
      + 
      CASE 
        WHEN c.STATUS='CANCELADA' THEN 0
        WHEN c.ID_CANAL=1 AND c.SEM_FRETE_CANAL1=1 THEN 0
        ELSE
          CASE 
            WHEN ROUND( ( (c.QTD_PROD * c.VLR_UNIT_OK)
                         - (CASE WHEN c.FORMA_PG IN ('PIX','DEBITO')
                                 THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
                                 ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
                            END)
                       ) * 0.1764705882, 2) < ROUND(ISNULL(c.DISTANCIA_KM,0) * ISNULL(c.VLR_KM_ROD,0), 2)
            THEN ROUND( ( (c.QTD_PROD * c.VLR_UNIT_OK)
                         - (CASE WHEN c.FORMA_PG IN ('PIX','DEBITO')
                                 THEN ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*7)%11)/100.0), 2)
                                 ELSE ROUND( (c.QTD_PROD * c.VLR_UNIT_OK) * (((c.rn*13)%13)/100.0), 2)
                            END)
                       ) * 0.1764705882, 2)
            ELSE ROUND(ISNULL(c.DISTANCIA_KM,0) * ISNULL(c.VLR_KM_ROD,0), 2)
          END
      END
  , 2) AS DECIMAL(10,2)),
  c.FORMA_PG,
  c.STATUS,
  c.ID_CANAL,
  CASE WHEN c.STATUS='CANCELADA' THEN NULL ELSE c.DT_ENTREGA_SUG END
FROM calc c
OPTION (MAXRECURSION 0);

/* ============================================================
   Dim_Fretes: sincronização com FATO (inserir faltantes, remover não usados, padronizar motoristas)
   ============================================================ */
IF OBJECT_ID('tempdb..#UsedFretes') IS NOT NULL DROP TABLE #UsedFretes;

SELECT DISTINCT ID_FRETE
INTO #UsedFretes
FROM dbo.Fato_Vendas
WHERE ID_FRETE IS NOT NULL;

INSERT INTO dbo.Dim_Fretes (ID_FRETE, DISTANCIA_KM, VLR_KM_ROD, MOTORISTA)
SELECT
  u.ID_FRETE,
  CAST(10 + ((u.ID_FRETE * 9) % 350) AS DECIMAL(10,2)),
  CAST(1.50 + ((u.ID_FRETE % 8) * 0.45) AS DECIMAL(10,2)),
  CASE ABS(u.ID_FRETE) % 3 WHEN 0 THEN 'ANTONIO' WHEN 1 THEN 'MARCELO' ELSE 'ROBERTO' END
FROM #UsedFretes u
LEFT JOIN dbo.Dim_Fretes f ON f.ID_FRETE = u.ID_FRETE
WHERE f.ID_FRETE IS NULL;

DELETE f
FROM dbo.Dim_Fretes f
LEFT JOIN #UsedFretes u ON u.ID_FRETE = f.ID_FRETE
WHERE u.ID_FRETE IS NULL;

UPDATE f
SET MOTORISTA = CASE ABS(f.ID_FRETE) % 3
                  WHEN 0 THEN 'ANTONIO'
                  WHEN 1 THEN 'MARCELO'
                  ELSE 'ROBERTO'
                END
FROM dbo.Dim_Fretes f;

/* ============================================================
   Índices: acelerar consultas comuns (fato por cliente/status; clientes por atributos demográficos)
   ============================================================ */
CREATE INDEX IX_Fato_Vendas_IDCLI_Status ON dbo.Fato_Vendas (ID_CLI, STATUS) INCLUDE (DT_PEDIDO);
CREATE INDEX IX_Clientes_PessoaNascGen ON dbo.Dim_Clientes (TP_PESSOA, DT_NASC, DESC_GEN) INCLUDE (ID_CLI);

/* ============================================================
   Confirmação da transação
   ============================================================ */
COMMIT;
