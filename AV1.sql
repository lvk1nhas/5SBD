-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 10/10/2024 às 01:24
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
-- Banco de dados: `aaaa`
--

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `wl_InserirDados` ()   BEGIN
    -- 1. Inserindo novos clientes que ainda não estão na base
    INSERT INTO wl_clientes (codigoComprador, nomeComprador, email)
    SELECT DISTINCT codigoComprador, nomeComprador, email
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_clientes WHERE codigoComprador = wl_tempdata.codigoComprador);

    -- 2. Inserindo novos pedidos que ainda não existem na tabela de pedidos
    INSERT INTO wl_pedidos (codigoPedido, codigoComprador, dataPedido, valor, status)
    SELECT DISTINCT codigoPedido, codigoComprador, dataPedido, valor, 'pendente'
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido);

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `wl_processar_estoque` ()   BEGIN

    -- Declaração de variáveis para armazenar os valores do cursor
    DECLARE v_SKU VARCHAR(20);  
    DECLARE v_quantidade INT;  
    DECLARE terminou INT DEFAULT 0;  -- Alterado o nome de 'pronto' para 'terminou' para diferenciar

    -- Definição do cursor para selecionar dados da tabela temporária
    DECLARE cursor_estoque CURSOR FOR SELECT SKU, quantidade FROM wl_tempdata_estoque;

    -- Manipulador para lidar com o fim do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET terminou = 1;  -- Alterei o nome do manipulador

    -- Abrindo o cursor para processar as linhas da tabela temporária
    OPEN cursor_estoque;

    -- Loop que percorre cada linha retornada pelo cursor
    movimentacao_loop:LOOP

        -- Buscando os valores da próxima linha do cursor e atribuindo às variáveis
        FETCH cursor_estoque INTO v_SKU, v_quantidade;

        -- Se o cursor já leu todas as linhas, saímos do loop
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `wl_processar_pedidos_v2` ()  
BEGIN

    DECLARE v_codigoPedido INT;
    DECLARE v_statusPedido VARCHAR(20);
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros

    -- Cursor para selecionar os pedidos ordenados pelo valor em ordem decrescente
    DECLARE cursor_pedidos CURSOR FOR 
    SELECT codigoPedido, status 
    FROM wl_pedidos 
    ORDER BY valor DESC;  

    -- Cursor para selecionar os itens de cada pedido
    DECLARE cursor_itens CURSOR FOR 
    SELECT SKU, quantidade 
    FROM wl_itens_pedidos
    WHERE codigoPedido = v_codigoPedido;  -- Filtra pelo pedido atual

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    OPEN cursor_pedidos;

    pedidos_loop: LOOP
        -- Obtém o próximo pedido
        FETCH cursor_pedidos INTO v_codigoPedido, v_statusPedido;

        IF pronto THEN
            LEAVE pedidos_loop;
        END IF;

        -- Processa apenas pedidos com status 'pendente'
        IF v_statusPedido = 'pendente' THEN

            -- Abre o cursor para os itens do pedido atual
            OPEN cursor_itens;

            itens_loop: LOOP
                -- Obtém o próximo item do pedido
                FETCH cursor_itens INTO v_codigoProduto, v_quantidade;

                IF pronto THEN
                    LEAVE itens_loop;
                END IF;

                -- Verifica se há estoque suficiente
                IF (SELECT quantidade FROM wl_estoque WHERE SKU = v_codigoProduto) >= v_quantidade THEN
                    -- Aprova o item e atualiza o estoque
                    UPDATE wl_itens_pedidos 
                    SET status = 'aprovado' 
                    WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;
                    
                    UPDATE wl_estoque 
                    SET quantidade = quantidade - v_quantidade 
                    WHERE SKU = v_codigoProduto;
                ELSE
                    -- Marca o pedido e o item como 'pendente'
                    UPDATE wl_pedidos 
                    SET status = 'pendente' 
                    WHERE codigoPedido = v_codigoPedido;
                    
                    UPDATE wl_itens_pedidos 
                    SET status = 'pendente' 
                    WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;

                    -- Atualiza ou insere a quantidade necessária de compra
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

            CLOSE cursor_itens;

            -- Se todos os itens do pedido forem aprovados, aprova o pedido
            IF NOT EXISTS (SELECT 1 FROM wl_itens_pedidos WHERE codigoPedido = v_codigoPedido AND status = 'pendente') THEN
                UPDATE wl_pedidos 
                SET status = 'aprovado' 
                WHERE codigoPedido = v_codigoPedido;
            END IF;

        END IF;

    END LOOP;

    CLOSE cursor_pedidos;

END$$

DELIMITER ;


-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_clientes`
--

CREATE TABLE `wl_clientes` (
  `id` int(11) NOT NULL,
  `codigoComprador` varchar(32) NOT NULL,
  `nomeComprador` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_compras`
--

CREATE TABLE `wl_compras` (
  `id` int(11) NOT NULL,
  `SKU` varchar(20) NOT NULL,
  `quantidade` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--


-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_entregas`
--

CREATE TABLE `wl_entregas` (
  `id` int(11) NOT NULL,
  `codigoPedido` varchar(32) NOT NULL,
  `endereco` varchar(255) NOT NULL,
  `CEP` varchar(11) NOT NULL,
  `UF` varchar(2) NOT NULL,
  `pais` varchar(20) NOT NULL,
  `valor` float(5,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_estoque`
--

CREATE TABLE `wl_estoque` (
  `id` int(11) NOT NULL,
  `SKU` varchar(20) NOT NULL,
  `quantidade` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--

-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_itens_pedidos`
--

CREATE TABLE `wl_itens_pedidos` (
  `id` int(11) NOT NULL,
  `codigoPedido` varchar(20) NOT NULL,
  `SKU` varchar(20) NOT NULL,
  `quantidade` int(11) NOT NULL,
  `valor_unitario` float(5,2) NOT NULL DEFAULT 0.00,
  `status` enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_pedidos`
--

CREATE TABLE `wl_pedidos` (
  `id` int(11) NOT NULL,
  `codigoPedido` varchar(32) NOT NULL,
  `codigoComprador` varchar(32) NOT NULL,
  `dataPedido` date NOT NULL,
  `valor` float(5,2) NOT NULL,
  `status` enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--


-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_produtos`
--

CREATE TABLE `wl_produtos` (
  `id` int(11) NOT NULL,
  `SKU` varchar(20) NOT NULL,
  `UPC` varchar(20) NOT NULL,
  `nomeProduto` varchar(50) NOT NULL,
  `valor` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_tempdata`
--

CREATE TABLE `wl_tempdata` (
  `codigoPedido` varchar(30) NOT NULL,
  `dataPedido` date NOT NULL,
  `SKU` varchar(20) NOT NULL,
  `UPC` varchar(20) NOT NULL,
  `nomeProduto` varchar(100) NOT NULL,
  `quantidade` int(11) NOT NULL,
  `valor` float NOT NULL,
  `frete` int(11) NOT NULL,
  `email` varchar(200) NOT NULL,
  `codigoComprador` varchar(4) NOT NULL,
  `nomeComprador` varchar(50) NOT NULL,
  `endereco` varchar(255) NOT NULL,
  `CEP` varchar(11) NOT NULL,
  `UF` varchar(2) NOT NULL,
  `pais` varchar(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela `wl_tempdata_estoque`
--

CREATE TABLE `wl_tempdata_estoque` (
  `SKU` varchar(20) NOT NULL,
  `quantidade` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



--
-- Índices de tabela `wl_clientes`
--
ALTER TABLE `wl_clientes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `codigoComprador` (`codigoComprador`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Índices de tabela `wl_compras`
--
ALTER TABLE `wl_compras`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `SKU` (`SKU`);

--
-- Índices de tabela `wl_entregas`
--
ALTER TABLE `wl_entregas`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `codigoPedido` (`codigoPedido`);

--
-- Índices de tabela `wl_estoque`
--
ALTER TABLE `wl_estoque`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `SKU` (`SKU`);

--
-- Índices de tabela `wl_itens_pedidos`
--
ALTER TABLE `wl_itens_pedidos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FK_ItensPedidosCodigoComprador` (`codigoPedido`),
  ADD KEY `FK_ItensPedidosSKU` (`SKU`);

--
-- Índices de tabela `wl_pedidos`
--
ALTER TABLE `wl_pedidos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `codigoPedido` (`codigoPedido`),
  ADD KEY `FK_PedidosComprador` (`codigoComprador`);

--
-- Índices de tabela `wl_produtos`
--
ALTER TABLE `wl_produtos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `SKU` (`SKU`),
  ADD UNIQUE KEY `UPC` (`UPC`);

--
-- AUTO_INCREMENT para tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela `wl_clientes`
--
ALTER TABLE `wl_clientes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de tabela `wl_compras`
--
ALTER TABLE `wl_compras`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de tabela `wl_entregas`
--
ALTER TABLE `wl_entregas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=527;

--
-- AUTO_INCREMENT de tabela `wl_estoque`
--
ALTER TABLE `wl_estoque`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de tabela `wl_itens_pedidos`
--
ALTER TABLE `wl_itens_pedidos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1039;

--
-- AUTO_INCREMENT de tabela `wl_pedidos`
--
ALTER TABLE `wl_pedidos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=527;

--
-- AUTO_INCREMENT de tabela `wl_produtos`
--
ALTER TABLE `wl_produtos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- Restrições para tabelas despejadas
--

--
-- Restrições para tabelas `wl_compras`
--
ALTER TABLE `wl_compras`
  ADD CONSTRAINT `FK_ComprasSKU` FOREIGN KEY (`SKU`) REFERENCES `wl_produtos` (`SKU`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas `wl_entregas`
--
ALTER TABLE `wl_entregas`
  ADD CONSTRAINT `FK_EntregasCodigoPedido` FOREIGN KEY (`codigoPedido`) REFERENCES `wl_pedidos` (`codigoPedido`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas `wl_estoque`
--
ALTER TABLE `wl_estoque`
  ADD CONSTRAINT `FK_EstoqueSKU` FOREIGN KEY (`SKU`) REFERENCES `wl_produtos` (`SKU`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas `wl_itens_pedidos`
--
ALTER TABLE `wl_itens_pedidos`
  ADD CONSTRAINT `FK_ItensPedidosCodigoComprador` FOREIGN KEY (`codigoPedido`) REFERENCES `wl_pedidos` (`codigoPedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_ItensPedidosSKU` FOREIGN KEY (`SKU`) REFERENCES `wl_produtos` (`SKU`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas `wl_pedidos`
--
ALTER TABLE `wl_pedidos`
  ADD CONSTRAINT `FK_PedidosComprador` FOREIGN KEY (`codigoComprador`) REFERENCES `wl_clientes` (`codigoComprador`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
