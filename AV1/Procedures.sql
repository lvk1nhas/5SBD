--PROCEDURES

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

DELIMITER //

CREATE PROCEDURE ProcessarItens()
BEGIN
    -- Declaração das variáveis
    DECLARE v_codigoPedido VARCHAR(32);
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronta INT DEFAULT 0;
    DECLARE estoqueDisponivel INT;
    DECLARE quantidadePendente INT;

    -- Declaração do cursor
    DECLARE cursor_itens CURSOR FOR 
        SELECT codigoPedido, SKU, quantidade 
        FROM wl_itens_pedidos 
        WHERE status = 'pendente';

    -- Manipulador para quando o cursor não encontrar mais registros
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronta = 1;

    START TRANSACTION;

    OPEN cursor_itens;

    -- Loop para processar todos os itens pendentes
    itens_loop: LOOP
        FETCH cursor_itens INTO v_codigoPedido, v_codigoProduto, v_quantidade;

        -- Se não houver mais registros, sai do loop
        IF pronta THEN
            LEAVE itens_loop;
        END IF;

        -- Calcula a quantidade total de produtos pendentes que estão estoque
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
            -- Aprova todos os itens pendentes desse produto
            UPDATE wl_itens_pedidos 
            SET status = 'aprovado' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';
        ELSE
            -- Se não houver estoque suficiente, marca os itens como pendentes novamente
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

    -- Fecha o cursor de itens
    CLOSE cursor_itens;

    -- Commit da transação
    COMMIT;
--CALL ProcessarPedidos(); deixei comentado mas pode ser usado para utilizar somente uma procedure que chamará outra já

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ProcessarPedidos()
BEGIN
    -- Declaração das variáveis
    DECLARE v_codigoPedido VARCHAR(32);
    DECLARE pronta INT DEFAULT 0;
    DECLARE totalItens INT;
    DECLARE totalAprovados INT;

    -- Declaração do cursor (antes do handler)
    DECLARE cursor_pedidos CURSOR FOR 
        SELECT DISTINCT codigoPedido 
        FROM wl_itens_pedidos 
        WHERE status = 'pendente' OR status = 'aprovado';

    -- Handler para fim do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronta = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abrir o cursor de pedidos
    OPEN cursor_pedidos;

    pedidos_loop: LOOP
        -- Buscar o próximo pedido
        FETCH cursor_pedidos INTO v_codigoPedido;

        -- Se não houver mais pedidos, sair do loop
        IF pronta THEN
            LEAVE pedidos_loop;
        END IF;

        -- Contar itens no pedido
        SELECT COUNT(*) INTO totalItens 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido;

        -- Contar itens aprovados
        SELECT COUNT(*) INTO totalAprovados 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido AND status = 'aprovado';

        -- Verificar se todos os itens do pedido estão aprovados
        IF totalItens = totalAprovados AND totalItens > 0 THEN
            -- Atualizar o status do pedido para 'aprovado'
            UPDATE wl_pedidos 
            SET status = 'aprovado' 
            WHERE codigoPedido = v_codigoPedido;

            -- Debitar itens do estoque com base nos itens aprovados
            UPDATE wl_estoque e
            INNER JOIN wl_itens_pedidos i ON e.SKU = i.SKU
            SET e.quantidade = e.quantidade - i.quantidade
            WHERE i.codigoPedido = v_codigoPedido 
              AND i.status = 'aprovado';
        ELSE
            -- Caso contrário, manter o status do pedido como 'pendente'
            UPDATE wl_pedidos 
            SET status = 'pendente' 
            WHERE codigoPedido = v_codigoPedido;
        END IF;
    END LOOP;

    -- Fechar o cursor
    CLOSE cursor_pedidos;

    -- Finalizar a transação
    COMMIT;

END //

DELIMITER ;
