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
-- Banco de dados: `waterfall`
--

DELIMITER $$
--
-- Procedimentos
--
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `wl_processar_pedidos_v2` ()   BEGIN

    -- Variáveis usadas para armazenar os valores dos pedidos e seus itens
    DECLARE v_codigoPedido INT;
    DECLARE v_statusPedido VARCHAR(20);
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros

    -- Cursores para os pedidos e itens de pedidos
    DECLARE cursor_pedidos CURSOR FOR SELECT codigoPedido, status FROM wl_pedidos;
    DECLARE cursor_itens CURSOR FOR SELECT SKU, quantidade FROM wl_itens_pedidos;
    
    -- Handler para quando o cursor não encontrar mais registros
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

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

    -- Limpar a tabela temporária de dados
    TRUNCATE TABLE wl_tempdata;

    -- Abrir o cursor de pedidos
    OPEN cursor_pedidos;

    -- Loop principal para processar os pedidos pendentes
    pedidos_loop: LOOP

        -- Buscar os dados do próximo pedido
        FETCH cursor_pedidos INTO v_codigoPedido, v_statusPedido;

        -- Se o cursor não encontrar mais registros, saia do loop
        IF NOT pronto THEN

            -- Verificar o status do pedido
            IF v_statusPedido = 'pendente' THEN

                -- Abrir o cursor para itens do pedido
                OPEN cursor_itens;

                -- Loop para processar os itens do pedido
                itens_loop: LOOP
                    -- Buscar dados do item
                    FETCH cursor_itens INTO v_codigoProduto, v_quantidade;

                    -- Se não houver mais itens, sair do loop
                    IF pronto THEN
                        LEAVE itens_loop;
                    END IF;

                    -- Verificar a disponibilidade no estoque
                    IF (SELECT quantidade FROM wl_estoque WHERE SKU = v_codigoProduto) >= v_quantidade THEN
                        -- Atualizar o status do item e diminuir o estoque
                        UPDATE wl_itens_pedidos SET status = 'aprovado' WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;
                        UPDATE wl_estoque SET quantidade = quantidade - v_quantidade WHERE SKU = v_codigoProduto;
                    ELSE
                        -- Caso o estoque não seja suficiente, marcar como pendente
                        UPDATE wl_pedidos SET status = 'pendente' WHERE codigoPedido = v_codigoPedido;
                        UPDATE wl_itens_pedidos SET status = 'pendente' WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;

                        -- Se o produto já estiver na lista de compras, atualizar a quantidade
                        IF EXISTS (SELECT 1 FROM wl_compras WHERE SKU = v_codigoProduto) THEN
                            UPDATE wl_compras SET quantidade = quantidade + v_quantidade WHERE SKU = v_codigoProduto;
                        ELSE
                            -- Caso contrário, inserir o produto na lista de compras
                            INSERT INTO wl_compras (SKU, quantidade) VALUES (v_codigoProduto, v_quantidade);
                        END IF;
                    END IF;
                END LOOP;

                -- Fechar o cursor de itens após processar todos
                CLOSE cursor_itens;

                -- Se todos os itens foram aprovados, aprovar o pedido
                IF NOT EXISTS (SELECT 1 FROM wl_itens_pedidos WHERE codigoPedido = v_codigoPedido AND status = 'pendente') THEN
                    UPDATE wl_pedidos SET status = 'aprovado' WHERE codigoPedido = v_codigoPedido;
                END IF;
            END IF;
        ELSE
            -- Sair do loop se o cursor não encontrar mais registros
            LEAVE pedidos_loop;
        END IF;
    END LOOP;

    -- Fechar o cursor de pedidos
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

--
-- Despejando dados para a tabela `wl_clientes`
--

INSERT INTO `wl_clientes` (`id`, `codigoComprador`, `nomeComprador`, `email`) VALUES
(1, '2001', 'Carlos Pereira', 'carlos.pereira@gmail.com'),
(2, '2002', 'Fernanda Lima', 'fernanda.lima@yahoo.com'),
(3, '2003', 'Juliana Carvalho', 'juliana.carvalho@outlook.com'),
(4, '2004', 'Rafael Costa', 'rafael.costa@gmail.com'),
(5, '2005', 'Amanda Souza', 'amanda.souza@hotmail.com');

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
-- Despejando dados para a tabela `wl_compras`
--

INSERT INTO `wl_compras` (`id`, `SKU`, `quantidade`) VALUES
(1, 'CAM123', 150),
(2, 'CAL456', 75),
(3, 'SAP789', 200),
(4, 'BOL101', 80),
(5, 'REL202', 60),
(6, 'BLU303', 90);

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

--
-- Despejando dados para a tabela `wl_entregas`
--

INSERT INTO `wl_entregas` (`id`, `codigoPedido`, `endereco`, `CEP`, `UF`, `pais`, `valor`) VALUES
(1, 'E001', 'Rua das Flores, 100', '12345-678', 'SP', 'Brasil', 50.00),
(2, 'E002', 'Avenida Brasil, 500', '98765-432', 'RJ', 'Brasil', 25.00),
(3, 'E003', 'Rua dos Lírios, 300', '54321-987', 'MG', 'Brasil', 35.00),
(4, 'E004', 'Avenida Paulista, 1500', '11111-222', 'SP', 'Brasil', 40.00),
(5, 'E005', 'Rua João Pessoa, 80', '67890-123', 'RS', 'Brasil', 45.00);

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
-- Despejando dados para a tabela `wl_estoque`
--

INSERT INTO `wl_estoque` (`id`, `SKU`, `quantidade`) VALUES
(1, 'CAM123', 10),
(2, 'CAL456', 5),
(3, 'SAP789', 2),
(4, 'BOL101', 7),
(5, 'REL202', 6),
(6, 'BLU303', 9);

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

--
-- Despejando dados para a tabela `wl_itens_pedidos`
--

INSERT INTO `wl_itens_pedidos` (`id`, `codigoPedido`, `SKU`, `quantidade`, `valor_unitario`, `status`) VALUES
(1, 'E001', 'CAM123', 2, 120.00, 'pendente'),
(2, 'E002', 'CAL456', 1, 85.00, 'pendente'),
(3, 'E003', 'SAP789', 3, 150.00, 'pendente'),
(4, 'E004', 'BOL101', 1, 60.00, 'pendente'),
(5, 'E005', 'REL202', 2, 250.00, 'pendente');

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
-- Despejando dados para a tabela `wl_pedidos`
--

INSERT INTO `wl_pedidos` (`id`, `codigoPedido`, `codigoComprador`, `dataPedido`, `valor`, `status`) VALUES
(1, 'E001', '2001', '2024-09-10', 240.00, 'pendente'),
(2, 'E002', '2002', '2024-09-11', 85.00, 'pendente'),
(3, 'E003', '2003', '2024-09-12', 450.00, 'pendente'),
(4, 'E004', '2004', '2024-09-13', 60.00, 'pendente'),
(5, 'E005', '2005', '2024-09-14', 500.00, 'pendente');

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

--
-- Despejando dados para a tabela `wl_produtos`
--

INSERT INTO `wl_produtos` (`id`, `SKU`, `UPC`, `nomeProduto`, `valor`) VALUES
(1, 'CAM123', '123456789012', 'Camiseta', 120),
(2, 'CAL456', '987654321098', 'Calça Jeans', 85),
(3, 'SAP789', '765432109876', 'Sapato', 120),
(4, 'BOL101', '345678901234', 'Bolsa', 60),
(5, 'REL202', '890123456789', 'Relógio', 250),
(6, 'BLU303', '567890123456', 'Blusa', 100);

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
-- Despejando dados para a tabela `wl_tempdata_estoque`
--

INSERT INTO `wl_tempdata_estoque` (`SKU`, `quantidade`) VALUES
('CAM123', 10),
('CAL456', 5),
('SAP789', 2),
('BOL101', 7),
('REL202', 6),
('BLU303', 9);

--
-- Índices para tabelas despejadas
--

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela `wl_compras`
--
ALTER TABLE `wl_compras`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de tabela `wl_entregas`
--
ALTER TABLE `wl_entregas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela `wl_estoque`
--
ALTER TABLE `wl_estoque`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela `wl_itens_pedidos`
--
ALTER TABLE `wl_itens_pedidos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1024;

--
-- AUTO_INCREMENT de tabela `wl_pedidos`
--
ALTER TABLE `wl_pedidos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela `wl_produtos`
--
ALTER TABLE `wl_produtos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

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
