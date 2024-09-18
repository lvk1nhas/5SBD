Comando: SQL pra importação dos dados em arquivo CSV:

LOAD DATA INFILE 'C:/Users/casol/Downloads/produtos.csv'
INTO TABLE wl_produtos
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id, codigo, nome, valor, quantidade);


Comando: Inserindo dados do TXT no banco
LOAD DATA INFILE 'C:/Users/casol/Downloads/pedidos.txt'
INTO TABLE wl_tempdata
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
(codigoPedido, dataPedido, SKU, UPC, nomeProduto, quantidade, valor, frete, email, codigoComprador, nomeComprador, endereco, CEP, UF, pais);


Comando: Selecionar clientes sem repetição
SELECT DISTINCT codigoComprador, email, endereco, CEP, UF, pais FROM wl_tempdata GROUP BY codigoComprador;
