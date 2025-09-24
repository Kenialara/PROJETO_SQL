/* ============================================================
   Sessão e transação: evitar contagens intermediárias e abortar em erro
   ============================================================ */
USE StyloImperial;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

/* ============================================================
   1. Indicadores financeiros mensais de 2025
   - Métricas: faturamento bruto, custos diretos, descontos,
     ticket médio, margem absoluta e percentual
   - Observação: frete desconsiderado (repassado ao motorista)
   ============================================================ */
SELECT 
    YEAR(FV.DT_NOTA) AS Ano,
    MONTH(FV.DT_NOTA) AS Mes,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS "Fat Bruto R$",
    SUM(PROD.VLR_CUSTO * FV.QTD_PROD) AS "Custo Prod R$",
    SUM(ISNULL(FV.VLR_DESC,0)) AS "Descontos R$",
    COUNT(FV.ID_VENDA) AS "Qtde Pedidos",
    CAST(SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) * 1.0 
         / NULLIF(COUNT(FV.ID_VENDA),0) AS DECIMAL(10,2)) AS "Ticket médio por pedido",
    SUM((FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) - (PROD.VLR_CUSTO * FV.QTD_PROD)) AS "Margem R$",
    CAST(
        (SUM((FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) - (PROD.VLR_CUSTO * FV.QTD_PROD)) * 100.0) 
        / NULLIF(SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)),0) AS DECIMAL(10,2)) AS "Margem %"
FROM Fato_Vendas AS FV
JOIN Dim_Produtos AS PROD
    ON FV.ID_PROD = PROD.ID_PROD
WHERE FV.Status = 'CONFIRMADA'
  AND YEAR(FV.DT_NOTA) = '2025'
GROUP BY YEAR(FV.DT_NOTA), MONTH(FV.DT_NOTA)
ORDER BY Ano DESC, Mes DESC;

/* ============================================================
   2. Percentual de atingimento da meta mensal (R$ 300.000,00) em 2025
   ============================================================ */
DECLARE @META_MENSAL DECIMAL(18,2) = 300000.00;

SELECT
    FORMAT(FV.DT_PEDIDO,'yyyy-MM') AS Ano_Mês,
    @META_MENSAL AS Meta,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento,
    CAST(100.0 * SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) / @META_MENSAL AS DECIMAL(10,2)) AS Perc_Atingido
FROM Fato_Vendas AS FV
WHERE FV.STATUS = 'CONFIRMADA'
  AND YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY FORMAT(FV.DT_PEDIDO,'yyyy-MM')
ORDER BY Ano_Mês DESC;

/* ============================================================
   3. Taxa de cancelamento mensal em 2025
   ============================================================ */
SELECT
    FORMAT(FV.DT_PEDIDO,'yyyy-MM') AS Ano_Mês,
    COUNT(*) AS Total_Vendas,
    SUM(CASE WHEN FV.STATUS = 'CANCELADA' THEN 1 ELSE 0 END) AS Canceladas,
    CAST(100.0 * SUM(CASE WHEN FV.STATUS = 'CANCELADA' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2)) AS Tx_Cancelamento
FROM Fato_Vendas AS FV
WHERE YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY FORMAT(FV.DT_PEDIDO,'yyyy-MM')
ORDER BY Ano_Mês DESC;

/* ============================================================
   4. Participação percentual das formas de pagamento no faturamento de 2025
   ============================================================ */
SELECT
    FV.FORMA_PG AS Forma_Pagamento,
    COUNT(*) AS Qtd_Vendas,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento,
    CAST(SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) * 100.0 
         / SUM(SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0))) OVER() AS DECIMAL(5,2)) AS Perc_Faturamento
FROM Fato_Vendas AS FV
WHERE FV.STATUS = 'CONFIRMADA'
  AND YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY FV.FORMA_PG
ORDER BY Faturamento DESC;

/* ============================================================
   5. Participação por canal no faturamento total de 2025
   ============================================================ */
WITH VENDAS_CANAL AS (
    SELECT
        YEAR(FV.DT_PEDIDO) AS Ano,
        CL.NM_CANAL AS Canal,
        SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento,
        COUNT(*) AS Qtd_Vendas,
        CAST(SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) * 1.0 / COUNT(*) AS DECIMAL(10,2)) AS Ticket_Medio
    FROM Fato_Vendas AS FV
    JOIN Dim_Canal AS CL
      ON FV.ID_CANAL = CL.ID_CANAL
    WHERE FV.STATUS = 'CONFIRMADA'
      AND YEAR(FV.DT_PEDIDO) = '2025'
    GROUP BY YEAR(FV.DT_PEDIDO), CL.NM_CANAL
)
SELECT *,
       CAST(Faturamento * 100.0 / SUM(Faturamento) OVER() AS DECIMAL(5,2)) AS "Percentual %"
FROM VENDAS_CANAL
ORDER BY Faturamento DESC;

/* ============================================================
   6. Segmentos de clientes (gênero + faixa etária) mais relevantes em 2025
   - Apenas clientes físicos
   ============================================================ */
WITH PERFIL_CLIENTE AS (
    SELECT
        YEAR(FV.DT_PEDIDO) AS Ano,
        CLI.DESC_GEN AS Genero,
        CASE 
            WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 18 AND 24 THEN '18-24'
            WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 25 AND 34 THEN '25-34'
            WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 35 AND 44 THEN '35-44'
            WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 45 AND 54 THEN '45-54'
            WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65-80'
        END AS Faixa_Etaria,
        SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento
    FROM Dim_Clientes AS CLI
    JOIN Fato_Vendas AS FV
      ON CLI.ID_CLI = FV.ID_CLI
    WHERE FV.STATUS = 'CONFIRMADA'
      AND CLI.DT_NASC IS NOT NULL
      AND CLI.TP_PESSOA = 'FISICA'
      AND YEAR(FV.DT_PEDIDO) = '2025'
    GROUP BY YEAR(FV.DT_PEDIDO), CLI.DESC_GEN,
             CASE 
                 WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 18 AND 24 THEN '18-24'
                 WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 25 AND 34 THEN '25-34'
                 WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 35 AND 44 THEN '35-44'
                 WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 45 AND 54 THEN '45-54'
                 WHEN DATEDIFF(YEAR, CLI.DT_NASC, GETDATE()) BETWEEN 55 AND 64 THEN '55-64'
                 ELSE '65-80'
             END
)
SELECT *,
       CAST(Faturamento * 100.0 / SUM(Faturamento) OVER() AS DECIMAL(5,2)) AS Perc_Participacao
FROM PERFIL_CLIENTE
ORDER BY Faturamento DESC;

/* ============================================================
   7. Top 10 clientes que mais contribuíram para o faturamento de 2025
   ============================================================ */
SELECT TOP (10)
    YEAR(FV.DT_PEDIDO) AS Ano,
    CLI.NM_CLI AS Nome,
    COUNT(*) AS Qtd_Vendas,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento
FROM Fato_Vendas AS FV
JOIN Dim_Clientes AS CLI
    ON CLI.ID_CLI = FV.ID_CLI
WHERE FV.STATUS = 'CONFIRMADA'
  AND YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY YEAR(FV.DT_PEDIDO), CLI.NM_CLI
ORDER BY Faturamento DESC;

/* ============================================================
   8. Faixa de renda que mais contribui para o faturamento em 2025
   ============================================================ */
WITH FAIXA_SALARIAL AS (
    SELECT
        YEAR(FV.DT_PEDIDO) AS Ano,
        CASE
            WHEN (CLI.RENDA/1518) BETWEEN 1.0 AND 2.99 THEN '1-3'
            WHEN (CLI.RENDA/1518) BETWEEN 3.0 AND 4.99 THEN '3-5'
            WHEN (CLI.RENDA/1518) BETWEEN 5.0 AND 7.99 THEN '5-8'
            ELSE '+8'
        END AS Faixa_Renda,
        SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento
    FROM Dim_Clientes AS CLI
    JOIN Fato_Vendas AS FV
      ON CLI.ID_CLI = FV.ID_CLI
    WHERE FV.STATUS = 'CONFIRMADA'
      AND CLI.RENDA IS NOT NULL
      AND YEAR(FV.DT_PEDIDO) = '2025'
    GROUP BY YEAR(FV.DT_PEDIDO),
             CASE
                 WHEN (CLI.RENDA/1518) BETWEEN 1.0 AND 2.99 THEN '1-3'
                 WHEN (CLI.RENDA/1518) BETWEEN 3.0 AND 4.99 THEN '3-5'
                 WHEN (CLI.RENDA/1518) BETWEEN 5.0 AND 7.99 THEN '5-8'
                 ELSE '+8'
             END
)
SELECT *,
       CAST(Faturamento * 100.0 / SUM(Faturamento) OVER() AS DECIMAL(5,2)) AS Perc_Participacao
FROM FAIXA_SALARIAL
ORDER BY Faturamento DESC;

/* ============================================================
   9. Cidades com maior concentração de clientes e faturamento
   ============================================================ */
SELECT
    CID.NM_CIDADE AS Cidade,
    COUNT(DISTINCT CLI.ID_CLI) AS Qtde_Clientes,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento
FROM Fato_Vendas AS FV
JOIN Dim_Clientes AS CLI
    ON FV.ID_CLI = CLI.ID_CLI
JOIN Dim_Cidades AS CID
    ON CLI.ID_CIDADE = CID.ID_CIDADE
WHERE FV.STATUS = 'CONFIRMADA'
GROUP BY CID.NM_CIDADE
ORDER BY Faturamento DESC;

/* ============================================================
   10. Top 10 produtos que mais contribuíram para o faturamento de 2025
   ============================================================ */
SELECT TOP(10)
    YEAR(FV.DT_PEDIDO) AS Ano,
    PROD.NM_PROD AS Produto,
    PROD.CATG_PROD AS Categoria,
    COUNT(*) AS Qtd_Vendas,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento
FROM Fato_Vendas AS FV
JOIN Dim_Produtos AS PROD 
    ON PROD.ID_PROD = FV.ID_PROD
WHERE FV.STATUS = 'CONFIRMADA' 
  AND YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY YEAR(FV.DT_PEDIDO), PROD.NM_PROD, PROD.CATG_PROD
ORDER BY Qtd_Vendas DESC, Faturamento DESC;

/* ============================================================
   11. Produtos com maior ticket médio em 2025
   ============================================================ */
SELECT TOP(10)
    FV.ID_PROD,
    PROD.NM_PROD,
    PROD.CATG_PROD,
    SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) AS Faturamento,
    SUM(FV.QTD_PROD) AS Qtd_Vendida,
    CAST((SUM(FV.VLR_TOTAL - ISNULL(FV.VLR_FRETE,0)) * 1.0) / SUM(FV.QTD_PROD) AS DECIMAL(10,2)) AS "Ticket médio"
FROM Fato_Vendas AS FV
JOIN Dim_Produtos AS PROD
    ON FV.ID_PROD = PROD.ID_PROD
WHERE FV.STATUS = 'CONFIRMADA'
GROUP BY FV.ID_PROD, PROD.NM_PROD, PROD.CATG_PROD
ORDER BY "Ticket médio" DESC;

/* ============================================================
   12. Top 5 categorias de produto com menor quantidade de vendas em 2025
   ============================================================ */
SELECT TOP(5) 
    YEAR(FV.DT_PEDIDO) AS Ano,
    PROD.CATG_PROD AS Categoria,
    SUM(FV.QTD_PROD) AS Qtd_Vendida
FROM Fato_Vendas AS FV
JOIN Dim_Produtos AS PROD 
    ON PROD.ID_PROD = FV.ID_PROD
WHERE FV.STATUS = 'CONFIRMADA'
  AND YEAR(FV.DT_PEDIDO) = '2025'
GROUP BY YEAR(FV.DT_PEDIDO), PROD.CATG_PROD
ORDER BY Qtd_Vendida;
