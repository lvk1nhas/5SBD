1 º comando: SQL pra importação dos dados em arquivo CSV:

LOAD DATA INFILE 'C:/Users/casol/Downloads/produtos.csv'
INTO TABLE wl_produtos
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id, codigo, nome, valor, quantidade);



2 º comando: Selecionar clientes sem repetição
SELECT DISTINCT codigoComprador, email, endereco, CEP, UF, pais FROM wl_tempdata GROUP BY codigoComprador;

3º comando: Inserindo dados do TXT no banco
LOAD DATA INFILE 'C:/Users/casol/Downloads/pedidos.txt'
INTO TABLE waterfall_dadostemp
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
(codigoPedido, dataPedido, SKU, UPC, nomeProduto, qtd, valor, frete, email, codigoComprador, nomeComprador, endereco, CEP, UF, pais);
