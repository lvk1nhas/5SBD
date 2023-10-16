-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 09/10/2024 às 20:29
-- Versão do servidor: 10.4.32-MariaDB
-- Versão do PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Banco de dados: waterfall
--

DELIMITER $$

CREATE PROCEDURE InserirDados()
BEGIN
    -- 1. Inserindo novos clientes que ainda não estão na base
    INSERT INTO wl_clientes (codigoComprador, nomeComprador, email)
    SELECT DISTINCT codigoComprador, nomeComprador, email
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_clientes WHERE codigoComprador = wl_tempdata.codigoComprador);

    -- 2. Inserindo novos pedidos que ainda não existem na tabela de pedidos
    INSERT INTO wl_pedidos (codigoPedido, codigoComprador, dataPedido, valor, status)
    SELECT DISTINCT codigoPedido, codigoComprador, dataPedido, SUM(valor), 'pendente'
    FROM wl_tempdata
    WHERE NOT EXISTS (SELECT 1 FROM wl_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido)
    GROUP BY codigoPedido;

    -- 3. Inserindo novos produtos na tabela de produtos
    INSERT INTO wl_produtos (SKU, UPC, nomeProduto, valor)
    SELECT DISTINCT SKU, UPC, nomeProduto, ROUND(valor / quantidade, 2)
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_produtos WHERE SKU = wl_tempdata.SKU);

    -- 4. Inserindo itens de pedido na tabela de itens de pedido
    INSERT INTO wl_itens_pedidos (codigoPedido, SKU, quantidade, valor_unitario)
    SELECT DISTINCT codigoPedido, SKU, quantidade, ROUND(valor / quantidade, 2)
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_itens_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido AND SKU = wl_tempdata.SKU);

    -- 5. Inserindo dados de entrega na tabela de entregas
    INSERT INTO wl_entregas (codigoPedido, endereco, CEP, UF, pais, valor)
    SELECT DISTINCT codigoPedido, endereco, CEP, UF, pais, frete
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_entregas WHERE codigoPedido = wl_tempdata.codigoPedido);

    -- 6. Inserindo produtos na tabela de estoque, se não existirem
    INSERT INTO wl_estoque (SKU)
    SELECT DISTINCT SKU FROM wl_tempdata
    WHERE NOT EXISTS (SELECT 1 FROM wl_estoque WHERE SKU = wl_tempdata.SKU);

END$$

DELIMITER ;

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=root@localhost PROCEDURE RecarregarEstoque ()   BEGIN

    -- Declaração de variáveis para armazenar os valores do cursor
    DECLARE v_SKU VARCHAR(20);  
    DECLARE v_quantidade INT;  
    DECLARE terminou INT DEFAULT 0; 

    -- Definição do cursor para selecionar dados da tabela temporária
    DECLARE cursor_estoque CURSOR FOR SELECT SKU, quantidade FROM wl_tempdata_estoque;

    -- Manipulador para lidar com o fim do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET terminou = 1; 

    -- Abrindo o cursor para processar as linhas da tabela temporária
    OPEN cursor_estoque;

    -- Loop que percorre cada linha retornada pelo cursor
    movimentacao_loop:LOOP

        -- Buscando os valores da próxima linha do cursor e atribuindo às variáveis
        FETCH cursor_estoque INTO v_SKU, v_quantidade;

        -- Se o cursor já leu todas as linhas, saio
        IF terminou THEN
            LEAVE movimentacao_loop;  -- Sair do loop quando terminar
        END IF;

        -- Atualizando a quantidade de produtos no estoque
        UPDATE wl_estoque 
        SET quantidade = quantidade + v_quantidade 
        WHERE SKU = v_SKU;

        -- Subtraindo a quantidade de compras processada
        UPDATE wl_compras 
        SET quantidade = quantidade - v_quantidade 
        WHERE SKU = v_SKU;
        
    END LOOP;  -- Fim do loop de processamento

    -- Deletando compras cuja quantidade final seja zero ou negativa
    DELETE FROM wl_compras WHERE quantidade <= 0;

    -- Limpando os dados temporários após o processamento
    -- TRUNCATE TABLE wl_tempdata_estoque;

END$$

DELIMITER ;

DELIMITER $$

DELIMITER $$

CREATE DEFINER=root@localhost PROCEDURE ProcessarItensPedidos ()   
BEGIN
    -- Declarando as variáveis no início da procedure
    DECLARE v_codigoPedido INT;
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronta INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros
    DECLARE estoqueDisponivel INT; -- Declaração da variável de estoque
    DECLARE quantidadePendente INT; -- Declaração da variável para a quantidade total pendente do produto
    
    -- Cursor para selecionar os itens dos pedidos
    DECLARE cursor_itens CURSOR FOR 
    SELECT codigoPedido, SKU, quantidade 
    FROM wl_itens_pedidos
    WHERE status = 'pendente';  -- Apenas itens pendentes serão processados
    
    -- Handler para quando não houver mais registros no cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronta = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abrindo o cursor de itens
    OPEN cursor_itens;

    itens_loop: LOOP
        -- Buscando os dados do cursor
        FETCH cursor_itens INTO v_codigoPedido, v_codigoProduto, v_quantidade;

        IF pronta THEN
            LEAVE itens_loop;
        END IF;

        -- Calcula a quantidade total pendente do produto no estoque
        SELECT SUM(quantidade) INTO quantidadePendente
        FROM wl_itens_pedidos 
        WHERE SKU = v_codigoProduto AND status = 'pendente';

        -- Verifica a quantidade total do item no estoque
        SELECT quantidade INTO estoqueDisponivel
        FROM wl_estoque
        WHERE SKU = v_codigoProduto
        FOR UPDATE;

        -- Verifica se o estoque disponível é suficiente para todos os itens pendentes
        IF quantidadePendente <= estoqueDisponivel THEN
            -- Aprova todos os itens pendentes para esse produto
            UPDATE wl_itens_pedidos 
            SET status = 'aprovado' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';
            
        ELSE
            -- Marca todos os itens pendentes desse produto como pendentes
            UPDATE wl_itens_pedidos 
            SET status = 'pendente' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';

            -- Verifica se o item precisa ser comprado
            IF EXISTS (SELECT 1 FROM wl_compras WHERE SKU = v_codigoProduto) THEN
                UPDATE wl_compras 
                SET quantidade = quantidade + v_quantidade 
                WHERE SKU = v_codigoProduto;
            ELSE
                INSERT INTO wl_compras (SKU, quantidade) 
                VALUES (v_codigoProduto, v_quantidade);
            END IF;
        END IF;
    END LOOP;

    -- Fechando o cursor de itens
    CLOSE cursor_itens;

    -- Commit da transação
    COMMIT;

END$$

DELIMITER ;



DELIMITER $$

CREATE PROCEDURE ProcessarPedidos()
BEGIN
    DECLARE v_codigoPedido VARCHAR(32);
    DECLARE totalItens INT;
    DECLARE totalAprovados INT;
    DECLARE pronto INT DEFAULT 0;

    -- Declara um cursor para selecionar todos os códigos de pedido
    DECLARE cursor_pedidos CURSOR FOR 
    SELECT DISTINCT codigoPedido 
    FROM wl_itens_pedidos;

    -- Manipulador para o final do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abre o cursor
    OPEN cursor_pedidos;

    pedidos_loop: LOOP
        -- Busca o próximo código de pedido
        FETCH cursor_pedidos INTO v_codigoPedido;

        -- Se o cursor tiver terminado, sai do loop
        IF pronto THEN
            LEAVE pedidos_loop;
        END IF;

        -- Conta o total de itens do pedido
        SELECT COUNT(*) INTO totalItens 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido;

        -- Conta o total de itens aprovados do pedido
        SELECT COUNT(*) INTO totalAprovados 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido AND status = 'aprovado';

        -- Verifica se todos os itens estão aprovados
        IF totalItens = totalAprovados THEN
            -- Atualiza o status do pedido para aprovado
            UPDATE wl_pedidos 
            SET status = 'aprovado' 
            WHERE codigoPedido = v_codigoPedido;

            -- Chama a procedure para debitar o estoque agora que o pedido foi aprovado
            CALL DebitarEstoquePedido(v_codigoPedido);
        END IF;
    END LOOP;

    -- Fechando o cursor de pedidos
    CLOSE cursor_pedidos;

    -- Commit da transação
    COMMIT;

END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE DebitarEstoquePedido(v_codigoPedido VARCHAR(32))
BEGIN
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;

    -- Declara um cursor para pegar os itens aprovados do pedido
    DECLARE cursor_itens_pedido CURSOR FOR 
    SELECT SKU, quantidade
    FROM wl_itens_pedidos
    WHERE codigoPedido = v_codigoPedido AND status = 'aprovado';

    -- Manipulador para o final do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- Abre o cursor
    OPEN cursor_itens_pedido;

    itens_pedido_loop: LOOP
        -- Busca os dados do item aprovado
        FETCH cursor_itens_pedido INTO v_codigoProduto, v_quantidade;

        -- Se o cursor não tiver mais itens, sai do loop
        IF pronto THEN
            LEAVE itens_pedido_loop;
        END IF;

        -- Debita o estoque do item aprovado
        UPDATE wl_estoque 
        SET quantidade = quantidade - v_quantidade 
        WHERE SKU = v_codigoProduto;
    END LOOP;

    -- Fechando o cursor
    CLOSE cursor_itens_pedido;

END$$

DELIMITER ;






-- --------------------------------------------------------

--
-- Estrutura para tabela wl_clientes
--

CREATE TABLE wl_clientes (
  id int(11) NOT NULL,
  codigoComprador varchar(32) NOT NULL,
  nomeComprador varchar(100) NOT NULL,
  email varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_compras
--

CREATE TABLE wl_compras (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela wl_entregas
--

CREATE TABLE wl_entregas (
  id int(11) NOT NULL,
  codigoPedido varchar(32) NOT NULL,
  endereco varchar(255) NOT NULL,
  CEP varchar(11) NOT NULL,
  UF varchar(2) NOT NULL,
  pais varchar(20) NOT NULL,
  valor float(5,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_estoque
--

CREATE TABLE wl_estoque (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_itens_pedidos
--

CREATE TABLE wl_itens_pedidos (
  id int(11) NOT NULL,
  codigoPedido varchar(20) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL,
  valor_unitario float(5,2) NOT NULL DEFAULT 0.00,
  status enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_pedidos
--

CREATE TABLE wl_pedidos (
  id int(11) NOT NULL,
  codigoPedido varchar(32) NOT NULL,
  codigoComprador varchar(32) NOT NULL,
  dataPedido date NOT NULL,
  valor float(5,2) NOT NULL,
  status enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela wl_produtos
--

CREATE TABLE wl_produtos (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  UPC varchar(20) NOT NULL,
  nomeProduto varchar(50) NOT NULL,
  valor float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_tempdata
--

CREATE TABLE wl_tempdata (
  codigoPedido varchar(30) NOT NULL,
  dataPedido date NOT NULL,
  SKU varchar(20) NOT NULL,
  UPC varchar(20) NOT NULL,
  nomeProduto varchar(100) NOT NULL,
  quantidade int(11) NOT NULL,
  valor float NOT NULL,
  frete int(11) NOT NULL,
  email varchar(200) NOT NULL,
  codigoComprador varchar(4) NOT NULL,
  nomeComprador varchar(50) NOT NULL,
  endereco varchar(255) NOT NULL,
  CEP varchar(11) NOT NULL,
  UF varchar(2) NOT NULL,
  pais varchar(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura para tabela wl_tempdata_estoque
--

CREATE TABLE wl_tempdata_estoque (
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;




--
-- Índices de tabela wl_clientes
--
ALTER TABLE wl_clientes
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoComprador (codigoComprador),
  ADD UNIQUE KEY email (email);

--
-- Índices de tabela wl_compras
--
ALTER TABLE wl_compras
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU);

--
-- Índices de tabela wl_entregas
--
ALTER TABLE wl_entregas
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoPedido (codigoPedido);

--
-- Índices de tabela wl_estoque
--
ALTER TABLE wl_estoque
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU);

--
-- Índices de tabela wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  ADD PRIMARY KEY (id),
  ADD KEY FK_ItensPedidosCodigoComprador (codigoPedido),
  ADD KEY FK_ItensPedidosSKU (SKU);

--
-- Índices de tabela wl_pedidos
--
ALTER TABLE wl_pedidos
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoPedido (codigoPedido),
  ADD KEY FK_PedidosComprador (codigoComprador);

--
-- Índices de tabela wl_produtos
--
ALTER TABLE wl_produtos
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU),
  ADD UNIQUE KEY UPC (UPC);

--
-- AUTO_INCREMENT para tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela wl_clientes
--
ALTER TABLE wl_clientes
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela wl_compras
--
ALTER TABLE wl_compras
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de tabela wl_entregas
--
ALTER TABLE wl_entregas
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela wl_estoque
--
ALTER TABLE wl_estoque
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1024;

--
-- AUTO_INCREMENT de tabela wl_pedidos
--
ALTER TABLE wl_pedidos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela wl_produtos
--
ALTER TABLE wl_produtos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Restrições para tabelas despejadas
--

--
-- Restrições para tabelas wl_compras
--
ALTER TABLE wl_compras
  ADD CONSTRAINT FK_ComprasSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_entregas
--
ALTER TABLE wl_entregas
  ADD CONSTRAINT FK_EntregasCodigoPedido FOREIGN KEY (codigoPedido) REFERENCES wl_pedidos (codigoPedido) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_estoque
--
ALTER TABLE wl_estoque
  ADD CONSTRAINT FK_EstoqueSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  ADD CONSTRAINT FK_ItensPedidosCodigoComprador FOREIGN KEY (codigoPedido) REFERENCES wl_pedidos (codigoPedido) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FK_ItensPedidosSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_pedidos
--
ALTER TABLE wl_pedidos
  ADD CONSTRAINT FK_PedidosComprador FOREIGN KEY (codigoComprador) REFERENCES wl_clientes (codigoComprador) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */; 
