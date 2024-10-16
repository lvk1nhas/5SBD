-- Carregando os dados de pedidos
LOAD DATA INFILE 'C:/tools/htdocs/MinhaAv1/Arquivos/pedidos.csv'
INTO TABLE wl_tempdata
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- Carregar o arquivo CSV na tabela temporária
LOAD DATA INFILE 'C:/tools/htdocs/MinhaAv1/Arquivos/estoque.csv'
INTO TABLE wl_tempdata_estoque
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
