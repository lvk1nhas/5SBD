1 º comando: SQL pra importação dos dados em arquivo CSV:

LOAD DATA INFILE 'C:/Users/casol/Downloads/[5SBD] Planilha de Dados - Produtos  - Produtos.csv'
INTO TABLE sbd_produtos
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id, codigo, nome, valor, qtd);


2 º comando: Selecionar clientes sem repetição
SELECT DISTINCT codigoComprador, email, endereco, CEP, UF, pais FROM pedidos_temp GROUP BY codigoComprador;


3º comando: Inserindo dados do TXT no banco
LOAD DATA INFILE 'C:/Users/casol/Downloads/pedidos.txt'
INTO TABLE sbd_datatemp
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
(codigoPedido, dataPedido, SKU, UPC, nomeProduto, qtd, valor, frete, email, codigoComprador, nomeComprador, endereco, CEP, UF, pais);
