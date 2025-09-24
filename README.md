# 📊 Projeto Análise de vendas e perfil de clientes — SQL Server

Este projeto de análise de dados foi desenvolvido na plataforma **SQL Server**, utilizando a linguagem **SQL** para estruturação e consultas dos dados, e apresentação das análises.  

O objetivo central foi investigar e compreender em profundidade o **desempenho das vendas** e o **perfil dos consumidores** de uma loja fictícia de móveis rústicos denominada **Stylo Imperial**.  

👉 Para maiores detalhes do projeto acesse: [Artigo no Medium](https://medium.com/@kenialara94/an%C3%A1lise-de-vendas-e-perfil-de-clientes-sqlserver-d060ef8169eb)

---

## 📂 Estrutura dos Arquivos

### 1. 📜 `Criação_Database_Schema_StyloImperial.sql`
Script responsável pela **criação do schema e tabelas** do projeto.  
- Modelagem em **estrela**:  
  - **Dimensões**: `Dim_Canal`, `Dim_Cidades`, `Dim_Clientes`, `Dim_Fretes`, `Dim_Produtos`  
  - **Fato**: `Fato_Vendas`  
- Define **chaves primárias e estrangeiras**, garantindo integridade referencial.  
- Estrutura de colunas preparada para análises de faturamento, clientes, produtos e fretes:contentReference[oaicite:0]{index=0}.

---

### 2. 📜 `Carga_dados_StyloImperial.sql`
Script para **popular o schema com dados sintéticos de teste**.  
Inclui:  
- Limpeza inicial das tabelas (ordem de dependências).  
- Inserção de dados mínimos e amostrais em dimensões (canais, cidades, produtos, clientes e fretes).  
- Geração de **mil vendas simuladas**, com regras de negócio realistas:
  - Status de vendas (confirmada/cancelada)  
  - Descontos e formas de pagamento variadas  
  - Frete condicionado ao canal e cálculo de custo por km  
  - Precificação ajustada por margem de lucro  
- Criação de **índices** para otimizar consultas:contentReference[oaicite:1]{index=1}.

---

### 3. 📜 `Querys_Perguntas_Negocio.sql`
Conjunto de **12 queries analíticas** que respondem perguntas de negócio.  
Entre as principais análises:  
- 📈 **Indicadores financeiros**: faturamento bruto, custos diretos, descontos, margem absoluta e percentual, ticket médio.  
- 🎯 **Atingimento de metas**: percentual da meta mensal (R$ 300.000,00).  
- ❌ **Taxa de cancelamento**: acompanhamento mensal.  
- 💳 **Participação por forma de pagamento**.  
- 🛒 **Participação por canal de vendas**.  
- 👥 **Segmentação de clientes**: gênero + faixa etária e faixas de renda.  
- 🏆 **Top clientes e produtos** mais relevantes no faturamento.  
- 🏙️ **Distribuição geográfica**: cidades com maior concentração de clientes.  
- 📉 **Categorias com menor volume de vendas**.  

As queries estão padronizadas com **comentários descritivos e seções bem organizadas**, facilitando leitura.

---

## 🔗 Fluxo de Execução

1. **Criar o schema** → `Criação_Database_Schema_StyloImperial.sql` 
2. **Popular com dados sintéticos** → `Carga_dados_StyloImperial.sql`
3. **Executar as análises de negócio** → `Querys_Perguntas_Negocio.sql`
